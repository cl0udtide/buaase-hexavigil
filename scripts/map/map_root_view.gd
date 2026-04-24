extends Node2D

const AppRefs = preload("res://scripts/common/app_refs.gd")

const CELL_SIZE := 64.0
const GRID_COLOR := Color(0.12, 0.18, 0.22, 0.85)
const HOVER_COLOR := Color(1.0, 0.9, 0.35, 0.35)
const SELECT_COLOR := Color(0.35, 0.8, 1.0, 0.4)
const ATTACK_RANGE_FILL := Color(0.20, 0.55, 0.95, 0.28)
const ATTACK_RANGE_BORDER := Color(0.30, 0.85, 1.0, 0.95)
const COLOR_HIDDEN := Color(0.10, 0.12, 0.16, 0.95)
const COLOR_PLAIN := Color(0.25, 0.44, 0.26, 1.0)
const COLOR_CORE := Color(0.25, 0.60, 0.95, 1.0)
const COLOR_SPAWN := Color(0.82, 0.30, 0.26, 1.0)
const COLOR_OBSTACLE := Color(0.28, 0.30, 0.34, 1.0)
const COLOR_RESOURCE_WOOD := Color(0.45, 0.31, 0.18, 1.0)
const COLOR_RESOURCE_STONE := Color(0.56, 0.59, 0.64, 1.0)
const COLOR_RESOURCE_MANA := Color(0.16, 0.62, 0.72, 1.0)
const COLOR_OCCUPIED := Color(0.60, 0.45, 0.22, 1.0)
const VIEW_PADDING := 0.0
const MAX_ZOOM_MULTIPLIER := 3.0
const ZOOM_STEP := 0.9
const PAN_OVERSCROLL_VIEWPORT_RATIO := 0.75

var _map_manager: Node
var _hovered_cell := Vector2i(-1, -1)
var _selected_cell := Vector2i(-1, -1)
var _camera: Camera2D
var _fit_zoom := 1.0
var _zoom_scalar := 1.0
var _is_dragging := false
var _debug_attack_range_cells: Array[Vector2i] = []


func _ready() -> void:
	set_process(true)
	_camera = get_node_or_null("MapCamera") as Camera2D
	if _camera == null:
		_camera = Camera2D.new()
		_camera.name = "MapCamera"
		_camera.position_smoothing_enabled = false
		_camera.enabled = true
		add_child(_camera)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	call_deferred("_fit_camera_to_map")


func _process(_delta: float) -> void:
	var map_manager := _get_map_manager()
	if map_manager == null:
		return
	var hovered: Vector2i = map_manager.world_to_cell(get_global_mouse_position())
	if map_manager.is_inside(hovered) and hovered != _hovered_cell:
		_hovered_cell = hovered
		queue_redraw()
	elif not map_manager.is_inside(hovered) and _hovered_cell != Vector2i(-1, -1):
		_hovered_cell = Vector2i(-1, -1)
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var map_manager := _get_map_manager()
	if map_manager == null or _camera == null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event, map_manager)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func refresh_from_map(map_manager: Node) -> void:
	_map_manager = map_manager
	_fit_camera_to_map()
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
			if _debug_attack_range_cells.has(cell):
				_draw_attack_range_cell(rect)
			if cell == _hovered_cell:
				draw_rect(rect.grow(-2.0), HOVER_COLOR)
			if cell == _selected_cell:
				draw_rect(rect.grow(-6.0), SELECT_COLOR)


func set_debug_attack_range(cells: Array[Vector2i]) -> void:
	_debug_attack_range_cells = cells.duplicate()
	queue_redraw()


func clear_debug_attack_range() -> void:
	_debug_attack_range_cells.clear()
	queue_redraw()


func _draw_attack_range_cell(rect: Rect2) -> void:
	# 调试场景只需要清晰标识攻击范围，避免斜线纹路干扰格子阅读。
	draw_rect(rect.grow(-4.0), ATTACK_RANGE_FILL)
	draw_rect(rect.grow(-4.0), ATTACK_RANGE_BORDER, false, 2.0)


func _get_cell_color(data) -> Color:
	if not data.discovered:
		return COLOR_HIDDEN
	if data.is_core:
		return COLOR_CORE
	if data.spawn_key != StringName():
		return COLOR_SPAWN
	if data.terrain == &"obstacle":
		return COLOR_OBSTACLE
	if data.occupied or data.unit_runtime_id >= 0:
		return COLOR_OCCUPIED
	if data.resource_type == &"wood":
		return COLOR_RESOURCE_WOOD
	if data.resource_type == &"stone":
		return COLOR_RESOURCE_STONE
	if data.resource_type == &"mana":
		return COLOR_RESOURCE_MANA
	return COLOR_PLAIN


