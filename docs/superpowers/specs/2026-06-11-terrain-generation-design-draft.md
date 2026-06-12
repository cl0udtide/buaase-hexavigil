> 状态：**草稿**（多代理设计工作流合成产物，2026-06-11，待用户评审拍板后转正式 spec）
> 来源：3 路调研 → 3 案竞争（noise-first / structure-first / evolve-current）→ 3 镜头评审 → 合成
> 前置已拍板约束：高台为专门地形（山/水回归纯美术差异阻挡）；5 口等弧 + 活跃集（方案 A）；无 LoS

# HexaVigil 地图生成终案设计书
## ——「骨架定结构・牌组出性格・走廊作验收」合成方案

> **合成原则**：三份镜头评审（玩家体验 / 工程 / 肉鸽系统）一致裁定 structure-first（骨架先行派）为优胜骨架（3 个第一名，总分 140 > 133 > 130）。本终案以其「Archetype × 扇区牌 → 骨架 → 长肉 → 修复」管线为主体，做三处结构性手术消解其全部致命缺陷（验收对象从作者车道换成 corridor 走廊集、隘口唯一性改为分级验收、轮辐同质化做五项缓解），并嫁接 noise-first 的经济地理 / 鞍部开凿 / 入侵度断言 / 分位数回调，与 evolve-current 的 mesa 反漂移闭环 / 预算台账 / RNG 流隔离 / 末路兜底 / 灰度合入序。全部代码事实已对照仓库复核（`map_generator.gd` 592 行、`cell_data.gd:5-7,22-23`、`unit_manager.gd:64,131`、`map_root_view.gd:1022,1052-1053`、`_is_protected_cell` 切比雪夫 ≤3 含界、`data/map_generation.json` 现行 19 键 `spawn_count=3`，无一失实）。

---

## 第 0 节 致命缺陷消解清单

评审共提出 13 条致命缺陷（去重后）。逐条说明终案如何消解，或为何对终案不成立。

### 0.1 优胜骨架 structure-first 自带的三条（必须手术）

**SF-1 作者车道 ≠ 敌人实际最短路**（肉鸽镜头）。骨架案的 protected lane 是噪声代价 A* 走出的蜿蜒线，按构造比最短路长；而敌人寻路是四向等代价 A*，会切角偏离作者线。mesa 的 lane_dist≤2、口袋、绕路全对着作者线校验，部分 seed 下射程耦合是对着没人走的路验收。
**消解**：终案把**验收对象整体替换为 corridor 走廊集**（嫁接自 noise-first）：长肉与修复完成后，对每口跑双 BFS 得 `dist_gate[]`、`dist_core[]`，定义 `corridor(g) = { c 可走 : dist_gate(c)+dist_core(c) ≤ 真实最短路长 + slack(3) }`。mesa 射程耦合、口袋位置、隘口相交、绕路带宽全部对 corridor / 真实 BFS 最短路断言。作者车道仅保留两个职责——构造性保证连通、提供自然蜿蜒的保护骨架——**不再作为任何验收对象**。corridor 是格集而非单线，天然抗玩家筑墙后的车道漂移（肉鸽镜头明示的便宜修法，照单全收）。

**SF-2 B4 隘口唯一性硬断言与「放弃封堵」自相矛盾**（工程 + 肉鸽镜头）。原案测试 B4 要求每口最短路必穿本扇区 aperture，但其风险节又允许「封堵顶破绕路 cap 时放弃封堵、接受双隘口」——照写 CI 必然拒掉设计自己宣布合法的图。
**消解**：终案给隘口**分级验收语义**。修复阶段尝试封堵旁路；封堵成功 → 该扇区元数据标 `pass_grade:"single"`；封堵会顶破 detour cap → 放弃封堵，标 `pass_grade:"dual"`。硬断言改为「**元数据与实际一致**」：single 扇区的真实最短路必穿 aperture，dual 扇区必存在 ≥2 条经过不同窗口的走廊。统计断言另控质量：200 seed 扫描中 dual 比例 ≤25%。dual 不是缺陷是牌面——UI 可如实播报「双口分流」，双线分流本身是合法玩法（原案开放问题 1 的「v1 标注不强封」路线，正式定案）。

**SF-3 元拓扑同质化：「核心放射 5 楔 + 每楔一隘口 + 3×4 标准口袋」十局看穿**（玩家 + 肉鸽镜头）。
**消解**（五项叠加 + 一项诚实承认）：
1. **「边界即山」不再恒成立**——山脉只长在抽到险关/峡谷牌的扇区边界上；开阔牌边界整段缺席（≥5 宽缺口），河谷牌的阻挡主体是横穿扇区的河而非放射边界。一张图通常只有 2-3 条边界被实体化；
2. **横穿元素**——河流按伪高程下降走线，天然跨扇区斜穿（见 2.2），打破纯放射格式塔；
3. **口袋去模板化**——protected 只锁 aperture 内侧 2×3 最小核，验收改为形状自由的 flood 判定（隘口内侧 12 格 flood 内 plain 可建格 ≥6），侵蚀与 CA 允许啃口袋边缘——矩形痕迹消失；
4. **中点位移 + 宽度调制 + 边缘侵蚀**三重变形（见 2.1），骨架线永不被直接渲染；
5. **湿度梯度**（嫁接 noise-first）：每局掷一个迎风方向，湿侧扇区湖/河概率上调、干侧下调——同 archetype 同牌组的两局气候面貌也不同。
诚实承认：长线（30 局 +）新鲜感天花板仍靠**加牌**抬升（v1.1 湖泽牌、后续遗物改写牌权重的肉鸽钩子已在 schema 留位）。这是可扩展的天花板问题，不是地基问题——玩家镜头原文背书。

### 0.2 noise-first 的六条（终案为何不继承）

