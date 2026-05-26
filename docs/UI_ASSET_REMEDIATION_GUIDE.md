# UI Asset Remediation Guide

本文档集中解决 Beta 阶段 UI 美术的三个核心问题：

1. UI 边缘有背景残留和锯齿。
2. UI 风格偏古早页游，青绿色廉价感明显。
3. UI 边框与底座烘在同一张 PNG 中，拉伸时边框粗细失控，也不好设置内容 margin。

结论先行：第三个问题不能只靠“把边框和底座拆成两张 PNG”解决。拆层只解决语义和状态管理；边框拉伸不变形要靠 Godot 的九宫格 `StyleBoxTexture`、分段边线，或程序化 `StyleBoxFlat`/shader。可缩放 UI 不应直接把普通边框 PNG 当 `TextureRect` 拉伸。

## 1. 文档收口

UI 文档保留三类：

- `docs/UI_SYSTEM.md`：总纲，记录目标风格、UI 层级、职责边界、资产语义和验收原则。
- `docs/UI_ASSET_GENERATION_PROMPTS.md`：提示词库，负责生成源图、命名和裁剪顺序。
- `docs/UI_ASSET_REMEDIATION_GUIDE.md`：本文，负责修复 Alpha 阶段 UI 资产质量问题和说明技术对策。

原来的 `UI_ASSET_SAFE_AREA_REFACTOR_GUIDE.md` 与 `UI_LAYOUT_SLOT_REFACTOR_GUIDE.md` 已被本文和 `UI_SYSTEM.md` 吸收，不再作为独立入口维护。

## 2. 问题一：背景残边与锯齿

### 2.1 根因

Alpha 资产使用了接近 UI 主色的青绿色背景。UI 本体也大量使用青绿、蓝绿、半透明发光和柔边，导致抠图时背景与主体边缘难以区分。结果是：

- 边缘留下青绿色 halo。
- 半透明光晕被错误保留或错误删除。
- 后续放到深色 HUD 上时残边特别明显。

### 2.2 新规则

- UI 源图背景统一使用高对比洋红 `#FF00FF`。
- UI 主体禁止使用接近 `#FF00FF` 的品红、紫红、粉紫边缘或柔光。
- 不再使用 `#79C7B6`、`#8AD1C1` 作为 UI 抠图背景。
- 背景必须是纯色平涂，不能有渐变、阴影、噪点、假透明棋盘格或 JPEG 压缩痕迹。
- 每个资产之间留足纯色间距，不互相接触，不投影到彼此背景上。

### 2.3 裁剪与清理

当前裁剪脚本 `scripts/dev/crop_ui_assets.py` 会从源图角落估计背景色，并对半透明边缘做 unmatting，理论上可以处理任意纯色背景。使用 `#FF00FF` 的目的不是让脚本只能识别这个颜色，而是让主体和背景距离足够大，减少 AI 生成阶段的颜色污染。

入库前检查：

- 透明 PNG 放在深灰、浅灰、纯黑三种背景上预览。
- 200% 放大检查边缘，没有洋红、青绿或灰色脏边。
- 半透明光晕贴近主体，不铺满整张图。
- frame 中心需要抠空的位置必须真正透明。

## 3. 问题二：廉价青绿色与古早页游感

### 3.1 根因

Alpha UI 的青绿色既是源图背景，又被当成 UI 主体色和状态光使用。大面积高饱和蓝绿、强发光、厚边框叠在一起，会让界面看起来像廉价页游或早期网页游戏皮肤。

### 3.2 Beta 视觉方向

UI 方向为“轻微奇幻 + 战术 HUD + 低饱和暗色”。推荐：

- 主底色：深冷灰、深青灰、蓝灰黑，例如 `#18242A`、`#202A30`、`#26333A`。
- 次级底色：低饱和灰蓝、灰绿，只作为微弱层次。
- 强调色：浅金、琥珀、冷白、钢蓝灰。
- 警告色：低饱和红灰或琥珀，不用纯红。
- 禁用色：灰黑、低透明遮罩，不用强黑块。

限制：

- 青绿只能作为极少量功能点缀，不允许成为大面积主色。
- 不使用大面积蓝紫渐变、霓虹外发光、黄金厚边、宝石角饰、卷轴边、家具感材质。
- 边框优先 1px 级细线、轻内阴影、轻高光，不做粗描边。

## 4. 问题三：边框与底座混在一张 PNG

### 4.1 关键判断

“分离边框与底座”本身不保证边框拉伸正确。

如果把边框单独做成一张普通 PNG，再用 `TextureRect` 或普通缩放拉到不同尺寸，边框依然会变粗、变细，角也会变形。正确方案是：

- 用九宫格保护边框厚度。
- 或把边、角拆成分段素材，只沿正确方向拉伸/平铺。
- 或使用程序化边框，让 Godot 画固定像素宽度的线。

### 4.2 推荐方案 A：`StyleBoxTexture` 九宫格

适用：

- 面板、卡片、按钮、弹窗、资源项等矩形 UI。
- 边框较薄、角落装饰克制、四边能横向/纵向拉伸的素材。

做法：

1. 资产仍可以是一张 `frame_*_base.png`，但必须设计成九宫格友好：
   - 四个角包含完整圆角和角部装饰。
   - 上下边只允许横向延展。
   - 左右边只允许纵向延展。
   - 中心区域可平铺或拉伸，不含固定内容。
