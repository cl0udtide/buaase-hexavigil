extends SceneTree

## 剧情数据层回归：StoryLibrary 加载/校验/触发查询/立绘路径解析 + 真实剧本目录可用。

const StoryLibrary = preload("res://scripts/story/story_library.gd")

const STORIES_DIR := "res://data/stories"

var _failures: int = 0


func _init() -> void:
	_test_load_and_validate()
	_test_trigger_query()
	_test_portrait_resolve()
	_test_invalid_rejected()
	if _failures == 0:
		print("STORY DATA TESTS PASSED")
		quit(0)
	else:
		printerr("STORY DATA TESTS FAILED: %d" % _failures)
		quit(1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _test_load_and_validate() -> void:
	var stories := StoryLibrary.load_dir(STORIES_DIR)
	_expect(not stories.is_empty(), "stories 目录非空")
	_expect(stories.has(&"opening_intro"), "opening_intro 已加载")
	for story_id in stories.keys():
		var errs := StoryLibrary.validate_story(stories[story_id])
		_expect(errs.is_empty(), "%s 校验通过: %s" % [String(story_id), ", ".join(errs)])


func _test_trigger_query() -> void:
	var stories := StoryLibrary.load_dir(STORIES_DIR)
	var run_start := StoryLibrary.ids_by_trigger(stories, "run_start")
	_expect(run_start.has(&"opening_intro"), "run_start 命中 opening_intro")
	_expect(StoryLibrary.ids_by_trigger(stories, "no_such_trigger").is_empty(), "未知触发返回空")


func _test_portrait_resolve() -> void:
	var unit_path := StoryLibrary.resolve_portrait_path(&"unit:blaze")
	_expect(unit_path == "res://assets/sprites/units/blaze/idle/blaze_idle_000.png", "unit 立绘路径解析")
	_expect(ResourceLoader.exists(unit_path), "blaze 立绘资源存在")
	var enemy_path := StoryLibrary.resolve_portrait_path(&"enemy:coucou_penguin")
	_expect(enemy_path == "res://assets/sprites/enemies/coucou_penguin/idle/coucou_penguin_idle_000.png", "enemy 立绘路径解析")
	_expect(ResourceLoader.exists(enemy_path), "凑凑企鹅立绘资源存在")
	_expect(StoryLibrary.resolve_portrait_path(&"") == "", "空 key 返回空")


func _test_invalid_rejected() -> void:
	var bad_skin := {"id": "bad", "trigger": "x", "lines": [{"skin": "nope", "text": "hi"}]}
	_expect(not StoryLibrary.validate_story(bad_skin).is_empty(), "非法 skin 被拒")
	var no_lines := {"id": "bad2", "trigger": "x", "lines": []}
	_expect(not StoryLibrary.validate_story(no_lines).is_empty(), "空 lines 被拒")
	var no_id := {"trigger": "x", "lines": [{"skin": "vn", "text": "hi"}]}
	_expect(not StoryLibrary.validate_story(no_id).is_empty(), "缺 id 被拒")
