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
const STEP_BLESSING := &"blessing"
const STEP_DONE := &"done"

var _steps: Array[Dictionary] = [
	{"id": STEP_INTRO, "title": "第一天演习", "body": "白天探索、采集、建造和招募；夜晚部署干员抵御敌人。教程关卡会陪你完成第一天的关键操作。", "hint": "点击下一步开始；点击跳过会直接开始正式第一天。", "wait": false},
	{"id": STEP_CORE, "title": "核心", "body": "地图中央是核心。敌人会从地图边缘出现，并沿路线尝试抵达核心。核心生命归零时本局失败。", "hint": "观察核心位置，然后继续。", "wait": false},
	{"id": STEP_EXPLORE, "title": "探索迷雾", "body": "白天点击相邻已探索区域的迷雾格，可以消耗行动力揭开新区域。", "hint": "点击核心周围的未探索格完成一次探索。", "wait": true},
	{"id": STEP_COLLECT, "title": "采集资源", "body": "探索后可能发现资源点。已探索的资源点每天可以手动采集一次，材料会用于建造。", "hint": "点击一个已探索资源点，在弹窗里选择采集；如果还没看到资源，可以先继续探索。", "wait": true},
	{"id": STEP_BUILD, "title": "布置建筑", "body": "左侧建筑卡可以拖到地图上建造。资源建筑提供白天收益，木墙会影响敌人的路线。", "hint": "从左侧拖拽任意可建造建筑到合法格子并释放。", "wait": true},
	{"id": STEP_SHOP, "title": "招募干员", "body": "商店会消耗声望购买干员槽位。每个槽位都能独立部署、撤退和再部署。", "hint": "在商店中购买任意一个干员。", "wait": true},
	{"id": STEP_DEPLOY, "title": "部署与朝向", "body": "白天也可以先布置干员。把底部干员卡拖到地图格，松手锁定落点，再从落点向外拖拽选择攻击朝向。", "hint": "在进入夜晚前，成功部署任意一名干员。", "wait": true},
	{"id": STEP_WAVE, "title": "查看今晚敌情", "body": "白天的作战 HUD 会显示今晚敌群和路线。建造阻挡建筑时，路线预览能帮你判断防线是否合理。", "hint": "确认敌情后继续。", "wait": false},
	{"id": STEP_NIGHT, "title": "进入夜晚", "body": "准备完成后进入夜晚。夜晚中敌人会按波次出现，时间控制也会开启。", "hint": "点击左下角进入黑夜按钮。", "wait": true},
	{"id": STEP_SKILL, "title": "释放技能", "body": "选中已部署干员后可以查看详情。技力准备好时，释放技能能显著改变战局。", "hint": "选中一名干员并释放一次技能。", "wait": true},
	{"id": STEP_BLESSING, "title": "选择遗物", "body": "守住夜晚后会获得遗物选择。正式局中，遗物会强化资源、建筑或干员，推动后续构筑。", "hint": "选择任意一件遗物。", "wait": true},
	{"id": STEP_DONE, "title": "教程完成", "body": "你已经走完第一天的完整循环。接下来会从新的正式局开始，把防线撑到第六夜。", "hint": "点击完成开始正式游玩。", "wait": false}
]

var _active := false
var _step_index := 0
var _explored_once := false
var _collected_once := false
var _built_once := false
var _bought_once := false
var _deployed_once := false
var _skill_cast_once := false
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
		event_bus.blessing_chosen.connect(_on_blessing_chosen)
	if _overlay != null:
		_overlay.next_requested.connect(_on_next_requested)
		_overlay.skip_requested.connect(_on_skip_requested)
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
	_active = true
	_step_index = 0
	_show_current_step()


func _show_current_step() -> void:
	if not _active or _overlay == null:
		return
	var step := _steps[_step_index]
	_overlay.show_step(_step_index + 1, _steps.size(), String(step.get("title", "")), String(step.get("body", "")), String(step.get("hint", "")), bool(step.get("wait", false)))
	if _overlay.has_method("set_panel_position"):
		_overlay.set_panel_position(_get_overlay_position(StringName(step.get("id", ""))))
	_update_map_focus(StringName(step.get("id", "")))
	_try_complete_current_step()


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
	_clear_map_focus()
	if _overlay != null:
		_overlay.hide_tutorial()
	if should_start_standard:
		_mark_tutorial_completed()
		var scene_router = AppRefs.scene_router()
		if scene_router != null and scene_router.has_method("goto_game"):
			scene_router.call_deferred("goto_game")


func _on_next_requested() -> void:
	if not _active:
		return
	var step := _steps[_step_index]
	if StringName(step.get("id", "")) == STEP_DONE:
		_finish()
	else:
		_advance()


func _on_skip_requested() -> void:
	_finish()


func _try_complete_current_step() -> void:
	if not _active:
		return
	var id := StringName(_steps[_step_index].get("id", ""))
	match id:
		STEP_EXPLORE:
			if _explored_once:
				_advance()
		STEP_COLLECT:
			if _collected_once:
				_advance()
		STEP_BUILD:
			if _built_once:
				_advance()
		STEP_SHOP:
			if _bought_once:
				_advance()
		STEP_NIGHT:
			var run_state = AppRefs.run_state()
			if run_state != null and int(run_state.phase) == GameEnums.PHASE_NIGHT:
				_advance()
		STEP_DEPLOY:
			if _deployed_once:
				_advance()
		STEP_SKILL:
			if _skill_cast_once:
				_advance()
		STEP_BLESSING:
			if _blessing_chosen_once:
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
	return step_id == STEP_BUILD or step_id == STEP_DEPLOY or step_id == STEP_SKILL or step_id == STEP_BLESSING or step_id == STEP_WAVE


func _get_overlay_position(_step_id: StringName) -> StringName:
	# top_right 会整列压住右侧栏敌情预告,统一走地图上方留白区
	return &"top_center"


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
		_start_if_first_run()


func _on_night_started(_day: int) -> void:
	_try_complete_current_step()


func _on_unit_deployed(_unit_runtime_id: int, _operator_key: StringName, _unit_id: StringName, _cell: Vector2i) -> void:
	_deployed_once = true
	_try_complete_current_step()


func _on_unit_skill_cast(_unit_runtime_id: int, _unit_id: StringName) -> void:
	_skill_cast_once = true
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
