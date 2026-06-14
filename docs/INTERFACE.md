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
func start_new_run(seed: int = -1, run_mode: StringName = &"standard") -> void
func enter_day(day: int) -> void
func enter_night() -> void
func enter_blessing() -> void
func end_run(win: bool) -> void
func get_current_phase() -> int
```

方法规格：

- `start_new_run(seed, run_mode = &"standard")`
  输入：`seed: int`，`-1` 表示内部生成随机种子；可选运行模式 `run_mode`。
  行为：确认 `DataRepo` 已加载静态配置后，按运行模式重置本局运行时状态，生成地图，并启动新一局流程。配置加载属于 `DataRepo` 的 Autoload 生命周期，不属于每局开局流程。
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
func try_collect_resource(cell: Vector2i) -> Dictionary
func is_resource_collected_today(cell: Vector2i) -> bool
func try_trigger_event(cell: Vector2i, choice_id: StringName = StringName()) -> Dictionary
func try_seal_spawn_gate(cell: Vector2i) -> Dictionary
func request_start_night() -> Dictionary
```

方法规格：

- `start_day(day)`
  输入：`day: int`。
  行为：初始化指定天数的白天状态。
  返回：无。
- `try_explore(cell)`
  输入：`cell: Vector2i`。
  行为：校验指定格子是否允许探索；目标必须未探索，且上下左右至少邻接一个已探索格；成功时扣除 2 点行动力并揭开 3×3 迷雾。若揭开的格子存在随机事件覆盖层，后续由地图交互弹窗触发，探索本身不结算事件效果。
  成功结果：返回 `ActionResult(ok = true)`，并推进探索后续逻辑。
  失败结果：返回 `ActionResult(ok = false)`，不修改状态。
- `try_collect_resource(cell)`
  输入：`cell: Vector2i`。
  行为：校验指定格子是否为白天、已探索资源点；每点每天最多手动采集一次；成功时扣除 1 点行动力，木材/石材/魔力矿资源点均获得 2 个对应资源。资源点已有正常建筑时仍允许手动采集，建筑每日产出独立结算。
  成功结果：返回 `ActionResult(ok = true)`，材料和行动力已更新。
  失败结果：返回 `ActionResult(ok = false)`，材料和行动力不变。
- `is_resource_collected_today(cell)`
  输入：`cell: Vector2i`。
  行为：查询该资源点当天是否已经手动采集。
  返回：布尔值。
- `try_trigger_event(cell, choice_id = StringName())`
  输入：`cell: Vector2i`，可选事件选项 ID。
  行为：校验指定格子位于已探索区域且存在事件，消耗 2 点行动力后委托 `RandomEventManager.apply_event_for_cell(cell, choice_id)` 完成事件结算。
  成功结果：返回 `ActionResult(ok = true)`，并完成事件结算；事件覆盖层移除该事件点，地图格属性不修改。
  失败结果：返回 `ActionResult(ok = false)`，不修改状态；若事件结算失败会退还已扣除行动力。
- `try_seal_spawn_gate(cell)`
  输入：`cell: Vector2i`。
  行为：白天封堵指定格子上的活跃出怪口，使其当晚沉默、怪物改道；每天最多封堵一次，需消耗石材和行动力，且至少保留一个活跃出怪口。成功时通过 `RunState.add_night_gate_closed()` 改写当晚出怪口集合，由 `night_gate_overrides_changed` 广播。
  成功结果：返回 `ActionResult(ok = true)`，payload 含 `gate_key`、`ap_cost`、`stone_cost`，石材与行动力已扣除。
  失败结果：返回 `ActionResult(ok = false)`（非白天、非出怪口、今晚本就沉默、仅剩最后一个活跃口、已达每日封堵上限或材料/行动力不足），不修改状态。
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
func get_random_blessing_choices(count: int = 0) -> Array[StringName]
func get_random_blessing_choices_with_sources(count: int = 0) -> Array[Dictionary]
func apply_blessing(buff_id: StringName) -> Dictionary
func has_buff(buff_id: StringName) -> bool
func get_all_buffs() -> Array[StringName]
```

方法规格：

- `get_random_blessing_choices(count)`
  输入：`count: int = 0`，`0` 表示使用默认候选数量。
  行为：生成指定数量的祝福候选。
  返回：`Array[StringName]`。
- `get_random_blessing_choices_with_sources(count)`
  输入：`count: int = 0`，`0` 表示使用默认候选数量。
  行为：生成带来源信息的祝福候选，供 UI 标注每个候选的出处。
  返回：`Array[Dictionary]`。
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
func get_event_id_at_cell(cell: Vector2i) -> StringName
func has_event_at_cell(cell: Vector2i) -> bool
func get_event_cells() -> Array[Vector2i]
func get_event_cfg_at_cell(cell: Vector2i) -> Dictionary
func apply_event(event_id: StringName) -> Dictionary
func apply_event_for_cell(cell: Vector2i, choice_id: StringName = StringName()) -> Dictionary
func mark_event_triggered(cell: Vector2i) -> void
func get_event_cfg(event_id: StringName) -> Dictionary
```

方法规格：

- `roll_event_for_cell(cell)`
  输入：`cell: Vector2i`。
  行为：兼容入口，读取指定地图格上的随机事件覆盖层 ID。正式事件点由每日刷新系统投放，不在探索时临时随机抽取。
  返回：事件 `id`；无事件时返回空值或约定空标识。
- `get_event_id_at_cell(cell)`
  输入：`cell: Vector2i`。
  行为：读取指定坐标上的事件覆盖层 ID。
  返回：事件 `id`；无事件时返回空 `StringName`。
- `has_event_at_cell(cell)`
  输入：`cell: Vector2i`。
  行为：检查指定坐标是否有事件覆盖层。
  返回：`bool`。
- `get_event_cells()`
  输入：无。
  行为：读取当前所有活跃事件点坐标。
  返回：`Array[Vector2i]`。
- `get_event_cfg_at_cell(cell)`
  输入：`cell: Vector2i`。
  行为：读取指定坐标上的事件配置；古代祭坛会动态补全该格子的灌注选项。
  返回：`Dictionary`。
- `apply_event(event_id)`
  输入：`event_id: StringName`。
  行为：结算指定事件。
  成功结果：返回 `ActionResult(ok = true)`，事件结算完成。
  失败结果：返回 `ActionResult(ok = false)`，不修改状态。
- `apply_event_for_cell(cell, choice_id = StringName())`
  输入：`cell: Vector2i`，可选事件选项 ID。
  行为：读取指定坐标上的事件覆盖层 ID，按选项跳转或动态祭坛选项结算事件，并从覆盖层移除该事件点。
  成功结果：返回 `ActionResult(ok = true)`，事件结算完成。
  失败结果：返回 `ActionResult(ok = false)`，不修改状态。
- `mark_event_triggered(cell)`
  输入：`cell: Vector2i`。
  行为：移除指定坐标上的事件覆盖层并刷新地图显示。
  返回：无。
- `get_event_cfg(event_id)`
  输入：`event_id: StringName`。
  行为：读取事件静态配置。
  返回：`Dictionary`。

#### `RunState`

作用：

- 当前局公共状态读写入口

```gdscript
func reset_for_new_run(seed: int, mode: StringName = RUN_MODE_STANDARD) -> void
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
func add_owned_operator(unit_id: StringName, display_name: String = "", star: int = 1) -> Dictionary
func add_owned_operator_with_key(operator_key: StringName, unit_id: StringName, display_name: String = "", star: int = 1) -> Dictionary
func get_owned_operator(operator_key: StringName) -> Dictionary
func get_owned_operators() -> Array[Dictionary]
func has_owned_operator(operator_key: StringName) -> bool
func sell_owned_operator(operator_key: StringName, refund_override: int = -1) -> Dictionary
func get_operator_star_up_cost(star: int) -> Dictionary
func upgrade_owned_operator_star(operator_key: StringName) -> Dictionary
func auto_merge_operators_for_unit(unit_id: StringName, before_merge: Callable = Callable()) -> Dictionary
func get_unit_covenants(unit_id: StringName) -> Array
func get_operator_covenants(operator_key: StringName) -> Array
func add_unit_covenant(unit_id: StringName, covenant: StringName) -> Dictionary
func add_operator_covenant(operator_key: StringName, covenant: StringName) -> Dictionary
func add_owned_unit(unit_id: StringName) -> void
func has_owned_unit(unit_id: StringName) -> bool
func set_deploy_limit(value: int) -> void
func change_deployed_count(delta: int) -> void
func clear_night_gate_overrides() -> void
func add_night_gate_closed(gate_key: String) -> void
func add_night_gate_extra_open(gate_key: String) -> void
```

方法规格：

- `reset_for_new_run(seed, mode = RUN_MODE_STANDARD)`
  输入：`seed: int`、可选运行模式 `mode`（`RUN_MODE_STANDARD` / `RUN_MODE_TUTORIAL`）。
  行为：按给定种子和运行模式重置整局公共状态。
  返回：无。
- `set_phase(phase)`
  输入：`phase: int`。
  行为：写入当前阶段并广播阶段变化。
  返回：无。
- `set_day(day)`
  输入：`day: int`。
  行为：写入当前天数，并根据完整经过天数调整部署上限；第 1-2 天无额外加成，第 3-4 天部署上限 +1，第 5-6 天部署上限 +2。该加成在现有部署上限上按差值调整，不覆盖遗物提供的部署上限加成。
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
- `add_owned_operator(unit_id, display_name = "", star = 1)`
  输入：单位 ID、可选显示名与可选星级。
  行为：生成唯一 `operator_key`，新增一个干员实例槽位；同一 `unit_id` 可以新增多个槽位。
  返回：槽位字典，至少包含 `key`、`unit_id`、`name`、`star`。
- `add_owned_operator_with_key(operator_key, unit_id, display_name = "", star = 1)`
  输入：外部指定的槽位 key、单位 ID、可选显示名与可选星级。
  行为：用于调试 preset 或存档恢复，按指定 key 写入干员槽位；如果 key 已存在则拒绝或覆盖失败。
  返回：槽位字典，至少包含 `key`、`unit_id`、`name`、`star`。
