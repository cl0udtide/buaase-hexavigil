extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const CovenantDefs = preload("res://scripts/combat/covenant_defs.gd")

# --- 每日事件刷新 ---
# 开局保底 2 个事件点，此后每天 1-2 个；囤而不触发的活跃上限 4 个。
const DAY_ONE_EVENT_SPAWNS := 2
const DAILY_EVENT_SPAWN_MIN := 1
const DAILY_EVENT_SPAWN_MAX := 2
const MAX_ACTIVE_EVENT_POINTS := 4
# 落点优先级：探索前沿的迷雾（距已探索区 ≤4 格）> 任意迷雾 > 已探索空地。
const FRONTIER_RADIUS := 4
const CORE_SAFE_RADIUS := 4
const SPAWN_SAFE_RADIUS := 2

# --- 祭坛事件 ---
const ALTAR_EVENT_ID: StringName = &"event_altar"
const ALTAR_OFFER_COUNT := 3
const ALTAR_MANA_COST := 2

@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _buff_manager: Node = get_node_or_null("../BuffManager")

var _events_by_cell: Dictionary = {}
var _spawned_event_ids: Dictionary = {}
var _altar_offers_by_cell: Dictionary = {}


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.day_started.connect(_on_day_started)


func _on_day_started(day: int) -> void:
	_spawn_daily_events(day)


func setup_events(event_points: Array) -> void:
	_events_by_cell.clear()
	_spawned_event_ids.clear()
	_altar_offers_by_cell.clear()
	for raw_point: Variant in event_points:
		if typeof(raw_point) != TYPE_DICTIONARY:
			continue
		var point: Dictionary = raw_point
		var cell := _parse_cell(point.get("cell", Vector2i(-1, -1)))
		var event_id := StringName(point.get("event_id", ""))
		if cell.x < 0 or cell.y < 0 or event_id == StringName():
			continue
		_events_by_cell[cell] = event_id
	_refresh_map()


func clear_events() -> void:
	_events_by_cell.clear()
	_spawned_event_ids.clear()
	_altar_offers_by_cell.clear()
	_refresh_map()


func get_event_id_at_cell(cell: Vector2i) -> StringName:
	return StringName(_events_by_cell.get(cell, StringName()))


func has_event_at_cell(cell: Vector2i) -> bool:
	return get_event_id_at_cell(cell) != StringName()


func get_event_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for raw_cell in _events_by_cell.keys():
		cells.append(raw_cell as Vector2i)
	return cells


func mark_event_triggered(cell: Vector2i) -> void:
	_events_by_cell.erase(cell)
	_altar_offers_by_cell.erase(cell)
	_refresh_map()


func get_event_cfg_at_cell(cell: Vector2i) -> Dictionary:
	var event_id := get_event_id_at_cell(cell)
	if event_id == StringName():
		return {}
	var cfg := get_event_cfg(event_id)
	if event_id == ALTAR_EVENT_ID:
		cfg["choices"] = _build_altar_choices(cell)
	return cfg


func roll_event_for_cell(cell: Vector2i) -> StringName:
	return get_event_id_at_cell(cell)


func apply_event(event_id: StringName) -> Dictionary:
	var run_state = AppRefs.run_state()
	var cfg := get_event_cfg(event_id)
	if cfg.is_empty():
		return ActionResult.err(&"EVENT_NOT_FOUND", "找不到事件配置")
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState 尚未初始化")
	var requires_result := _check_requirements(cfg, run_state)
	if not requires_result.get("ok", false):
		return requires_result
	var payload: Dictionary = cfg.get("payload", {})
	var effect_payload := payload.duplicate(true)
	run_state.add_materials(int(payload.get("wood", 0)), int(payload.get("stone", 0)), int(payload.get("mana", 0)))
	run_state.add_prestige(int(payload.get("prestige", 0)))
	var summary_lines := _apply_contract_effects(cfg, run_state)
	if not summary_lines.is_empty():
		effect_payload["summary"] = "\n".join(summary_lines)
	return ActionResult.ok({
		"event_id": event_id,
		"effect_type": StringName(cfg.get("effect_type", "")),
		"effect_payload": effect_payload,
	})


