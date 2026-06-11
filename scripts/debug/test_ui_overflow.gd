extends SceneTree

## UI 出界/截断/重叠 headless 回归 lint：
## 运行：Godot --headless --path . --script scripts/debug/test_ui_overflow.gd
##
## 检查项（仅可见节点，带裁剪感知：ScrollContainer/clip_contents 内被裁掉的部分不算出界）：
## 1. 节点尺寸小于自身最小尺寸（Label/Button 配置 autowrap、text_overrun_behavior、
##    clip_text 时最小尺寸自然缩小，等价于"已处理"，不会误报）。
## 2. 无裁剪祖先的节点越出 1920x1080 视口。
## 3. autowrap Label 竖向溢出：按当前宽度测量多行文本高度，超出节点高度判溢出。
## 4. 容器(Container)子节点 rect 越出父容器 rect。
## 5. 关键 HUD 模块两两重叠；敌情预览与右侧详情互斥同屏。
##
## 分级：WARN_PATHS 命中的节点只警告不计失败；WHITELIST 命中的为有意为之，直接跳过。
## 同构问题（动态列表里每张卡报一遍）按"去实例号路径+检查类型"去重，输出 xN 计数。

## 有意为之的节点（路径子串匹配），附原因注释。
const WHITELIST: Array[String] = [
	"DragGhost",  # 跟随鼠标的拖拽虚影，未拖拽时停在原点，允许越界
	"WavePreviewPanel x LegendPanel",  # 右列 VBox separation=-10 有意叠框互锁
	"UnitDetailPanel x LegendPanel",  # 同上，详情面板替换敌情预览时的同一交界
]

## 降级为警告的区域（当前为空；并行开发占用某面板时把路径子串加进来）。
const WARN_PATHS: Array[String] = []

const VIEWPORT_SIZE := Vector2(1920.0, 1080.0)
const RUN_SEED := 20260611

var _fatal: int = 0
var _warn: int = 0
var _game: Node = null
var _seen_findings: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_scene := load("res://scenes/game/Game.tscn") as PackedScene
	if game_scene == null:
		printerr("FAIL: load Game.tscn")
		quit(1)
		return
	_game = game_scene.instantiate()
	root.add_child(_game)
	for _i in range(12):
		await process_frame

	var run_state := root.get_node_or_null("/root/RunState")
	var data_repo := root.get_node_or_null("/root/DataRepo")
	var controller := _game.get_node_or_null("Managers/GameController")
	var shop := _game.get_node_or_null("Managers/ShopManager")
	var hud := _game.get_node_or_null("UI/ScreenLayout/CombatHudSlot/CombatHud")
	var hud_controller := _game.get_node_or_null("UI/CombatHudController")
	var build_panel := _game.get_node_or_null("UI/ScreenLayout/BuildPanelSlot/BuildPanel")
	var blessing_panel := _game.get_node_or_null("UI/ModalLayer/BlessingPanelSlot/BlessingPanel")
	if run_state == null or data_repo == null or controller == null or shop == null \
			or hud == null or hud_controller == null or build_panel == null or blessing_panel == null:
		printerr("FAIL: missing game nodes")
		quit(1)
		return

	# --- 状态 A：白天 1 默认 ---
	controller.start_new_run(RUN_SEED, &"standard")
	await _settle()
	_audit_state("day1_typical")

	# --- 状态 B：极端资源/满遗物/多干员 + 第 7 天 + 商店页 ---
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
		if (data_repo.get_unit_cfg(unit_id) as Dictionary).is_empty():
			continue
		run_state.add_owned_operator(unit_id, "", star)
		star = star % 3 + 1
	controller.enter_day(7)
	await _settle()
	_audit_state("day7_extreme")

	build_panel.call("_select_mode", &"shop")
	shop.try_buy_shop_slot(0)
	await _settle()
	_audit_state("shop_full_with_sold")

	# --- 状态 C：干员详情预览（最长技能文案） ---
	var preview_key := _find_operator_key(run_state, &"surtr")
	if preview_key != StringName():
		hud_controller.call("_show_operator_preview", preview_key)
		await _settle()
		_audit_state("operator_preview")
		hud.clear_unit_detail()
		await _settle()

	# --- 状态 D：遗物面板 / 设置面板 ---
	hud.toggle_relic_panel()
	await _settle()
	_audit_state("relic_panel_open")
	hud.toggle_relic_panel()
	await _settle()
	hud.toggle_settings_panel()
	await _settle()
	_audit_state("settings_panel_open")
	hud.toggle_settings_panel()
	await _settle()

	# --- 状态 E：祝福三选一（最长描述） ---
	blessing_panel.show_choices(_longest_desc_buffs(data_repo, 3))
	await _settle()
	_audit_state("blessing_panel_open")
	blessing_panel.hide_panel()
	await _settle()

	# --- 状态 F：夜晚 ---
	controller.enter_night()
	await _settle()
	_audit_state("night_phase")

	_game.queue_free()
	await process_frame
	_finish()


