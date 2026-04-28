extends Control

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const SCRIPT_PATH := "res://data/debug/dialog_sandbox_script.json"
const FAST_TYPE_SPEED := 220.0

var _script_data: Dictionary = {}
var _fast_text := false

@onready var _dialog_panel: Control = %DialogPanel
@onready var _debug_bar: PanelContainer = %DebugBar
@onready var _status_label: Label = %StatusLabel
@onready var _replay_button: Button = %ReplayButton
@onready var _next_button: Button = %NextButton
@onready var _skip_button: Button = %SkipButton
@onready var _speed_button: Button = %SpeedButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AppTheme.apply(self)
	_style_debug_bar()
	_bind_buttons()
	_bind_dialog_signals()
	_script_data = _load_script_data()
	_play_from_start()


func _bind_buttons() -> void:
	_replay_button.pressed.connect(_play_from_start)
	_next_button.pressed.connect(func() -> void: _dialog_panel.advance())
	_skip_button.pressed.connect(func() -> void: _dialog_panel.skip())
	_speed_button.pressed.connect(_toggle_fast_text)


func _bind_dialog_signals() -> void:
	_dialog_panel.dialog_started.connect(func() -> void: _status_label.text = "播放中")
	_dialog_panel.line_started.connect(_on_line_started)
	_dialog_panel.line_finished.connect(_on_line_finished)
	_dialog_panel.dialog_finished.connect(func() -> void: _status_label.text = "播放结束")


func _play_from_start() -> void:
	if _script_data.is_empty():
		_status_label.text = "剧情脚本加载失败"
		return
	var data := _script_data.duplicate(true)
	var settings: Dictionary = data.get("settings", {}).duplicate(true)
	if _fast_text:
		settings["type_speed"] = FAST_TYPE_SPEED
	data["settings"] = settings
	_speed_button.text = "快速文本：开" if _fast_text else "快速文本：关"
	_dialog_panel.play_script(data)


func _toggle_fast_text() -> void:
	_fast_text = not _fast_text
	_play_from_start()


func _on_line_started(index: int) -> void:
	var lines: Array = _script_data.get("lines", [])
	var total := lines.size()
	_status_label.text = "第 %d / %d 句" % [index + 1, total]


func _on_line_finished(index: int) -> void:
	var lines: Array = _script_data.get("lines", [])
	var total := lines.size()
	_status_label.text = "第 %d / %d 句已显示完" % [index + 1, total]


func _load_script_data() -> Dictionary:
	if not FileAccess.file_exists(SCRIPT_PATH):
		push_warning("Dialog sandbox script is missing: %s" % SCRIPT_PATH)
		return {}
	var file := FileAccess.open(SCRIPT_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Dialog sandbox script is not a dictionary: %s" % SCRIPT_PATH)
		return {}
	return (parsed as Dictionary).duplicate(true)


func _style_debug_bar() -> void:
	_debug_bar.add_theme_stylebox_override("panel", GameUiStyle.panel(GameUiStyle.BG_GLASS, GameUiStyle.STROKE_SOFT, 1.0, 6.0))
	_status_label.add_theme_color_override("font_color", GameUiStyle.TEXT_DIM)
	for button in [_replay_button, _next_button, _skip_button, _speed_button]:
		_style_button(button)


func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", GameUiStyle.button(GameUiStyle.STROKE))
	button.add_theme_stylebox_override("hover", GameUiStyle.button(GameUiStyle.ACCENT))
	button.add_theme_stylebox_override("pressed", GameUiStyle.button(GameUiStyle.AMBER))
	button.add_theme_color_override("font_color", GameUiStyle.TEXT)
