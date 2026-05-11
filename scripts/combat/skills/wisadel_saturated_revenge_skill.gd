extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_interval := 1.0
var _base_attack_multiplier := 1.0


func _on_skill_start() -> void:
	_base_attack_interval = owner_unit.attack_interval
	_base_attack_multiplier = owner_unit.attack_multiplier
	owner_unit.attack_interval = max(_base_attack_interval * float(owner_unit.cfg.get("skill_attack_interval_multiplier", 0.72)), 0.05)
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 1.2))
	_debug_log("技能启动：%s#%d 饱和复仇，多目标过载" % [owner_unit.unit_id, owner_unit.get_runtime_id()])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_interval = _base_attack_interval
	owner_unit.attack_multiplier = _base_attack_multiplier


func get_attack_targets_override() -> Array:
	if owner_unit == null or not is_active():
		return []
	var targets: Array = owner_unit.get_attack_targets()
	targets.shuffle()
	var limit: int = int(owner_unit.cfg.get("skill_overload_target_limit", 4)) if _is_overloaded() else int(owner_unit.cfg.get("skill_target_limit", 3))
	var result: Array = []
	for target in targets:
		if result.size() >= limit:
			break
		result.append(target)
	return result


func modify_attack_damage(base_damage: int, _target: Node) -> int:
	if not is_active():
		return base_damage
	if _is_overloaded():
		return _get_overload_hit_damage(base_damage)
	return base_damage


func after_attack(target: Node, _damage_value: int) -> void:
	if owner_unit == null or not is_active() or not _is_overloaded() or target == null or not is_instance_valid(target):
		return
	var extra_hits := int(owner_unit.cfg.get("skill_overload_extra_hits", 3))
	var extra_damage := _get_overload_hit_damage(owner_unit.get_effective_atk())
	var extra_damage_type: int = owner_unit.damage_type
	_play_overload_gunfire_effect(target)
	for _index in range(extra_hits):
		if not is_instance_valid(target) or int(target.get("current_hp")) <= 0:
			break
		target.receive_damage(extra_damage, extra_damage_type)


func _is_overloaded() -> bool:
	return active_timer > 0.0 and active_timer <= get_duration() * 0.5


func _get_overload_hit_damage(base_damage: int) -> int:
	return max(int(round(float(base_damage) * float(owner_unit.cfg.get("skill_overload_hit_multiplier", 0.65)))), 1)


func _play_overload_gunfire_effect(target: Node) -> void:
	if target == null or not is_instance_valid(target) or not target.has_method("play_follow_effect"):
		return
	target.play_follow_effect(
		"res://assets/effects/operators/wisadel_overload_gunfire_strip.png",
		0.34,
		6,
		6,
		18.0,
		Vector2(116.0, 84.0),
		false,
		Vector2(0.0, -8.0),
		25
	)
