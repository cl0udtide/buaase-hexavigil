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
const DAMAGE_TYPE_LABELS := ["物理", "法术", "真实"]

var _unit_ids: Array[StringName] = []
var _enemy_ids: Array[StringName] = []
var _presets: Array[Dictionary] = []
var _spawn_defs: Dictionary = {}
var _spawn_queues: Dictionary = {}
var _running_spawn_queues: Dictionary = {}
var _selected_spawn_key := StringName()
var _selected_queue_index := -1
var _selected_unit_runtime_id := -1
var _current_preset_id := ""
var _current_preset_name := ""
var _next_spawn_index := 1
var _log_lines: Array[String] = []
var _refreshing_editor_ui := false

var _editor_tabs: TabContainer
var _preset_option: OptionButton
var _preset_name_edit: LineEdit
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


func _ready() -> void:
	add_to_group("combat_debug_log")
	var data_repo = AppRefs.data_repo()
	if data_repo != null:
		data_repo.load_all()
	_load_presets_from_disk()
	_build_editor_ui()
	_populate_static_options()
	_connect_events()
	_apply_preset_by_index(0)
	set_process(true)


func _process(delta: float) -> void:
	_tick_spawn_queues(delta)
	_refresh_status()
	_refresh_skill_info(_get_selected_unit())
	if _selected_unit_runtime_id >= 0:
		_refresh_attack_range_preview()


