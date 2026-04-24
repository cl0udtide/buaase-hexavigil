extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	var multiplier := float(owner_unit.cfg.get("skill_atk_multiplier", 1.45))
	owner_unit.attack_multiplier = _base_attack_multiplier * multiplier
	_debug_log("技能启动：%s#%d 攻击力倍率 %.2f，持续 %.1f 秒" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		multiplier,
		get_duration()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier
	_debug_log("技能结束：%s#%d 攻击强化结束" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])
