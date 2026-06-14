# UI Asset AI Regeneration TODO

本文档只记录经过“源图外观 + 实际 UI 位置 + 九宫格拉伸方向”复核后，仍值得重新生成的少量 UI 框架素材。不要全量重生；每次只处理一个 UI 区域或一小组强相关素材。

## 纳入标准

只有同时满足以下条件之一，才进入本轮重生成列表：

- 实际组件会被明显横向或纵向拉伸，且当前图在该拉伸方向的边中段有徽章、分隔柱、固定槽位、断裂结构、中心牌匾等不可重复装饰。
- 源图比例或语义与实际节点明显不符，例如竖卡被当宽条、宽条被当高面板、整组选中框被当单个选中态。
- 内层卡片/标题条/状态 overlay 复制外层卡片边框，导致卡片套卡片、状态层像第二张底板，且该问题在实际节点层级中很显眼。

不纳入本轮的情况：

- 实际使用主要是缩小，而不是过度拉伸。
- 问题可以通过 Godot 运行时 modulation、裁剪或 template margins 缓解。
- 图标、头像框、小徽章、进度填充、滑条轨道/填充/拖柄等目前没有明显九宫格拉伸破坏。

## 必须遵守

- 生图只能用 imagegen；Python 只能裁切、去背景、检测、校验，不能程序化绘制新 UI。
- 生图背景必须是纯 `#FF00FF`；入库后背景完全透明。
- 最终 PNG alpha 只能是 `{0,255}`，不得有半透明像素。
- 不得有文字、数字、字母、水印、签名、假 UI 文案、固定列表、固定按钮组、固定进度。
- 只替换 `assets/ui/source/<asset_key>.png`；`assets/ui/generated/` 与 `assets/ui/styles/` 由派生脚本生成。
- `*_base` 只做底板或承托，不画运行时内容。
- `*_overlay` 只表达状态，不复制底板，不带实心卡面。
- 九宫格边中段必须连续、干净、可重复；装饰只放四角，或拆成额外 overlay。

## 优先重生成清单

