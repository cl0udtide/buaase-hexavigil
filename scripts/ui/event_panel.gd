extends PanelContainer

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
var _current_cell := Vector2i(-1, -1)
var _current_event_id := StringName()
var _choice_buttons: Array[Button] = []
var _resolved := false
var _base_desc_text := ""

@onready var _eyebrow_label: Label = %EyebrowLabel
@onready var _title_label: Label = %TitleLabel
@onready var _close_button: Button = %CloseButton
@onready var _desc_label: Label = %DescLabel
@onready var _result_label: Label = %ResultLabel
@onready var _choice_list: VBoxContainer = %ChoiceList
@onready var _illustration: Control = %Illustration
@onready var _event_glyph: Label = %EventGlyph


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	if _close_button != null:
		_close_button.pressed.connect(hide_event)
	hide_event()
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_open_event_panel.connect(_on_request_open_event_panel)
		event_bus.random_event_triggered.connect(_on_random_event_triggered)


func show_event_for_cell(cell: Vector2i) -> void:
	var random_event_manager := _get_random_event_manager()
	if random_event_manager == null or not random_event_manager.has_method("get_event_id_at_cell"):
		return
	var event_id: StringName = random_event_manager.get_event_id_at_cell(cell)
	if event_id == StringName():
		return
	# 优先按格子取配置：祭坛等事件的选项是按格子动态生成的。
	var cfg: Dictionary = {}
	if random_event_manager.has_method("get_event_cfg_at_cell"):
		cfg = random_event_manager.get_event_cfg_at_cell(cell)
	elif random_event_manager.has_method("get_event_cfg"):
		cfg = random_event_manager.get_event_cfg(event_id)
	else:
		cfg = _get_event_cfg(event_id)
	if cfg.is_empty():
		return
	_current_cell = cell
	_current_event_id = event_id
	_show_event_config(cfg)


func show_event(event_cfg: Dictionary) -> void:
	_current_cell = Vector2i(-1, -1)
	_current_event_id = StringName(event_cfg.get("id", ""))
	_show_event_config(event_cfg)


func hide_event() -> void:
	visible = false
	_current_cell = Vector2i(-1, -1)
	_current_event_id = StringName()
	_resolved = false
	_base_desc_text = ""
	_result_label.text = ""
	if _close_button != null:
		_close_button.visible = false
	_set_impact_text("")
	_build_choices([])


func _show_event_config(event_cfg: Dictionary) -> void:
	visible = true
	_resolved = false
	_result_label.text = ""
	if _close_button != null:
		_close_button.visible = false
	_set_impact_text("")
	if _eyebrow_label != null:
		_eyebrow_label.text = _make_eyebrow_text()
	if _title_label != null:
		_title_label.text = String(event_cfg.get("name", event_cfg.get("id", "事件")))
	if _desc_label != null:
		_base_desc_text = String(event_cfg.get("desc", "一处未记录的异常信号正在地图上浮现。"))
		_desc_label.text = _base_desc_text
	var choices := _get_choice_defs(event_cfg)
	if choices.is_empty():
		_build_choices([])
		_resolve_current_event(StringName())
	else:
		_build_choices(choices)


