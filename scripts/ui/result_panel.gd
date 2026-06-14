extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

var _win := false


func set_result(win: bool) -> void:
	_win = win
	_set_modal_layer_visible(true)
	_set_parent_slot_visible(true)
	visible = true
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
	visible = false
	_set_parent_slot_visible(false)
	_sync_modal_layer_visibility()
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.run_ended.connect(_on_run_ended)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_modal_layer_visibility()


func _on_run_ended(win: bool) -> void:
	set_result(win)


func _set_parent_slot_visible(value: bool) -> void:
	var slot := get_parent() as CanvasItem
	if slot != null:
		slot.visible = value


func _set_modal_layer_visible(value: bool) -> void:
	var layer := _get_modal_layer()
	if layer != null:
		layer.visible = value


func _sync_modal_layer_visibility() -> void:
	var layer := _get_modal_layer()
	if layer == null:
		return
	layer.visible = _modal_layer_has_visible_panel(layer)


func _get_modal_layer() -> CanvasItem:
	var slot := get_parent()
	if slot == null:
		return null
	return slot.get_parent() as CanvasItem


func _modal_layer_has_visible_panel(layer: Node) -> bool:
	for slot in layer.get_children():
		for child in slot.get_children():
			var canvas_item := child as CanvasItem
			if canvas_item != null and canvas_item.visible:
				return true
	return false
