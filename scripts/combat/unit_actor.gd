extends Node2D

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")

const CELL_SIZE := 64.0
const BLOCK_RADIUS_TILES := 0.7071
const SKILL_BEHAVIOR_REGISTRY := {
	&"guard_hold_line": "res://scripts/combat/skills/guard_hold_line_skill.gd",
	&"sniper_burst_dawn": "res://scripts/combat/skills/sniper_burst_dawn_skill.gd"
}


var unit_id: StringName
var runtime_id := -1
var current_cell := Vector2i.ZERO
var facing := Vector2i.RIGHT
var cfg: Dictionary = {}
var max_hp := 1
var current_hp := 1
var sp := 0.0
var atk := 1
var defense := 0
var resistance := 0
var block_count := 0
var attack_interval := 1.0
var attack_multiplier := 1.0
var damage_type := GameEnums.DAMAGE_PHYSICAL
var target_type: StringName = &"ground"
var range_pattern: Array[Vector2i] = []

var _attack_timer := 0.0
var _blocked_enemy_ids: Array[int] = []
var _current_target_runtime_id := -1
var _is_dead := false

@onready var _status_view: Node = get_node_or_null("%StatusView")
@onready var _skill_behavior: Node = get_node_or_null("%SkillBehavior")


func _ready() -> void:
	add_to_group("units")


func _process(delta: float) -> void:
	if _is_dead:
		return
	# UnitActor 只保留公共战斗循环；角色特化技能通过 SkillBehavior 子节点接入。
	if _skill_behavior != null and _skill_behavior.has_method("tick"):
		_skill_behavior.tick(delta)
	_recover_sp(delta)
	_refresh_blocking()
	_tick_attack(delta)


func setup_from_cfg(new_unit_id: StringName, new_cfg: Dictionary, spawn_cell: Vector2i, new_facing: Vector2i) -> void:
	unit_id = new_unit_id
	cfg = new_cfg.duplicate(true)
	current_cell = spawn_cell
	facing = new_facing
	max_hp = int(cfg.get("max_hp", 1))
	current_hp = max_hp
	atk = int(cfg.get("atk", 1))
	defense = int(cfg.get("def", 0))
	resistance = int(cfg.get("res", 0))
	block_count = int(cfg.get("block", 0))
	attack_interval = max(float(cfg.get("attack_interval", 1.0)), 0.05)
	attack_multiplier = 1.0
	damage_type = parse_damage_type(String(cfg.get("damage_type", "physical")))
	target_type = StringName(cfg.get("target_type", "ground"))
	range_pattern = parse_range_pattern(cfg.get("range_pattern", []))
	sp = clamp(float(cfg.get("sp_initial", cfg.get("initial_sp", 0.0))), 0.0, float(cfg.get("sp_max", 0.0)))
	_attack_timer = attack_interval
	_blocked_enemy_ids.clear()
	_current_target_runtime_id = -1
	_is_dead = false
	global_position = get_map_manager().cell_to_world(spawn_cell) if get_map_manager() != null else Vector2.ZERO
	var label := get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.theme = AppTheme.get_theme()
		label.text = String(cfg.get("name", unit_id))
		label.position = Vector2(-36.0, -58.0)
	_configure_skill_behavior()
	if _skill_behavior != null and _skill_behavior.has_method("setup"):
		_skill_behavior.setup(self)
	_update_status_view()


func receive_damage(value: int, damage_type_value: int) -> void:
	var final_damage := value
	if damage_type_value == GameEnums.DAMAGE_PHYSICAL:
		final_damage = CombatMath.calc_physical_damage(value, defense)
	elif damage_type_value == GameEnums.DAMAGE_MAGIC:
		final_damage = CombatMath.calc_magic_damage(value, resistance)
	current_hp = max(current_hp - final_damage, 0)
	_update_status_view()
	_play_hit_effect()
	_debug_log("单位 %s#%d 受到%s伤害：原始 %d，结算 %d，HP %d/%d" % [_debug_name(), runtime_id, _damage_type_text(damage_type_value), value, final_damage, current_hp, max_hp])
	if current_hp == 0 and not _is_dead:
		_is_dead = true
		_debug_log("单位 %s#%d 死亡" % [_debug_name(), runtime_id])
		var unit_manager := get_unit_manager()
		if unit_manager != null and unit_manager.has_method("remove_unit"):
			unit_manager.remove_unit(runtime_id, GameEnums.UNIT_REMOVE_DEAD)


