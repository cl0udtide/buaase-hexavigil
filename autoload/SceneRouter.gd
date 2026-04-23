extends Node


const MENU_SCENE := "res://scenes/bootstrap/MainMenu.tscn"
const GAME_SCENE := "res://scenes/game/Game.tscn"
const RESULT_SCENE := "res://scenes/bootstrap/Result.tscn"

var result_win: bool = false


func _ready() -> void:
	EventBus.run_ended.connect(goto_result)


func goto_menu() -> void:
	_change_scene(MENU_SCENE)


func goto_game() -> void:
	_change_scene(GAME_SCENE)


func goto_result(win: bool) -> void:
	result_win = win
	_change_scene(RESULT_SCENE)


func restart_run() -> void:
	goto_game()


func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Scene does not exist yet: %s" % path)
		return
	get_tree().change_scene_to_file(path)
