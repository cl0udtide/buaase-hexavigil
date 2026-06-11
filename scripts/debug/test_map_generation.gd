extends SceneTree

## 地图生成回归（地形包 B1 起建，B2 持续扩展）：
## 噪声决定性 / 种子分流隔离 / 绕路上限修复。
## 运行：Godot --headless --path . --script scripts/debug/test_map_generation.gd

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")
const MapGeneratorScript = preload("res://scripts/map/map_generator.gd")
const CellDataRef = preload("res://scripts/map/cell_data.gd")
const SkeletonGen = preload("res://scripts/map/generation/skeleton.gd")
const NightResolverRef = preload("res://scripts/enemy/night_template_resolver.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_int_noise()
	_test_stage_stream_isolation()
	_test_detour_repair()
	_test_cards_archetypes_wind()
	_test_sector_geometry()
	_finish()


## v2 配置字面量（密封测试用，不读 json；数值=设计稿 §4.4，平衡占位可自由取整）。
func _v2_cfg() -> Dictionary:
	return {
		"width": 30, "height": 30, "spawn_count": 5,
		"resources_per_type": 12, "near_resources_per_type": 2, "event_point_count": 0,
		"core_safe_radius": 3, "spawn_safe_radius": 2,
		"spawn_corner_margin": 3, "spawn_arc_center_ratio": 0.6,
		"generator": "skeleton_v2",
		"max_retries": 5, "max_repair_rounds": 3,
		"detour_cap": 1.6, "detour_floor": 1.15,
		"lane_jitter_base": 0.35, "corridor_slack": 3, "gate_slide_jitter": 2,
		"repair": {
			"carve_costs": {"water": 6, "mountain": 12},
			"intrusion_max_per_map": 0.15, "intrusion_max_mean": 0.10,
			"dual_pass_ratio_cap": 0.25,
		},
		"pass": {"aperture_depth": 2, "pocket_core_w": 3, "pocket_core_h": 2,
			"pocket_min_plain": 6, "pocket_flood_limit": 12},
		"mesa": {
			"count_min": 4, "count_max": 6, "count_floor_degraded": 3,
			"cells_min": 14, "cells_max": 24,
			"size_weights": {"3": 0.30, "4": 0.35, "5": 0.20, "6": 0.15},
			"max_corridor_dist": 2, "min_covered_ratio": 0.6,
			"starter": {"ring_min": 4, "ring_max": 5, "size_min": 3, "size_max": 4, "max_corridor_dist": 2},
		},
		"economy": {
			"resource_affinity": {"wood": "moist_plain", "stone": "foothill", "mana": "water_adjacent"},
			"risk_reward_bias": 0.5,
		},
		"moisture_gradient_strength": 0.2,
		"sector_cards": {
			"bastion": {"pass_width": 2, "pass_ring": [6, 8], "density": 1.3, "mesa_quota": 1, "jitter_amp": 0.5, "resource_mult": 1.0},
			"steppe": {"pass_width": 5, "pass_ring": [7, 10], "density": 0.6, "mesa_quota": 0, "jitter_amp": 0.3, "resource_mult": 1.5, "lake": [1, 2]},
			"riverlands": {"pass_width": 2, "pass_ring": [6, 9], "density": 0.9, "mesa_quota": 1, "jitter_amp": 0.4, "resource_mult": 1.1, "river": true, "ford_width": 2},
			"canyon": {"pass_width": 3, "pass_ring": [6, 10], "density": 1.2, "mesa_quota": 1, "jitter_amp": 0.35, "resource_mult": 0.9, "corridor_len": [6, 9]},
		},
		"archetypes": [
			{"id": "highland_run", "weight": 1.0, "deck": {"bastion": 2, "canyon": 2, "steppe": 1},
				"confluence": "five_fingers", "ratio_band": [0.24, 0.28]},
			{"id": "riverine_run", "weight": 1.0, "deck": {"riverlands": 3, "steppe": 1, "bastion": 1},
				"confluence": "twin_pincers", "ratio_band": [0.20, 0.24]},
			{"id": "open_run", "weight": 1.0, "deck": {"steppe": 3, "bastion": 1, "riverlands": 1},
				"confluence": "trident", "ratio_band": [0.20, 0.22]},
		],
		"day1_card_constraint": "no_double_steppe",
		"bias_cards_by_activation": false,
	}


func _new_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_int_noise() -> void:
	_expect(IntNoise.cell_hash(3, 7, 42) == IntNoise.cell_hash(3, 7, 42), "cell_hash deterministic")
	_expect(IntNoise.derive_seed(1234, 0, 2) == IntNoise.derive_seed(1234, 0, 2), "derive_seed deterministic")
	var same_count: int = 0
	for i in range(100):
		if IntNoise.cell_hash(i, 0, 42) == IntNoise.cell_hash(i + 1, 0, 42):
			same_count += 1
	_expect(same_count <= 5, "cell_hash varies across x (same=%d)" % same_count)
	_expect(IntNoise.derive_seed(1234, 0, 1) != IntNoise.derive_seed(1234, 0, 2), "stage ids derive distinct seeds")
	_expect(IntNoise.derive_seed(1234, 0, 1) != IntNoise.derive_seed(1234, 1, 1), "attempts derive distinct seeds")
	_expect(IntNoise.derive_seed(1234, 0, 1) != IntNoise.derive_seed(4321, 0, 1), "run seeds derive distinct seeds")
	for seed_value in [0, 1, -7, 123456789]:
		_expect(IntNoise.derive_seed(seed_value, 2, 3) >= 0, "derive_seed non-negative for %d" % seed_value)
	var min_v: float = 1.0
	var max_v: float = 0.0
	var prev: float = IntNoise.value_noise(0, 5, 42, 8)
	var max_step: float = 0.0
	for x in range(64):
		var v: float = IntNoise.value_noise(x, 5, 42, 8)
		min_v = minf(min_v, v)
		max_v = maxf(max_v, v)
		max_step = maxf(max_step, absf(v - prev))
		prev = v
	_expect(min_v >= 0.0 and max_v < 1.0, "value_noise in [0,1) (min=%f max=%f)" % [min_v, max_v])
	_expect(max_v - min_v > 0.2, "value_noise has variation")
	_expect(max_step < 0.5, "value_noise bilinear smoothness (max_step=%f)" % max_step)
	_expect(absf(IntNoise.value_noise(13, 21, 42, 8) - IntNoise.value_noise(13, 21, 42, 8)) == 0.0, "value_noise deterministic")
	var neg: float = IntNoise.value_noise(-13, -7, 42, 8)
	_expect(neg >= 0.0 and neg < 1.0, "value_noise handles negative coords (v=%f)" % neg)
	_expect(absf(IntNoise.value_noise(-13, -7, 42, 8) - neg) == 0.0, "negative coords deterministic")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _serialize_terrain(generated: Dictionary) -> String:
	var cells: Dictionary = generated.get("cells", {})
	var keys: Array = cells.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for raw_key: Variant in keys:
		var data: CellData = cells[raw_key]
		parts.append("%s:%s:%s" % [str(raw_key), String(data.terrain), String(data.resource_type)])
	return "|".join(parts)


func _serialize_obstacles_only(generated: Dictionary) -> String:
	var cells: Dictionary = generated.get("cells", {})
	var keys: Array = cells.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for raw_key: Variant in keys:
		var data: CellData = cells[raw_key]
		if data.terrain != CellDataRef.TERRAIN_PLAIN:
			parts.append("%s:%s" % [str(raw_key), String(data.terrain)])
	return "|".join(parts)


func _serialize_resources_only(generated: Dictionary) -> String:
	var cells: Dictionary = generated.get("cells", {})
	var keys: Array = cells.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for raw_key: Variant in keys:
		var data: CellData = cells[raw_key]
		if data.resource_type != StringName():
			parts.append("%s:%s" % [str(raw_key), String(data.resource_type)])
	return "|".join(parts)


func _test_stage_stream_isolation() -> void:
	var base_cfg := {"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0}
	var a: Dictionary = MapGeneratorScript.generate(30, 30, 9001, base_cfg, [])
	var b: Dictionary = MapGeneratorScript.generate(30, 30, 9001, base_cfg, [])
	_expect(_serialize_terrain(a) == _serialize_terrain(b), "same seed same map (full determinism)")
	var c: Dictionary = MapGeneratorScript.generate(30, 30, 9002, base_cfg, [])
	_expect(_serialize_terrain(a) != _serialize_terrain(c), "different seed different map")
	# 流隔离：只改资源参数，出怪口与障碍布局不得变化。
	var resource_cfg := {"spawn_count": 5, "resources_per_type": 8, "event_point_count": 0}
	var d: Dictionary = MapGeneratorScript.generate(30, 30, 9001, resource_cfg, [])
	_expect(str(a.get("spawn_cells")) == str(d.get("spawn_cells")), "resource cfg change keeps spawn placement")
	_expect(_serialize_obstacles_only(a) == _serialize_obstacles_only(d), "resource cfg change keeps obstacle layout")
	# 流隔离反向：只改障碍参数，但固定障碍为 0 以保持 terrain 候选集一致，
	# 验证 water_obstacle_chance 不同时资源布局相同（RNG 流独立，输入候选集也一致）。
	var no_obstacles_base := {
		"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0,
		"min_obstacle_count": 0, "max_obstacle_count": 0, "water_obstacle_chance": 0.35
	}
	var no_obstacles_alt := {
		"spawn_count": 5, "resources_per_type": 12, "event_point_count": 0,
		"min_obstacle_count": 0, "max_obstacle_count": 0, "water_obstacle_chance": 0.0
	}
	var e: Dictionary = MapGeneratorScript.generate(30, 30, 9001, no_obstacles_base, [])
	var f: Dictionary = MapGeneratorScript.generate(30, 30, 9001, no_obstacles_alt, [])
	_expect(str(e.get("spawn_cells")) == str(f.get("spawn_cells")), "obstacle cfg change keeps spawn placement")
	_expect(_serialize_resources_only(e) == _serialize_resources_only(f), "obstacle cfg change keeps resource layout (no-obstacle baseline)")


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _bfs_path_length(cells: Dictionary, width: int, height: int, from_cell: Vector2i, to_cell: Vector2i) -> int:
	var queue: Array[Vector2i] = [from_cell]
	var dist: Dictionary = {from_cell: 0}
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == to_cell:
			return int(dist[current])
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var neighbor: Vector2i = current + direction
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			if dist.has(neighbor):
				continue
			var data: CellData = cells.get(neighbor)
			if data == null or not data.walkable:
				continue
			dist[neighbor] = int(dist[current]) + 1
			queue.append(neighbor)
	return -1


func _test_detour_repair() -> void:
	var cfg := {
		"spawn_count": 5,
		"resources_per_type": 12,
		"event_point_count": 0,
		"obstacle_ratio": 0.24,
		"min_obstacle_count": 190,
		"max_obstacle_count": 220,
		"detour_cap": 1.6,
		"max_repair_rounds": 3,
	}
	var worst_ratio: float = 0.0
	for seed_value in range(7000, 7015):
		var generated: Dictionary = MapGeneratorScript.generate(30, 30, seed_value, cfg, [])
		var cells: Dictionary = generated.get("cells", {})
		var core_cell: Vector2i = generated.get("core_cell", Vector2i.ZERO)
		for raw_spawn: Variant in generated.get("spawn_cells", []):
			var spawn_cell: Vector2i = raw_spawn
			var path_len: int = _bfs_path_length(cells, 30, 30, spawn_cell, core_cell)
			_expect(path_len > 0, "seed %d: gate connected" % seed_value)
			if path_len <= 0:
				continue
			var ratio: float = float(path_len) / float(maxi(_manhattan(spawn_cell, core_cell), 1))
			worst_ratio = maxf(worst_ratio, ratio)
			_expect(ratio <= 1.6 + 0.0001, "seed %d: detour ratio %.3f <= 1.6" % [seed_value, ratio])
	print("  detour worst ratio: %.3f" % worst_ratio)
	var a: Dictionary = MapGeneratorScript.generate(30, 30, 7000, cfg, [])
	var b: Dictionary = MapGeneratorScript.generate(30, 30, 7000, cfg, [])
	_expect(_serialize_terrain(a) == _serialize_terrain(b), "repair keeps determinism")
	# 生产预算回归：评审实测的四个超限种子 + 50 种子统计扫。
	# cfg 各键逐字复制自 data/map_generation.json（超限种子按现行生产配置实测验证）。
	var prod_cfg := {
		"spawn_count": 5,
		"resources_per_type": 12,
		"near_resources_per_type": 2,
		"event_point_count": 0,
		"obstacle_ratio": 0.13,
		"water_obstacle_chance": 0.35,
		"min_obstacle_count": 65,
		"max_obstacle_count": 115,
		"terrain_cluster_count": 5,
		"terrain_cluster_min_size": 12,
		"terrain_cluster_max_size": 28,
		"terrain_cluster_attempts": 24,
		"scattered_obstacle_ratio": 0.22,
		"core_safe_radius": 3,
		"spawn_safe_radius": 2,
		"spawn_corner_margin": 3,
		"spawn_arc_center_ratio": 0.6,
		"detour_cap": 1.6,
		"max_repair_rounds": 3,
		"repair": {"carve_costs": {"water": 6, "mountain": 12}},
	}
	var prod_worst: float = 0.0
	var prod_seeds: Array[int] = [97, 160, 224, 430]
	for extra_seed in range(5000, 5046):
		prod_seeds.append(extra_seed)
	for prod_seed in prod_seeds:
		var prod_map: Dictionary = MapGeneratorScript.generate(30, 30, prod_seed, prod_cfg, [])
		var prod_cells: Dictionary = prod_map.get("cells", {})
		var prod_core: Vector2i = prod_map.get("core_cell", Vector2i.ZERO)
		for raw_gate: Variant in prod_map.get("spawn_cells", []):
			var gate_cell: Vector2i = raw_gate
			var prod_len: int = _bfs_path_length(prod_cells, 30, 30, gate_cell, prod_core)
			_expect(prod_len > 0, "prod seed %d: gate connected" % prod_seed)
			if prod_len <= 0:
				continue
			var prod_ratio: float = float(prod_len) / float(maxi(_manhattan(gate_cell, prod_core), 1))
			prod_worst = maxf(prod_worst, prod_ratio)
			_expect(prod_ratio <= 1.6 + 0.0001, "prod seed %d: ratio %.3f <= 1.6" % [prod_seed, prod_ratio])
	print("  prod budget worst ratio: %.3f" % prod_worst)


func _test_cards_archetypes_wind() -> void:
	var cfg := _v2_cfg()
	# json 已扩 schema（值与 _v2_cfg 同源；generator 在 B2-11 前保持 legacy）。
	var file := FileAccess.open("res://data/map_generation.json", FileAccess.READ)
	_expect(file != null, "map_generation.json readable")
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	for key in ["generator", "sector_cards", "archetypes", "day1_card_constraint",
			"moisture_gradient_strength", "pass", "mesa", "economy",
			"detour_floor", "lane_jitter_base", "corridor_slack", "gate_slide_jitter", "max_retries"]:
		_expect(parsed.has(key), "json has key %s" % key)
	_expect(["legacy", "skeleton_v2"].has(String(parsed.get("generator", ""))), "generator value sane")
	_expect(int(parsed.get("spawn_safe_radius", 0)) == 2, "spawn_safe_radius raised to 2 (spec 4.4)")
	_expect((parsed.get("sector_cards", {}) as Dictionary).size() == 4, "4 sector cards in json")
	_expect((parsed.get("archetypes", []) as Array).size() == 3, "3 archetypes in json")
	# archetype 抽取：分布覆盖 + 决定性。
	var seen: Dictionary = {}
	for seed_value in range(60):
		var arch: Dictionary = SkeletonGen.draw_archetype(cfg, _new_rng(seed_value))
		seen[String(arch.get("id", ""))] = true
	for arch_id in ["highland_run", "riverine_run", "open_run"]:
		_expect(seen.has(arch_id), "archetype %s drawn within 60 seeds" % arch_id)
	_expect(str(SkeletonGen.draw_archetype(cfg, _new_rng(7))) == str(SkeletonGen.draw_archetype(cfg, _new_rng(7))), "draw_archetype deterministic")
	# 发牌：牌面=牌组多重集、day1 约束 100 个种子零违反、决定性。
	var gate_keys: Array = ["S1", "S2", "S3", "S4", "S5"]
	for seed_value in range(100):
		var arch: Dictionary = SkeletonGen.draw_archetype(cfg, _new_rng(seed_value))
		var day1: Array = NightResolverRef.resolve_active_gates(gate_keys, seed_value, 1)
		var cards: Dictionary = SkeletonGen.deal_cards(arch, gate_keys, day1, _new_rng(seed_value * 31 + 1), cfg)
		_expect(cards.size() == 5, "seed %d: 5 cards dealt" % seed_value)
		var counts: Dictionary = {}
		for raw_key: Variant in cards.keys():
			var card_id := String(cards[raw_key])
			counts[card_id] = int(counts.get(card_id, 0)) + 1
		var deck: Dictionary = arch.get("deck", {})
		for raw_card: Variant in deck.keys():
			_expect(int(counts.get(String(raw_card), 0)) == int(deck[raw_card]), "seed %d: deck multiset preserved for %s" % [seed_value, String(raw_card)])
		var steppe_on_day1: int = 0
		for raw_gate: Variant in day1:
			if String(cards.get(String(raw_gate), "")) == "steppe":
				steppe_on_day1 += 1
		_expect(steppe_on_day1 < day1.size(), "seed %d: no_double_steppe holds (day1 gates=%s)" % [seed_value, str(day1)])
	var cards_a: Dictionary = SkeletonGen.deal_cards(cfg["archetypes"][2], gate_keys, ["S1", "S2"], _new_rng(99), cfg)
	var cards_b: Dictionary = SkeletonGen.deal_cards(cfg["archetypes"][2], gate_keys, ["S1", "S2"], _new_rng(99), cfg)
	_expect(str(cards_a) == str(cards_b), "deal_cards deterministic")
	# 风向：八向之一 + 决定性。
	var wind: Vector2i = SkeletonGen.roll_wind(_new_rng(5))
	_expect(wind != Vector2i.ZERO and absi(wind.x) <= 1 and absi(wind.y) <= 1, "wind is one of 8 compass dirs")
	_expect(SkeletonGen.roll_wind(_new_rng(5)) == wind, "roll_wind deterministic")


func _fixture_gate_cells() -> Array[Vector2i]:
	# 30×30 合成门位（角度互异、贴边、非角落）；S1..S5 = 下标+1。
	var gates: Array[Vector2i] = [Vector2i(15, 0), Vector2i(29, 9), Vector2i(24, 29), Vector2i(6, 29), Vector2i(0, 13)]
	return gates


func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _sector_component_ratio(sector_of: Dictionary, gate: Vector2i, key: String) -> float:
	var total: int = 0
	for raw_cell: Variant in sector_of.keys():
		if String(sector_of[raw_cell]) == key:
			total += 1
	var queue: Array[Vector2i] = [gate]
	var seen: Dictionary = {gate: true}
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var nb: Vector2i = current + direction
			if seen.has(nb) or not sector_of.has(nb):
				continue
			if String(sector_of[nb]) != key:
				continue
			seen[nb] = true
			queue.append(nb)
	return float(seen.size()) / float(maxi(total, 1))


func _test_sector_geometry() -> void:
	var cfg := _v2_cfg()
	var core := Vector2i(15, 15)
	var gates := _fixture_gate_cells()
	var sector_of: Dictionary = SkeletonGen.assign_sectors(30, 30, gates)
	_expect(sector_of.size() == 900, "every cell assigned a sector")
	for i in range(gates.size()):
		var key := "S%d" % (i + 1)
		_expect(String(sector_of.get(gates[i], "")) == key, "gate %s lies in own sector" % key)
		var ratio := _sector_component_ratio(sector_of, gates[i], key)
		_expect(ratio >= 0.95, "sector %s contiguous (gate component %.2f)" % [key, ratio])
	_expect(str(SkeletonGen.assign_sectors(30, 30, gates)) == str(sector_of), "assign_sectors deterministic")
	# 隘口锚：环带内 + 本扇区内 + 决定性。
	for seed_value in range(40):
		for i in range(gates.size()):
			for card_id in ["bastion", "steppe", "riverlands", "canyon"]:
				var card_cfg: Dictionary = cfg["sector_cards"][card_id]
				var anchor: Vector2i = SkeletonGen.place_pass_anchor(gates[i], core, card_cfg, _new_rng(seed_value * 100 + i))
				var ring: int = _cheb(anchor, core)
				var band: Array = card_cfg["pass_ring"]
				_expect(ring >= int(band[0]) and ring <= int(band[1]), "anchor ring %d in band %s (seed %d card %s)" % [ring, str(band), seed_value, card_id])
				_expect(String(sector_of.get(anchor, "")) == "S%d" % (i + 1), "anchor in own sector (seed %d gate %d card %s)" % [seed_value, i, card_id])
	var anchor_a: Vector2i = SkeletonGen.place_pass_anchor(gates[0], core, cfg["sector_cards"]["bastion"], _new_rng(3))
	var anchor_b: Vector2i = SkeletonGen.place_pass_anchor(gates[0], core, cfg["sector_cards"]["bastion"], _new_rng(3))
	_expect(anchor_a == anchor_b, "place_pass_anchor deterministic")
	# 汇流点：拓扑数量 + 环带 5-7 + 决定性。
	for seed_value in range(20):
		var none: Array[Dictionary] = SkeletonGen.place_confluences(cfg["archetypes"][0], gates, core, _new_rng(seed_value))
		_expect(none.is_empty(), "five_fingers has no confluence (seed %d)" % seed_value)
		var twin: Array[Dictionary] = SkeletonGen.place_confluences(cfg["archetypes"][1], gates, core, _new_rng(seed_value))
		_expect(twin.size() == 2, "twin_pincers has 2 confluences (seed %d)" % seed_value)
		var tri: Array[Dictionary] = SkeletonGen.place_confluences(cfg["archetypes"][2], gates, core, _new_rng(seed_value))
		_expect(tri.size() == 3, "trident has 3 confluences (seed %d)" % seed_value)
		for raw_conf: Variant in twin + tri:
			var conf: Dictionary = raw_conf
			var conf_ring: int = _cheb(conf.get("cell", core), core)
			_expect(conf_ring >= 5 and conf_ring <= 7, "confluence ring %d in [5,7] (seed %d)" % [conf_ring, seed_value])
			_expect((conf.get("gate_cells", []) as Array).size() >= 1, "confluence carries gate mapping (seed %d)" % seed_value)
	var twin_a: Array[Dictionary] = SkeletonGen.place_confluences(cfg["archetypes"][1], gates, core, _new_rng(11))
	var twin_b: Array[Dictionary] = SkeletonGen.place_confluences(cfg["archetypes"][1], gates, core, _new_rng(11))
	_expect(str(twin_a) == str(twin_b), "place_confluences deterministic")


func _finish() -> void:
	if _failures == 0:
		print("MAP GENERATION TESTS PASSED")
		quit(0)
	else:
		printerr("MAP GENERATION TESTS FAILED: %d" % _failures)
		quit(1)