**NF-1 kill-box 一招鲜 + core_basin 反向资敌**：终案**不采纳 core_basin 盆地塑形**——核心 ≤3 环畅通由 protected 集按构造保证即可，不需要把内圈刻成预制杀戮场。对「筑墙漏斗一招鲜」终案的回答是 structure-first 的**定价方案**：开阔牌 = 资源 ×1.5 但无天然隘口，筑墙 kill-box 只在被明码标价的扇区划算；其余扇区前压守牌面隘口省兵省墙，且经济建筑暴露车道会被顺路拆（现成机制）构成龟缩代价。
**NF-2 隘口存在性是统计产物**：对终案不成立——隘口由牌**构造保证**（每张非开阔牌实例化 aperture 锚点，长肉绕窗留口），不靠涌现。
**NF-3 高台供给自行降级为软约束**：终案保持**硬约束**：候选枯竭先降阶（座数下限降至 4，含起手台），仍不满足 → 整图重试。14 名远程的首晚可部署性是生死线，不可警告了事。
**NF-4 起手台「3~4 环」spec bug**：已抽查代码坐实（`_is_protected_cell` 为切比雪夫 ≤3 **含界**，3 环在保护区内，阻挡地形 mesa 进不去）。终案采用 evolve-current 的修正：**起手台取 4-5 环**（day1 成本仍为 0-1 次探索 = 0-2AP，开局 5×5 即切比雪夫 ≤2，4 环一次探索可达）。
**NF-5 与封口/活跃集系统零咬合**：终案继承 structure-first 的全套咬合（day1 活跃口发牌约束、`bias_cards_by_activation` 旋钮、sectors 元数据回传），此缺陷不进终案。
**NF-6 archetype 是统计配方不是性格**：终案是 archetype × 扇区牌双层结构，性格由牌的范畴差异（守口/筑墙/卡渡口）构造保证，不成立。

### 0.3 evolve-current 的四条（终案为何不继承）

**EC-1 环核山带同心圆签名 + 「守环」新一招鲜**：终案**否决环核山带**。它要提供的「隘口不对称」在终案由牌面参数承担（pass_width 2/3/5、pass_ring 6-10 抖动、mesa 配额有无），无需同心圆签名结构。
**EC-2 经济地理零增量**：终案嫁接 noise-first 的资源风味亲和（wood→湿地平原 / stone→山麓 / mana→临水）+ `risk_reward_bias`（贴阻挡、隘口外侧的资源格加权）+ 开阔牌 ×1.5 倍率，三件套补齐这根柱子。
**EC-3 外层棱线「引流」是纸面深度**：终案不采纳「引流」叙事。外层空间的策略意义由牌语义承担：开阔牌外层 = 富资源高风险采集区，河谷牌外层 = 渡口对岸资源，全部是有真实决策的地理而非布景。
**EC-4 自然感天花板坍塌返工风险**：终案的 walker 只降级为「沿骨架折线长肉」的工具（调研 C 认定的最佳归宿），且有 T10 形状质量门量化验收 + 侵蚀/CA 兜底；同时终案诚实接受「拓扑可读性优先于等高线连贯」的定位——30×30 上玩家读的是哪里能走哪里卡口。逃生舱保留：若 200 seed 抽看仍不满意，长肉锚线改由整数哈希值场驱动（~50 行，决定性无损），管线结构不动。

---

## 第 1 节 管线分阶段

### 1.0 总控（入口契约不变）

```gdscript
static func generate(width, height, seed, cfg, event_ids) -> Dictionary:
    # 返回 { cells, core_cell, spawn_cells, event_points,
    #        sectors,            # 新增：扇区元数据（牌面/aperture/pass_grade/corridor 摘要）
    #        debug }             # 新增：gen_report（attempt 数、各 pass 台账、失败约束）
    for attempt in range(cfg.max_retries):          # 默认 5
        var ctx := _build_context(width, height, seed, attempt, cfg)
        if _generate_once(ctx): return _to_result(ctx)
    return _conservative_fallback(...)              # 见第 5 节，构造性必成
```

`map_manager.gd:26` 是唯一调用方，只读 cells/core_cell/spawn_cells/event_points 四键——新增键向后兼容，零改动。`ctx` 为 Dictionary（cells/core/spawns/sectors/lanes/corridors/protected/budget_ledger/rng 流表），替代多参数签名传染；所有 pass 仍是纯静态函数。

每 pass 独立 RNG 子流（evolve-current 任务 0，整段采纳）：

```gdscript
rng[stage].seed = splitmix64(splitmix64(run_seed, attempt), STAGE_ID)
```

调 mesa 参数不重洗骨架的牌；T-A3 流隔离断言是这条纪律的硬证据。

### 1.1 十个 Stage

```
S0  种子派生 + ctx 构建（splitmix64 链，见第 5 节）

S1  Archetype 抽取 + 发牌
    archetype := weighted_draw(rng[S1], cfg.archetypes)
    cards[5]  := 从 archetype 牌组抽 5 张发给 5 个扇区
    发牌约束：day1 活跃口（S1,S2）所在扇区至少 1 张非「开阔」（no_double_steppe）
    可选旋钮 bias_cards_by_activation：险关偏发早/晚活跃口（逐夜难度曲线）
    掷迎风方向 wind_dir（湿度梯度，影响各扇区湖/河概率修正）

S2  骨架构建（纯抽象，不碰地形）
    gates[5]   := 周长 116 格等弧（弧距 ~23）+ 相位抽取 + 每口 ±2 滑移
                  约束：距四角 ≥3、曼哈顿(口,核心) ≥12、互距 ≥10（等弧自动满足）
    sectors[5] := 以核心为原点按相邻口角平分线切楔（整数叉积判归属，零浮点）
    confluence := 拓扑实例化（五指=无 / 双钳=2 汇流点 / 三叉=3，置于距核心 5-7 环）
    每扇区按牌实例化：pass_anchor（距核心 r ∈ 牌.pass_ring）、pass_width、
                      mesa_quota、river_plan、lake_plan

S3  车道走线 + protected 集
    cost(x,y) := 1 + int_value_noise(x,y, rng[S3]) * 牌.jitter_amp     # 噪声抖动代价场
    lane[i]   := A*(gate[i] → [confluence] → pass_anchor → core)
    走线自检：1.15 ≤ len/manhattan ≤ 1.6，过直升 jitter、过弯降 jitter 重走（≤3 次）
    protected := lane 格 ∪ 核心 cheb≤3 ∪ 口 apron(cheb≤2) ∪ aperture(宽 w×纵深 2)
                 ∪ 口袋最小核(aperture 内侧 2×3)

S4  骨架长肉（地貌实体化，预算台账驱动，详见第 2 节）
    台账初始化：target = 900 × ratio∈archetype.ratio_band，按牌密度系数分配各扇区额度
    险关/峡谷牌：扇区边界中点位移折线 + ridge walker 长山（隘口窗跳过）
    河谷牌：伪高程下降走河 + 渡口预规划（与车道交点恰留 1 个渡口）
    开阔牌：远侧 1-2 个 blob 湖（复用现 _build_lake_cluster），边界不长山
    每批落地走现有 _try_apply_obstacle_cells 连通回滚；台账记 申请/落地/回滚 三数

S5  自然化修饰（在修复之前，永不触碰 protected）
    边缘侵蚀：地貌边界格按整数哈希 ~30% 概率啃掉或外溢 1 格
    CA 1-2 轮 4 邻多数规则：清单格渣、删 <3 格阻挡孤岛、填 <4 格不可达死口袋

S6  corridor 派生 + 约束修复（详见第 3 节）
    每口双 BFS → 真实最短路 + corridor 集（slack=3）
    ① 连通断言（构造已保证，鞍部软代价 A* 开凿兜底）
    ② 绕路上限：双 BFS 最优破墙，并列取伪高程最低（鞍部破墙）
    > 2026-06-11 修订（B1/B2 落地）：①开凿语义为**字典序**（步数主序，水 6/山 12
    > 权重次序，见 `_soft_cost_path` 头注），加性软代价与 saddle_weight 弃用；
    > ②破墙并列裁决为 (y,x) 全序，伪高程不参与。
    ③ 绕路下限：直线段旁插山脊 spur
    ④ 隘口分级：single 扇区旁路封堵（封堵格沿最近山体生长）；顶破 cap → 标 dual
    ⑤ 口袋 flood 复检：不足则自隘口内侧按伪高程升序清障至 ≥6 可建 plain
    ⑥ 占比回调：欠收 → 距 corridor ≥3 的非开阔扇区格按伪高程分位数序补切；
                超收 → 同序啃地貌边缘
    每项 ≤3 轮，改一格记一笔入侵度台账

S7  mesa 高台放置（评分制 + 逐座反漂移闭环，详见 2.4）
    第 1 座：起手保底台（核心 cheb 4-5 环、距 corridor ≤2、2 格）
    第 2..N 座：全图按评分降序；每座落地 → 当场重跑双 BFS 重派生 corridor
                → 复检连通/绕路/射程耦合 → 失败回滚本座取下一候选

S8  资源与事件点
    近环保底：cheb 3-5 环每类 2 个（现 _is_near_exploration_ring 逻辑原样保留）
    远区：扇区倍率（开阔 ×1.5）× 风味亲和（wood→湿原/stone→山麓/mana→临水）
          × risk_reward_bias（贴阻挡/隘口外侧加权）；排除 corridor 格
    事件点逻辑原样（event_point_count 现为 0）

S9  终验 + 有界重试
    第 6 节全部硬断言；失败 → attempt+1 回 S0；5 次耗尽 → 保守兜底（第 5 节）
```

