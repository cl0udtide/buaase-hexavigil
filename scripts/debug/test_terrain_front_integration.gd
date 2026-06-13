extends SceneTree

## 地形正面推进集成回归（headless）：真 MapManager + PathService。
## 验证场从真地图构建（Phase2 接线）+ compute_coverage 覆盖面（Phase3）。
## 运行：/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/test_terrain_front_integration.gd

const MapManagerScript = preload("res://scripts/map/map_manager.gd")
const PathServiceScript = preload("res://scripts/map/path_service.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)


func _make(w: int, h: int, core: Vector2i, spawns: Dictionary) -> Dictionary:
	var managers := Node.new()
	managers.name = "Managers"
	get_root().add_child(managers)
	var mm = MapManagerScript.new()
	mm.name = "MapManager"
	managers.add_child(mm)
	var ps = PathServiceScript.new()
	ps.name = "PathService"
	managers.add_child(ps)
	mm.generate_debug_map(w, h, core, spawns, [], [])
	ps.rebuild_from_map()
	return {"managers": managers, "ps": ps}


func _run() -> void:
	print("[integration: 真 MapManager + PathService]")
	var open := _make(11, 7, Vector2i(10, 3), {"S1": Vector2i(0, 3)})
	var ps = open["ps"]
	_expect(ps.has_route(Vector2i(0, 3), &"normal"), "开阔: 出怪口有 normal 路")
	var d := int(ps.get_core_distance(Vector2i(0, 3), &"normal"))
	_expect(d == 10, "开阔: 距离 10 (同行 dx=10) (实 %d)" % d)
	var cov: Dictionary = ps.compute_coverage(Vector2i(0, 3), &"normal", 3)
	_expect(bool(cov["ok"]), "开阔: 覆盖 ok")
	var cov_n := (cov["coverage"] as Array).size()
	var center_n := (cov["centerline"] as Array).size()
	_expect(cov_n > center_n, "开阔: 覆盖面(%d) 宽于中心线(%d)" % [cov_n, center_n])
	(open["managers"] as Node).free()

	var corr := _make(11, 1, Vector2i(10, 0), {"S1": Vector2i(0, 0)})
	var ps2 = corr["ps"]
	var cov2: Dictionary = ps2.compute_coverage(Vector2i(0, 0), &"normal", 3)
	_expect(bool(cov2["ok"]), "走廊: 覆盖 ok")
	_expect((cov2["coverage"] as Array).size() == (cov2["centerline"] as Array).size(), "走廊: 覆盖=中心线(无横向余地)")
	(corr["managers"] as Node).free()

	if _failures == 0:
		print("ALL INTEGRATION TESTS PASSED")
	else:
		printerr("INTEGRATION FAILURES: %d" % _failures)
	quit(1 if _failures > 0 else 0)
