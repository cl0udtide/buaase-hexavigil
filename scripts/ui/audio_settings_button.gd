extends Button

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")

signal settings_button_pressed

@export var panel_path: NodePath
@export var auto_toggle_panel := true

var _panel: Control


func _ready() -> void:
	AppTheme.apply(self)
	_panel = get_node_or_null(panel_path) as Control
	pressed.connect(_on_pressed)
	_apply_visual_style()


func _on_pressed() -> void:
	settings_button_pressed.emit()
	if not auto_toggle_panel:
		return
	if _panel == null:
		return
	if _panel.has_method("toggle_panel"):
		_panel.toggle_panel()
	else:
		_panel.visible = not _panel.visible
		if _panel.visible and _panel.has_method("refresh_from_audio_manager"):
			_panel.refresh_from_audio_manager()


func _apply_visual_style() -> void:
	set_custom_minimum_size(Vector2(42.0, 40.0) if text.strip_edges().length() <= 2 else Vector2(94.0, 36.0))
	tooltip_text = "设置"
	var gear_texture := UiArtRegistry.get_catalog_icon(&"button_settings")
	GameUiStyle.set_button_texture_icon(self, gear_texture, Vector2(20.0, 20.0), &"center")
	var gear_label := get_node_or_null("GearIcon") as Label
	if gear_label != null:
		gear_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if gear_texture != null:
			gear_label.visible = false
	GameUiStyle.center_button_text(self)
	add_theme_stylebox_override("normal", GameUiStyle.settings_button())
	add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT, 0.28))
	add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.32))
	add_theme_stylebox_override("disabled", GameUiStyle.disabled_button())
	add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
