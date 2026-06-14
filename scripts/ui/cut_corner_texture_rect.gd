class_name CutCornerTextureRect
extends Control


@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

@export var cut_size := 7.0:
	set(value):
		cut_size = max(value, 0.0)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var draw_size: Vector2 = size
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var cut: float = min(cut_size, min(draw_size.x, draw_size.y) * 0.5)
	var points := PackedVector2Array([
		Vector2(cut, 0.0),
		Vector2(draw_size.x - cut, 0.0),
		Vector2(draw_size.x, cut),
		Vector2(draw_size.x, draw_size.y - cut),
		Vector2(draw_size.x - cut, draw_size.y),
		Vector2(cut, draw_size.y),
		Vector2(0.0, draw_size.y - cut),
		Vector2(0.0, cut),
	])
	var source_rect: Rect2 = _covered_source_rect(texture_size, draw_size)
	var uvs := PackedVector2Array()
	for point in points:
		var source_point: Vector2 = source_rect.position + Vector2(
			point.x / draw_size.x * source_rect.size.x,
			point.y / draw_size.y * source_rect.size.y
		)
		uvs.append(Vector2(source_point.x / texture_size.x, source_point.y / texture_size.y))
	draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)


func _covered_source_rect(texture_size: Vector2, draw_size: Vector2) -> Rect2:
	var texture_ratio: float = texture_size.x / texture_size.y
	var draw_ratio: float = draw_size.x / draw_size.y
	var source_size: Vector2 = texture_size
	if texture_ratio > draw_ratio:
		source_size.x = texture_size.y * draw_ratio
	else:
		source_size.y = texture_size.x / draw_ratio
	var source_pos: Vector2 = (texture_size - source_size) * 0.5
	return Rect2(source_pos, source_size)
