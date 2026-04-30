class_name BuildValidator
extends RefCounted

const AppRefs = preload("res://scripts/common/app_refs.gd")

var map_manager: Node


func can_place_building(cell: Vector2i, building_id: StringName) -> Dictionary:
	var data_repo = _get_data_repo()
	var run_state = _get_run_state()
	if data_repo == null or run_state == null:
		return ActionResult.err(&"APP_REFS_MISSING", "App refs are unavailable")

	var cfg: Dictionary = data_repo.get_building_cfg(building_id)
	if cfg.is_empty():
		return ActionResult.err(&"BUILDING_NOT_FOUND", "Building config was not found")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "Buildings can only be placed during the day")
	if map_manager == null or not map_manager.is_inside(cell):
		return ActionResult.err(&"OUT_OF_MAP", "Target cell is outside the map")
	if not map_manager.is_buildable(cell):
		return ActionResult.err(&"CELL_NOT_BUILDABLE", "Target cell cannot be built on")

	var cell_data: CellData = map_manager.get_cell_data(cell)
	if cell_data == null:
		return ActionResult.err(&"CELL_NOT_FOUND", "Target cell data is unavailable")

	var place_rule := StringName(cfg.get("place_rule", "plain_only"))
	var place_rule_result := _validate_place_rule(cell_data, place_rule)
	if not place_rule_result.get("ok", false):
		return place_rule_result

	if run_state.wood < int(cfg.get("cost_wood", 0)) or run_state.stone < int(cfg.get("cost_stone", 0)) or run_state.mana < int(cfg.get("cost_mana", 0)):
		return ActionResult.err(&"NOT_ENOUGH_MATERIALS", "Not enough materials")
	if run_state.action_points < int(cfg.get("ap_cost", 0)):
		return ActionResult.err(&"NOT_ENOUGH_AP", "Not enough action points")
	return ActionResult.ok()


func can_repair_building(_building_runtime_id: int) -> Dictionary:
	var run_state = _get_run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState is unavailable")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "Buildings can only be repaired during the day")
	return ActionResult.ok()


func _validate_place_rule(cell_data: CellData, place_rule: StringName) -> Dictionary:
	match place_rule:
		&"plain_only":
			if cell_data.resource_type != StringName():
				return ActionResult.err(&"PLACE_RULE_MISMATCH", "Requires a plain cell")
		&"wood_resource_only":
			if cell_data.resource_type != &"wood":
				return ActionResult.err(&"PLACE_RULE_MISMATCH", "Requires a wood resource cell")
		&"stone_resource_only":
			if cell_data.resource_type != &"stone":
				return ActionResult.err(&"PLACE_RULE_MISMATCH", "Requires a stone resource cell")
		&"mana_resource_only":
			if cell_data.resource_type != &"mana":
				return ActionResult.err(&"PLACE_RULE_MISMATCH", "Requires a mana resource cell")
		_:
			return ActionResult.err(&"UNKNOWN_PLACE_RULE", "Unknown place rule")
	return ActionResult.ok()


func _get_data_repo() -> Node:
	return AppRefs.data_repo()


func _get_run_state() -> Node:
	return AppRefs.run_state()
