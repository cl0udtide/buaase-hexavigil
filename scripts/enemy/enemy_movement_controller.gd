extends Node

const PATH_MODE_NORMAL: StringName = &"normal"
const PATH_MODE_DEMOLISHER: StringName = &"demolisher"
const PATH_MODE_FLYING: StringName = &"flying"
const CELL_SIZE := 64.0
const BLOCK_HOLD_DISTANCE := CELL_SIZE * 0.5
const BLOCK_SPREAD_DISTANCE := CELL_SIZE * 0.22
const BLOCK_SNAP_SPEED := CELL_SIZE * 6.0

var _owner_actor: Node2D = null
var _path: Array[Vector2i] = []
var _path_index := 0
var _blocked_by := -1
var _path_mode: StringName = PATH_MODE_NORMAL
var _block_slot := 0
var _block_slot_count := 1
var _block_anchor_dir := Vector2.ZERO
var _external_move_speed_multiplier: float = 1.0


func setup(owner_actor: Node2D) -> void:
	_owner_actor = owner_actor
	reset()


func reset() -> void:
	_path.clear()
	_path_index = 0
	_blocked_by = -1
	_block_slot = 0
	_block_slot_count = 1
	_block_anchor_dir = Vector2.ZERO
	_external_move_speed_multiplier = 1.0
	refresh_path_mode()


func refresh_path_mode() -> void:
	_path_mode = _resolve_path_mode()


func recalc_path() -> void:
	var path_service: Node = _owner_actor.get_node_or_null("../../../Managers/PathService") if _owner_actor != null else null
	var map_manager: Node = _get_map_manager()
	if map_manager == null:
		return
	var core_cell: Vector2i = map_manager.get_core_cell()
	if path_service != null:
		_path = path_service.find_path(_owner_actor.current_cell, core_cell, _path_mode)
		_path_index = min(1, _path.size() - 1) if not _path.is_empty() else 0


func has_path() -> bool:
	return not _path.is_empty()


func has_arrived() -> bool:
	return not _path.is_empty() and _path_index >= _path.size()


func get_next_path_cell() -> Vector2i:
	if _path.is_empty() or _path_index >= _path.size():
		return _owner_actor.current_cell
	return _path[_path_index]


func get_path_mode() -> StringName:
	return _path_mode


func process_path_movement(delta: float) -> bool:
	if _path.is_empty():
		return false
	if _path_index >= _path.size():
		return true
	var map_manager: Node = _get_map_manager()
	if map_manager == null:
		return false
	var target_pos: Vector2 = map_manager.cell_to_world(_path[_path_index])
	_owner_actor.global_position = _owner_actor.global_position.move_toward(target_pos, get_effective_move_speed() * CELL_SIZE * delta)
	if _owner_actor.global_position.distance_to(target_pos) < 2.0:
		_owner_actor.current_cell = _path[_path_index]
		_path_index += 1
		return _path_index >= _path.size()
	return false


func process_blocked_motion(delta: float, blocker: Node) -> void:
	var target_pos: Vector2 = _get_block_hold_position(blocker)
	var snap_speed: float = float(_owner_actor.cfg.get("blocked_snap_speed", BLOCK_SNAP_SPEED / CELL_SIZE)) * CELL_SIZE
	_owner_actor.global_position = _owner_actor.global_position.move_toward(target_pos, snap_speed * delta)
	var map_manager: Node = _get_map_manager()
	if map_manager != null:
		_owner_actor.current_cell = map_manager.world_to_cell(_owner_actor.global_position)


func apply_push(direction: Vector2i, tiles: int) -> bool:
	if _owner_actor == null or _blocked_by != -1 or tiles <= 0:
		return false
	var push_dir: Vector2i = _normalize_push_direction(direction)
	if push_dir == Vector2i.ZERO:
		return false
	var map_manager: Node = _get_map_manager()
	if map_manager == null:
		return false
	var target_cell: Vector2i = _owner_actor.current_cell
	for _step in range(tiles):
		var next_cell: Vector2i = target_cell + push_dir
		if not _can_push_to_cell(next_cell):
			break
		target_cell = next_cell
	if target_cell == _owner_actor.current_cell:
		return false
	_owner_actor.current_cell = target_cell
	_owner_actor.global_position = map_manager.cell_to_world(_owner_actor.current_cell)
	recalc_path()
	_debug_log("敌人 %s#%d 被推动到格子 %s" % [_debug_name(), _runtime_id(), _owner_actor.current_cell])
	return true


