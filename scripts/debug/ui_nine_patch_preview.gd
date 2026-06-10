@tool
extends Control

const STYLE_ROOT := "res://assets/ui/styles"
const SCENE_ROOT := "res://scenes"
const DEFAULT_FOCUS_STYLE_PATH := "res://assets/ui/styles/bar_progress_fill_core.tres"
const DEFAULT_TRACK_PATH := "res://assets/ui/styles/bar_progress_track.tres"
const DESIGN_VIEWPORT_SIZE := Vector2(1920.0, 1080.0)
const MAX_SCENE_PREVIEWS_PER_STYLE := 8

const COMBAT_HUD_CORE_TRACK_SIZE := Vector2(130.0, 25.0)
const COMBAT_HUD_CORE_FILL_INSET := 2.0
const COMBAT_HUD_CORE_RATIOS := [0.02, 0.05, 0.10, 0.25, 0.50, 0.75, 1.00]

const UNIT_DETAIL_PROGRESS_TRACK_SIZE := Vector2(210.0, 30.0)
const UNIT_DETAIL_PROGRESS_RATIOS := [0.05, 0.10, 0.25, 0.50, 0.75, 1.00]

@export_file("*.tres") var focus_style_path := DEFAULT_FOCUS_STYLE_PATH:
	set(value):
		focus_style_path = value
		_rebuild_deferred()

@export_file("*.tres") var track_style_path := DEFAULT_TRACK_PATH:
	set(value):
		track_style_path = value
		_rebuild_deferred()

@export var include_unreferenced_styles := true:
	set(value):
		include_unreferenced_styles = value
		_rebuild_deferred()

var _root: MarginContainer
var _body: VBoxContainer


func _ready() -> void:
	_rebuild_deferred()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reload_from_disk()


func _rebuild_deferred() -> void:
	if not is_inside_tree():
		return
	call_deferred("_rebuild")


func _reload_from_disk() -> void:
	for style_path in _find_files(STYLE_ROOT, ".tres"):
		ResourceLoader.load(style_path, "StyleBox", ResourceLoader.CACHE_MODE_REPLACE)
	if ResourceLoader.exists(track_style_path):
		ResourceLoader.load(track_style_path, "StyleBox", ResourceLoader.CACHE_MODE_REPLACE)
	_rebuild()


