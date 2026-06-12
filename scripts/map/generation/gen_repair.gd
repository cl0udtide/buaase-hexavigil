class_name MapGenRepair
extends RefCounted

## corridor 派生与约束修复（设计稿 S6①-⑥/§3）：验收对象 = 真实 BFS 最短路与
## corridor 走廊集（非作者车道，SF-1 手术）。修复改格分账：破坏性改写记
## ledger.repair_intrusion（≤ 阻挡 15%），建设性落山记 ledger.stages（预算补齐）。
## 决定性：全程无 RNG，一切裁决 (值, y, x) 全序。
## 回引 map_generator 静态助手用运行时 load（见计划「模块回引规则」）。

const FleshGen = preload("res://scripts/map/generation/flesh.gd")

const GRADE_SINGLE := &"single"
const GRADE_DUAL := &"dual"
const GRADE_OPEN := &"open"

const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const SPUR_MAX := 14               # ③ spur 条带总长硬上限（反链 ≤10 + 两端外溢）
const SPUR_MIN := 3                # ③ 低于此长的条带不可能成切割，直接跳过
const SPUR_OVERHANG := 2           # ③ 条带越出门-核包围盒的臂长（绕行代价 ≥ +4）
const POCKET_CLEAR_LIMIT := 12     # ⑤ 每轮清障格数上限
const REBALANCE_BATCH := 6         # ⑥ 欠收补切批大小
const CORRIDOR_CLEARANCE := 3      # ⑥ 候选距 corridor 格切比雪夫下限


static func _mg() -> GDScript:
	return load("res://scripts/map/map_generator.gd")


static func derive_corridor(cells: Dictionary, gate: Vector2i, core: Vector2i, slack: int = 3) -> Dictionary:
	var dist_gate: Dictionary = _bfs(cells, gate)
	var dist_core: Dictionary = _bfs(cells, core)
	var shortest: int = int(dist_gate.get(core, -1))
	if shortest < 0:
		return {"cells": {}, "shortest": -1}
	var corridor: Dictionary = {}
	for raw_cell: Variant in dist_gate.keys():
		if dist_core.has(raw_cell) and int(dist_gate[raw_cell]) + int(dist_core[raw_cell]) <= shortest + slack:
			corridor[raw_cell] = true
	return {"cells": corridor, "shortest": shortest}


static func derive_all_corridors(cells: Dictionary, skeleton: Dictionary, slack: int) -> Dictionary:
	var corridors: Dictionary = {}
	var keys: Array = (skeleton.get("gate_keys", []) as Array).duplicate()
	keys.sort()
	for raw_key: Variant in keys:
		corridors[String(raw_key)] = derive_corridor(cells, (skeleton["gate_cells"] as Dictionary)[raw_key], skeleton["core"], slack)
	return corridors


