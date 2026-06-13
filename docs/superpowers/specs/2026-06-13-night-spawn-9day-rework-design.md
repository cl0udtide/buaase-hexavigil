# 夜晚出怪机制 · 九天三幕重构 设计

> 状态：设计定稿 2026-06-13。对应主文档 `docs/肉鸽构筑与战斗优化方案.md` 的 P3-1（幕结构）、P3-2（第三 Boss）、P3-3（模板扩充+enemy_choices），落地后回填主文档与 §8 状态。
> 数值全部为占位，按"结构先稳、平衡后调"——def/res 阶梯定稿留到 P3-4 跑批；本期只保证结构/曲线/三 Boss 跑通且有 headless 回归。
> 现状权威以代码、`docs/ARCHITECTURE.md`、`docs/DATA_SCHEMA.md`、`docs/INTERFACE.md` 为准。

## 0. 目标

1. 修难度曲线：前期压人数 + 延后飞行；后期靠**全局强度系数**追上 2-3★ + 遗物的复利增长。
2. 九天三幕：`d3/d6/d9` 为幕 Boss 晚，胜利判定数据驱动（替换 `day>=6` 硬编码）。
3. 第三 Boss「焦壳奶龙」（奶龙换色占位）：反弹物理 + 大范围法术 AOE 普攻 + 二阶段朝向火雨。
4. ~21 个有独立战术命题的波次模板 + `enemy_choices` 变体。
5. 九天与遗物/事件咬合：构筑跑道随幕展开、在第三幕兑现（九天延长的唯一目的就是给构筑足够空间）。

诊断（为什么两头崩）：敌人强度静态（模板写死、只到第 6 天、零全局缩放），玩家强度复利（3★=2.3× 全属性 + 每遗物 +10~15% + 盟约 +25~60%）。第 1 天单波 early 就 15-20 只且可能含飞行 → 过载；后期固定数值敌人被碾压。文档 §4.4 早开过药方（数量、数值两条按天曲线）但从未实现——本期补上。

---

## 1. 全局强度系数 `DifficultyScale`（杂兵侧）

新文件 `scripts/enemy/difficulty_scale.gd`（`extends RefCounted`，`class_name DifficultyScale`），风格对齐 `NightTemplateResolver`/`NightAffixService`（纯静态、可脱离 DataRepo 测试）。

两张**逐天**表（每天一个值，阶梯回退取 `<=day` 最大键，超出回退末日 d9）：

| 天 | 1 | 2 | 3⚔ | 4 | 5 | 6⚔ | 7 | 8 | 9⚔ |
|---|---|---|---|---|---|---|---|---|---|
| `COUNT_SCALE_BY_DAY` | 0.65 | 0.75 | 0.85 | 0.95 | 1.05 | 1.15 | 1.25 | 1.35 | 1.45 |
| `STAT_SCALE_BY_DAY` | 1.0 | 1.08 | 1.18 | 1.30 | 1.45 | 1.62 | 1.82 | 2.05 | 2.30 |

数量逐天线性 +0.1（前期 <1 压人数，数量是次要杠杆）；数值步长逐天递增（.08→.25）、**后段更陡**，末日 2.30× 追玩家复利。两条都**逐天**变化，不压成分幕平台。

静态接口：`count_scale_for_day(day) -> float`、`stat_scale_for_day(day) -> float`。

挂载（`wave_manager.gd`）：
- **数量**：展开 group 时 `count = max(ceil(count * count_scale), 1)`（在 `_make_expanded_spawn_entries` 前，与 affix `transform_entries` 同层，affix 之后再乘）。
- **数值**：spawn 时把 `stat_scale` 写进 cfg_override（键如 `_stat_scale`），`enemy_actor` 在 `setup_from_cfg`（~`enemy_actor.gd:124`）读出并存为实例字段，对 `max_hp/atk/def/res` 整数乘；`_apply_phase_cfg`（~`enemy_actor.gd:841`）也套用同一实例字段——**保证阶段切换后仍缩放**。
- 整数处理（max_hp 下限 1，其余下限 0）与 `NightAffixService.INT_STATS` 一致。

