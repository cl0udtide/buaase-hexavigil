# UI Asset Generation Prompts

本文档用于网页端 AI 生图工具连续生成 UI 资产源图，是一份完整提示词集，包含生成要求、布局目标、资产命名、裁剪顺序和风格限制。

## 1. 全局提示词

每一轮都先复制本段，再追加对应批次提示词。

```text
我们要为一个 Godot 塔防游戏生成 UI 资产源图。游戏界面是俯视塔防战斗 HUD：地图在中心，UI 贴边显示信息和操作，不遮挡核心战场读图。

界面布局目标：
- 顶部最左侧是小型齿轮设置按钮，点击后打开音量设置面板。
- 顶部横向状态栏显示阶段、时间、核心生命、部署上限、暂停/倍速、资源状态。
- 顶部下方有遗物摘要条，显示遗物入口和少量遗物图标。
- 左侧是建筑/商店竖向栏，包含模式页签、建筑列表、分类页签、刷新或提示信息。
- 底部是待部署干员卡横向列表，卡片由代码动态生成，底部只需要轻量承托背景。
- 右侧是选中单位详情栏，包含单位标题、头像、HP/SP、属性、技能说明、技能按钮和撤退按钮。
- 右下角是战场图例或辅助信息面板。
- 弹窗包括遗物面板、设置面板、祝福选择面板、事件面板、地图交互弹窗、对话框和结算面板。

禁用风格：
- 不要厚重黑金边框、强发光、军事科幻重装甲质感。
- 不要做成家具、卷轴、石碑、盾牌、宝箱、相框、卡通按钮或实体装饰物。

整体风格：
- 轻微奇幻、战术 HUD、清爽、低饱和、暗色但不压抑。
- 主色为低饱和冷灰、深青灰、雾蓝灰，少量柔和浅金、浅琥珀、灰绿作为点缀。
- 资产要像轻薄的游戏 HUD 图层，不像家具、卷轴、石碑、盾牌、宝箱、相框或装饰画。

边缘与体积硬约束：
- 不要明显边框，不要厚边框，不要粗描边，不要双层外框，不要金属大框，不要卷轴边，不要雕花边，不要宝石装饰。
- 面板边界只能用非常轻的材质层次表达：1px 级细线、微弱内阴影、轻微半透明暗面、很浅的边缘高光。
- 外沿视觉重量必须很低，边缘装饰占比低于整体面积的 3%。中心内容区要干净、宽松、可放文字。
- 不做厚重 3D 挤出，不做大倒角，不做强烈外发光，不做浓黑阴影。
- 圆角小，接近 4-8px 的 UI 圆角；不要大圆角胶囊，不要臃肿软垫感。

分层硬约束：
- UI 资产按“底板、内容、覆盖框、状态层”拆分。不要把多个层级合并到一张图。
- 底板资产只画整体材质和极薄外沿，不画头像框、图标槽、进度条、按钮、固定列表项或固定卡槽。
- 头像、建筑图标、技能图标、遗物图标必须夹在 backplate 和 frame 之间。frame 中心保持纯色背景 #79C7B6，方便后续抠成透明孔洞。
- 进度条必须拆成 track 和 fill，不要画固定填充比例。
- 列表容器只画承托背景，不画固定数量的卡槽、格子、候选项或图例行。
- 选中、禁用、冷却、稀有度等状态做 overlay，不要复制一张带内容的大图。
- 图内不要出现任何文字、数字、字母、伪 UI 标签、水印、签名。
- 不要画真实人物、真实头像、角色立绘。头像资产只生成空 backplate/frame。

输出要求：
- 纯色背景，背景色固定为 #79C7B6，方便后续抠图；不要透明棋盘格，不要渐变背景，不要场景背景。
- 每张图中的资产按指定顺序排列，留足纯色背景间距，资产之间不要接触，不要互相投影。
- 资产是给游戏引擎裁剪和九宫格拉伸用的源图，不是完整 UI 截图，不要画鼠标、手指、地图、战斗单位或完整游戏画面。
- 输出清晰，边缘干净，适合裁剪成透明 PNG 后在 1080p UI 中使用。

如果模型倾向画得太亮，请改为：暗色低饱和 UI 材质，base color around #18242A / #223238，accent around #6AAFB4 / #C9A85C but only subtle accents。
如果模型倾向画厚边，请改为：borderless thin HUD panels, almost no outline, subtle material separation only, ultra-thin hairline edge。
```

## 2. 保存与裁剪约定

- 每轮生成一张源图，先保存为 `source_sheet_序号_主题.png`。
- 每张图内的资产按“从左到右、从上到下”的顺序裁剪。
- 裁剪后的文件名必须使用批次里给出的资产 key，例如 `frame_operator_card_base.png`。
- 大面板资产一张图最多 1-2 个；小组件一张图最多 8 个；图标一张图最多 8-10 个。
- 如果某一轮出现明显厚边框、臃肿、过亮、家具风、动态结构被画死，直接废弃该轮，使用第 29 节纠偏提示重新生成。

## 3. 第 1 轮：通用控件基础件

保存源图为：`source_sheet_01_common_controls.png`

裁剪顺序：

1. `frame_button_base`
2. `frame_button_primary_overlay`
3. `frame_button_danger_overlay`
4. `frame_button_disabled_overlay`
5. `frame_icon_backplate`
6. `frame_icon_frame`
7. `frame_tooltip_base`
8. `frame_scroll_track`
9. `frame_scroll_thumb`

