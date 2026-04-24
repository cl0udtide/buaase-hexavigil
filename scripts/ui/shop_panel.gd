extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")

const REFRESH_COST := 2

var _stock_slots: Array[Dictionary] = []
var _current_prestige := 0
var _current_phase := GameEnums.PHASE_MENU


func _ready() -> void:
	AppTheme.apply(self)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.shop_stock_changed.connect(refresh_stock)
		event_bus.shop_action_result.connect(_on_shop_action_result)
		event_bus.prestige_changed.connect(_on_prestige_changed)
		event_bus.phase_changed.connect(_on_phase_changed)
	var refresh_button := get_node_or_null("%RefreshButton") as BaseButton
	if refresh_button != null:
		refresh_button.text = "刷新 %d 声望" % REFRESH_COST
		refresh_button.pressed.connect(_on_refresh_pressed)
	var run_state = AppRefs.run_state()
	if run_state != null:
		_current_prestige = run_state.prestige
		_current_phase = run_state.phase
	set_visible_for_phase(_current_phase)
	_update_refresh_button()


func refresh_stock(stock_slots: Array[Dictionary]) -> void:
	_stock_slots.clear()
	for slot in stock_slots:
		_stock_slots.append((slot as Dictionary).duplicate(true))
	_rebuild_shop_cards()
	_update_refresh_button()


func set_visible_for_phase(phase: int) -> void:
	visible = phase == GameEnums.PHASE_DAY
	_update_refresh_button()


func _rebuild_shop_cards() -> void:
	var container := get_node_or_null("%ShopCardFlow") as HFlowContainer
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	for slot in _stock_slots:
		container.add_child(_make_shop_card(slot))


func _make_shop_card(slot: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(118, 118)
	button.clip_text = true
	var slot_index := int(slot.get("slot_index", -1))
	var unit_id := StringName(slot.get("unit_id", ""))
	var sold := bool(slot.get("sold", false))
	button.set_meta("slot_index", slot_index)
	button.disabled = sold or unit_id == StringName() or _current_phase != GameEnums.PHASE_DAY
	button.text = _format_card_text(unit_id, sold)
	button.add_theme_color_override("font_color", _tier_color(unit_id))
	button.pressed.connect(_on_card_pressed.bind(slot_index))
	return button


func _format_card_text(unit_id: StringName, sold: bool) -> String:
	if sold:
		return "已购买"
	if unit_id == StringName():
		return "空槽位"
	var cfg := _get_unit_cfg(unit_id)
	var name := String(cfg.get("name", unit_id))
	var profession_name := _class_text(String(cfg.get("class", "")))
	var cost := int(cfg.get("cost_prestige", 0))
	return "%s\n%s  %s\n%d 声望" % [name, profession_name, _tier_text(cost), cost]


func _tier_text(cost: int) -> String:
	match cost:
		1:
			return "一阶"
		3:
			return "二阶"
		7:
			return "三阶"
		_:
			return "%d阶" % cost


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
			return Color.WHITE


func _get_unit_cfg(unit_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_unit_cfg(unit_id) if data_repo != null else {}


func _on_card_pressed(slot_index: int) -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_buy_shop_slot.emit(slot_index)


func _on_refresh_pressed() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_refresh_shop.emit()


func _on_shop_action_result(action: StringName, result: Dictionary) -> void:
	var label := get_node_or_null("%MessageLabel") as Label
	if label == null:
		return
	if result.get("ok", false):
		label.text = "购买成功" if action == &"buy" else "商店已刷新"
		return
	label.text = String(result.get("message", "操作失败"))


func _on_prestige_changed(value: int) -> void:
	_current_prestige = value
	_update_refresh_button()


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	_current_phase = new_phase
	set_visible_for_phase(new_phase)
	_rebuild_shop_cards()


func _update_refresh_button() -> void:
	var button := get_node_or_null("%RefreshButton") as BaseButton
	if button == null:
		return
	button.disabled = _current_phase != GameEnums.PHASE_DAY or _current_prestige < REFRESH_COST
