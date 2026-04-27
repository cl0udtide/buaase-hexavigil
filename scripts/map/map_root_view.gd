extends Node2D

const AppRefs = preload("res://scripts/common/app_refs.gd")

const CELL_SIZE := 64.0
const GRID_COLOR := Color(0.12, 0.18, 0.22, 0.85)
const HOVER_COLOR := Color(1.0, 0.9, 0.35, 0.35)
const SELECT_COLOR := Color(0.35, 0.8, 1.0, 0.4)
const ATTACK_RANGE_FILL := Color(0.20, 0.55, 0.95, 0.28)
const ATTACK_RANGE_BORDER := Color(0.30, 0.85, 1.0, 0.95)
const DEPLOY_VALID_FILL := Color(0.18, 0.85, 0.65, 0.38)
const DEPLOY_VALID_BORDER := Color(0.38, 1.0, 0.82, 0.95)
const DEPLOY_INVALID_FILL := Color(1.0, 0.12, 0.10, 0.36)
const DEPLOY_INVALID_BORDER := Color(1.0, 0.32, 0.26, 0.95)
const DEPLOY_LOCKED_FILL := Color(1.0, 0.68, 0.18, 0.32)
const DEPLOY_LOCKED_BORDER := Color(1.0, 0.84, 0.32, 0.95)
const DEPLOY_RANGE_FILL := Color(0.95, 0.65, 0.18, 0.20)
const DEPLOY_RANGE_BORDER := Color(1.0, 0.78, 0.26, 0.82)
const COLOR_HIDDEN := Color(0.10, 0.12, 0.16, 0.95)
const COLOR_PLAIN := Color(0.25, 0.44, 0.26, 1.0)
const COLOR_BLOCKED := Color(0.33, 0.34, 0.38, 1.0)
const COLOR_CORE := Color(0.25, 0.60, 0.95, 1.0)
const COLOR_SPAWN := Color(0.82, 0.30, 0.26, 1.0)
const COLOR_OBSTACLE := Color(0.28, 0.30, 0.34, 1.0)
const COLOR_RESOURCE_WOOD := Color(0.45, 0.31, 0.18, 1.0)
const COLOR_RESOURCE_STONE := Color(0.56, 0.59, 0.64, 1.0)
const COLOR_RESOURCE_MANA := Color(0.16, 0.62, 0.72, 1.0)
const COLOR_EVENT := Color(0.72, 0.48, 0.88, 1.0)
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
var _camera_fit_initialized := false
var _last_map_size := Vector2.ZERO
var _is_dragging := false
var _debug_attack_range_cells: Array[Vector2i] = []
var _deploy_preview_cell := Vector2i(-1, -1)
var _deploy_preview_valid := false
var _deploy_locked_cell := Vector2i(-1, -1)
var _deploy_preview_facing := Vector2i.ZERO
var _deploy_range_preview_cells: Array[Vector2i] = []


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


func refresh_from_map(map_manager: Node, reset_camera: bool = false) -> void:
	_map_manager = map_manager
	var map_size := _get_map_size(map_manager)
	var map_size_changed := not map_size.is_equal_approx(_last_map_size)
	_last_map_size = map_size
	_fit_camera_to_map(reset_camera or map_size_changed or not _camera_fit_initialized)
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
			if _deploy_range_preview_cells.has(cell):
				_draw_deploy_range_cell(rect)
			if _debug_attack_range_cells.has(cell):
				_draw_attack_range_cell(rect)
			if cell == _deploy_preview_cell:
				_draw_deploy_preview_cell(rect, _deploy_preview_valid)
			if cell == _deploy_locked_cell:
				_draw_deploy_locked_cell(rect)
			if cell == _hovered_cell:
				draw_rect(rect.grow(-2.0), HOVER_COLOR)
			if cell == _selected_cell:
				draw_rect(rect.grow(-6.0), SELECT_COLOR)
	if _deploy_locked_cell.x >= 0 and _deploy_preview_facing != Vector2i.ZERO:
		_draw_deploy_direction_arrow(map_manager)


