# UI_SYSTEM

## 1. 目标风格

UI 重构目标以参考图的战术 HUD 信息结构为准，但后续资产风格走轻微奇幻、清新、低饱和路线。界面应服务塔防读图，地图永远是第一视觉层级。

- 顶部最左侧：小齿轮设置按钮，点击打开设置面板；面板内可调整音量，并含“自动释放技能”开关。
- 顶部：阶段、时间、核心生命、部署上限、暂停/倍速、资源状态。信息应分布到整条顶部栏，避免全部挤在中央；资源状态必须拆为行动点、木材、石材、魔力、声望等独立资源项。
- 顶部下方：遗物入口与少量遗物缩略提示。
- 左侧：建筑/商店竖向面板，标签固定，列表项紧凑。
- 左侧商店：点击商品先预览干员详情并选中商品，再通过购买按钮确认购买；不得点击商品立即购买。
- 底部：待部署干员角色卡横向列表，卡片显示职业、费用、HP/SP/CD；底栏只做轻量承托背景，不固定卡槽数量。
- 右侧：上方为“今晚敌情”模块，含敌人/波次预告和出怪口覆盖面预览开关；中部为选中单位/干员/商店干员详情，含头像占位、属性、SP、技能说明、技能/撤退/购买按钮；右下固定为战场图例。
- 中心：地图、部署拖拽、落点锁定、朝向选择、攻击范围和路径提示。
- 白天底部/左下：`ActionPanel` 显示模式、探索、入夜、建筑维修/拆除/启停等上下文操作。

当前工程已接入 `assets/ui/generated/` 分层图片资产：面板、按钮、进度条、图标框、状态覆盖层通过统一样式与资源入口读取。正式 UI 资源由离线派生管线生成并保持稳定路径；缺图应在生成脚本或导入检查中暴露，组件脚本不得各自拼接图片路径或创建文字/纯色美术兜底。

### 1.1 顶层布局槽位

当前 UI 只支持 `1920x1080`。不要在脚本中实现移动端、小屏、宽屏响应式，也不要同时保留“场景树一套位置、脚本一套位置”的双重来源。

常驻顶层 UI 的位置、尺寸、锚点和边距由场景 Slot 节点控制：

- `scenes/game/Game.tscn` 的 `UI/ScreenLayout` 管理 `BuildPanelSlot`、`ActionPanelSlot`、`CombatHudSlot`。
- `scenes/game/Game.tscn` 的 `UI/FloatingLayer` 管理鼠标附近浮层，`UI/ModalLayer` 管理 `EventPanelSlot`、`BlessingPanelSlot`、`ResultPanelSlot`。
- `scenes/ui/combat/CombatHud.tscn` 的 `HudChromeLayer` 管理 `SettingsButtonSlot`、`TopHudSlot`、`RelicStripSlot`、`RightColumnSlot`、`DeployDeckSlot`。
- `scenes/ui/combat/CombatHud.tscn` 的 `PopupLayer` 管理 `SettingsPanelSlot`、`RelicPanelSlot`。

脚本不得定位常驻 HUD 模块，不得在运行时为这些模块写入 `position`、`size`、`anchor_*` 或 `offset_*`。脚本只负责数据绑定、文本/数值刷新、显隐、动态列表子项、信号转发和样式。

允许的动态几何例外：

- `DragGhost` 跟随鼠标。
- `MapInteractionPopup` 出现在鼠标附近并避开屏幕边缘。
- 核心、HP、SP 等进度条 fill 根据数值比例改变宽度。
- 演员头顶状态条跟随世界对象。
- Tooltip 跟随鼠标或目标节点。
- 图标在父控件内部居中。
- 文本或列表内容决定弹窗内部高度与滚动内容。

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

## 3. 当前需要修改的内容（已完成 / 历史）

> 本章为历史改造清单，下列 11 条均已落地：`scenes/ui/relic/` 下 `RelicIcon`/`RelicStrip`/`RelicPanel`/`RelicCard` 四套场景与 `scripts/ui/relic/` 对应脚本已建成，齿轮设置入口、`R` 键、`Esc` 关闭等交互均已实现。保留为改造背景参考；当前现状以 §6.2.3 场景层级和 §8 验收标准为准。