性能预算：900 格上噪声采样、2 轮 CA、~6 次 A*、~15 次 BFS，单图 <50ms，重试 ×5 无感（换日加载预算内）。

---

## 第 2 节 地貌实现

### 2.1 山脉 = 被抽中边界的实体化（非恒定）

只有险关/峡谷牌的扇区边界长山，三步走：
1. **中点位移折线**：边界射线取 r=7、r=11 两控制点，各垂直位移 ∈[-3,+3] 格——walker 看到的指导线已经不直；
2. **ridge walker 长肉**：现有 `_build_mountain_cluster`（蛇形 walker）改造为沿折线锚点推进，宽度由整数哈希脊噪声分位数调制——高段宽 3、低段宽 1 甚至断 1-2 格小豁口（不可通行性不靠山体完整，靠 S6④ 的封堵/分级保证）；同时吸收 evolve-current 的纺锤剖面（中段 0.65 / 两端 0.2 的侧向增长概率），山体有腹有尾；
3. **隘口窗跳过**：折线穿过 aperture 保护区时 walker 跳过，断口两壁因宽度调制天然不对称。

预算核算：2-3 条实体化边界 × 长 12-18 × 均宽 1.5-2.5 ≈ 60-130 格，加河/湖/mesa/侵蚀外溢落在 ratio band 内，缺口由 S6⑥ 台账回调补齐。

### 2.2 河流 = 河谷牌的隘口载体（渡口是设计不是补丁）

伪高程场 `elev(x,y) = 4 × dist_to_最近山体(取反) + int_value_noise(x,y)`（离山脊越近越高），从扇区外缘最高非保护格**梯度下降**走到地图边缘，卡坑就地成 3-5 格小湖收尾（平局固定方向序；不实现 priority-flood，30×30 不值得——调研 C 结论）。河宽 1 格、纯 water。
**渡口预规划**（采纳 evolve-current）：落水前先预演河道折线，求与该口当前 BFS 最短路的交点，**每条车道恰保留 1 个 2 格渡口窗**（多交点只留一个，其余照常落水，强制车道走渡口）。渡口 = 全图最锐利的天然 choke：两侧是水，近战堵口效率最高、mesa 评分最高。v1 渡口为普通 plain；`is_ford` 渲染标记 + 浅滩贴图列 v1.5（noise-first 风险节的性价比补丁）。

### 2.3 湖与湿度梯度

开阔/河谷牌在车道远侧放 blob 湖（复用 `_build_lake_cluster`，15-30 格、更大更少更可读）。每局掷迎风方向：湿侧扇区 lake/river 计划概率 +0.2、干侧 −0.2——一行参数换来同牌组局间的气候不对称（嫁接 noise-first）。高台已接走「可部署高地」职责，**山和水放心做大块**——这正是用户拍板高台专门地形换来的设计自由。

### 2.4 天然高台：平台阵地 + 评分放置 + 反漂移闭环（2026-06-11 评审修订）

数值依据（调研 B 已核验，主会话复验）：sniper pattern 4×3 矩形（前向 3）、caster 同型缺角；**高台格到最近车道格切比雪夫 ≤2 时 14 名远程全员满覆盖，=3 术师近废，≥4 全废**；敌方最大射程同为 3（弩手 day1 即出场），高台无射程外安全位、对射对等。

> 修订记录：初稿"零星哨台"参数（5-8 座 × 1-3 格、禁 2×2、全图均匀散布座间距 ≥5）经用户评审**否决**——目标体验是明日方舟式"盾在隘口、狙术在侧后平台成建制齐射"的复合阵地。白嫖与决策塌缩两个平衡恐惧改由别处承接：白嫖交给敌方远程/飞行混编与部署上限（方舟同款解法），塌缩交给出怪口系统（每波主攻重抽 + 活跃集扩张本来就强制多阵地）。

| 规则 | 取值 | 理由 |
|---|---|---|
| 单座尺寸 | **3-6 格**，允许 1×3 / 1×4 / 2×3 / L / T（单座上限 6） | 一座平台站 2-4 名远程，成建制齐射是方舟手感的核心 |
| 全图供给 | **4-6 座、合计 14-24 格**（硬约束） | 平台少而精，每座都是"设计好的阵地" |
| 放置逻辑 | **战位锚定**：险关/河谷/峡谷牌各 1 座紧贴 aperture/渡口/走廊侧后；取消全图最小间距与均匀散布 | 看到平台=看到阵地，地图阅读即战术阅读 |
| 射程耦合 | 每座 ≥60% 的格距 **corridor 格集** cheb ≤2（硬），全格 ≤3 | 满覆盖线；corridor 抗筑墙漂移 |
| 起手保底 | 1 座 **3-4 格**，核心 cheb 4-5 环、距 corridor ≤2 | 开局站得下 2-3 名远程；4 环一次探索可达 |
| 开阔牌配额 | 0（**不补哨台**） | 缺口由人工高台建筑（§2.6）承接："富但难守"→"赚的钱就地变防线"，经济闭环 |

