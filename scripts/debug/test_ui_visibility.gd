extends SceneTree

## P2-0 UI 补课的可断言数据层回归：
##   - buff_manager 三选一回传槽位来源（buff_id 与 slot 对齐、取值合法、与旧接口一致）
##   - random_event_manager requires 预检（满足/缺口明细/缺口文案）
##   - random_event_manager 活跃事件计数 + 上限 getter
##   - wave_manager 波间倒计时 getter（非喘息期返回 -1）
## 运行：Godot --headless --path . --script scripts/debug/test_ui_visibility.gd

const WaveManagerScript = preload("res://scripts/enemy/wave_manager.gd")

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
	var random_event_manager := game.get_node_or_null("Managers/RandomEventManager")
	_expect(run_state != null and data_repo != null, "core singletons exist")
	_expect(buff_manager != null and random_event_manager != null, "managers exist")
	if run_state == null or data_repo == null or buff_manager == null or random_event_manager == null:
		_finish()
		return

	_test_blessing_slot_sources(run_state, buff_manager, data_repo)
	_test_event_requirement_preview(run_state, random_event_manager)
	_test_active_event_count(random_event_manager)
	_test_wave_countdown_getter()

	game.queue_free()
	await process_frame
	_finish()


# --- 1. 三选一槽位来源 ---
func _test_blessing_slot_sources(run_state: Node, buff_manager: Node, data_repo: Node) -> void:
	_expect(buff_manager.has_method("get_random_blessing_choices_with_sources"), "buff_manager exposes sourced draw")
	run_state.day = 4
	# 凑两名坚守干员，让盟约槽稳定供应（与 relic_draw 同口径；稀有度2钥匙第二幕起）。
	run_state.add_owned_operator(&"defender_t1", "测试森蚺")
	run_state.add_owned_operator(&"penance", "测试斥罪")
	var valid_slots := {&"covenant": true, &"economy": true, &"random": true}
	var saw_covenant := false
	for _round in range(12):
		var entries: Array = buff_manager.get_random_blessing_choices_with_sources()
		_expect(entries.size() == 3, "sourced draw returns 3 entries")
		var ids: Array = []
		for raw_entry: Variant in entries:
			_expect(typeof(raw_entry) == TYPE_DICTIONARY, "entry is a dict")
			var entry: Dictionary = raw_entry
			var buff_id := StringName(entry.get("buff_id", ""))
			var slot := StringName(entry.get("slot", ""))
			_expect(buff_id != StringName(), "entry has a buff_id")
			_expect(valid_slots.has(slot), "slot source is one of covenant/economy/random (got %s)" % slot)
			# buff_id 与 slot 必须对齐：buff_id 真实存在于配置。
			_expect(not data_repo.get_buff_cfg(buff_id).is_empty(), "entry buff_id resolves to a cfg")
			ids.append(buff_id)
			if slot == &"covenant":
				saw_covenant = true
		var distinct: Dictionary = {}
		for id in ids:
			distinct[id] = true
		_expect(distinct.size() == ids.size(), "sourced entries are distinct")
	_expect(saw_covenant, "covenant slot appears when covenant presence >= 2")

	# 旧接口必须与新接口同源（projection 一致：仅取 buff_id）。
	var legacy: Array = buff_manager.get_random_blessing_choices()
	_expect(legacy.size() == 3, "legacy draw still returns 3 ids")
	run_state.day = 1


