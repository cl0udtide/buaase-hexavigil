extends SceneTree

## 地图生成回归（地形包 B1 起建，B2 持续扩展）：
## 噪声决定性 / 种子分流隔离 / 绕路上限修复。
## 运行：Godot --headless --path . --script scripts/debug/test_map_generation.gd

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")
const MapGeneratorScript = preload("res://scripts/map/map_generator.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_int_noise()
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
	var prev: float = IntNoise.value_noise(0, 0, 42, 8)
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


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("MAP GENERATION TESTS PASSED")
		quit(0)
	else:
		printerr("MAP GENERATION TESTS FAILED: %d" % _failures)
		quit(1)
