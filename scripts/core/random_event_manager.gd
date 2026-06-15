extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const CovenantDefs = preload("res://scripts/combat/covenant_defs.gd")
const NightTemplateResolver = preload("res://scripts/enemy/night_template_resolver.gd")

# --- 开局事件铺设 ---
# 开局（第 1 天）一次性把所有设计好的母事件各投放一个，落点为全图随机合法平地。
const CORE_SAFE_RADIUS := 4          # 事件不落在核心安全区（切比雪夫 ≤4）内
const SPAWN_SAFE_RADIUS := 2         # 事件远离出怪口

# --- 祭坛事件 ---
const ALTAR_EVENT_ID: StringName = &"event_altar"
const ALTAR_OFFER_COUNT := 3
const ALTAR_MANA_COST := 2
const ALTAR_MEME_TEXTS := ["灌注塔菲喵", "灌注塔菲谢谢喵", "这祭坛应该是唐朝的"]

# --- 塌方契约事件 ---
const LANDSLIDE_EVENT_ID: StringName = &"event_landslide_contract"
const LANDSLIDE_MANA_COST := 3

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
	# 本局事件在第 1 天一次性铺好，之后不再刷新（常驻事件留在图上）。
	if day == 1:
		_spawn_run_events()


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


## 当前地图上未触发的活跃事件点数量（供 HUD 显示 X/上限）。
func get_active_event_count() -> int:
	return _events_by_cell.size()


## 本局事件总数（= 所有母事件数；供 HUD 与测试参考）。
func get_max_active_event_points() -> int:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_all_event_ids().size() if data_repo != null and data_repo.has_method("get_all_event_ids") else 0


func mark_event_triggered(cell: Vector2i) -> void:
	# 常驻事件（如奸商）触发后保留在地图上，可反复使用。
	if _is_persistent_event(get_event_id_at_cell(cell)):
		return
	_events_by_cell.erase(cell)
	_altar_offers_by_cell.erase(cell)
	_refresh_map()


func _is_persistent_event(event_id: StringName) -> bool:
	if event_id == StringName():
		return false
	return bool(get_event_cfg(event_id).get("persistent", false))


func get_event_cfg_at_cell(cell: Vector2i) -> Dictionary:
	var event_id := get_event_id_at_cell(cell)
	if event_id == StringName():
		return {}
	var cfg := get_event_cfg(event_id)
	if event_id == ALTAR_EVENT_ID:
		cfg["choices"] = _build_altar_choices(cell)
	elif event_id == LANDSLIDE_EVENT_ID:
		cfg["choices"] = _build_landslide_choices()
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


## UI 预检：给定事件选项，返回它指向子事件的 requires 满足情况与缺口明细。
## 不修改任何状态，供 event_panel 在建按钮时禁用 + 提示"还需 X"。
## 返回：{ ok: bool, requires: Dictionary, shortfalls: Array[{key,label,need,have,missing}], reason: String }
func preview_choice_requirements(event_id: StringName, choice_id: StringName) -> Dictionary:
	var requires := _requires_for_choice(event_id, choice_id)
	return preview_requirements(requires)


## 把一份 requires 与 RunState 当前资源比对，列出缺口。requires 为空时恒满足。
func preview_requirements(requires: Dictionary) -> Dictionary:
	var result := {"ok": true, "requires": requires, "shortfalls": [], "reason": ""}
	if requires == null or requires.is_empty():
		return result
	var run_state = AppRefs.run_state()
	if run_state == null:
		return result
	var checks := [
		{"key": "prestige", "label": "声望", "have": int(run_state.prestige)},
		{"key": "mana", "label": "魔力矿", "have": int(run_state.mana)},
		{"key": "wood", "label": "木材", "have": int(run_state.wood)},
		{"key": "stone", "label": "石材", "have": int(run_state.stone)},
	]
	var shortfalls: Array = []
	var reason_parts: PackedStringArray = PackedStringArray()
	for check_variant: Variant in checks:
		var check: Dictionary = check_variant
		var key := String(check.get("key", ""))
		var need := int(requires.get(key, 0))
		if need <= 0:
			continue
		var have := int(check.get("have", 0))
		if have < need:
			var missing := need - have
			shortfalls.append({
				"key": key,
				"label": String(check.get("label", key)),
				"need": need,
				"have": have,
				"missing": missing,
			})
			reason_parts.append("%d %s" % [missing, String(check.get("label", key))])
	if not shortfalls.is_empty():
		result["ok"] = false
		result["shortfalls"] = shortfalls
		result["reason"] = "还需 %s" % " / ".join(reason_parts)
	return result


