# ARCHITECTURE

## 1. 项目骨架

```text
res://
├─ autoload/                    [全局单例]
│  ├─ EventBus.gd
│  ├─ RunState.gd
│  ├─ DataRepo.gd
│  └─ SceneRouter.gd
├─ scenes/
│  ├─ bootstrap/               [主场景入口]
│  │  ├─ MainMenu.tscn
│  │  └─ Result.tscn
│  ├─ game/                    [游戏主场景]
│  │  └─ Game.tscn
│  ├─ world/                   [地图与世界部件]
│  │  ├─ MapRoot.tscn
│  │  ├─ Core.tscn
│  │  └─ SpawnPoint.tscn
│  ├─ actors/                  [运行时实体模板]
│  │  ├─ UnitActor.tscn
│  │  ├─ units/                [特殊单位继承场景]
│  │  ├─ EnemyActor.tscn
│  │  ├─ BuildingActor.tscn
│  │  └─ Projectile.tscn
│  └─ ui/                      [界面模板]
│     ├─ HUD.tscn
│     ├─ ActionPanel.tscn
│     ├─ BuildPanel.tscn
│     ├─ ShopPanel.tscn
│     ├─ DeployPanel.tscn
│     ├─ EventPanel.tscn
│     ├─ BlessingPanel.tscn
│     └─ ResultPanel.tscn
├─ scripts/
│  ├─ core/                    [阶段与全局控制]
│  ├─ map/                     [地图与寻路]
│  ├─ building/                [建筑]
│  ├─ combat/                  [单位、技能、商店]
│  ├─ enemy/                   [敌人、波次、Boss]
│  ├─ ui/                      [界面逻辑]
│  └─ data/                    [数据说明辅助文件]
├─ data/                       [JSON 配置]
├─ assets/                     [图片、音频、字体]
└─ docs/                       [架构与规范文档]
```

运行时只存在三个主场景：

- `MainMenu.tscn`
- `Game.tscn`
- `Result.tscn`

其中：

- `MainMenu.tscn` 负责进入新一局游戏。
- `Game.tscn` 是整局游戏唯一的运行主场景。
- `Result.tscn` 负责展示胜负结果。

白天、夜晚、祝福都在 `Game.tscn` 内切换，不切主场景。

---

## 2. `Game.tscn` 运行结构

`Game.tscn` 是整局游戏的根节点，固定拆成三层：

```text
Game
├─ World
├─ Managers
└─ UI
```

### 2.1 `World`

`World` 放所有会出现在游戏世界中的节点。

```text
World
├─ MapRoot
│  ├─ GroundLayer
│  ├─ ResourceLayer
│  ├─ FogLayer
│  └─ OverlayLayer
├─ SpawnRoot
├─ CoreRoot
├─ BuildingRoot
├─ UnitRoot
├─ EnemyRoot
├─ ProjectileRoot
└─ EffectRoot
```

各节点作用如下：

- `MapRoot`
  地图根节点，承载所有地图图层。
- `GroundLayer`
  地表层，绘制普通地块，例如平地、墙、沼泽等基础地形。
- `ResourceLayer`
  资源层，绘制木材点、石材点、魔力点等资源类格子。
- `FogLayer`
  迷雾层，覆盖未探索区域，负责白天探索后的揭雾表现。
- `OverlayLayer`
  覆盖层，显示额外提示信息，例如可建造范围、选中格、路径高亮、交互提示。
- `SpawnRoot`
  刷怪点容器，承载所有刷怪点相关节点或标记。
- `CoreRoot`
  核心建筑容器，承载玩家需要防守的核心对象。
- `BuildingRoot`
  场上全部建筑实例的父节点。
- `UnitRoot`
  场上全部己方单位实例的父节点。
- `EnemyRoot`
  场上全部敌方单位实例的父节点。
- `ProjectileRoot`
  场上全部投射物实例的父节点。
- `EffectRoot`
  场上全部临时特效实例的父节点。

### 2.2 `Managers`

`Managers` 放整局游戏的逻辑控制节点。

```text
Managers
├─ GameController
├─ DayManager
├─ NightManager
├─ MapManager
├─ PathService
├─ BuildingManager
├─ UnitManager
├─ ShopManager
├─ EnemyManager
├─ WaveManager
├─ BuffManager
└─ RandomEventManager
```

