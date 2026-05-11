extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

const DRAG_NONE := &"none"
const DRAG_CARD := &"drag_card"
const DRAG_LOCKED := &"locked"
const DRAG_FACING := &"facing"
const INVALID_CELL := Vector2i(-9999, -9999)
const PREVIEW_WARNING_STATUSES: Array[StringName] = [&"no_path", &"path_too_short", &"core_enclosed"]
const ROUTE_LABEL_ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const RESOURCE_DISPLAY_NAMES := {
	&"ap": "行动力",
	&"prestige": "声望",
	&"wood": "木材",
	&"stone": "石头",
	&"mana": "魔力矿"
}
const MATERIAL_RESOURCE_KEYS: Array[StringName] = [&"wood", &"stone", &"mana"]

var _operator_defs: Array[Dictionary] = []
var _selected_unit_runtime_id := -1
var _selected_operator_key := StringName()
var _selected_shop_slot_index := -1
var _selected_shop_unit_id := StringName()
var _selected_shop_price := 0
var _selected_shop_can_purchase := false
var _selected_shop_disabled_reason := ""
var _deploy_drag_state: StringName = DRAG_NONE
var _drag_operator_key := StringName()
var _locked_deploy_cell := INVALID_CELL
var _current_drag_cell := INVALID_CELL
var _current_drag_cell_valid := false
var _current_drag_facing := Vector2i.RIGHT
var _cooldown_message_operator_key := StringName()
var _last_wave_preview_signature := ""
var _wave_preview_active := false
var _show_wave_routes: bool = false
var _latest_wave_routes: Array[Dictionary] = []
var _latest_wave_preview_text := ""
var _wave_route_revision := 0
var _wave_preview_refresh_queued := false

@export_node_path("Control") var combat_hud_path: NodePath = ^"../ScreenLayout/CombatHudSlot/CombatHud"
@export_node_path("Control") var action_panel_path: NodePath = ^"../ScreenLayout/ActionPanelSlot/ActionPanel"
@export_node_path("Control") var build_panel_path: NodePath = ^"../ScreenLayout/BuildPanelSlot/BuildPanel"

@onready var _combat_hud: Control = get_node_or_null(combat_hud_path) as Control
@onready var _action_panel: Control = get_node_or_null(action_panel_path) as Control
@onready var _build_panel: Control = get_node_or_null(build_panel_path) as Control
@onready var _map_root: Node = get_node_or_null("../../World/MapRoot")
@onready var _map_manager: Node = get_node_or_null("../../Managers/MapManager")
@onready var _path_service: Node = get_node_or_null("../../Managers/PathService")
@onready var _wave_manager: Node = get_node_or_null("../../Managers/WaveManager")
@onready var _unit_manager: Node = get_node_or_null("../../Managers/UnitManager")
@onready var _enemy_manager: Node = get_node_or_null("../../Managers/EnemyManager")
@onready var _building_manager: Node = get_node_or_null("../../Managers/BuildingManager")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_pause_boundaries()
	set_process(true)
	set_process_unhandled_input(true)
	_bind_combat_hud()
	_connect_events()
	call_deferred("_bootstrap_hud")


func _process(_delta: float) -> void:
	_update_deploy_drag()
	_update_operator_cards()
	_refresh_top_hud()
	_refresh_detail_panel()
	_refresh_wave_preview()
	if _selected_unit_runtime_id >= 0:
		_refresh_attack_range_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _combat_hud != null and _combat_hud.has_method("close_top_panel") and _combat_hud.close_top_panel():
				return
			_cancel_deploy_flow("已取消")
			return
		if event.keycode == KEY_R:
			if _combat_hud != null and _combat_hud.has_method("toggle_relic_panel"):
				_combat_hud.toggle_relic_panel()
				return
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed and _deploy_drag_state != DRAG_NONE:
			_cancel_deploy_flow("已取消")
			return
		if _deploy_drag_state == DRAG_LOCKED and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _get_mouse_cell() == _locked_deploy_cell:
				_deploy_drag_state = DRAG_FACING
				_current_drag_facing = Vector2i.RIGHT
				_show_message("拖拽选择朝向")
				return

func _configure_pause_boundaries() -> void:
	var game_root := get_node_or_null("../..")
	if game_root == null:
		return
	var world := game_root.get_node_or_null("World")
	if world != null:
		world.process_mode = Node.PROCESS_MODE_PAUSABLE
		var map_root := world.get_node_or_null("MapRoot")
		if map_root != null:
			map_root.process_mode = Node.PROCESS_MODE_ALWAYS
	var managers := game_root.get_node_or_null("Managers")
	if managers != null:
		managers.process_mode = Node.PROCESS_MODE_PAUSABLE
	var ui := game_root.get_node_or_null("UI")
	if ui != null:
		ui.process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
	Engine.time_scale = 1.0


func _bind_combat_hud() -> void:
	if _combat_hud == null:
		push_warning("CombatHud node is missing from Game UI.")
		return
	if _combat_hud.has_signal("operator_card_pressed"):
		_combat_hud.connect(&"operator_card_pressed", Callable(self, "_on_operator_card_pressed"))
	if _combat_hud.has_signal("operator_card_drag_started"):
		_combat_hud.connect(&"operator_card_drag_started", Callable(self, "_on_operator_card_drag_started"))
	if _combat_hud.has_signal("pause_pressed"):
		_combat_hud.connect(&"pause_pressed", Callable(self, "_on_pause_pressed"))
	if _combat_hud.has_signal("speed_1_pressed"):
		_combat_hud.connect(&"speed_1_pressed", Callable(self, "_on_speed_1_pressed"))
	if _combat_hud.has_signal("speed_2_pressed"):
		_combat_hud.connect(&"speed_2_pressed", Callable(self, "_on_speed_2_pressed"))
	if _combat_hud.has_signal("cast_skill_requested"):
		_combat_hud.connect(&"cast_skill_requested", Callable(self, "_on_cast_skill_pressed"))
	if _combat_hud.has_signal("retreat_requested"):
		_combat_hud.connect(&"retreat_requested", Callable(self, "_on_retreat_pressed"))
	if _combat_hud.has_signal("wave_route_preview_toggled"):
		_combat_hud.connect(&"wave_route_preview_toggled", Callable(self, "_on_wave_route_preview_toggled"))
	if _combat_hud.has_signal("shop_unit_purchase_requested"):
		_combat_hud.connect(&"shop_unit_purchase_requested", Callable(self, "_on_shop_unit_purchase_requested"))
	if _combat_hud.has_method("set_wave_route_preview_enabled"):
		_combat_hud.set_wave_route_preview_enabled(_show_wave_routes)
	if _build_panel != null and _build_panel.has_signal("shop_unit_preview_requested"):
		_build_panel.connect(&"shop_unit_preview_requested", Callable(self, "_on_shop_unit_preview_requested"))


