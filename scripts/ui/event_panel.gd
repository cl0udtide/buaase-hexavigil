extends PanelContainer

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const CutCornerTextureRect = preload("res://scripts/ui/cut_corner_texture_rect.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

# 统一页面模型：每个事件页 = 文案 + 插图 + 选项。
# 选项 = 文本 + 悬停效果说明 + 指向的下一页(event_id)。
# 点选项：event_id 为空 → 关闭面板；否则执行目标页的底层效果并翻到目标页。
# 首次有效翻页消耗行动力 + 移除地图事件点；之后的翻页（含循环回开场）不再消耗。
var _current_cell := Vector2i(-1, -1)
var _root_event_id := StringName()
var _current_event_id := StringName()
var _event_consumed := false
var _choice_buttons: Array[Button] = []
var _base_desc_text := ""

@onready var _eyebrow_label: Label = %EyebrowLabel
@onready var _title_label: Label = %TitleLabel
@onready var _close_button: Button = %CloseButton
@onready var _desc_label: Label = %DescLabel
@onready var _result_label: Label = %ResultLabel
@onready var _choice_list: VBoxContainer = %ChoiceList
@onready var _choice_button_template: Button = %ChoiceButtonTemplate
@onready var _illustration: Control = %Illustration
@onready var _event_image: CutCornerTextureRect = %EventImage
@onready var _illustration_center: Control = %IllustrationCenter
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_modal_layer_visibility()


func show_event_for_cell(cell: Vector2i) -> void:
	var random_event_manager := _get_random_event_manager()
	if random_event_manager == null or not random_event_manager.has_method("get_event_id_at_cell"):
		return
	var event_id: StringName = random_event_manager.get_event_id_at_cell(cell)
	if event_id == StringName():
		return
	_current_cell = cell
	_root_event_id = event_id
	_event_consumed = false
	_show_page(event_id)


func show_event(event_cfg: Dictionary) -> void:
	_current_cell = Vector2i(-1, -1)
	_root_event_id = StringName(event_cfg.get("id", ""))
	_event_consumed = false
	_render_page(event_cfg)


func hide_event() -> void:
	visible = false
	_current_cell = Vector2i(-1, -1)
	_root_event_id = StringName()
	_current_event_id = StringName()
	_event_consumed = false
	_base_desc_text = ""
	_result_label.text = ""
	if _close_button != null:
		_close_button.visible = false
	_apply_event_image({})
	_build_choices([])


## 取某页配置：开场页可能是祭坛等动态选项事件，需按格子取动态 choices。
func _get_page_cfg(event_id: StringName) -> Dictionary:
	var random_event_manager := _get_random_event_manager()
	if event_id == _root_event_id and _current_cell.x >= 0 \
			and random_event_manager != null and random_event_manager.has_method("get_event_cfg_at_cell"):
		var dyn: Dictionary = random_event_manager.get_event_cfg_at_cell(_current_cell)
		if not dyn.is_empty():
			return dyn
	return _get_event_cfg(event_id)


func _show_page(event_id: StringName, effect_result: Dictionary = {}) -> void:
	var cfg := _get_page_cfg(event_id)
	if cfg.is_empty():
		hide_event()
		return
	_render_page(cfg, effect_result)


## 渲染任意一页：标题、描述、插图、效果回显、选项。
func _render_page(cfg: Dictionary, effect_result: Dictionary = {}) -> void:
	_set_modal_layer_visible(true)
	visible = true
	_current_event_id = StringName(cfg.get("id", _current_event_id))
	if _close_button != null:
		_close_button.visible = false
	_apply_event_image(cfg)
	if _eyebrow_label != null:
		_eyebrow_label.text = _make_eyebrow_text()
	if _title_label != null:
		_title_label.text = String(cfg.get("name", cfg.get("id", "事件")))
	_base_desc_text = String(cfg.get("desc", "一处未记录的异常信号正在地图上浮现。"))
	if _desc_label != null:
		_desc_label.text = _base_desc_text
	if not effect_result.is_empty() and effect_result.get("ok", false):
		_result_label.text = _format_visible_effect_text(effect_result)
	else:
		_result_label.text = ""
	var choices := _get_choice_defs(cfg)
	_build_choices(choices)
	# 兜底：某页没有任何选项时，给一个关闭按钮，避免卡死。
	if choices.is_empty():
		_enable_dismiss_after_resolution()


func _build_choices(choice_defs: Array) -> void:
	for button in _choice_buttons:
		if button != null and is_instance_valid(button):
			_choice_list.remove_child(button)
			button.queue_free()
	_choice_buttons.clear()
	if _choice_button_template == null:
		push_error("EventPanel missing ChoiceButtonTemplate")
		return
	for choice in choice_defs:
		var button := _choice_button_template.duplicate() as Button
		if button == null:
			continue
		button.visible = true
		var base_text := String(choice.get("text", "选项"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# 预检该选项指向页的 requires；不满足时禁用并在文案/tooltip 标出缺口。
		var requirement := _preview_choice_requirements(choice)
		var tooltip := _choice_tooltip_text(choice)
		if not bool(requirement.get("ok", true)):
			var reason := String(requirement.get("reason", "条件不足"))
			button.disabled = true
			button.text = "%s（%s）" % [base_text, reason]
			tooltip = reason if tooltip.is_empty() else "%s\n%s" % [tooltip, reason]
		else:
			button.text = base_text
		button.tooltip_text = tooltip
		button.pressed.connect(_on_choice_pressed.bind((choice as Dictionary).duplicate(true)))
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


func _on_choice_pressed(choice: Dictionary) -> void:
	var target := StringName(choice.get("event_id", ""))
	# 收尾选项：无指向 → 关闭面板。
	if target == StringName():
		hide_event()
		return
	_set_choices_disabled(true)
	var choice_id := StringName(choice.get("id", ""))
	var result: Dictionary
	if not _event_consumed:
		# 首次：消耗行动力 + 移除事件点，并执行目标页效果。
		var day_manager := _get_day_manager()
		if day_manager == null or not day_manager.has_method("try_trigger_event"):
			_result_label.text = "事件系统尚未初始化"
			_set_choices_disabled(false)
			return
		result = day_manager.try_trigger_event(_current_cell, choice_id)
		if result.get("ok", false):
			_event_consumed = true
	else:
		# 后续翻页（含循环回开场）：只执行目标页效果，不再消耗行动力/事件点。
		var random_event_manager := _get_random_event_manager()
		if random_event_manager != null and random_event_manager.has_method("apply_event"):
			result = random_event_manager.apply_event(target)
		else:
			result = {"ok": false, "message": "事件系统不可用"}
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.random_event_choice_selected.emit(_root_event_id, _current_cell, choice_id, result)
	if result.get("ok", false):
		var next_id := StringName((result.get("payload", {}) as Dictionary).get("event_id", target))
		_show_page(next_id, result)
	else:
		# requires 不足等：留在当前页并提示。
		_set_choices_disabled(false)
		_result_label.text = String(result.get("message", "无法进行该选项"))


func _set_choices_disabled(disabled: bool) -> void:
	for button in _choice_buttons:
		if button != null and is_instance_valid(button):
			button.disabled = disabled


func _format_visible_effect_text(result: Dictionary) -> String:
	var lines: PackedStringArray = []
	var summary := _format_effect_summary(result)
	if not summary.strip_edges().is_empty():
		lines.append(summary)
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
	var body := _format_effect_payload(effect_payload)
	return "实际效果：%s" % body if not body.is_empty() else ""


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
		return ""
	return "，".join(parts)


func _append_resource_delta(parts: PackedStringArray, payload: Dictionary, key: String, label: String) -> void:
	var amount := int(payload.get(key, 0))
	if amount == 0:
		return
	var prefix := "+" if amount > 0 else ""
	parts.append("%s%d %s" % [prefix, amount, label])


func _make_eyebrow_text() -> String:
	if _current_cell.x < 0:
		return "地图事件"
	return "地图事件  X%d Y%d" % [_current_cell.x, _current_cell.y]


func _on_request_open_event_panel(cell: Vector2i) -> void:
	show_event_for_cell(cell)


## 其他系统直接触发事件（如某些自动结算）时，在面板未占用同格时弹出结算页。
func _on_random_event_triggered(event_id: StringName, cell: Vector2i) -> void:
	if visible and _current_cell == cell:
		return
	var cfg := _get_event_cfg(event_id)
	if cfg.is_empty():
		return
	_current_cell = cell
	_root_event_id = event_id
	_event_consumed = true
	_render_page(cfg, {
		"ok": true,
		"payload": {
			"event_id": event_id,
			"effect_payload": cfg.get("payload", {}),
		},
	})


func _apply_event_image(event_cfg: Dictionary) -> void:
	var image_path := String(event_cfg.get("image", "")).strip_edges()
	var texture: Texture2D = null
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		texture = load(image_path) as Texture2D
	if texture != null:
		if _event_image != null:
			_event_image.texture = texture
			_event_image.visible = true
		if _illustration_center != null:
			_illustration_center.visible = false
		if _event_glyph != null:
			_event_glyph.visible = false
	else:
		if _event_image != null:
			_event_image.texture = null
			_event_image.visible = false
		if _illustration_center != null:
			_illustration_center.visible = true
		if _event_glyph != null:
			_event_glyph.visible = true


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
	if _event_glyph != null:
		_event_glyph.add_theme_color_override("font_color", GameUiStyle.AMBER)
		_event_glyph.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))


func _get_event_cfg(event_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_event_cfg(event_id) if data_repo != null and data_repo.has_method("get_event_cfg") else {}


## 预检选项指向页的前置资源：返回 {ok, reason, ...}；管理器不可用或无前置时按满足处理。
func _preview_choice_requirements(choice: Dictionary) -> Dictionary:
	var random_event_manager := _get_random_event_manager()
	if random_event_manager == null:
		return {"ok": true}
	var target := StringName(choice.get("event_id", ""))
	if target == StringName():
		# 祭坛/塌方等动态选项：无静态 event_id，用旧的按选项预检。
		var cid := StringName(choice.get("id", ""))
		if (String(cid).begins_with("infuse_") or String(cid).begins_with("seal_")) \
				and random_event_manager.has_method("preview_choice_requirements"):
			return random_event_manager.preview_choice_requirements(_current_event_id, cid)
		return {"ok": true}
	var target_cfg := _get_event_cfg(target)
	var requires: Variant = target_cfg.get("requires", {})
	if not (requires is Dictionary) or (requires as Dictionary).is_empty():
		return {"ok": true}
	if random_event_manager.has_method("preview_requirements"):
		return random_event_manager.preview_requirements(requires)
	return {"ok": true}


func _choice_tooltip_text(choice: Dictionary) -> String:
	for key in ["effect_desc", "tooltip", "preview", "effect_text"]:
		var text := String(choice.get(key, "")).strip_edges()
		if not text.is_empty():
			return text
	return ""


func _enable_dismiss_after_resolution() -> void:
	if _close_button != null:
		_close_button.visible = true


func _set_modal_layer_visible(value: bool) -> void:
	var layer := _get_modal_layer()
	if layer != null:
		layer.visible = value


func _sync_modal_layer_visibility() -> void:
	var layer := _get_modal_layer()
	if layer == null:
		return
	layer.visible = _modal_layer_has_visible_panel(layer)


func _get_modal_layer() -> CanvasItem:
	var slot := get_parent()
	if slot == null:
		return null
	return slot.get_parent() as CanvasItem


func _modal_layer_has_visible_panel(layer: Node) -> bool:
	for slot in layer.get_children():
		for child in slot.get_children():
			var canvas_item := child as CanvasItem
			if canvas_item != null and canvas_item.visible:
				return true
	return false


func _get_day_manager() -> Node:
	return get_node_or_null("../../../../Managers/DayManager")


func _get_random_event_manager() -> Node:
	return get_node_or_null("../../../../Managers/RandomEventManager")
