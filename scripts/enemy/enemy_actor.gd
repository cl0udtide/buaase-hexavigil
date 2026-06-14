extends Node2D

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const AppRefs = preload("res://scripts/common/app_refs.gd")
const BossController = preload("res://scripts/enemy/boss_controller.gd")
const EnemyMovementController = preload("res://scripts/enemy/enemy_movement_controller.gd")
const EnemyAttackController = preload("res://scripts/enemy/enemy_attack_controller.gd")
const OneShotEffect = preload("res://scripts/effects/one_shot_effect.gd")
const ContactShadow = preload("res://scripts/effects/contact_shadow.gd")
const DifficultyScale = preload("res://scripts/enemy/difficulty_scale.gd")

const DEBUG_SIZE := 40.0
const DEBUG_COLOR := Color(1.0, 0.25, 0.25, 0.95)
const INVALID_DEATH_SPAWN_CELL := Vector2i(-9999, -9999)
const VISUAL_TEXTURE_ROOT := "res://assets/sprites/enemies"
const VISUAL_IDLE_ANIM := "idle"
const VISUAL_TEXTURE_SIZE := 128.0
const VISUAL_DISPLAY_SIZE := 70.0
const VISUAL_OFFSET := Vector2(0.0, -8.0)
const CONTACT_SHADOW_Y := 25.0
const VISUAL_Z_INDEX := 2
const OVERLAY_Z_INDEX := 20
const ATTACK_LUNGE_DISTANCE := 5.0
const ATTACK_LUNGE_ROTATION_DEGREES := 7.0
const ATTACK_LUNGE_IN_SECONDS := 0.055
const ATTACK_LUNGE_OUT_SECONDS := 0.11
const IDLE_MOTION_ROOT_NAME := "IdleMotionRoot"
const IDLE_MOTION_GROUND_BREATH_SCALE := Vector2(0.993, 1.016)
const IDLE_MOTION_FLYING_BREATH_SCALE := Vector2(0.99, 1.02)
const IDLE_MOTION_GROUND_BOB_Y := -0.8
const IDLE_MOTION_FLYING_BOB_Y := -2.4
const IDLE_MOTION_MIN_SECONDS := 1.7
const IDLE_MOTION_MAX_SECONDS := 2.45
const DEFAULT_IMPACT_SIZE := Vector2(96.0, 96.0)
const DEFAULT_STATUS_EFFECT_SIZE := Vector2(112.0, 112.0)
const SFX_IMPACT_PHYSICAL := &"impact_physical"
const SFX_IMPACT_ARTS := &"impact_arts"
const CELL_SIZE := 64.0
# 瞄准用的“身体半径”（格数）：怪身体覆盖到的每个格子都算它所在，干员范围罩住任一格即可命中。
# 0.3 格 → 居中时只占 1 格；卡在格子交界（被阻挡/跨格行进）时占 2 格，修掉“贴图横跨两格却打不到”的手感问题。
const FOOTPRINT_RADIUS_TILES := 0.3

var enemy_id: StringName
var runtime_id := -1
var current_cell := Vector2i.ZERO
var facing := Vector2i.RIGHT
var cfg: Dictionary = {}
var current_hp := 1
var max_hp := 1
var _is_dead := false
var _movement_controller: Node = null
var _attack_controller: Node = null
var _boss_controller: Node = null
var _move_speed_effects: Dictionary = {}
var _external_attack_speed_add := 0.0
var _defense_shred_effects: Dictionary = {}
var _resistance_shred_effects: Dictionary = {}
var _physical_vulnerability_effects: Dictionary = {}
var _magic_vulnerability_effects: Dictionary = {}
var _dot_effects: Dictionary = {}
var _stun_timer := 0.0
var _bind_timer := 0.0
var _shield_hp := 0
var _max_shield_hp := 0
var _regen_carry := 0.0
var _stat_scale := 1.0
var _max_hp_scale := 1.0
var _regen_effect_cooldown := 0.0
var _idle_motion_root: Node2D = null
var _idle_motion_tween: Tween = null
var _attack_lunge_tween: Tween = null

@onready var _status_view: Node = get_node_or_null("%StatusView")
@onready var _visual_root: Node2D = get_node_or_null("%VisualRoot") as Node2D
var _has_visual_sprite := false


func _ready() -> void:
	add_to_group("enemies")
	var shadow := ContactShadow.new()
	shadow.name = "ContactShadow"
	shadow.position = Vector2(0.0, CONTACT_SHADOW_Y)
	shadow.radius = 12.0
	add_child(shadow)
	queue_redraw()


func _process(delta: float) -> void:
	if _is_dead:
		return
	_tick_status_effects(delta)
	if _is_dead:
		return
	_tick_regeneration(delta)
	_refresh_fog_visibility()
	if _boss_controller != null and _boss_controller.is_transitioning():
		var phase_cfg: Dictionary = _boss_controller.tick(delta)
		if not phase_cfg.is_empty():
			_apply_phase_cfg(phase_cfg)
			_boss_controller.apply_phase_enter_effects()
		return
	if _is_stunned():
		return
	if is_blocked():
		var blocker: Node = _get_blocker()
		if blocker == null or not is_instance_valid(blocker):
			clear_blocked()
			return
		_movement_controller.process_blocked_motion(delta, blocker)
		_attack_controller.process_blocked_attack(delta, blocker)
		return
	if not _movement_controller.has_path():
		return
	if _movement_controller.has_arrived():
		get_enemy_manager().notify_enemy_reached_core(runtime_id)
		return
	if _is_movement_locked():
		_movement_controller.process_idle_crowd_spacing(delta)
		_attack_controller.process_range_attack(delta)
		return
	var path_building: Node = _attack_controller.get_blocking_building_on_path(_movement_controller)
	if path_building != null:
		_attack_controller.process_building_attack(delta, path_building)
		return
	if _attack_controller.process_range_attack(delta):
		_movement_controller.process_idle_crowd_spacing(delta)
		return
	if _movement_controller.process_path_movement(delta):
		get_enemy_manager().notify_enemy_reached_core(runtime_id)


