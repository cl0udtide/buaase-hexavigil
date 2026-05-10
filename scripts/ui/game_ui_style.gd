class_name GameUiStyle
extends RefCounted

const UiFrameSpec = preload("res://scripts/ui/ui_frame_spec.gd")
const FRAME_TOP_HUD := UiFrameSpec.TOP_HUD
const FRAME_TOP_CARD := UiFrameSpec.TOP_CARD
const FRAME_SIDE_PANEL := UiFrameSpec.SIDE_PANEL
const FRAME_DECK_PANEL := UiFrameSpec.DECK_PANEL
const FRAME_CARD := UiFrameSpec.CARD
const FRAME_LIST_CARD := UiFrameSpec.LIST_CARD
const FRAME_OPERATOR_CARD := UiFrameSpec.OPERATOR_CARD
const FRAME_BUTTON := UiFrameSpec.BUTTON
const FRAME_TAB := UiFrameSpec.TAB
const FRAME_ICON_TILE := UiFrameSpec.ICON_TILE


const BG := Color(0.965, 0.980, 0.988, 1.0)
const BG_DARK := Color(0.982, 0.989, 0.995, 1.0)
const BG_GLASS := Color(1.000, 1.000, 1.000, 0.96)
const BG_CARD := Color(1.000, 1.000, 1.000, 0.98)
const BG_CARD_HOVER := Color(0.938, 0.970, 0.992, 1.0)
const BG_DISABLED := Color(0.922, 0.941, 0.955, 0.96)
const STROKE := Color(0.715, 0.776, 0.835, 1.0)
const STROKE_SOFT := Color(0.820, 0.867, 0.910, 1.0)
const STROKE_STRONG := Color(0.160, 0.405, 0.870, 1.0)
const ACCENT := Color(0.145, 0.388, 0.920, 1.0)
const AMBER := Color(0.915, 0.520, 0.075, 1.0)
const DANGER := Color(0.850, 0.145, 0.145, 1.0)
const SUCCESS := Color(0.090, 0.610, 0.360, 1.0)
const VIOLET := Color(0.450, 0.255, 0.820, 1.0)
const STEEL := Color(0.395, 0.465, 0.565, 1.0)
const TEXT := Color(0.075, 0.110, 0.175, 1.0)
const TEXT_DIM := Color(0.285, 0.365, 0.460, 1.0)
const TEXT_MUTED := Color(0.555, 0.630, 0.705, 1.0)
const TEXT_INVERTED := Color(0.925, 0.965, 1.000, 1.0)
const TEXT_INVERTED_DIM := Color(0.660, 0.760, 0.865, 1.0)
const TEXT_SHADOW := Color(1.0, 1.0, 1.0, 0.0)

const ACCENT_SOFT := Color(0.895, 0.935, 1.000, 1.0)
const AMBER_SOFT := Color(1.000, 0.948, 0.835, 1.0)
const DANGER_SOFT := Color(1.000, 0.905, 0.905, 1.0)
const SUCCESS_SOFT := Color(0.885, 0.965, 0.925, 1.0)
const VIOLET_SOFT := Color(0.940, 0.920, 1.000, 1.0)

const HOLOGRAM_ROOT := "res://assets/UI/1. Free Hologram Interface Wenrexa"
const HOLOGRAM_BUTTON_NORMAL := HOLOGRAM_ROOT + "/Button 1/Button Normal.png"
const HOLOGRAM_BUTTON_HOVER := HOLOGRAM_ROOT + "/Button 1/Button Hover.png"
const HOLOGRAM_BUTTON_PRESSED := HOLOGRAM_ROOT + "/Button 1/Button Active.png"
const HOLOGRAM_BUTTON_DISABLED := HOLOGRAM_ROOT + "/Button 1/Button Disable.png"
const HOLOGRAM_CARD := HOLOGRAM_ROOT + "/Card X1/Card X1.png"
const HOLOGRAM_CARD_WIDE := HOLOGRAM_ROOT + "/Card X1/Card X2.png"
const HOLOGRAM_PANEL_EMPTY := HOLOGRAM_ROOT + "/Card X1/Panel Empty.png"
const HOLOGRAM_PANEL_GREEN := HOLOGRAM_ROOT + "/Card X1/Panel Empty Green.png"
const HOLOGRAM_PANEL_RED := HOLOGRAM_ROOT + "/Card X1/Panel Red.png"

