extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

signal pressed(buff_id: StringName)

var buff_id := StringName()
var _cfg: Dictionary = {}
var _highlighted := false

@onready var _icon_backplate: Panel = %IconBackplate
@onready var _icon_texture: TextureRect = %IconTexture
@onready var _icon_frame: Panel = %IconFrame
@onready var _rarity_overlay: Panel = %RarityOverlay
@onready var _new_highlight_overlay: Panel = %NewHighlightOverlay
@onready var _icon_label: Label = %IconLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	gui_input.connect(_on_gui_input)
	_icon_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	_icon_label.add_theme_font_size_override("font_size", 18)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_backplate.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_RELIC_ICON_BACKPLATE, GameUiStyle.ACCENT_SOFT, GameUiStyle.STROKE_SOFT))
	_new_highlight_overlay.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_RELIC_ICON, Color(0.950, 0.650, 0.220, 0.09), GameUiStyle.AMBER, false))
	_apply_config()


func configure(new_buff_id: StringName, cfg: Dictionary, highlighted: bool = false) -> void:
	buff_id = new_buff_id
	_cfg = cfg.duplicate(true)
	_highlighted = highlighted
	if is_node_ready():
		_apply_config()


func set_highlighted(highlighted: bool) -> void:
	_highlighted = highlighted
	if is_node_ready():
		_apply_style()


func _apply_config() -> void:
	var rarity := int(_cfg.get("rarity", 1))
	custom_minimum_size = Vector2(34.0, 34.0)
	var texture := UiArtRegistry.get_texture(buff_id, &"icon")
	_icon_texture.texture = texture
	_icon_texture.visible = texture != null
	_icon_label.visible = texture == null
	_icon_label.text = UiDisplayText.icon_text(_cfg, "遗")
	_icon_label.add_theme_color_override("font_color", UiDisplayText.relic_rarity_color(rarity))
	tooltip_text = UiDisplayText.relic_tooltip_text(buff_id, _cfg)
	_apply_style()


func _apply_style() -> void:
	var rarity := int(_cfg.get("rarity", 1))
	_icon_frame.add_theme_stylebox_override("panel", GameUiStyle.relic_icon(rarity, _highlighted))
	_rarity_overlay.add_theme_stylebox_override("panel", GameUiStyle.relic_rarity_overlay(rarity))
	_new_highlight_overlay.visible = _highlighted


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		pressed.emit(buff_id)
		accept_event()
