class_name UiLayoutRules
extends RefCounted

const UiTokens = preload("res://scripts/ui/ui_tokens.gd")


static func hud_profile(viewport_size: Vector2, detail_visible: bool, left_reserved_width: float = 0.0) -> Dictionary:
	var width: float = maxf(viewport_size.x, 1.0)
	var height: float = maxf(viewport_size.y, 1.0)
	var compact: bool = UiTokens.is_compact(width)
	var narrow: bool = UiTokens.is_narrow(width)
	var edge: float = UiTokens.edge_for_width(width)
	var detail_width: float = _detail_width_for_width(width)
	var detail_min_height: float = _detail_min_height_for_width(width)
	var left_panel_width: float = _left_panel_width_for_width(width)
	var top_height: float = UiTokens.TOP_BAR_HEIGHT_COMPACT if compact else UiTokens.TOP_BAR_HEIGHT
	var settings_size: float = UiTokens.SETTINGS_BUTTON_SIZE_COMPACT if compact else UiTokens.SETTINGS_BUTTON_SIZE
	var relic_height := UiTokens.RELIC_STRIP_HEIGHT_COMPACT if compact else UiTokens.RELIC_STRIP_HEIGHT
	var content_top := UiTokens.TOP_BAR_Y + top_height + UiTokens.SPACE_XS + relic_height + UiTokens.SPACE_LG
	var deck_height: float = UiTokens.DEPLOY_DECK_HEIGHT_COMPACT if compact else UiTokens.DEPLOY_DECK_HEIGHT
	var detail_left: float = width - edge - detail_width
	var deck_y := height - edge - deck_height
	var legend_size := _legend_size_for_width(width)
	var wave_height := _wave_preview_height_for_width(width)
	var right_bottom_limit := deck_y - UiTokens.SPACE_SM
	var legend_visible := detail_visible
	var legend_y := right_bottom_limit - legend_size.y
	var min_right_height_with_legend := wave_height + UiTokens.SPACE_LG + detail_min_height + UiTokens.SPACE_SM + legend_size.y
	if right_bottom_limit - content_top < min_right_height_with_legend:
		legend_visible = false
	var legend_rect := Rect2(width - edge - legend_size.x, legend_y, legend_size.x, legend_size.y)
	if not legend_visible:
		legend_rect = Rect2(width - edge, right_bottom_limit, 0.0, 0.0)
	var detail_bottom := legend_rect.position.y - UiTokens.SPACE_SM if legend_visible else right_bottom_limit
	var right_column_rect := Rect2(detail_left, content_top, detail_width, maxf(detail_min_height, detail_bottom - content_top))
	var detail_rect := right_column_rect
	var action_size := _action_panel_size_for_width(width)
	var action_rect := Rect2(edge, height - edge - action_size.y, action_size.x, action_size.y)
	var left_panel_bottom := action_rect.position.y - UiTokens.SPACE_LG
	var left_panel_rect := Rect2(edge, content_top, left_panel_width, maxf(UiTokens.LEFT_PANEL_MIN_HEIGHT, left_panel_bottom - content_top))
	var deck_left: float = maxf(edge, left_reserved_width + UiTokens.SPACE_LG)
	var deck_right_x: float = width - edge
	if detail_visible:
		deck_right_x = detail_left - UiTokens.SPACE_LG
	if deck_right_x - deck_left < UiTokens.DEPLOY_DECK_MIN_WIDTH:
		deck_left = edge
		if detail_visible and width < UiTokens.BREAKPOINT_COMPACT:
			detail_left = width - edge - detail_width
			deck_right_x = detail_left - UiTokens.SPACE_SM
		if deck_right_x - deck_left < UiTokens.DEPLOY_DECK_MIN_WIDTH:
			detail_width = minf(detail_width, maxf(280.0, width * 0.28))
			detail_left = width - edge - detail_width
			deck_right_x = detail_left - UiTokens.SPACE_SM if detail_visible else width - edge
	var top_left := edge + settings_size + UiTokens.SPACE_SM
	var top_rect := Rect2(top_left, UiTokens.TOP_BAR_Y, maxf(0.0, width - top_left - edge), top_height)
	var relic_left: float = maxf(top_left, left_reserved_width + UiTokens.SPACE_LG)
	var relic_right_limit: float = detail_left - UiTokens.SPACE_SM if detail_visible else width - edge
	if relic_right_limit - relic_left < UiTokens.RELIC_STRIP_MIN_WIDTH:
		relic_left = top_left
		relic_right_limit = width - edge
	var relic_width: float = clampf(relic_right_limit - relic_left, 0.0, UiTokens.RELIC_STRIP_MAX_WIDTH)
	var relic_rect := Rect2(relic_left, UiTokens.TOP_BAR_Y + top_height + UiTokens.SPACE_XS, relic_width, relic_height)
	var settings_panel_width := minf(UiTokens.SETTINGS_PANEL_SIZE.x, width - edge * 2.0)
	var settings_panel_height := minf(UiTokens.SETTINGS_PANEL_SIZE.y, height - edge * 2.0 - settings_size)
	var relic_panel_width := minf(UiTokens.RELIC_PANEL_SIZE.x, width - edge * 2.0)
	var relic_panel_height := minf(UiTokens.RELIC_PANEL_SIZE.y, height - edge * 2.0)
	return {
		"compact": compact,
		"narrow": narrow,
		"edge": edge,
		"settings_button_rect": Rect2(edge, UiTokens.TOP_BAR_Y, settings_size, settings_size),
		"settings_panel_rect": Rect2(edge, UiTokens.TOP_BAR_Y + settings_size + UiTokens.SPACE_XS, settings_panel_width, settings_panel_height),
		"top_bar_rect": top_rect,
		"top_rect": top_rect,
		"relic_strip_rect": relic_rect,
		"left_panel_rect": left_panel_rect,
		"relic_panel_rect": Rect2((width - relic_panel_width) * 0.5, (height - relic_panel_height) * 0.5, relic_panel_width, relic_panel_height),
		"top_card_height": top_height,
		"top_separation": UiTokens.SPACE_SM if compact else UiTokens.SPACE_LG,
		"right_column_rect": right_column_rect,
		"wave_preview_height": wave_height,
		"detail_panel_rect": detail_rect,
		"detail_rect": detail_rect,
		"legend_panel_rect": legend_rect,
		"legend_visible": legend_visible,
		"deploy_deck_rect": Rect2(deck_left, deck_y, maxf(0.0, deck_right_x - deck_left), deck_height),
		"deck_rect": Rect2(deck_left, deck_y, maxf(0.0, deck_right_x - deck_left), deck_height),
		"deck_height": deck_height,
		"action_panel_rect": action_rect,
		"operator_card_size": UiTokens.OPERATOR_CARD_COMPACT_SIZE if compact else UiTokens.OPERATOR_CARD_SIZE,
	}


