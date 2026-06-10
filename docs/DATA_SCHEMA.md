# DATA_SCHEMA

## 1. 数据文件总览

项目静态配置统一放在 `res://data/`：

```text
data/
├─ units.json
├─ enemies.json
├─ buildings.json
├─ buffs.json
├─ events.json
├─ wave_templates.json
├─ night_affixes.json
├─ map_generation.json
└─ ui_icons.json
```

各文件用途：

- `units.json`
  单位静态配置。
- `enemies.json`
  敌人静态配置。
- `buildings.json`
  建筑静态配置。
- `buffs.json`
  遗物静态配置。旧接口仍沿用 buff 命名以兼容现有代码。
- `events.json`
  随机事件静态配置。
- `wave_templates.json`
  夜晚关卡模板池。运行时按天数阶段和本局随机种子解析出当晚的多波模板计划。
- `night_affixes.json`
  夜晚词缀池。每晚按天数与本局随机种子抽取 0-2 条全局修饰，清晨随敌情预览公示。
- `map_generation.json`
  地图生成与探索相关调参配置。
- `ui_icons.json`
  非实体 UI 图标目录，例如资源、阶段、属性、图例、通用按钮和音量图标。

这些文件只保存静态配置，不保存一局游戏的运行时状态。

---

## 2. 通用规则

### 2.1 顶层结构

- 配置表 JSON 文件顶层统一使用数组。
- 数组中的每一项代表一条记录。
- 全局调参文件可以使用对象结构，例如 `map_generation.json`。

### 2.2 `id`

- 每条记录必须有唯一标识。
- 单位、敌人、建筑、Buff、事件、夜晚关卡模板统一使用 `id`。

### 2.3 命名规则

- `id` 使用英文小写加下划线。
- 中文显示名称统一放在 `name`。
- 不使用中文名作为程序主键。

示例：

- `guard_01`
- `archer_basic`
- `slime`
- `medical_station`
- `buff_atk_up_small`

### 2.4 字段规则

- 行为差异必须使用明确字段表达，不写进备注。
- 数值字段必须给默认值，不省略字段。
- 同类对象尽量保持字段结构一致。

### 2.5 `scene_key`

配置表中不直接写 `res://scenes/...` 路径，而是写 `scene_key`。

`scene_key` 的作用是：在配置表中声明“这条配置应该实例化哪一种场景模板”。

例如：

```text
scene_key: unit_actor
```

这表示该配置项在运行时需要使用“单位模板”生成实例。  
实际场景文件路径由 `DataRepo` 负责映射，例如：

```text
unit_actor -> scenes/actors/UnitActor.tscn
enemy_actor -> scenes/actors/EnemyActor.tscn
building_actor -> scenes/actors/BuildingActor.tscn
```

### 2.6 UI 图标字段

如果某条配置需要在 UI 中显示图标，新数据优先写明确资源路径：

- `icon_path`：实体主图标，完整 `res://` 路径。
- `class_icon_path`：单位职业图标，完整 `res://` 路径。
- `skill_icon_path`：单位技能图标，完整 `res://` 路径。
- `portrait_path`：单位头像路径；当前没有头像资产时可以省略。
- `ui_icon_path`：历史兼容字段，优先级低于 `icon_path`。
- `icon_key`：旧逻辑键，仅用于旧数据兼容，不应作为新 UI 的正常图标来源。
- `icon_text`：图片缺失时的最终文本兜底。

UI 必须通过 `UiArtRegistry` 读取图标，读取优先级为：显式路径字段、兼容路径字段、旧 `icon_key`、调用方传入的 catalog fallback，最后才显示 `icon_text`。

### 2.7 UI 显示字段与统一显示工具

配置表中对象自身的显示信息优先写在数据里：

- `name`：显示名称。
- `desc`：说明文本。
- `icon_path` / `class_icon_path` / `skill_icon_path` / `portrait_path`：图片资产路径。
- `icon_text`：无真实图标时的占位图标文本，只作兜底。

跨 UI 复用的显示规则不应散落在各 UI 脚本中，例如：

- `class` 到职业中文名。
- `cost_prestige` 到临时阶级名和阶级颜色。
- 伤害类型枚举到中文标签。
- 阶段枚举到中文标签。
- 朝向向量到中文标签。

