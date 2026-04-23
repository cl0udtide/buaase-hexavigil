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
		var count := int(entry.get("count", 1))
		for _i in range(count):
			_enemy_manager.spawn_enemy(StringName(entry.get("enemy_id", "")), spawn_cell)
	_check_finish()


func start_wave_for_day(day: int) -> void:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		_pending_spawns.clear()
		_running = false
		return
	var cfg: Dictionary = data_repo.get_wave_cfg(day)
	_pending_spawns = cfg.get("entries", []).duplicate(true)
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


func _on_enemy_died(_enemy_runtime_id: int, _enemy_id: StringName) -> void:
	_check_finish()


func _check_finish() -> void:
	if is_wave_finished():
		_running = false
		var event_bus = AppRefs.event_bus()
		var run_state = AppRefs.run_state()
		if event_bus != null and run_state != null:
			event_bus.night_cleared.emit(run_state.day)
