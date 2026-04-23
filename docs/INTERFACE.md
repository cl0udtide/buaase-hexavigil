# INTERFACE

## 1. 接口总览

项目接口分为两类：

1. 公开方法
   由各模块脚本对外提供，供固定依赖方直接调用。
2. `EventBus` 信号
   由跨模块事件统一通过信号广播。

接口只描述模块之间允许怎样交互，不描述内部实现。

---

## 2. 接口规则

### 2.1 公开方法

公开方法只用于稳定依赖关系，例如：

- `GameController -> DayManager`
- `BuildingManager -> MapManager`
- `EnemyManager -> RunState`

外部模块只能调用公开方法，不能直接修改别的模块内部成员变量。

### 2.2 请求类方法返回值

所有“尝试执行”的公开方法统一返回 `ActionResult`：

```gdscript
{
    "ok": true,
    "code": &"OK",
    "message": "",
    "payload": {}
}
```

失败时例如：

```gdscript
{
    "ok": false,
    "code": &"NOT_ENOUGH_AP",
    "message": "行动力不足",
    "payload": {}
}
```

适用规则：

- 所有以 `try_` 开头的方法都应返回 `ActionResult`。

### 2.3 命名规则

方法命名：

- `get_xxx`
  读取数据
- `can_xxx`
  判断是否合法
- `try_xxx`
  尝试执行，返回 `ActionResult`
- `_do_xxx`
  内部实际执行

信号命名：

- `request_xxx`
  请求，尚未表示成功
- `xxx_changed`
  数值或状态已改变
- `xxx_ready`
  UI 或数据已准备好
- `xxx_placed` / `xxx_destroyed` / `xxx_died`
  事件已经发生

---

## 3. 公开方法接口

### 3.1 核心架构模块

#### `GameController`

作用：

- 整局流程主控
- 切换白天、夜晚、祝福、结算

```gdscript
func start_new_run(seed: int = -1) -> void
func enter_day(day: int) -> void
func enter_night() -> void
func enter_blessing() -> void
func end_run(win: bool) -> void
func get_current_phase() -> int
```

方法规格：

- `start_new_run(seed)`
  输入：`seed: int`，`-1` 表示内部生成随机种子。
  行为：重置本局状态，加载配置，并启动新一局流程。
  返回：无。
- `enter_day(day)`
  输入：`day: int`。
  行为：切换到指定天数的白天阶段，并执行白天初始化。
  返回：无。
- `enter_night()`
  输入：无。
  行为：从当前白天切换到夜晚阶段，并启动夜晚流程。
  返回：无。
- `enter_blessing()`
  输入：无。
  行为：进入祝福选择阶段。
  返回：无。
- `end_run(win)`
  输入：`win: bool`。
  行为：结束当前局并进入结算流程。
  返回：无。
- `get_current_phase()`
  输入：无。
  行为：读取当前阶段。
  返回：当前阶段枚举值。

#### `DayManager`

作用：

- 白天阶段逻辑入口

```gdscript
func start_day(day: int) -> void
func try_explore(cell: Vector2i) -> Dictionary
func try_trigger_event(cell: Vector2i) -> Dictionary
func request_start_night() -> Dictionary
```

方法规格：

- `start_day(day)`
  输入：`day: int`。
  行为：初始化指定天数的白天状态。
  返回：无。
- `try_explore(cell)`
  输入：`cell: Vector2i`。
  行为：校验指定格子是否允许探索；成功时扣除行动力并触发揭雾/事件流程。
  成功结果：返回 `ActionResult(ok = true)`，并推进探索后续逻辑。
  失败结果：返回 `ActionResult(ok = false)`，不修改状态。
- `try_trigger_event(cell)`
  输入：`cell: Vector2i`。
  行为：校验并处理指定格子的事件交互。
  成功结果：返回 `ActionResult(ok = true)`，并完成事件结算。
  失败结果：返回 `ActionResult(ok = false)`，不修改状态。
- `request_start_night()`
  输入：无。
  行为：校验当前是否允许结束白天并进入夜晚。
  成功结果：返回 `ActionResult(ok = true)`，允许后续切换夜晚。
  失败结果：返回 `ActionResult(ok = false)`，保持白天状态。

#### `NightManager`

作用：

- 夜晚阶段逻辑入口

```gdscript
func start_night(day: int) -> void
func finish_night() -> void
func is_night_running() -> bool
```

方法规格：

- `start_night(day)`
  输入：`day: int`。
  行为：初始化指定天数的夜晚流程。
  返回：无。
- `finish_night()`
  输入：无。
  行为：结束当前夜晚流程。
  返回：无。
- `is_night_running()`
  输入：无。
  行为：读取夜晚运行状态。
  返回：`bool`。

#### `BuffManager`

作用：

- 祝福抽取与 Buff 应用

```gdscript
func get_random_blessing_choices(count: int = 3) -> Array[StringName]
func apply_blessing(buff_id: StringName) -> Dictionary
func has_buff(buff_id: StringName) -> bool
func get_all_buffs() -> Array[StringName]
```

方法规格：

- `get_random_blessing_choices(count)`
  输入：`count: int = 3`。
  行为：生成指定数量的祝福候选。
  返回：`Array[StringName]`。
