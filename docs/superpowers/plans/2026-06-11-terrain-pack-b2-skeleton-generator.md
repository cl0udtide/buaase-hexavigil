# 地形包阶段 B2：骨架生成器（牌组 / 车道 / 长肉 / 修复 / mesa / 切换）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地设计稿 S0-S9 全管线：archetype×扇区牌抽取 → 等弧门+楔形扇区+隘口锚 → 噪声代价车道+protected 集 → 山/河/湖长肉（预算台账） → 侵蚀+CA → corridor 派生+全量修复（隘口分级/口袋/占比回调/入侵度） → mesa 平台反漂移放置 → 资源风味 → 编排器+重试+兜底，最终把 `data/map_generation.json` 切到 `"generator": "skeleton_v2"`（legacy 保留可切回）。

**Architecture:**
- 新增 6 个纯静态模块（preload 消费，单文件 ≤ ~400 行）：`scripts/map/generation/skeleton.gd`（抽牌/扇区/锚点）、`lanes.gd`（噪声代价 A* + protected）、`flesh.gd`（山脊/河湖/台账）、`natural.gd`（侵蚀+CA 清渣；从 flesh 拆出以守行数线，B2-6 创建）、`gen_repair.gd`（corridor 派生+全量修复）、`mesa.gd`（高台放置）。
- `map_generator.gd` 新增编排器 `generate_v2()`；`generate()` 按 `cfg.generator` 分派（默认 `"legacy"`，B2-11 才翻 json）。旧管线整体提取为 `_generate_legacy()`，返回 dict 补 `"sectors": {}`、`"gen_report": {}` 两个空键。`map_manager.generate_new_map` 只读 cells/core_cell/spawn_cells/event_points 四键（`map_manager.gd:41-46` 已核对），**零改动**，B2-10 验证之。
- **复用不重写**：等弧门 `_place_spawns`、`_place_resources` 近环保底（B2-9 包装）、`_build_lake_cluster`、`_try_apply_obstacle_cells` 连通回滚、`_repair_gate_detours` 绕路上限、`_soft_cost_path` 字典序鞍部开凿、`IntNoise`、stage RNG 派生（重试期 `IntNoise.derive_seed(seed, attempt, stage)` 启用 attempt 位）。
- **模块回引规则**：generation/* 模块需要 map_generator 静态函数（`_try_apply_obstacle_cells` / `_soft_cost_path` / `_repair_gate_detours` / `_build_lake_cluster`）时，**禁止 preload**（map_generator 反向 preload 这些模块会成环），统一用运行时取用：

```gdscript
static func _mg() -> GDScript:
	return load("res://scripts/map/map_generator.gd")
```

  generation/* 兄弟模块之间（如 flesh → skeleton 的 `ray_point`）可直接 preload（无环）。
- **决定性纪律**：v2 路径全部随机性来自 `IntNoise.derive_seed(actual_seed, attempt, STAGE_*)` 派生的 RNG 或 IntNoise 纯场采样；一切平局裁决 `(值, y, x)` 全序；**禁 Time/randomize 参与任何生成决策**（`gen_report.elapsed_ms` 等观测值除外，显式注释）。

**接口契约总表**（跨任务引用以此为准；后续任务不得改签名，只能新增）：

```gdscript
# skeleton.gd (class_name MapGenSkeleton)
static func draw_archetype(cfg: Dictionary, rng: RandomNumberGenerator) -> Dictionary
static func deal_cards(archetype: Dictionary, gate_keys: Array, day1_active: Array, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary  # gate_key(String)→card_id(String)
static func roll_wind(rng: RandomNumberGenerator) -> Vector2i
static func assign_sectors(width: int, height: int, gate_cells: Array[Vector2i]) -> Dictionary  # cell→gate_key("S%d"，按 gate_cells 下标+1)
static func place_pass_anchor(gate_cell: Vector2i, core_cell: Vector2i, card_cfg: Dictionary, rng: RandomNumberGenerator) -> Vector2i
static func place_confluences(archetype: Dictionary, gate_cells: Array[Vector2i], core_cell: Vector2i, rng: RandomNumberGenerator) -> Array[Dictionary]  # {"cell": Vector2i, "gate_cells": Array[Vector2i]}
static func ray_point(core: Vector2i, dir: Vector2i, ring: int) -> Vector2i
static func round_div(n: int, d: int) -> int  # d>0，四舍五入

# lanes.gd (class_name MapGenLanes)
static func trace_lane(cells: Dictionary, gate: Vector2i, waypoints: Array[Vector2i], core: Vector2i, jitter_amp: float, noise_seed: int) -> Array[Vector2i]
static func trace_lane_checked(cells: Dictionary, gate: Vector2i, waypoints: Array[Vector2i], core: Vector2i, jitter_amp: float, noise_seed: int) -> Array[Vector2i]
static func lane_ratio(path: Array[Vector2i], gate: Vector2i, core: Vector2i) -> float
static func aperture_window(anchor: Vector2i, gate: Vector2i, core: Vector2i, pass_width: int, depth: int) -> Array[Vector2i]
static func build_protected(lanes: Dictionary, core: Vector2i, gates: Array[Vector2i], anchors: Dictionary, cfg: Dictionary) -> Dictionary  # cell→StringName 类别

# flesh.gd (class_name MapGenFlesh)
static func make_ledger(cfg: Dictionary, archetype: Dictionary, cards: Dictionary, width: int, height: int) -> Dictionary
static func ledger_note(ledger: Dictionary, stage: String, requested: int, applied: int, rolled_back: int) -> void
static func grow_ridges(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary) -> void
static func build_elevation(cells: Dictionary, width: int, height: int, seed_value: int) -> Dictionary  # cell→int
static func roll_water_plans(skeleton: Dictionary, wind_dir: Vector2i, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary  # gate_key→{"river": bool, "lakes": int}
static func trace_river(cells: Dictionary, skeleton: Dictionary, gate_key: String, elevation: Dictionary, protected: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary) -> Dictionary  # {"river_cells","pond_cells","ford_cells"}
static func place_lakes(cells: Dictionary, skeleton: Dictionary, gate_key: String, lake_count: int, protected: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary) -> void

# natural.gd (class_name MapGenNatural)
static func erode_edges(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, seed_value: int, ledger: Dictionary) -> void
static func cellular_cleanup(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, ledger: Dictionary) -> void

# gen_repair.gd (class_name MapGenRepair)
static func derive_corridor(cells: Dictionary, gate: Vector2i, core: Vector2i, slack: int = 3) -> Dictionary  # {"cells": Dictionary集, "shortest": int}
static func derive_all_corridors(cells: Dictionary, skeleton: Dictionary, slack: int) -> Dictionary  # gate_key→corridor dict
static func full_repair(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, elevation: Dictionary, ledger: Dictionary) -> Dictionary
	# 返回 {"ok": bool, "fail_reason": String, "pass_grades": Dictionary, "corridors": Dictionary, "intrusion": int}

# mesa.gd (class_name MapGenMesa)
const SHAPES: Dictionary  # size(int)→Array[Array[Vector2i]]（形状目录，B2-8 给全量）
static func place_mesas(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, corridors: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary) -> Dictionary
	# 返回 {"ok": bool, "degraded": bool, "mesas": Array[Dictionary], "corridors": Dictionary}

# map_generator.gd 新增
const STAGE_CARDS := 11; const STAGE_GEOMETRY := 12; const STAGE_LANES := 13; const STAGE_RIDGES := 14
const STAGE_WATER := 15; const STAGE_EROSION := 16; const STAGE_REPAIR_V2 := 17; const STAGE_MESA := 18
static func _stage_rng_v2(run_seed: int, attempt: int, stage_id: int) -> RandomNumberGenerator
static func generate_v2(width: int, height: int, seed: int, cfg: Dictionary, event_ids: Array[StringName]) -> Dictionary
static func _generate_legacy(width: int, height: int, seed: int, cfg: Dictionary, event_ids: Array[StringName]) -> Dictionary
static func _place_resources_v2(cells: Dictionary, width: int, height: int, spawn_cells: Array[Vector2i], core_cell: Vector2i, rng: RandomNumberGenerator, cfg: Dictionary, skeleton: Dictionary, corridors: Dictionary) -> void
```

**skeleton 上下文 dict**（编排器组装，各模块只读；fords 由 trace_river 阶段写回）：

```gdscript
skeleton := {
	"width": int, "height": int, "core": Vector2i,
	"gate_keys": Array,            # ["S1".."S5"]，与 spawn_cells 下标对应
	"gate_cells": Dictionary,      # gate_key→Vector2i
	"spawn_cells": Array[Vector2i],
	"cards": Dictionary,           # gate_key→card_id
	"card_cfgs": Dictionary,       # card_id→cfg.sector_cards[card_id]
	"archetype": Dictionary,       # 含 ratio_band（保守剖面时为收窄副本）
	"wind": Vector2i,
	"sector_of": Dictionary,       # cell→gate_key
	"anchors": Dictionary,         # gate_key→{"cell": Vector2i, "pass_width": int, "aperture": Array[Vector2i]}
	"confluences": Array[Dictionary],
	"lanes": Dictionary,           # gate_key→Array[Vector2i]
	"fords": Dictionary,           # gate_key→Array[Vector2i]（无渡口则缺键）
	"conservative": bool,
	"cfg": Dictionary,
}
```

**protected 集**：`Dictionary[Vector2i→StringName]`，类别 `&"core"/&"apron"/&"aperture"/&"pocket"/&"lane"`，**先注册先得**（注册顺序 core→apron→aperture→pocket→lane）。一般地貌一律不得触碰 protected；唯一豁免：河流可淹 `&"lane"` 类别格（渡口窗除外，见 B2-5）。

**ledger**：`{"target": int, "requested": int, "applied": int, "rolled_back": int, "repair_intrusion": int, "sector_quota": Dictionary, "sector_applied": Dictionary, "stages": Dictionary}`（stages: stage 名→{requested, applied, rolled_back}）。

**Tech Stack:** Godot 4.6 GDScript（TAB 缩进、警告即错误、preload 常量跨文件引用）；headless `extends SceneTree` 回归套件扩展 `scripts/debug/test_map_generation.gd`。

**规格:** docs/superpowers/specs/2026-06-11-terrain-generation-design-draft.md §0.1（SF-2 分级验收）/§1（S0-S9）/§2.1-2.4+2.6（地貌与 mesa 修订版）/§3（修复表）/§4（牌与 archetype、§4.4 schema）/§5（决定性与重试）/§6（测试）/§7（迁移）

**通用约束:**
- 测试命令 `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/test_map_generation.gd`；其他套件同形换文件名；boot 检查 `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5`（输出无 ERROR/SCRIPT ERROR）。
- 每任务收尾 `--check-only` 解析全部受改 .gd；conventional commits；**禁 `git add -A`**（git status 现有杂项 uid 文件勿带入）。
- 每任务一个 commit；测试先行（红→绿）；回归最小集 = test_map_generation + test_spawn_gates_v2（触碰 map_generator.gd / json 的任务），B2-10/11 跑十套件全量。
- 行数线：单模块 ≤ ~400 行；flesh.gd 若在 B2-6 前已超线，按本计划把侵蚀/CA 放进 natural.gd（已预授权，无需再请示）。

**文件总览:**
- Modify: `data/map_generation.json`（B2-1 扩 schema 留 legacy；B2-11 翻 generator）
- Create: `scripts/map/generation/skeleton.gd`（B2-1/2）、`lanes.gd`（B2-3）、`flesh.gd`（B2-4/5）、`natural.gd`（B2-6）、`gen_repair.gd`（B2-7）、`mesa.gd`（B2-8）
- Modify: `scripts/map/map_generator.gd`（B2-9 资源包装；B2-10 编排器+分派）
- Modify: `scripts/debug/test_map_generation.gd`（每任务追加测试）
- Modify: `docs/DATA_SCHEMA.md`、`docs/superpowers/specs/2026-06-11-terrain-generation-design-draft.md`、`docs/肉鸽构筑与战斗优化方案.md`（B2-11 统一同步）

---

### Task B2-1: schema 扩展 + 抽牌（archetype / 发牌约束 / 风向）

**Files:**
- Modify: `data/map_generation.json`
- Create: `scripts/map/generation/skeleton.gd`
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。** 套件顶部加 preload 与公共 cfg 助手，`_run()` 中 `_finish()` 前追加 `_test_cards_archetypes_wind()`：

```gdscript
const SkeletonGen = preload("res://scripts/map/generation/skeleton.gd")
const NightResolverRef = preload("res://scripts/enemy/night_template_resolver.gd")


## v2 配置字面量（密封测试用，不读 json；数值=设计稿 §4.4，平衡占位可自由取整）。
func _v2_cfg() -> Dictionary:
	return {
		"width": 30, "height": 30, "spawn_count": 5,
		"resources_per_type": 12, "near_resources_per_type": 2, "event_point_count": 0,
		"core_safe_radius": 3, "spawn_safe_radius": 2,
		"spawn_corner_margin": 3, "spawn_arc_center_ratio": 0.6,
		"generator": "skeleton_v2",
		"max_retries": 5, "max_repair_rounds": 3,
		"detour_cap": 1.6, "detour_floor": 1.15,
		"lane_jitter_base": 0.35, "corridor_slack": 3, "gate_slide_jitter": 2,
		"repair": {
			"carve_costs": {"water": 6, "mountain": 12},
			"intrusion_max_per_map": 0.15, "intrusion_max_mean": 0.10,
			"dual_pass_ratio_cap": 0.25,
		},
		"pass": {"aperture_depth": 2, "pocket_core_w": 3, "pocket_core_h": 2,
			"pocket_min_plain": 6, "pocket_flood_limit": 12},
		"mesa": {
			"count_min": 4, "count_max": 6, "count_floor_degraded": 3,
			"cells_min": 14, "cells_max": 24,
			"size_weights": {"3": 0.30, "4": 0.35, "5": 0.20, "6": 0.15},
			"max_corridor_dist": 2, "min_covered_ratio": 0.6,
			"starter": {"ring_min": 4, "ring_max": 5, "size_min": 3, "size_max": 4, "max_corridor_dist": 2},
		},
		"economy": {
			"resource_affinity": {"wood": "moist_plain", "stone": "foothill", "mana": "water_adjacent"},
			"risk_reward_bias": 0.5,
		},
		"moisture_gradient_strength": 0.2,
		"sector_cards": {
			"bastion": {"pass_width": 2, "pass_ring": [6, 8], "density": 1.3, "mesa_quota": 1, "jitter_amp": 0.5, "resource_mult": 1.0},
			"steppe": {"pass_width": 5, "pass_ring": [7, 10], "density": 0.6, "mesa_quota": 0, "jitter_amp": 0.3, "resource_mult": 1.5, "lake": [1, 2]},
			"riverlands": {"pass_width": 2, "pass_ring": [6, 9], "density": 0.9, "mesa_quota": 1, "jitter_amp": 0.4, "resource_mult": 1.1, "river": true, "ford_width": 2},
			"canyon": {"pass_width": 3, "pass_ring": [6, 10], "density": 1.2, "mesa_quota": 1, "jitter_amp": 0.35, "resource_mult": 0.9, "corridor_len": [6, 9]},
		},
		"archetypes": [
			{"id": "highland_run", "weight": 1.0, "deck": {"bastion": 2, "canyon": 2, "steppe": 1},
				"confluence": "five_fingers", "ratio_band": [0.24, 0.28]},
			{"id": "riverine_run", "weight": 1.0, "deck": {"riverlands": 3, "steppe": 1, "bastion": 1},
				"confluence": "twin_pincers", "ratio_band": [0.20, 0.24]},
			{"id": "open_run", "weight": 1.0, "deck": {"steppe": 3, "bastion": 1, "riverlands": 1},
				"confluence": "trident", "ratio_band": [0.20, 0.22]},
		],
		"day1_card_constraint": "no_double_steppe",
		"bias_cards_by_activation": false,
	}


func _new_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_cards_archetypes_wind() -> void:
	var cfg := _v2_cfg()
	# json 已扩 schema（值与 _v2_cfg 同源；generator 在 B2-11 前保持 legacy）。
	var file := FileAccess.open("res://data/map_generation.json", FileAccess.READ)
	_expect(file != null, "map_generation.json readable")
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	for key in ["generator", "sector_cards", "archetypes", "day1_card_constraint",
			"moisture_gradient_strength", "pass", "mesa", "economy",
			"detour_floor", "lane_jitter_base", "corridor_slack", "gate_slide_jitter", "max_retries"]:
		_expect(parsed.has(key), "json has key %s" % key)
	_expect(["legacy", "skeleton_v2"].has(String(parsed.get("generator", ""))), "generator value sane")
	_expect(int(parsed.get("spawn_safe_radius", 0)) == 2, "spawn_safe_radius raised to 2 (spec 4.4)")
	_expect((parsed.get("sector_cards", {}) as Dictionary).size() == 4, "4 sector cards in json")
	_expect((parsed.get("archetypes", []) as Array).size() == 3, "3 archetypes in json")
	# archetype 抽取：分布覆盖 + 决定性。
	var seen: Dictionary = {}
	for seed_value in range(60):
		var arch: Dictionary = SkeletonGen.draw_archetype(cfg, _new_rng(seed_value))
		seen[String(arch.get("id", ""))] = true
	for arch_id in ["highland_run", "riverine_run", "open_run"]:
		_expect(seen.has(arch_id), "archetype %s drawn within 60 seeds" % arch_id)
	_expect(str(SkeletonGen.draw_archetype(cfg, _new_rng(7))) == str(SkeletonGen.draw_archetype(cfg, _new_rng(7))), "draw_archetype deterministic")
	# 发牌：牌面=牌组多重集、day1 约束 100 个种子零违反、决定性。
	var gate_keys: Array = ["S1", "S2", "S3", "S4", "S5"]
	for seed_value in range(100):
		var arch: Dictionary = SkeletonGen.draw_archetype(cfg, _new_rng(seed_value))
		var day1: Array = NightResolverRef.resolve_active_gates(gate_keys, seed_value, 1)
		var cards: Dictionary = SkeletonGen.deal_cards(arch, gate_keys, day1, _new_rng(seed_value * 31 + 1), cfg)
		_expect(cards.size() == 5, "seed %d: 5 cards dealt" % seed_value)
		var counts: Dictionary = {}
		for raw_key: Variant in cards.keys():
			var card_id := String(cards[raw_key])
			counts[card_id] = int(counts.get(card_id, 0)) + 1
		var deck: Dictionary = arch.get("deck", {})
		for raw_card: Variant in deck.keys():
			_expect(int(counts.get(String(raw_card), 0)) == int(deck[raw_card]), "seed %d: deck multiset preserved for %s" % [seed_value, String(raw_card)])
		var steppe_on_day1: int = 0
		for raw_gate: Variant in day1:
			if String(cards.get(String(raw_gate), "")) == "steppe":
				steppe_on_day1 += 1
		_expect(steppe_on_day1 < day1.size(), "seed %d: no_double_steppe holds (day1 gates=%s)" % [seed_value, str(day1)])
	var cards_a: Dictionary = SkeletonGen.deal_cards(cfg["archetypes"][2], gate_keys, ["S1", "S2"], _new_rng(99), cfg)
	var cards_b: Dictionary = SkeletonGen.deal_cards(cfg["archetypes"][2], gate_keys, ["S1", "S2"], _new_rng(99), cfg)
	_expect(str(cards_a) == str(cards_b), "deal_cards deterministic")
	# 风向：八向之一 + 决定性。
	var wind: Vector2i = SkeletonGen.roll_wind(_new_rng(5))
	_expect(wind != Vector2i.ZERO and absi(wind.x) <= 1 and absi(wind.y) <= 1, "wind is one of 8 compass dirs")
	_expect(SkeletonGen.roll_wind(_new_rng(5)) == wind, "roll_wind deterministic")
```

- [ ] **Step 2: 跑套件确认失败**（skeleton.gd 不存在 → preload 报错即红）。

- [ ] **Step 3: 改写 `data/map_generation.json`**（保留现行全部键；`spawn_safe_radius` 1→2 按规格 §4.4；新键值逐字对齐 `_v2_cfg()`；**`"generator": "legacy"`**——B2-11 才翻）：

```json
{
  "width": 30,
  "height": 30,
  "generator": "legacy",
  "spawn_count": 5,
  "resources_per_type": 12,
  "near_resources_per_type": 2,
  "event_point_count": 0,
  "obstacle_ratio": 0.13,
  "water_obstacle_chance": 0.35,
  "min_obstacle_count": 65,
  "max_obstacle_count": 115,
  "terrain_cluster_count": 5,
  "terrain_cluster_min_size": 12,
  "terrain_cluster_max_size": 28,
  "terrain_cluster_attempts": 24,
  "scattered_obstacle_ratio": 0.22,
  "core_safe_radius": 3,
  "spawn_safe_radius": 2,
  "spawn_corner_margin": 3,
  "spawn_arc_center_ratio": 0.6,
  "max_retries": 5,
  "max_repair_rounds": 3,
  "detour_cap": 1.6,
  "detour_floor": 1.15,
  "lane_jitter_base": 0.35,
  "corridor_slack": 3,
  "gate_slide_jitter": 2,
  "repair": {
    "carve_costs": { "water": 6, "mountain": 12 },
    "intrusion_max_per_map": 0.15,
    "intrusion_max_mean": 0.10,
    "dual_pass_ratio_cap": 0.25
  },
  "pass": { "aperture_depth": 2, "pocket_core_w": 3, "pocket_core_h": 2, "pocket_min_plain": 6, "pocket_flood_limit": 12 },
  "mesa": {
    "count_min": 4, "count_max": 6, "count_floor_degraded": 3,
    "cells_min": 14, "cells_max": 24,
    "size_weights": { "3": 0.30, "4": 0.35, "5": 0.20, "6": 0.15 },
    "max_corridor_dist": 2, "min_covered_ratio": 0.6,
    "starter": { "ring_min": 4, "ring_max": 5, "size_min": 3, "size_max": 4, "max_corridor_dist": 2 }
  },
  "economy": {
    "resource_affinity": { "wood": "moist_plain", "stone": "foothill", "mana": "water_adjacent" },
    "risk_reward_bias": 0.5
  },
  "moisture_gradient_strength": 0.2,
  "sector_cards": {
    "bastion":    { "pass_width": 2, "pass_ring": [6, 8],  "density": 1.3, "mesa_quota": 1, "jitter_amp": 0.5,  "resource_mult": 1.0 },
    "steppe":     { "pass_width": 5, "pass_ring": [7, 10], "density": 0.6, "mesa_quota": 0, "jitter_amp": 0.3,  "resource_mult": 1.5, "lake": [1, 2] },
    "riverlands": { "pass_width": 2, "pass_ring": [6, 9],  "density": 0.9, "mesa_quota": 1, "jitter_amp": 0.4,  "resource_mult": 1.1, "river": true, "ford_width": 2 },
    "canyon":     { "pass_width": 3, "pass_ring": [6, 10], "density": 1.2, "mesa_quota": 1, "jitter_amp": 0.35, "resource_mult": 0.9, "corridor_len": [6, 9] }
  },
  "archetypes": [
    { "id": "highland_run", "weight": 1.0, "deck": { "bastion": 2, "canyon": 2, "steppe": 1 },
      "confluence": "five_fingers", "ratio_band": [0.24, 0.28] },
    { "id": "riverine_run", "weight": 1.0, "deck": { "riverlands": 3, "steppe": 1, "bastion": 1 },
      "confluence": "twin_pincers", "ratio_band": [0.20, 0.24] },
    { "id": "open_run", "weight": 1.0, "deck": { "steppe": 3, "bastion": 1, "riverlands": 1 },
      "confluence": "trident", "ratio_band": [0.20, 0.22] }
  ],
  "day1_card_constraint": "no_double_steppe",
  "bias_cards_by_activation": false
}
```

注：规格 §4.4 的 `carve_costs.plain` 与 `saddle_weight` **不入 json**——B1 已落地的修复语义是字典序（步数主序 + 水/山权重次序，见 `_soft_cost_path` 头注），plain 成本与鞍部加权在该语义下无意义；B2-11 把规格文档同步到实现（见自审）。

- [ ] **Step 4: 实现 `scripts/map/generation/skeleton.gd`**（B2-1 范围：抽牌三函数 + 两个整数几何助手；扇区函数 B2-2 续写同文件）：

```gdscript
class_name MapGenSkeleton
extends RefCounted

## 骨架生成（设计稿 S1/S2）：archetype 抽取、扇区发牌（day1 约束）、风向、
## 整数射线/扇区几何。纯静态、决定性；headless 经 preload 使用。

const REDRAW_LIMIT := 8
const WIND_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]


static func draw_archetype(cfg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var entries: Array = cfg.get("archetypes", [])
	if entries.is_empty():
		return {}
	var total: float = 0.0
	for raw: Variant in entries:
		total += maxf(float((raw as Dictionary).get("weight", 1.0)), 0.0)
	var roll: float = rng.randf() * total
	var cursor: float = 0.0
	for raw: Variant in entries:
		var entry: Dictionary = raw
		cursor += maxf(float(entry.get("weight", 1.0)), 0.0)
		if roll < cursor:
			return entry
	return entries[entries.size() - 1]


static func deal_cards(archetype: Dictionary, gate_keys: Array, day1_active: Array, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	# 牌组展开（card_id 排序保证同 deck 同展开序）→ Fisher-Yates → 依 gate_keys 升序派发。
	# 约束 no_double_steppe：day1 活跃口不得全为 steppe；重抽 ≤REDRAW_LIMIT，
	# 仍违反 → 确定性交换兜底（首个 day1 steppe 口 ↔ 首个非 day1 非 steppe 口，均按 key 升序）。
	...
	return assigned  # gate_key→card_id


static func roll_wind(rng: RandomNumberGenerator) -> Vector2i:
	return WIND_DIRS[rng.randi_range(0, WIND_DIRS.size() - 1)]


static func round_div(n: int, d: int) -> int:
	# d > 0；四舍五入（.5 远离零），负 n 对称处理——射线取格决定性的基石。
	if n >= 0:
		return (2 * n + d) / (2 * d)
	return -((-2 * n + d) / (2 * d))


static func ray_point(core: Vector2i, dir: Vector2i, ring: int) -> Vector2i:
	# 核心→dir 射线上切比雪夫环 = ring 的格（dir 主轴长 L 归一）。
	var l: int = maxi(maxi(absi(dir.x), absi(dir.y)), 1)
	return core + Vector2i(round_div(dir.x * ring, l), round_div(dir.y * ring, l))
```

`deal_cards` 实现要点（完整逻辑，编码照写）：

```gdscript
	var deck: Dictionary = archetype.get("deck", {})
	var card_ids: Array = deck.keys()
	card_ids.sort()
	var keys_sorted: Array = gate_keys.duplicate()
	keys_sorted.sort()
	for _redraw in range(REDRAW_LIMIT + 1):
		var pile: Array = []
		for raw_card: Variant in card_ids:
			for _i in range(int(deck[raw_card])):
				pile.append(String(raw_card))
		for i in range(pile.size() - 1, 0, -1):           # Fisher-Yates（rng 流内）
			var j: int = rng.randi_range(0, i)
			var tmp: Variant = pile[i]; pile[i] = pile[j]; pile[j] = tmp
		var assigned: Dictionary = {}
		for i in range(keys_sorted.size()):
			assigned[String(keys_sorted[i])] = pile[i % pile.size()]
		if not _violates_day1(assigned, day1_active, cfg):
			return assigned
		if _redraw == REDRAW_LIMIT:
			return _swap_fallback(assigned, day1_active, keys_sorted)
	return {}

# _violates_day1: cfg.day1_card_constraint != "no_double_steppe" 或 day1_active.size()<2 → false；
#                 否则当且仅当 day1 口全为 "steppe" → true。
# _swap_fallback: 首个（升序）day1 口 steppe 牌 与 首个（升序）非 day1 口非 steppe 牌互换；
#                 牌组结构保证存在（任意 deck steppe ≤3 张，5 口中非 day1 口 ≥3 个）。
```

- [ ] **Step 5: 跑套件 → PASSED。** 同步更新既有 `_test_detour_repair` 内 `prod_cfg` 字面量 `"spawn_safe_radius": 1` → `2`（该 cfg 注释承诺逐字镜像 json），重跑确认 4 个生产种子断言仍绿。`--check-only` skeleton.gd / test_map_generation.gd。回归 test_spawn_gates_v2（json 改动）→ PASSED。

- [ ] **Step 6: Commit**

```bash
git add data/map_generation.json scripts/map/generation/skeleton.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): v2 schema keys and archetype card dealing"
```

---

### Task B2-2: 扇区几何（楔形归属 / 隘口锚 / 汇流点）

**Files:**
- Modify: `scripts/map/generation/skeleton.gd`
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。** 追加助手与 `_test_sector_geometry()`（`_run()` 注册）：

```gdscript
func _fixture_gate_cells() -> Array[Vector2i]:
	# 30×30 合成门位（角度互异、贴边、非角落）；S1..S5 = 下标+1。
	var gates: Array[Vector2i] = [Vector2i(15, 0), Vector2i(29, 9), Vector2i(24, 29), Vector2i(6, 29), Vector2i(0, 13)]
	return gates


func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _sector_component_ratio(sector_of: Dictionary, gate: Vector2i, key: String) -> float:
	var total: int = 0
	for raw_cell: Variant in sector_of.keys():
		if String(sector_of[raw_cell]) == key:
			total += 1
	var queue: Array[Vector2i] = [gate]
	var seen: Dictionary = {gate: true}
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var nb: Vector2i = current + direction
			if seen.has(nb) or not sector_of.has(nb):
				continue
			if String(sector_of[nb]) != key:
				continue
			seen[nb] = true
			queue.append(nb)
	return float(seen.size()) / float(maxi(total, 1))


func _test_sector_geometry() -> void:
	var cfg := _v2_cfg()
	var core := Vector2i(15, 15)
	var gates := _fixture_gate_cells()
	var sector_of: Dictionary = SkeletonGen.assign_sectors(30, 30, gates)
	_expect(sector_of.size() == 900, "every cell assigned a sector")
	for i in range(gates.size()):
		var key := "S%d" % (i + 1)
		_expect(String(sector_of.get(gates[i], "")) == key, "gate %s lies in own sector" % key)
		var ratio := _sector_component_ratio(sector_of, gates[i], key)
		_expect(ratio >= 0.95, "sector %s contiguous (gate component %.2f)" % [key, ratio])
	_expect(str(SkeletonGen.assign_sectors(30, 30, gates)) == str(sector_of), "assign_sectors deterministic")
	# 隘口锚：环带内 + 本扇区内 + 决定性。
	for seed_value in range(40):
		for i in range(gates.size()):
			for card_id in ["bastion", "steppe", "riverlands", "canyon"]:
				var card_cfg: Dictionary = cfg["sector_cards"][card_id]
				var anchor: Vector2i = SkeletonGen.place_pass_anchor(gates[i], core, card_cfg, _new_rng(seed_value * 100 + i))
				var ring: int = _cheb(anchor, core)
				var band: Array = card_cfg["pass_ring"]
				_expect(ring >= int(band[0]) and ring <= int(band[1]), "anchor ring %d in band %s (seed %d card %s)" % [ring, str(band), seed_value, card_id])
				_expect(String(sector_of.get(anchor, "")) == "S%d" % (i + 1), "anchor in own sector (seed %d gate %d card %s)" % [seed_value, i, card_id])
	var anchor_a: Vector2i = SkeletonGen.place_pass_anchor(gates[0], core, cfg["sector_cards"]["bastion"], _new_rng(3))
	var anchor_b: Vector2i = SkeletonGen.place_pass_anchor(gates[0], core, cfg["sector_cards"]["bastion"], _new_rng(3))
	_expect(anchor_a == anchor_b, "place_pass_anchor deterministic")
	# 汇流点：拓扑数量 + 环带 5-7 + 决定性。
	for seed_value in range(20):
		var none: Array[Dictionary] = SkeletonGen.place_confluences(cfg["archetypes"][0], gates, core, _new_rng(seed_value))
		_expect(none.is_empty(), "five_fingers has no confluence (seed %d)" % seed_value)
		var twin: Array[Dictionary] = SkeletonGen.place_confluences(cfg["archetypes"][1], gates, core, _new_rng(seed_value))
		_expect(twin.size() == 2, "twin_pincers has 2 confluences (seed %d)" % seed_value)
		var tri: Array[Dictionary] = SkeletonGen.place_confluences(cfg["archetypes"][2], gates, core, _new_rng(seed_value))
		_expect(tri.size() == 3, "trident has 3 confluences (seed %d)" % seed_value)
		for raw_conf: Variant in twin + tri:
			var conf: Dictionary = raw_conf
			var conf_ring: int = _cheb(conf.get("cell", core), core)
			_expect(conf_ring >= 5 and conf_ring <= 7, "confluence ring %d in [5,7] (seed %d)" % [conf_ring, seed_value])
			_expect((conf.get("gate_cells", []) as Array).size() >= 1, "confluence carries gate mapping (seed %d)" % seed_value)
	var twin_a: Array[Dictionary] = SkeletonGen.place_confluences(cfg["archetypes"][1], gates, core, _new_rng(11))
	var twin_b: Array[Dictionary] = SkeletonGen.place_confluences(cfg["archetypes"][1], gates, core, _new_rng(11))
	_expect(str(twin_a) == str(twin_b), "place_confluences deterministic")
```

- [ ] **Step 2: 跑套件确认失败**（assign_sectors 等不存在 → 脚本错误即红）。

- [ ] **Step 3: 实现三函数（skeleton.gd 续写）。**

`assign_sectors`——最近角归属 = 角平分线切楔的离散等价（设计稿 S2「整数叉积判归属，零浮点」），完整代码：

```gdscript
static func assign_sectors(width: int, height: int, gate_cells: Array[Vector2i]) -> Dictionary:
	var core := Vector2i(width / 2, height / 2)
	var sector_of: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var v := cell - core
			var best: int = 0
			for i in range(1, gate_cells.size()):
				if _closer_in_angle(v, gate_cells[i] - core, gate_cells[best] - core, gate_cells[i], gate_cells[best]):
					best = i
			sector_of[cell] = "S%d" % (best + 1)
	return sector_of


## v 与 a 的夹角是否严格小于 v 与 b 的夹角；纯整数（点积平方交叉相乘消根号）。
## 平局 → 门格 (y,x) 较小者胜（全序，决定性）。v=(0,0)（核心格）走平局分支。
static func _closer_in_angle(v: Vector2i, a: Vector2i, b: Vector2i, a_gate: Vector2i, b_gate: Vector2i) -> bool:
	var dot_a: int = v.x * a.x + v.y * a.y
	var dot_b: int = v.x * b.x + v.y * b.y
	if (dot_a >= 0) != (dot_b >= 0):
		return dot_a >= 0
	var lhs: int = dot_a * dot_a * (b.x * b.x + b.y * b.y)
	var rhs: int = dot_b * dot_b * (a.x * a.x + a.y * a.y)
	if lhs != rhs:
		return lhs > rhs if dot_a >= 0 else lhs < rhs
	return a_gate.y < b_gate.y or (a_gate.y == b_gate.y and a_gate.x < b_gate.x)
```

（量级核查：|dot| ≤ ~900，dot² ≤ 8.1e5，×len² ≤ 1.5e9，int64 安全。）

`place_pass_anchor`——射线取环 + 垂直 ±1 抖动，越带回退不抖：

```gdscript
static func place_pass_anchor(gate_cell: Vector2i, core_cell: Vector2i, card_cfg: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var band: Array = card_cfg.get("pass_ring", [6, 8])
	var ring: int = rng.randi_range(int(band[0]), int(band[1]))
	var dir := gate_cell - core_cell
	var base := ray_point(core_cell, dir, ring)
	var perp := Vector2i(0, 1) if absi(dir.x) >= absi(dir.y) else Vector2i(1, 0)
	var candidate := base + perp * rng.randi_range(-1, 1)
	var cheb: int = maxi(absi(candidate.x - core_cell.x), absi(candidate.y - core_cell.y))
	if cheb < int(band[0]) or cheb > int(band[1]):
		return base
	return candidate
```

（注意 rng 消费序固定：先 ring 后 offset，分支不影响消费次数。门格全在边缘 → 距核心 cheb ≥14 > pass_ring 上限 10，锚必在图内两环之间；抖动 ±1 在 ≥31° 角隙下不出本楔——见自审对齐点。）

`place_confluences`——角序相邻配对（twin_pincers 两对、trident 两对+单飞自有拐点），完整代码：

```gdscript
static func place_confluences(archetype: Dictionary, gate_cells: Array[Vector2i], core_cell: Vector2i, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var topology := String(archetype.get("confluence", "five_fingers"))
	var result: Array[Dictionary] = []
	if topology == "five_fingers" or gate_cells.size() < 5:
		return result
	var order := _angle_sorted_indices(gate_cells, core_cell)
	var start: int = rng.randi_range(0, gate_cells.size() - 1)
	var pairs: Array = [
		[order[start % 5], order[(start + 1) % 5]],
		[order[(start + 2) % 5], order[(start + 3) % 5]],
	]
	for raw_pair: Variant in pairs:
		var pair: Array = raw_pair
		var bisector: Vector2i = (gate_cells[pair[0]] - core_cell) + (gate_cells[pair[1]] - core_cell)
		var ring: int = rng.randi_range(5, 7)
		result.append({
			"cell": ray_point(core_cell, bisector, ring),
			"gate_cells": [gate_cells[pair[0]], gate_cells[pair[1]]],
		})
	if topology == "trident":
		var solo: int = order[(start + 4) % 5]
		var ring_solo: int = rng.randi_range(5, 7)
		result.append({
			"cell": ray_point(core_cell, gate_cells[solo] - core_cell, ring_solo),
			"gate_cells": [gate_cells[solo]],
		})
	return result


static func _angle_sorted_indices(gate_cells: Array[Vector2i], core_cell: Vector2i) -> Array[int]:
	# 屏幕坐标（y 向下）自 +x 轴顺时针角序；象限分段 + 同象限整数叉积，平局 (y,x)。
	var indices: Array[int] = []
	for i in range(gate_cells.size()):
		indices.append(i)
	for i in range(1, indices.size()):                      # 插入排序，5 元素足矣
		var j: int = i
		while j > 0 and _angle_less(gate_cells[indices[j]] - core_cell, gate_cells[indices[j - 1]] - core_cell):
			var tmp: int = indices[j]; indices[j] = indices[j - 1]; indices[j - 1] = tmp
			j -= 1
	return indices


static func _quadrant(v: Vector2i) -> int:
	if v.x > 0 and v.y >= 0:
		return 0
	if v.x <= 0 and v.y > 0:
		return 1
	if v.x < 0 and v.y <= 0:
		return 2
	return 3


static func _angle_less(a: Vector2i, b: Vector2i) -> bool:
	var qa := _quadrant(a)
	var qb := _quadrant(b)
	if qa != qb:
		return qa < qb
	var cross: int = a.x * b.y - a.y * b.x
	if cross != 0:
		return cross > 0
	return a.y < b.y or (a.y == b.y and a.x < b.x)
```

（相邻配对的 bisector = 两门方向向量和，门均在边缘故模长相近，整数和即近似角平分；相邻门不对径，bisector ≠ 0。）

- [ ] **Step 4: 跑套件 → PASSED；`--check-only` skeleton.gd。**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/generation/skeleton.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): sector wedges, pass anchors and confluences"
```

---

### Task B2-3: 车道与保护集（噪声代价 A* / aperture 窗 / protected 类别）

**Files:**
- Create: `scripts/map/generation/lanes.gd`
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。** 追加 preload `const LaneGen = preload("res://scripts/map/generation/lanes.gd")`、助手与 `_test_lanes_protected()`：

```gdscript
func _make_plain_cells() -> Dictionary:
	var cells: Dictionary = MapGeneratorScript._create_plain_cells(30, 30)
	MapGeneratorScript._setup_core_and_initial_fog(cells, Vector2i(15, 15))
	return cells


func _path_is_connected(path: Array[Vector2i]) -> bool:
	for i in range(1, path.size()):
		if absi(path[i].x - path[i - 1].x) + absi(path[i].y - path[i - 1].y) != 1:
			return false
	return true


func _test_lanes_protected() -> void:
	var cfg := _v2_cfg()
	var core := Vector2i(15, 15)
	var gates := _fixture_gate_cells()
	var cells := _make_plain_cells()
	# 车道：连通、贴图内、决定性；带检版比值上限硬、下限统计（下限硬保障在 B2-7 spur）。
	var in_band: int = 0
	var cases: int = 0
	for seed_value in range(10):
		for i in range(gates.size()):
			var noise_seed: int = IntNoise.derive_seed(seed_value, 0, 13) + i
			var empty_waypoints: Array[Vector2i] = []
			var path: Array[Vector2i] = LaneGen.trace_lane_checked(cells, gates[i], empty_waypoints, core, 0.5, noise_seed)
			cases += 1
			_expect(not path.is_empty() and path[0] == gates[i] and path[path.size() - 1] == core, "lane endpoints (seed %d gate %d)" % [seed_value, i])
			_expect(_path_is_connected(path), "lane 4-connected (seed %d gate %d)" % [seed_value, i])
			var all_walkable := true
			for raw_cell: Variant in path:
				var data: CellData = (cells.get(raw_cell) as CellData)
				if data == null or not data.walkable:
					all_walkable = false
			_expect(all_walkable, "lane cells walkable-eligible (seed %d gate %d)" % [seed_value, i])
			var ratio: float = LaneGen.lane_ratio(path, gates[i], core)
			_expect(ratio <= 1.6 + 0.0001, "lane ratio %.3f <= 1.6 (seed %d gate %d)" % [ratio, seed_value, i])
			if ratio >= 1.15:
				in_band += 1
	print("  lane ratio in-band: %d/%d" % [in_band, cases])
	_expect(in_band * 2 >= cases, "lane jitter reroll lands >=50%% cases above floor")
	var empty_wp: Array[Vector2i] = []
	var path_a: Array[Vector2i] = LaneGen.trace_lane(cells, gates[0], empty_wp, core, 0.5, 777)
	var path_b: Array[Vector2i] = LaneGen.trace_lane(cells, gates[0], empty_wp, core, 0.5, 777)
	_expect(str(path_a) == str(path_b), "trace_lane deterministic")
	# 途径点：汇流点在路径上。
	var conf_wp: Array[Vector2i] = [Vector2i(18, 9)]
	var via: Array[Vector2i] = LaneGen.trace_lane(cells, gates[0], conf_wp, core, 0.35, 778)
	_expect(via.has(Vector2i(18, 9)), "waypoint on lane path")
	# aperture 窗：尺寸 = pass_width × depth、含锚格。
	var window: Array[Vector2i] = LaneGen.aperture_window(Vector2i(15, 8), gates[0], core, 2, 2)
	_expect(window.size() == 4, "aperture window 2x2 cells")
	_expect(window.has(Vector2i(15, 8)), "aperture window contains anchor")
	# protected：车道/核心/围裙/aperture/口袋全员入集 + 类别正确 + 决定性。
	var lanes: Dictionary = {}
	var anchors: Dictionary = {}
	for i in range(gates.size()):
		var key := "S%d" % (i + 1)
		var anchor: Vector2i = SkeletonGen.place_pass_anchor(gates[i], core, cfg["sector_cards"]["bastion"], _new_rng(40 + i))
		var aperture: Array[Vector2i] = LaneGen.aperture_window(anchor, gates[i], core, 2, 2)
		anchors[key] = {"cell": anchor, "pass_width": 2, "aperture": aperture}
		var wp: Array[Vector2i] = [anchor]
		lanes[key] = LaneGen.trace_lane_checked(cells, gates[i], wp, core, 0.35, 900 + i)
	var protected: Dictionary = LaneGen.build_protected(lanes, core, gates, anchors, cfg)
	for raw_key: Variant in lanes.keys():
		for raw_cell: Variant in lanes[raw_key]:
			_expect(protected.has(raw_cell), "lane cell protected (%s)" % str(raw_cell))
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			_expect(protected.has(core + Vector2i(dx, dy)), "core cheb<=3 protected")
	_expect(StringName(protected.get(core, &"")) == &"core", "core category wins")
	for i in range(gates.size()):
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var apron_cell: Vector2i = gates[i] + Vector2i(dx, dy)
				if apron_cell.x >= 0 and apron_cell.x < 30 and apron_cell.y >= 0 and apron_cell.y < 30:
					_expect(protected.has(apron_cell), "gate apron protected (gate %d)" % i)
	for raw_key: Variant in anchors.keys():
		var entry: Dictionary = anchors[raw_key]
		for raw_cell: Variant in entry["aperture"]:
			_expect(protected.has(raw_cell), "aperture cell protected (%s)" % String(raw_key))
		var pocket_count: int = 0
		for raw_cell: Variant in protected.keys():
			if StringName(protected[raw_cell]) == &"pocket" and _cheb(raw_cell, entry["cell"]) <= 4:
				pocket_count += 1
		_expect(pocket_count >= 4, "pocket core present near anchor (%s, got %d)" % [String(raw_key), pocket_count])
	var protected_b: Dictionary = LaneGen.build_protected(lanes, core, gates, anchors, cfg)
	_expect(str(protected) == str(protected_b), "build_protected deterministic")
```

- [ ] **Step 2: 跑套件确认失败**（lanes.gd 不存在 → preload 报错即红）。

- [ ] **Step 3: 实现 `scripts/map/generation/lanes.gd`**（设计稿 S3）：

```gdscript
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
```

核心代价公式（全整数定点，决定性）：

```gdscript
## 进入格 c 的代价：16 + (噪声八位 × 抖动十六分位) >> 8 ∈ [16, 16+jitter_q)。
## noise_q = int(value_noise(x, y, noise_seed, 3) * 256.0)——value_noise 输出为
## blended/65536，×256 取整 == blended >> 8，浮点往返无损（除/乘均为 2 的幂）。
static func _step_cost(cell: Vector2i, noise_seed: int, jitter_q: int) -> int:
	var noise_q: int = int(IntNoise.value_noise(cell.x, cell.y, noise_seed, 3) * 256.0)
	return COST_UNIT + ((noise_q * jitter_q) >> 8)
```

`trace_lane`：分段 A*（gate→wp1→…→core）拼接去重；段内 A* 完整实现：

```gdscript
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
			segment.remove_at(0)        # 拼接处去重
		path.append_array(segment)
	return path


static func _astar_segment(cells: Dictionary, from_cell: Vector2i, to_cell: Vector2i, noise_seed: int, jitter_q: int) -> Array[Vector2i]:
	# open 表线性扫描取最小 (f, y, x)（同 _soft_cost_path 风格，900 格量级无虞）；
	# h = 16 × 曼哈顿（最小步代价 16 ⇒ 可采纳）；越界由 cells.has 判定；
	# 不可走格（此阶段尚无，防御性）跳过。决定性：无 RNG、全序裁决。
	...
	return reconstructed  # 含两端点
```

`trace_lane_checked`（自检重抽 ≤3：过直升幅、过弯降幅，幅度与子种子均确定性派生）：

```gdscript
static func lane_ratio(path: Array[Vector2i], gate: Vector2i, core: Vector2i) -> float:
	var manhattan: int = maxi(absi(gate.x - core.x) + absi(gate.y - core.y), 1)
	return float(path.size() - 1) / float(manhattan)


static func trace_lane_checked(cells: Dictionary, gate: Vector2i, waypoints: Array[Vector2i], core: Vector2i, jitter_amp: float, noise_seed: int) -> Array[Vector2i]:
	var amp: float = jitter_amp
	var best: Array[Vector2i] = []
	for try_index in range(RECHECK_LIMIT):
		var path := trace_lane(cells, gate, waypoints, core, amp, IntNoise.squirrel3(try_index, noise_seed))
		best = path
		var ratio := lane_ratio(path, gate, core)
		if ratio >= RATIO_FLOOR and ratio <= RATIO_CAP:
			return path
		amp = clampf(amp * (1.5 if ratio < RATIO_FLOOR else 0.6), 0.0, 1.0)
	return best   # 出带交 S6 修复（B2-7 绕路上下限兜底）
```

`aperture_window` 与 `build_protected`（注册顺序 core→apron→aperture→pocket→lane，先注册先得）：

```gdscript
static func aperture_window(anchor: Vector2i, gate: Vector2i, core: Vector2i, pass_width: int, depth: int) -> Array[Vector2i]:
	# 纵深沿门→核心主轴方向（dir_d），宽度沿其垂直轴（dir_w），锚格居中：
	# off ∈ [-(w/2), w - w/2)，di ∈ [0, depth)，cell = anchor + dir_d*di + dir_w*off，越界裁剪。
	var axis := core - gate
	var dir_d := Vector2i(signi(axis.x), 0) if absi(axis.x) >= absi(axis.y) else Vector2i(0, signi(axis.y))
	var dir_w := Vector2i(0, 1) if dir_d.x != 0 else Vector2i(1, 0)
	var window: Array[Vector2i] = []
	for di in range(depth):
		for wi in range(pass_width):
			var off: int = wi - pass_width / 2
			window.append(anchor + dir_d * di + dir_w * off)
	return window


static func build_protected(lanes: Dictionary, core: Vector2i, gates: Array[Vector2i], anchors: Dictionary, cfg: Dictionary) -> Dictionary:
	var protected: Dictionary = {}
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			_mark(protected, core + Vector2i(dx, dy), &"core")
	for gate in gates:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				_mark(protected, gate + Vector2i(dx, dy), &"apron")
	var pass_cfg: Dictionary = cfg.get("pass", {})
	var anchor_keys: Array = anchors.keys()
	anchor_keys.sort()
	for raw_key: Variant in anchor_keys:
		var entry: Dictionary = anchors[raw_key]
		for raw_cell: Variant in entry.get("aperture", []):
			_mark(protected, raw_cell, &"aperture")
		# 口袋最小核：aperture 内侧（核心向）pocket_core_w × pocket_core_h。
		...  # 同 aperture_window 的轴系，di ∈ [depth, depth + pocket_core_h)
	var lane_keys: Array = lanes.keys()
	lane_keys.sort()
	for raw_key: Variant in lane_keys:
		for raw_cell: Variant in lanes[raw_key]:
			_mark(protected, raw_cell, &"lane")
	return protected


static func _mark(protected: Dictionary, cell: Vector2i, category: StringName) -> void:
	if not protected.has(cell):
		protected[cell] = category
```

（`_mark` 不做越界判定，调用方对图内格调用；build_protected 内对窗/口袋格做 0..width/height 裁剪——width/height 取 cfg，缺省 30。）

- [ ] **Step 4: 跑套件 → PASSED；`--check-only` lanes.gd。**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/generation/lanes.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): noisy-cost lanes and protected set"
```

---

### Task B2-4: 山脉长肉（台账 / 边界折线 ridge / 峡谷双脊）

**Files:**
- Create: `scripts/map/generation/flesh.gd`
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。** 追加 preload `const FleshGen = preload("res://scripts/map/generation/flesh.gd")`、骨架夹具（**B2-5/6/7/8/9 复用，仅此处定义**）与 `_test_ridge_growth()`：

```gdscript
## 跑真实模块组装 skeleton 上下文（编排器-lite，B2-10 的可执行规格）。
## cards: gate_key→card_id 直接指定（绕过发牌，便于按牌构造场景）。
func _build_skeleton_fixture(seed_value: int, cards: Dictionary) -> Dictionary:
	var cfg := _v2_cfg()
	var cells := _make_plain_cells()
	var core := Vector2i(15, 15)
	var gate_cells := _fixture_gate_cells()
	var spawn_cells: Array[Vector2i] = []
	var gate_map: Dictionary = {}
	var gate_keys: Array = []
	for i in range(gate_cells.size()):
		var key := "S%d" % (i + 1)
		var data: CellData = cells[gate_cells[i]]
		data.spawn_key = StringName(key)
		data.buildable = false
		spawn_cells.append(gate_cells[i])
		gate_map[key] = gate_cells[i]
		gate_keys.append(key)
	var sector_of: Dictionary = SkeletonGen.assign_sectors(30, 30, gate_cells)
	var anchors: Dictionary = {}
	var lanes: Dictionary = {}
	var geom_rng := _new_rng(IntNoise.derive_seed(seed_value, 0, 12))
	var lane_seed: int = IntNoise.derive_seed(seed_value, 0, 13)
	for i in range(gate_cells.size()):
		var key := "S%d" % (i + 1)
		var card_cfg: Dictionary = cfg["sector_cards"][String(cards.get(key, "bastion"))]
		var anchor: Vector2i = SkeletonGen.place_pass_anchor(gate_map[key], core, card_cfg, geom_rng)
		var aperture: Array[Vector2i] = LaneGen.aperture_window(anchor, gate_map[key], core, int(card_cfg.get("pass_width", 2)), int(cfg["pass"]["aperture_depth"]))
		anchors[key] = {"cell": anchor, "pass_width": int(card_cfg.get("pass_width", 2)), "aperture": aperture}
		var waypoints: Array[Vector2i] = [anchor]
		lanes[key] = LaneGen.trace_lane_checked(cells, gate_map[key], waypoints, core, float(card_cfg.get("jitter_amp", 0.35)), IntNoise.squirrel3(i, lane_seed))
	var protected: Dictionary = LaneGen.build_protected(lanes, core, gate_cells, anchors, cfg)
	return {
		"cells": cells,
		"protected": protected,
		"skeleton": {
			"width": 30, "height": 30, "core": core,
			"gate_keys": gate_keys, "gate_cells": gate_map, "spawn_cells": spawn_cells,
			"cards": cards, "card_cfgs": cfg["sector_cards"],
			"archetype": {"id": "fixture", "ratio_band": [0.20, 0.26]},
			"wind": Vector2i(1, 0), "sector_of": sector_of,
			"anchors": anchors, "confluences": [], "lanes": lanes, "fords": {},
			"conservative": false, "cfg": cfg,
		},
	}


func _count_terrain(cells: Dictionary, terrain: StringName) -> int:
	var count: int = 0
	for raw_cell: Variant in cells.keys():
		if (cells[raw_cell] as CellData).terrain == terrain:
			count += 1
	return count


func _test_ridge_growth() -> void:
	var carded := {"S1": "bastion", "S2": "canyon", "S3": "steppe", "S4": "riverlands", "S5": "bastion"}
	var fx := _build_skeleton_fixture(2024, carded)
	var cells: Dictionary = fx["cells"]
	var skeleton: Dictionary = fx["skeleton"]
	var protected: Dictionary = fx["protected"]
	var ledger: Dictionary = FleshGen.make_ledger(skeleton["cfg"], skeleton["archetype"], carded, 30, 30)
	_expect(int(ledger.get("target", 0)) >= 180 and int(ledger.get("target", 0)) <= 230, "ledger target ~= band mid x cells (got %d)" % int(ledger.get("target", 0)))
	_expect((ledger.get("sector_quota", {}) as Dictionary).size() == 5, "per-sector quota present")
	FleshGen.grow_ridges(cells, skeleton, protected, _new_rng(IntNoise.derive_seed(2024, 0, 14)), ledger)
	var mountains: int = _count_terrain(cells, CellDataRef.TERRAIN_MOUNTAIN)
	_expect(mountains >= 20, "carded borders grew ridges (mountains=%d)" % mountains)
	# protected/aperture 不被触碰。
	for raw_cell: Variant in protected.keys():
		var data: CellData = cells[raw_cell]
		_expect(data.terrain != CellDataRef.TERRAIN_MOUNTAIN, "protected cell %s untouched" % str(raw_cell))
	# 连通不变式（_try_apply 保证）。
	_expect(MapGeneratorScript._are_all_spawns_connected(cells, 30, 30, skeleton["spawn_cells"], skeleton["core"]), "all gates connected after ridges")
	# 台账：applied 与实际山数一致、requested ≥ applied。
	_expect(int(ledger.get("applied", -1)) == mountains, "ledger applied == painted mountains")
	_expect(int(ledger.get("requested", 0)) >= int(ledger.get("applied", 0)), "ledger requested >= applied")
	# 峡谷双脊：canyon 扇区车道走廊段两侧均有山。
	var canyon_lane: Array[Vector2i] = skeleton["lanes"]["S2"]
	var canyon_gate: Vector2i = skeleton["gate_cells"]["S2"]
	var axis: Vector2i = skeleton["core"] - canyon_gate
	var left: int = 0
	var right: int = 0
	for raw_cell: Variant in cells.keys():
		var cell: Vector2i = raw_cell
		if String(skeleton["sector_of"].get(cell, "")) != "S2":
			continue
		if (cells[cell] as CellData).terrain != CellDataRef.TERRAIN_MOUNTAIN:
			continue
		var rel: Vector2i = cell - canyon_gate
		var cross: int = axis.x * rel.y - axis.y * rel.x
		if cross > 0:
			left += 1
		elif cross < 0:
			right += 1
	_expect(left >= 3 and right >= 3, "canyon double ridge flanks lane (L=%d R=%d)" % [left, right])
	# 全开阔/河谷 → 零边界山。
	var soft := {"S1": "steppe", "S2": "steppe", "S3": "steppe", "S4": "riverlands", "S5": "riverlands"}
	var fx2 := _build_skeleton_fixture(2025, soft)
	var ledger2: Dictionary = FleshGen.make_ledger(fx2["skeleton"]["cfg"], fx2["skeleton"]["archetype"], soft, 30, 30)
	FleshGen.grow_ridges(fx2["cells"], fx2["skeleton"], fx2["protected"], _new_rng(1), ledger2)
	_expect(_count_terrain(fx2["cells"], CellDataRef.TERRAIN_MOUNTAIN) == 0, "no carded sector -> no border ridges")
	# 决定性。
	var fx3 := _build_skeleton_fixture(2024, carded)
	var ledger3: Dictionary = FleshGen.make_ledger(fx3["skeleton"]["cfg"], fx3["skeleton"]["archetype"], carded, 30, 30)
	FleshGen.grow_ridges(fx3["cells"], fx3["skeleton"], fx3["protected"], _new_rng(IntNoise.derive_seed(2024, 0, 14)), ledger3)
	_expect(_serialize_obstacles_only({"cells": fx3["cells"]}) == _serialize_obstacles_only({"cells": cells}), "grow_ridges deterministic")
```

- [ ] **Step 2: 跑套件确认失败**（flesh.gd 缺失即红）。

- [ ] **Step 3: 实现 `scripts/map/generation/flesh.gd`**（B2-4 范围：台账 + grow_ridges；河湖 B2-5 续写）。

文件头与台账（完整代码）：

```gdscript
class_name MapGenFlesh
extends RefCounted

## 骨架长肉（设计稿 S4/§2.1-2.3）：预算台账、边界折线山脊、峡谷双脊、
## 伪高程、河流渡口、湖泊与湿度。纯静态、决定性。
## 回引 map_generator 静态助手用运行时 load（见计划「模块回引规则」）。

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")
const SkeletonGen = preload("res://scripts/map/generation/skeleton.gd")


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
```

`grow_ridges` 算法（精确散文 + 不变式；伪码见设计稿 §2.1 三步）：

1. **选边界**：按 `_angle_sorted_indices`（preload SkeletonGen）取角序相邻门对 `(i,j)`；当 `cards[i]` 或 `cards[j]` == `"bastion"` 时该边界实体化（去重：每对至多一次）。**canyon 不长边界**，改走第 4 步双脊（§4.2 牌面语义，见自审）。
2. **中点位移折线**：bisector `b = d_i + d_j`；控制点 `P1 = ray_point(core, b, 7)`、`P2 = ray_point(core, b, 11)`，各加垂直位移 `rng.randi_range(-3, 3)`（垂直轴 = b 主轴的正交轴）；折线顶点序列 `[ray_point(core, b, 5), P1', P2', edge_pt]`，`edge_pt` 沿 b 射线走到首个越界前格。
3. **walker 长肉**：逐段 Bresenham 步进（整数 DDA，主轴步进 + round_div 副轴）；对每个折线格 c：
   - 豁口：`noise_q(c) < 26`（≈10%）跳过（`noise_q = int(IntNoise.value_noise(x, y, ridge_seed, 4) * 256.0)`，ridge_seed 由 rng 在函数开头一次性 `rng.randi()` 派生，之后不再混用——保证 rng 消费序与格序无关）；
   - 宽度：`w = 1 + ((noise_q2(c) * 3) >> 8)` ∈ 1..3（noise_q2 用 ridge_seed+1）；纺锤剖面：折线位置 t（顶点序数比例）<0.2 或 >0.8 时 w 钳到 1（§2.1 两端收窄）；
   - 落格：c 加垂直偏移序列（w=1:[0]；w=2:[0,+1]；w=3:[0,+1,-1]），逐格过滤：图内、`not protected.has(cell)`、目标扇区 `sector_applied < quota × 1.5`；
   - 批量应用：每段折线一批，`_mg()._try_apply_obstacle_cells(cells, batch, CellData.TERRAIN_MOUNTAIN, w, h, spawn_cells, core, cfg)`（连通回滚保留）；`ledger_note(ledger, "ridges", batch.size(), applied, batch.size() - applied)`，并把 applied 计入各格所在扇区的 `sector_applied`；
   - 全局停机：`ledger.applied >= ledger.target` 时立即返回。
4. **峡谷双脊**：对每个 canyon 扇区：`corridor_len = rng.randi_range(card.corridor_len[0], card.corridor_len[1])`；取该扇区车道路径上 ring ∈ `[anchor_ring - corridor_len/2, anchor_ring + corridor_len/2]` 的子段；对子段每格 c 取切向 `t = path[k+1] - path[k-1]` 的符号向量，左右法向 `(±t.y, ∓t.x)` 各偏移 2 落山（保中间宽 3 走廊 = 车道 ±1），`noise_q` 同上做豁口与偶发加宽（偏移 3，概率 ~25%）；两侧各一批 `_try_apply` + 台账。

不变式：protected 永不触碰；任何批次应用后 5 口连通（`_try_apply` 保证，失败整批回滚入台账 rolled_back）；同输入（cells/skeleton/rng 种子）逐位同输出。

- [ ] **Step 4: 跑套件 → PASSED；`--check-only` flesh.gd。**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/generation/flesh.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): ridge growth along carded borders with budget ledger"
```

---

### Task B2-5: 河湖湿度（伪高程 / 渡口预规划 / blob 湖 / 风向修正）

**Files:**
- Modify: `scripts/map/generation/flesh.gd`
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。** 追加 `_test_rivers_lakes()`：

```gdscript
func _is_edge_cell(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == 29 or cell.y == 29


func _test_rivers_lakes() -> void:
	# 伪高程：山旁高于旷野、决定性。
	var carded := {"S1": "bastion", "S2": "canyon", "S3": "steppe", "S4": "riverlands", "S5": "bastion"}
	var fx := _build_skeleton_fixture(2024, carded)
	var ledger: Dictionary = FleshGen.make_ledger(fx["skeleton"]["cfg"], fx["skeleton"]["archetype"], carded, 30, 30)
	FleshGen.grow_ridges(fx["cells"], fx["skeleton"], fx["protected"], _new_rng(IntNoise.derive_seed(2024, 0, 14)), ledger)
	var elev: Dictionary = FleshGen.build_elevation(fx["cells"], 30, 30, 555)
	_expect(elev.size() == 900, "elevation covers all cells")
	var near_ridge: Vector2i = Vector2i(-1, -1)
	for raw_cell: Variant in fx["cells"].keys():
		var cell: Vector2i = raw_cell
		if (fx["cells"][cell] as CellData).terrain == CellDataRef.TERRAIN_MOUNTAIN:
			for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
				var nb: Vector2i = cell + direction
				if fx["cells"].has(nb) and (fx["cells"][nb] as CellData).terrain == CellDataRef.TERRAIN_PLAIN:
					near_ridge = nb
					break
		if near_ridge.x >= 0:
			break
	if near_ridge.x >= 0:
		var far_cell := Vector2i(15, 25) if _cheb(near_ridge, Vector2i(15, 25)) > 8 else Vector2i(8, 22)
		_expect(int(elev[near_ridge]) > int(elev[far_cell]), "elevation higher near ridges")
	var elev_b: Dictionary = FleshGen.build_elevation(fx["cells"], 30, 30, 555)
	_expect(str(elev) == str(elev_b), "build_elevation deterministic")
	# 河流 + 渡口：跨种子统计渡口出现率，出现时恰 1 个 2 格窗且新最短路穿窗。
	var ford_hits: int = 0
	var river_runs: int = 0
	for seed_value in range(3000, 3010):
		var rfx := _build_skeleton_fixture(seed_value, carded)
		var rledger: Dictionary = FleshGen.make_ledger(rfx["skeleton"]["cfg"], rfx["skeleton"]["archetype"], carded, 30, 30)
		FleshGen.grow_ridges(rfx["cells"], rfx["skeleton"], rfx["protected"], _new_rng(IntNoise.derive_seed(seed_value, 0, 14)), rledger)
		var relev: Dictionary = FleshGen.build_elevation(rfx["cells"], 30, 30, IntNoise.derive_seed(seed_value, 0, 15))
		var river: Dictionary = FleshGen.trace_river(rfx["cells"], rfx["skeleton"], "S4", relev, rfx["protected"], _new_rng(IntNoise.derive_seed(seed_value, 0, 15)), rledger)
		river_runs += 1
		var river_cells: Array = river.get("river_cells", [])
		var pond_cells: Array = river.get("pond_cells", [])
		_expect(river_cells.size() + pond_cells.size() >= 3, "seed %d: river or pond materialized" % seed_value)
		var reached_edge := false
		for raw_cell: Variant in river_cells:
			if _is_edge_cell(raw_cell):
				reached_edge = true
		_expect(reached_edge or pond_cells.size() >= 3, "seed %d: river reaches edge or ends in pond" % seed_value)
		_expect(MapGeneratorScript._are_all_spawns_connected(rfx["cells"], 30, 30, rfx["skeleton"]["spawn_cells"], rfx["skeleton"]["core"]), "seed %d: gates connected after river" % seed_value)
		var ford_cells: Array = river.get("ford_cells", [])
		if not ford_cells.is_empty():
			ford_hits += 1
			_expect(ford_cells.size() == 2, "seed %d: ford window is 2 cells" % seed_value)
			for raw_cell: Variant in ford_cells:
				_expect((rfx["cells"][raw_cell] as CellData).walkable, "seed %d: ford stays walkable" % seed_value)
			# 渡口唯一：S4 新最短路与水格零相交（只能走渡口）。
			var dist_gate: Dictionary = MapGeneratorScript._bfs_distances(rfx["cells"], 30, 30, rfx["skeleton"]["gate_cells"]["S4"])
			_expect(int(dist_gate.get(rfx["skeleton"]["core"], -1)) > 0, "seed %d: S4 still reaches core" % seed_value)
	print("  ford hits: %d/%d" % [ford_hits, river_runs])
	_expect(ford_hits >= 5, "fords occur in majority of riverlands runs")
	# 湖：steppe 扇区落湖、贴图、远离车道、不淹 protected。
	var lfx := _build_skeleton_fixture(2026, carded)
	var lledger: Dictionary = FleshGen.make_ledger(lfx["skeleton"]["cfg"], lfx["skeleton"]["archetype"], carded, 30, 30)
	FleshGen.place_lakes(lfx["cells"], lfx["skeleton"], "S3", 1, lfx["protected"], _new_rng(606), lledger)
	var water: int = _count_terrain(lfx["cells"], CellDataRef.TERRAIN_WATER)
	_expect(water >= 6, "steppe lake materialized (water=%d)" % water)
	for raw_cell: Variant in lfx["protected"].keys():
		_expect((lfx["cells"][raw_cell] as CellData).terrain != CellDataRef.TERRAIN_WATER, "lake spares protected")
	_expect(MapGeneratorScript._are_all_spawns_connected(lfx["cells"], 30, 30, lfx["skeleton"]["spawn_cells"], lfx["skeleton"]["core"]), "gates connected after lake")
	# 湿度：迎风侧計划 ≥ 背风侧（30 个种子聚合）。
	var wet_total: int = 0
	var dry_total: int = 0
	for seed_value in range(30):
		var plans: Dictionary = FleshGen.roll_water_plans(fx["skeleton"], Vector2i(1, 0), _new_rng(seed_value), fx["skeleton"]["cfg"])
		for raw_key: Variant in plans.keys():
			var gate: Vector2i = fx["skeleton"]["gate_cells"][raw_key]
			var dot: int = (gate - fx["skeleton"]["core"]).x
			var weight: int = int(plans[raw_key].get("lakes", 0)) + (1 if bool(plans[raw_key].get("river", false)) else 0)
			if dot > 0:
				wet_total += weight
			elif dot < 0:
				dry_total += weight
	_expect(wet_total > dry_total, "windward side plans more water (wet=%d dry=%d)" % [wet_total, dry_total])
	var plans_a: Dictionary = FleshGen.roll_water_plans(fx["skeleton"], Vector2i(1, 0), _new_rng(9), fx["skeleton"]["cfg"])
	var plans_b: Dictionary = FleshGen.roll_water_plans(fx["skeleton"], Vector2i(1, 0), _new_rng(9), fx["skeleton"]["cfg"])
	_expect(str(plans_a) == str(plans_b), "roll_water_plans deterministic")
```

- [ ] **Step 2: 跑套件确认失败**（build_elevation 等缺失即红）。

- [ ] **Step 3: 实现（flesh.gd 续写）。**

`build_elevation`（完整代码）：

```gdscript
static func build_elevation(cells: Dictionary, width: int, height: int, seed_value: int) -> Dictionary:
	# elev = max(0, 12 − dist_to_最近山体) × 1024 + noise_q（设计稿 §2.2 取反距离 + 整数值噪声）。
	# 多源 BFS 自全部山格起（含不可走格的几何距离）；无山 → 距离恒 12（纯噪声场）。
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
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var nb: Vector2i = current + direction
			if not cells.has(nb) or dist.has(nb):
				continue
			dist[nb] = int(dist[current]) + 1
			queue.append(nb)
	var elevation: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var d: int = mini(int(dist.get(cell, 12)), 12)
			var noise_q: int = int(IntNoise.value_noise(x, y, seed_value, 4) * 256.0)
			elevation[cell] = (12 - d) * 1024 + noise_q
	return elevation
```

`roll_water_plans`（完整代码——**每口固定消费 3 次 rng**，分支不改变流位置）：

```gdscript
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
```

`trace_river` 算法（精确散文 + 不变式；§2.2）：

1. **起点**：本扇区（sector_of==gate_key）中 ring(core) ∈ [9,13]、非 protected、可走格里 elev 最大者，平局 (y,x) 小者。无候选 → 返回空结果（台账记 0）。
2. **梯度下降**：每步取 4 邻中 elev 最低且未访问者；邻格 elev ≥ 当前 → 卡坑：就地成湖——以当前格为中心按 (elev, y, x) 升序收 `rng.randi_range(3, 5)` 个相邻格为 pond；到达地图边缘 → 终止。步数硬上限 200（防御）。
3. **渡口预规划**（落水前）：`dist_gate = _mg()._bfs_distances(...)` + parent 重建该口当前真实最短路 P（重建用「dist 递减且 (y,x) 最小邻」回溯，决定性）；crossings = 河折线 ∩ P；**chosen = 距本扇区 anchor.cell 切比雪夫最近者**（平局 (y,x)）；`ford_cells = [chosen, chosen + river_dir]`（river_dir = chosen 在折线上的下一格方向；chosen 为折线末格时取上一格方向反向）。crossings 空 → 无渡口（aperture 仍由锚窗承担）。
4. **落水**：paint = (折线 ∪ pond) − ford_cells − {protected 且类别 ≠ &"lane"}；类别 &"lane" 的格**允许淹**（多交点照常落水，强制车道走渡口——§2.2 原文）；整批 `_try_apply_obstacle_cells(TERRAIN_WATER)`，回滚则 ledger 记 rolled_back 并返回空 ford。
5. 返回 `{"river_cells": 实际落水折线格, "pond_cells": 实际落水 pond 格, "ford_cells": ford 或 []}`；调用方把非空 ford 写回 `skeleton["fords"][gate_key]`。

不变式：aperture/pocket/core/apron 永不进水；应用后 5 口连通；rng 消费序 = 起点选取 0 次 + pond 尺寸至多 1 次（固定在 stuck 分支，决定性由 elev 场与折线序保证）。

`place_lakes`（精确散文）：候选中心 = 本扇区格、距本扇区车道每格 cheb ≥ 4、ring ≥ 8、非 protected、可走，按 (y,x) 序收集；`center = candidates[rng.randi_range(0, size-1)]`；`size = rng.randi_range(15, 30)`；`cluster = _mg()._build_lake_cluster(cells, w, h, spawn_cells, core, cfg, rng, center, size)`（复用现 walker）；**剔除 protected 格后**整批 `_try_apply_obstacle_cells(TERRAIN_WATER)`；台账 "lakes"。lake_count 次循环；候选空 → 跳过并台账记 0。

- [ ] **Step 4: 跑套件 → PASSED；`--check-only` flesh.gd。**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/generation/flesh.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): elevation rivers fords and lakes with moisture"
```

---

### Task B2-6: 侵蚀与清渣（边缘啃噬 / CA 多数 / 孤岛与死口袋）

**Files:**
- Create: `scripts/map/generation/natural.gd`
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。** 追加 preload `const NaturalGen = preload("res://scripts/map/generation/natural.gd")`、组件助手与 `_test_erosion_cleanup()`：

```gdscript
func _blocked_component_sizes(cells: Dictionary) -> Array[int]:
	var seen: Dictionary = {}
	var sizes: Array[int] = []
	for raw_cell: Variant in cells.keys():
		var cell: Vector2i = raw_cell
		if seen.has(cell) or (cells[cell] as CellData).walkable:
			continue
		var queue: Array[Vector2i] = [cell]
		seen[cell] = true
		var head: int = 0
		var size: int = 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			size += 1
			for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
				var nb: Vector2i = current + direction
				if not cells.has(nb) or seen.has(nb) or (cells[nb] as CellData).walkable:
					continue
				seen[nb] = true
				queue.append(nb)
		sizes.append(size)
	return sizes


func _test_erosion_cleanup() -> void:
	# 合成场景：长直墙 + 单格渣 ×3 + 2 格岛 + 3 格封闭死口袋。
	var fx := _build_skeleton_fixture(2027, {"S1": "bastion", "S2": "bastion", "S3": "steppe", "S4": "riverlands", "S5": "canyon"})
	var cells: Dictionary = fx["cells"]
	var skeleton: Dictionary = fx["skeleton"]
	var protected: Dictionary = fx["protected"]
	var paint_wall: Array[Vector2i] = []
	for x in range(4, 14):
		paint_wall.append(Vector2i(x, 22))
	for raw_cell: Variant in paint_wall + [Vector2i(3, 4), Vector2i(26, 3), Vector2i(22, 24)]:
		var cell: Vector2i = raw_cell
		if not protected.has(cell):
			(cells[cell] as CellData).set_base_terrain(CellDataRef.TERRAIN_MOUNTAIN)
	# 2 格岛。
	for raw_cell: Variant in [Vector2i(25, 20), Vector2i(26, 20)]:
		if not protected.has(raw_cell):
			(cells[raw_cell] as CellData).set_base_terrain(CellDataRef.TERRAIN_MOUNTAIN)
	# 死口袋：(5,26)(6,26)(5,27) 由山圈死（圈格避 protected）。
	var pocket: Array[Vector2i] = [Vector2i(5, 26), Vector2i(6, 26), Vector2i(5, 27)]
	var fence: Array[Vector2i] = [Vector2i(4, 25), Vector2i(5, 25), Vector2i(6, 25), Vector2i(7, 25), Vector2i(4, 26), Vector2i(7, 26), Vector2i(4, 27), Vector2i(6, 27), Vector2i(7, 27), Vector2i(4, 28), Vector2i(5, 28), Vector2i(6, 28)]
	var fenced := true
	for raw_cell: Variant in fence:
		if protected.has(raw_cell):
			fenced = false
		else:
			(cells[raw_cell] as CellData).set_base_terrain(CellDataRef.TERRAIN_MOUNTAIN)
	var before := _serialize_obstacles_only({"cells": cells})
	var ledger: Dictionary = FleshGen.make_ledger(skeleton["cfg"], skeleton["archetype"], skeleton["cards"], 30, 30)
	NaturalGen.erode_edges(cells, skeleton, protected, 4242, ledger)
	# 侵蚀触动了边界但比例有度（10%-50% 边界格变动）。
	_expect(before != _serialize_obstacles_only({"cells": cells}), "erosion changed something")
	for raw_cell: Variant in protected.keys():
		var data: CellData = cells[raw_cell]
		_expect(data.terrain == CellDataRef.TERRAIN_PLAIN or StringName(protected[raw_cell]) != &"aperture", "erosion never touches aperture")
	NaturalGen.cellular_cleanup(cells, skeleton, protected, ledger)
	var sizes := _blocked_component_sizes(cells)
	for size in sizes:
		_expect(size >= 3, "no blocked component < 3 (got %d)" % size)
	# 死口袋被填或被打开：口袋格要么不可走（填）要么可达核心。
	if fenced:
		var dist_core: Dictionary = MapGeneratorScript._bfs_distances(cells, 30, 30, skeleton["core"])
		for raw_cell: Variant in pocket:
			var data: CellData = cells[raw_cell]
			_expect((not data.walkable) or dist_core.has(raw_cell), "dead pocket %s resolved" % str(raw_cell))
	_expect(MapGeneratorScript._are_all_spawns_connected(cells, 30, 30, skeleton["spawn_cells"], skeleton["core"]), "gates connected after cleanup")
	# 决定性：同输入重跑全等。
	var fx2 := _build_skeleton_fixture(2027, {"S1": "bastion", "S2": "bastion", "S3": "steppe", "S4": "riverlands", "S5": "canyon"})
	for raw_cell: Variant in paint_wall + [Vector2i(3, 4), Vector2i(26, 3), Vector2i(22, 24), Vector2i(25, 20), Vector2i(26, 20)]:
		if not fx2["protected"].has(raw_cell):
			(fx2["cells"][raw_cell] as CellData).set_base_terrain(CellDataRef.TERRAIN_MOUNTAIN)
	for raw_cell: Variant in fence:
		if not fx2["protected"].has(raw_cell):
			(fx2["cells"][raw_cell] as CellData).set_base_terrain(CellDataRef.TERRAIN_MOUNTAIN)
	var ledger2: Dictionary = FleshGen.make_ledger(fx2["skeleton"]["cfg"], fx2["skeleton"]["archetype"], fx2["skeleton"]["cards"], 30, 30)
	NaturalGen.erode_edges(fx2["cells"], fx2["skeleton"], fx2["protected"], 4242, ledger2)
	NaturalGen.cellular_cleanup(fx2["cells"], fx2["skeleton"], fx2["protected"], ledger2)
	_expect(_serialize_obstacles_only({"cells": fx2["cells"]}) == _serialize_obstacles_only({"cells": cells}), "erosion+cleanup deterministic")
```

- [ ] **Step 2: 跑套件确认失败**（natural.gd 缺失即红）。

- [ ] **Step 3: 实现 `scripts/map/generation/natural.gd`**（设计稿 S5；纯整数哈希场决策，无 RNG 流）：

```gdscript
class_name MapGenNatural
extends RefCounted

## 自然化修饰（设计稿 S5）：边缘侵蚀（哈希场 ~30% 啃噬 / ~15% 外溢）与
## CA 清渣（4 邻多数 1 轮 + 删 <3 格阻挡孤岛 + 填 <4 格不可达死口袋）。
## 决定性：决策全部来自 IntNoise.cell_hash 纯场 + (y,x) 扫描序，无 RNG。

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")


static func _mg() -> GDScript:
	return load("res://scripts/map/map_generator.gd")
```

`erode_edges` 精确散文：
- **快照两阶段**：先按 (y,x) 序在快照上收集决策，再统一应用（避免链式反应不决定）。
- 啃噬（blocked→plain，永远连通安全，直接应用）：阻挡格且 ≥1 个 4 邻可走，`IntNoise.cell_hash(x, y, seed_value) % 100 < 30` → 还原 plain。protected 内不存在阻挡格（构造保证），仍防御性跳过。
- 外溢（plain→blocked，需回滚保护）：可走格、非 protected、无资源/口/核心，≥1 个 4 邻阻挡（快照），`IntNoise.cell_hash(x, y, IntNoise.squirrel3(1, seed_value)) % 100 < 15` → 候补；地形取快照 4 邻阻挡多数（山/水平票取山）。山候补、 水候补各一批 `_mg()._try_apply_obstacle_cells`（整批回滚可接受——侵蚀是风味不是约束）。
- 台账 `"erode"`：requested = 啃噬+候补总数，applied = 实际改格，rolled_back = 批量回滚数。

`cellular_cleanup` 精确散文（顺序固定）：
1. **多数轮 ×1**：快照上每个非 protected、无资源/口/核心格数 4 邻阻挡数 n（越界邻居不计）：自身可走且 n ≥ 3 → 候补转阻挡（多数地形）；自身阻挡且 n ≤ 1 → 直接还原 plain。转阻挡候补一批 `_try_apply`。
2. **孤岛删除**：阻挡 4 连通组件 size < 3 → 全员 plain（直接应用，安全）。
3. **死口袋填充**：可走 4 连通组件，不含 core、不含任何 spawn 格，size < 4 → 全员转山（不可达区域填充不影响门→核连通，直接应用；防御性再跑一次 `_are_all_spawns_connected`，失败即还原本组件并 push_warning——理论不可达）。
4. **再扫孤岛**：步 3 可能制造新邻接，重复步 2 一次。
- 台账 `"cleanup"`。

不变式：protected 格 terrain 永不改写；结束后无 <3 阻挡组件、无 <4 不可达可走组件；5 口连通保持。

- [ ] **Step 4: 跑套件 → PASSED；`--check-only` natural.gd。**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/generation/natural.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): edge erosion and cellular cleanup"
```

---

### Task B2-7: 走廊派生与修复全量（corridor / 绕路下限 spur / 隘口分级 / 口袋 / 占比回调 / 入侵度）

**Files:**
- Create: `scripts/map/generation/gen_repair.gd`
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。** 追加 preload `const GenRepairMod = preload("res://scripts/map/generation/gen_repair.gd")`、长肉夹具（**B2-8/9 复用，仅此处定义**）与 `_test_corridor_repair()`：

```gdscript
## 骨架夹具 + 长肉全流程（山/河/湖/侵蚀/清渣），返回含 elevation 与 ledger。
func _build_fleshed_fixture(seed_value: int, cards: Dictionary) -> Dictionary:
	var fx := _build_skeleton_fixture(seed_value, cards)
	var cells: Dictionary = fx["cells"]
	var skeleton: Dictionary = fx["skeleton"]
	var protected: Dictionary = fx["protected"]
	var ledger: Dictionary = FleshGen.make_ledger(skeleton["cfg"], skeleton["archetype"], cards, 30, 30)
	FleshGen.grow_ridges(cells, skeleton, protected, _new_rng(IntNoise.derive_seed(seed_value, 0, 14)), ledger)
	var elevation: Dictionary = FleshGen.build_elevation(cells, 30, 30, IntNoise.derive_seed(seed_value, 0, 15))
	var water_rng := _new_rng(IntNoise.derive_seed(seed_value, 0, 15))
	var plans: Dictionary = FleshGen.roll_water_plans(skeleton, skeleton["wind"], water_rng, skeleton["cfg"])
	var keys: Array = (skeleton["gate_keys"] as Array).duplicate()
	keys.sort()
	for raw_key: Variant in keys:
		var key := String(raw_key)
		var plan: Dictionary = plans[key]
		if bool(plan.get("river", false)):
			var river: Dictionary = FleshGen.trace_river(cells, skeleton, key, elevation, protected, water_rng, ledger)
			if not (river.get("ford_cells", []) as Array).is_empty():
				skeleton["fords"][key] = river["ford_cells"]
		if int(plan.get("lakes", 0)) > 0:
			FleshGen.place_lakes(cells, skeleton, key, int(plan["lakes"]), protected, water_rng, ledger)
	NaturalGen.erode_edges(cells, skeleton, protected, IntNoise.derive_seed(seed_value, 0, 16), ledger)
	NaturalGen.cellular_cleanup(cells, skeleton, protected, ledger)
	fx["elevation"] = FleshGen.build_elevation(cells, 30, 30, IntNoise.derive_seed(seed_value, 0, 15))
	fx["ledger"] = ledger
	return fx


func _pocket_plain_count(cells: Dictionary, aperture: Array, core: Vector2i, flood_limit: int) -> int:
	# 自 aperture 内侧（核心向）flood ≤ flood_limit 数 plain 可建格。
	var dist_core: Dictionary = MapGeneratorScript._bfs_distances(cells, 30, 30, core)
	var seeds: Array[Vector2i] = []
	for raw_cell: Variant in aperture:
		var cell: Vector2i = raw_cell
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var nb: Vector2i = cell + direction
			if cells.has(nb) and dist_core.has(nb) and (cells[nb] as CellData).walkable:
				if int(dist_core.get(nb, 1 << 30)) < int(dist_core.get(cell, 1 << 30)):
					seeds.append(nb)
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	for seed_cell in seeds:
		dist[seed_cell] = 0
		queue.append(seed_cell)
	var head: int = 0
	var plain: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var data: CellData = cells[current]
		if data.walkable and data.buildable and data.terrain == CellDataRef.TERRAIN_PLAIN and data.resource_type == StringName():
			plain += 1
		if int(dist[current]) >= flood_limit:
			continue
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var nb: Vector2i = current + direction
			if not cells.has(nb) or dist.has(nb) or not (cells[nb] as CellData).walkable:
				continue
			dist[nb] = int(dist[current]) + 1
			queue.append(nb)
	return plain


func _test_corridor_repair() -> void:
	# corridor 定义：双 BFS 和 ≤ 最短 + slack。
	var cells := _make_plain_cells()
	var corridor: Dictionary = GenRepairMod.derive_corridor(cells, Vector2i(15, 0), Vector2i(15, 15), 3)
	_expect(int(corridor.get("shortest", -1)) == 15, "plain board shortest = manhattan")
	var corridor_cells: Dictionary = corridor.get("cells", {})
	_expect(corridor_cells.has(Vector2i(15, 7)), "corridor holds shortest path cells")
	_expect(corridor_cells.has(Vector2i(16, 7)), "corridor holds slack cells")
	_expect(not corridor_cells.has(Vector2i(25, 7)), "corridor excludes far cells")
	# 全量修复（标准夹具）：连通 + 绕路带 + 分级一致 + 口袋 + 占比 + 入侵度。
	var cards := {"S1": "bastion", "S2": "canyon", "S3": "steppe", "S4": "riverlands", "S5": "bastion"}
	for seed_value in [6001, 6002, 6003]:
		var fx := _build_fleshed_fixture(seed_value, cards)
		var verdict: Dictionary = GenRepairMod.full_repair(fx["cells"], fx["skeleton"], fx["protected"], fx["elevation"], fx["ledger"])
		_expect(bool(verdict.get("ok", false)), "seed %d: full_repair ok (%s)" % [seed_value, String(verdict.get("fail_reason", ""))])
		if not bool(verdict.get("ok", false)):
			continue
		var skeleton: Dictionary = fx["skeleton"]
		var blocked: int = 0
		for raw_cell: Variant in fx["cells"].keys():
			if not (fx["cells"][raw_cell] as CellData).walkable:
				blocked += 1
		var ratio: float = float(blocked) / 900.0
		var band: Array = skeleton["archetype"]["ratio_band"]
		_expect(ratio >= float(band[0]) - 0.02 and ratio <= float(band[1]) + 0.02, "seed %d: blocked ratio %.3f in band %s" % [seed_value, ratio, str(band)])
		for raw_key: Variant in skeleton["gate_keys"]:
			var key := String(raw_key)
			var gate: Vector2i = skeleton["gate_cells"][key]
			var path_len: int = _bfs_path_length(fx["cells"], 30, 30, gate, skeleton["core"])
			_expect(path_len > 0, "seed %d %s: connected" % [seed_value, key])
			var detour: float = float(path_len) / float(maxi(_manhattan(gate, skeleton["core"]), 1))
			_expect(detour <= 1.6 + 0.0001, "seed %d %s: detour %.3f <= cap" % [seed_value, key, detour])
			_expect(detour >= 1.15 - 0.0001, "seed %d %s: detour %.3f >= floor" % [seed_value, key, detour])
			var grade: StringName = verdict["pass_grades"].get(key, &"")
			if String(skeleton["cards"][key]) == "steppe":
				_expect(grade == &"open", "seed %d %s: steppe graded open" % [seed_value, key])
				continue
			var aperture: Array = skeleton["fords"].get(key, skeleton["anchors"][key]["aperture"])
			_expect(_pocket_plain_count(fx["cells"], aperture, skeleton["core"], 12) >= 6, "seed %d %s: pocket >= 6 plain" % [seed_value, key])
			if grade == &"single":
				var on_path := _shortest_path_cells(fx["cells"], gate, skeleton["core"])
				var crosses := false
				for raw_cell: Variant in aperture:
					if on_path.has(raw_cell):
						crosses = true
				_expect(crosses, "seed %d %s: single grade -> path crosses aperture" % [seed_value, key])
			else:
				_expect(grade == &"dual", "seed %d %s: grade single/dual only (got %s)" % [seed_value, key, grade])
		var intrusion: int = int(verdict.get("intrusion", 1 << 30))
		_expect(intrusion <= int(ceil(float(blocked) * 0.15)), "seed %d: intrusion %d <= 15%% of %d" % [seed_value, intrusion, blocked])
	# 绕路下限：空旷直线图 → spur 抬高到 ≥ floor 或如实失败重试信号。
	var open_cards := {"S1": "steppe", "S2": "steppe", "S3": "steppe", "S4": "steppe", "S5": "steppe"}
	var sfx := _build_skeleton_fixture(6010, open_cards)
	var sledger: Dictionary = FleshGen.make_ledger(sfx["skeleton"]["cfg"], sfx["skeleton"]["archetype"], open_cards, 30, 30)
	var selev: Dictionary = FleshGen.build_elevation(sfx["cells"], 30, 30, 1)
	var sverdict: Dictionary = GenRepairMod.full_repair(sfx["cells"], sfx["skeleton"], sfx["protected"], selev, sledger)
	if bool(sverdict.get("ok", false)):
		for raw_key: Variant in sfx["skeleton"]["gate_keys"]:
			var gate: Vector2i = sfx["skeleton"]["gate_cells"][raw_key]
			var path_len: int = _bfs_path_length(sfx["cells"], 30, 30, gate, sfx["skeleton"]["core"])
			var detour: float = float(path_len) / float(maxi(_manhattan(gate, sfx["skeleton"]["core"]), 1))
			_expect(detour >= 1.15 - 0.0001, "spur lifts open map above floor (%s %.3f)" % [String(raw_key), detour])
	else:
		_expect(String(sverdict.get("fail_reason", "")) != "", "floor failure reports reason")
	# 决定性：同夹具重跑修复全等。
	var dfx_a := _build_fleshed_fixture(6001, cards)
	var dfx_b := _build_fleshed_fixture(6001, cards)
	var verdict_a: Dictionary = GenRepairMod.full_repair(dfx_a["cells"], dfx_a["skeleton"], dfx_a["protected"], dfx_a["elevation"], dfx_a["ledger"])
	var verdict_b: Dictionary = GenRepairMod.full_repair(dfx_b["cells"], dfx_b["skeleton"], dfx_b["protected"], dfx_b["elevation"], dfx_b["ledger"])
	_expect(_serialize_obstacles_only({"cells": dfx_a["cells"]}) == _serialize_obstacles_only({"cells": dfx_b["cells"]}), "full_repair deterministic (cells)")
	_expect(str(verdict_a.get("pass_grades", {})) == str(verdict_b.get("pass_grades", {})), "full_repair deterministic (grades)")


func _shortest_path_cells(cells: Dictionary, gate: Vector2i, core: Vector2i) -> Dictionary:
	# 真实最短路重建：dist 递减回溯，平局 (y,x) 小者——与实现同规约。
	var dist: Dictionary = MapGeneratorScript._bfs_distances(cells, 30, 30, gate)
	if not dist.has(core):
		return {}
	var path: Dictionary = {core: true}
	var current: Vector2i = core
	while current != gate:
		var best := Vector2i(-1, -1)
		var best_dist: int = int(dist[current])
		for direction in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
			var nb: Vector2i = current + direction
			if not dist.has(nb) or int(dist[nb]) >= best_dist:
				continue
			if best.x < 0 or nb.y < best.y or (nb.y == best.y and nb.x < best.x):
				best = nb
		if best.x < 0:
			return path
		path[best] = true
		current = best
	return path
```

- [ ] **Step 2: 跑套件确认失败**（gen_repair.gd 缺失即红）。

- [ ] **Step 3: 实现 `scripts/map/generation/gen_repair.gd`**（设计稿 S6 / §3 表）。

文件头 + corridor（完整代码）：

```gdscript
class_name MapGenRepair
extends RefCounted

## corridor 派生与约束修复（设计稿 S6①-⑥/§3）：验收对象 = 真实 BFS 最短路与
## corridor 走廊集（非作者车道，SF-1 手术）。修复改格全部记入侵度台账。

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")

const GRADE_SINGLE := &"single"
const GRADE_DUAL := &"dual"
const GRADE_OPEN := &"open"


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


static func _bfs(cells: Dictionary, origin: Vector2i) -> Dictionary:
	# 与 map_generator._bfs_distances 同语义，但以 cells.has 判界（模块自洽）。
	...
```

`full_repair` 六步序（精确散文 + 关键规则；每步 ≤ cfg.max_repair_rounds 轮；**入侵度 = 修复改写格计数**，含 ① 开凿、③ spur、④ 封堵、⑤ 清障、⑥ 回调，写入 `ledger.repair_intrusion` 并返回）：

① **连通**（构造已保证，兜底）：每口（key 升序）不可达 → `_mg()._soft_cost_path(...)` 取路，路上阻挡格还原 plain（口/核/资源格防御性跳过——与 `_repair_gate_detours` 同条件）；改格计入侵度。

② **绕路上限**（复用）：快照阻挡集 → `_mg()._repair_gate_detours(cells, w, h, spawn_cells, core, cfg)` → 对比快照把翻面格数计入侵度。

③ **绕路下限**：每口 ratio < `cfg.detour_floor` → spur：真实最短路 P（BFS+回溯，规约同测试 `_shortest_path_cells`）取中点 mid；垂直轴 perp = P 在 mid 处切向的正交；**先试高程均值较高的一侧**（贴山读作支脉，§3「山脉天然支脉」）：spur 格 = `mid + perp * k`，k ∈ [-2, L-3]，L = 6 + (elev_q(mid) % 5) ∈ [6,10]（elev 场派生，无 RNG）；过滤 protected/口/核/资源/aperture 格；批量 `_try_apply_obstacle_cells(TERRAIN_MOUNTAIN)`；复测 ratio ∈ [floor, cap] 且全口 cap 仍满足 → 收下；否则整批还原 plain 换另一侧；两侧皆败 → 下一轮（轮尽仍 < floor → `ok=false, fail_reason="detour_floor"`）。

④ **隘口分级**（steppe 直接 `GRADE_OPEN` 跳过）：每口（key 升序）：
   - 验收窗 A = `skeleton.fords[key]`（有渡口）否则 `skeleton.anchors[key].aperture`；
   - 旁路检测：corridor(key) 中 ring(core) ∈ [ring_A − 1, ring_A + 1]（ring_A = A 首格环数）且不在 A 的 cheb≤1 膨胀内的格，8 连通聚类 = 旁路窗；
   - 逐旁路窗（按窗内最小 (y,x) 排序）封堵：窗格按 **elev 降序**（沿最近山体合龙，§3）批量 `_try_apply(TERRAIN_MOUNTAIN)` → 全口 cap 复测：破 cap → 整批还原 + 本口判 `GRADE_DUAL` 并停止封堵；未破 → 入侵度累计，继续下一窗；
   - 全部封堵成功后复测真实最短路穿 A → `GRADE_SINGLE`；不穿（残余旁路/检测盲区）→ `GRADE_DUAL`；
   - **一致性自证**：single 必须「最短路 ∩ A ≠ ∅」；dual 必须旁路窗数 ≥ 1（即 ≥2 条走廊窗）；自证不过 → `ok=false, fail_reason="grade_mismatch"`（B2-10 据此重试）。
⑤ **口袋 flood**：每非 steppe 口以验收窗 A 内侧种子 flood ≤ `pass.pocket_flood_limit`，数 plain 可建格（规约同测试 `_pocket_plain_count`）；< `pass.pocket_min_plain` → 取 flood 区相邻阻挡格按 **elev 升序**逐格还原 plain（凿出山坳，§3）、重 flood，至达标或本轮 12 格上限；轮尽不达 → `ok=false, fail_reason="pocket"`。

⑥ **占比回调**：blocked/(w×h) 对 `skeleton.archetype.ratio_band`：
   - 欠收：候选 = 可走、非 protected、距全部 corridor 格 cheb ≥ 3、所在扇区牌 ≠ steppe、无口/核/资源；按 **elev 降序 + (y,x)** 每批 6 格 `_try_apply(TERRAIN_MOUNTAIN)` 至入带或候选尽；
   - 超收：边界阻挡格（≥1 可走 4 邻）按 **elev 升序 + (y,x)** 逐格还原至入带（啃边永远安全）；
   - 改格计入侵度。轮尽不入带（±0.02 容差）→ `ok=false, fail_reason="ratio"`。

收尾：`corridors = derive_all_corridors(cells, skeleton, cfg.corridor_slack)`；入侵度上限自检 `intrusion <= ceil(blocked × repair.intrusion_max_per_map)` 否则 `ok=false, fail_reason="intrusion"`；返回契约 dict。

- [ ] **Step 4: 跑套件 → PASSED（修复链路 + 入侵度打印肉眼复核）；`--check-only` gen_repair.gd。**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/generation/gen_repair.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): corridor derivation and full repair pass"
```

---

### Task B2-8: mesa 平台放置（形状目录 / 战位锚定评分 / 逐座反漂移）

**Files:**
- Create: `scripts/map/generation/mesa.gd`
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。** 追加 preload `const MesaGen = preload("res://scripts/map/generation/mesa.gd")`、形状归一助手与 `_test_mesa_placement()`：

```gdscript
func _normalize_shape(shape_cells: Array) -> String:
	var min_x: int = 1 << 30
	var min_y: int = 1 << 30
	for raw: Variant in shape_cells:
		var cell: Vector2i = raw
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	var offsets: Array = []
	for raw: Variant in shape_cells:
		var cell: Vector2i = raw
		offsets.append(Vector2i(cell.x - min_x, cell.y - min_y))
	offsets.sort()
	return str(offsets)


func _min_cheb_to_set(cell: Vector2i, target: Dictionary) -> int:
	var best: int = 1 << 30
	for raw: Variant in target.keys():
		best = mini(best, _cheb(cell, raw))
	return best


func _test_mesa_placement() -> void:
	var cards := {"S1": "bastion", "S2": "canyon", "S3": "steppe", "S4": "riverlands", "S5": "bastion"}
	var legal_shapes: Dictionary = {}
	for raw_size: Variant in MesaGen.SHAPES.keys():
		for raw_shape: Variant in MesaGen.SHAPES[raw_size]:
			legal_shapes[_normalize_shape(raw_shape)] = true
	_expect(not legal_shapes.has(_normalize_shape([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])), "no standalone 2x2 in catalog")
	for seed_value in [7001, 7002]:
		var fx := _build_fleshed_fixture(seed_value, cards)
		var verdict: Dictionary = GenRepairMod.full_repair(fx["cells"], fx["skeleton"], fx["protected"], fx["elevation"], fx["ledger"])
		if not bool(verdict.get("ok", false)):
			continue
		var outcome: Dictionary = MesaGen.place_mesas(fx["cells"], fx["skeleton"], fx["protected"], verdict["corridors"], _new_rng(IntNoise.derive_seed(seed_value, 0, 18)), fx["ledger"])
		_expect(bool(outcome.get("ok", false)), "seed %d: mesas placed" % seed_value)
		if not bool(outcome.get("ok", false)):
			continue
		var mesas: Array = outcome.get("mesas", [])
		var total_cells: int = 0
		var starter_seen := false
		var corridor_union: Dictionary = {}
		for raw_key: Variant in outcome["corridors"].keys():
			for raw_cell: Variant in (outcome["corridors"][raw_key]["cells"] as Dictionary).keys():
				corridor_union[raw_cell] = true
		for raw_mesa: Variant in mesas:
			var mesa: Dictionary = raw_mesa
			var mesa_cells: Array = mesa.get("cells", [])
			total_cells += mesa_cells.size()
			_expect(legal_shapes.has(_normalize_shape(mesa_cells)), "seed %d: mesa shape legal %s" % [seed_value, _normalize_shape(mesa_cells)])
			var covered: int = 0
			for raw_cell: Variant in mesa_cells:
				var data: CellData = fx["cells"][raw_cell]
				_expect(data.terrain == CellDataRef.TERRAIN_HIGHLAND and not data.walkable and not data.buildable, "seed %d: mesa cell is blocking highland" % seed_value)
				if _min_cheb_to_set(raw_cell, corridor_union) <= 2:
					covered += 1
			_expect(covered * 10 >= mesa_cells.size() * 6, "seed %d: mesa coverage >=60%% (%d/%d)" % [seed_value, covered, mesa_cells.size()])
			if StringName(mesa.get("kind", &"")) == &"starter":
				starter_seen = true
				_expect(mesa_cells.size() >= 3 and mesa_cells.size() <= 4, "seed %d: starter 3-4 cells" % seed_value)
				for raw_cell: Variant in mesa_cells:
					var ring: int = _cheb(raw_cell, fx["skeleton"]["core"])
					_expect(ring >= 4 and ring <= 5, "seed %d: starter ring %d in [4,5]" % [seed_value, ring])
		_expect(starter_seen, "seed %d: starter mesa present" % seed_value)
		_expect(mesas.size() >= 4 and mesas.size() <= 6, "seed %d: mesa count %d in [4,6]" % [seed_value, mesas.size()])
		_expect(total_cells >= 14 and total_cells <= 24, "seed %d: mesa cells %d in [14,24]" % [seed_value, total_cells])
		# 战位锚定：每张配额牌扇区有一座贴本扇区验收窗。
		for raw_key: Variant in fx["skeleton"]["gate_keys"]:
			var key := String(raw_key)
			if int((fx["skeleton"]["card_cfgs"][fx["skeleton"]["cards"][key]] as Dictionary).get("mesa_quota", 0)) <= 0:
				continue
			var aperture: Array = fx["skeleton"]["fords"].get(key, fx["skeleton"]["anchors"][key]["aperture"])
			var aperture_set: Dictionary = {}
			for raw_cell: Variant in aperture:
				aperture_set[raw_cell] = true
			var hugged := false
			for raw_mesa: Variant in mesas:
				if String((raw_mesa as Dictionary).get("gate_key", "")) != key:
					continue
				for raw_cell: Variant in (raw_mesa as Dictionary).get("cells", []):
					if _min_cheb_to_set(raw_cell, aperture_set) <= 2:
						hugged = true
			_expect(hugged, "seed %d: quota mesa hugs %s aperture/ford" % [seed_value, key])
		# 反漂移闭环：放置后全口绕路 cap 仍守、连通仍在。
		for raw_key: Variant in fx["skeleton"]["gate_keys"]:
			var gate: Vector2i = fx["skeleton"]["gate_cells"][raw_key]
			var path_len: int = _bfs_path_length(fx["cells"], 30, 30, gate, fx["skeleton"]["core"])
			_expect(path_len > 0, "seed %d: %s connected after mesas" % [seed_value, String(raw_key)])
			var detour: float = float(path_len) / float(maxi(_manhattan(gate, fx["skeleton"]["core"]), 1))
			_expect(detour <= 1.6 + 0.0001, "seed %d: %s cap holds after mesas (%.3f)" % [seed_value, String(raw_key), detour])
	# 决定性。
	var fx_a := _build_fleshed_fixture(7001, cards)
	var fx_b := _build_fleshed_fixture(7001, cards)
	var verdict_a2: Dictionary = GenRepairMod.full_repair(fx_a["cells"], fx_a["skeleton"], fx_a["protected"], fx_a["elevation"], fx_a["ledger"])
	var verdict_b2: Dictionary = GenRepairMod.full_repair(fx_b["cells"], fx_b["skeleton"], fx_b["protected"], fx_b["elevation"], fx_b["ledger"])
	if bool(verdict_a2.get("ok", false)) and bool(verdict_b2.get("ok", false)):
		var out_a: Dictionary = MesaGen.place_mesas(fx_a["cells"], fx_a["skeleton"], fx_a["protected"], verdict_a2["corridors"], _new_rng(42), fx_a["ledger"])
		var out_b: Dictionary = MesaGen.place_mesas(fx_b["cells"], fx_b["skeleton"], fx_b["protected"], verdict_b2["corridors"], _new_rng(42), fx_b["ledger"])
		_expect(str(out_a.get("mesas", [])) == str(out_b.get("mesas", [])) and _serialize_obstacles_only({"cells": fx_a["cells"]}) == _serialize_obstacles_only({"cells": fx_b["cells"]}), "place_mesas deterministic")
```

- [ ] **Step 2: 跑套件确认失败**（mesa.gd 缺失即红）。

- [ ] **Step 3: 实现 `scripts/map/generation/mesa.gd`**（§2.4 修订版）。

形状目录（**完整常量，照写**；无独立 2×2，5 格走 L5/T5）：

```gdscript
class_name MapGenMesa
extends RefCounted

## 天然高台放置（设计稿 §2.4 修订版）：平台阵地、战位锚定、评分制、
## 逐座落地→重派生 corridor→复检→回滚 反漂移闭环。

const GenRepairMod = preload("res://scripts/map/generation/gen_repair.gd")

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
```

评分（§2.4 评分函数原文）与放置序（精确散文）：

- `score(cells组) = 3 × (组内距 corridor 并集 cheb≤2 的格数) + 6 × [任一格距本扇区验收窗(ford 优先) cheb≤2] + 3 × [任一格距任一汇流点 cheb≤2]`；候选全序 `(score 降, origin.y, origin.x, shape 序数)`。
- 候选合法性：全格图内、plain 可走、非 protected（任意类别）、无资源/口/核心。
- **放置序**：① starter（全格 ring(core) ∈ [starter.ring_min, ring_max]、尺寸 starter.size_min..max、距 corridor ≤ starter.max_corridor_dist）→ ② 配额座（每张 `mesa_quota > 0` 的牌，按 gate_key 升序；候选限本扇区且任一格距验收窗 cheb ≤2；尺寸 = `size_weights` 加权掷）→ ③ 填充座（全图候选；`target_count = rng.randi_range(count_min, count_max)`，conservative 时 = count_min；尺寸掷受 `cells_total + size <= cells_max` 约束）。
- **逐座反漂移协议**（每座一致）：批量 `_mg()._try_apply_obstacle_cells(cells, shape_cells, CellData.TERRAIN_HIGHLAND, ...)`（0 应用 → 下一候选）→ `corridors_next = GenRepairMod.derive_all_corridors(cells, skeleton, slack)` → 复检【全口连通（_try_apply 已证）、全口 ratio ≤ detour_cap、本座覆盖 ≥ min_covered_ratio、**既有各座对 corridors_next 覆盖 ≥ min_covered_ratio**、starter 距 corridor ≤2 仍立】→ 任一败 → 本座全格还原 plain（ledger rolled_back）→ 下一候选（每槽位候选试验上限 40）→ 全败跳过该槽位；成功 → `corridors = corridors_next`、记 mesa `{"cells", "kind"(&"starter"/&"quota"/&"filler"), "gate_key"}`、台账 "mesa"。
- **验收与降阶**：`count ∈ [count_min, count_max] 且 cells_total ∈ [cells_min, cells_max]` → `ok=true, degraded=false`；count ∈ [count_floor_degraded, count_min) 或 cells_total < cells_min → `ok=true, degraded=true`（B2-10 编排器对非末次 attempt 视 degraded 为失败重试——§2.4「降阶→仍不满足→整图重试」的工程化，见自审）；count < count_floor_degraded → `ok=false`。
- rng 消费序固定：starter 尺寸掷 → 每配额座 1 掷 → target_count 1 掷 → 每填充座 1 掷；候选挑选零随机（全序扫描）。

- [ ] **Step 4: 跑套件 → PASSED；`--check-only` mesa.gd。**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/generation/mesa.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): mesa platform placement with anti-drift loop"
```

---

### Task B2-9: 资源风味（近环保底不动 / 远区亲和加权 / risk_reward / 排除走廊）

**Files:**
- Modify: `scripts/map/map_generator.gd`
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。** 追加 `_test_resource_flavor()`：

```gdscript
func _resource_cells_by_type(cells: Dictionary) -> Dictionary:
	var by_type: Dictionary = {&"wood": [], &"stone": [], &"mana": []}
	for raw_cell: Variant in cells.keys():
		var data: CellData = cells[raw_cell]
		if data.resource_type != StringName() and by_type.has(data.resource_type):
			(by_type[data.resource_type] as Array).append(raw_cell)
	return by_type


func _near_terrain(cells: Dictionary, cell: Vector2i, terrain: StringName, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var nb: Vector2i = cell + Vector2i(dx, dy)
			if cells.has(nb) and (cells[nb] as CellData).terrain == terrain:
				return true
	return false


func _test_resource_flavor() -> void:
	var cards := {"S1": "bastion", "S2": "canyon", "S3": "steppe", "S4": "riverlands", "S5": "bastion"}
	var stone_hits: int = 0
	var stone_total: int = 0
	var wood_hits: int = 0
	var wood_total: int = 0
	var wood_base_hits: int = 0
	var wood_base_total: int = 0
	var mana_hits: int = 0
	var mana_total: int = 0
	var mana_base_hits: int = 0
	var mana_base_total: int = 0
	for seed_value in range(8001, 8013):
		var fx := _build_fleshed_fixture(seed_value, cards)
		var verdict: Dictionary = GenRepairMod.full_repair(fx["cells"], fx["skeleton"], fx["protected"], fx["elevation"], fx["ledger"])
		if not bool(verdict.get("ok", false)):
			continue
		var mesa_out: Dictionary = MesaGen.place_mesas(fx["cells"], fx["skeleton"], fx["protected"], verdict["corridors"], _new_rng(IntNoise.derive_seed(seed_value, 0, 18)), fx["ledger"])
		if not bool(mesa_out.get("ok", false)):
			continue
		var corridors: Dictionary = mesa_out["corridors"]
		# 基线率：远区候选里满足谓词的占比（自归一化对照）。
		for raw_cell: Variant in fx["cells"].keys():
			var data: CellData = fx["cells"][raw_cell]
			if not data.walkable or data.resource_type != StringName():
				continue
			wood_base_total += 1
			mana_base_total += 1
			if _near_terrain(fx["cells"], raw_cell, CellDataRef.TERRAIN_WATER, 2):
				wood_base_hits += 1
				mana_base_hits += 1
		MapGeneratorScript._place_resources_v2(fx["cells"], 30, 30, fx["skeleton"]["spawn_cells"], fx["skeleton"]["core"], _new_rng(IntNoise.derive_seed(seed_value, 0, 3)), fx["skeleton"]["cfg"], fx["skeleton"], corridors)
		var by_type := _resource_cells_by_type(fx["cells"])
		var corridor_union: Dictionary = {}
		for raw_key: Variant in corridors.keys():
			for raw_cell: Variant in (corridors[raw_key]["cells"] as Dictionary).keys():
				corridor_union[raw_cell] = true
		for raw_type: Variant in by_type.keys():
			var placed: Array = by_type[raw_type]
			_expect(placed.size() == 12, "seed %d: %s count 12 (got %d)" % [seed_value, String(raw_type), placed.size()])
			var near_ring: int = 0
			for raw_cell: Variant in placed:
				var ring: int = _cheb(raw_cell, fx["skeleton"]["core"])
				if ring >= 3 and ring <= 5:
					near_ring += 1
				_expect((fx["cells"][raw_cell] as CellData).walkable, "seed %d: resource walkable" % seed_value)
			_expect(near_ring >= 2, "seed %d: %s near-ring guarantee (got %d)" % [seed_value, String(raw_type), near_ring])
		# 远区资源不落 corridor（近环保底豁免——与近环既有语义一致）。
		for raw_type: Variant in by_type.keys():
			for raw_cell: Variant in by_type[raw_type]:
				var ring: int = _cheb(raw_cell, fx["skeleton"]["core"])
				if ring >= 3 and ring <= 5:
					continue
				_expect(not corridor_union.has(raw_cell), "seed %d: far resource off corridor (%s)" % [seed_value, str(raw_cell)])
		# 亲和统计样本。
		for raw_cell: Variant in by_type[&"stone"]:
			stone_total += 1
			if _near_terrain(fx["cells"], raw_cell, CellDataRef.TERRAIN_MOUNTAIN, 2):
				stone_hits += 1
		for raw_cell: Variant in by_type[&"wood"]:
			wood_total += 1
			if _near_terrain(fx["cells"], raw_cell, CellDataRef.TERRAIN_WATER, 2):
				wood_hits += 1
		for raw_cell: Variant in by_type[&"mana"]:
			mana_total += 1
			if _near_terrain(fx["cells"], raw_cell, CellDataRef.TERRAIN_WATER, 2):
				mana_hits += 1
	_expect(stone_total >= 48, "flavor sample size adequate (stone_total=%d)" % stone_total)
	_expect(stone_hits * 100 >= stone_total * 55, "stone foothill lean >=55%% (%d/%d)" % [stone_hits, stone_total])
	var wood_rate: float = float(wood_hits) / float(maxi(wood_total, 1))
	var wood_base: float = float(wood_base_hits) / float(maxi(wood_base_total, 1))
	_expect(wood_rate >= wood_base + 0.10, "wood moist lean beats base by 10pp (%.2f vs %.2f)" % [wood_rate, wood_base])
	var mana_rate: float = float(mana_hits) / float(maxi(mana_total, 1))
	var mana_base: float = float(mana_base_hits) / float(maxi(mana_base_total, 1))
	_expect(mana_rate >= mana_base + 0.10, "mana water lean beats base by 10pp (%.2f vs %.2f)" % [mana_rate, mana_base])
	# 决定性。
	var fx_a := _build_fleshed_fixture(8001, cards)
	var fx_b := _build_fleshed_fixture(8001, cards)
	var va: Dictionary = GenRepairMod.full_repair(fx_a["cells"], fx_a["skeleton"], fx_a["protected"], fx_a["elevation"], fx_a["ledger"])
	var vb: Dictionary = GenRepairMod.full_repair(fx_b["cells"], fx_b["skeleton"], fx_b["protected"], fx_b["elevation"], fx_b["ledger"])
	if bool(va.get("ok", false)) and bool(vb.get("ok", false)):
		var ma: Dictionary = MesaGen.place_mesas(fx_a["cells"], fx_a["skeleton"], fx_a["protected"], va["corridors"], _new_rng(1), fx_a["ledger"])
		var mb: Dictionary = MesaGen.place_mesas(fx_b["cells"], fx_b["skeleton"], fx_b["protected"], vb["corridors"], _new_rng(1), fx_b["ledger"])
		MapGeneratorScript._place_resources_v2(fx_a["cells"], 30, 30, fx_a["skeleton"]["spawn_cells"], fx_a["skeleton"]["core"], _new_rng(2), fx_a["skeleton"]["cfg"], fx_a["skeleton"], ma["corridors"])
		MapGeneratorScript._place_resources_v2(fx_b["cells"], 30, 30, fx_b["skeleton"]["spawn_cells"], fx_b["skeleton"]["core"], _new_rng(2), fx_b["skeleton"]["cfg"], fx_b["skeleton"], mb["corridors"])
		_expect(_serialize_terrain({"cells": fx_a["cells"]}) == _serialize_terrain({"cells": fx_b["cells"]}), "resources_v2 deterministic")
```

- [ ] **Step 2: 跑套件确认失败**（_place_resources_v2 缺失即红）。

- [ ] **Step 3: 实现 `map_generator.gd::_place_resources_v2`**（包装而非重写：近环保底块与 `_place_resource_type`/`_is_near_exploration_ring`/`_shuffle_cells` 原样复用；远区换加权抽取）。

结构（精确散文 + 权重公式）：

1. **候选收集**：与 `_place_resources` 同筛（图内 1..size-2、可走、无资源/口、保护判定带近环豁免）；近环候选 → `near_candidates`；远区候选额外剔除 `corridor_union` 格（任一口 corridor 含之）。
2. **近环保底（不动）**：`_shuffle_cells(near_candidates, rng)` → 对三类各 `_place_resource_type(..., near_target, ...)`——与旧实现逐行同语义（near-ring guarantee 原样）。
3. **远区加权**：对每类（固定序 wood→stone→mana）目标补到 `resources_per_type`：
   - 整数权重 `w(c, type) = 16`；
   - **风味亲和 ×3**：wood/mana → 距水 cheb ≤2；stone → 距山 cheb ≤2（§4.4 affinity 表的谓词化；倍率占位可调）；
   - **扇区倍率**：`w = w * int(round(resource_mult * 16)) / 16`（steppe 1.5 → ×24/16）；
   - **risk_reward_bias 0.5 → ×3/2**：距任一阻挡格 cheb ≤2，或 ring(core) > 本扇区锚环（隘口外侧）；
   - 加权无放回抽取：`total = Σw`，`roll = rng.randi_range(0, total - 1)`，按 (y,x) 序累计扫过 roll 落格；抽中即 `_set_resource_node` 并移除。
4. rng 消费序固定：近环洗牌 → 每类远区抽取 `target - 已放` 次。决定性由候选 (y,x) 序 + rng 流保证。

实现提示：阻挡邻近/水邻近/山邻近谓词先一遍预扫成三个 Dictionary 集（cheb ≤2 膨胀），权重查表 O(1)；锚环表 gate_key→cheb(anchor, core)。

- [ ] **Step 4: 跑套件 → PASSED（亲和统计打印复核）；`--check-only` map_generator.gd。回归 test_spawn_gates_v2 → PASSED（legacy 路径未触碰，应天然绿）。**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/map_generator.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): flavor-weighted resource placement"
```

---

### Task B2-10: 编排器 + 重试 + 兜底（generate_v2 / 分派 / gen_report / 金种子）

**Files:**
- Modify: `scripts/map/map_generator.gd`
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。** 追加 `_test_generate_v2()` 与 `_test_golden_seeds()`：

```gdscript
func _test_generate_v2() -> void:
	var cfg := _v2_cfg()
	# 分派：缺省/显式 legacy 与旧行为逐位等价；legacy 返回补空 sectors/gen_report。
	var base_cfg := {"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0}
	var legacy_cfg := {"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0, "generator": "legacy"}
	var a: Dictionary = MapGeneratorScript.generate(30, 30, 9001, base_cfg, [])
	var b: Dictionary = MapGeneratorScript.generate(30, 30, 9001, legacy_cfg, [])
	_expect(_serialize_terrain(a) == _serialize_terrain(b), "default dispatch == legacy")
	_expect(a.has("sectors") and (a["sectors"] as Dictionary).is_empty(), "legacy returns empty sectors")
	_expect(a.has("gen_report"), "legacy returns gen_report key")
	# v2：返回契约完整。
	var v2: Dictionary = MapGeneratorScript.generate(30, 30, 20260611, cfg, [])
	_expect((v2.get("spawn_cells", []) as Array).size() == 5, "v2 places 5 gates")
	var sectors: Dictionary = v2.get("sectors", {})
	_expect(sectors.size() == 5, "v2 returns 5 sector entries")
	for raw_key: Variant in sectors.keys():
		var meta: Dictionary = sectors[raw_key]
		for field in ["card", "pass_grade", "aperture", "anchor", "ford"]:
			_expect(meta.has(field), "sector %s has %s" % [String(raw_key), field])
	var report: Dictionary = v2.get("gen_report", {})
	for field in ["attempts", "archetype", "cards", "wind", "ledger", "intrusion", "blocked_ratio", "fallback", "fail_log"]:
		_expect(report.has(field), "gen_report has %s" % field)
	_expect(not bool(report.get("fallback", true)), "v2 normal seed no fallback")
	_expect(int(report.get("attempts", 0)) >= 1, "v2 records attempts")
	# 连通 + cells/core 契约（map_manager 四键零改动的依据）。
	var core_cell: Vector2i = v2.get("core_cell", Vector2i.ZERO)
	for raw_gate: Variant in v2.get("spawn_cells", []):
		_expect(_bfs_path_length(v2.get("cells", {}), 30, 30, raw_gate, core_cell) > 0, "v2 gate connected")
	# 兜底：不可能的 detour_cap → 5 attempts 后落 legacy，不崩溃。
	var doomed := _v2_cfg()
	doomed["detour_cap"] = 0.5
	doomed["detour_floor"] = 0.4
	var fb: Dictionary = MapGeneratorScript.generate(30, 30, 777, doomed, [])
	_expect(bool((fb.get("gen_report", {}) as Dictionary).get("fallback", false)), "impossible cfg falls back to legacy")
	_expect((fb.get("spawn_cells", []) as Array).size() == 5, "fallback map still has 5 gates")
	for raw_gate: Variant in fb.get("spawn_cells", []):
		_expect(_bfs_path_length(fb.get("cells", {}), 30, 30, raw_gate, fb.get("core_cell", Vector2i.ZERO)) > 0, "fallback gate connected")


func _test_golden_seeds() -> void:
	# 金种子决定性：两次 generate_v2 序列化哈希全等；seed+1 不同。
	var cfg := _v2_cfg()
	for seed_value in [20260611, 424242, 90417]:
		var a: Dictionary = MapGeneratorScript.generate_v2(30, 30, seed_value, cfg, [])
		var b: Dictionary = MapGeneratorScript.generate_v2(30, 30, seed_value, cfg, [])
		var hash_a: String = _serialize_terrain(a).md5_text()
		var hash_b: String = _serialize_terrain(b).md5_text()
		print("  golden seed %d terrain md5 %s" % [seed_value, hash_a])
		_expect(hash_a == hash_b, "golden seed %d deterministic" % seed_value)
		_expect(str(a.get("sectors", {})) == str(b.get("sectors", {})), "golden seed %d sectors deterministic" % seed_value)
	var c: Dictionary = MapGeneratorScript.generate_v2(30, 30, 20260612, cfg, [])
	var base: Dictionary = MapGeneratorScript.generate_v2(30, 30, 20260611, cfg, [])
	_expect(_serialize_terrain(c) != _serialize_terrain(base), "different seed different v2 map")
```

- [ ] **Step 2: 跑套件确认失败**（generate_v2 缺失 / legacy 无 sectors 键即红）。

- [ ] **Step 3: 实现 map_generator.gd 编排（设计稿 §1.0/1.1/S9/§5）。**

3a. 旧 `generate` 函数体整体改名 `_generate_legacy`（签名同契约表），返回 dict 增补 `"sectors": {}, "gen_report": {}`；新 `generate` 只做分派：

```gdscript
static func generate(width: int, height: int, seed: int = -1, cfg: Dictionary = {}, event_ids: Array[StringName] = []) -> Dictionary:
	if String(cfg.get("generator", "legacy")) == "skeleton_v2":
		return generate_v2(width, height, seed, cfg, event_ids)
	return _generate_legacy(width, height, seed, cfg, event_ids)
```

3b. 顶部追加模块 preload（单向，无环）与 STAGE 常量（契约表）；`_stage_rng_v2` 启用 attempt 位。

3c. `generate_v2` 重试壳（完整代码）：

```gdscript
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
```

（兜底=legacy 而非规格 §5 的曼哈顿走廊清障——legacy 全管线久经考验且更简单，偏差记自审。）

3d. `_generate_v2_attempt` 阶段接线（完整代码骨架；S1-S9 对位注释）：

```gdscript
static func _generate_v2_attempt(width: int, height: int, actual_seed: int, attempt: int, cfg: Dictionary, event_ids: Array[StringName], conservative: bool) -> Dictionary:
	var cells := _create_plain_cells(width, height)
	var core_cell := Vector2i(width / 2, height / 2)
	_setup_core_and_initial_fog(cells, core_cell)
	# S2a 等弧门（复用 B1 placement，attempt 进流）
	var spawn_cells := _place_spawns(cells, width, height, core_cell, _stage_rng_v2(actual_seed, attempt, STAGE_SPAWNS), cfg)
	if spawn_cells.size() < maxi(int(cfg.get("spawn_count", SPAWN_COUNT)), 1):
		return {"ok": false, "reason": "gate_placement"}
	var gate_keys: Array = []
	var gate_map: Dictionary = {}
	for i in range(spawn_cells.size()):
		var key := "S%d" % (i + 1)
		gate_keys.append(key)
		gate_map[key] = spawn_cells[i]
	# S1 archetype + day1 发牌约束 + 风向
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
	# S2b 扇区/锚/汇流
	var geom_rng := _stage_rng_v2(actual_seed, attempt, STAGE_GEOMETRY)
	var sector_of: Dictionary = SkeletonGen.assign_sectors(width, height, spawn_cells)
	var confluences: Array[Dictionary] = SkeletonGen.place_confluences(archetype, spawn_cells, core_cell, geom_rng)
	var anchors: Dictionary = {}
	for i in range(spawn_cells.size()):
		var key := String(gate_keys[i])
		var card_cfg: Dictionary = (cfg.get("sector_cards", {}) as Dictionary).get(String(cards.get(key, "bastion")), {})
		var anchor: Vector2i = SkeletonGen.place_pass_anchor(spawn_cells[i], core_cell, card_cfg, geom_rng)
		var aperture: Array[Vector2i] = LaneGen.aperture_window(anchor, spawn_cells[i], core_cell, int(card_cfg.get("pass_width", 2)), int((cfg.get("pass", {}) as Dictionary).get("aperture_depth", 2)))
		anchors[key] = {"cell": anchor, "pass_width": int(card_cfg.get("pass_width", 2)), "aperture": aperture}
	var skeleton := {
		"width": width, "height": height, "core": core_cell,
		"gate_keys": gate_keys, "gate_cells": gate_map, "spawn_cells": spawn_cells,
		"cards": cards, "card_cfgs": cfg.get("sector_cards", {}),
		"archetype": archetype, "wind": wind, "sector_of": sector_of,
		"anchors": anchors, "confluences": confluences, "lanes": {}, "fords": {},
		"conservative": conservative, "cfg": cfg,
	}
	# S3 车道 + protected（汇流点按 gate 归属插作途径点：外→内 = anchor → confluence）
	var lane_seed: int = IntNoise.derive_seed(actual_seed, attempt, STAGE_LANES)
	for i in range(spawn_cells.size()):
		var key := String(gate_keys[i])
		var card_cfg: Dictionary = (skeleton["card_cfgs"] as Dictionary).get(String(cards.get(key, "bastion")), {})
		var waypoints: Array[Vector2i] = [(anchors[key] as Dictionary)["cell"]]
		for raw_conf: Variant in confluences:
			if ((raw_conf as Dictionary).get("gate_cells", []) as Array).has(spawn_cells[i]):
				waypoints.append((raw_conf as Dictionary)["cell"])
		var jitter: float = 0.0 if conservative else float(card_cfg.get("jitter_amp", float(cfg.get("lane_jitter_base", 0.35))))
		(skeleton["lanes"] as Dictionary)[key] = LaneGen.trace_lane_checked(cells, spawn_cells[i], waypoints, core_cell, jitter, IntNoise.squirrel3(i, lane_seed))
		if ((skeleton["lanes"] as Dictionary)[key] as Array).is_empty():
			return {"ok": false, "reason": "lane_trace"}
	var protected: Dictionary = LaneGen.build_protected(skeleton["lanes"], core_cell, spawn_cells, anchors, cfg)
	# S4 山脊 + 台账
	var ledger: Dictionary = FleshGen.make_ledger(cfg, archetype, cards, width, height)
	FleshGen.grow_ridges(cells, skeleton, protected, _stage_rng_v2(actual_seed, attempt, STAGE_RIDGES), ledger)
	# S4.5 河湖（伪高程 → 计划 → 河/湖；ford 写回 skeleton.fords）
	var elevation: Dictionary = FleshGen.build_elevation(cells, width, height, IntNoise.derive_seed(actual_seed, attempt, STAGE_WATER))
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
	# S5 侵蚀 + 清渣
	NaturalGen.erode_edges(cells, skeleton, protected, IntNoise.derive_seed(actual_seed, attempt, STAGE_EROSION), ledger)
	NaturalGen.cellular_cleanup(cells, skeleton, protected, ledger)
	# S6 修复（高程按清渣后地形重建）
	elevation = FleshGen.build_elevation(cells, width, height, IntNoise.derive_seed(actual_seed, attempt, STAGE_WATER))
	var repair: Dictionary = GenRepair.full_repair(cells, skeleton, protected, elevation, ledger)
	if not bool(repair.get("ok", false)):
		return {"ok": false, "reason": "repair_%s" % String(repair.get("fail_reason", ""))}
	# S7 mesa（degraded 仅末次 attempt 放行）
	var mesa: Dictionary = MesaGen.place_mesas(cells, skeleton, protected, repair["corridors"], _stage_rng_v2(actual_seed, attempt, STAGE_MESA), ledger)
	if not bool(mesa.get("ok", false)):
		return {"ok": false, "reason": "mesa_supply"}
	var max_retries: int = maxi(int(cfg.get("max_retries", 5)), 1)
	if bool(mesa.get("degraded", false)) and attempt < max_retries - 1:
		return {"ok": false, "reason": "mesa_degraded"}
	# S8 资源 + 事件（复用流 id）
	_place_resources_v2(cells, width, height, spawn_cells, core_cell, _stage_rng_v2(actual_seed, attempt, STAGE_RESOURCES), cfg, skeleton, mesa["corridors"])
	var event_points := _place_event_points(cells, width, height, spawn_cells, core_cell, _stage_rng_v2(actual_seed, attempt, STAGE_EVENTS), cfg, event_ids)
	# S9 终验
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
```

3e. 配套小函数（签名 + 规则）：
- `static func _archetype_by_id(cfg: Dictionary, id: String, fallback: Dictionary) -> Dictionary`：线性找 id，缺 → fallback。
- `static func _blocked_ratio(cells: Dictionary, width: int, height: int) -> float`。
- `static func _build_sectors_meta(skeleton: Dictionary, repair: Dictionary, mesa: Dictionary) -> Dictionary`：每 gate_key → `{"card": String, "pass_grade": StringName, "anchor": Vector2i, "aperture": Array[Vector2i]（ford 非空用 ford 否则锚窗）, "ford": Array[Vector2i]}`。
- `static func _validate_v2(cells, skeleton, repair, mesa, cfg) -> Dictionary`（S9 终验，全部硬断言）：5 口齐 + 全口连通 + 每口 detour ∈ [detour_floor − ε, detour_cap + ε] + blocked_ratio ∈ ratio_band ± 0.02 + 分级一致性复核（single：最短路 ∩ 验收窗 ≠ ∅；dual：旁路窗 ≥ 1——调 GenRepair 同规约助手）+ mesa（ok 且 supply 带内或 degraded-放行）→ `{"ok": bool, "reason": String}`。

3f. **map_manager 零改动验证**：读 `scripts/map/map_manager.gd:34-48`，确认仍只取四键、新增键透传无感（不改文件，结论写实现报告）。

- [ ] **Step 4: 跑套件 → PASSED。十套件全量回归：test_map_generation / test_spawn_gates_v2 / test_highland_platform / test_night_waves_affixes / test_night_template_flow / test_wave_templates / test_contract_events / test_relic_draw / test_shop_lock_drift / test_targeted_star_up → 全 PASSED。boot `--quit-after 5` 干净（json 仍 legacy，旧路径无感）。`--check-only` map_generator.gd。**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/map_generator.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): skeleton_v2 orchestrator with retry and fallback"
```

---

### Task B2-11: 切换 + 种子扫描 + 文档同步

**Files:**
- Modify: `data/map_generation.json`（generator 翻 skeleton_v2）
- Modify: `scripts/debug/test_map_generation.gd`（`_test_skeleton_sweep()`）
- Modify: `docs/DATA_SCHEMA.md`、`docs/superpowers/specs/2026-06-11-terrain-generation-design-draft.md`、`docs/肉鸽构筑与战斗优化方案.md`

- [ ] **Step 1: 失败测试。** 追加 `_test_skeleton_sweep()`（3 archetype 强制 × 40 种子；全部硬断言 + 统计打印）：

```gdscript
func _test_skeleton_sweep() -> void:
	# 生产开关已翻（本任务 Step 3）。
	var file := FileAccess.open("res://data/map_generation.json", FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	_expect(String(parsed.get("generator", "")) == "skeleton_v2", "json generator flipped to skeleton_v2")
	var base_cfg := _v2_cfg()
	var card_seen: Dictionary = {}
	var dual_count: int = 0
	var graded_count: int = 0
	var retry_maps: int = 0
	var fallback_maps: int = 0
	var worst_ms: int = 0
	for arch_index in range(3):
		var forced_cfg: Dictionary = base_cfg.duplicate(true)
		var arch: Dictionary = (base_cfg["archetypes"] as Array)[arch_index]
		forced_cfg["archetypes"] = [arch.duplicate(true)]
		var arch_id := String(arch.get("id", ""))
		var ratio_sum: float = 0.0
		var ratio_lo: float = 1.0
		var ratio_hi: float = 0.0
		for seed_value in range(41000, 41040):
			var generated: Dictionary = MapGeneratorScript.generate(30, 30, seed_value, forced_cfg, [])
			var report: Dictionary = generated.get("gen_report", {})
			_expect(not bool(report.get("fallback", false)), "%s seed %d: no fallback" % [arch_id, seed_value])
			if bool(report.get("fallback", false)):
				fallback_maps += 1
				continue
			if int(report.get("attempts", 1)) > 1:
				retry_maps += 1
			worst_ms = maxi(worst_ms, int(report.get("elapsed_ms", 0)))
			var cells: Dictionary = generated["cells"]
			var core_cell: Vector2i = generated["core_cell"]
			var spawn_cells: Array = generated.get("spawn_cells", [])
			var sectors: Dictionary = generated.get("sectors", {})
			_expect(spawn_cells.size() == 5, "%s seed %d: 5 gates" % [arch_id, seed_value])
			# 连通 + 绕路带。
			for raw_gate: Variant in spawn_cells:
				var path_len: int = _bfs_path_length(cells, 30, 30, raw_gate, core_cell)
				_expect(path_len > 0, "%s seed %d: gate connected" % [arch_id, seed_value])
				var detour: float = float(path_len) / float(maxi(_manhattan(raw_gate, core_cell), 1))
				_expect(detour >= 1.15 - 0.0001 and detour <= 1.6 + 0.0001, "%s seed %d: detour %.3f in band" % [arch_id, seed_value, detour])
			# 占比带 ±0.02。
			var ratio: float = float(report.get("blocked_ratio", 0.0))
			ratio_sum += ratio
			ratio_lo = minf(ratio_lo, ratio)
			ratio_hi = maxf(ratio_hi, ratio)
			var band: Array = arch.get("ratio_band", [0.2, 0.26])
			_expect(ratio >= float(band[0]) - 0.02 and ratio <= float(band[1]) + 0.02, "%s seed %d: ratio %.3f in band±0.02" % [arch_id, seed_value, ratio])
			# mesa 供给 + 覆盖 + 起手台。
			var highlands: Dictionary = {}
			for raw_cell: Variant in cells.keys():
				if (cells[raw_cell] as CellData).terrain == CellDataRef.TERRAIN_HIGHLAND:
					highlands[raw_cell] = true
			_expect(highlands.size() >= 14 and highlands.size() <= 24, "%s seed %d: mesa cells %d in [14,24]" % [arch_id, seed_value, highlands.size()])
			var mesa_components := _blocked_component_sizes_of(cells, CellDataRef.TERRAIN_HIGHLAND)
			_expect(mesa_components.size() >= 4 and mesa_components.size() <= 6, "%s seed %d: mesa count %d in [4,6]" % [arch_id, seed_value, mesa_components.size()])
			var starter_found := false
			for raw_cell: Variant in highlands.keys():
				var ring: int = _cheb(raw_cell, core_cell)
				if ring >= 4 and ring <= 5:
					starter_found = true
			_expect(starter_found, "%s seed %d: starter mesa ring 4-5 present" % [arch_id, seed_value])
			# 扇区元数据：发牌覆盖、口袋、分级一致、dual 统计。
			var corridor_union: Dictionary = {}
			for raw_gate: Variant in spawn_cells:
				var corridor: Dictionary = GenRepairMod.derive_corridor(cells, raw_gate, core_cell, 3)
				for raw_cell: Variant in (corridor["cells"] as Dictionary).keys():
					corridor_union[raw_cell] = true
			var covered_total: int = 0
			for raw_cell: Variant in highlands.keys():
				if _min_cheb_to_set(raw_cell, corridor_union) <= 2:
					covered_total += 1
			_expect(covered_total * 10 >= highlands.size() * 6, "%s seed %d: mesa corridor coverage >=60%%" % [arch_id, seed_value])
			for raw_key: Variant in sectors.keys():
				var meta: Dictionary = sectors[raw_key]
				card_seen[String(meta.get("card", ""))] = true
				var grade: StringName = meta.get("pass_grade", &"")
				if grade == &"open":
					continue
				graded_count += 1
				if grade == &"dual":
					dual_count += 1
				_expect(_pocket_plain_count(cells, meta.get("aperture", []), core_cell, 12) >= 6, "%s seed %d %s: pocket >=6" % [arch_id, seed_value, String(raw_key)])
				if grade == &"single":
					var on_path := _shortest_path_cells(cells, _gate_of(spawn_cells, String(raw_key)), core_cell)
					var crosses := false
					for raw_cell: Variant in meta.get("aperture", []):
						if on_path.has(raw_cell):
							crosses = true
					_expect(crosses, "%s seed %d %s: single crosses aperture" % [arch_id, seed_value, String(raw_key)])
			# 资源 12×3 + 近环。
			var by_type := _resource_cells_by_type(cells)
			for raw_type: Variant in by_type.keys():
				_expect((by_type[raw_type] as Array).size() == 12, "%s seed %d: %s 12 nodes" % [arch_id, seed_value, String(raw_type)])
				var near_count: int = 0
				for raw_cell: Variant in by_type[raw_type]:
					var ring: int = _cheb(raw_cell, core_cell)
					if ring >= 3 and ring <= 5:
						near_count += 1
				_expect(near_count >= 2, "%s seed %d: %s near-ring >=2" % [arch_id, seed_value, String(raw_type)])
			# 入侵度上限。
			var blocked: int = 0
			for raw_cell: Variant in cells.keys():
				if not (cells[raw_cell] as CellData).walkable:
					blocked += 1
			_expect(int(report.get("intrusion", 1 << 30)) <= int(ceil(float(blocked) * 0.15)), "%s seed %d: intrusion cap" % [arch_id, seed_value])
		print("== sweep %s == ratio avg %.3f range [%.3f, %.3f]" % [arch_id, ratio_sum / 40.0, ratio_lo, ratio_hi])
	for card_id in ["bastion", "steppe", "riverlands", "canyon"]:
		_expect(card_seen.has(card_id), "card %s appeared in sweep" % card_id)
	_expect(dual_count * 100 <= graded_count * 25, "dual ratio %d/%d <= 25%%" % [dual_count, graded_count])
	_expect(fallback_maps == 0, "no fallback across sweep")
	print("== sweep totals == graded=%d dual=%d retries=%d worst_ms=%d" % [graded_count, dual_count, retry_maps, worst_ms])


func _blocked_component_sizes_of(cells: Dictionary, terrain: StringName) -> Array[int]:
	var seen: Dictionary = {}
	var sizes: Array[int] = []
	for raw_cell: Variant in cells.keys():
		var cell: Vector2i = raw_cell
		if seen.has(cell) or (cells[cell] as CellData).terrain != terrain:
			continue
		var queue: Array[Vector2i] = [cell]
		seen[cell] = true
		var head: int = 0
		var size: int = 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			size += 1
			for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
				var nb: Vector2i = current + direction
				if not cells.has(nb) or seen.has(nb) or (cells[nb] as CellData).terrain != terrain:
					continue
				seen[nb] = true
				queue.append(nb)
		sizes.append(size)
	return sizes


func _gate_of(spawn_cells: Array, gate_key: String) -> Vector2i:
	var index: int = int(gate_key.substr(1)) - 1
	if index >= 0 and index < spawn_cells.size():
		return spawn_cells[index]
	return Vector2i.ZERO
```

- [ ] **Step 2: 跑套件确认失败**（json 仍 legacy → 首断言红）。

- [ ] **Step 3: 翻开关**：`data/map_generation.json` `"generator": "legacy"` → `"skeleton_v2"`（其余键不动；legacy 键全保留可随时切回）。

- [ ] **Step 4: 跑套件 → PASSED（约 120 张图 + 全部既有用例；关注 sweep 统计块）。如有断言失败：按 gen_report/统计打印定位（占比带 → 调 grow_ridges 配额或回调批量；dual 超限 → pass_ring 内移优先于放宽 cap，见设计稿 §9 风险 1），修复后必须全绿才可进 Step 5。**

- [ ] **Step 5: 全量回归 + boot**：十套件全跑（B2-10 清单）→ 全 PASSED；boot `--quit-after 5` 干净（**此时真实局已走 skeleton_v2**，留意首帧地图日志无 ERROR）。

- [ ] **Step 6: 文档同步**
  - `docs/DATA_SCHEMA.md` §10：字段表追加 v2 全部新键（generator/max_retries/detour_floor/lane_jitter_base/corridor_slack/gate_slide_jitter/repair.*/pass.*/mesa.*/economy.*/moisture_gradient_strength/sector_cards/archetypes/day1_card_constraint/bias_cards_by_activation；`spawn_safe_radius` 行注明 1→2）；「当前配置」JSON 块替换为新文件全文；补一段「generator 开关：skeleton_v2 / legacy，旧键为 legacy 兜底所用」。
  - 设计稿 `2026-06-11-terrain-generation-design-draft.md`：§3 表「全 5 口连通核心」行与 §4.4 `repair.carve_costs` 处各加一行 **2026-06-11 修订记录**：开凿语义已实现为字典序（步数主序 + 水 6/山 12 次序，B1 落地），`plain` 成本与 `saddle_weight` 不再使用；§5 末路兜底改为「回落 legacy 生成器 + push_warning」（替代曼哈顿走廊清障，理由：legacy 久经回归、语义同样构造性必成）。
  - `docs/肉鸽构筑与战斗优化方案.md` §8.1：在「地形包阶段 A」段后追加「**地形包阶段 B（已落地，2026-06-11）**」段：骨架生成器 skeleton_v2 全管线（archetype×扇区牌、车道 protected、山河湖长肉、corridor 修复与隘口分级、mesa 战位锚定、资源风味、≤5 重试 + legacy 兜底）、json schema 扩展与开关、`sectors`/`gen_report` 元数据回传（夜晚播报链就绪）、新增 `scripts/map/generation/{skeleton,lanes,flesh,natural,gen_repair,mesa}.gd`、测试套件 `_test_skeleton_sweep` 3×40 种子；遗留：`tile_highland.png` 美术、沙盒 highland 画笔、湖泽牌 v1.1。

