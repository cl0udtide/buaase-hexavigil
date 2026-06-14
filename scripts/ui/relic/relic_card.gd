extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

signal pressed(buff_id: StringName)

var buff_id := StringName()
var _cfg: Dictionary = {}
var _selectable := true
var _selected := false
var _compact := false
var _choice_mode := false
var _show_effect := true
var _hovered := false
var _slot_source := StringName()

@onready var _common_card_base: Panel = %CommonCardBase
@onready var _uncommon_card_base: Panel = %UncommonCardBase
@onready var _rare_card_base: Panel = %RareCardBase
@onready var _icon_texture: TextureRect = %IconTexture
@onready var _common_backplate: Panel = %CommonBackplate
@onready var _uncommon_backplate: Panel = %UncommonBackplate
@onready var _rare_backplate: Panel = %RareBackplate
@onready var _icon_frame: Panel = %IconFrame
@onready var _hover_overlay: Panel = %HoverOverlay
@onready var _name_label: Label = %NameLabel
@onready var _rarity_label: Label = %RarityLabel
@onready var _desc_label: Label = %DescLabel
@onready var _tag_label: Label = %TagLabel
@onready var _slot_source_label: Label = %SlotSourceLabel


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
	for label in [_name_label, _rarity_label, _desc_label, _tag_label]:
		_add_label_shadow(label)
	_add_label_shadow(_slot_source_label)
	_apply_config()


func configure(new_buff_id: StringName, cfg: Dictionary, options: Dictionary = {}) -> void:
	buff_id = new_buff_id
	_cfg = cfg.duplicate(true)
	_selectable = bool(options.get("selectable", true))
	_selected = bool(options.get("selected", false))
	_compact = bool(options.get("compact", false))
	_choice_mode = bool(options.get("choice_mode", false))
	_show_effect = bool(options.get("show_effect", true))
	_slot_source = StringName(options.get("slot_source", ""))
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
	var texture := UiArtRegistry.get_icon_texture(_cfg)
	_icon_texture.texture = texture
	_icon_texture.visible = texture != null
	_name_label.text = UiDisplayText.config_name(_cfg, buff_id)
	_rarity_label.text = UiDisplayText.relic_rarity_label(rarity)
	var rarity_color := UiDisplayText.relic_rarity_color(rarity)
	_name_label.add_theme_color_override("font_color", rarity_color)
	_rarity_label.add_theme_color_override("font_color", rarity_color)
	_desc_label.text = UiDisplayText.relic_effect_text(_cfg) if _show_effect else ""
	_desc_label.visible = _show_effect
	_tag_label.text = UiDisplayText.relic_tag_text(_cfg)
	tooltip_text = ""
	_refresh_slot_source_badge()
	_apply_style()


## 三选一槽位来源角标：仅在抽取模式 + 有来源时显示，标注盟约导向/经济/随机。
func _refresh_slot_source_badge() -> void:
	var label_text := UiDisplayText.relic_slot_source_label(_slot_source)
	var should_show := _choice_mode and not label_text.is_empty()
	_slot_source_label.text = label_text
	_slot_source_label.add_theme_color_override("font_color", UiDisplayText.relic_slot_source_color(_slot_source))
	_slot_source_label.visible = should_show


func _apply_style() -> void:
	var rarity := int(_cfg.get("rarity", 1))
	_apply_rarity_visibility(rarity)
	_hover_overlay.visible = _selected or _hovered
	modulate.a = 1.0 if _selectable else 0.72


func _apply_rarity_visibility(rarity: int) -> void:
	var rarity_index := _rarity_index(rarity)
	_common_card_base.visible = rarity_index == 1
	_uncommon_card_base.visible = rarity_index == 2
	_rare_card_base.visible = rarity_index == 3
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
	if not _selectable or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		pressed.emit(buff_id)
		accept_event()


func _add_label_shadow(label: Label) -> void:
	if label == null:
		return
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
