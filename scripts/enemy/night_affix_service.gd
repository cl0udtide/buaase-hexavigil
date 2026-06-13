extends RefCounted
class_name NightAffixService

# 夜晚词缀的单一来源：抽取规则与效果结算都集中在此。
# 词缀只通过两个既有挂点生效：
#   1. 条目级 transform_entries()：波次 entries 展开前调用（追加编队、出怪口倍率）；
#   2. 个体级 apply_to_enemy_cfg()：敌人生成时作为 cfg_override（数值修饰、死亡效果、声望）。

## day -> 当晚词缀数量，逐幕加压：1（d1-3）→2（d4-6）→3（d7-9）。整数杠杆，按 <= 当天最大键阶梯取值。
const AFFIX_COUNT_BY_DAY := {
	1: 1,
	4: 2,
	7: 3,
}
const DEFAULT_AFFIX_COUNT := 3

## 这些敌人字段按整数结算（其余如 move_speed 保持浮点）。
const INT_STATS: Array[String] = ["max_hp", "atk", "def", "res", "prestige_reward", "core_damage"]


## 三幕分档：取 <= 当天的最大键（1/4/7 对应第一/二/三幕）。
static func affix_count_for_day(day: int) -> int:
	var best: int = -1
	for raw_key: Variant in AFFIX_COUNT_BY_DAY.keys():
		var k := int(raw_key)
		if k <= day and k > best:
			best = k
	return int(AFFIX_COUNT_BY_DAY[best]) if best >= 0 else DEFAULT_AFFIX_COUNT


## 确定性抽取当晚词缀：min_day 门控 + weight 加权 + 不重复。
## affix_cfgs 传入全部词缀配置（Array[Dictionary]），保持本函数可脱离 DataRepo 测试。
static func resolve_affixes_for_day(run_seed: int, day: int, affix_cfgs: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	var count := affix_count_for_day(day)
	if count <= 0:
		return result
	var candidates: Array[Dictionary] = []
	for raw_cfg: Variant in affix_cfgs:
		if typeof(raw_cfg) != TYPE_DICTIONARY:
			continue
		var cfg: Dictionary = raw_cfg
		if StringName(cfg.get("id", "")) == StringName():
			continue
		if int(cfg.get("min_day", 1)) > day:
			continue
		if float(cfg.get("weight", 1.0)) <= 0.0:
			continue
		candidates.append(cfg)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("affix|%d|%d" % [run_seed, day]).hash())
	while result.size() < count and not candidates.is_empty():
		var total_weight := 0.0
		for cfg in candidates:
			total_weight += float(cfg.get("weight", 1.0))
		var roll := rng.randf() * total_weight
		var cursor := 0.0
		var picked_index := candidates.size() - 1
		for index in range(candidates.size()):
			cursor += float(candidates[index].get("weight", 1.0))
			if roll <= cursor:
				picked_index = index
				break
		result.append(StringName(candidates[picked_index].get("id", "")))
		candidates.remove_at(picked_index)
	return result


## 把词缀的个体级效果应用到敌人配置上，返回修改后的完整 cfg（作为 spawn_enemy 的 cfg_override）。
static func apply_to_enemy_cfg(enemy_cfg: Dictionary, affix_cfgs: Array) -> Dictionary:
	var cfg := enemy_cfg.duplicate(true)
	for raw_affix: Variant in affix_cfgs:
		if typeof(raw_affix) != TYPE_DICTIONARY:
			continue
		for raw_effect: Variant in (raw_affix as Dictionary).get("effects", []):
			if typeof(raw_effect) != TYPE_DICTIONARY:
				continue
			var effect: Dictionary = raw_effect
			match StringName(effect.get("type", "")):
				&"enemy_stat_percent":
					_apply_stat_percent(cfg, effect)
				&"enemy_stat_add":
					_apply_stat_add(cfg, effect)
				&"death_effect_percent":
					_apply_death_effect(cfg, effect)
				_:
					pass
	return cfg


