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


const BG := Color(0.070, 0.090, 0.095, 1.0)
const BG_DARK := Color(0.040, 0.050, 0.055, 1.0)
const BG_GLASS := Color(0.105, 0.135, 0.145, 0.96)
const BG_CARD := Color(0.120, 0.165, 0.170, 0.98)
const BG_CARD_HOVER := Color(0.205, 0.345, 0.325, 1.0)
const BG_DISABLED := Color(0.215, 0.215, 0.205, 0.96)
const STROKE := Color(0.555, 0.555, 0.480, 1.0)
const STROKE_SOFT := Color(0.415, 0.440, 0.405, 1.0)
const STROKE_STRONG := Color(0.780, 0.675, 0.420, 1.0)
const ACCENT := Color(0.250, 0.615, 0.555, 1.0)
const AMBER := Color(0.875, 0.570, 0.155, 1.0)
const DANGER := Color(0.760, 0.145, 0.130, 1.0)
const SUCCESS := Color(0.250, 0.610, 0.385, 1.0)
const VIOLET := Color(0.445, 0.300, 0.645, 1.0)
const STEEL := Color(0.480, 0.500, 0.470, 1.0)
const TEXT := Color(0.910, 0.875, 0.760, 1.0)
const TEXT_DIM := Color(0.705, 0.700, 0.620, 1.0)
const TEXT_MUTED := Color(0.500, 0.520, 0.485, 1.0)
const TEXT_INVERTED := Color(0.965, 0.920, 0.775, 1.0)
const TEXT_INVERTED_DIM := Color(0.760, 0.760, 0.670, 1.0)
const TEXT_ON_PARCHMENT := Color(0.190, 0.145, 0.090, 1.0)
const TEXT_SHADOW := Color(0.025, 0.020, 0.015, 0.65)

const ACCENT_SOFT := Color(0.175, 0.330, 0.310, 1.0)
const AMBER_SOFT := Color(0.365, 0.260, 0.120, 1.0)
const DANGER_SOFT := Color(0.355, 0.120, 0.110, 1.0)
const SUCCESS_SOFT := Color(0.145, 0.285, 0.190, 1.0)
const VIOLET_SOFT := Color(0.225, 0.170, 0.315, 1.0)

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
		component = UiFrameSpec.BUTTON_HOVER
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


static func action_bar_panel() -> StyleBox:
	return frame_box(UiFrameSpec.DECK_PANEL, BG_GLASS, STROKE_SOFT, false)


static func compact_panel(border: Color = STROKE_SOFT, fill: Color = BG_GLASS, include_content := false) -> StyleBox:
	return frame_box(UiFrameSpec.CARD, fill, border, include_content)


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


static func progress_background() -> StyleBox:
	return frame_box(UiFrameSpec.PROGRESS_TRACK, Color(0.075, 0.095, 0.095, 1.0), Color(0.260, 0.280, 0.245, 1.0))


static func progress_fill(color: Color) -> StyleBox:
	var component := UiFrameSpec.PROGRESS_BLUE
	if color.r > color.b and color.r > color.g:
		component = UiFrameSpec.PROGRESS_RED
	elif color.g > color.b or color == AMBER:
		component = UiFrameSpec.PROGRESS_AMBER
	return frame_box(component, color, color)
