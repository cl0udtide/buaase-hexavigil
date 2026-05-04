extends PanelContainer

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const EVENT_TRIGGER_AP_COST := 2
const RESOURCE_COLLECT_AP_COST := 1
const RESOURCE_COLLECT_AMOUNT := 1
const POPUP_MIN_WIDTH := 228.0
const POPUP_OFFSET := Vector2(14.0, 14.0)
const INVALID_CELL := Vector2i(-1, -1)

var _current_cell := INVALID_CELL
var _current_phase := GameEnums.PHASE_MENU

@onready var _title_label: Label = %TitleLabel
@onready var _event_section: VBoxContainer = %EventSection
@onready var _event_info_label: Label = %EventInfoLabel
@onready var _trigger_event_button: Button = %TriggerEventButton
@onready var _resource_section: VBoxContainer = %ResourceSection
@onready var _resource_info_label: Label = %ResourceInfoLabel
@onready var _collect_button: Button = %CollectButton
@onready var _building_section: VBoxContainer = %BuildingSection
@onready var _building_info_label: Label = %BuildingInfoLabel
@onready var _building_action_flow: HFlowContainer = get_node_or_null("ContentMargin/VBoxContainer/BuildingSection/BuildingActionFlow") as HFlowContainer
@onready var _repair_button: Button = %RepairButton
@onready var _demolish_button: Button = %DemolishButton
@onready var _toggle_button: Button = %ToggleButton
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	visible = false
	_bind_buttons()
	_bind_events()
	var run_state = AppRefs.run_state()
	if run_state != null:
		_current_phase = int(run_state.phase)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_clear_building_range_preview()


func _bind_buttons() -> void:
	_trigger_event_button.pressed.connect(_on_trigger_event_pressed)
	_collect_button.pressed.connect(_on_collect_pressed)
	_repair_button.pressed.connect(_on_repair_pressed)
	_demolish_button.pressed.connect(_on_demolish_pressed)
	_toggle_button.pressed.connect(_on_toggle_pressed)


func _bind_events() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	event_bus.map_cell_clicked.connect(_on_map_cell_clicked)
	event_bus.phase_changed.connect(_on_phase_changed)
	event_bus.day_started.connect(_on_day_started)
	event_bus.action_points_changed.connect(_on_action_points_changed)
	event_bus.materials_changed.connect(_on_materials_changed)
	event_bus.building_destroyed.connect(_on_building_changed)
	event_bus.building_state_changed.connect(_on_building_state_changed)
	event_bus.resource_collected.connect(_on_resource_collected)


func _on_map_cell_clicked(cell: Vector2i) -> void:
	if _current_phase != GameEnums.PHASE_DAY or not _is_idle_action_mode():
		hide()
		return
	_current_cell = cell
	_message_label.text = ""
	if not _refresh_content():
		hide()
		return
	_show_near_mouse()


func _refresh_content() -> bool:
	var map_manager := _get_map_manager()
	if map_manager == null or not map_manager.has_method("get_cell_data"):
		return false
	if not map_manager.is_inside(_current_cell) or not map_manager.is_discovered(_current_cell):
		return false
	var data: CellData = map_manager.get_cell_data(_current_cell)
	if data == null:
		return false
	var building := _get_building_by_cell(_current_cell)
	var has_event := _has_event_at_cell(_current_cell)
	var has_resource := data.resource_type != StringName()
	var has_building := building != null
	if not has_event and not has_resource and not has_building:
		_clear_building_range_preview()
		return false
	_title_label.text = _make_title(data, building)
	_refresh_event_section(_current_cell)
	_refresh_resource_section(data)
	_refresh_building_section(building)
	_refresh_building_range_preview(building)
	return true


