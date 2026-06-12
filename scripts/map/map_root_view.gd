extends Node2D

const AppRefs = preload("res://scripts/common/app_refs.gd")

const CELL_SIZE := 64.0
const TILE_PLAIN: Texture2D = preload("res://assets/map/CommandMap/tile_plain.png")
const TILE_PLAIN_ALT: Texture2D = preload("res://assets/map/CommandMap/tile_plain_alt.png")
const TILE_HIDDEN: Texture2D = preload("res://assets/map/CommandMap/tile_hidden.png")
const TILE_MOUNTAIN: Texture2D = preload("res://assets/map/CommandMap/tile_mountain.png")
const TILE_WATER: Texture2D = preload("res://assets/map/CommandMap/tile_water.png")
const TILE_HIGHLAND: Texture2D = preload("res://assets/map/CommandMap/tile_highland.png")
const TILE_FORD: Texture2D = preload("res://assets/map/CommandMap/tile_ford.png")
const TILE_SPAWN: Texture2D = preload("res://assets/map/CommandMap/tile_spawn.png")
const TILE_RESOURCE_WOOD: Texture2D = preload("res://assets/map/CommandMap/tile_resource_wood.png")
const TILE_RESOURCE_STONE: Texture2D = preload("res://assets/map/CommandMap/tile_resource_stone.png")
const TILE_RESOURCE_MANA: Texture2D = preload("res://assets/map/CommandMap/tile_resource_mana.png")
const OVERLAY_MAP_HOVER: Texture2D = preload("res://assets/map/CommandMap/overlay_map_hover.png")
const OVERLAY_MAP_SELECTED: Texture2D = preload("res://assets/map/CommandMap/overlay_map_selected.png")
const OVERLAY_ATTACK_RANGE: Texture2D = preload("res://assets/map/CommandMap/overlay_attack_range.png")
const OVERLAY_BUILDING_RANGE: Texture2D = preload("res://assets/map/CommandMap/overlay_building_range.png")
const OVERLAY_DEPLOY_VALID: Texture2D = preload("res://assets/map/CommandMap/overlay_deploy_valid.png")
const OVERLAY_DEPLOY_INVALID: Texture2D = preload("res://assets/map/CommandMap/overlay_deploy_invalid.png")
const RANGE_EDGE_BASE: Texture2D = preload("res://assets/effects/range/range_outline_edge_base.png")
const RANGE_NODE_GLOW: Texture2D = preload("res://assets/effects/range/range_outline_node_glow_strip.png")
const RANGE_SKILL_EDGE: Texture2D = preload("res://assets/effects/range/skill_range_warning_edge_pulse_strip.png")
const RANGE_AOE_WARNING_EDGE: Texture2D = preload("res://assets/effects/range/aoe_warning_edge_pulse_strip.png")
const RANGE_FIELD_NODE: Texture2D = preload("res://assets/effects/range/field_boundary_node_pulse_strip.png")
const RANGE_GRAVITY_EDGE: Texture2D = preload("res://assets/effects/range/gravity_field_edge_pulse_strip.png")
const RANGE_BUILDING_EDGE: Texture2D = preload("res://assets/effects/range/building_aura_edge_pulse_strip.png")
const GRID_COLOR := Color(0.02, 0.045, 0.065, 0.36)
const HOVER_COLOR := Color(1.0, 0.9, 0.35, 0.35)
const FOG_EXPLORE_HOVER_COLOR := Color(0.55, 1.0, 0.70, 0.55)
const SELECT_COLOR := Color(0.35, 0.8, 1.0, 0.4)
const ATTACK_RANGE_FILL := Color(0.20, 0.55, 0.95, 0.28)
const ATTACK_RANGE_BORDER := Color(0.30, 0.85, 1.0, 0.95)
const BUILDING_RANGE_FILL := Color(0.28, 0.90, 0.42, 0.22)
const BUILDING_RANGE_BORDER := Color(0.46, 1.0, 0.58, 0.86)
const RANGE_OUTLINE_DEFAULT_COLOR := Color(0.55, 0.92, 1.0, 0.86)
const RANGE_OUTLINE_WARNING_COLOR := Color(1.0, 0.58, 0.22, 0.92)
const RANGE_OUTLINE_SHU_COLOR := Color(0.72, 0.96, 0.50, 0.88)
const RANGE_OUTLINE_SARIA_COLOR := Color(1.0, 0.82, 0.52, 0.90)
const DEPLOY_VALID_FILL := Color(0.18, 0.85, 0.65, 0.38)
const DEPLOY_VALID_BORDER := Color(0.38, 1.0, 0.82, 0.95)
const DEPLOY_INVALID_FILL := Color(1.0, 0.12, 0.10, 0.36)
const DEPLOY_INVALID_BORDER := Color(1.0, 0.32, 0.26, 0.95)
const DEPLOY_LOCKED_FILL := Color(1.0, 0.68, 0.18, 0.32)
const DEPLOY_LOCKED_BORDER := Color(1.0, 0.84, 0.32, 0.95)
const DEPLOY_RANGE_FILL := Color(0.95, 0.65, 0.18, 0.20)
const DEPLOY_RANGE_BORDER := Color(1.0, 0.78, 0.26, 0.82)
const UNIT_VISUAL_TEXTURE_ROOT := "res://assets/sprites/units"
const UNIT_VISUAL_IDLE_ANIM := "idle"
const UNIT_VISUAL_TEXTURE_SIZE := 128.0
const UNIT_VISUAL_DISPLAY_SIZE := 72.0
const UNIT_VISUAL_OFFSET := Vector2(0.0, -8.0)
const UNIT_PREVIEW_MODULATE := Color(1.0, 1.0, 1.0, 0.78)
const ROUTE_PREVIEW_COLORS: Array[Color] = [
	Color(1.0, 0.54, 0.20, 0.95),
	Color(0.20, 0.78, 1.0, 0.95),
	Color(0.86, 0.62, 1.0, 0.95),
	Color(0.38, 0.95, 0.58, 0.95),
	Color(1.0, 0.84, 0.24, 0.95)
]
const ROUTE_WARNING_COLOR := Color(1.0, 0.22, 0.20, 0.96)
const ROUTE_DEMOLISHER_COLOR := Color(1.0, 0.88, 0.34, 0.96)
const ROUTE_FLYING_COLOR := Color(0.36, 0.90, 1.0, 0.92)
const ROUTE_LABEL_DISTANCE_FROM_CORE_TILES := 2
const ROUTE_LABEL_BADGE_BG := Color(0.015, 0.032, 0.048, 0.90)
const ROUTE_LABEL_BADGE_RADIUS := 13.0
const ROUTE_LABEL_GROUP_OFFSET_STEP := 30.0
const ROUTE_LABEL_GROUP_BACK_OFFSET := 7.0
const EVENT_BUBBLE_FILL := Color(0.075, 0.165, 0.205, 0.96)
const EVENT_BUBBLE_BORDER := Color(0.970, 0.680, 0.245, 0.96)
const EVENT_BUBBLE_HOVER_FILL := Color(0.110, 0.235, 0.280, 0.98)
const EVENT_BUBBLE_HOVER_BORDER := Color(1.000, 0.845, 0.360, 1.0)
const EVENT_BUBBLE_TEXT := Color(0.945, 0.980, 1.000, 1.0)
const EVENT_BUBBLE_RADIUS := 18.0
const EVENT_BUBBLE_HIT_RADIUS := 25.0
const EVENT_BUBBLE_FLOAT_OFFSET := Vector2(0.0, -25.0)
const COLOR_HIDDEN := Color(0.10, 0.12, 0.16, 0.95)
const COLOR_PLAIN := Color(0.25, 0.44, 0.26, 1.0)
const COLOR_BLOCKED := Color(0.33, 0.34, 0.38, 1.0)
const COLOR_WATER := Color(0.08, 0.35, 0.42, 1.0)
const COLOR_CORE := Color(0.25, 0.60, 0.95, 1.0)
const COLOR_SPAWN := Color(0.82, 0.30, 0.26, 1.0)
const COLOR_RESOURCE_WOOD := Color(0.45, 0.31, 0.18, 1.0)
const COLOR_RESOURCE_STONE := Color(0.56, 0.59, 0.64, 1.0)
const COLOR_RESOURCE_MANA := Color(0.16, 0.62, 0.72, 1.0)
const COLOR_HIGHLAND := Color(0.62, 0.54, 0.38)
# 合成层：水陆岸线（画在水格内侧，赛璐璐两阶：浅水带 + 泡沫线）。
const SHORE_SHALLOW_COLOR := Color(0.62, 0.88, 0.92, 0.22)
const SHORE_FOAM_COLOR := Color(0.93, 0.98, 0.98, 0.45)
const SHORE_FOAM_WIDTH := 2.0
const SHORE_SHALLOW_WIDTH := 6.0
# 合成层：昼夜全局调色（资产画白天标准光，夜晚由 CanvasModulate 压冷）。
const NIGHT_CANVAS_TINT := Color(0.64, 0.68, 0.9)
const DAY_NIGHT_FADE_SECONDS := 1.2
# 合成层：地形特征外投影（左上暖光 → 山/高台向下/右邻格投冷色短影）。
const FEATURE_SHADOW_COLOR := Color(0.10, 0.10, 0.24, 0.16)
const FEATURE_SHADOW_WIDTH := 7.0
# 合成层：迷雾边缘羽化（已探索格沿雾邻边的雾色渐变带）。
const FOG_EDGE_COLOR := Color(0.13, 0.14, 0.20)
const FOG_EDGE_ALPHAS: Array[float] = [0.4, 0.22, 0.1]
const FOG_EDGE_STEP_WIDTH := 4.0
# 合成层：夜晚发光体（核心/魔力晶簇挂 PointLight2D，抵抗夜色压暗）。
const NIGHT_GLOW_CORE_COLOR := Color(0.66, 0.52, 1.0)
const NIGHT_GLOW_MANA_COLOR := Color(0.42, 0.76, 1.0)
const NIGHT_GLOW_CORE_ENERGY := 0.6
const NIGHT_GLOW_MANA_ENERGY := 0.42
const NIGHT_GLOW_CORE_SCALE := 0.8
const NIGHT_GLOW_MANA_SCALE := 0.55
# 合成层：平地微贴花与水面微光（按格哈希确定性撒布）。
const DECAL_STONE_LIGHT := Color(0.63, 0.61, 0.54)
const DECAL_STONE_DARK := Color(0.45, 0.44, 0.41)
const DECAL_FLOWER_PETAL := Color(0.96, 0.95, 0.88)
const DECAL_FLOWER_GOLD := Color(0.88, 0.76, 0.4)
const DECAL_GRASS := Color(0.32, 0.42, 0.2)
const SPARKLE_COLOR := Color(0.93, 1.0, 1.0)
const SPARKLE_REDRAW_HZ := 3.0
const VIEW_PADDING := 0.0
const MAX_ZOOM_MULTIPLIER := 3.0
const ZOOM_STEP := 0.9
const PAN_OVERSCROLL_VIEWPORT_RATIO := 0.75
const RANGE_TEXTURE_FRAME_COUNT := 6
const RANGE_TEXTURE_FPS := 7.0
const RANGE_EDGE_TEXTURE_SIZE := Vector2(72.0, 26.0)
const RANGE_NODE_TEXTURE_SIZE := Vector2(30.0, 30.0)
const RANGE_CORNER_TEXTURE_SIZE := Vector2(42.0, 42.0)

