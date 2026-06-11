extends SceneTree

## 动态出怪口 v2 回归：等弧放置 / 激活序 / 覆盖项 / 封口 / 公示冻结。
## 运行：Godot --headless --path . --script scripts/debug/test_spawn_gates_v2.gd

const MapGeneratorScript = preload("res://scripts/map/map_generator.gd")
const ResolverScript = preload("res://scripts/enemy/night_template_resolver.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_arc_placement()
	_test_activation()
	await _test_overrides_lifecycle()
	await _test_active_set_consumption()
	_finish()


func _perimeter_index(cell: Vector2i, width: int, height: int) -> int:
	if cell.y == 0:
		return cell.x
	if cell.x == width - 1:
		return (width - 1) + cell.y
	if cell.y == height - 1:
		return (width - 1) + (height - 1) + (width - 1 - cell.x)
	return (width - 1) * 2 + (height - 1) + (height - 1 - cell.y)


func _test_arc_placement() -> void:
	var cfg := {"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0}
	var perimeter_total: int = (30 - 1) * 4
	for seed_value in range(1000, 1020):
		var generated: Dictionary = MapGeneratorScript.generate(30, 30, seed_value, cfg, [])
		var spawn_cells: Array = generated.get("spawn_cells", [])
		_expect(spawn_cells.size() == 5, "seed %d: 5 gates placed" % seed_value)
		var cells: Dictionary = generated.get("cells", {})
		var indices: Array[int] = []
		for raw_cell: Variant in spawn_cells:
			var cell: Vector2i = raw_cell
			var on_edge := cell.x == 0 or cell.y == 0 or cell.x == 29 or cell.y == 29
			_expect(on_edge, "seed %d: gate on edge" % seed_value)
			var near_corner := (cell.x < 3 or cell.x > 26) and (cell.y < 3 or cell.y > 26)
			_expect(not near_corner, "seed %d: gate away from corners" % seed_value)
			var data: CellData = cells.get(cell)
			_expect(data != null and data.spawn_key != StringName(), "seed %d: gate cell keyed" % seed_value)
			_expect(data != null and not data.discovered and not data.buildable, "seed %d: gate cell invariants" % seed_value)
			indices.append(_perimeter_index(cell, 30, 30))
		indices.sort()
		for i in range(indices.size()):
			var gap: int = 0
			if i + 1 < indices.size():
				gap = indices[i + 1] - indices[i]
			else:
				gap = perimeter_total - indices[i] + indices[0]
			_expect(gap >= 9, "seed %d: perimeter gap %d >= 9" % [seed_value, gap])
	var first: Dictionary = MapGeneratorScript.generate(30, 30, 4242, cfg, [])
	var second: Dictionary = MapGeneratorScript.generate(30, 30, 4242, cfg, [])
	_expect(str(first.get("spawn_cells")) == str(second.get("spawn_cells")), "same seed same gates")


func _test_activation() -> void:
	var gates := ["S1", "S2", "S3", "S4", "S5"]
	var order_a: Array = ResolverScript.resolve_activation_order(gates, 777)
	var order_b: Array = ResolverScript.resolve_activation_order(gates, 777)
	_expect(str(order_a) == str(order_b), "activation order deterministic")
	_expect(order_a.size() == 5, "activation order full permutation")
	var sorted_copy: Array = order_a.duplicate()
	sorted_copy.sort()
	_expect(str(sorted_copy) == str(["S1", "S2", "S3", "S4", "S5"]), "activation order is a permutation")
	var varied := false
	for seed_value in range(50):
		if str(ResolverScript.resolve_activation_order(gates, seed_value)) != str(order_a):
			varied = true
			break
	_expect(varied, "activation order varies across seeds")
	_expect(ResolverScript.active_gate_count_for_day(1) == 2, "day1 count 2")
	_expect(ResolverScript.active_gate_count_for_day(2) == 2, "day2 count 2")
	_expect(ResolverScript.active_gate_count_for_day(3) == 3, "day3 count 3")
	_expect(ResolverScript.active_gate_count_for_day(5) == 4, "day5 count 4")
	_expect(ResolverScript.active_gate_count_for_day(9) == 5, "day9 count 5")
	var prev: Array = []
	for day in range(1, 10):
		var active: Array = ResolverScript.resolve_active_gates(gates, 777, day)
		_expect(active.size() == mini(ResolverScript.active_gate_count_for_day(day), 5), "day %d active size" % day)
		for raw_gate: Variant in prev:
			_expect(active.has(String(raw_gate)), "day %d superset of previous day" % day)
		prev = active
	var with_closed: Array = ResolverScript.resolve_active_gates(gates, 777, 3, [order_a[0]])
	_expect(not with_closed.has(String(order_a[0])), "closed gate excluded")
	_expect(with_closed.size() == 2, "closed shrinks active set")
	var silent_gate := String(order_a[4])
	var with_extra: Array = ResolverScript.resolve_active_gates(gates, 777, 1, [], [silent_gate])
	_expect(with_extra.has(silent_gate), "extra gate included")
	_expect(with_extra.size() == 3, "extra grows active set")
	var all_closed: Array = ResolverScript.resolve_active_gates(gates, 777, 1, gates)
	_expect(all_closed.size() == 1 and String(all_closed[0]) == String(order_a[0]), "min one gate kept (order head)")
	_expect((ResolverScript.resolve_active_gates([], 777, 1) as Array).is_empty(), "empty gates -> empty")


func _test_overrides_lifecycle() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var game_controller := game.get_node_or_null("Managers/GameController")
	_expect(run_state != null and game_controller != null, "boot ok for overrides test")
	if run_state == null or game_controller == null:
		game.queue_free()
		await process_frame
		return
	run_state.add_night_gate_closed("S1")
	run_state.add_night_gate_extra_open("S5")
	run_state.night_gate_seals_today = 1
	_expect((run_state.night_gate_closed_keys as Array).has("S1"), "closed recorded")
	_expect((run_state.night_gate_extra_open_keys as Array).has("S5"), "extra recorded")
	run_state.add_night_gate_closed("S1")
	_expect((run_state.night_gate_closed_keys as Array).size() == 1, "closed deduped")
	game_controller.enter_day(int(run_state.day) + 1)
	_expect((run_state.night_gate_closed_keys as Array).is_empty(), "closed cleared at dawn")
	_expect((run_state.night_gate_extra_open_keys as Array).is_empty(), "extra cleared at dawn")
	_expect(int(run_state.night_gate_seals_today) == 0, "seal counter cleared at dawn")
	game.queue_free()
	await process_frame


func _test_active_set_consumption() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var wave_manager := game.get_node_or_null("Managers/WaveManager")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	_expect(run_state != null and wave_manager != null and map_manager != null, "boot ok for active set test")
	if run_state == null or wave_manager == null or map_manager == null:
		game.queue_free()
		await process_frame
		return
	var all_gates: Array = map_manager.get_spawn_keys()
	_expect(all_gates.size() == 5, "five gates registered")
	var expected: Array = ResolverScript.resolve_active_gates(all_gates, int(run_state.random_seed), int(run_state.day), run_state.night_gate_closed_keys, run_state.night_gate_extra_open_keys)
	_expect(expected.size() == 2, "day1 two active gates")
	var preview: Dictionary = wave_manager.get_night_preview(run_state.night_wave_template_ids, run_state.night_affix_ids)
	var preview_gates: Array = preview.get("active_gates", [])
	_expect(str(preview_gates) == str(expected), "preview exposes active gates")
	for raw_summary: Variant in preview.get("waves", []):
		var summary: Dictionary = raw_summary
		_expect(expected.has(String(summary.get("main_gate", ""))), "main gate within active set")
		for raw_entry: Variant in summary.get("entries", []):
			var entry: Dictionary = raw_entry
			_expect(expected.has(String(entry.get("spawn_key", ""))), "entry gate within active set")
	# 封口后冻结契约：预览与解析共用同一活跃集。
	var victim := String(expected[0])
	run_state.add_night_gate_closed(victim)
	var preview2: Dictionary = wave_manager.get_night_preview(run_state.night_wave_template_ids, run_state.night_affix_ids)
	var gates2: Array = preview2.get("active_gates", [])
	_expect(not gates2.has(victim), "sealed gate absent from preview")
	for raw_summary2: Variant in preview2.get("waves", []):
		var summary2: Dictionary = raw_summary2
		for raw_entry2: Variant in summary2.get("entries", []):
			_expect(String((raw_entry2 as Dictionary).get("spawn_key", "")) != victim, "no entry spawns at sealed gate")
	run_state.clear_night_gate_overrides()
	game.queue_free()
	await process_frame


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("SPAWN GATES V2 TESTS PASSED")
		quit(0)
	else:
		printerr("SPAWN GATES V2 TESTS FAILED: %d" % _failures)
		quit(1)
