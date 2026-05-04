extends Node2D

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const BossController = preload("res://scripts/enemy/boss_controller.gd")
const EnemyMovementController = preload("res://scripts/enemy/enemy_movement_controller.gd")
const EnemyAttackController = preload("res://scripts/enemy/enemy_attack_controller.gd")

const DEBUG_SIZE := 40.0
const DEBUG_COLOR := Color(1.0, 0.25, 0.25, 0.95)
const INVALID_DEATH_SPAWN_CELL := Vector2i(-9999, -9999)

var enemy_id: StringName
var runtime_id := -1
var current_cell := Vector2i.ZERO
var cfg: Dictionary = {}
var current_hp := 1
var max_hp := 1
var _is_dead := false
var _movement_controller: Node = null
var _attack_controller: Node = null
var _boss_controller: Node = null
var _move_speed_effects: Dictionary = {}
var _defense_shred_effects: Dictionary = {}
var _resistance_shred_effects: Dictionary = {}
var _physical_vulnerability_effects: Dictionary = {}
var _magic_vulnerability_effects: Dictionary = {}
var _dot_effects: Dictionary = {}
var _stun_timer := 0.0
var _bind_timer := 0.0
var _necrosis_accum := 0.0
var _necrosis_burst_timer := 0.0
var _necrosis_vulnerability := 0.0
var _necrosis_dot_damage_per_sec := 0.0
var _necrosis_dot_carry := 0.0
var _shield_hp := 0
var _max_shield_hp := 0
var _regen_carry := 0.0

@onready var _status_view: Node = get_node_or_null("%StatusView")


func _ready() -> void:
	add_to_group("enemies")
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
		_attack_controller.process_range_attack(delta)
		return
	var path_building: Node = _attack_controller.get_blocking_building_on_path(_movement_controller)
	if path_building != null:
		_attack_controller.process_building_attack(delta, path_building)
		return
	if _attack_controller.process_range_attack(delta):
		return
	if _movement_controller.process_path_movement(delta):
		get_enemy_manager().notify_enemy_reached_core(runtime_id)


func setup_from_cfg(new_enemy_id: StringName, new_cfg: Dictionary, spawn_cell: Vector2i) -> void:
	enemy_id = new_enemy_id
	cfg = new_cfg.duplicate(true)
	max_hp = int(cfg.get("max_hp", 1))
	current_hp = max_hp
	_max_shield_hp = max(int(cfg.get("shield_hp", 0)), 0)
	_shield_hp = _max_shield_hp
	_regen_carry = 0.0
	current_cell = spawn_cell
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
	_update_status_view()
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ONE * (-DEBUG_SIZE * 0.5), Vector2.ONE * DEBUG_SIZE)
	draw_rect(rect, DEBUG_COLOR, false, 2.0)
	draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), DEBUG_COLOR, 1.5)
	draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0), DEBUG_COLOR, 1.5)


func receive_damage(value: int, damage_type: int) -> void:
	if (_boss_controller != null and _boss_controller.is_transitioning()) or bool(cfg.get("invulnerable", false)):
		_debug_log("敌人 %s#%d 处于无敌状态，免疫本次伤害" % [_debug_name(), runtime_id])
		return
	var final_damage: int = value
	if damage_type == GameEnums.DAMAGE_PHYSICAL:
		final_damage = CombatMath.calc_physical_damage(value, _get_effective_defense())
	elif damage_type == GameEnums.DAMAGE_MAGIC:
		final_damage = CombatMath.calc_magic_damage(value, _get_effective_resistance())
	final_damage = max(int(round(float(final_damage) * _get_vulnerability_multiplier(damage_type))), 0)
	var shield_absorbed: int = _absorb_damage_with_shield(final_damage)
	final_damage = max(final_damage - shield_absorbed, 0)
	current_hp = max(current_hp - final_damage, 0)
	_update_status_view()
	_play_hit_effect()
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


func apply_defeat_effects() -> void:
	_apply_death_area_damage()
	_spawn_death_enemies()


func apply_push(direction: Vector2i, tiles: int) -> bool:
	if _is_dead:
		return false
	return _movement_controller.apply_push(direction, tiles) if _movement_controller != null else false


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
	current_cell = cell
	global_position = map_manager.cell_to_world(cell)
	clear_blocked()
	recalc_path()
	_debug_log("敌人 %s#%d 被牵引回格子 %s" % [_debug_name(), runtime_id, current_cell])
	return true


func apply_stun(duration: float) -> void:
	_stun_timer = max(_stun_timer, duration)


func apply_bind(duration: float) -> void:
	_bind_timer = max(_bind_timer, duration)


func apply_move_speed_multiplier(effect_key: StringName, multiplier: float, duration: float) -> void:
	if duration <= 0.0:
		return
	_move_speed_effects[effect_key] = {
		"value": clamp(multiplier, 0.0, 1.0),
		"remaining": duration
	}
	_refresh_status_multipliers()