## 事件前置消耗校验：不足时整个事件不生效（行动力由 day_manager 退还）。
func _check_requirements(cfg: Dictionary, run_state: Node) -> Dictionary:
	var requires: Dictionary = cfg.get("requires", {})
	if requires.is_empty():
		return ActionResult.ok()
	if int(requires.get("prestige", 0)) > int(run_state.prestige):
		return ActionResult.err(&"NOT_ENOUGH_PRESTIGE", "声望不足，交易取消")
	if int(requires.get("wood", 0)) > int(run_state.wood) \
			or int(requires.get("stone", 0)) > int(run_state.stone) \
			or int(requires.get("mana", 0)) > int(run_state.mana):
		return ActionResult.err(&"NOT_ENOUGH_MATERIALS", "材料不足，交易取消")
	return ActionResult.ok()


## 契约类效果：核心上限增减、随机遗物、追加夜晚词缀、不漏怪赌约。
func _apply_contract_effects(cfg: Dictionary, run_state: Node) -> PackedStringArray:
	var summary_lines := PackedStringArray()
	for raw_effect: Variant in cfg.get("effects", []):
		if typeof(raw_effect) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = raw_effect
		match StringName(effect.get("type", "")):
			&"core_max_hp_add":
				var delta := int(effect.get("value", 0))
				if run_state.has_method("add_core_max_hp"):
					run_state.add_core_max_hp(delta)
					summary_lines.append("核心生命上限 %+d" % delta)
			&"grant_random_relic":
				var granted := _grant_random_relic(int(effect.get("rarity_min", 1)), int(effect.get("rarity_max", 3)))
				if granted != StringName():
					var data_repo = AppRefs.data_repo()
					var relic_cfg: Dictionary = data_repo.get_buff_cfg(granted) if data_repo != null else {}
					summary_lines.append("获得遗物：%s" % String(relic_cfg.get("name", granted)))
				else:
					run_state.add_prestige(6)
					summary_lines.append("遗物已搜罗一空，改为获得 6 声望")
			&"night_affix_add_random":
				var affix_id := _add_random_night_affix(run_state)
				if affix_id != StringName():
					var data_repo = AppRefs.data_repo()
					var affix_cfg: Dictionary = data_repo.get_night_affix_cfg(affix_id) if data_repo != null else {}
					summary_lines.append("今晚追加词缀：%s" % String(affix_cfg.get("name", affix_id)))
			&"wager_no_leak":
				run_state.night_wager_active = true
				summary_lines.append("赌约生效：若核心一夜未失血，明早额外进行一次遗物三选一")
			&"grant_random_operator":
				var granted_unit := _grant_random_operator(run_state, int(effect.get("unit_cost", 0)))
				if granted_unit != StringName():
					var data_repo = AppRefs.data_repo()
					var unit_cfg: Dictionary = data_repo.get_unit_cfg(granted_unit) if data_repo != null else {}
					summary_lines.append("获得干员：%s" % String(unit_cfg.get("name", granted_unit)))
				else:
					run_state.add_prestige(3)
					summary_lines.append("营地空无一人，改为获得 3 声望")
			&"night_affix_add":
				var fixed_affix := StringName(effect.get("affix_id", ""))
				if fixed_affix != StringName() and not (run_state.night_affix_ids as Array).has(fixed_affix):
					run_state.night_affix_ids.append(fixed_affix)
					var data_repo = AppRefs.data_repo()
					var affix_cfg: Dictionary = data_repo.get_night_affix_cfg(fixed_affix) if data_repo != null else {}
					summary_lines.append("今晚追加词缀：%s" % String(affix_cfg.get("name", fixed_affix)))
			_:
				pass
	return summary_lines


func _grant_random_relic(rarity_min: int, rarity_max: int) -> StringName:
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	if data_repo == null or run_state == null or _buff_manager == null or not _buff_manager.has_method("apply_blessing"):
		return StringName()
	var candidates: Array[StringName] = []
	for buff_id in data_repo.get_all_buff_ids():
		if run_state.has_buff(buff_id):
			continue
		var rarity := int(data_repo.get_buff_cfg(buff_id).get("rarity", 1))
		if rarity >= rarity_min and rarity <= rarity_max:
			candidates.append(buff_id)
	if candidates.is_empty():
		return StringName()
	var picked: StringName = candidates.pick_random()
	var result: Dictionary = _buff_manager.apply_blessing(picked)
	return picked if result.get("ok", false) else StringName()


