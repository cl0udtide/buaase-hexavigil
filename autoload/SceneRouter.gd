extends Node


const MENU_SCENE := "res://scenes/bootstrap/MainMenu.tscn"
const GAME_SCENE := "res://scenes/game/Game.tscn"
const RESULT_SCENE := "res://scenes/bootstrap/Result.tscn"
const RUN_MODE_STANDARD := &"standard"
const RUN_MODE_TUTORIAL := &"tutorial"

var result_win: bool = false
var _pending_run_mode: StringName = RUN_MODE_STANDARD
var _last_run_mode: StringName = RUN_MODE_STANDARD


func _ready() -> void:
	EventBus.run_ended.connect(goto_result)


func goto_menu() -> void:
	_change_scene(MENU_SCENE)


func goto_game() -> void:
	_goto_game_with_mode(RUN_MODE_STANDARD)


func goto_tutorial() -> void:
	_goto_game_with_mode(RUN_MODE_TUTORIAL)


func restart_run() -> void:
	_goto_game_with_mode(_last_run_mode)


func consume_pending_run_mode() -> StringName:
	var mode := _pending_run_mode
	_pending_run_mode = RUN_MODE_STANDARD
	_last_run_mode = mode
	return mode


func _goto_game_with_mode(mode: StringName) -> void:
	_pending_run_mode = _normalize_run_mode(mode)
	_last_run_mode = _pending_run_mode
	_change_scene(GAME_SCENE)


func goto_result(win: bool) -> void:
	result_win = win
	_change_scene(RESULT_SCENE)


func _normalize_run_mode(mode: StringName) -> StringName:
	return RUN_MODE_TUTORIAL if mode == RUN_MODE_TUTORIAL else RUN_MODE_STANDARD


func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Scene does not exist yet: %s" % path)
		return
	get_tree().change_scene_to_file(path)
