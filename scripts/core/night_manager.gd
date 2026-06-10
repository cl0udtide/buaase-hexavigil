extends Node


var _night_running := false

@onready var _wave_manager: Node = get_node_or_null("../WaveManager")


func start_night(_day: int) -> void:
	_night_running = true
	if _wave_manager == null:
		return
	var run_state = get_node_or_null("/root/RunState")
	var template_ids: Array = []
	var affix_ids: Array = []
	if run_state != null:
		template_ids = (run_state.night_wave_template_ids as Array).duplicate()
		affix_ids = (run_state.night_affix_ids as Array).duplicate()
		if template_ids.is_empty() and StringName(run_state.night_template_id) != StringName():
			template_ids = [StringName(run_state.night_template_id)]
	if template_ids.is_empty():
		push_warning("Night started without a resolved wave plan.")
		return
	if _wave_manager.has_method("start_night"):
		_wave_manager.start_night(template_ids, affix_ids)


func finish_night() -> void:
	_night_running = false


func is_night_running() -> bool:
	return _night_running