## 六步全量修复（S6①-⑥）：连通兜底 → 绕路上限 → 绕路下限 spur → 隘口分级 →
## 口袋 flood → 占比回调。入侵度（微创修复改写格，写 ledger.repair_intrusion）
## = 破坏性改写：① 开凿 + ② 破墙 + ⑤ 清障 + ⑥ 啃边（推倒已长地貌/凿穿）；
## 建设性落山（③ spur=支脉、④ 封堵=合龙、⑥ 欠收补切=贴地貌长肉，§3 自然感列）
## 是地貌预算补齐（设计稿「缺口由 S6⑥ 台账回调补齐」），只记台账 stages 不计
## 入侵度——长肉欠收时建设量本身即可超过阻挡总数 15%，按原文计数则占比带与
## 入侵度上限数学互斥（适配记录，详见任务报告）。
static func full_repair(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, elevation: Dictionary, ledger: Dictionary) -> Dictionary:
	var cfg: Dictionary = skeleton.get("cfg", {})
	var grades: Dictionary = {}
	var intrusion: int = 0
	# ① 连通（构造已保证，鞍部软代价开凿兜底）。
	var carved: int = _repair_connectivity(cells, skeleton, cfg)
	if carved < 0:
		return _verdict(cells, skeleton, ledger, false, "connectivity", grades, intrusion)
	FleshGen.ledger_note(ledger, "repair_carve", carved, carved, 0)
	intrusion += carved
	# ② 绕路上限（复用 _repair_gate_detours，快照差分计入侵度）。
	var cap_carved: int = _repair_caps(cells, skeleton, cfg)
	FleshGen.ledger_note(ledger, "repair_caps", cap_carved, cap_carved, 0)
	intrusion += cap_carved
	# ③ 绕路下限：直线段旁插山脊 spur（预算补齐，不计入侵度）。
	var floors: Dictionary = _repair_floors(cells, skeleton, protected, cfg)
	FleshGen.ledger_note(ledger, "repair_spur", int(floors["applied"]), int(floors["applied"]), 0)
	if not bool(floors["ok"]):
		return _verdict(cells, skeleton, ledger, false, "detour_floor", grades, intrusion)
	# ④ 隘口分级：旁路窗封堵（合龙=建设性，不计入侵度）→ single/dual/open + 自证。
	var grading: Dictionary = _grade_passes(cells, skeleton, protected, elevation, cfg)
	FleshGen.ledger_note(ledger, "repair_grade", int(grading["applied"]), int(grading["applied"]), 0)
	grades = grading["grades"]
	if not bool(grading["ok"]):
		return _verdict(cells, skeleton, ledger, false, "grade_mismatch", grades, intrusion)
	# ⑤ 口袋 flood 复检：不足按伪高程升序清障凿山坳。
	var pockets: Dictionary = _repair_pockets(cells, skeleton, protected, elevation, cfg)
	FleshGen.ledger_note(ledger, "repair_pocket", int(pockets["intrusion"]), int(pockets["intrusion"]), 0)
	intrusion += int(pockets["intrusion"])
	if not bool(pockets["ok"]):
		return _verdict(cells, skeleton, ledger, false, "pocket", grades, intrusion)
	# ⑥ 占比回调：欠收补切（预算补齐）/ 超收啃边（计入侵度）。
	var rebalance: Dictionary = _rebalance_ratio(cells, skeleton, protected, elevation, cfg)
	FleshGen.ledger_note(ledger, "repair_ratio", int(rebalance["filled"]) + int(rebalance["removed"]), int(rebalance["filled"]) + int(rebalance["removed"]), 0)
	intrusion += int(rebalance["removed"])
	if not bool(rebalance["ok"]):
		return _verdict(cells, skeleton, ledger, false, "ratio", grades, intrusion)
	# 收尾：入侵度上限自检（修复是微创不是重画）。
	var repair_cfg: Dictionary = cfg.get("repair", {})
	var max_intrusion: int = int(ceil(float(_blocked_count(cells)) * float(repair_cfg.get("intrusion_max_per_map", 0.15))))
	if intrusion > max_intrusion:
		return _verdict(cells, skeleton, ledger, false, "intrusion", grades, intrusion)
	return _verdict(cells, skeleton, ledger, true, "", grades, intrusion)


## ① 连通兜底：key 升序，每口不可达 → _soft_cost_path 取路并把路上阻挡格还原
## plain（口/核/资源格防御性跳过，与 _repair_gate_detours 同条件）。-1 = 失败。
static func _repair_connectivity(cells: Dictionary, skeleton: Dictionary, cfg: Dictionary) -> int:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var gate_map: Dictionary = skeleton.get("gate_cells", {})
	var rounds: int = maxi(int(cfg.get("max_repair_rounds", 3)), 1)
	var carved: int = 0
	for raw_key: Variant in _sorted_gate_keys(skeleton):
		var gate: Vector2i = gate_map[raw_key]
		for _round in range(rounds):
			if _bfs(cells, gate).has(core):
				break
			var path: Array[Vector2i] = _mg()._soft_cost_path(cells, width, height, gate, core, cfg)
			var carved_any := false
			for path_cell in path:
				var data: CellData = cells.get(path_cell) as CellData
				if data == null or data.walkable:
					continue
				if data.spawn_key != StringName() or data.is_core or data.resource_type != StringName():
					continue
				data.set_base_terrain(CellData.TERRAIN_PLAIN)
				carved += 1
				carved_any = true
			if not carved_any:
				break
		if not _bfs(cells, gate).has(core):
			return -1
	return carved


