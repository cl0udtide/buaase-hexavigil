extends Node

const FlowField = preload("res://scripts/map/flow_field.gd")

const PATH_MODE_NORMAL: StringName = &"normal"
const PATH_MODE_DEMOLISHER: StringName = &"demolisher"
const PATH_MODE_FLYING: StringName = &"flying"
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP
]
const CELL_SIZE := 64.0
const BLOCK_HOLD_DISTANCE := CELL_SIZE * 0.5
const BLOCK_SPREAD_DISTANCE := CELL_SIZE * 0.22
const BLOCK_SNAP_SPEED := CELL_SIZE * 6.0
const CROWD_SPREAD_DISTANCE := CELL_SIZE * 0.18
const CROWD_SNAP_SPEED := CELL_SIZE * 5.0
# 相位：黄金比低差异序列，相邻 runtime_id 错开 → 同代价分流时占不同平行路。
const PHASE_GOLDEN := 0.6180339887498949

var _owner_actor: Node2D = null
var _blocked_by := -1
var _base_path_mode: StringName = PATH_MODE_NORMAL
var _path_mode: StringName = PATH_MODE_NORMAL
var _lateral_phase: float = 0.0
var _block_slot := 0
var _block_slot_count := 1
var _block_anchor_dir := Vector2.ZERO
var _crowd_offset := Vector2.ZERO
var _external_move_speed_multiplier: float = 1.0


func setup(owner_actor: Node2D) -> void:
	_owner_actor = owner_actor
	_lateral_phase = _derive_phase()
	reset()


func reset() -> void:
	_blocked_by = -1
	_block_slot = 0
	_block_slot_count = 1
	_block_anchor_dir = Vector2.ZERO
	_crowd_offset = Vector2.ZERO
	_external_move_speed_multiplier = 1.0
	refresh_path_mode()


func refresh_path_mode() -> void:
	_base_path_mode = _resolve_path_mode()
	_path_mode = _base_path_mode


## 重判路径模式：普通怪在 normal 场到不了核心、但 demolisher 场能到 → 切拆墙。
func recalc_path() -> void:
	refresh_path_mode()
	var path_service := _path_service()
	if path_service == null or _owner_actor == null:
		return
	if _base_path_mode == PATH_MODE_NORMAL \
			and not path_service.has_route(_owner_actor.current_cell, PATH_MODE_NORMAL) \
			and path_service.has_route(_owner_actor.current_cell, PATH_MODE_DEMOLISHER):
		_path_mode = PATH_MODE_DEMOLISHER
		_debug_log("核心 normal 场不可达，敌人 %s#%d 切换拆墙路径" % [_debug_name(), _runtime_id()])
	else:
		_path_mode = _base_path_mode
	if has_path() and not has_arrived():
		_update_owner_facing_from_cell_delta(get_next_path_cell() - _owner_actor.current_cell)


func has_path() -> bool:
	if _owner_actor == null:
		return false
	if _path_mode == PATH_MODE_FLYING:
		return not has_arrived()
	var path_service := _path_service()
	return path_service != null and path_service.has_route(_owner_actor.current_cell, _path_mode)


func has_arrived() -> bool:
	if _owner_actor == null:
		return false
	var map_manager := _get_map_manager()
	return map_manager != null and _owner_actor.current_cell == map_manager.get_core_cell()


## 朝核心的梯度前进格（attack_controller 用它判路上是否有可拆的墙）。
func get_next_path_cell() -> Vector2i:
	if _owner_actor == null:
		return Vector2i.ZERO
	if has_arrived():
		return _owner_actor.current_cell
	if _path_mode == PATH_MODE_FLYING:
		return _straight_step_toward_core()
	var g := _gradient_dir()
	return _owner_actor.current_cell + g if g != Vector2i.ZERO else _owner_actor.current_cell


func get_path_mode() -> StringName:
	return _path_mode


