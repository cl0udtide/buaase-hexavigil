extends Control

const GameplaySettings = preload("res://scripts/core/gameplay_settings.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

signal close_requested
signal cheat_panel_requested

@export var audio_manager_path: NodePath

const PANEL_WIDTH := 420.0
const PANEL_HEIGHT := 326.0

@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _master_value_label: Label = %MasterValueLabel
@onready var _music_value_label: Label = %MusicValueLabel
@onready var _sfx_value_label: Label = %SfxValueLabel
@onready var _close_button: Button = get_node_or_null("%CloseButton") as Button
@onready var _auto_skill_button: Button = get_node_or_null("%AutoSkillButton") as Button
@onready var _main_vbox: VBoxContainer = get_node_or_null("ContentMargin/MainVBox") as VBoxContainer

var _audio_manager: Node
var _updating := false
var _cheat_open_button: Button


func _ready() -> void:
	visible = false
	_audio_manager = _resolve_audio_manager()
	if _close_button != null:
		_close_button.pressed.connect(func() -> void: close_requested.emit())
	_bind_sliders()
	_bind_auto_skill_toggle()
	_build_cheat_entry()
	refresh_from_audio_manager()
	refresh_from_gameplay_settings()
	_apply_panel_size()


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
	_apply_panel_size()


func hide_panel() -> void:
	visible = false


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func _bind_sliders() -> void:
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)


func _bind_auto_skill_toggle() -> void:
	if _auto_skill_button == null:
		return
	_auto_skill_button.toggled.connect(_on_auto_skill_toggled)


func _build_cheat_entry() -> void:
	if _main_vbox == null or _cheat_open_button != null:
		return
	_cheat_open_button = Button.new()
	_cheat_open_button.name = "CheatOpenButton"
	_cheat_open_button.custom_minimum_size = Vector2(0.0, 34.0)
	_cheat_open_button.focus_mode = Control.FOCUS_NONE
	_cheat_open_button.text = "打开作弊面板"
	_cheat_open_button.tooltip_text = "打开本局调试用作弊工具"
	_cheat_open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cheat_open_button.add_theme_font_size_override("font_size", 13)
	_cheat_open_button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_cheat_open_button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	_cheat_open_button.add_theme_color_override("font_pressed_color", GameUiStyle.TEXT_INVERTED)
	_cheat_open_button.add_theme_stylebox_override("normal", GameUiStyle.compact_button(false))
	_cheat_open_button.add_theme_stylebox_override("hover", GameUiStyle.compact_button(true))
	_cheat_open_button.add_theme_stylebox_override("pressed", GameUiStyle.compact_button(true))
	_cheat_open_button.pressed.connect(func() -> void: cheat_panel_requested.emit())
	_main_vbox.add_child(_cheat_open_button)


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
	_auto_skill_button.text = "开启" if _auto_skill_button.button_pressed else "关闭"
	_auto_skill_button.tooltip_text = "开启后，普通手动技能会在攻击范围内有目标时自动释放"


func _apply_panel_size() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	var parent_control := get_parent() as Control
	if parent_control != null:
		parent_control.offset_right = parent_control.offset_left + PANEL_WIDTH
		parent_control.offset_bottom = parent_control.offset_top + PANEL_HEIGHT


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