func _add_random_night_affix(run_state: Node) -> StringName:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or not data_repo.has_method("get_all_night_affix_ids"):
		return StringName()
	var day := int(run_state.day)
	var gated: Array[StringName] = []
	var fallback: Array[StringName] = []
	for affix_id in data_repo.get_all_night_affix_ids():
		if (run_state.night_affix_ids as Array).has(affix_id):
			continue
		fallback.append(affix_id)
		if int(data_repo.get_night_affix_cfg(affix_id).get("min_day", 1)) <= day:
			gated.append(affix_id)
	var pool := gated if not gated.is_empty() else fallback
	if pool.is_empty():
		return StringName()
	var picked: StringName = pool.pick_random()
	run_state.night_affix_ids.append(picked)
	return picked


func apply_event_for_cell(cell: Vector2i, choice_id: StringName = StringName()) -> Dictionary:
	var event_id := roll_event_for_cell(cell)
	if event_id == StringName():
		return ActionResult.err(&"NO_EVENT", "该格子没有可触发事件")
	if event_id == ALTAR_EVENT_ID and String(choice_id).begins_with("infuse_"):
		return _apply_altar_infusion(cell, choice_id)
	var triggered_event_id := event_id
	if choice_id != StringName():
		var choice_result := _resolve_choice_event_id(event_id, choice_id)
		if not choice_result.get("ok", false):
			return choice_result
		triggered_event_id = StringName(choice_result.get("payload", {}).get("event_id", event_id))
	var result := apply_event(triggered_event_id)
	if result.get("ok", false):
		var payload: Dictionary = result.get("payload", {})
		payload["source_event_id"] = event_id
		if choice_id != StringName():
			payload["choice_id"] = choice_id
		result["payload"] = payload
		mark_event_triggered(cell)
		var event_bus = AppRefs.event_bus()
		if event_bus != null:
			event_bus.random_event_triggered.emit(triggered_event_id, cell)
	return result


func get_event_cfg(event_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_event_cfg(event_id) if data_repo != null else {}


func _refresh_map() -> void:
	if _map_manager != null and _map_manager.has_method("refresh_all_layers"):
		_map_manager.refresh_all_layers()


func _parse_cell(raw_cell: Variant) -> Vector2i:
	if raw_cell is Vector2i:
		return raw_cell
	if raw_cell is Array and raw_cell.size() >= 2:
		return Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	if raw_cell is Dictionary:
		return Vector2i(int(raw_cell.get("x", -1)), int(raw_cell.get("y", -1)))
	return Vector2i(-1, -1)


func _resolve_choice_event_id(event_id: StringName, choice_id: StringName) -> Dictionary:
	var cfg := get_event_cfg(event_id)
	if cfg.is_empty():
		return ActionResult.err(&"EVENT_NOT_FOUND", "找不到事件配置")
	var raw_choices: Variant = cfg.get("choices", [])
	if typeof(raw_choices) != TYPE_ARRAY:
		return ActionResult.err(&"CHOICE_NOT_FOUND", "该事件没有可选分支")
	for raw_choice in raw_choices:
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue
		var choice := raw_choice as Dictionary
		if StringName(choice.get("id", "")) != choice_id:
			continue
		var target_event_id := StringName(choice.get("event_id", choice.get("trigger_event_id", event_id)))
		if target_event_id == StringName():
			target_event_id = event_id
		return ActionResult.ok({"event_id": target_event_id})
	return ActionResult.err(&"CHOICE_NOT_FOUND", "找不到事件选项")


# ---------------------------------------------------------------------------
# 每日事件刷新
# ---------------------------------------------------------------------------
func _spawn_daily_events(day: int) -> void:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null or _map_manager == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("events|%d|%d" % [int(run_state.random_seed), day]).hash())
	var spawn_count := DAY_ONE_EVENT_SPAWNS if day <= 1 else rng.randi_range(DAILY_EVENT_SPAWN_MIN, DAILY_EVENT_SPAWN_MAX)
	var spawned := false
	for _index in range(spawn_count):
		if _events_by_cell.size() >= MAX_ACTIVE_EVENT_POINTS:
			break
		var cell := _pick_event_spawn_cell(rng)
		if cell.x < 0:
			break
		var event_id := _pick_event_for_day(day, rng)
		if event_id == StringName():
			break
		_events_by_cell[cell] = event_id
		_spawned_event_ids[event_id] = true
		spawned = true
	if spawned:
		_refresh_map()