func process_path_movement(delta: float) -> bool:
	if _owner_actor == null:
		return false
	if has_arrived():
		return true
	if not has_path():
		return false
	var map_manager: Node = _get_map_manager()
	if map_manager == null:
		return false
	var step_cell: Vector2i = _next_step_cell()
	_update_crowd_offset()
	_update_owner_facing_from_cell_delta(step_cell - _owner_actor.current_cell)
	var target_pos: Vector2 = map_manager.cell_to_world(step_cell) + _crowd_offset
	_owner_actor.global_position = _owner_actor.global_position.move_toward(target_pos, get_effective_move_speed() * CELL_SIZE * delta)
	if _owner_actor.global_position.distance_to(target_pos) < 2.0:
		_owner_actor.current_cell = step_cell
		return has_arrived()
	return false


func process_idle_crowd_spacing(delta: float) -> void:
	var previous_offset := _crowd_offset
	_update_crowd_offset()
	var map_manager: Node = _get_map_manager()
	if map_manager == null:
		return
	var base_position := _owner_actor.global_position - previous_offset
	var target_pos := base_position + _crowd_offset
	var snap_speed: float = float(_owner_actor.cfg.get("crowd_snap_speed", CROWD_SNAP_SPEED / CELL_SIZE)) * CELL_SIZE
	_owner_actor.global_position = _owner_actor.global_position.move_toward(target_pos, snap_speed * delta)


func process_blocked_motion(delta: float, blocker: Node) -> void:
	var target_pos: Vector2 = _get_block_hold_position(blocker)
	_update_owner_facing_from_vector(target_pos - _owner_actor.global_position)
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


## 进度分：越靠近核心分越高（阻挡排序/技能选敌用）。无路时退化为到核心曼哈顿。
func get_path_progress_score() -> float:
	if _owner_actor == null:
		return 0.0
	var dist := -1
	var path_service := _path_service()
	if path_service != null:
		dist = path_service.get_core_distance(_owner_actor.current_cell, _path_mode)
	if dist < 0:
		var map_manager := _get_map_manager()
		if map_manager != null:
			var core: Vector2i = map_manager.get_core_cell()
			dist = absi(_owner_actor.current_cell.x - core.x) + absi(_owner_actor.current_cell.y - core.y)
	return -float(dist)


func get_effective_move_speed() -> float:
	return max(float(_owner_actor.cfg.get("move_speed", 1.0)) * _external_move_speed_multiplier, 0.05)


func set_external_move_speed_multiplier(value: float) -> void:
	_external_move_speed_multiplier = max(value, 0.1)


# ── 沿场决策 ──────────────────────────────────────────────────

func _derive_phase() -> float:
	return fposmod(float(_runtime_id()) * PHASE_GOLDEN, 1.0)


func _path_service() -> Node:
	return _owner_actor.get_node_or_null("../../../Managers/PathService") if _owner_actor != null else null


func _next_step_cell() -> Vector2i:
	if _path_mode == PATH_MODE_FLYING:
		return _straight_step_toward_core()
	var path_service := _path_service()
	if path_service == null:
		return _owner_actor.current_cell
	return FlowField.descend_step(
		path_service.get_dist_map(_path_mode),
		path_service.get_front_map(_path_mode),
		_owner_actor.current_cell,
		_lateral_phase,
		_extra_blocked()
	)


func _gradient_dir() -> Vector2i:
	var path_service := _path_service()
	if path_service == null:
		return Vector2i.ZERO
	var front: Dictionary = path_service.get_front_map(_path_mode).get(_owner_actor.current_cell, {})
	return front.get("g", Vector2i.ZERO)


func _straight_step_toward_core() -> Vector2i:
	var map_manager := _get_map_manager()
	if map_manager == null:
		return _owner_actor.current_cell
	var core: Vector2i = map_manager.get_core_cell()
	var cur: Vector2i = _owner_actor.current_cell
	if cur.x != core.x:
		return cur + (Vector2i.RIGHT if core.x > cur.x else Vector2i.LEFT)
	if cur.y != core.y:
		return cur + (Vector2i.DOWN if core.y > cur.y else Vector2i.UP)
	return cur


