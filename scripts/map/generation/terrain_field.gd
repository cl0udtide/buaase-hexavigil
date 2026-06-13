class_name MapGenTerrainField
extends RefCounted

## Terrain-first 第一阶段：自然地貌场（设计稿 S0–S1.5）。
## 纯静态、决定性、不看核心/出怪口。复用 IntNoise 逐位决定性整数噪声。

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")
const CellDataRef = preload("res://scripts/map/cell_data.gd")

# 本模块自有 STAGE 编号（集成阶段 map_generator 须引用同值，接在 STAGE_MESA=18 之后）。
const STAGE_HEIGHT := 19
const STAGE_MOIST := 20
const MIN_BLOB := 3
const RIVER_MIN_SRC_DIST := 9    # 河源彼此最小曼哈顿距（让河分散）
const RIVER_STEP_LIMIT := 80     # 单条河最大步数（防御性上限）
const RIVER_CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

## 气候预设（集成阶段由 archetype 提供；此处给默认值）。
## warp_amp 硬上限 5（>5 在 30×30 上拧成噪声、地形乱跳）；octave 固定 2。
## 占比用百分位阈值控制（mtn_frac/high_frac/low_frac）：预设管"多少"、噪声管"什么形"。
## base_bias/ridge_amp 只影响原始高度的绝对值，在百分位下不改占比（保留作形状默认）。
const DEFAULT_CLIMATE := {
	"base_bias": 0.0, "ridge_amp": 1.0,
	"mtn_frac": 0.14, "high_frac": 0.12, "low_frac": 0.16, "t_wet": 0.55,
	"moisture_bias": 0.0, "river_count": 2,
	"warp_amp": 3, "warp_scale": 12, "ridge_scale": 9,
}

## 三种气候预设（集成阶段写进 map_generation.json 的 archetypes）。
## 高地流：山高台多、紧凑；河流流：湿、低洼多；开阔流：平、少山。
const CLIMATE_PRESETS := {
	"highland_run": {
		"base_bias": 0.0, "ridge_amp": 1.0,
		"mtn_frac": 0.18, "high_frac": 0.16, "low_frac": 0.12, "t_wet": 0.55,
		"moisture_bias": -0.1, "river_count": 1, "warp_amp": 3, "warp_scale": 12, "ridge_scale": 8,
	},
	"riverine_run": {
		"base_bias": 0.0, "ridge_amp": 1.0,
		"mtn_frac": 0.10, "high_frac": 0.12, "low_frac": 0.24, "t_wet": 0.45,
		"moisture_bias": 0.2, "river_count": 3, "warp_amp": 3, "warp_scale": 12, "ridge_scale": 9,
	},
	"open_run": {
		"base_bias": 0.0, "ridge_amp": 1.0,
		"mtn_frac": 0.07, "high_frac": 0.08, "low_frac": 0.16, "t_wet": 0.55,
		"moisture_bias": -0.1, "river_count": 1, "warp_amp": 3, "warp_scale": 13, "ridge_scale": 10,
	},
}


## 山脊变换：把 [0,1) 值噪声折成"中间高、两端低"的线状脊。
static func _ridged(n: float) -> float:
	return 1.0 - absf(2.0 * n - 1.0)


## 决定性高度场：Vector2i -> int[0,255]。
static func build_height(width: int, height: int, run_seed: int, attempt: int, climate: Dictionary) -> Dictionary:
	var base: int = IntNoise.derive_seed(run_seed, attempt, STAGE_HEIGHT)
	var seeds := {
		"wx": IntNoise.squirrel3(0, base), "wy": IntNoise.squirrel3(1, base),
		"h1": IntNoise.squirrel3(2, base), "h2": IntNoise.squirrel3(3, base),
	}
	var field: Dictionary = {}
	for y in range(height):
		for x in range(width):
			field[Vector2i(x, y)] = int(_height01(x, y, seeds, climate) * 256.0)
	return field


