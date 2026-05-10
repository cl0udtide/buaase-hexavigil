class_name UiArtRegistry
extends RefCounted

const GENERATED_UI_DIR := "res://assets/ui/generated/"
const UI_ICON_CATALOG_PATH := "res://data/ui_icons.json"

static var _texture_cache: Dictionary = {}
static var _catalog_loaded := false
static var _catalog: Dictionary = {}


static func get_icon_texture(cfg: Dictionary, fallback_key: StringName = &"") -> Texture2D:
	var texture := _texture_from_cfg_path(cfg, "icon_path")
	if texture != null:
		return texture
	texture = _texture_from_cfg_path(cfg, "ui_icon_path")
	if texture != null:
		return texture
	var icon_key := StringName(cfg.get("icon_key", ""))
	texture = get_texture(icon_key, &"icon")
	if texture != null:
		return texture
	return get_catalog_icon(fallback_key)


static func get_class_icon_texture(unit_cfg: Dictionary) -> Texture2D:
	var texture := _texture_from_cfg_path(unit_cfg, "class_icon_path")
	if texture != null:
		return texture
	var class_key := String(unit_cfg.get("class", "")).strip_edges()
	if class_key.is_empty():
		return null
	return get_catalog_icon(StringName("class_%s" % class_key))


static func get_skill_icon_texture(unit_cfg: Dictionary) -> Texture2D:
	var texture := _texture_from_cfg_path(unit_cfg, "skill_icon_path")
	if texture != null:
		return texture
	texture = get_texture(StringName(unit_cfg.get("skill_icon_key", "")), &"icon")
	if texture != null:
		return texture
	var skill_id := String(unit_cfg.get("skill_id", "")).strip_edges()
	if skill_id.is_empty():
		return null
	return _load_texture("%sicon_skill_%s.png" % [GENERATED_UI_DIR, skill_id])


static func get_portrait_texture(cfg: Dictionary) -> Texture2D:
	var texture := _texture_from_cfg_path(cfg, "portrait_path")
	if texture != null:
		return texture
	return _texture_from_cfg_path(cfg, "ui_portrait_path")


static func get_catalog_icon(id: StringName) -> Texture2D:
	if id == StringName():
		return null
	_ensure_catalog_loaded()
	var path := String(_catalog.get(String(id), ""))
	if path.is_empty():
		return null
	return _load_texture(path)


static func get_texture(key: StringName, kind: StringName = &"icon") -> Texture2D:
	if key == StringName():
		return null
	_ensure_catalog_loaded()
	var key_text := String(key)
	var catalog_path := String(_catalog.get(key_text, ""))
	if not catalog_path.is_empty():
		return _load_texture(catalog_path)
	var legacy_path := _legacy_icon_path(key)
	if not legacy_path.is_empty():
		return _load_texture(legacy_path)
	if key_text.begins_with("res://"):
		return _load_texture(key_text)
	var direct_path := "%s%s.png" % [GENERATED_UI_DIR, key_text]
	var texture := _load_texture(direct_path)
	if texture != null:
		return texture
	if kind != StringName() and not key_text.begins_with("%s_" % String(kind)):
		return _load_texture("%s%s_%s.png" % [GENERATED_UI_DIR, String(kind), key_text])
	return null


static func _legacy_icon_path(key: StringName) -> String:
	var key_text := String(key)
	var suffix := "_%s" % "icon"
	if not key_text.ends_with(suffix):
		return ""
	var entity_id := key_text.trim_suffix(suffix)
	var building_path := "%sicon_building_%s.png" % [GENERATED_UI_DIR, entity_id]
	return building_path if ResourceLoader.exists(building_path) else ""


static func get_frame_texture(frame_key: StringName) -> Texture2D:
	return get_texture(frame_key, &"frame")


static func _texture_from_cfg_path(cfg: Dictionary, field_name: String) -> Texture2D:
	var path := String(cfg.get(field_name, "")).strip_edges()
	if path.is_empty():
		return null
	return _load_texture(path)


static func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		_texture_cache[path] = null
		return null
	var texture := load(path) as Texture2D
	_texture_cache[path] = texture
	return texture


static func _ensure_catalog_loaded() -> void:
	if _catalog_loaded:
		return
	_catalog_loaded = true
	_catalog.clear()
	if not FileAccess.file_exists(UI_ICON_CATALOG_PATH):
		return
	var file := FileAccess.open(UI_ICON_CATALOG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for key in (parsed as Dictionary).keys():
		_catalog[String(key)] = String((parsed as Dictionary)[key])
