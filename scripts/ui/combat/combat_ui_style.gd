class_name CombatUiStyle
extends RefCounted


const BG := Color(0.055, 0.075, 0.095, 0.88)
const BG_DARK := Color(0.025, 0.035, 0.045, 0.94)
const STROKE := Color(0.34, 0.48, 0.56, 0.65)
const ACCENT := Color(0.12, 0.78, 0.88, 0.95)
const AMBER := Color(1.0, 0.64, 0.18, 0.95)
const DANGER := Color(0.92, 0.18, 0.14, 0.95)
const TEXT := Color(0.90, 0.96, 0.98, 1.0)


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
	return style


static func button(border: Color, fill_alpha: float = 0.18) -> StyleBoxFlat:
	return panel(Color(border.r * 0.22, border.g * 0.22, border.b * 0.22, fill_alpha), border, 1.0, 6.0)
