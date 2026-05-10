class_name MapGenerator
extends RefCounted

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP
]
const ALL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1)
]
const OBSTACLE_RATIO := 0.13
const MIN_OBSTACLE_COUNT := 65
const MAX_OBSTACLE_COUNT := 115
const TERRAIN_CLUSTER_COUNT := 5
const TERRAIN_CLUSTER_MIN_SIZE := 12
const TERRAIN_CLUSTER_MAX_SIZE := 28
const TERRAIN_CLUSTER_ATTEMPTS := 24
const SCATTERED_OBSTACLE_RATIO := 0.22
const CORE_SAFE_RADIUS := 3
const SPAWN_SAFE_RADIUS := 1
const SPAWN_COUNT := 3
const RESOURCES_PER_TYPE := 12
const NEAR_RESOURCES_PER_TYPE := 2
const EVENT_POINT_COUNT := 8
const MIN_SPAWN_CORE_DISTANCE := 12
const MIN_SPAWN_DISTANCE := 10
const WATER_OBSTACLE_CHANCE := 0.35


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
			data.set_base_terrain(CellData.TERRAIN_PLAIN)
			data.discovered = false
			cells[data.cell] = data
	return cells


static func _setup_core_and_initial_fog(cells: Dictionary, core_cell: Vector2i) -> void:
	var core_data: CellData = cells[core_cell]
	core_data.is_core = true
	core_data.set_base_terrain(CellData.TERRAIN_PLAIN)
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
		spawn_data.set_base_terrain(CellData.TERRAIN_PLAIN)
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
	data.set_base_terrain(CellData.TERRAIN_PLAIN)
	data.resource_type = resource_type


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
	var candidates: Array[Vector2i] = _get_obstacle_candidates(cells, width, height, spawn_cells, core_cell, cfg)
	var target_count: int = _get_obstacle_target_count(width, height, candidates.size(), cfg)
	if target_count <= 0:
		return
	var scattered_ratio: float = clampf(float(cfg.get("scattered_obstacle_ratio", SCATTERED_OBSTACLE_RATIO)), 0.0, 1.0)
	var scattered_target_count: int = int(round(float(target_count) * scattered_ratio))
	var cluster_target_count: int = _max_int(target_count - scattered_target_count, 0)
	var placed_count: int = _place_obstacle_clusters(cells, width, height, spawn_cells, core_cell, rng, cfg, cluster_target_count)
	if placed_count < target_count:
		_place_scattered_obstacles(cells, width, height, spawn_cells, core_cell, rng, cfg, target_count - placed_count)


static func _get_obstacle_target_count(width: int, height: int, candidate_count: int, cfg: Dictionary) -> int:
	var obstacle_ratio: float = float(cfg.get("obstacle_ratio", OBSTACLE_RATIO))
	var min_obstacle_count: int = int(cfg.get("min_obstacle_count", MIN_OBSTACLE_COUNT))
	var max_obstacle_count: int = int(cfg.get("max_obstacle_count", MAX_OBSTACLE_COUNT))
	var estimated_count: int = int(round(float(width * height) * obstacle_ratio))
	var target_count: int = _max_int(min_obstacle_count, estimated_count)
	return _min_int(_min_int(target_count, max_obstacle_count), candidate_count)


