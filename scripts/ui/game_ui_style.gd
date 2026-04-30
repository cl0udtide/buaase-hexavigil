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


static func button(border: Color, fill_alpha: float = 0.18) -> StyleBoxFlat:
	return panel(Color(border.r * 0.22, border.g * 0.22, border.b * 0.22, fill_alpha), border, 1.0, 6.0)


static func card(border: Color, fill: Color = BG_CARD, border_width: float = 1.0) -> StyleBoxFlat:
	var style := panel(fill, border, border_width, 6.0)
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	return style


static func top_card() -> StyleBoxFlat:
	var style := card(STROKE_SOFT, BG_GLASS, 1.0)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style


static func accent_button(accent: Color) -> StyleBoxFlat:
	return panel(Color(accent.r * 0.24, accent.g * 0.24, accent.b * 0.24, 0.34), accent, 1.0, 6.0)


static func progress_background() -> StyleBoxFlat:
	return panel(Color(0.0, 0.0, 0.0, 0.42), Color(0.18, 0.23, 0.26, 0.9), 1.0, 3.0)


static func progress_fill(color: Color) -> StyleBoxFlat:
	return panel(color, color, 0.0, 3.0)
