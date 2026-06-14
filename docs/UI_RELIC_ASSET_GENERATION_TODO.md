# UI Relic Asset Generation TODO

本文档记录遗物 UI 新素材的生成、裁切和接入要求。生成后不要直接改运行时资源，应先放入 `assets/ui/source/`，再通过离线派生脚本生成 `assets/ui/generated/` 与 `assets/ui/styles/` 中的正式稳定资源。

## 1. 遗物 UI 框架补充素材

保存源图为：`source_sheet_35_relic_ui_refresh.png`

裁剪顺序：

1. `frame_relic_entry_button_base`
2. `frame_relic_rarity_common_backplate`
3. `frame_relic_rarity_uncommon_backplate`
4. `frame_relic_rarity_rare_backplate`
5. `frame_relic_rarity_common_card_base`
6. `frame_relic_rarity_uncommon_card_base`
7. `frame_relic_rarity_rare_card_base`

```text
请生成一张 UI 资产源图，纯色背景 #FF00FF，包含 7 个独立资产，按裁剪顺序排列。不要文字、数字、遗物图标、固定槽位或完整界面截图。

这批用于 Godot 塔防游戏的遗物摘要入口、遗物小图标承托和遗物卡底板。整体延续清新战术奇幻 UI：低饱和暗色基底、轻盈、清楚、带一点奇幻工艺感。不同稀有度要有明显但克制的差异：
- common / 常见：冷灰蓝、简洁、低亮度。
- uncommon / 稀有：青绿或蓝绿色微光，更精致。
- rare / 史诗：暖金或紫金点缀，更醒目但不要刺眼。

资产说明：
1. frame_relic_entry_button_base：RelicStrip 的入口按钮底板，用于放运行时“遗物 N”和背包图标；不要内置文字、数字、图标。
2. frame_relic_rarity_common_backplate：常见遗物图标背板，用于 RelicIcon 和 RelicCard 的 IconBackplate。
3. frame_relic_rarity_uncommon_backplate：稀有遗物图标背板，同尺寸同轮廓，但颜色和细节更高级。
4. frame_relic_rarity_rare_backplate：高稀有度遗物图标背板，同尺寸同轮廓，但有更明显的高级感。
5. frame_relic_rarity_common_card_base：常见遗物卡底板，用于承载图标、名称、稀有度、效果说明。
6. frame_relic_rarity_uncommon_card_base：稀有遗物卡底板，同结构但颜色和局部装饰区分。
7. frame_relic_rarity_rare_card_base：高稀有度遗物卡底板，同结构但更有仪式感。

NinePatch / 9-slice 要求：
- 所有 `frame_*` 都必须适合 Godot StyleBoxTexture 九宫格。
- 四边拉伸区不能有徽章、文字、数字、独特符号或不可变形花纹。
- 特殊装饰只能放四角或短边保护区，中心保持干净，方便放运行时文字。
- 三个 backplate 的外轮廓和尺寸应一致，三个 card_base 的外轮廓和尺寸应一致。

Chroma-key 要求：
- 背景必须是完全纯净的 #FF00FF 实色。
- 资产边缘干净，不要把 #FF00FF 混进主体边缘。
- 不要水印、签名、伪 UI 标签、文字、数字。
```

裁切后替换/新增：

- 覆盖 `assets/ui/source/frame_relic_entry_button_base.png`。
- 新增 `assets/ui/source/frame_relic_rarity_common_backplate.png`。
- 新增 `assets/ui/source/frame_relic_rarity_uncommon_backplate.png`。
- 新增 `assets/ui/source/frame_relic_rarity_rare_backplate.png`。
- 新增 `assets/ui/source/frame_relic_rarity_common_card_base.png`。
- 新增 `assets/ui/source/frame_relic_rarity_uncommon_card_base.png`。
- 新增 `assets/ui/source/frame_relic_rarity_rare_card_base.png`。

接入时同步：

- 为新增 6 个稀有度底板补 `assets/ui/templates/*.tres` 和 `assets/ui/build/ui_asset_build.json` 配置。
- 运行 `Godot --headless --path . --script scripts/tools/generate_ui_derived_assets.gd`。
- 将 `RelicIcon.tscn` / `RelicCard.tscn` 中的稀有度底板拆成可显示/隐藏的场景节点，脚本只根据 rarity 切换 visible，不在脚本里改位置和尺寸。

## 2. 遗物图标缺口

当前 `data/buffs.json` 中遗物没有 `icon_path` / `ui_icon_path` / `icon_key`，所以 `RelicIcon` 和 `RelicCard` 都会 fallback 到 `icon_relic_bag`。需要为以下所有遗物补图标。

生成后裁切到：

- `assets/ui/source/icon_relic_<id_without_relic_prefix>.png`

离线生成到：

- `assets/ui/generated/icon_relic_<id_without_relic_prefix>.png`

数据接入：

- 在对应 `data/buffs.json` 条目增加 `icon_path: "res://assets/ui/generated/icon_relic_xxx.png"`。
- 不要写运行时状态，不要写绝对路径。

## 3. 遗物图标第一批

保存源图为：`source_sheet_36_relic_icons_a.png`

裁剪顺序：

1. `icon_relic_legion_mirror`：军团护心镜，防御护心镜/镜面护符。
2. `icon_relic_first_aid_kit`：急救药箱，医疗箱、药瓶、绷带。
3. `icon_relic_noble_rapier`：贵族刺剑，细长刺剑。
4. `icon_relic_silver_fork`：银餐叉，精致银叉。
5. `icon_relic_gaul_bank_check`：高卢银行支票，票据、印章、金融凭证。
6. `icon_relic_water_of_life`：生命之水，发光药水瓶。
7. `icon_relic_gargoyle_statuette`：石像鬼塑像，小石雕。
8. `icon_relic_torn_photo`：残破合影，撕裂照片。
9. `icon_relic_emperors_collection`：皇帝的收藏，华贵收藏盒或宝匣。
10. `icon_relic_certificate_of_longevity`：长生者之证，古老证书/印记。

