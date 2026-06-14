extends Node

signal data_loaded
signal data_reload_failed(message: String)

const StoryLib = preload("res://scripts/story/story_library.gd")


const DATA_FILES := {
	"units": "res://data/units.json",
	"enemies": "res://data/enemies.json",
	"buildings": "res://data/buildings.json",
	"buffs": "res://data/buffs.json",
	"events": "res://data/events.json",
	"wave_templates": "res://data/wave_templates.json",
	"night_affixes": "res://data/night_affixes.json"
}

const CONFIG_FILES := {
	"map_generation": "res://data/map_generation.json",
	"ui_icons": "res://data/ui_icons.json"
}

## 剧情一段一文件，扫这个目录加载（区别于上面的单文件表）。
const STORIES_DIR := "res://data/stories"

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
	"wave_templates": {},
	"night_affixes": {}
}

var _configs: Dictionary = {
	"map_generation": {},
	"ui_icons": {}
}

var _stories: Dictionary = {}

var _loaded := false


func _ready() -> void:
	load_all()


func load_all() -> void:
	var loaded_tables: Dictionary = {}
	for table_name: String in DATA_FILES.keys():
		loaded_tables[table_name] = _load_table(DATA_FILES[table_name])
	_tables = loaded_tables

	var loaded_configs: Dictionary = {}
	for config_name: String in CONFIG_FILES.keys():
		loaded_configs[config_name] = _load_config(CONFIG_FILES[config_name])
	_configs = loaded_configs

	_stories = StoryLib.load_dir(STORIES_DIR)

	_loaded = true
	data_loaded.emit()


func is_loaded() -> bool:
	return _loaded


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


func get_wave_template_cfg(template_id: StringName) -> Dictionary:
	return _tables["wave_templates"].get(template_id, {}).duplicate(true)


func get_wave_template_ids_by_tier(tier: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for template_id in _tables["wave_templates"].keys():
		var cfg: Dictionary = _tables["wave_templates"].get(template_id, {})
		if StringName(cfg.get("tier", "")) == tier:
			ids.append(StringName(template_id))
	ids.sort()
	return ids


func get_night_affix_cfg(affix_id: StringName) -> Dictionary:
	return _tables["night_affixes"].get(affix_id, {}).duplicate(true)


func get_all_night_affix_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for affix_id in _tables["night_affixes"].keys():
		ids.append(StringName(affix_id))
	ids.sort()
	return ids


func get_all_wave_template_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for template_id in _tables["wave_templates"].keys():
		ids.append(StringName(template_id))
	ids.sort()
	return ids


func get_map_generation_cfg() -> Dictionary:
	return _configs["map_generation"].duplicate(true)


func get_ui_icon_catalog() -> Dictionary:
	return _configs["ui_icons"].duplicate(true)


func get_story_cfg(story_id: StringName) -> Dictionary:
	return _stories.get(story_id, {}).duplicate(true)


func get_all_story_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for story_id in _stories.keys():
		ids.append(StringName(story_id))
	ids.sort()
	return ids


func get_story_ids_by_trigger(trigger: String) -> Array[StringName]:
	return StoryLib.ids_by_trigger(_stories, trigger)


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


func get_all_enemy_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for enemy_id in _tables["enemies"].keys():
		ids.append(StringName(enemy_id))
	return ids


func get_all_buff_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for buff_id in _tables["buffs"].keys():
		ids.append(StringName(buff_id))
	return ids


func get_all_event_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for event_id in _tables["events"].keys():
		var cfg: Dictionary = _tables["events"].get(event_id, {})
		if bool(cfg.get("hidden_in_map_pool", false)):
			continue
		ids.append(StringName(event_id))
	return ids


func get_all_building_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for building_id in _tables["buildings"].keys():
		ids.append(StringName(building_id))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return _compare_building_order(a, b)
	)
	return ids


func get_building_ids_by_type(building_type: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for building_id in get_all_building_ids():
		var cfg := get_building_cfg(building_id)
		if bool(cfg.get("hidden_in_build_panel", false)):
			continue
		if StringName(cfg.get("building_type", "")) == building_type:
			ids.append(building_id)
	return ids


func _load_table(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: %s" % path)
		data_reload_failed.emit("Missing data file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Data file is not an array: %s" % path)
		data_reload_failed.emit("Data file is not an array: %s" % path)
		return {}

	var indexed: Dictionary = {}
	for entry: Variant in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_dict: Dictionary = entry
		var id_value: StringName = StringName(entry_dict.get("id", ""))
		if id_value != StringName():
			indexed[id_value] = entry_dict
	return indexed


func _load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing config file: %s" % path)
		data_reload_failed.emit("Missing config file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Config file is not a dictionary: %s" % path)
		data_reload_failed.emit("Config file is not a dictionary: %s" % path)
		return {}
	return (parsed as Dictionary).duplicate(true)


func _compare_building_order(a: StringName, b: StringName) -> bool:
	var cfg_a := get_building_cfg(a)
	var cfg_b := get_building_cfg(b)
	var order_a := int(cfg_a.get("sort_order", 0))
	var order_b := int(cfg_b.get("sort_order", 0))
	if order_a == order_b:
		return String(a) < String(b)
	return order_a < order_b
