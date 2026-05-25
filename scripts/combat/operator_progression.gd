extends RefCounted

const MIN_STAR := 1
const MAX_STAR := 3
const DEFAULT_STAR := 1

const STAR_MULTIPLIERS := {
	1: 1.0,
	2: 1.6,
	3: 2.3
}


static func normalize_star(value: Variant) -> int:
	return clampi(int(value), MIN_STAR, MAX_STAR)


static func get_multiplier(star: int) -> float:
	return float(STAR_MULTIPLIERS.get(normalize_star(star), 1.0))


static func format_star_label(star: int) -> String:
	return "★%d" % normalize_star(star)


static func make_effective_unit_cfg(unit_cfg: Dictionary, star: int) -> Dictionary:
	var effective_cfg := unit_cfg.duplicate(true)
	var multiplier := get_multiplier(star)
	effective_cfg["operator_star"] = normalize_star(star)
	effective_cfg["operator_star_multiplier"] = multiplier
	for stat_key in ["max_hp", "atk"]:
		if effective_cfg.has(stat_key):
			effective_cfg[stat_key] = max(int(round(float(effective_cfg.get(stat_key, 0)) * multiplier)), 1)
	for stat_key in ["def", "res"]:
		if effective_cfg.has(stat_key):
			effective_cfg[stat_key] = max(int(round(float(effective_cfg.get(stat_key, 0)) * multiplier)), 0)
	return effective_cfg
