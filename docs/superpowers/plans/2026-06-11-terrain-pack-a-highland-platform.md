# 地形包阶段 A：高台地形 + 人工高台建筑 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 引擎层支持第四种地形 highland（敌不可走/不可建/仅远程可部署）+ 玩家可建造的人工高台建筑（借墙逻辑、塌台死人），并堵住 reveal_area 可探索出怪口格的 v1 缺口。

**Architecture:** highland 是 CellData 新地形常量（阻挡语义同山水，部署语义独立）；部署校验在 unit_manager 抽公共函数后按职业分地形放行；人工高台是 `blocks_path: true` 的建筑（普通怪绕行、拆迁怪攻击免费获得），加"摧毁时同格干员走 UNIT_REMOVE_DEAD"一个钩子。天然高台的**放置**属于阶段 B（骨架生成器 mesa stage）——本阶段地图上不会自然出现 highland，引擎支持靠 debug/测试路径验证，人工高台是即时可玩的真功能。

**Tech Stack:** Godot 4.6 GDScript（TAB 缩进、警告即错误、headless 下跨文件引用用 preload 常量）；headless 回归 `extends SceneTree`。

**规格:** docs/superpowers/specs/2026-06-11-terrain-generation-design-draft.md §2.4（修订版）/§2.6/§7

**通用约束（每任务适用）:** 测试命令 `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/<file>.gd`；`--check-only` 解析受改文件；conventional commits；禁 `git add -A`；数值全为占位符照抄即可。

**文件总览:**
- Modify: `scripts/map/cell_data.gd`（TERRAIN_HIGHLAND + 查询）
- Modify: `scripts/map/map_root_view.gd:1013-1064`（渲染两处兜底陷阱前插 highland 分支 + 占位染色）
- Modify: `scripts/map/map_manager.gd`（debug 序列化 highland 键 + reveal_area 口格守卫）
- Modify: `scripts/combat/unit_manager.gd:37-145`（部署校验抽公共函数 + highland/平台放行）
- Modify: `data/buildings.json`（artificial_platform 条目）
- Modify: `scripts/building/building_manager.gd`（摧毁钩子 + 拆除守卫）
- Create: `scripts/debug/test_highland_platform.gd`（第九套件）
- Modify (Task A5): `docs/DATA_SCHEMA.md`、`docs/肉鸽构筑与战斗优化方案.md`

---

### Task A1: TERRAIN_HIGHLAND 地形核心 + 渲染 + debug 序列化

**Files:**
- Modify: `scripts/map/cell_data.gd`
- Modify: `scripts/map/map_root_view.gd`（`_get_cell_color`:1013、`_draw_cell_tile`:1035、`_get_cell_texture`:1043）
- Modify: `scripts/map/map_manager.gd`（`get_debug_map_state`:157、`apply_debug_map_state`:185、`generate_debug_map`/`_apply_debug_blocked_cells` 一族）
- Create: `scripts/debug/test_highland_platform.gd`

- [ ] **Step 1: 新建套件骨架 + 失败测试**

创建 `scripts/debug/test_highland_platform.gd`：

