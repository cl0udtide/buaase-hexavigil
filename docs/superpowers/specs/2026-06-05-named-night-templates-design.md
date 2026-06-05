# 命名夜晚出怪模板 + 白天关卡预告 设计（#210）

> 状态：设计待评审
> 主线 issue：#210（细化自 #177，联动 #215）
> 日期：2026-06-05
> 分支：`feature/named-night-templates`

## 1. 背景与目标

当前夜晚波次按 `day` 直接读 `data/waves.json`（硬编码 day 1–6），缺少可被玩家记忆、可提前规划的关卡主题。本设计把夜晚出怪整理成**一批具名模板**，并在**白天到来时把当晚关卡醒目预告**，同时重构右上角出怪预览。

目标（对齐 #210 验收）：
- 建立 ≥10 个具名夜晚出怪模板（本设计共 15 个）。
- 白天开始时即确定当晚模板，并在 HUD 醒目展示关卡名 + 文案 + 关键敌情。
- 右上角预览读取**同一份已解析模板**，保证「预告 = 实际生成」。
- 不破坏 `night_started` / `night_cleared` / 核心结算链路；与路径预览、动态阻挡预览、Boss 二选一兼容。

## 2. 范围 / 非范围

**范围**
- 模板数据结构与全表（15 个，含按方舟关卡文案风格撰写的 `desc`）。
- 白天确定当晚模板的确定性解析层（存入 RunState）。
- 右上角预览重构（v2：A 紧凑骨架 + 每出怪口横向卡片）。
- 白天关卡名揭示横幅（动效方案 A，所有夜晚统一）。
- 退役并删除 `data/waves.json`。

**非范围（仅留接口，不实现）**
- #177 夜中动态机制（动态出怪口、夜中变向）——模板 schema 与「白天解析层」是其接缝，本期不实现。
- #215 可变流程长度 / 多模式——「day→梯队曲线」做成可外置的小配置，本期固定 6 晚。

## 3. 决策摘要（已与需求方确认）

| 决策点 | 结论 |
|---|---|
| 范围边界 | 专注 #210，#177/#215 仅留接口 |
| 当晚模板如何确定 | **分梯队随机池**：按 day 查梯队 → 种子随机抽 → 存 RunState |
| Boss 夜 | **保留终局 Boss 夜**（最后一晚从 Boss 梯队抽） |
| 命名调性 | **混合**：普通夜走界园成语风（名字自带战术暗示），Boss 夜走萨卡兹史诗风 |
| 文案 `desc` | 分腔：普通夜=**界园文言志异腔**；爱国者=**萨卡兹神话悲怆腔**；奶龙酋长=**抽象/梗腔**（文案措辞需求方后续自行微调） |
| 模板落点 | 解析逻辑加进 `WaveManager`；RunState 写入由 `GameController` 负责 |
| 预览形态 | v2：标题区（关卡名+文案）+ 每出怪口横向卡片；移除堵路/路线臆测信息 |
| 横幅动效 | 方案 A「卷轴展开」，所有夜晚统一，非阻塞 |
| `waves.json` | **删除**（内容迁入模板，不保留兜底） |

## 4. 数据层

### 4.1 `data/wave_templates.json` Schema

新增配置表，**`entries` 沿用原 `waves.json` 条目格式**，使 `WaveManager` 的展开/定时/加权逻辑基本不动。

```jsonc
{
  "id": "slug_tide",            // 英文主键，小写下划线
  "name": "蠹潮汹涌",            // 具名（显示）
  "desc": "虫蠹之患，起于微末。待你察觉时，已成潮势，退之不及。", // 一段关卡文案（界园/萨卡兹/抽象 分腔）
  "tier": "early",             // early | mid | late | boss
  "key_enemies": ["lumberjack_veteran"], // 白天高亮的关键敌人；可省，缺省自动推断
  "entries": [
    { "time": 0.0, "enemy_id": "slime", "spawn_key": "S1", "count": 6, "interval": 0.9 },
    { "time": 5.0, "enemy_id": "lumberjack_veteran", "spawn_key": "S3", "count": 2, "interval": 1.5 }
  ]
}
```

字段说明：
- `entries`：与原 `waves.json` 完全一致，含可选 `enemy_choices`（加权随机，Boss 二选一沿用）。
- `desc`：关卡文案，1–2 短句，世界内口吻、给氛围与处境，**不罗列敌人数量**。用于白天横幅与右上角预览标题区。
- `key_enemies`：可选。缺省时由代码自动推断（见 §6 推断规则）。
- `tier`：决定该模板属于哪个梯队池。

### 4.2 梯队与 day 映射（6 晚）

`day → 梯队` 曲线本期写在 `WaveManager` 常量，**注释标记为 #215 外置点**：

| Day | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| 梯队 | early | early | mid | mid | late | **boss** |

