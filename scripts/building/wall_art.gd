extends RefCounted

## 程序化墙体贴图生成：木墙与人工高台（哨站）共用同一套"连接臂"几何与配色，
## 因此任意相邻组合在显示空间天然无缝。128×128 RGBA，硬边无半透明（NEAREST 缩放）。
## 绘制管线：足迹形状并集 → 向下挤出正面（伪 3/4 视角厚度）→ 边界描边 → 顶面纹样装饰。

const TEX := 128

# 连接臂横带（东西向）：顶面 y 带与正面挤出共享，决定与邻格的拼缝位置。
const ARM_TOP_Y0 := 42
const ARM_TOP_Y1 := 73
# 连接臂纵带（南北向）。
const ARM_X0 := 44
const ARM_X1 := 83
# 正面挤出深度（伪高度）。
const FRONT_WALL := 14
const FRONT_PLATFORM := 16

# 木墙中心块（比臂略外凸，形成桩位节奏）。
const CEN_X0 := 38
const CEN_Y0 := 36
const CEN_X1 := 89
const CEN_Y1 := 79

# 哨站甲板（石缘 + 木板台面）。
const DECK_X0 := 18
const DECK_Y0 := 16
const DECK_X1 := 109
const DECK_Y1 := 103
const DECK_RIM := 9

const COL_OUTLINE := Color8(54, 44, 38)
const COL_WOOD_A := Color8(221, 176, 116)
const COL_WOOD_B := Color8(202, 154, 95)
const COL_WOOD_C := Color8(180, 131, 76)
const COL_WOOD_SEAM := Color8(138, 103, 66)
const COL_WOOD_FRONT := Color8(118, 90, 64)
const COL_WOOD_FRONT_SEAM := Color8(92, 71, 58)
const COL_WOOD_SIDE := Color8(152, 118, 78)
# 金属包角（呼应生成建筑的铁件），冷灰偏蓝。
const COL_IRON := Color8(76, 78, 92)
const COL_IRON_LIGHT := Color8(136, 140, 156)
# 顶面光影（画风第 2 条：左上暖光、偏冷阴影）。
const LIGHT_EDGE_LIGHTEN := 0.12
const SHADE_EDGE_COLOR := Color(0.36, 0.36, 0.52)
const SHADE_EDGE_MIX := 0.22
const COL_DECK_A := Color8(214, 183, 136)
const COL_DECK_B := Color8(201, 169, 122)
const COL_DECK_SEAM := Color8(172, 142, 100)
const COL_STONE_LIGHT := Color8(182, 186, 189)
const COL_STONE_MID := Color8(152, 158, 163)
const COL_STONE_SEAM := Color8(124, 130, 136)
const COL_STONE_FRONT := Color8(98, 103, 109)
const COL_STONE_FRONT_SEAM := Color8(82, 87, 93)
const COL_POST := Color8(112, 90, 62)
const COL_POST_LIGHT := Color8(143, 116, 81)

const SUFFIX_TO_MASK := {
	"0000_isolated": 0,
	"0001_n": 1,
	"0010_e": 2,
	"0011_ne": 3,
	"0100_s": 4,
	"0101_ns": 5,
	"0110_es": 6,
	"0111_nes": 7,
	"1000_w": 8,
	"1001_nw": 9,
	"1010_ew": 10,
	"1011_new": 11,
	"1100_sw": 12,
	"1101_nsw": 13,
	"1110_esw": 14,
	"1111_nesw": 15,
}

static var _texture_cache: Dictionary = {}


## visual_key 形如 "wood_wall_0101_ns" / "artificial_platform_1111_nesw"。
## 非本模块负责的键返回 null（调用方回落文件贴图）。
static func texture_for_key(visual_key: String) -> Texture2D:
	var kind := StringName()
	var suffix := ""
	if visual_key.begins_with("wood_wall_"):
		kind = &"wood_wall"
		suffix = visual_key.substr(10)
	elif visual_key.begins_with("artificial_platform_"):
		kind = &"artificial_platform"
		suffix = visual_key.substr(20)
	else:
		return null
	if not SUFFIX_TO_MASK.has(suffix):
		return null
	if _texture_cache.has(visual_key):
		return _texture_cache[visual_key]
	var mask := int(SUFFIX_TO_MASK[suffix])
	var image := build_image(kind, mask)
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[visual_key] = texture
	return texture


