extends PanelContainer

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")

const EXPLORE_AP_COST := 2

var _current_mode: StringName = &"idle"
var _current_building_id: StringName = &""
var _current_phase := GameEnums.PHASE_MENU
var _selected_building_runtime_id := -1

@onready var _mode_label: Label = %ModeLabel
@onready var _start_night_button: Button = %StartNightButton
@onready var _repair_building_button: Button = %RepairBuildingButton
@onready var _demolish_building_button: Button = %DemolishBuildingButton
@onready var _toggle_building_button: Button = %ToggleBuildingButton
@onready var _building_info_label: Label = %BuildingInfoLabel
@onready var _map_root: Node = _resolve_node(["../../World/MapRoot", "../../../../World/MapRoot"])
@onready var _map_manager: Node = _resolve_node(["../../Managers/MapManager", "../../../../Managers/MapManager"])


func _resolve_node(paths: Array) -> Node:
	for path in paths:
		var node := get_node_or_null(String(path))
		if node != null:
			return node
	return null


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	_bind_buttons()
	_bind_events()
	set_process(true)
	var run_state = AppRefs.run_state()
	if run_state != null:
		_current_phase = int(run_state.phase)
	_refresh_state()


func _process(_delta: float) -> void:
	_refresh_building_range_preview()


func set_mode_idle() -> void:
	_current_mode = &"idle"
	_current_building_id = &""
	_clear_selected_building()
	_clear_building_range_preview()
	_refresh_state()


func set_mode_explore() -> void:
	_current_mode = &"explore"
	_current_building_id = &""
	_clear_selected_building()
	_clear_building_range_preview()
	_refresh_state()


func set_mode_build(building_id: StringName) -> void:
	_current_mode = &"build"
	_current_building_id = building_id
	_clear_selected_building()
	_refresh_building_range_preview()
	_refresh_state()


func clear_mode() -> void:
	set_mode_idle()


func get_current_mode() -> StringName:
	return _current_mode


func get_current_building_id() -> StringName:
	return _current_building_id


func _bind_buttons() -> void:
	_start_night_button.pressed.connect(_on_start_night_pressed)
	_repair_building_button.pressed.connect(_on_repair_building_pressed)
	_demolish_building_button.pressed.connect(_on_demolish_building_pressed)
	_toggle_building_button.pressed.connect(_on_toggle_building_pressed)


func _bind_events() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	event_bus.map_cell_clicked.connect(_on_map_cell_clicked)
	event_bus.map_cell_hovered.connect(_on_map_cell_hovered)
	event_bus.phase_changed.connect(_on_phase_changed)
	event_bus.action_points_changed.connect(_on_action_points_changed)
	event_bus.fog_revealed.connect(_on_fog_revealed)
	event_bus.building_placed.connect(_on_building_placed)
	event_bus.building_destroyed.connect(_on_building_changed)
	event_bus.building_state_changed.connect(_on_building_state_changed)


func _on_map_cell_clicked(cell: Vector2i) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null or int(run_state.phase) != GameEnums.PHASE_DAY:
		return
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	if _current_mode == &"explore":
		event_bus.request_explore.emit(cell)
		return
	if _current_mode == &"build" and _current_building_id != StringName():
		event_bus.request_build.emit(cell, _current_building_id)
		return
	if _can_auto_explore_cell(cell):
		event_bus.request_explore.emit(cell)


func _can_auto_explore_cell(cell: Vector2i) -> bool:
	if _map_manager == null:
		return false
	if not _map_manager.is_inside(cell) or _map_manager.is_discovered(cell):
		return false
	if not _map_manager.has_method("has_discovered_neighbor"):
		return false
	return bool(_map_manager.has_discovered_neighbor(cell))


func _has_enough_ap_to_explore() -> bool:
	var run_state = AppRefs.run_state()
	return run_state != null and int(run_state.action_points) >= EXPLORE_AP_COST


func _on_map_cell_hovered(cell: Vector2i) -> void:
	if _map_root == null or not _map_root.has_method("set_fog_hover_active"):
		return
	if _current_phase != GameEnums.PHASE_DAY:
		_map_root.set_fog_hover_active(false)
		return
	if _current_mode != &"idle":
		_map_root.set_fog_hover_active(false)
		return
	var active := _can_auto_explore_cell(cell) and _has_enough_ap_to_explore()
	_map_root.set_fog_hover_active(active)


func _refresh_fog_hover_from_cursor() -> void:
	if _map_root == null or _map_manager == null:
		return
	var cell: Vector2i = _map_manager.world_to_cell(_map_root.get_global_mouse_position())
	if not _map_manager.is_inside(cell):
		cell = Vector2i(-1, -1)
	_on_map_cell_hovered(cell)


func _on_action_points_changed(_value: int) -> void:
	_refresh_fog_hover_from_cursor()


func _on_fog_revealed(_cells: Array) -> void:
	_refresh_fog_hover_from_cursor()


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
		_clear_building_range_preview()
		set_mode_idle()
		if _map_root != null and _map_root.has_method("set_fog_hover_active"):
			_map_root.set_fog_hover_active(false)
	else:
		_refresh_state()
		_refresh_fog_hover_from_cursor()


func _on_start_night_pressed() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_start_night.emit()


func _refresh_state() -> void:
	_refresh_mode_label()
	_refresh_building_controls()
	var day_phase := _current_phase == GameEnums.PHASE_DAY
	visible = day_phase
	_start_night_button.disabled = not day_phase
	_style_action_button(_start_night_button, not day_phase)


