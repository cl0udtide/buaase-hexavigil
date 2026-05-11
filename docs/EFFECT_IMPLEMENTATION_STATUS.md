# 特效实装状态

统计时间：2026-05-11

统计口径：

- 只统计 `assets/effects/` 下的透明 PNG 运行资产和 `assets/effects/raw/` 下的源图。
- `已实装` 表示已有明确代码或数据配置入口，当前机制触发时会播放。
- `API 已接入` 表示底层接口会播放，但当前数据/技能未必有生产者。
- `备用` 表示资产可被默认逻辑或未来配置使用，但当前没有明确专属触发。
- `已停用` 表示曾用于运行时，但当前机制已改走其他入口。
- `管线初版` 表示已有程序化渲染入口，但尚未拼接对应 PNG 材质。
- `待材质拼接` 表示程序化管线已存在，但该 PNG 还没有被渲染器实际使用。
- `待管线` 表示资产已裁入库，但还缺专门渲染逻辑，不应硬接。
- `.import` 文件由 Godot 生成，不在表中逐项统计。

## 运行时入口

| 入口 | 文件 | 当前用途 |
|---|---|---|
| 通用一次性/循环特效节点 | `scripts/effects/one_shot_effect.gd` | 读取 `texture_path`，支持序列帧、循环、跟随目标、世界坐标、旋转和缩放；跟随目标失效时自动销毁 |
| 干员特效接口 | `scripts/combat/unit_actor.gd` | `spawn_one_shot_effect()`、`play_follow_effect()`、`spawn_world_effect()`、投射物配置透传 |
| 敌人特效接口 | `scripts/enemy/enemy_actor.gd` | 命中、状态、DOT、护盾、死亡、推拉、自回复、Boss/敌人技能反馈 |
| 建筑特效接口 | `scripts/building/building_actor.gd` | 建筑受击、修复反馈 |
| 投射物显示 | `scripts/combat/projectile.gd` | 读取 `texture_path` / `projectile_texture_path` 和尺寸配置，默认按伤害类型选贴图 |
| 通用技能启动/结束 | `scripts/combat/skills/unit_skill_behavior.gd` | 技能成功启动和自然/主动结束时播放短反馈 |
| 地图范围描边 | `scripts/map/map_root_view.gd` | `set_range_outline()` 按格集合计算外边界，并按 style 拼接 `assets/effects/range/` 的边线、角点、节点素材 |

## 源图

| 源图 | 状态 | 说明 |
|---|---|---|
| `raw/effect_source_sheet_01_common_impacts.png` | 已裁剪 | 通用受击与治疗反馈 |
| `raw/effect_source_sheet_02_projectiles.png` | 已裁剪 | 第一批干员/通用投射物 |
| `raw/effect_source_sheet_03_truesilver_slash.png` | 已裁剪 | 真银斩主剑气与命中火花 |
| `raw/effect_source_sheet_04_range_outlines.png` | 已裁剪，部分接入 | 通用范围描边素材；`edge_base` / `node_glow` 作为 fallback 接入 |
| `raw/effect_source_sheet_05_looping_auras.png` | 已裁剪 | 攻击增益、易伤、护盾、眩晕等循环反馈 |
| `raw/effect_source_sheet_06_common_status_fields.png` | 已裁剪 | 通用状态、DOT、推拉、死亡反馈 |
| `raw/effect_source_sheet_07_operator_priority_attacks.png` | 已裁剪 | P1 干员攻击特效 |
| `raw/effect_source_sheet_08_operator_fields_barriers.png` | 已替换并裁剪 | 塞雷娅/黍领域素材保留为候选；运行时已改走地图描边，避免整块覆盖 |
| `raw/effect_source_sheet_09_enemy_boss_effects.png` | 已裁剪 | 敌人与 Boss 专属反馈 |
| `raw/effect_source_sheet_10_range_cast_warnings.png` | 已裁剪并接入 | 技能范围、危险、重力、建筑范围边界素材；当前技能/建筑/重力样式已接入 |
| `raw/effect_source_sheet_11_operator_secondary_attacks.png` | 已裁剪并部分实装 | 剩余干员攻击主特效与专属投射物 |
| `raw/effect_source_sheet_12_operator_stances_recovery.png` | 已裁剪并部分实装 | 持续姿态、自回复、防御类反馈 |
| `raw/effect_source_sheet_13_enemy_projectile_environment.png` | 已裁剪并部分实装 | 敌人投射物、Boss、建筑修复补充 |

