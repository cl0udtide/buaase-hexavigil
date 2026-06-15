extends Control

const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const OperatorProgression = preload("res://scripts/combat/operator_progression.gd")

signal close_requested

const PANEL_SIZE := Vector2(640.0, 560.0)
const ROW_HEIGHT := 40.0

@onready var _panel_base: Panel = get_node_or_null("PanelBase") as Panel
@onready var _header: Control = get_node_or_null("ContentMargin/MainVBox/Header") as Control
@onready var _close_button: Button = get_node_or_null("ContentMargin/MainVBox/Header/CloseButton") as Button
@onready var _scroll: ScrollContainer = get_node_or_null("ContentMargin/MainVBox/CheatScroll") as ScrollContainer
@onready var _body: VBoxContainer = get_node_or_null("ContentMargin/MainVBox/CheatScroll/CheatBody") as VBoxContainer

var _cheat_manager: Node
var _updating := false
var _dragging := false
var _drag_offset := Vector2.ZERO
var _has_custom_position := false
var _cheat_enabled_button: Button
var _infinite_ap_button: Button
var _infinite_resources_button: Button
var _infinite_core_button: Button
var _day_spin_box: SpinBox
var _unit_option: OptionButton
var _unit_star_option: OptionButton
var _relic_option: OptionButton
var _event_option: OptionButton
var _message_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	if _panel_base != null:
		_panel_base.add_theme_stylebox_override("panel", GameUiStyle.relic_panel())
	if _header != null:
		_header.mouse_filter = Control.MOUSE_FILTER_STOP
		_header.mouse_default_cursor_shape = Control.CURSOR_MOVE
		_header.gui_input.connect(_on_header_gui_input)
	if _scroll != null:
		GameUiStyle.apply_scroll_style(_scroll)
	if _close_button != null:
		_close_button.pressed.connect(func() -> void: close_requested.emit())
		_style_button(_close_button)
	_build_controls()
	_cheat_manager = _resolve_cheat_manager()
	_bind_cheat_manager()
	refresh_from_cheat_manager()


func show_panel() -> void:
	visible = true
	_sync_panel_position()
	_cheat_manager = _resolve_cheat_manager()
	_bind_cheat_manager()
	refresh_from_cheat_manager()
	_populate_cheat_options()


func hide_panel() -> void:
	_dragging = false
	visible = false


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func move_panel_to(position_value: Vector2) -> void:
	_has_custom_position = true
	position = _clamp_position(position_value)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_move_to_global(_current_mouse_position() - _drag_offset)
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_dragging = false
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_dragging = true
			_drag_offset = _current_mouse_position() - global_position
			_has_custom_position = true
			accept_event()
		else:
			_dragging = false


func _sync_panel_position() -> void:
	size = PANEL_SIZE
	if _has_custom_position:
		position = _clamp_position(position)
	else:
		position = _center_position()


func _move_to_global(global_top_left: Vector2) -> void:
	var local_position := global_top_left
	var parent_control := get_parent() as Control
	if parent_control != null:
		local_position -= parent_control.global_position
	move_panel_to(local_position)


func _current_mouse_position() -> Vector2:
	var viewport := get_viewport()
	return viewport.get_mouse_position() if viewport != null else Vector2.ZERO


func _center_position() -> Vector2:
	var available_size := _parent_size()
	return Vector2(
		maxf(0.0, (available_size.x - PANEL_SIZE.x) * 0.5),
		maxf(0.0, (available_size.y - PANEL_SIZE.y) * 0.5)
	)


func _clamp_position(position_value: Vector2) -> Vector2:
	var available_size := _parent_size()
	var panel_size := size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = PANEL_SIZE
	var max_x := maxf(0.0, available_size.x - panel_size.x)
	var max_y := maxf(0.0, available_size.y - panel_size.y)
	return Vector2(
		clampf(position_value.x, 0.0, max_x),
		clampf(position_value.y, 0.0, max_y)
	)


