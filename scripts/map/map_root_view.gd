extends Node2D

const AppRefs = preload("res://scripts/common/app_refs.gd")

const CELL_SIZE := 64.0
const GRID_COLOR := Color(0.12, 0.18, 0.22, 0.85)
const HOVER_COLOR := Color(1.0, 0.9, 0.35, 0.35)
const SELECT_COLOR := Color(0.35, 0.8, 1.0, 0.4)
const COLOR_HIDDEN := Color(0.10, 0.12, 0.16, 0.95)
const COLOR_PLAIN := Color(0.25, 0.44, 0.26, 1.0)
const COLOR_CORE := Color(0.25, 0.60, 0.95, 1.0)
const COLOR_SPAWN := Color(0.82, 0.30, 0.26, 1.0)
const COLOR_OCCUPIED := Color(0.60, 0.45, 0.22, 1.0)

var _map_manager: Node
var _hovered_cell := Vector2i(-1, -1)
var _selected_cell := Vector2i(-1, -1)


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	var map_manager := _get_map_manager()
	if map_manager == null:
		return
	var hovered: Vector2i = map_manager.world_to_cell(get_global_mouse_position())
	if map_manager.is_inside(hovered) and hovered != _hovered_cell:
		_hovered_cell = hovered
		_update_info_label()
		queue_redraw()
	elif not map_manager.is_inside(hovered) and _hovered_cell != Vector2i(-1, -1):
		_hovered_cell = Vector2i(-1, -1)
		_update_info_label()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var map_manager := _get_map_manager()
	if map_manager == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell: Vector2i = map_manager.world_to_cell(get_global_mouse_position())
		if not map_manager.is_inside(cell):
			return
		_selected_cell = cell
		_update_info_label()
		queue_redraw()
		var event_bus = AppRefs.event_bus()
		if event_bus != null:
			event_bus.map_cell_clicked.emit(cell)


func refresh_from_map(map_manager: Node) -> void:
	_map_manager = map_manager
	_update_info_label()
	queue_redraw()


func _draw() -> void:
	var map_manager := _get_map_manager()
	if map_manager == null:
		return
	for y in range(map_manager.height):
		for x in range(map_manager.width):
			var cell := Vector2i(x, y)
			var data = map_manager.get_cell_data(cell)
			if data == null:
				continue
			var rect := Rect2(Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			draw_rect(rect, _get_cell_color(data))
			draw_rect(rect, GRID_COLOR, false, 1.0)
			if cell == _hovered_cell:
				draw_rect(rect.grow(-2.0), HOVER_COLOR)
			if cell == _selected_cell:
				draw_rect(rect.grow(-6.0), SELECT_COLOR)


func _get_cell_color(data) -> Color:
	if not data.discovered:
		return COLOR_HIDDEN
	if data.is_core:
		return COLOR_CORE
	if data.spawn_key != StringName():
		return COLOR_SPAWN
	if data.occupied or data.unit_runtime_id >= 0:
		return COLOR_OCCUPIED
	return COLOR_PLAIN


func _update_info_label() -> void:
	var label := get_node_or_null("%InfoLabel") as Label
	if label == null:
		return
	var map_manager := _get_map_manager()
	if map_manager == null:
		label.text = "Map not ready"
		return
	var text := "Map %dx%d  Core=%s" % [map_manager.width, map_manager.height, map_manager.get_core_cell()]
	if _hovered_cell.x >= 0:
		text += "  Hover=%s" % _hovered_cell
	if _selected_cell.x >= 0:
		text += "  Selected=%s" % _selected_cell
	label.text = text


func _get_map_manager() -> Node:
	if _map_manager != null:
		return _map_manager
	_map_manager = get_node_or_null("../../Managers/MapManager")
	return _map_manager
