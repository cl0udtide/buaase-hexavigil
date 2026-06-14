class_name DialogPanel
extends Control

## 剧情演出引擎：阻断式逐句序列播放器，逐句可换皮（vn / bubble）。
## 暂停时照跑（PROCESS_MODE_ALWAYS）；点屏幕任意处 / 空格 / 回车推进；按住 Ctrl 快进；ESC 整段跳过。
## 由 StoryDirector 驱动（pause→play→resume）；也可被调试沙盒直接 play_story。

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiFrameSpec = preload("res://scripts/ui/ui_frame_spec.gd")
const StoryLib = preload("res://scripts/story/story_library.gd")

signal dialog_started
signal line_started(index: int)
signal line_finished(index: int)
signal dialog_finished

const SIDE_LEFT := &"left"
const SIDE_RIGHT := &"right"
const SKIN_VN := &"vn"
const SKIN_BUBBLE := &"bubble"
const DEFAULT_TYPE_SPEED := 38.0
const FF_TYPE_SPEED := 100000.0   # 快进时打字机近乎瞬显
const FF_LINE_SEC := 0.05         # 快进时每句停留秒数
const BUBBLE_DEFAULT_POS := Vector2(670.0, 96.0)   # 顶部居中漂浮（1920 宽近似）

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
var _current_gated := false      # 当前句是否"等事件"门控（点击不推进）
var _gate_key := StringName()
var _ff_timer := 0.0
var _fade_tween: Tween

@onready var _background: ColorRect = %Background
@onready var _left_portrait: TextureRect = %LeftPortrait
@onready var _right_portrait: TextureRect = %RightPortrait
@onready var _text_box: PanelContainer = %TextBox
@onready var _speaker_plate: PanelContainer = %SpeakerPlate
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: RichTextLabel = %TextLabel
@onready var _prompt_label: Label = %PromptLabel

# 程序化构建（不改 .tscn）：全屏插图层 + 气泡皮
var _bg_image: TextureRect
var _bubble: PanelContainer
var _bubble_avatar: TextureRect
var _bubble_speaker: Label
var _bubble_label: RichTextLabel
var _bubble_prompt: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_bg_image()
	_build_bubble()
	_configure_layout_nodes()
	_apply_style()
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
	_current_gated = false
	_advance_unchecked()


func skip() -> void:
	if not visible:
		return
	if _typing:
		_finish_typing()
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
	_gate_key = StringName(advance_mode.substr(6)) if _current_gated else StringName()

	var text := String(line.get("text", ""))
	if _active_text_label != null:
		_active_text_label.text = text
		_active_text_label.visible_characters = 0
	_line_char_count = _count_visible_characters(text)
	_visible_chars_float = 0.0
	_line_finished_emitted = false
	_typing = _line_char_count > 0 and _type_speed > 0.0
	if _active_prompt != null:
		_active_prompt.text = "点击继续"
	line_started.emit(_current_index)
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
	if _active_text_label != null:
		_active_text_label.visible_characters = -1
	_visible_chars_float = float(_line_char_count)
	if _active_prompt != null:
		_active_prompt.text = "再次点击进入下一句"
	if not _line_finished_emitted:
		_line_finished_emitted = true
		line_finished.emit(_current_index)


func _finish_dialog() -> void:
	_typing = false
	_current_gated = false
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


# ---- 程序化构建 ----
func _build_bg_image() -> void:
	_bg_image = TextureRect.new()
	_bg_image.name = "BackgroundImage"
	_bg_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_image.visible = false
	add_child(_bg_image)
	move_child(_bg_image, 2)   # Background(0)/BackdropGrid(1) 之后、立绘之前


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.name = "Bubble"
	_bubble.custom_minimum_size = Vector2(580.0, 0.0)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	add_child(_bubble)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)
	_bubble_avatar = TextureRect.new()
	_bubble_avatar.custom_minimum_size = Vector2(88.0, 88.0)
	_bubble_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bubble_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bubble_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bubble_avatar.clip_contents = true
	_bubble_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_avatar.visible = false
	hbox.add_child(_bubble_avatar)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)
	_bubble_speaker = Label.new()
	_bubble_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_speaker.visible = false
	vbox.add_child(_bubble_speaker)
	_bubble_label = RichTextLabel.new()
	_bubble_label.bbcode_enabled = true
	_bubble_label.fit_content = true
	_bubble_label.scroll_active = false
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(420.0, 0.0)
	_bubble_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_bubble_label)
	_bubble_prompt = Label.new()
	_bubble_prompt.text = "点击继续"
	_bubble_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bubble_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_bubble_prompt)


