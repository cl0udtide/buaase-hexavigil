extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiLayoutRules = preload("res://scripts/ui/ui_layout_rules.gd")
const UiTokens = preload("res://scripts/ui/ui_tokens.gd")

signal operator_card_pressed(operator_key: StringName)
signal operator_card_drag_started(operator_key: StringName)
signal pause_pressed
signal speed_1_pressed
signal speed_2_pressed
signal cast_skill_requested
signal retreat_requested
signal shop_unit_purchase_requested(slot_index: int)
signal wave_route_preview_toggled(enabled: bool)

const OPERATOR_CARD_SCENE := preload("res://scenes/ui/combat/OperatorCard.tscn")
const RESOURCE_ORDER: Array[StringName] = [&"ap", &"wood", &"stone", &"mana", &"prestige"]
const CORE_HP_TITLE := "核心生命"

# Top HUD micro-tuning lives here so visual adjustments do not require hunting
# through layout code. Vector4 means left, top, right, bottom inset.
const TOP_CONTENT_INSETS := Vector4(0.0, 5.0, 0.0, 5.0)
const TOP_CHIP_LABEL_INSETS := Vector4(42.0, 10.0, 16.0, 10.0)
const TOP_MESSAGE_LABEL_INSETS := Vector4(42.0, 10.0, 18.0, 10.0)
const TOP_CORE_LABEL_LEFT := 42.0
const TOP_CORE_LABEL_TOP := 9.0
const TOP_CORE_LABEL_HEIGHT := 24.0
const TOP_CORE_BAR_LEFT := 44.0
const TOP_CORE_BAR_RIGHT := 16.0
const TOP_CORE_BAR_BOTTOM := 12.0
const TOP_CORE_BAR_HEIGHT := 18.0
const TOP_ICON_LEFT := 10.0
const TOP_ICON_SIZE := 28.0
const TIME_BUTTON_ROW_INSETS := Vector4(0.0, 10.0, 0.0, 10.0)
const RESOURCE_ROW_INSETS := Vector4(0.0, 4.0, 0.0, 4.0)
const RESOURCE_ITEM_INSETS := Vector4(8.0, 7.0, 8.0, 7.0)
const RESOURCE_ITEM_INSETS_COMPACT := Vector4(7.0, 6.0, 7.0, 6.0)

const WAVE_PREVIEW_MIN_TEXT_HEIGHT := 62.0
const WAVE_PREVIEW_LINE_HEIGHT := 19.0
const WAVE_PREVIEW_PANEL_BOTTOM_PADDING := 34.0
const WAVE_PREVIEW_HEADER_TEXT_PADDING := 54.0
const UNIT_DETAIL_GAP := 12.0

var _cards_by_operator_key: Dictionary = {}
var _resource_item_controls: Dictionary = {}
var _left_reserved_width := 0.0
var _layout_profile: Dictionary = {}
var _open_panel_stack: Array[StringName] = []
var _core_hp_ratio := 0.0
var _core_hp_current := 0
var _core_hp_max := 0
var _wave_preview_text_min_height := WAVE_PREVIEW_MIN_TEXT_HEIGHT

