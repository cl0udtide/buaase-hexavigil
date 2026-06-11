# Character and Enemy Asset Generation Prompts

本文档用于生成或重绘游戏内角色、干员和敌人 sprite。它不是技能图标、遗物图标或战斗特效提示词库；UI 资产继续参考 `docs/UI_ASSET_GENERATION_PROMPTS.md`，地图建筑参考 `docs/MAP_ASSET_GENERATION_PROMPTS.md`，战斗特效参考 `docs/EFFECT_ASSET_GENERATION_PROMPTS.md`。例外：干员 UI 胸像批次按 R3 评审决议收录在本文档第 7 节（它走 UI 头像规范，不走第 1 节地图 sprite 全局风格）。

当前运行时入口以代码为准：

- 干员：`scripts/combat/unit_actor.gd` 按 `data/units.json[].visual_key` 加载 `assets/sprites/units/<visual_key>/idle/<visual_key>_idle_000.png`。
- 敌人：`scripts/enemy/enemy_actor.gd` 按 `data/enemies.json[].visual_key` 加载 `assets/sprites/enemies/<visual_key>/idle/<visual_key>_idle_000.png`。
- 最终入库图为 `128x128` 透明 PNG，游戏中显示尺寸约为干员 `72px`、敌人 `70px`。
- 生成源图可以放在 `assets/sprites/units/raw/` 或 `assets/sprites/enemies/raw/`，裁切后的运行时 PNG 必须和 `visual_key` 路径对齐。

## 1. 全局风格

每轮生成或重绘都先复制本段，再追加纯文本版或参考图版的具体角色描述。

```text
我们要为一个 Godot 俯视塔防游戏生成游戏内角色/敌人 sprite。资产会被放在 64x64 地图格上，最终裁切为 128x128 透明 PNG，并在游戏中缩放到约 70-72px 显示。

整体风格：
- 低饱和半卡通手绘，轻微奇幻塔防，和现有 UI、地图建筑、敌人特效属于同一游戏。
- 俯视正交或轻微三分之二俯视，不要正面立绘、半身头像、卡牌插画、海报构图或强透视。
- 轮廓优先，72px 下必须能读出职业/敌人类型、体型、武器或核心识别点。
- 色彩以暗青灰、雾蓝灰、灰绿、石灰、木褐为基底；功能点缀可以使用低饱和青蓝、浅金、琥珀、暗红。
- 光效克制，只作为局部识别点，不能抢地图、范围提示和战斗特效的层级。

构图硬约束：
- 最终单张资产为 128x128 透明 PNG，主体完整，不被裁切。
- 主体居中略偏下，底部中心作为地图锚点；脚底或接地点不要贴边。
- 默认朝右或右下，方便 Godot 通过 flip_h 处理左向；不要做强方向性正面站姿。
- 普通干员和普通敌人的可见主体控制在约 64-82px；Boss 可以更大，但可见轮廓不要超过约 96px。
- 保留足够透明边距，顶部、左右不要顶到画布边缘。

禁用内容：
- 不要背景地块、投影大底座、UI 边框、卡片框、徽章、按钮、头像框、文字、数字、水印或签名。
- 不要写实照片、PBR 3D 渲染、厚黑描边、霓虹强发光、赛博重装甲、复杂高频纹理。
- 不要把技能特效、弹道、爆炸、范围圈烘进角色本体；这些属于特效资产。
- 不要生成透明棋盘格背景。源图阶段使用纯色背景 #79C7B6，最终抠成透明 PNG。

输出要求：
- 清晰边缘，低噪点，适合抠图和缩小。
- 角色脚底可以有极轻接触阴影，但阴影必须包含在透明 PNG 内且不能大到像地面块。
- 多个资产同一轮生成时，尺寸、视角、光照和锚点必须一致。
```

## 2. 保存与入库约定

- 源图命名建议：
  - 新干员：`assets/sprites/units/raw/unit_source_sheet_<theme>.png`
  - 新敌人：`assets/sprites/enemies/raw/enemy_source_sheet_<theme>.png`
  - 旧角色重绘：`assets/sprites/<units|enemies>/raw/<visual_key>_redraw_source.png`
- 裁切后的运行时路径：
  - 干员：`assets/sprites/units/<visual_key>/idle/<visual_key>_idle_000.png`
  - 敌人：`assets/sprites/enemies/<visual_key>/idle/<visual_key>_idle_000.png`
- 修改或新增 PNG 后运行 Godot 导入，并提交 `.png` 与对应 `.png.import`。
- 如果新增 `visual_key`，同步修改 `data/units.json` 或 `data/enemies.json`，并确认运行时路径存在。

