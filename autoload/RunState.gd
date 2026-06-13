extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const OperatorProgression = preload("res://scripts/combat/operator_progression.gd")

const DEFAULT_ACTION_POINTS := 30
const DEFAULT_INITIAL_PRESTIGE := 8
const DEFAULT_CORE_HP := 10
const DEFAULT_DEPLOY_LIMIT := 4
const DEPLOY_LIMIT_INCREASE_DAYS := 2
const OPERATOR_SELL_PRESTIGE := 1
# 定向升星价目（按当前星级索引）。占位定价，刻意高于商店合成期望：应急定向通道，不是合成主路径。
const OPERATOR_STAR_UP_COSTS := {
	1: {"mana": 3, "prestige": 4},
	2: {"mana": 6, "prestige": 8}
}
const RUN_MODE_STANDARD := &"standard"
const RUN_MODE_TUTORIAL := &"tutorial"

var phase: int = GameEnums.PHASE_MENU
var run_mode: StringName = RUN_MODE_STANDARD
var tutorial_completed := false
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
var night_template_id: StringName = &""
# 当晚完整波次计划（night_template_id 始终等于首波，作为旧调用路径的兼容视图）。
var night_wave_template_ids: Array[StringName] = []
var night_affix_ids: Array[StringName] = []
# 战争赌局契约：当晚激活、核心是否失血、待发放的额外遗物三选一次数。
var night_wager_active := false
var night_core_damaged := false
var pending_milestone_blessing := false
var pending_extra_blessings := 0
# 一夜覆盖项：玩家当晚手动封闭/额外开启的出怪口 key 列表，黎明由 clear_night_gate_overrides 清空。
var night_gate_closed_keys: Array[String] = []
var night_gate_extra_open_keys: Array[String] = []
var night_gate_seals_today: int = 0
var used_template_ids: Array[StringName] = []
var owned_units: Array[StringName] = []
# 干员槽位是真正的拥有列表；owned_units 只作为旧 UI / 旧调用路径的兼容视图。
var owned_operators: Array[Dictionary] = []
# 本局内按单位类型永久追加的盟约 tag。祭坛灌注写在这里，因此现有与后续同名实例都继承。
var unit_extra_covenants: Dictionary = {}
var buffs: Array[StringName] = []

var _next_operator_serial := 1
var _day_deploy_limit_bonus: int = 0


func reset_for_new_run(seed: int, mode: StringName = RUN_MODE_STANDARD) -> void:
	random_seed = seed
	run_mode = _normalize_run_mode(mode)
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
	night_template_id = &""
	night_wave_template_ids.clear()
	night_affix_ids.clear()
	night_wager_active = false
	night_core_damaged = false
	pending_milestone_blessing = false
	pending_extra_blessings = 0
	clear_night_gate_overrides()
	used_template_ids.clear()
	_day_deploy_limit_bonus = 0
	owned_units.clear()
	owned_operators.clear()
	unit_extra_covenants.clear()
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
	var damage: int = maxi(value, 0)
	var previous_hp := core_hp
	core_hp = max(core_hp - damage, 0)
	EventBus.core_hp_changed.emit(core_hp, core_hp_max)
	var actual_damage := previous_hp - core_hp
	if actual_damage > 0:
		EventBus.core_damaged.emit(actual_damage, core_hp, core_hp_max)
	if previous_hp > 0 and core_hp == 0:
		EventBus.core_destroyed.emit()


func heal_core(value: int) -> void:
	core_hp = min(core_hp + value, core_hp_max)
	EventBus.core_hp_changed.emit(core_hp, core_hp_max)


func heal_core_full() -> void:
	core_hp = core_hp_max
	EventBus.core_hp_changed.emit(core_hp, core_hp_max)


