extends SceneTree

## UI 截图采集：加载 Game.tscn 并驱动典型/极端 UI 状态，逐张输出 PNG 供显示质量审计。
## 必须带窗口运行（headless 不渲染，截图为空）：
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script scripts/debug/ui_screenshot_capture.gd
## 输出：tmp/ui_shots/<场景>_<状态>.png（tmp/ 不提交，脚本本身可提交）。

const CAPTURE_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR := "res://tmp/ui_shots"
const RUN_SEED := 20260611
const SETTLE_FRAMES := 10

var _viewport: SubViewport
var _shot_count := 0
var _errors := 0
var _done := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.title = "ui_screenshot_capture"
	# 渲染在 SubViewport 离屏进行；主窗口缩小置顶，避免被完全遮挡时 macOS 暂停出帧。
	root.size = Vector2i(480, 270)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_viewport = SubViewport.new()
	_viewport.size = CAPTURE_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_watchdog(300.0)

	# UI_SHOTS_ONLY=menu,game,result,dialog 可只跑部分分组（修复后重拍局部）。
	var only_env := OS.get_environment("UI_SHOTS_ONLY")
	var groups := only_env.split(",", false) if not only_env.is_empty() else PackedStringArray()
	if _group_enabled(groups, "menu"):
		await _capture_main_menu()
	if _group_enabled(groups, "game"):
		await _capture_game_states()
	if _group_enabled(groups, "result"):
		await _capture_result_scene()
	if _group_enabled(groups, "dialog"):
		await _capture_dialog_panel()

	_done = true
	if _errors > 0:
		printerr("[shots] finished with %d errors, %d shots" % [_errors, _shot_count])
		quit(1)
		return
	print("[shots] done: %d shots -> %s" % [_shot_count, OUTPUT_DIR])
	quit(0)


func _group_enabled(groups: PackedStringArray, group_name: String) -> bool:
	return groups.is_empty() or groups.has(group_name)


## 防御：任何状态驱动意外挂起时强制退出，避免无头值守跑死。
func _watchdog(seconds: float) -> void:
	await create_timer(seconds).timeout
	if not _done:
		printerr("[shots] WATCHDOG: timed out after %.0fs, force quitting" % seconds)
		quit(2)


func _capture_main_menu() -> void:
	var scene := load("res://scenes/bootstrap/MainMenu.tscn") as PackedScene
	if scene == null:
		_fail("load MainMenu.tscn")
		return
	var menu := scene.instantiate()
	_viewport.add_child(menu)
	await _settle()
	await _shot("main_menu_default")
	menu.queue_free()
	await process_frame


