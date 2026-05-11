extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiFrameSpec = preload("res://scripts/ui/ui_frame_spec.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

const RELIC_CARD_SCENE := preload("res://scenes/ui/relic/RelicCard.tscn")
const FILTERS := [
	{"category": &"all", "label": "全部"},
	{"category": &"unit", "label": "单位"},
	{"category": &"building", "label": "建筑"},
	{"category": &"economy", "label": "经济"},
	{"category": &"core", "label": "核心"},
	{"category": &"risk", "label": "风险"},
]

signal close_requested

var _relic_ids: Array[StringName] = []
var _current_filter := &"all"
var _selected_buff_id := StringName()

@onready var _panel_base: Panel = %PanelBase
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
	_panel_base.add_theme_stylebox_override("panel", GameUiStyle.relic_panel())
	GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin") as MarginContainer, GameUiStyle.FRAME_RELIC_PANEL)
	_style_labels()
	_detail_panel.add_theme_stylebox_override("panel", GameUiStyle.detail_section())
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
			"compact": true
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
	_detail_meta_label.text = "%s · %s" % [
		UiDisplayText.relic_rarity_label(int(cfg.get("rarity", 1))),
		UiDisplayText.relic_tag_text(cfg)
	]
	_detail_meta_label.add_theme_color_override("font_color", UiDisplayText.relic_rarity_color(int(cfg.get("rarity", 1))))
	_detail_effect_label.text = UiDisplayText.relic_effect_text(cfg)


func _on_card_pressed(buff_id: StringName) -> void:
	select_relic(buff_id)


func _bind_filter_buttons() -> void:
	for child in _filter_bar.get_children():
		child.free()
	for filter_def in FILTERS:
		var button := Button.new()
		button.text = String(filter_def.get("label", ""))
		button.focus_mode = Control.FOCUS_NONE
		button.set_custom_minimum_size(Vector2(72.0, 32.0))
		button.set_meta("category", filter_def.get("category", &"all"))
		button.set_meta("audio_cue", &"ui_tab_switch")
		_filter_bar.add_child(button)
		var category := StringName(filter_def.get("category", &"all"))
		button.pressed.connect(_on_filter_pressed.bind(category))
		_style_filter_button(button, category == _current_filter)


func _on_filter_pressed(category: StringName) -> void:
	_current_filter = category
	_refresh()


func _refresh_filter_buttons() -> void:
	for button in _filter_bar.get_children():
		if button is Button:
			var category := StringName((button as Button).get_meta("category", &"all"))
			_style_filter_button(button as Button, category == _current_filter)


func _style_labels() -> void:
	for label in [_title_label, _count_label, _empty_label, _detail_title_label, _detail_meta_label, _detail_effect_label]:
		label.add_theme_color_override("font_color", GameUiStyle.TEXT)
		label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
	_title_label.add_theme_font_size_override("font_size", 22)
	_detail_title_label.add_theme_font_size_override("font_size", 18)
	_count_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_empty_label.add_theme_color_override("font_color", GameUiStyle.TEXT_MUTED)
	_detail_effect_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_detail_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _style_filter_button(button: Button, selected: bool) -> void:
	GameUiStyle.center_button_text(button)
	var normal_component := UiFrameSpec.RELIC_FILTER_SELECTED if selected else UiFrameSpec.RELIC_FILTER_TAB
	GameUiStyle.set_button_texture_icon(button, UiArtRegistry.get_catalog_icon(StringName("filter_%s" % String(button.get_meta("category", &"all")))), &"left", 7.0)
	button.add_theme_stylebox_override("normal", GameUiStyle.frame_box(normal_component, GameUiStyle.BG_CARD, GameUiStyle.AMBER if selected else GameUiStyle.STROKE_SOFT))
	button.add_theme_stylebox_override("hover", GameUiStyle.frame_box(UiFrameSpec.RELIC_FILTER_SELECTED, GameUiStyle.BG_CARD, GameUiStyle.AMBER))
	button.add_theme_stylebox_override("pressed", GameUiStyle.frame_box(UiFrameSpec.RELIC_FILTER_SELECTED, GameUiStyle.BG_CARD, GameUiStyle.AMBER))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED if selected else GameUiStyle.TEXT_DIM)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)


func _style_close_button() -> void:
	_close_button.set_custom_minimum_size(Vector2(34.0, 30.0))
	GameUiStyle.set_button_texture_icon(_close_button, UiArtRegistry.get_catalog_icon(&"button_close"), &"center")
	GameUiStyle.center_button_text(_close_button)
	_close_button.add_theme_stylebox_override("normal", GameUiStyle.compact_button(false))
	_close_button.add_theme_stylebox_override("hover", GameUiStyle.compact_button(true))
	_close_button.add_theme_stylebox_override("pressed", GameUiStyle.compact_button(true))
	_close_button.add_theme_color_override("font_color", GameUiStyle.TEXT)