# --- 2. 事件 requires 预检 ---
func _test_event_requirement_preview(run_state: Node, random_event_manager: Node) -> void:
	_expect(random_event_manager.has_method("preview_choice_requirements"), "manager exposes requires preview")
	# event_kroos（奸商）：buy -> event_kroos_buy(requires prestige 8)
	#                     sell -> event_kroos_sell(requires mana 3)
	run_state.prestige = 0
	run_state.mana = 0
	var buy: Dictionary = random_event_manager.preview_choice_requirements(&"event_kroos", &"buy")
	_expect(not bool(buy.get("ok", true)), "buy blocked when prestige=0")
	_expect(String(buy.get("reason", "")).find("8") >= 0, "buy reason mentions missing 8 (got '%s')" % String(buy.get("reason", "")))
	var buy_short: Array = buy.get("shortfalls", [])
	_expect(buy_short.size() == 1, "buy has one shortfall")
	if buy_short.size() == 1:
		var sf: Dictionary = buy_short[0]
		_expect(String(sf.get("key", "")) == "prestige", "buy shortfall is prestige")
		_expect(int(sf.get("missing", 0)) == 8, "buy missing amount is 8")

	# 资源足够后应放行。
	run_state.prestige = 8
	var buy_ok: Dictionary = random_event_manager.preview_choice_requirements(&"event_kroos", &"buy")
	_expect(bool(buy_ok.get("ok", false)), "buy allowed when prestige=8")
	_expect((buy_ok.get("shortfalls", []) as Array).is_empty(), "no shortfalls when affordable")

	# sell 缺魔力矿。
	run_state.mana = 1
	var sell: Dictionary = random_event_manager.preview_choice_requirements(&"event_kroos", &"sell")
	_expect(not bool(sell.get("ok", true)), "sell blocked when mana=1")
	_expect(String(sell.get("reason", "")).find("魔力矿") >= 0, "sell reason mentions 魔力矿")
	run_state.mana = 3
	var sell_ok: Dictionary = random_event_manager.preview_choice_requirements(&"event_kroos", &"sell")
	_expect(bool(sell_ok.get("ok", false)), "sell allowed when mana=3")

	# 无 requires 的选项恒满足（奸商离开）。
	var leave: Dictionary = random_event_manager.preview_choice_requirements(&"event_kroos", &"leave")
	_expect(bool(leave.get("ok", false)), "requirement-free choice is always ok")
	run_state.prestige = 0
	run_state.mana = 0


# --- 3. 活跃事件计数 ---
func _test_active_event_count(random_event_manager: Node) -> void:
	_expect(random_event_manager.has_method("get_active_event_count"), "manager exposes active event count")
	_expect(random_event_manager.has_method("get_max_active_event_points"), "manager exposes max event points")
	_expect(int(random_event_manager.get_max_active_event_points()) > 0, "max active event points reflects mother event count")
	random_event_manager.clear_events()
	_expect(int(random_event_manager.get_active_event_count()) == 0, "count is 0 after clear")
	# 用非常驻母事件铺设，触发后应被移除使计数下降（常驻事件如 event_kroos 不会）。
	random_event_manager.setup_events([
		{"cell": Vector2i(5, 5), "event_id": "event_phoebe"},
		{"cell": Vector2i(6, 6), "event_id": "event_market"},
	])
	_expect(int(random_event_manager.get_active_event_count()) == 2, "count is 2 after setup of 2")
	random_event_manager.mark_event_triggered(Vector2i(5, 5))
	_expect(int(random_event_manager.get_active_event_count()) == 1, "count drops to 1 after trigger")
	random_event_manager.clear_events()


# --- 4. 波间倒计时 getter ---
func _test_wave_countdown_getter() -> void:
	var wave_manager := WaveManagerScript.new()
	_expect(wave_manager.has_method("get_seconds_to_next_wave"), "wave_manager exposes countdown getter")
	# 未运行 → -1。
	_expect(wave_manager.get_seconds_to_next_wave() < 0.0, "countdown is -1 when not running")
	# 模拟喘息态：running + 多波 + 已排定下一波时间。
	wave_manager._running = true
	wave_manager._wave_template_ids = [&"a", &"b"] as Array[StringName]
	wave_manager._wave_index = 0
	wave_manager._elapsed = 10.0
	wave_manager._next_wave_at = 18.0
	_expect(is_equal_approx(wave_manager.get_seconds_to_next_wave(), 8.0), "countdown returns remaining lull seconds")
	wave_manager._elapsed = 20.0
	_expect(is_zero_approx(wave_manager.get_seconds_to_next_wave()), "countdown clamps to 0 past target")
	# 未排定下一波（_next_wave_at < 0）→ -1。
	wave_manager._next_wave_at = -1.0
	_expect(wave_manager.get_seconds_to_next_wave() < 0.0, "countdown is -1 before next wave scheduled")
	# 最后一波（无后续）→ -1。
	wave_manager._wave_index = 1
	wave_manager._next_wave_at = 5.0
	wave_manager._elapsed = 0.0
	_expect(wave_manager.get_seconds_to_next_wave() < 0.0, "countdown is -1 on final wave")
	wave_manager.free()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("UI VISIBILITY TESTS PASSED")
		quit(0)
	else:
		printerr("UI VISIBILITY TESTS FAILED: %d" % _failures)
		quit(1)