## 通用与状态

| 资产 | 状态 | 触发位置 | 备注 |
|---|---|---|---|
| `common/impact_physical_small_strip.png` | 已实装 | `UnitActor`、`EnemyActor`、`BuildingActor` 物理受击 | 替代旧圆形受击表现 |
| `common/impact_arts_small_strip.png` | 已实装 | `UnitActor`、`EnemyActor`、`BuildingActor` 法术受击 | 按伤害类型自动选择 |
| `common/impact_true_damage_small_strip.png` | 已实装 | `UnitActor`、`EnemyActor`、`BuildingActor` 真实伤害受击 | 真实伤害/高强度命中 |
| `common/impact_heal_small_strip.png` | 备用 | 暂无运行时引用 | 旧治疗反馈候选；当前治疗使用 `heal_tick_small_strip` |
| `common/heal_tick_small_strip.png` | 已实装 | `UnitActor.receive_heal()` | 干员治疗、自回复、建筑光环治疗都会走这个入口 |
| `common/skill_cast_flash_strip.png` | 已实装 | `UnitSkillBehavior.cast()` | 技能成功启动时播放 |
| `common/skill_end_fade_strip.png` | 已实装 | `UnitSkillBehavior.tick()` / `end_skill()` | 技能自然结束或主动结束时播放 |
| `common/building_repair_heal_pulse_strip.png` | 已实装 | `BuildingActor.repair_full()` | 手动/白天自动修复都会播放 |
| `common/enemy_regen_tick_strip.png` | 已实装 | `EnemyActor._tick_regeneration()` | 当前由 `possessed_soldier` 的 `regen_per_sec` 触发 |
| `common/enemy_death_spawn_puff_strip.png` | 已实装 | `EnemyActor._play_death_spawn_effect()` | 分裂召唤的每个出生点小烟尘 |
| `common/slow_bind_snare_strip.png` | 已实装 | `EnemyActor.apply_bind()` / `apply_move_speed_multiplier()` | 塞雷娅、澄闪、娜仁图亚、莱伊、黍等会触发 |
| `common/resistance_shred_mark_strip.png` | 已实装 | `EnemyActor.apply_resistance_shred()` | 当前由伊芙利特灼地和攻击削抗触发 |
| `common/armor_break_mark_strip.png` | API 已接入 | `EnemyActor.apply_defense_shred()` | 当前没有已配置技能调用防御削减 |
| `auras/debuff_fragile_aura_strip.png` | 已实装 | `EnemyActor.apply_physical_vulnerability()` / `apply_magic_vulnerability()` | 当前塞雷娅钙质化触发法术易伤 |
| `common/psychic_dot_aura_strip.png` | 已实装 | `EnemyActor.apply_dot()` | 妮芙已回退为纯 DOT 后使用 |
| `common/burn_dot_small_strip.png` | API 已接入 | `EnemyActor.apply_dot()` 物理类型分支 | 当前没有明确物理 DOT 生产者 |
| `common/push_pull_streak_strip.png` | 已实装 | `EnemyActor.apply_push()` / `apply_relocate_to_cell()` | 异客推开、黍回拉等位移反馈 |

## 持续光环与标记

