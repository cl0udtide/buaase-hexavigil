extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const WALL_NORTH := 1
const WALL_EAST := 2
const WALL_SOUTH := 4
const WALL_WEST := 8
const WALL_REFRESH_OFFSETS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT
]

var _next_runtime_id := 1
var _buildings_by_runtime_id: Dictionary = {}
var _buildings_by_cell: Dictionary = {}
var _validator := BuildValidator.new()
var _unit_heal_remainders: Dictionary = {}
var _active_aura_outline_ids: Dictionary = {}

@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _path_service: Node = get_node_or_null("../PathService")
@onready var _unit_manager: Node = get_node_or_null("../UnitManager")
@onready var _enemy_manager: Node = get_node_or_null("../EnemyManager")
@onready var _building_root: Node = get_node_or_null("../../World/BuildingRoot")
@onready var _map_root: Node = get_node_or_null("../../World/MapRoot")


func _ready() -> void:
	set_process(true)
	_validator.map_manager = _map_manager
	_validator.path_service = _path_service
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_build.connect(_on_request_build)
		event_bus.request_toggle_building.connect(_on_request_toggle_building)
		event_bus.day_started.connect(_on_day_started)
		event_bus.night_started.connect(_on_night_started)


func _process(delta: float) -> void:
	_apply_aura_effects(delta)


