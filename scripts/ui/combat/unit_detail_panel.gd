extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const OperatorProgression = preload("res://scripts/combat/operator_progression.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

signal cast_skill_requested
signal retreat_requested
signal purchase_requested(slot_index: int)
signal sell_requested(operator_key: StringName)

const _BAR_FILL_INSET := 2.0

@onready var _title_label: Label = %TitleLabel
@onready var _level_label: Label = %LevelLabel
@onready var _portrait_texture: TextureRect = %PortraitTexture
@onready var _portrait_label: Label = %PortraitLabel
@onready var _hp_value_label: Label = %HpValueLabel
@onready var _hp_bar: Control = %HpBar
@onready var _hp_fill: Panel = %HpFill
@onready var _sp_value_label: Label = %SpValueLabel
@onready var _sp_bar: Control = %SpBar
@onready var _sp_fill: Panel = %SpFill
@onready var _atk_stat_label: Label = %AtkStatLabel
@onready var _def_stat_label: Label = %DefStatLabel
@onready var _res_stat_label: Label = %ResStatLabel
@onready var _block_stat_label: Label = %BlockStatLabel
@onready var _aspd_stat_label: Label = %AspdStatLabel
@onready var _covenant_stat_label: Label = %CovenantStatLabel
@onready var _skill_icon_texture: TextureRect = %SkillIconTexture
@onready var _skill_icon_label: Label = %SkillIconLabel
@onready var _skill_title_label: Label = %SkillTitleLabel
@onready var _skill_status_label: Label = %SkillStatusLabel
@onready var _skill_clip_area: Control = %SkillClipArea
@onready var _skill_scroll: ScrollContainer = %SkillScroll
@onready var _skill_label: RichTextLabel = %SkillLabel
@onready var _purchase_button: Button = %PurchaseButton
@onready var _purchase_button_icon: TextureRect = %PurchaseButtonIcon
@onready var _star_up_button: Button = %StarUpButton
@onready var _star_up_button_icon: TextureRect = %StarUpButtonIcon
@onready var _sell_button: Button = %SellButton
@onready var _sell_button_icon: TextureRect = %SellButtonIcon
@onready var _cast_button: Button = %CastSkillButton
@onready var _cast_button_icon: TextureRect = %CastSkillButtonIcon
@onready var _retreat_button: Button = %RetreatButton
@onready var _retreat_button_icon: TextureRect = %RetreatButtonIcon

var _last_skill_scroll_key := ""
var _hp_ratio := 0.0
var _sp_ratio := 0.0
var _shop_slot_index := -1
var _preview_operator_key := StringName()
var _preview_operator_state := StringName()
var _stat_value_labels: Dictionary = {}
var _covenant_chips: HBoxContainer = null
var _star_cost_cluster: HBoxContainer = null
var _star_cost_mana_label: Label = null
var _star_cost_prestige_label: Label = null


func _ready() -> void:
	AppTheme.apply(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameUiStyle.apply_scroll_style(_skill_scroll)
	_skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_skill_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_skill_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_label.add_theme_color_override("font_color", GameUiStyle.TEXT_ON_PARCHMENT)
	_level_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_level_label.add_theme_font_size_override("font_size", 16)
	_hp_value_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	_sp_value_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	GameUiStyle.center_label_text(_title_label)
	for label in [_atk_stat_label, _def_stat_label, _res_stat_label, _block_stat_label, _aspd_stat_label, _covenant_stat_label]:
		label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
		label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		var pill_parent: Node = label.get_parent()
		if pill_parent is PanelContainer:
			(pill_parent as PanelContainer).add_theme_stylebox_override("panel", _flat_pill_style())
	for section_base in [%VitalsSectionBase, %StatsSectionBase, %SkillSectionBase]:
		(section_base as Panel).add_theme_stylebox_override("panel", GameUiStyle.flat_section())
	(%SkillDescFrame as PanelContainer).add_theme_stylebox_override("panel", GameUiStyle.flat_stat_pill())
	(%HpTrack as Panel).add_theme_stylebox_override("panel", GameUiStyle.bar_track())
	(%SpTrack as Panel).add_theme_stylebox_override("panel", GameUiStyle.bar_track())
	_skill_title_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_skill_status_label.add_theme_color_override("font_color", GameUiStyle.TEXT_MUTED)
	_skill_status_label.add_theme_font_size_override("font_size", 13)
	_skill_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skill_label.add_theme_color_override("default_color", GameUiStyle.TEXT)
	_skill_label.add_theme_constant_override("line_separation", 3)
	_portrait_label.add_theme_color_override("font_color", GameUiStyle.ACCENT)
	_skill_icon_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_hp_bar.resized.connect(_refresh_progress_fills)
	_sp_bar.resized.connect(_refresh_progress_fills)
	_skill_clip_area.resized.connect(_refresh_skill_text_scroll_size)
	_skill_scroll.resized.connect(_refresh_skill_text_scroll_size)
	_style_action_button(_cast_button, GameUiStyle.ACCENT)
	_style_action_button(_retreat_button, GameUiStyle.DANGER)
	_style_action_button(_purchase_button, GameUiStyle.AMBER)
	_style_action_button(_star_up_button, GameUiStyle.AMBER)
	_style_action_button(_sell_button, GameUiStyle.DANGER)
	_ensure_stat_icon_rows()
	_ensure_covenant_row()
	_ensure_star_cost_cluster()
	_cast_button.pressed.connect(func() -> void: cast_skill_requested.emit())
	_retreat_button.pressed.connect(func() -> void: retreat_requested.emit())
	_purchase_button.pressed.connect(_on_purchase_pressed)
	_star_up_button.pressed.connect(_on_star_up_pressed)
	_sell_button.pressed.connect(_on_sell_pressed)
	# 定向升星走 EventBus 请求链路（出售仍走 combat_hud 转发的旧链路）。
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.operator_star_upgrade_result.connect(_on_operator_star_upgrade_result)
		event_bus.materials_changed.connect(_on_materials_changed_for_star_up)
		event_bus.prestige_changed.connect(_on_prestige_changed_for_star_up)
		event_bus.phase_changed.connect(_on_phase_changed_for_star_up)
	clear_unit()
	call_deferred("_refresh_skill_text_scroll_size")


func show_unit(unit: Node, display_name: String, _damage_label_text: String, _direction_label_text: String) -> void:
	if unit == null:
		clear_unit()
		return
	visible = true
	_shop_slot_index = -1
	_preview_operator_key = StringName()
	_set_action_mode(&"deployed", false, "")
	var sp_max := float(unit.cfg.get("sp_max", 0.0))
	_title_label.text = display_name
	_apply_texture_or_text(_portrait_texture, _portrait_label, _portrait_for_cfg(unit.cfg), _icon_text(unit.cfg, "◆"))
	_apply_texture_or_text(_skill_icon_texture, _skill_icon_label, _skill_icon_texture_from_cfg(unit.cfg), _icon_text(unit.cfg, "◇"))
	var star := OperatorProgression.normalize_star(unit.cfg.get("operator_star", OperatorProgression.DEFAULT_STAR))
	_level_label.text = "%s #%d" % [_star_pips(star), int(unit.get_runtime_id())]
	_set_progress(_hp_bar, _hp_fill, float(unit.current_hp), max(float(unit.max_hp), 1.0))
	_hp_bar.tooltip_text = "HP %d/%d" % [int(unit.current_hp), int(unit.max_hp)]
	_hp_value_label.text = "生命 %d/%d" % [int(unit.current_hp), int(unit.max_hp)]
	_set_progress(_sp_bar, _sp_fill, float(unit.sp), max(sp_max, 1.0))
	_sp_bar.tooltip_text = "SP %.0f/%.0f" % [float(unit.sp), sp_max]
	_sp_value_label.text = "技力 %.0f/%.0f" % [float(unit.sp), sp_max]
	_set_stat(_atk_stat_label, "攻击", str(int(unit.get_effective_atk()) if unit.has_method("get_effective_atk") else int(unit.atk)))
	_set_stat(_def_stat_label, "防御", str(int(unit.defense)))
	_set_stat(_res_stat_label, "法抗", str(int(unit.resistance)))
	_set_stat(_block_stat_label, "阻挡", str(int(unit.block_count)))
	_set_stat(_aspd_stat_label, "攻速", str(int(round(unit.get_effective_attack_speed()))))
	_set_covenants(unit.cfg)
	var active_remaining := float(unit.get_skill_active_remaining()) if unit.has_method("get_skill_active_remaining") else 0.0
	var status_lines := PackedStringArray()
	var active_state := "ready"
	if active_remaining < 0.0:
		status_lines.append("状态：常驻")
		active_state = "permanent"
	elif active_remaining > 0.0:
		status_lines.append("状态：持续 %.1fs" % active_remaining)
		active_state = "active"
	var ammo_text := _format_unit_ammo_status(unit)
	if not ammo_text.is_empty():
		status_lines.append(ammo_text)
	_skill_title_label.text = unit.get_skill_name()
	var status_text := "就绪" if status_lines.is_empty() and unit.can_cast_skill() else "未就绪"
	if not status_lines.is_empty():
		status_text = " / ".join(status_lines)
	_set_skill_status(status_text, GameUiStyle.TEXT_INVERTED_DIM)
	_skill_label.text = UiDisplayText.decorate_skill_description(unit.get_skill_description())
	_refresh_skill_text_scroll_size()
	call_deferred("_refresh_skill_text_scroll_size")
	var skill_scroll_key := "%d:%s:%s:%s" % [int(unit.get_runtime_id()), unit.get_skill_name(), active_state, ammo_text]
	if skill_scroll_key != _last_skill_scroll_key:
		_skill_scroll.scroll_vertical = 0
		_last_skill_scroll_key = skill_scroll_key
	if active_remaining < 0.0:
		_cast_button.text = "技能常驻"
	elif active_remaining > 0.0:
		_cast_button.text = "技能运行中"
	else:
		_cast_button.text = "激活技能"
	_cast_button.disabled = active_remaining != 0.0 or not unit.can_cast_skill()
	_retreat_button.disabled = false
	_refresh_action_icons()


func show_operator_preview(operator_info: Dictionary, unit_cfg: Dictionary, state: StringName, status_text: String = "") -> void:
	_shop_slot_index = -1
	_preview_operator_key = StringName(operator_info.get("key", ""))
	_preview_operator_state = state
	var display_name := String(operator_info.get("name", unit_cfg.get("name", operator_info.get("unit_id", ""))))
	var star := OperatorProgression.normalize_star(operator_info.get("star", OperatorProgression.DEFAULT_STAR))
	var skill_status_text := status_text.strip_edges()
	if skill_status_text.is_empty():
		skill_status_text = "冷却" if state == &"cooldown" else "预览"
	_show_cfg_preview(display_name, unit_cfg, _star_pips(star), skill_status_text)
	if state == &"cooldown":
		_skill_status_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	var can_sell := state == &"ready"
	var sell_reason := "" if can_sell else "该干员当前不能出售"
	_set_action_mode(&"preview", false, "", 0, can_sell, sell_reason)
	_refresh_star_up_button()


func show_shop_unit_preview(slot_index: int, unit_id: StringName, unit_cfg: Dictionary, price: int, can_purchase: bool, disabled_reason: String = "") -> void:
	_preview_operator_key = StringName()
	var display_name := UiDisplayText.config_name(unit_cfg, unit_id)
	_show_cfg_preview(display_name, unit_cfg, _star_pips(OperatorProgression.DEFAULT_STAR), "可购买" if can_purchase else "已锁定")
	_shop_slot_index = slot_index
	var reason := disabled_reason
	if can_purchase:
		reason = ""
	_set_action_mode(&"shop", can_purchase, reason, price)


func clear_unit() -> void:
	visible = false
	_shop_slot_index = -1
	_preview_operator_key = StringName()
	_last_skill_scroll_key = ""
	_title_label.text = "未选中"
	_level_label.text = "#--"
	_portrait_texture.visible = false
	_portrait_texture.self_modulate = Color.WHITE
	_portrait_label.visible = true
	_portrait_label.text = "◆"
	_skill_icon_texture.visible = false
	_skill_icon_label.visible = true
	_skill_icon_label.text = "◇"
	_set_progress(_hp_bar, _hp_fill, 0.0, 1.0)
	_set_progress(_sp_bar, _sp_fill, 0.0, 1.0)
	_hp_value_label.text = "生命 --/--"
	_sp_value_label.text = "技力 --/--"
	_set_stat(_atk_stat_label, "攻击", "--")
	_set_stat(_def_stat_label, "防御", "--")
	_set_stat(_res_stat_label, "法抗", "--")
	_set_stat(_block_stat_label, "阻挡", "--")
	_set_stat(_aspd_stat_label, "攻速", "--")
	_render_covenant_chips(PackedStringArray(), "--")
	_skill_title_label.text = "技能"
	_set_skill_status("未选中", GameUiStyle.TEXT_MUTED)
	_skill_label.text = "选择场上单位后显示技能描述。"
	_cast_button.text = "激活技能"
	_cast_button.disabled = true
	_retreat_button.disabled = true
	_refresh_skill_text_scroll_size()
	call_deferred("_refresh_skill_text_scroll_size")
	_set_action_mode(&"empty", false, "")
	_refresh_action_icons()


func _show_cfg_preview(display_name: String, cfg: Dictionary, level_text: String, skill_status_text: String = "预览") -> void:
	visible = true
	_last_skill_scroll_key = ""
	_title_label.text = display_name
	_level_label.text = level_text
	_apply_texture_or_text(_portrait_texture, _portrait_label, _portrait_for_cfg(cfg), _icon_text(cfg, "*"))
	_apply_texture_or_text(_skill_icon_texture, _skill_icon_label, _skill_icon_texture_from_cfg(cfg), _icon_text(cfg, "*"))
	var max_hp := int(cfg.get("max_hp", 0))
	var sp_max := float(cfg.get("sp_max", 0.0))
	_set_progress(_hp_bar, _hp_fill, float(max_hp), maxf(float(max_hp), 1.0))
	_set_progress(_sp_bar, _sp_fill, 0.0, maxf(sp_max, 1.0))
	_hp_bar.tooltip_text = "HP %d/%d" % [max_hp, max_hp]
	_sp_bar.tooltip_text = "SP 0/%.0f" % sp_max
	_hp_value_label.text = "生命 %d/%d" % [max_hp, max_hp]
	_sp_value_label.text = "技力 0/%.0f" % sp_max
	_set_stat(_atk_stat_label, "攻击", str(int(cfg.get("atk", 0))))
	_set_stat(_def_stat_label, "防御", str(int(cfg.get("def", 0))))
	_set_stat(_res_stat_label, "法抗", str(int(cfg.get("res", 0))))
	_set_stat(_block_stat_label, "阻挡", str(int(cfg.get("block", 0))))
	_set_stat(_aspd_stat_label, "攻速", str(int(round(float(cfg.get("attack_speed", 100.0))))))
	_set_covenants(cfg)
	_skill_title_label.text = String(cfg.get("skill_name", cfg.get("skill_id", "技能")))
	_set_skill_status(skill_status_text, GameUiStyle.TEXT_MUTED)
	_skill_label.text = UiDisplayText.decorate_skill_description(String(cfg.get("skill_description", "暂无技能说明")))
	_refresh_skill_text_scroll_size()
	call_deferred("_refresh_skill_text_scroll_size")
	_skill_scroll.scroll_vertical = 0
	_refresh_action_icons()


func _set_covenants(cfg: Dictionary) -> void:
	var tags := PackedStringArray()
	var raw = cfg.get("covenants", [])
	if typeof(raw) == TYPE_ARRAY:
		for tag in raw:
			tags.append(String(tag))
	_render_covenant_chips(tags, "无")


func _render_covenant_chips(tags: PackedStringArray, placeholder: String) -> void:
	if _covenant_chips == null:
		# 盟约行未能重建时回落旧单标签格式
		_covenant_stat_label.text = "盟约 %s" % ("·".join(tags) if not tags.is_empty() else placeholder)
		return
	for child in _covenant_chips.get_children():
		child.queue_free()
	if tags.is_empty():
		var empty_label := Label.new()
		empty_label.text = placeholder
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", GameUiStyle.TEXT_MUTED)
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_covenant_chips.add_child(empty_label)
		return
	for tag in tags:
		var chip := PanelContainer.new()
		var chip_style := GameUiStyle.flat_chip(GameUiStyle.ACCENT_SOFT, GameUiStyle.STROKE_SOFT)
		chip_style.content_margin_left = 8.0
		chip_style.content_margin_right = 8.0
		chip_style.content_margin_top = 2.0
		chip_style.content_margin_bottom = 2.0
		chip.add_theme_stylebox_override("panel", chip_style)
		chip.tooltip_text = tag
		var chip_label := Label.new()
		chip_label.text = tag
		chip_label.add_theme_font_size_override("font_size", 13)
		chip_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
		chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(chip_label)
		_covenant_chips.add_child(chip)


func _ensure_covenant_row() -> void:
	if _covenant_stat_label == null:
		return
	var row_panel := _covenant_stat_label.get_parent()
	if row_panel == null or row_panel.get_node_or_null("CovenantRowBox") != null:
		return
	var row := HBoxContainer.new()
	row.name = "CovenantRowBox"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var insert_index := _covenant_stat_label.get_index()
	row_panel.remove_child(_covenant_stat_label)
	row_panel.add_child(row)
	row_panel.move_child(row, insert_index)
	row.add_child(_covenant_stat_label)
	_covenant_stat_label.text = "盟约"
	_covenant_stat_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_covenant_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_covenant_stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_covenant_stat_label.add_theme_font_size_override("font_size", 13)
	_covenant_stat_label.add_theme_color_override("font_color", GameUiStyle.TEXT_MUTED)
	_covenant_chips = HBoxContainer.new()
	_covenant_chips.name = "CovenantChips"
	_covenant_chips.add_theme_constant_override("separation", 6)
	_covenant_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_covenant_chips)


func _set_action_mode(mode: StringName, can_purchase: bool, reason: String, price: int = 0, can_sell: bool = false, sell_reason: String = "") -> void:
	var is_shop := mode == &"shop"
	var is_deployed := mode == &"deployed"
	var is_preview := mode == &"preview"
	_purchase_button.visible = is_shop
	_purchase_button.disabled = not can_purchase
	_purchase_button.tooltip_text = reason if is_shop and not reason.strip_edges().is_empty() else ""
	_purchase_button.text = "购买 %d 声望" % price if is_shop and price > 0 else "购买"
	_sell_button.visible = is_preview
	_sell_button.disabled = not can_sell
	_sell_button.tooltip_text = sell_reason if is_preview and not sell_reason.strip_edges().is_empty() else ""
	_sell_button.text = "出售 1 声望"
	_star_up_button.visible = is_preview
	if not is_preview:
		_star_up_button.disabled = true
		_star_up_button.tooltip_text = ""
	_cast_button.visible = is_deployed or mode == &"empty"
	_retreat_button.visible = is_deployed or mode == &"empty"
	_refresh_action_icons()


func _on_purchase_pressed() -> void:
	if _shop_slot_index >= 0:
		purchase_requested.emit(_shop_slot_index)


func _on_sell_pressed() -> void:
	if _preview_operator_key != StringName():
		sell_requested.emit(_preview_operator_key)


func _on_star_up_pressed() -> void:
	if _preview_operator_key == StringName():
		return
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_upgrade_operator_star.emit(_preview_operator_key)


## 按当前预览干员重算升星按钮：价格文案、满星/非后备/非白天/资源不足时禁用并给原因。
func _refresh_star_up_button() -> void:
	if not _star_up_button.visible or _preview_operator_key == StringName():
		return
	var run_state = AppRefs.run_state()
	if run_state == null or not run_state.has_method("get_owned_operator") or not run_state.has_method("get_operator_star_up_cost"):
		_star_up_button.disabled = true
		_set_star_cost_cluster_visible(false)
		return
	var operator_info: Dictionary = run_state.get_owned_operator(_preview_operator_key)
	if operator_info.is_empty():
		_star_up_button.disabled = true
		_set_star_cost_cluster_visible(false)
		_refresh_action_icons()
		return
	var star := OperatorProgression.normalize_star(operator_info.get("star", OperatorProgression.DEFAULT_STAR))
	var cost: Dictionary = run_state.get_operator_star_up_cost(star)
	if cost.is_empty():
		_star_up_button.text = "已满星"
		_star_up_button.disabled = true
		_star_up_button.tooltip_text = "该干员已达星级上限"
		_set_star_cost_cluster_visible(false)
		_refresh_action_icons()
		return
	var cost_mana := int(cost.get("mana", 0))
	var cost_prestige := int(cost.get("prestige", 0))
	var mana_short := int(run_state.mana) < cost_mana
	var prestige_short := int(run_state.prestige) < cost_prestige
	_star_up_button.text = "升星"
	var reason := ""
	if _preview_operator_state != &"ready":
		reason = "该干员当前不能升星"
	elif int(run_state.phase) != GameEnums.PHASE_DAY:
		reason = "只有白天可以升星"
	elif mana_short:
		reason = "魔力矿不足"
	elif prestige_short:
		reason = "声望不足"
	_star_up_button.disabled = not reason.is_empty()
	_star_up_button.tooltip_text = reason
	_update_star_cost_cluster(cost_mana, cost_prestige, mana_short, prestige_short)
	_refresh_action_icons()


## 升星成功后按 RunState 重渲染预览（星级、数值、按钮价格）；UnitManager 回发的失败结果只刷新按钮状态。
func _on_operator_star_upgrade_result(operator_key: StringName, result: Dictionary) -> void:
	if _preview_operator_key == StringName() or operator_key != _preview_operator_key:
		return
	if bool(result.get("ok", false)):
		_refresh_owned_operator_preview_from_state()
		_play_star_up_feedback()
	else:
		_refresh_star_up_button()


func _refresh_owned_operator_preview_from_state() -> void:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	if run_state == null or data_repo == null or not run_state.has_method("get_owned_operator"):
		return
	var operator_info: Dictionary = run_state.get_owned_operator(_preview_operator_key)
	if operator_info.is_empty():
		return
	var star := OperatorProgression.normalize_star(operator_info.get("star", OperatorProgression.DEFAULT_STAR))
	var unit_cfg: Dictionary = data_repo.get_unit_cfg(StringName(operator_info.get("unit_id", "")))
	show_operator_preview(operator_info, OperatorProgression.make_effective_unit_cfg(unit_cfg, star), _preview_operator_state)


func _on_materials_changed_for_star_up(_wood: int, _stone: int, _mana: int) -> void:
	_refresh_star_up_button()


func _on_prestige_changed_for_star_up(_value: int) -> void:
	_refresh_star_up_button()


func _on_phase_changed_for_star_up(_old_phase: int, _new_phase: int) -> void:
	_refresh_star_up_button()


func _refresh_skill_text_scroll_size() -> void:
	if _skill_scroll == null or _skill_label == null:
		return
	var text_width := _skill_scroll.size.x
	if text_width <= 1.0 and _skill_clip_area != null:
		text_width = _skill_clip_area.size.x
	if text_width <= 1.0 and _skill_scroll.get_parent() is Control:
		text_width = (_skill_scroll.get_parent() as Control).size.x
	if text_width <= 1.0:
		text_width = 1.0
	_skill_label.custom_minimum_size = Vector2(text_width, 0.0)
	var label_height := maxf(1.0, _skill_label.get_combined_minimum_size().y)
	_skill_label.custom_minimum_size = Vector2(text_width, label_height)
	_align_skill_viewport_to_lines()


## 视口高度对齐到整数行,避免末行被腰斩;基于 clip 区高度计算,非累计值,resized 重入安全。
func _align_skill_viewport_to_lines() -> void:
	if _skill_clip_area == null or _skill_label == null:
		return
	var font := _skill_label.get_theme_font("normal_font")
	var font_size := _skill_label.get_theme_font_size("normal_font_size")
	if font == null or font_size <= 0:
		return
	var line_h := font.get_height(font_size) + float(_skill_label.get_theme_constant("line_separation"))
	if line_h <= 1.0 or _skill_clip_area.size.y < line_h:
		return
	var remainder := fposmod(_skill_clip_area.size.y, line_h)
	_skill_scroll.offset_bottom = -remainder


func _set_progress(bar: Control, fill: Control, value: float, max_value: float) -> void:
	var ratio := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
	if bar == _hp_bar:
		_hp_ratio = ratio
	elif bar == _sp_bar:
		_sp_ratio = ratio
	_update_fill(bar, fill, ratio)
	call_deferred("_refresh_progress_fills")


func _refresh_progress_fills() -> void:
	_update_fill(_hp_bar, _hp_fill, _hp_ratio)
	_update_fill(_sp_bar, _sp_fill, _sp_ratio)


func _update_fill(bar: Control, fill: Control, ratio: float) -> void:
	if bar == null or fill == null:
		return
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_left = _BAR_FILL_INSET
	fill.offset_top = _BAR_FILL_INSET
	fill.offset_right = _BAR_FILL_INSET + maxf(0.0, (bar.size.x - _BAR_FILL_INSET * 2.0) * ratio)
	fill.offset_bottom = -_BAR_FILL_INSET


func _style_action_button(button: Button, accent: Color) -> void:
	GameUiStyle.center_button_text(button)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", accent.lerp(GameUiStyle.TEXT_INVERTED, 0.35))
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_INVERTED_DIM)


