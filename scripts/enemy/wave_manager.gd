extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const NightTemplateResolver = preload("res://scripts/enemy/night_template_resolver.gd")
const NightAffixService = preload("res://scripts/enemy/night_affix_service.gd")


# 波间喘息时长：上一波清场后到下一波开始的间隔。
const WAVE_LULL_SEC := 12.0
# 上一波刷怪完毕后若残敌迟迟未清，强制开下一波的等待上限（防拖延/卡死）。
const WAVE_FORCE_NEXT_SEC := 45.0

var _elapsed := 0.0
var _pending_spawns: Array[Dictionary] = []
var _running := false
var _wave_template_ids: Array[StringName] = []
var _affix_cfgs: Array[Dictionary] = []
var _wave_index := -1
var _wave_spawns_done_at := -1.0
var _next_wave_at := -1.0
var _enemy_cfg_override_cache: Dictionary = {}

@onready var _enemy_manager: Node = get_node_or_null("../EnemyManager")
@onready var _map_manager: Node = get_node_or_null("../MapManager")


func _ready() -> void:
	set_process(true)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.enemy_died.connect(_on_enemy_died)


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	while not _pending_spawns.is_empty() and float(_pending_spawns[0].get("time", 0.0)) <= _elapsed:
		var entry: Dictionary = _pending_spawns.pop_front()
		var spawn_cell: Vector2i = _map_manager.get_spawn_cell_by_key(StringName(entry.get("spawn_key", "")))
		var enemy_id := StringName(entry.get("enemy_id", ""))
		_enemy_manager.spawn_enemy(enemy_id, spawn_cell, _affixed_enemy_cfg_override(enemy_id))
	if _pending_spawns.is_empty() and _wave_spawns_done_at < 0.0:
		_wave_spawns_done_at = _elapsed
	_update_wave_flow()


func tier_for_day(day: int) -> StringName:
	return NightTemplateResolver.tier_for_day(day)


func resolve_night_template(tier: StringName, run_seed: int, day: int, used_ids: Array) -> StringName:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or not data_repo.has_method("get_wave_template_ids_by_tier"):
		return StringName()
	var pool: Array[StringName] = data_repo.get_wave_template_ids_by_tier(tier)
	return NightTemplateResolver.resolve(pool, used_ids, run_seed, day)


func resolve_night_plan(run_seed: int, day: int, used_ids: Array) -> Array[StringName]:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or not data_repo.has_method("get_wave_template_ids_by_tier"):
		return []
	var pools: Dictionary = {}
	for tier in NightTemplateResolver.wave_tiers_for_day(day):
		if not pools.has(tier):
			pools[tier] = data_repo.get_wave_template_ids_by_tier(tier)
	return NightTemplateResolver.resolve_night_plan(pools, used_ids, run_seed, day)


## 启动整夜战斗：按计划顺序播放多个波次模板，并应用当晚词缀。
func start_night(template_ids: Array, affix_ids: Array = []) -> void:
	stop_wave()
	for raw_id: Variant in template_ids:
		var id := StringName(raw_id)
		if id != StringName():
			_wave_template_ids.append(id)
	_affix_cfgs = _load_affix_cfgs(affix_ids)
	_enemy_cfg_override_cache.clear()
	_elapsed = 0.0
	if _wave_template_ids.is_empty():
		return
	_running = true
	_start_wave(0)


## 单波兼容入口（沙盒/旧调用路径）。
func start_wave_for_template(template_id: StringName) -> void:
	if template_id == StringName():
		stop_wave()
		return
	start_night([template_id], [])


func stop_wave() -> void:
	_pending_spawns.clear()
	_wave_template_ids.clear()
	_affix_cfgs.clear()
	_enemy_cfg_override_cache.clear()
	_wave_index = -1
	_wave_spawns_done_at = -1.0
	_next_wave_at = -1.0
	_running = false


