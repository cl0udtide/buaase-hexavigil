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
- 所有可缩放 UI 资源必须适合 Godot NinePatch / 9-slice：四边拉伸区不能有徽章、符号、文字、数字、独特花纹或不能变形的装饰。
- 特殊装饰只能放在四角，或单独导出为透明 overlay；overlay 只包含叠加光效、描边或状态效果，不包含底板。
- 如果旧图把关键装饰放在上、下、左、右边中段，不为它实现复杂分段边框，标记为需要重新生成。
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

2. `frame_top_status_chip_base`
4. `frame_speed_toggle_base`
6. `frame_settings_button_base`
7. `frame_relic_strip_base`
8. `frame_relic_entry_button_base`

```text
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 8 个独立资产，按裁剪顺序排列。不要文字、数字、图标。

这批用于游戏顶部信息区：阶段、时间、核心生命、部署上限、暂停/倍速、资源和遗物摘要。请把它设计成清爽的战场信息 UI，而不是完整的顶部截图。

2. frame_top_status_chip_base：单个状态信息块底板。
4. frame_speed_toggle_base：暂停/倍速容器底板。
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

```text
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 8 个独立资产，按裁剪顺序排列。不要文字、数字、建筑图标。

这批用于左侧建筑/商店栏。左侧栏由代码动态放入页签、建筑列表、价格和撤销按钮，所以底板不要画死列表内容。

1. frame_left_sidebar_base：左侧栏整体背景。
2. frame_sidebar_tab_base：页签普通底板。
3. frame_sidebar_tab_selected_overlay：建筑列表项底板；这是正式 `BuildListCard/CardBase` 的稳定文件名，不要按页签 overlay 生成。
4. frame_build_list_card_base：商店 Unit 商品卡底板；这是正式 `ShopUnitCard/CardBase` 的稳定文件名，与建筑卡做差异化。
5. frame_build_icon_backplate：建筑图标背板。
6. frame_build_icon_frame：建筑图标覆盖框，中心保持 #FF00FF。
7. frame_cost_badge_base：成本徽标底板。
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
4. `frame_relic_card_base`
6. `frame_relic_icon_backplate`
7. `frame_relic_icon_frame`

```text
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 10 个独立资产，按裁剪顺序排列。不要文字、数字、遗物图标。

这批用于遗物面板、筛选页签、遗物卡、遗物图标承托和稀有度状态。遗物内容由代码动态填入。

1. frame_relic_panel_base：完整遗物面板底板。
2. frame_relic_filter_tab_base：遗物筛选页签底板。
4. frame_relic_card_base：遗物卡底板。
6. frame_relic_icon_backplate：遗物图标背板。
7. frame_relic_icon_frame：遗物图标覆盖框，中心保持 #FF00FF。
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
5. `frame_wave_preview_base`
6. `frame_legend_panel_base`
7. `frame_legend_row_base`

```text
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 7 个独立资产，按裁剪顺序排列。不要文字、数字、头像、图标。

这批用于对话框、结算面板、波次预览和战场图例。所有文字、头像、统计项和图例图标由代码添加。

1. frame_dialog_box_base：对话文本框底板。
2. frame_dialog_speaker_plate_base：说话人名牌底板。
3. frame_result_panel_base：结算面板底板。
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


```text
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是放进遗物卡中的小物件图标。请保持低饱和、轻奇幻、清晰可读。

```

## 24. 第 22 轮：遗物图标第二批

保存源图为：`source_sheet_22_relic_icons_b.png`

裁剪顺序：


```text
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是放进遗物卡中的小物件图标。请保持低饱和、轻奇幻、清晰可读。

```

## 25. 第 23 轮：遗物图标第三批

保存源图为：`source_sheet_23_relic_icons_c.png`

裁剪顺序：


```text
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是放进遗物卡中的小物件图标。请保持低饱和、轻奇幻、清晰可读。

```

## 26. 第 24 轮：遗物图标第四批

保存源图为：`source_sheet_24_relic_icons_d.png`

裁剪顺序：


```text
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 7 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是放进遗物卡中的小物件图标。请保持低饱和、轻奇幻、清晰可读。

```

## 27. 角色头像类资产生成原则

如果后续需要生成角色头像或半身像，单独开新对话生成，不要混在 UI 框架资产里。

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

```text
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 7 个独立资产，按裁剪顺序排列。不要文字、数字、图标。

这些是补充资产，用于资源项、今晚敌情模块和白天上下文操作面板。它们需要和前面 UI 框架保持同一清新战术奇幻风格。

1. frame_resource_item_base：单个资源项底板。
2. frame_resource_delta_badge：资源增长/消耗速率徽标底板。
3. frame_wave_enemy_row_base：今晚敌情单条敌人/波次条目底板。
4. frame_wave_route_toggle_base：路线预览开关底板。
5. frame_wave_warning_row_base：路线异常/堵路警告行底板。
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
