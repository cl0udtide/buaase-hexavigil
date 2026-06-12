extends Node2D

## 单位脚下的椭圆接触阴影（画风宪章：阴影是偏冷蓝紫的颜色化阴影）。
## 消除 sprite"贴在地表上"的悬浮感；合成层（C-track）落地后可由其统一接管。

const SHADOW_COLOR := Color(0.22, 0.20, 0.38, 0.30)

var radius := 13.0
var squash := 0.42


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, radius, SHADOW_COLOR)