| Asset | 实际位置/尺寸依据 | 为什么必须重生成 | 重生成成什么样 |
|---|---|---|---|
| `frame_bottom_deploy_rail_base` | `scenes/ui/combat/CombatHud.tscn` 底部部署栏；配置目标约 `980x176`，当前源图约 `350x196` | 实际是横向很宽的部署 rail，当前更像竖向/短面板，横向拉伸约 2.8 倍；若边中有固定板件或槽位会被拉长，且会和干员卡外框重复 | 宽横向战术部署栏底板；中段是连续暗色承托面，不画固定卡槽、按钮组、角色位；角部可有轻装饰 |
| `frame_operator_card_base` | `scenes/ui/combat/OperatorCard.tscn` 根卡片 `164x184` | 实际是竖向干员卡，当前源图比例接近横条，压缩/拉伸后层级和留白都不对；如果内置头像/属性区会和真实子节点重复 | 竖向干员卡底板；外轮廓清晰但中部干净，不内置头像框、费用徽章、属性行或文字 |
| `frame_operator_title_strip` | `OperatorCard.tscn` 标题条 `132x42` | 实际是卡片内部的轻量标题条，当前像完整小面板，被压扁后形成卡片套卡片 | 横向短标题条，低对比、薄边、嵌入式；不要复制 `frame_operator_card_base` 的厚边框 |
| `frame_operator_card_selected_overlay` | `OperatorCard.tscn` 选中态覆盖整张卡 `164x184` | 状态层若复制完整卡框，会在干员卡上叠出第二层边框；这是实际 hover/selected 最显眼的问题 | 透明中心的轻描边/角部高亮；严格贴合干员卡外轮廓，不带实心底板 |
| `frame_operator_card_deployed_overlay` | `OperatorCard.tscn` 已部署状态覆盖整张卡 `164x184` | 与选中态同类，完整边框式 overlay 会和底卡重复；状态语义应轻，不应改变卡片结构 | 透明状态叠层，可用角部标记或边缘色块表达已部署，不写文字、不复制底板 |
| `frame_operator_card_cooldown_overlay` | `OperatorCard.tscn` 冷却遮罩覆盖整张卡 `164x184` | 当前若是完整实心卡面，会遮住运行时内容并形成第三层卡框；冷却应由遮罩/调制表达 | 硬边、二值 alpha 的冷却遮罩或边缘压暗层；不写冷却数字，不带半透明像素 |
| `frame_operator_card_cooldown_selected_overlay` | `OperatorCard.tscn` 冷却且选中覆盖整张卡 `164x184` | 同时承担冷却和选中，最容易叠出重复边框；需要和上面两个状态层保持同一轮廓体系 | 冷却遮罩 + 轻选中描边，透明中心优先，不能像另一张完整卡片 |
| `frame_blessing_choice_card_base` | 祝福候选卡；配置目标 `560x112`，当前源图约 `267x380` | 实际是宽横向选择卡，当前像竖卡；横向拉伸超过 2 倍、纵向压缩明显，会破坏边中装饰和内部视觉重心 | 宽横向候选卡；比大面板轻，比普通按钮丰富；不画固定图标、文字、稀有度或子卡框 |
| `frame_event_choice_button_base` | `scripts/ui/event_panel.gd` 动态选项按钮；配置目标 `560x64`，场景中作为横向选项 | 实际是横向按钮/选项，当前偏方/偏竖；拉伸后边中装饰会变形，且不像可点击选项 | 横向事件选项按钮底；左右端帽固定，中段连续；不写选项文字，不画固定图标 |
| `frame_map_popup_base` | 地图弹窗；配置目标 `360x260`，当前源图约 `329x125` | 实际是中等高度弹窗，当前像窄条；纵向拉伸约 2 倍，顶部/底部中心装饰会被拉开 | 360x260 弹窗底板；中心干净可放动态按钮和说明，装饰仅角部或拆 overlay |
| `frame_result_panel_base` | `scenes/ui/ResultPanel.tscn` 面板 `520x260`，配置目标 `720x520`，当前源图约 `738x239` | 实际是高面板，当前过扁；纵向拉伸明显，若上下边中有牌匾/分隔会被拉坏 | 结算高面板底；不画统计行、评级、固定列表；边中连续，中心大面积干净 |
| `frame_relic_panel_base` | `scenes/ui/relic/RelicPanel.tscn` 面板 `668x430`，配置目标 `900x640`，当前源图约 `648x321` | 实际大面板纵向扩展明显；当前上/下边中装饰会在拉伸时变形，并和内部遗物卡抢层级 | 大型遗物面板底；外框安静，中心暗色承托，装饰只在四角或拆成 overlay |
| `frame_relic_card_base` | `scripts/ui/relic/relic_card.gd` 高度 `96/108` 的横向遗物卡；配置目标 `360x112`，当前源图约 `257x408` | 实际是横向列表卡，当前像竖卡；横向拉伸、纵向压缩都很大，且容易画出内置图标框/文本区与真实子节点重复 | 横向遗物卡底；区分于外层遗物面板，但不要内置图标背板、文字、稀有度框或固定按钮 |
> `frame_relic_card_hover_overlay` 与 `frame_speed_toggle_active_overlay` 已从派生资产中移除。遗物 hover/稀有度高亮改由 `GameUiStyle` 代码色块表达；倍速 active 层复用通用按钮 overlay，不再单独生图。

## 追加处理：WavePreviewPanel 专项

`WavePreviewPanel` 原本是临时新增的右侧“今晚敌情”模块。复核后发现它虽然已经接入 `CombatHud.tscn`，但内部敌人卡、路线按钮和警告行的素材语义仍偏临时，容易出现厚重横幅塞进小组件、按钮像分段开关、内层卡片套外层卡片的问题。因此单独作为一小组处理：