func _rebuild() -> void:
	_clear_preview()

	var background := ColorRect.new()
	background.name = "_PreviewBackground"
	background.color = Color(0.045, 0.055, 0.072, 1.0)
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
	_body.name = "PreviewList"
	_body.custom_minimum_size = Vector2(1760.0, 0.0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	scroll.add_child(_body)

	var style_paths := _find_files(STYLE_ROOT, ".tres")
	style_paths.sort()
	var scene_paths := _find_files(SCENE_ROOT, ".tscn")
	scene_paths.sort()
	var scan := _scan_scene_style_uses(scene_paths)
	var uses_by_style: Dictionary = scan["uses_by_style"]
	var scene_ref_count := int(scan["scene_ref_count"])

	_body.add_child(_header(style_paths.size(), scene_paths.size(), scene_ref_count))

	if not focus_style_path.is_empty() and style_paths.has(focus_style_path):
		_body.add_child(_section_label("Focused style"))
		_add_style_section(_body, focus_style_path, uses_by_style.get(focus_style_path, []), true)

	_body.add_child(_section_label("All scene-referenced styles"))
	for style_path in style_paths:
		if style_path == focus_style_path:
			continue
		var uses: Array = uses_by_style.get(style_path, [])
		if uses.is_empty():
			continue
		_add_style_section(_body, style_path, uses, false)

	if include_unreferenced_styles:
		_body.add_child(_section_label("Style files without direct .tscn size"))
		for style_path in style_paths:
			if style_path == focus_style_path:
				continue
			var uses: Array = uses_by_style.get(style_path, [])
			if not uses.is_empty():
				continue
			_add_style_section(_body, style_path, [], false)


func _clear_preview() -> void:
	for child in get_children():
		child.free()


func _header(style_count: int, scene_count: int, scene_ref_count: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat_box(Color(0.080, 0.105, 0.135, 0.96), Color(0.250, 0.330, 0.400, 1.0), 1, 6))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	row.add_child(copy)

	copy.add_child(_label("Nine-patch scene-size preview", 22, Color(0.930, 0.965, 1.000, 1.0)))
	copy.add_child(_label("Scans %s and previews every %s StyleBox at estimated scene sizes." % [SCENE_ROOT, STYLE_ROOT], 14, Color(0.690, 0.760, 0.830, 1.0)))
	copy.add_child(_label("%d style files, %d scenes, %d direct scene references. Press R or Reload after editing .tres margins." % [style_count, scene_count, scene_ref_count], 14, Color(0.820, 0.900, 0.940, 1.0)))

	var button := Button.new()
	button.text = "Reload"
	button.custom_minimum_size = Vector2(96, 42)
	button.pressed.connect(_reload_from_disk)
	row.add_child(button)

	return panel


func _section_label(text: String) -> Label:
	var label := _label(text, 18, Color(0.980, 0.780, 0.420, 1.0))
	label.custom_minimum_size = Vector2(0, 28)
	return label


func _hint_label(text: String) -> Label:
	return _label(text, 13, Color(0.620, 0.700, 0.760, 1.0))


func _add_style_section(parent: VBoxContainer, style_path: String, uses: Array, focused: bool) -> void:
	var style := _load_style(style_path)
	var track_style := _load_style(track_style_path)

	var section := PanelContainer.new()
	section.add_theme_stylebox_override("panel", _flat_box(Color(0.068, 0.084, 0.106, 0.94), Color(0.165, 0.225, 0.280, 1.0), 1, 5))
	parent.add_child(section)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	section.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title_color := Color(0.980, 0.930, 0.720, 1.0) if focused else Color(0.900, 0.940, 0.970, 1.0)
	box.add_child(_label("%s  (%d scene refs)" % [style_path.trim_prefix("res://"), uses.size()], 16, title_color))
	box.add_child(_label(_style_summary(style), 13, Color(0.660, 0.740, 0.800, 1.0)))

	_add_specialized_rows(box, style_path, style, track_style)

	var unique_uses := _unique_scene_uses(uses)
	if not unique_uses.is_empty():
		for i in range(mini(unique_uses.size(), MAX_SCENE_PREVIEWS_PER_STYLE)):
			var use: Dictionary = unique_uses[i]
			var size := _sanitize_preview_size(use.get("size", Vector2.ZERO), style)
			var title := "%s  %s  %s  %.0fx%.0f" % [
				String(use.get("scene", "")).trim_prefix("res://"),
				String(use.get("node", "")),
				String(use.get("slot", "")),
				size.x,
				size.y,
			]
			_add_standalone_preview(box, title, style, size)
		if unique_uses.size() > MAX_SCENE_PREVIEWS_PER_STYLE:
			box.add_child(_hint_label("+ %d more scene sizes hidden for this style." % (unique_uses.size() - MAX_SCENE_PREVIEWS_PER_STYLE)))
	else:
		box.add_child(_hint_label("No direct scene reference found. These previews use texture/default sizes so you can still inspect the margins."))
		for size in _fallback_sizes_for_style(style):
			_add_standalone_preview(box, "fallback %.0fx%.0f" % [size.x, size.y], style, size)


func _add_specialized_rows(parent: VBoxContainer, style_path: String, style: StyleBox, track_style: StyleBox) -> void:
	if style_path.ends_with("bar_progress_fill_core.tres"):
		parent.add_child(_hint_label("CombatHud/CoreFill actual script sizes: track 130x25, fill inset 2px, fill height 21px."))
		for ratio in COMBAT_HUD_CORE_RATIOS:
			var fill_size := _combat_core_fill_size(float(ratio))
			var title := "CombatHud/CoreFill %3d%%  fill %.0fx%.0f" % [int(round(float(ratio) * 100.0)), fill_size.x, fill_size.y]
			_add_track_fill_preview(parent, title, style, track_style, COMBAT_HUD_CORE_TRACK_SIZE, Vector2(COMBAT_HUD_CORE_FILL_INSET, COMBAT_HUD_CORE_FILL_INSET), fill_size)
	elif style_path.ends_with("bar_progress_fill_hp.tres") or style_path.ends_with("bar_progress_fill_sp.tres"):
		parent.add_child(_hint_label("UnitDetailPanel progress fill estimate: VitalsColumn width 210px, bar height 30px."))
		for ratio in UNIT_DETAIL_PROGRESS_RATIOS:
			var fill_size := Vector2(UNIT_DETAIL_PROGRESS_TRACK_SIZE.x * float(ratio), UNIT_DETAIL_PROGRESS_TRACK_SIZE.y)
			var title := "UnitDetailPanel %3d%%  fill %.0fx%.0f" % [int(round(float(ratio) * 100.0)), fill_size.x, fill_size.y]
			_add_track_fill_preview(parent, title, style, track_style, UNIT_DETAIL_PROGRESS_TRACK_SIZE, Vector2.ZERO, fill_size)
	elif style_path.ends_with("bar_progress_track.tres"):
		parent.add_child(_hint_label("Progress tracks used by CombatHud and UnitDetailPanel."))
		_add_standalone_preview(parent, "CombatHud/CoreTrack 130x25", style, COMBAT_HUD_CORE_TRACK_SIZE)
		_add_standalone_preview(parent, "UnitDetailPanel/HpTrack, SpTrack 210x30", style, UNIT_DETAIL_PROGRESS_TRACK_SIZE)


func _add_standalone_preview(parent: VBoxContainer, title: String, style: StyleBox, preview_size: Vector2) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	parent.add_child(block)

	block.add_child(_label(title, 12, Color(0.730, 0.805, 0.860, 1.0)))

	var slot := _preview_slot(preview_size)
	var panel := Panel.new()
	panel.custom_minimum_size = preview_size
	panel.size = preview_size
	panel.add_theme_stylebox_override("panel", _duplicate_style(style))
	slot.add_child(panel)
	block.add_child(slot)


func _add_track_fill_preview(parent: VBoxContainer, title: String, fill_style: StyleBox, track_style: StyleBox, track_size: Vector2, fill_position: Vector2, fill_size: Vector2) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	parent.add_child(block)

	block.add_child(_label(title, 12, Color(0.730, 0.805, 0.860, 1.0)))

	var slot := _preview_slot(track_size)

	var track := Panel.new()
	track.custom_minimum_size = track_size
	track.size = track_size
	track.add_theme_stylebox_override("panel", _duplicate_style(track_style))
	slot.add_child(track)

	var fill := Panel.new()
	fill.position = fill_position
	fill.custom_minimum_size = fill_size
	fill.size = fill_size
	fill.add_theme_stylebox_override("panel", _duplicate_style(fill_style))
	slot.add_child(fill)

	block.add_child(slot)


func _preview_slot(preview_size: Vector2) -> Control:
	var size := Vector2(maxf(1.0, preview_size.x), maxf(1.0, preview_size.y))
	var slot := Control.new()
	slot.custom_minimum_size = size
	slot.size = size
	slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.020, 0.026, 0.034, 1.0)
	backdrop.size = size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(backdrop)

	return slot


