extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

var _next_runtime_id := 1
var _buildings_by_runtime_id: Dictionary = {}
var _buildings_by_cell: Dictionary = {}
var _validator := BuildValidator.new()
var _unit_heal_remainders: Dictionary = {}

@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _path_service: Node = get_node_or_null("../PathService")
@onready var _unit_manager: Node = get_node_or_null("../UnitManager")
@onready var _enemy_manager: Node = get_node_or_null("../EnemyManager")
@onready var _building_root: Node = get_node_or_null("../../World/BuildingRoot")


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
	var check := _validator.can_place_building(cell, building_id)
	if not check.get("ok", false):
		return check

	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if data_repo == null or run_state == null:
		return ActionResult.err(&"APP_REFS_MISSING", "App refs are unavailable")
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
		return ActionResult.err(&"SCENE_MISSING", "Building scene is missing")
	if _building_root == null:
		run_state.add_materials(int(cfg.get("cost_wood", 0)), int(cfg.get("cost_stone", 0)), int(cfg.get("cost_mana", 0)))
		run_state.reset_action_points(run_state.action_points + int(cfg.get("ap_cost", 0)))
		return ActionResult.err(&"WORLD_NOT_READY", "BuildingRoot is missing")

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
	if _is_path_blocking_cfg(cfg):
		_emit_path_grid_changed("路径阻挡更新：放置 %s#%d，通知敌人重新寻路" % [String(cfg.get("name", building_id)), _next_runtime_id])
	var created_runtime_id := _next_runtime_id
	_next_runtime_id += 1
	return ActionResult.ok({"runtime_id": created_runtime_id})


func try_repair_building(building_runtime_id: int) -> Dictionary:
	var check := _validator.can_repair_building(building_runtime_id)
	if not check.get("ok", false):
		return check
	var actor := get_building_by_runtime_id(building_runtime_id)
	if actor == null:
		return ActionResult.err(&"BUILDING_NOT_FOUND", "Building instance was not found")
	if not _is_building_destroyed(actor):
		return ActionResult.err(&"BUILDING_NOT_DESTROYED", "只有完全损毁的建筑需要手动修复")
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState is unavailable")
	var repair_cost := _get_destroyed_repair_cost(actor)
	var spend_result: Dictionary = run_state.spend_materials(
		int(repair_cost.get("wood", 0)),
		int(repair_cost.get("stone", 0)),
		int(repair_cost.get("mana", 0))
	)
	if not spend_result.get("ok", false):
		return spend_result
	actor.repair_full()
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
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState is unavailable")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以拆除建筑")
	var actor := get_building_by_runtime_id(building_runtime_id)
	if actor == null:
		return ActionResult.err(&"BUILDING_NOT_FOUND", "Building instance was not found")
	var building_id: StringName = actor.building_id
	var cell: Vector2i = actor.get_current_cell()
	remove_building(building_runtime_id)
	_debug_log("拆除建筑 %s#%d" % [String(building_id), building_runtime_id])
	return ActionResult.ok({"runtime_id": building_runtime_id, "building_id": building_id, "cell": cell}, "建筑已拆除")


func try_toggle_building(building_runtime_id: int) -> Dictionary:
	var actor := get_building_by_runtime_id(building_runtime_id)
	if actor == null:
		return ActionResult.err(&"BUILDING_NOT_FOUND", "Building instance was not found")
	if not actor.has_method("can_toggle_enabled") or not actor.can_toggle_enabled():
		return ActionResult.err(&"BUILDING_NOT_TOGGLEABLE", "This building cannot be toggled")
	if _is_building_destroyed(actor):
		return ActionResult.err(&"BUILDING_DESTROYED", "损毁建筑不能切换开关")
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState is unavailable")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "Buildings can only be toggled during the day")
	var enabled: bool = actor.toggle_enabled()
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
	_buildings_by_runtime_id.erase(building_runtime_id)
	_buildings_by_cell.erase(cell)
	if _map_manager != null:
		_map_manager.set_building_occupy(cell, false)
	if bool(cfg.get("blocks_path", false)) and _path_service != null:
		_path_service.set_cell_blocked(cell, false)
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
	var gained_wood := 0
	var gained_stone := 0
	var gained_mana := 0
	for actor in _get_building_list():
		if not _is_building_operational(actor):
			continue
		var actor_cfg: Dictionary = actor.cfg
		var effect_type := StringName(actor_cfg.get("effect_type", ""))
		var effect_value := int(actor_cfg.get("effect_value", 0))
		match effect_type:
			&"collect_wood":
				gained_wood += effect_value
			&"collect_stone":
				gained_stone += effect_value
			&"collect_mana":
				gained_mana += effect_value
	if gained_wood > 0 or gained_stone > 0 or gained_mana > 0:
		run_state.add_materials(gained_wood, gained_stone, gained_mana)


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
	if actor.has_method("can_toggle_enabled") and actor.can_toggle_enabled() and actor.has_method("set_enabled"):
		actor.set_enabled(false)
	if bool(cfg.get("blocks_path", false)) and _path_service != null:
		_path_service.set_cell_blocked(cell, false)
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