func _refresh_event_section(cell: Vector2i) -> void:
	var event_cfg := _get_event_cfg_at_cell(cell)
	var has_event := not event_cfg.is_empty()
	_event_section.visible = has_event
	if not has_event:
		return
	var run_state = AppRefs.run_state()
	var enough_ap: bool = run_state != null and int(run_state.action_points) >= EVENT_TRIGGER_AP_COST
	var event_name := String(event_cfg.get("name", event_cfg.get("id", "Event")))
	var event_desc := String(event_cfg.get("desc", ""))
	_event_info_label.text = "%s\n%s\n消耗行动力：%d" % [event_name, event_desc, EVENT_TRIGGER_AP_COST]
	_trigger_event_button.disabled = _current_phase != GameEnums.PHASE_DAY or not enough_ap
	_style_button(_trigger_event_button, GameUiStyle.ACCENT)


func _refresh_resource_section(data: CellData) -> void:
	var has_resource := data != null and data.resource_type != StringName()
	_resource_section.visible = has_resource
	if not has_resource:
		return
	var day_manager := _get_day_manager()
	var run_state = AppRefs.run_state()
	var collected: bool = day_manager != null and day_manager.has_method("is_resource_collected_today") and day_manager.is_resource_collected_today(_current_cell)
	var enough_ap: bool = run_state != null and int(run_state.action_points) >= RESOURCE_COLLECT_AP_COST
	_resource_info_label.text = "%s资源点\n手动采集：行动力 %d，获得 %d %s\n%s" % [
		_resource_display_name(data.resource_type),
		RESOURCE_COLLECT_AP_COST,
		RESOURCE_COLLECT_AMOUNT,
		_resource_unit_name(data.resource_type),
		"今日已采集" if collected else "今日未采集"
	]
	_collect_button.disabled = _current_phase != GameEnums.PHASE_DAY or collected or not enough_ap
	_style_button(_collect_button, GameUiStyle.SUCCESS)


func _refresh_building_section(building: Node) -> void:
	_building_section.visible = building != null
	if building == null:
		return
	var is_destroyed := _is_building_destroyed(building)
	var can_demolish := _can_demolish_building(building)
	var can_toggle: bool = building.has_method("can_toggle_enabled") and building.can_toggle_enabled() and not is_destroyed
	_building_info_label.text = _format_building_info(building)
	_repair_button.visible = is_destroyed
	_demolish_button.visible = can_demolish
	_toggle_button.visible = can_toggle
	_repair_button.disabled = _current_phase != GameEnums.PHASE_DAY
	_demolish_button.disabled = _current_phase != GameEnums.PHASE_DAY
	_toggle_button.disabled = _current_phase != GameEnums.PHASE_DAY
	if _building_action_flow != null:
		_building_action_flow.visible = _repair_button.visible or _demolish_button.visible or _toggle_button.visible
	_style_button(_repair_button, GameUiStyle.AMBER)
	_style_button(_demolish_button, GameUiStyle.DANGER)
	_style_button(_toggle_button, GameUiStyle.ACCENT)


func _make_title(data: CellData, building: Node) -> String:
	if building != null:
		return String(building.cfg.get("name", building.building_id))
	if _has_event_at_cell(_current_cell):
		return "随机事件"
	if data != null and data.resource_type != StringName():
		return "%s资源点" % _resource_display_name(data.resource_type)
	return "地图对象"


func _show_near_mouse() -> void:
	visible = true
	_fit_to_content()
	await get_tree().process_frame
	_fit_to_content()
	var viewport_size := get_viewport_rect().size
	var desired := get_viewport().get_mouse_position() + POPUP_OFFSET
	desired.x = clamp(desired.x, 8.0, max(8.0, viewport_size.x - size.x - 8.0))
	desired.y = clamp(desired.y, 8.0, max(8.0, viewport_size.y - size.y - 8.0))
	position = desired


func _fit_to_content() -> void:
	var fit_size := get_combined_minimum_size()
	fit_size.x = max(fit_size.x, POPUP_MIN_WIDTH)
	size = fit_size


func _on_trigger_event_pressed() -> void:
	var day_manager := _get_day_manager()
	if day_manager == null or not day_manager.has_method("try_trigger_event"):
		return
	var result: Dictionary = day_manager.try_trigger_event(_current_cell)
	_message_label.text = _format_event_result(result)
	if result.get("ok", false):
		_title_label.text = "事件已处理"
		_event_section.visible = false
		_fit_to_content()
	else:
		_refresh_or_hide()


