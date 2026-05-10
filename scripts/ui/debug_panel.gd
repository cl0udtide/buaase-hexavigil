extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

@onready var _map_root: Node = get_node_or_null("../../World/MapRoot")


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	var apply_button := get_node_or_null("%ApplyDayButton") as BaseButton
	var line_edit := get_node_or_null("%DayInput") as LineEdit
	if apply_button != null:
		apply_button.pressed.connect(_on_apply_day_pressed)
	if line_edit != null:
		line_edit.text_submitted.connect(func(_text: String) -> void:
			_on_apply_day_pressed()
		)
	set_process(true)
	_refresh_debug_labels()


func _process(_delta: float) -> void:
	_refresh_debug_labels()


func _refresh_debug_labels() -> void:
	var run_state = AppRefs.run_state()
	var day_label := get_node_or_null("%CurrentDayLabel") as Label
	if day_label != null and run_state != null:
		day_label.text = "当前天数：%d  阶段：%s" % [run_state.day, _get_phase_text(run_state.phase)]
	var map_label := get_node_or_null("%MapDebugLabel") as Label
	if map_label != null:
		map_label.text = _map_root.get_debug_info() if _map_root != null and _map_root.has_method("get_debug_info") else "地图调试信息不可用"
	var apply_button := get_node_or_null("%ApplyDayButton") as BaseButton
	if apply_button != null and run_state != null:
		apply_button.disabled = run_state.phase == GameEnums.PHASE_NIGHT


func _on_apply_day_pressed() -> void:
	var line_edit := get_node_or_null("%DayInput") as LineEdit
	if line_edit == null:
		return
	var parsed := int(line_edit.text)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_debug_set_day.emit(clamp(parsed, 1, 6))


func _get_phase_text(phase: int) -> String:
	var phase_map := {
		GameEnums.PHASE_MENU: "菜单",
		GameEnums.PHASE_DAY: "白天",
		GameEnums.PHASE_NIGHT: "夜晚",
		GameEnums.PHASE_BLESSING: "祝福",
		GameEnums.PHASE_RESULT: "结算"
	}
	return String(phase_map.get(phase, "未知"))


func _apply_visual_style() -> void:
	add_theme_stylebox_override("panel", GameUiStyle.side_panel())
	GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin") as MarginContainer, GameUiStyle.FRAME_SIDE_PANEL)
	var title := get_node_or_null("ContentMargin/VBoxContainer/TitleLabel") as Label
	if title != null:
		title.text = "调试面板"
	for label in find_children("*", "Label", true, false):
		var label_node := label as Label
		label_node.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	var apply_button := get_node_or_null("%ApplyDayButton") as Button
	if apply_button != null:
		apply_button.text = "切换"
		GameUiStyle.center_button_text(apply_button)
		apply_button.add_theme_stylebox_override("normal", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.18))
		apply_button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT, 0.28))
		apply_button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.32))
		apply_button.add_theme_stylebox_override("disabled", GameUiStyle.disabled_button())
		apply_button.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
		apply_button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
