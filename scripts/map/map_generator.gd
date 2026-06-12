class_name MapGenerator
extends RefCounted

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")
const SkeletonGen = preload("res://scripts/map/generation/skeleton.gd")
const LaneGen = preload("res://scripts/map/generation/lanes.gd")
const FleshGen = preload("res://scripts/map/generation/flesh.gd")
const NaturalGen = preload("res://scripts/map/generation/natural.gd")
const GenRepair = preload("res://scripts/map/generation/gen_repair.gd")
const MesaGen = preload("res://scripts/map/generation/mesa.gd")
const NightTemplateResolver = preload("res://scripts/enemy/night_template_resolver.gd")

const STAGE_SPAWNS := 1
const STAGE_OBSTACLES := 2
const STAGE_RESOURCES := 3
const STAGE_EVENTS := 4
const STAGE_REPAIR := 5  # 修复 pass 当前纯确定性无 RNG；保留给 B2 随机化修复
const STAGE_CARDS := 11
const STAGE_GEOMETRY := 12
const STAGE_LANES := 13
const STAGE_RIDGES := 14
const STAGE_WATER := 15
const STAGE_EROSION := 16
const STAGE_REPAIR_V2 := 17  # full_repair 纯确定性无 RNG；按契约表保留流位
const STAGE_MESA := 18

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP
]
const ALL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1)
]
const OBSTACLE_RATIO := 0.13
const MIN_OBSTACLE_COUNT := 65
const MAX_OBSTACLE_COUNT := 115
const TERRAIN_CLUSTER_COUNT := 5
const TERRAIN_CLUSTER_MIN_SIZE := 12
const TERRAIN_CLUSTER_MAX_SIZE := 28
const TERRAIN_CLUSTER_ATTEMPTS := 24
const SCATTERED_OBSTACLE_RATIO := 0.22
const CORE_SAFE_RADIUS := 3
const SPAWN_SAFE_RADIUS := 1
const SPAWN_COUNT := 5
const RESOURCES_PER_TYPE := 12
const NEAR_RESOURCES_PER_TYPE := 2
const EVENT_POINT_COUNT := 8
const SPAWN_CORNER_MARGIN := 3
const SPAWN_ARC_CENTER_RATIO := 0.6
const WATER_OBSTACLE_CHANCE := 0.35