func _connect_events() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.owned_operators_changed.connect(_on_owned_operators_changed)
		event_bus.deploy_limit_changed.connect(_on_deploy_limit_changed)
		event_bus.core_hp_changed.connect(_on_core_hp_changed)
		event_bus.action_points_changed.connect(_on_action_points_changed)
		event_bus.prestige_changed.connect(_on_prestige_changed)
		event_bus.materials_changed.connect(_on_materials_changed)
		event_bus.buffs_changed.connect(_on_buffs_changed)
		event_bus.phase_changed.connect(_on_phase_changed)
		event_bus.day_started.connect(_on_day_started)
		event_bus.night_started.connect(_on_night_started)
		event_bus.unit_deployed.connect(_on_unit_deployed)
		event_bus.unit_removed.connect(_on_unit_removed)
		event_bus.map_cell_clicked.connect(_on_map_cell_clicked)
		event_bus.path_grid_changed.connect(_on_path_grid_changed)
		event_bus.building_placed.connect(_on_building_changed)
		event_bus.building_destroyed.connect(_on_building_changed)
		event_bus.building_state_changed.connect(_on_building_state_changed)
		event_bus.build_action_result.connect(_on_build_action_result)
	if _unit_manager != null and _unit_manager.has_signal("operator_redeploy_completed"):
		_unit_manager.connect(&"operator_redeploy_completed", Callable(self, "_on_operator_redeploy_completed"))


func _bootstrap_hud() -> void:
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_owned_operators"):
		_on_owned_operators_changed(run_state.get_owned_operators())
	if run_state != null and run_state.has_method("get_all_buffs"):
		_on_buffs_changed(run_state.get_all_buffs())
	_refresh_top_hud()
	_refresh_time_controls()
	_show_message("拖拽底部干员卡开始部署")
	_force_wave_preview_refresh()


func _on_owned_operators_changed(operators: Array[Dictionary]) -> void:
	_operator_defs.clear()
	for operator_info in operators:
		_operator_defs.append((operator_info as Dictionary).duplicate(true))
	if _combat_hud != null and _combat_hud.has_method("set_operators"):
		_combat_hud.set_operators(_operator_defs)
	_update_operator_cards()


func _on_deploy_limit_changed(_current: int, _max_value: int) -> void:
	_refresh_top_hud()
	_update_operator_cards()


func _on_core_hp_changed(_current: int, _max_value: int) -> void:
	_refresh_top_hud()


func _on_action_points_changed(_value: int) -> void:
	_refresh_top_hud()


func _on_prestige_changed(_value: int) -> void:
	_refresh_top_hud()


func _on_materials_changed(_wood: int, _stone: int, _mana: int) -> void:
	_refresh_top_hud()


func _on_buffs_changed(buff_ids: Array[StringName]) -> void:
	if _combat_hud != null and _combat_hud.has_method("set_relics"):
		_combat_hud.set_relics(buff_ids)
	_refresh_top_hud()


func _on_phase_changed(_old_phase: int, _new_phase: int) -> void:
	_cancel_deploy_flow("")
	if _new_phase != GameEnums.PHASE_NIGHT:
		get_tree().paused = false
		Engine.time_scale = 1.0
	if _new_phase != GameEnums.PHASE_DAY and _selected_shop_slot_index >= 0:
		_clear_detail_selection()
	_refresh_top_hud()
	_refresh_time_controls()
	_update_operator_cards()
	_force_wave_preview_refresh()


func _on_day_started(_day: int) -> void:
	_refresh_top_hud()
	_force_wave_preview_refresh()


func _on_night_started(_day: int) -> void:
	_refresh_top_hud()


func _on_operator_card_pressed(operator_key: StringName) -> void:
	var state := _get_operator_state(operator_key)
	if state == &"deployed":
		var deployed_unit = _unit_manager.get_unit_by_operator_key(operator_key) if _unit_manager != null and _unit_manager.has_method("get_unit_by_operator_key") else null
		if deployed_unit != null:
			_select_unit(deployed_unit)
	else:
		_show_operator_preview(operator_key)
		if state == &"cooldown":
			_show_message("干员正在再部署冷却中", operator_key)
	return


func _on_operator_card_drag_started(operator_key: StringName) -> void:
	var state := _get_operator_state(operator_key)
	if state == &"deployed":
		var deployed_unit = _unit_manager.get_unit_by_operator_key(operator_key) if _unit_manager != null and _unit_manager.has_method("get_unit_by_operator_key") else null
		if deployed_unit != null:
			_select_unit(deployed_unit)
		return
	if state != &"ready":
		_show_operator_preview(operator_key)
		_show_message("干员正在再部署冷却中", operator_key)
		return
	if not _can_deploy_now():
		_show_operator_preview(operator_key)
		_show_message("当前阶段不能部署干员")
		return
	_begin_operator_drag(operator_key)


func _begin_operator_drag(operator_key: StringName) -> void:
	_cancel_deploy_flow("")
	_clear_selected_unit()
	_clear_shop_preview_selection()
	_drag_operator_key = operator_key
	_selected_operator_key = operator_key
	_deploy_drag_state = DRAG_CARD
	_current_drag_cell = INVALID_CELL
	_current_drag_cell_valid = false
	if _action_panel != null and _action_panel.has_method("clear_mode"):
		_action_panel.clear_mode()
	if _combat_hud != null and _combat_hud.has_method("show_drag_ghost"):
		_combat_hud.show_drag_ghost(_format_operator_drag_text(operator_key))
	_show_message("拖拽到可部署格后松手锁定落点")


