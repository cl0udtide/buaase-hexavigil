extends SceneTree

## P2-5 定向升星（白天消耗魔力矿+声望对指定干员 +1 星）的 headless 回归：
## 运行：Godot --headless --path . --script scripts/debug/test_targeted_star_up.gd

const OperatorProgression = preload("res://scripts/combat/operator_progression.gd")
const Enums = preload("res://scripts/core/game_enums.gd")

var _failures: int = 0
var _upgrade_results: Array[Dictionary] = []


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
	var event_bus = root.get_node_or_null("EventBus")
	var unit_manager = game.get_node_or_null("Managers/UnitManager")
	_expect(run_state != null and event_bus != null and unit_manager != null, "core singletons exist")
	if run_state == null or event_bus == null or unit_manager == null:
		_finish()
		return
	_expect(unit_manager.has_method("try_upgrade_operator_star"), "unit_manager exposes try_upgrade_operator_star")
	_expect(run_state.has_method("upgrade_owned_operator_star"), "run_state exposes upgrade_owned_operator_star")
	if not unit_manager.has_method("try_upgrade_operator_star") or not run_state.has_method("upgrade_owned_operator_star"):
		_finish()
		return
	event_bus.operator_star_upgrade_result.connect(_on_upgrade_result)

	_test_costs_and_star_up(run_state, unit_manager)
	_test_full_star_rejected(run_state, unit_manager)
	_test_not_enough_resources(run_state, unit_manager)
	_test_phase_gating(run_state, unit_manager)
	_test_deployed_gating(run_state, unit_manager)
	_test_event_bus_roundtrip(run_state, event_bus)
	_test_detail_panel_button(run_state, event_bus)

	game.queue_free()
	await process_frame
	_finish()


func _test_costs_and_star_up(run_state: Node, unit_manager: Node) -> void:
	run_state.phase = Enums.PHASE_DAY
	var operator: Dictionary = run_state.add_owned_operator(&"defender_t1", "升星试验员")
	var key := StringName(operator.get("key", ""))
	_expect(key != StringName(), "test operator added")
	run_state.mana = 10
	run_state.prestige = 20
	var result: Dictionary = unit_manager.try_upgrade_operator_star(key)
	_expect(bool(result.get("ok", false)), "1->2 star up succeeds")
	_expect(int(run_state.mana) == 7, "1->2 costs 3 mana")
	_expect(int(run_state.prestige) == 16, "1->2 costs 4 prestige")
	_expect(_operator_star(run_state, key) == 2, "operator reaches star 2")
	result = unit_manager.try_upgrade_operator_star(key)
	_expect(bool(result.get("ok", false)), "2->3 star up succeeds")
	_expect(int(run_state.mana) == 1, "2->3 costs 6 mana")
	_expect(int(run_state.prestige) == 8, "2->3 costs 8 prestige")
	_expect(_operator_star(run_state, key) == 3, "operator reaches star 3")


func _test_full_star_rejected(run_state: Node, unit_manager: Node) -> void:
	run_state.phase = Enums.PHASE_DAY
	var operator: Dictionary = run_state.add_owned_operator(&"sniper_t1", "满星试验员", OperatorProgression.MAX_STAR)
	var key := StringName(operator.get("key", ""))
	run_state.mana = 10
	run_state.prestige = 20
	var result: Dictionary = unit_manager.try_upgrade_operator_star(key)
	_expect(not bool(result.get("ok", false)), "full star rejected")
	_expect(StringName(result.get("code", "")) == &"STAR_MAXED", "full star error code")
	_expect(int(run_state.mana) == 10 and int(run_state.prestige) == 20, "full star deducts nothing")
	_expect(_operator_star(run_state, key) == OperatorProgression.MAX_STAR, "full star stays at max")


func _test_not_enough_resources(run_state: Node, unit_manager: Node) -> void:
	run_state.phase = Enums.PHASE_DAY
	var operator: Dictionary = run_state.add_owned_operator(&"caster_t1", "穷困试验员")
	var key := StringName(operator.get("key", ""))
	# 魔力矿不足：声望充足也必须整体拒绝，不允许只扣一边。
	run_state.mana = 2
	run_state.prestige = 20
	var result: Dictionary = unit_manager.try_upgrade_operator_star(key)
	_expect(not bool(result.get("ok", false)), "insufficient mana rejected")
	_expect(int(run_state.mana) == 2 and int(run_state.prestige) == 20, "insufficient mana deducts nothing")
	_expect(_operator_star(run_state, key) == 1, "star unchanged on mana shortage")
	# 声望不足：魔力矿充足也必须整体拒绝。
	run_state.mana = 10
	run_state.prestige = 3
	result = unit_manager.try_upgrade_operator_star(key)
	_expect(not bool(result.get("ok", false)), "insufficient prestige rejected")
	_expect(int(run_state.mana) == 10 and int(run_state.prestige) == 3, "insufficient prestige deducts nothing")
	_expect(_operator_star(run_state, key) == 1, "star unchanged on prestige shortage")