func _parent_size() -> Vector2:
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
		return parent_control.size
	var viewport := get_viewport()
	return viewport.get_visible_rect().size if viewport != null else PANEL_SIZE


func refresh_from_cheat_manager() -> void:
	if _cheat_manager == null:
		_cheat_manager = _resolve_cheat_manager()
	if _cheat_manager == null or not _cheat_manager.has_method("get_state"):
		_set_controls_available(false)
		return
	var state: Dictionary = _cheat_manager.get_state()
	_updating = true
	_cheat_enabled_button.button_pressed = bool(state.get("enabled", false))
	_infinite_ap_button.button_pressed = bool(state.get("infinite_action_points", false))
	_infinite_resources_button.button_pressed = bool(state.get("infinite_resources", false))
	_infinite_core_button.button_pressed = bool(state.get("infinite_core_hp", false))
	_updating = false
	_refresh_button_labels()
	_set_controls_available(true)
	_update_body_enabled(bool(state.get("enabled", false)))


func _build_controls() -> void:
	if _body == null:
		return
	_body.add_theme_constant_override("separation", 8)
	_cheat_enabled_button = _make_button("作弊模式：关闭", true)
	_cheat_enabled_button.toggled.connect(_on_cheat_enabled_toggled)
	_body.add_child(_cheat_enabled_button)
	_body.add_child(_make_toggle_row("无限行动力", "_infinite_ap"))
	_body.add_child(_make_toggle_row("资源无限", "_infinite_resources"))
	_body.add_child(_make_toggle_row("核心血量无限", "_infinite_core"))
	_body.add_child(_make_action_row([
		{"text": "补满行动力", "method": "_on_fill_action_points_pressed"},
		{"text": "补满资源", "method": "_on_fill_resources_pressed"},
		{"text": "回满血量", "method": "_on_heal_core_pressed"}
	]))
	_body.add_child(_make_action_row([
		{"text": "迷雾全开", "method": "_on_reveal_all_pressed"},
		{"text": "清除敌人", "method": "_on_clear_enemies_pressed"}
	]))
	_body.add_child(_make_day_row())
	_body.add_child(_make_grant_unit_row())
	_body.add_child(_make_grant_relic_row())
	_body.add_child(_make_spawn_event_row())
	_message_label = Label.new()
	_message_label.custom_minimum_size = Vector2(0.0, 42.0)
	_message_label.add_theme_font_size_override("font_size", 13)
	_message_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.text = "作弊只影响当前局。"
	_body.add_child(_message_label)
	_populate_cheat_options()
	_refresh_button_labels()


func _make_toggle_row(text_value: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_label(text_value, 150.0))
	var button := _make_button("关闭", true)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	match key:
		"_infinite_ap":
			_infinite_ap_button = button
			button.toggled.connect(_on_infinite_ap_toggled)
		"_infinite_resources":
			_infinite_resources_button = button
			button.toggled.connect(_on_infinite_resources_toggled)
		"_infinite_core":
			_infinite_core_button = button
			button.toggled.connect(_on_infinite_core_toggled)
	return row


func _make_action_row(button_defs: Array) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 8)
	for raw_def: Variant in button_defs:
		var button_def := raw_def as Dictionary
		var button := _make_button(String(button_def.get("text", "")))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var method_name := StringName(button_def.get("method", ""))
		if method_name != StringName() and has_method(method_name):
			button.pressed.connect(Callable(self, method_name))
		row.add_child(button)
	return row


func _make_day_row() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	var first_row := HBoxContainer.new()
	first_row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	first_row.add_theme_constant_override("separation", 8)
	first_row.add_child(_make_label("天数", 70.0))
	_day_spin_box = SpinBox.new()
	_day_spin_box.min_value = 1.0
	_day_spin_box.max_value = 9.0
	_day_spin_box.step = 1.0
	_day_spin_box.value = 1.0
	_day_spin_box.custom_minimum_size = Vector2(96.0, 34.0)
	_day_spin_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	first_row.add_child(_day_spin_box)
	first_row.add_child(_make_connected_button("跳转", "_on_jump_day_pressed"))
	first_row.add_child(_make_connected_button("下一天", "_on_next_day_pressed"))
	root.add_child(first_row)
	root.add_child(_make_action_row([
		{"text": "直接进夜晚", "method": "_on_start_night_pressed"},
		{"text": "通关当前夜晚", "method": "_on_clear_night_pressed"}
	]))
	return root


