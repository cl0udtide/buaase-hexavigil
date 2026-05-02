extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const DEFAULT_RELIC_CHOICES := 3
const MAX_RELIC_CHOICES := 5
const RARITY_WEIGHTS := {
	1: 60.0,
	2: 30.0,
	3: 10.0
}


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
	return _draw_weighted_choices(pool, min(choice_count, pool.size()))


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
			"deploy_limit_add":
				run_state.set_deploy_limit(run_state.deploy_limit + int(effect.get("effect_value", 0)))
			"core_heal":
				run_state.heal_core(int(effect.get("effect_value", 0)))
			"core_max_hp_add":
				var value := int(effect.get("effect_value", 0))
				run_state.core_hp_max += value
				run_state.heal_core(value)
	return ActionResult.ok({"buff_id": buff_id}, "已获得遗物：%s" % String(cfg.get("name", buff_id)))


func has_buff(buff_id: StringName) -> bool:
	var run_state = AppRefs.run_state()
	return run_state != null and run_state.buffs.has(buff_id)


func get_all_buffs() -> Array[StringName]:
	var run_state = AppRefs.run_state()
	return run_state.buffs.duplicate() if run_state != null else []


func _draw_weighted_choices(pool: Array[StringName], count: int) -> Array[StringName]:
	var data_repo = AppRefs.data_repo()
	var remaining := pool.duplicate()
	var result: Array[StringName] = []
	while result.size() < count and not remaining.is_empty():
		var picked := _pick_weighted_relic(remaining, data_repo)
		if picked == StringName():
			break
		result.append(picked)
		remaining.erase(picked)
	return result


func _pick_weighted_relic(pool: Array[StringName], data_repo: Node) -> StringName:
	var total_weight := 0.0
	for buff_id in pool:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		total_weight += _get_relic_weight(cfg)
	if total_weight <= 0.0:
		return pool.pick_random()
	var roll := randf() * total_weight
	var cursor := 0.0
	for buff_id in pool:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		cursor += _get_relic_weight(cfg)
		if roll <= cursor:
			return buff_id
	return pool.back()


func _get_relic_weight(cfg: Dictionary) -> float:
	if cfg.has("weight"):
		return max(float(cfg.get("weight", 0.0)), 0.0)
	var rarity := int(cfg.get("rarity", 1))
	return float(RARITY_WEIGHTS.get(rarity, 10.0))


func _get_effect_entries(cfg: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if cfg.has("effects") and typeof(cfg.get("effects")) == TYPE_ARRAY:
		for raw_effect in cfg.get("effects", []):
			if typeof(raw_effect) == TYPE_DICTIONARY:
				result.append((raw_effect as Dictionary).duplicate(true))
	if result.is_empty() and cfg.has("effect_type"):
		result.append(cfg)
	return result
