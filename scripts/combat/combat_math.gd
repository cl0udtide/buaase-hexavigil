class_name CombatMath
extends RefCounted


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