static func _stage_rng(run_seed: int, stage_id: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = IntNoise.derive_seed(run_seed, 0, stage_id)
	return rng


## v2 重试期 stage 流：启用 attempt 位（B1 _stage_rng 恒 attempt=0，旧路径不动）。
static func _stage_rng_v2(run_seed: int, attempt: int, stage_id: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = IntNoise.derive_seed(run_seed, attempt, stage_id)
	return rng


static func generate(width: int, height: int, seed: int = -1, cfg: Dictionary = {}, event_ids: Array[StringName] = []) -> Dictionary:
	if String(cfg.get("generator", "legacy")) == "skeleton_v2":
		return generate_v2(width, height, seed, cfg, event_ids)
	return _generate_legacy(width, height, seed, cfg, event_ids)


## 旧管线整体提取（B2-10）：行为与提取前 generate() 逐位等价，仅返回 dict 增补
## 空 sectors/gen_report 两键（map_manager 只读四键，透传无感）。
static func _generate_legacy(width: int, height: int, seed: int, cfg: Dictionary, event_ids: Array[StringName]) -> Dictionary:
	var cells := _create_plain_cells(width, height)
	var actual_seed: int = seed
	if actual_seed < 0:
		var boot_rng := RandomNumberGenerator.new()
		boot_rng.randomize()
		actual_seed = int(boot_rng.randi())

	var core_cell: Vector2i = Vector2i(width / 2, height / 2)
	_setup_core_and_initial_fog(cells, core_cell)
	var spawn_cells := _place_spawns(cells, width, height, core_cell, _stage_rng(actual_seed, STAGE_SPAWNS), cfg)
	_place_random_obstacles(cells, width, height, spawn_cells, core_cell, _stage_rng(actual_seed, STAGE_OBSTACLES), cfg)
	_repair_gate_detours(cells, width, height, spawn_cells, core_cell, cfg)
	_place_resources(cells, width, height, spawn_cells, core_cell, _stage_rng(actual_seed, STAGE_RESOURCES), cfg)
	var event_points := _place_event_points(cells, width, height, spawn_cells, core_cell, _stage_rng(actual_seed, STAGE_EVENTS), cfg, event_ids)

	return {
		"cells": cells,
		"core_cell": core_cell,
		"spawn_cells": spawn_cells,
		"event_points": event_points,
		"sectors": {},
		"gen_report": {}
	}


## skeleton_v2 编排器（设计稿 §1.0/1.1/S9/§5）：≤max_retries 次独立尝试（每次
## 全阶段 RNG 经 IntNoise.derive_seed(seed, attempt, STAGE_*) 派生，末两轮保守
## 剖面），全败落 legacy 兜底（计划自审记录的偏差：规格 §5 曼哈顿走廊清障弃用，
## legacy 全管线久经考验且更简单）。elapsed_ms 仅观测指标，不参与生成决策。
static func generate_v2(width: int, height: int, seed: int, cfg: Dictionary, event_ids: Array[StringName]) -> Dictionary:
	var actual_seed: int = seed
	if actual_seed < 0:
		var boot_rng := RandomNumberGenerator.new()
		boot_rng.randomize()
		actual_seed = int(boot_rng.randi())
	var max_retries: int = maxi(int(cfg.get("max_retries", 5)), 1)
	var fail_log: Array = []
	var started_ms: int = Time.get_ticks_msec()   # 仅观测指标，不参与生成决策
	for attempt in range(max_retries):
		var conservative: bool = attempt >= max_retries - 2   # 末两轮保守剖面（设计稿 §5 attempt 4）
		var outcome: Dictionary = _generate_v2_attempt(width, height, actual_seed, attempt, cfg, event_ids, conservative)
		if bool(outcome.get("ok", false)):
			var result: Dictionary = outcome["result"]
			var report: Dictionary = result["gen_report"]
			report["attempts"] = attempt + 1
			report["fail_log"] = fail_log
			report["fallback"] = false
			report["elapsed_ms"] = Time.get_ticks_msec() - started_ms
			return result
		fail_log.append({"attempt": attempt, "reason": String(outcome.get("reason", "unknown"))})
	push_warning("skeleton_v2: %d attempts exhausted, falling back to legacy (%s)" % [max_retries, str(fail_log)])
	var legacy := _generate_legacy(width, height, actual_seed, cfg, event_ids)
	legacy["gen_report"] = {
		"attempts": max_retries, "fallback": true, "fail_log": fail_log,
		"archetype": "", "cards": {}, "wind": Vector2i.ZERO, "ledger": {},
		"intrusion": 0, "blocked_ratio": 0.0,
		"elapsed_ms": Time.get_ticks_msec() - started_ms,
	}
	return legacy


## skeleton_v2 单次尝试（S1-S9 对位接线）：失败 → {"ok": false, "reason": String}
## 交重试壳记 fail_log；成功 → {"ok": true, "result": Dictionary}（六键结果；
## attempts/fail_log/fallback/elapsed_ms 由重试壳补写）。
static func _generate_v2_attempt(width: int, height: int, actual_seed: int, attempt: int, cfg: Dictionary, event_ids: Array[StringName], conservative: bool) -> Dictionary:
	var cells := _create_plain_cells(width, height)
	var core_cell := Vector2i(width / 2, height / 2)
	_setup_core_and_initial_fog(cells, core_cell)
	# S2a 等弧门（复用 B1 placement，attempt 进流）。
	var spawn_cells := _place_spawns(cells, width, height, core_cell, _stage_rng_v2(actual_seed, attempt, STAGE_SPAWNS), cfg)
	if spawn_cells.size() < maxi(int(cfg.get("spawn_count", SPAWN_COUNT)), 1):
		return {"ok": false, "reason": "gate_placement"}
	var gate_keys: Array = []
	var gate_map: Dictionary = {}
	for i in range(spawn_cells.size()):
		var key := "S%d" % (i + 1)
		gate_keys.append(key)
		gate_map[key] = spawn_cells[i]
	# S1 archetype + day1 发牌约束 + 风向（保守剖面换 open_run 并收窄占比带）。
	var cards_rng := _stage_rng_v2(actual_seed, attempt, STAGE_CARDS)
	var archetype: Dictionary = SkeletonGen.draw_archetype(cfg, cards_rng)
	if conservative:
		archetype = _archetype_by_id(cfg, "open_run", archetype)
		archetype = archetype.duplicate(true)
		var band: Array = archetype.get("ratio_band", [0.20, 0.22])
		archetype["ratio_band"] = [float(band[0]), float(band[0]) + 0.01]
	var day1_active: Array = NightTemplateResolver.resolve_active_gates(gate_keys, actual_seed, 1)
	var cards: Dictionary = SkeletonGen.deal_cards(archetype, gate_keys, day1_active, cards_rng, cfg)
	var wind: Vector2i = SkeletonGen.roll_wind(cards_rng)
	# S2b 扇区楔形 / 隘口锚 / 汇流点。
	var geom_rng := _stage_rng_v2(actual_seed, attempt, STAGE_GEOMETRY)
	var sector_of: Dictionary = SkeletonGen.assign_sectors(width, height, spawn_cells)
	var confluences: Array[Dictionary] = SkeletonGen.place_confluences(archetype, spawn_cells, core_cell, geom_rng)
	var sector_cards: Dictionary = cfg.get("sector_cards", {})
	var pass_cfg: Dictionary = cfg.get("pass", {})
	var anchors: Dictionary = {}
	for i in range(spawn_cells.size()):
		var key := String(gate_keys[i])
		var card_cfg: Dictionary = sector_cards.get(String(cards.get(key, "bastion")), {})
		var anchor: Vector2i = SkeletonGen.place_pass_anchor(spawn_cells[i], core_cell, card_cfg, geom_rng)
		var aperture: Array[Vector2i] = LaneGen.aperture_window(anchor, spawn_cells[i], core_cell, int(card_cfg.get("pass_width", 2)), int(pass_cfg.get("aperture_depth", 2)))
		anchors[key] = {"cell": anchor, "pass_width": int(card_cfg.get("pass_width", 2)), "aperture": aperture}
	var skeleton := {
		"width": width, "height": height, "core": core_cell,
		"gate_keys": gate_keys, "gate_cells": gate_map, "spawn_cells": spawn_cells,
		"cards": cards, "card_cfgs": sector_cards,
		"archetype": archetype, "wind": wind, "sector_of": sector_of,
		"anchors": anchors, "confluences": confluences, "lanes": {}, "fords": {},
		"conservative": conservative, "cfg": cfg,
	}
	# S3 车道 + protected（途径点外→内 = anchor → 本门汇流点）。
	var lane_seed: int = IntNoise.derive_seed(actual_seed, attempt, STAGE_LANES)
	var lanes: Dictionary = skeleton["lanes"]
	for i in range(spawn_cells.size()):
		var key := String(gate_keys[i])
		var card_cfg: Dictionary = sector_cards.get(String(cards.get(key, "bastion")), {})
		var anchor_cell: Vector2i = (anchors[key] as Dictionary)["cell"]
		var waypoints: Array[Vector2i] = [anchor_cell]
		for raw_conf: Variant in confluences:
			if ((raw_conf as Dictionary).get("gate_cells", []) as Array).has(spawn_cells[i]):
				waypoints.append((raw_conf as Dictionary).get("cell", core_cell) as Vector2i)
		var jitter: float = 0.0 if conservative else float(card_cfg.get("jitter_amp", float(cfg.get("lane_jitter_base", 0.35))))
		var lane: Array[Vector2i] = LaneGen.trace_lane_checked(cells, spawn_cells[i], waypoints, core_cell, jitter, IntNoise.squirrel3(i, lane_seed))
		if lane.is_empty():
			return {"ok": false, "reason": "lane_trace"}
		lanes[key] = lane
	var protected: Dictionary = LaneGen.build_protected(lanes, core_cell, spawn_cells, anchors, cfg)
	# S4 山脊 + 预算台账。
	var ledger: Dictionary = FleshGen.make_ledger(cfg, archetype, cards, width, height)
	FleshGen.grow_ridges(cells, skeleton, protected, _stage_rng_v2(actual_seed, attempt, STAGE_RIDGES), ledger)
	# S4.5 河湖（伪高程 → 湿度计划 → 河/湖；trace_river 成功且渡口非空才写回
	# skeleton.fords，整批回滚的河留缺键——分级回退锚窗容忍，B2-5/7 评审结论）。
	var water_seed: int = IntNoise.derive_seed(actual_seed, attempt, STAGE_WATER)
	var elevation: Dictionary = FleshGen.build_elevation(cells, width, height, water_seed)
	var water_rng := _stage_rng_v2(actual_seed, attempt, STAGE_WATER)
	var plans: Dictionary = FleshGen.roll_water_plans(skeleton, wind, water_rng, cfg)
	for raw_key: Variant in gate_keys:
		var key := String(raw_key)
		var plan: Dictionary = plans.get(key, {})
		if bool(plan.get("river", false)):
			var river: Dictionary = FleshGen.trace_river(cells, skeleton, key, elevation, protected, water_rng, ledger)
			if not (river.get("ford_cells", []) as Array).is_empty():
				(skeleton["fords"] as Dictionary)[key] = river["ford_cells"]
		if int(plan.get("lakes", 0)) > 0:
			FleshGen.place_lakes(cells, skeleton, key, int(plan.get("lakes", 0)), protected, water_rng, ledger)
	# S5 侵蚀 + CA 清渣。
	NaturalGen.erode_edges(cells, skeleton, protected, IntNoise.derive_seed(actual_seed, attempt, STAGE_EROSION), ledger)
	NaturalGen.cellular_cleanup(cells, skeleton, protected, ledger)
	# S6 全量修复（伪高程按清渣后地形重建，种子复用 STAGE_WATER 流）。
	elevation = FleshGen.build_elevation(cells, width, height, water_seed)
	var repair: Dictionary = GenRepair.full_repair(cells, skeleton, protected, elevation, ledger)
	if not bool(repair.get("ok", false)):
		return {"ok": false, "reason": "repair_%s" % String(repair.get("fail_reason", ""))}
	# S7 mesa（degraded 仅末次 attempt 放行）。
	var mesa: Dictionary = MesaGen.place_mesas(cells, skeleton, protected, repair["corridors"], _stage_rng_v2(actual_seed, attempt, STAGE_MESA), ledger)
	if not bool(mesa.get("ok", false)):
		return {"ok": false, "reason": "mesa_supply"}
	var max_retries: int = maxi(int(cfg.get("max_retries", 5)), 1)
	if bool(mesa.get("degraded", false)) and attempt < max_retries - 1:
		return {"ok": false, "reason": "mesa_degraded"}
	# S8 资源风味 + 事件（复用既有流 id，attempt 进流）。
	_place_resources_v2(cells, width, height, spawn_cells, core_cell, _stage_rng_v2(actual_seed, attempt, STAGE_RESOURCES), cfg, skeleton, mesa["corridors"])
	var event_points := _place_event_points(cells, width, height, spawn_cells, core_cell, _stage_rng_v2(actual_seed, attempt, STAGE_EVENTS), cfg, event_ids)
	# S9 终验。
	var verdict: Dictionary = _validate_v2(cells, skeleton, repair, mesa, cfg)
	if not bool(verdict.get("ok", false)):
		return {"ok": false, "reason": "validate_%s" % String(verdict.get("reason", ""))}
	return {"ok": true, "result": {
		"cells": cells, "core_cell": core_cell, "spawn_cells": spawn_cells, "event_points": event_points,
		"sectors": _build_sectors_meta(skeleton, repair, mesa),
		"gen_report": {
			"archetype": String(archetype.get("id", "")), "cards": cards, "wind": wind,
			"ledger": ledger, "intrusion": int(repair.get("intrusion", 0)),
			"blocked_ratio": _blocked_ratio(cells, width, height),
			"pass_grades": repair.get("pass_grades", {}), "mesa_degraded": bool(mesa.get("degraded", false)),
		},
	}}


## 线性找 archetype id；缺 → fallback（保守剖面换 open_run 用）。
static func _archetype_by_id(cfg: Dictionary, id: String, fallback: Dictionary) -> Dictionary:
	for raw: Variant in (cfg.get("archetypes", []) as Array):
		if String((raw as Dictionary).get("id", "")) == id:
			return raw
	return fallback


static func _blocked_ratio(cells: Dictionary, width: int, height: int) -> float:
	var blocked: int = 0
	for raw_cell: Variant in cells.keys():
		if not (cells[raw_cell] as CellData).walkable:
			blocked += 1
	return float(blocked) / float(maxi(width * height, 1))


## 扇区元数据（generate_v2 返回 "sectors" 键）：gate_key → {card, pass_grade,
## anchor, aperture（渡口非空用渡口窗否则锚窗）, ford（无渡口 = 空数组）}。
static func _build_sectors_meta(skeleton: Dictionary, repair: Dictionary, _mesa: Dictionary) -> Dictionary:
	var sectors: Dictionary = {}
	var grades: Dictionary = repair.get("pass_grades", {})
	var fords: Dictionary = skeleton.get("fords", {})
	var anchors: Dictionary = skeleton.get("anchors", {})
	var cards: Dictionary = skeleton.get("cards", {})
	var keys: Array = (skeleton.get("gate_keys", []) as Array).duplicate()
	keys.sort()
	for raw_key: Variant in keys:
		var key := String(raw_key)
		var anchor_entry: Dictionary = anchors.get(key, {})
		var ford: Array = fords.get(key, [])
		var aperture: Array = ford if not ford.is_empty() else (anchor_entry.get("aperture", []) as Array)
		sectors[key] = {
			"card": String(cards.get(key, "")),
			"pass_grade": StringName(grades.get(key, &"")),
			"anchor": anchor_entry.get("cell", Vector2i.ZERO),
			"aperture": aperture,
			"ford": ford,
		}
	return sectors


## S9 终验（全部硬断言，任一失败 → 本 attempt 作废重试）：口数齐、全口连通、
## 每口 detour ∈ [floor−ε, cap+ε]、阻挡占比带、分级一致性、mesa 供给。
## 占比带按 mesa 精确格数扣除后复核（B2-8 评审结论：原带由 full_repair ⑥ 在
## mesa 前保障，mesa 最多 +cells_max/面积 ≈ +0.027，不得对 mesa 后地图重申原带）。
## 分级一致性同 gen_repair 规约：single → 当前最短路 ∩ 验收窗 ≠ ∅；
## dual → 旁路窗 ≥ 1；open（steppe）免检。
static func _validate_v2(cells: Dictionary, skeleton: Dictionary, repair: Dictionary, mesa: Dictionary, cfg: Dictionary) -> Dictionary:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var gate_map: Dictionary = skeleton.get("gate_cells", {})
	var gate_keys: Array = (skeleton.get("gate_keys", []) as Array).duplicate()
	gate_keys.sort()
	if gate_keys.size() < maxi(int(cfg.get("spawn_count", SPAWN_COUNT)), 1):
		return {"ok": false, "reason": "gate_count"}
	if not bool(mesa.get("ok", false)):
		return {"ok": false, "reason": "mesa"}
	var detour_cap: float = float(cfg.get("detour_cap", 1.6))
	var detour_floor: float = float(cfg.get("detour_floor", 1.15))
	var grades: Dictionary = repair.get("pass_grades", {})
	for raw_key: Variant in gate_keys:
		var key := String(raw_key)
		var gate: Vector2i = gate_map[key]
		var path_len: int = int(_bfs_distances(cells, width, height, gate).get(core, -1))
		if path_len <= 0:
			return {"ok": false, "reason": "connectivity"}
		var manhattan: int = maxi(absi(gate.x - core.x) + absi(gate.y - core.y), 1)
		var ratio: float = float(path_len) / float(manhattan)
		if ratio > detour_cap + 0.0001 or ratio < detour_floor - 0.0001:
			return {"ok": false, "reason": "detour"}
		var grade: StringName = StringName(grades.get(key, &""))
		if grade == &"single":
			var win: Array[Vector2i] = GenRepair._acceptance_window(skeleton, key)
			var path: Array[Vector2i] = GenRepair._shortest_path(cells, gate, core)
			var crosses := false
			for cell in win:
				if path.has(cell):
					crosses = true
					break
			if not crosses:
				return {"ok": false, "reason": "grade_single"}
		elif grade == &"dual":
			if _bypass_window_count(cells, skeleton, key, cfg) < 1:
				return {"ok": false, "reason": "grade_dual"}
		elif grade != &"open":
			return {"ok": false, "reason": "grade_missing"}
		if grade != &"open":
			# 口袋终验（B2-11）：⑤/⑤b 之后 mesa 仍可能圈死窄袋口（渡口窗为甚），
			# 资源点也会蚕食 plain 计数——非 steppe 口在终图上重申 ≥ pocket_min_plain。
			var pass_cfg: Dictionary = cfg.get("pass", {})
			var flood: Dictionary = GenRepair._pocket_flood(cells, GenRepair._acceptance_window(skeleton, key), core, int(pass_cfg.get("pocket_flood_limit", 12)))
			if int(flood.get("plain", 0)) < int(pass_cfg.get("pocket_min_plain", 6)):
				return {"ok": false, "reason": "pocket_final"}
	var mesa_cells_total: int = 0
	for raw_mesa: Variant in (mesa.get("mesas", []) as Array):
		mesa_cells_total += ((raw_mesa as Dictionary).get("cells", []) as Array).size()
	var blocked: int = 0
	for raw_cell: Variant in cells.keys():
		if not (cells[raw_cell] as CellData).walkable:
			blocked += 1
	var band: Array = (skeleton.get("archetype", {}) as Dictionary).get("ratio_band", [0.20, 0.26])
	var pre_mesa_ratio: float = float(blocked - mesa_cells_total) / float(maxi(width * height, 1))
	if pre_mesa_ratio < float(band[0]) - 0.02 or pre_mesa_ratio > float(band[1]) + 0.02:
		return {"ok": false, "reason": "ratio"}
	return {"ok": true, "reason": ""}


## dual 复核助手（与 gen_repair._grade_passes 同规约）：corridor 环带
## [ring_A−1, ring_A+1] 去验收窗膨胀（cheb≤1）后 8 连通聚类计数。
static func _bypass_window_count(cells: Dictionary, skeleton: Dictionary, key: String, cfg: Dictionary) -> int:
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var gate: Vector2i = (skeleton.get("gate_cells", {}) as Dictionary).get(key, core)
	var win: Array[Vector2i] = GenRepair._acceptance_window(skeleton, key)
	if win.is_empty():
		return 0
	var ring_a: int = maxi(absi(win[0].x - core.x), absi(win[0].y - core.y))
	var dilation: Dictionary = {}
	for cell in win:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				dilation[cell + Vector2i(dx, dy)] = true
	var corridor: Dictionary = GenRepair.derive_corridor(cells, gate, core, int(cfg.get("corridor_slack", 3)))
	var bypass: Array[Vector2i] = []
	for raw_cell: Variant in (corridor.get("cells", {}) as Dictionary).keys():
		var cell: Vector2i = raw_cell
		var ring: int = maxi(absi(cell.x - core.x), absi(cell.y - core.y))
		if absi(ring - ring_a) > 1 or dilation.has(cell):
			continue
		bypass.append(cell)
	return GenRepair._cluster8(bypass).size()


static func _create_plain_cells(width: int, height: int) -> Dictionary:
	var cells: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var data: CellData = CellData.new()
			data.cell = Vector2i(x, y)
			data.set_base_terrain(CellData.TERRAIN_PLAIN)
			data.discovered = false
			cells[data.cell] = data
	return cells


static func _setup_core_and_initial_fog(cells: Dictionary, core_cell: Vector2i) -> void:
	var core_data: CellData = cells[core_cell]
	core_data.is_core = true
	core_data.set_base_terrain(CellData.TERRAIN_PLAIN)
	core_data.buildable = false

	for y in range(core_cell.y - 2, core_cell.y + 3):
		for x in range(core_cell.x - 2, core_cell.x + 3):
			var reveal_cell: Vector2i = Vector2i(x, y)
			if cells.has(reveal_cell):
				var reveal_data: CellData = cells[reveal_cell]
				reveal_data.discovered = true


static func _get_perimeter_cells(width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(0, width):
		cells.append(Vector2i(x, 0))
	for y in range(1, height):
		cells.append(Vector2i(width - 1, y))
	for x in range(width - 2, -1, -1):
		cells.append(Vector2i(x, height - 1))
	for y in range(height - 2, 0, -1):
		cells.append(Vector2i(0, y))
	return cells


static func _is_near_corner(cell: Vector2i, width: int, height: int, margin: int) -> bool:
	var near_x: bool = cell.x < margin or cell.x > width - 1 - margin
	var near_y: bool = cell.y < margin or cell.y > height - 1 - margin
	return near_x and near_y


## 等弧放置：周长均分为 spawn_count 段，每段只在中部 arc_center_ratio 内抽取，
## 方向分散由构造保证；相位随机让弧界不固定在 (0,0)。
static func _place_spawns(cells: Dictionary, width: int, height: int, _core_cell: Vector2i, rng: RandomNumberGenerator, cfg: Dictionary) -> Array[Vector2i]:
	var perimeter := _get_perimeter_cells(width, height)
	var spawn_count: int = maxi(int(cfg.get("spawn_count", SPAWN_COUNT)), 1)
	var corner_margin: int = maxi(int(cfg.get("spawn_corner_margin", SPAWN_CORNER_MARGIN)), 0)
	var center_ratio: float = clampf(float(cfg.get("spawn_arc_center_ratio", SPAWN_ARC_CENTER_RATIO)), 0.1, 1.0)
	var total: int = perimeter.size()
	var phase: int = rng.randi() % total
	var spawn_cells: Array[Vector2i] = []
	for arc_index in range(spawn_count):
		var arc_start: float = float(total) * float(arc_index) / float(spawn_count)
		var arc_len: float = float(total) / float(spawn_count)
		var margin: float = arc_len * (1.0 - center_ratio) * 0.5
		var options: Array[Vector2i] = []
		for index in range(int(ceil(arc_start + margin)), int(floor(arc_start + arc_len - margin)) + 1):
			var cell: Vector2i = perimeter[(index + phase) % total]
			if _is_near_corner(cell, width, height, corner_margin):
				continue
			options.append(cell)
		# 回退窗用半开区间扫整段弧（不含弧界），主窗用含端点的中部窗。
		if options.is_empty():
			for index in range(int(ceil(arc_start)), int(floor(arc_start + arc_len))):
				var fallback_cell: Vector2i = perimeter[(index + phase) % total]
				if not _is_near_corner(fallback_cell, width, height, corner_margin):
					options.append(fallback_cell)
		if options.is_empty():
			push_warning("spawn arc %d has no candidates; map yields fewer gates" % arc_index)
			continue
		var pick: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		var spawn_data: CellData = cells[pick]
		spawn_data.spawn_key = StringName("S%d" % (spawn_cells.size() + 1))
		spawn_data.set_base_terrain(CellData.TERRAIN_PLAIN)
		spawn_data.discovered = false
		spawn_data.buildable = false
		spawn_cells.append(pick)
	return spawn_cells


static func _place_resources(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator,
	cfg: Dictionary
) -> void:
	var near_candidates: Array[Vector2i] = []
	var far_candidates: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell: Vector2i = Vector2i(x, y)
			var near_ring := _is_near_exploration_ring(cell, core_cell)
			if _is_protected_cell(cell, core_cell, spawn_cells, cfg) and not near_ring:
				continue
			var data: CellData = cells[cell]
			if data == null or not data.walkable or data.resource_type != StringName() or data.spawn_key != StringName():
				continue
			if near_ring:
				near_candidates.append(cell)
			else:
				far_candidates.append(cell)
	_shuffle_cells(near_candidates, rng)
	_shuffle_cells(far_candidates, rng)

	var resource_types: Array[StringName] = [&"wood", &"stone", &"mana"]
	var placed_by_type: Dictionary = {}
	for resource_type in resource_types:
		placed_by_type[resource_type] = 0
	var target_per_type: int = int(cfg.get("resources_per_type", RESOURCES_PER_TYPE))
	var near_target_per_type: int = min(int(cfg.get("near_resources_per_type", NEAR_RESOURCES_PER_TYPE)), target_per_type)
	for resource_type in resource_types:
		_place_resource_type(cells, near_candidates, resource_type, near_target_per_type, placed_by_type)
	for resource_type in resource_types:
		_place_resource_type(cells, far_candidates, resource_type, target_per_type, placed_by_type)


static func _place_resource_type(
	cells: Dictionary,
	candidates: Array[Vector2i],
	resource_type: StringName,
	target_count: int,
	placed_by_type: Dictionary
) -> void:
	for cell in candidates.duplicate():
		if int(placed_by_type.get(resource_type, 0)) >= target_count:
			return
		var data: CellData = cells[cell]
		if data == null or data.resource_type != StringName() or not data.walkable:
			continue
		_set_resource_node(data, resource_type)
		placed_by_type[resource_type] = int(placed_by_type.get(resource_type, 0)) + 1
		candidates.erase(cell)


static func _set_resource_node(data: CellData, resource_type: StringName) -> void:
	data.set_base_terrain(CellData.TERRAIN_PLAIN)
	data.resource_type = resource_type


static func _is_near_exploration_ring(cell: Vector2i, core_cell: Vector2i) -> bool:
	var distance: int = max(absi(cell.x - core_cell.x), absi(cell.y - core_cell.y))
	return distance >= 3 and distance <= 5


static func _place_random_obstacles(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator,
	cfg: Dictionary
) -> void:
	var candidates: Array[Vector2i] = _get_obstacle_candidates(cells, width, height, spawn_cells, core_cell, cfg)
	var target_count: int = _get_obstacle_target_count(width, height, candidates.size(), cfg)
	if target_count <= 0:
		return
	var scattered_ratio: float = clampf(float(cfg.get("scattered_obstacle_ratio", SCATTERED_OBSTACLE_RATIO)), 0.0, 1.0)
	var scattered_target_count: int = int(round(float(target_count) * scattered_ratio))
	var cluster_target_count: int = _max_int(target_count - scattered_target_count, 0)
	var placed_count: int = _place_obstacle_clusters(cells, width, height, spawn_cells, core_cell, rng, cfg, cluster_target_count)
	if placed_count < target_count:
		_place_scattered_obstacles(cells, width, height, spawn_cells, core_cell, rng, cfg, target_count - placed_count)


static func _get_obstacle_target_count(width: int, height: int, candidate_count: int, cfg: Dictionary) -> int:
	var obstacle_ratio: float = float(cfg.get("obstacle_ratio", OBSTACLE_RATIO))
	var min_obstacle_count: int = int(cfg.get("min_obstacle_count", MIN_OBSTACLE_COUNT))
	var max_obstacle_count: int = int(cfg.get("max_obstacle_count", MAX_OBSTACLE_COUNT))
	var estimated_count: int = int(round(float(width * height) * obstacle_ratio))
	var target_count: int = _max_int(min_obstacle_count, estimated_count)
	return _min_int(_min_int(target_count, max_obstacle_count), candidate_count)


static func _place_obstacle_clusters(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator,
	cfg: Dictionary,
	target_count: int
) -> int:
	if target_count <= 0:
		return 0
	var cluster_count: int = _max_int(int(cfg.get("terrain_cluster_count", TERRAIN_CLUSTER_COUNT)), 0)
	if cluster_count <= 0:
		return 0
	var min_size: int = _max_int(int(cfg.get("terrain_cluster_min_size", TERRAIN_CLUSTER_MIN_SIZE)), 1)
	var max_size: int = _max_int(int(cfg.get("terrain_cluster_max_size", TERRAIN_CLUSTER_MAX_SIZE)), min_size)
	var attempts_per_cluster: int = _max_int(int(cfg.get("terrain_cluster_attempts", TERRAIN_CLUSTER_ATTEMPTS)), 1)
	var max_attempts: int = cluster_count * attempts_per_cluster
	var placed_count: int = 0
	var placed_clusters: int = 0
	var attempts: int = 0
	while placed_clusters < cluster_count and placed_count < target_count and attempts < max_attempts:
		attempts += 1
		var candidates: Array[Vector2i] = _get_obstacle_candidates(cells, width, height, spawn_cells, core_cell, cfg)
		if candidates.is_empty():
			break
		var center: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var desired_size: int = _min_int(rng.randi_range(min_size, max_size), target_count - placed_count)
		var terrain: StringName = _roll_obstacle_terrain(rng, cfg)
		var cluster_cells: Array[Vector2i] = _build_obstacle_cluster(cells, width, height, spawn_cells, core_cell, cfg, rng, center, desired_size, terrain)
		var minimum_viable_size: int = _max_int(3, int(ceil(float(min_size) * 0.5)))
		if cluster_cells.size() < minimum_viable_size:
			continue
		var applied_count: int = _try_apply_obstacle_cells(cells, cluster_cells, terrain, width, height, spawn_cells, core_cell, cfg)
		if applied_count <= 0:
			continue
		placed_count += applied_count
		placed_clusters += 1
	return placed_count


static func _place_scattered_obstacles(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator,
	cfg: Dictionary,
	target_count: int
) -> int:
	if target_count <= 0:
		return 0
	var candidates: Array[Vector2i] = _get_obstacle_candidates(cells, width, height, spawn_cells, core_cell, cfg)
	_shuffle_cells(candidates, rng)
	var placed_count: int = 0
	for cell in candidates:
		if placed_count >= target_count:
			break
		var terrain: StringName = _roll_obstacle_terrain(rng, cfg)
		var single_cell: Array[Vector2i] = []
		single_cell.append(cell)
		placed_count += _try_apply_obstacle_cells(cells, single_cell, terrain, width, height, spawn_cells, core_cell, cfg)
	return placed_count


static func _build_obstacle_cluster(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary,
	rng: RandomNumberGenerator,
	center: Vector2i,
	target_size: int,
	terrain: StringName
) -> Array[Vector2i]:
	if terrain == CellData.TERRAIN_WATER:
		return _build_lake_cluster(cells, width, height, spawn_cells, core_cell, cfg, rng, center, target_size)
	return _build_mountain_cluster(cells, width, height, spawn_cells, core_cell, cfg, rng, center, target_size)


static func _build_lake_cluster(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary,
	rng: RandomNumberGenerator,
	center: Vector2i,
	target_size: int
) -> Array[Vector2i]:
	var cluster: Array[Vector2i] = []
	var lookup: Dictionary = {}
	_try_add_cluster_cell(cells, width, height, spawn_cells, core_cell, cfg, center, cluster, lookup)
	var attempts: int = 0
	while cluster.size() < target_size and attempts < target_size * 16 and not cluster.is_empty():
		attempts += 1
		var base: Vector2i = cluster[rng.randi_range(0, cluster.size() - 1)]
		var direction: Vector2i = ALL_DIRECTIONS[rng.randi_range(0, ALL_DIRECTIONS.size() - 1)]
		_try_add_cluster_cell(cells, width, height, spawn_cells, core_cell, cfg, base + direction, cluster, lookup)
		if rng.randf() < 0.35:
			for neighbor_direction in CARDINAL_DIRECTIONS:
				if cluster.size() >= target_size:
					break
				if rng.randf() < 0.35:
					_try_add_cluster_cell(cells, width, height, spawn_cells, core_cell, cfg, base + neighbor_direction, cluster, lookup)
	return cluster


static func _build_mountain_cluster(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary,
	rng: RandomNumberGenerator,
	center: Vector2i,
	target_size: int
) -> Array[Vector2i]:
	var cluster: Array[Vector2i] = []
	var lookup: Dictionary = {}
	var current: Vector2i = center
	var direction: Vector2i = _random_cardinal_direction(rng)
	var attempts: int = 0
	while cluster.size() < target_size and attempts < target_size * 16:
		attempts += 1
		_try_add_cluster_cell(cells, width, height, spawn_cells, core_cell, cfg, current, cluster, lookup)
		for side_direction in _get_perpendicular_directions(direction):
			if cluster.size() >= target_size:
				break
			if rng.randf() < 0.45:
				_try_add_cluster_cell(cells, width, height, spawn_cells, core_cell, cfg, current + side_direction, cluster, lookup)
		if rng.randf() < 0.26:
			direction = _turn_cardinal_direction(direction, rng)
		var next_cell: Vector2i = current + direction
		if _is_obstacle_candidate(cells, width, height, spawn_cells, core_cell, cfg, next_cell):
			current = next_cell
		elif not cluster.is_empty():
			current = cluster[rng.randi_range(0, cluster.size() - 1)]
			direction = _random_cardinal_direction(rng)
		else:
			break
	return cluster


static func _try_add_cluster_cell(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary,
	cell: Vector2i,
	cluster: Array[Vector2i],
	lookup: Dictionary
) -> bool:
	if lookup.has(cell):
		return false
	if not _is_obstacle_candidate(cells, width, height, spawn_cells, core_cell, cfg, cell):
		return false
	lookup[cell] = true
	cluster.append(cell)
	return true


static func _try_apply_obstacle_cells(
	cells: Dictionary,
	obstacle_cells: Array[Vector2i],
	terrain: StringName,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary
) -> int:
	var applied_cells: Array[Vector2i] = []
	for cell in obstacle_cells:
		if not _is_obstacle_candidate(cells, width, height, spawn_cells, core_cell, cfg, cell):
			continue
		var data: CellData = cells.get(cell) as CellData
		if data == null:
			continue
		data.set_base_terrain(terrain)
		applied_cells.append(cell)
	if applied_cells.is_empty():
		return 0
	if _are_all_spawns_connected(cells, width, height, spawn_cells, core_cell):
		return applied_cells.size()
	for cell in applied_cells:
		var data: CellData = cells.get(cell) as CellData
		if data != null:
			data.set_base_terrain(CellData.TERRAIN_PLAIN)
	return 0


static func _get_obstacle_candidates(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var cell: Vector2i = Vector2i(x, y)
			if _is_obstacle_candidate(cells, width, height, spawn_cells, core_cell, cfg, cell):
				candidates.append(cell)
	return candidates


static func _is_obstacle_candidate(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	cfg: Dictionary,
	cell: Vector2i
) -> bool:
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return false
	if _is_protected_cell(cell, core_cell, spawn_cells, cfg):
		return false
	var data: CellData = cells.get(cell) as CellData
	if data == null or data.resource_type != StringName() or data.spawn_key != StringName() or data.is_core:
		return false
	return data.walkable


static func _roll_obstacle_terrain(rng: RandomNumberGenerator, cfg: Dictionary) -> StringName:
	return CellData.TERRAIN_WATER if rng.randf() < float(cfg.get("water_obstacle_chance", WATER_OBSTACLE_CHANCE)) else CellData.TERRAIN_MOUNTAIN


static func _are_all_spawns_connected(cells: Dictionary, width: int, height: int, spawn_cells: Array[Vector2i], core_cell: Vector2i) -> bool:
	for spawn_cell in spawn_cells:
		if not _has_ground_path(cells, width, height, spawn_cell, core_cell):
			return false
	return true


static func _random_cardinal_direction(rng: RandomNumberGenerator) -> Vector2i:
	return CARDINAL_DIRECTIONS[rng.randi_range(0, CARDINAL_DIRECTIONS.size() - 1)]


static func _min_int(a: int, b: int) -> int:
	return a if a <= b else b


static func _max_int(a: int, b: int) -> int:
	return a if a >= b else b


static func _get_perpendicular_directions(direction: Vector2i) -> Array[Vector2i]:
	if direction.x != 0:
		var vertical_directions: Array[Vector2i] = []
		vertical_directions.append(Vector2i.UP)
		vertical_directions.append(Vector2i.DOWN)
		return vertical_directions
	var horizontal_directions: Array[Vector2i] = []
	horizontal_directions.append(Vector2i.LEFT)
	horizontal_directions.append(Vector2i.RIGHT)
	return horizontal_directions


static func _turn_cardinal_direction(direction: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var side_directions: Array[Vector2i] = _get_perpendicular_directions(direction)
	if rng.randf() < 0.75:
		return side_directions[rng.randi_range(0, side_directions.size() - 1)]
	return Vector2i(-direction.x, -direction.y)


static func _place_event_points(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator,
	cfg: Dictionary,
	event_ids: Array[StringName]
) -> Array[Dictionary]:
	var event_points: Array[Dictionary] = []
	if event_ids.is_empty():
		return event_points
	var candidates: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell: Vector2i = Vector2i(x, y)
			if _is_protected_cell(cell, core_cell, spawn_cells, cfg):
				continue
			var data: CellData = cells[cell]
			if data == null or not data.walkable or data.resource_type != StringName() or data.spawn_key != StringName() or data.is_core:
				continue
			candidates.append(cell)
	_shuffle_cells(candidates, rng)

	var event_point_count: int = min(int(cfg.get("event_point_count", EVENT_POINT_COUNT)), candidates.size())
	for index in range(event_point_count):
		event_points.append({
			"cell": candidates[index],
			"event_id": event_ids[rng.randi_range(0, event_ids.size() - 1)]
		})
	return event_points


static func _is_protected_cell(cell: Vector2i, core_cell: Vector2i, spawn_cells: Array[Vector2i], cfg: Dictionary) -> bool:
	var core_safe_radius: int = int(cfg.get("core_safe_radius", CORE_SAFE_RADIUS))
	var spawn_safe_radius: int = int(cfg.get("spawn_safe_radius", SPAWN_SAFE_RADIUS))
	if max(absi(cell.x - core_cell.x), absi(cell.y - core_cell.y)) <= core_safe_radius:
		return true
	for spawn_cell in spawn_cells:
		if max(absi(cell.x - spawn_cell.x), absi(cell.y - spawn_cell.y)) <= spawn_safe_radius:
			return true
	return false


static func _has_ground_path(
	cells: Dictionary,
	width: int,
	height: int,
	start_cell: Vector2i,
	end_cell: Vector2i
) -> bool:
	var queue: Array[Vector2i] = [start_cell]
	var visited: Dictionary = {start_cell: true}
	var head: int = 0

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == end_cell:
			return true

		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			if visited.has(neighbor):
				continue

			var data: CellData = cells.get(neighbor)
			if data == null or not data.walkable:
				continue

			visited[neighbor] = true
			queue.append(neighbor)

	return false


static func _shuffle_cells(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	if cells.size() <= 1:
		return
	for i in range(cells.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, i)
		var temp: Vector2i = cells[i]
		cells[i] = cells[swap_index]
		cells[swap_index] = temp


## 资源风味放置 v2（设计稿 S8）：包装 _place_resources 的近环保底块（UNTOUCHED），
## 远区换加权无放回抽取：风味亲和 ×3（wood/mana→水邻近 cheb≤2，stone→山邻近 cheb≤2）、
## 扇区 resource_mult 倍率、risk_reward_bias ×3/2（靠近阻挡或隘口外侧），
## 走廊格排除；决定性（候选 (y,x) 序 + rng 流）。
static func _place_resources_v2(
	cells: Dictionary,
	width: int,
	height: int,
	spawn_cells: Array[Vector2i],
	core_cell: Vector2i,
	rng: RandomNumberGenerator,
	cfg: Dictionary,
	skeleton: Dictionary,
	corridors: Dictionary
) -> void:
	var target_per_type: int = int(cfg.get("resources_per_type", RESOURCES_PER_TYPE))
	var near_target_per_type: int = mini(int(cfg.get("near_resources_per_type", NEAR_RESOURCES_PER_TYPE)), target_per_type)

	# 预扫：corridor 并集（走廊排除集）。
	var corridor_set: Dictionary = {}
	for raw_key: Variant in corridors.keys():
		var entry: Dictionary = corridors[raw_key]
		for raw_cell: Variant in (entry.get("cells", {}) as Dictionary).keys():
			corridor_set[raw_cell] = true

	# 预扫：水邻近集（cheb ≤2 膨胀，用于 wood/mana 亲和）。
	var water_near: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var data: CellData = cells.get(cell) as CellData
			if data != null and data.terrain == CellData.TERRAIN_WATER:
				for dy2 in range(-2, 3):
					for dx2 in range(-2, 3):
						water_near[Vector2i(x + dx2, y + dy2)] = true

	# 预扫：山邻近集（cheb ≤2，用于 stone 亲和）。
	var mountain_near: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var data: CellData = cells.get(cell) as CellData
			if data != null and data.terrain == CellData.TERRAIN_MOUNTAIN:
				for dy2 in range(-2, 3):
					for dx2 in range(-2, 3):
						mountain_near[Vector2i(x + dx2, y + dy2)] = true

	# 预扫：阻挡邻近集（任一阻挡格 cheb ≤2，用于 risk_reward）。
	var blocked_near: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var data: CellData = cells.get(cell) as CellData
			if data != null and not data.walkable:
				for dy2 in range(-2, 3):
					for dx2 in range(-2, 3):
						blocked_near[Vector2i(x + dx2, y + dy2)] = true

	# 预扫：锚环表（gate_key → cheb(anchor.cell, core)）。
	var anchor_rings: Dictionary = {}
	var anchors: Dictionary = skeleton.get("anchors", {})
	for raw_key: Variant in anchors.keys():
		var entry: Dictionary = anchors[raw_key]
		var anchor_cell: Vector2i = entry.get("cell", core_cell)
		anchor_rings[String(raw_key)] = maxi(absi(anchor_cell.x - core_cell.x), absi(anchor_cell.y - core_cell.y))

	# 扇区倍率表（gate_key → resource_mult float）。
	var sector_mults: Dictionary = {}
	var sector_cards: Dictionary = cfg.get("sector_cards", {})
	var cards_map: Dictionary = skeleton.get("cards", {})
	for raw_key: Variant in anchors.keys():
		var card_id := String(cards_map.get(String(raw_key), "bastion"))
		var card_cfg: Dictionary = sector_cards.get(card_id, {})
		sector_mults[String(raw_key)] = float(card_cfg.get("resource_mult", 1.0))

	var sector_of: Dictionary = skeleton.get("sector_of", {})
	var risk_reward_bias: float = float((cfg.get("economy", {}) as Dictionary).get("risk_reward_bias", 0.5))

	# 候选收集（按 (y,x) 序，保证决定性）。
	var near_candidates: Array[Vector2i] = []
	var far_candidates: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell := Vector2i(x, y)
			var near_ring := _is_near_exploration_ring(cell, core_cell)
			if _is_protected_cell(cell, core_cell, spawn_cells, cfg) and not near_ring:
				continue
			var data: CellData = cells.get(cell) as CellData
			if data == null or not data.walkable or data.resource_type != StringName() or data.spawn_key != StringName():
				continue
			if near_ring:
				near_candidates.append(cell)
			else:
				if not corridor_set.has(cell):
					far_candidates.append(cell)

	# 近环保底（原样复用）。
	_shuffle_cells(near_candidates, rng)
	var resource_types: Array[StringName] = [&"wood", &"stone", &"mana"]
	var placed_by_type: Dictionary = {}
	for rt in resource_types:
		placed_by_type[rt] = 0
	for rt in resource_types:
		_place_resource_type(cells, near_candidates, rt, near_target_per_type, placed_by_type)

	# 远区加权无放回抽取（固定序 wood→stone→mana）。
	for rt in resource_types:
		var remaining: int = target_per_type - int(placed_by_type.get(rt, 0))
		if remaining <= 0:
			continue
		# 当前远区候选（剔除已被占用的格）。
		var pool: Array[Vector2i] = []
		for cell: Vector2i in far_candidates:
			var data: CellData = cells.get(cell) as CellData
			if data == null or not data.walkable or data.resource_type != StringName():
				continue
			pool.append(cell)
		# 逐次加权抽取（无放回）。
		for _pick_iter in range(remaining):
			if pool.is_empty():
				break
			# 计算权重向量（整数，(y,x) 序已由 pool 构造序保证）。
			var weights: Array[int] = []
			var total_w: int = 0
			for cell: Vector2i in pool:
				var w: int = 16
				# 亲和 ×3。
				var affinity_hit := false
				if rt == &"wood" or rt == &"mana":
					affinity_hit = water_near.has(cell)
				else:  # stone
					affinity_hit = mountain_near.has(cell)
				if affinity_hit:
					w *= 3
				# 扇区倍率。
				var gate_key: String = String(sector_of.get(cell, "S1"))
				var mult: float = float(sector_mults.get(gate_key, 1.0))
				w = int(round(float(w) * mult * 16.0)) / 16
				if w < 1:
					w = 1
				# risk_reward_bias（×3/2）：靠近阻挡 cheb≤2，或 ring > 锚环。
				var ring_c: int = maxi(absi(cell.x - core_cell.x), absi(cell.y - core_cell.y))
				var anchor_ring: int = int(anchor_rings.get(gate_key, 0))
				var risk_hit := blocked_near.has(cell) or (anchor_ring > 0 and ring_c > anchor_ring)
				if risk_hit and risk_reward_bias > 0.0:
					w = w * 3 / 2
				if w < 1:
					w = 1
				weights.append(w)
				total_w += w
			if total_w <= 0:
				break
			# 滚动累计选格。
			var roll: int = rng.randi_range(0, total_w - 1)
			var cursor: int = 0
			var chosen_idx: int = pool.size() - 1
			for idx in range(pool.size()):
				cursor += weights[idx]
				if roll < cursor:
					chosen_idx = idx
					break
			var chosen: Vector2i = pool[chosen_idx]
			var chosen_data: CellData = cells.get(chosen) as CellData
			if chosen_data != null:
				_set_resource_node(chosen_data, rt)
				placed_by_type[rt] = int(placed_by_type.get(rt, 0)) + 1
			pool.remove_at(chosen_idx)


## 绕路上限修复（设计稿 S6②）：每口真实 BFS 路长 / 曼哈顿 > detour_cap 时，
## 鞍部软代价 A* 取门→核心最小代价路径，凿穿其上全部阻挡格（恢复平原），
## 任意墙厚一次贯通。每口 ≤ max_repair_rounds 轮；纯确定性，无 RNG。
static func _repair_gate_detours(cells: Dictionary, width: int, height: int, spawn_cells: Array[Vector2i], core_cell: Vector2i, cfg: Dictionary) -> void:
	var detour_cap: float = float(cfg.get("detour_cap", 1.6))
	var max_rounds: int = maxi(int(cfg.get("max_repair_rounds", 3)), 0)
	for spawn_cell in spawn_cells:
		for _round in range(max_rounds):
			var dist_gate: Dictionary = _bfs_distances(cells, width, height, spawn_cell)
			var path_len: int = int(dist_gate.get(core_cell, -1))
			var manhattan_len: int = maxi(absi(spawn_cell.x - core_cell.x) + absi(spawn_cell.y - core_cell.y), 1)
			if path_len > 0 and float(path_len) / float(manhattan_len) <= detour_cap:
				break
			var carve_path: Array[Vector2i] = _soft_cost_path(cells, width, height, spawn_cell, core_cell, cfg)
			if carve_path.is_empty():
				break
			var carved_any := false
			for path_cell in carve_path:
				var data: CellData = cells.get(path_cell)
				if data == null or data.walkable:
					continue
				if data.spawn_key != StringName() or data.is_core or data.resource_type != StringName():
					continue
				data.set_base_terrain(CellData.TERRAIN_PLAIN)
				carved_any = true
			if not carved_any:
				break


static func _bfs_distances(cells: Dictionary, width: int, height: int, origin: Vector2i) -> Dictionary:
	var dist: Dictionary = {origin: 0}
	var queue: Array[Vector2i] = [origin]
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			if dist.has(neighbor):
				continue
			var data: CellData = cells.get(neighbor)
			if data == null or not data.walkable:
				continue
			dist[neighbor] = int(dist[current]) + 1
			queue.append(neighbor)
	return dist


## 鞍部软代价 A*（设计稿 S6①）：字典序代价 = 步数主序 + carve_costs 次序（水 6/山 12）。
## 步数优先保证凿后路长≈曼哈顿（detour_cap 硬达标）；同步数路径间按开凿代价取最小，
## 天然偏向薄壁与水面（渡口/垭口），任意墙厚一次贯通。纯加性软代价会被既有绕路
##（全可走、零开凿代价）压过而拒绝开凿，无法压绕路比，故步数必须为主序。
static func _soft_cost_path(cells: Dictionary, width: int, height: int, start_cell: Vector2i, end_cell: Vector2i, cfg: Dictionary) -> Array[Vector2i]:
	var repair_cfg: Dictionary = cfg.get("repair", {}) if typeof(cfg.get("repair", {})) == TYPE_DICTIONARY else {}
	var carve_costs: Dictionary = repair_cfg.get("carve_costs", {}) if typeof(repair_cfg.get("carve_costs", {})) == TYPE_DICTIONARY else {}
	var water_cost: int = maxi(int(carve_costs.get("water", 6)), 1)
	var mountain_cost: int = maxi(int(carve_costs.get("mountain", 12)), 1)
	# 步数单元 > 全图开凿代价总和上界，确保字典序严格成立。
	var step_unit: int = width * height * maxi(water_cost, mountain_cost) + 1
	var dist: Dictionary = {start_cell: 0}
	var came_from: Dictionary = {}
	var frontier: Array[Vector2i] = [start_cell]
	while not frontier.is_empty():
		var best_index: int = 0
		var best_cell: Vector2i = frontier[0]
		var best_cost: int = int(dist.get(best_cell, 1 << 30))
		for i in range(1, frontier.size()):
			var candidate: Vector2i = frontier[i]
			var cost: int = int(dist.get(candidate, 1 << 30))
			if cost < best_cost or (cost == best_cost and (candidate.y < best_cell.y or (candidate.y == best_cell.y and candidate.x < best_cell.x))):
				best_index = i
				best_cell = candidate
				best_cost = cost
		frontier.remove_at(best_index)
		if best_cell == end_cell:
			break
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = best_cell + direction
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			var data: CellData = cells.get(neighbor)
			if data == null:
				continue
			var step_cost: int = step_unit
			if not data.walkable:
				if data.spawn_key != StringName() or data.is_core or data.resource_type != StringName():
					continue
				step_cost = step_unit + (water_cost if data.terrain == CellData.TERRAIN_WATER else mountain_cost)
			var next_cost: int = best_cost + step_cost
			if next_cost < int(dist.get(neighbor, 1 << 30)):
				dist[neighbor] = next_cost
				came_from[neighbor] = best_cell
				if not frontier.has(neighbor):
					frontier.append(neighbor)
	if not dist.has(end_cell):
		return []
	var path: Array[Vector2i] = [end_cell]
	var current: Vector2i = end_cell
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path
