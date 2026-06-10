# Effect Asset Generation Prompts

本文档用于网页端 AI 生图工具连续生成战斗特效源图。目标是把当前工程中偏程序绘制的圆形受击、线条投射物，逐步替换或补充为可裁剪、可复用、可在 Godot 中播放的透明 PNG 特效资产。

当前工程已经存在 `World/ProjectileRoot` 与 `World/EffectRoot`，也有基础 projectile 与 hit effect 逻辑。本文档只定义生图提示词、命名和裁剪约定；具体接入时以当前场景、脚本和数据结构为准。

## 1. 实施分层与阶段

特效资产先按“通用可复用”和“技能专用”拆分，避免第一轮直接为每个干员、敌人或建筑做一套不可复用的视觉规则。

### 1.1 第一阶段：通用特效

第一阶段优先做能覆盖大量战斗行为的基础资产：

- 通用命中反馈：物理命中、法术命中、治疗、重击或真实伤害。
- 通用投射物：箭矢、法术弹、重型射击、火焰弹。
- 通用持续状态：增益、易伤、护盾、眩晕等低存在感循环光效。
- 通用范围边框：由代码根据生效格子计算外边界，AI 只生成可平铺边线、角点、端帽和脉冲材质。

范围提示不建议使用“每个格子铺一张覆盖层”的方式。地图格本身、部署覆盖层、攻击范围、建筑范围和路径提示会叠加，逐格铺状态贴图很容易让画面变脏。更稳的方案是代码遍历生效格集合，只在外边界绘制描边；AI 负责生成描边材质，颜色和透明度由代码按类型调整。

### 1.2 第一阶段：少量技能专用主特效

技能专用特效只先做最能表达技能身份的部分，例如真银斩的剑气和命中火花。第一阶段不为每个特殊干员定制攻击范围边框，也不为每个技能单独生成一套范围格覆盖层。

如果某个技能需要显示“攻击范围变大”“重力塔影响范围”“危险预警范围”，优先复用通用范围边框材质，通过 tint、alpha、线宽、脉冲速度、边线噪声和 shader 参数做区分。等通用范围边框管线稳定后，再考虑为少数高辨识度干员增加专属范围风格。

### 1.3 后续技能专用扩展原则

后续为特殊干员做定制时，也应拆成以下几类，而不是直接生成完整范围截图：

- 技能主动作：剑气、火柱、雷弧、爆裂、冲击波等真正体现技能身份的动画。
- 命中反馈：该技能独有的短暂命中特效。
- 残留或持续场：技能结束前留下的轻量循环效果。
- 范围边框风格：只在机制确实需要强辨识度时定制，仍然由代码拼接边界，不生成整块范围图。

## 2. 全局提示词

每一轮都先复制本段，再追加对应批次提示词。

```text
我们要为一个 Godot 俯视塔防游戏生成战斗特效源图。游戏中心是低饱和半卡通地图，角色、怪物和建筑都是卡通化战术奇幻风格。特效需要让玩家快速读出攻击方向、命中范围、伤害类型或状态变化，但不能遮挡单位、路径、血条、部署格和 UI。

特效用途：
- 普通物理命中、法术命中、治疗、减速、眩晕、破甲等小型反馈。
- 远程投射物，例如箭矢、法术弹、狙击轨迹。
- 技能主特效，例如真银斩的剑气和命中火花。
- 范围边框材质，例如可平铺边线、角点、端帽、轻微脉冲。范围几何由代码生成，AI 不直接生成完整范围形状。

整体风格：
- 低饱和半卡通手绘，轻微奇幻，战术读图清晰。
- 和 UI、地图材质、角色、怪物属于同一个游戏，不是写实电影特效，不是照片烟尘，不是 PBR 爆炸，不是高饱和手游霓虹。
- 形状要概括，剪影要清楚，边缘干净，读图优先。远看先读出方向和范围，近看再看到少量手绘能量纹理。
- 使用柔和浅金、冷白、雾蓝、低饱和青蓝、暗红灰、灰紫、灰绿作为点缀；不要大面积纯红、纯蓝、亮紫、荧光绿或浓黑烟雾。
- 特效可以有轻微发光，但发光必须贴近主体，不要铺满整张图，不要形成大面积半透明雾。

网页端生图与抠图硬约束：
- 源图背景必须是纯色 #79C7B6，方便后续批量抠图；不要透明棋盘格，不要渐变背景，不要场景背景。
- 特效主体不要使用接近 #79C7B6 的颜色，尤其边缘、烟雾、光晕不能有青绿色污染。治疗或法术特效需要青蓝时，请偏向更冷的蓝白、深蓝或紫蓝，避免和背景色混在一起。
- 每个资产之间留足 #79C7B6 纯色间距，不要互相接触，不要互相投影。
- 不要让柔光、烟尘、残影铺到整张画布边缘；需要能从纯色背景中干净抠成透明 PNG。
- 输出必须是 PNG 或无损图片源，不要 JPEG 压缩噪点。

游戏内读图硬约束：
- 特效不能看起来像 UI 图标、徽章、按钮、贴纸或地图地块。
- 不要画角色、敌人、建筑、地图格、血条、数字、文字、箭头标签、水印或签名。
- 不要生成整块攻击范围贴图，不要生成每格铺满的状态覆盖层。范围类资产只做外边界描边、角点、端帽或短暂脉冲，具体范围形状由代码计算。
- 不要把投射物画成完整插画。投射物要能在代码里旋转、移动、缩放，形状要沿 X 轴或指定方向清楚。
- 序列帧必须保持同一锚点、同一视角、同一尺寸和同一主体身份；每帧只是时间变化，不要每帧换设计。
- 在 64x64 地图格、72px 单位显示尺寸和 1080p 视口下都要清楚，不能靠细碎粒子才能看懂。

输出要求：
- 静态投射物建议单个源尺寸 256x96 或 256x128。
- 小型命中特效建议 6 帧横向序列，单帧 192x192 或 256x256。
- 技能剑气建议 8 帧横向序列，单帧 384x192 或 512x256。
- 范围边框边线建议 384x64 或 512x64 横向可平铺资产；角点和端帽建议 128x128 或 192x192。
- 每个序列帧从左到右播放：起势、展开、峰值、衰减、消散。帧之间用 #79C7B6 间隔，不画边框线。
- 最终入库资产需要抠成透明 PNG；源图保留在 raw 目录用于回溯。

如果模型倾向画得太写实，请改为：stylized hand-painted cartoon VFX sprite, simplified shapes, clean silhouette, game-ready, no photo smoke, no realistic explosion, no PBR particles。
如果模型倾向画得太亮，请改为：low-saturation tactical fantasy VFX, soft limited glow, readable but restrained, no neon, no pure saturated colors。
如果模型倾向画成 UI 图标，请改为：in-world battle effect sprite, no icon frame, no badge, no button, no emblem, no decorative border。
如果模型倾向让背景难抠，请改为：flat solid chroma key background #79C7B6 only, no background haze, no shadow touching background, effect colors clearly different from the background。
```

## 3. 保存与裁剪约定