| Asset | 实际位置/尺寸依据 | 为什么重新生成 | 重生成成什么样 |
|---|---|---|---|
| `frame_wave_preview_base` | `CombatHud.tscn` 右侧 `WavePreviewPanel`，实际约 `384x316` | 旧外框较重，边中装饰多，右侧列内呼吸感不足 | 安静的敌情面板底板，中心干净，不画敌人列表、路线图或固定标题 |
| `frame_wave_spawn_card_base` | `WaveSpawnCardTemplate`，实际约 `328x132` | 原本是裸 `PanelContainer`，分组边界不足；不能只靠内部复制出的敌人卡撑视觉 | 轻量出怪口分组承托，比外层面板轻，不像完整卡片套卡片，中心可放出怪口标签和敌人小卡 |
| `frame_wave_enemy_row_base` | `WaveEnemyCardTemplate`，实际小卡约 `150x126` | 旧源图是 `1114x218` 大横幅，被压进小敌人卡后比例和层级都不对 | 轻量内部敌人承托，不像完整大面板，不画头像、文字、属性行 |
| `frame_wave_route_toggle_base` | `WaveRouteToggle`，实际 `64x36` | 旧图带分段柱，语义像一组三段开关；实际只是标题行内单按钮 | 单个小型路线按钮底，不画分段结构、数字或固定状态 |
| `frame_wave_warning_row_base` | `WaveWarningRow`，实际约 `328x38` | 旧警告行偏厚，容易抢外层面板层级 | 轻量警告条，保留红色危险语义，但中心干净、边中连续 |

## 追加处理：详情内层信息槽

右侧详情与干员卡内的分组/属性行虽然不是最严重的拉伸问题，但视觉验收后确认存在“卡片套卡片”：内层底纹像完整小卡片，和外层 `frame_right_detail_sidebar_base`、`frame_operator_card_base` 抢层级。因此作为一组补充处理，目标是更轻、更扁、更像嵌入式信息槽。

| Asset | 实际位置/尺寸依据 | 为什么重新生成 | 重生成成什么样 |
|---|---|---|---|
| `frame_detail_section_base` | `UnitDetailPanel.tscn` 中 `VitalsSectionBase`、`StatsSectionBase`、`SkillSectionBase`，约 `344x116`、`344x108`、`344x230`；也被 `EventPanel.tscn` / `RelicPanel.tscn` 作为通用 detail section | 旧图像完整内层卡片，叠在详情侧栏/事件/遗物面板内会形成卡片套卡片 | 通用轻量分组底板，低对比细边，中心干净，不画标题、列表、图标或固定内容 |
| `frame_unit_stat_row` | `UnitDetailPanel.tscn` 的 `AtkStatRow`、`DefStatRow`、`ResStatRow`、`BlockStatRow`、`AspdStatRow`、`CovenantStatRow`，实际约 `132x30/40` | 旧配置仍按 `320x28` 老尺寸生成，实际小行里边框显重，像小卡片 | 扁平属性信息条，左右端帽轻，横向中段连续，不抢分组底板层级 |
| `frame_operator_stat_row` | `OperatorCard.tscn` 的 `HpStatRow`、`SpStatRow`、`CdStatRow`，实际约 `132x30` | 旧行底放在干员卡内部显得像重复按钮/底板 | 更弱的短信息行底纹，适合 HP/SP/CD 文本，不画按钮态、不写文字数字 |

## 暂缓，不需要本轮重生成

这些素材之前被列入过，但按“实际拉伸破坏严重”标准复核后先移出本轮：

