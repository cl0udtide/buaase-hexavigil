# UI_SYSTEM

## 1. 目标风格

UI 重构目标以参考图的战术 HUD 信息结构为准，但后续资产风格走轻微奇幻、清新、低饱和路线。界面应服务塔防读图，地图永远是第一视觉层级。

- 顶部最左侧：小齿轮设置按钮，点击打开设置面板，面板内可调整音量。
- 顶部：阶段、时间、核心生命、部署上限、暂停/倍速、资源状态。
- 顶部下方：遗物入口与少量遗物缩略提示。
- 左侧：建筑/商店竖向面板，标签固定，列表项紧凑。
- 底部：待部署干员角色卡横向列表，卡片显示职业、费用、HP/SP/CD；底栏只做轻量承托背景，不固定卡槽数量。
- 右侧：选中单位详情，含头像占位、属性、SP、技能说明、技能/撤退按钮。
- 中心：地图、部署拖拽、落点锁定、朝向选择、攻击范围和路径提示。
- 右下：战场图例、标记或辅助信息。

当前工程基线仍允许无资产运行：面板、按钮、进度条先由 Godot 默认控件和 `StyleBoxFlat` 生成。后续接入图片资产时，只能通过统一样式与资源入口接入，不能让组件脚本各自拼路径。

## 2. 遗物展示方案

推荐方案：**遗物面板为主，顶部下方轻量摘要为辅。**

只在顶部下方开一整行遗物图标的问题是：遗物数量会越来越多，效果文本也包含职业过滤、建筑过滤、经济加成、负面代价和复合效果；靠 hover 看完整信息会很累，移动端或手柄也不友好。只放一个按钮打开面板的问题是：玩家很容易忘记当前局已经有哪些关键遗物。

因此使用混合结构：

1. `RelicStrip`
   放在顶部状态栏下方，靠右或接在资源状态下方。默认显示一个“遗物 N”入口按钮和最多 6 个小图标；超过数量显示 `+N`。
2. 悬停图标
   显示轻量 tooltip：遗物名、稀有度、效果描述。tooltip 只用于快速确认，不承担完整管理。
3. 点击入口按钮或按快捷键
   打开 `RelicPanel`，完整查看所有遗物。推荐快捷键 `R`，避免占用当前标记相关按键。
4. `RelicPanel`
   中央或右侧抽屉式面板，显示遗物网格/列表，可按“全部、单位、建筑、经济、核心、风险”筛选。每张遗物卡显示图标、名称、稀有度、效果描述和标签。
5. 祝福选择完成后
   新获得的遗物在 `RelicStrip` 中短暂高亮，`RelicPanel` 中按获得顺序靠前或提供“最近获得”排序。

数据来源：

- `RunState.get_all_buffs()` 读取已拥有遗物。
- `EventBus.buffs_changed` 驱动 `RelicStrip` 和 `RelicPanel` 刷新。
- `DataRepo.get_buff_cfg(buff_id)` 读取 `name`、`desc`、`rarity`、`effect_type`、`effects` 和过滤字段。

## 3. 当前需要修改的内容

1. 新增 `scenes/ui/relic/RelicIcon.tscn` 与 `scripts/ui/relic/relic_icon.gd`，作为遗物小图标组件，支持 hover tooltip、稀有度框和新获得高亮。
2. 新增 `scenes/ui/relic/RelicStrip.tscn` 与 `scripts/ui/relic/relic_strip.gd`，放入 `CombatHud.tscn` 顶部状态栏下方，监听或接收遗物列表并显示入口。
3. 新增 `scenes/ui/relic/RelicPanel.tscn` 与 `scripts/ui/relic/relic_panel.gd`，显示完整遗物列表、筛选标签和效果详情。
4. 新增 `scenes/ui/relic/RelicCard.tscn` 与 `scripts/ui/relic/relic_card.gd`，用于 `RelicPanel` 中的单个遗物条目。
5. `CombatHud` 增加 `relic_panel_requested` 或直接持有 `RelicPanel` 显隐逻辑；`CombatHudController` 只负责把 `RunState` 的遗物列表同步给 HUD。
6. `CombatHudController` 当前资源 tooltip 中的“遗物 N / 当前遗物列表”保留为兜底，但完整查看迁移到 `RelicPanel`。
7. `UiDisplayText` 增加遗物稀有度、遗物分类标签和效果字段格式化方法，避免 `RelicPanel`、`BlessingPanel`、tooltip 各写一套文案。
8. `BlessingPanel` 改成使用 `RelicCard` 的选择态版本，让“获得遗物”与“查看遗物”视觉一致。
9. `UiLayoutRules` 增加 `relic_strip_rect`，确保 1920x1080、1600x900、1366x768、1280x720 下不遮挡地图、左侧建筑栏和右侧详情。
10. 将设置入口固定到顶部最左侧：使用小齿轮按钮打开设置面板，设置面板至少包含主音量、音乐音量和音效音量滑条。
11. 补齐键鼠交互：`R` 打开/关闭遗物面板，`Esc` 优先关闭当前打开的遗物/设置面板，鼠标悬停显示 tooltip，点击遗物卡可展开详情。

## 4. 职责边界

### 场景负责

- 固定节点名与层级，例如 `TopBar`、`RelicStrip`、`DeployDeck`、`UnitDetailPanel`。
- 容器类型、基础锚点、控件语义和可复用组件模板。
- 单个组件内部的静态子节点，例如标签、按钮、进度条、图标占位框。

### 脚本负责

- 从 `RunState`、`DataRepo`、Manager 或传入参数读取状态。
- 调用 `GameUiStyle`、`UiFrameSpec`、`UiLayoutRules` 应用统一样式和布局。
- 动态生成重复项，例如干员卡、建筑列表、商店槽位、遗物卡。
- 发出 UI 信号或把 UI 信号转接为 Manager 请求。

### 禁止