## ② 绕路上限：快照阻挡集 → 复用 _repair_gate_detours → 翻面格差分计入侵度。
static func _repair_caps(cells: Dictionary, skeleton: Dictionary, cfg: Dictionary) -> int:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var snapshot: Dictionary = {}
	for raw_cell: Variant in cells.keys():
		if not (cells[raw_cell] as CellData).walkable:
			snapshot[raw_cell] = true
	_mg()._repair_gate_detours(cells, width, height, _spawn_list(skeleton), core, cfg)
	var flipped: int = 0
	for raw_cell: Variant in snapshot.keys():
		if (cells[raw_cell] as CellData).walkable:
			flipped += 1
	return flipped


## ③ 绕路下限（§3「直线段旁插山脊 spur」）：ratio < floor 的口沿真实最短路
## 自中点向两端扫锚位，锚位处沿门→核心行进向的单调反链插山脊条带，
## 每轮至多收下一墙，收下条件 = 本口路长严格变长、本口 ≤ cap 且全口 cap 保持
## （入带即停）。轮尽仍 < floor → fail。spur 格记台账 "repair_spur"（地貌预算
## 补齐），不计微创入侵度——见任务报告适配记录。
## 适配记录（详见任务报告）：a) 锚位不限中点（中点=最宽漏斗腰，单点必败）；
## b) 收下放宽到「严格推进」多墙成脉（§3 spur 即山脉支脉，单墙 +2 不足跨 floor）；
## c) 条带可越 &"lane" 格（SF-1：车道非验收对象，连通由 _try_apply 保证；
##    不破例则开放车道是 manhattan 级捷径，floor 数学不可达），
##    其余保护类含 ford/aperture/pocket 恒不可触；
## d) 条带为锚位两臂走到自然停点（图缘/既有阻挡/保护格/出包围盒 2 格）的最大
##    反链段（≤14 格），替代 6-10 固定长——短臂固定 2 时切割必漏（探针实证）。
static func _repair_floors(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, cfg: Dictionary) -> Dictionary:
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var gate_map: Dictionary = skeleton.get("gate_cells", {})
	var floor_ratio: float = float(cfg.get("detour_floor", 1.15))
	var rounds: int = maxi(int(cfg.get("max_repair_rounds", 3)), 1)
	var applied_total: int = 0
	for raw_key: Variant in _sorted_gate_keys(skeleton):
		var gate: Vector2i = gate_map[raw_key]
		var lifted := false
		for _round in range(rounds):
			if _gate_ratio(cells, gate, core) >= floor_ratio:
				lifted = true
				break
			var applied: int = _try_spur(cells, skeleton, protected, cfg, gate)
			if applied <= 0:
				break	# 无墙可落，重试同输入必同败——提前判负
			applied_total += applied
		if not lifted and _gate_ratio(cells, gate, core) < floor_ratio:
			return {"ok": false, "applied": applied_total}
	return {"ok": true, "applied": applied_total}


## 单轮 spur：沿当前最短路自中点向两端扫锚位，落下首个「严格推进且全口 cap
## 保持」的山脊条带并返回改格数；无可收墙返回 0。批内格落墙前均可走，还原即
## 整批回 plain（精确逆操作）。条带方向取门→核心整体行进向的单调反链
## （斜向行进 → 对角条带）：单调走廊唯有沿反链才存在短截面，轴向墙在宽漏斗
## 上必漏（探针实证）；两臂自锚位走到自然停点（图缘合龙/既有阻挡合龙/保护格
## 截断/越出门-核包围盒 SPUR_OVERHANG 格），总长 ≤ SPUR_MAX。
static func _try_spur(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, cfg: Dictionary, gate: Vector2i) -> int:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var cap: float = float(cfg.get("detour_cap", 1.6))
	var spawn_cells: Array[Vector2i] = _spawn_list(skeleton)
	var path: Array[Vector2i] = _shortest_path(cells, gate, core)
	if path.size() < 3:
		return 0
	var base_len: int = path.size() - 1
	var manhattan: int = maxi(absi(gate.x - core.x) + absi(gate.y - core.y), 1)
	var travel := Vector2i(signi(core.x - gate.x), signi(core.y - gate.y))
	var perp: Vector2i
	if travel.x != 0 and travel.y != 0:
		perp = Vector2i(travel.x, -travel.y)	# 斜向行进的单调反链方向
	else:
		perp = Vector2i(travel.y, -travel.x)	# 轴向行进 → 标准正交
	var rect_lo := Vector2i(mini(gate.x, core.x), mini(gate.y, core.y))
	var rect_hi := Vector2i(maxi(gate.x, core.x), maxi(gate.y, core.y))
	var mid_idx: int = path.size() / 2
	for offset in range(path.size()):
		var anchor_idx: int = mid_idx + ((offset + 1) / 2 if offset % 2 == 1 else -(offset / 2))
		if anchor_idx < 1 or anchor_idx > path.size() - 2:
			continue
		var batch: Array[Vector2i] = _spur_strip(cells, protected, path[anchor_idx], perp, rect_lo, rect_hi, width, height)
		if batch.size() < SPUR_MIN:
			continue
		var applied: int = _mg()._try_apply_obstacle_cells(cells, batch, CellData.TERRAIN_MOUNTAIN, width, height, spawn_cells, core, cfg)
		if applied <= 0:
			continue
		var new_len: int = int(_bfs(cells, gate).get(core, -1))
		if new_len > base_len and float(new_len) / float(manhattan) <= cap and _all_caps_ok(cells, skeleton, cap):
			return applied
		for cell in batch:
			(cells.get(cell) as CellData).set_base_terrain(CellData.TERRAIN_PLAIN)
	return 0