static func _place_obstacle_clusters(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator,
	cfg: Dictionary,
	target_count: int
) -> int:
	if target_count <= 0:
		return 0
	var cluster_count: int = _max_int(int(cfg.get("terrain_cluster_count", TERRAIN_CLUSTER_COUNT)), 0)
	if cluster_count <= 0:
		return 0
	var min_size: int = _max_int(int(cfg.get("terrain_cluster_min_size", TERRAIN_CLUSTER_MIN_SIZE)), 1)
	var max_size: int = _max_int(int(cfg.get("terrain_cluster_max_size", TERRAIN_CLUSTER_MAX_SIZE)), min_size)
	var attempts_per_cluster: int = _max_int(int(cfg.get("terrain_cluster_attempts", TERRAIN_CLUSTER_ATTEMPTS)), 1)
	var max_attempts: int = cluster_count * attempts_per_cluster
	var placed_count: int = 0
	var placed_clusters: int = 0
	var attempts: int = 0
	while placed_clusters < cluster_count and placed_count < target_count and attempts < max_attempts:
		attempts += 1
		var candidates: Array[Vector2i] = _get_obstacle_candidates(cells, width, height, spawn_cells, core_cell, cfg)
		if candidates.is_empty():
			break
		var center: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var desired_size: int = _min_int(rng.randi_range(min_size, max_size), target_count - placed_count)
		var terrain: StringName = _roll_obstacle_terrain(rng, cfg)
		var cluster_cells: Array[Vector2i] = _build_obstacle_cluster(cells, width, height, spawn_cells, core_cell, cfg, rng, center, desired_size, terrain)
		var minimum_viable_size: int = _max_int(3, int(ceil(float(min_size) * 0.5)))
		if cluster_cells.size() < minimum_viable_size:
			continue
		var applied_count: int = _try_apply_obstacle_cells(cells, cluster_cells, terrain, width, height, spawn_cells, core_cell, cfg)
		if applied_count <= 0:
			continue
		placed_count += applied_count
		placed_clusters += 1
	return placed_count


static func _place_scattered_obstacles(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator,
	cfg: Dictionary,
	target_count: int
) -> int:
	if target_count <= 0:
		return 0
	var candidates: Array[Vector2i] = _get_obstacle_candidates(cells, width, height, spawn_cells, core_cell, cfg)
	_shuffle_cells(candidates, rng)
	var placed_count: int = 0
	for cell in candidates:
		if placed_count >= target_count:
			break
		var terrain: StringName = _roll_obstacle_terrain(rng, cfg)
		var single_cell: Array[Vector2i] = []
		single_cell.append(cell)
		placed_count += _try_apply_obstacle_cells(cells, single_cell, terrain, width, height, spawn_cells, core_cell, cfg)
	return placed_count


static func _build_obstacle_cluster(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary,
	rng: RandomNumberGenerator,
	center: Vector2i,
	target_size: int,
	terrain: StringName
) -> Array[Vector2i]:
	if terrain == CellData.TERRAIN_WATER:
		return _build_lake_cluster(cells, width, height, spawn_cells, core_cell, cfg, rng, center, target_size)
	return _build_mountain_cluster(cells, width, height, spawn_cells, core_cell, cfg, rng, center, target_size)


static func _build_lake_cluster(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary,
	rng: RandomNumberGenerator,
	center: Vector2i,
	target_size: int
) -> Array[Vector2i]:
	var cluster: Array[Vector2i] = []
	var lookup: Dictionary = {}
	_try_add_cluster_cell(cells, width, height, spawn_cells, core_cell, cfg, center, cluster, lookup)
	var attempts: int = 0
	while cluster.size() < target_size and attempts < target_size * 16 and not cluster.is_empty():
		attempts += 1
		var base: Vector2i = cluster[rng.randi_range(0, cluster.size() - 1)]
		var direction: Vector2i = ALL_DIRECTIONS[rng.randi_range(0, ALL_DIRECTIONS.size() - 1)]
		_try_add_cluster_cell(cells, width, height, spawn_cells, core_cell, cfg, base + direction, cluster, lookup)
		if rng.randf() < 0.35:
			for neighbor_direction in CARDINAL_DIRECTIONS:
				if cluster.size() >= target_size:
					break
				if rng.randf() < 0.35:
					_try_add_cluster_cell(cells, width, height, spawn_cells, core_cell, cfg, base + neighbor_direction, cluster, lookup)
	return cluster


static func _build_mountain_cluster(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary,
	rng: RandomNumberGenerator,
	center: Vector2i,
	target_size: int
) -> Array[Vector2i]:
	var cluster: Array[Vector2i] = []
	var lookup: Dictionary = {}
	var current: Vector2i = center
	var direction: Vector2i = _random_cardinal_direction(rng)
	var attempts: int = 0
	while cluster.size() < target_size and attempts < target_size * 16:
		attempts += 1
		_try_add_cluster_cell(cells, width, height, spawn_cells, core_cell, cfg, current, cluster, lookup)
		for side_direction in _get_perpendicular_directions(direction):
			if cluster.size() >= target_size:
				break
			if rng.randf() < 0.45:
				_try_add_cluster_cell(cells, width, height, spawn_cells, core_cell, cfg, current + side_direction, cluster, lookup)
		if rng.randf() < 0.26:
			direction = _turn_cardinal_direction(direction, rng)
		var next_cell: Vector2i = current + direction
		if _is_obstacle_candidate(cells, width, height, spawn_cells, core_cell, cfg, next_cell):
			current = next_cell
		elif not cluster.is_empty():
			current = cluster[rng.randi_range(0, cluster.size() - 1)]
			direction = _random_cardinal_direction(rng)
		else:
			break
	return cluster


