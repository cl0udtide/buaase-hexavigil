extends Node2D

const AppTheme = preload("res://scripts/ui/app_theme.gd")

const ACTIVE_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const SILENT_MODULATE := Color(0.6, 0.6, 0.65, 0.55)


@export var spawn_key: StringName = &"S1"


func _ready() -> void:
	var label := get_node_or_null("%SpawnLabel") as Label
	if label != null:
		label.theme = AppTheme.get_theme()
		label.text = String(spawn_key)


## 活跃/沉默两态 + 当晚变化角标（封/开）。标记常显（穿透迷雾）由 map_manager 保证。
func set_gate_state(active: bool, badge: String = "") -> void:
	modulate = ACTIVE_MODULATE if active else SILENT_MODULATE
	var label := get_node_or_null("%SpawnLabel") as Label
	if label == null:
		return
	var base := String(spawn_key)
	label.text = base if badge.is_empty() else "%s·%s" % [base, badge]
