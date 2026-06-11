extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")
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
var _press_start_mouse := Vector2.ZERO
var _drag_started := false
var _operator_info: Dictionary = {}
var _unit_cfg: Dictionary = {}
var _class_icon_label: Label
var _cooldown_icon_texture: TextureRect

@onready var _class_icon_texture: TextureRect = %ClassIcon
@onready var _name_label: Label = %NameLabel
@onready var _selected_overlay: Panel = %SelectedOverlay
@onready var _deployed_overlay: Panel = %DeployedOverlay
@onready var _cooldown_overlay: Panel = %CooldownOverlay
@onready var _cooldown_selected_overlay: Panel = %CooldownSelectedOverlay
@onready var _cooldown_top_content: Control = %CooldownTopContent
@onready var _cooldown_label: Label = %CooldownLabel
@onready var _class_label: Label = %ClassLabel
@onready var _state_label: Label = %StateLabel
@onready var _hp_stat_label: Label = %HpStatLabel
@onready var _sp_stat_label: Label = %SpStatLabel
@onready var _cd_stat_label: Label = %CdStatLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	_apply_name_tier_color()
	_class_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_state_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_cooldown_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	for label in [_hp_stat_label, _sp_stat_label, _cd_stat_label]:
		label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	for label in [_name_label, _class_label, _state_label, _hp_stat_label, _sp_stat_label, _cd_stat_label]:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_add_label_shadow(_name_label)
	_add_label_shadow(_class_label)
	_add_label_shadow(_state_label)
	_add_label_shadow(_cooldown_label)
	_add_label_shadow(_hp_stat_label)
	_add_label_shadow(_sp_stat_label)
	_add_label_shadow(_cd_stat_label)
	_prepare_class_icon_texture()
	_prepare_cooldown_icon_texture()
	_flatten_inner_frames()
	_sync_state_overlays()
	_apply_density()
	_apply_card_style()


func _flatten_inner_frames() -> void:
	# 框层级降档:卡面只留最外层 CardBase 金属框;名牌与 HP/SP 行改平底,
	# CdStatRow 保留胶囊贴图作强调。runtime override 优先于场景资源,可随时回退。
	%TitleStrip.add_theme_stylebox_override("panel", GameUiStyle.flat_box(Color(0.0, 0.0, 0.0, 0.35), Color.TRANSPARENT, 0.0, 3.0))
	%HpStatRow.add_theme_stylebox_override("panel", GameUiStyle.flat_stat_pill())
	%SpStatRow.add_theme_stylebox_override("panel", GameUiStyle.flat_stat_pill())
	var stat_rows := %HpStatRow.get_parent() as VBoxContainer
	if stat_rows != null:
		stat_rows.add_theme_constant_override("separation", 0)


func setup(new_operator_key: StringName, operator_info: Dictionary = {}) -> void:
	operator_key = new_operator_key
	_operator_info = operator_info.duplicate(true)
	_unit_cfg = _resolve_unit_cfg()
	if is_node_ready():
		_apply_unit_art()


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
	var marker := "COST "
	var cost_index := meta.find(marker)
	if cost_index >= 0:
		_class_label.text = meta.substr(0, cost_index).strip_edges()
	else:
		marker = "费用 "
		cost_index = meta.find(marker)
		if cost_index >= 0:
			_class_label.text = meta.substr(0, cost_index).strip_edges()
		else:
			_normalize_meta_without_cost(meta)
	_apply_unit_art()
	_state_label.text = _state_label_text()
	_hp_stat_label.text = lines[2] if lines.size() > 2 else "HP --"
	_sp_stat_label.text = lines[3] if lines.size() > 3 else "SP --"
	_cd_stat_label.text = lines[4] if lines.size() > 4 else "CD 就绪"


func _update_cooldown_overlay(state: StringName) -> void:
	if _cooldown_overlay == null or _cooldown_label == null:
		return
	if state == &"cooldown":
		_cooldown_label.text = _format_cooldown_overlay_text(_cd_stat_label.text)
	if _cooldown_icon_texture != null:
		_cooldown_icon_texture.visible = state == &"cooldown"
	_sync_state_overlays()


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
	for token in ["READY", "DEPLOYED", "CD", "就绪"]:
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
			_press_start_mouse = get_global_mouse_position()
			accept_event()
		elif _pressing:
			_pressing = false
			if not _drag_started:
				operator_card_pressed.emit(operator_key)
			accept_event()
	elif event is InputEventMouseMotion and _pressing and not _drag_started:
		if get_global_mouse_position().distance_to(_press_start_mouse) >= DRAG_START_THRESHOLD:
			_drag_started = true
			operator_card_drag_started.emit(operator_key)
			accept_event()