func _build_editor_ui() -> void:
	var panel := get_node_or_null("UI/Panel") as Control
	if panel != null:
		AppTheme.apply(panel)
	var vbox := get_node_or_null("UI/Panel/MarginContainer/VBox") as VBoxContainer
	if vbox == null:
		return
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()

	var title := _make_label("Combat Sandbox Editor", 0.0)
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_status_label = _make_label("状态", 0.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	_editor_tabs = TabContainer.new()
	_editor_tabs.custom_minimum_size = Vector2(0, 450)
	_editor_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_tabs.tab_changed.connect(_on_editor_tab_changed)
	vbox.add_child(_editor_tabs)

	_build_combat_tab(_make_tab(_editor_tabs, "作战"))
	_build_preset_tab(_make_tab(_editor_tabs, "预设"))
	_build_spawn_tab(_make_tab(_editor_tabs, "出怪口"))
	_build_queue_tab(_make_tab(_editor_tabs, "队列"))
	_build_item_tab(_make_tab(_editor_tabs, "属性"))

	_message_label = _make_label("加载预设后可部署单位、编辑出怪口与队列。", 0.0)
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


func _build_combat_tab(tab: VBoxContainer) -> void:
	var unit_row := _make_row(tab)
	unit_row.add_child(_make_label("单位", 54.0))
	_unit_option = _make_option(unit_row)
	unit_row.add_child(_make_label("朝向", 54.0))
	_facing_option = _make_option(unit_row)

	var unit_action_row := _make_row(tab)
	unit_action_row.add_child(_make_button("释放技能", _on_cast_skill_pressed))
	unit_action_row.add_child(_make_button("撤退选中", _on_retreat_pressed))

	var run_row := _make_row(tab)
	run_row.add_child(_make_button("开始当前口", _on_start_selected_spawn_pressed))
	run_row.add_child(_make_button("开始全部", _on_start_all_spawns_pressed))
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
	action_row.add_child(_make_button("覆盖保存", _on_save_preset_pressed))
	action_row.add_child(_make_button("另存新预设", _on_save_new_preset_pressed))
	action_row.add_child(_make_button("删除预设", _on_delete_preset_pressed))


func _build_spawn_tab(tab: VBoxContainer) -> void:
	var spawn_row := _make_row(tab)
	spawn_row.add_child(_make_label("出怪口", 68.0))
	_spawn_option = _make_option(spawn_row)
	_spawn_option.item_selected.connect(_on_spawn_option_selected)
	spawn_row.add_child(_make_button("新增", _on_add_spawn_pressed))
	spawn_row.add_child(_make_button("删除", _on_delete_spawn_pressed))

	var hint := _make_label("点击红色出怪口格子可直接选中；点击空格会移动当前选中的出怪口。不能放在核心、单位或已有出怪口上。", 0.0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(hint)


func _build_queue_tab(tab: VBoxContainer) -> void:
	_queue_hint_label = _make_label("队列：未选择出怪口", 0.0)
	tab.add_child(_queue_hint_label)

	var add_row := _make_row(tab)
	add_row.add_child(_make_label("敌人", 54.0))
	_enemy_option = _make_option(add_row)
	add_row.add_child(_make_button("添加单只", _on_add_enemy_item_pressed))

	var batch_row := _make_row(tab)
	batch_row.add_child(_make_label("批量", 54.0))
	_batch_count_spin = _make_spin(1.0, 50.0, 1.0, 3.0)
	batch_row.add_child(_batch_count_spin)
	batch_row.add_child(_make_label("延迟", 54.0))
	_batch_delay_spin = _make_spin(0.0, 60.0, 0.05, 0.5)
	batch_row.add_child(_batch_delay_spin)
	batch_row.add_child(_make_button("批量追加", _on_batch_append_pressed))

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
	timing_row.add_child(_make_label("攻速", 68.0))
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
	move_row.add_child(_make_label("移速", 68.0))
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
	_clear_debug_log()
	_running_spawn_queues.clear()
	_selected_unit_runtime_id = -1
	_clear_attack_range_preview()
	if _enemy_manager != null and _enemy_manager.has_method("clear_all_enemies"):
		_enemy_manager.clear_all_enemies()
	if _unit_manager != null and _unit_manager.has_method("clear_all_units"):
		_unit_manager.clear_all_units()
	var run_state = AppRefs.run_state()
	if run_state != null:
		run_state.reset_for_new_run(1)
		run_state.set_day(1)
		run_state.set_phase(GameEnums.PHASE_DAY)
		run_state.set_deploy_limit(99)
		run_state.reset_action_points(999)
		for unit_id in _unit_ids:
			run_state.add_owned_unit(unit_id)
	_apply_debug_map_from_state()
	append_combat_debug("战斗编辑器已重置：预设 %s，出怪口 %d 个" % [_current_preset_name, _spawn_defs.size()])
	_refresh_editor_controls()


func _clear_battlefield() -> void:
	_running_spawn_queues.clear()
	_selected_unit_runtime_id = -1
	_clear_attack_range_preview()
	if _enemy_manager != null and _enemy_manager.has_method("clear_all_enemies"):
		_enemy_manager.clear_all_enemies()
	if _unit_manager != null and _unit_manager.has_method("clear_all_units"):
		_unit_manager.clear_all_units()
	if _map_manager != null and _map_manager.has_method("clear_runtime_occupancy"):
		_map_manager.clear_runtime_occupancy()
	var run_state = AppRefs.run_state()
	if run_state != null:
		run_state.deployed_count = 0
		run_state.core_hp = run_state.core_hp_max
		EventBus.deploy_limit_changed.emit(run_state.deployed_count, run_state.deploy_limit)
		EventBus.core_hp_changed.emit(run_state.core_hp, run_state.core_hp_max)
	append_combat_debug("清场完成：移除所有单位、敌人与运行中的刷怪队列，编辑器队列保留")


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
			append_combat_debug("出怪口 %s 队列完成" % spawn_key)
			continue
		var item: Dictionary = items[index]
		_spawn_enemy_item(spawn_key, item)
		index += 1
		if index >= items.size():
			_running_spawn_queues.erase(raw_key)
			append_combat_debug("出怪口 %s 队列完成" % spawn_key)
		else:
			state["index"] = index
			state["timer"] = float((items[index] as Dictionary).get("delay", 0.0))


func _spawn_enemy_item(spawn_key: StringName, item: Dictionary) -> void:
	if _enemy_manager == null or _map_manager == null:
		return
	if _map_manager.has_method("has_spawn_key") and not _map_manager.has_spawn_key(spawn_key):
		append_combat_debug("出怪失败：出怪口 %s 不存在" % spawn_key)
		return
	var enemy_id := StringName(item.get("enemy_id", ""))
	if enemy_id == StringName():
		return
	var spawn_cell: Vector2i = _map_manager.get_spawn_cell_by_key(spawn_key)
	var override := _make_enemy_override(item)
	_enemy_manager.spawn_enemy(enemy_id, spawn_cell, override)
	append_combat_debug("出怪口 %s 生成 %s：HP %d ATK %d DEF %d RES %d" % [
		spawn_key,
		String(item.get("name", enemy_id)),
		int(item.get("max_hp", 1)),
		int(item.get("atk", 1)),
		int(item.get("def", 0)),
		int(item.get("res", 0))
	])


func _on_map_cell_clicked(cell: Vector2i) -> void:
	var clicked_spawn_key := _get_spawn_key_at_cell(cell)
	if _is_tab_active("出怪口"):
		if clicked_spawn_key != StringName():
			_select_spawn_from_map(clicked_spawn_key)
			return
		_move_selected_spawn_to(cell)
		return
	if clicked_spawn_key != StringName() and not _is_tab_active("作战"):
		_select_spawn_from_map(clicked_spawn_key)
		return
	if not _is_tab_active("作战"):
		_show_message("当前页面不会部署单位；切换到“作战”页后点击地图部署或选中单位。")
		return
	if _unit_manager == null:
		return
	var existing_unit = _unit_manager.get_unit_by_cell(cell) if _unit_manager.has_method("get_unit_by_cell") else null
	if existing_unit != null:
		_selected_unit_runtime_id = existing_unit.get_runtime_id()
		_refresh_attack_range_preview()
		append_combat_debug("选中单位 %s#%d，预览攻击范围" % [existing_unit.unit_id, existing_unit.get_runtime_id()])
		_refresh_status()
		return
	var unit_id := _get_selected_unit_id()
	if unit_id == StringName():
		return
	var result: Dictionary = _unit_manager.try_deploy_unit(unit_id, cell, _get_selected_facing())
	_show_result_message(result, "部署完成", "部署失败")


func _on_preset_option_selected(_index: int) -> void:
	if _refreshing_editor_ui:
		return
	var preset := _get_selected_preset_option()
	if preset.is_empty():
		return
	_show_message("已选中预设 %s，点击“加载”应用到场景" % String(preset.get("name", "")))


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
	_show_message("已覆盖保存预设：%s" % _current_preset_name)
	append_combat_debug("保存调试预设 %s 到 %s" % [_current_preset_name, PRESET_PATH])


func _on_save_new_preset_pressed() -> void:
	_current_preset_id = _make_new_preset_id()
	_current_preset_name = _get_preset_name_from_input()
	_presets.append(_serialize_current_preset())
	_save_presets_to_disk()
	_populate_preset_options()
	_select_preset_option_by_id(_current_preset_id)
	_show_message("已另存为新预设：%s" % _current_preset_name)
	append_combat_debug("另存调试预设 %s" % _current_preset_name)


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
	_show_message("已选中出怪口 %s" % _selected_spawn_key)


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
	append_combat_debug("新增出怪口 %s 于 %s" % [spawn_key, cell])


func _on_delete_spawn_pressed() -> void:
	if _selected_spawn_key == StringName():
		return
	var key := String(_selected_spawn_key)
	if _map_manager != null and _map_manager.has_method("remove_debug_spawn"):
		_map_manager.remove_debug_spawn(_selected_spawn_key)
	_spawn_defs.erase(key)
	_spawn_queues.erase(key)
	_running_spawn_queues.erase(key)
	append_combat_debug("删除出怪口 %s，并清理该口队列" % _selected_spawn_key)
	var keys := _get_spawn_keys()
	_selected_spawn_key = keys[0] if not keys.is_empty() else StringName()
	_selected_queue_index = -1
	_sync_spawn_nodes()
	_refresh_editor_controls()


func _on_editor_tab_changed(_tab: int) -> void:
	if _is_tab_active("出怪口") and _selected_spawn_key != StringName():
		_show_message("点击已有出怪口选中；点击空格移动 %s" % _selected_spawn_key)


func _move_selected_spawn_to(cell: Vector2i) -> void:
	if _selected_spawn_key == StringName() or _map_manager == null:
		return
	if not _map_manager.has_method("upsert_debug_spawn") or not _map_manager.upsert_debug_spawn(_selected_spawn_key, cell):
		_show_message("移动失败：目标格不可用")
		append_combat_debug("移动出怪口 %s 失败，目标格 %s 不可用" % [_selected_spawn_key, cell])
		return
	_spawn_defs[String(_selected_spawn_key)] = cell
	_sync_spawn_nodes()
	_refresh_editor_controls()
	_show_message("已移动出怪口 %s 到 %s" % [_selected_spawn_key, cell])
	append_combat_debug("移动出怪口 %s 到 %s" % [_selected_spawn_key, cell])


func _select_spawn_from_map(spawn_key: StringName) -> void:
	if not _spawn_defs.has(String(spawn_key)):
		return
	_selected_spawn_key = spawn_key
	_selected_queue_index = -1
	_refresh_editor_controls()
	_show_message("已通过地图选中出怪口 %s" % spawn_key)
	append_combat_debug("通过地图选中出怪口 %s" % spawn_key)


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
	append_combat_debug("向出怪口 %s 批量追加 %d 只 %s" % [_selected_spawn_key, count, enemy_id])


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
	_show_message("已启动 %d 个出怪口队列" % started)


func _on_stop_spawns_pressed() -> void:
	_running_spawn_queues.clear()
	_refresh_editor_controls()
	_show_message("已停止所有运行中的出怪队列")
	append_combat_debug("停止所有运行中的出怪队列")


func _on_cast_skill_pressed() -> void:
	var unit := _get_selected_unit()
	if unit == null or _unit_manager == null:
		return
	var result: Dictionary = _unit_manager.try_cast_skill(unit.get_runtime_id())
	_show_result_message(result, "技能已释放", "技能失败")


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
	_show_message("已清场")


func _on_reset_pressed() -> void:
	_reset_sandbox()
	_show_message("已重置战斗编辑器")


func _on_unit_deployed(unit_runtime_id: int, _unit_id: StringName, _cell: Vector2i) -> void:
	_selected_unit_runtime_id = unit_runtime_id
	_refresh_attack_range_preview()


func _on_unit_removed(unit_runtime_id: int, _reason: int) -> void:
	if _selected_unit_runtime_id == unit_runtime_id:
		_selected_unit_runtime_id = -1
		_refresh_attack_range_preview()


func _start_spawn_queue(spawn_key: StringName, show_feedback: bool = true) -> bool:
	if spawn_key == StringName():
		return false
	var queue := _get_queue(spawn_key)
	if queue.is_empty():
		if show_feedback:
			_show_message("出怪口 %s 队列为空" % spawn_key)
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
	append_combat_debug("启动出怪口 %s 队列，共 %d 只敌人" % [spawn_key, items.size()])
	if show_feedback:
		_show_message("已启动出怪口 %s 队列" % spawn_key)
	return true


func _refresh_editor_controls() -> void:
	_refreshing_editor_ui = true
	_populate_spawn_options()
	_refresh_queue_list()
	_refresh_item_editor()
	if _preset_name_edit != null:
		_preset_name_edit.text = _current_preset_name
	_refreshing_editor_ui = false
	_refresh_status()


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
		selected_text = "%s HP %d/%d SP %.0f/%.0f CD %.1f" % [
			selected_unit.unit_id,
			selected_unit.current_hp,
			selected_unit.max_hp,
			selected_unit.sp,
			float(selected_unit.cfg.get("sp_max", 0.0)),
			_unit_manager.get_redeploy_remaining(selected_unit.unit_id) if _unit_manager != null else 0.0
		]
	var selected_spawn_text := String(_selected_spawn_key) if _selected_spawn_key != StringName() else "无"
	_status_label.text = "单位 %d  敌人 %d  核心 %s  运行队列 %d\n预设：%s  出怪口：%s  选中单位：%s" % [
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
	var skill_desc := String(cfg.get("skill_description", "暂无技能描述。"))
	var sp_max := float(cfg.get("sp_max", 0.0))
	var sp_text := "无技力"
	if sp_max > 0.0:
		sp_text = "技力 %.0f/%.0f" % [selected_unit.sp, sp_max]
	# 技能描述来自数据表，调试面板只负责展示，避免把技能文案写死在 UI 脚本里。
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
		_queue_list.add_item("%02d  +%.2fs  %s  HP%d ATK%d DEF%d RES%d" % [
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
		_queue_hint_label.text = "出怪口 %s：%d 只敌人" % [
			String(_selected_spawn_key) if _selected_spawn_key != StringName() else "无",
			queue.size()
		]
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
	_spawn_defs = _parse_spawn_defs(preset.get("spawns", []))
	_spawn_queues = _parse_spawn_queues(preset.get("queues", {}))
	for spawn_key in _spawn_defs.keys():
		if not _spawn_queues.has(String(spawn_key)):
			_spawn_queues[String(spawn_key)] = []
	var keys := _get_spawn_keys()
	_selected_spawn_key = keys[0] if not keys.is_empty() else StringName()
	_selected_queue_index = -1
	_next_spawn_index = _calc_next_spawn_index()
	_select_preset_option_by_id(_current_preset_id)
	_reset_sandbox()
	_show_message("已加载预设：%s" % _current_preset_name)


func _create_default_preset() -> Dictionary:
	return {
		"id": "default",
		"name": "默认三路调试",
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
				{"enemy_id": "wolf", "delay": 0.5, "name": "荒原狼", "max_hp": 60, "atk": 22, "def": 1, "res": 0, "move_speed": 1.4, "attack_interval": 1.0, "damage_type": "physical", "core_damage": 1}
			],
			"S3": []
		}
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
		"spawns": spawns,
		"queues": queues
	}


func _serialize_queue_item(item: Dictionary) -> Dictionary:
	return {
		"enemy_id": String(item.get("enemy_id", "")),
		"delay": float(item.get("delay", 0.0)),
		"name": String(item.get("name", "")),
		"max_hp": int(item.get("max_hp", 1)),
		"atk": int(item.get("atk", 1)),
		"def": int(item.get("def", 0)),
		"res": int(item.get("res", 0)),
		"move_speed": float(item.get("move_speed", 1.0)),
		"attack_interval": float(item.get("attack_interval", 1.0)),
		"damage_type": String(item.get("damage_type", "physical")),
		"core_damage": int(item.get("core_damage", 1))
	}


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
		_preset_option.add_item(String(preset.get("name", preset.get("id", "未命名"))))
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
	for text in ["右", "下", "左", "上"]:
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
		return tab_name == "作战"
	var tab_index := _editor_tabs.current_tab
	if tab_index < 0 or tab_index >= _editor_tabs.get_child_count():
		return false
	return _editor_tabs.get_child(tab_index).name == tab_name


func _refresh_attack_range_preview() -> void:
	var unit := _get_selected_unit()
	if _map_root == null or not _map_root.has_method("set_debug_attack_range"):
		return
	if unit == null:
		_clear_attack_range_preview()
		return
	_map_root.set_debug_attack_range(_get_unit_attack_range_cells(unit))


func _clear_attack_range_preview() -> void:
	# 清场、重置、撤退都会走这里，保证调试预览不会残留在地图上。
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
	# 调试预览和 UnitActor 使用同一套“默认向右，按朝向旋转”的约定。
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
