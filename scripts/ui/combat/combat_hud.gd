extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const EnemyIconHelper = preload("res://scripts/ui/combat/enemy_icon_helper.gd")

signal operator_card_pressed(operator_key: StringName)
signal operator_card_drag_started(operator_key: StringName)
signal pause_pressed
signal speed_1_pressed
signal speed_2_pressed
signal cast_skill_requested
signal retreat_requested
signal operator_sell_requested(operator_key: StringName)
signal shop_unit_purchase_requested(slot_index: int)
signal wave_route_preview_toggled(enabled: bool)

const OPERATOR_CARD_SCENE := preload("res://scenes/ui/combat/OperatorCard.tscn")
const RESOURCE_ORDER: Array[StringName] = [&"ap", &"prestige", &"wood", &"stone", &"mana"]
const CORE_HP_TITLE := "核心生命"
const LEVEL_INTRO_WIDTH_RATIO := 0.56
const LEVEL_INTRO_MIN_WIDTH := 560.0
const LEVEL_INTRO_MAX_WIDTH := 820.0
const LEVEL_INTRO_HEIGHT := 178.0
const LEVEL_INTRO_TOP_RATIO := 0.15
const LEVEL_INTRO_MIN_TOP := 124.0

const SPEED_ACTIVE_OVERLAY_ALPHA := 0.72
const BULLET_TIME_OVERLAY_ALPHA := 1.0
const MESSAGE_CHIP_BASE_Z := 0
const MESSAGE_CHIP_CONTENT_Z := 2
const MESSAGE_NORMAL_ICON := &"top_enemy_queue"
const MESSAGE_WARNING_ICON := &"button_cancel"
const DEPLOY_SCROLLBAR_STEP := 48
const WAVE_PREVIEW_NORMAL_HEIGHT := 316.0
const WAVE_PREVIEW_COMPACT_HEIGHT := 208.0
const RESOURCE_DELTA_GAIN_COLOR := Color(0.440, 0.650, 0.470, 1.0)
const RESOURCE_DELTA_LOSS_COLOR := Color(0.720, 0.340, 0.310, 1.0)
const RESOURCE_DELTA_NEUTRAL_COLOR := Color(0.850, 0.850, 0.800, 1.0)
const RESOURCE_DELTA_OUTLINE_SIZE := 0
const MESSAGE_WARNING_TOKENS := [
	"失败",
	"无法",
	"不能",
	"不可",
	"不足",
	"无效",
	"没有可",
	"尚未",
	"未选中",
	"未选择",
	"先选择",
	"冷却中",
	"无路",
	"封死",
	"警告"
]
const MESSAGE_TEXT_OVERRIDES := {
	"APP_REFS_MISSING": "操作失败：运行时服务不可用",
	"BUILDING_CONFIG_MISSING": "建造失败：建筑配置缺失",
	"BUILDING_DESTROYED": "操作失败：建筑已损毁",
	"BUILDING_NOT_DESTROYED": "无法修复：建筑尚未完全损毁",
	"BUILDING_NOT_FOUND": "操作失败：找不到目标建筑",
	"BUILDING_NOT_TOGGLEABLE": "无法切换：该建筑没有开关状态",
	"BUILDING_SCENE_MISSING": "建造失败：建筑场景缺失",
	"CANCELED": "操作失败：部署流程已取消",
	"CELL_ALREADY_HAS_BUILDING": "无法建造：目标格已有建筑",
	"CELL_BLOCKED": "无法建造：目标格不可通行",
	"CELL_HAS_BUILDING": "无法建造：目标格已有建筑",
	"CELL_HAS_UNIT": "无法建造：目标格已有部署单位",
	"CELL_IS_CORE": "无法建造：不能建在核心上",
	"CELL_IS_SPAWN": "无法建造：不能建在出怪点上",
	"CELL_MISSING": "操作失败：目标格数据缺失",
	"CELL_NOT_BUILDABLE": "无法建造：目标格不可建造",
	"CELL_NOT_DISCOVERED": "无法部署：目标格尚未探索",
	"CELL_NOT_FOUND": "操作失败：目标格数据不可用",
	"CELL_NOT_WALKABLE": "无法部署：目标格不可部署",
	"CELL_OUT_OF_BOUNDS": "操作失败：目标格不在地图内",
	"CELL_OUT_OF_RANGE": "无法部署：目标格不在地图内",
	"DEPLOY_LIMIT_REACHED": "无法部署：部署上限已满",
	"INVALID_PHASE": "操作失败：当前阶段不允许该操作",
	"MAP_MANAGER_MISSING": "操作失败：地图管理器不可用",
	"MAP_UNAVAILABLE": "操作失败：地图尚未初始化",
	"NOT_ENOUGH_ACTION_POINTS": "资源不足：行动力不足",
	"NOT_ENOUGH_AP": "资源不足：行动力不足",
	"NOT_ENOUGH_MATERIALS": "资源不足：材料不足",
	"OPERATOR_COOLDOWN": "无法部署：干员正在再部署冷却中",
	"OPERATOR_DEPLOYED": "无法部署：干员已经在场",
	"OPERATOR_NOT_OWNED": "无法部署：未拥有该干员",
	"PLACE_RULE_MISMATCH": "无法建造：目标格不满足放置规则",
	"RUN_STATE_MISSING": "操作失败：运行状态不可用",
	"SCENE_MISSING": "操作失败：场景资源缺失",
	"SHOP_SLOT_EMPTY": "购买失败：商店槽位为空",
	"SHOP_SLOT_INVALID": "购买失败：商店槽位无效",
	"SHOP_SLOT_SOLD": "购买失败：该槽位已购买",
	"SP_NOT_READY": "无法释放技能：技力尚未准备好",
	"UNIT_MANAGER_MISSING": "操作失败：单位管理器不可用",
	"UNIT_NOT_FOUND": "操作失败：找不到单位配置",
	"UNKNOWN_PLACE_RULE": "无法建造：未知放置规则",
	"WORLD_NOT_READY": "操作失败：战场节点尚未就绪"
}

var _cards_by_operator_key: Dictionary = {}
var _resource_item_controls: Dictionary = {}
var _open_panel_stack: Array[StringName] = []
var _core_hp_ratio := 0.0
var _core_hp_current := 0
var _core_hp_max := 0
var _message_warning_active := false
var _bullet_time_feedback_tween: Tween
var _level_intro_tween: Tween
var _wave_level_name_label: Label
var _wave_desc_label: Label
var _wave_summary_label: Label
var _wave_spawn_cards_box: VBoxContainer
var _wave_spawn_card_template: PanelContainer
var _wave_enemy_card_template: PanelContainer
var _wave_warning_row: Control
var _wave_warning_label: Label
var _night_affix_row: PanelContainer
var _night_affix_label: Label
var _wave_countdown_row: PanelContainer
var _wave_countdown_label: Label
var _active_gates_line: Label = null
var _event_count_line: Label = null
var _wave_preview_available := false
var _right_detail_active := false
var _level_intro_banner: Control
var _level_intro_content: VBoxContainer
var _level_intro_day_label: Label
var _level_intro_name_label: Label
var _level_intro_desc_label: Label
var _level_intro_line: ColorRect