func _update_deploy_drag() -> void:
	match _deploy_drag_state:
		DRAG_CARD:
			_update_drag_ghost_position()
			_update_card_drag_preview()
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				if _current_drag_cell_valid:
					_lock_deploy_cell(_current_drag_cell)
				else:
					_cancel_deploy_flow("部署位置无效", true)
		DRAG_FACING:
			_current_drag_facing = _get_facing_from_mouse(_locked_deploy_cell)
			_update_locked_deploy_preview(_current_drag_facing)
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_confirm_locked_deploy()


func _update_card_drag_preview() -> void:
	var cell := _get_mouse_cell()
	_current_drag_cell = cell
	var validation := _validate_drag_cell(_drag_operator_key, cell)
	_current_drag_cell_valid = bool(validation.get("ok", false))
	var preview_range: Array[Vector2i] = []
	if _current_drag_cell_valid:
		preview_range = _get_operator_attack_range_cells(_drag_operator_key, cell, Vector2i.RIGHT)
	if _map_root != null and _map_root.has_method("set_deploy_preview"):
		_map_root.set_deploy_preview(cell, _current_drag_cell_valid, preview_range, _get_operator_visual_key(_drag_operator_key))


func _lock_deploy_cell(cell: Vector2i) -> void:
	_deploy_drag_state = DRAG_LOCKED
	_locked_deploy_cell = cell
	_current_drag_facing = Vector2i.RIGHT
	if _combat_hud != null and _combat_hud.has_method("hide_drag_ghost"):
		_combat_hud.hide_drag_ghost()
	_update_locked_deploy_preview(_current_drag_facing)
	_show_message("从锁定格向外拖拽选择朝向")


func _update_locked_deploy_preview(facing: Vector2i) -> void:
	var preview_range := _get_operator_attack_range_cells(_drag_operator_key, _locked_deploy_cell, facing)
	if _map_root != null and _map_root.has_method("set_deploy_direction_preview"):
		_map_root.set_deploy_direction_preview(_locked_deploy_cell, facing, preview_range, _get_operator_visual_key(_drag_operator_key))


func _confirm_locked_deploy() -> void:
	if _unit_manager == null or not _unit_manager.has_method("try_deploy_operator"):
		_cancel_deploy_flow("部署失败：单位管理器不可用", true)
		return
	var result: Dictionary = _unit_manager.try_deploy_operator(_drag_operator_key, _locked_deploy_cell, _current_drag_facing)
	if result.get("ok", false):
		var runtime_id := int(result.get("payload", {}).get("runtime_id", -1))
		var unit = _unit_manager.get_unit_by_runtime_id(runtime_id) if _unit_manager.has_method("get_unit_by_runtime_id") else null
		_cancel_deploy_flow("")
		if unit != null:
			_select_unit(unit)
		_show_message("部署完成")
	else:
		_cancel_deploy_flow(String(result.get("message", "部署失败")), true)


func _cancel_deploy_flow(message: String = "", warning := false) -> void:
	_deploy_drag_state = DRAG_NONE
	_drag_operator_key = StringName()
	_locked_deploy_cell = INVALID_CELL
	_current_drag_cell = INVALID_CELL
	_current_drag_cell_valid = false
	if _combat_hud != null and _combat_hud.has_method("hide_drag_ghost"):
		_combat_hud.hide_drag_ghost()
	_clear_deploy_preview()
	if not message.is_empty():
		_show_message(message, StringName(), warning)


func _clear_deploy_preview() -> void:
	if _map_root != null and _map_root.has_method("clear_deploy_preview"):
		_map_root.clear_deploy_preview()


func _update_drag_ghost_position() -> void:
	if _combat_hud != null and _combat_hud.has_method("move_drag_ghost"):
		_combat_hud.move_drag_ghost(get_viewport().get_mouse_position())


func _on_map_cell_clicked(cell: Vector2i) -> void:
	if _deploy_drag_state != DRAG_NONE:
		return
	var unit = _unit_manager.get_unit_by_cell(cell) if _unit_manager != null and _unit_manager.has_method("get_unit_by_cell") else null
	if unit != null:
		_select_unit(unit)
	else:
		_clear_detail_selection()


