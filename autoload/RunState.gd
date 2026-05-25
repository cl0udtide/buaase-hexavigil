extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const OperatorProgression = preload("res://scripts/combat/operator_progression.gd")

const DEFAULT_ACTION_POINTS := 30
const DEFAULT_INITIAL_PRESTIGE := 8
const DEFAULT_CORE_HP := 10
const DEFAULT_DEPLOY_LIMIT := 4
const DEPLOY_LIMIT_INCREASE_DAYS := 2
const OPERATOR_SELL_PRESTIGE := 1

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
var _day_deploy_limit_bonus: int = 0


func reset_for_new_run(seed: int) -> void:
	random_seed = seed
	phase = GameEnums.PHASE_MENU
	day = 0
	action_points = DEFAULT_ACTION_POINTS
	prestige = DEFAULT_INITIAL_PRESTIGE
	wood = 3
	stone = 2
	mana = 1
	core_hp = DEFAULT_CORE_HP
	core_hp_max = DEFAULT_CORE_HP
	deploy_limit = DEFAULT_DEPLOY_LIMIT
	deployed_count = 0
	_day_deploy_limit_bonus = 0
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
	_apply_day_deploy_limit_bonus()


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


func add_owned_operator(unit_id: StringName, display_name: String = "", star: int = OperatorProgression.DEFAULT_STAR) -> Dictionary:
	return add_owned_operator_with_key(_make_next_operator_key(), unit_id, display_name, star)


func add_owned_operator_with_key(operator_key: StringName, unit_id: StringName, display_name: String = "", star: int = OperatorProgression.DEFAULT_STAR) -> Dictionary:
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
		"name": normalized_name,
		"star": OperatorProgression.normalize_star(star)
	}
	owned_operators.append(operator)
	_sync_next_operator_serial(operator_key)
	_refresh_owned_units_view()
	_emit_owned_roster()
	return _normalized_operator_dict(operator)


func get_owned_operator(operator_key: StringName) -> Dictionary:
	for operator in owned_operators:
		if StringName((operator as Dictionary).get("key", "")) == operator_key:
			return _normalized_operator_dict(operator as Dictionary)
	return {}


func get_owned_operators() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for operator in owned_operators:
		result.append(_normalized_operator_dict(operator as Dictionary))
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


func sell_owned_operator(operator_key: StringName) -> Dictionary:
	if phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以出售干员")
	if not has_owned_operator(operator_key):
		return ActionResult.err(&"OPERATOR_NOT_OWNED", "出售失败：未拥有该干员")
	var operator_info := get_owned_operator(operator_key)
	var display_name := String(operator_info.get("name", operator_key))
	if not _remove_owned_operator_no_emit(operator_key):
		return ActionResult.err(&"OPERATOR_NOT_OWNED", "出售失败：未拥有该干员")
	_refresh_owned_units_view()
	add_prestige(OPERATOR_SELL_PRESTIGE)
	_emit_owned_roster()
	return ActionResult.ok({
		"operator_key": operator_key,
		"refund_prestige": OPERATOR_SELL_PRESTIGE
	}, "已出售 %s，获得 %d 声望" % [display_name, OPERATOR_SELL_PRESTIGE])


func auto_merge_operators_for_unit(unit_id: StringName, before_merge: Callable = Callable()) -> Dictionary:
	var merge_events: Array[Dictionary] = []
	var changed := false
	var merged_this_pass := true
	while merged_this_pass:
		merged_this_pass = false
		for star in range(OperatorProgression.MIN_STAR, OperatorProgression.MAX_STAR):
			while true:
				var group := _get_merge_group(unit_id, star)
				if group.size() < 3:
					break
				var participant_keys: Array[StringName] = []
				for operator in group:
					participant_keys.append(StringName((operator as Dictionary).get("key", "")))
				if before_merge.is_valid():
					before_merge.call(participant_keys)
				var kept_key := participant_keys[0]
				var consumed_keys: Array[StringName] = []
				for index in range(1, participant_keys.size()):
					consumed_keys.append(participant_keys[index])
				_set_owned_operator_star_no_emit(kept_key, star + 1)
				for consumed_key in consumed_keys:
					_remove_owned_operator_no_emit(consumed_key)
				merge_events.append({
					"unit_id": unit_id,
					"from_star": star,
					"to_star": star + 1,
					"kept_key": kept_key,
					"consumed_keys": consumed_keys,
					"participant_keys": participant_keys
				})
				changed = true
				merged_this_pass = true
	if changed:
		_refresh_owned_units_view()
		_emit_owned_roster()
	return ActionResult.ok({"merge_events": merge_events})


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
		for effect in _get_buff_effect_entries(cfg):
			if _buff_effect_has_filters(effect):
				continue
			if StringName(effect.get("effect_type", "")) == effect_type:
				total += float(effect.get("effect_value", 0.0))
	return total


func get_buff_effect_total_for_unit(effect_type: StringName, unit_cfg: Dictionary) -> float:
	var tags: Dictionary = {
		"class": StringName(unit_cfg.get("class", "")),
		"damage_type": StringName(unit_cfg.get("damage_type", "")),
		"cost_prestige": int(unit_cfg.get("cost_prestige", 0))
	}
	return _get_filtered_buff_effect_total(effect_type, tags)


