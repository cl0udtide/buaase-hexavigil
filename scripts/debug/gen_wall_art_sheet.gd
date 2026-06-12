extends SceneTree

## 程序化墙体美术的视觉校样脚本（非测试）：
## 生成 16+16 变种图鉴 + 按游戏真实显示参数（72px 贴图 / 64px 格距 / -8 纵向偏移）
## 合成的拼接演示场景，落盘 /tmp/wall_art_sheet.png 供人工审看。

const WallArt = preload("res://scripts/building/wall_art.gd")

const CELL := 64
const DISPLAY := 72
const OFFSET_Y := -8
const BG := Color8(64, 112, 66)
const BG_ALT := Color8(59, 104, 61)
const HIGHLAND_BG := Color8(158, 138, 97)

const MASK_SUFFIX := [
	"0000_isolated", "0001_n", "0010_e", "0011_ne",
	"0100_s", "0101_ns", "0110_es", "0111_nes",
	"1000_w", "1001_nw", "1010_ew", "1011_new",
	"1100_sw", "1101_nsw", "1110_esw", "1111_nesw",
]


func _init() -> void:
	var sheet_w := 8 * 96
	var catalog_h := 2 * 2 * 96 + 32
	var demo_cols := 12
	var demo_rows := 7
	var demo_h := demo_rows * CELL + 48
	var sheet := Image.create(sheet_w, catalog_h + demo_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(38, 46, 40))

	for kind_index: int in range(2):
		var kind := &"wood_wall" if kind_index == 0 else &"artificial_platform"
		for i: int in range(16):
			var slot_x := (i % 8) * 96
			var slot_y := kind_index * 2 * 96 + (i / 8) * 96
			sheet.fill_rect(Rect2i(slot_x + 4, slot_y + 4, 88, 88), BG if i % 2 == 0 else BG_ALT)
			var img := WallArt.build_image(kind, i)
			img.resize(DISPLAY, DISPLAY, Image.INTERPOLATE_NEAREST)
			sheet.blend_rect(img, Rect2i(0, 0, DISPLAY, DISPLAY), Vector2i(slot_x + 48 - DISPLAY / 2, slot_y + 48 - DISPLAY / 2 + OFFSET_Y))

	# 拼接演示：W=木墙 P=哨站，按真实格距合成，检查无缝程度。
	var board: Array[String] = [
		"............",
		".WWPWW..W...",
		"........W...",
		".W..WPW.P.W.",
		".WW...W.W...",
		".P....P.....",
		"............",
	]
	var demo_y0 := catalog_h + 24
	for row: int in range(demo_rows):
		for col: int in range(demo_cols):
			var bg := BG if (row + col) % 2 == 0 else BG_ALT
			sheet.fill_rect(Rect2i(col * CELL, demo_y0 + row * CELL, CELL, CELL), bg)
	for row: int in range(demo_rows):
		for col: int in range(demo_cols):
			var ch := board[row][col]
			if ch != "W" and ch != "P":
				continue
			var mask := 0
			if row > 0 and _is_wall(board, col, row - 1):
				mask |= 1
			if col < demo_cols - 1 and _is_wall(board, col + 1, row):
				mask |= 2
			if row < demo_rows - 1 and _is_wall(board, col, row + 1):
				mask |= 4
			if col > 0 and _is_wall(board, col - 1, row):
				mask |= 8
			var kind := &"wood_wall" if ch == "W" else &"artificial_platform"
			var img := WallArt.build_image(kind, mask)
			img.resize(DISPLAY, DISPLAY, Image.INTERPOLATE_NEAREST)
			var px := col * CELL + CELL / 2 - DISPLAY / 2
			var py := demo_y0 + row * CELL + CELL / 2 - DISPLAY / 2 + OFFSET_Y
			sheet.blend_rect(img, Rect2i(0, 0, DISPLAY, DISPLAY), Vector2i(px, py))

	var err := sheet.save_png("/tmp/wall_art_sheet.png")
	print("wall_art_sheet saved err=%d" % err)

	# 关键接缝 3x 放大图：横墙对、墙-哨站对、十字、纵墙对。
	var zoom_src := Image.create(4 * CELL + 32, 4 * CELL + 32, false, Image.FORMAT_RGBA8)
	zoom_src.fill(BG)
	var pairs: Array[Array] = [
		[&"wood_wall", 2, Vector2i(0, 0), &"wood_wall", 8, Vector2i(1, 0)],
		[&"wood_wall", 2, Vector2i(0, 1), &"artificial_platform", 8, Vector2i(1, 1)],
		[&"wood_wall", 4, Vector2i(3, 0), &"artificial_platform", 1, Vector2i(3, 1)],
		[&"wood_wall", 15, Vector2i(0, 3), &"artificial_platform", 15, Vector2i(2, 3)],
	]
	for pair: Array in pairs:
		for k: int in range(0, 6, 3):
			var img := WallArt.build_image(pair[k], pair[k + 1])
			img.resize(DISPLAY, DISPLAY, Image.INTERPOLATE_NEAREST)
			var cell: Vector2i = pair[k + 2]
			var px := cell.x * CELL + CELL / 2 - DISPLAY / 2 + 16
			var py := cell.y * CELL + CELL / 2 - DISPLAY / 2 + OFFSET_Y + 16
			zoom_src.blend_rect(img, Rect2i(0, 0, DISPLAY, DISPLAY), Vector2i(px, py))
	zoom_src.resize(zoom_src.get_width() * 3, zoom_src.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var err2 := zoom_src.save_png("/tmp/wall_art_zoom.png")
	print("wall_art_zoom saved err=%d" % err2)
	quit(0 if err == OK and err2 == OK else 1)


func _is_wall(board: Array[String], col: int, row: int) -> bool:
	var ch := board[row][col]
	return ch == "W" or ch == "P"