- 组件脚本自行加载 `res://assets/...` UI 图片。
- 在多个 UI 脚本重复维护职业、阶段、伤害类型、朝向、遗物稀有度等显示映射。
- 在 `.tscn` 固定一套布局，同时又在脚本中创建另一套同名结构。
- 业务真相数据保存在 UI 节点里。

## 5. 现有 UI 基线

- `scripts/ui/app_theme.gd`：使用 Godot 默认字体，只设置字号、颜色和控件样式。
- `scripts/ui/game_ui_style.gd`：唯一主题入口，当前只生成 `StyleBoxFlat`。
- `scripts/ui/ui_frame_spec.gd`：只保存组件内容边距，不保存贴图路径。
- `scripts/ui/ui_layout_rules.gd`：作战 HUD 响应式矩形计算。
- `scripts/ui/ui_tokens.gd`：断点、间距、字号和固定组件尺寸。
- `scripts/ui/ui_display_text.gd`：跨 UI 显示文本转换。
- `scripts/ui/ui_art_registry.gd`：当前固定不返回贴图，保留未来资源接入点。

## 6. UI 资产生成规范

### 6.1 通用要求

- 风格：轻微奇幻、清新、低饱和，有少量木、石、布、浅金属、柔和魔法纹理即可。
- 背景：生成时使用纯色背景，推荐 `#79C7B6` 或 `#8AD1C1`，方便后续抠图；最终入库 PNG 应为透明背景。
- 色彩：避免高纯度霓虹色、大面积紫蓝渐变、浓重黑金边、复杂花纹和强烈外发光。
- 边框：边框要薄，圆角小，装饰克制。不要做厚重卷轴、黄金大框、宝石堆叠或过度雕花。
- 文字：资产内不得包含文字、数字、UI 文案或假按钮标签。
- 构图：图标主体居中，四周保留 12% 透明安全边距，64x64 缩略图下仍可辨认。
- 输出：源文件建议 512x512 或 1024x1024，入库导出为透明 PNG。可缩放框类资产需额外提供九宫格切片建议。

### 6.2 分层拆分原则

UI 资产默认按“底板、内容、覆盖框、状态层”拆分。凡是后续会被代码替换、裁剪、滚动、变长、变色或响应状态的内容，都不能烘在同一张大图里。

- 底板资产只负责整体材质和极薄边缘，不画具体数据区控件。
- 头像、建筑图标、技能图标、遗物图标这类内容图片必须夹在 `backplate` 和 `frame` 之间；`frame` 中心后续抠透明。
- 进度条必须拆为 `track`、`fill`、必要时的 `glow/overlay`，不得把填充比例画死。
- 列表容器只画承托背景，不画固定数量的卡槽；条目卡由代码动态生成。
- 选中、禁用、冷却、稀有度等状态优先做 overlay 或 state frame，不复制一张带内容的大图。
- 所有文字、数字、图标、头像、进度值、冷却值都由 Godot 节点绘制。
- 同父 `Control` 节点默认按树顺序后绘制覆盖前者；复杂部件可显式设置 `z_index`。

### 6.2.1 分层框架与控件资产

