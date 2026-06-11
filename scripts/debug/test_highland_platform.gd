extends SceneTree

## 地形包阶段 A 回归：highland 地形语义 / debug 序列化 / 部署门控 / 人工高台建筑。
## 运行：Godot --headless --path . --script scripts/debug/test_highland_platform.gd

const CellDataScript = preload("res://scripts/map/cell_data.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_highland_semantics()
	await _test_debug_roundtrip()
	await _test_highland_deploy()
	await _test_artificial_platform()
	await _test_reveal_skips_gates()
	_finish()


func _test_highland_semantics() -> void:
	var data: CellData = CellDataScript.new()
	data.cell = Vector2i(3, 3)
	data.set_base_terrain(CellDataScript.TERRAIN_HIGHLAND)
	_expect(not data.walkable, "highland blocks enemies")
	_expect(not data.buildable, "highland not buildable")
	_expect(data.is_terrain_blocking(), "highland counts as blocking terrain")
	_expect(data.allows_ranged_deploy(), "highland allows ranged deploy")
	var plain: CellData = CellDataScript.new()
	plain.set_base_terrain(CellDataScript.TERRAIN_PLAIN)
	_expect(not plain.allows_ranged_deploy(), "plain is not a ranged-only platform")
	var mountain: CellData = CellDataScript.new()
	mountain.set_base_terrain(CellDataScript.TERRAIN_MOUNTAIN)
	_expect(not mountain.allows_ranged_deploy(), "mountain stays pure blocker")


func _test_debug_roundtrip() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var map_manager := game.get_node_or_null("Managers/MapManager")
	if map_manager == null:
		_expect(false, "boot ok for debug roundtrip")
		game.queue_free()
		await process_frame
		return
	# Seed-proof: find a plain cell not flagged as core or spawn.
	var target := Vector2i(-1, -1)
	var candidates: Array[Vector2i] = [
		Vector2i(10, 10), Vector2i(11, 10), Vector2i(12, 10),
		Vector2i(13, 10), Vector2i(14, 10), Vector2i(15, 10)
	]
	for raw_candidate: Variant in candidates:
		var c: Vector2i = raw_candidate
		if not map_manager.is_inside(c):
			continue
		var cd: CellData = map_manager.get_cell_data(c)
		if cd == null:
			continue
		if cd.is_core or cd.spawn_key != StringName():
			continue
		target = c
		break
	if target == Vector2i(-1, -1):
		_expect(false, "could not find a safe target cell for roundtrip test")
		game.queue_free()
		await process_frame
		return
	var data: CellData = map_manager.get_cell_data(target)
	data.set_base_terrain(CellDataScript.TERRAIN_HIGHLAND)
	var state: Dictionary = map_manager.get_debug_map_state()
	var highland_cells: Array = state.get("highland", [])
	var found := false
	for raw_cell: Variant in highland_cells:
		var arr: Array = raw_cell
		if int(arr[0]) == target.x and int(arr[1]) == target.y:
			found = true
	_expect(found, "debug state serializes highland cells")
	map_manager.apply_debug_map_state(state, map_manager.get_debug_spawn_defs())
	var restored: CellData = map_manager.get_cell_data(target)
	_expect(restored != null and restored.terrain == CellDataScript.TERRAIN_HIGHLAND, "debug state restores highland")
	game.queue_free()
	await process_frame


func _test_highland_deploy() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	var unit_manager := game.get_node_or_null("Managers/UnitManager")
	if run_state == null or map_manager == null or unit_manager == null:
		_expect(false, "boot ok for highland deploy")
		game.queue_free()
		await process_frame
		return
	var core: Vector2i = map_manager.get_core_cell()
	var highland_cell := Vector2i(core.x + 2, core.y)
	var cell_data: CellData = map_manager.get_cell_data(highland_cell)
	cell_data.resource_type = &""
	cell_data.set_base_terrain(CellDataScript.TERRAIN_HIGHLAND)
	var sniper_info: Dictionary = run_state.add_owned_operator(&"sniper_t1", "测试高台狙击")
	var sniper_key := StringName(sniper_info.get("key", ""))
	var guard_info: Dictionary = run_state.add_owned_operator(&"guard_t1", "测试高台近卫")
	var guard_key := StringName(guard_info.get("key", ""))
	var guard_result: Dictionary = unit_manager.try_deploy_operator(guard_key, highland_cell, Vector2i.RIGHT)
	_expect(not guard_result.get("ok", false), "melee rejected on highland")
	var sniper_result: Dictionary = unit_manager.try_deploy_operator(sniper_key, highland_cell, Vector2i.LEFT)
	_expect(sniper_result.get("ok", false), "ranged deploys on highland")
	var second_sniper_info: Dictionary = run_state.add_owned_operator(&"sniper_t1", "测试占位狙击")
	var second_sniper_key := StringName(second_sniper_info.get("key", ""))
	var stacked: Dictionary = unit_manager.try_deploy_operator(second_sniper_key, highland_cell, Vector2i.LEFT)
	_expect(not stacked.get("ok", false), "occupied highland rejects second deploy")
	var plain_cell := Vector2i(core.x - 2, core.y)
	var plain_data: CellData = map_manager.get_cell_data(plain_cell)
	plain_data.resource_type = &""
	plain_data.set_base_terrain(CellDataScript.TERRAIN_PLAIN)
	var plain_result: Dictionary = unit_manager.try_deploy_operator(second_sniper_key, plain_cell, Vector2i.RIGHT)
	_expect(plain_result.get("ok", false), "ranged still deploys on plain")
	game.queue_free()
	await process_frame


func _test_artificial_platform() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	var unit_manager := game.get_node_or_null("Managers/UnitManager")
	var building_manager := game.get_node_or_null("Managers/BuildingManager")
	if run_state == null or map_manager == null or unit_manager == null or building_manager == null:
		_expect(false, "boot ok for platform test")
		game.queue_free()
		await process_frame
		return
	var core: Vector2i = map_manager.get_core_cell()
	var platform_cell := Vector2i(core.x, core.y + 2)
	var platform_data: CellData = map_manager.get_cell_data(platform_cell)
	platform_data.resource_type = &""
	platform_data.set_base_terrain(CellDataScript.TERRAIN_PLAIN)
	run_state.add_materials(10, 10, 0)
	run_state.reset_action_points(30)
	var place_result: Dictionary = building_manager.try_place_building(platform_cell, &"artificial_platform")
	_expect(place_result.get("ok", false), "platform places on plain")
	var sniper_info: Dictionary = run_state.add_owned_operator(&"sniper_t1", "测试台上狙击")
	var sniper_key := StringName(sniper_info.get("key", ""))
	var deploy_result: Dictionary = unit_manager.try_deploy_operator(sniper_key, platform_cell, Vector2i.RIGHT)
	_expect(deploy_result.get("ok", false), "ranged deploys onto living platform")
	var other_cell := Vector2i(core.x, core.y - 2)
	var other_data: CellData = map_manager.get_cell_data(other_cell)
	other_data.resource_type = &""
	other_data.set_base_terrain(CellDataScript.TERRAIN_PLAIN)
	var place2: Dictionary = building_manager.try_place_building(other_cell, &"artificial_platform")
	_expect(place2.get("ok", false), "second platform places")
	var guard_info: Dictionary = run_state.add_owned_operator(&"guard_t1", "测试台上近卫")
	var guard_key := StringName(guard_info.get("key", ""))
	var guard_result: Dictionary = unit_manager.try_deploy_operator(guard_key, other_cell, Vector2i.RIGHT)
	_expect(not guard_result.get("ok", false), "melee rejected on platform")
	var platform_actor: Node = building_manager.get_building_by_cell(platform_cell)
	var platform_id: int = int(platform_actor.get_runtime_id())
	var demolish_occupied: Dictionary = building_manager.try_demolish_building(platform_id)
	_expect(not demolish_occupied.get("ok", false), "demolish rejected while occupied")
	# 白天移除按设计不进再部署冷却（_start_operator_redeploy 的 PHASE_DAY 早退）；
	# 塌台实战发生在夜晚，切到夜晚再摧毁以验证战斗阵亡语义。
	run_state.set_phase(GameEnums.PHASE_NIGHT)
	building_manager.damage_building(platform_id, 9999, GameEnums.DAMAGE_PHYSICAL)
	await process_frame
	_expect(map_manager.get_cell_data(platform_cell).unit_runtime_id < 0, "occupant removed when platform destroyed")
	_expect(unit_manager.is_operator_redeploying(sniper_key), "occupant died into redeploy cooldown")
	game.queue_free()
	await process_frame


func _test_reveal_skips_gates() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var map_manager := game.get_node_or_null("Managers/MapManager")
	if map_manager == null:
		_expect(false, "boot ok for reveal test")
		game.queue_free()
		await process_frame
		return
	var gate_cell: Vector2i = (map_manager.get_spawn_cells() as Array)[0]
	map_manager.reveal_area(gate_cell, 1)
	_expect(not map_manager.is_discovered(gate_cell), "reveal_area never discovers gate cells")
	var revealed_any := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var neighbor := gate_cell + Vector2i(dx, dy)
			if neighbor == gate_cell or not map_manager.is_inside(neighbor):
				continue
			if map_manager.is_discovered(neighbor):
				revealed_any = true
	_expect(revealed_any, "non-gate neighbors still revealed")
	game.queue_free()
	await process_frame


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("HIGHLAND PLATFORM TESTS PASSED")
		quit(0)
	else:
		printerr("HIGHLAND PLATFORM TESTS FAILED: %d" % _failures)
		quit(1)
