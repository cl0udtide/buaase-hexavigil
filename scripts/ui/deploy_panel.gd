extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")


func _ready() -> void:
	AppTheme.apply(self)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.phase_changed.connect(_on_phase_changed)
		event_bus.deploy_limit_changed.connect(_on_deploy_limit_changed)
		event_bus.owned_units_changed.connect(refresh_owned_units)
	var run_state = AppRefs.run_state()
	if run_state != null:
		refresh_owned_units(run_state.owned_units)
		_on_deploy_limit_changed(run_state.deployed_count, run_state.deploy_limit)


func refresh_owned_units(unit_ids: Array[StringName]) -> void:
	var label := get_node_or_null("%OwnedUnitsLabel") as Label
	if label != null:
		label.text = "Owned: %s" % ", ".join(PackedStringArray(unit_ids))
	_rebuild_unit_buttons(unit_ids)


func refresh_redeploy_state(unit_id: StringName, ready: bool, remain_sec: float) -> void:
	var label := get_node_or_null("%RedeployLabel") as Label
	if label != null:
		label.text = "%s: %s %.1fs" % [unit_id, "ready" if ready else "cooldown", remain_sec]


func set_visible_for_phase(phase: int) -> void:
	visible = phase == GameEnums.PHASE_DAY


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	set_visible_for_phase(new_phase)


func _on_deploy_limit_changed(_current: int, _max_value: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	refresh_owned_units(run_state.owned_units)
	var count_label := get_node_or_null("%DeployCountLabel") as Label
	if count_label != null:
		count_label.text = "Deploy: %d/%d" % [run_state.deployed_count, run_state.deploy_limit]


func _rebuild_unit_buttons(unit_ids: Array[StringName]) -> void:
	var container := get_node_or_null("%UnitButtonList") as VBoxContainer
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	for unit_id in unit_ids:
		var button := Button.new()
		button.text = "Deploy %s" % String(unit_id)
		button.pressed.connect(_on_unit_selected.bind(unit_id))
		container.add_child(button)


func _on_unit_selected(unit_id: StringName) -> void:
	var action_panel := get_node_or_null("../ActionPanel")
	if action_panel != null and action_panel.has_method("set_mode_deploy"):
		action_panel.set_mode_deploy(unit_id)