func receive_heal(value: int) -> void:
	if _is_dead:
		return
	current_hp = min(current_hp + value, max_hp)
	_update_status_view()


func gain_sp(value: int) -> void:
	sp = min(sp + value, float(cfg.get("sp_max", 0)))


func can_cast_skill() -> bool:
	if _skill_behavior != null and _skill_behavior.has_method("can_cast"):
		return bool(_skill_behavior.can_cast())
	var sp_max := float(cfg.get("sp_max", 0.0))
	return sp_max > 0.0 and sp >= sp_max


func cast_skill() -> void:
	if not can_cast_skill():
		return
	var skill_name := get_skill_name()
	var cast_ok := false
	if _skill_behavior != null and _skill_behavior.has_method("cast"):
		cast_ok = bool(_skill_behavior.cast())
	else:
		sp = 0.0
		cast_ok = true
	if cast_ok:
		_debug_log("单位 %s#%d 释放技能：%s" % [_debug_name(), runtime_id, skill_name])


func get_skill_name() -> String:
	if _skill_behavior != null and _skill_behavior.has_method("get_skill_name"):
		return String(_skill_behavior.get_skill_name())
	return String(cfg.get("skill_name", cfg.get("skill_id", "未配置技能")))


func get_skill_description() -> String:
	if _skill_behavior != null and _skill_behavior.has_method("get_skill_description"):
		return String(_skill_behavior.get_skill_description())
	return String(cfg.get("skill_description", "暂无技能描述。"))


func get_skill_active_remaining() -> float:
	if _skill_behavior != null and _skill_behavior.has_method("get_active_remaining"):
		return float(_skill_behavior.get_active_remaining())
	return 0.0


func get_runtime_id() -> int:
	return runtime_id


func get_current_cell() -> Vector2i:
	return current_cell


func get_block_count() -> int:
	return block_count


func get_attack_targets() -> Array:
	var targets: Array = []
	for enemy in get_all_enemies():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if _blocked_enemy_ids.has(enemy.get_runtime_id()):
			targets.append(enemy)
			continue
		if _is_enemy_in_attack_range(enemy):
			targets.append(enemy)
	return targets


func get_current_target() -> Node:
	var enemy_manager := get_enemy_manager()
	return enemy_manager.get_enemy_by_runtime_id(_current_target_runtime_id) if enemy_manager != null else null


func get_sp_ratio() -> float:
	var sp_max := float(cfg.get("sp_max", 0.0))
	return sp / sp_max if sp_max > 0.0 else 0.0


func get_redeploy_sec() -> float:
	return float(cfg.get("redeploy_sec", 0.0))


func get_blocked_enemy_ids() -> Array[int]:
	return _blocked_enemy_ids.duplicate()


func get_blocked_enemies() -> Array:
	var enemies: Array = []
	var enemy_manager := get_enemy_manager()
	if enemy_manager == null:
		return enemies
	for enemy_runtime_id in _blocked_enemy_ids:
		var enemy = enemy_manager.get_enemy_by_runtime_id(enemy_runtime_id)
		if enemy != null and is_instance_valid(enemy):
			enemies.append(enemy)
	return enemies


func get_all_enemies() -> Array:
	var enemy_manager := get_enemy_manager()
	if enemy_manager == null or not enemy_manager.has_method("get_all_enemies"):
		return []
	return enemy_manager.get_all_enemies()


func release_all_blocked_enemies() -> void:
	var enemy_manager := get_enemy_manager()
	for enemy_runtime_id in _blocked_enemy_ids:
		var enemy = enemy_manager.get_enemy_by_runtime_id(enemy_runtime_id) if enemy_manager != null else null
		if enemy != null and enemy.has_method("get_blocker_runtime_id") and enemy.get_blocker_runtime_id() == runtime_id:
			_debug_log("单位 %s#%d 解除阻挡敌人 %s#%d" % [_debug_name(), runtime_id, enemy.enemy_id, enemy_runtime_id])
			enemy.clear_blocked()
	_blocked_enemy_ids.clear()


