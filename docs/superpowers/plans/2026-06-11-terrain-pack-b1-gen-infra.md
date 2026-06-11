# 地形包阶段 B1：生成器基建（整数噪声 / 分流种子 / 绕路修复）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为骨架生成器（B2）打地基：跨平台逐位一致的整数哈希噪声模块、每 pass 独立 RNG 流（改一段参数不重洗别段）、双 BFS 绕路上限修复（现行 walker 地图立即受益）。

**Architecture:** 新模块 `scripts/map/generation/int_noise.gd`（纯静态，squirrel3 式 32 位掩码哈希 + 定点双线性值噪声 + 种子派生链）；`map_generator.generate()` 签名不变，内部各 pass 改用派生种子的独立 RNG；新增生成后修复 pass（每口真实 BFS 路长 / 曼哈顿 ≤ detour_cap，超限双 BFS 选最优破墙格开凿，≤3 轮）。与设计稿任务表的偏差：原"任务 0 ctx 重构"中 ctx 字典化推迟到 B2 新编排器（旧管线即将被替换，深改无益），本计划只落其意图——流隔离与可测性；"绕路下限 spur"需要 B2 的山脊生长机器，随 B2 修复任务实现。

**Tech Stack:** Godot 4.6 GDScript（TAB、警告即错误、preload 常量跨文件引用）；headless `extends SceneTree` 回归。

**规格:** docs/superpowers/specs/2026-06-11-terrain-generation-design-draft.md §1.0-1.1（S0/S6②）/§5（决定性）/§6（A 组、B3）

**通用约束:** 测试命令 `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/<file>.gd`；`--check-only` 解析受改文件；conventional commits；禁 `git add -A`。

**文件总览:**
- Create: `scripts/map/generation/int_noise.gd`（纯静态噪声/哈希工具）
- Modify: `scripts/map/map_generator.gd`（分流种子 + 修复 pass）
- Modify: `data/map_generation.json`（detour_cap / max_repair_rounds）
- Create: `scripts/debug/test_map_generation.gd`（第十套件，B2 继续扩展）
- Task 3 文档随 B2 收尾统一更新（本计划不动 docs/）

---

### Task B1-1: int_noise.gd 整数哈希噪声模块

**Files:**
- Create: `scripts/map/generation/int_noise.gd`
- Create: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 新建套件 + 失败测试**

创建 `scripts/debug/test_map_generation.gd`：

```gdscript
extends SceneTree

## 地图生成回归（地形包 B1 起建，B2 持续扩展）：
## 噪声决定性 / 种子分流隔离 / 绕路上限修复。
## 运行：Godot --headless --path . --script scripts/debug/test_map_generation.gd

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")
const MapGeneratorScript = preload("res://scripts/map/map_generator.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_int_noise()
	_finish()


func _test_int_noise() -> void:
	# 决定性：同参同值，逐位一致。
	_expect(IntNoise.cell_hash(3, 7, 42) == IntNoise.cell_hash(3, 7, 42), "cell_hash deterministic")
	_expect(IntNoise.derive_seed(1234, 0, 2) == IntNoise.derive_seed(1234, 0, 2), "derive_seed deterministic")
	# 变化性：换任一输入值应变化（弱断言：至少 95% 邻对不同）。
	var same_count: int = 0
	for i in range(100):
		if IntNoise.cell_hash(i, 0, 42) == IntNoise.cell_hash(i + 1, 0, 42):
			same_count += 1
	_expect(same_count <= 5, "cell_hash varies across x (same=%d)" % same_count)
	_expect(IntNoise.derive_seed(1234, 0, 1) != IntNoise.derive_seed(1234, 0, 2), "stage ids derive distinct seeds")
	_expect(IntNoise.derive_seed(1234, 0, 1) != IntNoise.derive_seed(1234, 1, 1), "attempts derive distinct seeds")
	_expect(IntNoise.derive_seed(1234, 0, 1) != IntNoise.derive_seed(4321, 0, 1), "run seeds derive distinct seeds")
	# 非负（rng.seed 取 int，负数也合法但保持非负便于日志阅读）。
	for seed_value in [0, 1, -7, 123456789]:
		_expect(IntNoise.derive_seed(seed_value, 2, 3) >= 0, "derive_seed non-negative for %d" % seed_value)
	# 值噪声：范围 [0,1)、决定性、网格点间有变化、双线性连续性（相邻采样差 < 0.5）。
	var min_v: float = 1.0
	var max_v: float = 0.0
	var prev: float = IntNoise.value_noise(0, 0, 42, 8)
	var max_step: float = 0.0
	for x in range(64):
		var v: float = IntNoise.value_noise(x, 5, 42, 8)
		min_v = minf(min_v, v)
		max_v = maxf(max_v, v)
		max_step = maxf(max_step, absf(v - prev))
		prev = v
	_expect(min_v >= 0.0 and max_v < 1.0, "value_noise in [0,1) (min=%f max=%f)" % [min_v, max_v])
	_expect(max_v - min_v > 0.2, "value_noise has variation")
	_expect(max_step < 0.5, "value_noise bilinear smoothness (max_step=%f)" % max_step)
	_expect(absf(IntNoise.value_noise(13, 21, 42, 8) - IntNoise.value_noise(13, 21, 42, 8)) == 0.0, "value_noise deterministic")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("MAP GENERATION TESTS PASSED")
		quit(0)
	else:
		printerr("MAP GENERATION TESTS FAILED: %d" % _failures)
		quit(1)
```

