extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	var start_button := get_node_or_null("%StartButton") as BaseButton
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	var scene_router = AppRefs.scene_router()
	if scene_router != null:
		scene_router.goto_game()


func _apply_visual_style() -> void:
	var title := get_node_or_null("RightUiSlot/CenterContainer/VBoxContainer/TitleLabel") as Label
	if title != null:
		title.text = "HexaVigil"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 54)
		title.add_theme_color_override("font_color", Color(0.930, 0.965, 1.000, 1.0))
		title.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
		title.add_theme_constant_override("outline_size", 0)

	var vbox := get_node_or_null("RightUiSlot/CenterContainer/VBoxContainer") as VBoxContainer
	if vbox != null:
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 18)

	var start_button := get_node_or_null("%StartButton") as Button
	if start_button != null:
		start_button.text = "开始行动"
		start_button.custom_minimum_size = Vector2(280.0, 54.0)
		start_button.add_theme_font_size_override("font_size", 20)
		start_button.add_theme_stylebox_override("normal", GameUiStyle.accent_button(GameUiStyle.ACCENT))
		start_button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.ACCENT))
		start_button.add_theme_stylebox_override("pressed", GameUiStyle.accent_button(GameUiStyle.AMBER))
		start_button.add_theme_stylebox_override("disabled", GameUiStyle.disabled_button())

	var subtitle := get_node_or_null("RightUiSlot/CenterContainer/VBoxContainer/SubtitleLabel") as Label
	if subtitle != null:
		subtitle.text = "昼夜防线指挥"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 17)
		subtitle.add_theme_color_override("font_color", Color(0.670, 0.760, 0.860, 1.0))
