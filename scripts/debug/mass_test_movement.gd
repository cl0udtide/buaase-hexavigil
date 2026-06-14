extends SceneTree

## 移动批量测试台（headless）：复用真实地图生成器造图 → 抽出墙/核心/出怪口 →
## 用与游戏相同的 FlowField 逻辑跑一群 agent → 检测震荡(踱步)/卡住/铺开宽度。
## 在大量真实地形上找根因、对比走法策略。
## 运行：STRATEGY=current N_MAPS=400 SEED0=1 /Applications/Godot.app/Contents/MacOS/Godot \
##        --headless --path . --script scripts/debug/mass_test_movement.gd
## STRATEGY: current(现行) | mono(纯单调下行) | twomode(先铺后单调)

const FlowField = preload("res://scripts/map/flow_field.gd")
const MapGen = preload("res://scripts/map/map_generator.gd")
const CellDataRef = preload("res://scripts/map/cell_data.gd")
const INVALID := Vector2i(-9999, -9999)
const REVISIT_LIMIT := 4   # 某 agent 进同一格超过这么多次 → 判为震荡

var _failures_listed := 0


func _init() -> void:
	call_deferred("_run")


func _cfg() -> Dictionary:
	return {
		"width": 30, "height": 30, "spawn_count": 5,
		"generator": "terrain_first",
		"resources_per_type": 12, "near_resources_per_type": 2, "event_point_count": 0,
		"archetypes": [
			{"id": "highland_run", "weight": 1.0},
			{"id": "riverine_run", "weight": 1.0},
			{"id": "open_run", "weight": 1.0},
		],
	}


func _run() -> void:
	var render_seed := OS.get_environment("RENDER_SEED")
	if render_seed != "":
		_render_one(int(render_seed))
		quit(0)
		return
	var strategy := OS.get_environment("STRATEGY")
	if strategy == "":
		strategy = "current"
	var n_maps := int(OS.get_environment("N_MAPS")) if OS.get_environment("N_MAPS") != "" else 200
	var seed0 := int(OS.get_environment("SEED0")) if OS.get_environment("SEED0") != "" else 1
	var per_gate := int(OS.get_environment("PER_GATE")) if OS.get_environment("PER_GATE") != "" else 6
	var cfg := _cfg()
	var w := int(cfg["width"])
	var h := int(cfg["height"])

	var maps_tested := 0
	var maps_with_osc := 0
	var total_agents := 0
	var total_stuck := 0
	var sum_width := 0
	var min_width := 9999
	var sum_steps := 0
	var sample_seeds: Array = []

	for s in range(seed0, seed0 + n_maps):
		var gen: Dictionary = MapGen.generate(w, h, s, cfg, [])
		var cells: Dictionary = gen.get("cells", {})
		if cells.is_empty():
			continue
		var core: Vector2i = gen.get("core_cell", Vector2i.ZERO)
		var gates: Array = []
		for sc in gen.get("spawn_cells", []):
			gates.append(sc as Vector2i)
		if gates.is_empty():
			continue
		var walls: Dictionary = {}
		for key in cells.keys():
			if not (cells[key] as CellDataRef).walkable:
				walls[key] = true
		var dist: Dictionary = FlowField.compute_distance(cells, core, walls)
		var front: Dictionary = FlowField.compute_front(cells, dist, walls)
		# 只保留能到核心的口（不可达的口本就该被兜底处理，不算移动 bug）
		var live_gates: Array = []
		for g in gates:
			if dist.has(g):
				live_gates.append(g)
		if live_gates.is_empty():
			continue
		var n := per_gate * live_gates.size()
		var res := _sim_map(strategy, dist, front, core, live_gates, n, w, h)
		maps_tested += 1
		total_agents += n
		total_stuck += int(res["stuck"])
		sum_width += int(res["width"])
		min_width = mini(min_width, int(res["width"]))
		sum_steps += int(res["avg_steps"])
		if int(res["stuck"]) > 0:
			maps_with_osc += 1
			if sample_seeds.size() < 6:
				sample_seeds.append({"seed": s, "stuck": res["stuck"], "n": n, "sample_cycle": res["sample_cycle"]})

	print("==== STRATEGY=%s  地图 %d 张（种子 %d..%d）每口 %d 怪 ====" % [strategy, maps_tested, seed0, seed0 + n_maps - 1, per_gate])
	print("有震荡/卡住的地图: %d / %d  (%.1f%%)" % [maps_with_osc, maps_tested, 100.0 * float(maps_with_osc) / float(maxi(maps_tested, 1))])
	print("卡住 agent 总数: %d / %d  (%.2f%%)" % [total_stuck, total_agents, 100.0 * float(total_stuck) / float(maxi(total_agents, 1))])
	print("正面宽度 平均 %.1f  最小 %d   平均步数 %.0f" % [float(sum_width) / float(maxi(maps_tested, 1)), min_width, float(sum_steps) / float(maxi(maps_tested, 1))])
	print("样例卡住种子:")
	for sm in sample_seeds:
		print("  seed %d: 卡 %d/%d，某卡住 agent 反复走: %s" % [sm["seed"], sm["stuck"], sm["n"], str(sm["sample_cycle"])])
	# 机器可读汇总行（workflow 解析用）
	print("RESULT %s osc_maps=%d/%d stuck=%d/%d width_avg=%.2f width_min=%d" % [
		strategy, maps_with_osc, maps_tested, total_stuck, total_agents,
		float(sum_width) / float(maxi(maps_tested, 1)), min_width])
	quit(0)