func setup_from_cfg(new_enemy_id: StringName, new_cfg: Dictionary, spawn_cell: Vector2i) -> void:
	enemy_id = new_enemy_id
	cfg = new_cfg.duplicate(true)
	cfg["id"] = new_enemy_id
	_stat_scale = float(cfg.get("_stat_scale", 1.0))
	_max_hp_scale = float(cfg.get("_max_hp_scale", _stat_scale))
	DifficultyScale.apply_stat_scale(cfg, _stat_scale, _max_hp_scale)
	max_hp = int(cfg.get("max_hp", 1))
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_buff_effect_total_for_enemy"):
		max_hp = max(int(round(float(max_hp) * (1.0 + float(run_state.get_buff_effect_total_for_enemy(&"enemy_hp_percent", cfg))))), 1)
	current_hp = max_hp
	_max_shield_hp = max(int(cfg.get("shield_hp", 0)), 0)
	_shield_hp = _max_shield_hp
	_regen_carry = 0.0
	_regen_effect_cooldown = 0.0
	current_cell = spawn_cell
	facing = Vector2i.RIGHT
	_is_dead = false
	_clear_temporary_status()
	_setup_movement_controller()
	_setup_attack_controller()
	_setup_boss_controller()
	global_position = get_map_manager().cell_to_world(spawn_cell)
	recalc_path()
	_refresh_fog_visibility()
	var label: Label = get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.theme = AppTheme.get_theme()
		label.text = String(cfg.get("name", enemy_id))
		label.position = Vector2(-30.0, -58.0)
		label.z_index = OVERLAY_Z_INDEX
	if _status_view is CanvasItem:
		(_status_view as CanvasItem).z_index = OVERLAY_Z_INDEX
	_setup_visual_sprite()
	_update_status_view()
	queue_redraw()


func _draw() -> void:
	if _has_visual_sprite:
		return
	var rect: Rect2 = Rect2(Vector2.ONE * (-DEBUG_SIZE * 0.5), Vector2.ONE * DEBUG_SIZE)
	draw_rect(rect, DEBUG_COLOR, false, 2.0)
	draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), DEBUG_COLOR, 1.5)
	draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0), DEBUG_COLOR, 1.5)


func receive_damage(value: int, damage_type: int, defense_ignore: float = 0.0, source: Node = null, res_ignore_flat: int = 0) -> void:
	if (_boss_controller != null and _boss_controller.is_transitioning()) or bool(cfg.get("invulnerable", false)):
		_debug_log("敌人 %s#%d 处于无敌状态，免疫本次伤害" % [_debug_name(), runtime_id])
		return
	var ignore := clampf(defense_ignore, 0.0, 0.95)
	var final_damage: int = value
	if damage_type == GameEnums.DAMAGE_PHYSICAL:
		final_damage = CombatMath.calc_physical_damage(value, int(round(float(_get_effective_defense()) * (1.0 - ignore))))
	elif damage_type == GameEnums.DAMAGE_MAGIC:
		var eff_res: int = max(int(round(float(_get_effective_resistance()) * (1.0 - ignore))) - max(res_ignore_flat, 0), 0)
		final_damage = CombatMath.calc_magic_damage(value, eff_res)
	final_damage = max(int(round(float(final_damage) * _get_vulnerability_multiplier(damage_type))), 0)
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_enemy_damage_taken_percent"):
		final_damage = max(int(round(float(final_damage) * (1.0 + float(run_state.get_enemy_damage_taken_percent(damage_type, cfg))))), 0)
	var shield_absorbed: int = _absorb_damage_with_shield(final_damage)
	final_damage = max(final_damage - shield_absorbed, 0)
	current_hp = max(current_hp - final_damage, 0)
	_apply_reflect_damage(source, final_damage, damage_type)
	_update_status_view()
	if shield_absorbed > 0:
		_play_shield_absorb_effect()
	_play_hit_effect(damage_type)
	var shield_text := "，护盾吸收 %d，护盾 %d" % [shield_absorbed, _shield_hp] if shield_absorbed > 0 else ""
	_debug_log("敌人 %s#%d 受到%s伤害：原始 %d，结算 %d，HP %d/%d%s" % [_debug_name(), runtime_id, _damage_type_text(damage_type), value, final_damage, current_hp, max_hp, shield_text])
	if current_hp == 0 and not _is_dead:
		if _boss_controller != null and _boss_controller.try_consume_death_for_phase_transition():
			clear_blocked()
			_update_status_view()
			return
		_is_dead = true
		_debug_log("敌人 %s#%d 死亡" % [_debug_name(), runtime_id])
		get_enemy_manager().remove_enemy(runtime_id)


## 反弹物理伤害给来源（凑凑企鹅 P1）：逼"别用物理硬怼，换法术/真伤/远程"。
func _apply_reflect_damage(source: Node, final_damage: int, damage_type: int) -> void:
	if damage_type != GameEnums.DAMAGE_PHYSICAL or final_damage <= 0:
		return
	var percent := float(cfg.get("reflect_physical_percent", 0.0))
	if percent <= 0.0:
		return
	if source == null or source == self or not is_instance_valid(source) or not source.has_method("receive_damage"):
		return
	var reflected := maxi(int(round(float(final_damage) * percent)), 1)
	source.receive_damage(reflected, GameEnums.DAMAGE_PHYSICAL, null)
	var fx := String(cfg.get("reflect_effect", ""))
	if not fx.is_empty() and source.has_method("play_follow_effect"):
		# 反弹特效放在被弹的干员身上，而非企鹅自身。
		source.play_follow_effect(fx, 0.4, 6, 6, 18.0, Vector2(96.0, 96.0))


func apply_defeat_effects() -> void:
	_play_defeat_effect()
	_apply_death_area_damage()
	_spawn_death_enemies()


func apply_push(direction: Vector2i, tiles: int) -> bool:
	if _is_dead:
		return false
	var pushed: bool = _movement_controller.apply_push(direction, tiles) if _movement_controller != null else false
	if pushed:
		_play_push_pull_effect(direction)
	return pushed