func _make_grant_unit_row() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_label("干员", 70.0))
	_unit_option = OptionButton.new()
	_unit_option.custom_minimum_size = Vector2(260.0, 34.0)
	_unit_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_unit_option)
	_unit_star_option = OptionButton.new()
	_unit_star_option.custom_minimum_size = Vector2(64.0, 34.0)
	_unit_star_option.add_item("1", 1)
	_unit_star_option.add_item("2", 2)
	_unit_star_option.add_item("3", 3)
	_unit_star_option.select(0)
	row.add_child(_unit_star_option)
	row.add_child(_make_connected_button("获得", "_on_grant_unit_pressed"))
	root.add_child(row)
	root.add_child(_make_connected_button("获得全部干员", "_on_grant_all_units_pressed"))
	return root


func _make_grant_relic_row() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_label("遗物", 70.0))
	_relic_option = OptionButton.new()
	_relic_option.custom_minimum_size = Vector2(350.0, 34.0)
	_relic_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_relic_option)
	row.add_child(_make_connected_button("获得", "_on_grant_relic_pressed"))
	root.add_child(row)
	root.add_child(_make_connected_button("获得全部遗物", "_on_grant_all_relics_pressed"))
	return root


func _make_spawn_event_row() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_label("事件", 70.0))
	_event_option = OptionButton.new()
	_event_option.custom_minimum_size = Vector2(350.0, 34.0)
	_event_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_event_option)
	row.add_child(_make_connected_button("投放到已探索区", "_on_spawn_event_pressed"))
	root.add_child(row)
	return root


func _make_connected_button(text_value: String, method_name: String) -> Button:
	var button := _make_button(text_value)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var method_key := StringName(method_name)
	if method_key != StringName() and has_method(method_key):
		button.pressed.connect(Callable(self, method_key))
	return button


func _make_button(text_value: String, toggle := false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 34.0)
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = toggle
	button.text = text_value
	_style_button(button)
	return button


func _style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_pressed_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)
	button.add_theme_stylebox_override("normal", GameUiStyle.compact_button(false))
	button.add_theme_stylebox_override("hover", GameUiStyle.compact_button(true))
	button.add_theme_stylebox_override("pressed", GameUiStyle.compact_button(true))
	button.add_theme_stylebox_override("disabled", GameUiStyle.disabled_button())


func _make_label(text_value: String, width: float) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(width, 0.0)
	label.text = text_value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
	return label


func _bind_cheat_manager() -> void:
	if _cheat_manager == null:
		return
	var state_callable := Callable(self, "_on_cheat_state_changed")
	var result_callable := Callable(self, "_on_cheat_action_result")
	if _cheat_manager.has_signal("cheat_state_changed"):
		if not _cheat_manager.is_connected(&"cheat_state_changed", state_callable):
			_cheat_manager.connect(&"cheat_state_changed", state_callable)
	if _cheat_manager.has_signal("cheat_action_result"):
		if not _cheat_manager.is_connected(&"cheat_action_result", result_callable):
			_cheat_manager.connect(&"cheat_action_result", result_callable)


