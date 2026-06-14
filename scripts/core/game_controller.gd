extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")
const NightAffixService = preload("res://scripts/enemy/night_affix_service.gd")
const NightTemplateResolver = preload("res://scripts/enemy/night_template_resolver.gd")

const CORE_DESTROYED_RESULT_DELAY := 2.0
const DEFEAT_RESULT_HIT_DELAY := 1.656
const VICTORY_RESULT_HIT_DELAY := 1.35
const NIGHT_START_TRANSITION_DELAY := 5.25
const RUN_END_AUDIO_DELAY := 1.9


@onready var _day_manager: Node = get_node_or_null("../DayManager")
@onready var _night_manager: Node = get_node_or_null("../NightManager")
@onready var _shop_manager: Node = get_node_or_null("../ShopManager")
@onready var _building_manager: Node = get_node_or_null("../BuildingManager")
@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _unit_manager: Node = get_node_or_null("../UnitManager")
@onready var _wave_manager: Node = get_node_or_null("../WaveManager")

var _run_end_requested := false
var _night_start_transitioning := false


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.request_start_night.connect(_on_request_start_night)
		event_bus.night_cleared.connect(_on_night_cleared)
		event_bus.core_destroyed.connect(_on_core_destroyed)
		event_bus.blessing_chosen.connect(_on_blessing_chosen)
		event_bus.core_damaged.connect(_on_core_damaged_for_wager)

	if owner != null and owner.name == "Game":
		call_deferred("_bootstrap_run_if_needed")


func start_new_run(seed: int = -1, run_mode: StringName = &"standard") -> void:
	var actual_seed := seed if seed >= 0 else int(Time.get_unix_time_from_system())
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	if data_repo == null or (data_repo.has_method("is_loaded") and not data_repo.is_loaded()):
		push_error("DataRepo must be loaded before starting a run.")
		return
	if run_state != null:
		run_state.reset_for_new_run(actual_seed, run_mode)
	if _map_manager != null and _map_manager.has_method("generate_new_map"):
		_map_manager.generate_new_map(actual_seed)
	enter_day(1)