func apply_relocate_to_cell(cell: Vector2i) -> bool:
	if _is_dead:
		return false
	var map_manager := get_map_manager()
	if map_manager == null or not map_manager.is_inside(cell):
		return false
	var cell_data = map_manager.get_cell_data(cell) if map_manager.has_method("get_cell_data") else null
	if cell_data != null and cell_data.is_core:
		return false
	if not map_manager.is_walkable(cell):
		return false
	var old_position := global_position
	var new_position: Vector2 = map_manager.cell_to_world(cell)
	current_cell = cell
	global_position = new_position
	clear_blocked()
	recalc_path()
	_play_directional_streak_effect((old_position + new_position) * 0.5, new_position - old_position)
	_debug_log("敌人 %s#%d 被牵引回格子 %s" % [_debug_name(), runtime_id, current_cell])
	return true


func apply_stun(duration: float) -> void:
	var was_active := _stun_timer > 0.0
	_stun_timer = max(_stun_timer, duration)
	if not was_active:
		play_follow_effect(
			"res://assets/effects/auras/stun_star_small_strip.png",
			duration,
			8,
			8,
			10.0,
			Vector2(84.0, 84.0),
			true,
			Vector2(0.0, -38.0),
			26
		)


func apply_bind(duration: float) -> void:
	var was_active := _bind_timer > 0.0
	_bind_timer = max(_bind_timer, duration)
	if not was_active:
		play_follow_effect(
			"res://assets/effects/common/slow_bind_snare_strip.png",
			duration,
			6,
			6,
			12.0,
			Vector2(104.0, 80.0),
			true,
			Vector2.ZERO,
			23
		)


