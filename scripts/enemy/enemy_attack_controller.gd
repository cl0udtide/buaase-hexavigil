extends Node

var _owner_actor: Node2D = null
var _attack_timer := 0.0


func setup(owner_actor: Node2D) -> void:
	_owner_actor = owner_actor
	_attack_timer = 0.0


func reset_attack_timer() -> void:
	_attack_timer = 0.0


func set_attack_cooldown_from_cfg() -> void:
	_attack_timer = max(float(_owner_actor.cfg.get("attack_interval", 1.0)), 0.05)


func get_attack_range_tiles() -> int:
	return int(_owner_actor.cfg.get("attack_range", 0)) if _owner_actor != null else 0


func process_blocked_attack(delta: float, blocker: Node) -> void:
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return
	var damage_type: int = _parse_damage_type(String(_owner_actor.cfg.get("damage_type", "physical")))
	var damage_value: int = int(_owner_actor.cfg.get("atk", 1))
	_debug_log("敌人 %s#%d 攻击阻挡单位 %s#%d，%s伤害 %d" % [_debug_name(), _runtime_id(), blocker.unit_id, blocker.get_runtime_id(), _damage_type_text(damage_type), damage_value])
	_play_owner_attack_lunge()
	blocker.receive_damage(damage_value, damage_type, _owner_actor)
	set_attack_cooldown_from_cfg()


func process_building_attack(delta: float, building: Node) -> void:
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return
	var building_manager: Node = _get_building_manager()
	if building_manager == null or not building_manager.has_method("damage_building"):
		return
	var damage_type: int = _parse_damage_type(String(_owner_actor.cfg.get("damage_type", "physical")))
	var damage_value: int = int(_owner_actor.cfg.get("atk", 1))
	_debug_log("敌人 %s#%d 攻击路径建筑 %s，%s伤害 %d" % [_debug_name(), _runtime_id(), _target_debug_name(building), _damage_type_text(damage_type), damage_value])
	_play_owner_attack_lunge()
	_damage_building(building, damage_value, damage_type)
	set_attack_cooldown_from_cfg()


func process_range_attack(delta: float) -> bool:
	var attack_range: int = get_attack_range_tiles()
	if attack_range <= 0:
		return false
	var target: Node = _find_attack_target_in_range(attack_range)
	if target == null:
		return false
	_attack_timer = max(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return true
	var damage_type: int = _parse_damage_type(String(_owner_actor.cfg.get("damage_type", "physical")))
	var damage_value: int = int(_owner_actor.cfg.get("atk", 1))
	_debug_log("敌人 %s#%d 远程攻击 %s，%s伤害 %d" % [_debug_name(), _runtime_id(), _target_debug_name(target), _damage_type_text(damage_type), damage_value])
	_play_owner_attack_lunge()
	if target.has_method("receive_damage"):
		if target.is_in_group("units"):
			target.receive_damage(damage_value, damage_type, _owner_actor)
		else:
			_damage_building(target, damage_value, damage_type)
	set_attack_cooldown_from_cfg()
	return true


func get_blocking_building_on_path(movement_controller: Node) -> Node:
	if movement_controller == null or movement_controller.get_path_mode() == &"flying" or not movement_controller.has_path() or movement_controller.has_arrived():
		return null
	var building_manager: Node = _get_building_manager()
	if building_manager == null or not building_manager.has_method("get_building_by_cell"):
		return null
	var next_cell: Vector2i = movement_controller.get_next_path_cell()
	var building: Node = building_manager.get_building_by_cell(next_cell)
	if building == null or not is_instance_valid(building):
		return null
	if _is_destroyed_building(building):
		return null
	if not _should_attack_path_building(building, movement_controller):
		return null
	return building


func _find_attack_target_in_range(attack_range: int) -> Node:
	var unit_manager: Node = _get_unit_manager()
	var building_manager: Node = _get_building_manager()
	var best_target: Node = null
	var best_distance: int = 999999
	var current_cell: Vector2i = _owner_actor.get_current_cell()
	for y in range(current_cell.y - attack_range, current_cell.y + attack_range + 1):
		for x in range(current_cell.x - attack_range, current_cell.x + attack_range + 1):
			var cell: Vector2i = Vector2i(x, y)
			var distance: int = max(abs(cell.x - current_cell.x), abs(cell.y - current_cell.y))
			if distance > attack_range or distance >= best_distance:
				continue
			var unit: Node = null
			if unit_manager != null and unit_manager.has_method("get_unit_by_cell"):
				unit = unit_manager.get_unit_by_cell(cell)
			if unit != null and is_instance_valid(unit):
				best_target = unit
				best_distance = distance
				continue
			var building: Node = null
			if building_manager != null and building_manager.has_method("get_building_by_cell"):
				building = building_manager.get_building_by_cell(cell)
			if building != null and is_instance_valid(building) and not _is_destroyed_building(building):
				best_target = building
				best_distance = distance
	return best_target


func _damage_building(building: Node, damage_value: int, damage_type: int) -> void:
	var building_manager: Node = _get_building_manager()
	if building_manager != null and building_manager.has_method("damage_building"):
		building_manager.damage_building(int(building.get("runtime_id")), damage_value, damage_type)
	elif building != null and building.has_method("receive_damage"):
		building.receive_damage(damage_value, damage_type)


func _should_attack_path_building(building: Node, movement_controller: Node) -> bool:
	if _is_destroyed_building(building):
		return false
	var path_mode: StringName = movement_controller.get_path_mode() if movement_controller != null else &"normal"
	if path_mode == &"demolisher":
		return true
	if path_mode != &"normal":
		return false
	return not _is_wall_building(building)


func _is_destroyed_building(building: Node) -> bool:
	if building == null:
		return false
	if building.has_method("is_destroyed"):
		return bool(building.is_destroyed())
	var current_hp_variant: Variant = building.get("current_hp")
	return current_hp_variant != null and int(current_hp_variant) <= 0


func _is_wall_building(building: Node) -> bool:
	if building == null:
		return false
	if StringName(building.get("building_id")) == &"wood_wall":
		return true
	var cfg_variant: Variant = building.get("cfg")
	if typeof(cfg_variant) != TYPE_DICTIONARY:
		return false
	var building_cfg: Dictionary = cfg_variant
	return bool(building_cfg.get("blocks_path", false))


func _play_owner_attack_lunge() -> void:
	if _owner_actor != null and _owner_actor.has_method("play_attack_lunge"):
		_owner_actor.play_attack_lunge()


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


func _target_debug_name(target: Node) -> String:
	if target == null:
		return "未知目标"
	if target.is_in_group("units"):
		return "单位 %s#%d" % [String(target.get("unit_id")), int(target.get("runtime_id"))]
	if target.is_in_group("buildings"):
		return "建筑 %s#%d" % [String(target.get("building_id")), int(target.get("runtime_id"))]
	return String(target.name)


func _get_unit_manager() -> Node:
	return _owner_actor.get_unit_manager() if _owner_actor != null else null


func _get_building_manager() -> Node:
	return _owner_actor.get_building_manager() if _owner_actor != null else null


func _debug_log(message: String) -> void:
	if _owner_actor != null and _owner_actor.has_method("_debug_log"):
		_owner_actor._debug_log(message)


func _debug_name() -> String:
	if _owner_actor == null:
		return "未知敌人"
	return String(_owner_actor.cfg.get("name", _owner_actor.enemy_id))


func _runtime_id() -> int:
	return int(_owner_actor.get_runtime_id()) if _owner_actor != null else -1