func try_place_building(cell: Vector2i, building_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if data_repo == null or run_state == null:
		return ActionResult.err(&"APP_REFS_MISSING", "操作失败：运行时服务不可用")
	var cfg: Dictionary = data_repo.get_building_cfg(building_id)
	var material_costs := BuildValidator.get_building_material_costs(cfg)
	var check := _validator.can_place_building(cell, building_id, material_costs)
	if not check.get("ok", false):
		return check
	var cost_wood := int(material_costs.get("wood", 0))
	var cost_stone := int(material_costs.get("stone", 0))
	var cost_mana := int(material_costs.get("mana", 0))
	var material_result: Dictionary = run_state.spend_materials(
		cost_wood,
		cost_stone,
		cost_mana
	)
	if not material_result.get("ok", false):
		return material_result
	var ap_result: Dictionary = run_state.consume_action_points(int(cfg.get("ap_cost", 0)))
	if not ap_result.get("ok", false):
		run_state.add_materials(cost_wood, cost_stone, cost_mana)
		return ap_result

	var scene: PackedScene = data_repo.get_scene_by_key(StringName(cfg.get("scene_key", "")))
	if scene == null:
		run_state.add_materials(cost_wood, cost_stone, cost_mana)
		run_state.reset_action_points(run_state.action_points + int(cfg.get("ap_cost", 0)))
		return ActionResult.err(&"SCENE_MISSING", "建造失败：建筑场景缺失")
	if _building_root == null:
		run_state.add_materials(cost_wood, cost_stone, cost_mana)
		run_state.reset_action_points(run_state.action_points + int(cfg.get("ap_cost", 0)))
		return ActionResult.err(&"WORLD_NOT_READY", "操作失败：建筑根节点不可用")

	var actor: Node = scene.instantiate()
	_building_root.add_child(actor)
	actor.runtime_id = _next_runtime_id
	if actor.has_method("setup_from_cfg"):
		actor.setup_from_cfg(building_id, cfg, cell)

	_buildings_by_runtime_id[_next_runtime_id] = actor
	_buildings_by_cell[cell] = actor
	if _map_manager != null:
		_map_manager.set_building_occupy(cell, true, _next_runtime_id)
	if bool(cfg.get("blocks_path", false)) and _path_service != null:
		_path_service.set_cell_blocked(cell, true)
	if event_bus != null:
		event_bus.building_placed.emit(_next_runtime_id, building_id, cell)
	_refresh_wall_connections_around(cell)
	if _is_path_blocking_cfg(cfg):
		_emit_path_grid_changed("路径阻挡更新：放置 %s#%d，通知敌人重新寻路" % [String(cfg.get("name", building_id)), _next_runtime_id])
	var created_runtime_id := _next_runtime_id
	_next_runtime_id += 1
	return ActionResult.ok({"runtime_id": created_runtime_id})


func try_place_building_debug(cell: Vector2i, building_id: StringName) -> Dictionary:
	var check := _can_place_building_debug(cell)
	if not check.get("ok", false):
		return check
	var data_repo = AppRefs.data_repo()
	var event_bus = AppRefs.event_bus()
	if data_repo == null:
		return ActionResult.err(&"APP_REFS_MISSING", "操作失败：运行时服务不可用")
	var cfg: Dictionary = data_repo.get_building_cfg(building_id)
	if cfg.is_empty():
		return ActionResult.err(&"BUILDING_CONFIG_MISSING", "建造失败：找不到建筑配置")
	var scene: PackedScene = data_repo.get_scene_by_key(StringName(cfg.get("scene_key", "")))
	if scene == null:
		return ActionResult.err(&"SCENE_MISSING", "建造失败：建筑场景缺失")
	if _building_root == null:
		return ActionResult.err(&"WORLD_NOT_READY", "操作失败：建筑根节点不可用")

	var actor: Node = scene.instantiate()
	_building_root.add_child(actor)
	actor.runtime_id = _next_runtime_id
	if actor.has_method("setup_from_cfg"):
		actor.setup_from_cfg(building_id, cfg, cell)

	_buildings_by_runtime_id[_next_runtime_id] = actor
	_buildings_by_cell[cell] = actor
	if _map_manager != null:
		_map_manager.set_building_occupy(cell, true, _next_runtime_id)
	if bool(cfg.get("blocks_path", false)) and _path_service != null:
		_path_service.set_cell_blocked(cell, true)
	if event_bus != null:
		event_bus.building_placed.emit(_next_runtime_id, building_id, cell)
	_refresh_wall_connections_around(cell)
	if _is_path_blocking_cfg(cfg):
		_emit_path_grid_changed()
	var created_runtime_id := _next_runtime_id
	_next_runtime_id += 1
	return ActionResult.ok({"runtime_id": created_runtime_id})


func remove_building_at_cell(cell: Vector2i) -> bool:
	var actor := get_building_by_cell(cell)
	if actor == null:
		return false
	remove_building(int(actor.get_runtime_id()))
	return true


func clear_all_buildings() -> void:
	for runtime_id_variant in _buildings_by_runtime_id.keys().duplicate():
		remove_building(int(runtime_id_variant))


func try_repair_building(building_runtime_id: int) -> Dictionary:
	var check := _validator.can_repair_building(building_runtime_id)
	if not check.get("ok", false):
		return check
	var actor := get_building_by_runtime_id(building_runtime_id)
	if actor == null:
		return ActionResult.err(&"BUILDING_NOT_FOUND", "操作失败：找不到目标建筑")
	if not _is_building_destroyed(actor):
		return ActionResult.err(&"BUILDING_NOT_DESTROYED", "只有完全损毁的建筑需要手动修复")
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "操作失败：运行状态不可用")
	var repair_cost := _get_destroyed_repair_cost(actor)
	var spend_result: Dictionary = run_state.spend_materials(
		int(repair_cost.get("wood", 0)),
		int(repair_cost.get("stone", 0)),
		int(repair_cost.get("mana", 0))
	)
	if not spend_result.get("ok", false):
		return spend_result
	actor.repair_full()
	_refresh_map_layers()
	_refresh_wall_connections_around(actor.get_current_cell())
	if bool(actor.cfg.get("blocks_path", false)) and _path_service != null:
		_path_service.set_cell_blocked(actor.get_current_cell(), true)
	if _is_path_blocking_cfg(actor.cfg):
		_emit_path_grid_changed("路径阻挡更新：修复 %s#%d，通知敌人重新寻路" % [String(actor.cfg.get("name", actor.building_id)), building_runtime_id])
	_debug_log("修复建筑 %s#%d，消耗 木%d 石%d 魔%d" % [
		String(actor.cfg.get("name", actor.building_id)),
		building_runtime_id,
		int(repair_cost.get("wood", 0)),
		int(repair_cost.get("stone", 0)),
		int(repair_cost.get("mana", 0))
	])
	return ActionResult.ok({"runtime_id": building_runtime_id, "cost": repair_cost}, "建筑已修复")


