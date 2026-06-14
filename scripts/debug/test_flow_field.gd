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
	_test_oscillation()
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
	# 开阔绕行：前进格被干员占 → 横向绕过（不走进去）
	var blocked_step: Dictionary = {Vector2i(1, 2): true}
	var around := FlowField.next_step(dist, front, Vector2i(0, 2), 0.5, 8, blocked_step)
	_expect(around != Vector2i(1, 2) and dist.has(around), "open: detours around occupied cell (got %s)" % str(around))
	# 窄口接敌：走廊前格被干员占、无横向可绕 → 照走进去（软避让兜底）
	_expect(FlowField.next_step(cdist, cfront, Vector2i(1, 0), 0.5, 8, {Vector2i(2, 0): true}) == Vector2i(2, 0), "choke: walks into blocker when no detour")


## 仿真：一只怪从 start 逐步走到 core，记录首次跨过 mid_x 时所在的行。
func _sim_enemy(dist: Dictionary, front: Dictionary, start: Vector2i, core: Vector2i, phase: float, half_width: int, mid_x: int) -> Dictionary:
	# 跟真控制器一致：把上一格作为软避让传入，防止被梯度拽回去左右摇摆。
	var cell := start
	var prev := Vector2i(-9999, -9999)
	var steps := 0
	var row_at_mid := -999
	while cell != core and steps < 300:
		if cell.x >= mid_x and row_at_mid == -999:
			row_at_mid = cell.y
		var extra := {}
		if prev != Vector2i(-9999, -9999):
			extra[prev] = true
		var nxt: Vector2i = FlowField.next_step(dist, front, cell, phase, half_width, extra)
		if nxt == cell:
			break
		prev = cell
		cell = nxt
		steps += 1
	if cell.x >= mid_x and row_at_mid == -999:
		row_at_mid = cell.y
	return {"reached": cell == core, "row_at_mid": row_at_mid}


func _sim_reaches(dist: Dictionary, front: Dictionary, start: Vector2i, core: Vector2i, phase: float, half_width: int, use_prev: bool) -> bool:
	var cell := start
	var prev := Vector2i(-9999, -9999)
	var steps := 0
	while cell != core and steps < 400:
		var extra := {}
		if use_prev and prev != Vector2i(-9999, -9999):
			extra[prev] = true
		var nxt: Vector2i = FlowField.next_step(dist, front, cell, phase, half_width, extra)
		if nxt == cell:
			break
		prev = cell
		cell = nxt
		steps += 1
	return cell == core


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


func _test_oscillation() -> void:
	print("[oscillation: 对角偏置场 '不回头' 修复]")
	# 核心右上、出怪口左下：对角偏置 + 大量梯度并列，最易触发"铺开后被拽回上一格"的摇摆。
	var core := Vector2i(10, 0)
	var gate := Vector2i(0, 6)
	var cells := _grid(11, 7)
	var dist: Dictionary = FlowField.compute_distance(cells, core, {})
	var front: Dictionary = FlowField.compute_front(cells, dist, {})
	var phases := _phases(8)
	var reached_prev := 0
	var reached_noprev := 0
	for p: float in phases:
		if _sim_reaches(dist, front, gate, core, float(p), 6, true):
			reached_prev += 1
		if _sim_reaches(dist, front, gate, core, float(p), 6, false):
			reached_noprev += 1
	_expect(reached_prev == phases.size(), "对角场 不回头: 全部到核心 (%d/%d)" % [reached_prev, phases.size()])
	_expect(reached_prev >= reached_noprev, "对角场 不回头不比无修复差 (prev %d vs noprev %d)" % [reached_prev, reached_noprev])
	# 带障碍：中间一道墙掰弯距离场，绕行"阴影区"最易触发回拽摇摆（更接近 live 地形）。
	var wall: Dictionary = {}
	for yy in [2, 3, 4]:
		wall[Vector2i(5, yy)] = true
	var wcore := Vector2i(10, 3)
	var wgate := Vector2i(0, 3)
	var wdist: Dictionary = FlowField.compute_distance(cells, wcore, wall)
	var wfront: Dictionary = FlowField.compute_front(cells, wdist, wall)
	var wphases := _phases(10)
	var w_prev := 0
	var w_noprev := 0
	for p2: float in wphases:
		if _sim_reaches(wdist, wfront, wgate, wcore, float(p2), 6, true):
			w_prev += 1
		if _sim_reaches(wdist, wfront, wgate, wcore, float(p2), 6, false):
			w_noprev += 1
	_expect(w_prev == wphases.size(), "带墙场 不回头: 全部到核心 (%d/%d)" % [w_prev, wphases.size()])
	_expect(w_prev >= w_noprev, "带墙场 不回头不比无修复差 (prev %d vs noprev %d)" % [w_prev, w_noprev])
	if w_noprev < w_prev:
		print("    （带墙场复现了摇摆：无修复仅 %d/%d 到核心，修复后 %d/%d）" % [w_noprev, wphases.size(), w_prev, wphases.size()])


func _test_determinism() -> void:
	print("[determinism]")
	var cells := _grid(5, 5)
	var a: Dictionary = FlowField.compute_distance(cells, Vector2i(2, 2), {})
	var b: Dictionary = FlowField.compute_distance(cells, Vector2i(2, 2), {})
	_expect(str(a) == str(b), "compute_distance deterministic")
	var fa: Dictionary = FlowField.compute_front(cells, a, {})
	var fb: Dictionary = FlowField.compute_front(cells, b, {})
	_expect(str(fa) == str(fb), "compute_front deterministic")
