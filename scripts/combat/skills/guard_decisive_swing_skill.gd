extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_range_pattern: Array[Vector2i] = []


func _on_skill_start() -> void:
	_base_range_pattern = owner_unit.range_pattern.duplicate()
	owner_unit.range_pattern = owner_unit.parse_range_pattern(owner_unit.cfg.get("skill_range_pattern", []))
	_debug_log("技能启动：%s#%d 决战挥击，范围 %d 格，最多攻击 %d 个敌人，持续 %.1f 秒" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		owner_unit.range_pattern.size(),
		int(owner_unit.cfg.get("skill_target_limit", 5)),
		get_duration()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.range_pattern = _base_range_pattern.duplicate()
	_debug_log("技能结束：%s#%d 决战挥击结束" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func get_attack_targets_override() -> Array:
	if owner_unit == null or not is_active():
		return []
	var targets := _sort_targets(owner_unit.get_attack_targets())
	var result: Array = []
	var limit := int(owner_unit.cfg.get("skill_target_limit", 5))
	for target in targets:
		if result.size() >= limit:
			break
		result.append(target)
	return result


func modify_attack_damage(base_damage: int, _target: Node) -> int:
	if not is_active():
		return base_damage
	return max(int(round(float(base_damage) * float(owner_unit.cfg.get("skill_attack_multiplier", 1.6)))), 1)


func _sort_targets(targets: Array) -> Array:
	var sorted: Array = []
	for target in targets:
		var inserted := false
		for index in range(sorted.size()):
			if _is_higher_priority(target, sorted[index]):
				sorted.insert(index, target)
				inserted = true
				break
		if not inserted:
			sorted.append(target)
	return sorted


func _is_higher_priority(a: Node, b: Node) -> bool:
	var a_progress := float(a.get_path_progress_score()) if a.has_method("get_path_progress_score") else 0.0
	var b_progress := float(b.get_path_progress_score()) if b.has_method("get_path_progress_score") else 0.0
	if not is_equal_approx(a_progress, b_progress):
		return a_progress > b_progress
	return a.get_runtime_id() < b.get_runtime_id()
