class_name UnitSkillBehavior
extends Node


var owner_unit: Node
var active_timer := 0.0
var _infinite_active := false


func setup(unit: Node) -> void:
	owner_unit = unit
	active_timer = 0.0
	_infinite_active = false


func tick(delta: float) -> void:
	if active_timer <= 0.0:
		return
	if _infinite_active:
		return
	active_timer = max(active_timer - delta, 0.0)
	if active_timer == 0.0:
		_on_skill_end()


func can_cast() -> bool:
	return owner_unit != null and not is_active() and owner_unit.sp >= get_sp_max()


func cast() -> bool:
	if not can_cast():
		return false
	owner_unit.sp = 0.0
	_infinite_active = bool(owner_unit.cfg.get("skill_infinite_duration", false))
	active_timer = 1.0 if _infinite_active else get_duration()
	_on_skill_start()
	return true


func get_skill_name() -> String:
	return String(owner_unit.cfg.get("skill_name", owner_unit.cfg.get("skill_id", "未配置技能"))) if owner_unit != null else "未配置技能"


func get_skill_description() -> String:
	return String(owner_unit.cfg.get("skill_description", "暂无技能描述。")) if owner_unit != null else "暂无技能描述。"


func get_sp_max() -> float:
	return float(owner_unit.cfg.get("sp_max", 0.0)) if owner_unit != null else 0.0


func get_sp_recover_per_sec() -> float:
	return float(owner_unit.cfg.get("sp_recover_per_sec", 0.0)) if owner_unit != null else 0.0


func get_duration() -> float:
	return float(owner_unit.cfg.get("skill_duration", 0.0)) if owner_unit != null else 0.0


func get_active_remaining() -> float:
	return -1.0 if _infinite_active else active_timer


func is_active() -> bool:
	return active_timer > 0.0


func get_attack_targets_override() -> Array:
	return []


func get_attack_projectile_payloads(_target: Node, _damage_value: int) -> Array:
	return []


func after_attack(_target: Node, _damage_value: int) -> void:
	pass


func modify_attack_damage(base_damage: int, _target: Node) -> int:
	return base_damage


func after_receive_damage(_source: Node, _final_damage: int) -> void:
	pass


func _on_skill_start() -> void:
	pass


func _on_skill_end() -> void:
	_infinite_active = false
	pass


func _debug_log(message: String) -> void:
	if owner_unit == null:
		return
	var tree := owner_unit.get_tree()
	if tree != null:
		tree.call_group("combat_debug_log", "append_combat_debug", message)
