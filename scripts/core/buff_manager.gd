extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const DEFAULT_RELIC_CHOICES := 3
const MAX_RELIC_CHOICES := 5
# 三选一分槽构成：槽 A 盟约导向、槽 B 稀有度随机、槽 C 经济/通用保底。
# 盟约槽要求玩家在该盟约下拥有的不同干员数达到该值（接近/已激活 2 人档）。
const COVENANT_PRESENCE_MIN := 2
const ECONOMY_SLOT_CATEGORIES: Array[StringName] = [&"economy", &"generic"]

@onready var _unit_manager: Node = get_node_or_null("../UnitManager")
@onready var _enemy_manager: Node = get_node_or_null("../EnemyManager")
@onready var _building_manager: Node = get_node_or_null("../BuildingManager")


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	event_bus.core_damaged.connect(_on_core_damaged)
	event_bus.unit_died.connect(_on_unit_died)
	event_bus.night_cleared.connect(_on_night_cleared)
	event_bus.core_hp_changed.connect(_on_core_hp_changed)
	event_bus.unit_skill_cast.connect(_on_unit_skill_cast)


## 三选一构成：槽 A 从"接近/已激活盟约"的钥匙件中抽，槽 B 按当天稀有度门控随机，
## 槽 C 经济/通用保底；不足时从槽 B 池补齐。稀有度门控：第 1-2 天仅普通(1)，
## 第 3-4 天普通+稀有(1,2)，第 5 天起稀有+传说(2,3)；门控池不足时回退全池。
func get_random_blessing_choices(count: int = 0) -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in get_random_blessing_choices_with_sources(count):
		ids.append(StringName(entry.get("buff_id", "")))
	return ids


## 同 get_random_blessing_choices，但每个条目带槽位来源，供 UI 标注"盟约导向/经济/随机"。
## 返回：Array[{buff_id: StringName, slot: StringName}]，buff_id 与 slot 始终对齐（打乱时同步）。
## slot 取值：covenant（盟约导向槽）/ economy（经济槽）/ random（稀有度随机/保底槽）。
func get_random_blessing_choices_with_sources(count: int = 0) -> Array[Dictionary]:
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	if data_repo == null:
		return []
	var choice_count := count
	if choice_count <= 0:
		choice_count = DEFAULT_RELIC_CHOICES
	choice_count = clamp(choice_count, 1, MAX_RELIC_CHOICES)

	var unowned: Array[Dictionary] = []
	var all_buff_ids: Array[StringName] = data_repo.get_all_buff_ids()
	for buff_id in all_buff_ids:
		if run_state != null and run_state.has_buff(buff_id):
			continue
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
		if cfg.is_empty():
			continue
		cfg["id"] = buff_id
		unowned.append(cfg)

	var day: int = int(run_state.day) if run_state != null else 1
	var allowed_rarities := _allowed_rarities_for_day(day)
	var presence := _covenant_presence()
	# 未持有（不同干员数 < 2）盟约的钥匙件是死卡，整体不进入抽取池。
	var rarity_pool: Array[Dictionary] = []
	for cfg in unowned:
		if not allowed_rarities.has(int(cfg.get("rarity", 1))):
			continue
		if StringName(cfg.get("category", "")) == &"covenant" \
				and int(presence.get(StringName(cfg.get("covenant", "")), 0)) < COVENANT_PRESENCE_MIN:
			continue
		rarity_pool.append(cfg)
	if rarity_pool.is_empty():
		rarity_pool = unowned

	var economy_pool: Array[Dictionary] = []
	for cfg in rarity_pool:
		if ECONOMY_SLOT_CATEGORIES.has(StringName(cfg.get("category", "generic"))):
			economy_pool.append(cfg)

	var covenant_pool: Array[Dictionary] = []
	for cfg in rarity_pool:
		if StringName(cfg.get("category", "")) == &"covenant":
			covenant_pool.append(cfg)

	# entries 保持 (buff_id, slot) 配对；后续打乱以条目为单位，绝不丢来源对应关系。
	var entries: Array[Dictionary] = []
	var picked_ids: Array[StringName] = []
	# 保底（打完 3/6 幕末 Boss）：随机槽改抽一件高稀有度件，无视当天稀有度门控。
	var random_pool: Array[Dictionary] = rarity_pool
	if run_state != null and bool(run_state.get("pending_milestone_blessing")):
		run_state.pending_milestone_blessing = false
		var top: Array[Dictionary] = []
		for cfg in unowned:
			if int(cfg.get("rarity", 1)) == 3 and StringName(cfg.get("category", "")) != &"covenant":
				top.append(cfg)
		if top.is_empty():
			for cfg in unowned:
				if int(cfg.get("rarity", 1)) == 2 and StringName(cfg.get("category", "")) != &"covenant":
					top.append(cfg)
		if not top.is_empty():
			random_pool = top
	_append_sourced_choice(covenant_pool, picked_ids, entries, &"covenant")
	_append_sourced_choice(random_pool, picked_ids, entries, &"random")
	if choice_count >= 3:
		_append_sourced_choice(economy_pool, picked_ids, entries, &"economy")
	while entries.size() < choice_count:
		if not _append_sourced_choice(rarity_pool, picked_ids, entries, &"random") \
				and not _append_sourced_choice(unowned, picked_ids, entries, &"random"):
			break
	entries.shuffle()
	return entries


