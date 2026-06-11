extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const OperatorProgression = preload("res://scripts/combat/operator_progression.gd")

const RANGED_DEPLOY_CLASSES: Array[StringName] = [&"sniper", &"caster"]

signal operator_redeploy_completed(operator_key: StringName)


var _next_runtime_id := 1
var _units_by_runtime_id: Dictionary = {}
# Deployment state is keyed by operator_key so duplicate unit_id slots stay independent.
var _runtime_by_operator_key: Dictionary = {}
var _operator_key_by_runtime_id: Dictionary = {}
var _deploy_slot_cost_by_runtime_id: Dictionary = {}
var _redeploy_timers: Dictionary = {}
var _refreshing_predeployed_units_for_night := false

@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _unit_root: Node = get_node_or_null("../../World/UnitRoot")


func _ready() -> void:
	set_process(true)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_upgrade_operator_star.connect(_on_request_upgrade_operator_star)


func _process(delta: float) -> void:
	tick_redeploy(delta)


func validate_deploy_operator(operator_key: StringName, cell: Vector2i) -> Dictionary:
	return _validate_deploy_operator(operator_key, cell)


func try_deploy_operator(operator_key: StringName, cell: Vector2i, facing: Vector2i) -> Dictionary:
	var validation := _validate_deploy_operator(operator_key, cell)
	if not bool(validation.get("ok", false)):
		return validation
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	var event_bus = AppRefs.event_bus()
	if run_state == null or data_repo == null:
		return ActionResult.err(&"APP_REFS_MISSING", "操作失败：运行时服务不可用")
	var operator_info: Dictionary = run_state.get_owned_operator(operator_key) if run_state.has_method("get_owned_operator") else {}
	if operator_info.is_empty():
		return ActionResult.err(&"OPERATOR_NOT_OWNED", "无法部署：未拥有该干员")
	if _runtime_by_operator_key.has(operator_key):
		return ActionResult.err(&"OPERATOR_DEPLOYED", "无法部署：干员已经在场")
	if is_operator_redeploying(operator_key):
		return ActionResult.err(&"OPERATOR_COOLDOWN", "无法部署：干员正在再部署冷却中")
	var unit_id := StringName(operator_info.get("unit_id", ""))
	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
	if cfg.is_empty():
		return ActionResult.err(&"UNIT_NOT_FOUND", "操作失败：找不到单位配置")
	if not _is_deploy_phase(int(run_state.phase)):
		return ActionResult.err(&"INVALID_PHASE", "当前阶段不能部署")
	var deploy_slot_cost := _get_operator_deploy_slot_cost(cfg)
	if run_state.deployed_count + deploy_slot_cost > run_state.deploy_limit:
		return ActionResult.err(&"DEPLOY_LIMIT_REACHED", "无法部署：部署上限已满")
	var deploy_cell_result := _validate_deploy_cell(cell, cfg)
	if not deploy_cell_result.get("ok", false):
		return deploy_cell_result

	var scene: PackedScene = data_repo.get_scene_by_key(StringName(cfg.get("scene_key", "")))
	if scene == null:
		return ActionResult.err(&"SCENE_MISSING", "单位场景尚未创建")
	if _unit_root == null:
		return ActionResult.err(&"WORLD_NOT_READY", "操作失败：战场节点尚未就绪")
	var star := OperatorProgression.normalize_star(operator_info.get("star", OperatorProgression.DEFAULT_STAR))
	var effective_cfg := OperatorProgression.make_effective_unit_cfg(cfg, star)
	# 干员实例级盟约（祭坛灌注等）合入战场 cfg，盟约结算与遗物过滤随之生效。
	if run_state.has_method("get_operator_covenants"):
		var merged_covenants: Array = run_state.get_operator_covenants(operator_key)
		if not merged_covenants.is_empty():
			effective_cfg["covenants"] = merged_covenants
	var actor: Node = scene.instantiate()
	_unit_root.add_child(actor)
	actor.runtime_id = _next_runtime_id
	if actor.has_method("setup_from_cfg"):
		actor.setup_from_cfg(unit_id, effective_cfg, cell, facing, operator_key, String(operator_info.get("name", "")))
	_units_by_runtime_id[_next_runtime_id] = actor
	_runtime_by_operator_key[operator_key] = _next_runtime_id
	_operator_key_by_runtime_id[_next_runtime_id] = operator_key
	_deploy_slot_cost_by_runtime_id[_next_runtime_id] = deploy_slot_cost
	if _map_manager != null and _map_manager.has_method("set_unit_occupy"):
		_map_manager.set_unit_occupy(cell, true, _next_runtime_id)
	run_state.change_deployed_count(deploy_slot_cost)
	if event_bus != null:
		event_bus.unit_deployed.emit(_next_runtime_id, operator_key, unit_id, cell)
	_debug_log("部署干员 %s#%d 到格子 %s，朝向 %s" % [String(operator_info.get("name", cfg.get("name", unit_id))), _next_runtime_id, cell, _direction_text(facing)])
	_next_runtime_id += 1
	return ActionResult.ok({"runtime_id": _next_runtime_id - 1, "operator_key": operator_key, "unit_id": unit_id, "star": star})


