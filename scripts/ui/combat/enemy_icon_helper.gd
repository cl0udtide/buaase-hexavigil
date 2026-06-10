extends RefCounted
class_name EnemyIconHelper


static func texture_for_cfg(enemy_cfg: Dictionary) -> Texture2D:
	var visual_key := String(enemy_cfg.get("visual_key", enemy_cfg.get("id", ""))).strip_edges()
	if visual_key.is_empty():
		return null
	var path := "res://assets/sprites/enemies/%s/idle/%s_idle_000.png" % [visual_key, visual_key]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
