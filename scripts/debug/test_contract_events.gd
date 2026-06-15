extends SceneTree

## 随机事件系统（奇怪的商人 / 奸商 / 持石 / 人才市场 / 祭坛 等）的 headless 回归：
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

	# 回归：默认隐藏外层以免空层挡住点击，但打开面板时脚本必须同步打开父层。
	var modal_layer := game.get_node_or_null("UI/ModalLayer") as Control
	var event_panel_slot := game.get_node_or_null("UI/ModalLayer/EventPanelSlot") as Control
	var floating_layer := game.get_node_or_null("UI/FloatingLayer") as Control
	_expect(modal_layer != null and not modal_layer.visible, "ModalLayer hidden by default")
	_expect(event_panel_slot != null and event_panel_slot.visible, "EventPanelSlot visible by default")
	_expect(floating_layer != null and not floating_layer.visible, "FloatingLayer hidden by default")
	var event_panel := game.get_node_or_null("UI/ModalLayer/EventPanelSlot/EventPanel") as Control
	_expect(event_panel != null, "EventPanel exists")
	if event_panel != null and event_manager.has_method("get_event_cells"):
		var open_cells: Array = event_manager.get_event_cells()
		var event_bus = root.get_node_or_null("EventBus")
		_expect(event_bus != null, "EventBus exists")
		if event_bus != null and not open_cells.is_empty():
			# 新链路：地图小弹窗的「触发事件」按钮预扣行动力后 emit request_show_event_detail，
			# 才打开事件详情面板（request_open_event_panel 现在只开 map_interaction_popup 小弹窗）。
			event_bus.request_show_event_detail.emit(open_cells[0])
			await process_frame
			_expect(modal_layer.visible, "ModalLayer opens with event panel")
			_expect(event_panel.is_visible_in_tree(), "event panel renders after detail request signal")
			if event_panel.has_method("hide_event"):
				event_panel.hide_event()
				await process_frame
				_expect(not modal_layer.visible, "ModalLayer hides after event panel closes")

	# CombatHud 侧同族泄漏：空弹出层默认隐藏，设置与遗物面板打开时再恢复父层。
	var combat_hud := game.get_node_or_null("UI/ScreenLayout/CombatHudSlot/CombatHud") as Control
	_expect(combat_hud != null, "CombatHud exists")
	if combat_hud != null:
		for layer_path: String in ["PopupLayer", "PopupLayer/RelicPanelSlot", "PopupLayer/RelicPanelSlot/RelicPanelCenter"]:
			var layer := combat_hud.get_node_or_null(layer_path) as Control
			_expect(layer != null and not layer.visible, "%s hidden by default" % layer_path)
		var popup_layer := combat_hud.get_node_or_null("PopupLayer") as Control
		var settings_panel_slot := combat_hud.get_node_or_null("PopupLayer/SettingsPanelSlot") as Control
		var relic_panel_slot := combat_hud.get_node_or_null("PopupLayer/RelicPanelSlot") as Control
		var relic_panel_center := combat_hud.get_node_or_null("PopupLayer/RelicPanelSlot/RelicPanelCenter") as Control
		var settings_panel := combat_hud.get_node_or_null("PopupLayer/SettingsPanelSlot/AudioSettingsPanel") as Control
		var relic_panel := combat_hud.get_node_or_null("PopupLayer/RelicPanelSlot/RelicPanelCenter/RelicPanel") as Control
		_expect(settings_panel != null and relic_panel != null, "overlay panels exist")
		if settings_panel != null and combat_hud.has_method("toggle_settings_panel"):
			combat_hud.toggle_settings_panel()
			_expect(popup_layer != null and popup_layer.visible, "PopupLayer opens with settings panel")
			_expect(settings_panel_slot != null and settings_panel_slot.visible, "SettingsPanelSlot opens with settings panel")
			_expect(settings_panel.is_visible_in_tree(), "settings panel renders when opened")
			combat_hud.toggle_settings_panel()
			_expect(popup_layer != null and not popup_layer.visible, "PopupLayer hides after settings panel closes")
		if relic_panel != null and combat_hud.has_method("toggle_relic_panel"):
			combat_hud.toggle_relic_panel()
			_expect(popup_layer != null and popup_layer.visible, "PopupLayer opens with relic panel")
			_expect(relic_panel_slot != null and relic_panel_slot.visible, "RelicPanelSlot opens with relic panel")
			_expect(relic_panel_center != null and relic_panel_center.visible, "RelicPanelCenter opens with relic panel")
			_expect(relic_panel.is_visible_in_tree(), "relic panel renders when opened")
			combat_hud.toggle_relic_panel()
			_expect(popup_layer != null and not popup_layer.visible, "PopupLayer hides after relic panel closes")

	# 奇怪的商人·全都要（event_phoebe_all）：核心生命上限减半，并获得普通+稀有遗物。
	run_state.core_hp_max = 20
	var core_max_before: int = int(run_state.core_hp_max)
	var relics_before: int = (run_state.buffs as Array).size()
	var deal: Dictionary = event_manager.apply_event(&"event_phoebe_all")
	_expect(deal.get("ok", false), "phoebe all deal applies")
	_expect((run_state.buffs as Array).size() >= relics_before + 1, "phoebe all grants at least one relic")
	_expect(int(run_state.core_hp_max) < core_max_before, "core max hp halved")
	var summary := String((deal.get("payload", {}) as Dictionary).get("effect_payload", {}).get("summary", ""))
	_expect(summary.contains("核心生命上限减半"), "deal summary mentions core halve")

	# 奸商·买魔力矿（event_kroos_buy，requires prestige 8）：前置不足时整体取消；满足后 8 声望换 3 魔力矿。
	run_state.prestige = 0
	var buy_fail: Dictionary = event_manager.apply_event(&"event_kroos_buy")
	_expect(not buy_fail.get("ok", false), "kroos buy fails without prestige")
	run_state.prestige = 8
	var mana_before: int = run_state.mana
	var buy_ok: Dictionary = event_manager.apply_event(&"event_kroos_buy")
	_expect(buy_ok.get("ok", false), "kroos buy applies")
	_expect(run_state.prestige == 0 and run_state.mana == mana_before + 3, "kroos buy trades 8 prestige for 3 mana")

	# 持石的好处（event_stone_take）：追加一条随机夜晚词缀（day1 走回退池）并激活不漏怪赌约。
	var affixes_before: int = (run_state.night_affix_ids as Array).size()
	var wager: Dictionary = event_manager.apply_event(&"event_stone_take")
	_expect(wager.get("ok", false), "stone take applies")
	_expect((run_state.night_affix_ids as Array).size() == affixes_before + 1, "stone take adds a night affix")
	_expect(bool(run_state.night_wager_active), "wager flag is active")

	# 今晚词缀横幅在白天也要可见：事件追加词缀后（random_event_triggered）立即刷新显示。
	var banner_bus = root.get_node_or_null("EventBus")
	_expect(banner_bus != null, "EventBus exists for banner refresh")
	if banner_bus != null:
		banner_bus.random_event_triggered.emit(&"event_stone", Vector2i(-1, -1))
		await process_frame
	var hud_for_banner := game.get_node_or_null("UI/ScreenLayout/CombatHudSlot/CombatHud") as Control
	# 词缀横幅在 CombatHud 的 HudChromeLayer 下（CombatHud 直接子节点里没有 NightAffixRow）。
	var affix_row: Control = hud_for_banner.get_node_or_null("HudChromeLayer/NightAffixRow") as Control if hud_for_banner != null else null
	_expect(affix_row != null and affix_row.visible, "affix banner visible during day after event adds affix")
	var banner_event_panel := game.get_node_or_null("UI/ModalLayer/EventPanelSlot/EventPanel")
	if banner_event_panel != null and banner_event_panel.has_method("hide_event"):
		banner_event_panel.hide_event()

	# 赌约结算：未失血时累计额外三选一。
	run_state.night_core_damaged = false
	run_state.pending_extra_blessings = 0
	var game_controller := game.get_node_or_null("Managers/GameController")
	_expect(game_controller != null, "GameController exists")
	if game_controller != null:
		game_controller._on_night_cleared(1)
		_expect(int(run_state.pending_extra_blessings) == 1, "clean night pays extra blessing")
		_expect(not bool(run_state.night_wager_active), "wager resets after settlement")

	# 开局铺设：第 1 天一次性把本局母事件各投放一个到全图随机合法平地，取代旧的每日刷新/活跃上限。
	var run_event_cells: Array = event_manager.get_event_cells()
	var max_event_points := int(event_manager.get_max_active_event_points())
	_expect(run_event_cells.size() >= 1 and run_event_cells.size() <= max_event_points, "day1 spawns the run event set (1..mother count)")
	# 落点都应是非隐藏母事件，且每个母事件至多投放一个（铺设不重复）。
	var spawn_counts: Dictionary = {}
	var all_mother := true
	for raw_cell: Variant in run_event_cells:
		var spawned_id: StringName = event_manager.get_event_id_at_cell(raw_cell as Vector2i)
		if bool(event_manager.get_event_cfg(spawned_id).get("hidden_in_map_pool", false)):
			all_mother = false
		spawn_counts[spawned_id] = int(spawn_counts.get(spawned_id, 0)) + 1
	_expect(all_mother, "spawned events are all non-hidden mother events")
	var no_duplicate_spawn := true
	for spawned_id: Variant in spawn_counts.keys():
		if int(spawn_counts[spawned_id]) > 1:
			no_duplicate_spawn = false
	_expect(no_duplicate_spawn, "each mother event spawns at most once")

	# 人才市场·中端（event_market_mid，requires prestige 6）：6 声望随机得三名 4 费干员。
	run_state.prestige = 6
	var roster_before: int = (run_state.get_owned_operators() as Array).size()
	var hire: Dictionary = event_manager.apply_event(&"event_market_mid")
	_expect(hire.get("ok", false), "market mid applies")
	_expect((run_state.get_owned_operators() as Array).size() == roster_before + 3, "market mid grants three operators")
	_expect(run_state.prestige == 0, "market mid costs 6 prestige")

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
	var target_unit := StringName(offer.get("unit_id", ""))
	var target_covenant := StringName(offer.get("covenant", ""))
	var infuse: Dictionary = event_manager.apply_event_for_cell(altar_cell, StringName(offer.get("choice_id", "")))
	_expect(infuse.get("ok", false), "altar infusion applies")
	_expect(run_state.mana == 3, "altar infusion costs 2 mana")
	_expect((run_state.get_unit_covenants(target_unit) as Array).has(target_covenant), "unit type gains infused covenant")
	var future_operator: Dictionary = run_state.add_owned_operator(target_unit, "后续同名干员")
	var future_key := StringName(future_operator.get("key", ""))
	_expect((run_state.get_operator_covenants(future_key) as Array).has(target_covenant), "future same-unit operator inherits covenant")
	_expect(event_manager.get_event_id_at_cell(altar_cell) == StringName(), "altar consumed after infusion")

	# 祭坛：离开选项是动态生成的，不在静态配置里；必须映射到隐藏空事件并消耗事件点。
	var altar_leave_cell := Vector2i(6, 5)
	event_manager._events_by_cell[altar_leave_cell] = &"event_altar"
	var altar_leave: Dictionary = event_manager.apply_event_for_cell(altar_leave_cell, &"leave")
	_expect(altar_leave.get("ok", false), "altar leave applies")
	_expect(event_manager.get_event_id_at_cell(altar_leave_cell) == StringName(), "altar consumed after leave")

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
