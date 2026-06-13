class_name EnemyFlowField
extends RefCounted

## 敌人共享距离场 + 正面结构（纯静态、决定性）。
## - compute_distance：从核心四连通 BFS，跳过 blocked 与不可走格。
## - compute_front：每格梯度方向 g、局部正面宽度 width、横向比 frac。
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


## 每个有 dist 的格：梯度 g（朝 dist 最小邻、并列按 R,D,L,U）、局部正面宽度 width、横向比 frac、横向轴 axis。
static func compute_front(cells: Dictionary, dist: Dictionary, blocked: Dictionary) -> Dictionary:
	var front: Dictionary = {}
	for cell_variant: Variant in dist.keys():
		var cell: Vector2i = cell_variant
		var g: Vector2i = _gradient(dist, cell)
		var axis: Vector2i = _lateral_axis(g)
		var width: int = 1
		var frac: float = 0.0
		if axis != Vector2i.ZERO:
			var count_neg: int = _walk_axis(cells, blocked, cell, -axis)
			var count_pos: int = _walk_axis(cells, blocked, cell, axis)
			width = count_neg + count_pos + 1
			frac = float(count_neg) / float(width - 1) if width > 1 else 0.0
		front[cell] = {"g": g, "axis": axis, "width": width, "frac": frac}
	return front


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


## g 的垂直轴的"正"方向（约定：g 水平→轴取 DOWN(+y)，g 竖直→轴取 RIGHT(+x)）；g 为零返回零。
static func _lateral_axis(g: Vector2i) -> Vector2i:
	if g.x != 0:
		return Vector2i.DOWN
	if g.y != 0:
		return Vector2i.RIGHT
	return Vector2i.ZERO


## 从 cell 沿 dir 连续走可走且未 blocked 的格数（不含 cell 本身）。
static func _walk_axis(cells: Dictionary, blocked: Dictionary, cell: Vector2i, dir: Vector2i) -> int:
	var count: int = 0
	var probe: Vector2i = cell + dir
	while _passable(cells, blocked, probe):
		count += 1
		probe += dir
	return count
