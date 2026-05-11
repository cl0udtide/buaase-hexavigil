# UI Layout Slot Refactor Guide

本文档用于指导 Agent 将当前 UI 顶层布局从脚本硬编码迁移到 Godot 场景树。目标不是再整理一批常数，而是让 1920x1080 下的 UI 位置能够在编辑器里所见即所得地调整。

当前项目只支持 `1920x1080`。不要实现移动端、小屏、宽屏响应式；不要保留一套场景定位、一套脚本定位的双重来源。

## 1. 核心原则

### 1.1 布局唯一来源

所有常驻 UI 顶层模块的位置、大小、锚点、边距必须由场景树中的 Slot 节点决定。

脚本不得在运行时设置这些模块或 Slot 的下列属性：

- `position`
- `size`
- `anchor_left`
- `anchor_top`
- `anchor_right`
- `anchor_bottom`
- `offset_left`
- `offset_top`
- `offset_right`
- `offset_bottom`

受此规则约束的模块包括：

- `ActionPanel`
- `BuildPanel`
- `CombatHud`
- `SettingsButton`
- `TopBar`
- `RelicStrip`
- `WavePreviewPanel`
- `UnitDetailPanel`
- `LegendPanel`
- `DeployDeck`
- `AudioSettingsPanel`
- `RelicPanel`
- `EventPanel`
- `BlessingPanel`
- `ResultPanel`

### 1.2 脚本职责

UI 脚本只负责：

- 绑定数据
- 刷新文本、数值、图标、进度值
- 控制显隐
- 刷新动态列表内容
- 转发信号
- 播放状态 overlay
- 处理真正依赖鼠标、进度比例或内容尺寸的动态位置

脚本不得负责常驻 HUD 模块的静态屏幕坐标。

### 1.3 允许的动态几何例外

以下位置或尺寸允许由脚本动态计算，因为它们本质上不是静态 HUD 布局：

| 对象 | 允许原因 | 当前相关代码 |
| --- | --- | --- |
| `DragGhost` | 跟随鼠标拖拽 | `CombatHud.move_drag_ghost()` |
| `MapInteractionPopup` | 出现在鼠标附近，并避开屏幕边缘 | `map_interaction_popup.gd::_show_near_mouse()` |
| 进度条 fill | 宽度由生命/SP/核心血量比例决定 | `CombatHud._refresh_core_fill()`、`UnitDetailPanel._set_bar_fill()` |
| 演员头顶血条/SP 条 | 跟随世界对象绘制 | `actor_status_view.gd` |
| Tooltip | 跟随鼠标或目标节点 | Tooltip 相关逻辑 |
| 动态列表项数量 | 数据决定子节点数量，不决定面板屏幕坐标 | 干员卡、遗物卡、商店卡、资源项数据刷新 |
| 弹窗内容高度 | 文本长度和列表数量决定内部滚动区域 | `RelicPanel`、`MapInteractionPopup` |

除此以外，脚本中出现顶层 UI `Rect2`、`offset_*`、`anchor_*`、`position =`、`size =` 都应视为需要解释或迁移。

## 2. 当前布局现状调查

调查基于当前分支 `feature/top-hud-detail-polish`。主要问题是：场景里已经有部分 offset，但运行时又被脚本覆盖。

### 2.1 `Game.tscn`

`Game.tscn` 当前结构：

```text
Game
├─ World
├─ Managers
└─ UI (CanvasLayer)
   ├─ ActionPanel
   ├─ BuildPanel
   ├─ CombatHud
   ├─ CombatHudController
   ├─ MapInteractionPopup
   ├─ EventPanel
   ├─ BlessingPanel
   └─ ResultPanel
```

当前场景中已经给了一些位置：

| 节点 | 当前场景位置 | 问题 |
| --- | --- | --- |
| `UI/ActionPanel` | 左下角 offset，约 `x=8 y=1004 w=310 h=64` | `action_panel.gd::_apply_responsive_layout()` 运行时覆盖 |
| `UI/BuildPanel` | 左侧 offset，约 `x=12 y=88 w=314 h=992` | `build_panel.gd::_apply_responsive_layout()` 运行时覆盖 |
| `UI/CombatHud` | full rect | 合理，但 `CombatHud` 内部继续用脚本定位 |
| `UI/MapInteractionPopup` | 初始小尺寸 | 鼠标附近弹窗，允许动态定位 |
| `UI/EventPanel` | 有实例 offset | `event_panel.gd::_place_centered()` 运行时覆盖 |
| `UI/BlessingPanel` | 有实例 offset | `blessing_panel.gd::_place_centered()` 运行时覆盖 |
| `UI/ResultPanel` | full rect，内部 `CenterContainer` | 合理 |