**模板只描述构成形状，难度成长全交给这两张表——以后平衡只调这里，不动模板。** 预览管线走同一 resolve 路径，缩放后人数/数值在敌情预览里如实反映（预览即契约）。

---

## 2. Boss 动态数值 + boss 池（按"不写死哪天"要求）

- `DifficultyScale.BOSS_STAT_SCALE_BY_DAY = {3:1.0, 6:1.6, 9:2.5}`（占位，阶梯回退）。Boss 只在幕末 d3/d6/d9 出场，故只需三点（非平台问题）。Boss 走这条独立曲线，**不吃杂兵 `STAT_SCALE`**（免双重缩放）；复用 §1 的实例字段机制（spawn 时按 boss/非 boss 决定写入哪条系数）。
- **Boss 数值不下放**（现有 Boss 在终局已偏简单，只能更难、不能更弱）：保留奶龙/爱国者现数值（P1 hp 2400 / 2250）作为基准，第三 Boss 取相近量级（~2300），三只基准相当、差异体现在机制。`BOSS_STAT_SCALE` 以最早出场夜 d3=1.0 为下限（即不低于现状）、越晚越强：d3≈现状 / d6≈×1.6 / d9≈×2.5，没有任何 Boss 弱于现状，终局 Boss 明显更硬。缩放覆盖各 phase 的 hp/atk/def/res。
- **boss 不写死哪天**：boss tier 模板池含三个 boss 模板，`resolve_night_plan` 对 boss tier 已做抽取 + 局内去重 → d3/d6/d9 抽到三只不同 Boss，顺序随种子。
- 软闸：boss 模板支持可选 `min_day`；新 Boss「焦壳奶龙」`min_day=4`（≥幕二才登场，避免第一幕就上机制最重的 Boss）。其余两只无闸。pool 组装时（`wave_manager.resolve_night_plan` / 调用方）按 `min_day` 过滤当日 boss 池。

---

## 3. 九天三幕日程

`NightTemplateResolver`：

```
const TOTAL_DAYS := 9
const WAVE_TIERS_BY_DAY := {
    1: [early],
    2: [early, early],
    3: [early, boss],          # 幕一 Boss
    4: [mid, mid],
    5: [mid, mid, late],
    6: [late, boss],           # 幕二 Boss
    7: [late, late],
    8: [mid, late, late],
    9: [late, late, boss],     # 幕三 / 终局 Boss
}
```
波数 1,2,2,2,3,2,2,3,3（boss 晚刻意少配 adds，Boss 是主菜，count_scale 也已配合）。

- **胜利判定数据驱动**：`game_controller.gd:162` `run_state.day >= 6` → `run_state.day >= NightTemplateResolver.TOTAL_DAYS`。同步排查并改 `audio_manager.gd:284` 的 `day >= 6`（音乐升档阈值）等其它 6 天硬编码。
- **词缀数量** `NightAffixService.AFFIX_COUNT_BY_DAY`：逐幕加压 1→2→3（`{1:1,4:2,7:3}` 阶梯 = 1,1,1,2,2,2,3,3,3），末幕到 3 条。整数杠杆，三档展开九天（day1 名义 1 条，但词缀均 `min_day>=2`，首夜实际无缀）。
- **活跃出怪口** `NightTemplateResolver.ACTIVE_COUNT_BY_DAY`：逐步开口 2→3→4→5（`{1:2,4:3,6:4,8:5}` 阶梯），前期 2 口、d8 起全开 5（受地图总口数 5 封顶）。
- **部署上限** `floor((day-1)/2)` 天数无关，9 天 → 4→8 位，确认即可（不改公式）。
- **飞行闸**：含飞行敌人（`move_type:flying`，现为 `bat`/`arts_drone`）的 group 仅 `day>=2` 生效——实现为 `wave_manager` 展开 entry 时，若 `day<2` 且该 entry 的 enemy（含 enemy_choices 命中项）是飞行单位则跳过该 entry（查 DataRepo 敌人 cfg 的 `move_type`）。模板照常可写飞行 group，闸在运行时统一生效。修"第一晚就飞行"。