```gdscript
extends SceneTree

## 地形包阶段 A 回归：highland 地形语义 / debug 序列化 / 部署门控 / 人工高台建筑。
## 运行：Godot --headless --path . --script scripts/debug/test_highland_platform.gd

const CellDataScript = preload("res://scripts/map/cell_data.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_highland_semantics()
	await _test_debug_roundtrip()
	_finish()


func _test_highland_semantics() -> void:
	var data: CellData = CellDataScript.new()
	data.cell = Vector2i(3, 3)
	data.set_base_terrain(CellDataScript.TERRAIN_HIGHLAND)
	_expect(not data.walkable, "highland blocks enemies")
	_expect(not data.buildable, "highland not buildable")
	_expect(data.is_terrain_blocking(), "highland counts as blocking terrain")
	_expect(data.allows_ranged_deploy(), "highland allows ranged deploy")
	var plain: CellData = CellDataScript.new()
	plain.set_base_terrain(CellDataScript.TERRAIN_PLAIN)
	_expect(not plain.allows_ranged_deploy(), "plain is not a ranged-only platform")
	var mountain: CellData = CellDataScript.new()
	mountain.set_base_terrain(CellDataScript.TERRAIN_MOUNTAIN)
	_expect(not mountain.allows_ranged_deploy(), "mountain stays pure blocker")


func _test_debug_roundtrip() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var map_manager := game.get_node_or_null("Managers/MapManager")
	if map_manager == null:
		_expect(false, "boot ok for debug roundtrip")
		game.queue_free()
		await process_frame
		return
	var target := Vector2i(10, 10)
	var data: CellData = map_manager.get_cell_data(target)
	data.set_base_terrain(CellDataScript.TERRAIN_HIGHLAND)
	var state: Dictionary = map_manager.get_debug_map_state()
	var highland_cells: Array = state.get("highland", [])
	var found := false
	for raw_cell: Variant in highland_cells:
		var arr: Array = raw_cell
		if int(arr[0]) == target.x and int(arr[1]) == target.y:
			found = true
	_expect(found, "debug state serializes highland cells")
	map_manager.apply_debug_map_state(state, map_manager.get_debug_spawn_defs())
	var restored: CellData = map_manager.get_cell_data(target)
	_expect(restored != null and restored.terrain == CellDataScript.TERRAIN_HIGHLAND, "debug state restores highland")
	game.queue_free()
	await process_frame


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("HIGHLAND PLATFORM TESTS PASSED")
		quit(0)
	else:
		printerr("HIGHLAND PLATFORM TESTS FAILED: %d" % _failures)
		quit(1)
```

- [ ] **Step 2: 跑套件确认失败**（TERRAIN_HIGHLAND/allows_ranged_deploy 不存在 → 脚本错误即红）

- [ ] **Step 3: 实现 cell_data.gd**

```gdscript
const TERRAIN_HIGHLAND := &"highland"
```
（与现有 TERRAIN_* 常量并排）。`is_terrain_blocking()` 改为：

```gdscript
func is_terrain_blocking() -> bool:
	return terrain == TERRAIN_MOUNTAIN or terrain == TERRAIN_WATER or terrain == TERRAIN_HIGHLAND
```

新增查询（放 is_terrain_blocking 之后）：

```gdscript
## 高台：敌不可走、不可建，但远程职业可部署（阶段 B 由生成器放置，人工高台建筑另走 building 路径）。
func allows_ranged_deploy() -> bool:
	return terrain == TERRAIN_HIGHLAND
```

`set_base_terrain` 无需改（blocked 由 is_terrain_blocking 推导，highland 自动 walkable=false/buildable=false）。

- [ ] **Step 4: 实现 map_root_view.gd 渲染分支（两处陷阱 + 占位染色）**

`_get_cell_color`（1013）在 `TERRAIN_WATER` 分支之后、`TERRAIN_MOUNTAIN or not walkable` 兜底**之前**插入：

```gdscript
	if data.terrain == CellData.TERRAIN_HIGHLAND:
		return COLOR_HIGHLAND
```

文件顶部颜色常量区（grep `COLOR_BLOCKED` 找到常量块）加：

```gdscript
const COLOR_HIGHLAND := Color(0.62, 0.54, 0.38)
```

`_get_cell_texture`（1043）同位置插入（水之后、山兜底之前）：

```gdscript
	if data.terrain == CellData.TERRAIN_HIGHLAND:
		return TILE_MOUNTAIN
```

`_draw_cell_tile`（1035）整体替换为（占位方案：山贴图加暖黄 modulate，等 `tile_highland.png` 落地后只删 tint 分支——见美术文档 §11）：

