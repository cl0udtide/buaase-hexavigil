# 单位 Actor 与差异化配置方案

## 目标

战斗与塔防模块中的单位需要支持不同外观、技能、音效、特效和少量特殊行为。为了避免每个单位都复制一份完整场景导致公共结构难以维护，推荐采用以下原则：

> 属性差异数据化，行为差异组件化，结构差异才场景化。

也就是说，大多数单位应复用统一的 `UnitActor.tscn`；只有当单位的节点结构、生命周期或交互方式明显不同于普通单位时，才使用专用场景，并且专用场景应继承自 `UnitActor.tscn`，而不是复制一份平级场景。

## 推荐结构

```text
scenes/actors/UnitActor.tscn
├─ TitleLabel
├─ StatusView
├─ VisualRoot
├─ AudioRoot
├─ EffectRoot
└─ SkillBehavior

scenes/actors/units/Guard.tscn
└─ 继承 UnitActor.tscn，只覆盖近卫差异

scenes/actors/units/Sniper.tscn
└─ 继承 UnitActor.tscn，只覆盖狙击差异
```

`UnitActor.tscn` 是所有普通单位的基础模板，负责统一的运行时结构。派生单位场景只负责覆盖差异，例如替换外观节点、挂载专用技能脚本、配置音效或特效资源。

## 数据与场景的分工

### JSON 负责静态配置

`data/units.json` 适合保存可以被数据描述的内容，例如：

- 基础数值：生命、攻击、防御、法抗、阻挡数、攻速、再部署时间。
- 攻击配置：伤害类型、目标类型、攻击范围。
- 技能参数：SP 上限、持续时间、倍率、范围、溅射半径。
- 资源引用：图标 key、外观 key、音效 key、特效 key、技能行为 key。

示例字段设计：

```json
{
  "id": "guard_01",
  "name": "近卫",
  "class": "guard",
  "scene_key": "unit_actor",
  "visual_key": "guard_visual",
  "skill_behavior_key": "guard_hold_line",
  "attack_sfx_key": "guard_attack",
  "cast_vfx_key": "guard_skill_cast"
}
```

### 脚本负责行为逻辑

复杂技能不建议完全 JSON 化。JSON 应描述参数，脚本应负责行为。

例如：

```text
skill_behavior_key: guard_hold_line
-> scripts/combat/skills/guard_hold_line_skill.gd
```

技能脚本继承统一基类：

```gdscript
extends "res://scripts/combat/skills/unit_skill_behavior.gd"
```

这样可以复用统一的技能生命周期接口，同时允许不同技能拥有不同实现。

### 场景负责节点结构

场景适合表达节点结构和编辑器可视化配置，例如：

- 外观节点结构。
- 动画播放器。
- 音频播放器。
- 特效挂点。
- 碰撞区域。
- 选择框、状态条、Buff 图标挂点。

普通单位应优先使用 `UnitActor.tscn` 的公共结构，通过 JSON 或子节点资源完成差异化。

## 什么时候使用统一 `UnitActor.tscn`

以下情况应优先复用 `UnitActor.tscn`：

- 只是数值不同。
- 只是攻击范围不同。
- 只是技能参数不同。
- 只是技能脚本不同。
- 只是外观、音效、特效资源不同。
- 生命周期仍然是部署、攻击、受伤、技能、撤退、死亡这一套普通单位流程。

这种情况下，`units.json` 中的 `scene_key` 建议继续写：

```json
"scene_key": "unit_actor"
```

## 什么时候使用专用 `.tscn`

只有当单位确实突破普通单位结构时，才建议使用专用场景。例如：

- 单位拥有多个可独立受击或攻击的子节点。
- 单位部署后会展开成建筑或召唤物组合。
- 单位有完全不同的动画树、碰撞结构或挂点结构。
- 单位的交互方式和普通单位不同，例如可拖拽变形、可切换站位、可产生子单位。
- 普通 `UnitActor.tscn` 的预留挂点无法干净表达其结构。

即便如此，专用场景也不应从零新建或复制普通场景，而应使用 Godot 的继承场景机制。

## 专用场景必须继承基础场景

推荐关系：

```text
UnitActor.tscn
└─ Guard.tscn inherits UnitActor.tscn
└─ Sniper.tscn inherits UnitActor.tscn
└─ SpecialUnit.tscn inherits UnitActor.tscn
```

这样做的好处是：

- 公共节点只维护一份，例如 `StatusView`、选择框、Buff 图标、调试节点。
- 公共逻辑只维护一份，例如部署、受伤、攻击、SP、撤退、死亡。
- 基础场景新增公共节点后，派生场景可以自动继承。
- 派生场景只保存覆盖项，避免复制粘贴导致不一致。

在 Godot 编辑器中，应通过 `New Inherited Scene` / `新建继承场景` 从 `UnitActor.tscn` 创建专用单位场景，不要直接复制 `.tscn` 文件后改名。

## GDScript 的继承使用方式

GDScript 支持类、继承和方法覆写。

普通单位脚本：

```gdscript
extends Node2D
```

技能基类可以声明全局类名：

```gdscript
class_name UnitSkillBehavior
extends Node
```

具体技能继承技能基类：

```gdscript
extends "res://scripts/combat/skills/unit_skill_behavior.gd"
```

如果某个单位不仅技能特殊，而且普通攻击、受击、部署规则等核心行为都特殊，可以写派生单位脚本：

```gdscript
extends "res://scripts/combat/unit_actor.gd"

func _ready() -> void:
	super._ready()
	# 特殊初始化
```

对应的派生 `.tscn` 可以挂载这个特殊脚本，但仍然继承 `UnitActor.tscn` 的公共结构。

## 与“每个单位一个独立场景”的对比

### 统一 `UnitActor.tscn` 的优点

- 维护成本低，公共结构和公共逻辑只改一处。
- 更符合当前项目中 `DataRepo`、`scene_key` 和 `setup_from_cfg` 的数据驱动设计。
- 新增单位主要改 JSON 和少量资源，适合快速扩展。
- 减少场景结构漂移，避免不同单位节点命名和挂点不一致。

### 统一 `UnitActor.tscn` 的风险

- 如果强行把所有行为都塞进 JSON，会导致配置表复杂化。
- 如果公共场景预留挂点不足，特殊表现会变得难接入。

解决方式是保留脚本组件和继承场景，不追求完全 JSON 化。

### 每个单位独立场景的优点

- 编辑器中直观，适合美术直接摆节点和预览效果。
- 对非常特殊的单位更自由。

### 每个单位独立场景的风险

- 容易复制公共节点，后续统一修改困难。
- 单位数量增加后，场景维护、注册、检查成本上升。
- 公共节点、脚本、命名、信号容易出现不一致。

## 最终建议

1. 默认所有普通单位使用 `scene_key: unit_actor`。
2. 单位数值、范围、技能参数、资源 key 放在 `data/units.json`。
3. 技能行为使用 `UnitSkillBehavior` 子类实现，通过配置 key 或挂点接入。
4. `UnitActor.tscn` 预留 `VisualRoot`、`AudioRoot`、`EffectRoot`、`SkillBehavior` 等差异化挂点。
5. 真正特殊的单位可以有专用 `.tscn`，但必须继承 `UnitActor.tscn`。
6. 只有核心行为也特殊时，才写继承自 `unit_actor.gd` 的派生脚本。

这套方案可以兼顾数据驱动、编辑器可视化配置和特殊单位扩展能力，同时避免公共结构在多个单位场景之间失控。