static func build_image(kind: StringName, mask: int) -> Image:
	var is_platform := kind == &"artificial_platform"
	var shape := PackedByteArray()
	shape.resize(TEX * TEX)
	var cx0 := DECK_X0 if is_platform else CEN_X0
	var cy0 := DECK_Y0 if is_platform else CEN_Y0
	var cx1 := DECK_X1 if is_platform else CEN_X1
	var cy1 := DECK_Y1 if is_platform else CEN_Y1
	_mark_rect(shape, cx0, cy0, cx1, cy1)
	if mask & 1:
		_mark_rect(shape, ARM_X0, 0, ARM_X1, cy0)
	if mask & 4:
		_mark_rect(shape, ARM_X0, cy1, ARM_X1, TEX - 1)
	if mask & 2:
		_mark_rect(shape, cx1, ARM_TOP_Y0, TEX - 1, ARM_TOP_Y1)
	if mask & 8:
		_mark_rect(shape, 0, ARM_TOP_Y0, cx0, ARM_TOP_Y1)

	# 正面挤出：每列在形状下缘向下延伸，归属（木/石）取决于上缘像素属于臂还是甲板。
	var front := PackedByteArray()
	front.resize(TEX * TEX)
	for x: int in range(TEX):
		var y := 0
		while y < TEX:
			if shape[y * TEX + x] == 0:
				y += 1
				continue
			var run_end := y
			while run_end + 1 < TEX and shape[(run_end + 1) * TEX + x] == 1:
				run_end += 1
			if run_end < TEX - 1:
				var stone_owner := is_platform and _in_rect(x, run_end, DECK_X0, DECK_Y0, DECK_X1, DECK_Y1)
				var depth := FRONT_PLATFORM if stone_owner else FRONT_WALL
				var owner_flag := 2 if stone_owner else 1
				for fy: int in range(run_end + 1, mini(run_end + depth, TEX - 1) + 1):
					if shape[fy * TEX + x] == 1:
						break
					front[fy * TEX + x] = owner_flag
			y = run_end + 1

	var image := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	for y: int in range(TEX):
		for x: int in range(TEX):
			if shape[y * TEX + x] == 1:
				image.set_pixel(x, y, _top_color(is_platform, x, y, mask))
			elif front[y * TEX + x] == 1:
				image.set_pixel(x, y, _front_color_wood(x, y))
			elif front[y * TEX + x] == 2:
				image.set_pixel(x, y, _front_color_stone(x, y))
	_apply_top_light_pass(image, shape)
	if is_platform:
		_draw_corner_posts(image)
	else:
		_draw_corner_braces(image)
	_draw_outline(image, shape, front)
	return image


static func _mark_rect(shape: PackedByteArray, x0: int, y0: int, x1: int, y1: int) -> void:
	for y: int in range(maxi(y0, 0), mini(y1, TEX - 1) + 1):
		for x: int in range(maxi(x0, 0), mini(x1, TEX - 1) + 1):
			shape[y * TEX + x] = 1


static func _in_rect(x: int, y: int, x0: int, y0: int, x1: int, y1: int) -> bool:
	return x >= x0 and x <= x1 and y >= y0 and y <= y1


static func _hash(a: int, b: int, salt: int) -> int:
	var h := a * 374761393 + b * 668265263 + salt * 974711
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


static func _wood_shade(row: int, seg: int, salt: int) -> Color:
	var pick := _hash(row, seg, salt) % 3
	if pick == 0:
		return COL_WOOD_A
	if pick == 1:
		return COL_WOOD_B
	return COL_WOOD_C


## 木质顶面纹样：横带画横向板材（沿东西臂），纵带画纵向板材；板缝 + 错位对接缝。
static func _wood_top(x: int, y: int, horizontal: bool, salt: int) -> Color:
	if horizontal:
		var local := y - ARM_TOP_Y0
		var row := local / 8 if local >= 0 else (local - 7) / 8
		if local >= 0 and local % 8 == 7:
			return COL_WOOD_SEAM
		if (x + row * 11) % 26 == 0:
			return COL_WOOD_SEAM
		return _wood_shade(row, x / 16, salt)
	var local_x := x - ARM_X0
	var col := local_x / 8 if local_x >= 0 else (local_x - 7) / 8
	if local_x >= 0 and local_x % 8 == 7:
		return COL_WOOD_SEAM
	if (y + col * 11) % 26 == 0:
		return COL_WOOD_SEAM
	return _wood_shade(col, y / 16, salt + 7)


