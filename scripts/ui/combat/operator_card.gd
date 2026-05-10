extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiTokens = preload("res://scripts/ui/ui_tokens.gd")

signal operator_card_pressed(operator_key: StringName)
signal operator_card_drag_started(operator_key: StringName)

const DRAG_START_THRESHOLD := 10.0

var operator_key := StringName()
var _state := &"ready"
var _accent := GameUiStyle.ACCENT
var _hovered := false
var _compact := false
var _pressing := false
var _press_start_position := Vector2.ZERO
var _drag_started := false
var _unit_cfg: Dictionary = {}

@onready var _card_base: Panel = %CardBase
@onready var _card_content: MarginContainer = %CardContent
@onready var _title_strip: Panel = %TitleStrip
@onready var _name_label: Label = %NameLabel
@onready var _cost_badge: Panel = %CostBadge
@onready var _cost_label: Label = %CostLabel
@onready var _portrait_stack: Control = %PortraitStack
@onready var _portrait_backplate: Panel = %PortraitBackplate
@onready var _portrait_texture: TextureRect = %PortraitTexture
@onready var _portrait_frame: Panel = %PortraitFrame
@onready var _portrait_label: Label = %PortraitLabel
@onready var _selected_overlay: Panel = %SelectedOverlay
@onready var _deployed_overlay: Panel = %DeployedOverlay
@onready var _cooldown_overlay: TextureRect = %CooldownOverlay
@onready var _cooldown_label: Label = %CooldownLabel
@onready var _class_icon_texture: TextureRect = %ClassIcon
@onready var _class_label: Label = %ClassLabel
@onready var _state_label: Label = %StateLabel
@onready var _hp_stat_row: Panel = %HpStatRow
@onready var _sp_stat_row: Panel = %SpStatRow
@onready var _cd_stat_row: Panel = %CdStatRow
@onready var _hp_stat_label: Label = %HpStatLabel
@onready var _sp_stat_label: Label = %SpStatLabel
@onready var _cd_stat_label: Label = %CdStatLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_set_descendant_mouse_filter_ignore(self)
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
	GameUiStyle.apply_frame_margin(_card_content, GameUiStyle.FRAME_OPERATOR_CARD)
	_title_strip.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_OPERATOR_TITLE_STRIP, GameUiStyle.BG_DARK, GameUiStyle.STROKE_SOFT, false))
	_cost_badge.add_theme_stylebox_override("panel", GameUiStyle.operator_cost_badge())
	_portrait_backplate.add_theme_stylebox_override("panel", GameUiStyle.operator_portrait_slot())
	_portrait_frame.add_theme_stylebox_override("panel", GameUiStyle.operator_portrait_frame())
	_portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_class_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_class_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_class_icon_texture.custom_minimum_size = Vector2(18.0, 18.0)
	_class_icon_texture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for row in [_hp_stat_row, _sp_stat_row, _cd_stat_row]:
		row.add_theme_stylebox_override("panel", GameUiStyle.operator_stat_row())
	_selected_overlay.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_OPERATOR_CARD_SELECTED, Color(0.950, 0.650, 0.220, 0.06), GameUiStyle.AMBER, false))
	_deployed_overlay.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_OPERATOR_CARD_DEPLOYED, Color(0.290, 0.700, 0.430, 0.08), GameUiStyle.SUCCESS, false))
	_cooldown_overlay.texture = UiArtRegistry.get_texture(GameUiStyle.FRAME_OPERATOR_CARD_COOLDOWN, &"frame")
	_cooldown_overlay.visible = false
	_apply_layering()
	_apply_density()
	_apply_visual_textures()
	_apply_card_style()


func setup(new_operator_key: StringName) -> void:
	operator_key = new_operator_key