- [ ] **Step 2: 跑套件确认失败**（int_noise.gd 不存在 → preload 报错即红）

- [ ] **Step 3: 实现 `scripts/map/generation/int_noise.gd`**（先 `mkdir -p scripts/map/generation`）：

```gdscript
class_name IntNoiseUtil
extends RefCounted

## 整数哈希噪声工具（设计稿 §5）：squirrel3 式 32 位掩码哈希 + 定点双线性值噪声。
## 全部运算落在 32 位掩码整数上，跨平台逐位一致；不用 FastNoiseLite（浮点位差风险）。
## headless 测试经 preload 使用，勿依赖 class_name 注册。

const MASK_32 := 0xFFFFFFFF
const NOISE_1 := 0xB5297A4D
const NOISE_2 := 0x68E31DA4
const NOISE_3 := 0x1B56C4E9
const PRIME_Y := 198491317


## squirrel3 单值哈希：输入任意 int，输出 [0, 2^32) 掩码整数。
static func squirrel3(position: int, seed_value: int) -> int:
	var mangled: int = (position & MASK_32)
	mangled = (mangled * NOISE_1) & MASK_32
	mangled = (mangled + (seed_value & MASK_32)) & MASK_32
	mangled ^= (mangled >> 8)
	mangled = (mangled + NOISE_2) & MASK_32
	mangled ^= (mangled << 8) & MASK_32
	mangled = (mangled * NOISE_3) & MASK_32
	mangled ^= (mangled >> 8)
	return mangled & MASK_32


## 种子派生链：run_seed → attempt → stage，三层 squirrel3 嵌套（设计稿 S0）。
static func derive_seed(run_seed: int, attempt: int, stage_id: int) -> int:
	var mixed: int = squirrel3(run_seed, 0)
	mixed = squirrel3(attempt, mixed)
	mixed = squirrel3(stage_id, mixed)
	return mixed


## 二维格点哈希：输出 [0, 65536) 的 16 位整数（双线性用）。
static func cell_hash(x: int, y: int, seed_value: int) -> int:
	return squirrel3(x + ((y * PRIME_Y) & MASK_32), seed_value) >> 16


## 定点双线性值噪声：输出 [0.0, 1.0)。scale = 噪声网格边长（格数，>=1）。
## 权重用 1/256 定点，整数插值后才除以 65536.0——同输入逐位一致。
static func value_noise(x: int, y: int, seed_value: int, scale: int) -> float:
	var safe_scale: int = maxi(scale, 1)
	var gx: int = x / safe_scale if x >= 0 else (x - safe_scale + 1) / safe_scale
	var gy: int = y / safe_scale if y >= 0 else (y - safe_scale + 1) / safe_scale
	var fx: int = (x - gx * safe_scale) * 256 / safe_scale
	var fy: int = (y - gy * safe_scale) * 256 / safe_scale
	var h00: int = cell_hash(gx, gy, seed_value)
	var h10: int = cell_hash(gx + 1, gy, seed_value)
	var h01: int = cell_hash(gx, gy + 1, seed_value)
	var h11: int = cell_hash(gx + 1, gy + 1, seed_value)
	var top: int = h00 * (256 - fx) + h10 * fx
	var bottom: int = h01 * (256 - fx) + h11 * fx
	var blended: int = (top * (256 - fy) + bottom * fy) >> 16
	return float(blended) / 65536.0
```

