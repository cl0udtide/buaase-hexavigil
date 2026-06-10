extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

@onready var _map_manager: Node = get_node_or_null("../MapManager")
@onready var _buff_manager: Node = get_node_or_null("../BuffManager")

var _events_by_cell: Dictionary = {}


func setup_events(event_points: Array) -> void:
	_events_by_cell.clear()
	for raw_point: Variant in event_points:
		if typeof(raw_point) != TYPE_DICTIONARY:
			continue
		var point: Dictionary = raw_point
		var cell := _parse_cell(point.get("cell", Vector2i(-1, -1)))
		var event_id := StringName(point.get("event_id", ""))
		if cell.x < 0 or cell.y < 0 or event_id == StringName():
			continue
		_events_by_cell[cell] = event_id
	_refresh_map()


func clear_events() -> void:
	_events_by_cell.clear()
	_refresh_map()


func get_event_id_at_cell(cell: Vector2i) -> StringName:
	return StringName(_events_by_cell.get(cell, StringName()))


func has_event_at_cell(cell: Vector2i) -> bool:
	return get_event_id_at_cell(cell) != StringName()


func get_event_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for raw_cell in _events_by_cell.keys():
		cells.append(raw_cell as Vector2i)
	return cells


func mark_event_triggered(cell: Vector2i) -> void:
	_events_by_cell.erase(cell)
	_refresh_map()


func get_event_cfg_at_cell(cell: Vector2i) -> Dictionary:
	var event_id := get_event_id_at_cell(cell)
	if event_id == StringName():
		return {}
	return get_event_cfg(event_id)


func roll_event_for_cell(cell: Vector2i) -> StringName:
	return get_event_id_at_cell(cell)


func apply_event(event_id: StringName) -> Dictionary:
	var run_state = AppRefs.run_state()
	var cfg := get_event_cfg(event_id)
	if cfg.is_empty():
		return ActionResult.err(&"EVENT_NOT_FOUND", "找不到事件配置")
	if run_state == null:
		return ActionResult.err(&"RUN_STATE_MISSING", "RunState 尚未初始化")
	var requires_result := _check_requirements(cfg, run_state)
	if not requires_result.get("ok", false):
		return requires_result
	var payload: Dictionary = cfg.get("payload", {})
	var effect_payload := payload.duplicate(true)
	run_state.add_materials(int(payload.get("wood", 0)), int(payload.get("stone", 0)), int(payload.get("mana", 0)))
	run_state.add_prestige(int(payload.get("prestige", 0)))
	var summary_lines := _apply_contract_effects(cfg, run_state)
	if not summary_lines.is_empty():
		effect_payload["summary"] = "\n".join(summary_lines)
	return ActionResult.ok({
		"event_id": event_id,
		"effect_type": StringName(cfg.get("effect_type", "")),
		"effect_payload": effect_payload,
	})


## 事件前置消耗校验：不足时整个事件不生效（行动力由 day_manager 退还）。
func _check_requirements(cfg: Dictionary, run_state: Node) -> Dictionary:
	var requires: Dictionary = cfg.get("requires", {})
	if requires.is_empty():
		return ActionResult.ok()
	if int(requires.get("prestige", 0)) > int(run_state.prestige):
		return ActionResult.err(&"NOT_ENOUGH_PRESTIGE", "声望不足，交易取消")
	if int(requires.get("wood", 0)) > int(run_state.wood) \
			or int(requires.get("stone", 0)) > int(run_state.stone) \
			or int(requires.get("mana", 0)) > int(run_state.mana):
		return ActionResult.err(&"NOT_ENOUGH_MATERIALS", "材料不足，交易取消")
	return ActionResult.ok()


## 契约类效果：核心上限增减、随机遗物、追加夜晚词缀、不漏怪赌约。
func _apply_contract_effects(cfg: Dictionary, run_state: Node) -> PackedStringArray:
	var summary_lines := PackedStringArray()
	for raw_effect: Variant in cfg.get("effects", []):
		if typeof(raw_effect) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = raw_effect
		match StringName(effect.get("type", "")):
			&"core_max_hp_add":
				var delta := int(effect.get("value", 0))
				if run_state.has_method("add_core_max_hp"):
					run_state.add_core_max_hp(delta)
					summary_lines.append("核心生命上限 %+d" % delta)
			&"grant_random_relic":
				var granted := _grant_random_relic(int(effect.get("rarity_min", 1)), int(effect.get("rarity_max", 3)))
				if granted != StringName():
					var data_repo = AppRefs.data_repo()
					var relic_cfg: Dictionary = data_repo.get_buff_cfg(granted) if data_repo != null else {}
					summary_lines.append("获得遗物：%s" % String(relic_cfg.get("name", granted)))
				else:
					run_state.add_prestige(6)
					summary_lines.append("遗物已搜罗一空，改为获得 6 声望")
			&"night_affix_add_random":
				var affix_id := _add_random_night_affix(run_state)
				if affix_id != StringName():
					var data_repo = AppRefs.data_repo()
					var affix_cfg: Dictionary = data_repo.get_night_affix_cfg(affix_id) if data_repo != null else {}
					summary_lines.append("今晚追加词缀：%s" % String(affix_cfg.get("name", affix_id)))
			&"wager_no_leak":
				run_state.night_wager_active = true
				summary_lines.append("赌约生效：若核心一夜未失血，明早额外进行一次遗物三选一")
			_:
				pass
	return summary_lines


