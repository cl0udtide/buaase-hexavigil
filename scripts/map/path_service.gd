extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const FlowField = preload("res://scripts/map/flow_field.gd")

const PATH_MODE_NORMAL: StringName = &"normal"
const PATH_MODE_DEMOLISHER: StringName = &"demolisher"
const PATH_MODE_FLYING: StringName = &"flying"
const MIN_PREVIEW_PATH_CELLS := 4
const PREVIEW_CENTER_PHASE := 0.5
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
# 敌人共享场（按 mode）：cell→CellData 快照、cell→步数、cell→{g,axis,width,frac}
var _cells: Dictionary = {}
var _dist_by_mode: Dictionary = {}
var _front_by_mode: Dictionary = {}


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.path_grid_changed.connect(_on_path_grid_changed)
	rebuild_from_map()


func rebuild_from_map() -> void:
	_terrain_blocked_cells.clear()
	_normal_blocked_cells.clear()
	_cells.clear()
	_grid_ready = false
	if _map_manager == null:
		return
	for y in range(_map_manager.height):
		for x in range(_map_manager.width):
			var cell: Vector2i = Vector2i(x, y)
			var data: CellData = _map_manager.get_cell_data(cell)
			if data == null:
				continue
			_cells[cell] = data
			if not data.walkable:
				_terrain_blocked_cells[cell] = true
				_normal_blocked_cells[cell] = true
				continue
			if _is_path_blocking_building(data):
				_normal_blocked_cells[cell] = true
	_grid_ready = true
	_rebuild_fields()


## 重建按 mode 的距离场 + 正面结构（normal 绕墙、demolisher 无视墙）。随 rebuild_from_map 调用。
func _rebuild_fields() -> void:
	_dist_by_mode.clear()
	_front_by_mode.clear()
	if _map_manager == null:
		return
	var core: Vector2i = _map_manager.get_core_cell()
	var dist_normal: Dictionary = FlowField.compute_distance(_cells, core, _normal_blocked_cells)
	_dist_by_mode[PATH_MODE_NORMAL] = dist_normal
	_front_by_mode[PATH_MODE_NORMAL] = FlowField.compute_front(_cells, dist_normal, _normal_blocked_cells)
	var dist_demo: Dictionary = FlowField.compute_distance(_cells, core, _terrain_blocked_cells)
	_dist_by_mode[PATH_MODE_DEMOLISHER] = dist_demo
	_front_by_mode[PATH_MODE_DEMOLISHER] = FlowField.compute_front(_cells, dist_demo, _terrain_blocked_cells)


func get_dist_map(path_mode: StringName) -> Dictionary:
	return _dist_by_mode.get(path_mode, {})


func get_front_map(path_mode: StringName) -> Dictionary:
	return _front_by_mode.get(path_mode, {})


func get_path_blocker_cells() -> Dictionary:
	if not _grid_ready:
		rebuild_from_map()
	var blockers: Dictionary = {}
	for cell_variant: Variant in _normal_blocked_cells.keys():
		if not bool(_normal_blocked_cells.get(cell_variant, false)):
			continue
		if bool(_terrain_blocked_cells.get(cell_variant, false)):
			continue
		blockers[cell_variant] = true
	return blockers


func has_route(cell: Vector2i, path_mode: StringName) -> bool:
	return (_dist_by_mode.get(path_mode, {}) as Dictionary).has(cell)


## 到核心步数；无路返回 -1。
func get_core_distance(cell: Vector2i, path_mode: StringName) -> int:
	return int((_dist_by_mode.get(path_mode, {}) as Dictionary).get(cell, -1))


