extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const OperatorProgression = preload("res://scripts/combat/operator_progression.gd")

signal cheat_state_changed(state: Dictionary)
signal cheat_action_result(result: Dictionary)

const RESOURCE_TARGET := 999
const ACTION_POINT_TARGET := 99
const MAX_DEBUG_DAY := 9

@onready var _game_controller: Node = get_node_or_null("../GameController")
@onready var _night_manager: Node = get_node_or_null("../NightManager")
@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _shop_manager: Node = get_node_or_null("../ShopManager")
@onready var _buff_manager: Node = get_node_or_null("../BuffManager")
@onready var _enemy_manager: Node = get_node_or_null("../EnemyManager")
@onready var _wave_manager: Node = get_node_or_null("../WaveManager")

var _cheats_enabled := false
var _infinite_action_points := false
var _infinite_resources := false
var _infinite_core_hp := false
var _syncing_state := false


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	event_bus.action_points_changed.connect(_on_action_points_changed)
	event_bus.prestige_changed.connect(_on_prestige_changed)
	event_bus.materials_changed.connect(_on_materials_changed)
	event_bus.core_hp_changed.connect(_on_core_hp_changed)


func is_cheats_enabled() -> bool:
	return _cheats_enabled


func get_state() -> Dictionary:
	return {
		"enabled": _cheats_enabled,
		"infinite_action_points": _infinite_action_points,
		"infinite_resources": _infinite_resources,
		"infinite_core_hp": _infinite_core_hp
	}


func set_cheats_enabled(enabled: bool) -> Dictionary:
	_cheats_enabled = enabled
	if not _cheats_enabled:
		_infinite_action_points = false
		_infinite_resources = false
		_infinite_core_hp = false
	_emit_state_changed()
	return _ok("作弊模式已开启" if enabled else "作弊模式已关闭")


func set_infinite_action_points(enabled: bool) -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	_infinite_action_points = enabled
	if _infinite_action_points:
		_refill_action_points()
	_emit_state_changed()
	return _ok("无限行动力已开启" if enabled else "无限行动力已关闭")


func set_infinite_resources(enabled: bool) -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	_infinite_resources = enabled
	if _infinite_resources:
		_refill_resources()
	_emit_state_changed()
	return _ok("无限资源已开启" if enabled else "无限资源已关闭")


func set_infinite_core_hp(enabled: bool) -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	_infinite_core_hp = enabled
	if _infinite_core_hp:
		_refill_core_hp()
	_emit_state_changed()
	return _ok("核心血量无限已开启" if enabled else "核心血量无限已关闭")


func fill_resources() -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	_refill_resources()
	return _ok("资源已补到调试上限")


func fill_action_points() -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	_refill_action_points()
	return _ok("行动力已补到调试上限")


func heal_core_full() -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	_refill_core_hp()
	return _ok("核心生命已回满")


func reveal_all_fog() -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	if _map_manager == null or not _map_manager.has_method("get_all_cells") or not _map_manager.has_method("get_cell_data"):
		return _err(&"MAP_UNAVAILABLE", "地图管理器不可用")
	var revealed: Array[Vector2i] = []
	for cell in _map_manager.get_all_cells():
		var data: CellData = _map_manager.get_cell_data(cell)
		if data == null or data.discovered:
			continue
		if data.spawn_key != StringName():
			continue
		data.discovered = true
		revealed.append(cell)
	var event_bus = AppRefs.event_bus()
	if event_bus != null and not revealed.is_empty():
		event_bus.fog_revealed.emit(revealed)
	return _ok("迷雾已全开", {"revealed": revealed.size()})


func go_next_day() -> Dictionary:
	var run_state = AppRefs.run_state()
	if not _ensure_enabled():
		return _disabled_error()
	if run_state == null:
		return _err(&"RUN_STATE_MISSING", "运行状态不可用")
	return jump_to_day(clampi(int(run_state.day) + 1, 1, MAX_DEBUG_DAY))


