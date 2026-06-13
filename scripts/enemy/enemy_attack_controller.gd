extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const RANGED_ATTACK_HOLD_SECONDS := 1.0
const DEFAULT_PROJECTILE_SPEED := 460.0
const DEFAULT_PROJECTILE_HIT_RADIUS := 8.0
const DEFAULT_PROJECTILE_LIFETIME := 3.0
const DEMOLISHER_HIT_EFFECT_SIZE := Vector2(128.0, 104.0)
const SFX_PROJECTILE_PHYSICAL := &"projectile_physical"
const SFX_PROJECTILE_ARTS := &"projectile_arts"

var _owner_actor: Node2D = null
var _attack_timer := 0.0
var _range_attack_hold_timer := 0.0


func setup(owner_actor: Node2D) -> void:
	_owner_actor = owner_actor
	_attack_timer = 0.0
	_range_attack_hold_timer = 0.0


func reset_attack_timer() -> void:
	_attack_timer = 0.0
	_range_attack_hold_timer = 0.0


func set_attack_cooldown_from_cfg() -> void:
	var base_interval := float(_owner_actor.cfg.get("attack_interval", 1.0))
	_attack_timer = CombatMath.calc_attack_interval(base_interval, _owner_actor.get_effective_attack_speed())


func get_attack_range_tiles() -> int:
	return int(_owner_actor.cfg.get("attack_range", 0)) if _owner_actor != null else 0


func process_blocked_attack(delta: float, blocker: Node) -> void:
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return
	var damage_type: int = _parse_damage_type(String(_owner_actor.cfg.get("damage_type", "physical")))
	var damage_value: int = int(_owner_actor.cfg.get("atk", 1))
	_debug_log("敌人 %s#%d 攻击阻挡单位 %s#%d，%s伤害 %d" % [_debug_name(), _runtime_id(), blocker.unit_id, blocker.get_runtime_id(), _damage_type_text(damage_type), damage_value])
	_play_owner_attack_lunge()
	_play_melee_hit_effect(blocker)
	blocker.receive_damage(damage_value, damage_type, _owner_actor)
	_apply_attack_splash(blocker)
	set_attack_cooldown_from_cfg()


func process_building_attack(delta: float, building: Node) -> void:
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return
	var building_manager: Node = _get_building_manager()
	if building_manager == null or not building_manager.has_method("damage_building"):
		return
	var damage_type: int = _parse_damage_type(String(_owner_actor.cfg.get("damage_type", "physical")))
	var damage_value: int = int(_owner_actor.cfg.get("atk", 1))
	_debug_log("敌人 %s#%d 攻击路径建筑 %s，%s伤害 %d" % [_debug_name(), _runtime_id(), _target_debug_name(building), _damage_type_text(damage_type), damage_value])
	_play_owner_attack_lunge()
	_play_building_hit_effect(building)
	_damage_building(building, damage_value, damage_type)
	set_attack_cooldown_from_cfg()


func process_range_attack(delta: float) -> bool:
	var attack_range: int = get_attack_range_tiles()
	if attack_range <= 0:
		return false
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _range_attack_hold_timer > 0.0:
		_range_attack_hold_timer = max(_range_attack_hold_timer - delta, 0.0)
		return true
	if _attack_timer > 0.0:
		return false
	var target: Node = _find_attack_target_in_range(attack_range)
	if target == null:
		return false
	var damage_type: int = _parse_damage_type(String(_owner_actor.cfg.get("damage_type", "physical")))
	var damage_value: int = int(_owner_actor.cfg.get("atk", 1))
	_debug_log("敌人 %s#%d 远程攻击 %s，%s伤害 %d" % [_debug_name(), _runtime_id(), _target_debug_name(target), _damage_type_text(damage_type), damage_value])
	_play_owner_attack_lunge()
	if _uses_projectile_range_attack():
		var projectile := _launch_projectile(target, damage_value, damage_type)
		if projectile != null:
			set_attack_cooldown_from_cfg()
			_start_range_attack_hold(attack_range)
			return true
	_resolve_range_hit(target, damage_value, damage_type)
	set_attack_cooldown_from_cfg()
	_start_range_attack_hold(attack_range)
	return true


func _start_range_attack_hold(attack_range: int) -> void:
	if attack_range > 1:
		_range_attack_hold_timer = min(RANGED_ATTACK_HOLD_SECONDS, _attack_timer)


