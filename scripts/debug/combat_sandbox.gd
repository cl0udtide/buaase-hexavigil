extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")

const SPAWN_POINT_SCENE := preload("res://scenes/world/SpawnPoint.tscn")
const PRESET_PATH := "res://data/debug/combat_sandbox_presets.json"
const PRESET_DIR := "res://data/debug"
const SANDBOX_WIDTH := 12
const SANDBOX_HEIGHT := 7
const SANDBOX_CORE := Vector2i(10, 3)
const DEFAULT_SPAWNS := {
	"S1": Vector2i(0, 3),
	"S2": Vector2i(0, 1),
	"S3": Vector2i(0, 5)
}
const MAX_LOG_LINES := 220
const DAMAGE_TYPE_OPTIONS := ["physical", "magic", "true"]
const DRAG_NONE := &"none"
const DRAG_CARD := &"drag_card"
const DRAG_LOCKED := &"locked"
const DRAG_FACING := &"facing"
const INVALID_CELL := Vector2i(-9999, -9999)
const TOOL_SELECT := &"select"
const TOOL_BLOCK := &"block"
const TOOL_ERASE := &"erase"
const TOOL_CORE := &"core"
const TOOL_SPAWN := &"spawn"
const TOOL_BUILDING := &"building"
const TOOL_DELETE_BUILDING := &"delete_building"
const SPAWN_ACTION_NONE := &"none"
const SPAWN_ACTION_ADD := &"add"
const SPAWN_ACTION_MOVE := &"move"
const DAMAGE_TYPE_LABELS := ["物理", "法术", "真实"]
const DEBUG_BG := Color(0.045, 0.055, 0.07, 0.96)
const DEBUG_SURFACE := Color(0.09, 0.105, 0.13, 0.94)
const DEBUG_SURFACE_ALT := Color(0.12, 0.14, 0.17, 0.96)
const DEBUG_ACCENT := Color(0.23, 0.72, 0.95, 1.0)
const DEBUG_ACCENT_DIM := Color(0.12, 0.35, 0.48, 1.0)
const DEBUG_BORDER := Color(0.32, 0.39, 0.47, 0.55)
const DEBUG_TEXT_MUTED := Color(0.72, 0.78, 0.84, 1.0)

var _unit_ids: Array[StringName] = []
var _enemy_ids: Array[StringName] = []
var _building_ids: Array[StringName] = []
var _operator_defs: Array[Dictionary] = []
var _presets: Array[Dictionary] = []
var _spawn_defs: Dictionary = {}
var _spawn_queues: Dictionary = {}
var _debug_map_width := SANDBOX_WIDTH
var _debug_map_height := SANDBOX_HEIGHT
var _debug_core_cell := SANDBOX_CORE
var _debug_blocked_cells: Array[Vector2i] = []
var _running_spawn_queues: Dictionary = {}
var _selected_spawn_key := StringName()
var _selected_queue_index := -1
var _selected_operator_key := StringName()
var _selected_unit_runtime_id := -1
var _selected_tool: StringName = TOOL_SELECT
var _selected_building_id := StringName()
var _pending_spawn_action: StringName = SPAWN_ACTION_NONE
var _current_preset_id := ""
var _current_preset_name := ""
var _next_spawn_index := 1
var _log_lines: Array[String] = []
var _refreshing_editor_ui := false
var _debug_drawer_open := false
var _deploy_drag_state: StringName = DRAG_NONE
var _drag_operator_key := StringName()
var _locked_deploy_cell := INVALID_CELL
var _current_drag_cell := INVALID_CELL
var _current_drag_cell_valid := false
var _current_drag_facing := Vector2i.RIGHT
var _cooldown_message_operator_key := StringName()
var _last_painted_cell := INVALID_CELL
var _combat_hud: Control
var _debug_drawer_panel: Control
var _debug_drawer_content: Control

var _editor_tabs: TabContainer
var _preset_option: OptionButton
var _preset_name_edit: LineEdit
var _map_width_spin: SpinBox
var _map_height_spin: SpinBox
var _tool_buttons: Dictionary = {}
var _building_option: OptionButton
var _tool_help_label: Label
var _path_warning_label: Label
var _operator_list: ItemList
var _operator_name_edit: LineEdit
var _unit_option: OptionButton
var _facing_option: OptionButton
var _spawn_option: OptionButton
var _enemy_option: OptionButton
var _batch_count_spin: SpinBox
var _batch_first_delay_spin: SpinBox
var _batch_delay_spin: SpinBox
var _queue_list: ItemList
var _item_enemy_option: OptionButton
var _item_name_edit: LineEdit
var _item_delay_spin: SpinBox
var _item_hp_spin: SpinBox
var _item_atk_spin: SpinBox
var _item_def_spin: SpinBox
var _item_res_spin: SpinBox
var _item_speed_spin: SpinBox
var _item_interval_spin: SpinBox
var _item_damage_type_option: OptionButton
var _item_core_damage_spin: SpinBox
var _status_label: Label
var _unit_chip_label: Label
var _enemy_chip_label: Label
var _core_chip_label: Label
var _tool_chip_label: Label
var _skill_info_label: Label
var _message_label: Label
var _queue_hint_label: Label
var _log_text: TextEdit

@onready var _map_manager: Node = get_node_or_null("Managers/MapManager")
@onready var _path_service: Node = get_node_or_null("Managers/PathService")
@onready var _building_manager: Node = get_node_or_null("Managers/BuildingManager")
@onready var _unit_manager: Node = get_node_or_null("Managers/UnitManager")
@onready var _enemy_manager: Node = get_node_or_null("Managers/EnemyManager")
@onready var _map_root: Node = get_node_or_null("World/MapRoot")
@onready var _spawn_root: Node = get_node_or_null("World/SpawnRoot")
@onready var _projectile_root: Node = get_node_or_null("World/ProjectileRoot")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("combat_debug_log")
	_configure_pause_boundaries()
	var data_repo = AppRefs.data_repo()
	if data_repo != null and (not data_repo.has_method("is_loaded") or not data_repo.is_loaded()):
		data_repo.load_all()
	_load_presets_from_disk()
	_build_editor_ui()
	_bind_combat_hud()
	_populate_static_options()
	_connect_events()
	_apply_preset_by_index(0)
	set_process(true)


func _process(delta: float) -> void:
	if not get_tree().paused:
		_tick_spawn_queues(delta)
	_update_deploy_drag()
	_update_operator_card_states()
	_refresh_top_hud()
	_refresh_detail_panel()
	if _debug_drawer_open:
		_update_editor_drag_paint()
		_refresh_operator_list()
		_refresh_status()
		_refresh_skill_info(_get_selected_unit())
	if _selected_unit_runtime_id >= 0:
		_refresh_attack_range_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _deploy_drag_state != DRAG_NONE:
			_cancel_deploy_flow("已取消")
		elif _debug_drawer_open and _selected_tool != TOOL_SELECT:
			_select_editor_tool(TOOL_SELECT, "已返回选择工具")
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			if _deploy_drag_state != DRAG_NONE:
				_cancel_deploy_flow("已取消")
				get_viewport().set_input_as_handled()
				return
			return
		if _deploy_drag_state == DRAG_LOCKED and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _get_mouse_cell() == _locked_deploy_cell:
				_deploy_drag_state = DRAG_FACING
				_current_drag_facing = Vector2i.RIGHT
				_show_message("向外拖拽选择朝向")
				return

func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
	Engine.time_scale = 1.0


func _configure_pause_boundaries() -> void:
	var world := get_node_or_null("World")
	if world != null:
		world.process_mode = Node.PROCESS_MODE_PAUSABLE
		var map_root := world.get_node_or_null("MapRoot")
		if map_root != null:
			map_root.process_mode = Node.PROCESS_MODE_ALWAYS
	var managers := get_node_or_null("Managers")
	if managers != null:
		managers.process_mode = Node.PROCESS_MODE_PAUSABLE
	var ui := get_node_or_null("UI")
	if ui != null:
		ui.process_mode = Node.PROCESS_MODE_ALWAYS


func _bind_combat_hud() -> void:
	_combat_hud = get_node_or_null("UI/CombatHud") as Control
	if _combat_hud == null:
		push_warning("CombatHud scene is missing from CombatSandbox.")
		return
	if _combat_hud.has_signal("operator_card_pressed"):
		_combat_hud.connect(&"operator_card_pressed", Callable(self, "_on_operator_card_pressed"))
	if _combat_hud.has_signal("pause_pressed"):
		_combat_hud.connect(&"pause_pressed", Callable(self, "_on_pause_pressed"))
	if _combat_hud.has_signal("speed_1_pressed"):
		_combat_hud.connect(&"speed_1_pressed", Callable(self, "_on_speed_1_pressed"))
	if _combat_hud.has_signal("speed_2_pressed"):
		_combat_hud.connect(&"speed_2_pressed", Callable(self, "_on_speed_2_pressed"))
	if _combat_hud.has_signal("debug_drawer_toggle_pressed"):
		_combat_hud.connect(&"debug_drawer_toggle_pressed", Callable(self, "_on_debug_drawer_toggle_pressed"))
	if _combat_hud.has_signal("cast_skill_requested"):
		_combat_hud.connect(&"cast_skill_requested", Callable(self, "_on_cast_skill_pressed"))
	if _combat_hud.has_signal("retreat_requested"):
		_combat_hud.connect(&"retreat_requested", Callable(self, "_on_retreat_pressed"))
	_refresh_top_hud()
	_rebuild_deploy_deck()
	_refresh_detail_panel()


func _set_debug_drawer_open(open: bool) -> void:
	_debug_drawer_open = open
	if _debug_drawer_panel != null:
		_debug_drawer_panel.visible = open
		_debug_drawer_panel.anchor_left = 1.0
		_debug_drawer_panel.anchor_top = 0.0
		_debug_drawer_panel.anchor_right = 1.0
		_debug_drawer_panel.anchor_bottom = 1.0
		_debug_drawer_panel.offset_left = -900.0
		_debug_drawer_panel.offset_top = 82.0
		_debug_drawer_panel.offset_right = -18.0
		_debug_drawer_panel.offset_bottom = -18.0
	if _combat_hud != null and _combat_hud.has_method("set_debug_drawer_open"):
		_combat_hud.set_debug_drawer_open(open)


func _on_debug_drawer_toggle_pressed() -> void:
	_set_debug_drawer_open(not _debug_drawer_open)


func _on_pause_pressed() -> void:
	get_tree().paused = true
	_refresh_time_controls()


func _on_speed_1_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_refresh_time_controls()


func _on_speed_2_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 2.0
	_refresh_time_controls()


func _refresh_time_controls() -> void:
	if _combat_hud != null and _combat_hud.has_method("set_time_controls"):
		_combat_hud.set_time_controls(get_tree().paused, Engine.time_scale)


func _refresh_top_hud() -> void:
	var run_state = AppRefs.run_state()
	var core_text := "核心生命\n%d/%d" % [run_state.core_hp, run_state.core_hp_max] if run_state != null else "核心生命\n--/--"
	var deploy_text := "部署上限\n%d/%d" % [run_state.deployed_count, run_state.deploy_limit] if run_state != null else "部署上限\n0/0"
	var queue_text := "战斗沙盒\n运行队列 %d" % _running_spawn_queues.size()
	if _combat_hud != null and _combat_hud.has_method("set_top_values"):
		_combat_hud.set_top_values(core_text, deploy_text, queue_text)
	if _combat_hud != null and _combat_hud.has_method("set_resource_values"):
		_combat_hud.set_resource_values("调试资源\n沙盒模式")
	_refresh_time_controls()


func _rebuild_deploy_deck() -> void:
	if _combat_hud == null or not _combat_hud.has_method("set_operators"):
		return
	_combat_hud.set_operators(_operator_defs)
	_update_operator_card_states()


func _update_operator_card_states() -> void:
	for operator_info in _operator_defs:
		_refresh_operator_card(StringName((operator_info as Dictionary).get("key", "")))


func _refresh_operator_card(operator_key: StringName) -> void:
	if _combat_hud == null or not _combat_hud.has_method("set_operator_card"):
		return
	var operator_info := _get_operator_info(operator_key)
	var state := _get_operator_state(operator_key)
	_combat_hud.set_operator_card(operator_key, _format_operator_card_text(operator_info, state), state)


func _on_operator_card_pressed(operator_key: StringName) -> void:
	var state := _get_operator_state(operator_key)
	if state == &"ready":
		_begin_operator_drag(operator_key)
	elif state == &"deployed":
		var unit = _unit_manager.get_unit_by_operator_key(operator_key) if _unit_manager != null and _unit_manager.has_method("get_unit_by_operator_key") else null
		_select_deployed_unit(unit)
	else:
		_show_message("干员正在再部署冷却中", operator_key)


func _begin_operator_drag(operator_key: StringName) -> void:
	_cancel_deploy_flow("")
	_deploy_drag_state = DRAG_CARD
	_drag_operator_key = operator_key
	_selected_operator_key = operator_key
	_current_drag_cell = INVALID_CELL
	_current_drag_cell_valid = false
	_current_drag_facing = Vector2i.RIGHT
	if _combat_hud != null and _combat_hud.has_method("show_drag_ghost"):
		_combat_hud.show_drag_ghost(_format_operator_drag_text(operator_key))
	_show_message("拖拽干员卡到可部署格")


