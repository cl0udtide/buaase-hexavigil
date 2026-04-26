extends Node2D

const AppTheme = preload("res://scripts/ui/app_theme.gd")

var building_id: StringName
var runtime_id := -1
var current_cell := Vector2i.ZERO
var max_hp := 1
var current_hp := 1
var effect_radius := 0
var cfg: Dictionary = {}
var _enabled := true
var _is_destroyed := false

@onready var _status_view: Node = get_node_or_null("%StatusView")


func _ready() -> void:
	add_to_group("buildings")


func setup_from_cfg(new_building_id: StringName, new_cfg: Dictionary, cell: Vector2i) -> void:
	building_id = new_building_id
	cfg = new_cfg.duplicate(true)
	current_cell = cell
	max_hp = int(cfg.get("max_hp", 1))
	current_hp = max_hp
	effect_radius = int(cfg.get("effect_radius", 0))
	_enabled = bool(cfg.get("initial_enabled", true))
	_is_destroyed = false
	global_position = get_map_manager().cell_to_world(cell) if get_map_manager() != null else Vector2.ZERO
	_refresh_title_label()
	_update_status_view()


func receive_damage(value: int, _damage_type: int) -> void:
	if _is_destroyed:
		return
	current_hp = max(current_hp - value, 0)
	_update_status_view()
	_play_hit_effect()
	if current_hp == 0:
		_is_destroyed = true


func repair_full() -> void:
	current_hp = max_hp
	_is_destroyed = false
	_update_status_view()


func is_destroyed() -> bool:
	return _is_destroyed


func get_runtime_id() -> int:
	return runtime_id


func get_current_cell() -> Vector2i:
	return current_cell


func get_effect_radius() -> int:
	return effect_radius


func is_enabled() -> bool:
	return _enabled


func is_aura_active() -> bool:
	return not _is_destroyed and current_hp > 0 and _enabled


func can_toggle_enabled() -> bool:
	return building_id == &"war_shrine"


func set_enabled(value: bool) -> void:
	if not can_toggle_enabled():
		return
	_enabled = value
	_refresh_title_label()


func toggle_enabled() -> bool:
	if not can_toggle_enabled():
		return _enabled
	_enabled = not _enabled
	_refresh_title_label()
	return _enabled


func get_map_manager() -> Node:
	return get_node_or_null("../../../Managers/MapManager")


func _refresh_title_label() -> void:
	var label := get_node_or_null("%TitleLabel") as Label
	if label == null:
		return
	label.theme = AppTheme.get_theme()
	var title := String(cfg.get("name", building_id))
	if can_toggle_enabled():
		title += " [ON]" if _enabled else " [OFF]"
	label.text = title


func _update_status_view() -> void:
	if _status_view != null and _status_view.has_method("set_hp"):
		_status_view.set_hp(current_hp, max_hp)


func _play_hit_effect() -> void:
	if _status_view != null and _status_view.has_method("play_hit_effect"):
		_status_view.play_hit_effect()