func _grant_random_relic(rarity_min: int, rarity_max: int) -> StringName:
	var data_repo = AppRefs.data_repo()
	var run_state = AppRefs.run_state()
	if data_repo == null or run_state == null or _buff_manager == null or not _buff_manager.has_method("apply_blessing"):
		return StringName()
	var candidates: Array[StringName] = []
	for buff_id in data_repo.get_all_buff_ids():
		if run_state.has_buff(buff_id):
			continue
		var rarity := int(data_repo.get_buff_cfg(buff_id).get("rarity", 1))
		if rarity >= rarity_min and rarity <= rarity_max:
			candidates.append(buff_id)
	if candidates.is_empty():
		return StringName()
	var picked: StringName = candidates.pick_random()
	var result: Dictionary = _buff_manager.apply_blessing(picked)
	return picked if result.get("ok", false) else StringName()


func _add_random_night_affix(run_state: Node) -> StringName:
	var data_repo = AppRefs.data_repo()
	if data_repo == null or not data_repo.has_method("get_all_night_affix_ids"):
		return StringName()
	var day := int(run_state.day)
	var gated: Array[StringName] = []
	var fallback: Array[StringName] = []
	for affix_id in data_repo.get_all_night_affix_ids():
		if (run_state.night_affix_ids as Array).has(affix_id):
			continue
		fallback.append(affix_id)
		if int(data_repo.get_night_affix_cfg(affix_id).get("min_day", 1)) <= day:
			gated.append(affix_id)
	var pool := gated if not gated.is_empty() else fallback
	if pool.is_empty():
		return StringName()
	var picked: StringName = pool.pick_random()
	run_state.night_affix_ids.append(picked)
	return picked


func apply_event_for_cell(cell: Vector2i, choice_id: StringName = StringName()) -> Dictionary:
	var event_id := roll_event_for_cell(cell)
	if event_id == StringName():
		return ActionResult.err(&"NO_EVENT", "该格子没有可触发事件")
	var triggered_event_id := event_id
	if choice_id != StringName():
		var choice_result := _resolve_choice_event_id(event_id, choice_id)
		if not choice_result.get("ok", false):
			return choice_result
		triggered_event_id = StringName(choice_result.get("payload", {}).get("event_id", event_id))
	var result := apply_event(triggered_event_id)
	if result.get("ok", false):
		var payload: Dictionary = result.get("payload", {})
		payload["source_event_id"] = event_id
		if choice_id != StringName():
			payload["choice_id"] = choice_id
		result["payload"] = payload
		mark_event_triggered(cell)
		var event_bus = AppRefs.event_bus()
		if event_bus != null:
			event_bus.random_event_triggered.emit(triggered_event_id, cell)
	return result


func get_event_cfg(event_id: StringName) -> Dictionary:
	var data_repo = AppRefs.data_repo()
	return data_repo.get_event_cfg(event_id) if data_repo != null else {}


func _refresh_map() -> void:
	if _map_manager != null and _map_manager.has_method("refresh_all_layers"):
		_map_manager.refresh_all_layers()


func _parse_cell(raw_cell: Variant) -> Vector2i:
	if raw_cell is Vector2i:
		return raw_cell
	if raw_cell is Array and raw_cell.size() >= 2:
		return Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	if raw_cell is Dictionary:
		return Vector2i(int(raw_cell.get("x", -1)), int(raw_cell.get("y", -1)))
	return Vector2i(-1, -1)


func _resolve_choice_event_id(event_id: StringName, choice_id: StringName) -> Dictionary:
	var cfg := get_event_cfg(event_id)
	if cfg.is_empty():
		return ActionResult.err(&"EVENT_NOT_FOUND", "找不到事件配置")
	var raw_choices: Variant = cfg.get("choices", [])
	if typeof(raw_choices) != TYPE_ARRAY:
		return ActionResult.err(&"CHOICE_NOT_FOUND", "该事件没有可选分支")
	for raw_choice in raw_choices:
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue
		var choice := raw_choice as Dictionary
		if StringName(choice.get("id", "")) != choice_id:
			continue
		var target_event_id := StringName(choice.get("event_id", choice.get("trigger_event_id", event_id)))
		if target_event_id == StringName():
			target_event_id = event_id
		return ActionResult.ok({"event_id": target_event_id})
	return ActionResult.err(&"CHOICE_NOT_FOUND", "找不到事件选项")