1. 新增 `scenes/ui/relic/RelicIcon.tscn` 与 `scripts/ui/relic/relic_icon.gd`，作为遗物小图标组件，支持 hover tooltip、稀有度框和新获得高亮。
2. 新增 `scenes/ui/relic/RelicStrip.tscn` 与 `scripts/ui/relic/relic_strip.gd`，放入 `CombatHud.tscn` 顶部状态栏下方，监听或接收遗物列表并显示入口。
3. 新增 `scenes/ui/relic/RelicPanel.tscn` 与 `scripts/ui/relic/relic_panel.gd`，显示完整遗物列表、筛选标签和效果详情。
4. 新增 `scenes/ui/relic/RelicCard.tscn` 与 `scripts/ui/relic/relic_card.gd`，用于 `RelicPanel` 中的单个遗物条目。
5. `CombatHud` 增加 `relic_panel_requested` 或直接持有 `RelicPanel` 显隐逻辑；`CombatHudController` 只负责把 `RunState` 的遗物列表同步给 HUD。
6. `CombatHudController` 当前资源 tooltip 中的“遗物 N / 当前遗物列表”保留为兜底，但完整查看迁移到 `RelicPanel`。
7. `UiDisplayText` 增加遗物稀有度、遗物分类标签和效果字段格式化方法，避免 `RelicPanel`、`BlessingPanel`、tooltip 各写一套文案。
8. `BlessingPanel` 改成使用 `RelicCard` 的选择态版本，让“获得遗物”与“查看遗物”视觉一致。
9. 顶层位置统一落到 `Game.tscn` 与 `CombatHud.tscn` 的 Slot 节点，确保 1920x1080 下不遮挡地图、左侧建筑栏和右侧详情。
10. 将设置入口固定到顶部最左侧：使用小齿轮按钮打开设置面板，设置面板至少包含主音量、音乐音量和音效音量滑条。
11. 补齐键鼠交互：`R` 打开/关闭遗物面板，`Esc` 优先关闭当前打开的遗物/设置面板，鼠标悬停显示 tooltip，点击遗物卡可展开详情。

## 4. 职责边界

### 场景负责

- 固定节点名与层级，例如 `TopBar`、`RelicStrip`、`DeployDeck`、`UnitDetailPanel`。
- 容器类型、基础锚点、控件语义和可复用组件模板。
- 单个组件内部的静态子节点，例如标签、按钮、进度条、图标占位框。

### 脚本负责

- 从 `RunState`、`DataRepo`、Manager 或传入参数读取状态。
- 调用 `GameUiStyle`、`UiFrameSpec` 应用统一样式；不得定位常驻 HUD 模块。
- 动态生成重复项，例如干员卡、建筑列表、商店槽位、遗物卡。
- 发出 UI 信号或把 UI 信号转接为 Manager 请求。

### 禁止

- 组件脚本自行加载 `res://assets/...` UI 图片。
- 在多个 UI 脚本重复维护职业、阶段、伤害类型、朝向、遗物稀有度等显示映射。
- 在 `.tscn` 固定一套布局，同时又在脚本中创建另一套同名结构。
- 脚本写入常驻 HUD 模块的 `position`、`size`、`anchor_*` 或 `offset_*`。
- 业务真相数据保存在 UI 节点里。

## 5. 现有 UI 基线

- `scripts/ui/app_theme.gd`：使用 Godot 默认字体，只设置字号、颜色和控件样式。
- `scripts/ui/game_ui_style.gd`：唯一主题入口，按语义组件请求 frame、按钮、进度条、滚动条和滑条样式。
- `scripts/ui/ui_frame_spec.gd`：集中维护 frame 资产 key、九宫格边距和内容边距；正式样式资源由离线派生管线重写。
- `scripts/ui/ui_tokens.gd`：断点、间距、字号和固定组件尺寸。
- `scripts/ui/ui_display_text.gd`：跨 UI 显示文本转换。
- `scripts/ui/ui_art_registry.gd`：统一图标接口，优先读取 JSON 中的显式路径，其次兼容旧字段和 catalog fallback。

## 6. UI 资产生成规范

残边清理、色板修正与九宫格边框拆分的历史整改已随资产管线落地（`#FF00FF` 色键、`UiFrameSpec` 九宫格切片、`UiArtRegistry` 统一解析）。本节只保留总规则；批量生图提示词和裁剪顺序见 `docs/UI_ASSET_GENERATION_PROMPTS.md`。

遗留待办：遗物 UI 尚未完成视觉微调，当前在实际界面中处于隐藏状态（`RelicStripSlot.visible = false`）。数据链路已接好（`CombatHudController` 通过 `set_relics` 同步遗物列表），仅视觉微调未完成；若打开 slot，记得删掉这条遗留待办。

### 6.1 通用要求

