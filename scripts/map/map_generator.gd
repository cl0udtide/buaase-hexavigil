class_name MapGenerator
extends RefCounted


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
			spawn_data.discovered = true

	return {
		"cells": cells,
		"core_cell": core_cell,
		"spawn_cells": spawn_cells
	}