func _settle() -> void:
	for _i in range(8):
		await process_frame


func _finish() -> void:
	for dedup_key in _seen_findings:
		var count := int(_seen_findings[dedup_key])
		if count > 1:
			print("  (x%d) %s" % [count, dedup_key])
	if _fatal == 0:
		print("UI OVERFLOW TESTS PASSED (%d warnings)" % _warn)
		quit(0)
	else:
		printerr("UI OVERFLOW TESTS FAILED: %d fatal, %d warnings" % [_fatal, _warn])
		quit(1)


func _audit_state(state_name: String) -> void:
	var ui_layer := _game.get_node_or_null("UI")
	if ui_layer == null:
		_report(state_name, "UI", "missing", "UI CanvasLayer missing")
		return
	var viewport_rect := Rect2(Vector2.ZERO, VIEWPORT_SIZE)
	for child in ui_layer.get_children():
		if child is Control and (child as Control).visible:
			_walk_control(state_name, child as Control, viewport_rect, false)
	_check_module_overlaps(state_name)


## clip_rect：祖先裁剪链与视口的交集；has_clip：是否存在裁剪祖先。
func _walk_control(state_name: String, control: Control, clip_rect: Rect2, has_clip: bool) -> void:
	if not control.visible:
		return
	var rect := control.get_global_rect()
	# 被祖先完全裁掉的节点（滚动出视野）不可见，跳过自身检查，仍下钻子节点。
	var fully_clipped := has_clip and not clip_rect.intersects(rect)
	if not fully_clipped:
		_check_min_size(state_name, control)
		if not has_clip:
			_check_viewport_escape(state_name, control, rect)
		_check_autowrap_vertical(state_name, control)
		_check_container_escape(state_name, control)
	var child_clip := clip_rect
	var child_has_clip := has_clip
	if control.clip_contents or control is ScrollContainer:
		child_clip = clip_rect.intersection(rect)
		child_has_clip = true
	for child in control.get_children():
		if child is Control:
			_walk_control(state_name, child as Control, child_clip, child_has_clip)


func _check_min_size(state_name: String, control: Control) -> void:
	var min_size := control.get_combined_minimum_size()
	if control.size.x + 0.5 < min_size.x or control.size.y + 0.5 < min_size.y:
		_report(state_name, str(control.get_path()), "min-size",
			"smaller than minimum size: size=%s min=%s" % [control.size, min_size])


func _check_viewport_escape(state_name: String, control: Control, rect: Rect2) -> void:
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	var bounds := Rect2(Vector2.ZERO, VIEWPORT_SIZE)
	if rect.position.x < bounds.position.x - 0.5 \
			or rect.position.y < bounds.position.y - 0.5 \
			or rect.end.x > bounds.end.x + 0.5 \
			or rect.end.y > bounds.end.y + 0.5:
		_report(state_name, str(control.get_path()), "viewport",
			"outside viewport: rect=%s" % rect)


## autowrap Label：按当前宽度测量换行后的总高度，越出节点高度判竖向溢出。
func _check_autowrap_vertical(state_name: String, control: Control) -> void:
	var label := control as Label
	if label == null or label.text.is_empty():
		return
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		return
	if label.clip_text or label.max_lines_visible >= 0:
		return
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	if font == null or font_size <= 0:
		return
	var style := label.get_theme_stylebox(&"normal")
	var margin := Vector2.ZERO
	if style != null:
		margin = style.get_minimum_size()
	var inner_width := label.size.x - margin.x
	if inner_width <= 0.0:
		return
	var text_size := font.get_multiline_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, inner_width, font_size,
		-1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	var line_height := font.get_height(font_size)
	var line_count := maxi(1, int(round(text_size.y / maxf(1.0, line_height))))
	var spacing := label.get_theme_constant(&"line_spacing")
	var needed_height := text_size.y + float(spacing * (line_count - 1)) + margin.y
	if needed_height > label.size.y + 2.0:
		_report(state_name, str(label.get_path()), "wrap-overflow",
			"autowrap label vertical overflow: needs %.0fpx, has %.0fpx, text=\"%s\""
			% [needed_height, label.size.y, label.text.substr(0, 24)])