const MIKO_ROOT := "res://assets/UI/Wenrexa Assets GUI Dark Miko"
const MIKO_PANEL_GRAY := MIKO_ROOT + "/Panels Gray/Panel 10.png"
const MIKO_PANEL_GREEN := MIKO_ROOT + "/Panels Green/Panel 10.png"
const MIKO_BUTTON_NORMAL := MIKO_ROOT + "/Standart Button V1/Standart Button Normal/Standart Button Normal 1.png"
const MIKO_BUTTON_HOVER := MIKO_ROOT + "/Standart Button V1/Standart Button Hover/Standart Button Hover 1.png"
const MIKO_BUTTON_PRESSED := MIKO_ROOT + "/Standart Button V1/Standart Button Active/Standart Button Active 1.png"
const MIKO_BUTTON_DISABLED := MIKO_ROOT + "/Standart Button V1/Standart Button Disable/Standart Button Disable 1.png"
const MIKO_PROGRESS_BLUE_BG := MIKO_ROOT + "/ProgressBar Blue/V4/Background Static.png"
const MIKO_PROGRESS_BLUE_FILL := MIKO_ROOT + "/ProgressBar Blue/V4/Foreground.png"
const MIKO_PROGRESS_GREEN_FILL := MIKO_ROOT + "/ProgressBar Green/V4/Foreground.png"
const MIKO_PROGRESS_RED_FILL := MIKO_ROOT + "/ProgressBar Red/V4/Foreground.png"

const COMMAND_GLASS_ROOT := "res://assets/UI/CommandGlass"
const CG_PANEL_TOP_HUD := COMMAND_GLASS_ROOT + "/panel_top_hud.png"
const CG_PANEL_DETAIL := COMMAND_GLASS_ROOT + "/panel_detail.png"
const CG_PANEL_WIDE_LIGHT := COMMAND_GLASS_ROOT + "/panel_wide_light.png"
const CG_PANEL_OPERATOR := COMMAND_GLASS_ROOT + "/panel_operator.png"
const CG_CARD_LIGHT := COMMAND_GLASS_ROOT + "/card_light.png"
const CG_CARD_SMALL_LIGHT := COMMAND_GLASS_ROOT + "/card_small_light.png"
const CG_BUTTON_NORMAL := COMMAND_GLASS_ROOT + "/button_normal.png"
const CG_BUTTON_HOVER := COMMAND_GLASS_ROOT + "/button_hover.png"
const CG_BUTTON_PRESSED := COMMAND_GLASS_ROOT + "/button_pressed.png"
const CG_BUTTON_DISABLED := COMMAND_GLASS_ROOT + "/button_disabled.png"
const CG_TAB_SELECTED := COMMAND_GLASS_ROOT + "/tab_selected.png"
const CG_TAB_IDLE := COMMAND_GLASS_ROOT + "/tab_idle.png"
const CG_PROGRESS_TRACK := COMMAND_GLASS_ROOT + "/progress_track.png"
const CG_PROGRESS_BLUE := COMMAND_GLASS_ROOT + "/progress_fill_blue.png"
const CG_PROGRESS_AMBER := COMMAND_GLASS_ROOT + "/progress_fill_amber.png"
const CG_PROGRESS_RED := COMMAND_GLASS_ROOT + "/progress_fill_red.png"
const CG_ICON_TILE := COMMAND_GLASS_ROOT + "/icon_tile.png"


static func texture_box(path: String, fallback_fill: Color, fallback_border: Color, margin: float = 16.0) -> StyleBox:
	var texture := load(path) as Texture2D
	if texture == null:
		return flat_panel(fallback_fill, fallback_border, 1.0, minf(maxf(margin * 0.35, 5.0), 8.0))

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin(SIDE_LEFT, margin)
	style.set_texture_margin(SIDE_TOP, margin)
	style.set_texture_margin(SIDE_RIGHT, margin)
	style.set_texture_margin(SIDE_BOTTOM, margin)
	style.content_margin_left = 12.0
	style.content_margin_top = 9.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 9.0
	return style


static func frame_box(component: StringName, fallback_fill: Color, fallback_border: Color, include_content := true) -> StyleBox:
	return UiFrameSpec.style_box(component, fallback_fill, fallback_border, include_content)


static func apply_frame_margin(container: MarginContainer, component: StringName, extra := Vector4.ZERO) -> void:
	UiFrameSpec.apply_margin(container, component, extra)


static func frame_insets(component: StringName) -> Vector4:
	return UiFrameSpec.content_insets(component)


static func center_button_text(button: Button) -> void:
	if button == null:
		return
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER


static func center_label_text(label: Label) -> void:
	if label == null:
		return
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func hologram_texture_box(path: String, fallback_fill: Color, fallback_border: Color, margin: float = 22.0) -> StyleBox:
	var style := texture_box(path, fallback_fill, fallback_border, margin)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


