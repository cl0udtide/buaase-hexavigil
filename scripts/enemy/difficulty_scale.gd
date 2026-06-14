extends RefCounted
class_name DifficultyScale

## 按天数缩放出怪难度的全局开关。模板只描述构成形状，难度成长统一在这里调。
## 纯静态、确定性，可脱离 DataRepo 测试。数值为占位（平衡未定稿）。

## 杂兵数量系数：乘到每个 group 的 count 上（Boss 条目不缩放）。逐天爬升。
## 前期 <1 压人数（治"前期怪太多"），线性涨到末日 1.45；数量是次要杠杆，主难度交给数值。
const COUNT_SCALE_BY_DAY := {
	1: 0.65, 2: 0.75, 3: 0.85,
	4: 0.95, 5: 1.05, 6: 1.15,
	7: 1.25, 8: 1.35, 9: 1.45,
}
const DEFAULT_COUNT_SCALE := 1.0

## 杂兵非生命数值系数：乘到 atk/def/res 上。逐天上升且后段更陡（治"后期太简单"）。
## 每日步长递增（.08→.25），末日 2.30× 追上玩家复利。
const STAT_SCALE_BY_DAY := {
	1: 1.0, 2: 1.08, 3: 1.18,
	4: 1.30, 5: 1.45, 6: 1.62,
	7: 1.82, 8: 2.05, 9: 2.30,
}
const DEFAULT_STAT_SCALE := 1.0

## 杂兵生命系数：只乘到 max_hp 上。后两天独立抬高，攻防法抗仍走 STAT_SCALE。
const MAX_HP_SCALE_BY_DAY := {
	1: 1.0, 2: 1.08, 3: 1.18,
	4: 1.30, 5: 1.45, 6: 1.62,
	7: 1.82, 8: 2.90, 9: 4.00,
}
const DEFAULT_MAX_HP_SCALE := 1.0

## Boss 非生命数值系数：Boss 走这条独立曲线（不吃 STAT_SCALE，免双重缩放）。
## Boss 只在幕末（d3/d6/d9）出场，故只需三点；d3=1.0 为下限（不低于现状），末战拉到 2.5×。
const BOSS_STAT_SCALE_BY_DAY := {
	3: 1.0,
	6: 1.6,
	9: 2.5,
}
const DEFAULT_BOSS_STAT_SCALE := 1.0

## Boss 生命系数：只乘到 max_hp 上。d8/d9 与杂兵生命倍率对齐，便于终盘统一调血量。
const BOSS_MAX_HP_SCALE_BY_DAY := {
	3: 1.0,
	6: 1.6,
	8: 2.90,
	9: 4.00,
}
const DEFAULT_BOSS_MAX_HP_SCALE := 1.0

## 受非生命数值系数缩放的敌人数值字段。
const SCALED_NON_HP_STATS: Array[String] = ["atk", "def", "res"]


## 阶梯取值：命中精确键则直接返回，否则回退到 <= day 的最大键；都没有则用 default。
static func _stepwise(table: Dictionary, day: int, default_value: float) -> float:
	if table.has(day):
		return float(table[day])
	var best_key: int = -2147483648
	for raw_key: Variant in table.keys():
		var key := int(raw_key)
		if key <= day and key > best_key:
			best_key = key
	if best_key == -2147483648:
		return default_value
	return float(table[best_key])


static func count_scale_for_day(day: int) -> float:
	return _stepwise(COUNT_SCALE_BY_DAY, day, DEFAULT_COUNT_SCALE)


static func stat_scale_for_day(day: int) -> float:
	return _stepwise(STAT_SCALE_BY_DAY, day, DEFAULT_STAT_SCALE)


static func max_hp_scale_for_day(day: int) -> float:
	return _stepwise(MAX_HP_SCALE_BY_DAY, day, DEFAULT_MAX_HP_SCALE)


static func boss_stat_scale_for_day(day: int) -> float:
	return _stepwise(BOSS_STAT_SCALE_BY_DAY, day, DEFAULT_BOSS_STAT_SCALE)


static func boss_max_hp_scale_for_day(day: int) -> float:
	return _stepwise(BOSS_MAX_HP_SCALE_BY_DAY, day, DEFAULT_BOSS_MAX_HP_SCALE)


static func is_boss_cfg(enemy_cfg: Dictionary) -> bool:
	return StringName(enemy_cfg.get("behavior_type", "normal")) == &"boss"


## 该敌人当晚的数值系数：Boss 用 boss 曲线，其余用杂兵曲线。
static func stat_scale_for_enemy(enemy_cfg: Dictionary, day: int) -> float:
	return boss_stat_scale_for_day(day) if is_boss_cfg(enemy_cfg) else stat_scale_for_day(day)


## 该敌人当晚的生命系数：Boss 用 boss 生命曲线，其余用杂兵生命曲线。
static func max_hp_scale_for_enemy(enemy_cfg: Dictionary, day: int) -> float:
	return boss_max_hp_scale_for_day(day) if is_boss_cfg(enemy_cfg) else max_hp_scale_for_day(day)


## 缩放后的数量：向上取整、下限 1。
static func scaled_count(count: int, scale: float) -> int:
	return maxi(int(ceil(float(count) * scale)), 1)


## 就地把数值系数乘到 cfg 上。max_hp 可使用独立倍率，传负数时沿用 scale。
## max_hp 下限 1，其余下限 0，整数四舍五入（与 NightAffixService 口径一致）。
static func apply_stat_scale(target_cfg: Dictionary, scale: float, max_hp_scale: float = -1.0) -> void:
	var hp_scale: float = max_hp_scale if max_hp_scale >= 0.0 else scale
	if target_cfg.has("max_hp") and not is_equal_approx(hp_scale, 1.0):
		target_cfg["max_hp"] = maxi(int(round(float(target_cfg["max_hp"]) * hp_scale)), 1)
	if is_equal_approx(scale, 1.0):
		return
	for stat in SCALED_NON_HP_STATS:
		if not target_cfg.has(stat):
			continue
		target_cfg[stat] = maxi(int(round(float(target_cfg[stat]) * scale)), 0)
