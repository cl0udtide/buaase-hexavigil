# Map Asset Generation Prompts

本文档用于网页端 AI 生图工具连续生成地图地块源图。第一阶段只处理现有 `CommandMap` 的地图格，让中心地图与 `UI_SYSTEM.md` 中的轻薄、低饱和、轻微奇幻战术 HUD 风格保持一致，同时避免过度写实材质化。

当前工程地图渲染入口为 `scripts/map/map_root_view.gd`，单格尺寸为 64x64，材质文件位于 `assets/map/CommandMap/`。本轮不改变代码结构，只替换或补充同名贴图资产。

## 1. 全局提示词

每一轮都先复制本段，再追加对应批次提示词。

```text
我们要为一个 Godot 俯视塔防游戏生成地图地块源图。游戏中心是可读性很高的方形网格地图，四周是轻薄战术 HUD。地图必须是第一视觉层级，但不能和 UI 的深青灰、雾蓝灰、柔和琥珀、灰绿色风格冲突。

当前地图实现：
- 每个地图格最终导出为 64x64 PNG。
- 地图格是正方形俯视视角，不是六边形，不是等距透视，不是 3D 斜视。
- Godot 代码会额外绘制网格线、hover、选中、攻击范围、部署范围和路线预览，所以基础材质不要自带明显粗网格或厚边框。
- 常用格子包括平地、平地变化、未探索迷雾、山地阻挡、水域阻挡、核心、敌人出生点、木材资源、石材资源、魔力资源、随机事件。

整体风格：
- 半卡通手绘、轻微奇幻、战术读图、清爽、低饱和、暗色但不压抑。
- 视觉与 UI 资产一致：低饱和冷灰、深青灰、雾蓝灰作为基础，少量柔和浅金、浅琥珀、灰绿、暗青蓝做功能点缀。
- 地块要像和角色、怪物同一游戏里的卡通化战术地图，不是写实照片、PBR 材质贴图、厚重战争沙盘、卡通糖果地块或高饱和手游地图。
- 使用概括的形状、清晰的剪影和适度的手绘阴影表达类型；不要只靠平铺纹理区分地形。
- 细节要足够在 64x64 下可辨认，但不能嘈杂；远看先读出地形类型，近看再看到少量手绘纹理。

地形硬约束：
- 俯视正交视角，每个资产都是一个独立正方形地块。
- 不要透视地砖，不要等距菱形，不要六边形，不要圆形 token。
- 不要明显厚边框，不要把每个格子画成 UI 按钮、卡片、棋子、徽章或装饰框。
- 不要画固定的角色、建筑、敌人、血条、UI 面板、文字、数字、字母、箭头标签、水印或签名。
- 不要在基础地形中画强烈网格线；每块地可以有非常轻的边缘明暗，但不能形成粗框。
- 不要高纯度霓虹色、浓黑阴影、大面积紫蓝渐变、黑金边、强外发光或复杂花纹。
- 不要把山地、资源点和事件点做成单纯扁平材质块；这些功能格必须有可识别的卡通化主体形状。
- 允许低矮的俯视物件感，例如岩块、木堆、晶簇、符印石、浅水边缘，但必须保持 top-down orthographic，不要变成斜视立绘。

读图硬约束：
- 平地必须是最安静的底层，可承载单位、建筑、路径线和范围高亮。
- 山地和水域必须明显不可通行：山地需要有清楚岩块/小山丘轮廓，水域需要有清楚水面边界和流纹，但颜色不能比 UI 高亮更抢眼。
- 核心和出生点必须是功能地标，但不能像按钮或弹窗，也不能烘入文字标记。
- 资源点与事件点必须在 64x64 缩略图下可分辨：木材看得出木堆/树桩，石材看得出石簇，魔力看得出晶体或法力泉，事件看得出遗迹/符印。主体居中，四周留出单位/建筑叠放空间。
- 所有贴图在 30x30 地图上重复铺开时不能形成刺眼棋盘纹、方向性条纹或大面积噪点。

输出要求：
- 生成一张源图，背景使用纯色 #79C7B6，方便后续裁剪；每个资产之间留足纯色背景间距。
- 每个地块主体为完整正方形，建议源尺寸 256x256 或 512x512，最终裁剪后缩放到 64x64。
- 资产按指定顺序从左到右、从上到下排列，不要互相接触，不要互相投影。
- 地图格本体应为不透明正方形；只有覆盖层或特效类资产才允许透明。
- 输出清晰，边缘干净，适合裁剪后导入 Godot。

如果模型倾向画得太亮，请改为：dark low-saturation tactical fantasy map tiles, base colors around #1E2D2F / #263736 / #2E413A, subtle accents only。
如果模型倾向画成 UI 按钮，请改为：top-down cartoon game map tile, no bevel frame, no button shape, no panel border, readable terrain/object silhouette。
如果模型倾向画成写实照片，请改为：stylized hand-painted cartoon game tile, simplified shapes, clear silhouette, no PBR material, no photo texture, readable at 64x64。
如果模型倾向画得过于扁平，请改为：slightly raised cartoon terrain objects, clear mountain rocks / wood pile / stone cluster / mana crystal, top-down orthographic, still low-saturation。
```