@onready var _settings_button: Button = %SettingsButton
@onready var _settings_panel: Control = %AudioSettingsPanel
@onready var _top_bar: Control = %TopBar
@onready var _top_bar_base: Panel = %TopBarBase
@onready var _top_content_row: HBoxContainer = get_node_or_null("HudChromeLayer/TopBar/TopContent/TopContentRow") as HBoxContainer
@onready var _stage_chip: Control = %StageChip
@onready var _core_chip: Control = %CoreChip
@onready var _deploy_chip: Control = %DeployChip
@onready var _message_chip: Control = %MessageChip
@onready var _time_controls: Control = %TimeControls
@onready var _speed_toggle_base: Panel = %SpeedToggleBase
@onready var _speed_active_overlay: Panel = %SpeedActiveOverlay
@onready var _resource_chip: Control = %ResourceChip
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
	_top_bar_base.visible = false
	_top_bar_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_toggle_base.visible = false
	_speed_toggle_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var resource_base := _resource_chip.get_node_or_null("ChipBase") as Panel
	if resource_base != null:
		resource_base.visible = false
		resource_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_core_track.add_theme_stylebox_override("panel", GameUiStyle.progress_background())
	_core_fill.add_theme_stylebox_override("panel", GameUiStyle.core_progress_fill())
	_core_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_core_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_core_track.resized.connect(_refresh_core_fill)
	_ensure_top_bar_groups()
	_apply_frame_margins()
	_style_top_cards()
	_wave_preview_base.add_theme_stylebox_override("panel", GameUiStyle.wave_preview_panel())
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
	_wave_route_toggle.custom_minimum_size = Vector2(64.0, 26.0)
	_wave_route_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	_wave_route_toggle.size_flags_vertical = Control.SIZE_SHRINK_END
	_style_button(_wave_route_toggle, GameUiStyle.STROKE_SOFT)
	GameUiStyle.set_button_texture_icon(_wave_route_toggle, UiArtRegistry.get_catalog_icon(&"map_range"), Vector2(14.0, 14.0), &"left", 6.0)
	var wave_header := get_node_or_null("HudChromeLayer/WavePreviewPanel/WavePreviewMargin/WavePreviewContent/WavePreviewHeader") as HBoxContainer
	if wave_header != null:
		wave_header.custom_minimum_size.y = 34.0
		wave_header.clip_contents = true
	var wave_content := get_node_or_null("HudChromeLayer/WavePreviewPanel/WavePreviewMargin/WavePreviewContent") as Control
	if wave_content != null:
		wave_content.clip_contents = true
	_wave_preview_panel.clip_contents = true
	_deploy_rail_base.add_theme_stylebox_override("panel", GameUiStyle.deck_panel())
	GameUiStyle.apply_scroll_style(get_node_or_null("HudChromeLayer/DeployDeck/DeckMargin/ScrollContainer") as ScrollContainer)
	_legend_base.add_theme_stylebox_override("panel", GameUiStyle.legend_panel())
	_style_legend_panel()
	_speed_active_overlay.add_theme_stylebox_override("panel", GameUiStyle.speed_toggle_active())
	_wave_preview_panel.z_index = 18
	_deck_panel.z_index = 12
	_legend_panel.z_index = 14
	_detail_panel.z_index = 40
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
	if _detail_panel.has_signal("purchase_requested"):
		_detail_panel.purchase_requested.connect(func(slot_index: int) -> void: shop_unit_purchase_requested.emit(slot_index))
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
	_core_label.text = _core_title_from_text(core_text)
	_deploy_label.text = deploy_text
	_queue_label.text = queue_text
	_apply_chip_icon(_stage_chip, _phase_icon_id_for_text(queue_text))
	_apply_chip_icon(_core_chip, &"top_core_hp")
	_apply_chip_icon(_deploy_chip, &"top_deploy_limit")
	_apply_chip_icon(_message_chip, &"top_enemy_queue")
	_set_core_progress_from_text(core_text)


func set_core_hp(current: int, max_value: int) -> void:
	_core_hp_current = maxi(current, 0)
	_core_hp_max = maxi(max_value, 0)
	if _core_hp_max <= 0:
		_core_hp_ratio = 0.0
		var tooltip_missing := "%s --/--" % CORE_HP_TITLE
		_core_chip.tooltip_text = tooltip_missing
		_core_track.tooltip_text = tooltip_missing
		_core_fill.tooltip_text = tooltip_missing
	else:
		_core_hp_current = mini(_core_hp_current, _core_hp_max)
		_core_hp_ratio = clampf(float(_core_hp_current) / float(_core_hp_max), 0.0, 1.0)
		var tooltip_value := "%s %d/%d" % [CORE_HP_TITLE, _core_hp_current, _core_hp_max]
		_core_chip.tooltip_text = tooltip_value
		_core_track.tooltip_text = tooltip_value
		_core_fill.tooltip_text = tooltip_value
	_core_label.text = CORE_HP_TITLE
	_refresh_core_fill()


func show_message(text_value: String) -> void:
	_message_label.text = text_value


func set_resource_values(resource_text: String, tooltip_text_value: String = "") -> void:
	_resource_label.text = resource_text
	_resource_label.tooltip_text = tooltip_text_value
	set_resource_items({
		&"ap": {"icon": "AP", "value": resource_text.replace("\n", " ")}
	}, tooltip_text_value)