```text
请生成一张 UI 资产源图，纯色背景 #79C7B6，包含 9 个独立资产，按从左到右、从上到下排列，不要文字、数字、图标。

1. frame_button_base：通用按钮底，约 320x52。轻薄暗色按钮底，中心干净，不写文字。
2. frame_button_primary_overlay：主按钮高亮叠层，约 320x52。只做微弱青蓝状态光，不改变按钮结构。
3. frame_button_danger_overlay：危险按钮叠层，约 320x52。低饱和红灰状态，不要鲜红。
4. frame_button_disabled_overlay：禁用遮罩，约 320x52。半透明灰暗状态。
5. frame_icon_backplate：通用图标暗底，约 96x96。图标下方底板，不画图标。
6. frame_icon_frame：通用图标覆盖框，约 96x96。中心保持 #79C7B6，后续抠透明。极薄边，不要厚框。
7. frame_tooltip_base：tooltip 底板，约 360x160。暗色半透明小浮层，不画方向尖角，不写文字。
8. frame_scroll_track：滚动条轨道，约 16x200。细窄暗色轨道。
9. frame_scroll_thumb：滚动条拖块，约 16x60。轻薄小拖块。
```

## 4. 第 2 轮：进度条与滑条

保存源图为：`source_sheet_02_bars_sliders.png`

裁剪顺序：

1. `bar_progress_track`
2. `bar_progress_fill_hp`
3. `bar_progress_fill_sp`
4. `bar_progress_fill_core`
5. `frame_slider_track`
6. `frame_slider_fill`
7. `frame_slider_handle`

```text
请生成一张 UI 资产源图，纯色背景 #79C7B6，包含 7 个独立资产，按顺序排列，不要文字、数字。

1. bar_progress_track：HP/SP/核心进度条底轨，约 320x24。只画空轨道，不画填充。
2. bar_progress_fill_hp：HP 填充条，约 320x24。柔和低饱和红色，不能有固定百分比端点文字。
3. bar_progress_fill_sp：SP 填充条，约 320x24。柔和低饱和青蓝。
4. bar_progress_fill_core：核心生命填充条，约 320x24。柔和琥珀。
5. frame_slider_track：音量滑条底轨，约 280x24。只画轨道。
6. frame_slider_fill：音量滑条填充，约 280x24。柔和青蓝或浅绿，不画固定百分比。
7. frame_slider_handle：滑条拖柄，约 40x40。小圆或小菱形，轻薄，不像宝石。
```

## 5. 第 3 轮：顶部 HUD 与遗物摘要

保存源图为：`source_sheet_03_top_hud.png`

裁剪顺序：

1. `frame_top_status_bar_base`
2. `frame_top_status_chip_base`
3. `frame_top_status_chip_active_overlay`
4. `frame_speed_toggle_base`
5. `frame_speed_toggle_active_overlay`
6. `frame_settings_button_base`
7. `frame_relic_strip_base`
8. `frame_relic_entry_button_base`

```text
请生成一张 UI 资产源图，纯色背景 #79C7B6，包含 8 个独立资产。不要文字、数字、图标。

1. frame_top_status_bar_base：顶部状态栏底板，约 1200x72。只做承托背景，不画状态卡、资源槽、按钮或图标。
2. frame_top_status_chip_base：单个状态信息块底板，约 240x64。用于阶段、时间、核心、资源等，内容由代码叠放。
3. frame_top_status_chip_active_overlay：状态信息块高亮叠层，约 240x64。只做极轻状态光。
4. frame_speed_toggle_base：暂停/倍速容器底，约 220x56。不写 1X/2X，不画数字。
5. frame_speed_toggle_active_overlay：当前倍速选中叠层，约 110x52。可放在 1x 或 2x 区域下。
6. frame_settings_button_base：顶部最左侧设置按钮底，约 64x64。只画按钮底，不画齿轮。
7. frame_relic_strip_base：顶部下方遗物摘要条底，约 720x48。不画固定图标槽。
8. frame_relic_entry_button_base：遗物入口按钮底，约 128x44。不写“遗物”或数字。
```

## 6. 第 4 轮：左侧建筑/商店栏

保存源图为：`source_sheet_04_build_panel.png`

裁剪顺序：

1. `frame_left_sidebar_base`
2. `frame_sidebar_tab_base`
3. `frame_sidebar_tab_selected_overlay`
4. `frame_build_list_card_base`
5. `frame_build_icon_backplate`
6. `frame_build_icon_frame`
7. `frame_cost_badge_base`
8. `frame_undo_button_base`

```text
请生成一张 UI 资产源图，纯色背景 #79C7B6，包含 8 个独立资产，不要文字、数字、建筑图标。

1. frame_left_sidebar_base：左侧栏底板，约 320x760。只画侧栏承托背景，不画页签、列表项、撤销按钮或固定行。
2. frame_sidebar_tab_base：页签普通底，约 160x48。不写“建筑/商店”。
3. frame_sidebar_tab_selected_overlay：页签选中叠层，约 160x48。只做细小选中线或微弱亮度。
4. frame_build_list_card_base：建筑/商店列表项底板，约 280x104。不画图标框、价格徽标、文字或数字。
5. frame_build_icon_backplate：建筑图标下方暗底，约 72x72。
6. frame_build_icon_frame：建筑图标覆盖框，约 72x72。中心保持 #79C7B6，后续抠透明。
7. frame_cost_badge_base：成本徽标底，约 56x32。不写数字，不画资源图标。
8. frame_undo_button_base：撤销按钮底，约 160x44。不写文字，不画撤销图标。
```

## 7. 第 5 轮：底部部署区与干员卡

保存源图为：`source_sheet_05_operator_card.png`

裁剪顺序：

1. `frame_bottom_deploy_rail_base`
2. `frame_operator_card_base`
3. `frame_operator_card_selected_overlay`
4. `frame_operator_card_deployed_overlay`
5. `frame_operator_card_cooldown_overlay`
6. `frame_operator_card_cooldown_selected_overlay`
7. `frame_operator_title_strip`
8. `frame_operator_portrait_backplate`
9. `frame_operator_portrait_frame`
10. `frame_operator_cost_badge`
11. `frame_operator_stat_row`