var _map_manager: Node
var _building_manager: Node
var _random_event_manager: Node
var _hovered_cell := Vector2i(-1, -1)
var _fog_hover_active := false
var _selected_cell := Vector2i(-1, -1)
var _left_press_pos := Vector2.ZERO
var _left_press_tracking := false
var _right_press_pos := Vector2.ZERO
var _right_press_time_ms := 0
var _right_press_tracking := false

const MAP_DRAG_START_DISTANCE := 5.0
const PINCH_MIN_DISTANCE := 12.0
const RIGHT_TAP_MAX_DISTANCE := 5.0
const RIGHT_TAP_MAX_DURATION_MS := 300
var _camera: Camera2D
var _fit_zoom := 1.0
var _zoom_scalar := 1.0
var _camera_fit_initialized := false
var _last_map_size := Vector2.ZERO
var _is_dragging := false
var _drag_button_index := 0
var _active_touches: Dictionary = {}
var _pinch_active := false
var _pinch_touch_a := -1
var _pinch_touch_b := -1
var _suppress_emulated_mouse_until_touches_released := false
var _debug_attack_range_cells: Array[Vector2i] = []
var _building_effect_range_cells: Array[Vector2i] = []
var _range_outline_effects: Dictionary = {}
var _range_outline_time := 0.0
var _deploy_preview_cell := Vector2i(-1, -1)
var _deploy_preview_valid := false
var _deploy_locked_cell := Vector2i(-1, -1)
var _deploy_preview_facing := Vector2i.ZERO
var _deploy_range_preview_cells: Array[Vector2i] = []
var _deploy_preview_visual_key := ""
var _deploy_preview_texture: Texture2D = null
var _wave_route_previews: Array[Dictionary] = []
var _hovered_event_cell := Vector2i(-1, -1)


var _day_night_tint: CanvasModulate
var _sparkle_bucket := -1
var _night_glow_root: Node2D
var _glow_texture: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_camera = get_node_or_null("MapCamera") as Camera2D
	if _camera == null:
		_camera = Camera2D.new()
		_camera.name = "MapCamera"
		_camera.position_smoothing_enabled = false
		_camera.enabled = true
		add_child(_camera)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	call_deferred("_fit_camera_to_map")
	_day_night_tint = CanvasModulate.new()
	_day_night_tint.name = "DayNightTint"
	_day_night_tint.color = Color.WHITE
	add_child(_day_night_tint)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.day_started.connect(_on_day_started_tint)
		event_bus.night_started.connect(_on_night_started_tint)


func _process(delta: float) -> void:
	_range_outline_time += delta
	_tick_range_outline_effects(delta)
	var sparkle_bucket := int(_range_outline_time * SPARKLE_REDRAW_HZ)
	if sparkle_bucket != _sparkle_bucket:
		_sparkle_bucket = sparkle_bucket
		queue_redraw()
	var map_manager := _get_map_manager()
	if map_manager == null:
		return
	if _has_visible_event_bubbles(map_manager):
		queue_redraw()
	var hovered: Vector2i = map_manager.world_to_cell(get_global_mouse_position())
	var hovered_event := _get_event_bubble_cell_at_world(get_global_mouse_position(), map_manager)
	if hovered_event != _hovered_event_cell:
		_hovered_event_cell = hovered_event
		queue_redraw()
	if map_manager.is_inside(hovered) and hovered != _hovered_cell:
		_hovered_cell = hovered
		queue_redraw()
		var event_bus = AppRefs.event_bus()
		if event_bus != null:
			event_bus.map_cell_hovered.emit(hovered)
	elif not map_manager.is_inside(hovered) and _hovered_cell != Vector2i(-1, -1):
		_hovered_cell = Vector2i(-1, -1)
		_fog_hover_active = false
		queue_redraw()
		var event_bus = AppRefs.event_bus()
		if event_bus != null:
			event_bus.map_cell_hovered.emit(Vector2i(-1, -1))


func _unhandled_input(event: InputEvent) -> void:
	var map_manager := _get_map_manager()
	if map_manager == null or _camera == null:
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMagnifyGesture:
		_handle_magnify_gesture(event)
	elif event is InputEventMouseButton:
		if _suppress_emulated_mouse_until_touches_released:
			return
		_handle_mouse_button(event, map_manager)
	elif event is InputEventMouseMotion:
		if _suppress_emulated_mouse_until_touches_released:
			return
		_handle_mouse_motion(event)


func refresh_from_map(map_manager: Node, reset_camera: bool = false) -> void:
	_map_manager = map_manager
	var map_size := _get_map_size(map_manager)
	var map_size_changed := not map_size.is_equal_approx(_last_map_size)
	_last_map_size = map_size
	_fit_camera_to_map(reset_camera or map_size_changed or not _camera_fit_initialized)
	queue_redraw()


