# UI Asset AI Regeneration TODO

本文档记录已经接入离线派生管线、但仍建议用 AI 或美术重新生成的 UI 美术源素材。

## 范围

- 已全面接入派生管线：`assets/ui/build/ui_asset_build.json` 当前覆盖 `assets/ui/generated/*.png` 下全部 209 个正式 PNG。
- 其中 84 个有 `.tres` 的 `stylebox_texture` 资源是可缩放 UI 框、进度条、按钮、overlay、槽位和面板，属于本轮 AI 重生成清单。
- `icon_*` 等 texture-only 图标已接入管线，但不是本轮重生成目标；只有发现语义错误、文字残留、边缘脏像素或风格明显不一致时才单独重生。

## 生成原则

沿用 `docs/UI_ASSET_GENERATION_PROMPTS.md` 的全局提示词和对应批次。额外强制要求：

- 所有 `frame_*`、`bar_*`、`*_base`、`*_overlay` 必须适合 Godot NinePatch / 9-slice。
- 四边拉伸区不能有徽章、符号、文字、数字、独特花纹、断裂机械件或任何不能被拉伸的装饰。
- 特殊装饰只能放四角，或者单独导出 overlay。
- overlay 必须是透明背景，只包含叠加效果、描边、冷却遮罩、高亮或禁用效果，不包含底板。
- 进度条和滑条必须拆成 track/fill/handle，不画固定百分比。
- 所有文字、数字、图标、头像、费用、状态由 Godot 节点绘制，不进入资产图。

## Agent 生成提示词

把下面提示词交给负责生成 UI 素材的 Agent。每次只处理一个批次或一个小组，按表格中的 asset key 输出源图与裁切结果。

```text
你要为 Godot 塔防游戏重生成一批 UI 框架素材。目标不是做普通网页 UI，而是做有设计感、可九宫格拉伸的游戏 HUD 美术件。

项目风格：
- 清新战术奇幻 UI，低饱和暗色，轻盈、实用、有游戏界面质感。
- 材质可以混合深冷灰金属、雾蓝灰石材、暗布纹、轻微浅金属边、柔和魔法微光。
- 不要厚重黄金框、卷轴羊皮纸、宝石堆、过度写实机械、科幻霓虹大面积发光。

核心工程约束：
- 所有素材必须适合 Godot NinePatch / 9-slice。
- 四边可拉伸区必须是连续纹理、直线/轻折线边、均匀阴影或可重复材质。
- 四边中段不要放徽章、符号、文字、数字、独特花纹、断裂机械件、单独铆钉或不可变形装饰。
- 特殊装饰只能放四角，或者单独导出 overlay。
- 中心区域保持干净，方便运行时放文字、图标、头像、数值、列表。
- 不要在图里生成任何文字、数字、字母、水印、签名或假 UI 文案。
- 背景透明；如果生成工具必须用色键，则使用纯 #FF00FF，裁切入库前转透明。

重要审美要求：
- “适合九宫格”不等于只能做圆角矩形。可以使用轻微切角、阶梯形轮廓、斜切金属角、薄折线边、局部内凹、非对称但可拉伸的边框节奏。
- 参考 `frame_build_list_card_base.png` 的方向：轮廓有结构、有层次、有战术感，但边中仍然可以拉伸；四角负责设计感，边中负责连续性。
- 不要让所有卡片和面板共用同一套纹理。外层容器、内层卡片、微型信息条、按钮、徽标必须有明确层级差异。

层级差异设计：
- 外层面板/侧栏/大弹窗：更安静、更薄、更像背景承托；边框克制，中心暗而干净。
- 中层卡片/列表项：轮廓更明确，可以有轻切角、浅内阴影、局部角装饰；要能从外层面板中跳出来。
- 卡片内的小卡片/信息条/属性行：不要复制外层卡片纹理；使用更轻的材质、更低对比、更简单的线条，像嵌入式信息槽。
- 按钮：比信息条更可点击，边缘更硬朗，中心更平整；hover/primary/danger/disabled 通过透明 overlay 表达状态，不要复制完整底板。
- 图标/头像 backplate：像内容托盘，中心简洁；frame 是覆盖框，中心必须透明或可抠空。
- 进度条/滑条：端帽固定，中心横向连续；track、fill、handle 互相区分，不画固定进度。

输出要求：
- 按 asset key 命名每个裁切结果，例如 `frame_button_base.png`。
- overlay 必须透明背景，只包含叠加光效、描边、遮罩或状态效果，不包含底板。
- base/backplate/frame/overlay 分层清楚，不能把运行时会变化的内容烘进底图。
- 交付源 sheet 和裁切后的单图。单图替换 `assets/ui/source/<asset_key>.png`，不要直接替换 generated 或 styles。
```

