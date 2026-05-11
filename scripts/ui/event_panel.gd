extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.random_event_triggered.connect(_on_random_event_triggered)
	var close_button := get_node_or_null("%CloseButton") as BaseButton
	if close_button != null:
		close_button.pressed.connect(hide_event)


func show_event(event_cfg: Dictionary) -> void:
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
	add_theme_stylebox_override("panel", GameUiStyle.event_panel())
	GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin") as MarginContainer, GameUiStyle.FRAME_EVENT_PANEL, Vector4(8.0, 6.0, 8.0, 8.0))
	var body_card := get_node_or_null("ContentMargin/VBoxContainer/BodyCard") as PanelContainer
	if body_card != null:
		body_card.add_theme_stylebox_override("panel", GameUiStyle.list_card(false))
		GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin/VBoxContainer/BodyCard/BodyMargin") as MarginContainer, GameUiStyle.FRAME_LIST_CARD)
	var vbox := get_node_or_null("ContentMargin/VBoxContainer") as VBoxContainer
	if vbox != null:
		vbox.add_theme_constant_override("separation", 12)
	var title := get_node_or_null("%TitleLabel") as Label
	var desc := get_node_or_null("%DescLabel") as Label
	var close_button := get_node_or_null("%CloseButton") as Button
	if title != null:
		title.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
		title.add_theme_font_size_override("font_size", 22)
		GameUiStyle.center_label_text(title)
	if desc != null:
		desc.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if close_button != null:
		close_button.set_custom_minimum_size(Vector2(150.0, 40.0))
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_style_button(close_button, GameUiStyle.ACCENT)


func _style_button(button: Button, accent: Color) -> void:
	GameUiStyle.center_button_text(button)
	GameUiStyle.set_button_texture_icon(button, UiArtRegistry.get_catalog_icon(&"button_close"), Vector2(15.0, 15.0), &"left", 8.0)
	button.add_theme_stylebox_override("normal", GameUiStyle.event_choice_button())
	button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.AMBER))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.42))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.10))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_INVERTED_DIM)
