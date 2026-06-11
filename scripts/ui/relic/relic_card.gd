extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

signal pressed(buff_id: StringName)

static var _stat_wrap_regex: RegEx = null

var buff_id := StringName()
var _cfg: Dictionary = {}
var _selectable := true
var _selected := false
var _compact := false
var _choice_mode := false
var _show_effect := true
var _hovered := false

@onready var _card_base: Panel = %CardBase
@onready var _icon_stack: Control = %IconStack
@onready var _icon_texture: TextureRect = %IconTexture
@onready var _icon_frame: Panel = %IconFrame
@onready var _rarity_overlay: Panel = %RarityOverlay
@onready var _hover_overlay: Panel = %HoverOverlay
@onready var _icon_label: Label = %IconLabel
@onready var _name_label: Label = %NameLabel
@onready var _rarity_label: Label = %RarityLabel
@onready var _desc_label: Label = %DescLabel
@onready var _tag_label: Label = %TagLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void:
		_hovered = true
		_apply_style()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_apply_style()
	)
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
	_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_content_margins()
	_apply_config()


func _apply_content_margins() -> void:
	var content_margin := get_node_or_null("ContentMargin") as MarginContainer
	if content_margin != null:
		content_margin.add_theme_constant_override("margin_top", 12)
		content_margin.add_theme_constant_override("margin_bottom", 12)
		content_margin.add_theme_constant_override("margin_right", 24)
	var text_column := get_node_or_null("ContentMargin/Row/TextColumn") as VBoxContainer
	if text_column != null:
		text_column.add_theme_constant_override("separation", 6)


func configure(new_buff_id: StringName, cfg: Dictionary, options: Dictionary = {}) -> void:
	buff_id = new_buff_id
	_cfg = cfg.duplicate(true)
	_selectable = bool(options.get("selectable", true))
	_selected = bool(options.get("selected", false))
	_compact = bool(options.get("compact", false))
	_choice_mode = bool(options.get("choice_mode", false))
	_show_effect = bool(options.get("show_effect", true))
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
	var compact_height := 72.0 if not _show_effect else 96.0
	set_custom_minimum_size(Vector2(0.0, compact_height if _compact else 108.0))
	if _choice_mode:
		custom_minimum_size.y = 96.0
	var texture := UiArtRegistry.get_icon_texture(_cfg, &"relic_bag")
	_icon_texture.texture = texture
	_icon_texture.visible = texture != null
	_icon_label.visible = texture == null
	_icon_label.text = UiDisplayText.icon_text(_cfg, "遗")
	_icon_label.add_theme_color_override("font_color", UiDisplayText.relic_rarity_color(rarity))
	_name_label.text = UiDisplayText.config_name(_cfg, buff_id)
	_rarity_label.text = UiDisplayText.relic_rarity_label(rarity)
	_rarity_label.add_theme_color_override("font_color", UiDisplayText.relic_rarity_color(rarity))
	_apply_rarity_badge(UiDisplayText.relic_rarity_color(rarity))
	_desc_label.text = _join_stat_wraps(UiDisplayText.relic_effect_text(_cfg)) if _show_effect else ""
	_desc_label.visible = _show_effect
	_tag_label.text = UiDisplayText.relic_tag_text(_cfg)
	tooltip_text = UiDisplayText.relic_tooltip_text(buff_id, _cfg)
	_apply_density()
	_apply_style()


func _apply_rarity_badge(rarity_color: Color) -> void:
	# 品质字若裸贴在卡框角饰上会被金属高光吃掉,垫一层稀有度色徽板
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18)
	badge.border_color = rarity_color
	badge.set_border_width_all(1)
	badge.set_corner_radius_all(3)
	badge.content_margin_left = 6.0
	badge.content_margin_right = 6.0
	badge.content_margin_top = 2.0
	badge.content_margin_bottom = 2.0
	_rarity_label.add_theme_stylebox_override("normal", badge)
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func _join_stat_wraps(text: String) -> String:
	# U+2060 WORD JOINER 防止「攻击 +100%」在数值前折行出孤行
	if _stat_wrap_regex == null:
		_stat_wrap_regex = RegEx.new()
		_stat_wrap_regex.compile("(攻击|攻速|防御|生命|法抗) \\+")
	return _stat_wrap_regex.sub(text, "$1 \u2060+", true)


func _apply_density() -> void:
	var compact_font := _compact or _choice_mode
	_name_label.add_theme_font_size_override("font_size", 14 if _compact and not _show_effect else (15 if compact_font else 16))
	_rarity_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_font_size_override("font_size", 12 if compact_font else 13)
	_tag_label.add_theme_font_size_override("font_size", 13 if not _show_effect else 12)
	var icon_size := 42.0 if _compact and not _show_effect else (46.0 if compact_font else 52.0)
	_icon_stack.set_custom_minimum_size(Vector2(icon_size, icon_size))
	_icon_frame.set_custom_minimum_size(Vector2(icon_size, 0.0))
	GameUiStyle.fit_centered_icon(_icon_texture, Vector2(icon_size * 0.76, icon_size * 0.76))


func _apply_style() -> void:
	var rarity := int(_cfg.get("rarity", 1))
	if _choice_mode:
		_card_base.add_theme_stylebox_override("panel", GameUiStyle.blessing_choice_card(_selected or _hovered))
	else:
		_card_base.add_theme_stylebox_override("panel", GameUiStyle.relic_card(rarity, _selected))
	_icon_frame.add_theme_stylebox_override("panel", GameUiStyle.relic_icon(rarity, _selected or _hovered))
	_rarity_overlay.add_theme_stylebox_override("panel", GameUiStyle.relic_rarity_overlay(rarity, _selected, _compact or _choice_mode))
	_hover_overlay.add_theme_stylebox_override("panel", GameUiStyle.relic_card_hover_overlay(_selected))
	_hover_overlay.visible = _selected or _hovered
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