| 资产 key | 对应 UI 部件 | 建议规格 | 分层职责 |
|---|---|---:|---|
| `frame_top_status_bar_base` | `CombatHud/TopBar/Base` | 1200x72 | 顶部状态栏底板，只做承托背景，不内置状态卡、按钮或资源槽 |
| `frame_top_status_chip_base` | 阶段、时间、核心、部署、资源信息块 | 240x64 | 单个状态信息块底板，内容与图标由节点叠放 |
| `frame_top_status_chip_active_overlay` | 重要/警告状态叠层 | 240x64 | 轻微高亮状态层，不改变底板结构 |
| `frame_speed_toggle_base` | 暂停/倍速容器 | 220x56 | 倍速切换底板，不写 `1X/2X`，不画固定文字 |
| `frame_speed_toggle_active_overlay` | 当前倍速选中态 | 110x52 | 选中叠层，可移动到 1x 或 2x 按钮下 |
| `frame_settings_button_base` | 顶部最左侧设置按钮底 | 64x64 | 齿轮按钮底板，不画齿轮图标 |
| `frame_relic_strip_base` | `RelicStrip/Base` | 720x48 | 遗物摘要条底板，不画固定遗物槽 |
| `frame_relic_entry_button_base` | `RelicStrip/OpenButton` | 128x44 | “遗物 N”入口按钮底，不写文字数字 |
| `frame_left_sidebar_base` | `BuildPanel/Base` | 320x760 | 左侧建筑/商店栏底板，不内置页签和列表项 |
| `frame_sidebar_tab_base` | 建筑/商店页签普通态 | 160x48 | 页签底板，不写文字 |
| `frame_sidebar_tab_selected_overlay` | 建筑/商店页签选中态 | 160x48 | 页签选中叠层，不改变底板 |
| `frame_build_list_card_base` | `BuildListCard/Base` | 280x104 | 建筑/商店列表项底板，不内置图标框、价格徽标或按钮 |
| `frame_build_icon_backplate` | `BuildListCard/IconBackplate` | 72x72 | 建筑图标下方暗底 |
| `frame_build_icon_frame` | `BuildListCard/IconFrame` | 72x72 | 建筑图标上方覆盖框，中心可抠空 |
| `frame_cost_badge_base` | 建造/部署/商店成本徽标 | 56x32 | 成本数字底，不写数字和资源图标 |
| `frame_undo_button_base` | 撤销按钮底 | 160x44 | 左侧撤销按钮底，不画图标或文字 |
| `frame_bottom_deploy_rail_base` | `DeployDeck/Base` | 980x176 | 底部待部署区承托背景，不画固定卡槽 |
| `frame_operator_card_base` | `OperatorCard/Base` | 164x148 | 单张干员卡底板，不内置头像框、状态行或费用角标 |
| `frame_operator_card_selected_overlay` | `OperatorCard` 选中/拖拽态 | 164x148 | 选中叠层，轻描边/内光 |
| `frame_operator_card_deployed_overlay` | `OperatorCard` 已部署态 | 164x148 | 已部署状态叠层 |
| `frame_operator_card_cooldown_overlay` | `OperatorCard` 冷却态 | 164x148 | 冷却遮罩，不写冷却数字 |
| `frame_operator_title_strip` | `OperatorCard/TitleStrip` | 140x28 | 干员名/职业图标所在顶部条底 |
| `frame_operator_portrait_backplate` | `OperatorCard/PortraitBackplate` | 128x72 | 干员头像下方暗底 |
| `frame_operator_portrait_frame` | `OperatorCard/PortraitFrame` | 128x72 | 干员头像覆盖框，中心可抠空 |
| `frame_operator_cost_badge` | `OperatorCard/CostBadge` | 48x36 | 费用数字底，不写数字 |
| `frame_operator_stat_row` | `OperatorCard/StatRow` | 140x20 | HP/SP/CD 单行底纹，不写文字数字 |
| `frame_right_detail_sidebar_base` | `UnitDetailPanel/Base` | 380x760 | 右侧单位详情栏底板，不内置任何子控件 |
| `frame_unit_header_strip` | `UnitDetailPanel/Header` | 340x56 | 单位名称、编号、伤害类型、朝向所在信息条底 |
| `frame_unit_portrait_backplate` | `UnitDetailPanel/PortraitBackplate` | 128x128 | 单位头像下方暗底 |
| `frame_unit_portrait_frame` | `UnitDetailPanel/PortraitFrame` | 128x128 | 单位头像覆盖框，中心可抠空 |
| `frame_unit_stat_row` | `UnitDetailPanel/StatRow` | 320x28 | 攻击、防御、法抗、阻挡、攻速等属性行底 |
| `frame_skill_icon_backplate` | `UnitDetailPanel/SkillIconBackplate` | 72x72 | 技能图标下方暗底 |
| `frame_skill_icon_frame` | `UnitDetailPanel/SkillIconFrame` | 72x72 | 技能图标覆盖框，中心可抠空 |
| `frame_skill_desc_box` | `UnitDetailPanel/SkillDescription` | 320x150 | 技能描述滚动区域底板 |
| `frame_detail_section_base` | 属性、生命、技能区块 | 340x120 | 通用分组底板，不绑定具体内容 |
| `frame_relic_panel_base` | `RelicPanel/Base` | 900x640 | 遗物面板底板，不画固定网格、列表项或详情内容 |
| `frame_relic_filter_tab_base` | `RelicPanel/FilterTab` | 120x40 | 遗物筛选页签底板，不写文字图标 |
| `frame_relic_filter_selected_overlay` | `RelicPanel/FilterTab` selected | 120x40 | 筛选选中叠层 |
| `frame_relic_card_base` | `RelicCard/Base` | 360x112 | 遗物卡底板，不内置稀有度边、图标框或文本 |
| `frame_relic_card_hover_overlay` | `RelicCard` hover/selected | 360x112 | 遗物卡 hover/选中叠层 |
| `frame_relic_rarity_common_overlay` | 常见遗物稀有度 | 360x112 / 80x80 | 灰绿稀有度轻叠层，可用于卡或图标槽 |
| `frame_relic_rarity_uncommon_overlay` | 精良遗物稀有度 | 360x112 / 80x80 | 蓝青稀有度轻叠层 |
| `frame_relic_rarity_rare_overlay` | 稀有遗物稀有度 | 360x112 / 80x80 | 柔和浅金叠层，不做厚金框 |
| `frame_relic_icon_backplate` | `RelicIcon/Backplate` | 80x80 | 遗物图标下方暗底 |
| `frame_relic_icon_frame` | `RelicIcon/Frame` | 80x80 | 遗物图标覆盖框，中心可抠空 |
| `frame_settings_panel_base` | 设置面板底板 | 420x300 | 齿轮按钮打开的设置弹窗底板，不画滑条 |
| `frame_settings_row_base` | 设置项行底 | 360x48 | 主音量、音乐、音效等设置行底，不写文字 |
| `frame_slider_track` | 音量/数值滑条轨道 | 280x24 | 滑条底轨 |
| `frame_slider_fill` | 音量/数值滑条填充 | 280x24 | 滑条填充，不画固定比例 |
| `frame_slider_handle` | 滑条拖柄 | 40x40 | 小型拖柄，不做宝石或厚按钮 |
| `frame_button_base` | 通用按钮底 | 320x52 | 默认按钮底，不写文字图标 |
| `frame_button_primary_overlay` | 主按钮状态 | 320x52 | 主按钮高亮叠层 |
| `frame_button_danger_overlay` | 危险按钮状态 | 320x52 | 危险按钮叠层 |
| `frame_button_disabled_overlay` | 禁用按钮状态 | 320x52 | 禁用/不可用遮罩 |
| `frame_icon_backplate` | 通用图标暗底 | 96x96 | 建筑、技能、遗物、属性图标底 |
| `frame_icon_frame` | 通用图标覆盖框 | 96x96 | 图标覆盖框，中心可抠空 |
| `frame_tooltip_base` | hover tooltip | 360x160 | tooltip 底板，不画箭头绑定方向 |
| `frame_scroll_track` | 滚动条轨道 | 16x200 | 滚动条底轨 |
| `frame_scroll_thumb` | 滚动条拖块 | 16x60 | 滚动条拖块 |
| `bar_progress_track` | HP/SP/核心进度条底 | 320x24 | 进度条底轨 |
| `bar_progress_fill_hp` | HP 填充 | 320x24 | HP 填充条 |
| `bar_progress_fill_sp` | SP 填充 | 320x24 | SP 填充条 |
| `bar_progress_fill_core` | 核心生命填充 | 320x24 | 核心生命填充条 |
| `frame_blessing_panel_base` | `BlessingPanel/Base` | 640x440 | 祝福/遗物选择面板底板，不画候选卡槽 |
| `frame_blessing_choice_card_base` | 祝福候选卡底 | 560x112 | 候选遗物卡底板，复用遗物卡结构 |
| `frame_event_panel_base` | `EventPanel/Base` | 640x420 | 事件面板底板，不画选项按钮 |
| `frame_event_choice_button_base` | 事件选项按钮 | 560x64 | 事件选项按钮底，不写文字 |
| `frame_dialog_box_base` | `DialogPanel/TextBox` | 1100x220 | 对话文本框底板，不画头像或名字 |
| `frame_dialog_speaker_plate_base` | `DialogPanel/SpeakerPlate` | 240x56 | 说话人名牌底，不写名字 |
| `frame_result_panel_base` | `ResultPanel/Base` | 720x520 | 结算面板底板，不画固定统计项 |
| `frame_result_stat_row_base` | `ResultPanel/StatRow` | 600x44 | 结算统计行底，不写文字数字 |
| `frame_map_popup_base` | `MapInteractionPopup/Base` | 360x260 | 地图交互弹窗底板，不画固定按钮 |
| `frame_wave_preview_base` | 波次/路径预览 | 360x220 | 波次信息窗底板，不画敌人条目 |
| `frame_legend_panel_base` | 右下战场图例 | 260x220 | 图例面板底板，不画固定图例行 |
| `frame_legend_row_base` | 图例行底 | 220x28 | 单条图例行底，不画图标文字 |