@onready var _settings_button: Button = %SettingsButton
@onready var _settings_panel: Control = %AudioSettingsPanel
@onready var _top_bar: Control = %TopBar
@onready var _top_content: MarginContainer = _top_bar.get_node_or_null("TopContent") as MarginContainer
@onready var _top_content_row: HBoxContainer = _top_bar.get_node_or_null("TopContent/TopContentRow") as HBoxContainer
var _covenant_row: HBoxContainer = null
@onready var _stage_chip: Control = %StageChip
@onready var _core_chip: Control = %CoreChip
@onready var _deploy_chip: Control = %DeployChip
@onready var _message_chip: Control = %MessageChip
@onready var _time_controls: Control = %TimeControls
@onready var _speed_toggle_base: Panel = %SpeedToggleBase
@onready var _speed_active_overlay: Panel = %SpeedActiveOverlay
@onready var _bullet_time_overlay: Control = %BulletTimeOverlay
@onready var _resource_chip: Control = %ResourceChip
@onready var _resource_items_row: HBoxContainer = %ResourceItemsRow
@onready var _core_label: Label = %CoreLabel
@onready var _core_track: Panel = %CoreTrack
@onready var _core_clip: Control = %CoreClip
@onready var _core_fill: Panel = %CoreFill
@onready var _deploy_label: Label = %DeployLabel
@onready var _queue_label: Label = %QueueLabel
@onready var _message_label: Label = %MessageLabel
@onready var _message_icon_texture: TextureRect = _message_chip.get_node_or_null("ChipIconTexture") as TextureRect
@onready var _pause_button: Button = %PauseButton
@onready var _speed_1_button: Button = %Speed1Button
@onready var _speed_2_button: Button = %Speed2Button
@onready var _relic_strip: Control = %RelicStrip
@onready var _relic_panel: Control = %RelicPanel
@onready var _wave_preview_panel: Control = %WavePreviewPanel
@onready var _wave_preview_content: VBoxContainer = _wave_preview_panel.get_node_or_null("WavePreviewMargin/WavePreviewContent") as VBoxContainer
@onready var _wave_preview_title_label: Label = %WavePreviewTitleLabel
@onready var _wave_route_toggle: Button = %WaveRouteToggle
@onready var _wave_preview_scroll: ScrollContainer = %WavePreviewScroll
@onready var _wave_preview_label: Label = %WavePreviewLabel
@onready var _deck_panel: Control = %DeployDeck
@onready var _deck_scroll: ScrollContainer = _deck_panel.get_node_or_null("DeckMargin/ScrollContainer") as ScrollContainer
@onready var _deck_container: HBoxContainer = %DeployDeckContainer
@onready var _detail_panel: Control = %UnitDetailPanel
@onready var _legend_panel: Control = %LegendPanel
@onready var _drag_ghost: Control = %DragGhost
@onready var _drag_ghost_base: Panel = %DragGhostBase
@onready var _drag_ghost_label: Label = %DragGhostLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	set_process_unhandled_input(true)
	AppTheme.apply(self)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_speed_toggle_base.visible = true
	_speed_toggle_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_core_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_core_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_core_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_core_track.resized.connect(_refresh_core_fill)
	_core_clip.resized.connect(_refresh_core_fill)
	_collect_resource_items()
	_style_top_cards()
	_setup_message_chip_state()
	_wave_preview_title_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	_wave_preview_title_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	_wave_preview_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_wave_preview_title_label.add_theme_constant_override("shadow_offset_y", 0)
	_wave_preview_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_wave_preview_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	_wave_preview_label.add_theme_constant_override("shadow_offset_x", 0)
	_wave_preview_label.add_theme_constant_override("shadow_offset_y", 0)
	_wave_route_toggle.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	_style_wave_route_toggle()
	_bind_wave_preview_nodes()
	_ensure_level_intro_banner()
	_setup_deploy_deck_scroll()
	_style_legend_panel()
	_speed_active_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_active_overlay.modulate = Color(1.0, 1.0, 1.0, SPEED_ACTIVE_OVERLAY_ALPHA)
	_bullet_time_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bullet_time_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_bullet_time_overlay.visible = false
	_wave_preview_panel.z_index = 18
	_deck_panel.z_index = 12
	_deck_panel.visible = _deck_container.get_child_count() > 0
	_legend_panel.z_index = 14
	_detail_panel.z_index = 40
	_drag_ghost_base.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_CARD, GameUiStyle.BG_CARD, GameUiStyle.AMBER, false))
	_drag_ghost_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_speed_1_button.pressed.connect(func() -> void: speed_1_pressed.emit())
	_speed_2_button.pressed.connect(func() -> void: speed_2_pressed.emit())
	_wave_route_toggle.toggled.connect(func(enabled: bool) -> void: wave_route_preview_toggled.emit(enabled))
	_bind_overlay_panels()
	if _detail_panel.has_signal("cast_skill_requested"):
		_detail_panel.cast_skill_requested.connect(func() -> void: cast_skill_requested.emit())
	if _detail_panel.has_signal("retreat_requested"):
		_detail_panel.retreat_requested.connect(func() -> void: retreat_requested.emit())
	if _detail_panel.has_signal("sell_requested"):
		_detail_panel.sell_requested.connect(func(operator_key: StringName) -> void: operator_sell_requested.emit(operator_key))
	if _detail_panel.has_signal("purchase_requested"):
		_detail_panel.purchase_requested.connect(func(slot_index: int) -> void: shop_unit_purchase_requested.emit(slot_index))
	_style_top_button(_pause_button, false)
	_style_top_button(_speed_1_button, false)
	_style_top_button(_speed_2_button, false)
	_drag_ghost.visible = false
	_refresh_core_fill()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_refresh_core_fill()


func _input(event: InputEvent) -> void:
	_handle_overlay_shortcut(event)


func _unhandled_input(event: InputEvent) -> void:
	_handle_overlay_shortcut(event)


func _handle_overlay_shortcut(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if _is_text_input_focused():
		return
	if key_event.keycode == KEY_R:
		toggle_relic_panel()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and close_top_panel():
		get_viewport().set_input_as_handled()


func _is_text_input_focused() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func set_top_values(core_text: String, deploy_text: String, queue_text: String) -> void:
	_core_label.text = _core_title_from_text(core_text)
	_deploy_label.text = deploy_text
	_queue_label.text = queue_text
	_apply_chip_icon(_stage_chip, _phase_icon_id_for_text(queue_text))
	_apply_chip_icon(_core_chip, &"top_core_hp")
	_apply_chip_icon(_deploy_chip, &"top_deploy_limit")
	_apply_message_state(_message_warning_active)
	_set_core_progress_from_text(core_text)


func set_core_hp(current: int, max_value: int) -> void:
	_core_hp_current = maxi(current, 0)
	_core_hp_max = maxi(max_value, 0)
	if _core_hp_max <= 0:
		_core_hp_ratio = 0.0
		var tooltip_missing := "%s --/--" % CORE_HP_TITLE
		_core_chip.tooltip_text = tooltip_missing
		_core_track.tooltip_text = tooltip_missing
		_core_clip.tooltip_text = tooltip_missing
		_core_fill.tooltip_text = tooltip_missing
	else:
		_core_hp_current = mini(_core_hp_current, _core_hp_max)
		_core_hp_ratio = clampf(float(_core_hp_current) / float(_core_hp_max), 0.0, 1.0)
		var tooltip_value := "%s %d/%d" % [CORE_HP_TITLE, _core_hp_current, _core_hp_max]
		_core_chip.tooltip_text = tooltip_value
		_core_track.tooltip_text = tooltip_value
		_core_clip.tooltip_text = tooltip_value
		_core_fill.tooltip_text = tooltip_value
	_core_label.text = _format_core_hp_label()
	_refresh_core_fill()


func show_message(text_value: String, warning := false) -> void:
	var display_text := _localized_message_text(text_value)
	_message_label.text = display_text
	var warning_state: bool = warning or _is_warning_message(display_text) or _is_warning_message(text_value)
	_apply_message_state(warning_state)


func set_resource_values(resource_text: String, tooltip_text_value: String = "") -> void:
	set_resource_items({
		&"ap": {"value": resource_text.replace("\n", " ")}
	}, tooltip_text_value)


func set_resource_items(resource_items: Dictionary, tooltip_text_value: String = "") -> void:
	for resource_key in RESOURCE_ORDER:
		var item: Dictionary = _resource_item_controls.get(resource_key, {})
		if item.is_empty():
			continue
		var root := item.get("root") as Control
		var icon_texture := item.get("icon_texture") as TextureRect
		var value_label := item.get("value") as Label
		var delta_label := item.get("delta") as Label
		var delta_badge := item.get("delta_badge") as Control
		if root == null or icon_texture == null or value_label == null:
			continue
		var data: Dictionary = resource_items.get(resource_key, {})
		if data.is_empty():
			root.visible = false
			continue
		root.visible = true
		root.tooltip_text = String(data.get("tooltip", tooltip_text_value))
		var texture := UiArtRegistry.get_catalog_icon(StringName(data.get("icon_key", "resource_%s" % String(resource_key))))
		icon_texture.texture = texture
		icon_texture.visible = texture != null
		value_label.text = "%s\n%s" % [
			String(data.get("label", _resource_display_name(resource_key))),
			String(data.get("value", "--"))
		]
		var delta_text := String(data.get("delta", "--")).strip_edges()
		var delta_sign := int(data.get("delta_sign", 0))
		if delta_text.is_empty():
			delta_text = "--"
			delta_sign = 0
		if delta_label != null:
			delta_label.text = delta_text
			_apply_resource_delta_label_style(delta_label, delta_sign)
			delta_label.visible = true
		if delta_badge != null:
			delta_badge.visible = true
			delta_badge.z_index = 6


func set_relics(relic_ids: Array[StringName]) -> void:
	if _relic_strip != null and _relic_strip.has_method("set_relics"):
		_relic_strip.set_relics(relic_ids)
	if _relic_panel != null and _relic_panel.has_method("set_relics"):
		_relic_panel.set_relics(relic_ids)


# 刷新盟约横条。entries 来自 EventBus.covenants_changed（仅含人数≥1 的盟约）。
# 横条单独成行，置于顶栏下方，不挤占原有顶栏排版。
func update_covenants(entries: Array) -> void:
	_ensure_covenant_row()
	if _covenant_row == null:
		return
	for child in _covenant_row.get_children():
		child.queue_free()
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY:
			_covenant_row.add_child(_build_covenant_chip(entry))


func _ensure_covenant_row() -> void:
	if _covenant_row != null and is_instance_valid(_covenant_row):
		return
	# 独立定位条：紧贴顶栏下方，与 TopHudSlot 左边缘对齐。
	var slot := Control.new()
	slot.name = "CovenantSlot"
	slot.position = Vector2(66, 96)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	_covenant_row = HBoxContainer.new()
	_covenant_row.name = "CovenantRow"
	_covenant_row.add_theme_constant_override("separation", 8)
	slot.add_child(_covenant_row)


func _build_covenant_chip(entry: Dictionary) -> Control:
	var tier := int(entry.get("tier", 0))
	var count := int(entry.get("count", 0))
	var layers := int(entry.get("layers", 0))
	var cov_name := String(entry.get("name", ""))
	var active := tier >= CovenantDefs.TIER_PAIR
	var trio := tier >= CovenantDefs.TIER_TRIO

	# 复用顶栏状态 chip 的样式：激活态用 AMBER 描边高亮。
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", GameUiStyle.hud_cell(active))
	chip.mouse_filter = Control.MOUSE_FILTER_STOP

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	chip.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	var mark := "③" if trio else ("②" if active else "")
	var name_label := Label.new()
	name_label.text = cov_name + ((" " + mark) if mark != "" else "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", GameUiStyle.AMBER if active else GameUiStyle.TEXT_INVERTED_DIM)
	vbox.add_child(name_label)

	var info_label := Label.new()
	info_label.text = "%d人 · %d层" % [count, layers]
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED if active else GameUiStyle.TEXT_MUTED)
	vbox.add_child(info_label)

	var lines: Array = CovenantDefs.describe(StringName(entry.get("id", "")), layers)
	var tip := "%s（%d人激活）" % [cov_name, tier] if active else "%s（未激活，需 %d 人）" % [cov_name, CovenantDefs.TIER_PAIR]
	tip += "\n盟约层数：当前计入该盟约的干员星级总和。"
	if not lines.is_empty():
		tip += "\n" + "\n".join(lines)
	chip.tooltip_text = tip
	return chip


