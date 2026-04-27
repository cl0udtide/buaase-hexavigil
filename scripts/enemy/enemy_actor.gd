extends Node2D

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const BossController = preload("res://scripts/enemy/boss_controller.gd")

const DEBUG_SIZE := 40.0
const DEBUG_COLOR := Color(1.0, 0.25, 0.25, 0.95)
const PATH_MODE_NORMAL: StringName = &"normal"
const PATH_MODE_DEMOLISHER: StringName = &"demolisher"
const PATH_MODE_FLYING: StringName = &"flying"
const CELL_SIZE := 64.0
const BLOCK_HOLD_DISTANCE := CELL_SIZE * 0.5
const BLOCK_SPREAD_DISTANCE := CELL_SIZE * 0.22
const BLOCK_SNAP_SPEED := CELL_SIZE * 6.0

var enemy_id: StringName
var runtime_id := -1
var current_cell := Vector2i.ZERO
var cfg: Dictionary = {}
var current_hp := 1
var max_hp := 1
var _path: Array[Vector2i] = []
var _path_index := 0
var _blocked_by := -1
var _path_mode: StringName = PATH_MODE_NORMAL
var _block_slot := 0
var _block_slot_count := 1
var _block_anchor_dir := Vector2.ZERO
var _attack_timer := 0.0
var _is_dead := false
var _boss_controller: Node = null
var _external_move_speed_multiplier: float = 1.0

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
	if _blocked_by != -1:
		var blocker: Node = _get_blocker()
		if blocker == null or not is_instance_valid(blocker):
			clear_blocked()
			return
		_process_blocked_motion(delta, blocker)
		_process_blocked_attack(delta, blocker)
		return
	if _path.is_empty():
		return
	if _path_index >= _path.size():
		get_enemy_manager().notify_enemy_reached_core(runtime_id)
		return
	var path_building: Node = _get_blocking_building_on_path()
	if path_building != null:
		_process_building_attack(delta, path_building)
		return
	if _process_range_attack(delta):
		return
	var target_pos: Vector2 = get_map_manager().cell_to_world(_path[_path_index])
	global_position = global_position.move_toward(target_pos, get_effective_move_speed() * CELL_SIZE * delta)
	if global_position.distance_to(target_pos) < 2.0:
		current_cell = _path[_path_index]
		_path_index += 1
		if _path_index >= _path.size():
			get_enemy_manager().notify_enemy_reached_core(runtime_id)


func setup_from_cfg(new_enemy_id: StringName, new_cfg: Dictionary, spawn_cell: Vector2i) -> void:
	enemy_id = new_enemy_id
	cfg = new_cfg.duplicate(true)
	_path_mode = _resolve_path_mode()
	max_hp = int(cfg.get("max_hp", 1))
	current_hp = max_hp
	current_cell = spawn_cell
	_blocked_by = -1
	_block_slot = 0
	_block_slot_count = 1
	_block_anchor_dir = Vector2.ZERO
	_attack_timer = 0.0
	_is_dead = false
	_external_move_speed_multiplier = 1.0
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
	if _is_dead or _blocked_by != -1 or tiles <= 0:
		return false
	var push_dir: Vector2i = _normalize_push_direction(direction)
	if push_dir == Vector2i.ZERO:
		return false
	var map_manager: Node = get_map_manager()
	if map_manager == null:
		return false
	var target_cell: Vector2i = current_cell
	for _step in range(tiles):
		var next_cell: Vector2i = target_cell + push_dir
		if not _can_push_to_cell(next_cell):
			break
		target_cell = next_cell
	if target_cell == current_cell:
		return false
	current_cell = target_cell
	global_position = map_manager.cell_to_world(current_cell)
	recalc_path()
	_debug_log("敌人 %s#%d 被推动到格子 %s" % [_debug_name(), runtime_id, current_cell])
	return true


func get_runtime_id() -> int:
	return runtime_id


func get_current_cell() -> Vector2i:
	return current_cell


func get_attack_range_tiles() -> int:
	return int(cfg.get("attack_range", 0))