## 过锚位的最大可落反链条带：两臂沿 ±perp 走到自然停点。锚位不可落 → 空。
static func _spur_strip(cells: Dictionary, protected: Dictionary, anchor: Vector2i, perp: Vector2i, rect_lo: Vector2i, rect_hi: Vector2i, width: int, height: int) -> Array[Vector2i]:
	var batch: Array[Vector2i] = []
	if not _spur_blockable(cells, protected, anchor, width, height):
		return batch
	batch.append(anchor)
	for dir_sign: int in [1, -1]:
		var k: int = 1
		while batch.size() < SPUR_MAX:
			var cell: Vector2i = anchor + perp * (k * dir_sign)
			if not _spur_blockable(cells, protected, cell, width, height):
				break
			batch.append(cell)
			if _beyond_rect(cell, rect_lo, rect_hi) >= SPUR_OVERHANG:
				break
			k += 1
	return batch


## 格越出门-核包围盒的切比雪夫距离（盒内 = 0）。
static func _beyond_rect(cell: Vector2i, rect_lo: Vector2i, rect_hi: Vector2i) -> int:
	var dx: int = maxi(maxi(rect_lo.x - cell.x, cell.x - rect_hi.x), 0)
	var dy: int = maxi(maxi(rect_lo.y - cell.y, cell.y - rect_hi.y), 0)
	return maxi(dx, dy)


## ④ 隘口分级：steppe → open；其余口取验收窗 A（fords 优先，缺失/空回退锚
## aperture），corridor 环带 [ring_A−1, ring_A+1] 去 A 膨胀(cheb≤1) 后 8 连通聚类
## 为旁路窗，逐窗（窗内最小 (y,x) 升序）按 elev 降序封堵；破 cap/连通 → 整批
## 还原判 dual；全封后复测最短路穿 A → single。不穿且零旁路窗 → 自证失败。
static func _grade_passes(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, elevation: Dictionary, cfg: Dictionary) -> Dictionary:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var gate_map: Dictionary = skeleton.get("gate_cells", {})
	var cards: Dictionary = skeleton.get("cards", {})
	var spawn_cells: Array[Vector2i] = _spawn_list(skeleton)
	var cap: float = float(cfg.get("detour_cap", 1.6))
	var slack: int = int(cfg.get("corridor_slack", 3))
	var grades: Dictionary = {}
	var applied_total: int = 0
	for raw_key: Variant in _sorted_gate_keys(skeleton):
		var key := String(raw_key)
		if String(cards.get(key, "")) == "steppe":
			grades[key] = GRADE_OPEN
			continue
		var gate: Vector2i = gate_map[key]
		var win: Array[Vector2i] = _acceptance_window(skeleton, key)
		if win.is_empty():
			return {"ok": false, "grades": grades, "applied": applied_total}
		var ring_a: int = _ring(win[0], core)
		var dilation: Dictionary = {}
		for cell in win:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					dilation[cell + Vector2i(dx, dy)] = true
		var corridor: Dictionary = derive_corridor(cells, gate, core, slack)
		var bypass: Array[Vector2i] = []
		for raw_cell: Variant in (corridor["cells"] as Dictionary).keys():
			var cell: Vector2i = raw_cell
			if absi(_ring(cell, core) - ring_a) > 1 or dilation.has(cell):
				continue
			bypass.append(cell)
		var windows: Array = _cluster8(bypass)
		var dual := false
		for raw_window: Variant in windows:
			var batch: Array[Vector2i] = []
			for raw_cell: Variant in (raw_window as Array):
				var cell: Vector2i = raw_cell
				if _blockable(cells, protected, cell, width, height):
					batch.append(cell)
			_sort_by_elev(batch, elevation, false)
			if batch.is_empty():
				continue
			var applied: int = _mg()._try_apply_obstacle_cells(cells, batch, CellData.TERRAIN_MOUNTAIN, width, height, spawn_cells, core, cfg)
			if applied <= 0:
				dual = true	# 封堵即断连：该窗是承重走廊，如实判双口
				break
			if not _all_caps_ok(cells, skeleton, cap):
				for cell in batch:
					(cells.get(cell) as CellData).set_base_terrain(CellData.TERRAIN_PLAIN)
				dual = true
				break
			applied_total += applied
		if dual:
			grades[key] = GRADE_DUAL
			continue
		var crosses := false
		var path: Array[Vector2i] = _shortest_path(cells, gate, core)
		for cell in win:
			if path.has(cell):
				crosses = true
				break
		grades[key] = GRADE_SINGLE if crosses else GRADE_DUAL
		if not crosses and windows.is_empty():
			return {"ok": false, "grades": grades, "applied": applied_total}
	return {"ok": true, "grades": grades, "applied": applied_total}


