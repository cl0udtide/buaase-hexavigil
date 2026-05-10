# ART_PIPELINE

## 1. 文档目标

本文件定义 HexaVigil 新版玩法下的美术生产规范、AI prompt 母版、资产命名、验收标准和接入约定。

新版游戏的核心体验是：

- 白天：探索迷雾、处理随机事件、建造临时工事、招募干员、准备阵线。
- 夜晚：在 2D 网格地图上部署单位、阻挡敌人、释放技能、守住核心。
- 局外构筑：每日战斗后从祝福中三选一，逐步形成一局 6 天的构筑路线。

美术目标不是复刻现有商业游戏，而是吸收两类设计经验：

- 爬塔构筑类游戏的“选择感、卡牌感、事件感”。
- 战术塔防类游戏的“单位识别、职业轮廓、部署读图、技能反馈”。

统一视觉方向：

```text
暗色战术奇幻科幻、2D 网格地图、伪 3D 角色与建筑、清晰职业轮廓、低饱和环境、高识别交互色、冷静信息 UI、战斗可读性优先。
```

AI 生成时可以使用“dark tactical tower defense roguelite”“pseudo-3D 2D game asset”等原创描述，不要在 prompt 中写“in the style of Arknights”“in the style of Slay the Spire”等直接仿作表达。

---

## 2. 新版游戏视觉定位

### 2.1 世界观关键词

- 六边警戒据点
- 夜晚入侵
- 核心降落
- 迷雾探索
- 废土补给线
- 临时防线
- 战术干员
- 魔术回路与工程设备共存
- 资源紧张下的阵线选择

### 2.2 画面气质

主游戏画面应该像一张可操作的战术桌面，而不是一张展示插画。

- 地图是 2D 网格，格子、路径、阻挡、核心、刷怪点必须优先可读。
- 单位和建筑是伪 3D 2D 资产，类似小型战术棋子，放在格子上要有体积感。
- UI 是战术终端和肉鸽卡牌的结合：信息密度高，但不拥挤。
- 事件和祝福可以更有叙事感，但不能与战斗 UI 割裂。
- 技能特效要表达强弱和类型，但不能遮挡血条、攻击范围、敌人路径和部署格。

### 2.3 阶段视觉差异

| 游戏阶段 | 视觉关键词 | 美术重点 |
|---|---|---|
| 主菜单 | 冷启动、警戒、据点系统上线 | 核心、地图轮廓、夜色压迫 |
| 白天探索 | 可规划、资源紧张、局部安全 | 迷雾、资源点、事件点、建造提示 |
| 招募商店 | 选择、稀缺、职业对比 | 单位头像、价格、职业色、技能图标 |
| 夜晚战斗 | 高压、路径、阻挡、技能窗口 | 角色动画、敌人轮廓、弹道、血条 |
| 祝福三选一 | 构筑成长、奖励、下一天准备 | 祝福卡插画、稀有度、效果图标 |
| 结算 | 战果、失败原因、下一轮动机 | 核心状态、统计图标、胜败画面 |

---

## 3. 工程规格

### 3.1 屏幕与地图

| 项目 | 规格 |
|---|---|
| Godot 版本 | 4.6 |
| 主游戏视口 | `1280x720` |
| 主地图设计 | `30x30` 网格 |
| 当前战斗沙箱 | `12x7` 网格 |
| 逻辑格子 | `64px` |
| 中心初始可见区域 | `5x5` |
| 核心位置 | 主地图中心；沙箱当前为 `Vector2i(10, 3)` |
| 当前默认出怪口 | 主地图角落；沙箱当前为左侧 `S1/S2/S3` |

### 3.2 角色与敌人

| 资产 | alpha 规格 | 后续可扩展 |
|---|---|---|
| 单位序列帧画布 | `128x128` 透明 PNG | 精英或 Boss 可用 `192x192` |
| 敌人序列帧画布 | `128x128` 透明 PNG | 大型敌人可用 `192x192` |
| 建筑画布 | `128x128` 透明 PNG | 2x2 建筑可用 `192x192` |
| 普通动作帧率 | `8-12 fps` | 复杂技能可到 `15 fps` |
| 预览视频帧率 | `30 fps` | 补帧预览可到 `60 fps` |
| alpha 朝向 | 先做 1 向，默认朝右 | 稳定后扩展右/下/左/上 4 向 |
| 角色脚底锚点 | 画布水平居中、靠下，约 `x=50%`, `y=78%-86%` | 大型单位单独标注 |

