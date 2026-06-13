extends SceneTree

## 敌人距离场 + 正面结构回归（headless）。
## 运行：/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/test_flow_field.gd

const FlowField = preload("res://scripts/map/flow_field.gd")
const CellDataRef = preload("res://scripts/map/cell_data.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_distance_corridor()
	_test_front_open()
	_test_distance_wall()
	_test_next_step()
	_test_front_simulation()
	_test_determinism()
	if _failures == 0:
		print("ALL FLOW_FIELD TESTS PASSED")
	else:
		printerr("FLOW_FIELD FAILURES: %d" % _failures)
	quit(1 if _failures > 0 else 0)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)


# 矩形全可走格集
func _grid(w: int, h: int) -> Dictionary:
	var cells: Dictionary = {}
	for y in range(h):
		for x in range(w):
			var d = CellDataRef.new()
			d.cell = Vector2i(x, y)
			d.walkable = true
			cells[Vector2i(x, y)] = d
	return cells


func _test_distance_corridor() -> void:
	print("[distance: corridor 5x1]")
	var cells: Dictionary = {}
	for x in range(5):
		var d = CellDataRef.new()
		d.cell = Vector2i(x, 0)
		d.walkable = true
		cells[Vector2i(x, 0)] = d
	var dist: Dictionary = FlowField.compute_distance(cells, Vector2i(4, 0), {})
	_expect(int(dist.get(Vector2i(4, 0), -1)) == 0, "core dist 0")
	_expect(int(dist.get(Vector2i(0, 0), -1)) == 4, "far dist 4")
	var front: Dictionary = FlowField.compute_front(cells, dist, {})
	var f0: Dictionary = front.get(Vector2i(0, 0), {})
	_expect(int(f0.get("width", -1)) == 1, "corridor width 1")
	_expect(f0.get("g", Vector2i.ZERO) == Vector2i.RIGHT, "corridor g=RIGHT")
	_expect(abs(float(f0.get("frac", -1.0)) - 0.0) < 0.001, "corridor frac 0")


func _test_front_open() -> void:
	print("[front: open 5x5, core (2,2)]")
	var cells := _grid(5, 5)
	var dist: Dictionary = FlowField.compute_distance(cells, Vector2i(2, 2), {})
	_expect(int(dist.get(Vector2i(0, 0), -1)) == 4, "corner dist manhattan 4")
	var front: Dictionary = FlowField.compute_front(cells, dist, {})
	var mid: Dictionary = front.get(Vector2i(0, 2), {})
	_expect(int(mid.get("width", -1)) == 5, "left-mid front width 5 (full height)")
	_expect(abs(float(mid.get("frac", -1.0)) - 0.5) < 0.001, "left-mid frac 0.5")
	var corner: Dictionary = front.get(Vector2i(0, 0), {})
	_expect(abs(float(corner.get("frac", -1.0)) - 0.0) < 0.001, "corner frac 0 (top edge)")
	_expect(int(corner.get("width", -1)) == 5, "corner front width 5")


func _test_distance_wall() -> void:
	print("[distance: 5x3 with wall at (2,1)]")
	var cells := _grid(5, 3)
	var blocked: Dictionary = {Vector2i(2, 1): true}
	var dist: Dictionary = FlowField.compute_distance(cells, Vector2i(4, 1), blocked)
	_expect(not dist.has(Vector2i(2, 1)), "blocked cell absent from dist")
	_expect(dist.has(Vector2i(0, 1)), "left side still reachable around wall")
	# (3,1)->(4,1) 直接相邻=1；(0,1) 必须绕 y=0 或 y=2，>2
	_expect(int(dist.get(Vector2i(0, 1), -1)) > 2, "around-wall dist longer than straight")


func _test_next_step() -> void:
	print("[next_step: open 5x5 spreading]")
	var cells := _grid(5, 5)
	var dist: Dictionary = FlowField.compute_distance(cells, Vector2i(2, 2), {})
	var front: Dictionary = FlowField.compute_front(cells, dist, {})
	# 左中 (0,2)：phase 0 → 往上翼铺 (0,1)；phase 0.5 → 直接前进 (1,2)；phase 1 → 往下翼 (0,3)
	_expect(FlowField.next_step(dist, front, Vector2i(0, 2), 0.0, 8, {}) == Vector2i(0, 1), "phase0 spreads up")
	_expect(FlowField.next_step(dist, front, Vector2i(0, 2), 0.5, 8, {}) == Vector2i(1, 2), "phase0.5 goes forward")
	_expect(FlowField.next_step(dist, front, Vector2i(0, 2), 1.0, 8, {}) == Vector2i(0, 3), "phase1 spreads down")
	# 核心格：原地
	_expect(FlowField.next_step(dist, front, Vector2i(2, 2), 0.3, 8, {}) == Vector2i(2, 2), "at core stays")
	# 走廊：无论相位都只能前进
	var corridor: Dictionary = {}
	for x in range(5):
		var d = CellDataRef.new()
		d.cell = Vector2i(x, 0)
		d.walkable = true
		corridor[Vector2i(x, 0)] = d
	var cdist: Dictionary = FlowField.compute_distance(corridor, Vector2i(4, 0), {})
	var cfront: Dictionary = FlowField.compute_front(corridor, cdist, {})
	_expect(FlowField.next_step(cdist, cfront, Vector2i(0, 0), 0.2, 8, {}) == Vector2i(1, 0), "corridor only forward")
	# 绕行：前进格被占 → 改走未占的更低 dist 邻
	var blocked_step: Dictionary = {Vector2i(1, 2): true}
	var around := FlowField.next_step(dist, front, Vector2i(0, 2), 0.5, 8, blocked_step)
	_expect(around != Vector2i(1, 2) and dist.has(around), "detours around occupied forward cell")


