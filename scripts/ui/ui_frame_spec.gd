class_name UiFrameSpec
extends RefCounted


const COMMAND_GLASS_ROOT := "res://assets/UI/CommandGlass"
const CG_PANEL_TOP_HUD := COMMAND_GLASS_ROOT + "/panel_top_hud.png"
const CG_PANEL_DETAIL := COMMAND_GLASS_ROOT + "/panel_detail.png"
const CG_PANEL_OPERATOR := COMMAND_GLASS_ROOT + "/panel_operator.png"
const CG_CARD_LIGHT := COMMAND_GLASS_ROOT + "/card_light.png"
const CG_CARD_SMALL_LIGHT := COMMAND_GLASS_ROOT + "/card_small_light.png"
const CG_BUTTON_NORMAL := COMMAND_GLASS_ROOT + "/button_normal.png"
const CG_BUTTON_PRESSED := COMMAND_GLASS_ROOT + "/button_pressed.png"
const CG_BUTTON_DISABLED := COMMAND_GLASS_ROOT + "/button_disabled.png"
const CG_TAB_SELECTED := COMMAND_GLASS_ROOT + "/tab_selected.png"
const CG_TAB_IDLE := COMMAND_GLASS_ROOT + "/tab_idle.png"
const CG_PROGRESS_TRACK := COMMAND_GLASS_ROOT + "/progress_track.png"
const CG_PROGRESS_BLUE := COMMAND_GLASS_ROOT + "/progress_fill_blue.png"
const CG_PROGRESS_AMBER := COMMAND_GLASS_ROOT + "/progress_fill_amber.png"
const CG_PROGRESS_RED := COMMAND_GLASS_ROOT + "/progress_fill_red.png"
const CG_ICON_TILE := COMMAND_GLASS_ROOT + "/icon_tile.png"

const TOP_HUD := &"top_hud"
const TOP_CARD := &"top_card"
const SIDE_PANEL := &"side_panel"
const DECK_PANEL := &"deck_panel"
const CARD := &"card"
const LIST_CARD := &"list_card"
const OPERATOR_CARD := &"operator_card"
const BUTTON := &"button"
const BUTTON_PRESSED := &"button_pressed"
const BUTTON_DISABLED := &"button_disabled"
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
# and content values are the measured text-safe pixels after bevel/glow areas.
const SPECS := {
	TOP_HUD: {
		"path": CG_PANEL_TOP_HUD,
		"native": Vector2(1207.0, 246.0),
		"slice": Vector4(34.0, 34.0, 34.0, 34.0),
		"content": ZERO_INSETS,
	},
	TOP_CARD: {
		"path": CG_CARD_SMALL_LIGHT,
		"native": Vector2(193.0, 195.0),
		"slice": Vector4(24.0, 24.0, 24.0, 24.0),
		"content": Vector4(18.0, 16.0, 18.0, 10.0),
	},
	SIDE_PANEL: {
		"path": CG_PANEL_DETAIL,
		"native": Vector2(424.0, 464.0),
		"slice": Vector4(34.0, 34.0, 34.0, 34.0),
		"content": Vector4(18.0, 16.0, 18.0, 16.0),
	},
	DECK_PANEL: {
		"path": CG_PANEL_TOP_HUD,
		"native": Vector2(1207.0, 246.0),
		"slice": Vector4(34.0, 34.0, 34.0, 34.0),
		"content": Vector4(18.0, 16.0, 18.0, 16.0),
	},
	CARD: {
		"path": CG_CARD_LIGHT,
		"native": Vector2(363.0, 191.0),
		"slice": Vector4(26.0, 26.0, 26.0, 26.0),
		"content": Vector4(16.0, 12.0, 16.0, 12.0),
	},
	LIST_CARD: {
		"path": CG_CARD_LIGHT,
		"native": Vector2(363.0, 191.0),
		"slice": Vector4(26.0, 26.0, 26.0, 26.0),
		"content": Vector4(16.0, 12.0, 16.0, 12.0),
	},
	OPERATOR_CARD: {
		"path": CG_PANEL_OPERATOR,
		"native": Vector2(213.0, 257.0),
		"slice": Vector4(28.0, 28.0, 28.0, 28.0),
		"content": Vector4(14.0, 12.0, 14.0, 12.0),
	},
	BUTTON: {
		"path": CG_BUTTON_NORMAL,
		"native": Vector2(272.0, 101.0),
		"slice": Vector4(22.0, 22.0, 22.0, 22.0),
		"content": Vector4(10.0, 6.0, 10.0, 6.0),
	},
	BUTTON_PRESSED: {
		"path": CG_BUTTON_PRESSED,
		"native": Vector2(274.0, 102.0),
		"slice": Vector4(22.0, 22.0, 22.0, 22.0),
		"content": Vector4(10.0, 6.0, 10.0, 6.0),
	},
	BUTTON_DISABLED: {
		"path": CG_BUTTON_DISABLED,
		"native": Vector2(258.0, 103.0),
		"slice": Vector4(22.0, 22.0, 22.0, 22.0),
		"content": Vector4(10.0, 6.0, 10.0, 6.0),
	},
	TAB: {
		"path": CG_TAB_IDLE,
		"native": Vector2(286.0, 101.0),
		"slice": Vector4(24.0, 24.0, 24.0, 24.0),
		"content": Vector4(14.0, 10.0, 14.0, 7.0),
	},
	TAB_SELECTED: {
		"path": CG_TAB_SELECTED,
		"native": Vector2(300.0, 101.0),
		"slice": Vector4(24.0, 24.0, 24.0, 24.0),
		"content": Vector4(14.0, 10.0, 14.0, 7.0),
	},
	ICON_TILE: {
		"path": CG_ICON_TILE,
		"native": Vector2(103.0, 98.0),
		"slice": Vector4(20.0, 20.0, 20.0, 20.0),
		"content": Vector4(8.0, 8.0, 8.0, 8.0),
	},
	PROGRESS_TRACK: {
		"path": CG_PROGRESS_TRACK,
		"native": Vector2(533.0, 49.0),
		"slice": Vector4(16.0, 16.0, 16.0, 16.0),
		"content": ZERO_INSETS,
	},
	PROGRESS_BLUE: {
		"path": CG_PROGRESS_BLUE,
		"native": Vector2(533.0, 52.0),
		"slice": Vector4(16.0, 16.0, 16.0, 16.0),
		"content": ZERO_INSETS,
	},
	PROGRESS_AMBER: {
		"path": CG_PROGRESS_AMBER,
		"native": Vector2(533.0, 52.0),
		"slice": Vector4(16.0, 16.0, 16.0, 16.0),
		"content": ZERO_INSETS,
	},
	PROGRESS_RED: {
		"path": CG_PROGRESS_RED,
		"native": Vector2(533.0, 52.0),
		"slice": Vector4(16.0, 16.0, 16.0, 16.0),
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
