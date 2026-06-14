extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

const RELIC_CARD_SCENE := preload("res://scenes/ui/relic/RelicCard.tscn")

signal close_requested

var _relic_ids: Array[StringName] = []
var _current_filter := &"all"
var _selected_buff_id := StringName()

@onready var _title_label: Label = %TitleLabel
@onready var _count_label: Label = %CountLabel
@onready var _close_button: Button = %CloseButton
@onready var _filter_bar: Container = %FilterBar
@onready var _card_scroll: ScrollContainer = %CardScroll
@onready var _card_grid: VBoxContainer = %CardGrid
@onready var _empty_label: Label = %EmptyLabel
@onready var _detail_panel: Panel = %DetailPanel
@onready var _detail_title_label: Label = %DetailTitleLabel
@onready var _detail_meta_label: Label = %DetailMetaLabel
@onready var _detail_effect_label: Label = %DetailEffectLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	visible = false
	_style_labels()
	GameUiStyle.apply_scroll_style(_card_scroll)
	_bind_filter_buttons()
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	_style_close_button()
	_refresh()


func set_relics(relic_ids: Array[StringName]) -> void:
	_relic_ids.clear()
	for relic_id in relic_ids:
		_relic_ids.append(relic_id)
	if not _relic_ids.has(_selected_buff_id):
		_selected_buff_id = _relic_ids[0] if not _relic_ids.is_empty() else StringName()
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
	_selected_buff_id = buff_id
	if is_node_ready():
		_refresh_detail()
		_refresh_card_selection()


func _refresh() -> void:
	_count_label.text = "%d 件" % _relic_ids.size()
	_refresh_filter_buttons()
	_refresh_cards()
	_refresh_detail()


func _refresh_cards() -> void:
	for child in _card_grid.get_children():
		child.queue_free()
	var data_repo = AppRefs.data_repo()
	var visible_ids: Array[StringName] = []
	for buff_id in _relic_ids:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		if UiDisplayText.relic_matches_category(cfg, _current_filter):
			visible_ids.append(buff_id)
	if not visible_ids.has(_selected_buff_id):
		_selected_buff_id = visible_ids[0] if not visible_ids.is_empty() else StringName()
	for buff_id in visible_ids:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		var card = RELIC_CARD_SCENE.instantiate()
		card.configure(buff_id, cfg, {
			"selectable": true,
			"selected": buff_id == _selected_buff_id,
			"compact": true,
			"show_effect": false
		})
		card.set_meta("audio_cue", &"ui_card_select")
		card.pressed.connect(_on_card_pressed)
		_card_grid.add_child(card)
	_empty_label.visible = visible_ids.is_empty()


func _refresh_card_selection() -> void:
	for child in _card_grid.get_children():
		if child.has_method("get_buff_id") and child.has_method("set_selected"):
			child.set_selected(child.get_buff_id() == _selected_buff_id)


func _refresh_detail() -> void:
	if _selected_buff_id == StringName():
		_detail_title_label.text = "暂无遗物"
		_detail_meta_label.text = "当前还没有获得遗物"
		_detail_effect_label.text = "通过祝福选择获得遗物后，这里会显示完整效果。"
		return
	var data_repo = AppRefs.data_repo()
	var cfg: Dictionary = data_repo.get_buff_cfg(_selected_buff_id) if data_repo != null else {}
	_detail_title_label.text = UiDisplayText.config_name(cfg, _selected_buff_id)
	_detail_meta_label.text = "%s 路 %s" % [
		UiDisplayText.relic_rarity_label(int(cfg.get("rarity", 1))),
		UiDisplayText.relic_tag_text(cfg)
	]
	_detail_meta_label.add_theme_color_override("font_color", UiDisplayText.relic_rarity_color(int(cfg.get("rarity", 1))))
	_detail_effect_label.text = UiDisplayText.relic_effect_text(cfg)


func _on_card_pressed(buff_id: StringName) -> void:
	select_relic(buff_id)


func _bind_filter_buttons() -> void:
	for button in _filter_buttons():
		button.focus_mode = Control.FOCUS_NONE
		button.set_custom_minimum_size(Vector2(86.0, 32.0))
		if not button.has_meta("audio_cue"):
			button.set_meta("audio_cue", &"ui_tab_switch")
		var category := StringName(button.get_meta("category", &"all"))
		button.pressed.connect(_on_filter_pressed.bind(category))
		_style_filter_button(button, category == _current_filter)


func _on_filter_pressed(category: StringName) -> void:
	_current_filter = category
	_refresh()


func _refresh_filter_buttons() -> void:
	for button in _filter_buttons():
		var category := StringName(button.get_meta("category", &"all"))
		_style_filter_button(button, category == _current_filter)


func _filter_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in _filter_bar.get_children():
		if child is Button:
			buttons.append(child as Button)
	return buttons


func _style_labels() -> void:
	for label in [_title_label, _count_label, _empty_label, _detail_title_label, _detail_meta_label, _detail_effect_label]:
		label.add_theme_color_override("font_color", GameUiStyle.TEXT)
		label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
	_title_label.add_theme_font_size_override("font_size", 22)
	_detail_title_label.add_theme_font_size_override("font_size", 15)
	_detail_meta_label.add_theme_font_size_override("font_size", 12)
	_detail_effect_label.add_theme_font_size_override("font_size", 12)
	_detail_effect_label.add_theme_constant_override("line_spacing", 0)
	_count_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_empty_label.add_theme_color_override("font_color", GameUiStyle.TEXT_MUTED)
	_detail_effect_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_detail_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _style_filter_button(button: Button, selected: bool) -> void:
	GameUiStyle.center_button_text(button)
	GameUiStyle.set_button_texture_icon(button, UiArtRegistry.get_catalog_icon(StringName("filter_%s" % String(button.get_meta("category", &"all")))), &"left", 7.0)
	button.add_theme_stylebox_override("normal", GameUiStyle.relic_filter_tab(selected, false))
	button.add_theme_stylebox_override("hover", GameUiStyle.relic_filter_tab(selected, true))
	button.add_theme_stylebox_override("pressed", GameUiStyle.relic_filter_tab(true, true))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT if selected else GameUiStyle.TEXT_DIM)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT)
	button.add_theme_font_size_override("font_size", 12)


func _style_close_button() -> void:
	_close_button.set_custom_minimum_size(Vector2(34.0, 30.0))
	GameUiStyle.set_button_texture_icon(_close_button, UiArtRegistry.get_catalog_icon(&"button_close"), &"center")
	GameUiStyle.center_button_text(_close_button)
	_close_button.add_theme_stylebox_override("normal", _close_button_highlight_style(0.0))
	_close_button.add_theme_stylebox_override("hover", _close_button_highlight_style(0.12))
	_close_button.add_theme_stylebox_override("pressed", _close_button_highlight_style(0.18))
	_close_button.add_theme_color_override("font_color", GameUiStyle.TEXT)


func _close_button_highlight_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, alpha)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style