func _select_unit(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	_cancel_deploy_flow("")
	_clear_shop_preview_selection()
	_selected_unit_runtime_id = int(unit.get_runtime_id()) if unit.has_method("get_runtime_id") else -1
	_selected_operator_key = StringName(unit.operator_key) if unit.get("operator_key") != null else StringName()
	_refresh_attack_range_preview()
	_refresh_detail_panel()
	_show_message("已选中 %s#%d" % [_get_unit_display_name(unit), _selected_unit_runtime_id])


func _clear_selected_unit() -> void:
	_selected_unit_runtime_id = -1
	_clear_attack_range_preview()


func _refresh_detail_panel() -> void:
	var unit := _get_selected_unit()
	if _combat_hud == null:
		return
	if unit != null:
		if _combat_hud.has_method("show_unit_detail"):
			_combat_hud.show_unit_detail(unit, _get_unit_display_name(unit), UiDisplayText.damage_type_label(int(unit.damage_type)), UiDisplayText.direction_label(unit.facing))
		return
	if _selected_shop_slot_index >= 0:
		_refresh_shop_unit_preview()
		return
	if _selected_operator_key != StringName():
		_refresh_owned_operator_preview()
		return
	if _combat_hud.has_method("clear_unit_detail"):
		_combat_hud.clear_unit_detail()


func _show_operator_preview(operator_key: StringName) -> void:
	_cancel_deploy_flow("")
	_selected_unit_runtime_id = -1
	_selected_operator_key = operator_key
	_clear_shop_preview_selection()
	_clear_attack_range_preview()
	_refresh_detail_panel()


func _refresh_owned_operator_preview() -> void:
	var operator_info := _get_operator_info(_selected_operator_key)
	if operator_info.is_empty():
		_clear_detail_selection()
		return
	var state := _get_operator_state(_selected_operator_key)
	if state == &"deployed":
		var deployed_unit = _unit_manager.get_unit_by_operator_key(_selected_operator_key) if _unit_manager != null and _unit_manager.has_method("get_unit_by_operator_key") else null
		if deployed_unit != null:
			_selected_unit_runtime_id = int(deployed_unit.get_runtime_id()) if deployed_unit.has_method("get_runtime_id") else -1
			_refresh_detail_panel()
		return
	var unit_id := StringName(operator_info.get("unit_id", ""))
	var status_text := ""
	if state == &"cooldown" and _unit_manager != null and _unit_manager.has_method("get_operator_redeploy_remaining"):
		status_text = "%.1fs" % float(_unit_manager.get_operator_redeploy_remaining(_selected_operator_key))
	if _combat_hud.has_method("show_operator_preview"):
		_combat_hud.show_operator_preview(operator_info, _get_unit_cfg(unit_id), state, status_text)


func _refresh_shop_unit_preview() -> void:
	if _selected_shop_unit_id == StringName():
		_clear_detail_selection()
		return
	if _combat_hud != null and _combat_hud.has_method("show_shop_unit_preview"):
		_combat_hud.show_shop_unit_preview(
			_selected_shop_slot_index,
			_selected_shop_unit_id,
			_get_unit_cfg(_selected_shop_unit_id),
			_selected_shop_price,
			_selected_shop_can_purchase,
			_selected_shop_disabled_reason
		)


func _clear_shop_preview_selection() -> void:
	_selected_shop_slot_index = -1
	_selected_shop_unit_id = StringName()
	_selected_shop_price = 0
	_selected_shop_can_purchase = false
	_selected_shop_disabled_reason = ""


func _clear_detail_selection() -> void:
	_selected_unit_runtime_id = -1
	_selected_operator_key = StringName()
	_clear_shop_preview_selection()
	_clear_attack_range_preview()
	if _combat_hud != null and _combat_hud.has_method("clear_unit_detail"):
		_combat_hud.clear_unit_detail()


func _on_shop_unit_preview_requested(slot_index: int, unit_id: StringName, price: int, can_purchase: bool, disabled_reason: String) -> void:
	_cancel_deploy_flow("")
	_selected_unit_runtime_id = -1
	_selected_operator_key = StringName()
	_selected_shop_slot_index = slot_index
	_selected_shop_unit_id = unit_id
	_selected_shop_price = price
	_selected_shop_can_purchase = can_purchase
	_selected_shop_disabled_reason = disabled_reason
	_clear_attack_range_preview()
	_refresh_detail_panel()


func _on_shop_unit_purchase_requested(slot_index: int) -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_buy_shop_slot.emit(slot_index)


func _refresh_attack_range_preview() -> void:
	var unit := _get_selected_unit()
	if _map_root == null or not _map_root.has_method("set_debug_attack_range"):
		return
	if unit == null:
		_clear_attack_range_preview()
		return
	_map_root.set_debug_attack_range(_get_unit_attack_range_cells(unit))


func _clear_attack_range_preview() -> void:
	if _map_root != null and _map_root.has_method("clear_debug_attack_range"):
		_map_root.clear_debug_attack_range()


func _on_cast_skill_pressed() -> void:
	var unit := _get_selected_unit()
	if unit == null or _unit_manager == null:
		_show_message("未选中单位")
		return
	var result: Dictionary = _unit_manager.try_cast_skill(unit.get_runtime_id())
	_show_result_message(result, "技能已释放", "技能释放失败")
	_refresh_detail_panel()


func _on_retreat_pressed() -> void:
	var unit := _get_selected_unit()
	if unit == null or _unit_manager == null:
		_show_message("未选中单位")
		return
	var result: Dictionary = _unit_manager.try_retreat_unit(unit.get_runtime_id())
	if result.get("ok", false):
		_clear_selected_unit()
	_show_result_message(result, "已撤退", "撤退失败")


func _on_unit_deployed(unit_runtime_id: int, operator_key: StringName, _unit_id: StringName, _cell: Vector2i) -> void:
	_selected_operator_key = operator_key
	var unit = _unit_manager.get_unit_by_runtime_id(unit_runtime_id) if _unit_manager != null and _unit_manager.has_method("get_unit_by_runtime_id") else null
	if unit != null:
		_select_unit(unit)
	_update_operator_cards()


func _on_unit_removed(unit_runtime_id: int, _reason: int) -> void:
	if _selected_unit_runtime_id == unit_runtime_id:
		_clear_selected_unit()
		_refresh_detail_panel()
	_update_operator_cards()


func _on_path_grid_changed() -> void:
	_queue_wave_preview_refresh()


func _on_building_changed(_building_runtime_id: int, _building_id: StringName, _cell: Vector2i) -> void:
	_refresh_top_hud()
	_queue_wave_preview_refresh()


func _on_building_state_changed(_building_runtime_id: int, _building_id: StringName, _enabled: bool) -> void:
	_refresh_top_hud()
	_queue_wave_preview_refresh()


func _on_build_action_result(_building_id: StringName, _cell: Vector2i, result: Dictionary) -> void:
	if result.get("ok", false):
		return
	var message := String(result.get("message", "建造失败"))
	if not message.is_empty():
		_show_message(message, StringName(), true)


func _on_wave_route_preview_toggled(enabled: bool) -> void:
	_show_wave_routes = enabled
	_apply_wave_route_visibility()
	_force_wave_preview_refresh()


func _on_operator_redeploy_completed(operator_key: StringName) -> void:
	_update_operator_cards()
	if _cooldown_message_operator_key == operator_key:
		_show_message("%s 已可部署" % _get_operator_display_name(operator_key))


func _on_pause_pressed() -> void:
	if not _are_time_controls_enabled():
		return
	get_tree().paused = true
	_refresh_time_controls()


func _on_speed_1_pressed() -> void:
	if not _are_time_controls_enabled():
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	_refresh_time_controls()


func _on_speed_2_pressed() -> void:
	if not _are_time_controls_enabled():
		return
	get_tree().paused = false
	Engine.time_scale = 2.0
	_refresh_time_controls()


func _refresh_top_hud() -> void:
	if _combat_hud == null or not _combat_hud.has_method("set_top_values"):
		return
	var run_state = AppRefs.run_state()
	var core_text := "核心生命"
	var deploy_text := "部署上限\n0/0"
	var resource_text := "资源\n--"
	var resource_tooltip := ""
	var core_hp_current := 0
	var core_hp_max := 0
	var resource_items := _make_empty_resource_items()
	var phase_text := "准备"
	if run_state != null:
		core_hp_current = int(run_state.core_hp)
		core_hp_max = int(run_state.core_hp_max)
		core_text = "核心生命"
		deploy_text = "部署上限\n%d/%d" % [int(run_state.deployed_count), int(run_state.deploy_limit)]
		var buff_ids: Array[StringName] = run_state.get_all_buffs() if run_state.has_method("get_all_buffs") else []
		resource_text = "行动 %d/%d  声望 %d\n木 %d  石 %d  魔 %d  遗物 %d" % [
			int(run_state.action_points),
			int(run_state.DEFAULT_ACTION_POINTS),
			int(run_state.prestige),
			int(run_state.wood),
			int(run_state.stone),
			int(run_state.mana),
			buff_ids.size()
		]
		var material_delta := _get_projected_material_delta_to_next_day()
		resource_items = {
			&"ap": _make_resource_item(&"ap", "AP", str(int(run_state.action_points)), "行动力 %d/%d" % [int(run_state.action_points), int(run_state.DEFAULT_ACTION_POINTS)]),
			&"prestige": _make_resource_item(&"prestige", "P", str(int(run_state.prestige)), "声望"),
			&"wood": _make_resource_item(&"wood", "W", str(int(run_state.wood)), "木材", int(material_delta.get("wood", 0))),
			&"stone": _make_resource_item(&"stone", "S", str(int(run_state.stone)), "石头", int(material_delta.get("stone", 0))),
			&"mana": _make_resource_item(&"mana", "M", str(int(run_state.mana)), "魔力矿", int(material_delta.get("mana", 0)))
		}
		resource_tooltip = _format_resource_tooltip(buff_ids)
		phase_text = "Day %d %s" % [int(run_state.day), UiDisplayText.phase_label(int(run_state.phase))]
	var enemy_count: int = int(_enemy_manager.get_alive_enemy_count()) if _enemy_manager != null and _enemy_manager.has_method("get_alive_enemy_count") else 0
	_combat_hud.set_top_values(core_text, deploy_text, "当前阶段\n%s    敌人 %d" % [phase_text, enemy_count])
	if _combat_hud.has_method("set_core_hp"):
		_combat_hud.set_core_hp(core_hp_current, core_hp_max)
	if _combat_hud.has_method("set_resource_items"):
		_combat_hud.set_resource_items(resource_items, resource_tooltip)
	elif _combat_hud.has_method("set_resource_values"):
		_combat_hud.set_resource_values(resource_text, resource_tooltip)


func _make_empty_resource_items() -> Dictionary:
	return {
		&"ap": _make_resource_item(&"ap", "AP", "--", "行动力"),
		&"prestige": _make_resource_item(&"prestige", "P", "--", "声望"),
		&"wood": _make_resource_item(&"wood", "W", "--", "木材"),
		&"stone": _make_resource_item(&"stone", "S", "--", "石头"),
		&"mana": _make_resource_item(&"mana", "M", "--", "魔力矿")
	}


func _make_resource_item(resource_key: StringName, icon_text: String, value_text: String, tooltip_text: String, delta_value: int = 0) -> Dictionary:
	var item := {
		"icon": icon_text,
		"label": String(RESOURCE_DISPLAY_NAMES.get(resource_key, String(resource_key))),
		"value": value_text,
		"tooltip": tooltip_text
	}
	if MATERIAL_RESOURCE_KEYS.has(resource_key):
		var delta_text := _format_resource_delta(delta_value)
		if not delta_text.is_empty():
			item["delta"] = delta_text
			item["delta_sign"] = 1 if delta_value > 0 else -1
	return item


func _format_resource_delta(delta_value: int) -> String:
	if delta_value > 0:
		return "↑ %d" % delta_value
	if delta_value < 0:
		return "↓ %d" % absi(delta_value)
	return ""


func _get_projected_material_delta_to_next_day() -> Dictionary:
	if _building_manager != null and _building_manager.has_method("get_projected_material_delta_to_next_day"):
		return _building_manager.get_projected_material_delta_to_next_day()
	return {
		"wood": 0,
		"stone": 0,
		"mana": 0
	}


func _refresh_time_controls() -> void:
	if _combat_hud != null and _combat_hud.has_method("set_time_controls"):
		var enabled := _are_time_controls_enabled()
		_combat_hud.set_time_controls(get_tree().paused if enabled else false, Engine.time_scale, enabled)


func _refresh_wave_preview() -> void:
	var run_state = AppRefs.run_state()
	if run_state == null or int(run_state.phase) != GameEnums.PHASE_DAY:
		_clear_wave_preview()
		return
	if _wave_manager == null or _map_manager == null or _path_service == null:
		_last_wave_preview_signature = ""
		_clear_wave_routes()
		_set_wave_preview_text("今晚敌情\n地图或波次数据加载中...", true)
		return

	var preview: Dictionary = _wave_manager.get_wave_preview_for_day(int(run_state.day)) if _wave_manager.has_method("get_wave_preview_for_day") else {}
	if preview.is_empty():
		_last_wave_preview_signature = ""
		_set_wave_preview_text("今晚敌情\n暂无波次配置", true)
		_clear_wave_routes()
		return
	var hover_cell: Vector2i = _get_blocking_build_preview_cell()
	var signature: String = "%d|%s|%d|%d" % [int(run_state.day), str(hover_cell), int(preview.get("total_count", 0)), _wave_route_revision]
	if signature != _last_wave_preview_signature:
		_last_wave_preview_signature = signature
		var extra_blocked_cells: Dictionary = {}
		if hover_cell != INVALID_CELL:
			extra_blocked_cells[hover_cell] = true
		var routes: Array[Dictionary] = _build_wave_route_previews(preview, extra_blocked_cells)
		_set_wave_routes(routes)
	else:
		_apply_wave_route_visibility()
	_set_wave_preview_text(_format_wave_preview_text(preview, _latest_wave_routes, hover_cell), true)


func _force_wave_preview_refresh() -> void:
	_wave_preview_refresh_queued = false
	_wave_route_revision += 1
	_last_wave_preview_signature = ""
	_refresh_wave_preview()


func _queue_wave_preview_refresh() -> void:
	if _wave_preview_refresh_queued:
		return
	_wave_preview_refresh_queued = true
	call_deferred("_force_wave_preview_refresh")


func _clear_wave_preview() -> void:
	_wave_preview_active = false
	_last_wave_preview_signature = ""
	_latest_wave_preview_text = ""
	_set_wave_preview_text("", false)
	_clear_wave_routes()


func _set_wave_routes(routes: Array[Dictionary]) -> void:
	_latest_wave_routes.clear()
	for route: Dictionary in routes:
		_latest_wave_routes.append(route.duplicate(true))
	_apply_wave_route_visibility()


func _clear_wave_routes() -> void:
	_latest_wave_routes.clear()
	_apply_wave_route_visibility()


func _apply_wave_route_visibility() -> void:
	if _map_root != null and _map_root.has_method("set_wave_route_previews"):
		if _show_wave_routes:
			_map_root.set_wave_route_previews(_latest_wave_routes)
		elif _map_root.has_method("clear_wave_route_previews"):
			_map_root.clear_wave_route_previews()


func _set_wave_preview_text(text_value: String, show_panel: bool) -> void:
	_latest_wave_preview_text = text_value if show_panel else ""
	_wave_preview_active = show_panel and not text_value.strip_edges().is_empty()
	if _combat_hud != null and _combat_hud.has_method("set_wave_preview_text"):
		_combat_hud.set_wave_preview_text(text_value, show_panel)


func _build_wave_route_previews(preview: Dictionary, extra_blocked_cells: Dictionary) -> Array[Dictionary]:
	var routes_by_key: Dictionary = {}
	var entries: Array = preview.get("entries", [])
	for entry_variant: Variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var spawn_key := StringName(entry.get("spawn_key", ""))
		var path_mode := StringName(entry.get("path_mode", &"normal"))
		var route_key := "%s|%s" % [String(spawn_key), String(path_mode)]
		if routes_by_key.has(route_key):
			var existing: Dictionary = routes_by_key[route_key]
			existing["count"] = int(existing.get("count", 0)) + int(entry.get("count", 0))
			_add_enemy_to_route(existing, entry)
			continue
		var spawn_cell: Vector2i = _map_manager.get_spawn_cell_by_key(spawn_key)
		var core_cell: Vector2i = _map_manager.get_core_cell()
		var path_result: Dictionary = _path_service.find_path_preview(spawn_cell, core_cell, path_mode, extra_blocked_cells) if _path_service.has_method("find_path_preview") else {}
		var route := {
			"spawn_key": spawn_key,
			"spawn_cell": spawn_cell,
			"path_mode": path_mode,
			"effective_path_mode": StringName(path_result.get("effective_path_mode", path_mode)),
			"path": path_result.get("path", []),
			"ok": bool(path_result.get("ok", false)),
			"status": StringName(path_result.get("status", &"no_path")),
			"message": String(path_result.get("message", "")),
			"count": int(entry.get("count", 0)),
			"enemies": []
		}
		_add_enemy_to_route(route, entry)
		routes_by_key[route_key] = route
	var routes: Array[Dictionary] = []
	for route in routes_by_key.values():
		routes.append((route as Dictionary).duplicate(true))
	routes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var spawn_a := String(a.get("spawn_key", ""))
		var spawn_b := String(b.get("spawn_key", ""))
		if spawn_a == spawn_b:
			return String(a.get("path_mode", "")) < String(b.get("path_mode", ""))
		return spawn_a < spawn_b
	)
	for index in range(routes.size()):
		var route: Dictionary = routes[index]
		route["route_label"] = _route_label_for_index(index)
		route["route_summary"] = _format_route_enemy_summary(route)
		routes[index] = route
	return routes