## 验收窗：skeleton.fords[key] 非空用渡口窗，否则锚 aperture——fords 可能因
## 河流整批回滚而缺键或为空（陈旧空值），均容忍回退。
static func _acceptance_window(skeleton: Dictionary, key: String) -> Array[Vector2i]:
	var raw_win: Array = (skeleton.get("fords", {}) as Dictionary).get(key, [])
	if raw_win.is_empty():
		var anchors: Dictionary = skeleton.get("anchors", {})
		raw_win = (anchors.get(key, {}) as Dictionary).get("aperture", [])
	var win: Array[Vector2i] = []
	for raw_cell: Variant in raw_win:
		win.append(raw_cell)
	return win


## ⑤ 口袋 flood：非 steppe 口自验收窗内侧种子 flood ≤ pocket_flood_limit 数 plain
## 可建格（规约同测试，种子去重故计数只少不多——保守）；不足取 flood 区 4 邻阻挡格
## 按 (elev, y, x) 升序逐格还原 plain 重 flood，每轮 ≤ POCKET_CLEAR_LIMIT 格。
static func _repair_pockets(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, elevation: Dictionary, cfg: Dictionary) -> Dictionary:
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var cards: Dictionary = skeleton.get("cards", {})
	var pass_cfg: Dictionary = cfg.get("pass", {})
	var flood_limit: int = int(pass_cfg.get("pocket_flood_limit", 12))
	var min_plain: int = int(pass_cfg.get("pocket_min_plain", 6))
	var rounds: int = maxi(int(cfg.get("max_repair_rounds", 3)), 1)
	var intrusion: int = 0
	for raw_key: Variant in _sorted_gate_keys(skeleton):
		var key := String(raw_key)
		if String(cards.get(key, "")) == "steppe":
			continue
		var win: Array[Vector2i] = _acceptance_window(skeleton, key)
		var satisfied := false
		for _round in range(rounds):
			var cleared: int = 0
			while true:
				var flood: Dictionary = _pocket_flood(cells, win, core, flood_limit)
				if int(flood["plain"]) >= min_plain:
					satisfied = true
					break
				if cleared >= POCKET_CLEAR_LIMIT:
					break
				var cand: Vector2i = _pocket_clear_candidate(cells, protected, flood["region"], elevation)
				if cand.x < 0:
					break
				(cells.get(cand) as CellData).set_base_terrain(CellData.TERRAIN_PLAIN)
				cleared += 1
				intrusion += 1
			if satisfied:
				break
		if not satisfied:
			return {"ok": false, "intrusion": intrusion}
	return {"ok": true, "intrusion": intrusion}


