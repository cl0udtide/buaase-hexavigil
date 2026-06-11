class_name DialogPanel
extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

signal dialog_started
signal line_started(index: int)
signal line_finished(index: int)
signal dialog_finished

const SIDE_LEFT := &"left"
const SIDE_RIGHT := &"right"
const SIDE_NARRATOR := &"narrator"
const DEFAULT_TYPE_SPEED := 38.0

var _script_data: Dictionary = {}
var _lines: Array = []
var _backgrounds: Dictionary = {}
var _current_index := -1
var _type_speed := DEFAULT_TYPE_SPEED
var _typing := false
var _visible_chars_float := 0.0
var _line_char_count := 0
var _line_finished_emitted := false
var _active_side := StringName()
var _fade_tween: Tween

@onready var _background: ColorRect = %Background
@onready var _backdrop_texture: TextureRect = %BackdropTexture
@onready var _left_portrait: TextureRect = %LeftPortrait
@onready var _right_portrait: TextureRect = %RightPortrait
@onready var _text_box: PanelContainer = %TextBox
@onready var _speaker_plate: PanelContainer = %SpeakerPlate
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: RichTextLabel = %TextLabel
@onready var _prompt_label: Label = %PromptLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	_configure_layout_nodes()
	_apply_style()
	_clear_side(SIDE_LEFT)
	_clear_side(SIDE_RIGHT)
	visible = false


func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	_visible_chars_float += _type_speed * delta
	var next_count := mini(int(_visible_chars_float), _line_char_count)
	_text_label.visible_characters = next_count
	if next_count >= _line_char_count:
		_finish_typing()


func _gui_input(event: InputEvent) -> void:
	_handle_advance_pointer_input(event)


func _on_text_box_gui_input(event: InputEvent) -> void:
	_handle_advance_pointer_input(event)


func _handle_advance_pointer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			accept_event()
			advance()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			advance()
		elif key_event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			skip()


func play_script(script_data: Dictionary) -> void:
	_script_data = script_data.duplicate(true)
	_lines = _script_data.get("lines", [])
	_backgrounds = _script_data.get("backgrounds", {})
	var settings: Dictionary = _script_data.get("settings", {})
	_type_speed = max(float(settings.get("type_speed", DEFAULT_TYPE_SPEED)), 0.0)
	_current_index = -1
	_typing = false
	_line_finished_emitted = false
	_active_side = StringName()
	_clear_side(SIDE_LEFT)
	_clear_side(SIDE_RIGHT)
	_apply_background(StringName(_script_data.get("default_background", "")))
	visible = true
	modulate.a = 0.0
	_start_panel_fade(1.0)
	dialog_started.emit()
	advance()


func advance() -> void:
	if not visible:
		return
	if _typing:
		_finish_typing()
		return
	_current_index += 1
	if _current_index >= _lines.size():
		_finish_dialog()
		return
	var line: Dictionary = _lines[_current_index]
	_show_line(line)


func skip() -> void:
	if not visible:
		return
	if _typing:
		_finish_typing()
	_finish_dialog()


func restart() -> void:
	if _script_data.is_empty():
		return
	play_script(_script_data)


func set_type_speed(value: float) -> void:
	_type_speed = max(value, 0.0)


func _show_line(line: Dictionary) -> void:
	_apply_clear_sides(line.get("clear_sides", []))
	var background_key := StringName(line.get("background_key", ""))
	if background_key != StringName():
		_apply_background(background_key)

	var side := StringName(line.get("side", ""))
	var portrait_key := StringName(line.get("portrait_key", ""))
	if _is_portrait_side(side) and portrait_key != StringName():
		_set_portrait(side, portrait_key)

	_active_side = side if _is_portrait_side(side) else StringName()
	_update_portrait_focus()

	var speaker := String(line.get("speaker", "")).strip_edges()
	_speaker_plate.visible = not speaker.is_empty()
	_speaker_label.text = speaker

	var text := String(line.get("text", ""))
	_text_label.text = text
	_line_char_count = _count_visible_characters(text)
	_text_label.visible_characters = 0
	_visible_chars_float = 0.0
	_line_finished_emitted = false
	_typing = _line_char_count > 0 and _type_speed > 0.0
	_prompt_label.text = "▼ 点击继续"
	line_started.emit(_current_index)
	if not _typing:
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text_label.visible_characters = -1
	_visible_chars_float = float(_line_char_count)
	_prompt_label.text = "▼ 再次点击进入下一句"
	if not _line_finished_emitted:
		_line_finished_emitted = true
		line_finished.emit(_current_index)


func _finish_dialog() -> void:
	_typing = false
	dialog_finished.emit()
	_start_panel_fade(0.0, Callable(self, "_hide_after_fade"))


func _hide_after_fade() -> void:
	visible = false
	modulate.a = 1.0


