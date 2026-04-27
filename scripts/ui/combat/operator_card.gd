extends PanelContainer

const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

signal operator_card_pressed(operator_key: StringName)

var operator_key := StringName()
var _state := &"ready"
var _accent := GameUiStyle.ACCENT
var _fill := GameUiStyle.BG_CARD
var _hovered := false

@onready var _accent_bar: ColorRect = %AccentBar
@onready var _name_label: Label = %NameLabel
@onready var _cost_label: Label = %CostLabel
@onready var _portrait_box: PanelContainer = %PortraitBox
@onready var _portrait_label: Label = %PortraitLabel
@onready var _class_label: Label = %ClassLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(154.0, 136.0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _accent_bar != null:
		_accent_bar.visible = false
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void:
		_hovered = true
		_apply_card_style()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_apply_card_style()
	)
	_name_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_cost_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_class_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_status_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_portrait_label.add_theme_color_override("font_color", Color(0.42, 0.50, 0.54, 0.95))
	_add_label_shadow(_name_label)
	_add_label_shadow(_cost_label)
	_add_label_shadow(_class_label)
	_add_label_shadow(_status_label)
	_add_label_shadow(_portrait_label)
	_portrait_box.add_theme_stylebox_override("panel", GameUiStyle.panel(Color(0.02, 0.025, 0.03, 0.92), Color(0.18, 0.25, 0.30, 0.72), 1.0, 4.0))
	_apply_card_style()


func setup(new_operator_key: StringName) -> void:
	operator_key = new_operator_key


func set_state_text(text_value: String, state: StringName) -> void:
	var accent: Color = GameUiStyle.ACCENT
	var fill := GameUiStyle.BG_CARD
	if state == &"deployed":
		accent = GameUiStyle.AMBER
	elif state == &"cooldown":
		accent = GameUiStyle.DANGER
		fill = GameUiStyle.BG_DISABLED
	_state = state
	_accent = accent
	_fill = fill
	_parse_display_text(text_value)
	if _accent_bar != null:
		_accent_bar.visible = false
	_status_label.add_theme_color_override("font_color", GameUiStyle.TEXT if state == &"deployed" else GameUiStyle.TEXT_DIM)
	_apply_card_style()


func _parse_display_text(text_value: String) -> void:
	var lines := text_value.split("\n", false)
	_name_label.text = lines[0] if lines.size() > 0 else str(operator_key)
	var meta := lines[1] if lines.size() > 1 else ""
	var status := lines[2] if lines.size() > 2 else ""
	if lines.size() > 3:
		status = "\n".join(lines.slice(2))
	_class_label.text = meta
	_status_label.text = status
	var cost := "--"
	var marker := "COST "
	var cost_index := meta.find(marker)
	if cost_index >= 0:
		cost = meta.substr(cost_index + marker.length()).strip_edges()
		_class_label.text = meta.substr(0, cost_index).strip_edges()
	else:
		_normalize_meta_without_cost(meta)
	_cost_label.text = "◆ %s" % cost


func _normalize_meta_without_cost(meta: String) -> void:
	for token in ["READY", "DEPLOYED", "CD"]:
		var token_index := meta.find(token)
		if token_index > 0:
			_class_label.text = meta.substr(0, token_index).strip_edges()
			if _status_label.text.is_empty():
				_status_label.text = meta.substr(token_index).strip_edges()
			return


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		operator_card_pressed.emit(operator_key)
		accept_event()


func _apply_card_style() -> void:
	var border := GameUiStyle.AMBER if _hovered else _accent
	var fill := GameUiStyle.BG_CARD_HOVER if _hovered else _fill
	var width := 1.0
	if _hovered:
		width = 2.0
	elif _state == &"ready":
		width = 1.5
	add_theme_stylebox_override("panel", GameUiStyle.card(border, fill, width))


func _add_label_shadow(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.84))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
