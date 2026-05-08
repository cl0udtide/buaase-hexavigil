class_name GameUiStyle
extends RefCounted


const BG := Color(0.058, 0.071, 0.084, 0.98)
const BG_DARK := Color(0.034, 0.043, 0.052, 0.99)
const BG_GLASS := Color(0.070, 0.087, 0.100, 0.97)
const BG_CARD := Color(0.092, 0.110, 0.124, 0.98)
const BG_CARD_HOVER := Color(0.118, 0.148, 0.160, 1.0)
const BG_DISABLED := Color(0.048, 0.056, 0.064, 0.97)
const STROKE := Color(0.220, 0.355, 0.400, 0.78)
const STROKE_SOFT := Color(0.145, 0.205, 0.232, 0.76)
const STROKE_STRONG := Color(0.055, 0.690, 0.760, 0.88)
const ACCENT := Color(0.000, 0.760, 0.840, 0.96)
const AMBER := Color(1.000, 0.585, 0.145, 0.96)
const DANGER := Color(0.940, 0.225, 0.170, 0.96)
const SUCCESS := Color(0.265, 0.780, 0.465, 0.96)
const VIOLET := Color(0.620, 0.475, 0.960, 0.96)
const STEEL := Color(0.455, 0.590, 0.650, 0.92)
const TEXT := Color(0.900, 0.945, 0.955, 1.0)
const TEXT_DIM := Color(0.680, 0.755, 0.780, 1.0)
const TEXT_MUTED := Color(0.455, 0.530, 0.560, 1.0)
const TEXT_SHADOW := Color(0.0, 0.0, 0.0, 0.78)

const HOLOGRAM_ROOT := "res://assets/UI/1. Free Hologram Interface Wenrexa"
const HOLOGRAM_BUTTON_NORMAL := HOLOGRAM_ROOT + "/Button 1/Button Normal.png"
const HOLOGRAM_BUTTON_HOVER := HOLOGRAM_ROOT + "/Button 1/Button Hover.png"
const HOLOGRAM_BUTTON_PRESSED := HOLOGRAM_ROOT + "/Button 1/Button Active.png"
const HOLOGRAM_BUTTON_DISABLED := HOLOGRAM_ROOT + "/Button 1/Button Disable.png"
const HOLOGRAM_CARD := HOLOGRAM_ROOT + "/Card X1/Card X1.png"
const HOLOGRAM_CARD_WIDE := HOLOGRAM_ROOT + "/Card X1/Card X2.png"
const HOLOGRAM_PANEL_EMPTY := HOLOGRAM_ROOT + "/Card X1/Panel Empty.png"
const HOLOGRAM_PANEL_GREEN := HOLOGRAM_ROOT + "/Card X1/Panel Empty Green.png"
const HOLOGRAM_PANEL_RED := HOLOGRAM_ROOT + "/Card X1/Panel Red.png"

const MIKO_ROOT := "res://assets/UI/Wenrexa Assets GUI Dark Miko"
const MIKO_PANEL_GRAY := MIKO_ROOT + "/Panels Gray/Panel 10.png"
const MIKO_PANEL_GREEN := MIKO_ROOT + "/Panels Green/Panel 10.png"
const MIKO_BUTTON_NORMAL := MIKO_ROOT + "/Standart Button V1/Standart Button Normal/Standart Button Normal 1.png"
const MIKO_BUTTON_HOVER := MIKO_ROOT + "/Standart Button V1/Standart Button Hover/Standart Button Hover 1.png"
const MIKO_BUTTON_PRESSED := MIKO_ROOT + "/Standart Button V1/Standart Button Active/Standart Button Active 1.png"
const MIKO_BUTTON_DISABLED := MIKO_ROOT + "/Standart Button V1/Standart Button Disable/Standart Button Disable 1.png"
const MIKO_PROGRESS_BLUE_BG := MIKO_ROOT + "/ProgressBar Blue/V4/Background Static.png"
const MIKO_PROGRESS_BLUE_FILL := MIKO_ROOT + "/ProgressBar Blue/V4/Foreground.png"
const MIKO_PROGRESS_GREEN_FILL := MIKO_ROOT + "/ProgressBar Green/V4/Foreground.png"
const MIKO_PROGRESS_RED_FILL := MIKO_ROOT + "/ProgressBar Red/V4/Foreground.png"