- `get_owned_operator(operator_key)`
  输入：干员槽位 key。
  行为：读取指定槽位。
  返回：槽位字典；不存在时返回空字典。
- `get_owned_operators()`
  输入：无。
  行为：读取当前已拥有的全部干员实例槽位。
  返回：`Array[Dictionary]`。
- `has_owned_operator(operator_key)`
  输入：干员槽位 key。
  行为：检查是否拥有该槽位。
  返回：`bool`。
- `sell_owned_operator(operator_key, refund_override = -1)`
  输入：干员槽位 key 与可选返还覆盖值。
  行为：仅白天可调用；移除该干员槽位并返还声望。`refund_override < 0` 时使用默认 1 声望；调用方可按盟约等规则传入覆盖返还值。
  成功结果：返回 `ActionResult(ok = true)`，payload 中包含 `operator_key` 和 `refund_prestige`。
  失败结果：返回 `ActionResult(ok = false)`，槽位和声望不变。
- `get_operator_star_up_cost(star)`
  输入：当前星级。
  行为：读取从该星级升一星所需的材料/声望成本。
  返回：成本字典；无对应档位时返回空字典。
- `upgrade_owned_operator_star(operator_key)`
  输入：干员槽位 key。
  行为：仅白天可调用；对指定干员定向升星 +1，扣除魔力矿和声望成本。部署/冷却门控由 `UnitManager` 负责。
  成功结果：返回 `ActionResult(ok = true)`，槽位星级已提升、成本已扣除。
  失败结果：返回 `ActionResult(ok = false)`（非白天、未拥有该干员、已达最高星或材料/声望不足），不修改状态。
- `auto_merge_operators_for_unit(unit_id, before_merge = Callable())`
  输入：单位 ID 与可选合成前回调。
  行为：按同名同星三合一规则自动合成，保留最早槽位并提升星级；回调用于让 `UnitManager` 在合成前撤回参与槽位。
  返回：`ActionResult(ok = true)`，payload 中包含 `merge_events`。
- `get_unit_covenants(unit_id)`
  输入：`unit_id: StringName`。
  行为：读取单位类型的有效盟约，等于静态单位配置盟约加本局单位类型额外盟约，去重。
  返回：盟约 ID 数组。
- `get_operator_covenants(operator_key)`
  输入：干员槽位 key。
  行为：读取干员实例的有效盟约，等于其单位类型有效盟约加旧实例额外盟约，去重。
  返回：盟约 ID 数组。
- `add_unit_covenant(unit_id, covenant)`
  输入：单位 ID 与盟约 ID。
  行为：为该单位类型在本局追加永久盟约；现有与后续购买的同 `unit_id` 干员实例都会继承，自动三合一不会移除该追加盟约。
  成功结果：返回 `ActionResult(ok = true)`，payload 中包含 `unit_id` 和 `covenant`。
  失败结果：返回 `ActionResult(ok = false)`，单位不存在、盟约无效或已经拥有该盟约时不修改状态。
- `add_operator_covenant(operator_key, covenant)`
  输入：干员槽位 key 与盟约 ID。
  行为：兼容旧调用；先解析槽位对应的 `unit_id`，再调用 `add_unit_covenant`。
  成功结果：返回 `ActionResult(ok = true)`，payload 中包含 `unit_id`、`operator_key` 和 `covenant`。
  失败结果：返回 `ActionResult(ok = false)`。
- `add_owned_unit(unit_id)`
  输入：`unit_id: StringName`。
  行为：兼容旧调用，内部应转为新增一个干员实例槽位。
  返回：无。
- `has_owned_unit(unit_id)`
  输入：`unit_id: StringName`。
  行为：兼容旧调用，检查是否存在任一绑定该 `unit_id` 的干员槽位。
  返回：`bool`。
- `set_deploy_limit(value)`
  输入：`value: int`。
  行为：设置部署上限；天数成长和遗物都会基于当前部署上限继续调整。
  返回：无。
- `change_deployed_count(delta)`
  输入：`delta: int`。
  行为：增减当前已部署数量。
  返回：无。
- `clear_night_gate_overrides()`
  输入：无。
  行为：清空本局出怪口的动态封堵和额外开启覆盖，恢复默认出怪口集合。
  返回：无。
- `add_night_gate_closed(gate_key)`
  输入：出怪口 key。
  行为：将指定出怪口加入当晚封堵集合，使其沉默；由白天封口和事件等动态出怪口逻辑驱动，并广播 `night_gate_overrides_changed`。
  返回：无。
- `add_night_gate_extra_open(gate_key)`
  输入：出怪口 key。
  行为：将指定出怪口加入额外开启集合，使本不活跃的出怪口当晚激活；并广播 `night_gate_overrides_changed`。
  返回：无。

#### `DataRepo`

作用：

- 查询配置表
- 查询场景模板
- 广播静态配置加载完成状态

```gdscript
signal data_loaded
signal data_reload_failed(message: String)

func load_all() -> void
func is_loaded() -> bool
func get_unit_cfg(unit_id: StringName) -> Dictionary
func get_enemy_cfg(enemy_id: StringName) -> Dictionary
func get_building_cfg(building_id: StringName) -> Dictionary
func get_buff_cfg(buff_id: StringName) -> Dictionary
func get_event_cfg(event_id: StringName) -> Dictionary
func get_wave_template_cfg(template_id: StringName) -> Dictionary
func get_wave_template_ids_by_tier(tier: StringName) -> Array[StringName]
func get_all_wave_template_ids() -> Array[StringName]
func get_night_affix_cfg(affix_id: StringName) -> Dictionary
func get_all_night_affix_ids() -> Array[StringName]
func get_map_generation_cfg() -> Dictionary
func get_ui_icon_catalog() -> Dictionary
func get_scene_by_key(scene_key: StringName) -> PackedScene
func get_all_unit_ids() -> Array[StringName]
func get_all_enemy_ids() -> Array[StringName]
func get_all_buff_ids() -> Array[StringName]
func get_all_event_ids() -> Array[StringName]
func get_all_building_ids() -> Array[StringName]
func get_building_ids_by_type(building_type: StringName) -> Array[StringName]
```

方法规格：

- `load_all()`
  输入：无。
  行为：读取并缓存全部配置表和应用级配置。`DataRepo` 作为 Autoload 会在 `_ready()` 中自动调用；调试工具可以在需要热重载时显式调用。
  返回：无。
- `is_loaded()`
  输入：无。
  行为：读取静态配置是否已完成至少一次加载。
  返回：`bool`。
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
- `get_wave_template_cfg(template_id)`
  输入：`template_id: StringName`。
  行为：查询指定夜晚关卡模板配置。
  返回：`Dictionary`。
- `get_wave_template_ids_by_tier(tier)`
  输入：`tier: StringName`。
  行为：读取指定分层的模板 ID 列表。当前分层为 `early`、`mid`、`late`、`boss`。
  返回：`Array[StringName]`。
- `get_all_wave_template_ids()`
  输入：无。
  行为：读取全部夜晚关卡模板 ID。
  返回：`Array[StringName]`。
- `get_night_affix_cfg(affix_id)`
  输入：`affix_id: StringName`。
  行为：查询指定夜晚词缀配置。
  返回：`Dictionary`。
- `get_all_night_affix_ids()`
  输入：无。
  行为：读取全部夜晚词缀 ID。
  返回：`Array[StringName]`。
- `get_map_generation_cfg()`
  输入：无。
  行为：读取地图生成调参配置，包括地图尺寸、资源点数量、旧事件点数量、障碍数量和安全半径；正式随机事件点由 `RandomEventManager` 每日刷新。
  返回：`Dictionary`。
- `get_ui_icon_catalog()`
  输入：无。
  行为：读取 UI 图标目录配置。
  返回：`Dictionary`。
- `get_scene_by_key(scene_key)`
  输入：`scene_key: StringName`。
  行为：将逻辑场景名解析为场景模板。
  返回：`PackedScene`。
- `get_all_unit_ids()`
  输入：无。
  行为：读取全部单位配置 ID。
  返回：`Array[StringName]`。
- `get_all_enemy_ids()`
  输入：无。
  行为：读取全部敌人配置 ID。
  返回：`Array[StringName]`。
- `get_all_buff_ids()`
  输入：无。
  行为：读取全部 Buff/遗物配置 ID。
  返回：`Array[StringName]`。
- `get_all_event_ids()`
  输入：无。
  行为：读取全部可进入地图事件刷新池的根事件 ID，过滤 `hidden_in_map_pool` 的结果事件。
  返回：`Array[StringName]`。
- `get_all_building_ids()`
  输入：无。
  行为：按 `sort_order` 读取全部建筑配置 ID。
  返回：`Array[StringName]`。
