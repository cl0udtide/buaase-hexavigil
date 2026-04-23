extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")


func _ready() -> void:
	AppTheme.apply(self)
	_bind_button("%BuildMedicalButton", &"medical_station")
	_bind_button("%BuildWallButton", &"wood_wall")


func _bind_button(path: String, building_id: StringName) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button != null:
		button.pressed.connect(_on_build_button_pressed.bind(building_id))


func _on_build_button_pressed(building_id: StringName) -> void:
	var action_panel := get_node_or_null("../ActionPanel")
	if action_panel != null and action_panel.has_method("set_mode_build"):
		action_panel.set_mode_build(building_id)
