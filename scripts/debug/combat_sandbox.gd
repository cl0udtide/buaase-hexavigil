extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")

const SANDBOX_WIDTH := 12
const SANDBOX_HEIGHT := 7
const SANDBOX_CORE := Vector2i(10, 3)
const SANDBOX_SPAWNS := {
	&"S1": Vector2i(0, 3),
	&"S2": Vector2i(0, 1),
	&"S3": Vector2i(0, 5)
}
const MAX_LOG_LINES := 220

var _unit_ids: Array[StringName] = []
var _enemy_ids: Array[StringName] = []
var _spawn_keys: Array[StringName] = []
var _spawn_queue: Array[Dictionary] = []
var _selected_unit_runtime_id := -1
var _log_lines: Array[String] = []

@onready var _map_manager: Node = get_node_or_null("Managers/MapManager")
@onready var _path_service: Node = get_node_or_null("Managers/PathService")
@onready var _unit_manager: Node = get_node_or_null("Managers/UnitManager")
@onready var _enemy_manager: Node = get_node_or_null("Managers/EnemyManager")
@onready var _map_root: Node = get_node_or_null("World/MapRoot")


func _ready() -> void:
	add_to_group("combat_debug_log")
	AppTheme.apply(get_node_or_null("UI/Panel") as Control)
	var data_repo = AppRefs.data_repo()
	if data_repo != null:
		data_repo.load_all()
	_setup_ui()
	_connect_events()
	_reset_sandbox()
	set_process(true)


func _process(delta: float) -> void:
	_tick_spawn_queue(delta)
	_refresh_status()
	_refresh_skill_info(_get_selected_unit())
	if _selected_unit_runtime_id >= 0:
		_refresh_attack_range_preview()


func _setup_ui() -> void:
	_configure_spinbox("%EnemyCountSpin", 1.0, 50.0, 1.0, 3.0)
	_configure_spinbox("%EnemyIntervalSpin", 0.05, 10.0, 0.05, 0.5)
	_populate_unit_options()
	_populate_enemy_options()
	_populate_direction_options()
	_populate_spawn_options()
	_connect_button("%StartSpawnButton", _on_start_spawn_pressed)
	_connect_button("%CastSkillButton", _on_cast_skill_pressed)
	_connect_button("%RetreatButton", _on_retreat_pressed)
	_connect_button("%ClearButton", _on_clear_pressed)
	_connect_button("%ResetButton", _on_reset_pressed)


func _connect_events() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	event_bus.map_cell_clicked.connect(_on_map_cell_clicked)
	event_bus.unit_deployed.connect(_on_unit_deployed)
	event_bus.unit_removed.connect(_on_unit_removed)


func _reset_sandbox() -> void:
	_clear_debug_log()
	_spawn_queue.clear()
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
	if _map_manager != null and _map_manager.has_method("generate_debug_map"):
		_map_manager.generate_debug_map(SANDBOX_WIDTH, SANDBOX_HEIGHT, SANDBOX_CORE, SANDBOX_SPAWNS)
	if _path_service != null and _path_service.has_method("rebuild_from_map"):
		_path_service.rebuild_from_map()
	append_combat_debug("战斗沙盒已重置：固定地图 %dx%d，核心 %s，刷怪点 %s" % [SANDBOX_WIDTH, SANDBOX_HEIGHT, SANDBOX_CORE, SANDBOX_SPAWNS.keys()])
	_refresh_status()


func _clear_battlefield() -> void:
	_spawn_queue.clear()
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
	append_combat_debug("清场完成：移除所有单位、敌人、刷怪队列与格子占用")