- `get_building_ids_by_type(building_type)`
  输入：`building_type: StringName`。
  行为：按 `buildings.json[].building_type` 读取未被 `hidden_in_build_panel` 隐藏的建筑 ID，并按 `sort_order` 排序。
  返回：`Array[StringName]`。

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
func generate_debug_map(new_width: int, new_height: int, core_cell: Vector2i, spawn_defs: Dictionary, blocked_cells: Array = [], highland_cells: Array = []) -> void
func reset_map() -> void
func is_inside(cell: Vector2i) -> bool
func get_cell_data(cell: Vector2i) -> CellData
func get_all_cells() -> Array[Vector2i]
func is_discovered(cell: Vector2i) -> bool
func has_discovered_neighbor(cell: Vector2i) -> bool
func get_event_id_at_cell(cell: Vector2i) -> StringName
func mark_event_triggered(cell: Vector2i) -> void
func reveal_area(center: Vector2i, radius: int) -> Array[Vector2i]
func is_walkable(cell: Vector2i) -> bool
func is_buildable(cell: Vector2i) -> bool
func has_building(cell: Vector2i) -> bool
func has_unit(cell: Vector2i) -> bool
func set_building_occupy(cell: Vector2i, occupied: bool, building_runtime_id: int = -1) -> void
func set_unit_occupy(cell: Vector2i, occupied: bool, unit_runtime_id: int = -1) -> void
func clear_runtime_occupancy() -> void
func world_to_cell(world_pos: Vector2) -> Vector2i
func cell_to_world(cell: Vector2i) -> Vector2
func get_spawn_cells() -> Array[Vector2i]
func get_spawn_cell_by_key(spawn_key: StringName) -> Vector2i
func get_spawn_key_at_cell(cell: Vector2i) -> StringName
func get_core_cell() -> Vector2i
func get_random_discovered_empty_cell() -> Vector2i
func refresh_all_layers(reset_camera: bool = false) -> void
```

方法规格：

- `generate_new_map(seed)`
  输入：`seed: int`。
  行为：根据种子生成新地图并初始化格子数据。
  返回：无。
- `generate_debug_map(new_width, new_height, core_cell, spawn_defs, blocked_cells, highland_cells)`
  输入：调试地图尺寸、核心格、刷怪口字典、可选阻挡格列表、可选高台格列表。
  行为：生成全探索调试地图并刷新显示层；可按传入列表预置阻挡和高台地形；该操作允许重置地图镜头。
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
- `get_all_cells()`
  输入：无。
  行为：读取当前地图全部格子坐标，用于寻路、调试或统计；调用方不得直接修改格子真相数据。
  返回：`Array[Vector2i]`。
- `is_discovered(cell)`
  输入：`cell: Vector2i`。
  行为：判断格子是否已探索。
  返回：`bool`。
- `has_discovered_neighbor(cell)`
  输入：`cell: Vector2i`。
  行为：判断指定格子的上下左右四向邻居中是否至少有一个已探索格。
  返回：`bool`。
- `get_event_id_at_cell(cell)`
  输入：`cell: Vector2i`。
  行为：委托 `RandomEventManager` 读取指定坐标上的事件覆盖层 ID；无事件时返回空值。
  返回：`StringName`。
- `mark_event_triggered(cell)`
  输入：`cell: Vector2i`。
  行为：委托 `RandomEventManager` 移除指定坐标上的事件覆盖层，并刷新地图显示。
  返回：无。
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
- `has_unit(cell)`
  输入：`cell: Vector2i`。
  行为：判断格子是否有单位占用。
  返回：`bool`。
- `set_building_occupy(cell, occupied, building_runtime_id)`
  输入：格子、占用状态、建筑运行时 ID。
  行为：写入建筑占用状态。
  返回：无。
- `set_unit_occupy(cell, occupied, unit_runtime_id)`
  输入：格子、占用状态、单位运行时 ID。
  行为：写入单位占用状态并刷新地图显示；该刷新不应重置地图镜头。
  返回：无。
- `clear_runtime_occupancy()`
  输入：无。
  行为：清理建筑和单位运行时占用状态并刷新地图显示；该刷新不应重置地图镜头。
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
- `get_spawn_cell_by_key(spawn_key)`
  输入：刷怪口 key。
  行为：读取指定刷怪口所在格。
  返回：`Vector2i`；不存在时返回零向量。
- `get_spawn_key_at_cell(cell)`
  输入：地图格。
  行为：读取指定格上的刷怪口 key。
  返回：`StringName`；不存在时返回空值。
- `get_core_cell()`
  输入：无。
  行为：读取核心所在格子。
  返回：`Vector2i`。
- `get_random_discovered_empty_cell()`
  输入：无。
  行为：从已探索且未占用格中随机取一个。
  返回：`Vector2i`。
- `refresh_all_layers(reset_camera)`
  输入：是否重置地图镜头，默认 `false`。
  行为：刷新地图显示层和世界标记。普通占用变化只刷新图层；生成新地图、重置地图或地图尺寸变化时才传入 `true`。
  返回：无。

#### `MapRoot`

作用：

- 地图显示、地图点击事件与作战预览绘制

```gdscript
func refresh_from_map(map_manager: Node, reset_camera: bool = false) -> void
func set_debug_attack_range(cells: Array[Vector2i]) -> void
func clear_debug_attack_range() -> void
func set_deploy_preview(cell: Vector2i, is_valid: bool, range_cells: Array[Vector2i] = [], visual_key: String = "") -> void
func set_deploy_direction_preview(cell: Vector2i, facing: Vector2i, range_cells: Array[Vector2i] = [], visual_key: String = "") -> void
func clear_deploy_preview() -> void
func set_wave_route_previews(routes: Array[Dictionary]) -> void
func clear_wave_route_previews() -> void
func set_wave_route_highlight(spawn_key: String) -> void
func get_debug_info() -> String
```

方法规格：

- `refresh_from_map(map_manager, reset_camera)`
  输入：地图数据中心、是否重置镜头。
  行为：刷新地图绘制状态。`reset_camera=false` 时必须保留玩家当前镜头中心和相对缩放。
  返回：无。
- `set_debug_attack_range(cells)`
  输入：攻击范围格列表。
  行为：绘制选中单位的攻击范围预览。
  返回：无。
- `clear_debug_attack_range()`
  输入：无。
  行为：清除攻击范围预览；取消选中、撤退、清场时必须调用或间接触发。
  返回：无。
- `set_deploy_preview(cell, is_valid, range_cells, visual_key)`
  输入：拖拽落点、是否合法、按默认朝向计算的攻击范围、可选范围视觉 key。
  行为：绘制第一段拖拽时的合法/非法落点与范围预览。
  返回：无。
- `set_deploy_direction_preview(cell, facing, range_cells, visual_key)`
  输入：锁定落点、朝向、按该朝向计算的攻击范围、可选范围视觉 key。
  行为：绘制第二段拖拽时的锁定落点、朝向箭头和范围预览。
  返回：无。
- `clear_deploy_preview()`
  输入：无。
  行为：清除部署落点、朝向和范围预览。
  返回：无。
- `set_wave_route_previews(routes)`
  输入：整夜各出怪口的覆盖面路线数据数组。
  行为：绘制当晚每个出怪口的覆盖面路线预览。
  返回：无。
- `clear_wave_route_previews()`
  输入：无。
  行为：清除全部覆盖面路线预览。
  返回：无。
- `set_wave_route_highlight(spawn_key)`
  输入：出怪口 key。
  行为：高亮指定出怪口对应的覆盖面路线，用于敌情面板悬停联动；传空清除高亮。
  返回：无。

#### `PathService`

作用：

- 路径计算服务

```gdscript
func rebuild_from_map() -> void
func get_dist_map(path_mode: StringName) -> Dictionary
func get_front_map(path_mode: StringName) -> Dictionary
func has_route(cell: Vector2i, path_mode: StringName) -> bool
func get_core_distance(cell: Vector2i, path_mode: StringName) -> int
func compute_coverage(spawn_cell: Vector2i, requested_mode: StringName, half_width: int) -> Dictionary
func find_path(start_cell: Vector2i, end_cell: Vector2i, path_mode: StringName = PATH_MODE_NORMAL, extra_blocked_cells: Dictionary = {}) -> Array[Vector2i]
func find_path_preview(start_cell: Vector2i, end_cell: Vector2i, path_mode: StringName = PATH_MODE_NORMAL, extra_blocked_cells: Dictionary = {}) -> Dictionary
func get_cell_path(start_cell: Vector2i, end_cell: Vector2i, path_mode: StringName = PATH_MODE_NORMAL, extra_blocked_cells: Dictionary = {}) -> Array[Vector2i]
func has_path(start_cell: Vector2i, end_cell: Vector2i, path_mode: StringName = PATH_MODE_NORMAL, extra_blocked_cells: Dictionary = {}) -> bool
func is_core_enclosed_by_path_blockers(core_cell: Vector2i, extra_blocked_cells: Dictionary = {}) -> bool
func set_cell_blocked(cell: Vector2i, blocked: bool) -> void
```

方法规格：

- `rebuild_from_map()`
  输入：无。
  行为：根据当前地图阻挡信息重建路径网格，并按出怪口/飞行等模式预计算到核心的距离场与正面场。
  返回：无。
- `get_dist_map(path_mode)`
  输入：路径模式。
  行为：读取指定模式下全图到核心的距离场，是新移动系统铺面推进的依据。
  返回：`Dictionary`，键为格子坐标，值为到核心的步数。
- `get_front_map(path_mode)`
  输入：路径模式。
  行为：读取指定模式下的正面结构场，供敌人沿场铺面推进时判断同距等值面。
  返回：`Dictionary`。
- `has_route(cell, path_mode)`
  输入：格子与路径模式。
  行为：判断该格在指定模式下是否存在通往核心的路线（距离场可达）。
  返回：`bool`。
- `get_core_distance(cell, path_mode)`
  输入：格子与路径模式。
  行为：读取该格在指定模式下到核心的距离场步数。
  返回：`int`；不可达时返回约定的不可达值。
- `compute_coverage(spawn_cell, requested_mode, half_width)`
  输入：出怪口格、请求的路径模式、覆盖半宽。
  行为：沿距离场梯度从出怪口铺出一条中心线，再按半宽展开成覆盖带，用于覆盖面路线预览。
  返回：`Dictionary`，含中心线与覆盖格集合。
- `find_path(start_cell, end_cell, path_mode, extra_blocked_cells)`
  输入：起点格、终点格、路径模式、可选额外阻挡集合。
  行为：使用 A* 计算指定模式下的四向网格路径；保留为兼容入口，敌人常态移动已改走距离场铺面，不再每怪 A*。
  返回：`Array[Vector2i]`。
- `find_path_preview(start_cell, end_cell, path_mode, extra_blocked_cells)`
  输入：起点格、终点格、路径模式、可选额外阻挡集合。
  行为：在不改变寻路网格的前提下试算一条路径预览，用于部署/封口前的可达性与绕行预览。
  返回：`Dictionary`。
- `get_cell_path(start_cell, end_cell, path_mode, extra_blocked_cells)`
  输入：起点格、终点格、路径模式、可选额外阻挡集合。
  行为：使用 A* 计算指定模式下的四向网格路径。
  返回：`Array[Vector2i]`。
- `has_path(start_cell, end_cell, path_mode, extra_blocked_cells)`
  输入：起点格、终点格、路径模式、可选额外阻挡集合。
  行为：判断两点间在指定模式下是否存在路径。
  返回：`bool`。
- `is_core_enclosed_by_path_blockers(core_cell, extra_blocked_cells)`
  输入：核心格、可选额外阻挡集合。
  行为：判断核心是否被阻挡物完全围死，用于封口/建造前的合法性校验，避免出怪口被堵成无解局。
  返回：`bool`。
- `set_cell_blocked(cell, blocked)`
  输入：格子与阻挡状态。
  行为：手动设置某格是否阻挡寻路。
  返回：无。

#### `FlowField`

作用：

- 距离场与正面场计算核心，是新移动系统的底层算法。对外提供静态方法，由 `PathService` 调用预计算，敌人沿场逐步下降推进。

```gdscript
static func compute_distance(cells: Dictionary, core: Vector2i, blocked: Dictionary) -> Dictionary
static func compute_front(cells: Dictionary, dist: Dictionary, blocked: Dictionary) -> Dictionary
static func descend_step(dist: Dictionary, front: Dictionary, cell: Vector2i, phase: float, extra_blocked: Dictionary) -> Vector2i
```

方法规格：

- `compute_distance(cells, core, blocked)`
  输入：全部可行格集合、核心格、阻挡格集合。
  行为：从核心做 BFS，铺出全图到核心的距离场。
  返回：`Dictionary`，键为格子坐标，值为到核心的步数。
- `compute_front(cells, dist, blocked)`
  输入：可行格集合、已算好的距离场、阻挡格集合。
  行为：基于距离场计算正面结构场，标出同距等值面的推进正面。
  返回：`Dictionary`。
- `descend_step(dist, front, cell, phase, extra_blocked)`
  输入：距离场、正面场、当前格、相位扰动、运行时额外阻挡（如拦路干员）。
  行为：计算单只敌人沿场下降一格的下一步落点；遇到额外阻挡时沿正面横移绕行。
  返回：`Vector2i`，下一步格子。

### 3.3 建筑模块

#### `BuildValidator`

作用：

- 建造合法性校验

```gdscript
func can_place_building(cell: Vector2i, building_id: StringName, material_costs: Dictionary = {}) -> Dictionary
func can_repair_building(building_runtime_id: int) -> Dictionary
```

方法规格：

- `can_place_building(cell, building_id, material_costs)`
  输入：格子、建筑 ID、可选材料成本覆盖（传入时按其校验材料是否充足）。
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
func try_demolish_building(building_runtime_id: int) -> Dictionary
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
- `try_demolish_building(building_runtime_id)`
  输入：建筑运行时 ID。
  行为：白天拆除任意建筑，并清理地图占用与寻路状态。
  成功结果：返回 `ActionResult(ok = true)`，建筑已移除。
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
func start_new_day_shop(_day: int) -> void
func refresh_shop() -> Dictionary
func get_current_stock() -> Array[Dictionary]
func get_refresh_cost() -> int
func get_unit_purchase_cost(unit_cfg: Dictionary) -> int
func grant_unit(unit_id: StringName, star: int = 1, display_name: String = "") -> Dictionary
func try_buy_shop_slot(slot_index: int) -> Dictionary
func try_toggle_lock_slot(slot_index: int) -> Dictionary
func get_covenant_drift_state() -> Dictionary
func get_unit_roll_weight(unit_id: StringName) -> float
```