func apply_move_speed_multiplier(effect_key: StringName, multiplier: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var was_active := _move_speed_effects.has(effect_key)
	_move_speed_effects[effect_key] = {
		"value": clamp(multiplier, 0.0, 1.0),
		"remaining": duration
	}
	if not was_active and multiplier < 1.0:
		play_follow_effect(
			"res://assets/effects/common/slow_bind_snare_strip.png",
			duration,
			6,
			6,
			12.0,
			Vector2(96.0, 72.0),
			true,
			Vector2.ZERO,
			22
		)
	_refresh_status_multipliers()


func apply_defense_shred(effect_key: StringName, value: int, duration: float) -> void:
	var was_active := _defense_shred_effects.has(effect_key)
	_apply_number_status(_defense_shred_effects, effect_key, value, duration)
	if not was_active:
		play_follow_effect(
			"res://assets/effects/common/armor_break_mark_strip.png",
			duration,
			6,
			6,
			12.0,
			Vector2(92.0, 92.0),
			true
		)


func apply_resistance_shred(effect_key: StringName, value: int, duration: float) -> void:
	var was_active := _resistance_shred_effects.has(effect_key)
	_apply_number_status(_resistance_shred_effects, effect_key, value, duration)
	if not was_active:
		play_follow_effect(
			"res://assets/effects/common/resistance_shred_mark_strip.png",
			duration,
			6,
			6,
			12.0,
			Vector2(92.0, 92.0),
			true
		)


func apply_physical_vulnerability(effect_key: StringName, multiplier: float, duration: float) -> void:
	var was_active := _physical_vulnerability_effects.has(effect_key)
	_apply_multiplier_status(_physical_vulnerability_effects, effect_key, multiplier, duration)
	if not was_active:
		_play_fragile_effect(duration)


func apply_magic_vulnerability(effect_key: StringName, multiplier: float, duration: float) -> void:
	var was_active := _magic_vulnerability_effects.has(effect_key)
	_apply_multiplier_status(_magic_vulnerability_effects, effect_key, multiplier, duration)
	if not was_active:
		_play_fragile_effect(duration)


func apply_dot(effect_key: StringName, damage_per_sec: float, damage_type: int, duration: float, tick_interval: float = 1.0) -> void:
	if damage_per_sec <= 0.0 or duration <= 0.0:
		return
	var was_active := _dot_effects.has(effect_key)
	var interval: float = max(tick_interval, 0.1)
	_dot_effects[effect_key] = {
		"damage_per_sec": damage_per_sec,
		"damage_type": damage_type,
		"remaining": duration,
		"tick_interval": interval,
		"tick_timer": interval,
		"carry": 0.0
	}
	if not was_active:
		_play_dot_effect(damage_type, duration)


func get_runtime_id() -> int:
	return runtime_id


func get_current_cell() -> Vector2i:
	return current_cell


## 怪当前身体覆盖到的格子集合（按 global_position ± footprint 半径采四角去重）。
## 居中时返回 1 格；卡在格子交界时返回 2 格（极少数贴角 4 格）。瞄准命中判定用它而非单一 current_cell。
func get_footprint_cells() -> Array[Vector2i]:
	var map_manager: Node = get_map_manager()
	if map_manager == null or not map_manager.has_method("world_to_cell"):
		return [current_cell]
	var radius: float = float(cfg.get("footprint_radius_tiles", FOOTPRINT_RADIUS_TILES)) * CELL_SIZE
	var cells: Array[Vector2i] = []
	for corner: Vector2 in [Vector2(-radius, -radius), Vector2(radius, -radius), Vector2(-radius, radius), Vector2(radius, radius)]:
		var c: Vector2i = map_manager.world_to_cell(global_position + corner)
		if not cells.has(c):
			cells.append(c)
	if cells.is_empty():
		cells.append(current_cell)
	return cells


func get_attack_range_tiles() -> int:
	return _attack_controller.get_attack_range_tiles() if _attack_controller != null else int(cfg.get("attack_range", 0))


func recalc_path() -> void:
	if _movement_controller != null:
		_movement_controller.recalc_path()


func set_blocked(blocker_runtime_id: int, block_slot: int = 0, block_slot_count: int = 1) -> void:
	if _movement_controller == null:
		return
	if _movement_controller.get_blocker_runtime_id() != blocker_runtime_id:
		_attack_controller.reset_attack_timer()
	_movement_controller.set_blocked(blocker_runtime_id, block_slot, block_slot_count)


func clear_blocked() -> void:
	if _movement_controller != null:
		_movement_controller.clear_blocked()


func is_blocked() -> bool:
	return _movement_controller != null and _movement_controller.is_blocked()


func get_blocker_runtime_id() -> int:
	return _movement_controller.get_blocker_runtime_id() if _movement_controller != null else -1


func get_path_progress_score() -> float:
	return _movement_controller.get_path_progress_score() if _movement_controller != null else 0.0


func get_effective_move_speed() -> float:
	return _movement_controller.get_effective_move_speed() if _movement_controller != null else max(float(cfg.get("move_speed", 1.0)), 0.05)


func set_external_move_speed_multiplier(value: float) -> void:
	if _movement_controller != null:
		_movement_controller.set_external_move_speed_multiplier(value)


func get_effective_attack_speed() -> float:
	var relic_add := 0.0
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_buff_effect_total_for_enemy"):
		relic_add += float(run_state.get_buff_effect_total_for_enemy(&"enemy_attack_speed_add", cfg))
	return CombatMath.clamp_attack_speed(float(cfg.get("attack_speed", 100.0)) + _external_attack_speed_add + relic_add)


func set_external_attack_speed_add(value: float) -> void:
	_external_attack_speed_add = value


func set_facing(direction: Vector2i) -> void:
	var normalized := _normalize_visual_direction(direction)
	if facing == normalized:
		return
	facing = normalized
	_refresh_visual_facing()


func play_attack_lunge() -> void:
	if _visual_root == null:
		return
	var normalized := _normalize_visual_direction(facing)
	var forward := Vector2(float(normalized.x), float(normalized.y))
	if forward.length_squared() <= 0.0:
		return
	if _attack_lunge_tween != null and _attack_lunge_tween.is_valid():
		_attack_lunge_tween.kill()
	_visual_root.position = Vector2.ZERO
	_visual_root.rotation_degrees = 0.0
	_attack_lunge_tween = create_tween()
	_attack_lunge_tween.set_trans(Tween.TRANS_QUAD)
	_attack_lunge_tween.set_ease(Tween.EASE_OUT)
	_attack_lunge_tween.tween_property(_visual_root, "position", forward * ATTACK_LUNGE_DISTANCE, ATTACK_LUNGE_IN_SECONDS)
	_attack_lunge_tween.parallel().tween_property(_visual_root, "rotation_degrees", _get_attack_lunge_rotation(normalized), ATTACK_LUNGE_IN_SECONDS)
	_attack_lunge_tween.tween_property(_visual_root, "position", Vector2.ZERO, ATTACK_LUNGE_OUT_SECONDS)
	_attack_lunge_tween.parallel().tween_property(_visual_root, "rotation_degrees", 0.0, ATTACK_LUNGE_OUT_SECONDS)


func _update_status_view() -> void:
	if _status_view != null and _status_view.has_method("set_hp"):
		_status_view.set_hp(current_hp, max_hp)
	if _status_view != null and _status_view.has_method("set_shield"):
		_status_view.set_shield(_shield_hp, _max_shield_hp)


func _play_hit_effect(damage_type_value: int = GameEnums.DAMAGE_PHYSICAL) -> void:
	spawn_one_shot_effect({
		"texture_path": _default_impact_texture_path(damage_type_value),
		"follow_target": self,
		"local_position": VISUAL_OFFSET,
		"hframes": 6,
		"frame_count": 6,
		"fps": 18.0,
		"size": DEFAULT_IMPACT_SIZE,
		"z_index": 24
	})
	_request_audio_cue(_impact_sfx_for_damage_type(damage_type_value))


func _refresh_fog_visibility() -> void:
	var map_manager := get_map_manager()
	if map_manager == null or not map_manager.has_method("is_discovered"):
		visible = true
		return
	var position_cell: Vector2i = map_manager.world_to_cell(global_position) if map_manager.has_method("world_to_cell") else current_cell
	visible = map_manager.is_discovered(position_cell)


func get_map_manager() -> Node:
	return get_node_or_null("../../../Managers/MapManager")


func get_enemy_manager() -> Node:
	return get_node_or_null("../../../Managers/EnemyManager")


func get_unit_manager() -> Node:
	return get_node_or_null("../../../Managers/UnitManager")


func get_building_manager() -> Node:
	return get_node_or_null("../../../Managers/BuildingManager")


func _get_effect_root() -> Node:
	return get_node_or_null("../../EffectRoot")


func spawn_one_shot_effect(payload: Dictionary) -> Node:
	var effect_root := _get_effect_root()
	var effect_parent: Node = effect_root if effect_root != null else self
	var effect := OneShotEffect.new()
	effect_parent.add_child(effect)
	effect.setup(payload)
	return effect


func play_follow_effect(
	texture_path: String,
	duration: float,
	hframes: int = 6,
	frame_count: int = 6,
	fps: float = 18.0,
	size: Vector2 = DEFAULT_STATUS_EFFECT_SIZE,
	loop: bool = false,
	local_position: Vector2 = VISUAL_OFFSET,
	z_index_value: int = 24
) -> void:
	spawn_one_shot_effect({
		"texture_path": texture_path,
		"follow_target": self,
		"local_position": local_position,
		"hframes": hframes,
		"frame_count": frame_count,
		"fps": fps,
		"duration": duration,
		"size": size,
		"loop": loop,
		"z_index": z_index_value
	})


func spawn_world_effect(
	texture_path: String,
	position_value: Vector2,
	duration: float,
	hframes: int = 6,
	frame_count: int = 6,
	fps: float = 18.0,
	size: Vector2 = DEFAULT_STATUS_EFFECT_SIZE,
	rotation_value: float = 0.0,
	loop: bool = false,
	z_index_value: int = 24
) -> void:
	spawn_one_shot_effect({
		"texture_path": texture_path,
		"position": position_value,
		"rotation": rotation_value,
		"hframes": hframes,
		"frame_count": frame_count,
		"fps": fps,
		"duration": duration,
		"size": size,
		"loop": loop,
		"z_index": z_index_value
	})


func _play_fragile_effect(duration: float) -> void:
	play_follow_effect(
		"res://assets/effects/auras/debuff_fragile_aura_strip.png",
		duration,
		8,
		8,
		10.0,
		Vector2(112.0, 112.0),
		true,
		VISUAL_OFFSET,
		23
	)


func _play_dot_effect(damage_type_value: int, duration: float) -> void:
	var texture_path := "res://assets/effects/common/psychic_dot_aura_strip.png"
	if damage_type_value == GameEnums.DAMAGE_PHYSICAL:
		texture_path = "res://assets/effects/common/burn_dot_small_strip.png"
	play_follow_effect(
		texture_path,
		duration,
		6,
		6,
		10.0,
		Vector2(96.0, 96.0),
		true,
		VISUAL_OFFSET,
		22
	)


func _play_push_pull_effect(direction: Vector2i) -> void:
	var direction_vector := Vector2(direction)
	if direction_vector.length_squared() <= 0.001:
		return
	_play_directional_streak_effect(global_position, direction_vector)


func _play_directional_streak_effect(position_value: Vector2, direction_vector: Vector2) -> void:
	if direction_vector.length_squared() <= 0.001:
		return
	spawn_world_effect(
		"res://assets/effects/common/push_pull_streak_strip.png",
		position_value,
		0.32,
		6,
		6,
		18.0,
		Vector2(150.0, 72.0),
		direction_vector.angle(),
		false,
		25
	)


func _play_shield_absorb_effect() -> void:
	var texture_path := "res://assets/effects/auras/shield_absorb_aura_strip.png"
	if enemy_id == &"shieldguard":
		texture_path = "res://assets/effects/enemies/shieldguard_shield_absorb_strip.png"
	play_follow_effect(
		texture_path,
		0.45,
		6 if enemy_id == &"shieldguard" else 8,
		6 if enemy_id == &"shieldguard" else 8,
		18.0,
		Vector2(116.0, 116.0),
		false,
		VISUAL_OFFSET,
		25
	)


func _play_defeat_effect() -> void:
	if cfg.has("death_area_damage"):
		spawn_world_effect(
			"res://assets/effects/enemies/originium_slug_death_burst_strip.png",
			global_position,
			0.42,
			6,
			6,
			16.0,
			Vector2(144.0, 144.0),
			0.0,
			false,
			25
		)
	elif cfg.has("death_spawn"):
		spawn_world_effect(
			"res://assets/effects/enemies/originium_slug_split_puff_strip.png",
			global_position,
			0.5,
			6,
			6,
			14.0,
			Vector2(144.0, 112.0),
			0.0,
			false,
			25
		)


func _get_blocker() -> Node:
	var unit_manager: Node = get_unit_manager()
	return unit_manager.get_unit_by_runtime_id(get_blocker_runtime_id()) if unit_manager != null else null


func _setup_movement_controller() -> void:
	if _movement_controller == null or not is_instance_valid(_movement_controller):
		_movement_controller = EnemyMovementController.new()
		add_child(_movement_controller)
	_movement_controller.setup(self)
	_refresh_status_multipliers()


func _setup_attack_controller() -> void:
	if _attack_controller == null or not is_instance_valid(_attack_controller):
		_attack_controller = EnemyAttackController.new()
		add_child(_attack_controller)
	_attack_controller.setup(self)


func _setup_visual_sprite() -> void:
	_has_visual_sprite = false
	var texture := _load_visual_texture()
	if texture == null:
		queue_redraw()
		return
	if _visual_root == null:
		_visual_root = Node2D.new()
		_visual_root.name = "VisualRoot"
		_visual_root.unique_name_in_owner = true
		add_child(_visual_root)
	_idle_motion_root = _get_idle_motion_root()
	var sprite := _get_or_create_idle_sprite()
	if sprite == null:
		return
	sprite.texture = texture
	sprite.centered = true
	sprite.position = VISUAL_OFFSET
	sprite.scale = Vector2.ONE * (VISUAL_DISPLAY_SIZE / VISUAL_TEXTURE_SIZE)
	sprite.flip_h = _should_visual_face_left(facing)
	sprite.z_index = VISUAL_Z_INDEX
	_apply_visual_modulate(sprite)
	_has_visual_sprite = true
	_start_idle_motion()
	queue_redraw()


## 占位换色（凑凑企鹅 = 奶龙贴图染冷色）：cfg.visual_modulate = [r,g,b,(a)]。
func _apply_visual_modulate(sprite: Sprite2D) -> void:
	var raw: Variant = cfg.get("visual_modulate", null)
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 3:
		var m: Array = raw
		var a := float(m[3]) if m.size() >= 4 else 1.0
		sprite.self_modulate = Color(float(m[0]), float(m[1]), float(m[2]), a)
	else:
		sprite.self_modulate = Color.WHITE


func _get_idle_motion_root() -> Node2D:
	if _visual_root == null:
		return null
	var root := _visual_root.get_node_or_null(IDLE_MOTION_ROOT_NAME) as Node2D
	if root == null:
		root = Node2D.new()
		root.name = IDLE_MOTION_ROOT_NAME
		root.unique_name_in_owner = true
		_visual_root.add_child(root)
	return root


func _get_or_create_idle_sprite() -> Sprite2D:
	if _idle_motion_root == null:
		return null
	var sprite := _idle_motion_root.get_node_or_null("IdleSprite") as Sprite2D
	if sprite != null:
		return sprite
	var legacy_sprite: Sprite2D = null
	if _visual_root != null:
		legacy_sprite = _visual_root.get_node_or_null("IdleSprite") as Sprite2D
	if legacy_sprite != null:
		_visual_root.remove_child(legacy_sprite)
		_idle_motion_root.add_child(legacy_sprite)
		return legacy_sprite
	sprite = Sprite2D.new()
	sprite.name = "IdleSprite"
	_idle_motion_root.add_child(sprite)
	return sprite


func _start_idle_motion() -> void:
	if _idle_motion_root == null:
		return
	if _idle_motion_tween != null and _idle_motion_tween.is_valid():
		_idle_motion_tween.kill()
	_idle_motion_root.position = Vector2.ZERO
	_idle_motion_root.scale = Vector2.ONE
	_idle_motion_root.rotation_degrees = 0.0
	if not bool(cfg.get("idle_motion_enabled", true)):
		return
	var cycle_seconds := randf_range(
		float(cfg.get("idle_motion_min_seconds", IDLE_MOTION_MIN_SECONDS)),
		float(cfg.get("idle_motion_max_seconds", IDLE_MOTION_MAX_SECONDS))
	)
	var breath_scale := _get_idle_motion_breath_scale()
	var bob_y := _get_idle_motion_bob_y()
	var start_delay := randf_range(0.0, cycle_seconds)
	if start_delay <= 0.01:
		_begin_idle_motion_loop(cycle_seconds, breath_scale, bob_y)
		return
	_idle_motion_tween = create_tween()
	_idle_motion_tween.tween_interval(start_delay)
	_idle_motion_tween.tween_callback(Callable(self, "_begin_idle_motion_loop").bind(cycle_seconds, breath_scale, bob_y))


func _begin_idle_motion_loop(cycle_seconds: float, breath_scale: Vector2, bob_y: float) -> void:
	if _idle_motion_root == null:
		return
	var half_cycle: float = max(cycle_seconds * 0.5, 0.1)
	_idle_motion_tween = create_tween()
	_idle_motion_tween.set_loops()
	_idle_motion_tween.set_trans(Tween.TRANS_SINE)
	_idle_motion_tween.set_ease(Tween.EASE_IN_OUT)
	_idle_motion_tween.tween_property(_idle_motion_root, "scale", breath_scale, half_cycle)
	_idle_motion_tween.parallel().tween_property(_idle_motion_root, "position", Vector2(0.0, bob_y), half_cycle)
	_idle_motion_tween.tween_property(_idle_motion_root, "scale", Vector2.ONE, half_cycle)
	_idle_motion_tween.parallel().tween_property(_idle_motion_root, "position", Vector2.ZERO, half_cycle)


func _get_idle_motion_breath_scale() -> Vector2:
	var default_scale := IDLE_MOTION_FLYING_BREATH_SCALE if _is_flying_enemy() else IDLE_MOTION_GROUND_BREATH_SCALE
	return Vector2(
		float(cfg.get("idle_motion_scale_x", default_scale.x)),
		float(cfg.get("idle_motion_scale_y", default_scale.y))
	)


func _get_idle_motion_bob_y() -> float:
	var default_bob_y := IDLE_MOTION_FLYING_BOB_Y if _is_flying_enemy() else IDLE_MOTION_GROUND_BOB_Y
	return float(cfg.get("idle_motion_bob_y", default_bob_y))


func _is_flying_enemy() -> bool:
	return StringName(cfg.get("move_type", "ground")) == &"flying"


func _refresh_visual_facing() -> void:
	if _idle_motion_root == null:
		return
	var sprite := _idle_motion_root.get_node_or_null("IdleSprite") as Sprite2D
	if sprite != null:
		sprite.flip_h = _should_visual_face_left(facing)


func _should_visual_face_left(direction: Vector2i) -> bool:
	var normalized := _normalize_visual_direction(direction)
	return normalized == Vector2i.LEFT or normalized == Vector2i.UP


func _normalize_visual_direction(direction: Vector2i) -> Vector2i:
	if direction == Vector2i.ZERO:
		return Vector2i.RIGHT
	if abs(direction.x) >= abs(direction.y):
		return Vector2i.RIGHT if direction.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0 else Vector2i.UP


func _get_attack_lunge_rotation(direction: Vector2i) -> float:
	return -ATTACK_LUNGE_ROTATION_DEGREES if _should_visual_face_left(direction) else ATTACK_LUNGE_ROTATION_DEGREES


func _load_visual_texture() -> Texture2D:
	var visual_key := String(cfg.get("visual_key", enemy_id)).strip_edges()
	if visual_key.is_empty():
		visual_key = String(enemy_id)
	var path := "%s/%s/%s/%s_%s_000.png" % [VISUAL_TEXTURE_ROOT, visual_key, VISUAL_IDLE_ANIM, visual_key, VISUAL_IDLE_ANIM]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _setup_boss_controller() -> void:
	if _boss_controller != null and is_instance_valid(_boss_controller):
		_boss_controller.queue_free()
	_boss_controller = null
	var phases: Array = cfg.get("phases", [])
	var should_enable := StringName(cfg.get("behavior_type", "normal")) == &"boss" or not phases.is_empty()
	if not should_enable:
		return
	_boss_controller = BossController.new()
	add_child(_boss_controller)
	_boss_controller.setup(self, cfg)
	if not _boss_controller.is_enabled():
		_boss_controller.queue_free()
		_boss_controller = null


func _apply_phase_cfg(phase_cfg: Dictionary) -> void:
	var scaled_phase := phase_cfg.duplicate(true)
	DifficultyScale.apply_stat_scale(scaled_phase, _stat_scale, _max_hp_scale)
	cfg.merge(scaled_phase, true)
	if _movement_controller != null:
		_movement_controller.refresh_path_mode()
	max_hp = int(cfg.get("max_hp", max_hp))
	current_hp = max_hp
	_max_shield_hp = max(int(cfg.get("shield_hp", 0)), 0)
	_shield_hp = _max_shield_hp
	if _attack_controller != null:
		_attack_controller.set_attack_cooldown_from_cfg()
	_recalc_path_after_phase_change()
	_update_title_label()
	_update_status_view()
	_debug_log("敌人 %s#%d 转入第%d阶段，HP %d/%d" % [_debug_name(), runtime_id, int(phase_cfg.get("phase", 0)), current_hp, max_hp])


func _recalc_path_after_phase_change() -> void:
	if not is_blocked():
		recalc_path()


func _update_title_label() -> void:
	var label: Label = get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.theme = AppTheme.get_theme()
		label.text = String(cfg.get("name", enemy_id))
		label.position = Vector2(-30.0, -58.0)


func _parse_damage_type(raw_type: String) -> int:
	match raw_type:
		"magic":
			return GameEnums.DAMAGE_MAGIC
		"true":
			return GameEnums.DAMAGE_TRUE
		_:
			return GameEnums.DAMAGE_PHYSICAL


func _clear_temporary_status() -> void:
	_move_speed_effects.clear()
	_defense_shred_effects.clear()
	_resistance_shred_effects.clear()
	_physical_vulnerability_effects.clear()
	_magic_vulnerability_effects.clear()
	_dot_effects.clear()
	_stun_timer = 0.0
	_bind_timer = 0.0
	_refresh_status_multipliers()


func _tick_status_effects(delta: float) -> void:
	_stun_timer = max(_stun_timer - delta, 0.0)
	_bind_timer = max(_bind_timer - delta, 0.0)
	_tick_status_dict(_move_speed_effects, delta)
	_tick_status_dict(_defense_shred_effects, delta)
	_tick_status_dict(_resistance_shred_effects, delta)
	_tick_status_dict(_physical_vulnerability_effects, delta)
	_tick_status_dict(_magic_vulnerability_effects, delta)
	_tick_dot_effects(delta)
	_refresh_status_multipliers()


func _tick_status_dict(status_dict: Dictionary, delta: float) -> void:
	for effect_key in status_dict.keys().duplicate():
		var entry: Dictionary = status_dict[effect_key]
		entry["remaining"] = float(entry.get("remaining", 0.0)) - delta
		if float(entry.get("remaining", 0.0)) <= 0.0:
			status_dict.erase(effect_key)
		else:
			status_dict[effect_key] = entry


func _tick_dot_effects(delta: float) -> void:
	for effect_key in _dot_effects.keys().duplicate():
		var entry: Dictionary = _dot_effects[effect_key]
		entry["remaining"] = float(entry.get("remaining", 0.0)) - delta
		entry["tick_timer"] = float(entry.get("tick_timer", 1.0)) - delta
		var tick_interval: float = max(float(entry.get("tick_interval", 1.0)), 0.1)
		while float(entry.get("tick_timer", 0.0)) <= 0.0 and float(entry.get("remaining", 0.0)) > 0.0:
			entry["tick_timer"] = float(entry.get("tick_timer", 0.0)) + tick_interval
			entry["carry"] = float(entry.get("carry", 0.0)) + float(entry.get("damage_per_sec", 0.0)) * tick_interval
			var damage_value := int(floor(float(entry.get("carry", 0.0))))
			if damage_value > 0:
				entry["carry"] = float(entry.get("carry", 0.0)) - float(damage_value)
				receive_damage(damage_value, int(entry.get("damage_type", GameEnums.DAMAGE_MAGIC)))
				if _is_dead:
					return
		if float(entry.get("remaining", 0.0)) <= 0.0:
			_dot_effects.erase(effect_key)
		else:
			_dot_effects[effect_key] = entry


func _tick_regeneration(delta: float) -> void:
	_regen_effect_cooldown = max(_regen_effect_cooldown - delta, 0.0)
	var regen_per_sec: float = max(float(cfg.get("regen_per_sec", 0.0)), 0.0)
	if regen_per_sec <= 0.0 or current_hp <= 0 or current_hp >= max_hp:
		return
	_regen_carry += regen_per_sec * delta
	var heal_value := int(floor(_regen_carry))
	if heal_value <= 0:
		return
	_regen_carry -= float(heal_value)
	current_hp = min(current_hp + heal_value, max_hp)
	_update_status_view()
	if _regen_effect_cooldown <= 0.0:
		_regen_effect_cooldown = 0.8
		play_follow_effect(
			"res://assets/effects/common/enemy_regen_tick_strip.png",
			0.42,
			6,
			6,
			14.0,
			Vector2(92.0, 92.0),
			false,
			VISUAL_OFFSET,
			23
		)


func _absorb_damage_with_shield(damage_value: int) -> int:
	if _shield_hp <= 0 or damage_value <= 0:
		return 0
	var absorbed: int = min(_shield_hp, damage_value)
	_shield_hp -= absorbed
	return absorbed


func _apply_death_area_damage() -> void:
	var raw_area_cfg: Variant = cfg.get("death_area_damage", {})
	if typeof(raw_area_cfg) != TYPE_DICTIONARY:
		return
	var area_cfg: Dictionary = raw_area_cfg
	if area_cfg.is_empty():
		return
	var radius: int = max(int(area_cfg.get("radius", 1)), 0)
	var damage: int = max(int(area_cfg.get("damage", 0)), 0)
	if damage <= 0:
		return
	var damage_type_value: int = _parse_damage_type(String(area_cfg.get("damage_type", cfg.get("damage_type", "physical"))))
	var unit_manager: Node = get_unit_manager()
	var building_manager: Node = get_building_manager()
	for y in range(current_cell.y - radius, current_cell.y + radius + 1):
		for x in range(current_cell.x - radius, current_cell.x + radius + 1):
			var cell := Vector2i(x, y)
			if unit_manager != null and unit_manager.has_method("get_unit_by_cell"):
				var unit: Node = unit_manager.get_unit_by_cell(cell)
				if unit != null and unit.has_method("receive_damage"):
					unit.receive_damage(damage, damage_type_value, self)
			if building_manager != null and building_manager.has_method("get_building_by_cell"):
				var building: Node = building_manager.get_building_by_cell(cell)
				if building != null and is_instance_valid(building):
					_damage_building(building, damage, damage_type_value)
	_debug_log("敌人 %s#%d 死亡爆发，影响周围 %dx%d 区域，造成%s伤害 %d" % [_debug_name(), runtime_id, radius * 2 + 1, radius * 2 + 1, _damage_type_text(damage_type_value), damage])


func _spawn_death_enemies() -> void:
	var enemy_manager: Node = get_enemy_manager()
	if enemy_manager == null or not enemy_manager.has_method("spawn_enemy"):
		return
	var spawn_entries: Array[Dictionary] = _get_death_spawn_entries()
	var spawn_index := 0
	for spawn_cfg: Dictionary in spawn_entries:
		var spawn_enemy_id := StringName(spawn_cfg.get("enemy_id", ""))
		var count: int = max(int(spawn_cfg.get("count", 1)), 0)
		var radius: int = max(int(spawn_cfg.get("radius", 1)), 0)
		if spawn_enemy_id == StringName() or count <= 0:
			continue
		var spawned_count := 0
		for _index in range(count):
			var spawn_cell: Vector2i = _resolve_death_spawn_cell(spawn_index, radius)
			spawn_index += 1
			if spawn_cell == INVALID_DEATH_SPAWN_CELL:
				_debug_log("敌人 %s#%d 死亡分裂跳过 %s：周围没有合法生成格" % [_debug_name(), runtime_id, String(spawn_enemy_id)])
				continue
			enemy_manager.spawn_enemy(spawn_enemy_id, spawn_cell)
			_play_death_spawn_effect(spawn_cell)
			spawned_count += 1
		if spawned_count > 0:
			_debug_log("敌人 %s#%d 死亡分裂，生成 %d 个 %s" % [_debug_name(), runtime_id, spawned_count, String(spawn_enemy_id)])


func _get_death_spawn_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_spawn: Variant = cfg.get("death_spawn", [])
	if typeof(raw_spawn) == TYPE_DICTIONARY:
		result.append((raw_spawn as Dictionary).duplicate(true))
	elif typeof(raw_spawn) == TYPE_ARRAY:
		for entry_variant: Variant in raw_spawn:
			if typeof(entry_variant) == TYPE_DICTIONARY:
				result.append((entry_variant as Dictionary).duplicate(true))
	return result


func _resolve_death_spawn_cell(spawn_index: int, radius: int) -> Vector2i:
	var map_manager: Node = get_map_manager()
	if map_manager == null:
		return INVALID_DEATH_SPAWN_CELL
	var offsets: Array[Vector2i] = _make_spawn_offsets(radius)
	for attempt in range(offsets.size()):
		var offset: Vector2i = offsets[(spawn_index + attempt) % offsets.size()]
		var candidate := current_cell + offset
		if _can_spawn_death_enemy_at(map_manager, candidate):
			return candidate
	return INVALID_DEATH_SPAWN_CELL


func _make_spawn_offsets(radius: int) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = [Vector2i.ZERO]
	var radius_value: int = max(radius, 0)
	for distance in range(1, radius_value + 1):
		for y in range(-distance, distance + 1):
			for x in range(-distance, distance + 1):
				if max(abs(x), abs(y)) == distance:
					offsets.append(Vector2i(x, y))
	return offsets


func _can_spawn_death_enemy_at(map_manager: Node, cell: Vector2i) -> bool:
	if map_manager == null or not map_manager.is_inside(cell):
		return false
	var cell_data = map_manager.get_cell_data(cell) if map_manager.has_method("get_cell_data") else null
	if cell_data != null and cell_data.is_core:
		return false
	if map_manager.has_method("is_walkable") and not map_manager.is_walkable(cell):
		return false
	return true


func _play_death_spawn_effect(spawn_cell: Vector2i) -> void:
	var map_manager := get_map_manager()
	if map_manager == null or not map_manager.has_method("cell_to_world"):
		return
	spawn_world_effect(
		"res://assets/effects/common/enemy_death_spawn_puff_strip.png",
		map_manager.cell_to_world(spawn_cell),
		0.42,
		6,
		6,
		14.0,
		Vector2(96.0, 80.0),
		0.0,
		false,
		24
	)


func _damage_building(building: Node, damage_value: int, damage_type_value: int) -> void:
	var building_manager: Node = get_building_manager()
	if building_manager != null and building_manager.has_method("damage_building"):
		building_manager.damage_building(int(building.get("runtime_id")), damage_value, damage_type_value)
	elif building != null and building.has_method("receive_damage"):
		building.receive_damage(damage_value, damage_type_value)


func _refresh_status_multipliers() -> void:
	if _movement_controller == null:
		return
	var multiplier := 1.0
	for entry_variant in _move_speed_effects.values():
		var entry: Dictionary = entry_variant
		multiplier = min(multiplier, float(entry.get("value", 1.0)))
	_movement_controller.set_external_move_speed_multiplier(multiplier)


func _apply_number_status(status_dict: Dictionary, effect_key: StringName, value: int, duration: float) -> void:
	if value <= 0 or duration <= 0.0:
		return
	status_dict[effect_key] = {
		"value": value,
		"remaining": duration
	}


func _apply_multiplier_status(status_dict: Dictionary, effect_key: StringName, multiplier: float, duration: float) -> void:
	if multiplier <= 1.0 or duration <= 0.0:
		return
	status_dict[effect_key] = {
		"value": multiplier,
		"remaining": duration
	}


func _is_stunned() -> bool:
	return _stun_timer > 0.0


func _is_movement_locked() -> bool:
	return _bind_timer > 0.0


func _get_effective_defense() -> int:
	var defense_value := float(cfg.get("def", 0))
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_buff_effect_total_for_enemy"):
		defense_value *= 1.0 + float(run_state.get_buff_effect_total_for_enemy(&"enemy_def_percent", cfg))
	return max(int(round(defense_value)) - _sum_number_status(_defense_shred_effects), 0)


func _get_effective_resistance() -> int:
	var resistance_value := float(cfg.get("res", 0))
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_buff_effect_total_for_enemy"):
		resistance_value *= 1.0 + float(run_state.get_buff_effect_total_for_enemy(&"enemy_res_percent", cfg))
	return max(int(round(resistance_value)) - _sum_number_status(_resistance_shred_effects), 0)


func _sum_number_status(status_dict: Dictionary) -> int:
	var total := 0
	for entry_variant in status_dict.values():
		var entry: Dictionary = entry_variant
		total += int(entry.get("value", 0))
	return total


func _get_vulnerability_multiplier(damage_type_value: int) -> float:
	var multiplier := 1.0
	var status_dict := _physical_vulnerability_effects if damage_type_value == GameEnums.DAMAGE_PHYSICAL else _magic_vulnerability_effects
	if damage_type_value != GameEnums.DAMAGE_PHYSICAL and damage_type_value != GameEnums.DAMAGE_MAGIC:
		return multiplier
	for entry_variant in status_dict.values():
		var entry: Dictionary = entry_variant
		multiplier = max(multiplier, float(entry.get("value", 1.0)))
	return multiplier


func _debug_log(message: String) -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.call_group("combat_debug_log", "append_combat_debug", message)


func _debug_name() -> String:
	return String(cfg.get("name", enemy_id))


func _default_impact_texture_path(damage_type_value: int) -> String:
	match damage_type_value:
		GameEnums.DAMAGE_MAGIC:
			return "res://assets/effects/common/impact_arts_small_strip.png"
		GameEnums.DAMAGE_TRUE:
			return "res://assets/effects/common/impact_true_damage_small_strip.png"
		_:
			return "res://assets/effects/common/impact_physical_small_strip.png"


func _damage_type_text(type_value: int) -> String:
	match type_value:
		GameEnums.DAMAGE_MAGIC:
			return "法术"
		GameEnums.DAMAGE_TRUE:
			return "真实"
		_:
			return "物理"


func _impact_sfx_for_damage_type(damage_type_value: int) -> StringName:
	return SFX_IMPACT_ARTS if damage_type_value == GameEnums.DAMAGE_MAGIC else SFX_IMPACT_PHYSICAL


func _request_audio_cue(cue_key: StringName) -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.audio_cue_requested.emit(cue_key)