func get_blocking_building_on_path(movement_controller: Node) -> Node:
	if movement_controller == null or movement_controller.get_path_mode() == &"flying" or not movement_controller.has_path() or movement_controller.has_arrived():
		return null
	var building_manager: Node = _get_building_manager()
	if building_manager == null or not building_manager.has_method("get_building_by_cell"):
		return null
	var next_cell: Vector2i = movement_controller.get_next_path_cell()
	var building: Node = building_manager.get_building_by_cell(next_cell)
	if building == null or not is_instance_valid(building):
		return null
	if _is_destroyed_building(building):
		return null
	if not _should_attack_path_building(building, movement_controller):
		return null
	return building


func _find_attack_target_in_range(attack_range: int) -> Node:
	var unit_manager: Node = _get_unit_manager()
	var building_manager: Node = _get_building_manager()
	var best_target: Node = null
	var best_distance: int = 999999
	var current_cell: Vector2i = _owner_actor.get_current_cell()
	for y in range(current_cell.y - attack_range, current_cell.y + attack_range + 1):
		for x in range(current_cell.x - attack_range, current_cell.x + attack_range + 1):
			var cell: Vector2i = Vector2i(x, y)
			var distance: int = max(abs(cell.x - current_cell.x), abs(cell.y - current_cell.y))
			if distance > attack_range or distance >= best_distance:
				continue
			var unit: Node = null
			if unit_manager != null and unit_manager.has_method("get_unit_by_cell"):
				unit = unit_manager.get_unit_by_cell(cell)
			if unit != null and is_instance_valid(unit):
				best_target = unit
				best_distance = distance
				continue
			var building: Node = null
			if building_manager != null and building_manager.has_method("get_building_by_cell"):
				building = building_manager.get_building_by_cell(cell)
			if building != null and is_instance_valid(building) and not _is_destroyed_building(building):
				best_target = building
				best_distance = distance
	return best_target


func _damage_building(building: Node, damage_value: int, damage_type: int) -> void:
	var building_manager: Node = _get_building_manager()
	if building_manager != null and building_manager.has_method("damage_building"):
		building_manager.damage_building(int(building.get("runtime_id")), damage_value, damage_type)
	elif building != null and building.has_method("receive_damage"):
		building.receive_damage(damage_value, damage_type)