func _on_collect_pressed() -> void:
	var day_manager := _get_day_manager()
	if day_manager == null or not day_manager.has_method("try_collect_resource"):
		return
	var result: Dictionary = day_manager.try_collect_resource(_current_cell)
	_message_label.text = String(result.get("message", ""))
	if not result.get("ok", false) and _message_label.text.is_empty():
		_message_label.text = "采集失败"
	_refresh_or_hide()


func _on_repair_pressed() -> void:
	var building := _get_building_by_cell(_current_cell)
	var building_manager := _get_building_manager()
	if building == null or building_manager == null or not building_manager.has_method("try_repair_building"):
		return
	var result: Dictionary = building_manager.try_repair_building(int(building.get_runtime_id()))
	_message_label.text = String(result.get("message", ""))
	if not result.get("ok", false) and _message_label.text.is_empty():
		_message_label.text = "修复失败"
	_refresh_or_hide()


func _on_demolish_pressed() -> void:
	var building := _get_building_by_cell(_current_cell)
	var building_manager := _get_building_manager()
	if building == null or building_manager == null or not building_manager.has_method("try_demolish_building"):
		return
	var result: Dictionary = building_manager.try_demolish_building(int(building.get_runtime_id()))
	_message_label.text = String(result.get("message", ""))
	if not result.get("ok", false) and _message_label.text.is_empty():
		_message_label.text = "拆除失败"
	_refresh_or_hide()


func _on_toggle_pressed() -> void:
	var building := _get_building_by_cell(_current_cell)
	var building_manager := _get_building_manager()
	if building == null or building_manager == null or not building_manager.has_method("try_toggle_building"):
		return
	var result: Dictionary = building_manager.try_toggle_building(int(building.get_runtime_id()))
	_message_label.text = "已切换" if bool(result.get("ok", false)) else String(result.get("message", "开关失败"))
	_refresh_or_hide()


func _refresh_or_hide() -> void:
	if visible and not _refresh_content():
		hide()


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	_current_phase = new_phase
	hide()


func _on_day_started(_day: int) -> void:
	_refresh_or_hide()


func _on_action_points_changed(_value: int) -> void:
	_refresh_or_hide()


func _on_materials_changed(_wood: int, _stone: int, _mana: int) -> void:
	_refresh_or_hide()


func _on_building_changed(_building_runtime_id: int, _building_id: StringName, cell: Vector2i) -> void:
	if cell == _current_cell:
		_refresh_or_hide()


func _on_building_state_changed(_building_runtime_id: int, _building_id: StringName, _enabled: bool) -> void:
	_refresh_or_hide()


func _on_resource_collected(cell: Vector2i, _resource_type: StringName, _amount: int) -> void:
	if cell == _current_cell:
		_refresh_or_hide()


func _format_building_info(building: Node) -> String:
	var state_text := "已毁" if _is_building_destroyed(building) else "运作中"
	var text := "%s#%d\nHP %d/%d  %s" % [
		String(building.cfg.get("name", building.building_id)),
		int(building.get_runtime_id()),
		int(building.current_hp),
		int(building.max_hp),
		state_text
	]
	if _is_building_destroyed(building):
		var cost := _get_destroyed_repair_cost(building)
		text += "\n修复：木%d 石%d 魔%d" % [
			int(cost.get("wood", 0)),
			int(cost.get("stone", 0)),
			int(cost.get("mana", 0))
		]
	elif building.has_method("can_toggle_enabled") and building.can_toggle_enabled():
		text += "\n状态：%s" % ("开启" if building.is_enabled() else "关闭")
	return text


func _format_event_result(result: Dictionary) -> String:
	if not result.get("ok", false):
		return String(result.get("message", "事件处理失败"))
	var payload: Dictionary = result.get("payload", {})
	var event_id := StringName(payload.get("event_id", ""))
	var event_name := _event_display_name(event_id)
	return "%s已处理（-%d 行动力）" % [event_name, int(payload.get("ap_cost", EVENT_TRIGGER_AP_COST))]


