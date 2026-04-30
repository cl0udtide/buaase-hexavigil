extends Node2D


signal hit(projectile: Node, target: Node, payload: Dictionary)
signal expired(projectile: Node, reason: StringName, payload: Dictionary)

@export var speed := 520.0
@export var hit_radius := 8.0
@export var max_lifetime := 3.0
@export var body_length := 18.0
@export var body_width := 3.0
@export var body_color := Color(1.0, 0.78, 0.28, 0.95)

var direction := Vector2.RIGHT
var source: Node
var target: Variant = null
var payload: Dictionary = {}

var _age := 0.0
var _resolved := false


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
	var color_variant: Variant = payload.get("color", body_color)
	if color_variant is Color:
		body_color = color_variant
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
