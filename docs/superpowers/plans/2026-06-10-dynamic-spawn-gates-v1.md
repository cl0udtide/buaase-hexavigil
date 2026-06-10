# 动态出怪口 v1（模板组化 + lane 角色分配）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把波次模板与出怪口解耦——模板内条目改带 lane 角色（main/flank/any），每波主攻口清晨 seeded 结算并公示；同步补齐预览按波分段展示、出怪口标记穿透迷雾、夜间词缀清单三项 UI。

**Architecture:** 纯静态的口分配函数加在 `NightTemplateResolver`（可脱离场景树测试）；`wave_manager._build_resolved_entries` 在 enemy_choices 解析之后、词缀 transform 之前把 lane 解析为具体 `spawn_key`，预览与运行时共用同一条路径保证"公示即契约"；UI 消费 `get_night_preview()` 新增的 per-wave 字段。数据层 `entries`→`groups` 为机械迁移，代码同时兼容两种字段名。

**Tech Stack:** Godot 4 / GDScript，headless 回归用 `extends SceneTree` 模式（见 `scripts/debug/test_*.gd`）。

**分支：** 按用户要求直接在当前分支 `fix/map-popup-floating-layer` 上执行。规格见 `docs/superpowers/specs/2026-06-10-dynamic-spawn-gates-design.md`。

**通用验证命令**（每个任务的"运行测试"步骤都用这套，`$GODOT` = `/Applications/Godot.app/Contents/MacOS/Godot`）：

```bash
$GODOT --headless --path . --script scripts/debug/test_night_waves_affixes.gd
$GODOT --headless --path . --script scripts/debug/test_wave_templates.gd
$GODOT --headless --path . --script scripts/debug/test_night_template_flow.gd
$GODOT --headless --path . --script scripts/debug/test_relic_draw.gd
$GODOT --headless --path . --script scripts/debug/test_contract_events.gd
```

已知基线（2026-06-10 实测修正）：`test_night_template_flow.gd` 当前全绿（早前记录的 1 个 UI 失败项已不复现）；`test_wave_templates.gd` 的 `_check_resolver` 曾有 3 条沿用单波语义的过时断言，已在 Task 1 评审修复中改为首波语义。各任务 Expected 一律以全套件全绿为准。

GDScript 注意（来自 AGENTS.md）：项目把部分 warning 当 error——`max()`/`min()` 结果、字典/数组读取后的变量要显式标注类型；不要依赖 Variant 推断。

---

### Task 1: NightTemplateResolver 口分配静态函数

**Files:**
- Modify: `scripts/enemy/night_template_resolver.gd`（文件末尾追加）
- Test: `scripts/debug/test_night_waves_affixes.gd`

- [ ] **Step 1: 写失败测试**

在 `test_night_waves_affixes.gd` 的 `_run()` 中 `_test_resolver_plan()` 之后插入一行 `_test_gate_assignment()`，并在 `_test_affix_resolution()` 函数定义之前添加：

```gdscript
func _test_gate_assignment() -> void:
	var gates: Array = ["S1", "S2", "S3"]
	var main_a: String = Resolver.resolve_main_gate(gates, 42, 3, 0)
	var main_b: String = Resolver.resolve_main_gate(gates, 42, 3, 0)
	_expect(main_a == main_b, "main gate is deterministic")
	_expect(gates.has(main_a), "main gate is an active gate")
	var main_wave1: String = Resolver.resolve_main_gate(gates, 42, 3, 1)
	_expect(gates.has(main_wave1), "wave1 main gate is an active gate")
	# 不同 seed 下主攻口应该会变（扫几个 seed 至少出现两种结果）
	var seen: Dictionary = {}
	for probe_seed in range(20):
		seen[Resolver.resolve_main_gate(gates, probe_seed, 3, 0)] = true
	_expect(seen.size() >= 2, "main gate varies across seeds")

	_expect(Resolver.resolve_lane_gate(&"main", 0, main_a, gates, 42, 3, 0) == main_a, "lane main goes to main gate")
	for group_index in range(8):
		var flank_gate: String = Resolver.resolve_lane_gate(&"flank", group_index, main_a, gates, 42, 3, 0)
		_expect(flank_gate != main_a, "flank avoids main gate (group %d)" % group_index)
		_expect(gates.has(flank_gate), "flank gate is active (group %d)" % group_index)
		var any_gate: String = Resolver.resolve_lane_gate(&"any", group_index, main_a, gates, 42, 3, 0)
		_expect(gates.has(any_gate), "any gate is active (group %d)" % group_index)
	_expect(Resolver.resolve_lane_gate(&"flank", 0, main_a, gates, 42, 3, 0) == Resolver.resolve_lane_gate(&"flank", 0, main_a, gates, 42, 3, 0), "flank assignment deterministic")
	# 单口回退
	_expect(Resolver.resolve_lane_gate(&"flank", 0, "S1", ["S1"], 42, 3, 0) == "S1", "flank falls back to main when single gate")
	# 空口集合
	_expect(Resolver.resolve_main_gate([], 42, 3, 0) == "", "empty gates yield empty main")
```

