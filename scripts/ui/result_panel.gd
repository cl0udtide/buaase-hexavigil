extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")


func set_result(win: bool) -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	var title := get_node_or_null("%ResultLabel") as Label
	if title != null:
		title.text = "胜利" if win else "失败"
		title.add_theme_color_override("font_color", GameUiStyle.SUCCESS if win else GameUiStyle.DANGER)


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()


func _apply_visual_style() -> void:
	var card := get_node_or_null("%ResultCard") as PanelContainer
	if card != null:
		card.add_theme_stylebox_override("panel", GameUiStyle.panel(GameUiStyle.BG_DARK, GameUiStyle.STROKE_STRONG, 1.0, 6.0))
