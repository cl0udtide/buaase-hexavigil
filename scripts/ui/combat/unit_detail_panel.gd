extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")
const UiDisplayText = preload("res://scripts/ui/ui_display_text.gd")

signal cast_skill_requested
signal retreat_requested
signal purchase_requested(slot_index: int)

@onready var _panel_base: Panel = %PanelBase
@onready var _title_label: Label = %TitleLabel
@onready var _level_label: Label = %LevelLabel
@onready var _damage_pill: Panel = %DamagePill
@onready var _facing_pill: Panel = %FacingPill
@onready var _damage_label: Label = %DamageLabel
@onready var _facing_label: Label = %FacingLabel
@onready var _header_strip: Panel = %HeaderStrip
@onready var _vitals_base: Panel = %VitalsSectionBase
@onready var _portrait_backplate: Panel = %PortraitBackplate
@onready var _portrait_texture: TextureRect = %PortraitTexture
@onready var _portrait_frame: Panel = %PortraitFrame
@onready var _portrait_label: Label = %PortraitLabel
@onready var _hp_value_label: Label = %HpValueLabel
@onready var _hp_bar: Control = %HpBar
@onready var _hp_track: Panel = %HpTrack
@onready var _hp_fill: Panel = %HpFill
@onready var _sp_value_label: Label = %SpValueLabel
@onready var _sp_bar: Control = %SpBar
@onready var _sp_track: Panel = %SpTrack
@onready var _sp_fill: Panel = %SpFill
@onready var _stats_base: Panel = %StatsSectionBase
@onready var _atk_stat_label: Label = %AtkStatLabel
@onready var _def_stat_label: Label = %DefStatLabel
@onready var _res_stat_label: Label = %ResStatLabel
@onready var _block_stat_label: Label = %BlockStatLabel
@onready var _aspd_stat_label: Label = %AspdStatLabel
@onready var _skill_base: Panel = %SkillSectionBase
@onready var _skill_icon_backplate: Panel = %SkillIconBackplate
@onready var _skill_icon_texture: TextureRect = %SkillIconTexture
@onready var _skill_icon_frame: Panel = %SkillIconFrame
@onready var _skill_icon_label: Label = %SkillIconLabel
@onready var _skill_title_label: Label = %SkillTitleLabel
@onready var _skill_status_label: Label = %SkillStatusLabel
@onready var _skill_scroll: ScrollContainer = %SkillScroll
@onready var _skill_label: Label = %SkillLabel
@onready var _detail_source_label: Label = %DetailSourceLabel
@onready var _purchase_button: Button = %PurchaseButton
@onready var _purchase_reason_label: Label = %PurchaseReasonLabel
@onready var _cast_button: Button = %CastSkillButton
@onready var _retreat_button: Button = %RetreatButton

var _last_skill_scroll_key := ""
var _hp_ratio := 0.0
var _sp_ratio := 0.0
var _shop_slot_index := -1