`boss_day = 6`（最后一晚）。#215 拉长流程时只需扩展这张曲线 + 增补模板。

### 4.3 模板全表（15 个）

普通夜（early/mid/late）走界园成语风、名字自带战术暗示；Boss 走萨卡兹史诗风（奶龙除外，走抽象）。`desc` 为基线文案，措辞需求方后续自行微调。构成以原 `waves.json` day1–6 为配平基线，缺口补足（数值可自由取整，无既定平衡约束）。

**Early（4，对应 Day 1–2）**

- `slug_tide` **蠹潮汹涌**　key: `lumberjack_veteran`
  - desc：「虫蠹之患，起于微末。待你察觉时，已成潮势，退之不及。」
  - 构成：源石虫海 + 伐木老手趁夜拆建
- `moonlit_hounds` **群犬逐月**　key: `hound`
  - desc：「犬逐月而吠，人闻声而惧。真正咬人的那只，从不在月下出声。」
  - 构成：猎狗群高速突进 + 士兵跟进
- `nightfall_axe` **樵斧夜叩**　key: `lumberjack_veteran`
  - desc：「樵夫司木，昼伐于林，夜伐于户。斧斤所至，墙垣与林木，无异也。」
  - 构成：双伐木老手为核心 + 源石虫铺场
- `swarming_assault` **蚁附之势**　key: `soldier`
  - desc：「蚁附之众，前仆而后继，不计生死。挡得其一，挡不得其千。」
  - 构成：士兵+源石虫人海强攻 + 弩手压制

**Mid（5，对应 Day 3–4）**

- `arts_eclipse` **术火蔽空**　key: `caster`
  - desc：「术火无形，自空而降。见其光时，已临你顶上。」
  - 构成：术师 + 法术无人机远程压制
- `locust_swarm` **飞蝗扑灯**　key: `arts_drone`
  - desc：「墙可拒兽，不可拒飞。蝗之扑灯，不问高下，只趋一处明。」
  - 构成：妖怪无人机 + 法术无人机空袭主导（飞行）
- `splitting_brood` **裂卵成群**　key: `splitting_originium_slug`
  - desc：「碎其一者，反生其二。杀之愈众，来之愈繁，无有穷尽。」
  - 构成：分裂源石虫 + 高能源石虫，越打越多
- `ironwall_advance` **铁壁徐进**　key: `shieldguard`
  - desc：「徐徐而进者最难当。盾牌后头的东西，从不知何为急。」
  - 构成：持盾精锐 + 轻甲卫兵盾墙慢推
- `crossfire_volley` **暗弩攒射**　key: `crossbowman`
  - desc：「暗弩无声，引而不发。待你望见那箭，弦上早已空了。」
  - 构成：弩手 + 双持剑士远程集火 + 术师

**Late（4，对应 Day 5）**

- `siege_breach` **攻坚拔砦**　key: `siege_breaker`
  - desc：「拔砦者不绕行。当其道者，是墙是人，一概砸开。」
  - 构成：破城锤手 + 粉碎攻坚手强拆
- `greatblade_abyss` **巨刃临渊**　key: `sarkaz_greatswordsman`
  - desc：「刃大逾人，步重撼地。临渊而立者，不肯退，亦无路可退。」
  - 构成：萨卡兹大剑手高血压硬桥 + 双持剑士
- `heavyplate_siege` **重铠压境**　key: `heavy_defender`
  - desc：「甲厚则锋钝。你加诸它的每一击，它都默默记下——而后，照旧前行。」
  - 构成：重装防御者 + 持盾 + 轻甲超高防压境
- `arts_cataclysm` **术穹倾覆**　key: `senior_caster`
  - desc：「高术者一抬手，夜穹为之倾覆。法阵既成，你已无处可避。」
  - 构成：高阶术师 + 术师 + 法术无人机大范围法伤

**Boss（2，对应 Day 6，终局二选一由种子定）**

- `fiends_carnival` **群魔乱舞**（奶龙酋长 · 抽象/梗腔）　key: `milk_dragon_chief`
  - desc：「别问它从哪儿冒出来的，问就是——群魔乱舞。爱发奶龙的小朋友，它今晚亲自来了。」
  - 构成：奶龙酋长（含第二形态）+ 杂兵
- `twilight_triumph` **凯旋终焉**（爱国者 · 萨卡兹神话腔）　key: `patriot`
  - desc：「英雄死了又死，故事讲了又讲。他曾为旗帜行军，如今旗帜只余灰烬——可没人，准他停下。」
  - 构成：爱国者·行军→毁灭 + 杂兵

> 命名借自真实集成战略文学线但不照抄：界园「越山海/借力打力/暗箭难防」式 → 普通夜；萨卡兹「王冠之下/时光凯旋」式 →「凯旋终焉」；奶龙酋长本是抽象顶流，单独走梗腔（「群魔乱舞」）。文案锚定真实 register：界园文言志异（「禳，祛也；解，消也……」）、萨卡兹神话腔（「……英雄被神化，变得遥不可及」）。

