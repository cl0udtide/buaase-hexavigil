extends Node2D

## 地面持续危险区（凑凑企鹅 P2 火雨）：覆盖若干格，每 tick 对站其上的我方单位造成 DOT。
## 有特效贴图时按格渲染循环序列帧；否则回退半透明占位格。
## permanent=true 时不计时，战斗结束（场上无敌人）才清理，避免跨夜/沙盒重置残留。

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
var _enemy_manager: Node = null
var _permanent := false

var _fire_sprites: Array[Sprite2D] = []
var _effect_frames := 1
var _effect_fps := 10.0
var _anim_elapsed := 0.0


func setup(cells: Array, damage_per_sec: float, damage_type: int, duration: float, tick_interval: float, unit_manager: Node, map_manager: Node, permanent: bool = false, enemy_manager: Node = null, effect_path: String = "", effect_frames: int = 6, effect_fps: float = 10.0) -> void:
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
	_enemy_manager = enemy_manager
	_permanent = permanent
	_effect_frames = maxi(effect_frames, 1)
	_effect_fps = maxf(effect_fps, 1.0)
	z_index = 1
	position = Vector2.ZERO
	_build_fire_sprites(effect_path)
	queue_redraw()


## 有特效图时按格生成循环火焰 sprite；空路径回退占位 _draw。
func _build_fire_sprites(effect_path: String) -> void:
	for s in _fire_sprites:
		if is_instance_valid(s):
			s.queue_free()
	_fire_sprites.clear()
	if effect_path.is_empty() or not ResourceLoader.exists(effect_path):
		return
	var tex := load(effect_path) as Texture2D
	if tex == null or _map_manager == null or not _map_manager.has_method("cell_to_world"):
		return
	var frame_h := float(tex.get_height())
	var scale_factor := (CELL_SIZE * 1.15) / maxf(frame_h, 1.0)
	for cell in _cells:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.hframes = _effect_frames
		sprite.vframes = 1
		sprite.centered = true
		sprite.scale = Vector2.ONE * scale_factor
		# 火焰底部对齐格子中心略下、向上燃烧。
		sprite.position = _map_manager.cell_to_world(cell) - Vector2(0.0, frame_h * scale_factor * 0.25)
		sprite.z_index = 1
		add_child(sprite)
		_fire_sprites.append(sprite)


func _process(delta: float) -> void:
	if _permanent:
		# 永久火雨：不计时，战斗结束（场上无敌人）才清理。
		if _enemy_manager == null or not is_instance_valid(_enemy_manager) or (_enemy_manager.has_method("get_alive_enemy_count") and int(_enemy_manager.get_alive_enemy_count()) <= 0):
			queue_free()
			return
	else:
		if _remaining <= 0.0:
			queue_free()
			return
		_remaining -= delta
	_advance_fire_anim(delta)
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer += _tick_interval
		_carry += _damage_per_sec * _tick_interval
		var damage := int(floor(_carry))
		if damage > 0:
			_carry -= float(damage)
			_damage_units(damage)
	if not _permanent and _remaining <= 0.0:
		queue_free()


func _advance_fire_anim(delta: float) -> void:
	if _fire_sprites.is_empty():
		return
	_anim_elapsed += delta
	var frame := int(_anim_elapsed * _effect_fps) % _effect_frames
	for s in _fire_sprites:
		if is_instance_valid(s):
			s.frame = frame


func _damage_units(damage: int) -> void:
	if _unit_manager == null or not _unit_manager.has_method("get_unit_by_cell"):
		return
	for cell in _cells:
		var unit: Node = _unit_manager.get_unit_by_cell(cell)
		if unit != null and is_instance_valid(unit) and unit.has_method("receive_damage"):
			# 不带 source，避免触发单位荆棘反伤的连锁。
			unit.receive_damage(damage, _damage_type, null)


func _draw() -> void:
	if not _fire_sprites.is_empty():
		return  # 有火焰贴图时不画占位格
	if _map_manager == null or not _map_manager.has_method("cell_to_world"):
		return
	var half := Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	for cell in _cells:
		var center: Vector2 = _map_manager.cell_to_world(cell)
		var rect := Rect2(center - half, Vector2(CELL_SIZE, CELL_SIZE))
		draw_rect(rect, PLACEHOLDER_COLOR, true)
		draw_rect(rect, PLACEHOLDER_EDGE, false, 2.0)
