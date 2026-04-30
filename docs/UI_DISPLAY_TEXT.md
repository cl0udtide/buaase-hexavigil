# UI Display Text

## 1. 背景

当前 UI 显示文本来源混合存在：

- 配置表直接提供的显示字段，例如 `name`、`desc`、`icon_text`。
- UI 脚本本地维护的映射，例如职业、阶级、伤害类型、方向、阶段文本。
- `.tscn` 场景中的固定占位文本，例如按钮、空状态和默认标签。

这种混合方式能工作，但随着 UI 增多会带来重复映射和命名漂移。例如 `guard -> 近卫` 可能在多个脚本各写一遍；费用 `1/3/7 -> 一阶/二阶/三阶` 也可能和后续稀有度设计耦合不清。

目标是建立一个统一显示文本工具，集中处理“程序 key / 枚举 / 简单配置 -> UI 可读文本或占位图标”的转换。

---

## 2. 设计目标

- UI 脚本不再重复维护职业、阶级、伤害类型、方向、阶段等映射。
- 数据表已有的显示字段优先使用，例如 `name`、`desc`、`icon_text`。
- 数据表没有显示字段时，由统一工具提供稳定兜底。
- 统一工具只做显示转换，不读取或修改运行时真相数据。
- 后续接入真实图标资源时，保留 `icon_key` 到资源的扩展位置。

---

## 3. 建议文件

后续实现时建议新增：

```text
scripts/ui/ui_display_text.gd
```

建议类名：

```gdscript
class_name UiDisplayText
extends RefCounted
```

该工具属于 UI 层公共辅助，不属于 `DataRepo`、`RunState` 或任一玩法 Manager。

---

## 4. 数据优先级

### 4.1 名称与说明

名称和说明优先来自配置表：

```text
cfg.name
cfg.desc
cfg.skill_name
cfg.skill_description
```

统一工具只负责兜底，例如：

```text
空 name -> id
空 desc -> 暂无说明
空 skill_description -> 暂无技能描述
```

### 4.2 图标文本

当前阶段没有真实图标资源时，显示逻辑建议为：

```text
cfg.icon_text
-> 调用方传入的类型兜底图标字
-> cfg.name 的第一个字符
-> "*"
```

`icon_key` 保留给未来真实图标资源映射，不直接在 UI 脚本里拼路径。

其中 `fallback_text` 用于承载调用方已经知道的类型占位图标，例如单位职业图标“近/狙/术/重”。这样可以在单位名为“一阶近卫”“二阶狙击”等格式时继续保持原 UI 的职业占位图标表现；没有传入类型兜底时，才回退到 `name` 首字。

### 4.3 阶级与稀有度

当前商店用 `cost_prestige` 推导阶级：

```text
1 -> 一阶
3 -> 二阶
7 -> 三阶
其他 -> 特殊
```

该规则应集中在统一工具中，避免 UI 脚本散落重复逻辑。若后续单位表新增 `rarity` 或 `tier` 字段，则统一工具应优先使用显式字段，再回退到价格推导。

---

## 5. 建议接口

当前实现覆盖这些静态方法：

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

如果后续需要真实图标资源，可扩展：

```gdscript
static func icon_key(cfg: Dictionary) -> StringName
```

但资源加载本身建议另行放到资源仓库或主题资产工具中，避免显示文本工具承担资源生命周期。

---

## 6. 使用边界

统一显示文本工具负责：

- key 到中文标签的映射。
- 简单枚举到 UI 文案的映射。
- 配置显示字段的兜底。
- 占位图标文本的兜底。
- 阶级标签和阶级颜色的统一规则。

统一显示文本工具不负责：

- 加载 JSON 配置。
- 保存 UI 状态。
- 修改 `RunState`、地图、建筑、单位或商店状态。
- 实例化图标、贴图或场景。
- 决定建筑、单位是否可用或可见。

---

## 7. 迁移顺序

建议分阶段迁移，降低改动风险：

1. 已新增 `UiDisplayText`，迁移纯函数映射：职业、阶级、伤害类型、方向、阶段。
2. 已将 `BuildPanel` 中单位职业、阶级、阶级颜色、建筑/单位占位图标、配置名称和说明兜底改为调用工具。
3. 已将 `CombatHudController` 中职业、伤害类型、方向、阶段文本改为调用工具。
4. `UnitDetailPanel` 中默认技能说明兜底与标题格式仍可后续逐步收口。
5. 后续如数据表新增 `tier`、`rarity`、`icon_text`，由工具统一兼容旧字段和新字段。

迁移完成后，UI 脚本应更偏向“取数据、调用工具格式化、传给组件显示”，而不是在各自文件中维护重复映射。

---

## 8. 与现有数据字段的关系

- `name`：配置项主显示名，优先级最高。
- `desc`：配置项说明文本，优先级最高。
- `icon_key`：真实图标资源逻辑名，当前仅保留。
- `icon_text`：当前占位 UI 展示用单字图标。
- `cost_prestige`：当前用于商店费用和临时阶级推导。
- `class`：单位职业 key，由统一工具映射为中文职业名。
- `damage_type`：伤害类型 key 或枚举值，由统一工具映射为中文伤害名。

原则：**数据表表达对象自身的显示信息，统一工具表达跨 UI 复用的显示规则。**
