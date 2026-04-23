extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")


func _ready() -> void:
	AppTheme.apply(self)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.phase_changed.connect(_on_phase_changed)
		event_bus.deploy_limit_changed.connect(_on_deploy_limit_changed)


func refresh_owned_units(unit_ids: Array[StringName]) -> void:
	var label := get_node_or_null("%OwnedUnitsLabel") as Label
	if label != null:
		label.text = "已拥有: %s" % ", ".join(PackedStringArray(unit_ids))


func refresh_redeploy_state(unit_id: StringName, ready: bool, remain_sec: float) -> void:
	var label := get_node_or_null("%RedeployLabel") as Label
	if label != null:
		label.text = "%s: %s %.1fs" % [unit_id, "可部署" if ready else "冷却", remain_sec]


func set_visible_for_phase(phase: int) -> void:
	visible = phase == GameEnums.PHASE_DAY


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	set_visible_for_phase(new_phase)


func _on_deploy_limit_changed(_current: int, _max_value: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state != null:
		refresh_owned_units(run_state.owned_units)
