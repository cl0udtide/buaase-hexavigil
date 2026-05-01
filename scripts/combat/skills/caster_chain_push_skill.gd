extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_interval := 1.0
var _base_attack_multiplier := 1.0


func _on_skill_start() -> void:
	_base_attack_interval = owner_unit.attack_interval
	_base_attack_multiplier = owner_unit.attack_multiplier
	owner_unit.attack_interval = max(_base_attack_interval * float(owner_unit.cfg.get("skill_attack_interval_multiplier", 2.2)), 0.05)
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_attack_multiplier", 2.4))
	_debug_log("技能启动：%s#%d 链式冲击，攻击间隔 %.1f，攻击倍率 %.2f，持续 %.1f 秒" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		owner_unit.attack_interval,
		owner_unit.attack_multiplier,
		get_duration()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_interval = _base_attack_interval
	owner_unit.attack_multiplier = _base_attack_multiplier
	_debug_log("技能结束：%s#%d 链式冲击结束" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func after_attack(target: Node, damage_value: int) -> void:
	if owner_unit == null or not is_active() or target == null or not is_instance_valid(target):
		return
	var hit_targets: Array = [target]
	_push_if_active(target)
	var current: Node = target
	var chain_count := int(owner_unit.cfg.get("chain_count", 3))
	var chain_range := int(owner_unit.cfg.get("chain_range", 3))
	var decay := float(owner_unit.cfg.get("chain_damage_decay", 0.15))
	for chain_index in range(chain_count):
		var next_target: Node = _find_next_chain_target(current, hit_targets, chain_range)
		if next_target == null:
			break
		hit_targets.append(next_target)
		var chain_damage: int = max(int(round(float(damage_value) * max(1.0 - decay * float(chain_index + 1), 0.1))), 1)
		next_target.receive_damage(chain_damage, owner_unit.damage_type)
		_push_if_active(next_target)
		current = next_target
	if hit_targets.size() > 1:
		_debug_log("链法：%s#%d 连锁命中 %d 个敌人" % [
			owner_unit.unit_id,
			owner_unit.get_runtime_id(),
			hit_targets.size()
		])


func _find_next_chain_target(from_target: Node, used_targets: Array, chain_range: int) -> Node:
	var best_target: Node = null
	var best_dist := 0
	for enemy in owner_unit.get_all_enemies():
		if enemy == null or not is_instance_valid(enemy) or used_targets.has(enemy) or int(enemy.current_hp) <= 0:
			continue
		var dist: int = enemy.get_current_cell().distance_squared_to(from_target.get_current_cell())
		if dist > chain_range * chain_range:
			continue
		if best_target == null or dist < best_dist or (dist == best_dist and enemy.get_runtime_id() < best_target.get_runtime_id()):
			best_target = enemy
			best_dist = dist
	return best_target


func _push_if_active(enemy: Node) -> void:
	if not is_active() or enemy == null or not is_instance_valid(enemy) or int(enemy.current_hp) <= 0:
		return
	if enemy.has_method("apply_push"):
		enemy.apply_push(owner_unit.facing, int(owner_unit.cfg.get("skill_push_tiles", 1)))
