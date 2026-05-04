extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0
var _base_defense := 0
var _base_range_pattern: Array[Vector2i] = []
var _ammo := 0
var _max_ammo := 0


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	_base_defense = owner_unit.defense
	_base_range_pattern = owner_unit.range_pattern.duplicate()
	_max_ammo = max(int(owner_unit.cfg.get("skill_ammo", 5)), 0)
	_ammo = _max_ammo
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 1.65))
	owner_unit.defense = max(int(round(float(_base_defense) * float(owner_unit.cfg.get("skill_def_multiplier", 1.25)))), 0)
	owner_unit.range_pattern = owner_unit.parse_range_pattern(owner_unit.cfg.get("skill_range_pattern", owner_unit.cfg.get("range_pattern", [])))
	if owner_unit.has_method("refresh_status_view"):
		owner_unit.refresh_status_view()
	_debug_log("技能启动：%s#%d 饱和迸射，炮击弹药 %d" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		_ammo
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier
	owner_unit.defense = _base_defense
	owner_unit.range_pattern = _base_range_pattern.duplicate()
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
		"label": "炮弹"
	}


func after_attack(target: Node, damage_value: int) -> void:
	if owner_unit == null or not is_active():
		return
	if target != null and is_instance_valid(target):
		var splash_damage: int = max(int(round(float(damage_value) * float(owner_unit.cfg.get("skill_splash_multiplier", 0.55)))), 1)
		for enemy in _enemies_in_radius(target.get_current_cell(), int(owner_unit.cfg.get("skill_splash_radius", 1))):
			if enemy == target:
				continue
			enemy.receive_damage(splash_damage, owner_unit.damage_type)
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(float(owner_unit.cfg.get("skill_stun_duration", 0.6)))
		if target.has_method("apply_stun"):
			target.apply_stun(float(owner_unit.cfg.get("skill_stun_duration", 0.6)))
	_ammo -= 1
	if _ammo <= 0:
		end_skill()
	elif owner_unit.has_method("refresh_status_view"):
		owner_unit.refresh_status_view()
