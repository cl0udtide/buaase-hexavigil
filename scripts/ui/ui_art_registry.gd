class_name UiArtRegistry
extends RefCounted

const GENERATED_DIR := "res://assets/ui/generated/"

static var _texture_cache: Dictionary = {}


static func get_icon_texture(cfg: Dictionary) -> Texture2D:
	for key_name in ["ui_icon_key", "icon_key", "id", "visual_key"]:
		var key := StringName(cfg.get(key_name, ""))
		var texture := get_texture(key, &"icon")
		if texture != null:
			return texture
	var class_key := String(cfg.get("class", "")).strip_edges()
	if not class_key.is_empty():
		return get_texture(StringName("icon_class_%s" % class_key), &"icon")
	var skill_id := StringName(cfg.get("skill_id", ""))
	if skill_id != StringName():
		return get_texture(skill_id, &"skill")
	return null


static func get_portrait_texture(cfg: Dictionary) -> Texture2D:
	for key_name in ["portrait_key", "ui_portrait_key", "visual_key", "icon_key"]:
		var texture := get_texture(StringName(cfg.get(key_name, "")), &"portrait")
		if texture != null:
			return texture
	return null


static func get_texture(key: StringName, kind: StringName = &"icon") -> Texture2D:
	var raw_key := String(key).strip_edges()
	if raw_key.is_empty():
		return null
	if raw_key.begins_with("res://"):
		return _load_texture(raw_key)
	for candidate in _candidate_keys(raw_key, kind):
		var path := "%s%s.png" % [GENERATED_DIR, candidate]
		var texture := _load_texture(path)
		if texture != null:
			return texture
	return null


static func has_texture(key: StringName, kind: StringName = &"icon") -> bool:
	return get_texture(key, kind) != null


static func texture_path(key: StringName, kind: StringName = &"icon") -> String:
	var raw_key := String(key).strip_edges()
	if raw_key.is_empty():
		return ""
	for candidate in _candidate_keys(raw_key, kind):
		var path := "%s%s.png" % [GENERATED_DIR, candidate]
		if FileAccess.file_exists(path):
			return path
	return ""


static func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	if not FileAccess.file_exists(path):
		_texture_cache[path] = null
		return null
	var loaded := load(path)
	if loaded is Texture2D:
		_texture_cache[path] = loaded
		return loaded as Texture2D
	_texture_cache[path] = null
	return null


static func _candidate_keys(raw_key: String, kind: StringName) -> PackedStringArray:
	var keys := PackedStringArray()
	_append_unique(keys, raw_key)
	var base_key := raw_key
	if base_key.ends_with("_icon"):
		base_key = base_key.substr(0, base_key.length() - "_icon".length())
		_append_unique(keys, base_key)

	if not raw_key.begins_with("icon_") and not raw_key.begins_with("frame_") and not raw_key.begins_with("bar_"):
		match kind:
			&"frame":
				_append_unique(keys, "frame_%s" % base_key)
			&"skill":
				_append_unique(keys, "icon_skill_%s" % base_key)
			&"portrait":
				_append_unique(keys, "portrait_%s" % base_key)
			_:
				_append_unique(keys, "icon_%s" % base_key)

	_append_unique(keys, _resource_icon_key(base_key))
	_append_unique(keys, _class_icon_key(base_key))
	_append_unique(keys, _damage_icon_key(base_key))
	_append_unique(keys, _phase_icon_key(base_key))
	_append_unique(keys, _building_icon_key(base_key))
	_append_unique(keys, _skill_icon_key(base_key))
	_append_unique(keys, _relic_icon_key(base_key))
	return keys


static func _append_unique(keys: PackedStringArray, key: String) -> void:
	if key.strip_edges().is_empty():
		return
	if not keys.has(key):
		keys.append(key)


static func _resource_icon_key(key: String) -> String:
	match key:
		"ap", "action_point", "action_points":
			return "icon_action_points"
		"wood":
			return "icon_wood"
		"stone":
			return "icon_stone"
		"mana":
			return "icon_mana"
		"prestige":
			return "icon_prestige"
		_:
			return ""


static func _class_icon_key(key: String) -> String:
	match key:
		"guard", "sniper", "caster", "defender":
			return "icon_class_%s" % key
		_:
			return ""


static func _damage_icon_key(key: String) -> String:
	match key:
		"physical":
			return "icon_damage_physical"
		"magic", "arts":
			return "icon_damage_arts"
		"true":
			return "icon_damage_true"
		_:
			return ""


static func _phase_icon_key(key: String) -> String:
	match key:
		"day":
			return "icon_phase_day"
		"night":
			return "icon_phase_night"
		"blessing", "relic":
			return "icon_phase_blessing"
		_:
			return ""


static func _building_icon_key(key: String) -> String:
	match key:
		"lumber_station", "wood_station":
			return "icon_building_lumber_station"
		"stone_quarry":
			return "icon_building_stone_quarry"
		"mana_extractor":
			return "icon_building_mana_extractor"
		"medical_station":
			return "icon_building_medical_station"
		"gravity_tower":
			return "icon_building_gravity_tower"
		"inspiring_monolith":
			return "icon_building_inspiring_monolith"
		"war_shrine", "war_shrine_active", "war_shrine_inactive":
			return "icon_building_war_shrine"
		"wood_wall":
			return "icon_building_wood_wall"
		_:
			return ""


static func _skill_icon_key(key: String) -> String:
	var normalized := key
	if normalized.begins_with("skill_"):
		normalized = normalized.substr("skill_".length())
	return "icon_skill_%s" % normalized


static func _relic_icon_key(key: String) -> String:
	if key.begins_with("relic_"):
		return "icon_%s" % key
	return ""
