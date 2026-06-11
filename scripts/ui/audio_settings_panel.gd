extends Control

const GameplaySettings = preload("res://scripts/core/gameplay_settings.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")

signal close_requested

@export var audio_manager_path: NodePath

@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _master_value_label: Label = %MasterValueLabel
@onready var _music_value_label: Label = %MusicValueLabel
@onready var _sfx_value_label: Label = %SfxValueLabel
@onready var _close_button: Button = get_node_or_null("%CloseButton") as Button
@onready var _auto_skill_button: Button = get_node_or_null("%AutoSkillButton") as Button

var _audio_manager: Node
var _updating := false


func _ready() -> void:
	visible = false
	_audio_manager = _resolve_audio_manager()
	if _close_button != null:
		_close_button.pressed.connect(func() -> void: close_requested.emit())
	_apply_row_styles()
	_apply_slider_handles()
	_tighten_row_columns()
	_style_close_button()
	_style_auto_skill_button()
	_bind_sliders()
	_bind_auto_skill_toggle()
	refresh_from_audio_manager()
	refresh_from_gameplay_settings()


func set_audio_manager(audio_manager: Node) -> void:
	_audio_manager = audio_manager
	refresh_from_audio_manager()


func refresh_from_audio_manager() -> void:
	if _audio_manager == null:
		_audio_manager = _resolve_audio_manager()
	if _audio_manager == null or not _audio_manager.has_method("get_volume_state"):
		return
	var state: Dictionary = _audio_manager.get_volume_state()
	_updating = true
	_master_slider.value = float(state.get("master", 0.85))
	_music_slider.value = float(state.get("music", 0.75))
	_sfx_slider.value = float(state.get("sfx", 0.85))
	_updating = false
	_refresh_value_labels()


func refresh_from_gameplay_settings() -> void:
	if _auto_skill_button == null:
		return
	_updating = true
	_auto_skill_button.button_pressed = GameplaySettings.is_auto_skill_cast_enabled()
	_updating = false
	_refresh_auto_skill_button()


func show_panel() -> void:
	visible = true
	refresh_from_audio_manager()
	refresh_from_gameplay_settings()


func hide_panel() -> void:
	visible = false


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


## 行框从面板同款八角厚金属框降级为 flat 内凹板;
## RowMargin 左距 29 是给旧厚框侧夹扣留的,随之收窄到 12。
func _apply_row_styles() -> void:
	var row_style := GameUiStyle.settings_row()
	for row_name in ["MasterRow", "MusicRow", "SfxRow", "AutoSkillRow"]:
		var row := get_node_or_null("%" + row_name)
		if row == null:
			continue
		var row_base := row.get_node_or_null("RowBase") as Panel
		if row_base != null:
			row_base.add_theme_stylebox_override("panel", row_style)
		var row_margin := row.get_node_or_null("RowMargin") as MarginContainer
		if row_margin != null:
			row_margin.add_theme_constant_override("margin_left", 12)


## 场景里 grabber 直接引用了原始素材（236x119），grabber 图标按纹理原生尺寸绘制；
## 这里统一换成 GameUiStyle 降采样后的手柄，避免拖柄盖住整行。
## 轨道贴图细节在 8px 高下糊死,凹槽与已填充段改走 flat 样式。
func _apply_slider_handles() -> void:
	var groove := GameUiStyle.flat_box(GameUiStyle.BG_DARK, Color(0, 0, 0, 0.7), 1.0, 4.0)
	var filled := GameUiStyle.flat_box(GameUiStyle.ACCENT_SOFT, GameUiStyle.ACCENT, 1.0, 4.0)
	for style: StyleBoxFlat in [groove, filled]:
		# HSlider 按样式盒最小高度画轨道,content 上下 4 撑出 8px 可见凹槽
		style.content_margin_left = 0.0
		style.content_margin_top = 4.0
		style.content_margin_right = 0.0
		style.content_margin_bottom = 4.0
	var handle := GameUiStyle.slider_handle()
	for slider in [_master_slider, _music_slider, _sfx_slider]:
		slider.add_theme_stylebox_override("slider", groove)
		slider.add_theme_stylebox_override("grabber_area", filled)
		slider.add_theme_stylebox_override("grabber_area_highlight", filled)
		if handle != null:
			slider.add_theme_icon_override("grabber", handle)
			slider.add_theme_icon_override("grabber_highlight", handle)
			slider.add_theme_icon_override("grabber_pressed", handle)


## 标签/数值列各收一档,把行内多余空带让给滑条行程。
func _tighten_row_columns() -> void:
	for label_path in [
		"%MasterRow/RowMargin/RowContent/MasterLabel",
		"%MusicRow/RowMargin/RowContent/MusicLabel",
		"%SfxRow/RowMargin/RowContent/SfxLabel",
	]:
		var label := get_node_or_null(label_path) as Label
		if label != null:
			label.custom_minimum_size = Vector2(56, 0)
	for value_label in [_master_value_label, _music_value_label, _sfx_value_label]:
		if value_label != null:
			value_label.custom_minimum_size = Vector2(40, 0)