| 资产 | 状态 | 触发位置 | 备注 |
|---|---|---|---|
| `auras/barrier_guard_loop_strip.png` | 已实装 | `UnitActor.apply_damage_reduction()`、星熊、斥罪、左乐 | 通用减伤/屏障/防御姿态 |
| `auras/buff_attack_aura_strip.png` | 已实装 | `common_atk_up_skill.gd` | 通用攻击强化技能 |
| `auras/caster_overload_aura_strip.png` | 已实装 | `caster_overload_permanent_skill.gd` | 艾雅法拉火山永久姿态 |
| `auras/counter_thorn_spark_strip.png` | 已实装 | `defender_counter_stance_skill.gd`、`penance_thorny_body_skill.gd` | 反伤目标上播放 |
| `auras/defender_fortify_loop_strip.png` | 已实装 | `defender_fortify_skill.gd` | 非年防御姿态 fallback |
| `auras/nian_iron_guard_loop_strip.png` | 已实装 | `defender_fortify_skill.gd` | 年铁御专属护壁 |
| `auras/mark_target_lock_strip.png` | 已实装 | `typhon_eternal_hunt_skill.gd` | 提丰标记目标 |
| `auras/mountain_recover_pulse_strip.png` | 已实装 | `mountain_sweeping_stance_skill.gd` | 山横扫架势常驻自回复 |
| `auras/saria_calcification_field_strip.png` | 已停用 | 无运行时引用 | 塞雷娅领域已改用 `MapRoot.set_range_outline()`，避免整张跟随光环覆盖地图 |
| `auras/shu_growth_aura_strip.png` | 已停用 | 无运行时引用 | 黍半径两格领域已改用 `MapRoot.set_range_outline()`；没有种子标记 |
| `auras/shield_absorb_aura_strip.png` | 已实装 | `EnemyActor._play_shield_absorb_effect()` | 通用敌人护盾吸收 |
| `auras/stun_star_small_strip.png` | 已实装 | `EnemyActor.apply_stun()` | 杰西卡、提丰等眩晕触发 |
| `auras/surtr_twilight_aura_strip.png` | 已实装 | `surtr_twilight_skill.gd` | 史尔特尔黄昏持续身光 |

## 干员专属攻击与技能

| 资产 | 状态 | 触发位置 | 备注 |
|---|---|---|---|
| `slash/truesilver_slash_wave_strip.png` | 已实装 | `guard_decisive_swing_skill.gd` | 真银斩范围剑气，按技能范围计算尺寸 |
| `slash/truesilver_hit_spark_strip.png` | 已实装 | `guard_decisive_swing_skill.gd` | 真银斩命中火花 |
| `operators/fiammetta_shell_explosion_strip.png` | 已实装 | `sniper_burst_dawn_skill.gd` | 菲亚梅塔炮击落点 |
| `operators/jessica_shell_explosion_strip.png` | 已实装 | `jessica_saturation_burst_skill.gd` | 涤火杰西卡炮击爆点 |
| `operators/ifrit_flame_line_strip.png` | 已实装 | `ifrit_scorched_earth_skill.gd` | 伊芙利特直线灼地，按朝向拉伸 |
| `operators/goldenglow_lightning_strike_strip.png` | 已实装 | `goldenglow_clear_shine_skill.gd` | 澄闪落雷 |
| `operators/logos_execute_crack_strip.png` | 已实装 | `logos_oblivion_skill.gd` | 逻各斯低血斩杀 |
| `operators/logos_transfer_arc_strip.png` | 已实装 | `logos_oblivion_skill.gd` | 逻各斯溢出转移弧线 |
| `operators/surtr_twilight_hit_flare_strip.png` | 已实装 | `surtr_twilight_skill.gd` | 史尔特尔黄昏命中火花 |
| `operators/degenbrecher_multi_slash_pull_strip.png` | 已实装 | `degenbrecher_silence_skill.gd` | 锏多段斩击与牵引 |
| `operators/caster_chain_arc_strip.png` | 已实装 | `caster_chain_push_skill.gd` | 异客连锁法术电弧 |
| `operators/narantuya_return_path_spark_strip.png` | 已实装 | `narantuya_solar_swallow_skill.gd` | 娜仁图亚返程路径火花 |
| `operators/ray_bind_tether_strip.png` | 已实装 | `ray_light_skill.gd` | 莱伊束缚线 |
| `operators/typhon_hunt_extra_hit_strip.png` | 已实装 | `typhon_eternal_hunt_skill.gd` | 提丰额外追猎命中 |
| `operators/wisadel_overload_gunfire_strip.png` | 已实装 | `wisadel_saturated_revenge_skill.gd` | 维什戴尔后半段过载连击 |
| `operators/exusiai_volley_tracer_strip.png` | 已实装 | `sniper_quintuple_shot_skill.gd` | 能天使五连射曳光 |
| `operators/eyja_volcano_burst_strip.png` | 已实装 | `caster_overload_permanent_skill.gd` | 艾雅法拉火山范围爆点 |
| `operators/mountain_sweep_arc_strip.png` | 已实装 | `mountain_sweeping_stance_skill.gd` | 山攻击被阻挡敌人时的横扫弧 |
| `operators/guard_hold_line_arc_strip.png` | 已实装 | `guard_hold_line_skill.gd` | 煌/挡线攻击弧 |
| `operators/zuo_le_blood_cost_flash_strip.png` | 已实装 | `zuo_le_risky_venture_skill.gd` | 左乐行险损血代价反馈 |

