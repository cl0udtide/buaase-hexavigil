extends Node

const CELL_SIZE := 64.0
const GroundHazardZone = preload("res://scripts/effects/ground_hazard_zone.gd")

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
	_apply_fire_rain()
	_play_phase_enter_custom_effect()
	var area_cfg: Dictionary = _owner_actor.cfg.get("phase_enter_area_damage", {})
	if area_cfg.is_empty():
		_pending_phase_cfg.clear()
		return
	var radius: int = int(area_cfg.get("radius", 1))
	var damage: int = int(area_cfg.get("damage", 0))
	if radius < 0 or damage <= 0:
		_pending_phase_cfg.clear()
		return
	_play_phase_enter_flash_effect()
	_play_phase_enter_area_effect(radius)
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


## P2 朝向火雨（凑凑企鹅）：朝当前朝向在前方铺地面危险区，持续若干秒每秒法术 DOT。
func _apply_fire_rain() -> void:
	var fire_cfg: Dictionary = _owner_actor.cfg.get("fire_rain", {})
	if fire_cfg.is_empty():
		return
	var length: int = maxi(int(fire_cfg.get("length", 3)), 1)
	var half_width: int = maxi(int(fire_cfg.get("half_width", 1)), 0)
	var dps := float(fire_cfg.get("damage_per_sec", 10.0))
	var duration := float(fire_cfg.get("duration", 6.0))
	var tick := float(fire_cfg.get("tick_interval", 1.0))
	var permanent := bool(fire_cfg.get("permanent", false))
	var damage_type: int = _parse_damage_type(String(fire_cfg.get("damage_type", "magic")))
	var facing: Vector2i = _owner_actor.facing
	if facing == Vector2i.ZERO:
		facing = Vector2i.RIGHT
	var perp := Vector2i(-facing.y, facing.x)
	var origin: Vector2i = _owner_actor.get_current_cell()
	var cells: Array[Vector2i] = []
	for d in range(1, length + 1):
		for w in range(-half_width, half_width + 1):
			cells.append(origin + facing * d + perp * w)
	var parent: Node = _owner_actor.get_parent()
	if parent == null:
		return
	var zone := GroundHazardZone.new()
	parent.add_child(zone)
	zone.setup(cells, dps, damage_type, duration, tick, _owner_actor.get_unit_manager(), _owner_actor.get_map_manager(), permanent, _owner_actor.get_enemy_manager(), String(fire_cfg.get("effect", "")), int(fire_cfg.get("effect_frames", 6)), float(fire_cfg.get("effect_fps", 10.0)))
	_debug_log("敌人 %s#%d 释放火雨，覆盖 %d 格，持续 %.1f 秒" % [_debug_name(), _runtime_id(), cells.size(), duration])


## 进阶段时的专属爆发特效（凑凑企鹅寒霜变身）：cfg.phase_enter_effect。
func _play_phase_enter_custom_effect() -> void:
	var path := String(_owner_actor.cfg.get("phase_enter_effect", ""))
	if path.is_empty() or not _owner_actor.has_method("spawn_world_effect"):
		return
	_owner_actor.spawn_world_effect(path, _owner_actor.global_position, 0.7, 6, 6, 14.0, Vector2(168.0, 168.0), 0.0, false, 26)


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
	_play_phase_transition_effect()
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


func _play_phase_transition_effect() -> void:
	if _owner_actor == null or not is_instance_valid(_owner_actor) or not _owner_actor.has_method("play_follow_effect"):
		return
	_owner_actor.play_follow_effect(
		"res://assets/effects/enemies/boss_phase_transition_strip.png",
		max(_phase_transition_timer, 0.35),
		6,
		6,
		10.0,
		Vector2(148.0, 148.0),
		true,
		Vector2(0.0, -8.0),
		26
	)


func _play_phase_enter_area_effect(radius: int) -> void:
	if _owner_actor == null or not is_instance_valid(_owner_actor) or not _owner_actor.has_method("spawn_world_effect"):
		return
	var texture_path := "res://assets/effects/enemies/boss_phase_enter_area_burst_strip.png"
	var frame_count := 6
	var effect_size := Vector2.ONE * float(max(radius * 2 + 1, 1)) * CELL_SIZE
	if StringName(_owner_actor.get("enemy_id")) == &"patriot":
		texture_path = "res://assets/effects/enemies/patriot_destroyer_shockwave_strip.png"
		effect_size = Vector2.ONE * float(max(radius * 2 + 1, 1)) * CELL_SIZE * 1.1
	_owner_actor.spawn_world_effect(
		texture_path,
		_owner_actor.global_position,
		0.46,
		frame_count,
		frame_count,
		14.0,
		effect_size,
		0.0,
		false,
		25
	)


func _play_phase_enter_flash_effect() -> void:
	if _owner_actor == null or not is_instance_valid(_owner_actor) or not _owner_actor.has_method("play_follow_effect"):
		return
	_owner_actor.play_follow_effect(
		"res://assets/effects/enemies/boss_rage_cast_flash_strip.png",
		0.46,
		6,
		6,
		16.0,
		Vector2(146.0, 146.0),
		false,
		Vector2(0.0, -8.0),
		26
	)


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