## 把词缀的条目级效果应用到一波的 entries 上（在展开 count 之前调用）。
## spawn_keys: 该波涉及的出怪口列表；rng_seed 保证同一波的随机选点确定且与预览一致。
static func transform_entries(entries: Array, affix_cfgs: Array, spawn_keys: Array, rng_seed: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_entry: Variant in entries:
		if typeof(raw_entry) == TYPE_DICTIONARY:
			result.append((raw_entry as Dictionary).duplicate(true))
	if spawn_keys.is_empty():
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("affix_entries|%d" % rng_seed).hash())
	for raw_affix: Variant in affix_cfgs:
		if typeof(raw_affix) != TYPE_DICTIONARY:
			continue
		for raw_effect: Variant in (raw_affix as Dictionary).get("effects", []):
			if typeof(raw_effect) != TYPE_DICTIONARY:
				continue
			var effect: Dictionary = raw_effect
			match StringName(effect.get("type", "")):
				&"extra_squad":
					var squad_key: Variant = spawn_keys[rng.randi() % spawn_keys.size()]
					result.append({
						"time": float(effect.get("time_offset", 0.0)),
						"enemy_id": String(effect.get("enemy_id", "")),
						"spawn_key": String(squad_key),
						"count": int(effect.get("count", 1)),
						"interval": float(effect.get("interval", 1.0)),
					})
				&"spawn_redistribute":
					var surge_key: Variant = spawn_keys[rng.randi() % spawn_keys.size()]
					var surge_multiplier := float(effect.get("surge_multiplier", 1.0))
					var other_multiplier := float(effect.get("other_multiplier", 1.0))
					for entry in result:
						var multiplier := surge_multiplier if String(entry.get("spawn_key", "")) == String(surge_key) else other_multiplier
						var count: int = max(int(entry.get("count", 1)), 0)
						entry["count"] = max(int(ceil(float(count) * multiplier)), 1)
				_:
					pass
	return result


## UI 公示文案。
static func describe_lines(affix_cfg: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var desc := String(affix_cfg.get("desc", "")).strip_edges()
	if not desc.is_empty():
		lines.append(desc)
	return lines


static func _apply_stat_percent(cfg: Dictionary, effect: Dictionary) -> void:
	var stat := String(effect.get("stat", ""))
	if stat.is_empty() or not cfg.has(stat):
		return
	if effect.has("min_def") and float(cfg.get("def", 0)) < float(effect.get("min_def", 0)):
		return
	var base := float(cfg.get(stat, 0.0))
	var scaled := base * (1.0 + float(effect.get("value", 0.0)))
	_write_stat(cfg, stat, scaled)


static func _apply_stat_add(cfg: Dictionary, effect: Dictionary) -> void:
	var stat := String(effect.get("stat", ""))
	if stat.is_empty():
		return
	var base := float(cfg.get(stat, 0.0))
	_write_stat(cfg, stat, base + float(effect.get("value", 0.0)))


static func _apply_death_effect(cfg: Dictionary, effect: Dictionary) -> void:
	var damage_percent := float(effect.get("value", 0.0))
	if cfg.has("death_area_damage") and typeof(cfg.get("death_area_damage")) == TYPE_DICTIONARY:
		var area: Dictionary = cfg.get("death_area_damage")
		var damage := float(area.get("damage", 0.0)) * (1.0 + damage_percent)
		area["damage"] = max(int(round(damage)), 0)
		cfg["death_area_damage"] = area
	var spawn_add := int(effect.get("spawn_add", 0))
	if spawn_add != 0 and cfg.has("death_spawn") and typeof(cfg.get("death_spawn")) == TYPE_ARRAY:
		var spawns: Array = cfg.get("death_spawn")
		for raw_spawn: Variant in spawns:
			if typeof(raw_spawn) == TYPE_DICTIONARY:
				var spawn: Dictionary = raw_spawn
				spawn["count"] = max(int(spawn.get("count", 1)) + spawn_add, 0)
		cfg["death_spawn"] = spawns


static func _write_stat(cfg: Dictionary, stat: String, value: float) -> void:
	if INT_STATS.has(stat):
		var minimum := 1 if stat == "max_hp" else 0
		cfg[stat] = max(int(round(value)), minimum)
	else:
		cfg[stat] = value
