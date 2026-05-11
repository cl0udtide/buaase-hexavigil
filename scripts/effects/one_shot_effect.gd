extends Node2D


var _sprite: Sprite2D
var _frame_count := 1
var _fps := 18.0
var _duration := 0.1
var _elapsed := 0.0
var _loop_frames := false
var _follow_target: Node2D = null
var _follow_offset := Vector2.ZERO


func setup(payload: Dictionary) -> void:
	var texture_path := String(payload.get("texture_path", ""))
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		queue_free()
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		queue_free()
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	_sprite.texture = texture
	_sprite.centered = true
	_sprite.hframes = max(int(payload.get("hframes", 1)), 1)
	_sprite.vframes = max(int(payload.get("vframes", 1)), 1)
	_frame_count = clamp(int(payload.get("frame_count", _sprite.hframes * _sprite.vframes)), 1, _sprite.hframes * _sprite.vframes)
	_fps = max(float(payload.get("fps", 18.0)), 1.0)
	_duration = max(float(payload.get("duration", float(_frame_count) / _fps)), 0.01)
	_elapsed = 0.0
	_loop_frames = bool(payload.get("loop", false))
	_apply_position(payload)
	rotation = float(payload.get("rotation", rotation))
	z_index = int(payload.get("z_index", z_index))
	if payload.has("modulate"):
		_sprite.modulate = payload["modulate"]
	_apply_target_size(payload)
	_update_frame()


func _process(delta: float) -> void:
	_sync_follow_position()
	_elapsed += delta
	if _elapsed >= _duration:
		queue_free()
		return
	_update_frame()


func _update_frame() -> void:
	if _sprite == null:
		return
	var raw_frame_index := int(floor(_elapsed * _fps))
	var frame_index: int = raw_frame_index % _frame_count if _loop_frames else min(raw_frame_index, _frame_count - 1)
	_sprite.frame = frame_index


func _apply_target_size(payload: Dictionary) -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var frame_size := Vector2(
		float(_sprite.texture.get_width()) / float(_sprite.hframes),
		float(_sprite.texture.get_height()) / float(_sprite.vframes)
	)
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return
	if payload.has("size"):
		var size_variant: Variant = payload["size"]
		if size_variant is Vector2:
			var target_size: Vector2 = size_variant
			_sprite.scale = Vector2(
				target_size.x / frame_size.x,
				target_size.y / frame_size.y
			)
	elif payload.has("width"):
		var width: float = max(float(payload.get("width", frame_size.x)), 1.0)
		var scale: float = width / frame_size.x
		_sprite.scale = Vector2.ONE * scale


func _apply_position(payload: Dictionary) -> void:
	_follow_target = null
	_follow_offset = Vector2.ZERO
	var follow_target_variant: Variant = payload.get("follow_target", payload.get("attach_to", null))
	if follow_target_variant is Node2D and is_instance_valid(follow_target_variant):
		_follow_target = follow_target_variant
		var follow_offset_variant: Variant = payload.get("local_position", payload.get("follow_offset", Vector2.ZERO))
		if follow_offset_variant is Vector2:
			_follow_offset = follow_offset_variant
		_sync_follow_position()
		return
	var position_variant: Variant = payload.get("position", global_position)
	if position_variant is Vector2:
		global_position = position_variant


func _sync_follow_position() -> void:
	if _follow_target == null:
		return
	if not is_instance_valid(_follow_target):
		queue_free()
		return
	global_position = _follow_target.global_position + _follow_offset