func _scan_scene_style_uses(scene_paths: Array) -> Dictionary:
	var uses_by_style: Dictionary = {}
	var scene_ref_count := 0
	for scene_path in scene_paths:
		var scene_scan := _scan_single_scene(scene_path)
		var uses: Array = scene_scan["uses"]
		scene_ref_count += uses.size()
		for use in uses:
			var style_path := String(use.get("style_path", ""))
			if style_path.is_empty():
				continue
			if not uses_by_style.has(style_path):
				uses_by_style[style_path] = []
			uses_by_style[style_path].append(use)
	return {
		"uses_by_style": uses_by_style,
		"scene_ref_count": scene_ref_count,
	}


func _scan_single_scene(scene_path: String) -> Dictionary:
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return {"uses": []}

	var ext_resources: Dictionary = {}
	var nodes: Dictionary = {}
	var children_by_parent: Dictionary = {}
	var current := {}
	var lines := file.get_as_text().split("\n")
	for raw_line in lines:
		var line := String(raw_line).strip_edges()
		if line.begins_with("[ext_resource"):
			var path := _attribute(line, "path")
			var id := _attribute(line, "id")
			if path.begins_with(STYLE_ROOT) and path.ends_with(".tres"):
				ext_resources[id] = path
		elif line.begins_with("[node"):
			_store_scene_node(current, nodes, children_by_parent)
			current = {
				"name": _attribute(line, "name"),
				"type": _attribute(line, "type"),
				"parent": _attribute(line, "parent"),
				"props": {},
				"style_refs": [],
			}
		elif line.begins_with("["):
			_store_scene_node(current, nodes, children_by_parent)
			current = {}
		elif not current.is_empty() and line.find("=") >= 0:
			var eq := line.find("=")
			var key := line.substr(0, eq).strip_edges()
			var value := line.substr(eq + 1).strip_edges()
			current["props"][key] = value
			if key.begins_with("theme_override_styles/"):
				var id := _extract_ext_resource_id(value)
				if ext_resources.has(id):
					current["style_refs"].append({
						"slot": key.trim_prefix("theme_override_styles/"),
						"style_path": ext_resources[id],
					})
	_store_scene_node(current, nodes, children_by_parent)

	var cache: Dictionary = {}
	var uses: Array = []
	for node_path in nodes.keys():
		var node: Dictionary = nodes[node_path]
		var refs: Array = node.get("style_refs", [])
		if refs.is_empty():
			continue
		var size := _estimate_node_size(node_path, nodes, children_by_parent, cache)
		for ref in refs:
			uses.append({
				"style_path": ref["style_path"],
				"scene": scene_path,
				"node": node_path,
				"slot": ref["slot"],
				"size": size,
			})
	return {"uses": uses}