## 部署落格校验：平地走 is_walkable 全职业；highland 地形仅远程职业（设计稿 §2.4）。
## 人工高台建筑的放行将在后续任务加入本函数（保持单点）。
func _validate_deploy_cell(cell: Vector2i, cfg: Dictionary) -> Dictionary:
	if _map_manager == null:
		return ActionResult.err(&"MAP_UNAVAILABLE", "操作失败：地图尚未初始化")
	var cell_data = _map_manager.get_cell_data(cell) if _map_manager.has_method("get_cell_data") else null
	if cell_data != null and cell_data.is_core:
		return ActionResult.err(&"CELL_NOT_WALKABLE", "无法部署：不能部署在核心上")
	if cell_data != null and cell_data.has_method("allows_ranged_deploy") and cell_data.allows_ranged_deploy():
		if int(cell_data.unit_runtime_id) >= 0:
			return ActionResult.err(&"CELL_NOT_WALKABLE", "无法部署：该格已有干员")
		if not RANGED_DEPLOY_CLASSES.has(StringName(cfg.get("class", ""))):
			return ActionResult.err(&"CLASS_NOT_ALLOWED", "无法部署：高台只能部署狙击/术师")
		return ActionResult.ok()
	if not _map_manager.is_walkable(cell):
		return ActionResult.err(&"CELL_NOT_WALKABLE", "无法部署：目标格不可部署")
	return ActionResult.ok()


func _validate_deploy_operator(operator_key: StringName, cell: Vector2i) -> Dictionary:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null:
		return ActionResult.err(&"APP_REFS_MISSING", "操作失败：运行时服务不可用")
	var operator_info: Dictionary = run_state.get_owned_operator(operator_key) if run_state.has_method("get_owned_operator") else {}
	if operator_info.is_empty():
		return ActionResult.err(&"OPERATOR_NOT_OWNED", "无法部署：未拥有该干员")
	if _runtime_by_operator_key.has(operator_key):
		return ActionResult.err(&"OPERATOR_DEPLOYED", "无法部署：干员已经在场")
	if is_operator_redeploying(operator_key):
		return ActionResult.err(&"OPERATOR_COOLDOWN", "无法部署：干员正在再部署冷却中")
	var unit_id := StringName(operator_info.get("unit_id", ""))
	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
	if cfg.is_empty():
		return ActionResult.err(&"UNIT_NOT_FOUND", "操作失败：找不到单位配置")
	if not _is_deploy_phase(int(run_state.phase)):
		return ActionResult.err(&"INVALID_PHASE", "当前阶段不能部署")
	var deploy_slot_cost := _get_operator_deploy_slot_cost(cfg)
	if run_state.deployed_count + deploy_slot_cost > run_state.deploy_limit:
		return ActionResult.err(&"DEPLOY_LIMIT_REACHED", "无法部署：部署上限已满")
	if _map_manager == null:
		return ActionResult.err(&"MAP_UNAVAILABLE", "操作失败：地图尚未初始化")
	if not _map_manager.is_inside(cell):
		return ActionResult.err(&"CELL_OUT_OF_RANGE", "无法部署：目标格不在地图内")
	if _map_manager.has_method("is_discovered") and not _map_manager.is_discovered(cell):
		return ActionResult.err(&"CELL_NOT_DISCOVERED", "无法部署：目标格尚未探索")
	var deploy_cell_result := _validate_deploy_cell(cell, cfg)
	if not deploy_cell_result.get("ok", false):
		return deploy_cell_result
	return ActionResult.ok({"operator_key": operator_key, "unit_id": unit_id})


func _is_deploy_phase(phase: int) -> bool:
	return phase == GameEnums.PHASE_DAY or phase == GameEnums.PHASE_NIGHT