- 每轮生成一张源图，建议保存到 `assets/effects/raw/`，命名为 `effect_source_sheet_序号_主题.png`。
- 裁剪后的透明 PNG 建议按用途放到 `assets/effects/common/`、`assets/effects/projectiles/`、`assets/effects/slash/`、`assets/effects/range/`。
- 静态资产使用资产 key 命名，例如 `projectile_arrow.png`。
- 序列帧使用 `_strip` 后缀，例如 `impact_physical_small_strip.png`，并保持横向等宽帧。
- 每张图内的资产按“从左到右、从上到下”的顺序裁剪。序列帧行内按从左到右播放。
- 抠图时把 `#79C7B6` 转为透明。检查边缘不能残留青绿色描边；必要时重新生成，而不是用过强羽化把特效边缘磨糊。
- 如果某轮出现背景不纯、假透明棋盘格、写实烟尘、强霓虹、厚 UI 外框、文字、角色、地图格或帧间设计不一致，直接废弃该轮，使用第 21 节纠偏提示重新生成。

## 4. 资产目标清单

第一阶段优先覆盖“命中反馈、投射物、通用范围边框、真银斩主特效”四类。命名是建议目标，具体接入可以按当前 Godot 资源注册方式调整。

| 资产 key | 建议路径 | 用途 | 视觉目标 |
|---|---|---|---|
| `impact_physical_small_strip` | `assets/effects/common/impact_physical_small_strip.png` | 普通物理命中 | 小型冷白/浅金冲击火花 |
| `impact_arts_small_strip` | `assets/effects/common/impact_arts_small_strip.png` | 法术命中 | 小型蓝白/紫蓝能量爆散 |
| `impact_heal_small_strip` | `assets/effects/common/impact_heal_small_strip.png` | 治疗反馈 | 柔和绿白/金白上升脉冲，避免背景色 |
| `impact_true_damage_small_strip` | `assets/effects/common/impact_true_damage_small_strip.png` | 真实伤害或重击 | 冷白裂光与短促星芒 |
| `projectile_arrow` | `assets/effects/projectiles/projectile_arrow.png` | 弓弩/狙击投射物 | 细长箭矢或弹道光 |
| `projectile_arts_orb` | `assets/effects/projectiles/projectile_arts_orb.png` | 法术弹 | 小型蓝白能量球和短尾迹 |
| `projectile_heavy_shot` | `assets/effects/projectiles/projectile_heavy_shot.png` | 重型射击 | 暗金/冷白弹头与短尾迹 |
| `projectile_fire_orb` | `assets/effects/projectiles/projectile_fire_orb.png` | 火焰/爆裂投射物 | 低饱和琥珀火团 |
| `truesilver_slash_wave_strip` | `assets/effects/slash/truesilver_slash_wave_strip.png` | 真银斩主剑气 | 长条冷白银灰风刃，方向明确 |
| `truesilver_hit_spark_strip` | `assets/effects/slash/truesilver_hit_spark_strip.png` | 真银斩命中 | 银白碎裂火花和短弧线 |
| `range_outline_edge_base` | `assets/effects/range/range_outline_edge_base.png` | 通用范围外边界边线 | 横向可平铺中性银白边线，代码 tint |
| `range_outline_edge_pulse` | `assets/effects/range/range_outline_edge_pulse.png` | 通用范围边线脉冲 | 可平铺短循环光脉冲 |
| `range_outline_corner_base` | `assets/effects/range/range_outline_corner_base.png` | 通用范围角点 | 可旋转/翻转的 L 型角连接 |
| `range_outline_cap_base` | `assets/effects/range/range_outline_cap_base.png` | 通用范围端帽 | 边线断点或短边收口 |
| `range_outline_node_glow_strip` | `assets/effects/range/range_outline_node_glow_strip.png` | 边界节点闪光 | 轻量角点/节点循环光 |

## 5. 第 1 轮：通用命中特效

保存源图为：`effect_source_sheet_01_common_impacts.png`

裁剪顺序：4 行，每行 6 帧横向序列。

1. `impact_physical_small_strip`
2. `impact_arts_small_strip`
3. `impact_heal_small_strip`
4. `impact_true_damage_small_strip`

```text
请生成一张战斗命中特效序列帧源图，纯色背景 #79C7B6。画面包含 4 行特效，每行是 6 帧横向序列，从左到右播放。每帧建议 192x192 或 256x256，帧与帧之间留足 #79C7B6 间隔，不画边框线。最终会抠成透明 PNG，并在 Godot 中作为短暂命中特效播放。不要文字、数字、角色、敌人、地图格、UI 图标、徽章、按钮、照片烟尘。

1. impact_physical_small_strip：普通物理命中。冷白的小型冲击火花，少量碎线和短弧，第一帧很小，第三帧达到峰值，第六帧基本消散。不要大爆炸，不要血液，不要写实火花。
2. impact_arts_small_strip：法术命中。低饱和蓝白/紫蓝能量爆散，小型魔法碎光和短暂环形波。不要大魔法阵，不要霓虹蓝，不要贴近 #79C7B6 的青绿色边缘。
3. impact_heal_small_strip：治疗反馈。柔和金白与很低饱和灰绿光点向上或向外扩散，温和、干净、正向。不要纯绿荧光，不要医疗 UI 图标，不要十字按钮，不要和背景 #79C7B6 混色。
4. impact_true_damage_small_strip：真实伤害或重击反馈。冷白裂光、银灰短线、少量暗红灰冲击点，短促尖锐但不血腥。不要巨大红色爆炸，不要黑烟，不要照片碎片。

四行特效必须同一画风、同一相机视角、同一中心锚点。所有帧中心对齐，不能每帧漂移。风格是 stylized hand-painted cartoon VFX sprite, clean edges, low-saturation tactical fantasy, readable at small size, no realistic particles, no UI icon。
```

## 6. 第 2 轮：基础投射物

保存源图为：`effect_source_sheet_02_projectiles.png`

裁剪顺序：

1. `projectile_arrow`
2. `projectile_arts_orb`
3. `projectile_heavy_shot`
4. `projectile_fire_orb`

```text
请生成一张战斗投射物源图，纯色背景 #79C7B6，包含 4 个独立投射物 sprite，按从左到右排列。每个投射物建议 256x96 或 256x128，主体沿 X 轴朝右，方便在 Godot 中旋转到飞行方向。不要文字、数字、角色、敌人、地图背景、UI 边框、按钮、徽章、完整插画。

1. projectile_arrow：弓弩/狙击投射物。细长箭矢或冷白弹道光，右侧为尖端，左侧有短而克制的运动尾迹。颜色冷白、浅金、灰蓝。不要真实枪弹，不要巨大箭头 UI，不要过长拖尾。
2. projectile_arts_orb：法术弹。小型蓝白/紫蓝能量球，右侧运动方向清楚，左侧短尾迹。不要使用接近 #79C7B6 的青绿色边缘，不要大魔法阵。
3. projectile_heavy_shot：重型射击。暗金或冷白弹头，轻微压缩空气弧线，厚重但小巧。不要写实金属子弹，不要爆炸云。
4. projectile_fire_orb：火焰/爆裂投射物。低饱和琥珀火团和短尾火舌，手绘卡通感。不要高饱和橙红，不要真实火焰照片，不要大面积烟。

每个投射物都必须是独立透明 sprite 的源图，边缘干净，尾迹不能接触画布边缘。主体大小统一，适合代码移动、旋转、缩放。风格是 stylized cartoon projectile VFX, game-ready, restrained glow, clean silhouette, no UI icon。
```

## 7. 第 3 轮：真银斩与剑气特效