func _build_choices(choice_defs: Array) -> void:
	for button in _choice_buttons:
		if button != null and is_instance_valid(button):
			_choice_list.remove_child(button)
			button.queue_free()
	_choice_buttons.clear()
	for choice in choice_defs:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 46.0)
		button.focus_mode = Control.FOCUS_NONE
		var base_text := String(choice.get("text", "选项"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_choice_button(button, StringName(choice.get("kind", &"secondary")))
		var choice_id := StringName(choice.get("id", "choice"))
		# 预检该选项指向子事件的 requires；不满足时禁用并在文案/tooltip 标出缺口。
		var requirement := _preview_choice_requirements(choice_id)
		var tooltip := _choice_tooltip_text(choice)
		if not bool(requirement.get("ok", true)):
			var reason := String(requirement.get("reason", "条件不足"))
			button.disabled = true
			button.text = "%s（%s）" % [base_text, reason]
			tooltip = reason if tooltip.is_empty() else "%s\n%s" % [tooltip, reason]
		else:
			button.text = base_text
		button.tooltip_text = tooltip
		button.pressed.connect(_on_choice_pressed.bind(choice_id))
		_choice_list.add_child(button)
		_choice_buttons.append(button)


func _get_choice_defs(event_cfg: Dictionary) -> Array:
	var choices: Array = []
	var raw_choices: Variant = event_cfg.get("choices", [])
	if typeof(raw_choices) == TYPE_ARRAY:
		for raw_choice in raw_choices:
			if typeof(raw_choice) == TYPE_DICTIONARY:
				choices.append((raw_choice as Dictionary).duplicate(true))
	return choices


func _on_choice_pressed(choice_id: StringName) -> void:
	_resolve_current_event(choice_id)


func _resolve_current_event(choice_id: StringName) -> void:
	if _resolved:
		return
	if _current_cell.x < 0:
		return
	_resolved = true
	_set_choices_disabled(true)
	var day_manager := _get_day_manager()
	if day_manager == null or not day_manager.has_method("try_trigger_event"):
		_result_label.text = "事件系统尚未初始化"
		_resolved = false
		_set_choices_disabled(false)
		_enable_dismiss_after_resolution()
		return
	var result: Dictionary = day_manager.try_trigger_event(_current_cell, choice_id)
	if result.get("ok", false):
		_show_resolved_event_from_result(result)
	_set_result_text(result)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.random_event_choice_selected.emit(_current_event_id, _current_cell, choice_id, result)
	if result.get("ok", false):
		_build_choices([])
		_enable_dismiss_after_resolution()
	else:
		_resolved = false
		_set_choices_disabled(false)
		_enable_dismiss_after_resolution()


func _set_choices_disabled(disabled: bool) -> void:
	for button in _choice_buttons:
		if button != null and is_instance_valid(button):
			button.disabled = disabled


func _format_event_result(result: Dictionary) -> String:
	if not result.get("ok", false):
		return String(result.get("message", "事件处理失败"))
	var payload: Dictionary = result.get("payload", {})
	var event_id := StringName(payload.get("event_id", _current_event_id))
	var cfg := _get_event_cfg(event_id)
	var event_name := String(cfg.get("name", event_id))
	var lines: PackedStringArray = []
	lines.append("%s已处理" % event_name)
	lines.append(_format_visible_effect_text(result))
	return "\n".join(lines)


func _format_visible_effect_text(result: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append(_format_effect_summary(result))
	var payload: Dictionary = result.get("payload", {})
	var ap_cost := int(payload.get("ap_cost", 0))
	if ap_cost > 0:
		lines.append("行动力消耗：%d" % ap_cost)
	return "\n".join(lines)


func _format_effect_summary(result: Dictionary) -> String:
	if not result.get("ok", false):
		return ""
	var payload: Dictionary = result.get("payload", {})
	var event_id := StringName(payload.get("event_id", _current_event_id))
	var cfg := _get_event_cfg(event_id)
	var effect_payload: Dictionary = payload.get("effect_payload", cfg.get("payload", {}))
	return "实际效果：%s" % _format_effect_payload(effect_payload)


func _set_result_text(result: Dictionary) -> void:
	_result_label.text = _format_event_result(result)
	if result.get("ok", false):
		_set_impact_text(_format_visible_effect_text(result))


func _set_impact_text(text: String) -> void:
	if _desc_label != null:
		_desc_label.text = _base_desc_text if text.strip_edges().is_empty() else "%s\n\n%s" % [_base_desc_text, text]


func _format_effect_payload(effect_payload: Dictionary) -> String:
	var parts: PackedStringArray = []
	_append_resource_delta(parts, effect_payload, "wood", "木材")
	_append_resource_delta(parts, effect_payload, "stone", "石材")
	_append_resource_delta(parts, effect_payload, "mana", "魔力")
	_append_resource_delta(parts, effect_payload, "prestige", "声望")
	var summary := String(effect_payload.get("summary", "")).strip_edges()
	if not summary.is_empty():
		parts.append(summary)
	if parts.is_empty():
		return "无资源或声望变化"
	return "，".join(parts)


func _append_resource_delta(parts: PackedStringArray, payload: Dictionary, key: String, label: String) -> void:
	var amount := int(payload.get(key, 0))
	if amount == 0:
		return
	var prefix := "+" if amount > 0 else ""
	parts.append("%s%d %s" % [prefix, amount, label])


func _show_resolved_event_from_result(result: Dictionary) -> void:
	var payload: Dictionary = result.get("payload", {})
	var event_id := StringName(payload.get("event_id", _current_event_id))
	var cfg := _get_event_cfg(event_id)
	if cfg.is_empty():
		return
	_current_event_id = event_id
	_show_resolved_event_config(cfg)


func _make_eyebrow_text() -> String:
	if _current_cell.x < 0:
		return "地图事件"
	return "地图事件  X%d Y%d" % [_current_cell.x, _current_cell.y]


func _on_request_open_event_panel(cell: Vector2i) -> void:
	show_event_for_cell(cell)


func _on_random_event_triggered(event_id: StringName, cell: Vector2i) -> void:
	if visible and _current_cell == cell:
		return
	var cfg := _get_event_cfg(event_id)
	if cfg.is_empty():
		return
	_current_cell = cell
	_current_event_id = event_id
	_show_resolved_event_config(cfg)
	_set_result_text({
		"ok": true,
		"payload": {
			"event_id": event_id,
			"effect_payload": cfg.get("payload", {}),
		},
	})
	_build_choices([])
	_enable_dismiss_after_resolution()


func _show_resolved_event_config(event_cfg: Dictionary) -> void:
	visible = true
	_resolved = true
	if _close_button != null:
		_close_button.visible = false
	if _eyebrow_label != null:
		_eyebrow_label.text = _make_eyebrow_text()
	if _title_label != null:
		_title_label.text = String(event_cfg.get("name", event_cfg.get("id", "事件")))
	if _desc_label != null:
		_base_desc_text = String(event_cfg.get("desc", "一处未记录的异常信号正在地图上浮现。"))
		_desc_label.text = _base_desc_text


func _apply_visual_style() -> void:
	if _title_label != null:
		_title_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	if _eyebrow_label != null:
		_eyebrow_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
		_eyebrow_label.add_theme_font_size_override("font_size", 13)
	if _desc_label != null:
		_desc_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	if _result_label != null:
		_result_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	if _close_button != null:
		_style_choice_button(_close_button, &"secondary")
	if _event_glyph != null:
		_event_glyph.add_theme_color_override("font_color", GameUiStyle.AMBER)
		_event_glyph.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
func _style_choice_button(button: Button, kind: StringName) -> void:
	GameUiStyle.center_button_text(button)
	button.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)
	match kind:
		&"primary":
			button.add_theme_stylebox_override("normal", GameUiStyle.event_choice_button())
			button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.ACCENT))
			button.add_theme_stylebox_override("pressed", GameUiStyle.accent_button(GameUiStyle.AMBER))
		_:
			button.add_theme_stylebox_override("normal", GameUiStyle.secondary_button())
			button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.STEEL))
			button.add_theme_stylebox_override("pressed", GameUiStyle.accent_button(GameUiStyle.AMBER))
	button.add_theme_stylebox_override("disabled", GameUiStyle.disabled_button())


