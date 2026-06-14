class_name StoryLibrary
extends RefCounted

## 剧情数据：加载 / 校验 / 立绘路径解析。纯静态、确定性，可脱 DataRepo 测试。
## 一段剧情 = data/stories/<id>.json 一个文件，顶层对象：
##   id / trigger / replay(保留字段，本期忽略) / lines[]
## 每句 line：skin(bubble|vn) + text，外加可选 speaker/portrait/side/background/position/anchor/advance/clear。

const SKIN_BUBBLE := &"bubble"
const SKIN_VN := &"vn"
const VALID_SKINS: Array[StringName] = [SKIN_BUBBLE, SKIN_VN]

## portrait key → 游戏内 sprite idle 帧（说话人视觉先用游戏小人，不用专门立绘）。
const UNIT_SPRITE_FMT := "res://assets/sprites/units/%s/idle/%s_idle_000.png"
const ENEMY_SPRITE_FMT := "res://assets/sprites/enemies/%s/idle/%s_idle_000.png"

## VN 全屏插图背景 key → 资源路径。
const BACKGROUND_DIR := "res://assets/story/backgrounds/"


## 扫目录下全部 *.json，按 id 索引成 {id: cfg}。非法/无 id 的文件跳过，不阻断其余。
static func load_dir(dir_path: String) -> Dictionary:
	var stories: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return stories
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var cfg := _load_file(dir_path.path_join(file_name))
			var story_id := StringName(cfg.get("id", ""))
			if story_id != StringName():
				stories[story_id] = cfg
		file_name = dir.get_next()
	dir.list_dir_end()
	return stories


static func _load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("剧情文件不是对象: %s" % path)
		return {}
	return parsed as Dictionary


## 返回错误列表（空 = 通过）。加载期与测试期共用，保证剧本字段完整。
static func validate_story(cfg: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if StringName(cfg.get("id", "")) == StringName():
		errors.append("缺少 id")
	if String(cfg.get("trigger", "")).strip_edges().is_empty():
		errors.append("缺少 trigger")
	var raw_lines: Variant = cfg.get("lines", [])
	if typeof(raw_lines) != TYPE_ARRAY or (raw_lines as Array).is_empty():
		errors.append("lines 为空")
		return errors
	var idx := 0
	for raw_line: Variant in raw_lines:
		if typeof(raw_line) != TYPE_DICTIONARY:
			errors.append("第 %d 句不是对象" % idx)
			idx += 1
			continue
		var line: Dictionary = raw_line
		var skin := StringName(line.get("skin", ""))
		if not VALID_SKINS.has(skin):
			errors.append("第 %d 句 skin 非法(%s)" % [idx, String(skin)])
		var has_text := not String(line.get("text", "")).is_empty()
		var has_clear := line.has("clear")
		if not has_text and not has_clear:
			errors.append("第 %d 句既无 text 也无 clear" % idx)
		idx += 1
	return errors


## 句子 portrait key → sprite 资源路径。unit:<id> / enemy:<id>；
## 其他（专门角色 key）暂返回空字符串，留给 portrait_override 或后续映射表。
static func resolve_portrait_path(portrait_key: StringName) -> String:
	var key := String(portrait_key)
	if key.begins_with("unit:"):
		var unit_id := key.substr(5)
		return UNIT_SPRITE_FMT % [unit_id, unit_id]
	if key.begins_with("enemy:"):
		var enemy_id := key.substr(6)
		return ENEMY_SPRITE_FMT % [enemy_id, enemy_id]
	return ""


## 全屏插图 background key → 资源路径（不存在返回空，调用方回退纯色）。
static func resolve_background_path(key: String) -> String:
	if key.is_empty():
		return ""
	var path := BACKGROUND_DIR + key + ".png"
	return path if ResourceLoader.exists(path) else ""


## 取某触发对应的全部剧情 id（确定性排序）。供 StoryDirector 建 trigger→story 映射。
static func ids_by_trigger(stories: Dictionary, trigger: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	for raw_id in stories.keys():
		var cfg: Dictionary = stories[raw_id]
		if String(cfg.get("trigger", "")) == trigger:
			ids.append(StringName(raw_id))
	ids.sort()
	return ids