- 风格：轻微奇幻、战术 HUD、低饱和、暗色但不压抑，有少量木、石、布、浅金属、柔和魔法纹理即可。
- 背景：UI 源图色键统一使用高对比洋红 `#FF00FF`；最终入库 PNG 必须为透明背景。不要再使用接近 UI 主色的青绿背景作为 UI 色键。
- 色彩：主色以深冷灰、深青灰、雾蓝灰为主，浅金、琥珀、冷白、灰绿少量点缀；青绿色只能少量使用，不得成为大面积主色。
- 边框：边框要薄，圆角小，装饰克制。不要做厚重卷轴、黄金大框、宝石堆叠或过度雕花。可缩放边框必须通过九宫格、分段边线或程序化样式保证边宽稳定。
- 文字：资产内不得包含文字、数字、UI 文案或假按钮标签。
- 构图：图标主体居中，四周保留 12% 透明安全边距，64x64 缩略图下仍可辨认。
- 输出：源文件建议 512x512 或 1024x1024，入库导出为透明 PNG。可缩放框类资产必须提供九宫格切片建议，并在 `.tres` 或 `UiFrameSpec` 中记录 texture/content margin。

### 6.2 分层拆分原则

UI 资产默认按“底板、内容、覆盖框、状态层”拆分。凡是后续会被代码替换、裁剪、滚动、变长、变色或响应状态的内容，都不能烘在同一张大图里。

- 底板资产只负责整体材质和极薄边缘，不画具体数据区控件。
- 头像、建筑图标、技能图标、遗物图标这类内容图片必须夹在 `backplate` 和 `frame` 之间；`frame` 中心后续抠透明。
- 普通可缩放面板不要求额外拆出一张边框 PNG；优先让 `frame_*_base` 作为九宫格 `StyleBoxTexture`，用 `texture_margin` 保护边框，用 `content_margin` 保护内容区。
- 若边框装饰不适合九宫格，优先让美术重生成九宫格友好的源图；确实需要特殊状态时拆成独立 overlay，不在运行时创建临时美术兜底。
- 进度条必须拆为 `track`、`fill`、必要时的 `glow/overlay`，不得把填充比例画死。
- 列表容器只画承托背景，不画固定数量的卡槽；条目卡由代码动态生成。
- 选中、禁用、冷却、稀有度等状态优先做 overlay 或 state frame，不复制一张带内容的大图。
- 所有文字、数字、图标、头像、进度值、冷却值都由 Godot 节点绘制。
- 同父 `Control` 节点默认按树顺序后绘制覆盖前者；复杂部件可显式设置 `z_index`。

### 6.2.1 分层框架与控件资产