func get_buff_effect_total_for_building(effect_type: StringName, building_cfg: Dictionary) -> float:
	var tags: Dictionary = {
		"building_type": StringName(building_cfg.get("building_type", "")),
		"effect_type": StringName(building_cfg.get("effect_type", ""))
	}
	return _get_filtered_buff_effect_total(effect_type, tags)


func get_buff_effect_total_for_material(effect_type: StringName, material: StringName) -> float:
	return _get_filtered_buff_effect_total(effect_type, {"material": material})


func _get_filtered_buff_effect_total(effect_type: StringName, tags: Dictionary) -> float:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return 0.0
	var total := 0.0
	for buff_id in buffs:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
		for effect in _get_buff_effect_entries(cfg):
			if StringName(effect.get("effect_type", "")) != effect_type:
				continue
			if not _buff_matches_tags(effect, tags):
				continue
			total += float(effect.get("effect_value", 0.0))
	return total


func _get_buff_effect_entries(cfg: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if cfg.has("effects") and typeof(cfg.get("effects")) == TYPE_ARRAY:
		for raw_effect in cfg.get("effects", []):
			if typeof(raw_effect) == TYPE_DICTIONARY:
				var effect := (raw_effect as Dictionary).duplicate(true)
				for key in ["class_filter", "damage_type_filter", "building_type_filter", "material_filter", "max_cost_prestige", "min_cost_prestige"]:
					if not effect.has(key) and cfg.has(key):
						effect[key] = cfg[key]
				result.append(effect)
	if result.is_empty() and cfg.has("effect_type"):
		result.append(cfg)
	return result


func _buff_matches_tags(effect: Dictionary, tags: Dictionary) -> bool:
	for key in ["class", "damage_type", "building_type", "material"]:
		var filter_key := "%s_filter" % key
		if not effect.has(filter_key):
			continue
		var expected := StringName(effect.get(filter_key, ""))
		if expected != StringName() and expected != StringName(tags.get(key, "")):
			return false
	if effect.has("max_cost_prestige") and int(tags.get("cost_prestige", 999)) > int(effect.get("max_cost_prestige", 999)):
		return false
	if effect.has("min_cost_prestige") and int(tags.get("cost_prestige", 0)) < int(effect.get("min_cost_prestige", 0)):
		return false
	return true


func _buff_effect_has_filters(effect: Dictionary) -> bool:
	for key in ["class_filter", "damage_type_filter", "building_type_filter", "material_filter", "max_cost_prestige", "min_cost_prestige"]:
		if effect.has(key):
			return true
	return false


func _emit_all_state() -> void:
	EventBus.action_points_changed.emit(action_points)
	EventBus.prestige_changed.emit(prestige)
	EventBus.materials_changed.emit(wood, stone, mana)
	EventBus.core_hp_changed.emit(core_hp, core_hp_max)
	EventBus.deploy_limit_changed.emit(deployed_count, deploy_limit)
	_emit_owned_roster()
	EventBus.buffs_changed.emit(buffs.duplicate())


func _apply_day_deploy_limit_bonus() -> void:
	var next_bonus: int = _get_day_deploy_limit_bonus(day)
	var delta: int = next_bonus - _day_deploy_limit_bonus
	_day_deploy_limit_bonus = next_bonus
	if delta != 0:
		set_deploy_limit(deploy_limit + delta)


func _get_day_deploy_limit_bonus(day_value: int) -> int:
	if day_value <= 1:
		return 0
	return int(floor(float(day_value - 1) / float(DEPLOY_LIMIT_INCREASE_DAYS)))


func _emit_owned_roster() -> void:
	EventBus.owned_operators_changed.emit(get_owned_operators())
	EventBus.owned_units_changed.emit(owned_units.duplicate())


func _normalized_operator_dict(operator: Dictionary) -> Dictionary:
	var normalized := operator.duplicate(true)
	normalized["star"] = OperatorProgression.normalize_star(normalized.get("star", OperatorProgression.DEFAULT_STAR))
	return normalized


func _refresh_owned_units_view() -> void:
	owned_units.clear()
	for operator in owned_operators:
		owned_units.append(StringName((operator as Dictionary).get("unit_id", "")))


func _get_merge_group(unit_id: StringName, star: int) -> Array[Dictionary]:
	var group: Array[Dictionary] = []
	for operator in owned_operators:
		var operator_dict := operator as Dictionary
		if StringName(operator_dict.get("unit_id", "")) != unit_id:
			continue
		if OperatorProgression.normalize_star(operator_dict.get("star", OperatorProgression.DEFAULT_STAR)) != star:
			continue
		group.append(operator_dict)
		if group.size() >= 3:
			break
	return group


func _set_owned_operator_star_no_emit(operator_key: StringName, star: int) -> bool:
	for index in range(owned_operators.size()):
		var operator_dict := owned_operators[index] as Dictionary
		if StringName(operator_dict.get("key", "")) != operator_key:
			continue
		operator_dict["star"] = OperatorProgression.normalize_star(star)
		owned_operators[index] = operator_dict
		return true
	return false


func _remove_owned_operator_no_emit(operator_key: StringName) -> bool:
	for index in range(owned_operators.size()):
		if StringName((owned_operators[index] as Dictionary).get("key", "")) == operator_key:
			owned_operators.remove_at(index)
			return true
	return false


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