## 关闭按钮:30x28 下九宫格角部缩成细线、暗红像素 X 不可辨;
## 换齿轮同款 socket 底座并放大提亮 X(modulate 翻倍,黑描边不受影响)。
func _style_close_button() -> void:
	if _close_button == null:
		return
	_close_button.custom_minimum_size = Vector2(36, 32)
	var socket := load("res://assets/ui/styles/frame_settings_button_base_fit_36x32.tres") as StyleBox
	if socket != null:
		_close_button.add_theme_stylebox_override("normal", socket)
	var fitted_icon := _close_button.get_node_or_null("FittedIcon") as TextureRect
	if fitted_icon != null:
		fitted_icon.offset_left = -10.0
		fitted_icon.offset_top = -10.0
		fitted_icon.offset_right = 10.0
		fitted_icon.offset_bottom = 10.0
		fitted_icon.self_modulate = Color(2.0, 1.8, 1.8, 1.0)


## toggle 开启时常驻 pressed 态;primary overlay 是状态叠层,
## 单独当底用呈无框玻璃片,pressed/hover 换回与 normal 同款金属底。
func _style_auto_skill_button() -> void:
	if _auto_skill_button == null:
		return
	_auto_skill_button.custom_minimum_size = Vector2(88, 30)
	var base := load("res://assets/ui/styles/frame_button_base_fit_30x28.tres") as StyleBox
	if base == null:
		return
	_auto_skill_button.add_theme_stylebox_override("pressed", base)
	_auto_skill_button.add_theme_stylebox_override("hover", base)


func _bind_sliders() -> void:
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)


func _bind_auto_skill_toggle() -> void:
	if _auto_skill_button == null:
		return
	_auto_skill_button.toggled.connect(_on_auto_skill_toggled)


func _on_master_changed(value: float) -> void:
	if _updating:
		return
	if _audio_manager != null and _audio_manager.has_method("set_master_volume"):
		_audio_manager.set_master_volume(value)
	_refresh_value_labels()


func _on_music_changed(value: float) -> void:
	if _updating:
		return
	if _audio_manager != null and _audio_manager.has_method("set_music_volume"):
		_audio_manager.set_music_volume(value)
	_refresh_value_labels()


func _on_sfx_changed(value: float) -> void:
	if _updating:
		return
	if _audio_manager != null and _audio_manager.has_method("set_sfx_volume"):
		_audio_manager.set_sfx_volume(value)
	_refresh_value_labels()


func _on_auto_skill_toggled(enabled: bool) -> void:
	if _updating:
		return
	GameplaySettings.set_auto_skill_cast_enabled(enabled)
	_refresh_auto_skill_button()


func _refresh_value_labels() -> void:
	_master_value_label.text = _format_percent(_master_slider.value)
	_music_value_label.text = _format_percent(_music_slider.value)
	_sfx_value_label.text = _format_percent(_sfx_slider.value)
	_refresh_volume_icons()


func _refresh_auto_skill_button() -> void:
	if _auto_skill_button == null:
		return
	var enabled := _auto_skill_button.button_pressed
	_auto_skill_button.text = "已开启" if enabled else "已关闭"
	var state_color := GameUiStyle.ACCENT if enabled else GameUiStyle.TEXT_MUTED
	_auto_skill_button.add_theme_color_override("font_color", state_color)
	_auto_skill_button.add_theme_color_override("font_pressed_color", state_color)
	_auto_skill_button.tooltip_text = "开启后，普通手动技能会在攻击范围内有目标时自动释放"


func _format_percent(value: float) -> String:
	return "%d%%" % int(round(value * 100.0))


func _resolve_audio_manager() -> Node:
	if String(audio_manager_path) != "":
		var explicit := get_node_or_null(audio_manager_path)
		if explicit != null:
			return explicit
	var current_scene := get_tree().current_scene if get_tree() != null else null
	if current_scene != null:
		var scene_audio := current_scene.get_node_or_null("Managers/AudioManager")
		if scene_audio != null:
			return scene_audio
	var cursor: Node = self
	while cursor != null:
		var candidate := cursor.get_node_or_null("Managers/AudioManager")
		if candidate != null:
			return candidate
		cursor = cursor.get_parent()
	return null


func _refresh_volume_icons() -> void:
	_apply_label_icon(get_node_or_null("%MasterRow/RowMargin/RowContent/VolumeIcon") as Label, &"volume_mute" if is_zero_approx(_master_slider.value) else &"volume_master")
	_apply_label_icon(get_node_or_null("%MusicRow/RowMargin/RowContent/VolumeIcon") as Label, &"volume_mute" if is_zero_approx(_music_slider.value) else &"volume_music")
	_apply_label_icon(get_node_or_null("%SfxRow/RowMargin/RowContent/VolumeIcon") as Label, &"volume_mute" if is_zero_approx(_sfx_slider.value) else &"volume_sfx")


func _apply_label_icon(label: Label, icon_id: StringName) -> void:
	if label == null:
		return
	var texture := UiArtRegistry.get_catalog_icon(icon_id)
	if texture == null:
		return
	label.text = ""
	var texture_rect := label.get_node_or_null("IconTexture") as TextureRect
	if texture_rect == null:
		return
	texture_rect.texture = texture
	texture_rect.visible = true
