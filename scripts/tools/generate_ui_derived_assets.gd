extends SceneTree

const GENERATOR_VERSION := "ui-derived-assets-v8-icon-texturerect-source-size"
const CONFIG_PATH := "res://assets/ui/build/ui_asset_build.json"
const MANIFEST_PATH := "res://assets/ui/build/ui_asset_build_manifest.json"
const ACTUAL_SIZE_PATH := "res://assets/ui/build/ui_asset_actual_sizes.json"
const SCAN_SCRIPT_PATH := "scripts/tools/scan_ui_actual_sizes.gd"

var _failed := false
var _manifest: Dictionary = {}
var _actual_sizes: Dictionary = {}


func _init() -> void:
	_run()
	quit(1 if _failed else 0)


func _run() -> void:
	_scan_actual_sizes()
	if _failed:
		return
	_actual_sizes = _read_optional_json_dictionary(ACTUAL_SIZE_PATH)
	var config := _read_json_dictionary(CONFIG_PATH)
	if _failed:
		return
	if int(config.get("version", 0)) != 1:
		_fail("Unsupported ui asset build version in %s" % CONFIG_PATH)
		return

	_manifest = _read_manifest()
	_manifest["version"] = 1
	_manifest["generator_version"] = GENERATOR_VERSION
	if not (_manifest.get("assets", {}) is Dictionary):
		_manifest["assets"] = {}

	var assets: Dictionary = config.get("assets", {})
	var selected_assets := _selected_asset_names()
	var asset_names := assets.keys()
	asset_names.sort()
	for asset_name in asset_names:
		var asset_name_text := String(asset_name)
		if not selected_assets.is_empty() and not selected_assets.has(asset_name_text):
			continue
		var asset_config: Variant = assets[asset_name]
		if not (asset_config is Dictionary):
			_fail("Asset %s must be a dictionary." % String(asset_name))
			continue
		_process_asset(asset_name_text, asset_config as Dictionary)

	if _failed:
		return
	_write_json(MANIFEST_PATH, _manifest)


func _selected_asset_names() -> Dictionary:
	var selected: Dictionary = {}
	var args := OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	var index := 0
	while index < args.size():
		var arg := String(args[index])
		if arg == "--asset" and index + 1 < args.size():
			selected[String(args[index + 1])] = true
			index += 2
			continue
		if arg.begins_with("--asset="):
			selected[arg.trim_prefix("--asset=")] = true
		index += 1
	return selected


func _scan_actual_sizes() -> void:
	if not FileAccess.file_exists("res://%s" % SCAN_SCRIPT_PATH):
		_fail("Missing actual-size scan script: %s" % SCAN_SCRIPT_PATH)
		return
	var output: Array = []
	var args := PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		SCAN_SCRIPT_PATH,
	])
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true, false)
	for line in output:
		print(line)
	if exit_code != 0:
		_fail("Failed to scan actual UI sizes before generating assets: exit %d" % exit_code)
	elif not FileAccess.file_exists(ACTUAL_SIZE_PATH):
		_fail("Actual UI size scan did not write %s" % ACTUAL_SIZE_PATH)


