class_name UiArtRegistry
extends RefCounted


const ICON_DIRS := [
	"res://assets/ui/icons",
	"res://assets/ui",
	"res://assets/sprites/ui",
]

const PORTRAIT_DIRS := [
	"res://assets/ui/portraits",
	"res://assets/ui/operators",
	"res://assets/story/portraits",
]

const EXTENSIONS := ["png", "webp", "jpg", "svg"]

static var _texture_cache: Dictionary = {}


static func get_icon_texture(cfg: Dictionary) -> Texture2D:
	var key := StringName(cfg.get("icon_key", ""))
	return get_texture(key, &"icon")


static func get_portrait_texture(cfg: Dictionary) -> Texture2D:
	var key := StringName(cfg.get("portrait_key", cfg.get("icon_key", "")))
	return get_texture(key, &"portrait")


static func get_texture(key: StringName, kind: StringName = &"icon") -> Texture2D:
	if key == StringName():
		return null
	var cache_key := "%s:%s" % [String(kind), String(key)]
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]
	var texture := _load_first_existing(_candidate_paths(key, kind))
	_texture_cache[cache_key] = texture
	return texture


static func _candidate_paths(key: StringName, kind: StringName) -> PackedStringArray:
	var dirs := PORTRAIT_DIRS if kind == &"portrait" else ICON_DIRS
	var paths := PackedStringArray()
	for dir in dirs:
		for extension in EXTENSIONS:
			paths.append("%s/%s.%s" % [dir, String(key), extension])
	return paths


static func _load_first_existing(paths: PackedStringArray) -> Texture2D:
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null
