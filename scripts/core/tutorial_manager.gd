extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const OUTLINE_ID := &"tutorial_focus"
const STEP_INTRO := &"intro"
const STEP_CORE := &"core"
const STEP_EXPLORE := &"explore"
const STEP_COLLECT := &"collect"
const STEP_BUILD := &"build"
const STEP_SHOP := &"shop"
const STEP_WAVE := &"wave"
const STEP_NIGHT := &"night"
const STEP_DEPLOY := &"deploy"
const STEP_SKILL := &"skill"
const STEP_DEFENSE_CLEAR := &"defense_clear"
const STEP_BLESSING := &"blessing"
const STEP_DONE := &"done"
const STORY_FINISH_START_DELAY := 0.22
const RUN_START_TRIGGER := "run_start"

var _steps: Array[Dictionary] = [
	{"id": STEP_INTRO, "title": "第一天演习", "speaker": "干员 B", "portrait": "unit:ceobe", "body": "说是打响名声……可第一天就被黑潮冲散的话，信标也就没有意义了吧？", "hint": "", "wait": false},
	{"id": STEP_CORE, "title": "核心", "speaker": "干员 A", "portrait": "unit:blaze", "body": "所以现在不能急。master，先确认核心的位置。它正在抽取地脉能量，也是黑潮造物最想摧毁的目标。", "hint": "", "wait": false},
	{"id": STEP_EXPLORE, "title": "探索迷雾", "speaker": "干员 B", "portrait": "unit:ceobe", "body": "白天还能借用核心的力量驱散附近黑潮。先不要走远，点击一个与已探索区域相邻的迷雾格，看看那片区域里藏着什么。", "hint": "", "wait": true},
	{"id": STEP_COLLECT, "title": "采集资源", "speaker": "干员 A", "portrait": "unit:blaze", "body": "运气不错的话，迷雾后面会有木材、石材或魔力矿。点击资源点，在弹窗里选择采集；如果暂时没发现资源，就再探索一格。", "hint": "", "wait": true},
	{"id": STEP_BUILD, "title": "布置建筑", "speaker": "干员 A", "portrait": "unit:blaze", "body": "有了材料，就能修筑防线。资源建筑能让白天收益更稳定，木墙则能引导敌人的路线。现在从左侧拖拽任意建筑到合法格子。", "hint": "", "wait": true},
	{"id": STEP_SHOP, "title": "招募干员", "speaker": "干员 B", "portrait": "unit:ceobe", "body": "核心信标已经发出回应了。有人正在靠近这里，愿意为这道防线出力。master，先在商店中购买任意一名干员。", "hint": "", "wait": true},
	{"id": STEP_DEPLOY, "title": "部署与朝向", "speaker": "干员 A", "portrait": "unit:blaze", "body": "把底部干员卡拖到地图格上，松手确定落点，再向外拖拽选择朝向。注意，狙击和术师只能部署在天然高台或人工高台上。", "hint": "", "wait": true},
	{"id": STEP_WAVE, "title": "查看今晚敌情", "speaker": "干员 A", "portrait": "unit:blaze", "body": "入夜前，看一眼今晚的敌情。敌群、路线和出现方向都会影响布防；木墙改变道路时，路线预览也会立刻变化。", "hint": "", "wait": false},
	{"id": STEP_NIGHT, "title": "进入夜晚", "speaker": "干员 B", "portrait": "unit:ceobe", "body": "太阳快下去了。master，点击左下角的进入黑夜按钮，第一批黑潮造物很快就会来了。", "hint": "", "wait": true},
	{"id": STEP_SKILL, "title": "释放技能", "speaker": "干员 A", "portrait": "unit:blaze", "body": "战斗中，干员会积累技力。选中已部署干员，可以查看他的状态和技能；技力准备好时，尝试释放一次技能。", "hint": "", "wait": true},
	{"id": STEP_DEFENSE_CLEAR, "title": "守住核心", "speaker": "干员 A", "portrait": "unit:blaze", "body": "很好，技能已经接入战线。接下来稳住防守，等这一夜的黑潮被清理完；核心防守成功后，地脉回响会凝成可选择的遗物。", "hint": "", "wait": true},
	{"id": STEP_BLESSING, "title": "选择遗物", "speaker": "干员 B", "portrait": "unit:ceobe", "body": "守住了……核心的波动也稳定下来了。它好像凝出了几份地脉回响，这些遗物会影响接下来的每一天。master，选择任意一件。", "hint": "", "wait": true},
	{"id": STEP_DONE, "title": "教程完成", "speaker": "干员 A", "portrait": "unit:blaze", "body": "第一天的循环已经走完：白天扩张、采集、建造和招募，夜晚部署、迎敌并守住核心。master，正式行动开始吧。", "hint": "", "wait": false}
]

