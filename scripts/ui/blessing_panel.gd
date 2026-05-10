extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const PANEL_SIZE := Vector2(600.0, 380.0)
const RELIC_CARD_SCENE := preload("res://scenes/ui/relic/RelicCard.tscn")

@onready var _choice_list: VBoxContainer = %ChoiceList


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	_place_centered()
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.blessing_choices_ready.connect(show_choices)
	hide_panel()


func show_choices(choice_ids: Array[StringName]) -> void:
	_place_centered()
	visible = true
	_clear_choices()
	var data_repo = AppRefs.data_repo()
	for buff_id in choice_ids:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		var card = RELIC_CARD_SCENE.instantiate()
		card.configure(buff_id, cfg, {
			"selectable": true,
			"choice_mode": true
		})
		card.pressed.connect(_on_choice_pressed)
		_choice_list.add_child(card)


func hide_panel() -> void:
	visible = false


func _apply_visual_style() -> void:
	add_theme_stylebox_override("panel", GameUiStyle.blessing_panel())
	GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin") as MarginContainer, GameUiStyle.FRAME_BLESSING_PANEL)
	var title := get_node_or_null("ContentMargin/VBoxContainer/TitleLabel") as Label
	if title != null:
		title.add_theme_color_override("font_color", GameUiStyle.TEXT)
		title.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		title.add_theme_font_size_override("font_size", 22)
		GameUiStyle.center_label_text(title)


func _place_centered() -> void:
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -PANEL_SIZE.x * 0.5
	offset_top = -PANEL_SIZE.y * 0.5
	offset_right = PANEL_SIZE.x * 0.5
	offset_bottom = PANEL_SIZE.y * 0.5


func _on_choice_pressed(buff_id: StringName) -> void:
	if buff_id == StringName():
		return
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.blessing_chosen.emit(buff_id)
	hide_panel()


func _clear_choices() -> void:
	for child in _choice_list.get_children():
		child.queue_free()