评分函数（沿用 evolve-current）：`score = 3×(cheb≤2 内 corridor 格数) + 6×贴隘口/渡口 + 3×贴汇流点`，按 (score, y, x) 全序降序取（原"扇区饥饿/间距违例"两项随均匀散布一并移除）。
**反漂移闭环**原样保留：每座落地（terrain=highland，走 `_try_apply_obstacle_cells` 连通校验）→ 当场重跑双 BFS 重派生 corridor → 复检绕路与已放各座的射程耦合 → 任一失败回滚本座取下一候选。候选枯竭 → 座数下限降到 3（含起手台）→ 仍不满足 → 整图重试（硬约束不软化）。

### 2.5 长肉为什么不显得人工（五重保险）

① 骨架先自变形（中点位移）；② 宽度噪声调制 + 豁口；③ 车道是噪声代价场上 A* 自己找出来的蜿蜒（调研 C 认定的最高杠杆单点）；④ 边缘侵蚀 + CA 磨掉直线像素感；⑤ 修复产物伪装成地貌（鞍部开凿出垭口、封堵格沿山体合龙、口袋清成山坳）。最终画面里**没有任何一条骨架线被直接渲染**。

### 2.6 人工高台建筑（玩家侧付费炮位，2026-06-11 用户提案定稿）

与天然高台共存的建筑版高台，补齐三角：**天然高台=免费/固定/不可摧毁，人工高台=花钱/任意/可被拆，墙=便宜路障对照**。它彻底锁死"远程仅高台可部署"的严格门控——程序生成的公平性缺口由玩家付费自补。

机制（引擎账本已对代码验证）：
- **复用木墙逻辑**：`blocks_path: true` → 普通怪绕行、拆迁怪攻击路径上的建筑（`enemy_attack_controller._should_attack_path_building` 对 demolisher 全建筑返回 true，零代码）；建筑身份保证"核心被围→拆墙回退"链路完整，无地形围核死局；
- **复合格状态**：CellData 的 building_runtime_id 与 unit_runtime_id 本就是独立字段；敌方远程索敌同格**先查干员后查建筑**——狙击手挨弩箭、台子挨拆迁锤，分工天然成立；光环/医疗按半径自动生效；
- **要新写的三处**：① 部署校验放行"sniper/caser 上活着的人工高台"（unit_manager 部署校验加分支）；② **塌台死人钩子**：建筑摧毁时查同格 unit_runtime_id，有人则走 `UNIT_REMOVE_DEAD`（= 再部署冷却 + unit_died 事件，与战斗阵亡同语义，非永久减员）；③ buildings.json 条目 + 部署高亮把平台格计入远程合法格。"在已站人格子上盖台"已被 is_buildable 天然禁止；
- **数值占位**：2 木 + 2 石 + 2 AP，500 HP（墙 1 木 1 AP 700 HP）。比墙贵保住墙的路障性价比；比墙脆保证拆迁怪的真实威胁，制造"撤人 / 抢杀 / 弃台"临场三选。白天可修理（走既有建筑维修）；place_rule plain_only（天然高台上不可建）；仅远程可上。

连锁效应：拆迁怪从"反墙工具"升格为"平台查杀者"，带拆迁怪的夜变成护台之夜；开阔牌扇区 ×1.5 资源 + 无天然防御 + 人工高台 = 经济地理闭环。

---

## 第 3 节 约束与修复

哲学：**能构造保证的不靠修复；必须修复的把补丁打成地貌；修复量可观测可断言。**

| 硬约束 | 保证方式 | 违反时修复 | 修复如何「像设计的」 |
|---|---|---|---|
| 全 5 口连通核心 | **构造保证**：lane 格全程 protected plain | 鞍部软代价 A* 开凿（plain 1/water 6/mountain 12/highland 禁穿 + saddle_weight×伪高程）兜底。**2026-06-11 修订：实现为字典序（步数主序 + 水 6/山 12 权重次序，B1 落地）；plain 成本与 saddle_weight 不再使用、不入 json** | 凿口自动落在山墙最薄最低处=垭口；凿水变渡口 |
| 绕路上限（真实 BFS 路长/曼哈顿 ≤1.6） | S3 走线自检 | 双 BFS 最优破墙：`min(邻dist_gate)+1+min(邻dist_core)` 取最小，并列取伪高程最低，1-3 轮收敛 | 破在最薄处，读作又一个山口 |
| 绕路下限（≥1.15） | S3 自检 | 直线段旁插 6-10 格纺锤 spur | 山脉天然支脉 |
| 隘口分级一致性 | 牌构造 aperture | single 扇区旁路封堵（沿最近山体生长合龙）；顶破 cap → 改标 dual，元数据如实 | 封堵=山脉合龙；dual=双口分流牌面 |
| 核心保护区 cheb≤3 / 口 apron cheb≤2 / 口格 plain | protected，构造保证 | 断言兜底 | — |
| 隘口口袋（内侧 flood≤12 内 plain 可建 ≥6） | 2×3 最小核 protected | 自隘口内侧按伪高程升序清障至达标 | 凿出山坳盆地 |
| 高台供给（4-6 座/14-24 格/corridor≤2/起手 3-4 格在 4-5 环） | S7 战位锚定放置 + 逐座复检 | 滑移重贴 → 降阶到 3 座 → 整图重试 | 平台锚定隘口侧翼，位置自带叙事 |
| 近环资源保底（3-5 环各 2） | 现行 near_ring 逻辑原样（豁免保护判定） | 候选不足 → 近环中距 corridor 最远的阻挡格按分位数序还原平原 | 等同侵蚀地貌边缘 |
| 阻挡占比 ∈ archetype.ratio_band | 预算台账按牌密度系数分配 | 欠收补切（距 corridor ≥3、只投非开阔扇区）/ 超收啃边，均按伪高程分位数序 | 贴已有地貌长肉/削边 |
| **入侵度上限**（自然感代理，嫁接 noise-first） | — | 断言：S6 全部修复改写格 ≤ 阻挡总数 15%（单图）/ 10%（200 seed 均值） | 修复是微创不是重画 |

每类修复 ≤3 轮，耗尽 → 整图重试。修复从不递归打补丁。

