class_name UiFrameSpec
extends RefCounted

const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")

const STYLE_DIR := "res://assets/ui/styles/"

const TOP_CARD := &"frame_top_status_chip_base"
const TOP_CARD_ACTIVE := &"frame_top_status_chip_base"
const HUD_CELL := &"frame_top_status_chip_base"
const HUD_CELL_SELECTED := &"frame_top_status_chip_base"
const SIDE_PANEL := &"frame_detail_section_base"
const RIGHT_DETAIL_SIDEBAR := &"frame_right_detail_sidebar_base"
const BUILD_SIDE_PANEL := &"frame_left_sidebar_base"
const DECK_PANEL := &"frame_bottom_deploy_rail_base"
const HUD_BOTTOM_RAIL := &"frame_bottom_deploy_rail_base"
const DETAIL_SECTION := &"frame_detail_section_base"
const CARD := &"frame_detail_section_base"
const LIST_CARD := &"frame_build_list_card_base"
const BUILD_ICON_BACKPLATE := &"frame_build_icon_backplate"
const BUILD_ICON_FRAME := &"frame_build_icon_frame"
const COST_BADGE := &"frame_cost_badge_base"
const OPERATOR_CARD := &"frame_operator_card_base"
const OPERATOR_CARD_SELECTED := &"frame_operator_card_selected_overlay"
const OPERATOR_CARD_DEPLOYED := &"frame_operator_card_deployed_overlay"
const OPERATOR_CARD_COOLDOWN := &"frame_operator_card_cooldown_overlay"
const OPERATOR_CARD_COOLDOWN_SELECTED := &"frame_operator_card_cooldown_selected_overlay"
const OPERATOR_TITLE_STRIP := &"frame_operator_title_strip"
const OPERATOR_PORTRAIT_BACKPLATE := &"frame_operator_portrait_backplate"
const OPERATOR_PORTRAIT_FRAME := &"frame_operator_portrait_frame"
const OPERATOR_PORTRAIT_SLOT := &"frame_operator_portrait_backplate"
const OPERATOR_COST_BADGE := &"frame_operator_cost_badge"
const OPERATOR_STAT_ROW := &"frame_operator_stat_row"
const BUTTON := &"frame_button_base"
const BUTTON_PRIMARY_OVERLAY := &"frame_button_primary_overlay"
const BUTTON_DANGER_OVERLAY := &"frame_button_danger_overlay"
const BUTTON_DISABLED_OVERLAY := &"frame_button_disabled_overlay"
const BUTTON_COMPACT := &"frame_button_base"
const SETTINGS_BUTTON := &"frame_settings_button_base"
const TAB := &"frame_sidebar_tab_base"
const TAB_SELECTED := &"frame_sidebar_tab_selected_overlay"
const RELIC_STRIP := &"frame_relic_strip_base"
const RELIC_ENTRY_BUTTON := &"frame_relic_entry_button_base"
const RELIC_ICON := &"frame_relic_icon_frame"
const RELIC_ICON_BACKPLATE := &"frame_relic_icon_backplate"
const RELIC_ICON_COMMON := &"frame_relic_icon_frame"
const RELIC_ICON_UNCOMMON := &"frame_relic_icon_frame"
const RELIC_ICON_RARE := &"frame_relic_icon_frame"
const RELIC_PANEL := &"frame_relic_panel_base"
const RELIC_CARD := &"frame_relic_card_base"
const RELIC_CARD_COMMON := &"frame_relic_card_base"
const RELIC_CARD_UNCOMMON := &"frame_relic_card_base"
const RELIC_CARD_RARE := &"frame_relic_card_base"
const RELIC_CARD_HOVER := &"frame_relic_card_base"
const RELIC_FILTER_TAB := &"frame_relic_filter_tab_base"
const RELIC_FILTER_SELECTED := &"frame_relic_filter_tab_base"
const SETTINGS_PANEL := &"frame_settings_panel_base"
const SETTINGS_ROW := &"frame_settings_row_base"
const BLESSING_PANEL := &"frame_blessing_panel_base"
const BLESSING_CHOICE_CARD := &"frame_blessing_choice_card_base"
const LEGEND_PANEL := &"frame_legend_panel_base"
const LEGEND_ROW := &"frame_legend_row_base"
const ACTION_BUTTON := &"frame_button_base"
const MAP_POPUP := &"frame_map_popup_base"
const EVENT_PANEL := &"frame_event_panel_base"
const EVENT_CHOICE_BUTTON := &"frame_event_choice_button_base"
const DIALOG_BOX := &"frame_dialog_box_base"
const DIALOG_SPEAKER := &"frame_dialog_speaker_plate_base"
const RESULT_PANEL := &"frame_result_panel_base"
const WAVE_PREVIEW := &"frame_wave_preview_base"
const WAVE_ENEMY_ROW := &"frame_wave_enemy_row_base"
const WAVE_ROUTE_TOGGLE := &"frame_wave_route_toggle_base"
const WAVE_WARNING_ROW := &"frame_wave_warning_row_base"
const SKILL_BUTTON_PRIMARY := &"frame_button_base"
const BUTTON_SECONDARY := &"frame_button_base"
const BUTTON_DANGER := &"frame_button_base"
const SPEED_TOGGLE := &"frame_speed_toggle_base"
const SPEED_TOGGLE_ACTIVE := &"frame_button_primary_overlay"
const SKILL_ICON_BACKPLATE := &"frame_skill_icon_backplate"
const SKILL_ICON_FRAME := &"frame_skill_icon_frame"
const SKILL_DESC_BOX := &"frame_skill_desc_box"
const UNIT_HEADER_STRIP := &"frame_unit_header_strip"
const UNIT_PORTRAIT_BACKPLATE := &"frame_unit_portrait_backplate"
const UNIT_PORTRAIT_FRAME := &"frame_unit_portrait_frame"
const UNIT_STAT_ROW := &"frame_unit_stat_row"
const RESOURCE_ITEM := &"frame_resource_item_base"
const RESOURCE_DELTA_BADGE := &"frame_resource_delta_badge"
const TOOLTIP := &"frame_tooltip_base"
const SCROLL_TRACK := &"frame_scroll_track"
const SCROLL_THUMB := &"frame_scroll_thumb"
const SCROLL_TRACK_HORIZONTAL := &"frame_scroll_track"
const SCROLL_THUMB_HORIZONTAL := &"frame_scroll_thumb"
const SLIDER_TRACK := &"frame_slider_track"
const SLIDER_FILL := &"frame_slider_fill"
const SLIDER_HANDLE := &"frame_slider_handle"
const PROGRESS_TRACK := &"bar_progress_track"
const PROGRESS_BLUE := &"bar_progress_fill_sp"
const PROGRESS_AMBER := &"bar_progress_fill_core"
const PROGRESS_RED := &"bar_progress_fill_hp"

