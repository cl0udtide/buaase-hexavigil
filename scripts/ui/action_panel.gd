extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")


var _current_mode: StringName = &"idle"
var _current_building_id: StringName = &""


func _ready() -> void:
	AppTheme.apply(self)
	var idle_button := get_node_or_null("%IdleButton") as BaseButton
	var explore_button := get_node_or_null("%ExploreButton") as BaseButton
	var night_button := get_node_or_null("%StartNightButton") as BaseButton
	if idle_button != null:
		idle_button.pressed.connect(set_mode_idle)
	if explore_button != null:
		explore_button.pressed.connect(set_mode_explore)
	if night_button != null:
		night_button.pressed.connect(func() -> void:
			var event_bus = AppRefs.event_bus()
			if event_bus != null:
				event_bus.request_start_night.emit()
		)


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
