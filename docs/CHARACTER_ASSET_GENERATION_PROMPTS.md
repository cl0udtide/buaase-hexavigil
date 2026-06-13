# 角色与敌人美术生成：提示词与工作流

> 现有干员/敌人 sprite（高饱和赛璐璐、Q 版比例、干净细描边）是**全游戏画风基准，不在重绘范围**——环境美术反过来以它们为同台参照（见 `MAP_ASSET_GENERATION_PROMPTS.md` §1）。本文档只用于**新增**角色/敌人，或个别参考图重绘。生成工具 gpt-image-2 网页端（支持参照图）；有机素材必须附现有 sprite 作参照图，纯 SVG 不适用于角色。
>
> 本文档不管 UI 头像/图标（见 `UI_ASSET_GENERATION_PROMPTS.md`）、地图建筑（见 `MAP_ASSET_GENERATION_PROMPTS.md`）、战斗特效（见 `EFFECT_ASSET_GENERATION_PROMPTS.md`）。

运行时入口（以代码为准）：

- 干员：`scripts/combat/unit_actor.gd` 按 `data/units.json[].visual_key` 加载 `assets/sprites/units/<visual_key>/idle/<visual_key>_idle_000.png`。
- 敌人：`scripts/enemy/enemy_actor.gd` 按 `data/enemies.json[].visual_key` 加载 `assets/sprites/enemies/<visual_key>/idle/<visual_key>_idle_000.png`。
- 入库图为 128x128 透明 PNG，游戏内显示约干员 72px、敌人 70px。

## 1. 画风与硬约束

写提示词与验收只看本节；下面模板不再重复这些约束。

1. **同族基准**：与现有 sprite 完全同族——Q 版二到三头身、高饱和赛璐璐影调（2-3 阶硬影界）、干净的深色细描边、清晰材质分区（金属/布料/皮肤/甲壳）、克制的局部光泽高光。生成时必须附 1-2 张现有 sprite 作参照图，例如 `assets/sprites/units/blaze/idle/blaze_idle_000.png`、`assets/sprites/enemies/hound/idle/hound_idle_000.png`。
2. **角色是主角**：饱和度与对比可明显高于地形建筑；每个角色保留 1-2 个强色彩重音作识别点。发光只作局部识别点，不抢范围提示与战斗特效层级。
3. **视角与朝向**：俯视正交或轻微三分之二俯视；默认朝右或右下（Godot 用 flip_h 处理左向）。不要正面立绘、半身头像、卡牌插画、海报构图、强透视。
4. **轮廓优先**：70-72px 下先读出职业/敌人类型、体型、武器或核心识别点。
5. **构图**：128x128 透明 PNG，主体完整居中略偏下、底部中心为地图锚点、脚底不贴边；顶部与左右留透明边距。普通干员/敌人可见主体约 64-82px，Boss 可放大到约 86-96px。脚底可有极轻接触阴影，但必须包含在 PNG 内、不大到像地面块。
6. **抠图底**：源图用纯色 #FF00FF 背景，最终抠成透明 PNG；边缘干净、低噪点、无洋红残边。
7. **禁画**：背景地块、投影大底座、UI 边框/卡片框/徽章/按钮/头像框、文字、数字、水印、签名；技能特效/弹道/爆炸/范围圈（属特效资产）；写实照片、PBR 3D、霓虹强发光、复杂高频纹理。

## 2. 工作流与入库

- 源图命名：新干员 `assets/sprites/units/raw/unit_source_sheet_<theme>.png`，新敌人 `assets/sprites/enemies/raw/enemy_source_sheet_<theme>.png`，重绘 `assets/sprites/<units|enemies>/raw/<visual_key>_redraw_source.png`。
- 运行时路径必须与 `visual_key` 对齐：`assets/sprites/<units|enemies>/<visual_key>/idle/<visual_key>_idle_000.png`。
- 新增 `visual_key` 时同步改 `data/units.json` 或 `data/enemies.json`，并确认路径存在。
- 多个资产同轮生成时，尺寸、视角、光照、锚点必须一致。
- 改/增 PNG 后跑导入并提交 `.png` 与对应 `.png.import`：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . --quit
```

入库检查：

- `git diff --check` 无空白错误；PNG 是 128x128、透明、无 #FF00FF 残边。
- 路径与 `visual_key` 完全一致，Godot 能按当前逻辑找到文件。
- 在暗色平地、山地、水域、路径线和范围覆盖层上预览，70-72px 下轮廓清楚；Boss 不遮挡邻格单位、敌人路径和攻击范围提示。

## 3. 提示词模板

每轮先抄一遍 §1 的角色描述方向，再追加下面对应块；§1 的硬约束默认生效，提示词里只需补角色专属信息。

### 3.1 单体（新干员或新敌人）

```text
请生成 1 个地图 sprite，纯色背景 #FF00FF，最终裁切为 128x128 透明 PNG。附图是本游戏现有同类 sprite，生成结果必须与之完全同族。

