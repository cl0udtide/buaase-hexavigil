extends Node

# 盟约（卫戍协议）管理器：实时统计场上部署情况，计算各盟约人数/层数/激活档位，
# 把持续数值类修正按 &"covenant" 通道推送给单位，离散行为（迅捷部署 SP、萨尔贡叠层）
# 在事件点处理。远见按“拥有”而非“部署”统计（白天商店效果），单独重算。
# 盟约定义与数值见 CovenantDefs；效果接入点散落在 unit_actor / shop_manager / unit_manager。

const AppRefs = preload("res://scripts/common/app_refs.gd")

@onready var _unit_manager: Node = get_node_or_null("../UnitManager")

# covenant_id -> {count:int, layers:int, tier:int(0/2/3)}
var _state: Dictionary = {}
# 萨尔贡叠层：仅在萨尔贡人数≥2 时累积，<2 清零。
var _sargon_stacks := 0


func _ready() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		if event_bus.has_signal("unit_deployed"):
			event_bus.unit_deployed.connect(_on_unit_deployed)
		if event_bus.has_signal("unit_removed"):
			event_bus.unit_removed.connect(_on_unit_removed)
		if event_bus.has_signal("unit_skill_cast"):
			event_bus.unit_skill_cast.connect(_on_unit_skill_cast)
		if event_bus.has_signal("owned_operators_changed"):
			event_bus.owned_operators_changed.connect(_on_owned_operators_changed)
	recompute_owned()
	recompute()


func get_state() -> Dictionary:
	return _state.duplicate(true)


# 坚守 3 人：伤害均摊池是否激活。
func is_steadfast_pool_active() -> bool:
	return _tier(CovenantDefs.ID_STEADFAST) >= CovenantDefs.TIER_TRIO


# 当前存活的坚守干员（供 unit_actor 伤害均摊使用）。
func get_steadfast_units() -> Array:
	var result: Array = []
	for unit in _get_deployed_units():
		if _is_alive(unit) and _has_tag(_unit_covenants(unit), CovenantDefs.ID_STEADFAST):
			result.append(unit)
	return result


# 远见档位/层数（按拥有统计；供商店与出售查询）。
func get_foresight_tier() -> int:
	return _tier(CovenantDefs.ID_FORESIGHT)


func get_foresight_layers() -> int:
	return _layers(CovenantDefs.ID_FORESIGHT)


func _on_unit_deployed(unit_runtime_id: int, _operator_key: StringName, _unit_id: StringName, _cell: Vector2i) -> void:
	recompute()
	_grant_swift_deploy_sp(unit_runtime_id)


func _on_unit_removed(_unit_runtime_id: int, _reason: int) -> void:
	recompute()


func _on_owned_operators_changed(_operators: Array) -> void:
	recompute_owned()


# 萨尔贡：萨尔贡干员开启技能时叠加一层（封顶层数），重新推送增益。
func _on_unit_skill_cast(unit_runtime_id: int, _unit_id: StringName) -> void:
	if _tier(CovenantDefs.ID_SARGON) < CovenantDefs.TIER_PAIR:
		return
	var unit := _get_unit(unit_runtime_id)
	if unit == null or not _has_tag(_unit_covenants(unit), CovenantDefs.ID_SARGON):
		return
	var cap := CovenantDefs.sargon_max_stacks(_layers(CovenantDefs.ID_SARGON))
	var new_stacks := min(_sargon_stacks + 1, cap)
	if new_stacks == _sargon_stacks:
		return
	_sargon_stacks = new_stacks
	_push_unit_mods()


# 部署型盟约重算（不含按拥有统计的远见）。
func recompute() -> void:
	var units := _get_deployed_units()
	var member_ids: Dictionary = {}
	var layer_sums: Dictionary = {}
	for unit in units:
		if not _is_alive(unit):
			continue
		var star := int(unit.cfg.get("operator_star", 1))
		for covenant_id in _unit_covenants(unit):
			var cid := StringName(covenant_id)
			if not CovenantDefs.is_known(cid) or CovenantDefs.is_owned_based(cid):
				continue
			if not member_ids.has(cid):
				member_ids[cid] = {}
				layer_sums[cid] = 0
			(member_ids[cid] as Dictionary)[String(unit.unit_id)] = true
			layer_sums[cid] = int(layer_sums[cid]) + star

	for covenant_id in CovenantDefs.ORDER:
		if CovenantDefs.is_owned_based(covenant_id):
			continue
		var count := int((member_ids.get(covenant_id, {}) as Dictionary).size())
		_state[covenant_id] = {
			"count": count,
			"layers": int(layer_sums.get(covenant_id, 0)),
			"tier": _tier_for_count(count),
		}

	# 萨尔贡人数不足则清空叠层（3→2→3 不重置，因 2 人即满足）。
	if _tier(CovenantDefs.ID_SARGON) < CovenantDefs.TIER_PAIR:
		_sargon_stacks = 0

	_push_unit_mods()
	_emit_changed()