func set_debug_attack_range(cells: Array[Vector2i]) -> void:
	_debug_attack_range_cells = cells.duplicate()
	queue_redraw()


func clear_debug_attack_range() -> void:
	_debug_attack_range_cells.clear()
	queue_redraw()


func set_deploy_preview(cell: Vector2i, is_valid: bool, range_cells: Array[Vector2i] = []) -> void:
	_deploy_preview_cell = cell
	_deploy_preview_valid = is_valid
	_deploy_locked_cell = Vector2i(-1, -1)
	_deploy_preview_facing = Vector2i.ZERO
	_deploy_range_preview_cells = range_cells.duplicate()
	queue_redraw()


func set_deploy_direction_preview(cell: Vector2i, facing: Vector2i, range_cells: Array[Vector2i] = []) -> void:
	_deploy_preview_cell = Vector2i(-1, -1)
	_deploy_locked_cell = cell
	_deploy_preview_facing = _normalize_direction(facing)
	_deploy_range_preview_cells = range_cells.duplicate()
	queue_redraw()


func clear_deploy_preview() -> void:
	_deploy_preview_cell = Vector2i(-1, -1)
	_deploy_preview_valid = false
	_deploy_locked_cell = Vector2i(-1, -1)
	_deploy_preview_facing = Vector2i.ZERO
	_deploy_range_preview_cells.clear()
	queue_redraw()


func _draw_attack_range_cell(rect: Rect2) -> void:
	draw_rect(rect.grow(-4.0), ATTACK_RANGE_FILL)
	draw_rect(rect.grow(-4.0), ATTACK_RANGE_BORDER, false, 2.0)


func _draw_deploy_range_cell(rect: Rect2) -> void:
	draw_rect(rect.grow(-6.0), DEPLOY_RANGE_FILL)
	draw_rect(rect.grow(-6.0), DEPLOY_RANGE_BORDER, false, 1.5)


func _draw_deploy_preview_cell(rect: Rect2, is_valid: bool) -> void:
	draw_rect(rect.grow(-5.0), DEPLOY_VALID_FILL if is_valid else DEPLOY_INVALID_FILL)
	draw_rect(rect.grow(-5.0), DEPLOY_VALID_BORDER if is_valid else DEPLOY_INVALID_BORDER, false, 3.0)


func _draw_deploy_locked_cell(rect: Rect2) -> void:
	draw_rect(rect.grow(-5.0), DEPLOY_LOCKED_FILL)
	draw_rect(rect.grow(-5.0), DEPLOY_LOCKED_BORDER, false, 3.0)


func _normalize_direction(direction: Vector2i) -> Vector2i:
	if direction == Vector2i.ZERO:
		return Vector2i.RIGHT
	if abs(direction.x) >= abs(direction.y):
		return Vector2i.RIGHT if direction.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0 else Vector2i.UP


