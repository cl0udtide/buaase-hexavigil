# 命名夜晚出怪模板 + 白天关卡预告 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把硬编码的 `data/waves.json` 按 day 出怪，替换成 15 个具名夜晚模板：白天 `enter_day` 时确定性抽取当晚模板存入 RunState，白天用「卷轴展开」横幅醒目预告，右上角预览重构成「关卡名 + 每出怪口横向卡片」，且预告与夜晚实际生成读同一份解析结果。

**Architecture:** 新增 `data/wave_templates.json`（按 `id` 索引）+ 纯函数解析器 `NightTemplateResolver`（梯队→day 曲线 + 种子抽取，可 headless 单测）。`GameController.enter_day` 调解析器写 `RunState.night_template_id`；`WaveManager` 改为「按模板 id 跑波/出预览」；`NightManager` 读 RunState 模板生成敌人。UI 侧 `CombatHud` 重构预览面板 + 新增 `LevelIntroBanner`，控制器把结构化预览数据喂给视图。

**Tech Stack:** Godot 4 / GDScript；数据为 JSON；校验用 `Godot --headless --check-only --script`（解析检查）+ 一个 `extends SceneTree` 的 headless 断言脚本 + `scenes/debug/CombatSandbox.tscn` / 主场景 `scenes/game/Game.tscn` 人工验收。