## 2. 保存与裁剪约定

- 每轮生成一张源图，建议保存到 `assets/map/CommandMap/raw/`，命名为 `map_source_sheet_序号_主题.png`。
- 每张图内的资产按“从左到右、从上到下”的顺序裁剪。
- 裁剪后的文件名必须使用批次给出的资产 key，并导出到 `assets/map/CommandMap/`。
- 地图格最终文件尺寸为 64x64 PNG；源图裁剪可以先保留 256x256 或 512x512，再统一缩放。
- 基础地图格默认不透明；覆盖层资产如果后续使用，才导出透明 PNG。
- 如果某一轮出现厚边框、明显透视、强噪点、文字、角色、建筑、UI 按钮感、高饱和霓虹色、写实照片感或纯平面材质块，直接废弃该轮，使用第 9 节纠偏提示重新生成。

## 3. 资产目标清单

第一阶段与当前代码中 preload 的贴图保持同名：

| 资产 key | 当前文件 | 用途 | 视觉目标 |
|---|---|---|---|
| `tile_plain` | `tile_plain.png` | 默认可行走/可建造平地 | 最安静的暗绿灰或冷灰草地/土面 |
| `tile_plain_alt` | `tile_plain_alt.png` | 平地变化格 | 与平地同族，仅有轻微纹理变化 |
| `tile_hidden` | `tile_hidden.png` | 未探索格 | 暗雾遮蔽，信息隐藏但不纯黑 |
| `tile_mountain` | `tile_mountain.png` | 山地阻挡 | 卡通化低矮岩块/小山丘，明显不可通行 |
| `tile_water` | `tile_water.png` | 水域阻挡 | 暗青蓝浅水块，边界和流纹清楚 |
| `tile_core` | `tile_core.png` | 核心所在地 | 柔和核心晶体/能量基座地标，偏青蓝/琥珀 |
| `tile_spawn` | `tile_spawn.png` | 敌人出生点 | 克制危险裂隙/入口地标，暗红灰/琥珀提示 |
| `tile_resource_wood` | `tile_resource_wood.png` | 木材资源点 | 清晰小木堆/树桩/根须主体 |
| `tile_resource_stone` | `tile_resource_stone.png` | 石材资源点 | 清晰小石簇/矿石堆主体 |
| `tile_resource_mana` | `tile_resource_mana.png` | 魔力资源点 | 清晰青蓝晶簇/法力泉主体 |
| `tile_event` | `tile_event.png` | 随机事件点 | 清晰小遗迹/符印石/未知痕迹主体 |

后续如果要替换代码绘制的范围、路线、hover 状态，可再接入第 7 轮覆盖层资产；本阶段可以先只生成 source sheet，不改渲染逻辑。

## 4. 第 1 轮：基础地形与阻挡地块

保存源图为：`map_source_sheet_01_base_terrain.png`

裁剪顺序：

1. `tile_plain`
2. `tile_plain_alt`
3. `tile_hidden`
4. `tile_mountain`
5. `tile_water`

```text
请生成一张地图地块源图，纯色背景 #79C7B6，包含 5 个独立正方形俯视地块，按从左到右排列。每个地块建议 256x256，最终会缩放到 64x64。风格是低饱和半卡通手绘，与游戏角色和怪物同一视觉体系。不要文字、数字、角色、建筑、UI 边框、粗网格线、照片材质。

1. tile_plain：默认平地。低饱和暗绿灰与冷灰土面混合，手绘简化草痕和少量小石粒，中心干净，适合放置单位或建筑。不要写实草皮贴图，不要鲜绿草坪，不要花田，不要大图案。
2. tile_plain_alt：平地变化格。与 tile_plain 同色系，只加入轻微土色变化、浅草斑或柔和手绘块面，远看仍像平地。不要让它像资源点或阻挡物。
3. tile_hidden：未探索迷雾格。深青灰卡通暗雾覆盖，隐约有地形轮廓但信息被遮住，不纯黑，不发紫，不画问号。
4. tile_mountain：山地阻挡。地块上有 2-4 个低矮卡通岩块或小山丘轮廓，冷灰岩面、浅苔痕和简化阴影，明显不可通行。不要只画石头纹理平面，不要高耸写实山峰，不要等距山体，不要厚黑轮廓。
5. tile_water：水域阻挡。低饱和暗青蓝浅水块或湿地水洼，有清楚水面边界、简化流纹和少量手绘高光，明显与平地区分。不要只铺蓝色纹理，不要高亮蓝色，不要海浪，不要反光过强。

整体必须是 top-down orthographic square cartoon game map tiles, restrained tactical fantasy, low saturation, clear silhouettes, readable at 64x64, no perspective, no bevel frame, no photo texture。
```

