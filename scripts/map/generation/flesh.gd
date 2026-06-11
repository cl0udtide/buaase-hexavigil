class_name MapGenFlesh
extends RefCounted

## 骨架长肉（设计稿 S4/§2.1-2.3）：预算台账、边界折线山脊、峡谷双脊、
## 伪高程、河流渡口、湖泊与湿度。纯静态、决定性。
## 回引 map_generator 静态助手用运行时 load（见计划「模块回引规则」）。

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")
const SkeletonGen = preload("res://scripts/map/generation/skeleton.gd")

const GAP_THRESHOLD := 26          # 噪声八位 < 26 ≈ 10% 豁口（§2.1 walker）
const WIDEN_THRESHOLD := 192       # 噪声八位 >= 192 ≈ 25% 峡谷偶发加宽
const SPINDLE_EDGE := 0.2          # 纺锤剖面：折线两端 20% 收窄到宽 1
const QUOTA_SLACK := 1.5           # 扇区配额超额容忍系数
const RIDGE_NOISE_SCALE := 4       # 脊噪声网格边长（§2.1）
const ELEV_DIST_CAP := 12          # 伪高程山距截断（§2.2）
const RIVER_RING_MIN := 9          # 河源环带（扇区外缘）
const RIVER_RING_MAX := 13
const RIVER_STEP_LIMIT := 200      # 梯度下降步数硬上限（防御）
const POND_MIN := 3                # 卡坑小湖尺寸（§2.2 3-5 格）
const POND_MAX := 5
const LAKE_RING_MIN := 8           # 湖心最小核心环（§2.3）
const LAKE_LANE_CLEARANCE := 4     # 湖心距本扇区车道最小切比雪夫距离
const LAKE_SIZE_MIN := 15          # blob 湖目标尺寸（§2.3 15-30 格）
const LAKE_SIZE_MAX := 30
const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


static func _mg() -> GDScript:
	return load("res://scripts/map/map_generator.gd")


static func make_ledger(cfg: Dictionary, archetype: Dictionary, cards: Dictionary, width: int, height: int) -> Dictionary:
	var band: Array = archetype.get("ratio_band", [0.20, 0.26])
	var mid: float = (float(band[0]) + float(band[1])) * 0.5
	var target: int = int(round(mid * float(width * height)))
	var sector_cards: Dictionary = cfg.get("sector_cards", {})
	var density_sum: float = 0.0
	var keys: Array = cards.keys()
	keys.sort()
	for raw_key: Variant in keys:
		density_sum += float((sector_cards.get(String(cards[raw_key]), {}) as Dictionary).get("density", 1.0))
	var quota: Dictionary = {}
	for raw_key: Variant in keys:
		var density: float = float((sector_cards.get(String(cards[raw_key]), {}) as Dictionary).get("density", 1.0))
		quota[String(raw_key)] = int(round(float(target) * density / maxf(density_sum, 0.01)))
	return {
		"target": target, "requested": 0, "applied": 0, "rolled_back": 0,
		"repair_intrusion": 0, "sector_quota": quota, "sector_applied": {}, "stages": {},
	}


static func ledger_note(ledger: Dictionary, stage: String, requested: int, applied: int, rolled_back: int) -> void:
	ledger["requested"] = int(ledger.get("requested", 0)) + requested
	ledger["applied"] = int(ledger.get("applied", 0)) + applied
	ledger["rolled_back"] = int(ledger.get("rolled_back", 0)) + rolled_back
	var stages: Dictionary = ledger.get("stages", {})
	var entry: Dictionary = stages.get(stage, {"requested": 0, "applied": 0, "rolled_back": 0})
	entry["requested"] = int(entry["requested"]) + requested
	entry["applied"] = int(entry["applied"]) + applied
	entry["rolled_back"] = int(entry["rolled_back"]) + rolled_back
	stages[stage] = entry
	ledger["stages"] = stages


