class_name MapGenerator
extends RefCounted

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP
]
const OBSTACLE_RATIO := 0.0
const MIN_OBSTACLE_COUNT := 0
const MAX_OBSTACLE_COUNT := 0
const CORE_SAFE_RADIUS := 3
const SPAWN_SAFE_RADIUS := 1

const STARTING_RESOURCE_OFFSETS := {
	&"wood": Vector2i(-2, -2),
	&"stone": Vector2i(2, -2),
	&"mana": Vector2i(-2, 2)
}
const STARTING_OBSTACLE_OFFSET := Vector2i(2, 2)

static func generate(width: int, height: int, seed: int = -1) -> Dictionary:
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

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()

	var core_cell: Vector2i = Vector2i(width / 2, height / 2)
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

	var spawn_cells: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(width - 1, 0),
		Vector2i(0, height - 1)
	]
	for index in range(spawn_cells.size()):
		var spawn_cell: Vector2i = spawn_cells[index]
		if cells.has(spawn_cell):
			var spawn_data: CellData = cells[spawn_cell]
			spawn_data.spawn_key = StringName("S%d" % (index + 1))
			spawn_data.terrain = &"spawn"
			spawn_data.discovered = true
			spawn_data.buildable = false

	_place_starting_resources(cells, core_cell)
	_place_starting_obstacle(cells, core_cell)
	_place_random_obstacles(cells, width, height, spawn_cells, core_cell, rng)

	return {
		"cells": cells,
		"core_cell": core_cell,
		"spawn_cells": spawn_cells
	}


static func _place_starting_resources(cells: Dictionary, core_cell: Vector2i) -> void:
	for resource_type in STARTING_RESOURCE_OFFSETS.keys():
		var resource_key := StringName(resource_type)
		var resource_offset: Vector2i = STARTING_RESOURCE_OFFSETS.get(resource_key, Vector2i.ZERO)
		var resource_cell: Vector2i = core_cell + resource_offset
		if not cells.has(resource_cell):
			continue
		var resource_data: CellData = cells[resource_cell]
		_set_resource_node(resource_data, resource_key)


static func _place_starting_obstacle(cells: Dictionary, core_cell: Vector2i) -> void:
	var obstacle_cell: Vector2i = core_cell + STARTING_OBSTACLE_OFFSET
	if not cells.has(obstacle_cell):
		return
	var obstacle_data: CellData = cells[obstacle_cell]
	obstacle_data.terrain = &"obstacle"
	obstacle_data.resource_type = &""
	obstacle_data.buildable = false
	obstacle_data.walkable = false


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
