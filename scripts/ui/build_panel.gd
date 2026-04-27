extends PanelContainer

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const BuildListCardScene = preload("res://scenes/ui/BuildListCard.tscn")

const MODE_BUILD: StringName = &"build"
const MODE_SHOP: StringName = &"shop"
const CATEGORY_RESOURCE: StringName = &"resource"
const CATEGORY_AURA: StringName = &"aura"
const CATEGORY_BLOCK: StringName = &"block"
const REFRESH_COST := 2

const CATEGORY_BUILDINGS := {
	CATEGORY_RESOURCE: [
		&"lumber_station",
		&"stone_quarry",
		&"mana_extractor"
	],
	CATEGORY_AURA: [
		&"medical_station",
		&"gravity_tower",
		&"inspiring_monolith",
		&"war_shrine"
	],
	CATEGORY_BLOCK: [
		&"wood_wall"
	]
}

var _current_mode: StringName = MODE_BUILD
var _current_category: StringName = CATEGORY_RESOURCE
var _selected_building_id: StringName = &""
var _stock_slots: Array[Dictionary] = []
var _current_prestige := 0
var _current_phase := GameEnums.PHASE_MENU

@onready var _build_mode_button: Button = %BuildModeButton
@onready var _shop_mode_button: Button = %ShopModeButton
@onready var _selection_label: Label = %BuildSelectionLabel
@onready var _card_list: VBoxContainer = %BuildCardList
@onready var _category_tabs: HBoxContainer = %CategoryTabs
@onready var _resource_button: Button = %ResourceCategoryButton
@onready var _aura_button: Button = %AuraCategoryButton
@onready var _block_button: Button = %BlockCategoryButton
@onready var _refresh_shop_button: Button = %RefreshShopButton
@onready var _message_label: Label = %PanelMessageLabel


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	_bind_events()
	_bind_buttons()
	var run_state = AppRefs.run_state()
	if run_state != null:
		_current_phase = int(run_state.phase)
		_current_prestige = int(run_state.prestige)
		set_visible_for_phase(_current_phase)
	else:
		set_visible_for_phase(GameEnums.PHASE_MENU)
	_sync_shop_stock_from_manager()
	_select_mode(MODE_BUILD)


func _bind_events() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	event_bus.phase_changed.connect(_on_phase_changed)
	event_bus.prestige_changed.connect(_on_prestige_changed)
	event_bus.shop_stock_changed.connect(_on_shop_stock_changed)
	event_bus.shop_action_result.connect(_on_shop_action_result)


func _bind_buttons() -> void:
	_build_mode_button.pressed.connect(_select_mode.bind(MODE_BUILD))
	_shop_mode_button.pressed.connect(_select_mode.bind(MODE_SHOP))
	_resource_button.pressed.connect(_select_category.bind(CATEGORY_RESOURCE))
	_aura_button.pressed.connect(_select_category.bind(CATEGORY_AURA))
	_block_button.pressed.connect(_select_category.bind(CATEGORY_BLOCK))
	_refresh_shop_button.pressed.connect(_on_refresh_shop_pressed)


func _select_mode(mode: StringName) -> void:
	_current_mode = mode
	_selected_building_id = &""
	if _current_mode == MODE_SHOP:
		_sync_shop_stock_from_manager()
	_refresh_mode_buttons()
	_refresh_bottom_controls()
	_refresh_selection_label()
	_rebuild_cards()


func _select_category(category: StringName) -> void:
	_current_category = category
	_selected_building_id = &""
	_refresh_category_buttons()
	_refresh_selection_label()
	if _current_mode == MODE_BUILD:
		_rebuild_cards()


func _refresh_mode_buttons() -> void:
	_build_mode_button.disabled = _current_mode == MODE_BUILD
	_shop_mode_button.disabled = _current_mode == MODE_SHOP
	_style_tab_button(_build_mode_button, _current_mode == MODE_BUILD)
	_style_tab_button(_shop_mode_button, _current_mode == MODE_SHOP)


func _refresh_category_buttons() -> void:
	_resource_button.disabled = _current_category == CATEGORY_RESOURCE
	_aura_button.disabled = _current_category == CATEGORY_AURA
	_block_button.disabled = _current_category == CATEGORY_BLOCK
	_style_tab_button(_resource_button, _current_category == CATEGORY_RESOURCE)
	_style_tab_button(_aura_button, _current_category == CATEGORY_AURA)
	_style_tab_button(_block_button, _current_category == CATEGORY_BLOCK)


func _refresh_bottom_controls() -> void:
	_category_tabs.visible = _current_mode == MODE_BUILD
	_refresh_shop_button.visible = _current_mode == MODE_SHOP
	_refresh_shop_button.disabled = _current_phase != GameEnums.PHASE_DAY or _current_prestige < REFRESH_COST
	_style_command_button(_refresh_shop_button, GameUiStyle.STROKE_SOFT)
	_refresh_category_buttons()


func _rebuild_cards() -> void:
	for child in _card_list.get_children():
		child.queue_free()
	if _current_mode == MODE_SHOP:
		_rebuild_shop_cards()
	else:
		_rebuild_building_cards()


