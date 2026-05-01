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
const TEXT := Color(0.900, 0.945, 0.955, 1.0)
const TEXT_DIM := Color(0.680, 0.755, 0.780, 1.0)
const TEXT_MUTED := Color(0.455, 0.530, 0.560, 1.0)
const TEXT_SHADOW := Color(0.0, 0.0, 0.0, 0.78)


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


static func button(border: Color, fill_alpha: float = 0.18) -> StyleBoxFlat:
	return panel(Color(border.r * 0.20, border.g * 0.20, border.b * 0.20, fill_alpha), border, 1.0, 6.0)


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
	return panel(Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.42), accent, 1.0, 6.0)


static func progress_background() -> StyleBoxFlat:
	return panel(Color(0.020, 0.027, 0.032, 0.72), Color(0.160, 0.220, 0.250, 0.90), 1.0, 3.0)


static func progress_fill(color: Color) -> StyleBoxFlat:
	return panel(color, color, 0.0, 3.0)
