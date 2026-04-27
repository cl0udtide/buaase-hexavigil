# EnemyActor 与 BossController 拆分方案

## 1. 当前判断

`scripts/enemy/enemy_actor.gd` 当前约 588 行。这个体量在原型阶段仍可运行，但它已经承担了多个不同职责：

- 敌人基础状态：`enemy_id`、`runtime_id`、`cfg`、HP、死亡状态。
- 移动与寻路：路径缓存、路径进度、飞行 / 拆路 / 普通路径模式、击退。
- 阻挡逻辑：阻挡者记录、阻挡站位、阻挡时移动贴合。
- 攻击逻辑：攻击阻挡单位、攻击路径建筑、远程索敌、伤害类型解析。
- 建筑交互：路径建筑判定、是否攻击建筑、建筑伤害转发。
- Boss / 多阶段逻辑：阶段配置读取、转阶段无敌计时、二阶段配置合并、入场范围伤害。
- 表现和调试：绘制占位图形、标题更新、HP 状态条、战斗日志文本。

问题不只是“行数较多”，而是职责边界已经混在一起。尤其多阶段 Boss 的状态机目前嵌在普通敌人 Actor 里；后续如果加入多个 Boss、第三阶段、技能循环、召唤、地图效果或阶段事件，`EnemyActor` 会继续膨胀。

结论：

- 普通敌人不需要多阶段状态机。
- 只有 Boss 需要阶段控制，因此应复用并改造现有 `scripts/enemy/boss_controller.gd`。
- `BossController` 不应变成某一个 Boss 的专属脚本，而应作为“多阶段 Boss 的通用阶段控制器”。
- 具体 Boss 的特殊技能和机制，后续再通过可选行为组件扩展。

## 2. 当前状态

当前工作区状态：

- `EnemyActor` 已经支持配置化二阶段 Boss，但阶段状态机仍直接写在 `scripts/enemy/enemy_actor.gd` 中。
- `scripts/enemy/boss_controller.gd` 存在，但目前只是空壳接口，尚未参与运行。
- `data/enemies.json` 中已有 Boss 示例 `milk_dragon_chief`，通过 `behavior_type: "boss"`、`phase_transition_sec`、`phases` 和 `phase_enter_area_damage` 表达二阶段行为。
- `DATA_SCHEMA.md` 已经补充 Boss 数据约定：`phases` 仅 Boss 使用，`boss_controller_key` 默认 `phase_boss`，`boss_behavior_key` 是未来扩展字段。

因此，本方案不是描述“已经完成的代码结构”，而是描述从当前实现迁移到 `BossController` 结构的设计和步骤。

## 3. 目标设计

`EnemyActor` 仍是场上敌人的门面节点，负责：

- 暴露现有公开接口：`setup_from_cfg()`、`receive_damage()`、`get_runtime_id()`、`get_current_cell()`、`recalc_path()`、`set_blocked()`、`clear_blocked()`。
- 持有敌人身份、位置、HP 和死亡状态。
- 调度移动、攻击、受击、死亡和抵达核心流程。
- 在敌人是 Boss 时，把阶段相关决策交给 `BossController`。

`BossController` 作为可选子控制器，只在 `behavior_type == "boss"` 或配置存在 `phases` 时启用，负责：

- 读取和维护 `phases`。
- 判断一次 HP 归零是否应触发转阶段，而不是死亡。
- 管理转阶段无敌和计时。
- 在转阶段完成后提供下一阶段配置。
- 执行阶段进入效果，例如 `phase_enter_area_damage`。

## 4. 推荐结构

```text
scripts/enemy/
├─ enemy_actor.gd                    [敌人门面 Actor，普通敌人与 Boss 共用]
├─ boss_controller.gd                [通用多阶段 Boss 控制器]
├─ boss_behaviors/                   [可选，未来 Boss 专属机制]
│  ├─ boss_behavior.gd               [Boss 特殊行为基类]
│  ├─ summoner_boss_behavior.gd      [示例：召唤型 Boss]
│  └─ shield_cycle_boss_behavior.gd  [示例：护盾循环 Boss]
├─ enemy_movement_controller.gd      [可选后续拆分：移动、寻路、击退、路径模式]
├─ enemy_attack_controller.gd        [可选后续拆分：阻挡攻击、远程攻击、建筑攻击]
└─ enemy_targeting.gd                [可选后续拆分：目标搜索与目标选择]
```

近期只建议落地 `boss_controller.gd` 的通用阶段控制，不急于一次性拆移动和攻击。

## 5. BossController 设计

### 5.1 职责边界

`BossController` 负责“阶段系统”，不负责普通敌人行为：

- 不直接寻路。
- 不直接执行普通攻击。
- 不直接管理敌人出生或死亡移除。
- 不硬编码具体 Boss ID。

它可以调用 `EnemyActor` 提供的薄接口，例如应用阶段配置、获取当前位置、对周围单位或建筑造成阶段入场效果。

### 5.2 建议接口

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

方法说明：

- `setup(owner_actor, initial_cfg)`
  绑定所属 `EnemyActor`，读取初始配置和 `phases`。
- `is_enabled()`
  判断当前敌人是否启用 Boss 阶段控制。
- `try_consume_death_for_phase_transition()`
  当 `EnemyActor.receive_damage()` 把 HP 扣到 0 时调用。如果存在下一阶段，则进入转阶段并返回 `true`；否则返回 `false`，让 `EnemyActor` 继续死亡流程。
