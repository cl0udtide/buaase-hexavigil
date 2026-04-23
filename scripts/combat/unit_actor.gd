extends Node2D


var unit_id: StringName
var runtime_id := -1
var current_cell := Vector2i.ZERO
var facing := Vector2i.RIGHT
var cfg: Dictionary = {}
var max_hp := 1
var current_hp := 1
var sp := 0.0


func _ready() -> void:
	add_to_group("units")


func _process(delta: float) -> void:
	sp = min(sp + float(cfg.get("sp_recover_per_sec", 0.0)) * delta, float(cfg.get("sp_max", 0)))


func setup_from_cfg(new_unit_id: StringName, new_cfg: Dictionary, spawn_cell: Vector2i, new_facing: Vector2i) -> void:
	unit_id = new_unit_id
	cfg = new_cfg.duplicate(true)
	current_cell = spawn_cell
	facing = new_facing
	max_hp = int(cfg.get("max_hp", 1))
	current_hp = max_hp
	global_position = get_map_manager().cell_to_world(spawn_cell) if get_map_manager() != null else Vector2.ZERO
	var label := get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.text = String(cfg.get("name", unit_id))


func receive_damage(value: int, damage_type: int) -> void:
	var defense := int(cfg.get("def", 0))
	var final_damage := value
	if damage_type == GameEnums.DAMAGE_PHYSICAL:
		final_damage = CombatMath.calc_physical_damage(value, defense)
	current_hp = max(current_hp - final_damage, 0)


func receive_heal(value: int) -> void:
	current_hp = min(current_hp + value, max_hp)


func gain_sp(value: int) -> void:
	sp = min(sp + value, float(cfg.get("sp_max", 0)))


func can_cast_skill() -> bool:
	return sp >= float(cfg.get("sp_max", 0))


func cast_skill() -> void:
	if not can_cast_skill():
		return
	SkillRuntime.execute(self, cfg)
	sp = 0.0


func get_runtime_id() -> int:
	return runtime_id


func get_current_cell() -> Vector2i:
	return current_cell


func get_block_count() -> int:
	return int(cfg.get("block", 0))


func get_attack_targets() -> Array:
	return []


func get_map_manager() -> Node:
	return get_node_or_null("../../../Managers/MapManager")
