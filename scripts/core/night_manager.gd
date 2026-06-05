extends Node


var _night_running := false

@onready var _wave_manager: Node = get_node_or_null("../WaveManager")


func start_night(_day: int) -> void:
	_night_running = true
	if _wave_manager == null:
		return
	var run_state = get_node_or_null("/root/RunState")
	var template_id: StringName = StringName(run_state.night_template_id) if run_state != null else StringName()
	if template_id == StringName():
		push_warning("Night started without a resolved wave template.")
		return
	if _wave_manager.has_method("start_wave_for_template"):
		_wave_manager.start_wave_for_template(template_id)


func finish_night() -> void:
	_night_running = false


func is_night_running() -> bool:
	return _night_running