func _skill_icon_texture_from_cfg(cfg: Dictionary) -> Texture2D:
	return UiArtRegistry.get_skill_icon_texture(cfg)


func _refresh_action_icons() -> void:
	_set_button_icon(_cast_button, _cast_button_icon, UiArtRegistry.get_catalog_icon(&"skill_locked" if _cast_button.disabled else &"skill_ready"))
	_set_button_icon(_retreat_button, _retreat_button_icon, UiArtRegistry.get_catalog_icon(&"combat_retreat"))
	_set_button_icon(_purchase_button, _purchase_button_icon, UiArtRegistry.get_catalog_icon(&"button_cancel" if _purchase_button.disabled else &"button_confirm"))
	_set_button_icon(_star_up_button, _star_up_button_icon, UiArtRegistry.get_catalog_icon(&"button_cancel" if _star_up_button.disabled else &"button_confirm"))
	_set_button_icon(_sell_button, _sell_button_icon, UiArtRegistry.get_catalog_icon(&"button_cancel"))


func _set_button_icon(button: Button, icon_rect: TextureRect, texture: Texture2D) -> void:
	if button != null:
		# left=图标在文字左侧成组居中;center 会让图标与文字各自居中而互相叠印
		GameUiStyle.set_button_texture_icon(button, texture, &"left", 8.0)
	if icon_rect == null:
		return
	# 图标改由 Button.icon 跟随文字居中;场景里钉死的左缘 TextureRect 失效但保留引用
	icon_rect.texture = null
	icon_rect.visible = false