## 3. 纯文本版模板

### 3.1 新干员单体模板

```text
请生成 1 个干员地图 sprite，纯色背景 #79C7B6，最终裁切为 128x128 透明 PNG。

干员信息：
- id: <unit_id>
- visual_key: <visual_key>
- 显示名: <中文名>
- 职业/定位: <guard/sniper/caster/defender/medic/supporter 等>
- 攻击方式: <近战/远程/法术/治疗/阻挡>
- 轮廓关键词: <体型、站姿、武器、头部或背部识别点>
- 主色: <低饱和主色>
- 点缀色: <低饱和功能色>

造型要求：
- 低饱和半卡通手绘，轻微奇幻塔防地图实体。
- 默认朝右或右下，完整站姿，底部锚点居中。
- 72px 下先读出职业和武器，再读出服装细节。
- 不要画 UI 头像、卡牌立绘、职业图标、技能特效、名字或任何文字。

目标输出路径：
assets/sprites/units/<visual_key>/idle/<visual_key>_idle_000.png
```

### 3.2 新敌人单体模板

```text
请生成 1 个敌人地图 sprite，纯色背景 #79C7B6，最终裁切为 128x128 透明 PNG。

敌人信息：
- id: <enemy_id>
- visual_key: <visual_key>
- 显示名: <中文名>
- 行为/定位: <normal/boss/demolisher/caster/flying/ranged 等>
- 移动类型: <ground/flying>
- 攻击方式: <近战/远程投射/法术/爆炸/召唤>
- 轮廓关键词: <体型、头部、武器、护甲、核心器官或族群特征>
- 主色: <低饱和主色>
- 点缀色: <低饱和危险/法术色>

造型要求：
- 低饱和半卡通手绘，轻微奇幻塔防地图敌人。
- 默认朝右或右下，完整身体，底部锚点居中；飞行单位可略微悬浮，但不要画巨大地面影子。
- 普通敌人可见主体约 64-82px，Boss 可见主体可放大到约 86-96px。
- 70px 下先读出威胁类型和移动方式，再读出局部细节。
- 不要画 UI 图标、徽章、血条、名字、路线箭头、攻击弹道或爆炸特效。

目标输出路径：
assets/sprites/enemies/<visual_key>/idle/<visual_key>_idle_000.png
```

### 3.3 批量源图模板

```text
请生成一张角色/敌人 sprite 源图，纯色背景 #79C7B6，包含 <数量> 个独立资产，按从左到右、从上到下排列。每个资产最终都裁切为 128x128 透明 PNG。

统一要求：
- 所有资产同一视角、同一光照、同一缩放基准、同一底部锚点。
- 每个资产之间留足纯色背景间距，不要互相接触或投影。
- 不要文字、数字、UI 框、卡牌、地面块、技能弹道或完整战斗截图。

裁切顺序与目标路径：
1. <visual_key_1> -> assets/sprites/<units|enemies>/<visual_key_1>/idle/<visual_key_1>_idle_000.png
2. <visual_key_2> -> assets/sprites/<units|enemies>/<visual_key_2>/idle/<visual_key_2>_idle_000.png

逐项描述：
1. <visual_key_1>: <角色或敌人造型描述>
2. <visual_key_2>: <角色或敌人造型描述>
```

## 4. 参考图版模板

参考图版用于重绘少数旧角色/敌人，或把外部概念图转成项目内地图 sprite。传图后复制本节，并替换角色字段。参考图只用于继承身份、轮廓和关键设计点，不能保留原图背景、边框、UI 构图或不适合地图读图的细节。

### 4.1 旧角色/敌人重绘模板

```text
请基于上传的参考图，重绘为 Godot 俯视塔防游戏内角色/敌人 sprite。参考图用于保留角色身份、主要轮廓、颜色关系和关键识别元素，但最终必须转成项目统一的低饱和半卡通手绘地图实体。

目标信息：
- 类型: <unit/enemy>
- id: <unit_id 或 enemy_id>
- visual_key: <visual_key>
- 显示名: <中文名>
- 当前用途: <普通干员/普通敌人/Boss/飞行敌人/远程敌人等>
- 必须保留: <从参考图继承的 3-5 个关键点>
- 可以简化: <高频纹理、复杂饰品、巨大披风、背景元素等>
- 需要强化: <72px 下最重要的轮廓或颜色识别点>

重绘要求：
- 128x128 源图，纯色背景 #79C7B6，最终抠成透明 PNG。
- 默认朝右或右下，完整身体，主体居中略偏下，底部锚点居中。
- 保留参考图角色身份，但重新概括体块和细节，让它在 70-72px 下清楚可读。
- 不要保留参考图中的背景、UI 框、文字、光圈、复杂特效、阴影地面或裁切边。
- 不要做成头像、贴纸、表情包、卡牌立绘、写实 3D 模型或高饱和霓虹风。

目标输出路径：
assets/sprites/<units|enemies>/<visual_key>/idle/<visual_key>_idle_000.png
```

