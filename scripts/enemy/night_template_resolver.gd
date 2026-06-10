extends RefCounted
class_name NightTemplateResolver

## day -> 每晚各波的档位序列。调整单局天数或夜晚节奏时改这张表。
## 占位节奏：波数随天数递增，最后一晚为 late + boss。
const WAVE_TIERS_BY_DAY := {
	1: [&"early"],
	2: [&"early", &"early"],
	3: [&"early", &"mid"],
	4: [&"mid", &"mid"],
	5: [&"mid", &"late", &"late"],
	6: [&"late", &"boss"],
}
const DEFAULT_WAVE_TIERS: Array = [&"late", &"late"]
const DEFAULT_TIER: StringName = &"late"


static func wave_tiers_for_day(day: int) -> Array[StringName]:
	var raw_tiers: Array = WAVE_TIERS_BY_DAY.get(day, DEFAULT_WAVE_TIERS)
	var tiers: Array[StringName] = []
	for raw_tier: Variant in raw_tiers:
		tiers.append(StringName(raw_tier))
	return tiers


static func wave_count_for_day(day: int) -> int:
	return wave_tiers_for_day(day).size()


## 兼容入口：返回当晚首波档位。
static func tier_for_day(day: int) -> StringName:
	var tiers := wave_tiers_for_day(day)
	return tiers[0] if not tiers.is_empty() else DEFAULT_TIER


## 解析整夜计划：按当日档位序列逐波抽模板，夜内与局内均不重复（池耗尽时回退允许重复）。
## pools: Dictionary[StringName tier -> Array[StringName] template_ids]，由调用方从 DataRepo 组装。
static func resolve_night_plan(pools: Dictionary, used_ids: Array, run_seed: int, day: int) -> Array[StringName]:
	var plan: Array[StringName] = []
	var combined_used: Array = []
	for raw_used: Variant in used_ids:
		combined_used.append(StringName(raw_used))
	var tiers := wave_tiers_for_day(day)
	for wave_index in range(tiers.size()):
		var tier: StringName = tiers[wave_index]
		var pool: Array = pools.get(tier, [])
		var template_id := resolve(pool, combined_used, run_seed, day, wave_index)
		if template_id == StringName():
			continue
		plan.append(template_id)
		if not combined_used.has(template_id):
			combined_used.append(template_id)
	return plan


static func resolve(pool_ids: Array, used_ids: Array, run_seed: int, day: int, wave_index: int = 0) -> StringName:
	var available: Array[StringName] = []
	for raw_id: Variant in pool_ids:
		var id := StringName(raw_id)
		if id != StringName() and not used_ids.has(id):
			available.append(id)
	if available.is_empty():
		for raw_id: Variant in pool_ids:
			var id := StringName(raw_id)
			if id != StringName():
				available.append(id)
	if available.is_empty():
		return StringName()
	available.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("%d|%d|%d|%s" % [run_seed, day, wave_index, String(tier_for_day(day))]).hash())
	return available[rng.randi() % available.size()]
