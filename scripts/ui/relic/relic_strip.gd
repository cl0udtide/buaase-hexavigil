extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")

const RELIC_ICON_SCENE := preload("res://scenes/ui/relic/RelicIcon.tscn")
const MAX_VISIBLE_RELICS := 14
const RELIC_ICON_WIDTH := 34.0
const RELIC_ICON_GAP := 6.0
const RELIC_ROW_GAP := 8.0
const RELIC_FRAME_HORIZONTAL_PADDING := 26.0
const MIN_STRIP_WIDTH := 126.0
const FALLBACK_MAX_STRIP_WIDTH := 1100.0

signal panel_requested
signal relic_pressed(buff_id: StringName)

var _relic_ids: Array[StringName] = []
var _last_relic_ids: Array[StringName] = []
var _has_received_relics := false
var _last_visible_capacity := -1

@onready var _entry_button: Button = %EntryButton
@onready var _entry_label: Label = %EntryLabel
@onready var _icon_row: HBoxContainer = %IconRow
@onready var _overflow_label: Label = %OverflowLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	_entry_button.pressed.connect(func() -> void: panel_requested.emit())
	var parent_control := get_parent() as Control
	if parent_control != null:
		parent_control.resized.connect(_on_available_width_changed)
	resized.connect(_on_resized)
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
	var entry_width := _entry_button.custom_minimum_size.x if _entry_button != null else 86.0
	var overflow_width := _overflow_label.custom_minimum_size.x if _overflow_label != null else 42.0
	var available_width := maxf(0.0, strip_width - entry_width - RELIC_ROW_GAP - RELIC_FRAME_HORIZONTAL_PADDING)
	var capacity_without_overflow := _icon_capacity_for_width(available_width)
	if relic_count <= capacity_without_overflow:
		return mini(MAX_VISIBLE_RELICS, capacity_without_overflow)
	var capacity_with_overflow := _icon_capacity_for_width(maxf(0.0, available_width - overflow_width - RELIC_ROW_GAP))
	return mini(MAX_VISIBLE_RELICS, capacity_with_overflow)


func _icon_capacity_for_width(width: float) -> int:
	return maxi(1, int(floor((width + RELIC_ICON_GAP) / (RELIC_ICON_WIDTH + RELIC_ICON_GAP))))


func _available_strip_width() -> float:
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0:
		return parent_control.size.x
	if size.x > MIN_STRIP_WIDTH:
		return size.x
	return FALLBACK_MAX_STRIP_WIDTH
