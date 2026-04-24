extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")


var _operators: Array[Dictionary] = []


func _ready() -> void:
	AppTheme.apply(self)
	set_process(true)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.phase_changed.connect(_on_phase_changed)
		event_bus.deploy_limit_changed.connect(_on_deploy_limit_changed)
		event_bus.owned_operators_changed.connect(refresh_owned_operators)
		event_bus.unit_deployed.connect(_on_unit_deployed)
		event_bus.unit_removed.connect(_on_unit_removed)
	var run_state = AppRefs.run_state()
	if run_state != null:
		if run_state.has_method("get_owned_operators"):
			refresh_owned_operators(run_state.get_owned_operators())
		else:
			refresh_owned_units(run_state.owned_units)
		_on_deploy_limit_changed(run_state.deployed_count, run_state.deploy_limit)


func _process(_delta: float) -> void:
	_update_operator_button_states()


func refresh_owned_operators(operators: Array[Dictionary]) -> void:
	_operators.clear()
	for operator_info in operators:
		_operators.append((operator_info as Dictionary).duplicate(true))
	var label := get_node_or_null("%OwnedUnitsLabel") as Label
	if label != null:
		var names: Array[String] = []
		for operator_info in _operators:
			names.append(_format_operator_name(operator_info))
		label.text = "已拥有：%s" % ", ".join(PackedStringArray(names))
	_rebuild_operator_buttons()


func refresh_owned_units(unit_ids: Array[StringName]) -> void:
	var operators: Array[Dictionary] = []
	for index in range(unit_ids.size()):
		operators.append({
			"key": StringName("compat_%d" % index),
			"unit_id": unit_ids[index],
			"name": String(unit_ids[index])
		})
	refresh_owned_operators(operators)


func refresh_operator_state(operator_key: StringName, state: StringName, remain_sec: float) -> void:
	var label := get_node_or_null("%RedeployLabel") as Label
	if label != null:
		label.text = "%s：%s %.1f秒" % [String(operator_key), _state_text(state), remain_sec]
	_update_operator_button_states()


func refresh_redeploy_state(unit_id: StringName, ready: bool, remain_sec: float) -> void:
	var label := get_node_or_null("%RedeployLabel") as Label
	if label != null:
		label.text = "%s：%s %.1f秒" % [unit_id, "可部署" if ready else "冷却中", remain_sec]


func set_visible_for_phase(phase: int) -> void:
	visible = phase == GameEnums.PHASE_DAY


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	set_visible_for_phase(new_phase)


func _on_deploy_limit_changed(_current: int, _max_value: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	if run_state.has_method("get_owned_operators"):
		refresh_owned_operators(run_state.get_owned_operators())
	var count_label := get_node_or_null("%DeployCountLabel") as Label
	if count_label != null:
		count_label.text = "部署：%d/%d" % [run_state.deployed_count, run_state.deploy_limit]


func _on_unit_deployed(_unit_runtime_id: int, _operator_key: StringName, _unit_id: StringName, _cell: Vector2i) -> void:
	_update_operator_button_states()


func _on_unit_removed(_unit_runtime_id: int, _reason: int) -> void:
	_update_operator_button_states()


func _rebuild_operator_buttons() -> void:
	var container := get_node_or_null("%UnitButtonList") as VBoxContainer
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	for operator_info in _operators:
		var button := Button.new()
		button.set_meta("operator_key", operator_info.get("key", ""))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_operator_selected.bind(StringName(operator_info.get("key", ""))))
		container.add_child(button)
	_update_operator_button_states()


func _update_operator_button_states() -> void:
	var container := get_node_or_null("%UnitButtonList") as VBoxContainer
	if container == null:
		return
	for child in container.get_children():
		var button := child as Button
		if button == null:
			continue
		var operator_key := StringName(button.get_meta("operator_key", ""))
		var operator_info := _get_operator_info(operator_key)
		var state := _get_operator_state(operator_key)
		button.text = _format_operator_button_text(operator_info, state)
		button.disabled = state != &"ready"
	_refresh_redeploy_label()


func _refresh_redeploy_label() -> void:
	var label := get_node_or_null("%RedeployLabel") as Label
	if label == null:
		return
	var cooldowns: Array[String] = []
	var unit_manager := _get_unit_manager()
	for operator_info in _operators:
		var operator_key := StringName(operator_info.get("key", ""))
		if unit_manager != null and unit_manager.has_method("get_operator_redeploy_remaining"):
			var remain := float(unit_manager.get_operator_redeploy_remaining(operator_key))
			if remain > 0.0:
				cooldowns.append("%s %.1fs" % [_format_operator_name(operator_info), remain])
	var cooldown_text := ", ".join(PackedStringArray(cooldowns)) if not cooldowns.is_empty() else "无"
	label.text = "再部署：%s" % cooldown_text


func _on_operator_selected(operator_key: StringName) -> void:
	var action_panel := get_node_or_null("../ActionPanel")
	if action_panel != null and action_panel.has_method("set_mode_deploy"):
		action_panel.set_mode_deploy(operator_key)


func _get_operator_info(operator_key: StringName) -> Dictionary:
	for operator_info in _operators:
		if StringName((operator_info as Dictionary).get("key", "")) == operator_key:
			return (operator_info as Dictionary)
	return {}


func _get_operator_state(operator_key: StringName) -> StringName:
	var unit_manager := _get_unit_manager()
	if unit_manager == null or not unit_manager.has_method("get_operator_status"):
		return &"ready"
	return StringName(unit_manager.get_operator_status(operator_key))


func _format_operator_button_text(operator_info: Dictionary, state: StringName) -> String:
	var text := _format_operator_name(operator_info)
	if state == &"cooldown":
		var unit_manager := _get_unit_manager()
		var remain := float(unit_manager.get_operator_redeploy_remaining(StringName(operator_info.get("key", "")))) if unit_manager != null else 0.0
		return "%s  CD %.1fs" % [text, remain]
	if state == &"deployed":
		return "%s  已部署" % text
	return "部署 %s" % text


func _format_operator_name(operator_info: Dictionary) -> String:
	var name := String(operator_info.get("name", ""))
	if name.is_empty():
		name = String(operator_info.get("unit_id", operator_info.get("key", "")))
	return "%s[%s]" % [name, String(operator_info.get("key", ""))]


func _state_text(state: StringName) -> String:
	match state:
		&"ready":
			return "可部署"
		&"deployed":
			return "已部署"
		&"cooldown":
			return "冷却中"
		_:
			return String(state)


func _get_unit_manager() -> Node:
	return get_node_or_null("../../Managers/UnitManager")