- `apply_blessing(buff_id)`
  输入：`buff_id: StringName`。
  行为：校验并应用指定 Buff。
  成功结果：返回 `ActionResult(ok = true)`，Buff 生效。
  失败结果：返回 `ActionResult(ok = false)`，Buff 不生效。
- `has_buff(buff_id)`
  输入：`buff_id: StringName`。
  行为：检查当前是否已拥有指定 Buff。
  返回：`bool`。
- `get_all_buffs()`
  输入：无。
  行为：读取当前已拥有 Buff 列表。
  返回：`Array[StringName]`。

#### `RandomEventManager`

作用：

- 随机事件抽取与结算

```gdscript
func roll_event_for_cell(cell: Vector2i) -> StringName
func apply_event(event_id: StringName) -> Dictionary
func get_event_cfg(event_id: StringName) -> Dictionary
```

方法规格：

- `roll_event_for_cell(cell)`
  输入：`cell: Vector2i`。
  行为：为指定格子抽取随机事件。
  返回：事件 `id`；无事件时返回空值或约定空标识。
- `apply_event(event_id)`
  输入：`event_id: StringName`。
  行为：结算指定事件。
  成功结果：返回 `ActionResult(ok = true)`，事件结算完成。
  失败结果：返回 `ActionResult(ok = false)`，不修改状态。
- `get_event_cfg(event_id)`
  输入：`event_id: StringName`。
  行为：读取事件静态配置。
  返回：`Dictionary`。

#### `RunState`

作用：

- 当前局公共状态读写入口

```gdscript
func reset_for_new_run(seed: int) -> void
func set_phase(phase: int) -> void
func set_day(day: int) -> void
func reset_action_points(value: int) -> void
func consume_action_points(cost: int) -> Dictionary
func add_prestige(value: int) -> void
func spend_prestige(cost: int) -> Dictionary
func add_materials(wood: int, stone: int, mana: int) -> void
func spend_materials(wood: int, stone: int, mana: int) -> Dictionary
func damage_core(value: int) -> void
func heal_core(value: int) -> void
func add_owned_unit(unit_id: StringName) -> void
func has_owned_unit(unit_id: StringName) -> bool
func set_deploy_limit(value: int) -> void
func change_deployed_count(delta: int) -> void
```

方法规格：

- `reset_for_new_run(seed)`
  输入：`seed: int`。
  行为：按给定种子重置整局公共状态。
  返回：无。
- `set_phase(phase)`
  输入：`phase: int`。
  行为：写入当前阶段并广播阶段变化。
  返回：无。
- `set_day(day)`
  输入：`day: int`。
  行为：写入当前天数。
  返回：无。
- `reset_action_points(value)`
  输入：`value: int`。
  行为：将行动力重置为指定值。
  返回：无。
- `consume_action_points(cost)`
  输入：`cost: int`。
  行为：尝试扣除行动力。
  成功结果：返回 `ActionResult(ok = true)`，行动力已扣除。
  失败结果：返回 `ActionResult(ok = false)`，行动力不变。
- `add_prestige(value)`
  输入：`value: int`。
  行为：增加声望。
  返回：无。
- `spend_prestige(cost)`
  输入：`cost: int`。
  行为：尝试扣除声望。
  成功结果：返回 `ActionResult(ok = true)`，声望已扣除。
  失败结果：返回 `ActionResult(ok = false)`，声望不变。
- `add_materials(wood, stone, mana)`
  输入：三类材料增量。
  行为：增加材料。
  返回：无。
- `spend_materials(wood, stone, mana)`
  输入：三类材料消耗量。
  行为：尝试扣除材料。
  成功结果：返回 `ActionResult(ok = true)`，材料已扣除。
  失败结果：返回 `ActionResult(ok = false)`，材料不变。
- `damage_core(value)`
  输入：`value: int`。
  行为：对核心造成伤害。
  返回：无。
- `heal_core(value)`
  输入：`value: int`。
  行为：恢复核心生命。
  返回：无。
- `add_owned_unit(unit_id)`
  输入：`unit_id: StringName`。
  行为：将单位加入已拥有列表。
  返回：无。
- `has_owned_unit(unit_id)`
  输入：`unit_id: StringName`。
  行为：检查是否已拥有该单位。
  返回：`bool`。
- `set_deploy_limit(value)`
  输入：`value: int`。
  行为：设置部署上限。
  返回：无。
- `change_deployed_count(delta)`
  输入：`delta: int`。
  行为：增减当前已部署数量。
  返回：无。

#### `DataRepo`

作用：

- 查询配置表
- 查询场景模板

```gdscript
func load_all() -> void
func get_unit_cfg(unit_id: StringName) -> Dictionary
func get_enemy_cfg(enemy_id: StringName) -> Dictionary
func get_building_cfg(building_id: StringName) -> Dictionary
func get_buff_cfg(buff_id: StringName) -> Dictionary
func get_event_cfg(event_id: StringName) -> Dictionary
func get_wave_cfg(day: int) -> Dictionary
func get_scene_by_key(scene_key: StringName) -> PackedScene
```

方法规格：

- `load_all()`
  输入：无。
  行为：读取并缓存全部配置表。
  返回：无。
