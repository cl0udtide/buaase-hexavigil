extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiLayoutRules = preload("res://scripts/ui/ui_layout_rules.gd")

signal operator_card_pressed(operator_key: StringName)
signal pause_pressed
signal speed_1_pressed
signal speed_2_pressed
signal debug_drawer_toggle_pressed
signal cast_skill_requested
signal retreat_requested
signal wave_route_preview_toggled(enabled: bool)

const OPERATOR_CARD_SCENE := preload("res://scenes/ui/combat/OperatorCard.tscn")
const WAVE_PREVIEW_MIN_TEXT_HEIGHT := 108.0
const WAVE_PREVIEW_LINE_HEIGHT := 19.0
const WAVE_PREVIEW_PANEL_TOP := 84.0
const WAVE_PREVIEW_PANEL_BOTTOM_PADDING := 34.0
const UNIT_DETAIL_GAP := 12.0
const UNIT_DETAIL_MIN_TOP := 250.0

var _cards_by_operator_key: Dictionary = {}
var _left_reserved_width := 0.0
var _layout_profile: Dictionary = {}

@onready var _top_bar: PanelContainer = %TopBar
@onready var _core_label: Label = %CoreLabel
@onready var _deploy_label: Label = %DeployLabel
@onready var _queue_label: Label = %QueueLabel
@onready var _message_label: Label = %MessageLabel
@onready var _resource_label: Label = %ResourceLabel
@onready var _pause_button: Button = %PauseButton
@onready var _speed_1_button: Button = %Speed1Button
@onready var _speed_2_button: Button = %Speed2Button
@onready var _debug_button: Button = %DebugButton
@onready var _wave_preview_panel: PanelContainer = %WavePreviewPanel
@onready var _wave_preview_title_label: Label = %WavePreviewTitleLabel
@onready var _wave_route_toggle: CheckBox = %WaveRouteToggle
@onready var _wave_preview_label: Label = %WavePreviewLabel
@onready var _deck_panel: PanelContainer = %DeployDeck
@onready var _deck_container: HBoxContainer = %DeployDeckContainer
@onready var _detail_panel: PanelContainer = %UnitDetailPanel
@onready var _drag_ghost: PanelContainer = %DragGhost
@onready var _drag_ghost_label: Label = %DragGhostLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AppTheme.apply(self)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_top_bar.add_theme_stylebox_override("panel", GameUiStyle.top_hud_panel())
	_apply_frame_margins()
	_style_top_cards()
	_wave_preview_panel.add_theme_stylebox_override("panel", GameUiStyle.compact_panel(GameUiStyle.ACCENT, GameUiStyle.BG_GLASS, false))
	_wave_preview_title_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	_wave_preview_title_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	_wave_preview_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_wave_preview_title_label.add_theme_constant_override("shadow_offset_y", 0)
	GameUiStyle.center_label_text(_wave_preview_title_label)
	_wave_preview_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_wave_preview_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	_wave_preview_label.add_theme_constant_override("shadow_offset_x", 0)
	_wave_preview_label.add_theme_constant_override("shadow_offset_y", 0)
	_wave_route_toggle.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	_wave_route_toggle.custom_minimum_size = Vector2(68.0, 30.0)
	_style_button(_wave_route_toggle, GameUiStyle.STROKE_SOFT)
	_deck_panel.add_theme_stylebox_override("panel", GameUiStyle.deck_panel())
	_drag_ghost.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_CARD, GameUiStyle.BG_CARD, GameUiStyle.AMBER, false))
	_drag_ghost_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_speed_1_button.pressed.connect(func() -> void: speed_1_pressed.emit())
	_speed_2_button.pressed.connect(func() -> void: speed_2_pressed.emit())
	_debug_button.pressed.connect(func() -> void: debug_drawer_toggle_pressed.emit())
	_wave_route_toggle.toggled.connect(func(enabled: bool) -> void: wave_route_preview_toggled.emit(enabled))
	if _detail_panel.has_signal("cast_skill_requested"):
		_detail_panel.cast_skill_requested.connect(func() -> void: cast_skill_requested.emit())
	if _detail_panel.has_signal("retreat_requested"):
		_detail_panel.retreat_requested.connect(func() -> void: retreat_requested.emit())
	_style_button(_pause_button, GameUiStyle.STROKE)
	_style_button(_speed_1_button, GameUiStyle.STROKE)
	_style_button(_speed_2_button, GameUiStyle.STROKE)
	_style_button(_debug_button, GameUiStyle.STROKE)
	_drag_ghost.visible = false
	_apply_responsive_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_responsive_layout()


