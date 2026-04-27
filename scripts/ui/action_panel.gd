extends PanelContainer

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

var _current_mode: StringName = &"idle"
var _current_building_id: StringName = &""
var _current_phase := GameEnums.PHASE_MENU
var _selected_building_runtime_id := -1

@onready var _mode_label: Label = %ModeLabel
@onready var _idle_button: Button = %IdleButton
@onready var _explore_button: Button = %ExploreButton
@onready var _start_night_button: Button = %StartNightButton
@onready var _repair_building_button: Button = %RepairBuildingButton
@onready var _demolish_building_button: Button = %DemolishBuildingButton
@onready var _toggle_building_button: Button = %ToggleBuildingButton
@onready var _building_info_label: Label = %BuildingInfoLabel


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	_bind_buttons()
	_bind_events()
	var run_state = AppRefs.run_state()
	if run_state != null:
		_current_phase = int(run_state.phase)
	_refresh_state()


func set_mode_idle() -> void:
	_current_mode = &"idle"
	_current_building_id = &""
	_clear_selected_building()
	_refresh_state()


func set_mode_explore() -> void:
	_current_mode = &"explore"
	_current_building_id = &""
	_clear_selected_building()
	_refresh_state()


func set_mode_build(building_id: StringName) -> void:
	_current_mode = &"build"
	_current_building_id = building_id
	_clear_selected_building()
	_refresh_state()


func clear_mode() -> void:
	set_mode_idle()


func get_current_mode() -> StringName:
	return _current_mode


func get_current_building_id() -> StringName:
	return _current_building_id


func _bind_buttons() -> void:
	_idle_button.pressed.connect(set_mode_idle)
	_explore_button.pressed.connect(set_mode_explore)
	_start_night_button.pressed.connect(_on_start_night_pressed)
	_repair_building_button.pressed.connect(_on_repair_building_pressed)
	_demolish_building_button.pressed.connect(_on_demolish_building_pressed)
	_toggle_building_button.pressed.connect(_on_toggle_building_pressed)


func _bind_events() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	event_bus.map_cell_clicked.connect(_on_map_cell_clicked)
	event_bus.phase_changed.connect(_on_phase_changed)
	event_bus.building_destroyed.connect(_on_building_changed)
	event_bus.building_state_changed.connect(_on_building_state_changed)


func _on_map_cell_clicked(cell: Vector2i) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null or int(run_state.phase) != GameEnums.PHASE_DAY:
		return
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	var existing_building := _get_building_by_cell(cell)
	if existing_building != null:
		_select_building(existing_building)
		return
	_clear_selected_building()
	if _current_mode == &"idle" and _try_toggle_idle_building(cell):
		return
	if _current_mode == &"explore":
		event_bus.request_explore.emit(cell)
	elif _current_mode == &"build" and _current_building_id != StringName():
		event_bus.request_build.emit(cell, _current_building_id)


func _try_toggle_idle_building(cell: Vector2i) -> bool:
	var existing_building := _get_building_by_cell(cell)
	if existing_building == null or not is_instance_valid(existing_building):
		return false
	if StringName(existing_building.get("building_id")) != &"war_shrine":
		return false
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_toggle_building.emit(int(existing_building.get_runtime_id()))
	return true


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	_current_phase = new_phase
	if new_phase != GameEnums.PHASE_DAY:
		set_mode_idle()
	else:
		_refresh_state()


func _on_start_night_pressed() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_start_night.emit()


func _refresh_state() -> void:
	_refresh_mode_label()
	_refresh_building_controls()
	var day_phase := _current_phase == GameEnums.PHASE_DAY
	_idle_button.disabled = not day_phase or _current_mode == &"idle"
	_explore_button.disabled = not day_phase or _current_mode == &"explore"
	_start_night_button.disabled = not day_phase
	_style_action_button(_idle_button, _current_mode == &"idle")
	_style_action_button(_explore_button, _current_mode == &"explore")
	_style_action_button(_start_night_button, false)


func _refresh_mode_label() -> void:
	if _mode_label == null:
		return
	if _current_phase != GameEnums.PHASE_DAY:
		_mode_label.text = "待机"
		return
	match _current_mode:
		&"explore":
			_mode_label.text = "探索"
		&"build":
			_mode_label.text = "建造"
		_:
			_mode_label.text = "待机"