- [ ] **Step 4: 跑套件 → `MAP GENERATION TESTS PASSED`；`--check-only` int_noise.gd**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/generation/int_noise.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): integer hash noise module for deterministic generation"
```

---

### Task B1-2: map_generator 每 pass 独立 RNG 流

**Files:**
- Modify: `scripts/map/map_generator.gd`（`generate`:39-59）
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。追加 `_test_stage_stream_isolation()`，在 `_run()` 中调用：**

```gdscript
func _serialize_terrain(generated: Dictionary) -> String:
	var cells: Dictionary = generated.get("cells", {})
	var keys: Array = cells.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for raw_key: Variant in keys:
		var data: CellData = cells[raw_key]
		parts.append("%s:%s:%s" % [str(raw_key), String(data.terrain), String(data.resource_type)])
	return "|".join(parts)


func _serialize_obstacles_only(generated: Dictionary) -> String:
	var cells: Dictionary = generated.get("cells", {})
	var keys: Array = cells.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for raw_key: Variant in keys:
		var data: CellData = cells[raw_key]
		if data.terrain != CellDataRef.TERRAIN_PLAIN:
			parts.append("%s:%s" % [str(raw_key), String(data.terrain)])
	return "|".join(parts)


func _test_stage_stream_isolation() -> void:
	var base_cfg := {"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0}
	var a: Dictionary = MapGeneratorScript.generate(30, 30, 9001, base_cfg, [])
	var b: Dictionary = MapGeneratorScript.generate(30, 30, 9001, base_cfg, [])
	_expect(_serialize_terrain(a) == _serialize_terrain(b), "same seed same map (full determinism)")
	var c: Dictionary = MapGeneratorScript.generate(30, 30, 9002, base_cfg, [])
	_expect(_serialize_terrain(a) != _serialize_terrain(c), "different seed different map")
	# 流隔离：只改资源参数，出怪口与障碍布局不得变化。
	var resource_cfg := {"spawn_count": 5, "resources_per_type": 8, "event_point_count": 0}
	var d: Dictionary = MapGeneratorScript.generate(30, 30, 9001, resource_cfg, [])
	_expect(str(a.get("spawn_cells")) == str(d.get("spawn_cells")), "resource cfg change keeps spawn placement")
	_expect(_serialize_obstacles_only(a) == _serialize_obstacles_only(d), "resource cfg change keeps obstacle layout")
```

套件顶部补 `const CellDataRef = preload("res://scripts/map/cell_data.gd")`。

- [ ] **Step 2: 跑套件确认失败**（现行单 RNG 线性消费：资源参数变化会改变后续抽样流……注意 spawn 在资源**之前**抽取所以 spawn 断言可能恰好过，obstacle 同理——真正会红的是：现行实现里资源 pass 消费 RNG 的**次数**取决于 target 数，而事件 pass 在其后；若四个断言全绿说明现实现恰好顺序无关，则把 base_cfg 的变化点换成 `"water_obstacle_chance": 0.0`（障碍参数）并断言 spawn 不变、资源布点不变——总之构造一个"上游参数变化污染下游流"的红例。把最终采用的红例写进报告。）

- [ ] **Step 3: 实现 map_generator.gd 分流**

顶部：`const IntNoise = preload("res://scripts/map/generation/int_noise.gd")` 与 stage 常量：

```gdscript
const STAGE_SPAWNS := 1
const STAGE_OBSTACLES := 2
const STAGE_RESOURCES := 3
const STAGE_EVENTS := 4
const STAGE_REPAIR := 5
```

`generate()` 改为每 pass 派生独立 RNG（attempt 先固定 0，B2 重试时启用）：

```gdscript
static func _stage_rng(run_seed: int, stage_id: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = IntNoise.derive_seed(run_seed, 0, stage_id)
	return rng
```

`generate` 内：`seed < 0` 时先 `randomize` 出一个实际种子（保持旧语义：`var actual_seed := seed if seed >= 0 else int(Time.get_unix_time_from_system())`——注意现行代码用 rng.randomize()，改为显式 actual_seed 以便全管线可复现），然后：

```gdscript
	var spawn_cells := _place_spawns(cells, width, height, core_cell, _stage_rng(actual_seed, STAGE_SPAWNS), cfg)
	_place_random_obstacles(cells, width, height, spawn_cells, core_cell, _stage_rng(actual_seed, STAGE_OBSTACLES), cfg)
	_place_resources(cells, width, height, spawn_cells, core_cell, _stage_rng(actual_seed, STAGE_RESOURCES), cfg)
	var event_points := _place_event_points(cells, width, height, spawn_cells, core_cell, _stage_rng(actual_seed, STAGE_EVENTS), cfg, event_ids)
```

（各 `_place_*` 签名本就收 rng 参数，零内改。）

- [ ] **Step 4: 跑套件 → PASSED。回归 test_spawn_gates_v2（等弧放置仍决定性——注意：分流后同 seed 的地图与旧实现**不同**属预期，等弧测试只断言构造性质不断言具体格，应天然绿）+ test_highland_platform + test_night_waves_affixes → PASSED**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/map_generator.gd scripts/debug/test_map_generation.gd
git commit -m "feat(map): per-stage rng streams via derived seeds"
```

---

### Task B1-3: 双 BFS 绕路上限修复

**Files:**
- Modify: `scripts/map/map_generator.gd`（generate 内 obstacles 之后插入修复 pass）
- Modify: `data/map_generation.json`
- Modify: `scripts/debug/test_map_generation.gd`

- [ ] **Step 1: 失败测试。追加 `_test_detour_repair()`：**

```gdscript
func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _bfs_path_length(cells: Dictionary, width: int, height: int, from_cell: Vector2i, to_cell: Vector2i) -> int:
	var queue: Array[Vector2i] = [from_cell]
	var dist: Dictionary = {from_cell: 0}
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == to_cell:
			return int(dist[current])
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
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
	return -1


func _test_detour_repair() -> void:
	# 高障碍预算逼出绕路，修复后所有口路长/曼哈顿 ≤ detour_cap。
	var cfg := {
		"spawn_count": 5,
		"resources_per_type": 12,
		"event_point_count": 0,
		"obstacle_ratio": 0.24,
		"min_obstacle_count": 190,
		"max_obstacle_count": 220,
		"detour_cap": 1.6,
		"max_repair_rounds": 3,
	}
	var worst_ratio: float = 0.0
	for seed_value in range(7000, 7015):
		var generated: Dictionary = MapGeneratorScript.generate(30, 30, seed_value, cfg, [])
		var cells: Dictionary = generated.get("cells", {})
		var core_cell: Vector2i = generated.get("core_cell", Vector2i.ZERO)
		for raw_spawn: Variant in generated.get("spawn_cells", []):
			var spawn_cell: Vector2i = raw_spawn
			var path_len: int = _bfs_path_length(cells, 30, 30, spawn_cell, core_cell)
			_expect(path_len > 0, "seed %d: gate connected" % seed_value)
			if path_len <= 0:
				continue
			var ratio: float = float(path_len) / float(maxi(_manhattan(spawn_cell, core_cell), 1))
			worst_ratio = maxf(worst_ratio, ratio)
			_expect(ratio <= 1.6 + 0.0001, "seed %d: detour ratio %.3f <= 1.6" % [seed_value, ratio])
	print("  detour worst ratio: %.3f" % worst_ratio)
	# 决定性保持：修复也走派生流。
	var a: Dictionary = MapGeneratorScript.generate(30, 30, 7000, cfg, [])
	var b: Dictionary = MapGeneratorScript.generate(30, 30, 7000, cfg, [])
	_expect(_serialize_terrain(a) == _serialize_terrain(b), "repair keeps determinism")
```

- [ ] **Step 2: 跑套件确认失败**（高预算下部分 seed 比值 > 1.6；若 15 个 seed 全部恰好 ≤1.6 则把 obstacle 预算再调高直至出现红例，并把最终参数写回测试与报告）

- [ ] **Step 3: 实现修复 pass（map_generator.gd）**

`generate` 中 `_place_random_obstacles(...)` 之后、`_place_resources(...)` 之前插：

```gdscript
	_repair_gate_detours(cells, width, height, spawn_cells, core_cell, cfg)
```

实现（文件尾部追加；纯静态）：

```gdscript
## 绕路上限修复（设计稿 S6②）：每口真实 BFS 路长 / 曼哈顿 > detour_cap 时，
## 双 BFS 选最优破墙格开凿（min(邻 dist_gate)+1+min(邻 dist_core) 最小、并列取 (y,x) 序）。
## 每口 ≤ max_repair_rounds 轮；开凿格恢复平原，读作天然垭口。
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
			var dist_core: Dictionary = _bfs_distances(cells, width, height, core_cell)
			var best_cell := Vector2i(-1, -1)
			var best_score: int = 1 << 30
			for y in range(height):
				for x in range(width):
					var cell := Vector2i(x, y)
					var data: CellData = cells.get(cell)
					if data == null or data.walkable or data.spawn_key != StringName() or data.is_core or data.resource_type != StringName():
						continue
					var gate_side: int = _min_neighbor_distance(dist_gate, cell)
					var core_side: int = _min_neighbor_distance(dist_core, cell)
					if gate_side < 0 or core_side < 0:
						continue
					var score: int = gate_side + 1 + core_side
					if score < best_score:
						best_score = score
						best_cell = cell
			if best_cell.x < 0:
				break
			var carved: CellData = cells[best_cell]
			carved.set_base_terrain(CellData.TERRAIN_PLAIN)


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


static func _min_neighbor_distance(dist: Dictionary, cell: Vector2i) -> int:
	var best: int = -1
	for direction in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if not dist.has(neighbor):
			continue
		var value: int = int(dist[neighbor])
		if best < 0 or value < best:
			best = value
	return best
```

实现注意：
- 行优先扫描 + `<` 严格比较 = 并列取 (y,x) 全序，决定性无 RNG（STAGE_REPAIR 常量留给 B2 的随机化修复用，本 pass 纯确定性）；
- 开凿格排除口格/核心/资源格（资源此时尚未放置，防御性保留）；highland 此阶段不存在于生成器输出，但 `walkable` 判定天然覆盖；
- 水/山都可被凿（设计稿：凿水读作渡口、凿山读作垭口）。

`data/map_generation.json` 追加 `"detour_cap": 1.6, "max_repair_rounds": 3`。

- [ ] **Step 4: 跑套件 → PASSED（含 worst ratio 打印）。回归四套件：test_spawn_gates_v2 / test_highland_platform / test_night_waves_affixes / test_contract_events → PASSED。boot `--quit-after 5` 干净（真实局预算 65-115 下修复多为零开凿，但管线要跑通）。**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/map_generator.gd data/map_generation.json scripts/debug/test_map_generation.gd
git commit -m "feat(map): double-bfs detour cap repair pass"
```

---

## 自审记录

- **规格覆盖**：设计稿 §5 整数噪声/splitmix 链 → B1-1（squirrel3 实现，语义同）；S0 每 pass RNG 流 → B1-2（ctx 字典化显式推迟 B2，偏差已在 Architecture 声明）；S6② 绕路上限 + §6 B3 断言 → B1-3（绕路下限 spur 显式推迟 B2）。
- **类型一致性**：IntNoise.derive_seed/cell_hash/value_noise 签名三任务一致；`_serialize_terrain` 在 B1-2 定义、B1-3 复用。
- **实现期对齐点**：B1-2 Step 2 的红例构造（哪个参数变化能污染下游流取决于现行 RNG 消费顺序，由实现者实测后定，写进报告）；`generate` 的 `seed < 0` randomize 旧语义改 actual_seed 显式化。