func _store_scene_node(node: Dictionary, nodes: Dictionary, children_by_parent: Dictionary) -> void:
	if node.is_empty():
		return
	var name := String(node.get("name", ""))
	var parent := String(node.get("parent", ""))
	var full_path := "."
	if parent.is_empty():
		full_path = "."
	elif parent == ".":
		full_path = name
	else:
		full_path = "%s/%s" % [parent, name]
	node["path"] = full_path
	nodes[full_path] = node
	if parent.is_empty():
		return
	var parent_key := "." if parent == "." else parent
	if not children_by_parent.has(parent_key):
		children_by_parent[parent_key] = []
	children_by_parent[parent_key].append(full_path)


func _estimate_node_size(node_path: String, nodes: Dictionary, children_by_parent: Dictionary, cache: Dictionary) -> Vector2:
	if cache.has(node_path):
		return cache[node_path]
	if not nodes.has(node_path):
		return Vector2.ZERO

	var node: Dictionary = nodes[node_path]
	var props: Dictionary = node.get("props", {})
	var parent_path := String(node.get("parent", ""))
	if parent_path == ".":
		parent_path = "."

	var parent_size := DESIGN_VIEWPORT_SIZE
	if not parent_path.is_empty() and nodes.has(parent_path):
		parent_size = _estimate_node_size(parent_path, nodes, children_by_parent, cache)

	var custom_min := _vector2_prop(props, "custom_minimum_size")
	var anchor_left := _float_prop(props, "anchor_left", 0.0)
	var anchor_top := _float_prop(props, "anchor_top", 0.0)
	var anchor_right := _float_prop(props, "anchor_right", 0.0)
	var anchor_bottom := _float_prop(props, "anchor_bottom", 0.0)
	var offset_left := _float_prop(props, "offset_left", 0.0)
	var offset_top := _float_prop(props, "offset_top", 0.0)
	var offset_right := _float_prop(props, "offset_right", 0.0)
	var offset_bottom := _float_prop(props, "offset_bottom", 0.0)

	var size := Vector2.ZERO
	size.x = (anchor_right - anchor_left) * parent_size.x + offset_right - offset_left
	size.y = (anchor_bottom - anchor_top) * parent_size.y + offset_bottom - offset_top
	size = _size_from_parent_container(node_path, size, custom_min, nodes, children_by_parent, cache)
	size.x = maxf(size.x, custom_min.x)
	size.y = maxf(size.y, custom_min.y)

	if node_path == "." and size == Vector2.ZERO:
		size = DESIGN_VIEWPORT_SIZE

	cache[node_path] = Vector2(maxf(0.0, size.x), maxf(0.0, size.y))
	return cache[node_path]