## 5. 第 2 轮：核心与出生点地标

保存源图为：`map_source_sheet_02_core_spawn.png`

裁剪顺序：

1. `tile_core`
2. `tile_spawn`

```text
请生成一张地图地块源图，纯色背景 #79C7B6，包含 2 个独立正方形俯视地块，按从左到右排列。每个地块建议 256x256，最终会缩放到 64x64。风格是低饱和半卡通手绘，地标剪影清楚。不要文字、数字、箭头、角色、敌人、建筑、UI 面板、照片材质。

1. tile_core：核心所在地。基底仍是低饱和暗绿灰/冷灰地面，中心有一个清晰但克制的卡通核心晶体、能量基座或核心符印，偏柔和青蓝与少量琥珀。它是地图目标点，不是 UI 按钮，不要厚边框，不要巨大水晶立绘，不要强外发光。
2. tile_spawn：敌人出生点。基底仍属于同一地图地表，中心有可识别的暗红灰裂隙、低矮入口痕迹或危险符纹，表示敌人会从这里出现。不要只画红色地面纹理，不要画怪物、门牌、文字、血红传送门或强烈火焰。

这两个地标要比普通地形更醒目，靠形状和剪影识别，而不是靠高饱和发光。不能压过单位、路径线和 HUD 高亮。保持 top-down square cartoon tile, clean tactical fantasy, clear but restrained landmark, no UI button appearance。
```

## 6. 第 3 轮：资源点与事件点

保存源图为：`map_source_sheet_03_resources_events.png`

裁剪顺序：

1. `tile_resource_wood`
2. `tile_resource_stone`
3. `tile_resource_mana`
4. `tile_event`

```text
请生成一张地图地块源图，纯色背景 #79C7B6，包含 4 个独立正方形俯视地块，按从左到右排列。每个地块建议 256x256，最终会缩放到 64x64。风格是低饱和半卡通手绘，资源主体必须一眼可辨。不要文字、数字、资源图标徽章、UI 徽章、角色或建筑。

1. tile_resource_wood：木材资源点。低饱和平地基底上有清晰的小木堆、树桩截面、根须或几段原木，主体居中但不要占满整格。色彩为暗灰绿与柔和木褐，不能变成完整树木或建筑。不要只画棕色地面纹理。
2. tile_resource_stone：石材资源点。低饱和平地基底上有清晰小石簇、矿石堆或几块卡通化石料，冷灰色为主，少量青灰高光。不要只画灰色地表纹理，不要画巨大岩山，避免和 tile_mountain 混淆。
3. tile_resource_mana：魔力资源点。低饱和平地基底上有清晰小青蓝晶簇、法力泉或发光矿核。发光必须克制，不能霓虹，不能画成大魔法阵按钮。不要只画蓝色纹路。
4. tile_event：随机事件点。低饱和平地基底上有清晰小遗迹碎片、符印石、破碎碑片或未知痕迹，颜色偏雾蓝灰和少量柔和紫灰/琥珀。不要画问号、感叹号、文字、宝箱或完整祭坛。

四个资源/事件格必须共享同一套地图地表风格，通过居中的卡通化小主体区分功能。主体应该像地图上的自然资源/遗迹，不是 UI 图标徽章。保持 readable at 64x64, clear silhouette, no icon badge, no thick outline, no UI card, no photo texture。
```

## 7. 第 4 轮：可选覆盖层素材

保存源图为：`map_source_sheet_04_overlays_optional.png`

裁剪顺序：

1. `overlay_map_hover`
2. `overlay_map_selected`
3. `overlay_attack_range`
4. `overlay_building_range`
5. `overlay_deploy_valid`
6. `overlay_deploy_invalid`
7. `overlay_route_line`
8. `overlay_route_warning`

