extends SceneTree

## 商店锁定槽 + 盟约权重漂移（方案 §8.1 P2-1）的 headless 回归：
## 运行：Godot --headless --path . --script scripts/debug/test_shop_lock_drift.gd

const GameEnums = preload("res://scripts/core/game_enums.gd")

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
	var shop_manager := game.get_node_or_null("Managers/ShopManager")
	_expect(run_state != null and shop_manager != null, "core singletons exist")
	if run_state == null or shop_manager == null:
		_finish()
		return
	var has_api := shop_manager.has_method("try_toggle_lock_slot") \
			and shop_manager.has_method("get_covenant_drift_state") \
			and shop_manager.has_method("get_unit_roll_weight")
	_expect(has_api, "shop_manager exposes lock/drift api")
	if not has_api:
		_finish()
		return

	_test_lock_persists_across_days(shop_manager, run_state)
	_test_single_lock_and_toggle(shop_manager, run_state)
	_test_refresh_clears_lock(shop_manager, run_state)
	_test_lock_guards(shop_manager, run_state)
	_test_drift_day_gating(shop_manager, run_state)
	_test_drift_top_two_cutoff(shop_manager, run_state)

	game.queue_free()
	await process_frame
	_finish()


func _reset_day(run_state: Node, shop_manager: Node, day: int) -> void:
	run_state.reset_for_new_run(20260611)
	run_state.phase = GameEnums.PHASE_DAY
	run_state.day = day
	shop_manager.start_new_day_shop(day)


func _first_filled_slot_index(shop_manager: Node) -> int:
	var stock: Array[Dictionary] = shop_manager.get_current_stock()
	for slot in stock:
		if StringName((slot as Dictionary).get("unit_id", "")) != StringName():
			return int((slot as Dictionary).get("slot_index", -1))
	return -1


func _locked_indexes(shop_manager: Node) -> Array[int]:
	var result: Array[int] = []
	var stock: Array[Dictionary] = shop_manager.get_current_stock()
	for slot in stock:
		if bool((slot as Dictionary).get("locked", false)):
			result.append(int((slot as Dictionary).get("slot_index", -1)))
	return result


func _test_lock_persists_across_days(shop_manager: Node, run_state: Node) -> void:
	_reset_day(run_state, shop_manager, 1)
	var stock: Array[Dictionary] = shop_manager.get_current_stock()
	_expect(stock.size() == 5, "shop rolls 5 slots")
	for slot in stock:
		_expect((slot as Dictionary).has("locked"), "stock payload carries locked field")
	var index := _first_filled_slot_index(shop_manager)
	_expect(index >= 0, "shop has a purchasable slot")
	var lock_result: Dictionary = shop_manager.try_toggle_lock_slot(index)
	_expect(bool(lock_result.get("ok", false)), "locking a slot succeeds")
	stock = shop_manager.get_current_stock()
	_expect(bool(stock[index].get("locked", false)), "slot is locked after toggle")
	var locked_unit := StringName(stock[index].get("unit_id", ""))

	run_state.day = 2
	shop_manager.start_new_day_shop(2)
	stock = shop_manager.get_current_stock()
	_expect(StringName(stock[index].get("unit_id", "")) == locked_unit, "locked unit persists across daily reroll")
	_expect(bool(stock[index].get("locked", false)), "carried slot stays locked")
	_expect(not bool(stock[index].get("sold", false)), "carried slot stays purchasable")


func _test_single_lock_and_toggle(shop_manager: Node, run_state: Node) -> void:
	_reset_day(run_state, shop_manager, 1)
	shop_manager.try_toggle_lock_slot(0)
	shop_manager.try_toggle_lock_slot(1)
	var locked := _locked_indexes(shop_manager)
	_expect(locked.size() == 1 and locked[0] == 1, "locking another slot moves the single lock")
	var toggle_result: Dictionary = shop_manager.try_toggle_lock_slot(1)
	_expect(bool(toggle_result.get("ok", false)), "toggling locked slot succeeds")
	_expect(_locked_indexes(shop_manager).is_empty(), "toggle on locked slot unlocks it")


func _test_refresh_clears_lock(shop_manager: Node, run_state: Node) -> void:
	_reset_day(run_state, shop_manager, 1)
	run_state.add_prestige(10)
	shop_manager.try_toggle_lock_slot(0)
	var refresh_result: Dictionary = shop_manager.refresh_shop()
	_expect(bool(refresh_result.get("ok", false)), "manual refresh succeeds")
	_expect(_locked_indexes(shop_manager).is_empty(), "manual refresh clears the lock")


