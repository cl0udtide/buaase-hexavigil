extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")

@onready var _choice_list: VBoxContainer = %ChoiceList
@onready var _choice_card_template: Control = %ChoiceCardTemplate


var _last_sources_frame := -1


func _ready() -> void:
	AppTheme.apply(self)
	if _choice_card_template != null:
		_choice_card_template.visible = false
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		# 优先用带来源的信号；旧的纯 id 信号作为兼容兜底（同帧已渲染则跳过）。
		event_bus.blessing_choices_with_sources_ready.connect(show_choices_with_sources)
		event_bus.blessing_choices_ready.connect(show_choices)
	hide_panel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_modal_layer_visibility()


## 渲染三选一（带槽位来源）。entries: Array[{buff_id, slot}]。
func show_choices_with_sources(entries: Array) -> void:
	_last_sources_frame = Engine.get_process_frames()
	_set_modal_layer_visible(true)
	visible = true
	_emit_panel_shown()
	_clear_choices()
	var data_repo = AppRefs.data_repo()
	for raw_entry: Variant in entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		var buff_id := StringName(entry.get("buff_id", ""))
		if buff_id == StringName():
			continue
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		var card := _make_choice_card()
		if card == null:
			continue
		if not card.has_method("configure"):
			continue
		card.call("configure", buff_id, cfg, {
			"selectable": true,
			"choice_mode": true,
			"slot_source": StringName(entry.get("slot", "")),
		})
		card.set_meta("audio_cue", &"blessing_chosen")
		if card.has_signal("pressed"):
			card.connect(&"pressed", Callable(self, "_on_choice_pressed"))
		_choice_list.add_child(card)


func show_choices(choice_ids: Array[StringName]) -> void:
	# 同帧已由带来源信号渲染过则跳过，避免重复。
	if Engine.get_process_frames() == _last_sources_frame:
		return
	_set_modal_layer_visible(true)
	visible = true
	_emit_panel_shown()
	_clear_choices()
	var data_repo = AppRefs.data_repo()
	for buff_id in choice_ids:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		var card := _make_choice_card()
		if card == null:
			continue
		if not card.has_method("configure"):
			continue
		card.call("configure", buff_id, cfg, {
			"selectable": true,
			"choice_mode": true
		})
		card.set_meta("audio_cue", &"blessing_chosen")
		if card.has_signal("pressed"):
			card.connect(&"pressed", Callable(self, "_on_choice_pressed"))
		_choice_list.add_child(card)


func hide_panel() -> void:
	visible = false


func _on_choice_pressed(buff_id: StringName) -> void:
	if buff_id == StringName():
		return
	hide_panel()
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.blessing_chosen.emit(buff_id)


func _clear_choices() -> void:
	for child in _choice_list.get_children():
		if child == _choice_card_template:
			continue
		child.queue_free()


func _make_choice_card() -> Control:
	if _choice_card_template == null:
		return null
	var card := _choice_card_template.duplicate() as Control
	if card == null:
		return null
	card.visible = true
	return card


func _emit_panel_shown() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.blessing_panel_shown.emit()


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