各节点作用如下：

- `GameController`
  整局流程主控，负责新开一局、切换阶段、进入结算。
- `DayManager`
  负责白天阶段逻辑，例如探索、白天交互、进入夜晚前的校验。
- `NightManager`
  负责夜晚阶段逻辑，例如夜战开始、夜战结束、夜战运行状态管理。
- `MapManager`
  持有地图格子真相数据，负责地图状态、迷雾、格子合法性。
- `PathService`
  提供路径计算与路径重建能力，不持有玩法主控逻辑。
- `BuildingManager`
  管理建筑的建造、修复、销毁和运行时状态。
- `UnitManager`
  管理干员实例槽位的部署、撤退、死亡离场、再部署和场上单位运行时状态。
- `ShopManager`
  管理商店库存、刷新和购买逻辑；每次购买会生成一个独立干员槽位。
- `EnemyManager`
  管理敌人实例、敌人出生、死亡、抵达核心等运行时行为。
- `WaveManager`
  管理波次配置执行和待刷怪队列。
- `BuffManager`
  管理祝福选择与 Buff 生效逻辑。
- `RandomEventManager`
  管理随机事件抽取与事件结算。

### 2.3 `UI`

`UI` 放所有界面节点。

```text
UI
├─ HUD
├─ ActionPanel
├─ BuildPanel
├─ ShopPanel
├─ DeployPanel
├─ EventPanel
├─ BlessingPanel
└─ ResultPanel
```

各节点作用如下：

- `HUD`
  常驻信息栏，显示阶段、天数、资源、声望、核心生命、部署数量等全局信息。
- `ActionPanel`
  主操作与作战控制面板，负责探索、建造、部署朝向、场上单位选中、技能释放和撤退。
- `BuildPanel`
  建造面板，显示可建建筑并发出建造请求。
- `ShopPanel`
  商店面板，显示库存并发出购买、刷新请求。
- `DeployPanel`
  部署面板，按干员实例槽位显示可部署、已部署和再部署冷却状态，并发出部署请求。
- `EventPanel`
  随机事件面板，展示事件内容并发出事件交互请求。
- `BlessingPanel`
  祝福面板，展示三选一祝福并发出选择请求。
- `ResultPanel`
  结算信息面板，用于在游戏结束时展示胜负结果和统计信息。

### 2.4 固定命名

以下节点名属于架构固定项，不允许随意改名：

- `Game`
- `World`
- `Managers`
- `UI`
- `MapRoot`
- `GroundLayer`
- `ResourceLayer`
- `FogLayer`
- `OverlayLayer`
- `SpawnRoot`
- `CoreRoot`
- `BuildingRoot`
- `UnitRoot`
- `EnemyRoot`
- `ProjectileRoot`
- `EffectRoot`

---

## 3. 全局单例

项目只允许以下四个 `Autoload`。

### 3.1 `EventBus.gd`

作用：

- 定义跨模块信号
- 转发跨模块消息

不负责：

- 保存业务数据
- 编写业务规则

### 3.2 `RunState.gd`

作用：

- 保存一局游戏的全局运行状态

负责保存的数据：

- 当前阶段
- 当前天数
- 行动力
- 声望
- 木材、石材、魔力
- 核心生命
- 已获得 Buff
- 已拥有干员实例槽位
- 部署上限
- 当前已部署数量
- 随机种子

不负责：

- 地图格子状态
- 场上单位、建筑、敌人实例管理
- 寻路
- 波次执行

### 3.3 `DataRepo.gd`

作用：

- 读取并缓存 `data/` 下的配置表
- 管理 `scene_key` 到 `PackedScene` 的映射

具体职责：

- 启动时读取 `units.json`、`enemies.json`、`buildings.json`、`buffs.json`、`events.json`、`waves.json`
- 按 `id` 索引这些配置，供其他模块查询
- 维护一张场景注册表，把逻辑名映射到实际场景资源

`data/` 目录中的这些 JSON 文件是配置表，只保存静态配置，不保存一局游戏里的运行时状态。

例如：

- `units.json`
  保存单位的静态配置，例如单位名称、职业、数值、技能编号。