func _apply_resource_delta_label_style(label: Label, delta_sign: int) -> void:
	var color := RESOURCE_DELTA_NEUTRAL_COLOR
	if delta_sign < 0:
		color = RESOURCE_DELTA_LOSS_COLOR
	elif delta_sign > 0:
		color = RESOURCE_DELTA_GAIN_COLOR
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", color)
	label.add_theme_constant_override("outline_size", RESOURCE_DELTA_OUTLINE_SIZE)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)


func toggle_relic_panel() -> void:
	if _relic_panel == null:
		return
	if _relic_panel.visible:
		_hide_overlay_panel(&"relic")
	else:
		_show_overlay_panel(&"relic")


func toggle_settings_panel() -> void:
	if _settings_panel == null:
		return
	if _settings_panel.visible:
		_hide_overlay_panel(&"settings")
	else:
		_show_overlay_panel(&"settings")


func close_top_panel() -> bool:
	while not _open_panel_stack.is_empty():
		var panel_name: StringName = _open_panel_stack.pop_back()
		var panel := _panel_for_name(panel_name)
		if panel != null and panel.visible:
			_hide_overlay_panel(panel_name)
			return true
	if _settings_panel != null and _settings_panel.visible:
		_hide_overlay_panel(&"settings")
		return true
	if _relic_panel != null and _relic_panel.visible:
		_hide_overlay_panel(&"relic")
		return true
	return false


func set_wave_preview_text(text_value: String, show_panel: bool = true) -> void:
	_set_wave_preview_v2_visible(false)
	_wave_preview_label.text = text_value
	_wave_preview_label.visible = true
	_wave_preview_available = show_panel and not text_value.strip_edges().is_empty()
	_apply_right_column_visibility()


func set_wave_preview_data(data: Dictionary, show_panel: bool = true) -> void:
	_bind_wave_preview_nodes()
	var has_content := show_panel and not data.is_empty()
	_wave_preview_available = has_content
	_set_wave_preview_v2_visible(has_content)
	_wave_preview_label.visible = false
	if not has_content:
		_apply_right_column_visibility()
		return

	var day := int(data.get("day", 0))
	var name := String(data.get("name", data.get("template_id", "今夜")))
	var desc := String(data.get("desc", "")).strip_edges()
	var total_count := int(data.get("total_count", 0))
	var spawn_order: Array = data.get("spawn_order", [])
	var entries: Array = data.get("entries", [])
	var active_spawn_count := spawn_order.size()
	_wave_preview_title_label.text = "DAY %d · 今夜" % day if day > 0 else "今夜"
	_wave_level_name_label.text = name
	_wave_desc_label.text = desc
	_wave_desc_label.visible = not desc.is_empty()
	var wave_count := int(data.get("wave_count", 1))
	if wave_count > 1:
		_wave_summary_label.text = "共 %d 波 · 合计来袭 %d · 活跃出怪口 %d" % [wave_count, total_count, active_spawn_count]
	else:
		_wave_summary_label.text = "合计来袭 %d · 活跃出怪口 %d" % [total_count, active_spawn_count]
	_rebuild_wave_spawn_cards_by_wave(data.get("waves", []), spawn_order, entries, data.get("key_enemies", []))
	_wave_warning_label.text = _format_wave_warning_text(data)
	_wave_warning_row.visible = not _wave_warning_label.text.strip_edges().is_empty()
	_apply_right_column_visibility()


