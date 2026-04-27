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
└─ waves.json
```

各文件用途：

- `units.json`
  单位静态配置。
- `enemies.json`
  敌人静态配置。
- `buildings.json`
  建筑静态配置。
- `buffs.json`
  Buff / 祝福静态配置。
- `events.json`
  随机事件静态配置。
- `waves.json`
  夜晚波次配置。

这些文件只保存静态配置，不保存一局游戏的运行时状态。

---

## 2. 通用规则

### 2.1 顶层结构

- 每个 JSON 文件顶层统一使用数组。
- 数组中的每一项代表一条记录。

### 2.2 `id`

- 每条记录必须有唯一标识。
- 单位、敌人、建筑、Buff、事件统一使用 `id`。
- `waves.json` 以 `day` 作为主标识。

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

### 2.6 `icon_key`

如果某条配置需要在 UI 中显示图标，则使用 `icon_key`。  
`icon_key` 是图标资源的逻辑名，不直接写贴图路径。

---

## 3. `units.json`

作用：

- 定义单位的职业、数值、攻击范围、技能和部署相关配置。

记录示例：

```json
[
  {
    "id": "guard_01",
    "name": "前锋近卫",
    "class": "guard",
    "cost_prestige": 1,
    "max_hp": 120,
    "atk": 30,
    "def": 10,
    "res": 0,
    "block": 1,
    "attack_interval": 1.0,
    "damage_type": "physical",
    "target_type": "ground",
    "range_pattern": [[1, 0]],
    "redeploy_sec": 12,
    "sp_max": 20,
    "sp_recover_per_sec": 1.0,
    "skill_id": "guard_power_strike",
    "skill_behavior_key": "guard_power_strike",
    "scene_key": "unit_actor",
    "icon_key": "guard_01_icon"
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
| `target_type` | `String` | 攻击目标类型 |
| `attack_delivery` | `String` | 普攻命中形式；`instant` 为即时命中，`projectile` 为飞行物命中，未配置默认 `instant` |
| `projectile_scene_key` | `String` | 飞行物场景逻辑名，未配置默认 `projectile` |
| `projectile_speed` | `float` | 飞行物追踪速度 |
| `projectile_hit_radius` | `float` | 飞行物命中半径 |
| `projectile_lifetime` | `float` | 飞行物最大存活时间，未配置默认 3 秒 |
| `sp_recover_per_sec` | `float` | 每秒回复 SP |
| `skill_id` | `String` | 技能标识 |
| `skill_behavior_key` | `String` | 技能行为脚本逻辑名，未配置时默认回退到 `skill_id` |
| `icon_key` | `String` | 图标逻辑名 |

### 3.1 运行时干员槽位

干员槽位不是独立配置表，而是 `RunState`、存档和调试 preset 中使用的运行时结构。
它表示玩家拥有的一名可部署干员实例，而不是一个单位类型。

结构示例：

```json
{
  "key": "G1",
  "unit_id": "guard_01",
  "name": "近卫A"
}
```

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `key` | `String` | 槽位唯一标识；部署、撤退、再部署 CD 均按该值结算 |
| `unit_id` | `String` | 引用 `units.json[].id`，决定基础数值、攻击范围、技能和再部署时间 |
| `name` | `String` | UI 显示名；允许同类单位用不同槽位名区分 |

同一个 `unit_id` 可以出现在多个槽位中。`units.json[].redeploy_sec` 是单位类型默认再部署时间，但实际冷却状态属于具体槽位。

---

## 4. `enemies.json`

作用：

- 定义敌人的数值、行为类型、移动方式和对核心造成的伤害。

记录示例：

```json
[
  {
    "id": "slime",
    "name": "史莱姆",
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
| `behavior_type` | `String` | 行为类型 |
| `move_type` | `String` | 移动类型 |
| `core_damage` | `int` | 抵达核心时造成的伤害 |
| `scene_key` | `String` | 敌人模板逻辑名 |

常用可选字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `damage_type` | `String` | 伤害类型 |
| `attack_range` | `int` | 攻击范围，按棋盘格切比雪夫距离计算；未配置或小于等于 0 时只攻击阻挡单位 |
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
    "building_type": "aura",
    "max_hp": 150,
    "cost_wood": 2,
    "cost_stone": 1,
    "cost_mana": 0,
    "ap_cost": 1,
    "blocks_path": false,
    "effect_radius": 2,
    "effect_type": "heal",
    "effect_value": 8,
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
| `effect_type` | `String` | 效果类型 |
| `effect_value` | `int` / `float` | 效果数值 |

---

## 6. `waves.json`

作用：

- 定义每天夜晚的刷怪计划。

记录示例：

```json
[
  {
    "day": 1,
    "entries": [
      { "time": 0.0, "enemy_id": "slime", "spawn_key": "S1", "count": 4, "interval": 0.8 },
      { "time": 8.0, "enemy_id": "slime", "spawn_key": "S2", "count": 3, "interval": 0.7 }
    ]
  }
]
```

顶层字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `day` | `int` | 第几天夜晚 |
| `entries` | `Array` | 本夜晚的刷怪条目列表 |

`entries` 中每条记录必填字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `time` | `float` | 从夜晚开始后的触发时间 |
| `enemy_id` | `String` | 敌人配置 ID |
| `spawn_key` | `String` | 刷怪点逻辑名 |
| `count` | `int` | 生成数量 |
| `interval` | `float` | 同组敌人之间的生成间隔 |

---

## 7. `buffs.json`

作用：

- 定义 Buff / 祝福效果。

记录示例：

```json
[
  {
    "id": "buff_atk_up_small",
    "name": "战意高涨",
    "desc": "所有已部署单位攻击力 +10%",
    "effect_type": "unit_atk_percent",
    "effect_value": 0.1,
    "rarity": 1
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
  "id": "default_lane",
  "name": "默认一路调试",
  "operators": [
    {"key": "G1", "unit_id": "guard_01", "name": "近卫A"},
    {"key": "G2", "unit_id": "guard_01", "name": "近卫B"},
    {"key": "S1", "unit_id": "archer_basic", "name": "狙击A"}
  ],
  "spawns": [
    {"key": "S1", "cell": [0, 3]}
  ],
  "queues": {
    "S1": [
      {
        "enemy_id": "slime",
        "delay": 0.0,
        "name": "史莱姆",
        "max_hp": 90,
        "atk": 18,
        "def": 2,
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

## 10. 配置表之间的引用关系

### 10.1 单位

- `units.json[].skill_id` 引用技能逻辑标识
- `units.json[].scene_key` 引用单位模板
- `units.json[].icon_key` 引用单位图标

### 10.2 敌人

- `enemies.json[].scene_key` 引用敌人模板

### 10.3 建筑

- `buildings.json[].scene_key` 引用建筑模板

### 10.4 波次

- `waves.json[].entries[].enemy_id` 引用 `enemies.json[].id`
- `waves.json[].entries[].spawn_key` 引用地图中的刷怪点逻辑名

### 9.5 Buff 与事件

- `buffs.json[].effect_type` 决定 Buff 的结算逻辑
- `events.json[].effect_type` 决定事件的结算逻辑
- `events.json[].payload` 为对应结算逻辑提供参数