`Game.tscn` 应引入统一 Slot 根节点，避免 `ActionPanel`、`BuildPanel`、弹窗面板直接挂在 `UI` 下自行定位。

### 2.2 `CombatHud.tscn`

当前 `CombatHud` 结构：

```text
CombatHud
├─ HudChromeLayer
│  ├─ SettingsButton
│  ├─ TopBar
│  ├─ RelicStrip
│  ├─ WavePreviewPanel
│  ├─ DeployDeck
│  ├─ UnitDetailPanel
│  └─ LegendPanel
├─ InteractionLayer
│  └─ DragGhost
├─ PopupLayer
│  ├─ RelicPanel
│  └─ AudioSettingsPanel
└─ TooltipLayer
```

这些常驻节点目前是 `HudChromeLayer` 的直接子节点，但没有可视化 Slot。它们的屏幕位置由 `combat_hud.gd::_apply_responsive_layout()` 写入。

当前被脚本定位的节点：

- `%SettingsButton`
- `%AudioSettingsPanel`
- `%TopBar`
- `%RelicStrip`
- `%RelicPanel`
- `%DeployDeck`
- `%WavePreviewPanel`
- `%UnitDetailPanel`
- `%LegendPanel`

当前关键脚本问题：

| 文件 | 问题 |
| --- | --- |
| `scripts/ui/ui_layout_rules.gd` | 计算整套 HUD 顶层 `Rect2`，是静态布局的脚本来源 |
| `scripts/ui/combat/combat_hud.gd::_apply_responsive_layout()` | 把 `UiLayoutRules.hud_profile()` 的结果写回所有顶层 HUD 节点 |
| `scripts/ui/combat/combat_hud.gd::_place_control()` | 通用 offset 写入函数，应删除 |
| `scripts/ui/combat/combat_hud.gd::_place_wave_preview_and_detail()` | 动态计算右侧波次、详情、图例区域，应迁为 `RightColumnSlot + VBoxContainer` |
| `scripts/ui/combat/combat_hud.gd::_apply_top_bar_density()` | 根据宽度修改顶部卡片宽高；当前只支持 1920，应迁到场景 |
| `scripts/ui/combat/combat_hud.gd::_ensure_top_bar_groups()` | 运行时创建并重排 `LeftStatusGroup`、`CenterTimeGroup`、`RightResourceGroup`，应迁到场景 |
| `scripts/ui/combat/combat_hud.gd::_build_resource_items()` | 运行时创建固定 5 个资源项，建议迁到场景固定节点 |
| `scripts/ui/combat/combat_hud_controller.gd::_refresh_hud_reserved_width()` | 读取 `BuildPanel` / `ActionPanel` 宽度后影响底部卡组位置，应删除 |

### 2.3 `BuildPanel.tscn`

`BuildPanel` 内部已经主要使用 `VBoxContainer`、`ScrollContainer`、`Button` 等容器结构。内部局部布局可以保留。

必须修改的是根节点位置来源：

- 删除 `build_panel.gd` 中 `UiLayoutRules` preload。
- 删除 `get_viewport().size_changed.connect(_apply_responsive_layout)`。
- 删除 `_apply_responsive_layout()` 或改成空的兼容函数。
- 根节点的屏幕位置由 `Game.tscn` 中的 `BuildPanelSlot` 控制。

### 2.4 `ActionPanel.tscn`

`ActionPanel` 内部也是容器布局。必须修改的是根节点位置来源：

- 删除 `action_panel.gd` 中 `UiLayoutRules` preload。
- 删除 `get_viewport().size_changed.connect(_apply_responsive_layout)`。
- 删除 `_apply_responsive_layout()` 或改成空的兼容函数。
- 根节点的屏幕位置由 `Game.tscn` 中的 `ActionPanelSlot` 控制。