## 仿真：一只怪从 start 逐步走到 core，记录首次跨过 mid_x 时所在的行。
func _sim_enemy(dist: Dictionary, front: Dictionary, start: Vector2i, core: Vector2i, phase: float, half_width: int, mid_x: int) -> Dictionary:
	var cell := start
	var steps := 0
	var row_at_mid := -999
	while cell != core and steps < 300:
		if cell.x >= mid_x and row_at_mid == -999:
			row_at_mid = cell.y
		var nxt: Vector2i = FlowField.next_step(dist, front, cell, phase, half_width, {})
		if nxt == cell:
			break
		cell = nxt
		steps += 1
	if cell.x >= mid_x and row_at_mid == -999:
		row_at_mid = cell.y
	return {"reached": cell == core, "row_at_mid": row_at_mid}


func _phases(n: int) -> Array:
	var out: Array = []
	for i in range(1, n + 1):
		out.append(fposmod(float(i) * 0.6180339887498949, 1.0))
	return out


func _test_front_simulation() -> void:
	print("[front simulation: 开阔铺面 / 走廊收拢 / 封顶]")
	var core := Vector2i(10, 3)
	var gate := Vector2i(0, 3)
	var mid_x := 5
	var cells := _grid(11, 7)
	var dist: Dictionary = FlowField.compute_distance(cells, core, {})
	var front: Dictionary = FlowField.compute_front(cells, dist, {})
	var phases := _phases(7)
	# 真实半宽（7 只 → 2）：铺开多行且都到核心
	var rows: Dictionary = {}
	var all_reached := true
	for p: float in phases:
		var r := _sim_enemy(dist, front, gate, core, float(p), 2, mid_x)
		all_reached = all_reached and bool(r["reached"])
		rows[r["row_at_mid"]] = true
	_expect(all_reached, "开阔图所有怪都到核心(half=2)")
	_expect(rows.size() >= 3, "正面在中段铺开 >=3 行(实得 %d)" % rows.size())
	# 封顶对比：half=8 比 half=0 铺得更宽
	var rows_wide: Dictionary = {}
	var rows_narrow: Dictionary = {}
	for p2: float in phases:
		rows_wide[_sim_enemy(dist, front, gate, core, float(p2), 8, mid_x)["row_at_mid"]] = true
		rows_narrow[_sim_enemy(dist, front, gate, core, float(p2), 0, mid_x)["row_at_mid"]] = true
	_expect(rows_wide.size() > rows_narrow.size(), "半宽越大铺越宽(%d > %d)" % [rows_wide.size(), rows_narrow.size()])
	_expect(rows_narrow.size() <= 2, "半宽0 退化成单股(实得 %d 行)" % rows_narrow.size())
	# 走廊：都收成一行、都到核心
	var ccells := _grid(11, 1)
	var ccore := Vector2i(10, 0)
	var cdist: Dictionary = FlowField.compute_distance(ccells, ccore, {})
	var cfront: Dictionary = FlowField.compute_front(ccells, cdist, {})
	var crows: Dictionary = {}
	var creached := true
	for p3: float in phases:
		var rc := _sim_enemy(cdist, cfront, Vector2i(0, 0), ccore, float(p3), 8, 5)
		creached = creached and bool(rc["reached"])
		crows[rc["row_at_mid"]] = true
	_expect(creached, "走廊所有怪都到核心")
	_expect(crows.size() == 1, "走廊收成单行(实得 %d)" % crows.size())


func _test_determinism() -> void:
	print("[determinism]")
	var cells := _grid(5, 5)
	var a: Dictionary = FlowField.compute_distance(cells, Vector2i(2, 2), {})
	var b: Dictionary = FlowField.compute_distance(cells, Vector2i(2, 2), {})
	_expect(str(a) == str(b), "compute_distance deterministic")
	var fa: Dictionary = FlowField.compute_front(cells, a, {})
	var fb: Dictionary = FlowField.compute_front(cells, b, {})
	_expect(str(fa) == str(fb), "compute_front deterministic")