func try_demolish_building(building_runtime_id: int) -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "操作失败：运行状态不可用")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以拆除建筑")
	var actor := get_building_by_runtime_id(building_runtime_id)
	if actor == null:
		return ActionResult.err(&"BUILDING_NOT_FOUND", "操作失败：找不到目标建筑")
	var building_id: StringName = actor.building_id
	var cell: Vector2i = actor.get_current_cell()
	remove_building(building_runtime_id)
	_debug_log("拆除建筑 %s#%d" % [String(building_id), building_runtime_id])
	return ActionResult.ok({"runtime_id": building_runtime_id, "building_id": building_id, "cell": cell}, "建筑已拆除")


func try_toggle_building(building_runtime_id: int) -> Dictionary:
	var actor := get_building_by_runtime_id(building_runtime_id)
	if actor == null:
		return ActionResult.err(&"BUILDING_NOT_FOUND", "操作失败：找不到目标建筑")
	if not actor.has_method("can_toggle_enabled") or not actor.can_toggle_enabled():
		return ActionResult.err(&"BUILDING_NOT_TOGGLEABLE", "无法切换：该建筑不支持开关")
	if _is_building_destroyed(actor):
		return ActionResult.err(&"BUILDING_DESTROYED", "损毁建筑不能切换开关")
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "操作失败：运行状态不可用")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "无法切换：只有白天可以切换建筑")
	var enabled: bool = actor.toggle_enabled()
	if not enabled:
		_clear_building_aura_outline(actor)
	_emit_building_state_changed(actor, enabled)
	return ActionResult.ok({"runtime_id": building_runtime_id, "enabled": enabled})


func damage_building(building_runtime_id: int, value: int, damage_type: int) -> void:
	var actor := get_building_by_runtime_id(building_runtime_id)
	if actor == null:
		return
	var was_destroyed := _is_building_destroyed(actor)
	actor.receive_damage(value, damage_type)
	if not was_destroyed and _is_building_destroyed(actor):
		_mark_building_destroyed(actor)


func remove_building(building_runtime_id: int) -> void:
	var actor := get_building_by_runtime_id(building_runtime_id)
	if actor == null:
		return
	var cell: Vector2i = actor.get_current_cell()
	var cfg: Dictionary = actor.cfg
	var was_destroyed := _is_building_destroyed(actor)
	_clear_building_aura_outline(actor)
	_buildings_by_runtime_id.erase(building_runtime_id)
	_buildings_by_cell.erase(cell)
	if _map_manager != null:
		_map_manager.set_building_occupy(cell, false)
	if bool(cfg.get("blocks_path", false)) and _path_service != null:
		_path_service.set_cell_blocked(cell, false)
	_refresh_wall_connections_around(cell)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		if not was_destroyed:
			event_bus.building_destroyed.emit(building_runtime_id, actor.building_id, cell)
	if _is_path_blocking_cfg(cfg):
		_emit_path_grid_changed("路径阻挡更新：移除 %s#%d，通知敌人重新寻路" % [String(cfg.get("name", actor.building_id)), building_runtime_id])
	actor.queue_free()


func collect_day_income() -> void:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	var income := _get_day_income_delta()
	var gained_wood := int(income.get("wood", 0))
	var gained_stone := int(income.get("stone", 0))
	var gained_mana := int(income.get("mana", 0))
	if gained_wood > 0 or gained_stone > 0 or gained_mana > 0:
		run_state.add_materials(gained_wood, gained_stone, gained_mana)


