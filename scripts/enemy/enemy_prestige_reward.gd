extends RefCounted
class_name EnemyPrestigeReward

const LATE_REWARD_START_DAY := 4
const LATE_REWARD_REDUCTION := 2
const MIN_REWARD := 1


static func base_for_day(raw_reward: int, day: int) -> int:
	if raw_reward <= 0:
		return 0
	if day < LATE_REWARD_START_DAY:
		return raw_reward
	var adjusted_reward: int = raw_reward - LATE_REWARD_REDUCTION
	return MIN_REWARD if adjusted_reward < MIN_REWARD else adjusted_reward


static func apply_base_for_day(enemy_cfg: Dictionary, day: int) -> Dictionary:
	var cfg: Dictionary = enemy_cfg.duplicate(true)
	if cfg.has("prestige_reward"):
		cfg["prestige_reward"] = base_for_day(int(cfg.get("prestige_reward", 0)), day)
	return cfg