func _process_asset(asset_name: String, asset_config: Dictionary) -> void:
	var kind := String(asset_config.get("kind", ""))
	if kind != "stylebox_texture" and kind != "texture":
		_fail("%s has unsupported kind '%s'." % [asset_name, kind])
		return

	var source_png := _required_path(asset_name, asset_config, "source_png")
	var output_png := _required_path(asset_name, asset_config, "output_png")
	var template_style := ""
	var output_style := ""
	if kind == "stylebox_texture":
		template_style = _required_path(asset_name, asset_config, "template_style")
		output_style = _required_path(asset_name, asset_config, "output_style")
	if _failed:
		return

	_require_existing_file(asset_name, source_png)
	if kind == "stylebox_texture":
		_require_existing_file(asset_name, template_style)
	if _failed:
		return

	var actual_target := _resolved_target_size(asset_config)
	var pre_scale := _resolve_pre_scale(asset_name, asset_config)
	if pre_scale <= 0:
		return

	var input_hash := _input_hash(source_png, template_style, asset_config, actual_target)
	var manifest_assets: Dictionary = _manifest["assets"]
	var previous: Dictionary = manifest_assets.get(asset_name, {})
	if String(previous.get("input_hash", "")) == input_hash and _res_file_exists(output_png) and (kind == "texture" or _res_file_exists(output_style)):
		previous["output_png"] = output_png
		previous["pre_scale"] = pre_scale
		previous["actual_target_size"] = [actual_target.x, actual_target.y]
		if kind == "stylebox_texture":
			previous["output_style"] = output_style
		manifest_assets[asset_name] = previous
		print("skip %s" % asset_name)
		return

	var png_scale := _generate_png(asset_name, source_png, output_png, pre_scale, actual_target, asset_config, String(asset_config.get("interpolation", "nearest")))
	if kind == "stylebox_texture":
		_generate_style(asset_name, template_style, output_png, output_style, png_scale, asset_config)
	if _failed:
		return

	var record := {
		"input_hash": input_hash,
		"output_png": output_png,
		"pre_scale": pre_scale,
		"actual_target_size": [actual_target.x, actual_target.y],
		"png_scale": [png_scale.x, png_scale.y],
	}
	if kind == "stylebox_texture":
		record["output_style"] = output_style
	manifest_assets[asset_name] = record
	print("generated %s" % asset_name)


func _generate_png(asset_name: String, source_png: String, output_png: String, pre_scale: int, target_size: Vector2i, asset_config: Dictionary, interpolation: String) -> Vector2:
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(source_png))
	if load_error != OK:
		_fail("%s failed to load source PNG %s: %s" % [asset_name, source_png, error_string(load_error)])
		return Vector2.ONE
	var source_width := image.get_width()
	var source_height := image.get_height()
	var output_width := source_width
	var output_height := source_height
	if target_size.x > 0 and target_size.y > 0:
		if String(asset_config.get("kind", "")) == "stylebox_texture":
			if String(asset_config.get("png_scale_mode", "")) == "exact_target":
				output_width = target_size.x
				output_height = target_size.y
			else:
				var scale := _ninepatch_preserve_scale(Vector2i(source_width, source_height), target_size)
				output_width = maxi(1, int(round(float(source_width) * scale)))
				output_height = maxi(1, int(round(float(source_height) * scale)))
		else:
			if _should_preserve_texture_source_size(asset_name, asset_config):
				output_width = source_width
				output_height = source_height
			else:
				output_width = target_size.x
				output_height = target_size.y
	elif pre_scale != 1:
		output_width = source_width * pre_scale
		output_height = source_height * pre_scale
	if output_width != source_width or output_height != source_height:
		var mode := _interpolation_mode(asset_name, interpolation)
		if _failed:
			return Vector2.ONE
		image.resize(output_width, output_height, mode)
	_ensure_parent_dir(output_png)
	var save_error := image.save_png(output_png)
	if save_error != OK:
		_fail("%s failed to save output PNG %s: %s" % [asset_name, output_png, error_string(save_error)])
		return Vector2.ONE
	return Vector2(float(output_width) / float(source_width), float(output_height) / float(source_height))


func _interpolation_mode(asset_name: String, interpolation: String) -> int:
	if interpolation == "nearest":
		return Image.INTERPOLATE_NEAREST
	if interpolation == "bilinear":
		return Image.INTERPOLATE_BILINEAR
	_fail("%s has unsupported interpolation '%s'." % [asset_name, interpolation])
	return Image.INTERPOLATE_NEAREST


func _ninepatch_preserve_scale(source_size: Vector2i, target_size: Vector2i) -> float:
	if source_size.x <= 0 or source_size.y <= 0 or target_size.x <= 0 or target_size.y <= 0:
		return 1.0
	var target_is_landscape := target_size.x >= target_size.y
	var scale := float(target_size.y) / float(source_size.y) if target_is_landscape else float(target_size.x) / float(source_size.x)
	return minf(1.0, maxf(scale, 0.0))