func get_projected_material_delta_to_next_day() -> Dictionary:
	var delta := _get_day_income_delta()
	var run_state = AppRefs.run_state()
	if run_state != null and int(run_state.phase) == GameEnums.PHASE_DAY:
		var pending_cost := _get_pending_night_material_costs(int(run_state.mana))
		delta["wood"] = int(delta.get("wood", 0)) - int(pending_cost.get("wood", 0))
		delta["stone"] = int(delta.get("stone", 0)) - int(pending_cost.get("stone", 0))
		delta["mana"] = int(delta.get("mana", 0)) - int(pending_cost.get("mana", 0))
	return delta


func refresh_daytime_repair() -> void:
	var repaired_count := 0
	for actor in _get_building_list():
		if actor == null or not is_instance_valid(actor):
			continue
		if _is_building_destroyed(actor):
			continue
		var current_hp := int(actor.get("current_hp"))
		var max_hp := int(actor.get("max_hp"))
		if current_hp <= 0 or current_hp >= max_hp:
			continue
		if actor.has_method("repair_full"):
			actor.repair_full()
			repaired_count += 1
	if repaired_count > 0:
		_debug_log("白天自动修复 %d 个未完全损毁建筑" % repaired_count)


func get_building_by_cell(cell: Vector2i) -> Node:
	return _buildings_by_cell.get(cell)


func get_building_by_runtime_id(building_runtime_id: int) -> Node:
	return _buildings_by_runtime_id.get(building_runtime_id)


func _can_place_building_debug(cell: Vector2i) -> Dictionary:
	if _map_manager == null:
		return ActionResult.err(&"MAP_MANAGER_MISSING", "操作失败：地图管理器不可用")
	if not _map_manager.is_inside(cell):
		return ActionResult.err(&"CELL_OUT_OF_BOUNDS", "无法建造：目标格不在地图内")
	var data: CellData = _map_manager.get_cell_data(cell)
	if data == null:
		return ActionResult.err(&"CELL_MISSING", "操作失败：目标格数据不可用")
	if data.is_core:
		return ActionResult.err(&"CELL_IS_CORE", "无法建造：不能建在核心上")
	if data.spawn_key != StringName():
		return ActionResult.err(&"CELL_IS_SPAWN", "无法建造：不能建在出怪点上")
	if data.is_terrain_blocking() or not data.walkable:
		return ActionResult.err(&"CELL_BLOCKED", "无法建造：目标地形不可建造")
	if data.unit_runtime_id >= 0:
		return ActionResult.err(&"CELL_HAS_UNIT", "无法建造：目标格已有单位")
	if data.building_runtime_id >= 0 or data.occupied:
		return ActionResult.err(&"CELL_HAS_BUILDING", "无法建造：目标格已有建筑")
	return ActionResult.ok()


func _is_building_destroyed(actor: Node) -> bool:
	if actor == null:
		return false
	if actor.has_method("is_destroyed"):
		return bool(actor.is_destroyed())
	var current_hp_variant: Variant = actor.get("current_hp")
	return typeof(current_hp_variant) == TYPE_INT and int(current_hp_variant) <= 0


func _is_path_blocking_cfg(cfg: Dictionary) -> bool:
	return bool(cfg.get("blocks_path", false))


func _emit_path_grid_changed(message: String = "") -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.path_grid_changed.emit()
	if not message.is_empty():
		_debug_log(message)


func _mark_building_destroyed(actor: Node) -> void:
	var cell: Vector2i = actor.get_current_cell()
	var cfg: Dictionary = actor.cfg
	_clear_building_aura_outline(actor)
	if actor.has_method("can_toggle_enabled") and actor.can_toggle_enabled() and actor.has_method("set_enabled"):
		actor.set_enabled(false)
	if bool(cfg.get("blocks_path", false)) and _path_service != null:
		_path_service.set_cell_blocked(cell, false)
	_refresh_map_layers()
	_refresh_wall_connections_around(cell)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.building_destroyed.emit(int(actor.get_runtime_id()), actor.building_id, cell)
		event_bus.building_state_changed.emit(int(actor.get_runtime_id()), actor.building_id, false)
	if _is_path_blocking_cfg(cfg):
		_emit_path_grid_changed("路径阻挡更新：损毁 %s#%d，通知敌人重新寻路" % [String(cfg.get("name", actor.building_id)), int(actor.get_runtime_id())])


