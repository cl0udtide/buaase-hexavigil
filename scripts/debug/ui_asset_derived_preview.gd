@tool
extends Control

const CONFIG_PATH := "res://assets/ui/build/ui_asset_build.json"
const ACTUAL_SIZE_PATH := "res://assets/ui/build/ui_asset_actual_sizes.json"
const TEXTURE_MARGIN_COLOR := Color(1.0, 0.38, 0.18, 0.95)
const TEXTURE_MARGIN_FILL := Color(1.0, 0.38, 0.18, 0.08)
const CONTENT_MARGIN_COLOR := Color(0.18, 0.86, 1.0, 0.95)
const CONTENT_MARGIN_FILL := Color(0.18, 0.86, 1.0, 0.07)

var _root: MarginContainer
var _body: VBoxContainer
var _actual_sizes: Dictionary = {}


class MarginGuideOverlay:
	extends Control

	var source_size := Vector2.ZERO
	var margins := Vector4.ZERO
	var line_color := Color.WHITE
	var fill_color := Color.TRANSPARENT
	var label_text := ""
	var fit_to_slot := true


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	func _draw() -> void:
		if source_size.x <= 0.0 or source_size.y <= 0.0:
			return
		var image_rect := _fit_rect(source_size, size) if fit_to_slot else Rect2(Vector2.ZERO, size)
		var scale_x := image_rect.size.x / source_size.x
		var scale_y := image_rect.size.y / source_size.y
		var left := image_rect.position.x + margins.x * scale_x
		var top := image_rect.position.y + margins.y * scale_y
		var right := image_rect.position.x + image_rect.size.x - margins.z * scale_x
		var bottom := image_rect.position.y + image_rect.size.y - margins.w * scale_y
		var inner := Rect2(Vector2(left, top), Vector2(maxf(0.0, right - left), maxf(0.0, bottom - top)))
		draw_rect(inner, fill_color, true)
		draw_rect(image_rect, Color(line_color.r, line_color.g, line_color.b, 0.35), false, 1.0)
		draw_line(Vector2(left, image_rect.position.y), Vector2(left, image_rect.end.y), line_color, 1.5)
		draw_line(Vector2(right, image_rect.position.y), Vector2(right, image_rect.end.y), line_color, 1.5)
		draw_line(Vector2(image_rect.position.x, top), Vector2(image_rect.end.x, top), line_color, 1.5)
		draw_line(Vector2(image_rect.position.x, bottom), Vector2(image_rect.end.x, bottom), line_color, 1.5)


	func _fit_rect(texture_size: Vector2, slot_size: Vector2) -> Rect2:
		if texture_size.x <= 0.0 or texture_size.y <= 0.0 or slot_size.x <= 0.0 or slot_size.y <= 0.0:
			return Rect2(Vector2.ZERO, slot_size)
		var scale := minf(slot_size.x / texture_size.x, slot_size.y / texture_size.y)
		var fitted_size := texture_size * scale
		return Rect2((slot_size - fitted_size) * 0.5, fitted_size)


func _ready() -> void:
	_rebuild_deferred()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reload()


func _rebuild_deferred() -> void:
	if not is_inside_tree():
		return
	call_deferred("_rebuild")


func _reload() -> void:
	call_deferred("_reload_deferred")