func set_resource_items(resource_items: Dictionary, tooltip_text_value: String = "") -> void:
	for resource_key in RESOURCE_ORDER:
		var item: Dictionary = _resource_item_controls.get(resource_key, {})
		if item.is_empty():
			continue
		var root := item.get("root") as Control
		var icon_label := item.get("icon") as Label
		var icon_texture := item.get("icon_texture") as TextureRect
		var value_label := item.get("value") as Label
		var delta_label := item.get("delta") as Label
		var delta_badge := item.get("delta_badge") as Control
		if root == null or icon_label == null or icon_texture == null or value_label == null or delta_label == null:
			continue
		var data: Dictionary = resource_items.get(resource_key, {})
		if data.is_empty():
			root.visible = false
			continue
		root.visible = true
		root.tooltip_text = String(data.get("tooltip", tooltip_text_value))
		var texture := UiArtRegistry.get_catalog_icon(StringName(data.get("icon_key", "resource_%s" % String(resource_key))))
		icon_texture.texture = texture
		icon_texture.visible = texture != null
		icon_label.visible = texture == null
		icon_label.text = String(data.get("icon", _resource_default_icon(resource_key)))
		value_label.text = String(data.get("value", "--"))
		var delta_text := String(data.get("delta", ""))
		delta_label.text = delta_text
		var delta_visible := not delta_text.strip_edges().is_empty()
		delta_label.visible = delta_visible
		if delta_badge != null:
			delta_badge.visible = delta_visible


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
	var pause_texture := UiArtRegistry.get_catalog_icon(&"top_play" if pause_selected else &"top_pause")
	_pause_button.text = "" if pause_texture != null else "暂停"
	GameUiStyle.set_button_texture_icon(_pause_button, pause_texture, Vector2(18.0, 18.0), &"center")
	GameUiStyle.set_button_texture_icon(_speed_1_button, null, Vector2(1.0, 1.0))
	GameUiStyle.set_button_texture_icon(_speed_2_button, null, Vector2(1.0, 1.0))
	_style_top_button(_pause_button, pause_selected)
	_style_top_button(_speed_1_button, speed_1_selected)
	_style_top_button(_speed_2_button, speed_2_selected)
	call_deferred("_place_speed_active_overlay", _speed_1_button if speed_1_selected else (_speed_2_button if speed_2_selected else null))


func set_operators(operators: Array[Dictionary]) -> void:
	for child in _deck_container.get_children():
		child.queue_free()
	_cards_by_operator_key.clear()
	for operator_info in operators:
		var operator_key := StringName((operator_info as Dictionary).get("key", ""))
		var card = OPERATOR_CARD_SCENE.instantiate()
		card.setup(operator_key, operator_info)
		if card.has_method("set_compact"):
			card.set_compact(bool(_layout_profile.get("compact", false)))
		card.operator_card_pressed.connect(func(key: StringName) -> void: operator_card_pressed.emit(key))
		if card.has_signal("operator_card_drag_started"):
			card.connect(&"operator_card_drag_started", func(key: StringName) -> void: operator_card_drag_started.emit(key))
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


func show_operator_preview(operator_info: Dictionary, unit_cfg: Dictionary, state: StringName, status_text: String = "") -> void:
	if _detail_panel.has_method("show_operator_preview"):
		_detail_panel.show_operator_preview(operator_info, unit_cfg, state, status_text)
	_apply_responsive_layout()


func show_shop_unit_preview(slot_index: int, unit_id: StringName, unit_cfg: Dictionary, price: int, can_purchase: bool, disabled_reason: String = "") -> void:
	if _detail_panel.has_method("show_shop_unit_preview"):
		_detail_panel.show_shop_unit_preview(slot_index, unit_id, unit_cfg, price, can_purchase, disabled_reason)
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
	_wave_preview_text_min_height = maxf(WAVE_PREVIEW_MIN_TEXT_HEIGHT, float(line_count) * WAVE_PREVIEW_LINE_HEIGHT)
	_wave_preview_label.custom_minimum_size.y = _wave_preview_text_min_height


func _style_button(button: Button, accent: Color) -> void:
	GameUiStyle.center_button_text(button)
	button.add_theme_stylebox_override("normal", GameUiStyle.button(accent))
	button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.08))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_INVERTED)


