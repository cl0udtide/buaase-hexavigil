class_name MapGenNatural
extends RefCounted

## 自然化修饰（设计稿 S5）：边缘侵蚀（哈希场 ~30% 啃噬 / ~15% 外溢）与
## CA 清渣（4 邻多数 1 轮 + 删 <3 格阻挡孤岛 + 填 <4 格不可达死口袋）。
## 决定性：决策全部来自 IntNoise.cell_hash 纯场 + (y,x) 扫描序，无 RNG。
## 回引 map_generator 静态助手用运行时 load（见计划「模块回引规则」）。

const IntNoise = preload("res://scripts/map/generation/int_noise.gd")

const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const NIBBLE_THRESHOLD := 30   # cell_hash % 100 < 30 → ~30% 啃噬
const SPILL_THRESHOLD := 15    # cell_hash % 100 < 15 → ~15% 外溢
const ISLAND_MIN := 3          # 孤岛阻挡组件 < 3 格删除
const POCKET_MIN := 4          # 不可达可走组件 < 4 格填充


static func _mg() -> GDScript:
	return load("res://scripts/map/map_generator.gd")


## 边缘侵蚀（§S5）：快照两阶段决策 + 统一应用。
## 啃噬（blocked→plain）直接写；外溢（plain→blocked）经 _try_apply 整批回滚。
## 台账 "erode"：requested = 啃噬+候补总数，applied = 实际改格，rolled_back = 回滚数。
static func erode_edges(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, seed_value: int, ledger: Dictionary) -> void:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var spawn_cells: Array[Vector2i] = []
	for raw_cell: Variant in (skeleton.get("spawn_cells", []) as Array):
		spawn_cells.append(raw_cell)
	var cfg: Dictionary = skeleton.get("cfg", {})
	# 快照：记录每格当前是否阻挡（用于外溢判断，不受本阶段写入影响）。
	var snap_blocked: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var data: CellData = cells.get(cell) as CellData
			if data != null and not data.walkable:
				snap_blocked[cell] = data.terrain
	# 决策阶段（(y,x) 序）：收集啃噬列表和外溢候补（按地形分桶）。
	var nibble_list: Array[Vector2i] = []
	var spill_mountain: Array[Vector2i] = []
	var spill_water: Array[Vector2i] = []
	var spill_seed2: int = IntNoise.squirrel3(1, seed_value)
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var data: CellData = cells.get(cell) as CellData
			if data == null:
				continue
			if not data.walkable:
				# 啃噬候选：阻挡格、≥1 个 4 邻可走（快照中不是阻挡）、非 protected（防御性）。
				if protected.has(cell):
					continue
				var has_walkable_nb := false
				for direction in CARDINALS:
					var nb: Vector2i = cell + direction
					if cells.has(nb) and not snap_blocked.has(nb):
						has_walkable_nb = true
						break
				if not has_walkable_nb:
					continue
				if IntNoise.cell_hash(x, y, seed_value) % 100 < NIBBLE_THRESHOLD:
					nibble_list.append(cell)
			else:
				# 外溢候选：可走格、非 protected、无资源/口/核心、≥1 个 4 邻快照阻挡。
				if protected.has(cell):
					continue
				if data.resource_type != StringName() or data.spawn_key != StringName() or data.is_core:
					continue
				var has_blocked_nb := false
				for direction in CARDINALS:
					var nb: Vector2i = cell + direction
					if snap_blocked.has(nb):
						has_blocked_nb = true
						break
				if not has_blocked_nb:
					continue
				if IntNoise.cell_hash(x, y, spill_seed2) % 100 < SPILL_THRESHOLD:
					# 地形取快照 4 邻阻挡多数（山/水平票取山）。
					var mountain_nb: int = 0
					var water_nb: int = 0
					for direction in CARDINALS:
						var nb: Vector2i = cell + direction
						if snap_blocked.has(nb):
							var nb_terrain: StringName = snap_blocked[nb]
							if nb_terrain == CellData.TERRAIN_MOUNTAIN:
								mountain_nb += 1
							else:
								water_nb += 1
					if water_nb > mountain_nb:
						spill_water.append(cell)
					else:
						spill_mountain.append(cell)
	# 应用阶段：啃噬直接写（连通安全），外溢经 _try_apply（整批回滚）。
	var nibble_applied: int = 0
	for cell in nibble_list:
		var data: CellData = cells.get(cell) as CellData
		if data != null and not protected.has(cell):
			data.set_base_terrain(CellData.TERRAIN_PLAIN)
			nibble_applied += 1
	var spill_applied: int = 0
	var spill_rolledback: int = 0
	if not spill_mountain.is_empty():
		var applied_m: int = _mg()._try_apply_obstacle_cells(cells, spill_mountain, CellData.TERRAIN_MOUNTAIN, width, height, spawn_cells, core, cfg)
		spill_applied += applied_m
		if applied_m == 0:
			spill_rolledback += spill_mountain.size()
	if not spill_water.is_empty():
		var applied_w: int = _mg()._try_apply_obstacle_cells(cells, spill_water, CellData.TERRAIN_WATER, width, height, spawn_cells, core, cfg)
		spill_applied += applied_w
		if applied_w == 0:
			spill_rolledback += spill_water.size()
	# 台账：requested = nibble_list + spill candidates，applied = 实际改格。
	var total_requested: int = nibble_list.size() + spill_mountain.size() + spill_water.size()
	var total_applied: int = nibble_applied + spill_applied
	MapGenFlesh.ledger_note(ledger, "erode", total_requested, total_applied, spill_rolledback)