## 增减核心生命上限（事件契约等使用）。上限最低保留 1；正向增加同时回复等量生命。
func add_core_max_hp(delta: int) -> void:
	core_hp_max = max(core_hp_max + delta, 1)
	if delta > 0:
		core_hp = min(core_hp + delta, core_hp_max)
	else:
		core_hp = clamp(core_hp, 1, core_hp_max)
	EventBus.core_hp_changed.emit(core_hp, core_hp_max)


func set_core_hp_to_one() -> void:
	core_hp = min(1, core_hp_max)
	EventBus.core_hp_changed.emit(core_hp, core_hp_max)


func set_core_max_hp_to_one() -> void:
	core_hp_max = 1
	core_hp = 1
	EventBus.core_hp_changed.emit(core_hp, core_hp_max)


## 清空当晚所有出怪口覆盖项（黎明由 game_controller 调用；new_run 也调用）。
func clear_night_gate_overrides() -> void:
	night_gate_closed_keys = []
	night_gate_extra_open_keys = []
	night_gate_seals_today = 0
	EventBus.night_gate_overrides_changed.emit()


## 玩家封闭一个出怪口（当晚有效，去重）。
func add_night_gate_closed(gate_key: String) -> void:
	if gate_key.is_empty() or night_gate_closed_keys.has(gate_key):
		return
	night_gate_closed_keys.append(gate_key)
	EventBus.night_gate_overrides_changed.emit()


## 玩家额外开启一个出怪口（当晚有效，去重）。
func add_night_gate_extra_open(gate_key: String) -> void:
	if gate_key.is_empty() or night_gate_extra_open_keys.has(gate_key):
		return
	night_gate_extra_open_keys.append(gate_key)
	EventBus.night_gate_overrides_changed.emit()


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


func sell_owned_operator(operator_key: StringName, refund_override: int = -1) -> Dictionary:
	if phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以出售干员")
	if not has_owned_operator(operator_key):
		return ActionResult.err(&"OPERATOR_NOT_OWNED", "出售失败：未拥有该干员")
	var operator_info := get_owned_operator(operator_key)
	var display_name := String(operator_info.get("name", operator_key))
	if not _remove_owned_operator_no_emit(operator_key):
		return ActionResult.err(&"OPERATOR_NOT_OWNED", "出售失败：未拥有该干员")
	# refund_override 由调用方按盟约（远见）等规则计算；<0 表示用默认出售价。
	var refund := refund_override if refund_override >= 0 else OPERATOR_SELL_PRESTIGE
	_refresh_owned_units_view()
	add_prestige(refund)
	_emit_owned_roster()
	return ActionResult.ok({
		"operator_key": operator_key,
		"refund_prestige": refund
	}, "已出售 %s，获得 %d 声望" % [display_name, refund])


## 定向升星价格；满星（或更高）时返回空字典。
func get_operator_star_up_cost(star: int) -> Dictionary:
	var cost: Variant = OPERATOR_STAR_UP_COSTS.get(OperatorProgression.normalize_star(star))
	if typeof(cost) != TYPE_DICTIONARY:
		return {}
	return (cost as Dictionary).duplicate()


## 定向升星：白天消耗魔力矿+声望，把指定干员 +1 星。部署/冷却门控由 UnitManager 负责。
func upgrade_owned_operator_star(operator_key: StringName) -> Dictionary:
	if phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以升星干员")
	var operator_info := get_owned_operator(operator_key)
	if operator_info.is_empty():
		return ActionResult.err(&"OPERATOR_NOT_OWNED", "升星失败：未拥有该干员")
	var star := OperatorProgression.normalize_star(operator_info.get("star", OperatorProgression.DEFAULT_STAR))
	var cost := get_operator_star_up_cost(star)
	if cost.is_empty():
		return ActionResult.err(&"STAR_MAXED", "升星失败：该干员已满星")
	var cost_mana := int(cost.get("mana", 0))
	var cost_prestige := int(cost.get("prestige", 0))
	# 两种资源先整体校验再分别扣，避免只扣一半。
	if mana < cost_mana:
		return ActionResult.err(&"NOT_ENOUGH_MATERIALS", "升星失败：魔力矿不足")
	if prestige < cost_prestige:
		return ActionResult.err(&"NOT_ENOUGH_PRESTIGE", "升星失败：声望不足")
	spend_materials(0, 0, cost_mana)
	spend_prestige(cost_prestige)
	_set_owned_operator_star_no_emit(operator_key, star + 1)
	_emit_owned_roster()
	return ActionResult.ok({
		"operator_key": operator_key,
		"from_star": star,
		"to_star": star + 1,
		"cost_mana": cost_mana,
		"cost_prestige": cost_prestige
	}, "%s 升至 %s" % [String(operator_info.get("name", operator_key)), OperatorProgression.format_star_label(star + 1)])


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
			if not _buff_effect_is_active(effect):
				continue
			if _buff_effect_has_filters(effect):
				continue
			if StringName(effect.get("effect_type", "")) == effect_type:
				total += float(effect.get("effect_value", 0.0))
	return total


