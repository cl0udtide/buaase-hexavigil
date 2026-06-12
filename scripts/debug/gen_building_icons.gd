extends SceneTree

## 一次性资产生成（非测试）：从 wall_art 程序化贴图导出建造菜单图标。
## 运行后需 `--headless --import` 让 Godot 重新导入资产。

const WallArt = preload("res://scripts/building/wall_art.gd")

const TARGETS := {
	"res://assets/ui/generated/icon_building_wood_wall.png": [&"wood_wall", 0],
	"res://assets/ui/generated/icon_building_artificial_platform.png": [&"artificial_platform", 0],
}


func _init() -> void:
	var failures := 0
	for path_raw: Variant in TARGETS.keys():
		var path: String = path_raw
		var spec: Array = TARGETS[path]
		var image := WallArt.build_image(spec[0], int(spec[1]))
		var used := image.get_used_rect().grow(6).intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
		var icon := image.get_region(used)
		var err := icon.save_png(ProjectSettings.globalize_path(path))
		print("%s -> err=%d (%dx%d)" % [path, err, icon.get_width(), icon.get_height()])
		if err != OK:
			failures += 1
	quit(0 if failures == 0 else 1)