func _draw() -> void:
	var map_manager := _get_map_manager()
	if map_manager == null:
		return
	for y in range(map_manager.height):
		for x in range(map_manager.width):
			var cell := Vector2i(x, y)
			var data = map_manager.get_cell_data(cell)
			if data == null:
				continue
			var rect := Rect2(Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			_draw_cell_tile(rect, data)
			if data.discovered:
				if data.terrain == CellData.TERRAIN_WATER:
					_draw_shore_bands(rect, cell, map_manager)
					_draw_water_sparkles(rect, cell)
				else:
					_draw_feature_cast_shadow(rect, cell, map_manager, data)
				if _is_quiet_plain(data):
					_draw_plain_decals(rect, cell)
				_draw_fog_feather(rect, cell, map_manager)
			draw_rect(rect, GRID_COLOR, false, 1.0)
			if _deploy_range_preview_cells.has(cell):
				_draw_deploy_range_cell(rect)
			if _debug_attack_range_cells.has(cell):
				_draw_attack_range_cell(rect)
			if _building_effect_range_cells.has(cell):
				_draw_building_range_cell(rect)
			if cell == _deploy_preview_cell:
				_draw_deploy_preview_cell(rect, _deploy_preview_valid)
			if cell == _deploy_locked_cell:
				_draw_deploy_locked_cell(rect)
			if cell == _hovered_cell:
				var hover_tint := FOG_EXPLORE_HOVER_COLOR if _fog_hover_active else HOVER_COLOR
				_draw_cell_overlay(OVERLAY_MAP_HOVER, rect, hover_tint, Color.TRANSPARENT, 2.0, 0.0)
			if cell == _selected_cell:
				_draw_cell_overlay(OVERLAY_MAP_SELECTED, rect, SELECT_COLOR, Color.TRANSPARENT, 6.0, 0.0)
	_draw_range_outlines(map_manager)
	_draw_wave_route_previews(map_manager)
	_draw_deploy_visual_preview(map_manager)
	_draw_event_bubbles(map_manager)
	if _deploy_locked_cell.x >= 0 and _deploy_preview_facing != Vector2i.ZERO:
		_draw_deploy_direction_arrow(map_manager)


func set_debug_attack_range(cells: Array[Vector2i]) -> void:
	_debug_attack_range_cells = cells.duplicate()
	queue_redraw()


func clear_debug_attack_range() -> void:
	_debug_attack_range_cells.clear()
	queue_redraw()


func set_building_effect_range(cells: Array[Vector2i]) -> void:
	_building_effect_range_cells = cells.duplicate()
	queue_redraw()


func clear_building_effect_range() -> void:
	_building_effect_range_cells.clear()
	queue_redraw()


func set_range_outline(effect_id: StringName, cells: Array[Vector2i], options: Dictionary = {}) -> void:
	if effect_id == StringName():
		return
	var outline_cells := _dedupe_range_outline_cells(cells)
	if outline_cells.is_empty():
		clear_range_outline(effect_id)
		return
	var duration := float(options.get("duration", -1.0))
	var data := {
		"cells": outline_cells,
		"style": StringName(options.get("style", &"skill")),
		"owner_runtime_id": int(options.get("owner_runtime_id", -1)),
		"duration": duration,
		"remaining": duration,
		"width": float(options.get("width", 2.5)),
		"halo_width": float(options.get("halo_width", 7.0)),
		"pulse_amount": float(options.get("pulse_amount", 0.22)),
		"pulse_speed": float(options.get("pulse_speed", 3.0)),
		"draw_nodes": bool(options.get("draw_nodes", false)),
		"node_radius": float(options.get("node_radius", 2.5)),
		"use_texture": bool(options.get("use_texture", true))
	}
	if options.has("color"):
		data["color"] = options["color"]
	_range_outline_effects[effect_id] = data
	queue_redraw()


func clear_range_outline(effect_id: StringName) -> void:
	if _range_outline_effects.erase(effect_id):
		queue_redraw()


func clear_range_outlines_for_owner(owner_runtime_id: int) -> void:
	var changed := false
	for effect_id in _range_outline_effects.keys().duplicate():
		var data: Dictionary = _range_outline_effects[effect_id]
		if int(data.get("owner_runtime_id", -1)) == owner_runtime_id:
			_range_outline_effects.erase(effect_id)
			changed = true
	if changed:
		queue_redraw()


func set_fog_hover_active(active: bool) -> void:
	if _fog_hover_active == active:
		return
	_fog_hover_active = active
	queue_redraw()


func set_deploy_preview(cell: Vector2i, is_valid: bool, range_cells: Array[Vector2i] = [], visual_key: String = "") -> void:
	_deploy_preview_cell = cell
	_deploy_preview_valid = is_valid
	_deploy_locked_cell = Vector2i(-1, -1)
	_deploy_preview_facing = Vector2i.ZERO
	_deploy_range_preview_cells = range_cells.duplicate()
	_set_deploy_preview_visual(visual_key if is_valid else "")
	queue_redraw()


func set_deploy_direction_preview(cell: Vector2i, facing: Vector2i, range_cells: Array[Vector2i] = [], visual_key: String = "") -> void:
	_deploy_preview_cell = Vector2i(-1, -1)
	_deploy_locked_cell = cell
	_deploy_preview_facing = _normalize_direction(facing)
	_deploy_range_preview_cells = range_cells.duplicate()
	_set_deploy_preview_visual(visual_key)
	queue_redraw()


func clear_deploy_preview() -> void:
	_deploy_preview_cell = Vector2i(-1, -1)
	_deploy_preview_valid = false
	_deploy_locked_cell = Vector2i(-1, -1)
	_deploy_preview_facing = Vector2i.ZERO
	_deploy_range_preview_cells.clear()
	_set_deploy_preview_visual("")
	queue_redraw()


func set_wave_route_previews(routes: Array[Dictionary]) -> void:
	_wave_route_previews.clear()
	for route: Dictionary in routes:
		_wave_route_previews.append(route.duplicate(true))
	queue_redraw()


func clear_wave_route_previews() -> void:
	_wave_route_previews.clear()
	queue_redraw()


func _tick_range_outline_effects(delta: float) -> void:
	if _range_outline_effects.is_empty():
		return
	for effect_id in _range_outline_effects.keys().duplicate():
		var data: Dictionary = _range_outline_effects[effect_id]
		var remaining := float(data.get("remaining", -1.0))
		if remaining <= 0.0:
			continue
		remaining -= delta
		if remaining <= 0.0:
			_range_outline_effects.erase(effect_id)
		else:
			data["remaining"] = remaining
			_range_outline_effects[effect_id] = data
	queue_redraw()


func _draw_range_outlines(map_manager: Node) -> void:
	if _range_outline_effects.is_empty():
		return
	for effect_id in _range_outline_effects.keys():
		var data: Dictionary = _range_outline_effects[effect_id]
		var cells: Array = data.get("cells", [])
		_draw_range_outline_cells(map_manager, cells, data)


func _draw_range_outline_cells(map_manager: Node, cells: Array, data: Dictionary) -> void:
	var lookup: Dictionary = {}
	for raw_cell: Variant in cells:
		if not (raw_cell is Vector2i):
			continue
		var cell: Vector2i = raw_cell
		if map_manager != null and map_manager.has_method("is_inside") and not map_manager.is_inside(cell):
			continue
		lookup[cell] = true
	if lookup.is_empty():
		return
	var core_color: Color = _range_outline_color(data)
	var pulse_amount: float = clampf(float(data.get("pulse_amount", 0.22)), 0.0, 0.75)
	var pulse_speed: float = maxf(float(data.get("pulse_speed", 3.0)), 0.01)
	var pulse: float = 0.5 + sin(_range_outline_time * pulse_speed) * 0.5
	core_color.a *= 1.0 - pulse_amount + pulse * pulse_amount
	var texture_modulate := _range_outline_texture_modulate(data, core_color)
	var halo_color := Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.24)
	var width: float = maxf(float(data.get("width", 2.5)), 1.0)
	var halo_width: float = maxf(float(data.get("halo_width", width + 4.0)), width)
	var style_data := _range_outline_style_data(data)
	var edge_texture: Texture2D = style_data.get("edge_texture", null)
	var node_texture: Texture2D = style_data.get("node_texture", null)
	var corner_texture: Texture2D = style_data.get("corner_texture", null)
	var use_texture := bool(data.get("use_texture", true)) and edge_texture != null
	var edge_frame_count := int(style_data.get("edge_frame_count", 1))
	var node_frame_count := int(style_data.get("node_frame_count", 1))
	var corner_frame_count := int(style_data.get("corner_frame_count", 1))
	var frame_index := _range_outline_frame_index(edge_frame_count)
	var node_frame_index := _range_outline_frame_index(node_frame_count)
	var corner_frame_index := _range_outline_frame_index(corner_frame_count)
	var directions: Array[Dictionary] = [
		{"neighbor": Vector2i(0, -1), "from": Vector2(0.0, 0.0), "to": Vector2(CELL_SIZE, 0.0)},
		{"neighbor": Vector2i(1, 0), "from": Vector2(CELL_SIZE, 0.0), "to": Vector2(CELL_SIZE, CELL_SIZE)},
		{"neighbor": Vector2i(0, 1), "from": Vector2(CELL_SIZE, CELL_SIZE), "to": Vector2(0.0, CELL_SIZE)},
		{"neighbor": Vector2i(-1, 0), "from": Vector2(0.0, CELL_SIZE), "to": Vector2(0.0, 0.0)}
	]
	var node_points: Dictionary = {}
	var draw_nodes := bool(data.get("draw_nodes", false))
	for raw_cell: Variant in lookup.keys():
		var cell: Vector2i = raw_cell
		var origin := Vector2(float(cell.x), float(cell.y)) * CELL_SIZE
		for direction: Dictionary in directions:
			var neighbor: Vector2i = cell + direction["neighbor"]
			if lookup.has(neighbor):
				continue
			var from_point: Vector2 = origin + direction["from"]
			var to_point: Vector2 = origin + direction["to"]
			var edge_angle := (to_point - from_point).angle()
			if use_texture:
				_draw_range_texture_piece(edge_texture, edge_frame_count, frame_index, (from_point + to_point) * 0.5, edge_angle, Vector2(float(data.get("edge_length", RANGE_EDGE_TEXTURE_SIZE.x)), float(data.get("edge_thickness", RANGE_EDGE_TEXTURE_SIZE.y))), texture_modulate)
			elif halo_width > width:
				draw_line(from_point, to_point, halo_color, halo_width, true)
				draw_line(from_point, to_point, core_color, width, true)
			else:
				draw_line(from_point, to_point, core_color, width, true)
			if draw_nodes:
				_add_range_outline_node(node_points, from_point, edge_angle)
				_add_range_outline_node(node_points, to_point, edge_angle)
	if draw_nodes:
		var node_radius: float = maxf(float(data.get("node_radius", 2.5)), 1.0)
		var node_size := Vector2.ONE * float(data.get("node_size", RANGE_NODE_TEXTURE_SIZE.x))
		var corner_size := Vector2.ONE * float(data.get("corner_size", RANGE_CORNER_TEXTURE_SIZE.x))
		for node_data in node_points.values():
			var point: Vector2 = node_data.get("point", Vector2.ZERO)
			var angles: Array = node_data.get("angles", [])
			if not _is_range_outline_corner_node(angles):
				continue
			if corner_texture != null:
				_draw_range_texture_piece(corner_texture, corner_frame_count, corner_frame_index, point, 0.0, corner_size, texture_modulate)
			elif node_texture != null:
				_draw_range_texture_piece(node_texture, node_frame_count, node_frame_index, point, 0.0, node_size, texture_modulate)
			else:
				draw_circle(point, node_radius + 2.0, halo_color)
				draw_circle(point, node_radius, core_color)


func _range_outline_color(data: Dictionary) -> Color:
	var color_variant: Variant = data.get("color", null)
	if color_variant is Color:
		return color_variant
	match StringName(data.get("style", &"skill")):
		&"building":
			return BUILDING_RANGE_BORDER
		&"warning":
			return RANGE_OUTLINE_WARNING_COLOR
		&"shu_growth":
			return RANGE_OUTLINE_SHU_COLOR
		&"saria_calcification":
			return RANGE_OUTLINE_SARIA_COLOR
		_:
			return RANGE_OUTLINE_DEFAULT_COLOR


func _range_outline_texture_modulate(data: Dictionary, core_color: Color) -> Color:
	if data.has("color"):
		return core_color
	match StringName(data.get("style", &"skill")):
		&"shu_growth":
			return Color(0.82, 1.0, 0.68, core_color.a)
		&"saria_calcification":
			return Color(1.0, 0.96, 0.78, core_color.a)
		_:
			return Color(1.0, 1.0, 1.0, core_color.a)


