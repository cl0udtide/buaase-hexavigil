class_name CombatMath
extends RefCounted


static func calc_physical_damage(atk: int, defense: int) -> int:
	return max(atk - defense, 1)


static func calc_magic_damage(atk: int, resistance: int) -> int:
	return max(int(round(atk * (1.0 - clamp(resistance / 100.0, 0.0, 0.9)))), 1)


static func calc_heal(power: int) -> int:
	return max(power, 1)
