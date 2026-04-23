extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")


const CELL_SIZE := 64.0

var width := 30
var height := 30
var _cells: Dictionary = {}
var _spawn_cells: Array[Vector2i] = []
var _core_cell := Vector2i.ZERO

@onready var _map_root: Node = get_node_or_null("../../World/MapRoot")
@onready var _spawn_root: Node = get_node_or_null("../../World/SpawnRoot")
@onready var _core_root: Node = get_node_or_null("../../World/CoreRoot")


func generate_new_map(_seed: int) -> void:
	var generated: Dictionary = MapGenerator.generate(width, height)
	_cells = generated.get("cells", {})
	_spawn_cells.clear()
	for cell_variant: Variant in generated.get("spawn_cells", []):
		_spawn_cells.append(cell_variant as Vector2i)
	_core_cell = generated.get("core_cell", Vector2i.ZERO)
	refresh_all_layers()


func reset_map() -> void:
	_cells.clear()
	_spawn_cells.clear()
	_core_cell = Vector2i.ZERO
	refresh_all_layers()


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height


func get_cell_data(cell: Vector2i) -> CellData:
	return _cells.get(cell)


func is_discovered(cell: Vector2i) -> bool:
	var data := get_cell_data(cell)
	return data != null and data.discovered


func reveal_area(center: Vector2i, radius: int) -> Array[Vector2i]:
	var revealed: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if not is_inside(cell):
				continue
			var data := get_cell_data(cell)
			if data == null or data.discovered:
				continue
			data.discovered = true
			revealed.append(cell)
	if not revealed.is_empty():
		var event_bus = AppRefs.event_bus()
		if event_bus != null:
			event_bus.fog_revealed.emit(revealed)
		refresh_all_layers()
	return revealed


func is_walkable(cell: Vector2i) -> bool:
	var data := get_cell_data(cell)
	return data != null and data.walkable and not data.occupied and data.unit_runtime_id < 0


func is_buildable(cell: Vector2i) -> bool:
	var data := get_cell_data(cell)
	return data != null and data.buildable and data.discovered and not data.occupied and data.unit_runtime_id < 0 and not data.is_core


func has_building(cell: Vector2i) -> bool:
	var data := get_cell_data(cell)
	return data != null and data.occupied


func has_unit(cell: Vector2i) -> bool:
	var data := get_cell_data(cell)
	return data != null and data.unit_runtime_id >= 0


func set_building_occupy(cell: Vector2i, occupied: bool, building_runtime_id: int = -1) -> void:
	var data := get_cell_data(cell)
	if data == null:
		return
	data.occupied = occupied
	data.building_runtime_id = building_runtime_id if occupied else -1
	refresh_all_layers()


func set_unit_occupy(cell: Vector2i, occupied: bool, unit_runtime_id: int = -1) -> void:
	var data := get_cell_data(cell)
	if data == null:
		return
	data.unit_runtime_id = unit_runtime_id if occupied else -1
	refresh_all_layers()


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / CELL_SIZE), floor(world_pos.y / CELL_SIZE))


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * CELL_SIZE, (cell.y + 0.5) * CELL_SIZE)


func get_spawn_cells() -> Array[Vector2i]:
	return _spawn_cells.duplicate()


func get_spawn_cell_by_key(spawn_key: StringName) -> Vector2i:
	for cell in _spawn_cells:
		var data := get_cell_data(cell)
		if data != null and data.spawn_key == spawn_key:
			return cell
	return Vector2i.ZERO


func get_core_cell() -> Vector2i:
	return _core_cell


func get_random_discovered_empty_cell() -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell in _cells.keys():
		var data: CellData = _cells[cell]
		if data.discovered and not data.occupied and data.unit_runtime_id < 0 and not data.is_core:
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i.ZERO
	return candidates.pick_random()


func refresh_all_layers() -> void:
	if _map_root != null and _map_root.has_method("refresh_from_map"):
		_map_root.refresh_from_map(self)
	_refresh_world_markers()


func _refresh_world_markers() -> void:
	if _core_root != null:
		for child in _core_root.get_children():
			if child is Node2D:
				(child as Node2D).global_position = cell_to_world(_core_cell)
	if _spawn_root == null:
		return
	for child in _spawn_root.get_children():
		if not (child is Node2D):
			continue
		var spawn_key: StringName = child.get("spawn_key") if child.get("spawn_key") != null else StringName()
		var spawn_cell := get_spawn_cell_by_key(spawn_key)
		(child as Node2D).global_position = cell_to_world(spawn_cell)
