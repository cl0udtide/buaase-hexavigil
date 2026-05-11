extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")
const BuildListCardScene = preload("res://scenes/ui/BuildListCard.tscn")

const MODE_BUILD: StringName = &"build"
const MODE_SHOP: StringName = &"shop"
const CATEGORY_RESOURCE: StringName = &"resource"
const CATEGORY_AURA: StringName = &"aura"
const CATEGORY_BLOCK: StringName = &"block"
const REFRESH_COST := 2

signal shop_unit_preview_requested(slot_index: int, unit_id: StringName, price: int, can_purchase: bool, disabled_reason: String)

var _current_mode: StringName = MODE_BUILD
var _current_category: StringName = CATEGORY_RESOURCE
var _selected_building_id: StringName = &""
var _selected_shop_slot_index := -1
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
	_bind_events()
	_bind_buttons()
	_sync_shop_stock_from_manager()
	refresh_from_state()


func _bind_events() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.phase_changed.connect(_on_phase_changed)
		event_bus.prestige_changed.connect(_on_prestige_changed)
		event_bus.buffs_changed.connect(_on_buffs_changed)
		event_bus.shop_stock_changed.connect(_on_shop_stock_changed)
		event_bus.shop_action_result.connect(_on_shop_action_result)
		event_bus.building_placed.connect(_on_building_placed)
	var data_repo = AppRefs.data_repo()
	if data_repo != null and data_repo.has_signal("data_loaded"):
		data_repo.data_loaded.connect(_on_data_loaded)


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
	_selected_shop_slot_index = -1
	if _current_mode == MODE_SHOP:
		_sync_shop_stock_from_manager()
	refresh_from_state()


func _select_category(category: StringName) -> void:
	_current_category = category
	_selected_building_id = &""
	_selected_shop_slot_index = -1
	refresh_from_state()


func refresh_from_state() -> void:
	_sync_runtime_state()
	visible = _current_phase == GameEnums.PHASE_DAY
	_refresh_mode_buttons()
	_refresh_category_buttons()
	_refresh_bottom_controls()
	_refresh_selection_label()
	_rebuild_cards()


func _sync_runtime_state() -> void:
	var run_state = AppRefs.run_state()
	if run_state == null:
		_current_phase = GameEnums.PHASE_MENU
		_current_prestige = 0
		return
	_current_phase = int(run_state.phase)
	_current_prestige = int(run_state.prestige)


func _refresh_mode_buttons() -> void:
	_build_mode_button.disabled = _current_mode == MODE_BUILD
	_shop_mode_button.disabled = _current_mode == MODE_SHOP


func _refresh_category_buttons() -> void:
	_resource_button.disabled = _current_category == CATEGORY_RESOURCE
	_aura_button.disabled = _current_category == CATEGORY_AURA
	_block_button.disabled = _current_category == CATEGORY_BLOCK


func _refresh_bottom_controls() -> void:
	_category_tabs.visible = _current_mode == MODE_BUILD
	_refresh_shop_button.visible = _current_mode == MODE_SHOP
	var refresh_cost := _get_shop_refresh_cost()
	_refresh_shop_button.text = "刷新 %d 声望" % refresh_cost
	_refresh_shop_button.disabled = _current_phase != GameEnums.PHASE_DAY or _current_prestige < refresh_cost
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
	if _card_list.get_child_count() == 0:
		_card_list.add_child(_make_empty_state("暂无可建造建筑"))


func _rebuild_shop_cards() -> void:
	if _stock_slots.is_empty():
		_card_list.add_child(_make_empty_state("今日商店暂未刷新"))
		return
	for slot in _stock_slots:
		_card_list.add_child(_make_shop_card(slot as Dictionary))


func _get_category_buildings() -> Array[StringName]:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or not data_repo.has_method("get_building_ids_by_type"):
		return []
	return data_repo.get_building_ids_by_type(_current_category)


func _make_building_card(building_id: StringName) -> Control:
	var card_model := _make_building_card_model(building_id)
	var card := BuildListCardScene.instantiate() as Control
	card.call("configure", card_model)
	card.connect(&"pressed", _on_building_card_pressed.bind(building_id))
	return card


func _make_building_card_model(building_id: StringName) -> Dictionary:
	var cfg := _get_building_cfg(building_id)
	var selected := building_id == _selected_building_id
	return {
		"title": UiDisplayText.config_name(cfg, building_id),
		"subtitle": _format_building_cost(cfg),
		"detail": _format_building_detail(cfg),
		"icon_text": UiDisplayText.icon_text(cfg),
		"fallback_icon_key": &"",
		"source_cfg": cfg,
		"state": "已选择" if selected else "",
		"cost_badge_text": str(int(cfg.get("ap_cost", 0))),
		"selected": selected,
		"disabled": cfg.is_empty(),
		"audio_cue": &"ui_card_select",
	}