### 6.2.2 关键部件推荐层级

- `TopBar`
  `TopBarBase(frame_top_status_bar_base)`、多个 `StatusChip(frame_top_status_chip_base)`、`ChipIcon`、`Label`、`ProgressTrack/Fill`、`SpeedToggleBase`、`SpeedActiveOverlay`、`SettingsButtonBase`、`icon_settings_gear`。
- `BuildPanel`
  `SidebarBase(frame_left_sidebar_base)`、`TabBase`、`TabSelectedOverlay`、动态 `BuildListCardBase`、`BuildIconBackplate`、`BuildingIcon`、`BuildIconFrame`、`CostBadgeBase`、成本图标与数字、`UndoButtonBase`。
- `DeployDeck` 与 `OperatorCard`
  `DeployRailBase(frame_bottom_deploy_rail_base)`、动态 `OperatorCardBase`、`PortraitBackplate`、角色小头像、`PortraitFrame`、`TitleStrip`、职业图标、名字、`CostBadge`、费用数字、三条 `StatRow`、HP/SP/CD 文本、必要状态 overlay。
- `UnitDetailPanel`
  `PanelBase(frame_right_detail_sidebar_base)`、`HeaderStrip`、单位名/类型/朝向、`PortraitBackplate`、角色头像、`PortraitFrame`、HP/SP `Track/Fill`、`DetailSectionBase`、多个 `StatRow`、属性图标与文字、`SkillIconBackplate`、技能图标、`SkillIconFrame`、`SkillDescription`、主/次按钮。
- `RelicStrip`、`RelicPanel`、`RelicCard`
  容器底板不画固定数量；每个遗物项由 `RelicCardBase`、`RelicIconBackplate`、遗物图标、`RelicIconFrame`、稀有度 overlay、名称/描述/标签节点组成。
- `SettingsPanel`
  `SettingsPanelBase`、动态 `SettingsRowBase`、音量图标、文字、`SliderTrack`、`SliderFill`、`SliderHandle`；面板底板不得内置具体三条滑杆。
- `EventPanel`、`BlessingPanel`、`ResultPanel`
  大面板只做底板；选项、候选卡、统计行、按钮都使用独立条目资产动态排列。

### 6.2.3 场景层级与绘制顺序

重构目标不是把图片直接盖在现有控件上，而是把场景树整理成稳定的 UI 骨架。场景负责节点层级和可替换资产槽位，脚本负责状态、文本、列表数据和信号。

#### `Game/UI` 顶层

`Game.tscn` 当前已有 `UI` 作为 `CanvasLayer`。推荐保持这个入口，并让可视节点按下列顺序组织；若短期不移动现有节点，也必须用 `z_index` 保证相同绘制顺序。

```text
UI (CanvasLayer)
├─ BuildPanel                  # 左侧建筑/商店栏，z_index 20
├─ CombatHud                   # 作战 HUD 主体，z_index 30
├─ MapInteractionPopup         # 地图对象弹窗，z_index 60
├─ EventPanel                  # 随机事件弹窗，z_index 80
├─ BlessingPanel               # 祝福/遗物选择弹窗，z_index 90
├─ ResultPanel                 # 结算弹窗，z_index 100
└─ CombatHudController         # 非可视控制节点，不参与绘制
```

弹窗同屏冲突时只允许最高优先级面板可交互：`ResultPanel > BlessingPanel > EventPanel > MapInteractionPopup > CombatHud`。`Esc` 应优先关闭当前最高层面板。

#### `CombatHud` 主骨架

`CombatHud` 根节点铺满屏幕。地图读图优先，因此 `CombatHud` 内所有非弹窗面板都靠边放置，中心地图区域不放常驻大面板。

```text
CombatHud (Control, full rect)
├─ HudChromeLayer (Control, z_index 10)
│  ├─ SettingsButton
│  ├─ TopBar
│  ├─ RelicStrip
│  ├─ WavePreviewPanel
│  ├─ DeployDeck
│  ├─ UnitDetailPanel
│  └─ LegendPanel
├─ InteractionLayer (Control, z_index 30)
│  └─ DragGhost
├─ PopupLayer (Control, z_index 70)
│  ├─ RelicPanel
│  └─ AudioSettingsPanel
└─ TooltipLayer (Control, z_index 100)
```

