extends SceneTree

## 夜晚多波计划 + 夜晚词缀的 headless 回归：
## 运行：Godot --headless --path . --script scripts/debug/test_night_waves_affixes.gd

const Resolver = preload("res://scripts/enemy/night_template_resolver.gd")
const AffixService = preload("res://scripts/enemy/night_affix_service.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_resolver_plan()
	_test_gate_assignment()
	_test_affix_resolution()
	_test_affix_enemy_cfg()
	_test_affix_entries()
	await _test_game_boot()
	_finish()


func _test_resolver_plan() -> void:
	_expect(Resolver.wave_tiers_for_day(1).size() == 1, "day1 has 1 wave")
	_expect(Resolver.wave_tiers_for_day(2) == ([&"early", &"early"] as Array[StringName]), "day2 tiers early x2")
	_expect(Resolver.wave_tiers_for_day(5).size() == 3, "day5 has 3 waves")
	_expect(Resolver.wave_tiers_for_day(6) == ([&"late", &"boss"] as Array[StringName]), "day6 ends with boss")
	_expect(Resolver.wave_tiers_for_day(9).size() == 2, "day beyond table falls back to default")
	_expect(Resolver.tier_for_day(6) == &"late", "tier_for_day keeps first-wave compat")

	var pools := {
		&"early": [&"e1", &"e2", &"e3"],
		&"mid": [&"m1", &"m2"],
		&"late": [&"l1", &"l2"],
		&"boss": [&"b1"],
	}
	var plan_a: Array[StringName] = Resolver.resolve_night_plan(pools, [], 42, 2)
	var plan_b: Array[StringName] = Resolver.resolve_night_plan(pools, [], 42, 2)
	_expect(plan_a.size() == 2, "day2 plan has 2 waves")
	_expect(plan_a == plan_b, "plan resolution is deterministic")
	_expect(plan_a.size() == 2 and plan_a[0] != plan_a[1], "same-night waves are distinct")
	var used: Array = [plan_a[0]]
	var plan_c: Array[StringName] = Resolver.resolve_night_plan(pools, used, 42, 2)
	_expect(not plan_c.has(plan_a[0]), "used templates are excluded while pool lasts")
	var boss_plan: Array[StringName] = Resolver.resolve_night_plan(pools, [], 42, 6)
	_expect(boss_plan.size() == 2 and boss_plan[1] == &"b1", "day6 plan ends with boss template")


func _test_gate_assignment() -> void:
	var gates: Array = ["S1", "S2", "S3"]
	var main_a: String = Resolver.resolve_main_gate(gates, 42, 3, 0)
	var main_b: String = Resolver.resolve_main_gate(gates, 42, 3, 0)
	_expect(main_a == main_b, "main gate is deterministic")
	_expect(gates.has(main_a), "main gate is an active gate")
	var main_wave1: String = Resolver.resolve_main_gate(gates, 42, 3, 1)
	_expect(gates.has(main_wave1), "wave1 main gate is an active gate")
	# 不同 seed 下主攻口应该会变（扫几个 seed 至少出现两种结果）
	var seen: Dictionary = {}
	for probe_seed in range(20):
		seen[Resolver.resolve_main_gate(gates, probe_seed, 3, 0)] = true
	_expect(seen.size() >= 2, "main gate varies across seeds")

	_expect(Resolver.resolve_lane_gate(&"main", 0, main_a, gates, 42, 3, 0) == main_a, "lane main goes to main gate")
	var seen_flank: Dictionary = {}
	for group_index in range(8):
		var flank_gate: String = Resolver.resolve_lane_gate(&"flank", group_index, main_a, gates, 42, 3, 0)
		seen_flank[flank_gate] = true
		_expect(flank_gate != main_a, "flank avoids main gate (group %d)" % group_index)
		_expect(gates.has(flank_gate), "flank gate is active (group %d)" % group_index)
		var any_gate: String = Resolver.resolve_lane_gate(&"any", group_index, main_a, gates, 42, 3, 0)
		_expect(gates.has(any_gate), "any gate is active (group %d)" % group_index)
	_expect(seen_flank.size() >= 2, "flank gate varies across groups")
	_expect(Resolver.resolve_lane_gate(&"flank", 0, main_a, gates, 42, 3, 0) == Resolver.resolve_lane_gate(&"flank", 0, main_a, gates, 42, 3, 0), "flank assignment deterministic")
	# 单口回退
	_expect(Resolver.resolve_lane_gate(&"flank", 0, "S1", ["S1"], 42, 3, 0) == "S1", "flank falls back to main when single gate")
	# 空口集合
	_expect(Resolver.resolve_main_gate([], 42, 3, 0) == "", "empty gates yield empty main")
	# 顺序无关
	_expect(Resolver.resolve_main_gate(["S3", "S1", "S2"], 42, 3, 0) == main_a, "gate order does not affect result")


func _test_affix_resolution() -> void:
	_expect(AffixService.affix_count_for_day(1) == 0, "day1 has no affix")
	_expect(AffixService.affix_count_for_day(4) == 2, "day4 has 2 affixes")
	var cfgs: Array = [
		{"id": "a_early", "min_day": 2, "weight": 10},
		{"id": "b_early", "min_day": 2, "weight": 10},
		{"id": "c_late", "min_day": 4, "weight": 10},
	]
	_expect(AffixService.resolve_affixes_for_day(7, 1, cfgs).is_empty(), "day1 resolves no affix")
	var day2: Array[StringName] = AffixService.resolve_affixes_for_day(7, 2, cfgs)
	_expect(day2.size() == 1, "day2 resolves 1 affix")
	_expect(day2 == AffixService.resolve_affixes_for_day(7, 2, cfgs), "affix resolution is deterministic")
	_expect(not day2.has(&"c_late"), "min_day gates affixes")
	var day4: Array[StringName] = AffixService.resolve_affixes_for_day(7, 4, cfgs)
	_expect(day4.size() == 2 and day4[0] != day4[1], "day4 resolves 2 distinct affixes")


func _test_affix_enemy_cfg() -> void:
	var forced_march := {"effects": [
		{"type": "enemy_stat_percent", "stat": "move_speed", "value": 0.30},
		{"type": "enemy_stat_percent", "stat": "max_hp", "value": -0.20},
	]}
	var cfg: Dictionary = AffixService.apply_to_enemy_cfg({"max_hp": 100, "move_speed": 1.0}, [forced_march])
	_expect(int(cfg.get("max_hp", 0)) == 80, "forced_march reduces hp to 80")
	_expect(is_equal_approx(float(cfg.get("move_speed", 0.0)), 1.3), "forced_march speeds up to 1.3")

	var heavy := {"effects": [{"type": "enemy_stat_percent", "stat": "def", "value": 0.30, "min_def": 20}]}
	_expect(int(AffixService.apply_to_enemy_cfg({"def": 22}, [heavy]).get("def", 0)) == 29, "heavy_advance buffs armored def")
	_expect(int(AffixService.apply_to_enemy_cfg({"def": 10}, [heavy]).get("def", 0)) == 10, "heavy_advance skips light enemies")

	var bloodlust := {"effects": [
		{"type": "enemy_stat_percent", "stat": "atk", "value": 0.15},
		{"type": "enemy_stat_percent", "stat": "prestige_reward", "value": 0.30},
	]}
	var bl_cfg: Dictionary = AffixService.apply_to_enemy_cfg({"atk": 20, "prestige_reward": 10}, [bloodlust])
	_expect(int(bl_cfg.get("atk", 0)) == 23, "bloodlust buffs atk")
	_expect(int(bl_cfg.get("prestige_reward", 0)) == 13, "bloodlust raises prestige reward")

	var deathweave := {"effects": [{"type": "death_effect_percent", "value": 0.50, "spawn_add": 1}]}
	var dw_cfg: Dictionary = AffixService.apply_to_enemy_cfg({
		"death_area_damage": {"radius": 1, "damage": 38, "damage_type": "magic"},
		"death_spawn": [{"enemy_id": "slime", "count": 2, "radius": 1}],
	}, [deathweave])
	_expect(int((dw_cfg.get("death_area_damage", {}) as Dictionary).get("damage", 0)) == 57, "deathweave scales death damage")
	var dw_spawns: Array = dw_cfg.get("death_spawn", [])
	_expect(int((dw_spawns[0] as Dictionary).get("count", 0)) == 3, "deathweave adds split count")

	var arcane := {"effects": [{"type": "enemy_stat_add", "stat": "res", "value": 20}]}
	_expect(int(AffixService.apply_to_enemy_cfg({"res": 0}, [arcane]).get("res", -1)) == 20, "arcane_tide adds res")


func _test_affix_entries() -> void:
	var base_entries: Array = [
		{"time": 0.0, "enemy_id": "hound", "spawn_key": "S1", "count": 4, "interval": 0.5},
		{"time": 3.0, "enemy_id": "soldier", "spawn_key": "S2", "count": 4, "interval": 0.8},
	]
	var air_raid := {"effects": [{"type": "extra_squad", "enemy_id": "bat", "count": 4, "interval": 0.7, "time_offset": 6.0}]}
	var with_squad: Array[Dictionary] = AffixService.transform_entries(base_entries, [air_raid], ["S1", "S2"], 99)
	_expect(with_squad.size() == 3, "air_raid appends a squad entry")
	_expect(String(with_squad[2].get("enemy_id", "")) == "bat", "appended squad is flying unit")
	_expect(int(with_squad[2].get("count", 0)) == 4, "appended squad count")

	var surge := {"effects": [{"type": "spawn_redistribute", "surge_multiplier": 2.0, "other_multiplier": 0.5}]}
	var surged: Array[Dictionary] = AffixService.transform_entries(base_entries, [surge], ["S1", "S2"], 99)
	var counts: Array[int] = [int(surged[0].get("count", 0)), int(surged[1].get("count", 0))]
	counts.sort()
	_expect(counts == ([2, 8] as Array[int]), "spawn_surge doubles one gate and halves the other")
	var surged_again: Array[Dictionary] = AffixService.transform_entries(base_entries, [surge], ["S1", "S2"], 99)
	_expect(int(surged_again[0].get("count", 0)) == int(surged[0].get("count", 0)), "entry transform is deterministic")
	var tiny: Array[Dictionary] = AffixService.transform_entries([{"time": 0.0, "enemy_id": "hound", "spawn_key": "S1", "count": 1, "interval": 0.5}], [surge], ["S1", "S2"], 1)
	_expect(int(tiny[0].get("count", 0)) >= 1, "redistribute keeps at least 1 enemy")


func _test_game_boot() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	_expect(game_scene != null, "load Game scene")
	if game_scene == null:
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame

	var run_state = root.get_node_or_null("RunState")
	_expect(run_state != null, "RunState exists")
	var wave_manager := game.get_node_or_null("Managers/WaveManager")
	_expect(wave_manager != null, "WaveManager exists")
	if run_state != null and wave_manager != null:
		var plan: Array = run_state.night_wave_template_ids
		_expect(plan.size() == 1, "day1 plan has exactly 1 wave")
		_expect(StringName(run_state.night_template_id) == StringName(plan[0]) if not plan.is_empty() else false, "compat template id equals first wave")
		_expect((run_state.night_affix_ids as Array).is_empty(), "day1 has no affixes")

		var preview: Dictionary = wave_manager.get_night_preview(plan, run_state.night_affix_ids)
		_expect(not preview.is_empty(), "night preview exists")
		_expect(int(preview.get("total_count", 0)) > 0, "night preview total count")
		_expect(int(preview.get("wave_count", 0)) == 1, "night preview wave count")

		var late_plan: Array[StringName] = wave_manager.resolve_night_plan(int(run_state.random_seed), 5, [])
		_expect(late_plan.size() == 3, "day5 resolves 3 waves")
		var affixed_preview: Dictionary = wave_manager.get_night_preview(late_plan, [&"forced_march", &"spawn_surge"])
		_expect((affixed_preview.get("affixes", []) as Array).size() == 2, "preview discloses affixes")
		_expect(int(affixed_preview.get("wave_count", 0)) == 3, "multi-wave preview wave count")
		_expect(int(affixed_preview.get("total_count", 0)) > 0, "multi-wave preview total count")
		var data_repo = root.get_node_or_null("DataRepo")
		_expect(data_repo != null and not data_repo.get_night_affix_cfg(&"forced_march").is_empty(), "DataRepo loads night affixes")

		# --- 动态出怪口 v1：预览暴露 per-wave 主攻口与条目 ---
		var preview_repeat: Dictionary = wave_manager.get_night_preview(late_plan, [&"forced_march", &"spawn_surge"])
		_expect(str(preview_repeat) == str(affixed_preview), "night preview fully deterministic")
		var wave_infos: Array = affixed_preview.get("waves", [])
		_expect(not wave_infos.is_empty(), "preview has wave summaries")
		var active_gate_keys: Array = []
		var map_manager := game.get_node_or_null("Managers/MapManager")
		_expect(map_manager != null, "MapManager exists")
		if map_manager != null and map_manager.has_method("get_spawn_keys"):
			active_gate_keys = map_manager.get_spawn_keys()
		_expect(active_gate_keys.size() >= 2, "map exposes spawn keys")
		for raw_wave: Variant in wave_infos:
			if typeof(raw_wave) != TYPE_DICTIONARY:
				continue
			var wave_info: Dictionary = raw_wave
			var main_gate := String(wave_info.get("main_gate", ""))
			_expect(active_gate_keys.has(main_gate), "wave main gate is active gate")
			var wave_entries: Array = wave_info.get("entries", [])
			_expect(not wave_entries.is_empty(), "wave summary carries entries")
			for raw_entry: Variant in wave_entries:
				if typeof(raw_entry) != TYPE_DICTIONARY:
					continue
				var wave_entry: Dictionary = raw_entry
				_expect(active_gate_keys.has(String(wave_entry.get("spawn_key", ""))), "entry spawn key is active gate")
				if StringName(wave_entry.get("lane", "")) == &"flank" and active_gate_keys.size() >= 2:
					_expect(String(wave_entry.get("spawn_key", "")) != main_gate, "flank entry avoids main gate")

		# --- 标记穿透迷雾：格子保持未探索（探索约束与事件前沿落点依赖此不变式） ---
		if map_manager != null and map_manager.has_method("get_spawn_cells"):
			var spawn_cells: Array = map_manager.get_spawn_cells()
			_expect(not spawn_cells.is_empty(), "map has spawn cells")
			for raw_cell: Variant in spawn_cells:
				var spawn_cell: Vector2i = raw_cell
				_expect(not map_manager.is_discovered(spawn_cell), "spawn cell stays undiscovered at start")

	game.queue_free()
	await process_frame


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("NIGHT WAVES AFFIXES TESTS PASSED")
		quit(0)
	else:
		printerr("NIGHT WAVES AFFIXES TESTS FAILED: %d" % _failures)
		quit(1)