这些规则由 `scripts/ui/ui_display_text.gd` 统一提供。UI 分层与重构构想见 `docs/UI_SYSTEM.md`。

---

## 3. `units.json`

作用：

- 定义单位的职业、数值、攻击范围、技能和部署相关配置。

记录示例：

```json
[
  {
    "id": "guard_01",
    "name": "二阶近卫",
    "class": "guard",
    "cost_prestige": 3,
    "max_hp": 135,
    "atk": 34,
    "def": 12,
    "res": 0,
    "block": 2,
    "attack_interval": 1.0,
    "damage_type": "physical",
    "target_type": "ground",
    "range_pattern": [[0, 0], [1, 0]],
    "redeploy_sec": 12.0,
    "sp_max": 18,
    "sp_initial": 8,
    "sp_recover_per_sec": 1.0,
    "skill_id": "guard_hold_line",
    "skill_name": "战术咏唱·阵线压制",
    "skill_description": "阻挡数+1，普通攻击同时攻击所有被自身阻挡的敌人，持续10秒。",
    "skill_duration": 10.0,
    "skill_block_bonus": 1,
    "scene_key": "unit_actor",
    "skill_behavior_key": "guard_hold_line",
    "class_icon_path": "res://assets/ui/generated/icon_class_guard.png",
    "skill_icon_path": "res://assets/ui/generated/icon_skill_guard_hold_line.png",
    "icon_text": "煌"
  }
]
```

必填字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | 单位唯一标识 |
| `name` | `String` | 显示名称 |
| `class` | `String` | 职业类型 |
| `cost_prestige` | `int` | 购买所需声望 |
| `max_hp` | `int` | 最大生命 |
| `atk` | `int` | 攻击力 |
| `def` | `int` | 物理防御 |
| `res` | `int` | 法术抗性 |
| `block` | `int` | 阻挡数 |
| `attack_interval` | `float` | 攻击间隔 |
| `damage_type` | `String` | 伤害类型 |
| `range_pattern` | `Array` | 攻击范围格子模式 |
| `redeploy_sec` | `float` | 再部署冷却时间 |
| `sp_max` | `int` | 技能所需最大 SP |
| `scene_key` | `String` | 单位模板逻辑名 |

常用可选字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `target_type` | `String` | 攻击目标类型；只使用 `ground`、`flying`、`all`，未配置或非法值按 `ground` 处理 |
| `attack_delivery` | `String` | 普攻命中形式；`instant` 为即时命中，`projectile` 为飞行物命中，未配置默认 `instant` |
| `projectile_scene_key` | `String` | 飞行物场景逻辑名，未配置默认 `projectile` |
| `projectile_speed` | `float` | 飞行物追踪速度 |
| `projectile_hit_radius` | `float` | 飞行物命中半径 |
| `projectile_lifetime` | `float` | 飞行物最大存活时间，未配置默认 3 秒 |
| `sp_initial` | `float` | 部署时初始 SP；未配置默认 0 |
| `sp_recover_per_sec` | `float` | 每秒回复 SP |
| `skill_id` | `String` | 技能标识 |
| `skill_behavior_key` | `String` | 技能行为脚本逻辑名，未配置时默认回退到 `skill_id` |
| `class_icon_path` | `String` | 职业图标路径，优先用于干员卡与详情 UI |
| `skill_icon_path` | `String` | 技能图标路径，优先用于技能展示 |
| `portrait_path` | `String` | 头像路径；当前没有头像资产时可省略 |
| `icon_text` | `String` | 图片缺失时的文本兜底 |

### 3.1 运行时干员槽位

干员槽位不是独立配置表，而是 `RunState`、存档和调试 preset 中使用的运行时结构。
它表示玩家拥有的一名可部署干员实例，而不是一个单位类型。

结构示例：

```json
{
  "key": "G1",
  "unit_id": "guard_01",
  "name": "近卫A",
  "star": 1
}
```

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `key` | `String` | 槽位唯一标识；部署、撤退、再部署 CD 均按该值结算 |
| `unit_id` | `String` | 引用 `units.json[].id`，决定基础数值、攻击范围、技能和再部署时间 |
| `name` | `String` | UI 显示名；允许同类单位用不同槽位名区分 |
| `star` | `int` | 干员星级，范围 1-3；缺省按 1 处理 |