func try_retreat_unit(unit_runtime_id: int) -> Dictionary:
	var unit := get_unit_by_runtime_id(unit_runtime_id)
	if unit == null:
		return ActionResult.err(&"UNIT_NOT_FOUND", "操作失败：找不到目标单位")
	_debug_log("撤退干员 %s#%d" % [_get_unit_display_name(unit), unit_runtime_id])
	remove_unit(unit_runtime_id, GameEnums.UNIT_REMOVE_RETREAT)
	return ActionResult.ok()


func try_cast_skill(unit_runtime_id: int) -> Dictionary:
	var unit := get_unit_by_runtime_id(unit_runtime_id)
	if unit == null:
		return ActionResult.err(&"UNIT_NOT_FOUND", "操作失败：找不到目标单位")
	if not unit.can_cast_skill():
		return ActionResult.err(&"SP_NOT_READY", "无法释放技能：技力尚未准备好")
	unit.cast_skill()
	return ActionResult.ok()


func try_sell_operator(operator_key: StringName) -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "操作失败：运行状态不可用")
	if int(run_state.phase) != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以出售干员")
	if not run_state.has_owned_operator(operator_key):
		return ActionResult.err(&"OPERATOR_NOT_OWNED", "出售失败：未拥有该干员")
	if is_operator_deployed(operator_key):
		return ActionResult.err(&"OPERATOR_DEPLOYED", "出售失败：请先撤回已部署干员")
	if is_operator_redeploying(operator_key):
		return ActionResult.err(&"OPERATOR_COOLDOWN", "出售失败：干员正在再部署冷却中")
	if not run_state.has_method("sell_owned_operator"):
		return ActionResult.err(&"SELL_UNAVAILABLE", "出售失败：运行状态不支持出售")
	return run_state.sell_owned_operator(operator_key, _foresight_sell_refund(run_state, operator_key))


# v1 取舍：定向升星与出售同门控，只对未部署、未冷却（ready）的干员开放。
func try_upgrade_operator_star(operator_key: StringName) -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "操作失败：运行状态不可用")
	if is_operator_deployed(operator_key):
		return ActionResult.err(&"OPERATOR_DEPLOYED", "升星失败：请先撤回已部署干员")
	if is_operator_redeploying(operator_key):
		return ActionResult.err(&"OPERATOR_COOLDOWN", "升星失败：干员正在再部署冷却中")
	if not run_state.has_method("upgrade_owned_operator_star"):
		return ActionResult.err(&"UPGRADE_UNAVAILABLE", "升星失败：运行状态不支持升星")
	return run_state.upgrade_owned_operator_star(operator_key)


func _on_request_upgrade_operator_star(operator_key: StringName) -> void:
	var result := try_upgrade_operator_star(operator_key)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.operator_star_upgrade_result.emit(operator_key, result)


# 远见 3 人且层数达标时，出售价改为基础价折半；否则返回 -1 用默认出售价。
func _foresight_sell_refund(run_state, operator_key: StringName) -> int:
	var covenant_manager := get_node_or_null("../CovenantManager")
	if covenant_manager == null or not covenant_manager.has_method("get_foresight_tier"):
		return -1
	if int(covenant_manager.get_foresight_tier()) < CovenantDefs.TIER_TRIO:
		return -1
	if int(covenant_manager.get_foresight_layers()) < CovenantDefs.foresight_sell_discount_min_layers():
		return -1
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return -1
	var operator_info: Dictionary = run_state.get_owned_operator(operator_key)
	var cfg: Dictionary = data_repo.get_unit_cfg(StringName(operator_info.get("unit_id", "")))
	return CovenantDefs.foresight_sell_value(int(cfg.get("cost_prestige", 0)))


func get_unit_by_runtime_id(unit_runtime_id: int) -> Node:
	return _units_by_runtime_id.get(unit_runtime_id)


func get_unit_by_operator_key(operator_key: StringName) -> Node:
	var runtime_id := int(_runtime_by_operator_key.get(operator_key, -1))
	return get_unit_by_runtime_id(runtime_id)


func get_operator_key_by_runtime_id(unit_runtime_id: int) -> StringName:
	return StringName(_operator_key_by_runtime_id.get(unit_runtime_id, ""))


func get_all_deployed_units() -> Array:
	return _units_by_runtime_id.values()