- `get_unit_cfg(unit_id)`
  输入：`unit_id: StringName`。
  行为：查询单位配置。
  返回：`Dictionary`。
- `get_enemy_cfg(enemy_id)`
  输入：`enemy_id: StringName`。
  行为：查询敌人配置。
  返回：`Dictionary`。
- `get_building_cfg(building_id)`
  输入：`building_id: StringName`。
  行为：查询建筑配置。
  返回：`Dictionary`。
- `get_buff_cfg(buff_id)`
  输入：`buff_id: StringName`。
  行为：查询 Buff 配置。
  返回：`Dictionary`。
- `get_event_cfg(event_id)`
  输入：`event_id: StringName`。
  行为：查询事件配置。
  返回：`Dictionary`。
- `get_wave_cfg(day)`
  输入：`day: int`。
  行为：查询指定天数波次配置。
  返回：`Dictionary`。
- `get_scene_by_key(scene_key)`
  输入：`scene_key: StringName`。
  行为：将逻辑场景名解析为场景模板。
  返回：`PackedScene`。

#### `SceneRouter`

作用：

- 切换主场景

```gdscript
func goto_menu() -> void
func goto_game() -> void
func goto_result(win: bool) -> void
func restart_run() -> void
```

方法规格：

- `goto_menu()`
  输入：无。
  行为：切换到主菜单场景。
  返回：无。
- `goto_game()`
  输入：无。
  行为：切换到游戏主场景。
  返回：无。
- `goto_result(win)`
  输入：`win: bool`。
  行为：切换到结算场景并携带胜负结果。
  返回：无。
- `restart_run()`
  输入：无。
  行为：重新开始一局。
  返回：无。

### 3.2 地图模块

#### `MapManager`

作用：

- 地图真相数据中心

```gdscript
func generate_new_map(seed: int) -> void
func reset_map() -> void
func is_inside(cell: Vector2i) -> bool
func get_cell_data(cell: Vector2i) -> CellData
func is_discovered(cell: Vector2i) -> bool
func reveal_area(center: Vector2i, radius: int) -> Array[Vector2i]
func is_walkable(cell: Vector2i) -> bool
func is_buildable(cell: Vector2i) -> bool
func has_building(cell: Vector2i) -> bool
func set_building_occupy(cell: Vector2i, occupied: bool, building_runtime_id: int = -1) -> void
func world_to_cell(world_pos: Vector2) -> Vector2i
func cell_to_world(cell: Vector2i) -> Vector2
func get_spawn_cells() -> Array[Vector2i]
func get_core_cell() -> Vector2i
func get_random_discovered_empty_cell() -> Vector2i
func refresh_all_layers() -> void
```

方法规格：

- `generate_new_map(seed)`
  输入：`seed: int`。
  行为：根据种子生成新地图并初始化格子数据。
  返回：无。
- `reset_map()`
  输入：无。
  行为：清空当前地图运行时状态。
  返回：无。
- `is_inside(cell)`
  输入：`cell: Vector2i`。
  行为：判断格子是否在地图边界内。
  返回：`bool`。
- `get_cell_data(cell)`
  输入：`cell: Vector2i`。
  行为：读取指定格子的完整数据对象。
  返回：`CellData`。
- `is_discovered(cell)`
  输入：`cell: Vector2i`。
  行为：判断格子是否已探索。
  返回：`bool`。
- `reveal_area(center, radius)`
  输入：中心格与揭示半径。
  行为：揭开指定范围内迷雾。
  返回：被揭开的格子列表。
- `is_walkable(cell)`
  输入：`cell: Vector2i`。
  行为：判断格子当前是否可通行。
  返回：`bool`。
- `is_buildable(cell)`
  输入：`cell: Vector2i`。
  行为：判断格子当前是否允许建造。
  返回：`bool`。
- `has_building(cell)`
  输入：`cell: Vector2i`。
  行为：判断格子是否有建筑占用。
  返回：`bool`。
- `set_building_occupy(cell, occupied, building_runtime_id)`
  输入：格子、占用状态、建筑运行时 ID。
  行为：写入建筑占用状态。
  返回：无。
- `world_to_cell(world_pos)`
  输入：`world_pos: Vector2`。
  行为：世界坐标转格子坐标。
  返回：`Vector2i`。
- `cell_to_world(cell)`
  输入：`cell: Vector2i`。
  行为：格子坐标转世界坐标。
  返回：`Vector2`。
- `get_spawn_cells()`
  输入：无。
  行为：读取全部刷怪点格子。
  返回：`Array[Vector2i]`。
- `get_core_cell()`
  输入：无。
  行为：读取核心所在格子。
  返回：`Vector2i`。
- `get_random_discovered_empty_cell()`
  输入：无。
  行为：从已探索且未占用格中随机取一个。
  返回：`Vector2i`。
- `refresh_all_layers()`
  输入：无。
  行为：刷新地图显示层。
  返回：无。

#### `PathService`

作用：

- 路径计算服务

```gdscript
func rebuild_from_map() -> void
func get_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]
func has_path(start_cell: Vector2i, end_cell: Vector2i) -> bool
func set_cell_blocked(cell: Vector2i, blocked: bool) -> void
```