## 5. 选取与解析流程

### 5.1 RunState 字段

新增（在 `reset_for_new_run` 清空）：
- `night_template_id: StringName`（当晚已解析模板 id）
- `used_template_ids: Array[StringName]`（本局已用模板，用于同梯队池内不重复）

### 5.2 解析算法（确定性）

在 `GameController.enter_day(day)` 内，**设置 phase=DAY 后、发 `day_started` 前**：
1. `tier = WaveManager.tier_for_day(day)`。
2. `template_id = WaveManager.resolve_night_template(tier, run_seed, day, used_template_ids)`：
   - 取该 `tier` 下全部模板，剔除 `used_template_ids` 中已用的（若全用过则不剔除，回退到全池）。
   - 用 `seed = hash("%d|%d|%s" % [run_seed, day, tier])` 的 `RandomNumberGenerator` 抽一个。
3. `run_state.night_template_id = template_id`；`used_template_ids.append(template_id)`。
4. Boss 二选一（`enemy_choices`）仍在条目层用 `run_seed+day+entry_index` 解析——因为模板已在白天定死，预览与夜晚解析同种子同结果，天然一致。

> 解析为纯函数（`WaveManager` 不写 RunState）；RunState 写入集中在 `GameController`，符合现有职责边界。

### 5.3 WaveManager API 变更

- 新增 `tier_for_day(day) -> StringName`（读 §4.2 曲线）。
- 新增 `resolve_night_template(tier, run_seed, day, used_ids) -> StringName`（纯函数）。
- 新增 `start_wave_for_template(template_id)`：跑指定模板的 entries（原 `start_wave_for_day` 的展开逻辑迁移到此）。
- 新增 `get_wave_preview_for_template(template_id) -> Dictionary`：在现有 preview 聚合基础上，附加 `name`、`desc`、`tier`、`key_enemies`、`total_count`、按 `spawn_key` 分组的 `entries` 与 `spawn_order`。
- 移除按 day 读 `waves.json` 的旧路径（含 `_get_wave_cfg_with_fallback`）；`NightManager.start_night(day)` 改为读 `run_state.night_template_id` → `start_wave_for_template`（不再按 day 重新滚算，避免与白天预告不一致）。
- 如需，保留 `get_wave_preview_for_day(day)` 作测试用薄封装（内部解析 day→template_id 后转调）。

### 5.4 DataRepo 变更

- 移除 `waves.json` 加载；新增加载 `data/wave_templates.json` 到 `_tables["wave_templates"]`（按 `id` 建索引）。
- 新增 `get_wave_template_cfg(id) -> Dictionary`、`get_wave_templates_by_tier(tier) -> Array`。
- 删除 `get_wave_cfg(day)`（或保留为内部测试封装，二选一并在 PR 说明）。

## 6. 右上角预览重构（v2）

### 6.1 结构（替换现有单滚动 Label）

`WavePreviewPanel` 内容改为：
1. **标题区**：`DAY N · 今夜` 角标 + **关卡名（大字）** + **关卡文案 `desc`**（小字斜体、autowrap，替换原通用「今晚敌情」）。
2. **合计行**：`合计来袭 N · 活跃出怪口 K`。
3. **每出怪口横向卡片**（`VBoxContainer` 内若干 `HBoxContainer`）：左侧口标（S1/S2/S3 + 与地图出怪口同色圆点），右侧该口敌人 chip（`HFlowContainer` 自动换行，敌人立绘头像 + ×数量），关键敌 chip 描金。
4. **底部**：沿用现有「路线」开关（`WaveRouteToggle`）。

去掉内部 `ScrollContainer` 滚动依赖；面板高度自适应（带上限），靠每口卡片紧凑排布容纳。

### 6.2 数据流

- 控制器不再走 `_format_wave_preview_text`（纯文本拼接）。改为 `get_wave_preview_for_template(run_state.night_template_id)` 拿结构化 dict → 调 `CombatHud.set_wave_preview_data(dict)` 按节点填充。
- 敌人头像：新增 enemy_id → 立绘路径助手，路径 `res://assets/sprites/enemies/<visual_key>/idle/<visual_key>_idle_000.png`（`visual_key` 取自 enemy_cfg）。缺图兜底用类型字形/纯色块。
- 关键敌高亮：取模板 `key_enemies`；缺省时**自动推断**＝按「威胁权重」(Boss/demolisher > 远程/术师 > 高数量) 取前 1–2 个。

### 6.3 路线警告处置

