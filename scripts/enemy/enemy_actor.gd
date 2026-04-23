extends Node2D


var enemy_id: StringName
var runtime_id := -1
var current_cell := Vector2i.ZERO
var cfg: Dictionary = {}
var current_hp := 1
var _path: Array[Vector2i] = []
var _path_index := 0
var _blocked_by := -1


func _ready() -> void:
	add_to_group("enemies")


func _process(delta: float) -> void:
	if _blocked_by != -1 or _path.is_empty():
		return
	var target_pos: Vector2 = get_map_manager().cell_to_world(_path[_path_index])
	global_position = global_position.move_toward(target_pos, float(cfg.get("move_speed", 1.0)) * 64.0 * delta)
	if global_position.distance_to(target_pos) < 2.0:
		current_cell = _path[_path_index]
		_path_index += 1
		if _path_index >= _path.size():
			get_enemy_manager().notify_enemy_reached_core(runtime_id)


func setup_from_cfg(new_enemy_id: StringName, new_cfg: Dictionary, spawn_cell: Vector2i) -> void:
	enemy_id = new_enemy_id
	cfg = new_cfg.duplicate(true)
	current_hp = int(cfg.get("max_hp", 1))
	current_cell = spawn_cell
	global_position = get_map_manager().cell_to_world(spawn_cell)
	recalc_path()
	var label := get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.text = String(cfg.get("name", enemy_id))


func receive_damage(value: int, _damage_type: int) -> void:
	current_hp = max(current_hp - value, 0)
	if current_hp == 0:
		get_enemy_manager().remove_enemy(runtime_id)


func get_runtime_id() -> int:
	return runtime_id


func get_current_cell() -> Vector2i:
	return current_cell


func recalc_path() -> void:
	var path_service := get_node_or_null("../../../Managers/PathService")
	var core_cell: Vector2i = get_map_manager().get_core_cell()
	if path_service != null:
		_path = path_service.find_path(current_cell, core_cell)
		_path_index = min(1, _path.size() - 1) if not _path.is_empty() else 0


func set_blocked(blocker_runtime_id: int) -> void:
	_blocked_by = blocker_runtime_id


func clear_blocked() -> void:
	_blocked_by = -1


func get_map_manager() -> Node:
	return get_node_or_null("../../../Managers/MapManager")


func get_enemy_manager() -> Node:
	return get_node_or_null("../../../Managers/EnemyManager")