方法规格：

- `rebuild_from_map()`
  输入：无。
  行为：根据当前地图阻挡信息重建路径网格。
  返回：无。
- `get_path(start_cell, end_cell)`
  输入：起点格与终点格。
  行为：计算路径。
  返回：`Array[Vector2i]`。
- `has_path(start_cell, end_cell)`
  输入：起点格与终点格。
  行为：判断两点间是否存在路径。
  返回：`bool`。
- `set_cell_blocked(cell, blocked)`
  输入：格子与阻挡状态。
  行为：手动设置某格是否阻挡寻路。
  返回：无。

### 3.3 建筑模块

#### `BuildValidator`

作用：

- 建造合法性校验

```gdscript
func can_place_building(cell: Vector2i, building_id: StringName) -> Dictionary
func can_repair_building(building_runtime_id: int) -> Dictionary
```

方法规格：

- `can_place_building(cell, building_id)`
  输入：格子与建筑 ID。
  行为：校验是否允许放置指定建筑。
  成功结果：返回 `ActionResult(ok = true)`。
  失败结果：返回 `ActionResult(ok = false)`，包含失败原因。
- `can_repair_building(building_runtime_id)`
  输入：建筑运行时 ID。
  行为：校验是否允许修复指定建筑。
  成功结果：返回 `ActionResult(ok = true)`。
  失败结果：返回 `ActionResult(ok = false)`，包含失败原因。

#### `BuildingManager`

作用：

- 场上建筑主控

```gdscript
func try_place_building(cell: Vector2i, building_id: StringName) -> Dictionary
func try_repair_building(building_runtime_id: int) -> Dictionary
func damage_building(building_runtime_id: int, value: int, damage_type: int) -> void
func remove_building(building_runtime_id: int) -> void
func collect_day_income() -> void
func refresh_daytime_repair() -> void
func get_building_by_cell(cell: Vector2i) -> Node
func get_building_by_runtime_id(building_runtime_id: int) -> Node
```

方法规格：

- `try_place_building(cell, building_id)`
  输入：格子与建筑 ID。
  行为：尝试放置建筑，并同步地图占用与寻路状态。
  成功结果：返回 `ActionResult(ok = true)`，建筑实例已创建。
  失败结果：返回 `ActionResult(ok = false)`，不创建实例。
- `try_repair_building(building_runtime_id)`
  输入：建筑运行时 ID。
  行为：尝试修复建筑。
  成功结果：返回 `ActionResult(ok = true)`，建筑状态已更新。
  失败结果：返回 `ActionResult(ok = false)`，建筑状态不变。
- `damage_building(building_runtime_id, value, damage_type)`
  输入：建筑运行时 ID、伤害值、伤害类型。
  行为：对指定建筑造成伤害。
  返回：无。
- `remove_building(building_runtime_id)`
  输入：建筑运行时 ID。
  行为：移除建筑实例并清理占用与索引。
  返回：无。
- `collect_day_income()`
  输入：无。
  行为：结算白天建筑收益。
  返回：无。
- `refresh_daytime_repair()`
  输入：无。
  行为：刷新白天可修复状态。
  返回：无。
- `get_building_by_cell(cell)`
  输入：`cell: Vector2i`。
  行为：按格子查找建筑实例。
  返回：`Node` 或空值。
- `get_building_by_runtime_id(building_runtime_id)`
  输入：建筑运行时 ID。
  行为：按运行时 ID 查找建筑实例。
  返回：`Node` 或空值。

#### `BuildingActor`

作用：

- 单个建筑实例行为

```gdscript
func setup_from_cfg(building_id: StringName, cfg: Dictionary, cell: Vector2i) -> void
func receive_damage(value: int, damage_type: int) -> void
func repair_full() -> void
func get_runtime_id() -> int
func get_current_cell() -> Vector2i
func get_effect_radius() -> int
```

方法规格：

- `setup_from_cfg(building_id, cfg, cell)`
  输入：建筑 ID、配置、所在格。
  行为：用配置初始化建筑实例。
  返回：无。
- `receive_damage(value, damage_type)`
  输入：伤害值与伤害类型。
  行为：让建筑受到伤害。
  返回：无。
- `repair_full()`
  输入：无。
  行为：将建筑恢复到满状态。
  返回：无。
- `get_runtime_id()`
  输入：无。
  行为：读取建筑运行时唯一 ID。
  返回：`int`。
- `get_current_cell()`
  输入：无。
  行为：读取建筑所在格。
  返回：`Vector2i`。
- `get_effect_radius()`
  输入：无。
  行为：读取建筑效果半径。
  返回：`int`。

### 3.4 单位与商店模块

#### `ShopManager`

作用：

- 商店库存与购买主控

```gdscript
func start_new_day_shop(day: int) -> void
func refresh_shop() -> Dictionary
func get_current_stock() -> Array[StringName]
func try_buy_unit(unit_id: StringName) -> Dictionary
```

方法规格：

- `start_new_day_shop(day)`
  输入：`day: int`。
  行为：初始化指定天数的商店库存。
  返回：无。
- `refresh_shop()`
  输入：无。
  行为：刷新当前商店库存。
  成功结果：返回 `ActionResult(ok = true)`，库存已更新。
  失败结果：返回 `ActionResult(ok = false)`，库存保持不变。