---

## 第 4 节 Archetype 与扇区牌

### 4.1 双层变化结构

局间变化 = archetype（全局性格）× 扇区牌（局部性格）× 牌内参数抽取（pass_ring/宽度/河走向）× 湿度梯度方向。变化不靠噪声碰运气，靠**牌组组合爆炸**；同 archetype 两局也长得不同。

### 4.2 v1 牌组（四张，湖泽延后）

| 牌 | 隘口形态 | 密度系数 | mesa 配额 | 特征 | 玩家读到的语义 |
|---|---|---|---|---|---|
| **险关 bastion** | aperture 宽 2，r∈6-8 | 1.3 | 1（俯瞰 aperture） | 厚脊双翼 + 口袋 | 「这路口最好守，省兵力」 |
| **开阔 steppe** | 无显式隘口（边界 ≥5 宽缺口） | 0.6 | 0 | 散丘 + 远端湖，资源 ×1.5 | 「富但难守，用木墙自建防线」（blocks_path 现成机制） |
| **河谷 riverlands** | 渡口 2 格 | 0.9 | 1（渡口内侧） | 河沿山根斜穿 | 「卡渡口，一夫当关」 |
| **峡谷 canyon** | 双平行脊夹宽 3 走廊 | 1.2 | 1（走廊中段壁龛） | 长直纵深 | 「狙击走廊，列阵打靶」 |

湖泽牌（两湖夹地峡）列 v1.1——采纳 structure-first 自己的砍牌建议（保峡谷：与高台系统协同最强）。

### 4.3 Archetype 表（v1 三个）

| Archetype | 牌组 | 汇流拓扑 | 占比带 | 一句话性格 |
|---|---|---|---|---|
| 山地局 highland_run | 险关×2 峡谷×2 开阔×1 | 五指 | 0.24-0.28 | 处处雄关，兵力拆五路 |
| 河谷局 riverine_run | 河谷×3 开阔×1 险关×1 | 双钳 | 0.20-0.24 | 卡两个渡口吃天下 |
| 开阔局 open_run | 开阔×3 险关×1 河谷×1 | 三叉 | 0.20-0.22 | 经济膨胀，筑墙造关 |

`archetypes[].weight` 后续可被遗物/事件改写（「下一局必为河谷局」类肉鸽钩子，只动 JSON）。

### 4.4 data/map_generation.json 扩展 schema

现行 19 键保留为兜底默认（`spawn_count` 3→5，`spawn_safe_radius` 1→2；`obstacle_ratio`/`water_obstacle_chance`/`scattered_obstacle_ratio` 等旧算法键保留供兜底生成器使用）。新增（全部数值为占位符，项目未做平衡盘，可自由取整；`DataRepo.gd:127` 透传 dict 零改动）：

```jsonc
{
  "spawn_count": 5, "spawn_safe_radius": 2,
  "generator": "skeleton_v2",            // 切回 "legacy" 即旧 walker（兜底/灰度开关）
  "max_retries": 8, // 2026-06-11 调参：5→8（占位值自由取整；floor 修复成功率主导兜底率，详见 B2-11 实施报告）
  "max_repair_rounds": 3,
  "detour_cap": 1.6, "detour_floor": 1.15,
  "lane_jitter_base": 0.35, "corridor_slack": 3, "gate_slide_jitter": 2,
  "repair": {
    // 2026-06-11 修订：开凿语义实现为字典序（步数主序 + 水/山权重次序，B1 落地），
    // plain 成本与 saddle_weight 在该语义下无意义、不入 json。
    "carve_costs": { "water": 6, "mountain": 12 },
    "intrusion_max_per_map": 0.15, "intrusion_max_mean": 0.10,
    "dual_pass_ratio_cap": 0.25
  },
  "pass": { "aperture_depth": 2, "pocket_core_w": 3, "pocket_core_h": 2,
            "pocket_min_plain": 6, "pocket_flood_limit": 12 },
  "mesa": {
    "count_min": 4, "count_max": 6, "count_floor_degraded": 3,
    "cells_min": 14, "cells_max": 24,
    "size_weights": { "3": 0.30, "4": 0.35, "5": 0.20, "6": 0.15 },
    "max_corridor_dist": 2, "min_covered_ratio": 0.6,
    "starter": { "ring_min": 4, "ring_max": 5, "size_min": 3, "size_max": 4, "max_corridor_dist": 2 }
  },
  "economy": {
    "resource_affinity": { "wood": "moist_plain", "stone": "foothill", "mana": "water_adjacent" },
    "risk_reward_bias": 0.5
  },
  "moisture_gradient_strength": 0.2,
  "sector_cards": {
    "bastion":    { "pass_width": 2, "pass_ring": [6, 8],  "density": 1.3, "mesa_quota": 1, "jitter_amp": 0.5,  "resource_mult": 1.0 },
    "steppe":     { "pass_width": 5, "pass_ring": [7, 10], "density": 0.6, "mesa_quota": 0, "jitter_amp": 0.3,  "resource_mult": 1.5, "lake": [1, 2] },
    "riverlands": { "pass_width": 2, "pass_ring": [6, 9],  "density": 0.9, "mesa_quota": 1, "jitter_amp": 0.4,  "resource_mult": 1.1, "river": true, "ford_width": 2 },
    "canyon":     { "pass_width": 3, "pass_ring": [6, 10], "density": 1.2, "mesa_quota": 1, "jitter_amp": 0.35, "resource_mult": 0.9, "corridor_len": [6, 9] }
  },
  "archetypes": [
    { "id": "highland_run", "weight": 1.0, "deck": { "bastion": 2, "canyon": 2, "steppe": 1 },
      "confluence": "five_fingers", "ratio_band": [0.24, 0.28] },
    { "id": "riverine_run", "weight": 1.0, "deck": { "riverlands": 3, "steppe": 1, "bastion": 1 },
      "confluence": "twin_pincers", "ratio_band": [0.20, 0.24] },
    { "id": "open_run", "weight": 1.0, "deck": { "steppe": 3, "bastion": 1, "riverlands": 1 },
      "confluence": "trident", "ratio_band": [0.20, 0.22] }
  ],
  "day1_card_constraint": "no_double_steppe",
  "bias_cards_by_activation": false
}
```

---

## 第 5 节 决定性与重试