func _range_outline_style_data(data: Dictionary) -> Dictionary:
	match StringName(data.get("style", &"skill")):
		&"building":
			return {
				"edge_texture": RANGE_BUILDING_EDGE,
				"node_texture": RANGE_FIELD_NODE,
				"edge_frame_count": RANGE_TEXTURE_FRAME_COUNT,
				"node_frame_count": RANGE_TEXTURE_FRAME_COUNT
			}
		&"gravity":
			return {
				"edge_texture": RANGE_GRAVITY_EDGE,
				"node_texture": RANGE_FIELD_NODE,
				"edge_frame_count": RANGE_TEXTURE_FRAME_COUNT,
				"node_frame_count": RANGE_TEXTURE_FRAME_COUNT
			}
		&"warning":
			return {
				"edge_texture": RANGE_AOE_WARNING_EDGE,
				"node_texture": RANGE_FIELD_NODE,
				"edge_frame_count": RANGE_TEXTURE_FRAME_COUNT,
				"node_frame_count": RANGE_TEXTURE_FRAME_COUNT
			}
		&"shu_growth":
			return {
				"edge_texture": RANGE_BUILDING_EDGE,
				"node_texture": RANGE_FIELD_NODE,
				"edge_frame_count": RANGE_TEXTURE_FRAME_COUNT,
				"node_frame_count": RANGE_TEXTURE_FRAME_COUNT
			}
		&"saria_calcification":
			return {
				"edge_texture": RANGE_SKILL_EDGE,
				"node_texture": RANGE_FIELD_NODE,
				"edge_frame_count": RANGE_TEXTURE_FRAME_COUNT,
				"node_frame_count": RANGE_TEXTURE_FRAME_COUNT
			}
		&"skill":
			return {
				"edge_texture": RANGE_SKILL_EDGE,
				"node_texture": RANGE_FIELD_NODE,
				"edge_frame_count": RANGE_TEXTURE_FRAME_COUNT,
				"node_frame_count": RANGE_TEXTURE_FRAME_COUNT
			}
		_:
			return {
				"edge_texture": RANGE_EDGE_BASE,
				"node_texture": RANGE_NODE_GLOW,
				"edge_frame_count": 1,
				"node_frame_count": RANGE_TEXTURE_FRAME_COUNT
			}


func _range_outline_frame_index(frame_count: int) -> int:
	var normalized_count := maxi(frame_count, 1)
	return int(floor(_range_outline_time * RANGE_TEXTURE_FPS)) % normalized_count


