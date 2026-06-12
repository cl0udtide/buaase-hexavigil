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
| `covenants` | `Array[String]` | 该单位静态携带的盟约 tag（中文盟约名，见 `covenant_defs.gd` 的 `ORDER`）；运行时有效盟约 = 此字段 + 本局祭坛追加（`RunState.get_unit_covenants`） |

为新干员分配 `covenants` 时的原则（沿自盟约系统最初设计）：

- 一个干员可带 1-2 个盟约 tag，保证每个盟约的成员数量适中，不要太容易或太难凑满 2/3 人档位；
- 结合干员特点分配：精准只给远程、坚守偏向重装、突袭给适合空降单切的干员、萨尔贡无限制；但不要一满足条件就滥发，例如不要把所有远程干员都给精准。

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
| `wall_visual_prefix` | `String` | 墙族连接变体前缀；运行时组合为 `<prefix>_0001_n` 等 16 种四邻接贴图键。配置了该字段的建筑（木墙、人工高台）互为可连接邻居、互刷连接掩码；贴图由 `scripts/building/wall_art.gd` 程序化生成（`building_actor._load_visual_texture` 优先程序化路径，文件贴图为兜底） |
| `visual_display_size` | `float` | 建筑贴图在地图上的显示尺寸，默认 `72`，用于让 128px 贴图覆盖 64px 逻辑格并减少连接缝 |
| `hidden_in_build_panel` | `bool` | 是否从建筑面板隐藏，适合未开放或调试建筑 |
| `ranged_deployable` | `bool` | 机制标志：建筑存活时，该格视同高台，允许狙击/术师（`RANGED_DEPLOY_CLASSES`）部署；建筑被摧毁时同格占驻干员立即阵亡（夜间触发再部署冷却，白昼直接移除）；未配置默认 `false` |

`BuildPanel` 不维护独立建筑清单。建筑是否出现在某个标签页，由 `building_type` 决定：