func _allowed_rarities_for_day(day: int) -> Array[int]:
	# 三幕分档（369）：第一幕(1-3)普通、第二幕(4-6)加稀有、第三幕(7-9)稀有+传说。
	if day <= 3:
		return [1]
	if day <= 6:
		return [1, 2]
	return [2, 3]


## 玩家在各盟约下拥有的不同干员数（同名干员去重，与盟约触发人数口径一致）。
func _covenant_presence() -> Dictionary:
	var presence: Dictionary = {}
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null or not run_state.has_method("get_owned_operators"):
		return presence
	var counted_units_by_covenant: Dictionary = {}
	for operator in run_state.get_owned_operators():
		var operator_dict := operator as Dictionary
		var unit_id := StringName(operator_dict.get("unit_id", ""))
		if unit_id == StringName():
			continue
		var covenants: Array = run_state.get_operator_covenants(StringName(operator_dict.get("key", ""))) \
				if run_state.has_method("get_operator_covenants") else data_repo.get_unit_cfg(unit_id).get("covenants", [])
		for raw_covenant: Variant in covenants:
			var covenant := StringName(raw_covenant)
			if covenant == StringName():
				continue
			if not counted_units_by_covenant.has(covenant):
				counted_units_by_covenant[covenant] = {}
			var counted: Dictionary = counted_units_by_covenant[covenant]
			if counted.has(unit_id):
				continue
			counted[unit_id] = true
			presence[covenant] = int(presence.get(covenant, 0)) + 1
	return presence


func _append_random_choice(pool: Array[Dictionary], result: Array[StringName]) -> bool:
	var candidates: Array[StringName] = []
	for cfg in pool:
		var buff_id := StringName(cfg.get("id", ""))
		if buff_id != StringName() and not result.has(buff_id):
			candidates.append(buff_id)
	if candidates.is_empty():
		return false
	result.append(candidates.pick_random())
	return true


## 从 pool 抽一张未重复的牌，记录其槽位来源 slot；picked_ids 用于去重，entries 收 (buff_id, slot)。
func _append_sourced_choice(pool: Array[Dictionary], picked_ids: Array[StringName], entries: Array[Dictionary], slot: StringName) -> bool:
	var candidates: Array[StringName] = []
	for cfg in pool:
		var buff_id := StringName(cfg.get("id", ""))
		if buff_id != StringName() and not picked_ids.has(buff_id):
			candidates.append(buff_id)
	if candidates.is_empty():
		return false
	var picked: StringName = candidates.pick_random()
	picked_ids.append(picked)
	entries.append({"buff_id": picked, "slot": slot})
	return true


func apply_blessing(buff_id: StringName) -> Dictionary:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null:
		return ActionResult.err(&"APP_REFS_MISSING", "全局单例尚未初始化")
	if run_state.buffs.has(buff_id):
		return ActionResult.err(&"BUFF_EXISTS", "该遗物已经拥有")
	var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
	if cfg.is_empty():
		return ActionResult.err(&"BUFF_NOT_FOUND", "找不到该遗物配置")
	run_state.add_buff(buff_id)
	for effect in _get_effect_entries(cfg):
		match String(effect.get("effect_type", "")):
			"prestige_add":
				run_state.add_prestige(int(effect.get("effect_value", 0)))
			"deploy_limit_add":
				run_state.set_deploy_limit(run_state.deploy_limit + int(effect.get("effect_value", 0)))
			"core_heal":
				run_state.heal_core(int(effect.get("effect_value", 0)))
			"core_heal_full":
				if run_state.has_method("heal_core_full"):
					run_state.heal_core_full()
			"core_max_hp_add":
				var value := int(effect.get("effect_value", 0))
				run_state.core_hp_max += value
				run_state.heal_core(value)
			"core_hp_set_to_one":
				if run_state.has_method("set_core_hp_to_one"):
					run_state.set_core_hp_to_one()
			"core_max_hp_set_to_one":
				if run_state.has_method("set_core_max_hp_to_one"):
					run_state.set_core_max_hp_to_one()
	_refresh_relic_runtime_effects()
	return ActionResult.ok({"buff_id": buff_id}, "已获得遗物：%s" % String(cfg.get("name", buff_id)))


func has_buff(buff_id: StringName) -> bool:
	var run_state = AppRefs.run_state()
	return run_state != null and run_state.buffs.has(buff_id)


