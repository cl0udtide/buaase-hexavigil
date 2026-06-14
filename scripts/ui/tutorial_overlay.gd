extends Control

signal next_requested
signal skip_requested
signal step_started(step_index: int)

const EVENT_TUTORIAL_ACTION := &"tutorial_action"
const DEFAULT_TYPE_SPEED := 36.0

var _waiting_for_action := false
var _dialog_skip_requested := false
var _active := false
var _wait_by_step: Array[bool] = []

@onready var _dialog_panel: DialogPanel = get_node_or_null("DialogPanel") as DialogPanel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _dialog_panel != null:
		_dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dialog_panel.line_started.connect(_on_dialog_line_started)
		_dialog_panel.dialog_finished.connect(_on_dialog_finished)
		_dialog_panel.dialog_skipped.connect(_on_dialog_skipped)
	visible = false
	hide_tutorial()


func show_step(_step_index: int, _total_steps: int, _title: String, body: String, _hint: String, wait_for_action: bool, speaker: String = "", portrait: String = "") -> void:
	show_steps([{
		"speaker": speaker,
		"portrait": portrait,
		"body": body,
		"wait": wait_for_action
	}])


func show_steps(steps: Array) -> void:
	visible = true
	_active = true
	_waiting_for_action = false
	_dialog_skip_requested = false
	_wait_by_step.clear()
	var lines: Array[Dictionary] = []
	for step_index in range(steps.size()):
		var step: Dictionary = {}
		var raw_step: Variant = steps[step_index]
		if typeof(raw_step) == TYPE_DICTIONARY:
			step = raw_step
		var wait_for_action := bool(step.get("wait", false))
		_wait_by_step.append(wait_for_action)
		var advance_mode := "click"
		var prompt_text := "点击继续"
		var finished_prompt := "点击进入正式行动" if step_index == steps.size() - 1 else "再次点击进入下一句"
		if wait_for_action:
			advance_mode = "event:%s" % String(EVENT_TUTORIAL_ACTION)
			prompt_text = "完成当前操作后继续"
			finished_prompt = "完成当前操作后继续"
		lines.append({
			"skin": "bubble",
			"background": "map",
			"speaker": String(step.get("speaker", "")),
			"portrait": String(step.get("portrait", "")),
			"text": String(step.get("body", "")),
			"advance": advance_mode,
			"prompt": prompt_text,
			"finished_prompt": finished_prompt
		})
	var story := {
		"id": "tutorial_sequence",
		"trigger": "manual:tutorial",
		"settings": {"type_speed": DEFAULT_TYPE_SPEED},
		"lines": lines
	}
	if _dialog_panel != null and _dialog_panel.has_method("play_story"):
		_dialog_panel.play_story(story)


func set_panel_position(_position_id: StringName, _force := false) -> void:
	pass


func hide_tutorial() -> void:
	_active = false
	_waiting_for_action = false
	_dialog_skip_requested = false
	_wait_by_step.clear()
	visible = false
	if _dialog_panel != null:
		_dialog_panel.visible = false


func complete_waiting_step() -> void:
	if _waiting_for_action and _dialog_panel != null and _dialog_panel.has_method("notify_story_event"):
		_waiting_for_action = false
		_dialog_panel.notify_story_event(EVENT_TUTORIAL_ACTION)


func _on_dialog_line_started(line_index: int) -> void:
	if not _active:
		return
	_waiting_for_action = line_index >= 0 and line_index < _wait_by_step.size() and _wait_by_step[line_index]
	step_started.emit(line_index)


func _on_dialog_finished() -> void:
	if not _active:
		return
	if _dialog_skip_requested:
		_dialog_skip_requested = false
		_waiting_for_action = false
		call_deferred("_emit_skip_requested")
		return
	if _waiting_for_action:
		_waiting_for_action = false
		call_deferred("_emit_skip_requested")
		return
	call_deferred("_emit_next_requested")


func _on_dialog_skipped() -> void:
	_dialog_skip_requested = true


func _emit_next_requested() -> void:
	next_requested.emit()


func _emit_skip_requested() -> void:
	skip_requested.emit()