static func flat_panel(fill: Color, border: Color, border_width: float = 1.0, radius: float = 6.0) -> StyleBoxFlat:
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
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0.120, 0.180, 0.260, 0.10)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


static func panel(fill: Color, border: Color, border_width: float = 1.0, radius: float = 6.0) -> StyleBox:
	var component := UiFrameSpec.TOP_CARD
	if border == AMBER:
		component = UiFrameSpec.CARD
	elif border == DANGER:
		component = UiFrameSpec.OPERATOR_CARD
	return frame_box(component, fill, border)


static func flat_box(fill: Color, border: Color, border_width: float = 1.0, radius: float = 6.0) -> StyleBoxFlat:
	var style := flat_panel(fill, border, border_width, radius)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.shadow_color = Color.TRANSPARENT
	return style


static func button(border: Color, fill_alpha: float = 0.18) -> StyleBox:
	var component := UiFrameSpec.BUTTON
	if border == ACCENT or border == STROKE_STRONG or border == SUCCESS:
		component = UiFrameSpec.TAB_SELECTED
	elif border == AMBER:
		component = UiFrameSpec.BUTTON_PRESSED
	elif fill_alpha <= 0.10 or border == STROKE_SOFT:
		component = UiFrameSpec.BUTTON_DISABLED if fill_alpha <= 0.10 else UiFrameSpec.BUTTON
	return frame_box(component, BG_CARD, border)


static func card(border: Color, fill: Color = BG_CARD, border_width: float = 1.0) -> StyleBox:
	var component := UiFrameSpec.CARD
	if fill == BG_GLASS or fill == BG_DARK:
		component = UiFrameSpec.SIDE_PANEL
	elif border == AMBER:
		component = UiFrameSpec.CARD
	elif border == DANGER:
		component = UiFrameSpec.OPERATOR_CARD
	return frame_box(component, fill, border)


static func top_card() -> StyleBox:
	return frame_box(UiFrameSpec.TOP_CARD, BG_GLASS, STROKE_SOFT)


static func top_hud_panel() -> StyleBox:
	return frame_box(UiFrameSpec.TOP_HUD, BG_GLASS, STROKE_SOFT)


static func side_panel() -> StyleBox:
	return frame_box(UiFrameSpec.SIDE_PANEL, BG_GLASS, STROKE_SOFT, false)


static func deck_panel() -> StyleBox:
	return frame_box(UiFrameSpec.DECK_PANEL, BG_GLASS, STROKE_SOFT, false)


static func operator_card(border: Color = ACCENT) -> StyleBox:
	return frame_box(UiFrameSpec.OPERATOR_CARD, BG_CARD, border, false)


static func list_card(selected: bool = false) -> StyleBox:
	return frame_box(UiFrameSpec.LIST_CARD, BG_CARD, AMBER if selected else STROKE_SOFT, false)


static func icon_tile() -> StyleBox:
	return frame_box(UiFrameSpec.ICON_TILE, ACCENT_SOFT, STROKE_SOFT)


static func tab(selected: bool) -> StyleBox:
	var component := UiFrameSpec.TAB_SELECTED if selected else UiFrameSpec.TAB
	return frame_box(component, ACCENT_SOFT if selected else BG_CARD, ACCENT if selected else STROKE_SOFT)


static func accent_button(accent: Color) -> StyleBox:
	return button(accent, 0.26)


static func disabled_button() -> StyleBox:
	return button(STROKE_SOFT, 0.08)


static func miko_button(state: StringName = &"normal") -> StyleBox:
	var path := MIKO_BUTTON_NORMAL
	if state == &"hover":
		path = MIKO_BUTTON_HOVER
	elif state == &"pressed":
		path = MIKO_BUTTON_PRESSED
	elif state == &"disabled":
		path = MIKO_BUTTON_DISABLED
	return texture_box(path, BG_CARD, STROKE_SOFT, 12.0)


static func miko_panel(highlighted: bool = false) -> StyleBox:
	var path := MIKO_PANEL_GREEN if highlighted else MIKO_PANEL_GRAY
	return texture_box(path, BG_CARD, SUCCESS if highlighted else STROKE_SOFT, 18.0)


static func progress_background() -> StyleBox:
	return frame_box(UiFrameSpec.PROGRESS_TRACK, Color(0.900, 0.925, 0.945, 1.0), Color(0.900, 0.925, 0.945, 1.0))


static func progress_fill(color: Color) -> StyleBox:
	var component := UiFrameSpec.PROGRESS_BLUE
	if color.r > color.b and color.r > color.g:
		component = UiFrameSpec.PROGRESS_RED
	elif color.g > color.b or color == AMBER:
		component = UiFrameSpec.PROGRESS_AMBER
	return frame_box(component, color, color)
