class_name EnemyFlowField
extends RefCounted

## 敌人共享距离场 + 纯单调下行（flow field 标准做法，纯静态、决定性）。
## - compute_distance：从核心四连通 BFS，跳过 blocked 与不可走格 → 每格"到核心步数"。
## - compute_front：每格的梯度方向 g（朝核心）与横向轴 axis（仅用于同代价分流排序）。
## - descend_step：每步只走 dist 严格更小的邻；多个并列时按个体相位在横向序上分流。
##   严格单调 ⇒ 必达核心、绝不成环/踱步（可证明终止）；铺开宽度交给"距离场种子"等旁路。
## 设计稿：docs/敌人地形正面推进与覆盖预览设计.md

const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


## 从 core 四连通 BFS，跳过 blocked 与不可走格。返回 {cell: int 步数}，不可达不入表。
static func compute_distance(cells: Dictionary, core: Vector2i, blocked: Dictionary) -> Dictionary:
	var dist: Dictionary = {}
	if not _passable(cells, blocked, core):
		return dist
	dist[core] = 0
	var queue: Array[Vector2i] = [core]
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var next_d: int = int(dist[current]) + 1
		for dir in CARDINALS:
			var nb: Vector2i = current + dir
			if dist.has(nb) or not _passable(cells, blocked, nb):
				continue
			dist[nb] = next_d
			queue.append(nb)
	return dist


## 每个有 dist 的格：梯度 g（朝 dist 最小邻、并列按 R,D,L,U）+ 横向轴 axis（g 的垂直方向）。
## g 供覆盖预览描中心线；axis 供 descend_step 做同代价分流的横向排序。
static func compute_front(_cells: Dictionary, dist: Dictionary, _blocked: Dictionary) -> Dictionary:
	var front: Dictionary = {}
	for cell_variant: Variant in dist.keys():
		var cell: Vector2i = cell_variant
		var g: Vector2i = _gradient(dist, cell)
		front[cell] = {"g": g, "axis": _lateral_axis(g)}
	return front


## 单只怪的下一步：只走 dist 严格更小的邻（绝不持平/上升 ⇒ 绝不踱步）；并列时按相位在
## 横向序上分流，让等长的平行路被均匀占满而非挤一列。extra_blocked 软避让（干员）：
## 优先未占的下行邻，若全被占（窄口）则照走进去接敌。
static func descend_step(dist: Dictionary, front: Dictionary, cell: Vector2i, phase: float, extra_blocked: Dictionary) -> Vector2i:
	if not dist.has(cell):
		return cell
	var cur_d: int = int(dist[cell])
	if cur_d == 0:
		return cell
	var axis: Vector2i = (front.get(cell, {}) as Dictionary).get("axis", Vector2i.ZERO)
	var opts: Array = []
	for dir in CARDINALS:
		var nb: Vector2i = cell + dir
		if not dist.has(nb) or int(dist[nb]) >= cur_d:
			continue
		var lat: int = 0
		if axis != Vector2i.ZERO:
			var delta: Vector2i = nb - cell
			lat = delta.x * axis.x + delta.y * axis.y
		opts.append({"cell": nb, "lat": lat, "blocked": bool(extra_blocked.get(nb, false))})
	if opts.is_empty():
		return cell
	var pool: Array = opts.filter(func(o): return not bool(o["blocked"]))
	if pool.is_empty():
		pool = opts
	pool.sort_custom(func(a, b):
		if int(a["lat"]) != int(b["lat"]):
			return int(a["lat"]) < int(b["lat"])
		var ca: Vector2i = a["cell"]
		var cb: Vector2i = b["cell"]
		if ca.y != cb.y:
			return ca.y < cb.y
		return ca.x < cb.x
	)
	var idx: int = clampi(int(clampf(phase, 0.0, 1.0) * float(pool.size())), 0, pool.size() - 1)
	return (pool[idx] as Dictionary)["cell"]


static func _passable(cells: Dictionary, blocked: Dictionary, cell: Vector2i) -> bool:
	if bool(blocked.get(cell, false)):
		return false
	var data = cells.get(cell, null)
	return data != null and bool(data.walkable)


## 朝 dist 最小的邻格方向；并列按 CARDINALS 序裁决；无更低邻（核心）返回 ZERO。
static func _gradient(dist: Dictionary, cell: Vector2i) -> Vector2i:
	var current_d: int = int(dist[cell])
	var best_dir: Vector2i = Vector2i.ZERO
	var best_d: int = current_d
	for dir in CARDINALS:
		var nb: Vector2i = cell + dir
		if not dist.has(nb):
			continue
		var nb_d: int = int(dist[nb])
		if nb_d < best_d:
			best_d = nb_d
			best_dir = dir
	return best_dir


## g 的垂直轴的"正"方向（g 水平→轴取 DOWN(+y)，g 竖直→轴取 RIGHT(+x)）；g 为零返回零。
static func _lateral_axis(g: Vector2i) -> Vector2i:
	if g.x != 0:
		return Vector2i.DOWN
	if g.y != 0:
		return Vector2i.RIGHT
	return Vector2i.ZERO
