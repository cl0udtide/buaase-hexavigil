class_name UiFrameSpec
extends RefCounted


const FANTASY_STONE_ROOT := "res://assets/UI/FantasyStone"
const FS_PANEL_TOP_HUD := FANTASY_STONE_ROOT + "/panel_top_hud.png"
const FS_PANEL_TOP_HUD_PLAIN_GENERATED := FANTASY_STONE_ROOT + "/panel_top_hud_plain_generated.png"
const FS_PANEL_SIDE_SCROLL := FANTASY_STONE_ROOT + "/panel_side_scroll.png"
const FS_PANEL_BUILD_SIDE_PLAIN_GENERATED := FANTASY_STONE_ROOT + "/panel_build_side_plain_generated.png"
const FS_PANEL_DETAIL := FANTASY_STONE_ROOT + "/panel_detail.png"
const FS_PANEL_BADGE := FANTASY_STONE_ROOT + "/panel_badge.png"
const FS_PANEL_STRIP := FANTASY_STONE_ROOT + "/panel_strip.png"
const FS_PANEL_CARD_SQUARE := FANTASY_STONE_ROOT + "/panel_card_square.png"
const FS_PANEL_CARD_SMALL := FANTASY_STONE_ROOT + "/panel_card_small.png"
const FS_PANEL_HUD_CELL_GENERATED := FANTASY_STONE_ROOT + "/panel_hud_cell_generated.png"
const FS_PANEL_HUD_CELL_SLIM_GENERATED := FANTASY_STONE_ROOT + "/panel_hud_cell_slim_generated.png"
const FS_PANEL_HUD_CELL_SLIM_SELECTED_GENERATED := FANTASY_STONE_ROOT + "/panel_hud_cell_slim_selected_generated.png"
const FS_PANEL_HUD_BOTTOM_RAIL_GENERATED := FANTASY_STONE_ROOT + "/panel_hud_bottom_rail_generated.png"
const FS_PANEL_DETAIL_SECTION_GENERATED := FANTASY_STONE_ROOT + "/panel_detail_section_generated.png"
const FS_PANEL_DETAIL_SECTION_SLIM_GENERATED := FANTASY_STONE_ROOT + "/panel_detail_section_slim_generated.png"
const FS_BUTTON_NORMAL := FANTASY_STONE_ROOT + "/button_normal.png"
const FS_BUTTON_HOVER := FANTASY_STONE_ROOT + "/button_hover.png"
const FS_BUTTON_PRESSED := FANTASY_STONE_ROOT + "/button_pressed.png"
const FS_BUTTON_DISABLED := FANTASY_STONE_ROOT + "/button_disabled.png"
const FS_BUTTON_COMPACT_GENERATED := FANTASY_STONE_ROOT + "/button_compact_generated.png"
const FS_BUTTON_COMPACT_SELECTED_GENERATED := FANTASY_STONE_ROOT + "/button_compact_selected_generated.png"
const FS_TAB_SELECTED := FANTASY_STONE_ROOT + "/tab_selected.png"
const FS_TAB_IDLE := FANTASY_STONE_ROOT + "/tab_idle.png"
const FS_PROGRESS_TRACK := FANTASY_STONE_ROOT + "/progress_track.png"
const FS_PROGRESS_BLUE := FANTASY_STONE_ROOT + "/progress_fill_blue.png"
const FS_PROGRESS_AMBER := FANTASY_STONE_ROOT + "/progress_fill_amber.png"
const FS_PROGRESS_RED := FANTASY_STONE_ROOT + "/progress_fill_red.png"

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
const PROGRESS_TRACK := &"progress_track"
const PROGRESS_BLUE := &"progress_blue"
const PROGRESS_AMBER := &"progress_amber"
const PROGRESS_RED := &"progress_red"

const ZERO_INSETS := Vector4.ZERO
const DEFAULT_INSETS := Vector4(12.0, 9.0, 12.0, 9.0)