方法规格：

- `start_new_day_shop(_day)`
  输入：`_day: int`，当前实现未使用该形参（库存只按本局状态重抽）。
  行为：初始化新一天的商店库存；若存在锁定且未购买的槽位，其 `unit_id` 原位保留并维持锁定，其余槽位重抽。
  返回：无。
- `refresh_shop()`
  输入：无。
  行为：刷新当前商店库存；手动刷新会清空锁定并整页重抽。
  成功结果：返回 `ActionResult(ok = true)`，库存已更新。
  失败结果：返回 `ActionResult(ok = false)`，库存保持不变。
- `get_current_stock()`
  输入：无。
  行为：读取当前 5 个商店槽位。每个槽位至少包含 `slot_index`、`unit_id`、`sold`、`locked`。
  返回：`Array[Dictionary]`。
- `get_refresh_cost()`
  输入：无。
  行为：读取当前商店刷新价格；基础为 2 声望，远见 2 人且商店已买空时内部基价会置为 0，再叠加遗物修正，但当前实现最终最低夹取为 1。
  返回：`int`。
- `get_unit_purchase_cost(unit_cfg)`
  输入：单位配置字典。
  行为：读取当前购买该单位的实际价格；以 `cost_prestige` 为基础，叠加遗物和远见 3 人的价格修正，最终最低 1。
  返回：`int`。
- `grant_unit(unit_id, star = 1, display_name = "")`
  输入：单位 ID、可选星级和显示名。
  行为：不扣声望，直接新增一个干员槽位，并对该 `unit_id` 执行同名同星自动合成；事件奖励和调试工具使用该入口。
  成功结果：返回 `ActionResult(ok = true)`，payload 中包含新增槽位和 `merge_events`。
  失败结果：返回 `ActionResult(ok = false)`，不修改状态。
- `try_buy_shop_slot(slot_index)`
  输入：`slot_index: int`。
  行为：尝试购买指定商店槽位中的干员，购买成功后对该 `unit_id` 执行同名同星自动合成；若该槽位处于锁定状态则同时清除锁定。
  成功结果：返回 `ActionResult(ok = true)`，扣除声望、新增一个绑定该 `unit_id` 的 1 星干员实例槽位，并将商店槽位标记为已购买；payload 中可包含 `merge_events`。
  失败结果：返回 `ActionResult(ok = false)`，购买不生效。
- `try_toggle_lock_slot(slot_index)`
  输入：`slot_index: int`。
  行为：锁定或解锁指定的未购买槽位；每页同时只保留 1 个锁定位，锁定另一槽位会移走原锁定。锁定槽在次日 `start_new_day_shop` 重抽时原位保留，手动刷新清空锁定。仅白天可操作。
  成功结果：返回 `ActionResult(ok = true)`，payload 含 `slot_index`、`locked` 与最新 `stock`，并广播 `shop_stock_changed`。
  失败结果：返回 `ActionResult(ok = false)`（非白天、槽位无效、已购买或为空）。
- `get_covenant_drift_state()`
  输入：无。
  行为：读取盟约权重漂移状态。第 3 天起，按"去重单位类型"统计持有数最多的前 2 个盟约进入漂移集，其成员干员在同费用档内的出现权重 ×1.2（命中多个漂移盟约不叠乘），不影响 2/4/7 费档位分布。
  返回：`Dictionary`，含 `active: bool`、`covenants: Array[StringName]`、`multiplier: float`。
- `get_unit_roll_weight(unit_id)`
  输入：`unit_id: StringName`。
  行为：读取该单位在当前漂移状态下的商店抽取权重。
  返回：`float`（1.0 或漂移倍率）。

#### `UnitManager`

作用：

- 场上单位主控

```gdscript
func validate_deploy_operator(operator_key: StringName, cell: Vector2i) -> Dictionary
func try_deploy_operator(operator_key: StringName, cell: Vector2i, facing: Vector2i) -> Dictionary
func try_deploy_unit(unit_id: StringName, cell: Vector2i, facing: Vector2i) -> Dictionary
func try_retreat_unit(unit_runtime_id: int) -> Dictionary
func try_cast_skill(unit_runtime_id: int) -> Dictionary
func try_sell_operator(operator_key: StringName) -> Dictionary
func try_upgrade_operator_star(operator_key: StringName) -> Dictionary
func get_unit_by_runtime_id(unit_runtime_id: int) -> Node
func get_unit_by_operator_key(operator_key: StringName) -> Node
func get_operator_key_by_runtime_id(unit_runtime_id: int) -> StringName
func get_all_deployed_units() -> Array
func get_unit_by_cell(cell: Vector2i) -> Node
func is_operator_deployed(operator_key: StringName) -> bool
func is_operator_redeploying(operator_key: StringName) -> bool
func get_operator_redeploy_remaining(operator_key: StringName) -> float
func get_operator_status(operator_key: StringName) -> StringName
func withdraw_operators_for_merge(operator_keys: Array[StringName]) -> Dictionary
func is_unit_redeploying(unit_id: StringName) -> bool
func get_redeploy_remaining(unit_id: StringName) -> float
func tick_redeploy(delta: float) -> void
func remove_unit(unit_runtime_id: int, reason: int) -> void
func clear_all_units() -> void
```

方法规格：

- `validate_deploy_operator(operator_key, cell)`
  输入：干员槽位 key、候选部署格。
  行为：只执行部署合法性校验，不创建实例、不写入地图占用、不改变部署数量；用于拖拽部署预览。
  成功结果：返回 `ActionResult(ok = true)`。
  失败结果：返回 `ActionResult(ok = false)`，并给出失败原因。
- `try_deploy_operator(operator_key, cell, facing)`
  输入：干员槽位 key、部署格、朝向。
  行为：按槽位尝试部署单位并创建运行时实例；内部仍会重新校验合法性，不能只依赖 UI 预览结果。
  成功结果：返回 `ActionResult(ok = true)`，该槽位进入已部署状态。
  失败结果：返回 `ActionResult(ok = false)`，不创建实例。
- `try_deploy_unit(unit_id, cell, facing)`
  输入：单位 ID、部署格、朝向。
  行为：兼容旧调用；应选择一个绑定该 `unit_id`、未部署且未冷却的槽位后调用 `try_deploy_operator`。
  成功结果：返回 `ActionResult(ok = true)`，单位已部署。
  失败结果：返回 `ActionResult(ok = false)`，不创建实例。
- `try_retreat_unit(unit_runtime_id)`
  输入：单位运行时 ID。
  行为：尝试让单位撤退，并让对应干员槽位进入再部署冷却。
  成功结果：返回 `ActionResult(ok = true)`，单位已离场。
  失败结果：返回 `ActionResult(ok = false)`，单位保持在场。
- `try_cast_skill(unit_runtime_id)`
  输入：单位运行时 ID。
  行为：尝试释放单位技能。
  成功结果：返回 `ActionResult(ok = true)`，技能已执行。
  失败结果：返回 `ActionResult(ok = false)`，技能不执行。