func _draw_range_texture_piece(texture: Texture2D, hframes: int, frame_index: int, center: Vector2, rotation_value: float, size: Vector2, modulate: Color) -> void:
	if texture == null:
		return
	var normalized_hframes := maxi(hframes, 1)
	var frame_size := Vector2(
		float(texture.get_width()) / float(normalized_hframes),
		float(texture.get_height())
	)
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return
	var source_rect := Rect2(Vector2(frame_size.x * float(frame_index % normalized_hframes), 0.0), frame_size)
	draw_set_transform(center, rotation_value, Vector2.ONE)
	draw_texture_rect_region(texture, Rect2(-size * 0.5, size), source_rect, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _add_range_outline_node(node_points: Dictionary, point: Vector2, edge_angle: float) -> void:
	var key := _range_outline_node_key(point)
	var data: Dictionary = node_points.get(key, {"point": point, "angles": []})
	var angles: Array = data.get("angles", [])
	angles.append(edge_angle)
	data["angles"] = angles
	node_points[key] = data


func _is_range_outline_corner_node(angles: Array) -> bool:
	var normalized_angles: Array[float] = []
	for raw_angle: Variant in angles:
		var angle := fposmod(float(raw_angle), PI)
		var matched := false
		for existing: float in normalized_angles:
			if abs(existing - angle) < 0.01 or abs(abs(existing - angle) - PI) < 0.01:
				matched = true
				break
		if not matched:
			normalized_angles.append(angle)
	return normalized_angles.size() >= 2


func _range_outline_node_key(point: Vector2) -> String:
	return "%d:%d" % [int(round(point.x)), int(round(point.y))]


func _dedupe_range_outline_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen := {}
	for cell: Vector2i in cells:
		if seen.has(cell):
			continue
		seen[cell] = true
		result.append(cell)
	return result


func _draw_attack_range_cell(rect: Rect2) -> void:
	_draw_cell_overlay(OVERLAY_ATTACK_RANGE, rect, ATTACK_RANGE_FILL, ATTACK_RANGE_BORDER, 4.0, 2.0)


func _draw_deploy_range_cell(rect: Rect2) -> void:
	_draw_cell_overlay(OVERLAY_DEPLOY_VALID, rect, DEPLOY_RANGE_FILL, DEPLOY_RANGE_BORDER, 6.0, 1.5)


func _draw_building_range_cell(rect: Rect2) -> void:
	_draw_cell_overlay(OVERLAY_BUILDING_RANGE, rect, BUILDING_RANGE_FILL, BUILDING_RANGE_BORDER, 7.0, 2.0)


func _draw_deploy_preview_cell(rect: Rect2, is_valid: bool) -> void:
	if is_valid:
		_draw_cell_overlay(OVERLAY_DEPLOY_VALID, rect, DEPLOY_VALID_FILL, DEPLOY_VALID_BORDER, 5.0, 3.0)
	else:
		_draw_cell_overlay(OVERLAY_DEPLOY_INVALID, rect, DEPLOY_INVALID_FILL, DEPLOY_INVALID_BORDER, 5.0, 3.0)


func _draw_deploy_locked_cell(rect: Rect2) -> void:
	draw_rect(rect.grow(-5.0), DEPLOY_LOCKED_FILL)
	draw_rect(rect.grow(-5.0), DEPLOY_LOCKED_BORDER, false, 3.0)


func _draw_cell_overlay(texture: Texture2D, rect: Rect2, fill_color: Color, border_color: Color, inset: float, border_width: float) -> void:
	if texture != null:
		draw_texture_rect(texture, rect, false)
		return
	var overlay_rect := rect.grow(-inset)
	draw_rect(overlay_rect, fill_color)
	if border_color.a > 0.0 and border_width > 0.0:
		draw_rect(overlay_rect, border_color, false, border_width)


func _draw_deploy_visual_preview(map_manager: Node) -> void:
	if _deploy_preview_texture == null:
		return
	var cell := _deploy_locked_cell if _deploy_locked_cell.x >= 0 else _deploy_preview_cell
	if cell.x < 0:
		return
	if cell == _deploy_preview_cell and not _deploy_preview_valid:
		return
	var facing := _deploy_preview_facing if _deploy_locked_cell.x >= 0 else Vector2i.RIGHT
	_draw_unit_preview_texture(map_manager.cell_to_world(cell), facing)


func _draw_unit_preview_texture(center: Vector2, facing: Vector2i) -> void:
	var texture_size := _deploy_preview_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var visual_scale := UNIT_VISUAL_DISPLAY_SIZE / UNIT_VISUAL_TEXTURE_SIZE
	var scale_x := -visual_scale if _should_visual_face_left(facing) else visual_scale
	draw_set_transform(center + UNIT_VISUAL_OFFSET, 0.0, Vector2(scale_x, visual_scale))
	draw_texture_rect(_deploy_preview_texture, Rect2(-texture_size * 0.5, texture_size), false, UNIT_PREVIEW_MODULATE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _set_deploy_preview_visual(visual_key: String) -> void:
	var normalized_key := visual_key.strip_edges()
	if normalized_key == _deploy_preview_visual_key:
		return
	_deploy_preview_visual_key = normalized_key
	_deploy_preview_texture = _load_unit_visual_texture(normalized_key)


func _load_unit_visual_texture(visual_key: String) -> Texture2D:
	if visual_key.is_empty():
		return null
	var path := "%s/%s/%s/%s_%s_000.png" % [UNIT_VISUAL_TEXTURE_ROOT, visual_key, UNIT_VISUAL_IDLE_ANIM, visual_key, UNIT_VISUAL_IDLE_ANIM]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _should_visual_face_left(direction: Vector2i) -> bool:
	var normalized := _normalize_direction(direction)
	return normalized == Vector2i.LEFT or normalized == Vector2i.UP


func _normalize_direction(direction: Vector2i) -> Vector2i:
	if direction == Vector2i.ZERO:
		return Vector2i.RIGHT
	if abs(direction.x) >= abs(direction.y):
		return Vector2i.RIGHT if direction.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0 else Vector2i.UP


func _draw_deploy_direction_arrow(map_manager: Node) -> void:
	var start: Vector2 = map_manager.cell_to_world(_deploy_locked_cell)
	var direction := Vector2(_deploy_preview_facing)
	if direction.length_squared() <= 0.0:
		return
	direction = direction.normalized()
	var radius := CELL_SIZE * 1.25
	var tangent := Vector2(-direction.y, direction.x)
	var sector_points := PackedVector2Array([
		start,
		start + (direction + tangent * 0.58).normalized() * radius,
		start + (direction - tangent * 0.58).normalized() * radius
	])
	draw_circle(start, radius, Color(1.0, 0.70, 0.20, 0.11))
	draw_colored_polygon(sector_points, Color(1.0, 0.68, 0.18, 0.22))
	draw_arc(start, radius, 0.0, TAU, 72, Color(1.0, 0.74, 0.28, 0.55), 2.0, true)
	var center_rect := Rect2(start - Vector2.ONE * CELL_SIZE * 0.26, Vector2.ONE * CELL_SIZE * 0.52)
	draw_rect(center_rect, Color(1.0, 0.68, 0.18, 0.30))
	draw_rect(center_rect, DEPLOY_LOCKED_BORDER, false, 3.0)
	draw_line(start + Vector2(-10.0, 0.0), start + Vector2(10.0, 0.0), DEPLOY_LOCKED_BORDER, 3.0, true)
	draw_line(start + Vector2(0.0, -10.0), start + Vector2(0.0, 10.0), DEPLOY_LOCKED_BORDER, 3.0, true)
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for direction_i: Vector2i in directions:
		var arrow_direction := Vector2(direction_i)
		var selected := direction_i == _deploy_preview_facing
		var arrow_color := DEPLOY_LOCKED_BORDER if selected else Color(1.0, 0.82, 0.38, 0.48)
		var line_width := 6.0 if selected else 3.0
		var begin := start + arrow_direction * CELL_SIZE * 0.34
		var end := start + arrow_direction * CELL_SIZE * (0.94 if selected else 0.78)
		draw_line(begin, end, arrow_color, line_width, true)
		_draw_arrow_head(end, arrow_direction, arrow_color, 12.0 if selected else 8.0)


func _draw_arrow_head(tip: Vector2, direction: Vector2, color: Color, size: float) -> void:
	var normalized := direction.normalized()
	var tangent := Vector2(-normalized.y, normalized.x)
	var points := PackedVector2Array([
		tip,
		tip - normalized * size + tangent * size * 0.55,
		tip - normalized * size - tangent * size * 0.55
	])
	draw_colored_polygon(points, color)


func _draw_wave_route_previews(map_manager: Node) -> void:
	if _wave_route_previews.is_empty():
		return
	var label_infos: Array[Dictionary] = []
	for index in range(_wave_route_previews.size()):
		var route: Dictionary = _wave_route_previews[index]
		var color := _get_route_color(route, index)
		var offset := _get_route_offset(index)
		var path: Array = route.get("path", [])
		if not path.is_empty():
			_draw_route_path(map_manager, path, color, offset, StringName(route.get("effective_path_mode", route.get("path_mode", &"normal"))))
			var label_info := _make_route_label_info(map_manager, path, offset, color, route)
			if not label_info.is_empty():
				label_infos.append(label_info)
	_draw_route_label_badges(label_infos)


func _draw_route_path(map_manager: Node, path: Array, color: Color, offset: Vector2, path_mode: StringName) -> void:
	if path.size() <= 1:
		return
	var segments: Array[PackedVector2Array] = []
	var points := PackedVector2Array()
	for cell_variant: Variant in path:
		var cell: Vector2i = cell_variant
		if not map_manager.is_inside(cell) or not map_manager.is_discovered(cell):
			if points.size() > 1:
				segments.append(points)
			points = PackedVector2Array()
			continue
		points.append(map_manager.cell_to_world(cell) + offset)
	if points.size() > 1:
		segments.append(points)
	if segments.is_empty():
		return
	var width := 7.0 if path_mode == &"flying" else 5.0
	for segment: PackedVector2Array in segments:
		draw_polyline(segment, Color(color.r, color.g, color.b, 0.22), width + 5.0, true)
		draw_polyline(segment, color, width, true)
		if path_mode == &"demolisher":
			_draw_route_markers(segment, color, 11.0, true)
		elif path_mode == &"flying":
			_draw_route_markers(segment, color, 14.0, false)
		if segment.size() >= 2:
			_draw_arrow_head(segment[segment.size() - 1], segment[segment.size() - 1] - segment[segment.size() - 2], color, 13.0)


func _draw_route_markers(points: PackedVector2Array, color: Color, spacing: float, draw_square: bool) -> void:
	if points.size() < 2:
		return
	for i in range(1, points.size()):
		var from_point := points[i - 1]
		var to_point := points[i]
		var segment := to_point - from_point
		var length := segment.length()
		if length <= 0.01:
			continue
		var direction := segment / length
		var marker_count := int(floor(length / (CELL_SIZE * 0.85)))
		for marker_index in range(marker_count + 1):
			var point: Vector2 = from_point + direction * min(float(marker_index + 1) * CELL_SIZE * 0.55, length)
			if draw_square:
				draw_rect(Rect2(point - Vector2.ONE * spacing * 0.5, Vector2.ONE * spacing), Color(color.r, color.g, color.b, 0.45), false, 2.0)
			else:
				draw_circle(point, spacing * 0.32, Color(color.r, color.g, color.b, 0.45))


func _make_route_label_info(map_manager: Node, path: Array, offset: Vector2, color: Color, route: Dictionary) -> Dictionary:
	var anchor_info := _get_route_label_anchor(map_manager, path, offset)
	if anchor_info.is_empty():
		return {}
	var label_text := String(route.get("route_label", ""))
	if label_text.is_empty():
		label_text = String(route.get("spawn_key", "?"))
	return {
		"anchor_cell": anchor_info.get("cell", Vector2i(-1, -1)),
		"anchor": anchor_info.get("position", Vector2.ZERO),
		"direction": anchor_info.get("direction", Vector2.RIGHT),
		"color": color,
		"label": label_text
	}


func _get_route_label_anchor(map_manager: Node, path: Array, offset: Vector2) -> Dictionary:
	if path.is_empty():
		return {}
	var desired_index: int = max(path.size() - 1 - ROUTE_LABEL_DISTANCE_FROM_CORE_TILES, 0)
	var candidate_indexes: Array[int] = [desired_index]
	for step in range(1, path.size()):
		var toward_core := desired_index + step
		var toward_spawn := desired_index - step
		if toward_core < path.size():
			candidate_indexes.append(toward_core)
		if toward_spawn >= 0:
			candidate_indexes.append(toward_spawn)
	for index in candidate_indexes:
		var cell: Vector2i = path[index]
		if not map_manager.is_inside(cell) or not map_manager.is_discovered(cell):
			continue
		return {
			"cell": cell,
			"position": map_manager.cell_to_world(cell) + offset,
			"direction": _get_route_direction_at_index(path, index)
		}
	return {}


func _get_route_direction_at_index(path: Array, index: int) -> Vector2:
	if path.size() <= 1:
		return Vector2.RIGHT
	var previous_index: int = max(index - 1, 0)
	var next_index: int = min(index + 1, path.size() - 1)
	if previous_index == next_index:
		next_index = min(index + 1, path.size() - 1)
	var from_cell: Vector2i = path[previous_index]
	var to_cell: Vector2i = path[next_index]
	var direction := Vector2(float(to_cell.x - from_cell.x), float(to_cell.y - from_cell.y))
	if direction.length() > 0.01:
		return direction.normalized()
	if index > 0:
		from_cell = path[index - 1]
		to_cell = path[index]
		direction = Vector2(float(to_cell.x - from_cell.x), float(to_cell.y - from_cell.y))
		if direction.length() > 0.01:
			return direction.normalized()
	return Vector2.RIGHT


func _draw_route_label_badges(label_infos: Array[Dictionary]) -> void:
	if label_infos.is_empty():
		return
	var groups: Dictionary = {}
	var group_order: PackedStringArray = []
	for info in label_infos:
		var anchor_cell: Vector2i = info.get("anchor_cell", Vector2i(-1, -1))
		var group_key := "%d,%d" % [anchor_cell.x, anchor_cell.y]
		if not groups.has(group_key):
			groups[group_key] = []
			group_order.append(group_key)
		var group: Array = groups[group_key]
		group.append(info)
		groups[group_key] = group
	for group_key in group_order:
		var group: Array = groups[group_key]
		for index in range(group.size()):
			var info: Dictionary = group[index]
			var anchor: Vector2 = info.get("anchor", Vector2.ZERO)
			var direction: Vector2 = info.get("direction", Vector2.RIGHT)
			var color: Color = info.get("color", Color.WHITE)
			var label_text := String(info.get("label", "?"))
			var label_offset := _get_route_label_group_offset(index, group.size(), direction)
			var label_center := anchor + label_offset
			if label_offset.length() > 1.0:
				draw_line(anchor, label_center, Color(color.r, color.g, color.b, 0.64), 2.0, true)
			_draw_route_label_badge(label_center, color, label_text)


func _get_route_label_group_offset(index: int, count: int, direction: Vector2) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var normalized := direction.normalized()
	if normalized.length() <= 0.01:
		normalized = Vector2.RIGHT
	var tangent := Vector2(-normalized.y, normalized.x)
	var centered_index := float(index) - (float(count) - 1.0) * 0.5
	return tangent * centered_index * ROUTE_LABEL_GROUP_OFFSET_STEP - normalized * ROUTE_LABEL_GROUP_BACK_OFFSET


func _draw_route_label_badge(center: Vector2, color: Color, label_text: String) -> void:
	draw_circle(center, ROUTE_LABEL_BADGE_RADIUS + 5.0, Color(color.r, color.g, color.b, 0.18))
	draw_circle(center, ROUTE_LABEL_BADGE_RADIUS + 1.0, ROUTE_LABEL_BADGE_BG)
	draw_arc(center, ROUTE_LABEL_BADGE_RADIUS + 1.5, 0.0, TAU, 28, color, 2.5, true)
	draw_circle(center, ROUTE_LABEL_BADGE_RADIUS - 2.0, Color(color.r, color.g, color.b, 0.20))
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-ROUTE_LABEL_BADGE_RADIUS, 5.0),
		label_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		ROUTE_LABEL_BADGE_RADIUS * 2.0,
		15,
		Color.WHITE
	)


