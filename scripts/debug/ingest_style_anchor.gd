extends SceneTree

## 资产入库（非测试）：风格锚源图 → tile_plain / tile_plain_alt / tile_mountain / lumber_station。
## 按洋红空隙自动分割三个资产；地块裁内缩方块缩到 256，平地旋转 180° 派生 alt；
## 建筑抠洋红装入 128 画布（底部居中锚点）。运行后需 `--headless --import`。

const SRC := "res://assets/map/CommandMap/raw/style_anchor_sheet.png"
const TILE_SIZE := 256
const BUILDING_CANVAS := 128
const BUILDING_MAX := 116
const BUILDING_BOTTOM := 122
# 地块调色（画风第 3 条：地表最沉）：压明度、降饱和、色相微偏绿去黄。
const TILE_VALUE_MUL := 0.8
const TILE_SAT_MUL := 0.72
const TILE_HUE_SHIFT := 0.03


func _init() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if sheet == null:
		printerr("missing source: %s" % SRC)
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var spans := _split_columns(sheet)
	print("components: %d -> %s" % [spans.size(), str(spans)])
	if spans.size() != 3:
		printerr("expect 3 components")
		quit(1)
		return
	var failures := 0
	failures += _save_tile(_crop_component(sheet, spans[0]), "tile_plain", false)
	failures += _save_tile(_crop_component(sheet, spans[0]), "tile_plain_alt", true)
	failures += _save_tile(_crop_component(sheet, spans[1]), "tile_mountain", false)
	failures += _save_building(_crop_component(sheet, spans[2]), "lumber_station")
	quit(0 if failures == 0 else 1)


static func _is_key(c: Color) -> bool:
	return c.r8 > 180 and c.b8 > 180 and c.g8 < 120 and (c.r8 - c.g8) > 80 and (c.b8 - c.g8) > 80


## 按"整列全为洋红"分割横向组件，返回 [x0, x1] 列表。
static func _split_columns(img: Image) -> Array[Vector2i]:
	var spans: Array[Vector2i] = []
	var start := -1
	for x: int in range(img.get_width()):
		var occupied := false
		for y: int in range(0, img.get_height(), 2):
			if not _is_key(img.get_pixel(x, y)):
				occupied = true
				break
		if occupied and start < 0:
			start = x
		elif not occupied and start >= 0:
			if x - start > 32:
				spans.append(Vector2i(start, x - 1))
			start = -1
	if start >= 0:
		spans.append(Vector2i(start, img.get_width() - 1))
	return spans


static func _crop_component(img: Image, span: Vector2i) -> Image:
	var y0 := img.get_height()
	var y1 := 0
	for y: int in range(img.get_height()):
		for x: int in range(span.x, span.y + 1, 2):
			if not _is_key(img.get_pixel(x, y)):
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
				break
	return img.get_region(Rect2i(span.x, y0, span.y - span.x + 1, y1 - y0 + 1))


static func _save_tile(comp: Image, key: String, rotate: bool) -> int:
	# 内缩去洋红毛边，取中心正方形。
	var inset := 4
	var side := mini(comp.get_width(), comp.get_height()) - inset * 2
	var sq := comp.get_region(Rect2i((comp.get_width() - side) / 2, (comp.get_height() - side) / 2, side, side))
	sq.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_LANCZOS)
	if rotate:
		sq.rotate_180()
	# 地块必须完整不透明 + 统一调色。
	for y: int in range(TILE_SIZE):
		for x: int in range(TILE_SIZE):
			var c := sq.get_pixel(x, y)
			var toned := Color.from_hsv(fposmod(c.h + TILE_HUE_SHIFT, 1.0), clampf(c.s * TILE_SAT_MUL, 0.0, 1.0), clampf(c.v * TILE_VALUE_MUL, 0.0, 1.0))
			toned.a = 1.0
			sq.set_pixel(x, y, toned)
	var dst := "res://assets/map/CommandMap/%s.png" % key
	var err := sq.save_png(ProjectSettings.globalize_path(dst))
	print("%s -> err=%d" % [dst, err])
	return 0 if err == OK else 1


static func _save_building(comp: Image, key: String) -> int:
	for y: int in range(comp.get_height()):
		for x: int in range(comp.get_width()):
			if _is_key(comp.get_pixel(x, y)):
				comp.set_pixel(x, y, Color(0, 0, 0, 0))
	var used := comp.get_used_rect()
	var body := comp.get_region(used)
	var scale := minf(float(BUILDING_MAX) / body.get_width(), float(BUILDING_MAX) / body.get_height())
	var w := int(round(body.get_width() * scale))
	var h := int(round(body.get_height() * scale))
	body.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(BUILDING_CANVAS, BUILDING_CANVAS, false, Image.FORMAT_RGBA8)
	canvas.blend_rect(body, Rect2i(0, 0, w, h), Vector2i((BUILDING_CANVAS - w) / 2, BUILDING_BOTTOM - h))
	var dst := "res://assets/sprites/buildings/%s.png" % key
	var err := canvas.save_png(ProjectSettings.globalize_path(dst))
	print("%s -> err=%d (%dx%d)" % [dst, err, w, h])
	return 0 if err == OK else 1
