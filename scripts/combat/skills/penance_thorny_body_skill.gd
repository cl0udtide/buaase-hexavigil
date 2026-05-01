extends "res://scripts/combat/skills/unit_skill_behavior.gd"


var _base_attack_multiplier := 1.0
var _base_defense := 0
var _base_block_count := 0
var _barrier := 0


func _on_skill_start() -> void:
	_base_attack_multiplier = owner_unit.attack_multiplier
	_base_defense = owner_unit.defense
	_base_block_count = owner_unit.block_count
	_barrier = int(round(float(owner_unit.max_hp) * float(owner_unit.cfg.get("skill_barrier_percent", 1.2))))
	owner_unit.attack_multiplier = _base_attack_multiplier * float(owner_unit.cfg.get("skill_atk_multiplier", 1.55))
	owner_unit.defense = max(int(round(float(_base_defense) * float(owner_unit.cfg.get("skill_def_multiplier", 1.35)))), 0)
	owner_unit.block_count = _base_block_count + int(owner_unit.cfg.get("skill_block_bonus", 1))
	_debug_log("技能启动：%s#%d 披荆斩棘，屏障 %d 并受击法术反击" % [
		owner_unit.unit_id,
		owner_unit.get_runtime_id(),
		_barrier
	])


func _on_skill_end() -> void:
	if owner_unit == null:
		return
	owner_unit.attack_multiplier = _base_attack_multiplier
	owner_unit.defense = _base_defense
	owner_unit.block_count = _base_block_count
	_barrier = 0


func modify_final_incoming_damage(final_damage: int, _raw_damage: int, _damage_type_value: int, _source: Node) -> int:
	if not is_active() or _barrier <= 0 or final_damage <= 0:
		return final_damage
	var absorbed: int = min(_barrier, final_damage)
	_barrier -= absorbed
	return final_damage - absorbed


func after_receive_damage(source: Node, final_damage: int) -> void:
	if owner_unit == null or not is_active() or source == null or not is_instance_valid(source):
		return
	if not source.has_method("receive_damage"):
		return
	var counter_damage: int = max(int(round(float(owner_unit.get_effective_atk()) * float(owner_unit.cfg.get("skill_counter_atk_multiplier", 0.9)))) + int(round(float(final_damage) * float(owner_unit.cfg.get("skill_counter_damage_taken_multiplier", 0.45)))), 1)
	source.receive_damage(counter_damage, GameEnums.DAMAGE_MAGIC)
