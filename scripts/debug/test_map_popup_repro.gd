extends SceneTree

## 临时复现脚本：点击资源点弹窗不出现的 bug。
## 运行：godot --headless --path . --script scripts/debug/test_map_popup_repro.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(10):
		await process_frame

	var run_state = root.get_node_or_null("RunState")
	var event_bus = root.get_node_or_null("EventBus")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	var popup := game.get_node_or_null("UI/FloatingLayer/MapInteractionPopup")
	print("run_state=", run_state, " event_bus=", event_bus, " map_manager=", map_manager, " popup=", popup)
	if run_state == null or event_bus == null or map_manager == null or popup == null:
		quit(1)
		return

	print("phase=", run_state.phase, " (PHASE_DAY=", GameEnums.PHASE_DAY, ")")
	print("popup _current_phase=", popup._current_phase)

	# 找到一个有资源的格子
	var resource_cell := Vector2i(-1, -1)
	for y in range(map_manager.height):
		for x in range(map_manager.width):
			var cell := Vector2i(x, y)
			var data = map_manager.get_cell_data(cell)
			if data != null and data.resource_type != StringName():
				resource_cell = cell
				break
		if resource_cell.x >= 0:
			break
	print("resource_cell=", resource_cell)
	if resource_cell.x < 0:
		print("FAIL: no resource cell on map")
		quit(1)
		return

	# 确保已探索
	if map_manager.has_method("force_discover"):
		map_manager.force_discover(resource_cell)
	elif not map_manager.is_discovered(resource_cell):
		# 直接改 cell data
		var data = map_manager.get_cell_data(resource_cell)
		if data != null and "discovered" in data:
			data.discovered = true
	print("is_discovered=", map_manager.is_discovered(resource_cell))

	# 模拟点击
	event_bus.map_cell_clicked.emit(resource_cell)
	await process_frame
	await process_frame
	print("popup.visible=", popup.visible)
	if popup.visible:
		print("PASS: popup shown")
	else:
		print("FAIL: popup not shown")
		# 打印各个门控
		print("  gate phase ok=", popup._current_phase == GameEnums.PHASE_DAY)
		var mm = popup._get_map_manager()
		print("  popup._get_map_manager()=", mm)
		if mm != null:
			print("  is_inside=", mm.is_inside(resource_cell), " is_discovered=", mm.is_discovered(resource_cell))
	quit(0)
