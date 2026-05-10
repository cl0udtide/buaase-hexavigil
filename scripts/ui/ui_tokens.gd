class_name UiTokens
extends RefCounted


const BASE_VIEWPORT := Vector2(1920.0, 1080.0)
const BREAKPOINT_COMPACT := 1500.0
const BREAKPOINT_NARROW := 1280.0

const EDGE_DESKTOP := 14.0
const EDGE_COMPACT := 10.0
const EDGE_NARROW := 8.0

const SPACE_2XS := 4.0
const SPACE_XS := 6.0
const SPACE_SM := 8.0
const SPACE_MD := 10.0
const SPACE_LG := 12.0
const SPACE_XL := 16.0

const RADIUS_SM := 4.0
const RADIUS_MD := 6.0

const FONT_XS := 12
const FONT_SM := 13
const FONT_MD := 15
const FONT_LG := 16
const FONT_XL := 22

const TOP_BAR_HEIGHT := 58.0
const TOP_BAR_HEIGHT_COMPACT := 54.0
const TOP_BAR_Y := 8.0
const SETTINGS_BUTTON_SIZE := 44.0
const SETTINGS_BUTTON_SIZE_COMPACT := 40.0
const SETTINGS_PANEL_SIZE := Vector2(420.0, 226.0)
const RELIC_STRIP_HEIGHT := 44.0
const RELIC_STRIP_HEIGHT_COMPACT := 40.0
const RELIC_STRIP_MIN_WIDTH := 260.0
const RELIC_STRIP_MAX_WIDTH := 720.0
const RELIC_PANEL_SIZE := Vector2(900.0, 640.0)

const DETAIL_WIDTH := 384.0
const DETAIL_WIDTH_COMPACT := 342.0
const DETAIL_WIDTH_NARROW := 320.0
const DETAIL_TOP := 84.0

const DEPLOY_DECK_HEIGHT := 146.0
const DEPLOY_DECK_HEIGHT_COMPACT := 136.0
const DEPLOY_DECK_MIN_WIDTH := 520.0

const OPERATOR_CARD_SIZE := Vector2(154.0, 136.0)
const OPERATOR_CARD_COMPACT_SIZE := Vector2(138.0, 126.0)


static func edge_for_width(width: float) -> float:
	if width <= BREAKPOINT_NARROW:
		return EDGE_NARROW
	if width <= BREAKPOINT_COMPACT:
		return EDGE_COMPACT
	return EDGE_DESKTOP


static func is_compact(width: float) -> bool:
	return width <= BREAKPOINT_COMPACT


static func is_narrow(width: float) -> bool:
	return width <= BREAKPOINT_NARROW