保存源图为：`effect_source_sheet_03_truesilver_slash.png`

裁剪顺序：2 行，第一行为 8 帧横向序列，第二行为 6 帧横向序列。

1. `truesilver_slash_wave_strip`
2. `truesilver_hit_spark_strip`

```text
请生成一张真银斩/剑气特效源图，纯色背景 #79C7B6。画面包含 2 行特效：第 1 行是 8 帧横向剑气序列，第 2 行是 6 帧横向命中火花序列。帧与帧之间留足纯色背景，不画边框线。不要文字、数字、角色、敌人、地图格、攻击范围格、UI 图标、徽章、按钮。

1. truesilver_slash_wave_strip：真银斩主剑气。横向朝右的长条银白风刃，冷白、银灰、少量雾蓝，形状像快速斩出的弧形剑气。第 1-2 帧从细线起势，第 3-5 帧展开到峰值，第 6-8 帧拖尾并消散。建议单帧 384x192 或 512x256。不要做成巨大实体刀、角色武器、白色矩形光条或写实风暴。
2. truesilver_hit_spark_strip：真银斩命中火花。银白短弧、碎光和小型冲击裂线，从中心爆开后快速消散。建议单帧 192x192 或 256x256。不要血液，不要大爆炸，不要真实金属火花。

两种资产必须同一套银白冷灰风格，低饱和、干净、锋利但不过亮。真银斩第一阶段只做技能主动作和命中反馈；攻击范围边界先复用第 8 节的通用范围边框，并由代码 tint 成偏银白的技能态。保持 stylized tactical fantasy slash VFX, clean chroma key background, no realistic smoke, no neon, readable over dark map tiles。
```

## 8. 第 4 轮：通用范围边框材质

保存源图为：`effect_source_sheet_04_range_outlines.png`

裁剪顺序：

1. `range_outline_edge_base`
2. `range_outline_edge_pulse`
3. `range_outline_corner_base`
4. `range_outline_cap_base`
5. `range_outline_node_glow_strip`

```text
请生成一张通用范围边框材质源图，纯色背景 #79C7B6。这些资产不会铺满每个地图格，而是由 Godot 代码根据一组生效格子的外边界拼接成范围描边。请只生成边线、角点、端帽和小节点光，不要生成完整攻击范围形状，不要生成单格覆盖层，不要画地图格底图。不要文字、数字、箭头、角色、敌人、建筑、UI 按钮、厚边框。

1. range_outline_edge_base：通用范围外边界横向边线。建议 512x64，主体是一条细长、低饱和、可平铺的银白/雾蓝能量线，左右两端必须能无缝拼接。它会被代码旋转到上下左右四个方向，并按范围类型 tint 成攻击增益、重力、危险预警或技能范围。不要箭头，不要文字，不要粗实线，不要明显端点。
2. range_outline_edge_pulse：通用范围边线脉冲。建议 8 帧横向序列，每帧 512x64，和 edge_base 同一位置、同一粗细，只表现一段轻微流光沿边线移动。左右仍然需要可平铺。不要整条同时强闪，不要霓虹，不要高饱和。
3. range_outline_corner_base：90 度外边界角点。建议 192x192，L 型薄能量线，线宽和 edge_base 一致，可旋转或翻转成四个角。角点连接要干净，不要大装饰结，不要 UI 方框角标。
4. range_outline_cap_base：边线端帽。建议 192x96 或 192x128，用于短边、断点或非闭合提示的收口，形状轻薄，能和 edge_base 对齐。不要箭头头部，不要按钮端点。
5. range_outline_node_glow_strip：边界节点小光。建议 6 帧横向序列，每帧 128x128，用于角点或关键节点的轻微呼吸闪光。光点要小，低饱和，不能遮住地图内容。

整体颜色请以中性冷白、银灰、雾蓝为主，方便代码统一调色。不要做成重力塔专属、真银斩专属或某个干员专属；第一阶段必须足够通用。保持 tileable transparent range outline material, clean chroma key background, thin readable border, low-saturation tactical fantasy, no full-area overlay, no UI frame。
```

## 9. 第 5 轮：可选持续类光效

保存源图为：`effect_source_sheet_05_looping_auras.png`

裁剪顺序：4 行，每行 8 帧横向序列。

1. `buff_attack_aura_strip`
2. `debuff_fragile_aura_strip`
3. `shield_absorb_aura_strip`
4. `stun_star_small_strip`

```text
请生成一张持续类状态特效源图，纯色背景 #79C7B6。画面包含 4 行特效，每行是 8 帧横向循环序列。每帧建议 192x192 或 256x256，最终会叠在单位脚下或身上，不能遮挡角色主体。不要文字、数字、角色、敌人、地图格、UI 图标、徽章、按钮。

1. buff_attack_aura_strip：攻击增益光环。低饱和琥珀和浅金短线围绕中心轻微旋转，力量感克制。不要火焰爆炸，不要太阳图标。
2. debuff_fragile_aura_strip：易伤/虚弱光环。灰紫和暗红灰碎线轻微收缩，表现不稳定。不要血液，不要骷髅图标，不要黑雾铺满。
3. shield_absorb_aura_strip：护盾吸收光。冷白和雾蓝的薄弧护盾片段，间歇闪烁。不要完整大泡泡，不要高亮蓝罩住整个角色。
4. stun_star_small_strip：眩晕小星。低饱和浅金/白色小星点绕中心短暂旋转，卡通但不幼稚。不要表情符号，不要文字，不要大 UI 标记。

持续类光效必须低存在感，可以循环播放，不抢夺战斗主体。保持 clean transparent sprite loop, stable center anchor, low-saturation tactical fantasy, no neon, no UI icon。
```

## 10. 当前剩余特效需求盘点

本节基于当前 `data/units.json`、`data/enemies.json` 和 `scripts/combat/skills/`、`scripts/enemy/` 中的实际机制整理。旧文档或技能描述可能落后于实现，后续接入前以代码和数据为准。

已经完成第一步的部分：

- 通用受击：物理、法术、真实伤害已切到透明序列帧命中特效，并且播放时跟随受击目标。
- 通用投射物：干员和敌人的远程攻击已能使用生成的投射物贴图。
- 真银斩：已有主剑气和命中火花的第一版接入。

仍然缺口最大的部分不是“再生成更多命中火花”，而是技能状态、范围提示、持续场、专属主特效和 Boss/敌人特殊行为。

### 10.1 已有资产但还需要实装或补齐接入

| 资产或系统 | 当前状态 | 需要接入的位置 | 优先级 |
|---|---|---|---|
| `heal_tick_small_strip` / `impact_heal_small_strip` | 小型治疗已接 `UnitActor.receive_heal()`；大治疗反馈仍可后续区分 | 高额治疗、技能启动治疗、建筑/敌方治疗入口 | P2 |
| `buff_attack_aura_strip` | 已接通用攻击强化；过载/连射类仍可继续复用或做专属 | 攻击力提升、过载、连射、多目标攻击等技能激活期间 | P2 |
| `debuff_fragile_aura_strip` | 已接敌人易伤状态 | 后续可扩展到更多削弱状态的 tint / 尺寸差异 | P3 |
| `shield_absorb_aura_strip` / `barrier_guard_loop_strip` | 已接敌方护盾吸收、干员屏障/减伤持续态 | 年、森蚺等防御类技能可继续复用或加专属循环 | P2 |
| `stun_star_small_strip` | 已接敌人眩晕 | 后续如果单位也会眩晕，再补单位入口 | P3 |
| `range_outline_*` | 已有素材，尚未做范围描边管线 | 技能扩大范围、重力/减速场、Boss 范围预警、建筑影响范围 | P1 |
| `projectile_fire_orb`、`projectile_heavy_shot` | 重型弹已用于 Boss；火焰弹和部分技能弹道仍可细分 | 火山/灼地/爆裂炮击、特殊远程、连射技能 | P2 |