- [ ] **Step 7: Commit**

```bash
git add data/map_generation.json scripts/debug/test_map_generation.gd docs/DATA_SCHEMA.md docs/superpowers/specs/2026-06-11-terrain-generation-design-draft.md docs/肉鸽构筑与战斗优化方案.md
git commit -m "feat(map): enable skeleton_v2 generator with seed sweep and docs"
```

---

## 自审记录

**规格覆盖（设计稿 → 任务）**
- S0 种子链/ctx → B2-10（`_stage_rng_v2` 启用 attempt 位；ctx 即 skeleton dict，§1.0 的 Dictionary 方案）；S1 → B2-1；S2 → B2-2 + 复用等弧门；S3 → B2-3；S4/§2.1-2.3 → B2-4/5；S5 → B2-6；S6/§3 → B2-7；S7/§2.4 修订版 → B2-8；S8 → B2-9 + 事件点复用；S9/§5 → B2-10；§6 A2 金种子 → B2-10、B 组+C 组浓缩 → B2-11 sweep；§7 灰度（json 开关后翻、legacy 全保留）→ B2-1/B2-11。§2.6 人工高台与 D2/D3 部署链已在地形 A 落地，不在本计划范围。
- **declared 偏差**：① 末路兜底 = 回落 legacy 生成器（非 §5 曼哈顿走廊清障）——legacy 全管线有十套件回归背书、同样构造性必成且实现量为零；`gen_report.fallback` 可观测，B2-11 sweep 断言兜底率为 0。② 开凿成本语义 = B1 已落地的字典序（步数主序+权重次序），json 不含 `carve_costs.plain`/`saddle_weight`，B2-11 把设计稿 §3/§4.4 同步至实现。③ sweep 规模 3×40（非 §6 的 3×200）——单任务时长可控，种子区间为常量，后续扩容只改一个 range。④ §2.1「险关/峡谷边界长山」与 §4.2 峡谷「双平行脊」的张力按控制器决议落地：bastion 长边界脊、canyon 只长走廊双脊。⑤ mesa 降阶（§2.4「降到 3 → 仍不满足 → 整图重试」vs §6 B9 硬带 4-6）工程化为：degraded 在非末次 attempt 视为失败重试、末次放行并入 gen_report；sweep 仍硬断 4-6/14-24（若末次降阶在扫描中出现即红，作为质量信号处理）。⑥ steppe 无显式隘口 → `pass_grade:"open"`，不计入 dual 比例分母（SF-2 分级语义只覆盖有验收窗的牌）。⑦ 资源亲和倍率取 ×3（§4.4 未定数值；wood/mana 断言用「胜过自身基线 10pp」的自归一形式，stone 用控制器定的 ≥55% 绝对值）——平衡盘未做，数值可自由调整（项目共识）。
- **接口具体化**（outline 草签名 → 终签名，已在契约表统一）：`place_confluences` 返回 `Array[Dictionary]`（需携带门归属供车道接途径点）；`make_ledger`/`erode_edges`/`cellular_cleanup` 增补 cards/skeleton/ledger 参数（台账与回引所需）；`full_repair` 的 cfg 经 skeleton.cfg 传递。