# Insets are left, top, right, bottom. Native sizes are recorded from the PNGs,
# and content values are the measured text-safe pixels after bevel/decor areas.
const SPECS := {
	TOP_HUD: {
		"path": FS_PANEL_TOP_HUD_PLAIN_GENERATED,
		"native": Vector2(1200.0, 86.0),
		"slice": Vector4(42.0, 24.0, 42.0, 24.0),
		"content": Vector4(24.0, 8.0, 24.0, 8.0),
	},
	TOP_CARD: {
		"path": FS_PANEL_BADGE,
		"native": Vector2(232.0, 99.0),
		"slice": Vector4(28.0, 24.0, 28.0, 24.0),
		"content": Vector4(14.0, 10.0, 14.0, 10.0),
	},
	HUD_CELL: {
		"path": FS_PANEL_HUD_CELL_SLIM_GENERATED,
		"native": Vector2(320.0, 50.0),
		"slice": Vector4(26.0, 15.0, 26.0, 15.0),
		"content": Vector4(12.0, 4.0, 12.0, 4.0),
	},
	HUD_CELL_SELECTED: {
		"path": FS_PANEL_HUD_CELL_SLIM_SELECTED_GENERATED,
		"native": Vector2(320.0, 50.0),
		"slice": Vector4(26.0, 15.0, 26.0, 15.0),
		"content": Vector4(12.0, 4.0, 12.0, 4.0),
	},
	SIDE_PANEL: {
		"path": FS_PANEL_SIDE_SCROLL,
		"native": Vector2(453.0, 689.0),
		"slice": Vector4(34.0, 34.0, 34.0, 34.0),
		"content": Vector4(20.0, 18.0, 20.0, 18.0),
	},
	BUILD_SIDE_PANEL: {
		"path": FS_PANEL_BUILD_SIDE_PLAIN_GENERATED,
		"native": Vector2(314.0, 720.0),
		"slice": Vector4(34.0, 34.0, 34.0, 34.0),
		"content": Vector4(22.0, 20.0, 22.0, 20.0),
	},
	DECK_PANEL: {
		"path": FS_PANEL_STRIP,
		"native": Vector2(494.0, 74.0),
		"slice": Vector4(30.0, 24.0, 30.0, 24.0),
		"content": Vector4(32.0, 12.0, 32.0, 12.0),
	},
	HUD_BOTTOM_RAIL: {
		"path": FS_PANEL_HUD_BOTTOM_RAIL_GENERATED,
		"native": Vector2(640.0, 52.0),
		"slice": Vector4(42.0, 20.0, 42.0, 20.0),
		"content": ZERO_INSETS,
	},
	DETAIL_SECTION: {
		"path": FS_PANEL_DETAIL_SECTION_SLIM_GENERATED,
		"native": Vector2(360.0, 92.0),
		"slice": Vector4(22.0, 18.0, 22.0, 18.0),
		"content": Vector4(12.0, 8.0, 12.0, 8.0),
	},
	CARD: {
		"path": FS_PANEL_BADGE,
		"native": Vector2(232.0, 99.0),
		"slice": Vector4(28.0, 24.0, 28.0, 24.0),
		"content": Vector4(16.0, 12.0, 16.0, 12.0),
	},
	LIST_CARD: {
		"path": FS_PANEL_BADGE,
		"native": Vector2(232.0, 99.0),
		"slice": Vector4(28.0, 24.0, 28.0, 24.0),
		"content": Vector4(16.0, 12.0, 16.0, 12.0),
	},
	OPERATOR_CARD: {
		"path": FS_PANEL_CARD_SQUARE,
		"native": Vector2(232.0, 234.0),
		"slice": Vector4(28.0, 28.0, 28.0, 28.0),
		"content": Vector4(14.0, 12.0, 14.0, 12.0),
	},
	BUTTON: {
		"path": FS_BUTTON_NORMAL,
		"native": Vector2(224.0, 86.0),
		"slice": Vector4(28.0, 24.0, 28.0, 24.0),
		"content": Vector4(10.0, 6.0, 10.0, 6.0),
	},
	BUTTON_HOVER: {
		"path": FS_BUTTON_HOVER,
		"native": Vector2(216.0, 85.0),
		"slice": Vector4(28.0, 24.0, 28.0, 24.0),
		"content": Vector4(10.0, 6.0, 10.0, 6.0),
	},
	BUTTON_PRESSED: {
		"path": FS_BUTTON_PRESSED,
		"native": Vector2(202.0, 86.0),
		"slice": Vector4(28.0, 24.0, 28.0, 24.0),
		"content": Vector4(10.0, 6.0, 10.0, 6.0),
	},
	BUTTON_DISABLED: {
		"path": FS_BUTTON_DISABLED,
		"native": Vector2(198.0, 85.0),
		"slice": Vector4(28.0, 24.0, 28.0, 24.0),
		"content": Vector4(10.0, 6.0, 10.0, 6.0),
	},
	BUTTON_COMPACT: {
		"path": FS_BUTTON_COMPACT_GENERATED,
		"native": Vector2(174.0, 54.0),
		"slice": Vector4(24.0, 16.0, 24.0, 16.0),
		"content": Vector4(10.0, 4.0, 10.0, 4.0),
	},
	BUTTON_COMPACT_SELECTED: {
		"path": FS_BUTTON_COMPACT_SELECTED_GENERATED,
		"native": Vector2(174.0, 54.0),
		"slice": Vector4(24.0, 16.0, 24.0, 16.0),
		"content": Vector4(10.0, 4.0, 10.0, 4.0),
	},
	TAB: {
		"path": FS_TAB_IDLE,
		"native": Vector2(339.0, 89.0),
		"slice": Vector4(42.0, 28.0, 42.0, 24.0),
		"content": Vector4(16.0, 8.0, 16.0, 6.0),
	},
	TAB_SELECTED: {
		"path": FS_TAB_SELECTED,
		"native": Vector2(366.0, 91.0),
		"slice": Vector4(42.0, 28.0, 42.0, 24.0),
		"content": Vector4(16.0, 8.0, 16.0, 6.0),
	},
	ICON_TILE: {
		"path": FS_PANEL_CARD_SMALL,
		"native": Vector2(131.0, 130.0),
		"slice": Vector4(24.0, 24.0, 24.0, 24.0),
		"content": Vector4(8.0, 8.0, 8.0, 8.0),
	},
	PROGRESS_TRACK: {
		"path": FS_PROGRESS_TRACK,
		"native": Vector2(561.0, 59.0),
		"slice": Vector4(24.0, 18.0, 24.0, 18.0),
		"content": ZERO_INSETS,
	},
	PROGRESS_BLUE: {
		"path": FS_PROGRESS_BLUE,
		"native": Vector2(235.0, 52.0),
		"slice": Vector4(22.0, 18.0, 22.0, 18.0),
		"content": ZERO_INSETS,
	},
	PROGRESS_AMBER: {
		"path": FS_PROGRESS_AMBER,
		"native": Vector2(231.0, 52.0),
		"slice": Vector4(22.0, 18.0, 22.0, 18.0),
		"content": ZERO_INSETS,
	},
	PROGRESS_RED: {
		"path": FS_PROGRESS_RED,
		"native": Vector2(249.0, 52.0),
		"slice": Vector4(22.0, 18.0, 22.0, 18.0),
		"content": ZERO_INSETS,
	},
}