func _add_enemy_to_route(route: Dictionary, entry: Dictionary) -> void:
	var enemy_id := StringName(entry.get("enemy_id", ""))
	var enemy_name := String(entry.get("enemy_name", entry.get("enemy_id", "")))
	var count := int(entry.get("count", 0))
	if enemy_id == StringName() or count <= 0:
		return
	var enemies: Array = route.get("enemies", [])
	for index in range(enemies.size()):
		var enemy_variant: Variant = enemies[index]
		if typeof(enemy_variant) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_variant
		if StringName(enemy.get("enemy_id", "")) != enemy_id:
			continue
		enemy["count"] = int(enemy.get("count", 0)) + count
		enemies[index] = enemy
		route["enemies"] = enemies
		return
	enemies.append({
		"enemy_id": enemy_id,
		"enemy_name": enemy_name,
		"count": count
	})
	route["enemies"] = enemies


func _route_label_for_index(index: int) -> String:
	if index >= 0 and index < ROUTE_LABEL_ALPHABET.length():
		return ROUTE_LABEL_ALPHABET.substr(index, 1)
	return str(index + 1)


func _format_route_enemy_summary(route: Dictionary) -> String:
	var enemies: Array = route.get("enemies", [])
	var parts := PackedStringArray()
	for enemy_variant: Variant in enemies:
		if typeof(enemy_variant) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_variant
		var enemy_name := String(enemy.get("enemy_name", enemy.get("enemy_id", "")))
		var count := int(enemy.get("count", 0))
		if enemy_name.is_empty() or count <= 0:
			continue
		parts.append("%sx%d" % [enemy_name, count])
	return "、".join(parts)