- [ ] **Step 2: 运行确认失败**

Run: `$GODOT --headless --path . --script scripts/debug/test_night_waves_affixes.gd`
Expected: 报错（`resolve_main_gate` 不存在导致脚本解析失败或 FAIL 输出）。

- [ ] **Step 3: 实现**

在 `night_template_resolver.gd` 文件末尾追加：

```gdscript
## ---- 出怪口分配：lane 角色 -> 具体 spawn_key ----
## 设计稿见 docs/superpowers/specs/2026-06-10-dynamic-spawn-gates-design.md §3-§4。
## 纯静态、确定性：同 (run_seed, day, wave_index) 输入永远得到同样结果，预览即契约。

const LANE_MAIN: StringName = &"main"
const LANE_FLANK: StringName = &"flank"
const LANE_ANY: StringName = &"any"


static func _sorted_gates(active_gates: Array) -> Array[String]:
	var gates: Array[String] = []
	for raw_gate: Variant in active_gates:
		var gate := String(raw_gate)
		if not gate.is_empty() and not gates.has(gate):
			gates.append(gate)
	gates.sort()
	return gates


## 该波的主攻口：在活跃口中等权抽取。
static func resolve_main_gate(active_gates: Array, run_seed: int, day: int, wave_index: int) -> String:
	var gates := _sorted_gates(active_gates)
	if gates.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("gate|%d|%d|%d" % [run_seed, day, wave_index]).hash())
	return gates[rng.randi() % gates.size()]


## 按 lane 给一个组分配落口。flank 从非主攻口中独立抽取（单口时回退主攻口），any 全口等权。
static func resolve_lane_gate(lane: StringName, group_index: int, main_gate: String, active_gates: Array, run_seed: int, day: int, wave_index: int) -> String:
	var gates := _sorted_gates(active_gates)
	if gates.is_empty():
		return main_gate
	match lane:
		LANE_MAIN:
			return main_gate
		LANE_FLANK:
			var others: Array[String] = []
			for gate in gates:
				if gate != main_gate:
					others.append(gate)
			if others.is_empty():
				return main_gate
			var rng := RandomNumberGenerator.new()
			rng.seed = abs(("lane|%d|%d|%d|%d|flank" % [run_seed, day, wave_index, group_index]).hash())
			return others[rng.randi() % others.size()]
		_:
			var rng_any := RandomNumberGenerator.new()
			rng_any.seed = abs(("lane|%d|%d|%d|%d|any" % [run_seed, day, wave_index, group_index]).hash())
			return gates[rng_any.randi() % gates.size()]
```

- [ ] **Step 4: 运行确认通过**

Run: `$GODOT --headless --path . --script scripts/debug/test_night_waves_affixes.gd`
Expected: `NIGHT WAVES AFFIXES TESTS PASSED`

- [ ] **Step 5: 提交**

```bash
git add scripts/enemy/night_template_resolver.gd scripts/debug/test_night_waves_affixes.gd
git commit -m "feat(night): add seeded lane-to-gate assignment resolvers"
```

---

### Task 2: wave_manager 接线（兼容双 schema，数据未迁移时行为不变）

**Files:**
- Modify: `scripts/enemy/wave_manager.gd`
- Modify: `scripts/map/map_manager.gd`（新增 `get_spawn_keys()`）
- Test: `scripts/debug/test_night_waves_affixes.gd`（`_test_game_boot` 内追加断言）

此任务完成后：旧数据（带 `spawn_key` 的 `entries`）行为完全不变；带 `lane` 的条目会被解析出 `spawn_key`。预览新增 per-wave 字段。

- [ ] **Step 1: 写失败测试**

在 `_test_game_boot()` 中 `_expect(int(affixed_preview.get("total_count", 0)) > 0, ...)` 之后追加：

