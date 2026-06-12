class_name MapGenLanes
extends RefCounted

## 车道走线与保护集（设计稿 S3）：噪声抖动代价场 A*（×16 定点整数代价）、
## 走线自检重抽、aperture 窗、protected 类别集。纯静态、决定性。

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")

const COST_UNIT := 16
const RATIO_FLOOR := 1.15
const RATIO_CAP := 1.6
const RECHECK_LIMIT := 3
const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


## 进入格 c 的代价：16 + (噪声八位 × 抖动十六分位) >> 8 ∈ [16, 16+jitter_q)。
## noise_q = int(value_noise(x, y, noise_seed, 3) * 256.0)——value_noise 输出为
## blended/65536，×256 取整 == blended >> 8，浮点往返无损（除/乘均为 2 的幂）。
static func _step_cost(cell: Vector2i, noise_seed: int, jitter_q: int) -> int:
	var noise_q: int = int(IntNoise.value_noise(cell.x, cell.y, noise_seed, 3) * 256.0)
	return COST_UNIT + ((noise_q * jitter_q) >> 8)


## 段内 A*：从 from_cell 到 to_cell，返回含两端点的 4 连通路径；路径不存在返回 []。
## open 表线性扫描取最小 (f, y, x)（同 _soft_cost_path 风格，900 格量级无虞）；
## h = 16 × 曼哈顿（最小步代价 16 ⇒ 可采纳）；越界由 cells.has 判定；
## 不可走格（此阶段尚无，防御性）跳过。决定性：无 RNG、全序裁决。
static func _astar_segment(cells: Dictionary, from_cell: Vector2i, to_cell: Vector2i, noise_seed: int, jitter_q: int) -> Array[Vector2i]:
	if from_cell == to_cell:
		return [from_cell]
	# g_cost: cell → int（已知最短 g）
	var g_cost: Dictionary = {from_cell: 0}
	# came_from: cell → cell
	var came_from: Dictionary = {}
	# open: Array of [f, y, x, cell] for deterministic sort
	var open: Array = []
	var h0: int = COST_UNIT * (absi(from_cell.x - to_cell.x) + absi(from_cell.y - to_cell.y))
	open.append([h0, from_cell.y, from_cell.x, from_cell])
	var closed: Dictionary = {}

	while not open.is_empty():
		# Linear scan for minimum (f, y, x) — deterministic tiebreak
		var best_idx: int = 0
		for idx in range(1, open.size()):
			var a: Array = open[idx]
			var b: Array = open[best_idx]
			if a[0] < b[0] or (a[0] == b[0] and (a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))):
				best_idx = idx
		var current_entry: Array = open[best_idx]
		open.remove_at(best_idx)
		var current: Vector2i = current_entry[3]
		if closed.has(current):
			continue
		closed[current] = true
		if current == to_cell:
			# Reconstruct path
			var path: Array[Vector2i] = []
			var c: Vector2i = to_cell
			while came_from.has(c):
				path.append(c)
				c = came_from[c]
			path.append(from_cell)
			path.reverse()
			return path
		var g_curr: int = int(g_cost[current])
		for dir in CARDINALS:
			var nb: Vector2i = current + dir
			if not cells.has(nb):
				continue
			var data: CellData = cells[nb]
			if data == null or not data.walkable:
				continue
			if closed.has(nb):
				continue
			var step: int = _step_cost(nb, noise_seed, jitter_q)
			var g_new: int = g_curr + step
			if not g_cost.has(nb) or g_new < int(g_cost[nb]):
				g_cost[nb] = g_new
				came_from[nb] = current
				var h: int = COST_UNIT * (absi(nb.x - to_cell.x) + absi(nb.y - to_cell.y))
				open.append([g_new + h, nb.y, nb.x, nb])
	return []