## 整夜是否结束：所有波放完且场上无敌人。
func is_wave_finished() -> bool:
	return _running and _pending_spawns.is_empty() and not _has_more_waves() and _enemy_manager.get_alive_enemy_count() == 0


func has_pending_spawn() -> bool:
	return not _pending_spawns.is_empty()


func get_current_wave_index() -> int:
	return _wave_index


func get_wave_count() -> int:
	return _wave_template_ids.size()


func get_current_wave_template_id() -> StringName:
	if _wave_index >= 0 and _wave_index < _wave_template_ids.size():
		return _wave_template_ids[_wave_index]
	return StringName()


func _start_wave(index: int) -> void:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or index < 0 or index >= _wave_template_ids.size():
		_check_finish()
		return
	_wave_index = index
	_wave_spawns_done_at = -1.0
	_next_wave_at = -1.0
	_pending_spawns.clear()
	var template_id: StringName = _wave_template_ids[index]
	var cfg: Dictionary = data_repo.get_wave_template_cfg(template_id) if data_repo.has_method("get_wave_template_cfg") else {}
	var wave_start_time := _elapsed
	for entry in _build_resolved_entries(cfg, template_id, index, _affix_cfgs):
		for spawn_entry in _make_expanded_spawn_entries(entry):
			spawn_entry["time"] = wave_start_time + float(spawn_entry.get("time", 0.0))
			_pending_spawns.append(spawn_entry)
	_pending_spawns.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.night_wave_started.emit(index, _wave_template_ids.size())


func _has_more_waves() -> bool:
	return _wave_index + 1 < _wave_template_ids.size()


func _update_wave_flow() -> void:
	if not _running or not _pending_spawns.is_empty():
		return
	if not _has_more_waves():
		_check_finish()
		return
	var alive_count: int = _enemy_manager.get_alive_enemy_count() if _enemy_manager != null else 0
	if _next_wave_at < 0.0:
		if alive_count == 0:
			_next_wave_at = _elapsed + WAVE_LULL_SEC
		elif _wave_spawns_done_at >= 0.0 and _elapsed - _wave_spawns_done_at >= WAVE_FORCE_NEXT_SEC:
			_next_wave_at = _elapsed
	if _next_wave_at >= 0.0 and _elapsed >= _next_wave_at:
		_start_wave(_wave_index + 1)