func _test_phase_gating(run_state: Node, unit_manager: Node) -> void:
	var operator: Dictionary = run_state.add_owned_operator(&"guard_t1", "夜班试验员")
	var key := StringName(operator.get("key", ""))
	run_state.mana = 10
	run_state.prestige = 20
	run_state.phase = Enums.PHASE_NIGHT
	var result: Dictionary = unit_manager.try_upgrade_operator_star(key)
	_expect(not bool(result.get("ok", false)), "night phase rejected")
	_expect(StringName(result.get("code", "")) == &"INVALID_PHASE", "night phase error code")
	_expect(int(run_state.mana) == 10 and int(run_state.prestige) == 20, "night phase deducts nothing")
	_expect(_operator_star(run_state, key) == 1, "star unchanged at night")
	run_state.phase = Enums.PHASE_DAY


func _test_deployed_gating(run_state: Node, unit_manager: Node) -> void:
	run_state.phase = Enums.PHASE_DAY
	var operator: Dictionary = run_state.add_owned_operator(&"guard_t1", "在场试验员")
	var key := StringName(operator.get("key", ""))
	run_state.mana = 20
	run_state.prestige = 20
	# v1 取舍：升星与出售同门控，只对未部署（ready）干员开放；直接注入部署表模拟在场实例。
	unit_manager._runtime_by_operator_key[key] = 424242
	var result: Dictionary = unit_manager.try_upgrade_operator_star(key)
	_expect(not bool(result.get("ok", false)), "deployed operator rejected")
	_expect(StringName(result.get("code", "")) == &"OPERATOR_DEPLOYED", "deployed error code")
	_expect(_operator_star(run_state, key) == 1, "star unchanged while deployed")
	unit_manager._runtime_by_operator_key.erase(key)
	result = unit_manager.try_upgrade_operator_star(key)
	_expect(bool(result.get("ok", false)), "ready operator upgrades after retreat")


func _test_event_bus_roundtrip(run_state: Node, event_bus: Node) -> void:
	run_state.phase = Enums.PHASE_DAY
	var operator: Dictionary = run_state.add_owned_operator(&"sniper_t1", "信号试验员")
	var key := StringName(operator.get("key", ""))
	run_state.mana = 10
	run_state.prestige = 20
	_upgrade_results.clear()
	event_bus.request_upgrade_operator_star.emit(key)
	_expect(_upgrade_results.size() == 1, "request signal produces one result event")
	if _upgrade_results.size() == 1:
		var event := _upgrade_results[0]
		_expect(StringName(event.get("operator_key", "")) == key, "result event carries operator key")
		_expect(bool((event.get("result", {}) as Dictionary).get("ok", false)), "result event is ok")
	_expect(_operator_star(run_state, key) == 2, "event bus path upgrades star")
	_expect(int(run_state.mana) == 7 and int(run_state.prestige) == 16, "event bus path deducts cost")


func _test_detail_panel_button(run_state: Node, event_bus: Node) -> void:
	var data_repo = root.get_node_or_null("DataRepo")
	var panel_scene := load("res://scenes/ui/combat/UnitDetailPanel.tscn") as PackedScene
	_expect(data_repo != null and panel_scene != null, "panel scene and data repo available")
	if data_repo == null or panel_scene == null:
		return
	var panel := panel_scene.instantiate()
	root.add_child(panel)
	run_state.phase = Enums.PHASE_DAY
	var operator: Dictionary = run_state.add_owned_operator(&"guard_t1", "面板试验员")
	var key := StringName(operator.get("key", ""))
	run_state.mana = 10
	run_state.prestige = 20
	panel.show_operator_preview(run_state.get_owned_operator(key), data_repo.get_unit_cfg(&"guard_t1"), &"ready")
	var button: Button = panel.get_node("%StarUpButton")
	_expect(button.visible, "star up button visible in preview")
	_expect(not button.disabled, "star up button enabled when affordable")
	_expect(button.text == "升星 3魔力矿+4声望", "star up button shows 1->2 price")
	# 资源变化信号驱动按钮禁用/恢复。
	run_state.add_materials(0, 0, -8)
	_expect(button.disabled, "star up button disabled when mana short")
	run_state.add_materials(0, 0, 8)
	_expect(not button.disabled, "star up button re-enabled when mana restored")
	# 非后备（已部署/冷却）状态同出售门控：禁用。
	panel.show_operator_preview(run_state.get_owned_operator(key), data_repo.get_unit_cfg(&"guard_t1"), &"cooldown")
	_expect(button.disabled, "star up button disabled for non-ready operator")
	panel.show_operator_preview(run_state.get_owned_operator(key), data_repo.get_unit_cfg(&"guard_t1"), &"ready")
	# EventBus 回路：升星成功后面板按结果信号自刷新（星级标签与价格档位）。
	run_state.mana = 20
	run_state.prestige = 40
	event_bus.request_upgrade_operator_star.emit(key)
	_expect((panel.get_node("%LevelLabel") as Label).text == "★2", "level label refreshed to star 2")
	_expect(button.text == "升星 6魔力矿+8声望", "star up button shows 2->3 price after upgrade")
	event_bus.request_upgrade_operator_star.emit(key)
	_expect(button.text == "已满星" and button.disabled, "star up button shows maxed state")
	panel.queue_free()


func _operator_star(run_state: Node, key: StringName) -> int:
	return OperatorProgression.normalize_star((run_state.get_owned_operator(key) as Dictionary).get("star", 0))


func _on_upgrade_result(operator_key: StringName, result: Dictionary) -> void:
	_upgrade_results.append({"operator_key": operator_key, "result": result})


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("TARGETED STAR UP TESTS PASSED")
		quit(0)
	else:
		printerr("TARGETED STAR UP TESTS FAILED: %d" % _failures)
		quit(1)
