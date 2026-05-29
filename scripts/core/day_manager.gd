extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const EXPLORE_AP_COST := 2
const EVENT_TRIGGER_AP_COST := 2
const RESOURCE_COLLECT_AP_COST := 1
const WOOD_RESOURCE_COLLECT_AMOUNT := 2
const DEFAULT_RESOURCE_COLLECT_AMOUNT := 1

@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _random_event_manager: Node = get_node_or_null("../RandomEventManager")

var _collected_resource_cells: Dictionary = {}


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_explore.connect(_on_request_explore)
		event_bus.request_interact_event.connect(_on_request_interact_event)


func start_day(_day: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state != null:
		run_state.reset_action_points(run_state.DEFAULT_ACTION_POINTS)
	_collected_resource_cells.clear()


func try_explore(cell: Vector2i) -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState 尚未初始化")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天才能探索")
	if _map_manager == null or not _map_manager.has_method("is_inside"):
		return ActionResult.err(&"MAP_UNAVAILABLE", "地图尚未初始化")
	if not _map_manager.is_inside(cell):
		return ActionResult.err(&"OUT_OF_MAP", "目标格子不在地图内")
	if _map_manager.is_discovered(cell):
		return ActionResult.err(&"ALREADY_DISCOVERED", "该格子已经探索过")
	if _map_manager.has_method("has_discovered_neighbor") and not _map_manager.has_discovered_neighbor(cell):
		return ActionResult.err(&"NOT_ADJACENT_TO_DISCOVERED", "探索目标必须与已探索区域四向相邻")

	var ap_result: Dictionary = run_state.consume_action_points(EXPLORE_AP_COST)
	if not ap_result.get("ok", false):
		return ap_result

	_map_manager.reveal_area(cell, 1)
	return ActionResult.ok({"ap_cost": EXPLORE_AP_COST})


func try_trigger_event(cell: Vector2i, choice_id: StringName = StringName()) -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState 尚未初始化")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天才能处理事件")
	if _map_manager == null or not _map_manager.has_method("is_inside"):
		return ActionResult.err(&"MAP_UNAVAILABLE", "地图尚未初始化")
	if not _map_manager.is_inside(cell):
		return ActionResult.err(&"OUT_OF_MAP", "目标格子不在地图内")
	if not _map_manager.is_discovered(cell):
		return ActionResult.err(&"NOT_DISCOVERED", "只能处理已探索区域的事件")
	if _random_event_manager == null:
		return ActionResult.err(&"EVENT_UNAVAILABLE", "事件系统尚未初始化")
	if _random_event_manager.has_method("get_event_id_at_cell") and _random_event_manager.get_event_id_at_cell(cell) == StringName():
		return ActionResult.err(&"NO_EVENT", "该格子没有可触发事件")

	var ap_result: Dictionary = run_state.consume_action_points(EVENT_TRIGGER_AP_COST)
	if not ap_result.get("ok", false):
		return ap_result

	var result: Dictionary
	if _random_event_manager.has_method("apply_event_for_cell"):
		result = _random_event_manager.apply_event_for_cell(cell, choice_id)
	elif _random_event_manager.has_method("roll_event_for_cell") and _random_event_manager.has_method("apply_event"):
		var event_id: StringName = _random_event_manager.roll_event_for_cell(cell)
		if event_id == StringName():
			run_state.reset_action_points(run_state.action_points + EVENT_TRIGGER_AP_COST)
			return ActionResult.err(&"NO_EVENT", "该格子没有可触发事件")
		result = _random_event_manager.apply_event(event_id)
	else:
		run_state.reset_action_points(run_state.action_points + EVENT_TRIGGER_AP_COST)
		return ActionResult.err(&"EVENT_UNAVAILABLE", "事件系统尚未初始化")

	if not result.get("ok", false):
		run_state.reset_action_points(run_state.action_points + EVENT_TRIGGER_AP_COST)
		return result
	var payload: Dictionary = result.get("payload", {})
	payload["ap_cost"] = EVENT_TRIGGER_AP_COST
	result["payload"] = payload
	if String(result.get("message", "")).is_empty():
		result["message"] = "事件已处理"
	return result


func try_collect_resource(cell: Vector2i) -> Dictionary:
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState 尚未初始化")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天才能采集资源")
	if _map_manager == null or not _map_manager.has_method("is_inside"):
		return ActionResult.err(&"MAP_UNAVAILABLE", "地图尚未初始化")
	if not _map_manager.is_inside(cell):
		return ActionResult.err(&"OUT_OF_MAP", "目标格子不在地图内")
	if not _map_manager.is_discovered(cell):
		return ActionResult.err(&"NOT_DISCOVERED", "只能采集已探索的资源点")
	var data: CellData = _map_manager.get_cell_data(cell)
	if data == null or data.resource_type == StringName():
		return ActionResult.err(&"NOT_RESOURCE_CELL", "该格子不是资源点")
	if not [&"wood", &"stone", &"mana"].has(data.resource_type):
		return ActionResult.err(&"UNKNOWN_RESOURCE_TYPE", "未知资源类型")
	if _collected_resource_cells.has(cell):
		return ActionResult.err(&"RESOURCE_ALREADY_COLLECTED", "该资源点今天已经采集过")
	var ap_result: Dictionary = run_state.consume_action_points(RESOURCE_COLLECT_AP_COST)
	if not ap_result.get("ok", false):
		return ap_result
	var collect_amount: int = _get_resource_collect_amount(data.resource_type)
	match data.resource_type:
		&"wood":
			run_state.add_materials(collect_amount, 0, 0)
		&"stone":
			run_state.add_materials(0, collect_amount, 0)
		&"mana":
			run_state.add_materials(0, 0, collect_amount)
	_collected_resource_cells[cell] = true
	if event_bus != null:
		event_bus.resource_collected.emit(cell, data.resource_type, collect_amount)
	return ActionResult.ok({
		"cell": cell,
		"resource_type": data.resource_type,
		"amount": collect_amount,
		"ap_cost": RESOURCE_COLLECT_AP_COST
	}, "资源已采集")


func is_resource_collected_today(cell: Vector2i) -> bool:
	return _collected_resource_cells.has(cell)


func _get_resource_collect_amount(resource_type: StringName) -> int:
	return WOOD_RESOURCE_COLLECT_AMOUNT if resource_type == &"wood" else DEFAULT_RESOURCE_COLLECT_AMOUNT


func request_start_night() -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState 尚未初始化")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "当前不在白天阶段")
	return ActionResult.ok()


func _on_request_explore(cell: Vector2i) -> void:
	try_explore(cell)


func _on_request_interact_event(cell: Vector2i) -> void:
	try_trigger_event(cell)