func _populate_cheat_options() -> void:
	var data_repo = _resolve_data_repo()
	if data_repo == null:
		return
	if _unit_option != null:
		var selected_unit: Variant = _selected_option_metadata(_unit_option)
		_unit_option.clear()
		for unit_id: StringName in data_repo.get_all_unit_ids():
			var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
			var label := "%s (%s)" % [String(cfg.get("name", unit_id)), String(unit_id)]
			_unit_option.add_item(label)
			_unit_option.set_item_metadata(_unit_option.get_item_count() - 1, unit_id)
		_select_option_metadata(_unit_option, selected_unit)
	if _relic_option != null:
		var selected_relic: Variant = _selected_option_metadata(_relic_option)
		_relic_option.clear()
		for buff_id: StringName in data_repo.get_all_buff_ids():
			var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
			var label := "%s (%s)" % [String(cfg.get("name", buff_id)), String(buff_id)]
			_relic_option.add_item(label)
			_relic_option.set_item_metadata(_relic_option.get_item_count() - 1, buff_id)
		_select_option_metadata(_relic_option, selected_relic)
	if _event_option != null:
		var selected_event: Variant = _selected_option_metadata(_event_option)
		_event_option.clear()
		for event_id: StringName in data_repo.get_all_event_ids():
			var cfg: Dictionary = data_repo.get_event_cfg(event_id)
			var label := "%s (%s)" % [String(cfg.get("name", event_id)), String(event_id)]
			_event_option.add_item(label)
			_event_option.set_item_metadata(_event_option.get_item_count() - 1, event_id)
		_select_option_metadata(_event_option, selected_event)


func _selected_option_metadata(option: OptionButton) -> Variant:
	if option == null or option.selected < 0 or option.selected >= option.get_item_count():
		return StringName()
	return option.get_item_metadata(option.selected)


func _select_option_metadata(option: OptionButton, metadata: Variant) -> void:
	if option == null or option.get_item_count() <= 0:
		return
	for index in range(option.get_item_count()):
		if option.get_item_metadata(index) == metadata:
			option.select(index)
			return
	option.select(0)


func _on_cheat_enabled_toggled(enabled: bool) -> void:
	if _updating:
		return
	if _cheat_manager != null and _cheat_manager.has_method("set_cheats_enabled"):
		_report_cheat_result(_cheat_manager.set_cheats_enabled(enabled))


func _on_infinite_ap_toggled(enabled: bool) -> void:
	if _updating:
		return
	if _cheat_manager != null and _cheat_manager.has_method("set_infinite_action_points"):
		_report_cheat_result(_cheat_manager.set_infinite_action_points(enabled))


func _on_infinite_resources_toggled(enabled: bool) -> void:
	if _updating:
		return
	if _cheat_manager != null and _cheat_manager.has_method("set_infinite_resources"):
		_report_cheat_result(_cheat_manager.set_infinite_resources(enabled))


func _on_infinite_core_toggled(enabled: bool) -> void:
	if _updating:
		return
	if _cheat_manager != null and _cheat_manager.has_method("set_infinite_core_hp"):
		_report_cheat_result(_cheat_manager.set_infinite_core_hp(enabled))


func _on_fill_action_points_pressed() -> void:
	_call_cheat("fill_action_points")


func _on_fill_resources_pressed() -> void:
	_call_cheat("fill_resources")


func _on_heal_core_pressed() -> void:
	_call_cheat("heal_core_full")


func _on_reveal_all_pressed() -> void:
	_call_cheat("reveal_all_fog")


func _on_clear_enemies_pressed() -> void:
	_call_cheat("clear_enemies")


func _on_jump_day_pressed() -> void:
	if _cheat_manager != null and _cheat_manager.has_method("jump_to_day"):
		_report_cheat_result(_cheat_manager.jump_to_day(int(_day_spin_box.value)))


func _on_next_day_pressed() -> void:
	_call_cheat("go_next_day")


func _on_start_night_pressed() -> void:
	_call_cheat("start_night_now")


func _on_clear_night_pressed() -> void:
	_call_cheat("clear_current_night")


func _on_grant_unit_pressed() -> void:
	if _cheat_manager == null or not _cheat_manager.has_method("grant_unit"):
		return
	var unit_id := StringName(_selected_option_metadata(_unit_option))
	var star := OperatorProgression.normalize_star(_unit_star_option.get_item_id(_unit_star_option.selected))
	_report_cheat_result(_cheat_manager.grant_unit(unit_id, star))