func _get_destroyed_repair_cost(actor: Node) -> Dictionary:
	var cfg: Dictionary = actor.cfg if actor != null else {}
	return {
		"wood": _half_repair_cost(int(cfg.get("cost_wood", 0))),
		"stone": _half_repair_cost(int(cfg.get("cost_stone", 0))),
		"mana": _half_repair_cost(int(cfg.get("cost_mana", 0)))
	}


func _half_repair_cost(value: int) -> int:
	if value <= 0:
		return 0
	return int(ceil(float(value) * 0.5))


func _refresh_map_layers() -> void:
	if _map_manager != null and _map_manager.has_method("refresh_all_layers"):
		_map_manager.refresh_all_layers()


func _refresh_wall_connections_around(cell: Vector2i) -> void:
	for offset in WALL_REFRESH_OFFSETS:
		_refresh_wall_connection_at(cell + offset)


func _refresh_wall_connection_at(cell: Vector2i) -> void:
	var actor := get_building_by_cell(cell)
	if not _is_connectable_wall(actor):
		return
	var mask := 0
	if _has_connectable_wall(cell + Vector2i.UP):
		mask |= WALL_NORTH
	if _has_connectable_wall(cell + Vector2i.RIGHT):
		mask |= WALL_EAST
	if _has_connectable_wall(cell + Vector2i.DOWN):
		mask |= WALL_SOUTH
	if _has_connectable_wall(cell + Vector2i.LEFT):
		mask |= WALL_WEST
	if actor.has_method("set_wall_connection_mask"):
		actor.set_wall_connection_mask(mask)


func _has_connectable_wall(cell: Vector2i) -> bool:
	if _map_manager != null and _map_manager.has_method("is_inside") and not _map_manager.is_inside(cell):
		return false
	return _is_connectable_wall(get_building_by_cell(cell))


