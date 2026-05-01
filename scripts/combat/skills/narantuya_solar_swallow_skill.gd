extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 1.65))
	_debug_log("技能启动：%s#%d 吞日，回旋投射物强化" % [owner_unit.unit_id, owner_unit.get_runtime_id()])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier


func after_attack(target: Node, damage_value: int) -> void:
	if owner_unit == null or not is_active() or target == null or not is_instance_valid(target):
		return
	if target.has_method("apply_move_speed_multiplier"):
		target.apply_move_speed_multiplier(&"narantuya_stop", float(owner_unit.cfg.get("skill_slow_multiplier", 0.2)), float(owner_unit.cfg.get("skill_slow_duration", 1.0)))
	var return_damage: int = max(int(round(float(damage_value) * float(owner_unit.cfg.get("skill_return_damage_multiplier", 0.75)))), 1)
	var hit_count := 0
	for enemy in _collect_return_path_targets(target):
		if enemy == target:
			continue
		enemy.receive_damage(return_damage, owner_unit.damage_type)
		if enemy.has_method("apply_move_speed_multiplier"):
			enemy.apply_move_speed_multiplier(&"narantuya_return_stop", float(owner_unit.cfg.get("skill_slow_multiplier", 0.2)), float(owner_unit.cfg.get("skill_slow_duration", 1.0)))
		hit_count += 1
	if hit_count > 0:
		_debug_log("吞日返程：%s#%d 命中 %d 名敌人" % [owner_unit.unit_id, owner_unit.get_runtime_id(), hit_count])


func _collect_return_path_targets(target: Node) -> Array:
	var result: Array = []
	var start: Vector2i = target.get_current_cell()
	var end: Vector2i = owner_unit.current_cell
	var delta: Vector2i = end - start
	var major_axis_x: bool = abs(delta.x) >= abs(delta.y)
	for enemy in owner_unit.get_all_enemies():
		if enemy == null or not is_instance_valid(enemy) or int(enemy.get("current_hp")) <= 0:
			continue
		var cell: Vector2i = enemy.get_current_cell()
		if major_axis_x:
			if cell.x >= min(start.x, end.x) and cell.x <= max(start.x, end.x) and abs(cell.y - start.y) <= 1:
				result.append(enemy)
		else:
			if cell.y >= min(start.y, end.y) and cell.y <= max(start.y, end.y) and abs(cell.x - start.x) <= 1:
				result.append(enemy)
	return result