func _format_wave_preview_text(preview: Dictionary, routes: Array[Dictionary], hover_cell: Vector2i) -> String:
	var lines := PackedStringArray()
	lines.append("Day %d  合计 %d" % [int(preview.get("day", 0)), int(preview.get("total_count", 0))])
	var enemy_counts: Dictionary = {}
	var entries: Array = preview.get("entries", [])
	for entry_variant: Variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var enemy_name := String(entry.get("enemy_name", entry.get("enemy_id", "")))
		enemy_counts[enemy_name] = int(enemy_counts.get(enemy_name, 0)) + int(entry.get("count", 0))
	if not enemy_counts.is_empty():
		var enemy_lines := PackedStringArray()
		for enemy_name in enemy_counts.keys():
			enemy_lines.append("%s x%d" % [String(enemy_name), int(enemy_counts.get(enemy_name, 0))])
		lines.append("敌群: %s" % "、".join(enemy_lines))

	var warnings := _collect_route_warning_lines(routes)
	if hover_cell != INVALID_CELL:
		lines.append("预览阻挡: %s" % str(hover_cell))
	lines.append("路线预览: %s" % ("已开启" if _show_wave_routes else "关闭"))
	var route_lines := _collect_route_legend_lines(routes)
	if not route_lines.is_empty():
		lines.append("路线: %s" % "；".join(route_lines))
	if not warnings.is_empty():
		lines.append("警告: %s" % "；".join(warnings))
	return "\n".join(lines)


