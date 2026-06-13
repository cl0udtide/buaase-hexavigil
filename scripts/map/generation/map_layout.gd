class_name MapGenLayout
extends RefCounted

## Terrain-first 第二阶段：出怪口 + 连通（设计稿 S4 + S5 唯一硬底线）。
## 5 口均匀放在边缘、与地形无关；唯一保证 = 每口能走到核心（走不到就开凿）。
## 纯静态、决定性。

const CellDataRef = preload("res://scripts/map/cell_data.gd")

const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const CARVE_BLOCK_COST := 8       # 开凿穿过阻挡的代价（相对平原 1）


static func _is_blocking(t: StringName) -> bool:
	return t == CellDataRef.TERRAIN_MOUNTAIN or t == CellDataRef.TERRAIN_WATER or t == CellDataRef.TERRAIN_HIGHLAND


## 顺时针边缘环（去重角点）。
static func _perimeter_cells(width: int, height: int) -> Array[Vector2i]:
	var ring: Array[Vector2i] = []
	for x in range(width):
		ring.append(Vector2i(x, 0))
	for y in range(1, height):
		ring.append(Vector2i(width - 1, y))
	for x in range(width - 2, -1, -1):
		ring.append(Vector2i(x, height - 1))
	for y in range(height - 2, 0, -1):
		ring.append(Vector2i(0, y))
	return ring


## 5 口均匀放边缘（terrain-blind、决定性，不依赖种子/地形）。
static func place_gates(width: int, height: int, count: int) -> Array[Vector2i]:
	var ring: Array[Vector2i] = _perimeter_cells(width, height)
	var gates: Array[Vector2i] = []
	for i in range(count):
		gates.append(ring[(i * ring.size()) / count])
	return gates


## 唯一硬底线：每口能走到核心。口格强制平原；不可达则开凿一条路（穿阻挡代价高）。
## 直接改写 terrain（把口格与开凿路径设为平原）。
static func ensure_connectivity(terrain: Dictionary, _width: int, _height: int, core: Vector2i, gates: Array) -> void:
	for raw_g in gates:
		terrain[raw_g as Vector2i] = CellDataRef.TERRAIN_PLAIN
	for raw_g in gates:
		var g: Vector2i = raw_g
		if not _reachable(terrain, g, core):
			_carve(terrain, g, core)


## g 能否经非阻挡 4 连通走到 core。
static func _reachable(terrain: Dictionary, start: Vector2i, goal: Vector2i) -> bool:
	if _is_blocking(terrain.get(start, CellDataRef.TERRAIN_MOUNTAIN)):
		return false
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == goal:
			return true
		for d in CARDINALS:
			var nb: Vector2i = cur + d
			if seen.has(nb) or not terrain.has(nb):
				continue
			if _is_blocking(terrain.get(nb, CellDataRef.TERRAIN_MOUNTAIN)):
				continue
			seen[nb] = true
			queue.append(nb)
	return false


## 开凿：Dijkstra（平原 1 / 阻挡 CARVE_BLOCK_COST）找 g→core 最省路，路径全设平原。
## 线性扫描取最小（≤900 节点、罕触发，O(N²) 可接受）；决定性靠固定插入/邻序。
static func _carve(terrain: Dictionary, start: Vector2i, goal: Vector2i) -> void:
	var dist: Dictionary = {start: 0}
	var prev: Dictionary = {}
	var visited: Dictionary = {}
	while true:
		var best := Vector2i(-1, -1)
		var best_d: int = 1 << 30
		for raw_k in dist.keys():
			var k: Vector2i = raw_k
			if visited.has(k):
				continue
			if int(dist[k]) < best_d:
				best_d = int(dist[k])
				best = k
		if best.x < 0 or best == goal:
			break
		visited[best] = true
		for d in CARDINALS:
			var nb: Vector2i = best + d
			if not terrain.has(nb):
				continue
			var step: int = 1 if not _is_blocking(terrain.get(nb, CellDataRef.TERRAIN_MOUNTAIN)) else CARVE_BLOCK_COST
			var nd: int = best_d + step
			if not dist.has(nb) or nd < int(dist[nb]):
				dist[nb] = nd
				prev[nb] = best
	var cur: Vector2i = goal
	while cur != start:
		terrain[cur] = CellDataRef.TERRAIN_PLAIN
		if not prev.has(cur):
			break
		cur = prev[cur]
	terrain[start] = CellDataRef.TERRAIN_PLAIN