func _update_deploy_drag() -> void:
	if _deploy_drag_state == DRAG_NONE:
		return
	_update_drag_ghost_position()
	match _deploy_drag_state:
		DRAG_CARD:
			_update_card_drag_preview()
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				if _current_drag_cell_valid:
					_lock_deploy_cell(_current_drag_cell)
				else:
					_cancel_deploy_flow("已取消")
		DRAG_LOCKED:
			_update_locked_deploy_preview(Vector2i.RIGHT)
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
		_map_root.set_deploy_preview(cell, _current_drag_cell_valid, preview_range)


func _lock_deploy_cell(cell: Vector2i) -> void:
	_deploy_drag_state = DRAG_LOCKED
	_locked_deploy_cell = cell
	_current_drag_facing = Vector2i.RIGHT
	if _combat_hud != null and _combat_hud.has_method("hide_drag_ghost"):
		_combat_hud.hide_drag_ghost()
	_update_locked_deploy_preview(_current_drag_facing)
	_show_message("从锁定格向外拖拽选择朝向")


func _update_locked_deploy_preview(facing: Vector2i) -> void:
	if _locked_deploy_cell == INVALID_CELL:
		return
	var preview_range := _get_operator_attack_range_cells(_drag_operator_key, _locked_deploy_cell, facing)
	if _map_root != null and _map_root.has_method("set_deploy_direction_preview"):
		_map_root.set_deploy_direction_preview(_locked_deploy_cell, facing, preview_range)


func _confirm_locked_deploy() -> void:
	if _unit_manager == null or _locked_deploy_cell == INVALID_CELL:
		_cancel_deploy_flow("部署失败")
		return
	var result: Dictionary = _unit_manager.try_deploy_operator(_drag_operator_key, _locked_deploy_cell, _current_drag_facing)
	var payload: Dictionary = result.get("payload", {})
	var runtime_id := int(payload.get("runtime_id", -1))
	var unit = _unit_manager.get_unit_by_runtime_id(runtime_id) if runtime_id >= 0 and _unit_manager.has_method("get_unit_by_runtime_id") else null
	_clear_deploy_preview()
	_deploy_drag_state = DRAG_NONE
	_drag_operator_key = StringName()
	_locked_deploy_cell = INVALID_CELL
	if result.get("ok", false):
		_select_deployed_unit(unit)
	_show_result_message(result, "部署完成", "部署失败")


func _cancel_deploy_flow(message: String = "") -> void:
	_deploy_drag_state = DRAG_NONE
	_drag_operator_key = StringName()
	_locked_deploy_cell = INVALID_CELL
	_current_drag_cell = INVALID_CELL
	_current_drag_cell_valid = false
	if _combat_hud != null and _combat_hud.has_method("hide_drag_ghost"):
		_combat_hud.hide_drag_ghost()
	_clear_deploy_preview()
	if not message.is_empty():
		_show_message(message)


func _clear_deploy_preview() -> void:
	if _map_root != null and _map_root.has_method("clear_deploy_preview"):
		_map_root.clear_deploy_preview()


func _update_drag_ghost_position() -> void:
	if _combat_hud != null and _combat_hud.has_method("move_drag_ghost"):
		_combat_hud.move_drag_ghost(get_viewport().get_mouse_position())


func _validate_drag_cell(operator_key: StringName, cell: Vector2i) -> Dictionary:
	if _unit_manager == null or not _unit_manager.has_method("validate_deploy_operator"):
		return ActionResult.err(&"UNIT_MANAGER_MISSING", "UNIT_MANAGER_MISSING")
	return _unit_manager.validate_deploy_operator(operator_key, cell)


func _get_mouse_cell() -> Vector2i:
	if _map_manager == null or _map_root == null:
		return INVALID_CELL
	return _map_manager.world_to_cell(_map_root.get_global_mouse_position())


func _get_facing_from_mouse(origin_cell: Vector2i) -> Vector2i:
	if _map_manager == null or _map_root == null:
		return Vector2i.RIGHT
	var delta: Vector2 = _map_root.get_global_mouse_position() - _map_manager.cell_to_world(origin_cell)
	if delta.length_squared() < 64.0:
		return Vector2i.RIGHT
	if abs(delta.x) >= abs(delta.y):
		return Vector2i.RIGHT if delta.x >= 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y >= 0.0 else Vector2i.UP


func _handle_map_cell_selection(cell: Vector2i) -> void:
	if _deploy_drag_state != DRAG_NONE or _unit_manager == null:
		return
	if cell == INVALID_CELL:
		return
	var existing_unit = _unit_manager.get_unit_by_cell(cell) if _unit_manager.has_method("get_unit_by_cell") else null
	if existing_unit != null:
		_select_deployed_unit(existing_unit)
		return
	_clear_selected_unit_selection()


