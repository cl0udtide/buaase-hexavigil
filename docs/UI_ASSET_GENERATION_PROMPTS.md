# UI Asset Generation Prompts

本文档用于网页端 AI 生图工具连续生成 UI 资产源图。它更像一份创意 brief，而不是逐像素规格说明：保留用途、分层、裁剪顺序和必要工程底线，把造型、比例、装饰节奏交给生图模型发挥。

## 1. 全局提示词

每一轮先复制本段，再追加对应批次提示词。

```text
我们要为一个 Godot 塔防游戏生成 UI 资产源图。游戏是俯视塔防战场：地图在中心，UI 贴边显示阶段、资源、建筑、干员卡、单位详情、遗物、弹窗和战场辅助信息。

整体风格：
清新战术奇幻 UI，低饱和、暗色、轻盈、实用，但要有游戏界面的设计感。它应该像现代奇幻策略游戏的界面资产：清爽、帅气、略带奇幻工艺感。

创作原则：
- 请根据每个资产的用途自由设计轮廓、比例、材质和细节。
- 同一张源图内保持同一视觉家族，同时让不同用途的资产自然区分。
- 可以有多样形状：小圆角、轻微切角、柔和折线、流畅边线、简洁几何轮廓都可以。
- 内容区域要干净，方便游戏运行时放文字、数字、图标、头像或列表内容。
- 装饰服务于 UI 气质和可读性。

必要工程要求：
- 背景必须是完全纯净的 #FF00FF 实色，方便后续抠图。
- 不要生成半透明像素或半透明视觉效果；资产像素要么是不透明主体，要么是可抠掉的 #FF00FF 背景/孔洞，透明度和淡化效果由游戏引擎运行时调节。
- 图内不要出现文字、数字、字母、水印、签名或伪 UI 标签。
- 每个资产独立摆放，留足 #FF00FF 间距，不互相接触，不画完整游戏截图。
- `*_base` 是承托底板，不要内置运行时会变化的文字、图标、头像、列表项、按钮组或固定数量格子。
- `*_overlay` 是状态叠层，不要复制完整底板，也不要承载文字。
- `*_backplate` 放在内容图下方，`*_frame` 放在内容图上方；需要透明孔洞的 frame 中心保持 #FF00FF。
- `bar_*_track` 和 `bar_*_fill` 分开生成，不要画固定百分比。
- 面板、卡片、按钮、弹窗、tooltip、侧栏等 `frame_*_base` 尽量适合 Godot `StyleBoxTexture` 九宫格：角和边框可保护，中心可拉伸或平铺。
- 资产边缘要干净，不要把 #FF00FF 背景色混进主体边缘。
```

## 2. 保存与裁剪约定

- 每轮生成一张源图，先保存为 `source_sheet_序号_主题.png`。
- 每张图内资产按“从左到右、从上到下”的顺序裁剪。
- 裁剪后的文件名必须使用批次里给出的 asset key，例如 `frame_operator_card_base.png`。
- 大面板资产一张图最多 1-2 个；小组件一张图最多 8 个；图标一张图最多 8-12 个。
- 如果生成结果背景不纯、资产粘连、出现文字、把动态结构画死，直接废弃该轮重生成。

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
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 9 个独立资产，按裁剪顺序排列。不要文字、数字、图标。

这批是游戏最基础的通用控件，用于按钮、图标承托、tooltip 和滚动条。整体保持清新战术奇幻 UI 气质，让每个资产根据用途自然变化。

1. frame_button_base：通用按钮底板，用于放置运行时按钮文字。
2. frame_button_primary_overlay：主按钮状态叠层，用于表现可点击或强调状态。
3. frame_button_danger_overlay：危险按钮状态叠层，用于撤退、取消、危险操作。
4. frame_button_disabled_overlay：禁用按钮遮罩，用于不可点击状态。
5. frame_icon_backplate：通用图标背板，放在图标下方。
6. frame_icon_frame：通用图标覆盖框，放在图标上方，中心保持 #FF00FF。
7. frame_tooltip_base：tooltip 背景，用于说明文字承托。
8. frame_scroll_track：滚动条轨道。
9. frame_scroll_thumb：滚动条拖块。
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
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 7 个独立资产，按裁剪顺序排列。不要文字、数字。

这批用于生命、技能、核心生命和音量设置。track 与 fill 要能在 Godot 中由代码控制长度，不要画固定百分比。

1. bar_progress_track：HP/SP/核心生命通用底轨。
2. bar_progress_fill_hp：HP 填充条。
3. bar_progress_fill_sp：SP 填充条。
4. bar_progress_fill_core：核心生命填充条。
5. frame_slider_track：音量滑条轨道。
6. frame_slider_fill：音量滑条填充。
7. frame_slider_handle：音量滑条拖柄。
```

## 5. 第 3 轮：顶部状态栏与遗物摘要

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
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 8 个独立资产，按裁剪顺序排列。不要文字、数字、图标。

这批用于游戏顶部信息区：阶段、时间、核心生命、部署上限、暂停/倍速、资源和遗物摘要。请把它设计成清爽的战场信息 UI，而不是完整的顶部截图。

1. frame_top_status_bar_base：顶部状态栏整体承托背景。
2. frame_top_status_chip_base：单个状态信息块底板。
3. frame_top_status_chip_active_overlay：状态信息块高亮叠层。
4. frame_speed_toggle_base：暂停/倍速容器底板。
5. frame_speed_toggle_active_overlay：当前倍速选中叠层。
6. frame_settings_button_base：设置按钮底板，不画齿轮。
7. frame_relic_strip_base：遗物摘要条背景。
8. frame_relic_entry_button_base：遗物入口按钮底板。
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
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 8 个独立资产，按裁剪顺序排列。不要文字、数字、建筑图标。

这批用于左侧建筑/商店栏。左侧栏由代码动态放入页签、建筑列表、价格和撤销按钮，所以底板不要画死列表内容。

1. frame_left_sidebar_base：左侧栏整体背景。
2. frame_sidebar_tab_base：页签普通底板。
3. frame_sidebar_tab_selected_overlay：页签选中叠层。
4. frame_build_list_card_base：建筑/商店列表项底板。
5. frame_build_icon_backplate：建筑图标背板。
6. frame_build_icon_frame：建筑图标覆盖框，中心保持 #FF00FF。
7. frame_cost_badge_base：成本徽标底板。
8. frame_undo_button_base：撤销按钮底板，不画撤销图标。
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
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 11 个独立资产，按裁剪顺序排列。不要文字、数字、人物、头像、职业图标。

这批用于底部待部署干员区。干员卡由代码动态组合头像、名字、费用、状态和属性，所以每个素材只提供对应层级。

1. frame_bottom_deploy_rail_base：底部待部署区承托背景。
2. frame_operator_card_base：干员卡底板。
3. frame_operator_card_selected_overlay：干员卡选中/拖拽叠层。
4. frame_operator_card_deployed_overlay：干员卡已部署叠层。
5. frame_operator_card_cooldown_overlay：干员卡冷却遮罩。
6. frame_operator_card_cooldown_selected_overlay：选中且冷却的遮罩。
7. frame_operator_title_strip：干员卡标题条底板。
8. frame_operator_portrait_backplate：干员头像背板。
9. frame_operator_portrait_frame：干员头像覆盖框，中心保持 #FF00FF。
10. frame_operator_cost_badge：费用徽标底板。
11. frame_operator_stat_row：HP/SP/CD 等单行信息底纹。
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
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 9 个独立资产，按裁剪顺序排列。不要文字、数字、头像、图标。

这批用于右侧选中单位详情栏。详情栏由代码动态放入头像、血条、属性、技能图标、技能说明和按钮。

1. frame_right_detail_sidebar_base：右侧详情栏整体背景。
2. frame_unit_header_strip：单位标题区域底板。
3. frame_unit_portrait_backplate：单位头像背板。
4. frame_unit_portrait_frame：单位头像覆盖框，中心保持 #FF00FF。
5. frame_detail_section_base：详情分组底板。
6. frame_unit_stat_row：属性行底板。
7. frame_skill_icon_backplate：技能图标背板。
8. frame_skill_icon_frame：技能图标覆盖框，中心保持 #FF00FF。
9. frame_skill_desc_box：技能描述区域底板。
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
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 10 个独立资产，按裁剪顺序排列。不要文字、数字、遗物图标。

这批用于遗物面板、筛选页签、遗物卡、遗物图标承托和稀有度状态。遗物内容由代码动态填入。

1. frame_relic_panel_base：完整遗物面板底板。
2. frame_relic_filter_tab_base：遗物筛选页签底板。
3. frame_relic_filter_selected_overlay：筛选选中叠层。
4. frame_relic_card_base：遗物卡底板。
5. frame_relic_card_hover_overlay：遗物卡 hover/选中叠层。
6. frame_relic_icon_backplate：遗物图标背板。
7. frame_relic_icon_frame：遗物图标覆盖框，中心保持 #FF00FF。
8. frame_relic_rarity_common_overlay：常见稀有度轻叠层。
9. frame_relic_rarity_uncommon_overlay：精良稀有度轻叠层。
10. frame_relic_rarity_rare_overlay：稀有稀有度轻叠层。
```