- **种子链**：`run_seed → splitmix64(seed, attempt) → splitmix64(s, STAGE_ID) → 每 stage 独立 RandomNumberGenerator（PCG32）`。同 seed 同图；attempt 派生而非随机，整条链决定性。
- **噪声**：**整数哈希值噪声**（squirrel3 式 `hash(x,y,seed)` + 定点双线性插值 + 2 octave，~50 行 GDScript），不用 FastNoiseLite——跨平台逐位一致，「贴阈值格子翻面」问题**结构性不存在**（structure-first 与 evolve-current 共识，工程镜头背书）。
- **平局裁决**：A* open list、分位数序、梯度下降、评分排序全部用 `(值, y, x)` 全序；候选集行优先扫描构建（Godot 4 Dictionary 保插入序）。
- **有界重试**：stage 内局部重抽（走线 ≤3、修复 ≤3 轮、mesa 逐座回滚）→ 整图重试 ≤5 次（attempt 4 强制保守剖面：open_run、ratio 0.20、jitter=0、无河、mesa 4 座）→ **末路兜底**：对每个不连通口沿曼哈顿走廊直线清障到核心（构造性保证连通），`push_error` 报警但**任何路径都不返回非法地图、不死循环**（采纳 evolve-current 的完整语义）。因连通由 protected 车道按构造保证，整图重试预期触发率 <1%（工程镜头认定三案中唯一可信的近零承诺）。
  > 2026-06-11 修订（B2 落地）：末路兜底改为**回落 legacy 生成器 + `push_warning`**（legacy 全管线久经十套件回归、同样构造性必成，曼哈顿走廊清障弃用）；整图重试 5→8 次、保守剖面取末两轮（重试主因是绕路下限 1.15 在开阔剖面下 spur 修复不可达，非连通——生产形态实测兜底率 0/40，强制单 archetype 压力扫描 ≤3/40，详见 B2-11 报告）；③ 绕路下限改为修复期尽力、S9 终验硬裁决（与 ②/⑥ 同语义）。
- **失败可观测**：`debug.gen_report` 记 attempt 数、各 pass 台账（申请/落地/回滚）、入侵度、失败约束，供测试与调参读取。

---

## 第 6 节 测试计划

新建 `scripts/debug/test_map_generation.gd`（headless `extends SceneTree`，与现有 7 个 test_*.gd 同构；当前生成器零测试，本次补齐空白）。生成器是纯静态类，无需加载场景。

```
A. 决定性
  A1 同 seed 调 2 次 → 地形网格序列化哈希全等；seed+1 → 哈希不同
  A2 金种子快照：3 个 golden seed 地形哈希入库，改代码必须显式更新
  A3 RNG 流隔离：改 mesa.count_max 不改变 S4 以前的地形哈希（evolve-current 招牌断言）
B. 硬约束（3 archetype × 200 seed 扫描）
  B1 5 口在边缘、口格 plain、互距/离核距满足、等弧分布
  B2 每口 _has_ground_path 达核心
  B3 每口 1.15 ≤ 真实 BFS 路长/曼哈顿 ≤ 1.6        ← 验收对象是真实最短路
  B4 隘口分级一致性：single 扇区最短路必穿 aperture；dual 扇区元数据如实    ← 重定义后自洽
  B5 核心 cheb≤3 全 walkable；口 apron cheb≤2 全 walkable
  B6 每隘口内侧 flood≤12 内 plain 可建 ≥6
  B7 阻挡占比 ∈ archetype.ratio_band（±1%）
  B8 资源：3 类各 12；3-5 环各类 ≥2；全落 walkable 且不在 corridor 格
  B9 高台：4-6 座/14-24 格；每座 ≥60% 格距 corridor cheb≤2；起手台 3-4 格在 4-5 环；
     单座 3-6 格；highland 格 walkable=false 且 buildable=false
  B10 形状质量门（evolve-current T10）：孤立单格阻挡=0；<3 格阻挡组件=0；
      阻挡组件总数 ≤12；最大山体组件 ≥25 格；每条河渡口数=1/车道
  B11 入侵度：单图修复改写 ≤ 阻挡 15%；全 seed 均值 ≤10%（noise-first 自然感代理）
C. 分布统计
  C1 每 archetype/每张牌在 200 seed 内至少出现 1 次；day1 约束 100% 满足
  C2 dual 隘口比例 ≤25%；整图重试率 <5%；平均耗时 <50ms
D. 集成
  D1 经 map_manager.generate_new_map 全链路跑通，PathService rebuild 不炸
  D2 highland 部署校验：sniper/caster 通过、guard/defender 拒绝、敌不可走不可生成
  D3 人工高台：远程可上活台、近战拒绝、塌台时同格干员走 UNIT_REMOVE_DEAD、
     拆迁怪攻击路径上的平台、普通怪绕行、已站人格不可盖台
E. 兜底
  E1 注入必败配置（ratio=0.9）→ 5 attempts 后落保守剖面/曼哈顿走廊，不崩溃不死循环
```

另出 seed 扫描统计报表（占比/绕路/dual 比例/mesa 数/入侵度分布），供调参肉眼核对 + 人工抽看 20 张图校准形状门阈值。

---

## 第 7 节 迁移与任务拆分

**改动幅度**：`map_generator.gd`（592 行）重写为编排层 + 5 个模块：`scripts/map/generation/{skeleton.gd, lanes.gd, flesh.gd, repair.gd, int_noise.gd}`，合计约 900-1000 行；**原样复用约 300 行**（`_place_resources` 全套、`_place_event_points`、`_has_ground_path`、`_are_all_spawns_connected`、`_try_apply_obstacle_cells`、`_build_lake_cluster`、`_is_near_exploration_ring`、`_shuffle_cells`）；逐簇回滚作为主机制退役（占比欠收偏差由台账+回调根治），但保留旧 walker 全管线为 `generator:"legacy"` 兜底开关。

**highland 接入**（调研 A 最小改动集：7 文件 1 贴图 ~10 点），两个强制陷阱排雷：
1. `map_root_view.gd:1022` 与 `:1052-1053` 两处 `terrain == MOUNTAIN or not walkable` 兜底**之前**插 highland 分支（否则高台画成山）；
2. `map_manager.gd` debug 序列化 `get_debug_map_state`/`apply_debug_map_state` 加 `"highland"` 键带缺省 fallback（否则编辑器存取一轮高台蒸发）。
其余：`cell_data.gd` +`TERRAIN_HIGHLAND` 常量、`is_terrain_blocking` 纳入、新增 `allows_ranged_deploy()` 查询；`unit_manager.gd:64/131` 两处重复校验**先抽公共函数再加分支**（远程判定直接用现有 `class ∈ {sniper, caster}`，零 json 改动；拖拽预览 `combat_hud_controller.gd:1406` 自动跟随）；`tile_highland.png` 一张（强对比色阶）。combat_sandbox 高台画笔分期 v1.1，PR 描述显式声明。