## 单格高度 [0.0, 1.0)：坐标 domain-warp（取整保持整数链）后取 2 阶 ridged multifractal。
static func _height01(x: int, y: int, seeds: Dictionary, climate: Dictionary) -> float:
	var warp_amp: int = int(climate.get("warp_amp", 3))
	var warp_scale: int = int(climate.get("warp_scale", 12))
	var ridge_scale: int = int(climate.get("ridge_scale", 9))
	var base_bias: float = float(climate.get("base_bias", 0.42))
	var ridge_amp: float = float(climate.get("ridge_amp", 1.0))
	var wx: int = x + int(round(float(warp_amp) * (IntNoise.value_noise(x, y, int(seeds["wx"]), warp_scale) * 2.0 - 1.0)))
	var wy: int = y + int(round(float(warp_amp) * (IntNoise.value_noise(x, y, int(seeds["wy"]), warp_scale) * 2.0 - 1.0)))
	var n1: float = _ridged(IntNoise.value_noise(wx, wy, int(seeds["h1"]), ridge_scale))
	var n2: float = _ridged(IntNoise.value_noise(wx, wy, int(seeds["h2"]), maxi(ridge_scale / 2, 1))) * n1
	return clampf(base_bias + ridge_amp * (0.7 * n1 + 0.3 * n2), 0.0, 0.999999)


## 决定性湿度场：Vector2i -> int[0,255]。独立 stage seed，低频、不 ridged（成片湿区）。
static func build_moisture(width: int, height: int, run_seed: int, attempt: int, climate: Dictionary) -> Dictionary:
	var base: int = IntNoise.derive_seed(run_seed, attempt, STAGE_MOIST)
	var m_seed: int = IntNoise.squirrel3(5, base)
	var bias: float = float(climate.get("moisture_bias", 0.0))
	var field: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var v: float = clampf(IntNoise.value_noise(x, y, m_seed, 14) + bias, 0.0, 0.999999)
			field[Vector2i(x, y)] = int(v * 256.0)
	return field


## 高度×湿度 → 地形（百分位阈值）+ 河流。classify 只取地形；build 还返回高度/湿度场。
static func classify(width: int, height: int, run_seed: int, attempt: int, climate: Dictionary) -> Dictionary:
	return build(width, height, run_seed, attempt, climate)["terrain"]


## 完整地貌：返回 {"terrain","height","moisture"}。地形含河流（trace_rivers 顺高度场下流）。
static func build(width: int, height: int, run_seed: int, attempt: int, climate: Dictionary) -> Dictionary:
	var h: Dictionary = build_height(width, height, run_seed, attempt, climate)
	var m: Dictionary = build_moisture(width, height, run_seed, attempt, climate)
	# 百分位阈值：top mtn_frac → 山；其下 high_frac → 高台；bottom low_frac 且够湿 → 水。
	var mtn_frac: float = float(climate.get("mtn_frac", 0.14))
	var high_frac: float = float(climate.get("high_frac", 0.12))
	var low_frac: float = float(climate.get("low_frac", 0.16))
	var t_wet: int = int(float(climate.get("t_wet", 0.55)) * 256.0)
	var sorted_h: Array = h.values()
	sorted_h.sort()
	var n: int = sorted_h.size()
	var t_mtn: int = int(sorted_h[clampi(int((1.0 - mtn_frac) * n), 0, n - 1)])
	var t_high: int = int(sorted_h[clampi(int((1.0 - mtn_frac - high_frac) * n), 0, n - 1)])
	var t_low: int = int(sorted_h[clampi(int(low_frac * n), 0, n - 1)])
	var terrain: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var k := Vector2i(x, y)
			var hv: int = int(h[k])
			if hv >= t_mtn:
				terrain[k] = CellDataRef.TERRAIN_MOUNTAIN
			elif hv >= t_high:
				terrain[k] = CellDataRef.TERRAIN_HIGHLAND
			elif hv < t_low and int(m[k]) >= t_wet:
				terrain[k] = CellDataRef.TERRAIN_WATER
			else:
				terrain[k] = CellDataRef.TERRAIN_PLAIN
	terrain = _despeckle(terrain, width, height)
	trace_rivers(terrain, h, width, height, int(climate.get("river_count", 2)))
	return {"terrain": terrain, "height": h, "moisture": m}


## 河流：从高处的平原"泉眼"顺高度场往低处一路流，路径标水。决定性（源点按高度排序，无 RNG）。
static func trace_rivers(terrain: Dictionary, height_field: Dictionary, width: int, height: int, river_count: int) -> void:
	if river_count <= 0:
		return
	for src in _pick_river_sources(terrain, height_field, width, height, river_count):
		_flow_river(terrain, height_field, width, height, src)