func _draw_event_bubbles(map_manager: Node) -> void:
	if map_manager == null:
		return
	for cell in _get_visible_event_cells(map_manager):
		var center := _event_bubble_center(map_manager, cell)
		var hovered := cell == _hovered_event_cell
		var pulse := 0.5 + sin(_range_outline_time * 4.0 + float(cell.x + cell.y) * 0.25) * 0.5
		var radius := EVENT_BUBBLE_RADIUS + (3.0 if hovered else pulse * 2.0)
		var fill := EVENT_BUBBLE_HOVER_FILL if hovered else EVENT_BUBBLE_FILL
		var border := EVENT_BUBBLE_HOVER_BORDER if hovered else EVENT_BUBBLE_BORDER
		draw_line(map_manager.cell_to_world(cell), center + Vector2(0.0, radius), Color(border.r, border.g, border.b, 0.34), 2.0, true)
		draw_circle(center, radius + 7.0, Color(border.r, border.g, border.b, 0.14 + pulse * 0.08))
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 36, border, 3.0, true)
		draw_circle(center + Vector2(-radius * 0.28, -radius * 0.28), radius * 0.22, Color(1.0, 1.0, 1.0, 0.18))
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-radius, radius * 0.38),
			"!",
			HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0,
			22 if hovered else 20,
			EVENT_BUBBLE_TEXT
		)


func _get_visible_event_cells(map_manager: Node) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if map_manager == null:
		return cells
	var event_cells: Array = map_manager.get_all_cells()
	if _random_event_manager == null:
		_random_event_manager = get_node_or_null("../../Managers/RandomEventManager")
	if _random_event_manager != null and _random_event_manager.has_method("get_event_cells"):
		event_cells = _random_event_manager.get_event_cells()
	for raw_cell in event_cells:
		var cell: Vector2i = raw_cell
		if not map_manager.is_discovered(cell):
			continue
		if _has_event_at_cell(cell):
			cells.append(cell)
	return cells


func _has_visible_event_bubbles(map_manager: Node) -> bool:
	if map_manager == null:
		return false
	var event_cells: Array = map_manager.get_all_cells()
	if _random_event_manager == null:
		_random_event_manager = get_node_or_null("../../Managers/RandomEventManager")
	if _random_event_manager != null and _random_event_manager.has_method("get_event_cells"):
		event_cells = _random_event_manager.get_event_cells()
	for raw_cell in event_cells:
		var cell: Vector2i = raw_cell
		if map_manager.is_discovered(cell) and _has_event_at_cell(cell):
			return true
	return false


func _get_event_bubble_cell_at_world(world_position: Vector2, map_manager: Node) -> Vector2i:
	if map_manager == null:
		return Vector2i(-1, -1)
	for cell in _get_visible_event_cells(map_manager):
		if world_position.distance_to(_event_bubble_center(map_manager, cell)) <= EVENT_BUBBLE_HIT_RADIUS:
			return cell
	return Vector2i(-1, -1)


func _event_bubble_center(map_manager: Node, cell: Vector2i) -> Vector2:
	return map_manager.cell_to_world(cell) + EVENT_BUBBLE_FLOAT_OFFSET


func _get_route_color(route: Dictionary, index: int) -> Color:
	if not bool(route.get("ok", false)):
		return ROUTE_WARNING_COLOR
	var effective_path_mode := StringName(route.get("effective_path_mode", route.get("path_mode", &"normal")))
	if effective_path_mode == &"flying":
		return ROUTE_FLYING_COLOR
	if effective_path_mode == &"demolisher":
		return ROUTE_DEMOLISHER_COLOR
	return ROUTE_PREVIEW_COLORS[index % ROUTE_PREVIEW_COLORS.size()]


func _get_route_offset(index: int) -> Vector2:
	var offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(0.0, -7.0),
		Vector2(7.0, 0.0),
		Vector2(0.0, 7.0),
		Vector2(-7.0, 0.0)
	]
	return offsets[index % offsets.size()]


func _get_cell_color(data) -> Color:
	if not data.discovered:
		return COLOR_HIDDEN
	if data.is_core:
		return COLOR_CORE
	if data.spawn_key != StringName():
		return COLOR_SPAWN
	if data.terrain == CellData.TERRAIN_WATER:
		return COLOR_WATER
	if data.terrain == CellData.TERRAIN_HIGHLAND:
		return COLOR_HIGHLAND
	if data.terrain == CellData.TERRAIN_MOUNTAIN or not data.walkable:
		return COLOR_BLOCKED
	if _is_resource_hidden_by_operational_building(data):
		return COLOR_PLAIN
	if data.resource_type == &"wood":
		return COLOR_RESOURCE_WOOD
	if data.resource_type == &"stone":
		return COLOR_RESOURCE_STONE
	if data.resource_type == &"mana":
		return COLOR_RESOURCE_MANA
	return COLOR_PLAIN


static func _cell_hash(cell: Vector2i, salt: int) -> int:
	var h := cell.x * 374761393 + cell.y * 668265263 + salt * 2147483647
	h = (h ^ (h >> 13)) * 1274126177
	return int(abs(h ^ (h >> 16)))


## 安静平地（无资源/出生点/核心/渡口的草地）才撒微贴花。
func _is_quiet_plain(data) -> bool:
	if data.terrain != CellData.TERRAIN_PLAIN:
		return false
	return data.resource_type == StringName() and data.spawn_key == StringName() and not data.is_core and not data.is_ford


## 平地微贴花：按格哈希撒 0-2 个碎石/野花/草簇，打破平铺重复。
func _draw_plain_decals(rect: Rect2, cell: Vector2i) -> void:
	var roll := _cell_hash(cell, 11) % 10
	if roll >= 4:
		return
	var count := 2 if roll == 0 else 1
	for i: int in range(count):
		var px := 10.0 + float(_cell_hash(cell, 23 + i * 7) % 44)
		var py := 10.0 + float(_cell_hash(cell, 41 + i * 7) % 44)
		var at := rect.position + Vector2(px, py)
		var kind := _cell_hash(cell, 67 + i * 7) % 3
		if kind == 0:
			draw_circle(at + Vector2(0.6, 0.8), 2.4, DECAL_STONE_DARK)
			draw_circle(at, 2.2, DECAL_STONE_LIGHT)
		elif kind == 1:
			var petal := DECAL_FLOWER_PETAL if _cell_hash(cell, 83 + i) % 2 == 0 else DECAL_FLOWER_GOLD
			draw_circle(at + Vector2(-1.4, 0.4), 1.1, petal)
			draw_circle(at + Vector2(1.4, 0.4), 1.1, petal)
			draw_circle(at + Vector2(0.0, -1.2), 1.1, petal)
		else:
			draw_line(at + Vector2(-1.6, 2.0), at + Vector2(-2.2, -2.2), DECAL_GRASS, 1.1, false)
			draw_line(at + Vector2(0.0, 2.0), at + Vector2(0.4, -3.0), DECAL_GRASS, 1.1, false)
			draw_line(at + Vector2(1.6, 2.0), at + Vector2(2.4, -1.6), DECAL_GRASS, 1.1, false)


## 水面微光：按格哈希撒 1-2 条高光短线，相位错开低频闪烁。
func _draw_water_sparkles(rect: Rect2, cell: Vector2i) -> void:
	var count := 1 + _cell_hash(cell, 5) % 2
	for i: int in range(count):
		var phase := (_sparkle_bucket + _cell_hash(cell, 29 + i * 13)) % 6
		if phase >= 3:
			continue
		var alpha := 0.38 if phase == 1 else 0.2
		var px := 8.0 + float(_cell_hash(cell, 47 + i * 13) % 44)
		var py := 8.0 + float(_cell_hash(cell, 59 + i * 13) % 48)
		var at := rect.position + Vector2(px, py)
		var dash := 3.0 + float(_cell_hash(cell, 71 + i) % 3)
		var color := Color(SPARKLE_COLOR.r, SPARKLE_COLOR.g, SPARKLE_COLOR.b, alpha)
		draw_line(at, at + Vector2(dash, 0.0), color, 1.2, false)


## 左上暖光：北/西邻是山或高台时，本格沿该边受冷色短影。
func _draw_feature_cast_shadow(rect: Rect2, cell: Vector2i, map_manager: Node, data) -> void:
	if data.terrain == CellData.TERRAIN_MOUNTAIN or data.terrain == CellData.TERRAIN_HIGHLAND:
		return
	var north = map_manager.get_cell_data(cell + Vector2i(0, -1))
	if north != null and north.discovered and (north.terrain == CellData.TERRAIN_MOUNTAIN or north.terrain == CellData.TERRAIN_HIGHLAND):
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, FEATURE_SHADOW_WIDTH)), FEATURE_SHADOW_COLOR)
	var west = map_manager.get_cell_data(cell + Vector2i(-1, 0))
	if west != null and west.discovered and (west.terrain == CellData.TERRAIN_MOUNTAIN or west.terrain == CellData.TERRAIN_HIGHLAND):
		draw_rect(Rect2(rect.position, Vector2(FEATURE_SHADOW_WIDTH, rect.size.y)), FEATURE_SHADOW_COLOR)