func _reload_deferred() -> void:
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.free()

	var background := ColorRect.new()
	background.name = "_PreviewBackground"
	background.color = Color(0.040, 0.050, 0.062, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_root = MarginContainer.new()
	_root.name = "_PreviewRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("margin_left", 24)
	_root.add_theme_constant_override("margin_top", 18)
	_root.add_theme_constant_override("margin_right", 24)
	_root.add_theme_constant_override("margin_bottom", 18)
	add_child(_root)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(scroll)

	_body = VBoxContainer.new()
	_body.name = "DerivedAssetList"
	_body.custom_minimum_size = Vector2(1780.0, 0.0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_body)

	var config := _read_config()
	var assets: Dictionary = config.get("assets", {})
	_actual_sizes = _read_actual_sizes()
	_body.add_child(_header(assets.size()))
	var names := assets.keys()
	names.sort()
	for asset_name in names:
		_add_asset_row(String(asset_name), assets[asset_name] as Dictionary)


func _header(asset_count: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat_box(Color(0.078, 0.098, 0.120, 0.96), Color(0.250, 0.330, 0.400, 1.0), 1, 6))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	box.add_child(_label("Derived UI asset preview", 22, Color(0.930, 0.965, 1.000, 1.0)))
	box.add_child(_label("%d configured assets from %s. Press R to reload generated resources." % [asset_count, CONFIG_PATH], 14, Color(0.720, 0.800, 0.860, 1.0)))
	box.add_child(_label("Guides: orange = texture margins, cyan = content margins. This scene edits template margins only.", 14, Color(0.820, 0.900, 0.940, 1.0)))
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	box.add_child(button_row)
	var generate_button := Button.new()
	generate_button.text = "Generate Assets"
	generate_button.custom_minimum_size = Vector2(150.0, 34.0)
	var status := _label("Save template margins, then generate.", 13, Color(0.620, 0.700, 0.760, 1.0))
	generate_button.pressed.connect(func() -> void:
		status.text = "generating..."
		var exit_code := _run_generator()
		status.text = "generated and reloaded" if exit_code == 0 else "generate failed: exit %d" % exit_code
		_reload()
	, CONNECT_DEFERRED)
	button_row.add_child(generate_button)
	var reload_button := Button.new()
	reload_button.text = "Reload"
	reload_button.custom_minimum_size = Vector2(96.0, 34.0)
	reload_button.pressed.connect(_reload, CONNECT_DEFERRED)
	button_row.add_child(reload_button)
	button_row.add_child(status)
	return panel


func _add_asset_row(asset_name: String, asset: Dictionary) -> void:
	var section := PanelContainer.new()
	section.add_theme_stylebox_override("panel", _flat_box(Color(0.062, 0.078, 0.096, 0.94), Color(0.150, 0.210, 0.260, 1.0), 1, 5))
	_body.add_child(section)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	section.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	box.add_child(_label(asset_name, 17, Color(0.960, 0.910, 0.700, 1.0)))
	box.add_child(_label(_asset_summary(asset), 13, Color(0.670, 0.750, 0.810, 1.0)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)

	var template_style: StyleBoxTexture = null
	var preview_style: StyleBoxTexture = null
	var png_scale := _resolved_png_scale(asset)
	var source_guides: Array[MarginGuideOverlay] = []
	var output_guides: Array[MarginGuideOverlay] = []
	var source_content_guides: Array[MarginGuideOverlay] = []
	var output_content_guides: Array[MarginGuideOverlay] = []
	if String(asset.get("kind", "")) == "stylebox_texture":
		template_style = _load_template_style(String(asset.get("template_style", "")))
		if template_style != null:
			preview_style = template_style.duplicate(true) as StyleBoxTexture
			_apply_template_margins_to_preview(preview_style, template_style, png_scale)
	var show_margin_guides := String(asset.get("kind", "")) == "stylebox_texture"
	row.add_child(_texture_block("source_png", String(asset.get("source_png", "")), _texture_margins(template_style), _content_margins(template_style), show_margin_guides, source_guides, source_content_guides))
	row.add_child(_texture_block("output_png", String(asset.get("output_png", "")), _texture_margins(preview_style), _content_margins(preview_style), show_margin_guides, output_guides, output_content_guides))

	if String(asset.get("kind", "")) == "stylebox_texture":
		row.add_child(_margin_editor_block(asset_name, asset, template_style, preview_style, png_scale, source_guides, output_guides, source_content_guides, output_content_guides))


func _texture_block(
	title: String,
	path: String,
	texture_margins: Vector4,
	content_margins: Vector4,
	show_margin_guides: bool,
	texture_guides: Array[MarginGuideOverlay],
	content_guides: Array[MarginGuideOverlay]
) -> Control:
	var block := VBoxContainer.new()
	block.custom_minimum_size = Vector2(360.0, 0.0)
	block.add_theme_constant_override("separation", 5)
	block.add_child(_label("%s  %s" % [title, path.trim_prefix("res://")], 12, Color(0.730, 0.805, 0.860, 1.0)))
	var texture := _load_preview_texture(path)
	var slot := _preview_slot(Vector2(340.0, 120.0))
	if texture != null:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(rect)
		if show_margin_guides:
			var guide := _margin_guide(Vector2(texture.get_width(), texture.get_height()), texture_margins, TEXTURE_MARGIN_COLOR, TEXTURE_MARGIN_FILL, true)
			texture_guides.append(guide)
			slot.add_child(guide)
		if show_margin_guides:
			var guide := _margin_guide(Vector2(texture.get_width(), texture.get_height()), content_margins, CONTENT_MARGIN_COLOR, CONTENT_MARGIN_FILL, true)
			content_guides.append(guide)
			slot.add_child(guide)
		block.add_child(_label("texture %.0fx%.0f" % [texture.get_width(), texture.get_height()], 12, Color(0.620, 0.700, 0.760, 1.0)))
	else:
		slot.add_child(_center_label("missing"))
	block.add_child(slot)
	return block


func _margin_editor_block(
	asset_name: String,
	asset: Dictionary,
	template_style: StyleBoxTexture,
	preview_style: StyleBoxTexture,
	png_scale: Vector2,
	source_guides: Array[MarginGuideOverlay],
	output_guides: Array[MarginGuideOverlay],
	source_content_guides: Array[MarginGuideOverlay],
	output_content_guides: Array[MarginGuideOverlay]
) -> Control:
	var block := VBoxContainer.new()
	block.custom_minimum_size = Vector2(420.0, 0.0)
	block.add_theme_constant_override("separation", 5)
	block.add_child(_label("margin editor", 12, Color(0.730, 0.805, 0.860, 1.0)))
	if template_style == null or preview_style == null:
		block.add_child(_label("not a StyleBoxTexture", 13, Color(1.000, 0.520, 0.440, 1.0)))
		return block

	var status := _label("editing template margins; Save writes assets/ui/templates", 12, Color(0.620, 0.700, 0.760, 1.0))
	block.add_child(status)
	var callback := func(_value: float) -> void:
		_apply_template_margins_to_preview(preview_style, template_style, png_scale)
		_update_margin_guides(template_style, preview_style, source_guides, output_guides, source_content_guides, output_content_guides)
		status.text = "unsaved template margins for %s" % asset_name

	block.add_child(_margin_spin_grid("texture", template_style, true, callback))
	block.add_child(_margin_spin_grid("content", template_style, false, callback))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	block.add_child(buttons)
	var save_button := Button.new()
	save_button.text = "Save Template"
	save_button.custom_minimum_size = Vector2(132.0, 32.0)
	save_button.pressed.connect(func() -> void:
		var save_error := _save_template_style(String(asset.get("template_style", "")), template_style)
		status.text = "saved %s" % String(asset.get("template_style", "")).trim_prefix("res://") if save_error == OK else "save failed: %s" % error_string(save_error)
	)
	buttons.add_child(save_button)
	var generate_button := Button.new()
	generate_button.text = "Generate"
	generate_button.custom_minimum_size = Vector2(104.0, 32.0)
	generate_button.pressed.connect(func() -> void:
		var save_error := _save_template_style(String(asset.get("template_style", "")), template_style)
		if save_error != OK:
			status.text = "save failed: %s" % error_string(save_error)
			return
		status.text = "generating %s..." % asset_name
		var exit_code := _run_generator(asset_name)
		status.text = "generated %s" % asset_name if exit_code == 0 else "generate failed: exit %d" % exit_code
		_reload()
	, CONNECT_DEFERRED)
	buttons.add_child(generate_button)
	var reset_button := Button.new()
	reset_button.text = "Reload Row"
	reset_button.custom_minimum_size = Vector2(110.0, 32.0)
	reset_button.pressed.connect(_reload, CONNECT_DEFERRED)
	buttons.add_child(reset_button)
	return block


func _margin_spin_grid(title: String, style: StyleBoxTexture, texture_margin: bool, callback: Callable) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat_box(Color(0.045, 0.058, 0.072, 0.95), Color(0.130, 0.180, 0.220, 1.0), 1, 4))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	box.add_child(_label("%s margins" % title, 12, TEXTURE_MARGIN_COLOR if texture_margin else CONTENT_MARGIN_COLOR))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	grid.add_child(_margin_spin("L", _get_margin_value(style, texture_margin, "left"), func(value: float) -> void:
		_set_margin_value(style, texture_margin, "left", value)
		callback.call(value)
	))
	grid.add_child(_margin_spin("T", _get_margin_value(style, texture_margin, "top"), func(value: float) -> void:
		_set_margin_value(style, texture_margin, "top", value)
		callback.call(value)
	))
	grid.add_child(_margin_spin("R", _get_margin_value(style, texture_margin, "right"), func(value: float) -> void:
		_set_margin_value(style, texture_margin, "right", value)
		callback.call(value)
	))
	grid.add_child(_margin_spin("B", _get_margin_value(style, texture_margin, "bottom"), func(value: float) -> void:
		_set_margin_value(style, texture_margin, "bottom", value)
		callback.call(value)
	))
	return panel


func _margin_spin(label_text: String, value: float, callback: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(186.0, 0.0)
	row.add_theme_constant_override("separation", 6)
	var label := _label(label_text, 12, Color(0.820, 0.900, 0.940, 1.0))
	label.custom_minimum_size = Vector2(18.0, 0.0)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = 0.0
	spin.max_value = 512.0
	spin.step = 1.0
	spin.value = value
	spin.custom_minimum_size = Vector2(78.0, 28.0)
	spin.value_changed.connect(callback)
	row.add_child(spin)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 512.0
	slider.step = 1.0
	slider.value = value
	slider.custom_minimum_size = Vector2(76.0, 0.0)
	spin.value_changed.connect(func(new_value: float) -> void:
		if not is_equal_approx(slider.value, new_value):
			slider.value = new_value
	)
	slider.value_changed.connect(func(new_value: float) -> void:
		if not is_equal_approx(spin.value, new_value):
			spin.value = new_value
	)
	row.add_child(slider)
	return row


func _asset_summary(asset: Dictionary) -> String:
	var base := _array_size(asset.get("base_size", []))
	var actual_target := _actual_target_size(asset)
	var config_target := _array_size(asset.get("target_size", []))
	var target_label := "%.0fx%.0f actual" % [actual_target.x, actual_target.y] if actual_target != Vector2.ZERO else "%.0fx%.0f config" % [config_target.x, config_target.y]
	return "%s  source/base %.0fx%.0f  target %s  pre_scale %s  interpolation %s" % [
		String(asset.get("kind", "")),
		base.x,
		base.y,
		target_label,
		String(asset.get("pre_scale", "")),
		String(asset.get("interpolation", "")),
	]


func _resolved_png_scale(asset: Dictionary) -> Vector2:
	var source_texture := _load_preview_texture(String(asset.get("source_png", "")))
	if source_texture != null:
		var actual_target := _actual_target_size(asset)
		if actual_target != Vector2.ZERO:
			return Vector2(actual_target.x / float(source_texture.get_width()), actual_target.y / float(source_texture.get_height()))
	var raw: Variant = asset.get("pre_scale", 1)
	if raw is int or raw is float:
		var explicit := maxf(1.0, float(raw))
		return Vector2(explicit, explicit)
	if String(raw) != "auto_integer":
		return Vector2.ONE
	var target_size := _actual_target_size(asset)
	if target_size == Vector2.ZERO:
		target_size = _array_size(asset.get("target_size", []))
	var base := _array_size(asset.get("base_size", []))
	if target_size.x <= 0.0 or target_size.y <= 0.0 or base.x <= 0.0 or base.y <= 0.0:
		return Vector2.ONE
	var max_pre_scale := maxf(1.0, float(asset.get("max_pre_scale", 1)))
	var scale_x := target_size.x / base.x
	var scale_y := target_size.y / base.y
	var resolved := clampf(ceilf(maxf(scale_x, scale_y)), 1.0, max_pre_scale)
	return Vector2(resolved, resolved)


func _actual_target_size(asset: Dictionary) -> Vector2:
	var kind := String(asset.get("kind", ""))
	var bucket_name := "styles" if kind == "stylebox_texture" else "textures"
	var path_key := "output_style" if kind == "stylebox_texture" else "output_png"
	var asset_path := String(asset.get(path_key, ""))
	if asset_path.is_empty():
		return Vector2.ZERO
	var bucket: Dictionary = _actual_sizes.get(bucket_name, {})
	if not bucket.has(asset_path):
		return Vector2.ZERO
	var record: Dictionary = bucket.get(asset_path, {})
	var raw_size: Variant = record.get("max_size", [])
	if not (raw_size is Array) or (raw_size as Array).size() != 2:
		return Vector2.ZERO
	var size := Vector2(float((raw_size as Array)[0]), float((raw_size as Array)[1]))
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return size


func _preview_slot(size: Vector2) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(maxf(1.0, size.x), maxf(1.0, size.y))
	slot.size = slot.custom_minimum_size
	slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.018, 0.024, 0.031, 1.0)
	backdrop.size = slot.size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(backdrop)
	return slot


func _margin_guide(source_size: Vector2, margins: Vector4, line_color: Color, fill_color: Color, fit_to_slot: bool) -> MarginGuideOverlay:
	var guide := MarginGuideOverlay.new()
	guide.source_size = source_size
	guide.margins = margins
	guide.line_color = line_color
	guide.fill_color = fill_color
	guide.fit_to_slot = fit_to_slot
	guide.set_anchors_preset(Control.PRESET_FULL_RECT)
	return guide


func _texture_margins(style: StyleBoxTexture) -> Vector4:
	if style == null:
		return Vector4.ZERO
	return Vector4(
		maxf(0.0, style.texture_margin_left),
		maxf(0.0, style.texture_margin_top),
		maxf(0.0, style.texture_margin_right),
		maxf(0.0, style.texture_margin_bottom)
	)


func _content_margins(style: StyleBoxTexture) -> Vector4:
	if style == null:
		return Vector4.ZERO
	return Vector4(
		maxf(0.0, style.content_margin_left),
		maxf(0.0, style.content_margin_top),
		maxf(0.0, style.content_margin_right),
		maxf(0.0, style.content_margin_bottom)
	)


func _center_label(text: String) -> Label:
	var label := _label(text, 14, Color(1.000, 0.520, 0.440, 1.0))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _read_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {"assets": {}}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {"assets": {}}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {"assets": {}}


func _read_actual_sizes() -> Dictionary:
	if not FileAccess.file_exists(ACTUAL_SIZE_PATH):
		return {}
	var file := FileAccess.open(ACTUAL_SIZE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _array_size(raw: Variant) -> Vector2:
	if not (raw is Array) or (raw as Array).size() != 2:
		return Vector2(120.0, 48.0)
	return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))


