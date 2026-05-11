extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0
var _base_range_pattern: Array[Vector2i] = []
var _base_damage_type := 0
var _tick_timer := 0.0
const CELL_SIZE := 64.0


func tick(delta: float) -> void:
	super.tick(delta)
	if owner_unit == null or not is_active():
		return
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = float(owner_unit.cfg.get("skill_tick_interval", 0.75))
	var damage_value: int = max(int(round(float(owner_unit.get_effective_atk()) * float(owner_unit.cfg.get("skill_tick_damage_multiplier", 0.65)))), 1)
	_play_flame_line_effect()
	for enemy in _enemies_in_front_line(int(owner_unit.cfg.get("skill_line_length", 5)), int(owner_unit.cfg.get("skill_line_width", 0))):
		if enemy.has_method("apply_resistance_shred"):
			enemy.apply_resistance_shred(&"ifrit_scorched_earth", int(owner_unit.cfg.get("skill_res_shred", 18)), float(owner_unit.cfg.get("skill_status_duration", 2.0)))
		enemy.receive_damage(damage_value, GameEnums.DAMAGE_MAGIC)


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	_base_range_pattern = owner_unit.range_pattern.duplicate()
	_base_damage_type = owner_unit.damage_type
	_tick_timer = 0.0
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 1.2))
	owner_unit.damage_type = GameEnums.DAMAGE_MAGIC
	owner_unit.range_pattern = owner_unit.parse_range_pattern(owner_unit.cfg.get("skill_range_pattern", owner_unit.cfg.get("range_pattern", [])))
	_show_current_attack_range_outline()
	_debug_log("技能启动：%s#%d 灼地，直线灼烧并削减法抗" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier
	owner_unit.range_pattern = _base_range_pattern.duplicate()
	owner_unit.damage_type = _base_damage_type
	_clear_current_attack_range_outline()


func after_attack(target: Node, _damage_value: int) -> void:
	if owner_unit == null or not is_active() or target == null or not is_instance_valid(target):
		return
	if target.has_method("apply_resistance_shred"):
		target.apply_resistance_shred(&"ifrit_scorched_earth_attack", int(owner_unit.cfg.get("skill_res_shred", 18)), float(owner_unit.cfg.get("skill_status_duration", 2.0)))


func _play_flame_line_effect() -> void:
	if not owner_unit.has_method("spawn_one_shot_effect"):
		return
	var facing_vec: Vector2 = Vector2(owner_unit.facing)
	if facing_vec.length_squared() <= 0.001:
		facing_vec = Vector2.RIGHT
	var line_length: int = max(int(owner_unit.cfg.get("skill_line_length", 5)), 1)
	var line_width: int = max(int(owner_unit.cfg.get("skill_line_width", 0)) + 1, 1)
	owner_unit.spawn_one_shot_effect({
		"texture_path": "res://assets/effects/operators/ifrit_flame_line_strip.png",
		"position": (owner_unit as Node2D).global_position + facing_vec.normalized() * CELL_SIZE * float(line_length) * 0.5,
		"rotation": facing_vec.angle(),
		"hframes": 6,
		"frame_count": 6,
		"fps": 16.0,
		"duration": 0.38,
		"size": Vector2(float(line_length) * CELL_SIZE, float(line_width) * 80.0),
		"z_index": 21
	})