当前场景可以先保留这些节点为 `CombatHud` 直接子节点，但目标是逐步收拢进上述 layer。脚本中已有 `%SettingsButton`、`%TopBar`、`%RelicStrip`、`%DeployDeckContainer`、`%UnitDetailPanel`、`%RelicPanel`、`%AudioSettingsPanel`、`%DragGhost` 等引用；重构时若移动节点，必须保留 `unique_name_in_owner` 或同步更新脚本引用。

#### `TopBar`

```text
TopBar
├─ TopBarBase                  # frame_top_status_bar_base
└─ TopContent
   ├─ StageChip
   │  ├─ ChipBase              # frame_top_status_chip_base
   │  ├─ PhaseIcon
   │  └─ QueueLabel
   ├─ CoreChip
   │  ├─ ChipBase
   │  ├─ CoreIcon
   │  ├─ CoreLabel
   │  ├─ CoreTrack             # bar_progress_track
   │  └─ CoreFill              # bar_progress_fill_core
   ├─ DeployChip
   │  ├─ ChipBase
   │  ├─ DeployIcon
   │  └─ DeployLabel
   ├─ MessageChip
   │  ├─ ChipBase
   │  └─ MessageLabel
   ├─ TimeControls
   │  ├─ SpeedToggleBase       # frame_speed_toggle_base
   │  ├─ SpeedActiveOverlay
   │  ├─ PauseButton
   │  ├─ Speed1Button
   │  └─ Speed2Button
   └─ ResourceChip
      ├─ ChipBase
      ├─ ResourceIcons
      └─ ResourceLabel
```

`SettingsButton` 固定在顶部最左侧，不放入 `TopBar` 内部挤占状态信息。按钮结构为 `ButtonBase -> icon_settings_gear`，点击打开 `AudioSettingsPanel`。

#### `BuildPanel`

```text
BuildPanel
├─ SidebarBase                 # frame_left_sidebar_base
└─ ContentMargin
   └─ MainVBox
      ├─ ModeTabs
      │  ├─ BuildModeButton
      │  └─ ShopModeButton
      ├─ BuildSelectionLabel
      ├─ BuildCardScroll
      │  └─ BuildCardList      # 动态 BuildListCard
      └─ BottomControls
         ├─ CategoryTabs
         ├─ RefreshShopButton
         └─ PanelMessageLabel
```

`BuildListCard` 推荐结构：

```text
BuildListCard
├─ CardBase                    # frame_build_list_card_base
└─ Content
   ├─ IconBackplate
   ├─ BuildingIcon
   ├─ IconFrame
   ├─ TextColumn
   │  ├─ NameLabel
   │  └─ DescLabel
   └─ CostBadge
      ├─ CostIcon
      └─ CostLabel
```

#### `DeployDeck` 与 `OperatorCard`

```text
DeployDeck
├─ DeployRailBase              # frame_bottom_deploy_rail_base
└─ DeckMargin
   └─ ScrollContainer
      └─ DeployDeckContainer   # 动态 OperatorCard
```

`DeployDeck` 不画固定卡槽，不限制显示多少干员；滚动和数量完全由 `DeployDeckContainer` 决定。

```text
OperatorCard
├─ CardBase                    # frame_operator_card_base
├─ CardContent
│  ├─ TitleStrip
│  │  ├─ ClassIcon
│  │  ├─ NameLabel
│  │  └─ CostBadge
│  │     └─ CostLabel
│  ├─ PortraitBackplate
│  ├─ PortraitTexture
│  ├─ PortraitFrame
│  ├─ MetaRow
│  │  ├─ ClassLabel
│  │  └─ StateLabel
│  └─ StatRows
│     ├─ HpStatRow -> HpStatLabel
│     ├─ SpStatRow -> SpStatLabel
│     └─ CdStatRow -> CdStatLabel
├─ SelectedOverlay
├─ DeployedOverlay
└─ CooldownOverlay
   └─ CooldownLabel
```

`PortraitTexture` 位于 `PortraitBackplate` 和 `PortraitFrame` 之间。没有头像资源时可隐藏 `PortraitTexture`，显示 `PortraitLabel` 或默认占位。

#### `UnitDetailPanel`

```text
UnitDetailPanel
├─ PanelBase                   # frame_right_detail_sidebar_base
└─ ContentMargin
   └─ MainVBox
      ├─ Header
      │  ├─ HeaderStrip
      │  ├─ TitleLabel
      │  ├─ LevelLabel
      │  ├─ DamagePill -> DamageLabel
      │  └─ FacingPill -> FacingLabel
      ├─ VitalsSection
      │  ├─ SectionBase
      │  ├─ PortraitBackplate
      │  ├─ PortraitTexture
      │  ├─ PortraitFrame
      │  ├─ HpValueLabel
      │  ├─ HpTrack
      │  ├─ HpFill
      │  ├─ SpValueLabel
      │  ├─ SpTrack
      │  └─ SpFill
      ├─ StatsSection
      │  ├─ SectionBase
      │  └─ StatRows
      │     ├─ AtkStatLabel
      │     ├─ DefStatLabel
      │     ├─ ResStatLabel
      │     ├─ BlockStatLabel
      │     └─ AspdStatLabel
      ├─ SkillSection
      │  ├─ SectionBase
      │  ├─ SkillHeaderRow
      │  │  ├─ SkillIconBackplate
      │  │  ├─ SkillIconTexture
      │  │  ├─ SkillIconFrame
      │  │  ├─ SkillTitleLabel
      │  │  └─ SkillStatusLabel
      │  └─ SkillScroll
      │     └─ SkillLabel
      └─ Actions
         ├─ CastSkillButton
         └─ RetreatButton
```

