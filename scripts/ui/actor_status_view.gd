extends Node2D

const HIT_EFFECT_DURATION := 0.18

@export var hp_bar_size := Vector2(46.0, 6.0)
@export var hp_bar_offset := Vector2(-23.0, -34.0)
@export var hp_fill_color := Color(0.35, 0.95, 0.48, 0.95)
@export var shield_fill_color := Color(0.24, 0.66, 1.0, 0.95)
@export var ammo_fill_color := Color(1.0, 0.72, 0.22, 0.95)
@export var hit_effect_color := Color(0.85, 0.95, 1.0, 0.65)

var _current_hp := 1
var _max_hp := 1
var _current_shield := 0
var _max_shield := 0
var _current_ammo := 0
var _max_ammo := 0
var _hit_effect_timer := 0.0


func _ready() -> void:
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if _hit_effect_timer <= 0.0:
		set_process(false)
		return
	_hit_effect_timer = max(_hit_effect_timer - delta, 0.0)
	queue_redraw()


func set_hp(current_hp: int, max_hp: int) -> void:
	_current_hp = max(current_hp, 0)
	_max_hp = max(max_hp, 1)
	queue_redraw()


func set_shield(current_shield: int, max_shield: int) -> void:
	_max_shield = max(max_shield, 0)
	_current_shield = clamp(current_shield, 0, _max_shield)
	queue_redraw()


func set_ammo(current_ammo: int, max_ammo: int) -> void:
	_max_ammo = max(max_ammo, 0)
	_current_ammo = clamp(current_ammo, 0, _max_ammo)
	queue_redraw()


func play_hit_effect() -> void:
	# 战斗 Actor 只通知“受击”，具体表现集中在这个复用组件里。
	_hit_effect_timer = HIT_EFFECT_DURATION
	set_process(true)
	queue_redraw()


func _draw() -> void:
	_draw_hp_bar()
	_draw_secondary_bars()
	_draw_hit_effect()


func _draw_hp_bar() -> void:
	var bg_rect: Rect2 = Rect2(hp_bar_offset, hp_bar_size)
	draw_rect(bg_rect, Color(0.03, 0.04, 0.05, 0.82))
	var ratio: float = clamp(float(_current_hp) / float(_max_hp), 0.0, 1.0)
	var fill_rect: Rect2 = Rect2(
		hp_bar_offset + Vector2.ONE,
		Vector2(max((hp_bar_size.x - 2.0) * ratio, 0.0), hp_bar_size.y - 2.0)
	)
	draw_rect(fill_rect, hp_fill_color)
	draw_rect(bg_rect, Color(1.0, 1.0, 1.0, 0.82), false, 1.0)


func _draw_secondary_bars() -> void:
	var next_y := hp_bar_offset.y + hp_bar_size.y + 2.0
	if _max_shield > 0:
		_draw_ratio_bar(next_y, _current_shield, _max_shield, shield_fill_color)
		next_y += 5.0
	if _max_ammo > 0:
		_draw_ammo_bar(next_y)


func _draw_ratio_bar(y: float, current_value: int, max_value: int, fill_color: Color) -> void:
	var bar_size := Vector2(hp_bar_size.x, 4.0)
	var bg_rect := Rect2(Vector2(hp_bar_offset.x, y), bar_size)
	draw_rect(bg_rect, Color(0.03, 0.04, 0.05, 0.72))
	var ratio: float = clamp(float(current_value) / float(max(max_value, 1)), 0.0, 1.0)
	var fill_rect := Rect2(
		bg_rect.position + Vector2.ONE,
		Vector2(max((bar_size.x - 2.0) * ratio, 0.0), bar_size.y - 2.0)
	)
	draw_rect(fill_rect, fill_color)
	draw_rect(bg_rect, Color(0.82, 0.92, 1.0, 0.72), false, 1.0)


func _draw_ammo_bar(y: float) -> void:
	var pip_count: int = max(_max_ammo, 1)
	var gap := 2.0
	var total_gap := gap * float(max(pip_count - 1, 0))
	var pip_width: float = max((hp_bar_size.x - total_gap) / float(pip_count), 2.0)
	var pip_height := 4.0
	for index in range(pip_count):
		var pip_rect := Rect2(
			Vector2(hp_bar_offset.x + float(index) * (pip_width + gap), y),
			Vector2(pip_width, pip_height)
		)
		var filled := index < _current_ammo
		var fill_color := ammo_fill_color if filled else Color(0.09, 0.08, 0.05, 0.72)
		draw_rect(pip_rect, fill_color)
		draw_rect(pip_rect, Color(1.0, 0.86, 0.42, 0.68), false, 1.0)


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
