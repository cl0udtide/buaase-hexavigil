extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const EXPLORE_AP_COST := 2

@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _random_event_manager: Node = get_node_or_null("../RandomEventManager")


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_explore.connect(_on_request_explore)
		event_bus.request_interact_event.connect(_on_request_interact_event)


func start_day(_day: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state != null:
		run_state.reset_action_points(run_state.DEFAULT_ACTION_POINTS)


func try_explore(cell: Vector2i) -> Dictionary:
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
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
	var event_id := StringName()
	if _random_event_manager != null and _random_event_manager.has_method("roll_event_for_cell"):
		event_id = _random_event_manager.roll_event_for_cell(cell)
	if event_id != StringName():
		if event_bus != null:
			event_bus.random_event_triggered.emit(event_id, cell)
	return ActionResult.ok({"event_id": event_id})


func try_trigger_event(cell: Vector2i) -> Dictionary:
	if _random_event_manager == null:
		return ActionResult.err(&"EVENT_UNAVAILABLE", "事件系统尚未初始化")
	if _random_event_manager.has_method("apply_event_for_cell"):
		return _random_event_manager.apply_event_for_cell(cell)
	if not _random_event_manager.has_method("roll_event_for_cell"):
		return ActionResult.err(&"EVENT_UNAVAILABLE", "事件系统尚未初始化")
	var event_id: StringName = _random_event_manager.roll_event_for_cell(cell)
	if event_id == StringName():
		return ActionResult.err(&"NO_EVENT", "该格子没有可触发事件")
	return _random_event_manager.apply_event(event_id)


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