func apply_defense_shred(effect_key: StringName, value: int, duration: float) -> void:
	_apply_number_status(_defense_shred_effects, effect_key, value, duration)


func apply_resistance_shred(effect_key: StringName, value: int, duration: float) -> void:
	_apply_number_status(_resistance_shred_effects, effect_key, value, duration)


func apply_physical_vulnerability(effect_key: StringName, multiplier: float, duration: float) -> void:
	_apply_multiplier_status(_physical_vulnerability_effects, effect_key, multiplier, duration)


func apply_magic_vulnerability(effect_key: StringName, multiplier: float, duration: float) -> void:
	_apply_multiplier_status(_magic_vulnerability_effects, effect_key, multiplier, duration)


func apply_dot(effect_key: StringName, damage_per_sec: float, damage_type: int, duration: float) -> void:
	if damage_per_sec <= 0.0 or duration <= 0.0:
		return
	_dot_effects[effect_key] = {
		"damage_per_sec": damage_per_sec,
		"damage_type": damage_type,
		"remaining": duration,
		"carry": 0.0
	}


func apply_necrosis(effect_key: StringName, amount: float, burst_duration: float, vulnerability: float, damage_per_sec: float) -> bool:
	if amount <= 0.0 or _necrosis_burst_timer > 0.0:
		return false
	_necrosis_accum += amount
	var threshold := float(cfg.get("necrosis_threshold", 100.0))
	if _necrosis_accum < threshold:
		return false
	_necrosis_accum = 0.0
	_necrosis_burst_timer = max(burst_duration, 0.1)
	_necrosis_vulnerability = max(vulnerability, 0.0)
	_necrosis_dot_damage_per_sec = max(damage_per_sec, 0.0)
	_necrosis_dot_carry = 0.0
	_debug_log("敌人 %s#%d 触发凋亡虚弱：%s，持续 %.1f 秒" % [_debug_name(), runtime_id, String(effect_key), _necrosis_burst_timer])
	return true


func is_necrosis_bursting() -> bool:
	return _necrosis_burst_timer > 0.0


func get_runtime_id() -> int:
	return runtime_id


func get_current_cell() -> Vector2i:
	return current_cell


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


func _update_status_view() -> void:
	if _status_view != null and _status_view.has_method("set_hp"):
		_status_view.set_hp(current_hp, max_hp)
	if _status_view != null and _status_view.has_method("set_shield"):
		_status_view.set_shield(_shield_hp, _max_shield_hp)


func _play_hit_effect() -> void:
	if _status_view != null and _status_view.has_method("play_hit_effect"):
		_status_view.play_hit_effect()


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
	cfg.merge(phase_cfg, true)
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
	_necrosis_accum = 0.0
	_necrosis_burst_timer = 0.0
	_necrosis_vulnerability = 0.0
	_necrosis_dot_damage_per_sec = 0.0
	_necrosis_dot_carry = 0.0
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
	_tick_necrosis_burst(delta)
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
		entry["carry"] = float(entry.get("carry", 0.0)) + float(entry.get("damage_per_sec", 0.0)) * delta
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


func _tick_necrosis_burst(delta: float) -> void:
	if _necrosis_burst_timer <= 0.0:
		return
	_necrosis_burst_timer = max(_necrosis_burst_timer - delta, 0.0)
	_necrosis_dot_carry += _necrosis_dot_damage_per_sec * delta
	var damage_value := int(floor(_necrosis_dot_carry))
	if damage_value > 0:
		_necrosis_dot_carry -= float(damage_value)
		receive_damage(damage_value, GameEnums.DAMAGE_MAGIC)
		if _is_dead:
			return
	if _necrosis_burst_timer <= 0.0:
		_necrosis_vulnerability = 0.0
		_necrosis_dot_damage_per_sec = 0.0
		_necrosis_dot_carry = 0.0


func _tick_regeneration(delta: float) -> void:
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
	return max(int(cfg.get("def", 0)) - _sum_number_status(_defense_shred_effects), 0)


func _get_effective_resistance() -> int:
	return max(int(cfg.get("res", 0)) - _sum_number_status(_resistance_shred_effects), 0)


func _sum_number_status(status_dict: Dictionary) -> int:
	var total := 0
	for entry_variant in status_dict.values():
		var entry: Dictionary = entry_variant
		total += int(entry.get("value", 0))
	return total


func _get_vulnerability_multiplier(damage_type_value: int) -> float:
	var multiplier := 1.0 + _necrosis_vulnerability if _necrosis_burst_timer > 0.0 else 1.0
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


func _damage_type_text(type_value: int) -> String:
	match type_value:
		GameEnums.DAMAGE_MAGIC:
			return "法术"
		GameEnums.DAMAGE_TRUE:
			return "真实"
		_:
			return "物理"