func _apply_card_style() -> void:
	_sync_state_overlays()


func _sync_state_overlays() -> void:
	if _selected_overlay != null:
		_selected_overlay.visible = _hovered and _state != &"cooldown"
	if _deployed_overlay != null:
		_deployed_overlay.visible = _state == &"deployed"
	var is_cooldown := _state == &"cooldown"
	if _cooldown_overlay != null:
		_cooldown_overlay.visible = is_cooldown and not _hovered
	if _cooldown_selected_overlay != null:
		_cooldown_selected_overlay.visible = is_cooldown and _hovered
	if _cooldown_top_content != null:
		_cooldown_top_content.visible = is_cooldown
	if _cooldown_icon_texture != null:
		_cooldown_icon_texture.visible = is_cooldown


func _apply_density() -> void:
	set_custom_minimum_size(UiTokens.OPERATOR_CARD_COMPACT_SIZE if _compact else UiTokens.OPERATOR_CARD_SIZE)
	set_size(custom_minimum_size)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label.add_theme_font_size_override("font_size", 14 if _compact else 15)
	_class_label.add_theme_font_size_override("font_size", 13)
	_state_label.add_theme_font_size_override("font_size", 13)
	for label in [_hp_stat_label, _sp_stat_label, _cd_stat_label]:
		label.add_theme_font_size_override("font_size", 12)
	_cooldown_label.add_theme_font_size_override("font_size", 22 if _compact else 24)


func _state_label_text() -> String:
	match _state:
		&"deployed":
			return "在场"
		&"cooldown":
			return "冷却"
		_:
			return "待部署"


func _resolve_unit_cfg() -> Dictionary:
	var unit_id := StringName(_operator_info.get("unit_id", ""))
	if unit_id == StringName():
		return {}
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return {}
	return data_repo.get_unit_cfg(unit_id)


func _apply_unit_art() -> void:
	_apply_name_tier_color()
	if _unit_cfg.is_empty():
		return
	var class_texture := UiArtRegistry.get_class_icon_texture(_unit_cfg)
	if _class_icon_texture != null:
		_class_icon_texture.texture = class_texture
		_class_icon_texture.visible = class_texture != null
	if _class_icon_label != null:
		_class_icon_label.visible = class_texture == null
		_class_icon_label.text = UiDisplayText.class_label(String(_unit_cfg.get("class", ""))).substr(0, 1)


func _apply_name_tier_color() -> void:
	if _name_label == null:
		return
	if _unit_cfg.is_empty():
		_name_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
		return
	_name_label.add_theme_color_override("font_color", UiDisplayText.tier_color(int(_unit_cfg.get("cost_prestige", 0))))


func _prepare_class_icon_texture() -> void:
	if _class_icon_texture == null:
		return
	_class_icon_texture.set_custom_minimum_size(Vector2(18.0, 18.0))
	_class_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_class_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_class_icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _class_icon_label != null:
		return
	var parent := _class_icon_texture.get_parent()
	if parent == null:
		return
	_class_icon_label = Label.new()
	_class_icon_label.name = "ClassIconFallback"
	_class_icon_label.set_custom_minimum_size(Vector2(18.0, 18.0))
	_class_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_class_icon_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	_class_icon_label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
	_class_icon_label.add_theme_constant_override("shadow_offset_x", 0)
	_class_icon_label.add_theme_constant_override("shadow_offset_y", 0)
	_class_icon_label.visible = false
	parent.add_child(_class_icon_label)
	parent.move_child(_class_icon_label, _class_icon_texture.get_index() + 1)


func _prepare_cooldown_icon_texture() -> void:
	if _cooldown_top_content == null or _cooldown_icon_texture != null:
		return
	_cooldown_icon_texture = TextureRect.new()
	_cooldown_icon_texture.name = "CooldownIconTexture"
	_cooldown_icon_texture.anchor_left = 0.5
	_cooldown_icon_texture.anchor_top = 0.5
	_cooldown_icon_texture.anchor_right = 0.5
	_cooldown_icon_texture.anchor_bottom = 0.5
	_cooldown_icon_texture.offset_left = -14.0
	_cooldown_icon_texture.offset_top = -34.0
	_cooldown_icon_texture.offset_right = 14.0
	_cooldown_icon_texture.offset_bottom = -6.0
	_cooldown_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cooldown_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cooldown_icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_icon_texture.texture = UiArtRegistry.get_catalog_icon(&"combat_cooldown")
	_cooldown_icon_texture.visible = false
	_cooldown_top_content.add_child(_cooldown_icon_texture)


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
