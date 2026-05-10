extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiLayoutRules = preload("res://scripts/ui/ui_layout_rules.gd")

signal operator_card_pressed(operator_key: StringName)
signal pause_pressed
signal speed_1_pressed
signal speed_2_pressed
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
var _open_panel_stack: Array[StringName] = []
var _core_hp_ratio := 0.0

@onready var _settings_button: Button = %SettingsButton
@onready var _settings_panel: Control = %AudioSettingsPanel
@onready var _top_bar: Control = %TopBar
@onready var _top_bar_base: Panel = %TopBarBase
@onready var _core_label: Label = %CoreLabel
@onready var _core_track: Panel = %CoreTrack
@onready var _core_fill: Panel = %CoreFill
@onready var _deploy_label: Label = %DeployLabel
@onready var _queue_label: Label = %QueueLabel
@onready var _message_label: Label = %MessageLabel
@onready var _resource_label: Label = %ResourceLabel
@onready var _pause_button: Button = %PauseButton
@onready var _speed_1_button: Button = %Speed1Button
@onready var _speed_2_button: Button = %Speed2Button
@onready var _relic_strip: Control = %RelicStrip
@onready var _relic_panel: Control = %RelicPanel
@onready var _wave_preview_panel: Control = %WavePreviewPanel
@onready var _wave_preview_base: Panel = %WavePreviewBase
@onready var _wave_preview_title_label: Label = %WavePreviewTitleLabel
@onready var _wave_route_toggle: CheckBox = %WaveRouteToggle
@onready var _wave_preview_label: Label = %WavePreviewLabel
@onready var _deck_panel: Control = %DeployDeck
@onready var _deploy_rail_base: Panel = %DeployRailBase
@onready var _deck_container: HBoxContainer = %DeployDeckContainer
@onready var _detail_panel: Control = %UnitDetailPanel
@onready var _legend_panel: Control = %LegendPanel
@onready var _legend_base: Panel = %LegendBase
@onready var _drag_ghost: Control = %DragGhost
@onready var _drag_ghost_base: Panel = %DragGhostBase
@onready var _drag_ghost_label: Label = %DragGhostLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)
	AppTheme.apply(self)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_top_bar_base.add_theme_stylebox_override("panel", GameUiStyle.top_hud_panel())
	_core_track.add_theme_stylebox_override("panel", GameUiStyle.progress_background())
	_core_fill.add_theme_stylebox_override("panel", GameUiStyle.progress_fill(GameUiStyle.AMBER))
	_core_track.resized.connect(_refresh_core_fill)
	_apply_frame_margins()
	_style_top_cards()
	_wave_preview_base.add_theme_stylebox_override("panel", GameUiStyle.compact_panel(GameUiStyle.ACCENT, GameUiStyle.BG_GLASS, false))
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
	_deploy_rail_base.add_theme_stylebox_override("panel", GameUiStyle.deck_panel())
	_legend_base.add_theme_stylebox_override("panel", GameUiStyle.legend_panel())
	_style_legend_panel()
	_drag_ghost_base.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_CARD, GameUiStyle.BG_CARD, GameUiStyle.AMBER, false))
	_drag_ghost_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_speed_1_button.pressed.connect(func() -> void: speed_1_pressed.emit())
	_speed_2_button.pressed.connect(func() -> void: speed_2_pressed.emit())
	_wave_route_toggle.toggled.connect(func(enabled: bool) -> void: wave_route_preview_toggled.emit(enabled))
	_bind_overlay_panels()
	if _detail_panel.has_signal("cast_skill_requested"):
		_detail_panel.cast_skill_requested.connect(func() -> void: cast_skill_requested.emit())
	if _detail_panel.has_signal("retreat_requested"):
		_detail_panel.retreat_requested.connect(func() -> void: retreat_requested.emit())
	_style_top_button(_pause_button, false)
	_style_top_button(_speed_1_button, false)
	_style_top_button(_speed_2_button, false)
	_drag_ghost.visible = false
	_apply_responsive_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_responsive_layout()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_R:
		toggle_relic_panel()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and close_top_panel():
		get_viewport().set_input_as_handled()


func set_top_values(core_text: String, deploy_text: String, queue_text: String) -> void:
	_core_label.text = core_text
	_deploy_label.text = deploy_text
	_queue_label.text = queue_text
	_set_core_progress_from_text(core_text)


func show_message(text_value: String) -> void:
	_message_label.text = text_value


func set_resource_values(resource_text: String, tooltip_text_value: String = "") -> void:
	_resource_label.text = resource_text
	_resource_label.tooltip_text = tooltip_text_value