func _handle_mouse_button(event: InputEventMouseButton, map_manager: Node) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_at_mouse(1.0 / ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_at_mouse(ZOOM_STEP)
		MOUSE_BUTTON_RIGHT:
			_is_dragging = event.pressed
		MOUSE_BUTTON_LEFT:
			if event.pressed and not _is_dragging:
				var cell: Vector2i = map_manager.world_to_cell(get_global_mouse_position())
				if not map_manager.is_inside(cell):
					return
				_selected_cell = cell
				queue_redraw()
				var event_bus = AppRefs.event_bus()
				if event_bus != null:
					event_bus.map_cell_clicked.emit(cell)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _is_dragging or _camera == null:
		return
	_camera.position -= event.relative / max(_zoom_scalar, 0.001)
	_camera.position = _clamp_camera_center(_camera.position)


func _zoom_at_mouse(factor: float) -> void:
	if _camera == null:
		return
	var before_world := get_global_mouse_position()
	var min_zoom := _fit_zoom
	var max_zoom := _fit_zoom * MAX_ZOOM_MULTIPLIER
	_zoom_scalar = clamp(_zoom_scalar * factor, min_zoom, max_zoom)
	_apply_camera_zoom()
	var after_world := get_global_mouse_position()
	_camera.position += before_world - after_world
	_camera.position = _clamp_camera_center(_camera.position)


func _fit_camera_to_map() -> void:
	var map_manager := _get_map_manager()
	if map_manager == null or _camera == null:
		return
	var map_size := _get_map_size(map_manager)
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return
	var viewport_size := get_viewport_rect().size - Vector2.ONE * VIEW_PADDING * 2.0
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	# Use "cover" scaling so the map always fills the viewport.
	_fit_zoom = max(viewport_size.x / map_size.x, viewport_size.y / map_size.y)
	_fit_zoom = max(_fit_zoom, 0.01)
	_zoom_scalar = _fit_zoom
	_apply_camera_zoom()
	_camera.position = _get_map_center(map_manager)
	_camera.position = _clamp_camera_center(_camera.position)


func _apply_camera_zoom() -> void:
	if _camera != null:
		_camera.zoom = Vector2.ONE * _zoom_scalar


func _clamp_camera_center(desired_center: Vector2) -> Vector2:
	var map_manager := _get_map_manager()
	if map_manager == null:
		return desired_center
	var map_rect := Rect2(Vector2.ZERO, _get_map_size(map_manager))
	var visible_size: Vector2 = get_viewport_rect().size / max(_zoom_scalar, 0.001)
	var overscroll := visible_size * PAN_OVERSCROLL_VIEWPORT_RATIO
	var clamped := desired_center
	clamped.x = clamp(clamped.x, map_rect.position.x + visible_size.x * 0.5 - overscroll.x, map_rect.end.x - visible_size.x * 0.5 + overscroll.x)
	clamped.y = clamp(clamped.y, map_rect.position.y + visible_size.y * 0.5 - overscroll.y, map_rect.end.y - visible_size.y * 0.5 + overscroll.y)
	return clamped


func _get_map_size(map_manager: Node) -> Vector2:
	return Vector2(map_manager.width, map_manager.height) * CELL_SIZE


func _get_map_center(map_manager: Node) -> Vector2:
	return _get_map_size(map_manager) * 0.5


func get_debug_info() -> String:
	var map_manager := _get_map_manager()
	if map_manager == null:
		return "Map not ready"
	var effective_cell_size: float = CELL_SIZE * _zoom_scalar
	var text := "Map %dx%d  Core=%s  Cell~%.1fpx" % [
		map_manager.width,
		map_manager.height,
		map_manager.get_core_cell(),
		effective_cell_size
	]
	if _hovered_cell.x >= 0:
		text += "  Hover=%s" % _hovered_cell
	if _selected_cell.x >= 0:
		text += "  Selected=%s" % _selected_cell
	return text


func _on_viewport_size_changed() -> void:
	_fit_camera_to_map()


func _get_map_manager() -> Node:
	if _map_manager != null:
		return _map_manager
	_map_manager = get_node_or_null("../../Managers/MapManager")
	return _map_manager