func _capture_game_states() -> void:
	var scene := load("res://scenes/game/Game.tscn") as PackedScene
	if scene == null:
		_fail("load Game.tscn")
		return
	var game := scene.instantiate()
	_viewport.add_child(game)
	for _i in range(12):
		await process_frame

	var run_state := root.get_node_or_null("/root/RunState")
	var data_repo := root.get_node_or_null("/root/DataRepo")
	var controller := game.get_node_or_null("Managers/GameController")
	var shop := game.get_node_or_null("Managers/ShopManager")
	var hud := game.get_node_or_null("UI/ScreenLayout/CombatHudSlot/CombatHud")
	var hud_controller := game.get_node_or_null("UI/CombatHudController")
	var build_panel := game.get_node_or_null("UI/ScreenLayout/BuildPanelSlot/BuildPanel")
	var blessing_panel := game.get_node_or_null("UI/ModalLayer/BlessingPanelSlot/BlessingPanel")
	var event_panel := game.get_node_or_null("UI/ModalLayer/EventPanelSlot/EventPanel")
	var result_panel := game.get_node_or_null("UI/ModalLayer/ResultPanelSlot/ResultPanel")
	for pair in [
		["RunState", run_state], ["DataRepo", data_repo], ["GameController", controller],
		["ShopManager", shop], ["CombatHud", hud], ["CombatHudController", hud_controller],
		["BuildPanel", build_panel], ["BlessingPanel", blessing_panel],
		["EventPanel", event_panel], ["ResultPanel", result_panel],
	]:
		if pair[1] == null:
			_fail("missing node: %s" % pair[0])
	if _errors > 0:
		game.queue_free()
		return
	_force_overlay_layers_visible(game)

	# --- 典型态：开局白天 1，空卡组、初始资源 ---
	controller.start_new_run(RUN_SEED, &"standard")
	await _settle()
	await _shot("hud_day1_typical")

	# --- 左侧面板：建筑页 / 商店页（典型） ---
	build_panel.call("_select_mode", &"build")
	await _settle()
	await _shot("build_panel_build_tab")
	build_panel.call("_select_mode", &"shop")
	await _settle()
	_log_stock(shop)
	await _shot("build_panel_shop_typical")

	# --- 极端态：四位数资源、满部署、巨核心、满遗物、多干员 ---
	run_state.reset_action_points(9999)
	run_state.add_prestige(9999)
	run_state.add_materials(9999, 9999, 9999)
	run_state.add_core_max_hp(9990)
	run_state.heal_core_full()
	run_state.set_deploy_limit(99)
	run_state.change_deployed_count(99)
	for buff_id in data_repo.get_all_buff_ids():
		run_state.add_buff(buff_id)
	var roster: Array[StringName] = [
		&"wisadel", &"surtr", &"ifrit", &"saria", &"zuo_le",
		&"degenbrecher", &"typhon", &"goldenglow", &"logos", &"penance",
	]
	var star := 1
	for unit_id in roster:
		var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
		if cfg.is_empty():
			print("[shots] skip unknown unit: %s" % unit_id)
			continue
		run_state.add_owned_operator(unit_id, "", star)
		star = star % 3 + 1
	await _settle()
	await _shot("hud_day1_extreme_resources_relics_deck")

	# --- 极端态：第 7 天（自然掷词缀），敌情预览刷新 ---
	controller.enter_day(7)
	var affixes: Array[StringName] = run_state.night_affix_ids
	if affixes.size() < 3:
		var extra: Array[StringName] = data_repo.get_all_night_affix_ids()
		for affix_id in extra:
			if affixes.size() >= 4:
				break
			if not affixes.has(affix_id):
				affixes.append(affix_id)
		run_state.night_affix_ids = affixes
		hud_controller.call("_force_wave_preview_refresh")
	print("[shots] day7 affixes: %s" % str(run_state.night_affix_ids))
	await _settle()
	await _shot("hud_day7_extreme_affixes_wave_preview")

	# --- 商店满页 + 已售出槽位（声望充足） ---
	build_panel.call("_select_mode", &"shop")
	await _settle()
	var buy_result: Dictionary = shop.try_buy_shop_slot(0)
	print("[shots] buy slot0: %s" % str(buy_result))
	await _settle()
	_log_stock(shop)
	await _shot("build_panel_shop_full_with_sold")

	# --- 右侧详情：最长技能描述干员预览（仅审计，不改 UnitDetailPanel） ---
	var preview_key := _find_operator_key(run_state, &"surtr")
	if preview_key != StringName():
		hud_controller.call("_show_operator_preview", preview_key)
		await _settle()
		await _shot("unit_detail_operator_preview_surtr")
		hud.clear_unit_detail()
		await _settle()

	# --- 遗物面板（满遗物） ---
	hud.toggle_relic_panel()
	await _settle()
	await _shot("relic_panel_full")
	hud.toggle_relic_panel()
	await _settle()

	# --- 设置面板 ---
	hud.toggle_settings_panel()
	await _settle()
	await _shot("settings_panel_open")
	hud.toggle_settings_panel()
	await _settle()

	# --- 祝福三选一：最长描述遗物 ---
	var longest_buffs := _longest_desc_buffs(data_repo, 3)
	print("[shots] blessing choices: %s" % str(longest_buffs))
	blessing_panel.show_choices(longest_buffs)
	await _settle()
	await _shot("blessing_panel_longest_desc")
	blessing_panel.hide_panel()
	await _settle()

	# --- 事件面板：最长文案事件 ---
	var event_id := _longest_event_id(data_repo)
	if event_id != StringName():
		print("[shots] event: %s" % event_id)
		event_panel.show_event(data_repo.get_event_cfg(event_id))
		await _settle()
		await _shot("event_panel_longest_text")
		event_panel.hide_event()
		await _settle()

	# --- 夜晚 HUD：多词缀开战 ---
	controller.enter_night()
	await _settle()
	await _shot("hud_night_start")
	await create_timer(2.0).timeout
	await _shot("hud_night_wave_running")

	# --- 教程模式首步覆盖层 ---
	controller.start_new_run(RUN_SEED, &"tutorial")
	await _settle()
	await _settle()
	await _shot("tutorial_overlay_step1")

	print("[shots] freeing game scene")
	paused = false
	game.queue_free()
	await process_frame
	print("[shots] game scene freed")