**约定（每个改动 GDScript 的任务都要做）：**
- 解析检查：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script <改动的 .gd>`，期望无报错输出。
- 启动冒烟：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5`，期望无 `SCRIPT ERROR` / `data_reload_failed` / push_error。
- 提交：只 `git add` 本任务相关文件，commit message 用 `feat(scope): ...` / `refactor(scope): ...`，结尾带
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`。
- 分支：`feature/named-night-templates`（已创建，spec 已在此分支）。

---

## File Structure

**新增**
- `data/wave_templates.json` — 15 个命名模板（`id`/`name`/`desc`/`tier`/`key_enemies`/`entries`）。
- `scripts/enemy/night_template_resolver.gd` — 纯静态解析逻辑（梯队曲线 + 种子抽取 + 同局不重复）。
- `scripts/debug/test_wave_templates.gd` — `extends SceneTree` 的 headless 断言脚本（数据完整性 + 解析器确定性）。
- `scripts/ui/combat/enemy_icon_helper.gd` — enemy_id → 立绘 `Texture2D` 的静态助手（含类型字形兜底）。

**修改**
- `autoload/DataRepo.gd` — 移除 `waves` 加载，新增 `wave_templates` 加载与查询。
- `autoload/RunState.gd` — 新增 `night_template_id` / `used_template_ids` 字段并在 `reset_for_new_run` 清空。
- `scripts/enemy/wave_manager.gd` — 新增按模板 id 的解析/跑波/出预览；移除 day 兜底读取。
- `scripts/core/game_controller.gd` — `enter_day` 解析模板写 RunState。
- `scripts/core/night_manager.gd` — 读 `RunState.night_template_id` 起夜。
- `scripts/ui/combat/combat_hud.gd` — `set_wave_preview_data` 结构化填充 + `LevelIntroBanner` 播放。
- `scripts/ui/combat/combat_hud_controller.gd` — 预览改喂结构化数据 + `day_started` 触发横幅。
- `scenes/ui/combat/CombatHud.tscn` — 预览面板 v2 子树 + `LevelIntroBanner` 节点。
- `docs/DATA_SCHEMA.md` / `docs/UI_SYSTEM.md` — 同步。

**删除**
- `data/waves.json`。

---

## Phase 1 — 数据与解析核心（可 headless 自测）

### Task 1: 新增 `data/wave_templates.json`

**Files:**
- Create: `data/wave_templates.json`

- [ ] **Step 1: 写入完整模板表**

将以下内容**原样**写入 `data/wave_templates.json`（所有 `enemy_id` 均存在于 `data/enemies.json`，`spawn_key` 仅用 S1/S2/S3）：

```json
[
  { "id": "slug_tide", "name": "蠹潮汹涌", "tier": "early", "key_enemies": ["lumberjack_veteran"],
    "desc": "虫蠹之患，起于微末。待你察觉时，已成潮势，退之不及。",
    "entries": [
      { "time": 0.0, "enemy_id": "slime", "spawn_key": "S1", "count": 6, "interval": 0.8 },
      { "time": 4.0, "enemy_id": "originium_slug_alpha", "spawn_key": "S2", "count": 4, "interval": 0.9 },
      { "time": 8.0, "enemy_id": "hound", "spawn_key": "S2", "count": 2, "interval": 0.8 },
      { "time": 12.0, "enemy_id": "lumberjack_veteran", "spawn_key": "S3", "count": 2, "interval": 1.5 }
    ] },
  { "id": "moonlit_hounds", "name": "群犬逐月", "tier": "early", "key_enemies": ["hound"],
    "desc": "犬逐月而吠，人闻声而惧。真正咬人的那只，从不在月下出声。",
    "entries": [
      { "time": 0.0, "enemy_id": "hound", "spawn_key": "S1", "count": 4, "interval": 0.7 },
      { "time": 4.0, "enemy_id": "hound", "spawn_key": "S3", "count": 4, "interval": 0.6 },
      { "time": 8.0, "enemy_id": "soldier", "spawn_key": "S2", "count": 3, "interval": 1.0 },
      { "time": 13.0, "enemy_id": "hound", "spawn_key": "S1", "count": 4, "interval": 0.55 }
    ] },
  { "id": "nightfall_axe", "name": "樵斧夜叩", "tier": "early", "key_enemies": ["lumberjack_veteran"],
    "desc": "樵夫司木，昼伐于林，夜伐于户。斧斤所至，墙垣与林木，无异也。",
    "entries": [
      { "time": 0.0, "enemy_id": "slime", "spawn_key": "S1", "count": 5, "interval": 0.9 },
      { "time": 3.0, "enemy_id": "lumberjack_veteran", "spawn_key": "S2", "count": 2, "interval": 2.0 },
      { "time": 10.0, "enemy_id": "lumberjack_veteran", "spawn_key": "S3", "count": 2, "interval": 2.0 },
      { "time": 14.0, "enemy_id": "soldier", "spawn_key": "S1", "count": 3, "interval": 1.0 }
    ] },
  { "id": "swarming_assault", "name": "蚁附之势", "tier": "early", "key_enemies": ["soldier"],
    "desc": "蚁附之众，前仆而后继，不计生死。挡得其一，挡不得其千。",
    "entries": [
      { "time": 0.0, "enemy_id": "soldier", "spawn_key": "S1", "count": 4, "interval": 0.8 },
      { "time": 3.0, "enemy_id": "slime", "spawn_key": "S2", "count": 6, "interval": 0.7 },
      { "time": 7.0, "enemy_id": "soldier", "spawn_key": "S3", "count": 4, "interval": 0.8 },
      { "time": 12.0, "enemy_id": "crossbowman", "spawn_key": "S2", "count": 2, "interval": 1.2 }
    ] },

  { "id": "arts_eclipse", "name": "术火蔽空", "tier": "mid", "key_enemies": ["caster"],
    "desc": "术火无形，自空而降。见其光时，已临你顶上。",
    "entries": [
      { "time": 0.0, "enemy_id": "caster", "spawn_key": "S1", "count": 3, "interval": 1.2 },
      { "time": 4.0, "enemy_id": "arts_drone", "spawn_key": "S2", "count": 3, "interval": 1.0 },
      { "time": 9.0, "enemy_id": "caster", "spawn_key": "S3", "count": 3, "interval": 1.2 },
      { "time": 14.0, "enemy_id": "armored_soldier", "spawn_key": "S1", "count": 3, "interval": 1.0 }
    ] },
  { "id": "locust_swarm", "name": "飞蝗扑灯", "tier": "mid", "key_enemies": ["arts_drone"],
    "desc": "墙可拒兽，不可拒飞。蝗之扑灯，不问高下，只趋一处明。",
    "entries": [
      { "time": 0.0, "enemy_id": "bat", "spawn_key": "S1", "count": 5, "interval": 0.7 },
      { "time": 4.0, "enemy_id": "arts_drone", "spawn_key": "S3", "count": 3, "interval": 1.0 },
      { "time": 9.0, "enemy_id": "bat", "spawn_key": "S2", "count": 5, "interval": 0.65 },
      { "time": 13.0, "enemy_id": "hound_pro", "spawn_key": "S1", "count": 4, "interval": 0.6 }
    ] },
  { "id": "splitting_brood", "name": "裂卵成群", "tier": "mid", "key_enemies": ["splitting_originium_slug"],
    "desc": "碎其一者，反生其二。杀之愈众，来之愈繁，无有穷尽。",
    "entries": [
      { "time": 0.0, "enemy_id": "infused_originium_slug", "spawn_key": "S1", "count": 3, "interval": 1.0 },
      { "time": 4.0, "enemy_id": "splitting_originium_slug", "spawn_key": "S2", "count": 3, "interval": 1.2 },
      { "time": 9.0, "enemy_id": "splitting_originium_slug", "spawn_key": "S3", "count": 3, "interval": 1.2 },
      { "time": 13.0, "enemy_id": "infused_originium_slug", "spawn_key": "S2", "count": 3, "interval": 0.9 }
    ] },
  { "id": "ironwall_advance", "name": "铁壁徐进", "tier": "mid", "key_enemies": ["shieldguard"],
    "desc": "徐徐而进者最难当。盾牌后头的东西，从不知何为急。",
    "entries": [
      { "time": 0.0, "enemy_id": "shieldguard", "spawn_key": "S1", "count": 2, "interval": 1.8 },
      { "time": 3.0, "enemy_id": "armored_soldier", "spawn_key": "S2", "count": 3, "interval": 1.0 },
      { "time": 9.0, "enemy_id": "shieldguard", "spawn_key": "S3", "count": 2, "interval": 1.8 },
      { "time": 13.0, "enemy_id": "possessed_soldier", "spawn_key": "S1", "count": 2, "interval": 1.4 }
    ] },
  { "id": "crossfire_volley", "name": "暗弩攒射", "tier": "mid", "key_enemies": ["crossbowman"],
    "desc": "暗弩无声，引而不发。待你望见那箭，弦上早已空了。",
    "entries": [
      { "time": 0.0, "enemy_id": "crossbowman", "spawn_key": "S1", "count": 3, "interval": 1.1 },
      { "time": 4.0, "enemy_id": "dualstrike_swordsman", "spawn_key": "S2", "count": 4, "interval": 0.8 },
      { "time": 9.0, "enemy_id": "caster", "spawn_key": "S3", "count": 2, "interval": 1.3 },
      { "time": 13.0, "enemy_id": "crossbowman", "spawn_key": "S2", "count": 3, "interval": 1.0 }
    ] },

  { "id": "siege_breach", "name": "攻坚拔砦", "tier": "late", "key_enemies": ["siege_breaker"],
    "desc": "拔砦者不绕行。当其道者，是墙是人，一概砸开。",
    "entries": [
      { "time": 0.0, "enemy_id": "demolitionist", "spawn_key": "S1", "count": 2, "interval": 2.0 },
      { "time": 3.0, "enemy_id": "siege_breaker", "spawn_key": "S2", "count": 1, "interval": 0.0 },
      { "time": 8.0, "enemy_id": "hound_pro", "spawn_key": "S3", "count": 5, "interval": 0.55 },
      { "time": 13.0, "enemy_id": "demolitionist", "spawn_key": "S2", "count": 2, "interval": 2.0 },
      { "time": 18.0, "enemy_id": "siege_breaker", "spawn_key": "S1", "count": 1, "interval": 0.0 }
    ] },
  { "id": "greatblade_abyss", "name": "巨刃临渊", "tier": "late", "key_enemies": ["sarkaz_greatswordsman"],
    "desc": "刃大逾人，步重撼地。临渊而立者，不肯退，亦无路可退。",
    "entries": [
      { "time": 0.0, "enemy_id": "dualstrike_swordsman", "spawn_key": "S1", "count": 4, "interval": 0.8 },
      { "time": 4.0, "enemy_id": "sarkaz_greatswordsman", "spawn_key": "S2", "count": 2, "interval": 2.2 },
      { "time": 10.0, "enemy_id": "sarkaz_greatswordsman", "spawn_key": "S3", "count": 2, "interval": 2.2 },
      { "time": 15.0, "enemy_id": "possessed_soldier", "spawn_key": "S1", "count": 3, "interval": 1.2 }
    ] },
  { "id": "heavyplate_siege", "name": "重铠压境", "tier": "late", "key_enemies": ["heavy_defender"],
    "desc": "甲厚则锋钝。你加诸它的每一击，它都默默记下——而后，照旧前行。",
    "entries": [
      { "time": 0.0, "enemy_id": "heavy_defender", "spawn_key": "S1", "count": 2, "interval": 1.6 },
      { "time": 3.0, "enemy_id": "shieldguard", "spawn_key": "S2", "count": 2, "interval": 1.8 },
      { "time": 9.0, "enemy_id": "armored_soldier", "spawn_key": "S3", "count": 4, "interval": 1.0 },
      { "time": 14.0, "enemy_id": "heavy_defender", "spawn_key": "S2", "count": 1, "interval": 0.0 }
    ] },
  { "id": "arts_cataclysm", "name": "术穹倾覆", "tier": "late", "key_enemies": ["senior_caster"],
    "desc": "高术者一抬手，夜穹为之倾覆。法阵既成，你已无处可避。",
    "entries": [
      { "time": 0.0, "enemy_id": "senior_caster", "spawn_key": "S1", "count": 2, "interval": 1.8 },
      { "time": 4.0, "enemy_id": "arts_drone", "spawn_key": "S2", "count": 3, "interval": 1.0 },
      { "time": 9.0, "enemy_id": "caster", "spawn_key": "S3", "count": 3, "interval": 1.2 },
      { "time": 14.0, "enemy_id": "senior_caster", "spawn_key": "S2", "count": 2, "interval": 1.8 }
    ] },

  { "id": "fiends_carnival", "name": "群魔乱舞", "tier": "boss", "key_enemies": ["milk_dragon_chief"],
    "desc": "别问它从哪儿冒出来的，问就是——群魔乱舞。爱发奶龙的小朋友，它今晚亲自来了。",
    "entries": [
      { "time": 0.0, "enemy_id": "hound_pro", "spawn_key": "S1", "count": 4, "interval": 0.6 },
      { "time": 3.0, "enemy_id": "armored_soldier", "spawn_key": "S3", "count": 3, "interval": 1.0 },
      { "time": 6.0, "enemy_id": "milk_dragon_chief", "spawn_key": "S2", "count": 1, "interval": 0.0 },
      { "time": 12.0, "enemy_id": "possessed_soldier", "spawn_key": "S1", "count": 3, "interval": 1.2 }
    ] },
  { "id": "twilight_triumph", "name": "凯旋终焉", "tier": "boss", "key_enemies": ["patriot"],
    "desc": "英雄死了又死，故事讲了又讲。他曾为旗帜行军，如今旗帜只余灰烬——可没人，准他停下。",
    "entries": [
      { "time": 0.0, "enemy_id": "crossbowman", "spawn_key": "S1", "count": 2, "interval": 1.0 },
      { "time": 2.0, "enemy_id": "caster", "spawn_key": "S3", "count": 2, "interval": 1.2 },
      { "time": 6.0, "enemy_id": "patriot", "spawn_key": "S2", "count": 1, "interval": 0.0 },
      { "time": 12.0, "enemy_id": "sarkaz_greatswordsman", "spawn_key": "S1", "count": 2, "interval": 1.8 }
    ] }
]
```

- [ ] **Step 2: JSON 合法性校验**

Run: `python3 -c "import json,sys; d=json.load(open('data/wave_templates.json')); print('count',len(d)); print('tiers',sorted({t['tier'] for t in d}))"`
Expected: `count 15` 和 `tiers ['boss', 'early', 'late', 'mid']`

- [ ] **Step 3: Commit**

```bash
git add data/wave_templates.json
git commit -m "feat(waves): add 15 named night wave templates"
```

### Task 2: 纯函数解析器 `NightTemplateResolver`

**Files:**
- Create: `scripts/enemy/night_template_resolver.gd`

- [ ] **Step 1: 写解析器**

写入 `scripts/enemy/night_template_resolver.gd`：

```gdscript
extends RefCounted
class_name NightTemplateResolver

