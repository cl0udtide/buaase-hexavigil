extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0
var _base_damage_type := 0


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	_base_damage_type = owner_unit.damage_type
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 1.75))
	owner_unit.damage_type = GameEnums.DAMAGE_MAGIC
	_debug_log("技能启动：%s#%d 殁亡，低血斩杀并转移溢出法伤" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier
	owner_unit.damage_type = _base_damage_type


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
	var execute_threshold: int = max(int(round(float(target.max_hp) * float(owner_unit.cfg.get("skill_execute_hp_percent", 0.18)))), 1)
	if int(target.current_hp) > execute_threshold:
		return
	var remaining_hp := int(target.current_hp)
	if remaining_hp > 0:
		target.receive_damage(remaining_hp, GameEnums.DAMAGE_TRUE)
	var transfer_damage: int = max(int(round(float(max(damage_value, remaining_hp)) * float(owner_unit.cfg.get("skill_overflow_transfer_multiplier", 0.7)))), 1)
	var transfer_target: Node = _find_transfer_target(target)
	if transfer_target != null:
		transfer_target.receive_damage(transfer_damage, GameEnums.DAMAGE_MAGIC)


func _find_transfer_target(excluded: Node) -> Node:
	var best_target: Node = null
	for enemy in owner_unit.get_all_enemies():
		if enemy == null or not is_instance_valid(enemy) or enemy == excluded:
			continue
		if int(enemy.get("current_hp")) <= 0:
			continue
		if best_target == null or _is_target_higher_priority(enemy, best_target):
			best_target = enemy
	return best_target
