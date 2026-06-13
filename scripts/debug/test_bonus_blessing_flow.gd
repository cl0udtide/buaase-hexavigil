extends SceneTree

const GameEnums = preload("res://scripts/core/game_enums.gd")

## 无伤夜晚额外遗物三选一回归：
## 运行：Godot --headless --path . --script scripts/debug/test_bonus_blessing_flow.gd

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
	var game_controller := game.get_node_or_null("Managers/GameController")
	var blessing_panel := game.get_node_or_null("UI/ModalLayer/BlessingPanelSlot/BlessingPanel")
	_expect(run_state != null and game_controller != null and blessing_panel != null, "flow nodes exist")
	if run_state == null or game_controller == null or blessing_panel == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	if game_controller.has_method("start_new_run"):
		game_controller.start_new_run(12345)
	for _i in range(2):
		await process_frame

	run_state.pending_extra_blessings = 1
	game_controller.enter_blessing()
	await process_frame
	_expect(int(run_state.phase) == GameEnums.PHASE_BLESSING, "entered first blessing phase")
	_expect(bool(blessing_panel.visible), "first blessing panel visible")

	_press_first_choice(blessing_panel)
	await process_frame
	_expect(int(run_state.phase) == GameEnums.PHASE_BLESSING, "extra blessing keeps blessing phase")
	_expect(int(run_state.pending_extra_blessings) == 0, "extra blessing counter consumed")
	_expect(bool(blessing_panel.visible), "extra blessing panel remains visible after first pick")
	_expect(_choice_count(blessing_panel) > 0, "extra blessing choices rendered")

	_press_first_choice(blessing_panel)
	await process_frame
	_expect(int(run_state.phase) == GameEnums.PHASE_DAY, "second blessing advances to next day")
	_expect(int(run_state.day) == 2, "second blessing advances to day 2")
	_expect(not bool(blessing_panel.visible), "panel hidden after final blessing")

	game.queue_free()
	await process_frame
	_finish()


func _press_first_choice(blessing_panel: Node) -> void:
	var choice_list := _choice_list(blessing_panel)
	if choice_list == null:
		_expect(false, "choice list exists")
		return
	for child in choice_list.get_children():
		if child.has_method("get_buff_id") and child.has_signal("pressed"):
			var buff_id: StringName = child.get_buff_id()
			child.emit_signal("pressed", buff_id)
			return
	_expect(false, "has a pressable blessing choice")


func _choice_count(blessing_panel: Node) -> int:
	var choice_list := _choice_list(blessing_panel)
	return choice_list.get_child_count() if choice_list != null else 0


func _choice_list(blessing_panel: Node) -> VBoxContainer:
	return blessing_panel.get_node_or_null("ContentMargin/VBoxContainer/ChoiceList") as VBoxContainer


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("BONUS BLESSING FLOW TESTS PASSED")
		quit(0)
	else:
		printerr("BONUS BLESSING FLOW TESTS FAILED: %d" % _failures)
		quit(1)