func _make_shop_card(slot: Dictionary) -> Control:
	var unit_id := StringName(slot.get("unit_id", ""))
	var sold := bool(slot.get("sold", false))
	var slot_index := int(slot.get("slot_index", -1))
	var cfg := _get_unit_cfg(unit_id)
	var base_cost := int(cfg.get("cost_prestige", 0))
	var cost := _get_shop_unit_purchase_cost(cfg)
	var title := ""
	var subtitle := ""
	var detail := ""
	var state := ""
	if unit_id == StringName():
		title = "空槽位"
	else:
		title = UiDisplayText.config_name(cfg, unit_id)
		subtitle = UiDisplayText.class_label(str(cfg.get("class", "")))
		detail = UiDisplayText.tier_label(base_cost)
		if sold:
			state = "已购买"
		elif _current_prestige < cost:
			state = "声望不足"
	var card := BuildListCardScene.instantiate() as Control
	card.call("configure", {
		"title": title,
		"subtitle": subtitle,
		"detail": detail,
		"state": state,
		"icon_text": _unit_icon_text(unit_id),
		"fallback_icon_key": StringName("class_%s" % String(cfg.get("class", ""))),
		"source_cfg": cfg,
		"cost_badge_text": str(cost) if unit_id != StringName() else "",
		"selected": slot_index == _selected_shop_slot_index,
		"disabled": sold or unit_id == StringName() or _current_phase != GameEnums.PHASE_DAY or _current_prestige < cost,
		"pressable_when_disabled": unit_id != StringName(),
		"audio_cue": &"ui_card_select",
	})
	card.connect(&"pressed", _on_shop_card_pressed.bind(slot_index))
	return card


func _make_empty_state(text_value: String) -> Control:
	var card := BuildListCardScene.instantiate() as Control
	card.call("configure", {
		"title": text_value,
		"icon_text": "-",
		"disabled": true,
		"audio_cue": &"ui_click",
	})
	return card


func _format_building_cost(cfg: Dictionary) -> String:
	if cfg.is_empty():
		return "配置未加载"
	return "木 %d   石 %d   魔 %d" % [
		int(cfg.get("cost_wood", 0)),
		int(cfg.get("cost_stone", 0)),
		int(cfg.get("cost_mana", 0))
	]


func _format_building_detail(cfg: Dictionary) -> String:
	if int(cfg.get("effect_radius", 0)) > 0:
		return _format_effect_text(cfg)
	return UiDisplayText.config_desc(cfg, _format_effect_text(cfg))


func _format_effect_text(cfg: Dictionary) -> String:
	var effect_type := StringName(cfg.get("effect_type", ""))
	var effect_value := float(cfg.get("effect_value", 0.0))
	var radius := _get_effective_building_radius(cfg)
	var range_text := _format_building_range_text(radius)
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
			return "%s内友军持续回复 %d 生命/秒" % [range_text, int(effect_value)]
		&"slow":
			return "%s内敌人移速降低 %.0f%%" % [range_text, effect_value * 100.0]
		&"attack_interval_reduce":
			return "%s内友军攻击间隔降低 %.0f%%" % [range_text, effect_value * 100.0]
		&"attack_bonus_flat":
			return "%s内友军攻击 +%d，夜晚开启时消耗 %d 魔力矿" % [
				range_text,
				int(effect_value),
				int(cfg.get("night_mana_cost", 0))
			]
		_:
			return "暂无说明"


func _format_building_range_text(radius: int) -> String:
	if radius <= 0:
		return "自身格"
	return "一定范围"


func _get_effective_building_radius(cfg: Dictionary) -> int:
	var radius := int(cfg.get("effect_radius", 0))
	if radius <= 0:
		return radius
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("get_buff_effect_total_for_building"):
		radius += int(round(float(run_state.get_buff_effect_total_for_building(&"building_aura_radius_add", cfg))))
	return max(radius, 0)


func _get_action_panel() -> Node:
	var action_panel := get_node_or_null("../../ActionPanelSlot/ActionPanel")
	if action_panel == null:
		action_panel = get_node_or_null("../ActionPanel")
	return action_panel


func _on_building_card_pressed(building_id: StringName) -> void:
	_selected_building_id = building_id
	refresh_from_state()
	var action_panel := _get_action_panel()
	if action_panel != null and action_panel.has_method("set_mode_build"):
		action_panel.set_mode_build(building_id)


func _on_shop_card_pressed(slot_index: int) -> void:
	var preview := _make_shop_preview_payload(slot_index)
	if preview.is_empty():
		return
	_selected_shop_slot_index = slot_index
	refresh_from_state()
	shop_unit_preview_requested.emit(
		slot_index,
		StringName(preview.get("unit_id", "")),
		int(preview.get("price", 0)),
		bool(preview.get("can_purchase", false)),
		String(preview.get("disabled_reason", ""))
	)