| 资产 key | 对应 UI 部件 | 建议规格 | 分层职责 |
|---|---|---:|---|
| `frame_top_status_chip_base` | 阶段、时间、核心、部署、资源信息块 | 240x64 | 单个状态信息块底板，内容与图标由节点叠放 |
| `frame_resource_item_base` | `TopBar/ResourceItem` | 88x44 | 单个资源项底板，用于行动点、木材、石材、魔力、声望等，避免全部挤在一个文本 Label 中 |
| `frame_resource_delta_badge` | `TopBar/ResourceDelta` | 76x24 | 资源增长/消耗速率小徽标，例如每分钟产出，不写数字 |
| `frame_speed_toggle_base` | 暂停/倍速容器 | 220x56 | 倍速切换底板，不写 `1X/2X`，不画固定文字 |
| `frame_settings_button_base` | 顶部最左侧设置按钮底 | 64x64 | 齿轮按钮底板，不画齿轮图标 |
| `frame_relic_strip_base` | `RelicStrip/Base` | 720x48 | 遗物摘要条底板，不画固定遗物槽 |
| `frame_relic_entry_button_base` | `RelicStrip/OpenButton` | 128x44 | “遗物 N”入口按钮底，不写文字数字 |
| `frame_left_sidebar_base` | `BuildPanel/Base` | 320x760 | 左侧建筑/商店栏底板，不内置页签和列表项 |
| `frame_sidebar_tab_base` | 建筑/商店页签普通态 | 160x48 | 页签底板，不写文字 |
| `frame_sidebar_tab_selected_overlay` | `BuildListCard/CardBase` | 280x104 | 建筑列表项底板；保留稳定旧文件名，但当前语义不是页签 overlay |
| `frame_build_list_card_base` | `ShopUnitCard/CardBase` | 280x104 | 商店 Unit 商品卡底板；与建筑卡分场景静态引用，不在运行时切换 |
| `frame_build_icon_backplate` | `BuildListCard/IconBackplate` | 72x72 | 建筑图标下方暗底 |
| `frame_build_icon_frame` | `BuildListCard/IconFrame` | 72x72 | 建筑图标上方覆盖框，中心可抠空 |
| `frame_cost_badge_base` | 建造/部署/商店成本徽标 | 56x32 | 成本数字底，不写数字和资源图标 |
| `frame_bottom_deploy_rail_base` | `DeployDeck/Base` | 980x176 | 底部待部署区承托背景，不画固定卡槽 |
| `frame_operator_card_base` | `OperatorCard/Base` | 164x148 | 单张干员卡底板，不内置头像框、状态行或费用角标 |
| `frame_operator_card_selected_overlay` | `OperatorCard` 选中/拖拽态 | 164x148 | 选中叠层，轻描边/内光 |
| `frame_operator_card_deployed_overlay` | `OperatorCard` 已部署态 | 164x148 | 已部署状态叠层 |
| `frame_operator_card_cooldown_overlay` | `OperatorCard` 未选中冷却态 | 164x148 | 冷却遮罩，不写冷却数字，不带选中高亮 |
| `frame_operator_card_cooldown_selected_overlay` | `OperatorCard` 选中冷却态 | 164x148 | 冷却遮罩叠加轻微选中提示，不写冷却数字 |
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
| `frame_relic_card_base` | `RelicCard/Base` | 360x112 | 遗物卡底板，不内置稀有度边、图标框或文本 |
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
| `frame_map_popup_base` | `MapInteractionPopup/Base` | 360x260 | 地图交互弹窗底板，不画固定按钮 |
| `frame_wave_preview_base` | 波次/出怪口覆盖面预览 | 360x220 | 波次信息窗底板，不画敌人条目 |
| `frame_wave_enemy_row_base` | `WavePreviewPanel/EnemyRow` | 320x32 | 今晚敌情中的单条敌人/波次条目底，不写文字数字 |
| `frame_wave_route_toggle_base` | `WavePreviewPanel/RouteToggle` | 120x32 | 出怪口覆盖面预览开关底，必须放在敌情模块内部标题行 |
| `frame_wave_warning_row_base` | `WavePreviewPanel/WarningRow` | 320x32 | 路线异常/堵路警告行底 |
| `frame_legend_panel_base` | 右下战场图例 | 260x220 | 图例面板底板，不画固定图例行 |
| `frame_legend_row_base` | 图例行底 | 220x28 | 单条图例行底，不画图标文字 |

### 6.2.2 关键部件推荐层级

- `TopBar`
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
- `WavePreviewPanel`
  “今晚敌情”是独立 HUD 模块，不是 tooltip。结构为 `WavePreviewBase`、标题行、出怪口覆盖面预览开关、敌人条目/路线警告/正文。开关必须位于模块标题行内部。开关打开时，地图不画路线“线条”，而是把每个出怪口的可达范围画成逐格覆盖面填充 + 按口同心轮廓：单口格用该口色淡填，多口格用混色加深，每口再沿自己边界向内缩一圈描轮廓，因此即便两口完全重合也呈同心彩环、永不互相遮盖、能数出几个口。每个出怪口一片异色覆盖，开关只切换显隐。覆盖面、段头、徽标三处共用 `GameUiStyle.route_color_for_spawn_key`（按出怪口编号定色）。
- `ActionPanel`
  白天上下文操作面板，显示探索、入夜和建筑操作。它属于当前游戏已有 UI 元素，需要纳入布局与资产规范；不要让它与 `BuildPanel`、底部干员卡或地图弹窗互相遮挡。

### 6.2.3 场景层级与绘制顺序

重构目标不是把图片直接盖在现有控件上，而是把场景树整理成稳定的 UI 骨架。场景负责节点层级和可替换资产槽位，脚本负责状态、文本、列表数据和信号。

#### `Game/UI` 顶层

`Game.tscn` 当前已有 `UI` 作为 `CanvasLayer`。推荐保持这个入口，并让可视节点按下列顺序组织；若短期不移动现有节点，也必须用 `z_index` 保证相同绘制顺序。

```text
UI (CanvasLayer)
├─ ActionPanel                 # 白天上下文操作，z_index 15
├─ BuildPanel                  # 左侧建筑/商店栏，z_index 20
├─ CombatHud                   # 作战 HUD 主体，z_index 30
├─ DetailPreviewLayer          # 干员/单位详情置顶层，可在 CombatHud 内实现，z_index 55
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
│  ├─ BulletTimeOverlay        # 垫底氛围层 z_index -6，Tint + 四边带，mouse_filter IGNORE
│  ├─ SettingsButton
│  ├─ TopBar
│  ├─ RelicStrip
│  └─ RightColumnSlot
│     └─ RightColumnVBox       # 右侧列三块按 VBox 顺序排布、互斥显隐
│        ├─ WavePreviewPanel
│        ├─ UnitDetailPanel
│        └─ LegendPanel
├─ InteractionLayer (Control, z_index 30)
│  └─ DragGhost
├─ PopupLayer (Control, z_index 70)
│  ├─ RelicPanel
│  └─ AudioSettingsPanel
└─ TooltipLayer (Control, z_index 100)
```

