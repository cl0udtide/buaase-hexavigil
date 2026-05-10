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
	var top_height: float = UiTokens.TOP_BAR_HEIGHT_COMPACT if compact else UiTokens.TOP_BAR_HEIGHT
	var deck_height: float = UiTokens.DEPLOY_DECK_HEIGHT_COMPACT if compact else UiTokens.DEPLOY_DECK_HEIGHT
	var deck_left: float = maxf(edge, left_reserved_width + UiTokens.SPACE_LG)
	var detail_left: float = width - edge - detail_width
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
	return {
		"compact": compact,
		"narrow": narrow,
		"edge": edge,
		"top_rect": Rect2(edge, UiTokens.TOP_BAR_Y, width - edge * 2.0, top_height),
		"top_card_height": top_height,
		"top_separation": UiTokens.SPACE_SM if compact else UiTokens.SPACE_LG,
		"detail_rect": Rect2(detail_left, UiTokens.DETAIL_TOP, detail_width, maxf(240.0, height - UiTokens.DETAIL_TOP - edge)),
		"deck_rect": Rect2(deck_left, height - edge - deck_height, maxf(0.0, deck_right_x - deck_left), deck_height),
		"deck_height": deck_height,
		"operator_card_size": UiTokens.OPERATOR_CARD_COMPACT_SIZE if compact else UiTokens.OPERATOR_CARD_SIZE,
	}


static func top_card_widths(viewport_width: float) -> Dictionary:
	if viewport_width <= UiTokens.BREAKPOINT_NARROW:
		return {
			"stage": 138.0,
			"core": 142.0,
			"deploy": 122.0,
			"message": 178.0,
			"time": 178.0,
			"resource": 160.0,
			"debug": 62.0,
		}
	if viewport_width <= UiTokens.BREAKPOINT_COMPACT:
		return {
			"stage": 158.0,
			"core": 158.0,
			"deploy": 132.0,
			"message": 220.0,
			"time": 178.0,
			"resource": 188.0,
			"debug": 68.0,
		}
	return {
		"stage": 190.0,
		"core": 190.0,
		"deploy": 160.0,
		"message": 300.0,
		"time": 200.0,
		"resource": 245.0,
		"debug": 76.0,
	}


static func _detail_width_for_width(width: float) -> float:
	if width <= UiTokens.BREAKPOINT_NARROW:
		return UiTokens.DETAIL_WIDTH_NARROW
	if width <= UiTokens.BREAKPOINT_COMPACT:
		return UiTokens.DETAIL_WIDTH_COMPACT
	return UiTokens.DETAIL_WIDTH