var _active := false
var _pending_start := false
var _step_index := 0
var _explored_once := false
var _collected_once := false
var _built_once := false
var _bought_once := false
var _deployed_once := false
var _skill_cast_once := false
var _blessing_panel_shown_once := false
var _blessing_chosen_once := false

@onready var _overlay = get_node_or_null("../../UI/TutorialOverlay")
@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _map_root: Node = get_node_or_null("../../World/MapRoot")


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.fog_revealed.connect(_on_fog_revealed)
		event_bus.resource_collected.connect(_on_resource_collected)
		event_bus.building_placed.connect(_on_building_placed)
		event_bus.shop_action_result.connect(_on_shop_action_result)
		event_bus.day_started.connect(_on_day_started)
		event_bus.night_started.connect(_on_night_started)
		event_bus.unit_deployed.connect(_on_unit_deployed)
		event_bus.unit_skill_cast.connect(_on_unit_skill_cast)
		event_bus.blessing_panel_shown.connect(_on_blessing_panel_shown)
		event_bus.blessing_chosen.connect(_on_blessing_chosen)
	if _overlay != null:
		_overlay.next_requested.connect(_on_next_requested)
		_overlay.skip_requested.connect(_on_skip_requested)
		_overlay.step_started.connect(_on_step_started)
	var story_director = AppRefs.story_director()
	if story_director != null and story_director.has_signal("story_finished"):
		story_director.story_finished.connect(_on_story_finished)
	call_deferred("_start_if_first_run")


func _start_if_first_run() -> void:
	var run_state = AppRefs.run_state()
	if run_state == null or not _is_tutorial_run(run_state):
		if _overlay != null:
			_overlay.hide_tutorial()
		return
	if int(run_state.day) != 1 or int(run_state.phase) != GameEnums.PHASE_DAY:
		return
	if _active or _step_index > 0:
		return
	var story_director = AppRefs.story_director()
	if story_director != null and story_director.has_method("is_playing") and story_director.is_playing():
		_pending_start = true
		return
	_active = true
	_step_index = 0
	_pending_start = false
	_show_tutorial_sequence()


func _show_tutorial_sequence() -> void:
	if not _active or _overlay == null:
		return
	if _overlay.has_method("show_steps"):
		_overlay.show_steps(_steps)
	else:
		_show_current_step()


func _show_current_step() -> void:
	if not _active:
		return
	var step := _steps[_step_index]
	if _overlay != null:
		_overlay.show_step(_step_index + 1, _steps.size(), String(step.get("title", "")), String(step.get("body", "")), String(step.get("hint", "")), bool(step.get("wait", false)), String(step.get("speaker", "")), String(step.get("portrait", "")))
	_on_step_started(_step_index)


func _advance() -> void:
	if not _active:
		return
	_clear_map_focus()
	_step_index += 1
	if _step_index >= _steps.size():
		_finish()
		return
	_show_current_step()