static func _top_color(is_platform: bool, x: int, y: int, mask: int) -> Color:
	if is_platform:
		return _platform_top_color(x, y, mask)
	# 中心块沿用横板纹样并整体压暗一档，读作桩位。
	if _in_rect(x, y, CEN_X0, CEN_Y0, CEN_X1, CEN_Y1):
		var base := _wood_top(x, y, true, 3)
		return base.darkened(0.06)
	if y >= ARM_TOP_Y0 and y <= ARM_TOP_Y1 and (x < CEN_X0 or x > CEN_X1):
		return _wood_top(x, y, true, 1)
	return _wood_top(x, y, false, 1)


static func _platform_top_color(x: int, y: int, mask: int) -> Color:
	if not _in_rect(x, y, DECK_X0, DECK_Y0, DECK_X1, DECK_Y1):
		# 甲板之外的连接臂：与木墙完全同款，保证拼缝。
		if y >= ARM_TOP_Y0 and y <= ARM_TOP_Y1 and (x < DECK_X0 or x > DECK_X1):
			return _wood_top(x, y, true, 1)
		return _wood_top(x, y, false, 1)
	var dist_left := x - DECK_X0
	var dist_right := DECK_X1 - x
	var dist_top := y - DECK_Y0
	var dist_bottom := DECK_Y1 - y
	var dist := mini(mini(dist_left, dist_right), mini(dist_top, dist_bottom))
	if dist < DECK_RIM:
		# 连接方向的缘口让位给木质通道（城门式开口）。
		var in_gate_ns := x >= ARM_X0 and x <= ARM_X1 and ((mask & 1 and dist == dist_top) or (mask & 4 and dist == dist_bottom))
		var in_gate_ew := y >= ARM_TOP_Y0 and y <= ARM_TOP_Y1 and ((mask & 2 and dist == dist_right) or (mask & 8 and dist == dist_left))
		if in_gate_ns or in_gate_ew:
			return _deck_plank(x, y)
		var along := x if (dist == dist_top or dist == dist_bottom) else y
		if dist < 5:
			# 外缘垛口节奏。
			return Color8(192, 196, 199) if (along / 10) % 2 == 0 else Color8(128, 134, 140)
		if _hash(along / 9, dist, 11) % 5 == 0:
			return COL_STONE_SEAM
		return COL_STONE_MID
	if dist <= DECK_RIM + 1:
		return COL_WOOD_SIDE
	return _deck_plank(x, y)


static func _deck_plank(x: int, y: int) -> Color:
	var row := (y - DECK_Y0) / 9
	if (y - DECK_Y0) % 9 == 8:
		return COL_DECK_SEAM
	if (x + row * 13) % 30 == 0:
		return COL_DECK_SEAM
	return COL_DECK_A if _hash(row, x / 18, 23) % 2 == 0 else COL_DECK_B


static func _front_color_wood(x: int, y: int) -> Color:
	if x % 8 == 7:
		return COL_WOOD_FRONT_SEAM
	return COL_WOOD_FRONT if _hash(x / 8, y / 8, 31) % 4 != 0 else COL_WOOD_FRONT_SEAM.lightened(0.06)


static func _front_color_stone(x: int, y: int) -> Color:
	if x % 10 == 9:
		return COL_STONE_FRONT_SEAM
	return COL_STONE_FRONT if _hash(x / 10, y / 6, 37) % 4 != 0 else COL_STONE_FRONT_SEAM


## 顶面左上受光、右缘偏冷背光（只作用于顶面形状，幅度克制保住板缝纹样）。
static func _apply_top_light_pass(image: Image, shape: PackedByteArray) -> void:
	for y: int in range(TEX):
		for x: int in range(TEX):
			if shape[y * TEX + x] != 1:
				continue
			var north_open := y < 2 or shape[(y - 2) * TEX + x] == 0
			var west_open := x < 2 or shape[y * TEX + (x - 2)] == 0
			var east_open := x > TEX - 3 or shape[y * TEX + (x + 2)] == 0
			var base := image.get_pixel(x, y)
			if north_open or west_open:
				image.set_pixel(x, y, base.lightened(LIGHT_EDGE_LIGHTEN))
			elif east_open:
				image.set_pixel(x, y, base.lerp(SHADE_EDGE_COLOR, SHADE_EDGE_MIX))