## day → 梯队曲线（#215 拉长流程时改这里即可）。
const TIER_BY_DAY := {
	1: &"early", 2: &"early",
	3: &"mid", 4: &"mid",
	5: &"late",
	6: &"boss",
}
const BOSS_DAY := 6
## 超出曲线的 day 的兜底梯队（为 #215 预留）。
const DEFAULT_TIER: StringName = &"late"


static func tier_for_day(day: int) -> StringName:
	return StringName(TIER_BY_DAY.get(day, DEFAULT_TIER))


## 从 pool_ids 中按种子确定性抽一个，优先剔除 used_ids 中已用的；全用过则回退整池。
static func resolve(pool_ids: Array, used_ids: Array, run_seed: int, day: int) -> StringName:
	var available: Array[StringName] = []
	for raw_id: Variant in pool_ids:
		var id := StringName(raw_id)
		if id != StringName() and not used_ids.has(id):
			available.append(id)
	if available.is_empty():
		for raw_id: Variant in pool_ids:
			var id := StringName(raw_id)
			if id != StringName():
				available.append(id)
	if available.is_empty():
		return StringName()
	available.sort()  # 抽取前固定顺序，保证同种子同结果
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("%d|%d|%s" % [run_seed, day, String(tier_for_day(day))]).hash())
	return available[rng.randi() % available.size()]
```

- [ ] **Step 2: 解析检查**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/enemy/night_template_resolver.gd`
Expected: 无报错输出（命令静默返回）。

- [ ] **Step 3: Commit**

```bash
git add scripts/enemy/night_template_resolver.gd
git commit -m "feat(waves): add deterministic night template resolver"
```

### Task 3: headless 断言脚本（数据完整性 + 解析器确定性）

**Files:**
- Create: `scripts/debug/test_wave_templates.gd`

- [ ] **Step 1: 写断言脚本**

写入 `scripts/debug/test_wave_templates.gd`：

```gdscript
extends SceneTree
## headless 自测：校验 wave_templates.json 完整性 + 解析器确定性。
## 运行：Godot --headless --path . --script scripts/debug/test_wave_templates.gd

const Resolver = preload("res://scripts/enemy/night_template_resolver.gd")

var _failures: int = 0


func _init() -> void:
	var templates := _load_templates()
	_check_data(templates)
	_check_resolver(templates)
	if _failures == 0:
		print("ALL WAVE TEMPLATE TESTS PASSED")
		quit(0)
	else:
		printerr("WAVE TEMPLATE TESTS FAILED: %d" % _failures)
		quit(1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	_expect(f != null, "open %s" % path)
	return JSON.parse_string(f.get_as_text()) if f != null else null


func _load_templates() -> Array:
	var parsed: Variant = _load_json("res://data/wave_templates.json")
	_expect(typeof(parsed) == TYPE_ARRAY, "templates is array")
	return parsed if typeof(parsed) == TYPE_ARRAY else []


func _check_data(templates: Array) -> void:
	_expect(templates.size() >= 10, "at least 10 templates (got %d)" % templates.size())

	# 建敌人 id 集合。
	var enemies_parsed: Variant = _load_json("res://data/enemies.json")
	var enemy_ids: Dictionary = {}
	if typeof(enemies_parsed) == TYPE_ARRAY:
		for e: Variant in enemies_parsed:
			if typeof(e) == TYPE_DICTIONARY:
				enemy_ids[StringName((e as Dictionary).get("id", ""))] = true

	var valid_tiers := {&"early": true, &"mid": true, &"late": true, &"boss": true}
	var valid_spawns := {"S1": true, "S2": true, "S3": true}
	var seen_ids: Dictionary = {}
	for t: Variant in templates:
		_expect(typeof(t) == TYPE_DICTIONARY, "template is dict")
		var tpl: Dictionary = t
		var id := StringName(tpl.get("id", ""))
		_expect(id != StringName(), "template has id")
		_expect(not seen_ids.has(id), "template id unique: %s" % id)
		seen_ids[id] = true
		_expect(String(tpl.get("name", "")) != "", "%s has name" % id)
		_expect(String(tpl.get("desc", "")) != "", "%s has desc" % id)
		_expect(valid_tiers.has(StringName(tpl.get("tier", ""))), "%s tier valid" % id)
		var entries: Array = tpl.get("entries", [])
		_expect(entries.size() > 0, "%s has entries" % id)
		for entry: Variant in entries:
			var ed: Dictionary = entry
			_expect(enemy_ids.has(StringName(ed.get("enemy_id", ""))), "%s enemy_id valid: %s" % [id, ed.get("enemy_id", "")])
			_expect(valid_spawns.has(String(ed.get("spawn_key", ""))), "%s spawn_key valid: %s" % [id, ed.get("spawn_key", "")])


func _ids_by_tier(templates: Array, tier: StringName) -> Array:
	var ids: Array = []
	for t: Variant in templates:
		if typeof(t) == TYPE_DICTIONARY and StringName((t as Dictionary).get("tier", "")) == tier:
			ids.append(StringName((t as Dictionary).get("id", "")))
	return ids


func _check_resolver(templates: Array) -> void:
	# 每个曲线内的 day 都有可用模板。
	for day in [1, 2, 3, 4, 5, 6]:
		var tier := Resolver.tier_for_day(day)
		var pool := _ids_by_tier(templates, tier)
		_expect(pool.size() > 0, "day %d tier %s pool non-empty" % [day, tier])

	# 确定性：同种子同结果。
	var early := _ids_by_tier(templates, &"early")
	var a := Resolver.resolve(early, [], 12345, 1)
	var b := Resolver.resolve(early, [], 12345, 1)
	_expect(a == b and a != StringName(), "resolve deterministic")

	# 同局不重复：day1 抽到的，day2 传入 used 后不再抽到。
	var used: Array[StringName] = [a]
	var c := Resolver.resolve(early, used, 12345, 2)
	_expect(c != a, "no-repeat within run")
```

