extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")


func _ready() -> void:
	AppTheme.apply(self)
	var event_bus = AppRefs.event_bus()
	var run_state = AppRefs.run_state()
	if event_bus != null:
		event_bus.phase_changed.connect(_on_phase_changed)
		event_bus.day_started.connect(refresh_day)
		event_bus.materials_changed.connect(refresh_resources)
		event_bus.prestige_changed.connect(refresh_prestige)
		event_bus.action_points_changed.connect(refresh_action_points)
		event_bus.core_hp_changed.connect(refresh_core_hp)
		event_bus.deploy_limit_changed.connect(refresh_deploy_count)
		event_bus.buffs_changed.connect(refresh_buffs)
	if run_state != null:
		refresh_phase(run_state.phase)
		refresh_day(run_state.day)
		refresh_resources(run_state.wood, run_state.stone, run_state.mana)
		refresh_prestige(run_state.prestige)
		refresh_action_points(run_state.action_points)
		refresh_core_hp(run_state.core_hp, run_state.core_hp_max)
		refresh_deploy_count(run_state.deployed_count, run_state.deploy_limit)
		refresh_buffs(run_state.get_all_buffs())


func refresh_phase(phase: int) -> void:
	var label := get_node_or_null("%PhaseLabel") as Label
	if label != null:
		var text_map := {
			GameEnums.PHASE_MENU: "菜单",
			GameEnums.PHASE_DAY: "白天",
			GameEnums.PHASE_NIGHT: "夜晚",
			GameEnums.PHASE_BLESSING: "祝福",
			GameEnums.PHASE_RESULT: "结算"
		}
		label.text = "阶段: %s" % text_map.get(phase, "未知")


func refresh_day(day: int) -> void:
	var label := get_node_or_null("%DayLabel") as Label
	if label != null:
		label.text = "Day %d/6" % day


func refresh_resources(wood: int, stone: int, mana: int) -> void:
	var label := get_node_or_null("%ResourcesLabel") as Label
	if label != null:
		label.text = "木 %d 石 %d 魔 %d" % [wood, stone, mana]


func refresh_prestige(value: int) -> void:
	var label := get_node_or_null("%PrestigeLabel") as Label
	if label != null:
		label.text = "声望: %d" % value


func refresh_action_points(value: int) -> void:
	var label := get_node_or_null("%ActionPointsLabel") as Label
	if label != null:
		label.text = "行动力: %d" % value


func refresh_core_hp(current: int, max_value: int) -> void:
	var label := get_node_or_null("%CoreHpLabel") as Label
	if label != null:
		label.text = "核心: %d/%d" % [current, max_value]


func refresh_deploy_count(current: int, max_value: int) -> void:
	var label := get_node_or_null("%DeployLabel") as Label
	if label != null:
		label.text = "部署: %d/%d" % [current, max_value]


func refresh_buffs(buff_ids: Array[StringName]) -> void:
	var label := get_node_or_null("%BuffsLabel") as Label
	if label == null:
		return
	if buff_ids.is_empty():
		label.text = "Buff: None"
		return
	var data_repo = AppRefs.data_repo()
	var buff_names: PackedStringArray = []
	for buff_id in buff_ids:
		var cfg: Dictionary = data_repo.get_buff_cfg(buff_id) if data_repo != null else {}
		buff_names.append(String(cfg.get("name", buff_id)))
	label.text = "Buff: %s" % ", ".join(buff_names)


func show_message(text: String) -> void:
	var label := get_node_or_null("%MessageLabel") as Label
	if label != null:
		label.text = text


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	refresh_phase(new_phase)
