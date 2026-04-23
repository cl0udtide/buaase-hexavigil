extends Node2D


func refresh_from_map(map_manager: Node) -> void:
	var info_label := get_node_or_null("%InfoLabel") as Label
	if info_label != null:
		info_label.text = "Map %dx%d  Core=%s" % [map_manager.width, map_manager.height, map_manager.get_core_cell()]