func play_level_intro(day: int, name: String, desc: String) -> void:
	_ensure_level_intro_banner()
	if _level_intro_banner == null:
		return
	if _level_intro_tween != null:
		_level_intro_tween.kill()
	_level_intro_day_label.text = "DAY %d · 今夜" % day
	_level_intro_name_label.text = name
	_level_intro_desc_label.text = desc
	_level_intro_desc_label.visible = not desc.strip_edges().is_empty()
	_level_intro_banner.visible = true
	_level_intro_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var target_rect := _level_intro_content_rect(0.0)
	_apply_level_intro_content_rect(_level_intro_content_rect(18.0))
	_level_intro_line.scale.x = 0.0
	_level_intro_tween = create_tween()
	_level_intro_tween.set_parallel(true)
	_level_intro_tween.tween_property(_level_intro_banner, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22)
	_level_intro_tween.tween_property(_level_intro_content, "offset_top", target_rect.position.y, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_level_intro_tween.tween_property(_level_intro_content, "offset_bottom", target_rect.end.y, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_level_intro_tween.tween_property(_level_intro_line, "scale:x", 1.0, 0.34).set_delay(0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_level_intro_tween.set_parallel(false)
	var hold_time := 1.45 + minf(float(desc.length()) * 0.006, 0.65)
	_level_intro_tween.tween_interval(hold_time)
	_level_intro_tween.tween_property(_level_intro_banner, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.32)
	_level_intro_tween.tween_callback(func() -> void:
		if _level_intro_banner != null:
			_level_intro_banner.visible = false
	)


func set_wave_route_preview_enabled(enabled: bool) -> void:
	_wave_route_toggle.set_pressed_no_signal(enabled)


func set_time_controls(paused: bool, speed: float, enabled: bool = true) -> void:
	_pause_button.disabled = not enabled
	_speed_1_button.disabled = not enabled
	_speed_2_button.disabled = not enabled
	var effective_paused := paused and enabled
	var pause_selected := effective_paused
	var speed_1_selected := false
	var speed_2_selected := false
	if enabled and not effective_paused:
		speed_1_selected = is_equal_approx(speed, 1.0)
		speed_2_selected = is_equal_approx(speed, 2.0)
	var pause_texture := UiArtRegistry.get_catalog_icon(&"top_play" if pause_selected else &"top_pause")
	_pause_button.text = "" if pause_texture != null else "暂停"
	GameUiStyle.set_button_texture_icon(_pause_button, pause_texture, &"center")
	GameUiStyle.set_button_texture_icon(_speed_1_button, null)
	GameUiStyle.set_button_texture_icon(_speed_2_button, null)
	_style_top_button(_pause_button, false)
	_style_top_button(_speed_1_button, false)
	_style_top_button(_speed_2_button, false)
	var active_time_button: Button = null
	if pause_selected:
		active_time_button = _pause_button
	elif speed_1_selected:
		active_time_button = _speed_1_button
	elif speed_2_selected:
		active_time_button = _speed_2_button
	call_deferred("_place_speed_active_overlay", active_time_button)


func set_bullet_time_feedback(active: bool, _scale: float = 0.2) -> void:
	if _bullet_time_overlay == null:
		return
	if _bullet_time_feedback_tween != null:
		_bullet_time_feedback_tween.kill()
	if active:
		_bullet_time_overlay.visible = true
		_bullet_time_overlay.modulate = Color(1.0, 1.0, 1.0, BULLET_TIME_OVERLAY_ALPHA)
		return
	_bullet_time_feedback_tween = create_tween()
	_bullet_time_feedback_tween.tween_property(_bullet_time_overlay, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.12)
	_bullet_time_feedback_tween.tween_callback(func() -> void:
		if _bullet_time_overlay != null:
			_bullet_time_overlay.visible = false
	)


func set_operators(operators: Array[Dictionary]) -> void:
	for child in _deck_container.get_children():
		child.queue_free()
	_cards_by_operator_key.clear()
	_deck_panel.visible = not operators.is_empty()
	_deck_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_deck_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_deck_container.custom_minimum_size = Vector2.ZERO
	for operator_info in operators:
		var operator_key := StringName((operator_info as Dictionary).get("key", ""))
		var card = OPERATOR_CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.setup(operator_key, operator_info)
		card.operator_card_pressed.connect(func(key: StringName) -> void: operator_card_pressed.emit(key))
		if card.has_signal("operator_card_drag_started"):
			card.connect(&"operator_card_drag_started", func(key: StringName) -> void: operator_card_drag_started.emit(key))
		_deck_container.add_child(card)
		_cards_by_operator_key[operator_key] = card
	if _deck_scroll != null:
		_deck_scroll.scroll_horizontal = 0
	call_deferred("_refresh_deploy_deck_scroll_content")


func set_operator_card(operator_key: StringName, text_value: String, state: StringName) -> void:
	var card = _cards_by_operator_key.get(operator_key)
	if card != null and card.has_method("set_state_text"):
		card.set_state_text(text_value, state)


func set_operator_card_visible(operator_key: StringName, visible: bool) -> void:
	var card := _cards_by_operator_key.get(operator_key) as Control
	if card == null or card.visible == visible:
		return
	card.visible = visible
	call_deferred("_refresh_deploy_deck_scroll_content")


func show_drag_ghost(text_value: String) -> void:
	_drag_ghost_label.text = text_value
	_drag_ghost.visible = true
	move_drag_ghost(get_viewport().get_mouse_position())


func move_drag_ghost(position_value: Vector2) -> void:
	if _drag_ghost.visible:
		_drag_ghost.position = position_value + Vector2(18.0, 18.0)


func hide_drag_ghost() -> void:
	_drag_ghost.visible = false


func show_unit_detail(unit: Node, display_name: String, damage_label: String, direction_label: String) -> void:
	if _detail_panel.has_method("show_unit"):
		_detail_panel.show_unit(unit, display_name, damage_label, direction_label)
	_set_right_detail_active(unit != null)


func show_operator_preview(operator_info: Dictionary, unit_cfg: Dictionary, state: StringName, status_text: String = "", sell_refund: int = 1) -> void:
	if _detail_panel.has_method("show_operator_preview"):
		_detail_panel.show_operator_preview(operator_info, unit_cfg, state, status_text, sell_refund)
	_set_right_detail_active(true)


func show_shop_unit_preview(slot_index: int, unit_id: StringName, unit_cfg: Dictionary, price: int, can_purchase: bool, disabled_reason: String = "") -> void:
	if _detail_panel.has_method("show_shop_unit_preview"):
		_detail_panel.show_shop_unit_preview(slot_index, unit_id, unit_cfg, price, can_purchase, disabled_reason)
	_set_right_detail_active(true)


func clear_unit_detail() -> void:
	if _detail_panel.has_method("clear_unit"):
		_detail_panel.clear_unit()
	_set_right_detail_active(false)


func _set_right_detail_active(active: bool) -> void:
	_right_detail_active = active
	_apply_right_column_visibility()


func _apply_right_column_visibility() -> void:
	if _wave_preview_panel != null:
		_wave_preview_panel.visible = _wave_preview_available
		_wave_preview_panel.custom_minimum_size.y = WAVE_PREVIEW_COMPACT_HEIGHT if _right_detail_active else WAVE_PREVIEW_NORMAL_HEIGHT
		_wave_preview_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if _right_detail_active else Control.SIZE_EXPAND_FILL
	if _wave_preview_scroll != null:
		_wave_preview_scroll.visible = _wave_preview_available and not _right_detail_active
	if _detail_panel != null:
		if not _right_detail_active:
			_detail_panel.visible = false


func _style_button(button: Button, accent: Color) -> void:
	GameUiStyle.center_button_text(button)
	button.add_theme_stylebox_override("normal", GameUiStyle.button(accent))
	button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.08))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_INVERTED)


func _style_wave_route_toggle() -> void:
	_wave_route_toggle.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	_wave_route_toggle.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	_wave_route_toggle.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_INVERTED_DIM)


func _bind_wave_preview_nodes() -> void:
	if _wave_preview_content == null:
		return
	_wave_level_name_label = %WaveLevelNameLabel
	_wave_desc_label = %WaveLevelDescLabel
	_wave_summary_label = %WaveSummaryLabel
	_wave_spawn_cards_box = %WaveSpawnCardsBox
	_wave_spawn_card_template = %WaveSpawnCardTemplate
	_wave_enemy_card_template = %WaveEnemyCardTemplate
	_wave_warning_row = %WaveWarningRow
	_wave_warning_label = %WaveWarningLabel
	_wave_preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_wave_preview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	GameUiStyle.apply_scroll_style(_wave_preview_scroll)
	_wave_preview_label.visible = false
	_style_wave_preview_static_nodes()
	if _wave_spawn_card_template != null:
		_wave_spawn_card_template.visible = false
	if _wave_enemy_card_template != null:
		_wave_enemy_card_template.visible = false
	if _wave_warning_row != null:
		_wave_warning_row.visible = false


func _set_wave_preview_v2_visible(visible: bool) -> void:
	if _wave_level_name_label != null:
		_wave_level_name_label.visible = visible
	if _wave_desc_label != null:
		_wave_desc_label.visible = visible and not _wave_desc_label.text.strip_edges().is_empty()
	if _wave_summary_label != null:
		_wave_summary_label.visible = visible
	if _wave_spawn_cards_box != null:
		_wave_spawn_cards_box.visible = visible
	if _wave_warning_row != null:
		_wave_warning_row.visible = visible and _wave_warning_label != null and not _wave_warning_label.text.strip_edges().is_empty()


func _style_wave_preview_static_nodes() -> void:
	for label in [_wave_level_name_label, _wave_desc_label, _wave_summary_label, _wave_warning_label]:
		if label == null:
			continue
		label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
	if _wave_level_name_label != null:
		_wave_level_name_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	if _wave_desc_label != null:
		_wave_desc_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	if _wave_summary_label != null:
		_wave_summary_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	if _wave_warning_label != null:
		_wave_warning_label.add_theme_color_override("font_color", GameUiStyle.AMBER)


func _make_wave_label(node_name: String, font_size: int, color: Color, autowrap: bool) -> Label:
	var label := Label.new()
	label.name = node_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if autowrap else TextServer.AUTOWRAP_OFF
	label.clip_text = false
	return label


func _rebuild_wave_spawn_cards(spawn_order: Array, entries: Array, raw_key_enemies: Variant, main_gate: String = "") -> void:
	if _wave_spawn_cards_box == null or _wave_spawn_card_template == null or _wave_enemy_card_template == null:
		return
	for child in _wave_spawn_cards_box.get_children():
		child.queue_free()
	var entries_by_spawn: Dictionary = {}
	for raw_spawn: Variant in spawn_order:
		entries_by_spawn[String(raw_spawn)] = []
	for entry_variant: Variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var spawn_key := String(entry.get("spawn_key", ""))
		if spawn_key.is_empty():
			continue
		if not entries_by_spawn.has(spawn_key):
			entries_by_spawn[spawn_key] = []
		(entries_by_spawn[spawn_key] as Array).append(entry)
	var key_enemies := _key_enemy_lookup(raw_key_enemies)
	for raw_spawn: Variant in spawn_order:
		var spawn_key := String(raw_spawn)
		var spawn_entries: Array = entries_by_spawn.get(spawn_key, [])
		_wave_spawn_cards_box.add_child(_build_wave_spawn_card(spawn_key, spawn_entries, key_enemies, main_gate))


