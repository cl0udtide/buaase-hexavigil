class_name CombatMath
extends RefCounted

const BASE_ATTACK_SPEED := 100.0
const MIN_ATTACK_SPEED := 20.0
const MAX_ATTACK_SPEED := 600.0
const MIN_ATTACK_INTERVAL := 0.05


static func clamp_attack_speed(attack_speed: float) -> float:
	return clamp(attack_speed, MIN_ATTACK_SPEED, MAX_ATTACK_SPEED)


# 明日方舟攻速机制：实际攻击间隔 = 理论间隔 ÷ (攻速 ÷ 100)，攻速钳制在 [20, 600]。
static func calc_attack_interval(base_interval: float, attack_speed: float) -> float:
	var aspd := clamp_attack_speed(attack_speed)
	return max(base_interval * BASE_ATTACK_SPEED / aspd, MIN_ATTACK_INTERVAL)


static func calc_physical_damage(atk: int, defense: int) -> int:
	return max(atk - max(defense, 0), _minimum_damage(atk))


static func calc_magic_damage(atk: int, resistance: int) -> int:
	var multiplier: float = 1.0 - clamp(float(resistance) / 100.0, 0.0, 1.0)
	return max(int(round(float(atk) * multiplier)), _minimum_damage(atk))


static func calc_heal(power: int) -> int:
	return max(power, 1)


static func _minimum_damage(atk: int) -> int:
	# 明日方舟中物理/法术伤害至少造成攻击力 5% 的保底伤害。
	return max(int(ceil(float(max(atk, 1)) * 0.05)), 1)