func set_top_values(core_text: String, deploy_text: String, queue_text: String) -> void:
	_core_label.text = core_text
	_deploy_label.text = deploy_text
	_queue_label.text = queue_text


func show_message(text_value: String) -> void:
	_message_label.text = text_value


func set_resource_values(resource_text: String, tooltip_text_value: String = "") -> void:
	_resource_label.text = resource_text
	_resource_label.tooltip_text = tooltip_text_value


func set_wave_preview_text(text_value: String, show_panel: bool = true) -> void:
	_wave_preview_label.text = text_value
	_wave_preview_panel.visible = show_panel and not text_value.strip_edges().is_empty()
	_resize_wave_preview_panel(text_value)


func set_wave_route_preview_enabled(enabled: bool) -> void:
	_wave_route_toggle.set_pressed_no_signal(enabled)


func set_time_controls(paused: bool, speed: float, enabled: bool = true) -> void:
	_pause_button.disabled = not enabled
	_speed_1_button.disabled = not enabled
	_speed_2_button.disabled = not enabled
	var effective_paused := paused and enabled
	var pause_accent := GameUiStyle.AMBER if effective_paused else GameUiStyle.STROKE_SOFT
	var speed_1_accent := GameUiStyle.STROKE_SOFT
	var speed_2_accent := GameUiStyle.STROKE_SOFT
	if enabled and not effective_paused:
		speed_1_accent = GameUiStyle.ACCENT if is_equal_approx(speed, 1.0) else GameUiStyle.STROKE_SOFT
		speed_2_accent = GameUiStyle.ACCENT if is_equal_approx(speed, 2.0) else GameUiStyle.STROKE_SOFT
	_pause_button.text = "暂停"
	_style_button(_pause_button, pause_accent)
	_style_button(_speed_1_button, speed_1_accent)
	_style_button(_speed_2_button, speed_2_accent)


func set_debug_drawer_open(open: bool) -> void:
	_debug_button.text = "关闭" if open else "调试"


func set_operators(operators: Array[Dictionary]) -> void:
	for child in _deck_container.get_children():
		child.queue_free()
	_cards_by_operator_key.clear()
	for operator_info in operators:
		var operator_key := StringName((operator_info as Dictionary).get("key", ""))
		var card = OPERATOR_CARD_SCENE.instantiate()
		card.setup(operator_key)
		if card.has_method("set_compact"):
			card.set_compact(bool(_layout_profile.get("compact", false)))
		card.operator_card_pressed.connect(func(key: StringName) -> void: operator_card_pressed.emit(key))
		_deck_container.add_child(card)
		_cards_by_operator_key[operator_key] = card


func set_operator_card(operator_key: StringName, text_value: String, state: StringName) -> void:
	var card = _cards_by_operator_key.get(operator_key)
	if card != null and card.has_method("set_state_text"):
		card.set_state_text(text_value, state)


func show_drag_ghost(text_value: String) -> void:
	_drag_ghost_label.text = text_value
	_drag_ghost.visible = true
	move_drag_ghost(get_viewport().get_mouse_position())


func move_drag_ghost(position_value: Vector2) -> void:
	if _drag_ghost.visible:
		_drag_ghost.position = position_value + Vector2(18.0, 18.0)


func hide_drag_ghost() -> void:
	_drag_ghost.visible = false


func show_unit_detail(unit: Node, display_name: String, damage_label: String, direction_label: String) -> void:
	if _detail_panel.has_method("show_unit"):
		_detail_panel.show_unit(unit, display_name, damage_label, direction_label)
	_apply_responsive_layout()


func clear_unit_detail() -> void:
	if _detail_panel.has_method("clear_unit"):
		_detail_panel.clear_unit()
	_apply_responsive_layout()


func set_left_reserved_width(width: float) -> void:
	var next_width := maxf(0.0, width)
	if is_equal_approx(_left_reserved_width, next_width):
		return
	_left_reserved_width = next_width
	_apply_responsive_layout()


func _resize_wave_preview_panel(text_value: String) -> void:
	var line_count: int = max(text_value.count("\n") + 1, 1)
	var text_height: float = max(WAVE_PREVIEW_MIN_TEXT_HEIGHT, float(line_count) * WAVE_PREVIEW_LINE_HEIGHT)
	_wave_preview_label.custom_minimum_size.y = text_height
	var panel_height: float = text_height + WAVE_PREVIEW_PANEL_BOTTOM_PADDING
	_wave_preview_panel.offset_bottom = WAVE_PREVIEW_PANEL_TOP + panel_height
	_detail_panel.offset_top = max(UNIT_DETAIL_MIN_TOP, _wave_preview_panel.offset_bottom + UNIT_DETAIL_GAP)