```gdscript
		# --- 动态出怪口 v1：预览暴露 per-wave 主攻口与条目 ---
		var preview_repeat: Dictionary = wave_manager.get_night_preview(late_plan, [&"forced_march", &"spawn_surge"])
		_expect(str(preview_repeat) == str(affixed_preview), "night preview fully deterministic")
		var wave_infos: Array = affixed_preview.get("waves", [])
		_expect(not wave_infos.is_empty(), "preview has wave summaries")
		var active_gate_keys: Array = []
		var map_manager := game.get_node_or_null("Managers/MapManager")
		_expect(map_manager != null, "MapManager exists")
		if map_manager != null and map_manager.has_method("get_spawn_keys"):
			active_gate_keys = map_manager.get_spawn_keys()
		_expect(active_gate_keys.size() >= 2, "map exposes spawn keys")
		for raw_wave: Variant in wave_infos:
			if typeof(raw_wave) != TYPE_DICTIONARY:
				continue
			var wave_info: Dictionary = raw_wave
			var main_gate := String(wave_info.get("main_gate", ""))
			_expect(active_gate_keys.has(main_gate), "wave main gate is active gate")
			var wave_entries: Array = wave_info.get("entries", [])
			_expect(not wave_entries.is_empty(), "wave summary carries entries")
			for raw_entry: Variant in wave_entries:
				if typeof(raw_entry) != TYPE_DICTIONARY:
					continue
				var wave_entry: Dictionary = raw_entry
				_expect(active_gate_keys.has(String(wave_entry.get("spawn_key", ""))), "entry spawn key is active gate")
				if StringName(wave_entry.get("lane", "")) == &"flank" and active_gate_keys.size() >= 2:
					_expect(String(wave_entry.get("spawn_key", "")) != main_gate, "flank entry avoids main gate")
```

注意：此时模板还是 `spawn_key` 写死的旧数据，`main_gate` / `lane` 断言会 FAIL——这正是本任务要实现的（`main_gate` 字段在本任务落地；`lane` 断言在 Task 3 数据迁移后才真正生效，迁移前没有 flank 条目，循环体不会触发）。

- [ ] **Step 2: 运行确认失败**

Run: `$GODOT --headless --path . --script scripts/debug/test_night_waves_affixes.gd`
Expected: FAIL 项包含 "wave main gate is active gate"、"wave summary carries entries"、"map exposes spawn keys"。

- [ ] **Step 3: map_manager 新增 get_spawn_keys()**

在 `scripts/map/map_manager.gd` 的 `get_spawn_cell_by_key()`（约 337 行）之后添加：

```gdscript
func get_spawn_keys() -> Array[String]:
	var keys: Array[String] = []
	for cell in _spawn_cells:
		var data := get_cell_data(cell)
		if data != null and data.spawn_key != StringName():
			keys.append(String(data.spawn_key))
	keys.sort()
	return keys
```

- [ ] **Step 4: wave_manager 接入 lane 解析与 per-wave 预览字段**

对 `scripts/enemy/wave_manager.gd` 做四处修改：

(a) 新增两个辅助函数（放在 `_entry_transform_seed()` 附近）：

```gdscript
func _active_spawn_keys() -> Array:
	if _map_manager != null and _map_manager.has_method("get_spawn_keys"):
		return _map_manager.get_spawn_keys()
	return []


func _main_gate_for_wave(wave_index: int, active_gates: Array) -> String:
	var run_state = AppRefs.run_state()
	var run_seed := int(run_state.random_seed) if run_state != null else 0
	var day := int(run_state.day) if run_state != null else 0
	return NightTemplateResolver.resolve_main_gate(active_gates, run_seed, day, wave_index)
```

(b) 改写 `_build_resolved_entries()`（保持函数签名不变）：

```gdscript
## 一波的最终条目：groups/entries 读取 -> enemy_choices 解析 -> lane 落口分配 -> 词缀条目级变换。
## 运行时与预览共用，保证公示诚实。lane 解析必须在词缀 transform 之前（spawn_surge 等按 spawn_key 结算）。
func _build_resolved_entries(cfg: Dictionary, template_id: StringName, wave_index: int, affix_cfgs: Array) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	var raw_entries: Array = cfg.get("groups", cfg.get("entries", []))
	var seed_day := _seed_day_for(template_id)
	var active_gates: Array = _active_spawn_keys()
	var main_gate := _main_gate_for_wave(wave_index, active_gates)
	var run_state = AppRefs.run_state()
	var run_seed := int(run_state.random_seed) if run_state != null else 0
	var day := int(run_state.day) if run_state != null else 0
	for entry_index in range(raw_entries.size()):
		var entry_variant: Variant = raw_entries[entry_index]
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = _resolve_wave_entry(entry_variant as Dictionary, seed_day, entry_index)
		if StringName(entry.get("enemy_id", "")) == StringName():
			continue
		if String(entry.get("spawn_key", "")).is_empty():
			var lane := StringName(String(entry.get("lane", "any")))
			entry["spawn_key"] = NightTemplateResolver.resolve_lane_gate(lane, entry_index, main_gate, active_gates, run_seed, day, wave_index)
		resolved.append(entry)
	if affix_cfgs.is_empty():
		return resolved
	var spawn_keys: Array = _collect_spawn_keys(resolved)
	return NightAffixService.transform_entries(resolved, affix_cfgs, spawn_keys, _entry_transform_seed(template_id, wave_index))
```

