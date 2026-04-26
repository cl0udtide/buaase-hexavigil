extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")

const CATEGORY_RESOURCE: StringName = &"resource"
const CATEGORY_AURA: StringName = &"aura"

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
	]
}

var _current_category: StringName = CATEGORY_RESOURCE
var _selected_building_id: StringName = &""


func _ready() -> void:
	AppTheme.apply(self)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.phase_changed.connect(_on_phase_changed)
	_connect_category_button("%ResourceCategoryButton", CATEGORY_RESOURCE)
	_connect_category_button("%AuraCategoryButton", CATEGORY_AURA)
	_select_category(CATEGORY_RESOURCE)
	var run_state = AppRefs.run_state()
	if run_state != null:
		set_visible_for_phase(run_state.phase)
	else:
		set_visible_for_phase(GameEnums.PHASE_MENU)


func _connect_category_button(path: String, category: StringName) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button != null:
		button.pressed.connect(_on_category_pressed.bind(category))


func _on_category_pressed(category: StringName) -> void:
	_select_category(category)


func _select_category(category: StringName) -> void:
	_current_category = category
	_selected_building_id = &""
	_refresh_category_buttons()
	_refresh_selection_label()
	_rebuild_building_cards()


func _refresh_category_buttons() -> void:
	_set_category_button_state("%ResourceCategoryButton", _current_category == CATEGORY_RESOURCE)
	_set_category_button_state("%AuraCategoryButton", _current_category == CATEGORY_AURA)


func _set_category_button_state(path: String, selected: bool) -> void:
	var button := get_node_or_null(path) as Button
	if button == null:
		return
	button.disabled = selected


func _rebuild_building_cards() -> void:
	var container := get_node_or_null("%BuildCardList") as HBoxContainer
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	for building_id in _get_category_buildings():
		container.add_child(_make_building_card(building_id))


func _get_category_buildings() -> Array[StringName]:
	var result: Array[StringName] = []
	var source: Array = CATEGORY_BUILDINGS.get(_current_category, [])
	for building_id in source:
		result.append(StringName(building_id))
	return result


func _make_building_card(building_id: StringName) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(220.0, 140.0)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.clip_text = false
	button.text = _format_building_card_text(building_id)
	button.pressed.connect(_on_building_card_pressed.bind(building_id))
	return button


func _format_building_card_text(building_id: StringName) -> String:
	var cfg := _get_building_cfg(building_id)
	var name := String(cfg.get("name", building_id))
	var cost_text := "木%d  石%d  魔%d" % [
		int(cfg.get("cost_wood", 0)),
		int(cfg.get("cost_stone", 0)),
		int(cfg.get("cost_mana", 0))
	]
	var effect_text := String(cfg.get("desc", "")).strip_edges()
	if effect_text.is_empty():
		effect_text = _format_effect_text(cfg)
	return "%s\n消耗：%s\n效果：%s" % [name, cost_text, effect_text]


func _format_effect_text(cfg: Dictionary) -> String:
	var effect_type := StringName(cfg.get("effect_type", ""))
	var effect_value := float(cfg.get("effect_value", 0.0))
	var radius := int(cfg.get("effect_radius", 0))
	match effect_type:
		&"collect_wood":
			return "每天产出 %d 木材" % int(effect_value)
		&"collect_stone":
			return "每天产出 %d 石材" % int(effect_value)
		&"collect_mana":
			return "每天产出 %d 魔力矿" % int(effect_value)
		&"heal":
			return "范围 %d 内友军持续回复 %.0f 生命/秒" % [radius, effect_value]
		&"slow":
			return "范围 %d 内敌人移速降低 %.0f%%" % [radius, effect_value * 100.0]
		&"attack_interval_reduce":
			return "范围 %d 内友军攻击间隔降低 %.0f%%" % [radius, effect_value * 100.0]
		&"attack_bonus_flat":
			return "范围 %d 内友军攻击 +%d，夜晚耗魔 %d" % [
				radius,
				int(effect_value),
				int(cfg.get("night_mana_cost", 0))
			]
		_:
			return "暂无说明"


func _on_building_card_pressed(building_id: StringName) -> void:
	_selected_building_id = building_id
	_refresh_selection_label()
	var action_panel := get_node_or_null("../ActionPanel")
	if action_panel != null and action_panel.has_method("set_mode_build"):
		action_panel.set_mode_build(building_id)


func _refresh_selection_label() -> void:
	var label := get_node_or_null("%BuildSelectionLabel") as Label
	if label == null:
		return
	if _selected_building_id == StringName():
		label.text = "当前选择：无"
		return
	var cfg := _get_building_cfg(_selected_building_id)
	label.text = "当前选择：%s" % String(cfg.get("name", _selected_building_id))


func _get_building_cfg(building_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_building_cfg(building_id) if data_repo != null else {}


func set_visible_for_phase(phase: int) -> void:
	visible = phase == GameEnums.PHASE_DAY


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	set_visible_for_phase(new_phase)