func _ready() -> void:
	AppTheme.apply(self)
	_panel_base.add_theme_stylebox_override("panel", GameUiStyle.right_detail_sidebar())
	GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin") as MarginContainer, GameUiStyle.FRAME_RIGHT_DETAIL_SIDEBAR, Vector4(2.0, -4.0, 2.0, 2.0))
	var main_vbox := get_node_or_null("ContentMargin/MainVBox") as VBoxContainer
	if main_vbox != null:
		main_vbox.add_theme_constant_override("separation", 12)
	_header_strip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_damage_pill.add_theme_stylebox_override("panel", GameUiStyle.compact_panel(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_CARD, false))
	_facing_pill.add_theme_stylebox_override("panel", GameUiStyle.compact_panel(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_CARD, false))
	for section_base in [_vitals_base, _stats_base, _skill_base]:
		section_base.add_theme_stylebox_override("panel", GameUiStyle.detail_section())
	GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin/MainVBox/VitalsSection/VitalsMargin") as MarginContainer, GameUiStyle.FRAME_DETAIL_SECTION, Vector4(2.0, 2.0, 2.0, 2.0))
	GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin/MainVBox/StatsSection/StatsMargin") as MarginContainer, GameUiStyle.FRAME_DETAIL_SECTION, Vector4(2.0, 2.0, 2.0, 2.0))
	GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin/MainVBox/SkillSection/SkillMargin") as MarginContainer, GameUiStyle.FRAME_DETAIL_SECTION, Vector4(4.0, 4.0, 4.0, 4.0))
	var skill_section := get_node_or_null("ContentMargin/MainVBox/SkillSection") as Control
	if skill_section != null:
		skill_section.custom_minimum_size = Vector2(0.0, 210.0)
		skill_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_skill_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_skill_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_skill_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_backplate.add_theme_stylebox_override("panel", GameUiStyle.icon_tile())
	_portrait_frame.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_ICON_TILE, Color.TRANSPARENT, GameUiStyle.STROKE_SOFT, false))
	_skill_icon_backplate.add_theme_stylebox_override("panel", GameUiStyle.icon_tile())
	_skill_icon_frame.add_theme_stylebox_override("panel", GameUiStyle.frame_box(GameUiStyle.FRAME_ICON_TILE, Color.TRANSPARENT, GameUiStyle.STROKE_SOFT, false))
	_title_label.add_theme_color_override("font_color", GameUiStyle.TEXT_ON_PARCHMENT)
	_level_label.add_theme_color_override("font_color", GameUiStyle.TEXT_ON_PARCHMENT)
	_damage_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_facing_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_hp_value_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	_sp_value_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	GameUiStyle.center_label_text(_title_label)
	for label in [_damage_label, _facing_label]:
		GameUiStyle.center_label_text(label)
	for label in [_atk_stat_label, _def_stat_label, _res_stat_label, _block_stat_label, _aspd_stat_label]:
		label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
		label.add_theme_color_override("font_shadow_color", GameUiStyle.TEXT_SHADOW)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
	_skill_title_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_skill_status_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_skill_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_skill_label.add_theme_constant_override("line_spacing", 3)
	_portrait_label.add_theme_color_override("font_color", GameUiStyle.ACCENT)
	_skill_icon_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_hp_track.add_theme_stylebox_override("panel", GameUiStyle.progress_background())
	_hp_fill.add_theme_stylebox_override("panel", GameUiStyle.progress_fill(GameUiStyle.DANGER))
	_sp_track.add_theme_stylebox_override("panel", GameUiStyle.progress_background())
	_sp_fill.add_theme_stylebox_override("panel", GameUiStyle.progress_fill(Color(0.18, 0.72, 0.95, 0.95)))
	_hp_bar.resized.connect(_refresh_progress_fills)
	_sp_bar.resized.connect(_refresh_progress_fills)
	_style_action_button(_cast_button, GameUiStyle.ACCENT)
	_style_action_button(_retreat_button, GameUiStyle.STROKE_SOFT)
	_style_action_button(_purchase_button, GameUiStyle.AMBER)
	_detail_source_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_purchase_reason_label.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED_DIM)
	_cast_button.pressed.connect(func() -> void: cast_skill_requested.emit())
	_retreat_button.pressed.connect(func() -> void: retreat_requested.emit())
	_purchase_button.pressed.connect(_on_purchase_pressed)
	_ensure_scroll_wrapper()
	clear_unit()


func show_unit(unit: Node, display_name: String, damage_label: String, direction_label: String) -> void:
	if unit == null:
		clear_unit()
		return
	visible = true
	_shop_slot_index = -1
	_set_action_mode(&"deployed", "已部署单位", false, "")
	var sp_max := float(unit.cfg.get("sp_max", 0.0))
	_title_label.text = display_name
	_apply_texture_or_text(_portrait_texture, _portrait_label, UiArtRegistry.get_portrait_texture(unit.cfg), _icon_text(unit.cfg, "◆"))
	_apply_texture_or_text(_skill_icon_texture, _skill_icon_label, _skill_icon_texture_from_cfg(unit.cfg), _icon_text(unit.cfg, "◇"))
	_level_label.text = "#%d" % int(unit.get_runtime_id())
	_damage_label.text = "伤害 %s" % damage_label
	_facing_label.text = "朝向 %s" % direction_label
	_set_progress(_hp_bar, _hp_fill, float(unit.current_hp), max(float(unit.max_hp), 1.0))
	_hp_bar.tooltip_text = "HP %d/%d" % [int(unit.current_hp), int(unit.max_hp)]
	_hp_value_label.text = "生命 %d/%d" % [int(unit.current_hp), int(unit.max_hp)]
	_set_progress(_sp_bar, _sp_fill, float(unit.sp), max(sp_max, 1.0))
	_sp_bar.tooltip_text = "SP %.0f/%.0f" % [float(unit.sp), sp_max]
	_sp_value_label.text = "SP %.0f/%.0f" % [float(unit.sp), sp_max]
	_atk_stat_label.text = "攻击 %d" % (int(unit.get_effective_atk()) if unit.has_method("get_effective_atk") else int(unit.atk))
	_def_stat_label.text = "防御 %d" % int(unit.defense)
	_res_stat_label.text = "法抗 %d" % int(unit.resistance)
	_block_stat_label.text = "阻挡 %d" % int(unit.block_count)
	_aspd_stat_label.text = "攻速 %.2fs" % float(unit.attack_interval)
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
	_skill_status_label.text = "就绪" if status_lines.is_empty() and unit.can_cast_skill() else "未就绪"
	if not status_lines.is_empty():
		_skill_status_label.text = " / ".join(status_lines)
	_skill_label.text = unit.get_skill_description()
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


