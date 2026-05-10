class_name UiFrameSpec
extends RefCounted


const TOP_HUD := &"frame_top_status_bar"
const TOP_CARD := &"top_card"
const HUD_CELL := &"frame_top_status_chip"
const HUD_CELL_SELECTED := &"hud_cell_selected"
const SIDE_PANEL := &"side_panel"
const RIGHT_DETAIL_SIDEBAR := &"frame_right_detail_sidebar"
const BUILD_SIDE_PANEL := &"frame_left_build_sidebar"
const DECK_PANEL := &"frame_bottom_deploy_rail"
const HUD_BOTTOM_RAIL := &"hud_bottom_rail"
const DETAIL_SECTION := &"frame_detail_section"
const CARD := &"card"
const LIST_CARD := &"frame_build_list_card"
const OPERATOR_CARD := &"frame_operator_card_idle"
const OPERATOR_CARD_SELECTED := &"frame_operator_card_selected"
const OPERATOR_CARD_DEPLOYED := &"frame_operator_card_deployed"
const OPERATOR_CARD_COOLDOWN := &"frame_operator_card_cooldown"
const OPERATOR_PORTRAIT_SLOT := &"frame_operator_portrait_slot"
const OPERATOR_COST_BADGE := &"frame_operator_cost_badge"
const OPERATOR_STAT_ROW := &"frame_operator_stat_row"
const BUTTON := &"button"
const BUTTON_HOVER := &"button_hover"
const BUTTON_PRESSED := &"button_pressed"
const BUTTON_DISABLED := &"button_disabled"
const BUTTON_COMPACT := &"button_compact"
const BUTTON_COMPACT_SELECTED := &"button_compact_selected"
const SETTINGS_BUTTON := &"frame_settings_button"
const TAB := &"frame_build_tab_idle"
const TAB_SELECTED := &"frame_build_tab_selected"
const ICON_TILE := &"frame_icon_tile"
const RELIC_STRIP := &"frame_relic_strip"
const RELIC_ICON := &"relic_icon"
const RELIC_ICON_COMMON := &"frame_relic_icon_slot_common"
const RELIC_ICON_UNCOMMON := &"frame_relic_icon_slot_uncommon"
const RELIC_ICON_RARE := &"frame_relic_icon_slot_rare"
const RELIC_PANEL := &"frame_relic_panel"
const RELIC_CARD := &"relic_card"
const RELIC_CARD_COMMON := &"frame_relic_card_common"
const RELIC_CARD_UNCOMMON := &"frame_relic_card_uncommon"
const RELIC_CARD_RARE := &"frame_relic_card_rare"
const SETTINGS_PANEL := &"frame_settings_panel"
const BLESSING_PANEL := &"frame_blessing_panel"
const BLESSING_CHOICE_CARD := &"frame_blessing_choice_card"
const LEGEND_PANEL := &"frame_legend_panel"
const SKILL_BUTTON_PRIMARY := &"frame_skill_button_primary"
const BUTTON_SECONDARY := &"frame_button_secondary"
const BUTTON_DANGER := &"frame_button_danger"
const PROGRESS_TRACK := &"bar_progress_track"
const PROGRESS_BLUE := &"bar_progress_fill_sp"
const PROGRESS_AMBER := &"bar_progress_fill_core"
const PROGRESS_RED := &"bar_progress_fill_hp"

const ZERO_INSETS := Vector4.ZERO
const DEFAULT_INSETS := Vector4(12.0, 9.0, 12.0, 9.0)

