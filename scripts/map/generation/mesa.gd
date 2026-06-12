class_name MapGenMesa
extends RefCounted

## 天然高台放置（设计稿 §2.4 修订版）：平台阵地、战位锚定、评分制、
## 逐座落地→重派生 corridor→复检→回滚 反漂移闭环。
## 决定性：随机性仅尺寸/座数掷点（消费序固定：starter 尺寸 → 每配额座 1 掷 →
## target_count 1 掷 → 每填充座 1 掷），候选挑选零随机（(score 降, y, x, 形状序) 全序）。
## 回引 map_generator 静态助手用运行时 load（见计划「模块回引规则」）。

const GenRepairMod = preload("res://scripts/map/generation/gen_repair.gd")
const FleshGen = preload("res://scripts/map/generation/flesh.gd")

const KIND_STARTER := &"starter"
const KIND_QUOTA := &"quota"
const KIND_FILLER := &"filler"
const TRIALS_PER_SLOT := 40        # 每槽位候选试验上限（含连通回滚的空试）
const HUG_DIST := 2                # 验收窗/汇流点贴靠半径（§2.4 评分原文 cheb≤2）
const MIN_SHAPE_SIZE := 3          # 目录最小形状（配额座尺寸掷预留基数）

## 形状目录（§2.4 修订版）：1×3 / 1×4 / 2×3 / L / T，无独立 2×2，5 格走 L5/T5。
const SHAPES: Dictionary = {
	3: [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	],
	4: [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
		[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
	],
	5: [
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
		[Vector2i(3, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
		[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2)],
	],
	6: [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	],
}


static func _mg() -> GDScript:
	return load("res://scripts/map/map_generator.gd")


## 入口（契约见计划总表）：① starter（核心环带）→ ② 配额座（mesa_quota>0 的牌，
## gate_key 升序，贴本扇区验收窗）→ ③ 填充座至 target_count。
## 返回 {"ok", "degraded", "mesas": Array[Dictionary], "corridors"}；
## mesa 记录 {"cells": Array[Vector2i], "kind": StringName, "gate_key": String}。
static func place_mesas(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, corridors: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary) -> Dictionary:
	var cfg: Dictionary = skeleton.get("cfg", {})
	var mesa_cfg: Dictionary = cfg.get("mesa", {})
	var starter_cfg: Dictionary = mesa_cfg.get("starter", {})
	var count_min: int = int(mesa_cfg.get("count_min", 4))
	var count_max: int = int(mesa_cfg.get("count_max", 6))
	var count_floor: int = int(mesa_cfg.get("count_floor_degraded", 3))
	var cells_min: int = int(mesa_cfg.get("cells_min", 14))
	var cells_max: int = int(mesa_cfg.get("cells_max", 24))
	var ctx: Dictionary = _build_ctx(cells, skeleton, protected)
	var mesas: Array[Dictionary] = []
	var live: Dictionary = corridors
	# ① 起手保底台：全格 ring(core) 入 [ring_min, ring_max]。
	var starter_size: int = rng.randi_range(int(starter_cfg.get("size_min", 3)), int(starter_cfg.get("size_max", 4)))
	live = _place_slot_with_fallback(ctx, mesas, ledger, live, KIND_STARTER, "", starter_size)
	# ② 战位配额座。尺寸掷预留后续配额座最小形状量（适配：计划仅约束填充座掷，
	# 但 4 个配额扇区时无预留可掷爆 cells_max、挤掉后续配额保障——预留下界
	# 归纳保证每座可掷 ≥ MIN_SHAPE_SIZE 且总量恒 ≤ cells_max，详见任务报告）。
	var quota_keys: Array = []
	for raw_key: Variant in _sorted_gate_keys(skeleton):
		var card_id := String((skeleton.get("cards", {}) as Dictionary).get(String(raw_key), ""))
		var card_cfg: Dictionary = (skeleton.get("card_cfgs", {}) as Dictionary).get(card_id, {})
		if int(card_cfg.get("mesa_quota", 0)) > 0:
			quota_keys.append(String(raw_key))
	for i in range(quota_keys.size()):
		var reserve: int = MIN_SHAPE_SIZE * (quota_keys.size() - 1 - i)
		var quota_size: int = _roll_size(rng, mesa_cfg, cells_max - _cells_total(mesas) - reserve)
		if quota_size <= 0:
			continue
		live = _place_slot_with_fallback(ctx, mesas, ledger, live, KIND_QUOTA, String(quota_keys[i]), quota_size)
	# ③ 填充到座数带；conservative 取下限（掷点照常消费，保 rng 流序）。
	var rolled_count: int = rng.randi_range(count_min, count_max)
	var target_count: int = count_min if bool(skeleton.get("conservative", false)) else rolled_count
	var filler_slots: int = maxi(target_count - mesas.size(), 0)
	for _slot in range(filler_slots):
		var filler_size: int = _roll_size(rng, mesa_cfg, cells_max - _cells_total(mesas))
		if filler_size <= 0:
			break	# 预算尽，后续槽位同败
		live = _place_slot_with_fallback(ctx, mesas, ledger, live, KIND_FILLER, "", filler_size)
	# 量带兜底（B2-11）：尺寸降阶会压低总量（4×3=12 < cells_min），座数未达
	# 上限时补填至 cells_min（不掷 rng，决定性；单次新增 ≤6 → 总量恒 ≤ 19 < cells_max）。
	while mesas.size() < count_max and _cells_total(mesas) < cells_min:
		var top_size: int = mini(maxi(cells_min - _cells_total(mesas), MIN_SHAPE_SIZE), 6)
		var before_top: int = mesas.size()
		live = _place_slot_with_fallback(ctx, mesas, ledger, live, KIND_FILLER, "", top_size)
		if mesas.size() == before_top:
			break	# 全图无处可放，交验收降阶
	# 验收与降阶（B2-10 编排器对非末次 attempt 视 degraded 为失败重试）。
	var count: int = mesas.size()
	var total: int = _cells_total(mesas)
	var ok := true
	var degraded := false
	if count >= count_min and count <= count_max and total >= cells_min and total <= cells_max:
		degraded = false
	elif count >= count_floor and (count < count_min or total < cells_min):
		degraded = true
	else:
		ok = false
	return {"ok": ok, "degraded": degraded, "mesas": mesas, "corridors": live}


## 槽位无关上下文（窗/汇流点膨胀集只算一次；corridor 膨胀集随落座每槽重算）。
static func _build_ctx(cells: Dictionary, skeleton: Dictionary, protected: Dictionary) -> Dictionary:
	var window_near: Dictionary = {}
	for raw_key: Variant in _sorted_gate_keys(skeleton):
		var key := String(raw_key)
		var win: Array[Vector2i] = GenRepairMod._acceptance_window(skeleton, key)
		var win_set: Dictionary = {}
		for cell in win:
			win_set[cell] = true
		window_near[key] = _dilate(win_set, HUG_DIST)
	var conf_set: Dictionary = {}
	for raw_conf: Variant in (skeleton.get("confluences", []) as Array):
		conf_set[(raw_conf as Dictionary).get("cell", Vector2i.ZERO)] = true
	return {
		"cells": cells, "skeleton": skeleton, "protected": protected,
		"cfg": skeleton.get("cfg", {}),
		"width": int(skeleton.get("width", 30)), "height": int(skeleton.get("height", 30)),
		"core": skeleton.get("core", Vector2i.ZERO),
		"spawn_cells": _spawn_list(skeleton),
		"sector_of": skeleton.get("sector_of", {}),
		"window_near": window_near,
		"conf_near": _dilate(conf_set, HUG_DIST),
		"mg": _mg(),
	}


## 槽位放置 + 尺寸降阶兜底：rolled 尺寸候选枯竭/复检全败 → size−1 … 目录最小
## 形状逐级重试（窗区拥挤放不下大形状是配额座枯竭主因——B2-11 sweep 实证；
## 降阶序固定且不消费 rng，决定性不变）。
static func _place_slot_with_fallback(ctx: Dictionary, mesas: Array[Dictionary], ledger: Dictionary, corridors: Dictionary, kind: StringName, gate_key: String, size: int) -> Dictionary:
	var live: Dictionary = corridors
	var try_size: int = size
	while try_size >= MIN_SHAPE_SIZE:
		var before: int = mesas.size()
		live = _place_slot(ctx, mesas, ledger, live, kind, gate_key, try_size)
		if mesas.size() > before:
			break
		try_size -= 1
	return live


## 单槽位反漂移闭环：候选全序扫描（≤TRIALS_PER_SLOT 次试落）。每候选：批量
## _try_apply_obstacle_cells(TERRAIN_HIGHLAND)（0 应用 = 连通回滚 → 下一候选）
## → derive_all_corridors → 复检 → 败则整形还原 plain（ledger rolled_back）。
## 成功更新 corridors 并记 mesa；候选枯竭跳过槽位（座数验收兜底降阶/失败）。
static func _place_slot(ctx: Dictionary, mesas: Array[Dictionary], ledger: Dictionary, corridors: Dictionary, kind: StringName, gate_key: String, size: int) -> Dictionary:
	var cells: Dictionary = ctx["cells"]
	var skeleton: Dictionary = ctx["skeleton"]
	var cfg: Dictionary = ctx["cfg"]
	var slack: int = int(cfg.get("corridor_slack", 3))
	var mg: GDScript = ctx["mg"]
	var candidates: Array = _enumerate_candidates(ctx, corridors, kind, gate_key, size)
	var trials: int = mini(TRIALS_PER_SLOT, candidates.size())
	for t in range(trials):
		var shape_cells: Array[Vector2i] = (candidates[t] as Array)[4]
		var applied: int = mg._try_apply_obstacle_cells(cells, shape_cells, CellData.TERRAIN_HIGHLAND, ctx["width"], ctx["height"], ctx["spawn_cells"], ctx["core"], cfg)
		if applied <= 0:
			continue	# 断连，_try_apply 内部已整批还原
		var next: Dictionary = GenRepairMod.derive_all_corridors(cells, skeleton, slack)
		var pending: Dictionary = {"cells": shape_cells, "kind": kind, "gate_key": gate_key}
		if _recheck_ok(ctx, mesas, pending, next):
			mesas.append(pending)
			FleshGen.ledger_note(ledger, "mesa", shape_cells.size(), shape_cells.size(), 0)
			return next
		for cell in shape_cells:
			var data: CellData = cells.get(cell) as CellData
			if data != null and data.terrain == CellData.TERRAIN_HIGHLAND:
				data.set_base_terrain(CellData.TERRAIN_PLAIN)
		FleshGen.ledger_note(ledger, "mesa", shape_cells.size(), 0, shape_cells.size())
	return corridors


## 反漂移复检：全口连通 + 绕路 cap（复用 corridors_next 的 shortest）、本座与
## 既有各座对新 corridor 的覆盖率 ≥ min_covered_ratio、starter 距 corridor 仍
## ≤ starter.max_corridor_dist（覆盖率口径的兜底重申，半径可独立配置）。
static func _recheck_ok(ctx: Dictionary, mesas: Array[Dictionary], pending: Dictionary, corridors_next: Dictionary) -> bool:
	var skeleton: Dictionary = ctx["skeleton"]
	var cfg: Dictionary = ctx["cfg"]
	var core: Vector2i = ctx["core"]
	var cap: float = float(cfg.get("detour_cap", 1.6))
	var gate_map: Dictionary = skeleton.get("gate_cells", {})
	for raw_key: Variant in _sorted_gate_keys(skeleton):
		var entry: Dictionary = corridors_next.get(String(raw_key), {})
		var shortest: int = int(entry.get("shortest", -1))
		if shortest < 0:
			return false
		var gate: Vector2i = gate_map[raw_key]
		var manhattan: int = maxi(absi(gate.x - core.x) + absi(gate.y - core.y), 1)
		if float(shortest) / float(manhattan) > cap:
			return false
	var mesa_cfg: Dictionary = (cfg.get("mesa", {}) as Dictionary)
	var starter_cfg: Dictionary = (mesa_cfg.get("starter", {}) as Dictionary)
	var ratio: float = float(mesa_cfg.get("min_covered_ratio", 0.6))
	var corridor_dist: int = int(mesa_cfg.get("max_corridor_dist", 2))
	var starter_dist: int = int(starter_cfg.get("max_corridor_dist", 2))
	var union: Dictionary = _corridor_union(corridors_next)
	var near: Dictionary = _dilate(union, corridor_dist)
	var starter_near: Dictionary = near if starter_dist == corridor_dist else _dilate(union, starter_dist)
	var all_mesas: Array[Dictionary] = mesas.duplicate()
	all_mesas.append(pending)
	for mesa in all_mesas:
		var mesa_cells: Array[Vector2i] = mesa["cells"]
		if float(_count_in(mesa_cells, near)) < ratio * float(mesa_cells.size()) - 0.0001:
			return false
		if StringName(mesa["kind"]) == KIND_STARTER and not _any_in(mesa_cells, starter_near):
			return false
	return true


## 槽位候选枚举：合法性（全格图内 plain 可走、非 protected 任意类别、无资源/口/核
## ——经 map_generator._is_obstacle_candidate 预过滤，保证 _try_apply 全收）+
## 槽位约束（starter 环带 / quota 限本扇区且任一格贴验收窗）→ 评分（§2.4 原文：
## 3×corridor cheb≤2 格数 + 6×贴本扇区验收窗 + 3×贴汇流点）→ 全序排序。
## 条目 [score, origin.y, origin.x, ordinal, shape_cells]。
static func _enumerate_candidates(ctx: Dictionary, corridors: Dictionary, kind: StringName, gate_key: String, size: int) -> Array:
	var mesa_cfg: Dictionary = (ctx["cfg"] as Dictionary).get("mesa", {})
	var starter_cfg: Dictionary = (mesa_cfg as Dictionary).get("starter", {})
	var near: Dictionary = _dilate(_corridor_union(corridors), int(mesa_cfg.get("max_corridor_dist", 2)))
	var window_near: Dictionary = ctx["window_near"]
	var conf_near: Dictionary = ctx["conf_near"]
	var sector_of: Dictionary = ctx["sector_of"]
	var core: Vector2i = ctx["core"]
	var width: int = ctx["width"]
	var height: int = ctx["height"]
	var ring_min: int = int(starter_cfg.get("ring_min", 4))
	var ring_max: int = int(starter_cfg.get("ring_max", 5))
	var shapes: Array = SHAPES.get(size, [])
	var result: Array = []
	for ordinal in range(shapes.size()):
		var offsets: Array = shapes[ordinal]
		for y in range(height):
			for x in range(width):
				var origin := Vector2i(x, y)
				var shape_cells: Array[Vector2i] = []
				var legal := true
				for raw_off: Variant in offsets:
					var cell: Vector2i = origin + (raw_off as Vector2i)
					if not _cell_placeable(ctx, cell):
						legal = false
						break
					if kind == KIND_STARTER:
						var ring: int = maxi(absi(cell.x - core.x), absi(cell.y - core.y))
						if ring < ring_min or ring > ring_max:
							legal = false
							break
					elif kind == KIND_QUOTA and String(sector_of.get(cell, "")) != gate_key:
						legal = false
						break
					shape_cells.append(cell)
				if not legal:
					continue
				var window_key: String = gate_key if kind == KIND_QUOTA else String(sector_of.get(shape_cells[0], ""))
				var slot_window: Dictionary = window_near.get(window_key, {})
				if kind == KIND_QUOTA and not _any_in(shape_cells, slot_window):
					continue	# 战位锚定硬约束：任一格距本扇区验收窗 cheb≤HUG_DIST
				var score: int = 3 * _count_in(shape_cells, near)
				if _any_in(shape_cells, slot_window):
					score += 6
				if _any_in(shape_cells, conf_near):
					score += 3
				result.append([score, y, x, ordinal, shape_cells])
	result.sort_custom(_candidate_less)
	return result


## (score 降, origin.y, origin.x, 形状序数) 严格全序——(y,x,ordinal) 唯一，排序稳定性无关。
static func _candidate_less(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return int(a[0]) > int(b[0])
	if a[1] != b[1]:
		return int(a[1]) < int(b[1])
	if a[2] != b[2]:
		return int(a[2]) < int(b[2])
	return int(a[3]) < int(b[3])


## 候选格合法：非 protected（任意类别，含 ford/aperture/pocket/lane）、当前
## plain 可走、4 邻无既有 highland（两座相邻即 4 连通合并，座数对外读数塌缩
## ——B2-11 sweep 实证 count 带失败主因）、且过 map_generator 候选过滤
## （图内/安全半径/无资源口核）。
static func _cell_placeable(ctx: Dictionary, cell: Vector2i) -> bool:
	if (ctx["protected"] as Dictionary).has(cell):
		return false
	var cells: Dictionary = ctx["cells"]
	var data: CellData = cells.get(cell) as CellData
	if data == null or data.terrain != CellData.TERRAIN_PLAIN or not data.walkable:
		return false
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var nb: CellData = cells.get(cell + direction) as CellData
		if nb != null and nb.terrain == CellData.TERRAIN_HIGHLAND:
			return false
	var mg: GDScript = ctx["mg"]
	return bool(mg._is_obstacle_candidate(cells, ctx["width"], ctx["height"], ctx["spawn_cells"], ctx["core"], ctx["cfg"], cell))


## 加权尺寸掷：恒消费 1 次 randf（rng 流序固定），可行集 = 目录尺寸 ∩ 权重>0 ∩
## size ≤ budget（权重在可行集内重归一）；可行集空返回 0（槽位让过）。
static func _roll_size(rng: RandomNumberGenerator, mesa_cfg: Dictionary, budget: int) -> int:
	var roll: float = rng.randf()
	var weights: Dictionary = mesa_cfg.get("size_weights", {})
	var sizes: Array[int] = []
	var total: float = 0.0
	for raw_size: Variant in SHAPES.keys():
		var size: int = int(raw_size)
		var weight: float = float(weights.get(str(size), 0.0))
		if size <= budget and weight > 0.0:
			sizes.append(size)
			total += weight
	if sizes.is_empty() or total <= 0.0:
		return 0
	sizes.sort()
	var cursor: float = 0.0
	for size in sizes:
		cursor += float(weights.get(str(size), 0.0))
		if roll * total < cursor:
			return size
	return sizes[sizes.size() - 1]


static func _corridor_union(corridors: Dictionary) -> Dictionary:
	var union: Dictionary = {}
	var keys: Array = corridors.keys()
	keys.sort()
	for raw_key: Variant in keys:
		for raw_cell: Variant in ((corridors[raw_key] as Dictionary).get("cells", {}) as Dictionary).keys():
			union[raw_cell] = true
	return union


## 集合切比雪夫膨胀：距集合任一格 cheb ≤ radius 的格集（含原集；不裁图界，
## 仅作 has 查询无害）。
static func _dilate(cell_set: Dictionary, radius: int) -> Dictionary:
	var out: Dictionary = {}
	for raw_cell: Variant in cell_set.keys():
		var cell: Vector2i = raw_cell
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				out[cell + Vector2i(dx, dy)] = true
	return out


static func _count_in(cells_list: Array[Vector2i], cell_set: Dictionary) -> int:
	var count: int = 0
	for cell in cells_list:
		if cell_set.has(cell):
			count += 1
	return count


static func _any_in(cells_list: Array[Vector2i], cell_set: Dictionary) -> bool:
	for cell in cells_list:
		if cell_set.has(cell):
			return true
	return false


static func _cells_total(mesas: Array[Dictionary]) -> int:
	var total: int = 0
	for mesa in mesas:
		total += (mesa["cells"] as Array).size()
	return total


static func _sorted_gate_keys(skeleton: Dictionary) -> Array:
	var keys: Array = (skeleton.get("gate_keys", []) as Array).duplicate()
	keys.sort()
	return keys


static func _spawn_list(skeleton: Dictionary) -> Array[Vector2i]:
	var spawn_cells: Array[Vector2i] = []
	for raw_cell: Variant in (skeleton.get("spawn_cells", []) as Array):
		spawn_cells.append(raw_cell)
	return spawn_cells