func get_effective_atk() -> int:
	var run_state = AppRefs.run_state()
	var buff_multiplier := 1.0
	if run_state != null and run_state.has_method("get_buff_effect_total"):
		buff_multiplier += float(run_state.get_buff_effect_total(&"unit_atk_percent"))
	return max(int(round(float(atk) * buff_multiplier * attack_multiplier)), 1)


func get_map_manager() -> Node:
	return get_node_or_null("../../../Managers/MapManager")


func get_unit_manager() -> Node:
	return get_node_or_null("../../../Managers/UnitManager")


func get_enemy_manager() -> Node:
	return get_node_or_null("../../../Managers/EnemyManager")


func _configure_skill_behavior() -> void:
	var behavior_key := StringName(cfg.get("skill_behavior_key", cfg.get("skill_id", "")))
	if behavior_key == StringName():
		return
	if _skill_behavior != null and _skill_behavior.get_script() != null:
		return
	var script_path := String(SKILL_BEHAVIOR_REGISTRY.get(behavior_key, ""))
	if script_path.is_empty() or not ResourceLoader.exists(script_path):
		push_warning("Missing skill behavior script for %s: %s" % [unit_id, behavior_key])
		return
	if _skill_behavior == null:
		_skill_behavior = Node.new()
		_skill_behavior.name = "SkillBehavior"
		_skill_behavior.unique_name_in_owner = true
		add_child(_skill_behavior)
	var behavior_script := load(script_path) as Script
	if behavior_script == null:
		push_warning("Failed to load skill behavior script: %s" % script_path)
		return
	_skill_behavior.set_script(behavior_script)


func _recover_sp(delta: float) -> void:
	var recover_per_sec := float(cfg.get("sp_recover_per_sec", 0.0))
	var sp_max := float(cfg.get("sp_max", 0.0))
	if _skill_behavior != null:
		if _skill_behavior.has_method("get_sp_recover_per_sec"):
			recover_per_sec = float(_skill_behavior.get_sp_recover_per_sec())
		if _skill_behavior.has_method("get_sp_max"):
			sp_max = float(_skill_behavior.get_sp_max())
	sp = min(sp + recover_per_sec * delta, sp_max)


func _update_status_view() -> void:
	if _status_view != null and _status_view.has_method("set_hp"):
		_status_view.set_hp(current_hp, max_hp)


func _play_hit_effect() -> void:
	if _status_view != null and _status_view.has_method("play_hit_effect"):
		_status_view.play_hit_effect()


func _tick_attack(delta: float) -> void:
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return
	var override_targets: Array = []
	if _skill_behavior != null and _skill_behavior.has_method("get_attack_targets_override"):
		override_targets = _skill_behavior.get_attack_targets_override()
	if not override_targets.is_empty():
		for enemy in override_targets:
			_attack_target(enemy, false)
		gain_sp(int(cfg.get("sp_gain_on_attack", 0)))
		_attack_timer = attack_interval
		return
	var target := _select_attack_target()
	if target == null:
		return
	_attack_target(target)
	_attack_timer = attack_interval


func _attack_target(target: Node, gain_sp_on_attack: bool = true) -> void:
	if target == null or not is_instance_valid(target):
		return
	_current_target_runtime_id = target.get_runtime_id()
	var damage_value := get_effective_atk()
	_debug_log("单位 %s#%d 攻击敌人 %s#%d，%s伤害 %d" % [_debug_name(), runtime_id, target.enemy_id, target.get_runtime_id(), _damage_type_text(damage_type), damage_value])
	if target.has_method("receive_damage"):
		target.receive_damage(damage_value, damage_type)
	if _skill_behavior != null and _skill_behavior.has_method("after_attack"):
		_skill_behavior.after_attack(target, damage_value)
	if gain_sp_on_attack:
		gain_sp(int(cfg.get("sp_gain_on_attack", 0)))


func _select_attack_target() -> Node:
	var best_target: Node = null
	for enemy in get_attack_targets():
		if best_target == null or _is_enemy_higher_priority(enemy, best_target):
			best_target = enemy
	_current_target_runtime_id = best_target.get_runtime_id() if best_target != null else -1
	return best_target