func _ensure_top_bar_groups() -> void:
	if _top_content_row == null:
		return
	var left_group := _top_content_row.get_node_or_null("LeftStatusGroup") as HBoxContainer
	if left_group == null:
		left_group = HBoxContainer.new()
		left_group.name = "LeftStatusGroup"
		left_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_group.alignment = BoxContainer.ALIGNMENT_BEGIN
		_top_content_row.add_child(left_group)
	var center_group := _top_content_row.get_node_or_null("CenterTimeGroup") as HBoxContainer
	if center_group == null:
		center_group = HBoxContainer.new()
		center_group.name = "CenterTimeGroup"
		center_group.alignment = BoxContainer.ALIGNMENT_CENTER
		_top_content_row.add_child(center_group)
	var right_group := _top_content_row.get_node_or_null("RightResourceGroup") as HBoxContainer
	if right_group == null:
		right_group = HBoxContainer.new()
		right_group.name = "RightResourceGroup"
		right_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_group.alignment = BoxContainer.ALIGNMENT_END
		_top_content_row.add_child(right_group)
	_top_content_row.move_child(left_group, 0)
	_top_content_row.move_child(center_group, 1)
	_top_content_row.move_child(right_group, 2)
	for control in [_stage_chip, _core_chip, _deploy_chip, _message_chip]:
		_reparent_control(control, left_group)
	_reparent_control(_time_controls, center_group)
	_reparent_control(_resource_chip, right_group)
	_build_resource_items()


func _reparent_control(control: Control, target_parent: Control) -> void:
	if control == null or target_parent == null or control.get_parent() == target_parent:
		return
	if control.get_parent() != null:
		control.get_parent().remove_child(control)
	target_parent.add_child(control)


func _build_resource_items() -> void:
	if _resource_chip == null:
		return
	if _resource_label != null:
		_resource_label.visible = false
		_resource_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var resource_row := _resource_chip.get_node_or_null("ResourceItemsRow") as HBoxContainer
	if resource_row == null:
		resource_row = HBoxContainer.new()
		resource_row.name = "ResourceItemsRow"
		resource_row.anchor_right = 1.0
		resource_row.anchor_bottom = 1.0
		resource_row.alignment = BoxContainer.ALIGNMENT_END
		resource_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_resource_chip.add_child(resource_row)
	_apply_control_insets(resource_row, RESOURCE_ROW_INSETS)
	_resource_item_controls.clear()
	for resource_key in RESOURCE_ORDER:
		var item_root := resource_row.get_node_or_null("%sResourceItem" % _resource_node_prefix(resource_key)) as Control
		if item_root == null:
			item_root = _create_resource_item(resource_key)
			resource_row.add_child(item_root)
		var item := {
			"root": item_root,
			"base": item_root.get_node_or_null("ResourceItemBase"),
			"margin": item_root.get_node_or_null("ItemMargin"),
			"icon": item_root.get_node_or_null("ItemMargin/ItemRow/IconLabel"),
			"icon_texture": item_root.get_node_or_null("ItemMargin/ItemRow/IconTexture"),
			"value": item_root.get_node_or_null("ItemMargin/ItemRow/ValueLabel"),
			"delta_badge": item_root.get_node_or_null("ItemMargin/ItemRow/DeltaBadge"),
			"delta": item_root.get_node_or_null("ItemMargin/ItemRow/DeltaBadge/DeltaLabel")
		}
		_resource_item_controls[resource_key] = item


func _create_resource_item(resource_key: StringName) -> Control:
	var item_root := Control.new()
	item_root.name = "%sResourceItem" % _resource_node_prefix(resource_key)
	item_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_root.custom_minimum_size = Vector2(78.0, 48.0)
	var base := Panel.new()
	base.name = "ResourceItemBase"
	base.anchor_right = 1.0
	base.anchor_bottom = 1.0
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_root.add_child(base)
	var margin := MarginContainer.new()
	margin.name = "ItemMargin"
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_margin_constants(margin, RESOURCE_ITEM_INSETS)
	item_root.add_child(margin)
	var row := HBoxContainer.new()
	row.name = "ItemRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)
	var icon_label := Label.new()
	icon_label.name = "IconLabel"
	icon_label.custom_minimum_size = Vector2(24.0, 0.0)
	icon_label.text = _resource_default_icon(resource_key)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_texture := TextureRect.new()
	icon_texture.name = "IconTexture"
	icon_texture.custom_minimum_size = Vector2(24.0, 24.0)
	icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_texture.visible = false
	row.add_child(icon_texture)
	row.add_child(icon_label)
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_label)
	var delta_badge := Panel.new()
	delta_badge.name = "DeltaBadge"
	delta_badge.visible = false
	delta_badge.custom_minimum_size = Vector2(32.0, 22.0)
	delta_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delta_badge.add_theme_stylebox_override("panel", GameUiStyle.resource_delta_badge())
	row.add_child(delta_badge)
	var delta_label := Label.new()
	delta_label.name = "DeltaLabel"
	delta_label.anchor_right = 1.0
	delta_label.anchor_bottom = 1.0
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	delta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delta_badge.add_child(delta_label)
	return item_root


