extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")


var _next_runtime_id := 1
var _units_by_runtime_id: Dictionary = {}
var _redeploy_timers: Dictionary = {}

@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _unit_root: Node = get_node_or_null("../../World/UnitRoot")


func _ready() -> void:
	set_process(true)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_deploy.connect(_on_request_deploy)
		event_bus.request_retreat.connect(_on_request_retreat)
		event_bus.request_cast_skill.connect(_on_request_cast_skill)


func _process(delta: float) -> void:
	tick_redeploy(delta)


func try_deploy_unit(unit_id: StringName, cell: Vector2i, facing: Vector2i) -> Dictionary:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	var event_bus = AppRefs.event_bus()
	if run_state == null or data_repo == null:
		return ActionResult.err(&"APP_REFS_MISSING", "全局单例尚未初始化")
	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
	if cfg.is_empty():
		return ActionResult.err(&"UNIT_NOT_FOUND", "找不到单位配置")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以部署")
	if not run_state.has_owned_unit(unit_id):
		return ActionResult.err(&"UNIT_NOT_OWNED", "尚未拥有该单位")
	if run_state.deployed_count >= run_state.deploy_limit:
		return ActionResult.err(&"DEPLOY_LIMIT_REACHED", "已达到部署上限")
	if is_unit_redeploying(unit_id):
		return ActionResult.err(&"UNIT_COOLDOWN", "该单位仍在再部署冷却中")
	if _map_manager == null:
		return ActionResult.err(&"MAP_UNAVAILABLE", "地图尚未初始化")
	if not _map_manager.is_walkable(cell):
		return ActionResult.err(&"CELL_NOT_WALKABLE", "该格子不可部署单位")
	var cell_data = _map_manager.get_cell_data(cell) if _map_manager.has_method("get_cell_data") else null
	if cell_data != null and cell_data.is_core:
		return ActionResult.err(&"CELL_NOT_WALKABLE", "核心格不可部署单位")

	var scene: PackedScene = data_repo.get_scene_by_key(StringName(cfg.get("scene_key", "")))
	if scene == null:
		return ActionResult.err(&"SCENE_MISSING", "单位场景尚未创建")
	if _unit_root == null:
		return ActionResult.err(&"WORLD_NOT_READY", "UnitRoot 节点不存在")
	var actor: Node = scene.instantiate()
	_unit_root.add_child(actor)
	actor.runtime_id = _next_runtime_id
	if actor.has_method("setup_from_cfg"):
		actor.setup_from_cfg(unit_id, cfg, cell, facing)
	_units_by_runtime_id[_next_runtime_id] = actor
	if _map_manager != null and _map_manager.has_method("set_unit_occupy"):
		_map_manager.set_unit_occupy(cell, true, _next_runtime_id)
	run_state.change_deployed_count(1)
	if event_bus != null:
		event_bus.unit_deployed.emit(_next_runtime_id, unit_id, cell)
	_debug_log("部署单位 %s#%d 到格子 %s，朝向 %s" % [String(cfg.get("name", unit_id)), _next_runtime_id, cell, _direction_text(facing)])
	_next_runtime_id += 1
	return ActionResult.ok({"runtime_id": _next_runtime_id - 1})


func try_retreat_unit(unit_runtime_id: int) -> Dictionary:
	var unit := get_unit_by_runtime_id(unit_runtime_id)
	if unit == null:
		return ActionResult.err(&"UNIT_NOT_FOUND", "找不到单位实例")
	_redeploy_timers[unit.unit_id] = float(unit.cfg.get("redeploy_sec", 0.0))
	_debug_log("撤退单位 %s#%d，进入再部署冷却 %.1f 秒" % [String(unit.cfg.get("name", unit.unit_id)), unit_runtime_id, float(unit.cfg.get("redeploy_sec", 0.0))])
	remove_unit(unit_runtime_id, GameEnums.UNIT_REMOVE_RETREAT)
	return ActionResult.ok()


func try_cast_skill(unit_runtime_id: int) -> Dictionary:
	var unit := get_unit_by_runtime_id(unit_runtime_id)
	if unit == null:
		return ActionResult.err(&"UNIT_NOT_FOUND", "找不到单位实例")
	if not unit.can_cast_skill():
		return ActionResult.err(&"SP_NOT_READY", "技能能量不足")
	unit.cast_skill()
	return ActionResult.ok()


func get_unit_by_runtime_id(unit_runtime_id: int) -> Node:
	return _units_by_runtime_id.get(unit_runtime_id)


func get_all_deployed_units() -> Array:
	return _units_by_runtime_id.values()


func get_unit_by_cell(cell: Vector2i) -> Node:
	for unit in _units_by_runtime_id.values():
		if unit != null and unit.has_method("get_current_cell") and unit.get_current_cell() == cell:
			return unit
	return null


func is_unit_redeploying(unit_id: StringName) -> bool:
	return _redeploy_timers.get(unit_id, 0.0) > 0.0


func get_redeploy_remaining(unit_id: StringName) -> float:
	return float(_redeploy_timers.get(unit_id, 0.0))


func tick_redeploy(delta: float) -> void:
	var completed: Array[StringName] = []
	for unit_id in _redeploy_timers.keys():
		_redeploy_timers[unit_id] = max(_redeploy_timers[unit_id] - delta, 0.0)
		if _redeploy_timers[unit_id] <= 0.0:
			completed.append(unit_id)
	for unit_id in completed:
		_redeploy_timers.erase(unit_id)


func remove_unit(unit_runtime_id: int, reason: int) -> void:
	var unit := get_unit_by_runtime_id(unit_runtime_id)
	if unit == null:
		return
	_units_by_runtime_id.erase(unit_runtime_id)
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if _map_manager != null and _map_manager.has_method("set_unit_occupy"):
		_map_manager.set_unit_occupy(unit.get_current_cell(), false)
	if unit.has_method("release_all_blocked_enemies"):
		unit.release_all_blocked_enemies()
	if run_state != null:
		run_state.change_deployed_count(-1)
	if event_bus != null:
		event_bus.unit_removed.emit(unit_runtime_id, reason)
	_debug_log("单位离场 %s#%d，原因：%s" % [String(unit.cfg.get("name", unit.unit_id)), unit_runtime_id, _remove_reason_text(reason)])
	unit.queue_free()


func clear_all_units() -> void:
	for unit_runtime_id in _units_by_runtime_id.keys().duplicate():
		remove_unit(int(unit_runtime_id), GameEnums.UNIT_REMOVE_SCRIPTED)
	_redeploy_timers.clear()


func _debug_log(message: String) -> void:
	var tree := get_tree()
	if tree != null:
		tree.call_group("combat_debug_log", "append_combat_debug", message)


func _direction_text(direction: Vector2i) -> String:
	if abs(direction.x) >= abs(direction.y):
		return "右" if direction.x >= 0 else "左"
	return "下" if direction.y >= 0 else "上"


func _remove_reason_text(reason: int) -> String:
	match reason:
		GameEnums.UNIT_REMOVE_RETREAT:
			return "撤退"
		GameEnums.UNIT_REMOVE_DEAD:
			return "死亡"
		GameEnums.UNIT_REMOVE_SCRIPTED:
			return "调试清场"
		_:
			return "未知"


func _on_request_deploy(unit_id: StringName, cell: Vector2i, facing: Vector2i) -> void:
	try_deploy_unit(unit_id, cell, facing)


func _on_request_retreat(unit_runtime_id: int) -> void:
	try_retreat_unit(unit_runtime_id)


func _on_request_cast_skill(unit_runtime_id: int) -> void:
	try_cast_skill(unit_runtime_id)