右侧列没有独立的详情分层：`WavePreviewPanel`、`UnitDetailPanel`、`LegendPanel` 三者都是 `HudChromeLayer/RightColumnSlot/RightColumnVBox` 的直接子节点，靠 VBox 顺序和互斥显隐排布——详情卡与敌情面板互斥占据同一格，不是靠 `z_index` 分层叠放。`InteractionLayer`、`PopupLayer`、`TooltipLayer` 仍是 `CombatHud` 的直接子节点。`DeployDeck` 与底栏由 `Game.tscn` 的 `DeployDeckSlot` 承载，不在 `HudChromeLayer` 内。脚本中已有 `%SettingsButton`、`%TopBar`、`%RelicStrip`、`%DeployDeckContainer`、`%UnitDetailPanel`、`%RelicPanel`、`%AudioSettingsPanel`、`%DragGhost` 等引用；重构时若移动节点，必须保留 `unique_name_in_owner` 或同步更新脚本引用。

#### `TopBar`

```text
TopBar
└─ TopContent
   └─ TopContentRow
      ├─ LeftStatusGroup
      │  ├─ StageChip
      │  │  ├─ ChipBase        # frame_top_status_chip_base
      │  │  ├─ PhaseIcon
      │  │  └─ QueueLabel
      │  ├─ CoreChip
      │  │  ├─ ChipBase
      │  │  ├─ CoreIcon
      │  │  ├─ CoreLabel
      │  │  ├─ CoreTrack       # bar_progress_track
      │  │  └─ CoreFill        # bar_progress_fill_core
      │  └─ DeployChip
      │     ├─ ChipBase
      │     ├─ DeployIcon
      │     └─ DeployLabel
      ├─ TopSpacerLeft
      ├─ CenterTimeGroup
      │  ├─ MessageChip
      │  └─ TimeControls
      │     ├─ SpeedToggleBase # frame_speed_toggle_base
      │     ├─ SpeedActiveOverlay
      │     ├─ PauseButton
      │     ├─ Speed1Button
      │     └─ Speed2Button
      ├─ TopSpacerRight
      └─ RightResourceGroup
         ├─ ActionPointItem
         ├─ WoodItem
         ├─ StoneItem
         ├─ ManaItem
         └─ PrestigeItem
```

`SettingsButton` 固定在顶部最左侧，不放入 `TopBar` 内部挤占状态信息。按钮结构为 `ButtonBase -> icon_settings_gear`，点击打开 `AudioSettingsPanel`。顶部栏不得把所有 chip 居中堆在一起；`LeftStatusGroup` 靠左，`CenterTimeGroup` 居中，`RightResourceGroup` 靠右，两个 spacer 使用 `size_flags_horizontal = EXPAND_FILL`。

`RightResourceGroup` 中每个资源项推荐结构：

```text
ResourceItem
├─ ResourceItemBase            # frame_resource_item_base
├─ ResourceIcon
├─ ValueLabel
└─ DeltaBadge                  # 可选，frame_resource_delta_badge
   └─ DeltaLabel
```

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
├─ CardBase                    # 建筑卡为 frame_sidebar_tab_selected_overlay；商店 Unit 卡为 frame_build_list_card_base
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

商店模式下 `BuildListCard` 也用于干员商品。交互必须改为两步：

1. 单击商品卡：只选中该商品并在 `UnitDetailPanel` 中显示干员配置预览，不购买。
2. 再次点击当前已选商品的购买按钮，或点击 `UnitDetailPanel`/`BuildPanel` 中明确的 `PurchaseButton`：才发送购买请求。

商店干员预览应复用右侧详情卡，展示职业、费用、HP/SP、攻击、防御、法抗、阻挡、攻速、技能和购买价格。已售出或声望不足的商品仍可预览，但购买按钮禁用并显示原因。

```text
ShopMode
├─ BuildCardList
│  └─ ShopUnitCard
│     ├─ CardBase
│     ├─ IconBackplate
│     ├─ UnitIcon / PortraitTexture
│     ├─ IconFrame
│     ├─ NameLabel
│     ├─ Class/Tier/Cost
│     ├─ SelectedOverlay
│     └─ DisabledOverlay
└─ PurchaseBar
   ├─ SelectedUnitSummary
   └─ PurchaseButton
```