## 出怪口覆盖面预览：从出怪口沿真实下行候选展开，展示怪物当前可能走到的格子。
## hard_blocked_cells 用于白天拖拽墙体的假设阻挡；soft_blocked_cells 与敌人移动同义，优先绕开但窄口可进入。
## 返回 {ok, status, message, coverage:Array[Vector2i], centerline:Array[Vector2i], effective_path_mode}。
func compute_coverage(
		spawn_cell: Vector2i,
		requested_mode: StringName,
		_half_width: int,
		hard_blocked_cells: Dictionary = {},
		soft_blocked_cells: Dictionary = {}
	) -> Dictionary:
	if _map_manager == null:
		return {"ok": false, "status": &"no_path", "message": "", "coverage": [], "centerline": [], "effective_path_mode": requested_mode}
	if not _grid_ready:
		rebuild_from_map()
	var core: Vector2i = _map_manager.get_core_cell()
	if requested_mode == PATH_MODE_FLYING:
		var line: Array[Vector2i] = _make_flying_path(spawn_cell, core)
		return {"ok": true, "status": &"ok", "message": "", "coverage": line.duplicate(), "centerline": line, "effective_path_mode": PATH_MODE_FLYING}
	var mode := requested_mode
	var status: StringName = &"ok"
	var message := ""
	var route_maps: Dictionary = _get_route_maps_for_coverage(mode, hard_blocked_cells)
	var dist: Dictionary = route_maps.get("dist", {})
	var front: Dictionary = route_maps.get("front", {})
	if not dist.has(spawn_cell):
		if mode == PATH_MODE_NORMAL:
			var demolisher_maps: Dictionary = _get_route_maps_for_coverage(PATH_MODE_DEMOLISHER, hard_blocked_cells)
			var demolisher_dist: Dictionary = demolisher_maps.get("dist", {})
			if not demolisher_dist.has(spawn_cell):
				return {"ok": false, "status": &"no_path", "message": "无法生成从出怪点到核心的有效路径", "coverage": [], "centerline": [], "effective_path_mode": requested_mode}
			mode = PATH_MODE_DEMOLISHER
			status = &"core_enclosed"
			message = "普通路线封闭：敌人将改走拆墙路径"
			route_maps = demolisher_maps
			dist = demolisher_dist
			front = route_maps.get("front", {})
		else:
			return {"ok": false, "status": &"no_path", "message": "无法生成从出怪点到核心的有效路径", "coverage": [], "centerline": [], "effective_path_mode": requested_mode}
	var preview_soft_blocked: Dictionary = _get_soft_blocked_for_coverage(mode, hard_blocked_cells, soft_blocked_cells)
	var centerline := _trace_phase_line(spawn_cell, dist, front, preview_soft_blocked)
	var coverage := _trace_possible_cells(spawn_cell, dist, front, preview_soft_blocked)
	return {"ok": true, "status": status, "message": message, "coverage": coverage, "centerline": centerline, "effective_path_mode": mode}


func _get_route_maps_for_coverage(path_mode: StringName, hard_blocked_cells: Dictionary) -> Dictionary:
	if path_mode == PATH_MODE_DEMOLISHER or hard_blocked_cells.is_empty():
		return {
			"dist": get_dist_map(path_mode),
			"front": get_front_map(path_mode)
		}
	var blocked_cells: Dictionary = _get_blocked_cells_for_mode(path_mode, hard_blocked_cells)
	var core: Vector2i = _map_manager.get_core_cell()
	var dist: Dictionary = FlowField.compute_distance(_cells, core, blocked_cells)
	return {
		"dist": dist,
		"front": FlowField.compute_front(_cells, dist, blocked_cells)
	}


func _get_soft_blocked_for_coverage(path_mode: StringName, hard_blocked_cells: Dictionary, soft_blocked_cells: Dictionary) -> Dictionary:
	var blocked: Dictionary = {}
	_merge_truthy_cells(blocked, soft_blocked_cells)
	if path_mode == PATH_MODE_DEMOLISHER:
		_merge_truthy_cells(blocked, get_path_blocker_cells(), 2)
		_merge_truthy_cells(blocked, hard_blocked_cells, 2)
	return blocked


func _trace_phase_line(spawn_cell: Vector2i, dist: Dictionary, front: Dictionary, soft_blocked_cells: Dictionary) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	var cell := spawn_cell
	var guard := 0
	var limit := _cells.size() + 1
	while dist.has(cell) and guard < limit:
		line.append(cell)
		var next_cell: Vector2i = FlowField.descend_step(dist, front, cell, PREVIEW_CENTER_PHASE, soft_blocked_cells)
		if next_cell == cell:
			break
		cell = next_cell
		guard += 1
	return line


func _trace_possible_cells(spawn_cell: Vector2i, dist: Dictionary, front: Dictionary, soft_blocked_cells: Dictionary) -> Array[Vector2i]:
	if not dist.has(spawn_cell):
		return []
	var covered: Dictionary = {}
	var stack: Array[Vector2i] = [spawn_cell]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if covered.has(cell):
			continue
		covered[cell] = true
		var choices: Array[Vector2i] = FlowField.descend_choices(dist, front, cell, soft_blocked_cells)
		for next_cell: Vector2i in choices:
			if not covered.has(next_cell):
				stack.append(next_cell)
	return _sorted_cell_keys(covered)


