extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")


func _ready() -> void:
	AppTheme.apply(self)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.blessing_choices_ready.connect(show_choices)
	_connect_choice_button("%ChoiceButton1")
	_connect_choice_button("%ChoiceButton2")
	_connect_choice_button("%ChoiceButton3")
	_style_choice_button("%ChoiceButton1")
	_style_choice_button("%ChoiceButton2")
	_style_choice_button("%ChoiceButton3")
	hide_panel()


func show_choices(choice_ids: Array[StringName]) -> void:
	visible = true
	var buttons := [
		get_node_or_null("%ChoiceButton1") as BaseButton,
		get_node_or_null("%ChoiceButton2") as BaseButton,
		get_node_or_null("%ChoiceButton3") as BaseButton
	]
	for i in range(buttons.size()):
		var button: BaseButton = buttons[i]
		if button == null:
			continue
		button.disabled = i >= choice_ids.size()
		if i < choice_ids.size():
			var buff_id := choice_ids[i]
			var data_repo = AppRefs.data_repo()
			var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
			button.text = "%s\n%s" % [String(cfg.get("name", buff_id)), String(cfg.get("desc", "暂无效果说明"))]
			button.tooltip_text = String(cfg.get("desc", ""))
			button.set_meta("buff_id", buff_id)
		else:
			button.text = "未提供"
			button.tooltip_text = ""


func hide_panel() -> void:
	visible = false


func _connect_choice_button(path: String) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button != null and not button.pressed.is_connected(_on_choice_pressed.bind(button)):
		button.pressed.connect(_on_choice_pressed.bind(button))


func _style_choice_button(path: String) -> void:
	var button := get_node_or_null(path) as Button
	if button == null:
		return
	button.custom_minimum_size = Vector2(320.0, 78.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_stylebox_override("normal", GameUiStyle.card(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_CARD, 1.0))
	button.add_theme_stylebox_override("hover", GameUiStyle.card(GameUiStyle.ACCENT, GameUiStyle.BG_CARD_HOVER, 1.5))
	button.add_theme_stylebox_override("pressed", GameUiStyle.card(GameUiStyle.AMBER, GameUiStyle.BG_CARD_HOVER, 2.0))
	button.add_theme_stylebox_override("disabled", GameUiStyle.card(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_DISABLED, 1.0))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)


func _on_choice_pressed(button: BaseButton) -> void:
	var buff_id := StringName(button.get_meta("buff_id", ""))
	if buff_id == StringName():
		return
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.blessing_chosen.emit(buff_id)
	hide_panel()
