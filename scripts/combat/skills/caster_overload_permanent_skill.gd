extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	var multiplier := float(owner_unit.cfg.get("skill_atk_multiplier", 1.55))
	owner_unit.attack_multiplier = _base_attack_multiplier * multiplier
	owner_unit.play_follow_effect(
		"res://assets/effects/auras/caster_overload_aura_strip.png",
		3600.0,
		6,
		6,
		10.0,
		Vector2(110.0, 110.0),
		true,
		Vector2(0.0, -8.0),
		22
	)
	_debug_log("技能启动：%s#%d 术式过载，攻击力倍率 %.2f，持续时间无限" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		multiplier
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier


func after_attack(target: Node, damage_value: int) -> void:
	if owner_unit == null or not is_active() or target == null or not is_instance_valid(target):
		return
	var radius := int(owner_unit.cfg.get("aoe_radius", 1))
	var hit_count := 0
	for enemy in owner_unit.get_all_enemies():
		if enemy == null or not is_instance_valid(enemy) or enemy == target or not enemy.has_method("receive_damage"):
			continue
		if enemy.get_current_cell().distance_squared_to(target.get_current_cell()) > radius * radius:
			continue
		enemy.receive_damage(damage_value, owner_unit.damage_type)
		hit_count += 1
	if hit_count > 0:
		_play_volcano_burst_effect(target)
		_debug_log("范围术式：%s#%d 命中额外 %d 个敌人" % [
			owner_unit.unit_id,
			owner_unit.get_runtime_id(),
			hit_count
		])


func _play_volcano_burst_effect(target: Node) -> void:
	if target == null or not is_instance_valid(target) or not target.has_method("play_follow_effect"):
		return
	target.play_follow_effect(
		"res://assets/effects/operators/eyja_volcano_burst_strip.png",
		0.36,
		6,
		6,
		16.0,
		Vector2(128.0, 128.0),
		false,
		Vector2(0.0, -8.0),
		25
	)
