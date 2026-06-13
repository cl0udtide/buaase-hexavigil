# UI Asset Derived Audit

审计日期：2026-06-13
分支：`fix/ui-asset-integration`

本次按 `actual_sizes -> build config -> generated/style -> scene reference` 反向检查离线派生 UI 资产。当前事实来源是 `assets/ui/build/ui_asset_actual_sizes.json`、`assets/ui/build/ui_asset_build.json`、正式 `scenes/**/*.tscn`、`scripts/**/*.gd` 与 `data/**/*.json`。

## 摘要

- build 配置资产数：213。
- 缺失的 `source/template/generated/style` 文件：0。
- 正式 UI 引用了但未纳入 build 的真实资源：0。扫描到的 `res://assets/ui/generated/%s.png` 是 `UiFrameSpec.texture_path()` 的格式化模板，不是实际资源路径。
- 正式 `scenes` 与 `scripts/ui` 直接引用 `assets/ui/source` / `assets/ui/templates`：0。
- `StyleBoxTexture` margin 越界：0。
- 已删除冗余 build 资产：45 个，包括 31 个未接入遗物图标、5 个未正确接入的遗物 overlay、`frame_action_button_base`、`frame_speed_toggle_active_overlay`、`frame_top_status_chip_active_overlay`，以及 6 个只有 `UiFrameSpec` 死常量、无场景/数据/业务脚本使用的 frame。
- 需要重点人工视觉验收的尺寸族冲突：按钮状态 overlay、进度条 track、详情 section、遗物入口/卡片、wave spawn/warning。

## 未使用资产列表

这些 asset 原本在 build 配置中存在，且 `source_png`、`output_png` 都齐全，但正式扫描没有 `actual_sizes` 使用记录，`scenes/scripts/data` 也没有显式路径引用。2026-06-13 已按精简要求从 build 配置、manifest、source/generated 产物中删除。

| Asset key | 路径 | 判断依据 | 建议 |
|---|---|---|---|
| `icon_relic_aura_lens` | `assets/ui/source/<key>.png` + `assets/ui/generated/<key>.png` | 无 actual use，无正式引用 | 已删除 |
| `icon_relic_bastion_anchor` | 同上 | 同上 | 已删除 |
| `icon_relic_battle_standard` | 同上 | 同上 | 已删除 |
| `icon_relic_bayonet_drill` | 同上 | 同上 | 已删除 |
| `icon_relic_black_market_token` | 同上 | 同上 | 已删除 |
| `icon_relic_bounty_ledger` | 同上 | 同上 | 已删除 |
| `icon_relic_caster_focus` | 同上 | 同上 | 已删除 |
| `icon_relic_compressed_bulwark` | 同上 | 同上 | 已删除 |
| `icon_relic_core_capacitor` | 同上 | 同上 | 已删除 |
| `icon_relic_core_patch` | 同上 | 同上 | 已删除 |
| `icon_relic_defender_plate` | 同上 | 同上 | 已删除 |
| `icon_relic_duelist_contract` | 同上 | 同上 | 已删除 |
| `icon_relic_glass_barrel` | 同上 | 同上 | 已删除 |
| `icon_relic_greedy_seal` | 同上 | 同上 | 已删除 |
| `icon_relic_guard_manual` | 同上 | 同上 | 已删除 |
| `icon_relic_industrial_blueprint` | 同上 | 同上 | 已删除 |
| `icon_relic_iron_patience` | 同上 | 同上 | 已删除 |
| `icon_relic_lumber_contract` | 同上 | 同上 | 已删除 |
| `icon_relic_mana_resonator` | 同上 | 同上 | 已删除 |
| `icon_relic_mana_siphon` | 同上 | 同上 | 已删除 |
| `icon_relic_mobile_command` | 同上 | 同上 | 已删除 |
| `icon_relic_overclocked_core` | 同上 | 同上 | 已删除 |
| `icon_relic_quarry_glyph` | 同上 | 同上 | 已删除 |
| `icon_relic_range_pylon` | 同上 | 同上 | 已删除 |
| `icon_relic_rapid_recall` | 同上 | 同上 | 已删除 |
| `icon_relic_recurve_string` | 同上 | 同上 | 已删除 |
| `icon_relic_sharpened_orders` | 同上 | 同上 | 已删除 |
| `icon_relic_sniper_scope` | 同上 | 同上 | 已删除 |
| `icon_relic_travel_pack` | 同上 | 同上 | 已删除 |
| `icon_relic_vanguard_frame` | 同上 | 同上 | 已删除 |
| `icon_relic_wallwright_kit` | 同上 | 同上 | 已删除 |
| `frame_action_panel_base` | `assets/ui/source/<key>.png` + `assets/ui/generated/<key>.png` | 无 actual use，无 `.tscn` 直引，`GameUiStyle.action_bar_panel()` 无调用 | 已删除 |
| `frame_icon_backplate` | 同上 | 无 actual use，无 `.tscn` 直引，通用 `icon_tile()` wrapper 无调用 | 已删除 |
| `frame_icon_frame` | 同上 | 无 actual use，无 `.tscn` 直引，通用 `icon_frame()` wrapper 无调用 | 已删除 |
| `frame_result_stat_row_base` | 同上 | 无 actual use，无 `.tscn` 直引，`result_stat_row()` wrapper 无调用 | 已删除 |
| `frame_top_status_bar_base` | 同上 | 无 actual use，无 `.tscn` 直引，`top_hud_panel()` wrapper 无调用 | 已删除 |
| `frame_undo_button_base` | 同上 | 无 actual use，无 `.tscn` 直引，无业务脚本调用 | 已删除 |