static func _try_add_cluster_cell(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary,
	cell: Vector2i,
	cluster: Array[Vector2i],
	lookup: Dictionary
) -> bool:
	if lookup.has(cell):
		return false
	if not _is_obstacle_candidate(cells, width, height, spawn_cells, core_cell, cfg, cell):
		return false
	lookup[cell] = true
	cluster.append(cell)
	return true


static func _try_apply_obstacle_cells(
	cells: Dictionary,
	obstacle_cells: Array[Vector2i],
	terrain: StringName,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary
) -> int:
	var applied_cells: Array[Vector2i] = []
	for cell in obstacle_cells:
		if not _is_obstacle_candidate(cells, width, height, spawn_cells, core_cell, cfg, cell):
			continue
		var data: CellData = cells.get(cell) as CellData
		if data == null:
			continue
		data.set_base_terrain(terrain)
		applied_cells.append(cell)
	if applied_cells.is_empty():
		return 0
	if _are_all_spawns_connected(cells, width, height, spawn_cells, core_cell):
		return applied_cells.size()
	for cell in applied_cells:
		var data: CellData = cells.get(cell) as CellData
		if data != null:
			data.set_base_terrain(CellData.TERRAIN_PLAIN)
	return 0


static func _get_obstacle_candidates(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var cell: Vector2i = Vector2i(x, y)
			if _is_obstacle_candidate(cells, width, height, spawn_cells, core_cell, cfg, cell):
				candidates.append(cell)
	return candidates


static func _is_obstacle_candidate(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary,
	cell: Vector2i
) -> bool:
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return false
	if _is_protected_cell(cell, core_cell, spawn_cells, cfg):
		return false
	var data: CellData = cells.get(cell) as CellData
	if data == null or data.resource_type != StringName() or data.spawn_key != StringName() or data.is_core:
		return false
	return data.walkable


static func _roll_obstacle_terrain(rng: RandomNumberGenerator, cfg: Dictionary) -> StringName:
	return CellData.TERRAIN_WATER if rng.randf() < float(cfg.get("water_obstacle_chance", WATER_OBSTACLE_CHANCE)) else CellData.TERRAIN_MOUNTAIN


static func _are_all_spawns_connected(cells: Dictionary, width: int, height: int, spawn_cells: Array[Vector2i], core_cell: Vector2i) -> bool:
	for spawn_cell in spawn_cells:
		if not _has_ground_path(cells, width, height, spawn_cell, core_cell):
			return false
	return true


static func _random_cardinal_direction(rng: RandomNumberGenerator) -> Vector2i:
	return CARDINAL_DIRECTIONS[rng.randi_range(0, CARDINAL_DIRECTIONS.size() - 1)]


static func _min_int(a: int, b: int) -> int:
	return a if a <= b else b


static func _max_int(a: int, b: int) -> int:
	return a if a >= b else b


static func _get_perpendicular_directions(direction: Vector2i) -> Array[Vector2i]:
	if direction.x != 0:
		var vertical_directions: Array[Vector2i] = []
		vertical_directions.append(Vector2i.UP)
		vertical_directions.append(Vector2i.DOWN)
		return vertical_directions
	var horizontal_directions: Array[Vector2i] = []
	horizontal_directions.append(Vector2i.LEFT)
	horizontal_directions.append(Vector2i.RIGHT)
	return horizontal_directions


static func _turn_cardinal_direction(direction: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var side_directions: Array[Vector2i] = _get_perpendicular_directions(direction)
	if rng.randf() < 0.75:
		return side_directions[rng.randi_range(0, side_directions.size() - 1)]
	return Vector2i(-direction.x, -direction.y)


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
