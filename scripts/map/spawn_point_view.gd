extends Node2D

const AppTheme = preload("res://scripts/ui/app_theme.gd")


@export var spawn_key: StringName = &"S1"


func _ready() -> void:
	var label := get_node_or_null("%SpawnLabel") as Label
	if label != null:
		label.theme = AppTheme.get_theme()
		label.text = String(spawn_key)
