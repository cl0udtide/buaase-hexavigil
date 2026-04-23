extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")


func _ready() -> void:
	var retry_button := get_node_or_null("%RetryButton") as BaseButton
	if retry_button != null:
		retry_button.pressed.connect(_on_retry_pressed)

	var menu_button := get_node_or_null("%MenuButton") as BaseButton
	if menu_button != null:
		menu_button.pressed.connect(_on_menu_pressed)

	var result_panel := get_node_or_null("%ResultPanel")
	var scene_router = AppRefs.scene_router()
	if result_panel != null and result_panel.has_method("set_result") and scene_router != null:
		result_panel.call("set_result", scene_router.result_win)


func _on_retry_pressed() -> void:
	var scene_router = AppRefs.scene_router()
	if scene_router != null:
		scene_router.restart_run()


func _on_menu_pressed() -> void:
	var scene_router = AppRefs.scene_router()
	if scene_router != null:
		scene_router.goto_menu()