func _is_enemy_higher_priority(a: Node, b: Node) -> bool:
	var a_blocked_by_self := _blocked_enemy_ids.has(a.get_runtime_id())
	var b_blocked_by_self := _blocked_enemy_ids.has(b.get_runtime_id())
	if a_blocked_by_self != b_blocked_by_self:
		return a_blocked_by_self
	var a_progress := float(a.get_path_progress_score()) if a.has_method("get_path_progress_score") else 0.0
	var b_progress := float(b.get_path_progress_score()) if b.has_method("get_path_progress_score") else 0.0
	if not is_equal_approx(a_progress, b_progress):
		return a_progress > b_progress
	var map_manager := get_map_manager()
	if map_manager != null:
		var core_cell: Vector2i = map_manager.get_core_cell()
		var a_cell: Vector2i = a.get_current_cell()
		var b_cell: Vector2i = b.get_current_cell()
		var a_dist: int = a_cell.distance_squared_to(core_cell)
		var b_dist: int = b_cell.distance_squared_to(core_cell)
		if a_dist != b_dist:
			return a_dist < b_dist
	return a.get_runtime_id() < b.get_runtime_id()


func _refresh_blocking() -> void:
	var enemy_manager := get_enemy_manager()
	if enemy_manager == null:
		_blocked_enemy_ids.clear()
		return
	var removed_block := false
	for enemy_runtime_id in _blocked_enemy_ids.duplicate():
		var enemy = enemy_manager.get_enemy_by_runtime_id(enemy_runtime_id)
		if enemy == null or not _can_keep_blocking(enemy):
			_blocked_enemy_ids.erase(enemy_runtime_id)
			removed_block = true
			if enemy != null and enemy.has_method("get_blocker_runtime_id") and enemy.get_blocker_runtime_id() == runtime_id:
				_debug_log("单位 %s#%d 解除阻挡敌人 %s#%d" % [_debug_name(), runtime_id, enemy.enemy_id, enemy_runtime_id])
				enemy.clear_blocked()
	if removed_block:
		_sync_block_slots()
	if block_count <= 0:
		return
	# 阻挡与朝向无关：敌人进入单位中心附近的阻挡半径后，按距离最近优先接敌。
	var used_block := _get_used_block_count()
	for enemy in _collect_block_candidates():
		if used_block >= block_count:
			return
		var block_weight := _get_enemy_block_weight(enemy)
		if used_block + block_weight > block_count:
			continue
		enemy.set_blocked(runtime_id)
		_blocked_enemy_ids.append(enemy.get_runtime_id())
		used_block += block_weight
		_debug_log("单位 %s#%d 阻挡敌人 %s#%d，当前阻挡 %d/%d" % [_debug_name(), runtime_id, enemy.enemy_id, enemy.get_runtime_id(), used_block, block_count])
		_sync_block_slots()


