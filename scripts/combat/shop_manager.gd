extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const OperatorProgression = preload("res://scripts/combat/operator_progression.gd")

const REFRESH_COST := 2
const SHOP_SLOT_COUNT := 5
const DRIFT_START_DAY := 3
const DRIFT_TOP_COVENANT_COUNT := 2
const DRIFT_WEIGHT_MULTIPLIER := 1.2
## 商店档位权重按三幕分档（369）：后期高费干员更易出，配合定向升星让构筑成型。
const TIER_WEIGHTS_BY_DAY := {
	1: [{"cost": 2, "weight": 65.0}, {"cost": 4, "weight": 28.0}, {"cost": 7, "weight": 7.0}],
	4: [{"cost": 2, "weight": 50.0}, {"cost": 4, "weight": 35.0}, {"cost": 7, "weight": 15.0}],
	7: [{"cost": 2, "weight": 35.0}, {"cost": 4, "weight": 38.0}, {"cost": 7, "weight": 27.0}],
}
const TIER_WEIGHTS := [
	{"cost": 2, "weight": 65.0},
	{"cost": 4, "weight": 28.0},
	{"cost": 7, "weight": 7.0}
]

var _stock_slots: Array[Dictionary] = []

@onready var _unit_manager: Node = get_node_or_null("../UnitManager")
@onready var _covenant_manager: Node = get_node_or_null("../CovenantManager")


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_buy_shop_slot.connect(_on_request_buy_shop_slot)
		event_bus.request_refresh_shop.connect(_on_request_refresh_shop)
		event_bus.request_toggle_shop_lock.connect(_on_request_toggle_shop_lock)


func start_new_day_shop(_day: int) -> void:
	_roll_shop_stock(true)
	_emit_stock_changed()


func refresh_shop() -> Dictionary:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null:
		return ActionResult.err(&"APP_REFS_MISSING", "操作失败：运行时服务不可用")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以刷新商店")
	var spend_result: Dictionary = run_state.spend_prestige(_get_refresh_cost())
	if not spend_result.get("ok", false):
		return spend_result
	# 手动刷新清空锁定，整页重抽。
	_roll_shop_stock(false)
	_emit_stock_changed()
	return ActionResult.ok({"stock": get_current_stock()}, "商店已刷新")


func get_current_stock() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in _stock_slots:
		result.append((slot as Dictionary).duplicate(true))
	return result


func get_refresh_cost() -> int:
	return _get_refresh_cost()


func get_unit_purchase_cost(unit_cfg: Dictionary) -> int:
	return _get_unit_purchase_cost(unit_cfg)


func grant_unit(unit_id: StringName, star: int = OperatorProgression.DEFAULT_STAR, display_name: String = "") -> Dictionary:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null:
		return ActionResult.err(&"APP_REFS_MISSING", "操作失败：运行时服务不可用")
	if unit_id == StringName():
		return ActionResult.err(&"UNIT_NOT_FOUND", "添加失败：未选择干员")
	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
	if cfg.is_empty():
		return ActionResult.err(&"UNIT_NOT_FOUND", "添加失败：找不到单位配置")
	var operator_info: Dictionary = run_state.add_owned_operator(unit_id, display_name, OperatorProgression.normalize_star(star))
	if operator_info.is_empty():
		return ActionResult.err(&"OPERATOR_ADD_FAILED", "添加失败：无法创建干员槽位")
	var merge_result := _auto_merge_after_purchase(run_state, unit_id)
	var merge_events: Array = merge_result.get("payload", {}).get("merge_events", [])
	return ActionResult.ok({
		"unit_id": unit_id,
		"operator": operator_info,
		"merge_events": merge_events
	}, "已加入待部署区，已自动合成" if not merge_events.is_empty() else "已加入待部署区")


