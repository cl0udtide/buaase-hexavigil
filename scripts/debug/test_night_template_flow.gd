extends SceneTree

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
	_expect(run_state != null, "RunState exists")
	if run_state != null:
		_expect(int(run_state.day) == 1, "day 1 started")
		_expect(StringName(run_state.night_template_id) != StringName(), "night template resolved")
		_expect(not run_state.used_template_ids.is_empty(), "used template recorded")

	var wave_manager := game.get_node_or_null("Managers/WaveManager")
	_expect(wave_manager != null, "WaveManager exists")
	if wave_manager != null and run_state != null:
		var preview: Dictionary = wave_manager.get_wave_preview_for_template(run_state.night_template_id)
		_expect(not preview.is_empty(), "template preview exists")
		_expect(String(preview.get("name", "")) != "", "preview has name")
		_expect(String(preview.get("desc", "")) != "", "preview has desc")
		_expect(int(preview.get("total_count", 0)) > 0, "preview total count")
		_expect((preview.get("entries", []) as Array).size() > 0, "preview entries")

	var combat_hud := game.get_node_or_null("UI/ScreenLayout/CombatHudSlot/CombatHud")
	_expect(combat_hud != null, "CombatHud exists")
	if combat_hud != null:
		var preview_panel := combat_hud.get_node_or_null("%WavePreviewPanel") as Control
		_expect(preview_panel != null and preview_panel.visible, "wave preview panel visible")
		var spawn_cards := combat_hud.find_child("WaveSpawnCardsBox", true, false) as VBoxContainer
		_expect(spawn_cards != null, "spawn cards container exists")
		_expect(spawn_cards != null and spawn_cards.get_child_count() > 0, "spawn cards populated")
		var banner := combat_hud.find_child("LevelIntroBanner", true, false) as Control
		_expect(banner != null, "level intro banner exists")

	game.queue_free()
	await process_frame
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _finish() -> void:
	if _failures == 0:
		print("NIGHT TEMPLATE FLOW TESTS PASSED")
		quit(0)
	else:
		printerr("NIGHT TEMPLATE FLOW TESTS FAILED: %d" % _failures)
		quit(1)