```text
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 10 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是遗物卡中的小物件图标。每个图标是独立物件，不带 UI 边框。风格：清新战术奇幻、低饱和、轻微工艺感、小尺寸仍然清楚。图标主体要居中，留足 #FF00FF 间距，边缘干净。
```

## 4. 遗物图标第二批

保存源图为：`source_sheet_37_relic_icons_b.png`

裁剪顺序：

1. `icon_relic_support_supply_station`：支援补给站，补给箱/小型补给装置。
2. `icon_relic_rusty_hammer`：锈蚀的铁锤，旧锤。
3. `icon_relic_solo_music_box`：独奏八音盒，机械音乐盒。
4. `icon_relic_money_eye`：财眼，眼形钱币/金币眼。
5. `icon_relic_support_crane`：支援起重机，小型起重机钩。
6. `icon_relic_golden_expedition`：赤金的远征，金色远征徽记/罗盘。
7. `icon_relic_gin_goblet`：金酒之杯，酒杯。
8. `icon_relic_assault_protocol_blade`：突击协议-利刃，战术刀刃协议牌。
9. `icon_relic_fortress_protocol_hold`：堡垒协议-固守，盾形协议牌。
10. `icon_relic_ranged_protocol_counter`：远程协议-克敌，准星协议牌。

```text
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 10 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是遗物卡中的小物件图标。每个图标是独立物件，不带 UI 边框。风格：清新战术奇幻、低饱和、轻微工艺感、小尺寸仍然清楚。图标主体要居中，留足 #FF00FF 间距，边缘干净。
```

## 5. 遗物图标第三批

保存源图为：`source_sheet_38_relic_icons_c.png`

裁剪顺序：

1. `icon_relic_demolition_protocol_erase`：破坏协议-消除，爆破/裂纹协议牌。
2. `icon_relic_old_palm_fan`：老蒲扇，旧扇子。
3. `icon_relic_cov_unyielding`：殉道者的回响，坚守回响圣物。
4. `icon_relic_cov_precision`：鹰眼校准，鹰眼校准器。
5. `icon_relic_cov_steadfast`：磐石垒砌，石墙/磐石徽记。
6. `icon_relic_cov_swift`：迅捷髓液，迅捷药剂。
7. `icon_relic_cov_raid`：突袭信标，信标。
8. `icon_relic_cov_sargon`：萨尔贡战旗，战旗。
9. `icon_relic_cov_foresight`：远见账本，账本/预言记录。
10. `icon_relic_war_horn`：战吼图腾，号角或图腾。

```text
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 10 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是遗物卡中的小物件图标。每个图标是独立物件，不带 UI 边框。风格：清新战术奇幻、低饱和、轻微工艺感、小尺寸仍然清楚。图标主体要居中，留足 #FF00FF 间距，边缘干净。
```

## 6. 遗物图标第四批

保存源图为：`source_sheet_39_relic_icons_d.png`

裁剪顺序：

1. `icon_relic_emergency_activator`：紧急活性剂，注射器/活性剂瓶。
2. `icon_relic_rainbow_urn`：彩虹瓮，彩色陶瓮。
3. `icon_relic_stereoscopic_art_installation`：立体艺术装置，几何艺术装置。
4. `icon_relic_mandate_form`：王命凡形，王命文书/封印。
5. `icon_relic_demon_kings_ritual_vessel`：魔王的祭器，仪式器皿。
6. `icon_relic_glory_combo`：“荣耀套餐”，套餐托盘/礼盒。
7. `icon_relic_little_gran_faro`：“小格兰法洛”，小型灯塔/纪念模型。

```text
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 7 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是遗物卡中的小物件图标。每个图标是独立物件，不带 UI 边框。风格：清新战术奇幻、低饱和、轻微工艺感、小尺寸仍然清楚。图标主体要居中，留足 #FF00FF 间距，边缘干净。
```

## 7. 事件遗物图标补充批次

保存源图为：`source_sheet_40_relic_event_icons.png`

裁剪顺序：

1. `icon_relic_event_tasty`：好吃的，精致餐盘/犒赏食物。
2. `icon_relic_event_good_wine`：好酒，酒瓶与酒杯。
3. `icon_relic_event_sword_human`：人权剑·奥特尔，冷钢人类王权剑。
4. `icon_relic_event_sword_arts`：异权剑·赫格利，带法术能量的异色剑。
5. `icon_relic_event_sword_divine`：神权剑·提尔芬，神圣金色剑。
6. `icon_relic_event_arrogant`：已成骄兵，傲慢破裂军旗或高举头盔。
7. `icon_relic_event_grieving`：已成哀兵，哀悼面具或泪痕战旗。
8. `icon_relic_event_penguin_bandage`：企鹅创可贴，可爱的企鹅形创可贴或绷带。

```text
请生成一张遗物图标资产源图，纯色背景 #FF00FF，包含 8 个图标，按裁剪顺序排列。不要文字、数字、外框或底板。

这些是事件专属遗物卡中的小物件图标。每个图标是独立物件，不带 UI 边框。风格：清新战术奇幻、低饱和、轻微工艺感、小尺寸仍然清楚。图标主体要居中，留足 #FF00FF 间距，边缘干净。
```
