extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const VICTORY_BACKGROUND: Texture2D = preload("res://assets/story/backgrounds/page_result_victory.png")
const DEFEAT_BACKGROUND: Texture2D = preload("res://assets/story/backgrounds/page_result_defeat_milk_dragon.png")


func _ready() -> void:
	AppTheme.apply(self)
	var scene_router = AppRefs.scene_router()
	var win: bool = false
	if scene_router != null:
		win = bool(scene_router.result_win)
	_apply_background(win)
	_apply_button_style()

	var retry_button := get_node_or_null("%RetryButton") as BaseButton
	if retry_button != null:
		retry_button.pressed.connect(_on_retry_pressed)

	var menu_button := get_node_or_null("%MenuButton") as BaseButton
	if menu_button != null:
		menu_button.pressed.connect(_on_menu_pressed)

	var result_panel := get_node_or_null("%ResultPanel")
	if result_panel != null and result_panel.has_method("set_result"):
		result_panel.call("set_result", win)


func _on_retry_pressed() -> void:
	var scene_router = AppRefs.scene_router()
	if scene_router != null:
		scene_router.restart_run()


func _on_menu_pressed() -> void:
	var scene_router = AppRefs.scene_router()
	if scene_router != null:
		scene_router.goto_menu()


func _apply_background(win: bool) -> void:
	var background := get_node_or_null("Background") as TextureRect
	if background != null:
		background.texture = VICTORY_BACKGROUND if win else DEFEAT_BACKGROUND


func _apply_button_style() -> void:
	var retry_button := get_node_or_null("%RetryButton") as Button
	if retry_button != null:
		retry_button.add_theme_font_size_override("font_size", 18)
		retry_button.add_theme_stylebox_override("normal", GameUiStyle.accent_button(GameUiStyle.ACCENT))
		retry_button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.ACCENT))
		retry_button.add_theme_stylebox_override("pressed", GameUiStyle.accent_button(GameUiStyle.AMBER))
		retry_button.add_theme_stylebox_override("disabled", GameUiStyle.disabled_button())

	var menu_button := get_node_or_null("%MenuButton") as Button
	if menu_button != null:
		menu_button.add_theme_font_size_override("font_size", 18)
		menu_button.add_theme_stylebox_override("normal", GameUiStyle.secondary_button())
		menu_button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.ACCENT))
		menu_button.add_theme_stylebox_override("pressed", GameUiStyle.accent_button(GameUiStyle.AMBER))
		menu_button.add_theme_stylebox_override("disabled", GameUiStyle.disabled_button())