func _sim_map(strategy: String, dist: Dictionary, front: Dictionary, core: Vector2i, gates: Array, n: int, w: int, h: int) -> Dictionary:
	var half := clampi(int(round(0.6 * sqrt(float(maxi(n, 1))))), 1, 8)
	var phases := _phases(n)
	var agents: Array = []
	for i in range(n):
		agents.append({
			"cell": gates[i % gates.size()], "phase": float(phases[i]),
			"prev": INVALID, "spread_done": false, "reached": false,
			"visits": {}, "cycle": [],
		})
	var cap := 6 * (w + h)
	var width_rows := {}
	var width_cols := {}
	var max_width := 0
	var steps_sum := 0
	var done := 0
	for f in range(cap):
		var alive := 0
		width_rows.clear()
		width_cols.clear()
		for a in agents:
			if a["reached"]:
				continue
			alive += 1
			width_rows[(a["cell"] as Vector2i).y] = true
			width_cols[(a["cell"] as Vector2i).x] = true
		max_width = maxi(max_width, maxi(width_rows.size(), width_cols.size()))
		if alive == 0:
			break
		for a in agents:
			if a["reached"]:
				continue
			var nxt: Vector2i = _step(strategy, dist, front, a, half)
			if nxt != a["cell"]:
				a["prev"] = a["cell"]
				a["cell"] = nxt
				var vis: Dictionary = a["visits"]
				vis[nxt] = int(vis.get(nxt, 0)) + 1
			steps_sum += 1
			if a["cell"] == core:
				a["reached"] = true
				done += 1
	# 统计卡住：未到核心，且(到达步数上限 或 反复进同一格)
	var stuck := 0
	var sample_cycle: Array = []
	for a in agents:
		if a["reached"]:
			continue
		stuck += 1
		if sample_cycle.is_empty():
			# 找它进得最多的几格作为"踱步"证据
			var vis: Dictionary = a["visits"]
			var hot: Array = []
			for k in vis.keys():
				if int(vis[k]) >= REVISIT_LIMIT:
					hot.append([str(k), int(vis[k])])
			sample_cycle = hot.slice(0, 4)
	return {"stuck": stuck, "width": max_width, "avg_steps": float(steps_sum) / float(maxi(n, 1)), "sample_cycle": sample_cycle}


## 走一步：纯单调下行（flow field 标准做法）。STRATEGY 现仅保留 mono，参数留作兼容。
func _step(_strategy: String, dist: Dictionary, front: Dictionary, a: Dictionary, _half: int) -> Vector2i:
	return FlowField.descend_step(dist, front, a["cell"], a["phase"], {})


## 渲染单张真实生成地图上 mono 的行进，看正面到底是"一个宽面"还是"几条蚂蚁线"。
func _render_one(seed: int) -> void:
	var cfg := _cfg()
	var w := int(cfg["width"])
	var h := int(cfg["height"])
	var per_gate := int(OS.get_environment("PER_GATE")) if OS.get_environment("PER_GATE") != "" else 6
	var gen: Dictionary = MapGen.generate(w, h, seed, cfg, [])
	var cells: Dictionary = gen.get("cells", {})
	var core: Vector2i = gen.get("core_cell", Vector2i.ZERO)
	var walls: Dictionary = {}
	for key in cells.keys():
		if not (cells[key] as CellDataRef).walkable:
			walls[key] = true
	var dist: Dictionary = FlowField.compute_distance(cells, core, walls)
	var front: Dictionary = FlowField.compute_front(cells, dist, walls)
	var live: Array = []
	for sc in gen.get("spawn_cells", []):
		if dist.has(sc as Vector2i):
			live.append(sc as Vector2i)
	var n := per_gate * maxi(live.size(), 1)
	var phases := _phases(n)
	var agents: Array = []
	for i in range(n):
		agents.append({"cell": live[i % live.size()], "phase": float(phases[i]), "reached": false})
	print("== 真图 seed %d  %dx%d  核心 %s  活跃口 %d  怪 %d ==" % [seed, w, h, str(core), live.size(), n])
	var snaps := {6: true, 16: true, 28: true, 44: true}
	for f in range(4 * (w + h)):
		var alive := 0
		for a in agents:
			if not a["reached"]:
				alive += 1
		if snaps.has(f):
			print("-- 帧 %d（存活 %d）--" % [f, alive])
			print(_render_grid(agents, core, live, walls, w, h))
		if alive == 0:
			break
		for a in agents:
			if a["reached"]:
				continue
			var nxt: Vector2i = FlowField.descend_step(dist, front, a["cell"], a["phase"], {})
			if nxt != a["cell"]:
				a["cell"] = nxt
			if a["cell"] == core:
				a["reached"] = true


func _render_grid(agents: Array, core: Vector2i, gates: Array, walls: Dictionary, w: int, h: int) -> String:
	var count: Dictionary = {}
	for a in agents:
		if a["reached"]:
			continue
		count[a["cell"]] = int(count.get(a["cell"], 0)) + 1
	var gate_set: Dictionary = {}
	for g in gates:
		gate_set[g] = true
	var lines: Array = []
	for y in range(h):
		var row := ""
		for x in range(w):
			var c := Vector2i(x, y)
			if walls.has(c):
				row += "#"
			elif c == core:
				row += "C"
			elif count.has(c):
				var k: int = count[c]
				row += "*" if k > 9 else str(k)
			elif gate_set.has(c):
				row += "S"
			else:
				row += "."
		lines.append(row)
	return "\n".join(lines)


func _phases(n: int) -> Array:
	var out: Array = []
	for i in range(1, n + 1):
		out.append(fposmod(float(i) * 0.6180339887498949, 1.0))
	return out
