extends Control


func set_result(win: bool) -> void:
	var title := get_node_or_null("%ResultLabel") as Label
	if title != null:
		title.text = "胜利" if win else "失败"
