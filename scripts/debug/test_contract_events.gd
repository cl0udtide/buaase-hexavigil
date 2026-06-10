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

	# 每日刷新：day1 保底 2 个事件点；活跃上限 4。
	_expect((event_manager.get_event_cells() as Array).size() == 2, "day1 spawns exactly 2 event points")
	event_manager._spawn_daily_events(2)
	event_manager._spawn_daily_events(3)
	event_manager._spawn_daily_events(4)
	_expect((event_manager.get_event_cells() as Array).size() <= 4, "active event points capped at 4")

	# 雇佣兵营地：声望换随机干员。
	run_state.prestige = 10
	var roster_before: int = (run_state.get_owned_operators() as Array).size()
	var hire: Dictionary = event_manager.apply_event(&"event_mercenary_hire_mid")
	_expect(hire.get("ok", false), "mercenary hire applies")
	_expect((run_state.get_owned_operators() as Array).size() == roster_before + 1, "mercenary hire grants an operator")
	_expect(run_state.prestige == 7, "mercenary hire costs 3 prestige")

	# 祭坛：动态选项 + 灌注 = 干员实例获得盟约，魔力矿扣减。
	run_state.add_owned_operator(&"guard_t1", "测试斯卡蒂")
	var altar_cell := Vector2i(5, 5)
	event_manager._events_by_cell[altar_cell] = &"event_altar"
	var altar_cfg: Dictionary = event_manager.get_event_cfg_at_cell(altar_cell)
	var altar_choices: Array = altar_cfg.get("choices", [])
	_expect(altar_choices.size() >= 2, "altar offers dynamic choices plus leave")
	_expect(String((altar_choices[0] as Dictionary).get("id", "")).begins_with("infuse_"), "altar first choice is infusion")
	run_state.mana = 5
	var offers: Array = event_manager._ensure_altar_offers(altar_cell)
	var offer: Dictionary = offers[0]
	var target_key := StringName(offer.get("operator_key", ""))
	var target_covenant := StringName(offer.get("covenant", ""))
	var infuse: Dictionary = event_manager.apply_event_for_cell(altar_cell, StringName(offer.get("choice_id", "")))
	_expect(infuse.get("ok", false), "altar infusion applies")
	_expect(run_state.mana == 3, "altar infusion costs 2 mana")
	_expect((run_state.get_operator_covenants(target_key) as Array).has(target_covenant), "operator gains infused covenant")
	_expect(event_manager.get_event_id_at_cell(altar_cell) == StringName(), "altar consumed after infusion")

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
