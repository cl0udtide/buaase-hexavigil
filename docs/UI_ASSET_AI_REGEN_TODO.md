# UI Asset AI Regeneration TODO

本文档只记录经过现有素材逐张筛查后仍需要 AI 或美术重生成的 UI 框架源素材。不要再默认全量重生 84 个 `stylebox_texture` 资源；每次只处理下表中的一小组，并在替换前完成裁切、alpha、品红残留、分层和九宫格检查。

## 筛查结论

当前优先问题分两类：

1. **上下、左右边框不干净，不适合九宫格拉伸。**
   很多素材把菱形、徽章、铆钉、机械板、中心牌匾、分隔柱、固定槽位放在四边中段。Godot `StyleBoxTexture` 拉伸时这些细节会被压扁、重复或变形。需要重生成边中段连续、干净、可重复的版本；如果确实需要装饰，装饰应拆成额外 overlay 或角部素材，不要烘进可拉伸边。

2. **卡片内的卡片边框与外卡片过于重复，缺少层级设计。**
   一些内层卡片、属性行、标题条、按钮、徽标直接复制外层卡框语言，导致 UI 像一堆同款边框互相套娃。重生成时必须结合实际节点结构与位置：外层容器更安静，内层卡片更轻，属性行/标题条更简洁，按钮更像可点击件，overlay 只表达状态。

硬性通过项：所有候选 PNG 必须只有 `{0,255}` alpha，且不透明像素中不能残留品红背景。背景去除必须走 `scripts/dev/crop_ui_assets.py` 或基于它的现有裁切逻辑。

## 工作流

1. 先确认目标 key 在 `scenes/` 与 `scripts/` 中的实际位置和层级职责。
2. 生图前必须为每个小组准备明确上下文包：asset key、目标 UI 节点路径、实际用途、target/base size、当前 source 预览、相邻父子层级、对应 template margins、必须避开的旧图问题。
3. 提示词必须引用具体参考：同一 UI 区域中应保持的外层/内层/按钮/信息条层级关系，以及可以参考或必须区别开的现有素材。
4. 子 Agent 可以并行生图，但只能输出到临时目录，例如 `tmp/ui_regen_workers/<worker>/raw/` 与 `tmp/ui_regen_workers/<worker>/candidate/`。
5. 主 Agent 串行验收：只接收通过检查的候选图，并只替换 `assets/ui/source/<asset_key>.png`。
6. 保存 raw sheet 到 `assets/raw/`，文件名稳定英文；正式替换后运行派生脚本生成 `generated/styles`。
7. 不直接手改 `assets/ui/generated/` 或 `assets/ui/styles/`；它们只由派生脚本写入。

## 通用重生成规则

- 背景必须是纯 `#FF00FF`，裁切入库后背景完全透明。
- 不得生成或保留半透明像素；最终 PNG alpha 只能是 `0` 或 `255`。
- 不得有文字、数字、字母、水印、签名、假 UI 文案、固定列表、固定按钮组、固定进度。
- `*_base` 只做底板或承托，不画运行时内容。
- `*_overlay` 只做状态叠层，不复制底板，不带实心卡面。
- `*_backplate` 是内容下方托盘，中心应干净可放图标/头像。
- `*_frame` 是内容上方覆盖框，中心必须是透明孔洞。
- 进度条与滑条必须拆成 track/fill/handle，不画固定百分比；handle 必须是独立拖柄。
- 九宫格边中段必须连续、干净、可重复。徽章、菱形、铆钉、独特机械板、断裂结构、中心牌匾只能放四角，或拆成额外 overlay。

## 需要优先重生成的资源

