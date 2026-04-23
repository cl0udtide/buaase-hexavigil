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
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以部署")
	if not run_state.has_owned_unit(unit_id):
		return ActionResult.err(&"UNIT_NOT_OWNED", "尚未拥有该单位")
	if run_state.deployed_count >= run_state.deploy_limit:
		return ActionResult.err(&"DEPLOY_LIMIT_REACHED", "已达到部署上限")
	if is_unit_redeploying(unit_id):
		return ActionResult.err(&"UNIT_COOLDOWN", "该单位仍在再部署冷却中")
	if not _map_manager.is_walkable(cell):
		return ActionResult.err(&"CELL_NOT_WALKABLE", "该格子不可部署单位")

	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
	var scene: PackedScene = data_repo.get_scene_by_key(StringName(cfg.get("scene_key", "")))
	if scene == null:
		return ActionResult.err(&"SCENE_MISSING", "单位场景尚未创建")
	if _unit_root == null:
		return ActionResult.err(&"WORLD_NOT_READY", "UnitRoot 节点不存在")
	var actor: Node = scene.instantiate()
	actor.runtime_id = _next_runtime_id
	if actor.has_method("setup_from_cfg"):
		actor.setup_from_cfg(unit_id, cfg, cell, facing)
	_unit_root.add_child(actor)
	_units_by_runtime_id[_next_runtime_id] = actor
	run_state.change_deployed_count(1)
	if event_bus != null:
		event_bus.unit_deployed.emit(_next_runtime_id, unit_id, cell)
	_next_runtime_id += 1
	return ActionResult.ok({"runtime_id": _next_runtime_id - 1})


func try_retreat_unit(unit_runtime_id: int) -> Dictionary:
	var unit := get_unit_by_runtime_id(unit_runtime_id)
	if unit == null:
		return ActionResult.err(&"UNIT_NOT_FOUND", "找不到单位实例")
	_redeploy_timers[unit.unit_id] = float(unit.cfg.get("redeploy_sec", 0.0))
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


func is_unit_redeploying(unit_id: StringName) -> bool:
	return _redeploy_timers.get(unit_id, 0.0) > 0.0


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
	if run_state != null:
		run_state.change_deployed_count(-1)
	if event_bus != null:
		event_bus.unit_removed.emit(unit_runtime_id, reason)
	unit.queue_free()


func _on_request_deploy(unit_id: StringName, cell: Vector2i, facing: Vector2i) -> void:
	try_deploy_unit(unit_id, cell, facing)


func _on_request_retreat(unit_runtime_id: int) -> void:
	try_retreat_unit(unit_runtime_id)


func _on_request_cast_skill(unit_runtime_id: int) -> void:
	try_cast_skill(unit_runtime_id)