- [ ] **Step 2: 运行断言脚本（应通过）**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/test_wave_templates.gd`
Expected: 输出 `ALL WAVE TEMPLATE TESTS PASSED`，退出码 0。

- [ ] **Step 3: Commit**

```bash
git add scripts/debug/test_wave_templates.gd
git commit -m "test(waves): add headless wave template integrity + resolver checks"
```

### Task 4: `DataRepo` 加载模板表、移除 waves

**Files:**
- Modify: `autoload/DataRepo.gd`

- [ ] **Step 1: 改 DATA_FILES / _tables / 加载标记**

`DATA_FILES` 里把 `"waves": "res://data/waves.json"` 整行替换为：
```gdscript
	"wave_templates": "res://data/wave_templates.json"
```
`_tables` 初始化里把 `"waves": {}` 整行替换为：
```gdscript
	"wave_templates": {},
```
`load_all()` 里这一行：
```gdscript
		loaded_tables[table_name] = _load_table(DATA_FILES[table_name], table_name == "waves")
```
替换为（模板按 `id` 索引，故 day-key 恒为 false）：
```gdscript
		loaded_tables[table_name] = _load_table(DATA_FILES[table_name], false)
```

- [ ] **Step 2: 替换查询函数**

把 `get_wave_cfg` 整个函数：
```gdscript
func get_wave_cfg(day: int) -> Dictionary:
	return _tables["waves"].get(day, {}).duplicate(true)
```
替换为：
```gdscript
func get_wave_template_cfg(template_id: StringName) -> Dictionary:
	return _tables["wave_templates"].get(template_id, {}).duplicate(true)