func _collect_route_legend_lines(routes: Array[Dictionary]) -> PackedStringArray:
	var lines := PackedStringArray()
	for route in routes:
		var route_label := String(route.get("route_label", "?"))
		var spawn_key := String(route.get("spawn_key", ""))
		var route_summary := String(route.get("route_summary", ""))
		if route_summary.is_empty():
			route_summary = "无敌人"
		lines.append("%s线 %s: %s" % [route_label, spawn_key, route_summary])
	return lines


func _collect_route_warning_lines(routes: Array[Dictionary]) -> PackedStringArray:
	var warnings := PackedStringArray()
	for route in routes:
		var status := StringName(route.get("status", &"ok"))
		if not PREVIEW_WARNING_STATUSES.has(status):
			continue
		var message := String(route.get("message", "路线异常"))
		var line := message
		if not warnings.has(line):
			warnings.append(line)
	return warnings


func _get_blocking_build_preview_cell() -> Vector2i:
	if _action_panel == null or _map_manager == null or _map_root == null:
		return INVALID_CELL
	if not _action_panel.has_method("get_current_mode") or _action_panel.get_current_mode() != &"build":
		return INVALID_CELL
	if not _action_panel.has_method("get_current_building_id"):
		return INVALID_CELL
	var building_id := StringName(_action_panel.get_current_building_id())
	if building_id == StringName():
		return INVALID_CELL
	var data_repo = AppRefs.data_repo()
	var building_cfg: Dictionary = data_repo.get_building_cfg(building_id) if data_repo != null else {}
	if not bool(building_cfg.get("blocks_path", false)):
		return INVALID_CELL
	var cell := _get_mouse_cell()
	if not _map_manager.is_inside(cell):
		return INVALID_CELL
	if not _map_manager.is_buildable(cell):
		return INVALID_CELL
	return cell


func _are_time_controls_enabled() -> bool:
	var run_state = AppRefs.run_state()
	return run_state != null and int(run_state.phase) == GameEnums.PHASE_NIGHT


func _update_operator_cards() -> void:
	if _combat_hud == null:
		return
	for operator_info in _operator_defs:
		var operator_key := StringName((operator_info as Dictionary).get("key", ""))
		var state := _get_operator_state(operator_key)
		_combat_hud.set_operator_card(operator_key, _format_operator_card_text(operator_info, state), state)


func _format_operator_card_text(operator_info: Dictionary, state: StringName) -> String:
	var operator_key := StringName(operator_info.get("key", ""))
	var unit_id := StringName(operator_info.get("unit_id", ""))
	var cfg := _get_unit_cfg(unit_id)
	var name := str(operator_info.get("name", cfg.get("name", operator_key)))
	var class_text := UiDisplayText.class_label(str(cfg.get("class", "")))
	var hp_text := "HP %d" % int(cfg.get("max_hp", 0))
	var sp_text := "SP 0/%d" % int(cfg.get("sp_max", 0))
	var cd_text := "CD READY"
	if state == &"deployed":
		var unit = _unit_manager.get_unit_by_operator_key(operator_key) if _unit_manager != null and _unit_manager.has_method("get_unit_by_operator_key") else null
		if unit != null:
			hp_text = "HP %d/%d" % [int(unit.current_hp), int(unit.max_hp)]
			sp_text = "SP %.0f/%.0f" % [float(unit.sp), float(unit.cfg.get("sp_max", 0.0))]
			cd_text = "CD 在场"
			var ammo_text := _format_unit_ammo_status(unit)
			if not ammo_text.is_empty():
				sp_text = "%s  %s" % [sp_text, ammo_text]
		else:
			cd_text = "CD 在场"
	elif state == &"cooldown":
		var remain := float(_unit_manager.get_operator_redeploy_remaining(operator_key)) if _unit_manager != null and _unit_manager.has_method("get_operator_redeploy_remaining") else 0.0
		hp_text = "HP --"
		sp_text = "SP --"
		cd_text = "CD %.1f秒" % remain
	elif not _can_deploy_now():
		cd_text = "CD 阶段限制"
	return "%s\n%s COST %s\n%s\n%s\n%s" % [name, class_text, str(cfg.get("cost_prestige", "-")), hp_text, sp_text, cd_text]


func _format_unit_ammo_status(unit: Node) -> String:
	if unit == null or not unit.has_method("get_skill_ammo_status"):
		return ""
	var ammo_status: Dictionary = unit.get_skill_ammo_status()
	var max_ammo := int(ammo_status.get("max", 0))
	if max_ammo <= 0:
		return ""
	var label := String(ammo_status.get("label", "弹药"))
	return "%s %d/%d" % [label, int(ammo_status.get("current", 0)), max_ammo]


