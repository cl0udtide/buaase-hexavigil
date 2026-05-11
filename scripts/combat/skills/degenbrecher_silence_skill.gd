extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _slash_timer := 0.0
var _slashes_left := 0
const CELL_SIZE := 64.0


func tick(delta: float) -> void:
	super.tick(delta)
	if owner_unit == null or not is_active() or _slashes_left <= 0:
		return
	_slash_timer -= delta
	if _slash_timer > 0.0:
		return
	_slash_timer = float(owner_unit.cfg.get("skill_slash_interval", 0.35))
	_slashes_left -= 1
	_do_slash()


func _on_skill_start() -> void:
	_slashes_left = int(owner_unit.cfg.get("skill_slash_count", 10))
	_slash_timer = 0.0
	_debug_log("技能启动：%s#%d 归于宁静，多段斩击 %d 次" % [owner_unit.unit_id, owner_unit.get_runtime_id(), _slashes_left])


func _do_slash() -> void:
	var targets: Array = _sort_targets_by_priority(_enemies_in_radius(owner_unit.current_cell, int(owner_unit.cfg.get("skill_radius", 3))))
	var limit: int = int(owner_unit.cfg.get("skill_target_limit", 5))
	var damage: int = max(int(round(float(owner_unit.get_effective_atk()) * float(owner_unit.cfg.get("skill_attack_multiplier", 1.55)))), 1)
	_play_slash_pull_effect(int(owner_unit.cfg.get("skill_radius", 3)))
	var hit_count := 0
	for enemy in targets:
		if hit_count >= limit:
			break
		if enemy.has_method("receive_damage"):
			enemy.receive_damage(damage, owner_unit.damage_type)
		_pull_enemy(enemy, 1)
		hit_count += 1
	if _slashes_left <= 0:
		for enemy in targets:
			if enemy.has_method("receive_damage"):
				enemy.receive_damage(max(damage * 2, 1), owner_unit.damage_type)
			_pull_enemy(enemy, int(owner_unit.cfg.get("skill_final_pull_tiles", 2)))
		end_skill()


func _pull_enemy(enemy: Node, tiles: int) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("apply_push"):
		return
	var delta_cell: Vector2i = owner_unit.current_cell - enemy.get_current_cell()
	var direction: Vector2i = _normalize_direction(delta_cell)
	enemy.apply_push(direction, tiles)


func _play_slash_pull_effect(radius: int) -> void:
	if not owner_unit.has_method("spawn_one_shot_effect"):
		return
	owner_unit.spawn_one_shot_effect({
		"texture_path": "res://assets/effects/operators/degenbrecher_multi_slash_pull_strip.png",
		"position": (owner_unit as Node2D).global_position,
		"hframes": 6,
		"frame_count": 6,
		"fps": 18.0,
		"duration": 0.34,
		"size": Vector2.ONE * float(radius * 2 + 1) * CELL_SIZE,
		"z_index": 24
	})