## 山脉长肉（§2.1 三步 + 峡谷双脊）：
## 1. 选边界：角序相邻门对，任一侧为 bastion → 该边界实体化（canyon 不长边界）；
## 2. 中点位移折线：bisector 射线 r=5/7/11/边缘四顶点，r=7/11 各加垂直位移 ∈[-3,3]；
## 3. walker：整数 DDA 逐格，噪声豁口 ~10%、宽度 1..3 调制、纺锤两端收窄，
##    每段折线一批经 _try_apply_obstacle_cells（连通回滚）落山并记账；
## 4. 峡谷双脊：canyon 扇区车道走廊段两侧法向偏移 2 落山（保宽 3 走廊），偶发加宽偏移 3。
## ridge_seed 由 rng 开头一次性派生，之后噪声不再混用 rng——rng 消费序与格序无关。
## 全局停机：ledger.applied >= ledger.target 时立即返回。
static func grow_ridges(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary) -> void:
	var ridge_seed: int = rng.randi()
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var gate_keys: Array = skeleton.get("gate_keys", [])
	var gate_map: Dictionary = skeleton.get("gate_cells", {})
	var cards: Dictionary = skeleton.get("cards", {})
	var gate_cells: Array[Vector2i] = []
	for raw_key: Variant in gate_keys:
		gate_cells.append(gate_map[raw_key])
	if gate_cells.size() < 2:
		return
	# 1+2+3: 边界折线脊（角序相邻对，每对至多一次）。
	var order: Array[int] = SkeletonGen._angle_sorted_indices(gate_cells, core)
	for k in range(order.size()):
		var i: int = order[k]
		var j: int = order[(k + 1) % order.size()]
		var card_i := String(cards.get(String(gate_keys[i]), ""))
		var card_j := String(cards.get(String(gate_keys[j]), ""))
		if card_i != "bastion" and card_j != "bastion":
			continue
		var bisector: Vector2i = (gate_cells[i] - core) + (gate_cells[j] - core)
		if bisector == Vector2i.ZERO:
			continue
		if _grow_border_ridge(cells, skeleton, protected, rng, ledger, bisector, ridge_seed):
			return
	# 4: 峡谷双脊（gate_key 升序，决定性）。
	var sorted_keys: Array = gate_keys.duplicate()
	sorted_keys.sort()
	for raw_key: Variant in sorted_keys:
		var key := String(raw_key)
		if String(cards.get(key, "")) != "canyon":
			continue
		if _grow_canyon_ridges(cells, skeleton, protected, rng, ledger, key, ridge_seed):
			return


## 单条边界脊：中点位移折线 + 宽度调制 walker。返回 true = 预算已满应停机。
static func _grow_border_ridge(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary, bisector: Vector2i, ridge_seed: int) -> bool:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var perp: Vector2i = _perp_axis(bisector)
	var p1: Vector2i = SkeletonGen.ray_point(core, bisector, 7) + perp * rng.randi_range(-3, 3)
	var p2: Vector2i = SkeletonGen.ray_point(core, bisector, 11) + perp * rng.randi_range(-3, 3)
	var verts: Array[Vector2i] = [
		SkeletonGen.ray_point(core, bisector, 5), p1, p2,
		_edge_point(core, bisector, width, height),
	]
	# 折线全格序列（段间共享顶点去重；记录段号，t 取全线序数比例）。
	var line_cells: Array[Vector2i] = []
	var line_segs: Array[int] = []
	for s in range(verts.size() - 1):
		var seg: Array[Vector2i] = _walk_segment(verts[s], verts[s + 1])
		var start: int = 1 if s > 0 else 0
		for idx in range(start, seg.size()):
			line_cells.append(seg[idx])
			line_segs.append(s)
	var total: int = line_cells.size()
	for s in range(verts.size() - 1):
		var batch: Array[Vector2i] = []
		var queued: Dictionary = {}
		for idx in range(total):
			if line_segs[idx] != s:
				continue
			var c: Vector2i = line_cells[idx]
			if _noise_q(c, ridge_seed) < GAP_THRESHOLD:
				continue
			var w: int = 1 + ((_noise_q(c, ridge_seed + 1) * 3) >> 8)
			var t: float = float(idx) / float(maxi(total - 1, 1))
			if t < SPINDLE_EDGE or t > 1.0 - SPINDLE_EDGE:
				w = 1
			for off: int in _width_offsets(w):
				var cell: Vector2i = c + perp * off
				if queued.has(cell):
					continue
				if not _cell_paintable(cells, protected, skeleton, ledger, cell, width, height):
					continue
				queued[cell] = true
				batch.append(cell)
		_apply_batch(cells, skeleton, ledger, batch)
		if _budget_reached(ledger):
			return true
	return false