同一个 `unit_id` 可以出现在多个槽位中。`units.json[].redeploy_sec` 是单位类型默认再部署时间，但实际冷却状态属于具体槽位。

星级用于表达自动合成后的进阶强度。当前 `units.json` 中的数值视为 1 星基线；新购买干员默认为 1 星，`max_hp`、`atk`、`def`、`res` 为 100%；2 星为 160%；3 星为 230%。星级不改变费用、阻挡数、攻击间隔、射程、SP 或技能参数；任意星级出售时均固定返还 1 声望。

---

## 4. `enemies.json`

作用：

- 定义敌人的数值、行为类型、移动方式和对核心造成的伤害。

记录示例：

```json
[
  {
    "id": "slime",
    "name": "源石虫",
    "max_hp": 80,
    "atk": 18,
    "def": 2,
    "res": 0,
    "move_speed": 1.0,
    "attack_interval": 1.2,
    "damage_type": "physical",
    "behavior_type": "normal",
    "move_type": "ground",
    "core_damage": 1,
    "prestige_reward": 1,
    "scene_key": "enemy_actor"
  }
]
```

必填字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | 敌人唯一标识 |
| `name` | `String` | 显示名称 |
| `max_hp` | `int` | 最大生命 |
| `atk` | `int` | 攻击力 |
| `def` | `int` | 物理防御 |
| `res` | `int` | 法术抗性 |
| `move_speed` | `float` | 移动速度 |
| `attack_interval` | `float` | 攻击间隔 |
| `behavior_type` | `String` | 行为类型；当前使用 `normal`、`demolisher`、`boss` 等策略语义，移速差异统一由 `move_speed` 表达，不另设 `rush` 等速度型行为 |
| `move_type` | `String` | 移动类型；只使用 `ground`、`flying`，未配置或非法值按 `ground` 处理 |
| `core_damage` | `int` | 抵达核心时造成的伤害 |
| `prestige_reward` | `int` | 被击杀时奖励的声望；进入核心消失不发放 |
| `scene_key` | `String` | 敌人模板逻辑名 |

常用可选字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `damage_type` | `String` | 伤害类型 |
| `attack_range` | `int` | 攻击范围，按棋盘格切比雪夫距离计算；未配置或小于等于 0 时只攻击阻挡单位 |
| `block_weight` | `int` | 占用阻挡数；未配置默认 1，适合大体型敌人占用多个阻挡位 |
| `shield_hp` | `int` | 额外护盾值；护盾会先吸收结算后的伤害，归零后才损失生命 |
| `regen_per_sec` | `float` | 每秒生命回复量；仅在敌人受伤且仍存活时生效 |
| `death_area_damage` | `Dictionary` | 被击杀时触发的死亡爆发，支持 `radius`、`damage`、`damage_type`；进入核心离场不触发 |
| `death_spawn` | `Array` / `Dictionary` | 被击杀时生成额外敌人；每项包含 `enemy_id`、`count`、`radius`，生成位置优先选择死亡格周围可通行格 |
| `boss_controller_key` | `String` | Boss 阶段控制器逻辑名；未配置时默认使用通用 `phase_boss` |
| `boss_behavior_key` | `String` | 未来 Boss 专属行为组件逻辑名；用于召唤、护盾循环、地图效果等非通用机制 |
| `phase_transition_sec` | `float` | Boss 当前阶段 HP 耗尽后的无敌转阶段时长，期间不移动也不攻击 |
| `phases` | `Array` | Boss 后续阶段配置；仅 Boss 使用，每项通过 `phase` 标识阶段编号，并可覆盖基础数值 |
| `phase_enter_area_damage` | `Dictionary` | 进入该阶段时触发的区域伤害，支持 `radius`、`damage`、`damage_type` |

Boss 多阶段规则：

- 普通敌人不配置 `phases`。
- 运行时中，`behavior_type: "boss"` 或存在非空 `phases` 时启用 `BossController`。
- `BossController` 负责读取 `phases`、转阶段无敌计时和阶段进入效果。
- 阶段配置项可以覆盖 `name`、`max_hp`、`atk`、`def`、`res`、`move_speed`、`attack_interval`、`attack_range`、`damage_type`、`behavior_type`、`move_type`、`core_damage` 等基础字段。
- 多个 Boss 的共性阶段机制优先通过 `phases` 数据表达，不在代码中按 `enemy_id` 写分支。
- `boss_behavior_key` 只用于数据表达不了的 Boss 专属机制；当前可先预留，不要求已有实现。

