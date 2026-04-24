class_name SkillRuntime
extends RefCounted


static func execute(unit: Node, cfg: Dictionary) -> void:
	if unit == null:
		return
	var effect_type := String(cfg.get("skill_effect_type", "self_heal" if cfg.has("skill_heal") else "none"))
	match effect_type:
		"self_heal":
			var heal_value := int(cfg.get("skill_heal", cfg.get("skill_value", 0)))
			_debug_log(unit, "技能效果：%s#%d 自疗 %d 点" % [unit.unit_id, unit.get_runtime_id(), heal_value])
			unit.receive_heal(heal_value)
		"attack_boost":
			if unit.has_method("apply_temporary_attack_multiplier"):
				var multiplier := float(cfg.get("skill_atk_multiplier", 1.5))
				var duration := float(cfg.get("skill_duration", 5.0))
				_debug_log(unit, "技能效果：%s#%d 攻击倍率 %.2f，持续 %.1f 秒" % [unit.unit_id, unit.get_runtime_id(), multiplier, duration])
				unit.apply_temporary_attack_multiplier(multiplier, duration)
		"aoe_damage":
			_execute_aoe_damage(unit, cfg)
		_:
			_debug_log(unit, "技能效果：%s#%d 未配置可执行效果" % [unit.unit_id, unit.get_runtime_id()])


static func _execute_aoe_damage(unit: Node, cfg: Dictionary) -> void:
	if not unit.has_method("get_attack_targets"):
		return
	var targets: Array = unit.get_attack_targets()
	if targets.is_empty():
		return
	var center = unit.get_current_target() if unit.has_method("get_current_target") else targets[0]
	if center == null:
		center = targets[0]
	var center_cell: Vector2i = center.get_current_cell()
	var radius := int(cfg.get("skill_radius", 1))
	var damage := int(cfg.get("skill_damage", unit.get_effective_atk() if unit.has_method("get_effective_atk") else 1))
	var damage_type := _parse_damage_type(String(cfg.get("skill_damage_type", cfg.get("damage_type", "physical"))))
	var hit_count := 0
	for enemy in targets:
		if enemy == null or not enemy.has_method("receive_damage"):
			continue
		if enemy.get_current_cell().distance_squared_to(center_cell) <= radius * radius:
			hit_count += 1
			enemy.receive_damage(damage, damage_type)
	_debug_log(unit, "技能效果：%s#%d 范围伤害 %d，半径 %d，命中 %d 个敌人" % [unit.unit_id, unit.get_runtime_id(), damage, radius, hit_count])


static func _parse_damage_type(raw_type: String) -> int:
	match raw_type:
		"magic":
			return GameEnums.DAMAGE_MAGIC
		"true":
			return GameEnums.DAMAGE_TRUE
		_:
			return GameEnums.DAMAGE_PHYSICAL


static func _debug_log(unit: Node, message: String) -> void:
	var tree := unit.get_tree() if unit != null else null
	if tree != null:
		tree.call_group("combat_debug_log", "append_combat_debug", message)