func _tick_spawn_queue(delta: float) -> void:
	for entry in _spawn_queue.duplicate():
		entry["timer"] = float(entry.get("timer", 0.0)) - delta
		if float(entry["timer"]) > 0.0:
			continue
		_spawn_enemy(StringName(entry.get("enemy_id", "")), StringName(entry.get("spawn_key", "S1")))
		entry["remaining"] = int(entry.get("remaining", 0)) - 1
		if int(entry["remaining"]) <= 0:
			_spawn_queue.erase(entry)
		else:
			entry["timer"] = float(entry.get("interval", 0.5))


func _spawn_enemy(enemy_id: StringName, spawn_key: StringName) -> void:
	if _enemy_manager == null or _map_manager == null:
		return
	var spawn_cell: Vector2i = _map_manager.get_spawn_cell_by_key(spawn_key)
	_enemy_manager.spawn_enemy(enemy_id, spawn_cell)


func _on_map_cell_clicked(cell: Vector2i) -> void:
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


func _on_start_spawn_pressed() -> void:
	var enemy_id := _get_selected_enemy_id()
	var spawn_key := _get_selected_spawn_key()
	if enemy_id == StringName() or spawn_key == StringName():
		return
	_spawn_queue.append({
		"enemy_id": enemy_id,
		"spawn_key": spawn_key,
		"remaining": int(_get_spin_value("%EnemyCountSpin", 1.0)),
		"interval": float(_get_spin_value("%EnemyIntervalSpin", 0.5)),
		"timer": 0.0
	})
	var message := "开始出怪：%s @ %s，数量 %d，间隔 %.2fs" % [
		enemy_id,
		spawn_key,
		int(_get_spin_value("%EnemyCountSpin", 1.0)),
		float(_get_spin_value("%EnemyIntervalSpin", 0.5))
	]
	_show_message(message)
	append_combat_debug(message)


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
	_show_message("已重置战斗沙盒")


func _on_unit_deployed(unit_runtime_id: int, _unit_id: StringName, _cell: Vector2i) -> void:
	_selected_unit_runtime_id = unit_runtime_id
	_refresh_attack_range_preview()


func _on_unit_removed(unit_runtime_id: int, _reason: int) -> void:
	if _selected_unit_runtime_id == unit_runtime_id:
		_selected_unit_runtime_id = -1
		_refresh_attack_range_preview()


func _refresh_status() -> void:
	var label := get_node_or_null("%StatusLabel") as Label
	if label == null:
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
	label.text = "单位 %d  敌人 %d  核心 %s  队列 %d\n选中：%s" % [
		unit_count,
		enemy_count,
		core_text,
		_spawn_queue.size(),
		selected_text
	]


func _refresh_skill_info(selected_unit: Node) -> void:
	var label := get_node_or_null("%SkillInfoLabel") as Label
	if label == null:
		return
	if selected_unit == null:
		label.text = "技能：未选中单位"
		return
	var cfg: Dictionary = selected_unit.cfg
	var skill_name := String(cfg.get("skill_name", cfg.get("skill_id", "未配置技能")))
	var skill_desc := String(cfg.get("skill_description", "暂无技能描述。"))
	var sp_max := float(cfg.get("sp_max", 0.0))
	var sp_text := "无技力"
	if sp_max > 0.0:
		sp_text = "技力 %.0f/%.0f" % [selected_unit.sp, sp_max]
	# 技能描述来自数据表，调试面板只负责展示，避免把技能文案写死在 UI 脚本里。
	label.text = "技能：%s（%s）\n%s" % [skill_name, sp_text, skill_desc]


func _populate_unit_options() -> void:
	var option := get_node_or_null("%UnitOption") as OptionButton
	var data_repo = AppRefs.data_repo()
	if option == null or data_repo == null:
		return
	option.clear()
	_unit_ids = data_repo.get_all_unit_ids()
	for unit_id in _unit_ids:
		var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
		option.add_item(String(cfg.get("name", unit_id)))