---

## 5. `buildings.json`

作用：

- 定义建筑种类、建造成本、效果类型和放置规则。

记录示例：

```json
[
  {
    "id": "medical_station",
    "name": "医疗站",
    "desc": "一定范围内的友军持续回复 2 生命/秒",
    "building_type": "aura",
    "sort_order": 110,
    "icon_path": "res://assets/ui/generated/icon_building_medical_station.png",
    "icon_text": "疗",
    "visual_key": "medical_station",
    "destroyed_visual_key": "generic_destroyed_building",
    "max_hp": 380,
    "cost_wood": 2,
    "cost_stone": 1,
    "cost_mana": 0,
    "ap_cost": 2,
    "blocks_path": false,
    "effect_radius": 2,
    "effect_shape": "trimmed_square",
    "effect_type": "heal",
    "effect_value": 2,
    "place_rule": "plain_only",
    "scene_key": "building_actor"
  }
]
```

必填字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | 建筑唯一标识 |
| `name` | `String` | 显示名称 |
| `desc` | `String` | 建筑说明；部分动态效果建筑会在 UI 中按效果字段生成说明 |
| `building_type` | `String` | 建筑类别 |
| `max_hp` | `int` | 最大生命 |
| `cost_wood` | `int` | 木材消耗 |
| `cost_stone` | `int` | 石材消耗 |
| `cost_mana` | `int` | 魔力消耗 |
| `ap_cost` | `int` | 行动力消耗 |
| `blocks_path` | `bool` | 是否阻挡路径 |
| `place_rule` | `String` | 放置规则 |
| `scene_key` | `String` | 建筑模板逻辑名 |

常用可选字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `effect_radius` | `int` | 效果半径 |
| `effect_shape` | `String` | 效果范围形状；`trimmed_square` 表示方形范围去掉四个角 |
| `effect_type` | `String` | 效果类型 |
| `effect_value` | `int` / `float` | 效果数值 |
| `sort_order` | `int` | UI 排序值；`BuildPanel` 按该值从小到大显示，同值按 `id` 排序 |
| `icon_path` | `String` | 建筑图标路径，`BuildPanel` 优先通过统一接口读取 |
| `icon_text` | `String` | 图片缺失时的文本兜底 |
| `visual_key` | `String` | 建筑正常状态贴图逻辑名，默认按 `assets/sprites/buildings/` 下的同名资源查找 |
| `active_visual_key` | `String` | 可开关建筑开启状态贴图逻辑名，例如战火圣坛开启态 |
| `inactive_visual_key` | `String` | 可开关建筑关闭状态贴图逻辑名，例如战火圣坛关闭态 |
| `destroyed_visual_key` | `String` | 建筑完全损毁状态贴图逻辑名，缺省时使用 `generic_destroyed_building` |
| `wall_visual_prefix` | `String` | 木墙连接变体前缀；运行时组合为 `<prefix>_0001_n` 等 16 种四邻接贴图名 |
| `visual_display_size` | `float` | 建筑贴图在地图上的显示尺寸，默认 `72`，用于让 128px 贴图覆盖 64px 逻辑格并减少连接缝 |
| `hidden_in_build_panel` | `bool` | 是否从建筑面板隐藏，适合未开放或调试建筑 |

`BuildPanel` 不维护独立建筑清单。建筑是否出现在某个标签页，由 `building_type` 决定：

- `resource`：资源建筑。
- `aura`：增益/光环建筑。
- `block`：防御/路径阻挡建筑。

---

## 6. `wave_templates.json`

作用：

