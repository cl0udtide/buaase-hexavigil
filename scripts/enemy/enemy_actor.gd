extends Node2D

const AppTheme = preload("res://scripts/ui/app_theme.gd")

const DEBUG_SIZE := 40.0
const DEBUG_COLOR := Color(1.0, 0.25, 0.25, 0.95)
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
var _block_slot := 0
var _block_slot_count := 1
var _block_anchor_dir := Vector2.ZERO
var _attack_timer := 0.0
var _is_dead := false

@onready var _status_view: Node = get_node_or_null("%StatusView")


func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()


func _process(delta: float) -> void:
	if _is_dead:
		return
	if _blocked_by != -1:
		var blocker := _get_blocker()
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
	var target_pos: Vector2 = get_map_manager().cell_to_world(_path[_path_index])
	global_position = global_position.move_toward(target_pos, float(cfg.get("move_speed", 1.0)) * CELL_SIZE * delta)
	if global_position.distance_to(target_pos) < 2.0:
		current_cell = _path[_path_index]
		_path_index += 1
		if _path_index >= _path.size():
			get_enemy_manager().notify_enemy_reached_core(runtime_id)


func setup_from_cfg(new_enemy_id: StringName, new_cfg: Dictionary, spawn_cell: Vector2i) -> void:
	enemy_id = new_enemy_id
	cfg = new_cfg.duplicate(true)
	max_hp = int(cfg.get("max_hp", 1))
	current_hp = max_hp
	current_cell = spawn_cell
	_blocked_by = -1
	_block_slot = 0
	_block_slot_count = 1
	_block_anchor_dir = Vector2.ZERO
	_attack_timer = 0.0
	_is_dead = false
	global_position = get_map_manager().cell_to_world(spawn_cell)
	recalc_path()
	var label := get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.theme = AppTheme.get_theme()
		label.text = String(cfg.get("name", enemy_id))
		label.position = Vector2(-30.0, -58.0)
	_update_status_view()
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ONE * (-DEBUG_SIZE * 0.5), Vector2.ONE * DEBUG_SIZE)
	draw_rect(rect, DEBUG_COLOR, false, 2.0)
	draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), DEBUG_COLOR, 1.5)
	draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0), DEBUG_COLOR, 1.5)


func receive_damage(value: int, damage_type: int) -> void:
	var final_damage := value
	if damage_type == GameEnums.DAMAGE_PHYSICAL:
		final_damage = CombatMath.calc_physical_damage(value, int(cfg.get("def", 0)))
	elif damage_type == GameEnums.DAMAGE_MAGIC:
		final_damage = CombatMath.calc_magic_damage(value, int(cfg.get("res", 0)))
	current_hp = max(current_hp - final_damage, 0)
	_update_status_view()
	_play_hit_effect()
	_debug_log("敌人 %s#%d 受到%s伤害：原始 %d，结算 %d，HP %d/%d" % [_debug_name(), runtime_id, _damage_type_text(damage_type), value, final_damage, current_hp, max_hp])
	if current_hp == 0 and not _is_dead:
		_is_dead = true
		_debug_log("敌人 %s#%d 死亡" % [_debug_name(), runtime_id])
		get_enemy_manager().remove_enemy(runtime_id)


func get_runtime_id() -> int:
	return runtime_id


func get_current_cell() -> Vector2i:
	return current_cell


func recalc_path() -> void:
	var path_service := get_node_or_null("../../../Managers/PathService")
	var map_manager := get_map_manager()
	if map_manager == null:
		return
	var core_cell: Vector2i = map_manager.get_core_cell()
	if path_service != null:
		_path = path_service.find_path(current_cell, core_cell)
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
	var core_distance := 0.0
	var map_manager := get_map_manager()
	if map_manager != null:
		core_distance = float(get_current_cell().distance_squared_to(map_manager.get_core_cell()))
	return float(_path_index) * 100000.0 - core_distance


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


func _get_blocker() -> Node:
	var unit_manager := get_unit_manager()
	return unit_manager.get_unit_by_runtime_id(_blocked_by) if unit_manager != null else null


func _process_blocked_motion(delta: float, blocker: Node) -> void:
	var target_pos := _get_block_hold_position(blocker)
	var snap_speed := float(cfg.get("blocked_snap_speed", BLOCK_SNAP_SPEED / CELL_SIZE)) * CELL_SIZE
	global_position = global_position.move_toward(target_pos, snap_speed * delta)
	var map_manager := get_map_manager()
	if map_manager != null:
		current_cell = map_manager.world_to_cell(global_position)


func _process_blocked_attack(delta: float, blocker: Node) -> void:
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return
	var damage_type := _parse_damage_type(String(cfg.get("damage_type", "physical")))
	var damage_value := int(cfg.get("atk", 1))
	_debug_log("敌人 %s#%d 攻击阻挡单位 %s#%d，%s伤害 %d" % [_debug_name(), runtime_id, blocker.unit_id, blocker.get_runtime_id(), _damage_type_text(damage_type), damage_value])
	blocker.receive_damage(damage_value, damage_type)
	_attack_timer = max(float(cfg.get("attack_interval", 1.0)), 0.05)


func _get_block_hold_position(blocker: Node) -> Vector2:
	var anchor_dir := _block_anchor_dir
	if anchor_dir == Vector2.ZERO:
		anchor_dir = _resolve_block_anchor_dir(_blocked_by)
	var perpendicular := Vector2(-anchor_dir.y, anchor_dir.x)
	var centered_slot := float(_block_slot) - float(_block_slot_count - 1) * 0.5
	var hold_distance := float(cfg.get("block_hold_distance", BLOCK_HOLD_DISTANCE))
	var spread_distance := float(cfg.get("block_spread_distance", BLOCK_SPREAD_DISTANCE))
	return blocker.global_position + anchor_dir * hold_distance + perpendicular * centered_slot * spread_distance


func _resolve_block_anchor_dir(blocker_runtime_id: int) -> Vector2:
	var blocker := _get_unit_by_runtime_id(blocker_runtime_id)
	if blocker != null:
		var direct: Vector2 = global_position - blocker.global_position
		if direct.length() > 0.01:
			return direct.normalized()
	var move_dir := _get_current_move_direction()
	if move_dir.length() > 0.01:
		return -move_dir.normalized()
	return Vector2.LEFT


func _get_unit_by_runtime_id(unit_runtime_id: int) -> Node:
	var unit_manager := get_unit_manager()
	return unit_manager.get_unit_by_runtime_id(unit_runtime_id) if unit_manager != null else null


func _get_current_move_direction() -> Vector2:
	var map_manager := get_map_manager()
	if map_manager == null or _path.is_empty():
		return Vector2.ZERO
	var from_cell := current_cell
	var to_cell := _path[min(_path_index, _path.size() - 1)]
	if _path_index > 0 and _path_index < _path.size():
		from_cell = _path[_path_index - 1]
	var from_pos: Vector2 = map_manager.cell_to_world(from_cell)
	var to_pos: Vector2 = map_manager.cell_to_world(to_cell)
	return to_pos - from_pos


func _parse_damage_type(raw_type: String) -> int:
	match raw_type:
		"magic":
			return GameEnums.DAMAGE_MAGIC
		"true":
			return GameEnums.DAMAGE_TRUE
		_:
			return GameEnums.DAMAGE_PHYSICAL


func _debug_log(message: String) -> void:
	var tree := get_tree()
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