```text
请生成一张 UI 资产源图，纯色背景 #79C7B6，包含 11 个独立资产，不要文字、数字、人物、头像、职业图标。

1. frame_bottom_deploy_rail_base：底部待部署区承托背景，约 980x176。不要画固定卡槽、分隔槽、卡牌轮廓或干员数量。
2. frame_operator_card_base：单张干员卡底板，约 164x148。只画卡片整体轻薄底，不画头像框、状态行、费用徽标或标题条。
3. frame_operator_card_selected_overlay：干员卡选中/拖拽叠层，约 164x148。轻微青色状态，不厚边。
4. frame_operator_card_deployed_overlay：干员卡已部署叠层，约 164x148。低饱和琥珀或灰绿状态。
5. frame_operator_card_cooldown_overlay：干员卡未选中冷却遮罩，约 164x148。暗红灰半透明感，不写冷却数字，不带选中高亮。
6. frame_operator_card_cooldown_selected_overlay：干员卡选中冷却遮罩，约 164x148。暗红灰半透明感，并带非常轻的青色选中提示；不写冷却数字，不要厚边框。
7. frame_operator_title_strip：干员卡顶部标题条底，约 140x28。不写名字。
8. frame_operator_portrait_backplate：干员头像下方暗底，约 128x72。不画剪影。
9. frame_operator_portrait_frame：干员头像覆盖框，约 128x72。中心保持 #79C7B6，后续抠透明。
10. frame_operator_cost_badge：费用徽标底，约 48x36。不写数字。
11. frame_operator_stat_row：HP/SP/CD 单行底纹，约 140x20。不写 HP/SP/CD，不写数值。
```

## 8. 第 6 轮：右侧单位详情栏

保存源图为：`source_sheet_06_unit_detail.png`

裁剪顺序：

1. `frame_right_detail_sidebar_base`
2. `frame_unit_header_strip`
3. `frame_unit_portrait_backplate`
4. `frame_unit_portrait_frame`
5. `frame_detail_section_base`
6. `frame_unit_stat_row`
7. `frame_skill_icon_backplate`
8. `frame_skill_icon_frame`
9. `frame_skill_desc_box`

```text
请生成一张 UI 资产源图，纯色背景 #79C7B6，包含 9 个独立资产，不要文字、数字、头像、图标。

这些资产用于 Godot 分层叠放。推荐层级是：详情栏底板、头像底板、角色头像、头像覆盖框、进度条、属性行、技能图标底板、技能图标、技能覆盖框、技能描述底、按钮。

1. frame_right_detail_sidebar_base：右侧详情栏最底层背景，约 380x760。只画整体暗色底，不画头像框、血条、属性行、技能槽或按钮。
2. frame_unit_header_strip：顶部单位信息条底，约 340x56。不写单位名、编号、伤害类型或朝向。
3. frame_unit_portrait_backplate：单位头像下方暗底，约 128x128。不画人物或剪影。
4. frame_unit_portrait_frame：单位头像覆盖框，约 128x128。中心保持 #79C7B6，后续抠透明，边框极薄。
5. frame_detail_section_base：通用分组底板，约 340x120。不绑定具体内容。
6. frame_unit_stat_row：属性行底，约 320x28。不写属性名、数值或图标。
7. frame_skill_icon_backplate：技能图标下方暗底，约 72x72。
8. frame_skill_icon_frame：技能图标覆盖框，约 72x72。中心保持 #79C7B6，后续抠透明。
9. frame_skill_desc_box：技能描述滚动区域底板，约 320x150。不写文字，不画滚动条。
```

## 9. 第 7 轮：遗物 UI

保存源图为：`source_sheet_07_relic_ui.png`

裁剪顺序：

1. `frame_relic_panel_base`
2. `frame_relic_filter_tab_base`
3. `frame_relic_filter_selected_overlay`
4. `frame_relic_card_base`
5. `frame_relic_card_hover_overlay`
6. `frame_relic_icon_backplate`
7. `frame_relic_icon_frame`
8. `frame_relic_rarity_common_overlay`
9. `frame_relic_rarity_uncommon_overlay`
10. `frame_relic_rarity_rare_overlay`

```text
请生成一张 UI 资产源图，纯色背景 #79C7B6，包含 10 个独立资产，不要文字、数字、遗物图标。

1. frame_relic_panel_base：完整遗物面板底板，约 900x640。不要画固定网格、固定遗物槽、固定卡片或详情文字。
2. frame_relic_filter_tab_base：遗物筛选页签底，约 120x40。不写筛选文字。
3. frame_relic_filter_selected_overlay：筛选选中叠层，约 120x40。
4. frame_relic_card_base：遗物卡底板，约 360x112。不画图标槽、稀有度边、文字或标签。
5. frame_relic_card_hover_overlay：遗物卡 hover/选中叠层，约 360x112。
6. frame_relic_icon_backplate：遗物图标下方暗底，约 80x80。
7. frame_relic_icon_frame：遗物图标覆盖框，约 80x80。中心保持 #79C7B6，后续抠透明。
8. frame_relic_rarity_common_overlay：常见稀有度轻叠层，灰绿低饱和，不厚边。
9. frame_relic_rarity_uncommon_overlay：精良稀有度轻叠层，蓝青低饱和，不厚边。
10. frame_relic_rarity_rare_overlay：稀有稀有度轻叠层，柔和浅金，不要黄金大框。
```

## 10. 第 8 轮：设置面板

保存源图为：`source_sheet_08_settings_panel.png`

裁剪顺序：

1. `frame_settings_panel_base`
2. `frame_settings_row_base`

```text
请生成一张 UI 资产源图，纯色背景 #79C7B6，包含 2 个独立资产，不要文字、数字、图标、滑条。

1. frame_settings_panel_base：设置弹窗底板，约 420x300。只画标题区域和内容承托底，不画死三条滑条，不写“设置”。
2. frame_settings_row_base：单条设置项行底，约 360x48。用于主音量、音乐、音效等行，不写文字，不画滑条。
```

## 11. 第 9 轮：祝福、事件、地图弹窗

