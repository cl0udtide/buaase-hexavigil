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
	await _test_player_seal()
	await _test_gate_events()
	await _test_markers()
	await _test_gate_ui()
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
	_expect(ResolverScript.active_gate_count_for_day(3) == 2, "day3 count 2")
	_expect(ResolverScript.active_gate_count_for_day(4) == 3, "day4 count 3")
	_expect(ResolverScript.active_gate_count_for_day(6) == 4, "day6 count 4")
	_expect(ResolverScript.active_gate_count_for_day(8) == 5, "day8 count 5")
	_expect(ResolverScript.active_gate_count_for_day(9) == 5, "day9 count 5 (cap)")
	var prev: Array = []
	for day in range(1, 10):
		var active: Array = ResolverScript.resolve_active_gates(gates, 777, day)
		_expect(active.size() == mini(ResolverScript.active_gate_count_for_day(day), 5), "day %d active size" % day)
		for raw_gate: Variant in prev:
			_expect(active.has(String(raw_gate)), "day %d superset of previous day" % day)
		prev = active
	var with_closed: Array = ResolverScript.resolve_active_gates(gates, 777, 3, [order_a[0]])
	_expect(not with_closed.has(String(order_a[0])), "closed gate excluded")
	_expect(with_closed.size() == 1, "closed shrinks active set (day3 act1=2, -1=1)")
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


func _test_player_seal() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var day_manager := game.get_node_or_null("Managers/DayManager")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	if run_state == null or day_manager == null or map_manager == null:
		_expect(false, "boot ok for seal test")
		game.queue_free()
		await process_frame
		return
	var all_gates: Array = map_manager.get_spawn_keys()
	var active: Array = ResolverScript.resolve_active_gates(all_gates, int(run_state.random_seed), int(run_state.day), [], [])
	var gate_key := String(active[0])
	var gate_cell: Vector2i = map_manager.get_spawn_cell_by_key(StringName(gate_key))
	var silent_key := ""
	for raw_gate: Variant in all_gates:
		if not active.has(String(raw_gate)):
			silent_key = String(raw_gate)
			break
	run_state.stone = 0
	run_state.reset_action_points(30)
	var poor: Dictionary = day_manager.try_seal_spawn_gate(gate_cell)
	_expect(not poor.get("ok", false), "seal fails without stone")
	run_state.stone = 10
	var not_gate: Dictionary = day_manager.try_seal_spawn_gate(Vector2i(15, 15))
	_expect(not not_gate.get("ok", false), "seal rejects non-gate cell")
	var silent_cell: Vector2i = map_manager.get_spawn_cell_by_key(StringName(silent_key))
	var silent_result: Dictionary = day_manager.try_seal_spawn_gate(silent_cell)
	_expect(not silent_result.get("ok", false), "seal rejects silent gate")
	var ap_before: int = int(run_state.action_points)
	var ok_result: Dictionary = day_manager.try_seal_spawn_gate(gate_cell)
	_expect(ok_result.get("ok", false), "seal succeeds")
	_expect(int(run_state.stone) == 6 and int(run_state.action_points) == ap_before - 6, "seal costs 4 stone 6 ap")
	_expect((run_state.night_gate_closed_keys as Array).has(gate_key), "seal recorded")
	var second_gate := String(active[1])
	var second_cell: Vector2i = map_manager.get_spawn_cell_by_key(StringName(second_gate))
	var second: Dictionary = day_manager.try_seal_spawn_gate(second_cell)
	_expect(not second.get("ok", false), "daily seal limit enforced (also guards min-1)")
	run_state.clear_night_gate_overrides()
	game.queue_free()
	await process_frame