func get_buff_effect_total_for_unit(effect_type: StringName, unit_cfg: Dictionary) -> float:
	var tags: Dictionary = {
		"class": StringName(unit_cfg.get("class", "")),
		"damage_type": StringName(unit_cfg.get("damage_type", "")),
		"cost_prestige": int(unit_cfg.get("cost_prestige", 0)),
		"covenants": unit_cfg.get("covenants", [])
	}
	return _get_filtered_buff_effect_total(effect_type, tags) + _get_dynamic_unit_buff_effect_total(effect_type, tags)


func get_buff_effect_total_for_building(effect_type: StringName, building_cfg: Dictionary) -> float:
	var tags: Dictionary = {
		"building_type": StringName(building_cfg.get("building_type", "")),
		"effect_type": StringName(building_cfg.get("effect_type", ""))
	}
	return _get_filtered_buff_effect_total(effect_type, tags)


func get_buff_effect_total_for_material(effect_type: StringName, material: StringName) -> float:
	return _get_filtered_buff_effect_total(effect_type, {"material": material})


func get_buff_effect_total_for_enemy(effect_type: StringName, enemy_cfg: Dictionary) -> float:
	var tags: Dictionary = {
		"enemy_id": StringName(enemy_cfg.get("id", "")),
		"damage_type": StringName(enemy_cfg.get("damage_type", ""))
	}
	return _get_filtered_buff_effect_total(effect_type, tags)


func get_enemy_damage_taken_percent(damage_type: int, enemy_cfg: Dictionary) -> float:
	var tags: Dictionary = {
		"enemy_id": StringName(enemy_cfg.get("id", "")),
		"damage_type": _damage_type_key(damage_type)
	}
	return _get_filtered_buff_effect_total(&"enemy_damage_taken_percent", tags)


func get_buff_effect_entries_for_unit(effect_type: StringName, unit_cfg: Dictionary) -> Array[Dictionary]:
	var tags: Dictionary = {
		"class": StringName(unit_cfg.get("class", "")),
		"damage_type": StringName(unit_cfg.get("damage_type", "")),
		"cost_prestige": int(unit_cfg.get("cost_prestige", 0)),
		"covenants": unit_cfg.get("covenants", [])
	}
	return _get_filtered_buff_effect_entries(effect_type, tags)


func _get_filtered_buff_effect_total(effect_type: StringName, tags: Dictionary) -> float:
	var total := 0.0
	for effect in _get_filtered_buff_effect_entries(effect_type, tags):
		total += float(effect.get("effect_value", 0.0))
	return total


func _get_filtered_buff_effect_entries(effect_type: StringName, tags: Dictionary) -> Array[Dictionary]:
	var data_repo = AppRefs.data_repo()
	var result: Array[Dictionary] = []
	if data_repo == null:
		return result
	for buff_id in buffs:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
		for effect in _get_buff_effect_entries(cfg):
			if StringName(effect.get("effect_type", "")) != effect_type:
				continue
			if not _buff_effect_is_active(effect):
				continue
			if not _buff_matches_tags(effect, tags):
				continue
			result.append(effect)
	return result