func _should_preserve_texture_source_size(asset_name: String, asset_config: Dictionary) -> bool:
	if String(asset_config.get("kind", "")) != "texture":
		return false
	if not asset_name.begins_with("icon_"):
		return false
	var output_png := String(asset_config.get("output_png", ""))
	if output_png.is_empty():
		return false
	var bucket: Dictionary = _actual_sizes.get("textures", {})
	var record: Dictionary = bucket.get(output_png, {})
	var raw_uses: Variant = record.get("uses", [])
	if not (raw_uses is Array):
		return true
	var uses := raw_uses as Array
	if uses.is_empty():
		return true
	for use in uses:
		if not (use is Dictionary):
			continue
		if String((use as Dictionary).get("slot", "")) == "icon":
			return false
	return true


func _generate_style(asset_name: String, template_style: String, output_png: String, output_style: String, png_scale: Vector2, asset_config: Dictionary) -> void:
	if String(asset_config.get("margin_mode", "")) != "scale_from_template":
		_fail("%s margin_mode must be scale_from_template." % asset_name)
		return
	if String(asset_config.get("content_margin_mode", "")) != "scale_from_template":
		_fail("%s content_margin_mode must be scale_from_template." % asset_name)
		return

	var loaded := ResourceLoader.load(template_style, "StyleBox", ResourceLoader.CACHE_MODE_REPLACE)
	if not (loaded is StyleBoxTexture):
		_fail("%s template_style must be StyleBoxTexture: %s" % [asset_name, template_style])
		return
	var style := (loaded as StyleBoxTexture).duplicate(true) as StyleBoxTexture
	style.texture_margin_left = style.texture_margin_left * png_scale.x
	style.texture_margin_top = style.texture_margin_top * png_scale.y
	style.texture_margin_right = style.texture_margin_right * png_scale.x
	style.texture_margin_bottom = style.texture_margin_bottom * png_scale.y
	style.content_margin_left = style.content_margin_left * png_scale.x
	style.content_margin_top = style.content_margin_top * png_scale.y
	style.content_margin_right = style.content_margin_right * png_scale.x
	style.content_margin_bottom = style.content_margin_bottom * png_scale.y
	var output_png_size := _png_size(output_png)
	_clamp_style_margins_to_size(style, output_png_size)
	_ensure_parent_dir(output_style)
	var save_error := _save_stylebox_texture(output_style, output_png, style)
	if save_error != OK:
		_fail("%s failed to save output style %s: %s" % [asset_name, output_style, error_string(save_error)])


func _png_size(path: String) -> Vector2:
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(path))
	if load_error != OK:
		_fail("Failed to read generated PNG size %s: %s" % [path, error_string(load_error)])
		return Vector2.ZERO
	return Vector2(float(image.get_width()), float(image.get_height()))


func _clamp_style_margins_to_size(style: StyleBoxTexture, png_size: Vector2) -> void:
	if png_size.x <= 0.0 or png_size.y <= 0.0:
		return
	var texture_horizontal := _clamped_margin_pair(style.texture_margin_left, style.texture_margin_right, png_size.x)
	var texture_vertical := _clamped_margin_pair(style.texture_margin_top, style.texture_margin_bottom, png_size.y)
	var content_horizontal := _clamped_margin_pair(style.content_margin_left, style.content_margin_right, png_size.x)
	var content_vertical := _clamped_margin_pair(style.content_margin_top, style.content_margin_bottom, png_size.y)
	style.texture_margin_left = texture_horizontal.x
	style.texture_margin_right = texture_horizontal.y
	style.texture_margin_top = texture_vertical.x
	style.texture_margin_bottom = texture_vertical.y
	style.content_margin_left = content_horizontal.x
	style.content_margin_right = content_horizontal.y
	style.content_margin_top = content_vertical.x
	style.content_margin_bottom = content_vertical.y


