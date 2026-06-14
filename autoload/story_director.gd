extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

## 剧情演出控制器（autoload）：订阅游戏钩子，按 trigger 找剧情，
## 暂停游戏 → 令常驻 DialogPanel 播放 → 播完恢复 → 发 story_finished。
## 自带一个高层 CanvasLayer + 常驻 DialogPanel（默认隐藏），跨场景常驻。

signal story_finished(story_id: StringName)

const DIALOG_PANEL_SCENE := "res://scenes/ui/DialogPanel.tscn"
const STORY_LAYER := 100
const CORE_NODE_PATH := "World/CoreRoot/Core"
const BUBBLE_HALF_WIDTH := 290.0   # 气泡近似半宽，用于水平居中
const TOP_FLOAT_Y := 96.0          # 气泡顶部漂浮的 y（避开顶栏；实机微调）

var _panel: Control   # DialogPanel；不写成 class_name 类型以避开无头解析期未注册
var _playing_id := StringName()
var _was_paused := false
var _skip_next_trigger_counts: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.name = "StoryLayer"
	layer.layer = STORY_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var packed := load(DIALOG_PANEL_SCENE) as PackedScene
	if packed != null:
		_panel = packed.instantiate()
		layer.add_child(_panel)
		_panel.dialog_finished.connect(_on_dialog_finished)
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.day_started.connect(_on_day_started)


func _on_day_started(day: int) -> void:
	if day == 1:
		_play_trigger("run_start")


## 公开：手动触发（教程 / 事件 / boss 登场等代码侧调用）。
func request_play_story(story_id: StringName) -> void:
	_play_story(story_id)


func skip_next_trigger(trigger: String) -> void:
	var key := StringName(trigger)
	if key == StringName():
		return
	_skip_next_trigger_counts[key] = int(_skip_next_trigger_counts.get(key, 0)) + 1


func is_playing() -> bool:
	return _playing_id != StringName()


func _play_trigger(trigger: String) -> void:
	if _consume_skip_next_trigger(trigger):
		return
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return
	var ids: Array[StringName] = data_repo.get_story_ids_by_trigger(trigger)
	if ids.is_empty():
		return
	_play_story(ids[0])   # 同触发多段先播第一段（id 确定性排序）


func _consume_skip_next_trigger(trigger: String) -> bool:
	var key := StringName(trigger)
	var remaining := int(_skip_next_trigger_counts.get(key, 0))
	if remaining <= 0:
		return false
	if remaining <= 1:
		_skip_next_trigger_counts.erase(key)
	else:
		_skip_next_trigger_counts[key] = remaining - 1
	return true


func _play_story(story_id: StringName) -> void:
	if _panel == null or is_playing():
		return
	var data_repo = AppRefs.data_repo()
	if data_repo == null:
		return
	var cfg: Dictionary = data_repo.get_story_cfg(story_id)
	if cfg.is_empty():
		return
	_resolve_anchors(cfg)
	_playing_id = story_id
	_was_paused = get_tree().paused
	get_tree().paused = true
	# 延一帧再播：确保场景与镜头已就位，锚点解析准确
	_panel.call_deferred("play_story", cfg)


func _on_dialog_finished() -> void:
	var finished_id := _playing_id
	_playing_id = StringName()
	if not _was_paused:
		get_tree().paused = false
	if finished_id != StringName():
		story_finished.emit(finished_id)


## 把每句 bubble 的 anchor 解析成屏幕坐标写进 position。
## 游戏暂停期间镜头静止，开播时解析一次即可。
func _resolve_anchors(cfg: Dictionary) -> void:
	var lines: Variant = cfg.get("lines", [])
	if typeof(lines) != TYPE_ARRAY:
		return
	for raw_line: Variant in lines:
		if typeof(raw_line) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = raw_line
		if StringName(line.get("skin", "")) != &"bubble":
			continue
		if line.has("position"):
			continue
		var anchor := String(line.get("anchor", ""))
		if anchor.is_empty():
			continue
		var pos := _resolve_anchor(anchor)
		line["position"] = [pos.x, pos.y]


## 气泡定位：当前一律顶部居中漂浮（核心锚定实机观感不佳，已弃用；保留 core 解析函数备后续）。
func _resolve_anchor(_anchor: String) -> Vector2:
	var width := 1920.0
	var viewport := get_viewport()
	if viewport != null:
		width = float(viewport.get_visible_rect().size.x)
	return Vector2(width * 0.5 - BUBBLE_HALF_WIDTH, TOP_FLOAT_Y)


func _find_core_node() -> Node2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null(CORE_NODE_PATH) as Node2D