保存源图为：`source_sheet_09_modal_panels_a.png`

裁剪顺序：

1. `frame_blessing_panel_base`
2. `frame_blessing_choice_card_base`
3. `frame_event_panel_base`
4. `frame_event_choice_button_base`
5. `frame_map_popup_base`

```text
请生成一张 UI 资产源图，纯色背景 #79C7B6，包含 5 个独立资产，不要文字、数字、图标。

1. frame_blessing_panel_base：祝福/遗物选择面板底板，约 640x440。不要画死三张候选卡槽。
2. frame_blessing_choice_card_base：祝福候选卡底板，约 560x112。不画遗物图标、稀有度边或文字。
3. frame_event_panel_base：事件面板底板，约 640x420。不要画固定选项按钮。
4. frame_event_choice_button_base：事件选项按钮底，约 560x64。不写文字。
5. frame_map_popup_base：地图对象交互弹窗底板，约 360x260。不画固定按钮或图标。
```

## 12. 第 10 轮：对话、结算、图例、波次

保存源图为：`source_sheet_10_modal_panels_b.png`

裁剪顺序：

1. `frame_dialog_box_base`
2. `frame_dialog_speaker_plate_base`
3. `frame_result_panel_base`
4. `frame_result_stat_row_base`
5. `frame_wave_preview_base`
6. `frame_legend_panel_base`
7. `frame_legend_row_base`

```text
请生成一张 UI 资产源图，纯色背景 #79C7B6，包含 7 个独立资产，不要文字、数字、头像、图标。

1. frame_dialog_box_base：对话文本框底板，约 1100x220。只画文本区底，不画头像、名字或按钮。
2. frame_dialog_speaker_plate_base：说话人名牌底，约 240x56。不写名字。
3. frame_result_panel_base：结算面板底板，约 720x520。不画固定统计项或奖章。
4. frame_result_stat_row_base：结算统计行底，约 600x44。不写文字数字。
5. frame_wave_preview_base：波次/路径预览窗底板，约 360x220。不画敌人条目。
6. frame_legend_panel_base：右下战场图例面板底板，约 260x220。不画固定图例行。
7. frame_legend_row_base：单条图例行底，约 220x28。不画图标或文字。
```

## 13. 第 11 轮：通用功能图标

保存源图为：`source_sheet_11_common_icons.png`

裁剪顺序：

1. `icon_phase_day`
2. `icon_phase_night`
3. `icon_phase_blessing`
4. `icon_settings_gear`
5. `icon_core_hp`
6. `icon_deploy_limit`
7. `icon_enemy_queue`
8. `icon_timer`

```text
请生成一张 UI 图标资产源图，纯色背景 #79C7B6，包含 8 个图标，按 4x2 网格排列。不要文字、数字、外框或底板。

图标统一风格：轻微奇幻、低饱和、清晰剪影、少量柔和高光，64x64 缩小时仍可辨认。不要厚描边，不要强外发光。

1. icon_phase_day：白天阶段，简洁太阳符号。
2. icon_phase_night：夜晚阶段，简洁月亮符号。
3. icon_phase_blessing：祝福/遗物选择阶段，简洁星芒或小符文。
4. icon_settings_gear：设置入口，简洁小齿轮。
5. icon_core_hp：核心生命，简洁核心晶体或心形核心。
6. icon_deploy_limit：部署上限，简洁小旗或单位队列符号。
7. icon_enemy_queue：待刷怪/敌人队列，简洁队列箭头或小敌影符号，不画真实怪物。
8. icon_timer：作战计时，简洁小钟。
```

## 14. 第 12 轮：音量、资源、操作图标

保存源图为：`source_sheet_12_audio_resource_icons.png`

裁剪顺序：

1. `icon_volume_master`
2. `icon_volume_music`
3. `icon_volume_sfx`
4. `icon_volume_mute`
5. `icon_pause`
6. `icon_play`
7. `icon_action_points`
8. `icon_prestige`
9. `icon_wood`
10. `icon_stone`
11. `icon_mana`
12. `icon_refresh`

```text
请生成一张 UI 图标资产源图，纯色背景 #79C7B6，包含 12 个图标，按 4x3 网格排列。不要文字、数字、外框或底板。

统一低饱和暗色 HUD 奇幻风，线条清晰，避免厚描边和强发光。

1. icon_volume_master：主音量，简洁扬声器与声波。
2. icon_volume_music：音乐音量，简洁音符。
3. icon_volume_sfx：音效音量，简洁声效波形。
4. icon_volume_mute：静音，简洁静音扬声器。
5. icon_pause：暂停，两条竖线符号。
6. icon_play：继续，三角播放符号。
7. icon_action_points：行动力，简洁能量火花或行动徽记。
8. icon_prestige：声望，简洁徽章或旗帜。
9. icon_wood：木材，简洁木料。
10. icon_stone：石材，简洁石块。
11. icon_mana：魔力，简洁水晶或魔力滴。
12. icon_refresh：刷新，简洁循环箭头。
```

## 15. 第 13 轮：遗物筛选与面板操作图标

保存源图为：`source_sheet_13_relic_command_icons.png`

裁剪顺序：

1. `icon_relic_bag`
2. `icon_filter_all`
3. `icon_filter_unit`
4. `icon_filter_building`
5. `icon_filter_economy`
6. `icon_filter_core`
7. `icon_filter_risk`
8. `icon_close`
9. `icon_confirm`
10. `icon_cancel`

```text
请生成一张 UI 图标资产源图，纯色背景 #79C7B6，包含 10 个图标，按 5x2 网格排列。不要文字、数字、外框或底板。

1. icon_relic_bag：遗物总入口，简洁小包或符文匣。
2. icon_filter_all：全部筛选，简洁四点/网格。
3. icon_filter_unit：单位类遗物筛选，简洁头盔或单位剪影。
4. icon_filter_building：建筑类遗物筛选，简洁小塔。
5. icon_filter_economy：经济类遗物筛选，简洁钱币或账本。
6. icon_filter_core：核心防线类遗物筛选，简洁核心晶体。
7. icon_filter_risk：风险收益类遗物筛选，简洁警示符号。
8. icon_close：关闭，简洁 X。
9. icon_confirm：确认，简洁勾。
10. icon_cancel：取消/撤销，简洁回退箭头。
```

