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
@onready var _panel_shadow: Panel = %PanelShadow
@onready var _step_label: Label = %StepLabel
@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _hint_label: RichTextLabel = %HintLabel
@onready var _next_button: Button = %NextButton
@onready var _skip_button: Button = %SkipButton


func _ready() -> void:
	AppTheme.apply(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_clamp_panel_to_view)
	_panel.add_theme_stylebox_override("panel", GameUiStyle.event_panel())
	_panel.gui_input.connect(_on_panel_gui_input)
	var shadow_style := GameUiStyle.flat_panel(GameUiStyle.BG_DARK, Color.TRANSPARENT)
	# 弹窗浮在明亮地图上,默认浅色投影读不出抬升,局部加深
	shadow_style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	shadow_style.shadow_offset = Vector2(0.0, 4.0)
	_panel_shadow.add_theme_stylebox_override("panel", shadow_style)
	_panel.item_rect_changed.connect(_sync_panel_shadow)
	var next_states := GameUiStyle.popup_action_button(&"primary")
	for state in next_states:
		_next_button.add_theme_stylebox_override(state, next_states[state])
	_next_button.add_theme_color_override("font_hover_color", GameUiStyle.ACCENT)
	var skip_states := GameUiStyle.popup_action_button(&"secondary")
	for state in skip_states:
		_skip_button.add_theme_stylebox_override(state, skip_states[state])
	_step_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_title_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_body_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_hint_label.add_theme_color_override("default_color", GameUiStyle.TEXT_DIM)
	_next_button.pressed.connect(func() -> void: next_requested.emit())
	_skip_button.pressed.connect(func() -> void: skip_requested.emit())
	hide_tutorial()


func show_step(step_index: int, total_steps: int, title: String, body: String, hint: String, wait_for_action: bool) -> void:
	visible = true
	_step_label.text = "教程 %d/%d" % [step_index, total_steps]
	_title_label.text = title
	_body_label.text = body
	_hint_label.text = _decorate_hint(hint)
	_next_button.visible = true
	_next_button.disabled = false
	_next_button.text = "完成" if step_index >= total_steps else "下一步"


func set_panel_position(position_id: StringName, force := false) -> void:
	if _user_moved and not force:
		return
	_apply_panel_position(position_id)
	# fit_content 的 RichTextLabel 在文本写入同帧给出的最小高不可靠,布局后再校一次
	_apply_panel_position.call_deferred(position_id)


func _apply_panel_position(position_id: StringName) -> void:
	var panel_size := _sane_panel_size()
	var margin := Vector2(22.0, 118.0)
	var target := Vector2(size.x - panel_size.x - margin.x, margin.y)
	match position_id:
		POSITION_TOP_CENTER:
			target = Vector2(maxf((size.x - panel_size.x) * 0.5, 22.0), margin.y)
		_:
			target = Vector2(size.x - panel_size.x - margin.x, margin.y)
	_set_panel_top_left(target)


func _sane_panel_size() -> Vector2:
	var panel_size := _panel.get_combined_minimum_size()
	# 布局未稳定时 fit_content 会报出 0 或整屏级的病态最小高,回退既定尺寸
	if panel_size.x <= 0.0 or panel_size.y <= 0.0 \
			or panel_size.y > size.y * 0.6 or panel_size.x > size.x * 0.5:
		panel_size = Vector2(430.0, 254.0)
	return panel_size


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
	var panel_size := _sane_panel_size()
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


func _sync_panel_shadow() -> void:
	if _panel_shadow == null or _panel == null:
		return
	_panel_shadow.position = _panel.position + Vector2(4.0, 4.0)
	_panel_shadow.size = _panel.size - Vector2(8.0, 8.0)


static func _decorate_hint(hint: String) -> String:
	var decorated := hint
	for keyword in ["下一步", "跳过", "完成"]:
		decorated = decorated.replace(keyword, "[color=#%s]%s[/color]" % [GameUiStyle.ACCENT.to_html(false), keyword])
	return decorated