- 定义夜晚关卡模板池，包括关卡名称、预览文案、分层标签和刷怪计划。
- 运行时由 `GameController` / `WaveManager` 根据当前天数、`RunState.random_seed` 和已使用模板解析出当晚的**多波模板计划**（`RunState.night_wave_template_ids`，`night_template_id` 始终等于首波作兼容视图）；不要在该表中写入运行时状态。
- 每晚波数与档位由 `scripts/enemy/night_template_resolver.gd` 的 `WAVE_TIERS_BY_DAY` 维护：第 1 夜 1 波（early），第 2 夜 2 波（early），第 3 夜 early+mid，第 4 夜 2 波（mid），第 5 夜 mid+late+late，第 6 夜 late+boss。
- 波间节奏由 `scripts/enemy/wave_manager.gd` 维护：上一波清场后 12 秒开下一波；残敌拖延超过 45 秒则强制开下一波。

记录示例：

```json
[
  {
    "id": "slug_tide",
    "name": "虫潮涌流",
    "desc": "第一声警铃响起时，地缝里先钻出黏滑的虫群。它们不懂恐惧，只顺着灯光往核心涌来。",
    "tier": "early",
    "key_enemies": ["hound"],
    "entries": [
      { "time": 0.0, "enemy_id": "slime", "spawn_key": "S1", "count": 8, "interval": 0.45 },
      { "time": 3.0, "enemy_id": "hound", "spawn_key": "S2", "count": 8, "interval": 0.55 }
    ]
  },
  {
    "id": "fiends_carnival",
    "name": "狂欢之主",
    "desc": "鼓点从黑暗深处传来，奶龙酋长被一队披甲护卫簇拥上场。它像在赴宴，沿途却只留下被踩碎的路。",
    "tier": "boss",
    "key_enemies": ["milk_dragon_chief"],
    "entries": [
      {
        "time": 8.0,
        "spawn_key": "S2",
        "count": 1,
        "interval": 0.0,
        "enemy_id": "milk_dragon_chief"
      }
    ]
  }
]
```

顶层字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | 模板唯一标识，使用英文小写加下划线 |
| `name` | `String` | 关卡标题，显示在右上角敌情面板和开局横幅中 |
| `desc` | `String` | 关卡预览文案，显示在右上角敌情面板和开局横幅中 |
| `tier` | `String` | 模板分层。当前允许 `early`、`mid`、`late`、`boss` |
| `key_enemies` | `Array[String]` | 关键敌人 ID，用于预览面板优先展示威胁点 |
| `entries` | `Array` | 本模板的刷怪条目列表 |

`entries` 中每条记录基础字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `time` | `float` | 从夜晚开始后的触发时间 |
| `enemy_id` | `String` | 敌人配置 ID；当 `enemy_choices` 有有效候选时可省略 |
| `spawn_key` | `String` | 刷怪点逻辑名 |
| `count` | `int` | 生成数量 |
| `interval` | `float` | 同组敌人之间的生成间隔 |

`entries` 中每条记录常用可选字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `enemy_choices` | `Array` | 随机敌人候选池；每项包含 `enemy_id` 和可选 `weight`。运行时按本局随机种子、模板 ID 和条目序号确定选择，白天预览与夜晚实际刷怪保持一致 |

---

## 6.1 `night_affixes.json`

作用：

- 定义夜晚词缀池。每晚白天开始时由 `GameController` 按 `RunState.random_seed` 与天数确定性抽取，存入 `RunState.night_affix_ids` 并在敌情预览中公示。
- 每晚词缀数量由 `scripts/enemy/night_affix_service.gd` 的 `AFFIX_COUNT_BY_DAY` 维护（当前：第 1 夜 0 条，2-3 夜 1 条，4-5 夜 2 条，第 6 夜 1 条）。
- 词缀只通过两个挂点生效：条目级（波次 entries 展开前变换）与个体级（`spawn_enemy` 的 `cfg_override`），结算逻辑集中在 `night_affix_service.gd`。

记录示例：

```json
[
  {
    "id": "forced_march",
    "name": "急行军",
    "desc": "敌军轻装疾行：全体移动速度 +30%，最大生命 -20%。",
    "min_day": 2,
    "weight": 10,
    "effects": [
      { "type": "enemy_stat_percent", "stat": "move_speed", "value": 0.30 },
      { "type": "enemy_stat_percent", "stat": "max_hp", "value": -0.20 }
    ]
  }
]
```