## 16. 第 14 轮：职业、属性、伤害图标

保存源图为：`source_sheet_14_stat_combat_icons.png`

裁剪顺序：

1. `icon_class_guard`
2. `icon_class_sniper`
3. `icon_class_caster`
4. `icon_class_defender`
5. `icon_stat_hp`
6. `icon_stat_atk`
7. `icon_stat_def`
8. `icon_stat_res`
9. `icon_stat_block`
10. `icon_stat_attack_speed`
11. `icon_stat_sp`
12. `icon_retreat`

```text
请生成一张 UI 图标资产源图，纯色背景 #79C7B6，包含 12 个图标，按 4x3 网格排列。不要文字、数字、外框或底板。

统一风格：轻薄、低饱和、简洁战术奇幻图标，适合放在干员卡和右侧详情内。

1. icon_class_guard：近卫，简洁短剑。
2. icon_class_sniper：狙击，简洁瞄准镜或弩箭。
3. icon_class_caster：术士，简洁法术焦点。
4. icon_class_defender：重装，简洁盾牌。
5. icon_stat_hp：生命，简洁生命心或生命叶。
6. icon_stat_atk：攻击，简洁剑刃。
7. icon_stat_def：防御，简洁盾。
8. icon_stat_res：法抗，简洁符文护盾。
9. icon_stat_block：阻挡，简洁路障或拦截符号。
10. icon_stat_attack_speed：攻速，简洁速度刃。
11. icon_stat_sp：SP，简洁能量珠。
12. icon_retreat：撤退，简洁后撤箭头。
```

## 17. 第 15 轮：伤害、技能状态、朝向图标

保存源图为：`source_sheet_15_damage_direction_icons.png`

裁剪顺序：

1. `icon_damage_physical`
2. `icon_damage_arts`
3. `icon_damage_true`
4. `icon_skill_ready`
5. `icon_skill_locked`
6. `icon_cooldown`
7. `icon_direction_up`
8. `icon_direction_down`
9. `icon_direction_left`
10. `icon_direction_right`

```text
请生成一张 UI 图标资产源图，纯色背景 #79C7B6，包含 10 个图标，按 5x2 网格排列。不要文字、数字、外框或底板。

1. icon_damage_physical：物理伤害，简洁刀痕。
2. icon_damage_arts：法术伤害，简洁法术符文。
3. icon_damage_true：真实伤害，简洁穿透核心。
4. icon_skill_ready：技能可用，简洁点亮符号。
5. icon_skill_locked：技能不可用，简洁锁。
6. icon_cooldown：冷却，简洁沙漏或循环计时符号。
7. icon_direction_up：朝上箭头。
8. icon_direction_down：朝下箭头。
9. icon_direction_left：朝左箭头。
10. icon_direction_right：朝右箭头。
```

## 18. 第 16 轮：地图与图例图标

保存源图为：`source_sheet_16_map_legend_icons.png`

裁剪顺序：

1. `icon_legend_enemy_path`
2. `icon_legend_deploy_tile`
3. `icon_legend_friendly_building`
4. `icon_legend_blocker_tile`
5. `icon_legend_core_area`
6. `icon_map_marker`
7. `icon_map_warning`
8. `icon_map_range`

```text
请生成一张 UI 图标资产源图，纯色背景 #79C7B6，包含 8 个图标，按 4x2 网格排列。不要文字、数字、外框或底板。

1. icon_legend_enemy_path：敌人路径，简洁红灰虚线箭头。
2. icon_legend_deploy_tile：可部署地块，简洁蓝青方格。
3. icon_legend_friendly_building：我方建筑，简洁小塔。
4. icon_legend_blocker_tile：阻挡单元，简洁斜线格。
5. icon_legend_core_area：核心区域，简洁核心六边形。
6. icon_map_marker：玩家标记，简洁地图针。
7. icon_map_warning：非法部署/危险提示，简洁警告三角。
8. icon_map_range：攻击范围，简洁范围圆弧。
```

## 19. 第 17 轮：建筑图标

保存源图为：`source_sheet_17_building_icons.png`

裁剪顺序：

1. `icon_building_lumber_station`
2. `icon_building_stone_quarry`
3. `icon_building_mana_extractor`
4. `icon_building_medical_station`
5. `icon_building_gravity_tower`
6. `icon_building_inspiring_monolith`
7. `icon_building_war_shrine`
8. `icon_building_wood_wall`

```text
请生成一张建筑图标资产源图，纯色背景 #79C7B6，包含 8 个图标，按 4x2 网格排列。不要文字、数字、外框或底板。

建筑图标统一为轻微奇幻塔防风，低饱和，轮廓清楚，适合放在左侧建筑列表。不要画成复杂 3D 建筑模型，不要厚金属底座。

1. icon_building_lumber_station：伐木站，小木料和简洁棚架。
2. icon_building_stone_quarry：石矿场，小石块和采石标记。
3. icon_building_mana_extractor：魔力矿场，小水晶抽取器。
4. icon_building_medical_station：医疗站，简洁治疗十字和小站台。
5. icon_building_gravity_tower：重力塔，简洁塔芯和向下力场。
6. icon_building_inspiring_monolith：鼓舞石碑，简洁石碑和柔和符文。
7. icon_building_war_shrine：战火圣坛，简洁小祭坛和低饱和火焰。
8. icon_building_wood_wall：木墙，简洁木栅。
```

## 20. 第 18 轮：技能图标第一批

保存源图为：`source_sheet_18_skill_icons_a.png`

裁剪顺序：