func _size_from_parent_container(node_path: String, size: Vector2, custom_min: Vector2, nodes: Dictionary, children_by_parent: Dictionary, cache: Dictionary) -> Vector2:
	if not nodes.has(node_path):
		return size
	var node: Dictionary = nodes[node_path]
	var raw_parent := String(node.get("parent", ""))
	var parent_path := "." if raw_parent == "." else raw_parent
	if parent_path.is_empty() or not nodes.has(parent_path):
		return size

	var parent_node: Dictionary = nodes[parent_path]
	var parent_type := String(parent_node.get("type", ""))
	var parent_size := _estimate_node_size(parent_path, nodes, children_by_parent, cache)
	var parent_props: Dictionary = parent_node.get("props", {})

	if parent_type == "MarginContainer":
		var inner := parent_size - Vector2(
			_float_prop(parent_props, "theme_override_constants/margin_left", 0.0) + _float_prop(parent_props, "theme_override_constants/margin_right", 0.0),
			_float_prop(parent_props, "theme_override_constants/margin_top", 0.0) + _float_prop(parent_props, "theme_override_constants/margin_bottom", 0.0)
		)
		if size.x <= 0.0:
			size.x = maxf(0.0, inner.x)
		if size.y <= 0.0:
			size.y = maxf(0.0, inner.y)
	elif parent_type == "HBoxContainer":
		if size.y <= 0.0:
			size.y = parent_size.y
		if size.x <= 0.0:
			size.x = _container_child_width(node_path, parent_path, nodes, children_by_parent, parent_size.x, custom_min.x)
	elif parent_type == "VBoxContainer":
		if size.x <= 0.0:
			size.x = parent_size.x
		if size.y <= 0.0:
			size.y = custom_min.y
	elif parent_type == "CenterContainer":
		if size.x <= 0.0:
			size.x = custom_min.x
		if size.y <= 0.0:
			size.y = custom_min.y

	return size


func _container_child_width(node_path: String, parent_path: String, nodes: Dictionary, children_by_parent: Dictionary, parent_width: float, fallback_width: float) -> float:
	var children: Array = children_by_parent.get(parent_path, [])
	if children.is_empty():
		return fallback_width

	var parent_props: Dictionary = nodes[parent_path].get("props", {})
	var separation := _float_prop(parent_props, "theme_override_constants/separation", 0.0)
	var fixed_width := 0.0
	var expand_count := 0
	for child_path in children:
		var child: Dictionary = nodes[child_path]
		var child_props: Dictionary = child.get("props", {})
		var child_min := _vector2_prop(child_props, "custom_minimum_size")
		var expands := int(_float_prop(child_props, "size_flags_horizontal", 0.0)) == 3
		if expands:
			expand_count += 1
		else:
			fixed_width += child_min.x

	var available := parent_width - fixed_width - maxf(0.0, float(children.size() - 1)) * separation
	var current_props: Dictionary = nodes[node_path].get("props", {})
	var current_expands := int(_float_prop(current_props, "size_flags_horizontal", 0.0)) == 3
	if current_expands and expand_count > 0:
		return maxf(fallback_width, available / float(expand_count))
	return fallback_width


func _unique_scene_uses(uses: Array) -> Array:
	var seen: Dictionary = {}
	var unique: Array = []
	for use in uses:
		var raw_size: Vector2 = use.get("size", Vector2.ZERO)
		var key := "%s|%s|%d|%d" % [
			String(use.get("scene", "")),
			String(use.get("node", "")),
			int(round(raw_size.x)),
			int(round(raw_size.y)),
		]
		if seen.has(key):
			continue
		seen[key] = true
		unique.append(use)
	unique.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var asize: Vector2 = a.get("size", Vector2.ZERO)
		var bsize: Vector2 = b.get("size", Vector2.ZERO)
		var a_area := asize.x * asize.y
		var b_area := bsize.x * bsize.y
		if is_equal_approx(a_area, b_area):
			return String(a.get("node", "")) < String(b.get("node", ""))
		return a_area < b_area
	)
	return unique


func _find_files(root_path: String, extension: String) -> Array:
	var found: Array = []
	_find_files_recursive(root_path, extension, found)
	found.sort()
	return found