## 解析某事件选项最终触发子事件的 requires（祭坛/塌方动态选项无静态 requires，返回空）。
func _requires_for_choice(event_id: StringName, choice_id: StringName) -> Dictionary:
	if choice_id == StringName():
		return {}
	var target_event_id := event_id
	var choice_result := _resolve_choice_event_id(event_id, choice_id)
	if choice_result.get("ok", false):
		target_event_id = StringName(choice_result.get("payload", {}).get("event_id", event_id))
	var target_cfg := get_event_cfg(target_event_id)
	var requires: Variant = target_cfg.get("requires", {})
	return requires if requires is Dictionary else {}


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
			&"gate_open_extra_tonight":
				var gate_ctx := _gate_context()
				var opened := ""
				if not gate_ctx.is_empty():
					var order: Array = NightTemplateResolver.resolve_activation_order(gate_ctx.get("all_gates", []), int(run_state.random_seed))
					var active_now: Array = gate_ctx.get("active", [])
					var closed_now: Array = run_state.night_gate_closed_keys
					for raw_gate: Variant in order:
						var gate := String(raw_gate)
						if not active_now.has(gate) and not closed_now.has(gate):
							opened = gate
							break
				if opened.is_empty():
					summary_lines.append("所有出怪口都已活跃，只剩报酬")
				else:
					run_state.add_night_gate_extra_open(opened)
					summary_lines.append("今晚 %s 提前开放" % opened)
			&"night_affix_add":
				var fixed_affix := StringName(effect.get("affix_id", ""))
				if fixed_affix != StringName() and not (run_state.night_affix_ids as Array).has(fixed_affix):
					run_state.night_affix_ids.append(fixed_affix)
					var data_repo = AppRefs.data_repo()
					var affix_cfg: Dictionary = data_repo.get_night_affix_cfg(fixed_affix) if data_repo != null else {}
					summary_lines.append("今晚追加词缀：%s" % String(affix_cfg.get("name", fixed_affix)))
			&"prestige_pct_loss":
				var pct := clampf(float(effect.get("pct", 0.0)), 0.0, 1.0)
				var lost := int(floor(float(maxi(int(run_state.prestige), 0)) * pct))
				if lost > 0:
					run_state.add_prestige(-lost)
				summary_lines.append("失去 %d 声望（当前的 %d%%）" % [lost, int(round(pct * 100.0))])
			&"core_max_hp_halve":
				var old_max := int(run_state.core_hp_max)
				var new_max := maxi(int(floor(float(old_max) / 2.0)), 1)
				if run_state.has_method("add_core_max_hp") and new_max != old_max:
					run_state.add_core_max_hp(new_max - old_max)
				summary_lines.append("核心生命上限减半（%d → %d）" % [old_max, new_max])
			&"grant_relic":
				var relic_id := StringName(effect.get("relic_id", ""))
				if relic_id != StringName() and _buff_manager != null and _buff_manager.has_method("apply_blessing"):
					var grant_result: Dictionary = _buff_manager.apply_blessing(relic_id)
					var data_repo = AppRefs.data_repo()
					var rc: Dictionary = data_repo.get_buff_cfg(relic_id) if data_repo != null else {}
					if grant_result.get("ok", false):
						summary_lines.append("获得遗物：%s" % String(rc.get("name", relic_id)))
					else:
						summary_lines.append("已拥有遗物：%s" % String(rc.get("name", relic_id)))
			&"prestige_loss":
				var amount := int(effect.get("value", 0))
				var actual := mini(maxi(amount, 0), maxi(int(run_state.prestige), 0))
				if actual > 0:
					run_state.add_prestige(-actual)
				summary_lines.append("失去 %d 声望" % actual)
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
		var relic_cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
		if bool(relic_cfg.get("event_only", false)):
			continue
		var rarity := int(relic_cfg.get("rarity", 1))
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
	if event_id == LANDSLIDE_EVENT_ID and String(choice_id).begins_with("seal_"):
		return _apply_landslide_seal(cell, String(choice_id).trim_prefix("seal_"))
	var triggered_event_id := event_id
	if event_id == LANDSLIDE_EVENT_ID and choice_id == &"leave":
		# 塌方选项是动态生成的，静态配置里没有；离开分支直接映射到隐藏空事件，
		# 走通用流程消耗事件点（与其他事件的离开选项一致）。
		triggered_event_id = &"event_landslide_leave"
	elif event_id == ALTAR_EVENT_ID and choice_id == &"leave":
		# 祭坛选项同为动态生成，离开分支同样映射到隐藏空事件。
		triggered_event_id = &"event_altar_leave"
	elif choice_id != StringName():
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
# 开局事件铺设
# ---------------------------------------------------------------------------
## 开局（第 1 天）一次性把所有设计好的母事件各投放一个到全图随机合法平地。
func _spawn_run_events() -> void:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null or _map_manager == null:
		return
	var event_ids: Array = data_repo.get_all_event_ids()
	if event_ids.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("run_events|%d" % int(run_state.random_seed)).hash())
	var cells := _pick_run_event_cells(event_ids.size(), rng)
	var count := mini(cells.size(), event_ids.size())
	for i in range(count):
		_events_by_cell[cells[i]] = event_ids[i]
		_spawned_event_ids[event_ids[i]] = true
	_refresh_map()


