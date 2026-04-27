extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

@onready var _map_manager: Node = get_node_or_null("../MapManager")


func roll_event_for_cell(cell: Vector2i) -> StringName:
	if _map_manager != null and _map_manager.has_method("get_event_id_at_cell"):
		var map_event_id: StringName = _map_manager.get_event_id_at_cell(cell)
		if map_event_id != StringName():
			return map_event_id
	return StringName()


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
	if result.get("ok", false) and _map_manager != null and _map_manager.has_method("mark_event_triggered"):
		_map_manager.mark_event_triggered(cell)
	return result


func get_event_cfg(event_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_event_cfg(event_id) if data_repo != null else {}
