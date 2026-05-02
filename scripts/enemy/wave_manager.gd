extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")


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
	for entry_variant: Variant in cfg.get("entries", []):
		if typeof(entry_variant) == TYPE_DICTIONARY:
			_pending_spawns.append_array(_make_expanded_spawn_entries(entry_variant as Dictionary))
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
	var cfg: Dictionary = _get_wave_cfg_with_fallback(data_repo, day)
	if cfg.is_empty():
		return {}

	var entries_by_key: Dictionary = {}
	var spawn_order: Array[StringName] = []
	var total_count := 0
	for entry_variant: Variant in cfg.get("entries", []):
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
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
	return {
		"day": int(cfg.get("day", day)),
		"requested_day": day,
		"entries": entries,
		"spawn_order": spawn_order,
		"total_count": total_count
	}


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
