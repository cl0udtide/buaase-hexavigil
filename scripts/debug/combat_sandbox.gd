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
const DAMAGE_TYPE_LABELS := ["物理", "法术", "真实"]

var _unit_ids: Array[StringName] = []
var _enemy_ids: Array[StringName] = []
var _operator_defs: Array[Dictionary] = []
var _presets: Array[Dictionary] = []
var _spawn_defs: Dictionary = {}
var _spawn_queues: Dictionary = {}
var _running_spawn_queues: Dictionary = {}
var _selected_spawn_key := StringName()
var _selected_queue_index := -1
var _selected_operator_key := StringName()
var _selected_unit_runtime_id := -1
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
var _combat_hud: Control
var _debug_drawer_panel: Control
var _debug_drawer_content: Control

var _editor_tabs: TabContainer
var _preset_option: OptionButton
var _preset_name_edit: LineEdit
var _operator_list: ItemList
var _operator_name_edit: LineEdit
var _unit_option: OptionButton
var _facing_option: OptionButton
var _spawn_option: OptionButton
var _enemy_option: OptionButton
var _batch_count_spin: SpinBox
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
var _skill_info_label: Label
var _message_label: Label
var _queue_hint_label: Label
var _log_text: TextEdit

@onready var _map_manager: Node = get_node_or_null("Managers/MapManager")
@onready var _path_service: Node = get_node_or_null("Managers/PathService")
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
	if data_repo != null:
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
		_refresh_operator_list()
		_refresh_status()
		_refresh_skill_info(_get_selected_unit())
	if _selected_unit_runtime_id >= 0:
		_refresh_attack_range_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_deploy_flow("已取消")
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_cancel_deploy_flow("已取消")
			return
		if _deploy_drag_state == DRAG_LOCKED and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _get_mouse_cell() == _locked_deploy_cell:
				_deploy_drag_state = DRAG_FACING
				_current_drag_facing = Vector2i.RIGHT
				_show_message("向外拖拽选择朝向")
				return
		if get_tree().paused and _deploy_drag_state == DRAG_NONE and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_map_cell_selection(_get_mouse_cell())


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
	Engine.time_scale = 1.0


func _configure_pause_boundaries() -> void:
	var world := get_node_or_null("World")
	if world != null:
		world.process_mode = Node.PROCESS_MODE_PAUSABLE
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
		_debug_drawer_panel.offset_left = -720.0
		_debug_drawer_panel.offset_top = 82.0
		_debug_drawer_panel.offset_right = -18.0
		_debug_drawer_panel.offset_bottom = -18.0
	if _combat_hud != null and _combat_hud.has_method("set_debug_drawer_open"):
		_combat_hud.set_debug_drawer_open(open)


func _on_debug_drawer_toggle_pressed() -> void:
	_set_debug_drawer_open(not _debug_drawer_open)


func _on_pause_pressed() -> void:
	get_tree().paused = not get_tree().paused
	_refresh_time_controls()


func _on_speed_1_pressed() -> void:
	Engine.time_scale = 1.0
	_refresh_time_controls()


func _on_speed_2_pressed() -> void:
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
		var remain: float = _unit_manager.get_operator_redeploy_remaining(operator_key) if _unit_manager != null and _unit_manager.has_method("get_operator_redeploy_remaining") else 0.0
		_show_message("再部署冷却 %.1f秒" % remain)


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


