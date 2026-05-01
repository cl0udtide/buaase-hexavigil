class_name UnitSkillBehavior
extends Node


var owner_unit: Node
var active_timer := 0.0
var _infinite_active := false


func setup(unit: Node) -> void:
	owner_unit = unit
	active_timer = 0.0
	_infinite_active = false


func on_deployed() -> void:
	pass


func tick(delta: float) -> void:
	if active_timer <= 0.0:
		return
	if _infinite_active:
		return
	active_timer = max(active_timer - delta, 0.0)
	if active_timer == 0.0:
		_on_skill_end()


func should_auto_cast() -> bool:
	return bool(owner_unit.cfg.get("skill_auto_cast", false)) if owner_unit != null else false


func can_cast() -> bool:
	return owner_unit != null and not is_active() and owner_unit.sp >= get_sp_max()


func cast() -> bool:
	if not can_cast():
		return false
	owner_unit.sp = 0.0
	_infinite_active = bool(owner_unit.cfg.get("skill_infinite_duration", false))
	active_timer = 1.0 if _infinite_active else get_duration()
	_on_skill_start()
	return true


func end_skill() -> void:
	if active_timer <= 0.0:
		return
	active_timer = 0.0
	_infinite_active = false
	_on_skill_end()


func get_skill_name() -> String:
	return String(owner_unit.cfg.get("skill_name", owner_unit.cfg.get("skill_id", "未配置技能"))) if owner_unit != null else "未配置技能"


func get_skill_description() -> String:
	return String(owner_unit.cfg.get("skill_description", "暂无技能描述。")) if owner_unit != null else "暂无技能描述。"


func get_sp_max() -> float:
	return float(owner_unit.cfg.get("sp_max", 0.0)) if owner_unit != null else 0.0


func get_sp_recover_per_sec() -> float:
	return float(owner_unit.cfg.get("sp_recover_per_sec", 0.0)) if owner_unit != null else 0.0


func get_duration() -> float:
	return float(owner_unit.cfg.get("skill_duration", 0.0)) if owner_unit != null else 0.0


func get_active_remaining() -> float:
	return -1.0 if _infinite_active else active_timer


func is_active() -> bool:
	return active_timer > 0.0


func get_attack_targets_override() -> Array:
	return []


func get_attack_projectile_payloads(_target: Node, _damage_value: int) -> Array:
	return []


func after_attack(_target: Node, _damage_value: int) -> void:
	pass


func modify_attack_damage(base_damage: int, _target: Node) -> int:
	return base_damage


func modify_final_incoming_damage(final_damage: int, _raw_damage: int, _damage_type_value: int, _source: Node) -> int:
	return final_damage


func modify_incoming_heal(heal_value: int, _source: Node) -> int:
	return heal_value


func after_receive_damage(_source: Node, _final_damage: int) -> void:
	pass


func _on_skill_start() -> void:
	pass


func _on_skill_end() -> void:
	_infinite_active = false
	pass


func _debug_log(message: String) -> void:
	if owner_unit == null:
		return
	var tree := owner_unit.get_tree()
	if tree != null:
		tree.call_group("combat_debug_log", "append_combat_debug", message)


func _sort_targets_by_priority(targets: Array) -> Array:
	var sorted: Array = []
	for target in targets:
		if target == null or not is_instance_valid(target):
			continue
		var inserted := false
		for index in range(sorted.size()):
			if _is_target_higher_priority(target, sorted[index]):
				sorted.insert(index, target)
				inserted = true
				break
		if not inserted:
			sorted.append(target)
	return sorted


func _is_target_higher_priority(a: Node, b: Node) -> bool:
	var a_progress := float(a.get_path_progress_score()) if a.has_method("get_path_progress_score") else 0.0
	var b_progress := float(b.get_path_progress_score()) if b.has_method("get_path_progress_score") else 0.0
	if not is_equal_approx(a_progress, b_progress):
		return a_progress > b_progress
	return int(a.get_runtime_id()) < int(b.get_runtime_id())


func _enemies_in_radius(center_cell: Vector2i, radius: int) -> Array:
	var targets: Array = []
	if owner_unit == null:
		return targets
	var radius_sq := radius * radius
	for enemy in owner_unit.get_all_enemies():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if int(enemy.get("current_hp")) <= 0:
			continue
		if enemy.get_current_cell().distance_squared_to(center_cell) <= radius_sq:
			targets.append(enemy)
	return _sort_targets_by_priority(targets)


func _enemies_in_front_line(length: int, width: int = 0) -> Array:
	var targets: Array = []
	if owner_unit == null:
		return targets
	var forward := _normalize_direction(owner_unit.facing)
	var side := Vector2i(-forward.y, forward.x)
	var cells: Array[Vector2i] = []
	for step in range(1, max(length, 1) + 1):
		for offset in range(-width, width + 1):
			cells.append(owner_unit.current_cell + forward * step + side * offset)
	for enemy in owner_unit.get_all_enemies():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if cells.has(enemy.get_current_cell()):
			targets.append(enemy)
	return _sort_targets_by_priority(targets)


func _allies_in_radius(center_cell: Vector2i, radius: int) -> Array:
	var allies: Array = []
	if owner_unit == null:
		return allies
	var radius_sq := radius * radius
	for unit in owner_unit.get_all_deployed_units():
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.has_method("get_current_cell") and unit.get_current_cell().distance_squared_to(center_cell) <= radius_sq:
			allies.append(unit)
	return allies


func _nearest_damaged_allies(center_cell: Vector2i, radius: int, limit: int) -> Array:
	var candidates := _allies_in_radius(center_cell, radius)
	var result: Array = []
	while not candidates.is_empty() and result.size() < limit:
		var best_index := -1
		var best_missing := 0
		var best_dist := 0
		for index in range(candidates.size()):
			var unit: Node = candidates[index]
			var missing := int(unit.max_hp) - int(unit.current_hp)
			if missing <= 0:
				continue
			var dist: int = unit.get_current_cell().distance_squared_to(center_cell)
			if best_index < 0 or missing > best_missing or (missing == best_missing and dist < best_dist):
				best_index = index
				best_missing = missing
				best_dist = dist
		if best_index < 0:
			break
		result.append(candidates[best_index])
		candidates.remove_at(best_index)
	return result


func _normalize_direction(direction: Vector2i) -> Vector2i:
	if direction == Vector2i.ZERO:
		return Vector2i.RIGHT
	if abs(direction.x) >= abs(direction.y):
		return Vector2i.RIGHT if direction.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0 else Vector2i.UP
