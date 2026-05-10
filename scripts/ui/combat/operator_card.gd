extends PanelContainer

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiTokens = preload("res://scripts/ui/ui_tokens.gd")

signal operator_card_pressed(operator_key: StringName)

var operator_key := StringName()
var _state := &"ready"
var _accent := GameUiStyle.ACCENT
var _hovered := false
var _compact := false

@onready var _title_plate: PanelContainer = %TitlePlate
@onready var _name_label: Label = %NameLabel
@onready var _cost_badge: PanelContainer = %CostBadge
@onready var _cost_label: Label = %CostLabel
@onready var _portrait_box: PanelContainer = %PortraitBox
@onready var _portrait_label: Label = %PortraitLabel
@onready var _cooldown_overlay: ColorRect = %CooldownOverlay
@onready var _cooldown_label: Label = %CooldownLabel
@onready var _class_label: Label = %ClassLabel
@onready var _state_label: Label = %StateLabel
@onready var _hp_stat_row: PanelContainer = %HpStatRow
@onready var _sp_stat_row: PanelContainer = %SpStatRow
@onready var _cd_stat_row: PanelContainer = %CdStatRow
@onready var _hp_stat_label: Label = %HpStatLabel
@onready var _sp_stat_label: Label = %SpStatLabel
@onready var _cd_stat_label: Label = %CdStatLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_state_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_portrait_label.add_theme_color_override("font_color", GameUiStyle.ACCENT)
	_cooldown_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	for label in [_hp_stat_label, _sp_stat_label, _cd_stat_label]:
		label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	for label in [_name_label, _cost_label, _class_label, _state_label, _hp_stat_label, _sp_stat_label, _cd_stat_label]:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_add_label_shadow(_name_label)
	_add_label_shadow(_cost_label)
	_add_label_shadow(_class_label)
	_add_label_shadow(_state_label)
	_add_label_shadow(_portrait_label)
	_add_label_shadow(_cooldown_label)
	_add_label_shadow(_hp_stat_label)
	_add_label_shadow(_sp_stat_label)
	_add_label_shadow(_cd_stat_label)
	GameUiStyle.apply_frame_margin(get_node_or_null("CardMargin") as MarginContainer, GameUiStyle.FRAME_OPERATOR_CARD)
	_title_plate.add_theme_stylebox_override("panel", GameUiStyle.compact_panel(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_DARK, false))
	_cost_badge.add_theme_stylebox_override("panel", GameUiStyle.operator_cost_badge())
	_portrait_box.add_theme_stylebox_override("panel", GameUiStyle.operator_portrait_slot())
	for row in [_hp_stat_row, _sp_stat_row, _cd_stat_row]:
		row.add_theme_stylebox_override("panel", GameUiStyle.operator_stat_row())
	_cooldown_overlay.color = Color(0.160, 0.035, 0.032, 0.72)
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
	if state == &"deployed":
		accent = GameUiStyle.SUCCESS
	elif state == &"cooldown":
		accent = GameUiStyle.DANGER
	_state = state
	_accent = accent
	_parse_display_text(text_value)
	_update_cooldown_overlay(state)
	_state_label.add_theme_color_override("font_color", _accent if state != &"ready" else GameUiStyle.TEXT_INVERTED_DIM)
	_apply_card_style()


func _parse_display_text(text_value: String) -> void:
	var lines := text_value.split("\n", false)
	_name_label.text = lines[0] if lines.size() > 0 else str(operator_key)
	var meta := lines[1] if lines.size() > 1 else ""
	_class_label.text = meta
	var cost := "--"
	var marker := "COST "
	var cost_index := meta.find(marker)
	if cost_index >= 0:
		cost = meta.substr(cost_index + marker.length()).strip_edges()
		_class_label.text = meta.substr(0, cost_index).strip_edges()
	else:
		marker = "费用 "
		cost_index = meta.find(marker)
		if cost_index >= 0:
			cost = meta.substr(cost_index + marker.length()).strip_edges()
			_class_label.text = meta.substr(0, cost_index).strip_edges()
		else:
			_normalize_meta_without_cost(meta)
	_cost_label.text = "◆%s" % cost
	_state_label.text = _state_label_text()
	_hp_stat_label.text = lines[2] if lines.size() > 2 else "HP --"
	_sp_stat_label.text = lines[3] if lines.size() > 3 else "SP --"
	_cd_stat_label.text = lines[4] if lines.size() > 4 else "CD READY"


func _update_cooldown_overlay(state: StringName) -> void:
	if _cooldown_overlay == null or _cooldown_label == null:
		return
	if state != &"cooldown":
		_cooldown_overlay.visible = false
		return
	_cooldown_overlay.visible = true
	_cooldown_label.text = _format_cooldown_overlay_text(_cd_stat_label.text)


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
			return


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		operator_card_pressed.emit(operator_key)
		accept_event()


func _apply_card_style() -> void:
	add_theme_stylebox_override("panel", GameUiStyle.operator_card_state(_state, _hovered))


func _apply_density() -> void:
	custom_minimum_size = UiTokens.OPERATOR_CARD_COMPACT_SIZE if _compact else UiTokens.OPERATOR_CARD_SIZE
	_portrait_box.custom_minimum_size = Vector2(0.0, 48.0 if _compact else 54.0)
	_name_label.add_theme_font_size_override("font_size", 14 if _compact else 15)
	_cost_label.add_theme_font_size_override("font_size", 12 if _compact else 13)
	_class_label.add_theme_font_size_override("font_size", 12 if _compact else 13)
	_state_label.add_theme_font_size_override("font_size", 12)
	for label in [_hp_stat_label, _sp_stat_label, _cd_stat_label]:
		label.add_theme_font_size_override("font_size", 10 if _compact else 11)
	for row in [_hp_stat_row, _sp_stat_row, _cd_stat_row]:
		row.custom_minimum_size.y = 15.0 if _compact else 16.0
	_portrait_label.add_theme_font_size_override("font_size", 24 if _compact else 26)
	_cooldown_label.add_theme_font_size_override("font_size", 22 if _compact else 24)


func _state_label_text() -> String:
	match _state:
		&"deployed":
			return "在场"
		&"cooldown":
			return "冷却"
		_:
			return "待部署"


func _add_label_shadow(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