## 峡谷双脊（§4.2 canyon 牌面）：车道走廊段两侧法向偏移落山，两侧各一批。
## 返回 true = 预算已满应停机。
static func _grow_canyon_ridges(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary, gate_key: String, ridge_seed: int) -> bool:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var cards: Dictionary = skeleton.get("cards", {})
	var card_cfgs: Dictionary = skeleton.get("card_cfgs", {})
	var card_cfg: Dictionary = card_cfgs.get(String(cards.get(gate_key, "")), {})
	var len_band: Array = card_cfg.get("corridor_len", [6, 9])
	var corridor_len: int = rng.randi_range(int(len_band[0]), int(len_band[1]))
	var lanes: Dictionary = skeleton.get("lanes", {})
	var lane: Array = lanes.get(gate_key, [])
	var anchors: Dictionary = skeleton.get("anchors", {})
	var anchor_entry: Dictionary = anchors.get(gate_key, {})
	var anchor_cell: Vector2i = anchor_entry.get("cell", core)
	var anchor_ring: int = maxi(absi(anchor_cell.x - core.x), absi(anchor_cell.y - core.y))
	var ring_lo: int = anchor_ring - corridor_len / 2
	var ring_hi: int = anchor_ring + corridor_len / 2
	var left_batch: Array[Vector2i] = []
	var right_batch: Array[Vector2i] = []
	var queued: Dictionary = {}
	for k in range(1, lane.size() - 1):
		var c: Vector2i = lane[k]
		var ring: int = maxi(absi(c.x - core.x), absi(c.y - core.y))
		if ring < ring_lo or ring > ring_hi:
			continue
		var prev_cell: Vector2i = lane[k - 1]
		var next_cell: Vector2i = lane[k + 1]
		var tangent := Vector2i(signi(next_cell.x - prev_cell.x), signi(next_cell.y - prev_cell.y))
		if tangent == Vector2i.ZERO:
			continue
		if _noise_q(c, ridge_seed) < GAP_THRESHOLD:
			continue
		var widen: bool = _noise_q(c, ridge_seed + 1) >= WIDEN_THRESHOLD
		_queue_flank(cells, protected, skeleton, ledger, left_batch, queued, c, Vector2i(tangent.y, -tangent.x), widen, width, height)
		_queue_flank(cells, protected, skeleton, ledger, right_batch, queued, c, Vector2i(-tangent.y, tangent.x), widen, width, height)
	_apply_batch(cells, skeleton, ledger, left_batch)
	if _budget_reached(ledger):
		return true
	_apply_batch(cells, skeleton, ledger, right_batch)
	return _budget_reached(ledger)


## 单侧翼脊候选：车道格沿法向偏移 2（widen 时再加偏移 3），过滤后入批。
static func _queue_flank(cells: Dictionary, protected: Dictionary, skeleton: Dictionary, ledger: Dictionary, batch: Array[Vector2i], queued: Dictionary, lane_cell: Vector2i, normal: Vector2i, widen: bool, width: int, height: int) -> void:
	var offsets: Array[int] = [2]
	if widen:
		offsets.append(3)
	for off: int in offsets:
		var cell: Vector2i = lane_cell + normal * off
		if queued.has(cell):
			continue
		if not _cell_paintable(cells, protected, skeleton, ledger, cell, width, height):
			continue
		queued[cell] = true
		batch.append(cell)


