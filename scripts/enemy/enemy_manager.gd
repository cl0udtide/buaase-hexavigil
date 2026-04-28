extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")


var _next_runtime_id := 1
var _enemies_by_runtime_id: Dictionary = {}

@onready var _enemy_root: Node = get_node_or_null("../../World/EnemyRoot")


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.path_grid_changed.connect(_on_path_grid_changed)


func spawn_enemy(enemy_id: StringName, spawn_cell: Vector2i, cfg_override: Dictionary = {}) -> int:
	var data_repo = AppRefs.data_repo()
	var event_bus = AppRefs.event_bus()
	if data_repo == null:
		return -1
	var cfg: Dictionary = data_repo.get_enemy_cfg(enemy_id)
	for key in cfg_override.keys():
		cfg[key] = cfg_override[key]
	var scene: PackedScene = data_repo.get_scene_by_key(StringName(cfg.get("scene_key", "")))
	if scene == null:
		push_warning("Enemy scene missing for %s" % enemy_id)
		return -1
	if _enemy_root == null:
		push_warning("EnemyRoot node is missing")
		return -1
	var actor: Node = scene.instantiate()
	_enemy_root.add_child(actor)
	actor.runtime_id = _next_runtime_id
	if actor.has_method("setup_from_cfg"):
		actor.setup_from_cfg(enemy_id, cfg, spawn_cell)
	_enemies_by_runtime_id[_next_runtime_id] = actor
	if event_bus != null:
		event_bus.enemy_spawned.emit(_next_runtime_id, enemy_id, spawn_cell)
	_debug_log("生成敌人 %s#%d 于格子 %s" % [String(cfg.get("name", enemy_id)), _next_runtime_id, spawn_cell])
	_next_runtime_id += 1
	return _next_runtime_id - 1


func remove_enemy(enemy_runtime_id: int, defeated: bool = true) -> void:
	var enemy := get_enemy_by_runtime_id(enemy_runtime_id)
	if enemy == null:
		return
	var dead_enemy_id: StringName = enemy.enemy_id
	_enemies_by_runtime_id.erase(enemy_runtime_id)
	if defeated:
		_award_prestige_for_defeat(enemy)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.enemy_died.emit(enemy_runtime_id, dead_enemy_id)
	_debug_log("敌人离场 %s#%d" % [enemy.enemy_id, enemy_runtime_id])
	enemy.queue_free()


func get_enemy_by_runtime_id(enemy_runtime_id: int) -> Node:
	return _enemies_by_runtime_id.get(enemy_runtime_id)


func get_all_enemies() -> Array:
	return _enemies_by_runtime_id.values()


func get_alive_enemy_count() -> int:
	return _enemies_by_runtime_id.size()


func notify_enemy_reached_core(enemy_runtime_id: int) -> void:
	var enemy := get_enemy_by_runtime_id(enemy_runtime_id)
	if enemy == null:
		return
	var run_state = AppRefs.run_state()
	if run_state != null:
		run_state.damage_core(int(enemy.cfg.get("core_damage", 1)))
		_debug_log("敌人 %s#%d 抵达核心，核心受到 %d 点伤害，HP %d/%d" % [enemy.enemy_id, enemy_runtime_id, int(enemy.cfg.get("core_damage", 1)), run_state.core_hp, run_state.core_hp_max])
	remove_enemy(enemy_runtime_id, false)


func _on_path_grid_changed() -> void:
	for enemy in _enemies_by_runtime_id.values():
		if enemy.has_method("recalc_path"):
			enemy.recalc_path()


func clear_all_enemies() -> void:
	for enemy_runtime_id in _enemies_by_runtime_id.keys().duplicate():
		var enemy := get_enemy_by_runtime_id(int(enemy_runtime_id))
		if enemy != null:
			_enemies_by_runtime_id.erase(int(enemy_runtime_id))
			enemy.queue_free()


func _award_prestige_for_defeat(enemy: Node) -> void:
	var reward := int(enemy.cfg.get("prestige_reward", 0))
	if reward <= 0:
		return
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	run_state.add_prestige(reward)
	_debug_log("击杀敌人 %s#%d，获得 %d 声望" % [enemy.enemy_id, int(enemy.get_runtime_id()), reward])


func _debug_log(message: String) -> void:
	var tree := get_tree()
	if tree != null:
		tree.call_group("combat_debug_log", "append_combat_debug", message)
