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
│  ├─ debug/                   [调试与沙盒场景]
│  │  └─ CombatSandbox.tscn
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
│     ├─ ActionPanel.tscn
│     ├─ BuildPanel.tscn
│     ├─ BuildListCard.tscn
│     ├─ EventPanel.tscn
│     ├─ BlessingPanel.tscn
│     ├─ ResultPanel.tscn
│     ├─ DebugPanel.tscn
│     └─ combat/               [作战 HUD 组件]
│        ├─ CombatHud.tscn
│        ├─ OperatorCard.tscn
│        └─ UnitDetailPanel.tscn
├─ scripts/
│  ├─ common/                  [跨模块轻量辅助]
│  ├─ bootstrap/               [菜单与结算入口脚本]
│  ├─ core/                    [阶段与全局控制]
│  ├─ map/                     [地图与寻路]
│  ├─ building/                [建筑]
│  ├─ combat/                  [单位、技能、商店]
│  ├─ enemy/                   [敌人、波次、Boss]
│  ├─ ui/                      [界面逻辑，含 ui/combat 作战 HUD]
│  └─ debug/                   [调试场景逻辑]
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

`CombatSandbox.tscn` 属于调试入口，不计入正式运行主场景。它复用 `World`、`Managers` 和 `UI` 三层结构，用于快速验证部署、刷怪、技能和作战 HUD 交互。

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
├─ ActionPanel
├─ BuildPanel
├─ CombatHud
├─ CombatHudController
├─ EventPanel
├─ BlessingPanel
├─ ResultPanel
└─ DebugPanel
```

各节点作用如下：

- `ActionPanel`
  白天行动面板，只负责待机、探索、进入夜晚，以及建造模式下的地图点击转发。
- `BuildPanel`
  左侧建筑/商店复合面板。建筑模式下显示资源/增益类建筑；商店模式下显示招募槽位、价格和刷新入口。
- `CombatHud`
  作战 HUD，主场景夜晚和 `CombatSandbox` 共用；负责顶部作战状态、暂停/倍速、底部待部署干员卡槽、拖拽提示、单位详情面板和调试抽屉入口。
- `CombatHudController`
  主场景作战 UI 适配器，连接 `CombatHud`、`MapRoot`、`UnitManager` 和 `EnemyManager`，处理拖拽部署、二段朝向、单位选中、技能、撤退、暂停和倍速。
- `EventPanel`
  随机事件面板，展示事件内容并发出事件交互请求。
- `BlessingPanel`
  祝福面板，展示三选一祝福并发出选择请求。
- `ResultPanel`
  结算信息面板，用于在游戏结束时展示胜负结果和统计信息。
- `DebugPanel`
  正式主场景中的调试入口，默认仅用于开发验证。

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
- 在 Autoload 生命周期中加载静态配置，并通过 `data_loaded` 通知依赖方

具体职责：

- Autoload `_ready()` 时读取 `units.json`、`enemies.json`、`buildings.json`、`buffs.json`、`events.json`、`waves.json` 和应用级配置
- 按 `id` 索引这些配置，供其他模块查询
- 提供按建筑类别读取建筑 ID 的接口，供 `BuildPanel` 从 `buildings.json[].building_type` 动态生成建筑列表
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
- 在每局开始时重复承担运行时初始化职责

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
- `scripts/common/`
- `scripts/bootstrap/`
- `scripts/core/`
- `scenes/bootstrap/`
- `scenes/game/`

文件：

- `autoload/EventBus.gd`
- `autoload/RunState.gd`
- `autoload/DataRepo.gd`
- `autoload/SceneRouter.gd`
- `scripts/common/action_result.gd`
- `scripts/common/app_refs.gd`
- `scripts/bootstrap/main_menu_scene.gd`
- `scripts/bootstrap/result_scene.gd`
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
- 在 `DataRepo` Autoload 生命周期内加载静态配置
- 管理主场景切换

各文件作用：

- `EventBus.gd`
  全局事件总线，定义跨模块信号并承担广播通道。
- `RunState.gd`
  全局运行状态中心，保存当前局的公共状态数据。
- `DataRepo.gd`
  配置仓库，负责读取 JSON 配置表与全局调参文件，并提供场景模板映射。
- `SceneRouter.gd`
  主场景切换器，负责菜单、游戏、结算之间的场景跳转。
- `action_result.gd`
  `try_` 类接口的统一返回结构辅助，提供成功和失败结果的构造方法。
- `app_refs.gd`
  全局单例访问辅助，集中封装 `/root/EventBus`、`/root/RunState`、`/root/DataRepo` 和 `/root/SceneRouter` 的查找。
- `main_menu_scene.gd`
  主菜单场景脚本，负责开始游戏入口与主题应用。
- `result_scene.gd`
  结算场景脚本，负责展示结算面板并处理重开或返回菜单。
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
- `scripts/map/map_root_view.gd`
- `scripts/map/core_view.gd`
- `scripts/map/spawn_point_view.gd`
- `scenes/world/MapRoot.tscn`
- `scenes/world/Core.tscn`
- `scenes/world/SpawnPoint.tscn`

职责：

- 生成地图
- 保存格子数据
- 维护迷雾状态
- 管理刷怪点和核心位置
- 提供格子坐标与可通行信息
- 根据 `data/map_generation.json` 统一读取地图生成参数
- 在格子上记录资源点与随机事件点，但不结算资源或事件效果
- 为敌人寻路提供底层支持
- 为 UI 提供格子预览与作战范围绘制

地图生成当前规则：

- 地图默认 30×30，核心固定在中心，核心周围 5×5 初始可见。
- 障碍随机生成，但核心安全半径与刷怪点安全半径内不生成障碍、资源点和事件点。
- 障碍放置会保持刷怪点到核心的地面路径连通，避免地图生成破坏夜晚基础路径。
- 资源类型为木材、石材、魔力，当前每种目标 12 个；其中每种至少 2 个放在初始可见区外侧的近探索圈作为开局保底。
- 随机事件点是格子属性，数量由 `event_point_count` 控制，事件内容引用 `events.json`。
- 事件点与资源点互斥；地图模块只负责放置和记录事件 ID，事件展示、行动力消耗和效果结算由白天流程与随机事件模块负责。

各文件作用：

- `map_manager.gd`
  地图真相数据中心，统一对外提供格子状态查询。它持有格子的发现状态、地形、资源、事件标记、占用状态、核心位置和刷怪点位置。普通占用刷新不得重置玩家镜头；只有首次加载、生成新地图、重置地图或尺寸变化时才允许请求重置视角。
- `path_service.gd`
  路径计算服务，负责根据地图阻挡情况重建路径网格。
- `cell_data.gd`
  单格数据结构，描述地形、发现状态、资源类型、随机事件 ID、可建造、可通行、占用等属性。
- `map_generator.gd`
  地图生成逻辑，负责按 `data/map_generation.json` 生成初始地图，包括核心、初始迷雾、刷怪点、障碍、资源点和随机事件点。
- `map_root_view.gd`
  `MapRoot.tscn` 的显示与输入脚本，负责图层绘制、鼠标点击转发、攻击范围和部署预览。
- `core_view.gd`
  核心建筑显示脚本，负责核心节点的占位绘制与标签表现。
- `spawn_point_view.gd`
  刷怪点显示脚本，负责刷怪口节点的占位绘制与标签表现。
- `MapRoot.tscn`
  地图显示节点模板，对应 `World/MapRoot`。除基础格子绘制外，还负责鼠标悬停、选中格、攻击范围、部署落点、非法格、朝向箭头等作战预览层。
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
- `scripts/combat/projectile.gd`
- `scripts/combat/skills/unit_skill_behavior.gd`
- `scripts/combat/skills/*_skill.gd`
- `scripts/combat/combat_math.gd`
- `scenes/actors/UnitActor.tscn`
- `scenes/actors/Projectile.tscn`
- `scenes/actors/units/*.tscn`

职责：

- 商店刷新与购买
- 干员实例槽位部署与撤退
- 按槽位计算再部署冷却
- 单位普攻、受伤、技能
- 飞行物发射、追踪和命中触发
- 单位差异化行为装配
- 统一伤害计算

各文件作用：

- `unit_manager.gd`
  单位运行时主控，管理干员槽位部署、撤退、再部署和场上单位列表。
- `unit_actor.gd`
  单个单位实例脚本，处理攻击、受伤、技能、朝向、阻挡等单体行为，并在初始化时按单位配置装配技能行为组件。即时攻击和飞行物攻击共用命中结算路径，技能 `after_attack()` 必须在真实命中后触发；技能也可以通过 `get_attack_projectile_payloads()` 把一次攻击拆成多条可见弹道。
- `projectile.gd`
  通用飞行物 Actor，负责追踪目标、命中半径、生命周期和命中信号，不承载职业或技能规则。
- `skills/unit_skill_behavior.gd`
  单位技能行为基类，定义技能启动、结束、攻击后回调、目标覆盖、伤害修正、受击回调和飞行物 payload 等扩展点。
- `skills/*_skill.gd`
  具体单位技能行为脚本。`UnitActor` 根据 `data/units.json` 中的 `skill_behavior_key` 从注册表选择脚本，并动态挂到 `SkillBehavior` 节点；不同技能的差异优先写在这些组件里。
- `shop_manager.gd`
  商店主控，管理 5 格卡牌库存、购买和刷新逻辑；购买同一单位类型会新增独立槽位。
- `combat_math.gd`
  伤害与治疗计算工具。
- `UnitActor.tscn`
  普通单位统一实例模板，保留 `TitleLabel`、`StatusView`、`VisualRoot`、`AudioRoot`、`EffectRoot`、`SkillBehavior` 等公共挂点。
- `Projectile.tscn`
  通用飞行物模板，由 `World/ProjectileRoot` 承载。默认使用轻量占位绘制，后续可以通过 `projectile_scene_key` 替换为专用箭矢、法球或炸弹场景。
- `scenes/actors/units/*.tscn`
  特殊单位继承场景。只有结构、生命周期或交互方式明显不同于普通单位时才使用，且必须继承 `UnitActor.tscn`。

单位差异化原则：

- 属性差异数据化：生命、攻击、防御、阻挡、攻速、范围、SP、技能参数等写入 `data/units.json`。
- 行为差异组件化：不同技能通过 `skill_behavior_key` 映射到 `UnitSkillBehavior` 子类，由 `UnitActor` 在部署初始化时动态装配到 `SkillBehavior` 节点；技能弹道表现通过返回飞行物 payload 扩展，而不是把技能规则写进 `Projectile`。
- 技能不使用中心化 controller 统一分发。`UnitManager` 只负责请求释放技能，`UnitActor` 负责调用当前装配的技能行为组件，具体技能脚本负责自己的状态、持续时间、伤害修正、追加效果和结束恢复。
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
- `scripts/enemy/enemy_movement_controller.gd`
- `scripts/enemy/enemy_attack_controller.gd`
- `scenes/actors/EnemyActor.tscn`

职责：

- 按波次刷怪
- 驱动敌人移动、攻击、死亡
- 维护夜战清场判定
- 目标上通过 `BossController` 处理 Boss 多阶段逻辑

各文件作用：

- `enemy_manager.gd`
  敌人运行时主控，管理场上所有敌人实例。
- `enemy_actor.gd`
  单个敌人实例脚本，处理受伤、死亡和子控制器调度。它是普通敌人和 Boss 的运行时门面；当敌人配置为 Boss 或带有 `phases` 时，会按需启用 `BossController`；移动、寻路、阻挡贴位、击退和移速倍率交给 `EnemyMovementController`；阻挡攻击、远程攻击和路径建筑攻击交给 `EnemyAttackController`。
- `wave_manager.gd`
  波次执行器，负责按配置在正确时间生成敌人。
- `boss_controller.gd`
  通用多阶段 Boss 控制器。它读取 `enemies.json[].phases`，管理阶段编号、转阶段无敌计时、阶段配置切换和阶段进入效果。该脚本不硬编码具体 Boss；多个 Boss 的共性阶段机制走配置，特殊 Boss 机制后续可通过 `boss_behavior_key` 挂专用行为组件。
- `enemy_movement_controller.gd`
  单个敌人的移动控制器，由 `EnemyActor` 按需创建并调度。它维护路径缓存、路径进度、路径模式、阻挡状态、阻挡贴位、击退和外部移速倍率；不负责攻击结算、死亡移除或 Boss 阶段流转。普通路径模式默认避开挡路建筑；当正常路径不存在且核心所在连通区域被未损毁的挡路建筑封闭时，当前路径临时按拆除模式重算，让敌人在路线上拆除城墙。
- `enemy_attack_controller.gd`
  单个敌人的攻击控制器，由 `EnemyActor` 按需创建并调度。它维护攻击计时，处理阻挡单位攻击、远程索敌攻击和路径建筑攻击；不负责移动、寻路、死亡移除或 Boss 阶段流转。
- `EnemyActor.tscn`
  敌人实例模板。

关于 `enemy_targeting.gd`：

当前不单独拆出目标选择模块。现有索敌只服务于 `EnemyAttackController` 的远程普攻流程，尚未形成跨 Boss、技能、建筑攻击或多种敌人策略复用的公共能力。若后续出现优先低血量、优先建筑、仇恨列表、嘲讽、隐身、飞行/地面过滤、Boss 技能共用索敌等差异化目标策略，再将目标选择抽为独立 `enemy_targeting.gd`。

### 4.6 UI 模块

目录：

- `scripts/ui/`
- `scenes/ui/`

文件：

- `scripts/ui/action_panel.gd`
- `scripts/ui/app_theme.gd`
- `scripts/ui/actor_status_view.gd`
- `scripts/ui/build_panel.gd`
- `scripts/ui/build_list_card.gd`
- `scripts/ui/game_ui_style.gd`
- `scripts/ui/ui_display_text.gd`（规划）
- `scripts/ui/event_panel.gd`
- `scripts/ui/blessing_panel.gd`
- `scripts/ui/result_panel.gd`
- `scripts/ui/combat/combat_hud.gd`
- `scripts/ui/combat/combat_hud_controller.gd`
- `scripts/ui/combat/operator_card.gd`
- `scripts/ui/combat/unit_detail_panel.gd`
- `scenes/ui/ActionPanel.tscn`
- `scenes/ui/BuildPanel.tscn`
- `scenes/ui/BuildListCard.tscn`
- `scenes/ui/EventPanel.tscn`
- `scenes/ui/BlessingPanel.tscn`
- `scenes/ui/ResultPanel.tscn`
- `scenes/ui/DebugPanel.tscn`
- `scenes/ui/combat/CombatHud.tscn`
- `scenes/ui/combat/OperatorCard.tscn`
- `scenes/ui/combat/UnitDetailPanel.tscn`

职责：

- 显示状态
- 切换操作模式
- 展示商店、事件、祝福、结算
- 发出玩家输入请求

各文件作用：

- `action_panel.gd`
  白天行动面板逻辑，处理待机、探索、进入夜晚，以及建造模式下的地图点击转发。
- `app_theme.gd`
  全局 UI 主题辅助，集中加载中文字体并生成控件主题。
- `actor_status_view.gd`
  单位、敌人和建筑 Actor 复用的轻量状态显示脚本，负责 HP 状态和受击反馈。
- `build_panel.gd`
  建筑/商店复合面板逻辑。建筑页从 `DataRepo.get_building_ids_by_type()` 读取 `buildings.json` 中的动态分类、排序、说明和占位图标文本；商店页读取 `ShopManager` 库存。建筑选择写入 `ActionPanel` 的建造模式；商店购买和刷新通过 `EventBus` 请求 `ShopManager`。所有状态变化统一通过 `refresh_from_state()` 刷新，避免初始化和切换标签走不同路径。
- `build_list_card.gd`
  左侧建筑/商店列表项逻辑，显示标题、说明、状态、价格和选中态。
- `game_ui_style.gd`
  共用 UI 样式辅助函数，集中生成暗色玻璃面板、按钮和进度条等 `StyleBox`。
- `ui_display_text.gd`（规划）
  统一显示文本工具，集中处理职业、阶级、伤害类型、方向、阶段、占位图标文本等跨 UI 复用映射。数据表已有 `name`、`desc`、`icon_text` 时优先使用数据字段，工具只负责兜底和统一规则。详细设计见 `docs/UI_DISPLAY_TEXT.md`。
- `combat/combat_hud.gd`
  作战 HUD 容器逻辑，负责顶部状态、暂停/倍速、底部干员卡槽、拖拽提示、单位详情面板和调试抽屉按钮。它只发出 UI 信号，不直接修改单位或地图真相数据。
- `combat/combat_hud_controller.gd`
  主场景作战 UI 适配器，负责把 `CombatHud` 信号转成部署、选中、技能、撤退、暂停、倍速和预览绘制。
- `combat/operator_card.gd`
  单个待部署干员卡片逻辑，展示可部署、已部署和冷却状态，并把按下事件转换为 `operator_key` 信号。
- `combat/unit_detail_panel.gd`
  已部署单位详情面板逻辑，展示 HP、SP、属性、技能描述、技能可用状态，并发出释放技能和撤退请求。
- `event_panel.gd`
  事件面板逻辑。
- `blessing_panel.gd`
  祝福面板逻辑。
- `result_panel.gd`
  结算面板逻辑。
- `ActionPanel.tscn`
  白天行动面板模板。
- `BuildPanel.tscn`
  建筑/商店复合面板模板。
- `BuildListCard.tscn`
  建筑/商店列表项模板。
- `CombatHud.tscn`
  作战 HUD 场景模板。
- `OperatorCard.tscn`
  待部署干员卡片模板。
- `UnitDetailPanel.tscn`
  已部署单位详情面板模板。
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
- UI 控制器和面板响应状态变化
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

主场景和 `CombatSandbox` 统一使用场景化 `CombatHud` 验证作战交互。主场景由 `CombatHudController` 转接 UI 信号；沙盒由 `combat_sandbox.gd` 转接同一套 HUD 信号并保留调试抽屉。部署采用两段式拖拽：

1. 从底部待部署干员卡拖到地图格并松手，`UnitManager.validate_deploy_operator()` 只做合法性校验和预览，不创建单位。
2. 落点锁定后，从落点向外拖拽选择上下左右朝向并松手确认，最终调用 `UnitManager.try_deploy_operator()` 完成部署。

点击已部署单位所在格会选中该单位，显示 HP、SP、技能名、技能描述和技能持续状态，并可释放技能或撤退。点击没有单位的地图格会取消当前单位选中，清除攻击范围预览和详情面板，避免旧选中状态残留。

部署预览由 `MapRoot` 绘制，包含合法/非法落点、锁定落点、朝向箭头和攻击范围。普通地图刷新只重绘图层，不应把玩家镜头拉回地图中心。

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
| `attack_delivery` | 普攻结算路径 | `instant` 即时命中；`projectile` 通过飞行物命中 |
| `projectile_scene_key` | `launch_projectile()` | 飞行物场景逻辑名 |
| `projectile_speed` | `Projectile.speed` | 飞行物追踪速度 |
| `projectile_hit_radius` | `Projectile.hit_radius` | 飞行物命中半径 |
| `projectile_lifetime` | `Projectile.max_lifetime` | 飞行物最大存活时间 |
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

1. `CombatHudController` 或 `CombatSandbox` 调用 `UnitManager.try_deploy_operator(&"guard_01", cell, facing)`。
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