```gdscript
const HIGHLAND_PLACEHOLDER_TINT := Color(1.25, 1.1, 0.78)


func _draw_cell_tile(rect: Rect2, data) -> void:
	var texture := _get_cell_texture(data)
	if texture == null:
		draw_rect(rect, _get_cell_color(data))
		return
	# 占位：tile_highland.png 未生成前用山地贴图暖黄染色（docs/MAP_ASSET_GENERATION_PROMPTS.md §11）。
	if data.discovered and data.terrain == CellData.TERRAIN_HIGHLAND:
		draw_texture_rect(texture, rect, false, HIGHLAND_PLACEHOLDER_TINT)
		return
	draw_texture_rect(texture, rect, false)
```

（常量放文件常量区，函数保持原位置。`data.discovered` 守卫保证迷雾格仍画纯 TILE_HIDDEN 不染色。）

- [ ] **Step 5: 实现 map_manager.gd debug 序列化**

`get_debug_map_state`（157-178）：mountain 收集循环改为同时收集 highland（保持排序逻辑），返回字典加 `"highland": highland_cells`：

```gdscript
	var mountain_cells: Array = []
	var highland_cells: Array = []
	for raw_cell in _cells.keys():
		var cell: Vector2i = raw_cell
		var data := get_cell_data(cell)
		if data == null:
			continue
		if data.is_core or data.spawn_key != StringName():
			continue
		if data.terrain == CellData.TERRAIN_MOUNTAIN:
			mountain_cells.append([cell.x, cell.y])
		elif data.terrain == CellData.TERRAIN_HIGHLAND:
			highland_cells.append([cell.x, cell.y])
```
（两个数组都用既有的 sort_custom 排序；返回字典 `"mountain"` 旁加 `"highland"`。）

`apply_debug_map_state`（185-194）：读 `"highland"` 键（带缺省 `[]` fallback——旧存档无此键不炸），把 highland 单元格列表传给 `generate_debug_map`；`generate_debug_map` 加一个参数 `highland_cells: Array = []`，在 `_apply_debug_blocked_cells` 之后调用新的 `_apply_debug_highland_cells`（复制 `_apply_debug_blocked_cells` 结构，terrain 用 TERRAIN_HIGHLAND）：

```gdscript
func _apply_debug_highland_cells(highland_cells: Array) -> void:
	for raw_cell in highland_cells:
		var cell := _parse_debug_cell(raw_cell, Vector2i(-1, -1))
		if not is_inside(cell):
			continue
		var data := get_cell_data(cell)
		if data == null:
			continue
		if data.is_core or data.spawn_key != StringName():
			continue
		if data.occupied or data.unit_runtime_id >= 0 or data.building_runtime_id >= 0:
			continue
		data.set_base_terrain(CellData.TERRAIN_HIGHLAND)
```

注意 `clear_debug_blocked_cells`（122）只清 mountain——保持不动（highland 是独立地形不是"阻挡画笔"）。

- [ ] **Step 6: 跑套件 → `HIGHLAND PLATFORM TESTS PASSED`；`--check-only` 三个受改文件**

- [ ] **Step 7: 回归** test_spawn_gates_v2.gd + test_night_waves_affixes.gd → PASSED

- [ ] **Step 8: Commit**

```bash
git add scripts/map/cell_data.gd scripts/map/map_root_view.gd scripts/map/map_manager.gd scripts/debug/test_highland_platform.gd
git commit -m "feat(map): highland terrain type with render and debug schema"
```

---

### Task A2: 部署校验抽公共函数 + highland 仅远程放行

**Files:**
- Modify: `scripts/combat/unit_manager.gd`（`try_deploy_operator`:37 内联校验段 + `_validate_deploy_operator`:101）
- Modify: `scripts/debug/test_highland_platform.gd`

- [ ] **Step 1: 失败测试。追加 `_test_highland_deploy()`，`_run()` 中 await 调用：**