顶层字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | 词缀唯一标识，使用英文小写加下划线 |
| `name` | `String` | 词缀名称，公示于敌情面板预警区 |
| `desc` | `String` | 玩家可读的完整效果描述 |
| `min_day` | `int` | 最早出现天数（门控） |
| `weight` | `float` | 抽取权重 |
| `effects` | `Array` | 效果原语列表 |

`effects` 支持的效果原语：

| `type` | 字段 | 说明 |
|---|---|---|
| `enemy_stat_percent` | `stat`、`value`、可选 `min_def` | 敌人数值按百分比缩放；`min_def` 存在时仅作用于防御不低于该值的敌人。整数字段（`max_hp`/`atk`/`def`/`res`/`prestige_reward`/`core_damage`）四舍五入 |
| `enemy_stat_add` | `stat`、`value` | 敌人数值加算 |
| `death_effect_percent` | `value`、可选 `spawn_add` | 死亡爆炸伤害按百分比增强；`spawn_add` 增加死亡分裂数量 |
| `extra_squad` | `enemy_id`、`count`、`interval`、`time_offset` | 每波在随机出怪口追加一支编队，`time_offset` 为相对波开始的时间 |
| `spawn_redistribute` | `surge_multiplier`、`other_multiplier` | 随机一个出怪口条目数量乘 `surge_multiplier`，其余乘 `other_multiplier`（向上取整，最少 1） |

---

## 7. `buffs.json`

作用：

- 定义肉鸽遗物效果。旧接口仍沿用 Buff 命名以兼容现有代码。
- `rarity` 参与抽取门控（`buff_manager.gd`）：第 1-2 天只出 1（普通），第 3-4 天出 1-2，第 5 天起出 2-3（稀有/传说）。
- 三选一为分槽构成：槽 A 从玩家"拥有不同干员数 ≥2"的盟约对应钥匙件（`category = covenant`）中抽，槽 B 按稀有度门控随机，槽 C 从 `economy`/`generic` 中保底。
- `category` 取值：`covenant`（盟约钥匙件，需配 `covenant` 字段）、`mechanic`（机制改变件）、`class`（职业/编队件）、`economy`（经济引擎件）、`generic`（通用数值件）。

记录示例：

```json
[
  {
    "id": "relic_cov_steadfast",
    "name": "磐石垒砌",
    "desc": "坚守干员防御 +40%、法抗 +15。",
    "rarity": 2,
    "category": "covenant",
    "covenant": "坚守",
    "effects": [
      { "effect_type": "unit_def_percent", "effect_value": 0.40, "covenant_filter": "坚守" },
      { "effect_type": "unit_res_add", "effect_value": 15, "covenant_filter": "坚守" }
    ]
  }
]
```

推荐字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | Buff 唯一标识 |
| `name` | `String` | 显示名称 |
| `desc` | `String` | 描述文本 |
| `effect_type` | `String` | 效果类型 |
| `effect_value` | `int` / `float` | 效果数值 |
| `rarity` | `int` | 稀有度 |
| `icon_path` | `String` | 遗物图标路径，用于 `RelicStrip`、`RelicPanel`、`RelicCard` 和祝福候选卡 |
| `effects` | `Array` | 可选，复合遗物使用；每项包含 `effect_type`、`effect_value` 和过滤字段 |
| `class_filter` | `String` | 可选，仅影响指定职业，例如 `guard`、`sniper`、`caster`、`defender` |
| `building_type_filter` | `String` | 可选，仅影响指定建筑类别，例如 `resource`、`aura` |
| `material_filter` | `String` | 可选，仅影响指定资源，例如 `wood`、`stone`、`mana` |
| `covenant_filter` | `String` / `Array` | 可选，仅影响拥有指定盟约 tag 的干员（与 `units.json[].covenants` 求交集） |
| `category` | `String` | 抽取分槽用类别：`covenant` / `mechanic` / `class` / `economy` / `generic` |
| `covenant` | `String` | `category = covenant` 时必填，对应盟约名，用于盟约导向槽匹配 |

新增的机制效果类型：

| `effect_type` | 说明 |
|---|---|
| `unit_sp_on_skill_cast_team` | 任意干员开启技能时，所有在场干员获得 `effect_value` 点 SP（`buff_manager.gd` 监听 `unit_skill_cast`） |

---

## 8. `events.json`

作用：

- 定义随机事件及其结算参数。

