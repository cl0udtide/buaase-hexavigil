extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")


func _ready() -> void:
	AppTheme.apply(self)
	_build_visual_shell()
	var start_button := get_node_or_null("%StartButton") as BaseButton
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	var scene_router = AppRefs.scene_router()
	if scene_router != null:
		scene_router.goto_game()


func _build_visual_shell() -> void:
	var background := ColorRect.new()
	background.name = "TacticalBackground"
	background.color = Color(0.025, 0.033, 0.045, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)

	var grid := _make_grid_overlay()
	add_child(grid)
	move_child(grid, 1)

	var title := get_node_or_null("CenterContainer/VBoxContainer/TitleLabel") as Label
	if title != null:
		title.text = "HexaVigil"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 54)
		title.add_theme_color_override("font_color", Color(0.930, 0.965, 1.000, 1.0))
		title.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
		title.add_theme_constant_override("outline_size", 0)

	var center := get_node_or_null("CenterContainer") as CenterContainer
	if center != null:
		center.custom_minimum_size = Vector2(520.0, 360.0)

	var vbox := get_node_or_null("CenterContainer/VBoxContainer") as VBoxContainer
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

	if vbox != null and vbox.get_node_or_null("SubtitleLabel") == null:
		var subtitle := Label.new()
		subtitle.name = "SubtitleLabel"
		subtitle.text = "昼夜防线指挥"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 17)
		subtitle.add_theme_color_override("font_color", Color(0.670, 0.760, 0.860, 1.0))
		vbox.add_child(subtitle)
		vbox.move_child(subtitle, 1)

	var frame := get_node_or_null("CenterFrame") as PanelContainer
	if frame == null:
		frame = PanelContainer.new()
		frame.name = "CenterFrame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_preset(Control.PRESET_CENTER)
		frame.offset_left = -300.0
		frame.offset_top = -170.0
		frame.offset_right = 300.0
		frame.offset_bottom = 170.0
		frame.add_theme_stylebox_override("panel", GameUiStyle.card(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_GLASS, 1.0))
		add_child(frame)
		move_child(frame, 2)

	var center_node := get_node_or_null("CenterContainer")
	if center_node != null:
		move_child(center_node, get_child_count() - 1)


func _make_grid_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "GridOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	for index in range(8):
		var line := ColorRect.new()
		line.color = Color(0.145, 0.388, 0.920, 0.055)
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
		line.color = Color(0.145, 0.388, 0.920, 0.045)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.anchor_left = 0.0
		line.anchor_right = 1.0
		line.anchor_top = float(index + 1) / 6.0
		line.anchor_bottom = line.anchor_top
		line.offset_top = -1.0
		line.offset_bottom = 1.0
		overlay.add_child(line)
	return overlay
