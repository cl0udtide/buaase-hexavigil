# UI Asset Remediation Guide

本文档只保留当前仍需要处理的 UI 资产任务。原问题 1「边缘背景残留和锯齿」与问题 2「青绿色廉价感/古早页游感」已经通过新一轮源图生成、`#FF00FF` 背景、裁剪脚本清理和低饱和战术奇幻风格约束解决，不再作为待办维护。

当前剩余任务：

1. 解决可缩放 UI 的边框拉伸问题，推荐方案 A：`StyleBoxTexture` 九宫格。
2. 对遗物 UI 进行微调。目前遗物 UI 尚未完成视觉微调，并且在实际界面中处于隐藏状态。

## 任务一：用 `StyleBoxTexture` 九宫格解决边框拉伸

### 问题

部分 `frame_*_base` 资产同时包含底座、边框、角部装饰和中心内容区域。如果直接把普通 PNG 放进 `TextureRect` 或普通拉伸控件中，整体缩放会导致：

- 角部装饰被横向或纵向拉扯，形状变形。
- 边框厚度随控件尺寸变化，时粗时细。
- 中心暗底纹理被不必要地拉伸，出现模糊或压缩感。
- 内容节点没有可靠的安全边距，文字、图标和按钮容易压到视觉边框上。

只把「底座」和「边框」拆成两张 PNG 并不能根治这个问题。如果边框 PNG 仍然被整体缩放，边框和角仍然会变形。正确做法是让 Godot 知道哪些像素是角、哪些像素是边、哪些像素是中心区域。

### 推荐方案 A：`StyleBoxTexture` 九宫格

`StyleBoxTexture` 把一张 UI 纹理切成九个区域：

```text
┌─────────┬───────────────┬─────────┐
│ 左上角  │ 上边          │ 右上角  │
├─────────┼───────────────┼─────────┤
│ 左边    │ 中心          │ 右边    │
├─────────┼───────────────┼─────────┤
│ 左下角  │ 下边          │ 右下角  │
└─────────┴───────────────┴─────────┘
```

缩放时：

- 四个角不拉伸，保持原始装饰比例。
- 上下边只横向拉伸或平铺，边框厚度不变。
- 左右边只纵向拉伸或平铺，边框厚度不变。
- 中心区域负责填充可变尺寸，可以拉伸或平铺。

这正好匹配面板、按钮、卡片、弹窗、tooltip、资源项、状态栏等矩形 UI 的需求。

### 资产设计要求

适合九宫格的 `frame_*_base.png` 应遵守：

- 四个角包含完整角部造型，不能把关键装饰跨越到会被拉伸的边区。
- 上下边的纹理可以横向延展，避免中间出现固定徽章、固定断点或不可重复图案。
- 左右边的纹理可以纵向延展，避免大面积不可重复侧饰。
- 中心区域保持干净，适合放运行时文字、数字、图标、头像、列表或按钮。
- 不要把固定数量的格子、固定文字、固定头像、固定按钮组烘进底图。

如果某个面板需要复杂非重复装饰，应优先把装饰限制在角部或固定尺寸 overlay 中；不要把复杂装饰放进会被拉伸的边区。

### Godot `.tres` 配置

每个可缩放的 `frame_*_base` 应对应一个 `StyleBoxTexture` `.tres`，例如：

```gdresource
[gd_resource type="StyleBoxTexture" format=3]

[ext_resource type="Texture2D" path="res://assets/ui/generated/frame_example_base.png" id="1_texture"]

[resource]
texture = ExtResource("1_texture")
texture_margin_left = 18.0
texture_margin_top = 18.0
texture_margin_right = 18.0
texture_margin_bottom = 18.0
content_margin_left = 16.0
content_margin_top = 12.0
content_margin_right = 16.0
content_margin_bottom = 12.0
```

关键字段：

- `texture_margin_left/top/right/bottom`：九宫格切分线。它保护边框和角部不被错误拉伸。
- `content_margin_left/top/right/bottom`：内容安全区。它保护文本、图标和按钮不压到边框。

设置原则：

- `texture_margin_*` 至少覆盖完整边框厚度和角部装饰。
- `content_margin_*` 通常大于或等于视觉边框厚度。
- 大面板的 content margin 可以更大，按钮和小徽章可以更紧。
- 同一类组件的 margin 应统一记录在 `.tres` 或 `UiFrameSpec` 中，避免场景里到处手调。