---

## 4. 第三 Boss「焦壳奶龙」（奶龙换色占位）

`enemies.json` 新条目（id 如 `boss_emberscale`），`behavior_type:boss`，双 phase，美术=`milk_dragon_chief` 换色（厚鳞→焦壳/余烬，沿用其 sprite/动画）。复用现成双形态框架（`boss_controller.gd:7-99` 的 `_phases`/transition/`apply_phase_enter_effects`，`enemy_actor.gd:841` 的 `_apply_phase_cfg`）。

新增三个 cfg 字段（风格对齐现有 `shield_hp`/`regen_per_sec`/`death_area_damage`/`death_spawn`/`phase_enter_area_damage`）：

1. **`reflect_physical_percent: float`（0-1）** — P1 生效。`enemy_actor.gd` 的 `receive_damage(value, damage_type, source)`（~`:168`）结算后：若 `damage_type==DAMAGE_PHYSICAL` 且 `source` 有 `receive_damage`，向 source 反弹 `final_damage * percent` 物理伤害。参考玩家侧 `penance_thorny_body_skill.gd:53` 的 `after_receive_damage` 模式。逼"别用物理硬怼，换法术/真伤/远程"。
2. **`attack_splash_radius: int`（+可选 `attack_splash_damage_type`）** — 大范围法术 AOE 普攻（Stellar Corona 风味）。命中后对落点半径内我方单位补一份溅射。注入 `enemy_attack_controller.gd` 的 `_resolve_range_hit`（~`:152`）与 `projectile.gd` 命中点（~`:86`）；范围遍历复用 `enemy_actor.gd:984` 的循环 + `unit_manager.get_unit_by_cell`（`:268`）。
3. **`fire_rain: {radius, damage_per_sec, duration, tick_interval}`** — P2 进入时朝**当前移动朝向**在前方铺一片地面火雨危险区，持续数秒每秒对站其上的我方单位造成法术 DOT（区域封锁逼重新布防）。在 `boss_controller.apply_phase_enter_effects`（~`:68`）读字段并实例化新节点 `scripts/effects/ground_hazard_zone.gd`（`_process` 计时 + 按 `tick_interval` 遍历覆盖格 `get_unit_by_cell` 结算 DOT，到时 `queue_free`）。Talulah 式 P2 同时**上调 def/res**（与反弹叠加，物理更难受），用现有 phase 数值字段即可。

综合：第三 Boss 是"伤害类型 + 站位"双检验，与前两只纯数值检验 Boss 区别开。占位数值（reflect ~30%、splash radius 1、fire_rain radius 2 / dps 15 / 8s）留余量，P3-4 再调。

---

## 5. 波次模板 ~21 + `enemy_choices`

`wave_templates.json`：early ×6、mid ×6、late ×6、boss ×3（共 21）。每模板锚定一个**独立战术命题**，彼此不重叠：

| 命题 | 检验 | 代表敌人 |
|---|---|---|
| 分裂潮 | AOE | splitting_originium_slug + slime |
| 护甲墙 | 物理/真伤 or 法术穿透 | armored_soldier / heavy_defender / shieldguard |
| 远程齐射 | 盾位/速杀 | crossbowman 群 + caster |
| 飞行突袭 | 对空火力 | bat / arts_drone（day≥2） |
| 拆迁队 | 护建筑/纵深 | demolitionist / siege_breaker / lumberjack_veteran |
| 再生宿主 | 持续爆发 | possessed_soldier + sarkaz_greatswordsman |