func jump_to_day(day_value: int) -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	var day := clampi(day_value, 1, MAX_DEBUG_DAY)
	if _game_controller == null or not _game_controller.has_method("enter_day"):
		return _err(&"GAME_CONTROLLER_MISSING", "游戏控制器不可用")
	_clear_active_night_state()
	_game_controller.enter_day(day)
	_apply_persistent_cheats()
	return _ok("已跳转到第 %d 天" % day, {"day": day})


func start_night_now() -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	var run_state = AppRefs.run_state()
	if run_state == null:
		return _err(&"RUN_STATE_MISSING", "运行状态不可用")
	if int(run_state.phase) != GameEnums.PHASE_DAY:
		return _err(&"INVALID_PHASE", "只有白天可以直接进入夜晚")
	if _game_controller == null or not _game_controller.has_method("enter_night"):
		return _err(&"GAME_CONTROLLER_MISSING", "游戏控制器不可用")
	_game_controller.enter_night()
	_apply_persistent_cheats()
	return _ok("已直接进入夜晚")


func clear_current_night() -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	var run_state = AppRefs.run_state()
	if run_state == null:
		return _err(&"RUN_STATE_MISSING", "运行状态不可用")
	if int(run_state.phase) != GameEnums.PHASE_NIGHT:
		return _err(&"INVALID_PHASE", "当前不在夜晚阶段")
	_clear_active_night_state()
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.night_cleared.emit(int(run_state.day))
	_apply_persistent_cheats()
	return _ok("当前夜晚已清场")


func clear_enemies() -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	if _enemy_manager == null or not _enemy_manager.has_method("clear_all_enemies"):
		return _err(&"ENEMY_MANAGER_MISSING", "敌人管理器不可用")
	_enemy_manager.clear_all_enemies()
	return _ok("场上敌人已清除")


func grant_unit(unit_id: StringName, star: int = OperatorProgression.DEFAULT_STAR) -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	if data_repo == null or run_state == null:
		return _err(&"APP_REFS_MISSING", "运行时服务不可用")
	if unit_id == StringName() or data_repo.get_unit_cfg(unit_id).is_empty():
		return _err(&"UNIT_NOT_FOUND", "找不到指定干员")
	var result: Dictionary
	if _shop_manager != null and _shop_manager.has_method("grant_unit"):
		result = _shop_manager.grant_unit(unit_id, star)
	else:
		var operator_info: Dictionary = run_state.add_owned_operator(unit_id, "", star)
		result = ActionResult.ok({"operator": operator_info, "unit_id": unit_id}, "已加入待部署区")
	_report(result)
	return result


func grant_all_units(star: int = OperatorProgression.DEFAULT_STAR) -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return _err(&"DATA_REPO_MISSING", "数据表不可用")
	var count := 0
	for unit_id in data_repo.get_all_unit_ids():
		var result := grant_unit(unit_id, star)
		if bool(result.get("ok", false)):
			count += 1
	var final_result := ActionResult.ok({"count": count}, "已添加 %d 名干员" % count)
	_report(final_result)
	return final_result


func grant_relic(buff_id: StringName) -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	var data_repo = AppRefs.data_repo()
	if data_repo == null or buff_id == StringName() or data_repo.get_buff_cfg(buff_id).is_empty():
		return _err(&"BUFF_NOT_FOUND", "找不到指定遗物")
	var result: Dictionary
	if _buff_manager != null and _buff_manager.has_method("apply_blessing"):
		result = _buff_manager.apply_blessing(buff_id)
	else:
		var run_state = AppRefs.run_state()
		if run_state == null:
			result = ActionResult.err(&"RUN_STATE_MISSING", "运行状态不可用")
		else:
			run_state.add_buff(buff_id)
			result = ActionResult.ok({"buff_id": buff_id}, "已获得遗物")
	_report(result)
	return result


