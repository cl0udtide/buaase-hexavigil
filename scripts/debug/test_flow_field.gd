extends SceneTree

## 敌人距离场 + 纯单调下行回归（headless）。
## 运行：/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/test_flow_field.gd

const FlowField = preload("res://scripts/map/flow_field.gd")
const CellDataRef = preload("res://scripts/map/cell_data.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_distance()
	_test_front()
	_test_descend_basic()
	_test_descend_choices()
	_test_descend_spread()
	_test_mono_reaches()
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


func _grid(w: int, h: int) -> Dictionary:
	var cells: Dictionary = {}
	for y in range(h):
		for x in range(w):
			var d = CellDataRef.new()
			d.cell = Vector2i(x, y)
			d.walkable = true
			cells[Vector2i(x, y)] = d
	return cells


func _phases(n: int) -> Array:
	var out: Array = []
	for i in range(1, n + 1):
		out.append(fposmod(float(i) * 0.6180339887498949, 1.0))
	return out


func _test_distance() -> void:
	print("[distance]")
	# 走廊 5x1
	var corr: Dictionary = {}
	for x in range(5):
		var d = CellDataRef.new()
		d.cell = Vector2i(x, 0)
		d.walkable = true
		corr[Vector2i(x, 0)] = d
	var cd: Dictionary = FlowField.compute_distance(corr, Vector2i(4, 0), {})
	_expect(int(cd.get(Vector2i(4, 0), -1)) == 0, "走廊 核心 dist 0")
	_expect(int(cd.get(Vector2i(0, 0), -1)) == 4, "走廊 远端 dist 4")
	# 开阔 5x5
	var od: Dictionary = FlowField.compute_distance(_grid(5, 5), Vector2i(2, 2), {})
	_expect(int(od.get(Vector2i(0, 0), -1)) == 4, "开阔 角 dist 曼哈顿 4")
	# 带墙 5x3
	var wd: Dictionary = FlowField.compute_distance(_grid(5, 3), Vector2i(4, 1), {Vector2i(2, 1): true})
	_expect(not wd.has(Vector2i(2, 1)), "墙格不入 dist")
	_expect(int(wd.get(Vector2i(0, 1), -1)) > 2, "绕墙 dist 比直线长")


func _test_front() -> void:
	print("[front: g / axis]")
	var corr: Dictionary = {}
	for x in range(5):
		var d = CellDataRef.new()
		d.cell = Vector2i(x, 0)
		d.walkable = true
		corr[Vector2i(x, 0)] = d
	var cd: Dictionary = FlowField.compute_distance(corr, Vector2i(4, 0), {})
	var cf: Dictionary = FlowField.compute_front(corr, cd, {})
	_expect((cf.get(Vector2i(0, 0), {}) as Dictionary).get("g", Vector2i.ZERO) == Vector2i.RIGHT, "走廊 g=RIGHT")
	var cells := _grid(5, 5)
	var od: Dictionary = FlowField.compute_distance(cells, Vector2i(2, 2), {})
	var of: Dictionary = FlowField.compute_front(cells, od, {})
	var f02: Dictionary = of.get(Vector2i(0, 2), {})
	_expect(f02.get("g", Vector2i.ZERO) == Vector2i.RIGHT, "开阔(0,2) g=RIGHT")
	_expect(f02.get("axis", Vector2i.ZERO) == Vector2i.DOWN, "开阔(0,2) 横向轴=DOWN")


func _test_descend_basic() -> void:
	print("[descend: 基本]")
	var corr: Dictionary = {}
	for x in range(5):
		var d = CellDataRef.new()
		d.cell = Vector2i(x, 0)
		d.walkable = true
		corr[Vector2i(x, 0)] = d
	var cd: Dictionary = FlowField.compute_distance(corr, Vector2i(4, 0), {})
	var cf: Dictionary = FlowField.compute_front(corr, cd, {})
	_expect(FlowField.descend_step(cd, cf, Vector2i(0, 0), 0.3, {}) == Vector2i(1, 0), "走廊 只能前进")
	_expect(FlowField.descend_step(cd, cf, Vector2i(4, 0), 0.3, {}) == Vector2i(4, 0), "核心 原地")
	# 干员软避让：开阔对角处有两个下行邻，其一被占 → 绕另一个
	var cells := _grid(5, 5)
	var od: Dictionary = FlowField.compute_distance(cells, Vector2i(4, 4), {})
	var of: Dictionary = FlowField.compute_front(cells, od, {})
	var around := FlowField.descend_step(od, of, Vector2i(0, 0), 0.0, {Vector2i(1, 0): true})
	_expect(around != Vector2i(1, 0) and od.has(around), "下行邻之一被占 → 绕另一个(得 %s)" % str(around))


func _test_descend_choices() -> void:
	print("[descend: 候选]")
	var cells := _grid(5, 5)
	var dist: Dictionary = FlowField.compute_distance(cells, Vector2i(4, 4), {})
	var front: Dictionary = FlowField.compute_front(cells, dist, {})
	var choices: Array[Vector2i] = FlowField.descend_choices(dist, front, Vector2i(0, 0), {})
	_expect(choices.size() == 2 and choices.has(Vector2i(1, 0)) and choices.has(Vector2i(0, 1)), "开阔对角有两个真实下行候选")
	var avoid_wall: Array[Vector2i] = FlowField.descend_choices(dist, front, Vector2i(0, 0), {Vector2i(1, 0): true})
	_expect(avoid_wall.size() == 1 and avoid_wall[0] == Vector2i(0, 1), "候选之一软阻挡 → 只保留未阻挡候选")
	var all_blocked: Array[Vector2i] = FlowField.descend_choices(dist, front, Vector2i(0, 0), {Vector2i(1, 0): true, Vector2i(0, 1): true})
	_expect(all_blocked.size() == 2, "全部候选软阻挡 → 保留全部以便窄口接敌/拆墙")
	var priority: Array[Vector2i] = FlowField.descend_choices(dist, front, Vector2i(0, 0), {Vector2i(1, 0): 2, Vector2i(0, 1): 1})
	_expect(priority.size() == 1 and priority[0] == Vector2i(0, 1), "软阻挡分级: 同长时干员/空路优先于墙")


func _test_descend_spread() -> void:
	print("[descend: 分流铺开]")
	# 带墙分叉图：怪绕墙时分到上/下多路（纯开阔对角是已知最窄=2 边路，真图均值~9 见 mass_test）
	var cells := _grid(11, 7)
	var blocked := {Vector2i(5, 2): true, Vector2i(5, 3): true, Vector2i(5, 4): true}
	var dist: Dictionary = FlowField.compute_distance(cells, Vector2i(10, 3), blocked)
	var front: Dictionary = FlowField.compute_front(cells, dist, blocked)
	var rows: Dictionary = {}
	for p: float in _phases(12):
		var cell := Vector2i(0, 3)
		var steps := 0
		var row_at_mid := -1
		while cell != Vector2i(10, 3) and steps < 120:
			if cell.x >= 7 and row_at_mid < 0:
				row_at_mid = cell.y
			cell = FlowField.descend_step(dist, front, cell, float(p), {})
			steps += 1
		if row_at_mid >= 0:
			rows[row_at_mid] = true
	_expect(rows.size() >= 2, "带墙分叉分多路 (得 %d 行)" % rows.size())


func _test_mono_reaches() -> void:
	print("[mono: 各种地形全部到核心、绝不踱步]")
	var fields: Array = [
		{"name": "开阔同行口", "cells": _grid(11, 7), "core": Vector2i(10, 3), "gate": Vector2i(0, 3), "blocked": {}},
		{"name": "开阔对角口", "cells": _grid(11, 7), "core": Vector2i(10, 0), "gate": Vector2i(0, 6), "blocked": {}},
		{"name": "带墙绕行", "cells": _grid(11, 7), "core": Vector2i(10, 3), "gate": Vector2i(0, 3), "blocked": {Vector2i(5, 2): true, Vector2i(5, 3): true, Vector2i(5, 4): true}},
	]
	for fd in fields:
		var dist: Dictionary = FlowField.compute_distance(fd["cells"], fd["core"], fd["blocked"])
		var front: Dictionary = FlowField.compute_front(fd["cells"], dist, fd["blocked"])
		var reached := 0
		var total := 0
		for p: float in _phases(12):
			total += 1
			var cell: Vector2i = fd["gate"]
			var steps := 0
			while cell != fd["core"] and steps < 400:
				var nxt: Vector2i = FlowField.descend_step(dist, front, cell, float(p), {})
				if nxt == cell:
					break
				cell = nxt
				steps += 1
			if cell == fd["core"]:
				reached += 1
		_expect(reached == total, "%s: 全部到核心 (%d/%d)" % [fd["name"], reached, total])


func _test_determinism() -> void:
	print("[determinism]")
	var cells := _grid(6, 6)
	var a: Dictionary = FlowField.compute_distance(cells, Vector2i(3, 3), {})
	var b: Dictionary = FlowField.compute_distance(cells, Vector2i(3, 3), {})
	_expect(str(a) == str(b), "compute_distance 决定性")
	_expect(str(FlowField.compute_front(cells, a, {})) == str(FlowField.compute_front(cells, b, {})), "compute_front 决定性")