- `tick(delta)`
  推进转阶段计时。转阶段完成时返回下一阶段配置；未完成时返回空字典。
- `apply_phase_enter_effects()`
  执行阶段进入效果，例如 `phase_enter_area_damage`。

### 5.3 EnemyActor 调用流程

`EnemyActor.setup_from_cfg()`：

```text
初始化普通敌人字段
-> 如果 cfg.behavior_type == "boss" 或 cfg.phases 非空
-> 创建或启用 BossController
-> boss_controller.setup(self, cfg)
```

`EnemyActor.receive_damage()`：

```text
如果 BossController 正在转阶段，则免疫伤害
-> 正常扣血
-> HP 降到 0
-> boss_controller.try_consume_death_for_phase_transition()
-> 如果返回 true：刷新状态条并退出，不移除敌人
-> 如果返回 false：按普通敌人死亡流程移除
```

`EnemyActor._process()`：

```text
如果 BossController 正在转阶段：
    phase_cfg = boss_controller.tick(delta)
    如果 phase_cfg 非空：
        EnemyActor.apply_phase_cfg(phase_cfg)
        boss_controller.apply_phase_enter_effects()
    return

继续普通敌人的阻挡、攻击、移动流程
```

`EnemyActor.apply_phase_cfg(phase_cfg)` 建议保留在 `EnemyActor`，因为它直接影响 Actor 自身状态：

- merge 新阶段配置到 `cfg`。
- 重置 `max_hp/current_hp`。
- 更新路径模式。
- 重置攻击计时。
- 更新标题和状态条。
- 如未被阻挡，重新计算路径。

## 6. 多 Boss 扩展原则

多个 Boss 都有多阶段时，不应写成：

```gdscript
if enemy_id == &"boss_a":
    ...
elif enemy_id == &"boss_b":
    ...
```

推荐先数据化共性：

```json
{
  "id": "milk_dragon_chief",
  "behavior_type": "boss",
  "boss_controller_key": "phase_boss",
  "phases": [
    {
      "phase": 2,
      "name": "奶龙酋长·暴怒形态",
      "max_hp": 1100,
      "atk": 160,
      "phase_enter_area_damage": {
        "radius": 1,
        "damage": 80,
        "damage_type": "magic"
      }
    }
  ]
}
```

字段含义：

- `behavior_type: "boss"`
  表示这是 Boss 敌人，启用 Boss 相关逻辑。
- `boss_controller_key`
  可选。默认使用通用 `phase_boss`。未来如果出现完全不同的 Boss 阶段控制器，可以通过该 key 切换。
- `phases`
  后续阶段数组，每个阶段用 `phase` 标识阶段编号，并覆盖基础数值和阶段事件。

如果某个 Boss 有独特机制，再增加可选行为 key：

```json
{
  "boss_behavior_key": "summoner_boss"
}
```

对应未来目录：

```text
scripts/enemy/boss_behaviors/
├─ boss_behavior.gd
├─ summoner_boss_behavior.gd
└─ shield_cycle_boss_behavior.gd
```

`BossController` 仍只负责阶段流转；`boss_behaviors/*` 负责某个 Boss 的特殊技能、召唤、护盾循环或地图效果。

## 7. 推荐迁移顺序

### 第一步：启用 `boss_controller.gd`

把 `EnemyActor` 中以下字段和逻辑迁入 `BossController`：

- `_boss_phase`
- `_phase_transitioning`
- `_phase_transition_timer`
- `_phase_two_cfg`
- `_process_phase_transition()`
- `_should_enter_next_boss_phase()`
- `_start_phase_transition()`
- `_get_phase_cfg()`

`EnemyActor` 保留以下薄逻辑：

- 应用阶段配置。
- 更新 HP、标题、状态条。
- 重新计算路径。
- 调用 BossController 的阶段进入效果。

验收标准：

- `milk_dragon_chief` 第一阶段 HP 清零后仍进入无敌转阶段。
- 转阶段期间不移动、不攻击、免疫伤害。
- 转阶段后名称、HP、攻击范围、攻击间隔、核心伤害等字段按二阶段配置生效。
- `phase_enter_area_damage` 仍能对周围单位和建筑生效。
- 普通敌人没有 `phases` 时死亡流程不变，且不创建 BossController 的有效状态。

### 第二步：视情况拆移动与攻击

等 Boss 状态机迁出后，再评估 `enemy_actor.gd` 的剩余体量。如果仍然偏大，再按以下顺序拆：

1. `enemy_movement_controller.gd`
2. `enemy_attack_controller.gd`
3. `enemy_targeting.gd`

这一步不应和 BossController 迁移混在同一个 PR 中。

## 8. 不建议做的事

- 不建议把所有 Boss 规则都写进一个巨大的 `boss_controller.gd`。
- 不建议按 `enemy_id` 在 `EnemyActor` 或 `BossController` 中写大量分支。
- 不建议普通敌人也持有复杂阶段状态。
- 不建议在同一次改动里同时拆 Boss、移动、攻击和数据格式。

## 9. 最终期望

拆分完成后：

- `EnemyActor` 控制在约 300-400 行，主要表达敌人生命周期和模块调度。
- `BossController` 成为所有多阶段 Boss 的通用阶段控制器。
- 具体 Boss 差异优先由 `enemies.json` 数据表达。
- 数据表达不了的 Boss 特殊机制，再进入 `boss_behaviors/` 行为组件。