func _resource_node_prefix(resource_key: StringName) -> String:
	match resource_key:
		&"ap":
			return "ActionPoint"
		&"wood":
			return "Wood"
		&"stone":
			return "Stone"
		&"mana":
			return "Mana"
		&"prestige":
			return "Prestige"
		_:
			return "Resource"


func _resource_default_icon(resource_key: StringName) -> String:
	match resource_key:
		&"ap":
			return "AP"
		&"wood":
			return "W"
		&"stone":
			return "S"
		&"mana":
			return "M"
		&"prestige":
			return "P"
		_:
			return "?"


func _phase_icon_id_for_text(text_value: String) -> StringName:
	if text_value.contains("夜"):
		return &"phase_night"
	if text_value.contains("祝福"):
		return &"phase_blessing"
	return &"phase_day"


func _apply_chip_icon(chip: Control, icon_id: StringName) -> void:
	if chip == null:
		return
	var texture := UiArtRegistry.get_catalog_icon(icon_id)
	if texture == null:
		return
	var icon := chip.get_node_or_null("ChipIconTexture") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "ChipIconTexture"
		icon.anchor_left = 0.0
		icon.anchor_top = 0.5
		icon.anchor_right = 0.0
		icon.anchor_bottom = 0.5
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(icon)
	icon.offset_left = TOP_ICON_LEFT
	icon.offset_top = -TOP_ICON_SIZE * 0.5
	icon.offset_right = TOP_ICON_LEFT + TOP_ICON_SIZE
	icon.offset_bottom = TOP_ICON_SIZE * 0.5
	icon.texture = texture
	icon.visible = true


func _style_top_button(button: Button, selected: bool) -> void:
	GameUiStyle.center_button_text(button)
	if button == _pause_button:
		var empty_normal := StyleBoxEmpty.new()
		var empty_hover := StyleBoxEmpty.new()
		var empty_pressed := StyleBoxEmpty.new()
		var empty_disabled := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", empty_normal)
		button.add_theme_stylebox_override("hover", empty_hover)
		button.add_theme_stylebox_override("pressed", empty_pressed)
		button.add_theme_stylebox_override("disabled", empty_disabled)
	else:
		button.add_theme_stylebox_override("normal", GameUiStyle.compact_button(selected))
		button.add_theme_stylebox_override("hover", GameUiStyle.compact_button(true))
		button.add_theme_stylebox_override("pressed", GameUiStyle.compact_button(true))
		button.add_theme_stylebox_override("disabled", GameUiStyle.compact_button(false))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_pressed_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)


func _place_speed_active_overlay(button: Button) -> void:
	if _speed_active_overlay == null or _time_controls == null:
		return
	if button == null or button.disabled or not is_instance_valid(button):
		_speed_active_overlay.visible = false
		return
	var parent_rect := _time_controls.get_global_rect()
	var button_rect := button.get_global_rect()
	_speed_active_overlay.visible = true
	_speed_active_overlay.anchor_left = 0.0
	_speed_active_overlay.anchor_top = 0.0
	_speed_active_overlay.anchor_right = 0.0
	_speed_active_overlay.anchor_bottom = 0.0
	_speed_active_overlay.offset_left = button_rect.position.x - parent_rect.position.x
	_speed_active_overlay.offset_top = button_rect.position.y - parent_rect.position.y
	_speed_active_overlay.offset_right = _speed_active_overlay.offset_left + button_rect.size.x
	_speed_active_overlay.offset_bottom = _speed_active_overlay.offset_top + button_rect.size.y


func _apply_frame_margins() -> void:
	var top_content := get_node_or_null("HudChromeLayer/TopBar/TopContent") as MarginContainer
	if top_content != null:
		_apply_margin_constants(top_content, TOP_CONTENT_INSETS)
	GameUiStyle.apply_frame_margin(get_node_or_null("HudChromeLayer/WavePreviewPanel/WavePreviewMargin") as MarginContainer, GameUiStyle.FRAME_CARD, Vector4(2.0, 0.0, 2.0, 0.0))
	GameUiStyle.apply_frame_margin(get_node_or_null("HudChromeLayer/DeployDeck/DeckMargin") as MarginContainer, GameUiStyle.FRAME_DECK_PANEL)
	GameUiStyle.apply_frame_margin(get_node_or_null("HudChromeLayer/LegendPanel/LegendMargin") as MarginContainer, GameUiStyle.FRAME_LEGEND_PANEL)
	GameUiStyle.apply_frame_margin(get_node_or_null("InteractionLayer/DragGhost/GhostMargin") as MarginContainer, GameUiStyle.FRAME_CARD)