func get_wave_preview_for_template(template_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or template_id == StringName():
		return {}
	var cfg: Dictionary = data_repo.get_wave_template_cfg(template_id) if data_repo.has_method("get_wave_template_cfg") else {}
	if cfg.is_empty():
		return {}
	return _build_wave_preview(cfg, _seed_day_for(template_id), template_id)


## 整夜聚合预览：多波合并构成 + 词缀公示。条目与敌人属性均为词缀生效后的真实值。
## 预览的 gate 种子隐式使用当前 RunState.day，仅对"当晚"的计划有效；对未来夜晚的预演结果仅供参考。
func get_night_preview(template_ids: Array, affix_ids: Array = []) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or template_ids.is_empty():
		return {}
	var affix_cfgs: Array[Dictionary] = _load_affix_cfgs(affix_ids)
	var wave_previews: Array[Dictionary] = []
	for wave_index in range(template_ids.size()):
		var template_id := StringName(template_ids[wave_index])
		if template_id == StringName():
			continue
		var cfg: Dictionary = data_repo.get_wave_template_cfg(template_id) if data_repo.has_method("get_wave_template_cfg") else {}
		if cfg.is_empty():
			continue
		var wave_preview := _build_wave_preview(cfg, _seed_day_for(template_id), template_id, wave_index, affix_cfgs)
		if not wave_preview.is_empty():
			wave_previews.append(wave_preview)
	if wave_previews.is_empty():
		return {}

	var merged_by_key: Dictionary = {}
	var spawn_order: Array[StringName] = []
	var key_enemies: Array[StringName] = []
	var wave_summaries: Array[Dictionary] = []
	var wave_names := PackedStringArray()
	var total_count := 0
	for wave_preview in wave_previews:
		wave_names.append(String(wave_preview.get("name", "")))
		total_count += int(wave_preview.get("total_count", 0))
		wave_summaries.append({
			"wave_index": wave_summaries.size(),
			"template_id": StringName(wave_preview.get("template_id", "")),
			"name": String(wave_preview.get("name", "")),
			"desc": String(wave_preview.get("desc", "")),
			"total_count": int(wave_preview.get("total_count", 0)),
			"main_gate": String(wave_preview.get("main_gate", "")),
			"spawn_order": wave_preview.get("spawn_order", []),
			"entries": wave_preview.get("entries", []),
		})
		for raw_enemy: Variant in wave_preview.get("key_enemies", []):
			var key_enemy := StringName(raw_enemy)
			if key_enemy != StringName() and not key_enemies.has(key_enemy):
				key_enemies.append(key_enemy)
		for raw_entry: Variant in wave_preview.get("entries", []):
			if typeof(raw_entry) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = raw_entry
			var spawn_key := StringName(entry.get("spawn_key", ""))
			var aggregate_key := "%s|%s" % [String(spawn_key), String(entry.get("enemy_id", ""))]
			if not merged_by_key.has(aggregate_key):
				merged_by_key[aggregate_key] = entry.duplicate(true)
				if not spawn_order.has(spawn_key):
					spawn_order.append(spawn_key)
			else:
				var merged: Dictionary = merged_by_key[aggregate_key]
				merged["count"] = int(merged.get("count", 0)) + int(entry.get("count", 0))
				merged["first_time"] = min(float(merged.get("first_time", 0.0)), float(entry.get("first_time", 0.0)))
				merged["last_time"] = max(float(merged.get("last_time", 0.0)), float(entry.get("last_time", 0.0)))
	var merged_entries: Array[Dictionary] = []
	for raw_entry: Variant in merged_by_key.values():
		merged_entries.append(raw_entry as Dictionary)
	merged_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var spawn_a := String(a.get("spawn_key", ""))
		var spawn_b := String(b.get("spawn_key", ""))
		if spawn_a == spawn_b:
			return float(a.get("first_time", 0.0)) < float(b.get("first_time", 0.0))
		return spawn_a < spawn_b
	)

	var affixes: Array[Dictionary] = []
	for affix_cfg in affix_cfgs:
		affixes.append({
			"id": StringName(affix_cfg.get("id", "")),
			"name": String(affix_cfg.get("name", "")),
			"desc": String(affix_cfg.get("desc", "")),
		})
	var first_preview: Dictionary = wave_previews[0]
	return {
		"day": int(first_preview.get("day", 0)),
		"template_id": StringName(first_preview.get("template_id", "")),
		"name": " → ".join(wave_names),
		"desc": String(first_preview.get("desc", "")),
		"tier": StringName(first_preview.get("tier", "")),
		"key_enemies": key_enemies,
		"entries": merged_entries,
		"spawn_order": spawn_order,
		"total_count": total_count,
		"wave_count": wave_previews.size(),
		"waves": wave_summaries,
		"affixes": affixes,
	}