func get_wave_template_ids_by_tier(tier: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for template_id in _tables["wave_templates"].keys():
		var cfg: Dictionary = _tables["wave_templates"][template_id]
		if StringName(cfg.get("tier", "")) == tier:
			ids.append(StringName(template_id))
	return ids


func get_all_wave_template_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for template_id in _tables["wave_templates"].keys():
		ids.append(StringName(template_id))
	return ids
```

- [ ] **Step 3: 解析检查 + 启动冒烟**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script autoload/DataRepo.gd`
Expected: 无报错。
Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5 2>&1 | grep -iE "data_reload_failed|SCRIPT ERROR|Missing data" || echo CLEAN`
Expected: `CLEAN`（注意：此时 `waves.json` 仍在，但已不被加载；后续 Task 9 删除）。

- [ ] **Step 4: Commit**

```bash
git add autoload/DataRepo.gd
git commit -m "refactor(data): load wave_templates table, drop waves loading"
```

### Task 5: `RunState` 新增模板字段

**Files:**
- Modify: `autoload/RunState.gd`

- [ ] **Step 1: 新增字段**

在 `var random_seed: int = 0`（第 24 行）下一行插入：
```gdscript
var night_template_id: StringName = &""
var used_template_ids: Array[StringName] = []
```

- [ ] **Step 2: 在 reset_for_new_run 清空**

`reset_for_new_run` 里 `random_seed = seed` 之后插入：
```gdscript
	night_template_id = &""
	used_template_ids.clear()
```

- [ ] **Step 3: 解析检查**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script autoload/RunState.gd`
Expected: 无报错。

- [ ] **Step 4: Commit**

```bash
git add autoload/RunState.gd
git commit -m "feat(state): track resolved night template id on RunState"
```

---

## Phase 2 — 接入生成链路（夜晚按模板出怪）

### Task 6: `WaveManager` 改为按模板 id 解析/跑波/出预览

**Files:**
- Modify: `scripts/enemy/wave_manager.gd`

- [ ] **Step 1: 顶部加 resolver 预载**

文件顶部 `const AppRefs = preload("res://scripts/common/app_refs.gd")` 下一行加：
```gdscript
const Resolver = preload("res://scripts/enemy/night_template_resolver.gd")
```

- [ ] **Step 2: 新增解析入口 + 改 start/preview 走模板**

把现有 `start_wave_for_day(day)` 函数整体替换为下面三个函数（解析逻辑保留，只是数据源从 `get_wave_cfg(day)` 换成 `get_wave_template_cfg(template_id)`）：
```gdscript
func resolve_night_template(run_seed: int, day: int, used_ids: Array) -> StringName:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return StringName()
	var tier := Resolver.tier_for_day(day)
	var pool: Array[StringName] = data_repo.get_wave_template_ids_by_tier(tier)
	return Resolver.resolve(pool, used_ids, run_seed, day)


func start_wave_for_template(template_id: StringName) -> void:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or template_id == StringName():
		_pending_spawns.clear()
		_running = false
		return
	var cfg: Dictionary = data_repo.get_wave_template_cfg(template_id)
	_pending_spawns.clear()
	var raw_entries: Array = cfg.get("entries", [])
	for entry_index in range(raw_entries.size()):
		var entry_variant: Variant = raw_entries[entry_index]
		if typeof(entry_variant) == TYPE_DICTIONARY:
			var entry: Dictionary = _resolve_wave_entry(entry_variant as Dictionary, _seed_day_for(template_id), entry_index)
			if StringName(entry.get("enemy_id", "")) != StringName():
				_pending_spawns.append_array(_make_expanded_spawn_entries(entry))
	_pending_spawns.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	_elapsed = 0.0
	_running = true


func _seed_day_for(_template_id: StringName) -> int:
	var run_state = AppRefs.run_state()
	return int(run_state.day) if run_state != null else 0
```

> 说明：`_resolve_wave_entry` / `_pick_enemy_choice` / `_make_enemy_choice_seed` 维持原样（仍用 `run_seed+day+entry_index` 给 Boss 二选一播种），保证白天预览与夜晚同结果。

- [ ] **Step 3: 预览函数改走模板**

把 `get_wave_preview_for_day(day)` 函数签名与前两行：
```gdscript
func get_wave_preview_for_day(day: int) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return {}
	var cfg: Dictionary = _get_wave_cfg_with_fallback(data_repo, day)
```
替换为：
```gdscript
func get_wave_preview_for_template(template_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or template_id == StringName():
		return {}
	var cfg: Dictionary = data_repo.get_wave_template_cfg(template_id)
```
并把该函数内 `var day := ...` 相关的 day 用法替换：把 `_resolve_wave_entry(entry_variant as Dictionary, day, entry_index)` 中的 `day` 改为 `_seed_day_for(template_id)`；把返回字典里的 `"day": int(cfg.get("day", day))` 与 `"requested_day": day` 两行替换为：
```gdscript
		"template_id": template_id,
		"name": String(cfg.get("name", template_id)),
		"desc": String(cfg.get("desc", "")),
		"tier": StringName(cfg.get("tier", "")),
		"key_enemies": _resolve_key_enemies(cfg, entries_by_key, data_repo),
		"day": int(_seed_day_for(template_id)),
```

- [ ] **Step 4: 新增 key_enemies 推断 + 删除 day 兜底**

在文件末尾追加（缺省 key 推断：Boss/demolisher 优先，其次远程/术师，再次数量）：
```gdscript
func _resolve_key_enemies(cfg: Dictionary, entries_by_key: Dictionary, data_repo: Node) -> Array[StringName]:
	var declared: Array = cfg.get("key_enemies", [])
	if not declared.is_empty():
		var result: Array[StringName] = []
		for raw_id: Variant in declared:
			result.append(StringName(raw_id))
		return result
	# 自动推断：按威胁权重排序取前 2。
	var scored: Array[Dictionary] = []
	for aggregate_variant: Variant in entries_by_key.values():
		var aggregate: Dictionary = aggregate_variant
		var enemy_cfg: Dictionary = aggregate.get("enemy_cfg", {})
		scored.append({
			"enemy_id": StringName(aggregate.get("enemy_id", "")),
			"score": _threat_score(enemy_cfg, int(aggregate.get("count", 0)))
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("score", 0)) > float(b.get("score", 0)))
	var top: Array[StringName] = []
	for entry: Dictionary in scored:
		if StringName(entry.get("enemy_id", "")) != StringName():
			top.append(StringName(entry.get("enemy_id", "")))
		if top.size() >= 2:
			break
	return top


func _threat_score(enemy_cfg: Dictionary, count: int) -> float:
	var behavior := StringName(enemy_cfg.get("behavior_type", "normal"))
	var base := 0.0
	if behavior == &"boss":
		base = 1000.0
	elif behavior == &"demolisher":
		base = 100.0
	elif StringName(enemy_cfg.get("class", "")) == &"caster" or float(enemy_cfg.get("attack_range", 0.0)) > 1.5:
		base = 30.0
	return base + float(count)
```
并**删除** `_get_wave_cfg_with_fallback` 整个函数（不再有 day 兜底）。

- [ ] **Step 5: 解析检查**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/enemy/wave_manager.gd`
Expected: 无报错。

- [ ] **Step 6: Commit**

```bash
git add scripts/enemy/wave_manager.gd
git commit -m "refactor(waves): run waves and preview by template id"
```

### Task 7: `GameController.enter_day` 解析模板写 RunState

**Files:**
- Modify: `scripts/core/game_controller.gd`

- [ ] **Step 1: 加 WaveManager 引用**

在 `@onready var _unit_manager: Node = get_node_or_null("../UnitManager")` 下一行加：
```gdscript
@onready var _wave_manager: Node = get_node_or_null("../WaveManager")
```

- [ ] **Step 2: enter_day 中解析并存盘**

`enter_day` 里 `run_state.reset_action_points(run_state.DEFAULT_ACTION_POINTS)` 之后、`if _day_manager != null ...` 之前插入：
```gdscript
	if _wave_manager != null and _wave_manager.has_method("resolve_night_template"):
		var template_id: StringName = _wave_manager.resolve_night_template(run_state.random_seed, day, run_state.used_template_ids)
		run_state.night_template_id = template_id
		if template_id != StringName() and not run_state.used_template_ids.has(template_id):
			run_state.used_template_ids.append(template_id)
```

- [ ] **Step 3: 解析检查**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/core/game_controller.gd`
Expected: 无报错。

- [ ] **Step 4: Commit**

```bash
git add scripts/core/game_controller.gd
git commit -m "feat(flow): resolve night template at day start, store on RunState"
```

### Task 8: `NightManager` 读 RunState 模板起夜

**Files:**
- Modify: `scripts/core/night_manager.gd`

- [ ] **Step 1: 加 AppRefs 预载**

文件第一行 `extends Node` 下加：
```gdscript

const AppRefs = preload("res://scripts/common/app_refs.gd")
```

- [ ] **Step 2: start_night 改读模板**

把 `start_night` 函数体替换为：
```gdscript
func start_night(day: int) -> void:
	_night_running = true
	if _wave_manager == null:
		return
	var run_state = AppRefs.run_state()
	var template_id: StringName = run_state.night_template_id if run_state != null else &""
	if template_id != StringName() and _wave_manager.has_method("start_wave_for_template"):
		_wave_manager.start_wave_for_template(template_id)
	elif _wave_manager.has_method("start_wave_for_day"):
		_wave_manager.start_wave_for_day(day)
```

> `start_wave_for_day` 已在 Task 6 删除，这里 elif 分支恒为 false，仅作防御；保留可读性。如严格起见可删除 elif 分支。

- [ ] **Step 3: 解析检查 + 端到端冒烟**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/core/night_manager.gd`
Expected: 无报错。
Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 8 2>&1 | grep -iE "SCRIPT ERROR" || echo CLEAN`
Expected: `CLEAN`（主场景 bootstrap 进 day1，解析出 early 模板不报错）。

- [ ] **Step 4: Commit**

```bash
git add scripts/core/night_manager.gd
git commit -m "feat(flow): start night from resolved template id"
```

### Task 9: 删除 `data/waves.json`

**Files:**
- Delete: `data/waves.json`

- [ ] **Step 1: 删除并确认无引用**

Run: `git rm data/waves.json && grep -rn "waves.json\|get_wave_cfg\|_get_wave_cfg_with_fallback\|start_wave_for_day" scripts/ autoload/ scenes/ || echo NO_REFS`
Expected: 仅可能命中 `night_manager.gd` 里那条防御性 elif（若已删则 `NO_REFS`）。若命中其它实代码引用，回头修正。

- [ ] **Step 2: 启动冒烟**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5 2>&1 | grep -iE "SCRIPT ERROR|Missing data|reload_failed" || echo CLEAN`
Expected: `CLEAN`

- [ ] **Step 3: Commit**

```bash
git add -A data/waves.json
git commit -m "chore(waves): remove legacy per-day waves.json"
```

---

## Phase 3 — 右上角预览重构（v2）

### Task 10: enemy 立绘助手

**Files:**
- Create: `scripts/ui/combat/enemy_icon_helper.gd`

- [ ] **Step 1: 写助手**

写入 `scripts/ui/combat/enemy_icon_helper.gd`：
```gdscript
extends RefCounted
class_name EnemyIconHelper

const VISUAL_ROOT := "res://assets/sprites/enemies"


## 返回 enemy 立绘 idle_000.png；找不到返回 null（调用方做字形兜底）。
static func get_enemy_texture(enemy_cfg: Dictionary) -> Texture2D:
	var visual_key := String(enemy_cfg.get("visual_key", ""))
	if visual_key.is_empty():
		return null
	var path := "%s/%s/idle/%s_idle_000.png" % [VISUAL_ROOT, visual_key, visual_key]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## 字形兜底：取敌人名首字。
static func get_enemy_glyph(enemy_cfg: Dictionary) -> String:
	var name := String(enemy_cfg.get("name", "?"))
	return name.substr(0, 1) if name.length() > 0 else "?"
```

- [ ] **Step 2: 解析检查**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/ui/combat/enemy_icon_helper.gd`
Expected: 无报错。

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/combat/enemy_icon_helper.gd
git commit -m "feat(ui): add enemy idle-portrait icon helper"
```

### Task 11: `CombatHud.tscn` 预览面板 v2 子树

**Files:**
- Modify: `scenes/ui/combat/CombatHud.tscn`

> 这一步在 Godot 编辑器里改场景最稳妥（文本编辑 .tscn 易错）。目标节点树（替换原 `WavePreviewMargin/WavePreviewContent` 下的 `WavePreviewHeader`/`WavePreviewScroll`/`WavePreviewLabel`）：

- [ ] **Step 1: 重构 `WavePreviewPanel` 内容节点**

在 `HudChromeLayer/RightColumnSlot/RightColumnVBox/WavePreviewPanel/WavePreviewMargin/WavePreviewContent` 下，重排为：
- `TitleBlock` (VBoxContainer)
  - `DayBadgeLabel` (Label，`unique_name_in_owner=true`)
  - `LevelNameLabel` (Label，大字号，`unique_name_in_owner=true`)
  - `LevelDescLabel` (Label，小字，`autowrap_mode=3`，`unique_name_in_owner=true`)
- `TotalLine` (Label，`unique_name_in_owner=true`)
- `SpawnCardList` (VBoxContainer，`unique_name_in_owner=true`，`theme_override_constants/separation=6`) ← 运行时填充每口卡片
- `PreviewFooter` (HBoxContainer)
  - 把原 `WaveRouteToggle`（含其全部 `theme_override_styles` 与 `toggle_mode`/`text`/`icon`）移到此处，保持 `unique_name_in_owner=true` 与节点名 `WaveRouteToggle` 不变。

删除原 `WavePreviewScroll`、`WavePreviewLabel`、`WavePreviewHeader`、`WavePreviewTitleLabel`。`WavePreviewPanel` 的 `custom_minimum_size` 由 `Vector2(0,156)` 放宽到 `Vector2(0,200)`，并把 `size_flags_vertical` 设为 `3`（按内容增高，带上限由父 VBox 约束）。

- [ ] **Step 2: 校验场景可加载**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5 2>&1 | grep -iE "scene/resources|Failed loading|Parse Error|SCRIPT ERROR" || echo CLEAN`
Expected: `CLEAN`（注意：此时 `combat_hud.gd` 仍引用旧 `%WavePreviewLabel` 等，下一任务一起改完再整体验证；本步只确认 .tscn 本身能解析）。

- [ ] **Step 3: Commit**

```bash
git add scenes/ui/combat/CombatHud.tscn
git commit -m "feat(ui): restructure wave preview panel into title + spawn cards"
```

### Task 12: `combat_hud.gd` 结构化填充 `set_wave_preview_data`

**Files:**
- Modify: `scripts/ui/combat/combat_hud.gd`

- [ ] **Step 1: 换 @onready 节点引用**

把第 139–142 行的四个预览 `@onready`：
```gdscript
@onready var _wave_preview_panel: Control = %WavePreviewPanel
@onready var _wave_preview_title_label: Label = %WavePreviewTitleLabel
@onready var _wave_route_toggle: Button = %WaveRouteToggle
@onready var _wave_preview_label: Label = %WavePreviewLabel
```
替换为：
```gdscript
@onready var _wave_preview_panel: Control = %WavePreviewPanel
@onready var _wave_day_badge_label: Label = %DayBadgeLabel
@onready var _wave_level_name_label: Label = %LevelNameLabel
@onready var _wave_level_desc_label: Label = %LevelDescLabel
@onready var _wave_total_line_label: Label = %TotalLine
@onready var _wave_spawn_card_list: VBoxContainer = %SpawnCardList
@onready var _wave_route_toggle: Button = %WaveRouteToggle
```
并加预载（文件顶部 const 区）：
```gdscript
const EnemyIconHelper = preload("res://scripts/ui/combat/enemy_icon_helper.gd")
```

- [ ] **Step 2: 修 `_ready` 里引用旧节点的样式代码**

第 172–179 行对 `_wave_preview_title_label` / `_wave_preview_label` 的 `add_theme_*` 调用全部删除；保留对 `_wave_route_toggle` 的样式与 `_style_wave_route_toggle()`。给新标签设字色：在原位置改为：
```gdscript
	_wave_level_name_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	_wave_level_desc_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_wave_total_line_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_wave_day_badge_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
```

- [ ] **Step 3: 替换 `set_wave_preview_text` 为 `set_wave_preview_data`**

把 `set_wave_preview_text` 整个函数替换为：
```gdscript
func set_wave_preview_data(data: Dictionary, show_panel: bool = true) -> void:
	if data.is_empty():
		_wave_preview_panel.visible = false
		return
	_wave_preview_panel.visible = show_panel
	_wave_day_badge_label.text = "DAY %d · 今夜" % int(data.get("day", 0))
	_wave_level_name_label.text = String(data.get("name", ""))
	_wave_level_desc_label.text = String(data.get("desc", ""))
	var spawn_order: Array = data.get("spawn_order", [])
	_wave_total_line_label.text = "合计来袭 %d · 活跃出怪口 %d" % [int(data.get("total_count", 0)), spawn_order.size()]
	_populate_spawn_cards(data)


func _populate_spawn_cards(data: Dictionary) -> void:
	for child in _wave_spawn_card_list.get_children():
		child.queue_free()
	var key_enemies: Array = data.get("key_enemies", [])
	# 按 spawn_key 分组 entries。
	var by_spawn: Dictionary = {}
	for entry_variant: Variant in data.get("entries", []):
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var sk := String(entry.get("spawn_key", ""))
		if not by_spawn.has(sk):
			by_spawn[sk] = []
		(by_spawn[sk] as Array).append(entry)
	for spawn_key_variant: Variant in data.get("spawn_order", []):
		var sk := String(spawn_key_variant)
		_wave_spawn_card_list.add_child(_build_spawn_card(sk, by_spawn.get(sk, []), key_enemies))


func _build_spawn_card(spawn_key: String, entries: Array, key_enemies: Array) -> Control:
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	var key_label := Label.new()
	key_label.text = spawn_key
	key_label.custom_minimum_size = Vector2(28, 0)
	key_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	card.add_child(key_label)
	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry_variant: Variant in entries:
		var entry: Dictionary = entry_variant
		chips.add_child(_build_enemy_chip(entry, key_enemies))
	card.add_child(chips)
	return card


func _build_enemy_chip(entry: Dictionary, key_enemies: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var enemy_cfg: Dictionary = entry.get("enemy_cfg", {})
	var tex := EnemyIconHelper.get_enemy_texture(enemy_cfg)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	else:
		var glyph := Label.new()
		glyph.text = EnemyIconHelper.get_enemy_glyph(enemy_cfg)
		row.add_child(glyph)
	var label := Label.new()
	label.text = "%s×%d" % [String(entry.get("enemy_name", entry.get("enemy_id", ""))), int(entry.get("count", 0))]
	var is_key := key_enemies.has(StringName(entry.get("enemy_id", "")))
	label.add_theme_color_override("font_color", GameUiStyle.ACCENT if is_key else GameUiStyle.TEXT_INVERTED_DIM)
	row.add_child(label)
	return row
```

> 若 `GameUiStyle` 没有 `ACCENT` 常量，用其已有的高亮色常量替代（实现时 `grep "const .*Color" scripts/ui/game_ui_style.gd` 确认，例如金色高亮）。

- [ ] **Step 4: 解析检查**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/ui/combat/combat_hud.gd`
Expected: 无报错（若报 `GameUiStyle.ACCENT` 不存在，按上面注释替换常量名后重跑）。

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/combat/combat_hud.gd
git commit -m "feat(ui): populate wave preview from structured template data"
```

### Task 13: 控制器改喂结构化预览数据

**Files:**
- Modify: `scripts/ui/combat/combat_hud_controller.gd`

- [ ] **Step 1: `_refresh_wave_preview` 改用模板预览**

把 `_refresh_wave_preview` 中取数据这段：
```gdscript
	var preview: Dictionary = _wave_manager.get_wave_preview_for_day(int(run_state.day)) if _wave_manager.has_method("get_wave_preview_for_day") else {}
	if preview.is_empty():
		_last_wave_preview_signature = ""
		_set_wave_preview_text("今晚敌情\n暂无波次配置", true)
		_clear_wave_routes()
		return
```
替换为：
```gdscript
	var template_id: StringName = run_state.night_template_id
	var preview: Dictionary = _wave_manager.get_wave_preview_for_template(template_id) if _wave_manager.has_method("get_wave_preview_for_template") else {}
	if preview.is_empty():
		_last_wave_preview_signature = ""
		_set_wave_preview_data({}, false)
		_clear_wave_routes()
		return
```

- [ ] **Step 2: 末尾推送结构化数据**

把 `_refresh_wave_preview` 末尾：
```gdscript
	_set_wave_preview_text(_format_wave_preview_text(preview, _latest_wave_routes, hover_cell), true)
```
替换为：
```gdscript
	_set_wave_preview_data(preview, true)
```

- [ ] **Step 3: 替换 `_set_wave_preview_text` / `_clear_wave_preview` / 删除文本格式化**

把 `_set_wave_preview_text` 函数替换为：
```gdscript
func _set_wave_preview_data(data: Dictionary, show_panel: bool) -> void:
	_wave_preview_active = show_panel and not data.is_empty()
	if _combat_hud != null and _combat_hud.has_method("set_wave_preview_data"):
		_combat_hud.set_wave_preview_data(data, show_panel)
```
把 `_clear_wave_preview` 里：
```gdscript
	_latest_wave_preview_text = ""
	_set_wave_preview_text("", false)
```
替换为：
```gdscript
	_set_wave_preview_data({}, false)
```
其它分支里出现的 `_set_wave_preview_text("今晚敌情\n地图或波次数据加载中...", true)` 替换为 `_set_wave_preview_data({}, false)`。
删除 `_format_wave_preview_text` 整个函数（其调用的 `_collect_route_legend_lines` 若不再被引用一并删除；`_collect_route_warning_lines` 保留，仍供路线叠加层使用）。删除已不再使用的 `var _latest_wave_preview_text := ""` 声明。

- [ ] **Step 4: 解析检查 + 全场景冒烟**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/ui/combat/combat_hud_controller.gd`
Expected: 无报错（若报某 `_collect_route_legend_lines` 未定义/未使用，按提示清理）。
Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 8 2>&1 | grep -iE "SCRIPT ERROR" || echo CLEAN`
Expected: `CLEAN`

- [ ] **Step 5: 人工验收（预览）**

打开主场景 `scenes/game/Game.tscn` 运行，进入白天：右上角应显示**关卡名 + 文案 + 合计行 + 每出怪口一张横向卡片（敌人立绘+数量，关键敌高亮）**，不再是滚动文本。

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/combat/combat_hud_controller.gd
git commit -m "feat(ui): drive wave preview panel with structured template data"
```

---

## Phase 4 — 白天关卡预告横幅（方案 A）

### Task 14: `LevelIntroBanner` 节点

**Files:**
- Modify: `scenes/ui/combat/CombatHud.tscn`

- [ ] **Step 1: 加居中横幅节点**

在 `HudChromeLayer` 下新增 `LevelIntroBanner` (Control，`unique_name_in_owner=true`，`mouse_filter=2`(IGNORE)，全屏锚点 `anchors_preset=15`，初始 `visible=false`)，子节点：
- `Center` (VBoxContainer，居中：`anchors_preset=8`，`alignment=1`)
  - `BannerDayBadge` (Label，`unique_name_in_owner=true`)
  - `BannerName` (Label，大字号，`horizontal_alignment=1`，`unique_name_in_owner=true`)
  - `BannerUnderline` (ColorRect，`custom_minimum_size=Vector2(0,2)`，`unique_name_in_owner=true`)
  - `BannerDesc` (Label，`horizontal_alignment=1`，`autowrap_mode=3`，`custom_minimum_size=Vector2(520,0)`，`unique_name_in_owner=true`)

- [ ] **Step 2: 场景可加载**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5 2>&1 | grep -iE "Failed loading|Parse Error|SCRIPT ERROR" || echo CLEAN`
Expected: `CLEAN`

- [ ] **Step 3: Commit**

```bash
git add scenes/ui/combat/CombatHud.tscn
git commit -m "feat(ui): add level intro banner node to combat hud"
```

### Task 15: 横幅播放逻辑（卷轴展开，Tween）

**Files:**
- Modify: `scripts/ui/combat/combat_hud.gd`

- [ ] **Step 1: 加 @onready 引用**

const/@onready 区加：
```gdscript
@onready var _banner_root: Control = %LevelIntroBanner
@onready var _banner_day_badge: Label = %BannerDayBadge
@onready var _banner_name: Label = %BannerName
@onready var _banner_underline: ColorRect = %BannerUnderline
@onready var _banner_desc: Label = %BannerDesc
```

- [ ] **Step 2: 加播放方法**

文件末尾追加：
```gdscript
func play_level_intro(day: int, level_name: String, desc: String) -> void:
	if level_name.strip_edges().is_empty():
		return
	_banner_day_badge.text = "DAY %d · 今夜来袭" % day
	_banner_name.text = level_name
	_banner_desc.text = desc
	_banner_root.visible = true
	# 初值
	_banner_day_badge.modulate.a = 0.0
	_banner_name.modulate.a = 0.0
	_banner_name.position.y = 16.0
	_banner_desc.modulate.a = 0.0
	_banner_underline.custom_minimum_size.x = 0.0
	var full_w := 360.0
	var hold := 1.6 + clampf(float(desc.length()) * 0.02, 0.0, 1.4)
	var tw := create_tween()
	tw.tween_property(_banner_day_badge, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_banner_name, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(_banner_name, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_banner_underline, "custom_minimum_size:x", full_w, 0.25)
	tw.parallel().tween_property(_banner_desc, "modulate:a", 1.0, 0.25)
	tw.tween_interval(hold)
	tw.tween_property(_banner_root, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		_banner_root.visible = false
		_banner_root.modulate.a = 1.0
	)
```

- [ ] **Step 3: 解析检查**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/ui/combat/combat_hud.gd`
Expected: 无报错。

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/combat/combat_hud.gd
git commit -m "feat(ui): animate level intro banner (scroll-open)"
```

### Task 16: `day_started` 触发横幅

**Files:**
- Modify: `scripts/ui/combat/combat_hud_controller.gd`

- [ ] **Step 1: `_on_day_started` 播放横幅**

把 `_on_day_started` 函数体：
```gdscript
func _on_day_started(_day: int) -> void:
	_refresh_top_hud()
	_force_wave_preview_refresh()
```
替换为：
```gdscript
func _on_day_started(day: int) -> void:
	_refresh_top_hud()
	_force_wave_preview_refresh()
	_play_level_intro_banner(day)


func _play_level_intro_banner(day: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null or _wave_manager == null or _combat_hud == null:
		return
	if not _wave_manager.has_method("get_wave_preview_for_template") or not _combat_hud.has_method("play_level_intro"):
		return
	var preview: Dictionary = _wave_manager.get_wave_preview_for_template(run_state.night_template_id)
	if preview.is_empty():
		return
	_combat_hud.play_level_intro(day, String(preview.get("name", "")), String(preview.get("desc", "")))
```

- [ ] **Step 2: 解析检查 + 人工验收（横幅）**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/ui/combat/combat_hud_controller.gd`
Expected: 无报错。
人工：运行 `scenes/game/Game.tscn`，进入白天瞬间应看到居中「DAY N → 关卡名上浮 → 下划线展开 → 文案淡入 → 停留 → 淡出」，期间仍可操作（不暂停、不挡点击）。

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/combat/combat_hud_controller.gd
git commit -m "feat(ui): play level intro banner on day start"
```

---

## Phase 5 — 文档与最终验收

### Task 17: 同步文档

**Files:**
- Modify: `docs/DATA_SCHEMA.md`
- Modify: `docs/UI_SYSTEM.md`

- [ ] **Step 1: DATA_SCHEMA**

在 `docs/DATA_SCHEMA.md` 中：删除/标注 `waves.json` 段为「已退役」；新增 `wave_templates.json` 段，描述字段 `id/name/desc/tier/key_enemies/entries`（entries 沿用旧 waves 条目格式：`time/enemy_id/spawn_key/count/interval/enemy_choices`），并说明 `tier∈{early,mid,late,boss}`、`day→tier` 曲线在 `night_template_resolver.gd`。

- [ ] **Step 2: UI_SYSTEM**

在 `docs/UI_SYSTEM.md` 中：更新右上角「出怪预览」段为 v2 结构（标题区关卡名+文案 / 合计行 / 每出怪口横向卡片 / 路线开关）；新增「白天关卡预告横幅 `LevelIntroBanner`」段，说明触发于 `day_started`、卷轴展开动效、不阻塞。

- [ ] **Step 3: Commit**

```bash
git add docs/DATA_SCHEMA.md docs/UI_SYSTEM.md
git commit -m "docs: update data schema and ui system for night templates"
```

### Task 18: 最终一致性验收

- [ ] **Step 1: 跑数据/解析自测**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/debug/test_wave_templates.gd`
Expected: `ALL WAVE TEMPLATE TESTS PASSED`

- [ ] **Step 2: 全工程解析 + 启动冒烟**

Run: `git diff --check`（无空白错误）
Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 10 2>&1 | grep -iE "SCRIPT ERROR|reload_failed|Missing" || echo CLEAN`
Expected: `CLEAN`

- [ ] **Step 3: 人工一致性验收（关键）**

运行 `scenes/game/Game.tscn`：
- 白天横幅关卡名 == 右上角预览关卡名。
- 点开夜晚，实际出怪种类/出怪口分布 == 白天预览所示（含 day6 Boss 二选一显示的那只 == 实际刷出的那只）。
- 通关一晚 → `night_cleared` → 祝福 → 下一天换新关卡名；同一存档重开（同 seed）关卡序列可复现。
- day6 Boss 终局正常结算。

- [ ] **Step 4: 收尾**

参考 superpowers:finishing-a-development-branch 决定合并/PR。PR body 用 `Closes #210`，并在说明里列出：删除 waves.json、新增 15 模板、预览 v2、横幅 A、#177/#215 留作前向接口。

---

## Self-Review（已核对）

- **Spec 覆盖**：§4 数据→Task1/4；解析§5→Task2/5/7；WaveManager§5.3→Task6；NightManager→Task8；预览 v2 §6→Task10–13；横幅§7→Task14–16；删除 waves §8→Task9；文档§8→Task17；测试§9→Task3/18；#177/#215 §10→resolver 曲线注释（Task2）。无遗漏。
- **占位扫描**：无 TBD；每个改代码步骤给出实际代码或精确节点结构。两处需实现期 `grep` 确认的点（`GameUiStyle` 高亮常量名、`_collect_route_legend_lines` 是否仍被引用）已显式标注确认命令，非占位。
- **类型一致**：`resolve_night_template(run_seed, day, used_ids)`、`start_wave_for_template(template_id)`、`get_wave_preview_for_template(template_id)`、`set_wave_preview_data(data, show_panel)`、`play_level_intro(day, name, desc)`、RunState `night_template_id`/`used_template_ids`、DataRepo `get_wave_template_cfg`/`get_wave_template_ids_by_tier` 在各任务间签名一致。
