extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const RELIC_CARD_SCENE := preload("res://scenes/ui/relic/RelicCard.tscn")

@onready var _choice_list: VBoxContainer = %ChoiceList


var _last_sources_frame := -1


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		# 优先用带来源的信号；旧的纯 id 信号作为兼容兜底（同帧已渲染则跳过）。
		event_bus.blessing_choices_with_sources_ready.connect(show_choices_with_sources)
		event_bus.blessing_choices_ready.connect(show_choices)
	hide_panel()


## 渲染三选一（带槽位来源）。entries: Array[{buff_id, slot}]。
func show_choices_with_sources(entries: Array) -> void:
	_last_sources_frame = Engine.get_process_frames()
	visible = true
	_clear_choices()
	var data_repo = AppRefs.data_repo()
	for raw_entry: Variant in entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		var buff_id := StringName(entry.get("buff_id", ""))
		if buff_id == StringName():
			continue
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		var card = RELIC_CARD_SCENE.instantiate()
		card.configure(buff_id, cfg, {
			"selectable": true,
			"choice_mode": true,
			"slot_source": StringName(entry.get("slot", "")),
		})
		card.set_meta("audio_cue", &"blessing_chosen")
		card.pressed.connect(_on_choice_pressed)
		_choice_list.add_child(card)


func show_choices(choice_ids: Array[StringName]) -> void:
	# 同帧已由带来源信号渲染过则跳过，避免重复。
	if Engine.get_process_frames() == _last_sources_frame:
		return
	visible = true
	_clear_choices()
	var data_repo = AppRefs.data_repo()
	for buff_id in choice_ids:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		var card = RELIC_CARD_SCENE.instantiate()
		card.configure(buff_id, cfg, {
			"selectable": true,
			"choice_mode": true
		})
		card.set_meta("audio_cue", &"blessing_chosen")
		card.pressed.connect(_on_choice_pressed)
		_choice_list.add_child(card)


func hide_panel() -> void:
	visible = false


func _apply_visual_style() -> void:
	add_theme_stylebox_override("panel", GameUiStyle.blessing_panel())
	GameUiStyle.apply_frame_margin(get_node_or_null("ContentMargin") as MarginContainer, GameUiStyle.FRAME_BLESSING_PANEL)
	var title := get_node_or_null("ContentMargin/VBoxContainer/TitleLabel") as Label
	if title != null:
		title.add_theme_color_override("font_color", GameUiStyle.TEXT)
		title.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		title.add_theme_font_size_override("font_size", 22)
		GameUiStyle.center_label_text(title)

func _on_choice_pressed(buff_id: StringName) -> void:
	if buff_id == StringName():
		return
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.blessing_chosen.emit(buff_id)
	hide_panel()


func _clear_choices() -> void:
	for child in _choice_list.get_children():
		child.queue_free()