func _build_wave_preview(cfg: Dictionary, seed_day: int, template_id: StringName = StringName(), wave_index: int = 0, affix_cfgs: Array = []) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return {}
	var entries_by_key: Dictionary = {}
	var spawn_order: Array[StringName] = []
	var total_count := 0
	for entry in _build_resolved_entries(cfg, template_id, wave_index, affix_cfgs):
		var enemy_id := StringName(entry.get("enemy_id", ""))
		var spawn_key := StringName(entry.get("spawn_key", ""))
		if enemy_id == StringName() or spawn_key == StringName():
			continue
		var count: int = max(int(entry.get("count", 1)), 0)
		if count <= 0:
			continue
		var enemy_cfg: Dictionary = data_repo.get_enemy_cfg(enemy_id)
		if not affix_cfgs.is_empty():
			enemy_cfg = NightAffixService.apply_to_enemy_cfg(enemy_cfg, affix_cfgs)
		var aggregate_key := "%s|%s" % [String(spawn_key), String(enemy_id)]
		if not entries_by_key.has(aggregate_key):
			entries_by_key[aggregate_key] = {
				"spawn_key": spawn_key,
				"lane": StringName(String(entry.get("lane", ""))),
				"enemy_id": enemy_id,
				"enemy_name": String(enemy_cfg.get("name", enemy_id)),
				"enemy_cfg": enemy_cfg,
				"path_mode": _resolve_enemy_path_mode(enemy_cfg),
				"count": 0,
				"first_time": float(entry.get("time", 0.0)),
				"last_time": float(entry.get("time", 0.0)),
			}
			if not spawn_order.has(spawn_key):
				spawn_order.append(spawn_key)
		var aggregate: Dictionary = entries_by_key[aggregate_key]
		var first_time: float = float(entry.get("time", 0.0))
		var interval: float = max(float(entry.get("interval", 0.0)), 0.0)
		var last_time: float = first_time + interval * float(max(count - 1, 0))
		aggregate["count"] = int(aggregate.get("count", 0)) + count
		aggregate["first_time"] = min(float(aggregate.get("first_time", first_time)), first_time)
		aggregate["last_time"] = max(float(aggregate.get("last_time", last_time)), last_time)
		total_count += count

	var entries: Array[Dictionary] = []
	for entry in entries_by_key.values():
		entries.append((entry as Dictionary).duplicate(true))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var spawn_a := String(a.get("spawn_key", ""))
		var spawn_b := String(b.get("spawn_key", ""))
		if spawn_a == spawn_b:
			return float(a.get("first_time", 0.0)) < float(b.get("first_time", 0.0))
		return spawn_a < spawn_b
	)
	var run_state = AppRefs.run_state()
	var day_value: int = int(run_state.day) if run_state != null else int(cfg.get("day", seed_day))
	var preview := {
		"day": day_value,
		"seed_day": seed_day,
		"template_id": template_id,
		"name": String(cfg.get("name", template_id)),
		"desc": String(cfg.get("desc", "")),
		"tier": StringName(cfg.get("tier", "")),
		"key_enemies": _normalize_key_enemies(cfg.get("key_enemies", []), entries),
		"entries": entries,
		"spawn_order": spawn_order,
		"main_gate": _main_gate_for_wave(wave_index, _active_spawn_keys()),
		"total_count": total_count,
	}
	return preview


func _on_enemy_died(_enemy_runtime_id: int, _enemy_id: StringName) -> void:
	_check_finish()


func _check_finish() -> void:
	if is_wave_finished():
		_running = false
		var event_bus = AppRefs.event_bus()
		var run_state = AppRefs.run_state()
		if event_bus != null and run_state != null:
			event_bus.night_cleared.emit(run_state.day)


