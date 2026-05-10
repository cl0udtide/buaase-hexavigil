extends PanelContainer

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiTokens = preload("res://scripts/ui/ui_tokens.gd")

signal operator_card_pressed(operator_key: StringName)

var operator_key := StringName()
var _state := &"ready"
var _accent := GameUiStyle.ACCENT
var _fill := GameUiStyle.BG_CARD
var _hovered := false
var _compact := false

@onready var _accent_bar: ColorRect = %AccentBar
@onready var _name_label: Label = %NameLabel
@onready var _cost_label: Label = %CostLabel
@onready var _portrait_box: PanelContainer = %PortraitBox
@onready var _portrait_label: Label = %PortraitLabel
@onready var _cooldown_overlay: ColorRect = %CooldownOverlay
@onready var _cooldown_label: Label = %CooldownLabel
@onready var _class_label: Label = %ClassLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
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
	_name_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	_cost_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_class_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_status_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_portrait_label.add_theme_color_override("font_color", GameUiStyle.ACCENT)
	_cooldown_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	for label in [_name_label, _class_label, _status_label]:
		GameUiStyle.center_label_text(label)
	for label in [_name_label, _cost_label, _class_label, _status_label]:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_add_label_shadow(_name_label)
	_add_label_shadow(_cost_label)
	_add_label_shadow(_class_label)
	_add_label_shadow(_status_label)
	_add_label_shadow(_portrait_label)
	_add_label_shadow(_cooldown_label)
	GameUiStyle.apply_frame_margin(get_node_or_null("CardMargin") as MarginContainer, GameUiStyle.FRAME_OPERATOR_CARD)
	_portrait_box.add_theme_stylebox_override("panel", GameUiStyle.icon_tile())
	_cooldown_overlay.color = Color(0.960, 0.970, 0.980, 0.86)
	_cooldown_overlay.visible = false
	_apply_density()
	_apply_card_style()


func setup(new_operator_key: StringName) -> void:
	operator_key = new_operator_key


func set_compact(compact: bool) -> void:
	_compact = compact
	if is_node_ready():
		_apply_density()


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
	_update_cooldown_overlay(state)
	_status_label.add_theme_color_override("font_color", GameUiStyle.ACCENT if state == &"deployed" else GameUiStyle.TEXT_INVERTED_DIM)
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


func _update_cooldown_overlay(state: StringName) -> void:
	if _cooldown_overlay == null or _cooldown_label == null:
		return
	if state != &"cooldown":
		_cooldown_overlay.visible = false
		return
	_cooldown_overlay.visible = true
	_cooldown_label.text = _format_cooldown_overlay_text(_status_label.text)


func _format_cooldown_overlay_text(status: String) -> String:
	var digits := ""
	for index in range(status.length()):
		var ch := status.substr(index, 1)
		if ch.is_valid_int():
			digits += ch
		elif ch == "." and not digits.contains("."):
			digits += ch
	if digits.is_empty():
		return "CD"
	return "%ds" % int(ceil(float(digits)))


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
	add_theme_stylebox_override("panel", GameUiStyle.operator_card(border))


func _apply_density() -> void:
	custom_minimum_size = UiTokens.OPERATOR_CARD_COMPACT_SIZE if _compact else UiTokens.OPERATOR_CARD_SIZE
	_portrait_box.custom_minimum_size = Vector2(0.0, 50.0 if _compact else 58.0)
	_name_label.add_theme_font_size_override("font_size", 13 if _compact else 14)
	_cost_label.add_theme_font_size_override("font_size", 13 if _compact else 14)
	_class_label.add_theme_font_size_override("font_size", 12 if _compact else 13)
	_status_label.add_theme_font_size_override("font_size", 12 if _compact else 13)
	_portrait_label.add_theme_font_size_override("font_size", 22 if _compact else 24)
	_cooldown_label.add_theme_font_size_override("font_size", 20 if _compact else 22)


func _add_label_shadow(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