func _style_button(button: Button, accent: Color) -> void:
	GameUiStyle.center_button_text(button)
	button.add_theme_stylebox_override("normal", GameUiStyle.button(accent))
	button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.08))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_INVERTED)


func _apply_frame_margins() -> void:
	GameUiStyle.apply_frame_margin(get_node_or_null("TopBar/TopMargin") as MarginContainer, GameUiStyle.FRAME_TOP_HUD)
	GameUiStyle.apply_frame_margin(get_node_or_null("WavePreviewPanel/WavePreviewMargin") as MarginContainer, GameUiStyle.FRAME_CARD, Vector4(2.0, 0.0, 2.0, 0.0))
	GameUiStyle.apply_frame_margin(get_node_or_null("DeployDeck/DeckMargin") as MarginContainer, GameUiStyle.FRAME_DECK_PANEL)
	GameUiStyle.apply_frame_margin(get_node_or_null("DragGhost/MarginContainer") as MarginContainer, GameUiStyle.FRAME_CARD)


func _style_top_cards() -> void:
	for card_path in [
		"TopBar/TopMargin/Row/StageCard",
		"TopBar/TopMargin/Row/CoreCard",
		"TopBar/TopMargin/Row/DeployCard",
		"TopBar/TopMargin/Row/MessageCard",
		"TopBar/TopMargin/Row/TimeCard",
		"TopBar/TopMargin/Row/ResourceCard"
	]:
		var card := get_node_or_null(card_path) as PanelContainer
		if card != null:
			card.add_theme_stylebox_override("panel", GameUiStyle.top_card())
	for label in [_core_label, _deploy_label, _queue_label, _message_label, _resource_label]:
		label.add_theme_color_override("font_color", GameUiStyle.TEXT)
		label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_constant_override("line_spacing", 0)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for label in [_queue_label, _core_label, _deploy_label, _resource_label]:
		GameUiStyle.center_label_text(label)
	for label in [_message_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_message_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport_rect().size
	var detail_visible := _detail_panel != null and _detail_panel.visible
	_layout_profile = UiLayoutRules.hud_profile(viewport_size, detail_visible, _left_reserved_width)
	_place_control(_top_bar, _layout_profile.get("top_rect", Rect2()))
	_place_control(_deck_panel, _layout_profile.get("deck_rect", Rect2()))
	_place_control(_detail_panel, _layout_profile.get("detail_rect", Rect2()))
	_apply_top_bar_density(viewport_size.x)
	var compact := bool(_layout_profile.get("compact", false))
	for child in _deck_container.get_children():
		if child.has_method("set_compact"):
			child.set_compact(compact)


func _place_control(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


func _apply_top_bar_density(viewport_width: float) -> void:
	var widths := UiLayoutRules.top_card_widths(viewport_width)
	var top_height := float(_layout_profile.get("top_card_height", 68.0))
	var compact := bool(_layout_profile.get("compact", false))
	var row := get_node_or_null("TopBar/TopMargin/Row") as HBoxContainer
	if row != null:
		row.add_theme_constant_override("separation", int(_layout_profile.get("top_separation", 12.0)))
	_set_top_card_min("TopBar/TopMargin/Row/StageCard", widths.get("stage", 190.0), top_height)
	_set_top_card_min("TopBar/TopMargin/Row/CoreCard", widths.get("core", 190.0), top_height)
	_set_top_card_min("TopBar/TopMargin/Row/DeployCard", widths.get("deploy", 160.0), top_height)
	_set_top_card_min("TopBar/TopMargin/Row/MessageCard", widths.get("message", 260.0), top_height)
	_set_top_card_min("TopBar/TopMargin/Row/TimeCard", widths.get("time", 200.0), top_height)
	_set_top_card_min("TopBar/TopMargin/Row/ResourceCard", widths.get("resource", 245.0), top_height)
	_debug_button.custom_minimum_size = Vector2(float(widths.get("debug", 76.0)), top_height)
	var label_size := 12 if compact else 13
	for label in [_core_label, _deploy_label, _queue_label, _message_label]:
		label.add_theme_font_size_override("font_size", label_size)
	_resource_label.add_theme_font_size_override("font_size", 12)
	var button_height := 34.0 if compact else 36.0
	_pause_button.custom_minimum_size = Vector2(68.0 if compact else 74.0, button_height)
	_speed_1_button.custom_minimum_size = Vector2(52.0 if compact else 56.0, button_height)
	_speed_2_button.custom_minimum_size = Vector2(52.0 if compact else 56.0, button_height)


func _set_top_card_min(path: NodePath, width: float, height: float) -> void:
	var card := get_node_or_null(path) as Control
	if card != null:
		card.custom_minimum_size = Vector2(width, height)