## 全图所有合法平地随机挑选落点（远离核心安全区与出怪口，不限方向与距离）。
func _pick_run_event_cells(count: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var width: int = int(_map_manager.width)
	var height: int = int(_map_manager.height)
	var core_cell: Vector2i = _map_manager.get_core_cell() if _map_manager.has_method("get_core_cell") else Vector2i(-99, -99)
	var spawn_cells: Array = _map_manager.get_spawn_cells() if _map_manager.has_method("get_spawn_cells") else []
	var candidates: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell := Vector2i(x, y)
			if _is_valid_event_cell(cell, core_cell, spawn_cells):
				candidates.append(cell)
	var chosen: Array[Vector2i] = []
	var chosen_set: Dictionary = {}
	_fill_from_pool(chosen, chosen_set, candidates, count, rng)
	return chosen


## 调试用：在已探索的合法事件格随机投放指定事件，返回落点（无可用格时返回 -1,-1）。
func debug_spawn_event_in_discovered(event_id: StringName) -> Vector2i:
	if _map_manager == null or event_id == StringName():
		return Vector2i(-1, -1)
	var width: int = int(_map_manager.width)
	var height: int = int(_map_manager.height)
	var core_cell: Vector2i = _map_manager.get_core_cell() if _map_manager.has_method("get_core_cell") else Vector2i(-99, -99)
	var spawn_cells: Array = _map_manager.get_spawn_cells() if _map_manager.has_method("get_spawn_cells") else []
	var candidates: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell := Vector2i(x, y)
			if _events_by_cell.has(cell) or not _map_manager.is_discovered(cell):
				continue
			if _is_valid_event_cell(cell, core_cell, spawn_cells):
				candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	var cell: Vector2i = candidates.pick_random()
	_events_by_cell[cell] = event_id
	_refresh_map()
	return cell


## 从 pool 里用给定 rng 随机挑未选中的格子填入 chosen，直到达到 count 或 pool 取尽。
func _fill_from_pool(chosen: Array[Vector2i], chosen_set: Dictionary, pool: Array[Vector2i], count: int, rng: RandomNumberGenerator) -> void:
	while chosen.size() < count and not pool.is_empty():
		var idx := rng.randi() % pool.size()
		var cell: Vector2i = pool[idx]
		pool.remove_at(idx)
		if chosen_set.has(cell):
			continue
		chosen.append(cell)
		chosen_set[cell] = true


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


# ---------------------------------------------------------------------------
# 古代祭坛：为单位类型灌注本局永久盟约 tag（动态三选一 + 离开）
# ---------------------------------------------------------------------------
func _build_altar_choices(cell: Vector2i) -> Array:
	var choices: Array = []
	var offers := _ensure_altar_offers(cell)
	# 固定生成三个灌注选项（按钮是塔菲梗文案，悬停才是准确的"某干员灌注某盟约"描述）。
	# 候选不足时重复同一个，完全没有干员时三个都提示无法灌注、点了什么都不会发生。
	for i in range(ALTAR_OFFER_COUNT):
		var meme := String(ALTAR_MEME_TEXTS[i]) if i < ALTAR_MEME_TEXTS.size() else "灌注盟约"
		if offers.is_empty():
			choices.append({
				"id": "altar_empty_%d" % i,
				"text": meme,
				"kind": "primary",
				"effect_desc": "你还没有任何干员，无法灌注盟约——什么都不会发生。",
			})
			continue
		var offer: Dictionary = offers[i % offers.size()]
		choices.append({
			"id": String(offer.get("choice_id", "infuse_%d" % i)),
			"text": meme,
			"kind": "primary",
			"event_id": "event_altar_infused",
			"effect_desc": "消耗 %d 魔力矿，把「%s」盟约灌注给 %s——本局所有 %s（含之后购买）永久继承。" % [ALTAR_MANA_COST, String(offer.get("covenant", "")), String(offer.get("operator_name", "")), String(offer.get("operator_name", ""))],
		})
	choices.append({
		"id": "leave",
		"text": "感觉躺上去智力会降低，还是算了吧",
		"kind": "secondary",
		"event_id": "event_altar_leave",
		"effect_desc": "不进行灌注。",
	})
	return choices


## 生成最多 3 个（单位类型, 盟约）灌注组合：偏向玩家已有人数的盟约，帮助凑触发档位。
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
	var seen_units: Dictionary = {}
	var data_repo = AppRefs.data_repo()
	for operator_variant: Variant in operators:
		var operator: Dictionary = operator_variant
		var unit_id := StringName(operator.get("unit_id", ""))
		if unit_id == StringName() or seen_units.has(unit_id):
			continue
		seen_units[unit_id] = true
		var current: Array = run_state.get_unit_covenants(unit_id) if run_state.has_method("get_unit_covenants") else run_state.get_operator_covenants(StringName(operator.get("key", "")))
		var unit_cfg: Dictionary = data_repo.get_unit_cfg(unit_id) if data_repo != null else {}
		var display_name := String(unit_cfg.get("name", operator.get("name", unit_id)))
		for covenant_id in CovenantDefs.ORDER:
			if current.has(covenant_id):
				continue
			candidates.append({
				"unit_id": unit_id,
				"operator_name": display_name,
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
	var unit_id := StringName(offer.get("unit_id", ""))
	var infuse_result: Dictionary = run_state.add_unit_covenant(unit_id, covenant) if run_state.has_method("add_unit_covenant") else run_state.add_operator_covenant(StringName(offer.get("operator_key", "")), covenant)
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
			"summary": "所有 %s 获得「%s」盟约" % [String(offer.get("operator_name", "")), String(covenant)],
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


# ---------------------------------------------------------------------------
# 塌方契约 / 开口赌约：当夜出怪口覆盖项（动态封口选项 + 提前开口效果）
# ---------------------------------------------------------------------------
func _gate_context() -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null or _map_manager == null or not _map_manager.has_method("get_spawn_keys"):
		return {}
	var all_gates: Array = _map_manager.get_spawn_keys()
	var active: Array = NightTemplateResolver.resolve_active_gates(all_gates, int(run_state.random_seed), int(run_state.day), run_state.night_gate_closed_keys, run_state.night_gate_extra_open_keys)
	return {"run_state": run_state, "all_gates": all_gates, "active": active}


## 每个当前活跃出怪口一个封堵选项（仅当活跃口 >1，至少保留一口）+ 离开。
func _build_landslide_choices() -> Array:
	var choices: Array = []
	var ctx := _gate_context()
	var active: Array = ctx.get("active", [])
	if active.size() > 1:
		for raw_gate: Variant in active:
			var gate := String(raw_gate)
			choices.append({
				"id": "seal_%s" % gate,
				"text": "封堵 %s（%d 魔力矿）" % [gate, LANDSLIDE_MANA_COST],
				"kind": "primary",
				"effect_desc": "今晚 %s 不会出怪，怪物改道其他出怪口。" % gate,
			})
	choices.append({
		"id": "leave",
		"text": "不必了",
		"kind": "secondary",
		"event_id": "event_landslide_leave",
		"effect_desc": "保持现状。",
	})
	return choices


func _apply_landslide_seal(cell: Vector2i, gate_key: String) -> Dictionary:
	var ctx := _gate_context()
	if ctx.is_empty():
		return ActionResult.err(&"MAP_UNAVAILABLE", "地图尚未初始化")
	var run_state: Node = ctx.get("run_state")
	var active: Array = ctx.get("active", [])
	if not active.has(gate_key):
		return ActionResult.err(&"GATE_NOT_ACTIVE", "该出怪口今晚本就沉默")
	if active.size() <= 1:
		return ActionResult.err(&"LAST_ACTIVE_GATE", "至少要保留一个活跃出怪口")
	var spend_result: Dictionary = run_state.spend_materials(0, 0, LANDSLIDE_MANA_COST)
	if not spend_result.get("ok", false):
		return ActionResult.err(&"NOT_ENOUGH_MATERIALS", "魔力矿不足（需要 %d）" % LANDSLIDE_MANA_COST)
	run_state.add_night_gate_closed(gate_key)
	mark_event_triggered(cell)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.random_event_triggered.emit(LANDSLIDE_EVENT_ID, cell)
	return ActionResult.ok({
		"event_id": LANDSLIDE_EVENT_ID,
		"source_event_id": LANDSLIDE_EVENT_ID,
		"choice_id": StringName("seal_%s" % gate_key),
		"effect_type": &"contract",
		"effect_payload": {
			"mana": -LANDSLIDE_MANA_COST,
			"summary": "今晚 %s 已被塌方封堵" % gate_key,
		},
	})