func _can_keep_blocking(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if _is_enemy_unblockable(enemy):
		return false
	if enemy.has_method("get_blocker_runtime_id") and enemy.get_blocker_runtime_id() != runtime_id:
		return false
	return _is_enemy_within_block_radius(enemy)


func _can_start_blocking(enemy: Node) -> bool:
	if block_count <= 0:
		return false
	if enemy == null or not is_instance_valid(enemy):
		return false
	if _blocked_enemy_ids.has(enemy.get_runtime_id()):
		return false
	if _is_enemy_unblockable(enemy):
		return false
	if not _is_enemy_within_block_radius(enemy):
		return false
	if enemy.has_method("get_blocker_runtime_id"):
		var blocker_runtime_id: int = enemy.get_blocker_runtime_id()
		if blocker_runtime_id != -1 and blocker_runtime_id != runtime_id:
			return false
	return true


func _collect_block_candidates() -> Array:
	var candidates: Array = []
	for enemy in get_all_enemies():
		if _can_start_blocking(enemy):
			_insert_block_candidate(candidates, enemy)
	return candidates


func _insert_block_candidate(candidates: Array, enemy: Node) -> void:
	for index in range(candidates.size()):
		if _compare_block_candidates(enemy, candidates[index]):
			candidates.insert(index, enemy)
			return
	candidates.append(enemy)


func _compare_block_candidates(a: Node, b: Node) -> bool:
	var a_dist: float = global_position.distance_squared_to(a.global_position)
	var b_dist: float = global_position.distance_squared_to(b.global_position)
	if not is_equal_approx(a_dist, b_dist):
		return a_dist < b_dist
	return _is_enemy_higher_priority(a, b)


func _get_used_block_count() -> int:
	var used := 0
	var enemy_manager := get_enemy_manager()
	for enemy_runtime_id in _blocked_enemy_ids:
		var enemy = enemy_manager.get_enemy_by_runtime_id(enemy_runtime_id) if enemy_manager != null else null
		if enemy != null:
			used += _get_enemy_block_weight(enemy)
	return used


func _get_enemy_block_weight(enemy: Node) -> int:
	if enemy == null:
		return 1
	return max(int(enemy.cfg.get("block_weight", enemy.cfg.get("block_cost", 1))), 1)


func _is_enemy_unblockable(enemy: Node) -> bool:
	return enemy != null and bool(enemy.cfg.get("unblockable", false))


func _is_enemy_within_block_radius(enemy: Node) -> bool:
	var radius := float(cfg.get("block_radius_tiles", BLOCK_RADIUS_TILES)) * CELL_SIZE
	return global_position.distance_to(enemy.global_position) <= radius


func _sync_block_slots() -> void:
	var enemy_manager := get_enemy_manager()
	var slot_count := _blocked_enemy_ids.size()
	if enemy_manager == null or slot_count <= 0:
		return
	for index in range(slot_count):
		var enemy = enemy_manager.get_enemy_by_runtime_id(_blocked_enemy_ids[index])
		if enemy != null and enemy.has_method("set_blocked"):
			enemy.set_blocked(runtime_id, index, slot_count)


func _is_enemy_in_attack_range(enemy: Node) -> bool:
	var enemy_cell: Vector2i = enemy.get_current_cell()
	var relative: Vector2i = enemy_cell - current_cell
	for offset in range_pattern:
		if _rotate_offset(offset, facing) == relative:
			return true
	return false


func parse_range_pattern(raw_pattern: Variant) -> Array[Vector2i]:
	var parsed: Array[Vector2i] = []
	if typeof(raw_pattern) != TYPE_ARRAY:
		return parsed
	for entry: Variant in raw_pattern:
		if typeof(entry) == TYPE_ARRAY and (entry as Array).size() >= 2:
			var pair := entry as Array
			parsed.append(Vector2i(int(pair[0]), int(pair[1])))
		elif entry is Vector2i:
			parsed.append(entry)
	return parsed


func parse_damage_type(raw_type: String) -> int:
	match raw_type:
		"magic":
			return GameEnums.DAMAGE_MAGIC
		"true":
			return GameEnums.DAMAGE_TRUE
		_:
			return GameEnums.DAMAGE_PHYSICAL


func _rotate_offset(offset: Vector2i, direction: Vector2i) -> Vector2i:
	# range_pattern 默认按“向右”书写，这里根据单位朝向旋转格子偏移。
	var normalized := _normalize_direction(direction)
	if normalized == Vector2i.LEFT:
		return Vector2i(-offset.x, -offset.y)
	if normalized == Vector2i.UP:
		return Vector2i(offset.y, -offset.x)
	if normalized == Vector2i.DOWN:
		return Vector2i(-offset.y, offset.x)
	return offset


func _normalize_direction(direction: Vector2i) -> Vector2i:
	if abs(direction.x) >= abs(direction.y):
		return Vector2i.RIGHT if direction.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0 else Vector2i.UP


func _debug_log(message: String) -> void:
	var tree := get_tree()
	if tree != null:
		tree.call_group("combat_debug_log", "append_combat_debug", message)


func _debug_name() -> String:
	return String(cfg.get("name", unit_id))


func _damage_type_text(type_value: int) -> String:
	match type_value:
		GameEnums.DAMAGE_MAGIC:
			return "法术"
		GameEnums.DAMAGE_TRUE:
			return "真实"
		_:
			return "物理"