头像、技能图标、HP/SP 填充都必须是可替换节点，不得烘进 `PanelBase` 或 `SectionBase`。当前脚本依赖 `%TitleLabel`、`%PortraitTexture`、`%HpBar`、`%SpBar`、`%SkillIconTexture`、`%CastSkillButton`、`%RetreatButton` 等节点名；若把 `ProgressBar` 拆成 `Track/Fill`，要同步更新 `unit_detail_panel.gd`。

#### `RelicStrip`、`RelicPanel`、`RelicCard`

```text
RelicStrip
├─ StripBase
├─ EntryButton
├─ IconRow                     # 动态 RelicIcon
└─ OverflowLabel

RelicIcon
├─ IconBackplate
├─ IconTexture
├─ IconFrame
├─ RarityOverlay
└─ NewHighlightOverlay

RelicPanel
├─ PanelBase
└─ Content
   ├─ Header
   │  ├─ TitleLabel
   │  ├─ CountLabel
   │  └─ CloseButton
   ├─ FilterBar                # 动态 filter tabs
   ├─ CardScroll
   │  └─ CardGrid              # 动态 RelicCard
   ├─ EmptyLabel
   └─ DetailPanel
      ├─ DetailTitleLabel
      ├─ DetailMetaLabel
      └─ DetailEffectLabel

RelicCard
├─ CardBase
├─ IconBackplate
├─ IconTexture
├─ IconFrame
├─ RarityOverlay
├─ NameLabel
├─ RarityLabel
├─ DescLabel
├─ TagLabel
└─ HoverOverlay
```

`RelicPanel` 不固定遗物数量；`RelicCard` 与 `BlessingPanel` 的候选卡共用同一套结构和样式。

#### `AudioSettingsPanel`

```text
AudioSettingsPanel
├─ PanelBase
└─ ContentMargin
   └─ MainVBox
      ├─ Header
      │  ├─ TitleLabel
      │  └─ CloseButton
      ├─ MasterRow
      │  ├─ RowBase
      │  ├─ VolumeIcon
      │  ├─ MasterLabel
      │  ├─ MasterSlider
      │  └─ MasterValueLabel
      ├─ MusicRow
      └─ SfxRow
```

设置面板底板不画具体三条滑杆。当前可继续使用 Godot `HSlider`，后续接资产时通过统一主题替换 track/fill/handle。

#### 弹窗类面板

`MapInteractionPopup`、`EventPanel`、`BlessingPanel`、`ResultPanel`、`DialogPanel` 都遵循同样结构：`PanelBase` 只做底，标题、文本、选项、统计行、按钮都是独立节点。候选项或统计项必须动态生成，不在背景图里画固定数量。

#### 脚本兼容要求

- 保留当前脚本使用的 `%NodeName`，或在同一提交中同步修改对应脚本。
- 保留现有信号：`operator_card_pressed`、`pause_pressed`、`speed_1_pressed`、`speed_2_pressed`、`cast_skill_requested`、`retreat_requested`、`wave_route_preview_toggled`、`RelicStrip.panel_requested`、`RelicPanel.close_requested`。
- `CombatHud` 负责显示和转发 UI 信号，`CombatHudController` 负责把 Manager/RunState 数据同步到 HUD；不要把业务状态塞进 UI 节点。
- 无资产状态必须可运行。新增的 `TextureRect`、overlay、backplate、frame 在没有图片时用 `StyleBoxFlat` 或隐藏兜底。

### 6.3 通用功能图标

| 资产 key | 对应 UI 部件 | 说明 |
|---|---|---|
| `icon_phase_day` | 顶部阶段卡 | 白天阶段 |
| `icon_phase_night` | 顶部阶段卡 | 夜晚阶段 |
| `icon_phase_blessing` | 顶部阶段卡 / 祝福面板 | 祝福/遗物选择阶段 |
| `icon_settings_gear` | 顶部最左侧设置按钮 | 设置入口，小齿轮 |
| `icon_volume_master` | 设置面板主音量滑条 | 主音量 |
| `icon_volume_music` | 设置面板音乐音量滑条 | 音乐音量 |
| `icon_volume_sfx` | 设置面板音效音量滑条 | 音效音量 |
| `icon_volume_mute` | 设置面板静音状态 | 静音 |
| `icon_core_hp` | 核心生命卡 | 核心生命 |
| `icon_deploy_limit` | 部署上限卡 | 部署数量 |
| `icon_enemy_queue` | 波次/刷怪信息 | 待刷怪或敌人队列 |
| `icon_timer` | 时间卡 | 作战计时 |
| `icon_pause` | 暂停按钮 | 暂停 |
| `icon_play` | 暂停按钮恢复态 | 继续 |
| `icon_speed_1x` | 倍速按钮 | 1x |
| `icon_speed_2x` | 倍速按钮 | 2x |
| `icon_action_points` | 资源状态卡 | 行动力 |
| `icon_prestige` | 资源状态卡 / 商店价格 | 声望 |
| `icon_wood` | 资源状态卡 / 建造成本 | 木材 |
| `icon_stone` | 资源状态卡 / 建造成本 | 石材 |
| `icon_mana` | 资源状态卡 / 建造成本 | 魔力 |
| `icon_relic_bag` | `RelicStrip` 入口 | 遗物总入口 |
| `icon_filter_all` | `RelicPanel` 筛选 | 全部 |
| `icon_filter_unit` | `RelicPanel` 筛选 | 单位类遗物 |
| `icon_filter_building` | `RelicPanel` 筛选 | 建筑类遗物 |
| `icon_filter_economy` | `RelicPanel` 筛选 | 经济类遗物 |
| `icon_filter_core` | `RelicPanel` 筛选 | 核心防线类遗物 |
| `icon_filter_risk` | `RelicPanel` 筛选 | 风险收益类遗物 |
| `icon_close` | 面板关闭按钮 | 关闭 |
| `icon_refresh` | 商店刷新按钮 | 刷新 |
| `icon_confirm` | 确认按钮 | 确认 |
| `icon_cancel` | 取消/撤销按钮 | 取消 |