func _emit_selected_shop_preview() -> void:
	if _selected_shop_slot_index < 0:
		return
	var preview := _make_shop_preview_payload(_selected_shop_slot_index)
	if preview.is_empty():
		return
	shop_unit_preview_requested.emit(
		_selected_shop_slot_index,
		StringName(preview.get("unit_id", "")),
		int(preview.get("price", 0)),
		bool(preview.get("can_purchase", false)),
		String(preview.get("disabled_reason", ""))
	)


func _make_shop_preview_payload(slot_index: int) -> Dictionary:
	var slot := _get_shop_slot(slot_index)
	if slot.is_empty():
		return {}
	var unit_id := StringName(slot.get("unit_id", ""))
	if unit_id == StringName():
		return {}
	var cfg := _get_unit_cfg(unit_id)
	var price := _get_shop_unit_purchase_cost(cfg)
	var sold := bool(slot.get("sold", false))
	var reason := ""
	var can_purchase := true
	if sold:
		can_purchase = false
		reason = "已售出"
	elif _current_phase != GameEnums.PHASE_DAY:
		can_purchase = false
		reason = "仅白天可购买"
	elif _current_prestige < price:
		can_purchase = false
		reason = "声望不足"
	return {
		"unit_id": unit_id,
		"price": price,
		"can_purchase": can_purchase,
		"disabled_reason": reason
	}


func _get_shop_slot(slot_index: int) -> Dictionary:
	for slot in _stock_slots:
		if int((slot as Dictionary).get("slot_index", -1)) == slot_index:
			return (slot as Dictionary)
	return {}


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
	_selection_label.text = "当前选择：%s" % UiDisplayText.config_name(cfg, _selected_building_id)


func _on_shop_stock_changed(stock_slots: Array[Dictionary]) -> void:
	_stock_slots.clear()
	for slot in stock_slots:
		_stock_slots.append((slot as Dictionary).duplicate(true))
	refresh_from_state()
	_emit_selected_shop_preview()


func _sync_shop_stock_from_manager() -> void:
	var shop_manager := get_node_or_null("../../Managers/ShopManager")
	if shop_manager == null or not shop_manager.has_method("get_current_stock"):
		return
	_on_shop_stock_changed(shop_manager.get_current_stock())


func _on_shop_action_result(action: StringName, result: Dictionary) -> void:
	_message_label.text = "购买成功" if action == &"buy" and result.get("ok", false) else String(result.get("message", "操作失败"))
	if action == &"refresh" and result.get("ok", false):
		_message_label.text = "商店已刷新"
		_selected_shop_slot_index = -1
	if action == &"buy":
		_emit_selected_shop_preview()


func _on_building_placed(_building_runtime_id: int, building_id: StringName, _cell: Vector2i) -> void:
	if _current_mode != MODE_BUILD or building_id != _selected_building_id:
		return
	_selected_building_id = &""
	refresh_from_state()


func _on_prestige_changed(value: int) -> void:
	_current_prestige = value
	refresh_from_state()


func _on_buffs_changed(_buff_ids: Array[StringName]) -> void:
	refresh_from_state()


func _get_building_cfg(building_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_building_cfg(building_id) if data_repo != null else {}


func _get_unit_cfg(unit_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_unit_cfg(unit_id) if data_repo != null else {}


func _get_shop_refresh_cost() -> int:
	var shop_manager := get_node_or_null("../../Managers/ShopManager")
	if shop_manager != null and shop_manager.has_method("get_refresh_cost"):
		return int(shop_manager.get_refresh_cost())
	return REFRESH_COST


func _get_shop_unit_purchase_cost(cfg: Dictionary) -> int:
	if cfg.is_empty():
		return 0
	var shop_manager := get_node_or_null("../../Managers/ShopManager")
	if shop_manager != null and shop_manager.has_method("get_unit_purchase_cost"):
		return int(shop_manager.get_unit_purchase_cost(cfg))
	return int(cfg.get("cost_prestige", 0))


func _format_shop_cost(base_cost: int, cost: int) -> String:
	if cost != base_cost:
		return "%d 声望（原 %d）" % [cost, base_cost]
	return "%d 声望" % cost


func _unit_icon_text(unit_id: StringName) -> String:
	var cfg := _get_unit_cfg(unit_id)
	var class_icon := UiDisplayText.class_label(str(cfg.get("class", "")))
	return UiDisplayText.icon_text(cfg, class_icon)


func set_visible_for_phase(phase: int) -> void:
	_current_phase = phase
	refresh_from_state()


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	set_visible_for_phase(new_phase)


func _on_data_loaded() -> void:
	refresh_from_state()
