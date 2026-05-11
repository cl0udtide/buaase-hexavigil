extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

var _win := false


func set_result(win: bool) -> void:
	_win = win
	AppTheme.apply(self)
	_apply_visual_style()
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
	_apply_visual_style()
	set_result(_win)


func _apply_visual_style() -> void:
	var card := get_node_or_null("%ResultCard") as PanelContainer
	if card != null:
		card.add_theme_stylebox_override("panel", GameUiStyle.result_panel())
		GameUiStyle.apply_frame_margin(card.get_node_or_null("ContentMargin") as MarginContainer, GameUiStyle.FRAME_RESULT_PANEL)

	var title := get_node_or_null("%ResultLabel") as Label
	if title != null:
		title.add_theme_font_size_override("font_size", 40)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var summary := get_node_or_null("%ResultSummaryLabel") as Label
	if summary != null:
		summary.add_theme_font_size_override("font_size", 17)
		summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
