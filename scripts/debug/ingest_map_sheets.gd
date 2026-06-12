extends SceneTree

## 资产入库（非测试）：raw/ 下六轮生成源图 → 全量地块与建筑贴图。
## 按洋红空隙自动分割资产；地块裁内缩方块缩到 256 并统一调色；
## 建筑抠洋红装入 128 画布（底部居中锚点），标记 merge_building_parts 的轮次
## 把地块之后的全部组件视为同一建筑的部件，底对齐合成。运行后需 `--headless --import`。

const RAW := "res://assets/map/CommandMap/raw/"
const TILE_DIR := "res://assets/map/CommandMap/"
const BUILDING_DIR := "res://assets/sprites/buildings/"
const TILE_SIZE := 256
const BUILDING_CANVAS := 128
const BUILDING_MAX := 116
const BUILDING_BOTTOM := 122
# 地块调色（画风第 3 条：地表最沉）：压明度、降饱和、色相微偏绿去黄。
const TILE_VALUE_MUL := 0.8
const TILE_SAT_MUL := 0.72
const TILE_HUE_SHIFT := 0.03
# core_structure 是核心 sprite，与地块同目录（core_view.gd 加载）。
const CORE_KEYS: Array[String] = ["core_structure"]

const ROUNDS: Array[Dictionary] = [
	{
		"src": "style_anchor_sheet.png",
		"tiles": ["tile_plain", "tile_mountain"],
		"buildings": ["lumber_station"],
		"merge_building_parts": true,
	},
	{"src": "map_source_sheet_01_terrain.png", "tiles": ["tile_plain_alt", "tile_hidden", "tile_water"]},
	{"src": "map_source_sheet_02_feature_points.png", "tiles": ["tile_spawn", "tile_resource_wood", "tile_resource_stone", "tile_resource_mana"]},
	{"src": "map_source_sheet_03_highland_ford.png", "tiles": ["tile_highland", "tile_ford"]},
	{"src": "map_source_sheet_04_buildings.png", "buildings": ["stone_quarry", "mana_extractor", "medical_station", "gravity_tower", "inspiring_monolith", "core_structure"]},
	{"src": "map_source_sheet_05_buildings.png", "buildings": ["war_shrine_inactive", "war_shrine_active", "generic_destroyed_building"]},
]


func _init() -> void:
	var failures := 0
	for round_cfg: Dictionary in ROUNDS:
		failures += _ingest_round(round_cfg)
	quit(0 if failures == 0 else 1)


func _ingest_round(round_cfg: Dictionary) -> int:
	var src := RAW + String(round_cfg["src"])
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(src))
	if sheet == null:
		printerr("missing source: %s" % src)
		return 1
	sheet.convert(Image.FORMAT_RGBA8)
	var spans := _split_columns(sheet)
	var tiles: Array = round_cfg.get("tiles", [])
	var buildings: Array = round_cfg.get("buildings", [])
	var merge := bool(round_cfg.get("merge_building_parts", false))
	print("%s: %d components" % [String(round_cfg["src"]), spans.size()])
	var expected := tiles.size() + buildings.size()
	if (merge and spans.size() < expected) or (not merge and spans.size() != expected):
		printerr("  expect %s%d components, got %d" % [">=" if merge else "", expected, spans.size()])
		return 1
	var failures := 0
	for i: int in range(tiles.size()):
		failures += _save_tile(_crop_component(sheet, spans[i]), String(tiles[i]))
	if buildings.is_empty():
		return failures
	if merge:
		var parts: Array[Image] = []
		for i: int in range(tiles.size(), spans.size()):
			parts.append(_crop_component(sheet, spans[i]))
		failures += _save_building(parts, String(buildings[0]))
	else:
		for i: int in range(buildings.size()):
			var comp := _crop_component(sheet, spans[tiles.size() + i])
			failures += _save_building([comp], String(buildings[i]))
	return failures


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


static func _save_tile(comp: Image, key: String) -> int:
	# 内缩去洋红毛边，取中心正方形。
	var inset := 4
	var side := mini(comp.get_width(), comp.get_height()) - inset * 2
	var sq := comp.get_region(Rect2i((comp.get_width() - side) / 2, (comp.get_height() - side) / 2, side, side))
	sq.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_LANCZOS)
	# 地块必须完整不透明 + 统一调色。
	for y: int in range(TILE_SIZE):
		for x: int in range(TILE_SIZE):
			var c := sq.get_pixel(x, y)
			var toned := Color.from_hsv(fposmod(c.h + TILE_HUE_SHIFT, 1.0), clampf(c.s * TILE_SAT_MUL, 0.0, 1.0), clampf(c.v * TILE_VALUE_MUL, 0.0, 1.0))
			toned.a = 1.0
			sq.set_pixel(x, y, toned)
	var dst := TILE_DIR + key + ".png"
	var err := sq.save_png(ProjectSettings.globalize_path(dst))
	print("  %s -> err=%d" % [dst, err])
	return 0 if err == OK else 1


## 多个部件（如主棚+两侧原木捆）按源图顺序底对齐拼成一个建筑体。
static func _save_building(parts: Array[Image], key: String) -> int:
	const PART_GAP := 6
	var bodies: Array[Image] = []
	var total_w := 0
	var max_h := 0
	for comp: Image in parts:
		for y: int in range(comp.get_height()):
			for x: int in range(comp.get_width()):
				if _is_key(comp.get_pixel(x, y)):
					comp.set_pixel(x, y, Color(0, 0, 0, 0))
		var body := comp.get_region(comp.get_used_rect())
		bodies.append(body)
		total_w += body.get_width()
		max_h = maxi(max_h, body.get_height())
	total_w += PART_GAP * (bodies.size() - 1)
	var merged := Image.create(total_w, max_h, false, Image.FORMAT_RGBA8)
	var cursor_x := 0
	for body: Image in bodies:
		var rect := Rect2i(0, 0, body.get_width(), body.get_height())
		merged.blend_rect(body, rect, Vector2i(cursor_x, max_h - body.get_height()))
		cursor_x += body.get_width() + PART_GAP
	var scale := minf(float(BUILDING_MAX) / merged.get_width(), float(BUILDING_MAX) / merged.get_height())
	var w := int(round(merged.get_width() * scale))
	var h := int(round(merged.get_height() * scale))
	merged.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(BUILDING_CANVAS, BUILDING_CANVAS, false, Image.FORMAT_RGBA8)
	canvas.blend_rect(merged, Rect2i(0, 0, w, h), Vector2i((BUILDING_CANVAS - w) / 2, BUILDING_BOTTOM - h))
	var dst := (TILE_DIR if key in CORE_KEYS else BUILDING_DIR) + key + ".png"
	var err := canvas.save_png(ProjectSettings.globalize_path(dst))
	print("  %s -> err=%d (%dx%d)" % [dst, err, w, h])
	return 0 if err == OK else 1
