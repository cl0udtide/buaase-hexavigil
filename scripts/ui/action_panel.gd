extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")


var _current_mode: StringName = &"idle"
var _current_building_id: StringName = &""
var _current_operator_key: StringName = &""
var _selected_unit_runtime_id := -1
var _selected_building_runtime_id := -1
var _selected_facing := Vector2i.RIGHT


func _ready() -> void:
	AppTheme.apply(self)
	var event_bus = AppRefs.event_bus()
	var idle_button := get_node_or_null("%IdleButton") as BaseButton
	var explore_button := get_node_or_null("%ExploreButton") as BaseButton
	var night_button := get_node_or_null("%StartNightButton") as BaseButton
	if idle_button != null:
		idle_button.pressed.connect(set_mode_idle)
	if explore_button != null:
		explore_button.pressed.connect(set_mode_explore)
	if night_button != null:
		night_button.pressed.connect(func() -> void:
			if event_bus != null:
				event_bus.request_start_night.emit()
		)
	var facing_option := get_node_or_null("%FacingOption") as OptionButton
	if facing_option != null:
		_setup_facing_option(facing_option)
	var cast_button := get_node_or_null("%CastSkillButton") as BaseButton
	if cast_button != null:
		cast_button.custom_minimum_size = Vector2(120, 36)
		cast_button.pressed.connect(_on_cast_skill_pressed)
	var retreat_button := get_node_or_null("%RetreatButton") as BaseButton
	if retreat_button != null:
		retreat_button.custom_minimum_size = Vector2(90, 36)
		retreat_button.pressed.connect(_on_retreat_pressed)
	var repair_button := get_node_or_null("%RepairBuildingButton") as BaseButton
	if repair_button != null:
		repair_button.custom_minimum_size = Vector2(90, 36)
		repair_button.pressed.connect(_on_repair_building_pressed)
	var demolish_button := get_node_or_null("%DemolishBuildingButton") as BaseButton
	if demolish_button != null:
		demolish_button.custom_minimum_size = Vector2(90, 36)
		demolish_button.pressed.connect(_on_demolish_building_pressed)
	var toggle_button := get_node_or_null("%ToggleBuildingButton") as BaseButton
	if toggle_button != null:
		toggle_button.custom_minimum_size = Vector2(90, 36)
		toggle_button.pressed.connect(_on_toggle_building_pressed)
	for path in ["%IdleButton", "%ExploreButton", "%StartNightButton"]:
		var action_button := get_node_or_null(path) as BaseButton
		if action_button != null:
			action_button.custom_minimum_size = Vector2(90, 36)
	if event_bus != null:
		event_bus.map_cell_clicked.connect(_on_map_cell_clicked)
		event_bus.phase_changed.connect(_on_phase_changed)
		event_bus.unit_deployed.connect(_on_unit_deployed)
		event_bus.unit_removed.connect(_on_unit_removed)
		event_bus.building_state_changed.connect(_on_building_state_changed)
	set_process(true)
	_refresh_mode_labels()
	_refresh_combat_controls()
	_refresh_building_controls()


func _process(_delta: float) -> void:
	_refresh_combat_controls()
	_refresh_building_controls()


func set_mode_idle() -> void:
	_current_mode = &"idle"
	_current_building_id = &""
	_current_operator_key = &""
	_selected_unit_runtime_id = -1
	_selected_building_runtime_id = -1
	_clear_attack_range_preview()
	_refresh_mode_labels()


func set_mode_explore() -> void:
	_current_mode = &"explore"
	_current_building_id = &""
	_current_operator_key = &""
	_selected_unit_runtime_id = -1
	_selected_building_runtime_id = -1
	_clear_attack_range_preview()
	_refresh_mode_labels()


func set_mode_build(building_id: StringName) -> void:
	_current_mode = &"build"
	_current_building_id = building_id
	_current_operator_key = &""
	_selected_unit_runtime_id = -1
	_selected_building_runtime_id = -1
	_clear_attack_range_preview()
	_refresh_mode_labels()


func set_mode_deploy(operator_key: StringName) -> void:
	_current_mode = &"deploy"
	_current_building_id = &""
	_current_operator_key = operator_key
	_selected_unit_runtime_id = -1
	_selected_building_runtime_id = -1
	_clear_attack_range_preview()
	_refresh_mode_labels()