范围边线脉冲沿用当前资产名 `range_outline_edge_pulse.png`。它虽然是序列帧资产，但不再额外加 `_strip`，避免和已经导入的文件名不一致。

### 10.2 通用机制级缺口

| 机制 | 当前视觉问题 | 推荐视觉资产 | 接入建议 |
|---|---|---|---|
| 技能启动/结束 | 现在主要靠数值和日志，玩家不容易确认技能已开启 | 小型 `skill_cast_flash_strip`、`skill_end_fade_strip` | `UnitSkillBehavior.start_skill()` / `_on_skill_start()` 后统一触发，再允许专属覆盖 |
| 技能持续态 | 多数强化技能没有持续状态提示 | 低存在感脚下环、武器光、身体边缘光 | 给 `UnitActor` 增加可绑定的 loop effect 槽位，技能结束时清理 |
| 治疗与自回复 | `receive_heal()` 只改血条 | `impact_heal_small_strip`、`heal_tick_small_strip` | 治疗量较小的 tick 可以节流，避免每秒多次闪烁 |
| 护盾/屏障/减伤 | 盾量和屏障只在数值逻辑中存在 | `shield_absorb_aura_strip`、短促护盾受击闪 | 敌人护盾和干员屏障最好共用同一接口，只通过 tint 区分阵营 |
| 减速/束缚 | 敌人速度状态没有可见反馈 | `slow_bind_snare_strip`、脚下淡蓝/灰白束缚线 | `apply_move_speed_multiplier()` 和 `apply_bind()` 可共用低强度循环特效 |
| 眩晕 | 已有素材但未挂到状态 | `stun_star_small_strip` | `apply_stun()` 创建，状态过期销毁 |
| 防御/法抗削减 | 削抗和破甲没有读图 | `resistance_shred_mark_strip`、`armor_break_mark_strip` | 接 `apply_defense_shred()`、`apply_resistance_shred()` |
| 易伤/削弱 | 只影响伤害计算 | `debuff_fragile_aura_strip` | 易伤、破甲、削抗先用通用低存在感标记，不单独做复杂积累态 |
| DOT/灼烧/精神持续伤害 | 周期伤害只显示通用受击 | `burn_dot_small_strip`、`psychic_dot_aura_strip` | `_tick_dot_effects()` 默认每秒结算一次，特效也按低频 tick 播放，不要生成高频大爆点 |
| 推拉/位移 | 敌人移动了，但缺少力的方向 | `push_pull_streak_strip` | `apply_push()` / `apply_relocate_to_cell()` 触发方向性拖尾 |
| 范围/领域 | 扩大范围、减速场、Boss AOE 没有边界 | 通用范围描边材质 | 统一做“按格集合计算外边界”的描边渲染，不铺满格子 |
| 死亡爆炸/分裂召唤 | 高能源石虫与分裂源石虫缺少预期反馈 | `originium_slug_death_burst_strip`、`originium_slug_split_puff_strip`、`enemy_death_spawn_puff_strip` | `apply_defeat_effects()` 前后触发，爆炸范围可短暂显示边框 |

### 10.3 干员技能个性化缺口

优先级按“玩家是否需要靠视觉判断范围/目标/危险”和“技能身份是否强”排序。第一轮不建议为所有技能做专属资源；能用通用光效表达的先复用通用资产。

| 干员/技能 | 当前机制 | 建议特效 | 优先级 |
|---|---|---|---|
| 银灰 / 真银斩 | 范围扩大、多目标、剑气 | 主剑气已接入；还缺技能范围银白描边和启动蓄势 | P1 |
| 菲亚梅塔 / “你须愧悔” | 大范围炮击、溅射 | 重型炮弹、目标点爆裂、溅射半径边缘脉冲 | P1 |
| 涤火杰西卡 / 饱和迸射 | 炮击弹药、溅射、眩晕 | 炮口闪、炮弹、落点爆炸、眩晕小星 | P1 |
| 伊芙利特 / 灼地 | 直线灼烧、周期法伤、削抗 | 地面火线/灼烧带、线形范围边框、削抗烙印 | P1 |
| 澄闪 / 澄净闪耀 | 全图随机雷击、减速 | 从上方落雷、目标小电弧、短暂减速环 | P1 |
| 逻各斯 / 殁亡 | 低血斩杀、溢出转移 | 暗紫/冷白执行裂光、转移弧线 | P1 |
| 妮芙 / 心防溃决 | 多目标攻击，命中附加纯 DOT | 复用通用精神 DOT 标记，不做额外积累/爆发专属表现 | P3 |
| 锏 / 归于宁静 | 多段斩击、拉拽、终结重击 | 环形多段斩线、拉拽牵引线、终结十字斩 | P1 |
| 史尔特尔 / 黄昏 | 法伤决战、范围扩大、持续掉血 | 红橙低饱和身光、命中火花、生命流失暗纹 | P1 |
| 塞雷娅 / 钙质化 | 治疗、减速、法术易伤 | 金白钙化领域边框、治疗脉冲、敌方结晶减速纹 | P1 |
| 黍 / 离离枯荣 | 领域治疗庇护、敌人离场回拉 | 农作/生长领域光环、回拉线 | P1 |
| 异客 / 辉煌裂片 | 连锁法术、推开 | 目标间蓝白电弧、轻量推力冲击线 | P2 |
| 娜仁图亚 / 吞日 | 投射物返程、沿返程路径命中、减速 | 回旋/返程弹道、路径残影、目标减速环 | P2 |
| 莱伊 / “得见光芒” | 弹药、高倍率、束缚 | 瞄准标记、束缚光线/脚下钉住效果 | P2 |
| 提丰 / “永恒狩猎” | 标记目标、随机额外打击、眩晕 | 标记环、追猎弹道、短促眩晕闪 | P2 |
| 维什戴尔 / 饱和复仇 | 多目标，后半段过载连击 | 过载枪火、目标额外连击火花、后半段强化身光 | P2 |
| 能天使 / 过载模式 | 五连射 | 连射枪口闪、五段短弹道、命中连闪 | P2 |
| 艾雅法拉 / 火山 | 永久过载、命中周围法术伤害 | 小范围火山爆点、法术余波环 | P2 |
| 斥罪 / 披荆斩棘 | 屏障、受击法术反击 | 屏障环、反击刺状魔法火花 | P2 |
| 左乐 / 行险 | 损血、屏障、低血增伤 | 血量代价暗红闪、屏障吸收、低血锐化身光 | P2 |
| 山 / 横扫架势 | 自回复、强化挡线、攻击被阻挡敌人 | 横扫近战弧、自回复脉冲、脚下稳态光 | P3 |
| 星熊 / 荆棘 | 受击回复和反伤 | 护盾反弹星芒、真实伤害反击线 | P3 |
| 年 / 铁御 | 加防回血、阻挡提升 | 防御姿态护盾片、回血小脉冲 | P3 |
| 煌 / 链锯延伸模块 | 阻挡提升，攻击被阻挡敌人 | 链锯短弧、阻挡态脚下加固线 | P3 |
| 通用攻击强化类 | 攻击倍率提升 | `buff_attack_aura_strip` 即可 | P3 |

