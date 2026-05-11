extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")

const EXPLORE_AP_COST := 2

var _current_mode: StringName = &"idle"
var _current_building_id: StringName = &""
var _current_phase := GameEnums.PHASE_MENU

@onready var _start_night_button: Button = %StartNightButton
@onready var _map_root: Node = _resolve_node(["../../World/MapRoot", "../../../../World/MapRoot"])
@onready var _map_manager: Node = _resolve_node(["../../Managers/MapManager", "../../../../Managers/MapManager"])


func _resolve_node(paths: Array) -> Node:
	for path in paths:
		var node := get_node_or_null(String(path))
		if node != null:
			return node
	return null


func _ready() -> void:
	AppTheme.apply(self)
	_bind_buttons()
	_bind_events()
	var run_state = AppRefs.run_state()
	if run_state != null:
		_current_phase = int(run_state.phase)
	_refresh_state()


func set_mode_idle() -> void:
	_current_mode = &"idle"
	_current_building_id = &""


func set_mode_explore() -> void:
	_current_mode = &"explore"
	_current_building_id = &""


func set_mode_build(building_id: StringName) -> void:
	_current_mode = &"build"
	_current_building_id = building_id


func clear_mode() -> void:
	set_mode_idle()


func get_current_mode() -> StringName:
	return _current_mode


func get_current_building_id() -> StringName:
	return _current_building_id


func _bind_buttons() -> void:
	_start_night_button.pressed.connect(_on_start_night_pressed)


func _bind_events() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	event_bus.map_cell_clicked.connect(_on_map_cell_clicked)
	event_bus.map_cell_hovered.connect(_on_map_cell_hovered)
	event_bus.phase_changed.connect(_on_phase_changed)
	event_bus.action_points_changed.connect(_on_action_points_changed)
	event_bus.fog_revealed.connect(_on_fog_revealed)


func _on_map_cell_clicked(cell: Vector2i) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null or int(run_state.phase) != GameEnums.PHASE_DAY:
		return
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	if _current_mode == &"explore":
		event_bus.request_explore.emit(cell)
		return
	if _current_mode == &"build" and _current_building_id != StringName():
		event_bus.request_build.emit(cell, _current_building_id)
		return
	if _can_auto_explore_cell(cell):
		event_bus.request_explore.emit(cell)


func _can_auto_explore_cell(cell: Vector2i) -> bool:
	if _map_manager == null:
		return false
	if not _map_manager.is_inside(cell) or _map_manager.is_discovered(cell):
		return false
	if not _map_manager.has_method("has_discovered_neighbor"):
		return false
	return bool(_map_manager.has_discovered_neighbor(cell))


func _has_enough_ap_to_explore() -> bool:
	var run_state = AppRefs.run_state()
	return run_state != null and int(run_state.action_points) >= EXPLORE_AP_COST


func _on_map_cell_hovered(cell: Vector2i) -> void:
	if _map_root == null or not _map_root.has_method("set_fog_hover_active"):
		return
	if _current_phase != GameEnums.PHASE_DAY:
		_map_root.set_fog_hover_active(false)
		return
	if _current_mode != &"idle":
		_map_root.set_fog_hover_active(false)
		return
	var active := _can_auto_explore_cell(cell) and _has_enough_ap_to_explore()
	_map_root.set_fog_hover_active(active)


func _refresh_fog_hover_from_cursor() -> void:
	if _map_root == null or _map_manager == null:
		return
	var cell: Vector2i = _map_manager.world_to_cell(_map_root.get_global_mouse_position())
	if not _map_manager.is_inside(cell):
		cell = Vector2i(-1, -1)
	_on_map_cell_hovered(cell)


func _on_action_points_changed(_value: int) -> void:
	_refresh_fog_hover_from_cursor()


func _on_fog_revealed(_cells: Array) -> void:
	_refresh_fog_hover_from_cursor()


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	_current_phase = new_phase
	if new_phase != GameEnums.PHASE_DAY:
		if _map_root != null and _map_root.has_method("set_fog_hover_active"):
			_map_root.set_fog_hover_active(false)
	else:
		_refresh_fog_hover_from_cursor()
	_refresh_state()


func _on_start_night_pressed() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_start_night.emit()


func _refresh_state() -> void:
	var day_phase := _current_phase == GameEnums.PHASE_DAY
	visible = day_phase
	_start_night_button.disabled = not day_phase