```text
请生成一张地图覆盖层源图，纯色背景 #79C7B6，包含 8 个独立覆盖层资产，按从左到右、从上到下排列。覆盖层最终用于叠在 64x64 地图格或路径线上，导出时需要透明背景。不要文字、数字、箭头标签、完整 UI 面板。

1. overlay_map_hover：鼠标悬停格高亮，64x64。极薄浅琥珀内光或角标，中心透明，不要厚边框。
2. overlay_map_selected：已选中格高亮，64x64。低饱和青蓝细线或轻微内光，中心透明。
3. overlay_attack_range：攻击范围格，64x64。透明青蓝填充与极细边缘，不能遮住地形和单位。
4. overlay_building_range：建筑影响范围格，64x64。透明灰绿色填充与极细边缘。
5. overlay_deploy_valid：可部署格，64x64。透明青绿确认状态，克制，不要强荧光。
6. overlay_deploy_invalid：不可部署格，64x64。透明暗红警示状态，低饱和，不要刺眼。
7. overlay_route_line：敌人路线线段，约 96x24。可重复拼接的柔和琥珀/青蓝路线能量线，透明背景，不要箭头文字。
8. overlay_route_warning：路线异常线段，约 96x24。暗红灰警示线，透明背景，不要感叹号。

这些覆盖层必须轻薄、半透明、服务读图。不要做成 UI 按钮、粗描边、贴纸或大面积发光。
```

## 8. 裁剪后入库检查

- 文件名必须与第 3 节资产 key 一致，例如 `tile_plain.png`、`tile_resource_mana.png`。
- 导入路径保持 `assets/map/CommandMap/`，避免改动 `map_root_view.gd` 的 preload 路径。
- 单格最终尺寸为 64x64；同一批次缩放算法保持一致，避免清晰度不统一。
- 把 `tile_plain` 和 `tile_plain_alt` 在 10x10 区域内重复铺开检查：不能出现明显棋盘、接缝、强方向纹理。
- 把 `tile_mountain`、`tile_water` 与平地混排检查：必须靠形状一眼看出阻挡，山地不能只是灰色纹理，水域不能只是蓝色平面。
- 把资源点缩小到 64x64 检查：木、石、魔力三类不能互相混淆，且不能只是不同颜色的地表纹理。
- 用 1920x1080、1366x768 两个视口检查：地图在 HUD 下仍然可读，范围高亮、路线预览、单位和建筑不会被材质噪点淹没。
- 如果后续接入覆盖层资产，先保留当前代码绘制逻辑作为 fallback，不要一次性移除程序化高亮。

## 9. 纠偏提示词

### 9.1 太像 UI 按钮或卡片

```text
请重画为俯视地图地形材质，不要 UI 按钮，不要卡片，不要面板边框，不要 bevel，不要厚边框。每个资产是 top-down square terrain tile，地表自然材质为主，只保留极轻边缘明暗。
```

### 9.2 太写实或照片感太强

```text
请改为 stylized cartoon game-ready top-down map tile，低饱和手绘感，形状概括，剪影清楚，64x64 下清晰可读。不要照片纹理，不要真实地表扫描，不要 PBR 材质，不要高频噪点。
```

### 9.3 颜色太亮或太糖果化

```text
请降低饱和度与亮度，保留卡通化手绘形状，但使用暗青灰、雾蓝灰、暗灰绿作为主色，只有极少量柔和琥珀或青蓝点缀。不要鲜绿、亮蓝、纯红、霓虹紫、糖果色。
```

### 9.4 地形类型不够清楚

```text
请强化功能差异但保持同一画风：平地更安静，山地用清楚的低矮岩块或小山丘表示不可通行，水域用暗青蓝水块和边界流纹表示不可通行，资源点用居中的卡通化小主体区分木堆、石簇、魔力晶簇，核心和出生点作为克制地标。不要使用文字或图标标签。
```

### 9.5 重复铺开后太乱

```text
请减少纹理噪点和方向性图案，降低对比度，中心保持干净。地块需要在 30x30 网格中大量重复，不能产生刺眼棋盘纹、条纹或明显接缝。
```

### 9.6 透视错误

```text
请改成正交俯视 top-down square tile。不要 isometric，不要斜视透视，不要 3D 山峰，不要菱形地砖，不要六边形格。
```

### 9.7 太扁平或像普通材质块

```text
请不要只生成平铺材质纹理。改为低饱和半卡通地块：山地要有可识别的岩块/小山丘主体，木材要有木堆或树桩主体，石材要有石簇主体，魔力要有晶簇或法力泉主体，事件要有遗迹碎片或符印石主体。保持俯视正交，不要斜视，不要 UI 图标徽章。
```

## 10. 第二阶段：地图建筑资产提示词

本节用于生成地图上实际摆放的建筑 sprite，不是建筑列表里的 UI 图标。新 UI 美术里已经有 `assets/ui/generated/icon_building_*.png`，这些图标可以作为造型参考，但不要直接替换地图建筑贴图：

- UI 图标是非方形大图，尺寸通常在 200-330px 之间。
- 当前建筑渲染入口为 `scripts/building/building_actor.gd`，默认按 `assets/sprites/buildings/` 下的 `128x128` 透明 PNG 加载。
- 建筑在地图上显示尺寸约为 72 世界单位，必须能压进一个地图格附近，不应遮挡邻格单位、路线或范围高亮。
- 地图建筑需要有“落在地块上”的小型实体感，不能像 UI 图标、徽章、贴纸或按钮。