func enter_day(day: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	_night_start_transitioning = false
	run_state.set_day(day)
	run_state.set_phase(GameEnums.PHASE_DAY)
	run_state.night_wager_active = false
	run_state.night_core_damaged = false
	if run_state.has_method("clear_night_gate_overrides"):
		run_state.clear_night_gate_overrides()
	_resolve_night_template_for_day(run_state, day)
	_resolve_night_affixes_for_day(run_state, day)
	run_state.reset_action_points(run_state.DEFAULT_ACTION_POINTS)
	if _day_manager != null and _day_manager.has_method("start_day"):
		_day_manager.start_day(day)
	if _shop_manager != null and _shop_manager.has_method("start_new_day_shop"):
		_shop_manager.start_new_day_shop(day)
	if _building_manager != null and _building_manager.has_method("refresh_daytime_repair"):
		_building_manager.refresh_daytime_repair()
	if _unit_manager != null and _unit_manager.has_method("prepare_for_day"):
		_unit_manager.prepare_for_day()
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.day_started.emit(day)


func enter_night() -> void:
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if run_state == null or _night_start_transitioning:
		return
	_night_start_transitioning = true
	run_state.set_phase(GameEnums.PHASE_NIGHT)
	if _unit_manager != null and _unit_manager.has_method("refresh_predeployed_units_for_night"):
		_unit_manager.refresh_predeployed_units_for_night()
	if event_bus != null:
		event_bus.night_started.emit(run_state.day)
	if NIGHT_START_TRANSITION_DELAY > 0.0 and get_tree() != null:
		await get_tree().create_timer(NIGHT_START_TRANSITION_DELAY).timeout
	if not is_inside_tree():
		return
	if run_state == null or run_state.phase != GameEnums.PHASE_NIGHT:
		_night_start_transitioning = false
		return
	_night_start_transitioning = false
	if _night_manager != null and _night_manager.has_method("start_night"):
		_night_manager.start_night(run_state.day)


func enter_blessing() -> void:
	var run_state = AppRefs.run_state()
	var event_bus = AppRefs.event_bus()
	if run_state == null:
		return
	run_state.set_phase(GameEnums.PHASE_BLESSING)
	var buff_manager := get_node_or_null("../BuffManager")
	if buff_manager != null and event_bus != null and buff_manager.has_method("get_random_blessing_choices_with_sources"):
		# 带槽位来源抽取；同步发出兼容旧信号（仅 id）与新信号（含来源）。
		var entries: Array[Dictionary] = buff_manager.get_random_blessing_choices_with_sources()
		var choices: Array[StringName] = []
		for entry in entries:
			choices.append(StringName(entry.get("buff_id", "")))
		# 先发带来源信号（UI 优先用它渲染），再发兼容旧信号给纯 id 监听者。
		event_bus.blessing_choices_with_sources_ready.emit(entries)
		event_bus.blessing_choices_ready.emit(choices)
	elif buff_manager != null and buff_manager.has_method("get_random_blessing_choices") and event_bus != null:
		var fallback_choices: Array[StringName] = buff_manager.get_random_blessing_choices()
		event_bus.blessing_choices_ready.emit(fallback_choices)


func end_run(win: bool) -> void:
	if _run_end_requested:
		return
	if win:
		_end_run_after_delay(win, VICTORY_RESULT_HIT_DELAY)
	else:
		_end_run_after_delay(win, RUN_END_AUDIO_DELAY)


func _set_result_phase() -> void:
	var run_state = AppRefs.run_state()
	if run_state != null:
		run_state.set_phase(GameEnums.PHASE_RESULT)


func _emit_run_ended(win: bool) -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.run_ended.emit(win)


func _end_run_after_delay(win: bool, delay_seconds: float) -> void:
	if _run_end_requested:
		return
	_run_end_requested = true
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.run_ending.emit(win, delay_seconds)
	if delay_seconds > 0.0 and get_tree() != null:
		await get_tree().create_timer(delay_seconds).timeout
	if not is_inside_tree():
		return
	_set_result_phase()
	_emit_run_ended(win)


func get_current_phase() -> int:
	var run_state = AppRefs.run_state()
	return run_state.phase if run_state != null else GameEnums.PHASE_MENU


func _resolve_night_template_for_day(run_state: Node, day: int) -> void:
	var empty_plan: Array[StringName] = []
	run_state.night_wave_template_ids = empty_plan
	run_state.night_template_id = StringName()
	if _wave_manager == null or not _wave_manager.has_method("resolve_night_plan"):
		return
	var plan: Array[StringName] = _wave_manager.resolve_night_plan(int(run_state.random_seed), day, run_state.used_template_ids)
	run_state.night_wave_template_ids = plan
	if not plan.is_empty():
		run_state.night_template_id = plan[0]
	for template_id in plan:
		if template_id != StringName() and not run_state.used_template_ids.has(template_id):
			run_state.used_template_ids.append(template_id)


func _resolve_night_affixes_for_day(run_state: Node, day: int) -> void:
	var empty_affixes: Array[StringName] = []
	run_state.night_affix_ids = empty_affixes
	var data_repo = AppRefs.data_repo()
	if data_repo == null or not data_repo.has_method("get_all_night_affix_ids"):
		return
	var affix_cfgs: Array = []
	for affix_id in data_repo.get_all_night_affix_ids():
		affix_cfgs.append(data_repo.get_night_affix_cfg(affix_id))
	run_state.night_affix_ids = NightAffixService.resolve_affixes_for_day(int(run_state.random_seed), day, affix_cfgs)


func _bootstrap_run_if_needed() -> void:
	var run_mode := &"standard"
	var scene_router = AppRefs.scene_router()
	if scene_router != null and scene_router.has_method("consume_pending_run_mode"):
		run_mode = scene_router.consume_pending_run_mode()
	start_new_run(-1, run_mode)


func _on_request_start_night() -> void:
	if _day_manager == null or not _day_manager.has_method("request_start_night"):
		enter_night()
		return
	var result: Dictionary = _day_manager.request_start_night()
	if result.get("ok", false):
		enter_night()


func _on_night_cleared(_day: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state == null:
		return
	if run_state.phase == GameEnums.PHASE_RESULT or run_state.core_hp <= 0:
		return
	if run_state.night_wager_active and not run_state.night_core_damaged:
		run_state.pending_extra_blessings += 1
	run_state.night_wager_active = false
	# 幕末 Boss（d3/d6，非终局）清场 → 下次三选一保底一件高稀有度遗物。
	if NightTemplateResolver.is_boss_night(run_state.day) and run_state.day < NightTemplateResolver.TOTAL_DAYS:
		run_state.pending_milestone_blessing = true
	if run_state.day >= NightTemplateResolver.TOTAL_DAYS:
		end_run(true)
	else:
		enter_blessing()


func _on_core_destroyed() -> void:
	_end_run_after_delay(false, DEFEAT_RESULT_HIT_DELAY)


func _on_blessing_chosen(buff_id: StringName) -> void:
	var run_state = AppRefs.run_state()
	var buff_manager := get_node_or_null("../BuffManager")
	if buff_manager != null and buff_manager.has_method("apply_blessing"):
		buff_manager.apply_blessing(buff_id)
	if run_state == null:
		return
	if _is_tutorial_run(run_state):
		return
	# 战争赌局奖励：先兑现额外的遗物三选一，再进入新的一天。
	if int(run_state.pending_extra_blessings) > 0:
		run_state.pending_extra_blessings -= 1
		enter_blessing()
		return
	enter_day(run_state.day + 1)


func _on_core_damaged_for_wager(_amount: int, _current: int, _max_value: int) -> void:
	var run_state = AppRefs.run_state()
	if run_state != null and run_state.phase == GameEnums.PHASE_NIGHT:
		run_state.night_core_damaged = true


func _is_tutorial_run(run_state: Node) -> bool:
	return run_state != null and run_state.has_method("is_tutorial_run") and run_state.is_tutorial_run()