## 10. 第 8 轮：设置面板

保存源图为：`source_sheet_08_settings_panel.png`

裁剪顺序：

1. `frame_settings_panel_base`
2. `frame_settings_row_base`

```text
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 2 个独立资产，按裁剪顺序排列。不要文字、数字、图标、滑条。

这批用于设置弹窗。滑条和按钮由其他资产或代码组合，不要在面板里画死设置项。

1. frame_settings_panel_base：设置弹窗底板。
2. frame_settings_row_base：单条设置项行底板。
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
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 5 个独立资产，按裁剪顺序排列。不要文字、数字、图标。

这批用于祝福选择、事件选择和地图对象交互弹窗。候选卡、选项按钮和弹窗内容由代码动态组合。

1. frame_blessing_panel_base：祝福/遗物选择面板底板。
2. frame_blessing_choice_card_base：祝福候选卡底板。
3. frame_event_panel_base：事件面板底板。
4. frame_event_choice_button_base：事件选项按钮底板。
5. frame_map_popup_base：地图对象交互弹窗底板。
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
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 7 个独立资产，按裁剪顺序排列。不要文字、数字、头像、图标。

这批用于对话框、结算面板、波次预览和战场图例。所有文字、头像、统计项和图例图标由代码添加。

1. frame_dialog_box_base：对话文本框底板。
2. frame_dialog_speaker_plate_base：说话人名牌底板。
3. frame_result_panel_base：结算面板底板。
4. frame_result_stat_row_base：结算统计行底板。
5. frame_wave_preview_base：波次/路径预览窗口底板。
6. frame_legend_panel_base：右下战场图例面板底板。
7. frame_legend_row_base：单条图例行底板。
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
请生成一张 UI 图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是顶部状态栏和通用操作中使用的小图标。风格与 UI 框架一致：清晰、低饱和、轻微奇幻、适合小尺寸阅读。

1. icon_phase_day：白天阶段。
2. icon_phase_night：夜晚阶段。
3. icon_phase_blessing：祝福/遗物选择阶段。
4. icon_settings_gear：设置入口。
5. icon_core_hp：核心生命。
6. icon_deploy_limit：部署上限。
7. icon_enemy_queue：待刷怪/敌人队列。
8. icon_timer：作战计时。
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
请生成一张 UI 图标资产源图，纯色背景 #FF00FF，包含 12 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些图标用于音量设置、暂停/继续、资源显示和刷新操作。图标需要小尺寸清晰，风格与 UI 框架一致。

1. icon_volume_master：主音量。
2. icon_volume_music：音乐音量。
3. icon_volume_sfx：音效音量。
4. icon_volume_mute：静音。
5. icon_pause：暂停。
6. icon_play：继续。
7. icon_action_points：行动力。
8. icon_prestige：声望。
9. icon_wood：木材。
10. icon_stone：石材。
11. icon_mana：魔力。
12. icon_refresh：刷新。
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
请生成一张 UI 图标资产源图，纯色背景 #FF00FF，包含 10 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些图标用于遗物入口、遗物筛选和弹窗操作。它们应该是简洁、抽象、可读的小型功能图标。

1. icon_relic_bag：遗物总入口。
2. icon_filter_all：全部筛选。
3. icon_filter_unit：单位类遗物筛选。
4. icon_filter_building：建筑类遗物筛选。
5. icon_filter_economy：经济类遗物筛选。
6. icon_filter_core：核心防线类遗物筛选。
7. icon_filter_risk：风险收益类遗物筛选。
8. icon_close：关闭。
9. icon_confirm：确认。
10. icon_cancel：取消/撤销。
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
请生成一张 UI 图标资产源图，纯色背景 #FF00FF，包含 12 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些图标用于干员卡和右侧单位详情，表示职业、属性和撤退操作。请优先保证语义清晰和小尺寸可读。

1. icon_class_guard：近卫。
2. icon_class_sniper：狙击。
3. icon_class_caster：术士。
4. icon_class_defender：重装。
5. icon_stat_hp：生命。
6. icon_stat_atk：攻击。
7. icon_stat_def：防御。
8. icon_stat_res：法抗。
9. icon_stat_block：阻挡。
10. icon_stat_attack_speed：攻速。
11. icon_stat_sp：SP。
12. icon_retreat：撤退。
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
请生成一张 UI 图标资产源图，纯色背景 #FF00FF，包含 10 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些图标用于伤害类型、技能状态、冷却和朝向显示。它们是功能符号，不是插画。

1. icon_damage_physical：物理伤害。
2. icon_damage_arts：法术伤害。
3. icon_damage_true：真实伤害。
4. icon_skill_ready：技能可用。
5. icon_skill_locked：技能不可用。
6. icon_cooldown：冷却。
7. icon_direction_up：朝上。
8. icon_direction_down：朝下。
9. icon_direction_left：朝左。
10. icon_direction_right：朝右。
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
请生成一张 UI 图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些图标用于战场图例和地图辅助信息。请让它们清晰、符号化、适合放在小型图例行里。

1. icon_legend_enemy_path：敌人路径。
2. icon_legend_deploy_tile：可部署地块。
3. icon_legend_friendly_building：我方建筑。
4. icon_legend_blocker_tile：阻挡单元。
5. icon_legend_core_area：核心区域。
6. icon_map_marker：玩家标记。
7. icon_map_warning：非法部署/危险提示。
8. icon_map_range：攻击范围。
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
请生成一张建筑图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是左侧建筑列表中的建筑图标，不是完整建筑插画。请保持简洁、低饱和、清晰可读。

1. icon_building_lumber_station：伐木站。
2. icon_building_stone_quarry：石矿场。
3. icon_building_mana_extractor：魔力矿场。
4. icon_building_medical_station：医疗站。
5. icon_building_gravity_tower：重力塔。
6. icon_building_inspiring_monolith：鼓舞石碑。
7. icon_building_war_shrine：战火圣坛。
8. icon_building_wood_wall：木墙。
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
请生成一张技能图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是角色技能的抽象图标。不要画角色本人，只表达技能概念；小尺寸要能读懂。

1. icon_skill_common_atk_up：通用攻击强化。
2. icon_skill_guard_hold_line：近卫阵线压制。
3. icon_skill_guard_decisive_swing：近卫决胜斩击。
4. icon_skill_sniper_quintuple_shot：狙击连射。
5. icon_skill_sniper_burst_dawn：狙击爆发射击。
6. icon_skill_caster_overload_permanent：术士常驻过载。
7. icon_skill_caster_chain_push：术士连锁推击。
8. icon_skill_defender_fortify：重装固守。
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
请生成一张技能图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是角色技能的抽象图标。不要画角色本人，只表达技能概念；小尺寸要能读懂。

1. icon_skill_defender_counter_stance：重装反击姿态。
2. icon_skill_mountain_sweeping_stance：扫堂/架势。
3. icon_skill_zuo_le_risky_venture：风险突进。
4. icon_skill_degenbrecher_silence：沉默斩击。
5. icon_skill_surtr_twilight：黄昏火刃。
6. icon_skill_narantuya_solar_swallow：太阳燕。
7. icon_skill_ray_light：光束。
8. icon_skill_typhon_eternal_hunt：永恒狩猎。
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
请生成一张技能图标资产源图，纯色背景 #FF00FF，包含 9 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是角色技能的抽象图标。不要画角色本人，只表达技能概念；小尺寸要能读懂。

1. icon_skill_wisadel_saturated_revenge：饱和复仇。
2. icon_skill_ifrit_scorched_earth：灼地。
3. icon_skill_nymph_psychic_collapse：精神崩解。
4. icon_skill_goldenglow_clear_shine：澄净闪光。
5. icon_skill_logos_oblivion：湮灭。
6. icon_skill_saria_calcification：钙化。
7. icon_skill_penance_thorny_body：荆棘身躯。
8. icon_skill_jessica_saturation_burst：饱和爆发。
9. icon_skill_shu_cycle_of_growth：生长循环。
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
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是放进遗物卡中的小物件图标。请保持低饱和、轻奇幻、清晰可读。

1. icon_relic_battle_standard：边境战旗。
2. icon_relic_sharpened_orders：磨损军令。
3. icon_relic_vanguard_frame：预备队框架。
4. icon_relic_mobile_command：机动指挥台。
5. icon_relic_core_patch：核心补丁包。
6. icon_relic_core_capacitor：备用核心电容。
7. icon_relic_guard_manual：近卫手册。
8. icon_relic_bayonet_drill：刺刀操典。
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
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是放进遗物卡中的小物件图标。请保持低饱和、轻奇幻、清晰可读。

1. icon_relic_duelist_contract：决斗者契约。
2. icon_relic_sniper_scope：校准瞄具。
3. icon_relic_recurve_string：复合弓弦。
4. icon_relic_glass_barrel：玻璃枪管。
5. icon_relic_caster_focus：术式焦镜。
6. icon_relic_mana_resonator：魔力谐振器。
7. icon_relic_overclocked_core：过载法芯。
8. icon_relic_defender_plate：加厚盾板。
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
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是放进遗物卡中的小物件图标。请保持低饱和、轻奇幻、清晰可读。

1. icon_relic_bastion_anchor：堡垒锚钉。
2. icon_relic_compressed_bulwark：压缩壁垒装具。
3. icon_relic_travel_pack：远征背包。
4. icon_relic_black_market_token：黑市代币。
5. icon_relic_bounty_ledger：赏金账本。
6. icon_relic_greedy_seal：贪婪印章。
7. icon_relic_lumber_contract：木材契约。
8. icon_relic_quarry_glyph：采石符文。
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
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 7 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是放进遗物卡中的小物件图标。请保持低饱和、轻奇幻、清晰可读。

1. icon_relic_mana_siphon：魔力虹吸管。
2. icon_relic_industrial_blueprint：工业蓝图。
3. icon_relic_aura_lens：光环透镜。
4. icon_relic_range_pylon：扩散塔芯。
5. icon_relic_wallwright_kit：筑墙匠工具包。
6. icon_relic_iron_patience：铁质耐心。
7. icon_relic_rapid_recall：快速召回绳。
```

