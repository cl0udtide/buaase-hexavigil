class_name MapGenSkeleton
extends RefCounted

## 骨架生成（设计稿 S1/S2）：archetype 抽取、扇区发牌（day1 约束）、风向、
## 整数射线/扇区几何。纯静态、决定性；headless 经 preload 使用。

const REDRAW_LIMIT := 8
const WIND_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]


static func draw_archetype(cfg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var entries: Array = cfg.get("archetypes", [])
	if entries.is_empty():
		return {}
	var total: float = 0.0
	for raw: Variant in entries:
		total += maxf(float((raw as Dictionary).get("weight", 1.0)), 0.0)
	var roll: float = rng.randf() * total
	var cursor: float = 0.0
	for raw: Variant in entries:
		var entry: Dictionary = raw
		cursor += maxf(float(entry.get("weight", 1.0)), 0.0)
		if roll < cursor:
			return entry
	return entries[entries.size() - 1]


static func deal_cards(archetype: Dictionary, gate_keys: Array, day1_active: Array, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	# 牌组展开（card_id 排序保证同 deck 同展开序）→ Fisher-Yates → 依 gate_keys 升序派发。
	# 约束 no_double_steppe：day1 活跃口不得全为 steppe；重抽 ≤REDRAW_LIMIT，
	# 仍违反 → 确定性交换兜底（首个 day1 steppe 口 ↔ 首个非 day1 非 steppe 口，均按 key 升序）。
	var deck: Dictionary = archetype.get("deck", {})
	var card_ids: Array = deck.keys()
	card_ids.sort()
	var keys_sorted: Array = gate_keys.duplicate()
	keys_sorted.sort()
	for _redraw in range(REDRAW_LIMIT + 1):
		var pile: Array = []
		for raw_card: Variant in card_ids:
			for _i in range(int(deck[raw_card])):
				pile.append(String(raw_card))
		for i in range(pile.size() - 1, 0, -1):           # Fisher-Yates（rng 流内）
			var j: int = rng.randi_range(0, i)
			var tmp: Variant = pile[i]; pile[i] = pile[j]; pile[j] = tmp
		var assigned: Dictionary = {}
		for i in range(keys_sorted.size()):
			assigned[String(keys_sorted[i])] = pile[i % pile.size()]
		if not _violates_day1(assigned, day1_active, cfg):
			return assigned
		if _redraw == REDRAW_LIMIT:
			return _swap_fallback(assigned, day1_active, keys_sorted)
	return {}


## cfg.day1_card_constraint != "no_double_steppe" 或 day1_active.size()<2 → false；
## 否则当且仅当 day1 口全为 "steppe" → true。
static func _violates_day1(assigned: Dictionary, day1_active: Array, cfg: Dictionary) -> bool:
	if String(cfg.get("day1_card_constraint", "")) != "no_double_steppe":
		return false
	if day1_active.size() < 2:
		return false
	for raw_gate: Variant in day1_active:
		if String(assigned.get(String(raw_gate), "")) != "steppe":
			return false
	return true


## 首个（升序）day1 口 steppe 牌 与 首个（升序）非 day1 口非 steppe 牌互换；
## 牌组结构保证存在（任意 deck steppe ≤3 张，5 口中非 day1 口 ≥3 个）。
static func _swap_fallback(assigned: Dictionary, day1_active: Array, keys_sorted: Array) -> Dictionary:
	var day1_keys: Array[String] = []
	for raw_gate: Variant in day1_active:
		day1_keys.append(String(raw_gate))
	var steppe_key := ""
	var other_key := ""
	for raw_key: Variant in keys_sorted:
		var key := String(raw_key)
		if steppe_key.is_empty() and day1_keys.has(key) and String(assigned.get(key, "")) == "steppe":
			steppe_key = key
		if other_key.is_empty() and not day1_keys.has(key) and String(assigned.get(key, "")) != "steppe":
			other_key = key
	if steppe_key.is_empty() or other_key.is_empty():
		return assigned
	var tmp: Variant = assigned[steppe_key]
	assigned[steppe_key] = assigned[other_key]
	assigned[other_key] = tmp
	return assigned


static func roll_wind(rng: RandomNumberGenerator) -> Vector2i:
	return WIND_DIRS[rng.randi_range(0, WIND_DIRS.size() - 1)]


static func round_div(n: int, d: int) -> int:
	# d > 0；四舍五入（.5 远离零），负 n 对称处理——射线取格决定性的基石。
	if n >= 0:
		return (2 * n + d) / (2 * d)
	return -((-2 * n + d) / (2 * d))


static func ray_point(core: Vector2i, dir: Vector2i, ring: int) -> Vector2i:
	# 核心→dir 射线上切比雪夫环 = ring 的格（dir 主轴长 L 归一）。
	var l: int = maxi(maxi(absi(dir.x), absi(dir.y)), 1)
	return core + Vector2i(round_div(dir.x * ring, l), round_div(dir.y * ring, l))