func grant_all_relics() -> Dictionary:
	if not _ensure_enabled():
		return _disabled_error()
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	if data_repo == null or run_state == null:
		return _err(&"APP_REFS_MISSING", "运行时服务不可用")
	var count := 0
	for buff_id in data_repo.get_all_buff_ids():
		if run_state.has_buff(buff_id):
			continue
		var result := grant_relic(buff_id)
		if bool(result.get("ok", false)):
			count += 1
	var final_result := ActionResult.ok({"count": count}, "已添加 %d 件遗物" % count)
	_report(final_result)
	return final_result


func _on_action_points_changed(_value: int) -> void:
	if _cheats_enabled and _infinite_action_points:
		_refill_action_points()


func _on_prestige_changed(_value: int) -> void:
	if _cheats_enabled and _infinite_resources:
		_refill_resources()


func _on_materials_changed(_wood: int, _stone: int, _mana: int) -> void:
	if _cheats_enabled and _infinite_resources:
		_refill_resources()


func _on_core_hp_changed(_current: int, _max_value: int) -> void:
	if _cheats_enabled and _infinite_core_hp:
		_refill_core_hp()


func _apply_persistent_cheats() -> void:
	if _infinite_action_points:
		_refill_action_points()
	if _infinite_resources:
		_refill_resources()
	if _infinite_core_hp:
		_refill_core_hp()


func _refill_action_points() -> void:
	if _syncing_state:
		return
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	if int(run_state.action_points) >= ACTION_POINT_TARGET:
		return
	_syncing_state = true
	run_state.reset_action_points(ACTION_POINT_TARGET)
	_syncing_state = false


func _refill_resources() -> void:
	if _syncing_state:
		return
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	_syncing_state = true
	if int(run_state.prestige) < RESOURCE_TARGET:
		run_state.add_prestige(RESOURCE_TARGET - int(run_state.prestige))
	if int(run_state.wood) < RESOURCE_TARGET or int(run_state.stone) < RESOURCE_TARGET or int(run_state.mana) < RESOURCE_TARGET:
		run_state.add_materials(
			maxi(RESOURCE_TARGET - int(run_state.wood), 0),
			maxi(RESOURCE_TARGET - int(run_state.stone), 0),
			maxi(RESOURCE_TARGET - int(run_state.mana), 0)
		)
	_syncing_state = false


func _refill_core_hp() -> void:
	if _syncing_state:
		return
	var run_state = AppRefs.run_state()
	if run_state == null or int(run_state.core_hp_max) <= 0:
		return
	if int(run_state.core_hp) >= int(run_state.core_hp_max):
		return
	_syncing_state = true
	if run_state.has_method("heal_core_full"):
		run_state.heal_core_full()
	else:
		run_state.heal_core(int(run_state.core_hp_max))
	_syncing_state = false


func _clear_active_night_state() -> void:
	if _enemy_manager != null and _enemy_manager.has_method("clear_all_enemies"):
		_enemy_manager.clear_all_enemies()
	if _wave_manager != null and _wave_manager.has_method("stop_wave"):
		_wave_manager.stop_wave()
	if _night_manager != null and _night_manager.has_method("finish_night"):
		_night_manager.finish_night()


func _ensure_enabled() -> bool:
	return _cheats_enabled


func _disabled_error() -> Dictionary:
	return _err(&"CHEATS_DISABLED", "请先开启作弊模式")


func _emit_state_changed() -> void:
	cheat_state_changed.emit(get_state())


func _ok(message: String, payload: Dictionary = {}) -> Dictionary:
	var result := ActionResult.ok(payload, message)
	_report(result)
	return result


func _err(code: StringName, message: String, payload: Dictionary = {}) -> Dictionary:
	var result := ActionResult.err(code, message, payload)
	_report(result)
	return result


func _report(result: Dictionary) -> void:
	cheat_action_result.emit(result)
