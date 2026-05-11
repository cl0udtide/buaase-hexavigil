extends Node2D


signal hit(projectile: Node, target: Node, payload: Dictionary)
signal expired(projectile: Node, reason: StringName, payload: Dictionary)

@export var speed := 520.0
@export var hit_radius := 8.0
@export var max_lifetime := 3.0
@export var body_length := 18.0
@export var body_width := 3.0
@export var body_color := Color(1.0, 0.78, 0.28, 0.95)
@export var texture_path := ""
@export var visual_length := 42.0
@export var visual_height := 18.0

var direction := Vector2.RIGHT
var source: Node
var target: Variant = null
var payload: Dictionary = {}

var _age := 0.0
var _resolved := false
var _sprite: Sprite2D = null


func setup(new_payload: Dictionary) -> void:
	payload = new_payload.duplicate()
	source = payload.get("source", null) as Node
	target = payload.get("target", null)
	var origin_variant: Variant = payload.get("origin", global_position)
	if origin_variant is Vector2:
		global_position = origin_variant
	speed = max(float(payload.get("speed", speed)), 1.0)
	hit_radius = max(float(payload.get("hit_radius", hit_radius)), 1.0)
	max_lifetime = max(float(payload.get("max_lifetime", max_lifetime)), 0.05)
	var damage_type_value := int(payload.get("damage_type", -1))
	var color_variant: Variant = payload.get("color", _default_color_for_damage_type(damage_type_value))
	if color_variant is Color:
		body_color = color_variant
	texture_path = String(payload.get("texture_path", payload.get("projectile_texture_path", texture_path)))
	if texture_path.is_empty():
		texture_path = _default_texture_path_for_damage_type(damage_type_value)
	var default_visual_size := _default_visual_size_for_damage_type(damage_type_value)
	visual_length = max(float(payload.get("visual_length", payload.get("projectile_visual_length", default_visual_size.x))), 1.0)
	visual_height = max(float(payload.get("visual_height", payload.get("projectile_visual_height", default_visual_size.y))), 1.0)
	_setup_visual()
	_update_direction_to_target()
	queue_redraw()


func _process(delta: float) -> void:
	if _resolved:
		return
	_age += delta
	if _age >= max_lifetime:
		_expire(&"timeout")
		return
	if not _is_valid_target(target):
		_expire(&"target_lost")
		return
	var target_position := _get_target_position(target)
	var to_target := target_position - global_position
	var distance := to_target.length()
	if distance <= hit_radius:
		_hit()
		return
	if distance > 0.001:
		direction = to_target / distance
		rotation = direction.angle()
	var travel := speed * delta
	if travel + hit_radius >= distance:
		global_position = target_position
		_hit()
		return
	global_position += direction * travel


func _draw() -> void:
	if _sprite != null and _sprite.texture != null:
		return
	draw_line(Vector2(-body_length * 0.5, 0.0), Vector2(body_length * 0.5, 0.0), body_color, body_width, true)
	draw_circle(Vector2(body_length * 0.5, 0.0), body_width * 1.4, body_color)


func _hit() -> void:
	if _resolved:
		return
	_resolved = true
	hit.emit(self, target as Node, payload)
	queue_free()


func _expire(reason: StringName) -> void:
	if _resolved:
		return
	_resolved = true
	expired.emit(self, reason, payload)
	queue_free()


func _update_direction_to_target() -> void:
	if not _is_valid_target(target):
		return
	var to_target := _get_target_position(target) - global_position
	if to_target.length_squared() <= 0.001:
		return
	direction = to_target.normalized()
	rotation = direction.angle()


func _is_valid_target(candidate: Variant) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if not candidate is Node2D:
		return false
	var node := candidate as Node
	var hp_value: Variant = node.get("current_hp")
	if hp_value != null and int(hp_value) <= 0:
		return false
	return true


func _get_target_position(candidate: Variant) -> Vector2:
	if candidate is Node2D:
		return (candidate as Node2D).global_position
	return global_position


func _setup_visual() -> void:
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	_sprite.texture = texture
	_sprite.centered = true
	_sprite.modulate = body_color
	var texture_size := Vector2(float(texture.get_width()), float(texture.get_height()))
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	_sprite.scale = Vector2(visual_length / texture_size.x, visual_height / texture_size.y)


func _default_texture_path_for_damage_type(damage_type: int) -> String:
	match damage_type:
		GameEnums.DAMAGE_MAGIC:
			return "res://assets/effects/projectiles/projectile_arts_orb.png"
		GameEnums.DAMAGE_TRUE:
			return "res://assets/effects/projectiles/projectile_heavy_shot.png"
		_:
			return "res://assets/effects/projectiles/projectile_arrow.png"


func _default_visual_size_for_damage_type(damage_type: int) -> Vector2:
	match damage_type:
		GameEnums.DAMAGE_MAGIC:
			return Vector2(46.0, 22.0)
		GameEnums.DAMAGE_TRUE:
			return Vector2(50.0, 24.0)
		_:
			return Vector2(42.0, 14.0)


func _default_color_for_damage_type(damage_type: int) -> Color:
	match damage_type:
		GameEnums.DAMAGE_MAGIC:
			return Color(0.7, 0.88, 1.0, 0.96)
		GameEnums.DAMAGE_TRUE:
			return Color(1.0, 1.0, 1.0, 0.96)
		_:
			return Color(1.0, 0.9, 0.55, 0.95)