func _on_grant_all_units_pressed() -> void:
	if _cheat_manager == null or not _cheat_manager.has_method("grant_all_units"):
		return
	var star := OperatorProgression.normalize_star(_unit_star_option.get_item_id(_unit_star_option.selected))
	_report_cheat_result(_cheat_manager.grant_all_units(star))


func _on_grant_relic_pressed() -> void:
	if _cheat_manager == null or not _cheat_manager.has_method("grant_relic"):
		return
	var buff_id := StringName(_selected_option_metadata(_relic_option))
	_report_cheat_result(_cheat_manager.grant_relic(buff_id))


func _on_grant_all_relics_pressed() -> void:
	_call_cheat("grant_all_relics")


func _on_spawn_event_pressed() -> void:
	if _cheat_manager == null or not _cheat_manager.has_method("spawn_event"):
		return
	var event_id := StringName(_selected_option_metadata(_event_option))
	_report_cheat_result(_cheat_manager.spawn_event(event_id))


func _call_cheat(method_name: String) -> void:
	var method_key := StringName(method_name)
	if _cheat_manager == null or method_key == StringName() or not _cheat_manager.has_method(method_key):
		return
	_report_cheat_result(_cheat_manager.call(method_key))


func _on_cheat_state_changed(_state: Dictionary) -> void:
	refresh_from_cheat_manager()


func _on_cheat_action_result(result: Dictionary) -> void:
	_report_cheat_result(result)


func _report_cheat_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	var message := String(result.get("message", ""))
	if message.is_empty():
		message = "操作完成" if bool(result.get("ok", false)) else "操作失败"
	if _message_label != null:
		_message_label.text = message
		_message_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM if bool(result.get("ok", false)) else GameUiStyle.DANGER)
	refresh_from_cheat_manager()


func _refresh_button_labels() -> void:
	if _cheat_enabled_button != null:
		_cheat_enabled_button.text = "作弊模式：开启" if _cheat_enabled_button.button_pressed else "作弊模式：关闭"
	if _infinite_ap_button != null:
		_infinite_ap_button.text = "开启" if _infinite_ap_button.button_pressed else "关闭"
	if _infinite_resources_button != null:
		_infinite_resources_button.text = "开启" if _infinite_resources_button.button_pressed else "关闭"
	if _infinite_core_button != null:
		_infinite_core_button.text = "开启" if _infinite_core_button.button_pressed else "关闭"


func _set_controls_available(available: bool) -> void:
	if _body == null:
		return
	for child in _body.get_children():
		_set_controls_disabled_recursive(child, not available)
	if not available and _message_label != null:
		_message_label.text = "当前场景未接入作弊管理器。"


func _update_body_enabled(cheats_enabled: bool) -> void:
	if _body == null:
		return
	for child in _body.get_children():
		_set_controls_disabled_recursive(child, not cheats_enabled)
	if _cheat_enabled_button != null:
		_cheat_enabled_button.disabled = false


func _set_controls_disabled_recursive(node: Node, disabled: bool) -> void:
	if node is BaseButton:
		(node as BaseButton).disabled = disabled
	elif node is SpinBox:
		(node as SpinBox).editable = not disabled
	elif node is OptionButton:
		(node as OptionButton).disabled = disabled
	for child in node.get_children():
		_set_controls_disabled_recursive(child, disabled)


func _resolve_cheat_manager() -> Node:
	var current_scene := get_tree().current_scene if get_tree() != null else null
	if current_scene != null:
		var scene_cheat := current_scene.get_node_or_null("Managers/CheatManager")
		if scene_cheat != null:
			return scene_cheat
	var cursor: Node = self
	while cursor != null:
		var candidate := cursor.get_node_or_null("Managers/CheatManager")
		if candidate != null:
			return candidate
		cursor = cursor.get_parent()
	return null


func _resolve_data_repo() -> Node:
	var root := get_tree().root if get_tree() != null else null
	return root.get_node_or_null("/root/DataRepo") if root != null else null
