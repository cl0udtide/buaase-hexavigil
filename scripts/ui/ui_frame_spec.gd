class_name UiFrameSpec
extends RefCounted

const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")

const TOP_HUD := &"frame_top_status_bar_base"
const TOP_CARD := &"frame_top_status_chip_base"
const HUD_CELL := &"frame_top_status_chip_base"
const HUD_CELL_SELECTED := &"frame_top_status_chip_active_overlay"
const SIDE_PANEL := &"frame_detail_section_base"
const RIGHT_DETAIL_SIDEBAR := &"frame_right_detail_sidebar_base"
const BUILD_SIDE_PANEL := &"frame_left_sidebar_base"
const DECK_PANEL := &"frame_bottom_deploy_rail_base"
const HUD_BOTTOM_RAIL := &"frame_bottom_deploy_rail_base"
const DETAIL_SECTION := &"frame_detail_section_base"
const CARD := &"frame_detail_section_base"
const LIST_CARD := &"frame_build_list_card_base"
const OPERATOR_CARD := &"frame_operator_card_base"
const OPERATOR_CARD_SELECTED := &"frame_operator_card_selected_overlay"
const OPERATOR_CARD_DEPLOYED := &"frame_operator_card_deployed_overlay"
const OPERATOR_CARD_COOLDOWN := &"frame_operator_card_cooldown_overlay"
const OPERATOR_CARD_COOLDOWN_SELECTED := &"frame_operator_card_cooldown_selected_overlay"
const OPERATOR_TITLE_STRIP := &"frame_operator_title_strip"
const OPERATOR_PORTRAIT_BACKPLATE := &"frame_operator_portrait_backplate"
const OPERATOR_PORTRAIT_FRAME := &"frame_operator_portrait_frame"
const OPERATOR_PORTRAIT_SLOT := OPERATOR_PORTRAIT_BACKPLATE
const OPERATOR_COST_BADGE := &"frame_operator_cost_badge"
const OPERATOR_STAT_ROW := &"frame_operator_stat_row"
const BUTTON := &"frame_button_base"
const BUTTON_HOVER := &"frame_button_base"
const BUTTON_PRESSED := &"frame_button_primary_overlay"
const BUTTON_DISABLED := &"frame_button_disabled_overlay"
const BUTTON_COMPACT := &"frame_button_base"
const BUTTON_COMPACT_SELECTED := &"frame_button_primary_overlay"
const BUTTON_SECONDARY := &"frame_button_base"
const BUTTON_DANGER := &"frame_button_danger_overlay"
const SETTINGS_BUTTON := &"frame_settings_button_base"
const TAB := &"frame_sidebar_tab_base"
const TAB_SELECTED := &"frame_sidebar_tab_selected_overlay"
const ICON_TILE := &"frame_icon_backplate"
const ICON_FRAME := &"frame_icon_frame"
const BUILD_ICON_BACKPLATE := &"frame_build_icon_backplate"
const BUILD_ICON_FRAME := &"frame_build_icon_frame"
const COST_BADGE := &"frame_cost_badge_base"
const RELIC_STRIP := &"frame_relic_strip_base"
const RELIC_ENTRY_BUTTON := &"frame_relic_entry_button_base"
const RELIC_ICON := &"relic_icon"
const RELIC_ICON_BACKPLATE := &"frame_relic_icon_backplate"
const RELIC_ICON_FRAME := &"frame_relic_icon_frame"
const RELIC_ICON_COMMON := &"frame_relic_rarity_common_overlay"
const RELIC_ICON_UNCOMMON := &"frame_relic_rarity_uncommon_overlay"
const RELIC_ICON_RARE := &"frame_relic_rarity_rare_overlay"
const RELIC_PANEL := &"frame_relic_panel_base"
const RELIC_FILTER_TAB := &"frame_relic_filter_tab_base"
const RELIC_FILTER_TAB_SELECTED := &"frame_relic_filter_selected_overlay"
const RELIC_CARD := &"relic_card"
const RELIC_CARD_COMMON := &"frame_relic_card_base"
const RELIC_CARD_UNCOMMON := &"frame_relic_card_base"
const RELIC_CARD_RARE := &"frame_relic_card_base"
const RELIC_CARD_HOVER := &"frame_relic_card_hover_overlay"
const SETTINGS_PANEL := &"frame_settings_panel_base"
const SETTINGS_ROW := &"frame_settings_row_base"
const BLESSING_PANEL := &"frame_blessing_panel_base"
const BLESSING_CHOICE_CARD := &"frame_blessing_choice_card_base"
const LEGEND_PANEL := &"frame_legend_panel_base"
const LEGEND_ROW := &"frame_legend_row_base"
const ACTION_PANEL := &"frame_action_panel_base"
const ACTION_BUTTON := &"frame_action_button_base"
const EVENT_PANEL := &"frame_event_panel_base"
const EVENT_CHOICE_BUTTON := &"frame_event_choice_button_base"
const RESULT_PANEL := &"frame_result_panel_base"
const RESULT_STAT_ROW := &"frame_result_stat_row_base"
const DIALOG_BOX := &"frame_dialog_box_base"
const DIALOG_SPEAKER_PLATE := &"frame_dialog_speaker_plate_base"
const MAP_POPUP := &"frame_map_popup_base"
const WAVE_PREVIEW := &"frame_wave_preview_base"
const WAVE_ENEMY_ROW := &"frame_wave_enemy_row_base"
const WAVE_ROUTE_TOGGLE := &"frame_wave_route_toggle_base"
const WAVE_WARNING_ROW := &"frame_wave_warning_row_base"
const TOOLTIP := &"frame_tooltip_base"
const SKILL_BUTTON_PRIMARY := &"frame_button_base"
const PROGRESS_TRACK := &"bar_progress_track"
const PROGRESS_BLUE := &"bar_progress_fill_sp"
const PROGRESS_AMBER := &"bar_progress_fill_core"
const PROGRESS_RED := &"bar_progress_fill_hp"
const UNIT_HEADER_STRIP := &"frame_unit_header_strip"
const UNIT_PORTRAIT_BACKPLATE := &"frame_unit_portrait_backplate"
const UNIT_PORTRAIT_FRAME := &"frame_unit_portrait_frame"
const UNIT_STAT_ROW := &"frame_unit_stat_row"
const SKILL_ICON_BACKPLATE := &"frame_skill_icon_backplate"
const SKILL_ICON_FRAME := &"frame_skill_icon_frame"
const SKILL_DESC_BOX := &"frame_skill_desc_box"