- `enemies.json`
  保存敌人的静态配置，例如敌人名称、数值、行为类型、移动方式。
- `buildings.json`
  保存建筑的静态配置，例如建筑类型、建造成本、效果范围。
- `buffs.json`
  保存 Buff 或祝福的静态配置。
- `events.json`
  保存随机事件的静态配置。
- `waves.json`
  保存夜晚刷怪波次配置。

配置表里不直接写 `res://scenes/...` 路径，而是写 `scene_key`。

`scene_key` 的作用是：在配置表里引用“应该使用哪一种场景模板”。

例如某条单位配置可以写：

```text
scene_key: unit_actor
```

它的含义不是“场上已经有一个叫 `unit_actor` 的对象”，而是：

1. 这条单位配置需要使用“单位模板”来生成实例。
2. `unit_actor` 只是这个模板的逻辑名。
3. `DataRepo` 再把这个逻辑名映射到真正的场景文件，例如 `scenes/actors/UnitActor.tscn`。

也就是说，完整关系是：

```text
配置表中的 scene_key
-> DataRepo 中的场景注册表
-> 具体 .tscn 文件
-> 运行时实例化出的对象
```

例如：

```text
scene_key: unit_actor -> scenes/actors/UnitActor.tscn
scene_key: enemy_actor -> scenes/actors/EnemyActor.tscn
scene_key: building_actor -> scenes/actors/BuildingActor.tscn
```

这样配置表只需要写逻辑名，不需要写具体路径。

`PackedScene` 是 Godot 中“可实例化场景模板”的资源类型。  
例如 `UnitActor.tscn` 被加载后，就是一个 `PackedScene`；当系统需要把某个单位放到 `UnitRoot` 下时，就用这个 `PackedScene` 创建一个真正的单位实例。

对普通单位而言，`scene_key` 应默认指向 `unit_actor`。单位之间的数值、攻击范围、技能参数、技能行为、外观、音效和特效差异，不应优先拆成多个平级单位场景，而应通过 `units.json` 配置和 `UnitActor.tscn` 的公共挂点装配。

只有当某个单位的节点结构、生命周期或交互方式确实不同于普通单位时，才允许使用 `scenes/actors/units/` 下的专用单位场景。专用单位场景必须继承 `UnitActor.tscn`，不能复制一份平级场景后独立维护。

不负责：

- 保存本局运行时状态
- 管理场上对象

### 3.4 `SceneRouter.gd`

作用：

- 切换 `MainMenu.tscn`
- 切换 `Game.tscn`
- 切换 `Result.tscn`

不负责：

- 白天、夜晚、祝福阶段切换
- 业务状态管理

---

## 4. 模块划分

### 4.1 核心架构模块

目录：

- `autoload/`
- `scripts/core/`
- `scenes/bootstrap/`
- `scenes/game/`

文件：

- `autoload/EventBus.gd`
- `autoload/RunState.gd`
- `autoload/DataRepo.gd`
- `autoload/SceneRouter.gd`
- `scripts/core/game_controller.gd`
- `scripts/core/day_manager.gd`
- `scripts/core/night_manager.gd`
- `scripts/core/buff_manager.gd`
- `scripts/core/random_event_manager.gd`
- `scripts/core/game_enums.gd`
- `scenes/bootstrap/MainMenu.tscn`
- `scenes/bootstrap/Result.tscn`
- `scenes/game/Game.tscn`

职责：

- 初始化一局游戏
- 切换阶段
- 维护全局状态
- 加载配置
- 管理主场景切换

各文件作用：

- `EventBus.gd`
  全局事件总线，定义跨模块信号并承担广播通道。
- `RunState.gd`
  全局运行状态中心，保存当前局的公共状态数据。
- `DataRepo.gd`
  配置仓库，负责读取 JSON 配置表并提供场景模板映射。
- `SceneRouter.gd`
  主场景切换器，负责菜单、游戏、结算之间的场景跳转。
- `game_controller.gd`
  整局流程主控，负责开始新一局、切换白天夜晚祝福、结束结算。
- `day_manager.gd`
  白天逻辑控制器，负责探索、白天交互以及进入夜晚前的流程控制。