func _test_lock_guards(shop_manager: Node, run_state: Node) -> void:
	_reset_day(run_state, shop_manager, 1)
	run_state.phase = GameEnums.PHASE_NIGHT
	var night_result: Dictionary = shop_manager.try_toggle_lock_slot(0)
	_expect(not bool(night_result.get("ok", true)), "locking is day-only")
	run_state.phase = GameEnums.PHASE_DAY
	var invalid_result: Dictionary = shop_manager.try_toggle_lock_slot(99)
	_expect(not bool(invalid_result.get("ok", true)), "locking rejects invalid slot index")
	var index := _first_filled_slot_index(shop_manager)
	run_state.add_prestige(99)
	var buy_result: Dictionary = shop_manager.try_buy_shop_slot(index)
	_expect(bool(buy_result.get("ok", false)), "buying a slot succeeds")
	var sold_result: Dictionary = shop_manager.try_toggle_lock_slot(index)
	_expect(not bool(sold_result.get("ok", true)), "locking rejects sold slot")


func _test_drift_day_gating(shop_manager: Node, run_state: Node) -> void:
	_reset_day(run_state, shop_manager, 2)
	run_state.add_owned_operator(&"defender_t1", "测试坚守一")
	run_state.add_owned_operator(&"penance", "测试坚守二")
	var drift: Dictionary = shop_manager.get_covenant_drift_state()
	_expect(not bool(drift.get("active", true)), "drift inactive before day 3")
	_expect(is_equal_approx(float(shop_manager.get_unit_roll_weight(&"defender_t1")), 1.0), "no weight boost before day 3")

	run_state.day = 3
	drift = shop_manager.get_covenant_drift_state()
	_expect(bool(drift.get("active", false)), "drift active from day 3")
	var covenants: Array = drift.get("covenants", [])
	_expect(covenants.has(&"坚守"), "owned covenant enters drift set")
	_expect(covenants.size() == 1, "only present covenants drift")
	_expect(is_equal_approx(float(shop_manager.get_unit_roll_weight(&"defender_t1")), 1.2), "member unit weight is x1.2")
	_expect(is_equal_approx(float(shop_manager.get_unit_roll_weight(&"sniper_t1")), 1.0), "non-member unit weight stays 1.0")


func _test_drift_top_two_cutoff(shop_manager: Node, run_state: Node) -> void:
	_reset_day(run_state, shop_manager, 3)
	# 坚守 2 个去重单位、精准 2 个、不屈 1 个 → 漂移集只取前 2。
	run_state.add_owned_operator(&"defender_t1", "坚守一")
	run_state.add_owned_operator(&"penance", "坚守二")
	run_state.add_owned_operator(&"sniper_t1", "精准一")
	run_state.add_owned_operator(&"caster_t1", "精准二")
	run_state.add_owned_operator(&"guard_t1", "不屈一")
	var drift: Dictionary = shop_manager.get_covenant_drift_state()
	var covenants: Array = drift.get("covenants", [])
	_expect(covenants.size() == 2, "drift set keeps top two covenants")
	_expect(covenants.has(&"坚守") and covenants.has(&"精准"), "top two covenants by distinct units drift")
	_expect(not covenants.has(&"不屈"), "third covenant is cut off")
	_expect(is_equal_approx(float(shop_manager.get_unit_roll_weight(&"guard_t1")), 1.0), "cut-off covenant member stays 1.0")
	_expect(is_equal_approx(float(shop_manager.get_unit_roll_weight(&"caster_t1")), 1.2), "second covenant member gets x1.2")

	var data_repo = root.get_node_or_null("DataRepo")
	if data_repo != null:
		for unit_id in data_repo.get_all_unit_ids():
			var weight := float(shop_manager.get_unit_roll_weight(unit_id))
			_expect(is_equal_approx(weight, 1.0) or is_equal_approx(weight, 1.2), "weight for %s never stacks beyond x1.2" % unit_id)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("SHOP LOCK DRIFT TESTS PASSED")
		quit(0)
	else:
		printerr("SHOP LOCK DRIFT TESTS FAILED: %d" % _failures)
		quit(1)
