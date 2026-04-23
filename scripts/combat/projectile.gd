extends Node2D


@export var speed := 240.0
var direction := Vector2.RIGHT


func _process(delta: float) -> void:
	global_position += direction * speed * delta