func _clamped_margin_pair(first: float, second: float, limit: float) -> Vector2:
	var max_total := maxf(0.0, limit - 1.0)
	var total := first + second
	if total <= max_total:
		return Vector2(maxf(0.0, first), maxf(0.0, second))
	if total <= 0.0:
		return Vector2.ZERO
	var scale := max_total / total
	return Vector2(maxf(0.0, first * scale), maxf(0.0, second * scale))


func _save_stylebox_texture(output_style: String, output_png: String, style: StyleBoxTexture) -> Error:
	var file := FileAccess.open(output_style, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_OPEN
	var lines := PackedStringArray([
		"[gd_resource type=\"StyleBoxTexture\" format=3]",
		"",
		"[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1_texture\"]" % output_png,
		"",
		"[resource]",
		"content_margin_left = %s" % _format_float(style.content_margin_left),
		"content_margin_top = %s" % _format_float(style.content_margin_top),
		"content_margin_right = %s" % _format_float(style.content_margin_right),
		"content_margin_bottom = %s" % _format_float(style.content_margin_bottom),
		"texture = ExtResource(\"1_texture\")",
		"texture_margin_left = %s" % _format_float(style.texture_margin_left),
		"texture_margin_top = %s" % _format_float(style.texture_margin_top),
		"texture_margin_right = %s" % _format_float(style.texture_margin_right),
		"texture_margin_bottom = %s" % _format_float(style.texture_margin_bottom),
		"draw_center = %s" % ("true" if style.draw_center else "false"),
	])
	file.store_string("\n".join(lines) + "\n")
	return OK


func _format_float(value: float) -> String:
	return "%.4f" % value


func _resolve_pre_scale(asset_name: String, asset_config: Dictionary) -> int:
	var raw: Variant = asset_config.get("pre_scale", 1)
	if raw is int or raw is float:
		var explicit := int(raw)
		if explicit < 1:
			_fail("%s pre_scale must be >= 1." % asset_name)
			return 0
		return explicit
	if String(raw) != "auto_integer":
		_fail("%s pre_scale must be an integer or auto_integer." % asset_name)
		return 0
	var target := _resolved_target_size(asset_config)
	if target == Vector2i.ZERO:
		target = _required_size(asset_name, asset_config, "target_size")
	var base := _required_size(asset_name, asset_config, "base_size")
	if target == Vector2i.ZERO or base == Vector2i.ZERO:
		return 0
	var max_pre_scale := int(asset_config.get("max_pre_scale", 1))
	if max_pre_scale < 1:
		_fail("%s max_pre_scale must be >= 1." % asset_name)
		return 0
	var scale_x := float(target.x) / float(base.x)
	var scale_y := float(target.y) / float(base.y)
	return clampi(int(ceil(maxf(scale_x, scale_y))), 1, max_pre_scale)


func _actual_target_size(asset_config: Dictionary) -> Vector2i:
	var kind := String(asset_config.get("kind", ""))
	var bucket_name := "styles" if kind == "stylebox_texture" else "textures"
	var path_key := "output_style" if kind == "stylebox_texture" else "output_png"
	var asset_path := String(asset_config.get(path_key, ""))
	if asset_path.is_empty():
		return Vector2i.ZERO
	var bucket: Dictionary = _actual_sizes.get(bucket_name, {})
	if not bucket.has(asset_path):
		return Vector2i.ZERO
	var record: Dictionary = bucket.get(asset_path, {})
	var raw_size: Variant = record.get("max_size", [])
	if not (raw_size is Array) or (raw_size as Array).size() != 2:
		return Vector2i.ZERO
	var size := Vector2i(int((raw_size as Array)[0]), int((raw_size as Array)[1]))
	if size.x <= 0 or size.y <= 0:
		return Vector2i.ZERO
	return size


func _resolved_target_size(asset_config: Dictionary) -> Vector2i:
	var actual_target := _actual_target_size(asset_config)
	if actual_target == Vector2i.ZERO:
		return _optional_size(asset_config, "target_size")
	if String(asset_config.get("kind", "")) == "stylebox_texture":
		return _with_optional_target_floor(actual_target, asset_config)
	return actual_target


func _with_optional_target_floor(actual_target: Vector2i, asset_config: Dictionary) -> Vector2i:
	var config_target := _optional_size(asset_config, "target_size")
	if config_target == Vector2i.ZERO:
		return actual_target
	return Vector2i(maxi(actual_target.x, config_target.x), maxi(actual_target.y, config_target.y))


func _input_hash(source_png: String, template_style: String, asset_config: Dictionary, actual_target: Vector2i) -> String:
	var parts := PackedStringArray()
	parts.append(GENERATOR_VERSION)
	parts.append(_file_sha256(source_png))
	if not template_style.is_empty():
		parts.append(_file_sha256(template_style))
	parts.append(_sha256_text(_stable_stringify(asset_config)))
	parts.append("%d,%d" % [actual_target.x, actual_target.y])
	return "sha256:%s" % _sha256_text("\n".join(parts))


func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Failed to read %s for hashing." % path)
		return ""
	return _sha256_bytes(file.get_buffer(file.get_length()))


func _sha256_text(text: String) -> String:
	return _sha256_bytes(text.to_utf8_buffer())


func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	var start_error := context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		_fail("Failed to start SHA-256 hashing: %s" % error_string(start_error))
		return ""
	var update_error := context.update(bytes)
	if update_error != OK:
		_fail("Failed to update SHA-256 hashing: %s" % error_string(update_error))
		return ""
	var digest := context.finish()
	return digest.hex_encode()


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


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("Missing JSON file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Failed to open JSON file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_fail("JSON root must be a dictionary: %s" % path)
		return {}
	return parsed as Dictionary


func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {"version": 1, "generator_version": GENERATOR_VERSION, "assets": {}}
	return _read_json_dictionary(MANIFEST_PATH)


func _read_optional_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _write_json(path: String, data: Dictionary) -> void:
	_ensure_parent_dir(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Failed to write JSON file: %s" % path)
		return
	file.store_string(_pretty_json(data) + "\n")


func _pretty_json(data: Dictionary) -> String:
	return _stable_stringify(data)


func _required_path(asset_name: String, asset_config: Dictionary, key: String) -> String:
	var path := String(asset_config.get(key, "")).strip_edges()
	if path.is_empty():
		_fail("%s missing required path '%s'." % [asset_name, key])
	elif not path.begins_with("res://"):
		_fail("%s path '%s' must start with res://." % [asset_name, key])
	return path


func _required_size(asset_name: String, asset_config: Dictionary, key: String) -> Vector2i:
	var raw: Variant = asset_config.get(key, [])
	if not (raw is Array) or (raw as Array).size() != 2:
		_fail("%s %s must be [width, height]." % [asset_name, key])
		return Vector2i.ZERO
	var size := Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	if size.x <= 0 or size.y <= 0:
		_fail("%s %s must contain positive dimensions." % [asset_name, key])
		return Vector2i.ZERO
	return size


func _optional_size(asset_config: Dictionary, key: String) -> Vector2i:
	var raw: Variant = asset_config.get(key, [])
	if not (raw is Array) or (raw as Array).size() != 2:
		return Vector2i.ZERO
	var size := Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	if size.x <= 0 or size.y <= 0:
		return Vector2i.ZERO
	return size


func _require_existing_file(asset_name: String, path: String) -> void:
	if not _res_file_exists(path):
		_fail("%s missing required input file: %s" % [asset_name, path])


func _res_file_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)


func _ensure_parent_dir(path: String) -> void:
	var dir_path := path.get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	if error != OK:
		_fail("Failed to create directory %s: %s" % [dir_path, error_string(error)])


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