(c) `_build_wave_preview()`：在 `entries_by_key[aggregate_key] = {` 的字典里加一行 `"lane": StringName(String(entry.get("lane", ""))),`（放在 `"spawn_key": spawn_key,` 之后）；在函数末尾 `var preview := {` 字典里加一行 `"main_gate": _main_gate_for_wave(wave_index, _active_spawn_keys()),`（放在 `"total_count": total_count` 之前，注意给前一行补逗号）。

(d) `get_night_preview()`：`wave_summaries.append({...})` 的字典追加三个键：

```gdscript
			"main_gate": String(wave_preview.get("main_gate", "")),
			"spawn_order": wave_preview.get("spawn_order", []),
			"entries": wave_preview.get("entries", []),
```

- [ ] **Step 5: 运行确认通过（含解析检查）**

```bash
$GODOT --headless --path . --check-only --script scripts/enemy/wave_manager.gd
$GODOT --headless --path . --check-only --script scripts/map/map_manager.gd
$GODOT --headless --path . --script scripts/debug/test_night_waves_affixes.gd
$GODOT --headless --path . --script scripts/debug/test_wave_templates.gd
```
Expected: 全部 PASSED（旧数据路径不受影响）。

- [ ] **Step 6: 提交**

```bash
git add scripts/enemy/wave_manager.gd scripts/map/map_manager.gd scripts/debug/test_night_waves_affixes.gd
git commit -m "feat(night): resolve lane roles to spawn gates in wave pipeline"
```

---

### Task 3: 数据迁移（entries→groups、spawn_key→lane）

**Files:**
- Modify: `data/wave_templates.json`（15 个模板全部迁移）
- Modify: `scripts/debug/test_wave_templates.gd`（schema 校验改写）

- [ ] **Step 1: 先改 schema 测试（失败测试）**

`test_wave_templates.gd` `_check_data()` 中：

把 `var valid_spawns := {"S1": true, "S2": true, "S3": true}` 替换为：

```gdscript
	var valid_lanes := {"main": true, "flank": true, "any": true}
```

把 `var entries: Array = template.get("entries", [])` 起到 `_expect(float(entry.get("interval", -1.0)) >= 0.0, ...)` 为止的条目校验块替换为：

```gdscript
		var groups: Array = template.get("groups", [])
		_expect(groups.size() > 0, "%s has groups" % id)
		_expect(not template.has("entries"), "%s legacy entries removed" % id)
		var main_count := 0
		for group_variant: Variant in groups:
			_expect(typeof(group_variant) == TYPE_DICTIONARY, "%s group is dict" % id)
			if typeof(group_variant) != TYPE_DICTIONARY:
				continue
			var group: Dictionary = group_variant
			var enemy_id := StringName(group.get("enemy_id", ""))
			var choices: Array = group.get("enemy_choices", [])
			if enemy_id != StringName():
				_expect(enemy_ids.has(enemy_id), "%s enemy_id valid: %s" % [id, enemy_id])
			else:
				_expect(not choices.is_empty(), "%s has enemy_id or enemy_choices" % id)
				for choice_variant: Variant in choices:
					if typeof(choice_variant) == TYPE_DICTIONARY:
						var choice: Dictionary = choice_variant
						_expect(enemy_ids.has(StringName(choice.get("enemy_id", ""))), "%s enemy_choice valid" % id)
			_expect(not group.has("spawn_key"), "%s group has no hardcoded spawn_key" % id)
			var lane := String(group.get("lane", ""))
			_expect(valid_lanes.has(lane), "%s lane valid: %s" % [id, lane])
			if lane == "main":
				main_count += 1
			_expect(int(group.get("count", 0)) > 0, "%s count positive" % id)
			_expect(float(group.get("time", -1.0)) >= 0.0, "%s time non-negative" % id)
			_expect(float(group.get("interval", -1.0)) >= 0.0, "%s interval non-negative" % id)
		_expect(main_count >= 1, "%s has at least one main group" % id)
```

- [ ] **Step 2: 运行确认失败**

Run: `$GODOT --headless --path . --script scripts/debug/test_wave_templates.gd`
Expected: 每个模板 FAIL "has groups"。

