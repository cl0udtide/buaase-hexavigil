extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")


func _ready() -> void:
	AppTheme.apply(self)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.shop_stock_changed.connect(refresh_stock)
		event_bus.phase_changed.connect(_on_phase_changed)
	var refresh_button := get_node_or_null("%RefreshButton") as BaseButton
	if refresh_button != null:
		refresh_button.pressed.connect(func() -> void:
			var event_bus_inner = AppRefs.event_bus()
			if event_bus_inner != null:
				event_bus_inner.request_refresh_shop.emit()
		)
	_connect_buy_button("%BuyButton1")
	_connect_buy_button("%BuyButton2")
	_connect_buy_button("%BuyButton3")


func refresh_stock(stock: Array[StringName]) -> void:
	var label := get_node_or_null("%StockLabel") as Label
	if label != null:
		var display_names: PackedStringArray = []
		for unit_id in stock:
			display_names.append(String(unit_id))
		label.text = "商店: %s" % ", ".join(display_names)
	_bind_buy_buttons(stock)


func set_visible_for_phase(phase: int) -> void:
	visible = phase == GameEnums.PHASE_DAY


func _bind_buy_buttons(stock: Array[StringName]) -> void:
	var buttons := [
		get_node_or_null("%BuyButton1") as BaseButton,
		get_node_or_null("%BuyButton2") as BaseButton,
		get_node_or_null("%BuyButton3") as BaseButton
	]
	for i in range(buttons.size()):
		var button: BaseButton = buttons[i]
		if button == null:
			continue
		button.disabled = i >= stock.size()
		if i < stock.size():
			button.text = "购买 %s" % String(stock[i])
			button.set_meta("unit_id", stock[i])
		else:
			button.text = "空槽位"


func _connect_buy_button(path: String) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button != null and not button.pressed.is_connected(_on_buy_button_pressed.bind(button)):
		button.pressed.connect(_on_buy_button_pressed.bind(button))


func _on_buy_button_pressed(button: BaseButton) -> void:
	var unit_id := StringName(button.get_meta("unit_id", ""))
	if unit_id != StringName():
		var event_bus = AppRefs.event_bus()
		if event_bus != null:
			event_bus.request_buy_unit.emit(unit_id)


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	set_visible_for_phase(new_phase)
