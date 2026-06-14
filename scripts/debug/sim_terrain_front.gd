extends SceneTree

## 地形正面推进 ASCII 模拟器（headless，stdout 字符画）。
## 用与游戏完全相同的 FlowField.compute_distance/compute_front/next_step 驱动一群 agent，
## 逐帧打印地图+怪群密度，便于直接观察铺面/收拢/绕干员/有无摇摆——不依赖游戏与截图。
## 运行：/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/sim_terrain_front.gd
## 地图字符：'.'空地  '#'墙(不可走)  'C'核心  'S'出怪口  'U'已部署干员
## 帧字符：  '#'墙 'C'核心 数字=该格怪数(>9 用'*') 'U'干员 'S'空出怪口 '.'空

const FlowField = preload("res://scripts/map/flow_field.gd")
const CellDataRef = preload("res://scripts/map/cell_data.gd")
const INVALID := Vector2i(-9999, -9999)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for sc in _scenarios():
		_run_scenario(sc)
	quit(0)


func _scenarios() -> Array:
	return [
		{
			"name": "A. 开阔·出怪口与核心同行（最难铺开的情形）",
			"agents": 24, "frames": 60, "snaps": 7,
			"map": [
				"..............",
				"..............",
				"..............",
				"S............C",
				"..............",
				"..............",
				"..............",
			],
		},
		{
			"name": "B. 漏斗·开阔→1格隘口→开阔（地形决定宽窄）",
			"agents": 24, "frames": 70, "snaps": 7,
			"map": [
				".....##.....",
				".....##.....",
				"S..........C",
				".....##.....",
				".....##.....",
			],
		},
		{
			"name": "C. 中间一道墙·绕行（墙后阴影区最易触发摇摆）",
			"agents": 22, "frames": 80, "snaps": 8,
			"map": [
				"..............",
				"..............",
				".....#........",
				"S....#.......C",
				".....#........",
				"..............",
				"..............",
			],
		},
		{
			"name": "D. 绕干员·开阔处一个干员挡不住一整面",
			"agents": 20, "frames": 60, "snaps": 6,
			"map": [
				"............",
				"............",
				"S.....U....C",
				"............",
				"............",
			],
		},
	]


func _run_scenario(sc: Dictionary) -> void:
	var parsed := _parse(sc["map"])
	var cells: Dictionary = parsed["cells"]
	var walls: Dictionary = parsed["walls"]
	var units: Dictionary = parsed["units"]
	var core: Vector2i = parsed["core"]
	var gates: Array = parsed["gates"]
	var w: int = parsed["w"]
	var h: int = parsed["h"]
	# 墙 + 干员所在地形当不可走（干员不入地形阻挡，但其格作软避让；这里用墙集作场阻挡）。
	var dist: Dictionary = FlowField.compute_distance(cells, core, walls)
	var front: Dictionary = FlowField.compute_front(cells, dist, walls)
	var n: int = int(sc["agents"])
	var half := _half_width(n)
	print("\n================ %s ================" % sc["name"])
	print("尺寸 %dx%d  核心 %s  出怪口 %s  怪数 %d  half_width %d" % [w, h, str(core), str(gates), n, half])

	var with_fix := _simulate(dist, front, core, gates, units, n, half, int(sc["frames"]), int(sc["snaps"]), w, h, walls, true)
	print("【修复版·不回头】到核心 %d/%d，用 %d 帧；摇摆/卡住 %d 只；正面最大宽度 %d 行/列" % [
		with_fix["reached"], n, with_fix["frames_used"], with_fix["stuck"], with_fix["max_width"]])
	var no_fix := _simulate(dist, front, core, gates, units, n, half, int(sc["frames"]), 0, w, h, walls, false)
	print("【对照·无修复(允许回头)】到核心 %d/%d，摇摆/卡住 %d 只" % [no_fix["reached"], n, no_fix["stuck"]])
	if no_fix["stuck"] > with_fix["stuck"] or no_fix["reached"] < with_fix["reached"]:
		print("  → 该地形复现了摇摆，不回头修复有效。")