```gdscript
func _test_highland_deploy() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	var unit_manager := game.get_node_or_null("Managers/UnitManager")
	if run_state == null or map_manager == null or unit_manager == null:
		_expect(false, "boot ok for highland deploy")
		game.queue_free()
		await process_frame
		return
	var core: Vector2i = map_manager.get_core_cell()
	var highland_cell := Vector2i(core.x + 2, core.y)
	var cell_data: CellData = map_manager.get_cell_data(highland_cell)
	cell_data.resource_type = &""
	cell_data.set_base_terrain(CellDataScript.TERRAIN_HIGHLAND)
	var sniper_info: Dictionary = run_state.add_owned_operator(&"sniper_t1", "测试高台狙击")
	var sniper_key := StringName(sniper_info.get("key", ""))
	var guard_info: Dictionary = run_state.add_owned_operator(&"guard_t1", "测试高台近卫")
	var guard_key := StringName(guard_info.get("key", ""))
	var guard_result: Dictionary = unit_manager.try_deploy_operator(guard_key, highland_cell, Vector2i.RIGHT)
	_expect(not guard_result.get("ok", false), "melee rejected on highland")
	var sniper_result: Dictionary = unit_manager.try_deploy_operator(sniper_key, highland_cell, Vector2i.LEFT)
	_expect(sniper_result.get("ok", false), "ranged deploys on highland")
	var plain_cell := Vector2i(core.x - 2, core.y)
	var plain_data: CellData = map_manager.get_cell_data(plain_cell)
	plain_data.resource_type = &""
	plain_data.set_base_terrain(CellDataScript.TERRAIN_PLAIN)
	var sniper2_info: Dictionary = run_state.add_owned_operator(&"sniper_t1", "测试平地狙击")
	var sniper2_key := StringName(sniper2_info.get("key", ""))
	var plain_result: Dictionary = unit_manager.try_deploy_operator(sniper2_key, plain_cell, Vector2i.RIGHT)
	_expect(plain_result.get("ok", false), "ranged still deploys on plain")
	game.queue_free()
	await process_frame
```

（前置：核心周围 5×5 开局已探索，core±2 在其中；若 (core.x+2, core.y) 恰是资源格，测试先清掉 resource_type 再改地形——已写在上面。`add_owned_operator` 返回带 "key" 的字典——v1 测试同款用法。部署相位：白天可部署（`_is_deploy_phase` 含 PHASE_DAY）。）

- [ ] **Step 2: 跑套件确认失败**（melee rejected on highland 与 ranged deploys on highland 两条必有一条失败：现行 `is_walkable` 对 highland 返回 false → 狙击也被拒）

- [ ] **Step 3: 实现 unit_manager.gd**

顶部常量区加：

```gdscript
const RANGED_DEPLOY_CLASSES: Array[StringName] = [&"sniper", &"caster"]
```

新增公共校验（放 `_validate_deploy_operator` 附近）：

```gdscript
## 部署落格校验：平地走 is_walkable 全职业；highland 地形仅远程职业（设计稿 §2.4）。
## 人工高台建筑的放行在 Task A3 加入本函数（保持单点）。
func _validate_deploy_cell(cell: Vector2i, cfg: Dictionary) -> Dictionary:
	if _map_manager == null:
		return ActionResult.err(&"MAP_UNAVAILABLE", "操作失败：地图尚未初始化")
	var cell_data = _map_manager.get_cell_data(cell) if _map_manager.has_method("get_cell_data") else null
	if cell_data != null and cell_data.is_core:
		return ActionResult.err(&"CELL_NOT_WALKABLE", "无法部署：不能部署在核心上")
	if cell_data != null and cell_data.has_method("allows_ranged_deploy") and cell_data.allows_ranged_deploy():
		if cell_data.unit_runtime_id >= 0:
			return ActionResult.err(&"CELL_NOT_WALKABLE", "无法部署：该格已有干员")
		if not RANGED_DEPLOY_CLASSES.has(StringName(cfg.get("class", ""))):
			return ActionResult.err(&"CLASS_NOT_ALLOWED", "无法部署：高台只能部署狙击/术师")
		return ActionResult.ok()
	if not _map_manager.is_walkable(cell):
		return ActionResult.err(&"CELL_NOT_WALKABLE", "无法部署：目标格不可部署")
	return ActionResult.ok()
```

