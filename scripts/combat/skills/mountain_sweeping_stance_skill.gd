extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_interval := 1.0
var _base_attack_multiplier := 1.0
var _base_block_count := 0
var _regen_pool := 0.0


func tick(delta: float) -> void:
	super.tick(delta)
	if owner_unit == null or not is_active():
		return
	_regen_pool += float(owner_unit.max_hp) * float(owner_unit.cfg.get("skill_regen_percent_per_sec", 0.035)) * delta
	var heal_value := int(floor(_regen_pool))
	if heal_value > 0:
		_regen_pool -= float(heal_value)
		owner_unit.receive_heal(heal_value)


func _on_skill_start() -> void:
	_base_attack_interval = owner_unit.attack_interval
	_base_attack_multiplier = owner_unit.attack_multiplier
	_base_block_count = owner_unit.block_count
	_regen_pool = 0.0
	owner_unit.attack_interval = max(_base_attack_interval * float(owner_unit.cfg.get("skill_attack_interval_multiplier", 0.75)), 0.05)
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 1.25))
	owner_unit.block_count = _base_block_count + int(owner_unit.cfg.get("skill_block_bonus", 1))
	owner_unit.play_follow_effect(
		"res://assets/effects/auras/mountain_recover_pulse_strip.png",
		3600.0,
		6,
		6,
		10.0,
		Vector2(104.0, 104.0),
		true,
		Vector2(0.0, -8.0),
		22
	)
	_debug_log("技能启动：%s#%d 横扫架势，常驻自回复并强化挡线" % [owner_unit.unit_id, owner_unit.get_runtime_id()])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_interval = _base_attack_interval
	owner_unit.attack_multiplier = _base_attack_multiplier
	owner_unit.block_count = _base_block_count


func get_attack_targets_override() -> Array:
	if owner_unit == null or not is_active():
		return []
	return owner_unit.get_blocked_enemies()


func after_attack(target: Node, _damage_value: int) -> void:
	if owner_unit == null or not is_active() or target == null or not is_instance_valid(target):
		return
	if not target.has_method("play_follow_effect"):
		return
	target.play_follow_effect(
		"res://assets/effects/operators/mountain_sweep_arc_strip.png",
		0.3,
		6,
		6,
		18.0,
		Vector2(112.0, 88.0),
		false,
		Vector2(0.0, -8.0),
		25
	)