### 6.4 职业、属性与战斗图标

| 资产 key | 对应 UI 部件 | 说明 |
|---|---|---|
| `icon_class_guard` | `OperatorCard` / `UnitDetailPanel` / 遗物过滤标签 | 近卫 |
| `icon_class_sniper` | `OperatorCard` / `UnitDetailPanel` / 遗物过滤标签 | 狙击 |
| `icon_class_caster` | `OperatorCard` / `UnitDetailPanel` / 遗物过滤标签 | 术士 |
| `icon_class_defender` | `OperatorCard` / `UnitDetailPanel` / 遗物过滤标签 | 重装 |
| `icon_stat_hp` | `UnitDetailPanel` | 生命 |
| `icon_stat_atk` | `UnitDetailPanel` | 攻击 |
| `icon_stat_def` | `UnitDetailPanel` | 防御 |
| `icon_stat_res` | `UnitDetailPanel` | 法抗 |
| `icon_stat_block` | `UnitDetailPanel` | 阻挡 |
| `icon_stat_attack_speed` | `UnitDetailPanel` | 攻速 |
| `icon_stat_sp` | `UnitDetailPanel` | SP |
| `icon_damage_physical` | 详情/技能说明 | 物理伤害 |
| `icon_damage_arts` | 详情/技能说明 | 法术伤害 |
| `icon_damage_true` | 详情/技能说明 | 真实伤害 |
| `icon_skill_ready` | 技能按钮/详情 | 技能可用 |
| `icon_skill_locked` | 技能按钮/详情 | 技能不可用 |
| `icon_cooldown` | `OperatorCard` | 冷却 |
| `icon_retreat` | 撤退按钮 | 撤退 |
| `icon_direction_up` | 部署朝向提示 | 朝上 |
| `icon_direction_down` | 部署朝向提示 | 朝下 |
| `icon_direction_left` | 部署朝向提示 | 朝左 |
| `icon_direction_right` | 部署朝向提示 | 朝右 |

### 6.5 建筑图标

| 资产 key | 对应 UI 部件 | 说明 |
|---|---|---|
| `icon_building_lumber_station` | `BuildListCard` / 地图弹窗 | 伐木站 |
| `icon_building_stone_quarry` | `BuildListCard` / 地图弹窗 | 石矿场 |
| `icon_building_mana_extractor` | `BuildListCard` / 地图弹窗 | 魔力矿场 |
| `icon_building_medical_station` | `BuildListCard` / 地图弹窗 | 医疗站 |
| `icon_building_gravity_tower` | `BuildListCard` / 地图弹窗 | 重力塔 |
| `icon_building_inspiring_monolith` | `BuildListCard` / 地图弹窗 | 鼓舞石碑 |
| `icon_building_war_shrine` | `BuildListCard` / 地图弹窗 | 战火圣坛 |
| `icon_building_wood_wall` | `BuildListCard` / 地图弹窗 | 木墙 |

### 6.6 技能图标

| 资产 key | 对应 UI 部件 | 说明 |
|---|---|---|
| `icon_skill_common_atk_up` | `UnitDetailPanel/SkillIcon` | 通用攻击强化 |
| `icon_skill_guard_hold_line` | `UnitDetailPanel/SkillIcon` | 近卫阵线压制 |
| `icon_skill_guard_decisive_swing` | `UnitDetailPanel/SkillIcon` | 近卫决胜斩击 |
| `icon_skill_sniper_quintuple_shot` | `UnitDetailPanel/SkillIcon` | 狙击连射 |
| `icon_skill_sniper_burst_dawn` | `UnitDetailPanel/SkillIcon` | 狙击爆发射击 |
| `icon_skill_caster_overload_permanent` | `UnitDetailPanel/SkillIcon` | 术士常驻过载 |
| `icon_skill_caster_chain_push` | `UnitDetailPanel/SkillIcon` | 术士连锁推击 |
| `icon_skill_defender_fortify` | `UnitDetailPanel/SkillIcon` | 重装固守 |
| `icon_skill_defender_counter_stance` | `UnitDetailPanel/SkillIcon` | 重装反击姿态 |
| `icon_skill_mountain_sweeping_stance` | `UnitDetailPanel/SkillIcon` | 山技能 |
| `icon_skill_zuo_le_risky_venture` | `UnitDetailPanel/SkillIcon` | 左乐技能 |
| `icon_skill_degenbrecher_silence` | `UnitDetailPanel/SkillIcon` | 锏技能 |
| `icon_skill_surtr_twilight` | `UnitDetailPanel/SkillIcon` | 史尔特尔技能 |
| `icon_skill_narantuya_solar_swallow` | `UnitDetailPanel/SkillIcon` | 娜仁图亚技能 |
| `icon_skill_ray_light` | `UnitDetailPanel/SkillIcon` | 莱伊技能 |
| `icon_skill_typhon_eternal_hunt` | `UnitDetailPanel/SkillIcon` | 提丰技能 |
| `icon_skill_wisadel_saturated_revenge` | `UnitDetailPanel/SkillIcon` | 维什戴尔技能 |
| `icon_skill_ifrit_scorched_earth` | `UnitDetailPanel/SkillIcon` | 伊芙利特技能 |
| `icon_skill_nymph_psychic_collapse` | `UnitDetailPanel/SkillIcon` | 妮芙技能 |
| `icon_skill_goldenglow_clear_shine` | `UnitDetailPanel/SkillIcon` | 澄闪技能 |
| `icon_skill_logos_oblivion` | `UnitDetailPanel/SkillIcon` | 逻各斯技能 |
| `icon_skill_saria_calcification` | `UnitDetailPanel/SkillIcon` | 塞雷娅技能 |
| `icon_skill_penance_thorny_body` | `UnitDetailPanel/SkillIcon` | 斥罪技能 |
| `icon_skill_jessica_saturation_burst` | `UnitDetailPanel/SkillIcon` | 涤火杰西卡技能 |
| `icon_skill_shu_cycle_of_growth` | `UnitDetailPanel/SkillIcon` | 黍技能 |