func show_operator_preview(operator_info: Dictionary, unit_cfg: Dictionary, state: StringName, status_text: String = "") -> void:
	_shop_slot_index = -1
	var display_name := String(operator_info.get("name", unit_cfg.get("name", operator_info.get("unit_id", ""))))
	var source_text := "待部署干员"
	if state == &"cooldown":
		source_text = "再部署冷却"
	if not status_text.strip_edges().is_empty():
		source_text = "%s  %s" % [source_text, status_text]
	_show_cfg_preview(display_name, unit_cfg, "#--", source_text)
	_set_action_mode(&"preview", source_text, false, "")


func show_shop_unit_preview(slot_index: int, unit_id: StringName, unit_cfg: Dictionary, price: int, can_purchase: bool, disabled_reason: String = "") -> void:
	var display_name := UiDisplayText.config_name(unit_cfg, unit_id)
	var source_text := "招募商店  槽位 %d  价格 %d 声望" % [slot_index + 1, price]
	_show_cfg_preview(display_name, unit_cfg, "#%d" % (slot_index + 1), source_text)
	_shop_slot_index = slot_index
	var reason := disabled_reason
	if can_purchase:
		reason = ""
	_set_action_mode(&"shop", source_text, can_purchase, reason, price)


func clear_unit() -> void:
	visible = false
	_shop_slot_index = -1
	_last_skill_scroll_key = ""
	_title_label.text = "未选中"
	_level_label.text = "#--"
	_damage_label.text = "伤害 --"
	_facing_label.text = "朝向 --"
	_portrait_texture.visible = false
	_portrait_label.visible = true
	_portrait_label.text = "◆"
	_skill_icon_texture.visible = false
	_skill_icon_label.visible = true
	_skill_icon_label.text = "◇"
	_set_progress(_hp_bar, _hp_fill, 0.0, 1.0)
	_set_progress(_sp_bar, _sp_fill, 0.0, 1.0)
	_hp_value_label.text = "生命 --/--"
	_sp_value_label.text = "SP --/--"
	_atk_stat_label.text = "攻击 --"
	_def_stat_label.text = "防御 --"
	_res_stat_label.text = "法抗 --"
	_block_stat_label.text = "阻挡 --"
	_aspd_stat_label.text = "攻速 --"
	_skill_title_label.text = "技能"
	_skill_status_label.text = "未选中"
	_skill_label.text = "选择场上单位后显示技能描述。"
	_cast_button.text = "激活技能"
	_cast_button.disabled = true
	_retreat_button.disabled = true
	_set_action_mode(&"empty", "选择单位、干员或商店商品", false, "")


