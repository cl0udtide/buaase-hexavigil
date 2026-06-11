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
