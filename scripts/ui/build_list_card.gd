class_name BuildListCard
extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

signal pressed

var _pending_config: Dictionary = {}
var _accent := GameUiStyle.STROKE_SOFT
var _disabled := false
var _pressable_when_disabled := false
var _selected := false
var _hovered := false

@onready var _card_base: Panel = %CardBase
@onready var _icon_backplate: Panel = %IconBackplate
@onready var _icon_texture: TextureRect = %IconTexture
@onready var _icon_frame: Panel = %IconFrame
@onready var _icon_label: Label = %IconLabel
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _state_label: Label = %StateLabel
@onready var _cost_badge: Panel = %CostBadge
@onready var _cost_label: Label = %CostLabel
@onready var _selected_overlay: Panel = %SelectedOverlay
@onready var _disabled_overlay: ColorRect = %DisabledOverlay


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
	_title_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_subtitle_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_detail_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_state_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_icon_label.add_theme_color_override("font_color", GameUiStyle.ACCENT)
	_cost_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	GameUiStyle.center_label_text(_state_label)
	GameUiStyle.center_label_text(_cost_label)
	for label in [_title_label, _subtitle_label, _state_label, _cost_label]:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_add_label_shadow(_title_label)
	_add_label_shadow(_subtitle_label)
	_add_label_shadow(_detail_label)
	_add_label_shadow(_state_label)
	_add_label_shadow(_icon_label)
	_add_label_shadow(_cost_label)
	GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin") as MarginContainer, GameUiStyle.FRAME_LIST_CARD)
	_icon_backplate.add_theme_stylebox_override("panel", GameUiStyle.icon_tile())
	_icon_frame.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_ICON_TILE, Color.TRANSPARENT, GameUiStyle.STROKE_SOFT, false))
	_cost_badge.add_theme_stylebox_override("panel", GameUiStyle.operator_cost_badge())
	_selected_overlay.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_LIST_CARD, Color(0.950, 0.650, 0.220, 0.06), GameUiStyle.AMBER, false))
	_disabled_overlay.color = Color(0.02, 0.03, 0.035, 0.38)
	_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not _pending_config.is_empty():
		_apply_config(_pending_config)
	else:
		_apply_style()


func configure(config: Dictionary) -> void:
	_pending_config = config.duplicate(true)
	if is_node_ready():
		_apply_config(_pending_config)


func _apply_config(config: Dictionary) -> void:
	custom_minimum_size = Vector2(float(config.get("min_width", 0.0)), float(config.get("min_height", 96.0)))
	_accent = config.get("accent", GameUiStyle.STROKE_SOFT) as Color
	_disabled = bool(config.get("disabled", false))
	_pressable_when_disabled = bool(config.get("pressable_when_disabled", false))
	_selected = bool(config.get("selected", false))
	_title_label.text = String(config.get("title", ""))
	_subtitle_label.text = String(config.get("subtitle", ""))
	_detail_label.text = String(config.get("detail", ""))
	_state_label.text = String(config.get("state", ""))
	_icon_label.text = String(config.get("icon_text", "*"))
	_cost_label.text = String(config.get("cost_badge_text", ""))
	_apply_icon_texture(config)
	_subtitle_label.visible = not _subtitle_label.text.is_empty()
	_detail_label.visible = not _detail_label.text.is_empty()
	_state_label.visible = not _state_label.text.is_empty()
	_cost_badge.visible = not _cost_label.text.strip_edges().is_empty()
	_state_label.add_theme_color_override("font_color", config.get("state_color", GameUiStyle.AMBER) as Color)
	_title_label.add_theme_color_override("font_color", GameUiStyle.TEXT if _disabled else config.get("title_color", GameUiStyle.TEXT) as Color)
	_icon_label.add_theme_color_override("font_color", config.get("icon_color", GameUiStyle.ACCENT) as Color)
	_apply_style()


func _apply_icon_texture(_config: Dictionary) -> void:
	_icon_texture.texture = null
	_icon_texture.visible = false
	_icon_label.visible = true


func _apply_style() -> void:
	_card_base.add_theme_stylebox_override("panel", GameUiStyle.list_card(_selected or _hovered))
	_icon_frame.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_ICON_TILE, Color.TRANSPARENT, _accent, false))
	_selected_overlay.visible = _selected or _hovered
	_disabled_overlay.visible = _disabled
	modulate.a = 0.86 if _disabled else 1.0


func _add_label_shadow(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)


func _on_gui_input(event: InputEvent) -> void:
	if (_disabled and not _pressable_when_disabled) or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		pressed.emit()
		accept_event()