func try_buy_shop_slot(slot_index: int) -> Dictionary:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null:
		return ActionResult.err(&"APP_REFS_MISSING", "操作失败：运行时服务不可用")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以购买干员")
	if slot_index < 0 or slot_index >= _stock_slots.size():
		return ActionResult.err(&"SHOP_SLOT_INVALID", "购买失败：商店槽位无效")

	var slot: Dictionary = _stock_slots[slot_index]
	if bool(slot.get("sold", false)):
		return ActionResult.err(&"SHOP_SLOT_SOLD", "该槽位已购买")
	var unit_id := StringName(slot.get("unit_id", ""))
	if unit_id == StringName():
		return ActionResult.err(&"SHOP_SLOT_EMPTY", "购买失败：商店槽位为空")

	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
	if cfg.is_empty():
		return ActionResult.err(&"UNIT_NOT_FOUND", "购买失败：找不到单位配置")
	var spend_result: Dictionary = run_state.spend_prestige(_get_unit_purchase_cost(cfg))
	if not spend_result.get("ok", false):
		return spend_result

	var grant_result := grant_unit(unit_id)
	if not bool(grant_result.get("ok", false)):
		return grant_result
	slot["sold"] = true
	slot["locked"] = false
	_stock_slots[slot_index] = slot
	_emit_stock_changed()
	var grant_payload: Dictionary = grant_result.get("payload", {})
	var operator_info: Dictionary = grant_payload.get("operator", {})
	var merge_events: Array = grant_payload.get("merge_events", [])
	return ActionResult.ok({
		"slot_index": slot_index,
		"unit_id": unit_id,
		"operator": operator_info,
		"merge_events": merge_events,
		"stock": get_current_stock()
	}, "购买成功，已自动合成" if not merge_events.is_empty() else "购买成功")


## 锁定/解锁一个未购买槽位。每页同时只保留 1 个锁定位：
## 锁定槽在次日 start_new_day_shop 重抽时原位保留，手动刷新则清空锁定。
func try_toggle_lock_slot(slot_index: int) -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"APP_REFS_MISSING", "操作失败：运行时服务不可用")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以锁定商店槽位")
	if slot_index < 0 or slot_index >= _stock_slots.size():
		return ActionResult.err(&"SHOP_SLOT_INVALID", "锁定失败：商店槽位无效")
	var slot: Dictionary = _stock_slots[slot_index]
	if bool(slot.get("sold", false)):
		return ActionResult.err(&"SHOP_SLOT_SOLD", "已购买的槽位无需锁定")
	if StringName(slot.get("unit_id", "")) == StringName():
		return ActionResult.err(&"SHOP_SLOT_EMPTY", "锁定失败：商店槽位为空")
	var locking := not bool(slot.get("locked", false))
	if locking:
		for index in range(_stock_slots.size()):
			var other := _stock_slots[index] as Dictionary
			other["locked"] = false
			_stock_slots[index] = other
	slot["locked"] = locking
	_stock_slots[slot_index] = slot
	_emit_stock_changed()
	return ActionResult.ok({
		"slot_index": slot_index,
		"locked": locking,
		"stock": get_current_stock()
	}, "已锁定，明日保留" if locking else "已取消锁定")


func _roll_shop_stock(preserve_locked: bool = false) -> void:
	var carried_units: Dictionary = {}
	if preserve_locked:
		for slot in _stock_slots:
			var slot_dict := slot as Dictionary
			if bool(slot_dict.get("locked", false)) and not bool(slot_dict.get("sold", false)) \
					and StringName(slot_dict.get("unit_id", "")) != StringName():
				carried_units[int(slot_dict.get("slot_index", -1))] = StringName(slot_dict.get("unit_id", ""))
	var drifted_covenants := _get_active_drift_covenants()
	_stock_slots.clear()
	for index in range(SHOP_SLOT_COUNT):
		var locked: bool = carried_units.has(index)
		_stock_slots.append({
			"slot_index": index,
			"unit_id": StringName(carried_units[index]) if locked else _roll_unit_id(drifted_covenants),
			"sold": false,
			"locked": locked
		})