static func style_box(component: StringName, fallback_fill: Color, fallback_border: Color, include_content := true) -> StyleBox:
	var spec := _spec(component)
	var texture := load(String(spec.get("path", ""))) as Texture2D
	var content := content_insets(component) if include_content else ZERO_INSETS
	if texture == null:
		return _fallback_box(fallback_fill, fallback_border, content)

	var style := StyleBoxTexture.new()
	style.texture = texture
	_apply_texture_margins(style, spec.get("slice", DEFAULT_INSETS) as Vector4)
	_apply_content_margins(style, content)
	return style


static func content_insets(component: StringName) -> Vector4:
	return _spec(component).get("content", DEFAULT_INSETS) as Vector4


static func texture_path(component: StringName) -> String:
	return String(_spec(component).get("path", ""))


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


static func _apply_texture_margins(style: StyleBoxTexture, insets: Vector4) -> void:
	style.set_texture_margin(SIDE_LEFT, insets.x)
	style.set_texture_margin(SIDE_TOP, insets.y)
	style.set_texture_margin(SIDE_RIGHT, insets.z)
	style.set_texture_margin(SIDE_BOTTOM, insets.w)


static func _apply_content_margins(style: StyleBox, insets: Vector4) -> void:
	style.content_margin_left = insets.x
	style.content_margin_top = insets.y
	style.content_margin_right = insets.z
	style.content_margin_bottom = insets.w


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
	_apply_content_margins(style, content)
	return style