- `night_manager.gd`
  夜晚逻辑控制器，负责夜战开始、夜战结束和夜战运行状态。
- `buff_manager.gd`
  Buff 控制器，负责生成祝福选项并将 Buff 应用到当前局状态。
- `random_event_manager.gd`
  随机事件控制器，负责抽取事件并执行事件结算。
- `game_enums.gd`
  公共枚举定义文件，集中定义阶段、资源类型、伤害类型等共享常量。
- `MainMenu.tscn`
  菜单主场景，提供开始游戏入口。
- `Result.tscn`
  结算主场景，展示胜负结果。
- `Game.tscn`
  游戏运行主场景，承载整局游戏的 `World`、`Managers`、`UI` 三层结构。

### 4.2 地图模块

目录：

- `scripts/map/`
- `scenes/world/`

文件：

- `scripts/map/map_manager.gd`
- `scripts/map/path_service.gd`
- `scripts/map/cell_data.gd`
- `scripts/map/map_generator.gd`
- `scenes/world/MapRoot.tscn`
- `scenes/world/Core.tscn`
- `scenes/world/SpawnPoint.tscn`

职责：

- 生成地图
- 保存格子数据
- 维护迷雾状态
- 管理刷怪点和核心位置
- 提供格子坐标与可通行信息
- 为敌人寻路提供底层支持

各文件作用：

- `map_manager.gd`
  地图真相数据中心，统一对外提供格子状态查询。
- `path_service.gd`
  路径计算服务，负责根据地图阻挡情况重建路径网格。
- `cell_data.gd`
  单格数据结构，描述地形、发现状态、可建造、占用等属性。
- `map_generator.gd`
  地图生成逻辑，负责按规则生成初始地图。
- `MapRoot.tscn`
  地图显示节点模板，对应 `World/MapRoot`。
- `Core.tscn`
  核心建筑模板。
- `SpawnPoint.tscn`
  刷怪点模板。

### 4.3 建筑模块

目录：

- `scripts/building/`
- `scenes/actors/BuildingActor.tscn`

文件：

- `scripts/building/building_manager.gd`
- `scripts/building/building_actor.gd`
- `scripts/building/build_validator.gd`
- `scenes/actors/BuildingActor.tscn`

职责：

- 建造
- 修复
- 销毁
- 建筑效果结算
- 建筑阻挡对地图和寻路的影响

各文件作用：

- `building_manager.gd`
  建筑运行时主控，管理场上全部建筑实例与建筑生命周期。
- `building_actor.gd`
  单个建筑实例脚本，处理建筑生命、受伤、效果半径等单体行为。
- `build_validator.gd`
  建造合法性校验，判断格子、资源、阶段是否允许建造。
- `BuildingActor.tscn`
  建筑实例模板。

### 4.4 单位与商店模块

目录：

- `scripts/combat/`
- `scenes/actors/UnitActor.tscn`

文件：

- `scripts/combat/unit_manager.gd`
- `scripts/combat/unit_actor.gd`
- `scripts/combat/shop_manager.gd`
- `scripts/combat/skills/unit_skill_behavior.gd`
- `scripts/combat/combat_math.gd`
- `scripts/combat/skill_runtime.gd`
- `scenes/actors/UnitActor.tscn`
- `scenes/actors/units/*.tscn`

职责：

- 商店刷新与购买
- 干员实例槽位部署与撤退
- 按槽位计算再部署冷却
- 单位普攻、受伤、技能
- 单位差异化行为装配
- 统一伤害计算

各文件作用：

- `unit_manager.gd`
  单位运行时主控，管理干员槽位部署、撤退、再部署和场上单位列表。
- `unit_actor.gd`
  单个单位实例脚本，处理攻击、受伤、技能、朝向、阻挡等单体行为，并在初始化时按单位配置装配技能行为组件。
- `skills/unit_skill_behavior.gd`
  单位技能行为基类，定义技能启动、结束、攻击后回调和目标覆盖等扩展点。
- `shop_manager.gd`
  商店主控，管理 5 格卡牌库存、购买和刷新逻辑；购买同一单位类型会新增独立槽位。
- `combat_math.gd`
  伤害与治疗计算工具。
