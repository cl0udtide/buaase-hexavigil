extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_interval := 1.0
var _marked_enemy_runtime_id := -1
var _ammo := 0
var _max_ammo := 0


func can_cast() -> bool:
	return owner_unit != null and not is_active() and owner_unit.sp >= get_sp_max() and _select_marked_target_id() >= 0


func _on_skill_start() -> void:
	_base_attack_interval = owner_unit.attack_interval
	_marked_enemy_runtime_id = _select_marked_target_id()
	if _marked_enemy_runtime_id < 0:
		_debug_log("技能启动失败：%s#%d “永恒狩猎”没有可标记目标" % [owner_unit.unit_id, owner_unit.get_runtime_id()])
		end_skill()
		return
	_max_ammo = max(int(owner_unit.cfg.get("skill_ammo", 8)), 0)
	_ammo = _max_ammo
	owner_unit.attack_interval = max(_base_attack_interval + float(owner_unit.cfg.get("skill_attack_interval_add", 2.0)), 0.05)
	if owner_unit.has_method("refresh_status_view"):
		owner_unit.refresh_status_view()
	_debug_log("技能启动：%s#%d “永恒狩猎”，标记 %d，弹药 %d" % [owner_unit.unit_id, owner_unit.get_runtime_id(), _marked_enemy_runtime_id, _ammo])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_interval = _base_attack_interval
	_marked_enemy_runtime_id = -1
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


func get_attack_targets_override() -> Array:
	if owner_unit == null or not is_active():
		return []
	var marked := _get_marked_enemy()
	if marked == null:
		end_skill()
		return []
	var targets: Array = _enemies_in_radius(marked.get_current_cell(), int(owner_unit.cfg.get("skill_mark_radius", 2)))
	if targets.is_empty():
		return []
	targets.shuffle()
	return [targets[0]]


func modify_attack_damage(base_damage: int, _target: Node) -> int:
	if not is_active():
		return base_damage
	return max(int(round(float(base_damage) * float(owner_unit.cfg.get("skill_attack_multiplier", 1.55)))), 1)


func after_attack(target: Node, damage_value: int) -> void:
	if owner_unit == null or not is_active():
		return
	var marked := _get_marked_enemy()
	if marked != null:
		var hits := int(owner_unit.cfg.get("skill_extra_hit_count", 3))
		var hit_multiplier := float(owner_unit.cfg.get("skill_extra_hit_multiplier", 0.55))
		for _index in range(hits):
			var candidates: Array = _enemies_in_radius(marked.get_current_cell(), int(owner_unit.cfg.get("skill_mark_radius", 2)))
			if candidates.is_empty():
				break
			candidates.shuffle()
			var enemy: Node = candidates[0]
			enemy.receive_damage(max(int(round(float(damage_value) * hit_multiplier)), 1), owner_unit.damage_type)
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(float(owner_unit.cfg.get("skill_stun_duration", 0.35)))
	if target != null and is_instance_valid(target) and target.has_method("apply_stun"):
		target.apply_stun(float(owner_unit.cfg.get("skill_stun_duration", 0.35)))
	_ammo -= 1
	if _ammo <= 0:
		end_skill()
	elif owner_unit.has_method("refresh_status_view"):
		owner_unit.refresh_status_view()


func _select_marked_target_id() -> int:
	var targets: Array = _sort_targets_by_priority(owner_unit.get_attack_targets())
	if targets.is_empty():
		return -1
	return int(targets[0].get_runtime_id())


func _get_marked_enemy() -> Node:
	if _marked_enemy_runtime_id < 0:
		return null
	for enemy in owner_unit.get_all_enemies():
		if enemy != null and is_instance_valid(enemy) and int(enemy.get_runtime_id()) == _marked_enemy_runtime_id and int(enemy.get("current_hp")) > 0:
			return enemy
	return null
