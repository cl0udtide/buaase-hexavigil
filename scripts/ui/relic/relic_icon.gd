extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

signal pressed(buff_id: StringName)

var buff_id := StringName()
var _cfg: Dictionary = {}

@onready var _icon_texture: TextureRect = %IconTexture
@onready var _common_backplate: Panel = %CommonBackplate
@onready var _uncommon_backplate: Panel = %UncommonBackplate
@onready var _rare_backplate: Panel = %RareBackplate
@onready var _icon_frame: Panel = %IconFrame


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	gui_input.connect(_on_gui_input)
	_apply_config()


func configure(new_buff_id: StringName, cfg: Dictionary, _highlighted: bool = false) -> void:
	buff_id = new_buff_id
	_cfg = cfg.duplicate(true)
	if is_node_ready():
		_apply_config()


func _apply_config() -> void:
	var rarity := int(_cfg.get("rarity", 1))
	var texture := UiArtRegistry.get_icon_texture(_cfg)
	_icon_texture.texture = texture
	_icon_texture.visible = texture != null
	tooltip_text = UiDisplayText.relic_tooltip_text(buff_id, _cfg)
	_apply_style()


func _apply_style() -> void:
	var rarity := int(_cfg.get("rarity", 1))
	_apply_backplate_visibility(rarity)


func _apply_backplate_visibility(rarity: int) -> void:
	var rarity_index := _rarity_index(rarity)
	_common_backplate.visible = rarity_index == 1
	_uncommon_backplate.visible = rarity_index == 2
	_rare_backplate.visible = rarity_index == 3


func _rarity_index(rarity: int) -> int:
	if rarity >= 3:
		return 3
	if rarity == 2:
		return 2
	return 1


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		pressed.emit(buff_id)
		accept_event()