- `skill_runtime.gd`
  技能运行时逻辑，处理技能释放与效果执行。
- `UnitActor.tscn`
  普通单位统一实例模板，保留 `TitleLabel`、`StatusView`、`VisualRoot`、`AudioRoot`、`EffectRoot`、`SkillBehavior` 等公共挂点。
- `scenes/actors/units/*.tscn`
  特殊单位继承场景。只有结构、生命周期或交互方式明显不同于普通单位时才使用，且必须继承 `UnitActor.tscn`。

单位差异化原则：

- 属性差异数据化：生命、攻击、防御、阻挡、攻速、范围、SP、技能参数等写入 `data/units.json`。
- 行为差异组件化：不同技能通过 `skill_behavior_key` 映射到 `UnitSkillBehavior` 子类。
- 结构差异场景化：外观、音效、特效优先挂到 `UnitActor.tscn` 的公共挂点；真正特殊的节点结构才使用继承场景。

### 4.5 敌人与波次模块

目录：

- `scripts/enemy/`
- `scenes/actors/EnemyActor.tscn`

文件：

- `scripts/enemy/enemy_manager.gd`
- `scripts/enemy/enemy_actor.gd`
- `scripts/enemy/wave_manager.gd`
- `scripts/enemy/boss_controller.gd`
- `scenes/actors/EnemyActor.tscn`

职责：

- 按波次刷怪
- 驱动敌人移动、攻击、死亡
- 维护夜战清场判定
- 处理 Boss 阶段逻辑

各文件作用：

- `enemy_manager.gd`
  敌人运行时主控，管理场上所有敌人实例。
- `enemy_actor.gd`
  单个敌人实例脚本，处理移动、受伤、被阻挡、攻击核心等单体行为。
- `wave_manager.gd`
  波次执行器，负责按配置在正确时间生成敌人。
- `boss_controller.gd`
  Boss 专属扩展控制，用于多阶段 Boss 行为。
- `EnemyActor.tscn`
  敌人实例模板。

### 4.6 UI 模块

目录：

- `scripts/ui/`
- `scenes/ui/`

文件：

- `scripts/ui/hud.gd`
- `scripts/ui/action_panel.gd`
- `scripts/ui/build_panel.gd`
- `scripts/ui/shop_panel.gd`
- `scripts/ui/deploy_panel.gd`
- `scripts/ui/event_panel.gd`
- `scripts/ui/blessing_panel.gd`
- `scripts/ui/result_panel.gd`
- `scenes/ui/HUD.tscn`
- `scenes/ui/ActionPanel.tscn`
- `scenes/ui/BuildPanel.tscn`
- `scenes/ui/ShopPanel.tscn`
- `scenes/ui/DeployPanel.tscn`
- `scenes/ui/EventPanel.tscn`
- `scenes/ui/BlessingPanel.tscn`
- `scenes/ui/ResultPanel.tscn`

职责：

- 显示状态
- 切换操作模式
- 展示商店、事件、祝福、结算
- 发出玩家输入请求

各文件作用：

- `hud.gd`
  HUD 逻辑，负责全局状态显示刷新。
- `action_panel.gd`
  主操作面板逻辑，处理地图点击后的探索、建造、按朝向部署，以及选中场上单位后的技能释放、撤退和攻击范围预览。
- `build_panel.gd`
  建造面板逻辑。
- `shop_panel.gd`
  商店面板逻辑，显示 5 格干员卡牌、价格、阶级、刷新与购买反馈。
- `deploy_panel.gd`
  部署面板逻辑。
- `event_panel.gd`
  事件面板逻辑。
- `blessing_panel.gd`
  祝福面板逻辑。
- `result_panel.gd`
  结算面板逻辑。
- `HUD.tscn`
  HUD 模板。
- `ActionPanel.tscn`
  主操作面板模板。
- `BuildPanel.tscn`
  建造面板模板。
- `ShopPanel.tscn`
  商店面板模板。
- `DeployPanel.tscn`
  部署面板模板。
- `EventPanel.tscn`
  事件面板模板。
- `BlessingPanel.tscn`
  祝福面板模板。
- `ResultPanel.tscn`
  结算面板模板。

限制：

