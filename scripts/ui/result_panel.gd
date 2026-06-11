extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

var _win := false
var _verdict_rim: Panel = null
var _stats_grid: GridContainer = null
var _footer_row: HBoxContainer = null


func set_result(win: bool) -> void:
	_win = win
	AppTheme.apply(self)
	var verdict_color := GameUiStyle.SUCCESS if win else GameUiStyle.DANGER_BRIGHT
	var title := get_node_or_null("%ResultLabel") as Label
	if title != null:
		title.text = "✦ 胜利" if win else "✕ 失败"
		var title_font := FontVariation.new()
		title_font.base_font = AppTheme.FONT_CN
		title_font.set_spacing(TextServer.SPACING_GLYPH, 4)
		title.add_theme_font_override("font", title_font)
		title.add_theme_color_override("font_color", verdict_color)
		title.add_theme_color_override(
			"font_outline_color", Color(verdict_color.r, verdict_color.g, verdict_color.b, 0.3)
		)
		title.add_theme_constant_override("outline_size", 6)
	var summary := get_node_or_null("%ResultSummaryLabel") as Label
	if summary != null:
		summary.text = "核心仍在发光，守夜防线挺过了这一轮。" if win else "核心防线被突破，敌群已占领阵地。"
		summary.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_update_verdict_rim(verdict_color)
	_rebuild_stats()
	_reorder_rows()


## 结算页脚:把场景层的动作按钮收进面板内,统一构图(运行时迁移,避免跨场景搬节点)。
func adopt_action_buttons(retry_button: Button, menu_button: Button) -> void:
	var vbox := _content_vbox()
	if vbox == null:
		return
	if _footer_row == null or not is_instance_valid(_footer_row):
		_footer_row = HBoxContainer.new()
		_footer_row.name = "FooterRow"
		_footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_footer_row.add_theme_constant_override("separation", 16)
		vbox.add_child(_footer_row)
	for button: Button in [retry_button, menu_button]:
		if button == null or not is_instance_valid(button):
			continue
		button.custom_minimum_size = Vector2(206.0, 52.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if button.get_parent() != _footer_row:
			button.reparent(_footer_row, false)
	_reorder_rows()


func _ready() -> void:
	AppTheme.apply(self)
	set_result(_win)


func _update_verdict_rim(color: Color) -> void:
	var card := get_node_or_null("%ResultCard") as PanelContainer
	if card == null:
		return
	if _verdict_rim == null or not is_instance_valid(_verdict_rim):
		# 有意叠层:胜负判定内沿光,与外层金属框非冗余叠框
		_verdict_rim = Panel.new()
		_verdict_rim.name = "VerdictRim"
		_verdict_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(_verdict_rim)
		card.move_child(_verdict_rim, 0)
	_verdict_rim.add_theme_stylebox_override(
		"panel", GameUiStyle.flat_box(Color.TRANSPARENT, color, 2.0, 4.0)
	)


func _rebuild_stats() -> void:
	var vbox := _content_vbox()
	if vbox == null:
		return
	if _stats_grid != null and is_instance_valid(_stats_grid):
		vbox.remove_child(_stats_grid)
		_stats_grid.free()
		_stats_grid = null
	var entries := _collect_stat_entries()
	if entries.is_empty():
		return
	_stats_grid = GridContainer.new()
	_stats_grid.name = "StatsGrid"
	_stats_grid.columns = 2
	_stats_grid.add_theme_constant_override("h_separation", 10)
	_stats_grid.add_theme_constant_override("v_separation", 8)
	for entry in entries:
		_stats_grid.add_child(_build_stat_cell(String(entry[0]), String(entry[1])))
	vbox.add_child(_stats_grid)


func _collect_stat_entries() -> Array:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return []
	var entries: Array = [
		["存活天数", "第 %d 天" % int(run_state.get("day"))],
		["核心耐久", "%d / %d" % [int(run_state.get("core_hp")), int(run_state.get("core_hp_max"))]],
		["在编干员", "%d 名" % (run_state.get("owned_operators") as Array).size()],
		["获得祝福", "%d 项" % (run_state.get("buffs") as Array).size()],
	]
	if String(run_state.get("run_mode")) != "tutorial":
		entries.append(["剩余威望", str(int(run_state.get("prestige")))])
	return entries


func _build_stat_cell(stat_name: String, stat_value: String) -> PanelContainer:
	var cell := PanelContainer.new()
	var row_style := GameUiStyle.result_stat_row().duplicate() as StyleBox
	row_style.content_margin_top = 5.0
	row_style.content_margin_bottom = 5.0
	cell.add_theme_stylebox_override("panel", row_style)
	cell.custom_minimum_size = Vector2(0.0, 28.0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = stat_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = stat_value
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	row.add_child(value_label)
	cell.add_child(row)
	return cell


func _reorder_rows() -> void:
	var vbox := _content_vbox()
	if vbox == null:
		return
	if _stats_grid != null and is_instance_valid(_stats_grid):
		vbox.move_child(_stats_grid, vbox.get_child_count() - 1)
	if _footer_row != null and is_instance_valid(_footer_row):
		vbox.move_child(_footer_row, vbox.get_child_count() - 1)


func _content_vbox() -> VBoxContainer:
	return get_node_or_null("CenterContainer/ResultCard/ContentMargin/VBoxContainer") as VBoxContainer