- `get_current_stock()`
  输入：无。
  行为：读取当前库存单位 ID 列表。
  返回：`Array[StringName]`。
- `try_buy_unit(unit_id)`
  输入：`unit_id: StringName`。
  行为：尝试购买指定单位。
  成功结果：返回 `ActionResult(ok = true)`，单位加入已拥有列表。
  失败结果：返回 `ActionResult(ok = false)`，购买不生效。

#### `UnitManager`

作用：

- 场上单位主控

```gdscript
func try_deploy_unit(unit_id: StringName, cell: Vector2i, facing: Vector2i) -> Dictionary
func try_retreat_unit(unit_runtime_id: int) -> Dictionary
func try_cast_skill(unit_runtime_id: int) -> Dictionary
func get_unit_by_runtime_id(unit_runtime_id: int) -> Node
func get_all_deployed_units() -> Array
func is_unit_redeploying(unit_id: StringName) -> bool
func tick_redeploy(delta: float) -> void
func remove_unit(unit_runtime_id: int, reason: int) -> void
```

方法规格：

- `try_deploy_unit(unit_id, cell, facing)`
  输入：单位 ID、部署格、朝向。
  行为：尝试部署单位并创建实例。
  成功结果：返回 `ActionResult(ok = true)`，单位已部署。
  失败结果：返回 `ActionResult(ok = false)`，不创建实例。
- `try_retreat_unit(unit_runtime_id)`
  输入：单位运行时 ID。
  行为：尝试让单位撤退并进入再部署冷却。
  成功结果：返回 `ActionResult(ok = true)`，单位已离场。
  失败结果：返回 `ActionResult(ok = false)`，单位保持在场。
- `try_cast_skill(unit_runtime_id)`
  输入：单位运行时 ID。
  行为：尝试释放单位技能。
  成功结果：返回 `ActionResult(ok = true)`，技能已执行。
  失败结果：返回 `ActionResult(ok = false)`，技能不执行。
- `get_unit_by_runtime_id(unit_runtime_id)`
  输入：单位运行时 ID。
  行为：按运行时 ID 查找单位实例。
  返回：`Node` 或空值。
- `get_all_deployed_units()`
  输入：无。
  行为：读取场上全部已部署单位。
  返回：`Array`。
- `is_unit_redeploying(unit_id)`
  输入：单位 ID。
  行为：检查单位是否处于再部署冷却。
  返回：`bool`。
- `tick_redeploy(delta)`
  输入：`delta: float`。
  行为：推进再部署冷却计时。
  返回：无。
- `remove_unit(unit_runtime_id, reason)`
  输入：单位运行时 ID 与离场原因。
  行为：移除指定单位。
  返回：无。

#### `CombatMath`

作用：

- 战斗计算工具

```gdscript
static func calc_physical_damage(atk: int, defense: int) -> int
static func calc_magic_damage(atk: int, resistance: int) -> int
static func calc_heal(power: int) -> int
```

方法规格：

- `calc_physical_damage(atk, defense)`
  输入：攻击力与防御。
  行为：计算物理伤害。
  返回：`int`。
- `calc_magic_damage(atk, resistance)`
  输入：攻击力与抗性。
  行为：计算法术伤害。
  返回：`int`。
- `calc_heal(power)`
  输入：治疗强度。
  行为：计算治疗量。
  返回：`int`。

#### `UnitActor`

作用：

- 单个单位实例行为

```gdscript
func setup_from_cfg(unit_id: StringName, cfg: Dictionary, spawn_cell: Vector2i, facing: Vector2i) -> void
func receive_damage(value: int, damage_type: int) -> void
func receive_heal(value: int) -> void
func gain_sp(value: int) -> void
func can_cast_skill() -> bool
func cast_skill() -> void
func get_runtime_id() -> int
func get_current_cell() -> Vector2i
func get_block_count() -> int
func get_attack_targets() -> Array
```

方法规格：

- `setup_from_cfg(unit_id, cfg, spawn_cell, facing)`
  输入：单位 ID、配置、出生格、朝向。
  行为：用配置初始化单位实例。
  返回：无。
- `receive_damage(value, damage_type)`
  输入：伤害值与伤害类型。
  行为：让单位受到伤害。
  返回：无。
- `receive_heal(value)`
  输入：治疗值。
  行为：让单位恢复生命。
  返回：无。
- `gain_sp(value)`
  输入：SP 增量。
  行为：增加单位 SP。
  返回：无。
- `can_cast_skill()`
  输入：无。
  行为：判断单位是否可释放技能。
  返回：`bool`。
- `cast_skill()`
  输入：无。
  行为：执行单位技能释放。
  返回：无。
- `get_runtime_id()`
  输入：无。
  行为：读取单位运行时唯一 ID。
  返回：`int`。
- `get_current_cell()`
  输入：无。
  行为：读取单位所在格。
  返回：`Vector2i`。
- `get_block_count()`
  输入：无。
  行为：读取单位当前阻挡数。
  返回：`int`。
- `get_attack_targets()`
  输入：无。
  行为：获取当前可攻击目标列表。
  返回：`Array`。

