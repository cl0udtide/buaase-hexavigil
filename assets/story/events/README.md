# 随机事件插画 / Event Illustrations

事件弹窗（`scenes/ui/EventPanel.tscn`）左栏插图区使用的事件插画。
数据侧由 `data/events.json` 每页的 `image` 字段指向此目录；
`scripts/ui/event_panel.gd` 在显示事件时加载，**文件不存在时自动回退**到占位字形 `"!"`，
所以未生成的图不会报错、不阻塞游戏运行。

## 规格

- **画风**：角色为主体的事件插画，**由作者提供 ACG 角色参考图锁定形象**；背景是 HexaVigil 的营地/防线/暮色基调，低饱和、不抢戏。
- **比例**：竖版 3:4（弹窗插图卡约 330×430，运行时 `TextureRect` 以 `keep_aspect_covered` 裁切填满）。角色脸与关键道具放中部安全区。
- **禁止**：多余的文字/数字/UI/水印（个别梗里的残缺字母见提示词文档）。
- 提示词见 [`docs/EVENT_ASSET_GENERATION_PROMPTS.md`](../../../docs/EVENT_ASSET_GENERATION_PROMPTS.md)。

## 文件清单（34 张，每个事件页一张、无复用）

每个事件 = 1 张初遇主图 + 每个选项各自的结局图。

| 事件 | 主图 | 结局图 |
|---|---|---|
| 奇怪的商人（菲比） | `event_phoebe` | `event_phoebe_fame`（集体祈祷）· `event_phoebe_all`（黑洞造物）· `event_phoebe_leave`（赶走·商人离去） |
| 持石的好处（要乐奈·军装） | `event_stone` | `event_stone_take`（石头悬挂·开心）· `event_stone_tired`（拒绝·无趣 master） |
| ？！奸商！？（可露希尔） | `event_kroos` | `event_kroos_buy`（买入·递魔力矿）· `event_kroos_sell`（卖出·收情报给声望）· `event_kroos_leave`（收手·不服气） |
| 上古祭坛（塔菲浮雕） | `event_altar` | `event_altar_infused`（祭坛狂笑·灌注）· `event_altar_leave`（离开·嗡鸣远去） |
| 人才市场 | `event_market` | `event_market_mid`（中坚加入）· `event_market_high`（原石引精锐）· `event_market_leave`（无人理会·冷场） |
| 古代仓库（算力集群） | `event_warehouse` | `event_warehouse_loot`（拆解·残缺 NVIDI…）· `event_warehouse_leave`（作罢·大门合拢） |
| 吃什么 | `event_dinner` | `event_dinner_bbq`（烧烤源石虫·吃饱）· `event_dinner_wine`（喝酒微醺·不听指挥） |
| 两把剑（卡提希娅） | `event_swords` | `event_swords_human`（人之剑·奥特尔）· `event_swords_arts`（异之剑·赫格利）· `event_swords_divine`（神之剑·提尔芬） |
| 兵法 | `event_artofwar` | `event_artofwar_arrogant`（骄兵·敌方气运衰）· `event_artofwar_grieving`（哀兵·我方气运升） |
| 粉色奶龙（千早爱音×奶龙） | `event_pinkdragon` | `event_pinkdragon_talk`（递企鹅创可贴）· `event_pinkdragon_shoo`（赶走·委屈哭泣） |

> 文件名 = `data/events.json` 各页 `image` 字段指向的 `<key>.png`，一一对应、无复用。

## 入库流程

1. 用 gpt-image-2 按 `docs/EVENT_ASSET_GENERATION_PROMPTS.md` 生成竖版图（先复制顶层通用提示词、再接对应事件的具体场景，喂角色参考图），按上表文件名存入本目录。
2. 在 Godot 触发导入（或 `Godot --headless --import --path . --quit`），生成 `.png.import`。
3. 提交 `.png` 与 `.png.import`。游戏内打开对应事件即可看到插画；未配的图保持 `"!"` 占位。
