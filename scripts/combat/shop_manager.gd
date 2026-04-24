extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const REFRESH_COST := 2

var _stock: Array[StringName] = []


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_buy_unit.connect(_on_request_buy_unit)
		event_bus.request_refresh_shop.connect(_on_request_refresh_shop)


func start_new_day_shop(_day: int) -> void:
	var data_repo = AppRefs.data_repo()
	var all_units: Array[StringName] = data_repo.get_all_unit_ids() if data_repo != null else []
	all_units.shuffle()
	_stock = all_units.slice(0, min(3, all_units.size()))
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.shop_stock_changed.emit(_stock)


func refresh_shop() -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState 尚未初始化")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以刷新商店")
	var spend_result: Dictionary = run_state.spend_prestige(REFRESH_COST)
	if not spend_result.get("ok", false):
		return spend_result
	start_new_day_shop(run_state.day)
	return ActionResult.ok({"stock": _stock})


func get_current_stock() -> Array[StringName]:
	return _stock.duplicate()


func try_buy_unit(unit_id: StringName) -> Dictionary:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null:
		return ActionResult.err(&"APP_REFS_MISSING", "全局单例尚未初始化")
	if not _stock.has(unit_id):
		return ActionResult.err(&"UNIT_NOT_IN_STOCK", "该单位不在当前商店库存中")
	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
	if cfg.is_empty():
		return ActionResult.err(&"UNIT_NOT_FOUND", "找不到单位配置")
	var spend_result: Dictionary = run_state.spend_prestige(int(cfg.get("cost_prestige", 0)))
	if not spend_result.get("ok", false):
		return spend_result
	# 商店购买的是编队槽位，不再按 unit_id 去重；同类单位可拥有多名实例。
	var operator_info: Dictionary = run_state.add_owned_operator(unit_id)
	return ActionResult.ok({"unit_id": unit_id, "operator": operator_info})


func _on_request_buy_unit(unit_id: StringName) -> void:
	try_buy_unit(unit_id)


func _on_request_refresh_shop() -> void:
	refresh_shop()