const ZERO_INSETS := Vector4.ZERO
const DEFAULT_INSETS := Vector4(12.0, 9.0, 12.0, 9.0)

# Frame textures are resolved only here; component scripts request semantic
# frames and rely on offline-generated stable style resources.
const SPECS := {
	HUD_CELL: {"content": Vector4(18.0, 7.0, 18.0, 7.0)},
	RIGHT_DETAIL_SIDEBAR: {"content": Vector4(20.0, 18.0, 20.0, 20.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	BUILD_SIDE_PANEL: {"content": Vector4(24.0, 20.0, 24.0, 28.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	DECK_PANEL: {"content": Vector4(24.0, 10.0, 24.0, 10.0)},
	DETAIL_SECTION: {"content": Vector4(14.0, 10.0, 14.0, 10.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	LIST_CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	BUILD_ICON_BACKPLATE: {"content": Vector4(6.0, 6.0, 6.0, 6.0), "texture": Vector4(10.0, 10.0, 10.0, 10.0)},
	BUILD_ICON_FRAME: {"content": Vector4(6.0, 6.0, 6.0, 6.0), "texture": Vector4(10.0, 10.0, 10.0, 10.0)},
	COST_BADGE: {"content": Vector4(6.0, 4.0, 6.0, 4.0), "texture": Vector4(10.0, 10.0, 10.0, 10.0)},
	OPERATOR_CARD: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_CARD_SELECTED: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_CARD_DEPLOYED: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_CARD_COOLDOWN: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	OPERATOR_PORTRAIT_SLOT: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	OPERATOR_COST_BADGE: {"content": Vector4(6.0, 4.0, 6.0, 4.0)},
	OPERATOR_STAT_ROW: {"content": Vector4(6.0, 2.0, 6.0, 2.0)},
	BUTTON: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_PRIMARY_OVERLAY: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_DANGER_OVERLAY: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_DISABLED_OVERLAY: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	SETTINGS_BUTTON: {"content": Vector4(4.0, 4.0, 4.0, 4.0)},
	TAB: {"content": Vector4(12.0, 6.0, 12.0, 6.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	TAB_SELECTED: {"content": Vector4(12.0, 6.0, 12.0, 6.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	RELIC_STRIP: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	RELIC_ENTRY_BUTTON: {"content": Vector4(10.0, 5.0, 10.0, 5.0), "texture": Vector4(12.0, 10.0, 12.0, 10.0)},
	RELIC_ICON: {"content": Vector4(6.0, 6.0, 6.0, 6.0), "texture": Vector4(10.0, 10.0, 10.0, 10.0)},
	RELIC_ICON_BACKPLATE: {"content": Vector4(6.0, 6.0, 6.0, 6.0), "texture": Vector4(10.0, 10.0, 10.0, 10.0)},
	RELIC_PANEL: {"content": Vector4(24.0, 18.0, 24.0, 18.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	RELIC_CARD: {"content": Vector4(16.0, 10.0, 16.0, 10.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	RELIC_FILTER_TAB: {"content": Vector4(12.0, 5.0, 12.0, 5.0), "texture": Vector4(12.0, 10.0, 12.0, 10.0)},
	SETTINGS_PANEL: {"content": Vector4(14.0, 12.0, 14.0, 12.0)},
	BLESSING_PANEL: {"content": Vector4(18.0, 16.0, 18.0, 16.0)},
	BLESSING_CHOICE_CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	LEGEND_PANEL: {"content": Vector4(14.0, 12.0, 14.0, 12.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	LEGEND_ROW: {"content": Vector4(10.0, 4.0, 10.0, 4.0), "texture": Vector4(18.0, 10.0, 18.0, 10.0)},
	WAVE_PREVIEW: {"content": Vector4(14.0, 12.0, 14.0, 12.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	WAVE_ENEMY_ROW: {"content": Vector4(10.0, 4.0, 10.0, 4.0), "texture": Vector4(18.0, 12.0, 18.0, 12.0)},
	WAVE_ROUTE_TOGGLE: {"content": Vector4(10.0, 4.0, 10.0, 4.0), "texture": Vector4(18.0, 12.0, 18.0, 12.0)},
	WAVE_WARNING_ROW: {"content": Vector4(10.0, 4.0, 10.0, 4.0), "texture": Vector4(18.0, 12.0, 18.0, 12.0)},
	UNIT_HEADER_STRIP: {"content": Vector4(14.0, 8.0, 14.0, 8.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	UNIT_PORTRAIT_BACKPLATE: {"content": Vector4(8.0, 8.0, 8.0, 8.0), "texture": Vector4(10.0, 10.0, 10.0, 10.0)},
	UNIT_PORTRAIT_FRAME: {"content": Vector4(8.0, 8.0, 8.0, 8.0), "texture": Vector4(10.0, 10.0, 10.0, 10.0)},
	UNIT_STAT_ROW: {"content": Vector4(10.0, 4.0, 10.0, 4.0), "texture": Vector4(18.0, 12.0, 18.0, 12.0)},
	SKILL_ICON_BACKPLATE: {"content": Vector4(6.0, 6.0, 6.0, 6.0), "texture": Vector4(10.0, 10.0, 10.0, 10.0)},
	SKILL_ICON_FRAME: {"content": Vector4(6.0, 6.0, 6.0, 6.0), "texture": Vector4(10.0, 10.0, 10.0, 10.0)},
	SKILL_DESC_BOX: {"content": Vector4(12.0, 10.0, 12.0, 10.0), "texture": Vector4(18.0, 18.0, 18.0, 18.0)},
	PROGRESS_TRACK: {"content": ZERO_INSETS},
	PROGRESS_BLUE: {"content": ZERO_INSETS},
	PROGRESS_AMBER: {"content": ZERO_INSETS},
	PROGRESS_RED: {"content": ZERO_INSETS},
}


static func style_box(component: StringName, fallback_fill: Color, fallback_border: Color, include_content := true) -> StyleBox:
	var content := content_insets(component) if include_content else ZERO_INSETS
	var style := _style_resource(component)
	if style is StyleBoxTexture:
		return _prepared_texture_style(style as StyleBoxTexture, fallback_fill, content)
	var texture := UiArtRegistry.get_frame_texture(component)
	if texture == null:
		push_error("Missing UI frame asset for %s. Run scripts/tools/generate_ui_derived_assets.gd." % String(component))
		return StyleBoxEmpty.new()
	return _texture_box(texture, component, fallback_fill, content)


static func content_insets(component: StringName) -> Vector4:
	return _spec(component).get("content", DEFAULT_INSETS) as Vector4


static func texture_insets(component: StringName) -> Vector4:
	var explicit: Variant = _spec(component).get("texture", null)
	if explicit is Vector4:
		return explicit as Vector4
	return _default_texture_margin(component)


static func texture_path(component: StringName) -> String:
	var path := "res://assets/ui/generated/%s.png" % String(component)
	return path if ResourceLoader.exists(path) else ""


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


static func _style_resource(component: StringName) -> StyleBox:
	var path := "%s%s.tres" % [STYLE_DIR, String(component)]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as StyleBox


static func _prepared_texture_style(base_style: StyleBoxTexture, fallback_fill: Color, content: Vector4) -> StyleBoxTexture:
	var style := base_style.duplicate(true) as StyleBoxTexture
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	style.modulate_color = Color(1.0, 1.0, 1.0, fallback_fill.a)
	return style


static func _texture_box(texture: Texture2D, component: StringName, fallback_fill: Color, content: Vector4) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.draw_center = true
	var margin := _texture_margin(component)
	style.texture_margin_left = margin.x
	style.texture_margin_top = margin.y
	style.texture_margin_right = margin.z
	style.texture_margin_bottom = margin.w
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	style.modulate_color = Color(1.0, 1.0, 1.0, fallback_fill.a)
	return style


static func _texture_margin(component: StringName) -> Vector4:
	return texture_insets(component)


static func _default_texture_margin(component: StringName) -> Vector4:
	if component in [SCROLL_TRACK, SCROLL_THUMB, SCROLL_TRACK_HORIZONTAL, SCROLL_THUMB_HORIZONTAL]:
		return Vector4(5.0, 5.0, 5.0, 5.0)
	if component == SLIDER_HANDLE:
		return Vector4(8.0, 8.0, 8.0, 8.0)
	var component_text := String(component)
	if component_text.begins_with("bar_progress"):
		return Vector4(8.0, 6.0, 8.0, 6.0)
	if component_text.begins_with("icon_") or component_text.contains("_icon_"):
		return Vector4(10.0, 10.0, 10.0, 10.0)
	return Vector4(18.0, 18.0, 18.0, 18.0)
