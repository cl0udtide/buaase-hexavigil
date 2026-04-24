extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const DEFAULT_ACTION_POINTS := 10
const DEFAULT_CORE_HP := 10
const DEFAULT_DEPLOY_LIMIT := 4

var phase: int = GameEnums.PHASE_MENU
var day: int = 0
var action_points: int = DEFAULT_ACTION_POINTS
var prestige: int = 0
var wood: int = 0
var stone: int = 0
var mana: int = 0
var core_hp: int = DEFAULT_CORE_HP
var core_hp_max: int = DEFAULT_CORE_HP
var deploy_limit: int = DEFAULT_DEPLOY_LIMIT
var deployed_count: int = 0
var random_seed: int = 0
var owned_units: Array[StringName] = []
# 干员槽位是真正的拥有列表；owned_units 只作为旧 UI / 旧调用路径的兼容视图。
var owned_operators: Array[Dictionary] = []
var buffs: Array[StringName] = []

var _next_operator_serial := 1


func reset_for_new_run(seed: int) -> void:
	random_seed = seed
	phase = GameEnums.PHASE_MENU
	day = 0
	action_points = DEFAULT_ACTION_POINTS
	prestige = 30
	wood = 3
	stone = 2
	mana = 1
	core_hp = DEFAULT_CORE_HP
	core_hp_max = DEFAULT_CORE_HP
	deploy_limit = DEFAULT_DEPLOY_LIMIT
	deployed_count = 0
	owned_units.clear()
	owned_operators.clear()
	_next_operator_serial = 1
	buffs.clear()
	_emit_all_state()


func set_phase(value: int) -> void:
	if phase == value:
		return
	var old_phase := phase
	phase = value
	EventBus.phase_changed.emit(old_phase, phase)


func set_day(value: int) -> void:
	day = value


func reset_action_points(value: int) -> void:
	action_points = max(value, 0)
	EventBus.action_points_changed.emit(action_points)


func consume_action_points(cost: int) -> Dictionary:
	if cost < 0:
		return ActionResult.err(&"INVALID_COST", "行动力消耗不能为负数")
	if action_points < cost:
		return ActionResult.err(&"NOT_ENOUGH_AP", "行动力不足")
	action_points -= cost
	EventBus.action_points_changed.emit(action_points)
	return ActionResult.ok()


func add_prestige(value: int) -> void:
	prestige += value
	EventBus.prestige_changed.emit(prestige)


func spend_prestige(cost: int) -> Dictionary:
	if prestige < cost:
		return ActionResult.err(&"NOT_ENOUGH_PRESTIGE", "声望不足")
	prestige -= cost
	EventBus.prestige_changed.emit(prestige)
	return ActionResult.ok()


func add_materials(add_wood: int, add_stone: int, add_mana: int) -> void:
	wood += add_wood
	stone += add_stone
	mana += add_mana
	EventBus.materials_changed.emit(wood, stone, mana)


func spend_materials(cost_wood: int, cost_stone: int, cost_mana: int) -> Dictionary:
	if wood < cost_wood or stone < cost_stone or mana < cost_mana:
		return ActionResult.err(&"NOT_ENOUGH_MATERIALS", "材料不足")
	wood -= cost_wood
	stone -= cost_stone
	mana -= cost_mana
	EventBus.materials_changed.emit(wood, stone, mana)
	return ActionResult.ok()


func damage_core(value: int) -> void:
	core_hp = max(core_hp - value, 0)
	EventBus.core_hp_changed.emit(core_hp, core_hp_max)
	if core_hp == 0:
		EventBus.core_destroyed.emit()


func heal_core(value: int) -> void:
	core_hp = min(core_hp + value, core_hp_max)
	EventBus.core_hp_changed.emit(core_hp, core_hp_max)


func add_owned_operator(unit_id: StringName, display_name: String = "") -> Dictionary:
	return add_owned_operator_with_key(_make_next_operator_key(), unit_id, display_name)


func add_owned_operator_with_key(operator_key: StringName, unit_id: StringName, display_name: String = "") -> Dictionary:
	if unit_id == StringName():
		return {}
	if operator_key == StringName():
		operator_key = _make_next_operator_key()
	if has_owned_operator(operator_key):
		return {}
	var normalized_name := String(display_name).strip_edges()
	if normalized_name.is_empty():
		normalized_name = _make_operator_name(unit_id)
	var operator := {
		"key": operator_key,
		"unit_id": unit_id,
		"name": normalized_name
	}
	owned_operators.append(operator)
	_sync_next_operator_serial(operator_key)
	_refresh_owned_units_view()
	_emit_owned_roster()
	return operator.duplicate(true)