- 路线/堵路是**玩家造阻挡建筑触发的动态状态**（`path_service.find_path_preview` 的 `no_path`/`core_enclosed`/`path_too_short`），**不属于模板信息**，不进出怪口卡片。
- 现有「路线」叠加层 + 警告逻辑**保持不变**；警告仅在实际被堵时作为底部条件性提示出现（沿用 `_collect_route_warning_lines`），不占常驻位置。

## 7. 白天关卡预告横幅（方案 A）

### 7.1 节点与触发

- `CombatHud.tscn` 新增居中覆盖节点 `LevelIntroBanner`（`mouse_filter = IGNORE`，不挡操作、不暂停游戏），含 DAY 角标 / 关卡名 Label / 琥珀下划线 `ColorRect` / 文案 Label（autowrap）。
- 控制器 `_on_day_started(day)` 读 `run_state.night_template_id` → 取 `name`/`desc`/`total_count` → 播放横幅。

### 7.2 动画分段（方案 A「卷轴展开」，纯 Tween/AnimationPlayer，可复现）

1. DAY 角标淡入 + 轻微上浮（`modulate.a` 0→1，子节点 `position.y`）。
2. 关卡名上浮淡入（`TRANS_CUBIC`：子节点 `position.y` +16→0，`modulate.a` 0→1）。
3. 琥珀下划线由中心向两侧展开（`ColorRect` 宽度 Tween）。
4. 文案 `desc` 淡入（多句时停留时长按文案长度自适应，保证可读完）。
5. 停留 ≈1.6s（随文案长度上浮）。
6. 整体上浮淡出。

时长 ≈ 入场 0.5s + 停留 1.6s+ + 退场 0.4s。点击可提前跳过（可选）。视觉作用于子节点，不动主节点 `global_position`（符合 AGENTS.md）。

## 8. 兼容性与迁移

- **EventBus / 流程**：`enter_day` 仅在原有顺序中插入「解析模板 + 写 RunState」，`day_started`/`night_started`/`night_cleared`/`core_destroyed` 与结算链路不变。
- **NightManager**：改读 `run_state.night_template_id`，保证与白天预告一致。
- **Boss 终局**：`day6` 命中 boss 梯队；二选一沿用 `enemy_choices` 加权 + 种子，白天即定死并在预告显示解析后的那只。
- **`data/waves.json`**：内容迁入 `wave_templates.json` 后**删除**；同步清理 `DataRepo` 加载与按 day 读取的旧路径。
- **文档**：同步 `docs/DATA_SCHEMA.md`（新增 `wave_templates.json` schema、移除 `waves.json`）、`docs/UI_SYSTEM.md`（预览 v2 + 横幅）。

## 9. 测试与验证

- 改动 GDScript 跑解析检查：`Godot --headless --check-only --script <file>`。
- 主场景/`CombatSandbox` 验证：
  - 白天横幅在 `day_started` 正常播放、不挡操作、文案完整可读。
  - 右上角预览显示关卡名/文案/每口卡片，敌人立绘正常加载。
  - **一致性**：白天预告的关卡名/敌群 == 当晚实际生成（含 Boss 二选一）。
  - `day6` Boss 终局正常；`night_cleared` → 祝福 → 下一天链路正常。
  - 同一 `run_seed` 跨重开可复现；不同 seed 模板有变化；同局同梯队不重复。
- 模板表加载数量 ≥10（断言 15）。

## 10. 前向接口（#177 / #215）

- **#215（流程长度/模式）**：`day→梯队` 曲线 + `boss_day` 外置即可扩展到 8–10 晚或多模式；模板池按梯队增补。
- **#177（夜中动态）**：模板 schema 预留扩展位（如未来 `dynamic` 段描述夜中出怪口切换）；「白天解析 → 存 RunState → 夜晚消费」这条链是动态机制的注入点。

## 11. 涉及文件清单（预估）

- 新增：`data/wave_templates.json`
- 删除：`data/waves.json`
- 改：`autoload/DataRepo.gd`（移除 waves 加载、新增 templates 加载与查询）
- 改：`scripts/enemy/wave_manager.gd`（梯队曲线、解析、按模板跑波/出预览；移除 day 兜底）
- 改：`scripts/core/night_manager.gd`（读 RunState 模板）
- 改：`scripts/core/game_controller.gd`（enter_day 解析 + 写 RunState）
- 改：RunState（新增 `night_template_id` / `used_template_ids`，`autoload/` 下，以 `project.godot` 为准）
- 改：`scenes/ui/combat/CombatHud.tscn`（预览 v2 节点 + `LevelIntroBanner`）
- 改：`scripts/ui/combat/combat_hud.gd`（`set_wave_preview_data`、横幅播放、enemy 立绘助手）
- 改：`scripts/ui/combat/combat_hud_controller.gd`（结构化预览数据、横幅触发）
- 改：`docs/DATA_SCHEMA.md`、`docs/UI_SYSTEM.md`
