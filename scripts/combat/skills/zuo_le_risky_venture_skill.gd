extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0
var _base_block_count := 0
var _barrier := 0


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	_base_block_count = owner_unit.block_count
	owner_unit.lose_hp(int(ceil(float(owner_unit.current_hp) * float(owner_unit.cfg.get("skill_hp_loss_percent", 0.5)))), false)
	owner_unit.play_follow_effect(
		"res://assets/effects/operators/zuo_le_blood_cost_flash_strip.png",
		0.34,
		6,
		6,
		18.0,
		Vector2(112.0, 112.0),
		false,
		Vector2(0.0, -8.0),
		25
	)
	_barrier = int(round(float(owner_unit.max_hp) * float(owner_unit.cfg.get("skill_barrier_percent", 0.7))))
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 1.75))
	owner_unit.block_count = _base_block_count + int(owner_unit.cfg.get("skill_block_bonus", 1))
	owner_unit.play_follow_effect(
		"res://assets/effects/auras/barrier_guard_loop_strip.png",
		get_duration(),
		8,
		8,
		10.0,
		Vector2(112.0, 112.0),
		true,
		Vector2(0.0, -8.0),
		22
	)
	_debug_log("技能启动：%s#%d 行险，屏障 %d，阻挡 %d" % [owner_unit.unit_id, owner_unit.get_runtime_id(), _barrier, owner_unit.block_count])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier
	owner_unit.block_count = _base_block_count
	_barrier = 0


func modify_final_incoming_damage(final_damage: int, _raw_damage: int, _damage_type_value: int, _source: Node) -> int:
	if _barrier <= 0 or final_damage <= 0:
		return final_damage
	var absorbed: int = min(_barrier, final_damage)
	_barrier -= absorbed
	return final_damage - absorbed


func modify_attack_damage(base_damage: int, _target: Node) -> int:
	if owner_unit == null or not is_active():
		return base_damage
	var max_hp_value: float = float(max(float(owner_unit.max_hp), 1.0))
	var missing_ratio: float = 1.0 - (float(owner_unit.current_hp) / max_hp_value)
	var low_hp_bonus: float = 1.0 + missing_ratio * float(owner_unit.cfg.get("skill_missing_hp_atk_bonus", 0.45))
	return max(int(round(float(base_damage) * low_hp_bonus)), 1)


func get_attack_targets_override() -> Array:
	if owner_unit == null or not is_active():
		return []
	return owner_unit.get_blocked_enemies()
