extends SceneTree

## 契约事件系统（黑市/赌局/商队）的 headless 回归：
## 运行：Godot --headless --path . --script scripts/debug/test_contract_events.gd

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
	var event_manager := game.get_node_or_null("Managers/RandomEventManager")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	_expect(run_state != null and event_manager != null, "managers exist")
	if run_state == null or event_manager == null:
		_finish()
		return

	# 地图事件点：正式地图应放置事件点，且全部来自非隐藏池。
	if map_manager != null and event_manager.has_method("get_event_cells"):
		var cells: Array = event_manager.get_event_cells()
		_expect(cells.size() >= 1, "map has event points")

	# 黑市：核心上限 -2 并获得一件稀有遗物。
	var relics_before: int = (run_state.buffs as Array).size()
	var max_before: int = run_state.core_hp_max
	var deal: Dictionary = event_manager.apply_event(&"event_black_market_deal")
	_expect(deal.get("ok", false), "black market deal applies")
	_expect(run_state.core_hp_max == max_before - 2, "black market costs 2 core max hp")
	_expect((run_state.buffs as Array).size() == relics_before + 1, "black market grants a relic")
	var summary := String((deal.get("payload", {}) as Dictionary).get("effect_payload", {}).get("summary", ""))
	_expect(summary.contains("核心生命上限"), "deal summary mentions core cost")

	# 商队：前置不足时整体取消；满足后双向兑换。
	run_state.prestige = 0
	var buy_fail: Dictionary = event_manager.apply_event(&"event_caravan_buy")
	_expect(not buy_fail.get("ok", false), "caravan buy fails without prestige")
	run_state.prestige = 5
	var mana_before: int = run_state.mana
	var buy_ok: Dictionary = event_manager.apply_event(&"event_caravan_buy")
	_expect(buy_ok.get("ok", false), "caravan buy applies")
	_expect(run_state.prestige == 2 and run_state.mana == mana_before + 2, "caravan buy trades prestige for mana")

	# 赌局：追加一条词缀（day1 走回退池）并激活赌约。
	var affixes_before: int = (run_state.night_affix_ids as Array).size()
	var wager: Dictionary = event_manager.apply_event(&"event_war_wager_accept")
	_expect(wager.get("ok", false), "war wager applies")
	_expect((run_state.night_affix_ids as Array).size() == affixes_before + 1, "wager adds a night affix")
	_expect(bool(run_state.night_wager_active), "wager flag is active")

	# 赌约结算：未失血时累计额外三选一。
	run_state.night_core_damaged = false
	run_state.pending_extra_blessings = 0
	var game_controller := game.get_node_or_null("Managers/GameController")
	_expect(game_controller != null, "GameController exists")
	if game_controller != null:
		game_controller._on_night_cleared(1)
		_expect(int(run_state.pending_extra_blessings) == 1, "clean night pays extra blessing")
		_expect(not bool(run_state.night_wager_active), "wager resets after settlement")

	game.queue_free()
	await process_frame
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("CONTRACT EVENT TESTS PASSED")
		quit(0)
	else:
		printerr("CONTRACT EVENT TESTS FAILED: %d" % _failures)
		quit(1)