## 多波时按"波 × 口"分段展示（消费 get_night_preview 的 waves[].entries / main_gate）；
## 单波或缺 per-wave 数据时回退聚合卡片。
func _rebuild_wave_spawn_cards_by_wave(waves: Array, merged_spawn_order: Array, merged_entries: Array, raw_key_enemies: Variant) -> void:
	var usable_waves: Array[Dictionary] = []
	for wave_variant: Variant in waves:
		if typeof(wave_variant) != TYPE_DICTIONARY:
			continue
		var wave_info: Dictionary = wave_variant
		if not (wave_info.get("entries", []) as Array).is_empty():
			usable_waves.append(wave_info)
	if usable_waves.size() <= 1:
		var single_main: String = ""
		if usable_waves.size() == 1:
			single_main = String(usable_waves[0].get("main_gate", ""))
		_rebuild_wave_spawn_cards(merged_spawn_order, merged_entries, raw_key_enemies, single_main)
		return
	if _wave_spawn_cards_box == null or _wave_spawn_card_template == null or _wave_enemy_card_template == null:
		return
	for child in _wave_spawn_cards_box.get_children():
		child.queue_free()
	var key_enemies := _key_enemy_lookup(raw_key_enemies)
	for wave_info in usable_waves:
		var main_gate := String(wave_info.get("main_gate", ""))
		var header := _make_wave_label("WaveHeader", 13, GameUiStyle.AMBER, false)
		var header_text := "第 %d 波 · %s" % [int(wave_info.get("wave_index", 0)) + 1, String(wave_info.get("name", ""))]
		if not main_gate.is_empty():
			header_text += " · 主攻 %s" % main_gate
		header.text = header_text
		_wave_spawn_cards_box.add_child(header)
		var wave_entries: Array = wave_info.get("entries", [])
		var spawn_order: Array = wave_info.get("spawn_order", [])
		var entries_by_spawn: Dictionary = {}
		for raw_spawn: Variant in spawn_order:
			entries_by_spawn[String(raw_spawn)] = []
		for entry_variant: Variant in wave_entries:
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_variant
			var spawn_key := String(entry.get("spawn_key", ""))
			if spawn_key.is_empty():
				continue
			if not entries_by_spawn.has(spawn_key):
				entries_by_spawn[spawn_key] = []
			(entries_by_spawn[spawn_key] as Array).append(entry)
		for raw_spawn: Variant in spawn_order:
			var spawn_key := String(raw_spawn)
			var spawn_entries: Array = entries_by_spawn.get(spawn_key, [])
			_wave_spawn_cards_box.add_child(_build_wave_spawn_card(spawn_key, spawn_entries, key_enemies, main_gate))


func _build_wave_spawn_card(spawn_key: String, entries: Array, key_enemies: Dictionary, main_gate: String = "") -> Control:
	var card := _wave_spawn_card_template.duplicate() as PanelContainer
	card.name = "WaveSpawn%sCard" % spawn_key
	card.unique_name_in_owner = false
	card.visible = true
	var key_label := card.get_node_or_null("SpawnCardRow/SpawnKeyLabel") as Label
	if spawn_key == main_gate and not main_gate.is_empty():
		key_label.text = "%s · 主攻" % spawn_key
	else:
		key_label.text = spawn_key
	key_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	var chips := card.get_node_or_null("SpawnCardRow/WaveEnemyCardsFlow") as HFlowContainer
	for child in chips.get_children():
		child.queue_free()
	for entry_variant: Variant in entries:
		if typeof(entry_variant) == TYPE_DICTIONARY:
			var entry: Dictionary = entry_variant
			chips.add_child(_build_wave_enemy_chip(entry, key_enemies.has(StringName(entry.get("enemy_id", "")))))
	return card


func _build_wave_enemy_chip(entry: Dictionary, highlighted: bool) -> Control:
	var chip := _wave_enemy_card_template.duplicate() as PanelContainer
	chip.name = "WaveEnemyCard"
	chip.unique_name_in_owner = false
	chip.visible = true
	var name_label := chip.get_node_or_null("EnemyCardMargin/EnemyCardBody/EnemyInfoBox/EnemyNameLabel") as Label
	name_label.text = String(entry.get("enemy_name", entry.get("enemy_id", "")))
	name_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED if not highlighted else GameUiStyle.AMBER)

	var count_label := chip.get_node_or_null("EnemyCardMargin/EnemyCardBody/EnemyInfoBox/EnemyCountLabel") as Label
	count_label.text = "×%d · %s" % [int(entry.get("count", 0)), _format_wave_enemy_timing(entry)]
	count_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)

	var stats := chip.get_node_or_null("EnemyCardMargin/EnemyCardBody/EnemyInfoBox/WaveEnemyStats") as VBoxContainer
	var enemy_cfg: Dictionary = entry.get("enemy_cfg", {})
	var stat_lines := _wave_enemy_stat_lines(enemy_cfg)
	for index in range(stats.get_child_count()):
		var stat_label := stats.get_child(index) as Label
		stat_label.text = stat_lines[index] if index < stat_lines.size() else ""
		stat_label.visible = index < stat_lines.size()
		stat_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)

	var tags := _wave_enemy_tags(enemy_cfg)
	var tag_label := chip.get_node_or_null("EnemyCardMargin/EnemyCardBody/EnemyInfoBox/EnemyTagLabel") as Label
	tag_label.text = " / ".join(tags)
	tag_label.visible = not tags.is_empty()
	tag_label.add_theme_color_override("font_color", GameUiStyle.AMBER if highlighted else GameUiStyle.TEXT_INVERTED_DIM)
	_fill_wave_enemy_preview(chip.get_node_or_null("EnemyCardMargin/EnemyCardBody/WaveEnemyPreview") as Control, entry, enemy_cfg)
	chip.tooltip_text = _wave_enemy_tooltip(entry)
	return chip


func _fill_wave_enemy_preview(slot: Control, entry: Dictionary, enemy_cfg: Dictionary) -> void:
	if slot == null:
		return
	var texture_rect := slot.get_node_or_null("WaveEnemyPreviewTexture") as TextureRect
	var fallback_label := slot.get_node_or_null("WaveEnemyPreviewFallback") as Label
	if texture_rect == null or fallback_label == null:
		return
	texture_rect.texture = EnemyIconHelper.texture_for_cfg(enemy_cfg)
	texture_rect.visible = texture_rect.texture != null
	fallback_label.text = String(entry.get("enemy_name", entry.get("enemy_id", "?"))).substr(0, 1)
	fallback_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	fallback_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	fallback_label.add_theme_constant_override("shadow_offset_x", 0)
	fallback_label.add_theme_constant_override("shadow_offset_y", 0)
	fallback_label.visible = texture_rect.texture == null