说明：表中路径表示同名 `source_png` 与 `output_png` 成组存在，即 `assets/ui/source/<key>.png` 和 `assets/ui/generated/<key>.png`。

注意：不能只按 `.tscn` 直引判断。`frame_blessing_panel_base` 没有 `.tscn` 直引，但 `scenes/ui/BlessingPanel.tscn` 挂载 `scripts/ui/blessing_panel.gd`，运行时通过 `GameUiStyle.blessing_panel()` 与 `GameUiStyle.apply_frame_margin(..., FRAME_BLESSING_PANEL)` 使用；因此它不是精简对象。

## 未纳入 Build 的正式 UI 资源

未发现真实遗漏。`res://assets/ui/generated/%s.png` 只来自 `scripts/ui/ui_frame_spec.gd` 的格式化字符串，不能作为待配置资源。

## Overlay/Base 对齐审计

| Overlay | 对应 base | actual size | 输出 PNG 对齐 | 结论 |
|---|---|---:|---|---|
| `frame_build_list_card_selected_overlay` | `frame_build_list_card_base` | overlay `272x104`，base `280x104` | overlay `272x181`，base `280x187` | 高度族一致，宽度因 Game 实例收缩到 272；可用，但需验收 selected 对齐 |
| `frame_button_primary_overlay` | `frame_button_base` | overlay `318x76`，base `280x36` | 不同 | 被 ActionPanel 大按钮和小按钮共用，尺寸族冲突，建议拆出语义资源 |
| `frame_button_disabled_overlay` | `frame_button_base` | overlay `318x76`，base `280x36` | 不同 | 同上；尤其被 `72x72`、`318x76`、`280x33` 共用 |
| `frame_button_danger_overlay` | `frame_button_base` | overlay `280x33`，base `280x36` | 高度接近但 PNG 不同 | 可短期保留，仍建议与普通按钮族统一 |
| `frame_operator_card_*_overlay` | `frame_operator_card_base` | 全部 `164x184` | PNG 高度相差 3-5px | actual 对齐，输出图高度略不一致；需人工确认透明 overlay 未复制底板 |
| `frame_relic_card_hover_overlay` | `frame_relic_card_base` | 未被正式扫描使用 | PNG `434x112` vs base `425x112` | 已删除，hover 改由代码色块表达 |
| `frame_relic_filter_selected_overlay` | `frame_relic_filter_tab_base` | 未被正式扫描使用 | 只配置自身；未见正式引用 | 已删除，selected 复用 filter tab base |
| `frame_relic_rarity_*_overlay` | `frame_relic_card_base` / icon frame | 未被正式扫描使用 | `345-352x201-202` 与 card/icon 尺寸族不一致 | 已删除，rarity 改由代码色块表达 |
| `frame_sidebar_tab_selected_overlay` | `frame_sidebar_tab_base` | 两者 `134x50` | PNG 高度不同 | actual 对齐，输出图语义需验收是否只含状态层 |
| `frame_speed_toggle_active_overlay` | `frame_speed_toggle_base` | overlay `216x82`，base `200x82` | PNG `216x123` vs base `331x82` | 已删除，`SpeedActiveOverlay` 复用通用 primary overlay |
| `frame_top_status_chip_active_overlay` | `frame_top_status_chip_base` | 未被正式扫描使用 | PNG `240x106` vs base `273x154` | 已删除，selected hud cell 改为代码色块 |

