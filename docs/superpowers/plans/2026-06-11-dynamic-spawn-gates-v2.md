# 动态出怪口 v2 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 候选口 3→5（等弧放置），活跃集按天单调扩张 + 事件/玩家一夜开关覆盖，预览与运行时共享活跃集（公示即契约），UI 同步两态标记/封口弹窗/活跃口行/黎明公告。

**Architecture:** 纯静态解析（night_template_resolver 新增激活序与活跃集函数，无存档状态）→ RunState 仅存两个一夜覆盖数组（黎明清空）→ wave_manager._active_spawn_keys() 换源（预览/运行时单点真源）→ day_manager 承载玩家封口动作 → 事件走契约 effects 分支。

**Tech Stack:** Godot 4.6 GDScript（警告即错误：显式类型、禁 Variant 推断）；headless 回归 `extends SceneTree` 脚本。

**规格:** docs/superpowers/specs/2026-06-11-dynamic-spawn-gates-v2-design.md

**通用约束（每个任务都适用）:**
- TAB 缩进；跨文件引用脚本类一律 `const X = preload("res://...")`（headless 下 class_name 不注册）；
- 测试命令统一 `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/<file>.gd`；
- 每任务结束跑本任务测试 + `--check-only` 解析受改文件；任务 9 跑全量八套件；
- commit 用 conventional 格式，禁 `git add -A`。

**文件总览:**
- Modify: `scripts/map/map_generator.gd`（等弧放置）、`data/map_generation.json`（spawn_count 5 + 弧参数）
- Modify: `scripts/enemy/night_template_resolver.gd`（追加激活序/活跃集统计函数）
- Modify: `autoload/RunState.gd`（覆盖项字段+方法）、`autoload/EventBus.gd`（信号）、`scripts/core/game_controller.gd`（enter_day 清空）
- Modify: `scripts/enemy/wave_manager.gd`（_active_spawn_keys 换源 + preview 加 active_gates）
- Modify: `scripts/core/day_manager.gd`（try_seal_spawn_gate）
- Modify: `data/events.json` + `scripts/core/random_event_manager.gd`（塌方契约/开口赌约）
- Modify: `scripts/map/map_manager.gd`（标记动态同步+状态）、`scripts/map/spawn_point_view.gd`（两态+角标）
- Modify: `scripts/ui/map_interaction_popup.gd`（封口分支）、`scripts/ui/combat/combat_hud.gd` + `combat_hud_controller.gd`（活跃口行+黎明公告）
- Create: `scripts/debug/test_spawn_gates_v2.gd`（本特性专属套件，随任务逐步扩展）
- Modify: `docs/DATA_SCHEMA.md`、`docs/肉鸽构筑与战斗优化方案.md` §8.1（任务 9）

---

### Task 1: 等弧放置 5 候选口

**Files:**
- Modify: `scripts/map/map_generator.gd:88-124`（替换 `_place_spawns` 与 `_get_edge_candidates` 的消费方式）
- Modify: `data/map_generation.json`
- Create: `scripts/debug/test_spawn_gates_v2.gd`

- [ ] **Step 1: 写失败测试（新建套件骨架 + 弧放置断言）**

创建 `scripts/debug/test_spawn_gates_v2.gd`：

```gdscript
extends SceneTree

## 动态出怪口 v2 回归：等弧放置 / 激活序 / 覆盖项 / 封口 / 公示冻结。
## 运行：Godot --headless --path . --script scripts/debug/test_spawn_gates_v2.gd

const MapGeneratorScript = preload("res://scripts/map/map_generator.gd")
const ResolverScript = preload("res://scripts/enemy/night_template_resolver.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_arc_placement()
	_finish()


func _perimeter_index(cell: Vector2i, width: int, height: int) -> int:
	if cell.y == 0:
		return cell.x
	if cell.x == width - 1:
		return (width - 1) + cell.y
	if cell.y == height - 1:
		return (width - 1) + (height - 1) + (width - 1 - cell.x)
	return (width - 1) * 2 + (height - 1) + (height - 1 - cell.y)


func _test_arc_placement() -> void:
	var cfg := {"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0}
	var perimeter_total: int = (30 - 1) * 4
	for seed_value in range(1000, 1020):
		var generated: Dictionary = MapGeneratorScript.generate(30, 30, seed_value, cfg, [])
		var spawn_cells: Array = generated.get("spawn_cells", [])
		_expect(spawn_cells.size() == 5, "seed %d: 5 gates placed" % seed_value)
		var cells: Dictionary = generated.get("cells", {})
		var indices: Array[int] = []
		for raw_cell: Variant in spawn_cells:
			var cell: Vector2i = raw_cell
			var on_edge := cell.x == 0 or cell.y == 0 or cell.x == 29 or cell.y == 29
			_expect(on_edge, "seed %d: gate on edge" % seed_value)
			var near_corner := (cell.x < 3 or cell.x > 26) and (cell.y < 3 or cell.y > 26)
			_expect(not near_corner, "seed %d: gate away from corners" % seed_value)
			var data: CellData = cells.get(cell)
			_expect(data != null and data.spawn_key != StringName(), "seed %d: gate cell keyed" % seed_value)
			_expect(data != null and not data.discovered and not data.buildable, "seed %d: gate cell invariants" % seed_value)
			indices.append(_perimeter_index(cell, 30, 30))
		indices.sort()
		for i in range(indices.size()):
			var next_index: int = indices[(i + 1) % indices.size()]
			var gap: int = next_index - indices[i] if i + 1 < indices.size() else perimeter_total - indices[i] + indices[0]
			_expect(gap >= 8, "seed %d: perimeter gap %d >= 8" % [seed_value, gap])
	var first: Dictionary = MapGeneratorScript.generate(30, 30, 4242, cfg, [])
	var second: Dictionary = MapGeneratorScript.generate(30, 30, 4242, cfg, [])
	_expect(str(first.get("spawn_cells")) == str(second.get("spawn_cells")), "same seed same gates")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("SPAWN GATES V2 TESTS PASSED")
		quit(0)
	else:
		printerr("SPAWN GATES V2 TESTS FAILED: %d" % _failures)
		quit(1)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/test_spawn_gates_v2.gd`
Expected: FAIL（gap 断言大量失败——现行洗牌贪心不保证分散；可能还有 5 口数量失败）

- [ ] **Step 3: 实现等弧放置**

`scripts/map/map_generator.gd`：在常量区加（保留旧常量不删）：

```gdscript
const SPAWN_CORNER_MARGIN := 3
const SPAWN_ARC_CENTER_RATIO := 0.6
```

整体替换 `_place_spawns`（原 88-113 行），并新增两个辅助（`_get_edge_candidates` 保留给其他调用方，若无人用则删除）：

