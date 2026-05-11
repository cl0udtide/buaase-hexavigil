extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

var _win := false


func set_result(win: bool) -> void:
	_win = win
	AppTheme.apply(self)
	var title := get_node_or_null("%ResultLabel") as Label
	if title != null:
		title.text = "胜利" if win else "失败"
		title.add_theme_color_override("font_color", GameUiStyle.SUCCESS if win else GameUiStyle.DANGER)
	var summary := get_node_or_null("%ResultSummaryLabel") as Label
	if summary != null:
		summary.text = "核心仍在发光，守夜防线挺过了这一轮。" if win else "核心防线被突破，敌群已占领阵地。"
		summary.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)


func _ready() -> void:
	AppTheme.apply(self)
	set_result(_win)
