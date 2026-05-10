extends Node2D

@export var sprite_root := "res://assets/sprites/units"
@export var visual_key := "skadi"
@export var frame_prefix := "skadi"
@export var action := "idle"
@export_range(1.0, 30.0, 0.5) var fps := 8.0
@export_range(1.0, 8.0, 0.25) var display_scale := 4.0

const ACTIONS := ["idle", "attack", "skill", "deploy", "death"]
const PRESETS := [
	{
		"name": "eunectes",
		"visual_key": "eunectes",
		"frame_prefix": "eunectes",
		"action": "idle"
	},
	{
		"name": "eunectes_attack",
		"visual_key": "eunectes",
		"frame_prefix": "eunectes",
		"action": "attack"
	},
	{
		"name": "ceobe",
		"visual_key": "ceobe",
		"frame_prefix": "ceobe",
		"action": "idle"
	},
	{
		"name": "ceobe_attack",
		"visual_key": "ceobe",
		"frame_prefix": "ceobe",
		"action": "attack"
	},
	{
		"name": "pozyomka",
		"visual_key": "pozyomka",
		"frame_prefix": "pozyomka",
		"action": "idle"
	},
	{
		"name": "pozyomka_attack",
		"visual_key": "pozyomka",
		"frame_prefix": "pozyomka",
		"action": "attack"
	},
	{
		"name": "skadi",
		"visual_key": "skadi",
		"frame_prefix": "skadi",
		"action": "idle"
	},
	{
		"name": "skadi_attack",
		"visual_key": "skadi",
		"frame_prefix": "skadi",
		"action": "attack"
	},
	{
		"name": "sniper_t2",
		"visual_key": "sniper_t2",
		"frame_prefix": "sniper_t2",
		"action": "idle"
	},
	{
		"name": "sniper_t2_clean",
		"visual_key": "sniper_t2_clean",
		"frame_prefix": "sniper_t2",
		"action": "idle"
	}
]

@onready var _sprite: AnimatedSprite2D = %Sprite
@onready var _info_label: Label = %InfoLabel
@onready var _hint_label: Label = %HintLabel
@onready var _camera: Camera2D = %Camera2D

var _action_index := 0
var _preset_index := 0
var _frame_count := 0


func _ready() -> void:
	_camera.enabled = true
	_camera.make_current()
	_preset_index = _find_current_preset_index()
	_action_index = max(ACTIONS.find(action), 0)
	_sprite.scale = Vector2.ONE * display_scale
	_sprite.centered = true
	_sprite.z_index = 10
	_hint_label.text = "Left / Right: unit   [ / ]: action   Space: reload   - / =: FPS"
	_reload_animation()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_SPACE:
			_reload_animation()
		KEY_LEFT:
			_switch_preset(-1)
		KEY_RIGHT:
			_switch_preset(1)
		KEY_BRACKETLEFT:
			_action_index = wrapi(_action_index - 1, 0, ACTIONS.size())
			action = ACTIONS[_action_index]
			_reload_animation()
		KEY_BRACKETRIGHT:
			_action_index = wrapi(_action_index + 1, 0, ACTIONS.size())
			action = ACTIONS[_action_index]
			_reload_animation()
		KEY_MINUS:
			fps = max(fps - 1.0, 1.0)
			_apply_speed()
		KEY_EQUAL:
			fps = min(fps + 1.0, 30.0)
			_apply_speed()


func _find_current_preset_index() -> int:
	for index in range(PRESETS.size()):
		var preset: Dictionary = PRESETS[index]
		if (
			String(preset.get("visual_key", "")) == visual_key
			and String(preset.get("frame_prefix", "")) == frame_prefix
			and String(preset.get("action", "")) == action
		):
			return index
	return 0


func _switch_preset(direction: int) -> void:
	_preset_index = wrapi(_preset_index + direction, 0, PRESETS.size())
	var preset: Dictionary = PRESETS[_preset_index]
	visual_key = String(preset.get("visual_key", visual_key))
	frame_prefix = String(preset.get("frame_prefix", frame_prefix))
	action = String(preset.get("action", action))
	_action_index = max(ACTIONS.find(action), 0)
	_reload_animation()


func _reload_animation() -> void:
	var textures := _load_sequence_textures()
	_frame_count = textures.size()
	if textures.is_empty():
		_sprite.sprite_frames = SpriteFrames.new()
		_update_info("missing frames")
		return

	var frames := SpriteFrames.new()
	frames.add_animation(action)
	frames.set_animation_loop(action, true)
	frames.set_animation_speed(action, fps)
	for texture in textures:
		frames.add_frame(action, texture)
	_sprite.sprite_frames = frames
	_sprite.animation = action
	_sprite.frame = 0
	_sprite.play(action)
	_update_info("playing")


func _load_sequence_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var folder_path := "%s/%s/%s" % [sprite_root, visual_key, action]
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return textures

	var exact_prefix := "%s_%s_" % [frame_prefix, action]
	var loose_action_token := "_%s_" % action
	var file_names: Array[String] = []
	var all_png_file_names: Array[String] = []
	for file_name in dir.get_files():
		if file_name.ends_with(".import"):
			continue
		if not file_name.ends_with(".png"):
			continue
		all_png_file_names.append(file_name)
		if file_name.begins_with(exact_prefix):
			file_names.append(file_name)

	if file_names.is_empty():
		for file_name in all_png_file_names:
			if file_name.find(loose_action_token) >= 0:
				file_names.append(file_name)

	if file_names.is_empty():
		file_names = all_png_file_names

	file_names.sort()
	for file_name in file_names:
		var path := "%s/%s" % [folder_path, file_name]
		var texture := load(path) as Texture2D
		if texture != null:
			textures.append(texture)
	return textures


func _apply_speed() -> void:
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(action):
		_sprite.sprite_frames.set_animation_speed(action, fps)
	_update_info("playing")


func _update_info(status: String) -> void:
	var pattern := "%s/%s/%s/%s_%s_%%03d.png" % [
		sprite_root,
		visual_key,
		action,
		frame_prefix,
		action
	]
	var preset_name := String(PRESETS[_preset_index].get("name", frame_prefix)) if _preset_index >= 0 and _preset_index < PRESETS.size() else frame_prefix
	_info_label.text = "%s: %s\n%s\nframes: %d   fps: %.1f   scale: %.1f" % [
		status,
		preset_name,
		pattern,
		_frame_count,
		fps,
		display_scale
	]