func _resolve_range_hit(target: Node, damage_value: int, damage_type: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.is_in_group("units") and target.has_method("receive_damage"):
		target.receive_damage(damage_value, damage_type, _owner_actor)
	elif target.is_in_group("buildings"):
		_damage_building(target, damage_value, damage_type)
	elif target.has_method("receive_damage"):
		target.receive_damage(damage_value, damage_type)
	_apply_attack_splash(target)


## 攻击范围溅射（凑凑企鹅 Stellar Corona 风味）：普攻额外对自身半径内其它单位造成法术伤害。
func _apply_attack_splash(primary_target: Node) -> void:
	var radius := int(_owner_actor.cfg.get("attack_splash_radius", 0))
	if radius <= 0:
		return
	var splash_damage := int(_owner_actor.cfg.get("atk", 1))
	if splash_damage <= 0:
		return
	var splash_type := _parse_damage_type(String(_owner_actor.cfg.get("attack_splash_damage_type", "magic")))
	var unit_manager: Node = _get_unit_manager()
	if unit_manager == null or not unit_manager.has_method("get_unit_by_cell"):
		return
	var center: Vector2i = _owner_actor.get_current_cell()
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var unit: Node = unit_manager.get_unit_by_cell(Vector2i(x, y))
			if unit != null and unit != primary_target and is_instance_valid(unit) and unit.has_method("receive_damage"):
				unit.receive_damage(splash_damage, splash_type, _owner_actor)
	var fx := String(_owner_actor.cfg.get("attack_splash_effect", ""))
	if not fx.is_empty() and _owner_actor.has_method("spawn_world_effect"):
		var diameter := float(radius * 2 + 1) * 64.0
		_owner_actor.spawn_world_effect(fx, _owner_actor.global_position, 0.5, 6, 6, 18.0, Vector2(diameter, diameter), 0.0, false, 23)


func _uses_projectile_range_attack() -> bool:
	return _owner_actor != null and StringName(_owner_actor.cfg.get("attack_delivery", "instant")) == &"projectile"


func _launch_projectile(target: Node, damage_value: int, damage_type: int) -> Node:
	if target == null or not is_instance_valid(target):
		return null
	var projectile_root := _get_projectile_root()
	if projectile_root == null:
		return null
	var scene_key := StringName(_owner_actor.cfg.get("projectile_scene_key", "projectile"))
	var data_repo = AppRefs.data_repo()
	var projectile_scene: PackedScene = data_repo.get_scene_by_key(scene_key) if data_repo != null else null
	if projectile_scene == null:
		return null
	var projectile := projectile_scene.instantiate()
	projectile_root.add_child(projectile)
	var projectile_payload := {
		"source": _owner_actor,
		"target": target,
		"origin": _get_projectile_origin(target),
		"speed": float(_owner_actor.cfg.get("projectile_speed", DEFAULT_PROJECTILE_SPEED)),
		"hit_radius": float(_owner_actor.cfg.get("projectile_hit_radius", DEFAULT_PROJECTILE_HIT_RADIUS)),
		"max_lifetime": float(_owner_actor.cfg.get("projectile_lifetime", DEFAULT_PROJECTILE_LIFETIME)),
		"damage": damage_value,
		"damage_type": damage_type
	}
	_copy_projectile_visual_config(projectile_payload)
	var projectile_color: Variant = _parse_projectile_color(_owner_actor.cfg.get("projectile_color", null))
	if projectile_color is Color:
		projectile_payload["color"] = projectile_color
	if projectile.has_signal("hit"):
		projectile.hit.connect(_on_projectile_hit)
	if projectile.has_method("setup"):
		projectile.setup(projectile_payload)
	elif projectile is Node2D:
		(projectile as Node2D).global_position = projectile_payload["origin"]
	_request_audio_cue(_projectile_sfx_for_damage_type(damage_type))
	return projectile


func _on_projectile_hit(_projectile: Node, target: Node, projectile_payload: Dictionary) -> void:
	if _owner_actor == null or not is_instance_valid(_owner_actor):
		return
	if int(_owner_actor.get("current_hp")) <= 0:
		return
	_resolve_range_hit(
		target,
		int(projectile_payload.get("damage", int(_owner_actor.cfg.get("atk", 1)))),
		int(projectile_payload.get("damage_type", _parse_damage_type(String(_owner_actor.cfg.get("damage_type", "physical")))))
	)


func _get_projectile_root() -> Node:
	return _owner_actor.get_node_or_null("../../ProjectileRoot") if _owner_actor != null else null


func _get_projectile_origin(target: Node) -> Vector2:
	var origin := _owner_actor.global_position
	var direction := Vector2.ZERO
	if target is Node2D:
		direction = (target as Node2D).global_position - origin
	if direction.length_squared() <= 0.001:
		direction = Vector2(_owner_actor.facing)
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	return origin + direction.normalized() * 18.0


func _copy_projectile_visual_config(projectile_payload: Dictionary) -> void:
	for key in [
		"projectile_texture_path",
		"texture_path",
		"projectile_visual_length",
		"projectile_visual_height",
		"visual_length",
		"visual_height",
		"impact_texture_path",
		"impact_hframes",
		"impact_frame_count",
		"impact_fps"
	]:
		if not projectile_payload.has(key) and _owner_actor.cfg.has(key):
			projectile_payload[key] = _owner_actor.cfg[key]


func _should_attack_path_building(building: Node, movement_controller: Node) -> bool:
	if _is_destroyed_building(building):
		return false
	var path_mode: StringName = movement_controller.get_path_mode() if movement_controller != null else &"normal"
	if path_mode == &"demolisher":
		return true
	if path_mode != &"normal":
		return false
	return not _is_wall_building(building)


func _is_destroyed_building(building: Node) -> bool:
	if building == null:
		return false
	if building.has_method("is_destroyed"):
		return bool(building.is_destroyed())
	var current_hp_variant: Variant = building.get("current_hp")
	return current_hp_variant != null and int(current_hp_variant) <= 0


func _is_wall_building(building: Node) -> bool:
	if building == null:
		return false
	if StringName(building.get("building_id")) == &"wood_wall":
		return true
	var cfg_variant: Variant = building.get("cfg")
	if typeof(cfg_variant) != TYPE_DICTIONARY:
		return false
	var building_cfg: Dictionary = cfg_variant
	return bool(building_cfg.get("blocks_path", false))


func _play_owner_attack_lunge() -> void:
	if _owner_actor != null and _owner_actor.has_method("play_attack_lunge"):
		_owner_actor.play_attack_lunge()


func _play_building_hit_effect(building: Node) -> void:
	if _owner_actor == null or not _owner_actor.has_method("spawn_world_effect"):
		return
	if StringName(_owner_actor.cfg.get("behavior_type", "normal")) != &"demolisher":
		return
	var effect_position := _owner_actor.global_position
	if building is Node2D:
		effect_position = (building as Node2D).global_position
	_owner_actor.spawn_world_effect(
		"res://assets/effects/enemies/demolisher_heavy_hit_strip.png",
		effect_position,
		0.36,
		6,
		6,
		18.0,
		DEMOLISHER_HIT_EFFECT_SIZE,
		0.0,
		false,
		25
	)


func _play_melee_hit_effect(target: Node) -> void:
	if target == null or not is_instance_valid(target) or not target.has_method("play_follow_effect"):
		return
	if not _should_play_heavy_melee_effect():
		return
	target.play_follow_effect(
		"res://assets/effects/enemies/enemy_melee_heavy_hit_strip.png",
		0.34,
		6,
		6,
		18.0,
		Vector2(118.0, 118.0),
		false,
		Vector2(0.0, -8.0),
		25
	)


func _should_play_heavy_melee_effect() -> bool:
	if _owner_actor == null:
		return false
	var behavior_type := StringName(_owner_actor.cfg.get("behavior_type", "normal"))
	if behavior_type == &"boss" or behavior_type == &"demolisher":
		return true
	return int(_owner_actor.cfg.get("atk", 0)) >= 60 or int(_owner_actor.cfg.get("block_weight", 1)) >= 2


func _parse_damage_type(raw_type: String) -> int:
	match raw_type:
		"magic":
			return GameEnums.DAMAGE_MAGIC
		"true":
			return GameEnums.DAMAGE_TRUE
		_:
			return GameEnums.DAMAGE_PHYSICAL


func _parse_projectile_color(raw_color: Variant) -> Variant:
	if raw_color is Color:
		return raw_color
	if typeof(raw_color) == TYPE_ARRAY:
		var color_values := raw_color as Array
		if color_values.size() >= 3:
			var alpha := float(color_values[3]) if color_values.size() >= 4 else 1.0
			return Color(float(color_values[0]), float(color_values[1]), float(color_values[2]), alpha)
	return null


func _damage_type_text(type_value: int) -> String:
	match type_value:
		GameEnums.DAMAGE_MAGIC:
			return "法术"
		GameEnums.DAMAGE_TRUE:
			return "真实"
		_:
			return "物理"


func _projectile_sfx_for_damage_type(damage_type_value: int) -> StringName:
	return SFX_PROJECTILE_ARTS if damage_type_value == GameEnums.DAMAGE_MAGIC else SFX_PROJECTILE_PHYSICAL


func _request_audio_cue(cue_key: StringName) -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.audio_cue_requested.emit(cue_key)


func _target_debug_name(target: Node) -> String:
	if target == null:
		return "未知目标"
	if target.is_in_group("units"):
		return "单位 %s#%d" % [String(target.get("unit_id")), int(target.get("runtime_id"))]
	if target.is_in_group("buildings"):
		return "建筑 %s#%d" % [String(target.get("building_id")), int(target.get("runtime_id"))]
	return String(target.name)


func _get_unit_manager() -> Node:
	return _owner_actor.get_unit_manager() if _owner_actor != null else null


func _get_building_manager() -> Node:
	return _owner_actor.get_building_manager() if _owner_actor != null else null


func _debug_log(message: String) -> void:
	if _owner_actor != null and _owner_actor.has_method("_debug_log"):
		_owner_actor._debug_log(message)


func _debug_name() -> String:
	if _owner_actor == null:
		return "未知敌人"
	return String(_owner_actor.cfg.get("name", _owner_actor.enemy_id))


func _runtime_id() -> int:
	return int(_owner_actor.get_runtime_id()) if _owner_actor != null else -1