func recalc_path() -> void:
	var path_service: Node = get_node_or_null("../../../Managers/PathService")
	var map_manager: Node = get_map_manager()
	if map_manager == null:
		return
	var core_cell: Vector2i = map_manager.get_core_cell()
	if path_service != null:
		_path = path_service.find_path(current_cell, core_cell, _path_mode)
		_path_index = min(1, _path.size() - 1) if not _path.is_empty() else 0


func set_blocked(blocker_runtime_id: int, block_slot: int = 0, block_slot_count: int = 1) -> void:
	if _blocked_by != blocker_runtime_id:
		_attack_timer = 0.0
		_block_anchor_dir = _resolve_block_anchor_dir(blocker_runtime_id)
	_blocked_by = blocker_runtime_id
	_block_slot = max(block_slot, 0)
	_block_slot_count = max(block_slot_count, 1)


func clear_blocked() -> void:
	_blocked_by = -1
	_block_slot = 0
	_block_slot_count = 1
	_block_anchor_dir = Vector2.ZERO


func is_blocked() -> bool:
	return _blocked_by != -1


func get_blocker_runtime_id() -> int:
	return _blocked_by


func get_path_progress_score() -> float:
	var core_distance: float = 0.0
	var map_manager: Node = get_map_manager()
	if map_manager != null:
		core_distance = float(get_current_cell().distance_squared_to(map_manager.get_core_cell()))
	return float(_path_index) * 100000.0 - core_distance


func get_effective_move_speed() -> float:
	return max(float(cfg.get("move_speed", 1.0)) * _external_move_speed_multiplier, 0.05)


func set_external_move_speed_multiplier(value: float) -> void:
	_external_move_speed_multiplier = max(value, 0.1)


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
	return unit_manager.get_unit_by_runtime_id(_blocked_by) if unit_manager != null else null


func _process_blocked_motion(delta: float, blocker: Node) -> void:
	var target_pos: Vector2 = _get_block_hold_position(blocker)
	var snap_speed: float = float(cfg.get("blocked_snap_speed", BLOCK_SNAP_SPEED / CELL_SIZE)) * CELL_SIZE
	global_position = global_position.move_toward(target_pos, snap_speed * delta)
	var map_manager: Node = get_map_manager()
	if map_manager != null:
		current_cell = map_manager.world_to_cell(global_position)


func _process_blocked_attack(delta: float, blocker: Node) -> void:
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return
	var damage_type: int = _parse_damage_type(String(cfg.get("damage_type", "physical")))
	var damage_value: int = int(cfg.get("atk", 1))
	_debug_log("敌人 %s#%d 攻击阻挡单位 %s#%d，%s伤害 %d" % [_debug_name(), runtime_id, blocker.unit_id, blocker.get_runtime_id(), _damage_type_text(damage_type), damage_value])
	blocker.receive_damage(damage_value, damage_type, self)
	_attack_timer = max(float(cfg.get("attack_interval", 1.0)), 0.05)


func _process_building_attack(delta: float, building: Node) -> void:
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return
	var building_manager: Node = get_building_manager()
	if building_manager == null or not building_manager.has_method("damage_building"):
		return
	var damage_type: int = _parse_damage_type(String(cfg.get("damage_type", "physical")))
	var damage_value: int = int(cfg.get("atk", 1))
	_debug_log("敌人 %s#%d 攻击路径建筑 %s，%s伤害 %d" % [_debug_name(), runtime_id, _target_debug_name(building), _damage_type_text(damage_type), damage_value])
	_damage_building(building, damage_value, damage_type)
	_attack_timer = max(float(cfg.get("attack_interval", 1.0)), 0.05)


func _process_range_attack(delta: float) -> bool:
	var attack_range: int = get_attack_range_tiles()
	if attack_range <= 0:
		return false
	var target: Node = _find_attack_target_in_range(attack_range)
	if target == null:
		return false
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return true
	var damage_type: int = _parse_damage_type(String(cfg.get("damage_type", "physical")))
	var damage_value: int = int(cfg.get("atk", 1))
	_debug_log("敌人 %s#%d 远程攻击 %s，%s伤害 %d" % [_debug_name(), runtime_id, _target_debug_name(target), _damage_type_text(damage_type), damage_value])
	if target.has_method("receive_damage"):
		if target.is_in_group("units"):
			target.receive_damage(damage_value, damage_type, self)
		else:
			_damage_building(target, damage_value, damage_type)
	_attack_timer = max(float(cfg.get("attack_interval", 1.0)), 0.05)
	return true


