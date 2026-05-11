extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0
var _base_range_pattern: Array[Vector2i] = []
var _base_damage_type := 0
var _hp_loss_pool := 0.0


func tick(delta: float) -> void:
	super.tick(delta)
	if owner_unit == null or not is_active():
		return
	_hp_loss_pool += float(owner_unit.max_hp) * float(owner_unit.cfg.get("skill_hp_loss_percent_per_sec", 0.045)) * delta
	var loss := int(floor(_hp_loss_pool))
	if loss > 0:
		_hp_loss_pool -= float(loss)
		owner_unit.lose_hp(loss, bool(owner_unit.cfg.get("skill_hp_loss_can_kill", true)))


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	_base_range_pattern = owner_unit.range_pattern.duplicate()
	_base_damage_type = owner_unit.damage_type
	_hp_loss_pool = 0.0
	owner_unit.receive_heal(int(round(float(owner_unit.max_hp) * float(owner_unit.cfg.get("skill_initial_heal_percent", 0.45)))))
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 2.6))
	owner_unit.damage_type = owner_unit.parse_damage_type(String(owner_unit.cfg.get("skill_damage_type", "magic")))
	owner_unit.range_pattern = owner_unit.parse_range_pattern(owner_unit.cfg.get("skill_range_pattern", owner_unit.cfg.get("range_pattern", [])))
	_show_current_attack_range_outline()
	if owner_unit.has_method("play_follow_effect"):
		owner_unit.play_follow_effect(
			"res://assets/effects/auras/surtr_twilight_aura_strip.png",
			get_duration(),
			8,
			8,
			12.0,
			Vector2(128.0, 128.0),
			true,
			Vector2.ZERO,
			23
		)
	_debug_log("技能启动：%s#%d 黄昏，法伤决战并持续流失生命" % [owner_unit.unit_id, owner_unit.get_runtime_id()])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier
	owner_unit.range_pattern = _base_range_pattern.duplicate()
	owner_unit.damage_type = _base_damage_type
	_clear_current_attack_range_outline()


func get_attack_targets_override() -> Array:
	if owner_unit == null or not is_active():
		return []
	var targets: Array = _sort_targets_by_priority(owner_unit.get_attack_targets())
	var result: Array = []
	var limit: int = int(owner_unit.cfg.get("skill_target_limit", 3))
	for target in targets:
		if result.size() >= limit:
			break
		result.append(target)
	return result


func after_attack(target: Node, _damage_value: int) -> void:
	if owner_unit == null or not is_active() or target == null or not is_instance_valid(target):
		return
	if owner_unit.has_method("spawn_one_shot_effect"):
		owner_unit.spawn_one_shot_effect({
			"texture_path": "res://assets/effects/operators/surtr_twilight_hit_flare_strip.png",
			"follow_target": target,
			"local_position": Vector2(0.0, -8.0),
			"hframes": 6,
			"frame_count": 6,
			"fps": 18.0,
			"duration": 0.34,
			"size": Vector2(112.0, 112.0),
			"z_index": 25
		})