两处既有校验改为调用它：
- `try_deploy_operator`（~64 行）：把 `if not _map_manager.is_walkable(cell): return ...` 与紧随的 is_core 检查整段替换为：

```gdscript
	var deploy_cell_result := _validate_deploy_cell(cell, cfg)
	if not deploy_cell_result.get("ok", false):
		return deploy_cell_result
```

- `_validate_deploy_operator`（~129-133 行）：`is_core` / `is_discovered` / `is_walkable` 三段中，保留 `is_inside` 与 `is_discovered` 检查（highland 也要求已探索——探索语义不变），把 is_core+is_walkable 两段替换为同样的 `_validate_deploy_cell` 调用（放在 is_discovered 之后）。

注意 try_deploy_operator 原本没有 is_discovered 检查（验证走 _validate_deploy_operator 先行？读 37-100 确认调用链：UI 先调 `_validate_deploy_operator` 再调 `try_deploy_operator`，但 try_deploy 自身也做了一遍内联校验——保持两处行为一致即可，不要在 try_deploy 新增 discovered 要求，维持现状语义）。

- [ ] **Step 4: 跑套件 → PASSED；回归 test_targeted_star_up.gd（部署链路消费方）+ test_spawn_gates_v2.gd → PASSED**

- [ ] **Step 5: 部署高亮检查（验证非新功能）**：grep combat_hud_controller.gd 的拖拽合法格预览（~1406 一带 `is_walkable` 或 `_validate_deploy_operator` 调用）。若预览走 `_validate_deploy_operator` → 自动跟随，无需改动；若直接调 `map_manager.is_walkable` → 改为调 `unit_manager._validate_deploy_operator(...)` 不可行（私有），则给 unit_manager 加一行公共包装 `func can_deploy_operator_at(operator_key: StringName, cell: Vector2i) -> bool: return _validate_deploy_operator(operator_key, cell).get("ok", false)` 并让预览用它。把实际处置写进报告。

- [ ] **Step 6: Commit**

```bash
git add scripts/combat/unit_manager.gd scripts/debug/test_highland_platform.gd
git commit -m "feat(combat): ranged-only highland deploy via shared cell validation"
```
（若 Step 5 改了 controller 一并 add。）

---

### Task A3: 人工高台建筑（buildings.json + 上台部署 + 塌台死人 + 拆除守卫）

**Files:**
- Modify: `data/buildings.json`
- Modify: `scripts/combat/unit_manager.gd`（`_validate_deploy_cell` 加平台分支）
- Modify: `scripts/building/building_manager.gd`（`_mark_building_destroyed`:363 钩子 + `try_demolish_building` 守卫）
- Modify: `scripts/debug/test_highland_platform.gd`

- [ ] **Step 1: 失败测试。追加 `_test_artificial_platform()`，await 调用：**

