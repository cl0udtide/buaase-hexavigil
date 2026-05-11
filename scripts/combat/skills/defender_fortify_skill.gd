extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_defense := 0
var _base_block_count := 0
var _heal_pool := 0.0


func tick(delta: float) -> void:
	super.tick(delta)
	if owner_unit == null or not is_active():
		return
	_heal_pool += float(owner_unit.max_hp) * float(owner_unit.cfg.get("skill_regen_percent_per_sec", 0.03)) * delta
	var heal_value := int(floor(_heal_pool))
	if heal_value <= 0:
		return
	_heal_pool -= float(heal_value)
	owner_unit.receive_heal(heal_value)


func _on_skill_start() -> void:
	_base_defense = owner_unit.defense
	_base_block_count = owner_unit.block_count
	_heal_pool = 0.0
	owner_unit.defense = max(int(round(float(_base_defense) * float(owner_unit.cfg.get("skill_def_multiplier", 1.6)))), 0)
	owner_unit.block_count = _base_block_count + int(owner_unit.cfg.get("skill_block_bonus", 1))
	owner_unit.play_follow_effect(
		_get_fortify_effect_path(),
		get_duration(),
		6,
		6,
		10.0,
		Vector2(116.0, 116.0),
		true,
		Vector2(0.0, -8.0),
		22
	)
	_debug_log("技能启动：%s#%d 加防回血，阻挡 %d，防御 %d，持续 %.1f 秒" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		owner_unit.block_count,
		owner_unit.defense,
		get_duration()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.defense = _base_defense
	owner_unit.block_count = _base_block_count
	_debug_log("技能结束：%s#%d 防御姿态结束" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func _get_fortify_effect_path() -> String:
	if String(owner_unit.cfg.get("visual_key", owner_unit.unit_id)) == "nian":
		return "res://assets/effects/auras/nian_iron_guard_loop_strip.png"
	return "res://assets/effects/auras/defender_fortify_loop_strip.png"