### 2.5 `EventPanel` 与 `BlessingPanel`

当前 `event_panel.gd` 和 `blessing_panel.gd` 都有 `_place_centered()`，用脚本设置居中 offset。

这类静态居中也应迁到场景：

- 在 `Game.tscn` 的 `ModalLayer` 下创建 `EventPanelSlot` 和 `BlessingPanelSlot`。
- Slot 使用固定 1920x1080 坐标居中。
- 删除 `EventPanel._place_centered()` 和 `BlessingPanel._place_centered()` 的调用。
- 面板自身只负责内容和显隐。

### 2.6 `MapInteractionPopup`

`MapInteractionPopup` 是鼠标附近的上下文弹窗，允许动态定位。它应放在 `FloatingLayer` 下，脚本继续根据鼠标位置设置 `position` 和 `size`。

此例外必须在验收报告中单独归类，不能作为其他常驻 HUD 面板继续脚本定位的理由。

## 3. 目标场景结构

### 3.1 `Game.tscn` 目标结构

`UI` 下必须建立清晰层级，常驻 HUD 和弹窗分层：

```text
UI (CanvasLayer)
├─ ScreenLayout (Control, full rect 1920x1080)
│  ├─ BuildPanelSlot (Control)
│  │  └─ BuildPanel
│  ├─ ActionPanelSlot (Control)
│  │  └─ ActionPanel
│  └─ CombatHudSlot (Control)
│     └─ CombatHud
├─ FloatingLayer (Control, full rect 1920x1080)
│  └─ MapInteractionPopup
├─ ModalLayer (Control, full rect 1920x1080)
│  ├─ EventPanelSlot (Control)
│  │  └─ EventPanel
│  ├─ BlessingPanelSlot (Control)
│  │  └─ BlessingPanel
│  └─ ResultPanelSlot (Control)
│     └─ ResultPanel
└─ CombatHudController (Node)
```

`CombatHudController` 是非可视节点，不放进任何 Slot。移动节点后必须更新 controller 的节点路径。推荐把路径改成 `@export_node_path`，并提供当前场景默认值，避免以后再次改层级时要搜脚本。

### 3.2 `Game.tscn` 固定 Slot 坐标

所有 Slot 使用 `anchors_preset = 0` 或等价固定锚点，坐标按 1920x1080 写在场景里。

| Slot | 位置与尺寸 |
| --- | --- |
| `ScreenLayout` | full rect |
| `CombatHudSlot` | `x=0 y=0 w=1920 h=1080` |
| `BuildPanelSlot` | `x=14 y=152 w=320 h=826` |
| `ActionPanelSlot` | `x=14 y=990 w=318 h=76` |
| `FloatingLayer` | full rect |
| `ModalLayer` | full rect |
| `EventPanelSlot` | `x=690 y=410 w=540 h=260` |
| `BlessingPanelSlot` | `x=660 y=350 w=600 h=380` |
| `ResultPanelSlot` | full rect，因为 `ResultPanel` 自带 backdrop 与 `CenterContainer` |

`MapInteractionPopup` 不使用固定 Slot 坐标；它是鼠标动态弹窗。

### 3.3 `CombatHud.tscn` 目标结构

`CombatHud` 继续 full rect，但 `HudChromeLayer` 下不能再直接散放顶层模块。必须加入 Slot：

```text
CombatHud
├─ HudChromeLayer (Control, full rect)
│  ├─ SettingsButtonSlot
│  │  └─ SettingsButton
│  ├─ TopHudSlot
│  │  └─ TopBar
│  │     └─ TopContent
│  │        └─ TopContentRow
│  │           ├─ LeftStatusGroup
│  │           │  ├─ StageChip
│  │           │  ├─ CoreChip
│  │           │  ├─ DeployChip
│  │           │  └─ MessageChip
│  │           ├─ CenterTimeGroup
│  │           │  └─ TimeControls
│  │           └─ RightResourceGroup
│  │              └─ ResourceChip
│  │                 └─ ResourceItemsRow
│  │                    ├─ ActionPointResourceItem
│  │                    ├─ WoodResourceItem
│  │                    ├─ StoneResourceItem
│  │                    ├─ ManaResourceItem
│  │                    └─ PrestigeResourceItem
│  ├─ RelicStripSlot
│  │  └─ RelicStrip
│  ├─ RightColumnSlot
│  │  └─ RightColumnVBox
│  │     ├─ WavePreviewPanel
│  │     ├─ UnitDetailPanel
│  │     └─ LegendPanel
│  └─ DeployDeckSlot
│     └─ DeployDeck
├─ InteractionLayer (Control, full rect)
│  └─ DragGhost
├─ PopupLayer (Control, full rect)
│  ├─ SettingsPanelSlot
│  │  └─ AudioSettingsPanel
│  └─ RelicPanelSlot
│     └─ RelicPanel
└─ TooltipLayer (Control, full rect)
```

注意：

- `SettingsButton`、`TopBar`、`RelicStrip`、`RightColumnVBox`、`DeployDeck`、`AudioSettingsPanel`、`RelicPanel` 的屏幕位置由其父 Slot 决定。
- `WavePreviewPanel`、`UnitDetailPanel`、`LegendPanel` 在 `RightColumnVBox` 内由容器自然排列。脚本只改 `visible`，不改坐标。
- `ResourceItemsRow` 和 5 个资源项是固定 HUD 结构，应在场景里存在。脚本只填 icon/value/delta。
- `LeftStatusGroup`、`CenterTimeGroup`、`RightResourceGroup` 必须在场景里存在。脚本不得运行时创建或 reparent。

### 3.4 `CombatHud.tscn` 固定 Slot 坐标

| Slot | 位置与尺寸 |
| --- | --- |
| `SettingsButtonSlot` | `x=14 y=8 w=44 h=44` |
| `TopHudSlot` | `x=66 y=8 w=1840 h=82` |
| `RelicStripSlot` | `x=66 y=96 w=1100 h=44` |
| `RightColumnSlot` | `x=1522 y=104 w=384 h=768` |
| `DeployDeckSlot` | `x=338 y=876 w=1568 h=190` |
| `SettingsPanelSlot` | `x=14 y=58 w=420 h=226` |
| `RelicPanelSlot` | `x=510 y=220 w=900 h=640` |
| `InteractionLayer` | full rect |
| `PopupLayer` | full rect |
| `TooltipLayer` | full rect |

`RightColumnVBox` 内建议：

- `WavePreviewPanel.custom_minimum_size.y = 156`
- `UnitDetailPanel.size_flags_vertical = EXPAND_FILL`
- `LegendPanel.custom_minimum_size.y = 144`
- `RightColumnVBox` separation 使用场景常量，例如 `8` 或 `12`
- 当 `WavePreviewPanel.visible = false` 时，容器自动释放空间
- 当 `UnitDetailPanel.visible = false` 时，`LegendPanel` 仍在底部区域可见

## 4. 必须删除或改造的脚本布局入口

### 4.1 `scripts/ui/ui_layout_rules.gd`

运行时代码不应再使用 `UiLayoutRules.hud_profile()` 或 `UiLayoutRules.top_card_widths()`。

处理方式二选一：

1. 删除 `ui_layout_rules.gd` 及其 `.uid`，同时删除所有 preload。
2. 保留文件但不被运行时代码引用，文件头标注仅用于旧布局参考。

推荐第 1 种，减少后续误用。

### 4.2 `scripts/ui/combat/combat_hud.gd`

必须删除或改造：

- `const UiLayoutRules = preload(...)`
- `_layout_profile`
- `_left_reserved_width`
- `_on_viewport_size_changed()` 中的布局调用
- `_apply_responsive_layout()`
- `_place_control()`
- `_place_wave_preview_and_detail()`
- `_apply_top_bar_density()`
- `_set_top_card_min()`
- `set_left_reserved_width()`
- `_ensure_top_bar_groups()` 的创建/reparent 行为
- `_build_resource_items()` 的固定资源项创建行为

保留或改造为数据绑定：

- `set_top_values()`
- `set_core_hp()`
- `set_resource_items()`
- `set_wave_preview()`
- `set_deploy_cards()`
- `show_unit_detail()` / `hide_unit_detail()` 类似接口
- `move_drag_ghost()`
- `_refresh_core_fill()`
- `_update_speed_active_overlay()`，但它只允许在 `TimeControls` 内移动选中 overlay，不允许影响顶层 HUD 坐标

顶部 HUD 的宽度、高度、资源项宽度、按钮高度、卡片分组 separation 应全部落在场景节点属性或主题常量上。当前只支持 1920x1080，不需要根据 viewport width 调整。

### 4.3 `scripts/ui/build_panel.gd`

必须删除或改造：

- `const UiLayoutRules = preload(...)`
- `get_viewport().size_changed.connect(_apply_responsive_layout)`
- `_apply_responsive_layout()`

保留：

- 建筑/商店列表刷新
- 卡片创建
- 选择与购买逻辑
- 内部按钮和图标样式

### 4.4 `scripts/ui/action_panel.gd`

必须删除或改造：

- `const UiLayoutRules = preload(...)`
- `get_viewport().size_changed.connect(_apply_responsive_layout)`
- `_apply_responsive_layout()`

保留：

- 当前模式显示
- 探索、入夜、修复、拆除、启停按钮逻辑
- 建筑上下文信息刷新

### 4.5 `scripts/ui/combat/combat_hud_controller.gd`

必须删除或改造：

- `_refresh_hud_reserved_width()`
- 对 `CombatHud.set_left_reserved_width()` 的调用
- 通过 `panel.position.x + panel.size.x` 影响其他 HUD 位置的逻辑

控制器可以继续读取 `ActionPanel`、`BuildPanel`、`CombatHud`，但只能用于数据与信号转接，不得以任何 UI 几何信息参与布局。

### 4.6 `scripts/ui/event_panel.gd`

必须删除或改造：

- `PANEL_SIZE`
- `_place_centered()`
- `_ready()` 和 `show_event()` 中对 `_place_centered()` 的调用

居中由 `Game.tscn/ModalLayer/EventPanelSlot` 完成。

### 4.7 `scripts/ui/blessing_panel.gd`

必须删除或改造：

- `PANEL_SIZE`
- `_place_centered()`
- `_ready()` 和 `show_choices()` 中对 `_place_centered()` 的调用

居中由 `Game.tscn/ModalLayer/BlessingPanelSlot` 完成。

## 5. 资源项与顶部 HUD 的细化要求

当前 `CombatHud` 会在脚本里动态创建固定 5 个资源项。由于资源种类固定，应该场景化。

必须在 `CombatHud.tscn` 中创建以下节点：

```text
ResourceChip
└─ ResourceItemsRow (HBoxContainer)
   ├─ ActionPointResourceItem
   │  ├─ ResourceItemBase
   │  └─ ItemMargin/ItemRow/IconTexture, IconLabel, ValueLabel, DeltaBadge/DeltaLabel
   ├─ WoodResourceItem
   ├─ StoneResourceItem
   ├─ ManaResourceItem
   └─ PrestigeResourceItem
```

脚本只做：

- 收集这些节点到 `_resource_item_controls`
- 根据数据设置 icon texture、value text、delta text
- 根据是否有 delta 控制 `DeltaBadge.visible`

脚本不得再 `Control.new()`、`Panel.new()`、`HBoxContainer.new()` 来创建固定资源项。

顶部三组也必须场景化：

```text
TopContentRow
├─ LeftStatusGroup
│  ├─ StageChip
│  ├─ CoreChip
│  ├─ DeployChip
│  └─ MessageChip
├─ CenterTimeGroup
│  └─ TimeControls
└─ RightResourceGroup
   └─ ResourceChip
```

脚本不得再运行时创建或移动这些组。

## 6. 动态列表的边界

以下列表仍允许脚本创建子项，因为数量来自数据：

- `DeployDeckContainer` 下的 `OperatorCard`
- `BuildCardList` 下的建筑卡和商店卡
- `RelicStrip/IconRow` 下的遗物小图标
- `RelicPanel/CardGrid` 下的遗物卡
- `BlessingPanel/ChoiceList` 下的候选遗物卡

但是，承载这些列表的面板、ScrollContainer、Slot 的屏幕位置必须来自场景。

## 7. Agent 执行顺序

1. 从最新 `dev` 签出新分支，建议分支名：

   ```text
   refactor/ui-layout-slots
   ```

2. 先不要改业务逻辑，先按本文档修改 `Game.tscn` 与 `CombatHud.tscn` 的 Slot 结构。

3. 移动节点后立即更新脚本中的 NodePath：

   - `CombatHudController` 对 `ActionPanel`、`BuildPanel`、`CombatHud` 的引用
   - `CombatHud` 对 `SettingsButton`、`TopBar`、`RelicStrip`、`DeployDeckContainer`、`UnitDetailPanel`、`LegendPanel`、`RelicPanel`、`AudioSettingsPanel` 的引用
   - 所有使用硬编码路径 `HudChromeLayer/...` 的 `get_node_or_null()` 调用

4. 迁移顶部组和资源项到场景。

5. 删除或改造第 4 节列出的脚本布局入口。

6. 运行 Godot 校验，修复节点路径和脚本错误。

7. 运行硬编码审计，按第 8 节分类剩余项。

8. 更新 `docs/UI_SYSTEM.md`，写明：

   - 当前只支持 1920x1080
   - 顶层布局由 `Game.tscn` 和 `CombatHud.tscn` Slot 控制
   - 脚本不得定位常驻 HUD 模块
   - 动态例外列表

## 8. 验收命令

Godot 加载校验：

```powershell
godot --headless --editor --quit --path .
```

运行时布局旧入口检查：

```powershell
rg "UiLayoutRules|hud_profile|top_card_widths|_apply_responsive_layout|_place_control|set_left_reserved_width|_refresh_hud_reserved_width" scripts/ui scenes/ui scenes/game/Game.tscn
```

期望结果：

- `scripts/ui/combat/combat_hud.gd`
- `scripts/ui/build_panel.gd`
- `scripts/ui/action_panel.gd`
- `scripts/ui/combat/combat_hud_controller.gd`

这些文件中不应再出现上述旧入口。

静态 HUD 坐标写入检查：

```powershell
rg "anchor_left|anchor_top|anchor_right|anchor_bottom|offset_left|offset_top|offset_right|offset_bottom|position =|size =" scripts/ui
```

剩余结果必须分类：

- 允许：`DragGhost`
- 允许：`MapInteractionPopup`
- 允许：进度条 fill
- 允许：演员头顶状态条
- 允许：图标在父控件内部居中
- 允许：动态文本内容高度
- 不允许：任何常驻 HUD 顶层面板、Slot 或弹窗静态居中

场景结构检查：

```powershell
rg "BuildPanelSlot|ActionPanelSlot|CombatHudSlot|SettingsButtonSlot|TopHudSlot|RelicStripSlot|RightColumnSlot|DeployDeckSlot|SettingsPanelSlot|RelicPanelSlot|EventPanelSlot|BlessingPanelSlot" scenes/game/Game.tscn scenes/ui/combat/CombatHud.tscn
```

这些 Slot 必须全部存在。

## 9. 最终人工检查

在 1920x1080 下检查：

- 移动 `Game.tscn/ScreenLayout/BuildPanelSlot` 后，左侧建筑/商店面板位置随之改变，运行时不会被脚本挪回。
- 移动 `Game.tscn/ScreenLayout/ActionPanelSlot` 后，白天操作面板位置随之改变，运行时不会被脚本挪回。
- 移动 `CombatHud.tscn/HudChromeLayer/TopHudSlot` 后，顶部 HUD 位置随之改变，运行时不会被脚本挪回。
- 移动 `CombatHud.tscn/HudChromeLayer/RightColumnSlot` 后，今晚敌情、单位详情、战场图例整体随之改变，运行时不会被脚本挪回。
- 移动 `CombatHud.tscn/HudChromeLayer/DeployDeckSlot` 后，底部干员卡组位置随之改变，运行时不会被脚本挪回。
- `MapInteractionPopup` 仍能出现在鼠标附近。
- `DragGhost` 仍能跟随鼠标。
- 核心血条、单位详情血条/SP 条仍按数值变化。
- 商店预览/购买、干员卡点击/拖拽、遗物面板、设置面板音量仍正常。

## 10. 提交要求

完成后提交：

```text
refactor(UI): 将UI顶层布局迁移到场景槽位
```

最终报告必须包含：

- 新分支名
- 修改的场景
- 修改的脚本
- 删除或停用的旧布局入口
- 剩余动态几何项及允许原因
- 硬编码审计结果
- Godot CLI 验证结果
