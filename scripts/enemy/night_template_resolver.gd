extends RefCounted
class_name NightTemplateResolver

## day -> 每晚各波的档位序列。调整单局天数或夜晚节奏时改这张表。
## 占位节奏：波数随天数递增，最后一晚为 late + boss。
const WAVE_TIERS_BY_DAY := {
	1: [&"early"],
	2: [&"early", &"early"],
	3: [&"early", &"mid"],
	4: [&"mid", &"mid"],
	5: [&"mid", &"late", &"late"],
	6: [&"late", &"boss"],
}
const DEFAULT_WAVE_TIERS: Array = [&"late", &"late"]
const DEFAULT_TIER: StringName = &"late"


static func wave_tiers_for_day(day: int) -> Array[StringName]:
	var raw_tiers: Array = WAVE_TIERS_BY_DAY.get(day, DEFAULT_WAVE_TIERS)
	var tiers: Array[StringName] = []
	for raw_tier: Variant in raw_tiers:
		tiers.append(StringName(raw_tier))
	return tiers


static func wave_count_for_day(day: int) -> int:
	return wave_tiers_for_day(day).size()


## 兼容入口：返回当晚首波档位。
static func tier_for_day(day: int) -> StringName:
	var tiers := wave_tiers_for_day(day)
	return tiers[0] if not tiers.is_empty() else DEFAULT_TIER


## 解析整夜计划：按当日档位序列逐波抽模板，夜内与局内均不重复（池耗尽时回退允许重复）。
## pools: Dictionary[StringName tier -> Array[StringName] template_ids]，由调用方从 DataRepo 组装。
static func resolve_night_plan(pools: Dictionary, used_ids: Array, run_seed: int, day: int) -> Array[StringName]:
	var plan: Array[StringName] = []
	var combined_used: Array = []
	for raw_used: Variant in used_ids:
		combined_used.append(StringName(raw_used))
	var tiers := wave_tiers_for_day(day)
	for wave_index in range(tiers.size()):
		var tier: StringName = tiers[wave_index]
		var pool: Array = pools.get(tier, [])
		var template_id := resolve(pool, combined_used, run_seed, day, wave_index)
		if template_id == StringName():
			continue
		plan.append(template_id)
		if not combined_used.has(template_id):
			combined_used.append(template_id)
	return plan


static func resolve(pool_ids: Array, used_ids: Array, run_seed: int, day: int, wave_index: int = 0) -> StringName:
	var available: Array[StringName] = []
	for raw_id: Variant in pool_ids:
		var id := StringName(raw_id)
		if id != StringName() and not used_ids.has(id):
			available.append(id)
	if available.is_empty():
		for raw_id: Variant in pool_ids:
			var id := StringName(raw_id)
			if id != StringName():
				available.append(id)
	if available.is_empty():
		return StringName()
	available.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("%d|%d|%d|%s" % [run_seed, day, wave_index, String(tier_for_day(day))]).hash())
	return available[rng.randi() % available.size()]


## ---- 出怪口分配：lane 角色 -> 具体 spawn_key ----
## 设计稿见 docs/superpowers/specs/2026-06-10-dynamic-spawn-gates-design.md §3-§4。
## 纯静态、确定性：同 (run_seed, day, wave_index) 输入永远得到同样结果，预览即契约。

const LANE_MAIN: StringName = &"main"
const LANE_FLANK: StringName = &"flank"
const LANE_ANY: StringName = &"any"


static func _sorted_gates(active_gates: Array) -> Array[String]:
	var gates: Array[String] = []
	for raw_gate: Variant in active_gates:
		var gate := String(raw_gate)
		if not gate.is_empty() and not gates.has(gate):
			gates.append(gate)
	gates.sort()
	return gates


## 该波的主攻口：在活跃口中等权抽取。
static func resolve_main_gate(active_gates: Array, run_seed: int, day: int, wave_index: int) -> String:
	var gates := _sorted_gates(active_gates)
	if gates.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("gate|%d|%d|%d" % [run_seed, day, wave_index]).hash())
	return gates[rng.randi() % gates.size()]


## 按 lane 给一个组分配落口。flank 从非主攻口中独立抽取（单口时回退主攻口），any 全口等权。
## 未知 lane 按 any 处理；空口集合回退 main_gate。
static func resolve_lane_gate(lane: StringName, group_index: int, main_gate: String, active_gates: Array, run_seed: int, day: int, wave_index: int) -> String:
	var gates := _sorted_gates(active_gates)
	if gates.is_empty():
		return main_gate
	match lane:
		LANE_MAIN:
			return main_gate
		LANE_FLANK:
			var others: Array[String] = []
			for gate in gates:
				if gate != main_gate:
					others.append(gate)
			if others.is_empty():
				return main_gate
			var rng := RandomNumberGenerator.new()
			rng.seed = abs(("lane|%d|%d|%d|%d|flank" % [run_seed, day, wave_index, group_index]).hash())
			return others[rng.randi() % others.size()]
		_:
			var rng_any := RandomNumberGenerator.new()
			rng_any.seed = abs(("lane|%d|%d|%d|%d|any" % [run_seed, day, wave_index, group_index]).hash())
			return gates[rng_any.randi() % gates.size()]


## ---- 激活序与当日活跃集 ----

## 活跃口数量日程表（占位值）：阶梯取 <= day 的最大键。
const ACTIVE_COUNT_BY_DAY := {1: 2, 3: 3, 5: 4, 7: 5}


static func active_gate_count_for_day(day: int) -> int:
	var best_key: int = -1
	for raw_key: Variant in ACTIVE_COUNT_BY_DAY.keys():
		var key := int(raw_key)
		if key <= day and key > best_key:
			best_key = key
	if best_key < 0:
		return int(ACTIVE_COUNT_BY_DAY.get(1, 2))
	return int(ACTIVE_COUNT_BY_DAY.get(best_key, 2))


## 激活序：每局固定的口激活顺序。无存档状态，任意一天可由 seed 重算。
static func resolve_activation_order(all_gates: Array, run_seed: int) -> Array[String]:
	var gates := _sorted_gates(all_gates)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("gate_order|%d" % run_seed).hash())
	for i in range(gates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := gates[i]
		gates[i] = gates[j]
		gates[j] = tmp
	return gates


## 当日有效活跃集 = (激活序前 N ∪ extra_open) − closed，下限 1（保激活序第一位）。
## closed/extra_open 是一夜覆盖项（RunState 持有，黎明清空）。返回值升序。
static func resolve_active_gates(all_gates: Array, run_seed: int, day: int, closed: Array = [], extra_open: Array = []) -> Array[String]:
	var order := resolve_activation_order(all_gates, run_seed)
	if order.is_empty():
		return []
	var closed_keys: Array[String] = []
	for raw_closed: Variant in closed:
		closed_keys.append(String(raw_closed))
	var count: int = mini(active_gate_count_for_day(day), order.size())
	var active: Array[String] = []
	for i in range(count):
		active.append(order[i])
	for raw_extra: Variant in extra_open:
		var extra_gate := String(raw_extra)
		if order.has(extra_gate) and not active.has(extra_gate):
			active.append(extra_gate)
	var result: Array[String] = []
	for gate in active:
		if not closed_keys.has(gate):
			result.append(gate)
	if result.is_empty():
		result.append(order[0])
	result.sort()
	return result