## 一批脊格经连通回滚应用并记账；批内格须已过 _cell_paintable（当前全可走）。
static func _apply_batch(cells: Dictionary, skeleton: Dictionary, ledger: Dictionary, batch: Array[Vector2i]) -> void:
	if batch.is_empty():
		return
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var cfg: Dictionary = skeleton.get("cfg", {})
	var spawn_cells: Array[Vector2i] = []
	for raw_cell: Variant in (skeleton.get("spawn_cells", []) as Array):
		spawn_cells.append(raw_cell)
	var applied: int = _mg()._try_apply_obstacle_cells(cells, batch, CellData.TERRAIN_MOUNTAIN, width, height, spawn_cells, core, cfg)
	ledger_note(ledger, "ridges", batch.size(), applied, batch.size() - applied)
	if applied <= 0:
		return
	var sector_of: Dictionary = skeleton.get("sector_of", {})
	var sector_applied: Dictionary = ledger.get("sector_applied", {})
	for cell in batch:
		var data: CellData = cells.get(cell) as CellData
		if data == null or data.terrain != CellData.TERRAIN_MOUNTAIN:
			continue
		var sector_key := String(sector_of.get(cell, ""))
		sector_applied[sector_key] = int(sector_applied.get(sector_key, 0)) + 1
	ledger["sector_applied"] = sector_applied


## 落格过滤：图内、非 protected、当前可走（未被先批占用）、扇区配额 < quota×1.5。
static func _cell_paintable(cells: Dictionary, protected: Dictionary, skeleton: Dictionary, ledger: Dictionary, cell: Vector2i, width: int, height: int) -> bool:
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return false
	if protected.has(cell):
		return false
	var data: CellData = cells.get(cell) as CellData
	if data == null or not data.walkable:
		return false
	var sector_of: Dictionary = skeleton.get("sector_of", {})
	var sector_key := String(sector_of.get(cell, ""))
	var quota: Dictionary = ledger.get("sector_quota", {})
	var sector_applied: Dictionary = ledger.get("sector_applied", {})
	return float(int(sector_applied.get(sector_key, 0))) < float(int(quota.get(sector_key, 0))) * QUOTA_SLACK


static func _budget_reached(ledger: Dictionary) -> bool:
	return int(ledger.get("applied", 0)) >= int(ledger.get("target", 0))


## 噪声八位分位：int(value_noise × 256)，scale=RIDGE_NOISE_SCALE（§2.1 脊噪声）。
static func _noise_q(cell: Vector2i, seed_value: int) -> int:
	return int(IntNoise.value_noise(cell.x, cell.y, seed_value, RIDGE_NOISE_SCALE) * 256.0)


## v 主轴的正交轴（与 place_pass_anchor 同约定）。
static func _perp_axis(v: Vector2i) -> Vector2i:
	return Vector2i(0, 1) if absi(v.x) >= absi(v.y) else Vector2i(1, 0)


## 宽度 → 垂直偏移序列（§2.1：w=1 [0]；w=2 [0,+1]；w=3 [0,+1,-1]）。
static func _width_offsets(w: int) -> Array[int]:
	if w >= 3:
		return [0, 1, -1]
	if w == 2:
		return [0, 1]
	return [0]


## 沿 bisector 射线自 ring=12 起走到最后一个图内格（首个越界前格）。
static func _edge_point(core: Vector2i, bisector: Vector2i, width: int, height: int) -> Vector2i:
	var best: Vector2i = SkeletonGen.ray_point(core, bisector, 11)
	var ring: int = 12
	while ring <= width + height:
		var candidate: Vector2i = SkeletonGen.ray_point(core, bisector, ring)
		if candidate.x < 0 or candidate.x >= width or candidate.y < 0 or candidate.y >= height:
			break
		best = candidate
		ring += 1
	return best


