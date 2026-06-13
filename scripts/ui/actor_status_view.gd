extends Node2D

const DEFAULT_TRACK_STYLE := preload("res://assets/ui/styles/bar_actor_status_track.tres")
const DEFAULT_HP_FILL_STYLE := preload("res://assets/ui/styles/bar_actor_status_fill_hp.tres")
const DEFAULT_SP_FILL_STYLE := preload("res://assets/ui/styles/bar_actor_status_fill_sp.tres")
const HIT_EFFECT_DURATION := 0.18
const SECONDARY_BAR_HEIGHT := 4.0
const SECONDARY_BAR_GAP := 2.0

@export var hp_bar_size := Vector2(46.0, 6.0)
@export var hp_bar_offset := Vector2(-23.0, -34.0)
@export var track_style: StyleBox = DEFAULT_TRACK_STYLE
@export var hp_fill_style: StyleBox = DEFAULT_HP_FILL_STYLE
@export var shield_fill_style: StyleBox = DEFAULT_SP_FILL_STYLE
@export var ammo_fill_style: StyleBox = DEFAULT_SP_FILL_STYLE
@export var hit_effect_color := Color(0.85, 0.95, 1.0, 0.65)

var _current_hp := 1
var _max_hp := 1
var _current_shield := 0
var _max_shield := 0
var _current_ammo := 0
var _max_ammo := 0
var _hit_effect_timer := 0.0
var _bars_root: Control
var _hp_bar_nodes: Dictionary = {}
var _shield_bar_nodes: Dictionary = {}
var _ammo_bar_nodes: Dictionary = {}


func _ready() -> void:
	_ensure_status_bar_nodes()
	set_process(false)
	_refresh_status_bars()


func _process(delta: float) -> void:
	if _hit_effect_timer <= 0.0:
		set_process(false)
		return
	_hit_effect_timer = max(_hit_effect_timer - delta, 0.0)
	queue_redraw()


func set_hp(current_hp: int, max_hp: int) -> void:
	_current_hp = maxi(current_hp, 0)
	_max_hp = maxi(max_hp, 1)
	_refresh_status_bars()


func set_shield(current_shield: int, max_shield: int) -> void:
	_max_shield = maxi(max_shield, 0)
	_current_shield = clampi(current_shield, 0, _max_shield)
	_refresh_status_bars()


func set_ammo(current_ammo: int, max_ammo: int) -> void:
	_max_ammo = maxi(max_ammo, 0)
	_current_ammo = clampi(current_ammo, 0, _max_ammo)
	_refresh_status_bars()


func play_hit_effect() -> void:
	# 战斗 Actor 只通知“受击”，具体表现集中在这个复用组件里。
	_hit_effect_timer = HIT_EFFECT_DURATION
	set_process(true)
	queue_redraw()


func _draw() -> void:
	_draw_hit_effect()


func _ensure_status_bar_nodes() -> void:
	if _bars_root != null:
		return
	_bars_root = Control.new()
	_bars_root.name = "StatusBarsRoot"
	_bars_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bars_root)
	_hp_bar_nodes = _create_progress_bar("HpBar", hp_fill_style)
	_shield_bar_nodes = _create_progress_bar("ShieldBar", shield_fill_style)
	_ammo_bar_nodes = _create_progress_bar("AmmoBar", ammo_fill_style)


func _create_progress_bar(bar_name: String, fill_style: StyleBox) -> Dictionary:
	var root := Control.new()
	root.name = bar_name
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_root.add_child(root)

	var track := Panel.new()
	track.name = "Track"
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", track_style)
	root.add_child(track)

	var clip := Control.new()
	clip.name = "Clip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)

	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel", fill_style)
	clip.add_child(fill)

	return {
		"root": root,
		"track": track,
		"clip": clip,
		"fill": fill,
	}


func _refresh_status_bars() -> void:
	if not is_node_ready():
		return
	_ensure_status_bar_nodes()
	var hp_ratio: float = clampf(float(_current_hp) / float(maxi(_max_hp, 1)), 0.0, 1.0)
	_apply_bar(_hp_bar_nodes, hp_bar_offset, hp_bar_size, hp_ratio, true)
	var next_y := hp_bar_offset.y + hp_bar_size.y + SECONDARY_BAR_GAP
	var secondary_size := Vector2(hp_bar_size.x, SECONDARY_BAR_HEIGHT)
	if _max_shield > 0:
		var shield_ratio: float = clampf(float(_current_shield) / float(maxi(_max_shield, 1)), 0.0, 1.0)
		_apply_bar(_shield_bar_nodes, Vector2(hp_bar_offset.x, next_y), secondary_size, shield_ratio, true)
		next_y += SECONDARY_BAR_HEIGHT + SECONDARY_BAR_GAP
	else:
		_apply_bar(_shield_bar_nodes, Vector2(hp_bar_offset.x, next_y), secondary_size, 0.0, false)
	if _max_ammo > 0:
		var ammo_ratio: float = clampf(float(_current_ammo) / float(maxi(_max_ammo, 1)), 0.0, 1.0)
		_apply_bar(_ammo_bar_nodes, Vector2(hp_bar_offset.x, next_y), secondary_size, ammo_ratio, true)
	else:
		_apply_bar(_ammo_bar_nodes, Vector2(hp_bar_offset.x, next_y), secondary_size, 0.0, false)


func _apply_bar(nodes: Dictionary, position: Vector2, bar_size: Vector2, ratio: float, visible: bool) -> void:
	var root := nodes.get("root") as Control
	var track := nodes.get("track") as Panel
	var clip := nodes.get("clip") as Control
	var fill := nodes.get("fill") as Panel
	if root == null or track == null or clip == null or fill == null:
		return
	root.visible = visible
	root.position = position
	root.size = bar_size
	root.custom_minimum_size = bar_size
	track.set_anchors_preset(Control.PRESET_FULL_RECT, false)
	track.offset_left = 0.0
	track.offset_top = 0.0
	track.offset_right = 0.0
	track.offset_bottom = 0.0
	clip.set_anchors_preset(Control.PRESET_FULL_RECT, false)
	clip.offset_left = 0.0
	clip.offset_top = 0.0
	clip.offset_right = 0.0
	clip.offset_bottom = 0.0
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 0.0
	fill.offset_top = 0.0
	fill.offset_right = maxf(0.0, bar_size.x * clampf(ratio, 0.0, 1.0))
	fill.offset_bottom = 0.0


func _draw_hit_effect() -> void:
	if _hit_effect_timer <= 0.0:
		return
	var progress: float = 1.0 - (_hit_effect_timer / HIT_EFFECT_DURATION)
	var alpha: float = 1.0 - progress
	var radius: float = 18.0 + progress * 14.0
	var color: Color = hit_effect_color
	color.a *= alpha
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 32, Color(color.r, color.g, color.b, min(color.a + 0.15, 1.0)), 2.0)