**美术资产 TODO**（提示词已补至 `docs/MAP_ASSET_GENERATION_PROMPTS.md` 第 11 节，gpt-image-2 生成）：`tile_highland.png`（高台地形格）、`artificial_platform.png` + `artificial_platform_destroyed` 沿用通用残骸（人工高台建筑 sprite）、`tile_ford.png`（渡口浅滩，v1.5 可选）。**实装前占位方案**：tile_highland 复制 tile_mountain 调色（代码侧 modulate 暖黄）或纯色块；人工高台暂用 inspiring_monolith 贴图 + icon_text"台"。

**TDD 任务列表（红→绿，逐 PR 可合，主干始终可发布）**：

| # | 任务 | 测试先行 | 量级 |
|---|---|---|---|
| 0 | ctx 重构 + 每 pass RNG 流（行为不变，旧管线保绿） | A1/A3 | 0.5d |
| 1 | highland 最小集（cell_data/unit_manager/map_root_view 两陷阱/debug schema/贴图） | D2 + 单测 | 1d |
| 2 | int_noise.gd + splitmix64 链 | A1-A2 | 0.5d |
| 3 | 双 BFS 破墙 + 绕路修复（**先于新地貌，老地图直接受益**） | B3 | 0.5d |
| 4 | skeleton.gd：五口等弧 + 扇区 + 发牌 + 汇流 | B1/C1 | 1d |
| 5 | lanes.gd：噪声代价 A* + protected 集 | B2/B5 | 1d |
| 6 | flesh.gd：山脉（折线 + walker 改造 + 纺锤） + 台账 | B7 + 金种子目测 | 1d |
| 7 | flesh.gd：河流下降 + 渡口预规划 + 湖 + 湿度梯度 | B10 渡口项 | 1d |
| 8 | 侵蚀 + CA 清渣 | B10 | 0.5d |
| 9 | repair.gd：corridor 派生 + 鞍部开凿 + 隘口分级封堵 + 口袋 + 回调 + 入侵度台账 | B4/B6/B11 | 1.5d |
| 10 | mesa 评分放置 + 逐座重派生复检闭环 | B9 | 1d |
| 11 | 资源风味 + 扇区倍率 + risk_reward_bias | B8 | 0.5d |
| 12 | 重试 + 保守兜底 + 曼哈顿走廊 + gen_report | E1 | 0.5d |
| 13 | 3×200 seed 扫描调参 + 报表 + 人工抽看 | C1/C2 + D1 | 1d |
| 14 | 人工高台建筑（buildings.json + 部署放行 + 塌台死人钩子 + 高亮） | D3 | 1d |

合计约 12.5 人日。里程碑：任务 0-2 是独立 highland/基建 PR；3 单独合（纯修复，玩家无感收益）；4-5 合「骨架+车道」PR（落地即可玩，只是地貌丑）；6-8 地貌 PR；9-13 收尾 PR。灰度序采纳 evolve-current：修复 → 观感 → 玩法。任务 0-3 不依赖 highland，可与 1 并行。

---

## 第 8 节 典型地图走查（河谷局，双钳拓扑，某 seed）

**开局**：核心 (15,15) 亮起 5×5。正北偏东 4 格处一座 2 格灰白高台贴着开阔地——起手保底 mesa（4 环、距北侧 corridor 1 格），开局已点亮一半，day1 花 2AP 探一步即全亮。近环三个保底资源点提示采集方向。状态栏：今晚 S1（东北）、S2（东）两口活跃；昨夜发牌约束保证这两口至少一张非开阔牌。

**第 1 天向北探 2 次（4AP）**：揭开一条河，自东北山根斜穿扇区流向西边——河谷牌翻开。河上唯一一处 2 格浅滩渡口恰卡在车道上（渡口预规划的产物），渡口内侧一片形状不规则的平地 flood 区（口袋判定达标但无矩形痕迹）。你立刻读懂：北线 = 渡口局，近战 1 人锁渡口，起手台狙击在后白嫖。夜幕横幅播报「今晚主攻：东北河谷渡口」——sectors 元数据接通夜晚系统的信息链。

**第 2-3 天向东南探**：完全另一个性格——稀疏小丘、一面 20 格大湖、资源点密得发亮（开阔牌 ×1.5，其中两个魔矿贴在湖对岸隘口外侧——risk_reward_bias 的「要钱还是要命」）。没有天然隘口，day3 这个口激活前你开始攒木头：这里的防线得自己用墙拼，而这正是全图唯一筑墙划算的扇区。

**中盘读图**：西侧两条车道在距核心 6 格处汇成一股（双钳另一只钳），汇流点外侧连绵山体把两口怪流逼进同一山口——但本局这个扇区元数据标着 `pass_grade:"dual"`：封堵旁路会顶破绕路上限，生成器如实放弃，山口旁还留着一条 2 格窄的绕行廊。一处投资守两口，但要留一个机动位看住侧廊——dual 不是 bug，是这局的牌。山口左肩一座 3 格 L 形 mesa 俯瞰主窗（险关牌配额）。

**整图观感**：阻挡 22.6%。山脉连绵有粗有细带豁口，河贴山根斜穿两个扇区，湖压出 S 弯车道；没有散点群岛、没有同心圆、没有矩形口袋。五张牌随揭雾逐扇区翻开——探索本身成了读牌。

---

## 第 9 节 风险与开放问题

**风险（按严重度）**
1. **dual 隘口比例失控**：封堵与绕路 cap 的拉扯若使 dual >25%，「隘口质量差异」会被稀释。缓解：C2 统计断言盯比例；超标优先调 pass_ring 内移（封堵空间更大）而非放宽 cap。开放：dual 扇区是否给资源补偿（dual = 难守，可学开阔牌微调倍率）。
2. **长线元拓扑疲劳**（SF-3 的残余）：五项缓解后仍是轮辐底盘。缓解路线已定：v1.1 湖泽牌、遗物改写牌权重、必要时引入「偏心核心扇区切分」（核心固定但角平分线加大抖动）。承认这是天花板不是地基。
3. **walker 自然感天花板**：到不了噪声场等高线级。T10 形状门 + 200 seed 抽看 20 张验收；逃生舱是长肉锚线改由整数哈希场驱动（~50 行，决定性无损，管线不动）。
4. **5 口 + 20-28% 阻挡 + 5 条保护车道挤压建造面积**：平原约 650-720 格，扣车道/口袋/资源后建造自由度需实测；第一调节阀是口袋最小核与车道缓冲。
5. **玩家筑墙后的动态漂移**：corridor 格集已显著抗漂移，但无法全保；「主攻口→扇区」播报在玩家大改后可能失真。开放：播报是否动态重算（UI 范畴，生成器侧 corridor 数据现成）。
6. **debug 沙盒画笔延期**：任务 1 已含序列化键，仅画笔缺席 v1——编辑器画不出高台但不丢数据，PR 描述显式声明。
7. **数值全是占位符**：密度系数/资源倍率/形状门阈值未盘（项目共识可自由取整）。先锁结构，跑 200 seed 报表再调数。