- UI 只显示和发请求，不保存业务真相数据。
- UI 不直接修改阶段。
- UI 不直接修改地图、建筑、单位、敌人状态。

### 4.7 数据与资源模块

目录：

- `data/`
- `assets/`

文件：

- `data/units.json`
- `data/enemies.json`
- `data/buildings.json`
- `data/buffs.json`
- `data/events.json`
- `data/waves.json`
- `assets/sprites/`
- `assets/ui/`
- `assets/audio/`
- `assets/fonts/`

职责：

- 提供配置表
- 提供图片、音频、字体资源

---

## 5. 数据归属

每类运行时数据只允许一个拥有者。

| 数据 | 拥有者 |
|---|---|
| 当前阶段、天数、行动力、声望、资源、核心生命、Buff、已拥有干员槽位、部署上限 | `RunState` |
| 地图格子、迷雾、可通行、可建造、占用信息、刷怪点、核心位置 | `MapManager` |
| 场上建筑运行时状态 | `BuildingManager` |
| 场上单位、槽位部署映射、再部署状态、技能运行时状态 | `UnitManager` |
| 商店库存 | `ShopManager` |
| 场上敌人运行时状态 | `EnemyManager` |
| 波次进度与待生成队列 | `WaveManager` |
| Buff 选择与 Buff 结算 | `BuffManager` |
| 随机事件抽取与事件结算 | `RandomEventManager` |
| UI 面板显示状态 | 各 UI 脚本 |

规则：

1. 非拥有者不能私自保存同一份业务真相。
2. 非拥有者只能读取，或通过公开接口请求修改。

---

## 6. 模块协作方式

模块之间只允许以下三种方式协作。

### 6.1 直接调用

用于固定依赖关系，例如：

- `GameController -> DayManager`
- `GameController -> NightManager`
- `BuildingManager -> MapManager`

### 6.2 `EventBus`

用于跨模块广播，例如：

- UI 发出请求
- HUD 响应状态变化
- 建筑变化通知寻路重建

### 6.3 Group

用于同类对象批量处理，例如：

- `units`
- `enemies`
- `buildings`

禁止事项：

- 不允许跨模块硬编码不稳定节点路径。
- 不允许普通模块直接改阶段。
- 不允许 UI 直接改业务状态。

---

## 7. 关键链路

### 7.1 白天探索

```text
UI -> DayManager -> RunState / MapManager / RandomEventManager
```

### 7.2 白天建造

```text
UI -> BuildingManager -> BuildValidator -> RunState -> MapManager -> PathService
```

### 7.3 商店购买

```text
UI -> ShopManager -> RunState -> UnitManager/UI
```

商店购买的结果不是解锁一个单位类型，而是在 `RunState` 中新增一个干员实例槽位。
同一个 `unit_id` 可以被多次购买，每次购买都会得到不同的 `operator_key`，后续部署、撤退和再部署都按这个槽位独立结算。

商店每页包含 5 个槽位。新一天会免费刷新一页，玩家也可以在白天花费 2 声望刷新。
干员按固定权重抽取：1 声望一阶 60%，3 声望二阶 30%，7 声望三阶 10%。同一页允许出现重复干员。
购买指定槽位后，该槽位标记为已购买并保持为空位状态，直到下一次刷新或进入新一天。

### 7.4 进入夜晚

```text
UI -> GameController -> RunState -> NightManager -> WaveManager
```

### 7.5 部署单位

```text
UI -> UnitManager -> RunState -> UnitRoot
```

部署请求使用 `operator_key` 指向一个已拥有干员槽位。`UnitManager` 负责检查该槽位是否已在场、是否处于再部署冷却、当前部署数是否达到上限，以及目标格是否合法。撤退或死亡后只让该槽位进入再部署冷却，不影响同类单位的其他槽位。

主场景中，`DeployPanel` 负责选择干员槽位，`ActionPanel` 负责选择部署朝向并在地图点击时调用部署逻辑。
点击已部署单位所在格会选中该单位，显示 HP、SP、技能名、技能描述和技能持续状态，并可释放技能或撤退。

### 7.6 敌人攻击核心

```text
EnemyActor -> EnemyManager -> RunState -> GameController
```

### 7.7 夜战结束