func _style_top_cards() -> void:
	for card in [
		_stage_chip.get_node_or_null("ChipBase") as Panel,
		_core_chip.get_node_or_null("ChipBase") as Panel,
		_deploy_chip.get_node_or_null("ChipBase") as Panel,
		_message_chip.get_node_or_null("ChipBase") as Panel
	]:
		if card != null:
			card.add_theme_stylebox_override("panel", GameUiStyle.top_card())
	if _speed_toggle_base != null:
		_speed_toggle_base.visible = false
		_speed_toggle_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var resource_base := _resource_chip.get_node_or_null("ChipBase") as Panel
	if resource_base != null:
		resource_base.visible = false
		resource_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in _resource_item_controls.values():
		var item_base := (item as Dictionary).get("base") as Panel
		if item_base != null:
			item_base.add_theme_stylebox_override("panel", GameUiStyle.resource_item())
	for label in [_core_label, _deploy_label, _queue_label, _message_label]:
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
	for item in _resource_item_controls.values():
		var item_dict := item as Dictionary
		for label_key in ["icon", "value", "delta"]:
			var label := item_dict.get(label_key) as Label
			if label == null:
				continue
			label.add_theme_color_override("font_color", GameUiStyle.TEXT)
			label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
			label.add_theme_constant_override("shadow_offset_x", 0)
			label.add_theme_constant_override("shadow_offset_y", 0)
			GameUiStyle.center_label_text(label)
		var delta := item_dict.get("delta") as Label
		if delta != null:
			delta.add_theme_color_override("font_color", GameUiStyle.SUCCESS)


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
	_apply_legend_icon("EnemyPathRow", &"legend_enemy_path")
	_apply_legend_icon("DeployTileRow", &"legend_deploy_tile")
	_apply_legend_icon("FriendlyBuildingRow", &"legend_friendly_building")
	_apply_legend_icon("BlockerRow", &"legend_blocker_tile")
	_apply_legend_icon("CoreAreaRow", &"legend_core_area")