## 候选落点分级：探索前沿迷雾 > 任意迷雾 > 已探索空地；均需远离核心与刷怪点。
func _pick_event_spawn_cell(rng: RandomNumberGenerator) -> Vector2i:
	var width: int = int(_map_manager.width)
	var height: int = int(_map_manager.height)
	var core_cell: Vector2i = _map_manager.get_core_cell() if _map_manager.has_method("get_core_cell") else Vector2i(-99, -99)
	var spawn_cells: Array = _map_manager.get_spawn_cells() if _map_manager.has_method("get_spawn_cells") else []
	var frontier: Array[Vector2i] = []
	var fog: Array[Vector2i] = []
	var discovered: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell := Vector2i(x, y)
			if _events_by_cell.has(cell):
				continue
			if not _is_valid_event_cell(cell, core_cell, spawn_cells):
				continue
			if _map_manager.is_discovered(cell):
				discovered.append(cell)
			elif _is_near_discovered(cell):
				frontier.append(cell)
			else:
				fog.append(cell)
	var pool: Array[Vector2i] = frontier if not frontier.is_empty() else (fog if not fog.is_empty() else discovered)
	if pool.is_empty():
		return Vector2i(-1, -1)
	return pool[rng.randi() % pool.size()]


func _is_valid_event_cell(cell: Vector2i, core_cell: Vector2i, spawn_cells: Array) -> bool:
	var data = _map_manager.get_cell_data(cell) if _map_manager.has_method("get_cell_data") else null
	if data == null or not data.walkable or data.is_core:
		return false
	if StringName(data.resource_type) != StringName() or StringName(data.spawn_key) != StringName():
		return false
	if max(absi(cell.x - core_cell.x), absi(cell.y - core_cell.y)) <= CORE_SAFE_RADIUS:
		return false
	for raw_spawn: Variant in spawn_cells:
		var spawn_cell := raw_spawn as Vector2i
		if max(absi(cell.x - spawn_cell.x), absi(cell.y - spawn_cell.y)) <= SPAWN_SAFE_RADIUS:
			return false
	return true


func _is_near_discovered(cell: Vector2i) -> bool:
	for dy in range(-FRONTIER_RADIUS, FRONTIER_RADIUS + 1):
		for dx in range(-FRONTIER_RADIUS, FRONTIER_RADIUS + 1):
			if dx == 0 and dy == 0:
				continue
			if _map_manager.is_discovered(cell + Vector2i(dx, dy)):
				return true
	return false


## 按 min_day/max_day 门控 + weight 加权抽事件；优先抽本局没刷过的。
func _pick_event_for_day(day: int, rng: RandomNumberGenerator) -> StringName:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return StringName()
	var fresh: Array[Dictionary] = []
	var all_valid: Array[Dictionary] = []
	for event_id in data_repo.get_all_event_ids():
		var cfg: Dictionary = data_repo.get_event_cfg(event_id)
		if day < int(cfg.get("min_day", 1)) or day > int(cfg.get("max_day", 99)):
			continue
		if float(cfg.get("weight", 1.0)) <= 0.0:
			continue
		cfg["id"] = event_id
		all_valid.append(cfg)
		if not _spawned_event_ids.has(event_id):
			fresh.append(cfg)
	var pool := fresh if not fresh.is_empty() else all_valid
	if pool.is_empty():
		return StringName()
	var total_weight := 0.0
	for cfg in pool:
		total_weight += float(cfg.get("weight", 1.0))
	var roll := rng.randf() * total_weight
	var cursor := 0.0
	for cfg in pool:
		cursor += float(cfg.get("weight", 1.0))
		if roll <= cursor:
			return StringName(cfg.get("id", ""))
	return StringName((pool.back() as Dictionary).get("id", ""))


# ---------------------------------------------------------------------------
# 古代祭坛：为干员实例灌注盟约 tag（动态三选一 + 离开）
# ---------------------------------------------------------------------------
func _build_altar_choices(cell: Vector2i) -> Array:
	var choices: Array = []
	for offer_variant: Variant in _ensure_altar_offers(cell):
		var offer: Dictionary = offer_variant
		choices.append({
			"id": String(offer.get("choice_id", "")),
			"text": "灌注「%s」→ %s" % [String(offer.get("covenant", "")), String(offer.get("operator_name", ""))],
			"kind": "primary",
			"event_id": "event_altar_infused",
			"effect_desc": "消耗 %d 魔力矿，%s 永久获得「%s」盟约。" % [ALTAR_MANA_COST, String(offer.get("operator_name", "")), String(offer.get("covenant", ""))],
		})
	choices.append({
		"id": "leave",
		"text": "离开祭坛",
		"kind": "secondary",
		"event_id": "event_altar_leave",
		"effect_desc": "不进行灌注。",
	})
	return choices