func _is_connectable_wall(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if _is_building_destroyed(actor):
		return false
	return StringName(actor.get("building_id")) == &"wood_wall"


func _get_income_value(cfg: Dictionary, base_value: int, material: StringName) -> int:
	var run_state = AppRefs.run_state()
	var value := float(base_value)
	if run_state != null:
		if run_state.has_method("get_buff_effect_total_for_building"):
			value *= 1.0 + float(run_state.get_buff_effect_total_for_building(&"building_income_percent", cfg))
		if run_state.has_method("get_buff_effect_total_for_material"):
			value += float(run_state.get_buff_effect_total_for_material(&"building_income_add", material))
	return max(int(round(value)), 0)


func _apply_aura_effects(delta: float) -> void:
	var units: Array = _get_deployed_units()
	var enemies: Array = _get_alive_enemies()
	var unit_interval_multipliers: Dictionary = {}
	var unit_attack_bonuses: Dictionary = {}
	var unit_heal_amounts: Dictionary = {}
	var enemy_speed_multipliers: Dictionary = {}
	var active_aura_outline_ids: Dictionary = {}

	for unit in units:
		if unit == null or not is_instance_valid(unit) or int(unit.current_hp) <= 0:
			continue
		var unit_runtime_id: int = int(unit.get_runtime_id())
		unit_interval_multipliers[unit_runtime_id] = 1.0
		unit_attack_bonuses[unit_runtime_id] = 0
		unit_heal_amounts[unit_runtime_id] = 0.0

	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or int(enemy.current_hp) <= 0:
			continue
		var enemy_runtime_id: int = int(enemy.get_runtime_id())
		enemy_speed_multipliers[enemy_runtime_id] = 1.0

	for actor in _get_building_list():
		if not _is_building_operational(actor):
			continue
		var actor_cfg: Dictionary = actor.cfg
		var effect_type := StringName(actor_cfg.get("effect_type", ""))
		var effect_radius: int = int(actor_cfg.get("effect_radius", 0))
		var effect_value: float = float(actor_cfg.get("effect_value", 0.0))
		var run_state = AppRefs.run_state()
		if run_state != null and run_state.has_method("get_buff_effect_total_for_building"):
			effect_radius += int(round(float(run_state.get_buff_effect_total_for_building(&"building_aura_radius_add", actor_cfg))))
			effect_value *= 1.0 + float(run_state.get_buff_effect_total_for_building(&"building_aura_effect_percent", actor_cfg))
		var building_cell: Vector2i = actor.get_current_cell()
		_sync_building_aura_outline(actor, effect_radius, effect_type, actor_cfg, active_aura_outline_ids)
		match effect_type:
			&"heal":
				for unit in units:
					if unit == null or not is_instance_valid(unit) or int(unit.current_hp) <= 0:
						continue
					if not _is_target_within_building_range(building_cell, unit.get_current_cell(), effect_radius, actor_cfg):
						continue
					var unit_runtime_id: int = int(unit.get_runtime_id())
					unit_heal_amounts[unit_runtime_id] = float(unit_heal_amounts.get(unit_runtime_id, 0.0)) + effect_value * delta
			&"slow":
				var slow_multiplier: float = max(1.0 - effect_value, 0.1)
				for enemy in enemies:
					if enemy == null or not is_instance_valid(enemy) or int(enemy.current_hp) <= 0:
						continue
					if not _is_target_within_building_range(building_cell, enemy.get_current_cell(), effect_radius, actor_cfg):
						continue
					var enemy_runtime_id: int = int(enemy.get_runtime_id())
					enemy_speed_multipliers[enemy_runtime_id] = min(float(enemy_speed_multipliers.get(enemy_runtime_id, 1.0)), slow_multiplier)
			&"attack_interval_reduce":
				var attack_interval_multiplier: float = max(1.0 - effect_value, 0.1)
				for unit in units:
					if unit == null or not is_instance_valid(unit) or int(unit.current_hp) <= 0:
						continue
					if not _is_target_within_building_range(building_cell, unit.get_current_cell(), effect_radius, actor_cfg):
						continue
					var unit_runtime_id: int = int(unit.get_runtime_id())
					unit_interval_multipliers[unit_runtime_id] = min(float(unit_interval_multipliers.get(unit_runtime_id, 1.0)), attack_interval_multiplier)
			&"attack_bonus_flat":
				for unit in units:
					if unit == null or not is_instance_valid(unit) or int(unit.current_hp) <= 0:
						continue
					if not _is_target_within_building_range(building_cell, unit.get_current_cell(), effect_radius, actor_cfg):
						continue
					var unit_runtime_id: int = int(unit.get_runtime_id())
					unit_attack_bonuses[unit_runtime_id] = int(unit_attack_bonuses.get(unit_runtime_id, 0)) + int(effect_value)

	_clear_inactive_building_aura_outlines(active_aura_outline_ids)
	_apply_unit_aura_effects(units, unit_interval_multipliers, unit_attack_bonuses, unit_heal_amounts)
	_apply_enemy_aura_effects(enemies, enemy_speed_multipliers)


func _apply_unit_aura_effects(units: Array, interval_multipliers: Dictionary, attack_bonuses: Dictionary, heal_amounts: Dictionary) -> void:
	var active_runtime_ids: Dictionary = {}
	for unit in units:
		if unit == null or not is_instance_valid(unit) or int(unit.current_hp) <= 0:
			continue
		var unit_runtime_id: int = int(unit.get_runtime_id())
		active_runtime_ids[unit_runtime_id] = true
		if unit.has_method("set_external_attack_interval_multiplier"):
			unit.set_external_attack_interval_multiplier(float(interval_multipliers.get(unit_runtime_id, 1.0)))
		if unit.has_method("set_external_attack_bonus"):
			unit.set_external_attack_bonus(int(attack_bonuses.get(unit_runtime_id, 0)))
		var total_heal: float = float(_unit_heal_remainders.get(unit_runtime_id, 0.0)) + float(heal_amounts.get(unit_runtime_id, 0.0))
		var heal_value: int = int(floor(total_heal))
		_unit_heal_remainders[unit_runtime_id] = total_heal - float(heal_value)
		if heal_value > 0 and unit.has_method("receive_heal"):
			unit.receive_heal(heal_value)
	for runtime_id_variant in _unit_heal_remainders.keys().duplicate():
		var runtime_id: int = int(runtime_id_variant)
		if not active_runtime_ids.has(runtime_id):
			_unit_heal_remainders.erase(runtime_id)


func _apply_enemy_aura_effects(enemies: Array, speed_multipliers: Dictionary) -> void:
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or int(enemy.current_hp) <= 0:
			continue
		var enemy_runtime_id: int = int(enemy.get_runtime_id())
		if enemy.has_method("set_external_move_speed_multiplier"):
			enemy.set_external_move_speed_multiplier(float(speed_multipliers.get(enemy_runtime_id, 1.0)))


func _on_request_build(cell: Vector2i, building_id: StringName) -> void:
	var result := try_place_building(cell, building_id)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.build_action_result.emit(building_id, cell, result)


func _on_request_toggle_building(building_runtime_id: int) -> void:
	try_toggle_building(building_runtime_id)


func _on_day_started(_day: int) -> void:
	collect_day_income()


func _on_night_started(_day: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	for actor in _get_building_list():
		if actor == null or not is_instance_valid(actor):
			continue
		if _is_building_destroyed(actor):
			continue
		if actor.get("building_id") != &"war_shrine":
			continue
		if not actor.has_method("is_enabled") or not actor.is_enabled():
			continue
		var night_cost: int = int(actor.cfg.get("night_mana_cost", 0))
		if night_cost <= 0:
			continue
		var spend_result: Dictionary = run_state.spend_materials(0, 0, night_cost)
		if not spend_result.get("ok", false):
			if actor.has_method("set_enabled"):
				actor.set_enabled(false)
				_emit_building_state_changed(actor, false)


func _get_building_list() -> Array:
	return _buildings_by_runtime_id.values()


func _get_deployed_units() -> Array:
	if _unit_manager == null or not _unit_manager.has_method("get_all_deployed_units"):
		return []
	return _unit_manager.get_all_deployed_units()


func _get_alive_enemies() -> Array:
	if _enemy_manager == null or not _enemy_manager.has_method("get_all_enemies"):
		return []
	return _enemy_manager.get_all_enemies()


func _is_building_operational(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if int(actor.current_hp) <= 0:
		return false
	var effect_type := StringName(actor.cfg.get("effect_type", ""))
	if effect_type == &"none" or effect_type == StringName():
		return false
	if actor.has_method("is_aura_active"):
		return actor.is_aura_active()
	return true


func _get_day_income_delta() -> Dictionary:
	var delta := {
		"wood": 0,
		"stone": 0,
		"mana": 0
	}
	for actor in _get_building_list():
		if not _is_building_operational(actor):
			continue
		var actor_cfg: Dictionary = actor.cfg
		var effect_type := StringName(actor_cfg.get("effect_type", ""))
		var effect_value := int(actor_cfg.get("effect_value", 0))
		match effect_type:
			&"collect_wood":
				delta["wood"] = int(delta.get("wood", 0)) + _get_income_value(actor_cfg, effect_value, &"wood")
			&"collect_stone":
				delta["stone"] = int(delta.get("stone", 0)) + _get_income_value(actor_cfg, effect_value, &"stone")
			&"collect_mana":
				delta["mana"] = int(delta.get("mana", 0)) + _get_income_value(actor_cfg, effect_value, &"mana")
	return delta


func _get_pending_night_material_costs(available_mana: int) -> Dictionary:
	var costs := {
		"wood": 0,
		"stone": 0,
		"mana": 0
	}
	var remaining_mana: int = maxi(available_mana, 0)
	for actor in _get_building_list():
		if actor == null or not is_instance_valid(actor):
			continue
		if _is_building_destroyed(actor):
			continue
		if actor.get("building_id") != &"war_shrine":
			continue
		if not actor.has_method("is_enabled") or not actor.is_enabled():
			continue
		var night_cost: int = int(actor.cfg.get("night_mana_cost", 0))
		if night_cost <= 0:
			continue
		if remaining_mana < night_cost:
			continue
		remaining_mana -= night_cost
		costs["mana"] = int(costs.get("mana", 0)) + night_cost
	return costs


func _is_target_within_building_range(origin: Vector2i, target: Vector2i, radius: int, cfg: Dictionary) -> bool:
	if radius <= 0:
		return origin == target
	var dx: int = abs(origin.x - target.x)
	var dy: int = abs(origin.y - target.y)
	if dx > radius or dy > radius:
		return false
	if StringName(cfg.get("effect_shape", "")) == &"trimmed_square" and dx == radius and dy == radius:
		return false
	return true


func _sync_building_aura_outline(actor: Node, effect_radius: int, effect_type: StringName, cfg: Dictionary, active_outline_ids: Dictionary) -> void:
	if actor == null or not is_instance_valid(actor) or effect_radius <= 0:
		return
	if _map_root == null or not _map_root.has_method("set_range_outline"):
		return
	var outline_id := _building_aura_outline_id(actor)
	active_outline_ids[outline_id] = true
	_map_root.set_range_outline(outline_id, _get_building_aura_cells(actor.get_current_cell(), effect_radius, cfg), {
		"style": _building_aura_outline_style(effect_type),
		"duration": -1.0,
		"draw_nodes": true,
		"edge_length": 74.0,
		"edge_thickness": 26.0,
		"node_size": 26.0
	})


func _clear_inactive_building_aura_outlines(active_outline_ids: Dictionary) -> void:
	if _map_root != null and _map_root.has_method("clear_range_outline"):
		for outline_id in _active_aura_outline_ids.keys().duplicate():
			if not active_outline_ids.has(outline_id):
				_map_root.clear_range_outline(outline_id)
	_active_aura_outline_ids = active_outline_ids.duplicate()


func _clear_building_aura_outline(actor: Node) -> void:
	if actor == null or _map_root == null or not _map_root.has_method("clear_range_outline"):
		return
	var outline_id := _building_aura_outline_id(actor)
	_map_root.clear_range_outline(outline_id)
	_active_aura_outline_ids.erase(outline_id)


func _building_aura_outline_id(actor: Node) -> StringName:
	return StringName("building_aura_%d" % int(actor.get_runtime_id()))


func _building_aura_outline_style(effect_type: StringName) -> StringName:
	return &"gravity" if effect_type == &"slow" else &"building"


func _get_building_aura_cells(center: Vector2i, radius: int, cfg: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _map_manager == null:
		return cells
	var trimmed_square: bool = StringName(cfg.get("effect_shape", "")) == &"trimmed_square"
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if trimmed_square and abs(cell.x - center.x) == radius and abs(cell.y - center.y) == radius:
				continue
			if _map_manager.is_inside(cell) and not cells.has(cell):
				cells.append(cell)
	return cells


func _emit_building_state_changed(actor: Node, enabled: bool) -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null and actor != null:
		event_bus.building_state_changed.emit(int(actor.get_runtime_id()), StringName(actor.building_id), enabled)


func _debug_log(message: String) -> void:
	var tree := get_tree()
	if tree != null:
		tree.call_group("combat_debug_log", "append_combat_debug", message)