- [ ] **Step 3: 迁移 JSON 数据**

对 `data/wave_templates.json` 每个模板：键 `"entries"` 改名 `"groups"`；每条记录删除 `"spawn_key": "Sx"`，按下表在 `"enemy_id"` 之后插入 `"lane": "..."`。其余字段（time/count/interval）一律不动。lane 判定已按"Boss 固定 main、远程/飞行骚扰 flank、杂兵 any、main 占多数"的规格约定逐条审定：

| 模板 | 各组 lane（按 time 顺序） |
|---|---|
| slug_tide | slime→any, hound→main, hound_pro→main, lumberjack_veteran→flank |
| moonlit_hounds | hound→main, crossbowman→flank, hound→any, armored_soldier→main |
| nightfall_axe | hound→any, soldier→main, crossbowman→flank, lumberjack_veteran→main |
| swarming_assault | slime→any, originium_slug_alpha→main, bat→flank, infused_originium_slug→main |
| arts_eclipse | soldier→main, caster→flank, armored_soldier→main, shieldguard→any |
| locust_swarm | crossbowman→main, dualstrike_swordsman→main, crossbowman→flank, caster→flank |
| splitting_brood | hound_pro→any, splitting_originium_slug→main, dualstrike_swordsman→main, infused_originium_slug→flank |
| ironwall_advance | hound_pro→any, dualstrike_swordsman→main, demolitionist→flank, siege_breaker→main |
| crossfire_volley | soldier→any, caster→flank, sarkaz_greatswordsman→main, demolitionist→flank |
| siege_breach | demolitionist→flank, shieldguard→main, heavy_defender→main, siege_breaker→main |
| greatblade_abyss | bat→flank, splitting_originium_slug→any, possessed_soldier→main, sarkaz_greatswordsman→main |
| heavyplate_siege | slime→any, shieldguard→main, heavy_defender→main, senior_caster→flank |
| arts_cataclysm | caster→main, arts_drone→flank, senior_caster→main, infused_originium_slug→any |
| fiends_carnival | armored_soldier→main, crossbowman→flank, milk_dragon_chief→main, heavy_defender→main, caster→flank |
| twilight_triumph | shieldguard→main, crossbowman→flank, patriot→main, sarkaz_greatswordsman→main, caster→flank |

示例（slug_tide 迁移后）：

```json
    "groups": [
      { "time": 0.0, "enemy_id": "slime", "lane": "any", "count": 8, "interval": 0.45 },
      { "time": 3.0, "enemy_id": "hound", "lane": "main", "count": 8, "interval": 0.55 },
      { "time": 8.0, "enemy_id": "hound_pro", "lane": "main", "count": 2, "interval": 1.2 },
      { "time": 13.0, "enemy_id": "lumberjack_veteran", "lane": "flank", "count": 1, "interval": 0.0 }
    ]
```

- [ ] **Step 4: 运行全部相关套件确认通过**

```bash
$GODOT --headless --path . --script scripts/debug/test_wave_templates.gd
$GODOT --headless --path . --script scripts/debug/test_night_waves_affixes.gd
$GODOT --headless --path . --script scripts/debug/test_night_template_flow.gd
```
Expected: wave_templates 与 night_waves_affixes PASSED（此时 Task 2 写的 lane/flank 断言开始真正生效）；night_template_flow 全绿。

- [ ] **Step 5: 提交**

```bash
git add data/wave_templates.json scripts/debug/test_wave_templates.gd
git commit -m "feat(data): migrate wave templates to lane-based groups"
```

---

### Task 4: 出怪口标记穿透迷雾 + 探索/事件不变式

**Files:**
- Modify: `scripts/map/map_manager.gd:394`
- Test: `scripts/debug/test_night_waves_affixes.gd`（`_test_game_boot` 内追加）

- [ ] **Step 1: 写失败测试（不变式断言）**

在 `_test_game_boot()` 中 Task 2 添加的断言块之后追加：

```gdscript
		# --- 标记穿透迷雾：格子保持未探索（探索约束与事件前沿落点依赖此不变式） ---
		if map_manager != null and map_manager.has_method("get_spawn_cells"):
			var spawn_cells: Array = map_manager.get_spawn_cells()
			_expect(not spawn_cells.is_empty(), "map has spawn cells")
			for raw_cell: Variant in spawn_cells:
				var spawn_cell: Vector2i = raw_cell
				_expect(not map_manager.is_discovered(spawn_cell), "spawn cell stays undiscovered at start")
```