建议流程：

1. 先用 UI 建筑图标作为 reference image 或视觉参考，保留图标的主体概念。
2. 重新生成为地图建筑 sprite：透明背景、128x128 最终输出、主体居中偏下、底部中心为锚点。
3. 普通建筑可以直接覆盖 `assets/sprites/buildings/<visual_key>.png`。
4. `war_shrine` 需要保留 `war_shrine_inactive.png` 与 `war_shrine_active.png` 两个状态。
5. `wood_wall` 需要保留 16 个连接变体，不能只用一张 UI 木墙图标替换。

### 10.1 建筑全局提示词

每一轮建筑生成都先复制本段，再追加对应批次提示词。

```text
我们要为一个 Godot 俯视塔防游戏生成地图建筑 sprite。建筑会被放在 64x64 地图格上方，最终导出为 128x128 透明 PNG，并在游戏中缩放到约 72px 显示。

整体风格：
- 低饱和半卡通手绘，轻微奇幻塔防，和现有 UI 图标、角色、怪物、地图地块属于同一游戏。
- 比 UI 图标更像地图实体：有简化体积、轻微顶面和侧面、底部接触阴影，但不要变成复杂写实 3D 模型。
- 允许轻微三分之二俯视伪 3D 体积，用来表达高度；不要等距菱形底座，不要大透视建筑插画。
- 主体轮廓必须在 72px 显示尺寸下清楚，优先读出建筑类型，而不是展示复杂内部细节。
- 色彩以暗青灰、雾蓝灰、灰绿、木褐、石灰为主，少量柔和青蓝、琥珀、暗红作为功能点缀。

硬约束：
- 最终单张资产为 128x128 透明 PNG，主体完整，不被裁切。
- 主体居中偏下，底部中心作为地图锚点；底部不能贴边，顶部不能顶到画布边缘。
- 不要背景地块、网格线、UI 边框、卡片底板、徽章底座、文字、数字、图标标签、水印或签名。
- 不要厚黑描边、霓虹强发光、金属 UI 边框、按钮高光、照片/PBR 材质或高频噪点。
- 允许非常轻的接触阴影，但阴影不能大到覆盖整格。
- 需要适配暗色低饱和地图地块，不能太亮、太纯、太像独立 UI 图标。

如果使用 UI 建筑图标作为参考图：请只继承主体设计语言和识别元素，把它重绘成地图上可放置的小型建筑 sprite，不要保留 UI 图标构图、外框、底板或夸张居中海报感。
```

### 10.2 第 5 轮：普通建筑地图 Sprite

保存源图为：`building_source_sheet_01_core_buildings.png`

裁剪顺序：

1. `lumber_station`
2. `stone_quarry`
3. `mana_extractor`
4. `medical_station`
5. `gravity_tower`
6. `inspiring_monolith`

目标输出路径：

```text
assets/sprites/buildings/lumber_station.png
assets/sprites/buildings/stone_quarry.png
assets/sprites/buildings/mana_extractor.png
assets/sprites/buildings/medical_station.png
assets/sprites/buildings/gravity_tower.png
assets/sprites/buildings/inspiring_monolith.png
```

```text
请生成一张地图建筑 sprite 源图，纯色背景 #79C7B6，包含 6 个独立建筑，按从左到右排列。每个建筑最终会裁剪到 128x128 透明 PNG，并在 64x64 地图格上以约 72px 显示。风格是低饱和半卡通手绘、轻微奇幻塔防地图实体。不要文字、数字、UI 边框、图标底板、徽章、卡片、地图地块背景。

1. lumber_station：伐木站。小型木料棚、短木桩、捆扎原木和简化支架，木褐与暗灰绿为主。轮廓要像资源生产建筑，不要变成 UI 木材图标，也不要太大像房屋。
2. stone_quarry：石矿场。小型采石台、几块灰色石料、简化木架或采石标记，冷灰石块清楚。不要画成巨大山体，不要和地图石材资源点混淆。
3. mana_extractor：魔力抽取器。低矮基座围住青蓝晶体或小型抽取柱，柔和青蓝点缀，发光克制。不要强霓虹，不要变成大水晶立绘。
4. medical_station：医疗站。小型治疗帐篷/站台、浅色医疗旗或十字识别元素，青蓝治疗灯光克制。不要画成现代医院，不要大红十字按钮。
5. gravity_tower：重力塔。小型塔芯、向下力场部件、石金属底座，冷灰与青蓝点缀，轮廓竖向但不能过高。不要强电弧，不要大范围特效。
6. inspiring_monolith：鼓舞石碑。低矮石碑或符文方尖碑，柔和琥珀/青蓝符纹，底座稳重。不要过高，不要做成随机事件遗迹，不要强外发光。

每个建筑都要有地图实体感，像放在格子上的小建筑，主体完整、底部锚点清楚、透明背景、无地面方块。保持 readable at 72px, clean silhouette, low-saturation tactical fantasy, not UI icon, not realistic 3D render。
```

