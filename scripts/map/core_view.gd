extends Node2D


@export var label_text := "Core"


func _ready() -> void:
	var label := get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.text = label_text
