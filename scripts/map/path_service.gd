extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const PATH_MODE_NORMAL: StringName = &"normal"
const PATH_MODE_DEMOLISHER: StringName = &"demolisher"
const PATH_MODE_FLYING: StringName = &"flying"
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP
]
const SCORE_INF := 1_000_000_000

@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _building_manager: Node = get_node_or_null("../BuildingManager")

var _terrain_blocked_cells: Dictionary = {}
var _normal_blocked_cells: Dictionary = {}
var _grid_ready: bool = false


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.path_grid_changed.connect(_on_path_grid_changed)
	rebuild_from_map()


func rebuild_from_map() -> void:
	_terrain_blocked_cells.clear()
	_normal_blocked_cells.clear()
	_grid_ready = false
	if _map_manager == null:
		return
	for y in range(_map_manager.height):
		for x in range(_map_manager.width):
			var cell: Vector2i = Vector2i(x, y)
			var data: CellData = _map_manager.get_cell_data(cell)
			if data == null:
				continue
			if not data.walkable:
				_terrain_blocked_cells[cell] = true
				_normal_blocked_cells[cell] = true
				continue
			if _is_path_blocking_building(data):
				_normal_blocked_cells[cell] = true
	_grid_ready = true


func find_path(start_cell: Vector2i, end_cell: Vector2i, path_mode: StringName = PATH_MODE_NORMAL) -> Array[Vector2i]:
	if _map_manager == null:
		return []
	if not _grid_ready:
		rebuild_from_map()
	if not _map_manager.is_inside(start_cell) or not _map_manager.is_inside(end_cell):
		return []
	if start_cell == end_cell:
		return [start_cell]
	if path_mode == PATH_MODE_FLYING:
		return _make_flying_path(start_cell, end_cell)

	var blocked_cells: Dictionary = _get_blocked_cells_for_mode(path_mode)
	if blocked_cells.get(end_cell, false):
		return []

	var open_set: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}
	g_score[start_cell] = 0
	f_score[start_cell] = _estimate_cost(start_cell, end_cell)

	while not open_set.is_empty():
		var current: Vector2i = _pop_best_open_cell(open_set, end_cell, f_score)
		if current == end_cell:
			return _reconstruct_path(came_from, current)

		var current_g := int(g_score.get(current, SCORE_INF))
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if not _map_manager.is_inside(neighbor):
				continue
			if neighbor != end_cell and blocked_cells.get(neighbor, false):
				continue

			var tentative_g: int = current_g + 1
			if tentative_g >= int(g_score.get(neighbor, SCORE_INF)):
				continue

			came_from[neighbor] = current
			g_score[neighbor] = tentative_g
			f_score[neighbor] = tentative_g + _estimate_cost(neighbor, end_cell)
			if not open_set.has(neighbor):
				open_set.append(neighbor)

	return []


func get_cell_path(start_cell: Vector2i, end_cell: Vector2i, path_mode: StringName = PATH_MODE_NORMAL) -> Array[Vector2i]:
	return find_path(start_cell, end_cell, path_mode)


func has_path(start_cell: Vector2i, end_cell: Vector2i, path_mode: StringName = PATH_MODE_NORMAL) -> bool:
	return not find_path(start_cell, end_cell, path_mode).is_empty()


func set_cell_blocked(cell: Vector2i, blocked: bool) -> void:
	_grid_ready = true
	if blocked:
		_normal_blocked_cells[cell] = true
	else:
		_normal_blocked_cells.erase(cell)


func _on_path_grid_changed() -> void:
	rebuild_from_map()


func _estimate_cost(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return absi(from_cell.x - to_cell.x) + absi(from_cell.y - to_cell.y)


func _get_blocked_cells_for_mode(path_mode: StringName) -> Dictionary:
	if path_mode == PATH_MODE_DEMOLISHER:
		return _terrain_blocked_cells
	return _normal_blocked_cells


func _make_flying_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [start_cell]
	var current := start_cell
	while current.x != end_cell.x:
		current.x += signi(end_cell.x - current.x)
		path.append(current)
	while current.y != end_cell.y:
		current.y += signi(end_cell.y - current.y)
		path.append(current)
	return path


func _is_path_blocking_building(data: CellData) -> bool:
	if data.building_runtime_id < 0 or _building_manager == null:
		return false
	if not _building_manager.has_method("get_building_by_runtime_id"):
		return false
	var building: Node = _building_manager.get_building_by_runtime_id(data.building_runtime_id)
	if building == null:
		return false
	if _is_building_destroyed(building):
		return false
	if building.get("building_id") == &"wood_wall":
		return true
	var cfg_variant: Variant = building.get("cfg")
	if typeof(cfg_variant) != TYPE_DICTIONARY:
		return false
	var cfg: Dictionary = cfg_variant
	return bool(cfg.get("blocks_path", false))


func _is_building_destroyed(building: Node) -> bool:
	if building == null:
		return false
	if building.has_method("is_destroyed"):
		return bool(building.is_destroyed())
	var current_hp_variant: Variant = building.get("current_hp")
	return current_hp_variant != null and int(current_hp_variant) <= 0


func _pop_best_open_cell(open_set: Array[Vector2i], end_cell: Vector2i, f_score: Dictionary) -> Vector2i:
	var best_index: int = 0
	var best_cell: Vector2i = open_set[0]
	var best_f: int = int(f_score.get(best_cell, SCORE_INF))
	var best_h: int = _estimate_cost(best_cell, end_cell)
	for i in range(1, open_set.size()):
		var candidate: Vector2i = open_set[i]
		var candidate_f: int = int(f_score.get(candidate, SCORE_INF))
		var candidate_h: int = _estimate_cost(candidate, end_cell)
		if candidate_f < best_f or (candidate_f == best_f and candidate_h < best_h):
			best_index = i
			best_cell = candidate
			best_f = candidate_f
			best_h = candidate_h
	open_set.remove_at(best_index)
	return best_cell


func _reconstruct_path(came_from: Dictionary, end_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [end_cell]
	var current: Vector2i = end_cell
	while came_from.has(current):
		current = Vector2i(came_from[current])
		path.push_front(current)
	return path
