extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0
var _base_range_pattern: Array[Vector2i] = []
var _ammo := 0
var _max_ammo := 0
var _killed_during_skill := false


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	_base_range_pattern = owner_unit.range_pattern.duplicate()
	_max_ammo = max(int(owner_unit.cfg.get("skill_ammo", 6)), 0)
	_ammo = _max_ammo
	_killed_during_skill = false
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 2.4))
	owner_unit.range_pattern = owner_unit.parse_range_pattern(owner_unit.cfg.get("skill_range_pattern", owner_unit.cfg.get("range_pattern", [])))
	_show_current_attack_range_outline()
	if owner_unit.has_method("refresh_status_view"):
		owner_unit.refresh_status_view()
	_debug_log("技能启动：%s#%d “得见光芒”，弹药 %d" % [owner_unit.unit_id, owner_unit.get_runtime_id(), _ammo])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier
	owner_unit.range_pattern = _base_range_pattern.duplicate()
	_clear_current_attack_range_outline()
	if _killed_during_skill:
		owner_unit.gain_sp(int(owner_unit.cfg.get("skill_refund_sp_on_kill", 8)))
	_ammo = 0
	_max_ammo = 0
	if owner_unit.has_method("refresh_status_view"):
		owner_unit.refresh_status_view()


func get_ammo_status() -> Dictionary:
	if _max_ammo <= 0 or (not is_active() and _ammo <= 0):
		return {}
	return {
		"current": _ammo,
		"max": _max_ammo,
		"label": "弹药"
	}


func get_attack_projectile_payloads(target: Node, damage_value: int) -> Array:
	if owner_unit == null or not is_active() or target == null or not is_instance_valid(target):
		return []
	return [{
		"damage": damage_value,
		"damage_type": owner_unit.damage_type,
		"texture_path": "res://assets/effects/projectiles/ray_bind_shot_projectile.png",
		"visual_length": 82.0,
		"visual_height": 28.0,
		"speed": float(owner_unit.cfg.get("projectile_speed", 620.0)),
		"hit_radius": float(owner_unit.cfg.get("projectile_hit_radius", 7.0)),
		"trigger_after_attack": true
	}]


func after_attack(target: Node, _damage_value: int) -> void:
	if owner_unit == null or not is_active():
		return
	if target != null and is_instance_valid(target):
		if target.has_method("apply_bind"):
			target.apply_bind(float(owner_unit.cfg.get("skill_bind_duration", 1.5)))
			_play_bind_tether_effect(target)
		if int(target.get("current_hp")) <= 0:
			_killed_during_skill = true
	_ammo -= 1
	if _ammo <= 0:
		end_skill()
	elif owner_unit.has_method("refresh_status_view"):
		owner_unit.refresh_status_view()


func _play_bind_tether_effect(target: Node) -> void:
	if owner_unit == null or not owner_unit.has_method("spawn_world_effect"):
		return
	if not (owner_unit is Node2D) or not (target is Node2D):
		return
	var start_position := (owner_unit as Node2D).global_position
	var end_position := (target as Node2D).global_position
	var delta := end_position - start_position
	if delta.length_squared() <= 0.001:
		return
	owner_unit.spawn_world_effect(
		"res://assets/effects/operators/ray_bind_tether_strip.png",
		(start_position + end_position) * 0.5,
		0.45,
		6,
		6,
		16.0,
		Vector2(max(delta.length(), 96.0), 58.0),
		delta.angle(),
		false,
		25
	)
