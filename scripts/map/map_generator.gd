class_name MapGenerator
extends RefCounted

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP
]
const OBSTACLE_RATIO := 0.11
const MIN_OBSTACLE_COUNT := 45
const MAX_OBSTACLE_COUNT := 95
const CORE_SAFE_RADIUS := 3
const SPAWN_SAFE_RADIUS := 1
const SPAWN_COUNT := 3
const RESOURCES_PER_TYPE := 12
const NEAR_RESOURCES_PER_TYPE := 2
const EVENT_POINT_COUNT := 8
const MIN_SPAWN_CORE_DISTANCE := 12
const MIN_SPAWN_DISTANCE := 10


static func generate(width: int, height: int, seed: int = -1, cfg: Dictionary = {}, event_ids: Array[StringName] = []) -> Dictionary:
	var cells := _create_plain_cells(width, height)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()

	var core_cell: Vector2i = Vector2i(width / 2, height / 2)
	_setup_core_and_initial_fog(cells, core_cell)
	var spawn_cells := _place_spawns(cells, width, height, core_cell, rng, cfg)
	_place_random_obstacles(cells, width, height, spawn_cells, core_cell, rng, cfg)
	_place_resources(cells, width, height, spawn_cells, core_cell, rng, cfg)
	var event_points := _place_event_points(cells, width, height, spawn_cells, core_cell, rng, cfg, event_ids)

	return {
		"cells": cells,
		"core_cell": core_cell,
		"spawn_cells": spawn_cells,
		"event_points": event_points
	}


static func _create_plain_cells(width: int, height: int) -> Dictionary:
	var cells: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var data: CellData = CellData.new()
			data.cell = Vector2i(x, y)
			data.terrain = &"plain"
			data.buildable = true
			data.walkable = true
			data.discovered = false
			cells[data.cell] = data
	return cells


static func _setup_core_and_initial_fog(cells: Dictionary, core_cell: Vector2i) -> void:
	var core_data: CellData = cells[core_cell]
	core_data.is_core = true
	core_data.terrain = &"core"
	core_data.buildable = false

	for y in range(core_cell.y - 2, core_cell.y + 3):
		for x in range(core_cell.x - 2, core_cell.x + 3):
			var reveal_cell: Vector2i = Vector2i(x, y)
			if cells.has(reveal_cell):
				var reveal_data: CellData = cells[reveal_cell]
				reveal_data.discovered = true


static func _place_spawns(cells: Dictionary, width: int, height: int, core_cell: Vector2i, rng: RandomNumberGenerator, cfg: Dictionary) -> Array[Vector2i]:
	var candidates := _get_edge_candidates(width, height)
	_shuffle_cells(candidates, rng)
	var spawn_cells: Array[Vector2i] = []
	var spawn_count: int = int(cfg.get("spawn_count", SPAWN_COUNT))
	var min_core_distance: int = int(cfg.get("min_spawn_core_distance", MIN_SPAWN_CORE_DISTANCE))
	var min_spawn_distance: int = int(cfg.get("min_spawn_distance", MIN_SPAWN_DISTANCE))
	for candidate in candidates:
		if spawn_cells.size() >= spawn_count:
			break
		if _manhattan(candidate, core_cell) < min_core_distance:
			continue
		var far_from_existing: bool = true
		for spawn_cell in spawn_cells:
			if _manhattan(candidate, spawn_cell) < min_spawn_distance:
				far_from_existing = false
				break
		if not far_from_existing:
			continue
		var spawn_data: CellData = cells[candidate]
		spawn_data.spawn_key = StringName("S%d" % (spawn_cells.size() + 1))
		spawn_data.terrain = &"spawn"
		spawn_data.discovered = false
		spawn_data.buildable = false
		spawn_cells.append(candidate)
	return spawn_cells


