class_name BuildValidator
extends RefCounted

const AppRefs = preload("res://scripts/common/app_refs.gd")


var map_manager: Node


func can_place_building(cell: Vector2i, building_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	if data_repo == null or run_state == null:
		return ActionResult.err(&"APP_REFS_MISSING", "全局单例尚未初始化")
	var cfg: Dictionary = data_repo.get_building_cfg(building_id)
	if cfg.is_empty():
		return ActionResult.err(&"BUILDING_NOT_FOUND", "找不到建筑配置")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以建造")
	if map_manager == null or not map_manager.is_inside(cell):
		return ActionResult.err(&"OUT_OF_MAP", "目标格子不在地图内")
	if not map_manager.is_buildable(cell):
		return ActionResult.err(&"CELL_NOT_BUILDABLE", "该格子不可建造")
	if run_state.wood < int(cfg.get("cost_wood", 0)) or run_state.stone < int(cfg.get("cost_stone", 0)) or run_state.mana < int(cfg.get("cost_mana", 0)):
		return ActionResult.err(&"NOT_ENOUGH_MATERIALS", "材料不足")
	if run_state.action_points < int(cfg.get("ap_cost", 0)):
		return ActionResult.err(&"NOT_ENOUGH_AP", "行动力不足")
	return ActionResult.ok()


func can_repair_building(_building_runtime_id: int) -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState 尚未初始化")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天可以修复")
	return ActionResult.ok()
