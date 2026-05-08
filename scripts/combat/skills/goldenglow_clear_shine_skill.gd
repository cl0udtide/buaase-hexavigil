extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0
var _lightning_timer := 0.0


func tick(delta: float) -> void:
	super.tick(delta)
	if owner_unit == null or not is_active():
		return
	_lightning_timer -= delta
	if _lightning_timer > 0.0:
		return
	_lightning_timer = float(owner_unit.cfg.get("skill_lightning_interval", 0.8))
	var targets: Array = _collect_global_targets()
	if targets.is_empty():
		return
	targets.shuffle()
	var count: int = min(int(owner_unit.cfg.get("skill_lightning_count", 2)), targets.size())
	var damage_value: int = max(int(round(float(owner_unit.get_effective_atk()) * float(owner_unit.cfg.get("skill_lightning_multiplier", 0.85)))), 1)
	for index in range(count):
		var enemy: Node = targets[index]
		enemy.receive_damage(damage_value, GameEnums.DAMAGE_MAGIC)
		if enemy.has_method("apply_move_speed_multiplier"):
			enemy.apply_move_speed_multiplier(&"goldenglow_clear_shine", float(owner_unit.cfg.get("skill_slow_multiplier", 0.65)), float(owner_unit.cfg.get("skill_slow_duration", 0.8)))


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	_lightning_timer = 0.0
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 1.15))
	_debug_log("技能启动：%s#%d 澄净闪耀，全图随机索敌雷击" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier


func _collect_global_targets() -> Array:
	var targets: Array = []
	for enemy in owner_unit.get_all_enemies():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if int(enemy.get("current_hp")) <= 0:
			continue
		targets.append(enemy)
	return targets
