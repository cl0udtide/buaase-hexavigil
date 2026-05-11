extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")

var _current_mode: StringName = &"idle"
var _current_building_id: StringName = &""
var _current_phase := GameEnums.PHASE_MENU

@onready var _start_night_button: Button = %StartNightButton


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
	event_bus.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	_current_phase = new_phase
	_refresh_state()


func _on_start_night_pressed() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_start_night.emit()


func _refresh_state() -> void:
	var day_phase := _current_phase == GameEnums.PHASE_DAY
	visible = day_phase
	_start_night_button.disabled = not day_phase
