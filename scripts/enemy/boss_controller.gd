extends Node

var _owner_actor: Node = null
var _initial_cfg: Dictionary = {}
var _phases: Array[Dictionary] = []
var _enabled := false
var _boss_phase := 1
var _phase_transitioning := false
var _phase_transition_timer := 0.0
var _pending_phase_cfg: Dictionary = {}


func setup(owner_actor: Node, initial_cfg: Dictionary) -> void:
	_owner_actor = owner_actor
	_initial_cfg = initial_cfg.duplicate(true)
	_phases.clear()
	_pending_phase_cfg.clear()
	_boss_phase = 1
	_phase_transitioning = false
	_phase_transition_timer = 0.0
	var raw_phases: Array = _initial_cfg.get("phases", [])
	for raw_phase in raw_phases:
		if typeof(raw_phase) != TYPE_DICTIONARY:
			continue
		_phases.append((raw_phase as Dictionary).duplicate(true))
	_phases.sort_custom(_compare_phase_cfg)
	_enabled = StringName(_initial_cfg.get("behavior_type", "normal")) == &"boss" or not _phases.is_empty()


func is_enabled() -> bool:
	return _enabled


func is_transitioning() -> bool:
	return _enabled and _phase_transitioning


func try_consume_death_for_phase_transition() -> bool:
	if not _enabled or _phase_transitioning:
		return false
	var next_phase_cfg: Dictionary = _get_next_phase_cfg()
	if next_phase_cfg.is_empty():
		return false
	_start_phase_transition(next_phase_cfg)
	return true


func tick(delta: float) -> Dictionary:
	if not is_transitioning():
		return {}
	_phase_transition_timer = max(_phase_transition_timer - delta, 0.0)
	if _phase_transition_timer > 0.0:
		return {}
	_phase_transitioning = false
	return _pending_phase_cfg.duplicate(true)


func get_current_phase() -> int:
	return _boss_phase


func get_pending_phase_cfg() -> Dictionary:
	return _pending_phase_cfg.duplicate(true)


func apply_phase_enter_effects() -> void:
	if _owner_actor == null or not is_instance_valid(_owner_actor):
		return
	var area_cfg: Dictionary = _owner_actor.cfg.get("phase_enter_area_damage", {})
	if area_cfg.is_empty():
		_pending_phase_cfg.clear()
		return
	var radius: int = int(area_cfg.get("radius", 1))
	var damage: int = int(area_cfg.get("damage", 0))
	if radius < 0 or damage <= 0:
		_pending_phase_cfg.clear()
		return
	var damage_type: int = _parse_damage_type(String(area_cfg.get("damage_type", _owner_actor.cfg.get("damage_type", "physical"))))
	var unit_manager: Node = _owner_actor.get_unit_manager()
	var building_manager: Node = _owner_actor.get_building_manager()
	var current_cell: Vector2i = _owner_actor.get_current_cell()
	for y in range(current_cell.y - radius, current_cell.y + radius + 1):
		for x in range(current_cell.x - radius, current_cell.x + radius + 1):
			var cell: Vector2i = Vector2i(x, y)
			if unit_manager != null and unit_manager.has_method("get_unit_by_cell"):
				var unit: Node = unit_manager.get_unit_by_cell(cell)
				if unit != null and unit.has_method("receive_damage"):
					unit.receive_damage(damage, damage_type, _owner_actor)
			if building_manager != null and building_manager.has_method("get_building_by_cell"):
				var building: Node = building_manager.get_building_by_cell(cell)
				if building != null and is_instance_valid(building):
					_damage_building(building, damage, damage_type)
	_debug_log("敌人 %s#%d 点燃周围 %dx%d 区域，造成%s伤害 %d" % [_debug_name(), _runtime_id(), radius * 2 + 1, radius * 2 + 1, _damage_type_text(damage_type), damage])
	_pending_phase_cfg.clear()


func on_hp_threshold_crossed(_percent: float) -> void:
	pass


func enter_phase_two() -> void:
	if _boss_phase < 2:
		var phase_cfg: Dictionary = _get_phase_cfg(2)
		if not phase_cfg.is_empty():
			_start_phase_transition(phase_cfg)


func cast_boss_skill(_skill_id: StringName) -> void:
	pass


func _start_phase_transition(next_phase_cfg: Dictionary) -> void:
	_pending_phase_cfg = next_phase_cfg.duplicate(true)
	_boss_phase = int(_pending_phase_cfg.get("phase", _boss_phase + 1))
	_phase_transitioning = true
	_phase_transition_timer = max(float(_get_owner_cfg().get("phase_transition_sec", 1.5)), 0.0)
	if _owner_actor != null and is_instance_valid(_owner_actor):
		if _owner_actor.has_method("clear_blocked"):
			_owner_actor.clear_blocked()
	_debug_log("敌人 %s#%d 第%d阶段血量耗尽，进入 %.1f 秒无敌转阶段" % [_debug_name(), _runtime_id(), _boss_phase - 1, _phase_transition_timer])


func _get_next_phase_cfg() -> Dictionary:
	for phase_cfg in _phases:
		if int(phase_cfg.get("phase", 0)) > _boss_phase:
			return phase_cfg.duplicate(true)
	return {}


func _get_phase_cfg(phase: int) -> Dictionary:
	for phase_cfg in _phases:
		if int(phase_cfg.get("phase", 0)) == phase:
			return phase_cfg.duplicate(true)
	return {}


func _compare_phase_cfg(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("phase", 0)) < int(b.get("phase", 0))


func _get_owner_cfg() -> Dictionary:
	if _owner_actor != null and is_instance_valid(_owner_actor):
		var cfg_variant: Variant = _owner_actor.get("cfg")
		if typeof(cfg_variant) == TYPE_DICTIONARY:
			return cfg_variant
	return _initial_cfg


func _damage_building(building: Node, damage_value: int, damage_type: int) -> void:
	var building_manager: Node = _owner_actor.get_building_manager() if _owner_actor != null and is_instance_valid(_owner_actor) else null
	if building_manager != null and building_manager.has_method("damage_building"):
		building_manager.damage_building(int(building.get("runtime_id")), damage_value, damage_type)
	elif building != null and building.has_method("receive_damage"):
		building.receive_damage(damage_value, damage_type)


func _parse_damage_type(raw_type: String) -> int:
	match raw_type:
		"magic":
			return GameEnums.DAMAGE_MAGIC
		"true":
			return GameEnums.DAMAGE_TRUE
		_:
			return GameEnums.DAMAGE_PHYSICAL


func _damage_type_text(type_value: int) -> String:
	match type_value:
		GameEnums.DAMAGE_MAGIC:
			return "法术"
		GameEnums.DAMAGE_TRUE:
			return "真实"
		_:
			return "物理"


func _debug_log(message: String) -> void:
	if _owner_actor != null and is_instance_valid(_owner_actor) and _owner_actor.has_method("_debug_log"):
		_owner_actor._debug_log(message)


func _debug_name() -> String:
	if _owner_actor != null and is_instance_valid(_owner_actor):
		return String(_owner_actor.cfg.get("name", _owner_actor.enemy_id))
	return String(_initial_cfg.get("name", "Boss"))


func _runtime_id() -> int:
	if _owner_actor != null and is_instance_valid(_owner_actor):
		return int(_owner_actor.get_runtime_id())
	return -1
