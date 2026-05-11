class_name BuildListCard
extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")

signal pressed
signal drag_started

const DRAG_START_THRESHOLD := 10.0

var _pending_config: Dictionary = {}
var _accent := GameUiStyle.STROKE_SOFT
var _disabled := false
var _pressable_when_disabled := false
var _selected := false
var _hovered := false
var _draggable := false
var _pressing := false
var _press_start_mouse := Vector2.ZERO
var _drag_started := false

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
	_add_label_shadow(_title_label)
	_add_label_shadow(_subtitle_label)
	_add_label_shadow(_detail_label)
	_add_label_shadow(_state_label)
	_add_label_shadow(_icon_label)
	_add_label_shadow(_cost_label)
	if not _pending_config.is_empty():
		_apply_config(_pending_config)
	else:
		_apply_style()


func configure(config: Dictionary) -> void:
	_pending_config = config.duplicate(true)
	if is_node_ready():
		_apply_config(_pending_config)


func _apply_config(config: Dictionary) -> void:
	if config.has("audio_cue"):
		set_meta("audio_cue", config.get("audio_cue"))
	if config.has("min_width") or config.has("min_height"):
		set_custom_minimum_size(Vector2(float(config.get("min_width", custom_minimum_size.x)), float(config.get("min_height", custom_minimum_size.y))))
	_accent = config.get("accent", GameUiStyle.STROKE_SOFT) as Color
	_disabled = bool(config.get("disabled", false))
	_pressable_when_disabled = bool(config.get("pressable_when_disabled", false))
	_draggable = bool(config.get("draggable", false))
	_selected = bool(config.get("selected", false))
	tooltip_text = String(config.get("disabled_reason", ""))
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


func _apply_icon_texture(config: Dictionary) -> void:
	var cfg: Dictionary = config.get("source_cfg", {})
	var fallback_key := StringName(config.get("fallback_icon_key", ""))
	var texture := UiArtRegistry.get_icon_texture(cfg, fallback_key)
	_icon_texture.texture = texture
	_icon_texture.visible = texture != null
	_icon_label.visible = texture == null


func _apply_style() -> void:
	_card_base.add_theme_stylebox_override("panel", GameUiStyle.list_card(_selected or _hovered))
	_icon_frame.add_theme_stylebox_override("panel", GameUiStyle.build_icon_frame(_accent))
	_selected_overlay.visible = _selected or (_hovered and not _disabled)
	_disabled_overlay.visible = _disabled
	modulate.a = 1.0


func _add_label_shadow(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)


func _on_gui_input(event: InputEvent) -> void:
	if _disabled and not _pressable_when_disabled:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_pressing = true
			_drag_started = false
			_press_start_mouse = get_global_mouse_position()
			accept_event()
			if not _draggable:
				pressed.emit()
		elif _pressing:
			_pressing = false
			if _draggable and not _drag_started:
				pressed.emit()
			accept_event()
	elif event is InputEventMouseMotion and _pressing and _draggable and not _drag_started:
		if get_global_mouse_position().distance_to(_press_start_mouse) >= DRAG_START_THRESHOLD:
			_drag_started = true
			drag_started.emit()
			accept_event()
