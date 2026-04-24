extends "res://scripts/combat/skills/unit_skill_behavior.gd"


func modify_attack_damage(base_damage: int, _target: Node) -> int:
	if not is_active():
		return base_damage
	return _segment_damage(base_damage)


func after_attack(target: Node, damage_value: int) -> void:
	if owner_unit == null or not is_active() or target == null or not is_instance_valid(target):
		return
	var hit_count := int(owner_unit.cfg.get("skill_hit_count", 5))
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