### 3.5 敌人与波次模块

#### `WaveManager`

作用：

- 波次执行器

```gdscript
func start_wave_for_day(day: int) -> void
func stop_wave() -> void
func is_wave_finished() -> bool
func has_pending_spawn() -> bool
```

方法规格：

- `start_wave_for_day(day)`
  输入：`day: int`。
  行为：启动指定天数的波次执行。
  返回：无。
- `stop_wave()`
  输入：无。
  行为：停止当前波次。
  返回：无。
- `is_wave_finished()`
  输入：无。
  行为：判断当前波次是否已结束。
  返回：`bool`。
- `has_pending_spawn()`
  输入：无。
  行为：判断是否仍有待生成敌人。
  返回：`bool`。

#### `EnemyManager`

作用：

- 场上敌人主控

```gdscript
func spawn_enemy(enemy_id: StringName, spawn_cell: Vector2i) -> int
func remove_enemy(enemy_runtime_id: int) -> void
func get_enemy_by_runtime_id(enemy_runtime_id: int) -> Node
func get_alive_enemy_count() -> int
func notify_enemy_reached_core(enemy_runtime_id: int) -> void
```

方法规格：

- `spawn_enemy(enemy_id, spawn_cell)`
  输入：敌人 ID 与刷怪格。
  行为：创建敌人实例并加入场景。
  返回：敌人运行时 ID。
- `remove_enemy(enemy_runtime_id)`
  输入：敌人运行时 ID。
  行为：移除指定敌人实例。
  返回：无。
- `get_enemy_by_runtime_id(enemy_runtime_id)`
  输入：敌人运行时 ID。
  行为：按运行时 ID 查找敌人实例。
  返回：`Node` 或空值。
- `get_alive_enemy_count()`
  输入：无。
  行为：读取当前存活敌人数。
  返回：`int`。
- `notify_enemy_reached_core(enemy_runtime_id)`
  输入：敌人运行时 ID。
  行为：处理敌人抵达核心后的扣血与移除。
  返回：无。

#### `EnemyActor`

作用：

- 单个敌人实例行为

```gdscript
func setup_from_cfg(enemy_id: StringName, cfg: Dictionary, spawn_cell: Vector2i) -> void
func receive_damage(value: int, damage_type: int) -> void
func get_runtime_id() -> int
func get_current_cell() -> Vector2i
func recalc_path() -> void
func set_blocked(blocker_runtime_id: int) -> void
func clear_blocked() -> void
```

方法规格：

- `setup_from_cfg(enemy_id, cfg, spawn_cell)`
  输入：敌人 ID、配置、出生格。
  行为：用配置初始化敌人实例。
  返回：无。
- `receive_damage(value, damage_type)`
  输入：伤害值与伤害类型。
  行为：让敌人受到伤害。
  返回：无。
- `get_runtime_id()`
  输入：无。
  行为：读取敌人运行时唯一 ID。
  返回：`int`。
- `get_current_cell()`
  输入：无。
  行为：读取敌人所在格。
  返回：`Vector2i`。
- `recalc_path()`
  输入：无。
  行为：重新计算当前寻路路径。
  返回：无。
- `set_blocked(blocker_runtime_id)`
  输入：阻挡者运行时 ID。
  行为：设置敌人被阻挡状态。
  返回：无。
- `clear_blocked()`
  输入：无。
  行为：清除阻挡状态。
  返回：无。

#### `BossController`

作用：

- Boss 扩展控制

```gdscript
func on_hp_threshold_crossed(percent: float) -> void
func enter_phase_two() -> void
func cast_boss_skill(skill_id: StringName) -> void
```

方法规格：

- `on_hp_threshold_crossed(percent)`
  输入：血量百分比。
  行为：处理 Boss 血量越过阈值时的状态切换。
  返回：无。
- `enter_phase_two()`
  输入：无。
  行为：让 Boss 进入第二阶段。
  返回：无。
- `cast_boss_skill(skill_id)`
  输入：技能 ID。
  行为：释放指定 Boss 技能。
  返回：无。

### 3.6 UI 模块

#### `HUD`

作用：

- HUD 刷新接口

```gdscript
func refresh_phase(phase: int) -> void
func refresh_day(day: int) -> void
func refresh_resources(wood: int, stone: int, mana: int) -> void
func refresh_prestige(value: int) -> void
func refresh_action_points(value: int) -> void
func refresh_core_hp(current: int, max_value: int) -> void
func refresh_deploy_count(current: int, max_value: int) -> void
func show_message(text: String) -> void
```

方法规格：

- `refresh_phase(phase)`
  输入：阶段枚举值。
  行为：刷新阶段显示。
  返回：无。
- `refresh_day(day)`
  输入：天数。
  行为：刷新天数显示。
  返回：无。
- `refresh_resources(wood, stone, mana)`
  输入：三类材料数值。
  行为：刷新材料显示。
  返回：无。
- `refresh_prestige(value)`
  输入：声望值。
  行为：刷新声望显示。
  返回：无。
- `refresh_action_points(value)`
  输入：行动力数值。
  行为：刷新行动力显示。
  返回：无。
- `refresh_core_hp(current, max_value)`
  输入：当前生命与最大生命。
  行为：刷新核心血量显示。
  返回：无。
