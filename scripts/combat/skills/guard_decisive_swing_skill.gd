extends "res://scripts/combat/skills/unit_skill_behavior.gd"


const CELL_SIZE := 64.0
const SLASH_TEXTURE := "res://assets/effects/slash/truesilver_slash_wave_strip.png"
const HIT_TEXTURE := "res://assets/effects/slash/truesilver_hit_spark_strip.png"
const SLASH_EFFECT_INTERVAL_MSEC := 90

var _base_range_pattern: Array[Vector2i] = []
var _last_slash_effect_msec := -100000


func _on_skill_start() -> void:
	_base_range_pattern = owner_unit.range_pattern.duplicate()
	owner_unit.range_pattern = owner_unit.parse_range_pattern(owner_unit.cfg.get("skill_range_pattern", []))
	_show_current_attack_range_outline()
	_debug_log("技能启动：%s#%d 决战挥击，范围 %d 格，最多攻击 %d 个敌人，持续 %.1f 秒" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		owner_unit.range_pattern.size(),
		int(owner_unit.cfg.get("skill_target_limit", 5)),
		get_duration()
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.range_pattern = _base_range_pattern.duplicate()
	_clear_current_attack_range_outline()
	_debug_log("技能结束：%s#%d 决战挥击结束" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id()
	])


func get_attack_targets_override() -> Array:
	if owner_unit == null or not is_active():
		return []
	var targets := _sort_targets(owner_unit.get_attack_targets())
	var result: Array = []
	var limit := int(owner_unit.cfg.get("skill_target_limit", 5))
	for target in targets:
		if result.size() >= limit:
			break
		result.append(target)
	return result


func modify_attack_damage(base_damage: int, _target: Node) -> int:
	if not is_active():
		return base_damage
	return max(int(round(float(base_damage) * float(owner_unit.cfg.get("skill_attack_multiplier", 1.6)))), 1)


func after_attack(target: Node, _damage_value: int) -> void:
	if owner_unit == null or not is_active():
		return
	_play_slash_effect_once()
	_play_hit_effect(target)


func _play_slash_effect_once() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_slash_effect_msec < SLASH_EFFECT_INTERVAL_MSEC:
		return
	_last_slash_effect_msec = now
	if not owner_unit.has_method("spawn_one_shot_effect"):
		return
	var metrics := _get_range_effect_metrics()
	owner_unit.spawn_one_shot_effect({
		"texture_path": SLASH_TEXTURE,
		"position": metrics["position"],
		"rotation": metrics["rotation"],
		"size": metrics["size"],
		"hframes": 8,
		"frame_count": 8,
		"fps": 22.0,
		"duration": 0.36,
		"z_index": 22
	})


func _play_hit_effect(target: Node) -> void:
	if target == null or not is_instance_valid(target) or not target is Node2D:
		return
	if not owner_unit.has_method("spawn_one_shot_effect"):
		return
	owner_unit.spawn_one_shot_effect({
		"texture_path": HIT_TEXTURE,
		"follow_target": target,
		"local_position": Vector2(0.0, -8.0),
		"hframes": 6,
		"frame_count": 6,
		"fps": 20.0,
		"duration": 0.3,
		"size": Vector2(112.0, 112.0),
		"z_index": 24
	})


func _get_range_effect_metrics() -> Dictionary:
	var pattern: Array[Vector2i] = owner_unit.parse_range_pattern(owner_unit.cfg.get("skill_range_pattern", owner_unit.cfg.get("range_pattern", [])))
	if pattern.is_empty():
		pattern = owner_unit.range_pattern.duplicate()
	var min_x := 0
	var max_x := 0
	var min_y := 0
	var max_y := 0
	var initialized := false
	for offset in pattern:
		if not initialized:
			min_x = offset.x
			max_x = offset.x
			min_y = offset.y
			max_y = offset.y
			initialized = true
		else:
			min_x = min(min_x, offset.x)
			max_x = max(max_x, offset.x)
			min_y = min(min_y, offset.y)
			max_y = max(max_y, offset.y)
	var local_center := Vector2(
		(float(min_x + max_x) * 0.5) * CELL_SIZE,
		(float(min_y + max_y) * 0.5) * CELL_SIZE
	)
	var facing_vec := Vector2(owner_unit.facing)
	if facing_vec.length_squared() <= 0.001:
		facing_vec = Vector2.RIGHT
	var rotation := facing_vec.angle()
	var forward_span := float(max_x - min_x + 1) * CELL_SIZE
	var cross_span := float(max_y - min_y + 1) * CELL_SIZE
	return {
		"position": (owner_unit as Node2D).global_position + local_center.rotated(rotation),
		"rotation": rotation,
		"size": Vector2(max(forward_span * 1.75, 360.0), max(cross_span * 1.35, 300.0))
	}


func _sort_targets(targets: Array) -> Array:
	var sorted: Array = []
	for target in targets:
		var inserted := false
		for index in range(sorted.size()):
			if _is_higher_priority(target, sorted[index]):
				sorted.insert(index, target)
				inserted = true
				break
		if not inserted:
			sorted.append(target)
	return sorted


func _is_higher_priority(a: Node, b: Node) -> bool:
	var a_progress := float(a.get_path_progress_score()) if a.has_method("get_path_progress_score") else 0.0
	var b_progress := float(b.get_path_progress_score()) if b.has_method("get_path_progress_score") else 0.0
	if not is_equal_approx(a_progress, b_progress):
		return a_progress > b_progress
	return a.get_runtime_id() < b.get_runtime_id()