### 10.3 第 6 轮：战火圣坛状态

保存源图为：`building_source_sheet_02_war_shrine_states.png`

裁剪顺序：

1. `war_shrine_inactive`
2. `war_shrine_active`

目标输出路径：

```text
assets/sprites/buildings/war_shrine_inactive.png
assets/sprites/buildings/war_shrine_active.png
```

```text
请生成一张地图建筑 sprite 源图，纯色背景 #79C7B6，包含 2 个独立建筑状态，按从左到右排列。最终每个资产裁剪为 128x128 透明 PNG。风格低饱和半卡通手绘，与普通建筑同一套地图实体风格。不要文字、数字、UI 边框、图标底板、徽章、地图地块背景。

1. war_shrine_inactive：关闭状态的战火圣坛。低矮石质祭坛、暗红灰和冷灰石材，中心火焰熄灭或只剩微弱余烬。轮廓能看出是祭坛，但整体安静，不应像敌人出生点。
2. war_shrine_active：开启状态的战火圣坛。与关闭状态结构完全一致，中心有低饱和琥珀/暗红火焰或能量核心，少量柔和光照，表现正在提供攻击增益。不要巨大火柱，不要强红光，不要遮住建筑本体。

两个状态必须尺寸、视角、锚点、建筑主体结构一致，只通过火焰/能量强度区分开关。保持 readable at 72px, same silhouette, transparent background, no UI icon appearance。
```

### 10.4 第 7 轮：木墙连接变体

保存源图为：`building_source_sheet_03_wood_wall_variants.png`

裁剪顺序：

1. `wood_wall_0000_isolated`
2. `wood_wall_0001_n`
3. `wood_wall_0010_e`
4. `wood_wall_0011_ne`
5. `wood_wall_0100_s`
6. `wood_wall_0101_ns`
7. `wood_wall_0110_es`
8. `wood_wall_0111_nes`
9. `wood_wall_1000_w`
10. `wood_wall_1001_nw`
11. `wood_wall_1010_ew`
12. `wood_wall_1011_new`
13. `wood_wall_1100_sw`
14. `wood_wall_1101_nsw`
15. `wood_wall_1110_esw`
16. `wood_wall_1111_nesw`

目标输出路径：

```text
assets/sprites/buildings/wood_wall/wood_wall_0000_isolated.png
assets/sprites/buildings/wood_wall/wood_wall_0001_n.png
assets/sprites/buildings/wood_wall/wood_wall_0010_e.png
assets/sprites/buildings/wood_wall/wood_wall_0011_ne.png
assets/sprites/buildings/wood_wall/wood_wall_0100_s.png
assets/sprites/buildings/wood_wall/wood_wall_0101_ns.png
assets/sprites/buildings/wood_wall/wood_wall_0110_es.png
assets/sprites/buildings/wood_wall/wood_wall_0111_nes.png
assets/sprites/buildings/wood_wall/wood_wall_1000_w.png
assets/sprites/buildings/wood_wall/wood_wall_1001_nw.png
assets/sprites/buildings/wood_wall/wood_wall_1010_ew.png
assets/sprites/buildings/wood_wall/wood_wall_1011_new.png
assets/sprites/buildings/wood_wall/wood_wall_1100_sw.png
assets/sprites/buildings/wood_wall/wood_wall_1101_nsw.png
assets/sprites/buildings/wood_wall/wood_wall_1110_esw.png
assets/sprites/buildings/wood_wall/wood_wall_1111_nesw.png
```

连接方向说明：文件名后缀按 N/E/S/W 四个方向编码，例如 `0001_n` 表示只向北连接，`1010_ew` 表示东西连接，`1111_nesw` 表示四向连接。