func _ensure_stat_icon_rows() -> void:
	_ensure_icon_row_for_label(_atk_stat_label, &"stat_atk")
	_ensure_icon_row_for_label(_def_stat_label, &"stat_def")
	_ensure_icon_row_for_label(_res_stat_label, &"stat_res")
	_ensure_icon_row_for_label(_block_stat_label, &"stat_block")
	_ensure_icon_row_for_label(_aspd_stat_label, &"stat_attack_speed")


func _ensure_icon_row_for_label(label: Label, icon_id: StringName) -> void:
	if label == null:
		return
	var parent := label.get_parent()
	if parent == null or parent.get_node_or_null("%sRow" % label.name) != null:
		return
	var texture := UiArtRegistry.get_catalog_icon(icon_id)
	if texture == null:
		return
	var row := HBoxContainer.new()
	row.name = "%sRow" % label.name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	if parent is PanelContainer:
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
	var insert_index := label.get_index()
	parent.remove_child(label)
	parent.add_child(row)
	parent.move_child(row, insert_index)
	var icon_rect := TextureRect.new()
	icon_rect.name = "IconTexture"
	icon_rect.set_custom_minimum_size(Vector2(18.0, 18.0))
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)
	row.add_child(label)
	icon_rect.texture = texture
	# 标签退化为弱化名称位,数值另起右对齐 Label,便于扫读对比
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", GameUiStyle.TEXT_MUTED)
	var value_label := Label.new()
	value_label.name = "%sValue" % label.name
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_label)
	_stat_value_labels[label] = value_label