func get_owned_operator(operator_key: StringName) -> Dictionary:
	for operator in owned_operators:
		if StringName((operator as Dictionary).get("key", "")) == operator_key:
			return (operator as Dictionary).duplicate(true)
	return {}


func get_owned_operators() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for operator in owned_operators:
		result.append((operator as Dictionary).duplicate(true))
	return result


func has_owned_operator(operator_key: StringName) -> bool:
	for operator in owned_operators:
		if StringName((operator as Dictionary).get("key", "")) == operator_key:
			return true
	return false


func remove_owned_operator(operator_key: StringName) -> bool:
	for index in range(owned_operators.size()):
		if StringName((owned_operators[index] as Dictionary).get("key", "")) == operator_key:
			owned_operators.remove_at(index)
			_refresh_owned_units_view()
			_emit_owned_roster()
			return true
	return false


func get_owned_unit_ids() -> Array[StringName]:
	return owned_units.duplicate()


func add_owned_unit(unit_id: StringName) -> void:
	add_owned_operator(unit_id)


func has_owned_unit(unit_id: StringName) -> bool:
	for operator in owned_operators:
		if StringName((operator as Dictionary).get("unit_id", "")) == unit_id:
			return true
	return false


func set_deploy_limit(value: int) -> void:
	deploy_limit = max(value, 0)
	EventBus.deploy_limit_changed.emit(deployed_count, deploy_limit)


func change_deployed_count(delta: int) -> void:
	deployed_count = max(deployed_count + delta, 0)
	EventBus.deploy_limit_changed.emit(deployed_count, deploy_limit)


func add_buff(buff_id: StringName) -> void:
	if buffs.has(buff_id):
		return
	buffs.append(buff_id)
	EventBus.buffs_changed.emit(buffs.duplicate())


func has_buff(buff_id: StringName) -> bool:
	return buffs.has(buff_id)


func get_all_buffs() -> Array[StringName]:
	return buffs.duplicate()


func get_buff_effect_total(effect_type: StringName) -> float:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return 0.0
	var total := 0.0
	for buff_id in buffs:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
		if StringName(cfg.get("effect_type", "")) == effect_type:
			total += float(cfg.get("effect_value", 0.0))
	return total


func _emit_all_state() -> void:
	EventBus.action_points_changed.emit(action_points)
	EventBus.prestige_changed.emit(prestige)
	EventBus.materials_changed.emit(wood, stone, mana)
	EventBus.core_hp_changed.emit(core_hp, core_hp_max)
	EventBus.deploy_limit_changed.emit(deployed_count, deploy_limit)
	_emit_owned_roster()
	EventBus.buffs_changed.emit(buffs.duplicate())


func _emit_owned_roster() -> void:
	EventBus.owned_operators_changed.emit(get_owned_operators())
	EventBus.owned_units_changed.emit(owned_units.duplicate())


func _refresh_owned_units_view() -> void:
	owned_units.clear()
	for operator in owned_operators:
		owned_units.append(StringName((operator as Dictionary).get("unit_id", "")))


func _make_next_operator_key() -> StringName:
	var operator_key := StringName("op_%04d" % _next_operator_serial)
	while has_owned_operator(operator_key):
		_next_operator_serial += 1
		operator_key = StringName("op_%04d" % _next_operator_serial)
	_next_operator_serial += 1
	return operator_key


func _sync_next_operator_serial(operator_key: StringName) -> void:
	var key := String(operator_key)
	if not key.begins_with("op_"):
		return
	var suffix := key.substr(3)
	if suffix.is_valid_int():
		_next_operator_serial = max(_next_operator_serial, int(suffix) + 1)


func _make_operator_name(unit_id: StringName) -> String:
	var data_repo = AppRefs.data_repo()
	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id) if data_repo != null else {}
	var base_name := String(cfg.get("name", unit_id))
	var same_unit_count := 0
	for operator in owned_operators:
		if StringName((operator as Dictionary).get("unit_id", "")) == unit_id:
			same_unit_count += 1
	return base_name if same_unit_count == 0 else "%s%d" % [base_name, same_unit_count + 1]