## 27. 角色头像类资产生成原则

如果后续需要生成角色头像或半身像，单独开新对话生成，不要混在 UI 框架资产里。

干员 UI 胸像批次（`portrait_unit_<unit_id>`，28 张）已按本原则正式立项，资产清单、提示词与接线说明见 `docs/CHARACTER_ASSET_GENERATION_PROMPTS.md` 第 7 节。

```text
请只生成角色头像源图，纯色背景 #FF00FF。不要 UI 边框，不要卡牌，不要文字数字。头像构图要能放入头像窗口，人物边缘干净，光照柔和，低饱和轻微奇幻风。
```

## 28. 裁剪后入库检查

- `*_base` 只能作为底板，不应含有运行时可变内容。
- `*_backplate` 在内容图下方。
- `*_frame` 在内容图上方，中心必须透明。
- `*_overlay` 在最上方，用于状态。
- `bar_*_track` 和 `bar_*_fill` 分开使用。
- 如果裁剪后发现某资产内置固定文字、固定头像框、固定格子数量或固定填充比例，废弃重生成。

## 29. 简短纠偏提示词

如果生成结果把动态结构画死，使用：

```text
上一版把动态 UI 结构画死了。请重新生成同一批资产：只生成分层素材，不要内置文字、数字、头像、图标、固定列表项、固定网格、固定按钮组或固定填充比例。背景仍为纯 #FF00FF，保持原裁剪顺序。
```

如果生成结果背景或边缘不干净，使用：

```text
上一版不适合抠图。请重新生成同一批资产：背景必须是完全纯色 #FF00FF，资产之间留足间距，边缘干净，不要文字数字。保持原裁剪顺序。
```

## 30. 增量补充批次：资源项、今晚敌情、ActionPanel

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
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 7 个独立资产，按裁剪顺序排列。不要文字、数字、图标。

这些是补充资产，用于资源项、今晚敌情模块和白天上下文操作面板。它们需要和前面 UI 框架保持同一清新战术奇幻风格。

1. frame_resource_item_base：单个资源项底板。
2. frame_resource_delta_badge：资源增长/消耗速率徽标底板。
3. frame_wave_enemy_row_base：今晚敌情单条敌人/波次条目底板。
4. frame_wave_route_toggle_base：路线预览开关底板。
5. frame_wave_warning_row_base：路线异常/堵路警告行底板。
6. frame_action_panel_base：白天上下文操作面板底板。
7. frame_action_button_base：ActionPanel 按钮底板。
```

## 31. 页面叙事背景：开始与结算

这些图不是可九宫格裁切的 UI 框架件，而是 `MainMenu` 与 `Result` 页面使用的全屏叙事背景。运行时图保存到 `assets/story/backgrounds/`，原始生成图保存到 `assets/story/backgrounds/raw/`。

通用约束：

- 输出为 16:9 横版背景，运行时导出为 1920x1080。
- 画面右侧 40% 是 UI 安全区，只保留低细节天空、雾、地面或色块过渡；不放角色、建筑、强光焦点、高对比边缘、文字或假 UI。
- 画面左侧 60% 承载叙事主体。不要在图里画按钮、菜单、标题、Logo、水印、签名、字母或数字。
- 不参考或使用 `assets/story/portraits/` 下的对话立绘。开始和胜利页不画具体角色 likeness，只用核心、防线、地形、旗帜、光线和环境叙事。
- 风格保持轻微奇幻、清新低饱和、塔防战场感。

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

## 32. 第 26 轮：功能图标提亮重制批（R3 评审批次 ①）

> 轮次编号说明：第 30 节「增量补充批次」使用 `source_sheet_25`，计为第 25 轮；本节起编号顺延为第 26 轮。
> 本节起的批次来自 UI 三轮评审（`tmp/ui_round3_findings.json` 与 `tmp/ui_round3_central_spec.md`）中 verdict 为 `art-todo` 或 `mixed`（detail 含美术 TODO）的条目，每轮标注来源条目 id，接线说明中「」内为 triage 原话。

来源条目：`dark-icons-on-dark-plates`、`topbar-icon-silhouettes-illegible`、`pause-icon-near-invisible`、`demolish-icon-emoji-mismatch`、`stat-icons-indistinct`、`building-icons-muddy-at-tile-size`、`build-thumb-muddy-dark`。

共 33 枚内容图标，分 4 张源图。除 `icon_demolish` 为新增 key，其余全部沿用原 asset key 同名覆盖 `assets/ui/generated/`，零代码生效。

### 26-A 顶栏功能图标（8 枚）

保存源图为：`source_sheet_26a_topbar_icons.png`

| 裁剪序 | asset key | 目标尺寸（源图） | 分层类型 | 显示位 |
|---|---|---|---|---|
| 1 | `icon_settings_gear` | 256x256（显示 18-28px） | 独立 icon | 顶栏设置按钮 |
| 2 | `icon_prestige` | 256x256（显示 18-28px） | 独立 icon | 顶栏资源区声望项 |
| 3 | `icon_deploy_limit` | 256x256（显示 18-28px） | 独立 icon | 顶栏部署上限 chip |
| 4 | `icon_phase_day` | 256x256（显示 18-28px） | 独立 icon | 顶栏阶段 chip |
| 5 | `icon_phase_night` | 256x256（显示 18-28px） | 独立 icon | 顶栏阶段 chip / ActionPanel 夜晚图标 |
| 6 | `icon_phase_blessing` | 256x256（显示 18-28px） | 独立 icon | 顶栏阶段 chip |
| 7 | `icon_core_hp` | 256x256（显示 18-28px） | 独立 icon | 顶栏核心生命 chip |
| 8 | `icon_enemy_queue` | 256x256（显示 18-28px） | 独立 icon | 顶栏待刷怪 chip |

先复制第 1 节全局提示词，再追加以下本批提示词：

```text
请生成一张 UI 图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这批是顶部状态栏功能图标的「深底亮色版」重制：现版本体深灰（不透明区平均亮度仅 56-73/255），压在暗色底板上不可读。重制要求：亮银/浅钢色（约 #B8C4CC）主体 + teal 细缘光，粗线条扁平剪影、轮廓粗壮低细节，不透明区平均亮度 ≥140，18-28px 显示下一眼可读。

