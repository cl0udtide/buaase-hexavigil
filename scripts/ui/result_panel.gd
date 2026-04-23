extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")


func set_result(win: bool) -> void:
	AppTheme.apply(self)
	var title := get_node_or_null("%ResultLabel") as Label
	if title != null:
		title.text = "胜利" if win else "失败"