func _load_template_style(path: String) -> StyleBoxTexture:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "StyleBox", ResourceLoader.CACHE_MODE_REPLACE) as StyleBoxTexture


func _load_preview_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(path))
	if load_error != OK:
		return null
	return ImageTexture.create_from_image(image)


func _apply_template_margins_to_preview(preview_style: StyleBoxTexture, template_style: StyleBoxTexture, png_scale: Vector2) -> void:
	if preview_style == null or template_style == null:
		return
	preview_style.texture_margin_left = template_style.texture_margin_left * png_scale.x
	preview_style.texture_margin_top = template_style.texture_margin_top * png_scale.y
	preview_style.texture_margin_right = template_style.texture_margin_right * png_scale.x
	preview_style.texture_margin_bottom = template_style.texture_margin_bottom * png_scale.y
	preview_style.content_margin_left = template_style.content_margin_left * png_scale.x
	preview_style.content_margin_top = template_style.content_margin_top * png_scale.y
	preview_style.content_margin_right = template_style.content_margin_right * png_scale.x
	preview_style.content_margin_bottom = template_style.content_margin_bottom * png_scale.y


func _update_margin_guides(
	template_style: StyleBoxTexture,
	preview_style: StyleBoxTexture,
	source_guides: Array[MarginGuideOverlay],
	output_guides: Array[MarginGuideOverlay],
	source_content_guides: Array[MarginGuideOverlay],
	output_content_guides: Array[MarginGuideOverlay]
) -> void:
	var source_margins := _texture_margins(template_style)
	var output_margins := _texture_margins(preview_style)
	var source_content_margins := _content_margins(template_style)
	var output_content_margins := _content_margins(preview_style)
	for guide in source_guides:
		guide.margins = source_margins
		guide.queue_redraw()
	for guide in output_guides:
		guide.margins = output_margins
		guide.queue_redraw()
	for guide in source_content_guides:
		guide.margins = source_content_margins
		guide.queue_redraw()
	for guide in output_content_guides:
		guide.margins = output_content_margins
		guide.queue_redraw()