## 整数 DDA：主轴逐步推进、副轴 round_div 取格；含两端点，段内无重复格。
static func _walk_segment(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var delta: Vector2i = to_cell - from_cell
	var steps: int = maxi(absi(delta.x), absi(delta.y))
	var pts: Array[Vector2i] = []
	if steps == 0:
		pts.append(from_cell)
		return pts
	for s in range(steps + 1):
		pts.append(from_cell + Vector2i(SkeletonGen.round_div(delta.x * s, steps), SkeletonGen.round_div(delta.y * s, steps)))
	return pts


## 伪高程场（§2.2）：elev = max(0, 12 − 最近山距) × 1024 + 噪声八位。
## 多源 BFS 自全部山格起（含不可走格的几何距离）；无山 → 距离恒 12（纯噪声场）。
static func build_elevation(cells: Dictionary, width: int, height: int, seed_value: int) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			if (cells[cell] as CellData).terrain == CellData.TERRAIN_MOUNTAIN:
				dist[cell] = 0
				queue.append(cell)
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction in CARDINALS:
			var nb: Vector2i = current + direction
			if not cells.has(nb) or dist.has(nb):
				continue
			dist[nb] = int(dist[current]) + 1
			queue.append(nb)
	var elevation: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var d: int = mini(int(dist.get(cell, ELEV_DIST_CAP)), ELEV_DIST_CAP)
			var noise_q: int = int(IntNoise.value_noise(x, y, seed_value, RIDGE_NOISE_SCALE) * 256.0)
			elevation[cell] = (ELEV_DIST_CAP - d) * 1024 + noise_q
	return elevation


## 河湖计划（§2.3 湿度梯度）：每口固定消费 3 次 rng，分支不改变流位置。
static func roll_water_plans(skeleton: Dictionary, wind_dir: Vector2i, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var strength: float = float(cfg.get("moisture_gradient_strength", 0.2))
	var plans: Dictionary = {}
	var keys: Array = (skeleton.get("gate_keys", []) as Array).duplicate()
	keys.sort()
	for raw_key: Variant in keys:
		var key := String(raw_key)
		var card_id := String((skeleton.get("cards", {}) as Dictionary).get(key, "bastion"))
		var card_cfg: Dictionary = (skeleton.get("card_cfgs", {}) as Dictionary).get(card_id, {})
		var gate: Vector2i = (skeleton.get("gate_cells", {}) as Dictionary).get(key, Vector2i.ZERO)
		var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
		var rel := gate - core
		var dot: int = rel.x * wind_dir.x + rel.y * wind_dir.y
		var moist: float = strength * float(signi(dot))
		var roll_lake: float = rng.randf()
		var roll_extra: float = rng.randf()
		var lake_base: int = rng.randi_range(1, 2)        # 三连掷固定消费
		var plan := {"river": false, "lakes": 0}
		if bool(card_cfg.get("river", false)):
			plan["river"] = true                           # 河谷结构性必有河（渡口=牌面隘口）
		elif roll_extra < moist:
			plan["river"] = true                           # 湿侧加成河
		if card_cfg.has("lake"):
			plan["lakes"] = lake_base
			if roll_lake < absf(moist):
				plan["lakes"] = clampi(lake_base + signi(dot), 1, 3)
		elif bool(card_cfg.get("river", false)):
			plan["lakes"] = 1 if roll_lake < clampf(0.35 + moist, 0.0, 1.0) else 0
		if bool(skeleton.get("conservative", false)):
			plan["river"] = false                          # 保守剖面：无河（设计稿 §5）
		plans[key] = plan
	return plans


## 河流走线（§2.2）：扇区外缘最高格起梯度下降至边缘，卡坑就地成 3-5 格小湖；
## 落水前预演与本口当前 BFS 最短路的交点，恰保留 1 个 2 格渡口窗（多交点收敛
## 为一窗，其余照常落水，强制车道走渡口）。&"lane" 类保护格允许淹，其余保护格
## 不可落水亦不可流经——视作盆沿，河行至即卡坑成湖（apron/core 等永不进水）。
## rng 消费序：起点选取 0 次 + pond 尺寸至多 1 次（固定在 stuck 分支）。
static func trace_river(cells: Dictionary, skeleton: Dictionary, gate_key: String, elevation: Dictionary, protected: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary) -> Dictionary:
	var result := {"river_cells": [], "pond_cells": [], "ford_cells": []}
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var start: Vector2i = _river_start(cells, skeleton, gate_key, elevation, protected, core)
	if start.x < 0:
		ledger_note(ledger, "rivers", 0, 0, 0)
		return result
	# 梯度下降折线；卡坑 → pond 收尾（此处掷唯一一次 rng）。
	var polyline: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var pond: Array[Vector2i] = []
	var current: Vector2i = start
	for _step in range(RIVER_STEP_LIMIT):
		if current.x == 0 or current.y == 0 or current.x == width - 1 or current.y == height - 1:
			break
		var best := Vector2i(-1, -1)
		var best_elev: int = 0
		for direction in CARDINALS:
			var nb: Vector2i = current + direction
			if visited.has(nb) or not _water_paintable(cells, protected, nb):
				continue
			var nb_elev: int = int(elevation.get(nb, 0))
			if best.x < 0 or _elev_less(nb_elev, nb, best_elev, best):
				best = nb
				best_elev = nb_elev
		if best.x < 0 or best_elev >= int(elevation.get(current, 0)):
			pond = _collect_pond(cells, elevation, protected, visited, current, rng.randi_range(POND_MIN, POND_MAX))
			break
		current = best
		polyline.append(best)
		visited[best] = true
	# 渡口预规划（落水前）。
	var ford: Array[Vector2i] = _plan_ford(cells, skeleton, gate_key, polyline)
	var ford_lookup: Dictionary = {}
	for cell in ford:
		ford_lookup[cell] = true
	# 落水批：折线 ∪ pond − 渡口窗 − 非 lane 类保护格。
	var batch: Array[Vector2i] = []
	var batch_river: Dictionary = {}
	var batch_pond: Dictionary = {}
	for cell in polyline:
		if ford_lookup.has(cell) or not _water_paintable(cells, protected, cell):
			continue
		batch_river[cell] = true
		batch.append(cell)
	for cell in pond:
		if ford_lookup.has(cell) or batch_river.has(cell):
			continue
		batch_pond[cell] = true
		batch.append(cell)
	if batch.is_empty():
		ledger_note(ledger, "rivers", 0, 0, 0)
		return result
	var spawn_cells: Array[Vector2i] = []
	for raw_cell: Variant in (skeleton.get("spawn_cells", []) as Array):
		spawn_cells.append(raw_cell)
	var cfg: Dictionary = skeleton.get("cfg", {})
	var applied: int = _mg()._try_apply_obstacle_cells(cells, batch, CellData.TERRAIN_WATER, width, height, spawn_cells, core, cfg)
	ledger_note(ledger, "rivers", batch.size(), applied, batch.size() - applied)
	if applied <= 0:
		return result                                      # 整批回滚 → 空 ford
	var river_cells: Array = result["river_cells"]
	var pond_cells: Array = result["pond_cells"]
	for cell in batch:
		var data: CellData = cells.get(cell) as CellData
		if data == null or data.terrain != CellData.TERRAIN_WATER:
			continue
		if batch_pond.has(cell):
			pond_cells.append(cell)
		else:
			river_cells.append(cell)
	result["ford_cells"] = ford
	return result


## 湖泊放置（§2.3）：候选中心 = 本扇区、ring ≥ 8、距本扇区车道 cheb ≥ 4、
## 非 protected、可走（(y,x) 序收集）；中心/尺寸各掷一次后复用 _build_lake_cluster
## walker 长 blob，剔除 protected 格整批落水（连通回滚）并记账。候选空 → 记 0 跳过。
static func place_lakes(cells: Dictionary, skeleton: Dictionary, gate_key: String, lake_count: int, protected: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary) -> void:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var cfg: Dictionary = skeleton.get("cfg", {})
	var sector_of: Dictionary = skeleton.get("sector_of", {})
	var lane: Array = (skeleton.get("lanes", {}) as Dictionary).get(gate_key, [])
	var spawn_cells: Array[Vector2i] = []
	for raw_cell: Variant in (skeleton.get("spawn_cells", []) as Array):
		spawn_cells.append(raw_cell)
	for _i in range(lake_count):
		var candidates: Array[Vector2i] = []
		for y in range(height):
			for x in range(width):
				var cell := Vector2i(x, y)
				if String(sector_of.get(cell, "")) != gate_key:
					continue
				if maxi(absi(cell.x - core.x), absi(cell.y - core.y)) < LAKE_RING_MIN:
					continue
				if protected.has(cell):
					continue
				var data: CellData = cells.get(cell) as CellData
				if data == null or not data.walkable:
					continue
				if _min_cheb_to_lane(cell, lane) < LAKE_LANE_CLEARANCE:
					continue
				candidates.append(cell)
		if candidates.is_empty():
			ledger_note(ledger, "lakes", 0, 0, 0)
			continue
		var center: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var target_size: int = rng.randi_range(LAKE_SIZE_MIN, LAKE_SIZE_MAX)
		var cluster: Array[Vector2i] = _mg()._build_lake_cluster(cells, width, height, spawn_cells, core, cfg, rng, center, target_size)
		var batch: Array[Vector2i] = []
		for cell in cluster:
			if protected.has(cell):
				continue
			batch.append(cell)
		var applied: int = 0
		if not batch.is_empty():
			applied = _mg()._try_apply_obstacle_cells(cells, batch, CellData.TERRAIN_WATER, width, height, spawn_cells, core, cfg)
		ledger_note(ledger, "lakes", batch.size(), applied, batch.size() - applied)


## 河源：本扇区 ring ∈ [9,13]、非 protected、可走格中 elev 最大者；
## 平局 (y,x) 小者（y/x 升序扫描 + 严格大于即天然成立）。无候选 → (-1,-1)。
static func _river_start(cells: Dictionary, skeleton: Dictionary, gate_key: String, elevation: Dictionary, protected: Dictionary, core: Vector2i) -> Vector2i:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var sector_of: Dictionary = skeleton.get("sector_of", {})
	var best := Vector2i(-1, -1)
	var best_elev: int = -1
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			if String(sector_of.get(cell, "")) != gate_key:
				continue
			var ring: int = maxi(absi(cell.x - core.x), absi(cell.y - core.y))
			if ring < RIVER_RING_MIN or ring > RIVER_RING_MAX:
				continue
			if protected.has(cell):
				continue
			var data: CellData = cells.get(cell) as CellData
			if data == null or not data.walkable:
				continue
			var e: int = int(elevation.get(cell, 0))
			if e > best_elev:
				best = cell
				best_elev = e
	return best


## 卡坑成湖：自 stuck 格按 (elev, y, x) 升序区域生长收 target 格（stuck 格本身
## 已在折线内，不计入）；只收落水过滤可过的格，保证 pond 计数即可落水计数。
static func _collect_pond(cells: Dictionary, elevation: Dictionary, protected: Dictionary, visited: Dictionary, center: Vector2i, target: int) -> Array[Vector2i]:
	var pond: Array[Vector2i] = []
	var lookup: Dictionary = {center: true}
	while pond.size() < target:
		var best := Vector2i(-1, -1)
		var best_elev: int = 0
		for raw_seed: Variant in lookup.keys():
			var seed_cell: Vector2i = raw_seed
			for direction in CARDINALS:
				var nb: Vector2i = seed_cell + direction
				if lookup.has(nb) or visited.has(nb):
					continue
				if not _water_paintable(cells, protected, nb):
					continue
				var nb_elev: int = int(elevation.get(nb, 0))
				if best.x < 0 or _elev_less(nb_elev, nb, best_elev, best):
					best = nb
					best_elev = nb_elev
		if best.x < 0:
			break
		lookup[best] = true
		pond.append(best)
	return pond


## 渡口预规划（§2.2）：dist_gate BFS + 「dist 递减且 (y,x) 最小邻」自核心回溯重建
## 本口当前真实最短路 P；crossings = 河折线 ∩ P；chosen = 距本扇区锚格切比雪夫
## 最近者（平局 (y,x)）；窗 = [chosen, chosen + 河向]（chosen 为折线末格时取上一格
## 方向延伸；延伸格出图则回退 [上一格, chosen]）。无交点/折线过短 → 空（锚窗承担）。
static func _plan_ford(cells: Dictionary, skeleton: Dictionary, gate_key: String, polyline: Array[Vector2i]) -> Array[Vector2i]:
	var ford: Array[Vector2i] = []
	if polyline.size() < 2:
		return ford
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var gate: Vector2i = (skeleton.get("gate_cells", {}) as Dictionary).get(gate_key, core)
	var dist: Dictionary = _mg()._bfs_distances(cells, width, height, gate)
	if not dist.has(core):
		return ford
	var path_set: Dictionary = {core: true}
	var cursor: Vector2i = core
	while int(dist.get(cursor, 0)) > 0:
		var next_cell := Vector2i(-1, -1)
		for direction in CARDINALS:
			var nb: Vector2i = cursor + direction
			if not dist.has(nb) or int(dist[nb]) != int(dist[cursor]) - 1:
				continue
			if next_cell.x < 0 or _yx_less(nb, next_cell):
				next_cell = nb
		if next_cell.x < 0:
			return ford                                    # 防御：BFS 场必有递减邻
		cursor = next_cell
		path_set[cursor] = true
	var anchor_entry: Dictionary = (skeleton.get("anchors", {}) as Dictionary).get(gate_key, {})
	var anchor_cell: Vector2i = anchor_entry.get("cell", core)
	var chosen_idx: int = -1
	var chosen_d: int = 0
	for idx in range(polyline.size()):
		if not path_set.has(polyline[idx]):
			continue
		var d: int = maxi(absi(polyline[idx].x - anchor_cell.x), absi(polyline[idx].y - anchor_cell.y))
		if chosen_idx < 0 or d < chosen_d or (d == chosen_d and _yx_less(polyline[idx], polyline[chosen_idx])):
			chosen_idx = idx
			chosen_d = d
	if chosen_idx < 0:
		return ford
	var chosen: Vector2i = polyline[chosen_idx]
	if chosen_idx + 1 < polyline.size():
		ford.append(chosen)
		ford.append(polyline[chosen_idx + 1])
		return ford
	var extended: Vector2i = chosen + (chosen - polyline[chosen_idx - 1])
	if cells.has(extended):
		ford.append(chosen)
		ford.append(extended)
	else:
		ford.append(polyline[chosen_idx - 1])
		ford.append(chosen)
	return ford


## 河水可落格：图内、可走、非 protected——唯一豁免 &"lane" 类（§2.2 车道允许被淹）。
static func _water_paintable(cells: Dictionary, protected: Dictionary, cell: Vector2i) -> bool:
	var data: CellData = cells.get(cell) as CellData
	if data == null or not data.walkable:
		return false
	if protected.has(cell) and StringName(protected[cell]) != &"lane":
		return false
	return true


## (elev, y, x) 升序全序：决定性平局裁决。
static func _elev_less(elev_a: int, cell_a: Vector2i, elev_b: int, cell_b: Vector2i) -> bool:
	if elev_a != elev_b:
		return elev_a < elev_b
	return _yx_less(cell_a, cell_b)


static func _yx_less(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func _min_cheb_to_lane(cell: Vector2i, lane: Array) -> int:
	var best: int = 1 << 30
	for raw_cell: Variant in lane:
		var lane_cell: Vector2i = raw_cell
		best = mini(best, maxi(absi(cell.x - lane_cell.x), absi(cell.y - lane_cell.y)))
	return best