func _finish() -> void:
	var should_start_standard := _is_current_run_tutorial()
	_active = false
	_pending_start = false
	_clear_map_focus()
	if _overlay != null:
		_overlay.hide_tutorial()
	if should_start_standard:
		_mark_tutorial_completed()
		var story_director = AppRefs.story_director()
		if story_director != null and story_director.has_method("skip_next_trigger"):
			story_director.skip_next_trigger(RUN_START_TRIGGER)
		var scene_router = AppRefs.scene_router()
		if scene_router != null and scene_router.has_method("goto_game"):
			scene_router.call_deferred("goto_game")


func _on_next_requested() -> void:
	if not _active:
		return
	_finish()


func _on_skip_requested() -> void:
	_finish()


func _on_step_started(step_index: int) -> void:
	if not _active:
		return
	if step_index < 0 or step_index >= _steps.size():
		return
	_clear_map_focus()
	_step_index = step_index
	if _overlay != null and _overlay.has_method("set_panel_position"):
		_overlay.set_panel_position(_get_overlay_position(StringName(_steps[_step_index].get("id", ""))), true)
	_update_map_focus(StringName(_steps[_step_index].get("id", "")))
	_try_complete_current_step()


func _on_story_finished(_story_id: StringName) -> void:
	if _pending_start:
		_pending_start = false
		_start_after_story_cleanup()


func _start_after_story_cleanup() -> void:
	if STORY_FINISH_START_DELAY > 0.0 and get_tree() != null:
		await get_tree().create_timer(STORY_FINISH_START_DELAY).timeout
	if not is_inside_tree():
		return
	_start_if_first_run()


func _try_complete_current_step() -> void:
	if not _active:
		return
	var id := StringName(_steps[_step_index].get("id", ""))
	match id:
		STEP_EXPLORE:
			if _explored_once:
				_complete_current_waiting_step()
		STEP_COLLECT:
			if _collected_once:
				_complete_current_waiting_step()
		STEP_BUILD:
			if _built_once:
				_complete_current_waiting_step()
		STEP_SHOP:
			if _bought_once:
				_complete_current_waiting_step()
		STEP_NIGHT:
			var run_state = AppRefs.run_state()
			if run_state != null and int(run_state.phase) == GameEnums.PHASE_NIGHT:
				_complete_current_waiting_step()
		STEP_DEPLOY:
			if _deployed_once:
				_complete_current_waiting_step()
		STEP_SKILL:
			if _skill_cast_once:
				_complete_current_waiting_step()
		STEP_DEFENSE_CLEAR:
			if _blessing_panel_shown_once:
				_complete_current_waiting_step()
		STEP_BLESSING:
			if _blessing_chosen_once:
				_complete_current_waiting_step()


func _complete_current_waiting_step() -> void:
	if _overlay != null and _overlay.has_method("complete_waiting_step"):
		_overlay.complete_waiting_step()
	else:
		_advance()


func _update_map_focus(step_id: StringName) -> void:
	if _map_root == null or not _map_root.has_method("set_range_outline") or _map_manager == null:
		return
	if _should_skip_map_focus(step_id):
		_clear_map_focus()
		return
	var cells := _get_focus_cells(step_id)
	if cells.is_empty():
		_clear_map_focus()
		return
	_map_root.set_range_outline(OUTLINE_ID, cells, {
		"style": &"building",
		"duration": -1.0,
		"width": 3.0,
		"halo_width": 10.0,
		"pulse_amount": 0.32,
		"use_texture": false,
		"color": Color(0.95, 0.65, 0.22, 1.0)
	})


func _clear_map_focus() -> void:
	if _map_root != null and _map_root.has_method("clear_range_outline"):
		_map_root.clear_range_outline(OUTLINE_ID)


func _get_focus_cells(step_id: StringName) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _map_manager == null:
		return cells
	match step_id:
		STEP_CORE:
			cells.append(_map_manager.get_core_cell())
		STEP_EXPLORE:
			cells = _get_explorable_cells()
		STEP_COLLECT:
			cells = _get_discovered_resource_cells()
			if cells.is_empty():
				cells = _get_explorable_cells()
	return cells