### 10.4 敌人与 Boss 特效缺口

| 敌人/机制 | 当前机制 | 建议特效 | 优先级 |
|---|---|---|---|
| 弩手、术师、高阶术师、法术无人机 | 已有远程投射物，但都是通用读图 | 弩矢、法术球、无人机小型能量弹可继续区分颜色和形状 | P2 |
| 持盾精锐 | 有护盾数值 | 身前护盾片、护盾吸收闪 | P1 |
| 高能源石虫 | 死亡范围法伤 | 死亡前短闪、低饱和源石爆裂、范围边界瞬闪 | P1 |
| 分裂源石虫 | 死亡召唤小源石虫 | 分裂烟尘、生成点小裂缝/孵化闪 | P1 |
| 拆路类敌人 | 会攻击路径建筑 | 重击地面/建筑的钝击冲击、短暂碎石 | P2 |
| Boss 转阶段 | 无敌等待后切阶段 | 转阶段蓄势环、身体轮廓光、阶段完成冲击波 | P1 |
| Boss 入阶段范围伤害 | 范围伤害只结算，无预警 | 阶段 AOE 预警描边、爆发环、地面裂光 | P1 |
| 奶龙酋长 | 两阶段，厚鳞到暴怒，远程重击 | 厚鳞护甲闪、暴怒火橙冲击、重型弹 | P2 |
| 爱国者 | 两姿态，毁灭姿态范围更大 | 行军姿态冷铁压迫光、毁灭姿态冲击波/战戟震地 | P2 |

### 10.5 建议实现顺序

1. 已接入已有通用素材：治疗、眩晕、护盾/屏障、攻击增益、易伤/削抗、DOT、推拉、死亡爆裂和生成烟尘。
2. 已接入一批 P1 干员/Boss 主特效：菲亚梅塔、杰西卡、伊芙利特、澄闪、逻各斯、锏、史尔特尔、塞雷娅、黍、Boss 转阶段/阶段 AOE。
3. 下一步优先做范围描边管线：技能扩大范围、领域、Boss 预警、建筑影响范围都走同一个外边界系统。
4. 再补 P2/P3 个性化表现：连锁、返程弹道、束缚瞄准、连射、过载、火山、横扫、防御姿态。
5. 对没有真实场景对象的机制，只做光环或瞬时反馈，不额外生成独立标记物。

## 11. 第 6 轮：通用状态、领域与死亡反馈

保存源图为：`effect_source_sheet_06_common_status_fields.png`

裁剪顺序：8 行，每行 6 或 8 帧横向序列。

1. `heal_tick_small_strip`
2. `slow_bind_snare_strip`
3. `resistance_shred_mark_strip`
4. `armor_break_mark_strip`
5. `psychic_dot_aura_strip`
6. `burn_dot_small_strip`
7. `push_pull_streak_strip`
8. `enemy_death_spawn_puff_strip`

```text
请生成一张通用状态、领域和死亡反馈特效源图，纯色背景 #79C7B6。画面包含 8 行特效，每行是横向序列帧，从左到右播放。每帧建议 192x192 或 256x256，帧之间留足纯色背景。不要文字、数字、角色、敌人、建筑、地图格、UI 图标、徽章、按钮。

1. heal_tick_small_strip：小型治疗 tick。柔和金白与低饱和灰绿光点上升，适合频繁播放，不能太亮。
2. slow_bind_snare_strip：减速/束缚。脚下淡蓝白与灰紫细线短暂收紧，表现行动受限，不要大冰块，不要荧光青绿。
3. resistance_shred_mark_strip：法抗削减。小型紫蓝裂纹和碎光贴在目标身上，低饱和，不要大魔法阵。
4. armor_break_mark_strip：防御削减。银灰碎片和浅金裂线短促破开，不要写实金属碎片，不要 UI 盾牌图标。
5. psychic_dot_aura_strip：精神/法术持续伤害。暗紫灰与冷白细裂纹缓慢闪动，贴近目标脚下或身上，作为普通 DOT 标记，不要表现成复杂积累或爆发机制。
6. burn_dot_small_strip：灼烧 DOT。低饱和琥珀小火舌和热浪，适合叠在敌人身上循环，不要真实火焰照片。
7. push_pull_streak_strip：推拉/位移拖尾。横向方向性速度线，冷白/灰蓝，可旋转到推拉方向。不要箭头 UI。
8. enemy_death_spawn_puff_strip：死亡爆裂或分裂召唤烟尘。小型源石灰尘、碎光和短暂裂缝，卡通手绘，不能遮挡大范围。

所有资产要保持低饱和半卡通战术奇幻风格。持续类特效必须低存在感，短促反馈必须中心锚点稳定。背景固定 #79C7B6，主体颜色不要接近背景色，边缘干净，方便抠图。
```

## 12. 第 7 轮：高优先级干员专属攻击特效

保存源图为：`effect_source_sheet_07_operator_priority_attacks.png`

裁剪顺序：8 行，每行 6 或 8 帧横向序列。

1. `fiammetta_shell_explosion_strip`
2. `jessica_shell_explosion_strip`
3. `ifrit_flame_line_strip`
4. `goldenglow_lightning_strike_strip`
5. `logos_execute_crack_strip`
6. `logos_transfer_arc_strip`
7. `surtr_twilight_hit_flare_strip`
8. `degenbrecher_multi_slash_pull_strip`

```text
请生成一张高优先级干员专属攻击特效源图，纯色背景 #79C7B6。画面包含 8 行特效，每行是横向序列帧。每行保持同一锚点、同一主体身份，不要每帧换设计。不要画干员、敌人、建筑、地图格、技能图标、文字或 UI。

1. fiammetta_shell_explosion_strip：菲亚梅塔炮击落点爆炸。低饱和琥珀、灰白冲击波和少量碎片，半径读图清楚，不要真实火球和黑烟。
2. jessica_shell_explosion_strip：涤火杰西卡炮击爆点。更紧凑的冷白/浅金炮击冲击，带短促震荡环，可用于眩晕炮击。
3. ifrit_flame_line_strip：伊芙利特直线灼地。横向地面火线，低饱和橙金和热浪，适合代码拉伸到多格长度；不要铺满整张，不要真实火焰。
4. goldenglow_lightning_strike_strip：澄闪落雷。竖向冷白/淡紫雷击，从上到下击中目标，小型冲击环，不要高饱和霓虹蓝。
5. logos_execute_crack_strip：逻各斯低血斩杀。暗紫灰和冷白裂光从目标中心切开，干净、短促、肃杀，不要血腥。
6. logos_transfer_arc_strip：逻各斯溢出转移。横向冷白/紫蓝细弧，适合在两个目标之间拉伸和旋转，不要粗激光。
7. surtr_twilight_hit_flare_strip：史尔特尔黄昏命中。低饱和红橙与冷白火花在目标中心短促爆开，危险但不要真实火焰和大面积黑烟。
8. degenbrecher_multi_slash_pull_strip：锏多段斩击与牵引。环形/半环银灰斩线带向中心收束的力感，适合半径内多目标打击。

整体必须是 stylized hand-painted cartoon VFX sprite，低饱和、边缘清晰、读图优先。不要写实爆炸、照片烟尘、PBR 火花、大面积黑烟或纯色霓虹。
```

