extends Node2D

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const BossController = preload("res://scripts/enemy/boss_controller.gd")
const EnemyMovementController = preload("res://scripts/enemy/enemy_movement_controller.gd")
const EnemyAttackController = preload("res://scripts/enemy/enemy_attack_controller.gd")

const DEBUG_SIZE := 40.0
const DEBUG_COLOR := Color(1.0, 0.25, 0.25, 0.95)

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

@onready var _status_view: Node = get_node_or_null("%StatusView")


func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()


func _process(delta: float) -> void:
	if _is_dead:
		return
	if _boss_controller != null and _boss_controller.is_transitioning():
		var phase_cfg: Dictionary = _boss_controller.tick(delta)
		if not phase_cfg.is_empty():
			_apply_phase_cfg(phase_cfg)
			_boss_controller.apply_phase_enter_effects()
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
	current_cell = spawn_cell
	_is_dead = false
	_setup_movement_controller()
	_setup_attack_controller()
	_setup_boss_controller()
	global_position = get_map_manager().cell_to_world(spawn_cell)
	recalc_path()
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
		final_damage = CombatMath.calc_physical_damage(value, int(cfg.get("def", 0)))
	elif damage_type == GameEnums.DAMAGE_MAGIC:
		final_damage = CombatMath.calc_magic_damage(value, int(cfg.get("res", 0)))
	current_hp = max(current_hp - final_damage, 0)
	_update_status_view()
	_play_hit_effect()
	_debug_log("敌人 %s#%d 受到%s伤害：原始 %d，结算 %d，HP %d/%d" % [_debug_name(), runtime_id, _damage_type_text(damage_type), value, final_damage, current_hp, max_hp])
	if current_hp == 0 and not _is_dead:
		if _boss_controller != null and _boss_controller.try_consume_death_for_phase_transition():
			clear_blocked()
			_update_status_view()
			return
		_is_dead = true
		_debug_log("敌人 %s#%d 死亡" % [_debug_name(), runtime_id])
		get_enemy_manager().remove_enemy(runtime_id)


func apply_push(direction: Vector2i, tiles: int) -> bool:
	if _is_dead:
		return false
	return _movement_controller.apply_push(direction, tiles) if _movement_controller != null else false


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


func _play_hit_effect() -> void:
	if _status_view != null and _status_view.has_method("play_hit_effect"):
		_status_view.play_hit_effect()


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