```gdscript
func _test_artificial_platform() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	var unit_manager := game.get_node_or_null("Managers/UnitManager")
	var building_manager := game.get_node_or_null("Managers/BuildingManager")
	if run_state == null or map_manager == null or unit_manager == null or building_manager == null:
		_expect(false, "boot ok for platform test")
		game.queue_free()
		await process_frame
		return
	var core: Vector2i = map_manager.get_core_cell()
	var platform_cell := Vector2i(core.x, core.y + 2)
	var platform_data: CellData = map_manager.get_cell_data(platform_cell)
	platform_data.resource_type = &""
	platform_data.set_base_terrain(CellDataScript.TERRAIN_PLAIN)
	run_state.add_materials(10, 10, 0)
	run_state.reset_action_points(30)
	var place_result: Dictionary = building_manager.try_place_building(platform_cell, &"artificial_platform")
	_expect(place_result.get("ok", false), "platform places on plain")
	var sniper_info: Dictionary = run_state.add_owned_operator(&"sniper_t1", "测试台上狙击")
	var sniper_key := StringName(sniper_info.get("key", ""))
	var deploy_result: Dictionary = unit_manager.try_deploy_operator(sniper_key, platform_cell, Vector2i.RIGHT)
	_expect(deploy_result.get("ok", false), "ranged deploys onto living platform")
	var guard_info: Dictionary = run_state.add_owned_operator(&"guard_t1", "测试台上近卫")
	var guard_key := StringName(guard_info.get("key", ""))
	var other_cell := Vector2i(core.x, core.y - 2)
	var other_data: CellData = map_manager.get_cell_data(other_cell)
	other_data.resource_type = &""
	other_data.set_base_terrain(CellDataScript.TERRAIN_PLAIN)
	var place2: Dictionary = building_manager.try_place_building(other_cell, &"artificial_platform")
	_expect(place2.get("ok", false), "second platform places")
	var guard_result: Dictionary = unit_manager.try_deploy_operator(guard_key, other_cell, Vector2i.RIGHT)
	_expect(not guard_result.get("ok", false), "melee rejected on platform")
	# 拆除守卫：台上有人不能拆。
	var platform_actor: Node = building_manager.get_building_by_cell(platform_cell)
	var platform_id: int = int(platform_actor.get_runtime_id())
	var demolish_occupied: Dictionary = building_manager.try_demolish_building(platform_id)
	_expect(not demolish_occupied.get("ok", false), "demolish rejected while occupied")
	# 塌台死人：打掉平台，台上干员阵亡（再部署冷却 = UNIT_REMOVE_DEAD 语义）。
	building_manager.damage_building(platform_id, 9999, GameEnums.DAMAGE_PHYSICAL)
	await process_frame
	_expect(map_manager.get_cell_data(platform_cell).unit_runtime_id < 0, "occupant removed when platform destroyed")
	_expect(unit_manager.is_operator_redeploying(sniper_key), "occupant died into redeploy cooldown")
	game.queue_free()
	await process_frame
```

- [ ] **Step 2: 跑套件确认失败**（artificial_platform 不存在 → 放置失败连锁红）

- [ ] **Step 3: buildings.json 追加条目**（wood_wall 之后，保持文件格式；占位视觉复用鼓舞石碑——美术文档 §11 出图后只换 visual_key/icon_path）：

```json
  {
    "id": "artificial_platform",
    "name": "人工高台",
    "desc": "可供狙击/术师站立的木石炮台。阻挡敌人路径；被摧毁时其上干员阵亡",
    "sort_order": 220,
    "icon_text": "台",
    "building_type": "platform",
    "max_hp": 500,
    "visual_key": "inspiring_monolith",
    "destroyed_visual_key": "generic_destroyed_building",
    "cost_wood": 2,
    "cost_stone": 2,
    "cost_mana": 0,
    "ap_cost": 2,
    "blocks_path": true,
    "ranged_deployable": true,
    "effect_radius": 0,
    "effect_type": "none",
    "effect_value": 0,
    "place_rule": "plain_only",
    "scene_key": "building_actor",
    "icon_path": "res://assets/ui/generated/icon_building_inspiring_monolith.png"
  }
```

- [ ] **Step 4: unit_manager.gd `_validate_deploy_cell` 平台分支**——在 highland 分支之后、`is_walkable` 兜底之前插入：