## 迷雾羽化：已探索格沿未探索邻边画雾色渐变带，软化硬切。
func _draw_fog_feather(rect: Rect2, cell: Vector2i, map_manager: Node) -> void:
	for dir: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var neighbor = map_manager.get_cell_data(cell + dir)
		if neighbor == null or neighbor.discovered:
			continue
		for step: int in range(FOG_EDGE_ALPHAS.size()):
			var color := Color(FOG_EDGE_COLOR.r, FOG_EDGE_COLOR.g, FOG_EDGE_COLOR.b, FOG_EDGE_ALPHAS[step])
			var offset := float(step) * FOG_EDGE_STEP_WIDTH
			var band := Rect2()
			if dir == Vector2i(-1, 0):
				band = Rect2(rect.position + Vector2(offset, 0.0), Vector2(FOG_EDGE_STEP_WIDTH, rect.size.y))
			elif dir == Vector2i(1, 0):
				band = Rect2(rect.position + Vector2(rect.size.x - offset - FOG_EDGE_STEP_WIDTH, 0.0), Vector2(FOG_EDGE_STEP_WIDTH, rect.size.y))
			elif dir == Vector2i(0, -1):
				band = Rect2(rect.position + Vector2(0.0, offset), Vector2(rect.size.x, FOG_EDGE_STEP_WIDTH))
			else:
				band = Rect2(rect.position + Vector2(0.0, rect.size.y - offset - FOG_EDGE_STEP_WIDTH), Vector2(rect.size.x, FOG_EDGE_STEP_WIDTH))
			draw_rect(band, color)


## 水格内侧沿临陆边画浅水带+泡沫线（渡口与水视作同面，未探索邻格不画防剧透）。
func _draw_shore_bands(rect: Rect2, cell: Vector2i, map_manager: Node) -> void:
	for dir: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var neighbor = map_manager.get_cell_data(cell + dir)
		if neighbor == null or not neighbor.discovered:
			continue
		if neighbor.terrain == CellData.TERRAIN_WATER or neighbor.is_ford:
			continue
		var foam := Rect2()
		var shallow := Rect2()
		if dir == Vector2i(-1, 0):
			foam = Rect2(rect.position, Vector2(SHORE_FOAM_WIDTH, rect.size.y))
			shallow = Rect2(rect.position + Vector2(SHORE_FOAM_WIDTH, 0.0), Vector2(SHORE_SHALLOW_WIDTH, rect.size.y))
		elif dir == Vector2i(1, 0):
			foam = Rect2(rect.position + Vector2(rect.size.x - SHORE_FOAM_WIDTH, 0.0), Vector2(SHORE_FOAM_WIDTH, rect.size.y))
			shallow = Rect2(rect.position + Vector2(rect.size.x - SHORE_FOAM_WIDTH - SHORE_SHALLOW_WIDTH, 0.0), Vector2(SHORE_SHALLOW_WIDTH, rect.size.y))
		elif dir == Vector2i(0, -1):
			foam = Rect2(rect.position, Vector2(rect.size.x, SHORE_FOAM_WIDTH))
			shallow = Rect2(rect.position + Vector2(0.0, SHORE_FOAM_WIDTH), Vector2(rect.size.x, SHORE_SHALLOW_WIDTH))
		else:
			foam = Rect2(rect.position + Vector2(0.0, rect.size.y - SHORE_FOAM_WIDTH), Vector2(rect.size.x, SHORE_FOAM_WIDTH))
			shallow = Rect2(rect.position + Vector2(0.0, rect.size.y - SHORE_FOAM_WIDTH - SHORE_SHALLOW_WIDTH), Vector2(rect.size.x, SHORE_SHALLOW_WIDTH))
		draw_rect(shallow, SHORE_SHALLOW_COLOR)
		draw_rect(foam, SHORE_FOAM_COLOR)


func _on_day_started_tint(_day: int) -> void:
	_tween_day_night_tint(Color.WHITE)
	_clear_night_glows()


func _on_night_started_tint(_day: int) -> void:
	_tween_day_night_tint(NIGHT_CANVAS_TINT)
	_spawn_night_glows()


func _clear_night_glows() -> void:
	if _night_glow_root != null:
		_night_glow_root.queue_free()
		_night_glow_root = null


## 夜晚为核心与已探索魔力晶簇挂径向点光（代码生成渐变纹理，不依赖资产）。
func _spawn_night_glows() -> void:
	_clear_night_glows()
	var map_manager := _get_map_manager()
	if map_manager == null:
		return
	_night_glow_root = Node2D.new()
	_night_glow_root.name = "NightGlowRoot"
	add_child(_night_glow_root)
	for y in range(map_manager.height):
		for x in range(map_manager.width):
			var data = map_manager.get_cell_data(Vector2i(x, y))
			if data == null or not data.discovered:
				continue
			if data.is_core:
				_add_night_glow(Vector2i(x, y), NIGHT_GLOW_CORE_COLOR, NIGHT_GLOW_CORE_ENERGY, NIGHT_GLOW_CORE_SCALE)
			elif data.resource_type == &"mana":
				_add_night_glow(Vector2i(x, y), NIGHT_GLOW_MANA_COLOR, NIGHT_GLOW_MANA_ENERGY, NIGHT_GLOW_MANA_SCALE)