## 生成最多 3 个（干员, 盟约）灌注组合：偏向玩家已有人数的盟约，帮助凑触发档位。
func _ensure_altar_offers(cell: Vector2i) -> Array:
	if _altar_offers_by_cell.has(cell):
		return _altar_offers_by_cell[cell]
	var offers: Array = []
	var run_state = AppRefs.run_state()
	if run_state == null or not run_state.has_method("get_owned_operators"):
		_altar_offers_by_cell[cell] = offers
		return offers
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("altar|%d|%d|%s" % [int(run_state.random_seed), int(run_state.day), str(cell)]).hash())

	var presence: Dictionary = {}
	var operators: Array = run_state.get_owned_operators()
	for operator_variant: Variant in operators:
		for raw_covenant: Variant in run_state.get_operator_covenants(StringName((operator_variant as Dictionary).get("key", ""))):
			var covenant := StringName(raw_covenant)
			presence[covenant] = int(presence.get(covenant, 0)) + 1

	var candidates: Array[Dictionary] = []
	for operator_variant: Variant in operators:
		var operator: Dictionary = operator_variant
		var operator_key := StringName(operator.get("key", ""))
		var current: Array = run_state.get_operator_covenants(operator_key)
		for covenant_id in CovenantDefs.ORDER:
			if current.has(covenant_id):
				continue
			candidates.append({
				"operator_key": operator_key,
				"operator_name": String(operator.get("name", operator_key)),
				"covenant": covenant_id,
				"weight": 1.0 + 2.0 * float(int(presence.get(covenant_id, 0))),
			})
	while offers.size() < ALTAR_OFFER_COUNT and not candidates.is_empty():
		var total_weight := 0.0
		for candidate in candidates:
			total_weight += float(candidate.get("weight", 1.0))
		var roll := rng.randf() * total_weight
		var cursor := 0.0
		var picked_index := candidates.size() - 1
		for index in range(candidates.size()):
			cursor += float(candidates[index].get("weight", 1.0))
			if roll <= cursor:
				picked_index = index
				break
		var picked: Dictionary = candidates[picked_index]
		picked["choice_id"] = "infuse_%d" % offers.size()
		offers.append(picked)
		candidates.remove_at(picked_index)
	_altar_offers_by_cell[cell] = offers
	return offers


func _apply_altar_infusion(cell: Vector2i, choice_id: StringName) -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState 尚未初始化")
	var offer: Dictionary = {}
	for offer_variant: Variant in _ensure_altar_offers(cell):
		if StringName((offer_variant as Dictionary).get("choice_id", "")) == choice_id:
			offer = offer_variant
			break
	if offer.is_empty():
		return ActionResult.err(&"CHOICE_NOT_FOUND", "找不到灌注选项")
	var spend_result: Dictionary = run_state.spend_materials(0, 0, ALTAR_MANA_COST)
	if not spend_result.get("ok", false):
		return ActionResult.err(&"NOT_ENOUGH_MATERIALS", "魔力矿不足，灌注取消")
	var covenant := StringName(offer.get("covenant", ""))
	var operator_key := StringName(offer.get("operator_key", ""))
	var infuse_result: Dictionary = run_state.add_operator_covenant(operator_key, covenant)
	if not infuse_result.get("ok", false):
		run_state.add_materials(0, 0, ALTAR_MANA_COST)
		return infuse_result
	mark_event_triggered(cell)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.random_event_triggered.emit(&"event_altar_infused", cell)
	return ActionResult.ok({
		"event_id": &"event_altar_infused",
		"source_event_id": ALTAR_EVENT_ID,
		"choice_id": choice_id,
		"effect_type": &"contract",
		"effect_payload": {
			"mana": -ALTAR_MANA_COST,
			"summary": "%s 获得「%s」盟约" % [String(offer.get("operator_name", "")), String(covenant)],
		},
	})


func _grant_random_operator(run_state: Node, unit_cost: int) -> StringName:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or unit_cost <= 0 or not run_state.has_method("add_owned_operator"):
		return StringName()
	var candidates: Array[StringName] = []
	for unit_id in data_repo.get_all_unit_ids():
		if int(data_repo.get_unit_cfg(unit_id).get("cost_prestige", -1)) == unit_cost:
			candidates.append(unit_id)
	if candidates.is_empty():
		return StringName()
	var picked: StringName = candidates.pick_random()
	var added: Dictionary = run_state.add_owned_operator(picked)
	return picked if not added.is_empty() else StringName()
