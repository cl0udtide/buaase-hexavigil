extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

@onready var _map_manager: Node = get_node_or_null("../MapManager")

var _events_by_cell: Dictionary = {}


func setup_events(event_points: Array) -> void:
	_events_by_cell.clear()
	for raw_point: Variant in event_points:
		if typeof(raw_point) != TYPE_DICTIONARY:
			continue
		var point: Dictionary = raw_point
		var cell := _parse_cell(point.get("cell", Vector2i(-1, -1)))
		var event_id := StringName(point.get("event_id", ""))
		if cell.x < 0 or cell.y < 0 or event_id == StringName():
			continue
		_events_by_cell[cell] = event_id
	_refresh_map()


func clear_events() -> void:
	_events_by_cell.clear()
	_refresh_map()


func get_event_id_at_cell(cell: Vector2i) -> StringName:
	return StringName(_events_by_cell.get(cell, StringName()))


func has_event_at_cell(cell: Vector2i) -> bool:
	return get_event_id_at_cell(cell) != StringName()


func mark_event_triggered(cell: Vector2i) -> void:
	_events_by_cell.erase(cell)
	_refresh_map()


func get_event_cfg_at_cell(cell: Vector2i) -> Dictionary:
	var event_id := get_event_id_at_cell(cell)
	if event_id == StringName():
		return {}
	return get_event_cfg(event_id)


func roll_event_for_cell(cell: Vector2i) -> StringName:
	return get_event_id_at_cell(cell)


func apply_event(event_id: StringName) -> Dictionary:
	var run_state = AppRefs.run_state()
	var cfg := get_event_cfg(event_id)
	if cfg.is_empty():
		return ActionResult.err(&"EVENT_NOT_FOUND", "找不到事件配置")
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState 尚未初始化")
	var payload: Dictionary = cfg.get("payload", {})
	run_state.add_materials(int(payload.get("wood", 0)), int(payload.get("stone", 0)), int(payload.get("mana", 0)))
	run_state.add_prestige(int(payload.get("prestige", 0)))
	return ActionResult.ok({"event_id": event_id})


func apply_event_for_cell(cell: Vector2i) -> Dictionary:
	var event_id := roll_event_for_cell(cell)
	if event_id == StringName():
		return ActionResult.err(&"NO_EVENT", "该格子没有可触发事件")
	var result := apply_event(event_id)
	if result.get("ok", false):
		mark_event_triggered(cell)
		var event_bus = AppRefs.event_bus()
		if event_bus != null:
			event_bus.audio_cue_requested.emit(&"event_trigger")
	return result


func get_event_cfg(event_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_event_cfg(event_id) if data_repo != null else {}


func _refresh_map() -> void:
	if _map_manager != null and _map_manager.has_method("refresh_all_layers"):
		_map_manager.refresh_all_layers()


func _parse_cell(raw_cell: Variant) -> Vector2i:
	if raw_cell is Vector2i:
		return raw_cell
	if raw_cell is Array and raw_cell.size() >= 2:
		return Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	if raw_cell is Dictionary:
		return Vector2i(int(raw_cell.get("x", -1)), int(raw_cell.get("y", -1)))
	return Vector2i(-1, -1)