## CA 清渣（§S5）：顺序固定四步。台账 "cleanup"。
## 不变式：protected 格 terrain 永不改写；5 口连通保持。
static func cellular_cleanup(cells: Dictionary, skeleton: Dictionary, protected: Dictionary, ledger: Dictionary) -> void:
	var width: int = int(skeleton.get("width", 30))
	var height: int = int(skeleton.get("height", 30))
	var core: Vector2i = skeleton.get("core", Vector2i.ZERO)
	var spawn_cells: Array[Vector2i] = []
	for raw_cell: Variant in (skeleton.get("spawn_cells", []) as Array):
		spawn_cells.append(raw_cell)
	var cfg: Dictionary = skeleton.get("cfg", {})
	var cleanup_requested: int = 0
	var cleanup_applied: int = 0
	var cleanup_rolledback: int = 0
	# 步 1：4 邻多数轮（快照）。
	var snap_walkable: Dictionary = {}
	var snap_terrain: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var data: CellData = cells.get(cell) as CellData
			if data != null:
				snap_walkable[cell] = data.walkable
				snap_terrain[cell] = data.terrain
	var to_plain: Array[Vector2i] = []
	var to_blocked_mountain: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			if protected.has(cell):
				continue
			var data: CellData = cells.get(cell) as CellData
			if data == null:
				continue
			if data.resource_type != StringName() or data.spawn_key != StringName() or data.is_core:
				continue
			var n_blocked: int = 0
			var mountain_nb: int = 0
			var water_nb: int = 0
			for direction in CARDINALS:
				var nb: Vector2i = cell + direction
				if not cells.has(nb):
					continue
				if not bool(snap_walkable.get(nb, true)):
					n_blocked += 1
					var nb_terrain: StringName = snap_terrain.get(nb, CellData.TERRAIN_PLAIN)
					if nb_terrain == CellData.TERRAIN_MOUNTAIN:
						mountain_nb += 1
					elif nb_terrain == CellData.TERRAIN_WATER:
						water_nb += 1
			if bool(snap_walkable.get(cell, true)) and n_blocked >= 3:
				# 转阻挡：多数地形（平票取山）。
				to_blocked_mountain.append(cell)
			elif not bool(snap_walkable.get(cell, true)) and n_blocked <= 1:
				# 直接还原 plain（n≤1 邻阻挡，孤单格，安全）。
				to_plain.append(cell)
	for cell in to_plain:
		var data: CellData = cells.get(cell) as CellData
		if data != null and not protected.has(cell):
			data.set_base_terrain(CellData.TERRAIN_PLAIN)
			cleanup_applied += 1
	cleanup_requested += to_plain.size() + to_blocked_mountain.size()
	if not to_blocked_mountain.is_empty():
		var applied_b: int = _mg()._try_apply_obstacle_cells(cells, to_blocked_mountain, CellData.TERRAIN_MOUNTAIN, width, height, spawn_cells, core, cfg)
		cleanup_applied += applied_b
		if applied_b == 0:
			cleanup_rolledback += to_blocked_mountain.size()
	# 步 2：孤岛删除（阻挡组件 < ISLAND_MIN 格）。
	var island_applied: int = _delete_small_blocked_islands(cells, protected, ISLAND_MIN)
	cleanup_requested += island_applied
	cleanup_applied += island_applied
	# 步 3：死口袋填充（可走组件，不含 core/spawn，< POCKET_MIN 格）。
	var pocket_result := _fill_dead_pockets(cells, protected, skeleton, width, height, spawn_cells, core, cfg, POCKET_MIN)
	cleanup_requested += pocket_result[0]
	cleanup_applied += pocket_result[1]
	# 步 4：再扫孤岛（步 3 可能制造新邻接）。
	var island2_applied: int = _delete_small_blocked_islands(cells, protected, ISLAND_MIN)
	cleanup_requested += island2_applied
	cleanup_applied += island2_applied
	MapGenFlesh.ledger_note(ledger, "cleanup", cleanup_requested, cleanup_applied, cleanup_rolledback)


