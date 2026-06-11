extends Node2D

const AppTheme = preload("res://scripts/ui/app_theme.gd")


@export var spawn_key: StringName = &"S1"


func _ready() -> void:
	var label := get_node_or_null("%SpawnLabel") as Label
	if label != null:
		label.theme = AppTheme.get_theme()
		label.text = String(spawn_key)
		label.add_theme_stylebox_override("normal", _badge_style())


## 出怪口正式标记:裸白字垫暗底警示徽章,避免读作调试输出。
func _badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.020, 0.026, 0.80)
	style.border_color = Color(0.86, 0.23, 0.185, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style