1. `icon_skill_common_atk_up`
2. `icon_skill_guard_hold_line`
3. `icon_skill_guard_decisive_swing`
4. `icon_skill_sniper_quintuple_shot`
5. `icon_skill_sniper_burst_dawn`
6. `icon_skill_caster_overload_permanent`
7. `icon_skill_caster_chain_push`
8. `icon_skill_defender_fortify`

```text
请生成一张技能图标资产源图，纯色背景 #79C7B6，包含 8 个图标，按 4x2 网格排列。不要文字、数字、外框或底板。

技能图标统一为低饱和轻微奇幻战术风，读图清楚，避免复杂插画和厚描边。

1. icon_skill_common_atk_up：通用攻击强化，剑刃和上升符号。
2. icon_skill_guard_hold_line：近卫阵线压制，短剑与横向阵线。
3. icon_skill_guard_decisive_swing：近卫决胜斩击，单道斩击弧。
4. icon_skill_sniper_quintuple_shot：狙击连射，多枚细箭或弹道。
5. icon_skill_sniper_burst_dawn：狙击爆发射击，瞄准点和柔和光束。
6. icon_skill_caster_overload_permanent：术士常驻过载，法芯和稳定环。
7. icon_skill_caster_chain_push：术士连锁推击，链状法术和推力箭。
8. icon_skill_defender_fortify：重装固守，盾和加固符号。
```

## 21. 第 19 轮：技能图标第二批

保存源图为：`source_sheet_19_skill_icons_b.png`

裁剪顺序：

1. `icon_skill_defender_counter_stance`
2. `icon_skill_mountain_sweeping_stance`
3. `icon_skill_zuo_le_risky_venture`
4. `icon_skill_degenbrecher_silence`
5. `icon_skill_surtr_twilight`
6. `icon_skill_narantuya_solar_swallow`
7. `icon_skill_ray_light`
8. `icon_skill_typhon_eternal_hunt`

```text
请生成一张技能图标资产源图，纯色背景 #79C7B6，包含 8 个图标，按 4x2 网格排列。不要文字、数字、外框或底板。

这些是角色技能的抽象图标，不要画角色本人或版权角色特征，只画技能概念符号。统一低饱和轻奇幻风。

1. icon_skill_defender_counter_stance：重装反击姿态，盾与反击箭。
2. icon_skill_mountain_sweeping_stance：扫堂/架势，拳风或横扫弧。
3. icon_skill_zuo_le_risky_venture：风险突进，短刃和危险标记。
4. icon_skill_degenbrecher_silence：沉默斩击，断裂音波和剑痕。
5. icon_skill_surtr_twilight：黄昏火刃，低饱和火焰剑。
6. icon_skill_narantuya_solar_swallow：太阳燕，太阳弧和飞鸟抽象剪影。
7. icon_skill_ray_light：光束，聚焦光线。
8. icon_skill_typhon_eternal_hunt：永恒狩猎，瞄准环和长箭。
```

## 22. 第 20 轮：技能图标第三批

保存源图为：`source_sheet_20_skill_icons_c.png`

裁剪顺序：

1. `icon_skill_wisadel_saturated_revenge`
2. `icon_skill_ifrit_scorched_earth`
3. `icon_skill_nymph_psychic_collapse`
4. `icon_skill_goldenglow_clear_shine`
5. `icon_skill_logos_oblivion`
6. `icon_skill_saria_calcification`
7. `icon_skill_penance_thorny_body`
8. `icon_skill_jessica_saturation_burst`
9. `icon_skill_shu_cycle_of_growth`

```text
请生成一张技能图标资产源图，纯色背景 #79C7B6，包含 9 个图标，按 3x3 网格排列。不要文字、数字、外框或底板。

这些是角色技能的抽象图标，不要画角色本人或版权角色特征，只画技能概念符号。统一低饱和轻奇幻风，边缘清楚但不厚。

1. icon_skill_wisadel_saturated_revenge：饱和复仇，密集弹幕和复仇符号。
2. icon_skill_ifrit_scorched_earth：灼地，低饱和火焰地裂。
3. icon_skill_nymph_psychic_collapse：精神崩解，破碎心灵符文。
4. icon_skill_goldenglow_clear_shine：澄净闪光，柔和电光星芒。
5. icon_skill_logos_oblivion：湮灭，黑蓝低饱和空洞符号。
6. icon_skill_saria_calcification：钙化，结晶护盾。
7. icon_skill_penance_thorny_body：荆棘身躯，盾和荆棘。
8. icon_skill_jessica_saturation_burst：饱和爆发，弹片和冲击波。
9. icon_skill_shu_cycle_of_growth：生长循环，嫩芽和循环环。
```

## 23. 第 21 轮：遗物图标第一批

保存源图为：`source_sheet_21_relic_icons_a.png`

裁剪顺序：

1. `icon_relic_battle_standard`
2. `icon_relic_sharpened_orders`
3. `icon_relic_vanguard_frame`
4. `icon_relic_mobile_command`
5. `icon_relic_core_patch`
6. `icon_relic_core_capacitor`
7. `icon_relic_guard_manual`
8. `icon_relic_bayonet_drill`

```text
请生成一张遗物图标资产源图，纯色背景 #79C7B6，包含 8 个图标，按 4x2 网格排列。不要文字、数字、外框或底板。

遗物图标风格：轻微奇幻、小物件、低饱和、清晰轮廓，像游戏道具图标但不要厚重收藏品框，不要强金光。

1. icon_relic_battle_standard：边境战旗，小旗帜、旧布、浅青纹。
2. icon_relic_sharpened_orders：磨损军令，卷起军令、细裂纹。
3. icon_relic_vanguard_frame：预备队框架，轻型部署框架。
4. icon_relic_mobile_command：机动指挥台，小型指挥台。
5. icon_relic_core_patch：核心补丁包，修补包、浅色核心纹。
6. icon_relic_core_capacitor：备用核心电容，小电容、柔光。
7. icon_relic_guard_manual：近卫手册，剑形书签与手册。
8. icon_relic_bayonet_drill：刺刀操典，训练册与短刃。
```

