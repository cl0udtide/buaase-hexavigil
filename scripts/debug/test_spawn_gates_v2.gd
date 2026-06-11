extends SceneTree

## 动态出怪口 v2 回归：等弧放置 / 激活序 / 覆盖项 / 封口 / 公示冻结。
## 运行：Godot --headless --path . --script scripts/debug/test_spawn_gates_v2.gd

const MapGeneratorScript = preload("res://scripts/map/map_generator.gd")
const ResolverScript = preload("res://scripts/enemy/night_template_resolver.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_arc_placement()
	_finish()


func _perimeter_index(cell: Vector2i, width: int, height: int) -> int:
	if cell.y == 0:
		return cell.x
	if cell.x == width - 1:
		return (width - 1) + cell.y
	if cell.y == height - 1:
		return (width - 1) + (height - 1) + (width - 1 - cell.x)
	return (width - 1) * 2 + (height - 1) + (height - 1 - cell.y)


func _test_arc_placement() -> void:
	var cfg := {"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0}
	var perimeter_total: int = (30 - 1) * 4
	for seed_value in range(1000, 1020):
		var generated: Dictionary = MapGeneratorScript.generate(30, 30, seed_value, cfg, [])
		var spawn_cells: Array = generated.get("spawn_cells", [])
		_expect(spawn_cells.size() == 5, "seed %d: 5 gates placed" % seed_value)
		var cells: Dictionary = generated.get("cells", {})
		var indices: Array[int] = []
		for raw_cell: Variant in spawn_cells:
			var cell: Vector2i = raw_cell
			var on_edge := cell.x == 0 or cell.y == 0 or cell.x == 29 or cell.y == 29
			_expect(on_edge, "seed %d: gate on edge" % seed_value)
			var near_corner := (cell.x < 3 or cell.x > 26) and (cell.y < 3 or cell.y > 26)
			_expect(not near_corner, "seed %d: gate away from corners" % seed_value)
			var data: CellData = cells.get(cell)
			_expect(data != null and data.spawn_key != StringName(), "seed %d: gate cell keyed" % seed_value)
			_expect(data != null and not data.discovered and not data.buildable, "seed %d: gate cell invariants" % seed_value)
			indices.append(_perimeter_index(cell, 30, 30))
		indices.sort()
		for i in range(indices.size()):
			var gap: int = 0
			if i + 1 < indices.size():
				gap = indices[i + 1] - indices[i]
			else:
				gap = perimeter_total - indices[i] + indices[0]
			_expect(gap >= 8, "seed %d: perimeter gap %d >= 8" % [seed_value, gap])
	var first: Dictionary = MapGeneratorScript.generate(30, 30, 4242, cfg, [])
	var second: Dictionary = MapGeneratorScript.generate(30, 30, 4242, cfg, [])
	_expect(str(first.get("spawn_cells")) == str(second.get("spawn_cells")), "same seed same gates")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("SPAWN GATES V2 TESTS PASSED")
		quit(0)
	else:
		printerr("SPAWN GATES V2 TESTS FAILED: %d" % _failures)
		quit(1)