角色信息：
- 类型: <unit / enemy>
- id: <unit_id 或 enemy_id>
- visual_key: <visual_key>
- 显示名: <中文名>
- 定位: <干员职业，或 normal/boss/demolisher/caster/flying/ranged 等敌人类型>
- 移动/攻击方式: <近战/远程/法术/治疗/阻挡/爆炸/召唤；ground/flying>
- 轮廓关键词: <体型、站姿、头部、武器、护甲、族群或核心识别点>
- 主色 / 点缀色: <主色> / <功能或危险重音色>

70px 下先读出类型与武器/威胁，再读出服装或材质细节。飞行单位可略悬浮，但不画巨大地面影子。

目标输出路径：assets/sprites/<units|enemies>/<visual_key>/idle/<visual_key>_idle_000.png
```

### 3.2 批量源图

```text
请生成一张 sprite 源图，纯色背景 #FF00FF，包含 <数量> 个独立资产，按从左到右、从上到下排列。每个资产最终裁切为 128x128 透明 PNG。附图是本游戏现有同类 sprite。

- 所有资产同一视角、同一光照、同一缩放基准、同一底部锚点。
- 资产之间留足纯色背景间距，互不接触、互不投影。

裁切顺序与目标路径：
1. <visual_key_1> -> assets/sprites/<units|enemies>/<visual_key_1>/idle/<visual_key_1>_idle_000.png
2. <visual_key_2> -> assets/sprites/<units|enemies>/<visual_key_2>/idle/<visual_key_2>_idle_000.png

逐项描述：
1. <visual_key_1>: <造型描述：定位、轮廓关键词、主色/点缀色>
2. <visual_key_2>: <造型描述>
```

### 3.3 参考图重绘

把外部概念图或旧资产转成项目内地图 sprite。参考图只用于继承身份、轮廓和关键设计点，不保留原图背景、边框、UI 构图或不适合读图的细节；最终必须转成与现有 sprite（另附）同族。

```text
请基于上传的参考图，重绘为 Godot 俯视塔防游戏内地图 sprite。参考图保留角色身份、主要轮廓、颜色关系和关键识别元素；最终转成与另附现有 sprite 同族的高饱和赛璐璐 Q 版地图实体。

目标信息：
- 类型: <unit / enemy>
- id: <unit_id 或 enemy_id>
- visual_key: <visual_key>
- 显示名: <中文名>
- 用途: <普通干员/普通敌人/Boss/飞行/远程等>
- 必须保留: <从参考图继承的 3-5 个关键识别点>
- 可以简化: <高频纹理、复杂饰品、巨大披风、背景元素等>
- 需要强化: <72px 下最重要的轮廓或颜色识别点>

重新概括体块和细节，让它在 70-72px 下清楚可读。不要保留参考图里的背景、UI 框、文字、光圈、复杂特效或裁切边，不要做成头像、贴纸、卡牌立绘或写实 3D。

目标输出路径：assets/sprites/<units|enemies>/<visual_key>/idle/<visual_key>_idle_000.png
```

## 4. 当前资产状态

截至维护时，`data/units.json` 的全部 28 名干员与 `data/enemies.json` 的全部敌人/Boss 都已生成对应 `idle_000.png` 并入库（`hound_pro` 复用 `hound`、`heavy_defender` 复用 `shieldguard`、`bat`/妖怪无人机用 `monster_drone`）。新增角色时按 §3 出图，并照 §2 对齐 `visual_key`。

唯一保留的参考图重绘实例：**奶龙酋长**（已生成）。

- id `milk_dragon_chief`，显示名 `奶龙酋长·厚鳞形态`，行为 `boss`。
- 运行时 visual_key `milk_dragon_chief_thick_scale`（历史兼容键，不表示单独形态资产）；整场战斗共用同一张 sprite，阶段差异由 `phases` 配置与特效表现。
- 已入库：源图 `assets/sprites/enemies/raw/milk_dragon_chief_redraw_source.png`，运行时图 `assets/sprites/enemies/milk_dragon_chief_thick_scale/idle/milk_dragon_chief_thick_scale_idle_000.png`。
- 需重出时上传奶龙酋长参考图后用以下提示词：

```text
请基于上传的参考图，重绘奶龙酋长为 Godot 俯视塔防 Boss sprite。参考图是外观的唯一依据：保留角色身份、整体轮廓、比例、配色和关键识别元素，转成项目统一的地图实体。

- 类型: enemy boss
- 资产代号: milk_dragon_chief
- 体量按参考图，但需适合 64x64 地图格附近显示；顶部和左右留透明边距，不压满画布。
- 70px 下优先保持参考图主要轮廓和识别点清楚。
- 不要添加参考图里没有的外貌/装备/颜色/状态元素，不要攻击弹道、范围爆发、火焰背景或大外发光。

风格关键词：
vivid cel-shaded chibi boss sprite matching the attached game sprites, clean dark lineart, crisp 2-3 tone shading, top-down tactical fantasy, clean silhouette, map-ready transparent sprite, readable at 70px, no UI frame, no text, no realistic 3D render, no neon glow.
```
