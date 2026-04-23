extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")


@onready var _map_manager: Node = get_node_or_null("../MapManager")

var _blocked_cells: Dictionary = {}


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.path_grid_changed.connect(_on_path_grid_changed)


func rebuild_from_map() -> void:
	_blocked_cells.clear()
	if _map_manager == null:
		return
	for cell in _map_manager._cells.keys():
		if not _map_manager.is_walkable(cell):
			_blocked_cells[cell] = true


func find_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if _blocked_cells.get(end_cell, false):
		return []
	var path: Array[Vector2i] = []
	var current := start_cell
	path.append(current)
	while current != end_cell:
		if current.x < end_cell.x:
			current.x += 1
		elif current.x > end_cell.x:
			current.x -= 1
		elif current.y < end_cell.y:
			current.y += 1
		elif current.y > end_cell.y:
			current.y -= 1
		if _blocked_cells.get(current, false):
			return []
		path.append(current)
	return path


func has_path(start_cell: Vector2i, end_cell: Vector2i) -> bool:
	return not find_path(start_cell, end_cell).is_empty()


func set_cell_blocked(cell: Vector2i, blocked: bool) -> void:
	if blocked:
		_blocked_cells[cell] = true
	else:
		_blocked_cells.erase(cell)


func _on_path_grid_changed() -> void:
	rebuild_from_map()
