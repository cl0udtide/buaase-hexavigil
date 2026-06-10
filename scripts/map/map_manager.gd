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
@onready var _random_event_manager: Node = get_node_or_null("../RandomEventManager")


func generate_new_map(seed: int) -> void:
	var data_repo = AppRefs.data_repo()
	var cfg: Dictionary = data_repo.get_map_generation_cfg() if data_repo != null and data_repo.has_method("get_map_generation_cfg") else {}
	width = int(cfg.get("width", width))
	height = int(cfg.get("height", height))
	var event_ids: Array[StringName] = data_repo.get_all_event_ids() if data_repo != null and data_repo.has_method("get_all_event_ids") else []
	var generated: Dictionary = MapGenerator.generate(width, height, seed, cfg, event_ids)
	_cells = generated.get("cells", {})
	_spawn_cells.clear()
	for cell_variant: Variant in generated.get("spawn_cells", []):
		_spawn_cells.append(cell_variant as Vector2i)
	_core_cell = generated.get("core_cell", Vector2i.ZERO)
	_setup_event_overlay(generated.get("event_points", []))
	refresh_all_layers(true)
	_emit_path_grid_changed()


func generate_debug_map(new_width: int, new_height: int, core_cell: Vector2i, spawn_defs: Dictionary, blocked_cells: Array = []) -> void:
	width = max(1, new_width)
	height = max(1, new_height)
	_cells.clear()
	_spawn_cells.clear()
	for y in range(height):
		for x in range(width):
			var data := CellData.new()
			data.cell = Vector2i(x, y)
			data.discovered = true
			data.set_base_terrain(CellData.TERRAIN_PLAIN)
			_cells[data.cell] = data
	_core_cell = Vector2i(clamp(core_cell.x, 0, width - 1), clamp(core_cell.y, 0, height - 1))
	if _cells.has(_core_cell):
		var core_data: CellData = _cells[_core_cell]
		core_data.is_core = true
		core_data.buildable = false
	_apply_debug_spawns(spawn_defs)
	_apply_debug_blocked_cells(blocked_cells)
	_clear_event_overlay()
	refresh_all_layers(true)
	_emit_path_grid_changed()


func set_debug_spawns(spawn_defs: Dictionary) -> void:
	_apply_debug_spawns(spawn_defs)
	refresh_all_layers()
	_emit_path_grid_changed()


func upsert_debug_spawn(spawn_key: StringName, cell: Vector2i) -> bool:
	if not is_inside(cell):
		return false
	var target_data := get_cell_data(cell)
	if target_data == null or target_data.is_core or target_data.occupied or target_data.unit_runtime_id >= 0 or target_data.building_runtime_id >= 0:
		return false
	if target_data.spawn_key != StringName() and target_data.spawn_key != spawn_key:
		return false
	_clear_debug_spawn(spawn_key)
	target_data.set_base_terrain(CellData.TERRAIN_PLAIN)
	target_data.spawn_key = spawn_key
	target_data.buildable = false
	if not _spawn_cells.has(cell):
		_spawn_cells.append(cell)
	refresh_all_layers()
	_emit_path_grid_changed()
	return true


func remove_debug_spawn(spawn_key: StringName) -> bool:
	var removed := _clear_debug_spawn(spawn_key)
	if removed:
		refresh_all_layers()
		_emit_path_grid_changed()
	return removed


func get_debug_spawn_defs() -> Dictionary:
	var result := {}
	for cell in _spawn_cells:
		var data := get_cell_data(cell)
		if data != null and data.spawn_key != StringName():
			result[String(data.spawn_key)] = cell
	return result


func set_debug_cell_blocked(cell: Vector2i, blocked: bool) -> bool:
	if not is_inside(cell):
		return false
	var data := get_cell_data(cell)
	if data == null:
		return false
	if data.is_core or data.spawn_key != StringName():
		return false
	if data.occupied or data.unit_runtime_id >= 0 or data.building_runtime_id >= 0:
		return false
	if blocked:
		data.set_base_terrain(CellData.TERRAIN_MOUNTAIN)
	else:
		data.set_base_terrain(CellData.TERRAIN_PLAIN)
	refresh_all_layers()
	_emit_path_grid_changed()
	return true


