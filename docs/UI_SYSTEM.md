# UI_SYSTEM

## 1. 目标风格

UI 重构目标以参考图的战术 HUD 信息结构为准，但后续资产风格走轻微奇幻、清新、低饱和路线。界面应服务塔防读图，地图永远是第一视觉层级。

- 顶部：阶段、时间、核心生命、部署上限、暂停/倍速、资源状态。
- 顶部下方：遗物入口与少量遗物缩略提示。
- 左侧：建筑/商店竖向面板，标签固定，列表项紧凑。
- 底部：待部署干员卡组横向栏，卡片显示职业、费用、HP/SP/CD。
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
10. 补齐键鼠交互：`R` 打开/关闭遗物面板，`Esc` 关闭面板，鼠标悬停显示 tooltip，点击遗物卡可展开详情。

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

### 6.2 边栏与面板资产

| 资产 key | 对应 UI 部件 | 建议规格 | 说明 |
|---|---|---:|---|
| `frame_top_status_bar` | `CombatHud/TopBar` | 1200x72 | 顶部主状态条，薄边、浅冷灰底、轻微布纹或磨砂石纹 |
| `frame_top_status_chip` | 阶段、核心、部署、时间、资源状态卡 | 240x64 | 小型信息块，适合九宫格拉伸 |
| `frame_relic_strip` | `RelicStrip` | 720x48 | 顶部下方遗物摘要条，必须比主状态条更轻 |
| `frame_relic_icon_slot_common` | `RelicIcon` 常见遗物槽 | 80x80 | 低饱和灰绿边 |
| `frame_relic_icon_slot_uncommon` | `RelicIcon` 精良遗物槽 | 80x80 | 低饱和蓝青边 |
| `frame_relic_icon_slot_rare` | `RelicIcon` 稀有遗物槽 | 80x80 | 柔和浅金边，不要强金光 |
| `frame_relic_panel` | `RelicPanel` | 900x640 | 完整遗物面板，清爽浅暗底，细边 |
| `frame_relic_card_common` | `RelicCard` 常见卡 | 360x112 | 列表/网格遗物卡常见态 |
| `frame_relic_card_uncommon` | `RelicCard` 精良卡 | 360x112 | 精良态，边框只轻微变色 |
| `frame_relic_card_rare` | `RelicCard` 稀有卡 | 360x112 | 稀有态，避免厚金框 |
| `frame_left_build_sidebar` | `BuildPanel` | 320x760 | 左侧建筑/商店栏 |
| `frame_build_tab_idle` | 建筑/商店页签 idle | 160x48 | 页签普通态 |
| `frame_build_tab_selected` | 建筑/商店页签 selected | 160x48 | 页签选中态 |
| `frame_build_list_card` | `BuildListCard` | 280x104 | 建筑/商店列表项 |
| `frame_bottom_deploy_deck` | `CombatHud/DeployDeck` | 980x176 | 底部待部署卡组底栏 |
| `frame_operator_card_idle` | `OperatorCard` ready | 164x148 | 干员卡普通态 |
| `frame_operator_card_selected` | `OperatorCard` hover/drag | 164x148 | 干员卡选中态 |
| `frame_operator_card_deployed` | `OperatorCard` 已部署 | 164x148 | 已部署态，琥珀/绿轻边 |
| `frame_operator_card_cooldown` | `OperatorCard` 冷却 | 164x148 | 冷却态，低饱和红灰遮罩 |
| `frame_right_detail_sidebar` | `UnitDetailPanel` | 380x760 | 右侧单位详情栏 |
| `frame_detail_section` | 属性、生命、技能区块 | 340x120 | 右侧详情中的分组面板 |
| `frame_skill_button_primary` | 激活技能按钮 | 320x52 | 主按钮，青色轻边 |
| `frame_button_secondary` | 撤退、关闭、刷新等按钮 | 320x52 | 次按钮，灰蓝轻边 |
| `frame_button_danger` | 危险操作按钮 | 320x52 | 红灰轻边 |
| `frame_wave_preview` | 波次/路径预览 | 360x220 | 右侧或顶部附近的小信息窗 |
| `frame_legend_panel` | 右下战场图例 | 260x220 | 图例与标记说明 |
| `frame_tooltip` | hover tooltip | 360x160 | 小型说明气泡，不要尖角太夸张 |
| `frame_blessing_panel` | `BlessingPanel` | 640x440 | 遗物三选一面板 |
| `frame_blessing_choice_card` | 祝福候选遗物卡 | 560x112 | 可复用 `RelicCard` 选择态 |
| `frame_event_panel` | `EventPanel` | 640x420 | 随机事件面板 |
| `frame_dialog_box` | `DialogPanel/TextBox` | 1100x220 | 对话框底栏 |
| `frame_dialog_speaker_plate` | `DialogPanel/SpeakerPlate` | 240x56 | 说话人名牌 |
| `frame_result_panel` | `ResultPanel` | 720x520 | 结算面板 |
| `frame_map_popup` | `MapInteractionPopup` | 360x260 | 地图对象交互弹窗 |
| `frame_audio_settings_panel` | 音量设置面板 | 420x280 | 设置弹窗 |
| `frame_icon_tile` | 通用图标底板 | 96x96 | 建筑、技能、遗物、属性图标底板 |
| `bar_progress_track` | HP/SP/核心进度条底 | 320x24 | 细长轨道 |
| `bar_progress_fill_hp` | HP 填充 | 320x24 | 柔和红色 |
| `bar_progress_fill_sp` | SP 填充 | 320x24 | 柔和青蓝 |
| `bar_progress_fill_core` | 核心生命填充 | 320x24 | 柔和琥珀 |

### 6.3 通用功能图标

| 资产 key | 对应 UI 部件 | 说明 |
|---|---|---|
| `icon_phase_day` | 顶部阶段卡 | 白天阶段 |
| `icon_phase_night` | 顶部阶段卡 | 夜晚阶段 |
| `icon_phase_blessing` | 顶部阶段卡 / 祝福面板 | 祝福/遗物选择阶段 |
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

1. 先实现 `RelicStrip`、`RelicPanel`、`RelicIcon`、`RelicCard` 的无资产版本。
2. 把 `CombatHudController` 里的遗物 tooltip 文本迁到 `UiDisplayText` 和遗物组件。
3. 将 `BlessingPanel` 的三选一按钮改为遗物卡组件。
4. 按参考图重排 `CombatHud.tscn`，把 `RelicStrip` 放进顶部区域。
5. 调整 `UiLayoutRules`，保证遗物条、底部卡组、右侧详情在小屏不互相遮挡。
6. 生成并接入第一批资产：通用面板、遗物图标、资源图标、职业图标。
7. 再补齐建筑图标、技能图标、地图图例图标。
8. 用 1920x1080、1600x900、1366x768、1280x720 检查文本、按钮、卡片、tooltip 是否溢出。

## 8. 验收标准

- 已拥有遗物不再只藏在资源 tooltip 中，玩家能在顶部看到入口和数量。
- 任意遗物都能通过 hover 快速查看名称、稀有度和效果。
- 完整遗物面板能查看全部遗物，并支持按类别筛选。
- `BlessingPanel`、`RelicStrip`、`RelicPanel` 使用同一套遗物显示组件和同一套文案格式化规则。
- 新资产接入后，删除资产仍能回退到文本占位，不影响项目运行。