func _rebuild_building_cards() -> void:
	for building_id in _get_category_buildings():
		_card_list.add_child(_make_building_card(building_id))


func _rebuild_shop_cards() -> void:
	if _stock_slots.is_empty():
		_card_list.add_child(_make_empty_state("今日商店暂未刷新"))
		return
	for slot in _stock_slots:
		_card_list.add_child(_make_shop_card(slot as Dictionary))


func _get_category_buildings() -> Array[StringName]:
	var result: Array[StringName] = []
	var source: Array = CATEGORY_BUILDINGS.get(_current_category, [])
	for building_id in source:
		result.append(StringName(building_id))
	return result


func _make_building_card(building_id: StringName) -> Control:
	var cfg := _get_building_cfg(building_id)
	var name := str(cfg.get("name", building_id))
	var cost_text := "木 %d   石 %d   魔 %d" % [
		int(cfg.get("cost_wood", 0)),
		int(cfg.get("cost_stone", 0)),
		int(cfg.get("cost_mana", 0))
	]
	var effect_text := str(cfg.get("desc", "")).strip_edges()
	if effect_text.is_empty():
		effect_text = _format_effect_text(cfg)
	var card := BuildListCardScene.instantiate() as Control
	card.call("configure", {
		"title": name,
		"subtitle": cost_text,
		"detail": effect_text,
		"icon_text": _building_icon_text(building_id),
		"accent": GameUiStyle.STROKE_SOFT,
		"title_color": GameUiStyle.TEXT,
		"state": "已选择" if building_id == _selected_building_id else "",
		"state_color": GameUiStyle.AMBER,
		"selected": building_id == _selected_building_id,
		"min_height": 96.0
	})
	card.connect(&"pressed", _on_building_card_pressed.bind(building_id))
	return card


func _make_shop_card(slot: Dictionary) -> Control:
	var unit_id := StringName(slot.get("unit_id", ""))
	var sold := bool(slot.get("sold", false))
	var slot_index := int(slot.get("slot_index", -1))
	var accent := _tier_color(unit_id)
	if sold or unit_id == StringName():
		accent = GameUiStyle.STROKE_SOFT
	var title := ""
	var subtitle := ""
	var detail := ""
	var state := ""
	var title_color := _tier_color(unit_id)
	if unit_id == StringName():
		title = "空槽位"
		title_color = GameUiStyle.TEXT_MUTED
	else:
		var cfg := _get_unit_cfg(unit_id)
		var cost := int(cfg.get("cost_prestige", 0))
		title = str(cfg.get("name", unit_id))
		subtitle = "%s  %s" % [_class_text(str(cfg.get("class", ""))), _tier_text(cost)]
		detail = "%d 声望" % cost
		if sold:
			state = "已购买"
	var card := BuildListCardScene.instantiate() as Control
	card.call("configure", {
		"title": title,
		"subtitle": subtitle,
		"detail": detail,
		"state": state,
		"icon_text": _unit_icon_text(unit_id),
		"accent": accent,
		"title_color": title_color,
		"state_color": GameUiStyle.TEXT_MUTED if sold else GameUiStyle.AMBER,
		"disabled": sold or unit_id == StringName() or _current_phase != GameEnums.PHASE_DAY,
		"min_height": 102.0
	})
	card.connect(&"pressed", _on_shop_card_pressed.bind(slot_index))
	return card


func _make_empty_state(text_value: String) -> Control:
	var card := BuildListCardScene.instantiate() as Control
	card.call("configure", {
		"title": text_value,
		"icon_text": "路",
		"accent": GameUiStyle.STROKE_SOFT,
		"title_color": GameUiStyle.TEXT_DIM,
		"disabled": true,
		"min_height": 96.0
	})
	return card


func _format_effect_text(cfg: Dictionary) -> String:
	var effect_type := StringName(cfg.get("effect_type", ""))
	var effect_value := float(cfg.get("effect_value", 0.0))
	var radius := int(cfg.get("effect_radius", 0))
	if bool(cfg.get("blocks_path", false)):
		return "阻挡敌人路径，损毁后不再挡路"
	match effect_type:
		&"collect_wood":
			return "每天产出 %d 木材" % int(effect_value)
		&"collect_stone":
			return "每天产出 %d 石材" % int(effect_value)
		&"collect_mana":
			return "每天产出 %d 魔力" % int(effect_value)
		&"heal":
			return "范围 %d 内友军持续恢复生命" % radius
		&"slow":
			return "范围 %d 内敌人移速降低 %.0f%%" % [radius, effect_value * 100.0]
		&"attack_interval_reduce":
			return "范围 %d 内友军攻击间隔降低 %.0f%%" % [radius, effect_value * 100.0]
		&"attack_bonus_flat":
			return "范围 %d 内友军攻击 +%d，夜晚消耗魔力 %d" % [
				radius,
				int(effect_value),
				int(cfg.get("night_mana_cost", 0))
			]
		_:
			return "暂无说明"