func _sorted_cell_keys(cells: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell_variant: Variant in cells.keys():
		var cell: Vector2i = cell_variant
		out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	return out


func find_path(start_cell: Vector2i, end_cell: Vector2i, path_mode: StringName = PATH_MODE_NORMAL, extra_blocked_cells: Dictionary = {}) -> Array[Vector2i]:
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

	var blocked_cells: Dictionary = _get_blocked_cells_for_mode(path_mode, extra_blocked_cells)
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


func find_path_preview(start_cell: Vector2i, end_cell: Vector2i, path_mode: StringName = PATH_MODE_NORMAL, extra_blocked_cells: Dictionary = {}) -> Dictionary:
	var path: Array[Vector2i] = find_path(start_cell, end_cell, path_mode, extra_blocked_cells)
	var effective_path_mode := path_mode
	var status: StringName = &"ok"
	var message := ""

	if path.is_empty() and path_mode == PATH_MODE_NORMAL and is_core_enclosed_by_path_blockers(end_cell, extra_blocked_cells):
		var demolisher_path: Array[Vector2i] = find_path(start_cell, end_cell, PATH_MODE_DEMOLISHER)
		if not demolisher_path.is_empty():
			path = demolisher_path
			effective_path_mode = PATH_MODE_DEMOLISHER
			status = &"core_enclosed"
			message = "普通路线封闭：敌人将改走拆墙路径"

	if path.is_empty():
		return {
			"ok": false,
			"status": &"no_path",
			"message": "无法生成从出怪点到核心的有效路径",
			"path": [],
			"requested_path_mode": path_mode,
			"effective_path_mode": effective_path_mode
		}
	if path.size() < MIN_PREVIEW_PATH_CELLS and status == &"ok":
		status = &"path_too_short"
		message = "出怪点到核心的路径过短"
	return {
		"ok": true,
		"status": status,
		"message": message,
		"path": path,
		"requested_path_mode": path_mode,
		"effective_path_mode": effective_path_mode
	}


func get_cell_path(start_cell: Vector2i, end_cell: Vector2i, path_mode: StringName = PATH_MODE_NORMAL, extra_blocked_cells: Dictionary = {}) -> Array[Vector2i]:
	return find_path(start_cell, end_cell, path_mode, extra_blocked_cells)


func has_path(start_cell: Vector2i, end_cell: Vector2i, path_mode: StringName = PATH_MODE_NORMAL, extra_blocked_cells: Dictionary = {}) -> bool:
	return not find_path(start_cell, end_cell, path_mode, extra_blocked_cells).is_empty()


func is_core_enclosed_by_path_blockers(core_cell: Vector2i, extra_blocked_cells: Dictionary = {}) -> bool:
	if _map_manager == null or not _map_manager.is_inside(core_cell):
		return false
	if not _grid_ready:
		rebuild_from_map()
	var blocked_cells := _get_blocked_cells_for_mode(PATH_MODE_NORMAL, extra_blocked_cells)
	var queue: Array[Vector2i] = [core_cell]
	var visited: Dictionary = {core_cell: true}
	var head := 0
	var found_path_blocker := false
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if _is_edge_cell(current):
			return false
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if not _map_manager.is_inside(neighbor) or visited.has(neighbor):
				continue
			var data: CellData = _map_manager.get_cell_data(neighbor)
			if data == null or not data.walkable:
				continue
			if blocked_cells.get(neighbor, false):
				found_path_blocker = true
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return found_path_blocker


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


func _get_blocked_cells_for_mode(path_mode: StringName, extra_blocked_cells: Dictionary = {}) -> Dictionary:
	if path_mode == PATH_MODE_DEMOLISHER:
		return _terrain_blocked_cells
	if extra_blocked_cells.is_empty():
		return _normal_blocked_cells
	var blocked_cells := _normal_blocked_cells.duplicate()
	for cell_variant: Variant in extra_blocked_cells.keys():
		if bool(extra_blocked_cells.get(cell_variant, false)):
			blocked_cells[cell_variant] = true
	return blocked_cells


func _merge_truthy_cells(target: Dictionary, source: Dictionary, score: int = 1) -> void:
	for cell_variant: Variant in source.keys():
		if bool(source.get(cell_variant, false)):
			target[cell_variant] = score


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


func _is_edge_cell(cell: Vector2i) -> bool:
	return cell.x <= 0 or cell.y <= 0 or cell.x >= int(_map_manager.width) - 1 or cell.y >= int(_map_manager.height) - 1


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