func _draw_deploy_direction_arrow(map_manager: Node) -> void:
	var start: Vector2 = map_manager.cell_to_world(_deploy_locked_cell)
	var direction := Vector2(_deploy_preview_facing)
	if direction.length_squared() <= 0.0:
		return
	direction = direction.normalized()
	var radius := CELL_SIZE * 1.25
	var tangent := Vector2(-direction.y, direction.x)
	var sector_points := PackedVector2Array([
		start,
		start + (direction + tangent * 0.58).normalized() * radius,
		start + (direction - tangent * 0.58).normalized() * radius
	])
	draw_circle(start, radius, Color(1.0, 0.70, 0.20, 0.11))
	draw_colored_polygon(sector_points, Color(1.0, 0.68, 0.18, 0.22))
	draw_arc(start, radius, 0.0, TAU, 72, Color(1.0, 0.74, 0.28, 0.55), 2.0, true)
	var center_rect := Rect2(start - Vector2.ONE * CELL_SIZE * 0.26, Vector2.ONE * CELL_SIZE * 0.52)
	draw_rect(center_rect, Color(1.0, 0.68, 0.18, 0.30))
	draw_rect(center_rect, DEPLOY_LOCKED_BORDER, false, 3.0)
	draw_line(start + Vector2(-10.0, 0.0), start + Vector2(10.0, 0.0), DEPLOY_LOCKED_BORDER, 3.0, true)
	draw_line(start + Vector2(0.0, -10.0), start + Vector2(0.0, 10.0), DEPLOY_LOCKED_BORDER, 3.0, true)
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for direction_i: Vector2i in directions:
		var arrow_direction := Vector2(direction_i)
		var selected := direction_i == _deploy_preview_facing
		var arrow_color := DEPLOY_LOCKED_BORDER if selected else Color(1.0, 0.82, 0.38, 0.48)
		var line_width := 6.0 if selected else 3.0
		var begin := start + arrow_direction * CELL_SIZE * 0.34
		var end := start + arrow_direction * CELL_SIZE * (0.94 if selected else 0.78)
		draw_line(begin, end, arrow_color, line_width, true)
		_draw_arrow_head(end, arrow_direction, arrow_color, 12.0 if selected else 8.0)


func _draw_arrow_head(tip: Vector2, direction: Vector2, color: Color, size: float) -> void:
	var normalized := direction.normalized()
	var tangent := Vector2(-normalized.y, normalized.x)
	var points := PackedVector2Array([
		tip,
		tip - normalized * size + tangent * size * 0.55,
		tip - normalized * size - tangent * size * 0.55
	])
	draw_colored_polygon(points, color)


func _get_cell_color(data) -> Color:
	if not data.discovered:
		return COLOR_HIDDEN
	if data.is_core:
		return COLOR_CORE
	if data.spawn_key != StringName():
		return COLOR_SPAWN
	if data.terrain == &"obstacle":
		return COLOR_OBSTACLE
	if data.terrain == &"blocked" or not data.walkable:
		return COLOR_BLOCKED
	if data.occupied or data.unit_runtime_id >= 0:
		return COLOR_OCCUPIED
	if data.resource_type == &"wood":
		return COLOR_RESOURCE_WOOD
	if data.resource_type == &"stone":
		return COLOR_RESOURCE_STONE
	if data.resource_type == &"mana":
		return COLOR_RESOURCE_MANA
	if data.event_id != StringName() and not data.event_triggered:
		return COLOR_EVENT
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


func _fit_camera_to_map(reset_view: bool = true) -> void:
	var map_manager := _get_map_manager()
	if map_manager == null or _camera == null:
		return
	var map_size := _get_map_size(map_manager)
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return
	var viewport_size := get_viewport_rect().size - Vector2.ONE * VIEW_PADDING * 2.0
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var previous_fit_zoom := _fit_zoom
	var previous_zoom_scalar := _zoom_scalar
	_fit_zoom = max(viewport_size.x / map_size.x, viewport_size.y / map_size.y)
	_fit_zoom = max(_fit_zoom, 0.01)
	if reset_view:
		_zoom_scalar = _fit_zoom
		_camera.position = _get_map_center(map_manager)
	else:
		var zoom_ratio: float = previous_zoom_scalar / max(previous_fit_zoom, 0.001)
		_zoom_scalar = clamp(_fit_zoom * zoom_ratio, _fit_zoom, _fit_zoom * MAX_ZOOM_MULTIPLIER)
	_apply_camera_zoom()
	_camera.position = _clamp_camera_center(_camera.position)
	_camera_fit_initialized = true


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
	_fit_camera_to_map(false)


func _get_map_manager() -> Node:
	if _map_manager != null:
		return _map_manager
	_map_manager = get_node_or_null("../../Managers/MapManager")
	return _map_manager
