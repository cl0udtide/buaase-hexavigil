class_name SkillRuntime
extends RefCounted


static func execute(unit: Node, cfg: Dictionary) -> void:
	if unit == null:
		return
	unit.receive_heal(int(cfg.get("skill_heal", 0)))
