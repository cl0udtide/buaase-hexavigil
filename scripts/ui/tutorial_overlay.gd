extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

signal next_requested
signal skip_requested

const POSITION_TOP_RIGHT := &"top_right"
const POSITION_TOP_CENTER := &"top_center"

var _dragging := false
var _drag_offset := Vector2.ZERO
var _user_moved := false

@onready var _panel: PanelContainer = %Panel
@onready var _step_label: Label = %StepLabel
@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _hint_label: Label = %HintLabel
@onready var _next_button: Button = %NextButton
@onready var _skip_button: Button = %SkipButton


func _ready() -> void:
	AppTheme.apply(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_clamp_panel_to_view)
	_panel.add_theme_stylebox_override("panel", GameUiStyle.event_panel())
	_panel.gui_input.connect(_on_panel_gui_input)
	_next_button.add_theme_stylebox_override("normal", GameUiStyle.button(GameUiStyle.ACCENT))
	_next_button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.AMBER))
	_next_button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER))
	_skip_button.add_theme_stylebox_override("normal", GameUiStyle.secondary_button())
	_skip_button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.STROKE_STRONG))
	_skip_button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.STROKE_STRONG))
	_step_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_title_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_body_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_hint_label.add_theme_color_override("font_color", GameUiStyle.ACCENT)
	_next_button.pressed.connect(func() -> void: next_requested.emit())
	_skip_button.pressed.connect(func() -> void: skip_requested.emit())
	hide_tutorial()


func show_step(step_index: int, total_steps: int, title: String, body: String, hint: String, wait_for_action: bool) -> void:
	visible = true
	_step_label.text = "教程 %d/%d" % [step_index, total_steps]
	_title_label.text = title
	_body_label.text = body
	_hint_label.text = hint
	_next_button.visible = true
	_next_button.disabled = false


func set_panel_position(position_id: StringName, force := false) -> void:
	if _user_moved and not force:
		return
	var panel_size := _panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = Vector2(430.0, 254.0)
	var margin := Vector2(22.0, 118.0)
	var target := Vector2(size.x - panel_size.x - margin.x, margin.y)
	match position_id:
		POSITION_TOP_CENTER:
			target = Vector2(maxf((size.x - panel_size.x) * 0.5, 22.0), margin.y)
		_:
			target = Vector2(size.x - panel_size.x - margin.x, margin.y)
	_set_panel_top_left(target)


func hide_tutorial() -> void:
	visible = false


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_dragging = true
			_drag_offset = get_global_mouse_position() - _panel.position
			_panel.accept_event()
		else:
			_dragging = false
			_panel.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_user_moved = true
		_set_panel_top_left(get_global_mouse_position() - _drag_offset)
		_panel.accept_event()


func _set_panel_top_left(top_left: Vector2) -> void:
	var panel_size := _panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = Vector2(430.0, 254.0)
	var clamped := Vector2(
		clampf(top_left.x, 8.0, maxf(8.0, size.x - panel_size.x - 8.0)),
		clampf(top_left.y, 8.0, maxf(8.0, size.y - panel_size.y - 8.0))
	)
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = clamped.x
	_panel.offset_top = clamped.y
	_panel.offset_right = clamped.x + panel_size.x
	_panel.offset_bottom = clamped.y + panel_size.y


func _clamp_panel_to_view() -> void:
	if _panel == null:
		return
	_set_panel_top_left(_panel.position)