static func _get_edge_candidates(width: int, height: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for x in range(width):
		candidates.append(Vector2i(x, 0))
		candidates.append(Vector2i(x, height - 1))
	for y in range(1, height - 1):
		candidates.append(Vector2i(0, y))
		candidates.append(Vector2i(width - 1, y))
	return candidates


static func _place_resources(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator,
	cfg: Dictionary
) -> void:
	var near_candidates: Array[Vector2i] = []
	var far_candidates: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell: Vector2i = Vector2i(x, y)
			var near_ring := _is_near_exploration_ring(cell, core_cell)
			if _is_protected_cell(cell, core_cell, spawn_cells, cfg) and not near_ring:
				continue
			var data: CellData = cells[cell]
			if data == null or not data.walkable or data.resource_type != StringName() or data.spawn_key != StringName():
				continue
			if near_ring:
				near_candidates.append(cell)
			else:
				far_candidates.append(cell)
	_shuffle_cells(near_candidates, rng)
	_shuffle_cells(far_candidates, rng)

	var resource_types: Array[StringName] = [&"wood", &"stone", &"mana"]
	var placed_by_type: Dictionary = {}
	for resource_type in resource_types:
		placed_by_type[resource_type] = 0
	var target_per_type: int = int(cfg.get("resources_per_type", RESOURCES_PER_TYPE))
	var near_target_per_type: int = min(int(cfg.get("near_resources_per_type", NEAR_RESOURCES_PER_TYPE)), target_per_type)
	for resource_type in resource_types:
		_place_resource_type(cells, near_candidates, resource_type, near_target_per_type, placed_by_type)
	for resource_type in resource_types:
		_place_resource_type(cells, far_candidates, resource_type, target_per_type, placed_by_type)


static func _place_resource_type(
	cells: Dictionary,
	candidates: Array[Vector2i],
	resource_type: StringName,
	target_count: int,
	placed_by_type: Dictionary
) -> void:
	for cell in candidates.duplicate():
		if int(placed_by_type.get(resource_type, 0)) >= target_count:
			return
		var data: CellData = cells[cell]
		if data == null or data.resource_type != StringName() or not data.walkable:
			continue
		_set_resource_node(data, resource_type)
		placed_by_type[resource_type] = int(placed_by_type.get(resource_type, 0)) + 1
		candidates.erase(cell)


static func _set_resource_node(data: CellData, resource_type: StringName) -> void:
	data.terrain = &"resource"
	data.resource_type = resource_type
	data.buildable = true
	data.walkable = true


static func _is_near_exploration_ring(cell: Vector2i, core_cell: Vector2i) -> bool:
	var distance: int = max(absi(cell.x - core_cell.x), absi(cell.y - core_cell.y))
	return distance >= 3 and distance <= 5


static func _place_random_obstacles(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator,
	cfg: Dictionary
) -> void:
	var candidates: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var cell: Vector2i = Vector2i(x, y)
			if _is_protected_cell(cell, core_cell, spawn_cells, cfg):
				continue
			var data: CellData = cells[cell]
			if data == null or data.resource_type != StringName() or data.spawn_key != StringName():
				continue
			candidates.append(cell)

	_shuffle_cells(candidates, rng)

	var obstacle_ratio: float = float(cfg.get("obstacle_ratio", OBSTACLE_RATIO))
	var min_obstacle_count: int = int(cfg.get("min_obstacle_count", MIN_OBSTACLE_COUNT))
	var max_obstacle_count: int = int(cfg.get("max_obstacle_count", MAX_OBSTACLE_COUNT))
	var target_count: int = max(min_obstacle_count, int(round(width * height * obstacle_ratio)))
	target_count = min(target_count, min(max_obstacle_count, candidates.size()))
	var placed_count: int = 0

	for cell in candidates:
		if placed_count >= target_count:
			break

		var data: CellData = cells.get(cell)
		if data == null:
			continue

		data.terrain = &"blocked"
		data.walkable = false
		data.buildable = false

		var all_spawns_connected: bool = true
		for spawn_cell in spawn_cells:
			if not _has_ground_path(cells, width, height, spawn_cell, core_cell):
				all_spawns_connected = false
				break

		if all_spawns_connected:
			placed_count += 1
		else:
			data.terrain = &"plain"
			data.walkable = true
			data.buildable = true


static func _place_event_points(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator,
	cfg: Dictionary,
	event_ids: Array[StringName]
) -> Array[Dictionary]:
	var event_points: Array[Dictionary] = []
	if event_ids.is_empty():
		return event_points
	var candidates: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell: Vector2i = Vector2i(x, y)
			if _is_protected_cell(cell, core_cell, spawn_cells, cfg):
				continue
			var data: CellData = cells[cell]
			if data == null or not data.walkable or data.resource_type != StringName() or data.spawn_key != StringName() or data.is_core:
				continue
			candidates.append(cell)
	_shuffle_cells(candidates, rng)

	var event_point_count: int = min(int(cfg.get("event_point_count", EVENT_POINT_COUNT)), candidates.size())
	for index in range(event_point_count):
		event_points.append({
			"cell": candidates[index],
			"event_id": event_ids[rng.randi_range(0, event_ids.size() - 1)]
		})
	return event_points


static func _is_protected_cell(cell: Vector2i, core_cell: Vector2i, spawn_cells: Array[Vector2i], cfg: Dictionary) -> bool:
	var core_safe_radius: int = int(cfg.get("core_safe_radius", CORE_SAFE_RADIUS))
	var spawn_safe_radius: int = int(cfg.get("spawn_safe_radius", SPAWN_SAFE_RADIUS))
	if max(absi(cell.x - core_cell.x), absi(cell.y - core_cell.y)) <= core_safe_radius:
		return true
	for spawn_cell in spawn_cells:
		if max(absi(cell.x - spawn_cell.x), absi(cell.y - spawn_cell.y)) <= spawn_safe_radius:
			return true
	return false


static func _has_ground_path(
	cells: Dictionary,
	width: int,
	height: int,
	start_cell: Vector2i,
	end_cell: Vector2i
) -> bool:
	var queue: Array[Vector2i] = [start_cell]
	var visited: Dictionary = {start_cell: true}
	var head: int = 0

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == end_cell:
			return true

		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			if visited.has(neighbor):
				continue

			var data: CellData = cells.get(neighbor)
			if data == null or not data.walkable:
				continue

			visited[neighbor] = true
			queue.append(neighbor)

	return false


static func _shuffle_cells(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	if cells.size() <= 1:
		return
	for i in range(cells.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, i)
		var temp: Vector2i = cells[i]
		cells[i] = cells[swap_index]
		cells[swap_index] = temp


static func _manhattan(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return absi(from_cell.x - to_cell.x) + absi(from_cell.y - to_cell.y)