func _find_attack_target_in_range(attack_range: int) -> Node:
	var unit_manager: Node = get_unit_manager()
	var building_manager: Node = get_building_manager()
	var best_target: Node = null
	var best_distance: int = 999999
	for y in range(current_cell.y - attack_range, current_cell.y + attack_range + 1):
		for x in range(current_cell.x - attack_range, current_cell.x + attack_range + 1):
			var cell: Vector2i = Vector2i(x, y)
			var distance: int = max(abs(cell.x - current_cell.x), abs(cell.y - current_cell.y))
			if distance > attack_range or distance >= best_distance:
				continue
			var unit: Node = null
			if unit_manager != null and unit_manager.has_method("get_unit_by_cell"):
				unit = unit_manager.get_unit_by_cell(cell)
			if unit != null and is_instance_valid(unit):
				best_target = unit
				best_distance = distance
				continue
			var building: Node = null
			if building_manager != null and building_manager.has_method("get_building_by_cell"):
				building = building_manager.get_building_by_cell(cell)
			if building != null and is_instance_valid(building) and not _is_destroyed_building(building):
				best_target = building
				best_distance = distance
	return best_target


func _damage_building(building: Node, damage_value: int, damage_type: int) -> void:
	var building_manager: Node = get_building_manager()
	if building_manager != null and building_manager.has_method("damage_building"):
		building_manager.damage_building(int(building.get("runtime_id")), damage_value, damage_type)
	elif building != null and building.has_method("receive_damage"):
		building.receive_damage(damage_value, damage_type)


func _get_blocking_building_on_path() -> Node:
	if _path_mode == PATH_MODE_FLYING or _path.is_empty() or _path_index >= _path.size():
		return null
	var building_manager: Node = get_building_manager()
	if building_manager == null or not building_manager.has_method("get_building_by_cell"):
		return null
	var next_cell: Vector2i = _path[_path_index]
	var building: Node = building_manager.get_building_by_cell(next_cell)
	if building == null or not is_instance_valid(building):
		return null
	if _is_destroyed_building(building):
		return null
	if not _should_attack_path_building(building):
		return null
	return building


func _should_attack_path_building(building: Node) -> bool:
	if _is_destroyed_building(building):
		return false
	if _path_mode == PATH_MODE_DEMOLISHER:
		return true
	if _path_mode != PATH_MODE_NORMAL:
		return false
	return not _is_wall_building(building)


func _is_destroyed_building(building: Node) -> bool:
	if building == null:
		return false
	if building.has_method("is_destroyed"):
		return bool(building.is_destroyed())
	var current_hp_variant: Variant = building.get("current_hp")
	return current_hp_variant != null and int(current_hp_variant) <= 0


func _is_wall_building(building: Node) -> bool:
	if building == null:
		return false
	if StringName(building.get("building_id")) == &"wood_wall":
		return true
	var cfg_variant: Variant = building.get("cfg")
	if typeof(cfg_variant) != TYPE_DICTIONARY:
		return false
	var building_cfg: Dictionary = cfg_variant
	return bool(building_cfg.get("blocks_path", false))


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
	_path_mode = _resolve_path_mode()
	max_hp = int(cfg.get("max_hp", max_hp))
	current_hp = max_hp
	_attack_timer = max(float(cfg.get("attack_interval", 1.0)), 0.05)
	_recalc_path_after_phase_change()
	_update_title_label()
	_update_status_view()
	_debug_log("敌人 %s#%d 转入第%d阶段，HP %d/%d" % [_debug_name(), runtime_id, int(phase_cfg.get("phase", 0)), current_hp, max_hp])