### 3.3 动作标准

| 动作 | 用途 | 推荐帧数 |
|---|---|---|
| `idle` | 待机、部署后常态 | 6-8 |
| `attack` | 普攻出手 | 6-10 |
| `cast` | 手动技能释放 | 8-12 |
| `hit` | 受击反馈 | 3-4 |
| `death` | 死亡/撤离 | 8-12 |
| `walk` | 敌人移动 | 6-8 |
| `skill_loop` | 持续技能状态 | 6-10 |

### 3.4 UI 图标

| 资产 | 规格 |
|---|---|
| 职业图标 | `64x64` PNG |
| 技能图标 | `64x64` PNG |
| 资源图标 | `32x32` 或 `64x64` PNG |
| 商店/部署头像 | `128x128` PNG |
| 事件插画 | `512x288` PNG |
| 祝福卡插画 | `256x160` 或 `512x288` PNG |
| 面板背景纹理 | `512x512` 可平铺 PNG |
| 结算插画 | `1280x720` 或 `1024x576` PNG |

---

## 4. 色彩、材质与可读性

### 4.1 主色板

| 用途 | 建议色 |
|---|---|
| 背景暗色 | 深铁灰、墨黑蓝、低饱和夜色 |
| 地图平地 | 暗橄榄、冷灰绿 |
| 未探索迷雾 | 近黑蓝灰 |
| 核心 | 冷蓝、白蓝能量 |
| 出怪口 | 暗红、污染红、熔橙 |
| 可部署提示 | 青绿色或蓝绿色 |
| 攻击范围 | 蓝色半透明 |
| 敌方危险 | 暗红、熔橙、污染紫红 |
| 法术能量 | 青蓝、薄荷绿、冷白 |
| 确认/奖励 | 琥珀色、信号黄 |

当前 `MapRoot` 已使用的调试色彩中，核心偏蓝、出怪口偏红、攻击范围偏蓝。正式素材应保留这个信息关系。

### 4.2 材质关键词

- 磨砂金属
- 战术织物
- 旧式终端玻璃
- 轻微磨损边缘
- 魔术回路微光
- 可读的硬边阴影
- 少量尘土和刮痕
- 临时工程结构

### 4.3 可读性硬规则

- `64px` 格子内必须一眼看出职业或敌人类型。
- 单位和敌人不能共用同一主轮廓。
- 玩家单位偏冷色和清洁边缘；敌人偏污染色和不规则轮廓。
- 建筑要比单位更“稳”，重心低、轮廓宽，避免像可移动角色。
- 技能特效只占必要空间，不做大面积全屏光效。
- UI 图标在 `64x64` 缩略图下仍要能辨认含义。

---

## 5. 当前 alpha 资产清单

### 5.1 单位

当前 `data/units.json` 已包含四个职业、三个价格/强度档位。美术资源应优先覆盖这些 ID。

| id | class | 美术定位 | 主色 | 关键轮廓 |
|---|---|---|---|---|
| `guard_t1` | `guard` | 一阶近卫 | 红/钢灰 | 短剑、前倾 |
| `guard_01` | `guard` | 二阶近卫 | 红/黑钢 | 更完整护甲、战线压制 |
| `guard_t3` | `guard` | 三阶近卫 | 深红/亮刃 | 更大攻击范围、决战感 |
| `sniper_t1` | `sniper` | 一阶狙击 | 蓝/黑 | 长枪、稳定站姿 |
| `sniper_t2` | `sniper` | 二阶狙击 | 蓝/银 | 连射机构、瞄准镜 |
| `archer_basic` | `sniper` | 三阶狙击 | 深蓝/冷白 | 爆裂弹药、远程压制 |
| `caster_t1` | `caster` | 一阶术士 | 青蓝/深灰 | 短杖、小法环 |
| `caster_t2` | `caster` | 二阶术士 | 青蓝/紫 | 过载符文、范围溅射 |
| `caster_t3` | `caster` | 三阶术士 | 冷白/青紫 | 链式法术、推击能量 |
| `defender_t1` | `defender` | 一阶重装 | 黄绿/铁灰 | 大盾、低重心 |
| `defender_t2` | `defender` | 二阶重装 | 黄绿/钢 | 强化壁垒、回血模块 |
| `defender_t3` | `defender` | 三阶重装 | 暗金/铁灰 | 反击壁垒、重型盾甲 |