注意：这条断言在现状下就应通过（出怪点本来就 `discovered=false`），它的价值是把"标记可见 ≠ 格子已探索"锁成回归不变式，防止后续实现走捷径把格子设为已探索。先运行确认它是绿的，再改标记可见性，改完必须仍是绿的。

- [ ] **Step 2: 运行确认当前为绿**

Run: `$GODOT --headless --path . --script scripts/debug/test_night_waves_affixes.gd`
Expected: PASSED。

- [ ] **Step 3: 标记常显**

`scripts/map/map_manager.gd` `_refresh_world_markers()` 中，把：

```gdscript
		(child as Node2D).visible = is_discovered(spawn_cell)
```

替换为：

```gdscript
		# 出怪口标记穿透迷雾常显（设计稿 §3.3）：格子保持未探索，仅标记可见，
		# 探索扩展约束与事件前沿落点都依赖 discovered，不得把出怪格置为已探索。
		(child as Node2D).visible = true
```

- [ ] **Step 4: 运行确认仍为绿 + 启动检查**

```bash
$GODOT --headless --path . --check-only --script scripts/map/map_manager.gd
$GODOT --headless --path . --script scripts/debug/test_night_waves_affixes.gd
$GODOT --headless --path . --script scripts/debug/test_contract_events.gd
$GODOT --headless --path . --quit-after 5
```
Expected: 全部 PASSED / 正常退出（contract_events 覆盖事件落点逻辑，确认未受影响）。

- [ ] **Step 5: 提交**

```bash
git add scripts/map/map_manager.gd scripts/debug/test_night_waves_affixes.gd
git commit -m "feat(map): spawn gate markers visible through fog"
```

---

### Task 5: 预览 UI 按"波 × 口"分段展示

**Files:**
- Modify: `scripts/ui/combat/combat_hud.gd`

UI 为场景绑定逻辑，headless 难以断言渲染结果；本任务以解析检查 + 启动检查 + 任务 7 的人工清单验收。数据正确性已由 Task 2/3 的 headless 断言保证。

- [ ] **Step 1: 卡片标题支持主攻标注**

`combat_hud.gd` `_build_wave_spawn_card()` 改签名并标注主攻（保持旧调用兼容）：

```gdscript
func _build_wave_spawn_card(spawn_key: String, entries: Array, key_enemies: Dictionary, main_gate: String = "") -> Control:
	var card := _wave_spawn_card_template.duplicate() as PanelContainer
	card.name = "WaveSpawn%sCard" % spawn_key
	card.unique_name_in_owner = false
	card.visible = true
	var key_label := card.get_node_or_null("SpawnCardRow/SpawnKeyLabel") as Label
	key_label.text = "%s · 主攻" % spawn_key if spawn_key == main_gate and not main_gate.is_empty() else spawn_key
	key_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
```

（函数其余部分不动。）

- [ ] **Step 2: 新增按波分段重建函数**

在 `_rebuild_wave_spawn_cards()` 之后添加：

```gdscript
## 多波时按"波 × 口"分段展示（消费 get_night_preview 的 waves[].entries / main_gate）；
## 单波或缺 per-wave 数据时回退聚合卡片。
func _rebuild_wave_spawn_cards_by_wave(waves: Array, merged_spawn_order: Array, merged_entries: Array, raw_key_enemies: Variant) -> void:
	var usable_waves: Array[Dictionary] = []
	for wave_variant: Variant in waves:
		if typeof(wave_variant) != TYPE_DICTIONARY:
			continue
		var wave_info: Dictionary = wave_variant
		if not (wave_info.get("entries", []) as Array).is_empty():
			usable_waves.append(wave_info)
	if usable_waves.size() <= 1:
		_rebuild_wave_spawn_cards(merged_spawn_order, merged_entries, raw_key_enemies)
		return
	if _wave_spawn_cards_box == null or _wave_spawn_card_template == null or _wave_enemy_card_template == null:
		return
	for child in _wave_spawn_cards_box.get_children():
		child.queue_free()
	var key_enemies := _key_enemy_lookup(raw_key_enemies)
	for wave_info in usable_waves:
		var main_gate := String(wave_info.get("main_gate", ""))
		var header := Label.new()
		var header_text := "第 %d 波 · %s" % [int(wave_info.get("wave_index", 0)) + 1, String(wave_info.get("name", ""))]
		if not main_gate.is_empty():
			header_text += " · 主攻 %s" % main_gate
		header.text = header_text
		header.add_theme_color_override("font_color", GameUiStyle.AMBER)
		_wave_spawn_cards_box.add_child(header)
		var wave_entries: Array = wave_info.get("entries", [])
		var spawn_order: Array = wave_info.get("spawn_order", [])
		var entries_by_spawn: Dictionary = {}
		for raw_spawn: Variant in spawn_order:
			entries_by_spawn[String(raw_spawn)] = []
		for entry_variant: Variant in wave_entries:
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_variant
			var spawn_key := String(entry.get("spawn_key", ""))
			if spawn_key.is_empty():
				continue
			if not entries_by_spawn.has(spawn_key):
				entries_by_spawn[spawn_key] = []
			(entries_by_spawn[spawn_key] as Array).append(entry)
		for raw_spawn: Variant in spawn_order:
			var spawn_key := String(raw_spawn)
			var spawn_entries: Array = entries_by_spawn.get(spawn_key, [])
			_wave_spawn_cards_box.add_child(_build_wave_spawn_card(spawn_key, spawn_entries, key_enemies, main_gate))
```

