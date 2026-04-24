extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_block_count := 0


func _on_skill_start() -> void:
	_base_block_count = owner_unit.block_count
	owner_unit.block_count = _base_block_count + int(owner_unit.cfg.get("skill_block_bonus", 2))
	_debug_log("技能启动：%s#%d 反击壁垒，阻挡 %d，持续 %.1f 秒" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		owner_unit.block_count,
		get_duration()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.block_count = _base_block_count
	_debug_log("技能结束：%s#%d 反击壁垒结束" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func after_receive_damage(source: Node, final_damage: int) -> void:
	if owner_unit == null or not is_active() or final_damage <= 0:
		return
	var heal_value := int(owner_unit.cfg.get("skill_recover_on_damage", 14))
	if heal_value > 0:
		owner_unit.receive_heal(heal_value)
	if source != null and is_instance_valid(source) and source.has_method("receive_damage"):
		var counter_damage := int(owner_unit.cfg.get("skill_counter_damage", 18))
		var damage_type: int = owner_unit.parse_damage_type(String(owner_unit.cfg.get("skill_counter_damage_type", "true")))
		source.receive_damage(counter_damage, damage_type)
		_debug_log("反伤：%s#%d 受到伤害后回复 %d，并反击 %s#%d %d 点" % [
			owner_unit.unit_id,
			owner_unit.get_runtime_id(),
			heal_value,
			source.enemy_id,
			source.get_runtime_id(),
			counter_damage
		])