### 5.2 敌人

| id | 玩法定位 | 美术定位 |
|---|---|---|
| `slime` | 慢速基础敌人 | 污染凝胶、低矮轮廓、内部核心光 |
| `wolf` | 快速突进敌人 | 荒原狼、低姿态奔跑、红眼或碎片突变 |

### 5.3 建筑

| id | 玩法定位 | 美术定位 |
|---|---|---|
| `medical_station` | 范围治疗 | 折叠式医疗设备、青蓝治疗光、低矮设备 |
| `wood_wall` | 阻挡路径 | 临时木墙、金属加固、宽而稳的障碍物 |

### 5.4 祝福与事件

| id | 类型 | 插画/图标方向 |
|---|---|---|
| `buff_atk_up_small` | 攻击提升 | 指挥桌、武器校准、红色战意光 |
| `buff_deploy_plus_one` | 部署上限 | 阵线扩编、额外单位令牌、蓝绿色部署格 |
| `buff_core_regen` | 核心恢复 | 核心稳压、蓝白能量回流 |
| `event_abandoned_cart` | 随机事件 | 废弃货车、补给箱、声望代价暗示 |

---

## 6. 职业视觉规则

### 6.1 单位职业

| class | 中文定位 | 轮廓语言 | 主色 | 装备关键词 |
|---|---|---|---|---|
| `guard` | 近卫 | 前倾、短武器、攻击姿态 | 红/钢灰 | 单手剑、战术护臂、轻甲 |
| `sniper` | 狙击 | 横向长武器、稳定站姿 | 蓝/黑 | 长枪、瞄准镜、披肩 |
| `caster` | 术士 | 竖向法杖、悬浮能量 | 青/紫点缀 | 法杖、术式环、轻长袍 |
| `defender` | 重装 | 宽厚块面、大盾、低重心 | 黄绿/铁灰 | 大盾、重甲、地面支撑 |

### 6.2 阶段差异

| tier | 价格/强度 | 视觉变化 |
|---|---|---|
| `t1` | 1 声望 | 装备简洁，轮廓干净，发光件很少 |
| `t2` | 3 声望 | 增加护甲层、职业标识、少量发光部件 |
| `t3` | 7 声望 | 轮廓更强，武器更独特，技能特效更明显 |

### 6.3 技能视觉语言

| 玩法效果 | 视觉语言 |
|---|---|
| 攻击力提升 | 武器边缘增亮、红橙能量沿刃流动 |
| 阻挡提升 | 地面锚点、盾面扩张、阵线投影 |
| 范围扩大 | 半透明战术网格或扇形锁定线 |
| 连射 | 枪口连续短闪、细小弹道残影 |
| 溅射 | 目标点小范围冲击环，不要全屏爆炸 |
| 链式法术 | 细线连接多个目标，逐跳衰减 |
| 推击 | 短促冲击波，方向明确 |
| 反击 | 盾面火花、近距离回弹线 |
| 治疗 | 青蓝粒子回流，避免与伤害红色混淆 |

---

## 7. Prompt 母版

### 7.1 全局风格 prompt

用于角色、敌人、建筑、图标和插画的共同前缀。

```text
Original 2D game asset for a dark tactical fantasy sci-fi tower defense roguelite.
Pseudo-3D hand-painted look, three-quarter top-down camera, readable silhouette,
clean shape language, low-saturation tactical palette with one sharp accent color,
matte metal, worn fabric, temporary engineering parts, subtle magical circuitry glow,
consistent upper-left lighting, crisp edges, transparent background,
designed for a 1280x720 2D grid-based game with 64px tiles,
clear at small size, no text, no logo, no watermark.
```

### 7.2 全局 negative prompt