```text
WaveManager -> GameController -> BuffManager 或 Result
```

---

## 8. Unit 属性与差异化装载

### 8.1 总体原则

单位装载遵循以下分层：

```text
data/units.json
-> DataRepo.get_unit_cfg(unit_id)
-> UnitManager.try_deploy_unit(unit_id, cell, facing)
-> DataRepo.get_scene_by_key(cfg.scene_key)
-> UnitActor.tscn.instantiate()
-> UnitActor.setup_from_cfg(unit_id, cfg, cell, facing)
-> 按 cfg 写入运行时属性并装配行为/表现组件
```

其中：

- `units.json` 保存静态配置，不保存运行时状态。
- `UnitManager` 负责部署合法性、实例化、加入 `UnitRoot`、维护运行时字典和再部署状态。
- `UnitActor` 负责把静态配置转换成单个单位实例上的运行时属性。
- `UnitSkillBehavior` 子类负责技能行为差异。
- `VisualRoot`、`AudioRoot`、`EffectRoot` 负责外观、音效和特效挂载点。

### 8.2 字段归属

单位字段按用途分为四类。

#### 基础数值字段

这类字段直接由 `UnitActor.setup_from_cfg()` 读取并写入运行时变量：

| 字段 | 装载目标 | 说明 |
|---|---|---|
| `max_hp` | `max_hp` / `current_hp` | 最大生命，部署时当前生命回满 |
| `atk` | `atk` | 基础攻击力 |
| `def` | `defense` | 物理防御 |
| `res` | `resistance` | 法术抗性 |
| `block` | `block_count` | 阻挡数 |
| `attack_interval` | `attack_interval` | 普攻间隔 |
| `damage_type` | `damage_type` | 伤害类型，部署时解析成枚举 |
| `target_type` | `target_type` | 目标类型，例如地面或飞行 |
| `range_pattern` | `range_pattern` | 攻击范围格子偏移 |
| `redeploy_sec` | `get_redeploy_sec()` | 撤退或死亡后的再部署冷却 |

#### 技能字段

技能字段分为“技能公共信息”和“具体技能参数”：

| 字段 | 装载目标 | 说明 |
|---|---|---|
| `skill_id` | 技能标识 | 用于显示、日志或默认行为 key 回退 |
| `skill_name` | 技能显示名 | UI 和调试日志读取 |
| `skill_description` | 技能描述 | UI 展示读取 |
| `skill_behavior_key` | `SkillBehavior` 脚本选择 | 映射到某个 `UnitSkillBehavior` 子类 |
| `sp_max` | SP 上限 | 技能行为或 `UnitActor` 读取 |
| `sp_recover_per_sec` | SP 回复速度 | 技能行为或 `UnitActor` 读取 |
| `skill_duration` | 技能持续时间 | 技能行为读取 |

具体技能参数由对应技能脚本按需读取。例如近卫技能读取 `skill_block_bonus`，狙击技能读取 `skill_range_pattern`、`skill_attack_multiplier`、`skill_splash_radius` 等。

#### 表现资源字段

表现字段不应直接写 `res://` 路径，而应写逻辑 key：

| 字段 | 建议装载位置 | 说明 |
|---|---|---|
| `icon_key` | UI 面板 | 单位图标逻辑名 |
| `visual_key` | `VisualRoot` | 单位外观资源逻辑名 |
| `attack_sfx_key` | `AudioRoot` | 普攻音效逻辑名 |
| `cast_sfx_key` | `AudioRoot` | 技能音效逻辑名 |
| `cast_vfx_key` | `EffectRoot` | 技能释放特效逻辑名 |
| `hit_vfx_key` | `EffectRoot` | 受击特效逻辑名 |

资源 key 到实际资源路径的映射可以后续集中放入资源仓库或专门的表现配置表，避免单位表直接依赖具体文件路径。

#### 场景字段

| 字段 | 装载目标 | 说明 |
|---|---|---|
| `scene_key` | `DataRepo.get_scene_by_key()` | 普通单位默认使用 `unit_actor` |

普通单位不应因为外观、音效、特效或技能不同而改成专用 `scene_key`。专用 `scene_key` 只用于结构非常特殊的单位，并且对应 `.tscn` 必须继承 `UnitActor.tscn`。