func _run_generator(asset_name: String = "") -> int:
	var output: Array = []
	var args := PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"scripts/tools/generate_ui_derived_assets.gd",
	])
	if not asset_name.is_empty():
		args.append("--asset")
		args.append(asset_name)
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true, false)
	for line in output:
		print(line)
	return exit_code


func _save_template_style(path: String, template_style: StyleBoxTexture) -> Error:
	if path.is_empty() or template_style == null:
		return ERR_INVALID_PARAMETER
	template_style.texture = null
	return ResourceSaver.save(template_style, path)


func _get_margin_value(style: StyleBoxTexture, texture_margin: bool, side: String) -> float:
	if style == null:
		return 0.0
	if texture_margin:
		match side:
			"left":
				return style.texture_margin_left
			"top":
				return style.texture_margin_top
			"right":
				return style.texture_margin_right
			"bottom":
				return style.texture_margin_bottom
	else:
		match side:
			"left":
				return style.content_margin_left
			"top":
				return style.content_margin_top
			"right":
				return style.content_margin_right
			"bottom":
				return style.content_margin_bottom
	return 0.0


func _set_margin_value(style: StyleBoxTexture, texture_margin: bool, side: String, value: float) -> void:
	if style == null:
		return
	if texture_margin:
		match side:
			"left":
				style.texture_margin_left = value
			"top":
				style.texture_margin_top = value
			"right":
				style.texture_margin_right = value
			"bottom":
				style.texture_margin_bottom = value
	else:
		match side:
			"left":
				style.content_margin_left = value
			"top":
				style.content_margin_top = value
			"right":
				style.content_margin_right = value
			"bottom":
				style.content_margin_bottom = value


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _flat_box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box