1. icon_settings_gear：设置入口，粗轮廓齿轮。
2. icon_prestige：声望，徽记/桂冠。
3. icon_deploy_limit：部署上限，三叉部署标。
4. icon_phase_day：白天阶段，太阳。
5. icon_phase_night：夜晚阶段，弯月与星。
6. icon_phase_blessing：祝福阶段，光辉饰记。
7. icon_core_hp：核心生命，核心纹章。
8. icon_enemy_queue：待刷怪/敌人队列，队列双箭头。
```

### 26-B 图例与音量图标（9 枚）

保存源图为：`source_sheet_26b_legend_volume_icons.png`

| 裁剪序 | asset key | 目标尺寸（源图） | 分层类型 | 显示位 |
|---|---|---|---|---|
| 1 | `icon_legend_enemy_path` | 256x256（显示 18-28px） | 独立 icon | 右下战场图例行 |
| 2 | `icon_legend_deploy_tile` | 256x256（显示 18-28px） | 独立 icon | 右下战场图例行 |
| 3 | `icon_legend_friendly_building` | 256x256（显示 18-28px） | 独立 icon | 右下战场图例行 |
| 4 | `icon_legend_blocker_tile` | 256x256（显示 18-28px） | 独立 icon | 右下战场图例行 |
| 5 | `icon_legend_core_area` | 256x256（显示 18-28px） | 独立 icon | 右下战场图例行 |
| 6 | `icon_volume_master` | 256x256（显示 18-28px） | 独立 icon | 设置面板音量行 |
| 7 | `icon_volume_music` | 256x256（显示 18-28px） | 独立 icon | 设置面板音量行 |
| 8 | `icon_volume_sfx` | 256x256（显示 18-28px） | 独立 icon | 设置面板音量行 |
| 9 | `icon_volume_mute` | 256x256（显示 18-28px） | 独立 icon | 设置面板静音项 |

先复制第 1 节全局提示词，再追加以下本批提示词：

```text
请生成一张 UI 图标资产源图，纯色背景 #FF00FF，包含 9 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这批是战场图例与音量图标的「深底亮色版」重制，要求与上一张相同：亮银/浅钢色主体 + teal 细缘光，粗线条扁平剪影、低细节，不透明区平均亮度 ≥140，小尺寸图例行内可读。

1. icon_legend_enemy_path：敌人路径。
2. icon_legend_deploy_tile：可部署地块。
3. icon_legend_friendly_building：我方建筑。
4. icon_legend_blocker_tile：阻挡单元。
5. icon_legend_core_area：核心区域。
6. icon_volume_master：主音量。
7. icon_volume_music：音乐音量。
8. icon_volume_sfx：音效音量。
9. icon_volume_mute：静音。
```

### 26-C 属性、播放控制与拆除图标（8 枚）

保存源图为：`source_sheet_26c_stat_control_icons.png`

| 裁剪序 | asset key | 目标尺寸（源图） | 分层类型 | 显示位 |
|---|---|---|---|---|
| 1 | `icon_stat_atk` | 48x48（按 18px 可辨设计） | 独立 icon | 右侧详情属性行 / 部署卡 / tooltip |
| 2 | `icon_stat_def` | 48x48（按 18px 可辨设计） | 独立 icon | 同上 |
| 3 | `icon_stat_res` | 48x48（按 18px 可辨设计） | 独立 icon | 同上 |
| 4 | `icon_stat_block` | 48x48（按 18px 可辨设计） | 独立 icon | 同上 |
| 5 | `icon_stat_attack_speed` | 48x48（按 18px 可辨设计） | 独立 icon | 同上 |
| 6 | `icon_pause` | 96x96（显示 16-24px） | 独立 icon | 顶栏暂停/倍速组 |
| 7 | `icon_play` | 96x96（显示 16-24px） | 独立 icon | 顶栏暂停/倍速组（暂停态换图） |
| 8 | `icon_demolish`（新增 key） | 128x128（显示 16-24px） | 独立 icon | 地图弹窗拆除按钮 |

先复制第 1 节全局提示词，再追加以下本批提示词：

```text
请生成一张 UI 图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

前 5 枚是属性图标重制：剪影优先、每枚独立色相，18px 下五枚互不混淆（现版法抗/攻速同为青色环涡、防御/阻挡同为蓝盾，必须拉开）。后 3 枚是控制类图标：亮色实心主体、1px 深钢描边、微金属高光、无浮雕暗面。

1. icon_stat_atk：攻击，亮红斜剑。
2. icon_stat_def：防御，钢蓝方盾。
3. icon_stat_res：法抗，紫色符文六芒。
4. icon_stat_block：阻挡，金黄拦挡手掌。
5. icon_stat_attack_speed：攻速，青绿沙漏或双箭头。
6. icon_pause：暂停，米白 #E8F0F5 实心双竖条。
7. icon_play：继续，米白 #E8F0F5 实心右向三角。
8. icon_demolish：拆除，单色钢青系锤形或撬棍剪影，与 icon_confirm/icon_close 同族线性工艺感。
```

### 26-D 建筑缩略图（8 枚）

保存源图为：`source_sheet_26d_building_icons.png`

| 裁剪序 | asset key | 目标尺寸（源图） | 分层类型 | 显示位 |
|---|---|---|---|---|
| 1 | `icon_building_lumber_station` | ~300x340（显示 48-64px） | 独立 icon | 左侧建筑列表缩略图 |
| 2 | `icon_building_stone_quarry` | ~300x340（显示 48-64px） | 独立 icon | 左侧建筑列表缩略图 |
| 3 | `icon_building_mana_extractor` | ~300x340（显示 48-64px） | 独立 icon | 左侧建筑列表缩略图 |
| 4 | `icon_building_medical_station` | ~300x340（显示 48-64px） | 独立 icon | 左侧建筑列表缩略图 |
| 5 | `icon_building_gravity_tower` | ~300x340（显示 48-64px） | 独立 icon | 左侧建筑列表缩略图 |
| 6 | `icon_building_inspiring_monolith` | ~300x340（显示 48-64px） | 独立 icon | 左侧建筑列表缩略图 |
| 7 | `icon_building_war_shrine` | ~300x340（显示 48-64px） | 独立 icon | 左侧建筑列表缩略图 |
| 8 | `icon_building_wood_wall` | ~300x340（显示 48-64px） | 独立 icon | 左侧建筑列表缩略图 |

先复制第 1 节全局提示词，再追加以下本批提示词：

```text
请生成一张建筑图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这批是建筑缩略图重制：现版是整幅像素建筑画压暗（不透明区平均亮度 54-65/255），缩到列表尺寸糊成剪影。重制为高对比简化建筑剪影，亮青描边 + 每栋 1-2 个特征元素，主体提亮至不透明区平均亮度 ≥120，加冷色缘光，深蓝底上 48-64px 可辨。三座矿场主色强区分：伐木站木褐、石矿场石灰青、魔力矿场魔力紫 teal。