`PurchaseBar` 可以先用现有 `BottomControls` 承载；若短期不新增按钮，则必须让右侧 `UnitDetailPanel` 在商店预览模式下显示购买按钮。

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
├─ CooldownOverlay
├─ CooldownSelectedOverlay
└─ CooldownLabel
```

`PortraitTexture` 位于 `PortraitBackplate` 和 `PortraitFrame` 之间。没有头像资源时可隐藏 `PortraitTexture`，显示 `PortraitLabel` 或默认占位。

底部干员卡交互建议区分“单击预览”和“拖拽部署”：

- 单击或短按：选中干员并在 `UnitDetailPanel` 显示干员配置/当前状态预览。
- 按下并移动超过拖拽阈值：开始部署拖拽。
- 已部署干员单击：显示部署单位详情并显示技能/撤退按钮。
- 冷却中干员单击：仍显示详情，但行动按钮禁用并显示冷却原因。

`OperatorCard` 根节点的 `custom_minimum_size`、实际 `size`、点击区域和视觉 `CardBase` 必须一致。`SelectedOverlay`、`DeployedOverlay`、`CooldownOverlay`、`CooldownSelectedOverlay`、`PortraitFrame` 等覆盖层 `mouse_filter = IGNORE`，不得扩大或拦截命中区域。冷却但未选中时显示 `CooldownOverlay`；冷却且选中/预览时隐藏 `CooldownOverlay` 并显示 `CooldownSelectedOverlay`，避免把选中态与冷却态写死在同一张通用图里。

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

`UnitDetailPanel` 有三种显示来源：

- `deployed_unit`：地图上已部署单位，显示技能按钮和撤退按钮。
- `owned_operator_preview`：底部干员卡或未部署干员预览，显示部署状态、费用、属性、技能；技能/撤退按钮隐藏或禁用。
- `shop_unit_preview`：左侧商店干员预览，显示购买价格和购买按钮；不允许通过点击商品卡直接购买。

`PanelBase` 必须覆盖 `UnitDetailPanel` 的完整 `rect`，包括底部 `Actions`。如果内容高度不足或小屏下超出，应把 `MainVBox` 放入 `ScrollContainer` 或压缩 section 间距，不能让底部按钮落到背景外。`UnitDetailPanel` 的绘制层级必须高于 `LegendPanel`、`WavePreviewPanel` 和 `DeployDeck`。

#### `WavePreviewPanel`（今晚敌情）

```text
WavePreviewPanel
├─ WavePreviewBase             # frame_wave_preview_base
└─ WavePreviewMargin
   └─ WavePreviewContent
      ├─ WavePreviewHeader
      │  ├─ WavePreviewTitleLabel
      │  └─ WaveRouteToggle    # 必须在 header 内
      ├─ WaveLevelNameLabel    # 运行时补齐，显示当晚关卡名
      ├─ WaveLevelDescLabel    # 运行时补齐，显示完整关卡预览文案
      ├─ WaveSummaryLabel      # 运行时补齐，显示总数、活跃出怪口 N 和关键敌人摘要
      ├─ WavePreviewScroll
      │  └─ WaveSpawnCardsBox  # 运行时补齐，按刷怪点分组显示敌人 mini-card：左侧数量/时间窗/基础数值/特性标签，右侧保留更大的怪物预览。多波夜晚按"第 N 波 · 模板名 · 主攻 Sx"分段展示，单波回退聚合卡片（主攻口仍标注）。各出怪口段头按编号异色（`GameUiStyle.route_color_for_spawn_key`，与地图覆盖面、徽标共用色源）并在左缘加同色竖条，使侧栏本身即图例。悬停段卡 emit `wave_spawn_segment_hovered(spawn_key)`，联动地图高亮该口覆盖面并压暗其余口；段卡内子控件全置 `mouse_filter = IGNORE` 以保证整段稳定可悬停。
      ├─ WaveWarningLabel      # 运行时补齐，显示路线异常/拆墙提示
      └─ WavePreviewLabel      # 旧文本兜底；V2 数据可用时隐藏
