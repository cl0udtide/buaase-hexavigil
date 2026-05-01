extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 1.35))
	_debug_log("技能启动：%s#%d 心防溃决，攻击积累凋亡损伤" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier


func get_attack_targets_override() -> Array:
	if owner_unit == null or not is_active():
		return []
	var targets: Array = _sort_targets_by_priority(owner_unit.get_attack_targets())
	var result: Array = []
	var limit: int = int(owner_unit.cfg.get("skill_target_limit", 2))
	for target in targets:
		if result.size() >= limit:
			break
		result.append(target)
	return result


func after_attack(target: Node, damage_value: int) -> void:
	if owner_unit == null or not is_active() or target == null or not is_instance_valid(target):
		return
	if target.has_method("apply_necrosis"):
		target.apply_necrosis(
			&"nymph_psychic_collapse",
			float(owner_unit.cfg.get("skill_necrosis_amount", 42.0)),
			float(owner_unit.cfg.get("skill_necrosis_duration", 6.0)),
			float(owner_unit.cfg.get("skill_necrosis_vulnerability", 0.25)),
			float(owner_unit.cfg.get("skill_necrosis_dot_per_sec", 8.0))
		)
	if target.has_method("is_necrosis_bursting") and target.is_necrosis_bursting():
		target.receive_damage(max(int(round(float(damage_value) * float(owner_unit.cfg.get("skill_burst_bonus_multiplier", 0.55)))), 1), GameEnums.DAMAGE_MAGIC)
