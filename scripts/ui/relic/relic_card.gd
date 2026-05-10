extends PanelContainer

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

signal pressed(buff_id: StringName)

var buff_id := StringName()
var _cfg: Dictionary = {}
var _selectable := true
var _selected := false
var _compact := false
var _choice_mode := false

@onready var _icon_panel: PanelContainer = %IconPanel
@onready var _icon_label: Label = %IconLabel
@onready var _name_label: Label = %NameLabel
@onready var _rarity_label: Label = %RarityLabel
@onready var _desc_label: Label = %DescLabel
@onready var _tag_label: Label = %TagLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	gui_input.connect(_on_gui_input)
	_icon_panel.add_theme_stylebox_override("panel", GameUiStyle.icon_tile())
	_name_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_rarity_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_desc_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_tag_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.add_theme_font_size_override("font_size", 22)
	for label in [_name_label, _rarity_label, _desc_label, _tag_label, _icon_label]:
		_add_label_shadow(label)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rarity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUiStyle.apply_frame_margin(get_node_or_null("CardMargin") as MarginContainer, GameUiStyle.FRAME_RELIC_CARD)
	_apply_config()


func configure(new_buff_id: StringName, cfg: Dictionary, options: Dictionary = {}) -> void:
	buff_id = new_buff_id
	_cfg = cfg.duplicate(true)
	_selectable = bool(options.get("selectable", true))
	_selected = bool(options.get("selected", false))
	_compact = bool(options.get("compact", false))
	_choice_mode = bool(options.get("choice_mode", false))
	if is_node_ready():
		_apply_config()


func get_buff_id() -> StringName:
	return buff_id


func set_selected(selected: bool) -> void:
	_selected = selected
	if is_node_ready():
		_apply_style()


func _apply_config() -> void:
	var rarity := int(_cfg.get("rarity", 1))
	custom_minimum_size = Vector2(0.0, 104.0 if _compact else 116.0)
	if _choice_mode:
		custom_minimum_size.y = 96.0
	_icon_label.text = UiDisplayText.icon_text(_cfg, "遗")
	_icon_label.add_theme_color_override("font_color", UiDisplayText.relic_rarity_color(rarity))
	_name_label.text = UiDisplayText.config_name(_cfg, buff_id)
	_rarity_label.text = UiDisplayText.relic_rarity_label(rarity)
	_rarity_label.add_theme_color_override("font_color", UiDisplayText.relic_rarity_color(rarity))
	_desc_label.text = UiDisplayText.relic_effect_text(_cfg)
	_tag_label.text = UiDisplayText.relic_tag_text(_cfg)
	tooltip_text = UiDisplayText.relic_tooltip_text(buff_id, _cfg)
	_apply_density()
	_apply_style()


func _apply_density() -> void:
	var compact_font := _compact or _choice_mode
	_name_label.add_theme_font_size_override("font_size", 15 if compact_font else 16)
	_rarity_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_font_size_override("font_size", 12 if compact_font else 13)
	_tag_label.add_theme_font_size_override("font_size", 12)
	_icon_panel.custom_minimum_size = Vector2(46.0 if compact_font else 54.0, 0.0)


func _apply_style() -> void:
	if _choice_mode:
		add_theme_stylebox_override("panel", GameUiStyle.blessing_choice_card(_selected))
	else:
		add_theme_stylebox_override("panel", GameUiStyle.relic_card(int(_cfg.get("rarity", 1)), _selected))
	modulate.a = 1.0 if _selectable else 0.72


func _on_gui_input(event: InputEvent) -> void:
	if not _selectable or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		pressed.emit(buff_id)
		accept_event()


func _add_label_shadow(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