func _should_skip_map_focus(step_id: StringName) -> bool:
	return step_id == STEP_BUILD or step_id == STEP_DEPLOY or step_id == STEP_SKILL or step_id == STEP_DEFENSE_CLEAR or step_id == STEP_BLESSING or step_id == STEP_WAVE


func _get_overlay_position(step_id: StringName) -> StringName:
	if step_id == STEP_DEPLOY or step_id == STEP_NIGHT or step_id == STEP_SKILL or step_id == STEP_DEFENSE_CLEAR or step_id == STEP_BLESSING:
		return &"top_center"
	return &"bottom_center"


func _get_explorable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _map_manager.get_all_cells():
		if _map_manager.is_discovered(cell):
			continue
		if _map_manager.has_discovered_neighbor(cell):
			result.append(cell)
		if result.size() >= 12:
			break
	return result


func _get_discovered_resource_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _map_manager.get_all_cells():
		var data: CellData = _map_manager.get_cell_data(cell)
		if data != null and data.discovered and data.resource_type != StringName():
			result.append(cell)
	return result


func _get_buildable_cells_near_core() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var core_cell: Vector2i = _map_manager.get_core_cell()
	for cell in _map_manager.get_all_cells():
		if not _map_manager.is_buildable(cell):
			continue
		if abs(cell.x - core_cell.x) <= 4 and abs(cell.y - core_cell.y) <= 4:
			result.append(cell)
		if result.size() >= 16:
			break
	return result


func _get_walkable_cells_near_core() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var core_cell: Vector2i = _map_manager.get_core_cell()
	for cell in _map_manager.get_all_cells():
		if not _map_manager.is_walkable(cell):
			continue
		if abs(cell.x - core_cell.x) <= 5 and abs(cell.y - core_cell.y) <= 5:
			result.append(cell)
		if result.size() >= 18:
			break
	return result


func _on_fog_revealed(cells: Array[Vector2i]) -> void:
	if not cells.is_empty():
		_explored_once = true
		if _active:
			_update_map_focus(StringName(_steps[_step_index].get("id", "")))
	_try_complete_current_step()


func _on_resource_collected(_cell: Vector2i, _resource_type: StringName, _amount: int) -> void:
	_collected_once = true
	_try_complete_current_step()


func _on_building_placed(_building_runtime_id: int, _building_id: StringName, _cell: Vector2i) -> void:
	_built_once = true
	_try_complete_current_step()


func _on_shop_action_result(action: StringName, result: Dictionary) -> void:
	if action == &"buy" and bool(result.get("ok", false)):
		_bought_once = true
	_try_complete_current_step()


func _on_day_started(day: int) -> void:
	if day == 1:
		call_deferred("_start_if_first_run")


func _on_night_started(_day: int) -> void:
	_try_complete_current_step()


func _on_unit_deployed(_unit_runtime_id: int, _operator_key: StringName, _unit_id: StringName, _cell: Vector2i) -> void:
	_deployed_once = true
	_try_complete_current_step()


func _on_unit_skill_cast(_unit_runtime_id: int, _unit_id: StringName) -> void:
	_skill_cast_once = true
	_try_complete_current_step()


func _on_blessing_panel_shown() -> void:
	_blessing_panel_shown_once = true
	_try_complete_current_step()


func _on_blessing_chosen(_buff_id: StringName) -> void:
	_blessing_chosen_once = true
	_try_complete_current_step()


func _is_current_run_tutorial() -> bool:
	var run_state = AppRefs.run_state()
	return _is_tutorial_run(run_state)


func _is_tutorial_run(run_state: Node) -> bool:
	return run_state != null and run_state.has_method("is_tutorial_run") and run_state.is_tutorial_run()


func _mark_tutorial_completed() -> void:
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.has_method("mark_tutorial_completed"):
		run_state.mark_tutorial_completed()
