extends Button

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

@export var panel_path: NodePath

var _panel: Control


func _ready() -> void:
	AppTheme.apply(self)
	_panel = get_node_or_null(panel_path) as Control
	pressed.connect(_on_pressed)
	_apply_visual_style()


func _on_pressed() -> void:
	if _panel == null:
		return
	_panel.visible = not _panel.visible
	if _panel.visible and _panel.has_method("refresh_from_audio_manager"):
		_panel.refresh_from_audio_manager()


func _apply_visual_style() -> void:
	add_theme_stylebox_override("normal", GameUiStyle.button(GameUiStyle.ACCENT, 0.18))
	add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT, 0.28))
	add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.32))
	add_theme_color_override("font_color", GameUiStyle.TEXT)
