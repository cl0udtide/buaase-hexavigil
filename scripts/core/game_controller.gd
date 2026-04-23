extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")


@onready var _day_manager: Node = get_node_or_null("../DayManager")
@onready var _night_manager: Node = get_node_or_null("../NightManager")
@onready var _shop_manager: Node = get_node_or_null("../ShopManager")
@onready var _building_manager: Node = get_node_or_null("../BuildingManager")
@onready var _map_manager: Node = get_node_or_null("../MapManager")


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_start_night.connect(_on_request_start_night)
		event_bus.night_cleared.connect(_on_night_cleared)
		event_bus.core_destroyed.connect(_on_core_destroyed)
		event_bus.blessing_chosen.connect(_on_blessing_chosen)

	if owner != null and owner.name == "Game":
		call_deferred("_bootstrap_run_if_needed")


func start_new_run(seed: int = -1) -> void:
	var actual_seed := seed if seed >= 0 else int(Time.get_unix_time_from_system())
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	if data_repo != null:
		data_repo.load_all()
	if run_state != null:
		run_state.reset_for_new_run(actual_seed)
	if _map_manager != null and _map_manager.has_method("generate_new_map"):
		_map_manager.generate_new_map(actual_seed)
	enter_day(1)


func enter_day(day: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	run_state.set_day(day)
	run_state.set_phase(GameEnums.PHASE_DAY)
	run_state.reset_action_points(run_state.DEFAULT_ACTION_POINTS)
	if _day_manager != null and _day_manager.has_method("start_day"):
		_day_manager.start_day(day)
	if _shop_manager != null and _shop_manager.has_method("start_new_day_shop"):
		_shop_manager.start_new_day_shop(day)
	if _building_manager != null and _building_manager.has_method("refresh_daytime_repair"):
		_building_manager.refresh_daytime_repair()
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.day_started.emit(day)


func enter_night() -> void:
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if run_state == null:
		return
	run_state.set_phase(GameEnums.PHASE_NIGHT)
	if _night_manager != null and _night_manager.has_method("start_night"):
		_night_manager.start_night(run_state.day)
	if event_bus != null:
		event_bus.night_started.emit(run_state.day)


func enter_blessing() -> void:
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if run_state == null:
		return
	run_state.set_phase(GameEnums.PHASE_BLESSING)
	var buff_manager := get_node_or_null("../BuffManager")
	if buff_manager != null and buff_manager.has_method("get_random_blessing_choices") and event_bus != null:
		var choices: Array[StringName] = buff_manager.get_random_blessing_choices()
		event_bus.blessing_choices_ready.emit(choices)


func end_run(win: bool) -> void:
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if run_state != null:
		run_state.set_phase(GameEnums.PHASE_RESULT)
	if event_bus != null:
		event_bus.run_ended.emit(win)


func get_current_phase() -> int:
	var run_state = AppRefs.run_state()
	return run_state.phase if run_state != null else GameEnums.PHASE_MENU


func _bootstrap_run_if_needed() -> void:
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.day <= 0:
		start_new_run()


func _on_request_start_night() -> void:
	if _day_manager == null or not _day_manager.has_method("request_start_night"):
		enter_night()
		return
	var result: Dictionary = _day_manager.request_start_night()
	if result.get("ok", false):
		enter_night()


func _on_night_cleared(_day: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.day >= 3:
		end_run(true)
	else:
		enter_blessing()


func _on_core_destroyed() -> void:
	end_run(false)


func _on_blessing_chosen(buff_id: StringName) -> void:
	var run_state = AppRefs.run_state()
	var buff_manager := get_node_or_null("../BuffManager")
	if buff_manager != null and buff_manager.has_method("apply_blessing"):
		buff_manager.apply_blessing(buff_id)
	if run_state != null:
		enter_day(run_state.day + 1)
