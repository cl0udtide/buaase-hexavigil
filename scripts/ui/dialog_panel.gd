class_name DialogPanel
extends Control

## 剧情演出引擎：阻断式逐句序列播放器，逐句可换皮（vn / bubble）。
## 暂停时照跑（PROCESS_MODE_ALWAYS）；点屏幕任意处 / 空格 / 回车推进；按住 Ctrl 快进；ESC 整段跳过。
## 由 StoryDirector 驱动（pause→play→resume）；也可被调试沙盒直接 play_story。

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const StoryLib = preload("res://scripts/story/story_library.gd")

signal dialog_started
signal line_started(index: int)
signal line_finished(index: int)
signal dialog_finished
signal dialog_skipped

const SIDE_LEFT := &"left"
const SIDE_RIGHT := &"right"
const SKIN_VN := &"vn"
const SKIN_BUBBLE := &"bubble"
const DEFAULT_TYPE_SPEED := 38.0
const FF_TYPE_SPEED := 100000.0   # 快进时打字机近乎瞬显
const FF_LINE_SEC := 0.05         # 快进时每句停留秒数
const BUBBLE_DEFAULT_POS := Vector2(670.0, 96.0)   # 顶部居中漂浮（1920 宽近似）
const DIALOG_BLIP_PATH := "res://assets/audio/sfx/dialog_blip_neutral.ogg"
const DIALOG_BLIP_MIN_SECONDS := 0.18
const DIALOG_BLIP_MAX_SECONDS := 8.0

var _lines: Array = []
var _settings: Dictionary = {}
var _current_index := -1
var _type_speed := DEFAULT_TYPE_SPEED
var _typing := false
var _visible_chars_float := 0.0
var _line_char_count := 0
var _line_finished_emitted := false
var _active_side := StringName()
var _active_skin := SKIN_VN
var _active_text_label: RichTextLabel
var _active_prompt: Label
var _current_finished_prompt := ""
var _current_gated := false      # 当前句是否"等事件"门控（点击不推进）
var _gate_release_pending := false
var _gate_key := StringName()
var _ff_timer := 0.0
var _fade_tween: Tween
var _dialog_blip_stop_token := 0

@onready var _background: ColorRect = %Background
@onready var _left_portrait: TextureRect = %LeftPortrait
@onready var _right_portrait: TextureRect = %RightPortrait
@onready var _text_box: PanelContainer = %TextBox
@onready var _speaker_plate: PanelContainer = %SpeakerPlate
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: RichTextLabel = %TextLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _bg_image: TextureRect = %BackgroundImage
@onready var _bubble: PanelContainer = %Bubble
@onready var _bubble_avatar: TextureRect = %BubbleAvatar
@onready var _bubble_speaker: Label = %BubbleSpeaker
@onready var _bubble_label: RichTextLabel = %BubbleLabel
@onready var _bubble_prompt: Label = %BubblePrompt
@onready var _dialog_blip_player: AudioStreamPlayer = %DialogBlipPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_dialog_blip_player()
	_configure_layout_nodes()
	_clear_side(SIDE_LEFT)
	_clear_side(SIDE_RIGHT)
	visible = false
	# 主题仅装饰，放最后；即便某些无头/早期环境下出问题也不影响引擎构建。
	AppTheme.apply(self)


func _process(delta: float) -> void:
	if not visible:
		return
	var fast := Input.is_key_pressed(KEY_CTRL)
	if _typing:
		var speed := FF_TYPE_SPEED if fast else _type_speed
		_visible_chars_float += speed * delta
		var next_count := mini(int(_visible_chars_float), _line_char_count)
		if _active_text_label != null:
			_active_text_label.visible_characters = next_count
		if next_count >= _line_char_count:
			_finish_typing()
		return
	if fast and not _current_gated:
		_ff_timer += delta
		if _ff_timer >= FF_LINE_SEC:
			_ff_timer = 0.0
			_advance_unchecked()
	else:
		_ff_timer = 0.0


# ---- 输入 ----
func _gui_input(event: InputEvent) -> void:
	_handle_advance_pointer_input(event)


func _on_text_box_gui_input(event: InputEvent) -> void:
	_handle_advance_pointer_input(event)


func _on_bubble_gui_input(event: InputEvent) -> void:
	_handle_advance_pointer_input(event)


func _handle_advance_pointer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			accept_event()
			advance()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			advance()
		elif ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			skip()


# ---- 播放控制 ----
func play_story(story: Dictionary) -> void:
	_settings = story.get("settings", {})
	_lines = story.get("lines", [])
	_type_speed = maxf(float(_settings.get("type_speed", DEFAULT_TYPE_SPEED)), 0.0)
	_current_index = -1
	_typing = false
	_ff_timer = 0.0
	_current_gated = false
	_gate_release_pending = false
	_current_finished_prompt = ""
	_line_finished_emitted = false
	_active_side = StringName()
	_clear_side(SIDE_LEFT)
	_clear_side(SIDE_RIGHT)
	_bubble.visible = false
	_apply_background("")
	visible = true
	modulate.a = 0.0
	_start_panel_fade(1.0)
	dialog_started.emit()
	advance()