```

“今晚敌情”模块和 `UnitDetailPanel` 共用最右侧列，但二者互斥显示：没有选中干员、商店商品或场上单位时，`WavePreviewPanel` 占满右侧列；打开任意干员详情时，`WavePreviewPanel` 隐藏，`UnitDetailPanel` 占满右侧列。`WaveRouteToggle` 不得漂在模块外部。敌情预览不需要为详情卡预留空间，详情卡也不需要为敌情预留空间。

夜晚关卡模板的完整文案必须放在 `WaveLevelDescLabel` 中。开局横幅只是一闪而过的气氛提示，不能成为唯一承载剧情或关键信息的位置。路线异常文案保留在敌情面板内；普通路线被完全封闭时，提示使用“普通路线封闭：敌人将改走拆墙路径”，而不是把它当作不可继续游戏的阻塞错误。

#### `LevelIntroBanner`

`LevelIntroBanner` 由 `CombatHud.gd` 在运行时创建，位于 HUD 上层，`mouse_filter` 为 `IGNORE`，不阻挡地图和按钮输入。它在白天开始、模板已解析后播放短暂入场动画，内容包括：

- `LevelIntroDayLabel`：当前天数。
- `LevelIntroNameLabel`：当晚关卡名。
- `LevelIntroDescLabel`：与右上角敌情面板一致的关卡预览文案，可用于检查多行显示。

由于横幅显示时间很短，所有需要玩家反复查看的信息仍以 `WavePreviewPanel` 为准。

#### `WaveCountdownRow`

`WaveCountdownRow` 由 `CombatHud.gd` 在运行时通过 `set_wave_countdown` 创建，位于 HUD 顶部居中、`mouse_filter` 为 `IGNORE`，在波间喘息期显示“下一波 N 秒”。倒计时结束或传入负值时隐藏，不阻挡地图和按钮输入。

#### `LegendPanel`

```text
LegendPanel
├─ LegendBase                  # frame_legend_panel_base
└─ LegendMargin
   └─ LegendVBox
      ├─ LegendTitleLabel
      └─ LegendRows
         ├─ EnemyPathRow
         ├─ DeployTileRow
         ├─ FriendlyBuildingRow
         ├─ BlockerRow
         └─ CoreAreaRow
```

`LegendPanel` 必须锚定右下角，位于 `DeployDeck` 上方或右侧安全间距内，不得与 `UnitDetailPanel`、`WavePreviewPanel`、`DeployDeck` 重叠。若右侧详情卡可见且空间不足，优先缩小或隐藏图例，而不是遮住详情卡。

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
      ├─ SfxRow
      └─ AutoSkillRow
         ├─ RowBase
         ├─ SkillIcon
         ├─ AutoSkillLabel
         └─ AutoSkillButton    # toggle，开关“自动释放技能”
```

设置面板底板不画具体三条滑杆。当前继续使用 Godot `HSlider`，但 track/fill/handle 通过统一主题资产替换。除三条音量滑条外，面板还含一个“自动释放技能”开关行 `AutoSkillRow`，因此设置面板不止音量。

#### `ActionPanel`

```text
ActionPanel
└─ ContentMargin
   └─ MainVBox
      ├─ ModeLabel
      ├─ ActionButtonFlow
      │  ├─ IdleButton
      │  ├─ ExploreButton
      │  └─ StartNightButton
      ├─ BuildingActionFlow
      │  ├─ RepairBuildingButton
      │  ├─ DemolishBuildingButton
      │  └─ ToggleBuildingButton
      └─ BuildingInfoLabel
```

`ActionPanel` 是白天/建筑上下文操作入口，应纳入布局计算。它不能与 `BuildPanel`、`MapInteractionPopup` 或 `DeployDeck` 重叠。夜晚若不使用，应隐藏或收起，不保留空白遮挡区域。

#### 弹窗类面板

`MapInteractionPopup`、`EventPanel`、`BlessingPanel`、`ResultPanel`、`DialogPanel` 都遵循同样结构：`PanelBase` 只做底，标题、文本、选项、统计行、按钮都是独立节点。候选项或统计项必须动态生成，不在背景图里画固定数量。

点到出怪口格时，`MapInteractionPopup` 额外补一段出怪口来源信息：显示该口今晚的活跃/沉默态，以及动态封堵入口 `GateSealButton`（封一晚，成本石 N + 行动力 N，按资源余额和当天可封次数校验是否可用；沉默口、仅剩一个活跃口、非白天阶段等情况按钮禁用并显示原因）。

#### 脚本兼容要求