func _make_expanded_spawn_entries(entry: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var count: int = max(int(entry.get("count", 1)), 0)
	var interval: float = max(float(entry.get("interval", 0.0)), 0.0)
	var start_time: float = float(entry.get("time", 0.0))
	for index in range(count):
		var spawn_entry := entry.duplicate(true)
		spawn_entry["time"] = start_time + interval * float(index)
		spawn_entry["count"] = 1
		entries.append(spawn_entry)
	return entries


## 一波的最终条目：groups/entries 读取 -> enemy_choices 解析 -> lane 落口分配 -> 词缀条目级变换。
## 运行时与预览共用，保证公示诚实。lane 解析必须在词缀 transform 之前（spawn_surge 等按 spawn_key 结算）。
func _build_resolved_entries(cfg: Dictionary, template_id: StringName, wave_index: int, affix_cfgs: Array) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	var raw_entries_variant: Variant = cfg.get("groups", cfg.get("entries", []))
	var raw_entries: Array = raw_entries_variant if typeof(raw_entries_variant) == TYPE_ARRAY else []
	var seed_day := _seed_day_for(template_id)
	var active_gates: Array = _active_spawn_keys()
	var main_gate := _main_gate_for_wave(wave_index, active_gates)
	var run_state = AppRefs.run_state()
	var run_seed := int(run_state.random_seed) if run_state != null else 0
	var day := int(run_state.day) if run_state != null else 0
	for entry_index in range(raw_entries.size()):
		var entry_variant: Variant = raw_entries[entry_index]
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = _resolve_wave_entry(entry_variant as Dictionary, seed_day, entry_index)
		if StringName(entry.get("enemy_id", "")) == StringName():
			continue
		if String(entry.get("spawn_key", "")).is_empty():
			var lane := StringName(String(entry.get("lane", "any")))
			entry["spawn_key"] = NightTemplateResolver.resolve_lane_gate(lane, entry_index, main_gate, active_gates, run_seed, day, wave_index)
		resolved.append(entry)
	if affix_cfgs.is_empty():
		return resolved
	var spawn_keys: Array = _collect_spawn_keys(resolved)
	return NightAffixService.transform_entries(resolved, affix_cfgs, spawn_keys, _entry_transform_seed(template_id, wave_index))


func _collect_spawn_keys(entries: Array) -> Array:
	var keys: Array = []
	for raw_entry: Variant in entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var key := String((raw_entry as Dictionary).get("spawn_key", ""))
		if not key.is_empty() and not keys.has(key):
			keys.append(key)
	keys.sort()
	return keys


func _active_spawn_keys() -> Array:
	if _map_manager != null and _map_manager.has_method("get_spawn_keys"):
		return _map_manager.get_spawn_keys()
	return []


func _main_gate_for_wave(wave_index: int, active_gates: Array) -> String:
	# 预览（_build_wave_preview）与条目解析（_build_resolved_entries）两处调用必须保持同参，否则公示与实际落口会分叉。
	var run_state = AppRefs.run_state()
	var run_seed := int(run_state.random_seed) if run_state != null else 0
	var day := int(run_state.day) if run_state != null else 0
	return NightTemplateResolver.resolve_main_gate(active_gates, run_seed, day, wave_index)


func _entry_transform_seed(template_id: StringName, wave_index: int) -> int:
	var run_state = AppRefs.run_state()
	var run_seed := int(run_state.random_seed) if run_state != null else 0
	var day := int(run_state.day) if run_state != null else 0
	return abs(("%d|%d|%d|%s" % [run_seed, day, wave_index, String(template_id)]).hash())


func _load_affix_cfgs(affix_ids: Array) -> Array[Dictionary]:
	var cfgs: Array[Dictionary] = []
	var data_repo = AppRefs.data_repo()
	if data_repo == null or not data_repo.has_method("get_night_affix_cfg"):
		return cfgs
	for raw_id: Variant in affix_ids:
		var cfg: Dictionary = data_repo.get_night_affix_cfg(StringName(raw_id))
		if not cfg.is_empty():
			cfgs.append(cfg)
	return cfgs


func _affixed_enemy_cfg_override(enemy_id: StringName) -> Dictionary:
	if _affix_cfgs.is_empty() or enemy_id == StringName():
		return {}
	if _enemy_cfg_override_cache.has(enemy_id):
		return _enemy_cfg_override_cache[enemy_id]
	var data_repo = AppRefs.data_repo()
	var base_cfg: Dictionary = data_repo.get_enemy_cfg(enemy_id) if data_repo != null else {}
	var override: Dictionary = NightAffixService.apply_to_enemy_cfg(base_cfg, _affix_cfgs)
	_enemy_cfg_override_cache[enemy_id] = override
	return override


func _resolve_wave_entry(entry: Dictionary, day: int, entry_index: int) -> Dictionary:
	var resolved := entry.duplicate(true)
	var chosen_enemy_id := _pick_enemy_choice(resolved.get("enemy_choices", []), day, entry_index)
	if chosen_enemy_id != StringName():
		resolved["enemy_id"] = chosen_enemy_id
	return resolved


func _pick_enemy_choice(raw_choices: Variant, day: int, entry_index: int) -> StringName:
	if typeof(raw_choices) != TYPE_ARRAY:
		return StringName()
	var choices: Array = raw_choices
	var weighted_choices: Array[Dictionary] = []
	var total_weight := 0.0
	for choice_variant: Variant in choices:
		if typeof(choice_variant) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_variant
		var enemy_id := StringName(choice.get("enemy_id", ""))
		var weight: float = max(float(choice.get("weight", 1.0)), 0.0)
		if enemy_id == StringName() or weight <= 0.0:
			continue
		weighted_choices.append({
			"enemy_id": enemy_id,
			"weight": weight
		})
		total_weight += weight
	if weighted_choices.is_empty() or total_weight <= 0.0:
		return StringName()

	var rng := RandomNumberGenerator.new()
	rng.seed = _make_enemy_choice_seed(day, entry_index)
	var roll: float = rng.randf() * total_weight
	var cursor := 0.0
	for choice: Dictionary in weighted_choices:
		cursor += float(choice.get("weight", 0.0))
		if roll <= cursor:
			return StringName(choice.get("enemy_id", ""))
	return StringName((weighted_choices.back() as Dictionary).get("enemy_id", ""))


func _make_enemy_choice_seed(day: int, entry_index: int) -> int:
	var run_state = AppRefs.run_state()
	var run_seed := int(run_state.random_seed) if run_state != null else 0
	var seed_text := "%d|%d|%d" % [run_seed, day, entry_index]
	return abs(seed_text.hash())


func _seed_day_for(template_id: StringName) -> int:
	return abs(String(template_id).hash())


func _normalize_key_enemies(raw_key_enemies: Variant, entries: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	if typeof(raw_key_enemies) == TYPE_ARRAY:
		for raw_enemy: Variant in raw_key_enemies:
			var enemy_id := StringName(raw_enemy)
			if enemy_id != StringName() and not result.has(enemy_id):
				result.append(enemy_id)
	if not result.is_empty():
		return result
	var scored: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var enemy_cfg: Dictionary = entry.get("enemy_cfg", {})
		var enemy_id := StringName(entry.get("enemy_id", ""))
		if enemy_id == StringName():
			continue
		scored.append({
			"enemy_id": enemy_id,
			"score": _key_enemy_score(entry, enemy_cfg)
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	for item: Dictionary in scored:
		var enemy_id := StringName(item.get("enemy_id", ""))
		if enemy_id != StringName() and not result.has(enemy_id):
			result.append(enemy_id)
		if result.size() >= 2:
			break
	return result


func _key_enemy_score(entry: Dictionary, enemy_cfg: Dictionary) -> float:
	var score := float(entry.get("count", 0))
	var enemy_id := StringName(entry.get("enemy_id", ""))
	var behavior_type := StringName(enemy_cfg.get("behavior_type", "normal"))
	var move_type := StringName(enemy_cfg.get("move_type", "ground"))
	if enemy_id == &"milk_dragon_chief" or enemy_id == &"patriot":
		score += 1000.0
	if behavior_type == &"demolisher":
		score += 120.0
	if int(enemy_cfg.get("core_damage", 1)) >= 2:
		score += 60.0
	if float(enemy_cfg.get("attack_range", 0.0)) > 1.0:
		score += 45.0
	if move_type == &"flying":
		score += 35.0
	return score


func _resolve_enemy_path_mode(enemy_cfg: Dictionary) -> StringName:
	if StringName(enemy_cfg.get("move_type", "ground")) == &"flying":
		return &"flying"
	return &"demolisher" if StringName(enemy_cfg.get("behavior_type", "normal")) == &"demolisher" else &"normal"