static func top_card_widths(viewport_width: float) -> Dictionary:
	if viewport_width <= 720.0:
		return {
			"stage": 112.0,
			"core": 112.0,
			"deploy": 100.0,
			"message": 0.0,
			"time": 164.0,
			"resource_item": 58.0,
		}
	if viewport_width <= UiTokens.BREAKPOINT_NARROW:
		return {
			"stage": 132.0,
			"core": 136.0,
			"deploy": 118.0,
			"message": 0.0,
			"time": 188.0,
			"resource_item": 64.0,
		}
	if viewport_width <= UiTokens.BREAKPOINT_COMPACT:
		return {
			"stage": 152.0,
			"core": 154.0,
			"deploy": 128.0,
			"message": 0.0,
			"time": 198.0,
			"resource_item": 70.0,
		}
	return {
		"stage": 180.0,
		"core": 180.0,
		"deploy": 150.0,
		"message": 300.0 if viewport_width <= 1680.0 else 360.0,
		"time": 216.0,
		"resource_item": 78.0 if viewport_width <= 1680.0 else 86.0,
	}


static func _detail_width_for_width(width: float) -> float:
	if width <= UiTokens.BREAKPOINT_NARROW:
		return UiTokens.DETAIL_WIDTH_NARROW
	if width <= UiTokens.BREAKPOINT_COMPACT:
		return UiTokens.DETAIL_WIDTH_COMPACT
	return UiTokens.DETAIL_WIDTH


static func _detail_min_height_for_width(width: float) -> float:
	if width <= UiTokens.BREAKPOINT_NARROW:
		return UiTokens.DETAIL_MIN_HEIGHT_NARROW
	if width <= UiTokens.BREAKPOINT_COMPACT:
		return UiTokens.DETAIL_MIN_HEIGHT_COMPACT
	return UiTokens.DETAIL_MIN_HEIGHT


static func _left_panel_width_for_width(width: float) -> float:
	if width <= UiTokens.BREAKPOINT_NARROW:
		return UiTokens.LEFT_PANEL_WIDTH_NARROW
	if width <= UiTokens.BREAKPOINT_COMPACT:
		return UiTokens.LEFT_PANEL_WIDTH_COMPACT
	return UiTokens.LEFT_PANEL_WIDTH


static func _legend_size_for_width(width: float) -> Vector2:
	if width <= UiTokens.BREAKPOINT_NARROW:
		return UiTokens.LEGEND_SIZE_NARROW
	if width <= UiTokens.BREAKPOINT_COMPACT:
		return UiTokens.LEGEND_SIZE_COMPACT
	return UiTokens.LEGEND_SIZE


static func _wave_preview_height_for_width(width: float) -> float:
	if width <= UiTokens.BREAKPOINT_NARROW:
		return UiTokens.WAVE_PREVIEW_HEIGHT_NARROW
	if width <= UiTokens.BREAKPOINT_COMPACT:
		return UiTokens.WAVE_PREVIEW_HEIGHT_COMPACT
	return UiTokens.WAVE_PREVIEW_HEIGHT


static func _action_panel_size_for_width(width: float) -> Vector2:
	if width <= UiTokens.BREAKPOINT_NARROW:
		return UiTokens.ACTION_PANEL_SIZE_NARROW
	if width <= UiTokens.BREAKPOINT_COMPACT:
		return UiTokens.ACTION_PANEL_SIZE_COMPACT
	return UiTokens.ACTION_PANEL_SIZE
