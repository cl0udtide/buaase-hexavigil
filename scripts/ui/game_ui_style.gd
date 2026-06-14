class_name GameUiStyle
extends RefCounted

const UiFrameSpec = preload("res://scripts/ui/ui_frame_spec.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const FRAME_TOP_CARD := UiFrameSpec.TOP_CARD
const FRAME_HUD_CELL := UiFrameSpec.HUD_CELL
const FRAME_SIDE_PANEL := UiFrameSpec.SIDE_PANEL
const FRAME_RIGHT_DETAIL_SIDEBAR := UiFrameSpec.RIGHT_DETAIL_SIDEBAR
const FRAME_BUILD_SIDE_PANEL := UiFrameSpec.BUILD_SIDE_PANEL
const FRAME_DECK_PANEL := UiFrameSpec.DECK_PANEL
const FRAME_DETAIL_SECTION := UiFrameSpec.DETAIL_SECTION
const FRAME_CARD := UiFrameSpec.CARD
const FRAME_LIST_CARD := UiFrameSpec.LIST_CARD
const FRAME_OPERATOR_CARD := UiFrameSpec.OPERATOR_CARD
const FRAME_OPERATOR_PORTRAIT_SLOT := UiFrameSpec.OPERATOR_PORTRAIT_SLOT
const FRAME_OPERATOR_PORTRAIT_BACKPLATE := UiFrameSpec.OPERATOR_PORTRAIT_BACKPLATE
const FRAME_OPERATOR_PORTRAIT_FRAME := UiFrameSpec.OPERATOR_PORTRAIT_FRAME
const FRAME_OPERATOR_TITLE_STRIP := UiFrameSpec.OPERATOR_TITLE_STRIP
const FRAME_OPERATOR_COST_BADGE := UiFrameSpec.OPERATOR_COST_BADGE
const FRAME_OPERATOR_STAT_ROW := UiFrameSpec.OPERATOR_STAT_ROW
const FRAME_BUTTON := UiFrameSpec.BUTTON
const FRAME_TAB := UiFrameSpec.TAB
const FRAME_BUILD_ICON_BACKPLATE := UiFrameSpec.BUILD_ICON_BACKPLATE
const FRAME_BUILD_ICON_FRAME := UiFrameSpec.BUILD_ICON_FRAME
const FRAME_COST_BADGE := UiFrameSpec.COST_BADGE
const FRAME_RELIC_STRIP := UiFrameSpec.RELIC_STRIP
const FRAME_RELIC_ICON := UiFrameSpec.RELIC_ICON
const FRAME_RELIC_PANEL := UiFrameSpec.RELIC_PANEL
const FRAME_RELIC_CARD := UiFrameSpec.RELIC_CARD
const FRAME_SETTINGS_PANEL := UiFrameSpec.SETTINGS_PANEL
const FRAME_BLESSING_PANEL := UiFrameSpec.BLESSING_PANEL
const FRAME_LEGEND_PANEL := UiFrameSpec.LEGEND_PANEL
const FRAME_ACTION_BUTTON := UiFrameSpec.ACTION_BUTTON
const FRAME_MAP_POPUP := UiFrameSpec.MAP_POPUP
const FRAME_EVENT_PANEL := UiFrameSpec.EVENT_PANEL
const FRAME_EVENT_CHOICE_BUTTON := UiFrameSpec.EVENT_CHOICE_BUTTON
const FRAME_DIALOG_BOX := UiFrameSpec.DIALOG_BOX
const FRAME_DIALOG_SPEAKER := UiFrameSpec.DIALOG_SPEAKER
const FRAME_RESULT_PANEL := UiFrameSpec.RESULT_PANEL
const FRAME_WAVE_PREVIEW := UiFrameSpec.WAVE_PREVIEW
const FRAME_WAVE_ROUTE_TOGGLE := UiFrameSpec.WAVE_ROUTE_TOGGLE
const FRAME_SKILL_ICON_BACKPLATE := UiFrameSpec.SKILL_ICON_BACKPLATE
const FRAME_SKILL_ICON_FRAME := UiFrameSpec.SKILL_ICON_FRAME
const FRAME_SKILL_DESC_BOX := UiFrameSpec.SKILL_DESC_BOX
const FRAME_UNIT_HEADER_STRIP := UiFrameSpec.UNIT_HEADER_STRIP
const FRAME_UNIT_PORTRAIT_BACKPLATE := UiFrameSpec.UNIT_PORTRAIT_BACKPLATE
const FRAME_UNIT_PORTRAIT_FRAME := UiFrameSpec.UNIT_PORTRAIT_FRAME
const FRAME_UNIT_STAT_ROW := UiFrameSpec.UNIT_STAT_ROW
const FRAME_RESOURCE_ITEM := UiFrameSpec.RESOURCE_ITEM
const FRAME_RESOURCE_DELTA_BADGE := UiFrameSpec.RESOURCE_DELTA_BADGE
const FRAME_TOOLTIP := UiFrameSpec.TOOLTIP
const FRAME_SPEED_TOGGLE := UiFrameSpec.SPEED_TOGGLE
const FRAME_SPEED_TOGGLE_ACTIVE := UiFrameSpec.SPEED_TOGGLE_ACTIVE
const FRAME_SCROLL_TRACK := UiFrameSpec.SCROLL_TRACK
const FRAME_SCROLL_THUMB := UiFrameSpec.SCROLL_THUMB
const FRAME_SCROLL_TRACK_HORIZONTAL := UiFrameSpec.SCROLL_TRACK_HORIZONTAL
const FRAME_SCROLL_THUMB_HORIZONTAL := UiFrameSpec.SCROLL_THUMB_HORIZONTAL
const FRAME_SLIDER_TRACK := UiFrameSpec.SLIDER_TRACK
const FRAME_SLIDER_FILL := UiFrameSpec.SLIDER_FILL
const FRAME_SLIDER_HANDLE := UiFrameSpec.SLIDER_HANDLE


const BG := Color(0.035, 0.045, 0.052, 1.0)
const BG_DARK := Color(0.015, 0.020, 0.026, 1.0)
const BG_GLASS := Color(0.045, 0.060, 0.068, 0.94)
const BG_CARD := Color(0.065, 0.080, 0.088, 0.96)
const BG_CARD_HOVER := Color(0.095, 0.140, 0.155, 0.98)
const BG_DISABLED := Color(0.055, 0.060, 0.064, 0.82)
const STROKE := Color(0.300, 0.365, 0.385, 1.0)
const STROKE_SOFT := Color(0.180, 0.230, 0.245, 1.0)
const STROKE_STRONG := Color(0.760, 0.530, 0.180, 1.0)
const ACCENT := Color(0.260, 0.760, 0.920, 1.0)
const AMBER := Color(0.950, 0.650, 0.220, 1.0)

## 出怪口主题色：按编号钉死（S1→橙、S4→青…），地图覆盖/徽标与右栏段头共用，跨视图同色。
const ROUTE_PREVIEW_COLORS: Array[Color] = [
	Color(1.0, 0.54, 0.20),
	Color(0.20, 0.78, 1.0),
	Color(0.86, 0.62, 1.0),
	Color(0.38, 0.95, 0.58),
	Color(1.0, 0.84, 0.24),
]
const DANGER := Color(0.860, 0.230, 0.185, 1.0)
const SUCCESS := Color(0.290, 0.700, 0.430, 1.0)
const VIOLET := Color(0.500, 0.420, 0.760, 1.0)
const STEEL := Color(0.500, 0.570, 0.600, 1.0)
const TEXT := Color(0.900, 0.940, 0.960, 1.0)
const TEXT_DIM := Color(0.620, 0.700, 0.735, 1.0)
const TEXT_MUTED := Color(0.390, 0.460, 0.490, 1.0)
const TEXT_INVERTED := Color(0.930, 0.970, 0.990, 1.0)
const TEXT_INVERTED_DIM := Color(0.620, 0.710, 0.760, 1.0)
const TEXT_ON_PARCHMENT := Color(0.930, 0.970, 0.990, 1.0)
const TEXT_SHADOW := Color(0.000, 0.000, 0.000, 0.65)

const ACCENT_SOFT := Color(0.070, 0.175, 0.210, 1.0)
const AMBER_SOFT := Color(0.235, 0.160, 0.060, 1.0)
const DANGER_SOFT := Color(0.220, 0.070, 0.060, 1.0)
const SUCCESS_SOFT := Color(0.070, 0.170, 0.105, 1.0)
const VIOLET_SOFT := Color(0.120, 0.105, 0.190, 1.0)
const BUTTON_ICON_MAX_WIDTH := 18
const BUTTON_ICON_MAX_WIDTH_COMPACT := 14
const TOOLTIP_STYLE_PATH := "res://assets/ui/styles/frame_tooltip_base.tres"

static func texture_box(_path: String, fallback_fill: Color, fallback_border: Color, margin: float = 16.0) -> StyleBox:
	return flat_panel(fallback_fill, fallback_border, 1.0, minf(maxf(margin * 0.35, 5.0), 8.0))


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


static func set_button_texture_icon(button: Button, texture: Texture2D, placement: StringName = &"left", padding: float = 8.0) -> TextureRect:
	if button == null:
		return null
	var icon_max_width := _button_icon_max_width(button, placement)
	button.add_theme_constant_override("icon_max_width", icon_max_width)
	button.set("expand_icon", true)
	var fitted_icon := button.get_node_or_null("FittedIcon") as TextureRect
	if placement == &"overlay_center":
		button.icon = null
		if fitted_icon == null:
			fitted_icon = TextureRect.new()
			fitted_icon.name = "FittedIcon"
			fitted_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fitted_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			fitted_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			button.add_child(fitted_icon)
		fit_centered_icon(fitted_icon, Vector2(icon_max_width, icon_max_width))
		fitted_icon.texture = texture
		fitted_icon.visible = texture != null
		return fitted_icon
	if fitted_icon != null:
		fitted_icon.visible = false
	button.icon = texture
	button.add_theme_constant_override("h_separation", int(maxf(4.0, padding * 0.5)))
	button.set("icon_alignment", HORIZONTAL_ALIGNMENT_CENTER if placement == &"center" else HORIZONTAL_ALIGNMENT_LEFT)
	return null


static func _button_icon_max_width(button: Button, placement: StringName) -> int:
	var height := button.custom_minimum_size.y
	if height <= 0.0:
		height = button.size.y
	if height > 0.0:
		return int(clampf(floorf(height * 0.58), BUTTON_ICON_MAX_WIDTH_COMPACT, 24.0))
	return BUTTON_ICON_MAX_WIDTH_COMPACT if placement == &"center" else BUTTON_ICON_MAX_WIDTH


static func fit_centered_icon(control: Control, icon_size: Vector2) -> void:
	if control == null:
		return
	control.set_custom_minimum_size(Vector2.ZERO)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -icon_size.x * 0.5
	control.offset_top = -icon_size.y * 0.5
	control.offset_right = icon_size.x * 0.5
	control.offset_bottom = icon_size.y * 0.5


## 按出怪口编号取主题色：S1→0号(橙)、S4→3号(青)，跨局稳定；解析不出编号则退字符串哈希。
## 颜色钉在 spawn_key 上（而非路线 index），避免地图(字母序)与右栏(首见序)排序不同导致串色。
static func route_color_for_spawn_key(spawn_key: String) -> Color:
	var digits := ""
	for ch in spawn_key:
		if ch >= "0" and ch <= "9":
			digits += ch
	var n := (digits.to_int() - 1) if not digits.is_empty() else absi(spawn_key.hash())
	if n < 0:
		n = absi(spawn_key.hash())
	return ROUTE_PREVIEW_COLORS[n % ROUTE_PREVIEW_COLORS.size()]


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
	style.set("shadow_size", 8)
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
	style.set("shadow_size", 0)
	style.shadow_offset = Vector2.ZERO
	style.shadow_color = Color.TRANSPARENT
	return style


static func button(border: Color, fill_alpha: float = 0.18) -> StyleBox:
	var fill := BG_DISABLED if fill_alpha <= 0.10 else BG_CARD
	return frame_box(UiFrameSpec.BUTTON, fill, border)


static func apply_button_state_styles(button: Button, variant: StringName = &"primary") -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", frame_box(UiFrameSpec.BUTTON, BG_CARD, STROKE_SOFT))
	button.add_theme_stylebox_override("hover", frame_box(UiFrameSpec.BUTTON, BG_CARD, ACCENT if variant != &"danger" else DANGER))
	button.add_theme_stylebox_override("pressed", frame_box(UiFrameSpec.BUTTON, BG_CARD, AMBER if variant != &"danger" else DANGER))
	button.add_theme_stylebox_override("disabled", frame_box(UiFrameSpec.BUTTON, BG_DISABLED, STROKE_SOFT))


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
	return hud_cell(false)


static func hud_cell(selected: bool = false) -> StyleBox:
	if selected:
		return flat_box(BG_CARD_HOVER, AMBER, 1.0, 6.0)
	return frame_box(UiFrameSpec.HUD_CELL, BG_CARD, STROKE_SOFT)


static func side_panel() -> StyleBox:
	return frame_box(UiFrameSpec.SIDE_PANEL, BG_GLASS, STROKE_SOFT, false)


static func build_side_panel() -> StyleBox:
	return frame_box(UiFrameSpec.BUILD_SIDE_PANEL, BG_GLASS, STROKE_SOFT, false)


static func right_detail_sidebar() -> StyleBox:
	return frame_box(UiFrameSpec.RIGHT_DETAIL_SIDEBAR, BG_GLASS, STROKE_SOFT, false)


static func deck_panel() -> StyleBox:
	return frame_box(UiFrameSpec.DECK_PANEL, BG_GLASS, STROKE_SOFT, false)


static func compact_panel(border: Color = STROKE_SOFT, fill: Color = BG_GLASS, include_content := false) -> StyleBox:
	return frame_box(UiFrameSpec.CARD, fill, border, include_content)


static func operator_card(border: Color = ACCENT) -> StyleBox:
	return frame_box(UiFrameSpec.OPERATOR_CARD, BG_CARD, border, false)


static func operator_card_state(state: StringName, selected: bool = false) -> StyleBox:
	var component := UiFrameSpec.OPERATOR_CARD
	var border := ACCENT
	var fill := BG_CARD
	if selected:
		component = UiFrameSpec.OPERATOR_CARD_SELECTED
		border = AMBER
		fill = BG_CARD_HOVER
	elif state == &"deployed":
		component = UiFrameSpec.OPERATOR_CARD_DEPLOYED
		border = SUCCESS
	elif state == &"cooldown":
		component = UiFrameSpec.OPERATOR_CARD_COOLDOWN
		border = DANGER
		fill = BG_DISABLED
	return frame_box(component, fill, border, false)


static func operator_portrait_slot() -> StyleBox:
	return frame_box(UiFrameSpec.OPERATOR_PORTRAIT_BACKPLATE, ACCENT_SOFT, STROKE_SOFT)


static func operator_portrait_frame() -> StyleBox:
	return frame_box(UiFrameSpec.OPERATOR_PORTRAIT_FRAME, Color.TRANSPARENT, STROKE_SOFT, false)


static func operator_title_strip() -> StyleBox:
	return frame_box(UiFrameSpec.OPERATOR_TITLE_STRIP, BG_DARK, STROKE_SOFT, false)


static func operator_cost_badge() -> StyleBox:
	return frame_box(UiFrameSpec.OPERATOR_COST_BADGE, AMBER_SOFT, AMBER)


static func operator_stat_row() -> StyleBox:
	return frame_box(UiFrameSpec.OPERATOR_STAT_ROW, BG_DARK, STROKE_SOFT)


static func list_card(selected: bool = false) -> StyleBox:
	return frame_box(UiFrameSpec.LIST_CARD, BG_CARD, AMBER if selected else STROKE_SOFT, false)


static func build_icon_backplate() -> StyleBox:
	return frame_box(UiFrameSpec.BUILD_ICON_BACKPLATE, ACCENT_SOFT, STROKE_SOFT)


static func build_icon_frame(accent: Color = STROKE_SOFT) -> StyleBox:
	return frame_box(UiFrameSpec.BUILD_ICON_FRAME, Color.TRANSPARENT, accent, false)


static func cost_badge() -> StyleBox:
	return frame_box(UiFrameSpec.COST_BADGE, AMBER_SOFT, AMBER)


static func relic_strip() -> StyleBox:
	return frame_box(UiFrameSpec.RELIC_STRIP, Color(0.036, 0.050, 0.058, 0.86), STROKE_SOFT, false)


static func relic_icon(rarity: int = 1, highlighted: bool = false) -> StyleBox:
	var border := AMBER if highlighted else relic_rarity_color(rarity)
	var fill := Color(0.036, 0.050, 0.058, 0.90 if highlighted else 0.78)
	return frame_box(UiFrameSpec.RELIC_ICON, fill, border, false)


static func relic_icon_highlight_overlay() -> StyleBox:
	return frame_box(UiFrameSpec.RELIC_ICON, Color(0.950, 0.650, 0.220, 0.18), AMBER, false)


static func relic_icon_backplate() -> StyleBox:
	return frame_box(UiFrameSpec.RELIC_ICON_BACKPLATE, Color(0.026, 0.040, 0.046, 0.82), STROKE_SOFT)


static func relic_rarity_overlay(rarity: int = 1, selected: bool = false, compact := false) -> StyleBox:
	var rarity_color := relic_rarity_color(rarity)
	var alpha := 0.11
	if rarity == 2:
		alpha = 0.14
	elif rarity >= 3:
		alpha = 0.17
	if selected:
		alpha += 0.05
	if compact:
		alpha = maxf(alpha - 0.03, 0.08)
	return flat_box(Color(rarity_color.r, rarity_color.g, rarity_color.b, alpha), Color.TRANSPARENT, 0.0, 4.0)


static func relic_card_hover_overlay(selected: bool = false) -> StyleBox:
	var alpha := 0.26 if selected else 0.14
	var fill := Color(0.950, 0.650, 0.220, alpha)
	return flat_box(fill, AMBER, 1.0, 5.0)


static func relic_card(rarity: int = 1, selected: bool = false) -> StyleBox:
	var fill := Color(0.046, 0.060, 0.066, 0.86)
	if selected:
		fill = Color(0.064, 0.086, 0.092, 0.92)
	var border := AMBER if selected else STROKE_SOFT
	if _frame_texture_is_landscape(UiFrameSpec.RELIC_CARD):
		return frame_box(UiFrameSpec.RELIC_CARD, fill, border, false)
	return flat_box(fill, border, 1.0, 5.0)


static func relic_panel() -> StyleBox:
	return frame_box(UiFrameSpec.RELIC_PANEL, Color(0.034, 0.048, 0.056, 0.90), STROKE_SOFT, false)


static func relic_detail_section() -> StyleBox:
	return frame_box(UiFrameSpec.DETAIL_SECTION, Color(0.034, 0.048, 0.056, 0.82), STROKE_SOFT, false)


static func relic_filter_tab(selected: bool = false, hovered: bool = false) -> StyleBox:
	var fill := Color(0.048, 0.064, 0.070, 0.68)
	var border := STROKE_SOFT
	if selected:
		fill = Color(0.090, 0.085, 0.060, 0.78)
		border = AMBER
	elif hovered:
		fill = Color(0.062, 0.084, 0.092, 0.74)
	if hovered and selected:
		fill = Color(0.108, 0.098, 0.070, 0.84)
	return frame_box(UiFrameSpec.RELIC_FILTER_TAB, fill, border)


static func settings_panel() -> StyleBox:
	return frame_box(UiFrameSpec.SETTINGS_PANEL, BG_GLASS, ACCENT, false)


static func settings_row() -> StyleBox:
	return frame_box(UiFrameSpec.SETTINGS_ROW, BG_CARD, STROKE_SOFT, false)


static func settings_button() -> StyleBox:
	return frame_box(UiFrameSpec.SETTINGS_BUTTON, BG_CARD, STROKE_SOFT, false)


static func blessing_panel() -> StyleBox:
	return frame_box(UiFrameSpec.BLESSING_PANEL, BG_GLASS, STROKE_SOFT, false)


static func blessing_choice_card(selected: bool = false) -> StyleBox:
	return frame_box(UiFrameSpec.BLESSING_CHOICE_CARD, BG_CARD_HOVER if selected else BG_CARD, AMBER if selected else STROKE_SOFT, false)


static func legend_panel() -> StyleBox:
	return frame_box(UiFrameSpec.LEGEND_PANEL, BG_GLASS, STROKE_SOFT, false)


static func map_popup() -> StyleBox:
	return frame_box(UiFrameSpec.MAP_POPUP, BG_GLASS, STROKE_SOFT, false)


static func event_panel() -> StyleBox:
	return frame_box(UiFrameSpec.EVENT_PANEL, BG_GLASS, STROKE_STRONG, false)


static func event_choice_button() -> StyleBox:
	return frame_box(UiFrameSpec.EVENT_CHOICE_BUTTON, BG_CARD, ACCENT)


static func dialog_box() -> StyleBox:
	return frame_box(UiFrameSpec.DIALOG_BOX, BG_GLASS, STROKE_SOFT, false)


static func dialog_speaker_plate() -> StyleBox:
	return frame_box(UiFrameSpec.DIALOG_SPEAKER, ACCENT_SOFT, ACCENT)


static func result_panel() -> StyleBox:
	return frame_box(UiFrameSpec.RESULT_PANEL, BG_DARK, STROKE_STRONG, false)


static func wave_preview_panel() -> StyleBox:
	return frame_box(UiFrameSpec.WAVE_PREVIEW, BG_GLASS, ACCENT, false)


static func wave_route_toggle() -> StyleBox:
	return frame_box(UiFrameSpec.WAVE_ROUTE_TOGGLE, BG_CARD, STROKE_SOFT)


static func relic_rarity_color(rarity: int) -> Color:
	match rarity:
		3:
			return AMBER
		2:
			return ACCENT
		_:
			return SUCCESS


static func _frame_texture_is_landscape(component: StringName) -> bool:
	var texture := UiArtRegistry.get_frame_texture(component)
	return texture == null or texture.get_width() >= texture.get_height()


static func tab(selected: bool) -> StyleBox:
	var component := UiFrameSpec.TAB_SELECTED if selected else UiFrameSpec.TAB
	return frame_box(component, ACCENT_SOFT if selected else BG_CARD, ACCENT if selected else STROKE_SOFT)


static func compact_button(selected: bool = false) -> StyleBox:
	if selected:
		return frame_box(UiFrameSpec.BUTTON_COMPACT, BG_CARD, AMBER)
	return frame_box(UiFrameSpec.BUTTON_COMPACT, BG_CARD, STROKE_SOFT)


static func detail_section() -> StyleBox:
	return frame_box(UiFrameSpec.DETAIL_SECTION, BG_CARD, STROKE_SOFT, false)


static func unit_header_strip() -> StyleBox:
	return frame_box(UiFrameSpec.UNIT_HEADER_STRIP, BG_CARD, STROKE_SOFT, false)


static func unit_portrait_backplate() -> StyleBox:
	return frame_box(UiFrameSpec.UNIT_PORTRAIT_BACKPLATE, ACCENT_SOFT, STROKE_SOFT)


static func unit_portrait_frame() -> StyleBox:
	return frame_box(UiFrameSpec.UNIT_PORTRAIT_FRAME, Color.TRANSPARENT, STROKE_SOFT, false)


static func unit_stat_row() -> StyleBox:
	return frame_box(UiFrameSpec.UNIT_STAT_ROW, BG_DARK, STROKE_SOFT)


static func skill_icon_backplate() -> StyleBox:
	return frame_box(UiFrameSpec.SKILL_ICON_BACKPLATE, ACCENT_SOFT, STROKE_SOFT)


static func skill_icon_frame() -> StyleBox:
	return frame_box(UiFrameSpec.SKILL_ICON_FRAME, Color.TRANSPARENT, STROKE_SOFT, false)


static func skill_desc_box() -> StyleBox:
	return frame_box(UiFrameSpec.SKILL_DESC_BOX, BG_CARD, STROKE_SOFT, false)


static func accent_button(accent: Color) -> StyleBox:
	return button(accent, 0.26)


static func skill_button_primary() -> StyleBox:
	return frame_box(UiFrameSpec.BUTTON, BG_CARD, ACCENT)


static func secondary_button() -> StyleBox:
	return frame_box(UiFrameSpec.BUTTON_SECONDARY, BG_CARD, STROKE_SOFT)


static func danger_button() -> StyleBox:
	return frame_box(UiFrameSpec.BUTTON, BG_CARD, DANGER)


static func disabled_button() -> StyleBox:
	return button(STROKE_SOFT, 0.08)


static func resource_item() -> StyleBox:
	return frame_box(UiFrameSpec.RESOURCE_ITEM, BG_CARD, STROKE_SOFT, false)


static func resource_delta_badge() -> StyleBox:
	return frame_box(UiFrameSpec.RESOURCE_DELTA_BADGE, SUCCESS_SOFT, SUCCESS, false)


static func speed_toggle_base() -> StyleBox:
	return frame_box(UiFrameSpec.SPEED_TOGGLE, BG_CARD, STROKE_SOFT, false)


static func speed_toggle_active() -> StyleBox:
	return flat_box(AMBER_SOFT, AMBER, 1.0, 5.0)


static func scroll_track() -> StyleBox:
	return frame_box(UiFrameSpec.SCROLL_TRACK, BG_DARK, STROKE_SOFT, false)


static func scroll_track_horizontal() -> StyleBox:
	return frame_box(UiFrameSpec.SCROLL_TRACK_HORIZONTAL, BG_DARK, STROKE_SOFT, false)


static func tooltip() -> StyleBox:
	if ResourceLoader.exists(TOOLTIP_STYLE_PATH):
		var style := load(TOOLTIP_STYLE_PATH) as StyleBox
		if style != null:
			return style
	return frame_box(UiFrameSpec.TOOLTIP, BG_GLASS, STROKE_SOFT)


static func scroll_thumb() -> StyleBox:
	return frame_box(UiFrameSpec.SCROLL_THUMB, BG_CARD_HOVER, ACCENT, false)


static func scroll_thumb_horizontal() -> StyleBox:
	return frame_box(UiFrameSpec.SCROLL_THUMB_HORIZONTAL, BG_CARD_HOVER, ACCENT, false)


static func slider_track() -> StyleBox:
	return frame_box(UiFrameSpec.SLIDER_TRACK, BG_DARK, STROKE_SOFT, false)


static func slider_fill() -> StyleBox:
	return frame_box(UiFrameSpec.SLIDER_FILL, ACCENT_SOFT, ACCENT, false)


static func slider_handle() -> Texture2D:
	return UiArtRegistry.get_frame_texture(UiFrameSpec.SLIDER_HANDLE)


static func apply_scroll_style(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	var vbar := scroll.get_v_scroll_bar()
	if vbar != null:
		_apply_scroll_bar_style(vbar)
	var hbar := scroll.get_h_scroll_bar()
	if hbar != null:
		_apply_scroll_bar_style(hbar)


static func _apply_scroll_bar_style(scroll_bar: ScrollBar) -> void:
	var track := scroll_track_horizontal() if scroll_bar is HScrollBar else scroll_track()
	var thumb := scroll_thumb_horizontal() if scroll_bar is HScrollBar else scroll_thumb()
	scroll_bar.add_theme_stylebox_override("scroll", track)
	scroll_bar.add_theme_stylebox_override("grabber", thumb)
	scroll_bar.add_theme_stylebox_override("grabber_highlight", thumb)
	scroll_bar.add_theme_stylebox_override("grabber_pressed", thumb)


static func apply_slider_style(slider: Slider) -> void:
	if slider == null:
		return
	slider.add_theme_stylebox_override("slider", slider_track())
	slider.add_theme_stylebox_override("grabber_area", slider_fill())
	slider.add_theme_stylebox_override("grabber_area_highlight", slider_fill())
	var handle := slider_handle()
	if handle != null:
		slider.add_theme_icon_override("grabber", handle)
		slider.add_theme_icon_override("grabber_highlight", handle)
		slider.add_theme_icon_override("grabber_pressed", handle)