1. icon_building_lumber_station：伐木站，锯轮特征。
2. icon_building_stone_quarry：石矿场，碎石镐特征。
3. icon_building_mana_extractor：魔力矿场，晶体导管特征。
4. icon_building_medical_station：医疗站。
5. icon_building_gravity_tower：重力塔。
6. icon_building_inspiring_monolith：鼓舞石碑。
7. icon_building_war_shrine：战火圣坛。
8. icon_building_wood_wall：木墙。
```

### 第 26 轮验收要点

- 功能/图例/音量图标：不透明区平均亮度 ≥140（triage 实测现状：icon_settings_gear 59、icon_prestige 68、icon_deploy_limit 56、icon_phase_night 66、icon_legend_friendly_building 67、icon_legend_blocker_tile 61、icon_volume_master/music/sfx 66-73）。
- 建筑缩略图：不透明区平均亮度 ≥120（现状 54/60/65）。
- `icon_pause` 与 `icon_play` 必须同批重出：「set_time_controls 在暂停态会换 top_play 图标，两张都要重出否则状态切换亮度跳变」；目标与顶栏 1X/2X 白字同明度档（现状不透明像素平均亮度 0.212/0.247，按钮 icon 着色是乘法 modulate，「无法把深灰提亮到与 1X/2X 白字同级，参数不可救」）。
- 属性图标在 18px 实尺寸下五枚互不混淆；「每枚独立色相要求与生图模型的成功率有出入，准备废弃重抽」。
- 全部压在 BG_CARD（亮度 ≈20）底板上目检；入库后按显示位实尺寸截图验收。

### 第 26 轮实装接线

- 同名覆盖即生效：「沿用同名 key 覆盖即可自动生效（CombatHud.tscn 直接 ExtResource 引用同路径）；别改文件名，否则 .tscn 的 uid 引用断」（dark-icons-on-dark-plates）；「同名覆盖注意保留 .import」。
- 属性图标：「落图即生效（catalog 路径不变），部署卡与 tooltip 自动复用」（stat-icons-indistinct，`data/ui_icons.json` 已注册这 5 个 key）。
- 暂停/播放：「覆盖 assets/ui/generated/ 同名文件，data/ui_icons.json 的 top_pause/top_play 键无需改」（pause-icon-near-invisible）。
- `icon_demolish`（新增）：在 `data/ui_icons.json` 登记新 key，并把 `scenes/game/Game.tscn` DemolishButton 的 Icon 引用从 icon_cancel.png 换为 icon_demolish.png；「icon_cancel.png 本体不要动——它语义上属『取消/撤销』，其它场景（撤退/取消操作）可能后续引用；只换 Demolish 按钮的引用」（demolish-icon-emoji-mismatch）。
- 建筑缩略图：「同名覆盖即生效，零代码」（building-icons-muddy-at-tile-size，buildings.json 经 icon_path 直引）；「地图上的建筑走 visual_key 另一套贴图，不受影响」。
- 亮色版落地后移除场景侧过渡提亮：「落盘后移除 self_modulate 临时项」（topbar-icon-silhouettes-illegible）；集中层 G34 的 `set_button_texture_icon` tint 参数「美术亮色版图标落地后传 Color.WHITE 即回退」。

## 33. 第 27 轮：遗物类别图标批（R3 ②）

来源条目：`relic-icon-single-pixel-pouch`（同根条目：`relic-icons-all-same-pouch`、`blessing-icons-identical-pouch`、`relic-rail-collides-banner`）。

背景：`data/buffs.json` 37 件遗物均无 icon_key/icon_path 字段，「relic_card.gd:89、relic_icon.gd:53、relic_strip.gd:60 全部回落到 &"relic_bag"」（227x243 像素风钱袋，平均亮度 49/255），列表行、三选一、顶栏遗物链全员同图。本轮先落 6 枚类别图标作为兜底；37 件逐遗物专属图标见第 37 节长尾批次。

保存源图为：`source_sheet_27_relic_category_icons.png`

| 裁剪序 | asset key | 目标尺寸（源图） | 分层类型 | 显示位 |
|---|---|---|---|---|
| 1 | `icon_relic_cat_unit` | ~256x256（显示 24-52px） | 独立 icon | 遗物卡 / 遗物行 / 顶栏遗物链 / 三选一卡 |
| 2 | `icon_relic_cat_building` | ~256x256（显示 24-52px） | 独立 icon | 同上 |
| 3 | `icon_relic_cat_economy` | ~256x256（显示 24-52px） | 独立 icon | 同上 |
| 4 | `icon_relic_cat_core` | ~256x256（显示 24-52px） | 独立 icon | 同上 |
| 5 | `icon_relic_cat_risk` | ~256x256（显示 24-52px） | 独立 icon | 同上 |
| 6 | `icon_relic_cat_generic` | ~256x256（显示 24-52px） | 独立 icon | 同上（无类目兜底） |

先复制第 1 节全局提示词，再追加以下本批提示词：

```text
请生成一张 UI 图标资产源图，纯色背景 #FF00FF，包含 6 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这批是遗物类别图标：painterly 冷钢银主体 + teal 点缀，深底亮缘光剪影；稀有度不画进图（描边由 rarity overlay 负责），24px 显示下六类一眼可分。

1. icon_relic_cat_unit：单位类，盔甲人形。
2. icon_relic_cat_building：建筑类，塔楼。
3. icon_relic_cat_economy：经济类，钱币堆。
4. icon_relic_cat_core：核心防线类，核心晶体。
5. icon_relic_cat_risk：风险收益类，裂纹火焰。
6. icon_relic_cat_generic：通用类，六角徽记。
```

### 第 27 轮验收要点

- 24px 最小显示尺寸（顶栏遗物链）下六类轮廓可区分；明度与第 26 轮亮色图标同档（不透明区平均亮度 ≥140 同标准）。
- 与既有 icon_filter_unit/building/economy/core/risk 语义一一对应，但不是同族复用：filter 系是线性小符号，本批是 painterly 剪影内容图。

### 第 27 轮实装接线

- 「接线零代码：UiArtRegistry.get_icon_texture 已支持 cfg.icon_key→generated/<key>.png，只需在 data/buffs.json 每条加 "icon_key"（或在 relic_card/relic_icon 按 category 映射兜底，约 10 行）」（relic-icon-single-pixel-pouch）。
- 三选一自动生效：「BlessingPanel 走同一 RelicCard.configure→get_icon_texture 链路自动生效」（blessing-icons-identical-pouch）。
- 「不要动 relic_bag 这个兜底键，作为缺图保险留着」；「33 个旧 icon_relic_* 资产先留着（可能被旧档/调试引用），只增不删」。
- 「data/buffs.json 加字段对 buff 逻辑零影响（配置只读）」。

## 34. 第 28 轮：框体与战场控件重制批（R3 ③）

来源条目：`chip-hardware-repetition-brown-clash`、`bottom-frame-hex-pods-oversized`（= 中央规格 F7 挂起项）、`relic-band-crest-flattened-vs-blessing`、`unselected-tab-plaque-disintegrated`、`flat-default-buttons-clash`、`settings-frame-family-three-levels`（= F7 挂起项）、`blessing-card-sepia-clash`、`slider-grabber-crate-overdetail`、`hp-sp-fill-too-dark`、`direction-picker-programmer-art`。

共 15 个资产，分 4 张源图。本轮全部是「九宫格参数救不了」的烤死装饰/竖横比错配/源图过暗问题，等图期间集中层 flat 兜底已就位（G12/G13/G14/G19 等），落图即升级。

### 28-A 大面板（2 个）

保存源图为：`source_sheet_28a_large_panels.png`

| 裁剪序 | asset key | 新增/覆盖 | 目标尺寸（源图） | 分层类型 | 显示位 |
|---|---|---|---|---|---|
| 1 | `frame_left_sidebar_slim_base` | 新增 key | ~300x904（显示 320x826） | `*_base` 九宫格 | 左侧建筑/商店栏整体背景 |
| 2 | `frame_relic_panel_base` | 同名覆盖重绘 | 648x321（同位重绘） | `*_base` 九宫格 | 遗物面板（运行时拉伸至 ~900x640） |

先复制第 1 节全局提示词，再追加以下本批提示词：

```text
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 2 个大面板资产，按裁剪顺序排列。不要文字、数字、图标。

