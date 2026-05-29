extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const OperatorProgression = preload("res://scripts/combat/operator_progression.gd")

const REFRESH_COST := 2
const SHOP_SLOT_COUNT := 5
const TIER_WEIGHTS := [
	{"cost": 2, "weight": 60.0},
	{"cost": 4, "weight": 30.0},
	{"cost": 7, "weight": 10.0}
]

var _stock_slots: Array[Dictionary] = []

@onready var _unit_manager: Node = get_node_or_null("../UnitManager")
@onready var _covenant_manager: Node = get_node_or_null("../CovenantManager")


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_buy_shop_slot.connect(_on_request_buy_shop_slot)
		event_bus.request_refresh_shop.connect(_on_request_refresh_shop)


func start_new_day_shop(_day: int) -> void:
	_roll_shop_stock()
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
	_roll_shop_stock()
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


func _roll_shop_stock() -> void:
	_stock_slots.clear()
	for index in range(SHOP_SLOT_COUNT):
		_stock_slots.append({
			"slot_index": index,
			"unit_id": _roll_unit_id(),
			"sold": false
		})


func _roll_unit_id() -> StringName:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return StringName()
	var target_cost := _roll_tier_cost()
	var candidates := _get_unit_ids_by_cost(target_cost)
	if candidates.is_empty():
		candidates = data_repo.get_all_unit_ids()
	if candidates.is_empty():
		return StringName()
	return StringName(candidates.pick_random())


func _roll_tier_cost() -> int:
	var total_weight := 0.0
	for entry in TIER_WEIGHTS:
		total_weight += float((entry as Dictionary).get("weight", 0.0))
	if total_weight <= 0.0:
		return 1
	var roll := randf() * total_weight
	var cursor := 0.0
	for entry in TIER_WEIGHTS:
		var entry_dict := entry as Dictionary
		cursor += float(entry_dict.get("weight", 0.0))
		if roll <= cursor:
			return int(entry_dict.get("cost", 1))
	return int((TIER_WEIGHTS.back() as Dictionary).get("cost", 1))


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
	# 远见 2 人：商店买空后刷新不消耗声望。
	if _foresight_tier() >= CovenantDefs.TIER_PAIR and _is_shop_bought_out():
		return 0
	var run_state = AppRefs.run_state()
	var cost := REFRESH_COST
	if run_state != null and run_state.has_method("get_buff_effect_total"):
		cost += int(round(float(run_state.get_buff_effect_total(&"shop_refresh_cost_add"))))
	return max(cost, 0)


func _get_unit_purchase_cost(unit_cfg: Dictionary) -> int:
	var run_state = AppRefs.run_state()
	var cost := int(unit_cfg.get("cost_prestige", 0))
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		cost += int(round(float(run_state.get_buff_effect_total_for_unit(&"shop_unit_cost_add", unit_cfg))))
	# 远见 3 人：所有商店干员购买价格 -1。
	if _foresight_tier() >= CovenantDefs.TIER_TRIO:
		cost += CovenantDefs.foresight_purchase_cost_delta()
	return max(cost, 0)


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
