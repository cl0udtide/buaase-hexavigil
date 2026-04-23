extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")


var _current_mode: StringName = &"idle"
var _current_building_id: StringName = &""
var _current_unit_id: StringName = &""


func _ready() -> void:
	AppTheme.apply(self)
	var event_bus = AppRefs.event_bus()
	var idle_button := get_node_or_null("%IdleButton") as BaseButton
	var explore_button := get_node_or_null("%ExploreButton") as BaseButton
	var night_button := get_node_or_null("%StartNightButton") as BaseButton
	if idle_button != null:
		idle_button.pressed.connect(set_mode_idle)
	if explore_button != null:
		explore_button.pressed.connect(set_mode_explore)
	if night_button != null:
		night_button.pressed.connect(func() -> void:
			if event_bus != null:
				event_bus.request_start_night.emit()
		)
	if event_bus != null:
		event_bus.map_cell_clicked.connect(_on_map_cell_clicked)
		event_bus.phase_changed.connect(_on_phase_changed)
	_refresh_mode_labels()


func set_mode_idle() -> void:
	_current_mode = &"idle"
	_current_building_id = &""
	_current_unit_id = &""
	_refresh_mode_labels()


func set_mode_explore() -> void:
	_current_mode = &"explore"
	_current_building_id = &""
	_current_unit_id = &""
	_refresh_mode_labels()


func set_mode_build(building_id: StringName) -> void:
	_current_mode = &"build"
	_current_building_id = building_id
	_current_unit_id = &""
	_refresh_mode_labels()


func set_mode_deploy(unit_id: StringName) -> void:
	_current_mode = &"deploy"
	_current_building_id = &""
	_current_unit_id = unit_id
	_refresh_mode_labels()


func clear_mode() -> void:
	set_mode_idle()


func get_current_mode() -> StringName:
	return _current_mode


func get_current_building_id() -> StringName:
	return _current_building_id


func get_current_unit_id() -> StringName:
	return _current_unit_id


func _on_map_cell_clicked(cell: Vector2i) -> void:
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if run_state == null or run_state.phase != GameEnums.PHASE_DAY or event_bus == null:
		return
	match _current_mode:
		&"explore":
			event_bus.request_explore.emit(cell)
		&"build":
			if _current_building_id != StringName():
				event_bus.request_build.emit(cell, _current_building_id)
		&"deploy":
			if _current_unit_id != StringName():
				event_bus.request_deploy.emit(_current_unit_id, cell, Vector2i.RIGHT)


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	if new_phase != GameEnums.PHASE_DAY:
		set_mode_idle()


func _refresh_mode_labels() -> void:
	var mode_label := get_node_or_null("%ModeLabel") as Label
	var selection_label := get_node_or_null("%SelectionLabel") as Label
	if mode_label != null:
		mode_label.text = "Mode: %s" % String(_current_mode)
	if selection_label == null:
		return
	match _current_mode:
		&"build":
			selection_label.text = "Selected: %s" % String(_current_building_id)
		&"deploy":
			selection_label.text = "Selected: %s" % String(_current_unit_id)
		_:
			selection_label.text = "Selected: none"
