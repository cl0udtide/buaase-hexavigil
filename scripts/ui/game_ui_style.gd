class_name GameUiStyle
extends RefCounted


const BG := Color(0.055, 0.075, 0.095, 0.88)
const BG_DARK := Color(0.025, 0.035, 0.045, 0.94)
const BG_GLASS := Color(0.035, 0.045, 0.052, 0.82)
const BG_CARD := Color(0.065, 0.080, 0.088, 0.92)
const BG_CARD_HOVER := Color(0.085, 0.105, 0.112, 0.96)
const BG_DISABLED := Color(0.030, 0.034, 0.038, 0.82)
const STROKE := Color(0.34, 0.48, 0.56, 0.65)
const STROKE_SOFT := Color(0.25, 0.32, 0.36, 0.58)
const STROKE_STRONG := Color(0.52, 0.72, 0.82, 0.82)
const ACCENT := Color(0.12, 0.78, 0.88, 0.95)
const AMBER := Color(1.0, 0.64, 0.18, 0.95)
const DANGER := Color(0.92, 0.18, 0.14, 0.95)
const SUCCESS := Color(0.30, 0.88, 0.56, 0.95)
const TEXT := Color(0.90, 0.96, 0.98, 1.0)
const TEXT_DIM := Color(0.72, 0.80, 0.84, 1.0)
const TEXT_MUTED := Color(0.58, 0.66, 0.70, 1.0)

const UI_ROOT := "res://assets/UI/Wenrexa Assets GUI Dark Miko"
const PANEL_GRAY := UI_ROOT + "/Panels Gray/Panel 10.png"
const PANEL_GRAY_DARK := UI_ROOT + "/Panels Gray/Panel 12.png"
const PANEL_GREEN := UI_ROOT + "/Panels Green/Panel 10.png"
const PANEL_GREEN_DARK := UI_ROOT + "/Panels Green/Panel 12.png"
const BUTTON_NORMAL := UI_ROOT + "/Standart Button V2/Standart Button Normal/Standart Button Normal 1.png"
const BUTTON_HOVER := UI_ROOT + "/Standart Button V2/Standart Button Hover/Standart Button Hover 1.png"
const BUTTON_PRESSED := UI_ROOT + "/Standart Button V2/Standart Button Active/Standart Button Active 1.png"
const BUTTON_DISABLED := UI_ROOT + "/Standart Button V2/Standart Button Disable/Standart Button Disable 1.png"
const BIG_BUTTON_NORMAL := UI_ROOT + "/Custom Big Buttons/Custom Buttons Normal/Custom Button Normal 1.png"
const BIG_BUTTON_HOVER := UI_ROOT + "/Custom Big Buttons/Custom Buttons Hover/Custom Button Hover 1.png"
const BIG_BUTTON_PRESSED := UI_ROOT + "/Custom Big Buttons/Custom Buttons Active/Custom Button Active 1.png"
const BIG_BUTTON_DISABLED := UI_ROOT + "/Custom Big Buttons/Custom Buttons Disable/Custom Button Disable 1.png"
const PROGRESS_BLUE_BG := UI_ROOT + "/ProgressBar Blue/V4/Background Static.png"
const PROGRESS_BLUE_FILL := UI_ROOT + "/ProgressBar Blue/V4/Foreground.png"
const PROGRESS_GREEN_FILL := UI_ROOT + "/ProgressBar Green/V4/Foreground.png"
const PROGRESS_RED_FILL := UI_ROOT + "/ProgressBar Red/V4/Foreground.png"


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
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


static func button(border: Color, fill_alpha: float = 0.18) -> StyleBox:
	if border == AMBER:
		return texture_box(BUTTON_PRESSED, Color(border.r * 0.22, border.g * 0.22, border.b * 0.22, fill_alpha), border, 12.0)
	if border == ACCENT or border == SUCCESS:
		return texture_box(BUTTON_HOVER, Color(border.r * 0.22, border.g * 0.22, border.b * 0.22, fill_alpha), border, 12.0)
	return texture_box(BUTTON_NORMAL, Color(border.r * 0.22, border.g * 0.22, border.b * 0.22, fill_alpha), border, 12.0)


static func card(border: Color, fill: Color = BG_CARD, border_width: float = 1.0) -> StyleBox:
	var path := PANEL_GRAY
	if border == ACCENT or border == SUCCESS:
		path = PANEL_GREEN
	elif border == AMBER:
		path = PANEL_GREEN_DARK
	var style := texture_box(path, fill, border, 18.0)
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
	var path := BIG_BUTTON_NORMAL
	if accent == AMBER:
		path = BIG_BUTTON_PRESSED
	elif accent == ACCENT or accent == SUCCESS:
		path = BIG_BUTTON_HOVER
	return texture_box(path, Color(accent.r * 0.24, accent.g * 0.24, accent.b * 0.24, 0.34), accent, 18.0)


static func disabled_button() -> StyleBox:
	return texture_box(BUTTON_DISABLED, BG_DISABLED, STROKE_SOFT, 12.0)


static func progress_background() -> StyleBox:
	return texture_box(PROGRESS_BLUE_BG, Color(0.0, 0.0, 0.0, 0.42), Color(0.18, 0.23, 0.26, 0.9), 8.0)


static func progress_fill(color: Color) -> StyleBox:
	var path := PROGRESS_BLUE_FILL
	if color.r > color.b and color.r > color.g:
		path = PROGRESS_RED_FILL
	elif color.g > color.b:
		path = PROGRESS_GREEN_FILL
	return texture_box(path, color, color, 8.0)