```gdscript
	if cell_data != null and cell_data.building_runtime_id >= 0 and _building_manager != null:
		var building: Node = _building_manager.get_building_by_runtime_id(cell_data.building_runtime_id) if _building_manager.has_method("get_building_by_runtime_id") else null
		if building != null and is_instance_valid(building):
			var building_cfg_variant: Variant = building.get("cfg")
			var building_cfg: Dictionary = building_cfg_variant if typeof(building_cfg_variant) == TYPE_DICTIONARY else {}
			if bool(building_cfg.get("ranged_deployable", false)) and not _is_building_destroyed_for_deploy(building):
				if cell_data.unit_runtime_id >= 0:
					return ActionResult.err(&"CELL_NOT_WALKABLE", "无法部署：该格已有干员")
				if not RANGED_DEPLOY_CLASSES.has(StringName(cfg.get("class", ""))):
					return ActionResult.err(&"CLASS_NOT_ALLOWED", "无法部署：高台只能部署狙击/术师")
				return ActionResult.ok()
```

辅助（仿 enemy_attack_controller 的判毁式样）：

```gdscript
func _is_building_destroyed_for_deploy(building: Node) -> bool:
	if building.has_method("is_destroyed"):
		return bool(building.is_destroyed())
	var hp_variant: Variant = building.get("current_hp")
	return hp_variant != null and int(hp_variant) <= 0
```

unit_manager 需要 `_building_manager` 引用：grep 该文件——若没有，加 `@onready var _building_manager: Node = get_node_or_null("../BuildingManager")`（与 `_map_manager` 同款）。

- [ ] **Step 5: building_manager.gd 两处**

`_mark_building_destroyed`（363，emits building_destroyed:375）在 emit 之前加塌台钩子：

```gdscript
	# 塌台死人：摧毁时同格干员走 UNIT_REMOVE_DEAD（再部署冷却 + unit_died 事件，与战斗阵亡同语义）。
	var occupant_cell: Vector2i = actor.get_current_cell() if actor.has_method("get_current_cell") else Vector2i(-1, -1)
	if _map_manager != null and _map_manager.has_method("get_cell_data"):
		var occupant_data = _map_manager.get_cell_data(occupant_cell)
		if occupant_data != null and int(occupant_data.unit_runtime_id) >= 0:
			var unit_manager := get_node_or_null("../UnitManager")
			if unit_manager != null and unit_manager.has_method("remove_unit"):
				unit_manager.remove_unit(int(occupant_data.unit_runtime_id), GameEnums.UNIT_REMOVE_DEAD)
```

（`_map_manager` 引用与 `get_current_cell` 名以该文件实际为准——grep 确认，building actor 有 `get_current_cell`（enemy_attack_controller 用过 building.get_current_cell）。）

`try_demolish_building`（~218 一带）入口加守卫（找到函数后在已毁检查附近插）：

```gdscript
	var demolish_cell: Vector2i = actor.get_current_cell() if actor.has_method("get_current_cell") else Vector2i(-1, -1)
	if _map_manager != null and _map_manager.has_method("get_cell_data"):
		var demolish_data = _map_manager.get_cell_data(demolish_cell)
		if demolish_data != null and int(demolish_data.unit_runtime_id) >= 0:
			return ActionResult.err(&"BUILDING_OCCUPIED", "无法拆除：先撤回上面的干员")
```

- [ ] **Step 6: 跑套件 → `HIGHLAND PLATFORM TESTS PASSED`；回归 test_contract_events.gd（建筑链路）+ test_spawn_gates_v2.gd → PASSED；boot `--quit-after 5` 干净**

- [ ] **Step 7: Commit**

```bash
git add data/buildings.json scripts/combat/unit_manager.gd scripts/building/building_manager.gd scripts/debug/test_highland_platform.gd
git commit -m "feat(building): artificial platform with ranged deploy and collapse kill"
```

---

### Task A4: reveal_area 跳过出怪口格（堵 v1 缺口）

**Files:**
- Modify: `scripts/map/map_manager.gd`（`reveal_area`:260-277）
- Modify: `scripts/debug/test_highland_platform.gd`

- [ ] **Step 1: 失败测试。追加 `_test_reveal_skips_gates()`，await 调用：**