## Margin 越界列表

未发现越界。所有 `assets/ui/styles/*.tres` 满足：

- `texture_margin_left + texture_margin_right <= output_png_width`
- `texture_margin_top + texture_margin_bottom <= output_png_height`
- `content_margin_left + content_margin_right <= output_png_width`
- `content_margin_top + content_margin_bottom <= output_png_height`

派生脚本当前按 output PNG 相对 source PNG 的 `png_scale` 同步 texture/content margin；`bar_progress_fill_hp/sp` 的 `1x30` 实际 fill 宽度会用配置 target 宽度兜底，不会误伤 `bar_actor_status_*` 的真实小尺寸 `46x6/46x4`。

## 尺寸族冲突列表

| Asset | 尺寸差异 | 建议 |
|---|---|---|
| `bar_progress_track` | `1x30`、`114x25` | fill 兜底已处理；track 仍可考虑拆 `bar_unit_detail_track` 与 `bar_core_track` |
| `frame_button_base` | `30x28` 到 `280x33/36` | 建议拆 `frame_button_compact_base`、`frame_button_action_base` |
| `frame_button_primary_overlay` / `disabled_overlay` | `30x28`、`72x72`、`318x76`、`280x33` 等 | overlay 不适合跨大按钮/图标按钮/普通按钮共用，建议按语义拆分 |
| `frame_detail_section_base` | `59x175`、`176x240`、`330x16` | 通用 detail section 被多种比例复用，建议区分详情分组、事件分组、细分隔条 |
| `frame_relic_strip_base` | `126x40`、`126x84` | 遗物入口和条带高度不一，建议验收后拆分 |
| `frame_result_panel_base` | `520x260`、`520x581` | 结算大面板与较矮面板共用，建议按结果页布局拆 |
| `frame_top_status_chip_base` | `160/210/220/300x82` | 同一高度多宽度可接受，但边中装饰需验收 |
| `frame_wave_spawn_card_base` | `113x132`、`328x356` | 出怪口卡存在大比例差异，建议按 spawn group 与 enemy card 拆 |
| `frame_wave_warning_row_base` | `23x29`、`23x113` | 宽度扫描异常偏小，需复核布局节点和实际显示 |
| `icon_close` | `14x14`、`36x36` | 图标可缩放，但建议避免同一 PNG 承担按钮主图标和内联小图标 |
| `icon_relic_bag` | `24x24`、`40x40`、`86x30` | 入口按钮 icon 与卡片/小图标语义不同，建议拆出 `icon_relic_entry_bag` |

## 需要 AI 重生成的素材

继续沿用 `docs/UI_ASSET_AI_REGEN_TODO.md` 的优先级。基于本次审计，新增确认点：

- `frame_button_primary_overlay`、`frame_button_disabled_overlay`：被多尺寸按钮共用，建议先拆分语义资源，再决定是否重生成。
- `frame_wave_spawn_card_base`、`frame_wave_warning_row_base`：扫描尺寸差异异常，需先在 `CombatHud.tscn` 实际画面确认布局，再重生成。

## Preview 修复记录

`scripts/debug/ui_asset_derived_preview.gd` 已补充 `output_png` 展示块，并在该块叠加正式 output margin 边界。现在每个 asset row 能同时看到 source 图、output 图、margin 编辑控件、actual uses、actual size 和正式 output style 渲染效果。

## 搜索结论

- `_fit_`：仅发现布局/摄像机 fit 命名，不是旧 `_fit_` UI 资产机制残留。
- `StyleBoxFlat`：保留在 `GameUiStyle` fallback、debug preview 和 combat sandbox 调试样式中，不是正式 UI 美术资源替代。
- `draw_rect()`：主要在地图绘制、敌人 debug 框、debug preview margin guide 中，不是正式 UI 面板 fallback。
- `IconLabel`、`GearIcon`：未发现正式残留。
