extends Node2D

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameplaySettings = preload("res://scripts/core/gameplay_settings.gd")
const OneShotEffect = preload("res://scripts/effects/one_shot_effect.gd")
const ContactShadow = preload("res://scripts/effects/contact_shadow.gd")

const CELL_SIZE := 64.0
const BLOCK_RADIUS_TILES := 0.7071
const DEFAULT_PROJECTILE_SPEED := 520.0
const DEFAULT_PROJECTILE_HIT_RADIUS := 8.0
const DEFAULT_PROJECTILE_LIFETIME := 3.0
const SFX_IMPACT_PHYSICAL := &"impact_physical"
const SFX_IMPACT_ARTS := &"impact_arts"
const SFX_PROJECTILE_PHYSICAL := &"projectile_physical"
const SFX_PROJECTILE_ARTS := &"projectile_arts"
const DEFAULT_IMPACT_SIZE := Vector2(96.0, 96.0)
const DEFAULT_STATUS_EFFECT_SIZE := Vector2(112.0, 112.0)
const TARGET_TYPE_GROUND: StringName = &"ground"
const TARGET_TYPE_FLYING: StringName = &"flying"
const TARGET_TYPE_ALL: StringName = &"all"
const MOVE_TYPE_GROUND: StringName = &"ground"
const MOVE_TYPE_FLYING: StringName = &"flying"
const VISUAL_TEXTURE_ROOT := "res://assets/sprites/units"
const VISUAL_IDLE_ANIM := "idle"
const VISUAL_TEXTURE_SIZE := 128.0
const VISUAL_DISPLAY_SIZE := 72.0
const VISUAL_OFFSET := Vector2(0.0, -8.0)
# 高台格部署时整体上抬，让脚落在台顶面而不是崖底（tile_highland 顶面中心偏上）。
const HIGHLAND_VISUAL_LIFT := Vector2(0.0, -24.0)
const CONTACT_SHADOW_Y := 26.0
const VISUAL_Z_INDEX := 2
const OVERLAY_Z_INDEX := 20
const ATTACK_LUNGE_DISTANCE := 5.0
const ATTACK_LUNGE_ROTATION_DEGREES := 7.0
const ATTACK_LUNGE_IN_SECONDS := 0.055
const ATTACK_LUNGE_OUT_SECONDS := 0.11
const IDLE_MOTION_ROOT_NAME := "IdleMotionRoot"
const IDLE_MOTION_BREATH_SCALE := Vector2(0.99, 1.02)
const IDLE_MOTION_BOB_Y := -1.1
const IDLE_MOTION_MIN_SECONDS := 1.65
const IDLE_MOTION_MAX_SECONDS := 2.35
const SKILL_BEHAVIOR_REGISTRY := {
	&"common_atk_up": "res://scripts/combat/skills/common_atk_up_skill.gd",
	&"guard_hold_line": "res://scripts/combat/skills/guard_hold_line_skill.gd",
	&"guard_decisive_swing": "res://scripts/combat/skills/guard_decisive_swing_skill.gd",
	&"sniper_quintuple_shot": "res://scripts/combat/skills/sniper_quintuple_shot_skill.gd",
	&"sniper_burst_dawn": "res://scripts/combat/skills/sniper_burst_dawn_skill.gd",
	&"caster_overload_permanent": "res://scripts/combat/skills/caster_overload_permanent_skill.gd",
	&"caster_chain_push": "res://scripts/combat/skills/caster_chain_push_skill.gd",
	&"defender_fortify": "res://scripts/combat/skills/defender_fortify_skill.gd",
	&"defender_counter_stance": "res://scripts/combat/skills/defender_counter_stance_skill.gd",
	&"mountain_sweeping_stance": "res://scripts/combat/skills/mountain_sweeping_stance_skill.gd",
	&"zuo_le_risky_venture": "res://scripts/combat/skills/zuo_le_risky_venture_skill.gd",
	&"degenbrecher_silence": "res://scripts/combat/skills/degenbrecher_silence_skill.gd",
	&"surtr_twilight": "res://scripts/combat/skills/surtr_twilight_skill.gd",
	&"narantuya_solar_swallow": "res://scripts/combat/skills/narantuya_solar_swallow_skill.gd",
	&"ray_light": "res://scripts/combat/skills/ray_light_skill.gd",
	&"typhon_eternal_hunt": "res://scripts/combat/skills/typhon_eternal_hunt_skill.gd",
	&"wisadel_saturated_revenge": "res://scripts/combat/skills/wisadel_saturated_revenge_skill.gd",
	&"ifrit_scorched_earth": "res://scripts/combat/skills/ifrit_scorched_earth_skill.gd",
	&"nymph_psychic_collapse": "res://scripts/combat/skills/nymph_psychic_collapse_skill.gd",
	&"goldenglow_clear_shine": "res://scripts/combat/skills/goldenglow_clear_shine_skill.gd",
	&"logos_oblivion": "res://scripts/combat/skills/logos_oblivion_skill.gd",
	&"saria_calcification": "res://scripts/combat/skills/saria_calcification_skill.gd",
	&"penance_thorny_body": "res://scripts/combat/skills/penance_thorny_body_skill.gd",
	&"jessica_saturation_burst": "res://scripts/combat/skills/jessica_saturation_burst_skill.gd",
	&"shu_cycle_of_growth": "res://scripts/combat/skills/shu_cycle_of_growth_skill.gd"
}


var unit_id: StringName
var operator_key: StringName
var operator_name := ""
var runtime_id := -1
var current_cell := Vector2i.ZERO
var facing := Vector2i.RIGHT
var cfg: Dictionary = {}
var max_hp := 1
var current_hp := 1
var sp := 0.0
var atk := 1
var defense := 0
var resistance := 0
var block_count := 0
var attack_interval := 1.0
var attack_speed := 100.0
var attack_multiplier := 1.0
# 不含盟约/光环加成的基础最大生命；max_hp 为含加成的实时上限。
var _base_max_hp := 1
# 统一外部修正层：按来源通道（&"aura" / &"covenant"）整组存放修正，
# effective getter 汇总各通道。详见 set_modifier_channel。
var _mod_channels: Dictionary = {}
var damage_type := GameEnums.DAMAGE_PHYSICAL
var target_type: StringName = TARGET_TYPE_GROUND
var range_pattern: Array[Vector2i] = []

var _attack_timer := 0.0
var _blocked_enemy_ids: Array[int] = []
var _current_target_runtime_id := -1
var _is_dead := false
var _damage_reduction_effects: Dictionary = {}
var _timed_modifier_effects: Dictionary = {}
var _relic_sp_periodic_timers: Dictionary = {}
var _registered_range_outline_ids: Array[StringName] = []
var _idle_motion_root: Node2D = null
var _idle_motion_tween: Tween = null
var _attack_lunge_tween: Tween = null

@onready var _status_view: Node = get_node_or_null("%StatusView")
@onready var _skill_behavior: Node = get_node_or_null("%SkillBehavior")
@onready var _visual_root: Node2D = get_node_or_null("%VisualRoot") as Node2D


func _ready() -> void:
	add_to_group("units")


func _exit_tree() -> void:
	_cleanup_skill_behavior()
	clear_all_skill_range_outlines()