记录示例：

```json
[
  {
    "id": "event_abandoned_cart",
    "name": "废弃货车",
    "desc": "获得 2 木材，但失去 1 声望。",
    "effect_type": "material_and_prestige",
    "payload": {
      "wood": 2,
      "stone": 0,
      "mana": 0,
      "prestige": -1
    }
  }
]
```

推荐字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | 事件唯一标识 |
| `name` | `String` | 显示名称 |
| `desc` | `String` | 事件描述 |
| `effect_type` | `String` | 结算类型 |
| `payload` | `Dictionary` | 结算参数 |

---

## 9. 调试战斗预设

`data/debug/combat_sandbox_presets.json` 用于保存战斗沙盒的可复现调试关卡。

记录示例：

```json
{
  "id": "default",
  "name": "默认一路调试",
  "operators": [
    {"key": "G1", "unit_id": "guard_t1", "name": "一阶近卫"},
    {"key": "G2", "unit_id": "guard_01", "name": "二阶近卫"},
    {"key": "G3", "unit_id": "guard_t3", "name": "三阶近卫"},
    {"key": "S1", "unit_id": "sniper_t1", "name": "一阶狙击"},
    {"key": "S2", "unit_id": "sniper_t2", "name": "二阶狙击"},
    {"key": "S3", "unit_id": "archer_basic", "name": "三阶狙击"}
  ],
  "spawns": [
    {"key": "S1", "cell": [0, 3]}
  ],
  "queues": {
    "S1": [
      {
        "enemy_id": "slime",
        "delay": 0.0,
        "name": "源石虫",
        "max_hp": 300,
        "atk": 18,
        "def": 20,
        "res": 0,
        "move_speed": 1.0,
        "attack_interval": 1.2,
        "damage_type": "physical",
        "core_damage": 1
      }
    ]
  }
}
```

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | preset 唯一标识 |
| `name` | `String` | preset 显示名 |
| `operators` | `Array` | 沙盒开局拥有的干员槽位列表，结构同运行时干员槽位 |
| `spawns` | `Array` | 出怪口列表；每项包含 `key` 与 `cell` |
| `queues` | `Dictionary` | 按出怪口 key 分组的独立出怪队列 |

`operators` 缺省时，沙盒可用内置默认编队兜底，避免旧 preset 立即失效。

---

## 10. `map_generation.json`

作用：

- 集中配置地图生成参数，便于快速调整资源点、事件点、障碍、刷怪点等数量和安全半径。
- 该文件只描述地图生成侧的数量、距离和安全区参数，不保存单局运行时状态。

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `width` | `int` | 地图宽度 |
| `height` | `int` | 地图高度 |
| `spawn_count` | `int` | 刷怪点数量；当前波次表使用 `S1`、`S2`、`S3` |
| `resources_per_type` | `int` | 每种资源在整张地图上的目标生成数量 |
| `near_resources_per_type` | `int` | 每种资源在核心可见区外侧探索圈内的保底生成数量 |
| `event_point_count` | `int` | 地图上随机事件点数量；事件内容引用 `events.json`，当前配置为 8 |
| `obstacle_ratio` | `float` | 障碍目标比例，最终数量还会受最小/最大值限制 |
| `water_obstacle_chance` | `float` | 单个地貌簇或零散障碍生成为水域的概率；未命中时生成山地 |
| `min_obstacle_count` | `int` | 障碍最小生成数量 |
| `max_obstacle_count` | `int` | 障碍最大生成数量 |
| `terrain_cluster_count` | `int` | 连续地貌簇目标数量，用于生成山脉、湖泊等成片不可通行区域 |
| `terrain_cluster_min_size` | `int` | 单个连续地貌簇的最小目标格数 |
| `terrain_cluster_max_size` | `int` | 单个连续地貌簇的最大目标格数 |
| `terrain_cluster_attempts` | `int` | 每个连续地貌簇的尝试次数；失败通常是因为会堵死刷怪点到核心路径 |
| `scattered_obstacle_ratio` | `float` | 总障碍中保留为零散障碍的比例，其余优先生成连续地貌簇 |
| `core_safe_radius` | `int` | 核心周围不会随机生成障碍、额外资源、事件点的安全半径 |
| `spawn_safe_radius` | `int` | 刷怪点周围不会随机生成障碍、额外资源、事件点的安全半径 |
| `min_spawn_core_distance` | `int` | 刷怪点到核心的最小曼哈顿距离 |
| `min_spawn_distance` | `int` | 刷怪点之间的最小曼哈顿距离 |

