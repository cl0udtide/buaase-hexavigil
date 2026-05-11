extends "res://scripts/combat/skills/unit_skill_behavior.gd"


func modify_attack_damage(base_damage: int, _target: Node) -> int:
	if not is_active():
		return base_damage
	return _segment_damage(base_damage)


func get_attack_projectile_payloads(target: Node, damage_value: int) -> Array:
	var payloads: Array[Dictionary] = []
	if owner_unit == null or not is_active() or target == null or not is_instance_valid(target):
		return payloads
	var hit_count: int = int(owner_unit.cfg.get("skill_hit_count", 5))
	hit_count = max(hit_count, 1)
	var owner_position: Vector2 = (owner_unit as Node2D).global_position if owner_unit is Node2D else Vector2.ZERO
	var target_position: Vector2 = (target as Node2D).global_position if target is Node2D else owner_position
	var facing_vec: Vector2 = Vector2(owner_unit.facing)
	if facing_vec.length_squared() <= 0.001:
		facing_vec = (target_position - owner_position).normalized()
	if facing_vec.length_squared() <= 0.001:
		facing_vec = Vector2.RIGHT
	else:
		facing_vec = facing_vec.normalized()
	var side_vec: Vector2 = Vector2(-facing_vec.y, facing_vec.x)
	var origin: Vector2 = owner_position + facing_vec * 18.0
	_play_volley_tracer(origin, target_position)
	var spread: float = 7.0
	var base_speed: float = float(owner_unit.cfg.get("projectile_speed", 520.0))
	var base_hit_radius: float = float(owner_unit.cfg.get("projectile_hit_radius", 8.0))
	for index in range(hit_count):
		var centered: float = float(index) - float(hit_count - 1) * 0.5
		payloads.append({
			"damage": damage_value,
			"damage_type": owner_unit.damage_type,
			"trigger_after_attack": false,
			"origin": origin + side_vec * centered * spread - facing_vec * abs(centered) * 3.0,
			"speed": base_speed * (1.0 + centered * 0.025),
			"hit_radius": base_hit_radius,
			"color": Color(1.0, 0.9 - min(abs(centered) * 0.06, 0.18), 0.36, 0.98)
		})
	return payloads


func after_attack(target: Node, damage_value: int) -> void:
	if owner_unit == null or not is_active() or target == null or not is_instance_valid(target):
		return
	var hit_count: int = int(owner_unit.cfg.get("skill_hit_count", 5))
	for _index in range(max(hit_count - 1, 0)):
		if target == null or not is_instance_valid(target) or int(target.current_hp) <= 0:
			break
		target.receive_damage(damage_value, owner_unit.damage_type)
	_debug_log("技能连击：%s#%d 对 %s#%d 造成 %d 段 %.0f%% 攻击力伤害" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		target.enemy_id,
		target.get_runtime_id(),
		hit_count,
		float(owner_unit.cfg.get("skill_hit_multiplier", 0.7)) * 100.0
	])


func _segment_damage(base_damage: int) -> int:
	return max(int(round(float(base_damage) * float(owner_unit.cfg.get("skill_hit_multiplier", 0.7)))), 1)


func _play_volley_tracer(start_position: Vector2, end_position: Vector2) -> void:
	if owner_unit == null or not owner_unit.has_method("spawn_world_effect"):
		return
	var delta := end_position - start_position
	if delta.length_squared() <= 0.001:
		return
	owner_unit.spawn_world_effect(
		"res://assets/effects/operators/exusiai_volley_tracer_strip.png",
		(start_position + end_position) * 0.5,
		0.28,
		6,
		6,
		20.0,
		Vector2(max(delta.length(), 96.0), 54.0),
		delta.angle(),
		false,
		25
	)
