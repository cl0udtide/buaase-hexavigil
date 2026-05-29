class_name CovenantDefs
extends RefCounted

# 盟约（卫戍协议）定义的单一来源：可调数值与公式形态都集中在此，
# CovenantManager 只负责按场上状态调用这些函数并编排效果。
# 盟约的“效果逻辑”（复活、伤害透传等）在各接入点实现，本文件不含逻辑。

const TIER_PAIR := 2   # 2 人激活档位
const TIER_TRIO := 3   # 3 人激活档位

# UI 统一盟约色（不为每个盟约单独配色）
const UNIFIED_COLOR := Color(0.86, 0.74, 0.42)

# 盟约 id（= units.json 中 covenants 数组里的字符串）
const ID_UNYIELDING: StringName = &"不屈"
const ID_PRECISION: StringName = &"精准"
const ID_STEADFAST: StringName = &"坚守"
const ID_SWIFT: StringName = &"迅捷"
const ID_RAID: StringName = &"突袭"
const ID_SARGON: StringName = &"萨尔贡"
const ID_FORESIGHT: StringName = &"远见"

# UI 展示顺序
const ORDER: Array[StringName] = [
	ID_UNYIELDING, ID_PRECISION, ID_STEADFAST, ID_SWIFT, ID_RAID, ID_SARGON, ID_FORESIGHT
]

const NAMES := {
	ID_UNYIELDING: "不屈",
	ID_PRECISION: "精准",
	ID_STEADFAST: "坚守",
	ID_SWIFT: "迅捷",
	ID_RAID: "突袭",
	ID_SARGON: "萨尔贡",
	ID_FORESIGHT: "远见",
}

# 远见按“拥有”而非“部署”统计（白天阶段商店效果）。
const OWNED_BASED: Array[StringName] = [ID_FORESIGHT]


static func is_owned_based(covenant_id: StringName) -> bool:
	return OWNED_BASED.has(covenant_id)


static func is_known(covenant_id: StringName) -> bool:
	return ORDER.has(covenant_id)


static func display_name(covenant_id: StringName) -> String:
	return String(NAMES.get(covenant_id, covenant_id))


# ---------------------------------------------------------------------------
# 可调数值与公式（按盟约总层数 layer 计算）
# ---------------------------------------------------------------------------

# 精准 2 人：精准干员攻击力 +(30+10×层)%
static func precision_atk_percent(layer: int) -> float:
	return (30.0 + 10.0 * float(layer)) / 100.0

# 精准 3 人追加：攻击无视敌人 30% 防御/法抗
static func precision_defense_ignore() -> float:
	return 0.30

# 坚守 2 人：坚守干员生命 +(30+10×层)%
static func steadfast_hp_percent(layer: int) -> float:
	return (30.0 + 10.0 * float(layer)) / 100.0

# 迅捷 2 人：所有干员 SP 回复 +0.1×层 /秒
static func swift_sp_recover_add(layer: int) -> float:
	return 0.1 * float(layer)

# 迅捷 3 人：所有干员部署/再部署初动 +5 SP
static func swift_deploy_sp() -> int:
	return 5

# 突袭 2 人：突袭干员再部署时间 −(层×10%)，上限 70%
static func raid_redeploy_reduction(layer: int) -> float:
	return minf(0.10 * float(layer), 0.70)

# 不屈 2 人：被击倒时 min(10%×层, 100%) 概率原地满血复活
static func unyielding_revive_chance(layer: int) -> float:
	return clampf(0.10 * float(layer), 0.0, 1.0)

# 萨尔贡：每层叠加提供 +10 攻速 / +10% 攻击力，叠加次数上限为层数
static func sargon_aspd_per_stack() -> float:
	return 10.0

static func sargon_atk_percent_per_stack() -> float:
	return 0.10

static func sargon_max_stacks(layer: int) -> int:
	return max(layer, 0)

# 远见 3 人：商店购买价格 -1（最低 0），由 shop_manager 应用
static func foresight_purchase_cost_delta() -> int:
	return -1

# 远见 3 人：层数达到该值后，出售按基础价折半（向下取整）而非固定 1
static func foresight_sell_discount_min_layers() -> int:
	return 10

static func foresight_sell_value(base_cost_prestige: int) -> int:
	return max(int(floor(float(base_cost_prestige) / 2.0)), 1)


# ---------------------------------------------------------------------------
# UI 提示文案（按当前层数生成 2 人 / 3 人两条说明）
# ---------------------------------------------------------------------------
static func describe(covenant_id: StringName, layer: int) -> Array:
	match covenant_id:
		ID_UNYIELDING:
			return [
				"2人：不屈干员被击倒时 %d%% 概率清空再部署并原地满血复活" % int(round(unyielding_revive_chance(layer) * 100.0)),
				"3人：上述效果作用于所有干员",
			]
		ID_PRECISION:
			return [
				"2人：精准干员攻击力 +%d%%" % int(round(precision_atk_percent(layer) * 100.0)),
				"3人：作用于所有远程干员，并攻击无视敌人 %d%% 防御/法抗" % int(round(precision_defense_ignore() * 100.0)),
			]
		ID_STEADFAST:
			return [
				"2人：坚守干员生命 +%d%%" % int(round(steadfast_hp_percent(layer) * 100.0)),
				"3人：受到伤害由所有坚守干员均摊（开发中）",
			]
		ID_SWIFT:
			return [
				"2人：所有干员 SP 回复 +%.1f/秒" % swift_sp_recover_add(layer),
				"3人：所有干员部署/再部署初动 +%d SP" % swift_deploy_sp(),
			]
		ID_RAID:
			return [
				"2人：突袭干员再部署时间 −%d%%" % int(round(raid_redeploy_reduction(layer) * 100.0)),
				"3人：作用于所有干员",
			]
		ID_SARGON:
			return [
				"2人：萨尔贡干员开技能时，所有萨尔贡干员攻速+%d、攻击力+%d%%，最多叠 %d 层" % [int(sargon_aspd_per_stack()), int(round(sargon_atk_percent_per_stack() * 100.0)), sargon_max_stacks(layer)],
				"3人：增益作用于所有干员（仍只有萨尔贡干员开技能叠层）",
			]
		ID_FORESIGHT:
			var sell_line := "3人：商店购买 −1 声望" + ("；层数≥%d 时出售按基础价折半" % foresight_sell_discount_min_layers() if layer >= foresight_sell_discount_min_layers() else "")
			return [
				"2人：商店买空后刷新不消耗声望（按拥有数计算）",
				sell_line,
			]
		_:
			return []
