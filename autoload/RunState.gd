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
var buffs: Array[StringName] = []


func reset_for_new_run(seed: int) -> void:
	random_seed = seed
	phase = GameEnums.PHASE_MENU
	day = 0
	action_points = DEFAULT_ACTION_POINTS
	prestige = 3
	wood = 3
	stone = 2
	mana = 1
	core_hp = DEFAULT_CORE_HP
	core_hp_max = DEFAULT_CORE_HP
	deploy_limit = DEFAULT_DEPLOY_LIMIT
	deployed_count = 0
	owned_units.clear()
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


func add_owned_unit(unit_id: StringName) -> void:
	if owned_units.has(unit_id):
		return
	owned_units.append(unit_id)
	EventBus.owned_units_changed.emit(owned_units.duplicate())


func has_owned_unit(unit_id: StringName) -> bool:
	return owned_units.has(unit_id)


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
	EventBus.owned_units_changed.emit(owned_units.duplicate())