**类型一致性**
- 全部跨任务引用的函数/常量签名集中在「接口契约总表」，B2-4 起的夹具（`_build_skeleton_fixture`/`_build_fleshed_fixture`）与 B2-10 编排器按同一契约组装 skeleton dict——夹具即编排器的可执行规格，B2-10 若发现字段缺漏以契约表为准回改夹具。
- protected 为 `cell→StringName` 类别字典（非布尔集）：河流豁免 `&"lane"`、侵蚀/清渣全类别跳过、修复⑤口袋种子从 `&"aperture"` 内侧推——三处消费同一结构。
- 测试助手单点定义：`_v2_cfg`/`_new_rng`（B2-1）、`_fixture_gate_cells`/`_cheb`/`_sector_component_ratio`（B2-2）、`_make_plain_cells`/`_path_is_connected`（B2-3）、`_build_skeleton_fixture`/`_count_terrain`（B2-4）、`_is_edge_cell`（B2-5）、`_blocked_component_sizes`（B2-6）、`_build_fleshed_fixture`/`_pocket_plain_count`/`_shortest_path_cells`（B2-7）、`_normalize_shape`/`_min_cheb_to_set`（B2-8）、`_resource_cells_by_type`/`_near_terrain`（B2-9）、`_blocked_component_sizes_of`/`_gate_of`（B2-11）。