| Asset | 位置/用途 | 问题类型 | 重生成重点 |
|---|---|---|---|
| `frame_button_base` | 通用按钮底板 | 边中段菱形/装饰不适合九宫格 | 保留可点击感；上下左右边中完全连续，装饰只在四角。 |
| `frame_button_primary_overlay` | 主按钮状态 | overlay 过像完整边框，边中有装饰 | 透明中心，只保留轻描边/高亮；不复制底板。 |
| `frame_button_danger_overlay` | 危险按钮状态 | overlay 过像完整边框，边中有装饰 | 透明中心，危险色只做描边或角部状态。 |
| `frame_button_disabled_overlay` | 禁用按钮状态 | overlay 过像完整边框，边中有装饰 | 透明中心或硬边遮罩，不用半透明像素。 |
| `frame_tooltip_base` | Tooltip 底板 | 上下边中段有徽章/牌匾 | 大面积中心干净；边中连续。 |
| `frame_icon_backplate` | 通用图标背板 | 四边中点菱形装饰 | 作为固定托盘可有角装饰，但不要边中徽章。 |
| `frame_icon_frame` | 通用图标覆盖框 | 四边中点菱形装饰 | 中心孔洞透明；边中干净。 |
| `frame_scroll_thumb` | 滚动条拖块 | 中段刻线/端饰拉伸风险 | 端点固定，中段纯净可拉伸。 |
| `bar_progress_track` | HP/SP/Core 底轨 | 边中固定板件/刻线 | 左右端帽固定，中段连续暗槽。 |
| `bar_progress_fill_hp` | HP 填充 | 像完整满条，运行时裁剪风险 | 不画固定百分比；中段连续，颜色可由运行时裁剪/缩放使用。 |
| `bar_progress_fill_sp` | SP 填充 | 像完整满条，运行时裁剪风险 | 同上，避免右端固定装饰被裁断。 |
| `bar_progress_fill_core` | Core 填充 | 像完整满条，运行时裁剪风险 | 同上。 |
| `frame_slider_track` | 设置滑条轨道 | 中段固定刻线/板件 | 左右端帽固定，中段连续。 |
| `frame_slider_fill` | 设置滑条填充 | 中段固定装饰/固定比例感 | 完整可裁剪填充，不画百分比。 |
| `frame_slider_handle` | 设置滑条拖柄 | 画成横向滑轨，不是独立 handle | 生成接近 40x40 的独立拖柄。 |
| `frame_top_status_bar_base` | 顶部状态栏 | 中段固定槽/板件 | 只做整条承托，不画固定 chip 或槽位。 |
| `frame_top_status_chip_active_overlay` | 顶部 chip 状态 | 侧板过重，像复制底板 | 透明中心，轻描边/角部高亮。 |
| `frame_speed_toggle_base` | 倍速容器 | 画死固定分段 | 只做一个容器底板，分段由节点或 overlay 表达。 |
| `frame_speed_toggle_active_overlay` | 倍速选中态 | 画成整组 overlay | 单个 110x52 可移动选中层，不带整组结构。 |
| `frame_relic_strip_base` | 遗物摘要条 | 中段固定面板/槽位 | 长条承托，不能画固定遗物槽。 |
| `frame_left_sidebar_base` | 左侧建筑栏 | 边中段灯条/机械块拉伸风险 | 外层侧栏要安静、薄、背景化。 |
| `frame_sidebar_tab_base` | 左侧页签底 | 过像卡片，边中装饰 | 页签应比列表卡轻，边中连续。 |
| `frame_sidebar_tab_selected_overlay` | 左侧页签选中 | 复制完整底板/飘带 | 透明状态层，不带实心底。 |
| `frame_build_list_card_base` | 建筑列表项 | 造型可参考但需确认边中与内层关系 | 保留战术感；内容区要承托，不要只是空心外框。 |
| `frame_bottom_deploy_rail_base` | 底部部署栏 | 方向/语义错误风险 | 必须是宽横向 rail，不画固定卡槽。 |
| `frame_operator_card_base` | 干员卡底 | 与 rail/内层卡重复，语义错位 | 竖向卡片；外层卡面明确但不内置头像框/费用/属性。 |
| `frame_operator_card_selected_overlay` | 干员卡选中 | 完整边框式 overlay | 只做轻描边/角部高亮，不复制卡底。 |
| `frame_operator_card_deployed_overlay` | 干员卡已部署 | 完整边框式 overlay | 状态色/角标叠层，不带底板。 |
| `frame_operator_card_cooldown_overlay` | 干员卡冷却 | 复制完整实心底板 | 使用硬边遮罩/线性遮挡层，不写冷却数字。 |
| `frame_operator_card_cooldown_selected_overlay` | 冷却且选中 | 完整边框式 overlay | 冷却遮罩 + 轻选中提示，透明中心。 |
| `frame_operator_title_strip` | 干员卡标题条 | 像小面板，层级太重 | 做轻量嵌入式标题条，不复制外卡边框。 |
| `frame_operator_portrait_backplate` | 干员头像背板 | 与 frame 职责混淆 | 必须是横向 128x72 不透明托盘。 |
| `frame_operator_portrait_frame` | 干员头像框 | 中心孔洞/比例需严格 | 横向 128x72 覆盖框，中心透明。 |
| `frame_operator_stat_row` | 干员属性行 | 边中装饰过重 | 更轻、更低对比，像嵌入式信息槽。 |
| `frame_right_detail_sidebar_base` | 右侧详情栏 | 边中灯条/机械块拉伸风险 | 外层侧栏背景化，少装饰。 |
| `frame_unit_header_strip` | 单位详情标题条 | 上下边中牌匾/灯条 | 标题条应轻量，边中连续。 |
| `frame_detail_section_base` | 详情分组底 | 上下中心牌匾 | 分组底比外框更轻，不要复制卡片边框。 |
| `frame_unit_stat_row` | 单位属性行 | 边中灯条/装饰 | 嵌入式信息行，低对比，边中干净。 |
| `frame_skill_desc_box` | 技能描述框 | 上下中心牌匾 | 描述框中心干净，边中连续。 |
| `frame_relic_panel_base` | 遗物面板 | 上下中心徽章/边中装饰 | 大面板更安静，装饰拆角或 overlay。 |
| `frame_relic_filter_tab_base` | 遗物筛选 tab | 边中牌匾/侧板 | 小 tab 更轻，不能像完整卡片。 |
| `frame_relic_filter_selected_overlay` | 筛选选中 | 复制完整 tab 边框 | 透明状态层，轻描边。 |
| `frame_relic_card_base` | 遗物卡 | 上下徽章/侧板拉伸风险 | 与面板区分，作为中层卡片，不内置图标框/文本。 |
| `frame_relic_card_hover_overlay` | 遗物卡 hover | 完整卡框式 overlay | 只做高亮/描边，不复制 card base。 |
| `frame_relic_rarity_common_overlay` | 常见稀有度 | 完整边框/侧板 | 稀有度应是轻叠层，不是另一个卡框。 |
| `frame_relic_rarity_uncommon_overlay` | 精良稀有度 | 完整边框/侧板 | 同上，颜色可运行时或轻描边体现。 |
| `frame_relic_rarity_rare_overlay` | 稀有稀有度 | 完整边框/侧板 | 同上，避免厚金框。 |
| `frame_settings_panel_base` | 设置面板 | 四边中段机械板/螺丝 | 弹窗底板中心干净，边中连续。 |
| `frame_settings_row_base` | 设置项行 | 上下边中固定机械块 | 设置行应轻量，像嵌入式行底。 |
| `frame_blessing_panel_base` | 祝福面板 | 顶/底中段宝石装饰 | 大面板装饰拆角或 overlay。 |
| `frame_blessing_choice_card_base` | 祝福候选卡 | 方向错误，需横向 560x112 | 横向候选卡，区别于遗物卡但同家族。 |
| `frame_event_panel_base` | 事件面板 | 顶部固定状态条/刻度 | 不画固定标题条或内容结构。 |
| `frame_event_choice_button_base` | 事件选项按钮 | 比例错误/假刻痕 | 横向 560x64 按钮底，不写文字。 |
| `frame_map_popup_base` | 地图弹窗 | 像窄条，不是面板 | 360x260 弹窗底板，中心可放动态按钮。 |
| `frame_dialog_speaker_plate_base` | 对话说话人名牌 | 边中装饰过重 | 名牌底板轻量，不能画名字。 |
| `frame_result_panel_base` | 结算面板 | 过扁，目标是高面板 | 720x520 高面板，不画统计项。 |
| `frame_result_stat_row_base` | 结算统计行 | 高度/边饰过重 | 600x44 细行，内层信息槽风格。 |
| `frame_wave_preview_base` | 今晚敌情面板 | 边中刻度/状态灯 | 不画固定敌人条目或路线槽。 |
| `frame_legend_panel_base` | 图例面板 | 上下中心 tab 装饰 | 小面板边中连续。 |
| `frame_legend_row_base` | 图例行 | 端部装饰占比过大 | 220x28 极细行，细节简化。 |
| `frame_resource_item_base` | 顶部资源项 | 左右固定盒状结构抢内容区 | 小资源项应简洁，给图标/数值留空间。 |
| `frame_wave_enemy_row_base` | 今晚敌情行 | 中段多个固定卡扣 | 320x32 细行，边中连续。 |
| `frame_wave_route_toggle_base` | 路线开关底 | 画死分隔柱 | 不画固定多段结构。 |
| `frame_action_panel_base` | ActionPanel 底 | 固定装饰重，中心纹理抢内容 | 白天操作面板外框安静，按钮由节点生成。 |

