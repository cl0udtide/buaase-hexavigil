extends Node2D


@export var spawn_key: StringName = &"S1"


func _ready() -> void:
	var label := get_node_or_null("%SpawnLabel") as Label
	if label != null:
		label.text = String(spawn_key)