func set_blocked(blocker_runtime_id: int, block_slot: int = 0, block_slot_count: int = 1) -> void:
	if _blocked_by != blocker_runtime_id:
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
	var map_manager: Node = _get_map_manager()
	if map_manager != null:
		core_distance = float(_owner_actor.current_cell.distance_squared_to(map_manager.get_core_cell()))
	return float(_path_index) * 100000.0 - core_distance


func get_effective_move_speed() -> float:
	return max(float(_owner_actor.cfg.get("move_speed", 1.0)) * _external_move_speed_multiplier, 0.05)


func set_external_move_speed_multiplier(value: float) -> void:
	_external_move_speed_multiplier = max(value, 0.1)


func _get_block_hold_position(blocker: Node) -> Vector2:
	var anchor_dir: Vector2 = _block_anchor_dir
	if anchor_dir == Vector2.ZERO:
		anchor_dir = _resolve_block_anchor_dir(_blocked_by)
	var perpendicular: Vector2 = Vector2(-anchor_dir.y, anchor_dir.x)
	var centered_slot: float = float(_block_slot) - float(_block_slot_count - 1) * 0.5
	var hold_distance: float = float(_owner_actor.cfg.get("block_hold_distance", BLOCK_HOLD_DISTANCE))
	var spread_distance: float = float(_owner_actor.cfg.get("block_spread_distance", BLOCK_SPREAD_DISTANCE))
	return blocker.global_position + anchor_dir * hold_distance + perpendicular * centered_slot * spread_distance


func _resolve_block_anchor_dir(blocker_runtime_id: int) -> Vector2:
	var blocker: Node = _get_unit_by_runtime_id(blocker_runtime_id)
	if blocker != null:
		var direct: Vector2 = _owner_actor.global_position - blocker.global_position
		if direct.length() > 0.01:
			return direct.normalized()
	var move_dir: Vector2 = _get_current_move_direction()
	if move_dir.length() > 0.01:
		return -move_dir.normalized()
	return Vector2.LEFT


func _get_current_move_direction() -> Vector2:
	var map_manager: Node = _get_map_manager()
	if map_manager == null or _path.is_empty():
		return Vector2.ZERO
	var from_cell: Vector2i = _owner_actor.current_cell
	var to_cell: Vector2i = _path[min(_path_index, _path.size() - 1)]
	if _path_index > 0 and _path_index < _path.size():
		from_cell = _path[_path_index - 1]
	var from_pos: Vector2 = map_manager.cell_to_world(from_cell)
	var to_pos: Vector2 = map_manager.cell_to_world(to_cell)
	return to_pos - from_pos


func _can_push_to_cell(cell: Vector2i) -> bool:
	var map_manager: Node = _get_map_manager()
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


func _get_unit_by_runtime_id(unit_runtime_id: int) -> Node:
	var unit_manager: Node = _owner_actor.get_unit_manager() if _owner_actor != null else null
	return unit_manager.get_unit_by_runtime_id(unit_runtime_id) if unit_manager != null else null


func _get_map_manager() -> Node:
	return _owner_actor.get_map_manager() if _owner_actor != null else null


func _resolve_path_mode() -> StringName:
	if _owner_actor == null:
		return PATH_MODE_NORMAL
	var move_type: StringName = StringName(_owner_actor.cfg.get("move_type", "ground"))
	if move_type == PATH_MODE_FLYING:
		return PATH_MODE_FLYING

	var behavior_type: StringName = StringName(_owner_actor.cfg.get("behavior_type", "normal"))
	match behavior_type:
		&"demolisher", &"siege", &"rush", &"breaker":
			return PATH_MODE_DEMOLISHER
		_:
			return PATH_MODE_NORMAL


func _debug_log(message: String) -> void:
	if _owner_actor != null and _owner_actor.has_method("_debug_log"):
		_owner_actor._debug_log(message)


func _debug_name() -> String:
	if _owner_actor == null:
		return "未知敌人"
	return String(_owner_actor.cfg.get("name", _owner_actor.enemy_id))


func _runtime_id() -> int:
	return int(_owner_actor.get_runtime_id()) if _owner_actor != null else -1