### 6.7 遗物图标

这些图标同时用于 `RelicStrip`、`RelicPanel`、`RelicCard` 和 `BlessingPanel`。

| 资产 key | 遗物 | 视觉方向 |
|---|---|---|
| `icon_relic_battle_standard` | 边境战旗 | 小旗帜、旧布、浅青纹 |
| `icon_relic_sharpened_orders` | 磨损军令 | 卷起军令、细裂纹 |
| `icon_relic_vanguard_frame` | 预备队框架 | 轻型部署框架 |
| `icon_relic_mobile_command` | 机动指挥台 | 小型指挥台 |
| `icon_relic_core_patch` | 核心补丁包 | 修补包、浅色核心纹 |
| `icon_relic_core_capacitor` | 备用核心电容 | 小电容、柔光 |
| `icon_relic_guard_manual` | 近卫手册 | 剑形书签与手册 |
| `icon_relic_bayonet_drill` | 刺刀操典 | 训练册与短刃 |
| `icon_relic_duelist_contract` | 决斗者契约 | 契约纸与单剑 |
| `icon_relic_sniper_scope` | 校准瞄具 | 瞄具镜片 |
| `icon_relic_recurve_string` | 复合弓弦 | 弓弦线圈 |
| `icon_relic_glass_barrel` | 玻璃枪管 | 透明枪管零件 |
| `icon_relic_caster_focus` | 术式焦镜 | 镜片与小法阵 |
| `icon_relic_mana_resonator` | 魔力谐振器 | 小谐振器 |
| `icon_relic_overclocked_core` | 过载法芯 | 过载核心，克制微光 |
| `icon_relic_defender_plate` | 加厚盾板 | 盾板 |
| `icon_relic_bastion_anchor` | 堡垒锚钉 | 锚钉与盾形底 |
| `icon_relic_compressed_bulwark` | 压缩壁垒装具 | 折叠护盾装置 |
| `icon_relic_travel_pack` | 远征背包 | 小背包 |
| `icon_relic_black_market_token` | 黑市代币 | 暗色代币，不要过黑 |
| `icon_relic_bounty_ledger` | 赏金账本 | 账本和小印章 |
| `icon_relic_greedy_seal` | 贪婪印章 | 印章与硬币 |
| `icon_relic_lumber_contract` | 木材契约 | 木纹契约牌 |
| `icon_relic_quarry_glyph` | 采石符文 | 石片符文 |
| `icon_relic_mana_siphon` | 魔力虹吸管 | 小玻璃虹吸管 |
| `icon_relic_industrial_blueprint` | 工业蓝图 | 蓝图纸和铅笔 |
| `icon_relic_aura_lens` | 光环透镜 | 淡色透镜 |
| `icon_relic_range_pylon` | 扩散塔芯 | 小塔芯 |
| `icon_relic_wallwright_kit` | 筑墙匠工具包 | 工具包与木钉 |
| `icon_relic_iron_patience` | 铁质耐心 | 铁片护符 |
| `icon_relic_rapid_recall` | 快速召回绳 | 收束绳结 |

### 6.8 地图与图例图标

| 资产 key | 对应 UI 部件 | 说明 |
|---|---|---|
| `icon_legend_enemy_path` | 右下图例 | 敌人路径 |
| `icon_legend_deploy_tile` | 右下图例 | 可部署地块 |
| `icon_legend_friendly_building` | 右下图例 | 我方建筑 |
| `icon_legend_blocker_tile` | 右下图例 | 阻挡单元 |
| `icon_legend_core_area` | 右下图例 | 核心区域 |
| `icon_map_marker` | 标记按钮/地图标记 | 玩家标记 |
| `icon_map_warning` | 非法部署/危险提示 | 警告 |
| `icon_map_range` | 攻击范围提示 | 范围 |

## 7. 重构顺序

1. 先确认顶部最左侧设置按钮和设置面板的节点归属，复用或迁移现有音量设置脚本，保证主音量、音乐、音效滑条可用。
2. 实现 `RelicStrip`、`RelicPanel`、`RelicIcon`、`RelicCard` 的无资产版本。
3. 把 `CombatHudController` 里的遗物 tooltip 文本迁到 `UiDisplayText` 和遗物组件。
4. 将 `BlessingPanel` 的三选一按钮改为遗物卡组件。
5. 按参考图重排 `CombatHud.tscn`，把设置按钮放到顶部最左，把 `RelicStrip` 放进顶部区域下方。
6. 调整 `UiLayoutRules`，保证设置按钮、遗物条、底部卡组、右侧详情在小屏不互相遮挡。
7. 生成并接入第一批分层资产：通用按钮、进度条、面板底板、backplate、frame、overlay、设置按钮/音量图标、资源图标、职业图标。
8. 再补齐建筑图标、技能图标、遗物图标、地图图例图标。
9. 用 1920x1080、1600x900、1366x768、1280x720 检查文本、按钮、卡片、tooltip、设置面板是否溢出。

## 8. 验收标准

- 已拥有遗物不再只藏在资源 tooltip 中，玩家能在顶部看到入口和数量。
- 任意遗物都能通过 hover 快速查看名称、稀有度和效果。
- 完整遗物面板能查看全部遗物，并支持按类别筛选。
- `BlessingPanel`、`RelicStrip`、`RelicPanel` 使用同一套遗物显示组件和同一套文案格式化规则。
- 顶部最左侧始终有小齿轮设置入口，点击后能打开音量设置面板并调整主音量、音乐和音效。
- 大面板资产只作为底板，头像框、图标框、进度条、按钮、列表项、状态高亮都由独立资产和节点分层叠放。
- 新资产接入后，删除资产仍能回退到文本占位，不影响项目运行。