## 敌人与 Boss

| 资产 | 状态 | 触发位置 | 备注 |
|---|---|---|---|
| `enemies/shieldguard_shield_absorb_strip.png` | 已实装 | `EnemyActor._play_shield_absorb_effect()` | `shieldguard` 专属护盾吸收 |
| `enemies/originium_slug_death_burst_strip.png` | 已实装 | `EnemyActor._play_defeat_effect()` | 有 `death_area_damage` 的敌人死亡爆裂 |
| `enemies/originium_slug_split_puff_strip.png` | 已实装 | `EnemyActor._play_defeat_effect()` | 有 `death_spawn` 的敌人死亡主体分裂烟尘 |
| `enemies/demolisher_heavy_hit_strip.png` | 已实装 | `EnemyAttackController.process_building_attack()` | 拆路敌人攻击路径建筑 |
| `enemies/enemy_melee_heavy_hit_strip.png` | 已实装 | `EnemyAttackController.process_blocked_attack()` | Boss、拆路敌人、高攻击或高重量敌人的近战重击 |
| `enemies/boss_phase_transition_strip.png` | 已实装 | `BossController._start_phase_transition()` | Boss 转阶段无敌等待期 |
| `enemies/boss_phase_enter_area_burst_strip.png` | 已实装 | `BossController.apply_phase_enter_effects()` | Boss 入阶段范围伤害，非爱国者使用 |
| `enemies/patriot_destroyer_shockwave_strip.png` | 已实装 | `BossController.apply_phase_enter_effects()` | 爱国者入毁灭姿态范围冲击 |
| `enemies/boss_rage_cast_flash_strip.png` | 已实装 | `BossController.apply_phase_enter_effects()` | Boss 入阶段瞬时启动闪光 |
| `enemies/boss_thick_scale_absorb_strip.png` | 暂不接入 | 无运行时引用 | 当前奶龙厚鳞没有独立吸收/护甲触发机制，硬播会误导玩家 |

## 投射物

