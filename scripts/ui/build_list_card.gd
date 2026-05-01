class_name BuildListCard
extends PanelContainer

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")

signal pressed

var _pending_config: Dictionary = {}
var _accent := GameUiStyle.STROKE_SOFT
var _disabled := false
var _selected := false
var _hovered := false

@onready var _accent_bar: ColorRect = %AccentBar
@onready var _icon_panel: PanelContainer = %IconPanel
@onready var _icon_texture: TextureRect = %IconTexture
@onready var _icon_label: Label = %IconLabel
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _state_label: Label = %StateLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	if _accent_bar != null:
		_accent_bar.visible = false
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
	_icon_label.add_theme_color_override("font_color", Color(0.50, 0.60, 0.64, 0.96))
	_add_label_shadow(_title_label)
	_add_label_shadow(_subtitle_label)
	_add_label_shadow(_detail_label)
	_add_label_shadow(_state_label)
	_add_label_shadow(_icon_label)
	_icon_panel.add_theme_stylebox_override("panel", GameUiStyle.panel(Color(0.035, 0.046, 0.055, 0.98), GameUiStyle.STROKE_SOFT, 1.0, 4.0))
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
	_selected = bool(config.get("selected", false))
	_title_label.text = String(config.get("title", ""))
	_subtitle_label.text = String(config.get("subtitle", ""))
	_detail_label.text = String(config.get("detail", ""))
	_state_label.text = String(config.get("state", ""))
	_icon_label.text = String(config.get("icon_text", "*"))
	_apply_icon_texture(config)
	_subtitle_label.visible = not _subtitle_label.text.is_empty()
	_detail_label.visible = not _detail_label.text.is_empty()
	_state_label.visible = not _state_label.text.is_empty()
	_state_label.add_theme_color_override("font_color", config.get("state_color", GameUiStyle.AMBER) as Color)
	_title_label.add_theme_color_override("font_color", GameUiStyle.TEXT if _disabled else config.get("title_color", GameUiStyle.TEXT) as Color)
	_icon_label.add_theme_color_override("font_color", config.get("icon_color", Color(0.50, 0.60, 0.64, 0.96)) as Color)
	_apply_style()


func _apply_icon_texture(config: Dictionary) -> void:
	var texture: Texture2D = null
	var raw_texture: Variant = config.get("icon_texture", null)
	if raw_texture is Texture2D:
		texture = raw_texture
	elif config.has("source_cfg"):
		texture = UiArtRegistry.get_icon_texture(config.get("source_cfg", {}) as Dictionary)
	_icon_texture.texture = texture
	_icon_texture.visible = texture != null
	_icon_label.visible = texture == null


func _apply_style() -> void:
	var border := _accent
	var fill := GameUiStyle.BG_CARD
	var width := 1.0
	if _disabled:
		border = GameUiStyle.STROKE_SOFT
		fill = GameUiStyle.BG_DISABLED
	elif _selected:
		border = GameUiStyle.AMBER
		fill = Color(0.175, 0.128, 0.050, 0.98)
		width = 1.5
	elif _hovered:
		border = GameUiStyle.ACCENT
		fill = GameUiStyle.BG_CARD_HOVER
		width = 1.5
	add_theme_stylebox_override("panel", GameUiStyle.card(border, fill, width))
	if _accent_bar != null:
		_accent_bar.visible = false
	modulate.a = 0.86 if _disabled else 1.0


func _add_label_shadow(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


func _on_gui_input(event: InputEvent) -> void:
	if _disabled or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		pressed.emit()
		accept_event()

