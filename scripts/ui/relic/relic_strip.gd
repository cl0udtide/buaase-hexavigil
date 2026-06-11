extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")
const UiArtRegistry = preload("res://scripts/ui/ui_art_registry.gd")

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

@onready var _strip_base: Panel = %StripBase
@onready var _entry_button: Button = %EntryButton
@onready var _icon_row: HBoxContainer = %IconRow
@onready var _overflow_label: Label = %OverflowLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AppTheme.apply(self)
	_entry_button.pressed.connect(func() -> void: panel_requested.emit())
	_style_entry_button()
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
	_entry_button.text = "遗物" if _relic_ids.is_empty() else "遗物 %d" % _relic_ids.size()
	GameUiStyle.set_button_texture_icon(_entry_button, UiArtRegistry.get_catalog_icon(&"relic_bag"), &"left", 7.0)
	_entry_button.tooltip_text = "点击或按 R 查看全部遗物"
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
	# 空态幽灵化但保留 R 键/点击入口,禁用 visible=false(防"该显示的被藏"回归)
	modulate.a = 0.35 if _relic_ids.is_empty() else 1.0


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


func _apply_content_width(visible_count: int, has_overflow: bool) -> void:
	var width := _target_strip_width(visible_count, has_overflow)
	var height := maxf(size.y, 40.0)
	set_custom_minimum_size(Vector2(width, 40.0))
	set_size(Vector2(width, height))


func _target_strip_width(visible_count: int, has_overflow: bool) -> float:
	var entry_width := _entry_button.custom_minimum_size.x if _entry_button != null else 86.0
	var overflow_width := _overflow_label.custom_minimum_size.x if _overflow_label != null else 42.0
	var width := RELIC_FRAME_HORIZONTAL_PADDING + entry_width
	if visible_count > 0:
		width += RELIC_ROW_GAP
		width += float(visible_count) * RELIC_ICON_WIDTH
		width += float(maxi(0, visible_count - 1)) * RELIC_ICON_GAP
	if has_overflow:
		width += RELIC_ROW_GAP + overflow_width
	return clampf(ceilf(width), MIN_STRIP_WIDTH, _available_strip_width())


func _available_strip_width() -> float:
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0:
		return parent_control.size.x
	if size.x > MIN_STRIP_WIDTH:
		return size.x
	return FALLBACK_MAX_STRIP_WIDTH


func _style_entry_button() -> void:
	_entry_button.set_custom_minimum_size(Vector2(86.0, 30.0))
	_entry_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	GameUiStyle.center_button_text(_entry_button)
	_entry_button.add_theme_stylebox_override("normal", GameUiStyle.flat_chip())
	_entry_button.add_theme_stylebox_override("hover", GameUiStyle.compact_button(true))
	_entry_button.add_theme_stylebox_override("pressed", GameUiStyle.compact_button(true))
	_entry_button.add_theme_color_override("font_color", GameUiStyle.TEXT)
	_entry_button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT_INVERTED)