## 暂不优先重生成

以下素材目前没有作为首批问题项处理。后续如果实际 UI 预览中发现九宫格变形、层级重复或视觉冲突，再单独加入上表：

- `frame_build_icon_backplate`
- `frame_build_icon_frame`
- `frame_cost_badge_base`
- `frame_undo_button_base`
- `frame_operator_cost_badge`
- `frame_unit_portrait_backplate`
- `frame_unit_portrait_frame`
- `frame_skill_icon_backplate`
- `frame_skill_icon_frame`
- `frame_relic_icon_backplate`
- `frame_relic_icon_frame`
- `frame_relic_entry_button_base`
- `frame_resource_delta_badge`
- `frame_dialog_box_base`
- `frame_action_button_base`
- `frame_wave_warning_row_base`
- `frame_top_status_chip_base`
- `frame_settings_button_base`
- `frame_scroll_track`

`frame_build_list_card_selected_overlay` 已作为优先案例单独处理过：源图与派生图 alpha 为 `{0,255}`，无不透明品红残留，并按 `frame_build_list_card_base` 的轮廓/尺寸更新了派生配置。仍需在实际 `BuildListCard` hover/selected 态中做人工视觉验收。

## 验收命令

根据改动范围最少运行：

```powershell
python scripts/dev/crop_ui_assets.py --output-dir tmp/ui_generated_candidate --sheet <source_sheet_name>.png --clean
godot --headless --path . --script scripts/tools/generate_ui_derived_assets.gd
godot --headless --import --path . --quit
git diff --check
```

每个替换批次还必须记录：

- raw sheet 路径；
- 处理的 asset keys；
- 替换的 `assets/ui/source/*.png`；
- alpha 集合是否为 `{0,255}`；
- 不透明品红像素是否为 `0`；
- 哪些 UI 节点/九宫格目标尺寸已经检查；
- 仍需人工视觉验收的点。

## 不在本轮 AI 重生成范围

- `icon_*` texture-only 图标：已接入派生管线，但通常不做 NinePatch 拉伸；除非出现文字、水印、边缘脏像素、语义错误或风格严重不一致，否则不需要本轮重生。
- `assets/ui/generated/` 和 `assets/ui/styles/`：这些是离线脚本输出，不手工替换。
- `assets/ui/templates/`：只维护 margins，不放正式贴图引用。仅当新源图尺寸或不可拉伸保护区变化时，才同步调整对应 template margins。
