extends Node2D

## 地面持续危险区（凑凑企鹅 P2 火雨）：覆盖若干格，持续 N 秒，每 tick 对站在其上的我方单位造成 DOT。
## 视觉为占位（半透明暖色格）；正式火焰 VFX 随 Boss 美术批次替换。
## 数据驱动，节点独立于 Boss 存在（Boss 死亡/移动后火雨仍持续到时）。

const CELL_SIZE := 64.0
const PLACEHOLDER_COLOR := Color(1.0, 0.45, 0.12, 0.34)
const PLACEHOLDER_EDGE := Color(1.0, 0.62, 0.2, 0.6)

var _cells: Array[Vector2i] = []
var _damage_per_sec := 0.0
var _damage_type := 1
var _tick_interval := 1.0
var _remaining := 0.0
var _tick_timer := 0.0
var _carry := 0.0
var _unit_manager: Node = null
var _map_manager: Node = null


func setup(cells: Array, damage_per_sec: float, damage_type: int, duration: float, tick_interval: float, unit_manager: Node, map_manager: Node) -> void:
	_cells.clear()
	for raw_cell: Variant in cells:
		if raw_cell is Vector2i:
			_cells.append(raw_cell)
	_damage_per_sec = max(damage_per_sec, 0.0)
	_damage_type = damage_type
	_tick_interval = max(tick_interval, 0.1)
	_remaining = max(duration, 0.0)
	_tick_timer = _tick_interval
	_carry = 0.0
	_unit_manager = unit_manager
	_map_manager = map_manager
	z_index = 1
	position = Vector2.ZERO
	queue_redraw()


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		queue_free()
		return
	_remaining -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer += _tick_interval
		_carry += _damage_per_sec * _tick_interval
		var damage := int(floor(_carry))
		if damage > 0:
			_carry -= float(damage)
			_damage_units(damage)
	if _remaining <= 0.0:
		queue_free()


func _damage_units(damage: int) -> void:
	if _unit_manager == null or not _unit_manager.has_method("get_unit_by_cell"):
		return
	for cell in _cells:
		var unit: Node = _unit_manager.get_unit_by_cell(cell)
		if unit != null and is_instance_valid(unit) and unit.has_method("receive_damage"):
			# 不带 source，避免触发单位荆棘反伤的连锁。
			unit.receive_damage(damage, _damage_type, null)


func _draw() -> void:
	if _map_manager == null or not _map_manager.has_method("cell_to_world"):
		return
	var half := Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	for cell in _cells:
		var center: Vector2 = _map_manager.cell_to_world(cell)
		var rect := Rect2(center - half, Vector2(CELL_SIZE, CELL_SIZE))
		draw_rect(rect, PLACEHOLDER_COLOR, true)
		draw_rect(rect, PLACEHOLDER_EDGE, false, 2.0)
