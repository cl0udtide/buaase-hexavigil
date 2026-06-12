extends Node2D

## 核心视图：立体建筑 sprite 叠在平地地块上（贴图由生成批次产出，见
## docs/MAP_ASSET_GENERATION_PROMPTS.md §4.2），比普通建筑（72px）更大更庄重。

const CORE_TEXTURE: Texture2D = preload("res://assets/map/CommandMap/core_structure.png")
const TEXTURE_SIZE := 128.0
const DISPLAY_SIZE := 88.0
const VISUAL_OFFSET := Vector2(0.0, -10.0)
const VISUAL_Z_INDEX := 2


func _ready() -> void:
	var label := get_node_or_null("%TitleLabel") as Label
	if label != null:
		label.visible = false
	var sprite := Sprite2D.new()
	sprite.name = "CoreSprite"
	sprite.texture = CORE_TEXTURE
	sprite.centered = true
	sprite.position = VISUAL_OFFSET
	sprite.scale = Vector2.ONE * (DISPLAY_SIZE / TEXTURE_SIZE)
	sprite.z_index = VISUAL_Z_INDEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
