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
		if scene_path == GAME_SCENE_PATH:
			control.set_anchors_preset(Control.PRESET_FULL_RECT)
			control.size = Vector2(VIEWPORT_SIZE)
		else:
			var minimum_size := control.get_combined_minimum_size()
			control.size = Vector2(
				maxf(1.0, maxf(control.size.x, minimum_size.x)),
				maxf(1.0, maxf(control.size.y, minimum_size.y))
			)
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
	var node_path := _node_path(control)
	for property_info in control.get_property_list():
		var property_name := String(property_info.get("name", ""))
		if property_name.begins_with("theme_override_styles/"):
			var value: Variant = control.get(property_name)
			if value is StyleBox:
				var style_path := (value as StyleBox).resource_path
				if style_path.begins_with(STYLE_DIR):
					var style_size := _style_use_size(control)
					if style_size.x > 0.0 and style_size.y > 0.0:
						_record_use("styles", style_path, scene_path, node_path, property_name.trim_prefix("theme_override_styles/"), style_size)
		elif property_name == "texture" or property_name == "icon":
			var texture_value: Variant = control.get(property_name)
			if texture_value is Texture2D:
				var texture_path := (texture_value as Texture2D).resource_path
				if texture_path.begins_with(GENERATED_DIR):
					var texture_size := _texture_use_size(control, property_name, texture_value as Texture2D)
					if texture_size.x > 0.0 and texture_size.y > 0.0:
						_record_use("textures", texture_path, scene_path, node_path, property_name, texture_size)


func _style_use_size(control: Control) -> Vector2:
	var size := _control_use_size(control)
	if _is_tiny_fill_size(control, size):
		var full_bar_size := _progress_fill_full_size(control)
		if full_bar_size.x > 0.0 and full_bar_size.y > 0.0:
			return full_bar_size
	if size.x > 0.0 and size.y > 0.0:
		return size
	var parent_control := control.get_parent() as Control
	if parent_control != null:
		size = _control_use_size(parent_control)
		if size.x > 0.0 and size.y > 0.0:
			return size
	return Vector2.ZERO


func _is_tiny_fill_size(control: Control, size: Vector2) -> bool:
	var node_name := String(control.name).to_lower()
	return node_name.ends_with("fill") and (size.x <= 1.0 or size.y <= 1.0)


func _progress_fill_full_size(control: Control) -> Vector2:
	var clip := control.get_parent() as Control
	if clip == null:
		return Vector2.ZERO
	var bar := clip.get_parent() as Control
	if bar != null:
		for child in bar.get_children():
			if child is Control and String(child.name).to_lower().contains("track"):
				var track_size := _control_use_size(child as Control)
				if track_size.x > 0.0 and track_size.y > 0.0:
					return track_size
	var clip_size := _control_use_size(clip)
	if clip_size.x > 0.0 and clip_size.y > 0.0:
		return clip_size
	if bar != null:
		var bar_size := _control_use_size(bar)
		if bar_size.x > 0.0 and bar_size.y > 0.0:
			return bar_size
	return Vector2.ZERO


func _control_use_size(control: Control) -> Vector2:
	var width := control.size.x
	var height := control.size.y
	var minimum_size := control.get_combined_minimum_size()
	width = maxf(width, minimum_size.x)
	height = maxf(height, minimum_size.y)
	width = maxf(width, control.custom_minimum_size.x)
	height = maxf(height, control.custom_minimum_size.y)
	if width <= 0.0 or height <= 0.0:
		return Vector2.ZERO
	return Vector2(width, height)


func _texture_use_size(control: Control, property_name: String, texture: Texture2D) -> Vector2:
	if property_name == "icon" and control is Button:
		return _button_icon_use_size(control as Button, texture)
	if property_name == "texture" and control is TextureRect:
		return _texture_rect_use_size(control as TextureRect)
	return _control_use_size(control)


func _texture_rect_use_size(texture_rect: TextureRect) -> Vector2:
	var slot_size := _control_use_size(texture_rect)
	if slot_size.x <= 0.0 or slot_size.y <= 0.0:
		return Vector2.ZERO
	match texture_rect.stretch_mode:
		TextureRect.STRETCH_KEEP_CENTERED:
			var texture := texture_rect.texture
			if texture == null:
				return slot_size
			return Vector2(minf(float(texture.get_width()), slot_size.x), minf(float(texture.get_height()), slot_size.y))
		TextureRect.STRETCH_KEEP_ASPECT, TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			var side := minf(slot_size.x, slot_size.y)
			return Vector2(side, side)
	return slot_size


func _button_icon_use_size(button: Button, texture: Texture2D) -> Vector2:
	var button_size := _control_use_size(button)
	if button_size.x <= 0.0 or button_size.y <= 0.0:
		return Vector2.ZERO
	var icon_max_width := float(button.get_theme_constant("icon_max_width"))
	var side := 0.0
	if icon_max_width > 0.0:
		side = icon_max_width
	elif bool(button.get("expand_icon")):
		side = minf(button_size.x, button_size.y)
	else:
		side = minf(minf(float(texture.get_width()), float(texture.get_height())), minf(button_size.x, button_size.y))
	side = maxf(1.0, side)
	return Vector2(side, side)


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
		var max_size: Array = record.get("max_size", [0, 0])
		var game_max_size: Array = record.get("game_max_size", [0, 0])
		var width := int(max_size[0])
		var height := int(max_size[1])
		if int(game_max_size[0]) > 1:
			width = int(game_max_size[0])
		if int(game_max_size[1]) > 1:
			height = int(game_max_size[1])
		record["max_size"] = [width, height]
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