func _apply_texture_or_text(texture_rect: TextureRect, label: Label, texture: Texture2D, fallback_text: String) -> void:
	texture_rect.texture = texture
	texture_rect.visible = texture != null
	label.visible = texture == null
	if texture == null:
		label.text = fallback_text


func _icon_text(cfg: Dictionary, fallback_text: String) -> String:
	var icon := String(cfg.get("icon_text", "")).strip_edges()
	if not icon.is_empty():
		return icon.substr(0, 1)
	return fallback_text


func _star_pips(star: int) -> String:
	var normalized := OperatorProgression.normalize_star(star)
	return "★".repeat(normalized) + "☆".repeat(OperatorProgression.MAX_STAR - normalized)


func _set_stat(label: Label, stat_name: String, value_text: String) -> void:
	var value_label: Label = _stat_value_labels.get(label)
	if value_label != null:
		label.text = stat_name
		value_label.text = value_text
	else:
		# 图标行未建成(图标缺资源)时回落整串文本
		label.text = "%s %s" % [stat_name, value_text]


func _set_skill_status(text: String, color: Color) -> void:
	_skill_status_label.text = text
	_skill_status_label.add_theme_color_override("font_color", color)


## 头像过渡方案:正式立绘缺位时回落职业图标(提亮),再缺才回落首字。
func _portrait_for_cfg(cfg: Dictionary) -> Texture2D:
	var texture := UiArtRegistry.get_portrait_texture(cfg)
	if texture != null:
		_portrait_texture.self_modulate = Color.WHITE
		return texture
	texture = UiArtRegistry.get_class_icon_texture(cfg)
	if texture != null:
		_portrait_texture.self_modulate = Color(1.55, 1.65, 1.7)
	return texture