func _recalc_path_after_phase_change() -> void:
	if _blocked_by == -1:
		recalc_path()


func _update_title_label() -> void:
	var label: Label = get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.theme = AppTheme.get_theme()
		label.text = String(cfg.get("name", enemy_id))
		label.position = Vector2(-30.0, -58.0)


func _get_block_hold_position(blocker: Node) -> Vector2:
	var anchor_dir: Vector2 = _block_anchor_dir
	if anchor_dir == Vector2.ZERO:
		anchor_dir = _resolve_block_anchor_dir(_blocked_by)
	var perpendicular: Vector2 = Vector2(-anchor_dir.y, anchor_dir.x)
	var centered_slot: float = float(_block_slot) - float(_block_slot_count - 1) * 0.5
	var hold_distance: float = float(cfg.get("block_hold_distance", BLOCK_HOLD_DISTANCE))
	var spread_distance: float = float(cfg.get("block_spread_distance", BLOCK_SPREAD_DISTANCE))
	return blocker.global_position + anchor_dir * hold_distance + perpendicular * centered_slot * spread_distance


func _resolve_block_anchor_dir(blocker_runtime_id: int) -> Vector2:
	var blocker: Node = _get_unit_by_runtime_id(blocker_runtime_id)
	if blocker != null:
		var direct: Vector2 = global_position - blocker.global_position
		if direct.length() > 0.01:
			return direct.normalized()
	var move_dir: Vector2 = _get_current_move_direction()
	if move_dir.length() > 0.01:
		return -move_dir.normalized()
	return Vector2.LEFT


func _get_unit_by_runtime_id(unit_runtime_id: int) -> Node:
	var unit_manager: Node = get_unit_manager()
	return unit_manager.get_unit_by_runtime_id(unit_runtime_id) if unit_manager != null else null


func _get_current_move_direction() -> Vector2:
	var map_manager: Node = get_map_manager()
	if map_manager == null or _path.is_empty():
		return Vector2.ZERO
	var from_cell: Vector2i = current_cell
	var to_cell: Vector2i = _path[min(_path_index, _path.size() - 1)]
	if _path_index > 0 and _path_index < _path.size():
		from_cell = _path[_path_index - 1]
	var from_pos: Vector2 = map_manager.cell_to_world(from_cell)
	var to_pos: Vector2 = map_manager.cell_to_world(to_cell)
	return to_pos - from_pos


func _can_push_to_cell(cell: Vector2i) -> bool:
	var map_manager: Node = get_map_manager()
	if map_manager == null or not map_manager.is_inside(cell):
		return false
	var cell_data = map_manager.get_cell_data(cell)
	if cell_data == null or cell_data.is_core:
		return false
	return map_manager.is_walkable(cell)


func _normalize_push_direction(direction: Vector2i) -> Vector2i:
	if direction == Vector2i.ZERO:
		return Vector2i.ZERO
	if abs(direction.x) >= abs(direction.y):
		return Vector2i.RIGHT if direction.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0 else Vector2i.UP


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


func _target_debug_name(target: Node) -> String:
	if target == null:
		return "未知目标"
	if target.is_in_group("units"):
		return "单位 %s#%d" % [String(target.get("unit_id")), int(target.get("runtime_id"))]
	if target.is_in_group("buildings"):
		return "建筑 %s#%d" % [String(target.get("building_id")), int(target.get("runtime_id"))]
	return String(target.name)


func _damage_type_text(type_value: int) -> String:
	match type_value:
		GameEnums.DAMAGE_MAGIC:
			return "法术"
		GameEnums.DAMAGE_TRUE:
			return "真实"
		_:
			return "物理"


func _resolve_path_mode() -> StringName:
	var move_type: StringName = StringName(cfg.get("move_type", "ground"))
	if move_type == PATH_MODE_FLYING:
		return PATH_MODE_FLYING

	var behavior_type: StringName = StringName(cfg.get("behavior_type", "normal"))
	match behavior_type:
		&"demolisher", &"siege", &"rush", &"breaker":
			return PATH_MODE_DEMOLISHER
		_:
			return PATH_MODE_NORMAL