func get_unit_by_cell(cell: Vector2i) -> Node:
	for unit in _units_by_runtime_id.values():
		if unit != null and unit.has_method("get_current_cell") and unit.get_current_cell() == cell:
			return unit
	return null


func is_operator_deployed(operator_key: StringName) -> bool:
	return _runtime_by_operator_key.has(operator_key)


func is_operator_redeploying(operator_key: StringName) -> bool:
	return _redeploy_timers.get(operator_key, 0.0) > 0.0


func get_operator_redeploy_remaining(operator_key: StringName) -> float:
	return float(_redeploy_timers.get(operator_key, 0.0))


func get_operator_status(operator_key: StringName) -> StringName:
	if is_operator_deployed(operator_key):
		return &"deployed"
	if is_operator_redeploying(operator_key):
		return &"cooldown"
	return &"ready"


func ready_random_redeploying_operator() -> StringName:
	if _redeploy_timers.is_empty():
		return StringName()
	var operator_keys := _redeploy_timers.keys()
	var operator_key := StringName(operator_keys.pick_random())
	_redeploy_timers.erase(operator_key)
	operator_redeploy_completed.emit(operator_key)
	_debug_log("遗物效果：干员 %s 再部署冷却归零" % String(operator_key))
	return operator_key


func refresh_relic_effects_on_deployed_units() -> void:
	for unit in _units_by_runtime_id.values():
		if unit != null and is_instance_valid(unit) and unit.has_method("refresh_relic_effects"):
			unit.refresh_relic_effects()


func withdraw_operators_for_merge(operator_keys: Array[StringName]) -> Dictionary:
	var withdrawn: Array[StringName] = []
	for operator_key in operator_keys:
		if not _runtime_by_operator_key.has(operator_key):
			continue
		var runtime_id := int(_runtime_by_operator_key.get(operator_key, -1))
		if runtime_id < 0:
			continue
		remove_unit(runtime_id, GameEnums.UNIT_REMOVE_MERGE)
		withdrawn.append(operator_key)
	return ActionResult.ok({"withdrawn_operator_keys": withdrawn})


func tick_redeploy(delta: float) -> void:
	var completed: Array[StringName] = []
	for unit_id in _redeploy_timers.keys():
		_redeploy_timers[unit_id] = max(_redeploy_timers[unit_id] - delta, 0.0)
		if _redeploy_timers[unit_id] <= 0.0:
			completed.append(unit_id)
	for unit_id in completed:
		_redeploy_timers.erase(unit_id)
		operator_redeploy_completed.emit(unit_id)


func prepare_for_day() -> void:
	_redeploy_timers.clear()
	for unit in _units_by_runtime_id.values():
		if unit != null and is_instance_valid(unit) and unit.has_method("receive_heal"):
			unit.receive_heal(int(unit.get("max_hp")))


func refresh_predeployed_units_for_night() -> void:
	var deployments: Array[Dictionary] = []
	for unit in _units_by_runtime_id.values():
		if unit == null or not is_instance_valid(unit):
			continue
		deployments.append({
			"runtime_id": int(unit.get_runtime_id()) if unit.has_method("get_runtime_id") else int(unit.runtime_id),
			"operator_key": _get_unit_operator_key(unit),
			"cell": unit.get_current_cell() if unit.has_method("get_current_cell") else unit.current_cell,
			"facing": unit.facing
		})
	_refreshing_predeployed_units_for_night = true
	for deployment in deployments:
		var runtime_id := int(deployment.get("runtime_id", -1))
		var operator_key := StringName(deployment.get("operator_key", ""))
		var cell: Vector2i = deployment.get("cell", Vector2i.ZERO)
		var facing: Vector2i = deployment.get("facing", Vector2i.RIGHT)
		if runtime_id < 0 or operator_key == StringName():
			continue
		remove_unit(runtime_id, GameEnums.UNIT_REMOVE_PREDEPLOY_REFRESH)
		var result := try_deploy_operator(operator_key, cell, facing)
		if not bool(result.get("ok", false)):
			_debug_log("夜晚开场重新部署失败：%s 于 %s，%s" % [String(operator_key), cell, String(result.get("message", ""))])
	_refreshing_predeployed_units_for_night = false


func is_refreshing_predeployed_units_for_night() -> bool:
	return _refreshing_predeployed_units_for_night