## 24. 第 22 轮：遗物图标第二批

保存源图为：`source_sheet_22_relic_icons_b.png`

裁剪顺序：

1. `icon_relic_duelist_contract`
2. `icon_relic_sniper_scope`
3. `icon_relic_recurve_string`
4. `icon_relic_glass_barrel`
5. `icon_relic_caster_focus`
6. `icon_relic_mana_resonator`
7. `icon_relic_overclocked_core`
8. `icon_relic_defender_plate`

```text
请生成一张遗物图标资产源图，纯色背景 #79C7B6，包含 8 个图标，按 4x2 网格排列。不要文字、数字、外框或底板。

统一轻微奇幻小物件风，低饱和，图标清楚，避免厚描边和强发光。

1. icon_relic_duelist_contract：决斗者契约，契约纸与单剑。
2. icon_relic_sniper_scope：校准瞄具，瞄具镜片。
3. icon_relic_recurve_string：复合弓弦，弓弦线圈。
4. icon_relic_glass_barrel：玻璃枪管，透明枪管零件。
5. icon_relic_caster_focus：术式焦镜，镜片与小法阵。
6. icon_relic_mana_resonator：魔力谐振器，小谐振器。
7. icon_relic_overclocked_core：过载法芯，过载核心，克制微光。
8. icon_relic_defender_plate：加厚盾板，盾板。
```

## 25. 第 23 轮：遗物图标第三批

保存源图为：`source_sheet_23_relic_icons_c.png`

裁剪顺序：

1. `icon_relic_bastion_anchor`
2. `icon_relic_compressed_bulwark`
3. `icon_relic_travel_pack`
4. `icon_relic_black_market_token`
5. `icon_relic_bounty_ledger`
6. `icon_relic_greedy_seal`
7. `icon_relic_lumber_contract`
8. `icon_relic_quarry_glyph`

```text
请生成一张遗物图标资产源图，纯色背景 #79C7B6，包含 8 个图标，按 4x2 网格排列。不要文字、数字、外框或底板。

统一轻微奇幻小物件风，低饱和，避免厚重金属和浓黑阴影。

1. icon_relic_bastion_anchor：堡垒锚钉，锚钉与盾形底。
2. icon_relic_compressed_bulwark：压缩壁垒装具，折叠护盾装置。
3. icon_relic_travel_pack：远征背包，小背包。
4. icon_relic_black_market_token：黑市代币，暗色代币，不要过黑。
5. icon_relic_bounty_ledger：赏金账本，账本和小印章。
6. icon_relic_greedy_seal：贪婪印章，印章与硬币。
7. icon_relic_lumber_contract：木材契约，木纹契约牌。
8. icon_relic_quarry_glyph：采石符文，石片符文。
```

## 26. 第 24 轮：遗物图标第四批

保存源图为：`source_sheet_24_relic_icons_d.png`

裁剪顺序：

1. `icon_relic_mana_siphon`
2. `icon_relic_industrial_blueprint`
3. `icon_relic_aura_lens`
4. `icon_relic_range_pylon`
5. `icon_relic_wallwright_kit`
6. `icon_relic_iron_patience`
7. `icon_relic_rapid_recall`

```text
请生成一张遗物图标资产源图，纯色背景 #79C7B6，包含 7 个图标，按 4+3 的网格排列。不要文字、数字、外框或底板。

统一轻微奇幻小物件风，低饱和，清晰轮廓，避免厚边框和强发光。

1. icon_relic_mana_siphon：魔力虹吸管，小玻璃虹吸管。
2. icon_relic_industrial_blueprint：工业蓝图，蓝图纸和铅笔。
3. icon_relic_aura_lens：光环透镜，淡色透镜。
4. icon_relic_range_pylon：扩散塔芯，小塔芯。
5. icon_relic_wallwright_kit：筑墙匠工具包，工具包与木钉。
6. icon_relic_iron_patience：铁质耐心，铁片护符。
7. icon_relic_rapid_recall：快速召回绳，收束绳结。
```

## 27. 角色头像类资产生成原则

如果后续需要生成角色头像或半身像，单独开新对话生成，不要混在 UI 框架资产里。

```text
请只生成角色头像源图，纯色背景 #79C7B6。不要 UI 边框，不要卡牌，不要文字数字。头像构图要能放入 128x128 或 128x72 的头像窗口，人物边缘干净，光照柔和，低饱和轻微奇幻风。导出后头像位于 backplate 与 frame 之间。
```

## 28. 裁剪后入库检查

- `*_base` 只能作为底板，不应含有可变内容。
- `*_backplate` 在内容图下方。
- `*_frame` 在内容图上方，中心必须透明。
- `*_overlay` 在最上方，用于状态，不承载文字或数字。
- `bar_*_track` 和 `bar_*_fill` 分开使用，fill 用 Godot 裁剪或缩放控制长度。
- 如果裁剪后发现某资产内置了固定数量、固定文字、固定头像框或固定填充比例，废弃重生成。

## 29. 纠偏提示词

如果生成结果仍然有明显边框或太臃肿，使用下面提示词重新生成同一批：

```text
上一版边框太明显、太厚、太臃肿。请重新生成同一批资产：
- 去掉可见粗外框，禁止厚描边、金属大边、双层框、装饰角、卷轴边、宝石边。
- 边界只允许 1px 级细线、极轻内阴影、微弱材质差；整体看起来接近 borderless HUD panel。
- 资产要更薄、更平、更轻，内容区更大，装饰更少。
- 色调降低亮度与饱和度，避免小清新家具风；使用暗色低饱和冷灰、深青灰。
- 保持纯色背景 #79C7B6 和原来的裁剪顺序。
```

如果生成结果过亮、像家具或卡通按钮，使用下面提示词：