func get_all_buffs() -> Array[StringName]:
	var run_state = AppRefs.run_state()
	return run_state.buffs.duplicate() if run_state != null else []


func _draw_random_choices(pool: Array[StringName], count: int) -> Array[StringName]:
	var remaining := pool.duplicate()
	var result: Array[StringName] = []
	while result.size() < count and not remaining.is_empty():
		var picked: StringName = remaining.pick_random()
		if picked == StringName():
			break
		result.append(picked)
		remaining.erase(picked)
	return result


func _get_effect_entries(cfg: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if cfg.has("effects") and typeof(cfg.get("effects")) == TYPE_ARRAY:
		for raw_effect in cfg.get("effects", []):
			if typeof(raw_effect) == TYPE_DICTIONARY:
				var effect := (raw_effect as Dictionary).duplicate(true)
				for key in ["class_filter", "damage_type_filter", "building_type_filter", "material_filter", "covenant_filter", "condition"]:
					if not effect.has(key) and cfg.has(key):
						effect[key] = cfg[key]
				result.append(effect)
	if result.is_empty() and cfg.has("effect_type"):
		result.append(cfg)
	return result


func _get_owned_effect_entries(effect_type: StringName) -> Array[Dictionary]:
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	var result: Array[Dictionary] = []
	if data_repo == null or run_state == null:
		return result
	for buff_id in run_state.get_all_buffs():
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
		for effect in _get_effect_entries(cfg):
			if StringName(effect.get("effect_type", "")) == effect_type:
				result.append(effect)
	return result


func _on_core_damaged(_amount: int, current: int, _max_value: int) -> void:
	if current <= 0:
		return
	for effect in _get_owned_effect_entries(&"core_breach_redeploy_ready_random"):
		if _unit_manager != null and _unit_manager.has_method("ready_random_redeploying_operator"):
			_unit_manager.ready_random_redeploying_operator()
	for effect in _get_owned_effect_entries(&"core_breach_stun_all_enemies"):
		var duration := float(effect.get("effect_value", 0.0))
		if duration > 0.0 and _enemy_manager != null and _enemy_manager.has_method("stun_all_enemies"):
			_enemy_manager.stun_all_enemies(duration)
	_refresh_relic_runtime_effects()


func _on_unit_died(_unit_runtime_id: int, unit_id: StringName, cell: Vector2i) -> void:
	var data_repo = AppRefs.data_repo()
	var unit_cfg: Dictionary = data_repo.get_unit_cfg(unit_id) if data_repo != null else {}
	for effect in _get_owned_effect_entries(&"unit_death_stun_radius"):
		if not _effect_matches_unit_covenants(effect, unit_cfg):
			continue
		var duration := float(effect.get("effect_value", 0.0))
		var radius := int(effect.get("radius", 0))
		if duration > 0.0 and radius > 0 and _enemy_manager != null and _enemy_manager.has_method("stun_enemies_in_radius"):
			_enemy_manager.stun_enemies_in_radius(cell, radius, duration)


func _on_unit_skill_cast(_unit_runtime_id: int, _unit_id: StringName) -> void:
	var sp_total := 0
	for effect in _get_owned_effect_entries(&"unit_sp_on_skill_cast_team"):
		sp_total += int(effect.get("effect_value", 0))
	if sp_total <= 0 or _unit_manager == null or not _unit_manager.has_method("get_all_deployed_units"):
		return
	for unit in _unit_manager.get_all_deployed_units():
		if unit != null and is_instance_valid(unit) and unit.has_method("gain_sp"):
			unit.gain_sp(sp_total)


func _effect_matches_unit_covenants(effect: Dictionary, unit_cfg: Dictionary) -> bool:
	if not effect.has("covenant_filter"):
		return true
	var raw_filter: Variant = effect.get("covenant_filter")
	var filters: Array = raw_filter if raw_filter is Array else [raw_filter]
	var raw_covenants: Variant = unit_cfg.get("covenants", [])
	var covenants: Array = raw_covenants if raw_covenants is Array else []
	for raw_expected: Variant in filters:
		var expected := StringName(raw_expected)
		if expected == StringName():
			continue
		for raw_covenant: Variant in covenants:
			if StringName(raw_covenant) == expected:
				return true
	return false


func _on_night_cleared(_day: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	for effect in _get_owned_effect_entries(&"core_heal_night_end"):
		run_state.heal_core(int(effect.get("effect_value", 0)))
	_refresh_relic_runtime_effects()


func _on_core_hp_changed(_current: int, _max_value: int) -> void:
	_refresh_relic_runtime_effects()


func _refresh_relic_runtime_effects() -> void:
	if _unit_manager != null and _unit_manager.has_method("refresh_relic_effects_on_deployed_units"):
		_unit_manager.refresh_relic_effects_on_deployed_units()
	if _building_manager != null and _building_manager.has_method("refresh_relic_effects_on_buildings"):
		_building_manager.refresh_relic_effects_on_buildings()
