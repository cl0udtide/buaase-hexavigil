class_name MapGenerator
extends RefCounted

const STARTING_RESOURCE_OFFSETS := {
	&"wood": Vector2i(-2, -2),
	&"stone": Vector2i(2, -2),
	&"mana": Vector2i(-2, 2)
}
const STARTING_OBSTACLE_OFFSET := Vector2i(2, 2)

static func generate(width: int, height: int) -> Dictionary:
	var cells: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var data := CellData.new()
			data.cell = Vector2i(x, y)
			data.buildable = true
			data.walkable = true
			data.discovered = false
			cells[data.cell] = data

	var core_cell := Vector2i(width / 2, height / 2)
	var core_data: CellData = cells[core_cell]
	core_data.is_core = true
	core_data.terrain = &"core"
	core_data.buildable = false
	for y in range(core_cell.y - 2, core_cell.y + 3):
		for x in range(core_cell.x - 2, core_cell.x + 3):
			var reveal_cell := Vector2i(x, y)
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