## 兼容旧调用名（调试沙盒）。
func play_script(story: Dictionary) -> void:
	play_story(story)


func advance() -> void:
	if not visible:
		return
	if _typing:
		_finish_typing()
		return
	if _current_gated:
		return
	_advance_unchecked()


func _advance_unchecked() -> void:
	_current_index += 1
	if _current_index >= _lines.size():
		_finish_dialog()
		return
	var line: Variant = _lines[_current_index]
	if typeof(line) == TYPE_DICTIONARY:
		_show_line(line)
	else:
		_advance_unchecked()


## 动手门控：游戏事件发生时由 StoryDirector 调用以推进当前门控句。
func notify_story_event(event_key: StringName) -> void:
	if not _current_gated:
		return
	if _gate_key != StringName() and _gate_key != event_key:
		return
	if _typing:
		_current_gated = false
		_gate_release_pending = true
		return
	_current_gated = false
	_advance_unchecked()


func skip() -> void:
	if not visible:
		return
	if _typing:
		_finish_typing()
	dialog_skipped.emit()
	_finish_dialog()


func is_playing() -> bool:
	return visible


func set_type_speed(value: float) -> void:
	_type_speed = maxf(value, 0.0)


# ---- 单句呈现 ----
func _show_line(line: Dictionary) -> void:
	_apply_clear(line.get("clear", ""))
	_apply_background(String(line.get("background", "")))

	var skin := StringName(line.get("skin", SKIN_VN))
	_active_skin = skin
	if skin == SKIN_BUBBLE:
		_setup_bubble_line(line)
	else:
		_setup_vn_line(line)

	var advance_mode := String(line.get("advance", "click"))
	_current_gated = advance_mode.begins_with("event:")
	_gate_release_pending = false
	_gate_key = StringName(advance_mode.substr(6)) if _current_gated else StringName()
	_current_finished_prompt = String(line.get("finished_prompt", ""))

	var text := String(line.get("text", ""))
	if _active_text_label != null:
		_active_text_label.text = text
		_active_text_label.visible_characters = 0
	_line_char_count = _count_visible_characters(text)
	_visible_chars_float = 0.0
	_line_finished_emitted = false
	_typing = _line_char_count > 0 and _type_speed > 0.0
	if _active_prompt != null:
		_active_prompt.text = String(line.get("prompt", "点击继续"))
	line_started.emit(_current_index)
	_play_dialog_blip_for_current_line()
	if not _typing:
		_finish_typing()


func _setup_vn_line(line: Dictionary) -> void:
	_bubble.visible = false
	_text_box.visible = true
	var side := StringName(line.get("side", ""))
	var portrait_key := StringName(line.get("portrait", ""))
	if _is_portrait_side(side) and portrait_key != StringName():
		_set_portrait(side, portrait_key)
	_active_side = side if _is_portrait_side(side) else StringName()
	_update_portrait_focus()
	var speaker := String(line.get("speaker", "")).strip_edges()
	_speaker_plate.visible = not speaker.is_empty()
	_speaker_label.text = speaker
	_active_text_label = _text_label
	_active_prompt = _prompt_label


func _setup_bubble_line(line: Dictionary) -> void:
	_text_box.visible = false
	_clear_side(SIDE_LEFT)
	_clear_side(SIDE_RIGHT)
	_bubble.visible = true
	_place_bubble(line)
	var avatar := _make_head_avatar(StringName(line.get("portrait", "")))
	_bubble_avatar.texture = avatar
	_bubble_avatar.visible = avatar != null
	var speaker := String(line.get("speaker", "")).strip_edges()
	_bubble_speaker.visible = not speaker.is_empty()
	_bubble_speaker.text = speaker
	_active_text_label = _bubble_label
	_active_prompt = _bubble_prompt


## 气泡定位：显式 position 优先；anchor(core/ui:/cell:/unit:) 的世界换算留待 StoryDirector
## 注入屏幕坐标，暂未注入时落默认位。
func _place_bubble(line: Dictionary) -> void:
	var pos := BUBBLE_DEFAULT_POS
	if line.has("position"):
		var raw: Variant = line.get("position")
		if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
			pos = Vector2(float(raw[0]), float(raw[1]))
		elif typeof(raw) == TYPE_DICTIONARY:
			var d: Dictionary = raw
			pos = Vector2(float(d.get("x", pos.x)), float(d.get("y", pos.y)))
	_bubble.position = pos


# ---- 打字机收尾 ----
func _finish_typing() -> void:
	_typing = false
	_stop_dialog_blip()
	if _active_text_label != null:
		_active_text_label.visible_characters = -1
	_visible_chars_float = float(_line_char_count)
	if _active_prompt != null:
		if not _current_finished_prompt.is_empty():
			_active_prompt.text = _current_finished_prompt
		elif _current_gated:
			_active_prompt.text = "完成当前操作后继续"
		else:
			_active_prompt.text = "再次点击进入下一句"
	if not _line_finished_emitted:
		_line_finished_emitted = true
		line_finished.emit(_current_index)
	if _gate_release_pending:
		_gate_release_pending = false
		call_deferred("_advance_unchecked")