- `try_sell_operator(operator_key)`
  输入：干员槽位 key。
  行为：检查白天阶段、拥有状态、未部署且未处于再部署冷却后，委托 `RunState.sell_owned_operator()` 移除槽位。
  成功结果：返回 `ActionResult(ok = true)`，默认获得 1 声望；远见 3 人且层数达标时由 `UnitManager` 按基础购买价折半覆盖返还值。
  失败结果：返回 `ActionResult(ok = false)`，槽位和声望不变。
- `try_upgrade_operator_star(operator_key)`
  输入：干员槽位 key。
  行为：校验该槽位未部署且未处于再部署冷却后，委托 `RunState.upgrade_owned_operator_star()` 对该干员定向升星。
  成功结果：返回 `ActionResult(ok = true)`，干员星级已提升、成本已扣除。
  失败结果：返回 `ActionResult(ok = false)`（已部署、再部署冷却中或 `RunState` 升星校验未通过），不修改状态。
- `get_unit_by_runtime_id(unit_runtime_id)`
  输入：单位运行时 ID。
  行为：按运行时 ID 查找单位实例。
  返回：`Node` 或空值。
- `get_unit_by_operator_key(operator_key)`
  输入：干员槽位 key。
  行为：查找该槽位当前部署在场的单位实例。
  返回：`Node` 或空值。
- `get_operator_key_by_runtime_id(unit_runtime_id)`
  输入：单位运行时 ID。
  行为：读取该运行时单位绑定的干员槽位 key。
  返回：`StringName`；不存在时返回空值。
- `get_all_deployed_units()`
  输入：无。
  行为：读取场上全部已部署单位。
  返回：`Array`。
- `get_unit_by_cell(cell)`
  输入：地图格。
  行为：查找部署在该格上的单位实例。
  返回：`Node` 或空值。
- `is_operator_deployed(operator_key)`
  输入：干员槽位 key。
  行为：检查该槽位是否已经部署在场。
  返回：`bool`。
- `is_operator_redeploying(operator_key)`
  输入：干员槽位 key。
  行为：检查该槽位是否处于再部署冷却。
  返回：`bool`。
- `get_operator_redeploy_remaining(operator_key)`
  输入：干员槽位 key。
  行为：读取该槽位剩余再部署冷却时间。
  返回：`float`。
- `get_operator_status(operator_key)`
  输入：干员槽位 key。
  行为：读取槽位部署状态。
  返回：`ready`、`deployed` 或 `cooldown`。
- `withdraw_operators_for_merge(operator_keys)`
  输入：参与合成的干员槽位 key 列表。
  行为：将其中已经部署在场的槽位移出战场，释放地图占用并减少部署数量；不触发再部署冷却。
  返回：`ActionResult(ok = true)`。
- `is_unit_redeploying(unit_id)`
  输入：单位 ID。
  行为：兼容旧调用；检查是否存在任一绑定该 `unit_id` 的槽位仍在冷却。
  返回：`bool`。
- `get_redeploy_remaining(unit_id)`
  输入：单位 ID。
  行为：兼容旧调用；读取绑定该 `unit_id` 的槽位中最长剩余再部署时间。
  返回：`float`。
- `tick_redeploy(delta)`
  输入：`delta: float`。
  行为：推进再部署冷却计时。
  返回：无。
- `remove_unit(unit_runtime_id, reason)`
  输入：单位运行时 ID 与离场原因。
  行为：移除指定单位；撤退和死亡原因会让对应槽位进入再部署冷却，调试清场、自动合成撤回等脚本原因不进入冷却。
  返回：无。
- `clear_all_units()`
  输入：无。
  行为：清除全部场上单位和槽位部署映射；用于调试清场或重置。
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
func setup_from_cfg(unit_id: StringName, cfg: Dictionary, spawn_cell: Vector2i, facing: Vector2i, new_operator_key: StringName = StringName(), new_operator_name: String = "") -> void
func receive_damage(value: int, damage_type_value: int, source: Node = null, pooled: bool = false) -> void
func receive_heal(value: int) -> void
func gain_sp(value: int) -> void
func can_cast_skill() -> bool
func cast_skill() -> void
func get_skill_ammo_status() -> Dictionary
func refresh_status_view() -> void
func get_runtime_id() -> int
func get_current_cell() -> Vector2i
func get_block_count() -> int
func get_attack_targets() -> Array
func launch_projectile(target: Node, payload: Dictionary = {}) -> Node
```

方法规格：

- `setup_from_cfg(unit_id, cfg, spawn_cell, facing, new_operator_key, new_operator_name)`
  输入：单位 ID、配置、出生格、朝向、可选干员槽位 key、可选干员显示名。
  行为：用配置初始化单位实例，并绑定其代表的干员槽位 key 与显示名。
  返回：无。
- `receive_damage(value, damage_type_value, source, pooled)`
  输入：伤害值、伤害类型、可选伤害来源节点、是否为池化伤害。
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
- `get_skill_ammo_status()`
  输入：无。
  行为：读取当前技能暴露的弹药状态；无弹药技能返回空字典。
  返回：`Dictionary`，可包含 `current`、`max`、`label`。
- `refresh_status_view()`
  输入：无。
  行为：要求单位刷新头顶状态条，用于技能内部弹药等运行时状态变化后同步 UI。
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
- `launch_projectile(target, payload)`
  输入：目标节点与飞行物 payload。payload 可覆盖 `projectile_scene_key`、`speed`、`hit_radius`、`damage`、`damage_type` 等字段。
  行为：在 `ProjectileRoot` 下创建飞行物并绑定命中回调；用于普攻和未来技能发射飞行物。
  返回：飞行物节点；创建失败时返回空值。

#### `UnitSkillBehavior`

作用：

- 单位技能行为扩展点。单位技能差异不走中心化 controller 分发，而是在 `UnitActor.setup_from_cfg()` 中按 `skill_behavior_key` 动态装配到 `SkillBehavior` 节点。

```gdscript
func setup(unit: Node) -> void
func tick(delta: float) -> void
func can_cast() -> bool
func cast() -> bool
func get_skill_name() -> String
func get_skill_description() -> String
func get_sp_max() -> float
func get_sp_recover_per_sec() -> float
func get_duration() -> float
func get_active_remaining() -> float
func is_active() -> bool
func get_ammo_status() -> Dictionary
func get_attack_targets_override() -> Array
func get_attack_projectile_payloads(target: Node, damage_value: int) -> Array
func after_attack(target: Node, damage_value: int) -> void
func modify_attack_damage(base_damage: int, target: Node) -> int
func after_receive_damage(source: Node, final_damage: int) -> void
```

方法规格：

- `setup(unit)`
  输入：所属单位实例。
  行为：绑定技能行为的 owner，初始化技能内部计时和状态。
  返回：无。
- `tick(delta)`
  输入：帧间隔。
  行为：推进技能持续时间；持续时间结束时恢复临时效果。
  返回：无。
- `can_cast()`
  输入：无。
  行为：判断技能是否满足 SP、未激活等释放条件。
  返回：`bool`。
- `cast()`
  输入：无。
  行为：执行技能启动逻辑，扣除 SP，并进入持续或永久激活状态。
  返回：是否成功释放。
- `get_skill_name()` / `get_skill_description()`
  行为：读取技能显示信息，供 HUD 和详情面板展示。
  返回：`String`。
- `get_sp_max()` / `get_sp_recover_per_sec()` / `get_duration()` / `get_active_remaining()` / `is_active()`
  行为：读取技能 SP、回复、持续时间和激活状态。
  返回：对应数值或状态。
- `get_ammo_status()`
  输入：无。
  行为：弹药型技能返回当前弹药状态；非弹药技能保持空字典。
  返回：`Dictionary`，可包含 `current`、`max`、`label`。
- `get_attack_targets_override()`
  输入：无。
  行为：可覆盖本次攻击目标列表，例如让近卫攻击所有被自身阻挡的敌人。
  返回：目标节点数组；空数组表示使用 `UnitActor` 默认索敌。
- `get_attack_projectile_payloads(target, damage_value)`
  输入：当前攻击目标与本次攻击伤害。
  行为：可返回多个飞行物 payload，用于让技能把一次普攻拆成多条可见弹道；返回空数组时 `UnitActor` 使用默认单飞行物。
  返回：`Array`，元素为 `Dictionary`。
- `after_attack(target, damage_value)`
  输入：真实命中的目标与伤害。
  行为：在即时攻击或飞行物命中后触发，用于追加连击、溅射、连锁等效果。
  返回：无。
- `modify_attack_damage(base_damage, target)`
  输入：基础伤害和目标。
  行为：在普攻伤害结算前修正伤害，例如攻击倍率提升。
  返回：修正后的伤害。
- `after_receive_damage(source, final_damage)`
  输入：伤害来源和最终伤害。
  行为：在单位受击后触发，用于反击、减伤反馈等技能效果。
  返回：无。

#### `Projectile`

作用：

- 通用飞行物 Actor

```gdscript
signal hit(projectile: Node, target: Node, payload: Dictionary)
signal expired(projectile: Node, reason: StringName, payload: Dictionary)

