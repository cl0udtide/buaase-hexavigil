extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

signal operator_card_pressed(operator_key: StringName)
signal pause_pressed
signal speed_1_pressed
signal speed_2_pressed
signal debug_drawer_toggle_pressed
signal cast_skill_requested
signal retreat_requested

const OPERATOR_CARD_SCENE := preload("res://scenes/ui/combat/OperatorCard.tscn")

var _cards_by_operator_key: Dictionary = {}

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
@onready var _deck_panel: PanelContainer = %DeployDeck
@onready var _deck_container: HBoxContainer = %DeployDeckContainer
@onready var _detail_panel: PanelContainer = %UnitDetailPanel
@onready var _drag_ghost: PanelContainer = %DragGhost
@onready var _drag_ghost_label: Label = %DragGhostLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AppTheme.apply(self)
	_top_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_style_top_cards()
	_deck_panel.add_theme_stylebox_override("panel", GameUiStyle.panel(GameUiStyle.BG_DARK, GameUiStyle.STROKE_SOFT, 1.0, 6.0))
	_drag_ghost.add_theme_stylebox_override("panel", GameUiStyle.panel(Color(0.08, 0.10, 0.11, 0.88), GameUiStyle.AMBER, 2.0, 6.0))
	_drag_ghost_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_speed_1_button.pressed.connect(func() -> void: speed_1_pressed.emit())
	_speed_2_button.pressed.connect(func() -> void: speed_2_pressed.emit())
	_debug_button.pressed.connect(func() -> void: debug_drawer_toggle_pressed.emit())
	if _detail_panel.has_signal("cast_skill_requested"):
		_detail_panel.cast_skill_requested.connect(func() -> void: cast_skill_requested.emit())
	if _detail_panel.has_signal("retreat_requested"):
		_detail_panel.retreat_requested.connect(func() -> void: retreat_requested.emit())
	_style_button(_pause_button, GameUiStyle.STROKE)
	_style_button(_speed_1_button, GameUiStyle.STROKE)
	_style_button(_speed_2_button, GameUiStyle.STROKE)
	_style_button(_debug_button, GameUiStyle.STROKE)
	_drag_ghost.visible = false


func set_top_values(core_text: String, deploy_text: String, queue_text: String) -> void:
	_core_label.text = core_text
	_deploy_label.text = deploy_text
	_queue_label.text = queue_text


func show_message(text_value: String) -> void:
	_message_label.text = text_value


func set_resource_values(resource_text: String, tooltip_text_value: String = "") -> void:
	_resource_label.text = resource_text
	_resource_label.tooltip_text = tooltip_text_value


func set_time_controls(paused: bool, speed: float) -> void:
	_pause_button.text = "继续" if paused else "暂停"
	_style_button(_speed_1_button, GameUiStyle.ACCENT if is_equal_approx(speed, 1.0) else GameUiStyle.STROKE)
	_style_button(_speed_2_button, GameUiStyle.ACCENT if is_equal_approx(speed, 2.0) else GameUiStyle.STROKE)


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


func clear_unit_detail() -> void:
	if _detail_panel.has_method("clear_unit"):
		_detail_panel.clear_unit()


func set_left_reserved_width(width: float) -> void:
	_deck_panel.offset_left = max(18.0, width + 14.0)


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", GameUiStyle.button(accent))
	button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.08))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)


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
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_message_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