```text
photorealistic, messy detail, over-rendered background, full scene background,
front-facing portrait, side-scroller view, extreme perspective, blurry, low contrast,
tiny unreadable silhouette, extra limbs, malformed hands, inconsistent weapon,
cropped body, duplicate character, text, letters, numbers, UI mockup, watermark,
brand logo, copied existing game character, copied existing game UI.
```

### 7.3 角色静帧 prompt 模板

```text
{style_core}

Subject: one {tier} {character_class} operator, {role_description}.
Pose: {pose_description}, feet visible, centered on canvas, full body.
Equipment: {equipment_description}.
Design notes: original character, tactical fantasy sci-fi gear, strong class identity,
clear silhouette, readable weapon shape, compact enough to fit one 64px map tile.
Camera: three-quarter top-down, pseudo-3D 2D sprite, transparent background.
Canvas: 128x128 game sprite, anchor at bottom center.

{negative}
```

### 7.4 角色序列帧 prompt 模板

生成序列帧时，每个动作先锁定同一个角色参考图，再生成动作帧。不要每帧重新设计角色。

```text
{style_core}

Create a consistent animation sprite sheet for the same {tier} {character_class} operator.
Action: {action}.
Frame count: {frame_count} frames.
Frame layout: horizontal strip, equal frame size, transparent background.
Character must keep the same costume, weapon, body proportions, colors, and silhouette in every frame.
Movement should be readable but compact, suitable for a 64px grid tactical tower defense unit.
Default facing direction is right. No camera movement, no background, no text.

{negative}
```

### 7.5 敌人序列帧 prompt 模板

```text
{style_core}

Create a consistent animation sprite sheet for one {enemy_type} enemy.
Action: {action}.
Frame count: {frame_count} frames.
Frame layout: horizontal strip, equal frame size, transparent background.
The enemy must read as hostile at 64px tile size, with polluted red or violet accents.
Keep the same body proportions and silhouette in every frame.
Default movement direction is right. No camera movement, no background, no text.

{negative}
```

### 7.6 建筑 prompt 模板

```text
{style_core}

Subject: one deployable {building_type} building for a tactical 2D grid.
Design notes: {building_description}, low center of gravity, readable as a structure,
compact enough to fit one 64px map tile, not a character, not a vehicle.
Camera: three-quarter top-down, pseudo-3D 2D sprite, transparent background.
Canvas: 128x128 building sprite, anchor at bottom center.

{negative}
```

### 7.7 UI 图标 prompt 模板

```text
{style_core}

Create a square game UI icon for {icon_subject}.
Icon type: {icon_type}.
Shape language: bold silhouette, simple internal detail, high contrast center shape,
dark tactical frame, small accent glow matching {accent_color}.
Must remain readable at 64x64 pixels.
No text, no numbers, no logo, transparent background or simple dark icon plate.

{negative}
```

### 7.8 事件/祝福插画 prompt 模板

```text
{style_core}

Create a narrative card illustration for {event_or_blessing_name}.
Scene idea: {scene_description}.
Mood: tense strategic choice, night frontier outpost, scarce resources.
Composition: clear focal object, readable at small card size, no written text,
dark tactical fantasy sci-fi palette, subtle magical glow.
Aspect ratio: 16:9, intended for 512x288 UI card art.

{negative}
```

---

## 8. Alpha Prompt 实例

### 8.1 `guard_t1`

```text
{style_core}

Subject: one tier 1 guard operator, a frontline melee fighter for holding a narrow lane.
Pose: ready stance with a short sword angled forward, feet visible, centered on canvas, full body.
Equipment: light tactical armor, single-edged sword, small forearm guard, red accent scarf.
Design notes: original character, tactical fantasy sci-fi gear, strong guard identity,
clear silhouette, readable sword shape, compact enough to fit one 64px map tile.
Camera: three-quarter top-down, pseudo-3D 2D sprite, transparent background.
Canvas: 128x128 game sprite, anchor at bottom center.

{negative}
```

### 8.2 `sniper_t1`