# 拥有型盟约重算（远见）。
func recompute_owned() -> void:
	var run_state = AppRefs.run_state()
	var data_repo = AppRefs.data_repo()
	var owned: Array = run_state.get_owned_operators() if run_state != null and run_state.has_method("get_owned_operators") else []
	for covenant_id in CovenantDefs.OWNED_BASED:
		var members: Dictionary = {}
		var layers := 0
		for op in owned:
			var op_dict := op as Dictionary
			var unit_id := StringName(op_dict.get("unit_id", ""))
			if _unit_id_has_covenant(unit_id, covenant_id, data_repo):
				members[String(unit_id)] = true
				layers += int(op_dict.get("star", 1))
		var count := int(members.size())
		_state[covenant_id] = {"count": count, "layers": layers, "tier": _tier_for_count(count)}
	_emit_changed()


func _push_unit_mods() -> void:
	for unit in _get_deployed_units():
		if _is_alive(unit) and unit.has_method("set_modifier_channel"):
			unit.set_modifier_channel(&"covenant", _build_unit_mods(unit))


# 为单个单位汇总当前盟约带来的 &"covenant" 修正。
func _build_unit_mods(unit: Node) -> Dictionary:
	var mods: Dictionary = {}
	var tags := _unit_covenants(unit)
	var is_ranged := _is_ranged(unit)

	# 精准：2人精准干员 atk%；3人作用于所有远程并追加无视防御/法抗
	var prec_tier := _tier(CovenantDefs.ID_PRECISION)
	if prec_tier >= CovenantDefs.TIER_PAIR:
		var prec_layer := _layers(CovenantDefs.ID_PRECISION)
		var atk_eligible := _has_tag(tags, CovenantDefs.ID_PRECISION) or (prec_tier >= CovenantDefs.TIER_TRIO and is_ranged)
		if atk_eligible:
			mods["atk_percent"] = float(mods.get("atk_percent", 0.0)) + CovenantDefs.precision_atk_percent(prec_layer)
		if prec_tier >= CovenantDefs.TIER_TRIO and is_ranged:
			mods["defense_ignore"] = float(mods.get("defense_ignore", 0.0)) + CovenantDefs.precision_defense_ignore()

	# 坚守：2人坚守干员 hp%（3人伤害均摊在 unit_actor 中处理）
	if _tier(CovenantDefs.ID_STEADFAST) >= CovenantDefs.TIER_PAIR and _has_tag(tags, CovenantDefs.ID_STEADFAST):
		mods["hp_percent"] = float(mods.get("hp_percent", 0.0)) + CovenantDefs.steadfast_hp_percent(_layers(CovenantDefs.ID_STEADFAST))

	# 迅捷：2人起所有干员 SP 回复加值
	if _tier(CovenantDefs.ID_SWIFT) >= CovenantDefs.TIER_PAIR:
		mods["sp_recover_add"] = float(mods.get("sp_recover_add", 0.0)) + CovenantDefs.swift_sp_recover_add(_layers(CovenantDefs.ID_SWIFT))

	# 突袭：2人突袭干员再部署减免；3人作用于所有干员
	var raid_tier := _tier(CovenantDefs.ID_RAID)
	if raid_tier >= CovenantDefs.TIER_PAIR and (_has_tag(tags, CovenantDefs.ID_RAID) or raid_tier >= CovenantDefs.TIER_TRIO):
		mods["redeploy_reduction"] = float(mods.get("redeploy_reduction", 0.0)) + CovenantDefs.raid_redeploy_reduction(_layers(CovenantDefs.ID_RAID))

	# 不屈：2人不屈干员复活几率；3人作用于所有干员
	var uny_tier := _tier(CovenantDefs.ID_UNYIELDING)
	if uny_tier >= CovenantDefs.TIER_PAIR and (_has_tag(tags, CovenantDefs.ID_UNYIELDING) or uny_tier >= CovenantDefs.TIER_TRIO):
		mods["revive_chance"] = max(float(mods.get("revive_chance", 0.0)), CovenantDefs.unyielding_revive_chance(_layers(CovenantDefs.ID_UNYIELDING)))

	# 萨尔贡：2人增益作用于萨尔贡干员；3人作用于所有干员（仍只有萨尔贡开技能叠层）
	var sargon_tier := _tier(CovenantDefs.ID_SARGON)
	if sargon_tier >= CovenantDefs.TIER_PAIR and _sargon_stacks > 0:
		if _has_tag(tags, CovenantDefs.ID_SARGON) or sargon_tier >= CovenantDefs.TIER_TRIO:
			mods["aspd_add"] = float(mods.get("aspd_add", 0.0)) + CovenantDefs.sargon_aspd_per_stack() * float(_sargon_stacks)
			mods["atk_percent"] = float(mods.get("atk_percent", 0.0)) + CovenantDefs.sargon_atk_percent_per_stack() * float(_sargon_stacks)

	return mods


