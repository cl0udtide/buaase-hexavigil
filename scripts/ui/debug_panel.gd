extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")

@onready var _map_root: Node = get_node_or_null("../../World/MapRoot")


func _ready() -> void:
	AppTheme.apply(self)
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
		day_label.text = "Current Day: %d  Phase: %s" % [run_state.day, _get_phase_text(run_state.phase)]
	var map_label := get_node_or_null("%MapDebugLabel") as Label
	if map_label != null:
		map_label.text = _map_root.get_debug_info() if _map_root != null and _map_root.has_method("get_debug_info") else "Map debug unavailable"
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
		GameEnums.PHASE_MENU: "Menu",
		GameEnums.PHASE_DAY: "Day",
		GameEnums.PHASE_NIGHT: "Night",
		GameEnums.PHASE_BLESSING: "Blessing",
		GameEnums.PHASE_RESULT: "Result"
	}
	return String(phase_map.get(phase, "Unknown"))