### 场景使用方式

固定面板优先使用：

```text
PanelContainer
└─ ContentRoot
```

或在需要更明确分层时使用：

```text
PanelRoot
├─ PanelBase        # Panel，theme_override_styles/panel 指向 StyleBoxTexture
└─ ContentMargin    # 内容节点；边距来自 StyleBoxTexture 或同步配置
   └─ ContentRoot
```

避免：

- 用 `TextureRect` 直接整体拉伸带边框 PNG。
- 用负 margin 把内容挤回边框区域。
- 为同一个可缩放面板额外叠一张完整边框 overlay，再对 overlay 整体缩放。

### 验收标准

- 在 1920x1080 和更小窗口下，面板边框粗细稳定。
- 四个角不变形，角部装饰不被压扁或拉长。
- 文本、图标、头像和按钮不压到视觉边框。
- 同一素材用于不同尺寸面板时，中心区域自然延展，边框仍然清晰。
- 可缩放 `frame_*_base` 均有对应 `.tres` 或等效 `GameUiStyle` / `UiFrameSpec` 配置。

## 任务二：遗物 UI 微调

### 当前状态

遗物 UI 已有基础资产和场景入口，但尚未进行完整视觉微调。当前界面中遗物面板/遗物列表处于隐藏或低使用状态，因此还没有经过实际截图验收。

需要重点检查的资源包括：

- `frame_relic_panel_base`
- `frame_relic_filter_tab_base`
- `frame_relic_filter_selected_overlay`
- `frame_relic_card_base`
- `frame_relic_card_hover_overlay`
- `frame_relic_icon_backplate`
- `frame_relic_icon_frame`
- `frame_relic_rarity_common_overlay`
- `frame_relic_rarity_uncommon_overlay`
- `frame_relic_rarity_rare_overlay`
- `icon_relic_*`
- `icon_filter_*`

### 调整目标

- 遗物面板应与当前 UI 家族一致：低饱和、暗色、轻盈、实用，带清新战术奇幻工艺感。
- 不要让遗物面板比作战 HUD 更厚重或更亮。
- 遗物卡片要能清楚区分普通、hover/选中、稀有度状态。
- 筛选标签要清晰，但不要像主导航一样抢视觉重心。
- 遗物图标应保持小尺寸可读，避免过度复杂或接近完整插画。

### 推荐检查顺序

1. 在 `CombatHud.tscn` 或相关遗物场景中临时显示遗物 UI，截取 1920x1080 预览。
2. 检查遗物面板与顶部 HUD、右侧详情栏、底部部署栏是否风格一致。
3. 检查 `frame_relic_panel_base` 是否适合作为 `StyleBoxTexture` 九宫格面板。
4. 检查遗物卡片是否有足够内容安全区，名称、描述、图标、稀有度 overlay 不压边。
5. 检查筛选 tab 的普通态与选中态是否清楚，但不过亮。
6. 检查 hover/selected overlay 是否只是状态层，不复制完整卡片底图。
7. 检查所有 `icon_relic_*` 在实际卡片尺寸内是否可读。

### 可能的修正项

- 若遗物面板边框拉伸变形，优先补齐 `StyleBoxTexture` 九宫格 margin。
- 若遗物卡片过亮，降低中心底色对比度，把高光限制在边缘。
- 若稀有度 overlay 太花，改为细边线、角标或轻量色带。
- 若筛选标签像按钮组一样拥挤，调整 tab 宽度、间距和 content margin。
- 若遗物图标和卡片边框抢视觉焦点，降低 icon 饱和度或缩小卡片边框装饰。

### 验收标准

- 遗物 UI 从隐藏状态打开后，不遮挡或压迫主要战斗信息。
- 面板、卡片、筛选标签和图标风格统一，但层级有区分。
- 普通态、hover/选中态、稀有度状态都能一眼识别。
- 所有可缩放遗物 frame 都通过 `StyleBoxTexture` 或等效方式保护边框。
- 遗物内容由 Godot 节点动态填充，PNG 中不烘固定文字、数字、图标列表或卡片数量。