- 保留当前脚本使用的 `%NodeName`，或在同一提交中同步修改对应脚本。
- 保留现有信号：`operator_card_pressed`、`operator_card_drag_started`、`operator_sell_requested`、`pause_pressed`、`speed_1_pressed`、`speed_2_pressed`、`cast_skill_requested`、`retreat_requested`、`wave_route_preview_toggled`、`wave_spawn_segment_hovered(spawn_key)`、`RelicStrip.panel_requested`、`RelicPanel.close_requested`。
- 商店重构需要新增或等价实现两个语义：`shop_unit_preview_requested(slot_index, unit_id)` 和 `shop_unit_purchase_requested(slot_index)`。预览信号不得购买，购买信号必须来自明确的购买按钮或二次确认。
- 右侧详情需要支持 `show_unit(unit)`、`show_operator_preview(operator_key/unit_id)`、`show_shop_unit_preview(slot_index, unit_id, price)` 三类入口，具体方法名可按代码风格调整，但语义必须分清。
- `CombatHud` 负责显示和转发 UI 信号，`CombatHudController` 负责把 Manager/RunState 数据同步到 HUD；不要把业务状态塞进 UI 节点。
- 正式 UI 不提供无资产美术兜底。新增的 `TextureRect`、overlay、backplate、frame 必须通过 `assets/ui/generated/` 与 `assets/ui/styles/` 的稳定资源接入，并由离线派生脚本保证文件存在。

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

## 7. 重构顺序（已完成 / 历史）

> 本章记录原定的重构落地顺序，下列步骤均已完成，遗物条仅剩视觉微调（见 §6 遗留待办）。保留为历史参考，不再是待办清单。

1. 先确认顶部最左侧设置按钮和设置面板的节点归属，复用或迁移现有音量设置脚本，保证主音量、音乐、音效滑条可用。
2. `RelicStrip`、`RelicPanel`、`RelicIcon`、`RelicCard` 使用遗物数据中的 `icon_path`，并保留无资产兜底。
3. 把 `CombatHudController` 里的遗物 tooltip 文本迁到 `UiDisplayText` 和遗物组件。
4. 将 `BlessingPanel` 的三选一按钮改为遗物卡组件。
5. 按参考图重排 `CombatHud.tscn`，把设置按钮放到顶部最左，把 `RelicStrip` 放进顶部区域下方。
6. 重排顶部状态栏为左侧状态组、中央时间/倍速组、右侧资源组，资源组拆成行动点、木材、石材、魔力、声望等独立资源项。
7. 调整右侧列：`WavePreviewPanel` 在上方且出怪口覆盖面预览开关位于标题行，`UnitDetailPanel` 在中部且层级最高，`LegendPanel` 固定右下角且不遮挡详情。
8. 重构商店交互为“点击预览、按钮购买”，并让商店干员与底部干员卡都能打开右侧详情预览。
9. 修正 `OperatorCard` 根节点、视觉卡面和鼠标命中区域一致，overlay 不拦截输入。
10. 调整 `Game.tscn` 与 `CombatHud.tscn` 的 Slot，保证设置按钮、遗物条、今晚敌情、底部卡组、右侧详情、右下图例在 1920x1080 下不互相遮挡。
11. 生成并接入第一批分层资产：通用按钮、进度条、面板底板、backplate、frame、overlay、设置按钮/音量图标、资源图标、职业图标。
12. 再补齐建筑图标、技能图标、遗物图标、地图图例图标。
13. 用 1920x1080 检查文本、按钮、卡片、tooltip、设置面板是否溢出。

## 8. 验收标准

- 已拥有遗物不再只藏在资源 tooltip 中，玩家能在顶部看到入口和数量。
- 任意遗物都能通过 hover 快速查看名称、稀有度和效果。
- 完整遗物面板能查看全部遗物，并支持按类别筛选。
- `BlessingPanel`、`RelicStrip`、`RelicPanel` 使用同一套遗物显示组件和同一套文案格式化规则。
- 顶部最左侧始终有小齿轮设置入口，点击后能打开设置面板并调整主音量、音乐和音效，并切换“自动释放技能”开关。
- 顶部状态栏不再集中挤在中间；资源信息拆为独立资源项，行动点、木材、石材、魔力、声望等可分别扫描。
- “今晚敌情”模块上移到右侧详情上方，出怪口覆盖面预览开关位于模块内部标题行。
- 战场图例固定在右下角，不与右侧详情、今晚敌情或底部干员栏重叠。
- 右侧详情卡底板覆盖完整高度，底部按钮和所有栏目都在背景内。
- 底部干员卡、已部署单位、左侧商店干员都能打开右侧详情；右侧详情层级高于图例、底部栏和敌情模块。
- 商店商品点击只预览并选中，购买必须通过明确购买按钮或二次确认。
- 底部干员卡视觉大小、Control 尺寸和鼠标命中区域一致，覆盖层不拦截鼠标。
- 大面板资产只作为底板，头像框、图标框、进度条、按钮、列表项、状态高亮都由独立资产和节点分层叠放。
- 新资产接入后，删除资产仍能回退到文本占位，不影响项目运行。
