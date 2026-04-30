extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const REFRESH_COST := 2
const SHOP_SLOT_COUNT := 5
const TIER_WEIGHTS := [
	{"cost": 1, "weight": 60.0},
	{"cost": 3, "weight": 30.0},
	{"cost": 7, "weight": 10.0}
]

var _stock_slots: Array[Dictionary] = []


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
		return ActionResult.err(&"APP_REFS_MISSING", "APP_REFS_MISSING")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以刷新商店")
	var spend_result: Dictionary = run_state.spend_prestige(REFRESH_COST)
	if not spend_result.get("ok", false):
		return spend_result
	_roll_shop_stock()
	_emit_stock_changed()
	return ActionResult.ok({"stock": get_current_stock()}, "SHOP_REFRESHED")


func get_current_stock() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in _stock_slots:
		result.append((slot as Dictionary).duplicate(true))
	return result


func try_buy_shop_slot(slot_index: int) -> Dictionary:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null:
		return ActionResult.err(&"APP_REFS_MISSING", "APP_REFS_MISSING")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以购买干员")
	if slot_index < 0 or slot_index >= _stock_slots.size():
		return ActionResult.err(&"SHOP_SLOT_INVALID", "SHOP_SLOT_INVALID")

	var slot: Dictionary = _stock_slots[slot_index]
	if bool(slot.get("sold", false)):
		return ActionResult.err(&"SHOP_SLOT_SOLD", "该槽位已购买")
	var unit_id := StringName(slot.get("unit_id", ""))
	if unit_id == StringName():
		return ActionResult.err(&"SHOP_SLOT_EMPTY", "SHOP_SLOT_EMPTY")

	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
	if cfg.is_empty():
		return ActionResult.err(&"UNIT_NOT_FOUND", "UNIT_NOT_FOUND")
	var spend_result: Dictionary = run_state.spend_prestige(int(cfg.get("cost_prestige", 0)))
	if not spend_result.get("ok", false):
		return spend_result

	var operator_info: Dictionary = run_state.add_owned_operator(unit_id)
	slot["sold"] = true
	_stock_slots[slot_index] = slot
	_emit_stock_changed()
	return ActionResult.ok({
		"slot_index": slot_index,
		"unit_id": unit_id,
		"operator": operator_info,
		"stock": get_current_stock()
	}, "璐拱鎴愬姛")


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