当前配置：

```json
{
  "width": 30,
  "height": 30,
  "spawn_count": 3,
  "resources_per_type": 12,
  "near_resources_per_type": 2,
  "event_point_count": 8,
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
  "spawn_safe_radius": 1,
  "min_spawn_core_distance": 12,
  "min_spawn_distance": 10
}
```

生成规则说明：

- 地图默认生成 30×30 网格，核心位于地图中心，初始只揭开核心周围 5×5 区域。
- 初始 5×5 可见区内不再固定塞资源点；资源保底改为放在可见区外侧的近探索圈，避免开局过空。
- `resources_per_type` 表示每种资源的目标总数；当前木材、石材、魔力各 12 个。
- `near_resources_per_type` 表示每种资源在近探索圈内的保底数量；当前木材、石材、魔力各至少 2 个靠近开局区域。
- 障碍数量先按 `width * height * obstacle_ratio` 估算，再被 `min_obstacle_count` 与 `max_obstacle_count` 限制。
- 障碍优先生成若干连续地貌簇：水域偏块状湖泊，山地偏带状山脉；随后按 `scattered_obstacle_ratio` 补少量零散障碍，避免地图过于规则。
- 障碍放置后会校验刷怪点到核心仍存在地面路径，失败的地貌簇或散点会回滚，避免随机地图把夜晚路径彻底堵死。
- 刷怪点优先从地图边缘选择，受核心距离和刷怪点互相距离限制。

事件点说明：

- 随机事件点由 `RandomEventManager` 作为地图覆盖层维护，地图格本身不记录事件触发状态。
- 当前 `event_point_count` 为 8，正式地图默认生成 8 个随机事件点。
- 随机事件点与资源点互斥，同一个格子不会同时是资源点和事件点。
- `MapGenerator` 只负责放置事件点并引用已有事件 ID，不负责新增事件内容。
- 事件具体内容、效果和结算参数仍由 `events.json` 与 `RandomEventManager` 负责。
- 地图侧只负责“这个格子是否有事件”；探索发现后的展示和事件效果结算属于白天流程与随机事件模块。

### 10.1 `ui_icons.json`

作用：

- 集中维护非实体 UI 图标路径。
- 覆盖资源、阶段、按钮、音量、职业 fallback、属性、伤害类型、朝向、地图标记和战场图例等。
- UI 通过 `UiArtRegistry.get_catalog_icon(id)` 读取，不在组件脚本中拼接图片路径。

结构为顶层对象：

```json
{
  "resource_wood": "res://assets/ui/generated/icon_wood.png",
  "button_close": "res://assets/ui/generated/icon_close.png"
}
```

---

## 11. 配置表之间的引用关系

### 11.1 单位

- `units.json[].skill_id` 引用技能逻辑标识
- `units.json[].scene_key` 引用单位模板
- `units.json[].class_icon_path` 引用职业图标
- `units.json[].skill_icon_path` 引用技能图标
- `units.json[].portrait_path` 可选引用头像图标

### 11.2 敌人

- `enemies.json[].scene_key` 引用敌人模板

### 11.3 建筑

- `buildings.json[].scene_key` 引用建筑模板
- `buildings.json[].icon_path` 引用建筑 UI 图标

### 11.4 夜晚关卡模板

- `wave_templates.json[].key_enemies[]` 引用 `enemies.json[].id`
- `wave_templates.json[].entries[].enemy_id` 引用 `enemies.json[].id`
- `wave_templates.json[].entries[].enemy_choices[].enemy_id` 引用 `enemies.json[].id`
- `wave_templates.json[].entries[].spawn_key` 引用地图中的刷怪点逻辑名

### 11.5 Buff 与事件

- `buffs.json[].effect_type` 决定 Buff 的结算逻辑
- `buffs.json[].icon_path` 引用遗物 UI 图标
- `events.json[].effect_type` 决定事件的结算逻辑
- `events.json[].payload` 为对应结算逻辑提供参数
