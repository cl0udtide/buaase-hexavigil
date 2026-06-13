class_name MapGenCorePicker
extends RefCounted

## Terrain-first 第二阶段：核心选址（设计稿 S3）。
## 在已生成的自然地貌上挑一个"有题可读"的核心位置（核心不在中心）。
## 不做强制公平：只是软偏好 + 高分位随机；极端落点照样可选。纯静态、决定性。

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")
const CellDataRef = preload("res://scripts/map/cell_data.gd")

const STAGE_CORE := 21        # 接在 terrain_field STAGE_MOIST=20 之后
const EDGE_MARGIN := 5        # 核心离图边最小格数（设计者定：不贴最边上）
const BUILD_RADIUS := 2       # 核心圈可建空地统计半径
const MIN_BUILD := 6          # 粗筛：核心圈至少这么多可建平原（摆得下初始防御）
const HIGH_RADIUS := 4        # 高台 perk 统计半径
const BARRIER_MAXSTEP := 5    # 8 方向天然屏障探测步数
const TOP_QUANTILE := 0.20    # 高分位池比例（取池内随机一个，非全局最高）

const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const ALL8: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


static func _is_blocking(t: StringName) -> bool:
	return t == CellDataRef.TERRAIN_MOUNTAIN or t == CellDataRef.TERRAIN_WATER or t == CellDataRef.TERRAIN_HIGHLAND


## clearance 场：每格到最近阻挡（或图边）的曼哈顿距 = 通道半宽。阻挡格=0。多源 BFS。
static func clearance_field(terrain: Dictionary, width: int, height: int) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var k := Vector2i(x, y)
			if _is_blocking(terrain.get(k, CellDataRef.TERRAIN_PLAIN)):
				dist[k] = 0
				queue.append(k)
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in CARDINALS:
			var nb: Vector2i = cur + d
			if not terrain.has(nb) or dist.has(nb):
				continue
			dist[nb] = int(dist[cur]) + 1
			queue.append(nb)
	var out: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var k := Vector2i(x, y)
			var edge: int = mini(mini(x, width - 1 - x), mini(y, height - 1 - y)) + 1
			out[k] = mini(int(dist.get(k, edge)), edge)
	return out


## 选核：粗筛（平原 + 离边 ≥EDGE_MARGIN + 核心圈可建 ≥MIN_BUILD）→ 打分 →
## 高分位池里按 derive_seed 决定性随机取一个。无候选 → 退回图心。
static func pick_core(terrain: Dictionary, width: int, height: int, run_seed: int, attempt: int) -> Vector2i:
	var clr: Dictionary = clearance_field(terrain, width, height)
	var cands: Array = []        # [score, y, x, cell]
	for y in range(height):
		for x in range(width):
			var c := Vector2i(x, y)
			if terrain.get(c, CellDataRef.TERRAIN_MOUNTAIN) != CellDataRef.TERRAIN_PLAIN:
				continue
			var margin: int = mini(mini(x, width - 1 - x), mini(y, height - 1 - y))
			if margin < EDGE_MARGIN:
				continue
			var build: int = _build_count(terrain, c)
			if build < MIN_BUILD:
				continue
			cands.append([_score(terrain, clr, c, build), y, x, c])
	if cands.is_empty():
		return Vector2i(width / 2, height / 2)
	cands.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] > b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	var topk: int = maxi(1, int(float(cands.size()) * TOP_QUANTILE))
	var pick: int = IntNoise.derive_seed(run_seed, attempt, STAGE_CORE) % topk
	return cands[pick][3]


## 评分（纯"有题可读"软偏好；无难度/公平惩罚）：
## 2×天然被堵方向 + 3×近核天然隘口 + 1×近核高台 perk + 1×核心圈可建空地。
static func _score(terrain: Dictionary, clr: Dictionary, c: Vector2i, build: int) -> int:
	return 2 * _barrier_dirs(terrain, c) + 3 * _choke_count(terrain, clr, c) + _highland_near(terrain, c) + build


## 核心圈（cheb ≤ BUILD_RADIUS）可建平原数。
static func _build_count(terrain: Dictionary, c: Vector2i) -> int:
	var n: int = 0
	for dy in range(-BUILD_RADIUS, BUILD_RADIUS + 1):
		for dx in range(-BUILD_RADIUS, BUILD_RADIUS + 1):
			if terrain.get(c + Vector2i(dx, dy), CellDataRef.TERRAIN_MOUNTAIN) == CellDataRef.TERRAIN_PLAIN:
				n += 1
	return n


## 近核（cheb ≤ HIGH_RADIUS）天然高台数（远程 perk）。
static func _highland_near(terrain: Dictionary, c: Vector2i) -> int:
	var n: int = 0
	for dy in range(-HIGH_RADIUS, HIGH_RADIUS + 1):
		for dx in range(-HIGH_RADIUS, HIGH_RADIUS + 1):
			if terrain.get(c + Vector2i(dx, dy), CellDataRef.TERRAIN_MOUNTAIN) == CellDataRef.TERRAIN_HIGHLAND:
				n += 1
	return n


## 8 方向中"近距离撞山/遇水/图边"的方向数（越多=四周天然有墙=省墙）。
static func _barrier_dirs(terrain: Dictionary, c: Vector2i) -> int:
	var n: int = 0
	for d in ALL8:
		for step in range(1, BARRIER_MAXSTEP + 1):
			var k: Vector2i = c + d * step
			if not terrain.has(k):
				n += 1
				break
			if _is_blocking(terrain[k]):
				n += 1
				break
	return n


## 核心 cheb∈[2,4] 环带上的天然隘口数：平原、clearance ≤2、且是 4 邻 clearance 局部极小。
static func _choke_count(terrain: Dictionary, clr: Dictionary, c: Vector2i) -> int:
	var n: int = 0
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var cheb: int = maxi(absi(dx), absi(dy))
			if cheb < 2 or cheb > 4:
				continue
			var k: Vector2i = c + Vector2i(dx, dy)
			if terrain.get(k, CellDataRef.TERRAIN_MOUNTAIN) != CellDataRef.TERRAIN_PLAIN:
				continue
			var cl: int = int(clr.get(k, 99))
			if cl > 2:
				continue
			var is_min: bool = true
			for d in CARDINALS:
				if int(clr.get(k + d, 99)) < cl:
					is_min = false
					break
			if is_min:
				n += 1
	return n


## ASCII 转储 + 覆盖标记（marks: Vector2i -> 单字符串）。. 平原 / ^ 山 / : 高台 / ~ 水。
static func ascii_overlay(terrain: Dictionary, width: int, height: int, marks: Dictionary) -> String:
	var glyph := {
		CellDataRef.TERRAIN_PLAIN: ".", CellDataRef.TERRAIN_MOUNTAIN: "^",
		CellDataRef.TERRAIN_HIGHLAND: ":", CellDataRef.TERRAIN_WATER: "~",
	}
	var out: String = ""
	for y in range(height):
		for x in range(width):
			var k := Vector2i(x, y)
			if marks.has(k):
				out += String(marks[k])
			else:
				out += String(glyph.get(terrain.get(k, CellDataRef.TERRAIN_PLAIN), "?"))
		out += "\n"
	return out