### 4.2 参考图转变体模板

```text
请基于上传的参考图，为同一角色生成一个可区分的新状态/阶段 sprite。保持角色身份、骨架比例、视角、锚点和基础配色一致，只通过局部装备、姿态、颜色点缀或状态标记表现差异。

变体信息：
- 基础 visual_key: <base_visual_key>
- 新 visual_key: <variant_visual_key>
- 状态/阶段名: <例如 暴怒形态/精英形态/受损形态>
- 与基础形态相同: <必须一致的轮廓、体型、脸部或武器>
- 与基础形态不同: <状态差异>

硬约束：
- 两个状态在地图上不能像两个不同角色。
- 不要通过大面积特效遮挡本体；阶段效果优先留给 VFX sprite。
- 仍然输出 128x128 透明 PNG，路径按新 visual_key 入库。
```

## 5. 当前条目：奶龙酋长参考图重绘

本次只为 `milk_dragon_chief` 建立参考图重绘提示词。当前 Boss 没有区分不同形态的多套角色资产，整场战斗复用同一张运行时 sprite；阶段差异由 `phases` 配置和特效表现。提示词和源图命名统一按“奶龙酋长”处理，不把它描述成某个独立形态。

### 5.1 数据与目标路径

- 数据文件：`data/enemies.json`
- id：`milk_dragon_chief`
- 显示名：`奶龙酋长`
- 当前运行时 visual_key：`milk_dragon_chief_thick_scale`，这是现有数据和路径的兼容键，不表示单独的厚鳞形态资产。
- 行为：`boss`
- 资产用途：奶龙酋长整场战斗共用的 Boss sprite
- 源图建议：`assets/sprites/enemies/raw/milk_dragon_chief_redraw_source.png`
- 最终仍需覆盖当前现有运行时文件：`assets/sprites/enemies/milk_dragon_chief_thick_scale/idle/milk_dragon_chief_thick_scale_idle_000.png`

### 5.2 参考图版提示词

上传奶龙酋长参考图后复制以下内容：

```text
请基于上传的参考图，重绘“奶龙酋长”为 Godot 俯视塔防 Boss 敌人 sprite。参考图是角色外观的唯一依据；请照着参考图保留角色身份、整体轮廓、比例、配色和关键识别元素，只把它转换成项目统一的游戏内地图 sprite。

目标信息：
- 类型: enemy boss
- 资产代号: milk_dragon_chief
- 显示名: 奶龙酋长

重绘要求：
- 128x128 源图，纯色背景 #79C7B6，最终抠成透明 PNG。
- 默认朝右或右下，完整身体，主体居中略偏下，底部锚点居中。
- 体量按参考图表现，但需要适合 64x64 地图格附近显示；顶部和左右保留透明边距，不要压满画布。
- 70px 下优先保持参考图中的主要轮廓和识别点清楚。
- 造型要适合俯视塔防地图实体，不要变成 UI 头像、贴纸、卡牌立绘或完整插画。
- 不要额外添加参考图里没有的外貌元素、装备元素、颜色设定或状态特征。
- 不要画攻击弹道、范围爆发、火焰背景或大外发光。
- 不要保留参考图中的背景、文字、水印、UI 框、影子地面、装饰底座或裁切边。

风格关键词：
low-saturation hand-painted cartoon boss sprite, top-down tactical fantasy, clean silhouette, map-ready transparent sprite, readable at 70px, no UI frame, no text, no realistic 3D render, no neon glow.
```

## 6. 入库检查

