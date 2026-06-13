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


const LATERAL_SLACK := 1
const SCORE_INF := 1_000_000_000


## 单只怪的下一步格：沿梯度前进 + 朝相位槽位横向铺开 + 避让 extra_blocked（占用格）。
## 纯函数，输入已算好的 dist/front。无可走则返回原格。
static func next_step(dist: Dictionary, front: Dictionary, cell: Vector2i, phase: float, half_width: int, extra_blocked: Dictionary) -> Vector2i:
	var f: Dictionary = front.get(cell, {})
	if f.is_empty():
		return cell
	var g: Vector2i = f.get("g", Vector2i.ZERO)
	if g == Vector2i.ZERO:
		return cell  # 已在核心
	var width: int = int(f.get("width", 1))
	var axis: Vector2i = f.get("axis", Vector2i.ZERO)
	var cur_d: int = int(dist.get(cell, 0))
	var cur_index: int = int(round(float(f.get("frac", 0.0)) * float(max(width - 1, 1))))
	var desired_index: int = _desired_index(width, phase, half_width)
	var fwd: Vector2i = cell + g
	var fwd_ok: bool = _can_enter(dist, extra_blocked, fwd) and int(dist[fwd]) < cur_d
	# 1) 前进可行时，先按相位"向外"铺开（slack 内允许 dist 略升，否则开阔地无法铺开）。
	#    只许远离正面中心、不许向内拽回——回中心交给梯度漏斗，避免近核心来回震荡。
	if fwd_ok and axis != Vector2i.ZERO and cur_index != desired_index:
		var step_sign: int = 1 if desired_index > cur_index else -1
		var new_index: int = cur_index + step_sign
		var center: float = float(width - 1) * 0.5
		if absf(float(new_index) - center) >= absf(float(cur_index) - center) - 0.001:
			var lat_dir: Vector2i = axis if step_sign > 0 else -axis
			var lat_cell: Vector2i = cell + lat_dir
			if _can_enter(dist, extra_blocked, lat_cell) and int(dist[lat_cell]) <= cur_d + LATERAL_SLACK:
				return lat_cell
	# 2) 前进（严格降 dist）
	if fwd_ok:
		return fwd
	# 3) 前进格被占 → 垂直绕行：只看横向邻（垂直于前进向），避免把"后退"误判成绕行。
	#    开阔有横向空位即绕过一个干员；窄口无横向空位则落到第 5 步。
	if axis != Vector2i.ZERO:
		var around: Vector2i = Vector2i.ZERO
		var around_d: int = SCORE_INF
		for lat_dir2: Vector2i in [axis, -axis]:
			var nb: Vector2i = cell + lat_dir2
			if _can_enter(dist, extra_blocked, nb) and int(dist[nb]) <= cur_d + LATERAL_SLACK and int(dist[nb]) < around_d:
				around = nb
				around_d = int(dist[nb])
		if around_d < SCORE_INF:
			return around
	# 4) 任一 dist 更低的未占邻（一般绕行兜底）
	for dir in CARDINALS:
		var nb2: Vector2i = cell + dir
		if _can_enter(dist, extra_blocked, nb2) and int(dist[nb2]) < cur_d:
			return nb2
	# 5) 窄口无绕行余地：忽略 extra_blocked 照走梯度前进格（走进干员接敌，由阻挡半径拦下）。
	#    extra_blocked 因此是"能绕就绕"的软避让，而非硬墙——避免怪卡在前一格够不到阻挡半径而死锁。
	if dist.has(fwd) and int(dist[fwd]) < cur_d:
		return fwd
	return cell


static func _can_enter(dist: Dictionary, extra_blocked: Dictionary, cell: Vector2i) -> bool:
	return dist.has(cell) and not bool(extra_blocked.get(cell, false))


## 相位 [0,1) → 该正面内的目标横向 index；half_width 封顶展开幅度。
static func _desired_index(width: int, phase: float, half_width: int) -> int:
	if width <= 1:
		return 0
	var center: float = float(width - 1) * 0.5
	var spread: float = min(float(width - 1), float(2 * max(half_width, 0)))
	var idx: float = center + (clampf(phase, 0.0, 1.0) - 0.5) * spread
	return clampi(int(round(idx)), 0, width - 1)


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