1. frame_left_sidebar_slim_base：窄侧栏整体背景框，四角六角角件收至约 40px，角件内芯冷灰蓝金属（去棕），上下框带变薄，中心大面积干净深蓝，可九宫格拉伸。
2. frame_relic_panel_base：遗物面板底板重绘，延续现款构图与 18px 九宫格边距结构，顶带改为无中央纹章的素管段（可安全横向拉伸），纹章改由独立 overlay 承载（见 28-B 第 8 项）。
```

### 28-B 中小框体（8 个）

保存源图为：`source_sheet_28b_midsize_frames.png`

| 裁剪序 | asset key | 新增/覆盖 | 目标尺寸（源图） | 分层类型 | 显示位 |
|---|---|---|---|---|---|
| 1 | `frame_top_status_chip_base` | 同名覆盖重绘 | 273x154 | `*_base` 九宫格 | 顶栏状态 chip（fit_145x82 系列 4 个 + fit_130x74） |
| 2 | `frame_resource_item_base` | 同名覆盖重绘 | 521x179 | `*_base` 九宫格 | 顶栏资源项 |
| 3 | `frame_sidebar_tab_base` | 同名覆盖（竖版改横版） | ~300x100（显示 150x50） | `*_base` 九宫格 | 左栏页签 |
| 4 | `frame_small_button_base` | 新增 key | ~320x88（派生 fit_160x44 / fit_90x40） | `*_base` 九宫格 | 锁定/刷新/自动技能等小按钮 |
| 5 | `frame_inner_row_base` | 新增 key | ~400x56 | `*_base` 九宫格 | 设置行 / 列表行 / 图标底板共用 |
| 6 | `frame_blessing_choice_card_base` | 同名覆盖（竖版改横版） | ~530x150（显示 ~480x96-140） | `*_base` 九宫格 | 三选一祝福候选卡 |
| 7 | `frame_slider_handle` | 同名覆盖简化 | ~64x96（显示 16x24） | 独立拖柄件 | 设置面板音量滑条拖柄 |
| 8 | `frame_dialog_crest_overlay` | 新增 key | ~256x96 | `*_overlay` 装饰叠层 | 遗物/祝福/事件面板顶带中央纹章 |

先复制第 1 节全局提示词，再追加以下本批提示词：

```text
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 8 个独立资产，按裁剪顺序排列。不要文字、数字、图标。

这批是评审后的框体重制件：整体去暖色、降装饰重量，让位内容。*_base 仍须适合九宫格拉伸；frame_dialog_crest_overlay 是装饰叠层，不复制底板、不承载文字。

1. frame_top_status_chip_base：顶栏状态 chip 底板重绘，左右立柱由饱和棕木改青铜灰、整体去暖色，顶边中央凸饰弱化为低对比小铆点，保持现有轮廓与角板族系。
2. frame_resource_item_base：资源小件底板，同步去暖色、降低五金件对比让位数据。
3. frame_sidebar_tab_base：横版页签铭牌，与选中态同形的低调实心金属铭牌，降亮度去高光、无侧挂饰，冷钢深芯。
4. frame_small_button_base：小按钮底板，薄冷钢斜边 + 深色芯，与 action_button 同族但装饰减半。
5. frame_inner_row_base：轻量行底板，无角撑、1px 暗描边、内凹深芯。
6. frame_blessing_choice_card_base：横版祝福候选卡底板，冷钢深蓝横卡框、四角小护角、内容区干净无做旧噪点，品质描边交给 overlay。
7. frame_slider_handle：滑条拖柄，纯亮银圆角方块 + 单条 teal 竖中线，无铆钉无端盖，强轮廓低细节。
8. frame_dialog_crest_overlay：拱形双翼蓝宝石纹章，与现有对话框顶带纹章同款工艺，独立摆放。
```

### 28-C 条形填充鲜亮版（2 个）

保存源图为：`source_sheet_28c_bar_fills.png`

| 裁剪序 | asset key | 新增/覆盖 | 目标尺寸（源图） | 分层类型 | 显示位 |
|---|---|---|---|---|---|
| 1 | `bar_progress_fill_hp` | 同名覆盖重绘 | ~1370x85 | `bar_*_fill` | 详情页 HP 条填充 |
| 2 | `bar_progress_fill_sp` | 同名覆盖重绘 | ~1379x83 | `bar_*_fill` | 详情页 SP 条填充 |

先复制第 1 节全局提示词，再追加以下本批提示词：

```text
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 2 个条形填充资产，横向长条、上下排列。不要文字、数字，不要画固定百分比，不要画轨道。

1. bar_progress_fill_hp：HP 填充条重制，鲜红→橙红横向均匀色身 + 顶部 1px 高光，中段亮度明显高于暗色轨道内芯（目标 ≥3 倍）。
2. bar_progress_fill_sp：SP 填充条，同工艺亮 teal 青版。
```

### 28-D 部署朝向控件（3 个）

保存源图为：`source_sheet_28d_direction_picker.png`。注意：本组入库目录是 `assets/map/CommandMap/`（内容贴图非九宫格，先例 overlay_deploy_valid.png 256x256），不是 `assets/ui/generated/`。

| 裁剪序 | asset key | 新增/覆盖 | 目标尺寸（源图） | 分层类型 | 显示位 |
|---|---|---|---|---|---|
| 1 | `overlay_direction_ring` | 新增 key | 320x320（中心透明） | 独立内容贴图 | 部署朝向选择环 |
| 2 | `overlay_direction_chevron` | 新增 key | 96x96 | 独立内容贴图 | 朝向楔（未选中，右向基准） |
| 3 | `overlay_direction_chevron_active` | 新增 key | 96x96 | 独立内容贴图 | 朝向楔（选中，实心 + 外发光） |

先复制第 1 节全局提示词，再追加以下本批提示词：

```text
请生成一张战场控件贴图源图，纯色背景 #FF00FF，包含 3 个独立资产，按裁剪顺序排列。不要文字、数字、UI 底板。

这批替换部署朝向选择器的代码矢量绘制（现为 draw_circle/扇形/十字线拼凑的程序员美术）。

