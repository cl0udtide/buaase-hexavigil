extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")


var _next_runtime_id := 1
var _buildings_by_runtime_id: Dictionary = {}
var _buildings_by_cell: Dictionary = {}
var _validator := BuildValidator.new()

@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _path_service: Node = get_node_or_null("../PathService")
@onready var _building_root: Node = get_node_or_null("../../World/BuildingRoot")


func _ready() -> void:
	_validator.map_manager = _map_manager
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_build.connect(_on_request_build)


func try_place_building(cell: Vector2i, building_id: StringName) -> Dictionary:
	var check := _validator.can_place_building(cell, building_id)
	if not check.get("ok", false):
		return check

	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if data_repo == null or run_state == null:
		return ActionResult.err(&"APP_REFS_MISSING", "全局单例尚未初始化")
	var cfg: Dictionary = data_repo.get_building_cfg(building_id)
	var material_result: Dictionary = run_state.spend_materials(
		int(cfg.get("cost_wood", 0)),
		int(cfg.get("cost_stone", 0)),
		int(cfg.get("cost_mana", 0))
	)
	if not material_result.get("ok", false):
		return material_result
	var ap_result: Dictionary = run_state.consume_action_points(int(cfg.get("ap_cost", 0)))
	if not ap_result.get("ok", false):
		run_state.add_materials(int(cfg.get("cost_wood", 0)), int(cfg.get("cost_stone", 0)), int(cfg.get("cost_mana", 0)))
		return ap_result

	var scene: PackedScene = data_repo.get_scene_by_key(StringName(cfg.get("scene_key", "")))
	if scene == null:
		run_state.add_materials(int(cfg.get("cost_wood", 0)), int(cfg.get("cost_stone", 0)), int(cfg.get("cost_mana", 0)))
		run_state.reset_action_points(run_state.action_points + int(cfg.get("ap_cost", 0)))
		return ActionResult.err(&"SCENE_MISSING", "建筑场景尚未创建")
	if _building_root == null:
		run_state.add_materials(int(cfg.get("cost_wood", 0)), int(cfg.get("cost_stone", 0)), int(cfg.get("cost_mana", 0)))
		run_state.reset_action_points(run_state.action_points + int(cfg.get("ap_cost", 0)))
		return ActionResult.err(&"WORLD_NOT_READY", "BuildingRoot 节点不存在")
	var actor: Node = scene.instantiate()
	actor.runtime_id = _next_runtime_id
	if actor.has_method("setup_from_cfg"):
		actor.setup_from_cfg(building_id, cfg, cell)
	_building_root.add_child(actor)

	_buildings_by_runtime_id[_next_runtime_id] = actor
	_buildings_by_cell[cell] = actor
	_map_manager.set_building_occupy(cell, true, _next_runtime_id)
	if bool(cfg.get("blocks_path", false)):
		_path_service.set_cell_blocked(cell, true)
	if event_bus != null:
		event_bus.building_placed.emit(_next_runtime_id, building_id, cell)
		event_bus.path_grid_changed.emit()
	_next_runtime_id += 1
	return ActionResult.ok({"runtime_id": _next_runtime_id - 1})


func try_repair_building(building_runtime_id: int) -> Dictionary:
	var check := _validator.can_repair_building(building_runtime_id)
	if not check.get("ok", false):
		return check
	var actor := get_building_by_runtime_id(building_runtime_id)
	if actor == null:
		return ActionResult.err(&"BUILDING_NOT_FOUND", "找不到建筑实例")
	actor.repair_full()
	return ActionResult.ok()


func damage_building(building_runtime_id: int, value: int, damage_type: int) -> void:
	var actor := get_building_by_runtime_id(building_runtime_id)
	if actor != null:
		actor.receive_damage(value, damage_type)


func remove_building(building_runtime_id: int) -> void:
	var actor := get_building_by_runtime_id(building_runtime_id)
	if actor == null:
		return
	var cell: Vector2i = actor.get_current_cell()
	var cfg: Dictionary = actor.cfg
	_buildings_by_runtime_id.erase(building_runtime_id)
	_buildings_by_cell.erase(cell)
	if _map_manager != null:
		_map_manager.set_building_occupy(cell, false)
	if bool(cfg.get("blocks_path", false)):
		_path_service.set_cell_blocked(cell, false)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.building_destroyed.emit(building_runtime_id, actor.building_id, cell)
		event_bus.path_grid_changed.emit()
	actor.queue_free()


func collect_day_income() -> void:
	pass


func refresh_daytime_repair() -> void:
	pass


func get_building_by_cell(cell: Vector2i) -> Node:
	return _buildings_by_cell.get(cell)


func get_building_by_runtime_id(building_runtime_id: int) -> Node:
	return _buildings_by_runtime_id.get(building_runtime_id)


func _on_request_build(cell: Vector2i, building_id: StringName) -> void:
	try_place_building(cell, building_id)