## 怪应"能绕则绕"的占用格 = 已部署干员所在格。descend_step 优先未占的下行邻、
## 窄口无路则照走进去接敌。被阻挡中的怪走 process_blocked_motion，不经此处。
func _extra_blocked() -> Dictionary:
	var blocked: Dictionary = {}
	var unit_manager: Node = _owner_actor.get_unit_manager() if _owner_actor != null else null
	if unit_manager == null or not unit_manager.has_method("get_all_units"):
		return blocked
	for unit in unit_manager.get_all_units():
		if unit != null and is_instance_valid(unit) and unit.has_method("get_current_cell"):
			blocked[unit.get_current_cell()] = true
	return blocked


# ── 拥挤 / 阻挡 走位（沿用旧逻辑）────────────────────────────────

func _update_crowd_offset() -> void:
	if _owner_actor == null or _blocked_by != -1:
		_crowd_offset = Vector2.ZERO
		return
	var cell_peers := _get_unblocked_peers_in_cell(_owner_actor.current_cell)
	if cell_peers.size() <= 1:
		_crowd_offset = Vector2.ZERO
		return
	cell_peers.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get_runtime_id()) < int(b.get_runtime_id())
	)
	var owner_index := cell_peers.find(_owner_actor)
	if owner_index < 0:
		_crowd_offset = Vector2.ZERO
		return
	var direction := _get_current_move_direction()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var centered_slot := float(owner_index) - float(cell_peers.size() - 1) * 0.5
	var spread_distance := float(_owner_actor.cfg.get("crowd_spread_distance", CROWD_SPREAD_DISTANCE))
	_crowd_offset = perpendicular * centered_slot * spread_distance


func _get_unblocked_peers_in_cell(cell: Vector2i) -> Array:
	var peers: Array = []
	var enemy_manager: Node = _owner_actor.get_enemy_manager() if _owner_actor != null else null
	if enemy_manager == null or not enemy_manager.has_method("get_all_enemies"):
		return peers
	for enemy in enemy_manager.get_all_enemies():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_blocked") and enemy.is_blocked():
			continue
		if enemy.has_method("get_current_cell") and enemy.get_current_cell() == cell:
			peers.append(enemy)
	return peers


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
	if map_manager == null or _owner_actor == null:
		return Vector2.ZERO
	var next_cell: Vector2i = get_next_path_cell()
	if next_cell == _owner_actor.current_cell:
		return Vector2.ZERO
	return map_manager.cell_to_world(next_cell) - map_manager.cell_to_world(_owner_actor.current_cell)


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


func _update_owner_facing_from_cell_delta(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	if _owner_actor != null and _owner_actor.has_method("set_facing"):
		_owner_actor.set_facing(_normalize_push_direction(direction))


func _update_owner_facing_from_vector(direction: Vector2) -> void:
	if direction.length_squared() <= 0.01:
		return
	var cell_direction := Vector2i.ZERO
	if abs(direction.x) >= abs(direction.y):
		cell_direction = Vector2i.RIGHT if direction.x >= 0.0 else Vector2i.LEFT
	else:
		cell_direction = Vector2i.DOWN if direction.y >= 0.0 else Vector2i.UP
	_update_owner_facing_from_cell_delta(cell_direction)


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
	return PATH_MODE_DEMOLISHER if behavior_type == &"demolisher" else PATH_MODE_NORMAL


func _debug_log(message: String) -> void:
	if _owner_actor != null and _owner_actor.has_method("_debug_log"):
		_owner_actor._debug_log(message)


func _debug_name() -> String:
	if _owner_actor == null:
		return "未知敌人"
	return String(_owner_actor.cfg.get("name", _owner_actor.enemy_id))


func _runtime_id() -> int:
	return int(_owner_actor.get_runtime_id()) if _owner_actor != null else -1