func _on_building_card_pressed(building_id: StringName) -> void:
	_selected_building_id = building_id
	_refresh_selection_label()
	_rebuild_cards()
	var action_panel := get_node_or_null("../ActionPanel")
	if action_panel != null and action_panel.has_method("set_mode_build"):
		action_panel.set_mode_build(building_id)


func _on_shop_card_pressed(slot_index: int) -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_buy_shop_slot.emit(slot_index)


func _on_refresh_shop_pressed() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_refresh_shop.emit()


func _refresh_selection_label() -> void:
	if _current_mode == MODE_SHOP:
		_selection_label.text = "招募商店：%d 声望" % _current_prestige
		return
	if _selected_building_id == StringName():
		_selection_label.text = "当前选择：无"
		return
	var cfg := _get_building_cfg(_selected_building_id)
	_selection_label.text = "当前选择：%s" % str(cfg.get("name", _selected_building_id))


func _on_shop_stock_changed(stock_slots: Array[Dictionary]) -> void:
	_stock_slots.clear()
	for slot in stock_slots:
		_stock_slots.append((slot as Dictionary).duplicate(true))
	if _current_mode == MODE_SHOP:
		_rebuild_cards()


func _sync_shop_stock_from_manager() -> void:
	var shop_manager := get_node_or_null("../../Managers/ShopManager")
	if shop_manager == null or not shop_manager.has_method("get_current_stock"):
		return
	_on_shop_stock_changed(shop_manager.get_current_stock())


func _on_shop_action_result(action: StringName, result: Dictionary) -> void:
	_message_label.text = "购买成功" if action == &"buy" and result.get("ok", false) else String(result.get("message", "操作失败"))
	if action == &"refresh" and result.get("ok", false):
		_message_label.text = "商店已刷新"


func _on_prestige_changed(value: int) -> void:
	_current_prestige = value
	_refresh_bottom_controls()
	_refresh_selection_label()
	if _current_mode == MODE_SHOP:
		_rebuild_cards()


func _get_building_cfg(building_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_building_cfg(building_id) if data_repo != null else {}


func _get_unit_cfg(unit_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_unit_cfg(unit_id) if data_repo != null else {}


func _tier_text(cost: int) -> String:
	match cost:
		1:
			return "一阶"
		3:
			return "二阶"
		7:
			return "三阶"
		_:
			return "特殊"


func _class_text(value: String) -> String:
	match value:
		"guard":
			return "近卫"
		"sniper":
			return "狙击"
		"caster":
			return "术士"
		"defender":
			return "重装"
		_:
			return value


func _building_icon_text(building_id: StringName) -> String:
	match building_id:
		&"lumber_station":
			return "木"
		&"stone_quarry":
			return "石"
		&"mana_extractor":
			return "魔"
		&"medical_station":
			return "疗"
		&"gravity_tower":
			return "缓"
		&"inspiring_monolith":
			return "速"
		&"war_shrine":
			return "攻"
		&"wood_wall":
			return "墙"
		_:
			return "*"


func _unit_icon_text(unit_id: StringName) -> String:
	var class_value := str(_get_unit_cfg(unit_id).get("class", ""))
	match class_value:
		"guard":
			return "近"
		"sniper":
			return "狙"
		"caster":
			return "术"
		"defender":
			return "重"
		_:
			return "*"


func _tier_color(unit_id: StringName) -> Color:
	var cost := int(_get_unit_cfg(unit_id).get("cost_prestige", 0))
	match cost:
		1:
			return Color(0.86, 0.93, 0.88)
		3:
			return Color(0.72, 0.88, 1.0)
		7:
			return Color(1.0, 0.82, 0.38)
		_:
			return GameUiStyle.TEXT


func set_visible_for_phase(phase: int) -> void:
	_current_phase = phase
	visible = phase == GameEnums.PHASE_DAY
	_refresh_bottom_controls()
	if _current_mode == MODE_SHOP:
		_rebuild_cards()


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	set_visible_for_phase(new_phase)


func _apply_visual_style() -> void:
	add_theme_stylebox_override("panel", GameUiStyle.panel(GameUiStyle.BG_DARK, GameUiStyle.STROKE_SOFT, 1.0, 6.0))
	_selection_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_message_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_style_tab_button(_build_mode_button, true)
	_style_tab_button(_shop_mode_button, false)
	_style_command_button(_refresh_shop_button, GameUiStyle.STROKE_SOFT)


func _style_tab_button(button: Button, selected: bool) -> void:
	if button == null:
		return
	var accent := GameUiStyle.ACCENT if selected else GameUiStyle.STROKE_SOFT
	button.add_theme_stylebox_override("normal", GameUiStyle.button(accent, 0.18))
	button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT, 0.28))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.30))
	button.add_theme_stylebox_override("disabled", GameUiStyle.accent_button(GameUiStyle.ACCENT))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT)


func _style_command_button(button: Button, accent: Color) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", GameUiStyle.button(accent, 0.18))
	button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT, 0.28))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.34))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.10))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)