func clear_mode() -> void:
	set_mode_idle()


func get_current_mode() -> StringName:
	return _current_mode


func get_current_building_id() -> StringName:
	return _current_building_id


func get_current_unit_id() -> StringName:
	var run_state = AppRefs.run_state()
	if run_state == null or not run_state.has_method("get_owned_operator"):
		return StringName()
	var operator_info: Dictionary = run_state.get_owned_operator(_current_operator_key)
	return StringName(operator_info.get("unit_id", ""))


func get_current_operator_key() -> StringName:
	return _current_operator_key


func _on_map_cell_clicked(cell: Vector2i) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	var unit_manager := _get_unit_manager()
	if unit_manager != null and unit_manager.has_method("get_unit_by_cell"):
		var existing_unit = unit_manager.get_unit_by_cell(cell)
		if existing_unit != null:
			_select_unit(existing_unit)
			return
	var building_manager := _get_building_manager()
	if building_manager != null and building_manager.has_method("get_building_by_cell"):
		var existing_building = building_manager.get_building_by_cell(cell)
		if existing_building != null:
			_select_building(existing_building)
			return
	_clear_selected_building()
	_clear_selected_unit()
	if run_state.phase != GameEnums.PHASE_DAY:
		return
	var event_bus = AppRefs.event_bus()
	match _current_mode:
		&"explore":
			if event_bus != null:
				event_bus.request_explore.emit(cell)
		&"build":
			if _current_building_id != StringName() and event_bus != null:
				event_bus.request_build.emit(cell, _current_building_id)
		&"deploy":
			if _current_operator_key != StringName():
				_try_deploy_selected_operator(cell)


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	if new_phase != GameEnums.PHASE_DAY:
		set_mode_idle()


func _refresh_mode_labels() -> void:
	var mode_label := get_node_or_null("%ModeLabel") as Label
	var selection_label := get_node_or_null("%SelectionLabel") as Label
	if mode_label != null:
		var mode_text := {
			&"idle": "待机",
			&"explore": "探索",
			&"build": "建造",
			&"deploy": "部署"
		}
		mode_label.text = "模式：%s" % String(mode_text.get(_current_mode, _current_mode))
	if selection_label == null:
		return
	match _current_mode:
		&"build":
			selection_label.text = "当前选择：%s" % String(_current_building_id)
		&"deploy":
			selection_label.text = "当前选择：%s" % _get_operator_display_text(_current_operator_key)
		_:
			var selected_unit := _get_selected_unit()
			if selected_unit != null:
				selection_label.text = "当前选择：%s#%d" % [String(selected_unit.cfg.get("name", selected_unit.unit_id)), int(selected_unit.get_runtime_id())]
			else:
				var selected_building := _get_selected_building()
				if selected_building != null:
					selection_label.text = "当前选择：%s#%d" % [
						String(selected_building.cfg.get("name", selected_building.building_id)),
						int(selected_building.get_runtime_id())
					]
				else:
					selection_label.text = "当前选择：无"
	_refresh_combat_controls()
	_refresh_building_controls()


func _get_operator_display_text(operator_key: StringName) -> String:
	if operator_key == StringName():
		return "无"
	var run_state = AppRefs.run_state()
	if run_state == null or not run_state.has_method("get_owned_operator"):
		return String(operator_key)
	var operator_info: Dictionary = run_state.get_owned_operator(operator_key)
	if operator_info.is_empty():
		return String(operator_key)
	return "%s（%s）" % [String(operator_info.get("name", operator_key)), String(operator_info.get("unit_id", ""))]


func _setup_facing_option(option: OptionButton) -> void:
	option.clear()
	option.add_item("右", 0)
	option.add_item("下", 1)
	option.add_item("左", 2)
	option.add_item("上", 3)
	option.select(0)
	option.item_selected.connect(_on_facing_selected)


func _on_facing_selected(index: int) -> void:
	match index:
		1:
			_selected_facing = Vector2i.DOWN
		2:
			_selected_facing = Vector2i.LEFT
		3:
			_selected_facing = Vector2i.UP
		_:
			_selected_facing = Vector2i.RIGHT