func _build_combat_tab(tab: VBoxContainer) -> void:
	var roster_label := _make_label("干员槽位", 0.0)
	tab.add_child(roster_label)
	_operator_list = ItemList.new()
	_operator_list.custom_minimum_size = Vector2(0, 150)
	_operator_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_operator_list.item_selected.connect(_on_operator_item_selected)
	tab.add_child(_operator_list)

	var add_row := _make_row(tab)
	add_row.add_child(_make_label("类型", 54.0))
	_unit_option = _make_option(add_row)
	add_row.add_child(_make_label("名称", 54.0))
	_operator_name_edit = LineEdit.new()
	_operator_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(_operator_name_edit)

	var roster_action_row := _make_row(tab)
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
	scene_row.add_child(_make_button("清场", _on_clear_pressed))
	scene_row.add_child(_make_button("重置", _on_reset_pressed))

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

	var add_row := _make_row(tab)
	add_row.add_child(_make_label("敌人", 54.0))
	_enemy_option = _make_option(add_row)
	add_row.add_child(_make_button("添加单个", _on_add_enemy_item_pressed))

	var batch_row := _make_row(tab)
	batch_row.add_child(_make_label("数量", 54.0))
	_batch_count_spin = _make_spin(1.0, 50.0, 1.0, 3.0)
	batch_row.add_child(_batch_count_spin)
	batch_row.add_child(_make_label("延迟", 54.0))
	_batch_delay_spin = _make_spin(0.0, 60.0, 0.05, 0.5)
	batch_row.add_child(_batch_delay_spin)
	batch_row.add_child(_make_button("追加批次", _on_batch_append_pressed))

	_queue_list = ItemList.new()
	_queue_list.custom_minimum_size = Vector2(0, 180)
	_queue_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_queue_list.item_selected.connect(_on_queue_item_selected)
	tab.add_child(_queue_list)

	var action_row := _make_row(tab)
	action_row.add_child(_make_button("复制", _on_duplicate_queue_item_pressed))
	action_row.add_child(_make_button("删除", _on_remove_queue_item_pressed))
	action_row.add_child(_make_button("上移", _on_move_queue_item_up_pressed))
	action_row.add_child(_make_button("下移", _on_move_queue_item_down_pressed))


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
	if event_bus == null:
		return
	event_bus.map_cell_clicked.connect(_on_map_cell_clicked)
	event_bus.unit_deployed.connect(_on_unit_deployed)
	event_bus.unit_removed.connect(_on_unit_removed)


func _populate_static_options() -> void:
	_populate_unit_options()
	_populate_enemy_options()
	_populate_direction_options()
	_populate_damage_type_options()
	_populate_preset_options()


func _reset_sandbox() -> void:
	_cancel_deploy_flow("")
	_clear_debug_log()
	_running_spawn_queues.clear()
	_selected_operator_key = _get_first_operator_key()
	_selected_unit_runtime_id = -1
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
	if _map_manager != null and _map_manager.has_method("clear_runtime_occupancy"):
		_map_manager.clear_runtime_occupancy()
	var run_state = AppRefs.run_state()
	if run_state != null:
		run_state.deployed_count = 0
		run_state.core_hp = run_state.core_hp_max
		EventBus.deploy_limit_changed.emit(run_state.deployed_count, run_state.deploy_limit)
		EventBus.core_hp_changed.emit(run_state.core_hp, run_state.core_hp_max)
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
	if _deploy_drag_state != DRAG_NONE:
		return
	_clear_unit_selection_if_click_misses_unit(cell)
	var clicked_spawn_key_new := _get_spawn_key_at_cell(cell)
	if _debug_drawer_open and _is_tab_active("Spawns"):
		if clicked_spawn_key_new != StringName():
			_select_spawn_from_map(clicked_spawn_key_new)
			return
		_move_selected_spawn_to(cell)
		return
	if _debug_drawer_open and clicked_spawn_key_new != StringName() and not _is_tab_active("Combat"):
		_select_spawn_from_map(clicked_spawn_key_new)
		return
	_handle_map_cell_selection(cell)


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
	_refresh_editor_controls()
	_show_message("已选择出怪点 %s" % _selected_spawn_key)


func _on_add_spawn_pressed() -> void:
	var spawn_key := _make_next_spawn_key()
	var cell := _find_default_spawn_cell()
	_spawn_defs[String(spawn_key)] = cell
	_spawn_queues[String(spawn_key)] = []
	if _map_manager != null and _map_manager.has_method("upsert_debug_spawn"):
		_map_manager.upsert_debug_spawn(spawn_key, cell)
	_selected_spawn_key = spawn_key
	_selected_queue_index = -1
	_sync_spawn_nodes()
	_refresh_editor_controls()
	append_combat_debug("已在 %s 添加出怪点 %s" % [cell, spawn_key])


func _on_delete_spawn_pressed() -> void:
	if _selected_spawn_key == StringName():
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
	_sync_spawn_nodes()
	_refresh_editor_controls()


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
	_sync_spawn_nodes()
	_refresh_editor_controls()
	_show_message("已移动出怪点 %s 到 %s" % [_selected_spawn_key, cell])
	append_combat_debug("已移动出怪点 %s 到 %s" % [_selected_spawn_key, cell])


