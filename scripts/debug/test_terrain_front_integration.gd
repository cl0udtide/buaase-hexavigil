extends SceneTree

## 地形正面推进集成回归（headless）：真 MapManager + PathService。
## 验证场从真地图构建（Phase2 接线）+ compute_coverage 覆盖面（Phase3）。
## 运行：/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/test_terrain_front_integration.gd

const MapManagerScript = preload("res://scripts/map/map_manager.gd")
const PathServiceScript = preload("res://scripts/map/path_service.gd")
const MapRootView = preload("res://scripts/map/map_root_view.gd")
const CellDataRef = preload("res://scripts/map/cell_data.gd")

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
	_expect(cov_n == center_n, "开阔同行: 真实候选不再虚扩覆盖(%d/%d)" % [cov_n, center_n])
	(open["managers"] as Node).free()

	var diagonal := _make(5, 5, Vector2i(4, 4), {"S1": Vector2i(0, 0)})
	var ps_diag = diagonal["ps"]
	var cov_diag: Dictionary = ps_diag.compute_coverage(Vector2i(0, 0), &"normal", 0)
	_expect(bool(cov_diag["ok"]), "开阔对角: 覆盖 ok")
	_expect((cov_diag["coverage"] as Array).size() > (cov_diag["centerline"] as Array).size(), "开阔对角: 真实候选覆盖多条等长路径")
	var cov_soft: Dictionary = ps_diag.compute_coverage(Vector2i(0, 0), &"normal", 0, {}, {Vector2i(1, 0): true})
	_expect(not (cov_soft["coverage"] as Array).has(Vector2i(1, 0)) and (cov_soft["coverage"] as Array).has(Vector2i(0, 1)), "软阻挡: 有等长空路时预览绕开")
	(diagonal["managers"] as Node).free()

	var demo := _make(5, 5, Vector2i(4, 4), {"S1": Vector2i(0, 0)})
	var ps_demo = demo["ps"]
	ps_demo.set_cell_blocked(Vector2i(1, 0), true)
	var cov_demo: Dictionary = ps_demo.compute_coverage(Vector2i(0, 0), &"demolisher", 0)
	_expect(not (cov_demo["coverage"] as Array).has(Vector2i(1, 0)) and (cov_demo["coverage"] as Array).has(Vector2i(0, 1)), "拆墙路径: 等长时优先无墙候选")
	(demo["managers"] as Node).free()

	var corr := _make(11, 1, Vector2i(10, 0), {"S1": Vector2i(0, 0)})
	var ps2 = corr["ps"]
	var cov2: Dictionary = ps2.compute_coverage(Vector2i(0, 0), &"normal", 3)
	_expect(bool(cov2["ok"]), "走廊: 覆盖 ok")
	_expect((cov2["coverage"] as Array).size() == (cov2["centerline"] as Array).size(), "走廊: 覆盖=中心线(无横向余地)")
	(corr["managers"] as Node).free()

	_test_fog_gate()

	if _failures == 0:
		print("ALL INTEGRATION TESTS PASSED")
	else:
		printerr("INTEGRATION FAILURES: %d" % _failures)
	quit(1 if _failures > 0 else 0)


## 出怪口穿透迷雾：未探索的出怪口格应显示出怪口贴图、而非迷雾，且 discovered 不变。
func _test_fog_gate() -> void:
	print("[fog: 出怪口穿透迷雾]")
	var view = MapRootView.new()
	var gate = CellDataRef.new()
	gate.spawn_key = &"S1"
	gate.discovered = false
	var gate_seen = CellDataRef.new()
	gate_seen.spawn_key = &"S1"
	gate_seen.discovered = true
	var plain = CellDataRef.new()
	plain.discovered = false
	var t_gate = view._get_cell_texture(gate)
	_expect(t_gate != MapRootView.TILE_HIDDEN, "未探索出怪口不再是迷雾贴图")
	_expect(t_gate == MapRootView.TILE_SPAWN, "未探索出怪口显示出怪口贴图")
	_expect(t_gate == view._get_cell_texture(gate_seen), "出怪口贴图与探索后一致")
	_expect(view._get_cell_texture(plain) == MapRootView.TILE_HIDDEN, "未探索普通格仍是迷雾")
	_expect(not gate.discovered, "出怪口 discovered 仍为 false（探索经济不变）")
	view.free()