func _capture_result_scene() -> void:
	# 真实结算页是 SceneRouter 切换的独立场景（Game 内 ResultPanel 为遗留死节点）。
	var scene := load("res://scenes/bootstrap/Result.tscn") as PackedScene
	if scene == null:
		_fail("load Result.tscn")
		return
	var router := root.get_node_or_null("/root/SceneRouter")
	for win in [true, false]:
		if router != null:
			router.result_win = win
		var result_scene := scene.instantiate()
		_viewport.add_child(result_scene)
		await _settle()
		await _shot("result_scene_win" if win else "result_scene_lose")
		result_scene.queue_free()
		await process_frame


func _capture_dialog_panel() -> void:
	var scene := load("res://scenes/ui/DialogPanel.tscn") as PackedScene
	if scene == null:
		print("[shots] DialogPanel.tscn not found, skip")
		return
	print("[shots] dialog: scene loaded")
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.08, 0.09, 0.11, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(backdrop)
	var dialog := scene.instantiate()
	_viewport.add_child(dialog)
	if dialog is Control:
		(dialog as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	await _settle()
	var script_data := _load_json("res://data/debug/dialog_sandbox_script.json")
	if script_data.is_empty():
		print("[shots] dialog script missing, skip")
	else:
		var settings: Dictionary = script_data.get("settings", {})
		settings["type_speed"] = 100000.0
		script_data["settings"] = settings
		dialog.play_script(script_data)
		await _settle()
		await _settle()
		await _shot("dialog_panel_line1_full_text")
	dialog.queue_free()
	backdrop.queue_free()
	await process_frame


## 弹窗/设置/遗物的容器层在场景里被 visible=false 藏住（"UI 点不开"，另一会话修复中）。
## 这里仅在运行时强制显示容器层以便审计面板内容，不改动场景文件；面板自身仍按
## 各自 _ready 的默认隐藏逻辑工作。等修复 PR 合入后此函数自然变为幂等无副作用。
func _force_overlay_layers_visible(game: Node) -> void:
	for layer_path in [
		"UI/ModalLayer",
		"UI/ScreenLayout/CombatHudSlot/CombatHud/PopupLayer",
		"UI/ScreenLayout/CombatHudSlot/CombatHud/PopupLayer/RelicPanelSlot",
		"UI/ScreenLayout/CombatHudSlot/CombatHud/PopupLayer/RelicPanelSlot/RelicPanelCenter",
	]:
		var layer := game.get_node_or_null(layer_path) as CanvasItem
		if layer != null:
			layer.visible = true


func _settle() -> void:
	for _i in range(SETTLE_FRAMES):
		await process_frame


func _shot(shot_name: String) -> void:
	# 不等 frame_post_draw（窗口被遮挡时可能永不触发），强制同步渲染一帧后取图。
	await process_frame
	RenderingServer.force_draw()
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty image for %s" % shot_name)
		return
	var path := "%s/%s.png" % [OUTPUT_DIR, shot_name]
	var err := image.save_png(path)
	if err != OK:
		_fail("save_png %s err=%d" % [path, err])
		return
	_shot_count += 1
	print("[shots] %s (%dx%d)" % [shot_name, image.get_width(), image.get_height()])


func _fail(msg: String) -> void:
	_errors += 1
	printerr("[shots] FAIL: %s" % msg)


func _log_stock(shop: Node) -> void:
	var stock: Array[Dictionary] = shop.get_current_stock()
	var parts := PackedStringArray()
	for slot in stock:
		parts.append("%s%s" % [String(slot.get("unit_id", "?")), "(sold)" if bool(slot.get("sold", false)) else ""])
	print("[shots] shop stock: %s" % ", ".join(parts))


func _find_operator_key(run_state: Node, unit_id: StringName) -> StringName:
	for operator_info in run_state.get_owned_operators():
		if StringName(operator_info.get("unit_id", &"")) == unit_id:
			return StringName(operator_info.get("key", &""))
	return StringName()


func _longest_desc_buffs(data_repo: Node, count: int) -> Array[StringName]:
	var scored: Array[Dictionary] = []
	for buff_id in data_repo.get_all_buff_ids():
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id)
		scored.append({"id": buff_id, "len": String(cfg.get("desc", "")).length()})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["len"]) > int(b["len"]))
	var result: Array[StringName] = []
	for entry in scored.slice(0, count):
		result.append(StringName(entry["id"]))
	return result


func _longest_event_id(data_repo: Node) -> StringName:
	var best_id := StringName()
	var best_score := -1
	for event_id in data_repo.get_all_event_ids():
		var cfg: Dictionary = data_repo.get_event_cfg(event_id)
		var choices: Array = cfg.get("choices", [])
		var score := String(cfg.get("desc", "")).length() + choices.size() * 40
		if score > best_score:
			best_score = score
			best_id = event_id
	return best_id


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary
