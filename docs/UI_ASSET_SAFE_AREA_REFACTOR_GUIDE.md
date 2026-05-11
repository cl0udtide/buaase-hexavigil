# UI Asset Safe Area Refactor Guide

本文档用于指导 Agent 解决当前 UI 资产接入中的两个核心问题：

1. 场景中仍显示默认灰框，实际运行时才由 gd 脚本替换为素材，导致编辑器里无法所见即所得。
2. 生成素材普遍带有轻边框，内容安全区没有被系统化管理，导致文字、数字、图标容易压到边框或遮罩上。

目标是把 UI 资产变成可编辑、可检查、可复用的组件规格：场景里能看到真实素材，内容永远放在安全区内，遮罩层按照语义放在正确层级。

## 1. 总目标

### 1.1 场景里必须可见真实素材

最终 UI 不应依赖 `_ready()` 中批量 `add_theme_stylebox_override()` 才变成正式外观。

对于已经固定在场景树中的 UI 节点，素材和安全边距应尽量直接序列化在场景或 `.tres` 样式资源中，让 Godot 编辑器打开场景时就能看到接近运行时的外观。

脚本允许继续处理：

- 动态列表项创建后应用样式。
- 数据驱动的图标、文本、进度值。
- hover、selected、disabled、cooldown 等状态切换。
- 动态生成节点的 fallback 样式。

脚本不应继续处理：

- 已固定场景节点的基础底板外观。
- 已固定场景节点的内容安全 margin。
- 仅为了替换默认灰框而做的 `_apply_visual_style()` 样式赋值。

### 1.2 每个 frame 资产都有内容安全区

所有带边框、纹理边、阴影、角饰的 frame 资产必须定义两个概念：

- `texture_margin`：九宫格切分边距，用于保护边框不被拉伸变形。
- `content_margin`：内容安全边距，用于保证文字、图标、按钮不压到边框。

`content_margin` 必须大于或等于视觉边框厚度，并额外留出 2-6 px 的呼吸空间。

禁止通过负 margin 把内容压回边框区域。当前若看到类似 `Vector4(0.0, -2.0, 0.0, -2.0)` 的补偿，需要重新评估并改成扩大容器或调整 Slot，而不是挤压安全区。

### 1.3 遮罩层必须按语义分层

不要把所有 overlay 都当成“盖在最顶层的透明图”。遮罩分四类：

| 类型 | 作用 | 推荐层级 | 是否可盖住文字 |
| --- | --- | --- | --- |
| 底板状态层 | 表示卡片/按钮处于某种状态，但仍要读内容 | `Base` 之上、`Content` 之下，或低透明度顶层 | 不应影响文字可读性 |
| 边缘高亮层 | 表示选中、hover、可拖拽 | 可在 `Content` 之上，但必须主要影响边缘 | 不应覆盖正文区域 |
| 全面遮罩层 | 表示冷却、禁用、锁定 | `Content` 之上，提示文字/图标之下 | 可以压暗内容，但提示必须在其上方 |
| 局部遮罩层 | 只服务某个局部区域，如底栏、徽标、按钮 | 只覆盖对应局部节点 | 不得铺满整个面板 |

所有装饰层、frame、overlay、TextureRect 默认 `mouse_filter = IGNORE`。只有真正需要交互的根节点或按钮可以接收鼠标事件。

## 2. 推荐实现架构

### 2.1 建立序列化样式资源

建议新增目录：

```text
assets/ui/styles/
```

为常用 frame 资产创建 `.tres` 样式资源，例如：

```text
assets/ui/styles/frame_bottom_deploy_rail_base.tres
assets/ui/styles/frame_operator_card_base.tres
assets/ui/styles/frame_operator_card_selected_overlay.tres
assets/ui/styles/frame_operator_card_cooldown_overlay.tres
assets/ui/styles/frame_right_detail_sidebar_base.tres
assets/ui/styles/frame_button_base.tres
```

每个 `.tres` 是 `StyleBoxTexture`，应包含：

- `texture = res://assets/ui/generated/<asset>.png`
- `texture_margin_left/top/right/bottom`
- `content_margin_left/top/right/bottom`
- `draw_center`
- 必要时的 `modulate_color`

这些 `.tres` 资源应直接挂在场景节点的 theme override 上。这样打开 `.tscn` 时就能看到真实素材和真实内容边距。

`UiFrameSpec.gd` 可以继续作为安全区规格表，但不应成为固定场景节点唯一的运行时样式来源。推荐让 Agent 写一个一次性 Godot 工具脚本，从 `UiFrameSpec.SPECS` 生成或更新 `.tres`，然后把 `.tres` 应用到场景。

### 2.2 固定场景节点优先使用 `PanelContainer`

对于本身承载内容的面板，优先结构：

```text
PanelContainer
└─ ContentRoot
```

`PanelContainer` 的 stylebox content margin 会自然保护内容区。

如果现有场景已经是 `Panel + MarginContainer`，可以先保留结构，但必须满足：

```text
PanelRoot
├─ PanelBase          # 只显示素材底板，mouse_filter = IGNORE
└─ ContentMargin      # margin 写在场景中，值来自该素材 content_margin
   └─ ContentRoot
```

不要让 `ContentRoot` 与 `PanelBase` 平级但没有安全 margin。

### 2.3 动态节点使用统一 helper

动态创建的卡片、按钮、遗物项、资源项可以继续在脚本中应用样式，但必须通过统一接口：

- `UiFrameSpec.content_insets(component)`
- `UiFrameSpec.style_box(component, ...)`
- `GameUiStyle.apply_frame_margin(container, component, extra)`
- 或新的 `GameUiStyle.apply_surface(surface_node, margin_node, component)`

禁止每个脚本自己写一套硬编码安全边距。

### 2.4 素材分类与用法

| 资产类型 | 典型名称 | 正确用法 |
| --- | --- | --- |
| `frame_*_base` | `frame_bottom_deploy_rail_base` | 面板/卡片/按钮底板，提供安全内容区 |
| `frame_*_backplate` | `frame_operator_portrait_backplate` | 图标或头像下面的局部底板 |
| `frame_*_frame` | `frame_operator_portrait_frame` | 覆盖在头像/图标上方，只服务局部 |
| `frame_*_overlay` | `frame_operator_card_selected_overlay` | 状态层，按语义决定局部或全局 |
| `bar_progress_track` | 血条/SP/核心底轨 | 进度条底轨 |
| `bar_progress_fill_*` | HP/SP/Core fill | 只改变宽度，不做面板背景 |
| `icon_*` | 资源、技能、遗物图标 | TextureRect/Icon，不当底板 |

## 3. 需要优先处理的 UI 分块

### 3.1 底部部署栏与干员卡

文件：

- `scenes/ui/combat/CombatHud.tscn`
- `scenes/ui/combat/OperatorCard.tscn`
- `scripts/ui/combat/combat_hud.gd`
- `scripts/ui/combat/operator_card.gd`

目标结构：

```text
DeployDeck
├─ DeployRailBase                  # frame_bottom_deploy_rail_base
└─ DeckMargin                      # 使用 FRAME_DECK_PANEL content margin
   └─ ScrollContainer
      └─ DeployDeckContainer
```

`DeckMargin` 必须避开底栏边框。干员卡不得压到底栏边框。

`OperatorCard` 推荐层级：

```text
OperatorCard
├─ CardBase                         # frame_operator_card_base
├─ CardContentMargin                # 使用 OPERATOR_CARD 安全区
│  └─ CardContent
│     ├─ TitleStrip
│     ├─ PortraitStack
│     │  ├─ PortraitBackplate
│     │  ├─ PortraitTexture / PortraitLabel
│     │  └─ PortraitFrame
│     ├─ MetaRow
│     └─ StatRows
├─ DeployedOverlay                  # 轻量状态，不压暗正文
├─ SelectedOverlay                  # 轻量边缘高亮
├─ CooldownOverlay                  # 全卡冷却遮罩
├─ CooldownSelectedOverlay          # 冷却且选中，二选一显示
└─ CooldownTopContent               # 冷却数字/图标，必须高于遮罩
```

规则：

- `CooldownOverlay` 与 `CooldownSelectedOverlay` 不要同时显示。
- `SelectedOverlay` 如果是边缘高亮，可以在内容之上；如果素材中心明显染色，则改为低透明度或放到内容之下。
- `DeployedOverlay` 不应盖住 HP/SP/CD 文本。
- 头像必须是 `Backplate -> Texture/Label -> Frame`。

### 3.2 顶部 HUD 与设置面板

文件：

- `scenes/ui/combat/CombatHud.tscn`
- `scripts/ui/combat/combat_hud.gd`
- `scripts/ui/audio_settings_button.gd`
- `scripts/ui/audio_settings_panel.gd`

目标：

- `TopBar`、`ResourceItem`、`SpeedToggle`、`SettingsPanel` 在场景中显示真实素材。
- 资源项内容不压在 `frame_resource_item_base` 边框上。
- `SpeedActiveOverlay` 只覆盖当前激活按钮槽位，不铺满整个 `TimeControls`。
- `ResourceDeltaBadge` 只覆盖资源项中的小徽标区域。
- 核心血条使用 `bar_progress_track` 和 `bar_progress_fill_core`，fill 只按比例改变宽度。

### 3.3 左侧建筑/商店与 ActionPanel

文件：

- `scenes/ui/BuildPanel.tscn`
- `scenes/ui/BuildListCard.tscn`
- `scenes/ui/ActionPanel.tscn`
- `scripts/ui/build_panel.gd`
- `scripts/ui/build_list_card.gd`
- `scripts/ui/action_panel.gd`

目标：

- `BuildPanel` 底板、tab、建筑卡、成本徽标、图标 backplate/frame 在场景或可复用资源中真实可见。
- 建筑卡的 `SelectedOverlay` 以边缘或轻 tint 表示选中，不压住文字。
- `DisabledOverlay` 可以全卡遮罩，但要保证禁用原因/价格仍可读。
- `ActionPanel` 按钮底板不要挤压按钮文本，按钮图标与文字要落在安全区。

### 3.4 右侧详情、敌情、图例

文件：

- `scenes/ui/combat/UnitDetailPanel.tscn`
- `scenes/ui/combat/CombatHud.tscn`
- `scripts/ui/combat/unit_detail_panel.gd`
- `scripts/ui/combat/combat_hud.gd`

目标：

- `UnitDetailPanel/PanelBase` 只做底板，`ContentMargin` 必须避开边框。
- `HeaderStrip`、`DetailSectionBase`、`StatRow`、`SkillDescBox` 都有独立安全区。
- 头像和技能图标必须是 `Backplate -> Texture/Label -> Frame`。
- `WavePreviewPanel` 的敌人行、警告行、路线开关如果有对应资产，应作为局部底板，不得直接覆盖整块面板内容。
- `LegendRow` 内容要在行底板安全区内。

### 3.5 遗物与祝福

文件：

- `scenes/ui/relic/RelicStrip.tscn`
- `scenes/ui/relic/RelicIcon.tscn`
- `scenes/ui/relic/RelicPanel.tscn`
- `scenes/ui/relic/RelicCard.tscn`
- `scenes/ui/BlessingPanel.tscn`
- `scripts/ui/relic/**`
- `scripts/ui/blessing_panel.gd`

目标：

- `RarityOverlay` 不应压住名称和描述。它更适合作为底板上方的低透明 tint，或作为图标/卡边缘状态。
- `HoverOverlay` 可以顶层显示，但必须透明且 `mouse_filter = IGNORE`。
- `RelicIcon` 必须是 `IconBackplate -> IconTexture/Label -> IconFrame -> Rarity/New overlays`。
- `BlessingPanel` 复用 `RelicCard` 时不得把祝福候选卡的 selected/hover 遮罩叠得过厚。

### 3.6 弹窗、对话、结算

文件：

- `scenes/ui/EventPanel.tscn`
- `scenes/ui/DialogPanel.tscn`
- `scenes/ui/ResultPanel.tscn`
- `scripts/ui/event_panel.gd`
- `scripts/ui/dialog_panel.gd`
- `scripts/ui/result_panel.gd`
- `scripts/ui/map_interaction_popup.gd`

目标：

- 弹窗大背景遮罩与面板底板分离。
- `DialogPanel/TextBox` 有安全内容区，文字不压边框。
- `SpeakerPlate` 只承载说话人名字，不应用作整块文本遮罩。
- `MapInteractionPopup` 可继续跟随鼠标，但面板内容应在 `frame_map_popup_base` 安全区内。

## 4. 安全区规格建议

现有 `UiFrameSpec.SPECS` 已经有部分 `content` 值，但需要审计并补齐。建议按下列原则调整：

| 组件 | 建议 content margin |
| --- | --- |
| 大面板，如 `BUILD_SIDE_PANEL`、`RIGHT_DETAIL_SIDEBAR`、`RELIC_PANEL` | 18-24 px |
| 底部部署栏 `DECK_PANEL` | left/right 24-32 px，top/bottom 12-18 px |
| 卡片 `OPERATOR_CARD`、`RELIC_CARD`、`LIST_CARD` | 10-14 px |
| 小按钮 `BUTTON`、`ACTION_BUTTON`、`TAB` | left/right 10-14 px，top/bottom 6-8 px |
| 头像/图标 backplate/frame | 4-8 px |
| 徽标 `COST_BADGE`、`RESOURCE_DELTA_BADGE` | 4-6 px |
| 进度条 track/fill | 0 px content margin，使用外层容器控制位置 |

如果素材边框较厚，应优先扩大 content margin，而不是缩小字体或让文本贴边。

## 5. 推荐 Agent 执行顺序

1. 从 `dev` 签出新分支。
2. 审计指定 UI 分块的场景节点：
   - 哪些节点打开场景时仍是默认灰框。
   - 哪些节点只有运行时脚本才会应用素材。
   - 哪些文字/图标压在边框上。
   - 哪些 overlay 盖错范围或层级。
3. 为该分块相关 frame 资产建立或补齐 `.tres` `StyleBoxTexture`。
4. 将固定场景节点的基础底板样式和 content margin 写入场景。
5. 将脚本中的固定节点样式赋值降级：
   - 如果场景已序列化样式，脚本不要重复覆盖。
   - 动态节点仍可通过 helper 应用样式。
6. 调整遮罩层级和 `mouse_filter`。
7. 运行 Godot 校验和 rg 审计。
8. 报告仍需人工目视微调的节点。

## 6. 验收标准

打开相关 `.tscn`，应能直接看到真实 UI 素材，而不是默认灰框。

运行时不应出现：

- 文字压在 frame 边框上。
- 图标被头像框或按钮框裁掉。
- overlay 挡住按钮点击。
- cooldown/selected/deployed 等状态层同时叠加过厚。
- frame 资产被当普通图标使用。
- icon 资产被当面板底板使用。
- 进度条 fill 拉伸成整块面板背景。

命令：

```powershell
godot --headless --editor --quit --path .
```

```powershell
rg "add_theme_stylebox_override|apply_frame_margin" scripts/ui
```

上面的结果不要求清零，但每处都必须属于以下情况之一：

- 动态创建节点的样式。
- 状态切换样式，如 hover/selected/disabled。
- 临时 fallback，且场景中固定节点已经有真实样式。
- 公共控件 helper。

```powershell
rg "mouse_filter = 0" scenes/ui
```

所有装饰层、overlay、TextureRect 若仍是 `mouse_filter = STOP`，必须解释或修复。

## 7. 可直接给 Agent 的通用提示词

```text
请从最新 dev 分支签出新分支，针对指定 UI 分块完成“真实素材可视化 + 内容安全区 + 遮罩层级”重构。

目标 UI 分块：<填写 bottom_deploy_operator / top_hud_settings / build_action_panel / right_tactical_column / relic_blessing_ui / modal_popup_ui>

前置流程：
1. 阅读 README.md 的 Git 协作规范。
2. 从最新 dev 签出新分支：
   - git status --short
   - 如果工作区不干净，先停止并报告
   - git fetch origin
   - git checkout dev
   - git pull --ff-only origin dev
   - git checkout -b style/ui-safe-area-<目标 UI 分块>
3. 阅读：
   - docs/UI_SYSTEM.md
   - docs/UI_ASSET_SAFE_AREA_REFACTOR_GUIDE.md
   - docs/UI_ASSET_GENERATION_PROMPTS.md
4. 不要修改 assets/raw/，不要引用 source_sheet_*.png。

核心目标：
当前很多 UI 场景里是默认灰框，运行时才由 gd 脚本替换为素材。请将指定分块的固定 UI 节点改为场景中可见真实素材，并为所有带边框素材建立正确内容安全区，避免文字/数字/图标压到边框。同时审计并修复 selected/hover/cooldown/deployed/rarity/disabled 等遮罩层的层级、范围、透明度和鼠标穿透。

要求：
1. 固定场景节点的基础底板样式应序列化在场景或 .tres StyleBoxTexture 中，打开 .tscn 时就能看到真实素材。
2. 每个 frame 资产必须有 texture_margin 和 content_margin。
3. 内容必须位于安全区内；不得用负 margin 把内容挤到边框上。
4. 底板、内容、frame、overlay、提示文字/图标必须按语义分层。
5. overlay、frame、TextureRect 默认 mouse_filter = IGNORE。
6. 脚本只保留动态节点样式、状态切换、数据绑定、进度值、显隐逻辑。
7. 不要重构业务逻辑，不要改 EventBus 接口，不要改变部署/购买/技能/撤退行为。
8. 如果必须修改 GameUiStyle、UiFrameSpec、UiArtRegistry，必须说明影响范围。

指定分块范围：
- bottom_deploy_operator：
  - CombatHud.tscn 中 DeployDeck
  - OperatorCard.tscn
  - combat_hud.gd
  - operator_card.gd
- top_hud_settings：
  - CombatHud.tscn 顶部 HUD、资源项、核心血条、速度按钮
  - AudioSettingsPanel
  - audio_settings_button.gd / audio_settings_panel.gd
- build_action_panel：
  - BuildPanel.tscn
  - BuildListCard.tscn
  - ActionPanel.tscn
  - build_panel.gd / build_list_card.gd / action_panel.gd
- right_tactical_column：
  - UnitDetailPanel.tscn
  - CombatHud.tscn 中 WavePreviewPanel / LegendPanel
  - unit_detail_panel.gd / combat_hud.gd
- relic_blessing_ui：
  - RelicStrip / RelicIcon / RelicPanel / RelicCard / BlessingPanel
  - scripts/ui/relic/** / blessing_panel.gd
- modal_popup_ui：
  - EventPanel / DialogPanel / ResultPanel / MapInteractionPopup
  - event_panel.gd / dialog_panel.gd / result_panel.gd / map_interaction_popup.gd

执行步骤：
1. 审计该分块当前所有底板、frame、overlay、TextureRect、MarginContainer。
2. 列出哪些节点仍在编辑器显示默认灰框。
3. 列出哪些节点只在 _ready() 或 _apply_visual_style() 中被替换成素材。
4. 列出文字/图标可能压边框的节点。
5. 建立或补齐相关 .tres StyleBoxTexture，并设置九宫格边距与内容安全边距。
6. 将固定节点的样式和 margin 写入场景。
7. 移除该分块中固定节点重复的运行时基础样式覆盖；保留动态节点和状态样式。
8. 修复 overlay 层级、透明度、mouse_filter。
9. 运行 Godot 校验。

验收：
1. 打开相关场景能看到真实素材，不是默认灰框。
2. 文本、数字、图标都在安全区内，不压边框。
3. overlay 不拦截鼠标。
4. cooldown/selected/deployed/hover/rarity/disabled 等遮罩语义正确，不乱叠。
5. 运行：
   godot --headless --editor --quit --path .
6. 运行：
   rg "assets/raw|source_sheet" scenes scripts data
   scenes/scripts/data 不应引用 raw 源图。
7. 运行：
   rg "add_theme_stylebox_override|apply_frame_margin" scripts/ui
   对指定分块中剩余结果逐项说明：动态节点、状态切换、fallback 或待后续处理。

完成后提交：
style(UI): 规范<目标 UI 分块>素材安全区

最终报告包含：
- 新分支名
- 目标 UI 分块
- 修改的场景/脚本/样式资源
- 新增或调整的 content_margin / texture_margin
- 修复的遮罩层级问题
- 仍保留的运行时样式覆盖及原因
- Godot CLI 验证结果
```
