extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0
var _base_range_pattern: Array[Vector2i] = []
var _ammo := 0
var _killed_during_skill := false


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	_base_range_pattern = owner_unit.range_pattern.duplicate()
	_ammo = int(owner_unit.cfg.get("skill_ammo", 6))
	_killed_during_skill = false
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 2.4))
	owner_unit.range_pattern = owner_unit.parse_range_pattern(owner_unit.cfg.get("skill_range_pattern", owner_unit.cfg.get("range_pattern", [])))
	_debug_log("技能启动：%s#%d “得见光芒”，弹药 %d" % [owner_unit.unit_id, owner_unit.get_runtime_id(), _ammo])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier
	owner_unit.range_pattern = _base_range_pattern.duplicate()
	if _killed_during_skill:
		owner_unit.gain_sp(int(owner_unit.cfg.get("skill_refund_sp_on_kill", 8)))
	_ammo = 0


func after_attack(target: Node, _damage_value: int) -> void:
	if owner_unit == null or not is_active():
		return
	if target != null and is_instance_valid(target):
		if target.has_method("apply_bind"):
			target.apply_bind(float(owner_unit.cfg.get("skill_bind_duration", 1.5)))
		if int(target.get("current_hp")) <= 0:
			_killed_during_skill = true
	_ammo -= 1
	if _ammo <= 0:
		end_skill()
