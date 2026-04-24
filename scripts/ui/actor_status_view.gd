extends Node2D

const HIT_EFFECT_DURATION := 0.18

@export var hp_bar_size := Vector2(46.0, 6.0)
@export var hp_bar_offset := Vector2(-23.0, -34.0)
@export var hp_fill_color := Color(0.35, 0.95, 0.48, 0.95)
@export var hit_effect_color := Color(0.85, 0.95, 1.0, 0.65)

var _current_hp := 1
var _max_hp := 1
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


func play_hit_effect() -> void:
	# 战斗 Actor 只通知“受击”，具体表现集中在这个复用组件里。
	_hit_effect_timer = HIT_EFFECT_DURATION
	set_process(true)
	queue_redraw()


func _draw() -> void:
	_draw_hp_bar()
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