## 选河源：内部、平原、最高、彼此 ≥RIVER_MIN_SRC_DIST（曼哈顿）的格。
static func _pick_river_sources(terrain: Dictionary, height_field: Dictionary, width: int, height: int, river_count: int) -> Array:
	var cands: Array = []
	for y in range(2, height - 2):
		for x in range(2, width - 2):
			var c := Vector2i(x, y)
			if terrain.get(c, CellDataRef.TERRAIN_MOUNTAIN) == CellDataRef.TERRAIN_PLAIN:
				cands.append([int(height_field[c]), c])
	cands.sort_custom(func(a, b):
		if int(a[0]) != int(b[0]):
			return int(a[0]) > int(b[0])
		if (a[1] as Vector2i).y != (b[1] as Vector2i).y:
			return (a[1] as Vector2i).y < (b[1] as Vector2i).y
		return (a[1] as Vector2i).x < (b[1] as Vector2i).x)
	var picked: Array = []
	for entry in cands:
		var c: Vector2i = entry[1]
		var ok := true
		for raw_p in picked:
			var p: Vector2i = raw_p
			if absi(c.x - p.x) + absi(c.y - p.y) < RIVER_MIN_SRC_DIST:
				ok = false
				break
		if ok:
			picked.append(c)
		if picked.size() >= river_count:
			break
	return picked


## 单条河：每步走到"最低的、未访问、非山非高台"4 邻；遇图边/水/无路则停。路径全标水。
static func _flow_river(terrain: Dictionary, height_field: Dictionary, width: int, height: int, start: Vector2i) -> void:
	var cur := start
	var visited: Dictionary = {start: true}
	var path: Array[Vector2i] = [start]
	for _step in range(RIVER_STEP_LIMIT):
		if cur.x == 0 or cur.y == 0 or cur.x == width - 1 or cur.y == height - 1:
			break
		var best := Vector2i(-1, -1)
		var best_h: int = 1 << 30
		for d in RIVER_CARDINALS:
			var nb := cur + d
			if visited.has(nb) or nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= height:
				continue
			var t: StringName = terrain.get(nb, CellDataRef.TERRAIN_MOUNTAIN)
			if t == CellDataRef.TERRAIN_MOUNTAIN or t == CellDataRef.TERRAIN_HIGHLAND:
				continue
			var hnb: int = int(height_field[nb])
			if hnb < best_h:
				best_h = hnb
				best = nb
		if best.x < 0:
			break
		cur = best
		visited[cur] = true
		path.append(cur)
		if terrain.get(cur) == CellDataRef.TERRAIN_WATER:
			break
	for c in path:
		terrain[c] = CellDataRef.TERRAIN_WATER


## 去碎点：把 < MIN_BLOB 的山/高台 4 连通域降回平原（站不下、看着碎）。
## 水不在此清（湖天然可小）。决定性：固定 (y,x) 扫描序 + 4 邻 BFS。
static func _despeckle(terrain: Dictionary, width: int, height: int) -> Dictionary:
	var visited: Dictionary = {}
	var cardinals: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for y in range(height):
		for x in range(width):
			var start := Vector2i(x, y)
			if visited.has(start):
				continue
			var t0: StringName = terrain[start]
			if t0 != CellDataRef.TERRAIN_MOUNTAIN and t0 != CellDataRef.TERRAIN_HIGHLAND:
				visited[start] = true
				continue
			# 同类 4 连通域 BFS。
			var comp: Array[Vector2i] = []
			var queue: Array[Vector2i] = [start]
			visited[start] = true
			var head: int = 0
			while head < queue.size():
				var cur: Vector2i = queue[head]
				head += 1
				comp.append(cur)
				for d in cardinals:
					var nb: Vector2i = cur + d
					if visited.has(nb) or not terrain.has(nb):
						continue
					if terrain[nb] == t0:
						visited[nb] = true
						queue.append(nb)
			if comp.size() < MIN_BLOB:
				for c in comp:
					terrain[c] = CellDataRef.TERRAIN_PLAIN
	return terrain


## ASCII 转储（人眼调试）：. 平原 / ^ 山 / : 高台 / ~ 水。固定 (y,x) 序。
static func ascii_dump(terrain: Dictionary, width: int, height: int) -> String:
	var glyph := {
		CellDataRef.TERRAIN_PLAIN: ".", CellDataRef.TERRAIN_MOUNTAIN: "^",
		CellDataRef.TERRAIN_HIGHLAND: ":", CellDataRef.TERRAIN_WATER: "~",
	}
	var out: String = ""
	for y in range(height):
		for x in range(width):
			out += String(glyph.get(terrain.get(Vector2i(x, y), CellDataRef.TERRAIN_PLAIN), "?"))
		out += "\n"
	return out
