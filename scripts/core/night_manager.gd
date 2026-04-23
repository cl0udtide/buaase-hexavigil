extends Node


var _night_running := false

@onready var _wave_manager: Node = get_node_or_null("../WaveManager")


func start_night(day: int) -> void:
	_night_running = true
	if _wave_manager != null and _wave_manager.has_method("start_wave_for_day"):
		_wave_manager.start_wave_for_day(day)


func finish_night() -> void:
	_night_running = false


func is_night_running() -> bool:
	return _night_running