func _show_cfg_preview(display_name: String, cfg: Dictionary, level_text: String, source_text: String) -> void:
	visible = true
	_last_skill_scroll_key = ""
	_title_label.text = display_name
	_level_label.text = level_text
	_damage_label.text = "伤害 %s" % _damage_label_from_cfg(cfg)
	_facing_label.text = "来源 预览"
	_apply_texture_or_text(_portrait_texture, _portrait_label, UiArtRegistry.get_portrait_texture(cfg), _icon_text(cfg, "*"))
	_apply_texture_or_text(_skill_icon_texture, _skill_icon_label, _skill_icon_texture_from_cfg(cfg), _icon_text(cfg, "*"))
	var max_hp := int(cfg.get("max_hp", 0))
	var sp_max := float(cfg.get("sp_max", 0.0))
	_set_progress(_hp_bar, _hp_fill, float(max_hp), maxf(float(max_hp), 1.0))
	_set_progress(_sp_bar, _sp_fill, 0.0, maxf(sp_max, 1.0))
	_hp_bar.tooltip_text = "HP %d" % max_hp
	_sp_bar.tooltip_text = "SP 0/%.0f" % sp_max
	_hp_value_label.text = "生命 %d" % max_hp
	_sp_value_label.text = "SP 0/%.0f" % sp_max
	_atk_stat_label.text = "攻击 %d" % int(cfg.get("atk", 0))
	_def_stat_label.text = "防御 %d" % int(cfg.get("def", 0))
	_res_stat_label.text = "法抗 %d" % int(cfg.get("res", 0))
	_block_stat_label.text = "阻挡 %d" % int(cfg.get("block", 0))
	_aspd_stat_label.text = "攻速 %.2fs" % float(cfg.get("attack_interval", 0.0))
	_skill_title_label.text = String(cfg.get("skill_name", cfg.get("skill_id", "技能")))
	_skill_status_label.text = source_text
	_skill_label.text = String(cfg.get("skill_description", "暂无技能说明"))
	_skill_scroll.scroll_vertical = 0


func _set_action_mode(mode: StringName, source_text: String, can_purchase: bool, reason: String, price: int = 0) -> void:
	_detail_source_label.text = source_text
	_detail_source_label.visible = not source_text.strip_edges().is_empty()
	var is_shop := mode == &"shop"
	var is_deployed := mode == &"deployed"
	_purchase_button.visible = is_shop
	_purchase_reason_label.visible = is_shop and not reason.strip_edges().is_empty()
	_purchase_reason_label.text = reason
	_purchase_button.disabled = not can_purchase
	_purchase_button.text = "购买 %d 声望" % price if is_shop and price > 0 else "购买"
	_cast_button.visible = is_deployed or mode == &"empty"
	_retreat_button.visible = is_deployed or mode == &"empty"
	if mode == &"preview":
		_cast_button.visible = false
		_retreat_button.visible = false


func _ensure_scroll_wrapper() -> void:
	var content_margin := get_node_or_null("ContentMargin") as MarginContainer
	var main_vbox := get_node_or_null("ContentMargin/MainVBox") as VBoxContainer
	if content_margin == null or main_vbox == null:
		return
	var scroll := ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_margin.remove_child(main_vbox)
	content_margin.add_child(scroll)
	scroll.add_child(main_vbox)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _on_purchase_pressed() -> void:
	if _shop_slot_index >= 0:
		purchase_requested.emit(_shop_slot_index)


func _damage_label_from_cfg(cfg: Dictionary) -> String:
	match String(cfg.get("damage_type", "physical")):
		"magic":
			return UiDisplayText.damage_type_label(GameEnums.DAMAGE_MAGIC)
		"true":
			return UiDisplayText.damage_type_label(GameEnums.DAMAGE_TRUE)
		_:
			return UiDisplayText.damage_type_label(GameEnums.DAMAGE_PHYSICAL)


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
	fill.offset_left = 0.0
	fill.offset_top = 0.0
	fill.offset_right = maxf(0.0, bar.size.x * ratio)
	fill.offset_bottom = 0.0


func _style_action_button(button: Button, accent: Color) -> void:
	GameUiStyle.center_button_text(button)
	var normal_style := GameUiStyle.skill_button_primary() if accent == GameUiStyle.ACCENT else GameUiStyle.secondary_button()
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.AMBER))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.42))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.10))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_INVERTED_DIM)


func _skill_icon_texture_from_cfg(cfg: Dictionary) -> Texture2D:
	var key := StringName(cfg.get("skill_icon_key", cfg.get("icon_key", "")))
	return UiArtRegistry.get_texture(key, &"icon")


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


func _format_unit_ammo_status(unit: Node) -> String:
	if unit == null or not unit.has_method("get_skill_ammo_status"):
		return ""
	var ammo_status: Dictionary = unit.get_skill_ammo_status()
	var max_ammo := int(ammo_status.get("max", 0))
	if max_ammo <= 0:
		return ""
	var label := String(ammo_status.get("label", "弹药"))
	return "%s：%d/%d" % [label, int(ammo_status.get("current", 0)), max_ammo]