func set_relics(relic_ids: Array[StringName]) -> void:
	if _relic_strip != null and _relic_strip.has_method("set_relics"):
		_relic_strip.set_relics(relic_ids)
	if _relic_panel != null and _relic_panel.has_method("set_relics"):
		_relic_panel.set_relics(relic_ids)


func toggle_relic_panel() -> void:
	if _relic_panel == null:
		return
	if _relic_panel.visible:
		_hide_overlay_panel(&"relic")
	else:
		_show_overlay_panel(&"relic")


func toggle_settings_panel() -> void:
	if _settings_panel == null:
		return
	if _settings_panel.visible:
		_hide_overlay_panel(&"settings")
	else:
		_show_overlay_panel(&"settings")


func close_top_panel() -> bool:
	while not _open_panel_stack.is_empty():
		var panel_name: StringName = _open_panel_stack.pop_back()
		var panel := _panel_for_name(panel_name)
		if panel != null and panel.visible:
			_hide_overlay_panel(panel_name)
			return true
	if _settings_panel != null and _settings_panel.visible:
		_hide_overlay_panel(&"settings")
		return true
	if _relic_panel != null and _relic_panel.visible:
		_hide_overlay_panel(&"relic")
		return true
	return false


func set_wave_preview_text(text_value: String, show_panel: bool = true) -> void:
	_wave_preview_label.text = text_value
	_wave_preview_panel.visible = show_panel and not text_value.strip_edges().is_empty()
	_resize_wave_preview_panel(text_value)
	_apply_responsive_layout()


func set_wave_route_preview_enabled(enabled: bool) -> void:
	_wave_route_toggle.set_pressed_no_signal(enabled)


func set_time_controls(paused: bool, speed: float, enabled: bool = true) -> void:
	_pause_button.disabled = not enabled
	_speed_1_button.disabled = not enabled
	_speed_2_button.disabled = not enabled
	var effective_paused := paused and enabled
	var pause_selected := effective_paused
	var speed_1_selected := false
	var speed_2_selected := false
	if enabled and not effective_paused:
		speed_1_selected = is_equal_approx(speed, 1.0)
		speed_2_selected = is_equal_approx(speed, 2.0)
	_pause_button.text = "暂停"
	_style_top_button(_pause_button, pause_selected)
	_style_top_button(_speed_1_button, speed_1_selected)
	_style_top_button(_speed_2_button, speed_2_selected)


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


func _style_button(button: Button, accent: Color) -> void:
	GameUiStyle.center_button_text(button)
	button.add_theme_stylebox_override("normal", GameUiStyle.button(accent))
	button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.08))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_INVERTED)


func _style_top_button(button: Button, selected: bool) -> void:
	GameUiStyle.center_button_text(button)
	button.add_theme_stylebox_override("normal", GameUiStyle.compact_button(selected))
	button.add_theme_stylebox_override("hover", GameUiStyle.compact_button(true))
	button.add_theme_stylebox_override("pressed", GameUiStyle.compact_button(true))
	button.add_theme_stylebox_override("disabled", GameUiStyle.compact_button(false))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_pressed_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)


func _apply_frame_margins() -> void:
	GameUiStyle.apply_frame_margin(get_node_or_null("HudChromeLayer/TopBar/TopContent") as MarginContainer, GameUiStyle.FRAME_TOP_HUD, Vector4(4.0, 0.0, 4.0, 0.0))
	GameUiStyle.apply_frame_margin(get_node_or_null("HudChromeLayer/WavePreviewPanel/WavePreviewMargin") as MarginContainer, GameUiStyle.FRAME_CARD, Vector4(2.0, 0.0, 2.0, 0.0))
	GameUiStyle.apply_frame_margin(get_node_or_null("HudChromeLayer/DeployDeck/DeckMargin") as MarginContainer, GameUiStyle.FRAME_DECK_PANEL)
	GameUiStyle.apply_frame_margin(get_node_or_null("HudChromeLayer/LegendPanel/LegendMargin") as MarginContainer, GameUiStyle.FRAME_LEGEND_PANEL)
	GameUiStyle.apply_frame_margin(get_node_or_null("InteractionLayer/DragGhost/GhostMargin") as MarginContainer, GameUiStyle.FRAME_CARD)


func _style_top_cards() -> void:
	for card_path in [
		"HudChromeLayer/TopBar/TopContent/TopContentRow/StageChip/ChipBase",
		"HudChromeLayer/TopBar/TopContent/TopContentRow/CoreChip/ChipBase",
		"HudChromeLayer/TopBar/TopContent/TopContentRow/DeployChip/ChipBase",
		"HudChromeLayer/TopBar/TopContent/TopContentRow/MessageChip/ChipBase",
		"HudChromeLayer/TopBar/TopContent/TopContentRow/TimeControls/SpeedToggleBase",
		"HudChromeLayer/TopBar/TopContent/TopContentRow/ResourceChip/ChipBase"
	]:
		var card := get_node_or_null(card_path) as Panel
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
		GameUiStyle.center_label_text(label)
	_message_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)


