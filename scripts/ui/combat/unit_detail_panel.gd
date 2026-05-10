extends PanelContainer

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")

signal cast_skill_requested
signal retreat_requested

@onready var _title_label: Label = %TitleLabel
@onready var _level_label: Label = %LevelLabel
@onready var _damage_pill: PanelContainer = %DamagePill
@onready var _facing_pill: PanelContainer = %FacingPill
@onready var _damage_label: Label = %DamageLabel
@onready var _facing_label: Label = %FacingLabel
@onready var _header_plate: PanelContainer = %HeaderPlate
@onready var _vitals_card: PanelContainer = %VitalsCard
@onready var _portrait_panel: PanelContainer = %PortraitPanel
@onready var _portrait_texture: TextureRect = %PortraitTexture
@onready var _portrait_label: Label = %PortraitLabel
@onready var _hp_value_label: Label = %HpValueLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _sp_value_label: Label = %SpValueLabel
@onready var _sp_bar: ProgressBar = %SpBar
@onready var _stats_card: PanelContainer = %StatsCard
@onready var _atk_stat_label: Label = %AtkStatLabel
@onready var _def_stat_label: Label = %DefStatLabel
@onready var _res_stat_label: Label = %ResStatLabel
@onready var _block_stat_label: Label = %BlockStatLabel
@onready var _aspd_stat_label: Label = %AspdStatLabel
@onready var _skill_card: PanelContainer = %SkillCard
@onready var _skill_icon_panel: PanelContainer = %SkillIconPanel
@onready var _skill_icon_texture: TextureRect = %SkillIconTexture
@onready var _skill_icon_label: Label = %SkillIconLabel
@onready var _skill_title_label: Label = %SkillTitleLabel
@onready var _skill_status_label: Label = %SkillStatusLabel
@onready var _skill_scroll: ScrollContainer = %SkillScroll
@onready var _skill_label: Label = %SkillLabel
@onready var _cast_button: Button = %CastSkillButton
@onready var _retreat_button: Button = %RetreatButton

var _last_skill_scroll_key := ""


func _ready() -> void:
	AppTheme.apply(self)
	add_theme_stylebox_override("panel", GameUiStyle.right_detail_sidebar())
	GameUiStyle.apply_frame_margin(get_node_or_null("MarginContainer") as MarginContainer, GameUiStyle.FRAME_RIGHT_DETAIL_SIDEBAR, Vector4(2.0, -4.0, 2.0, 2.0))
	var main_vbox := get_node_or_null("MarginContainer/MainVBox") as VBoxContainer
	if main_vbox != null:
		main_vbox.add_theme_constant_override("separation", 12)
	_header_plate.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_damage_pill.add_theme_stylebox_override("panel", GameUiStyle.compact_panel(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_CARD, false))
	_facing_pill.add_theme_stylebox_override("panel", GameUiStyle.compact_panel(GameUiStyle.STROKE_SOFT, GameUiStyle.BG_CARD, false))
	_vitals_card.add_theme_stylebox_override("panel", GameUiStyle.detail_section())
	_stats_card.add_theme_stylebox_override("panel", GameUiStyle.detail_section())
	GameUiStyle.apply_frame_margin(get_node_or_null("MarginContainer/MainVBox/VitalsCard/VitalsMargin") as MarginContainer, GameUiStyle.FRAME_DETAIL_SECTION, Vector4(2.0, 2.0, 2.0, 2.0))
	GameUiStyle.apply_frame_margin(get_node_or_null("MarginContainer/MainVBox/StatsCard/StatsMargin") as MarginContainer, GameUiStyle.FRAME_DETAIL_SECTION, Vector4(2.0, 2.0, 2.0, 2.0))
	GameUiStyle.apply_frame_margin(get_node_or_null("MarginContainer/MainVBox/SkillCard/SkillMargin") as MarginContainer, GameUiStyle.FRAME_DETAIL_SECTION, Vector4(4.0, 4.0, 4.0, 4.0))
	_skill_card.custom_minimum_size = Vector2(0.0, 210.0)
	_skill_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_skill_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_skill_icon_panel.custom_minimum_size = Vector2(48.0, 48.0)
	_skill_icon_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_stats_card.custom_minimum_size = Vector2(0.0, 92.0)
	_portrait_panel.custom_minimum_size = Vector2(88.0, 88.0)
	_portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_skill_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_skill_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_panel.add_theme_stylebox_override("panel", GameUiStyle.icon_tile())
	_skill_card.add_theme_stylebox_override("panel", GameUiStyle.detail_section())
	_skill_icon_panel.add_theme_stylebox_override("panel", GameUiStyle.icon_tile())
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
	_hp_bar.add_theme_stylebox_override("background", GameUiStyle.progress_background())
	_hp_bar.add_theme_stylebox_override("fill", GameUiStyle.progress_fill(GameUiStyle.DANGER))
	_hp_bar.custom_minimum_size = Vector2(0.0, 12.0)
	_sp_bar.add_theme_stylebox_override("background", GameUiStyle.progress_background())
	_sp_bar.add_theme_stylebox_override("fill", GameUiStyle.progress_fill(Color(0.18, 0.72, 0.95, 0.95)))
	_sp_bar.custom_minimum_size = Vector2(0.0, 12.0)
	_style_action_button(_cast_button, GameUiStyle.ACCENT)
	_style_action_button(_retreat_button, GameUiStyle.STROKE_SOFT)
	_cast_button.pressed.connect(func() -> void: cast_skill_requested.emit())
	_retreat_button.pressed.connect(func() -> void: retreat_requested.emit())
	clear_unit()


func show_unit(unit: Node, display_name: String, damage_label: String, direction_label: String) -> void:
	if unit == null:
		clear_unit()
		return
	visible = true
	var sp_max := float(unit.cfg.get("sp_max", 0.0))
	_title_label.text = display_name
	_apply_texture_or_text(_portrait_texture, _portrait_label, UiArtRegistry.get_portrait_texture(unit.cfg), _icon_text(unit.cfg, "◆"))
	_apply_texture_or_text(_skill_icon_texture, _skill_icon_label, _skill_icon_texture_from_cfg(unit.cfg), _icon_text(unit.cfg, "◇"))
	_level_label.text = "#%d" % int(unit.get_runtime_id())
	_damage_label.text = "伤害 %s" % damage_label
	_facing_label.text = "朝向 %s" % direction_label
	_hp_bar.max_value = max(float(unit.max_hp), 1.0)
	_hp_bar.value = clamp(float(unit.current_hp), 0.0, _hp_bar.max_value)
	_hp_bar.tooltip_text = "HP %d/%d" % [int(unit.current_hp), int(unit.max_hp)]
	_hp_value_label.text = "生命 %d/%d" % [int(unit.current_hp), int(unit.max_hp)]
	_sp_bar.max_value = max(sp_max, 1.0)
	_sp_bar.value = clamp(float(unit.sp), 0.0, _sp_bar.max_value)
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


func clear_unit() -> void:
	visible = true
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
	_hp_bar.max_value = 1.0
	_hp_bar.value = 0.0
	_sp_bar.max_value = 1.0
	_sp_bar.value = 0.0
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