| Asset | 暂缓原因 |
|---|---|
| `bar_progress_fill_hp` | 实际作为进度填充被裁剪/缩放使用，主要风险是运行时裁切表现，不是九宫格过度拉伸；当前不优先生图 |
| `bar_progress_fill_sp` | 同上 |
| `bar_progress_fill_core` | 同上 |
| `bar_progress_track` | 在详情/状态区域主要作为细轨使用，当前先通过 margins 与运行时尺寸观察，不作为首批重生 |
| `frame_slider_track` | 设置面板中实际宽度约 `170`，当前源图主要是缩小；不是过度拉伸破坏 |
| `frame_slider_fill` | 同上，作为 slider 填充由控件裁剪/绘制，先不重生 |
| `frame_slider_handle` | 当前问题更像控件使用/尺寸语义问题，未发现实际九宫格拉伸破坏到必须生图 |
| `frame_button_base` / `frame_button_*_overlay` | 多处使用但尺寸以小按钮/普通按钮为主；先不全局替换，避免影响面过大 |
| `frame_left_sidebar_base` / `frame_right_detail_sidebar_base` | 虽然是大容器，但当前更需要在整体 UI 预览中判断，不作为第一批生图 |
| `frame_resource_item_base` / `frame_legend_row_base` | 实际多为小型信息行或缩小使用，不符合本轮“过度拉伸且破坏大”的条件 |
| `frame_icon_*` / `frame_*_portrait_*` / `frame_relic_icon_*` / `frame_skill_icon_*` | 多为固定尺寸图标/头像承托，不按本轮 NinePatch 拉伸问题处理 |

`frame_build_list_card_selected_overlay` 已不再作为正式 UI 资源生成或引用。建筑卡与商店 Unit 卡的 hover/selected 态改为简单白色提亮；源素材可保留作历史对照，但不应重新接回正式场景。

## 子 Agent 生图提示词骨架

每个子 Agent 只负责一个 UI 区域。主 Agent 串行验收，不合格直接废弃，不靠程序画图补救。

```text
你要为 Godot 塔防游戏重生成一小组 UI 框架素材，必须贴近现有清新战术奇幻、低饱和暗色风格。

仓库路径：
e:\资料\课程资料\大三下\软工\BUAASE-HexaVigil

必须先读：
- AGENTS.md
- docs/UI_ASSET_AI_REGEN_TODO.md
- docs/UI_ASSET_GENERATION_PROMPTS.md
- docs/UI_SYSTEM.md
- scripts/dev/crop_ui_assets.py
- assets/ui/build/ui_asset_build.json
- 本组 asset 对应的 .tscn / .gd 实际使用位置

本组目标：
- asset keys: <只填本组 keys>
- UI 位置: <节点路径/场景/脚本>
- 实际尺寸: <实际节点尺寸与 target size>
- 当前源图问题: <比例错误、拉伸方向装饰、卡片套卡片、overlay 复制底板等>
- 参考素材: <同区域应保持一致的现有 source png>

生成要求：
1. 只能用 imagegen 创作，不得用 Python/Pillow/程序化绘制新图。
2. sheet 背景必须是纯 #FF00FF，不要透明背景。
3. 最终 PNG alpha 只能是 0 或 255；不要半透明高光、阴影、禁用、冷却。
4. 不要文字、数字、字母、水印、头像、固定列表、固定按钮组、固定进度。
5. NinePatch 边中段必须连续、干净、可重复；装饰只放四角，或拆成 overlay。
6. base 只做承托；overlay 只做状态，不复制底板；frame 中心孔洞要透明；backplate 中心要干净。
7. 生图后保存 raw sheet 到临时目录，由主 Agent 用 crop_ui_assets.py 裁切和验收。
```

## 验收命令

每个替换批次至少运行：

```powershell
python scripts/dev/crop_ui_assets.py --output-dir tmp/ui_generated_candidate --sheet <source_sheet_name>.png --clean
godot --headless --path . --script scripts/tools/generate_ui_derived_assets.gd
godot --headless --import --path . --quit
git diff --check
```

每个批次最终记录：

- 当前分支；
- raw sheet 路径；
- 处理的 asset keys；
- 替换的 `assets/ui/source/*.png`；
- alpha 集合是否为 `{0,255}`；
- 不透明品红像素是否为 `0`；
- 检查过的 UI 节点、实际尺寸和 template margins；
- 仍需人工视觉验收的点。