func _select_deployed_unit(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	_selected_unit_runtime_id = unit.get_runtime_id() if unit.has_method("get_runtime_id") else -1
	_selected_operator_key = StringName(unit.operator_key) if unit.get("operator_key") != null else StringName()
	_refresh_attack_range_preview()
	_refresh_detail_panel()
	_show_message("已选中 %s" % _get_unit_display_name_for_ui(unit))


func _clear_selected_unit_selection() -> void:
	_selected_unit_runtime_id = -1
	_clear_attack_range_preview()
	_refresh_detail_panel()


func _clear_unit_selection_if_click_misses_unit(cell: Vector2i) -> void:
	if _selected_unit_runtime_id < 0 or _unit_manager == null or not _unit_manager.has_method("get_unit_by_cell"):
		return
	var clicked_unit = _unit_manager.get_unit_by_cell(cell)
	if clicked_unit != null and is_instance_valid(clicked_unit) and clicked_unit.has_method("get_runtime_id") and int(clicked_unit.get_runtime_id()) == _selected_unit_runtime_id:
		return
	_clear_selected_unit_selection()


func _refresh_detail_panel() -> void:
	if _combat_hud == null:
		return
	var unit := _get_selected_unit()
	if unit == null:
		if _combat_hud.has_method("clear_unit_detail"):
			_combat_hud.clear_unit_detail()
		return
	if _combat_hud.has_method("show_unit_detail"):
		_combat_hud.show_unit_detail(
			unit,
			_get_unit_display_name_for_ui(unit),
			_damage_type_label(String(unit.cfg.get("damage_type", "physical"))),
			_direction_label(unit.facing)
		)


func _get_operator_attack_range_cells(operator_key: StringName, origin: Vector2i, facing: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _map_manager == null:
		return cells
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null or not run_state.has_method("get_owned_operator"):
		return cells
	var operator_info: Dictionary = run_state.get_owned_operator(operator_key)
	var unit_id := StringName(operator_info.get("unit_id", ""))
	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
	for offset in _parse_range_pattern_for_ui(cfg.get("range_pattern", [])):
		var cell := origin + _rotate_offset(offset, facing)
		if _map_manager.is_inside(cell) and not cells.has(cell):
			cells.append(cell)
	return cells


func _parse_range_pattern_for_ui(raw_pattern: Variant) -> Array[Vector2i]:
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


func _get_unit_display_name_for_ui(unit: Node) -> String:
	if unit == null:
		return "未知单位"
	if unit.operator_name != "":
		return String(unit.operator_name)
	return String(unit.cfg.get("name", unit.unit_id))


func _format_operator_card_text(operator_info: Dictionary, state: StringName) -> String:
	if operator_info.is_empty():
		return "未知\n--"
	var operator_key := StringName(operator_info.get("key", ""))
	var data_repo = AppRefs.data_repo()
	var unit_id := StringName(operator_info.get("unit_id", ""))
	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id) if data_repo != null else {}
	var name := str(operator_info.get("name", cfg.get("name", operator_key)))
	var class_text := _class_label(str(cfg.get("class", "")))
	var cost_text := str(cfg.get("cost_prestige", "--"))
	if state == &"deployed":
		var unit = _unit_manager.get_unit_by_operator_key(operator_key) if _unit_manager != null and _unit_manager.has_method("get_unit_by_operator_key") else null
		if unit != null:
			return "%s\n%s  费用 %s\n生命 %d/%d  技力 %.0f" % [name, class_text, cost_text, int(unit.current_hp), int(unit.max_hp), float(unit.sp)]
		return "%s\n%s  费用 %s\n已部署" % [name, class_text, cost_text]
	if state == &"cooldown":
		var remain: float = _unit_manager.get_operator_redeploy_remaining(operator_key) if _unit_manager != null and _unit_manager.has_method("get_operator_redeploy_remaining") else 0.0
		return "%s\n%s  费用 %s\n冷却 %.1f秒" % [name, class_text, cost_text, remain]
	return "%s\n%s  费用 %s\n拖拽部署" % [name, class_text, cost_text]


func _format_operator_drag_text(operator_key: StringName) -> String:
	var operator_info := _get_operator_info(operator_key)
	if operator_info.is_empty():
		return String(operator_key)
	return "%s\n%s" % [String(operator_info.get("name", operator_key)), String(operator_info.get("unit_id", ""))]


func _get_operator_state(operator_key: StringName) -> StringName:
	if _unit_manager == null or not _unit_manager.has_method("get_operator_status"):
		return &"ready"
	return StringName(_unit_manager.get_operator_status(operator_key))


func _class_label(raw_class: String) -> String:
	match raw_class:
		"guard":
			return "近卫"
		"sniper":
			return "狙击"
		"caster":
			return "术士"
		"defender":
			return "重装"
		_:
			return raw_class if not raw_class.is_empty() else "干员"


func _damage_type_label(raw_type: String) -> String:
	match raw_type:
		"magic":
			return "法术"
		"true":
			return "真实"
		_:
			return "物理"


func _direction_label(direction: Vector2i) -> String:
	if abs(direction.x) >= abs(direction.y):
		return "右" if direction.x >= 0 else "左"
	return "下" if direction.y >= 0 else "上"


func _build_editor_ui() -> void:
	_build_editor_ui_v2()
	return
	var panel := get_node_or_null("UI/Panel") as Control
	if panel != null:
		AppTheme.apply(panel)
		_debug_drawer_panel = panel
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var vbox := get_node_or_null("UI/Panel/MarginContainer/VBox") as VBoxContainer
	if vbox == null:
		return
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()

	var title := _make_label("战斗沙盒编辑器", 0.0)
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_status_label = _make_label("单位 0  敌人 0", 0.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	_editor_tabs = TabContainer.new()
	_editor_tabs.custom_minimum_size = Vector2(0, 450)
	_editor_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_tabs.tab_changed.connect(_on_editor_tab_changed)
	vbox.add_child(_editor_tabs)

	_build_map_tab(_make_tab(_editor_tabs, "地图"))
	_build_combat_tab(_make_tab(_editor_tabs, "战斗"))
	_build_preset_tab(_make_tab(_editor_tabs, "预设"))
	_build_spawn_tab(_make_tab(_editor_tabs, "出怪点"))
	_build_queue_tab(_make_tab(_editor_tabs, "队列"))
	_build_item_tab(_make_tab(_editor_tabs, "敌人"))

	_message_label = _make_label("加载预设，编辑出怪点并调整敌人队列。", 0.0)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_message_label)

	var log_title := _make_label("战斗日志", 0.0)
	vbox.add_child(log_title)
	_log_text = TextEdit.new()
	_log_text.custom_minimum_size = Vector2(0, 230)
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.editable = false
	_log_text.wrap_mode = 1
	vbox.add_child(_log_text)
	_set_debug_drawer_open(false)


func _build_editor_ui_v2() -> void:
	var panel := get_node_or_null("UI/Panel") as Control
	if panel != null:
		AppTheme.apply(panel)
		_debug_drawer_panel = panel
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.custom_minimum_size = Vector2(900, 0)
		if panel is PanelContainer:
			(panel as PanelContainer).add_theme_stylebox_override("panel", _make_panel_style(DEBUG_BG, DEBUG_ACCENT_DIM, 8, 1))
	var vbox := get_node_or_null("UI/Panel/MarginContainer/VBox") as VBoxContainer
	if vbox == null:
		return
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()
	vbox.add_theme_constant_override("separation", 10)

	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.07, 0.09, 0.12, 0.98), DEBUG_ACCENT_DIM, 8, 1))
	vbox.add_child(header_panel)
	var header_margin := _make_margin_container(12, 8, 12, 8)
	header_panel.add_child(header_margin)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header_margin.add_child(header)
	var title := _make_label("战斗沙盒工作台", 0.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 1.0))
	header.add_child(title)
	_unit_chip_label = _make_status_chip(header, "单位 --")
	_enemy_chip_label = _make_status_chip(header, "敌人 --")
	_core_chip_label = _make_status_chip(header, "核心 --")
	_tool_chip_label = _make_status_chip(header, "工具 选择", true)
	header.add_child(_make_button("清战斗", _on_clear_pressed))
	header.add_child(_make_button("重置沙盒", _on_reset_pressed))

	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.075, 0.095, 0.92), DEBUG_BORDER, 6, 1))
	vbox.add_child(status_panel)
	var status_margin := _make_margin_container(10, 6, 10, 6)
	status_panel.add_child(status_margin)
	_status_label = _make_label("地图 12x7  预设 默认调试  出怪点 S1", 0.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", DEBUG_TEXT_MUTED)
	status_margin.add_child(_status_label)

	var message_panel := PanelContainer.new()
	message_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.105, 0.13, 0.86), DEBUG_ACCENT_DIM, 6, 1))
	vbox.add_child(message_panel)
	var message_margin := _make_margin_container(10, 6, 10, 6)
	message_panel.add_child(message_margin)
	_message_label = _make_label("选择地图工具或右侧出怪点动作后，在地图上完成对应操作。点击出怪点会切换右侧队列。", 0.0)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
	message_margin.add_child(_message_label)

	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = 0
	body_scroll.vertical_scroll_mode = 1
	vbox.add_child(body_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body_scroll.add_child(body)

	var main_row := HBoxContainer.new()
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_FILL
	main_row.add_theme_constant_override("separation", 10)
	body.add_child(main_row)

	var left := _make_scroll_panel(main_row, Vector2(390, 0))
	var right := _make_scroll_panel(main_row, Vector2(450, 0))

	_build_map_tab(_make_section(left, "地图与建筑"))
	_build_preset_tab(_make_section(left, "预设"))

	_build_queue_tab(_make_section(right, "出怪点与敌人队列"))
	_build_item_tab(_make_section(right, "选中敌人属性"))

	var log_header := _make_row(body)
	var log_title := _make_label("战斗日志", 0.0)
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
	log_header.add_child(log_title)
	log_header.add_child(_make_button("清日志", _clear_debug_log))
	_log_text = TextEdit.new()
	_log_text.custom_minimum_size = Vector2(0, 260)
	_log_text.size_flags_vertical = Control.SIZE_FILL
	_log_text.editable = false
	_log_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_style_text_edit(_log_text)
	body.add_child(_log_text)
	_editor_tabs = null
	_set_debug_drawer_open(false)


func _build_map_tab(tab: VBoxContainer) -> void:
	var size_row := _make_row(tab)
	size_row.add_child(_make_label("宽", 36.0))
	_map_width_spin = _make_spin(6.0, 40.0, 1.0, float(_debug_map_width))
	_map_width_spin.value_changed.connect(_on_map_size_changed)
	size_row.add_child(_map_width_spin)
	size_row.add_child(_make_label("高", 36.0))
	_map_height_spin = _make_spin(4.0, 24.0, 1.0, float(_debug_map_height))
	_map_height_spin.value_changed.connect(_on_map_size_changed)
	size_row.add_child(_map_height_spin)
	var size_hint := _make_label("宽高修改会立即重建地图，并清空当前战斗运行态。", 0.0)
	size_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size_hint.add_theme_color_override("font_color", DEBUG_TEXT_MUTED)
	tab.add_child(size_hint)

	_tool_buttons.clear()
	var tool_grid := GridContainer.new()
	tool_grid.columns = 2
	tool_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_grid.add_theme_constant_override("h_separation", 7)
	tool_grid.add_theme_constant_override("v_separation", 7)
	tab.add_child(tool_grid)
	_add_tool_button(tool_grid, TOOL_SELECT, "01 选择")
	_add_tool_button(tool_grid, TOOL_BLOCK, "02 阻挡")
	_add_tool_button(tool_grid, TOOL_ERASE, "03 橡皮")
	_add_tool_button(tool_grid, TOOL_CORE, "04 核心")
	_add_tool_button(tool_grid, TOOL_SPAWN, "05 出怪点")
	_add_tool_button(tool_grid, TOOL_BUILDING, "06 建筑")
	_add_tool_button(tool_grid, TOOL_DELETE_BUILDING, "07 拆除")

	_tool_help_label = _make_label("", 0.0)
	_tool_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_help_label.add_theme_color_override("font_color", DEBUG_TEXT_MUTED)
	tab.add_child(_tool_help_label)

	var building_row := _make_row(tab)
	building_row.add_child(_make_label("建筑", 54.0))
	_building_option = _make_option(building_row)
	_building_option.item_selected.connect(_on_building_option_selected)

	_path_warning_label = _make_label("", 0.0)
	_path_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(_path_warning_label)

	var hint := _make_label("选择工具用于查看单位和选中出怪点；出怪点工具用于新增或移动出怪点。", 0.0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(hint)
	_refresh_tool_buttons()


func _add_tool_button(row: Control, tool: StringName, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		_select_editor_tool(tool)
	)
	_apply_button_style(button, false)
	row.add_child(button)
	_tool_buttons[tool] = button


func _build_combat_tab(tab: VBoxContainer) -> void:
	var roster_label := _make_label("部署区干员（自动包含全部）", 0.0)
	tab.add_child(roster_label)
	_operator_list = ItemList.new()
	_operator_list.custom_minimum_size = Vector2(0, 150)
	_operator_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_operator_list.item_selected.connect(_on_operator_item_selected)
	_style_item_list(_operator_list)
	tab.add_child(_operator_list)

	var add_row := _make_row(tab)
	add_row.visible = false
	add_row.add_child(_make_label("类型", 54.0))
	_unit_option = _make_option(add_row)
	add_row.add_child(_make_label("名称", 54.0))
	_operator_name_edit = LineEdit.new()
	_operator_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(_operator_name_edit)
	add_row.add_child(_operator_name_edit)

	var roster_action_row := _make_row(tab)
	roster_action_row.visible = false
	roster_action_row.add_child(_make_button("添加槽位", _on_add_operator_pressed))
	roster_action_row.add_child(_make_button("删除槽位", _on_delete_operator_pressed))

	var facing_row := _make_row(tab)
	facing_row.visible = false
	facing_row.add_child(_make_label("朝向", 54.0))
	_facing_option = _make_option(facing_row)

	var unit_action_row := _make_row(tab)
	unit_action_row.visible = false
	unit_action_row.add_child(_make_button("释放技能", _on_cast_skill_pressed))
	unit_action_row.add_child(_make_button("撤退", _on_retreat_pressed))

	var run_row := _make_row(tab)
	run_row.add_child(_make_button("启动选中", _on_start_selected_spawn_pressed))
	run_row.add_child(_make_button("全部启动", _on_start_all_spawns_pressed))
	run_row.add_child(_make_button("停止队列", _on_stop_spawns_pressed))

	var scene_row := _make_row(tab)
	scene_row.add_child(_make_button("清战斗", _on_clear_pressed))
	scene_row.add_child(_make_button("重置沙盒", _on_reset_pressed))

	_skill_info_label = _make_label("技能：未选中单位", 0.0)
	_skill_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(_skill_info_label)


func _build_preset_tab(tab: VBoxContainer) -> void:
	var select_row := _make_row(tab)
	select_row.add_child(_make_label("预设", 54.0))
	_preset_option = _make_option(select_row)
	_preset_option.item_selected.connect(_on_preset_option_selected)
	select_row.add_child(_make_button("加载", _on_load_preset_pressed))

	var name_row := _make_row(tab)
	name_row.add_child(_make_label("名称", 54.0))
	_preset_name_edit = LineEdit.new()
	_preset_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(_preset_name_edit)
	name_row.add_child(_preset_name_edit)

	var action_row := _make_row(tab)
	action_row.add_child(_make_button("保存", _on_save_preset_pressed))
	action_row.add_child(_make_button("另存", _on_save_new_preset_pressed))
	action_row.add_child(_make_button("删除", _on_delete_preset_pressed))


func _build_spawn_tab(tab: VBoxContainer) -> void:
	var spawn_row := _make_row(tab)
	spawn_row.add_child(_make_label("出怪点", 68.0))
	_spawn_option = _make_option(spawn_row)
	_spawn_option.item_selected.connect(_on_spawn_option_selected)
	spawn_row.add_child(_make_button("添加", _on_add_spawn_pressed))
	spawn_row.add_child(_make_button("删除", _on_delete_spawn_pressed))

	var hint := _make_label("点击已有出怪点进行选择，或点击空格移动当前选中的出怪点。", 0.0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(hint)


func _build_queue_tab(tab: VBoxContainer) -> void:
	_queue_hint_label = _make_label("队列：未选择出怪点", 0.0)
	tab.add_child(_queue_hint_label)

	var spawn_row := _make_row(tab)
	spawn_row.add_child(_make_label("出怪点", 68.0))
	_spawn_option = _make_option(spawn_row)
	_spawn_option.item_selected.connect(_on_spawn_option_selected)
	var spawn_action_row := _make_row(tab)
	spawn_action_row.add_child(_make_button("添加出怪点", _on_add_spawn_pressed))
	spawn_action_row.add_child(_make_button("删除出怪点", _on_delete_spawn_pressed))

	var run_row := _make_row(tab)
	run_row.add_child(_make_button("启动当前", _on_start_selected_spawn_pressed))
	run_row.add_child(_make_button("启动全部", _on_start_all_spawns_pressed))
	run_row.add_child(_make_button("停止全部", _on_stop_spawns_pressed))

	var add_row := _make_row(tab)
	add_row.add_child(_make_label("敌人", 54.0))
	_enemy_option = _make_option(add_row)
	add_row.add_child(_make_button("添加单个", _on_add_enemy_item_pressed))

	var batch_row := _make_row(tab)
	batch_row.add_child(_make_label("首延迟", 54.0))
	_batch_first_delay_spin = _make_spin(0.0, 60.0, 0.05, 0.0)
	batch_row.add_child(_batch_first_delay_spin)
	batch_row.add_child(_make_label("数量", 54.0))
	_batch_count_spin = _make_spin(1.0, 50.0, 1.0, 3.0)
	batch_row.add_child(_batch_count_spin)
	var interval_row := _make_row(tab)
	interval_row.add_child(_make_label("间隔", 54.0))
	_batch_delay_spin = _make_spin(0.0, 60.0, 0.05, 0.5)
	interval_row.add_child(_batch_delay_spin)
	interval_row.add_child(_make_button("追加批次", _on_batch_append_pressed))

	_queue_list = ItemList.new()
	_queue_list.custom_minimum_size = Vector2(0, 125)
	_queue_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_queue_list.item_selected.connect(_on_queue_item_selected)
	_style_item_list(_queue_list)
	tab.add_child(_queue_list)

	var action_row := _make_row(tab)
	action_row.add_child(_make_button("复制", _on_duplicate_queue_item_pressed))
	action_row.add_child(_make_button("删除", _on_remove_queue_item_pressed))
	action_row.add_child(_make_button("上移", _on_move_queue_item_up_pressed))
	action_row.add_child(_make_button("下移", _on_move_queue_item_down_pressed))
	action_row.add_child(_make_button("立即刷出", _on_spawn_selected_queue_item_pressed))


func _build_item_tab(tab: VBoxContainer) -> void:
	var enemy_row := _make_row(tab)
	enemy_row.add_child(_make_label("敌人ID", 68.0))
	_item_enemy_option = _make_option(enemy_row)
	_item_enemy_option.item_selected.connect(_on_selected_item_property_changed)

	var name_row := _make_row(tab)
	name_row.add_child(_make_label("名称", 68.0))
	_item_name_edit = LineEdit.new()
	_item_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_name_edit.text_changed.connect(_on_selected_item_property_changed)
	_style_line_edit(_item_name_edit)
	name_row.add_child(_item_name_edit)

	var timing_row := _make_row(tab)
	timing_row.add_child(_make_label("延迟", 68.0))
	_item_delay_spin = _make_spin(0.0, 60.0, 0.05, 0.0)
	_item_delay_spin.value_changed.connect(_on_selected_item_property_changed)
	timing_row.add_child(_item_delay_spin)
	timing_row.add_child(_make_label("间隔", 68.0))
	_item_interval_spin = _make_spin(0.05, 60.0, 0.05, 1.0)
	_item_interval_spin.value_changed.connect(_on_selected_item_property_changed)
	timing_row.add_child(_item_interval_spin)

	var hp_row := _make_row(tab)
	hp_row.add_child(_make_label("生命", 68.0))
	_item_hp_spin = _make_spin(1.0, 99999.0, 1.0, 1.0)
	_item_hp_spin.value_changed.connect(_on_selected_item_property_changed)
	hp_row.add_child(_item_hp_spin)
	hp_row.add_child(_make_label("攻击", 68.0))
	_item_atk_spin = _make_spin(0.0, 99999.0, 1.0, 1.0)
	_item_atk_spin.value_changed.connect(_on_selected_item_property_changed)
	hp_row.add_child(_item_atk_spin)

	var defense_row := _make_row(tab)
	defense_row.add_child(_make_label("防御", 68.0))
	_item_def_spin = _make_spin(0.0, 99999.0, 1.0, 0.0)
	_item_def_spin.value_changed.connect(_on_selected_item_property_changed)
	defense_row.add_child(_item_def_spin)
	defense_row.add_child(_make_label("法抗", 68.0))
	_item_res_spin = _make_spin(0.0, 100.0, 1.0, 0.0)
	_item_res_spin.value_changed.connect(_on_selected_item_property_changed)
	defense_row.add_child(_item_res_spin)

	var move_row := _make_row(tab)
	move_row.add_child(_make_label("速度", 68.0))
	_item_speed_spin = _make_spin(0.05, 20.0, 0.05, 1.0)
	_item_speed_spin.value_changed.connect(_on_selected_item_property_changed)
	move_row.add_child(_item_speed_spin)
	move_row.add_child(_make_label("核心伤害", 68.0))
	_item_core_damage_spin = _make_spin(0.0, 99.0, 1.0, 1.0)
	_item_core_damage_spin.value_changed.connect(_on_selected_item_property_changed)
	move_row.add_child(_item_core_damage_spin)

	var damage_row := _make_row(tab)
	damage_row.add_child(_make_label("伤害类型", 68.0))
	_item_damage_type_option = _make_option(damage_row)
	_item_damage_type_option.item_selected.connect(_on_selected_item_property_changed)


func _connect_events() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.map_cell_clicked.connect(_on_map_cell_clicked)
		event_bus.unit_deployed.connect(_on_unit_deployed)
		event_bus.unit_removed.connect(_on_unit_removed)
	if _unit_manager != null and _unit_manager.has_signal("operator_redeploy_completed"):
		_unit_manager.connect(&"operator_redeploy_completed", Callable(self, "_on_operator_redeploy_completed"))


func _populate_static_options() -> void:
	_populate_unit_options()
	_populate_enemy_options()
	_populate_building_options()
	_populate_direction_options()
	_populate_damage_type_options()
	_populate_preset_options()


func _reset_sandbox() -> void:
	_cancel_deploy_flow("")
	_clear_debug_log()
	get_tree().paused = false
	Engine.time_scale = 1.0
	_running_spawn_queues.clear()
	_selected_operator_key = _get_first_operator_key()
	_selected_unit_runtime_id = -1
	_selected_tool = TOOL_SELECT
	_pending_spawn_action = SPAWN_ACTION_NONE
	_clear_attack_range_preview()
	if _enemy_manager != null and _enemy_manager.has_method("clear_all_enemies"):
		_enemy_manager.clear_all_enemies()
	if _unit_manager != null and _unit_manager.has_method("clear_all_units"):
		_unit_manager.clear_all_units()
	_clear_projectiles()
	var run_state = AppRefs.run_state()
	if run_state != null:
		run_state.reset_for_new_run(1)
		run_state.set_day(1)
		run_state.set_phase(GameEnums.PHASE_DAY)
		run_state.set_deploy_limit(99)
		run_state.reset_action_points(999)
		for operator_info in _operator_defs:
			var operator_dict := operator_info as Dictionary
			run_state.add_owned_operator_with_key(
				StringName(operator_dict.get("key", "")),
				StringName(operator_dict.get("unit_id", "")),
				String(operator_dict.get("name", ""))
			)
	_apply_debug_map_from_state()
	append_combat_debug("沙盒已重置")
	_refresh_editor_controls()


func _clear_battlefield() -> void:
	_cancel_deploy_flow("")
	_running_spawn_queues.clear()
	_selected_unit_runtime_id = -1
	_clear_attack_range_preview()
	if _enemy_manager != null and _enemy_manager.has_method("clear_all_enemies"):
		_enemy_manager.clear_all_enemies()
	if _unit_manager != null and _unit_manager.has_method("clear_all_units"):
		_unit_manager.clear_all_units()
	_clear_projectiles()
	var run_state = AppRefs.run_state()
	if run_state != null:
		run_state.deployed_count = 0
		run_state.core_hp = run_state.core_hp_max
		var event_bus = AppRefs.event_bus()
		if event_bus != null:
			event_bus.deploy_limit_changed.emit(run_state.deployed_count, run_state.deploy_limit)
			event_bus.core_hp_changed.emit(run_state.core_hp, run_state.core_hp_max)
	_refresh_path_warning()
	append_combat_debug("战场已清空")


func _clear_projectiles() -> void:
	if _projectile_root == null:
		return
	for child in _projectile_root.get_children():
		child.queue_free()


func _tick_spawn_queues(delta: float) -> void:
	for raw_key in _running_spawn_queues.keys().duplicate():
		var spawn_key := StringName(raw_key)
		var state: Dictionary = _running_spawn_queues[raw_key]
		state["timer"] = float(state.get("timer", 0.0)) - delta
		if float(state["timer"]) > 0.0:
			continue
		var items: Array = state.get("items", [])
		var index := int(state.get("index", 0))
		if index >= items.size():
			_running_spawn_queues.erase(raw_key)
			append_combat_debug("出怪点 %s 队列完成" % spawn_key)
			continue
		var item: Dictionary = items[index]
		_spawn_enemy_item(spawn_key, item)
		index += 1
		if index >= items.size():
			_running_spawn_queues.erase(raw_key)
			append_combat_debug("出怪点 %s 队列完成" % spawn_key)
		else:
			state["index"] = index
			state["timer"] = float((items[index] as Dictionary).get("delay", 0.0))


func _spawn_enemy_item(spawn_key: StringName, item: Dictionary) -> void:
	if _enemy_manager == null or _map_manager == null:
		return
	if _map_manager.has_method("has_spawn_key") and not _map_manager.has_spawn_key(spawn_key):
		append_combat_debug("出怪点 %s 已不存在" % spawn_key)
		return
	var enemy_id := StringName(item.get("enemy_id", ""))
	if enemy_id == StringName():
		return
	var spawn_cell: Vector2i = _map_manager.get_spawn_cell_by_key(spawn_key)
	var override := _make_enemy_override(item)
	_enemy_manager.spawn_enemy(enemy_id, spawn_cell, override)
	append_combat_debug("出怪点 %s 生成 %s：生命 %d 攻击 %d 防御 %d 法抗 %d" % [
		spawn_key,
		String(item.get("name", enemy_id)),
		int(item.get("max_hp", 1)),
		int(item.get("atk", 1)),
		int(item.get("def", 0)),
		int(item.get("res", 0))
	])


func _on_map_cell_clicked(cell: Vector2i) -> void:
	_handle_primary_map_click(cell)


func _handle_primary_map_click(cell: Vector2i) -> bool:
	if _deploy_drag_state != DRAG_NONE:
		return true
	if _map_manager == null or cell == INVALID_CELL or not _map_manager.is_inside(cell):
		return false
	if _debug_drawer_open:
		return _handle_editor_map_click(cell)
	_handle_map_cell_selection(cell)
	return true


func _handle_editor_map_click(cell: Vector2i) -> bool:
	if _selected_tool != TOOL_SELECT:
		return _apply_editor_tool_at_cell(cell, false)
	_clear_unit_selection_if_click_misses_unit(cell)
	var clicked_spawn_key := _get_spawn_key_at_cell(cell)
	if clicked_spawn_key != StringName():
		_select_spawn_from_map(clicked_spawn_key)
		return true
	_handle_map_cell_selection(cell)
	return true


func _update_editor_drag_paint() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_last_painted_cell = INVALID_CELL
		return
	if not _debug_drawer_open or _deploy_drag_state != DRAG_NONE:
		return
	if not _is_drag_editor_tool(_selected_tool):
		return
	if _is_pointer_over_debug_drawer():
		return
	_apply_editor_tool_at_cell(_get_mouse_cell(), true)


func _apply_editor_tool_at_cell(cell: Vector2i, is_drag: bool) -> bool:
	if _map_manager == null or cell == INVALID_CELL or not _map_manager.is_inside(cell):
		return false
	if is_drag and not _is_drag_editor_tool(_selected_tool):
		return false
	if cell == _last_painted_cell:
		return true
	_last_painted_cell = cell
	match _selected_tool:
		TOOL_BLOCK:
			return _paint_blocked_cell(cell, true, is_drag)
		TOOL_ERASE:
			return _paint_blocked_cell(cell, false, is_drag)
		TOOL_CORE:
			return _move_core_to_cell(cell)
		TOOL_SPAWN:
			return _use_spawn_tool(cell)
		TOOL_BUILDING:
			return _place_debug_building(cell, is_drag)
		TOOL_DELETE_BUILDING:
			return _delete_debug_building(cell, is_drag)
		_:
			return false


func _paint_blocked_cell(cell: Vector2i, blocked: bool, is_drag: bool) -> bool:
	if _map_manager == null or not _map_manager.has_method("set_debug_cell_blocked"):
		return false
	if not _map_manager.set_debug_cell_blocked(cell, blocked):
		if not is_drag:
			_show_message("该格不能编辑阻挡地块")
		return false
	_sync_debug_map_state_from_manager()
	_refresh_path_warning()
	return true


func _move_core_to_cell(cell: Vector2i) -> bool:
	if _map_manager == null or not _map_manager.has_method("set_debug_core"):
		return false
	if not _map_manager.set_debug_core(cell):
		_show_message("无法把核心移动到该格")
		return false
	_sync_debug_map_state_from_manager()
	_refresh_path_warning()
	_show_message("核心已移动到 %s" % cell)
	return true


func _use_spawn_tool(cell: Vector2i) -> bool:
	var clicked_spawn_key := _get_spawn_key_at_cell(cell)
	if clicked_spawn_key != StringName():
		_pending_spawn_action = SPAWN_ACTION_MOVE
		_select_spawn_from_map(clicked_spawn_key)
		return true
	if _pending_spawn_action == SPAWN_ACTION_ADD or _selected_spawn_key == StringName():
		return _create_spawn_at_cell(cell)
	_move_selected_spawn_to(cell)
	return true


func _create_spawn_at_cell(cell: Vector2i) -> bool:
	var spawn_key := _make_next_spawn_key()
	if _map_manager != null and _map_manager.has_method("upsert_debug_spawn"):
		if not _map_manager.upsert_debug_spawn(spawn_key, cell):
			_show_message("无法在该格放置出怪点")
			return false
	_spawn_defs[String(spawn_key)] = cell
	_spawn_queues[String(spawn_key)] = []
	_selected_spawn_key = spawn_key
	_selected_queue_index = -1
	_pending_spawn_action = SPAWN_ACTION_MOVE
	_sync_spawn_nodes()
	_refresh_editor_controls()
	_refresh_path_warning()
	append_combat_debug("已在 %s 添加出怪点 %s" % [cell, spawn_key])
	_show_message("已添加出怪点 %s；继续点击空格可移动它" % spawn_key)
	return true


func _place_debug_building(cell: Vector2i, is_drag: bool) -> bool:
	if _building_manager == null or not _building_manager.has_method("try_place_building_debug"):
		return false
	if _selected_building_id == StringName() and not _building_ids.is_empty():
		_selected_building_id = _building_ids[0]
	if _selected_building_id == StringName():
		if not is_drag:
			_show_message("没有可放置的建筑")
		return false
	var result: Dictionary = _building_manager.try_place_building_debug(cell, _selected_building_id)
	if not bool(result.get("ok", false)):
		if not is_drag:
			_show_result_message(result, "", "建筑无法放置")
		return false
	_refresh_path_warning()
	if not is_drag:
		_show_result_message(result, "建筑已放置", "建筑无法放置")
	return true


func _delete_debug_building(cell: Vector2i, is_drag: bool) -> bool:
	if _building_manager == null or not _building_manager.has_method("remove_building_at_cell"):
		return false
	if not bool(_building_manager.remove_building_at_cell(cell)):
		if not is_drag:
			_show_message("该格没有建筑")
		return false
	_refresh_path_warning()
	if not is_drag:
		_show_message("建筑已删除")
	return true


func _select_editor_tool(tool: StringName, message: String = "") -> void:
	if _deploy_drag_state != DRAG_NONE:
		_cancel_deploy_flow("")
	_selected_tool = tool
	if tool != TOOL_SPAWN:
		_pending_spawn_action = SPAWN_ACTION_NONE
	elif _pending_spawn_action == SPAWN_ACTION_NONE and _selected_spawn_key != StringName():
		_pending_spawn_action = SPAWN_ACTION_MOVE
	if tool != TOOL_SELECT:
		_clear_selected_unit_selection()
	_last_painted_cell = INVALID_CELL
	_refresh_tool_buttons()
	_show_message(message if not message.is_empty() else "当前工具：%s" % _tool_label(tool))


func _refresh_tool_buttons() -> void:
	for raw_tool in _tool_buttons.keys():
		var tool := StringName(raw_tool)
		var button := _tool_buttons[raw_tool] as Button
		if button != null:
			var selected := tool == _selected_tool
			button.button_pressed = selected
			_apply_button_style(button, selected)
	if _tool_chip_label != null:
		_tool_chip_label.text = "工具 %s" % _tool_label(_selected_tool)
	if _tool_help_label != null:
		_tool_help_label.text = _tool_help_text(_selected_tool)


func _tool_label(tool: StringName) -> String:
	match tool:
		TOOL_BLOCK:
			return "画阻挡"
		TOOL_ERASE:
			return "擦地块"
		TOOL_CORE:
			return "移动核心"
		TOOL_SPAWN:
			return "添加出怪点" if _pending_spawn_action == SPAWN_ACTION_ADD else "编辑出怪点"
		TOOL_BUILDING:
			return "放建筑"
		TOOL_DELETE_BUILDING:
			return "拆建筑"
		_:
			return "选择"


func _tool_help_text(tool: StringName) -> String:
	match tool:
		TOOL_BLOCK:
			return "在地图上点击或拖拽，把格子设为不可通行。不会阻止你堵死路径，但会显示路径警告。"
		TOOL_ERASE:
			return "在地图上点击或拖拽，清除阻挡地块。这个工具只处理地块，不会删除建筑。"
		TOOL_CORE:
			return "点击一个空地块移动核心。核心位置会保存到预设。"
		TOOL_SPAWN:
			if _pending_spawn_action == SPAWN_ACTION_ADD:
				return "点击空格放置新的出怪点；点击已有出怪点只切换当前队列。"
			if _selected_spawn_key != StringName():
				return "点击空格移动当前出怪点 %s；点击已有出怪点切换右侧队列。" % _selected_spawn_key
			return "点击空格新增或移动当前出怪点；点击已有出怪点会选中它并显示右侧队列。"
		TOOL_BUILDING:
			return "选择建筑类型后点击空地放置调试建筑。建筑不保存到预设，加载或重置时会清空。"
		TOOL_DELETE_BUILDING:
			return "点击已有建筑所在格删除建筑。"
		_:
			return "点击单位可查看攻击范围；点击出怪点会选中它并编辑右侧敌人队列。"


func _is_drag_editor_tool(tool: StringName) -> bool:
	return tool == TOOL_BLOCK or tool == TOOL_ERASE or tool == TOOL_DELETE_BUILDING


func _is_pointer_over_debug_drawer() -> bool:
	if _debug_drawer_panel == null or not _debug_drawer_panel.visible:
		return false
	return _debug_drawer_panel.get_global_rect().has_point(get_viewport().get_mouse_position())


func _on_preset_option_selected(_index: int) -> void:
	if _refreshing_editor_ui:
		return
	var preset := _get_selected_preset_option()
	if preset.is_empty():
		return
	_show_message("已选择预设 %s，点击加载以应用。" % String(preset.get("name", "")))


func _on_load_preset_pressed() -> void:
	if _preset_option == null or _preset_option.selected < 0:
		return
	_apply_preset_by_index(_preset_option.selected)


func _on_save_preset_pressed() -> void:
	_current_preset_name = _get_preset_name_from_input()
	var serialized := _serialize_current_preset()
	var index := _find_preset_index_by_id(_current_preset_id)
	if index >= 0:
		_presets[index] = serialized
	else:
		_presets.append(serialized)
	_save_presets_to_disk()
	_populate_preset_options()
	_select_preset_option_by_id(_current_preset_id)
	_show_message("已保存预设：%s" % _current_preset_name)
	append_combat_debug("已保存调试预设 %s 到 %s" % [_current_preset_name, PRESET_PATH])


func _on_save_new_preset_pressed() -> void:
	_current_preset_id = _make_new_preset_id()
	_current_preset_name = _get_preset_name_from_input()
	_presets.append(_serialize_current_preset())
	_save_presets_to_disk()
	_populate_preset_options()
	_select_preset_option_by_id(_current_preset_id)
	_show_message("已另存预设：%s" % _current_preset_name)
	append_combat_debug("已另存调试预设 %s" % _current_preset_name)


func _on_delete_preset_pressed() -> void:
	if _preset_option == null or _preset_option.selected < 0 or _preset_option.selected >= _presets.size():
		return
	var next_index := int(min(_preset_option.selected, _presets.size() - 2))
	var deleted_name := String(_presets[_preset_option.selected].get("name", "未命名"))
	_presets.remove_at(_preset_option.selected)
	if _presets.is_empty():
		_presets.append(_create_default_preset())
	_save_presets_to_disk()
	_populate_preset_options()
	_apply_preset_by_index(clamp(next_index, 0, _presets.size() - 1))
	_show_message("已删除预设：%s" % deleted_name)


func _on_spawn_option_selected(index: int) -> void:
	if _refreshing_editor_ui:
		return
	var keys := _get_spawn_keys()
	if index < 0 or index >= keys.size():
		return
	_selected_spawn_key = keys[index]
	_selected_queue_index = -1
	if _selected_tool == TOOL_SPAWN:
		_pending_spawn_action = SPAWN_ACTION_MOVE
	_refresh_editor_controls()
	_show_message("已选择出怪点 %s" % _selected_spawn_key)


func _on_building_option_selected(index: int) -> void:
	if index < 0 or index >= _building_ids.size():
		_selected_building_id = StringName()
		return
	_selected_building_id = _building_ids[index]
	_select_editor_tool(TOOL_BUILDING)


func _on_map_size_changed(_value: float) -> void:
	if _refreshing_editor_ui:
		return
	_apply_map_size_from_controls()


func _apply_map_size_from_controls() -> void:
	if _map_width_spin == null or _map_height_spin == null:
		return
	_debug_map_width = int(_map_width_spin.value)
	_debug_map_height = int(_map_height_spin.value)
	_debug_core_cell = _clamp_cell_to_map(_debug_core_cell)
	_reflow_spawn_defs_after_map_resize()
	var kept_blocked: Array[Vector2i] = []
	for cell in _debug_blocked_cells:
		if _is_cell_inside_debug_map(cell):
			kept_blocked.append(cell)
	_debug_blocked_cells = kept_blocked
	_apply_debug_map_from_state(true)
	_refresh_editor_controls()
	_show_message("地图尺寸已更新为 %dx%d，当前战斗运行态已清空" % [_debug_map_width, _debug_map_height])


func _on_add_spawn_pressed() -> void:
	_pending_spawn_action = SPAWN_ACTION_ADD
	_select_editor_tool(TOOL_SPAWN, "点击地图空格放置新的出怪点；点击已有出怪点只切换当前队列。")


func _on_delete_spawn_pressed() -> void:
	if _selected_spawn_key == StringName():
		_show_message("未选择出怪点")
		return
	var key := String(_selected_spawn_key)
	if _map_manager != null and _map_manager.has_method("remove_debug_spawn"):
		_map_manager.remove_debug_spawn(_selected_spawn_key)
	_spawn_defs.erase(key)
	_spawn_queues.erase(key)
	_running_spawn_queues.erase(key)
	append_combat_debug("已删除出怪点 %s 并清空队列" % _selected_spawn_key)
	var keys := _get_spawn_keys()
	_selected_spawn_key = keys[0] if not keys.is_empty() else StringName()
	_selected_queue_index = -1
	_pending_spawn_action = SPAWN_ACTION_MOVE if _selected_tool == TOOL_SPAWN and _selected_spawn_key != StringName() else SPAWN_ACTION_NONE
	_sync_spawn_nodes()
	_refresh_editor_controls()
	_show_message("已删除出怪点 %s" % key)


func _on_editor_tab_changed(_tab: int) -> void:
	if _is_tab_active("Spawns") and _selected_spawn_key != StringName():
		_show_message("点击已有出怪点进行选择，或点击空格移动 %s。" % _selected_spawn_key)


func _move_selected_spawn_to(cell: Vector2i) -> void:
	if _selected_spawn_key == StringName() or _map_manager == null:
		return
	if not _map_manager.has_method("upsert_debug_spawn") or not _map_manager.upsert_debug_spawn(_selected_spawn_key, cell):
		_show_message("无法把出怪点移动到该格")
		append_combat_debug("移动出怪点 %s 到 %s 失败" % [_selected_spawn_key, cell])
		return
	_spawn_defs[String(_selected_spawn_key)] = cell
	_pending_spawn_action = SPAWN_ACTION_MOVE
	_sync_spawn_nodes()
	_refresh_editor_controls()
	_refresh_path_warning()
	_show_message("已移动出怪点 %s 到 %s" % [_selected_spawn_key, cell])
	append_combat_debug("已移动出怪点 %s 到 %s" % [_selected_spawn_key, cell])


func _select_spawn_from_map(spawn_key: StringName) -> void:
	if not _spawn_defs.has(String(spawn_key)):
		return
	_selected_spawn_key = spawn_key
	_selected_queue_index = -1
	if _selected_tool == TOOL_SPAWN:
		_pending_spawn_action = SPAWN_ACTION_MOVE
	_refresh_editor_controls()
	_show_message("已从地图选择出怪点 %s" % spawn_key)
	append_combat_debug("已从地图选择出怪点 %s" % spawn_key)


func _on_add_enemy_item_pressed() -> void:
	var queue := _get_selected_queue()
	var enemy_id := _get_selected_enemy_id()
	if enemy_id == StringName() or _selected_spawn_key == StringName():
		_show_message("先选择出怪点和敌人")
		return
	queue.append(_make_enemy_queue_item(enemy_id, 0.0))
	_selected_queue_index = queue.size() - 1
	_refresh_editor_controls()


func _on_batch_append_pressed() -> void:
	var queue := _get_selected_queue()
	var enemy_id := _get_selected_enemy_id()
	if enemy_id == StringName() or _selected_spawn_key == StringName():
		_show_message("先选择出怪点和敌人")
		return
	var count := int(_batch_count_spin.value)
	var first_delay := float(_batch_first_delay_spin.value) if _batch_first_delay_spin != null else 0.0
	var delay := float(_batch_delay_spin.value)
	for i in range(count):
		var item_delay := first_delay if i == 0 else delay
		queue.append(_make_enemy_queue_item(enemy_id, item_delay))
	_selected_queue_index = queue.size() - 1
	_refresh_editor_controls()
	append_combat_debug("已向出怪点 %s 追加 %d 个 %s 条目" % [_selected_spawn_key, count, enemy_id])


func _on_queue_item_selected(index: int) -> void:
	_selected_queue_index = index
	_refresh_item_editor()


func _on_duplicate_queue_item_pressed() -> void:
	var queue := _get_selected_queue()
	if _selected_queue_index < 0 or _selected_queue_index >= queue.size():
		return
	queue.insert(_selected_queue_index + 1, (queue[_selected_queue_index] as Dictionary).duplicate(true))
	_selected_queue_index += 1
	_refresh_editor_controls()


func _on_remove_queue_item_pressed() -> void:
	var queue := _get_selected_queue()
	if _selected_queue_index < 0 or _selected_queue_index >= queue.size():
		return
	queue.remove_at(_selected_queue_index)
	_selected_queue_index = min(_selected_queue_index, queue.size() - 1)
	_refresh_editor_controls()


func _on_move_queue_item_up_pressed() -> void:
	var queue := _get_selected_queue()
	if _selected_queue_index <= 0 or _selected_queue_index >= queue.size():
		return
	_swap_queue_items(queue, _selected_queue_index, _selected_queue_index - 1)
	_selected_queue_index -= 1
	_refresh_editor_controls()


func _on_move_queue_item_down_pressed() -> void:
	var queue := _get_selected_queue()
	if _selected_queue_index < 0 or _selected_queue_index >= queue.size() - 1:
		return
	_swap_queue_items(queue, _selected_queue_index, _selected_queue_index + 1)
	_selected_queue_index += 1
	_refresh_editor_controls()


func _on_spawn_selected_queue_item_pressed() -> void:
	var item := _get_selected_queue_item()
	if item.is_empty() or _selected_spawn_key == StringName():
		return
	_spawn_enemy_item(_selected_spawn_key, item)


func _on_selected_item_property_changed(_value: Variant = null) -> void:
	if _refreshing_editor_ui:
		return
	var queue := _get_selected_queue()
	if _selected_queue_index < 0 or _selected_queue_index >= queue.size():
		return
	var item: Dictionary = queue[_selected_queue_index]
	item["enemy_id"] = String(_get_item_enemy_option_id())
	item["name"] = _item_name_edit.text
	item["delay"] = float(_item_delay_spin.value)
	item["max_hp"] = int(_item_hp_spin.value)
	item["atk"] = int(_item_atk_spin.value)
	item["def"] = int(_item_def_spin.value)
	item["res"] = int(_item_res_spin.value)
	item["move_speed"] = float(_item_speed_spin.value)
	item["attack_interval"] = float(_item_interval_spin.value)
	item["damage_type"] = _get_selected_damage_type()
	item["core_damage"] = int(_item_core_damage_spin.value)
	queue[_selected_queue_index] = item
	_refresh_queue_list(false)


func _on_start_selected_spawn_pressed() -> void:
	if _selected_spawn_key == StringName():
		_show_message("未选择出怪点")
		return
	if _start_spawn_queue(_selected_spawn_key):
		_refresh_editor_controls()


func _on_start_all_spawns_pressed() -> void:
	var started := 0
	for spawn_key in _get_spawn_keys():
		if _start_spawn_queue(spawn_key, false):
			started += 1
	_refresh_editor_controls()
	_show_message("已启动 %d 个出怪队列" % started)


func _on_stop_spawns_pressed() -> void:
	_running_spawn_queues.clear()
	_refresh_editor_controls()
	_show_message("已停止全部出怪队列")
	append_combat_debug("已停止全部出怪队列")


func _on_cast_skill_pressed() -> void:
	var unit := _get_selected_unit()
	if unit == null or _unit_manager == null:
		return
	var result: Dictionary = _unit_manager.try_cast_skill(unit.get_runtime_id())
	_show_result_message(result, "技能已释放", "技能释放失败")


func _on_retreat_pressed() -> void:
	var unit := _get_selected_unit()
	if unit == null or _unit_manager == null:
		return
	var result: Dictionary = _unit_manager.try_retreat_unit(unit.get_runtime_id())
	if result.get("ok", false):
		_selected_unit_runtime_id = -1
	_show_result_message(result, "已撤退", "撤退失败")


func _on_clear_pressed() -> void:
	_clear_battlefield()
	_show_message("战斗运行态已清空")


func _on_reset_pressed() -> void:
	_reset_sandbox()
	_show_message("沙盒已重置")


func _on_operator_item_selected(index: int) -> void:
	if _refreshing_editor_ui:
		return
	if index < 0 or index >= _operator_defs.size():
		return
	var operator_info: Dictionary = _operator_defs[index]
	_selected_operator_key = StringName(operator_info.get("key", ""))
	var deployed_unit = _unit_manager.get_unit_by_operator_key(_selected_operator_key) if _unit_manager != null and _unit_manager.has_method("get_unit_by_operator_key") else null
	_selected_unit_runtime_id = deployed_unit.get_runtime_id() if deployed_unit != null else -1
	_refresh_attack_range_preview()
	_refresh_operator_list()
	_show_message("已选择干员槽位：%s" % _format_operator_label(operator_info))


func _on_add_operator_pressed() -> void:
	_show_message("战斗沙盒部署区固定包含全部干员")


func _on_delete_operator_pressed() -> void:
	_show_message("战斗沙盒部署区固定包含全部干员")


func _on_unit_deployed(unit_runtime_id: int, operator_key: StringName, _unit_id: StringName, _cell: Vector2i) -> void:
	_selected_operator_key = operator_key
	_selected_unit_runtime_id = unit_runtime_id
	_select_operator_item(operator_key)
	_refresh_attack_range_preview()
	_update_operator_card_states()
	_refresh_detail_panel()


func _on_unit_removed(unit_runtime_id: int, _reason: int) -> void:
	if _selected_unit_runtime_id == unit_runtime_id:
		_selected_unit_runtime_id = -1
		_refresh_attack_range_preview()
	_refresh_operator_list()
	_update_operator_card_states()
	_refresh_detail_panel()


func _on_operator_redeploy_completed(operator_key: StringName) -> void:
	_refresh_operator_list()
	_update_operator_card_states()
	if _cooldown_message_operator_key == operator_key:
		_show_message("%s 已可部署" % _get_operator_display_name(operator_key))


func _start_spawn_queue(spawn_key: StringName, show_feedback: bool = true) -> bool:
	if spawn_key == StringName():
		return false
	var queue := _get_queue(spawn_key)
	if queue.is_empty():
		if show_feedback:
			_show_message("出怪点 %s 队列为空" % spawn_key)
		return false
	var key := String(spawn_key)
	var items: Array = []
	for item in queue:
		items.append((item as Dictionary).duplicate(true))
	_running_spawn_queues[key] = {
		"items": items,
		"index": 0,
		"timer": float((items[0] as Dictionary).get("delay", 0.0))
	}
	append_combat_debug("已启动出怪点 %s 队列" % spawn_key)
	if show_feedback:
		_show_message("已启动出怪点 %s 队列" % spawn_key)
	return true


func _refresh_editor_controls() -> void:
	_refreshing_editor_ui = true
	_populate_spawn_options()
	_refresh_operator_list()
	_refresh_queue_list()
	_refresh_item_editor()
	_refresh_debug_map_controls()
	if _preset_name_edit != null:
		_preset_name_edit.text = _current_preset_name
	_refreshing_editor_ui = false
	_refresh_status()
	_refresh_path_warning()
	_rebuild_deploy_deck()


func _refresh_status() -> void:
	if _status_label == null:
		return
	var run_state = AppRefs.run_state()
	var unit_count: int = _unit_manager.get_all_deployed_units().size() if _unit_manager != null else 0
	var enemy_count: int = _enemy_manager.get_alive_enemy_count() if _enemy_manager != null else 0
	var core_text := "%d/%d" % [run_state.core_hp, run_state.core_hp_max] if run_state != null else "?"
	var selected_text := "无"
	var selected_unit := _get_selected_unit()
	if selected_unit != null:
		selected_text = "%s 生命 %d/%d 技力 %.0f/%.0f" % [
			_get_operator_display_name(StringName(selected_unit.operator_key)),
			selected_unit.current_hp,
			selected_unit.max_hp,
			selected_unit.sp,
			float(selected_unit.cfg.get("sp_max", 0.0))
		]
	elif _selected_operator_key != StringName():
		selected_text = "%s %s" % [_get_operator_display_name(_selected_operator_key), _get_operator_state_text(_selected_operator_key)]
	var selected_spawn_text := String(_selected_spawn_key) if _selected_spawn_key != StringName() else "无"
	if _unit_chip_label != null:
		_unit_chip_label.text = "单位 %d" % unit_count
	if _enemy_chip_label != null:
		_enemy_chip_label.text = "敌人 %d" % enemy_count
	if _core_chip_label != null:
		_core_chip_label.text = "核心 %s" % core_text
	if _tool_chip_label != null:
		_tool_chip_label.text = "工具 %s" % _tool_label(_selected_tool)
	_status_label.text = "地图 %dx%d  队列 %d  预设：%s  出怪点：%s\n选择：%s" % [
		_debug_map_width,
		_debug_map_height,
		_running_spawn_queues.size(),
		_current_preset_name,
		selected_spawn_text,
		selected_text
	]


func _refresh_debug_map_controls() -> void:
	if _map_width_spin != null:
		_map_width_spin.value = float(_debug_map_width)
	if _map_height_spin != null:
		_map_height_spin.value = float(_debug_map_height)
	if _building_option != null and _selected_building_id != StringName():
		for index in range(_building_ids.size()):
			if _building_ids[index] == _selected_building_id:
				_building_option.select(index)
				break
	_refresh_tool_buttons()


func _refresh_path_warning() -> void:
	if _path_warning_label == null:
		return
	if _path_service == null or _map_manager == null:
		_path_warning_label.text = ""
		return
	var blocked_spawns: Array[String] = []
	for spawn_key in _get_spawn_keys():
		var cell: Vector2i = _spawn_defs[String(spawn_key)]
		if not _path_service.has_path(cell, _debug_core_cell):
			blocked_spawns.append(String(spawn_key))
	if blocked_spawns.is_empty():
		_path_warning_label.text = "路径状态：所有出怪点可达核心。"
	else:
		_path_warning_label.text = "路径警告：%s 无路可达核心。" % ", ".join(blocked_spawns)


func _refresh_skill_info(selected_unit: Node) -> void:
	if _skill_info_label == null:
		return
	if selected_unit == null:
		_skill_info_label.text = "技能：未选中单位"
		return
	var cfg: Dictionary = selected_unit.cfg
	var skill_name := String(cfg.get("skill_name", cfg.get("skill_id", "未配置技能")))
	var skill_desc := String(cfg.get("skill_description", "暂无技能说明。"))
	var sp_max := float(cfg.get("sp_max", 0.0))
	var sp_text := "无技力"
	if sp_max > 0.0:
		sp_text = "技力 %.0f/%.0f" % [selected_unit.sp, sp_max]
	_skill_info_label.text = "技能：%s（%s）\n%s" % [skill_name, sp_text, skill_desc]


func _refresh_queue_list(update_item_editor: bool = true) -> void:
	if _queue_list == null:
		return
	var queue := _get_selected_queue()
	if _selected_queue_index >= queue.size():
		_selected_queue_index = queue.size() - 1
	_queue_list.clear()
	for index in range(queue.size()):
		var item: Dictionary = queue[index]
		_queue_list.add_item("%02d +%.2fs  %s  HP%d A%d D%d R%d" % [
			index + 1,
			float(item.get("delay", 0.0)),
			String(item.get("name", item.get("enemy_id", ""))),
			int(item.get("max_hp", 1)),
			int(item.get("atk", 1)),
			int(item.get("def", 0)),
			int(item.get("res", 0))
		])
	if _selected_queue_index >= 0 and _selected_queue_index < queue.size():
		_queue_list.select(_selected_queue_index)
	if _queue_hint_label != null:
		var spawn_label := String(_selected_spawn_key) if _selected_spawn_key != StringName() else "无"
		_queue_hint_label.text = "当前：%s    条目：%d" % [spawn_label, queue.size()]
	if update_item_editor:
		_refresh_item_editor()


func _refresh_item_editor() -> void:
	if _item_name_edit == null:
		return
	_refreshing_editor_ui = true
	var item := _get_selected_queue_item()
	var has_item := not item.is_empty()
	_item_name_edit.editable = has_item
	_item_enemy_option.disabled = not has_item
	_item_damage_type_option.disabled = not has_item
	for spin in [_item_delay_spin, _item_hp_spin, _item_atk_spin, _item_def_spin, _item_res_spin, _item_speed_spin, _item_interval_spin, _item_core_damage_spin]:
		spin.editable = has_item
	if has_item:
		_select_enemy_option(_item_enemy_option, StringName(item.get("enemy_id", "")))
		_item_name_edit.text = String(item.get("name", ""))
		_item_delay_spin.value = float(item.get("delay", 0.0))
		_item_hp_spin.value = float(item.get("max_hp", 1))
		_item_atk_spin.value = float(item.get("atk", 1))
		_item_def_spin.value = float(item.get("def", 0))
		_item_res_spin.value = float(item.get("res", 0))
		_item_speed_spin.value = float(item.get("move_speed", 1.0))
		_item_interval_spin.value = float(item.get("attack_interval", 1.0))
		_item_core_damage_spin.value = float(item.get("core_damage", 1))
		_select_damage_type(String(item.get("damage_type", "physical")))
	else:
		_item_name_edit.text = ""
		_item_delay_spin.value = 0.0
		_item_hp_spin.value = 1.0
		_item_atk_spin.value = 1.0
		_item_def_spin.value = 0.0
		_item_res_spin.value = 0.0
		_item_speed_spin.value = 1.0
		_item_interval_spin.value = 1.0
		_item_core_damage_spin.value = 1.0
	_refreshing_editor_ui = false


func _load_presets_from_disk() -> void:
	_presets.clear()
	if FileAccess.file_exists(PRESET_PATH):
		var file := FileAccess.open(PRESET_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_ARRAY:
				for preset_variant in parsed:
					if typeof(preset_variant) == TYPE_DICTIONARY:
						_presets.append((preset_variant as Dictionary).duplicate(true))
	if _presets.is_empty():
		_presets.append(_create_default_preset())


func _save_presets_to_disk() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PRESET_DIR))
	var file := FileAccess.open(PRESET_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write combat sandbox presets: %s" % PRESET_PATH)
		return
	file.store_string(JSON.stringify(_presets, "\t"))


func _apply_preset_by_index(index: int) -> void:
	if _presets.is_empty():
		_presets.append(_create_default_preset())
	index = clamp(index, 0, _presets.size() - 1)
	var preset: Dictionary = _presets[index]
	_current_preset_id = String(preset.get("id", "default"))
	_current_preset_name = String(preset.get("name", "默认调试预设"))
	_operator_defs = _create_all_operator_defs()
	_parse_map_state(preset.get("map", {}))
	_spawn_defs = _parse_spawn_defs(preset.get("spawns", []))
	_spawn_queues = _parse_spawn_queues(preset.get("queues", {}))
	for spawn_key in _spawn_defs.keys():
		if not _spawn_queues.has(String(spawn_key)):
			_spawn_queues[String(spawn_key)] = []
	var keys := _get_spawn_keys()
	_selected_spawn_key = keys[0] if not keys.is_empty() else StringName()
	_selected_operator_key = _get_first_operator_key()
	_selected_queue_index = -1
	_next_spawn_index = _calc_next_spawn_index()
	_select_preset_option_by_id(_current_preset_id)
	_reset_sandbox()
	_show_message("已加载预设：%s" % _current_preset_name)


func _create_default_preset() -> Dictionary:
	return {
		"id": "default",
		"name": "默认三路测试",
		"map": {
			"width": SANDBOX_WIDTH,
			"height": SANDBOX_HEIGHT,
			"core": [SANDBOX_CORE.x, SANDBOX_CORE.y],
			"mountain": []
		},
		"spawns": [
			{"key": "S1", "cell": [0, 3]},
			{"key": "S2", "cell": [0, 1]},
			{"key": "S3", "cell": [0, 5]}
		],
		"queues": {
			"S1": [
				{"enemy_id": "slime", "delay": 0.0, "name": "源石虫", "max_hp": 80, "atk": 18, "def": 2, "res": 0, "move_speed": 1.0, "attack_interval": 1.2, "damage_type": "physical", "core_damage": 1}
			],
			"S2": [
				{"enemy_id": "lumberjack_veteran", "delay": 0.5, "name": "伐木老手", "max_hp": 210, "atk": 42, "def": 10, "res": 0, "move_speed": 0.72, "attack_interval": 1.45, "damage_type": "physical", "behavior_type": "demolisher", "core_damage": 1}
			],
			"S3": []
		}
	}


func _create_all_operator_defs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data_repo = AppRefs.data_repo()
	if data_repo == null or not data_repo.has_method("get_all_unit_ids"):
		return result
	var unit_ids: Array[StringName] = data_repo.get_all_unit_ids()
	for unit_id in unit_ids:
		var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
		if cfg.is_empty():
			continue
		result.append({
			"key": String(unit_id),
			"unit_id": String(unit_id),
			"name": String(cfg.get("name", unit_id))
		})
	return result


func _parse_map_state(raw_map: Variant) -> void:
	_debug_map_width = SANDBOX_WIDTH
	_debug_map_height = SANDBOX_HEIGHT
	_debug_core_cell = SANDBOX_CORE
	_debug_blocked_cells.clear()
	if typeof(raw_map) != TYPE_DICTIONARY:
		return
	var map_dict: Dictionary = raw_map
	_debug_map_width = max(1, int(map_dict.get("width", SANDBOX_WIDTH)))
	_debug_map_height = max(1, int(map_dict.get("height", SANDBOX_HEIGHT)))
	_debug_core_cell = _clamp_cell_to_map(_parse_cell(map_dict.get("core", [SANDBOX_CORE.x, SANDBOX_CORE.y]), SANDBOX_CORE))
	_debug_blocked_cells = _parse_blocked_cells(map_dict.get("mountain", map_dict.get("blocked", [])))


func _parse_spawn_defs(raw_spawns: Variant) -> Dictionary:
	var result := {}
	if typeof(raw_spawns) == TYPE_ARRAY:
		for entry_variant in raw_spawns:
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_variant
			var key := String(entry.get("key", ""))
			if key.is_empty():
				continue
			var cell := _clamp_cell_to_map(_parse_cell(entry.get("cell", [0, 0]), Vector2i.ZERO))
			if cell == _debug_core_cell:
				continue
			result[key] = cell
	if result.is_empty():
		for key in DEFAULT_SPAWNS.keys():
			var default_cell: Vector2i = _clamp_cell_to_map(DEFAULT_SPAWNS[key])
			if default_cell != _debug_core_cell:
				result[String(key)] = default_cell
	return result


func _parse_spawn_queues(raw_queues: Variant) -> Dictionary:
	var result := {}
	if typeof(raw_queues) != TYPE_DICTIONARY:
		return result
	var raw_dict: Dictionary = raw_queues
	for raw_key in raw_dict.keys():
		var key := String(raw_key)
		var queue: Array = []
		var raw_queue: Variant = raw_dict[raw_key]
		if typeof(raw_queue) == TYPE_ARRAY:
			for item_variant in raw_queue:
				if typeof(item_variant) == TYPE_DICTIONARY:
					queue.append(_normalize_queue_item(item_variant as Dictionary))
		result[key] = queue
	return result


func _parse_cell(raw_cell: Variant, fallback: Vector2i) -> Vector2i:
	if typeof(raw_cell) == TYPE_ARRAY:
		var raw_array: Array = raw_cell
		if raw_array.size() >= 2:
			return Vector2i(int(raw_array[0]), int(raw_array[1]))
	if typeof(raw_cell) == TYPE_DICTIONARY:
		var raw_dict: Dictionary = raw_cell
		return Vector2i(int(raw_dict.get("x", fallback.x)), int(raw_dict.get("y", fallback.y)))
	return fallback


func _parse_blocked_cells(raw_blocked: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if typeof(raw_blocked) != TYPE_ARRAY:
		return result
	for raw_cell in raw_blocked:
		var cell := _parse_cell(raw_cell, INVALID_CELL)
		if cell == INVALID_CELL:
			continue
		if not _is_cell_inside_debug_map(cell):
			continue
		if cell == _debug_core_cell:
			continue
		if not result.has(cell):
			result.append(cell)
	return result


func _serialize_current_preset() -> Dictionary:
	var spawns: Array = []
	for spawn_key in _get_spawn_keys():
		var cell: Vector2i = _spawn_defs[String(spawn_key)]
		spawns.append({"key": String(spawn_key), "cell": [cell.x, cell.y]})
	var queues := {}
	for raw_key in _spawn_defs.keys():
		var key := String(raw_key)
		var serialized_queue: Array = []
		for item in _get_queue(StringName(key)):
			serialized_queue.append(_serialize_queue_item(item as Dictionary))
		queues[key] = serialized_queue
	return {
		"id": _current_preset_id,
		"name": _current_preset_name,
		"map": _serialize_debug_map_state(),
		"spawns": spawns,
		"queues": queues
	}


func _serialize_debug_map_state() -> Dictionary:
	if _map_manager != null and _map_manager.has_method("get_debug_map_state"):
		var map_state: Dictionary = _map_manager.get_debug_map_state()
		_debug_map_width = int(map_state.get("width", _debug_map_width))
		_debug_map_height = int(map_state.get("height", _debug_map_height))
		_debug_core_cell = _parse_cell(map_state.get("core", [_debug_core_cell.x, _debug_core_cell.y]), _debug_core_cell)
		_debug_blocked_cells = _parse_blocked_cells(map_state.get("mountain", map_state.get("blocked", [])))
	return {
		"width": _debug_map_width,
		"height": _debug_map_height,
		"core": [_debug_core_cell.x, _debug_core_cell.y],
		"mountain": _serialize_blocked_cells()
	}


func _serialize_blocked_cells() -> Array:
	var cells: Array = []
	for cell in _debug_blocked_cells:
		cells.append([cell.x, cell.y])
	return cells


func _sync_debug_map_state_from_manager() -> void:
	if _map_manager == null or not _map_manager.has_method("get_debug_map_state"):
		return
	var map_state: Dictionary = _map_manager.get_debug_map_state()
	_debug_map_width = int(map_state.get("width", _debug_map_width))
	_debug_map_height = int(map_state.get("height", _debug_map_height))
	_debug_core_cell = _parse_cell(map_state.get("core", [_debug_core_cell.x, _debug_core_cell.y]), _debug_core_cell)
	_debug_blocked_cells = _parse_blocked_cells(map_state.get("mountain", map_state.get("blocked", [])))
	var was_refreshing := _refreshing_editor_ui
	_refreshing_editor_ui = true
	_refresh_debug_map_controls()
	_refreshing_editor_ui = was_refreshing


func _serialize_queue_item(item: Dictionary) -> Dictionary:
	var serialized := item.duplicate(true)
	serialized["enemy_id"] = String(item.get("enemy_id", ""))
	serialized["delay"] = float(item.get("delay", 0.0))
	serialized["name"] = String(item.get("name", ""))
	serialized["max_hp"] = int(item.get("max_hp", 1))
	serialized["atk"] = int(item.get("atk", 1))
	serialized["def"] = int(item.get("def", 0))
	serialized["res"] = int(item.get("res", 0))
	serialized["move_speed"] = float(item.get("move_speed", 1.0))
	serialized["attack_interval"] = float(item.get("attack_interval", 1.0))
	serialized["damage_type"] = String(item.get("damage_type", "physical"))
	serialized["core_damage"] = int(item.get("core_damage", 1))
	return serialized


func _normalize_queue_item(raw_item: Dictionary) -> Dictionary:
	var enemy_id := StringName(raw_item.get("enemy_id", _get_default_enemy_id()))
	var item := _make_enemy_queue_item(enemy_id, float(raw_item.get("delay", 0.0)))
	for key in raw_item.keys():
		item[key] = raw_item[key]
	item["enemy_id"] = String(enemy_id)
	item["delay"] = float(item.get("delay", 0.0))
	item["max_hp"] = int(item.get("max_hp", 1))
	item["atk"] = int(item.get("atk", 1))
	item["def"] = int(item.get("def", 0))
	item["res"] = int(item.get("res", 0))
	item["move_speed"] = float(item.get("move_speed", 1.0))
	item["attack_interval"] = float(item.get("attack_interval", 1.0))
	item["damage_type"] = String(item.get("damage_type", "physical"))
	item["core_damage"] = int(item.get("core_damage", 1))
	return item


func _make_enemy_queue_item(enemy_id: StringName, delay: float) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	var cfg: Dictionary = data_repo.get_enemy_cfg(enemy_id) if data_repo != null else {}
	return {
		"enemy_id": String(enemy_id),
		"delay": delay,
		"name": String(cfg.get("name", enemy_id)),
		"max_hp": int(cfg.get("max_hp", 1)),
		"atk": int(cfg.get("atk", 1)),
		"def": int(cfg.get("def", 0)),
		"res": int(cfg.get("res", 0)),
		"move_speed": float(cfg.get("move_speed", 1.0)),
		"attack_interval": float(cfg.get("attack_interval", 1.0)),
		"damage_type": String(cfg.get("damage_type", "physical")),
		"core_damage": int(cfg.get("core_damage", 1))
	}


func _make_enemy_override(item: Dictionary) -> Dictionary:
	var override := _serialize_queue_item(item)
	override.erase("enemy_id")
	override.erase("delay")
	return override


func _apply_debug_map_from_state(clear_runtime: bool = true) -> void:
	if _map_manager == null:
		return
	if clear_runtime:
		_clear_runtime_for_map_rebuild()
	if _building_manager != null and _building_manager.has_method("clear_all_buildings"):
		_building_manager.clear_all_buildings()
	var spawn_defs := {}
	for raw_key in _spawn_defs.keys():
		spawn_defs[StringName(raw_key)] = _spawn_defs[raw_key]
	if _map_manager.has_method("generate_debug_map"):
		_map_manager.generate_debug_map(_debug_map_width, _debug_map_height, _debug_core_cell, spawn_defs, _serialize_blocked_cells())
	_sync_spawn_nodes()
	if _path_service != null and _path_service.has_method("rebuild_from_map"):
		_path_service.rebuild_from_map()
	_sync_debug_map_state_from_manager()
	_refresh_path_warning()


func _clear_runtime_for_map_rebuild() -> void:
	_cancel_deploy_flow("")
	_running_spawn_queues.clear()
	_selected_unit_runtime_id = -1
	_clear_attack_range_preview()
	if _enemy_manager != null and _enemy_manager.has_method("clear_all_enemies"):
		_enemy_manager.clear_all_enemies()
	if _unit_manager != null and _unit_manager.has_method("clear_all_units"):
		_unit_manager.clear_all_units()
	_clear_projectiles()
	var run_state = AppRefs.run_state()
	if run_state != null:
		run_state.deployed_count = 0
		run_state.core_hp = run_state.core_hp_max
		var event_bus = AppRefs.event_bus()
		if event_bus != null:
			event_bus.deploy_limit_changed.emit(run_state.deployed_count, run_state.deploy_limit)
			event_bus.core_hp_changed.emit(run_state.core_hp, run_state.core_hp_max)


func _sync_spawn_nodes() -> void:
	if _spawn_root == null:
		return
	for child in _spawn_root.get_children():
		_spawn_root.remove_child(child)
		child.queue_free()
	for spawn_key in _get_spawn_keys():
		var marker := SPAWN_POINT_SCENE.instantiate()
		marker.name = "SpawnPoint%s" % String(spawn_key)
		marker.set("spawn_key", spawn_key)
		_spawn_root.add_child(marker)
	if _map_manager != null and _map_manager.has_method("refresh_all_layers"):
		_map_manager.refresh_all_layers()


func _populate_preset_options() -> void:
	if _preset_option == null:
		return
	_refreshing_editor_ui = true
	_preset_option.clear()
	for preset in _presets:
		_preset_option.add_item(String(preset.get("name", preset.get("id", "Unnamed"))))
	_refreshing_editor_ui = false


func _populate_spawn_options() -> void:
	if _spawn_option == null:
		return
	_refreshing_editor_ui = true
	_spawn_option.clear()
	var keys := _get_spawn_keys()
	for index in range(keys.size()):
		var spawn_key := keys[index]
		var cell: Vector2i = _spawn_defs[String(spawn_key)]
		_spawn_option.add_item("%s  %s" % [String(spawn_key), cell])
		if spawn_key == _selected_spawn_key:
			_spawn_option.select(index)
	_refreshing_editor_ui = false


func _populate_unit_options() -> void:
	if _unit_option == null:
		return
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return
	_unit_option.clear()
	_unit_ids = data_repo.get_all_unit_ids()
	for unit_id in _unit_ids:
		var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
		_unit_option.add_item(String(cfg.get("name", unit_id)))


func _refresh_operator_list() -> void:
	if _operator_list == null:
		return
	_refreshing_editor_ui = true
	var previous_selected := _selected_operator_key
	_operator_list.clear()
	for index in range(_operator_defs.size()):
		var operator_info: Dictionary = _operator_defs[index]
		var operator_key := StringName(operator_info.get("key", ""))
		_operator_list.add_item(_format_operator_list_item(operator_info))
		if operator_key == previous_selected:
			_operator_list.select(index)
	_refreshing_editor_ui = false


func _select_operator_item(operator_key: StringName) -> void:
	if _operator_list == null:
		return
	for index in range(_operator_defs.size()):
		if StringName((_operator_defs[index] as Dictionary).get("key", "")) == operator_key:
			_operator_list.select(index)
			return


func _format_operator_list_item(operator_info: Dictionary) -> String:
	var operator_key := StringName(operator_info.get("key", ""))
	var state_text := _get_operator_state_text(operator_key)
	var unit_id := StringName(operator_info.get("unit_id", ""))
	var cd_text := ""
	if _unit_manager != null and _unit_manager.has_method("get_operator_redeploy_remaining"):
		var remain := float(_unit_manager.get_operator_redeploy_remaining(operator_key))
		if remain > 0.0:
			cd_text = " %.1fs" % remain
	return "%s  %s%s  [%s]" % [_format_operator_label(operator_info), state_text, cd_text, String(unit_id)]


func _format_operator_label(operator_info: Dictionary) -> String:
	return "%s(%s)" % [String(operator_info.get("name", operator_info.get("key", ""))), String(operator_info.get("key", ""))]


func _populate_enemy_options() -> void:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return
	_enemy_ids = data_repo.get_all_enemy_ids()
	for option in [_enemy_option, _item_enemy_option]:
		if option == null:
			continue
		option.clear()
		for enemy_id in _enemy_ids:
			var cfg: Dictionary = data_repo.get_enemy_cfg(enemy_id)
			option.add_item(String(cfg.get("name", enemy_id)))


func _populate_building_options() -> void:
	if _building_option == null:
		return
	var data_repo = AppRefs.data_repo()
	if data_repo == null or not data_repo.has_method("get_all_building_ids"):
		return
	_building_option.clear()
	_building_ids = data_repo.get_all_building_ids()
	for building_id in _building_ids:
		var cfg: Dictionary = data_repo.get_building_cfg(building_id)
		_building_option.add_item(String(cfg.get("name", building_id)))
	if not _building_ids.is_empty():
		_selected_building_id = _building_ids[0]
		_building_option.select(0)


func _populate_direction_options() -> void:
	if _facing_option == null:
		return
	_facing_option.clear()
	for text in ["Right", "Down", "Left", "Up"]:
		_facing_option.add_item(text)


func _populate_damage_type_options() -> void:
	if _item_damage_type_option == null:
		return
	_item_damage_type_option.clear()
	for label in DAMAGE_TYPE_LABELS:
		_item_damage_type_option.add_item(label)


func _get_selected_preset_option() -> Dictionary:
	if _preset_option == null or _preset_option.selected < 0 or _preset_option.selected >= _presets.size():
		return {}
	return _presets[_preset_option.selected]


func _get_selected_operator_key() -> StringName:
	if _selected_operator_key != StringName():
		return _selected_operator_key
	if _operator_list != null and _operator_list.get_selected_items().size() > 0:
		var index := int(_operator_list.get_selected_items()[0])
		if index >= 0 and index < _operator_defs.size():
			return StringName((_operator_defs[index] as Dictionary).get("key", ""))
	return StringName()


func _get_first_operator_key() -> StringName:
	if _operator_defs.is_empty():
		return StringName()
	return StringName((_operator_defs[0] as Dictionary).get("key", ""))


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


func _get_operator_state_text(operator_key: StringName) -> String:
	if _unit_manager == null or not _unit_manager.has_method("get_operator_status"):
		return "可部署"
	match StringName(_unit_manager.get_operator_status(operator_key)):
		&"deployed":
			return "已部署"
		&"cooldown":
			return "冷却中"
		_:
			return "可部署"


func _get_selected_enemy_id() -> StringName:
	if _enemy_option == null or _enemy_option.selected < 0 or _enemy_option.selected >= _enemy_ids.size():
		return StringName()
	return _enemy_ids[_enemy_option.selected]


func _get_item_enemy_option_id() -> StringName:
	if _item_enemy_option == null or _item_enemy_option.selected < 0 or _item_enemy_option.selected >= _enemy_ids.size():
		return _get_default_enemy_id()
	return _enemy_ids[_item_enemy_option.selected]


func _get_default_enemy_id() -> StringName:
	return _enemy_ids[0] if not _enemy_ids.is_empty() else StringName()


func _get_selected_facing() -> Vector2i:
	if _facing_option == null:
		return Vector2i.RIGHT
	match _facing_option.selected:
		1:
			return Vector2i.DOWN
		2:
			return Vector2i.LEFT
		3:
			return Vector2i.UP
		_:
			return Vector2i.RIGHT


func _get_selected_damage_type() -> String:
	if _item_damage_type_option == null or _item_damage_type_option.selected < 0 or _item_damage_type_option.selected >= DAMAGE_TYPE_OPTIONS.size():
		return "physical"
	return DAMAGE_TYPE_OPTIONS[_item_damage_type_option.selected]


func _get_spawn_key_at_cell(cell: Vector2i) -> StringName:
	if _map_manager == null or not _map_manager.has_method("get_spawn_key_at_cell"):
		return StringName()
	return _map_manager.get_spawn_key_at_cell(cell)


func _get_selected_unit() -> Node:
	if _unit_manager == null or _selected_unit_runtime_id < 0:
		return null
	var unit = _unit_manager.get_unit_by_runtime_id(_selected_unit_runtime_id)
	if unit == null or not is_instance_valid(unit):
		_selected_unit_runtime_id = -1
		return null
	return unit


func _get_selected_queue() -> Array:
	return _get_queue(_selected_spawn_key)


func _get_queue(spawn_key: StringName) -> Array:
	var key := String(spawn_key)
	if key.is_empty():
		return []
	if not _spawn_queues.has(key):
		_spawn_queues[key] = []
	return _spawn_queues[key]


func _get_selected_queue_item() -> Dictionary:
	var queue := _get_selected_queue()
	if _selected_queue_index < 0 or _selected_queue_index >= queue.size():
		return {}
	return queue[_selected_queue_index]


func _get_spawn_keys() -> Array[StringName]:
	var raw_keys := _spawn_defs.keys()
	raw_keys.sort()
	var result: Array[StringName] = []
	for key in raw_keys:
		result.append(StringName(key))
	return result


func _make_next_spawn_key() -> StringName:
	while _spawn_defs.has("S%d" % _next_spawn_index):
		_next_spawn_index += 1
	var spawn_key := StringName("S%d" % _next_spawn_index)
	_next_spawn_index += 1
	return spawn_key


func _calc_next_spawn_index() -> int:
	var max_index := 0
	for raw_key in _spawn_defs.keys():
		var key := String(raw_key)
		if key.begins_with("S") and key.substr(1).is_valid_int():
			max_index = max(max_index, int(key.substr(1)))
	return max_index + 1


func _reflow_spawn_defs_after_map_resize() -> void:
	var reserved := {}
	for raw_key in _get_spawn_keys():
		var key := String(raw_key)
		var preferred: Vector2i = _clamp_cell_to_map(_spawn_defs[key])
		var cell := _find_available_spawn_cell(preferred, reserved, false)
		if cell == INVALID_CELL:
			_spawn_defs.erase(key)
			_spawn_queues.erase(key)
			_running_spawn_queues.erase(key)
			if String(_selected_spawn_key) == key:
				_selected_spawn_key = StringName()
			continue
		_spawn_defs[key] = cell
		reserved[cell] = true
	var keys := _get_spawn_keys()
	if _selected_spawn_key == StringName() and not keys.is_empty():
		_selected_spawn_key = keys[0]


func _find_available_spawn_cell(preferred: Vector2i, reserved: Dictionary = {}, check_existing_spawns: bool = true) -> Vector2i:
	if _can_use_spawn_cell_with_reserved(preferred, reserved, check_existing_spawns):
		return preferred
	for y in range(_debug_map_height):
		var cell := Vector2i(0, y)
		if _can_use_spawn_cell_with_reserved(cell, reserved, check_existing_spawns):
			return cell
	for y in range(_debug_map_height):
		for x in range(_debug_map_width):
			var cell := Vector2i(x, y)
			if _can_use_spawn_cell_with_reserved(cell, reserved, check_existing_spawns):
				return cell
	return INVALID_CELL


func _can_use_spawn_cell_with_reserved(cell: Vector2i, reserved: Dictionary = {}, check_existing_spawns: bool = true) -> bool:
	if cell == _debug_core_cell:
		return false
	if reserved.has(cell):
		return false
	if check_existing_spawns:
		for used_cell in _spawn_defs.values():
			if used_cell == cell:
				return false
	return _is_cell_inside_debug_map(cell)


func _is_cell_inside_debug_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _debug_map_width and cell.y >= 0 and cell.y < _debug_map_height


func _clamp_cell_to_map(cell: Vector2i) -> Vector2i:
	return Vector2i(clamp(cell.x, 0, _debug_map_width - 1), clamp(cell.y, 0, _debug_map_height - 1))


func _find_preset_index_by_id(preset_id: String) -> int:
	for index in range(_presets.size()):
		if String(_presets[index].get("id", "")) == preset_id:
			return index
	return -1


func _select_preset_option_by_id(preset_id: String) -> void:
	if _preset_option == null:
		return
	var index := _find_preset_index_by_id(preset_id)
	if index >= 0:
		_preset_option.select(index)


func _select_enemy_option(option: OptionButton, enemy_id: StringName) -> void:
	for index in range(_enemy_ids.size()):
		if _enemy_ids[index] == enemy_id:
			option.select(index)
			return
	if not _enemy_ids.is_empty():
		option.select(0)


func _select_damage_type(damage_type: String) -> void:
	if _item_damage_type_option == null:
		return
	var index := DAMAGE_TYPE_OPTIONS.find(damage_type)
	_item_damage_type_option.select(index if index >= 0 else 0)


func _get_preset_name_from_input() -> String:
	if _preset_name_edit == null:
		return "未命名调试预设"
	var preset_name := _preset_name_edit.text.strip_edges()
	return preset_name if not preset_name.is_empty() else "未命名调试预设"


func _make_new_preset_id() -> String:
	return "preset_%d" % Time.get_ticks_msec()


func _swap_queue_items(queue: Array, a: int, b: int) -> void:
	var temp = queue[a]
	queue[a] = queue[b]
	queue[b] = temp


func _is_tab_active(tab_name: String) -> bool:
	if _editor_tabs == null:
		return tab_name == "Combat"
	var current_index := _editor_tabs.current_tab
	if current_index < 0 or current_index >= _editor_tabs.get_child_count():
		return false
	var expected_index: int = _get_editor_tab_index(tab_name)
	return current_index == expected_index


func _set_editor_tab(tab_name: String) -> void:
	if _editor_tabs == null:
		return
	var index := _get_editor_tab_index(tab_name)
	if index >= 0 and index < _editor_tabs.get_child_count():
		_editor_tabs.current_tab = index


func _get_editor_tab_index(tab_name: String) -> int:
	var tab_indices: Dictionary = {
		"Map": 0,
		"Combat": 1,
		"Presets": 2,
		"Spawns": 3,
		"Queues": 4,
		"Enemy": 5
	}
	return int(tab_indices.get(tab_name, -1))


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


func _get_unit_attack_range_cells(unit: Node) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _map_manager == null:
		return cells
	var origin: Vector2i = unit.get_current_cell()
	for offset: Vector2i in unit.range_pattern:
		var cell := origin + _rotate_offset(offset, unit.facing)
		if _map_manager.is_inside(cell) and not cells.has(cell):
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


func _show_message(text: String, cooldown_operator_key: StringName = &"") -> void:
	_cooldown_message_operator_key = cooldown_operator_key
	if _message_label != null:
		_message_label.text = text
	if _combat_hud != null and _combat_hud.has_method("show_message"):
		_combat_hud.show_message(text)


func append_combat_debug(text: String) -> void:
	var timestamp := Time.get_ticks_msec() / 1000.0
	_log_lines.append("[%.2f] %s" % [timestamp, text])
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	if _log_text != null:
		_log_text.text = "\n".join(_log_lines)
		_log_text.scroll_vertical = _log_text.get_line_count()


func _clear_debug_log() -> void:
	_log_lines.clear()
	if _log_text != null:
		_log_text.text = ""


func _show_result_message(result: Dictionary, success_text: String, failure_text: String) -> void:
	var message := String(result.get("message", ""))
	if message.is_empty():
		message = success_text if result.get("ok", false) else failure_text
	_show_message(message)
	append_combat_debug(message)


func _make_scroll_panel(parent: Control, min_size: Vector2) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.custom_minimum_size = min_size
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	parent.add_child(content)
	return content


func _make_section(parent: Control, title: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_panel_style(DEBUG_SURFACE, DEBUG_BORDER, 8, 1))
	parent.add_child(card)
	var margin := _make_margin_container(10, 9, 10, 10)
	card.add_child(margin)
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)
	var label := _make_label(title, 0.0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0, 1.0))
	outer.add_child(label)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = DEBUG_ACCENT_DIM
	outer.add_child(rule)
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 7)
	outer.add_child(section)
	return section


func _make_status_chip(parent: Control, text: String, accented: bool = false) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(88, 34)
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(DEBUG_ACCENT_DIM if accented else Color(0.08, 0.10, 0.125, 0.95), DEBUG_ACCENT if accented else DEBUG_BORDER, 16, 1)
	)
	parent.add_child(panel)
	var margin := _make_margin_container(10, 4, 10, 4)
	panel.add_child(margin)
	var label := _make_label(text, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.93, 0.98, 1.0, 1.0))
	margin.add_child(label)
	return label