**实现期对齐点（写给执行者）**
1. **seed 同一性**：`game_controller.start_new_run` 把同一 `actual_seed` 同时给 `run_state.reset_for_new_run` 与 `generate_new_map`（`game_controller.gd:29-39` 已核对），故 generate_v2 内用收到的 seed 调 `resolve_active_gates(gate_keys, actual_seed, 1)` 与夜晚实际活跃集一致；直调 `generate(…, seed=-1, …)` 时自掷种子会与外部 RunState 脱钩——仅调试路径，可接受。
2. **B2-3 比值带为统计断言**（≥50% 案例过下限）：白板上 jitter 重抽不保证 ≥1.15，硬下限由 B2-7 spur 与 S9 终验承担；若实测白板比值普遍过低，调 `RECHECK_LIMIT` 内的放大系数而非改断言语义。
3. **B2-7 标准夹具的 `full_repair ok` 断言**：夹具种子（6001-6003）若有修复硬失败，优先换种子并在报告里记录（修复失败→重试是合法路径，测试要的是「成功样本上的性质」）；同理 B2-8/9 对 verdict.ok 用 if 短路。
4. **占比带可达性**：fixture 的 ratio_band [0.20,0.26] 与回调批量（6 格/批）配套；若 sweep 中 highland_run 的 [0.24,0.28] 难入带，先调 `grow_ridges` 的扇区配额超额系数（×1.5）再调回调批量。
5. **行数线**：flesh.gd 预计 ~330 行（台账+山脊+高程+河+湖+计划），超 400 时把 trace_river/place_lakes 拆 `scripts/map/generation/water.gd`（命名已预留，契约表签名不变，preload 调整即可——执行时在报告声明）。
6. **`_try_apply_obstacle_cells` 的 cfg 保护半径**：v2 批次已先过 protected 集，cfg 半径（core 3 / spawn 2）是更弱的子集，二者叠加无冲突；但批内格仍可能被它静默跳过（如 spawn cheb≤2 的车道旁格）——applied 计数以返回值为准记台账，勿用批长度。
7. **决定性深坑**：模块内一切「集合迭代」必须走显式排序（keys.sort() / (y,x) 扫描）；rng 消费次数不得依赖地图内容分支（roll_water_plans 的三连掷模式是范本）；浮点只允许出现在权重/比值的最终比较，不得进格序裁决。
8. **性能**：mesa 反漂移每座 ~10 次 BFS、sweep 120 图 ×（~40 BFS + 2 A*）≈ 数秒级，若超 30s 优先把 `derive_all_corridors` 的 BFS 改增量（只在 _try_apply 成功后重算受影响口）——非必需不做。