func _wave_enemy_stat_lines(enemy_cfg: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append("HP %d  攻 %d" % [
		int(enemy_cfg.get("max_hp", 0)),
		int(enemy_cfg.get("atk", 0))
	])
	lines.append("防 %d  抗 %d" % [
		int(enemy_cfg.get("def", 0)),
		int(enemy_cfg.get("res", 0))
	])
	var attack_range := float(enemy_cfg.get("attack_range", 0.0))
	if attack_range > 0.0:
		lines.append("速 %.2f  距 %.0f" % [float(enemy_cfg.get("move_speed", 0.0)), attack_range])
	else:
		lines.append("速 %.2f  近战" % float(enemy_cfg.get("move_speed", 0.0)))
	lines.append("核 %d  声 %d" % [
		int(enemy_cfg.get("core_damage", 1)),
		int(enemy_cfg.get("prestige_reward", 0))
	])
	return lines


func _wave_enemy_tags(enemy_cfg: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	var damage_type := StringName(enemy_cfg.get("damage_type", "physical"))
	match damage_type:
		&"magic":
			tags.append("法术")
		&"true":
			tags.append("真实")
		_:
			tags.append("物理")
	var behavior_type := StringName(enemy_cfg.get("behavior_type", "normal"))
	if behavior_type == &"boss":
		tags.append("首领")
	elif behavior_type == &"demolisher":
		tags.append("拆墙")
	if StringName(enemy_cfg.get("move_type", "ground")) == &"flying":
		tags.append("飞行")
	if enemy_cfg.has("death_area_damage"):
		tags.append("爆裂")
	if enemy_cfg.has("death_spawn"):
		tags.append("分裂")
	if float(enemy_cfg.get("regen_per_sec", 0.0)) > 0.0:
		tags.append("自愈")
	if int(enemy_cfg.get("shield_hp", 0)) > 0:
		tags.append("护盾")
	return tags


func _format_wave_enemy_timing(entry: Dictionary) -> String:
	var first_time := float(entry.get("first_time", 0.0))
	var last_time := float(entry.get("last_time", first_time))
	if is_equal_approx(first_time, last_time):
		return "%.0fs" % first_time
	return "%.0f-%.0fs" % [first_time, last_time]


func _wave_enemy_tooltip(entry: Dictionary) -> String:
	var enemy_cfg: Dictionary = entry.get("enemy_cfg", {})
	var lines := PackedStringArray()
	lines.append("%s ×%d" % [String(entry.get("enemy_name", entry.get("enemy_id", ""))), int(entry.get("count", 0))])
	lines.append("出现：%s" % _format_wave_enemy_timing(entry))
	lines.append("生命 %d / 攻击 %d / 防御 %d / 法抗 %d" % [
		int(enemy_cfg.get("max_hp", 0)),
		int(enemy_cfg.get("atk", 0)),
		int(enemy_cfg.get("def", 0)),
		int(enemy_cfg.get("res", 0))
	])
	lines.append("移速 %.2f / 攻击间隔 %.2fs / 核心伤害 %d / 声望 %d" % [
		float(enemy_cfg.get("move_speed", 0.0)),
		float(enemy_cfg.get("attack_interval", 0.0)),
		int(enemy_cfg.get("core_damage", 1)),
		int(enemy_cfg.get("prestige_reward", 0))
	])
	var tags := _wave_enemy_tags(enemy_cfg)
	if not tags.is_empty():
		lines.append("特性：%s" % " / ".join(tags))
	return "\n".join(lines)


func _key_enemy_lookup(raw_key_enemies: Variant) -> Dictionary:
	var lookup: Dictionary = {}
	if typeof(raw_key_enemies) != TYPE_ARRAY:
		return lookup
	for raw_enemy: Variant in raw_key_enemies:
		lookup[StringName(raw_enemy)] = true
	return lookup


func _format_wave_warning_text(data: Dictionary) -> String:
	var routes: Array = data.get("routes", [])
	var warnings := PackedStringArray()
	for raw_affix: Variant in data.get("affixes", []):
		if typeof(raw_affix) != TYPE_DICTIONARY:
			continue
		var affix: Dictionary = raw_affix
		var affix_name := String(affix.get("name", "")).strip_edges()
		var affix_desc := String(affix.get("desc", "")).strip_edges()
		if affix_name.is_empty():
			continue
		warnings.append("夜晚词缀【%s】%s" % [affix_name, affix_desc])
	for route_variant: Variant in routes:
		if typeof(route_variant) != TYPE_DICTIONARY:
			continue
		var route: Dictionary = route_variant
		var status := StringName(route.get("status", &"ok"))
		if status != &"no_path" and status != &"core_enclosed":
			continue
		var message := String(route.get("message", "路线异常"))
		if not warnings.has(message):
			warnings.append(message)
	var hover_cell: Vector2i = data.get("hover_cell", Vector2i(-9999, -9999))
	if hover_cell != Vector2i(-9999, -9999):
		warnings.append("预览阻挡：%s" % str(hover_cell))
	return "；".join(warnings)


## 当晚词缀清单（含事件临时追加项），白天与夜间常显，由 controller 驱动；
## 仅在菜单/三选一/结算等非昼夜阶段隐藏。
func set_night_affixes(affixes: Array) -> void:
	_ensure_night_affix_row()
	if _night_affix_row == null:
		return
	var parts := PackedStringArray()
	var tips := PackedStringArray()
	for raw_affix: Variant in affixes:
		if typeof(raw_affix) != TYPE_DICTIONARY:
			continue
		var affix: Dictionary = raw_affix
		var affix_name := String(affix.get("name", "")).strip_edges()
		if affix_name.is_empty():
			continue
		parts.append(affix_name)
		tips.append("【%s】%s" % [affix_name, String(affix.get("desc", "")).strip_edges()])
	_night_affix_label.text = "今晚词缀：%s" % " · ".join(parts)
	_night_affix_row.tooltip_text = "\n".join(tips)
	_night_affix_row.visible = not parts.is_empty()


func hide_night_affixes() -> void:
	if _night_affix_row != null:
		_night_affix_row.visible = false


## 波间倒计时横幅：喘息期显示"下一波 N 秒"。seconds < 0 时隐藏。
func set_wave_countdown(seconds: float) -> void:
	if seconds < 0.0:
		hide_wave_countdown()
		return
	_ensure_wave_countdown_row()
	if _wave_countdown_row == null:
		return
	_wave_countdown_label.text = "下一波 %d 秒" % int(ceil(seconds))
	_wave_countdown_row.visible = true


func hide_wave_countdown() -> void:
	if _wave_countdown_row != null:
		_wave_countdown_row.visible = false


func _ensure_wave_countdown_row() -> void:
	if _wave_countdown_row != null:
		return
	_wave_countdown_row = PanelContainer.new()
	_wave_countdown_row.name = "WaveCountdownRow"
	_wave_countdown_row.visible = false
	_wave_countdown_row.z_index = 41
	_wave_countdown_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_countdown_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wave_countdown_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wave_countdown_row.offset_top = 128.0
	add_child(_wave_countdown_row)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_wave_countdown_row.add_child(margin)
	_wave_countdown_label = Label.new()
	_wave_countdown_label.add_theme_font_size_override("font_size", 18)
	_wave_countdown_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_wave_countdown_label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
	_wave_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(_wave_countdown_label)


## 今晚活跃口一行（含已封堵后缀），挂在波次卡片容器的父节点上，重建卡片不会清掉它。
func set_active_gates_line(text: String) -> void:
	if _active_gates_line == null:
		if _wave_spawn_cards_box == null:
			return
		var host := _wave_spawn_cards_box.get_parent() as Control
		if host == null:
			return
		_active_gates_line = _make_wave_label("ActiveGatesLine", 13, GameUiStyle.AMBER, true)
		host.add_child(_active_gates_line)
		host.move_child(_active_gates_line, 0)
	_active_gates_line.text = text
	_active_gates_line.visible = not text.is_empty()


## 活跃事件点一行（"事件点 X/4"），挂在波次预览容器父节点上，重建卡片不会清掉它。
## warn 为真（达上限）时用警示色，提示玩家先去处理已有事件。
func set_event_count_line(text: String, warn: bool = false) -> void:
	if _event_count_line == null:
		if _wave_spawn_cards_box == null:
			return
		var host := _wave_spawn_cards_box.get_parent() as Control
		if host == null:
			return
		_event_count_line = _make_wave_label("EventCountLine", 13, GameUiStyle.AMBER, true)
		host.add_child(_event_count_line)
		host.move_child(_event_count_line, 0)
	_event_count_line.text = text
	_event_count_line.add_theme_color_override("font_color", GameUiStyle.DANGER if warn else GameUiStyle.AMBER)
	_event_count_line.visible = not text.is_empty()


func _ensure_night_affix_row() -> void:
	if _night_affix_row != null:
		return
	_night_affix_row = PanelContainer.new()
	_night_affix_row.name = "NightAffixRow"
	_night_affix_row.visible = false
	_night_affix_row.z_index = 40
	_night_affix_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_night_affix_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_night_affix_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_night_affix_row.offset_top = 94.0
	add_child(_night_affix_row)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_night_affix_row.add_child(margin)
	_night_affix_label = Label.new()
	_night_affix_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	margin.add_child(_night_affix_label)


func _ensure_level_intro_banner() -> void:
	if _level_intro_banner != null:
		return
	_level_intro_banner = Control.new()
	_level_intro_banner.name = "LevelIntroBanner"
	_level_intro_banner.visible = false
	_level_intro_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_intro_banner.z_index = 80
	_level_intro_banner.anchor_right = 1.0
	_level_intro_banner.anchor_bottom = 1.0
	add_child(_level_intro_banner)

	_level_intro_content = VBoxContainer.new()
	_level_intro_content.name = "LevelIntroContent"
	_level_intro_content.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_level_intro_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_intro_content.add_theme_constant_override("separation", 8)
	_level_intro_banner.add_child(_level_intro_content)
	_apply_level_intro_content_rect(_level_intro_content_rect(0.0))

	_level_intro_day_label = _make_wave_label("LevelIntroDayLabel", 16, GameUiStyle.AMBER, false)
	_level_intro_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_intro_content.add_child(_level_intro_day_label)

	_level_intro_name_label = _make_wave_label("LevelIntroNameLabel", 38, GameUiStyle.TEXT_INVERTED, true)
	_level_intro_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_intro_content.add_child(_level_intro_name_label)

	var line_wrap := CenterContainer.new()
	line_wrap.custom_minimum_size = Vector2(0, 5)
	_level_intro_content.add_child(line_wrap)
	_level_intro_line = ColorRect.new()
	_level_intro_line.custom_minimum_size = Vector2(460, 3)
	_level_intro_line.color = GameUiStyle.AMBER
	line_wrap.add_child(_level_intro_line)

	_level_intro_desc_label = _make_wave_label("LevelIntroDescLabel", 16, GameUiStyle.TEXT_INVERTED_DIM, true)
	_level_intro_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_intro_content.add_child(_level_intro_desc_label)


func _collect_resource_items() -> void:
	if _resource_chip == null:
		return
	if _resource_items_row == null:
		push_warning("ResourceItemsRow is missing from CombatHud scene.")
		return
	_resource_item_controls.clear()
	for resource_key in RESOURCE_ORDER:
		var item_root := _resource_items_row.get_node_or_null("%sResourceItem" % _resource_node_prefix(resource_key)) as Control
		if item_root == null:
			push_warning("%sResourceItem is missing from CombatHud scene." % _resource_node_prefix(resource_key))
			continue
		var projected_delta_badge := item_root.get_node_or_null("ProjectedDeltaBadge") as Control
		if projected_delta_badge != null:
			projected_delta_badge.visible = true
			projected_delta_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			projected_delta_badge.z_index = 6
		var item := {
			"root": item_root,
			"base": item_root.get_node_or_null("ResourceItemBase"),
			"margin": item_root.get_node_or_null("ItemMargin"),
			"icon_texture": item_root.get_node_or_null("ItemMargin/ItemRow/IconTexture"),
			"value": item_root.get_node_or_null("ItemMargin/ItemRow/ValueLabel"),
			"delta_badge": projected_delta_badge,
			"delta": projected_delta_badge.get_node_or_null("DeltaLabel") if projected_delta_badge != null else null
		}
		_resource_item_controls[resource_key] = item
	_order_resource_item_nodes()


func _resource_node_prefix(resource_key: StringName) -> String:
	match resource_key:
		&"ap":
			return "ActionPoint"
		&"wood":
			return "Wood"
		&"stone":
			return "Stone"
		&"mana":
			return "Mana"
		&"prestige":
			return "Prestige"
		_:
			return "Resource"


func _order_resource_item_nodes() -> void:
	if _resource_items_row == null:
		return
	var next_index := 0
	for resource_key in RESOURCE_ORDER:
		var item: Dictionary = _resource_item_controls.get(resource_key, {})
		var root := item.get("root") as Control
		if root == null or root.get_parent() != _resource_items_row:
			continue
		_resource_items_row.move_child(root, next_index)
		next_index += 1


func _resource_display_name(resource_key: StringName) -> String:
	match resource_key:
		&"ap":
			return "行动力"
		&"prestige":
			return "声望"
		&"wood":
			return "木材"
		&"stone":
			return "石头"
		&"mana":
			return "魔力矿"
		_:
			return String(resource_key)


func _phase_icon_id_for_text(text_value: String) -> StringName:
	if text_value.contains("夜"):
		return &"phase_night"
	if text_value.contains("祝福"):
		return &"phase_blessing"
	return &"phase_day"


func _apply_chip_icon(chip: Control, icon_id: StringName) -> void:
	if chip == null:
		return
	var texture := UiArtRegistry.get_catalog_icon(icon_id)
	if texture == null:
		return
	var icon := chip.get_node_or_null("ChipIconTexture") as TextureRect
	if icon == null:
		return
	icon.texture = texture
	icon.visible = true


func _style_top_button(button: Button, _selected: bool) -> void:
	GameUiStyle.center_button_text(button)
	button.toggle_mode = false
	button.set_pressed_no_signal(false)
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_pressed_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)


func _place_speed_active_overlay(_button: Button) -> void:
	if _speed_active_overlay == null:
		return
	if _button == null or not _button.visible:
		_speed_active_overlay.visible = false
		return
	var overlay_parent := _speed_active_overlay.get_parent() as Control
	if overlay_parent == null:
		_speed_active_overlay.visible = false
		return
	var button_rect := _button.get_global_rect()
	var parent_to_local := overlay_parent.get_global_transform_with_canvas().affine_inverse()
	var local_position := parent_to_local * button_rect.position
	var inset := Vector2.ZERO
	var top_left := local_position + inset
	var bottom_right := local_position + button_rect.size - inset
	_speed_active_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_speed_active_overlay.offset_left = top_left.x
	_speed_active_overlay.offset_top = top_left.y
	_speed_active_overlay.offset_right = bottom_right.x
	_speed_active_overlay.offset_bottom = bottom_right.y
	_speed_active_overlay.visible = true


func _setup_deploy_deck_scroll() -> void:
	_deck_scroll = _deck_panel.get_node_or_null("DeckMargin/ScrollContainer") as ScrollContainer
	if _deck_scroll == null:
		push_warning("Deploy deck ScrollContainer is missing; expected DeployDeck/DeckMargin/ScrollContainer.")
		return
	_deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_deck_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_deck_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_deck_scroll.clip_contents = true
	_deck_scroll.scroll_horizontal_custom_step = DEPLOY_SCROLLBAR_STEP
	GameUiStyle.apply_scroll_style(_deck_scroll)
	if not _deck_scroll.resized.is_connected(_refresh_deploy_deck_scroll_content):
		_deck_scroll.resized.connect(_refresh_deploy_deck_scroll_content)
	var horizontal_bar := _deck_scroll.get_h_scroll_bar()
	if horizontal_bar != null:
		horizontal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vertical_bar := _deck_scroll.get_v_scroll_bar()
	if vertical_bar != null:
		vertical_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_deploy_deck_scroll_content()


func _refresh_deploy_deck_scroll_content() -> void:
	if _deck_container == null:
		return
	var card_width := 0.0
	var card_height := 0.0
	var visible_card_count := 0
	for child in _deck_container.get_children():
		var card := child as Control
		if card == null or not card.visible:
			continue
		var minimum := card.get_combined_minimum_size()
		if minimum == Vector2.ZERO:
			minimum = card.custom_minimum_size
		card_width += maxf(minimum.x, card.custom_minimum_size.x)
		card_height = maxf(card_height, maxf(minimum.y, card.custom_minimum_size.y))
		visible_card_count += 1
	var separation := float(_deck_container.get_theme_constant("separation"))
	if visible_card_count > 1:
		card_width += separation * float(visible_card_count - 1)
	if _deck_panel != null:
		_deck_panel.visible = visible_card_count > 0
	_deck_container.custom_minimum_size = Vector2(card_width, card_height)
	_deck_container.size.x = card_width
	_deck_container.size.y = card_height


func _style_top_cards() -> void:
	for card in [
		_stage_chip.get_node_or_null("ChipBase") as Panel,
		_core_chip.get_node_or_null("ChipBase") as Panel,
		_deploy_chip.get_node_or_null("ChipBase") as Panel,
		_message_chip.get_node_or_null("ChipBase") as Panel
	]:
		if card != null:
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _speed_toggle_base != null:
		_speed_toggle_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in _resource_item_controls.values():
		var item_base := (item as Dictionary).get("base") as Panel
		if item_base != null:
			item_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var delta_badge := (item as Dictionary).get("delta_badge") as Panel
		if delta_badge != null:
			delta_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [_core_label, _deploy_label, _queue_label, _message_label]:
		label.add_theme_color_override("font_color", GameUiStyle.TEXT)
		label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_constant_override("line_spacing", 0)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for label in [_queue_label, _core_label, _deploy_label]:
		GameUiStyle.center_label_text(label)
	for label in [_message_label]:
		GameUiStyle.center_label_text(label)
	_message_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	for item in _resource_item_controls.values():
		var item_dict := item as Dictionary
		for label_key in ["value", "delta"]:
			var label := item_dict.get(label_key) as Label
			if label == null:
				continue
			label.add_theme_color_override("font_color", GameUiStyle.TEXT)
			label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
			label.add_theme_constant_override("shadow_offset_x", 0)
			label.add_theme_constant_override("shadow_offset_y", 0)
			GameUiStyle.center_label_text(label)
		var delta := item_dict.get("delta") as Label
		if delta != null:
			_apply_resource_delta_label_style(delta, 0)


func _setup_message_chip_state() -> void:
	if _message_chip == null:
		return
	_message_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_base := _message_chip.get_node_or_null("ChipBase") as Panel
	if chip_base != null:
		chip_base.z_index = MESSAGE_CHIP_BASE_Z
	var existing_overlay := _message_chip.get_node_or_null("MessageWarningOverlay")
	if existing_overlay != null:
		_message_chip.remove_child(existing_overlay)
		existing_overlay.queue_free()
	_message_label.z_index = MESSAGE_CHIP_CONTENT_Z
	if _message_icon_texture != null:
		_message_icon_texture.z_index = MESSAGE_CHIP_CONTENT_Z
		_message_icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_message_state(false)


func _apply_message_state(warning: bool) -> void:
	_message_warning_active = warning
	if _message_label != null:
		var text_color: Color = GameUiStyle.DANGER if warning else GameUiStyle.TEXT_DIM
		_message_label.add_theme_color_override("font_color", text_color)
	if _message_icon_texture == null:
		return
	var icon_key: StringName = MESSAGE_WARNING_ICON if warning else MESSAGE_NORMAL_ICON
	var texture := UiArtRegistry.get_catalog_icon(icon_key)
	if texture == null:
		return
	_message_icon_texture.texture = texture
	_message_icon_texture.visible = true


func _is_warning_message(text_value: String) -> bool:
	for token in MESSAGE_WARNING_TOKENS:
		if text_value.contains(token):
			return true
	if _looks_like_unlocalized_message(text_value):
		return true
	return false


func _localized_message_text(text_value: String) -> String:
	var trimmed := text_value.strip_edges()
	if trimmed.is_empty():
		return text_value
	if MESSAGE_TEXT_OVERRIDES.has(trimmed):
		return String(MESSAGE_TEXT_OVERRIDES[trimmed])
	var upper_text := trimmed.to_upper()
	if MESSAGE_TEXT_OVERRIDES.has(upper_text):
		return String(MESSAGE_TEXT_OVERRIDES[upper_text])
	var canonical_code := _canonical_message_code(trimmed)
	if MESSAGE_TEXT_OVERRIDES.has(canonical_code):
		return String(MESSAGE_TEXT_OVERRIDES[canonical_code])
	if _looks_like_unlocalized_message(trimmed):
		return "错误码 %s：请查看调试日志" % canonical_code
	return text_value


func _looks_like_unlocalized_message(text_value: String) -> bool:
	for index in text_value.length():
		var code := text_value.unicode_at(index)
		if code >= 65 and code <= 90:
			return true
		if code >= 97 and code <= 122:
			return true
	return false


func _canonical_message_code(text_value: String) -> String:
	var result := ""
	var previous_was_separator := true
	for index in text_value.length():
		var code := text_value.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_upper or is_lower:
			result += char(code).to_upper()
			previous_was_separator = false
		elif not previous_was_separator:
			result += "_"
			previous_was_separator = true
	return result.trim_suffix("_")


func _style_legend_panel() -> void:
	var title := _legend_panel.get_node_or_null("LegendMargin/LegendVBox/LegendTitleLabel") as Label
	for label_node in _legend_panel.find_children("*", "Label", true, false):
		var label := label_node as Label
		label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
		label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_font_size_override("font_size", 12)
	if title != null:
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", GameUiStyle.TEXT)
		GameUiStyle.center_label_text(title)
	_apply_legend_icon("EnemyPathRow", &"legend_enemy_path")
	_apply_legend_icon("DeployTileRow", &"legend_deploy_tile")
	_apply_legend_icon("FriendlyBuildingRow", &"legend_friendly_building")
	_apply_legend_icon("BlockerRow", &"legend_blocker_tile")
	_apply_legend_icon("CoreAreaRow", &"legend_core_area")


func _apply_legend_icon(row_name: String, icon_id: StringName) -> void:
	var row := _legend_panel.get_node_or_null("LegendMargin/LegendVBox/LegendRows/%s" % row_name) as Control
	if row == null:
		return
	var content := row.get_node_or_null("RowContent") as HBoxContainer
	if content == null and row is HBoxContainer:
		content = row as HBoxContainer
	if content == null:
		return
	var texture := UiArtRegistry.get_catalog_icon(icon_id)
	if texture == null:
		return
	var swatch := content.get_node_or_null("Swatch") as CanvasItem
	if swatch != null:
		swatch.visible = false
	var icon := content.get_node_or_null("IconTexture") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "IconTexture"
		icon.set_custom_minimum_size(Vector2(18.0, 18.0))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)
		content.move_child(icon, 0)
	icon.texture = texture
	icon.visible = true