- 每模板配 1-2 个 `enemy_choices` 同档替换槽（同档敌人互换、权重各 1）→ 同模板每局换脸，启用闲置的 `_pick_enemy_choice`（`wave_manager.gd:483` 已实现，预览一致）。
- boss 模板：三个，各引一只 Boss + 该 Boss 主题的 lead-in adds。
- lane（main/flank/any）沿用 gates v2 解耦语义，不写死出怪口。

修既有 `scripts/debug/test_wave_templates.gd`：把"15 模板 / 4-5-4-2"硬断言改为新档量；启用当前被跳过的 `enemy_choices` 校验分支。

---

## 6. 九天 × 遗物 × 事件 咬合（用户重点）

九天延长的唯一目的是给构筑足够跑道并在第三幕兑现，所以以下三者必须协同：

**遗物稀有度曲线**（`buff_manager._allowed_rarities_for_day`，对齐三幕）：
```
d<=2: [1]        # 幕一前段：普通铺底
d<=4: [1,2]      # 幕一末~幕二前：稀有进入
else  [2,3]      # d5-9：稀有为主 + 传说兑现（band 拉长 = 构筑 payoff）
```
- 夜后三选一次数：9 天 = **8 次**（vs 6 天 5 次），构筑跑道翻倍——目标是约幕二成型、幕三兑现，正好对冲 §1 上升的 stat 曲线。
- **幕收尾保底（幕间大节点轻量版）**：幕一/幕二 Boss 清场（d3/d6）后的那次三选一，保底至少一件该幕稀有度上限的遗物。实现：`_on_night_cleared` 检测 act-boss 清场置 `pending_milestone_blessing`，`enter_blessing` 让 `buff_manager` 抽取时该槽设稀有度下限。完整三选一大奖励（定向升星/移除词缀/高级契约）UI 留 follow-up，不在本期。

**随机事件与九天**：
- 每日刷新已 day 驱动（开局 2 / 每天 1-2 / 上限 4，`random_event_manager.gd:9-14`），天数变多自然延长事件循环——魔力矿/声望/定向升星经济获得更多回合兑现构筑，祭坛灌注 tag、战争赌局额外三选一随天数复利。
- **核对 6 天遗留门控**：`events.json` 的 `min_day/max_day` 按 6 天设的要重估——开口赌约 `max_day:6`（gates v2）放宽到 ~8；`max_day:5` 的事件（`events.json:70`）评估是否随九天上调。`random_event_manager` 本身无 6 天硬编码（`:417` 用 `max_day` 默认 99），改数据即可。

**风险（交 P3-4 跑批验收，本期留余量）**：词缀 × 契约在幕三高 stat 下的最坏组合不应无解；占位 stat 曲线（d9 1.8×）与 boss 曲线（d9 2.4×）保守取值，避免一次性拉满。

---

## 7. 商店档位权重随天数（支撑构筑兑现）

`shop_manager.TIER_WEIGHTS`（静态 60/30/10）改为按幕的 `TIER_WEIGHTS_BY_DAY`（占位）：

| 幕 | 天 | 2 费 | 4 费 | 7 费 |
|---|---|---|---|---|
| 一 | 1-3 | 65 | 28 | 7 |
| 二 | 4-6 | 50 | 35 | 15 |
| 三 | 7-9 | 35 | 38 | 27 |

高费（通常高影响）干员后段更易出现，配合定向升星让构筑在幕二/幕三稳定成型。`start_new_day_shop(day)` 已传 day（当前忽略），按当日取权重即可；与 P2-1 锁定/盟约漂移并存（漂移在档位权重之上再叠）。

---

## 8. 测试（headless，`extends SceneTree`）