func clear_debug_blocked_cells() -> void:
	for raw_cell in _cells.keys():
		var cell: Vector2i = raw_cell
		var data := get_cell_data(cell)
		if data == null or data.terrain != CellData.TERRAIN_MOUNTAIN:
			continue
		data.set_base_terrain(CellData.TERRAIN_PLAIN)
		data.buildable = not data.is_core and data.spawn_key == StringName()
	refresh_all_layers()
	_emit_path_grid_changed()


func set_debug_core(cell: Vector2i) -> bool:
	if not is_inside(cell):
		return false
	var target := get_cell_data(cell)
	if target == null:
		return false
	if target.spawn_key != StringName():
		return false
	if target.occupied or target.unit_runtime_id >= 0 or target.building_runtime_id >= 0:
		return false
	var old_core := get_cell_data(_core_cell)
	if old_core != null:
		old_core.is_core = false
		old_core.buildable = old_core.spawn_key == StringName() and not old_core.is_terrain_blocking()
	target.set_base_terrain(CellData.TERRAIN_PLAIN)
	target.is_core = true
	target.buildable = false
	_core_cell = cell
	refresh_all_layers()
	_emit_path_grid_changed()
	return true


func get_debug_map_state() -> Dictionary:
	var mountain_cells: Array = []
	for raw_cell in _cells.keys():
		var cell: Vector2i = raw_cell
		var data := get_cell_data(cell)
		if data == null:
			continue
		if data.is_core or data.spawn_key != StringName():
			continue
		if data.terrain == CellData.TERRAIN_MOUNTAIN:
			mountain_cells.append([cell.x, cell.y])
	mountain_cells.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[1]) == int(b[1]):
			return int(a[0]) < int(b[0])
		return int(a[1]) < int(b[1])
	)
	return {
		"width": width,
		"height": height,
		"core": [_core_cell.x, _core_cell.y],
		"mountain": mountain_cells,
	}


func serialize_debug_map_state() -> Dictionary:
	return get_debug_map_state()


func apply_debug_map_state(map_state: Dictionary, spawn_defs: Dictionary = {}) -> void:
	var new_width := int(map_state.get("width", width))
	var new_height := int(map_state.get("height", height))
	var raw_core: Variant = map_state.get("core", [_core_cell.x, _core_cell.y])
	var core_cell := _parse_debug_cell(raw_core, _core_cell)
	var blocked_cells: Array = []
	var raw_blocked: Variant = map_state.get("mountain", map_state.get("blocked", []))
	if typeof(raw_blocked) == TYPE_ARRAY:
		blocked_cells = raw_blocked
	generate_debug_map(new_width, new_height, core_cell, spawn_defs, blocked_cells)


func set_debug_map_size(new_width: int, new_height: int) -> void:
	var spawn_defs := {}
	for cell in _spawn_cells:
		var data := get_cell_data(cell)
		if data != null and data.spawn_key != StringName():
			spawn_defs[data.spawn_key] = Vector2i(clamp(cell.x, 0, max(1, new_width) - 1), clamp(cell.y, 0, max(1, new_height) - 1))
	var state := get_debug_map_state()
	state["width"] = new_width
	state["height"] = new_height
	state["core"] = [
		clamp(_core_cell.x, 0, max(1, new_width) - 1),
		clamp(_core_cell.y, 0, max(1, new_height) - 1)
	]
	apply_debug_map_state(state, spawn_defs)


func reset_map() -> void:
	_cells.clear()
	_spawn_cells.clear()
	_core_cell = Vector2i.ZERO
	_clear_event_overlay()
	refresh_all_layers(true)
	_emit_path_grid_changed()


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height


func get_cell_data(cell: Vector2i) -> CellData:
	return _cells.get(cell)


func get_all_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_variant in _cells.keys():
		result.append(cell_variant as Vector2i)
	return result


func is_discovered(cell: Vector2i) -> bool:
	var data := get_cell_data(cell)
	return data != null and data.discovered


func has_discovered_neighbor(cell: Vector2i) -> bool:
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if is_discovered(cell + offset):
			return true
	return false


func get_event_id_at_cell(cell: Vector2i) -> StringName:
	if _random_event_manager == null or not _random_event_manager.has_method("get_event_id_at_cell"):
		return StringName()
	return _random_event_manager.get_event_id_at_cell(cell)