## 删除 size < min_size 的阻挡 4 连通组件（直接 plain，连通安全）。返回改格数。
static func _delete_small_blocked_islands(cells: Dictionary, protected: Dictionary, min_size: int) -> int:
	var seen: Dictionary = {}
	var total_deleted: int = 0
	for raw_cell: Variant in cells.keys():
		var cell: Vector2i = raw_cell
		if seen.has(cell):
			continue
		var data: CellData = cells.get(cell) as CellData
		if data == null or data.walkable:
			continue
		# BFS 收集组件。
		var component: Array[Vector2i] = [cell]
		seen[cell] = true
		var head: int = 0
		while head < component.size():
			var current: Vector2i = component[head]
			head += 1
			for direction in CARDINALS:
				var nb: Vector2i = current + direction
				if seen.has(nb) or not cells.has(nb):
					continue
				var nb_data: CellData = cells.get(nb) as CellData
				if nb_data == null or nb_data.walkable:
					continue
				seen[nb] = true
				component.append(nb)
		if component.size() < min_size:
			for comp_cell in component:
				var comp_data: CellData = cells.get(comp_cell) as CellData
				if comp_data != null and not protected.has(comp_cell):
					comp_data.set_base_terrain(CellData.TERRAIN_PLAIN)
					total_deleted += 1
	return total_deleted


## 填充死口袋：可走 4 连通组件，不含 core、不含 spawn 格，size < min_size → 填山。
## 防御性验证连通性，失败则还原并 push_warning。返回 [requested, applied]。
static func _fill_dead_pockets(cells: Dictionary, protected: Dictionary, skeleton: Dictionary, width: int, height: int, spawn_cells: Array[Vector2i], core: Vector2i, cfg: Dictionary, min_size: int) -> Array[int]:
	var spawn_lookup: Dictionary = {}
	for sp_cell in spawn_cells:
		spawn_lookup[sp_cell] = true
	var seen: Dictionary = {}
	var total_requested: int = 0
	var total_applied: int = 0
	for raw_cell: Variant in cells.keys():
		var cell: Vector2i = raw_cell
		if seen.has(cell):
			continue
		var data: CellData = cells.get(cell) as CellData
		if data == null or not data.walkable:
			continue
		# BFS 收集可走组件（4 连通）。
		var component: Array[Vector2i] = [cell]
		seen[cell] = true
		var has_core := (cell == core)
		var has_spawn := spawn_lookup.has(cell)
		var head: int = 0
		while head < component.size():
			var current: Vector2i = component[head]
			head += 1
			for direction in CARDINALS:
				var nb: Vector2i = current + direction
				if seen.has(nb) or not cells.has(nb):
					continue
				var nb_data: CellData = cells.get(nb) as CellData
				if nb_data == null or not nb_data.walkable:
					continue
				seen[nb] = true
				component.append(nb)
				if nb == core:
					has_core = true
				if spawn_lookup.has(nb):
					has_spawn = true
		# 跳过含 core 或 spawn 格的组件。
		if has_core or has_spawn:
			continue
		if component.size() >= min_size:
			continue
		# 填充为山：不经 _try_apply（不可达区域，门→核连通不受影响）。
		total_requested += component.size()
		var painted: Array[Vector2i] = []
		for comp_cell in component:
			var comp_data: CellData = cells.get(comp_cell) as CellData
			if comp_data != null and not protected.has(comp_cell):
				comp_data.set_base_terrain(CellData.TERRAIN_MOUNTAIN)
				painted.append(comp_cell)
		# 防御性连通验证。
		if not _mg()._are_all_spawns_connected(cells, width, height, spawn_cells, core):
			push_warning("MapGenNatural: pocket fill broke connectivity (size=%d) — reverting" % painted.size())
			for painted_cell in painted:
				var pd: CellData = cells.get(painted_cell) as CellData
				if pd != null:
					pd.set_base_terrain(CellData.TERRAIN_PLAIN)
		else:
			total_applied += painted.size()
	return [total_requested, total_applied]


const MapGenFlesh = preload("res://scripts/map/generation/flesh.gd")
