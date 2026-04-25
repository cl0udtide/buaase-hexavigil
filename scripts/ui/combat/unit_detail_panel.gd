extends PanelContainer

const CombatUiStyle = preload("res://scripts/ui/combat/combat_ui_style.gd")

signal cast_skill_requested
signal retreat_requested

@onready var _title_label: Label = %TitleLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _sp_bar: ProgressBar = %SpBar
@onready var _stats_label: Label = %StatsLabel
@onready var _skill_label: Label = %SkillLabel
@onready var _cast_button: Button = %CastSkillButton
@onready var _retreat_button: Button = %RetreatButton


func _ready() -> void:
	add_theme_stylebox_override("panel", CombatUiStyle.panel(CombatUiStyle.BG, CombatUiStyle.ACCENT, 2.0, 8.0))
	_title_label.add_theme_color_override("font_color", CombatUiStyle.ACCENT)
	_cast_button.add_theme_stylebox_override("normal", CombatUiStyle.button(CombatUiStyle.AMBER))
	_retreat_button.add_theme_stylebox_override("normal", CombatUiStyle.button(CombatUiStyle.DANGER))
	_cast_button.pressed.connect(func() -> void: cast_skill_requested.emit())
	_retreat_button.pressed.connect(func() -> void: retreat_requested.emit())
	visible = false


func show_unit(unit: Node, display_name: String, damage_label: String, direction_label: String) -> void:
	if unit == null:
		clear_unit()
		return
	visible = true
	var sp_max := float(unit.cfg.get("sp_max", 0.0))
	_title_label.text = "%s  #%d" % [display_name, int(unit.get_runtime_id())]
	_hp_bar.max_value = max(float(unit.max_hp), 1.0)
	_hp_bar.value = clamp(float(unit.current_hp), 0.0, _hp_bar.max_value)
	_hp_bar.tooltip_text = "HP %d/%d" % [int(unit.current_hp), int(unit.max_hp)]
	_sp_bar.max_value = max(sp_max, 1.0)
	_sp_bar.value = clamp(float(unit.sp), 0.0, _sp_bar.max_value)
	_sp_bar.tooltip_text = "SP %.0f/%.0f" % [float(unit.sp), sp_max]
	_stats_label.text = "HP %d/%d   SP %.0f/%.0f\nATK %d   DEF %d   RES %d   阻挡 %d\n攻速 %.2fs   伤害 %s   朝向 %s" % [
		int(unit.current_hp),
		int(unit.max_hp),
		float(unit.sp),
		sp_max,
		int(unit.get_effective_atk()) if unit.has_method("get_effective_atk") else int(unit.atk),
		int(unit.defense),
		int(unit.resistance),
		int(unit.block_count),
		float(unit.attack_interval),
		damage_label,
		direction_label
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