func _on_viewport_size_changed() -> void:
	_refresh_core_fill()
	if _level_intro_banner != null and not _level_intro_banner.visible:
		_apply_level_intro_content_rect(_level_intro_content_rect(0.0))


func _level_intro_content_rect(y_offset: float) -> Rect2:
	var viewport_size := get_viewport_rect().size
	var width: float = clampf(viewport_size.x * LEVEL_INTRO_WIDTH_RATIO, LEVEL_INTRO_MIN_WIDTH, LEVEL_INTRO_MAX_WIDTH)
	var left: float = (viewport_size.x - width) * 0.5
	var top: float = maxf(LEVEL_INTRO_MIN_TOP, viewport_size.y * LEVEL_INTRO_TOP_RATIO) + y_offset
	return Rect2(left, top, width, LEVEL_INTRO_HEIGHT)


func _apply_level_intro_content_rect(rect: Rect2) -> void:
	if _level_intro_content == null:
		return
	_level_intro_content.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_level_intro_content.offset_left = rect.position.x
	_level_intro_content.offset_top = rect.position.y
	_level_intro_content.offset_right = rect.end.x
	_level_intro_content.offset_bottom = rect.end.y


func _core_title_from_text(core_text: String) -> String:
	for token in core_text.split("\n", false):
		var title := token.strip_edges()
		if title.is_empty() or title.contains("/"):
			continue
		return title
	return CORE_HP_TITLE


