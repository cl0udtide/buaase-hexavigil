extends PanelContainer

const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

signal cast_skill_requested
signal retreat_requested

@onready var _title_label: Label = %TitleLabel
@onready var _level_label: Label = %LevelLabel
@onready var _type_label: Label = %TypeLabel
@onready var _portrait_panel: PanelContainer = %PortraitPanel
@onready var _portrait_label: Label = %PortraitLabel
@onready var _hp_value_label: Label = %HpValueLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _sp_value_label: Label = %SpValueLabel
@onready var _sp_bar: ProgressBar = %SpBar
@onready var _stats_label: Label = %StatsLabel
@onready var _skill_card: PanelContainer = %SkillCard
@onready var _skill_icon_panel: PanelContainer = %SkillIconPanel
@onready var _skill_icon_label: Label = %SkillIconLabel
@onready var _skill_label: Label = %SkillLabel
@onready var _cast_button: Button = %CastSkillButton
@onready var _retreat_button: Button = %RetreatButton


func _ready() -> void:
	add_theme_stylebox_override("panel", GameUiStyle.panel(GameUiStyle.BG_DARK, GameUiStyle.STROKE_SOFT, 1.0, 6.0))
	_skill_card.custom_minimum_size = Vector2(0.0, 128.0)
	_skill_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_skill_icon_panel.custom_minimum_size = Vector2(64.0, 64.0)
	_skill_icon_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait_panel.add_theme_stylebox_override("panel", GameUiStyle.panel(Color(0.02, 0.025, 0.03, 0.92), GameUiStyle.STROKE_SOFT, 1.0, 5.0))
	_skill_card.add_theme_stylebox_override("panel", GameUiStyle.panel(GameUiStyle.BG_CARD, GameUiStyle.STROKE_SOFT, 1.0, 5.0))
	_skill_icon_panel.add_theme_stylebox_override("panel", GameUiStyle.panel(Color(0.12, 0.04, 0.025, 0.86), GameUiStyle.AMBER, 1.0, 4.0))
	_title_label.add_theme_color_override("font_color", GameUiStyle.ACCENT)
	_level_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_type_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	_hp_value_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_sp_value_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_stats_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_skill_label.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_portrait_label.add_theme_color_override("font_color", Color(0.40, 0.48, 0.52, 0.95))
	_skill_icon_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_hp_bar.add_theme_stylebox_override("background", GameUiStyle.progress_background())
	_hp_bar.add_theme_stylebox_override("fill", GameUiStyle.progress_fill(GameUiStyle.ACCENT))
	_sp_bar.add_theme_stylebox_override("background", GameUiStyle.progress_background())
	_sp_bar.add_theme_stylebox_override("fill", GameUiStyle.progress_fill(Color(0.18, 0.72, 0.95, 0.95)))
	_style_action_button(_cast_button, GameUiStyle.ACCENT)
	_style_action_button(_retreat_button, GameUiStyle.STROKE_SOFT)
	_cast_button.pressed.connect(func() -> void: cast_skill_requested.emit())
	_retreat_button.pressed.connect(func() -> void: retreat_requested.emit())
	visible = false


func show_unit(unit: Node, display_name: String, damage_label: String, direction_label: String) -> void:
	if unit == null:
		clear_unit()
		return
	visible = true
	var sp_max := float(unit.cfg.get("sp_max", 0.0))
	_title_label.text = display_name
	_level_label.text = "#%d" % int(unit.get_runtime_id())
	_type_label.text = "%s / 朝向 %s" % [damage_label, direction_label]
	_hp_bar.max_value = max(float(unit.max_hp), 1.0)
	_hp_bar.value = clamp(float(unit.current_hp), 0.0, _hp_bar.max_value)
	_hp_bar.tooltip_text = "HP %d/%d" % [int(unit.current_hp), int(unit.max_hp)]
	_hp_value_label.text = "生命        %d/%d" % [int(unit.current_hp), int(unit.max_hp)]
	_sp_bar.max_value = max(sp_max, 1.0)
	_sp_bar.value = clamp(float(unit.sp), 0.0, _sp_bar.max_value)
	_sp_bar.tooltip_text = "SP %.0f/%.0f" % [float(unit.sp), sp_max]
	_sp_value_label.text = "SP          %.0f/%.0f" % [float(unit.sp), sp_max]
	_stats_label.text = "攻击 %d     防御 %d     法抗 %d\n阻挡 %d     攻速 %.2f秒     伤害 %s" % [
		int(unit.get_effective_atk()) if unit.has_method("get_effective_atk") else int(unit.atk),
		int(unit.defense),
		int(unit.resistance),
		int(unit.block_count),
		float(unit.attack_interval),
		damage_label
	]
	var active_remaining := float(unit.get_skill_active_remaining()) if unit.has_method("get_skill_active_remaining") else 0.0
	var active_text := ""
	if active_remaining < 0.0:
		active_text = "\n状态：常驻"
	elif active_remaining > 0.0:
		active_text = "\n状态：持续 %.1fs" % active_remaining
	_skill_label.text = "%s\n%s%s" % [unit.get_skill_name(), unit.get_skill_description(), active_text]
	_cast_button.disabled = not unit.can_cast_skill()
	_retreat_button.disabled = false


func clear_unit() -> void:
	visible = false
	_cast_button.disabled = true
	_retreat_button.disabled = true


func _style_action_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", GameUiStyle.accent_button(accent))
	button.add_theme_stylebox_override("hover", GameUiStyle.accent_button(GameUiStyle.AMBER))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER, 0.42))
	button.add_theme_stylebox_override("disabled", GameUiStyle.button(GameUiStyle.STROKE_SOFT, 0.10))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	button.add_theme_color_override("font_disabled_color", GameUiStyle.TEXT_MUTED)