```gdscript
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
		if options.is_empty():
			for index in range(int(ceil(arc_start)), int(floor(arc_start + arc_len))):
				var fallback_cell: Vector2i = perimeter[(index + phase) % total]
				if not _is_near_corner(fallback_cell, width, height, corner_margin):
					options.append(fallback_cell)
		var pick: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		var spawn_data: CellData = cells[pick]
		spawn_data.spawn_key = StringName("S%d" % (spawn_cells.size() + 1))
		spawn_data.set_base_terrain(CellData.TERRAIN_PLAIN)
		spawn_data.discovered = false
		spawn_data.buildable = false
		spawn_cells.append(pick)
	return spawn_cells
```

`data/map_generation.json`：`"spawn_count": 3` 改 `5`；删除 `"min_spawn_core_distance"` 与 `"min_spawn_distance"` 两键（已无消费方）；追加 `"spawn_corner_margin": 3, "spawn_arc_center_ratio": 0.6`。同时确认 map_generator 内不再引用 `MIN_SPAWN_CORE_DISTANCE`/`MIN_SPAWN_DISTANCE`（删掉这两个常量与 `_manhattan` 若已无人用）。

- [ ] **Step 4: 跑测试确认通过 + 解析检查**

Run: 同 Step 2，Expected: `SPAWN GATES V2 TESTS PASSED`
Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/map/map_generator.gd`，Expected: 无输出（解析通过）

- [ ] **Step 5: 回归既有受影响套件**

Run: test_wave_templates / test_night_waves_affixes / test_night_template_flow（三者涉及地图与口）
Expected: 全 PASSED（若 test_night_waves_affixes 的 boot 段对口数有隐含假设，按"以 get_spawn_keys() 动态取数"修正测试而非实现）

- [ ] **Step 6: Commit**

```bash
git add scripts/map/map_generator.gd data/map_generation.json scripts/debug/test_spawn_gates_v2.gd
git commit -m "feat(map): place five spawn gates by equal perimeter arcs"
```

---

### Task 2: 解析器激活序与活跃集

**Files:**
- Modify: `scripts/enemy/night_template_resolver.gd`（127 行后追加）
- Modify: `scripts/debug/test_spawn_gates_v2.gd`

- [ ] **Step 1: 写失败测试（追加 `_test_activation()`，并在 `_run` 中调用）**

```gdscript
func _test_activation() -> void:
	var gates := ["S1", "S2", "S3", "S4", "S5"]
	var order_a: Array = ResolverScript.resolve_activation_order(gates, 777)
	var order_b: Array = ResolverScript.resolve_activation_order(gates, 777)
	_expect(str(order_a) == str(order_b), "activation order deterministic")
	_expect(order_a.size() == 5, "activation order full permutation")
	var sorted_copy: Array = order_a.duplicate()
	sorted_copy.sort()
	_expect(str(sorted_copy) == str(["S1", "S2", "S3", "S4", "S5"]), "activation order is a permutation")
	var varied := false
	for seed_value in range(50):
		if str(ResolverScript.resolve_activation_order(gates, seed_value)) != str(order_a):
			varied = true
			break
	_expect(varied, "activation order varies across seeds")
	_expect(ResolverScript.active_gate_count_for_day(1) == 2, "day1 count 2")
	_expect(ResolverScript.active_gate_count_for_day(2) == 2, "day2 count 2")
	_expect(ResolverScript.active_gate_count_for_day(3) == 3, "day3 count 3")
	_expect(ResolverScript.active_gate_count_for_day(5) == 4, "day5 count 4")
	_expect(ResolverScript.active_gate_count_for_day(9) == 5, "day9 count 5")
	var prev: Array = []
	for day in range(1, 10):
		var active: Array = ResolverScript.resolve_active_gates(gates, 777, day)
		_expect(active.size() == mini(ResolverScript.active_gate_count_for_day(day), 5), "day %d active size" % day)
		for raw_gate: Variant in prev:
			_expect(active.has(String(raw_gate)), "day %d superset of day %d" % [day, day - 1])
		prev = active
	var with_closed: Array = ResolverScript.resolve_active_gates(gates, 777, 3, [order_a[0]])
	_expect(not with_closed.has(String(order_a[0])), "closed gate excluded")
	_expect(with_closed.size() == 2, "closed shrinks active set")
	var silent_gate := String(order_a[4])
	var with_extra: Array = ResolverScript.resolve_active_gates(gates, 777, 1, [], [silent_gate])
	_expect(with_extra.has(silent_gate), "extra gate included")
	_expect(with_extra.size() == 3, "extra grows active set")
	var all_closed: Array = ResolverScript.resolve_active_gates(gates, 777, 1, gates)
	_expect(all_closed.size() == 1 and all_closed[0] == String(order_a[0]), "min one gate kept (order head)")
	_expect((ResolverScript.resolve_active_gates([], 777, 1) as Array).is_empty(), "empty gates -> empty")
```

- [ ] **Step 2: 跑测试确认失败**（Expected: FAIL，函数不存在导致脚本报错也算红——若整脚本编译失败，先以 `has_method` 探测式写法过渡或直接接受报错为红）

- [ ] **Step 3: 实现（night_template_resolver.gd 末尾追加）**

```gdscript
## 活跃口数量日程表（占位值）：阶梯取 <= day 的最大键。
const ACTIVE_COUNT_BY_DAY := {1: 2, 3: 3, 5: 4, 7: 5}


static func active_gate_count_for_day(day: int) -> int:
	var best_key: int = -1
	for raw_key: Variant in ACTIVE_COUNT_BY_DAY.keys():
		var key := int(raw_key)
		if key <= day and key > best_key:
			best_key = key
	if best_key < 0:
		return int(ACTIVE_COUNT_BY_DAY.get(1, 2))
	return int(ACTIVE_COUNT_BY_DAY.get(best_key, 2))


