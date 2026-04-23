extends Node2D


var building_id: StringName
var runtime_id := -1
var current_cell := Vector2i.ZERO
var max_hp := 1
var current_hp := 1
var effect_radius := 0
var cfg: Dictionary = {}


func _ready() -> void:
	add_to_group("buildings")


func setup_from_cfg(new_building_id: StringName, new_cfg: Dictionary, cell: Vector2i) -> void:
	building_id = new_building_id
	cfg = new_cfg.duplicate(true)
	current_cell = cell
	max_hp = int(cfg.get("max_hp", 1))
	current_hp = max_hp
	effect_radius = int(cfg.get("effect_radius", 0))
	global_position = get_map_manager().cell_to_world(cell) if get_map_manager() != null else Vector2.ZERO
	var label := get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.text = String(cfg.get("name", building_id))


func receive_damage(value: int, _damage_type: int) -> void:
	current_hp = max(current_hp - value, 0)


func repair_full() -> void:
	current_hp = max_hp


func get_runtime_id() -> int:
	return runtime_id


func get_current_cell() -> Vector2i:
	return current_cell


func get_effect_radius() -> int:
	return effect_radius


func get_map_manager() -> Node:
	return get_node_or_null("../../../Managers/MapManager")