func _roll_unit_id(drifted_covenants: Array[StringName]) -> StringName:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return StringName()
	var target_cost := _roll_tier_cost()
	var candidates := _get_unit_ids_by_cost(target_cost)
	if candidates.is_empty():
		candidates = data_repo.get_all_unit_ids()
	if candidates.is_empty():
		return StringName()
	if drifted_covenants.is_empty():
		return StringName(candidates.pick_random())
	var weights: Array[float] = []
	var total_weight := 0.0
	for unit_id in candidates:
		var weight := _unit_roll_weight(unit_id, drifted_covenants)
		weights.append(weight)
		total_weight += weight
	var roll := randf() * total_weight
	var cursor := 0.0
	for index in range(candidates.size()):
		cursor += weights[index]
		if roll <= cursor:
			return StringName(candidates[index])
	return StringName(candidates.back())


## 盟约权重漂移（方案 §8.1 P2-1）：第 DRIFT_START_DAY 天起，持有"去重单位数"
## 最多的前 DRIFT_TOP_COVENANT_COUNT 个盟约，其成员干员的商店出现权重 x1.2。
## 只改变同费用档内的相对权重，不影响 2/4/7 费档位分布。
func get_covenant_drift_state() -> Dictionary:
	var covenants := _get_active_drift_covenants()
	return {
		"active": not covenants.is_empty(),
		"covenants": covenants,
		"multiplier": DRIFT_WEIGHT_MULTIPLIER
	}


func get_unit_roll_weight(unit_id: StringName) -> float:
	return _unit_roll_weight(unit_id, _get_active_drift_covenants())


func _get_active_drift_covenants() -> Array[StringName]:
	var run_state = AppRefs.run_state()
	var empty: Array[StringName] = []
	if run_state == null or int(run_state.day) < DRIFT_START_DAY:
		return empty
	return _top_owned_covenants()


func _top_owned_covenants() -> Array[StringName]:
	# 与 buff_manager._covenant_presence 同语义：每个盟约按去重单位类型统计持有数。
	var result: Array[StringName] = []
	var run_state = AppRefs.run_state()
	if run_state == null or not run_state.has_method("get_owned_operators") \
			or not run_state.has_method("get_operator_covenants"):
		return result
	var counted_units_by_covenant: Dictionary = {}
	for operator in run_state.get_owned_operators():
		var operator_dict := operator as Dictionary
		var unit_id := StringName(operator_dict.get("unit_id", ""))
		if unit_id == StringName():
			continue
		var covenants: Array = run_state.get_operator_covenants(StringName(operator_dict.get("key", "")))
		for raw_covenant: Variant in covenants:
			var covenant := StringName(raw_covenant)
			if covenant == StringName():
				continue
			var units: Dictionary = counted_units_by_covenant.get(covenant, {})
			units[unit_id] = true
			counted_units_by_covenant[covenant] = units
	var entries: Array[Dictionary] = []
	for covenant: Variant in counted_units_by_covenant.keys():
		entries.append({
			"covenant": StringName(covenant),
			"count": (counted_units_by_covenant[covenant] as Dictionary).size()
		})
	entries.sort_custom(func(entry_a: Dictionary, entry_b: Dictionary) -> bool:
		var count_a := int(entry_a.get("count", 0))
		var count_b := int(entry_b.get("count", 0))
		if count_a != count_b:
			return count_a > count_b
		return String(entry_a.get("covenant", "")) < String(entry_b.get("covenant", ""))
	)
	var top_count: int = min(DRIFT_TOP_COVENANT_COUNT, entries.size())
	for index in range(top_count):
		result.append(StringName(entries[index].get("covenant", "")))
	return result


func _unit_roll_weight(unit_id: StringName, drifted_covenants: Array[StringName]) -> float:
	if drifted_covenants.is_empty():
		return 1.0
	var run_state = AppRefs.run_state()
	if run_state == null or not run_state.has_method("get_unit_covenants"):
		return 1.0
	for raw_covenant: Variant in run_state.get_unit_covenants(unit_id):
		# 命中多个漂移盟约不叠乘，封顶一次倍率。
		if drifted_covenants.has(StringName(raw_covenant)):
			return DRIFT_WEIGHT_MULTIPLIER
	return 1.0