- `git diff --check` 无空白错误。
- PNG 最终尺寸是 `128x128`，透明背景无青绿色残边。
- 路径和 `visual_key` 完全一致，Godot 能按当前加载逻辑找到文件。
- 在暗色平地、山地、水域、路径线和范围覆盖层上预览，70-72px 下轮廓清楚。
- Boss 不能遮挡邻格单位、敌人路径和攻击范围提示。
- 如果修改 PNG，运行：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . --quit
```

## 7. 干员 UI 胸像批次（R3 评审批次 ⑥：`portrait_unit_<unit_id>`，28 张）

来源评审条目（`tmp/ui_round3_findings.json`）：`avatar-placeholder-glyph`、`unit-identity-three-styles`、`operator-portrait-missing`。现状：「data/units.json 28 个干员无 portrait_path/ui_portrait_path 字段（UiArtRegistry.get_portrait_texture 只认这两个），unit_detail_panel.gd:118 回落 _icon_text(cfg) 首字汉字，部署卡只有 class_icon」——详情页用 44px 首字 monogram 占位、商店卡/部署卡/详情页三处身份表达互不一致。

### 7.1 范围与规范

- 本批是本文档「只做地图 sprite」总则的显式例外：生成时**不要复制第 1 节全局风格**（俯视地图 sprite 规范与胸像构图冲突），改用 7.3 的胸像全局提示词；并遵守 `docs/UI_ASSET_GENERATION_PROMPTS.md` §27——「头像单独开对话生成，不混 UI 框架批次」（avatar-placeholder-glyph 原话：「严格走 docs/UI_ASSET_GENERATION_PROMPTS.md §27」）。
- 目标尺寸：单张 256x256（triage 给出 192x192 与 256x256 两档口径，统一取大者；显示端：详情页头像窗内容区约 80-96px、部署卡 32-48px，均有 2x 余量）。
- 分层类型：独立内容图，运行时夹在既有 `frame_unit_portrait_backplate` 与 `frame_unit_portrait_frame` 之间，无 `_base/_overlay` 后缀；#FF00FF 纯底抠图，无边框、无卡牌、无文字。
- 源图组织：按职业分 4 张源图、每张 7 个（triage 口径「一图 8 个（28 干员共 4 图）」，按职业整除取 7）；裁切后入库 `assets/ui/generated/portrait_unit_<unit_id>.png`，连 `.png.import` 一起提交。
- 身份依据：每个干员上传其现有地图 sprite `assets/sprites/units/<visual_key>/idle/<visual_key>_idle_000.png` 作参考图，继承配色与关键识别点；不要自创外貌设定。

### 7.2 资产清单（28 张，key 按 data/units.json 的 id）

| # | asset key | 干员 | 职业 | 参考 visual_key |
|---|---|---|---|---|
| 1 | `portrait_unit_guard_t1` | 斯卡蒂 | guard | skadi |
| 2 | `portrait_unit_guard_01` | 煌 | guard | blaze |
| 3 | `portrait_unit_guard_t3` | 银灰 | guard | silverash |
| 4 | `portrait_unit_mountain` | 山 | guard | mountain |
| 5 | `portrait_unit_zuo_le` | 左乐 | guard | zuo_le |
| 6 | `portrait_unit_degenbrecher` | 锏 | guard | degenbrecher |
| 7 | `portrait_unit_surtr` | 史尔特尔 | guard | surtr |
| 8 | `portrait_unit_sniper_t1` | 鸿雪 | sniper | pozyomka |
| 9 | `portrait_unit_sniper_t2` | 能天使 | sniper | exusiai |
| 10 | `portrait_unit_archer_basic` | 菲亚梅塔 | sniper | fiammetta |
| 11 | `portrait_unit_narantuya` | 娜仁图亚 | sniper | narantuya |
| 12 | `portrait_unit_ray` | 莱伊 | sniper | ray |
| 13 | `portrait_unit_typhon` | 提丰 | sniper | typhon |
| 14 | `portrait_unit_wisadel` | 维什戴尔 | sniper | wisadel |
| 15 | `portrait_unit_caster_t1` | 刻俄柏 | caster | ceobe |
| 16 | `portrait_unit_caster_t2` | 艾雅法拉 | caster | eyjafjalla |
| 17 | `portrait_unit_caster_t3` | 异客 | caster | passenger |
| 18 | `portrait_unit_ifrit` | 伊芙利特 | caster | ifrit |
| 19 | `portrait_unit_nymph` | 妮芙 | caster | nymph |
| 20 | `portrait_unit_goldenglow` | 澄闪 | caster | goldenglow |
| 21 | `portrait_unit_logos` | 逻各斯 | caster | logos |
| 22 | `portrait_unit_defender_t1` | 森蚺 | defender | eunectes |
| 23 | `portrait_unit_defender_t2` | 年 | defender | nian |
| 24 | `portrait_unit_defender_t3` | 星熊 | defender | hoshiguma |
| 25 | `portrait_unit_saria` | 塞雷娅 | defender | saria |
| 26 | `portrait_unit_penance` | 斥罪 | defender | penance |
| 27 | `portrait_unit_jessica_alter` | 涤火杰西卡 | defender | jessica_the_liberated |
| 28 | `portrait_unit_shu` | 黍 | defender | shu |

### 7.3 胸像全局提示词

每张源图先复制本段，再追加 7.4 的分批清单：

```text
我们要为 Godot 塔防游戏生成干员 UI 胸像。胸像运行时显示在头像背板之上、头像覆盖框之下，显示尺寸约 80-96px（详情页）与 32-48px（部署卡）。