## 裁切与替换流程

1. 按 `docs/UI_ASSET_GENERATION_PROMPTS.md` 对应批次生成 source sheet，保存到临时目录或 `assets/ui/source/raw/`。
2. 按提示词中的裁剪顺序裁切，文件名必须等于 asset key，例如 `frame_button_base.png`。
3. 只替换 `assets/ui/source/<asset_key>.png`，不要直接改 `assets/ui/generated/` 或 `assets/ui/styles/`。
4. 如果新源图尺寸变化，更新 `assets/ui/build/ui_asset_build.json` 中该 asset 的 `base_size`；`target_size` 保持 UI 设计尺寸，除非场景尺寸也变了。
5. 检查或调整 `assets/ui/templates/<asset_key>.tres` 的 `texture_margin_*` 与 `content_margin_*`。模板文件只保存 margins，不绑定 texture。
6. 运行：

```powershell
Godot --headless --path . --script scripts/tools/generate_ui_derived_assets.gd
Godot --headless --import --path . --quit
```

7. 打开或运行 `scenes/debug/UiAssetDerivedPreview.tscn` 和 `scenes/debug/UiNinePatchPreview.tscn` 检查目标尺寸下边角、边中和中心拉伸是否干净。

## 需要 AI 重生成的资源

| Asset | 类型 | target_size | 当前 source_size | 替换源文件 | 重生成注意 |
|---|---|---:|---:|---|---|
| `bar_progress_fill_core` | 进度条 | 320x24 | 1372x86 | `res://assets/ui/source/bar_progress_fill_core.png` | 端帽只放两端，中心横向连续可拉伸；不要固定百分比。 |
| `bar_progress_fill_hp` | 进度条 | 320x24 | 1371x85 | `res://assets/ui/source/bar_progress_fill_hp.png` | 端帽只放两端，中心横向连续可拉伸；不要固定百分比。 |
| `bar_progress_fill_sp` | 进度条 | 320x24 | 1379x83 | `res://assets/ui/source/bar_progress_fill_sp.png` | 端帽只放两端，中心横向连续可拉伸；不要固定百分比。 |
| `bar_progress_track` | 进度条 | 320x24 | 1387x153 | `res://assets/ui/source/bar_progress_track.png` | 端帽只放两端，中心横向连续可拉伸；不要固定百分比。 |
| `frame_action_button_base` | 按钮 | 150x44 | 354x153 | `res://assets/ui/source/frame_action_button_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_action_panel_base` | 九宫格底板 | 520x150 | 646x300 | `res://assets/ui/source/frame_action_panel_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_blessing_choice_card_base` | 九宫格底板 | 560x112 | 267x380 | `res://assets/ui/source/frame_blessing_choice_card_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_blessing_panel_base` | 九宫格底板 | 640x440 | 782x458 | `res://assets/ui/source/frame_blessing_panel_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_bottom_deploy_rail_base` | 九宫格底板 | 980x176 | 350x196 | `res://assets/ui/source/frame_bottom_deploy_rail_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_build_icon_backplate` | 图标/头像槽 | 72x72 | 278x313 | `res://assets/ui/source/frame_build_icon_backplate.png` | 内容承托底，中心简洁可缩放，边中无独特图案。 |
| `frame_build_icon_frame` | 图标/头像槽 | 72x72 | 271x313 | `res://assets/ui/source/frame_build_icon_frame.png` | 中心孔洞透明，边中不能有独特徽章；角可装饰。 |
| `frame_build_list_card_base` | 九宫格底板 | 280x104 | 324x216 | `res://assets/ui/source/frame_build_list_card_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_build_list_card_selected_overlay` | 状态 overlay | 156x104 | 156x104 | `res://assets/ui/source/frame_build_list_card_selected_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_button_base` | 按钮 | 320x52 | 409x235 | `res://assets/ui/source/frame_button_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_button_danger_overlay` | 状态 overlay | 320x52 | 377x242 | `res://assets/ui/source/frame_button_danger_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_button_disabled_overlay` | 状态 overlay | 320x52 | 417x284 | `res://assets/ui/source/frame_button_disabled_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_button_primary_overlay` | 状态 overlay | 320x52 | 357x239 | `res://assets/ui/source/frame_button_primary_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_cost_badge_base` | 九宫格底板 | 56x32 | 134x225 | `res://assets/ui/source/frame_cost_badge_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_detail_section_base` | 九宫格底板 | 340x120 | 491x226 | `res://assets/ui/source/frame_detail_section_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_dialog_box_base` | 九宫格底板 | 1100x220 | 701x266 | `res://assets/ui/source/frame_dialog_box_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_dialog_speaker_plate_base` | 九宫格底板 | 240x56 | 460x121 | `res://assets/ui/source/frame_dialog_speaker_plate_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_event_choice_button_base` | 按钮 | 560x64 | 250x253 | `res://assets/ui/source/frame_event_choice_button_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_event_panel_base` | 九宫格底板 | 640x420 | 760x355 | `res://assets/ui/source/frame_event_panel_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_icon_backplate` | 图标/头像槽 | 96x96 | 331x322 | `res://assets/ui/source/frame_icon_backplate.png` | 内容承托底，中心简洁可缩放，边中无独特图案。 |
| `frame_icon_frame` | 图标/头像槽 | 96x96 | 335x325 | `res://assets/ui/source/frame_icon_frame.png` | 中心孔洞透明，边中不能有独特徽章；角可装饰。 |
| `frame_left_sidebar_base` | 九宫格底板 | 320x760 | 300x904 | `res://assets/ui/source/frame_left_sidebar_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_legend_panel_base` | 九宫格底板 | 260x220 | 285x318 | `res://assets/ui/source/frame_legend_panel_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_legend_row_base` | 九宫格底板 | 220x28 | 364x99 | `res://assets/ui/source/frame_legend_row_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_map_popup_base` | 九宫格底板 | 360x260 | 329x125 | `res://assets/ui/source/frame_map_popup_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_operator_card_base` | 九宫格底板 | 164x148 | 561x142 | `res://assets/ui/source/frame_operator_card_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_operator_card_cooldown_overlay` | 状态 overlay | 164x148 | 201x332 | `res://assets/ui/source/frame_operator_card_cooldown_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_operator_card_cooldown_selected_overlay` | 状态 overlay | 164x148 | 196x336 | `res://assets/ui/source/frame_operator_card_cooldown_selected_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_operator_card_deployed_overlay` | 状态 overlay | 164x148 | 192x335 | `res://assets/ui/source/frame_operator_card_deployed_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_operator_card_selected_overlay` | 状态 overlay | 164x148 | 201x335 | `res://assets/ui/source/frame_operator_card_selected_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_operator_cost_badge` | 九宫格底板 | 48x36 | 185x115 | `res://assets/ui/source/frame_operator_cost_badge.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_operator_portrait_backplate` | 图标/头像槽 | 128x72 | 199x204 | `res://assets/ui/source/frame_operator_portrait_backplate.png` | 内容承托底，中心简洁可缩放，边中无独特图案。 |
| `frame_operator_portrait_frame` | 图标/头像槽 | 128x72 | 238x78 | `res://assets/ui/source/frame_operator_portrait_frame.png` | 中心孔洞透明，边中不能有独特徽章；角可装饰。 |
| `frame_operator_stat_row` | 九宫格底板 | 140x20 | 396x78 | `res://assets/ui/source/frame_operator_stat_row.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_operator_title_strip` | 九宫格底板 | 140x28 | 190x208 | `res://assets/ui/source/frame_operator_title_strip.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_relic_card_base` | 九宫格底板 | 360x112 | 257x408 | `res://assets/ui/source/frame_relic_card_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_relic_card_hover_overlay` | 状态 overlay | 360x112 | 254x409 | `res://assets/ui/source/frame_relic_card_hover_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_relic_entry_button_base` | 按钮 | 128x44 | 228x137 | `res://assets/ui/source/frame_relic_entry_button_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_relic_filter_selected_overlay` | 状态 overlay | 120x40 | 240x134 | `res://assets/ui/source/frame_relic_filter_selected_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_relic_filter_tab_base` | 九宫格底板 | 120x40 | 241x135 | `res://assets/ui/source/frame_relic_filter_tab_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_relic_icon_backplate` | 图标/头像槽 | 80x80 | 243x235 | `res://assets/ui/source/frame_relic_icon_backplate.png` | 内容承托底，中心简洁可缩放，边中无独特图案。 |
| `frame_relic_icon_frame` | 图标/头像槽 | 80x80 | 244x234 | `res://assets/ui/source/frame_relic_icon_frame.png` | 中心孔洞透明，边中不能有独特徽章；角可装饰。 |
| `frame_relic_panel_base` | 九宫格底板 | 900x640 | 648x321 | `res://assets/ui/source/frame_relic_panel_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_relic_rarity_common_overlay` | 状态 overlay | 352x202 | 352x202 | `res://assets/ui/source/frame_relic_rarity_common_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_relic_rarity_rare_overlay` | 状态 overlay | 345x201 | 345x201 | `res://assets/ui/source/frame_relic_rarity_rare_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_relic_rarity_uncommon_overlay` | 状态 overlay | 345x202 | 345x202 | `res://assets/ui/source/frame_relic_rarity_uncommon_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_relic_strip_base` | 九宫格底板 | 720x48 | 1038x90 | `res://assets/ui/source/frame_relic_strip_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_resource_delta_badge` | 九宫格底板 | 76x24 | 292x135 | `res://assets/ui/source/frame_resource_delta_badge.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_resource_item_base` | 九宫格底板 | 88x44 | 521x179 | `res://assets/ui/source/frame_resource_item_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_result_panel_base` | 九宫格底板 | 720x520 | 738x239 | `res://assets/ui/source/frame_result_panel_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_result_stat_row_base` | 九宫格底板 | 600x44 | 518x115 | `res://assets/ui/source/frame_result_stat_row_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_right_detail_sidebar_base` | 九宫格底板 | 380x760 | 406x957 | `res://assets/ui/source/frame_right_detail_sidebar_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_scroll_thumb` | 滚动条 | 16x60 | 68x247 | `res://assets/ui/source/frame_scroll_thumb.png` | 端点固定，中段连续；竖横复用时避免方向性独特花纹。 |
| `frame_scroll_track` | 滚动条 | 16x200 | 69x393 | `res://assets/ui/source/frame_scroll_track.png` | 端点固定，中段连续；竖横复用时避免方向性独特花纹。 |
| `frame_settings_button_base` | 按钮 | 64x64 | 204x169 | `res://assets/ui/source/frame_settings_button_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_settings_panel_base` | 九宫格底板 | 420x300 | 715x612 | `res://assets/ui/source/frame_settings_panel_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_settings_row_base` | 九宫格底板 | 360x48 | 793x167 | `res://assets/ui/source/frame_settings_row_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_sidebar_tab_base` | 九宫格底板 | 160x48 | 377x527 | `res://assets/ui/source/frame_sidebar_tab_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_sidebar_tab_selected_overlay` | 状态 overlay | 160x48 | 337x211 | `res://assets/ui/source/frame_sidebar_tab_selected_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_skill_desc_box` | 九宫格控件 | 320x150 | 590x273 | `res://assets/ui/source/frame_skill_desc_box.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_skill_icon_backplate` | 图标/头像槽 | 72x72 | 178x191 | `res://assets/ui/source/frame_skill_icon_backplate.png` | 内容承托底，中心简洁可缩放，边中无独特图案。 |
| `frame_skill_icon_frame` | 图标/头像槽 | 72x72 | 198x205 | `res://assets/ui/source/frame_skill_icon_frame.png` | 中心孔洞透明，边中不能有独特徽章；角可装饰。 |
| `frame_slider_fill` | 滑条 | 280x24 | 1270x56 | `res://assets/ui/source/frame_slider_fill.png` | 端帽只放两端，中心横向连续可拉伸；不要固定百分比。 |
| `frame_slider_handle` | 滑条 | 40x40 | 236x119 | `res://assets/ui/source/frame_slider_handle.png` | 端帽只放两端，中心横向连续可拉伸；不要固定百分比。 |
| `frame_slider_track` | 滑条 | 280x24 | 1338x66 | `res://assets/ui/source/frame_slider_track.png` | 端帽只放两端，中心横向连续可拉伸；不要固定百分比。 |
| `frame_speed_toggle_active_overlay` | 状态 overlay | 110x52 | 452x111 | `res://assets/ui/source/frame_speed_toggle_active_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_speed_toggle_base` | 九宫格底板 | 220x56 | 601x149 | `res://assets/ui/source/frame_speed_toggle_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_tooltip_base` | 九宫格底板 | 360x160 | 651x321 | `res://assets/ui/source/frame_tooltip_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_top_status_bar_base` | 九宫格底板 | 1200x72 | 1443x192 | `res://assets/ui/source/frame_top_status_bar_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_top_status_chip_active_overlay` | 状态 overlay | 240x64 | 333x147 | `res://assets/ui/source/frame_top_status_chip_active_overlay.png` | 透明背景，只含叠加光效/描边/遮罩，不含底板。 |
| `frame_top_status_chip_base` | 九宫格底板 | 240x64 | 273x154 | `res://assets/ui/source/frame_top_status_chip_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_undo_button_base` | 按钮 | 160x44 | 207x160 | `res://assets/ui/source/frame_undo_button_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_unit_header_strip` | 九宫格底板 | 340x56 | 797x137 | `res://assets/ui/source/frame_unit_header_strip.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_unit_portrait_backplate` | 图标/头像槽 | 128x128 | 272x273 | `res://assets/ui/source/frame_unit_portrait_backplate.png` | 内容承托底，中心简洁可缩放，边中无独特图案。 |
| `frame_unit_portrait_frame` | 图标/头像槽 | 128x128 | 271x269 | `res://assets/ui/source/frame_unit_portrait_frame.png` | 中心孔洞透明，边中不能有独特徽章；角可装饰。 |
| `frame_unit_stat_row` | 九宫格底板 | 320x28 | 429x101 | `res://assets/ui/source/frame_unit_stat_row.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_wave_enemy_row_base` | 九宫格底板 | 320x32 | 1114x218 | `res://assets/ui/source/frame_wave_enemy_row_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_wave_preview_base` | 九宫格底板 | 360x220 | 470x306 | `res://assets/ui/source/frame_wave_preview_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_wave_route_toggle_base` | 九宫格底板 | 120x32 | 388x123 | `res://assets/ui/source/frame_wave_route_toggle_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
| `frame_wave_warning_row_base` | 九宫格底板 | 320x32 | 655x125 | `res://assets/ui/source/frame_wave_warning_row_base.png` | 角可装饰，四边拉伸区保持连续纹理；不含文字、数字、图标。 |
## 不在本轮 AI 重生成范围

- `icon_*` texture-only 图标：已接入派生管线，但通常不做 NinePatch 拉伸；除非出现文字、水印、边缘脏像素、语义错误或风格严重不一致，否则不需要本轮重生。
- `assets/ui/generated/` 和 `assets/ui/styles/`：这些是离线脚本输出，不手工替换。
- `assets/ui/templates/`：只维护 margins，不放正式贴图引用。