func setup(payload: Dictionary) -> void
```

方法规格：

- `setup(payload)`
  输入：飞行物初始化 payload，至少包含 `source` 和 `target`；常用字段包括 `origin`、`damage`、`damage_type`、`speed`、`hit_radius`、`max_lifetime`、`color`。
  行为：初始化来源、目标、运动参数和表现参数，随后在 `_process()` 中追踪目标。
  返回：无。

信号规格：

- `hit(projectile, target, payload)`
  行为：飞行物命中有效目标时发出。伤害结算由发射方监听后执行，确保不同单位和技能可以复用飞行物表现。
- `expired(projectile, reason, payload)`
  行为：目标失效或生命周期结束时发出。此时不造成伤害。

### 3.5 敌人与波次模块

#### `WaveManager`

作用：

- 夜晚关卡模板解析辅助与波次执行器

```gdscript
func tier_for_day(day: int) -> StringName
func resolve_night_template(tier: StringName, run_seed: int, day: int, used_ids: Array) -> StringName
func resolve_night_plan(run_seed: int, day: int, used_ids: Array) -> Array[StringName]
func start_night(template_ids: Array, affix_ids: Array = []) -> void
func start_wave_for_template(template_id: StringName) -> void
func stop_wave() -> void
func is_wave_finished() -> bool
func has_pending_spawn() -> bool
func get_current_wave_index() -> int
func get_wave_count() -> int
func get_current_wave_template_id() -> StringName
func get_wave_preview_for_template(template_id: StringName) -> Dictionary
func get_night_preview(template_ids: Array, affix_ids: Array = []) -> Dictionary
```

方法规格：

- `tier_for_day(day)`
  输入：`day: int`。
  行为：兼容入口，返回当晚多波计划的首波分层。完整分层序列由 `night_template_resolver.gd` 的 `wave_tiers_for_day()` 维护。
  返回：`StringName`。
- `resolve_night_template(tier, run_seed, day, used_ids)`
  输入：`tier: StringName`、`run_seed: int`、`day: int`、`used_ids: Array`。
  行为：兼容入口，从指定分层模板池中按本局随机种子和天数确定一个模板，并尽量避开本局已使用模板。
  返回：`StringName`。
- `resolve_night_plan(run_seed, day, used_ids)`
  输入：本局随机种子、天数和已使用模板 ID。
  行为：按当日多波分层序列逐波抽取模板；夜内和局内尽量不重复，池耗尽时允许回退重复。
  返回：`Array[StringName]`，为空表示无法解析有效夜晚计划。
- `start_night(template_ids, affix_ids = [])`
  输入：整夜模板 ID 序列与当晚词缀 ID 序列。
  行为：启动整夜多波刷怪流程；每波条目会先应用夜晚词缀变换，敌人生成时再应用词缀后的配置覆盖。
  返回：无。
- `start_wave_for_template(template_id)`
  输入：`template_id: StringName`。
  行为：单波兼容入口，内部等价于 `start_night([template_id], [])`。
  返回：无。
- `stop_wave()`
  输入：无。
  行为：停止当前波次。
  返回：无。
- `is_wave_finished()`
  输入：无。
  行为：判断整夜是否已结束：所有波次已放完、待刷怪队列为空且场上无敌人。
  返回：`bool`。
- `has_pending_spawn()`
  输入：无。
  行为：判断是否仍有待生成敌人。
  返回：`bool`。
- `get_current_wave_index()`
  输入：无。
  行为：读取当前正在执行的波次索引，未运行时返回 `-1`。
  返回：`int`。
- `get_wave_count()`
  输入：无。
  行为：读取当前整夜计划中的波次数。
  返回：`int`。
- `get_current_wave_template_id()`
  输入：无。
  行为：读取当前波次对应的模板 ID。
  返回：`StringName`。
- `get_wave_preview_for_template(template_id)`
  输入：`template_id: StringName`。
  行为：聚合单个模板刷怪条目，返回右上角敌情面板所需的标题、文案、关键敌人、路线和总数信息。预览中的随机敌人选择与夜晚实际刷怪使用同一确定性种子。
  返回：`Dictionary`。
- `get_night_preview(template_ids, affix_ids = [])`
  输入：整夜模板 ID 序列与当晚词缀 ID 序列。
  行为：聚合整夜多波预览，返回波次摘要、合并敌群、总数、出怪口顺序和词缀公示；条目和敌人数值按词缀生效后的真实结果计算。
  返回：`Dictionary`。

#### `EnemyManager`

作用：

- 场上敌人主控

```gdscript
func spawn_enemy(enemy_id: StringName, spawn_cell: Vector2i, cfg_override: Dictionary = {}) -> int
func remove_enemy(enemy_runtime_id: int, defeated: bool = true) -> void
func get_enemy_by_runtime_id(enemy_runtime_id: int) -> Node
func get_alive_enemy_count() -> int
func notify_enemy_reached_core(enemy_runtime_id: int) -> void
func clear_all_enemies() -> void
```

方法规格：

- `spawn_enemy(enemy_id, spawn_cell, cfg_override = {})`
  输入：敌人 ID、刷怪格和可选配置覆盖。
  行为：读取敌人基础配置，叠加 `cfg_override` 后创建敌人实例并加入场景；夜晚词缀使用该覆盖参数修正敌人数值。
  返回：敌人运行时 ID。
- `remove_enemy(enemy_runtime_id, defeated = true)`
  输入：敌人运行时 ID 和是否视为被击败。
  行为：移除指定敌人实例；`defeated = true` 时结算死亡效果和击杀声望，进核心等非击杀离场传 `false`。
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
- `clear_all_enemies()`
  输入：无。
  行为：清空当前场上所有敌人，不结算击杀奖励。
  返回：无。

#### `EnemyActor`

作用：

- 单个敌人实例行为

```gdscript
func setup_from_cfg(enemy_id: StringName, cfg: Dictionary, spawn_cell: Vector2i) -> void
func receive_damage(value: int, damage_type: int, defense_ignore: float = 0.0, source: Node = null) -> void
func get_runtime_id() -> int
func get_current_cell() -> Vector2i
func recalc_path() -> void
func set_blocked(blocker_runtime_id: int, block_slot: int = 0, block_slot_count: int = 1) -> void
func clear_blocked() -> void
```

方法规格：

- `setup_from_cfg(enemy_id, cfg, spawn_cell)`
  输入：敌人 ID、配置、出生格。
  行为：用配置初始化敌人实例。
  返回：无。
- `receive_damage(value, damage_type, defense_ignore, source)`
  输入：伤害值、伤害类型、可选无视防御比例、可选伤害来源节点。
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
- `set_blocked(blocker_runtime_id, block_slot, block_slot_count)`
  输入：阻挡者运行时 ID、阻挡槽位序号、阻挡槽位总数。
  行为：设置敌人被阻挡状态，并按槽位信息错开同一阻挡者上多个敌人的站位。
  返回：无。
- `clear_blocked()`
  输入：无。
  行为：清除阻挡状态。
  返回：无。

#### `BossController`

作用：

- 通用多阶段 Boss 控制器接口。
- 只在 `behavior_type == "boss"` 或配置存在非空 `phases` 时启用。
- 负责阶段流转、转阶段无敌计时、阶段配置读取和阶段进入效果；不负责普通移动、普通攻击、刷怪或死亡移除。
- 不硬编码具体 Boss ID。多个 Boss 的共性阶段机制通过 `enemies.json[].phases` 表达；特殊机制后续通过 `boss_behavior_key` 对应的行为组件扩展。

```gdscript
func setup(owner_actor: Node, initial_cfg: Dictionary) -> void
func is_enabled() -> bool
func is_transitioning() -> bool
func try_consume_death_for_phase_transition() -> bool
func tick(delta: float) -> Dictionary
func get_current_phase() -> int
func get_pending_phase_cfg() -> Dictionary
func apply_phase_enter_effects() -> void
```

方法规格：

- `setup(owner_actor, initial_cfg)`
  输入：所属 `EnemyActor` 与初始敌人配置。
  行为：绑定所属 Actor，读取 `phases`，初始化阶段状态。
  返回：无。
- `is_enabled()`
  输入：无。
  行为：判断当前敌人是否启用 Boss 阶段控制。
  返回：`bool`。
- `is_transitioning()`
  输入：无。
  行为：判断 Boss 是否处于转阶段无敌计时中。
  返回：`bool`。
- `try_consume_death_for_phase_transition()`
  输入：无。
  行为：当 `EnemyActor` HP 降为 0 时调用；若存在下一阶段，则进入转阶段并消费这次死亡。
  返回：`true` 表示进入转阶段，`false` 表示没有下一阶段，应继续普通死亡流程。
- `tick(delta)`
  输入：帧间隔。
  行为：推进转阶段计时。转阶段完成时返回下一阶段配置；未完成时返回空字典。
  返回：`Dictionary`。
- `get_current_phase()`
  输入：无。
  行为：读取当前 Boss 阶段编号。
  返回：`int`。
- `get_pending_phase_cfg()`
  输入：无。
  行为：读取待切换阶段配置。
  返回：`Dictionary`。
- `apply_phase_enter_effects()`
  输入：无。
  行为：执行阶段进入效果，例如 `phase_enter_area_damage`。
  返回：无。

Boss 阶段链路：

```text
wave_templates.json -> WaveManager -> EnemyManager.spawn_enemy()
-> DataRepo.get_enemy_cfg()
-> EnemyActor.setup_from_cfg()
-> EnemyActor 启用 BossController
-> EnemyActor.receive_damage()
-> BossController.try_consume_death_for_phase_transition()
-> BossController.tick()
-> EnemyActor 应用下一阶段配置
```

当 Boss 配置存在 `phases` 且当前阶段 HP 降为 0 时，`BossController` 会进入 `phase_transition_sec` 秒无敌转阶段；转阶段结束后向 `EnemyActor` 返回下一阶段配置。`EnemyActor` 负责 merge 配置、重置 `max_hp/current_hp`、重新计算寻路并更新显示，然后由 `BossController` 执行阶段进入效果。

### 3.6 UI 模块

#### `ActionPanel`

作用：

- 白天行动入口，目前仅承载 `进入黑夜` 按钮与建筑维护按钮（修复 / 拆除 / 开关）。
- 监听 `map_cell_clicked` 实现「点击未探索且相邻已探索的迷雾格 → 自动 `request_explore`」；监听 `map_cell_hovered` 配合 `MapRoot.set_fog_hover_active()` 给可探索迷雾格做悬停高亮。
- 旧的「待机 / 探索 / 建造」三态模式已废弃，模式相关 API 保留为兼容空壳，不应在新代码中调用。

```gdscript
# 兼容保留，新代码不要使用
func set_mode_idle() -> void
func set_mode_explore() -> void
func set_mode_build(building_id: StringName) -> void
func clear_mode() -> void
func get_current_mode() -> StringName
func get_current_building_id() -> StringName
```

方法规格：

- 上述 `set_mode_*` / `clear_mode` / `get_current_mode` / `get_current_building_id` 仍保留以避免破坏旧调用方，但内部不再驱动任何 UI 状态——`_current_mode` 恒为 `&"idle"`，建造请求改走拖拽流程（见 `CombatHudController` 与 `BuildPanel`）。

#### `BuildPanel`

作用：

- 建筑/商店复合显示接口

```gdscript
func set_visible_for_phase(phase: int) -> void
func refresh_from_state() -> void
```

方法规格：

- `set_visible_for_phase(phase)`
  输入：阶段枚举值。
  行为：记录阶段并调用 `refresh_from_state()`，根据当前阶段切换面板显隐并刷新当前标签页。
  返回：无。
- `refresh_from_state()`
  输入：无。
  行为：从 `RunState`、`ShopManager` 缓存和 `DataRepo` 统一刷新按钮状态、选择提示和卡片列表。建筑页通过 `DataRepo.get_building_ids_by_type()` 动态读取配置；商店页展示 `shop_stock_changed` 推送的库存。
  返回：无。
- 建筑卡点击
  行为：仅更新本面板的 `_selected_building_id` 用于卡片高亮；不再进入任何建造模式。
- 建筑卡拖拽
  行为：当鼠标按下后位移超过 `BuildListCard.DRAG_START_THRESHOLD` 时，卡片发出 `drag_started`，`BuildPanel` 转发为 `building_card_drag_started(building_id)`；由 `CombatHudController` 接管放置预览与落点提交。
- 商店卡点击
  行为：发出 `EventBus.request_buy_shop_slot(slot_index)`。
- 刷新按钮
  行为：发出 `EventBus.request_refresh_shop()`。
- 锁定按钮
  行为：对当前选中的商店槽位发出 `EventBus.request_toggle_shop_lock(slot_index)`；选中槽位已锁定时按钮文案变为"解锁槽位"，非白天、未选中、已购买或空槽位时禁用。锁定中的卡片状态栏显示"已锁定"。

#### `BuildListCard`

作用：

- 建筑/商店列表项

```gdscript
signal pressed
signal drag_started