### 8.3 详细例子：近卫单位装载

假设 `data/units.json` 中有如下配置：

```json
{
  "id": "guard_01",
  "name": "近卫",
  "class": "guard",
  "cost_prestige": 1,
  "max_hp": 120,
  "atk": 30,
  "def": 10,
  "res": 0,
  "block": 2,
  "attack_interval": 1.0,
  "damage_type": "physical",
  "target_type": "ground",
  "range_pattern": [[0, 0], [1, 0]],
  "redeploy_sec": 12.0,
  "sp_max": 18,
  "sp_recover_per_sec": 1.0,
  "skill_id": "guard_hold_line",
  "skill_behavior_key": "guard_hold_line",
  "skill_name": "战术咏唱·阵线压制",
  "skill_description": "阻挡数+1，普通攻击同时攻击所有被自身阻挡的敌人，持续10秒。",
  "skill_duration": 10.0,
  "skill_block_bonus": 1,
  "scene_key": "unit_actor",
  "icon_key": "guard_01_icon",
  "visual_key": "guard_visual",
  "attack_sfx_key": "guard_attack",
  "cast_vfx_key": "guard_hold_line_cast"
}
```

部署时的装载流程如下：

1. UI 发出部署请求：`request_deploy.emit(&"guard_01", cell, facing)`。
2. `UnitManager` 调用 `DataRepo.get_unit_cfg(&"guard_01")` 取得配置副本。
3. `UnitManager` 校验阶段、拥有状态、部署上限、再部署冷却和地图格子合法性。
4. `UnitManager` 读取 `scene_key: "unit_actor"`，通过 `DataRepo.get_scene_by_key(&"unit_actor")` 取得 `UnitActor.tscn`。
5. `UnitManager` 实例化 `UnitActor.tscn`，加入 `World/UnitRoot`，分配 `runtime_id`。
6. `UnitManager` 调用 `actor.setup_from_cfg(&"guard_01", cfg, cell, facing)`。
7. `UnitActor` 将基础字段写入运行时变量：
   - `max_hp = 120`，`current_hp = 120`
   - `atk = 30`
   - `defense = 10`
   - `resistance = 0`
   - `block_count = 2`
   - `attack_interval = 1.0`
   - `damage_type = DAMAGE_PHYSICAL`
   - `target_type = &"ground"`
   - `range_pattern = [Vector2i(0, 0), Vector2i(1, 0)]`
8. `UnitActor` 根据 `cell` 和地图坐标系统设置 `global_position`，根据 `facing` 记录攻击朝向。
9. `UnitActor` 根据 `name` 更新 `TitleLabel`，根据生命和 SP 更新 `StatusView`。
10. `UnitActor` 读取 `skill_behavior_key: "guard_hold_line"`，找到 `guard_hold_line_skill.gd`，挂到 `SkillBehavior` 节点。
11. `SkillBehavior.setup(self)` 保存所属单位引用，后续可读取 `owner_unit.cfg` 中的技能参数。
12. 夜战中单位自动回复 SP；当 SP 满且玩家释放技能时，`guard_hold_line_skill.gd` 读取：
    - `skill_duration = 10.0`
    - `skill_block_bonus = 1`
13. 技能启动时，技能脚本临时把 `owner_unit.block_count` 从 `2` 改为 `3`，并让普攻目标覆盖为当前阻挡的所有敌人。
14. 技能结束时，技能脚本恢复原始阻挡数。

这个例子中，近卫没有使用专用 `Guard.tscn`，因为它的差异可以被“数值配置 + 技能行为脚本 + 公共挂点”表达。

### 8.4 什么时候允许专用 Unit 场景

如果未来出现特殊单位，例如部署后展开为多个可受击部件、拥有独立炮塔子节点、或需要特殊碰撞结构，则可以新增：

```text
scenes/actors/units/SpecialUnit.tscn
```

但该场景必须通过 Godot 的继承场景机制继承：

```text
SpecialUnit.tscn inherits UnitActor.tscn
```

这样公共节点、公共脚本和后续新增挂点仍然由 `UnitActor.tscn` 统一维护。专用场景只覆盖特殊结构或特殊资源，不复制公共生命周期逻辑。