func _apply_legend_icon(row_name: String, icon_id: StringName) -> void:
	var row := get_node_or_null("HudChromeLayer/LegendPanel/LegendMargin/LegendVBox/LegendRows/%s" % row_name) as HBoxContainer
	if row == null:
		return
	var texture := UiArtRegistry.get_catalog_icon(icon_id)
	if texture == null:
		return
	var swatch := row.get_node_or_null("Swatch") as CanvasItem
	if swatch != null:
		swatch.visible = false
	var icon := row.get_node_or_null("IconTexture") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "IconTexture"
		icon.custom_minimum_size = Vector2(18.0, 18.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		row.move_child(icon, 0)
	icon.texture = texture
	icon.visible = true


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
	_legend_panel.visible = bool(_layout_profile.get("legend_visible", true))
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
	var right_rect: Rect2 = _layout_profile.get("right_column_rect", _layout_profile.get("detail_panel_rect", _layout_profile.get("detail_rect", Rect2())))
	var detail_rect := right_rect
	if _wave_preview_panel != null and _wave_preview_panel.visible:
		var profile_height := float(_layout_profile.get("wave_preview_height", 124.0))
		var desired_height := maxf(profile_height, _wave_preview_text_min_height + WAVE_PREVIEW_PANEL_BOTTOM_PADDING)
		var max_height := maxf(UiTokens.WAVE_PREVIEW_MIN_HEIGHT, right_rect.size.y * UiTokens.WAVE_PREVIEW_MAX_COLUMN_RATIO)
		var wave_height := clampf(desired_height, UiTokens.WAVE_PREVIEW_MIN_HEIGHT, max_height)
		var min_detail_height := float(_layout_profile.get("detail_min_height", UiTokens.DETAIL_MIN_HEIGHT))
		if right_rect.size.y - wave_height - UNIT_DETAIL_GAP < min_detail_height:
			wave_height = maxf(UiTokens.WAVE_PREVIEW_MIN_HEIGHT, right_rect.size.y - min_detail_height - UNIT_DETAIL_GAP)
		_wave_preview_label.custom_minimum_size.y = maxf(_wave_preview_text_min_height, wave_height - WAVE_PREVIEW_HEADER_TEXT_PADDING)
		_place_control(_wave_preview_panel, Rect2(right_rect.position, Vector2(right_rect.size.x, wave_height)))
		var detail_bottom := right_rect.end.y
		detail_rect.position.y += wave_height + UNIT_DETAIL_GAP
		detail_rect.size.y = maxf(180.0, detail_bottom - detail_rect.position.y)
	else:
		_place_control(_wave_preview_panel, Rect2(right_rect.position, Vector2(right_rect.size.x, 0.0)))
	_place_control(_detail_panel, detail_rect)


func _apply_top_bar_density(viewport_width: float) -> void:
	var widths := UiLayoutRules.top_card_widths(viewport_width)
	var top_height := float(_layout_profile.get("top_card_height", 50.0))
	var compact := bool(_layout_profile.get("compact", false))
	if _top_content_row != null:
		_top_content_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_top_content_row.add_theme_constant_override("separation", int(_layout_profile.get("top_separation", 12.0)))
	for group_name in ["LeftStatusGroup", "CenterTimeGroup", "RightResourceGroup"]:
		var group: HBoxContainer = null
		if _top_content_row != null:
			group = _top_content_row.get_node_or_null(group_name) as HBoxContainer
		if group != null:
			group.add_theme_constant_override("separation", 6 if compact else 8)
	var card_height := maxf(54.0, top_height - TOP_CONTENT_INSETS.y - TOP_CONTENT_INSETS.w)
	var show_message_card := float(widths.get("message", 0.0)) > 0.0
	if _message_chip != null:
		_message_chip.visible = show_message_card
	_set_top_card_min(_stage_chip, widths.get("stage", 190.0), card_height)
	_set_top_card_min(_core_chip, widths.get("core", 190.0), card_height)
	_set_top_card_min(_deploy_chip, widths.get("deploy", 160.0), card_height)
	_set_top_card_min(_message_chip, widths.get("message", 260.0), card_height)
	_set_top_card_min(_time_controls, widths.get("time", 200.0), card_height)
	_apply_top_chip_content_layout(card_height, compact)
	_apply_core_bar_layout(card_height, compact)
	var resource_item_width := float(widths.get("resource_item", 74.0))
	var resource_total_width := resource_item_width * float(RESOURCE_ORDER.size()) + float(maxi(RESOURCE_ORDER.size() - 1, 0)) * (6.0 if compact else 8.0) + 8.0
	_set_top_card_min(_resource_chip, resource_total_width, card_height)
	var resource_row: HBoxContainer = null
	if _resource_chip != null:
		resource_row = _resource_chip.get_node_or_null("ResourceItemsRow") as HBoxContainer
	if resource_row != null:
		resource_row.add_theme_constant_override("separation", 6 if compact else 8)
		_apply_control_insets(resource_row, RESOURCE_ROW_INSETS)
	for item in _resource_item_controls.values():
		var root := (item as Dictionary).get("root") as Control
		if root != null:
			root.custom_minimum_size = Vector2(resource_item_width, maxf(48.0, card_height - 8.0))
		var margin := (item as Dictionary).get("margin") as MarginContainer
		if margin != null:
			_apply_margin_constants(margin, RESOURCE_ITEM_INSETS_COMPACT if compact else RESOURCE_ITEM_INSETS)
	var label_size := 13 if compact else 14
	for label in [_core_label, _deploy_label, _queue_label, _message_label]:
		label.add_theme_font_size_override("font_size", label_size)
	for item in _resource_item_controls.values():
		var item_dict := item as Dictionary
		var icon_label := item_dict.get("icon") as Label
		var icon_texture := item_dict.get("icon_texture") as TextureRect
		var value_label := item_dict.get("value") as Label
		var delta_label := item_dict.get("delta") as Label
		if icon_label != null:
			icon_label.add_theme_font_size_override("font_size", 11 if compact else 12)
			icon_label.custom_minimum_size = Vector2(24.0 if compact else 26.0, 0.0)
		if icon_texture != null:
			icon_texture.custom_minimum_size = Vector2(24.0 if compact else 26.0, 24.0 if compact else 26.0)
		if value_label != null:
			value_label.add_theme_font_size_override("font_size", 13)
		if delta_label != null:
			delta_label.add_theme_font_size_override("font_size", 10)
	var button_height := 44.0 if compact else 46.0
	_pause_button.custom_minimum_size = Vector2(52.0 if compact else 56.0, button_height)
	_speed_1_button.custom_minimum_size = Vector2(62.0 if compact else 68.0, button_height)
	_speed_2_button.custom_minimum_size = Vector2(62.0 if compact else 68.0, button_height)
	var time_margin := get_node_or_null("HudChromeLayer/TopBar/TopContent/TopContentRow/CenterTimeGroup/TimeControls/TimeMargin") as MarginContainer
	if time_margin == null:
		time_margin = get_node_or_null("HudChromeLayer/TopBar/TopContent/TopContentRow/TimeControls/TimeMargin") as MarginContainer
	if time_margin != null:
		_apply_margin_constants(time_margin, TIME_BUTTON_ROW_INSETS)


func _set_top_card_min(card: Control, width: float, height: float) -> void:
	if card != null:
		card.custom_minimum_size = Vector2(width, height)


func _apply_top_chip_content_layout(_card_height: float, _compact: bool) -> void:
	_apply_control_insets(_queue_label, TOP_CHIP_LABEL_INSETS)
	_apply_control_insets(_deploy_label, TOP_CHIP_LABEL_INSETS)
	_apply_control_insets(_message_label, TOP_MESSAGE_LABEL_INSETS)


func _apply_control_insets(control: Control, insets: Vector4) -> void:
	if control == null:
		return
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = insets.x
	control.offset_top = insets.y
	control.offset_right = -insets.z
	control.offset_bottom = -insets.w


func _apply_margin_constants(container: MarginContainer, insets: Vector4) -> void:
	if container == null:
		return
	container.add_theme_constant_override("margin_left", int(round(insets.x)))
	container.add_theme_constant_override("margin_top", int(round(insets.y)))
	container.add_theme_constant_override("margin_right", int(round(insets.z)))
	container.add_theme_constant_override("margin_bottom", int(round(insets.w)))


func _apply_core_bar_layout(card_height: float, compact: bool) -> void:
	if _core_label != null:
		_core_label.anchor_left = 0.0
		_core_label.anchor_top = 0.0
		_core_label.anchor_right = 1.0
		_core_label.anchor_bottom = 0.0
		_core_label.offset_left = TOP_CORE_LABEL_LEFT - (4.0 if compact else 0.0)
		_core_label.offset_top = TOP_CORE_LABEL_TOP
		_core_label.offset_right = -TOP_CORE_BAR_RIGHT
		_core_label.offset_bottom = TOP_CORE_LABEL_TOP + TOP_CORE_LABEL_HEIGHT
		_core_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _core_track != null:
		_core_track.anchor_left = 0.0
		_core_track.anchor_top = 0.0
		_core_track.anchor_right = 1.0
		_core_track.anchor_bottom = 0.0
		_core_track.offset_left = TOP_CORE_BAR_LEFT - (4.0 if compact else 0.0)
		_core_track.offset_top = card_height - TOP_CORE_BAR_BOTTOM - TOP_CORE_BAR_HEIGHT
		_core_track.offset_right = -TOP_CORE_BAR_RIGHT
		_core_track.offset_bottom = card_height - TOP_CORE_BAR_BOTTOM
	if _core_fill != null and _core_track != null:
		_refresh_core_fill()


func _core_title_from_text(core_text: String) -> String:
	for token in core_text.split("\n", false):
		var title := token.strip_edges()
		if title.is_empty() or title.contains("/"):
			continue
		return title
	return CORE_HP_TITLE


func _set_core_progress_from_text(core_text: String) -> void:
	var ratio := _core_hp_ratio
	var parsed_hp_text := false
	for token in core_text.split("\n", false):
		var slash_index := token.find("/")
		if slash_index <= 0:
			continue
		parsed_hp_text = true
		var current_text := token.substr(0, slash_index).strip_edges()
		var max_text := token.substr(slash_index + 1).strip_edges()
		if current_text.is_valid_int() and max_text.is_valid_int():
			var max_value := max_text.to_int()
			if max_value <= 0:
				ratio = 0.0
			else:
				ratio = clampf(float(current_text.to_int()) / float(max_value), 0.0, 1.0)
			break
		else:
			ratio = 0.0
	if parsed_hp_text:
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