func configure(config: Dictionary) -> void
```

方法规格：

- `configure(config)`
  输入：标题、说明、状态、图标文本、强调色、禁用态、`draggable`、`disabled_reason`（用作 tooltip）、最小高度等。
  行为：刷新列表项显示；当 `draggable=true` 且非 disabled 时按住卡片后位移超过 `DRAG_START_THRESHOLD` 触发 `drag_started`；释放前未触发拖拽则发出 `pressed`。

#### `UiDisplayText`

作用：

- 统一 UI 层显示文本与占位图标文本映射。
- 避免职业、阶级、伤害类型、方向、阶段等映射散落在多个 UI 脚本。

```gdscript
static func config_name(cfg: Dictionary, fallback_id: Variant = "") -> String
static func config_desc(cfg: Dictionary, fallback_text: String = "暂无说明") -> String
static func icon_text(cfg: Dictionary, fallback_text: String = "*") -> String
static func class_label(class_key: String) -> String
static func tier_label(cost_prestige: int) -> String
static func tier_color(cost_prestige: int) -> Color
static func damage_type_label(type_value: int) -> String
static func direction_label(direction: Vector2i) -> String
static func phase_label(phase: int) -> String
```

方法规格：

- `config_name(cfg, fallback_id)`
  输入：配置字典和兜底 ID。
  行为：优先返回 `cfg.name`，为空时返回兜底 ID。
  返回：`String`。
- `config_desc(cfg, fallback_text)`
  输入：配置字典和兜底说明。
  行为：优先返回 `cfg.desc`，为空时返回兜底说明。
  返回：`String`。
- `icon_text(cfg, fallback_text)`
  输入：配置字典和兜底图标字。
  行为：优先返回 `cfg.icon_text`；传入非默认兜底图标字时，其次返回兜底图标字；否则取 `cfg.name` 首字；最后返回 `*`。
  返回：`String`。
- `class_label(class_key)`
  输入：单位职业 key。
  行为：将 `guard`、`sniper`、`caster`、`defender` 等职业 key 映射为 UI 中文标签。
  返回：`String`。
- `tier_label(cost_prestige)` / `tier_color(cost_prestige)`
  输入：声望价格。
  行为：按当前商店价格规则映射阶级文本和颜色；后续存在显式 `tier` 或 `rarity` 字段时应优先使用显式字段。
  返回：`String` / `Color`。
- `damage_type_label(type_value)`
  输入：伤害类型枚举值。
  行为：映射为物理、法术、真实等中文标签。
  返回：`String`。
- `direction_label(direction)`
  输入：四向朝向。
  行为：映射为上、下、左、右。
  返回：`String`。
- `phase_label(phase)`
  输入：阶段枚举值。
  行为：映射为白天、夜晚、祝福、结算等中文阶段标签。
  返回：`String`。

UI 分层与重构构想见 `docs/UI_SYSTEM.md`。该工具只做显示转换，不加载配置、不保存 UI 状态、不修改玩法数据。

#### `CombatHud`

作用：

- 作战 HUD 场景化容器，主场景夜晚和 `CombatSandbox` 共用

信号：

```gdscript
signal operator_card_pressed(operator_key: StringName)
signal operator_card_drag_started(operator_key: StringName)
signal pause_pressed
signal speed_1_pressed
signal speed_2_pressed
signal cast_skill_requested
signal retreat_requested
signal operator_sell_requested(operator_key: StringName)
signal shop_unit_purchase_requested(slot_index: int)
signal wave_route_preview_toggled(enabled: bool)
signal wave_spawn_segment_hovered(spawn_key: String)
```

方法：

```gdscript
func set_top_values(core_text: String, deploy_text: String, queue_text: String) -> void
func show_message(text_value: String) -> void
func set_resource_values(resource_text: String, tooltip_text_value: String = "") -> void
func set_time_controls(paused: bool, speed: float) -> void
func set_bullet_time_feedback(active: bool, scale: float = 0.2) -> void
func set_operators(operators: Array[Dictionary]) -> void
func set_operator_card(operator_key: StringName, text_value: String, state: StringName) -> void
func show_drag_ghost(text_value: String) -> void
func move_drag_ghost(position_value: Vector2) -> void
func hide_drag_ghost() -> void
func show_unit_detail(unit: Node, display_name: String, damage_label: String, direction_label: String) -> void
func clear_unit_detail() -> void
```

方法规格：

- `set_top_values(core_text, deploy_text, queue_text)`
  行为：刷新顶部核心生命、部署数量和阶段/刷怪状态文本。
- `set_resource_values(resource_text, tooltip_text_value)`
  行为：刷新顶部资源文本和 tooltip。
- `set_time_controls(paused, speed)`
  行为：刷新暂停按钮和 1x/2x 倍速按钮状态；实际暂停和倍速由承载场景处理。
- `set_bullet_time_feedback(active, scale = 0.2)`
  行为：切换选中/部署操作时的子弹时间画面反馈；不显示说明文字，实际时间缩放由承载场景处理。
- `set_operators(operators)`
  行为：根据干员槽位列表实例化底部 `OperatorCard`。
- `set_operator_card(operator_key, text_value, state)`
  行为：刷新单个干员卡片文本和状态；`state` 至少覆盖 `ready`、`deployed`、`cooldown`。
- `show_drag_ghost()` / `move_drag_ghost()` / `hide_drag_ghost()`
  行为：显示、移动或隐藏卡片拖拽提示。
- `show_unit_detail()` / `clear_unit_detail()`
  行为：显示或清空选中单位详情；释放技能和撤退通过信号通知承载场景。

#### `CombatHudController`

作用：

- 主场景作战 UI 适配器

依赖节点：

```text
../CombatHud
../ActionPanel
../../World/MapRoot
../../Managers/MapManager
../../Managers/UnitManager
../../Managers/EnemyManager
```

行为规格：

- 接收 `CombatHud` 信号。
- 从 `RunState` 同步干员槽位和顶部状态。
- 执行底部干员卡拖拽、落点锁定、二段朝向选择和部署确认。
- 选中待部署干员、拖拽部署或点选场上干员时临时进入 `0.2x` 子弹时间，并同步显示右侧详情；再次点击同一干员卡或点击其他未处理区域时退出并清空详情，切换商店/建造、暂停或手动切换倍速时也恢复。
- 点击已部署单位时显示详情和攻击范围。
- 点击空地图格时取消选中并清除攻击范围。
- 转接技能、撤退、暂停和 1x/2x。

#### `OperatorCard`

作用：

- 底部待部署干员卡片

```gdscript
signal operator_card_pressed(operator_key: StringName)

func setup(new_operator_key: StringName) -> void
func set_state_text(text_value: String, state: StringName) -> void
```

方法规格：

- `setup(new_operator_key)`
  行为：绑定该卡片代表的干员槽位 key。
- `set_state_text(text_value, state)`
  行为：刷新卡片显示内容和状态色。

#### `UnitDetailPanel`

作用：

- 已部署单位详情和作战操作面板

```gdscript
signal cast_skill_requested
signal retreat_requested

