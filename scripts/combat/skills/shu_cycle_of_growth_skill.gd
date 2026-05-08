extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _tick_timer := 0.0
var _seed_cells: Dictionary = {}


func tick(delta: float) -> void:
	super.tick(delta)
	if owner_unit == null or not is_active():
		return
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = float(owner_unit.cfg.get("skill_tick_interval", 1.0))
	var radius := int(owner_unit.cfg.get("skill_seed_radius", 2))
	for ally in _allies_in_radius(owner_unit.current_cell, radius):
		ally.receive_heal(max(int(round(float(owner_unit.get_effective_atk()) * float(owner_unit.cfg.get("skill_heal_multiplier", 0.75)))), 1))
		if ally.has_method("apply_damage_reduction"):
			ally.apply_damage_reduction(&"shu_shelter", float(owner_unit.cfg.get("skill_damage_taken_multiplier", 0.82)), float(owner_unit.cfg.get("skill_shelter_duration", 1.4)))
	for enemy in _enemies_in_radius(owner_unit.current_cell, radius):
		_track_enemy_in_field(enemy)
	_pull_tracked_enemies()


func _on_skill_start() -> void:
	_tick_timer = 0.0
	_seed_cells.clear()
	_debug_log("技能启动：%s#%d 离离枯荣，播种、治疗庇护并回拉敌人" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func _on_skill_end() -> void:
	_seed_cells.clear()


func _track_enemy_in_field(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var enemy_id := int(enemy.get_runtime_id())
	var enemy_cell: Vector2i = enemy.get_current_cell()
	if not _seed_cells.has(enemy_id):
		_seed_cells[enemy_id] = enemy_cell
	if enemy.has_method("apply_move_speed_multiplier"):
		enemy.apply_move_speed_multiplier(&"shu_seeded_field", float(owner_unit.cfg.get("skill_slow_multiplier", 0.6)), float(owner_unit.cfg.get("skill_shelter_duration", 1.4)))


func _pull_tracked_enemies() -> void:
	for raw_enemy_id in _seed_cells.keys().duplicate():
		var enemy_id := int(raw_enemy_id)
		var enemy := _find_enemy_by_runtime_id(enemy_id)
		if enemy == null or not is_instance_valid(enemy) or int(enemy.get("current_hp")) <= 0:
			_seed_cells.erase(enemy_id)
			continue
		var seeded_cell: Vector2i = _seed_cells[enemy_id]
		_pull_enemy_if_needed(enemy, seeded_cell)


func _pull_enemy_if_needed(enemy: Node, seeded_cell: Vector2i) -> void:
	var enemy_cell: Vector2i = enemy.get_current_cell()
	var pull_distance := int(owner_unit.cfg.get("skill_pull_distance", 3))
	if enemy_cell.distance_squared_to(seeded_cell) < pull_distance * pull_distance:
		return
	if enemy.has_method("apply_relocate_to_cell") and enemy.apply_relocate_to_cell(seeded_cell):
		_seed_cells[int(enemy.get_runtime_id())] = seeded_cell


func _find_enemy_by_runtime_id(enemy_id: int) -> Node:
	for enemy in owner_unit.get_all_enemies():
		if enemy != null and is_instance_valid(enemy) and int(enemy.get_runtime_id()) == enemy_id:
			return enemy
	return null