func _apply_aura_effects(delta: float) -> void:
	var units: Array = _get_deployed_units()
	var enemies: Array = _get_alive_enemies()
	var unit_interval_multipliers: Dictionary = {}
	var unit_attack_bonuses: Dictionary = {}
	var unit_heal_amounts: Dictionary = {}
	var enemy_speed_multipliers: Dictionary = {}

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
		var building_cell: Vector2i = actor.get_current_cell()
		match effect_type:
			&"heal":
				for unit in units:
					if unit == null or not is_instance_valid(unit) or int(unit.current_hp) <= 0:
						continue
					if not _is_target_within_square_range(building_cell, unit.get_current_cell(), effect_radius):
						continue
					var unit_runtime_id: int = int(unit.get_runtime_id())
					unit_heal_amounts[unit_runtime_id] = float(unit_heal_amounts.get(unit_runtime_id, 0.0)) + effect_value * delta
			&"slow":
				var slow_multiplier: float = max(1.0 - effect_value, 0.1)
				for enemy in enemies:
					if enemy == null or not is_instance_valid(enemy) or int(enemy.current_hp) <= 0:
						continue
					if not _is_target_within_square_range(building_cell, enemy.get_current_cell(), effect_radius):
						continue
					var enemy_runtime_id: int = int(enemy.get_runtime_id())
					enemy_speed_multipliers[enemy_runtime_id] = min(float(enemy_speed_multipliers.get(enemy_runtime_id, 1.0)), slow_multiplier)
			&"attack_interval_reduce":
				var attack_interval_multiplier: float = max(1.0 - effect_value, 0.1)
				for unit in units:
					if unit == null or not is_instance_valid(unit) or int(unit.current_hp) <= 0:
						continue
					if not _is_target_within_square_range(building_cell, unit.get_current_cell(), effect_radius):
						continue
					var unit_runtime_id: int = int(unit.get_runtime_id())
					unit_interval_multipliers[unit_runtime_id] = min(float(unit_interval_multipliers.get(unit_runtime_id, 1.0)), attack_interval_multiplier)
			&"attack_bonus_flat":
				for unit in units:
					if unit == null or not is_instance_valid(unit) or int(unit.current_hp) <= 0:
						continue
					if not _is_target_within_square_range(building_cell, unit.get_current_cell(), effect_radius):
						continue
					var unit_runtime_id: int = int(unit.get_runtime_id())
					unit_attack_bonuses[unit_runtime_id] = int(unit_attack_bonuses.get(unit_runtime_id, 0)) + int(effect_value)

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


func _is_target_within_square_range(origin: Vector2i, target: Vector2i, range_size: int) -> bool:
	if range_size <= 0:
		return origin == target
	return abs(origin.x - target.x) <= range_size and abs(origin.y - target.y) <= range_size


func _emit_building_state_changed(actor: Node, enabled: bool) -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null and actor != null:
		event_bus.building_state_changed.emit(int(actor.get_runtime_id()), StringName(actor.building_id), enabled)


func _debug_log(message: String) -> void:
	var tree := get_tree()
	if tree != null:
		tree.call_group("combat_debug_log", "append_combat_debug", message)