func _refresh_mode_label() -> void:
	if _mode_label == null:
		return
	_mode_label.visible = false
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
	var content_margin := get_node_or_null("ContentMargin") as MarginContainer
	if content_margin != null:
		content_margin.add_theme_constant_override("margin_left", 0)
		content_margin.add_theme_constant_override("margin_top", 0)
		content_margin.add_theme_constant_override("margin_right", 0)
		content_margin.add_theme_constant_override("margin_bottom", 0)
	if _mode_label != null:
		_mode_label.visible = false
		_mode_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	for button in [_start_night_button, _repair_building_button, _demolish_building_button, _toggle_building_button]:
		if button != null:
			button.set_custom_minimum_size(Vector2(74.0, 36.0))
			GameUiStyle.center_button_text(button)
	var action_button_flow := get_node_or_null("%ActionButtonFlow") as BoxContainer
	if action_button_flow != null:
		action_button_flow.alignment = BoxContainer.ALIGNMENT_CENTER
	var building_action_flow := get_node_or_null("%BuildingActionFlow") as Control
	if building_action_flow == null:
		building_action_flow = get_node_or_null("ContentMargin/VBoxContainer/BuildingActionFlow") as Control
	if building_action_flow != null:
		building_action_flow.visible = false
	if _building_info_label != null:
		_building_info_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
		_building_info_label.visible = false


func _style_action_button(button: Button, selected: bool) -> void:
	if button == null:
		return
	GameUiStyle.center_button_text(button)
	var accent := GameUiStyle.AMBER if selected else GameUiStyle.STROKE_SOFT
	var normal_style := GameUiStyle.frame_box(GameUiStyle.FRAME_ACTION_BUTTON, GameUiStyle.BG_CARD, accent)
	GameUiStyle.set_button_texture_icon(button, _icon_for_action_button(button), &"left", 8.0)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", GameUiStyle.frame_box(GameUiStyle.FRAME_ACTION_BUTTON, GameUiStyle.BG_CARD_HOVER, GameUiStyle.ACCENT))
	button.add_theme_stylebox_override("pressed", GameUiStyle.frame_box(GameUiStyle.FRAME_ACTION_BUTTON, GameUiStyle.BG_CARD_HOVER, GameUiStyle.AMBER))
	button.add_theme_stylebox_override("disabled", normal_style if selected else GameUiStyle.frame_box(GameUiStyle.FRAME_ACTION_BUTTON, GameUiStyle.BG_CARD, GameUiStyle.STROKE_SOFT))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_INVERTED if selected else GameUiStyle.TEXT_INVERTED_DIM)


func _icon_for_action_button(button: Button) -> Texture2D:
	if button == _start_night_button:
		return UiArtRegistry.get_catalog_icon(&"phase_night")
	if button == _repair_building_button:
		return UiArtRegistry.get_catalog_icon(&"button_confirm")
	if button == _demolish_building_button:
		return UiArtRegistry.get_catalog_icon(&"button_cancel")
	if button == _toggle_building_button:
		return UiArtRegistry.get_catalog_icon(&"button_refresh")
	return null


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
	var can_demolish := _can_demolish_building(building)
	if _building_info_label != null:
		_building_info_label.text = _format_building_info(building)
	if _repair_building_button != null:
		_repair_building_button.disabled = building == null or not is_day or not is_destroyed
		_style_action_button(_repair_building_button, false)
	if _demolish_building_button != null:
		_demolish_building_button.disabled = building == null or not is_day or not can_demolish
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
	elif _can_demolish_building(building):
		text += "\n可直接拆除，用于重新打开或调整敌人路线"
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


func _on_building_placed(_building_runtime_id: int, building_id: StringName, _cell: Vector2i) -> void:
	if _current_mode == &"build" and building_id == _current_building_id:
		set_mode_idle()


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


func _can_demolish_building(building: Node) -> bool:
	return building != null


func _refresh_building_range_preview() -> void:
	if _current_phase != GameEnums.PHASE_DAY or _current_mode != &"build" or _current_building_id == StringName():
		return
	if _map_root == null or _map_manager == null or not _map_root.has_method("set_building_effect_range"):
		return
	var cfg := _get_building_cfg(_current_building_id)
	var radius := _get_effective_building_radius(cfg)
	if radius <= 0:
		_clear_building_range_preview()
		return
	var cell: Vector2i = _map_manager.world_to_cell(_map_root.get_global_mouse_position())
	if not _map_manager.is_inside(cell) or not _map_manager.is_discovered(cell):
		_clear_building_range_preview()
		return
	_map_root.set_building_effect_range(_get_building_range_cells(cell, radius, cfg))


func _clear_building_range_preview() -> void:
	if _map_root != null and _map_root.has_method("clear_building_effect_range"):
		_map_root.clear_building_effect_range()


func _get_building_range_cells(center: Vector2i, radius: int, cfg: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _map_manager == null:
		return cells
	var trimmed_square: bool = StringName(cfg.get("effect_shape", "")) == &"trimmed_square"
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if trimmed_square and abs(cell.x - center.x) == radius and abs(cell.y - center.y) == radius:
				continue
			if _map_manager.is_inside(cell):
				cells.append(cell)
	return cells


func _get_effective_building_radius(cfg: Dictionary) -> int:
	var radius := int(cfg.get("effect_radius", 0))
	if radius <= 0:
		return radius
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_buff_effect_total_for_building"):
		radius += int(round(float(run_state.get_buff_effect_total_for_building(&"building_aura_radius_add", cfg))))
	return max(radius, 0)


func _get_building_cfg(building_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_building_cfg(building_id) if data_repo != null else {}