func _format_operator_drag_text(operator_key: StringName) -> String:
	var operator_info := _get_operator_info(operator_key)
	if operator_info.is_empty():
		return String(operator_key)
	return "%s\n%s" % [String(operator_info.get("name", operator_key)), String(operator_info.get("unit_id", ""))]


func _format_resource_tooltip(buff_ids: Array[StringName]) -> String:
	var lines := PackedStringArray([
		"行动力用于探索和建造。",
		"声望用于招募和刷新商店。"
	])
	if buff_ids.is_empty():
		lines.append("当前遗物：无")
		return "\n".join(lines)
	var data_repo = AppRefs.data_repo()
	var buff_lines := PackedStringArray()
	for buff_id in buff_ids:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		buff_lines.append("%s：%s" % [
			UiDisplayText.config_name(cfg, buff_id),
			UiDisplayText.relic_effect_text(cfg)
		])
	lines.append("当前遗物：")
	lines.append("\n".join(buff_lines))
	return "\n".join(lines)


func _validate_drag_cell(operator_key: StringName, cell: Vector2i) -> Dictionary:
	if _unit_manager == null or not _unit_manager.has_method("validate_deploy_operator"):
		return ActionResult.err(&"UNIT_MANAGER_MISSING", "操作失败：单位管理器不可用")
	return _unit_manager.validate_deploy_operator(operator_key, cell)


func _get_mouse_cell() -> Vector2i:
	if _map_root == null or _map_manager == null:
		return INVALID_CELL
	return _map_manager.world_to_cell(_map_root.get_global_mouse_position())


func _get_facing_from_mouse(origin_cell: Vector2i) -> Vector2i:
	if _map_root == null or _map_manager == null:
		return Vector2i.RIGHT
	var origin_world: Vector2 = _map_manager.cell_to_world(origin_cell)
	var delta: Vector2 = _map_root.get_global_mouse_position() - origin_world
	if delta.length_squared() <= 16.0:
		return _current_drag_facing
	if abs(delta.x) >= abs(delta.y):
		return Vector2i.RIGHT if delta.x >= 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y >= 0.0 else Vector2i.UP


func _get_operator_attack_range_cells(operator_key: StringName, origin: Vector2i, facing: Vector2i) -> Array[Vector2i]:
	var operator_info := _get_operator_info(operator_key)
	var cfg := _get_unit_cfg(StringName(operator_info.get("unit_id", "")))
	return _get_range_cells_from_pattern(origin, facing, _parse_range_pattern(cfg.get("range_pattern", [])))


func _get_unit_attack_range_cells(unit: Node) -> Array[Vector2i]:
	if unit == null:
		return []
	return _get_range_cells_from_pattern(unit.get_current_cell(), unit.facing, unit.range_pattern)


func _get_range_cells_from_pattern(origin: Vector2i, facing: Vector2i, pattern: Array[Vector2i]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _map_manager == null:
		return cells
	for offset: Vector2i in pattern:
		var cell := origin + _rotate_offset(offset, facing)
		if _map_manager.is_inside(cell) and not cells.has(cell):
			cells.append(cell)
	return cells


func _parse_range_pattern(raw_pattern: Variant) -> Array[Vector2i]:
	var parsed: Array[Vector2i] = []
	if typeof(raw_pattern) != TYPE_ARRAY:
		return parsed
	for entry: Variant in raw_pattern:
		if typeof(entry) == TYPE_ARRAY and (entry as Array).size() >= 2:
			var pair := entry as Array
			parsed.append(Vector2i(int(pair[0]), int(pair[1])))
		elif entry is Vector2i:
			parsed.append(entry)
	return parsed


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


func _get_selected_unit() -> Node:
	if _selected_unit_runtime_id < 0 or _unit_manager == null:
		return null
	var unit = _unit_manager.get_unit_by_runtime_id(_selected_unit_runtime_id) if _unit_manager.has_method("get_unit_by_runtime_id") else null
	if unit == null or not is_instance_valid(unit):
		_selected_unit_runtime_id = -1
		_clear_attack_range_preview()
		return null
	return unit


func _get_operator_state(operator_key: StringName) -> StringName:
	if _unit_manager == null or not _unit_manager.has_method("get_operator_status"):
		return &"ready"
	return StringName(_unit_manager.get_operator_status(operator_key))


func _can_deploy_now() -> bool:
	var run_state = AppRefs.run_state()
	return run_state == null or int(run_state.phase) == GameEnums.PHASE_DAY or int(run_state.phase) == GameEnums.PHASE_NIGHT


func _get_operator_info(operator_key: StringName) -> Dictionary:
	for operator_info in _operator_defs:
		if StringName((operator_info as Dictionary).get("key", "")) == operator_key:
			return (operator_info as Dictionary)
	return {}


func _get_operator_display_name(operator_key: StringName) -> String:
	var operator_info := _get_operator_info(operator_key)
	if operator_info.is_empty():
		return String(operator_key)
	return String(operator_info.get("name", operator_key))


func _get_operator_visual_key(operator_key: StringName) -> String:
	var operator_info := _get_operator_info(operator_key)
	if operator_info.is_empty():
		return ""
	var unit_id := StringName(operator_info.get("unit_id", ""))
	var cfg := _get_unit_cfg(unit_id)
	return String(cfg.get("visual_key", unit_id)).strip_edges()


func _get_unit_cfg(unit_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return {}
	return data_repo.get_unit_cfg(unit_id)


func _get_unit_display_name(unit: Node) -> String:
	if unit == null:
		return "未知单位"
	if unit.get("operator_name") != null and not String(unit.operator_name).is_empty():
		return String(unit.operator_name)
	return String(unit.cfg.get("name", unit.unit_id))


func _show_message(text: String, cooldown_operator_key: StringName = &"", warning := false) -> void:
	_cooldown_message_operator_key = cooldown_operator_key
	if _combat_hud != null and _combat_hud.has_method("show_message"):
		_combat_hud.show_message(text, warning)


func _show_result_message(result: Dictionary, success_text: String, failure_text: String) -> void:
	var message := String(result.get("message", ""))
	if message.is_empty():
		message = success_text if result.get("ok", false) else failure_text
	_show_message(message, StringName(), not bool(result.get("ok", false)))
