extends Node


const DATA_FILES := {
	"units": "res://data/units.json",
	"enemies": "res://data/enemies.json",
	"buildings": "res://data/buildings.json",
	"buffs": "res://data/buffs.json",
	"events": "res://data/events.json",
	"waves": "res://data/waves.json"
}

const SCENE_REGISTRY := {
	&"unit_actor": "res://scenes/actors/UnitActor.tscn",
	&"enemy_actor": "res://scenes/actors/EnemyActor.tscn",
	&"building_actor": "res://scenes/actors/BuildingActor.tscn",
	&"projectile": "res://scenes/actors/Projectile.tscn",
	&"map_root": "res://scenes/world/MapRoot.tscn",
	&"spawn_point": "res://scenes/world/SpawnPoint.tscn",
	&"core": "res://scenes/world/Core.tscn"
}

var _tables: Dictionary = {
	"units": {},
	"enemies": {},
	"buildings": {},
	"buffs": {},
	"events": {},
	"waves": {}
}


func load_all() -> void:
	for table_name: String in DATA_FILES.keys():
		_tables[table_name] = _load_table(DATA_FILES[table_name], table_name == "waves")


func get_unit_cfg(unit_id: StringName) -> Dictionary:
	return _tables["units"].get(unit_id, {}).duplicate(true)


func get_enemy_cfg(enemy_id: StringName) -> Dictionary:
	return _tables["enemies"].get(enemy_id, {}).duplicate(true)


func get_building_cfg(building_id: StringName) -> Dictionary:
	return _tables["buildings"].get(building_id, {}).duplicate(true)


func get_buff_cfg(buff_id: StringName) -> Dictionary:
	return _tables["buffs"].get(buff_id, {}).duplicate(true)


func get_event_cfg(event_id: StringName) -> Dictionary:
	return _tables["events"].get(event_id, {}).duplicate(true)


func get_wave_cfg(day: int) -> Dictionary:
	return _tables["waves"].get(day, {}).duplicate(true)


func get_scene_by_key(scene_key: StringName) -> PackedScene:
	var path: String = String(SCENE_REGISTRY.get(scene_key, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


func get_all_unit_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for unit_id in _tables["units"].keys():
		ids.append(StringName(unit_id))
	return ids


func get_all_buff_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for buff_id in _tables["buffs"].keys():
		ids.append(StringName(buff_id))
	return ids


func get_all_event_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for event_id in _tables["events"].keys():
		ids.append(StringName(event_id))
	return ids


func _load_table(path: String, use_day_key: bool) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Data file is not an array: %s" % path)
		return {}

	var indexed: Dictionary = {}
	for entry: Variant in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_dict: Dictionary = entry
		if use_day_key:
			indexed[int(entry_dict.get("day", -1))] = entry_dict
		else:
			var id_value: StringName = StringName(entry_dict.get("id", ""))
			if id_value != StringName():
				indexed[id_value] = entry_dict
	return indexed