整体风格：
- 低饱和轻奇幻、柔光、冷钢 + teal 调，与游戏现有 UI、地图 sprite 同族；1:1 胸像剪影风，深底亮缘光。
- 方形构图适配头像窗：头肩部为主体，主体占画面约 70-85%，居中，不被裁切。
- 以上传的地图 sprite 参考图为唯一身份依据，继承配色、发型/头部识别点与武器或服装关键元素；不要添加参考图没有的设定。

必要工程要求：
- 背景必须是完全纯净的 #FF00FF 实色，人物边缘干净，无半透明像素。
- 不要 UI 边框、卡牌、徽章、按钮、头像框，不要文字、数字、水印、签名。
- 多个胸像同一张源图时：同一视角、同一光照、同一裁切基准，互不接触，留足 #FF00FF 间距。
```

### 7.4 分批生成提示词（4 张源图）

每张源图按下表逐项上传对应 `idle_000` 参考图，并在 7.3 全局提示词后追加：

```text
请生成一张干员胸像源图，纯色背景 #FF00FF，包含 7 个独立胸像，按从左到右、从上到下排列，每个最终裁切为 256x256。

裁切顺序与对应参考图：
<按 7.2 清单中本职业 7 人的顺序，逐行列出「portrait_unit_<id>：<干员名>，参考 assets/sprites/units/<visual_key>/idle/<visual_key>_idle_000.png」>
```

- 源图 1（guard 7 人）：`assets/sprites/units/raw/portrait_source_sheet_guard.png`，对应清单 #1-#7。
- 源图 2（sniper 7 人）：`assets/sprites/units/raw/portrait_source_sheet_sniper.png`，对应清单 #8-#14。
- 源图 3（caster 7 人）：`assets/sprites/units/raw/portrait_source_sheet_caster.png`，对应清单 #15-#21。
- 源图 4（defender 7 人）：`assets/sprites/units/raw/portrait_source_sheet_defender.png`，对应清单 #22-#28。

### 7.5 验收要点

- 方形构图适配头像窗，#FF00FF 抠图后边缘干净无残色（洋红羽边在 32px 下会糊成脏边）。
- 96px（详情页）与 32px（部署卡）双尺寸目检：身份可辨，与同名地图 sprite 配色/识别点对得上。
- 同批 28 张视角、光照、裁切基准一致；不含 UI 边框、文字、卡牌元素（§27 规范）。
- 「portrait 资产同时被部署卡 OPERATOR_PORTRAIT 槽位复用，落图后两处都要目检」（avatar-placeholder-glyph）；落图后重跑出界 lint（unit-identity-three-styles 风险项）。

### 7.6 实装接线

- 入库路径：`assets/ui/generated/portrait_unit_<unit_id>.png`（连 `.png.import` 提交，跑一次 headless import）。
- 数据接线（data-only，零代码）：`data/units.json` 每条加 `portrait_path` 字段。triage 原话：「入库后 units.json 每单位补 `"portrait_path": "res://assets/ui/generated/portrait_unit_<id>.png"`，UiArtRegistry.get_portrait_texture 即自动生效于详情页」（unit-identity-three-styles）。`get_portrait_texture` 只读 `portrait_path`/`ui_portrait_path` 两个 cfg 字段（已核实 scripts/ui/ui_art_registry.gd:49-53），字段落上即生效，无需改任何脚本。
- 可选配套（场景侧，非本批工作）：部署卡加头像位——「OperatorCard.tscn TitleStrip 上方加 48px TextureRect 用同一 portrait_path（operator_card.gd `_apply_unit_art()` 已有 cfg，可直接扩展）」；注意「部署卡 164x184 已被名牌+3 条 stat 占满，塞 48px 头像位需与 metal-pill 条目的内部扁平化一起做才有空间」（unit-identity-three-styles）。
- 等图期间过渡（场景侧，可先行）：「_show_cfg_preview/show_unit 里 portrait 为 null 时改用 UiArtRegistry.get_class_icon_texture(cfg)（方法已存在）+ ACCENT_SOFT 底，摆脱首字占位」（avatar-placeholder-glyph）。
- 干员数量提示：「干员数量多……整批生成工作量大，建议先做过渡方案」；可按本期卡池优先级分源图逐张落地，单张落地单条生效，互不阻塞。
