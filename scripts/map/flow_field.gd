class_name EnemyFlowField
extends RefCounted

## 敌人共享距离场 + 纯单调下行（flow field 标准做法，纯静态、决定性）。
## - compute_distance：从核心四连通 BFS，跳过 blocked 与不可走格 → 每格"到核心步数"。
## - compute_front：每格的梯度方向 g（朝核心）与横向轴 axis（用于同代价分流排序）。
## - descend_choices：列出某格所有真实可选的下行邻，供移动与路径预览共用。
## - descend_step：每步只走 dist 严格更小的邻；多个并列时按个体相位在横向序上分流。
##   严格单调 ⇒ 必达核心、绝不成环/踱步（可证明终止）；铺开宽度交给"距离场种子"等旁路。

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
## axis 供同代价分流排序；g 保留给调试与兼容调用。
static func compute_front(_cells: Dictionary, dist: Dictionary, _blocked: Dictionary) -> Dictionary:
	var front: Dictionary = {}
	for cell_variant: Variant in dist.keys():
		var cell: Vector2i = cell_variant
		var g: Vector2i = _gradient(dist, cell)
		front[cell] = {"g": g, "axis": _lateral_axis(g)}
	return front


## 某格的真实下行候选：只包含 dist 严格更小的邻；extra_blocked 为软避让。
## 值可用 bool 或 int 表示避让等级：0/false=不避让，1=干员等软阻挡，2=墙等更不优先目标。
## 总是选择避让等级最低的一组候选；若全被同级软阻挡，则保留全部，允许窄口接敌/拆墙。
static func descend_choices(dist: Dictionary, front: Dictionary, cell: Vector2i, extra_blocked: Dictionary) -> Array[Vector2i]:
	if not dist.has(cell):
		return []
	var cur_d: int = int(dist[cell])
	if cur_d == 0:
		return []
	var axis: Vector2i = (front.get(cell, {}) as Dictionary).get("axis", Vector2i.ZERO)
	var opts: Array[Dictionary] = []
	for dir in CARDINALS:
		var nb: Vector2i = cell + dir
		if not dist.has(nb) or int(dist[nb]) >= cur_d:
			continue
		var lat: int = 0
		if axis != Vector2i.ZERO:
			var delta: Vector2i = nb - cell
			lat = delta.x * axis.x + delta.y * axis.y
		opts.append({"cell": nb, "lat": lat, "block_score": _soft_block_score(extra_blocked, nb)})
	if opts.is_empty():
		return []
	var best_block_score := 1_000_000_000
	for opt: Dictionary in opts:
		best_block_score = mini(best_block_score, int(opt["block_score"]))
	var pool: Array[Dictionary] = []
	for opt: Dictionary in opts:
		if int(opt["block_score"]) == best_block_score:
			pool.append(opt)
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["lat"]) != int(b["lat"]):
			return int(a["lat"]) < int(b["lat"])
		var ca: Vector2i = a["cell"]
		var cb: Vector2i = b["cell"]
		if ca.y != cb.y:
			return ca.y < cb.y
		return ca.x < cb.x
	)
	var cells: Array[Vector2i] = []
	for item: Dictionary in pool:
		var choice_cell: Vector2i = item["cell"]
		cells.append(choice_cell)
	return cells


## 单只怪的下一步：只走 dist 严格更小的邻（绝不持平/上升 ⇒ 绝不踱步）；并列时按相位在
## 横向序上分流，让等长的平行路被均匀占满而非挤一列。
static func descend_step(dist: Dictionary, front: Dictionary, cell: Vector2i, phase: float, extra_blocked: Dictionary) -> Vector2i:
	var pool: Array[Vector2i] = descend_choices(dist, front, cell, extra_blocked)
	if pool.is_empty():
		return cell
	var idx: int = clampi(int(clampf(phase, 0.0, 1.0) * float(pool.size())), 0, pool.size() - 1)
	return pool[idx]


static func _soft_block_score(extra_blocked: Dictionary, cell: Vector2i) -> int:
	if not extra_blocked.has(cell):
		return 0
	var value: Variant = extra_blocked.get(cell)
	if typeof(value) == TYPE_BOOL:
		return 1 if bool(value) else 0
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return maxi(int(value), 0)
	return 1


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
