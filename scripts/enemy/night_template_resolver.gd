extends RefCounted
class_name NightTemplateResolver

## day -> tier curve. Extend or externalize this when the run length changes.
const TIER_BY_DAY := {
	1: &"early",
	2: &"early",
	3: &"mid",
	4: &"mid",
	5: &"late",
	6: &"boss",
}
const DEFAULT_TIER: StringName = &"late"


static func tier_for_day(day: int) -> StringName:
	return StringName(TIER_BY_DAY.get(day, DEFAULT_TIER))


static func resolve(pool_ids: Array, used_ids: Array, run_seed: int, day: int) -> StringName:
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
	rng.seed = abs(("%d|%d|%s" % [run_seed, day, String(tier_for_day(day))]).hash())
	return available[rng.randi() % available.size()]
