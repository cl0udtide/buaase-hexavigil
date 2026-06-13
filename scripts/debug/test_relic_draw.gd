extends SceneTree

## 遗物池重写（稀有度门控 + 分槽软导向 + 盟约过滤）的 headless 回归：
## 运行：Godot --headless --path . --script scripts/debug/test_relic_draw.gd

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	_expect(game_scene != null, "load Game scene")
	if game_scene == null:
		_finish()
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame

	var run_state = root.get_node_or_null("RunState")
	var data_repo = root.get_node_or_null("DataRepo")
	var buff_manager := game.get_node_or_null("Managers/BuffManager")
	_expect(run_state != null and data_repo != null and buff_manager != null, "core singletons exist")
	if run_state == null or data_repo == null or buff_manager == null:
		_finish()
		return

	_test_pool_data(data_repo)
	_test_rarity_gating(run_state, buff_manager)
	_test_economy_slot(run_state, buff_manager, data_repo)
	_test_covenant_slot(run_state, buff_manager, data_repo)
	_test_covenant_filter(run_state, data_repo)

	game.queue_free()
	await process_frame
	_finish()


func _test_pool_data(data_repo: Node) -> void:
	var ids: Array[StringName] = data_repo.get_all_buff_ids()
	_expect(ids.size() >= 30, "pool has at least 30 relics")
	var has_rarity_1 := false
	for buff_id in ids:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
		_expect(cfg.has("category"), "relic %s has category" % buff_id)
		if int(cfg.get("rarity", 0)) == 1:
			has_rarity_1 = true
	_expect(has_rarity_1, "pool has common relics")


func _test_rarity_gating(run_state: Node, buff_manager: Node) -> void:
	run_state.day = 1
	var data_repo = root.get_node_or_null("DataRepo")
	for _round in range(5):
		var choices: Array[StringName] = buff_manager.get_random_blessing_choices()
		_expect(choices.size() == 3, "day1 draw has 3 choices")
		var distinct: Dictionary = {}
		for buff_id in choices:
			distinct[buff_id] = true
			var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
			_expect(int(cfg.get("rarity", 0)) == 1, "day1 choice %s is common" % buff_id)
		_expect(distinct.size() == choices.size(), "choices are distinct")
	run_state.day = 7
	for _round in range(5):
		for buff_id in buff_manager.get_random_blessing_choices():
			var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
			_expect(int(cfg.get("rarity", 0)) >= 2, "day7 (act3) choice %s is rare or legendary" % buff_id)
	run_state.day = 1


func _test_economy_slot(run_state: Node, buff_manager: Node, data_repo: Node) -> void:
	run_state.day = 3
	for _round in range(5):
		var has_economy_or_generic := false
		for buff_id in buff_manager.get_random_blessing_choices():
			var category := StringName((data_repo.get_buff_cfg(buff_id) as Dictionary).get("category", ""))
			if category == &"economy" or category == &"generic":
				has_economy_or_generic = true
		_expect(has_economy_or_generic, "draw contains an economy/generic fallback slot")
	run_state.day = 1


func _test_covenant_slot(run_state: Node, buff_manager: Node, data_repo: Node) -> void:
	# 拥有两名坚守干员（去重计数 2）→ 盟约槽应稳定供应坚守钥匙件（rarity 2 需第 4 天起=第二幕）。
	run_state.add_owned_operator(&"defender_t1", "测试森蚺")
	run_state.add_owned_operator(&"penance", "测试斥罪")
	run_state.day = 4
	var found_steadfast_key := false
	for _round in range(10):
		for buff_id in buff_manager.get_random_blessing_choices():
			var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
			if StringName(cfg.get("category", "")) == &"covenant":
				_expect(StringName(cfg.get("covenant", "")) == &"坚守", "covenant slot only offers present covenants")
				found_steadfast_key = true
	_expect(found_steadfast_key, "covenant key relic appears when covenant presence >= 2")
	run_state.day = 1


func _test_covenant_filter(run_state: Node, data_repo: Node) -> void:
	run_state.add_buff(&"relic_cov_steadfast")
	var steadfast_cfg: Dictionary = data_repo.get_unit_cfg(&"defender_t1")
	var other_cfg: Dictionary = data_repo.get_unit_cfg(&"sniper_t1")
	_expect(is_equal_approx(float(run_state.get_buff_effect_total_for_unit(&"unit_def_percent", steadfast_cfg)), 0.40), "covenant relic buffs covenant unit")
	_expect(is_zero_approx(float(run_state.get_buff_effect_total_for_unit(&"unit_def_percent", other_cfg))), "covenant relic skips other units")
	_expect(is_zero_approx(float(run_state.get_buff_effect_total(&"unit_def_percent"))), "unfiltered total skips covenant-filtered effects")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("RELIC DRAW TESTS PASSED")
		quit(0)
	else:
		printerr("RELIC DRAW TESTS FAILED: %d" % _failures)
		quit(1)