| 资产 | 状态 | 触发位置 | 备注 |
|---|---|---|---|
| `projectiles/projectile_arrow.png` | 备用/默认 | `Projectile._default_texture_path_for_damage_type()` | 物理投射物未配置专属贴图时使用 |
| `projectiles/projectile_arts_orb.png` | 备用/默认 | `Projectile._default_texture_path_for_damage_type()` | 法术投射物未配置专属贴图时使用 |
| `projectiles/projectile_heavy_shot.png` | 已实装 | `Projectile` 默认真实伤害；`data/enemies.json` 爱国者配置 | 重型弹体 |
| `projectiles/projectile_fire_orb.png` | 备用 | 暂无运行时引用 | 可给未来火焰投射物配置 |
| `projectiles/projectile_crossbow_bolt.png` | 已实装 | `data/enemies.json` 弩手 | 敌方物理远程 |
| `projectiles/projectile_enemy_arts_orb.png` | 已实装 | `data/enemies.json` 术师、高阶术师 | 敌方法术远程 |
| `projectiles/projectile_drone_arts_orb.png` | 已实装 | `data/enemies.json` 法术无人机 | 飞行敌人法术弹 |
| `projectiles/projectile_milk_dragon_rage.png` | 已实装 | `data/enemies.json` 奶龙酋长 | Boss 专属重型投射物 |
| `projectiles/narantuya_return_projectile.png` | 已实装 | `narantuya_solar_swallow_skill.gd` | 娜仁图亚技能期专属弹体 |
| `projectiles/ray_bind_shot_projectile.png` | 已实装 | `ray_light_skill.gd` | 莱伊技能期专属束缚射击 |

## 范围描边资产

范围描边已有材质版管线：`MapRoot` 可以按一组生效格计算外边界，并按 style 选择不同 PNG 边线、角点和节点素材。临时 UI 预览仍保持每格覆盖层；实战生效的扩展攻击范围和已建成建筑光环走边界描边。

| 资产 | 状态 | 预期用途 |
|---|---|---|
| `range/range_outline_edge_base.png` | 已实装 | 通用范围外边界 fallback 边线 |
| `range/range_outline_edge_pulse.png` | 暂不接入 | 当前 PNG alpha 为空，不能作为可见脉冲边线使用 |
| `range/range_outline_corner_base.png` | 备用 | 通用范围角点；当前技能范围优先使用专用角点 |
| `range/range_outline_cap_base.png` | 备用 | 通用端帽；当前外边界都是闭合区域，暂不需要端帽 |
| `range/range_outline_node_glow_strip.png` | 已实装 | 通用 fallback 边界节点呼吸 |
| `range/skill_range_warning_edge_pulse_strip.png` | 已实装 | 扩展攻击范围技能边线；塞雷娅领域也复用 |
| `range/skill_range_warning_corner_pulse_strip.png` | 备用 | L 型角点较醒目，当前扩展攻击范围先用更轻的节点光 |
| `range/aoe_warning_edge_pulse_strip.png` | API 已接入 | `warning` style 可用；当前未主动给 Boss/AOE 注册持续预警 |
| `range/field_boundary_node_pulse_strip.png` | 已实装 | 建筑光环、重力场、黍领域的边界节点 |
| `range/gravity_field_edge_pulse_strip.png` | 已实装 | 已建成重力塔的实际减速光环边线 |
| `range/building_aura_edge_pulse_strip.png` | 已实装 | 已建成建筑光环边线；黍领域也复用 |

## 已确认不再做的冗余表现

| 旧方向 | 当前处理 | 原因 |
|---|---|---|
| 黍种子标记 / 播种地块 | 不接入，已改为 `MapRoot` 半径两格细描边领域 | 当前机制只是记录敌人回拉锚点，没有真实种子实体 |
| 史尔特尔地面热浪持续覆盖 | 不接入 | 当前机制是身光、命中火花和生命流失，没有独立地面对象 |
| 每格状态覆盖层 | 不接入 | 格子贴图会叠加，容易遮挡地图与部署信息；后续改做外边界描边 |

## 下一步建议

1. 后续若要做 Boss/AOE 预警，可以直接调用 `MapRoot.set_range_outline(..., {"style": &"warning"})`。
2. 若要使用 `boss_thick_scale_absorb_strip`，需要先给奶龙厚鳞阶段设计明确的护甲吸收、减伤触发或受击吸收机制。
3. `impact_heal_small_strip`、`projectile_fire_orb.png`、`armor_break_mark_strip.png`、`burn_dot_small_strip.png` 可保留为备用；等有明确机制生产者再接。
