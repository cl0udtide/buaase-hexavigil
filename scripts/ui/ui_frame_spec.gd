class_name UiFrameSpec
extends RefCounted


const TOP_HUD := &"top_hud"
const TOP_CARD := &"top_card"
const HUD_CELL := &"hud_cell"
const HUD_CELL_SELECTED := &"hud_cell_selected"
const SIDE_PANEL := &"side_panel"
const BUILD_SIDE_PANEL := &"build_side_panel"
const DECK_PANEL := &"deck_panel"
const HUD_BOTTOM_RAIL := &"hud_bottom_rail"
const DETAIL_SECTION := &"detail_section"
const CARD := &"card"
const LIST_CARD := &"list_card"
const OPERATOR_CARD := &"operator_card"
const BUTTON := &"button"
const BUTTON_HOVER := &"button_hover"
const BUTTON_PRESSED := &"button_pressed"
const BUTTON_DISABLED := &"button_disabled"
const BUTTON_COMPACT := &"button_compact"
const BUTTON_COMPACT_SELECTED := &"button_compact_selected"
const TAB := &"tab"
const TAB_SELECTED := &"tab_selected"
const ICON_TILE := &"icon_tile"
const RELIC_STRIP := &"relic_strip"
const RELIC_ICON := &"relic_icon"
const RELIC_PANEL := &"relic_panel"
const RELIC_CARD := &"relic_card"
const SETTINGS_PANEL := &"settings_panel"
const PROGRESS_TRACK := &"progress_track"
const PROGRESS_BLUE := &"progress_blue"
const PROGRESS_AMBER := &"progress_amber"
const PROGRESS_RED := &"progress_red"

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
	BUILD_SIDE_PANEL: {"content": Vector4(22.0, 20.0, 22.0, 20.0)},
	DECK_PANEL: {"content": Vector4(24.0, 10.0, 24.0, 10.0)},
	HUD_BOTTOM_RAIL: {"content": ZERO_INSETS},
	DETAIL_SECTION: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	LIST_CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	OPERATOR_CARD: {"content": Vector4(12.0, 10.0, 12.0, 10.0)},
	BUTTON: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_HOVER: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_PRESSED: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_DISABLED: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	BUTTON_COMPACT: {"content": Vector4(10.0, 5.0, 10.0, 5.0)},
	BUTTON_COMPACT_SELECTED: {"content": Vector4(10.0, 5.0, 10.0, 5.0)},
	TAB: {"content": Vector4(12.0, 6.0, 12.0, 6.0)},
	TAB_SELECTED: {"content": Vector4(12.0, 6.0, 12.0, 6.0)},
	ICON_TILE: {"content": Vector4(8.0, 8.0, 8.0, 8.0)},
	RELIC_STRIP: {"content": Vector4(10.0, 6.0, 10.0, 6.0)},
	RELIC_ICON: {"content": Vector4(6.0, 6.0, 6.0, 6.0)},
	RELIC_PANEL: {"content": Vector4(18.0, 16.0, 18.0, 16.0)},
	RELIC_CARD: {"content": Vector4(12.0, 8.0, 12.0, 8.0)},
	SETTINGS_PANEL: {"content": Vector4(14.0, 12.0, 14.0, 12.0)},
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