func _configure_layout_nodes() -> void:
	for portrait in [_left_portrait, _right_portrait]:
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 立绘缩小（sprite 仅 128px，避免高倍放大糊）并下移，使下半身压在对话框之下。
	_set_portrait_rect(_left_portrait, 0.17, 0.36)
	_set_portrait_rect(_right_portrait, 0.59, 0.78)
	# 对话框几何：保持宽（盖住立绘下半身），压低高度去掉空白，下沿贴近屏底。
	_text_box.offset_left = 150.0
	_text_box.offset_right = -150.0
	_text_box.offset_top = -188.0
	_text_box.offset_bottom = -34.0
	var text_margin := _text_box.get_node_or_null("TextMargin") as MarginContainer
	if text_margin != null:
		text_margin.add_theme_constant_override("margin_left", 40)
		text_margin.add_theme_constant_override("margin_right", 40)
		text_margin.add_theme_constant_override("margin_top", 18)
		text_margin.add_theme_constant_override("margin_bottom", 16)
		var vbox := text_margin.get_node_or_null("VBoxContainer") as VBoxContainer
		if vbox != null:
			vbox.add_theme_constant_override("separation", 10)
	_text_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_text_box.gui_input.connect(_on_text_box_gui_input)
	_set_descendant_mouse_filter(_text_box, Control.MOUSE_FILTER_IGNORE)
	_text_label.bbcode_enabled = true
	_text_label.scroll_active = false
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_active_text_label = _text_label
	_active_prompt = _prompt_label


## 立绘矩形：横向 [a_left,a_right] 锚点，纵向固定（上 0.60→下 1.0，下半身越过对话框顶进框后）。
func _set_portrait_rect(portrait: TextureRect, a_left: float, a_right: float) -> void:
	portrait.anchor_left = a_left
	portrait.anchor_right = a_right
	portrait.anchor_top = 0.45
	portrait.anchor_bottom = 1.0
	portrait.offset_left = 0.0
	portrait.offset_top = 0.0
	portrait.offset_right = 0.0
	portrait.offset_bottom = 0.0


func _set_descendant_mouse_filter(root: Node, filter: Control.MouseFilter) -> void:
	for child in root.get_children():
		if child is Control:
			(child as Control).mouse_filter = filter
		_set_descendant_mouse_filter(child, filter)


func _apply_style() -> void:
	# 对话框 / 名牌 / 气泡全部复用游戏现成 UI 框，与 HUD 风格一致：
	#   对话框=事件弹窗框，名牌=干员标题条，气泡=地图弹窗框。
	_text_box.add_theme_stylebox_override("panel", GameUiStyle.frame_box(UiFrameSpec.RIGHT_DETAIL_SIDEBAR, GameUiStyle.BG_GLASS, GameUiStyle.STROKE_SOFT, false))

	_speaker_plate.add_theme_stylebox_override("panel", GameUiStyle.frame_box(UiFrameSpec.OPERATOR_TITLE_STRIP, GameUiStyle.BG_CARD, GameUiStyle.ACCENT))
	_speaker_plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_speaker_plate.custom_minimum_size = Vector2.ZERO
	_speaker_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_speaker_label.add_theme_font_size_override("font_size", 18)
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_speaker_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_speaker_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_speaker_label.custom_minimum_size = Vector2.ZERO

	_text_label.add_theme_color_override("default_color", GameUiStyle.TEXT)
	_text_label.add_theme_font_size_override("normal_font_size", 24)
	_text_label.add_theme_constant_override("line_separation", 6)
	_prompt_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_prompt_label.add_theme_font_size_override("font_size", 14)

	_bubble.add_theme_stylebox_override("panel", GameUiStyle.frame_box(UiFrameSpec.MAP_POPUP, GameUiStyle.BG_GLASS, GameUiStyle.STROKE_SOFT))
	_bubble_speaker.add_theme_color_override("font_color", GameUiStyle.ACCENT)
	_bubble_speaker.add_theme_font_size_override("font_size", 16)
	_bubble_label.add_theme_color_override("default_color", GameUiStyle.TEXT)
	_bubble_label.add_theme_font_size_override("normal_font_size", 20)
	_bubble_prompt.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_bubble_prompt.add_theme_font_size_override("font_size", 13)