## 容器子节点不得越出容器自身 rect（滚动容器除外）。
func _check_container_escape(state_name: String, control: Control) -> void:
	var parent := control.get_parent()
	if parent == null or not (parent is Container) or parent is ScrollContainer:
		return
	var parent_control := parent as Container
	var parent_rect := parent_control.get_global_rect()
	var rect := control.get_global_rect()
	# 1px 容差，忽略零尺寸占位节点。
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	if rect.position.x < parent_rect.position.x - 1.0 \
			or rect.position.y < parent_rect.position.y - 1.0 \
			or rect.end.x > parent_rect.end.x + 1.0 \
			or rect.end.y > parent_rect.end.y + 1.0:
		_report(state_name, str(control.get_path()), "escape",
			"child escapes container: child=%s parent=%s" % [rect, parent_rect])


## 关键 HUD 模块两两不重叠；敌情预览与右侧详情互斥。
func _check_module_overlaps(state_name: String) -> void:
	var hud := _game.get_node_or_null("UI/ScreenLayout/CombatHudSlot/CombatHud")
	var modules: Array[Dictionary] = []
	var candidates := {
		"BuildPanel": _game.get_node_or_null("UI/ScreenLayout/BuildPanelSlot/BuildPanel"),
		"ActionPanel": _game.get_node_or_null("UI/ScreenLayout/ActionPanelSlot/ActionPanel"),
	}
	if hud != null:
		for module_name in ["TopBar", "RelicStrip", "WavePreviewPanel", "UnitDetailPanel", "LegendPanel", "DeployDeck", "SettingsButton"]:
			candidates[module_name] = hud.get_node_or_null("%%%s" % module_name)
	for module_name in candidates:
		var node: Control = candidates[module_name] as Control
		if node != null and node.is_visible_in_tree():
			modules.append({"name": module_name, "rect": node.get_global_rect()})
	for i in range(modules.size()):
		for j in range(i + 1, modules.size()):
			var a: Dictionary = modules[i]
			var b: Dictionary = modules[j]
			var rect_a := (a["rect"] as Rect2).grow(-2.0)
			var rect_b := (b["rect"] as Rect2).grow(-2.0)
			if rect_a.intersects(rect_b):
				_report(state_name, "%s x %s" % [a["name"], b["name"]], "overlap",
					"HUD modules overlap: %s=%s %s=%s" % [a["name"], a["rect"], b["name"], b["rect"]])
	var wave_visible := candidates.get("WavePreviewPanel") != null and (candidates["WavePreviewPanel"] as Control).is_visible_in_tree()
	var detail_visible := candidates.get("UnitDetailPanel") != null and (candidates["UnitDetailPanel"] as Control).is_visible_in_tree()
	if wave_visible and detail_visible:
		_report(state_name, "WavePreviewPanel x UnitDetailPanel", "mutex", "mutually exclusive panels visible together")


func _report(state_name: String, path_text: String, check_kind: String, message: String) -> void:
	for entry in WHITELIST:
		if path_text.contains(entry) or message.contains(entry):
			return
	# 动态列表（卡片、行）的同构问题去重：剥离 @Node@123 实例号后相同视为一条。
	var instance_regex := RegEx.create_from_string("@[A-Za-z0-9_]*@\\d+")
	var normalized_path := instance_regex.sub(path_text, "*", true)
	var dedup_key := "%s|%s|%s" % [state_name, check_kind, normalized_path]
	if _seen_findings.has(dedup_key):
		_seen_findings[dedup_key] = int(_seen_findings[dedup_key]) + 1
		return
	_seen_findings[dedup_key] = 1
	var is_warn := false
	for entry in WARN_PATHS:
		if path_text.contains(entry) or message.contains(entry):
			is_warn = true
			break
	if is_warn:
		_warn += 1
		print("WARN [%s][%s] %s | %s" % [state_name, check_kind, normalized_path, message])
	else:
		_fatal += 1
		printerr("FATAL [%s][%s] %s | %s" % [state_name, check_kind, normalized_path, message])


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