## 当天档位权重（三幕分档，取 <= 当天最大键）。
func _current_tier_weights() -> Array:
	var run_state = AppRefs.run_state()
	var day := int(run_state.day) if run_state != null else 1
	var best := -1
	for raw_key: Variant in TIER_WEIGHTS_BY_DAY.keys():
		var k := int(raw_key)
		if k <= day and k > best:
			best = k
	return TIER_WEIGHTS_BY_DAY[best] if best >= 0 else TIER_WEIGHTS


func _roll_tier_cost() -> int:
	var weights := _current_tier_weights()
	var total_weight := 0.0
	for entry in weights:
		total_weight += float((entry as Dictionary).get("weight", 0.0))
	if total_weight <= 0.0:
		return 1
	var roll := randf() * total_weight
	var cursor := 0.0
	for entry in weights:
		var entry_dict := entry as Dictionary
		cursor += float(entry_dict.get("weight", 0.0))
		if roll <= cursor:
			return int(entry_dict.get("cost", 1))
	return int((weights.back() as Dictionary).get("cost", 1))


func _get_unit_ids_by_cost(cost: int) -> Array[StringName]:
	var data_repo = AppRefs.data_repo()
	var result: Array[StringName] = []
	if data_repo == null:
		return result
	for unit_id in data_repo.get_all_unit_ids():
		var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
		if int(cfg.get("cost_prestige", 0)) == cost:
			result.append(unit_id)
	return result


func _get_refresh_cost() -> int:
	# 远见 2 人：商店买空后刷新内部基价降为 0；最终仍遵循刷新费用最低 1。
	var run_state = AppRefs.run_state()
	var cost := REFRESH_COST
	if _foresight_tier() >= CovenantDefs.TIER_PAIR and _is_shop_bought_out():
		cost = 0
	if run_state != null and run_state.has_method("get_buff_effect_total"):
		cost += int(round(float(run_state.get_buff_effect_total(&"shop_refresh_cost_add"))))
	return max(cost, 1)


func _get_unit_purchase_cost(unit_cfg: Dictionary) -> int:
	var run_state = AppRefs.run_state()
	var cost := int(unit_cfg.get("cost_prestige", 0))
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		cost += int(round(float(run_state.get_buff_effect_total_for_unit(&"shop_unit_cost_add", unit_cfg))))
	# 远见 3 人：所有商店干员购买价格 -1。
	if _foresight_tier() >= CovenantDefs.TIER_TRIO:
		cost += CovenantDefs.foresight_purchase_cost_delta()
	return max(cost, 1)


func _foresight_tier() -> int:
	if _covenant_manager != null and _covenant_manager.has_method("get_foresight_tier"):
		return int(_covenant_manager.get_foresight_tier())
	return 0


# 商店是否已买空（没有任何可购买的槽位）。
func _is_shop_bought_out() -> bool:
	if _stock_slots.is_empty():
		return false
	for slot in _stock_slots:
		var s := slot as Dictionary
		if not bool(s.get("sold", false)) and StringName(s.get("unit_id", "")) != StringName():
			return false
	return true


func _auto_merge_after_purchase(run_state: Node, unit_id: StringName) -> Dictionary:
	if run_state == null or not run_state.has_method("auto_merge_operators_for_unit"):
		return ActionResult.ok({"merge_events": []})
	var before_merge := Callable()
	if _unit_manager != null and _unit_manager.has_method("withdraw_operators_for_merge"):
		before_merge = Callable(_unit_manager, "withdraw_operators_for_merge")
	return run_state.auto_merge_operators_for_unit(unit_id, before_merge)


func _emit_stock_changed() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.shop_stock_changed.emit(get_current_stock())


func _emit_action_result(action: StringName, result: Dictionary) -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.shop_action_result.emit(action, result)


func _on_request_buy_shop_slot(slot_index: int) -> void:
	_emit_action_result(&"buy", try_buy_shop_slot(slot_index))


func _on_request_refresh_shop() -> void:
	_emit_action_result(&"refresh", refresh_shop())


func _on_request_toggle_shop_lock(slot_index: int) -> void:
	_emit_action_result(&"lock", try_toggle_lock_slot(slot_index))