## 分段 A*（gate→wp1→…→core）拼接去重。
static func trace_lane(cells: Dictionary, gate: Vector2i, waypoints: Array[Vector2i], core: Vector2i, jitter_amp: float, noise_seed: int) -> Array[Vector2i]:
	var jitter_q: int = int(round(clampf(jitter_amp, 0.0, 1.0) * 16.0))
	var points: Array[Vector2i] = [gate]
	points.append_array(waypoints)
	points.append(core)
	var path: Array[Vector2i] = []
	for i in range(points.size() - 1):
		var segment := _astar_segment(cells, points[i], points[i + 1], noise_seed, jitter_q)
		if segment.is_empty():
			return []
		if not path.is_empty():
			segment.remove_at(0)	# 拼接处去重
		path.append_array(segment)
	return path


static func lane_ratio(path: Array[Vector2i], gate: Vector2i, core: Vector2i) -> float:
	var manhattan: int = maxi(absi(gate.x - core.x) + absi(gate.y - core.y), 1)
	return float(path.size() - 1) / float(manhattan)


## 自检重抽 ≤RECHECK_LIMIT：过直升幅、过弯降幅；幅度与子种子均确定性派生。
static func trace_lane_checked(cells: Dictionary, gate: Vector2i, waypoints: Array[Vector2i], core: Vector2i, jitter_amp: float, noise_seed: int) -> Array[Vector2i]:
	var amp: float = jitter_amp
	var best: Array[Vector2i] = []
	for try_index in range(RECHECK_LIMIT):
		var path := trace_lane(cells, gate, waypoints, core, amp, IntNoise.squirrel3(try_index, noise_seed))
		best = path
		if path.is_empty():
			amp = clampf(amp * 1.5, 0.0, 1.0)
			continue
		var ratio := lane_ratio(path, gate, core)
		if ratio >= RATIO_FLOOR and ratio <= RATIO_CAP:
			return path
		amp = clampf(amp * (1.5 if ratio < RATIO_FLOOR else 0.6), 0.0, 1.0)
	return best	# 出带交 S6 修复（B2-7 绕路上下限兜底）


## aperture 窗：纵深沿门→核心主轴方向（dir_d），宽度沿其垂直轴（dir_w），锚格居中：
## off ∈ [-(w/2), w - w/2)，di ∈ [0, depth)，cell = anchor + dir_d*di + dir_w*off，越界裁剪。
static func aperture_window(anchor: Vector2i, gate: Vector2i, core: Vector2i, pass_width: int, depth: int) -> Array[Vector2i]:
	var axis := core - gate
	var dir_d := Vector2i(signi(axis.x), 0) if absi(axis.x) >= absi(axis.y) else Vector2i(0, signi(axis.y))
	var dir_w := Vector2i(0, 1) if dir_d.x != 0 else Vector2i(1, 0)
	var window: Array[Vector2i] = []
	for di in range(depth):
		for wi in range(pass_width):
			var off: int = wi - pass_width / 2
			window.append(anchor + dir_d * di + dir_w * off)
	return window


## 从 gate→core 主轴提取单步方向向量（与 aperture_window 轴系约定一致）。
static func _main_axis(gate: Vector2i, core: Vector2i) -> Vector2i:
	var axis := core - gate
	return Vector2i(signi(axis.x), 0) if absi(axis.x) >= absi(axis.y) else Vector2i(0, signi(axis.y))