```text
{style_core}

Subject: one tier 1 sniper operator, a ranged unit watching a long lane.
Pose: stable firing stance with a long rifle held diagonally, feet visible, centered on canvas, full body.
Equipment: compact marksman rifle, hooded tactical cape, slim armor plates, blue accent lens.
Design notes: original character, readable long weapon silhouette, calm precise posture,
compact enough to fit one 64px map tile.
Camera: three-quarter top-down, pseudo-3D 2D sprite, transparent background.
Canvas: 128x128 game sprite, anchor at bottom center.

{negative}
```

### 8.3 `caster_t1`

```text
{style_core}

Subject: one tier 1 caster operator, a ranged magic damage unit.
Pose: upright casting stance with a short staff and a small floating spell ring,
feet visible, centered on canvas, full body.
Equipment: light coat, compact staff, glowing cyan runes, small utility pouch.
Design notes: original character, clear staff silhouette, subtle magical energy,
compact enough to fit one 64px map tile.
Camera: three-quarter top-down, pseudo-3D 2D sprite, transparent background.
Canvas: 128x128 game sprite, anchor at bottom center.

{negative}
```

### 8.4 `defender_t1`

```text
{style_core}

Subject: one tier 1 defender operator, a heavy unit built to block enemies.
Pose: braced defensive stance behind a large shield, feet visible, centered on canvas, full body.
Equipment: broad rectangular shield, heavy shoulder armor, reinforced boots, yellow-green signal accent.
Design notes: original character, wide sturdy silhouette, strong shield shape,
compact enough to fit one 64px map tile.
Camera: three-quarter top-down, pseudo-3D 2D sprite, transparent background.
Canvas: 128x128 game sprite, anchor at bottom center.

{negative}
```

### 8.5 `slime`

```text
{style_core}

Subject: one small corrupted slime enemy for a night invasion wave.
Pose: creeping forward, low body, visible glowing core inside.
Design notes: dark translucent body, toxic red-purple accent, simple readable blob silhouette,
clearly weaker than humanoid enemies, compact enough to fit one 64px map tile.
Camera: three-quarter top-down, pseudo-3D 2D sprite, transparent background.
Canvas: 128x128 game sprite, anchor at bottom center.

{negative}
```

### 8.6 `wolf`

```text
{style_core}

Subject: one fast wasteland wolf enemy for a night invasion wave.
Pose: low sprinting posture, head forward, legs compact and readable.
Design notes: lean angular body, dark fur, metal shard growths, faint red eye glow,
fast enemy silhouette, compact enough to fit one 64px map tile.
Camera: three-quarter top-down, pseudo-3D 2D sprite, transparent background.
Canvas: 128x128 game sprite, anchor at bottom center.

{negative}
```

### 8.7 `medical_station`

```text
{style_core}

Subject: one small deployable medical station building for a tactical grid.
Design notes: compact field device, foldable legs, soft cyan healing glow,
clear medical silhouette without text or cross symbol, fits one 64px map tile.
Camera: three-quarter top-down, pseudo-3D 2D sprite, transparent background.
Canvas: 128x128 building sprite, anchor at bottom center.

{negative}
```

### 8.8 `wood_wall`

```text
{style_core}

Subject: one temporary wooden barricade wall for blocking a path.
Design notes: reinforced timber, metal braces, worn tactical construction,
wide sturdy silhouette, readable as obstacle, fits one 64px map tile.
Camera: three-quarter top-down, pseudo-3D 2D sprite, transparent background.
Canvas: 128x128 building sprite, anchor at bottom center.

{negative}
```

---

## 9. UI 与卡牌资源

### 9.1 UI 生产原则

AI 负责生成可控图片素材，Godot 负责布局和文字。不要让 AI 直接生成整张 UI 截图。

- 图标、头像、插画、面板纹理可以 AI 生成。
- 文字、价格、数值、按钮状态、列表布局必须由 Godot UI 渲染。
- 中文字体使用项目内 `SourceHanSansSC-Normal.otf`。
- UI 图标不包含文字、数字、商标、伪装按钮文案。

### 9.2 面板视觉规则

