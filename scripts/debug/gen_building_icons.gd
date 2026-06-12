extends SceneTree

## 一次性资产生成（非测试）：导出建造菜单图标。
## 墙族来自 wall_art 程序化贴图（孤立变种），其余建筑直接裁切实装 sprite。
## 运行后需 `--headless --import` 让 Godot 重新导入资产。

const WallArt = preload("res://scripts/building/wall_art.gd")

const WALL_TARGETS := {
	"res://assets/ui/generated/icon_building_wood_wall.png": [&"wood_wall", 0],
	"res://assets/ui/generated/icon_building_artificial_platform.png": [&"artificial_platform", 0],
}
# 图标名 -> 建筑 sprite 名（战火圣坛用关闭态）。
const SPRITE_TARGETS := {
	"lumber_station": "lumber_station",
	"stone_quarry": "stone_quarry",
	"mana_extractor": "mana_extractor",
	"medical_station": "medical_station",
	"gravity_tower": "gravity_tower",
	"inspiring_monolith": "inspiring_monolith",
	"war_shrine": "war_shrine_inactive",
}


func _init() -> void:
	var failures := 0
	for path_raw: Variant in WALL_TARGETS.keys():
		var path: String = path_raw
		var spec: Array = WALL_TARGETS[path]
		failures += _save_icon(WallArt.build_image(spec[0], int(spec[1])), path)
	for icon_key: String in SPRITE_TARGETS:
		var src := "res://assets/sprites/buildings/%s.png" % String(SPRITE_TARGETS[icon_key])
		var image := Image.load_from_file(ProjectSettings.globalize_path(src))
		if image == null:
			printerr("missing sprite: %s" % src)
			failures += 1
			continue
		image.convert(Image.FORMAT_RGBA8)
		failures += _save_icon(image, "res://assets/ui/generated/icon_building_%s.png" % icon_key)
	quit(0 if failures == 0 else 1)


static func _save_icon(image: Image, path: String) -> int:
	var used := image.get_used_rect().grow(6).intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
	var icon := image.get_region(used)
	var err := icon.save_png(ProjectSettings.globalize_path(path))
	print("%s -> err=%d (%dx%d)" % [path, err, icon.get_width(), icon.get_height()])
	return 0 if err == OK else 1