func _get_event_cfg(event_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_event_cfg(event_id) if data_repo != null and data_repo.has_method("get_event_cfg") else {}


## 预检选项前置资源：返回 {ok, reason, shortfalls}；管理器不可用时按满足处理。
func _preview_choice_requirements(choice_id: StringName) -> Dictionary:
	if _current_event_id == StringName() or choice_id == StringName():
		return {"ok": true}
	var random_event_manager := _get_random_event_manager()
	if random_event_manager == null or not random_event_manager.has_method("preview_choice_requirements"):
		return {"ok": true}
	return random_event_manager.preview_choice_requirements(_current_event_id, choice_id)


func _choice_tooltip_text(choice: Dictionary) -> String:
	for key in ["effect_desc", "tooltip", "preview", "effect_text", "desc"]:
		var text := String(choice.get(key, "")).strip_edges()
		if not text.is_empty():
			return text
	var target_event_id := StringName(choice.get("event_id", choice.get("trigger_event_id", "")))
	var cfg := _get_event_cfg(target_event_id)
	return String(cfg.get("desc", "")).strip_edges()


func _enable_dismiss_after_resolution() -> void:
	if _close_button != null:
		_close_button.visible = true


func _get_day_manager() -> Node:
	return get_node_or_null("../../../../Managers/DayManager")


func _get_random_event_manager() -> Node:
	return get_node_or_null("../../../../Managers/RandomEventManager")
