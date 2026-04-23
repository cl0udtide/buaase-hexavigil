extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")


func roll_event_for_cell(cell: Vector2i) -> StringName:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return StringName()
	var event_ids: Array[StringName] = data_repo.get_all_event_ids()
	if cell.x % 2 == 0 and not event_ids.is_empty():
		return event_ids[0]
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


func get_event_cfg(event_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_event_cfg(event_id) if data_repo != null else {}