## 13. 第 8 轮：领域、屏障与特殊干员持续效果

保存源图为：`effect_source_sheet_08_operator_fields_barriers.png`

裁剪保留顺序：6 行，每行 8 帧横向循环序列。上一版中 `surtr_twilight_ground_heat_strip` 和 `shu_seed_mark_strip` 容易表现不存在的地面/种子对象，当前机制不需要，后续不再生成。

1. `surtr_twilight_aura_strip`
2. `saria_calcification_field_strip`
3. `shu_growth_aura_strip`
4. `barrier_guard_loop_strip`
5. `counter_thorn_spark_strip`
6. `mark_target_lock_strip`

```text
请生成一张领域、屏障和特殊干员持续效果源图，纯色背景 #79C7B6。画面包含 6 行循环序列帧，每行 8 帧，从左到右循环。它们会叠在单位、敌人或范围边界上，必须低存在感，不能遮住角色、血条或地图路径。不要文字、角色、敌人、建筑、地图格、UI 图标。

1. surtr_twilight_aura_strip：史尔特尔黄昏身光。低饱和红橙与暗金火焰轮廓，危险但克制，不要真实火焰。
2. saria_calcification_field_strip：塞雷娅钙质化领域。以半径范围边缘为主体的细圆环/细边界，内部基本透明；金白、米白结晶脉冲只沿边缘出现，不能铺成一整块奶油色覆盖层。
3. shu_growth_aura_strip：黍生长领域光环。半径两格范围的细边缘圆环，开启技能后出现在技能范围内；低饱和金绿、白色细苗/稻穗点缀只沿边缘分布，不要生成单独种子、作物实体、地块贴图或满铺光雾。
4. barrier_guard_loop_strip：通用屏障/防御姿态。冷白、银灰、雾蓝薄盾片循环闪烁，适合左乐、斥罪、年、星熊、护盾敌。
5. counter_thorn_spark_strip：反击荆棘/刺状反伤。短促银白/暗红灰刺线从中心弹出，不能血腥。
6. mark_target_lock_strip：狙击标记/追猎标记。细薄目标锁定环，低饱和浅金/冷白，不要 UI 准星图标，不要文字。

持续效果要能循环，亮度波动小，中心锚点稳定。范围类资产可以是完整圆形边缘光环，也可以是边界节点；内部必须保持透明，不要生成完整范围地块覆盖。
```

## 14. 第 9 轮：敌人与 Boss 专属特效

保存源图为：`effect_source_sheet_09_enemy_boss_effects.png`

裁剪顺序：8 行，每行 6 或 8 帧横向序列；静态投射物可单独裁剪。

1. `shieldguard_shield_absorb_strip`
2. `originium_slug_death_burst_strip`
3. `originium_slug_split_puff_strip`
4. `demolisher_heavy_hit_strip`
5. `boss_phase_transition_strip`
6. `boss_phase_enter_area_burst_strip`
7. `projectile_milk_dragon_rage`
8. `patriot_destroyer_shockwave_strip`

```text
请生成一张敌人与 Boss 专属特效源图，纯色背景 #79C7B6。画面包含护盾、死亡爆裂、分裂召唤、拆路重击、Boss 转阶段、Boss 入阶段范围爆发、Boss 重型投射物和冲击波。不要画完整敌人、Boss、建筑、地图格、UI、文字、血条或技能图标。

1. shieldguard_shield_absorb_strip：持盾精锐护盾吸收。身前半弧薄盾片被击中闪烁，冷白/雾蓝/银灰，低饱和。
2. originium_slug_death_burst_strip：高能源石虫死亡爆裂。小型源石蓝紫/灰白能量爆开，范围清楚，不要真实爆炸。
3. originium_slug_split_puff_strip：分裂源石虫召唤烟尘。两三个小型生成点烟尘和裂光，卡通干净，不要画出具体小怪。
4. demolisher_heavy_hit_strip：拆路敌人重击建筑/地面。钝重冲击、碎石和灰白冲击线，不要大爆炸。
5. boss_phase_transition_strip：Boss 转阶段蓄势。围绕中心的低饱和能量环逐渐收束再爆开，可叠在 Boss 身上。
6. boss_phase_enter_area_burst_strip：Boss 入阶段范围爆发。地面圆形/方形冲击环和裂光，适合配合范围描边预警。
7. projectile_milk_dragon_rage：奶龙暴怒阶段重型投射物。低饱和橙金厚重能量弹，朝右，短尾迹。
8. patriot_destroyer_shockwave_strip：爱国者毁灭姿态冲击波。冷铁银灰与暗红灰地面震波，厚重、压迫但不遮屏。

Boss 特效要比普通敌人更有重量，但仍然保持战术读图：范围边缘清楚，峰值帧不能覆盖整屏。风格必须与当前半卡通地图、角色和 UI 匹配，不要写实电影级烟尘。
```

## 15. 第 10 轮：范围描边、技能启动与预警

保存源图为：`effect_source_sheet_10_range_cast_warnings.png`

裁剪顺序：8 行。第 1、2 行为 6 帧横向序列；第 3 到 8 行为可循环边线/节点素材，建议 8 帧横向序列。范围几何仍由代码按格集合生成，AI 不画完整范围图。

1. `skill_cast_flash_strip`
2. `skill_end_fade_strip`
3. `skill_range_warning_edge_pulse_strip`
4. `skill_range_warning_corner_pulse_strip`
5. `aoe_warning_edge_pulse_strip`
6. `field_boundary_node_pulse_strip`
7. `gravity_field_edge_pulse_strip`
8. `building_aura_edge_pulse_strip`

```text
请生成一张范围描边、技能启动和危险预警特效源图，纯色背景 #79C7B6。画面包含 8 行资产，每行横向序列帧，从左到右播放或循环。不要画完整攻击范围，不要画地图格，不要画角色、敌人、建筑、血条、文字或 UI 图标。范围类只做可平铺边线、角点、节点或短脉冲材质，方便代码沿外边界拼接。

1. skill_cast_flash_strip：技能启动小闪。叠在干员身上的短促冷白/浅金脉冲，半卡通手绘，峰值清楚但不遮脸，不要大魔法阵。
2. skill_end_fade_strip：技能结束淡出。低亮度灰白/浅金碎光向内收束后消失，作为状态结束提示，不要爆炸。
3. skill_range_warning_edge_pulse_strip：技能范围边线脉冲。横向细边线，银白/浅金，可平铺，透明感强，不能像 UI 边框或格子填充。
4. skill_range_warning_corner_pulse_strip：技能范围角点脉冲。L 型角连接，能与边线对齐，低饱和浅金/冷白，不要画成完整方框。
5. aoe_warning_edge_pulse_strip：危险 AOE 预警边线。低饱和暗红灰和冷白短脉冲，读出危险但不要高饱和红，不要整块红色覆盖。
6. field_boundary_node_pulse_strip：领域边界节点闪。小型节点光，金白/雾蓝，可放在边界转角或关键点，不能像按钮。
7. gravity_field_edge_pulse_strip：重力/减速场边线。低饱和紫灰/冷白细线，轻微向内收缩感，不能铺满格子。
8. building_aura_edge_pulse_strip：建筑影响范围边线。木石/工程感的浅金灰白细边，克制、稳定，适合防御建筑或辅助建筑范围。

所有范围素材都必须是外边界材质，不是范围地块贴图。边线要细、可重复平铺、中心对齐、亮度波动小。背景固定 #79C7B6，主体颜色不要接近背景色，边缘干净，方便抠图。
```

