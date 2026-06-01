extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const DEFAULT_RELIC_CHOICES := 3
const MAX_RELIC_CHOICES := 5

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


func get_random_blessing_choices(count: int = 0) -> Array[StringName]:
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	var pool: Array[StringName] = []
	var all_buff_ids: Array[StringName] = data_repo.get_all_buff_ids() if data_repo != null else []
	for buff_id in all_buff_ids:
		if run_state != null and run_state.has_buff(buff_id):
			continue
		pool.append(buff_id)
	var choice_count := count
	if choice_count <= 0:
		choice_count = DEFAULT_RELIC_CHOICES
	choice_count = clamp(choice_count, 1, MAX_RELIC_CHOICES)
	return _draw_random_choices(pool, min(choice_count, pool.size()))


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
				for key in ["class_filter", "damage_type_filter", "building_type_filter", "material_filter", "condition"]:
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


func _on_unit_died(_unit_runtime_id: int, _unit_id: StringName, cell: Vector2i) -> void:
	for effect in _get_owned_effect_entries(&"unit_death_stun_radius"):
		var duration := float(effect.get("effect_value", 0.0))
		var radius := int(effect.get("radius", 0))
		if duration > 0.0 and radius > 0 and _enemy_manager != null and _enemy_manager.has_method("stun_enemies_in_radius"):
			_enemy_manager.stun_enemies_in_radius(cell, radius, duration)


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