# UI is currently asset-free. These specs keep the old component contract and
# only describe content padding; all visual frames are StyleBoxFlat defaults.
const SPECS := {
	TOP_HUD: {"content": Vector4(24.0, 8.0, 24.0, 8.0)},
	TOP_CARD: {"content": Vector4(14.0, 8.0, 14.0, 8.0)},
	HUD_CELL: {"content": Vector4(18.0, 7.0, 18.0, 7.0)},
	HUD_CELL_SELECTED: {"content": Vector4(18.0, 7.0, 18.0, 7.0)},
	SIDE_PANEL: {"content": Vector4(20.0, 18.0, 20.0, 18.0)},
	RIGHT_DETAIL_SIDEBAR: {"content": Vector4(18.0, 18.0, 18.0, 18.0)},
	BUILD_SIDE_PANEL: {"content": Vector4(22.0, 20.0, 22.0, 20.0)},
	DECK_PANEL: {"content": Vector4(24.0, 10.0, 24.0, 10.0)},
	HUD_BOTTOM_RAIL: {"content": ZERO_INSETS},
	DETAIL_SECTION: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	LIST_CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	OPERATOR_CARD: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_CARD_SELECTED: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_CARD_DEPLOYED: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_CARD_COOLDOWN: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_PORTRAIT_SLOT: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	OPERATOR_COST_BADGE: {"content": Vector4(6.0, 4.0, 6.0, 4.0)},
	OPERATOR_STAT_ROW: {"content": Vector4(6.0, 2.0, 6.0, 2.0)},
	BUTTON: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_HOVER: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_PRESSED: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_DISABLED: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_COMPACT: {"content": Vector4(10.0, 5.0, 10.0, 5.0)},
	BUTTON_COMPACT_SELECTED: {"content": Vector4(10.0, 5.0, 10.0, 5.0)},
	SETTINGS_BUTTON: {"content": Vector4(4.0, 4.0, 4.0, 4.0)},
	TAB: {"content": Vector4(12.0, 6.0, 12.0, 6.0)},
	TAB_SELECTED: {"content": Vector4(12.0, 6.0, 12.0, 6.0)},
	ICON_TILE: {"content": Vector4(8.0, 8.0, 8.0, 8.0)},
	RELIC_STRIP: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	RELIC_ICON: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	RELIC_ICON_COMMON: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	RELIC_ICON_UNCOMMON: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	RELIC_ICON_RARE: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	RELIC_PANEL: {"content": Vector4(18.0, 16.0, 18.0, 16.0)},
	RELIC_CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	RELIC_CARD_COMMON: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	RELIC_CARD_UNCOMMON: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	RELIC_CARD_RARE: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	SETTINGS_PANEL: {"content": Vector4(14.0, 12.0, 14.0, 12.0)},
	BLESSING_PANEL: {"content": Vector4(18.0, 16.0, 18.0, 16.0)},
	BLESSING_CHOICE_CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	LEGEND_PANEL: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	SKILL_BUTTON_PRIMARY: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	BUTTON_SECONDARY: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	BUTTON_DANGER: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	PROGRESS_TRACK: {"content": ZERO_INSETS},
	PROGRESS_BLUE: {"content": ZERO_INSETS},
	PROGRESS_AMBER: {"content": ZERO_INSETS},
	PROGRESS_RED: {"content": ZERO_INSETS},
}


static func style_box(component: StringName, fallback_fill: Color, fallback_border: Color, include_content := true) -> StyleBox:
	var content := content_insets(component) if include_content else ZERO_INSETS
	return _fallback_box(fallback_fill, fallback_border, content)


static func content_insets(component: StringName) -> Vector4:
	return _spec(component).get("content", DEFAULT_INSETS) as Vector4


static func texture_path(_component: StringName) -> String:
	return ""


static func apply_margin(container: MarginContainer, component: StringName, extra := Vector4.ZERO) -> void:
	if container == null:
		return
	apply_custom_margin(container, content_insets(component) + extra)


static func apply_custom_margin(container: MarginContainer, insets: Vector4) -> void:
	if container == null:
		return
	container.add_theme_constant_override("margin_left", int(round(insets.x)))
	container.add_theme_constant_override("margin_top", int(round(insets.y)))
	container.add_theme_constant_override("margin_right", int(round(insets.z)))
	container.add_theme_constant_override("margin_bottom", int(round(insets.w)))


static func _spec(component: StringName) -> Dictionary:
	return SPECS.get(component, SPECS[BUTTON]) as Dictionary


static func _fallback_box(fill: Color, border: Color, content: Vector4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style