func _make_margin_container(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _make_panel_style(bg: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style


func _apply_button_style(button: Button, selected: bool = false) -> void:
	var normal_bg := DEBUG_ACCENT_DIM if selected else DEBUG_SURFACE_ALT
	var hover_bg := DEBUG_ACCENT if selected else Color(0.16, 0.19, 0.23, 1.0)
	var pressed_bg := DEBUG_ACCENT if selected else Color(0.10, 0.31, 0.43, 1.0)
	button.add_theme_stylebox_override("normal", _make_panel_style(normal_bg, DEBUG_BORDER, 6, 1))
	button.add_theme_stylebox_override("hover", _make_panel_style(hover_bg, DEBUG_ACCENT, 6, 1))
	button.add_theme_stylebox_override("pressed", _make_panel_style(pressed_bg, DEBUG_ACCENT, 6, 1))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _style_text_edit(text_edit: TextEdit) -> void:
	text_edit.add_theme_stylebox_override("normal", _make_panel_style(Color(0.04, 0.05, 0.065, 0.95), DEBUG_BORDER, 6, 1))
	text_edit.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98, 1.0))
	text_edit.add_theme_color_override("font_readonly_color", Color(0.78, 0.84, 0.90, 1.0))


func _style_item_list(item_list: ItemList) -> void:
	item_list.add_theme_stylebox_override("panel", _make_panel_style(Color(0.045, 0.055, 0.07, 0.95), DEBUG_BORDER, 6, 1))
	item_list.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98, 1.0))
	item_list.add_theme_color_override("font_selected_color", Color.WHITE)


