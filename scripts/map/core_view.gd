extends Node2D

const AppTheme = preload("res://scripts/ui/app_theme.gd")


@export var label_text := "Core"


func _ready() -> void:
	var label := get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.theme = AppTheme.get_theme()
		label.text = label_text
