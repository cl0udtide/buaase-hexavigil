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
const TITLE_ICON_WIDTH := 18.0
const TITLE_ICON_NAME_GAP := 4.0
const TITLE_NAME_HORIZONTAL_PADDING := 2.0
const TITLE_NAME_MAX_WIDTH_FALLBACK := 86.0

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
var _covenant_badge: Label

@onready var _card_base: Panel = %CardBase
@onready var _card_content: MarginContainer = %CardContent
@onready var _title_row: HBoxContainer = get_node("CardContent/VBox/TitleStrip/TitleMargin/TitleRow") as HBoxContainer
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
	resized.connect(_sync_card_rects)
	_apply_label_colors()
	_state_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_cooldown_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	for label in [_hp_stat_label, _sp_stat_label, _cd_stat_label]:
		label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	for label in [_name_label, _class_label, _state_label, _hp_stat_label, _sp_stat_label, _cd_stat_label]:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_add_label_shadow(_name_label)
	_add_label_shadow(_class_label)
	_add_label_shadow(_state_label)
	_add_label_shadow(_cooldown_label)
	_add_label_shadow(_hp_stat_label)
	_add_label_shadow(_sp_stat_label)
	_add_label_shadow(_cd_stat_label)
	_prepare_class_icon_texture()
	_prepare_cooldown_icon_texture()
	_sync_state_overlays()
	_apply_density()
	_apply_card_style()


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
	var lines: PackedStringArray = text_value.split("\n", false)
	var raw_name: String = lines[0] if lines.size() > 0 else str(operator_key)
	var rarity_label: String = _extract_rarity_label(raw_name)
	_name_label.text = _strip_rarity_from_name(raw_name, rarity_label)
	_sync_name_label_width()
	var meta: String = lines[1] if lines.size() > 1 else ""
	_class_label.text = _format_class_label(meta, rarity_label)
	_apply_unit_art()
	_state_label.text = _state_label_text()
	_hp_stat_label.text = lines[2] if lines.size() > 2 else "HP --"
	_sp_stat_label.text = lines[3] if lines.size() > 3 else "SP --"
	_cd_stat_label.text = lines[4] if lines.size() > 4 else "CD READY"


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


func _format_class_label(meta: String, rarity_label: String) -> String:
	var class_text: String = _class_text_from_meta(meta)
	if rarity_label.is_empty():
		return class_text
	if class_text.is_empty():
		return rarity_label
	return "%s %s" % [class_text, rarity_label]


func _class_text_from_meta(meta: String) -> String:
	var class_text: String = meta.strip_edges()
	var marker: String = "COST "
	var cost_index: int = class_text.find(marker)
	if cost_index >= 0:
		return class_text.substr(0, cost_index).strip_edges()
	marker = "费用 "
	cost_index = class_text.find(marker)
	if cost_index >= 0:
		return class_text.substr(0, cost_index).strip_edges()
	for token in ["READY", "DEPLOYED", "CD"]:
		var token_index: int = class_text.find(token)
		if token_index > 0:
			return class_text.substr(0, token_index).strip_edges()
	return class_text


func _extract_rarity_label(raw_name: String) -> String:
	var name: String = raw_name.strip_edges()
	var star_index: int = name.rfind("★")
	if star_index < 0:
		return ""
	var rarity_label: String = name.substr(star_index).strip_edges()
	if rarity_label.length() <= 1:
		return ""
	for index in range(1, rarity_label.length()):
		var ch: String = rarity_label.substr(index, 1)
		if not ch.is_valid_int():
			return ""
	return rarity_label


func _strip_rarity_from_name(raw_name: String, rarity_label: String) -> String:
	if rarity_label.is_empty():
		return raw_name
	var name: String = raw_name.strip_edges()
	if not name.ends_with(rarity_label):
		return raw_name
	var stripped_name: String = name.substr(0, name.length() - rarity_label.length()).strip_edges()
	return stripped_name if not stripped_name.is_empty() else raw_name


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
		_selected_overlay.visible = _hovered
	if _deployed_overlay != null:
		_deployed_overlay.visible = _state == &"deployed"
	var is_cooldown: bool = _state == &"cooldown"
	if _cooldown_overlay != null:
		_cooldown_overlay.visible = is_cooldown
	if _cooldown_selected_overlay != null:
		_cooldown_selected_overlay.visible = false
	if _cooldown_top_content != null:
		_cooldown_top_content.visible = is_cooldown
	if _cooldown_icon_texture != null:
		_cooldown_icon_texture.visible = is_cooldown


func _apply_density() -> void:
	var card_size: Vector2 = UiTokens.OPERATOR_CARD_COMPACT_SIZE if _compact else UiTokens.OPERATOR_CARD_SIZE
	set_custom_minimum_size(card_size)
	set_size(custom_minimum_size)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label.add_theme_font_size_override("font_size", 14 if _compact else 15)
	_class_label.add_theme_font_size_override("font_size", 12 if _compact else 13)
	_state_label.add_theme_font_size_override("font_size", 12)
	for label in [_hp_stat_label, _sp_stat_label, _cd_stat_label]:
		label.add_theme_font_size_override("font_size", 10 if _compact else 11)
	_cooldown_label.add_theme_font_size_override("font_size", 22 if _compact else 24)
	_sync_card_rects()
	_sync_name_label_width()