- [ ] **Step 3: set_wave_preview_data 切换到按波重建**

`combat_hud.gd:533` 把：

```gdscript
	_rebuild_wave_spawn_cards(spawn_order, entries, data.get("key_enemies", []))
```

替换为：

```gdscript
	_rebuild_wave_spawn_cards_by_wave(data.get("waves", []), spawn_order, entries, data.get("key_enemies", []))
```

- [ ] **Step 4: 解析与启动检查**

```bash
$GODOT --headless --path . --check-only --script scripts/ui/combat/combat_hud.gd
$GODOT --headless --path . --script scripts/debug/test_night_template_flow.gd
$GODOT --headless --path . --quit-after 5
```
Expected: 解析无错；night_template_flow 全绿；启动正常。

- [ ] **Step 5: 提交**

```bash
git add scripts/ui/combat/combat_hud.gd
git commit -m "feat(ui): per-wave gate breakdown in night preview"
```

---

### Task 6: 夜间词缀清单常显

**Files:**
- Modify: `scripts/ui/combat/combat_hud.gd`（新增 banner 控件与 API）
- Modify: `scripts/ui/combat/combat_hud_controller.gd`（`_on_night_started` / `_on_phase_changed` 接线）

- [ ] **Step 1: combat_hud 新增夜间词缀行**

`combat_hud.gd` 成员变量区（`_wave_warning_label` 声明附近）添加：

```gdscript
var _night_affix_row: PanelContainer
var _night_affix_label: Label
```

在 `_ensure_level_intro_banner()` 之前添加：

```gdscript
## 夜间常显的当晚词缀清单（含事件临时追加项）。白天隐藏，由 controller 驱动。
func set_night_affixes(affixes: Array) -> void:
	_ensure_night_affix_row()
	if _night_affix_row == null:
		return
	var parts := PackedStringArray()
	var tips := PackedStringArray()
	for raw_affix: Variant in affixes:
		if typeof(raw_affix) != TYPE_DICTIONARY:
			continue
		var affix: Dictionary = raw_affix
		var affix_name := String(affix.get("name", "")).strip_edges()
		if affix_name.is_empty():
			continue
		parts.append(affix_name)
		tips.append("【%s】%s" % [affix_name, String(affix.get("desc", "")).strip_edges()])
	_night_affix_label.text = "夜晚词缀：%s" % " · ".join(parts)
	_night_affix_row.tooltip_text = "\n".join(tips)
	_night_affix_row.visible = not parts.is_empty()


func hide_night_affixes() -> void:
	if _night_affix_row != null:
		_night_affix_row.visible = false


func _ensure_night_affix_row() -> void:
	if _night_affix_row != null:
		return
	_night_affix_row = PanelContainer.new()
	_night_affix_row.name = "NightAffixRow"
	_night_affix_row.visible = false
	_night_affix_row.z_index = 40
	_night_affix_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_night_affix_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_night_affix_row.offset_top = 72.0
	add_child(_night_affix_row)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_night_affix_row.add_child(margin)
	_night_affix_label = Label.new()
	_night_affix_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	margin.add_child(_night_affix_label)
```

- [ ] **Step 2: controller 接线**

`combat_hud_controller.gd` 把 `_on_night_started()`（约 281 行）改为：

```gdscript
func _on_night_started(_day: int) -> void:
	_refresh_top_hud()
	_show_night_affix_banner()


func _show_night_affix_banner() -> void:
	if _combat_hud == null or not _combat_hud.has_method("set_night_affixes"):
		return
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null or not data_repo.has_method("get_night_affix_cfg"):
		return
	var affixes: Array[Dictionary] = []
	for raw_id: Variant in (run_state.night_affix_ids as Array):
		var cfg: Dictionary = data_repo.get_night_affix_cfg(StringName(raw_id))
		if not cfg.is_empty():
			affixes.append({"name": String(cfg.get("name", "")), "desc": String(cfg.get("desc", ""))})
	_combat_hud.set_night_affixes(affixes)
```