## 注册顺序 core→apron→aperture→pocket→lane，先注册先得。
## build_protected 内对窗/口袋格做 0..width/height 裁剪（width/height 取 cfg，缺省 30）。
static func build_protected(lanes: Dictionary, core: Vector2i, gates: Array[Vector2i], anchors: Dictionary, cfg: Dictionary) -> Dictionary:
	var width: int = int(cfg.get("width", 30))
	var height: int = int(cfg.get("height", 30))
	var pass_cfg: Dictionary = cfg.get("pass", {})
	var pocket_w: int = int(pass_cfg.get("pocket_core_w", 3))
	var pocket_h: int = int(pass_cfg.get("pocket_core_h", 2))
	var aperture_depth: int = int(pass_cfg.get("aperture_depth", 2))
	var protected: Dictionary = {}
	# core 围裙 cheb <= 3
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			_mark(protected, core + Vector2i(dx, dy), &"core")
	# gate 围裙 cheb <= 2（5×5 方块，裁剪图外）
	for gate in gates:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var apron_cell: Vector2i = gate + Vector2i(dx, dy)
				if apron_cell.x >= 0 and apron_cell.x < width and apron_cell.y >= 0 and apron_cell.y < height:
					_mark(protected, apron_cell, &"apron")
	# aperture 窗 + 口袋核心（每锚按排序键名迭代保证决定性）
	var anchor_keys: Array = anchors.keys()
	anchor_keys.sort()
	for raw_key: Variant in anchor_keys:
		var entry: Dictionary = anchors[raw_key]
		var anchor_cell: Vector2i = entry.get("cell", core)
		var pass_width: int = int(entry.get("pass_width", 2))
		# aperture 已由调用方计算好存入 entry["aperture"]，直接注册
		for raw_cell: Variant in entry.get("aperture", []):
			var c: Vector2i = raw_cell
			if c.x >= 0 and c.x < width and c.y >= 0 and c.y < height:
				_mark(protected, c, &"aperture")
		# 口袋最小核：aperture 核心侧（核心向）pocket_w × pocket_h。
		# aperture_window 发射顺序为 di 外循环 × wi 内循环，故：
		#   aperture[0]          = anchor + dir_d*0 + dir_w*(-pass_width/2)
		#   aperture[pass_width] = anchor + dir_d*1 + dir_w*(-pass_width/2)
		#   => aperture[pass_width] - aperture[0] = dir_d（纵深轴单步）
		# 用该差值可精确还原纵深方向；pass_width=1 时数组只有 depth 行共 depth 格，
		# 无法用该差取（idx==pass_width 可能 == depth 超界），回退到 _main_axis。
		var aperture_arr: Array = entry.get("aperture", [])
		var dir_d: Vector2i
		if aperture_arr.size() > pass_width:
			# aperture[pass_width] - aperture[0] = dir_d（纵深轴）
			var a0: Vector2i = aperture_arr[0]
			var a1: Vector2i = aperture_arr[pass_width]
			var raw: Vector2i = a1 - a0
			dir_d = Vector2i(signi(raw.x), 0) if absi(raw.x) >= absi(raw.y) else Vector2i(0, signi(raw.y))
		else:
			# 回退：从 anchors entry 不携带 gate_cell，用最近 gate 门近似——
			# 因 anchor 唯一属于本扇区且 gate→core 主轴与 anchor 同扇区，_main_axis
			# 使用 core 全局方向作为兜底（pass_width>=2 的正常路径永不触此）。
			dir_d = _main_axis(anchor_cell, core)
		var dir_w: Vector2i = Vector2i(0, 1) if dir_d.x != 0 else Vector2i(1, 0)
		if not aperture_arr.is_empty():
			for di in range(aperture_depth, aperture_depth + pocket_h):
				for wi in range(pocket_w):
					var off: int = wi - pocket_w / 2
					var pc: Vector2i = anchor_cell + dir_d * di + dir_w * off
					if pc.x >= 0 and pc.x < width and pc.y >= 0 and pc.y < height:
						_mark(protected, pc, &"pocket")
	# 车道格（最后注册，优先级最低）
	var lane_keys: Array = lanes.keys()
	lane_keys.sort()
	for raw_key: Variant in lane_keys:
		for raw_cell: Variant in lanes[raw_key]:
			_mark(protected, raw_cell, &"lane")
	return protected


static func _mark(protected: Dictionary, cell: Vector2i, category: StringName) -> void:
	if not protected.has(cell):
		protected[cell] = category