func _populate_enemy_options() -> void:
	var option := get_node_or_null("%EnemyOption") as OptionButton
	var data_repo = AppRefs.data_repo()
	if option == null or data_repo == null:
		return
	option.clear()
	_enemy_ids = data_repo.get_all_enemy_ids()
	for enemy_id in _enemy_ids:
		var cfg: Dictionary = data_repo.get_enemy_cfg(enemy_id)
		option.add_item(String(cfg.get("name", enemy_id)))


func _populate_direction_options() -> void:
	var option := get_node_or_null("%FacingOption") as OptionButton
	if option == null:
		return
	option.clear()
	for text in ["右", "下", "左", "上"]:
		option.add_item(text)


func _populate_spawn_options() -> void:
	var option := get_node_or_null("%SpawnOption") as OptionButton
	if option == null:
		return
	option.clear()
	_spawn_keys.clear()
	for spawn_key in SANDBOX_SPAWNS.keys():
		_spawn_keys.append(StringName(spawn_key))
	for spawn_key in _spawn_keys:
		option.add_item(String(spawn_key))


func _get_selected_unit_id() -> StringName:
	var option := get_node_or_null("%UnitOption") as OptionButton
	if option == null or option.selected < 0 or option.selected >= _unit_ids.size():
		return StringName()
	return _unit_ids[option.selected]


func _get_selected_enemy_id() -> StringName:
	var option := get_node_or_null("%EnemyOption") as OptionButton
	if option == null or option.selected < 0 or option.selected >= _enemy_ids.size():
		return StringName()
	return _enemy_ids[option.selected]


func _get_selected_spawn_key() -> StringName:
	var option := get_node_or_null("%SpawnOption") as OptionButton
	if option == null or option.selected < 0 or option.selected >= _spawn_keys.size():
		return StringName()
	return _spawn_keys[option.selected]


func _get_selected_facing() -> Vector2i:
	var option := get_node_or_null("%FacingOption") as OptionButton
	if option == null:
		return Vector2i.RIGHT
	match option.selected:
		1:
			return Vector2i.DOWN
		2:
			return Vector2i.LEFT
		3:
			return Vector2i.UP
		_:
			return Vector2i.RIGHT


func _get_selected_unit() -> Node:
	if _unit_manager == null or _selected_unit_runtime_id < 0:
		return null
	var unit = _unit_manager.get_unit_by_runtime_id(_selected_unit_runtime_id)
	if unit == null or not is_instance_valid(unit):
		_selected_unit_runtime_id = -1
		return null
	return unit


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
	var label := get_node_or_null("%MessageLabel") as Label
	if label != null:
		label.text = text


func append_combat_debug(text: String) -> void:
	var timestamp := Time.get_ticks_msec() / 1000.0
	_log_lines.append("[%.2f] %s" % [timestamp, text])
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	var log_text := get_node_or_null("%CombatLogText") as TextEdit
	if log_text != null:
		log_text.text = "\n".join(_log_lines)
		log_text.scroll_vertical = log_text.get_line_count()


func _clear_debug_log() -> void:
	_log_lines.clear()
	var log_text := get_node_or_null("%CombatLogText") as TextEdit
	if log_text != null:
		log_text.text = ""


func _show_result_message(result: Dictionary, success_text: String, failure_text: String) -> void:
	var message := String(result.get("message", ""))
	if message.is_empty():
		message = success_text if result.get("ok", false) else failure_text
	_show_message(message)
	append_combat_debug(message)


func _connect_button(path: String, callable: Callable) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button != null:
		button.pressed.connect(callable)


func _configure_spinbox(path: String, min_value: float, max_value: float, step: float, value: float) -> void:
	var spinbox := get_node_or_null(path) as SpinBox
	if spinbox == null:
		return
	spinbox.min_value = min_value
	spinbox.max_value = max_value
	spinbox.step = step
	spinbox.value = value


func _get_spin_value(path: String, fallback: float) -> float:
	var spinbox := get_node_or_null(path) as SpinBox
	return spinbox.value if spinbox != null else fallback