static func _draw_corner_posts(image: Image) -> void:
	var corners: Array[Vector2i] = [
		Vector2i(DECK_X0 + 3, DECK_Y0 + 3),
		Vector2i(DECK_X1 - 14, DECK_Y0 + 3),
		Vector2i(DECK_X0 + 3, DECK_Y1 - 14),
		Vector2i(DECK_X1 - 14, DECK_Y1 - 14),
	]
	for corner: Vector2i in corners:
		image.fill_rect(Rect2i(corner.x, corner.y, 12, 12), COL_POST)
		image.fill_rect(Rect2i(corner.x, corner.y, 12, 3), COL_IRON)
		image.fill_rect(Rect2i(corner.x, corner.y, 12, 1), COL_IRON_LIGHT)
		image.fill_rect(Rect2i(corner.x, corner.y + 3, 1, 9), COL_POST_LIGHT)


## 中心块四角铁质 L 形包角（替代旧版 3px 木桩点）。
static func _draw_corner_braces(image: Image) -> void:
	var arm := 9
	var thick := 3
	var specs: Array[Array] = [
		[Vector2i(CEN_X0 + 2, CEN_Y0 + 2), 1, 1],
		[Vector2i(CEN_X1 - 2, CEN_Y0 + 2), -1, 1],
		[Vector2i(CEN_X0 + 2, CEN_Y1 - 2), 1, -1],
		[Vector2i(CEN_X1 - 2, CEN_Y1 - 2), -1, -1],
	]
	for spec: Array in specs:
		var origin: Vector2i = spec[0]
		var sx := int(spec[1])
		var sy := int(spec[2])
		var h_rect := Rect2i(origin.x if sx > 0 else origin.x - arm + 1, origin.y if sy > 0 else origin.y - thick + 1, arm, thick)
		var v_rect := Rect2i(origin.x if sx > 0 else origin.x - thick + 1, origin.y if sy > 0 else origin.y - arm + 1, thick, arm)
		image.fill_rect(h_rect, COL_IRON)
		image.fill_rect(v_rect, COL_IRON)
		image.fill_rect(Rect2i(h_rect.position, Vector2i(h_rect.size.x, 1)), COL_IRON_LIGHT)
		image.fill_rect(Rect2i(v_rect.position, Vector2i(1, v_rect.size.y)), COL_IRON_LIGHT)


## 形状（顶面+正面）外侧 2px 描边；两轮 4 邻域膨胀。
static func _draw_outline(image: Image, shape: PackedByteArray, front: PackedByteArray) -> void:
	var solid := PackedByteArray()
	solid.resize(TEX * TEX)
	for i: int in range(TEX * TEX):
		solid[i] = 1 if (shape[i] == 1 or front[i] != 0) else 0
	var ring := _dilate_ring(solid)
	for i: int in range(TEX * TEX):
		if ring[i] == 1:
			solid[i] = 1
	var ring2 := _dilate_ring(solid)
	for y: int in range(TEX):
		for x: int in range(TEX):
			var i := y * TEX + x
			if ring[i] == 1 or ring2[i] == 1:
				image.set_pixel(x, y, COL_OUTLINE)


static func _dilate_ring(solid: PackedByteArray) -> PackedByteArray:
	var ring := PackedByteArray()
	ring.resize(TEX * TEX)
	for y: int in range(TEX):
		for x: int in range(TEX):
			var i := y * TEX + x
			if solid[i] == 1:
				continue
			var touches := false
			if x > 0 and solid[i - 1] == 1:
				touches = true
			elif x < TEX - 1 and solid[i + 1] == 1:
				touches = true
			elif y > 0 and solid[i - TEX] == 1:
				touches = true
			elif y < TEX - 1 and solid[i + TEX] == 1:
				touches = true
			if touches:
				ring[i] = 1
	return ring