func mark_event_triggered(cell: Vector2i) -> void:
	if _random_event_manager != null and _random_event_manager.has_method("mark_event_triggered"):
		_random_event_manager.mark_event_triggered(cell)


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


func clear_runtime_occupancy() -> void:
	for data in _cells.values():
		data.occupied = false
		data.building_runtime_id = -1
		data.unit_runtime_id = -1
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


func get_spawn_keys() -> Array[String]:
	var keys: Array[String] = []
	for cell in _spawn_cells:
		var data := get_cell_data(cell)
		if data != null and data.spawn_key != StringName():
			keys.append(String(data.spawn_key))
	keys.sort()
	return keys


func get_spawn_key_at_cell(cell: Vector2i) -> StringName:
	var data := get_cell_data(cell)
	if data == null:
		return StringName()
	return data.spawn_key


func has_spawn_key(spawn_key: StringName) -> bool:
	for cell in _spawn_cells:
		var data := get_cell_data(cell)
		if data != null and data.spawn_key == spawn_key:
			return true
	return false


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


func refresh_all_layers(reset_camera: bool = false) -> void:
	if _map_root != null and _map_root.has_method("refresh_from_map"):
		_map_root.refresh_from_map(self, reset_camera)
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
		(child as Node2D).visible = is_discovered(spawn_cell)


func _apply_debug_spawns(spawn_defs: Dictionary) -> void:
	for cell in _spawn_cells:
		var old_data := get_cell_data(cell)
		if old_data != null:
			old_data.spawn_key = StringName()
			old_data.buildable = not old_data.is_core and not old_data.is_terrain_blocking()
	_spawn_cells.clear()
	for raw_key in spawn_defs.keys():
		var spawn_key := StringName(raw_key)
		var spawn_cell: Vector2i = spawn_defs[raw_key]
		if not _cells.has(spawn_cell):
			continue
		var spawn_data: CellData = _cells[spawn_cell]
		if spawn_data.is_core or spawn_data.occupied or spawn_data.unit_runtime_id >= 0 or spawn_data.building_runtime_id >= 0:
			continue
		spawn_data.set_base_terrain(CellData.TERRAIN_PLAIN)
		spawn_data.spawn_key = spawn_key
		spawn_data.buildable = false
		if not _spawn_cells.has(spawn_cell):
			_spawn_cells.append(spawn_cell)


func _apply_debug_blocked_cells(blocked_cells: Array) -> void:
	for raw_cell in blocked_cells:
		var cell := _parse_debug_cell(raw_cell, Vector2i(-1, -1))
		if not is_inside(cell):
			continue
		var data := get_cell_data(cell)
		if data == null:
			continue
		if data.is_core or data.spawn_key != StringName():
			continue
		if data.occupied or data.unit_runtime_id >= 0 or data.building_runtime_id >= 0:
			continue
		data.set_base_terrain(CellData.TERRAIN_MOUNTAIN)


func _parse_debug_cell(raw_cell: Variant, fallback: Vector2i) -> Vector2i:
	if raw_cell is Vector2i:
		return raw_cell
	if raw_cell is Array and raw_cell.size() >= 2:
		return Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	if raw_cell is Dictionary:
		return Vector2i(int(raw_cell.get("x", fallback.x)), int(raw_cell.get("y", fallback.y)))
	return fallback


func _setup_event_overlay(event_points: Array) -> void:
	if _random_event_manager != null and _random_event_manager.has_method("setup_events"):
		_random_event_manager.setup_events(event_points)


func _clear_event_overlay() -> void:
	if _random_event_manager != null and _random_event_manager.has_method("clear_events"):
		_random_event_manager.clear_events()


func _clear_debug_spawn(spawn_key: StringName) -> bool:
	for cell in _spawn_cells.duplicate():
		var data := get_cell_data(cell)
		if data != null and data.spawn_key == spawn_key:
			data.spawn_key = StringName()
			data.buildable = not data.is_core and not data.is_terrain_blocking()
			_spawn_cells.erase(cell)
			return true
	return false


func _emit_path_grid_changed() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.path_grid_changed.emit()
