extends SceneTree

## 夜晚出怪机制 · 九天三幕重构 回归测试。
## 设计见 docs/superpowers/specs/2026-06-13-night-spawn-9day-rework-design.md。
## 随各步实现逐步补充断言；当前覆盖：第 1 步 DifficultyScale 全局强度系数。

const DifficultyScale = preload("res://scripts/enemy/difficulty_scale.gd")

var _failures: int = 0


func _init() -> void:
	_test_count_scale()
	_test_stat_scale()
	_test_boss_stat_scale()
	_test_scaled_count()
	_test_apply_stat_scale()
	_test_stat_scale_for_enemy()
	if _failures == 0:
		print("NIGHT SPAWN REWORK TESTS PASSED")
		quit(0)
	else:
		printerr("NIGHT SPAWN REWORK TESTS FAILED: %d" % _failures)
		quit(1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _expect_approx(a: float, b: float, msg: String) -> void:
	_expect(is_equal_approx(a, b), "%s (got %f, want %f)" % [msg, a, b])


func _test_count_scale() -> void:
	# 九天数量系数：前期 <1 压人数，后期 >1。
	var expected := {1: 0.6, 2: 0.8, 3: 0.9, 4: 1.0, 5: 1.1, 6: 1.0, 7: 1.2, 8: 1.3, 9: 1.1}
	for day in expected:
		_expect_approx(DifficultyScale.count_scale_for_day(day), float(expected[day]), "count_scale day %d" % day)
	# 阶梯回退：超过 9 天取第 9 天值。
	_expect_approx(DifficultyScale.count_scale_for_day(12), 1.1, "count_scale fallback >9 -> day9")


func _test_stat_scale() -> void:
	# 九天数值系数：单调上升，后期追上玩家复利。
	var expected := {1: 1.0, 2: 1.0, 3: 1.05, 4: 1.1, 5: 1.2, 6: 1.3, 7: 1.45, 8: 1.6, 9: 1.8}
	for day in expected:
		_expect_approx(DifficultyScale.stat_scale_for_day(day), float(expected[day]), "stat_scale day %d" % day)
	_expect_approx(DifficultyScale.stat_scale_for_day(20), 1.8, "stat_scale fallback >9 -> day9")


func _test_boss_stat_scale() -> void:
	# Boss 独立曲线，d3=1.0 下限，越晚越强。
	_expect_approx(DifficultyScale.boss_stat_scale_for_day(3), 1.0, "boss scale d3")
	_expect_approx(DifficultyScale.boss_stat_scale_for_day(6), 1.5, "boss scale d6")
	_expect_approx(DifficultyScale.boss_stat_scale_for_day(9), 2.2, "boss scale d9")
	# 阶梯回退：非幕末天取 <= day 最大键；早于第一只 boss 时回退默认 1.0。
	_expect_approx(DifficultyScale.boss_stat_scale_for_day(4), 1.0, "boss scale d4 -> key3")
	_expect_approx(DifficultyScale.boss_stat_scale_for_day(7), 1.5, "boss scale d7 -> key6")
	_expect_approx(DifficultyScale.boss_stat_scale_for_day(1), 1.0, "boss scale d1 -> default")


func _test_scaled_count() -> void:
	_expect(DifficultyScale.scaled_count(10, 0.6) == 6, "scaled_count 10*0.6 = 6 (ceil)")
	_expect(DifficultyScale.scaled_count(5, 1.1) == 6, "scaled_count 5*1.1 = 6 (ceil 5.5)")
	_expect(DifficultyScale.scaled_count(1, 1.3) == 2, "scaled_count 1*1.3 = 2")
	_expect(DifficultyScale.scaled_count(1, 0.6) == 1, "scaled_count 1*0.6 floored to 1")


func _test_apply_stat_scale() -> void:
	var cfg := {"max_hp": 100, "atk": 50, "def": 20, "res": 10, "move_speed": 1.0}
	DifficultyScale.apply_stat_scale(cfg, 1.5)
	_expect(int(cfg["max_hp"]) == 150, "scale max_hp 100*1.5 = 150")
	_expect(int(cfg["atk"]) == 75, "scale atk 50*1.5 = 75")
	_expect(int(cfg["def"]) == 30, "scale def 20*1.5 = 30")
	_expect(int(cfg["res"]) == 15, "scale res 10*1.5 = 15")
	_expect_approx(float(cfg["move_speed"]), 1.0, "move_speed not scaled")
	# scale=1.0 不动；缺失字段不报错。
	var cfg2 := {"max_hp": 80}
	DifficultyScale.apply_stat_scale(cfg2, 1.0)
	_expect(int(cfg2["max_hp"]) == 80, "scale 1.0 leaves max_hp")
	DifficultyScale.apply_stat_scale(cfg2, 2.0)
	_expect(int(cfg2["max_hp"]) == 160, "missing atk/def/res not crash; max_hp 80*2 = 160")
	# max_hp 下限 1。
	var cfg3 := {"max_hp": 1}
	DifficultyScale.apply_stat_scale(cfg3, 0.01)
	_expect(int(cfg3["max_hp"]) >= 1, "max_hp floor 1")


func _test_stat_scale_for_enemy() -> void:
	var boss_cfg := {"behavior_type": "boss"}
	var normal_cfg := {"behavior_type": "normal"}
	_expect(DifficultyScale.is_boss_cfg(boss_cfg), "is_boss_cfg true")
	_expect(not DifficultyScale.is_boss_cfg(normal_cfg), "is_boss_cfg false")
	# 同一天：Boss 走 boss 曲线，杂兵走 stat 曲线。
	_expect_approx(DifficultyScale.stat_scale_for_enemy(boss_cfg, 6), 1.5, "boss enemy d6 -> boss scale")
	_expect_approx(DifficultyScale.stat_scale_for_enemy(normal_cfg, 6), 1.3, "normal enemy d6 -> stat scale")