- `refresh_deploy_count(current, max_value)`
  输入：当前部署数与部署上限。
  行为：刷新部署数量显示。
  返回：无。
- `show_message(text)`
  输入：提示文本。
  行为：显示提示消息。
  返回：无。

#### `ActionPanel`

作用：

- 白天操作模式接口

```gdscript
func set_mode_idle() -> void
func set_mode_explore() -> void
func set_mode_build(building_id: StringName) -> void
func clear_mode() -> void
func get_current_mode() -> StringName
```

方法规格：

- `set_mode_idle()`
  输入：无。
  行为：切换到待机模式。
  返回：无。
- `set_mode_explore()`
  输入：无。
  行为：切换到探索模式。
  返回：无。
- `set_mode_build(building_id)`
  输入：建筑 ID。
  行为：切换到建造模式并记录当前建筑。
  返回：无。
- `clear_mode()`
  输入：无。
  行为：清空当前模式。
  返回：无。
- `get_current_mode()`
  输入：无。
  行为：读取当前操作模式。
  返回：`StringName`。

#### `ShopPanel`

作用：

- 商店显示接口

```gdscript
func refresh_stock(stock: Array[StringName]) -> void
func set_visible_for_phase(phase: int) -> void
```

方法规格：

- `refresh_stock(stock)`
  输入：库存单位 ID 列表。
  行为：刷新商店库存显示。
  返回：无。
- `set_visible_for_phase(phase)`
  输入：阶段枚举值。
  行为：根据当前阶段切换面板显隐。
  返回：无。

#### `DeployPanel`

作用：

- 部署显示接口

```gdscript
func refresh_owned_units(unit_ids: Array[StringName]) -> void
func refresh_redeploy_state(unit_id: StringName, ready: bool, remain_sec: float) -> void
func set_visible_for_phase(phase: int) -> void
```

方法规格：

- `refresh_owned_units(unit_ids)`
  输入：单位 ID 列表。
  行为：刷新已拥有单位列表显示。
  返回：无。
- `refresh_redeploy_state(unit_id, ready, remain_sec)`
  输入：单位 ID、可部署状态、剩余冷却时间。
  行为：刷新指定单位再部署状态显示。
  返回：无。
- `set_visible_for_phase(phase)`
  输入：阶段枚举值。
  行为：根据当前阶段切换面板显隐。
  返回：无。

#### `EventPanel`

作用：

- 随机事件显示接口

```gdscript
func show_event(event_cfg: Dictionary) -> void
func hide_event() -> void
```

方法规格：

- `show_event(event_cfg)`
  输入：事件配置。
  行为：显示事件内容。
  返回：无。
- `hide_event()`
  输入：无。
  行为：隐藏事件面板。
  返回：无。

#### `BlessingPanel`

作用：

- 祝福显示接口

```gdscript
func show_choices(choice_ids: Array[StringName]) -> void
func hide_panel() -> void
```

方法规格：

- `show_choices(choice_ids)`
  输入：祝福 ID 列表。
  行为：显示祝福候选内容。
  返回：无。
- `hide_panel()`
  输入：无。
  行为：隐藏祝福面板。
  返回：无。

---

## 4. `EventBus` 信号接口

### 4.1 生命周期与阶段信号

| 信号名 | 参数 | 发出方 | 监听方 | 说明 |
|---|---|---|---|---|
| `phase_changed` | `old_phase: int, new_phase: int` | `GameController` | UI、各 Manager | 阶段已切换 |
| `day_started` | `day: int` | `GameController` | HUD、DayManager、ShopManager、BuildingManager | 一天开始 |
| `night_started` | `day: int` | `GameController` | NightManager、WaveManager、UI | 夜晚开始 |
| `night_cleared` | `day: int` | `WaveManager` / `NightManager` | `GameController` | 夜战结束且守住 |
| `run_ended` | `win: bool` | `GameController` | `SceneRouter`、`ResultPanel` | 一局结束 |

### 4.2 状态变化信号

| 信号名 | 参数 | 发出方 | 监听方 | 说明 |
|---|---|---|---|---|
| `action_points_changed` | `value: int` | `RunState` | HUD | 行动力变化 |
| `prestige_changed` | `value: int` | `RunState` | HUD、ShopPanel | 声望变化 |
| `materials_changed` | `wood: int, stone: int, mana: int` | `RunState` | HUD、BuildPanel | 材料变化 |
| `core_hp_changed` | `current: int, max_value: int` | `RunState` | HUD、ResultPanel | 核心血量变化 |
| `deploy_limit_changed` | `current: int, max_value: int` | `RunState` | HUD、DeployPanel | 部署数量变化 |
| `shop_stock_changed` | `stock: Array[StringName]` | `ShopManager` | ShopPanel | 商店库存变化 |

### 4.3 玩家请求信号

