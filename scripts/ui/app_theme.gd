class_name AppTheme
extends RefCounted

const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const FONT_CN := preload("res://assets/fonts/SourceHanSansSC-Normal.otf")

const SIZE_BODY := 16
const SIZE_BUTTON := 16
const SIZE_LABEL := 16
const SIZE_SMALL := 14

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme

	var theme := Theme.new()

	theme.set_default_font(FONT_CN)
	theme.set_default_font_size(SIZE_BODY)

	for type_name in ["LineEdit", "TextEdit", "RichTextLabel", "OptionButton"]:
		theme.set_font_size("font_size", type_name, SIZE_BODY)
	for type_name in ["Label", "CheckBox"]:
		theme.set_font_size("font_size", type_name, SIZE_LABEL)

	theme.set_font_size("font_size", "Button", SIZE_BUTTON)

	theme.set_color("font_color", "Label", GameUiStyle.TEXT)
	theme.set_color("font_shadow_color", "Label", GameUiStyle.TEXT_SHADOW)
	theme.set_color("font_color", "Button", GameUiStyle.TEXT_INVERTED)
	theme.set_color("font_hover_color", "Button", GameUiStyle.TEXT_INVERTED)
	theme.set_color("font_pressed_color", "Button", GameUiStyle.TEXT_INVERTED)
	theme.set_color("font_disabled_color", "Button", GameUiStyle.TEXT_MUTED)
	theme.set_color("font_color", "CheckBox", GameUiStyle.TEXT_DIM)

	theme.set_stylebox("panel", "PanelContainer", GameUiStyle.card(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_CARD, 1.0))
	theme.set_stylebox("normal", "Button", GameUiStyle.button(GameUiStyle.STROKE_SOFT))
	theme.set_stylebox("hover", "Button", GameUiStyle.button(GameUiStyle.ACCENT))
	theme.set_stylebox("pressed", "Button", GameUiStyle.button(GameUiStyle.AMBER))
	theme.set_stylebox("disabled", "Button", GameUiStyle.disabled_button())

	theme.set_constant("h_separation", "Button", 6)
	theme.set_constant("outline_size", "Label", 0)
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 0)
	theme.set_color("font_outline_color", "Label", Color.TRANSPARENT)

	theme.set_font_size("font_size", "TooltipLabel", SIZE_SMALL)
	theme.set_stylebox("panel", "TooltipPanel", GameUiStyle.tooltip())

	_theme = theme
	return _theme


static func apply(control: Control) -> void:
	if control != null:
		control.theme = get_theme()