func _apply_visual_style() -> void:
	add_theme_stylebox_override("panel", GameUiStyle.panel(GameUiStyle.BG_DARK, GameUiStyle.STROKE_SOFT, 1.0, 6.0))
	var content_margin := get_node_or_null("ContentMargin") as MarginContainer
	if content_margin != null:
		content_margin.add_theme_constant_override("margin_left", 8)
		content_margin.add_theme_constant_override("margin_top", 6)
		content_margin.add_theme_constant_override("margin_right", 8)
		content_margin.add_theme_constant_override("margin_bottom", 6)
	if _mode_label != null:
		_mode_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	for button in [_idle_button, _explore_button, _start_night_button, _repair_building_button, _demolish_building_button, _toggle_building_button]:
		if button != null:
			button.custom_minimum_size = Vector2(58.0, 28.0)
	if _building_info_label != null:
		_building_info_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)


func _style_action_button(button: Button, selected: bool) -> void:
	if button == null:
		return
	var accent := GameUiStyle.ACCENT if selected else GameUiStyle.STROKE_SOFT
	button.add_theme_stylebox_override("normal", GameUiStyle.button(accent, 0.18))
	button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT, 0.26))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.32))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.10))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)


func _get_building_manager() -> Node:
	return get_node_or_null("../../Managers/BuildingManager")


func _get_building_by_cell(cell: Vector2i) -> Node:
	var building_manager := _get_building_manager()
	if building_manager == null or not building_manager.has_method("get_building_by_cell"):
		return null
	var building = building_manager.get_building_by_cell(cell)
	return building if building != null and is_instance_valid(building) else null


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


func _select_building(building: Node) -> void:
	_selected_building_runtime_id = int(building.get_runtime_id())
	_refresh_building_controls()


func _clear_selected_building() -> void:
	_selected_building_runtime_id = -1
	_refresh_building_controls()


func _refresh_building_controls() -> void:
	var building := _get_selected_building()
	var is_day := _current_phase == GameEnums.PHASE_DAY
	var is_destroyed := _is_building_destroyed(building)
	if _building_info_label != null:
		_building_info_label.text = _format_building_info(building)
	if _repair_building_button != null:
		_repair_building_button.disabled = building == null or not is_day or not is_destroyed
		_style_action_button(_repair_building_button, false)
	if _demolish_building_button != null:
		_demolish_building_button.disabled = building == null or not is_day or not is_destroyed
		_style_action_button(_demolish_building_button, false)
	if _toggle_building_button != null:
		_toggle_building_button.disabled = building == null or not is_day or is_destroyed or StringName(building.get("building_id")) != &"war_shrine"
		_style_action_button(_toggle_building_button, false)


func _format_building_info(building: Node) -> String:
	if building == null:
		return "选择建筑查看耐久"
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


func _on_repair_building_pressed() -> void:
	var building := _get_selected_building()
	var building_manager := _get_building_manager()
	if building == null or building_manager == null or not building_manager.has_method("try_repair_building"):
		return
	building_manager.try_repair_building(building.get_runtime_id())
	_refresh_building_controls()


func _on_demolish_building_pressed() -> void:
	var building := _get_selected_building()
	var building_manager := _get_building_manager()
	if building == null or building_manager == null or not building_manager.has_method("try_demolish_building"):
		return
	var result: Dictionary = building_manager.try_demolish_building(building.get_runtime_id())
	if result.get("ok", false):
		_selected_building_runtime_id = -1
	_refresh_building_controls()


func _on_toggle_building_pressed() -> void:
	var building := _get_selected_building()
	var building_manager := _get_building_manager()
	if building == null or building_manager == null or not building_manager.has_method("try_toggle_building"):
		return
	building_manager.try_toggle_building(building.get_runtime_id())
	_refresh_building_controls()


func _on_building_changed(building_runtime_id: int, _building_id: StringName, _cell: Vector2i) -> void:
	if building_runtime_id == _selected_building_runtime_id:
		_refresh_building_controls()


func _on_building_state_changed(building_runtime_id: int, _building_id: StringName, _enabled: bool) -> void:
	if building_runtime_id == _selected_building_runtime_id:
		_refresh_building_controls()


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
