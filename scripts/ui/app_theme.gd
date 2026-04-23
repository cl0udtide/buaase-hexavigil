class_name AppTheme
extends RefCounted


const FONT_PATH := "res://assets/fonts/SourceHanSansSC-Normal.otf"

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
	for type_name in ["Label", "Button", "LineEdit", "TextEdit", "RichTextLabel", "CheckBox", "OptionButton"]:
		theme.set_font("font", type_name, font)
		theme.set_font_size("font_size", type_name, 20)

	_theme = theme
	return _theme


static func apply(control: Control) -> void:
	if control != null:
		control.theme = get_theme()
