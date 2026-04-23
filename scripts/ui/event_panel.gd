extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")


func _ready() -> void:
	AppTheme.apply(self)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.random_event_triggered.connect(_on_random_event_triggered)
	var close_button := get_node_or_null("%CloseButton") as BaseButton
	if close_button != null:
		close_button.pressed.connect(hide_event)


func show_event(event_cfg: Dictionary) -> void:
	visible = true
	var title := get_node_or_null("%TitleLabel") as Label
	var desc := get_node_or_null("%DescLabel") as Label
	if title != null:
		title.text = String(event_cfg.get("name", "未知事件"))
	if desc != null:
		desc.text = String(event_cfg.get("desc", ""))


func hide_event() -> void:
	visible = false


func _on_random_event_triggered(event_id: StringName, _cell: Vector2i) -> void:
	var data_repo = AppRefs.data_repo()
	if data_repo != null:
		show_event(data_repo.get_event_cfg(event_id))
