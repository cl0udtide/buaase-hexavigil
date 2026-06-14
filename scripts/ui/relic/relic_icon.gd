extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

signal pressed(buff_id: StringName)

var buff_id := StringName()
var _cfg: Dictionary = {}
var _highlighted := false

@onready var _icon_texture: TextureRect = %IconTexture
@onready var _icon_backplate: Panel = %IconBackplate
@onready var _icon_frame: Panel = %IconFrame
@onready var _rarity_overlay: Panel = %RarityOverlay
@onready var _new_highlight_overlay: Panel = %NewHighlightOverlay


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	gui_input.connect(_on_gui_input)
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
	var texture := UiArtRegistry.get_icon_texture(_cfg, &"relic_bag")
	_icon_texture.texture = texture
	_icon_texture.visible = texture != null
	tooltip_text = UiDisplayText.relic_tooltip_text(buff_id, _cfg)
	_apply_style()


func _apply_style() -> void:
	var rarity := int(_cfg.get("rarity", 1))
	var rarity_color := UiDisplayText.relic_rarity_color(rarity)
	var backplate_strength := 0.12
	if rarity == 2:
		backplate_strength = 0.18
	elif rarity >= 3:
		backplate_strength = 0.24
	_icon_backplate.modulate = Color(
		0.72 + rarity_color.r * backplate_strength,
		0.72 + rarity_color.g * backplate_strength,
		0.72 + rarity_color.b * backplate_strength,
		1.0
	)
	_icon_frame.modulate = Color(
		0.88 + rarity_color.r * 0.12,
		0.88 + rarity_color.g * 0.12,
		0.88 + rarity_color.b * 0.12,
		1.0
	)
	_rarity_overlay.modulate = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.12)
	_new_highlight_overlay.visible = _highlighted


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		pressed.emit(buff_id)
		accept_event()
