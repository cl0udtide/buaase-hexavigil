extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")


func get_random_blessing_choices(count: int = 3) -> Array[StringName]:
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	var pool: Array[StringName] = []
	var all_buff_ids: Array[StringName] = data_repo.get_all_buff_ids() if data_repo != null else []
	for buff_id in all_buff_ids:
		if run_state != null and run_state.has_buff(buff_id):
			continue
		pool.append(buff_id)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))


func apply_blessing(buff_id: StringName) -> Dictionary:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null:
		return ActionResult.err(&"APP_REFS_MISSING", "全局单例尚未初始化")
	if run_state.buffs.has(buff_id):
		return ActionResult.err(&"BUFF_EXISTS", "该祝福已经拥有")
	var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
	if cfg.is_empty():
		return ActionResult.err(&"BUFF_NOT_FOUND", "找不到该祝福配置")
	run_state.add_buff(buff_id)
	match String(cfg.get("effect_type", "")):
		"deploy_limit_add":
			run_state.set_deploy_limit(run_state.deploy_limit + int(cfg.get("effect_value", 0)))
		"core_heal":
			run_state.heal_core(int(cfg.get("effect_value", 0)))
	return ActionResult.ok({"buff_id": buff_id}, "已获得祝福：%s" % String(cfg.get("name", buff_id)))


func has_buff(buff_id: StringName) -> bool:
	var run_state = AppRefs.run_state()
	return run_state != null and run_state.buffs.has(buff_id)


func get_all_buffs() -> Array[StringName]:
	var run_state = AppRefs.run_state()
	return run_state.buffs.duplicate() if run_state != null else []