func _simulate(dist: Dictionary, front: Dictionary, core: Vector2i, gates: Array, units: Dictionary, n: int, half: int, max_frames: int, snaps: int, w: int, h: int, walls: Dictionary, use_prev: bool) -> Dictionary:
	var phases := _phases(n)
	var agents: Array = []
	for i in range(n):
		agents.append({"cell": gates[i % gates.size()], "phase": float(phases[i]), "prev": INVALID, "reached": false})
	var snap_at := {}
	if snaps > 0:
		for s in range(snaps):
			snap_at[int(round(float(s) * float(max_frames) / float(max(snaps - 1, 1))))] = true
	var max_width := 0
	var frames_used := max_frames
	var all_done_frame := -1
	for f in range(max_frames + 1):
		# 统计当前正面宽度（活着的怪占了多少不同行/列里较大的那个）
		var rows := {}
		var cols := {}
		var alive := 0
		for a in agents:
			if a["reached"]:
				continue
			alive += 1
			rows[(a["cell"] as Vector2i).y] = true
			cols[(a["cell"] as Vector2i).x] = true
		max_width = maxi(max_width, maxi(rows.size(), cols.size()))
		if snaps > 0 and snap_at.has(f):
			print("  -- 帧 %d（存活 %d）--" % [f, alive])
			print(_render(agents, core, gates, units, walls, w, h))
		if alive == 0:
			all_done_frame = f
			break
		if f == max_frames:
			break
		# 推进一步
		for a in agents:
			if a["reached"]:
				continue
			var extra := {}
			if use_prev and a["prev"] != INVALID:
				extra[a["prev"]] = true
			for u_key in units.keys():
				extra[u_key] = true
			var nxt: Vector2i = FlowField.next_step(dist, front, a["cell"], a["phase"], half, extra)
			if nxt != a["cell"]:
				a["prev"] = a["cell"]
				a["cell"] = nxt
			if a["cell"] == core:
				a["reached"] = true
	if all_done_frame >= 0:
		frames_used = all_done_frame
	var reached := 0
	var stuck := 0
	for a in agents:
		if a["reached"]:
			reached += 1
		else:
			stuck += 1
	return {"reached": reached, "stuck": stuck, "frames_used": frames_used, "max_width": max_width}


func _render(agents: Array, core: Vector2i, gates: Array, units: Dictionary, walls: Dictionary, w: int, h: int) -> String:
	var count := {}
	for a in agents:
		if a["reached"]:
			continue
		var c: Vector2i = a["cell"]
		count[c] = int(count.get(c, 0)) + 1
	var gate_set := {}
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
			elif units.has(c):
				row += "U"
			elif gate_set.has(c):
				row += "S"
			else:
				row += "."
		lines.append("    " + row)
	return "\n".join(lines)


func _parse(map: Array) -> Dictionary:
	var cells := {}
	var walls := {}
	var units := {}
	var gates: Array = []
	var core := Vector2i.ZERO
	var h := map.size()
	var w := 0
	for y in range(h):
		var line: String = map[y]
		w = maxi(w, line.length())
		for x in range(line.length()):
			var ch := line[x]
			var c := Vector2i(x, y)
			var data = CellDataRef.new()
			data.cell = c
			data.walkable = ch != "#"
			cells[c] = data
			match ch:
				"#": walls[c] = true
				"C": core = c
				"S": gates.append(c)
				"U": units[c] = true
	return {"cells": cells, "walls": walls, "units": units, "core": core, "gates": gates, "w": w, "h": h}


func _half_width(n: int) -> int:
	return clampi(int(round(0.6 * sqrt(float(maxi(n, 1))))), 1, 8)


func _phases(n: int) -> Array:
	var out: Array = []
	for i in range(1, n + 1):
		out.append(fposmod(float(i) * 0.6180339887498949, 1.0))
	return out