# 迅捷 3人：部署/再部署初动 +5 SP（部署完成事件触发）。
func _grant_swift_deploy_sp(unit_runtime_id: int) -> void:
	if _tier(CovenantDefs.ID_SWIFT) < CovenantDefs.TIER_TRIO:
		return
	var unit := _get_unit(unit_runtime_id)
	if unit != null and unit.has_method("gain_sp"):
		unit.gain_sp(CovenantDefs.swift_deploy_sp())


# ---------------------------------------------------------------------------
func _tier_for_count(count: int) -> int:
	if count >= CovenantDefs.TIER_TRIO:
		return CovenantDefs.TIER_TRIO
	if count >= CovenantDefs.TIER_PAIR:
		return CovenantDefs.TIER_PAIR
	return 0


func _tier(covenant_id: StringName) -> int:
	return int((_state.get(covenant_id, {}) as Dictionary).get("tier", 0))


func _layers(covenant_id: StringName) -> int:
	return int((_state.get(covenant_id, {}) as Dictionary).get("layers", 0))


func _get_deployed_units() -> Array:
	if _unit_manager != null and _unit_manager.has_method("get_all_deployed_units"):
		return _unit_manager.get_all_deployed_units()
	return []


func _get_unit(unit_runtime_id: int) -> Node:
	if _unit_manager != null and _unit_manager.has_method("get_unit_by_runtime_id"):
		return _unit_manager.get_unit_by_runtime_id(unit_runtime_id)
	return null


func _is_alive(unit) -> bool:
	return unit != null and is_instance_valid(unit) and int(unit.current_hp) > 0


func _is_ranged(unit) -> bool:
	var c := String(unit.cfg.get("class", ""))
	return c == "sniper" or c == "caster"


func _unit_covenants(unit) -> Array:
	var raw = unit.cfg.get("covenants", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


# 通过单位配置（data_repo）判断某 unit_id 是否带有盟约 tag（用于拥有制统计）。
func _unit_id_has_covenant(unit_id: StringName, covenant_id: StringName, data_repo = null) -> bool:
	if data_repo == null:
		data_repo = AppRefs.data_repo()
	if data_repo == null or unit_id == StringName():
		return false
	var cfg: Dictionary = data_repo.get_unit_cfg(unit_id)
	var raw = cfg.get("covenants", [])
	return _has_tag(raw if typeof(raw) == TYPE_ARRAY else [], covenant_id)


func _has_tag(tags: Array, covenant_id: StringName) -> bool:
	for t in tags:
		if String(t) == String(covenant_id):
			return true
	return false


func _emit_changed() -> void:
	var entries: Array = []
	for covenant_id in CovenantDefs.ORDER:
		var s: Dictionary = _state.get(covenant_id, {})
		var count := int(s.get("count", 0))
		if count <= 0:
			continue
		entries.append({
			"id": covenant_id,
			"name": CovenantDefs.display_name(covenant_id),
			"count": count,
			"layers": int(s.get("layers", 0)),
			"tier": int(s.get("tier", 0)),
		})
	var event_bus = AppRefs.event_bus()
	if event_bus != null and event_bus.has_signal("covenants_changed"):
		event_bus.covenants_changed.emit(entries)