func _get_dynamic_unit_buff_effect_total(effect_type: StringName, tags: Dictionary) -> float:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return 0.0
	var total := 0.0
	for buff_id in buffs:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
		for effect in _get_buff_effect_entries(cfg):
			if not _buff_effect_is_active(effect):
				continue
			match StringName(effect.get("effect_type", "")):
				&"prestige_chunk_effect":
					if StringName(effect.get("target_effect_type", "")) != effect_type:
						continue
					if not _buff_matches_tags(effect, tags):
						continue
					var chunk_size: int = maxi(int(effect.get("chunk_size", 1)), 1)
					var max_layers: int = maxi(int(effect.get("max_layers", 0)), 0)
					var layers := int(floor(float(max(prestige, 0)) / float(chunk_size)))
					if max_layers > 0:
						layers = min(layers, max_layers)
					total += float(effect.get("effect_value", 0.0)) * float(max(layers, 0))
				&"formation_class_count_effect":
					if StringName(effect.get("target_effect_type", "")) != effect_type:
						continue
					if not _buff_matches_tags(effect, tags):
						continue
					var source_class := StringName(effect.get("source_class", effect.get("class_filter", "")))
					var layers: int = _count_owned_operators_by_class(source_class)
					var max_layers: int = maxi(int(effect.get("max_layers", 0)), 0)
					if max_layers > 0:
						layers = min(layers, max_layers)
					total += float(effect.get("effect_value", 0.0)) * float(max(layers, 0))
				&"formation_distinct_class_effect":
					if StringName(effect.get("target_effect_type", "")) != effect_type:
						continue
					if not _buff_matches_tags(effect, tags):
						continue
					var layers: int = _count_distinct_owned_operator_classes()
					var max_layers: int = maxi(int(effect.get("max_layers", 0)), 0)
					if max_layers > 0:
						layers = min(layers, max_layers)
					total += float(effect.get("effect_value", 0.0)) * float(max(layers, 0))
	return total