## 激活序：每局固定的口激活顺序。无存档状态，任意一天可由 seed 重算。
static func resolve_activation_order(all_gates: Array, run_seed: int) -> Array[String]:
	var gates := _sorted_gates(all_gates)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("gate_order|%d" % run_seed).hash())
	for i in range(gates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := gates[i]
		gates[i] = gates[j]
		gates[j] = tmp
	return gates


## 当日有效活跃集 = (激活序前 N ∪ extra_open) − closed，下限 1（保激活序第一位）。
## closed/extra_open 是一夜覆盖项（RunState 持有，黎明清空）。返回值升序。
static func resolve_active_gates(all_gates: Array, run_seed: int, day: int, closed: Array = [], extra_open: Array = []) -> Array[String]:
	var order := resolve_activation_order(all_gates, run_seed)
	if order.is_empty():
		return []
	var closed_keys: Array[String] = []
	for raw_closed: Variant in closed:
		closed_keys.append(String(raw_closed))
	var count: int = mini(active_gate_count_for_day(day), order.size())
	var active: Array[String] = []
	for i in range(count):
		active.append(order[i])
	for raw_extra: Variant in extra_open:
		var extra_gate := String(raw_extra)
		if order.has(extra_gate) and not active.has(extra_gate):
			active.append(extra_gate)
	var result: Array[String] = []
	for gate in active:
		if not closed_keys.has(gate):
			result.append(gate)
	if result.is_empty():
		result.append(order[0])
	result.sort()
	return result
```

- [ ] **Step 4: 跑测试确认通过**（含 Task 1 部分继续绿）

- [ ] **Step 5: Commit**

```bash
git add scripts/enemy/night_template_resolver.gd scripts/debug/test_spawn_gates_v2.gd
git commit -m "feat(night): seeded gate activation order and daily active set"
```

---

### Task 3: RunState 一夜覆盖项 + EventBus 信号 + 黎明清空

**Files:**
- Modify: `autoload/RunState.gd`（字段区 ~39-41 行附近、reset_for_new_run）
- Modify: `autoload/EventBus.gd`（信号区）
- Modify: `scripts/core/game_controller.gd:49-50`（enter_day）
- Modify: `scripts/debug/test_spawn_gates_v2.gd`

- [ ] **Step 1: 写失败测试（追加 `_test_overrides_lifecycle()`，需要场景树：参照 test_contract_events 的 boot 写法，加载 Game.tscn 后取 RunState/GameController）**

```gdscript
func _test_overrides_lifecycle() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var game_controller := game.get_node_or_null("Managers/GameController")
	_expect(run_state != null and game_controller != null, "boot ok for overrides test")
	if run_state == null or game_controller == null:
		game.queue_free()
		await process_frame
		return
	run_state.add_night_gate_closed("S1")
	run_state.add_night_gate_extra_open("S5")
	run_state.night_gate_seals_today = 1
	_expect((run_state.night_gate_closed_keys as Array).has("S1"), "closed recorded")
	_expect((run_state.night_gate_extra_open_keys as Array).has("S5"), "extra recorded")
	game_controller.enter_day(int(run_state.day) + 1)
	_expect((run_state.night_gate_closed_keys as Array).is_empty(), "closed cleared at dawn")
	_expect((run_state.night_gate_extra_open_keys as Array).is_empty(), "extra cleared at dawn")
	_expect(int(run_state.night_gate_seals_today) == 0, "seal counter cleared at dawn")
	game.queue_free()
	await process_frame
```

注意 `_run` 改 async：调用处 `await _test_overrides_lifecycle()`。

- [ ] **Step 2: 跑测试确认失败**（字段不存在）

- [ ] **Step 3: 实现**

`autoload/EventBus.gd` 信号区追加：

```gdscript
signal night_gate_overrides_changed()
```

`autoload/RunState.gd` 在 `night_wager_active` 附近追加字段与方法：

```gdscript
var night_gate_closed_keys: Array[String] = []
var night_gate_extra_open_keys: Array[String] = []
var night_gate_seals_today: int = 0


func clear_night_gate_overrides() -> void:
	night_gate_closed_keys = []
	night_gate_extra_open_keys = []
	night_gate_seals_today = 0
	EventBus.night_gate_overrides_changed.emit()


func add_night_gate_closed(gate_key: String) -> void:
	if gate_key.is_empty() or night_gate_closed_keys.has(gate_key):
		return
	night_gate_closed_keys.append(gate_key)
	EventBus.night_gate_overrides_changed.emit()


func add_night_gate_extra_open(gate_key: String) -> void:
	if gate_key.is_empty() or night_gate_extra_open_keys.has(gate_key):
		return
	night_gate_extra_open_keys.append(gate_key)
	EventBus.night_gate_overrides_changed.emit()
```

`reset_for_new_run`（~71 行 `night_wager_active = false` 附近）追加 `clear_night_gate_overrides()`。
`scripts/core/game_controller.gd` `enter_day` 中 `run_state.night_core_damaged = false`（50 行）之后追加：

```gdscript
	if run_state.has_method("clear_night_gate_overrides"):
		run_state.clear_night_gate_overrides()
```

- [ ] **Step 4: 跑测试确认通过**
- [ ] **Step 5: Commit**

```bash
git add autoload/RunState.gd autoload/EventBus.gd scripts/core/game_controller.gd scripts/debug/test_spawn_gates_v2.gd
git commit -m "feat(night): one-night gate override state cleared at dawn"
```

---

### Task 4: wave_manager 接活跃集 + 公示冻结断言

**Files:**
- Modify: `scripts/enemy/wave_manager.gd:418-421`（`_active_spawn_keys`）与 `get_night_preview`（183 行函数，返回字典加键）
- Modify: `scripts/debug/test_spawn_gates_v2.gd`

- [ ] **Step 1: 写失败测试（追加 `_test_active_set_consumption()`，复用 Step1@Task3 的 boot 模式）**

```gdscript
func _test_active_set_consumption() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var wave_manager := game.get_node_or_null("Managers/WaveManager")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	_expect(run_state != null and wave_manager != null and map_manager != null, "boot ok for active set test")
	if run_state == null or wave_manager == null or map_manager == null:
		game.queue_free()
		await process_frame
		return
	var all_gates: Array = map_manager.get_spawn_keys()
	_expect(all_gates.size() == 5, "five gates registered")
	var expected: Array = ResolverScript.resolve_active_gates(all_gates, int(run_state.random_seed), int(run_state.day), run_state.night_gate_closed_keys, run_state.night_gate_extra_open_keys)
	_expect(expected.size() == 2, "day1 two active gates")
	var template_ids: Array = [run_state.night_template_ids[0]] if (run_state.night_template_ids as Array).size() > 0 else []
	var preview: Dictionary = wave_manager.get_night_preview(run_state.night_template_ids, run_state.night_affix_ids)
	var preview_gates: Array = preview.get("active_gates", [])
	_expect(str(preview_gates) == str(expected), "preview exposes active gates")
	for raw_summary: Variant in preview.get("wave_summaries", []):
		var summary: Dictionary = raw_summary
		_expect(expected.has(String(summary.get("main_gate", ""))), "main gate within active set")
		for raw_entry: Variant in summary.get("entries", []):
			var entry: Dictionary = raw_entry
			_expect(expected.has(String(entry.get("spawn_key", ""))), "entry gate within active set")
	# 封口后冻结契约：预览与解析共用同一活跃集。
	var victim := String(expected[0])
	run_state.add_night_gate_closed(victim)
	var preview2: Dictionary = wave_manager.get_night_preview(run_state.night_template_ids, run_state.night_affix_ids)
	var gates2: Array = preview2.get("active_gates", [])
	_expect(not gates2.has(victim), "sealed gate absent from preview")
	for raw_summary2: Variant in preview2.get("wave_summaries", []):
		var summary2: Dictionary = raw_summary2
		for raw_entry2: Variant in summary2.get("entries", []):
			_expect(String((raw_entry2 as Dictionary).get("spawn_key", "")) != victim, "no entry spawns at sealed gate")
	run_state.clear_night_gate_overrides()
	game.queue_free()
	await process_frame
```

注：`run_state.night_template_ids` 若字段名不符，以 RunState 实际字段为准（grep `night_template`）；预览字段名 `wave_summaries/main_gate/entries` 与 v1 一致（wave_manager.gd:183-378 可对照）。

- [ ] **Step 2: 跑测试确认失败**（active_gates 键不存在 + 5 口下预览出现非活跃口）

- [ ] **Step 3: 实现**

`_active_spawn_keys()` 整体替换：

```gdscript
func _active_spawn_keys() -> Array:
	if _map_manager == null or not _map_manager.has_method("get_spawn_keys"):
		return []
	var all_gates: Array = _map_manager.get_spawn_keys()
	var run_state = AppRefs.run_state()
	if run_state == null:
		return all_gates
	# 有效活跃集 =（按天日程 ∪ 事件加开）− 封堵；预览与运行时共用本函数（公示即契约）。
	return NightTemplateResolver.resolve_active_gates(
		all_gates,
		int(run_state.random_seed),
		int(run_state.day),
		run_state.night_gate_closed_keys,
		run_state.night_gate_extra_open_keys
	)
```

`get_night_preview` 返回字典追加一键（在函数末尾 return 的字典里）：`"active_gates": _active_spawn_keys(),`

- [ ] **Step 4: 跑测试确认通过 + 回归 test_night_waves_affixes / test_night_template_flow**
- [ ] **Step 5: Commit**

```bash
git add scripts/enemy/wave_manager.gd scripts/debug/test_spawn_gates_v2.gd
git commit -m "feat(night): waves consume daily active gate set with overrides"
```

---

### Task 5: 玩家封口动作（day_manager）

**Files:**
- Modify: `scripts/core/day_manager.gd`（常量区 + 新函数）
- Modify: `scripts/debug/test_spawn_gates_v2.gd`

- [ ] **Step 1: 写失败测试（追加 `_test_player_seal()`，boot 模式）**

```gdscript
func _test_player_seal() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var day_manager := game.get_node_or_null("Managers/DayManager")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	if run_state == null or day_manager == null or map_manager == null:
		_expect(false, "boot ok for seal test")
		game.queue_free()
		await process_frame
		return
	var all_gates: Array = map_manager.get_spawn_keys()
	var active: Array = ResolverScript.resolve_active_gates(all_gates, int(run_state.random_seed), int(run_state.day), [], [])
	var gate_key := String(active[0])
	var gate_cell: Vector2i = map_manager.get_spawn_cell_by_key(StringName(gate_key))
	var silent_key := ""
	for raw_gate: Variant in all_gates:
		if not active.has(String(raw_gate)):
			silent_key = String(raw_gate)
			break
	run_state.stone = 0
	run_state.reset_action_points(30)
	var poor: Dictionary = day_manager.try_seal_spawn_gate(gate_cell)
	_expect(not poor.get("ok", false), "seal fails without stone")
	run_state.stone = 10
	var not_gate: Dictionary = day_manager.try_seal_spawn_gate(Vector2i(15, 15))
	_expect(not not_gate.get("ok", false), "seal rejects non-gate cell")
	var silent_cell: Vector2i = map_manager.get_spawn_cell_by_key(StringName(silent_key))
	var silent_result: Dictionary = day_manager.try_seal_spawn_gate(silent_cell)
	_expect(not silent_result.get("ok", false), "seal rejects silent gate")
	var ap_before: int = int(run_state.action_points)
	var ok_result: Dictionary = day_manager.try_seal_spawn_gate(gate_cell)
	_expect(ok_result.get("ok", false), "seal succeeds")
	_expect(int(run_state.stone) == 6 and int(run_state.action_points) == ap_before - 6, "seal costs 4 stone 6 ap")
	_expect((run_state.night_gate_closed_keys as Array).has(gate_key), "seal recorded")
	var second_gate := String(active[1])
	var second_cell: Vector2i = map_manager.get_spawn_cell_by_key(StringName(second_gate))
	var second: Dictionary = day_manager.try_seal_spawn_gate(second_cell)
	_expect(not second.get("ok", false), "daily seal limit enforced (also guards min-1)")
	run_state.clear_night_gate_overrides()
	game.queue_free()
	await process_frame
```

- [ ] **Step 2: 跑测试确认失败**（函数不存在）

- [ ] **Step 3: 实现（day_manager.gd 顶部常量 + preload + 新函数）**

```gdscript
const NightTemplateResolver = preload("res://scripts/enemy/night_template_resolver.gd")
const GATE_SEAL_STONE_COST := 4
const GATE_SEAL_AP_COST := 6
const GATE_SEALS_PER_DAY := 1
```

```gdscript
## 玩家封口：白天对一个活跃口支付石材+行动力，使其今晚沉默（一夜有效，黎明解封）。
## 语义是导流不是减伤：总刷怪量不变，怪改派其他活跃口。
func try_seal_spawn_gate(cell: Vector2i) -> Dictionary:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState 尚未初始化")
	if run_state.phase != GameEnums.PHASE_DAY:
		return ActionResult.err(&"INVALID_PHASE", "只有白天才能封堵出怪口")
	if _map_manager == null or not _map_manager.has_method("get_spawn_key_at_cell"):
		return ActionResult.err(&"MAP_UNAVAILABLE", "地图尚未初始化")
	var gate_key := String(_map_manager.get_spawn_key_at_cell(cell))
	if gate_key.is_empty():
		return ActionResult.err(&"NOT_A_GATE", "该格子不是出怪口")
	if int(run_state.night_gate_seals_today) >= GATE_SEALS_PER_DAY:
		return ActionResult.err(&"SEAL_LIMIT_REACHED", "今天已经封堵过出怪口")
	var all_gates: Array = _map_manager.get_spawn_keys()
	var active: Array = NightTemplateResolver.resolve_active_gates(all_gates, int(run_state.random_seed), int(run_state.day), run_state.night_gate_closed_keys, run_state.night_gate_extra_open_keys)
	if not active.has(gate_key):
		return ActionResult.err(&"GATE_NOT_ACTIVE", "该出怪口今晚本就沉默")
	if active.size() <= 1:
		return ActionResult.err(&"LAST_ACTIVE_GATE", "至少要保留一个活跃出怪口")
	if int(run_state.stone) < GATE_SEAL_STONE_COST:
		return ActionResult.err(&"NOT_ENOUGH_MATERIALS", "石材不足（需要 %d）" % GATE_SEAL_STONE_COST)
	if int(run_state.action_points) < GATE_SEAL_AP_COST:
		return ActionResult.err(&"NOT_ENOUGH_AP", "行动力不足（需要 %d）" % GATE_SEAL_AP_COST)
	run_state.spend_materials(0, GATE_SEAL_STONE_COST, 0)
	run_state.consume_action_points(GATE_SEAL_AP_COST)
	run_state.night_gate_seals_today = int(run_state.night_gate_seals_today) + 1
	run_state.add_night_gate_closed(gate_key)
	return ActionResult.ok({"gate_key": gate_key, "ap_cost": GATE_SEAL_AP_COST, "stone_cost": GATE_SEAL_STONE_COST}, "已封堵 %s 一晚，怪物将改道其他出怪口" % gate_key)
```

- [ ] **Step 4: 跑测试确认通过**
- [ ] **Step 5: Commit**

```bash
git add scripts/core/day_manager.gd scripts/debug/test_spawn_gates_v2.gd
git commit -m "feat(day): player gate sealing action with stone and ap cost"
```

---

### Task 6: 事件接入（塌方契约 + 开口赌约）

**Files:**
- Modify: `data/events.json`
- Modify: `scripts/core/random_event_manager.gd`（`_apply_contract_effects` 加分支；动态选项镜像祭坛模式——参照 `_build_altar_choices`:410、`_ensure_altar_offers`:432、`apply_event_for_cell`:228、`get_event_cfg_at_cell`:496-519 的既有结构）
- Modify: `scripts/debug/test_spawn_gates_v2.gd`

- [ ] **Step 1: 写失败测试（追加 `_test_gate_events()`，boot 模式）**

```gdscript
func _test_gate_events() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var event_manager := game.get_node_or_null("Managers/RandomEventManager")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	if run_state == null or event_manager == null or map_manager == null:
		_expect(false, "boot ok for gate events test")
		game.queue_free()
		await process_frame
		return
	var all_gates: Array = map_manager.get_spawn_keys()
	var active: Array = ResolverScript.resolve_active_gates(all_gates, int(run_state.random_seed), int(run_state.day), [], [])
	# 塌方契约：动态选项 = 每个可封活跃口一项 + 离开。
	var landslide_cell := Vector2i(7, 7)
	event_manager._events_by_cell[landslide_cell] = &"event_landslide_contract"
	var cfg: Dictionary = event_manager.get_event_cfg_at_cell(landslide_cell)
	var choices: Array = cfg.get("choices", [])
	_expect(choices.size() == active.size() + 1, "landslide offers one choice per active gate plus leave")
	run_state.mana = 10
	var target_gate := String(active[0])
	var seal_result: Dictionary = event_manager.apply_event_for_cell(landslide_cell, StringName("seal_%s" % target_gate))
	_expect(seal_result.get("ok", false), "landslide seal applies")
	_expect(int(run_state.mana) == 7, "landslide costs 3 mana")
	_expect((run_state.night_gate_closed_keys as Array).has(target_gate), "landslide closes gate tonight")
	# 开口赌约：激活序中下一个沉默口提前开放 + 报酬。
	var prestige_before: int = int(run_state.prestige)
	var wager_result: Dictionary = event_manager.apply_event(&"event_gate_wager_accept")
	_expect(wager_result.get("ok", false), "gate wager applies")
	_expect((run_state.night_gate_extra_open_keys as Array).size() == 1, "gate wager opens one extra gate")
	var opened := String(run_state.night_gate_extra_open_keys[0])
	_expect(not active.has(opened), "wager opens a previously silent gate")
	_expect(int(run_state.prestige) == prestige_before + 3, "wager pays prestige reward")
	run_state.clear_night_gate_overrides()
	game.queue_free()
	await process_frame
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 实现**

`data/events.json` 追加四条（数值占位）：

```json
{"id": "event_landslide_contract", "name": "塌方契约", "desc": "工兵头目敲了敲手里的爆破筒：“看见那些口子了吗？给点魔力矿当工钱，今晚我让其中一个塌得严严实实。”", "effect_type": "contract", "choices": []},
{"id": "event_landslide_leave", "name": "塌方契约", "desc": "你婉拒了。工兵耸耸肩，收起了家伙。", "effect_type": "contract", "hidden_in_map_pool": true},
{"id": "event_gate_wager", "name": "开口赌约", "desc": "斥候压低声音：“东面有条暗道，敌人还没发现。要是我们故意把它捅开，今晚会更难——但乱中取利，报酬丰厚。”", "effect_type": "contract", "max_day": 6, "choices": [{"id": "accept", "text": "捅开暗道", "kind": "primary", "event_id": "event_gate_wager_accept", "effect_desc": "今晚一个沉默出怪口提前开放；立即获得 3 声望与 2 魔力矿。"}, {"id": "decline", "text": "保持隐蔽", "kind": "secondary", "event_id": "event_gate_wager_decline", "effect_desc": "不冒这个险。"}]},
{"id": "event_gate_wager_accept", "name": "开口赌约", "desc": "巨石滚落，暗道洞开。远处传来兴奋的嚎叫。", "effect_type": "contract", "hidden_in_map_pool": true, "payload": {"wood": 0, "stone": 0, "mana": 2, "prestige": 3}, "effects": [{"type": "gate_open_extra_tonight"}]},
{"id": "event_gate_wager_decline", "name": "开口赌约", "desc": "斥候点点头，把地图塞回了怀里。", "effect_type": "contract", "hidden_in_map_pool": true}
```

`random_event_manager.gd`：
1. 顶部确认/追加 `const NightTemplateResolver = preload("res://scripts/enemy/night_template_resolver.gd")`；
2. `get_event_cfg_at_cell` 中镜像祭坛分支：`event_id == &"event_landslide_contract"` 时把 `choices` 置为 `_build_landslide_choices()`；
3. `apply_event_for_cell` 中镜像祭坛分支：cell 上是塌方事件且 `choice_id` 以 `"seal_"` 开头时走 `_apply_landslide_seal`；`choice_id == &"leave"` 时返回 `apply_event(&"event_landslide_leave")`；
4. 新增：

```gdscript
const LANDSLIDE_MANA_COST := 3


func _gate_context() -> Dictionary:
	var run_state = AppRefs.run_state()
	var map_manager := get_node_or_null("../MapManager")
	if run_state == null or map_manager == null or not map_manager.has_method("get_spawn_keys"):
		return {}
	var all_gates: Array = map_manager.get_spawn_keys()
	var active: Array = NightTemplateResolver.resolve_active_gates(all_gates, int(run_state.random_seed), int(run_state.day), run_state.night_gate_closed_keys, run_state.night_gate_extra_open_keys)
	return {"run_state": run_state, "all_gates": all_gates, "active": active}


func _build_landslide_choices() -> Array:
	var choices: Array = []
	var ctx := _gate_context()
	var active: Array = ctx.get("active", [])
	if active.size() > 1:
		for raw_gate: Variant in active:
			var gate := String(raw_gate)
			choices.append({
				"id": "seal_%s" % gate,
				"text": "封堵 %s（%d 魔力矿）" % [gate, LANDSLIDE_MANA_COST],
				"kind": "primary",
				"effect_desc": "今晚 %s 不会出怪，怪物改道其他出怪口。" % gate,
			})
	choices.append({"id": "leave", "text": "不必了", "kind": "secondary", "event_id": "event_landslide_leave", "effect_desc": "保持现状。"})
	return choices


func _apply_landslide_seal(cell: Vector2i, gate_key: String) -> Dictionary:
	var ctx := _gate_context()
	if ctx.is_empty():
		return ActionResult.err(&"MAP_UNAVAILABLE", "地图尚未初始化")
	var run_state: Node = ctx.get("run_state")
	var active: Array = ctx.get("active", [])
	if not active.has(gate_key):
		return ActionResult.err(&"GATE_NOT_ACTIVE", "该出怪口今晚本就沉默")
	if active.size() <= 1:
		return ActionResult.err(&"LAST_ACTIVE_GATE", "至少要保留一个活跃出怪口")
	if int(run_state.mana) < LANDSLIDE_MANA_COST:
		return ActionResult.err(&"NOT_ENOUGH_MATERIALS", "魔力矿不足（需要 %d）" % LANDSLIDE_MANA_COST)
	run_state.spend_materials(0, 0, LANDSLIDE_MANA_COST)
	run_state.add_night_gate_closed(gate_key)
	mark_event_triggered(cell)
	return ActionResult.ok({
		"event_id": &"event_landslide_contract",
		"effect_type": &"contract",
		"effect_payload": {"summary": "今晚 %s 已被塌方封堵" % gate_key},
	})
```

（`mark_event_triggered` 若实际函数名不同，按祭坛消费后清理 cell 的同款调用对齐。）
5. `_apply_contract_effects` 的 match 中追加：

```gdscript
			&"gate_open_extra_tonight":
				var ctx := _gate_context()
				var opened := ""
				if not ctx.is_empty():
					var order: Array = NightTemplateResolver.resolve_activation_order(ctx.get("all_gates", []), int(run_state.random_seed))
					var active_now: Array = ctx.get("active", [])
					for raw_gate: Variant in order:
						var gate := String(raw_gate)
						if not active_now.has(gate):
							opened = gate
							break
				if opened.is_empty():
					summary_lines.append("所有出怪口都已活跃，只剩报酬")
				else:
					run_state.add_night_gate_extra_open(opened)
					summary_lines.append("今晚 %s 提前开放" % opened)
```

- [ ] **Step 4: 跑测试确认通过 + 回归 test_contract_events**
- [ ] **Step 5: Commit**

```bash
git add data/events.json scripts/core/random_event_manager.gd scripts/debug/test_spawn_gates_v2.gd
git commit -m "feat(events): landslide seal and gate wager one-night overrides"
```

---

### Task 7: 地图标记动态同步 + 活跃/沉默两态 + 角标

**Files:**
- Modify: `scripts/map/map_manager.gd`（`_refresh_world_markers`:391-406 重写 + 新增 `_ready` 与状态刷新）
- Modify: `scripts/map/spawn_point_view.gd`
- Modify: `scripts/debug/test_spawn_gates_v2.gd`

- [ ] **Step 1: 写失败测试（追加 `_test_markers()`，boot 模式）**

```gdscript
func _test_markers() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	var spawn_root := game.get_node_or_null("World/SpawnRoot")
	if run_state == null or map_manager == null or spawn_root == null:
		_expect(false, "boot ok for marker test")
		game.queue_free()
		await process_frame
		return
	var keys: Array = map_manager.get_spawn_keys()
	var visible_markers: Dictionary = {}
	for child in spawn_root.get_children():
		if child is Node2D and (child as Node2D).visible:
			visible_markers[String(child.get("spawn_key"))] = child
	for raw_key: Variant in keys:
		_expect(visible_markers.has(String(raw_key)), "marker visible for gate %s" % String(raw_key))
	var active: Array = ResolverScript.resolve_active_gates(keys, int(run_state.random_seed), int(run_state.day), [], [])
	for raw_key2: Variant in keys:
		var key := String(raw_key2)
		var marker: Node2D = visible_markers.get(key)
		if marker == null:
			continue
		if active.has(key):
			_expect(marker.modulate.a > 0.9, "active marker bright: %s" % key)
		else:
			_expect(marker.modulate.a < 0.9, "silent marker dimmed: %s" % key)
	# 封口后角标与状态刷新。
	var victim := String(active[0])
	run_state.add_night_gate_closed(victim)
	await process_frame
	var victim_marker: Node2D = visible_markers.get(victim)
	_expect(victim_marker != null and victim_marker.modulate.a < 0.9, "sealed marker dimmed")
	var label := victim_marker.get_node_or_null("%SpawnLabel") as Label
	_expect(label != null and label.text.contains("封"), "sealed marker badge")
	run_state.clear_night_gate_overrides()
	game.queue_free()
	await process_frame
```

- [ ] **Step 2: 跑测试确认失败**（S4/S5 无标记节点 → marker visible 断言失败）

- [ ] **Step 3: 实现**

`scripts/map/spawn_point_view.gd` 追加：

```gdscript
const ACTIVE_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const SILENT_MODULATE := Color(0.6, 0.6, 0.65, 0.55)


## 活跃/沉默两态 + 当晚变化角标（封/开）。标记常显（穿透迷雾）由 map_manager 保证。
func set_gate_state(active: bool, badge: String = "") -> void:
	modulate = ACTIVE_MODULATE if active else SILENT_MODULATE
	var label := get_node_or_null("%SpawnLabel") as Label
	if label == null:
		return
	var base := String(spawn_key)
	label.text = base if badge.is_empty() else "%s·%s" % [base, badge]
```

`scripts/map/map_manager.gd`：顶部加 `const SPAWN_POINT_SCENE := preload("res://scenes/world/SpawnPoint.tscn")` 与 `const NightTemplateResolver = preload("res://scripts/enemy/night_template_resolver.gd")`；新增 `_ready`：

```gdscript
func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	event_bus.day_started.connect(_on_day_started_refresh_markers)
	event_bus.night_gate_overrides_changed.connect(_refresh_world_markers)


func _on_day_started_refresh_markers(_day: int) -> void:
	_refresh_world_markers()
```

`_refresh_world_markers` 的 spawn 段整体替换（核心段保留）：

```gdscript
	if _spawn_root == null:
		return
	var keys: Array[String] = get_spawn_keys()
	var views_by_key: Dictionary = {}
	for child in _spawn_root.get_children():
		if not (child is Node2D):
			continue
		var child_key := String(child.get("spawn_key")) if child.get("spawn_key") != null else ""
		views_by_key[child_key] = child
	for key in keys:
		var view: Node2D = views_by_key.get(key)
		if view == null:
			# Game.tscn 仅预置 3 个标记节点，5 口需要动态补齐。
			view = SPAWN_POINT_SCENE.instantiate() as Node2D
			view.set("spawn_key", StringName(key))
			_spawn_root.add_child(view)
			views_by_key[key] = view
		# 出怪口标记穿透迷雾常显（设计稿 §3.3）：格子保持未探索，仅标记可见，
		# 探索扩展约束与事件前沿落点都依赖 discovered，不得把出怪格置为已探索。
		view.visible = true
		view.global_position = cell_to_world(get_spawn_cell_by_key(StringName(key)))
	for stale_key_variant: Variant in views_by_key.keys():
		var stale_key := String(stale_key_variant)
		if not keys.has(stale_key):
			(views_by_key[stale_key] as Node2D).visible = false
	_refresh_gate_marker_states(keys, views_by_key)


func _refresh_gate_marker_states(keys: Array[String], views_by_key: Dictionary) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	var closed: Array = run_state.night_gate_closed_keys
	var extra: Array = run_state.night_gate_extra_open_keys
	var active: Array = NightTemplateResolver.resolve_active_gates(keys, int(run_state.random_seed), int(run_state.day), closed, extra)
	for key in keys:
		var view: Node2D = views_by_key.get(key)
		if view == null or not view.has_method("set_gate_state"):
			continue
		var badge := ""
		if closed.has(key):
			badge = "封"
		elif extra.has(key):
			badge = "开"
		view.set_gate_state(active.has(String(key)), badge)
```

注意：RunState 字段在启动早期（reset 前）可能未初始化日数——`resolve_active_gates` 对 day=0 走表回退（day1 档），无须特判。

- [ ] **Step 4: 跑测试确认通过 + 回归 test_night_waves_affixes（其中有标记可见性断言）**
- [ ] **Step 5: Commit**

```bash
git add scripts/map/map_manager.gd scripts/map/spawn_point_view.gd scripts/debug/test_spawn_gates_v2.gd
git commit -m "feat(map): dynamic gate markers with active and silent states"
```

---

### Task 8: 封口弹窗 + 预览活跃口行 + 黎明公告

**Files:**
- Modify: `scripts/ui/map_interaction_popup.gd`（`_refresh_content`:93-113 前段重排 + 懒建 gate 段）
- Modify: `scripts/ui/combat/combat_hud.gd`（懒建 ActiveGatesLine）
- Modify: `scripts/ui/combat/combat_hud_controller.gd`（day_started 公告 + overrides 刷新）
- Modify: `scripts/debug/test_spawn_gates_v2.gd`

- [ ] **Step 1: 写失败测试（追加 `_test_gate_ui()`，boot 模式）**

```gdscript
func _test_gate_ui() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	var event_bus = root.get_node_or_null("EventBus")
	var popup := game.find_child("MapInteractionPopup", true, false) as Control
	if run_state == null or map_manager == null or event_bus == null or popup == null:
		_expect(false, "boot ok for gate ui test (popup node name?)")
		game.queue_free()
		await process_frame
		return
	var keys: Array = map_manager.get_spawn_keys()
	var active: Array = ResolverScript.resolve_active_gates(keys, int(run_state.random_seed), int(run_state.day), [], [])
	var gate_cell: Vector2i = map_manager.get_spawn_cell_by_key(StringName(String(active[0])))
	event_bus.map_cell_clicked.emit(gate_cell)
	await process_frame
	_expect(popup.is_visible_in_tree(), "popup opens on undiscovered gate cell")
	var seal_button := popup.find_child("GateSealButton", true, false) as Button
	_expect(seal_button != null and seal_button.visible, "seal button present for active gate")
	# 预览活跃口行：combat_hud 暴露 set_active_gates_line 后由 controller 喂入。
	var hud := game.get_node_or_null("UI/ScreenLayout/CombatHudSlot/CombatHud")
	_expect(hud != null and hud.has_method("set_active_gates_line"), "hud exposes active gates line")
	if hud != null and hud.has_method("set_active_gates_line"):
		hud.set_active_gates_line("今晚活跃口：S1 S2")
		var line := (hud as Node).find_child("ActiveGatesLine", true, false) as Label
		_expect(line != null and line.visible and line.text.contains("活跃口"), "active gates line renders")
	game.queue_free()
	await process_frame
```

- [ ] **Step 2: 跑测试确认失败**（弹窗对未探索口格直接 return false；GateSealButton/接口不存在）

- [ ] **Step 3: 实现**

`map_interaction_popup.gd`：
1. `_refresh_content` 头部重排——`is_inside` 检查后、`is_discovered` 检查前插入 gate 分支：

```gdscript
	if not map_manager.is_inside(_current_cell):
		return false
	# 出怪口格永不探索但标记常显，封堵入口必须先于 discovered 检查。
	var gate_key := StringName()
	if map_manager.has_method("get_spawn_key_at_cell"):
		gate_key = map_manager.get_spawn_key_at_cell(_current_cell)
	if gate_key != StringName():
		_title_label.text = "出怪口 %s" % String(gate_key)
		_event_section.visible = false
		_resource_section.visible = false
		_building_section.visible = false
		_clear_building_range_preview()
		_refresh_gate_section(String(gate_key))
		return true
	_set_gate_section_visible(false)
	if not map_manager.is_discovered(_current_cell):
		return false
```

（原有 `is_inside or is_discovered` 合并判断拆开；其余流程不动。）
2. 懒建 gate 段 + 行为：

```gdscript
const GATE_SEAL_STONE_COST := 4
const GATE_SEAL_AP_COST := 6

var _gate_section: VBoxContainer = null
var _gate_info_label: Label = null
var _gate_seal_button: Button = null
var _current_gate_key := ""


func _ensure_gate_section() -> void:
	if _gate_section != null:
		return
	var content := get_node_or_null("ContentMargin/VBoxContainer") as VBoxContainer
	if content == null:
		return
	_gate_section = VBoxContainer.new()
	_gate_section.name = "GateSection"
	_gate_info_label = Label.new()
	_gate_info_label.name = "GateInfoLabel"
	_gate_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gate_section.add_child(_gate_info_label)
	_gate_seal_button = Button.new()
	_gate_seal_button.name = "GateSealButton"
	_gate_seal_button.text = "封堵一晚（石 %d · 行动力 %d）" % [GATE_SEAL_STONE_COST, GATE_SEAL_AP_COST]
	_gate_seal_button.pressed.connect(_on_seal_gate_pressed)
	_gate_section.add_child(_gate_seal_button)
	content.add_child(_gate_section)
	content.move_child(_gate_section, 1)


func _set_gate_section_visible(value: bool) -> void:
	if _gate_section != null:
		_gate_section.visible = value


func _refresh_gate_section(gate_key: String) -> void:
	_ensure_gate_section()
	if _gate_section == null:
		return
	_current_gate_key = gate_key
	_gate_section.visible = true
	var run_state = AppRefs.run_state()
	var day_manager := _get_day_manager()
	var status_lines: Array[String] = []
	var can_seal := false
	var reason := ""
	if run_state == null or day_manager == null or not day_manager.has_method("try_seal_spawn_gate"):
		reason = "封堵功能不可用"
	else:
		var map_manager := _get_map_manager()
		var keys: Array = map_manager.get_spawn_keys() if map_manager != null else []
		var resolver := preload("res://scripts/enemy/night_template_resolver.gd")
		var active: Array = resolver.resolve_active_gates(keys, int(run_state.random_seed), int(run_state.day), run_state.night_gate_closed_keys, run_state.night_gate_extra_open_keys)
		var is_active: bool = active.has(gate_key)
		status_lines.append("今晚状态：%s" % ("活跃" if is_active else "沉默"))
		if (run_state.night_gate_closed_keys as Array).has(gate_key):
			status_lines.append("已封堵一晚，黎明解封")
		if not is_active:
			reason = "沉默口无需封堵"
		elif active.size() <= 1:
			reason = "至少保留一个活跃口"
		elif int(run_state.night_gate_seals_today) >= 1:
			reason = "今天已封堵过出怪口"
		elif int(run_state.stone) < GATE_SEAL_STONE_COST:
			reason = "石材不足"
		elif int(run_state.action_points) < GATE_SEAL_AP_COST:
			reason = "行动力不足"
		else:
			can_seal = true
	status_lines.append("封堵后总刷怪量不变，怪物改道其他活跃口。")
	if not reason.is_empty():
		status_lines.append(reason)
	_gate_info_label.text = "\n".join(status_lines)
	_gate_seal_button.disabled = not can_seal or _current_phase != GameEnums.PHASE_DAY


func _on_seal_gate_pressed() -> void:
	var day_manager := _get_day_manager()
	if day_manager == null or not day_manager.has_method("try_seal_spawn_gate"):
		return
	var result: Dictionary = day_manager.try_seal_spawn_gate(_current_cell)
	_message_label.text = String(result.get("message", ""))
	_refresh_or_hide()
```

注意 `_refresh_or_hide` 走 `_refresh_content`，gate 格会重新进 gate 分支刷新状态。AppTheme 已对整个 popup 应用，动态控件继承主题。
3. `_refresh_content` 原 `return false`（无资源无建筑）路径前补 `_set_gate_section_visible(false)`；`_show_for_current_cell` 不变。

`combat_hud.gd` 追加（参照 NightAffixRow 的懒建模式，挂到夜晚预览卡片容器上方——实现时 grep `_rebuild_wave_spawn_cards_by_wave` 找容器引用，把 Label 插到该容器父级第 0 位）：

```gdscript
var _active_gates_line: Label = null


func set_active_gates_line(text: String) -> void:
	if _active_gates_line == null:
		var host := _wave_cards_container().get_parent() as Control
		if host == null:
			return
		_active_gates_line = Label.new()
		_active_gates_line.name = "ActiveGatesLine"
		_active_gates_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		host.add_child(_active_gates_line)
		host.move_child(_active_gates_line, 0)
	_active_gates_line.text = text
	_active_gates_line.visible = not text.is_empty()
```

（`_wave_cards_container()` 为实现期确认的既有容器访问器；若无，按 `_rebuild_wave_spawn_cards_by_wave` 实际使用的节点引用替换。）

`combat_hud_controller.gd`：
1. `_on_day_started` 与预览刷新处（v1 的 `_refresh_wave_preview` 一族）计算并喂入活跃口行 + 黎明公告：

```gdscript
func _refresh_active_gates_line() -> void:
	var run_state = AppRefs.run_state()
	if run_state == null or _combat_hud == null or not _combat_hud.has_method("set_active_gates_line"):
		return
	var map_manager := _get_map_manager()
	if map_manager == null or not map_manager.has_method("get_spawn_keys"):
		return
	var keys: Array = map_manager.get_spawn_keys()
	var resolver := preload("res://scripts/enemy/night_template_resolver.gd")
	var active: Array = resolver.resolve_active_gates(keys, int(run_state.random_seed), int(run_state.day), run_state.night_gate_closed_keys, run_state.night_gate_extra_open_keys)
	var closed: Array = run_state.night_gate_closed_keys
	var text := "今晚活跃口：%s" % " ".join(PackedStringArray(active))
	if not closed.is_empty():
		text += "（%s 已封堵）" % " ".join(PackedStringArray(closed))
	_combat_hud.set_active_gates_line(text)
```

2. 黎明扩张公告（`_on_day_started` 内）：

```gdscript
	var resolver := preload("res://scripts/enemy/night_template_resolver.gd")
	var map_manager := _get_map_manager()
	if map_manager != null and map_manager.has_method("get_spawn_keys"):
		var keys: Array = map_manager.get_spawn_keys()
		var run_state_for_gates = AppRefs.run_state()
		if run_state_for_gates != null and _day > 1:
			var today: Array = resolver.resolve_active_gates(keys, int(run_state_for_gates.random_seed), _day)
			var yesterday: Array = resolver.resolve_active_gates(keys, int(run_state_for_gates.random_seed), _day - 1)
			for raw_gate: Variant in today:
				if not yesterday.has(String(raw_gate)):
					_show_message("战线扩张：%s 今晚加入进攻" % String(raw_gate))
	_refresh_active_gates_line()
```

3. `_ready` 的事件绑定区追加 `event_bus.night_gate_overrides_changed.connect(_refresh_active_gates_line)`（同时触发预览重建，若预览有独立刷新函数一并调用）。
（`_get_map_manager`/`_combat_hud`/`_day` 等访问器名以 controller 实际代码为准，实现时对齐。）

- [ ] **Step 4: 跑测试确认通过 + 回归 test_contract_events（弹窗族）与 test_night_template_flow（预览 UI 族）**
- [ ] **Step 5: Commit**

```bash
git add scripts/ui/map_interaction_popup.gd scripts/ui/combat/combat_hud.gd scripts/ui/combat/combat_hud_controller.gd scripts/debug/test_spawn_gates_v2.gd
git commit -m "feat(ui): gate seal popup, active gates line and dawn expansion notice"
```

---

### Task 9: 文档同步 + 全量回归

**Files:**
- Modify: `docs/DATA_SCHEMA.md`（map_generation 新键、events 新条目、ACTIVE_COUNT_BY_DAY 说明）
- Modify: `docs/肉鸽构筑与战斗优化方案.md` §8.1（P2-4 v2 标记完成，剩余项更新）

- [ ] **Step 1: 文档更新**——DATA_SCHEMA：`spawn_count`/`spawn_corner_margin`/`spawn_arc_center_ratio` 键说明 + 删除两个废键的记录；事件表追加塌方/开口赌约；夜晚解析节补"激活序/活跃集/一夜覆盖项"。方案文档 §8.1：P2-4 v2 落地说明（已实现项 + 显式延期项：异动警报事件、地形耦合）。
- [ ] **Step 2: 全量回归（八套件 + 启动）**

Run（逐个）: test_wave_templates / test_night_waves_affixes / test_night_template_flow / test_relic_draw / test_contract_events / test_shop_lock_drift / test_targeted_star_up / test_spawn_gates_v2
Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5` （BOOT 检查无报错）
Expected: 全 PASSED + 启动干净

- [ ] **Step 3: Commit**

```bash
git add docs/DATA_SCHEMA.md docs/肉鸽构筑与战斗优化方案.md
git commit -m "docs(night): document spawn gates v2 schema and progress"
```

---

## 自审记录

- **规格覆盖**：§2.1→Task1；§2.2→Task2；§2.3→Task3;§2.4→Task5+8；§2.5→Task6（异动警报按规格"可选做"显式延期，记入 Task9 文档）；§2.6→Task4；§3 UI 六项→Task7+8（路线迷雾裁剪与词缀横幅为"不动"项）；§4→各任务测试+Task9 回归。
- **类型一致性**：resolver 新函数签名在 Task2 定义，Task4/5/6/7/8 调用处一致（all_gates: Array, run_seed: int, day: int, closed: Array, extra_open: Array）；RunState 字段名三处一致。
- **已知实现期自由度**（非占位符，是对既有代码的对齐点，子代理执行时按真实代码微调）：popup 节点名（find_child "MapInteractionPopup"）、combat_hud 卡片容器访问器、controller 的 day_started 形参名、`mark_event_triggered` 实名。