func _find_files_recursive(path: String, extension: String, found: Array) -> void:
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
			_find_files_recursive(full_path, extension, found)
		elif entry.ends_with(extension):
			found.append(full_path)
	dir.list_dir_end()


func _attribute(line: String, attribute_name: String) -> String:
	var needle := "%s=\"" % attribute_name
	var start := line.find(needle)
	if start < 0:
		return ""
	start += needle.length()
	var end := line.find("\"", start)
	if end < 0:
		return ""
	return line.substr(start, end - start)


func _extract_ext_resource_id(value: String) -> String:
	var needle := "ExtResource(\""
	var start := value.find(needle)
	if start < 0:
		return ""
	start += needle.length()
	var end := value.find("\"", start)
	if end < 0:
		return ""
	return value.substr(start, end - start)


func _vector2_prop(props: Dictionary, key: String) -> Vector2:
	if not props.has(key):
		return Vector2.ZERO
	var value := String(props[key])
	var start := value.find("(")
	var end := value.find(")", start)
	if start < 0 or end < 0:
		return Vector2.ZERO
	var parts := value.substr(start + 1, end - start - 1).split(",")
	if parts.size() < 2:
		return Vector2.ZERO
	return Vector2(String(parts[0]).strip_edges().to_float(), String(parts[1]).strip_edges().to_float())


func _float_prop(props: Dictionary, key: String, default_value: float) -> float:
	if not props.has(key):
		return default_value
	return String(props[key]).to_float()


func _combat_core_fill_size(ratio: float) -> Vector2:
	var fill_width := maxf(0.0, (COMBAT_HUD_CORE_TRACK_SIZE.x - COMBAT_HUD_CORE_FILL_INSET * 2.0) * ratio)
	var fill_height := maxf(0.0, COMBAT_HUD_CORE_TRACK_SIZE.y - COMBAT_HUD_CORE_FILL_INSET * 2.0)
	return Vector2(fill_width, fill_height)


func _fallback_sizes_for_style(style: StyleBox) -> Array:
	var sizes: Array = []
	if style is StyleBoxTexture:
		var texture_style := style as StyleBoxTexture
		var min_width := maxf(32.0, texture_style.texture_margin_left + texture_style.texture_margin_right + 24.0)
		var min_height := maxf(24.0, texture_style.texture_margin_top + texture_style.texture_margin_bottom + 14.0)
		sizes.append(Vector2(min_width, min_height))
		if texture_style.texture != null:
			sizes.append(texture_style.texture.get_size())
		sizes.append(Vector2(maxf(96.0, min_width), maxf(40.0, min_height)))
		sizes.append(Vector2(maxf(180.0, min_width), maxf(64.0, min_height)))
	else:
		sizes.append(Vector2(120.0, 48.0))
	return sizes


func _sanitize_preview_size(size: Vector2, style: StyleBox) -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return Vector2(maxf(1.0, round(size.x)), maxf(1.0, round(size.y)))
	var fallback: Array = _fallback_sizes_for_style(style)
	if fallback.is_empty():
		return Vector2(80.0, 32.0)
	return fallback[0]


func _load_style(path: String) -> StyleBox:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "StyleBox", ResourceLoader.CACHE_MODE_REUSE) as StyleBox


func _style_summary(style: StyleBox) -> String:
	if style == null:
		return "StyleBox missing or failed to load"
	if style is StyleBoxTexture:
		var texture_style := style as StyleBoxTexture
		var texture_size := Vector2.ZERO
		if texture_style.texture != null:
			texture_size = texture_style.texture.get_size()
		return "StyleBoxTexture texture %.0fx%.0f, texture margin L %.1f  T %.1f  R %.1f  B %.1f" % [
			texture_size.x,
			texture_size.y,
			texture_style.texture_margin_left,
			texture_style.texture_margin_top,
			texture_style.texture_margin_right,
			texture_style.texture_margin_bottom,
		]
	return "Loaded %s" % style.get_class()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _duplicate_style(style: StyleBox) -> StyleBox:
	if style == null:
		return _flat_box(Color(0.300, 0.080, 0.080, 1.0), Color(1.000, 0.350, 0.250, 1.0), 1, 4)
	return style.duplicate(true) as StyleBox


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