新增 `scripts/debug/test_night_spawn_rework.gd`：
- `DifficultyScale` count/stat/boss 三表取值 + 阶梯回退 + 缺省。
- 9 天 `WAVE_TIERS_BY_DAY` 结构、boss 晚位置；`TOTAL_DAYS` 胜利判定（day 8 进 blessing、day 9 胜）。
- boss 池：固定种子下 d3/d6/d9 抽到三只不同 Boss；`min_day` 软闸使新 Boss 不出现在 d3；boss 动态缩放后数值（含 phase）正确。
- 第三 Boss 行为（沙盒断言）：物理来源受反弹、法术来源不受；attack_splash 命中半径内多个我方单位；fire_rain 区域内我方逐秒扣血、到时消失；phase 切换后缩放保持。
- 遗物 9 天 rarity 门控表；幕收尾保底槽生效。

改 `test_wave_templates.gd`（档量 21 / 启用 enemy_choices 分支）。其余既有套件（night_template_flow / night_waves_affixes / relic_draw / contract_events / shop_lock_drift / targeted_star_up / spawn_gates_v2 / highland_platform / map_generation / wall_art）保持全绿——其中 night_template_flow 等含 6 天假设的断言需同步改到 9 天。

---

## 9. 触点清单

| 文件 | 改动 |
|---|---|
| `scripts/enemy/difficulty_scale.gd` | **新增**：count/stat/boss 三条曲线 + 静态取值 |
| `scripts/enemy/wave_manager.gd` | count 缩放（展开）、stat/boss 系数写入 cfg_override、飞行 day 闸、boss 池 min_day 过滤 |
| `scripts/enemy/enemy_actor.gd` | `setup_from_cfg`/`_apply_phase_cfg` 套用缩放系数；`receive_damage` 反弹钩子 |
| `scripts/enemy/enemy_attack_controller.gd` + `scripts/combat/projectile.gd` | attack_splash 范围溅射 |
| `scripts/enemy/boss_controller.gd` | fire_rain 实例化（phase_enter） |
| `scripts/effects/ground_hazard_zone.gd` | **新增**：地面火雨 DOT 危险区节点 |
| `scripts/enemy/night_template_resolver.gd` | `TOTAL_DAYS`、9 天 `WAVE_TIERS_BY_DAY` |
| `scripts/enemy/night_affix_service.gd` | `AFFIX_COUNT_BY_DAY` 扩 9 天 |
| `scripts/core/game_controller.gd` | 胜利判定改 `TOTAL_DAYS`；幕收尾保底 blessing |
| `scripts/core/audio_manager.gd` | `day>=6` 阈值重估 |
| `scripts/core/buff_manager.gd` | rarity 9 天曲线；幕收尾保底槽 |
| `scripts/combat/shop_manager.gd` | `TIER_WEIGHTS_BY_DAY` |
| `data/enemies.json` | 新增第三 Boss 条目（两 Boss 现数值不动，靠 boss 曲线越晚越强） |
| `data/wave_templates.json` | ~21 模板 + enemy_choices + boss 池 |
| `data/events.json` | 6 天遗留 min_day/max_day 重估 |
| `scripts/debug/test_*.gd` | 新增 1 套 + 改 wave_templates/含 6 天假设的套件 |

---

## 10. 落地顺序（供 writing-plans 分解）

1. `DifficultyScale` + wave_manager 缩放挂载 + 测试（最小可验证内核）。
2. 9 天日程：`TOTAL_DAYS` + `WAVE_TIERS_BY_DAY` + 胜利判定 + affix/部署/飞行闸 + 同步既有断言。
3. Boss 动态缩放 + boss 池 + `min_day` 软闸。
4. 第三 Boss 三机制（反弹 / attack_splash / fire_rain 节点）+ 美术换色条目。
5. ~21 模板 + enemy_choices + 改 test_wave_templates。
6. 商店权重曲线 + 遗物 rarity 9 天曲线 + 幕收尾保底 + 事件 6 天门控重估。
7. 测试收口（全套件绿）+ 回填主文档状态。