func _flat_pill_style() -> StyleBoxFlat:
	var pill := GameUiStyle.flat_stat_pill()
	pill.content_margin_top = 3.0
	pill.content_margin_bottom = 3.0
	return pill


func _ensure_star_cost_cluster() -> void:
	if _star_cost_cluster != null or _star_up_button == null:
		return
	_star_cost_cluster = HBoxContainer.new()
	_star_cost_cluster.name = "CostCluster"
	_star_cost_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star_cost_cluster.add_theme_constant_override("separation", 3)
	_star_cost_cluster.visible = false
	_star_up_button.add_child(_star_cost_cluster)
	_star_cost_mana_label = _append_star_cost_entry(&"resource_mana")
	_star_cost_prestige_label = _append_star_cost_entry(&"resource_prestige")
	_star_up_button.resized.connect(_layout_star_cost_cluster)


func _append_star_cost_entry(icon_id: StringName) -> Label:
	var icon_rect := TextureRect.new()
	icon_rect.set_custom_minimum_size(Vector2(16.0, 16.0))
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture = UiArtRegistry.get_catalog_icon(icon_id)
	_star_cost_cluster.add_child(icon_rect)
	var cost_label := Label.new()
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star_cost_cluster.add_child(cost_label)
	return cost_label


func _update_star_cost_cluster(cost_mana: int, cost_prestige: int, mana_short: bool, prestige_short: bool) -> void:
	if _star_cost_cluster == null:
		# cluster 缺位时回落旧整串文案
		_star_up_button.text = "升星 %d魔力矿+%d声望" % [cost_mana, cost_prestige]
		return
	_star_cost_cluster.visible = true
	_star_cost_mana_label.text = str(cost_mana)
	_star_cost_mana_label.add_theme_color_override("font_color", GameUiStyle.DANGER if mana_short else GameUiStyle.AMBER)
	_star_cost_prestige_label.text = str(cost_prestige)
	_star_cost_prestige_label.add_theme_color_override("font_color", GameUiStyle.DANGER if prestige_short else GameUiStyle.AMBER)
	_star_cost_cluster.modulate = Color(1.0, 1.0, 1.0, 0.6) if _star_up_button.disabled else Color.WHITE
	call_deferred("_layout_star_cost_cluster")


func _set_star_cost_cluster_visible(value: bool) -> void:
	if _star_cost_cluster != null:
		_star_cost_cluster.visible = value


func _layout_star_cost_cluster() -> void:
	if _star_cost_cluster == null or not _star_cost_cluster.visible:
		return
	var cluster_size := _star_cost_cluster.get_combined_minimum_size()
	_star_cost_cluster.size = cluster_size
	_star_cost_cluster.position = Vector2(
		_star_up_button.size.x - cluster_size.x - 14.0,
		(_star_up_button.size.y - cluster_size.y) * 0.5
	)


func _play_star_up_feedback() -> void:
	if _level_label == null:
		return
	_level_label.pivot_offset = _level_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(_level_label, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_level_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _format_unit_ammo_status(unit: Node) -> String:
	if unit == null or not unit.has_method("get_skill_ammo_status"):
		return ""
	var ammo_status: Dictionary = unit.get_skill_ammo_status()
	var max_ammo := int(ammo_status.get("max", 0))
	if max_ammo <= 0:
		return ""
	var label := String(ammo_status.get("label", "弹药"))
	return "%s：%d/%d" % [label, int(ammo_status.get("current", 0)), max_ammo]