func _format_core_hp_label() -> String:
	if _core_hp_max <= 0:
		return "%s --/--" % CORE_HP_TITLE
	return "%s %d/%d" % [CORE_HP_TITLE, _core_hp_current, _core_hp_max]


func _set_core_progress_from_text(core_text: String) -> void:
	var ratio := _core_hp_ratio
	var parsed_hp_text := false
	for token in core_text.split("\n", false):
		var slash_index := token.find("/")
		if slash_index <= 0:
			continue
		parsed_hp_text = true
		var current_text := token.substr(0, slash_index).strip_edges()
		var max_text := token.substr(slash_index + 1).strip_edges()
		if current_text.is_valid_int() and max_text.is_valid_int():
			var max_value := max_text.to_int()
			if max_value <= 0:
				ratio = 0.0
			else:
				ratio = clampf(float(current_text.to_int()) / float(max_value), 0.0, 1.0)
			break
		else:
			ratio = 0.0
	if parsed_hp_text:
		_core_hp_ratio = ratio
		_refresh_core_fill()


func _refresh_core_fill() -> void:
	if _core_clip == null or _core_fill == null:
		return
	_core_fill.anchor_left = 0.0
	_core_fill.anchor_top = 0.0
	_core_fill.anchor_right = 0.0
	_core_fill.anchor_bottom = 1.0
	_core_fill.offset_left = 0.0
	_core_fill.offset_top = 0.0
	_core_fill.offset_right = maxf(0.0, _core_clip.size.x * clampf(_core_hp_ratio, 0.0, 1.0))
	_core_fill.offset_bottom = 0.0


func _bind_overlay_panels() -> void:
	if _settings_button != null:
		if _settings_button.has_signal("settings_button_pressed"):
			_settings_button.connect(&"settings_button_pressed", Callable(self, "_on_settings_button_pressed"))
		else:
			_settings_button.pressed.connect(_on_settings_button_pressed)
	if _settings_panel != null and _settings_panel.has_signal("close_requested"):
		_settings_panel.connect(&"close_requested", Callable(self, "_on_settings_panel_close_requested"))
	if _relic_strip != null:
		if _relic_strip.has_signal("panel_requested"):
			_relic_strip.connect(&"panel_requested", Callable(self, "_on_relic_panel_requested"))
		if _relic_strip.has_signal("relic_pressed"):
			_relic_strip.connect(&"relic_pressed", Callable(self, "_on_relic_strip_relic_pressed"))
	if _relic_panel != null and _relic_panel.has_signal("close_requested"):
		_relic_panel.connect(&"close_requested", Callable(self, "_on_relic_panel_close_requested"))


func _on_settings_button_pressed() -> void:
	toggle_settings_panel()


func _on_settings_panel_close_requested() -> void:
	_hide_overlay_panel(&"settings")


func _on_relic_panel_requested() -> void:
	_show_overlay_panel(&"relic")


func _on_relic_strip_relic_pressed(buff_id: StringName) -> void:
	if _relic_panel != null and _relic_panel.has_method("select_relic"):
		_relic_panel.select_relic(buff_id)


func _on_relic_panel_close_requested() -> void:
	_hide_overlay_panel(&"relic")


func _show_overlay_panel(panel_name: StringName) -> void:
	var panel := _panel_for_name(panel_name)
	if panel == null:
		return
	_show_control_ancestors(panel)
	if panel.has_method("show_panel"):
		panel.show_panel()
	else:
		panel.visible = true
	_move_control_to_front(panel)
	_mark_panel_top(panel_name)


func _hide_overlay_panel(panel_name: StringName) -> void:
	var panel := _panel_for_name(panel_name)
	if panel == null:
		return
	if panel.has_method("hide_panel"):
		panel.hide_panel()
	else:
		panel.visible = false
	_remove_panel_from_stack(panel_name)


func _panel_for_name(panel_name: StringName) -> Control:
	match panel_name:
		&"settings":
			return _settings_panel
		&"relic":
			return _relic_panel
		_:
			return null


func _mark_panel_top(panel_name: StringName) -> void:
	_remove_panel_from_stack(panel_name)
	_open_panel_stack.append(panel_name)


func _remove_panel_from_stack(panel_name: StringName) -> void:
	while _open_panel_stack.has(panel_name):
		_open_panel_stack.erase(panel_name)


func _move_control_to_front(control: Control) -> void:
	if control == null or control.get_parent() == null:
		return
	var parent := control.get_parent()
	parent.move_child(control, parent.get_child_count() - 1)


func _show_control_ancestors(control: Control) -> void:
	var current: Node = control.get_parent()
	while current != null and current != self:
		if current is CanvasItem:
			var canvas_item: CanvasItem = current as CanvasItem
			canvas_item.visible = true
		current = current.get_parent()