func _sync_card_rects() -> void:
	var card_size: Vector2 = custom_minimum_size
	var origin: Vector2 = Vector2.ZERO
	if size.x > card_size.x:
		origin.x = floor((size.x - card_size.x) * 0.5)
	if size.y > card_size.y:
		origin.y = floor((size.y - card_size.y) * 0.5)
	var card_rect_controls: Array[Control] = [
		_card_base,
		_card_content,
		_selected_overlay,
		_deployed_overlay,
		_cooldown_overlay,
		_cooldown_selected_overlay,
		_cooldown_top_content,
	]
	for control: Control in card_rect_controls:
		_place_card_rect(control, origin, card_size)


func _place_card_rect(control: Control, origin: Vector2, card_size: Vector2) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	control.position = origin
	control.size = card_size
	control.custom_minimum_size = card_size


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
	_apply_label_colors()
	if _unit_cfg.is_empty():
		return
	var class_texture := UiArtRegistry.get_class_icon_texture(_unit_cfg)
	if _class_icon_texture != null:
		_class_icon_texture.texture = class_texture
		_class_icon_texture.visible = class_texture != null
	if _class_icon_label != null:
		_class_icon_label.visible = class_texture == null
		_class_icon_label.text = UiDisplayText.class_label(String(_unit_cfg.get("class", ""))).substr(0, 1)
	_refresh_covenant_badge()
	_sync_name_label_width()


## 部署卡盟约角标：右上角显示盟约（含祭坛灌注），灌注项加 ✦；tooltip 给全名。
func _refresh_covenant_badge() -> void:
	var base_covenants: Array[StringName] = []
	var raw_base: Variant = _unit_cfg.get("covenants", [])
	if typeof(raw_base) == TYPE_ARRAY:
		for tag in (raw_base as Array):
			var covenant := StringName(tag)
			if covenant != StringName() and not base_covenants.has(covenant):
				base_covenants.append(covenant)

	var effective: Array = []
	var run_state = AppRefs.run_state()
	var unit_id := StringName(_operator_info.get("unit_id", ""))
	if run_state != null:
		if operator_key != StringName() and run_state.has_method("get_operator_covenants"):
			effective = run_state.get_operator_covenants(operator_key)
		elif unit_id != StringName() and run_state.has_method("get_unit_covenants"):
			effective = run_state.get_unit_covenants(unit_id)
	if effective.is_empty():
		effective = base_covenants

	if effective.is_empty():
		if _covenant_badge != null:
			_covenant_badge.visible = false
		tooltip_text = ""
		return

	var has_infused := false
	var full_names: PackedStringArray = PackedStringArray()
	for raw_tag: Variant in effective:
		var covenant := StringName(raw_tag)
		if covenant == StringName():
			continue
		if base_covenants.has(covenant):
			full_names.append(String(covenant))
		else:
			has_infused = true
			full_names.append("✦%s" % String(covenant))
	_ensure_covenant_badge()
	if _covenant_badge == null:
		return
	# 角标紧凑：取每个盟约首字 + 灌注标记，完整名进 tooltip。
	var badge_text := "✦" if has_infused else ""
	badge_text += "盟"
	_covenant_badge.text = badge_text
	_covenant_badge.visible = true
	tooltip_text = "盟约：%s" % "·".join(full_names)


func _ensure_covenant_badge() -> void:
	if _covenant_badge != null and is_instance_valid(_covenant_badge):
		return
	_covenant_badge = Label.new()
	_covenant_badge.name = "CovenantBadge"
	_covenant_badge.z_index = 12
	_covenant_badge.add_theme_font_size_override("font_size", 11)
	_covenant_badge.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_covenant_badge.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
	_covenant_badge.add_theme_constant_override("shadow_offset_x", 0)
	_covenant_badge.add_theme_constant_override("shadow_offset_y", 0)
	_covenant_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_covenant_badge.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_covenant_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_covenant_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_covenant_badge.offset_left = -40.0
	_covenant_badge.offset_top = 4.0
	_covenant_badge.offset_right = -6.0
	_covenant_badge.offset_bottom = 22.0
	add_child(_covenant_badge)


func _apply_label_colors() -> void:
	if _name_label == null:
		return
	_name_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	if _class_label == null:
		return
	if _unit_cfg.is_empty():
		_class_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
		return
	_class_label.add_theme_color_override("font_color", UiDisplayText.tier_color(int(_unit_cfg.get("cost_prestige", 0))))


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
	_sync_name_label_width()


func _sync_name_label_width() -> void:
	if _name_label == null:
		return
	var font: Font = _name_label.get_theme_font("font")
	if font == null:
		return
	var font_size: int = _name_label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var desired_width: float = ceil(text_width + TITLE_NAME_HORIZONTAL_PADDING)
	var max_width: float = TITLE_NAME_MAX_WIDTH_FALLBACK
	if _title_row != null and _title_row.size.x > 0.0:
		max_width = max(0.0, _title_row.size.x - TITLE_ICON_WIDTH - TITLE_ICON_NAME_GAP)
	_name_label.custom_minimum_size.x = min(desired_width, max_width)


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