| 面板 | 视觉方向 |
|---|---|
| HUD | 冷静、窄条、信息优先，避免装饰压住地图 |
| 商店 | 卡片式但克制，突出价格档位 `1/3/7` |
| 部署 | 干员槽位清楚，突出可部署/已部署/再部署 CD |
| 事件 | 叙事卡片，中心插画 + 选择按钮 |
| 祝福 | 三选一卡牌，稀有度和效果类型要清楚 |
| 结算 | 战果报告，核心状态和统计优先 |
| 战斗沙箱 | 工具界面，密度高、少装饰、便于调参 |

### 9.3 图标 prompt 示例

```text
{style_core}

Create a square game UI icon for the deploy limit blessing.
Icon type: blessing icon.
Shape language: three small operator tokens appearing on a tactical grid,
bold silhouette, simple internal detail, high contrast center shape,
dark tactical frame, cyan-green deployment glow.
Must remain readable at 64x64 pixels.
No text, no numbers, no logo, transparent background or simple dark icon plate.

{negative}
```

### 9.4 事件插画 prompt 示例

```text
{style_core}

Create a narrative card illustration for an abandoned supply cart event.
Scene idea: a damaged cart at the edge of a foggy road, two sealed crates still intact,
a faint red warning light suggesting reputation cost.
Mood: tense strategic choice, night frontier outpost, scarce resources.
Composition: clear focal object, readable at small card size, no written text,
dark tactical fantasy sci-fi palette, subtle magical glow.
Aspect ratio: 16:9, intended for 512x288 UI card art.

{negative}
```

---

## 10. 目录规范

AI 原始输出和正式游戏资源分开保存。

```text
assets/
├─ source_ai/
│  ├─ units/
│  ├─ enemies/
│  ├─ buildings/
│  ├─ ui/
│  └─ cards/
├─ sprites/
│  ├─ units/
│  ├─ enemies/
│  └─ buildings/
└─ ui/
   ├─ icons/
   │  ├─ units/
   │  ├─ skills/
   │  ├─ resources/
   │  └─ blessings/
   ├─ portraits/
   ├─ panels/
   └─ cards/
```

命名规则：

```text
assets/sprites/units/guard_t1/idle/guard_t1_idle_000.png
assets/sprites/units/guard_t1/attack/guard_t1_attack_000.png
assets/sprites/enemies/slime/walk/slime_walk_000.png
assets/sprites/buildings/wood_wall/wood_wall_idle_000.png
assets/ui/icons/units/guard_t1_icon.png
assets/ui/icons/skills/guard_hold_line_icon.png
assets/ui/icons/blessings/buff_deploy_plus_one_icon.png
assets/ui/cards/events/event_abandoned_cart.png
```

---

## 11. Godot 接入约定

### 11.1 逻辑 key 与资源路径

玩法配置中优先使用逻辑 key，不直接写图片路径。

当前已有：

- `units.json[].icon_key`
- `units.json[].scene_key`
- `enemies.json[].scene_key`
- `buildings.json[].scene_key`

后续表现资源建议新增集中映射，例如：

```text
visual_key -> SpriteFrames / Texture2D / AudioStream / VFX scene
icon_key -> Texture2D
```

不要把正式图片路径散落写进战斗、商店、部署、祝福逻辑里。

### 11.2 UnitActor 挂载点

当前 `UnitActor.tscn` 已有：

```text
UnitActor
├─ TitleLabel
├─ StatusView
├─ VisualRoot
├─ AudioRoot
├─ EffectRoot
└─ SkillBehavior
```

接入表现资源时：

- 角色动画挂在 `VisualRoot`。
- 受击、技能、弹道特效挂在 `EffectRoot` 或独立 `Projectile`。
- 音效挂在 `AudioRoot`。
- `TitleLabel` 和 `StatusView` 不应被角色贴图遮挡。

### 11.3 SpriteFrames 约定

建议所有单位和敌人使用统一动画名：

```text
idle
attack
cast
hit
death
walk
skill_loop
```

alpha 阶段如果暂时缺少某动作：

- 缺 `cast`：可回退到 `attack`。
- 缺 `hit`：可用短暂闪白或状态条反馈。
- 缺 `death`：可淡出。
- 缺 `walk`：敌人可用 `idle` 加位移。

---

## 12. 生产流程

### 12.1 单位资源

