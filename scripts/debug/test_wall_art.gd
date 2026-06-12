extends SceneTree

## 程序化墙体美术回归：wall_art 生成确定性 / 全变种覆盖 / 木墙-人工高台互连掩码 /
## 运行时贴图走程序化路径（ImageTexture 而非文件贴图）。
## 运行：Godot --headless --path . --script scripts/debug/test_wall_art.gd

const WallArt = preload("res://scripts/building/wall_art.gd")
const CellDataScript = preload("res://scripts/map/cell_data.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_generation()
	await _test_connection_masks()
	_finish()


func _test_generation() -> void:
	for kind: StringName in [&"wood_wall", &"artificial_platform"]:
		for suffix_raw: Variant in WallArt.SUFFIX_TO_MASK.keys():
			var suffix: String = suffix_raw
			var key := "%s_%s" % [kind, suffix]
			var texture := WallArt.texture_for_key(key)
			_expect(texture != null, "texture generated for %s" % key)
			_expect(texture == WallArt.texture_for_key(key), "texture cached for %s" % key)
	_expect(WallArt.texture_for_key("inspiring_monolith") == null, "non-wall key falls through")
	_expect(WallArt.texture_for_key("wood_wall_9999_bogus") == null, "bogus suffix falls through")
	var first := WallArt.build_image(&"wood_wall", 10)
	var second := WallArt.build_image(&"wood_wall", 10)
	_expect(first.get_data() == second.get_data(), "generation is deterministic")
	var opaque := true
	for y: int in range(first.get_height()):
		for x: int in range(first.get_width()):
			var alpha := first.get_pixel(x, y).a
			if alpha > 0.001 and alpha < 0.999:
				opaque = false
	_expect(opaque, "no semi-transparent pixels")


func _test_connection_masks() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame
	var run_state = root.get_node_or_null("RunState")
	var map_manager := game.get_node_or_null("Managers/MapManager")
	var building_manager := game.get_node_or_null("Managers/BuildingManager")
	if run_state == null or map_manager == null or building_manager == null:
		_expect(false, "boot ok for connection test")
		game.queue_free()
		await process_frame
		return
	var core: Vector2i = map_manager.get_core_cell()
	# 初始探索半径有限，取核心近旁的相邻格。
	var wall_cell := Vector2i(core.x + 1, core.y)
	var platform_cell := Vector2i(core.x + 2, core.y)
	for cell: Vector2i in [wall_cell, platform_cell]:
		var data: CellData = map_manager.get_cell_data(cell)
		data.resource_type = &""
		data.set_base_terrain(CellDataScript.TERRAIN_PLAIN)
	run_state.add_materials(20, 20, 0)
	run_state.reset_action_points(30)
	var wall_place: Dictionary = building_manager.try_place_building(wall_cell, &"wood_wall")
	_expect(wall_place.get("ok", false), "wall places")
	var platform_place: Dictionary = building_manager.try_place_building(platform_cell, &"artificial_platform")
	_expect(platform_place.get("ok", false), "platform places")
	var wall_actor: Node = building_manager.get_building_by_cell(wall_cell)
	var platform_actor: Node = building_manager.get_building_by_cell(platform_cell)
	_expect(int(wall_actor.get_wall_connection_mask()) == 2, "wall connects east to platform")
	_expect(int(platform_actor.get_wall_connection_mask()) == 8, "platform connects west to wall")
	var wall_sprite := wall_actor.get_node_or_null("VisualRoot/IdleSprite") as Sprite2D
	var platform_sprite := platform_actor.get_node_or_null("VisualRoot/IdleSprite") as Sprite2D
	_expect(wall_sprite != null and wall_sprite.texture is ImageTexture, "wall uses procedural texture")
	_expect(platform_sprite != null and platform_sprite.texture is ImageTexture, "platform uses procedural texture")
	# 墙被摧毁后，哨站掩码回落为孤立。
	building_manager.damage_building(int(wall_actor.get_runtime_id()), 9999, GameEnums.DAMAGE_PHYSICAL)
	await process_frame
	_expect(int(platform_actor.get_wall_connection_mask()) == 0, "platform mask resets after wall destroyed")
	game.queue_free()
	await process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		_failures += 1
		printerr("FAIL %s" % label)


func _finish() -> void:
	if _failures > 0:
		printerr("test_wall_art: %d failure(s)" % _failures)
		quit(1)
	else:
		print("test_wall_art: all green")
		quit(0)