const ZERO_INSETS := Vector4.ZERO
const DEFAULT_INSETS := Vector4(12.0, 9.0, 12.0, 9.0)

const SPECS := {
	TOP_HUD: {"content": Vector4(24.0, 8.0, 24.0, 8.0), "slice": 18.0},
	HUD_CELL: {"content": Vector4(18.0, 7.0, 18.0, 7.0)},
	HUD_CELL_SELECTED: {"content": Vector4(18.0, 7.0, 18.0, 7.0)},
	RIGHT_DETAIL_SIDEBAR: {"content": Vector4(18.0, 18.0, 18.0, 18.0)},
	BUILD_SIDE_PANEL: {"content": Vector4(22.0, 20.0, 22.0, 20.0)},
	DECK_PANEL: {"content": Vector4(24.0, 10.0, 24.0, 10.0)},
	DETAIL_SECTION: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	LIST_CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	OPERATOR_CARD: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_CARD_SELECTED: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_CARD_DEPLOYED: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_CARD_COOLDOWN: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_CARD_COOLDOWN_SELECTED: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_TITLE_STRIP: {"content": Vector4(8.0, 3.0, 8.0, 3.0), "slice": 8.0},
	OPERATOR_PORTRAIT_BACKPLATE: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	OPERATOR_PORTRAIT_FRAME: {"content": ZERO_INSETS},
	OPERATOR_COST_BADGE: {"content": Vector4(6.0, 4.0, 6.0, 4.0)},
	OPERATOR_STAT_ROW: {"content": Vector4(6.0, 2.0, 6.0, 2.0)},
	BUTTON: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_PRESSED: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_DISABLED: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	SETTINGS_BUTTON: {"content": Vector4(4.0, 4.0, 4.0, 4.0)},
	TAB: {"content": Vector4(12.0, 6.0, 12.0, 6.0)},
	TAB_SELECTED: {"content": Vector4(12.0, 6.0, 12.0, 6.0)},
	ICON_TILE: {"content": Vector4(8.0, 8.0, 8.0, 8.0)},
	ICON_FRAME: {"content": ZERO_INSETS},
	BUILD_ICON_BACKPLATE: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	BUILD_ICON_FRAME: {"content": ZERO_INSETS},
	COST_BADGE: {"content": Vector4(6.0, 4.0, 6.0, 4.0)},
	RELIC_STRIP: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	RELIC_ENTRY_BUTTON: {"content": Vector4(10.0, 4.0, 10.0, 4.0)},
	RELIC_ICON: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	RELIC_ICON_BACKPLATE: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	RELIC_ICON_FRAME: {"content": ZERO_INSETS},
	RELIC_ICON_COMMON: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	RELIC_ICON_UNCOMMON: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	RELIC_ICON_RARE: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	RELIC_PANEL: {"content": Vector4(18.0, 16.0, 18.0, 16.0)},
	RELIC_FILTER_TAB: {"content": Vector4(10.0, 5.0, 10.0, 5.0)},
	RELIC_FILTER_TAB_SELECTED: {"content": Vector4(10.0, 5.0, 10.0, 5.0)},
	RELIC_CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	RELIC_CARD_COMMON: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	RELIC_CARD_HOVER: {"content": ZERO_INSETS},
	SETTINGS_PANEL: {"content": Vector4(14.0, 12.0, 14.0, 12.0)},
	SETTINGS_ROW: {"content": Vector4(10.0, 5.0, 10.0, 5.0)},
	BLESSING_PANEL: {"content": Vector4(18.0, 16.0, 18.0, 16.0)},
	BLESSING_CHOICE_CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	LEGEND_PANEL: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	LEGEND_ROW: {"content": Vector4(6.0, 2.0, 6.0, 2.0)},
	ACTION_PANEL: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	ACTION_BUTTON: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	EVENT_PANEL: {"content": Vector4(18.0, 16.0, 18.0, 16.0)},
	EVENT_CHOICE_BUTTON: {"content": Vector4(14.0, 8.0, 14.0, 8.0)},
	RESULT_PANEL: {"content": Vector4(24.0, 20.0, 24.0, 20.0)},
	RESULT_STAT_ROW: {"content": Vector4(12.0, 6.0, 12.0, 6.0)},
	DIALOG_BOX: {"content": Vector4(26.0, 24.0, 26.0, 16.0)},
	DIALOG_SPEAKER_PLATE: {"content": Vector4(18.0, 6.0, 18.0, 6.0)},
	MAP_POPUP: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	WAVE_PREVIEW: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	WAVE_ENEMY_ROW: {"content": Vector4(6.0, 2.0, 6.0, 2.0)},
	WAVE_ROUTE_TOGGLE: {"content": Vector4(8.0, 3.0, 8.0, 3.0)},
	WAVE_WARNING_ROW: {"content": Vector4(6.0, 2.0, 6.0, 2.0)},
	TOOLTIP: {"content": Vector4(14.0, 10.0, 14.0, 10.0)},
	BUTTON_DANGER: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	PROGRESS_TRACK: {"content": ZERO_INSETS},
	PROGRESS_BLUE: {"content": ZERO_INSETS},
	PROGRESS_AMBER: {"content": ZERO_INSETS},
	PROGRESS_RED: {"content": ZERO_INSETS},
	UNIT_HEADER_STRIP: {"content": Vector4(12.0, 6.0, 12.0, 6.0)},
	UNIT_PORTRAIT_BACKPLATE: {"content": Vector4(8.0, 8.0, 8.0, 8.0)},
	UNIT_PORTRAIT_FRAME: {"content": ZERO_INSETS},
	UNIT_STAT_ROW: {"content": Vector4(8.0, 3.0, 8.0, 3.0)},
	SKILL_ICON_BACKPLATE: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	SKILL_ICON_FRAME: {"content": ZERO_INSETS},
	SKILL_DESC_BOX: {"content": Vector4(10.0, 8.0, 10.0, 8.0)},
}


static func style_box(component: StringName, fallback_fill: Color, fallback_border: Color, include_content := true) -> StyleBox:
	var content := content_insets(component) if include_content else ZERO_INSETS
	var texture := UiArtRegistry.get_texture(component, &"frame")
	if texture != null:
		return _texture_box(component, texture, content)
	return _fallback_box(fallback_fill, fallback_border, content)


static func content_insets(component: StringName) -> Vector4:
	return _spec(component).get("content", DEFAULT_INSETS) as Vector4


static func texture_path(component: StringName) -> String:
	return UiArtRegistry.texture_path(component, &"frame")


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


static func _texture_box(component: StringName, texture: Texture2D, content: Vector4) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	var slice := float(_spec(component).get("slice", 14.0))
	var max_x := maxf(1.0, float(texture.get_width()) * 0.45)
	var max_y := maxf(1.0, float(texture.get_height()) * 0.45)
	var horizontal_margin := int(round(minf(slice, max_x)))
	var vertical_margin := int(round(minf(slice, max_y)))
	style.texture_margin_left = horizontal_margin
	style.texture_margin_right = horizontal_margin
	style.texture_margin_top = vertical_margin
	style.texture_margin_bottom = vertical_margin
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.draw_center = true
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style


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
