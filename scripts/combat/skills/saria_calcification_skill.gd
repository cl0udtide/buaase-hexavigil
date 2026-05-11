extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _tick_timer := 0.0


func tick(delta: float) -> void:
	super.tick(delta)
	if owner_unit == null or not is_active():
		return
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = float(owner_unit.cfg.get("skill_tick_interval", 1.0))
	var radius := int(owner_unit.cfg.get("skill_radius", 2))
	for ally in _nearest_damaged_allies(owner_unit.current_cell, radius, int(owner_unit.cfg.get("skill_heal_target_limit", 3))):
		ally.receive_heal(max(int(round(float(owner_unit.get_effective_atk()) * float(owner_unit.cfg.get("skill_heal_multiplier", 1.2)))), 1))
	for enemy in _enemies_in_radius(owner_unit.current_cell, radius):
		if enemy.has_method("apply_move_speed_multiplier"):
			enemy.apply_move_speed_multiplier(&"saria_calcification", float(owner_unit.cfg.get("skill_slow_multiplier", 0.35)), float(owner_unit.cfg.get("skill_status_duration", 1.5)))
		if enemy.has_method("apply_magic_vulnerability"):
			enemy.apply_magic_vulnerability(&"saria_calcification", float(owner_unit.cfg.get("skill_magic_vulnerability", 1.25)), float(owner_unit.cfg.get("skill_status_duration", 1.5)))


func _on_skill_start() -> void:
	_tick_timer = 0.0
	var radius := int(owner_unit.cfg.get("skill_radius", 2))
	if owner_unit.has_method("show_skill_range_outline"):
		owner_unit.show_skill_range_outline(&"saria_calcification", _cells_in_radius(owner_unit.current_cell, radius), {
			"style": &"saria_calcification",
			"duration": get_duration(),
			"width": 2.5,
			"halo_width": 7.0,
			"pulse_amount": 0.2,
			"pulse_speed": 2.8,
			"draw_nodes": false
		})
	_debug_log("技能启动：%s#%d 钙质化，范围治疗并施加减速和法术易伤" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func _on_skill_end() -> void:
	if owner_unit != null and owner_unit.has_method("clear_skill_range_outline"):
		owner_unit.clear_skill_range_outline(&"saria_calcification")