func _select_spawn_from_map(spawn_key: StringName) -> void:
	if not _spawn_defs.has(String(spawn_key)):
		return
	_selected_spawn_key = spawn_key
	_selected_queue_index = -1
	_refresh_editor_controls()
	_show_message("已从地图选择出怪点 %s" % spawn_key)
	append_combat_debug("已从地图选择出怪点 %s" % spawn_key)


func _on_add_enemy_item_pressed() -> void:
	var queue := _get_selected_queue()
	var enemy_id := _get_selected_enemy_id()
	if enemy_id == StringName() or _selected_spawn_key == StringName():
		return
	queue.append(_make_enemy_queue_item(enemy_id, 0.0))
	_selected_queue_index = queue.size() - 1
	_refresh_editor_controls()


func _on_batch_append_pressed() -> void:
	var queue := _get_selected_queue()
	var enemy_id := _get_selected_enemy_id()
	if enemy_id == StringName() or _selected_spawn_key == StringName():
		return
	var count := int(_batch_count_spin.value)
	var delay := float(_batch_delay_spin.value)
	for _i in range(count):
		queue.append(_make_enemy_queue_item(enemy_id, delay))
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
	_show_message("战场已清空")


func _on_reset_pressed() -> void:
	_reset_sandbox()
	_show_message("战斗编辑器已重置")


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
	var unit_id := _get_selected_unit_id()
	if unit_id == StringName():
		return
	var operator_info := _normalize_operator_def({
		"key": String(_make_next_operator_key(unit_id)),
		"unit_id": String(unit_id),
		"name": _get_operator_name_from_input(unit_id)
	})
	_operator_defs.append(operator_info)
	_selected_operator_key = StringName(operator_info.get("key", ""))
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("add_owned_operator_with_key"):
		run_state.add_owned_operator_with_key(_selected_operator_key, unit_id, String(operator_info.get("name", "")))
	_refresh_operator_list()
	_rebuild_deploy_deck()
	_show_message("已添加干员槽位：%s" % _format_operator_label(operator_info))
	append_combat_debug("鏂板骞插憳妲戒綅 %s锛屽崟浣嶇被鍨?%s" % [_selected_operator_key, unit_id])


