extends Control

const CombatUiStyle = preload("res://scripts/ui/combat/combat_ui_style.gd")

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
	_top_bar.add_theme_stylebox_override("panel", CombatUiStyle.panel(CombatUiStyle.BG_DARK, CombatUiStyle.STROKE, 2.0, 8.0))
	_deck_panel.add_theme_stylebox_override("panel", CombatUiStyle.panel(CombatUiStyle.BG_DARK, CombatUiStyle.STROKE, 2.0, 8.0))
	_drag_ghost.add_theme_stylebox_override("panel", CombatUiStyle.panel(Color(0.08, 0.12, 0.15, 0.82), CombatUiStyle.AMBER, 2.0, 8.0))
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_speed_1_button.pressed.connect(func() -> void: speed_1_pressed.emit())
	_speed_2_button.pressed.connect(func() -> void: speed_2_pressed.emit())
	_debug_button.pressed.connect(func() -> void: debug_drawer_toggle_pressed.emit())
	if _detail_panel.has_signal("cast_skill_requested"):
		_detail_panel.cast_skill_requested.connect(func() -> void: cast_skill_requested.emit())
	if _detail_panel.has_signal("retreat_requested"):
		_detail_panel.retreat_requested.connect(func() -> void: retreat_requested.emit())
	_style_button(_pause_button, CombatUiStyle.STROKE)
	_style_button(_speed_1_button, CombatUiStyle.STROKE)
	_style_button(_speed_2_button, CombatUiStyle.STROKE)
	_style_button(_debug_button, CombatUiStyle.STROKE)
	_drag_ghost.visible = false


func set_top_values(core_text: String, deploy_text: String, queue_text: String) -> void:
	_core_label.text = core_text
	_deploy_label.text = deploy_text
	_queue_label.text = queue_text


func show_message(text_value: String) -> void:
	_message_label.text = text_value


func set_time_controls(paused: bool, speed: float) -> void:
	_pause_button.text = "继续" if paused else "暂停"
	_style_button(_speed_1_button, CombatUiStyle.ACCENT if is_equal_approx(speed, 1.0) else CombatUiStyle.STROKE)
	_style_button(_speed_2_button, CombatUiStyle.ACCENT if is_equal_approx(speed, 2.0) else CombatUiStyle.STROKE)


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


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", CombatUiStyle.button(accent))
	button.add_theme_stylebox_override("hover", CombatUiStyle.button(CombatUiStyle.ACCENT))
	button.add_theme_stylebox_override("pressed", CombatUiStyle.button(CombatUiStyle.AMBER))