```text
请生成一张木墙地图建筑 sprite 源图，纯色背景 #79C7B6，包含 16 个独立木墙连接变体，按 4x4 网格排列。最终每个资产裁剪为 128x128 透明 PNG，并在地图上以约 72px 显示。风格是低饱和半卡通木栅墙，和 UI 木墙图标同一设计语言，但必须是地图实体，不是图标。

统一要求：
- 木墙由短木桩、横向绑绳、尖木桩或简化木板组成，木褐、暗灰绿和少量冷灰阴影。
- 所有变体高度、厚度、锚点、材质一致，连接端必须对齐到相邻格方向，连续摆放时能拼成墙线。
- 每个变体都在 128x128 透明画布中居中，墙体不要触碰画布边缘，但连接方向要明显靠近对应边。
- 不要地面方块、UI 底板、文字、数字、方向箭头、墙体标签、金属科幻墙或写实木纹。
- 远看要先读出“阻挡墙”和连接方向，近看再看到木桩和绑绳。

请按以下顺序生成：
1. wood_wall_0000_isolated：孤立短木墙，小型独立栅栏段，四边不连接。
2. wood_wall_0001_n：向北连接，有上方连接端。
3. wood_wall_0010_e：向东连接，有右侧连接端。
4. wood_wall_0011_ne：向北和向东连接，转角形。
5. wood_wall_0100_s：向南连接，有下方连接端。
6. wood_wall_0101_ns：南北直线墙。
7. wood_wall_0110_es：向东和向南连接，转角形。
8. wood_wall_0111_nes：北东南三向连接。
9. wood_wall_1000_w：向西连接，有左侧连接端。
10. wood_wall_1001_nw：向北和向西连接，转角形。
11. wood_wall_1010_ew：东西直线墙。
12. wood_wall_1011_new：北东西三向连接。
13. wood_wall_1100_sw：向南和向西连接，转角形。
14. wood_wall_1101_nsw：南北西三向连接。
15. wood_wall_1110_esw：东西南三向连接。
16. wood_wall_1111_nesw：四向连接，十字/节点墙。

所有木墙变体必须能互相拼接，连接端位置统一，不能每张重新设计墙的高度、颜色或粗细。保持 map-ready transparent sprite, compact readable wall, no UI icon badge。
```

### 10.5 第 8 轮：损毁建筑通用残骸

保存源图为：`building_source_sheet_04_destroyed.png`

裁剪顺序：

1. `generic_destroyed_building`

目标输出路径：

```text
assets/sprites/buildings/generic_destroyed_building.png
```

```text
请生成一张通用损毁建筑地图 sprite，纯色背景 #79C7B6，只包含 1 个资产，最终裁剪为 128x128 透明 PNG。风格为低饱和半卡通手绘，与普通建筑同一地图实体体系。不要文字、数字、UI 边框、地面方块、火焰特效或角色。

generic_destroyed_building：小型通用建筑残骸。破碎木板、低矮石块、少量灰烬和弯折支架，暗灰、木褐、冷灰为主。应能代表任意建筑损毁后的残骸，但不要像敌人出生点、随机事件遗迹或资源点。轮廓低矮，不遮挡单位和路线，底部锚点居中。

保持 readable at 72px, transparent background, restrained damage, no strong fire, no smoke cloud, no UI icon appearance。
```

### 10.6 建筑资产入库检查

- 输出文件必须是透明 PNG，最终尺寸为 128x128。
- 普通建筑文件名必须和 `data/buildings.json` 中的 `visual_key` 对齐。
- `war_shrine` 必须保留 active / inactive 两个状态，结构一致、差异清楚。
- `wood_wall` 必须检查 16 个连接变体在地图上连续摆放时能对齐；尤其检查 `1010_ew`、`0101_ns`、`1111_nesw`。
- 把建筑叠在 `tile_plain`、`tile_resource_wood`、`tile_resource_stone`、`tile_resource_mana` 上预览：不能遮住资源主体到不可读，也不能被地块噪点淹没。
- 在 1920x1080 和 1366x768 视口中检查：建筑、单位、范围覆盖层、路径线同时存在时仍能分清层级。
- 如果使用 UI 图标作为参考，检查最终资产是否已经从“图标”转化为“地图实体”；不能保留图标式海报构图和 UI 底板感。

### 10.7 建筑纠偏提示词

#### 10.7.1 太像 UI 图标

```text
请把它重画成地图上摆放的小型建筑 sprite，不要图标构图，不要徽章感，不要居中海报式大物件。主体需要有底部锚点、轻微体积和接触阴影，透明背景，适合放在 64x64 地图格上。
```

#### 10.7.2 建筑太大或遮挡邻格

```text
请缩小主体体积，保留 128x128 透明画布，但建筑实际可见轮廓控制在画布中部约 72-88px 范围内，顶部和左右留白，底部锚点居中。不能遮挡相邻地图格。
```

#### 10.7.3 太写实或太 3D

```text
请改为低饱和半卡通手绘塔防建筑，形状概括，材质简化，轮廓清楚。不要写实建筑渲染、PBR 材质、复杂机械细节或强透视。
```

#### 10.7.4 木墙连接不齐

```text
请保持所有木墙变体相同高度、厚度、颜色和锚点。连接端必须统一对齐到 N/E/S/W 四个方向，连续摆放时形成一条完整墙线。不要每个变体重新设计不同墙体。
```

