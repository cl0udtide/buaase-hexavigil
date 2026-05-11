extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_interval := 1.0
var _base_range_pattern: Array[Vector2i] = []
var _base_attack_multiplier := 1.0


func _on_skill_start() -> void:
	_base_attack_interval = owner_unit.attack_interval
	_base_range_pattern = owner_unit.range_pattern.duplicate()
	_base_attack_multiplier = owner_unit.attack_multiplier
	owner_unit.attack_interval = max(_base_attack_interval + float(owner_unit.cfg.get("skill_attack_interval_add", 2.9)), 0.05)
	owner_unit.attack_multiplier = max(float(owner_unit.cfg.get("skill_attack_multiplier", 1.8)), 0.0)
	owner_unit.range_pattern = owner_unit.parse_range_pattern(owner_unit.cfg.get("skill_range_pattern", []))
	_show_current_attack_range_outline()
	_debug_log("技能启动：%s#%d 爆裂黎明，范围 %d 格，攻击间隔 %.1f，攻击倍率 %.2f，持续 %.1f 秒" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		owner_unit.range_pattern.size(),
		owner_unit.attack_interval,
		owner_unit.attack_multiplier,
		get_duration()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_interval = _base_attack_interval
	owner_unit.range_pattern = _base_range_pattern.duplicate()
	owner_unit.attack_multiplier = _base_attack_multiplier
	_clear_current_attack_range_outline()
	_debug_log("技能结束：%s#%d 爆裂黎明结束，攻击范围与攻击间隔恢复" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func after_attack(target: Node, damage_value: int) -> void:
	if owner_unit == null or active_timer <= 0.0 or target == null:
		return
	var radius: int = int(owner_unit.cfg.get("skill_splash_radius", 2))
	if owner_unit.has_method("spawn_one_shot_effect") and target is Node2D:
		owner_unit.spawn_one_shot_effect({
			"texture_path": "res://assets/effects/operators/fiammetta_shell_explosion_strip.png",
			"position": (target as Node2D).global_position,
			"hframes": 6,
			"frame_count": 6,
			"fps": 16.0,
			"duration": 0.42,
			"size": Vector2.ONE * float(radius * 2 + 1) * 64.0,
			"z_index": 24
		})
	var multiplier: float = float(owner_unit.cfg.get("skill_splash_damage_multiplier", 2.2))
	var damage_type: int = owner_unit.parse_damage_type(String(owner_unit.cfg.get("skill_splash_damage_type", "physical")))
	var splash_damage: int = max(int(round(float(damage_value) * multiplier)), 1)
	var center_cell: Vector2i = target.get_current_cell()
	var hit_count: int = 0
	for enemy in owner_unit.get_all_enemies():
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("receive_damage"):
			continue
		if enemy.get_current_cell().distance_squared_to(center_cell) > radius * radius:
			continue
		hit_count += 1
		enemy.receive_damage(splash_damage, damage_type)
	_debug_log("技能溅射：%s#%d 以 %s#%d 为中心，半径 %d，伤害 %d，命中 %d" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		target.enemy_id,
		target.get_runtime_id(),
		radius,
		splash_damage,
		hit_count
	])