func configure(operator_info: Dictionary, unit_cfg: Dictionary) -> void:
	operator_key = StringName(operator_info.get("key", operator_key))
	_unit_cfg = unit_cfg.duplicate(true)
	if is_node_ready():
		_apply_visual_textures()


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
	_refresh_class_icon()


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
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_pressing = true
			_drag_started = false
			_press_start_position = get_global_mouse_position()
			accept_event()
		elif _pressing:
			_pressing = false
			if not _drag_started:
				operator_card_pressed.emit(operator_key)
			accept_event()
	elif event is InputEventMouseMotion and _pressing and not _drag_started:
		if get_global_mouse_position().distance_to(_press_start_position) >= DRAG_START_THRESHOLD:
			_drag_started = true
			operator_card_drag_started.emit(operator_key)
			accept_event()


func _apply_card_style() -> void:
	_card_base.add_theme_stylebox_override("panel", GameUiStyle.operator_card_state(_state, _hovered))
	_selected_overlay.visible = _hovered and _state != &"cooldown"
	_deployed_overlay.visible = _state == &"deployed"
	_cooldown_overlay.visible = _state == &"cooldown"
	if _cooldown_overlay.visible:
		var overlay_key := GameUiStyle.FRAME_OPERATOR_CARD_COOLDOWN_SELECTED if _hovered else GameUiStyle.FRAME_OPERATOR_CARD_COOLDOWN
		_cooldown_overlay.texture = UiArtRegistry.get_texture(overlay_key, &"frame")


func _apply_layering() -> void:
	_card_base.z_index = 0
	_selected_overlay.z_index = 1
	_deployed_overlay.z_index = 1
	_cooldown_overlay.z_index = 1
	_card_content.z_index = 5
	_cooldown_label.z_index = 10
	_portrait_backplate.z_index = 0
	_portrait_frame.z_index = 3
	_portrait_texture.z_index = 5
	_portrait_label.z_index = 5


func _apply_density() -> void:
	custom_minimum_size = UiTokens.OPERATOR_CARD_COMPACT_SIZE if _compact else UiTokens.OPERATOR_CARD_SIZE
	size = custom_minimum_size
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_stack.custom_minimum_size = Vector2(0.0, 52.0 if _compact else 60.0)
	_name_label.add_theme_font_size_override("font_size", 14 if _compact else 15)
	_cost_label.add_theme_font_size_override("font_size", 12 if _compact else 13)
	_class_label.add_theme_font_size_override("font_size", 12 if _compact else 13)
	_state_label.add_theme_font_size_override("font_size", 12)
	for label in [_hp_stat_label, _sp_stat_label, _cd_stat_label]:
		label.add_theme_font_size_override("font_size", 10 if _compact else 11)
	for row in [_hp_stat_row, _sp_stat_row, _cd_stat_row]:
		row.custom_minimum_size.y = 17.0 if _compact else 18.0
	_portrait_label.add_theme_font_size_override("font_size", 24 if _compact else 26)
	_cooldown_label.add_theme_font_size_override("font_size", 22 if _compact else 24)


func _apply_visual_textures() -> void:
	var portrait := UiArtRegistry.get_portrait_texture(_unit_cfg)
	_portrait_texture.texture = portrait
	_portrait_texture.visible = portrait != null
	_portrait_label.visible = portrait == null
	if portrait == null:
		_portrait_label.text = _icon_text(_unit_cfg, "*")
	_refresh_class_icon()


func _refresh_class_icon() -> void:
	if _class_icon_texture == null:
		return
	var class_key := String(_unit_cfg.get("class", "")).strip_edges()
	var texture := UiArtRegistry.get_texture(StringName("icon_class_%s" % class_key), &"icon") if not class_key.is_empty() else null
	_class_icon_texture.texture = texture
	_class_icon_texture.visible = texture != null


func _icon_text(cfg: Dictionary, fallback_text: String) -> String:
	var icon := String(cfg.get("icon_text", "")).strip_edges()
	if not icon.is_empty():
		return icon.substr(0, 1)
	return fallback_text


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


func _set_descendant_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_descendant_mouse_filter_ignore(child)
