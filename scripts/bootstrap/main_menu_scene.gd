extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const GAME_SCENE := "res://scenes/game/Game.tscn"


func _ready() -> void:
	AppTheme.apply(self)
	_build_visual_shell()
	var start_button := _get_start_button()
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	var scene_router = AppRefs.scene_router()
	if scene_router != null:
		scene_router.goto_game()
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _build_visual_shell() -> void:
	var background := ColorRect.new()
	background.name = "TacticalBackground"
	background.color = Color(0.012, 0.018, 0.023, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)

	var grid := _make_grid_overlay()
	add_child(grid)
	move_child(grid, 1)

	var title := _get_menu_node("VBoxContainer/TitleLabel") as Label
	if title != null:
		title.text = "HexaVigil"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 52)
		title.add_theme_color_override("font_color", Color(0.90, 0.96, 0.92, 1.0))
		title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.46))
		title.add_theme_constant_override("outline_size", 2)

	var center := _get_center_container()
	if center != null:
		center.custom_minimum_size = Vector2(520.0, 360.0)

	var vbox := _get_menu_node("VBoxContainer") as VBoxContainer
	if vbox != null:
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 18)

	var start_button := _get_start_button() as Button
	if start_button != null:
		start_button.text = "START OPERATION"
		start_button.custom_minimum_size = Vector2(320.0, 62.0)
		start_button.add_theme_font_size_override("font_size", 18)
		start_button.add_theme_stylebox_override("normal", GameUiStyle.accent_button(GameUiStyle.SUCCESS))
		start_button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.ACCENT))
		start_button.add_theme_stylebox_override("pressed", GameUiStyle.accent_button(GameUiStyle.AMBER))
		start_button.add_theme_stylebox_override("disabled", GameUiStyle.disabled_button())

	if vbox != null and vbox.get_node_or_null("SubtitleLabel") == null:
		var subtitle := Label.new()
		subtitle.name = "SubtitleLabel"
		subtitle.text = "NIGHT WATCH COMMAND"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 15)
		subtitle.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
		vbox.add_child(subtitle)
		vbox.move_child(subtitle, 1)

	var frame := _ensure_menu_card()
	if frame != null:
		frame.set_anchors_preset(Control.PRESET_CENTER)
		frame.offset_left = -300.0
		frame.offset_top = -190.0
		frame.offset_right = 300.0
		frame.offset_bottom = 190.0
		frame.add_theme_stylebox_override("panel", GameUiStyle.card(GameUiStyle.SUCCESS, GameUiStyle.BG_DARK, 1.0))
		move_child(frame, get_child_count() - 1)


func _ensure_menu_card() -> PanelContainer:
	var frame := get_node_or_null("CenterFrame") as PanelContainer
	var center := get_node_or_null("CenterContainer") as CenterContainer
	if frame != null:
		return frame
	frame = PanelContainer.new()
	frame.name = "CenterFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(frame)
	if center != null:
		remove_child(center)
		frame.add_child(center)
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.offset_left = 22.0
		center.offset_top = 20.0
		center.offset_right = -22.0
		center.offset_bottom = -20.0
	return frame


func _get_center_container() -> CenterContainer:
	var center := get_node_or_null("CenterContainer") as CenterContainer
	if center != null:
		return center
	return get_node_or_null("CenterFrame/CenterContainer") as CenterContainer


func _get_menu_node(path: NodePath) -> Node:
	var center := _get_center_container()
	if center == null:
		return null
	return center.get_node_or_null(path)


func _get_start_button() -> BaseButton:
	var button := get_node_or_null("%StartButton") as BaseButton
	if button != null:
		return button
	return _get_menu_node("VBoxContainer/StartButton") as BaseButton


func _make_grid_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "GridOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	for index in range(8):
		var line := ColorRect.new()
		line.color = Color(0.13, 0.54, 0.45, 0.08)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.anchor_left = float(index + 1) / 9.0
		line.anchor_right = line.anchor_left
		line.anchor_top = 0.0
		line.anchor_bottom = 1.0
		line.offset_left = -1.0
		line.offset_right = 1.0
		overlay.add_child(line)
	for index in range(5):
		var line := ColorRect.new()
		line.color = Color(0.13, 0.54, 0.45, 0.08)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.anchor_left = 0.0
		line.anchor_right = 1.0
		line.anchor_top = float(index + 1) / 6.0
		line.anchor_bottom = line.anchor_top
		line.offset_top = -1.0
		line.offset_bottom = 1.0
		overlay.add_child(line)
	return overlay