func _style_legend_panel() -> void:
	var title := get_node_or_null("HudChromeLayer/LegendPanel/LegendMargin/LegendVBox/LegendTitleLabel") as Label
	for label_node in _legend_panel.find_children("*", "Label", true, false):
		var label := label_node as Label
		label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
		label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_font_size_override("font_size", 12)
	if title != null:
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", GameUiStyle.TEXT)
		GameUiStyle.center_label_text(title)


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()
	_refresh_core_fill()


func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport_rect().size
	var detail_visible := _detail_panel != null and _detail_panel.visible
	_layout_profile = UiLayoutRules.hud_profile(viewport_size, detail_visible, _left_reserved_width)
	_place_control(_settings_button, _layout_profile.get("settings_button_rect", Rect2()))
	_place_control(_settings_panel, _layout_profile.get("settings_panel_rect", Rect2()))
	var top_rect: Rect2 = _layout_profile.get("top_bar_rect", _layout_profile.get("top_rect", Rect2()))
	_place_control(_top_bar, top_rect)
	_place_control(_relic_strip, _layout_profile.get("relic_strip_rect", Rect2()))
	_place_control(_relic_panel, _layout_profile.get("relic_panel_rect", Rect2()))
	_place_control(_deck_panel, _layout_profile.get("deploy_deck_rect", _layout_profile.get("deck_rect", Rect2())))
	_place_wave_preview_and_detail()
	_place_control(_legend_panel, _layout_profile.get("legend_panel_rect", Rect2()))
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


func _place_wave_preview_and_detail() -> void:
	var detail_rect: Rect2 = _layout_profile.get("detail_panel_rect", _layout_profile.get("detail_rect", Rect2()))
	if _wave_preview_panel != null and _wave_preview_panel.visible:
		var desired_height := _wave_preview_label.custom_minimum_size.y + WAVE_PREVIEW_PANEL_BOTTOM_PADDING
		var max_height := maxf(116.0, minf(188.0, detail_rect.size.y * 0.34))
		var wave_height := clampf(desired_height, 118.0, max_height)
		_place_control(_wave_preview_panel, Rect2(detail_rect.position, Vector2(detail_rect.size.x, wave_height)))
		var detail_bottom := detail_rect.end.y
		detail_rect.position.y += wave_height + UNIT_DETAIL_GAP
		detail_rect.size.y = maxf(180.0, detail_bottom - detail_rect.position.y)
	else:
		_place_control(_wave_preview_panel, Rect2(detail_rect.position, Vector2(detail_rect.size.x, 0.0)))
	_place_control(_detail_panel, detail_rect)


func _apply_top_bar_density(viewport_width: float) -> void:
	var widths := UiLayoutRules.top_card_widths(viewport_width)
	var top_height := float(_layout_profile.get("top_card_height", 50.0))
	var compact := bool(_layout_profile.get("compact", false))
	var row := get_node_or_null("HudChromeLayer/TopBar/TopContent/TopContentRow") as HBoxContainer
	if row != null:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", int(_layout_profile.get("top_separation", 12.0)))
	var card_height := maxf(36.0, top_height - 8.0)
	var show_message_card := viewport_width > 720.0
	var message_card := get_node_or_null("HudChromeLayer/TopBar/TopContent/TopContentRow/MessageChip") as Control
	if message_card != null:
		message_card.visible = show_message_card
	_set_top_card_min("HudChromeLayer/TopBar/TopContent/TopContentRow/StageChip", widths.get("stage", 190.0), card_height)
	_set_top_card_min("HudChromeLayer/TopBar/TopContent/TopContentRow/CoreChip", widths.get("core", 190.0), card_height)
	_set_top_card_min("HudChromeLayer/TopBar/TopContent/TopContentRow/DeployChip", widths.get("deploy", 160.0), card_height)
	_set_top_card_min("HudChromeLayer/TopBar/TopContent/TopContentRow/MessageChip", widths.get("message", 260.0), card_height)
	_set_top_card_min("HudChromeLayer/TopBar/TopContent/TopContentRow/TimeControls", widths.get("time", 200.0), card_height)
	_set_top_card_min("HudChromeLayer/TopBar/TopContent/TopContentRow/ResourceChip", widths.get("resource", 245.0), card_height)
	var label_size := 12 if compact else 13
	for label in [_core_label, _deploy_label, _queue_label, _message_label]:
		label.add_theme_font_size_override("font_size", label_size)
	_resource_label.add_theme_font_size_override("font_size", 12)
	var button_height := 34.0 if compact else 36.0
	_pause_button.custom_minimum_size = Vector2(74.0 if compact else 82.0, button_height)
	_speed_1_button.custom_minimum_size = Vector2(58.0 if compact else 64.0, button_height)
	_speed_2_button.custom_minimum_size = Vector2(58.0 if compact else 64.0, button_height)