1. 用静帧 prompt 生成每个单位的标准小人。
2. 选中 1 张作为该单位的角色参考图。
3. 基于参考图生成 `idle`、`attack`、`cast`、`hit`、`death`。
4. 清理透明背景、统一画布、统一脚底锚点。
5. 用 `tools/frames_to_video.py` 合成预览视频。
6. 放入战斗沙箱检查帧间抖动、攻击方向、体积占用。
7. 登记到表现资源映射，再接入 `UnitActor/VisualRoot`。

示例预览命令：

```powershell
python tools/frames_to_video.py assets/sprites/units/guard_t1/attack -o preview_guard_t1_attack.mp4 --fps 12 --out-fps 30 --overwrite
```

### 12.2 敌人资源

1. 先做 `walk` 和 `hit`，保证夜战基础反馈。
2. 再做 `attack` 和 `death`。
3. 在沙箱中检查不同速度下的可读性。
4. 快速敌人必须在低帧率下仍能看出移动方向。

### 12.3 建筑资源

1. 每个建筑先做 `idle` 静帧。
2. 有功能的建筑再补 `active` 或 `working` 循环。
3. 可损毁建筑后续补 `damaged` 和 `destroyed`。
4. 建筑必须比单位更稳、更低、更像地面结构。

### 12.4 UI 资源

1. 先生成职业图标、技能图标、资源图标。
2. 缩到 `64x64` 检查可读性。
3. 再做商店/部署头像和事件/祝福插画。
4. Godot 内只使用图片资源，不使用 AI 生成整张 UI 截图。
5. 面板布局、按钮状态、中文文字和主题仍由 Godot UI 负责。

---

## 13. Alpha 优先级

### P0：最小可玩可视化

- 4 个职业图标。
- 木材、石材、魔力、声望、行动力、核心生命图标。
- `slime` 和 `wolf` 的基础 `walk` 动画。
- `wood_wall` 和 `medical_station` 静帧。

### P1：战斗读图

- 12 个单位头像。
- 4 个职业的一阶单位 `idle` 和 `attack`。
- 攻击范围、部署方向、技能可释放状态的视觉统一。
- 基础弹道或命中特效。

### P2：构筑体验

- 祝福三选一卡图。
- `buff_atk_up_small`、`buff_deploy_plus_one`、`buff_core_regen` 图标。
- `event_abandoned_cart` 插画。
- 商店卡牌纹理和部署卡头像。

### P3：完整 alpha 表现

- 12 个单位完整动作。
- 敌人 `attack/hit/death`。
- 建筑 `active/damaged/destroyed`。
- 主菜单、胜利、失败画面。

---

## 14. 验收标准

每批资源进入 alpha 前必须检查：

- `64px` 格子内能看清单位职业。
- 单位、敌人、建筑不会在战斗中混成一团。
- 角色脚底位置稳定，帧动画不明显跳动。
- 攻击动作能看出出手方向。
- 技能特效不遮挡血条、路径和部署格。
- UI 图标在 `64x64` 下仍能辨认含义。
- 事件/祝福插画没有文字、商标和直接可识别的现有游戏角色。
- 所有文件名使用英文小写、数字和下划线。
- 所有正式资源路径可由 key 映射，不在玩法配置里硬编码图片路径。
- 战斗沙箱中至少跑一轮默认预设，不出现贴图缺失、错位、遮挡状态条。

---

## 15. Prompt 变量表

| 变量 | 示例 |
|---|---|
| `{character_class}` | `guard`, `sniper`, `caster`, `defender` |
| `{tier}` | `tier 1`, `tier 2`, `tier 3` |
| `{action}` | `idle`, `attack`, `cast`, `hit`, `death`, `walk` |
| `{frame_count}` | `6`, `8`, `10`, `12` |
| `{accent_color}` | `red steel`, `blue lens`, `cyan magic`, `yellow-green signal` |
| `{icon_type}` | `class icon`, `skill icon`, `resource icon`, `unit portrait`, `blessing icon` |
| `{enemy_type}` | `corrupted slime`, `wasteland wolf` |
| `{building_type}` | `medical station`, `wooden barricade`, `resource collector` |
| `{scene_description}` | `a night outpost supply decision`, `a glowing tactical command table` |
