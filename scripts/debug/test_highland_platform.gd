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
