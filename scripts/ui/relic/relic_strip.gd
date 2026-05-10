extends PanelContainer

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const RELIC_ICON_SCENE := preload("res://scenes/ui/relic/RelicIcon.tscn")
const MAX_VISIBLE_RELICS := 6

signal panel_requested
signal relic_pressed(buff_id: StringName)

var _relic_ids: Array[StringName] = []
var _last_relic_ids: Array[StringName] = []
var _has_received_relics := false

@onready var _entry_button: Button = %EntryButton
@onready var _icon_row: HBoxContainer = %IconRow
@onready var _overflow_label: Label = %OverflowLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	add_theme_stylebox_override("panel", GameUiStyle.relic_strip())
	GameUiStyle.apply_frame_margin(get_node_or_null("StripMargin") as MarginContainer, GameUiStyle.FRAME_RELIC_STRIP)
	_entry_button.pressed.connect(func() -> void: panel_requested.emit())
	_style_entry_button()
	_overflow_label.add_theme_color_override("font_color", GameUiStyle.AMBER)
	_overflow_label.add_theme_font_size_override("font_size", 14)
	_overflow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	set_relics(_relic_ids)


func set_relics(relic_ids: Array[StringName]) -> void:
	_last_relic_ids = _relic_ids.duplicate()
	_relic_ids.clear()
	for relic_id in relic_ids:
		_relic_ids.append(relic_id)
	if is_node_ready():
		_refresh()
	_has_received_relics = true


func _refresh() -> void:
	_entry_button.text = "遗物 %d" % _relic_ids.size()
	_entry_button.tooltip_text = "点击或按 R 查看全部遗物"
	for child in _icon_row.get_children():
		child.queue_free()
	var data_repo = AppRefs.data_repo()
	var visible_count := mini(MAX_VISIBLE_RELICS, _relic_ids.size())
	for index in range(visible_count):
		var buff_id := _relic_ids[index]
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		var icon = RELIC_ICON_SCENE.instantiate()
		icon.configure(buff_id, cfg, _has_received_relics and not _last_relic_ids.has(buff_id))
		icon.pressed.connect(func(id: StringName) -> void:
			relic_pressed.emit(id)
			panel_requested.emit()
		)
		_icon_row.add_child(icon)
	var overflow := _relic_ids.size() - visible_count
	_overflow_label.visible = overflow > 0
	_overflow_label.text = "+%d" % overflow


func _style_entry_button() -> void:
	_entry_button.custom_minimum_size = Vector2(86.0, 30.0)
	GameUiStyle.center_button_text(_entry_button)
	_entry_button.add_theme_stylebox_override("normal", GameUiStyle.compact_button(false))
	_entry_button.add_theme_stylebox_override("hover", GameUiStyle.compact_button(true))
	_entry_button.add_theme_stylebox_override("pressed", GameUiStyle.compact_button(true))
	_entry_button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_entry_button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