```text
上一版太亮、太像家具或卡通按钮。请重新生成同一批资产：
- 改为暗色低饱和战术 HUD 材质，base color around #18242A / #223238。
- 只保留轻微奇幻纹理，不要木质家具感、皮革软垫感、糖果色、厚圆角。
- 按钮和面板要像游戏 HUD 的轻薄图层，不像实体家具部件。
- 纯色背景 #79C7B6，保持原来的裁剪顺序。
```

如果生成结果把动态结构画死，使用下面提示词：

```text
上一版把动态 UI 结构画死了。请重新生成同一批资产：
- 大面板底板不要内置头像框、图标槽、血条、属性行、技能槽、按钮、固定列表项或固定网格。
- 底部部署区不要固定卡槽，只有轻量承托背景。
- 右侧角色详情栏底板不要内置任何子控件，这些必须单独分层生成。
- 遗物面板不要固定网格数量，祝福面板不要画死三张候选卡。
- 设置面板不要画死三条滑条，滑条由单独资产生成。
- 所有文字、数字、图标内容由代码添加，资产只提供无文字背景和结构。
```

## 30. 增量补充批次：资源项、今晚敌情、ActionPanel

此批次用于补齐已经生成过的资产中可能缺少的当前游戏 UI 元素。它是追加批次，不需要重做前面已有资产。

保存源图为：`source_sheet_25_incremental_hud_elements.png`

裁剪顺序：

1. `frame_resource_item_base`
2. `frame_resource_delta_badge`
3. `frame_wave_enemy_row_base`
4. `frame_wave_route_toggle_base`
5. `frame_wave_warning_row_base`
6. `frame_action_panel_base`
7. `frame_action_button_base`

```text
请生成一张 UI 资产源图，纯色背景 #79C7B6，包含 7 个独立资产，按从左到右、从上到下排列，不要文字、数字、图标。

这些是追加资产，用于塔防 HUD 中还缺少的资源项、今晚敌情模块和白天操作面板。保持轻微奇幻、低饱和、暗色、轻薄 HUD 风格。不要厚边框，不要家具风，不要强发光。

1. frame_resource_item_base：单个资源项底板，约 88x44。用于行动点、木材、石材、魔力、声望等资源。只画小型轻薄底，不写数字，不画资源图标。
2. frame_resource_delta_badge：资源增长/消耗速率徽标底，约 76x24。用于每分钟产出或消耗提示，不写数字。
3. frame_wave_enemy_row_base：今晚敌情单条敌人/波次条目底，约 320x32。不写敌人名、数量或路线。
4. frame_wave_route_toggle_base：路线预览开关底，约 120x32。用于放在今晚敌情标题行内部，不写“路线”或开关文字。
5. frame_wave_warning_row_base：路线异常/堵路警告行底，约 320x32。低饱和琥珀或红灰状态，不能鲜艳。
6. frame_action_panel_base：白天上下文操作面板底板，约 520x150。用于探索、入夜、建筑维修/拆除/启停等操作，不画固定按钮。
7. frame_action_button_base：ActionPanel 按钮底，约 150x44。不写文字，不画图标。
```

## 31. 页面叙事背景：开始与结算

这些图不是可九宫格裁切的 UI 框架件，而是 `MainMenu` 与 `Result` 页面使用的全屏叙事背景。运行时图保存到 `assets/story/backgrounds/`，原始生成图保存到 `assets/story/backgrounds/raw/`。

通用约束：

- 输出为 16:9 横版背景，运行时导出为 1920x1080。
- 画面右侧 40% 是 UI 安全区，只保留低细节天空、雾、地面或色块过渡；不放角色、建筑、强光焦点、高对比边缘、文字或假 UI。
- 画面左侧 60% 承载叙事主体。不要在图里画按钮、菜单、标题、Logo、水印、签名、字母或数字。
- 不参考或使用 `assets/story/portraits/` 下的对话立绘。开始和胜利页不画具体角色 likeness，只用核心、防线、地形、旗帜、光线和环境叙事。
- 风格保持轻微奇幻、清新低饱和、战术塔防感；避免厚重黑金、霓虹科幻、过度写实和人像立绘感。

保存文件：

1. `page_start_defense.png`
2. `page_result_victory.png`
3. `page_result_defeat_milk_dragon.png`

```text
Global prompt:
stylized painterly fantasy tower-defense key art, fresh low-saturation palette, clear narrative, no text, no UI, no logo, no watermark, no fake buttons, rightmost 40% quiet atmospheric negative space for UI.

Start page:
Create a narrative key art background for the start page. The scene is a watch line just before nightfall: a glowing hexagonal core and low defensive barricades in the left/middle distance, distant enemy silhouettes gathering near the horizon, banners and lanterns catching wind, and a sense that the night defense is about to begin. Keep all major storytelling in the left 60%; make the right 40% quiet low-detail dusk sky/fog/terrain for UI.

Victory page:
Create a narrative key art background for the victory page. The same watch line after surviving the night: dawn light breaks through mist, the hexagonal core remains intact and glowing gently, battered barricades stand around it, broken enemy weapons and harmless debris lie outside the defense, and the mood is earned relief and quiet triumph. Keep all major storytelling in the left 60%; make the right 40% quiet low-detail morning mist/sky/terrain for UI.

Defeat page:
Use only the milk dragon chief reference at assets/sprites/enemies/raw/milk_dragon_chief_redraw_source.png. Preserve the round yellow body, cream belly, laughing open mouth, tiny fangs, leafy tribal cloak/collar, skull and feather head ornament, rope/bone accessories, wooden staff with red spiral mark, and playful but threatening boss energy. Create a dynamic defeat illustration where the chief leads small follower creatures in a triumphant charge across a broken night defense line, with dust, splinters, torn banners, cracked barricades, and scattered stones. Keep the chief and followers in the left 60%; make the right 40% quiet smoky dark teal fog/ground for UI.
```
