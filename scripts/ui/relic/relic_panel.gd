extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

const RELIC_CARD_SCENE := preload("res://scenes/ui/relic/RelicCard.tscn")

signal close_requested

var _relic_ids: Array[StringName] = []
var _current_filter := &"all"

@onready var _count_label: Label = %CountLabel
@onready var _close_button: Button = %CloseButton
@onready var _filter_bar: Container = %FilterBar
@onready var _card_scroll: ScrollContainer = %CardScroll
@onready var _card_grid: VBoxContainer = %CardGrid
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	visible = false
	GameUiStyle.apply_scroll_style(_card_scroll)
	_bind_filter_buttons()
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	_refresh()


func set_relics(relic_ids: Array[StringName]) -> void:
	_relic_ids.clear()
	for relic_id in relic_ids:
		_relic_ids.append(relic_id)
	if is_node_ready():
		_refresh()


func show_panel() -> void:
	visible = true
	_refresh()


func hide_panel() -> void:
	visible = false


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func select_relic(buff_id: StringName) -> void:
	_on_card_pressed(buff_id)


func _refresh() -> void:
	_count_label.text = "%d 件" % _relic_ids.size()
	_refresh_filter_buttons()
	_refresh_cards()


func _refresh_cards() -> void:
	for child in _card_grid.get_children():
		child.queue_free()
	var data_repo = AppRefs.data_repo()
	var visible_ids: Array[StringName] = []
	for buff_id in _relic_ids:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		if UiDisplayText.relic_matches_category(cfg, _current_filter):
			visible_ids.append(buff_id)
	for buff_id in visible_ids:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		var card = RELIC_CARD_SCENE.instantiate()
		card.configure(buff_id, cfg, {
			"selectable": true,
			"compact": true,
			"show_effect": true
		})
		card.set_meta("audio_cue", &"ui_card_select")
		card.pressed.connect(_on_card_pressed)
		_card_grid.add_child(card)
	_empty_label.visible = visible_ids.is_empty()


func _on_card_pressed(_buff_id: StringName) -> void:
	pass


func _bind_filter_buttons() -> void:
	for button in _filter_buttons():
		if not button.has_meta("audio_cue"):
			button.set_meta("audio_cue", &"ui_tab_switch")
		var category := StringName(button.get_meta("category", &"all"))
		button.pressed.connect(_on_filter_pressed.bind(category))
		button.button_pressed = category == _current_filter


func _on_filter_pressed(category: StringName) -> void:
	_current_filter = category
	_refresh()


func _refresh_filter_buttons() -> void:
	for button in _filter_buttons():
		var category := StringName(button.get_meta("category", &"all"))
		button.button_pressed = category == _current_filter


func _filter_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in _filter_bar.get_children():
		if child is Button:
			buttons.append(child as Button)
	return buttons