func _set_top_card_min(path: NodePath, width: float, height: float) -> void:
	var card := get_node_or_null(path) as Control
	if card != null:
		card.custom_minimum_size = Vector2(width, height)


func _set_core_progress_from_text(core_text: String) -> void:
	var ratio := 0.0
	for token in core_text.split("\n", false):
		var slash_index := token.find("/")
		if slash_index <= 0:
			continue
		var current_text := token.substr(0, slash_index).strip_edges()
		var max_text := token.substr(slash_index + 1).strip_edges()
		if current_text.is_valid_int() and max_text.is_valid_int():
			var max_value := maxf(float(max_text.to_int()), 1.0)
			ratio = clampf(float(current_text.to_int()) / max_value, 0.0, 1.0)
			break
	_core_hp_ratio = ratio
	_refresh_core_fill()


func _refresh_core_fill() -> void:
	if _core_track == null or _core_fill == null:
		return
	_core_fill.anchor_left = _core_track.anchor_left
	_core_fill.anchor_top = _core_track.anchor_top
	_core_fill.anchor_right = _core_track.anchor_left
	_core_fill.anchor_bottom = _core_track.anchor_bottom
	_core_fill.offset_left = _core_track.offset_left
	_core_fill.offset_top = _core_track.offset_top
	_core_fill.offset_right = _core_track.offset_left + maxf(0.0, _core_track.size.x * _core_hp_ratio)
	_core_fill.offset_bottom = _core_track.offset_bottom


func _bind_overlay_panels() -> void:
	if _settings_button != null:
		if _settings_button.has_signal("settings_button_pressed"):
			_settings_button.connect(&"settings_button_pressed", Callable(self, "_on_settings_button_pressed"))
		else:
			_settings_button.pressed.connect(_on_settings_button_pressed)
	if _settings_panel != null and _settings_panel.has_signal("close_requested"):
		_settings_panel.connect(&"close_requested", Callable(self, "_on_settings_panel_close_requested"))
	if _relic_strip != null:
		if _relic_strip.has_signal("panel_requested"):
			_relic_strip.connect(&"panel_requested", Callable(self, "_on_relic_panel_requested"))
		if _relic_strip.has_signal("relic_pressed"):
			_relic_strip.connect(&"relic_pressed", Callable(self, "_on_relic_strip_relic_pressed"))
	if _relic_panel != null and _relic_panel.has_signal("close_requested"):
		_relic_panel.connect(&"close_requested", Callable(self, "_on_relic_panel_close_requested"))


func _on_settings_button_pressed() -> void:
	toggle_settings_panel()


func _on_settings_panel_close_requested() -> void:
	_hide_overlay_panel(&"settings")


func _on_relic_panel_requested() -> void:
	_show_overlay_panel(&"relic")


func _on_relic_strip_relic_pressed(buff_id: StringName) -> void:
	if _relic_panel != null and _relic_panel.has_method("select_relic"):
		_relic_panel.select_relic(buff_id)


func _on_relic_panel_close_requested() -> void:
	_hide_overlay_panel(&"relic")


func _show_overlay_panel(panel_name: StringName) -> void:
	var panel := _panel_for_name(panel_name)
	if panel == null:
		return
	if panel.has_method("show_panel"):
		panel.show_panel()
	else:
		panel.visible = true
	_move_control_to_front(panel)
	_mark_panel_top(panel_name)


func _hide_overlay_panel(panel_name: StringName) -> void:
	var panel := _panel_for_name(panel_name)
	if panel == null:
		return
	if panel.has_method("hide_panel"):
		panel.hide_panel()
	else:
		panel.visible = false
	_remove_panel_from_stack(panel_name)


func _panel_for_name(panel_name: StringName) -> Control:
	match panel_name:
		&"settings":
			return _settings_panel
		&"relic":
			return _relic_panel
		_:
			return null


func _mark_panel_top(panel_name: StringName) -> void:
	_remove_panel_from_stack(panel_name)
	_open_panel_stack.append(panel_name)


func _remove_panel_from_stack(panel_name: StringName) -> void:
	while _open_panel_stack.has(panel_name):
		_open_panel_stack.erase(panel_name)


func _move_control_to_front(control: Control) -> void:
	if control == null or control.get_parent() == null:
		return
	var parent := control.get_parent()
	parent.move_child(control, parent.get_child_count() - 1)