1. overlay_direction_ring：单层金属刻度环，内嵌四向凹槽，中心保持 #FF00FF（运行时透明）。
2. overlay_direction_chevron：方向楔 chevron（未选中态），描线款，右向基准，运行时由代码旋转复用。
3. overlay_direction_chevron_active：同造型方向楔（选中态），实心 + 外发光，右向基准。
```

### 第 28 轮验收要点

- 顶栏 chip / 资源件：「落盘后重出 fit 变体（fit_145x82 系列 4 个 + fit_130x74，沿用现 .tres 的 texture_margin）」；「fit 变体重生成时保持 .tres margin 数值不变，否则 content 区漂移」；「替换影响全 HUD 10+ chip，必须全状态截图前后对比」。「『凸饰仅留分组首 chip』需两套贴图变体，本轮放弃」。
- 侧栏 slim 框：四角角件收至 ~40px、中心可拉伸；「换底框后 #tab-row 的 margin_top=48 需按新带厚回调；面板级换皮影响左栏全部截图基线，放最后做」。
- 遗物面板重绘：「重绘需保持 18px 九宫格边距结构」；顶带在 ~1.4x 横向拉伸（648→900 宽）下无可见变形。
- 页签横版：九宫格压进 150x50 后无碎渣、无「漂浮金属件」（现 377x527 竖版整面板框的病因）。
- 祝福卡必须横版：集中层 G14 已加竖图守卫，「贴图竖图当下恒走 flat，将来横版重绘落地自动回归贴图」——交付竖版等于白做。
- 滑条拖柄在 16x24 显示下轮廓清晰不糊（现版 236x119 铆钉小金属箱降采样后「细节糊死」）。
- HP/SP 填充：「中段亮度≥轨道内芯 3 倍」；HP 鲜红、SP 亮 teal，与 G29 bar_track()/TRACK_BG 轨道体系配合验收。
- 朝向控件：「高频核心交互，改绘制必须真机验证四向选择/点击判定不变（绘制与输入解耦，_get_facing_from_mouse 不动）」。

### 第 28 轮实装接线

- `frame_left_sidebar_slim_base`：「就位流程：ui_frame_spec.gd BUILD_SIDE_PANEL 键改指新名→BuildPanel.tscn SidebarBase 引用→跑 fit_ui_style_assets.py 生成 fit_320x826」（bottom-frame-hex-pods-oversized；中央规格 F7：「均依赖 AI 重绘资产，落图后才改键」）。
- `frame_relic_panel_base`：同名覆盖，既有 frame_relic_panel_base.tres 直接生效。纹章 overlay 挂接：「relic_panel.gd _ready 在 PanelBase 上方加居中 TextureRect（stretch_mode=KEEP_ASPECT_CENTERED，anchor 顶部居中，纹理 UiArtRegistry.get_frame_texture(&"frame_dialog_crest_overlay")），纹理缺失时自动隐藏；blessing/event 面板将来可复用同一 overlay」；「新增 TextureRect 注意默认 visible 状态写对，防 visible=false 回归」。
- `frame_top_status_chip_base` / `frame_resource_item_base`：同名覆盖 + 重出 fit 变体（见验收第 1 条）。
- `frame_sidebar_tab_base`：同名覆盖（竖版改横版）；「BuildPanel.tscn 文本编辑只替换 stylebox 引用行，严禁顺手增删 visible 属性（该面板已 4 次出现 visible=false 回归）」；「需确认无人依赖竖版原图」。
- `frame_small_button_base`：新增 key，派生 `_fit_160x44` 与 `_fit_90x40` 两档；场景侧「三处 normal 换 ExtResource 指向……disabled 改为 StyleBoxFlat（BG_DISABLED+STROKE_SOFT）不再用 overlay 当 base」（flat-default-buttons-clash：BuildPanel Lock/RefreshShopButton 与 CombatHud AutoSkillButton）；「CombatHud.tscn 是高危回归文件，只改三行 ExtResource 引用，不动 visible/布局」。
- `frame_inner_row_base`：新增 key；「落图后把 UiFrameSpec.SETTINGS_ROW 与 BUILD_ICON_BACKPLATE 指到新 key」（settings-frame-family-three-levels；中央规格 F7 同句）。
- `frame_blessing_choice_card_base`：同名覆盖；落地后 G14 竖图守卫自动回归贴图，零代码（现状「默认 margin 18，无专用 .tres」，落图后建议补专用 .tres 或确认默认 margin 适配 ~96-140px 高横卡）。
- `frame_slider_handle`：同名覆盖；「grabber 是 icon 非 stylebox，换图即生效」；「audio_settings_panel.gd 已有 handle 降采样补丁（注释 81-90 行），新图落地后该补丁自动短路（高度≤26 直接用原图），不要删该函数」。
- `bar_progress_fill_hp/sp`：同名覆盖源图后重跑竖向重采样生成 fit_1x30 与 fit_refs（管线见中央规格 A4）；注意 A4 的 ×1.6/×1.4 亮度乘法是对旧暗图的补偿，新鲜亮源图重跑时应去掉倍率，以新图自身亮度为准。
- 朝向控件：入库 `assets/map/CommandMap/`；结构改写（场景侧）：「_draw_deploy_direction_arrow 重写为 draw_texture_rect ring 居中 + 每向 draw_set_transform 旋转画 chevron（选中 active 版，未选 modulate alpha 0.5），删 draw_circle/arc/十字/中心 rect/扇形 polygon……锁定格只保留 _draw_deploy_locked_cell 一层」（direction-picker-programmer-art，scripts/map/map_root_view.gd）；「贴图未就绪前可先落过渡参数版」。

## 35. 第 29 轮：局部修复批（R3 ④）

来源条目：`panel-side-slot-gold-noise`（中央规格 A8 表「frame_result_panel_base 噪点修复 + fit_520x380」行标记为美术 TODO / 场景 gated）、`dialog-bottom-notch-asymmetric`。

本轮不出新版式源图，两项均为对既有资产的修复/重绘替换，需把现有 PNG 作为参考图上传。

### 29-A `frame_result_panel_base` 金棕噪点局部修复

- 操作：上传 `assets/ui/generated/frame_result_panel_base.png`（738x239）做局部 inpaint，输出保持透明背景与原 alpha（不要重新铺 #FF00FF）。

```text
请基于上传的原图做局部修复，保持 738x239 原尺寸、原构图、透明背景与原 alpha 边缘：仅清除左右边框中段竖槽下半段的金棕色噪点（左右镜像各一团，AI 残留），或将其修整为成形的小块黄铜铭牌细节；其余像素与现图保持一致。不要整图重生成，不要改动四角与边带其他细节，不要文字、数字、水印。
```

- 验收要点：「整图重生成（而非局部修补）会改变边框其余细节，引发与历史截图的全面 diff——务必只做局部 inpaint」；与原图逐像素 diff 应仅集中在左右竖槽下半段。
- 实装接线：「修复后需同步重生成两张派生贴图：frame_result_panel_base_fit_refs.png（520x168）与 frame_result_panel_base_fit_520x260.png（沿用项目既有 fit 预缩放流程，Lanczos 降采样），否则运行时（ResultPanel.tscn 直引 fit_520x260.tres）看不到修复效果」；「两张 fit 派生图忘了重生成是最可能的遗漏点」；「.tres 的 texture_margin（56.37/49.32）按原图比例标定，保持源图尺寸不变就不用动 .tres」；「可与 finding 7 提到的可能新增 fit_520x300 合并为一次重生成」（A8 表另记 fit_520x380 依赖 Result 重排、场景 gated，落图时与场景侧确认尺寸取一）。

### 29-B `frame_dialog_box_base` 底缺口重绘

- 操作：上传 `assets/ui/generated/frame_dialog_box_base.png`（701x266）作参考重绘。缺口是「底边左侧 ~x120 处烧死的『语音尾巴』，落在 texture_margin_left=143 的角区内，九宫格拉伸后固定偏左，无法用参数移动」。

```text
请参考上传的 frame_dialog_box_base.png 重绘同款对话文本框底板，纯色背景 #FF00FF，源图约 1400x530（现版 701x266 的 2x，顺带解决清晰度）：深蓝战术奇幻对话文本框底板，金属包角细边，底边平直无缺口（或左右镜像成对缺口），中心区干净可九宫格拉伸，不要文字、数字、图标。
```

- 验收要点：底边无单侧缺口；金属包角与边带细节在 fit 到 1700x238 显示尺寸后不糊；「若选『缺口对齐名牌』方案则缺口位置依赖名牌 x 坐标，与九宫格拉伸冲突，建议直接去尾」。
- 实装接线：「落地后重跑 scripts/dev/fit_ui_style_assets.py 重新生成 fit_1700x238 变体并重标 texture_margin」；「替换 base 源图会连带 fit 变体与 texture_margin 数值，必须三件套一起换」；注意中央规格 S2 已把 fit_1700x238.tres 的 content_margin_left/right 改为 64.0，重标 texture_margin 时保留该口径。

## 36. 第 30 轮：品牌与剧情演出批（R3 ⑤）

来源条目：`menu-title-plain-default-type`（合并 `main-menu-title-plain-logotype`）、`dialog-scene-pure-void-backdrop`（critic 复评）、`event-illustration-placeholder-bang`。

| asset key | 目标尺寸 | 分层类型 | 显示位 |
|---|---|---|---|
| `logo_menu_hexavigil` | ~1024x300 | 单层成图（图内含文字，见豁免说明） | 主菜单标题区（替换 TitleLabel） |
| `page_dialog_camp_night` | 1920x1080 | 整图背景（assets/story/backgrounds/ page_* 族） | 对话演出场景背景 |
| `portrait_dialog_watch_operator` | ~720x960 | 单层剪影立绘 | 对话面板 LeftPortrait 槽（anchor 0.02-0.49） |
| `illu_event_mercenary_camp` | 760x880 | 整幅内容插图 | 事件面板插图区（显示约 330x440） |
| `illu_event_smuggler_caravan` | 760x880 | 整幅内容插图 | 同上 |
| `illu_event_black_market` | 760x880 | 整幅内容插图 | 同上（黑市 + 赌局事件共用） |
| `illu_event_ruin` | 760x880 | 整幅内容插图 | 同上（军械库 + 祭坛事件共用） |
| `illu_event_mana_rift` | 760x880 | 整幅内容插图 | 同上 |

### 36-A `logo_menu_hexavigil` 字标

> ⚠️ 显式豁免：本资产是全文档唯一允许「图内含文字」的项，第 1 节全局提示词中「图内不要出现文字、数字、字母……」对本条不适用；字标内容固定为 "HexaVigil"，拼写必须正确，除该词外仍不得出现任何其他文字、水印或签名。

先复制第 1 节全局提示词（声明上述豁免），再追加：

```text
请生成 1 张游戏标题字标，纯色背景 #FF00FF，约 1024x300：HexaVigil 金属浮雕字标，钢色立体字 + 青色内发光描边，低饱和战术奇幻，可嵌六边形守夜灯纹样点缀，与现有铆钉金属框语言统一。图内只允许出现 "HexaVigil" 这一个单词，拼写必须正确，无背景元素、无水印、无副标题。
```

- 验收要点：拼写必须正确（HexaVigil 大小写一致）；#FF00FF 纯底可抠；约 440x150 显示（@2x 余量）下笔画边缘干净。
- 实装接线：「入库后 MainMenu.tscn TitleLabel 换 TextureRect」（menu-title-plain-default-type）；「保留 Label 作降级回退，运行时按贴图存在性切换」（main-menu-title-plain-logotype；该条目另给备选 key decor_main_logotype/880x300，本文档统一收敛为 logo_menu_hexavigil 一个 key）。

### 36-B `page_dialog_camp_night` 对话背景

沿用第 31 节页面叙事背景的通用约束（16:9、导出 1920x1080、无文字无伪 UI；运行时图保存到 `assets/story/backgrounds/`，原始生成图保存到 `assets/story/backgrounds/raw/`）。

```text
请生成 1 张对话演出背景，1920x1080，stylized painterly fantasy tower-defense key art 同族画风：夜色边界营地远望灯塔微光，低饱和暗蓝，中下部留暗供对话框，无文字、无水印、无伪 UI。
```

- 验收要点：中下部约 1/3 画面保持低对比暗区，不与对话文字争对比（critic 对临时方案的要求「复用主菜单图作底需压暗到不与对话文字争对比」，正式图自身就要为对话框留暗）。
- 实装接线：「DialogPanel.tscn 在 Background 与 BackdropGrid 之间加 TextureRect 'BackdropTexture'（满锚，stretch keep-aspect-covered，modulate≈(0.5,0.55,0.62) 压暗），现有 BackdropGrid（黑 0.18）即兜底 vignette；dialog_panel.gd `_apply_background` 扩展识别 cfg['texture'] 键」（dialog-scene-pure-void-backdrop）；「.tscn 增节点时勿改既有节点 visible」。

### 36-C `portrait_dialog_watch_operator` 对话立绘

```text
请生成 1 张对话立绘，纯色背景 #FF00FF，约 720x960：守夜干员披风剪影，轮廓一线灯塔暖光，低饱和轻奇幻，竖幅半身构图，边缘干净适合抠图，无文字、无边框。
```

- 验收要点：剪影读得出「披风 + 守夜」身份；#FF00FF 抠图后边缘无残色；竖幅构图适配 LeftPortrait 槽（anchor 0.02-0.49）。
- 实装接线：「dialog_panel.gd `_get_portrait_texture`（行 266）是恒 return null 的桩（LeftPortrait/RightPortrait 节点存在但永远无图）」——落图后让该函数返回本纹理即可；「接立绘时 _update_portrait_focus 的 modulate 动画已就绪，只需 _get_portrait_texture 返回纹理」。

### 36-D 事件插图 5 张

```text
请生成竖幅事件场景插图（共 5 张，每张 760x880，可分次单独生成；若同图多张须留足 #FF00FF 间距）：低饱和暗色战术奇幻事件场景插图，主体居中、四边安静，便于嵌入深色金属框，无文字、无伪 UI。

