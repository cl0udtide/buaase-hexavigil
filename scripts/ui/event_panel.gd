extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const PANEL_SIZE := Vector2(540.0, 260.0)


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	_place_centered()
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.random_event_triggered.connect(_on_random_event_triggered)
	var close_button := get_node_or_null("%CloseButton") as BaseButton
	if close_button != null:
		close_button.pressed.connect(hide_event)


func show_event(event_cfg: Dictionary) -> void:
	_place_centered()
	visible = true
	var title := get_node_or_null("%TitleLabel") as Label
	var desc := get_node_or_null("%DescLabel") as Label
	if title != null:
		title.text = String(event_cfg.get("name", "未知事件"))
	if desc != null:
		desc.text = String(event_cfg.get("desc", ""))


func hide_event() -> void:
	visible = false


func _on_random_event_triggered(event_id: StringName, _cell: Vector2i) -> void:
	var data_repo = AppRefs.data_repo()
	if data_repo != null:
		show_event(data_repo.get_event_cfg(event_id))


func _apply_visual_style() -> void:
	add_theme_stylebox_override("panel", GameUiStyle.panel(GameUiStyle.BG_DARK, GameUiStyle.STROKE_STRONG, 1.0, 6.0))
	var title := get_node_or_null("%TitleLabel") as Label
	var desc := get_node_or_null("%DescLabel") as Label
	var close_button := get_node_or_null("%CloseButton") as Button
	if title != null:
		title.add_theme_color_override("font_color", GameUiStyle.ACCENT)
		title.add_theme_font_size_override("font_size", 22)
	if desc != null:
		desc.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	if close_button != null:
		_style_button(close_button, GameUiStyle.ACCENT)


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", GameUiStyle.accent_button(accent))
	button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.AMBER))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.42))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.10))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)


func _place_centered() -> void:
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -PANEL_SIZE.x * 0.5
	offset_top = -PANEL_SIZE.y * 0.5
	offset_right = PANEL_SIZE.x * 0.5
	offset_bottom = PANEL_SIZE.y * 0.5