2. 在 `.tres` 或 `UiFrameSpec` 中设置：
   - `texture_margin_left/top/right/bottom`：保护边框和角不被拉伸。
   - `content_margin_left/top/right/bottom`：保护文字、图标和按钮不压边。
3. 固定场景节点优先使用 `PanelContainer + StyleBoxTexture`。
4. 动态卡片和按钮通过 `GameUiStyle` / `UiFrameSpec` 统一取样式。

示意：

```text
StyleBoxTexture
├─ corner：不拉伸
├─ top/bottom edge：只横向拉伸
├─ left/right edge：只纵向拉伸
└─ center：拉伸或平铺
```

这才是“边框粗细不随整体尺寸变化”的核心。

### 4.3 推荐方案 B：分段边线与角点

适用：

- 装饰性强、九宫格拉伸会露馅的边框。
- 需要局部角标、断点、线段动画的框。
- 范围描边、选中框、警告框等状态层。

做法：

- 四个角独立 PNG，不缩放。
- 上下左右边独立 PNG，只沿长度方向拉伸或平铺。
- 中心底板独立 `base`。
- 由场景节点或脚本组合：

```text
FrameRoot
├─ Base                 # 可拉伸底板
├─ TopEdge              # 横向拉伸/平铺
├─ BottomEdge
├─ LeftEdge             # 纵向拉伸/平铺
├─ RightEdge
├─ CornerTL             # 不缩放
├─ CornerTR
├─ CornerBL
└─ CornerBR
```

代价是节点更多，维护成本高。只建议用于少数关键面板或特殊状态，不作为所有 UI 的默认方案。

### 4.4 推荐方案 C：程序化边框

适用：

- 只是 1px-2px 细线、圆角矩形、简单内阴影。
- 不需要复杂手绘材质。

做法：

- 使用 `StyleBoxFlat` 设置固定 `border_width_*`、`corner_radius_*`、`content_margin_*`。
- 或用 shader/自绘实现固定像素边线。

优点：

- 边宽永远稳定。
- 不会有抠图残边。
- 改色和状态切换成本低。

缺点：

- 手绘质感较弱，需要搭配轻微背景纹理或局部装饰。

### 4.5 什么时候真的需要拆成 base/frame/overlay

拆层主要解决下面的问题：

- `base`：承托背景和中心材质，可九宫格拉伸。
- `frame`：只用于头像、图标、特殊局部框，通常固定尺寸，中心透明。
- `overlay`：选中、hover、禁用、冷却、稀有度等状态，不改变底板结构。
- `track/fill`：进度条拆开，fill 按比例裁剪。

如果只是普通面板的 1px 边线，没有必要强行把边框单独做成一张 overlay PNG。可以直接让 `frame_*_base` 作为九宫格 StyleBoxTexture，边框由 `texture_margin` 保护，内容由 `content_margin` 保护。

## 5. 项目落地规则

### 5.1 资产命名

- `frame_*_base`：可作为 `StyleBoxTexture` 的底板。
- `frame_*_backplate`：图标或头像下方暗底。
- `frame_*_frame`：图标或头像上方覆盖框，通常固定尺寸，中心透明。
- `frame_*_overlay`：状态叠层。
- `bar_*_track`：进度条底轨。
- `bar_*_fill_*`：进度条填充。
- `icon_*`：纯图标，不带底板和边框。

### 5.2 场景结构

固定面板优先：

```text
PanelContainer
└─ ContentRoot
```

如果必须使用 `Panel + MarginContainer`：

```text
PanelRoot
├─ PanelBase          # StyleBoxTexture 或 TextureRect，仅装饰
└─ ContentMargin      # margin 来自 content_margin
   └─ ContentRoot
```

不要让内容节点直接压在视觉边框上，也不要用负 margin 把内容挤回边框区域。

### 5.3 禁止事项

- 禁止用 `TextureRect` 直接拉伸有边框的 UI PNG 当大面板。
- 禁止把固定数量的卡槽、列表项、头像框、文字、数字画进大面板底图。
- 禁止把选中态、禁用态、冷却态复制成多张完整卡片图。
- 禁止在组件脚本里自己拼 `res://assets/ui/generated/...` 路径。
- 禁止使用接近 UI 主色的背景做抠图色键。

## 6. 验收标准

- 透明 PNG 无洋红、青绿、灰边残留。
- 主界面大面积色彩为低饱和冷灰/深青灰，不再以青绿色为主。
- 所有可缩放 `frame_*_base` 都有 `texture_margin` 和 `content_margin`。
- 1920x1080 下拉伸面板边框粗细稳定，圆角不变形。
- 文本、图标、数值不压边框。
- overlay 不拦截鼠标。
- 动态内容由 Godot 节点绘制，不烘在 PNG 内。

## 7. 推荐执行顺序

1. 修改提示词库，将 UI 源图背景改为 `#FF00FF`，限制青绿色大面积使用。
2. 重新生成或清理 P0 UI 资产：按钮、顶部 HUD、资源项、部署栏、干员卡、右侧详情、建筑栏。
3. 为 P0 `frame_*_base` 建立 `.tres` StyleBoxTexture。
4. 在 `UiFrameSpec` 中补齐 texture margin 与 content margin。
5. 将固定场景节点改为直接使用 `.tres`，动态节点继续走 `GameUiStyle`。
6. 对少数九宫格不适合的特殊框，再使用分段边线方案。
7. 跑 Godot 校验和截图验收。
