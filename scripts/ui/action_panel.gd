extends PanelContainer

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

var _current_mode: StringName = &"idle"
var _current_building_id: StringName = &""
var _current_phase := GameEnums.PHASE_MENU

@onready var _mode_label: Label = %ModeLabel
@onready var _idle_button: Button = %IdleButton
@onready var _explore_button: Button = %ExploreButton
@onready var _start_night_button: Button = %StartNightButton


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	_bind_buttons()
	_bind_events()
	var run_state = AppRefs.run_state()
	if run_state != null:
		_current_phase = int(run_state.phase)
	_refresh_state()


func set_mode_idle() -> void:
	_current_mode = &"idle"
	_current_building_id = &""
	_refresh_state()


func set_mode_explore() -> void:
	_current_mode = &"explore"
	_current_building_id = &""
	_refresh_state()


func set_mode_build(building_id: StringName) -> void:
	_current_mode = &"build"
	_current_building_id = building_id
	_refresh_state()


func clear_mode() -> void:
	set_mode_idle()


func get_current_mode() -> StringName:
	return _current_mode


func get_current_building_id() -> StringName:
	return _current_building_id


func _bind_buttons() -> void:
	_idle_button.pressed.connect(set_mode_idle)
	_explore_button.pressed.connect(set_mode_explore)
	_start_night_button.pressed.connect(_on_start_night_pressed)


func _bind_events() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	event_bus.map_cell_clicked.connect(_on_map_cell_clicked)
	event_bus.phase_changed.connect(_on_phase_changed)


func _on_map_cell_clicked(cell: Vector2i) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null or int(run_state.phase) != GameEnums.PHASE_DAY:
		return
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	if _current_mode == &"idle" and _try_toggle_idle_building(cell):
		return
	if _current_mode == &"explore":
		event_bus.request_explore.emit(cell)
	elif _current_mode == &"build" and _current_building_id != StringName():
		event_bus.request_build.emit(cell, _current_building_id)


func _try_toggle_idle_building(cell: Vector2i) -> bool:
	var building_manager := get_node_or_null("../../Managers/BuildingManager")
	if building_manager == null or not building_manager.has_method("get_building_by_cell"):
		return false
	var existing_building: Node = building_manager.get_building_by_cell(cell)
	if existing_building == null or not is_instance_valid(existing_building):
		return false
	if StringName(existing_building.get("building_id")) != &"war_shrine":
		return false
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_toggle_building.emit(int(existing_building.get_runtime_id()))
	return true


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	_current_phase = new_phase
	if new_phase != GameEnums.PHASE_DAY:
		set_mode_idle()
	else:
		_refresh_state()


func _on_start_night_pressed() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_start_night.emit()


func _refresh_state() -> void:
	_refresh_mode_label()
	var day_phase := _current_phase == GameEnums.PHASE_DAY
	_idle_button.disabled = not day_phase or _current_mode == &"idle"
	_explore_button.disabled = not day_phase or _current_mode == &"explore"
	_start_night_button.disabled = not day_phase
	_style_action_button(_idle_button, _current_mode == &"idle")
	_style_action_button(_explore_button, _current_mode == &"explore")
	_style_action_button(_start_night_button, false)


func _refresh_mode_label() -> void:
	if _mode_label == null:
		return
	if _current_phase != GameEnums.PHASE_DAY:
		_mode_label.text = "待机"
		return
	match _current_mode:
		&"explore":
			_mode_label.text = "探索"
		&"build":
			_mode_label.text = "建造"
		_:
			_mode_label.text = "待机"


func _apply_visual_style() -> void:
	add_theme_stylebox_override("panel", GameUiStyle.panel(GameUiStyle.BG_DARK, GameUiStyle.STROKE_SOFT, 1.0, 6.0))
	var content_margin := get_node_or_null("ContentMargin") as MarginContainer
	if content_margin != null:
		content_margin.add_theme_constant_override("margin_left", 8)
		content_margin.add_theme_constant_override("margin_top", 6)
		content_margin.add_theme_constant_override("margin_right", 8)
		content_margin.add_theme_constant_override("margin_bottom", 6)
	if _mode_label != null:
		_mode_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	for button in [_idle_button, _explore_button, _start_night_button]:
		if button != null:
			button.custom_minimum_size = Vector2(58.0, 28.0)


func _style_action_button(button: Button, selected: bool) -> void:
	if button == null:
		return
	var accent := GameUiStyle.ACCENT if selected else GameUiStyle.STROKE_SOFT
	button.add_theme_stylebox_override("normal", GameUiStyle.button(accent, 0.18))
	button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT, 0.26))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.32))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.10))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)