**开放问题（需设计拍板）**
1. 发牌是否对玩家开局公开（开图读盘爽感）vs 探索翻牌（本案第 8 节体验）——元数据已备齐，纯 UI 决策；倾向探索翻牌（肉鸽镜头建议）。
2. 起手 mesa 是否感知 day1 活跃口朝向偏置——需夜晚活跃序前置到生成期，跨系统时序改动，v2。
3. 贴车道资源的「风险标签」UI 提示——经济地理深度的便宜增量，UI/数值范畴。
4. 高台格花 AP 探索的合法性（现行 `try_explore` 不查地形）：建议允许（侦察价值），确认不与「探索=建造许可」教学话术冲突。
5. 渡口浅滩专属贴图（v1.5，1 张美术图的可读性增益）。

---

## 第 10 节 评审裁决记录

### 10.1 得分汇总

| 设计案 | 玩家镜头 | 工程镜头 | 肉鸽镜头 | 总分 | 名次分布 |
|---|---|---|---|---|---|
| **structure-first** | 48（第 1） | 45（第 1） | 47（第 1） | **140** | 三镜头全票第一 |
| noise-first | 44（第 2） | 44（第 3，同分 tiebreak 负） | 45（第 2） | 133 | 两个第二一个第三 |
| evolve-current | 42（第 3） | 44（第 2，tiebreak 胜） | 44（第 3） | 130 | 两个第三一个第二 |

三份评审的终案建议高度一致：以 structure-first 为骨，长肉/修复层引 noise-first，工程纪律层引 evolve-current——本终案即此合成的执行。

### 10.2 采纳清单（按来源）

**structure-first（骨架主体）**：S1-S9 管线结构；archetype × 扇区牌双层变化；隘口/口袋/apron 由 protected 集构造保证；day1 发牌约束 + bias_cards_by_activation（三案中唯一接通夜晚系统，肉鸽镜头标杆）；开阔牌 ×1.5「富但难守」定价（对抗筑墙一招鲜的最优解，玩家镜头标杆）；sectors 元数据回传与主攻口播报链；噪声抖动代价场车道 A*；金种子快照 + 全链路集成测试；模块化拆分与里程碑 PR 切分；整数哈希噪声替代 FastNoiseLite。

**noise-first（长肉与修复供体）**：corridor = 最短路 + slack 格集作为统一验收对象（直接修掉骨架案最大缺陷）；鞍部软代价开凿（修复即设计，三案中对修复伤痕最优雅的回答）；入侵度量化断言（自然感变成可回归指标）；占比回调的分位数序补切/啃边；资源风味亲和 + risk_reward_bias（三案中唯一成体系的经济地理）；迎风湿度梯度；reserved/protected 前置预防优先于修复的三级约束哲学；splitmix64 派生 attempt 的有界重掷语义。

**evolve-current（工程纪律供体）**：任务 0「行为不变的 ctx + 每 pass RNG 流」重构先行 + A3 流隔离断言（主张配验证的范本）；mesa 评分函数 + 逐座落地→重派生→复检→回滚闭环（车道漂移最严谨的解）；渡口预规划（每车道强制恰 1 渡口）；预算台账（申请/落地/回滚三数可观测）；T10 反蚯蚓形状质量门；保守剖面 + 曼哈顿走廊清障的末路兜底（「任何路径不返回非法地图不死循环」）；灰度合入序（纯修复先行老地图受益）；起手台 4-5 环修正（唯一发现任务书自带矛盾并修正的方案）；walker 纺锤剖面 + 动量卷曲（作为长肉工具保留）。

### 10.3 否决清单（及理由）

| 被否决项 | 来源 | 理由 |
|---|---|---|
| 环核山带（同心弧） | evolve-current | 几何签名与「文明6 式自然」正面冲突；0.40 权重致近半数局同形；「守环」固化为新一招鲜（玩家 + 肉鸽镜头一致致命） |
| core_basin 核心盆地塑形 | noise-first | 替玩家预制中央 kill-box、反向资敌（玩家镜头致命）；核心保护区由 protected 构造保证已足够 |
| 隘口靠噪声涌现（无构造保证） | noise-first | 「通常有垭口」在肉鸽里 = 部分 seed 没牌打；终案隘口由牌构造保证 |
| 高台供给软约束化 | noise-first | 与任务书硬约束冲突，首晚远程可部署性是生死线 |
| 起手台 3~4 环 | noise-first | 代码坐实 3 环在保护区内（`_is_protected_cell` ≤3 含界），改 4-5 环 |
| 外层棱线「引流」 | evolve-current | 被自身代码注释戳穿的纸面深度，否决叙事、外层意义改由牌语义承担 |
| B4 隘口唯一性硬断言原文 | structure-first | 与放弃封堵策略矛盾，CI 必红；改为 pass_grade 分级验收 |
| 作者车道作为验收对象 | structure-first | 敌人走真实最短路会偏出作者线；验收对象换 corridor |
| 固定 3×4 矩形口袋 protected | structure-first | 模板痕迹；改 2×3 最小核 + flood 形状自由判定 |
| FastNoiseLite | noise-first（备选） | 整数哈希噪声逐位跨平台一致且实现仅 ~50 行，浮点风险结构性归零 |
| WFC / 完整 priority-flood / LoS 系统 | 调研 C / 任务书 | 全局约束 WFC 表达不了；30×30 不值得；LoS 用户明令禁止 |
| 湖泽牌（v1） | structure-first 自荐砍项 | 三 archetype 最小词汇表已由四张牌满足，省 ~1.5 任务量，v1.1 回补 |

---

**关键文件**：`/Users/messmerr/Documents/3.2/ruangong_projects/BUAASE-HexaVigil/scripts/map/map_generator.gd`（整体重写对象）、`scripts/map/cell_data.gd`（+TERRAIN_HIGHLAND）、`scripts/combat/unit_manager.gd:64,131`（部署校验）、`scripts/map/map_root_view.gd:1022,1052`（渲染兜底陷阱）、`scripts/map/map_manager.gd`（debug 序列化 + 唯一调用方）、`data/map_generation.json`（schema 扩展）、新建 `scripts/map/generation/{skeleton,lanes,flesh,repair,int_noise}.gd` 与 `scripts/debug/test_map_generation.gd`。