| 信号名 | 参数 | 发出方 | 监听方 | 说明 |
|---|---|---|---|---|
| `request_explore` | `cell: Vector2i` | UI | `DayManager` | 请求探索 |
| `request_build` | `cell: Vector2i, building_id: StringName` | UI | `BuildingManager` / `DayManager` | 请求建造 |
| `request_interact_event` | `cell: Vector2i` | UI | `DayManager` / `RandomEventManager` | 请求处理事件 |
| `request_start_night` | 无 | UI | `GameController` / `DayManager` | 请求结束白天 |
| `request_buy_unit` | `unit_id: StringName` | UI | `ShopManager` | 请求购买单位 |
| `request_refresh_shop` | 无 | UI | `ShopManager` | 请求刷新商店 |
| `request_deploy` | `unit_id: StringName, cell: Vector2i, facing: Vector2i` | UI | `UnitManager` | 请求部署 |
| `request_retreat` | `unit_runtime_id: int` | UI | `UnitManager` | 请求撤退 |
| `request_cast_skill` | `unit_runtime_id: int` | UI | `UnitManager` | 请求释放技能 |
| `blessing_chosen` | `buff_id: StringName` | UI | `GameController`、`BuffManager` | 选择某个祝福 |

### 4.4 世界事件信号

| 信号名 | 参数 | 发出方 | 监听方 | 说明 |
|---|---|---|---|---|
| `fog_revealed` | `cells: Array[Vector2i]` | `MapManager` | UI、调试工具 | 迷雾被揭开 |
| `building_placed` | `building_runtime_id: int, building_id: StringName, cell: Vector2i` | `BuildingManager` | `MapManager`、`PathService` | 建筑已放置 |
| `building_destroyed` | `building_runtime_id: int, building_id: StringName, cell: Vector2i` | `BuildingManager` | `MapManager`、`PathService` | 建筑已摧毁 |
| `path_grid_changed` | 无 | `BuildingManager` / `MapManager` | `PathService`、`EnemyManager` | 寻路网格需重建 |
| `unit_deployed` | `unit_runtime_id: int, unit_id: StringName, cell: Vector2i` | `UnitManager` | HUD、DeployPanel | 单位已部署 |
| `unit_removed` | `unit_runtime_id: int, reason: int` | `UnitManager` | HUD、DeployPanel | 单位离场 |
| `enemy_spawned` | `enemy_runtime_id: int, enemy_id: StringName, cell: Vector2i` | `EnemyManager` | HUD、调试工具 | 敌人出生 |
| `enemy_died` | `enemy_runtime_id: int, enemy_id: StringName` | `EnemyManager` | `WaveManager`、`BuffManager` | 敌人死亡 |
| `random_event_triggered` | `event_id: StringName, cell: Vector2i` | `RandomEventManager` | `EventPanel` | 随机事件触发 |
| `blessing_choices_ready` | `choice_ids: Array[StringName]` | `BuffManager` | `BlessingPanel` | 祝福选项已生成 |
| `core_destroyed` | 无 | `RunState` | `GameController`、`ResultPanel` | 核心归零 |

---

## 5. UI 请求出口

UI 发请求时统一使用 `EventBus.emit()`，不直接操作业务模块内部状态。

- 探索：`EventBus.request_explore.emit(cell)`
- 建造：`EventBus.request_build.emit(cell, building_id)`
- 处理事件：`EventBus.request_interact_event.emit(cell)`
- 结束白天：`EventBus.request_start_night.emit()`
- 购买单位：`EventBus.request_buy_unit.emit(unit_id)`
- 刷新商店：`EventBus.request_refresh_shop.emit()`
- 部署单位：`EventBus.request_deploy.emit(unit_id, cell, facing)`
- 撤退单位：`EventBus.request_retreat.emit(unit_runtime_id)`
- 释放技能：`EventBus.request_cast_skill.emit(unit_runtime_id)`
- 选择祝福：`EventBus.blessing_chosen.emit(buff_id)`

---

## 6. 模块监听关系

### 6.1 核心架构模块

监听：

- `request_start_night`
- `night_cleared`
- `core_destroyed`
- `blessing_chosen`

对外广播：

- `phase_changed`
- `day_started`
- `night_started`
- `blessing_choices_ready`
- `run_ended`

### 6.2 地图模块

监听：

- `building_placed`
- `building_destroyed`
- `path_grid_changed`
- `request_explore`

对外广播：

- `fog_revealed`
- `path_grid_changed`

### 6.3 建筑模块

监听：

- `request_build`
- `day_started`
- `night_started`

对外广播：

- `building_placed`
- `building_destroyed`
- `path_grid_changed`

### 6.4 单位与商店模块

监听：

- `request_buy_unit`
- `request_refresh_shop`
- `request_deploy`
- `request_retreat`
- `request_cast_skill`
- `phase_changed`
- `day_started`
- `night_started`

对外广播：

- `shop_stock_changed`
- `unit_deployed`
- `unit_removed`

### 6.5 敌人与波次模块

监听：

- `night_started`
- `path_grid_changed`
- `enemy_died`
- `core_destroyed`

对外广播：

- `enemy_spawned`
- `enemy_died`
- `night_cleared`

### 6.6 UI 模块

监听：

- `phase_changed`
- `day_started`
- `action_points_changed`
- `prestige_changed`
- `materials_changed`
- `core_hp_changed`
- `shop_stock_changed`
- `blessing_choices_ready`
- `random_event_triggered`
- `deploy_limit_changed`

对外广播：

- 全部 `request_xxx`
- `blessing_chosen`