func _on_delete_operator_pressed() -> void:
	var operator_key := _get_selected_operator_key()
	if operator_key == StringName():
		return
	if _unit_manager != null and _unit_manager.has_method("get_operator_status") and StringName(_unit_manager.get_operator_status(operator_key)) != &"ready":
		_show_message("只能删除可部署的干员槽位")
		return
	for index in range(_operator_defs.size()):
		if StringName((_operator_defs[index] as Dictionary).get("key", "")) == operator_key:
			_operator_defs.remove_at(index)
			break
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("remove_owned_operator"):
		run_state.remove_owned_operator(operator_key)
	_selected_operator_key = _get_first_operator_key()
	_refresh_operator_list()
	_rebuild_deploy_deck()
	_show_message("已删除干员槽位：%s" % operator_key)
	append_combat_debug("鍒犻櫎骞插憳妲戒綅 %s" % operator_key)


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
	if _preset_name_edit != null:
		_preset_name_edit.text = _current_preset_name
	_refreshing_editor_ui = false
	_refresh_status()
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
		selected_text = "%s 生命 %d/%d 技力 %.0f/%.0f 冷却 %.1f" % [
			_get_operator_display_name(StringName(selected_unit.operator_key)),
			selected_unit.current_hp,
			selected_unit.max_hp,
			selected_unit.sp,
			float(selected_unit.cfg.get("sp_max", 0.0)),
			_unit_manager.get_operator_redeploy_remaining(StringName(selected_unit.operator_key)) if _unit_manager != null and _unit_manager.has_method("get_operator_redeploy_remaining") else 0.0
		]
	elif _selected_operator_key != StringName():
		selected_text = "%s %s" % [_get_operator_display_name(_selected_operator_key), _get_operator_state_text(_selected_operator_key)]
	var selected_spawn_text := String(_selected_spawn_key) if _selected_spawn_key != StringName() else "无"
	_status_label.text = "单位 %d  敌人 %d  核心 %s  运行队列 %d\n预设：%s  出怪点：%s  选择：%s" % [
		unit_count,
		enemy_count,
		core_text,
		_running_spawn_queues.size(),
		_current_preset_name,
		selected_spawn_text,
		selected_text
	]


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
		_queue_list.add_item("%02d  +%.2f秒  %s  生命%d 攻击%d 防御%d 法抗%d" % [
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
		_queue_hint_label.text = "队列：%s  条目：%d" % [spawn_label, queue.size()]
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
	_operator_defs = _parse_operator_defs(preset.get("operators", []))
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
		"operators": [
			{"key": "G1", "unit_id": "guard_t1", "name": "一阶近卫"},
			{"key": "G2", "unit_id": "guard_01", "name": "二阶近卫"},
			{"key": "G3", "unit_id": "guard_t3", "name": "三阶近卫"},
			{"key": "S1", "unit_id": "sniper_t1", "name": "一阶狙击"},
			{"key": "S2", "unit_id": "sniper_t2", "name": "二阶狙击"},
			{"key": "S3", "unit_id": "archer_basic", "name": "三阶狙击"},
			{"key": "C1", "unit_id": "caster_t1", "name": "一阶术士"},
			{"key": "C2", "unit_id": "caster_t2", "name": "二阶术士"},
			{"key": "C3", "unit_id": "caster_t3", "name": "三阶术士"},
			{"key": "D1", "unit_id": "defender_t1", "name": "一阶重装"},
			{"key": "D2", "unit_id": "defender_t2", "name": "二阶重装"},
			{"key": "D3", "unit_id": "defender_t3", "name": "三阶重装"}
		],
		"spawns": [
			{"key": "S1", "cell": [0, 3]},
			{"key": "S2", "cell": [0, 1]},
			{"key": "S3", "cell": [0, 5]}
		],
		"queues": {
			"S1": [
				{"enemy_id": "slime", "delay": 0.0, "name": "史莱姆", "max_hp": 80, "atk": 18, "def": 2, "res": 0, "move_speed": 1.0, "attack_interval": 1.2, "damage_type": "physical", "core_damage": 1}
			],
			"S2": [
				{"enemy_id": "wolf", "delay": 0.5, "name": "狼", "max_hp": 60, "atk": 22, "def": 1, "res": 0, "move_speed": 1.4, "attack_interval": 1.0, "damage_type": "physical", "core_damage": 1}
			],
			"S3": []
		}
	}


func _parse_operator_defs(raw_operators: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(raw_operators) == TYPE_ARRAY:
		for entry_variant in raw_operators:
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var operator_info := _normalize_operator_def(entry_variant as Dictionary)
			if not operator_info.is_empty():
				result.append(operator_info)
	if result.is_empty():
		for entry in _create_default_preset().get("operators", []):
			result.append(_normalize_operator_def(entry as Dictionary))
	return result


func _normalize_operator_def(raw_operator: Dictionary) -> Dictionary:
	var unit_id := StringName(raw_operator.get("unit_id", _get_default_unit_id()))
	if unit_id == StringName():
		return {}
	var operator_key := StringName(raw_operator.get("key", ""))
	if operator_key == StringName():
		operator_key = _make_next_operator_key(unit_id)
	var name := String(raw_operator.get("name", "")).strip_edges()
	if name.is_empty():
		name = _make_operator_display_name(unit_id)
	return {
		"key": String(operator_key),
		"unit_id": String(unit_id),
		"name": name
	}


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
			result[key] = _parse_cell(entry.get("cell", [0, 0]), Vector2i.ZERO)
	if result.is_empty():
		for key in DEFAULT_SPAWNS.keys():
			result[String(key)] = DEFAULT_SPAWNS[key]
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
		"operators": _serialize_operator_defs(),
		"spawns": spawns,
		"queues": queues
	}


func _serialize_operator_defs() -> Array:
	var serialized: Array = []
	for operator_info in _operator_defs:
		var operator_dict := operator_info as Dictionary
		serialized.append({
			"key": String(operator_dict.get("key", "")),
			"unit_id": String(operator_dict.get("unit_id", "")),
			"name": String(operator_dict.get("name", ""))
		})
	return serialized


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


func _apply_debug_map_from_state() -> void:
	if _map_manager == null:
		return
	var spawn_defs := {}
	for raw_key in _spawn_defs.keys():
		spawn_defs[StringName(raw_key)] = _spawn_defs[raw_key]
	if _map_manager.has_method("generate_debug_map"):
		_map_manager.generate_debug_map(SANDBOX_WIDTH, SANDBOX_HEIGHT, SANDBOX_CORE, spawn_defs)
	_sync_spawn_nodes()
	if _path_service != null and _path_service.has_method("rebuild_from_map"):
		_path_service.rebuild_from_map()


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


func _get_selected_unit_id() -> StringName:
	if _unit_option == null or _unit_option.selected < 0 or _unit_option.selected >= _unit_ids.size():
		return StringName()
	return _unit_ids[_unit_option.selected]


func _get_default_unit_id() -> StringName:
	return _unit_ids[0] if not _unit_ids.is_empty() else StringName()


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


func _make_next_operator_key(unit_id: StringName) -> StringName:
	var prefix := "O"
	var raw_unit := String(unit_id).to_lower()
	if raw_unit.begins_with("guard"):
		prefix = "G"
	elif raw_unit.begins_with("archer") or raw_unit.begins_with("sniper"):
		prefix = "S"
	elif raw_unit.begins_with("caster"):
		prefix = "C"
	elif raw_unit.begins_with("defender"):
		prefix = "D"
	var index := 1
	while _has_operator_key(StringName("%s%d" % [prefix, index])):
		index += 1
	return StringName("%s%d" % [prefix, index])


func _has_operator_key(operator_key: StringName) -> bool:
	for operator_info in _operator_defs:
		if StringName((operator_info as Dictionary).get("key", "")) == operator_key:
			return true
	return false


func _get_operator_name_from_input(unit_id: StringName) -> String:
	if _operator_name_edit != null:
		var typed_name := _operator_name_edit.text.strip_edges()
		if not typed_name.is_empty():
			return typed_name
	return _make_operator_display_name(unit_id)


func _make_operator_display_name(unit_id: StringName) -> String:
	var data_repo = AppRefs.data_repo()
	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id) if data_repo != null else {}
	var base_name := String(cfg.get("name", unit_id))
	var count := 0
	for operator_info in _operator_defs:
		if StringName((operator_info as Dictionary).get("unit_id", "")) == unit_id:
			count += 1
	return base_name if count == 0 else "%s%d" % [base_name, count + 1]


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