func remove_unit(unit_runtime_id: int, reason: int) -> void:
	var unit := get_unit_by_runtime_id(unit_runtime_id)
	if unit == null:
		return
	var operator_key := _get_unit_operator_key(unit)
	_units_by_runtime_id.erase(unit_runtime_id)
	if operator_key != StringName():
		_runtime_by_operator_key.erase(operator_key)
	_operator_key_by_runtime_id.erase(unit_runtime_id)
	var deploy_slot_cost := 0
	if _deploy_slot_cost_by_runtime_id.has(unit_runtime_id):
		deploy_slot_cost = int(_deploy_slot_cost_by_runtime_id.get(unit_runtime_id, 0))
	else:
		deploy_slot_cost = _get_operator_deploy_slot_cost(unit.cfg)
	_deploy_slot_cost_by_runtime_id.erase(unit_runtime_id)
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if _map_manager != null and _map_manager.has_method("set_unit_occupy"):
		_map_manager.set_unit_occupy(unit.get_current_cell(), false)
	if unit.has_method("release_all_blocked_enemies"):
		unit.release_all_blocked_enemies()
	if reason == GameEnums.UNIT_REMOVE_RETREAT or reason == GameEnums.UNIT_REMOVE_DEAD:
		_start_operator_redeploy(unit, operator_key)
	if run_state != null:
		run_state.change_deployed_count(-deploy_slot_cost)
	if event_bus != null:
		if reason == GameEnums.UNIT_REMOVE_DEAD:
			event_bus.unit_died.emit(unit_runtime_id, StringName(unit.unit_id), unit.get_current_cell())
		event_bus.unit_removed.emit(unit_runtime_id, reason)
	_debug_log("单位离场 %s#%d，原因：%s" % [_get_unit_display_name(unit), unit_runtime_id, _remove_reason_text(reason)])
	unit.queue_free()


func clear_all_units() -> void:
	for unit_runtime_id in _units_by_runtime_id.keys().duplicate():
		remove_unit(int(unit_runtime_id), GameEnums.UNIT_REMOVE_SCRIPTED)
	_redeploy_timers.clear()
	_runtime_by_operator_key.clear()
	_operator_key_by_runtime_id.clear()
	_deploy_slot_cost_by_runtime_id.clear()


func _debug_log(message: String) -> void:
	var tree := get_tree()
	if tree != null:
		tree.call_group("combat_debug_log", "append_combat_debug", message)


func _direction_text(direction: Vector2i) -> String:
	if abs(direction.x) >= abs(direction.y):
		return "Right" if direction.x >= 0 else "Left"
	return "Down" if direction.y >= 0 else "Up"


func _remove_reason_text(reason: int) -> String:
	match reason:
		GameEnums.UNIT_REMOVE_RETREAT:
			return "撤退"
		GameEnums.UNIT_REMOVE_DEAD:
			return "死亡"
		GameEnums.UNIT_REMOVE_SCRIPTED:
			return "调试清场"
		GameEnums.UNIT_REMOVE_MERGE:
			return "合成"
		GameEnums.UNIT_REMOVE_PREDEPLOY_REFRESH:
			return "夜晚开场重新部署"
		_:
			return "未知"


func _get_unit_operator_key(unit: Node) -> StringName:
	if unit == null:
		return StringName()
	return StringName(unit.operator_key) if unit.operator_key != StringName() else StringName(unit.unit_id)


func _start_operator_redeploy(unit: Node, operator_key: StringName) -> void:
	if operator_key == StringName():
		return
	var run_state = AppRefs.run_state()
	if run_state != null and int(run_state.phase) == GameEnums.PHASE_DAY:
		return
	var redeploy_sec := float(unit.get_effective_redeploy_sec()) if unit.has_method("get_effective_redeploy_sec") else float(unit.cfg.get("redeploy_sec", 0.0))
	if redeploy_sec <= 0.0:
		return
	_redeploy_timers[operator_key] = redeploy_sec
	_debug_log("Operator %s slot %s redeploy cooldown %.1fs" % [_get_unit_display_name(unit), String(operator_key), redeploy_sec])


func _get_unit_display_name(unit: Node) -> String:
	if unit == null:
		return "未知单位"
	if unit.operator_name != "":
		return String(unit.operator_name)
	return String(unit.cfg.get("name", unit.unit_id))


func _get_operator_deploy_slot_cost(unit_cfg: Dictionary) -> int:
	var cost := 1
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_buff_effect_total_for_unit"):
		cost += int(round(float(run_state.get_buff_effect_total_for_unit(&"unit_deploy_slot_cost_add", unit_cfg))))
	return max(cost, 0)