static func texture_box(path: String, fallback_fill: Color, fallback_border: Color, margin: float = 16.0) -> StyleBox:
	var texture := load(path) as Texture2D
	if texture == null:
		return panel(fallback_fill, fallback_border, 1.0, 6.0)

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin(SIDE_LEFT, margin)
	style.set_texture_margin(SIDE_TOP, margin)
	style.set_texture_margin(SIDE_RIGHT, margin)
	style.set_texture_margin(SIDE_BOTTOM, margin)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style


static func hologram_texture_box(path: String, fallback_fill: Color, fallback_border: Color, margin: float = 22.0) -> StyleBox:
	var style := texture_box(path, fallback_fill, fallback_border, margin)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


static func panel(fill: Color, border: Color, border_width: float = 1.0, radius: float = 6.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = int(border_width)
	style.border_width_top = int(border_width)
	style.border_width_right = int(border_width)
	style.border_width_bottom = int(border_width)
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0.0, 5.0)
	return style


static func flat_box(fill: Color, border: Color, border_width: float = 1.0, radius: float = 6.0) -> StyleBoxFlat:
	var style := panel(fill, border, border_width, radius)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.shadow_color = Color.TRANSPARENT
	return style


static func button(border: Color, fill_alpha: float = 0.18) -> StyleBox:
	if border == AMBER:
		return hologram_texture_box(HOLOGRAM_BUTTON_PRESSED, Color(border.r * 0.16, border.g * 0.16, border.b * 0.16, fill_alpha), border, 18.0)
	if border == STROKE_SOFT:
		return hologram_texture_box(HOLOGRAM_BUTTON_NORMAL, Color(border.r * 0.16, border.g * 0.16, border.b * 0.16, fill_alpha), border, 18.0)
	return hologram_texture_box(HOLOGRAM_BUTTON_HOVER, Color(border.r * 0.16, border.g * 0.16, border.b * 0.16, fill_alpha), border, 18.0)


static func card(border: Color, fill: Color = BG_CARD, border_width: float = 1.0) -> StyleBox:
	var style := hologram_texture_box(HOLOGRAM_CARD, fill, AMBER, 24.0)
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	return style


static func top_card() -> StyleBox:
	var style := card(STROKE_SOFT, BG_GLASS, 1.0)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style


static func accent_button(accent: Color) -> StyleBox:
	if accent == AMBER:
		return hologram_texture_box(HOLOGRAM_BUTTON_PRESSED, Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 0.34), accent, 18.0)
	return hologram_texture_box(HOLOGRAM_BUTTON_HOVER, Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 0.34), accent, 18.0)


static func disabled_button() -> StyleBox:
	return hologram_texture_box(HOLOGRAM_BUTTON_DISABLED, BG_DISABLED, STROKE_SOFT, 18.0)


static func miko_button(state: StringName = &"normal") -> StyleBox:
	var path := MIKO_BUTTON_NORMAL
	if state == &"hover":
		path = MIKO_BUTTON_HOVER
	elif state == &"pressed":
		path = MIKO_BUTTON_PRESSED
	elif state == &"disabled":
		path = MIKO_BUTTON_DISABLED
	return texture_box(path, BG_CARD, STROKE_SOFT, 12.0)


static func miko_panel(highlighted: bool = false) -> StyleBox:
	var path := MIKO_PANEL_GREEN if highlighted else MIKO_PANEL_GRAY
	return texture_box(path, BG_CARD, SUCCESS if highlighted else STROKE_SOFT, 18.0)


static func progress_background() -> StyleBox:
	return texture_box(MIKO_PROGRESS_BLUE_BG, Color(0.0, 0.0, 0.0, 0.42), Color(0.18, 0.23, 0.26, 0.9), 8.0)


static func progress_fill(color: Color) -> StyleBox:
	var path := MIKO_PROGRESS_BLUE_FILL
	if color.r > color.b and color.r > color.g:
		path = MIKO_PROGRESS_RED_FILL
	elif color.g > color.b:
		path = MIKO_PROGRESS_GREEN_FILL
	return texture_box(path, color, color, 8.0)