func _apply_clear_sides(raw_clear_sides: Variant) -> void:
	if typeof(raw_clear_sides) == TYPE_STRING:
		raw_clear_sides = [raw_clear_sides]
	if typeof(raw_clear_sides) != TYPE_ARRAY:
		return
	for raw_side in raw_clear_sides:
		var side := StringName(raw_side)
		if side == &"all":
			_clear_side(SIDE_LEFT)
			_clear_side(SIDE_RIGHT)
		elif _is_portrait_side(side):
			_clear_side(side)


func _set_portrait(side: StringName, portrait_key: StringName) -> void:
	var target := _get_portrait_rect(side)
	if target == null:
		return
	var texture := _get_portrait_texture(portrait_key)
	if texture == null:
		_clear_side(side)
		return
	var changed := StringName(target.get_meta("portrait_key", "")) != portrait_key
	target.texture = texture
	target.visible = true
	target.set_meta("portrait_key", portrait_key)
	if changed:
		target.scale = Vector2(1.03, 1.03)
		target.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(target, "scale", Vector2.ONE, 0.22)
		tween.tween_property(target, "modulate:a", 1.0, 0.22)


func _clear_side(side: StringName) -> void:
	var target := _get_portrait_rect(side)
	if target == null:
		return
	target.visible = false
	target.texture = null
	target.remove_meta("portrait_key")


func _update_portrait_focus() -> void:
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		var target := _get_portrait_rect(side)
		if target == null or not target.visible:
			continue
		var focus_color := Color(1.0, 1.0, 1.0, 1.0)
		if _active_side != StringName() and side != _active_side:
			focus_color = Color(0.48, 0.55, 0.62, 0.72)
		var tween := create_tween()
		tween.tween_property(target, "modulate", focus_color, 0.16)


func _apply_background(background_key: StringName) -> void:
	var fallback := Color(0.040, 0.052, 0.064, 1.0)
	if background_key == StringName():
		_background.color = fallback
		return
	var raw_background: Variant = _backgrounds.get(String(background_key), _backgrounds.get(background_key, {}))
	if typeof(raw_background) == TYPE_DICTIONARY:
		var cfg: Dictionary = raw_background
		_background.color = _parse_color(String(cfg.get("color", "")), fallback)
		_apply_backdrop_texture(String(cfg.get("texture", "")))
	elif typeof(raw_background) == TYPE_STRING:
		_background.color = _parse_color(String(raw_background), fallback)
	else:
		_background.color = fallback


func _apply_backdrop_texture(texture_path: String) -> void:
	# 加载失败时保留场景默认底图,不留纯黑空墙
	if _backdrop_texture == null or texture_path.is_empty():
		return
	if not ResourceLoader.exists(texture_path, "Texture2D"):
		return
	var texture := load(texture_path) as Texture2D
	if texture != null:
		_backdrop_texture.texture = texture


func _get_portrait_texture(_portrait_key: StringName) -> Texture2D:
	return null


func _get_portrait_rect(side: StringName) -> TextureRect:
	if side == SIDE_LEFT:
		return _left_portrait
	if side == SIDE_RIGHT:
		return _right_portrait
	return null


func _is_portrait_side(side: StringName) -> bool:
	return side == SIDE_LEFT or side == SIDE_RIGHT


func _count_visible_characters(bbcode_text: String) -> int:
	var count := 0
	var in_tag := false
	for i in range(bbcode_text.length()):
		var character := bbcode_text[i]
		if character == "[":
			in_tag = true
			continue
		if character == "]" and in_tag:
			in_tag = false
			continue
		if not in_tag:
			count += 1
	return count


func _parse_color(raw_color: String, fallback: Color) -> Color:
	if raw_color.is_empty():
		return fallback
	if raw_color.begins_with("#"):
		return Color.html(raw_color)
	return fallback


func _start_panel_fade(target_alpha: float, callback: Callable = Callable()) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", target_alpha, 0.18)
	if callback.is_valid():
		_fade_tween.tween_callback(callback)


func _configure_layout_nodes() -> void:
	for portrait in [_left_portrait, _right_portrait]:
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_text_box.gui_input.connect(_on_text_box_gui_input)
	_set_descendant_mouse_filter(_text_box, Control.MOUSE_FILTER_IGNORE)
	_text_label.bbcode_enabled = true
	_text_label.scroll_active = false
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _set_descendant_mouse_filter(root: Node, filter: int) -> void:
	for child in root.get_children():
		if child is Control:
			(child as Control).mouse_filter = filter
		_set_descendant_mouse_filter(child, filter)


func _apply_style() -> void:
	_speaker_label.add_theme_color_override("font_color", GameUiStyle.TEXT_ON_PARCHMENT)
	_speaker_label.add_theme_font_size_override("font_size", 22)
	GameUiStyle.center_label_text(_speaker_label)
	_text_label.add_theme_color_override("default_color", GameUiStyle.TEXT_INVERTED)
	_text_label.add_theme_font_size_override("normal_font_size", 23)
	# 续行提示降为 caption 级,不与正文抢权重
	_prompt_label.add_theme_color_override("font_color", Color(0.62, 0.71, 0.76, 0.5))
	_prompt_label.add_theme_font_size_override("font_size", 13)