func _test_gate_events() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var event_manager := game.get_node_or_null("Managers/RandomEventManager")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	if run_state == null or event_manager == null or map_manager == null:
		_expect(false, "boot ok for gate events test")
		game.queue_free()
		await process_frame
		return
	var all_gates: Array = map_manager.get_spawn_keys()
	var active: Array = ResolverScript.resolve_active_gates(all_gates, int(run_state.random_seed), int(run_state.day), [], [])
	var landslide_cell := Vector2i(7, 7)
	event_manager._events_by_cell[landslide_cell] = &"event_landslide_contract"
	var cfg: Dictionary = event_manager.get_event_cfg_at_cell(landslide_cell)
	var choices: Array = cfg.get("choices", [])
	_expect(choices.size() == active.size() + 1, "landslide offers one choice per active gate plus leave")
	run_state.mana = 10
	var target_gate := String(active[0])
	var seal_result: Dictionary = event_manager.apply_event_for_cell(landslide_cell, StringName("seal_%s" % target_gate))
	_expect(seal_result.get("ok", false), "landslide seal applies")
	_expect(int(run_state.mana) == 7, "landslide costs 3 mana")
	_expect((run_state.night_gate_closed_keys as Array).has(target_gate), "landslide closes gate tonight")
	_expect(event_manager.get_event_id_at_cell(landslide_cell) == StringName(), "landslide consumed after seal")
	var prestige_before: int = int(run_state.prestige)
	var wager_result: Dictionary = event_manager.apply_event(&"event_gate_wager_accept")
	_expect(wager_result.get("ok", false), "gate wager applies")
	_expect((run_state.night_gate_extra_open_keys as Array).size() == 1, "gate wager opens one extra gate")
	var opened := String(run_state.night_gate_extra_open_keys[0])
	_expect(not active.has(opened), "wager opens a previously silent gate")
	_expect(int(run_state.prestige) == prestige_before + 3, "wager pays prestige reward")
	run_state.clear_night_gate_overrides()
	game.queue_free()
	await process_frame


func _test_markers() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	var spawn_root := game.get_node_or_null("World/SpawnRoot")
	if run_state == null or map_manager == null or spawn_root == null:
		_expect(false, "boot ok for marker test")
		game.queue_free()
		await process_frame
		return
	var keys: Array = map_manager.get_spawn_keys()
	var visible_markers: Dictionary = {}
	for child in spawn_root.get_children():
		if child is Node2D and (child as Node2D).visible:
			visible_markers[String(child.get("spawn_key"))] = child
	for raw_key: Variant in keys:
		_expect(visible_markers.has(String(raw_key)), "marker visible for gate %s" % String(raw_key))
	var active: Array = ResolverScript.resolve_active_gates(keys, int(run_state.random_seed), int(run_state.day), [], [])
	for raw_key2: Variant in keys:
		var key := String(raw_key2)
		var marker: Node2D = visible_markers.get(key)
		if marker == null:
			continue
		if active.has(key):
			_expect(marker.modulate.a > 0.9, "active marker bright: %s" % key)
		else:
			_expect(marker.modulate.a < 0.9, "silent marker dimmed: %s" % key)
	var victim := String(active[0])
	run_state.add_night_gate_closed(victim)
	await process_frame
	var victim_marker: Node2D = visible_markers.get(victim)
	_expect(victim_marker != null and victim_marker.modulate.a < 0.9, "sealed marker dimmed")
	var label := victim_marker.get_node_or_null("%SpawnLabel") as Label
	_expect(label != null and label.text.contains("封"), "sealed marker badge")
	run_state.clear_night_gate_overrides()
	game.queue_free()
	await process_frame


func _test_gate_ui() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	var event_bus = root.get_node_or_null("EventBus")
	var popup := game.find_child("MapInteractionPopup", true, false) as Control
	if run_state == null or map_manager == null or event_bus == null or popup == null:
		_expect(false, "boot ok for gate ui test (popup node name?)")
		game.queue_free()
		await process_frame
		return
	var keys: Array = map_manager.get_spawn_keys()
	var active: Array = ResolverScript.resolve_active_gates(keys, int(run_state.random_seed), int(run_state.day), [], [])
	var gate_cell: Vector2i = map_manager.get_spawn_cell_by_key(StringName(String(active[0])))
	event_bus.map_cell_clicked.emit(gate_cell)
	await process_frame
	_expect(popup.is_visible_in_tree(), "popup opens on undiscovered gate cell")
	var seal_button := popup.find_child("GateSealButton", true, false) as Button
	_expect(seal_button != null and seal_button.visible, "seal button present for active gate")
	run_state.stone = 10
	run_state.reset_action_points(30)
	if seal_button != null:
		seal_button.pressed.emit()
		await process_frame
		_expect((run_state.night_gate_closed_keys as Array).has(String(active[0])), "popup seal button seals the gate")
	var hud := game.get_node_or_null("UI/ScreenLayout/CombatHudSlot/CombatHud")
	_expect(hud != null and hud.has_method("set_active_gates_line"), "hud exposes active gates line")
	if hud != null and hud.has_method("set_active_gates_line"):
		hud.set_active_gates_line("今晚活跃口：S1 S2")
		var line := (hud as Node).find_child("ActiveGatesLine", true, false) as Label
		_expect(line != null and line.visible and line.text.contains("活跃口"), "active gates line renders")
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