## 16. 第 11 轮：剩余干员攻击主特效

保存源图为：`effect_source_sheet_11_operator_secondary_attacks.png`

裁剪顺序：8 行。静态投射物可单独裁剪成单帧 PNG；其他行为使用 6 或 8 帧横向序列。

1. `caster_chain_arc_strip`
2. `narantuya_return_projectile`
3. `narantuya_return_path_spark_strip`
4. `ray_bind_shot_projectile`
5. `ray_bind_tether_strip`
6. `typhon_hunt_extra_hit_strip`
7. `wisadel_overload_gunfire_strip`
8. `exusiai_volley_tracer_strip`

```text
请生成一张剩余干员攻击主特效源图，纯色背景 #79C7B6。画面包含 8 行资产，每个资产锚点稳定、方向明确、适合 Godot 俯视塔防中旋转、缩放或跟随目标播放。不要角色、敌人、建筑、地图格、技能图标、文字或 UI。

1. caster_chain_arc_strip：异客连锁法术电弧。横向蓝白/雾紫细弧，适合拉伸到两个敌人之间，不能像粗激光，不要高饱和霓虹蓝。
2. narantuya_return_projectile：娜仁图亚吞日返程投射物。朝右的回旋羽状/日轮弹道，低饱和金红和冷白短尾，不能像 UI 徽章。
3. narantuya_return_path_spark_strip：吞日返程路径命中火花。沿路径短促扫过的金红碎光，横向方向性强，可拉伸，不要整片火焰。
4. ray_bind_shot_projectile：莱伊束缚射击弹。朝右的冷白/浅金狙击弹，细长、稳定、有少量尾迹，不要真实子弹照片。
5. ray_bind_tether_strip：莱伊束缚光线。横向细线和脚下钉住感，淡金/冷白，适合命中后贴在目标脚下或目标与射手之间。
6. typhon_hunt_extra_hit_strip：提丰追猎额外打击。短促冷白/浅金穿刺火花，带一点目标锁定感，但不要画成 UI 准星。
7. wisadel_overload_gunfire_strip：维什戴尔过载枪火。多段短促枪火和冷白碎光，方向朝右，可用于后半段额外连击，不要大爆炸。
8. exusiai_volley_tracer_strip：能天使五连射弹道。五段极短浅金/冷白曳光线，节奏清楚，可连续播放，不能像一条粗光束。

整体为 stylized hand-painted cartoon VFX sprite，低饱和、剪影清楚、边缘干净。不要真实枪火、照片烟尘、PBR 火花、强霓虹或厚重黑烟。
```

## 17. 第 12 轮：持续姿态、自回复与防御特效

保存源图为：`effect_source_sheet_12_operator_stances_recovery.png`

裁剪顺序：8 行，每行 6 或 8 帧横向序列；持续姿态建议 8 帧循环，小型反馈建议 6 帧。

1. `eyja_volcano_burst_strip`
2. `caster_overload_aura_strip`
3. `mountain_sweep_arc_strip`
4. `mountain_recover_pulse_strip`
5. `guard_hold_line_arc_strip`
6. `defender_fortify_loop_strip`
7. `nian_iron_guard_loop_strip`
8. `zuo_le_blood_cost_flash_strip`

```text
请生成一张持续姿态、自回复和防御类干员特效源图，纯色背景 #79C7B6。画面包含 8 行资产，每行横向序列帧。不要角色、敌人、建筑、地图格、UI、文字、图标或完整范围覆盖层。

1. eyja_volcano_burst_strip：艾雅法拉火山命中小范围爆点。低饱和橙金和灰白法术余波，短促、圆心稳定，不要真实火山喷发和黑烟。
2. caster_overload_aura_strip：术师过载持续身光。低饱和紫蓝/冷白细光围绕中心轻微脉冲，适合永久技能，亮度必须克制。
3. mountain_sweep_arc_strip：山横扫近战弧。宽而短的灰白/浅金拳风或扫击弧，贴近地面，适合命中被阻挡敌人，不要像剑气。
4. mountain_recover_pulse_strip：山自回复脉冲。脚下低存在感金白/灰绿恢复光，循环或低频播放，不要接近背景青绿。
5. guard_hold_line_arc_strip：煌链锯延伸短弧。橙金/银灰短斩线，有机械切割感但卡通化，不要真实电锯和飞溅碎片。
6. defender_fortify_loop_strip：防御姿态循环护光。银灰/冷白盾片和脚下稳态线，适合森蚺、年等加防回血技能，不要画盾牌图标。
7. nian_iron_guard_loop_strip：年铁御专属护壁。更厚重的银灰/淡金铁片轮廓，低存在感循环，可叠在单位身上，不遮角色。
8. zuo_le_blood_cost_flash_strip：左乐行险生命代价。暗红灰和冷白短闪，从身体边缘收缩，不血腥，不表现伤口。

持续类必须能循环且不抢眼；短促反馈必须读图明确但峰值不遮挡单位。风格保持低饱和半卡通战术奇幻，不要写实烟尘、照片火焰或纯色霓虹。
```

## 18. 第 13 轮：敌人、投射物与环境补充特效

保存源图为：`effect_source_sheet_13_enemy_projectile_environment.png`

裁剪顺序：8 行。投射物可单帧裁剪；其他使用 6 帧或 8 帧横向序列。

1. `enemy_regen_tick_strip`
2. `enemy_melee_heavy_hit_strip`
3. `projectile_crossbow_bolt`
4. `projectile_enemy_arts_orb`
5. `projectile_drone_arts_orb`
6. `boss_thick_scale_absorb_strip`
7. `boss_rage_cast_flash_strip`
8. `building_repair_heal_pulse_strip`

```text
请生成一张敌人、投射物与环境补充特效源图，纯色背景 #79C7B6。画面包含 8 行资产，适合后续区分普通敌人远程、Boss 状态、建筑修复与敌人自回复。不要完整敌人、Boss、建筑、地图格、血条、UI、文字或图标。

1. enemy_regen_tick_strip：敌人自回复 tick。低饱和暗红灰/灰绿小脉冲，贴在敌人身上，不能像治疗 UI，也不要接近背景色。
2. enemy_melee_heavy_hit_strip：大型近战重击命中。灰白/浅金冲击裂线，适合大剑手和重装敌人近战，不能像爆炸。
3. projectile_crossbow_bolt：弩手箭矢。朝右细长弩箭或浅金曳光，单帧即可，读图清楚，不要真实箭照片。
4. projectile_enemy_arts_orb：敌方术师法术弹。朝右小型紫蓝/冷白能量球，短尾迹，低饱和，不要霓虹球。
5. projectile_drone_arts_orb：法术无人机小能量弹。比术师弹更小更轻，雾蓝/冷白短尾，适合飞行敌人。
6. boss_thick_scale_absorb_strip：奶龙厚鳞形态护甲吸收。橙金/银灰鳞片状短闪，贴在 Boss 身上，表现厚鳞但不要画鳞片贴图。
7. boss_rage_cast_flash_strip：Boss 暴怒或阶段技能启动。低饱和橙红灰和冷白冲击，短促、有重量，不要整屏红光。
8. building_repair_heal_pulse_strip：建筑修复/回复。木石工程感金白脉冲，贴在建筑中心，不能像 UI 加号或按钮。

敌方资产要比干员资产更粗粝一点，但仍是半卡通手绘、边缘干净、读图明确。背景固定 #79C7B6，主体颜色远离背景色，方便批量抠图。
```

