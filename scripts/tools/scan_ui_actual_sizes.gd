extends SceneTree

const SCENE_ROOT := "res://scenes"
const OUTPUT_PATH := "res://assets/ui/build/ui_asset_actual_sizes.json"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const GAME_SCENE_PATH := "res://scenes/game/Game.tscn"
const STYLE_DIR := "res://assets/ui/styles/"
const GENERATED_DIR := "res://assets/ui/generated/"

var _failed := false
var _scene_paths: Array[String] = []
var _scene_index := 0
var _root_node: Node = null
var _result: Dictionary = {
	"version": 1,
	"viewport_size": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
	"scene_root": SCENE_ROOT,
	"styles": {},
	"textures": {},
}


func _init() -> void:
	root.size = VIEWPORT_SIZE
	_scene_paths = _find_files(SCENE_ROOT, ".tscn")
	_scene_paths.sort()
	call_deferred("_scan_next_scene")


func _scan_next_scene() -> void:
	if _root_node != null:
		_root_node.queue_free()
		_root_node = null
	if _scene_index >= _scene_paths.size():
		_finalize_max_sizes("styles")
		_finalize_max_sizes("textures")
		_write_json(OUTPUT_PATH, _result)
		quit(1 if _failed else 0)
		return
	var scene_path := _scene_paths[_scene_index]
	_scene_index += 1
	var packed := load(scene_path) as PackedScene
	if packed == null:
		call_deferred("_scan_next_scene")
		return
	_root_node = packed.instantiate()
	if _root_node == null:
		call_deferred("_scan_next_scene")
		return
	_disable_runtime_callbacks(_root_node)
	root.add_child(_root_node)
	_disable_runtime_callbacks(_root_node)
	if _root_node is Control:
		var control := _root_node as Control
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.size = Vector2(VIEWPORT_SIZE)
	call_deferred("_collect_after_layout", scene_path)


func _collect_after_layout(scene_path: String) -> void:
	await process_frame
	await process_frame
	if _root_node != null:
		_collect_node(scene_path, _root_node)
	call_deferred("_scan_next_scene")


func _collect_node(scene_path: String, node: Node) -> void:
	if node is Control:
		_collect_control(scene_path, node as Control)
	for child in node.get_children():
		_collect_node(scene_path, child)


func _collect_control(scene_path: String, control: Control) -> void:
	if control.size.x <= 0.0 or control.size.y <= 0.0:
		return
	var node_path := _node_path(control)
	for property_info in control.get_property_list():
		var property_name := String(property_info.get("name", ""))
		if property_name.begins_with("theme_override_styles/"):
			var value: Variant = control.get(property_name)
			if value is StyleBox:
				var style_path := (value as StyleBox).resource_path
				if style_path.begins_with(STYLE_DIR):
					_record_use("styles", style_path, scene_path, node_path, property_name.trim_prefix("theme_override_styles/"), control.size)
		elif property_name == "texture" or property_name == "icon":
			var texture_value: Variant = control.get(property_name)
			if texture_value is Texture2D:
				var texture_path := (texture_value as Texture2D).resource_path
				if texture_path.begins_with(GENERATED_DIR):
					_record_use("textures", texture_path, scene_path, node_path, property_name, control.size)


func _disable_runtime_callbacks(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	for child in node.get_children():
		_disable_runtime_callbacks(child)


func _record_use(bucket_name: String, asset_path: String, scene_path: String, node_path: String, slot: String, size: Vector2) -> void:
	var bucket: Dictionary = _result[bucket_name]
	if not bucket.has(asset_path):
		bucket[asset_path] = {
			"max_size": [0, 0],
			"game_max_size": [0, 0],
			"uses": [],
		}
	var record: Dictionary = bucket[asset_path]
	var max_size: Array = record.get("max_size", [0, 0])
	var width := int(ceilf(size.x))
	var height := int(ceilf(size.y))
	max_size[0] = maxi(int(max_size[0]), width)
	max_size[1] = maxi(int(max_size[1]), height)
	record["max_size"] = max_size
	if scene_path == GAME_SCENE_PATH:
		var game_max_size: Array = record.get("game_max_size", [0, 0])
		game_max_size[0] = maxi(int(game_max_size[0]), width)
		game_max_size[1] = maxi(int(game_max_size[1]), height)
		record["game_max_size"] = game_max_size
	var uses: Array = record["uses"]
	uses.append({
		"scene": scene_path,
		"node": node_path,
		"slot": slot,
		"size": [width, height],
	})
	bucket[asset_path] = record
	_result[bucket_name] = bucket


func _finalize_max_sizes(bucket_name: String) -> void:
	var bucket: Dictionary = _result.get(bucket_name, {})
	for asset_path in bucket.keys():
		var record: Dictionary = bucket[asset_path]
		var game_max_size: Array = record.get("game_max_size", [0, 0])
		if int(game_max_size[0]) > 0 and int(game_max_size[1]) > 0:
			record["max_size"] = [int(game_max_size[0]), int(game_max_size[1])]
		bucket[asset_path] = record
	_result[bucket_name] = bucket


func _node_path(node: Node) -> String:
	if _root_node == null:
		return str(node.name)
	if node == _root_node:
		return "."
	return str(_root_node.get_path_to(node))


func _find_files(root_path: String, extension: String) -> Array[String]:
	var found: Array[String] = []
	_find_files_recursive(root_path, extension, found)
	found.sort()
	return found


func _find_files_recursive(path: String, extension: String, found: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var full_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			if full_path == "res://scenes/debug":
				continue
			_find_files_recursive(full_path, extension, found)
		elif entry.ends_with(extension):
			found.append(full_path)
	dir.list_dir_end()


func _write_json(path: String, data: Dictionary) -> void:
	var dir_path := path.get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	if error != OK:
		_failed = true
		push_error("Failed to create directory %s: %s" % [dir_path, error_string(error)])
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failed = true
		push_error("Failed to write %s" % path)
		return
	file.store_string(_stable_stringify(data) + "\n")


func _stable_stringify(value: Variant) -> String:
	if value is Dictionary:
		var dict := value as Dictionary
		var keys := dict.keys()
		keys.sort()
		var entries := PackedStringArray()
		for key in keys:
			entries.append("%s:%s" % [JSON.stringify(String(key)), _stable_stringify(dict[key])])
		return "{%s}" % ",".join(entries)
	if value is Array:
		var parts := PackedStringArray()
		for item in value as Array:
			parts.append(_stable_stringify(item))
		return "[%s]" % ",".join(parts)
	return JSON.stringify(value)