- `resource`：资源建筑。
- `aura`：增益/光环建筑。
- `block`：防御/路径阻挡建筑（木墙、人工高台等）。

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
    "groups": [
      { "time": 0.0, "enemy_id": "slime", "lane": "any", "count": 8, "interval": 0.45 },
      { "time": 3.0, "enemy_id": "hound", "lane": "main", "count": 8, "interval": 0.55 },
      { "time": 8.0, "enemy_id": "hound_pro", "lane": "main", "count": 2, "interval": 1.2 },
      { "time": 13.0, "enemy_id": "lumberjack_veteran", "lane": "flank", "count": 1, "interval": 0.0 }
    ]
  },
  {
    "id": "fiends_carnival",
    "name": "狂欢之主",
    "desc": "鼓点从黑暗深处传来，奶龙酋长被一队披甲护卫簇拥上场。它像在赴宴，沿途却只留下被踩碎的路。",
    "tier": "boss",
    "key_enemies": ["milk_dragon_chief"],
    "groups": [
      {
        "time": 8.0,
        "lane": "main",
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
| `groups` | `Array` | 本模板的刷怪分组列表 |

`groups` 中每条记录基础字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `time` | `float` | 从夜晚开始后的触发时间 |
| `enemy_id` | `String` | 敌人配置 ID；当 `enemy_choices` 有有效候选时可省略 |
| `lane` | `String` | 进攻角色：`main`（该波主攻口）/ `flank`（非主攻口，单口时回退）/ `any`（活跃口随机）。落口由 `night_template_resolver.gd` 清晨 seeded 结算 |
| `count` | `int` | 生成数量 |
| `interval` | `float` | 同组敌人之间的生成间隔 |

`groups` 中每条记录常用可选字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `enemy_choices` | `Array` | 随机敌人候选池；每项包含 `enemy_id` 和可选 `weight`。运行时按本局随机种子、模板 ID 和组序号确定选择，白天预览与夜晚实际刷怪保持一致 |

### 6.0 活跃口集合（spawn gates v2）

每晚出怪前，`night_template_resolver.gd` 根据以下规则确定本晚的**活跃出怪口集合**：

**激活序**：`resolve_activation_order` 用本局 `run_seed` 对全部 5 个候选口做 seeded shuffle，得到一条固定的顺序（每局唯一，不随天数改变）。

**日程表**：`ACTIVE_COUNT_BY_DAY = {1: 2, 3: 3, 5: 4, 7: 5}`。清晨按当天天数找最近触发的门槛，从激活序中取前 N 个口作为基础活跃集。

**一夜覆盖项**（存于 `RunState`，黎明清零）：

| 字段 | 说明 |
|---|---|
| `night_gate_extra_open_keys` | 今晚额外追加为活跃的口 |
| `night_gate_closed_keys` | 今晚封堵的口（由塌方契约写入，不得使活跃口低于 1） |
| `night_gate_seals_today` | 玩家今日主动封口的使用次数（int，上限 1 次/天，黎明清零；塌方契约不写入此字段） |

**最终活跃集** = (日程表前 N 口 ∪ extra_open) − closed，且至少保留 1 口。

**预览即契约**：清晨结算完成后通过 EventBus `night_gate_overrides_changed` 通知 UI，`wave_manager.get_night_preview` 返回的 `active_gates` 字段与运行时 `wave_manager._active_spawn_keys()` 使用同一计算路径——预览内容等于夜晚实际开口，无二次随机。

---

## 6.1 `night_affixes.json`

作用：

- 定义夜晚词缀池。每晚白天开始时由 `GameController` 按 `RunState.random_seed` 与天数确定性抽取，存入 `RunState.night_affix_ids` 并在敌情预览中公示。
- 每晚词缀数量由 `scripts/enemy/night_affix_service.gd` 的 `AFFIX_COUNT_BY_DAY` 维护（当前：第 1 夜 0 条，2-3 夜 1 条，4-5 夜 2 条，第 6 夜 1 条）。
- 词缀只通过两个挂点生效：条目级（波次 groups 展开前变换）与个体级（`spawn_enemy` 的 `cfg_override`），结算逻辑集中在 `night_affix_service.gd`。

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
| `covenant_filter` | `String` / `Array` | 可选，仅影响拥有指定有效盟约 tag 的干员（静态 `units.json[].covenants` + 本局追加盟约） |
| `category` | `String` | 抽取分槽用类别：`covenant` / `mechanic` / `class` / `economy` / `generic` |
| `covenant` | `String` | `category = covenant` 时必填，对应盟约名，用于盟约导向槽匹配 |

新增的机制效果类型：

| `effect_type` | 说明 |
|---|---|
| `unit_sp_on_skill_cast_team` | 任意干员开启技能时，所有在场干员获得 `effect_value` 点 SP（`buff_manager.gd` 监听 `unit_skill_cast`） |

---

## 8. `events.json`

作用：

- 定义随机事件（契约系统）。设计铁律：事件必须是有代价、有改造或有赌注的交易，禁止无代价的纯资源发放。
- 根事件（无 `hidden_in_map_pool`）进入**每日刷新池**：开局保底 2 个事件点，此后每天 1-2 个，活跃上限 4 个；落点优先探索前沿的迷雾（`random_event_manager.gd` 维护规则与数值）。`map_generation.json` 的 `event_point_count` 已置 0，不再在地图生成期放置。
- 事件抽取受 `min_day` / `max_day` 门控与 `weight` 加权，且本局未刷过的事件优先。
- 选项跳转的结果事件标记 `hidden_in_map_pool: true`。
- 触发事件消耗 2 行动力（`day_manager.gd`）；`requires` 前置不满足时事件整体取消并退还行动力。
- 特例：`event_altar`（古代祭坛）的选项按格子动态生成（最多 3 个"单位类型×盟约"灌注组合 + 离开），灌注消耗 2 魔力矿，为该 `unit_id` 在本局追加盟约 tag（`RunState.add_unit_covenant`），现有与后续同名实例都会继承。
- 当前根事件池共 7 类：黑市商人、战争赌局、走私商队、古代祭坛、雇佣兵营地、废弃军械库、魔力裂隙。所有选项结果事件都应设置 `hidden_in_map_pool: true`。

记录示例：

```json
[
  {
    "id": "event_black_market_deal",
    "name": "黑市商人",
    "desc": "商人撬走了两块核心装甲板，留下一只沉重的箱子。",
    "effect_type": "contract",
    "hidden_in_map_pool": true,
    "effects": [
      { "type": "core_max_hp_add", "value": -2 },
      { "type": "grant_random_relic", "rarity_min": 2, "rarity_max": 3 }
    ]
  }
]
```

推荐字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | 事件唯一标识 |
| `name` | `String` | 显示名称 |
| `desc` | `String` | 事件描述 |
| `effect_type` | `String` | 结算类型：`material_and_prestige`（资源结算）或 `contract`（契约效果） |
| `payload` | `Dictionary` | `material_and_prestige` 的资源增减参数 |
| `requires` | `Dictionary` | 可选前置消耗校验，如 `{ "prestige": 4 }`、`{ "mana": 3 }` |
| `effects` | `Array` | 契约效果列表（见下表） |
| `choices` | `Array` | 选项列表；每项含 `id`、`text`、`kind`、`event_id`（跳转的结果事件）、`effect_desc` |
| `hidden_in_map_pool` | `bool` | 结果事件标记，不进入地图事件点池 |
| `min_day` / `max_day` | `int` | 可选，事件可刷出的天数区间（默认 1 / 99） |
| `weight` | `float` | 可选，刷新抽取权重（默认 1） |

`effects` 支持的契约效果（`random_event_manager.gd`）：

| `type` | 字段 | 说明 |
|---|---|---|
| `core_max_hp_add` | `value` | 核心生命上限增减（最低保留 1） |
| `grant_random_relic` | `rarity_min`、`rarity_max` | 获得一件指定稀有度区间的随机未持有遗物；池空时改发 6 声望 |
| `night_affix_add_random` | — | 为今晚追加一条随机夜晚词缀（优先满足 `min_day`，无候选时回退全池） |
| `wager_no_leak` | — | 激活赌约：核心一夜未失血则次日清晨额外一次遗物三选一（`game_controller.gd` 结算） |
| `grant_random_operator` | `unit_cost` | 获得一名指定费用档（`cost_prestige`）的随机干员；无候选时改发 3 声望 |
| `night_affix_add` | `affix_id` | 为今晚追加指定的夜晚词缀（已存在时跳过） |
| `gate_open_extra_tonight` | — | 今晚在当前激活序中的下一个沉默口追加为活跃口（写入 `RunState.night_gate_extra_open_keys`）；无可用沉默口时无效 |

### 8.1 出怪口相关事件（spawn gates v2）

当前根事件池新增两类口相关事件：

**塌方契约（`event_landslide_contract`）**

- 根事件，动态生成选项：每个当前活跃出怪口对应一个"封堵该口（消耗 3 魔力矿）"的选项 + 一个"拒绝"选项，类似祭坛的动态选项模式。
- 选择封堵后执行隐藏子事件，效果为将该口写入 `RunState.night_gate_closed_keys`（今晚封堵，黎明清空）。
- 封堵后活跃口不得低于 1；口数 = 1 时无可选封堵项，塌方契约实质上为空选项。

隐藏子事件（均设 `hidden_in_map_pool: true`）：

| `id` | 说明 |
|---|---|
| `event_landslide_leave` | 玩家拒绝，无效果 |

（每个活跃口的封堵结果事件由 `random_event_manager.gd` 在运行时动态构造，不写入 JSON）

**开口赌约（`event_gate_wager`）**

- 根事件，`max_day: 6`。
- 两个选项：接受（`event_gate_wager_accept`）/ 拒绝（`event_gate_wager_decline`）。
- `event_gate_wager_accept` 效果：`gate_open_extra_tonight`（今晚追加一个沉默口为活跃口）+ `payload.prestige: 3, mana: 2`。

| `id` | 说明 |
|---|---|
| `event_gate_wager_accept` | 追加一个沉默口 + 获得 3 声望 2 魔力矿 |
| `event_gate_wager_decline` | 无效果 |

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

- 集中配置地图生成参数，便于快速调整资源点、障碍、刷怪点等数量和安全半径。
- 该文件只描述地图生成侧的数量、距离和安全区参数，不保存单局运行时状态。

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `width` | `int` | 地图宽度 |
| `height` | `int` | 地图高度 |
| `spawn_count` | `int` | 刷怪候选口数量；spawn gates v2 起固定为 5，由 `map_generator.gd` 按等弧算法放置 |
| `spawn_corner_margin` | `int` | 等弧放置时距地图角落的最小格数，防止出怪口卡在角落 |
| `spawn_arc_center_ratio` | `float` | 等弧放置时每段弧的中央窗口宽度比例（0-1）；门格从该弧段中央的此比例范围内随机抽取（0.6 = 中间 60% 范围），数值越大分布越均匀，越小越向弧段中点集中 |
| `resources_per_type` | `int` | 每种资源在整张地图上的目标生成数量 |
| `near_resources_per_type` | `int` | 每种资源在核心可见区外侧探索圈内的保底生成数量 |
| `event_point_count` | `int` | 旧地图生成期事件点数量；当前配置为 0，正式事件由 `RandomEventManager` 每日刷新 |
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
| `spawn_safe_radius` | `int` | 刷怪点周围不会随机生成障碍、额外资源、事件点的安全半径（地形包阶段 B 起 1→2） |
| ~~`min_spawn_core_distance`~~ | ~~`int`~~ | ~~刷怪点到核心的最小曼哈顿距离~~ → **v2 已删除**，等弧算法隐式保证边缘距离 |
| ~~`min_spawn_distance`~~ | ~~`int`~~ | ~~刷怪点之间的最小曼哈顿距离~~ → **v2 已删除**，等弧均分自然保证间距 |

骨架生成器（skeleton_v2，地形包阶段 B）新增字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `generator` | `string` | 生成器开关：`"skeleton_v2"`（现行）/ `"legacy"`（旧 walker 管线，随时可切回） |
| `max_retries` | `int` | skeleton_v2 整图重试上限（末两轮强制保守剖面；全败回落 legacy 并 `push_warning`） |
| `max_repair_rounds` | `int` | 修复 pass 内每个目标项的轮数上限 |
| `detour_cap` / `detour_floor` | `float` | 每口「真实最短路长 / 曼哈顿距离」的验收带 [1.15, 1.6]（cap 同时被 legacy 绕路修复使用） |
| `lane_jitter_base` | `float` | 车道噪声抖动缺省幅度（牌的 `jitter_amp` 覆写） |
| `corridor_slack` | `int` | corridor 派生松弛：双 BFS 距离和 ≤ 最短 + slack |
| `gate_slide_jitter` | `int` | 门位弧内滑移抖动幅度 **预留（未接线）** |
| `repair` | `object` | 开凿代价权重（`carve_costs.water`/`mountain`，字典序次序键）、入侵度上限（单图/均值）、`dual_pass_ratio_cap`（dual 隘口比例目标，平衡盘项）；其中 `intrusion_max_mean` **预留（仅单图上限已接线）** |
| `pass` | `object` | 隘口验收窗纵深（`aperture_depth`）、口袋核尺寸（`pocket_core_w/h`）与口袋 flood 验收（`pocket_min_plain`/`pocket_flood_limit`） |
| `mesa` | `object` | 天然高台座数带（`count_min/max` 5-8、降阶下限 4）、总格数带（`cells_min/max` 20-30）、尺寸权重、corridor 贴靠（`max_corridor_dist`/`min_covered_ratio`）、起手台（`starter.*` 环带 4-5、4-5 格） |
| `economy` | `object` | 资源风味亲和（wood→湿原 / stone→山麓 / mana→临水）与 `risk_reward_bias`；其中 `resource_affinity` 键值 **预留（当前亲和规则硬编码，键值未消费）** |
| `moisture_gradient_strength` | `float` | 湿度梯度强度（河湖计划与资源风味用） |
| `sector_cards` | `object` | 扇区牌定义（bastion / steppe / riverlands / canyon：隘口宽、环带、密度、mesa 配额、抖动、资源倍率、河/湖键）；其中 `riverlands.ford_width` **预留（渡口宽度硬编码 2）** |
| `archetypes` | `array` | 地图原型（id、权重、牌组多重集、汇流拓扑、阻挡占比带 `ratio_band`） |
| `day1_card_constraint` | `string` | 发牌约束：`"no_double_steppe"` = 第 1 天活跃口不得全为 steppe |
| `bias_cards_by_activation` | `bool` | 预留：按激活序加权发牌（当前 `false`） |

generator 开关说明：`"skeleton_v2"` 走骨架生成器全管线（牌组 → 车道 → 长肉 → 修复 → mesa → 资源），`"legacy"` 走旧 walker 管线；`obstacle_ratio`、`terrain_cluster_*` 等旧算法键全部保留，既作回切配置，也是 skeleton_v2 重试耗尽后的兜底生成器所用。`generate` 返回字典在 v2 下额外回传 `sectors`（gate_key → {card, pass_grade, anchor, aperture, ford}）与 `gen_report`（attempts / fallback / ledger / intrusion / blocked_ratio 等）两键；新增键由 generate() 返回，map_manager 仅消费四个旧键（cells / core_cell / spawn_cells / event_points），sectors/gen_report 当前无运行时消费方（夜晚播报链接入需另行铺管），legacy 路径回传两个空字典。

当前配置：

```json
{
  "width": 30,
  "height": 30,
  "generator": "skeleton_v2",
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
  "max_retries": 8,
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
    "count_min": 5, "count_max": 8, "count_floor_degraded": 4,
    "cells_min": 20, "cells_max": 30,
    "size_weights": { "3": 0.30, "4": 0.35, "5": 0.20, "6": 0.15 },
    "max_corridor_dist": 2, "min_covered_ratio": 0.6,
    "starter": { "ring_min": 4, "ring_max": 5, "size_min": 4, "size_max": 5, "max_corridor_dist": 2 }
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

生成规则说明：

- 地图默认生成 30×30 网格，核心位于地图中心，初始只揭开核心周围 5×5 区域。
- 初始 5×5 可见区内不再固定塞资源点；资源保底改为放在可见区外侧的近探索圈，避免开局过空。
- `resources_per_type` 表示每种资源的目标总数；当前木材、石材、魔力各 12 个。
- `near_resources_per_type` 表示每种资源在近探索圈内的保底数量；当前木材、石材、魔力各至少 2 个靠近开局区域。
- 障碍数量先按 `width * height * obstacle_ratio` 估算，再被 `min_obstacle_count` 与 `max_obstacle_count` 限制。
- 障碍优先生成若干连续地貌簇：水域偏块状湖泊，山地偏带状山脉；随后按 `scattered_obstacle_ratio` 补少量零散障碍，避免地图过于规则。
- 障碍放置后会校验刷怪点到核心仍存在地面路径，失败的地貌簇或散点会回滚，避免随机地图把夜晚路径彻底堵死。
- 刷怪点（spawn gates v2）按等弧算法沿地图边缘均匀放置：将边缘划分为 `spawn_count` 段等长弧，每段在中央 `spawn_arc_center_ratio` 比例的窗口内随机抽取一个格作为门格，并跳过距角落不足 `spawn_corner_margin` 格的位置。此方案取代了旧的 `min_spawn_core_distance` / `min_spawn_distance` 随机筛选策略。

事件点说明：

- 随机事件点由 `RandomEventManager` 作为地图覆盖层维护，地图格本身不记录事件触发状态。
- 当前 `event_point_count` 为 0，正式地图不在生成期放置事件点；事件点在每天开始时刷新：第 1 天保底 2 个，此后每天 1-2 个，活跃上限 4 个。
- 随机事件点与资源点互斥，同一个格子不会同时是资源点和事件点。
- `MapGenerator` 保留旧事件点字段兼容，但正式流程不再依赖它放置事件点。
- 事件具体内容、效果和结算参数仍由 `events.json` 与 `RandomEventManager` 负责。
- 地图侧只负责“这个格子是否有事件”；探索发现后的展示和事件效果结算属于白天流程与随机事件模块。

### 10.1 地形类型与调试地图序列化

运行时每个格由 `cell_data.gd` 的 `terrain` 字段区分地形类别（`StringName`）。当前定义的类型：

| 地形值 | 显示名 | 敌人可走 | 可建造 | 部署规则 | 渲染说明 |
|---|---|---|---|---|---|
| `plain` | 平地 | 可通行 | 可建造 | 非远程职业可部署（**sniper/caster 仅限高台**，严格门控） | `tile_plain.png` |
| `mountain` | 山地 | 阻挡 | 不可建造 | 不可部署 | `tile_mountain.png`（概括化岩块） |
| `water` | 水域 | 阻挡（飞行可过） | 不可建造 | 不可部署 | `tile_water.png` |
| `highland` | 高台 | 阻挡 | 不可建造 | **仅远程（狙击/术师）**可部署 | `tile_mountain.png` 暖黄 modulate 占位，`tile_highland.png` 待阶段 B 美术 |

`highland` 与 `mountain` 的关键区别：`cell_data.allows_ranged_deploy()` 对 highland 返回 `true`，对 mountain/water 返回 `false`。`is_terrain_blocking()` 对两者均返回 `true`（敌人无法穿越）。

**调试地图状态序列化**（`map_manager.get_debug_map_state` / `apply_debug_map_state`）：

```json
{
  "width": 10,
  "height": 10,
  "core": [5, 5],
  "mountain": [[2, 3], [2, 4]],
  "highland": [[6, 3]]
}
```

`"highland"` 键保存所有高台格坐标，缺省时回退 `[]`（旧存档不带此键不会出错）。`apply_debug_map_state` 会把 highland 列表一同传给 `generate_debug_map`，全量重建地图后由 `_apply_debug_highland_cells` 写入地形。出怪口格不会被 `reveal_area` 揭开（`map_manager.reveal_area` 内有口格跳过逻辑）。

---

### 10.2 `ui_icons.json`

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
- `wave_templates.json[].groups[].enemy_id` 引用 `enemies.json[].id`
- `wave_templates.json[].groups[].enemy_choices[].enemy_id` 引用 `enemies.json[].id`
- `wave_templates.json[].groups[].lane` 取值 main/flank/any（见 docs/superpowers/specs/2026-06-10-dynamic-spawn-gates-design.md）

### 11.5 Buff 与事件

- `buffs.json[].effect_type` 决定 Buff 的结算逻辑
- `buffs.json[].icon_path` 引用遗物 UI 图标
- `events.json[].effect_type` 决定事件的结算逻辑
- `events.json[].payload` 为对应结算逻辑提供参数
