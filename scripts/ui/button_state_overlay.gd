extends Node

@export var active_overlay_name: StringName = &"PrimaryOverlay"
@export var disabled_overlay_name: StringName = &"DisabledOverlay"

var _button: Button
var _hovered := false
var _pressed := false


func _ready() -> void:
	_button = get_parent() as Button
	if _button == null:
		push_warning("ButtonStateOverlay must be a child of Button.")
		return
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)
	_button.visibility_changed.connect(_sync)
	set_process(true)
	_sync()


func _on_mouse_entered() -> void:
	_hovered = true
	_sync()


func _on_mouse_exited() -> void:
	_hovered = false
	_pressed = false
	_sync()


func _on_button_down() -> void:
	_pressed = true
	_sync()


func _on_button_up() -> void:
	_pressed = false
	_sync()


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	if _button == null:
		return
	var active_overlay := _button.get_node_or_null(NodePath(String(active_overlay_name))) as CanvasItem
	var disabled_overlay := _button.get_node_or_null(NodePath(String(disabled_overlay_name))) as CanvasItem
	var active := _button.visible and not _button.disabled and (_hovered or _pressed)
	if active_overlay != null:
		active_overlay.visible = active
	if disabled_overlay != null:
		disabled_overlay.visible = _button.visible and _button.disabled
