class_name BuildValidator
extends RefCounted

const AppRefs = preload("res://scripts/common/app_refs.gd")

var map_manager: Node
var path_service: Node


func can_place_building(cell: Vector2i, building_id: StringName, material_costs: Dictionary = {}) -> Dictionary:
	var data_repo = _get_data_repo()
	var run_state = _get_run_state()
	if data_repo == null or run_state == null:
		return ActionResult.err(&"APP_REFS_MISSING", "操作失败：运行时服务不可用")

	var cfg: Dictionary = data_repo.get_building_cfg(building_id)
	if cfg.is_empty():
		return ActionResult.err(&"BUILDING_NOT_FOUND", "建造失败：找不到建筑配置")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "无法建造：只有白天可以建造")
	if map_manager == null or not map_manager.is_inside(cell):
		return ActionResult.err(&"OUT_OF_MAP", "无法建造：目标格不在地图内")
	if not map_manager.is_buildable(cell):
		return ActionResult.err(&"CELL_NOT_BUILDABLE", "无法建造：目标格不可建造")

	var cell_data: CellData = map_manager.get_cell_data(cell)
	if cell_data == null:
		return ActionResult.err(&"CELL_NOT_FOUND", "操作失败：目标格数据不可用")

	var place_rule := StringName(cfg.get("place_rule", "plain_only"))
	var place_rule_result := _validate_place_rule(cell_data, place_rule)
	if not place_rule_result.get("ok", false):
		return place_rule_result

	var costs := material_costs if not material_costs.is_empty() else get_building_material_costs(cfg)
	if run_state.wood < int(costs.get("wood", 0)) or run_state.stone < int(costs.get("stone", 0)) or run_state.mana < int(costs.get("mana", 0)):
		return ActionResult.err(&"NOT_ENOUGH_MATERIALS", "资源不足：材料不足")
	if run_state.action_points < get_building_ap_cost(cfg):
		return ActionResult.err(&"NOT_ENOUGH_AP", "资源不足：行动力不足")
	if bool(cfg.get("blocks_path", false)):
		var path_result := _validate_path_after_block(cell)
		if not bool(path_result.get("ok", false)):
			return path_result
	return ActionResult.ok()


static func get_building_material_costs(cfg: Dictionary) -> Dictionary:
	return {
		"wood": get_building_material_cost(cfg, &"wood"),
		"stone": get_building_material_cost(cfg, &"stone"),
		"mana": get_building_material_cost(cfg, &"mana")
	}


static func get_building_material_cost(cfg: Dictionary, material: StringName) -> int:
	var key := "cost_%s" % String(material)
	var cost := int(cfg.get(key, 0))
	var run_state = AppRefs.run_state()
	if run_state != null:
		if run_state.has_method("get_buff_effect_total_for_building"):
			cost += int(round(float(run_state.get_buff_effect_total_for_building(&"building_cost_add", cfg))))
		if run_state.has_method("get_buff_effect_total_for_material"):
			cost += int(round(float(run_state.get_buff_effect_total_for_material(&"building_material_cost_add", material))))
	return max(cost, 0)


static func get_building_ap_cost(cfg: Dictionary) -> int:
	var cost := int(cfg.get("ap_cost", 0))
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_buff_effect_total_for_building"):
		cost += int(round(float(run_state.get_buff_effect_total_for_building(&"building_ap_cost_add", cfg))))
	return max(cost, 1)


func can_repair_building(_building_runtime_id: int) -> Dictionary:
	var run_state = _get_run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "操作失败：运行状态不可用")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "无法修复：只有白天可以修复")
	return ActionResult.ok()


func _validate_place_rule(cell_data: CellData, place_rule: StringName) -> Dictionary:
	match place_rule:
		&"plain_only":
			if cell_data.resource_type != StringName():
				return ActionResult.err(&"PLACE_RULE_MISMATCH", "无法建造：需要普通地块")
		&"wood_resource_only":
			if cell_data.resource_type != &"wood":
				return ActionResult.err(&"PLACE_RULE_MISMATCH", "无法建造：需要木材资源点")
		&"stone_resource_only":
			if cell_data.resource_type != &"stone":
				return ActionResult.err(&"PLACE_RULE_MISMATCH", "无法建造：需要石材资源点")
		&"mana_resource_only":
			if cell_data.resource_type != &"mana":
				return ActionResult.err(&"PLACE_RULE_MISMATCH", "无法建造：需要魔力资源点")
		_:
			return ActionResult.err(&"UNKNOWN_PLACE_RULE", "无法建造：未知放置规则")
	return ActionResult.ok()


func _validate_path_after_block(block_cell: Vector2i) -> Dictionary:
	if map_manager == null or path_service == null:
		return ActionResult.ok()
	if not path_service.has_method("find_path_preview"):
		return ActionResult.ok()
	var extra_blocked_cells: Dictionary = {block_cell: true}
	var core_cell: Vector2i = map_manager.get_core_cell()
	var blocked_spawns := PackedStringArray()
	for spawn_cell: Vector2i in map_manager.get_spawn_cells():
		var spawn_key := String(map_manager.get_spawn_key_at_cell(spawn_cell))
		var result: Dictionary = path_service.find_path_preview(spawn_cell, core_cell, &"normal", extra_blocked_cells)
		if not bool(result.get("ok", false)):
			blocked_spawns.append(spawn_key)
	if not blocked_spawns.is_empty():
		return ActionResult.err(&"PATH_BLOCKED", "该建筑会封死出怪点 " + "、".join(blocked_spawns) + " 到核心的路径")
	return ActionResult.ok()


func _get_data_repo() -> Node:
	return AppRefs.data_repo()


func _get_run_state() -> Node:
	return AppRefs.run_state()
