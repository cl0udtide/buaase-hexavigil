extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const NightTemplateResolver = preload("res://scripts/enemy/night_template_resolver.gd")


var _elapsed := 0.0
var _pending_spawns: Array[Dictionary] = []
var _running := false

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
		_enemy_manager.spawn_enemy(StringName(entry.get("enemy_id", "")), spawn_cell)
	_check_finish()


func start_wave_for_day(day: int) -> void:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		_pending_spawns.clear()
		_running = false
		return
	var cfg: Dictionary = _get_wave_cfg_with_fallback(data_repo, day)
	_pending_spawns.clear()
	var raw_entries: Array = cfg.get("entries", [])
	for entry_index in range(raw_entries.size()):
		var entry_variant: Variant = raw_entries[entry_index]
		if typeof(entry_variant) == TYPE_DICTIONARY:
			var entry: Dictionary = _resolve_wave_entry(entry_variant as Dictionary, day, entry_index)
			if StringName(entry.get("enemy_id", "")) != StringName():
				_pending_spawns.append_array(_make_expanded_spawn_entries(entry))
	_pending_spawns.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	_elapsed = 0.0
	_running = true


func tier_for_day(day: int) -> StringName:
	return NightTemplateResolver.tier_for_day(day)


func resolve_night_template(tier: StringName, run_seed: int, day: int, used_ids: Array) -> StringName:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or not data_repo.has_method("get_wave_template_ids_by_tier"):
		return StringName()
	var pool: Array[StringName] = data_repo.get_wave_template_ids_by_tier(tier)
	return NightTemplateResolver.resolve(pool, used_ids, run_seed, day)


func start_wave_for_template(template_id: StringName) -> void:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or template_id == StringName():
		_pending_spawns.clear()
		_running = false
		return
	var cfg: Dictionary = data_repo.get_wave_template_cfg(template_id) if data_repo.has_method("get_wave_template_cfg") else {}
	if cfg.is_empty():
		_pending_spawns.clear()
		_running = false
		return
	_pending_spawns.clear()
	var raw_entries: Array = cfg.get("entries", [])
	var seed_day := _seed_day_for(template_id)
	for entry_index in range(raw_entries.size()):
		var entry_variant: Variant = raw_entries[entry_index]
		if typeof(entry_variant) == TYPE_DICTIONARY:
			var entry: Dictionary = _resolve_wave_entry(entry_variant as Dictionary, seed_day, entry_index)
			if StringName(entry.get("enemy_id", "")) != StringName():
				_pending_spawns.append_array(_make_expanded_spawn_entries(entry))
	_pending_spawns.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	_elapsed = 0.0
	_running = true


func stop_wave() -> void:
	_pending_spawns.clear()
	_running = false


func is_wave_finished() -> bool:
	return _running and _pending_spawns.is_empty() and _enemy_manager.get_alive_enemy_count() == 0


func has_pending_spawn() -> bool:
	return not _pending_spawns.is_empty()


func get_wave_preview_for_day(day: int) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return {}
	var run_state = AppRefs.run_state()
	if run_state != null and StringName(run_state.night_template_id) != StringName() and data_repo.has_method("get_wave_template_cfg"):
		return get_wave_preview_for_template(run_state.night_template_id)
	var cfg: Dictionary = _get_wave_cfg_with_fallback(data_repo, day)
	if cfg.is_empty():
		return {}
	return _build_wave_preview(cfg, day, StringName())


func get_wave_preview_for_template(template_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or template_id == StringName():
		return {}
	var cfg: Dictionary = data_repo.get_wave_template_cfg(template_id) if data_repo.has_method("get_wave_template_cfg") else {}
	if cfg.is_empty():
		return {}
	return _build_wave_preview(cfg, _seed_day_for(template_id), template_id)


func _build_wave_preview(cfg: Dictionary, seed_day: int, template_id: StringName = StringName()) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return {}
	var entries_by_key: Dictionary = {}
	var spawn_order: Array[StringName] = []
	var total_count := 0
	var raw_entries: Array = cfg.get("entries", [])
	for entry_index in range(raw_entries.size()):
		var entry_variant: Variant = raw_entries[entry_index]
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = _resolve_wave_entry(entry_variant as Dictionary, seed_day, entry_index)
		var enemy_id := StringName(entry.get("enemy_id", ""))
		var spawn_key := StringName(entry.get("spawn_key", ""))
		if enemy_id == StringName() or spawn_key == StringName():
			continue
		var count: int = max(int(entry.get("count", 1)), 0)
		if count <= 0:
			continue
		var enemy_cfg: Dictionary = data_repo.get_enemy_cfg(enemy_id)
		var aggregate_key := "%s|%s" % [String(spawn_key), String(enemy_id)]
		if not entries_by_key.has(aggregate_key):
			entries_by_key[aggregate_key] = {
				"spawn_key": spawn_key,
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
		"total_count": total_count
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


func _get_wave_cfg_with_fallback(data_repo: Node, day: int) -> Dictionary:
	var fallback_day := day
	while fallback_day >= 1:
		var cfg: Dictionary = data_repo.get_wave_cfg(fallback_day)
		if not cfg.is_empty() and not (cfg.get("entries", []) as Array).is_empty():
			return cfg
		fallback_day -= 1
	return {}


func _resolve_enemy_path_mode(enemy_cfg: Dictionary) -> StringName:
	if StringName(enemy_cfg.get("move_type", "ground")) == &"flying":
		return &"flying"
	return &"demolisher" if StringName(enemy_cfg.get("behavior_type", "normal")) == &"demolisher" else &"normal"