func _find_default_spawn_cell() -> Vector2i:
	for y in range(SANDBOX_HEIGHT):
		var cell := Vector2i(0, y)
		if _can_use_spawn_cell(cell):
			return cell
	for y in range(SANDBOX_HEIGHT):
		for x in range(SANDBOX_WIDTH):
			var cell := Vector2i(x, y)
			if _can_use_spawn_cell(cell):
				return cell
	return Vector2i.ZERO


func _can_use_spawn_cell(cell: Vector2i) -> bool:
	if cell == SANDBOX_CORE:
		return false
	for used_cell in _spawn_defs.values():
		if used_cell == cell:
			return false
	return cell.x >= 0 and cell.x < SANDBOX_WIDTH and cell.y >= 0 and cell.y < SANDBOX_HEIGHT


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
	var tab_indices: Dictionary = {
		"Combat": 0,
		"Presets": 1,
		"Spawns": 2,
		"Queues": 3,
		"Enemy": 4
	}
	var expected_index: int = int(tab_indices.get(tab_name, -1))
	return current_index == expected_index


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


func _show_message(text: String) -> void:
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
	parent.add_child(row)
	return row


func _make_label(text: String, min_width: float) -> Label:
	var label := Label.new()
	label.text = text
	if min_width > 0.0:
		label.custom_minimum_size = Vector2(min_width, 0)
	return label


func _make_option(parent: Control) -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(option)
	return option


func _make_button(text: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callable)
	return button


func _make_spin(min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var spinbox := SpinBox.new()
	spinbox.min_value = min_value
	spinbox.max_value = max_value
	spinbox.step = step
	spinbox.value = value
	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spinbox