func _style_line_edit(line_edit: LineEdit) -> void:
	line_edit.add_theme_stylebox_override("normal", _make_panel_style(Color(0.045, 0.055, 0.07, 0.95), DEBUG_BORDER, 6, 1))
	line_edit.add_theme_stylebox_override("focus", _make_panel_style(Color(0.055, 0.07, 0.09, 0.98), DEBUG_ACCENT, 6, 1))
	line_edit.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0, 1.0))


func _style_option_button(option: OptionButton) -> void:
	_apply_button_style(option, false)


func _style_spinbox(spinbox: SpinBox) -> void:
	spinbox.custom_minimum_size = Vector2(0, 34)
	if spinbox.has_method("get_line_edit"):
		var line_edit := spinbox.get_line_edit()
		if line_edit != null:
			_style_line_edit(line_edit)


func _make_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = title
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(tab)
	return tab


func _make_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 7)
	parent.add_child(row)
	return row


func _make_label(text: String, min_width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.86, 0.91, 0.96, 1.0))
	if min_width > 0.0:
		label.custom_minimum_size = Vector2(min_width, 0)
	return label


func _make_option(parent: Control) -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size = Vector2(0, 34)
	_style_option_button(option)
	parent.add_child(option)
	return option


func _make_button(text: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callable)
	_apply_button_style(button, false)
	return button


func _make_spin(min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var spinbox := SpinBox.new()
	spinbox.min_value = min_value
	spinbox.max_value = max_value
	spinbox.step = step
	spinbox.value = value
	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_spinbox(spinbox)
	return spinbox