## 11. 第三阶段：高台地形与人工高台（TODO，地形包迭代用）

> **状态：TODO**——本节资产服务于"地形包"迭代（设计稿：动态地图生成终案），实装由 AI 完成，生成工具使用 gpt-image-2。生成与裁剪约定同第 2 节。**资产未就绪前的占位方案**：`tile_highland` 由代码侧复制 `tile_mountain` 加暖黄 modulate 占位；人工高台建筑暂用 `inspiring_monolith.png` + 建筑列表 icon_text"台"占位。

### 11.1 资产清单

| 资产 key | 输出路径 | 用途 | 视觉目标 |
|---|---|---|---|
| `tile_highland` | `assets/map/CommandMap/tile_highland.png` | 高台地形格（敌不可走、仅远程干员可部署） | 卡通化平顶台地/崖缘平台，暖赭色调与山地冷灰明确区分 |
| `artificial_platform` | `assets/sprites/buildings/artificial_platform.png` | 人工高台建筑（玩家建造的木石炮台基座，可载干员） | 低矮木石结构平台，看得出"上面能站人" |
| `tile_ford` | `assets/map/CommandMap/tile_ford.png` | 渡口浅滩格（v1.5 可选） | 水面中的可通行浅滩/碎石滩 |

### 11.2 第 9 轮：高台地形格

保存源图为：`map_source_sheet_05_highland.png`，裁剪顺序：1. `tile_highland` 2. `tile_ford`

```text
（先复制第 1 节全局提示词，再追加本段）

请生成一张地图地块源图，纯色背景 #79C7B6，包含 2 个独立正方形俯视地块，按从左到右排列。每个地块建议 256x256，最终缩放到 64x64。风格与已有地块一致：低饱和半卡通手绘。不要文字、数字、UI 边框、粗网格线。

1. tile_highland：高台地形格。卡通化平顶台地：边缘是清晰的崖缘/石阶剪影表示与平地的高差，顶面是干净开阔的平台面（之后会有干员单位站在上面，中心必须留白可叠放）。主色用暖赭/土黄与浅岩灰，与 tile_mountain 的冷灰岩块、tile_plain 的暗绿灰都拉开明确色相差。远看一眼能读出"这是一块高起来的可站立平台"，不是山、不是墙。不要画梯子、旗帜、建筑、人物，不要画成悬浮岛或祭坛。
2. tile_ford：渡口浅滩格。在 tile_water 同款暗青蓝水面中，有一条由碎石/沙洲构成的可通行浅滩带，水纹在浅滩两侧断开，浅滩本体颜色接近平地土面表示可以走。不要画桥（木桥是建筑感）、不要画完整道路，保持自然浅滩感。

两格必须与现有 tile_plain / tile_mountain / tile_water 同一画风，铺在一起无违和。保持 top-down orthographic square cartoon game map tiles, readable at 64x64。
```

### 11.3 第 10 轮：人工高台建筑 Sprite

保存源图为：`building_source_sheet_05_artificial_platform.png`，裁剪顺序：1. `artificial_platform`

```text
（先复制第 10.1 节建筑全局提示词，再追加本段）

请生成一张地图建筑 sprite 源图，纯色背景 #79C7B6，只包含 1 个建筑，最终裁剪为 128x128 透明 PNG，在 64x64 地图格上以约 72px 显示。风格与已有建筑（木墙、鼓舞石碑）同一套低饱和半卡通地图实体。不要文字、数字、UI 边框、底板。

artificial_platform：人工高台。玩家用木材和石材搭建的低矮方形炮台基座：木桩框架 + 石块基础 + 顶面平整的木板平台，可以看出顶面是留给干员站立的（顶面居中留白，不要画人）。高度感克制（约半格高的伪 3D 体积），比木墙更厚重、更像"工事"而不是"栅栏"。木褐 + 冷石灰为主，少量绑绳/铆钉细节。损毁状态沿用 generic_destroyed_building，无需单独生成。不要画成箭塔/炮塔（塔身封闭无站位）、不要瞭望塔高架、不要旗帜火把。

保持 readable at 72px, transparent background, bottom-center anchor, same visual family as wood_wall and inspiring_monolith。
```

### 11.4 入库检查（追加）

- `tile_highland` 与 `tile_mountain` 并排铺开必须一眼可分（色相差 + 平顶 vs 岩块剪影）；与单位 sprite 叠放时顶面留白足够。
- `artificial_platform` 顶面叠放狙击/术师单位 sprite 后，单位剪影不被平台细节淹没。
- `tile_ford` 嵌进 tile_water 河道中段时，水纹衔接自然、浅滩可读为"能走"。
