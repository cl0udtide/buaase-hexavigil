extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiTokens = preload("res://scripts/ui/ui_tokens.gd")


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	var start_button := get_node_or_null("%StartButton") as BaseButton
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	var tutorial_button := get_node_or_null("%TutorialButton") as BaseButton
	if tutorial_button != null:
		tutorial_button.pressed.connect(_on_tutorial_pressed)


func _on_start_pressed() -> void:
	var scene_router = AppRefs.scene_router()
	if scene_router != null:
		scene_router.goto_game()


func _on_tutorial_pressed() -> void:
	var scene_router = AppRefs.scene_router()
	if scene_router != null:
		if scene_router.has_method("goto_tutorial"):
			scene_router.goto_tutorial()
		else:
			scene_router.goto_game()


func _apply_visual_style() -> void:
	var title := get_node_or_null("RightUiSlot/CenterContainer/VBoxContainer/TitleLabel") as Label
	if title != null:
		title.text = "HexaVigil"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var logo_font := FontVariation.new()
		logo_font.base_font = AppTheme.FONT_CN
		logo_font.set_spacing(TextServer.SPACING_GLYPH, 5)
		title.add_theme_font_override("font", logo_font)
		title.add_theme_font_size_override("font_size", 54)
		title.add_theme_color_override("font_color", Color(0.960, 0.930, 0.850, 1.0))
		title.add_theme_color_override("font_outline_color", Color(0.050, 0.090, 0.120, 0.9))
		title.add_theme_constant_override("outline_size", 3)
		title.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.add_theme_constant_override("shadow_offset_y", 2)

	var vbox := get_node_or_null("RightUiSlot/CenterContainer/VBoxContainer") as VBoxContainer
	if vbox != null:
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 22)
		vbox.custom_minimum_size = Vector2(430.0, 440.0)

	var start_button := get_node_or_null("%StartButton") as Button
	if start_button != null:
		start_button.text = "开始行动"
		start_button.custom_minimum_size = Vector2(380.0, UiTokens.BUTTON_H_LG)
		start_button.add_theme_font_size_override("font_size", 20)
		start_button.add_theme_stylebox_override("normal", GameUiStyle.accent_button(GameUiStyle.ACCENT))
		start_button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.ACCENT))
		start_button.add_theme_stylebox_override("pressed", GameUiStyle.accent_button(GameUiStyle.AMBER))
		start_button.add_theme_stylebox_override("disabled", GameUiStyle.disabled_button())

	var tutorial_button := get_node_or_null("%TutorialButton") as Button
	if tutorial_button != null:
		tutorial_button.text = _get_tutorial_button_text()
		tutorial_button.custom_minimum_size = Vector2(380.0, 52.0)
		tutorial_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tutorial_button.add_theme_font_size_override("font_size", 18)
		tutorial_button.add_theme_color_override("font_color", GameUiStyle.TEXT)
		tutorial_button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT)
		tutorial_button.add_theme_color_override("font_pressed_color", GameUiStyle.TEXT)
		tutorial_button.add_theme_stylebox_override("normal", GameUiStyle.secondary_button())
		tutorial_button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.ACCENT))
		tutorial_button.add_theme_stylebox_override("pressed", GameUiStyle.accent_button(GameUiStyle.AMBER))
		tutorial_button.add_theme_stylebox_override("disabled", GameUiStyle.disabled_button())

	var subtitle := get_node_or_null("RightUiSlot/CenterContainer/VBoxContainer/SubtitleLabel") as Label
	if subtitle != null:
		subtitle.text = "— 昼夜防线指挥 —"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 17)
		subtitle.add_theme_color_override("font_color", Color(0.670, 0.760, 0.860, 1.0))

	if vbox != null and subtitle != null and vbox.get_node_or_null("SubtitleSpacer") == null:
		var spacer := Control.new()
		spacer.name = "SubtitleSpacer"
		spacer.custom_minimum_size = Vector2(0.0, 14.0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(spacer)
		vbox.move_child(spacer, subtitle.get_index() + 1)


func _get_tutorial_button_text() -> String:
	var run_state = AppRefs.run_state()
	if run_state != null and bool(run_state.get("tutorial_completed")):
		return "新手教程 · 已完成"
	return "新手教程 · 第一天演习"
