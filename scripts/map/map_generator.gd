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
const EXTRA_RESOURCES_PER_TYPE := 4

const STARTING_RESOURCE_OFFSETS := {
	&"wood": Vector2i(-2, -2),
	&"stone": Vector2i(2, -2),
	&"mana": Vector2i(-2, 2)
}


static func generate(width: int, height: int, seed: int = -1) -> Dictionary:
	var cells := _create_plain_cells(width, height)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()

	var core_cell: Vector2i = Vector2i(width / 2, height / 2)
	_setup_core_and_initial_fog(cells, core_cell)
	var spawn_cells := _place_spawns(cells, width, height, core_cell, rng)
	_place_starting_resources(cells, core_cell)
	_place_random_obstacles(cells, width, height, spawn_cells, core_cell, rng)
	_place_extra_resources(cells, width, height, spawn_cells, core_cell, rng)

	return {
		"cells": cells,
		"core_cell": core_cell,
		"spawn_cells": spawn_cells
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


static func _place_spawns(cells: Dictionary, width: int, height: int, core_cell: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var candidates := _get_edge_candidates(width, height)
	_shuffle_cells(candidates, rng)
	var spawn_cells: Array[Vector2i] = []
	for candidate in candidates:
		if spawn_cells.size() >= SPAWN_COUNT:
			break
		if _manhattan(candidate, core_cell) < 12:
			continue
		var far_from_existing := true
		for spawn_cell in spawn_cells:
			if _manhattan(candidate, spawn_cell) < 10:
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


static func _place_starting_resources(cells: Dictionary, core_cell: Vector2i) -> void:
	for resource_type in STARTING_RESOURCE_OFFSETS.keys():
		var resource_key := StringName(resource_type)
		var resource_offset: Vector2i = STARTING_RESOURCE_OFFSETS.get(resource_key, Vector2i.ZERO)
		var resource_cell: Vector2i = core_cell + resource_offset
		if not cells.has(resource_cell):
			continue
		var resource_data: CellData = cells[resource_cell]
		_set_resource_node(resource_data, resource_key)


static func _place_extra_resources(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator
) -> void:
	var candidates: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell := Vector2i(x, y)
			if _is_protected_cell(cell, core_cell, spawn_cells):
				continue
			var data: CellData = cells[cell]
			if data == null or not data.walkable or data.resource_type != StringName() or data.spawn_key != StringName():
				continue
			candidates.append(cell)
	_shuffle_cells(candidates, rng)

	var resource_types: Array[StringName] = [&"wood", &"stone", &"mana"]
	var placed_by_type: Dictionary = {}
	for resource_type in resource_types:
		placed_by_type[resource_type] = 0
	for cell in candidates:
		var resource_type: StringName = resource_types[rng.randi_range(0, resource_types.size() - 1)]
		if int(placed_by_type.get(resource_type, 0)) >= EXTRA_RESOURCES_PER_TYPE:
			var all_done := true
			for type_key in resource_types:
				if int(placed_by_type.get(type_key, 0)) < EXTRA_RESOURCES_PER_TYPE:
					all_done = false
					resource_type = type_key
					break
			if all_done:
				break
		_set_resource_node(cells[cell], resource_type)
		placed_by_type[resource_type] = int(placed_by_type.get(resource_type, 0)) + 1


static func _set_resource_node(data: CellData, resource_type: StringName) -> void:
	data.terrain = &"resource"
	data.resource_type = resource_type
	data.buildable = true
	data.walkable = true


static func _place_random_obstacles(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator
) -> void:
	var candidates: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var cell: Vector2i = Vector2i(x, y)
			if _is_protected_cell(cell, core_cell, spawn_cells):
				continue
			var data: CellData = cells[cell]
			if data == null or data.resource_type != StringName() or data.spawn_key != StringName():
				continue
			candidates.append(cell)

	_shuffle_cells(candidates, rng)

	var target_count: int = max(MIN_OBSTACLE_COUNT, int(round(width * height * OBSTACLE_RATIO)))
	target_count = min(target_count, min(MAX_OBSTACLE_COUNT, candidates.size()))
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


static func _is_protected_cell(cell: Vector2i, core_cell: Vector2i, spawn_cells: Array[Vector2i]) -> bool:
	if max(absi(cell.x - core_cell.x), absi(cell.y - core_cell.y)) <= CORE_SAFE_RADIUS:
		return true
	for spawn_cell in spawn_cells:
		if max(absi(cell.x - spawn_cell.x), absi(cell.y - spawn_cell.y)) <= SPAWN_SAFE_RADIUS:
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
