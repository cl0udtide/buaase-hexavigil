extends SceneTree

## 地图生成回归（地形包 B1 起建，B2 持续扩展）：
## 噪声决定性 / 种子分流隔离 / 绕路上限修复。
## 运行：Godot --headless --path . --script scripts/debug/test_map_generation.gd

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")
const MapGeneratorScript = preload("res://scripts/map/map_generator.gd")
const CellDataRef = preload("res://scripts/map/cell_data.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_int_noise()
	_test_stage_stream_isolation()
	_test_detour_repair()
	_finish()


func _test_int_noise() -> void:
	_expect(IntNoise.cell_hash(3, 7, 42) == IntNoise.cell_hash(3, 7, 42), "cell_hash deterministic")
	_expect(IntNoise.derive_seed(1234, 0, 2) == IntNoise.derive_seed(1234, 0, 2), "derive_seed deterministic")
	var same_count: int = 0
	for i in range(100):
		if IntNoise.cell_hash(i, 0, 42) == IntNoise.cell_hash(i + 1, 0, 42):
			same_count += 1
	_expect(same_count <= 5, "cell_hash varies across x (same=%d)" % same_count)
	_expect(IntNoise.derive_seed(1234, 0, 1) != IntNoise.derive_seed(1234, 0, 2), "stage ids derive distinct seeds")
	_expect(IntNoise.derive_seed(1234, 0, 1) != IntNoise.derive_seed(1234, 1, 1), "attempts derive distinct seeds")
	_expect(IntNoise.derive_seed(1234, 0, 1) != IntNoise.derive_seed(4321, 0, 1), "run seeds derive distinct seeds")
	for seed_value in [0, 1, -7, 123456789]:
		_expect(IntNoise.derive_seed(seed_value, 2, 3) >= 0, "derive_seed non-negative for %d" % seed_value)
	var min_v: float = 1.0
	var max_v: float = 0.0
	var prev: float = IntNoise.value_noise(0, 5, 42, 8)
	var max_step: float = 0.0
	for x in range(64):
		var v: float = IntNoise.value_noise(x, 5, 42, 8)
		min_v = minf(min_v, v)
		max_v = maxf(max_v, v)
		max_step = maxf(max_step, absf(v - prev))
		prev = v
	_expect(min_v >= 0.0 and max_v < 1.0, "value_noise in [0,1) (min=%f max=%f)" % [min_v, max_v])
	_expect(max_v - min_v > 0.2, "value_noise has variation")
	_expect(max_step < 0.5, "value_noise bilinear smoothness (max_step=%f)" % max_step)
	_expect(absf(IntNoise.value_noise(13, 21, 42, 8) - IntNoise.value_noise(13, 21, 42, 8)) == 0.0, "value_noise deterministic")
	var neg: float = IntNoise.value_noise(-13, -7, 42, 8)
	_expect(neg >= 0.0 and neg < 1.0, "value_noise handles negative coords (v=%f)" % neg)
	_expect(absf(IntNoise.value_noise(-13, -7, 42, 8) - neg) == 0.0, "negative coords deterministic")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _serialize_terrain(generated: Dictionary) -> String:
	var cells: Dictionary = generated.get("cells", {})
	var keys: Array = cells.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for raw_key: Variant in keys:
		var data: CellData = cells[raw_key]
		parts.append("%s:%s:%s" % [str(raw_key), String(data.terrain), String(data.resource_type)])
	return "|".join(parts)


func _serialize_obstacles_only(generated: Dictionary) -> String:
	var cells: Dictionary = generated.get("cells", {})
	var keys: Array = cells.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for raw_key: Variant in keys:
		var data: CellData = cells[raw_key]
		if data.terrain != CellDataRef.TERRAIN_PLAIN:
			parts.append("%s:%s" % [str(raw_key), String(data.terrain)])
	return "|".join(parts)


func _serialize_resources_only(generated: Dictionary) -> String:
	var cells: Dictionary = generated.get("cells", {})
	var keys: Array = cells.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for raw_key: Variant in keys:
		var data: CellData = cells[raw_key]
		if data.resource_type != StringName():
			parts.append("%s:%s" % [str(raw_key), String(data.resource_type)])
	return "|".join(parts)


func _test_stage_stream_isolation() -> void:
	var base_cfg := {"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0}
	var a: Dictionary = MapGeneratorScript.generate(30, 30, 9001, base_cfg, [])
	var b: Dictionary = MapGeneratorScript.generate(30, 30, 9001, base_cfg, [])
	_expect(_serialize_terrain(a) == _serialize_terrain(b), "same seed same map (full determinism)")
	var c: Dictionary = MapGeneratorScript.generate(30, 30, 9002, base_cfg, [])
	_expect(_serialize_terrain(a) != _serialize_terrain(c), "different seed different map")
	# 流隔离：只改资源参数，出怪口与障碍布局不得变化。
	var resource_cfg := {"spawn_count": 5, "resources_per_type": 8, "event_point_count": 0}
	var d: Dictionary = MapGeneratorScript.generate(30, 30, 9001, resource_cfg, [])
	_expect(str(a.get("spawn_cells")) == str(d.get("spawn_cells")), "resource cfg change keeps spawn placement")
	_expect(_serialize_obstacles_only(a) == _serialize_obstacles_only(d), "resource cfg change keeps obstacle layout")
	# 流隔离反向：只改障碍参数，但固定障碍为 0 以保持 terrain 候选集一致，
	# 验证 water_obstacle_chance 不同时资源布局相同（RNG 流独立，输入候选集也一致）。
	var no_obstacles_base := {
		"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0,
		"min_obstacle_count": 0, "max_obstacle_count": 0, "water_obstacle_chance": 0.35
	}
	var no_obstacles_alt := {
		"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0,
		"min_obstacle_count": 0, "max_obstacle_count": 0, "water_obstacle_chance": 0.0
	}
	var e: Dictionary = MapGeneratorScript.generate(30, 30, 9001, no_obstacles_base, [])
	var f: Dictionary = MapGeneratorScript.generate(30, 30, 9001, no_obstacles_alt, [])
	_expect(str(e.get("spawn_cells")) == str(f.get("spawn_cells")), "obstacle cfg change keeps spawn placement")
	_expect(_serialize_resources_only(e) == _serialize_resources_only(f), "obstacle cfg change keeps resource layout (no-obstacle baseline)")


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _bfs_path_length(cells: Dictionary, width: int, height: int, from_cell: Vector2i, to_cell: Vector2i) -> int:
	var queue: Array[Vector2i] = [from_cell]
	var dist: Dictionary = {from_cell: 0}
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == to_cell:
			return int(dist[current])
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var neighbor: Vector2i = current + direction
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			if dist.has(neighbor):
				continue
			var data: CellData = cells.get(neighbor)
			if data == null or not data.walkable:
				continue
			dist[neighbor] = int(dist[current]) + 1
			queue.append(neighbor)
	return -1


func _test_detour_repair() -> void:
	var cfg := {
		"spawn_count": 5,
		"resources_per_type": 12,
		"event_point_count": 0,
		"obstacle_ratio": 0.24,
		"min_obstacle_count": 190,
		"max_obstacle_count": 220,
		"detour_cap": 1.6,
		"max_repair_rounds": 3,
	}
	var worst_ratio: float = 0.0
	for seed_value in range(7000, 7015):
		var generated: Dictionary = MapGeneratorScript.generate(30, 30, seed_value, cfg, [])
		var cells: Dictionary = generated.get("cells", {})
		var core_cell: Vector2i = generated.get("core_cell", Vector2i.ZERO)
		for raw_spawn: Variant in generated.get("spawn_cells", []):
			var spawn_cell: Vector2i = raw_spawn
			var path_len: int = _bfs_path_length(cells, 30, 30, spawn_cell, core_cell)
			_expect(path_len > 0, "seed %d: gate connected" % seed_value)
			if path_len <= 0:
				continue
			var ratio: float = float(path_len) / float(maxi(_manhattan(spawn_cell, core_cell), 1))
			worst_ratio = maxf(worst_ratio, ratio)
			_expect(ratio <= 1.6 + 0.0001, "seed %d: detour ratio %.3f <= 1.6" % [seed_value, ratio])
	print("  detour worst ratio: %.3f" % worst_ratio)
	var a: Dictionary = MapGeneratorScript.generate(30, 30, 7000, cfg, [])
	var b: Dictionary = MapGeneratorScript.generate(30, 30, 7000, cfg, [])
	_expect(_serialize_terrain(a) == _serialize_terrain(b), "repair keeps determinism")


func _finish() -> void:
	if _failures == 0:
		print("MAP GENERATION TESTS PASSED")
		quit(0)
	else:
		printerr("MAP GENERATION TESTS FAILED: %d" % _failures)
		quit(1)
