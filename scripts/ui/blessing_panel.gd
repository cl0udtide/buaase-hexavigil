extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const PANEL_SIZE := Vector2(580.0, 330.0)


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	_place_centered()
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.blessing_choices_ready.connect(show_choices)
	for button in _get_choice_buttons():
		_connect_choice_button(button)
		_style_choice_button(button)
	hide_panel()


func show_choices(choice_ids: Array[StringName]) -> void:
	_place_centered()
	visible = true
	var buttons := _get_choice_buttons()
	for i in range(buttons.size()):
		var button: BaseButton = buttons[i]
		if button == null:
			continue
		button.visible = i < choice_ids.size()
		button.disabled = i >= choice_ids.size()
		if i < choice_ids.size():
			var buff_id := choice_ids[i]
			var data_repo = AppRefs.data_repo()
			var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
			button.text = _format_relic_button_text(buff_id, cfg)
			button.tooltip_text = String(cfg.get("desc", "暂无效果说明"))
			button.set_meta("buff_id", buff_id)
		else:
			button.text = "未提供"
			button.tooltip_text = ""


func hide_panel() -> void:
	visible = false


func _connect_choice_button(button: BaseButton) -> void:
	if button != null and not button.pressed.is_connected(_on_choice_pressed.bind(button)):
		button.pressed.connect(_on_choice_pressed.bind(button))


func _style_choice_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(420.0, 96.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_stylebox_override("normal", GameUiStyle.card(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_CARD, 1.0))
	button.add_theme_stylebox_override("hover", GameUiStyle.card(GameUiStyle.ACCENT, GameUiStyle.BG_CARD_HOVER, 1.5))
	button.add_theme_stylebox_override("pressed", GameUiStyle.card(GameUiStyle.AMBER, GameUiStyle.BG_CARD_HOVER, 2.0))
	button.add_theme_stylebox_override("disabled", GameUiStyle.card(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_DISABLED, 1.0))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_hover_color", GameUiStyle.ACCENT)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)


func _apply_visual_style() -> void:
	add_theme_stylebox_override("panel", GameUiStyle.side_panel())
	GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin") as MarginContainer, GameUiStyle.FRAME_SIDE_PANEL)


func _place_centered() -> void:
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -PANEL_SIZE.x * 0.5
	offset_top = -PANEL_SIZE.y * 0.5
	offset_right = PANEL_SIZE.x * 0.5
	offset_bottom = PANEL_SIZE.y * 0.5


func _on_choice_pressed(button: BaseButton) -> void:
	var buff_id := StringName(button.get_meta("buff_id", ""))
	if buff_id == StringName():
		return
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.blessing_chosen.emit(buff_id)
	hide_panel()


func _get_choice_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	var container := get_node_or_null("%ChoiceList")
	if container == null:
		container = get_node_or_null("ContentMargin/VBoxContainer")
	if container == null:
		return buttons
	for child in container.get_children():
		if child is Button:
			buttons.append(child as Button)
	return buttons


func _format_relic_button_text(buff_id: StringName, cfg: Dictionary) -> String:
	var rarity_text := _rarity_text(int(cfg.get("rarity", 1)))
	var name := String(cfg.get("name", buff_id))
	var desc := String(cfg.get("desc", "暂无效果说明"))
	return "[%s] %s\n%s" % [rarity_text, name, desc]


func _rarity_text(rarity: int) -> String:
	match rarity:
		3:
			return "稀有"
		2:
			return "精良"
		_:
			return "常见"