## 19. 下一批入库与接入准备

下一批图片到位后，优先按以下顺序处理，避免先裁出一堆暂时没有入口的资产：

1. 先裁第 10 轮范围描边素材，并实现统一的范围边界渲染入口。技能扩大范围、领域和 Boss AOE 预警都应复用同一套拼接逻辑。
2. 再裁第 11 轮攻击主特效。优先接异客连锁、娜仁图亚返程、莱伊束缚、提丰额外打击、维什戴尔过载、能天使五连射。
3. 第 12 轮持续姿态先接通用入口：持续 loop effect、受击/治疗短反馈、技能结束清理。不要为每个技能写重复生命周期逻辑。当前已接入术式过载、山、年/防御姿态、左乐生命代价。
4. 第 13 轮敌人投射物可通过 `data/enemies.json` 的 `projectile_texture_path`、`projectile_visual_length`、`projectile_visual_height` 配置接入；敌人状态反馈继续走 `EnemyActor.play_follow_effect()`。当前已接入弩手/术师/法术无人机投射物、敌人自回复、重型近战命中、建筑修复反馈。
5. 任何新资产如果对应机制尚不存在，先只保留 prompt 和裁剪规范，不预先生成“看起来有机制”的视觉。

建议路径：

| 类型 | 路径 |
|---|---|
| 通用短反馈和状态 | `assets/effects/common/` |
| 干员专属攻击 | `assets/effects/operators/` |
| 持续光环和标记 | `assets/effects/auras/` |
| 敌人和 Boss | `assets/effects/enemies/` |
| 静态投射物 | `assets/effects/projectiles/` |
| 范围描边 | `assets/effects/range/` |
| 源图 | `assets/effects/raw/` |

## 20. 裁剪后入库检查

- 源图必须保留在 `assets/effects/raw/`，最终透明 PNG 再进入功能目录。
- 检查背景是否为统一 `#79C7B6`。如果背景有压缩噪点、渐变、阴影或假透明棋盘格，不要继续裁剪。
- 抠图后分别放在深色平地、山地、水域、角色 sprite、怪物 sprite 上预览。边缘不能出现青绿色残边。
- 把小型命中特效缩到 96px、64px、48px 检查。仍需能读出物理、法术、治疗、重击差异。
- 把范围边框资产沿多个相邻 64x64 地图格的外边界拼接检查。边线和角点必须能对齐，不能挡住单位、建筑、路线和部署覆盖层。
- 把序列帧按目标帧率播放检查。中心锚点不能跳，尺寸不能跳，亮度不能忽明忽暗。
- 真银斩资产要额外检查方向：剑气朝向和命中火花应能组合成同一个技能，而不是两套不同视觉语言。
- 如果使用 Godot 导入，注意关闭不必要的过滤或按项目现有像素/手绘资源导入方式统一配置，避免不同特效清晰度不一致。

## 21. 纠偏提示词

### 21.1 背景不纯或不好抠

```text
请重画为纯色 chroma key 背景，背景固定为 #79C7B6，整张图只有这一种背景色。不要渐变背景，不要透明棋盘格，不要背景烟雾，不要投影落在背景上。特效主体颜色必须和 #79C7B6 明显不同，边缘不能有青绿色污染。
```

### 21.2 太写实或像电影特效

```text
请改为 stylized hand-painted cartoon game VFX sprite，形状概括、剪影清楚、边缘干净，适合 Godot 俯视塔防游戏。不要照片烟尘，不要真实爆炸，不要 PBR 火花，不要高频粒子噪点。
```

### 21.3 太亮或太霓虹

```text
请降低饱和度与亮度，保留特效形状但减少外发光面积。使用低饱和冷白、银灰、雾蓝、柔和琥珀、暗红灰，只保留少量亮点。不要纯蓝、纯红、荧光绿、亮紫或整屏发光。
```

### 21.4 太像 UI 图标

```text
请改为游戏内战斗特效 sprite，不要图标构图，不要徽章，不要圆形按钮，不要边框，不要装饰底板。特效应该像叠在角色、敌人或地图格上的瞬时视觉效果，而不是技能图标。
```

### 21.5 序列帧不一致

```text
请保持每帧同一资产、同一中心锚点、同一视角、同一大小和同一配色。每帧只表现时间变化：起势、展开、峰值、衰减、消散。不要每帧改变设计，不要让主体跳动或漂移。
```

### 21.6 范围边框太厚或像格子覆盖层

```text
请改为只用于外边界拼接的范围描边材质，不要生成完整攻击范围，不要生成单个格子的填充覆盖层，不要大面积半透明块。边线要更细、更低对比，可以平铺，角点和端帽能与边线对齐。它需要提示范围外轮廓，但不能遮挡地图、单位、建筑、血条和路线。
```

### 21.7 特效边缘被抠坏

```text
请减少半透明烟雾和大面积柔光，改用更清晰的手绘形状、短线、弧线和集中光点。主体边缘要清楚，背景保持纯 #79C7B6，方便干净抠成透明 PNG。不要让光晕融入背景。
```

### 21.8 真银斩不够可读

```text
请强化真银斩的方向性和命中反馈：主剑气是横向银白风刃，命中是银白碎裂火花。第一阶段不要生成真银斩专属攻击范围格或完整范围图，范围边界复用通用描边材质并由代码调色。保持低饱和，不要巨大白色光幕，不要真实风暴，不要角色或武器本体。
```

## 附录：运行时特效入口

接入新特效资产时，先确认走哪个入口（原 EFFECT_IMPLEMENTATION_STATUS.md 仅保留此表，逐资产实装状态以代码为准）：

| 入口 | 文件 | 当前用途 |
|---|---|---|
| 通用一次性/循环特效节点 | `scripts/effects/one_shot_effect.gd` | 读取 `texture_path`，支持序列帧、循环、跟随目标、世界坐标、旋转和缩放；跟随目标失效时自动销毁 |
| 干员特效接口 | `scripts/combat/unit_actor.gd` | `spawn_one_shot_effect()`、`play_follow_effect()`、`spawn_world_effect()`、投射物配置透传 |
| 敌人特效接口 | `scripts/enemy/enemy_actor.gd` | 命中、状态、DOT、护盾、死亡、推拉、自回复、Boss/敌人技能反馈 |
| 建筑特效接口 | `scripts/building/building_actor.gd` | 建筑受击、修复反馈 |
| 投射物显示 | `scripts/combat/projectile.gd` | 读取 `texture_path` / `projectile_texture_path` 和尺寸配置，默认按伤害类型选贴图 |
| 通用技能启动/结束 | `scripts/combat/skills/unit_skill_behavior.gd` | 技能成功启动和自然/主动结束时播放短反馈 |
| 地图范围描边 | `scripts/map/map_root_view.gd` | `set_range_outline()` 按格集合计算外边界，并按 style 拼接 `assets/effects/range/` 的边线、角点、节点素材 |