1. illu_event_mercenary_camp：雇佣兵营地篝火。
2. illu_event_smuggler_caravan：走私商队篷车。
3. illu_event_black_market：黑市摊位。
4. illu_event_ruin：废墟祭坛。
5. illu_event_mana_rift：魔力裂隙。
```

- 验收要点：330x440 实际显示尺寸下主体可辨；四边留安静过渡，嵌入深色金属框不打架；5 张同一画风同一明度档。
- 实装接线：「落地需小代码钩子：event_panel.gd `_show_event_config` 按 event_id 前缀映射贴图到新增 TextureRect，缺图回退现有纹章字符（EventGlyph 保留为 fallback）」（event-illustration-placeholder-bang，现状 %EventGlyph 是 64px 的 Label『!』占位，插图区约 330 宽）；风险：「EventPanel.tscn 根节点 visible=false 与 CloseButton visible=false 是正确初始态，编辑场景时不得误改；新增 TextureRect 必须默认 visible=true，谨防编辑器保存回归模式重演」。

## 37. R3 长尾挂起批次与作废说明

### 37.1 长尾批次（已立项，不阻塞本轮）

| 批次 | asset key 约定 | 数量 | 尺寸 / 分层 | 接线 | 来源条目 |
|---|---|---|---|---|---|
| 逐遗物专属图标 | `icon_relic_<buff_id 去前缀 relic_>`（如 icon_relic_legion_mirror） | 37 | 源图约 224x224（与现存 icon_relic_* 一致；relic-rail 条目另给 64x64 口径，按现存族取大），独立 icon | 「ui_art_registry.gd get_icon_texture() 在 icon_key 查找后追加 `texture = get_texture(StringName(cfg.get("id","")), &"icon")`……美术落地即自动生效」；或 buffs.json 每条加 icon_key 并登记 data/ui_icons.json | relic-icons-all-same-pouch / relic-rail-collides-banner / relic-strip-icons-unreadable-scaling |
| 干员商店卡图标 | `icon_unit_<unit_id>`（如 icon_unit_zuo_le、icon_unit_guard_t1） | 21（「可先出本期卡池 5-8 张」） | 源图 96x96（显示 48px），单层内容图（置 backplate 之上、frame 之下） | 「落地零代码：units.json 每条加 ui_icon_path 字段（registry 已支持）」 | shop-class-icons-repetitive |

画面口径：逐遗物图标 =「暗钢圆底 + 金属浮雕主题物，稀有度不画进图——描边由 rarity overlay 负责」「各遗物主题的亮色小剪影（与资源图标同明度）」，逐条画面描述按 `data/buffs.json` 的 name/desc 衍生（triage 示例：「icon_relic_legion_mirror=军团制式护心圆镜」）；干员商店图标 =「干员半身剪影头像，低饱和冷色底、干员主色点缀、深底上轮廓清晰」。优先级：「三选一是伤害最大场景，生图批次可先做祝福池高频遗物」。

注：第 27 轮类别图标即此长尾的过渡兜底；商店卡当前维持职业图标 fallback（「商店卡 BuildListCard 的 fallback_icon_key 已是 class 图标，保持」，unit-identity-three-styles）。干员胸像批（portrait_unit_*，28 张）不在本表——已正式立项，见 `docs/CHARACTER_ASSET_GENERATION_PROMPTS.md` 第 7 节。

### 37.2 作废项（切勿按评审原话重做）

以下资产配方在集中规格裁决中已作废或被程序化方案吸收，不进任何生图批次（摘自 `tmp/ui_round3_central_spec.md` §A8）：

- `frame_relic_filter_tab_base` 的任何 fit 重切 / 选中态合成变体（含 fit_86x32、filter-chip-ornament-crush 提的 fit_120x32）：G12 遗物过滤签全程走 flat，裁决 R5「资产组原配方 F（filter fit/composite）作废」。
- `frame_sidebar_tab_unselected.tres`（StyleBoxFlat 新建）：G19 tab() 全 flat 吸收，裁决 R18。注意：第 28 轮的 `frame_sidebar_tab_base` 横版重制仍有效——服务 .tscn 直引与 disabled 防回归通道，两者不冲突。
- `frame_button_base_fit_280x54/280x52/280x86`：A1 `frame_button_primary_base`（Pillow 程序化合成，非 AI 生图）+ G4 吸收，裁决 R1。
- 可选挂起（本轮均不做，A8 已记录场景侧/程序化替代）：frame_scroll_thumb_horizontal.png 恢复、frame_legend_panel_base_fit_384x200、frame_speed_toggle_active_overlay fit 68x72。
