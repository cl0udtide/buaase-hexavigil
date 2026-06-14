extends SceneTree

## 剧情引擎回归：实例化 DialogPanel 场景、播放真实开场剧本、逐句推进到结束。
## 无头无渲染，但跑通状态机：加载/可见/逐句 line_started/立绘解析/背景切换/收尾，不崩溃。
## 用 _initialize + await process_frame：等树 tick 一帧，节点 _ready/@onready 才就绪。

const OPENING_PATH := "res://data/stories/opening_intro.json"
const PANEL_SCENE := "res://scenes/ui/DialogPanel.tscn"

var _failures: int = 0
var _finished := false
var _started := 0
var _lines_seen := 0


func _initialize() -> void:
	_run()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _run() -> void:
	var data := _load_json(OPENING_PATH)
	_expect(not data.is_empty(), "开场剧本加载")
	var packed := load(PANEL_SCENE) as PackedScene
	_expect(packed != null, "DialogPanel 场景加载")
	if packed == null:
		_finish()
		return

	var panel := packed.instantiate()
	root.add_child(panel)
	await process_frame   # 等一帧：_ready 与 @onready 就绪

	_expect(panel.get_node_or_null("Bubble") != null, "_ready 已构建气泡节点")
	_expect(panel.get_node_or_null("BackgroundImage") != null, "_ready 已构建背景图层")
	_expect(panel.has_method("play_story"), "有 play_story 接口")

	panel.dialog_started.connect(func() -> void: _started += 1)
	panel.line_started.connect(func(_i: int) -> void: _lines_seen += 1)
	panel.dialog_finished.connect(func() -> void: _finished = true)

	panel.play_story(data)
	_expect(_started == 1, "dialog_started 触发一次")
	_expect(panel.visible, "播放后可见")

	# 手动 advance 驱动状态机（每句两次：收尾打字 + 进下一句）
	var guard := 0
	while not _finished and guard < 300:
		panel.advance()
		guard += 1

	_expect(_finished, "推进到 dialog_finished")
	var total_lines := (data.get("lines", []) as Array).size()
	_expect(_lines_seen == total_lines, "每句都 line_started (%d/%d)" % [_lines_seen, total_lines])

	panel.queue_free()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("DIALOG ENGINE TESTS PASSED")
		quit(0)
	else:
		printerr("DIALOG ENGINE TESTS FAILED: %d" % _failures)
		quit(1)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}