func _process(delta: float) -> void:
	if _is_dead:
		return
	if not _is_combat_simulation_active():
		return
	# UnitActor 只保留公共战斗循环；角色特化技能通过 SkillBehavior 子节点接入。
	if _skill_behavior != null and _skill_behavior.has_method("tick"):
		_skill_behavior.tick(delta)
	_tick_damage_reduction_effects(delta)
	_tick_timed_modifier_effects(delta)
	_recover_sp(delta)
	_tick_periodic_relic_sp(delta)
	_try_auto_cast_skill()
	_refresh_blocking()
	_tick_attack(delta)


func setup_from_cfg(new_unit_id: StringName, new_cfg: Dictionary, spawn_cell: Vector2i, new_facing: Vector2i, new_operator_key: StringName = StringName(), new_operator_name: String = "") -> void:
	unit_id = new_unit_id
	operator_key = new_operator_key if new_operator_key != StringName() else new_unit_id
	operator_name = new_operator_name.strip_edges()
	cfg = new_cfg.duplicate(true)
	current_cell = spawn_cell
	facing = new_facing
	_base_max_hp = int(cfg.get("max_hp", 1))
	var run_state = AppRefs.run_state()
	max_hp = _calculate_effective_max_hp()
	current_hp = max_hp
	atk = int(cfg.get("atk", 1))
	defense = int(cfg.get("def", 0))
	resistance = int(cfg.get("res", 0))
	block_count = int(cfg.get("block", 0))
	attack_interval = max(float(cfg.get("attack_interval", 1.0)), 0.05)
	attack_speed = float(cfg.get("attack_speed", 100.0))
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		atk = max(int(round(float(atk) * (1.0 + float(run_state.get_buff_effect_total_for_unit(&"unit_base_atk_percent", cfg))))), 1)
		block_count = max(block_count + int(round(float(run_state.get_buff_effect_total_for_unit(&"unit_block_add", cfg)))), 0)
	attack_multiplier = 1.0
	_mod_channels.clear()
	_damage_reduction_effects.clear()
	_timed_modifier_effects.clear()
	_relic_sp_periodic_timers.clear()
	damage_type = parse_damage_type(String(cfg.get("damage_type", "physical")))
	target_type = parse_target_type(String(cfg.get("target_type", "ground")))
	range_pattern = parse_range_pattern(cfg.get("range_pattern", []))
	sp = clamp(_get_initial_sp_value(), 0.0, float(cfg.get("sp_max", 0.0)))
	_attack_timer = attack_interval
	_blocked_enemy_ids.clear()
	_current_target_runtime_id = -1
	_is_dead = false
	global_position = get_map_manager().cell_to_world(spawn_cell) if get_map_manager() != null else Vector2.ZERO
	if get_map_manager() != null:
		var spawn_data = get_map_manager().get_cell_data(spawn_cell)
		if spawn_data != null and spawn_data.terrain == &"highland":
			global_position += HIGHLAND_VISUAL_LIFT
	_ensure_contact_shadow()
	var label := get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.theme = AppTheme.get_theme()
		label.text = _debug_name()
		label.position = Vector2(-32.0, -64.0)
		label.size = Vector2(64.0, 23.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.z_index = OVERLAY_Z_INDEX
	if _status_view is CanvasItem:
		(_status_view as CanvasItem).z_index = OVERLAY_Z_INDEX
	_setup_visual_sprite()
	_configure_skill_behavior()
	if _skill_behavior != null and _skill_behavior.has_method("setup"):
		_skill_behavior.setup(self)
	if _skill_behavior != null and _skill_behavior.has_method("on_deployed"):
		_skill_behavior.on_deployed()
	_apply_on_deploy_relic_effects()
	_update_status_view()


func receive_damage(value: int, damage_type_value: int, source: Node = null, pooled: bool = false) -> void:
	# 坚守 3 人：把“理想伤害”均摊给所有坚守干员，各自用自身防御/法抗结算。
	# pooled=true 表示这是均摊后的份额，跳过再均摊以避免递归。
	if not pooled and _try_steadfast_pool(value, damage_type_value, source):
		return
	var final_damage := value
	if damage_type_value == GameEnums.DAMAGE_PHYSICAL:
		final_damage = CombatMath.calc_physical_damage(value, get_effective_defense())
	elif damage_type_value == GameEnums.DAMAGE_MAGIC:
		final_damage = CombatMath.calc_magic_damage(value, get_effective_resistance())
	final_damage = max(int(round(float(final_damage) * _get_damage_reduction_multiplier())), 0)
	if _skill_behavior != null and _skill_behavior.has_method("modify_final_incoming_damage"):
		final_damage = max(int(_skill_behavior.modify_final_incoming_damage(final_damage, value, damage_type_value, source)), 0)
	var hp_before := current_hp
	current_hp = max(current_hp - final_damage, 0)
	_update_status_view()
	_play_hit_effect(damage_type_value)
	_debug_log("单位 %s#%d 受到%s伤害：原始 %d，结算 %d，HP %d/%d" % [_debug_name(), runtime_id, _damage_type_text(damage_type_value), value, final_damage, current_hp, max_hp])
	if final_damage > 0 and current_hp < hp_before and _skill_behavior != null and _skill_behavior.has_method("after_receive_damage"):
		_skill_behavior.after_receive_damage(source, final_damage)
	if final_damage > 0 and current_hp < hp_before:
		gain_sp(_get_relic_sp_on_hit_add())
	if current_hp == 0:
		_die()


func receive_heal(value: int, source: Node = null) -> void:
	if _is_dead:
		return
	var final_value: int = max(value, 0)
	if _skill_behavior != null and _skill_behavior.has_method("modify_incoming_heal"):
		final_value = max(int(_skill_behavior.modify_incoming_heal(final_value, source)), 0)
	if final_value <= 0:
		return
	current_hp = min(current_hp + final_value, max_hp)
	_update_status_view()
	_play_heal_effect()


func lose_hp(value: int, allow_death: bool = false) -> void:
	if _is_dead:
		return
	var final_value: int = max(value, 0)
	if final_value <= 0:
		return
	current_hp = current_hp - final_value if allow_death else max(current_hp - final_value, 1)
	current_hp = max(current_hp, 0)
	_update_status_view()
	if current_hp == 0:
		_die()


# 收敛的死亡入口：先判定不屈复活，否则正式移除。
func _die() -> void:
	if _is_dead:
		return
	var revive_chance := get_effective_revive_chance()
	if revive_chance > 0.0 and randf() < revive_chance:
		current_hp = max_hp
		_update_status_view()
		_play_heal_effect()
		_debug_log("单位 %s#%d 触发不屈，原地满血复活" % [_debug_name(), runtime_id])
		return
	_is_dead = true
	_debug_log("单位 %s#%d 死亡" % [_debug_name(), runtime_id])
	var unit_manager := get_unit_manager()
	if unit_manager != null and unit_manager.has_method("remove_unit"):
		unit_manager.remove_unit(runtime_id, GameEnums.UNIT_REMOVE_DEAD)


func apply_damage_reduction(effect_key: StringName, multiplier: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var was_active := _damage_reduction_effects.has(effect_key)
	_damage_reduction_effects[effect_key] = {
		"multiplier": clamp(multiplier, 0.0, 1.0),
		"remaining": duration
	}
	if not was_active:
		play_follow_effect(
			"res://assets/effects/auras/barrier_guard_loop_strip.png",
			duration,
			8,
			8,
			10.0,
			Vector2(112.0, 112.0),
			true
		)


func gain_sp(value: int) -> void:
	if _is_skill_active():
		return
	sp = min(sp + value, float(cfg.get("sp_max", 0)))


func can_cast_skill() -> bool:
	if not _is_combat_simulation_active():
		return false
	if _skill_behavior != null and _skill_behavior.has_method("can_cast"):
		return bool(_skill_behavior.can_cast())
	var sp_max := float(cfg.get("sp_max", 0.0))
	return sp_max > 0.0 and sp >= sp_max


func cast_skill() -> void:
	if not can_cast_skill():
		return
	var skill_name := get_skill_name()
	var cast_ok := false
	if _skill_behavior != null and _skill_behavior.has_method("cast"):
		cast_ok = bool(_skill_behavior.cast())
	else:
		sp = 0.0
		cast_ok = true
	if cast_ok:
		_debug_log("单位 %s#%d 释放技能：%s" % [_debug_name(), runtime_id, skill_name])
		var event_bus = AppRefs.event_bus()
		if event_bus != null:
			event_bus.unit_skill_cast.emit(runtime_id, unit_id)


func get_skill_name() -> String:
	if _skill_behavior != null and _skill_behavior.has_method("get_skill_name"):
		return String(_skill_behavior.get_skill_name())
	return String(cfg.get("skill_name", cfg.get("skill_id", "未配置技能")))


func get_skill_description() -> String:
	if _skill_behavior != null and _skill_behavior.has_method("get_skill_description"):
		return String(_skill_behavior.get_skill_description())
	return String(cfg.get("skill_description", "暂无技能描述。"))


func get_skill_active_remaining() -> float:
	if _skill_behavior != null and _skill_behavior.has_method("get_active_remaining"):
		return float(_skill_behavior.get_active_remaining())
	return 0.0


func get_skill_ammo_status() -> Dictionary:
	if _skill_behavior != null and _skill_behavior.has_method("get_ammo_status"):
		var status: Variant = _skill_behavior.get_ammo_status()
		if typeof(status) == TYPE_DICTIONARY:
			return (status as Dictionary).duplicate(true)
	return {}


func refresh_status_view() -> void:
	_update_status_view()


func is_skill_active() -> bool:
	return _is_skill_active()


func get_runtime_id() -> int:
	return runtime_id


func get_current_cell() -> Vector2i:
	return current_cell


func get_block_count() -> int:
	return block_count


func get_attack_targets() -> Array:
	var targets: Array = []
	for enemy in get_all_enemies():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not _can_detect_enemy(enemy):
			continue
		if not _can_target_enemy(enemy):
			continue
		if _blocked_enemy_ids.has(enemy.get_runtime_id()):
			targets.append(enemy)
			continue
		if _is_enemy_in_attack_range(enemy):
			targets.append(enemy)
	return targets


func get_current_target() -> Node:
	var enemy_manager := get_enemy_manager()
	return enemy_manager.get_enemy_by_runtime_id(_current_target_runtime_id) if enemy_manager != null else null


func get_sp_ratio() -> float:
	var sp_max := float(cfg.get("sp_max", 0.0))
	return sp / sp_max if sp_max > 0.0 else 0.0


func get_redeploy_sec() -> float:
	return float(cfg.get("redeploy_sec", 0.0))


func get_blocked_enemy_ids() -> Array[int]:
	return _blocked_enemy_ids.duplicate()


func get_blocked_enemies() -> Array:
	var enemies: Array = []
	var enemy_manager := get_enemy_manager()
	if enemy_manager == null:
		return enemies
	for enemy_runtime_id in _blocked_enemy_ids:
		var enemy = enemy_manager.get_enemy_by_runtime_id(enemy_runtime_id)
		if enemy != null and is_instance_valid(enemy):
			enemies.append(enemy)
	return enemies


func get_all_enemies() -> Array:
	var enemy_manager := get_enemy_manager()
	if enemy_manager == null or not enemy_manager.has_method("get_all_enemies"):
		return []
	return enemy_manager.get_all_enemies()


func get_all_deployed_units() -> Array:
	var unit_manager := get_unit_manager()
	if unit_manager == null or not unit_manager.has_method("get_all_deployed_units"):
		return []
	return unit_manager.get_all_deployed_units()


func release_all_blocked_enemies() -> void:
	var enemy_manager := get_enemy_manager()
	for enemy_runtime_id in _blocked_enemy_ids:
		var enemy = enemy_manager.get_enemy_by_runtime_id(enemy_runtime_id) if enemy_manager != null else null
		if enemy != null and enemy.has_method("get_blocker_runtime_id") and enemy.get_blocker_runtime_id() == runtime_id:
			_debug_log("单位 %s#%d 解除阻挡敌人 %s#%d" % [_debug_name(), runtime_id, enemy.enemy_id, enemy_runtime_id])
			enemy.clear_blocked()
	_blocked_enemy_ids.clear()


func get_effective_atk() -> int:
	var run_state = AppRefs.run_state()
	var buff_multiplier := 1.0
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		buff_multiplier += float(run_state.get_buff_effect_total_for_unit(&"unit_atk_percent", cfg))
	buff_multiplier += _sum_modifier(&"atk_percent")
	var atk_flat := int(round(_sum_modifier(&"atk_flat")))
	return max(int(round(float(atk) * buff_multiplier * attack_multiplier)) + atk_flat, 1)


func get_effective_attack_speed() -> float:
	var run_state = AppRefs.run_state()
	var relic_add := 0.0
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		relic_add += float(run_state.get_buff_effect_total_for_unit(&"unit_attack_speed_add", cfg))
	relic_add += _get_low_hp_relic_attack_speed_add()
	return CombatMath.clamp_attack_speed(attack_speed + relic_add + _sum_modifier(&"aspd_add") + _sum_timed_modifier(&"aspd_add"))


func get_effective_defense() -> int:
	var run_state = AppRefs.run_state()
	var defense_value := float(defense)
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		defense_value *= 1.0 + float(run_state.get_buff_effect_total_for_unit(&"unit_def_percent", cfg))
	return max(int(round(defense_value)) + int(round(_sum_modifier(&"def_flat"))) + int(round(_sum_timed_modifier(&"def_flat"))), 0)


func get_effective_resistance() -> int:
	var run_state = AppRefs.run_state()
	var relic_add := 0.0
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		relic_add += float(run_state.get_buff_effect_total_for_unit(&"unit_res_add", cfg))
	return max(resistance + int(round(relic_add)) + int(round(_sum_modifier(&"res_flat"))) + int(round(_sum_timed_modifier(&"res_flat"))), 0)


# 攻击时无视目标防御/法抗的比例（精准 3 人），上限 95%。
func get_effective_defense_ignore() -> float:
	return clampf(_sum_modifier(&"defense_ignore"), 0.0, 0.95)


# 每秒 SP 回复：基础（含技能覆盖）×(1+遗物%) + 盟约 flat 加值。
func get_effective_sp_recover_per_sec() -> float:
	var recover_per_sec := float(cfg.get("sp_recover_per_sec", 0.0))
	if _skill_behavior != null and _skill_behavior.has_method("get_sp_recover_per_sec"):
		recover_per_sec = float(_skill_behavior.get_sp_recover_per_sec())
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		recover_per_sec *= 1.0 + float(run_state.get_buff_effect_total_for_unit(&"unit_sp_recover_percent", cfg))
		recover_per_sec += float(run_state.get_buff_effect_total_for_unit(&"unit_sp_recover_flat_add", cfg))
	return recover_per_sec + _sum_modifier(&"sp_recover_add")


# 再部署时间：基础 ×(1+遗物%) ×(1 − 盟约减免)，最低 0。
func get_effective_redeploy_sec() -> float:
	var redeploy_sec := float(cfg.get("redeploy_sec", 0.0))
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		redeploy_sec *= 1.0 + float(run_state.get_buff_effect_total_for_unit(&"unit_redeploy_percent", cfg))
	var reduction := clampf(_sum_modifier(&"redeploy_reduction"), 0.0, 0.9)
	return max(redeploy_sec * (1.0 - reduction), 0.0)


# 不屈：被击倒时原地满血复活的概率（0 表示不触发）。
func get_effective_revive_chance() -> float:
	return clampf(_sum_modifier(&"revive_chance"), 0.0, 1.0)


# 汇总所有来源通道中某个修正键的数值。
func _sum_modifier(key: StringName) -> float:
	var total := 0.0
	for source in _mod_channels:
		total += float((_mod_channels[source] as Dictionary).get(key, 0.0))
	return total


func _sum_timed_modifier(key: StringName) -> float:
	var total := 0.0
	for entry_variant in _timed_modifier_effects.values():
		total += float((entry_variant as Dictionary).get(key, 0.0))
	return total


func get_effective_attack_interval() -> float:
	return CombatMath.calc_attack_interval(attack_interval, get_effective_attack_speed())


# 整组替换某来源通道的修正贡献。mods 为修正键→数值字典；传空字典即清除该来源。
# 支持的键：atk_percent / atk_flat / aspd_add / def_flat / res_flat /
#           hp_percent / sp_recover_add / redeploy_reduction / defense_ignore / revive_chance
func set_modifier_channel(source: StringName, mods: Dictionary) -> void:
	var old_hp_percent := _sum_modifier(&"hp_percent")
	if mods.is_empty():
		_mod_channels.erase(source)
	else:
		_mod_channels[source] = mods.duplicate(true)
	if not is_equal_approx(_sum_modifier(&"hp_percent"), old_hp_percent):
		_recompute_max_hp()


func _apply_timed_modifier(effect_key: StringName, mods: Dictionary, duration: float) -> void:
	if duration <= 0.0 or mods.is_empty():
		return
	var payload := mods.duplicate(true)
	payload["remaining"] = duration
	_timed_modifier_effects[effect_key] = payload
	if mods.has("hp_percent"):
		_recompute_max_hp()


func _tick_timed_modifier_effects(delta: float) -> void:
	var hp_changed := false
	for effect_key in _timed_modifier_effects.keys().duplicate():
		var entry: Dictionary = _timed_modifier_effects[effect_key]
		entry["remaining"] = float(entry.get("remaining", 0.0)) - delta
		if float(entry.get("remaining", 0.0)) <= 0.0:
			if entry.has("hp_percent"):
				hp_changed = true
			_timed_modifier_effects.erase(effect_key)
		else:
			_timed_modifier_effects[effect_key] = entry
	if hp_changed:
		_recompute_max_hp()


# hp% 变化时重算最大生命：上升则当前血同步 +Δ，下降则仅 clamp 到新上限。
func _recompute_max_hp() -> void:
	var new_max := _calculate_effective_max_hp()
	if new_max == max_hp:
		return
	var delta := new_max - max_hp
	max_hp = new_max
	if delta > 0 and not _is_dead:
		current_hp += delta
	current_hp = mini(current_hp, max_hp)
	_update_status_view()


func _calculate_effective_max_hp() -> int:
	var run_state = AppRefs.run_state()
	var hp_percent := _sum_modifier(&"hp_percent") + _sum_timed_modifier(&"hp_percent")
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		hp_percent += float(run_state.get_buff_effect_total_for_unit(&"unit_hp_percent", cfg))
	return maxi(int(round(float(_base_max_hp) * (1.0 + hp_percent))), 1)


func refresh_relic_effects() -> void:
	_recompute_max_hp()
	_update_status_view()


func get_map_manager() -> Node:
	return get_node_or_null("../../../Managers/MapManager")


func get_map_root() -> Node:
	return get_node_or_null("../../MapRoot")


func get_unit_manager() -> Node:
	return get_node_or_null("../../../Managers/UnitManager")


func get_covenant_manager() -> Node:
	return get_node_or_null("../../../Managers/CovenantManager")


func get_enemy_manager() -> Node:
	return get_node_or_null("../../../Managers/EnemyManager")


# 坚守 3 人均摊：把理想伤害平均分给所有存活坚守干员（各自结算自身减伤）。
# 返回 true 表示已转移，调用方不再对自身结算。
func _try_steadfast_pool(value: int, damage_type_value: int, source: Node) -> bool:
	var covenant_manager := get_covenant_manager()
	if covenant_manager == null or not covenant_manager.has_method("is_steadfast_pool_active"):
		return false
	if not covenant_manager.is_steadfast_pool_active():
		return false
	var steadfast: Array = covenant_manager.get_steadfast_units()
	if steadfast.is_empty():
		return false
	var recipients: Array = []
	for su in steadfast:
		if su != null and is_instance_valid(su) and su.has_method("receive_damage"):
			recipients.append(su)
	if recipients.is_empty():
		return false
	var total_damage: int = maxi(value, 0)
	var recipient_count: int = recipients.size()
	var base_share: int = int(floor(float(total_damage) / float(recipient_count)))
	var remainder: int = total_damage - base_share * recipient_count
	for index in range(recipient_count):
		var share: int = base_share + (1 if index < remainder else 0)
		if share <= 0:
			continue
		var su = recipients[index]
		if su != null and is_instance_valid(su) and su.has_method("receive_damage"):
			su.receive_damage(share, damage_type_value, source, true)
	return true


func get_projectile_root() -> Node:
	return get_node_or_null("../../ProjectileRoot")


func get_effect_root() -> Node:
	return get_node_or_null("../../EffectRoot")


func show_skill_range_outline(outline_key: StringName, cells: Array[Vector2i], options: Dictionary = {}) -> void:
	var map_root := get_map_root()
	if map_root == null or not map_root.has_method("set_range_outline"):
		return
	var effect_id := _make_skill_range_outline_id(outline_key)
	var payload := options.duplicate(true)
	payload["owner_runtime_id"] = runtime_id
	map_root.set_range_outline(effect_id, cells, payload)
	if not _registered_range_outline_ids.has(effect_id):
		_registered_range_outline_ids.append(effect_id)


func clear_skill_range_outline(outline_key: StringName) -> void:
	var map_root := get_map_root()
	var effect_id := _make_skill_range_outline_id(outline_key)
	if map_root != null and map_root.has_method("clear_range_outline"):
		map_root.clear_range_outline(effect_id)
	_registered_range_outline_ids.erase(effect_id)


func clear_all_skill_range_outlines() -> void:
	var map_root := get_map_root()
	if runtime_id >= 0 and map_root != null and map_root.has_method("clear_range_outlines_for_owner"):
		map_root.clear_range_outlines_for_owner(runtime_id)
	elif map_root != null and map_root.has_method("clear_range_outline"):
		for effect_id: StringName in _registered_range_outline_ids:
			map_root.clear_range_outline(effect_id)
	_registered_range_outline_ids.clear()


func spawn_one_shot_effect(payload: Dictionary) -> Node:
	var effect_root := get_effect_root()
	if effect_root == null:
		return null
	var effect := OneShotEffect.new()
	effect_root.add_child(effect)
	effect.setup(payload)
	return effect


func _make_skill_range_outline_id(outline_key: StringName) -> StringName:
	var normalized_key := String(outline_key).strip_edges()
	if normalized_key.is_empty():
		normalized_key = "skill"
	return StringName("unit_%d_%s" % [runtime_id, normalized_key])


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


func launch_projectile(target: Node, payload: Dictionary = {}) -> Node:
	if target == null or not is_instance_valid(target):
		return null
	var projectile_root := get_projectile_root()
	if projectile_root == null:
		return null
	var scene_key := StringName(payload.get("projectile_scene_key", payload.get("scene_key", cfg.get("projectile_scene_key", "projectile"))))
	var data_repo = AppRefs.data_repo()
	var projectile_scene: PackedScene = data_repo.get_scene_by_key(scene_key) if data_repo != null else null
	if projectile_scene == null:
		return null
	var projectile := projectile_scene.instantiate()
	projectile_root.add_child(projectile)
	var projectile_payload := payload.duplicate()
	projectile_payload["source"] = self
	projectile_payload["target"] = target
	if not projectile_payload.has("origin"):
		projectile_payload["origin"] = _get_projectile_origin()
	if not projectile_payload.has("speed"):
		projectile_payload["speed"] = float(cfg.get("projectile_speed", DEFAULT_PROJECTILE_SPEED))
	if not projectile_payload.has("hit_radius"):
		projectile_payload["hit_radius"] = float(cfg.get("projectile_hit_radius", DEFAULT_PROJECTILE_HIT_RADIUS))
	if not projectile_payload.has("max_lifetime"):
		projectile_payload["max_lifetime"] = float(cfg.get("projectile_lifetime", DEFAULT_PROJECTILE_LIFETIME))
	if not projectile_payload.has("color"):
		var projectile_color: Variant = _parse_projectile_color(cfg.get("projectile_color", null))
		if projectile_color is Color:
			projectile_payload["color"] = projectile_color
	_copy_projectile_visual_config(projectile_payload)
	if projectile.has_signal("hit"):
		projectile.hit.connect(_on_projectile_hit)
	if projectile.has_method("setup"):
		projectile.setup(projectile_payload)
	elif projectile is Node2D:
		var origin_variant: Variant = projectile_payload.get("origin", global_position)
		if origin_variant is Vector2:
			(projectile as Node2D).global_position = origin_variant
	_request_audio_cue(_projectile_sfx_for_damage_type(int(projectile_payload.get("damage_type", damage_type))))
	return projectile


func _uses_projectile_attack() -> bool:
	return StringName(cfg.get("attack_delivery", "instant")) == &"projectile"


func _get_projectile_origin() -> Vector2:
	return global_position + Vector2(facing).normalized() * 18.0


func _configure_skill_behavior() -> void:
	var behavior_key := StringName(cfg.get("skill_behavior_key", cfg.get("skill_id", "")))
	if behavior_key == StringName():
		return
	if _skill_behavior != null and _skill_behavior.get_script() != null:
		return
	var script_path := String(SKILL_BEHAVIOR_REGISTRY.get(behavior_key, ""))
	if script_path.is_empty() or not ResourceLoader.exists(script_path):
		push_warning("Missing skill behavior script for %s: %s" % [unit_id, behavior_key])
		return
	if _skill_behavior == null:
		_skill_behavior = Node.new()
		_skill_behavior.name = "SkillBehavior"
		_skill_behavior.unique_name_in_owner = true
		add_child(_skill_behavior)
	var behavior_script := load(script_path) as Script
	if behavior_script == null:
		push_warning("Failed to load skill behavior script: %s" % script_path)
		return
	_skill_behavior.set_script(behavior_script)


func _setup_visual_sprite() -> void:
	var texture := _load_visual_texture()
	if texture == null:
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
	_start_idle_motion()


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


func _ensure_contact_shadow() -> void:
	if get_node_or_null("ContactShadow") != null:
		return
	var shadow := ContactShadow.new()
	shadow.name = "ContactShadow"
	shadow.position = Vector2(0.0, CONTACT_SHADOW_Y)
	add_child(shadow)


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
	var breath_scale := Vector2(
		float(cfg.get("idle_motion_scale_x", IDLE_MOTION_BREATH_SCALE.x)),
		float(cfg.get("idle_motion_scale_y", IDLE_MOTION_BREATH_SCALE.y))
	)
	var bob_y := float(cfg.get("idle_motion_bob_y", IDLE_MOTION_BOB_Y))
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


func _play_attack_lunge(direction: Vector2i) -> void:
	if _visual_root == null:
		return
	var normalized := _normalize_direction(direction)
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


func _get_attack_lunge_rotation(direction: Vector2i) -> float:
	return -ATTACK_LUNGE_ROTATION_DEGREES if _should_visual_face_left(direction) else ATTACK_LUNGE_ROTATION_DEGREES


func _load_visual_texture() -> Texture2D:
	var visual_key := String(cfg.get("visual_key", unit_id)).strip_edges()
	if visual_key.is_empty():
		visual_key = String(unit_id)
	var path := "%s/%s/%s/%s_%s_000.png" % [VISUAL_TEXTURE_ROOT, visual_key, VISUAL_IDLE_ANIM, visual_key, VISUAL_IDLE_ANIM]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _should_visual_face_left(direction: Vector2i) -> bool:
	var normalized := _normalize_visual_direction(direction)
	return normalized == Vector2i.LEFT or normalized == Vector2i.UP


func _normalize_visual_direction(direction: Vector2i) -> Vector2i:
	if direction == Vector2i.ZERO:
		return Vector2i.RIGHT
	if abs(direction.x) >= abs(direction.y):
		return Vector2i.RIGHT if direction.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0 else Vector2i.UP


func _get_initial_sp_value() -> float:
	var value := float(cfg.get("sp_initial", cfg.get("initial_sp", 0.0)))
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		value += float(run_state.get_buff_effect_total_for_unit(&"unit_initial_sp_add", cfg))
	return value


func _apply_on_deploy_relic_effects() -> void:
	var run_state = AppRefs.run_state()
	if run_state == null or not run_state.has_method("get_buff_effect_entries_for_unit"):
		return
	var index := 0
	for effect in run_state.get_buff_effect_entries_for_unit(&"unit_on_deploy_aspd_add_duration", cfg):
		var aspd := float(effect.get("effect_value", 0.0))
		var duration := float(effect.get("duration", 0.0))
		if aspd == 0.0 or duration <= 0.0:
			continue
		_apply_timed_modifier(StringName("relic_on_deploy_aspd_%d" % index), {"aspd_add": aspd}, duration)
		index += 1


func _get_relic_sp_on_attack_add() -> int:
	var run_state = AppRefs.run_state()
	if run_state == null or not run_state.has_method("get_buff_effect_total_for_unit"):
		return 0
	return int(round(float(run_state.get_buff_effect_total_for_unit(&"unit_sp_on_attack_add", cfg))))


func _get_relic_sp_on_hit_add() -> int:
	var run_state = AppRefs.run_state()
	if run_state == null or not run_state.has_method("get_buff_effect_total_for_unit"):
		return 0
	return int(round(float(run_state.get_buff_effect_total_for_unit(&"unit_sp_on_hit_add", cfg))))


func _get_low_hp_relic_attack_speed_add() -> float:
	if max_hp <= 0:
		return 0.0
	var run_state = AppRefs.run_state()
	if run_state == null or not run_state.has_method("get_buff_effect_entries_for_unit"):
		return 0.0
	var hp_ratio := clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	var total := 0.0
	for effect in run_state.get_buff_effect_entries_for_unit(&"unit_low_hp_aspd_add", cfg):
		var threshold := clampf(float(effect.get("threshold", 0.3)), 0.01, 1.0)
		var max_add := float(effect.get("effect_value", 0.0))
		var factor := 1.0 if hp_ratio <= threshold else clampf((1.0 - hp_ratio) / (1.0 - threshold), 0.0, 1.0)
		total += max_add * factor
	return total


func _recover_sp(delta: float) -> void:
	var sp_max := float(cfg.get("sp_max", 0.0))
	if _skill_behavior != null and _skill_behavior.has_method("get_sp_max"):
		sp_max = float(_skill_behavior.get_sp_max())
	if _is_skill_active():
		sp = min(sp, sp_max)
		return
	sp = min(sp + get_effective_sp_recover_per_sec() * delta, sp_max)


func _tick_periodic_relic_sp(delta: float) -> void:
	if _is_skill_active():
		return
	var run_state = AppRefs.run_state()
	if run_state == null or not run_state.has_method("get_buff_effect_entries_for_unit"):
		return
	var active_keys: Dictionary = {}
	var index := 0
	for effect in run_state.get_buff_effect_entries_for_unit(&"unit_sp_periodic_add", cfg):
		var interval: float = maxf(float(effect.get("interval", 1.0)), 0.1)
		var amount := int(effect.get("effect_value", 0))
		if amount <= 0:
			continue
		var effect_key := StringName("periodic_sp_%d_%s_%s" % [index, str(interval), str(amount)])
		active_keys[effect_key] = true
		var remaining := float(_relic_sp_periodic_timers.get(effect_key, interval))
		remaining -= delta
		while remaining <= 0.0:
			gain_sp(amount)
			remaining += interval
		_relic_sp_periodic_timers[effect_key] = remaining
		index += 1
	for effect_key in _relic_sp_periodic_timers.keys().duplicate():
		if not active_keys.has(effect_key):
			_relic_sp_periodic_timers.erase(effect_key)


func _is_skill_active() -> bool:
	return _skill_behavior != null and _skill_behavior.has_method("is_active") and bool(_skill_behavior.is_active())


func _cleanup_skill_behavior() -> void:
	if _skill_behavior != null and _skill_behavior.has_method("cleanup"):
		_skill_behavior.cleanup()


func _is_combat_simulation_active() -> bool:
	var run_state = AppRefs.run_state()
	return run_state != null and int(run_state.phase) == GameEnums.PHASE_NIGHT


func _try_auto_cast_skill() -> void:
	if _skill_behavior == null or not _skill_behavior.has_method("should_auto_cast"):
		return
	var config_auto_cast := bool(_skill_behavior.should_auto_cast())
	if not config_auto_cast and not GameplaySettings.is_auto_skill_cast_enabled():
		return
	if not can_cast_skill():
		return
	if _requires_auto_cast_target() and not _has_auto_cast_target():
		return
	cast_skill()


func _requires_auto_cast_target() -> bool:
	if _skill_behavior != null and _skill_behavior.has_method("requires_auto_cast_target"):
		return bool(_skill_behavior.requires_auto_cast_target())
	return not bool(cfg.get("skill_infinite_duration", false))


func _has_auto_cast_target() -> bool:
	if _skill_behavior != null and _skill_behavior.has_method("has_auto_cast_target"):
		return bool(_skill_behavior.has_auto_cast_target())
	return _has_attack_target_for_auto_skill()


func _has_attack_target_for_auto_skill() -> bool:
	for enemy in get_attack_targets():
		if enemy != null and is_instance_valid(enemy) and int(enemy.get("current_hp")) > 0:
			return true
	return false


func _tick_damage_reduction_effects(delta: float) -> void:
	for effect_key in _damage_reduction_effects.keys().duplicate():
		var entry: Dictionary = _damage_reduction_effects[effect_key]
		entry["remaining"] = float(entry.get("remaining", 0.0)) - delta
		if float(entry.get("remaining", 0.0)) <= 0.0:
			_damage_reduction_effects.erase(effect_key)
		else:
			_damage_reduction_effects[effect_key] = entry


func _get_damage_reduction_multiplier() -> float:
	var multiplier := 1.0
	for entry_variant in _damage_reduction_effects.values():
		var entry: Dictionary = entry_variant
		multiplier = min(multiplier, float(entry.get("multiplier", 1.0)))
	return multiplier


func _update_status_view() -> void:
	if _status_view != null and _status_view.has_method("set_hp"):
		_status_view.set_hp(current_hp, max_hp)
	if _status_view != null and _status_view.has_method("set_ammo"):
		var ammo_status := get_skill_ammo_status()
		_status_view.set_ammo(int(ammo_status.get("current", 0)), int(ammo_status.get("max", 0)))


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


func _play_heal_effect() -> void:
	play_follow_effect(
		"res://assets/effects/common/heal_tick_small_strip.png",
		0.36,
		6,
		6,
		18.0,
		Vector2(92.0, 92.0),
		false
	)


func _tick_attack(delta: float) -> void:
	var effective_attack_interval := get_effective_attack_interval()
	_attack_timer = min(_attack_timer, effective_attack_interval)
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return
	var override_targets: Array = []
	if _skill_behavior != null and _skill_behavior.has_method("get_attack_targets_override"):
		override_targets = _skill_behavior.get_attack_targets_override()
	if not override_targets.is_empty():
		for enemy in override_targets:
			_attack_target(enemy, false)
		gain_sp(int(cfg.get("sp_gain_on_attack", 0)) + _get_relic_sp_on_attack_add())
		_attack_timer = effective_attack_interval
		return
	var target := _select_attack_target()
	if target == null:
		return
	_attack_target(target)
	_attack_timer = effective_attack_interval


func _attack_target(target: Node, gain_sp_on_attack: bool = true) -> void:
	if target == null or not is_instance_valid(target):
		return
	_current_target_runtime_id = target.get_runtime_id()
	_play_attack_lunge(facing)
	var damage_value := get_effective_atk()
	if _skill_behavior != null and _skill_behavior.has_method("modify_attack_damage"):
		damage_value = max(int(_skill_behavior.modify_attack_damage(damage_value, target)), 1)
	var defense_ignore := get_effective_defense_ignore()
	_debug_log("单位 %s#%d 攻击敌人 %s#%d，%s伤害 %d" % [_debug_name(), runtime_id, target.enemy_id, target.get_runtime_id(), _damage_type_text(damage_type), damage_value])
	if _uses_projectile_attack():
		var launched_count := 0
		for raw_payload in _get_attack_projectile_payloads(target, damage_value):
			var projectile_payload := (raw_payload as Dictionary).duplicate(true)
			if not projectile_payload.has("damage"):
				projectile_payload["damage"] = damage_value
			if not projectile_payload.has("damage_type"):
				projectile_payload["damage_type"] = damage_type
			if not projectile_payload.has("trigger_after_attack"):
				projectile_payload["trigger_after_attack"] = true
			if not projectile_payload.has("defense_ignore"):
				projectile_payload["defense_ignore"] = defense_ignore
			var projectile := launch_projectile(target, projectile_payload)
			if projectile != null:
				launched_count += 1
		if launched_count > 0:
			if gain_sp_on_attack:
				gain_sp(int(cfg.get("sp_gain_on_attack", 0)) + _get_relic_sp_on_attack_add())
			return
	_resolve_attack_hit(target, damage_value, damage_type, true, defense_ignore)
	if gain_sp_on_attack:
		gain_sp(int(cfg.get("sp_gain_on_attack", 0)) + _get_relic_sp_on_attack_add())


func _resolve_attack_hit(target: Node, damage_value: int, damage_type_value: int, trigger_after_attack: bool = true, defense_ignore: float = 0.0) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("receive_damage"):
		target.receive_damage(damage_value, damage_type_value, defense_ignore)
	if trigger_after_attack and _skill_behavior != null and _skill_behavior.has_method("after_attack"):
		_skill_behavior.after_attack(target, damage_value)


func _on_projectile_hit(_projectile: Node, target: Node, projectile_payload: Dictionary) -> void:
	if _is_dead:
		return
	_resolve_attack_hit(
		target,
		int(projectile_payload.get("damage", get_effective_atk())),
		int(projectile_payload.get("damage_type", damage_type)),
		bool(projectile_payload.get("trigger_after_attack", true)),
		float(projectile_payload.get("defense_ignore", 0.0))
	)


func _get_attack_projectile_payloads(target: Node, damage_value: int) -> Array[Dictionary]:
	var payloads: Array[Dictionary] = []
	if _skill_behavior != null and _skill_behavior.has_method("get_attack_projectile_payloads"):
		for payload_variant in _skill_behavior.get_attack_projectile_payloads(target, damage_value):
			if typeof(payload_variant) == TYPE_DICTIONARY:
				payloads.append((payload_variant as Dictionary).duplicate(true))
	if payloads.is_empty():
		payloads.append({
			"damage": damage_value,
			"damage_type": damage_type,
			"trigger_after_attack": true
		})
	return payloads


func _copy_projectile_visual_config(projectile_payload: Dictionary) -> void:
	for key in [
		"projectile_texture_path",
		"texture_path",
		"projectile_visual_length",
		"projectile_visual_height",
		"visual_length",
		"visual_height",
		"impact_texture_path",
		"impact_hframes",
		"impact_frame_count",
		"impact_fps"
	]:
		if not projectile_payload.has(key) and cfg.has(key):
			projectile_payload[key] = cfg[key]


func _default_impact_texture_path(damage_type_value: int) -> String:
	match damage_type_value:
		GameEnums.DAMAGE_MAGIC:
			return "res://assets/effects/common/impact_arts_small_strip.png"
		GameEnums.DAMAGE_TRUE:
			return "res://assets/effects/common/impact_true_damage_small_strip.png"
		_:
			return "res://assets/effects/common/impact_physical_small_strip.png"


func _select_attack_target() -> Node:
	var best_target: Node = null
	for enemy in get_attack_targets():
		if best_target == null or _is_enemy_higher_priority(enemy, best_target):
			best_target = enemy
	_current_target_runtime_id = best_target.get_runtime_id() if best_target != null else -1
	return best_target


func _is_enemy_higher_priority(a: Node, b: Node) -> bool:
	var a_blocked_by_self := _blocked_enemy_ids.has(a.get_runtime_id())
	var b_blocked_by_self := _blocked_enemy_ids.has(b.get_runtime_id())
	if a_blocked_by_self != b_blocked_by_self:
		return a_blocked_by_self
	var a_progress := float(a.get_path_progress_score()) if a.has_method("get_path_progress_score") else 0.0
	var b_progress := float(b.get_path_progress_score()) if b.has_method("get_path_progress_score") else 0.0
	if not is_equal_approx(a_progress, b_progress):
		return a_progress > b_progress
	var map_manager := get_map_manager()
	if map_manager != null:
		var core_cell: Vector2i = map_manager.get_core_cell()
		var a_cell: Vector2i = a.get_current_cell()
		var b_cell: Vector2i = b.get_current_cell()
		var a_dist: int = a_cell.distance_squared_to(core_cell)
		var b_dist: int = b_cell.distance_squared_to(core_cell)
		if a_dist != b_dist:
			return a_dist < b_dist
	return a.get_runtime_id() < b.get_runtime_id()


func _refresh_blocking() -> void:
	var enemy_manager := get_enemy_manager()
	if enemy_manager == null:
		_blocked_enemy_ids.clear()
		return
	var removed_block := false
	for enemy_runtime_id in _blocked_enemy_ids.duplicate():
		var enemy = enemy_manager.get_enemy_by_runtime_id(enemy_runtime_id)
		if enemy == null or not _can_keep_blocking(enemy):
			_blocked_enemy_ids.erase(enemy_runtime_id)
			removed_block = true
			if enemy != null and enemy.has_method("get_blocker_runtime_id") and enemy.get_blocker_runtime_id() == runtime_id:
				_debug_log("单位 %s#%d 解除阻挡敌人 %s#%d" % [_debug_name(), runtime_id, enemy.enemy_id, enemy_runtime_id])
				enemy.clear_blocked()
	if removed_block:
		_sync_block_slots()
	if block_count <= 0:
		return
	# 阻挡与朝向无关：敌人进入单位中心附近的阻挡半径后，按距离最近优先接敌。
	var used_block := _get_used_block_count()
	for enemy in _collect_block_candidates():
		if used_block >= block_count:
			return
		var block_weight := _get_enemy_block_weight(enemy)
		if used_block + block_weight > block_count:
			continue
		enemy.set_blocked(runtime_id)
		_blocked_enemy_ids.append(enemy.get_runtime_id())
		used_block += block_weight
		_debug_log("单位 %s#%d 阻挡敌人 %s#%d，当前阻挡 %d/%d" % [_debug_name(), runtime_id, enemy.enemy_id, enemy.get_runtime_id(), used_block, block_count])
		_sync_block_slots()


func _can_keep_blocking(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not _can_detect_enemy(enemy):
		return false
	if _is_enemy_unblockable(enemy):
		return false
	if enemy.has_method("get_blocker_runtime_id") and enemy.get_blocker_runtime_id() != runtime_id:
		return false
	return _is_enemy_within_block_radius(enemy)


func _can_start_blocking(enemy: Node) -> bool:
	if block_count <= 0:
		return false
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not _can_detect_enemy(enemy):
		return false
	if _blocked_enemy_ids.has(enemy.get_runtime_id()):
		return false
	if _is_enemy_unblockable(enemy):
		return false
	if not _is_enemy_within_block_radius(enemy):
		return false
	if enemy.has_method("get_blocker_runtime_id"):
		var blocker_runtime_id: int = enemy.get_blocker_runtime_id()
		if blocker_runtime_id != -1 and blocker_runtime_id != runtime_id:
			return false
	return true


func _collect_block_candidates() -> Array:
	var candidates: Array = []
	for enemy in get_all_enemies():
		if _can_start_blocking(enemy):
			_insert_block_candidate(candidates, enemy)
	return candidates


func _insert_block_candidate(candidates: Array, enemy: Node) -> void:
	for index in range(candidates.size()):
		if _compare_block_candidates(enemy, candidates[index]):
			candidates.insert(index, enemy)
			return
	candidates.append(enemy)


func _compare_block_candidates(a: Node, b: Node) -> bool:
	var a_dist: float = global_position.distance_squared_to(a.global_position)
	var b_dist: float = global_position.distance_squared_to(b.global_position)
	if not is_equal_approx(a_dist, b_dist):
		return a_dist < b_dist
	return _is_enemy_higher_priority(a, b)


func _get_used_block_count() -> int:
	var used := 0
	var enemy_manager := get_enemy_manager()
	for enemy_runtime_id in _blocked_enemy_ids:
		var enemy = enemy_manager.get_enemy_by_runtime_id(enemy_runtime_id) if enemy_manager != null else null
		if enemy != null:
			used += _get_enemy_block_weight(enemy)
	return used


func _get_enemy_block_weight(enemy: Node) -> int:
	if enemy == null:
		return 1
	return max(int(enemy.cfg.get("block_weight", enemy.cfg.get("block_cost", 1))), 1)


func _is_enemy_unblockable(enemy: Node) -> bool:
	return enemy != null and (bool(enemy.cfg.get("unblockable", false)) or StringName(enemy.cfg.get("move_type", "ground")) == &"flying")


func _can_target_enemy(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var enemy_move_type := _get_enemy_move_type(enemy)
	match target_type:
		TARGET_TYPE_ALL:
			return true
		TARGET_TYPE_FLYING:
			return enemy_move_type == MOVE_TYPE_FLYING
		TARGET_TYPE_GROUND:
			return enemy_move_type == MOVE_TYPE_GROUND
	return false


func _can_detect_enemy(enemy: Node) -> bool:
	var map_manager := get_map_manager()
	if map_manager == null or not map_manager.has_method("is_discovered"):
		return true
	var enemy_cell: Vector2i = map_manager.world_to_cell(enemy.global_position) if map_manager.has_method("world_to_cell") else enemy.get_current_cell()
	return map_manager.is_discovered(enemy_cell)


func _is_enemy_within_block_radius(enemy: Node) -> bool:
	var radius := float(cfg.get("block_radius_tiles", BLOCK_RADIUS_TILES)) * CELL_SIZE
	return global_position.distance_to(enemy.global_position) <= radius


func _sync_block_slots() -> void:
	var enemy_manager := get_enemy_manager()
	var slot_count := _blocked_enemy_ids.size()
	if enemy_manager == null or slot_count <= 0:
		return
	for index in range(slot_count):
		var enemy = enemy_manager.get_enemy_by_runtime_id(_blocked_enemy_ids[index])
		if enemy != null and enemy.has_method("set_blocked"):
			enemy.set_blocked(runtime_id, index, slot_count)


func _is_enemy_in_attack_range(enemy: Node) -> bool:
	var enemy_cell: Vector2i = enemy.get_current_cell()
	var relative: Vector2i = enemy_cell - current_cell
	for offset in range_pattern:
		if _rotate_offset(offset, facing) == relative:
			return true
	return false


func parse_range_pattern(raw_pattern: Variant) -> Array[Vector2i]:
	var parsed: Array[Vector2i] = []
	if typeof(raw_pattern) != TYPE_ARRAY:
		return parsed
	for entry: Variant in raw_pattern:
		if typeof(entry) == TYPE_ARRAY and (entry as Array).size() >= 2:
			var pair := entry as Array
			parsed.append(Vector2i(int(pair[0]), int(pair[1])))
		elif entry is Vector2i:
			parsed.append(entry)
	return parsed


func parse_damage_type(raw_type: String) -> int:
	match raw_type:
		"magic":
			return GameEnums.DAMAGE_MAGIC
		"true":
			return GameEnums.DAMAGE_TRUE
		_:
			return GameEnums.DAMAGE_PHYSICAL


func _parse_projectile_color(raw_color: Variant) -> Variant:
	if raw_color is Color:
		return raw_color
	if typeof(raw_color) == TYPE_ARRAY:
		var color_values := raw_color as Array
		if color_values.size() >= 3:
			var alpha := float(color_values[3]) if color_values.size() >= 4 else 1.0
			return Color(float(color_values[0]), float(color_values[1]), float(color_values[2]), alpha)
	return null


func parse_target_type(raw_type: String) -> StringName:
	match raw_type:
		"flying":
			return TARGET_TYPE_FLYING
		"all":
			return TARGET_TYPE_ALL
		_:
			return TARGET_TYPE_GROUND


func _get_enemy_move_type(enemy: Node) -> StringName:
	if enemy == null:
		return MOVE_TYPE_GROUND
	var move_type := StringName(enemy.cfg.get("move_type", String(MOVE_TYPE_GROUND)))
	return MOVE_TYPE_FLYING if move_type == MOVE_TYPE_FLYING else MOVE_TYPE_GROUND


func _rotate_offset(offset: Vector2i, direction: Vector2i) -> Vector2i:
	# range_pattern 默认按“向右”书写，这里根据单位朝向旋转格子偏移。
	var normalized := _normalize_direction(direction)
	if normalized == Vector2i.LEFT:
		return Vector2i(-offset.x, -offset.y)
	if normalized == Vector2i.UP:
		return Vector2i(offset.y, -offset.x)
	if normalized == Vector2i.DOWN:
		return Vector2i(-offset.y, offset.x)
	return offset


func _normalize_direction(direction: Vector2i) -> Vector2i:
	if abs(direction.x) >= abs(direction.y):
		return Vector2i.RIGHT if direction.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0 else Vector2i.UP


func _debug_log(message: String) -> void:
	var tree := get_tree()
	if tree != null:
		tree.call_group("combat_debug_log", "append_combat_debug", message)


func _debug_name() -> String:
	if not operator_name.is_empty():
		return operator_name
	return String(cfg.get("name", unit_id))


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


func _projectile_sfx_for_damage_type(damage_type_value: int) -> StringName:
	return SFX_PROJECTILE_ARTS if damage_type_value == GameEnums.DAMAGE_MAGIC else SFX_PROJECTILE_PHYSICAL


func _request_audio_cue(cue_key: StringName) -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.audio_cue_requested.emit(cue_key)
