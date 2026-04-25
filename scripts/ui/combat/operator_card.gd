extends Button

const CombatUiStyle = preload("res://scripts/ui/combat/combat_ui_style.gd")

signal operator_card_pressed(operator_key: StringName)

var operator_key := StringName()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(152.0, 86.0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	gui_input.connect(_on_gui_input)
	add_theme_color_override("font_color", CombatUiStyle.TEXT)


func setup(new_operator_key: StringName) -> void:
	operator_key = new_operator_key


func set_state_text(text_value: String, state: StringName) -> void:
	text = text_value
	var accent: Color = CombatUiStyle.ACCENT
	if state == &"deployed":
		accent = CombatUiStyle.AMBER
	elif state == &"cooldown":
		accent = CombatUiStyle.DANGER
	add_theme_stylebox_override("normal", CombatUiStyle.button(accent, 0.28))
	add_theme_stylebox_override("hover", CombatUiStyle.button(accent, 0.42))
	add_theme_stylebox_override("pressed", CombatUiStyle.button(accent, 0.55))


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		operator_card_pressed.emit(operator_key)
		accept_event()
