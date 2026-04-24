extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_block_count := 0


func _on_skill_start() -> void:
	_base_block_count = owner_unit.block_count
	var block_bonus := int(owner_unit.cfg.get("skill_block_bonus", 1))
	owner_unit.block_count = _base_block_count + block_bonus
	_debug_log("技能启动：%s#%d 阻挡数 +%d，并攻击所有被自身阻挡的敌人，持续 %.1f 秒" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		block_bonus,
		get_duration()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.block_count = _base_block_count
	_debug_log("技能结束：%s#%d 阵线压制结束，阻挡数恢复为 %d" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		owner_unit.block_count
	])


func get_attack_targets_override() -> Array:
	if owner_unit == null or active_timer <= 0.0:
		return []
	return owner_unit.get_blocked_enemies()