func _get_buff_effect_entries(cfg: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if cfg.has("effects") and typeof(cfg.get("effects")) == TYPE_ARRAY:
		for raw_effect in cfg.get("effects", []):
			if typeof(raw_effect) == TYPE_DICTIONARY:
				var effect := (raw_effect as Dictionary).duplicate(true)
				for key in ["class_filter", "damage_type_filter", "building_type_filter", "material_filter", "covenant_filter", "max_cost_prestige", "min_cost_prestige", "condition"]:
					if not effect.has(key) and cfg.has(key):
						effect[key] = cfg[key]
				result.append(effect)
	if result.is_empty() and cfg.has("effect_type"):
		result.append(cfg)
	return result


func _buff_matches_tags(effect: Dictionary, tags: Dictionary) -> bool:
	for key in ["class", "damage_type", "building_type", "material", "enemy_id"]:
		var filter_key := "%s_filter" % key
		if not effect.has(filter_key):
			continue
		if not _filter_matches(effect.get(filter_key), tags.get(key, "")):
			return false
	if effect.has("covenant_filter") and not _covenant_filter_matches(effect.get("covenant_filter"), tags.get("covenants", [])):
		return false
	if effect.has("max_cost_prestige") and int(tags.get("cost_prestige", 999)) > int(effect.get("max_cost_prestige", 999)):
		return false
	if effect.has("min_cost_prestige") and int(tags.get("cost_prestige", 0)) < int(effect.get("min_cost_prestige", 0)):
		return false
	return true


func _buff_effect_has_filters(effect: Dictionary) -> bool:
	for key in ["class_filter", "damage_type_filter", "building_type_filter", "material_filter", "enemy_id_filter", "covenant_filter", "max_cost_prestige", "min_cost_prestige"]:
		if effect.has(key):
			return true
	return false


## covenant_filter：效果只作用于拥有指定盟约 tag 的干员。filter 与干员 covenants 数组求交集。
func _covenant_filter_matches(raw_filter: Variant, raw_covenants: Variant) -> bool:
	var covenants: Array = raw_covenants if raw_covenants is Array else []
	var filters: Array = raw_filter if raw_filter is Array else [raw_filter]
	for raw_expected: Variant in filters:
		var expected := StringName(raw_expected)
		if expected == StringName():
			continue
		for raw_covenant: Variant in covenants:
			if StringName(raw_covenant) == expected:
				return true
	return false


func _filter_matches(raw_filter: Variant, tag_value: Variant) -> bool:
	var tag := StringName(tag_value)
	if typeof(raw_filter) == TYPE_ARRAY:
		for expected in raw_filter:
			if StringName(expected) == tag:
				return true
		return false
	var expected := StringName(raw_filter)
	return expected == StringName() or expected == tag


func _buff_effect_is_active(effect: Dictionary) -> bool:
	if not effect.has("condition"):
		return true
	var condition: Variant = effect.get("condition")
	if typeof(condition) == TYPE_ARRAY:
		for entry in condition:
			if typeof(entry) != TYPE_DICTIONARY or not _condition_matches(entry as Dictionary):
				return false
		return true
	if typeof(condition) == TYPE_DICTIONARY:
		return _condition_matches(condition as Dictionary)
	var condition_type := StringName(condition)
	if condition_type == StringName():
		return true
	return _condition_matches({"type": condition_type})


func _condition_matches(condition: Dictionary) -> bool:
	match StringName(condition.get("type", "")):
		&"core_hp_equals":
			return core_hp == int(condition.get("value", 0))
		&"core_hp_full":
			return core_hp > 0 and core_hp == core_hp_max
		&"core_hp_at_most":
			return core_hp <= int(condition.get("value", 0))
		&"core_hp_at_least":
			return core_hp >= int(condition.get("value", 0))
		_:
			return true


func _count_owned_operators_by_class(class_key: StringName) -> int:
	if class_key == StringName():
		return 0
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return 0
	var count := 0
	for operator in owned_operators:
		var operator_dict := operator as Dictionary
		var cfg: Dictionary = data_repo.get_unit_cfg(StringName(operator_dict.get("unit_id", "")))
		if StringName(cfg.get("class", "")) == class_key:
			count += 1
	return count


func _count_distinct_owned_operator_classes() -> int:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return 0
	var classes: Dictionary = {}
	for operator in owned_operators:
		var operator_dict := operator as Dictionary
		var cfg: Dictionary = data_repo.get_unit_cfg(StringName(operator_dict.get("unit_id", "")))
		var class_key := StringName(cfg.get("class", ""))
		if class_key != StringName():
			classes[class_key] = true
	return classes.size()


func _damage_type_key(damage_type: int) -> StringName:
	match damage_type:
		GameEnums.DAMAGE_MAGIC:
			return &"magic"
		GameEnums.DAMAGE_TRUE:
			return &"true"
		_:
			return &"physical"


func _emit_all_state() -> void:
	EventBus.action_points_changed.emit(action_points)
	EventBus.prestige_changed.emit(prestige)
	EventBus.materials_changed.emit(wood, stone, mana)
	EventBus.core_hp_changed.emit(core_hp, core_hp_max)
	EventBus.deploy_limit_changed.emit(deployed_count, deploy_limit)
	_emit_owned_roster()
	EventBus.buffs_changed.emit(buffs.duplicate())


func is_tutorial_run() -> bool:
	return run_mode == RUN_MODE_TUTORIAL


func mark_tutorial_completed() -> void:
	tutorial_completed = true


func _normalize_run_mode(mode: StringName) -> StringName:
	return RUN_MODE_TUTORIAL if mode == RUN_MODE_TUTORIAL else RUN_MODE_STANDARD


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
	var unit_extra := _get_unit_extra_covenants(StringName(normalized.get("unit_id", "")))
	var raw_extra: Variant = normalized.get("extra_covenants", [])
	for raw_covenant: Variant in (raw_extra if raw_extra is Array else []):
		var covenant := StringName(raw_covenant)
		if covenant != StringName() and not unit_extra.has(covenant):
			unit_extra.append(covenant)
	normalized["extra_covenants"] = unit_extra
	return normalized


func _get_unit_extra_covenants(unit_id: StringName) -> Array:
	var raw_extra: Variant = unit_extra_covenants.get(unit_id, [])
	var result: Array = []
	for raw_covenant: Variant in (raw_extra if raw_extra is Array else []):
		var covenant := StringName(raw_covenant)
		if covenant != StringName() and not result.has(covenant):
			result.append(covenant)
	return result


## 单位类型的有效盟约 = 单位配置盟约 + 本局追加盟约（祭坛灌注等），去重。
func get_unit_covenants(unit_id: StringName) -> Array:
	if unit_id == StringName():
		return []
	var data_repo = AppRefs.data_repo()
	var unit_cfg: Dictionary = data_repo.get_unit_cfg(unit_id) if data_repo != null else {}
	var covenants: Array = []
	var raw_base: Variant = unit_cfg.get("covenants", [])
	for raw_covenant: Variant in (raw_base if raw_base is Array else []):
		var covenant := StringName(raw_covenant)
		if covenant != StringName() and not covenants.has(covenant):
			covenants.append(covenant)
	for raw_covenant: Variant in _get_unit_extra_covenants(unit_id):
		var covenant := StringName(raw_covenant)
		if covenant != StringName() and not covenants.has(covenant):
			covenants.append(covenant)
	return covenants


## 干员实例的有效盟约 = 单位类型有效盟约 + 旧实例额外盟约，去重。
func get_operator_covenants(operator_key: StringName) -> Array:
	var operator := get_owned_operator(operator_key)
	if operator.is_empty():
		return []
	var covenants := get_unit_covenants(StringName(operator.get("unit_id", "")))
	for raw_covenant: Variant in (operator.get("extra_covenants", []) as Array):
		var covenant := StringName(raw_covenant)
		if covenant != StringName() and not covenants.has(covenant):
			covenants.append(covenant)
	return covenants


## 为单位类型追加本局永久盟约 tag。现有与后续同名实例都会继承。
func add_unit_covenant(unit_id: StringName, covenant: StringName) -> Dictionary:
	if covenant == StringName():
		return ActionResult.err(&"INVALID_COVENANT", "无效的盟约")
	if unit_id == StringName():
		return ActionResult.err(&"UNIT_NOT_FOUND", "无效的干员")
	var data_repo = AppRefs.data_repo()
	if data_repo == null or data_repo.get_unit_cfg(unit_id).is_empty():
		return ActionResult.err(&"UNIT_NOT_FOUND", "找不到该干员")
	if get_unit_covenants(unit_id).has(covenant):
		return ActionResult.err(&"COVENANT_EXISTS", "该干员已拥有此盟约")
	var extra := _get_unit_extra_covenants(unit_id)
	extra.append(covenant)
	unit_extra_covenants[unit_id] = extra
	_emit_owned_roster()
	return ActionResult.ok({"unit_id": unit_id, "covenant": covenant})


## 兼容旧调用：传入一个实例，实际为它的单位类型追加本局永久盟约 tag。
func add_operator_covenant(operator_key: StringName, covenant: StringName) -> Dictionary:
	var operator := get_owned_operator(operator_key)
	if operator.is_empty():
		return ActionResult.err(&"OPERATOR_NOT_OWNED", "未拥有该干员")
	var result := add_unit_covenant(StringName(operator.get("unit_id", "")), covenant)
	if result.get("ok", false):
		var payload: Dictionary = result.get("payload", {})
		payload["operator_key"] = operator_key
		result["payload"] = payload
	return result


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