并在 `_on_phase_changed()`（约 258 行）的 `_refresh_top_hud()` 之前插入：

```gdscript
	if _new_phase != GameEnums.PHASE_NIGHT and _combat_hud != null and _combat_hud.has_method("hide_night_affixes"):
		_combat_hud.hide_night_affixes()
```

注意 `_on_phase_changed` 现有参数名为 `_new_phase`（带下划线前缀），引用它后需把签名里的 `_new_phase` 保持原名（GDScript 允许引用带下划线参数，现有函数体已在使用，无需改名）。

- [ ] **Step 3: 解析与启动检查**

```bash
$GODOT --headless --path . --check-only --script scripts/ui/combat/combat_hud.gd
$GODOT --headless --path . --check-only --script scripts/ui/combat/combat_hud_controller.gd
$GODOT --headless --path . --quit-after 5
$GODOT --headless --path . --script scripts/debug/test_night_template_flow.gd
```
Expected: 解析无错；启动正常；night_template_flow 全绿。

- [ ] **Step 4: 提交**

```bash
git add scripts/ui/combat/combat_hud.gd scripts/ui/combat/combat_hud_controller.gd
git commit -m "feat(ui): persistent night affix banner during combat"
```

---

### Task 7: 文档同步 + 全量回归 + 人工验收清单

**Files:**
- Modify: `docs/DATA_SCHEMA.md`（§6 wave_templates）
- Modify: `docs/superpowers/specs/2026-06-10-dynamic-spawn-gates-design.md`（状态行）

- [ ] **Step 1: DATA_SCHEMA.md §6 改写**

§6 中所有 `entries` 字段说明改为 `groups`；示例 JSON 改用迁移后的 slug_tide 片段（见 Task 3 Step 3）；字段表把 `spawn_key`（"刷怪点逻辑名"）一行替换为：

```markdown
| `lane` | `String` | 进攻角色：`main`（该波主攻口）/ `flank`（非主攻口，单口时回退）/ `any`（活跃口随机）。落口由 `night_template_resolver.gd` 清晨 seeded 结算 |
```

文末"引用关系"清单（约 814-817 行）把 `entries` 改为 `groups`、删除 `spawn_key 引用刷怪点逻辑名` 一行，追加一行：`wave_templates.json[].groups[].lane 取值 main/flank/any（见 docs/superpowers/specs/2026-06-10-dynamic-spawn-gates-design.md）`。

- [ ] **Step 2: 设计稿状态行更新**

`docs/superpowers/specs/2026-06-10-dynamic-spawn-gates-design.md` 首行状态从"已批准"改为"已批准；v1 已实现（2026-06-10，分支 fix/map-popup-floating-layer）"。

- [ ] **Step 3: 全量回归**

```bash
git diff --check
$GODOT --headless --path . --script scripts/debug/test_wave_templates.gd
$GODOT --headless --path . --script scripts/debug/test_night_waves_affixes.gd
$GODOT --headless --path . --script scripts/debug/test_night_template_flow.gd
$GODOT --headless --path . --script scripts/debug/test_relic_draw.gd
$GODOT --headless --path . --script scripts/debug/test_contract_events.gd
$GODOT --headless --path . --quit-after 5
```
Expected: 全部 PASSED。

- [ ] **Step 4: 提交**

```bash
git add docs/DATA_SCHEMA.md docs/superpowers/specs/2026-06-10-dynamic-spawn-gates-design.md docs/superpowers/plans/2026-06-10-dynamic-spawn-gates-v1.md docs/肉鸽构筑与战斗优化方案.md
git commit -m "docs(night): sync schema and plan docs for dynamic spawn gates v1"
```

- [ ] **Step 5: 人工验收清单（报告给用户，由用户在编辑器里跑游戏确认）**

1. 开局地图：迷雾中能看到 3 个出怪口标记；出怪口周边格子仍要逐格探索才能揭开；
2. 第 2 天起白天预览：敌情卡片按"第 N 波"分段，每段标题含"主攻 Sx"，主攻口卡片有"· 主攻"后缀；同一晚不同波主攻口可能不同；
3. 夜间：屏幕上方常显"夜晚词缀：…"横幅（第 1 晚无词缀不显示），悬停显示完整描述；触发战争赌局/军械库后当晚横幅包含新增词缀；
4. 实际刷怪方向与预览标注一致（抽查一晚）；
5. 重开新局（不同 seed）：主攻口分布与上局不同。