func _add_night_glow(cell: Vector2i, color: Color, energy: float, glow_scale: float) -> void:
	var light := PointLight2D.new()
	light.texture = _get_glow_texture()
	light.position = (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE
	light.color = color
	light.energy = energy
	light.texture_scale = glow_scale
	_night_glow_root.add_child(light)


func _get_glow_texture() -> Texture2D:
	if _glow_texture != null:
		return _glow_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 256
	texture.height = 256
	_glow_texture = texture
	return _glow_texture


func _tween_day_night_tint(target: Color) -> void:
	if _day_night_tint == null:
		return
	var tween := create_tween()
	tween.tween_property(_day_night_tint, "color", target, DAY_NIGHT_FADE_SECONDS)


func _draw_cell_tile(rect: Rect2, data) -> void:
	var texture := _get_cell_texture(data)
	if texture == null:
		draw_rect(rect, _get_cell_color(data))
		return
	draw_texture_rect(texture, rect, false)


func _get_cell_texture(data) -> Texture2D:
	if not data.discovered:
		return TILE_HIDDEN
	if data.is_core:
		return TILE_PLAIN
	if data.spawn_key != StringName():
		return TILE_SPAWN
	if data.terrain == CellData.TERRAIN_WATER:
		return TILE_WATER
	if data.terrain == CellData.TERRAIN_HIGHLAND:
		return TILE_HIGHLAND
	if data.terrain == CellData.TERRAIN_MOUNTAIN or not data.walkable:
		return TILE_MOUNTAIN
	if data.is_ford:
		return TILE_FORD
	if _is_resource_hidden_by_operational_building(data):
		return TILE_PLAIN_ALT if _uses_alternate_plain(data.cell) else TILE_PLAIN
	if data.resource_type == &"wood":
		return TILE_RESOURCE_WOOD
	if data.resource_type == &"stone":
		return TILE_RESOURCE_STONE
	if data.resource_type == &"mana":
		return TILE_RESOURCE_MANA
	if _uses_alternate_plain(data.cell):
		return TILE_PLAIN_ALT
	return TILE_PLAIN


func _uses_alternate_plain(cell: Vector2i) -> bool:
	return int(abs(cell.x * 37 + cell.y * 19)) % 5 == 0


func _is_resource_hidden_by_operational_building(data) -> bool:
	if data == null or data.resource_type == StringName() or int(data.building_runtime_id) < 0:
		return false
	var building := _get_building_by_runtime_id(int(data.building_runtime_id))
	if building == null:
		return true
	return not _is_building_destroyed(building)


func _get_building_by_runtime_id(building_runtime_id: int) -> Node:
	var building_manager := _get_building_manager()
	if building_manager == null or not building_manager.has_method("get_building_by_runtime_id"):
		return null
	var building: Node = building_manager.get_building_by_runtime_id(building_runtime_id)
	return building if building != null and is_instance_valid(building) else null


func _is_building_destroyed(building: Node) -> bool:
	if building == null:
		return false
	if building.has_method("is_destroyed"):
		return bool(building.is_destroyed())
	var current_hp_variant: Variant = building.get("current_hp")
	return current_hp_variant != null and int(current_hp_variant) <= 0


func _handle_mouse_button(event: InputEventMouseButton, map_manager: Node) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if _is_pointer_over_gui():
				return
			if event.pressed:
				_zoom_at_mouse(1.0 / ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			if _is_pointer_over_gui():
				return
			if event.pressed:
				_zoom_at_mouse(ZOOM_STEP)
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_right_press_pos = event.position
				_right_press_time_ms = Time.get_ticks_msec()
				_right_press_tracking = true
				_is_dragging = false
				_drag_button_index = MOUSE_BUTTON_RIGHT
			else:
				if _right_press_tracking:
					var was_dragging := _is_dragging and _drag_button_index == MOUSE_BUTTON_RIGHT
					var distance: float = event.position.distance_to(_right_press_pos)
					var elapsed: int = Time.get_ticks_msec() - _right_press_time_ms
					if not was_dragging and distance <= RIGHT_TAP_MAX_DISTANCE and elapsed <= RIGHT_TAP_MAX_DURATION_MS:
						var event_bus = AppRefs.event_bus()
						if event_bus != null:
							event_bus.right_click_tapped.emit()
				_right_press_tracking = false
				if _drag_button_index == MOUSE_BUTTON_RIGHT:
					_is_dragging = false
					_drag_button_index = 0
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _is_deploy_preview_active():
					return
				_left_press_pos = event.position
				_left_press_tracking = true
				_is_dragging = false
				_drag_button_index = MOUSE_BUTTON_LEFT
			elif _left_press_tracking:
				var was_dragging := _is_dragging and _drag_button_index == MOUSE_BUTTON_LEFT
				_left_press_tracking = false
				if _drag_button_index == MOUSE_BUTTON_LEFT:
					_is_dragging = false
					_drag_button_index = 0
				if not was_dragging and event.position.distance_to(_left_press_pos) < MAP_DRAG_START_DISTANCE:
					var event_cell := _get_event_bubble_cell_at_world(get_global_mouse_position(), map_manager)
					if event_cell.x >= 0:
						_selected_cell = event_cell
						queue_redraw()
						var event_bus = AppRefs.event_bus()
						if event_bus != null:
							event_bus.request_open_event_panel.emit(event_cell)
						return
					var cell: Vector2i = map_manager.world_to_cell(get_global_mouse_position())
					if not map_manager.is_inside(cell):
						return
					_selected_cell = cell
					queue_redraw()
					var event_bus = AppRefs.event_bus()
					if event_bus != null:
						event_bus.map_cell_clicked.emit(cell)


func _is_pointer_over_gui() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var hovered_control := viewport.gui_get_hovered_control()
	return hovered_control != null and hovered_control.is_visible_in_tree()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _camera == null:
		return
	if _drag_button_index == MOUSE_BUTTON_LEFT and _left_press_tracking:
		if _is_deploy_preview_active():
			_left_press_tracking = false
			_is_dragging = false
			_drag_button_index = 0
			return
		_drag_camera_from_mouse_motion(event, _left_press_pos)
	elif _drag_button_index == MOUSE_BUTTON_RIGHT and _right_press_tracking:
		_drag_camera_from_mouse_motion(event, _right_press_pos)


func _drag_camera_from_mouse_motion(event: InputEventMouseMotion, press_pos: Vector2) -> void:
	_drag_camera_from_relative_motion(event.position, press_pos, event.relative)


func _drag_camera_from_relative_motion(current_pos: Vector2, press_pos: Vector2, relative: Vector2) -> void:
	if not _is_dragging:
		if current_pos.distance_to(press_pos) < MAP_DRAG_START_DISTANCE:
			return
		_is_dragging = true
	_camera.position -= relative / max(_zoom_scalar, 0.001)
	_camera.position = _clamp_camera_center(_camera.position)


func _cancel_camera_drag(button_index: int) -> void:
	if _drag_button_index != button_index:
		return
	match button_index:
		MOUSE_BUTTON_LEFT:
			_left_press_tracking = false
		MOUSE_BUTTON_RIGHT:
			_right_press_tracking = false
	_is_dragging = false
	_drag_button_index = 0


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_active_touches[event.index] = event.position
		if _active_touches.size() >= 2:
			_begin_touch_pinch()
	else:
		_active_touches.erase(event.index)
		if _pinch_active and (event.index == _pinch_touch_a or event.index == _pinch_touch_b):
			_end_touch_pinch()
		if _active_touches.is_empty():
			_suppress_emulated_mouse_until_touches_released = false


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _active_touches.has(event.index):
		return
	if not _pinch_active:
		_active_touches[event.index] = event.position
		return
	if not _is_pinch_touch(event.index) or not _active_touches.has(_pinch_touch_a) or not _active_touches.has(_pinch_touch_b):
		_active_touches[event.index] = event.position
		return
	if _is_deploy_preview_active():
		_active_touches[event.index] = event.position
		return
	var old_a: Vector2 = _active_touches[_pinch_touch_a]
	var old_b: Vector2 = _active_touches[_pinch_touch_b]
	_active_touches[event.index] = event.position
	var new_a: Vector2 = _active_touches[_pinch_touch_a]
	var new_b: Vector2 = _active_touches[_pinch_touch_b]
	_zoom_from_viewport_points(old_a, old_b, new_a, new_b)


func _handle_magnify_gesture(event: InputEventMagnifyGesture) -> void:
	if _is_pointer_over_gui() or _is_deploy_preview_active():
		return
	_zoom_at_viewport_positions(float(event.factor), event.position, event.position)


func _begin_touch_pinch() -> void:
	if _pinch_active or _is_deploy_preview_active():
		return
	var touch_indexes := _active_touches.keys()
	if touch_indexes.size() < 2:
		return
	_pinch_touch_a = int(touch_indexes[0])
	_pinch_touch_b = int(touch_indexes[1])
	_pinch_active = true
	_suppress_emulated_mouse_until_touches_released = true
	_cancel_camera_drag(MOUSE_BUTTON_LEFT)


func _end_touch_pinch() -> void:
	_pinch_active = false
	_pinch_touch_a = -1
	_pinch_touch_b = -1


func _is_pinch_touch(index: int) -> bool:
	return index == _pinch_touch_a or index == _pinch_touch_b


func _zoom_from_viewport_points(old_a: Vector2, old_b: Vector2, new_a: Vector2, new_b: Vector2) -> void:
	var old_distance := old_a.distance_to(old_b)
	var new_distance := new_a.distance_to(new_b)
	if old_distance < PINCH_MIN_DISTANCE or new_distance < PINCH_MIN_DISTANCE:
		return
	var before_position := (old_a + old_b) * 0.5
	var after_position := (new_a + new_b) * 0.5
	_zoom_at_viewport_positions(new_distance / old_distance, before_position, after_position)


func _is_deploy_preview_active() -> bool:
	return (
		_deploy_preview_cell != Vector2i(-1, -1)
		or _deploy_locked_cell != Vector2i(-1, -1)
		or not _deploy_range_preview_cells.is_empty()
		or not _deploy_preview_visual_key.is_empty()
	)


func _zoom_at_mouse(factor: float) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var mouse_position := viewport.get_mouse_position()
	_zoom_at_viewport_positions(factor, mouse_position, mouse_position)


func _zoom_at_viewport_positions(factor: float, before_position: Vector2, after_position: Vector2) -> void:
	if _camera == null:
		return
	var before_world := _viewport_to_world(before_position)
	var min_zoom := _fit_zoom
	var max_zoom := _fit_zoom * MAX_ZOOM_MULTIPLIER
	_zoom_scalar = clamp(_zoom_scalar * factor, min_zoom, max_zoom)
	_apply_camera_zoom()
	var after_world := _viewport_to_world(after_position)
	_camera.position += before_world - after_world
	_camera.position = _clamp_camera_center(_camera.position)


func _viewport_to_world(viewport_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * viewport_position


func _fit_camera_to_map(reset_view: bool = true) -> void:
	var map_manager := _get_map_manager()
	if map_manager == null or _camera == null:
		return
	var map_size := _get_map_size(map_manager)
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return
	var viewport_size := get_viewport_rect().size - Vector2.ONE * VIEW_PADDING * 2.0
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var previous_fit_zoom := _fit_zoom
	var previous_zoom_scalar := _zoom_scalar
	_fit_zoom = max(viewport_size.x / map_size.x, viewport_size.y / map_size.y)
	_fit_zoom = max(_fit_zoom, 0.01)
	if reset_view:
		_zoom_scalar = _fit_zoom
		_camera.position = _get_map_center(map_manager)
	else:
		var zoom_ratio: float = previous_zoom_scalar / max(previous_fit_zoom, 0.001)
		_zoom_scalar = clamp(_fit_zoom * zoom_ratio, _fit_zoom, _fit_zoom * MAX_ZOOM_MULTIPLIER)
	_apply_camera_zoom()
	_camera.position = _clamp_camera_center(_camera.position)
	_camera_fit_initialized = true


func _apply_camera_zoom() -> void:
	if _camera != null:
		_camera.zoom = Vector2.ONE * _zoom_scalar


func _clamp_camera_center(desired_center: Vector2) -> Vector2:
	var map_manager := _get_map_manager()
	if map_manager == null:
		return desired_center
	var map_rect := Rect2(Vector2.ZERO, _get_map_size(map_manager))
	var visible_size: Vector2 = get_viewport_rect().size / max(_zoom_scalar, 0.001)
	var overscroll := visible_size * PAN_OVERSCROLL_VIEWPORT_RATIO
	var clamped := desired_center
	clamped.x = clamp(clamped.x, map_rect.position.x + visible_size.x * 0.5 - overscroll.x, map_rect.end.x - visible_size.x * 0.5 + overscroll.x)
	clamped.y = clamp(clamped.y, map_rect.position.y + visible_size.y * 0.5 - overscroll.y, map_rect.end.y - visible_size.y * 0.5 + overscroll.y)
	return clamped


func _get_map_size(map_manager: Node) -> Vector2:
	return Vector2(map_manager.width, map_manager.height) * CELL_SIZE


func _get_map_center(map_manager: Node) -> Vector2:
	return _get_map_size(map_manager) * 0.5


func get_debug_info() -> String:
	var map_manager := _get_map_manager()
	if map_manager == null:
		return "Map not ready"
	var effective_cell_size: float = CELL_SIZE * _zoom_scalar
	var text := "Map %dx%d  Core=%s  Cell~%.1fpx" % [
		map_manager.width,
		map_manager.height,
		map_manager.get_core_cell(),
		effective_cell_size
	]
	if _hovered_cell.x >= 0:
		text += "  Hover=%s" % _hovered_cell
	if _selected_cell.x >= 0:
		text += "  Selected=%s" % _selected_cell
	return text


func _on_viewport_size_changed() -> void:
	_fit_camera_to_map(false)


func _get_map_manager() -> Node:
	if _map_manager != null:
		return _map_manager
	_map_manager = get_node_or_null("../../Managers/MapManager")
	return _map_manager


func _get_building_manager() -> Node:
	if _building_manager != null:
		return _building_manager
	_building_manager = get_node_or_null("../../Managers/BuildingManager")
	return _building_manager


func _has_event_at_cell(cell: Vector2i) -> bool:
	if _random_event_manager == null:
		_random_event_manager = get_node_or_null("../../Managers/RandomEventManager")
	return _random_event_manager != null and _random_event_manager.has_method("has_event_at_cell") and _random_event_manager.has_event_at_cell(cell)