func _finish_dialog() -> void:
	_typing = false
	_current_gated = false
	_stop_dialog_blip()
	dialog_finished.emit()
	_start_panel_fade(0.0, Callable(self, "_hide_after_fade"))


func _hide_after_fade() -> void:
	visible = false
	modulate.a = 1.0


# ---- 立绘 ----
func _apply_clear(raw_clear: Variant) -> void:
	if typeof(raw_clear) == TYPE_STRING:
		raw_clear = [raw_clear]
	if typeof(raw_clear) != TYPE_ARRAY:
		return
	for raw_side in raw_clear:
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
	if target.has_meta("portrait_key"):
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


func _get_portrait_texture(portrait_key: StringName) -> Texture2D:
	var path := StoryLib.resolve_portrait_path(portrait_key)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## 气泡头像：从说话角色 sprite 顶部居中裁出一块正方头部区域。
## 用正方裁区 + 正方头像框（COVERED 同比例 → 不会再切掉脑袋两侧）；比例后续可微调。
func _make_head_avatar(portrait_key: StringName) -> Texture2D:
	var tex := _get_portrait_texture(portrait_key)
	if tex == null:
		return null
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	if w <= 0.0 or h <= 0.0:
		return null
	var side := minf(w, h) * 0.66
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2((w - side) * 0.5, h * 0.03, side, side)
	return atlas


func _get_portrait_rect(side: StringName) -> TextureRect:
	if side == SIDE_LEFT:
		return _left_portrait
	if side == SIDE_RIGHT:
		return _right_portrait
	return null


func _is_portrait_side(side: StringName) -> bool:
	return side == SIDE_LEFT or side == SIDE_RIGHT


# ---- 背景三档：透明(map)/纯色(#hex)/插图(key) ----
func _apply_background(bg: String) -> void:
	var fallback := Color(0.040, 0.052, 0.064, 1.0)
	if bg.is_empty() or bg == "map":
		_bg_image.visible = false
		_background.color = Color(fallback.r, fallback.g, fallback.b, 0.0)
		return
	if bg.begins_with("#"):
		_bg_image.visible = false
		_background.color = _parse_color(bg, fallback)
		return
	var path := StoryLib.resolve_background_path(bg)
	if not path.is_empty() and ResourceLoader.exists(path):
		_bg_image.texture = load(path) as Texture2D
		_bg_image.visible = true
		_background.color = Color(0.0, 0.0, 0.0, 1.0)
	else:
		_bg_image.visible = false
		_background.color = fallback


func _parse_color(raw: String, fallback: Color) -> Color:
	if raw.is_empty():
		return fallback
	if raw.begins_with("#"):
		return Color.html(raw)
	return fallback


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


func _start_panel_fade(target_alpha: float, callback: Callable = Callable()) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", target_alpha, 0.18)
	if callback.is_valid():
		_fade_tween.tween_callback(callback)


func _setup_dialog_blip_player() -> void:
	_dialog_blip_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if _dialog_blip_player.stream == null and ResourceLoader.exists(DIALOG_BLIP_PATH):
		_dialog_blip_player.stream = load(DIALOG_BLIP_PATH) as AudioStream


func _play_dialog_blip_for_current_line() -> void:
	if _dialog_blip_player == null or _dialog_blip_player.stream == null:
		return
	if _line_char_count <= 0:
		_stop_dialog_blip()
		return
	var duration := _dialog_blip_duration_for_chars(_line_char_count, _type_speed)
	_dialog_blip_stop_token += 1
	var token := _dialog_blip_stop_token
	_dialog_blip_player.stop()
	_dialog_blip_player.play(0.0)
	_stop_dialog_blip_after(duration, token)


func _stop_dialog_blip_after(duration: float, token: int) -> void:
	if duration > 0.0 and get_tree() != null:
		await get_tree().create_timer(duration, true).timeout
	if token == _dialog_blip_stop_token:
		_stop_dialog_blip()


func _stop_dialog_blip() -> void:
	_dialog_blip_stop_token += 1
	if _dialog_blip_player != null:
		_dialog_blip_player.stop()


func _dialog_blip_duration_for_chars(char_count: int, type_speed: float) -> float:
	if char_count <= 0 or type_speed <= 0.0:
		return 0.0
	return clampf(float(char_count) / type_speed, DIALOG_BLIP_MIN_SECONDS, DIALOG_BLIP_MAX_SECONDS)


func _configure_layout_nodes() -> void:
	for portrait in [_left_portrait, _right_portrait]:
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_text_box.gui_input.connect(_on_text_box_gui_input)
	_set_descendant_mouse_filter(_text_box, Control.MOUSE_FILTER_IGNORE)
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.gui_input.connect(_on_bubble_gui_input)
	_set_descendant_mouse_filter(_bubble, Control.MOUSE_FILTER_IGNORE)
	_active_text_label = _text_label
	_active_prompt = _prompt_label


func _set_descendant_mouse_filter(root: Node, filter: Control.MouseFilter) -> void:
	for child in root.get_children():
		if child is Control:
			(child as Control).mouse_filter = filter
		_set_descendant_mouse_filter(child, filter)