func show_unit(unit: Node, display_name: String, damage_label: String, direction_label: String) -> void
func clear_unit() -> void
```

方法规格：

- `show_unit(unit, display_name, damage_label, direction_label)`
  行为：展示 HP、SP、ATK、DEF、RES、阻挡、攻速、伤害类型、朝向、技能名、技能描述和技能持续状态；SP 未满时禁用技能按钮。
- `clear_unit()`
  行为：隐藏详情面板，并禁用技能和撤退按钮。

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
| `day_started` | `day: int` | `GameController` | UI、DayManager、ShopManager、BuildingManager | 一天开始 |
| `night_started` | `day: int` | `GameController` | NightManager、WaveManager、UI | 夜晚开始 |
| `night_cleared` | `day: int` | `WaveManager` / `NightManager` | `GameController` | 夜战结束且守住 |
| `night_wave_started` | `wave_index: int, wave_count: int` | `WaveManager` | UI、调试工具 | 整夜中的某一波开始 |
| `run_ended` | `win: bool` | `GameController` | `SceneRouter`、`ResultPanel` | 一局结束 |

### 4.2 状态变化信号

| 信号名 | 参数 | 发出方 | 监听方 | 说明 |
|---|---|---|---|---|
| `action_points_changed` | `value: int` | `RunState` | CombatHudController、ActionPanel | 行动力变化 |
| `prestige_changed` | `value: int` | `RunState` | CombatHudController、BuildPanel | 声望变化 |
| `materials_changed` | `wood: int, stone: int, mana: int` | `RunState` | CombatHudController、BuildPanel | 材料变化 |
| `core_hp_changed` | `current: int, max_value: int` | `RunState` | CombatHudController、ResultPanel | 核心血量变化 |
| `core_damaged` | `amount: int, current: int, max_value: int` | `RunState` | GameController、调试工具 | 核心实际受到伤害 |
| `deploy_limit_changed` | `current: int, max_value: int` | `RunState` | CombatHudController、CombatSandbox | 部署数量变化 |
| `owned_operators_changed` | `operators: Array[Dictionary]` | `RunState` | CombatHudController、CombatSandbox | 已拥有干员槽位变化 |
| `owned_units_changed` | `unit_ids: Array[StringName]` | `RunState` | 兼容旧调用、调试工具 | 已拥有单位类型集合变化，兼容旧的按 `unit_id` 读取方式 |
| `buffs_changed` | `buff_ids: Array[StringName]` | `RunState` | 调试工具、后续 UI | 已获得 Buff 列表变化 |
| `shop_stock_changed` | `stock_slots: Array[Dictionary]` | `ShopManager` | BuildPanel | 商店槽位库存变化 |
| `shop_action_result` | `action: StringName, result: Dictionary` | `ShopManager` | BuildPanel | 商店购买或刷新结果 |
| `resource_collected` | `cell: Vector2i, resource_type: StringName, amount: int` | `DayManager` | MapInteractionPopup | 资源点手动采集完成 |

### 4.3 玩家请求信号

| 信号名 | 参数 | 发出方 | 监听方 | 说明 |
|---|---|---|---|---|
| `request_explore` | `cell: Vector2i` | UI | `DayManager` | 请求探索 |
| `request_build` | `cell: Vector2i, building_id: StringName` | UI | `BuildingManager` / `DayManager` | 请求建造 |
| `request_toggle_building` | `building_runtime_id: int` | UI / ActionPanel | `BuildingManager` | 请求切换可开关建筑的启用状态 |
| `request_interact_event` | `cell: Vector2i` | UI | `DayManager` / `RandomEventManager` | 请求处理事件 |
| `request_open_event_panel` | `cell: Vector2i` | UI | `EventPanel` | 请求打开指定事件点的事件弹窗 |
| `request_start_night` | 无 | UI | `GameController` / `DayManager` | 请求结束白天 |
| `request_buy_shop_slot` | `slot_index: int` | UI | `ShopManager` | 请求购买指定商店槽位 |
| `request_refresh_shop` | 无 | UI | `ShopManager` | 请求刷新商店 |
| `request_toggle_shop_lock` | `slot_index: int` | UI | `ShopManager` | 请求锁定/解锁指定商店槽位 |
| `request_upgrade_operator_star` | `operator_key: StringName` | UI | `UnitManager` | 请求对指定干员定向升星 |
| `operator_star_upgrade_result` | `operator_key: StringName, result: Dictionary` | `UnitManager` | UI | 定向升星结果回执 |
| `blessing_chosen` | `buff_id: StringName` | UI | `GameController`、`BuffManager` | 选择某个祝福 |

### 4.4 世界事件信号

| 信号名 | 参数 | 发出方 | 监听方 | 说明 |
|---|---|---|---|---|
| `fog_revealed` | `cells: Array[Vector2i]` | `MapManager` | UI、调试工具 | 迷雾被揭开 |
| `map_cell_clicked` | `cell: Vector2i` | `MapRoot` | ActionPanel、CombatHudController、CombatSandbox | 地图格点击事件，承载场景根据当前模式解释点击含义 |
| `map_cell_hovered` | `cell: Vector2i` | `MapRoot` | CombatHudController、CombatSandbox | 地图格悬停事件 |
| `right_click_tapped` | 无 | `MapRoot` | ActionPanel、CombatHudController | 右键/取消输入 |
| `building_placed` | `building_runtime_id: int, building_id: StringName, cell: Vector2i` | `BuildingManager` | `MapManager`、`PathService` | 建筑已放置 |
| `building_destroyed` | `building_runtime_id: int, building_id: StringName, cell: Vector2i` | `BuildingManager` | `MapManager`、`PathService` | 建筑已摧毁 |
| `building_state_changed` | `building_runtime_id: int, building_id: StringName, enabled: bool` | `BuildingManager` | ActionPanel、调试工具 | 建筑启用/停用状态已变化 |
| `build_action_result` | `building_id: StringName, cell: Vector2i, result: Dictionary` | `BuildingManager` | BuildPanel、ActionPanel | 建造/建筑操作结果 |
| `path_grid_changed` | 无 | `BuildingManager` / `MapManager` | `PathService`、`EnemyManager` | 寻路网格需重建 |
| `unit_deployed` | `unit_runtime_id: int, operator_key: StringName, unit_id: StringName, cell: Vector2i` | `UnitManager` | CombatHudController、CombatSandbox | 干员槽位已部署 |
| `unit_removed` | `unit_runtime_id: int, reason: int` | `UnitManager` | CombatHudController、CombatSandbox | 单位离场 |
| `unit_died` | `unit_runtime_id: int, unit_id: StringName, cell: Vector2i` | `UnitManager` | BuffManager、CombatHudController | 单位死亡 |
| `covenants_changed` | `entries: Array` | `CovenantManager` | UI、调试工具 | 盟约状态重算 |
| `unit_skill_cast` | `unit_runtime_id: int, unit_id: StringName` | `UnitActor` | BuffManager | 单位释放技能 |
| `enemy_spawned` | `enemy_runtime_id: int, enemy_id: StringName, cell: Vector2i` | `EnemyManager` | CombatHudController、调试工具 | 敌人出生 |
| `enemy_died` | `enemy_runtime_id: int, enemy_id: StringName` | `EnemyManager` | `WaveManager`、`BuffManager` | 敌人死亡 |
| `random_event_triggered` | `event_id: StringName, cell: Vector2i` | `RandomEventManager` | `EventPanel` | 兼容旧事件展示入口；当前地图事件默认通过地图对象弹窗点击触发 |
| `random_event_choice_selected` | `event_id: StringName, cell: Vector2i, choice_id: StringName, result: Dictionary` | `EventPanel` | UI、调试工具 | 事件选项已选择并返回结算结果 |
| `blessing_choices_ready` | `choice_ids: Array[StringName]` | `BuffManager` | `BlessingPanel` | 祝福选项已生成 |
| `blessing_choices_with_sources_ready` | `entries: Array` | `BuffManager` | `BlessingPanel` | 带来源的遗物三选一已生成，每项含 `buff_id` 与 `slot`（盟约导向/经济/随机） |
| `night_gate_overrides_changed` | 无 | `RunState` | UI、`WaveManager` | 出怪口动态封堵/额外开启集合变化 |
| `audio_cue_requested` | `cue_key: StringName` | UI / 系统 | 音频绑定器 | 请求播放指定音效 |
| `core_destroyed` | 无 | `RunState` | `GameController`、`ResultPanel` | 核心归零 |

---

## 5. UI 请求出口

白天经营请求继续使用 `EventBus.emit()`，作战部署、技能和撤退由 `CombatHudController` 或 `CombatSandbox` 直接调用 `UnitManager`。

- 探索：`EventBus.request_explore.emit(cell)`
- 建造：`EventBus.request_build.emit(cell, building_id)`
- 切换建筑开关：`EventBus.request_toggle_building.emit(building_runtime_id)`
- 处理事件：`EventBus.request_interact_event.emit(cell)`
- 结束白天：`EventBus.request_start_night.emit()`
- 购买商店槽位：`EventBus.request_buy_shop_slot.emit(slot_index)`
- 刷新商店：`EventBus.request_refresh_shop.emit()`
- 选择祝福：`EventBus.blessing_chosen.emit(buff_id)`

地图格点击由 `MapRoot` 在左键短按释放时统一发出 `EventBus.map_cell_clicked.emit(cell)`，再由 `ActionPanel`（未探索的可探索迷雾格自动 `request_explore`）、`MapInteractionPopup`（已探索格弹出资源/事件/建筑交互窗）、`CombatHudController` 或 `CombatSandbox`（战斗中的单位选中与部署流程）各自解释。左键或右键按下后移动超过 5 px 会改为平移地图镜头，不触发格子点击或右键关闭；触摸端单指沿用鼠标模拟，双指手势由 `InputEventScreenTouch` / `InputEventScreenDrag` 直接缩放并跟随双指中心平移。建造请求改由 `CombatHudController` 监听 `BuildPanel.building_card_drag_started` 启动拖拽，并在释放时通过 `EventBus.request_build.emit(cell, building_id)` 提交。鼠标悬停通过 `EventBus.map_cell_hovered` 通知 `ActionPanel` 触发迷雾可探索高亮；右键 tap（5 px / 300 ms 内）通过 `EventBus.right_click_tapped` 通知 `MapInteractionPopup` 一键关闭浮层。

作战 UI 组件本身仍只发出信号。例如 `CombatHud` 发出干员卡片、暂停、倍速、技能和撤退信号；主场景由 `CombatHudController` 调用 `UnitManager`、`MapRoot` 或修改 `SceneTree.paused`，调试场景由 `CombatSandbox` 做同样转接。

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
- `map_cell_clicked`

### 6.3 建筑模块

监听：

- `request_build`
- `request_toggle_building`
- `day_started`
- `night_started`

对外广播：

- `building_placed`
- `building_destroyed`
- `building_state_changed`
- `path_grid_changed`

### 6.4 单位与商店模块

监听：

- `request_buy_shop_slot`
- `request_refresh_shop`
- `request_toggle_shop_lock`
- `request_upgrade_operator_star`
- `phase_changed`
- `day_started`
- `night_started`

对外广播：

- `shop_stock_changed`
- `shop_action_result`
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
- `shop_action_result`
- `blessing_choices_ready`
- `random_event_triggered`
- `deploy_limit_changed`
- `owned_operators_changed`
- `covenants_changed`
- `night_gate_overrides_changed`
- `map_cell_clicked`

对外广播：

- 全部 `request_xxx`
- `blessing_chosen`