## 自验收窗内侧（核心向更近邻）种子 flood；返回 {"plain": int, "region": Dictionary}。
static func _pocket_flood(cells: Dictionary, win: Array[Vector2i], core: Vector2i, flood_limit: int) -> Dictionary:
	var dist_core: Dictionary = _bfs(cells, core)
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	for cell in win:
		for direction in CARDINALS:
			var nb: Vector2i = cell + direction
			if not cells.has(nb) or not dist_core.has(nb) or dist.has(nb):
				continue
			if int(dist_core[nb]) >= int(dist_core.get(cell, 1 << 30)):
				continue
			dist[nb] = 0
			queue.append(nb)
	var head: int = 0
	var plain: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var data: CellData = cells[current]
		if data.walkable and data.buildable and data.terrain == CellData.TERRAIN_PLAIN and data.resource_type == StringName():
			plain += 1
		if int(dist[current]) >= flood_limit:
			continue
		for direction in CARDINALS:
			var nb: Vector2i = current + direction
			if not cells.has(nb) or dist.has(nb) or not (cells[nb] as CellData).walkable:
				continue
			dist[nb] = int(dist[current]) + 1
			queue.append(nb)
	return {"plain": plain, "region": dist}


## flood 区 4 邻阻挡格中 (elev, y, x) 最小者（凿山坳自最低处）；无候选 → (-1,-1)。
static func _pocket_clear_candidate(cells: Dictionary, protected: Dictionary, region: Dictionary, elevation: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_elev: int = 0
	for raw_cell: Variant in region.keys():
		var cell: Vector2i = raw_cell
		for direction in CARDINALS:
			var nb: Vector2i = cell + direction
			if protected.has(nb):
				continue
			var data: CellData = cells.get(nb) as CellData
			if data == null or data.walkable:
				continue
			if data.spawn_key != StringName() or data.is_core or data.resource_type != StringName():
				continue
			var nb_elev: int = int(elevation.get(nb, 0))
			if best.x < 0 or nb_elev < best_elev or (nb_elev == best_elev and _yx_less(nb, best)):
				best = nb
				best_elev = nb_elev
	return best


## ⑥ 占比回调：欠收 → 距全部 corridor 格 cheb ≥ 3、非 steppe 扇区、按 (elev 降,
## y, x) 每批 6 格补切（corridor 外加格不动最短路，cap 不受扰；预算补齐，记
## "filled"）；超收 → 边界阻挡格按 (elev 升, y, x) 啃边（微创，记 "removed"）。
## 轮尽出带（±0.02 容差）→ 失败。
static func _rebalance_ratio(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, elevation: Dictionary, cfg: Dictionary) -> Dictionary:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var spawn_cells: Array[Vector2i] = _spawn_list(skeleton)
	var band: Array = (skeleton.get("archetype", {}) as Dictionary).get("ratio_band", [0.20, 0.26])
	var lo: float = float(band[0])
	var hi: float = float(band[1])
	var total: int = maxi(width * height, 1)
	var rounds: int = maxi(int(cfg.get("max_repair_rounds", 3)), 1)
	var slack: int = int(cfg.get("corridor_slack", 3))
	var filled: int = 0
	var removed: int = 0
	for _round in range(rounds):
		var blocked: int = _blocked_count(cells)
		if float(blocked) / float(total) >= lo and float(blocked) / float(total) <= hi:
			break
		if float(blocked) / float(total) < lo:
			var candidates: Array[Vector2i] = _fill_candidates(cells, skeleton, protected, elevation, slack)
			var idx: int = 0
			while float(blocked) / float(total) < lo and idx < candidates.size():
				var batch: Array[Vector2i] = []
				while batch.size() < REBALANCE_BATCH and idx < candidates.size():
					batch.append(candidates[idx])
					idx += 1
				var applied: int = _mg()._try_apply_obstacle_cells(cells, batch, CellData.TERRAIN_MOUNTAIN, width, height, spawn_cells, core, cfg)
				blocked += applied
				filled += applied
		else:
			var removals: Array[Vector2i] = _edge_blocked_cells(cells, protected, elevation)
			var ridx: int = 0
			while float(blocked) / float(total) > hi and ridx < removals.size():
				(cells.get(removals[ridx]) as CellData).set_base_terrain(CellData.TERRAIN_PLAIN)
				ridx += 1
				blocked -= 1
				removed += 1
	var final_ratio: float = float(_blocked_count(cells)) / float(total)
	var ok: bool = final_ratio >= lo - 0.02 and final_ratio <= hi + 0.02
	return {"ok": ok, "filled": filled, "removed": removed}


## 欠收补切候选：可走、非 protected、距全部 corridor 格 cheb ≥ CORRIDOR_CLEARANCE、
## 所在扇区牌 ≠ steppe、无口/核/资源；(elev 降, y, x) 序。
static func _fill_candidates(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, elevation: Dictionary, slack: int) -> Array[Vector2i]:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var gate_map: Dictionary = skeleton.get("gate_cells", {})
	var cards: Dictionary = skeleton.get("cards", {})
	var sector_of: Dictionary = skeleton.get("sector_of", {})
	var near_corridor: Dictionary = {}
	for raw_key: Variant in _sorted_gate_keys(skeleton):
		var corridor: Dictionary = derive_corridor(cells, gate_map[raw_key], core, slack)
		for raw_cell: Variant in (corridor["cells"] as Dictionary).keys():
			var cell: Vector2i = raw_cell
			for dy in range(-(CORRIDOR_CLEARANCE - 1), CORRIDOR_CLEARANCE):
				for dx in range(-(CORRIDOR_CLEARANCE - 1), CORRIDOR_CLEARANCE):
					near_corridor[cell + Vector2i(dx, dy)] = true
	var candidates: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			if near_corridor.has(cell) or not _blockable(cells, protected, cell, width, height):
				continue
			if String(cards.get(String(sector_of.get(cell, "")), "")) == "steppe":
				continue
			candidates.append(cell)
	_sort_by_elev(candidates, elevation, false)
	return candidates


## 超收啃边候选：阻挡格、≥1 可走 4 邻、非 protected；(elev 升, y, x) 序（啃边安全）。
static func _edge_blocked_cells(cells: Dictionary, protected: Dictionary, elevation: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for raw_cell: Variant in cells.keys():
		var cell: Vector2i = raw_cell
		if protected.has(cell) or (cells[cell] as CellData).walkable:
			continue
		for direction in CARDINALS:
			var nb: Vector2i = cell + direction
			if cells.has(nb) and (cells[nb] as CellData).walkable:
				result.append(cell)
				break
	_sort_by_elev(result, elevation, true)
	return result


static func _verdict(cells: Dictionary, skeleton: Dictionary, ledger: Dictionary, ok: bool, fail_reason: String, grades: Dictionary, intrusion: int) -> Dictionary:
	var cfg: Dictionary = skeleton.get("cfg", {})
	ledger["repair_intrusion"] = int(ledger.get("repair_intrusion", 0)) + intrusion
	return {
		"ok": ok, "fail_reason": fail_reason, "pass_grades": grades,
		"corridors": derive_all_corridors(cells, skeleton, int(cfg.get("corridor_slack", 3))),
		"intrusion": intrusion,
	}


## 与 map_generator._bfs_distances 同语义，但以 cells.has 判界（模块自洽）。
static func _bfs(cells: Dictionary, origin: Vector2i) -> Dictionary:
	var dist: Dictionary = {origin: 0}
	var queue: Array[Vector2i] = [origin]
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction in CARDINALS:
			var neighbor: Vector2i = current + direction
			if dist.has(neighbor) or not cells.has(neighbor):
				continue
			var data: CellData = cells.get(neighbor) as CellData
			if data == null or not data.walkable:
				continue
			dist[neighbor] = int(dist[current]) + 1
			queue.append(neighbor)
	return dist


## 真实最短路重建（规约同测试 _shortest_path_cells）：BFS 自门，自核心按
## 「dist 递减且 (y,x) 最小邻」回溯；返回 gate→core 有序路径，不可达 []。
static func _shortest_path(cells: Dictionary, gate: Vector2i, core: Vector2i) -> Array[Vector2i]:
	var dist: Dictionary = _bfs(cells, gate)
	if not dist.has(core):
		return []
	var reversed_path: Array[Vector2i] = [core]
	var current: Vector2i = core
	while current != gate:
		var best := Vector2i(-1, -1)
		var best_dist: int = int(dist[current])
		for direction in CARDINALS:
			var nb: Vector2i = current + direction
			if not dist.has(nb) or int(dist[nb]) >= best_dist:
				continue
			if best.x < 0 or _yx_less(nb, best):
				best = nb
		if best.x < 0:
			return []
		reversed_path.append(best)
		current = best
	reversed_path.reverse()
	return reversed_path


static func _gate_ratio(cells: Dictionary, gate: Vector2i, core: Vector2i) -> float:
	var path_len: int = int(_bfs(cells, gate).get(core, -1))
	if path_len <= 0:
		return -1.0
	return float(path_len) / float(maxi(absi(gate.x - core.x) + absi(gate.y - core.y), 1))


static func _all_caps_ok(cells: Dictionary, skeleton: Dictionary, cap: float) -> bool:
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var gate_map: Dictionary = skeleton.get("gate_cells", {})
	for raw_key: Variant in _sorted_gate_keys(skeleton):
		var ratio: float = _gate_ratio(cells, gate_map[raw_key], core)
		if ratio < 0.0 or ratio > cap:
			return false
	return true


## 修复落山过滤：图内、非 protected（含 ford/aperture）、可走、无口/核/资源。
static func _blockable(cells: Dictionary, protected: Dictionary, cell: Vector2i, width: int, height: int) -> bool:
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height or protected.has(cell):
		return false
	var data: CellData = cells.get(cell) as CellData
	if data == null or not data.walkable:
		return false
	return data.spawn_key == StringName() and not data.is_core and data.resource_type == StringName()


## spur 专用落山过滤：同 _blockable 但放行 &"lane" 类（SF-1，见 _repair_floors 注）。
static func _spur_blockable(cells: Dictionary, protected: Dictionary, cell: Vector2i, width: int, height: int) -> bool:
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return false
	if protected.has(cell) and StringName(protected[cell]) != &"lane":
		return false
	var data: CellData = cells.get(cell) as CellData
	if data == null or not data.walkable:
		return false
	return data.spawn_key == StringName() and not data.is_core and data.resource_type == StringName()


## 8 连通聚类：窗按窗内最小 (y,x) 升序（扫描序自然成立），窗内格 (y,x) 升序。
static func _cluster8(cells_list: Array[Vector2i]) -> Array:
	var lookup: Dictionary = {}
	for cell in cells_list:
		lookup[cell] = true
	var ordered: Array[Vector2i] = cells_list.duplicate()
	ordered.sort_custom(_yx_less)
	var seen: Dictionary = {}
	var clusters: Array = []
	for cell in ordered:
		if seen.has(cell):
			continue
		var cluster: Array[Vector2i] = [cell]
		seen[cell] = true
		var head: int = 0
		while head < cluster.size():
			var current: Vector2i = cluster[head]
			head += 1
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nb: Vector2i = current + Vector2i(dx, dy)
					if lookup.has(nb) and not seen.has(nb):
						seen[nb] = true
						cluster.append(nb)
		cluster.sort_custom(_yx_less)
		clusters.append(cluster)
	return clusters


## (elev, y, x) 全序原地排序；ascending=false 取 elev 降序（平局恒 (y,x) 升序）。
static func _sort_by_elev(batch: Array[Vector2i], elevation: Dictionary, ascending: bool) -> void:
	batch.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var elev_a: int = int(elevation.get(a, 0))
		var elev_b: int = int(elevation.get(b, 0))
		if elev_a != elev_b:
			return elev_a < elev_b if ascending else elev_a > elev_b
		return _yx_less(a, b))


static func _sorted_gate_keys(skeleton: Dictionary) -> Array:
	var keys: Array = (skeleton.get("gate_keys", []) as Array).duplicate()
	keys.sort()
	return keys


static func _spawn_list(skeleton: Dictionary) -> Array[Vector2i]:
	var spawn_cells: Array[Vector2i] = []
	for raw_cell: Variant in (skeleton.get("spawn_cells", []) as Array):
		spawn_cells.append(raw_cell)
	return spawn_cells


static func _blocked_count(cells: Dictionary) -> int:
	var blocked: int = 0
	for raw_cell: Variant in cells.keys():
		if not (cells[raw_cell] as CellData).walkable:
			blocked += 1
	return blocked


static func _ring(cell: Vector2i, core: Vector2i) -> int:
	return maxi(absi(cell.x - core.x), absi(cell.y - core.y))


static func _yx_less(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
