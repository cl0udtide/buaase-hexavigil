extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const RELIC_ICON_SCENE := preload("res://scenes/ui/relic/RelicIcon.tscn")
const MAX_VISIBLE_RELICS := 14
const FALLBACK_MAX_STRIP_WIDTH := 1100.0

signal panel_requested
signal relic_pressed(buff_id: StringName)

var _relic_ids: Array[StringName] = []
var _last_relic_ids: Array[StringName] = []
var _has_received_relics := false
var _last_visible_capacity := -1
var _scene_custom_minimum_size := Vector2.ZERO
var _relic_icon_width := 0.0

@onready var _strip_base: Panel = %StripBase
@onready var _strip_margin: MarginContainer = $StripMargin
@onready var _row: HBoxContainer = $StripMargin/Row
@onready var _entry_button: Button = %EntryButton
@onready var _entry_label: Label = %EntryLabel
@onready var _icon_row: HBoxContainer = %IconRow
@onready var _overflow_label: Label = %OverflowLabel


func _ready() -> void:
	_scene_custom_minimum_size = custom_minimum_size
	_relic_icon_width = _read_relic_icon_width()
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	_entry_button.pressed.connect(func() -> void: panel_requested.emit())
	var parent_control := get_parent() as Control
	if parent_control != null:
		parent_control.resized.connect(_on_available_width_changed)
	_icon_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_overflow_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	resized.connect(_on_resized)
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
	_entry_label.text = "遗物 %d" % _relic_ids.size()
	for child in _icon_row.get_children():
		child.queue_free()
	var data_repo = AppRefs.data_repo()
	var visible_capacity := _visible_relic_capacity(_relic_ids.size())
	_last_visible_capacity = visible_capacity
	var visible_count := mini(visible_capacity, _relic_ids.size())
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
	_icon_row.visible = visible_count > 0
	_apply_content_width(visible_count, overflow > 0)


func _on_resized() -> void:
	if not is_node_ready():
		return
	var next_capacity := _visible_relic_capacity(_relic_ids.size())
	if next_capacity != _last_visible_capacity:
		_refresh()


func _on_available_width_changed() -> void:
	if is_node_ready():
		_refresh()


func _visible_relic_capacity(relic_count: int) -> int:
	var strip_width := _available_strip_width()
	var entry_width := _entry_button_minimum_width()
	var overflow_width := _overflow_label_minimum_width()
	var row_gap := _row_separation()
	var available_width := maxf(0.0, strip_width - entry_width - row_gap - _horizontal_margins())
	var capacity_without_overflow := _icon_capacity_for_width(available_width)
	if relic_count <= capacity_without_overflow:
		return mini(MAX_VISIBLE_RELICS, capacity_without_overflow)
	var capacity_with_overflow := _icon_capacity_for_width(maxf(0.0, available_width - overflow_width - row_gap))
	return mini(MAX_VISIBLE_RELICS, capacity_with_overflow)


func _icon_capacity_for_width(width: float) -> int:
	var icon_gap := _icon_separation()
	return maxi(1, int(floor((width + icon_gap) / (_relic_icon_width + icon_gap))))


func _apply_content_width(visible_count: int, has_overflow: bool) -> void:
	var width := _target_strip_width(visible_count, has_overflow)
	custom_minimum_size = Vector2(width, _scene_custom_minimum_size.y)


func _target_strip_width(visible_count: int, has_overflow: bool) -> float:
	var row_gap := _row_separation()
	var icon_gap := _icon_separation()
	var width := _horizontal_margins() + _entry_button_minimum_width()
	if visible_count > 0:
		width += row_gap
		width += float(visible_count) * _relic_icon_width
		width += float(maxi(0, visible_count - 1)) * icon_gap
	if has_overflow:
		width += row_gap + _overflow_label_minimum_width()
	return clampf(ceilf(width), _scene_custom_minimum_size.x, _available_strip_width())


func _read_relic_icon_width() -> float:
	var icon := RELIC_ICON_SCENE.instantiate() as Control
	if icon == null:
		return 0.0
	var icon_width := icon.custom_minimum_size.x
	icon.free()
	return icon_width


func _entry_button_minimum_width() -> float:
	if _entry_button == null:
		return 0.0
	return maxf(_entry_button.custom_minimum_size.x, _entry_button.get_combined_minimum_size().x)


func _overflow_label_minimum_width() -> float:
	if _overflow_label == null:
		return 0.0
	return maxf(_overflow_label.custom_minimum_size.x, _overflow_label.get_combined_minimum_size().x)


func _horizontal_margins() -> float:
	if _strip_margin == null:
		return 0.0
	return float(_strip_margin.get_theme_constant("margin_left")) + float(_strip_margin.get_theme_constant("margin_right"))


func _row_separation() -> float:
	if _row == null:
		return 0.0
	return float(_row.get_theme_constant("separation"))


func _icon_separation() -> float:
	if _icon_row == null:
		return 0.0
	return float(_icon_row.get_theme_constant("separation"))


func _available_strip_width() -> float:
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0:
		return parent_control.size.x
	if size.x > _scene_custom_minimum_size.x:
		return size.x
	return FALLBACK_MAX_STRIP_WIDTH