```gdscript
func _test_reveal_skips_gates() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var map_manager := game.get_node_or_null("Managers/MapManager")
	if map_manager == null:
		_expect(false, "boot ok for reveal test")
		game.queue_free()
		await process_frame
		return
	var gate_cell: Vector2i = (map_manager.get_spawn_cells() as Array)[0]
	map_manager.reveal_area(gate_cell, 1)
	_expect(not map_manager.is_discovered(gate_cell), "reveal_area never discovers gate cells")
	var neighbor := Vector2i(clamp(gate_cell.x, 1, 28), clamp(gate_cell.y, 1, 28))
	if neighbor == gate_cell:
		neighbor = gate_cell + (Vector2i(1, 0) if gate_cell.x < 15 else Vector2i(-1, 0))
	_expect(map_manager.is_discovered(neighbor) or neighbor == gate_cell, "non-gate neighbors still revealed")
	game.queue_free()
	await process_frame
```

- [ ] **Step 2: 跑套件确认失败**（gate cell 被 reveal）

- [ ] **Step 3: 实现**——`reveal_area` 循环内 `if data == null or data.discovered: continue` 之后加：

```gdscript
			# 出怪口格永不探索（设计稿 §3.3 不变式）：标记常显但格子保持未探索，
			# 否则玩家可从地图边缘的口格继续邻接探索，绕开探索经济。
			if data.spawn_key != StringName():
				continue
```

- [ ] **Step 4: 跑套件 + 回归 test_spawn_gates_v2.gd（弹窗 gate 分支不受影响——它本就在 discovered 检查之前）→ 全 PASSED**

- [ ] **Step 5: Commit**

```bash
git add scripts/map/map_manager.gd scripts/debug/test_highland_platform.gd
git commit -m "fix(map): reveal_area never discovers spawn gate cells"
```

---

### Task A5: 文档同步 + 全量回归（九套件）

**Files:**
- Modify: `docs/DATA_SCHEMA.md`（buildings 节加 artificial_platform 与 `ranged_deployable`/`building_type: platform` 字段说明；地形节加 highland 语义；debug 地图状态 schema 加 highland 键）
- Modify: `docs/肉鸽构筑与战斗优化方案.md`（§8.1 地形包条目：阶段 A 已落地 + 阶段 B 待做说明）

- [ ] **Step 1: 文档更新**（紧凑，按两文件既有口吻）
- [ ] **Step 2: 全量回归**——九套件逐个跑（八个既有 + test_highland_platform）+ `--quit-after 5` boot。全 PASSED 才继续；有失败即 BLOCKED 上报，不私修无关失败。
- [ ] **Step 3: Commit**

```bash
git add docs/DATA_SCHEMA.md docs/肉鸽构筑与战斗优化方案.md
git commit -m "docs(terrain): document highland terrain and artificial platform"
```

---

## 自审记录

- **规格覆盖**：§2.4 highland 语义（阻挡+仅远程部署）→ A1/A2；§2.6 人工高台全要素（借墙逻辑=blocks_path 数据位、复合格部署、塌台死人 UNIT_REMOVE_DEAD、2木2石2AP/500HP、plain_only、白天修理走既有机制无需新码）→ A3；§7 渲染两陷阱与 debug schema 陷阱 → A1；reveal_area 缺口（终审发现，任务卡 task_830d54ef）→ A4。天然高台的生成器放置、tile_highland 正式贴图、combat_sandbox 高台画笔 = 阶段 B/美术期，显式不在本计划。
- **类型一致性**：`allows_ranged_deploy()` A1 定义 A2/A3 消费；`RANGED_DEPLOY_CLASSES` A2 定义 A3 复用；`_validate_deploy_cell(cell, cfg)` 签名两任务一致。
- **实现期对齐点**（非占位符）：unit_manager 是否已有 `_building_manager` 引用、building actor 的 cell 访问器名、try_demolish_building 的实际行号、部署高亮的实际调用方式（A2 Step 5 要求写进报告）。