func _try_deploy_selected_operator(cell: Vector2i) -> void:
	var unit_manager := _get_unit_manager()
	if unit_manager == null or not unit_manager.has_method("try_deploy_operator"):
		_show_message("部署失败：UnitManager 不可用")
		return
	var result: Dictionary = unit_manager.try_deploy_operator(_current_operator_key, cell, _selected_facing)
	if result.get("ok", false):
		_show_message("部署完成")
		var runtime_id := int(result.get("payload", {}).get("runtime_id", -1))
		var unit = unit_manager.get_unit_by_runtime_id(runtime_id) if unit_manager.has_method("get_unit_by_runtime_id") else null
		if unit != null:
			_select_unit(unit)
	else:
		_show_message(String(result.get("message", "部署失败")))


func _select_unit(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	_selected_unit_runtime_id = int(unit.get_runtime_id()) if unit.has_method("get_runtime_id") else -1
	_selected_building_runtime_id = -1
	_current_operator_key = StringName(unit.operator_key) if unit.get("operator_key") != null else StringName()
	_current_mode = &"idle"
	_current_building_id = &""
	_refresh_mode_labels()
	_refresh_attack_range_preview()
	_show_message("已选中 %s#%d" % [String(unit.cfg.get("name", unit.unit_id)), _selected_unit_runtime_id])


func _clear_selected_unit() -> void:
	_selected_unit_runtime_id = -1
	_clear_attack_range_preview()
	_refresh_mode_labels()


func _select_building(building: Node) -> void:
	if building == null or not is_instance_valid(building):
		return
	_selected_building_runtime_id = int(building.get_runtime_id()) if building.has_method("get_runtime_id") else -1
	_selected_unit_runtime_id = -1
	_current_mode = &"idle"
	_current_building_id = &""
	_current_operator_key = &""
	_clear_attack_range_preview()
	_refresh_mode_labels()
	_show_message("已选中 %s#%d" % [String(building.cfg.get("name", building.building_id)), _selected_building_runtime_id])


func _clear_selected_building() -> void:
	_selected_building_runtime_id = -1
	_refresh_mode_labels()


func _on_cast_skill_pressed() -> void:
	var unit := _get_selected_unit()
	var unit_manager := _get_unit_manager()
	if unit == null or unit_manager == null:
		_show_message("请先选择一个已部署干员")
		return
	var result: Dictionary = unit_manager.try_cast_skill(unit.get_runtime_id())
	_show_result_message(result, "技能已释放", "技能失败")
	_refresh_combat_controls()


func _on_retreat_pressed() -> void:
	var unit := _get_selected_unit()
	var unit_manager := _get_unit_manager()
	if unit == null or unit_manager == null:
		_show_message("请先选择一个已部署干员")
		return
	var result: Dictionary = unit_manager.try_retreat_unit(unit.get_runtime_id())
	if result.get("ok", false):
		_selected_unit_runtime_id = -1
		_clear_attack_range_preview()
	_show_result_message(result, "已撤退", "撤退失败")
	_refresh_combat_controls()


func _refresh_combat_controls() -> void:
	var unit := _get_selected_unit()
	var skill_label := get_node_or_null("%SkillInfoLabel") as Label
	var cast_button := get_node_or_null("%CastSkillButton") as BaseButton
	var retreat_button := get_node_or_null("%RetreatButton") as BaseButton
	if skill_label != null:
		skill_label.text = _format_skill_info(unit)
	if cast_button != null:
		cast_button.disabled = unit == null or not unit.can_cast_skill()
	if retreat_button != null:
		retreat_button.disabled = unit == null


func _refresh_building_controls() -> void:
	var building := _get_selected_building()
	var info_label := get_node_or_null("%BuildingInfoLabel") as Label
	var repair_button := get_node_or_null("%RepairBuildingButton") as BaseButton
	var demolish_button := get_node_or_null("%DemolishBuildingButton") as BaseButton
	var toggle_button := get_node_or_null("%ToggleBuildingButton") as BaseButton
	var run_state: Node = AppRefs.run_state()
	var is_day: bool = run_state != null and run_state.phase == GameEnums.PHASE_DAY
	var is_destroyed: bool = _is_building_destroyed(building)
	if info_label != null:
		info_label.text = _format_building_info(building)
	if repair_button != null:
		repair_button.disabled = building == null or not is_day or not is_destroyed
	if demolish_button != null:
		demolish_button.disabled = building == null or not is_day or not is_destroyed
	if toggle_button != null:
		toggle_button.disabled = building == null or not is_day or is_destroyed or building.get("building_id") != &"war_shrine"


func _format_skill_info(unit: Node) -> String:
	if unit == null:
		return "选中场上干员后可查看技能、释放技能或撤退。"
	var sp_max := float(unit.cfg.get("sp_max", 0.0))
	var active_remaining := float(unit.get_skill_active_remaining()) if unit.has_method("get_skill_active_remaining") else 0.0
	var active_text := ""
	if active_remaining < 0.0:
		active_text = "  技能已常驻"
	elif active_remaining > 0.0:
		active_text = "  持续 %.1fs" % active_remaining
	return "%s#%d  HP %d/%d  SP %.0f/%.0f%s\n%s：%s" % [
		String(unit.cfg.get("name", unit.unit_id)),
		int(unit.get_runtime_id()),
		int(unit.current_hp),
		int(unit.max_hp),
		float(unit.sp),
		sp_max,
		active_text,
		unit.get_skill_name(),
		unit.get_skill_description()
	]


func _format_building_info(building: Node) -> String:
	if building == null:
		return "选中建筑后可查看耐久。"
	var state_text := "已毁" if _is_building_destroyed(building) else "运作中"
	var text := "%s#%d  HP %d/%d  %s" % [
		String(building.cfg.get("name", building.building_id)),
		int(building.get_runtime_id()),
		int(building.current_hp),
		int(building.max_hp),
		state_text
	]
	if _is_building_destroyed(building):
		var cost := _get_destroyed_repair_cost(building)
		text += "\n修复消耗：木%d 石%d 魔%d" % [
			int(cost.get("wood", 0)),
			int(cost.get("stone", 0)),
			int(cost.get("mana", 0))
		]
	elif building.has_method("can_toggle_enabled") and building.can_toggle_enabled():
		text += "\n状态：%s" % ("开启" if building.is_enabled() else "关闭")
	return text


func _get_selected_unit() -> Node:
	if _selected_unit_runtime_id < 0:
		return null
	var unit_manager := _get_unit_manager()
	if unit_manager == null or not unit_manager.has_method("get_unit_by_runtime_id"):
		return null
	var unit = unit_manager.get_unit_by_runtime_id(_selected_unit_runtime_id)
	if unit == null or not is_instance_valid(unit):
		_selected_unit_runtime_id = -1
		_clear_attack_range_preview()
		return null
	return unit


func _get_selected_building() -> Node:
	if _selected_building_runtime_id < 0:
		return null
	var building_manager := _get_building_manager()
	if building_manager == null or not building_manager.has_method("get_building_by_runtime_id"):
		return null
	var building = building_manager.get_building_by_runtime_id(_selected_building_runtime_id)
	if building == null or not is_instance_valid(building):
		_selected_building_runtime_id = -1
		return null
	return building


func _refresh_attack_range_preview() -> void:
	var unit := _get_selected_unit()
	var map_root := _get_map_root()
	if map_root == null or not map_root.has_method("set_debug_attack_range"):
		return
	if unit == null:
		_clear_attack_range_preview()
		return
	map_root.set_debug_attack_range(_get_unit_attack_range_cells(unit))


func _clear_attack_range_preview() -> void:
	var map_root := _get_map_root()
	if map_root != null and map_root.has_method("clear_debug_attack_range"):
		map_root.clear_debug_attack_range()


func _get_unit_attack_range_cells(unit: Node) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var map_manager := _get_map_manager()
	if map_manager == null or unit == null:
		return cells
	var origin: Vector2i = unit.get_current_cell()
	for offset: Vector2i in unit.range_pattern:
		var cell := origin + _rotate_offset(offset, unit.facing)
		if map_manager.is_inside(cell) and not cells.has(cell):
			cells.append(cell)
	return cells


func _rotate_offset(offset: Vector2i, direction: Vector2i) -> Vector2i:
	var normalized := _normalize_direction(direction)
	if normalized == Vector2i.LEFT:
		return Vector2i(-offset.x, -offset.y)
	if normalized == Vector2i.UP:
		return Vector2i(offset.y, -offset.x)
	if normalized == Vector2i.DOWN:
		return Vector2i(-offset.y, offset.x)
	return offset


func _normalize_direction(direction: Vector2i) -> Vector2i:
	if abs(direction.x) >= abs(direction.y):
		return Vector2i.RIGHT if direction.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0 else Vector2i.UP


func _on_unit_deployed(unit_runtime_id: int, _operator_key: StringName, _unit_id: StringName, _cell: Vector2i) -> void:
	_selected_unit_runtime_id = unit_runtime_id
	_selected_building_runtime_id = -1
	_refresh_attack_range_preview()
	_refresh_combat_controls()


func _on_unit_removed(unit_runtime_id: int, _reason: int) -> void:
	if _selected_unit_runtime_id == unit_runtime_id:
		_selected_unit_runtime_id = -1
		_clear_attack_range_preview()
	_refresh_combat_controls()


func _on_building_state_changed(_building_runtime_id: int, building_id: StringName, enabled: bool) -> void:
	if building_id != &"war_shrine":
		return
	_show_message("War Shrine %s" % ("enabled" if enabled else "disabled"))
	_refresh_building_controls()


func _on_repair_building_pressed() -> void:
	var building := _get_selected_building()
	var building_manager := _get_building_manager()
	if building == null or building_manager == null or not building_manager.has_method("try_repair_building"):
		_show_message("请先选择一个已毁建筑")
		return
	var result: Dictionary = building_manager.try_repair_building(building.get_runtime_id())
	_show_result_message(result, "建筑已修复", "修复失败")
	_refresh_mode_labels()


func _on_demolish_building_pressed() -> void:
	var building := _get_selected_building()
	var building_manager := _get_building_manager()
	if building == null or building_manager == null or not building_manager.has_method("try_demolish_building"):
		_show_message("请先选择一个已毁建筑")
		return
	var result: Dictionary = building_manager.try_demolish_building(building.get_runtime_id())
	if result.get("ok", false):
		_selected_building_runtime_id = -1
	_show_result_message(result, "建筑已拆除", "拆除失败")
	_refresh_mode_labels()


func _on_toggle_building_pressed() -> void:
	var building := _get_selected_building()
	var building_manager := _get_building_manager()
	if building == null or building_manager == null or not building_manager.has_method("try_toggle_building"):
		_show_message("请先选择一个可切换建筑")
		return
	var result: Dictionary = building_manager.try_toggle_building(building.get_runtime_id())
	_show_result_message(result, "建筑状态已切换", "切换失败")
	_refresh_mode_labels()


func _get_destroyed_repair_cost(building: Node) -> Dictionary:
	var cfg: Dictionary = building.cfg if building != null else {}
	return {
		"wood": _half_repair_cost(int(cfg.get("cost_wood", 0))),
		"stone": _half_repair_cost(int(cfg.get("cost_stone", 0))),
		"mana": _half_repair_cost(int(cfg.get("cost_mana", 0)))
	}


func _half_repair_cost(value: int) -> int:
	if value <= 0:
		return 0
	return int(ceil(float(value) * 0.5))


func _is_building_destroyed(building: Node) -> bool:
	if building == null:
		return false
	if building.has_method("is_destroyed"):
		return bool(building.is_destroyed())
	var current_hp_variant: Variant = building.get("current_hp")
	return current_hp_variant != null and int(current_hp_variant) <= 0


func _show_message(text: String) -> void:
	var message_label := get_node_or_null("%MessageLabel") as Label
	if message_label != null:
		message_label.text = text
	var hud := get_node_or_null("../HUD")
	if hud != null and hud.has_method("show_message"):
		hud.show_message(text)


func _show_result_message(result: Dictionary, success_text: String, failure_text: String) -> void:
	var message := String(result.get("message", ""))
	if message.is_empty():
		message = success_text if result.get("ok", false) else failure_text
	_show_message(message)


func _get_unit_manager() -> Node:
	return get_node_or_null("../../Managers/UnitManager")


func _get_map_manager() -> Node:
	return get_node_or_null("../../Managers/MapManager")


func _get_map_root() -> Node:
	return get_node_or_null("../../World/MapRoot")


func _get_building_manager() -> Node:
	return get_node_or_null("../../Managers/BuildingManager")
