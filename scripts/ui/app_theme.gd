class_name AppTheme
extends RefCounted

const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const FONT_PATH := "res://assets/fonts/SourceHanSansSC-Normal.otf"

const SIZE_BODY := 18
const SIZE_BUTTON := 17
const SIZE_LABEL := 18
const SIZE_SMALL := 14

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme

	var font := load(FONT_PATH) as FontFile
	if font == null:
		push_warning("Missing UI font: %s" % FONT_PATH)
		_theme = Theme.new()
		return _theme

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = SIZE_BODY
	for type_name in ["LineEdit", "TextEdit", "RichTextLabel", "OptionButton"]:
		theme.set_font("font", type_name, font)
		theme.set_font_size("font_size", type_name, SIZE_BODY)
	for type_name in ["Label", "CheckBox"]:
		theme.set_font("font", type_name, font)
		theme.set_font_size("font_size", type_name, SIZE_LABEL)
	theme.set_font("font", "Button", font)
	theme.set_font_size("font_size", "Button", SIZE_BUTTON)
	theme.set_color("font_color", "Label", GameUiStyle.TEXT)
	theme.set_color("font_shadow_color", "Label", GameUiStyle.TEXT_SHADOW)
	theme.set_color("font_color", "Button", GameUiStyle.TEXT)
	theme.set_color("font_hover_color", "Button", GameUiStyle.TEXT)
	theme.set_color("font_pressed_color", "Button", GameUiStyle.TEXT)
	theme.set_color("font_disabled_color", "Button", GameUiStyle.TEXT_MUTED)
	theme.set_stylebox("panel", "PanelContainer", GameUiStyle.card(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_DARK, 1.0))
	theme.set_stylebox("normal", "Button", GameUiStyle.button(GameUiStyle.STROKE_SOFT))
	theme.set_stylebox("hover", "Button", GameUiStyle.button(GameUiStyle.ACCENT))
	theme.set_stylebox("pressed", "Button", GameUiStyle.button(GameUiStyle.AMBER))
	theme.set_stylebox("disabled", "Button", GameUiStyle.disabled_button())
	theme.set_constant("h_separation", "Button", 6)
	theme.set_constant("outline_size", "Label", 1)
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_outline_color", "Label", Color(0.0, 0.0, 0.0, 0.55))
	theme.set_font_size("font_size", "TooltipLabel", SIZE_SMALL)

	_theme = theme
	return _theme


static func apply(control: Control) -> void:
	if control != null:
		control.theme = get_theme()