func _event_display_name(event_id: StringName) -> String:
	var data_repo = AppRefs.data_repo()
	if data_repo != null and data_repo.has_method("get_event_cfg"):
		var cfg: Dictionary = data_repo.get_event_cfg(event_id)
		if not cfg.is_empty():
			return String(cfg.get("name", event_id))
	return String(event_id)


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


func _resource_display_name(resource_type: StringName) -> String:
	match resource_type:
		&"wood":
			return "木材"
		&"stone":
			return "石材"
		&"mana":
			return "魔力"
	return "未知"


func _resource_unit_name(resource_type: StringName) -> String:
	match resource_type:
		&"wood":
			return "木材"
		&"stone":
			return "石材"
		&"mana":
			return "魔力矿"
	return "资源"


func _is_idle_action_mode() -> bool:
	var action_panel := get_node_or_null("../ActionPanel")
	if action_panel == null or not action_panel.has_method("get_current_mode"):
		return true
	return StringName(action_panel.get_current_mode()) == &"idle"


func _get_map_manager() -> Node:
	return get_node_or_null("../../Managers/MapManager")


func _get_day_manager() -> Node:
	return get_node_or_null("../../Managers/DayManager")


func _get_building_manager() -> Node:
	return get_node_or_null("../../Managers/BuildingManager")


func _get_random_event_manager() -> Node:
	return get_node_or_null("../../Managers/RandomEventManager")


func _has_event_at_cell(cell: Vector2i) -> bool:
	var random_event_manager := _get_random_event_manager()
	return random_event_manager != null and random_event_manager.has_method("has_event_at_cell") and random_event_manager.has_event_at_cell(cell)


func _get_event_cfg_at_cell(cell: Vector2i) -> Dictionary:
	var random_event_manager := _get_random_event_manager()
	if random_event_manager == null or not random_event_manager.has_method("get_event_cfg_at_cell"):
		return {}
	return random_event_manager.get_event_cfg_at_cell(cell)


func _get_building_by_cell(cell: Vector2i) -> Node:
	var building_manager := _get_building_manager()
	if building_manager == null or not building_manager.has_method("get_building_by_cell"):
		return null
	var building = building_manager.get_building_by_cell(cell)
	return building if building != null and is_instance_valid(building) else null


func _refresh_building_range_preview(building: Node) -> void:
	if building == null or not is_instance_valid(building):
		_clear_building_range_preview()
		return
	var radius := int(building.cfg.get("effect_radius", 0))
	if radius <= 0:
		_clear_building_range_preview()
		return
	var map_manager := _get_map_manager()
	var map_root := get_node_or_null("../../World/MapRoot")
	if map_manager == null or map_root == null or not map_root.has_method("set_building_effect_range"):
		return
	map_root.set_building_effect_range(_get_square_range_cells(building.get_current_cell(), radius))


func _clear_building_range_preview() -> void:
	var map_root := get_node_or_null("../../World/MapRoot")
	if map_root != null and map_root.has_method("clear_building_effect_range"):
		map_root.clear_building_effect_range()


func _get_square_range_cells(center: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var map_manager := _get_map_manager()
	if map_manager == null:
		return cells
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if map_manager.is_inside(cell):
				cells.append(cell)
	return cells


func _apply_visual_style() -> void:
	add_theme_stylebox_override("panel", GameUiStyle.panel(GameUiStyle.BG_DARK, GameUiStyle.STROKE_STRONG, 1.0, 6.0))
	custom_minimum_size = Vector2(POPUP_MIN_WIDTH, 0.0)
	if _title_label != null:
		_title_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	if _event_info_label != null:
		_event_info_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	if _resource_info_label != null:
		_resource_info_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	if _building_info_label != null:
		_building_info_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	if _message_label != null:
		_message_label.add_theme_color_override("font_color", GameUiStyle.AMBER)


func _style_button(button: Button, accent: Color) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", GameUiStyle.button(accent, 0.18))
	button.add_theme_stylebox_override("hover", GameUiStyle.button(accent, 0.28))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.32))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.10))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)
