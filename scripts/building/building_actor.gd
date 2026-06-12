extends Node2D

const AppTheme = preload("res://scripts/ui/app_theme.gd")
const AppRefs = preload("res://scripts/common/app_refs.gd")
const OneShotEffect = preload("res://scripts/effects/one_shot_effect.gd")
const WallArt = preload("res://scripts/building/wall_art.gd")
const ContactShadow = preload("res://scripts/effects/contact_shadow.gd")

const VISUAL_TEXTURE_ROOT := "res://assets/sprites/buildings"
const VISUAL_IDLE_ANIM := "idle"
const VISUAL_TEXTURE_SIZE := 128.0
const VISUAL_DISPLAY_SIZE := 72.0
const VISUAL_OFFSET := Vector2(0.0, -8.0)
const CONTACT_SHADOW_Y := 25.0
const VISUAL_Z_INDEX := 2
const OVERLAY_Z_INDEX := 20
const DESTROYED_VISUAL_KEY := "generic_destroyed_building"
const DEFAULT_IMPACT_SIZE := Vector2(96.0, 96.0)

var building_id: StringName
var runtime_id := -1
var current_cell := Vector2i.ZERO
var max_hp := 1
var current_hp := 1
var effect_radius := 0
var cfg: Dictionary = {}
var _base_max_hp := 1
var _enabled := true
var _is_destroyed := false
var _wall_connection_mask := 0
var _has_visual_sprite := false
var _using_destroyed_visual_fallback := false

@onready var _status_view: Node = get_node_or_null("%StatusView")
@onready var _visual_root: Node2D = get_node_or_null("%VisualRoot") as Node2D


func _ready() -> void:
	add_to_group("buildings")
	_setup_overlay_z_index()


func setup_from_cfg(new_building_id: StringName, new_cfg: Dictionary, cell: Vector2i) -> void:
	building_id = new_building_id
	cfg = new_cfg.duplicate(true)
	current_cell = cell
	_base_max_hp = int(cfg.get("max_hp", 1))
	max_hp = _calculate_effective_max_hp()
	current_hp = max_hp
	effect_radius = int(cfg.get("effect_radius", 0))
	_enabled = bool(cfg.get("initial_enabled", true))
	_is_destroyed = false
	global_position = get_map_manager().cell_to_world(cell) if get_map_manager() != null else Vector2.ZERO
	_refresh_visual_sprite()
	_refresh_title_label()
	_update_status_view()


func receive_damage(value: int, damage_type: int) -> void:
	if _is_destroyed:
		return
	current_hp = max(current_hp - value, 0)
	_update_status_view()
	_play_hit_effect(damage_type)
	if current_hp == 0:
		_set_destroyed(true)


func repair_full() -> void:
	current_hp = max_hp
	_set_destroyed(false)
	_update_status_view()
	_play_repair_effect()


func refresh_relic_effects() -> void:
	var new_max := _calculate_effective_max_hp()
	if new_max == max_hp:
		return
	var delta := new_max - max_hp
	max_hp = new_max
	if delta > 0 and not _is_destroyed:
		current_hp += delta
	current_hp = min(current_hp, max_hp)
	_update_status_view()


func is_destroyed() -> bool:
	return _is_destroyed


func _calculate_effective_max_hp() -> int:
	var run_state = AppRefs.run_state()
	var hp_percent := 0.0
	if run_state != null and run_state.has_method("get_buff_effect_total_for_building"):
		hp_percent += float(run_state.get_buff_effect_total_for_building(&"building_max_hp_percent", cfg))
	return max(int(round(float(_base_max_hp) * (1.0 + hp_percent))), 1)


func get_runtime_id() -> int:
	return runtime_id


func get_current_cell() -> Vector2i:
	return current_cell


func get_effect_radius() -> int:
	return effect_radius


func is_enabled() -> bool:
	return _enabled


func is_aura_active() -> bool:
	return not _is_destroyed and current_hp > 0 and _enabled


func can_toggle_enabled() -> bool:
	return building_id == &"war_shrine"


func set_wall_connection_mask(mask: int) -> void:
	var normalized_mask: int = max(0, min(mask, 15))
	if _wall_connection_mask == normalized_mask:
		return
	_wall_connection_mask = normalized_mask
	_refresh_visual_sprite()


func get_wall_connection_mask() -> int:
	return _wall_connection_mask


func set_enabled(value: bool) -> void:
	if not can_toggle_enabled():
		return
	_enabled = value
	_refresh_visual_sprite()


func toggle_enabled() -> bool:
	if not can_toggle_enabled():
		return _enabled
	_enabled = not _enabled
	_refresh_visual_sprite()
	return _enabled


func get_map_manager() -> Node:
	return get_node_or_null("../../../Managers/MapManager")


func _refresh_title_label() -> void:
	var label := get_node_or_null("%TitleLabel") as Label
	if label == null:
		return
	label.theme = AppTheme.get_theme()
	label.visible = not _has_visual_sprite
	var title := String(cfg.get("name", building_id))
	if _is_destroyed:
		title += " [已毁]"
	if can_toggle_enabled():
		title += " [ON]" if _enabled else " [OFF]"
	label.text = title


func _setup_overlay_z_index() -> void:
	var label := get_node_or_null("%TitleLabel")
	if label is CanvasItem:
		(label as CanvasItem).z_index = OVERLAY_Z_INDEX
	if _status_view is CanvasItem:
		(_status_view as CanvasItem).z_index = OVERLAY_Z_INDEX


func _refresh_visual_sprite() -> void:
	_has_visual_sprite = false
	_using_destroyed_visual_fallback = false
	var desired_key := _resolve_visual_key()
	var texture := _load_visual_texture(desired_key)
	if texture == null and _uses_wall_visuals() and not _is_destroyed:
		var base_key := String(cfg.get("visual_key", "")).strip_edges()
		if not base_key.is_empty() and base_key != desired_key:
			texture = _load_visual_texture(base_key)
		var prefix_key := String(cfg.get("wall_visual_prefix", "")).strip_edges()
		if texture == null and not prefix_key.is_empty() and prefix_key != desired_key and prefix_key != base_key:
			texture = _load_visual_texture(prefix_key)
	if texture == null and _is_destroyed:
		var fallback_key := _resolve_operational_visual_key()
		if not fallback_key.is_empty() and fallback_key != desired_key:
			texture = _load_visual_texture(fallback_key)
			_using_destroyed_visual_fallback = texture != null
	var sprite := _get_visual_sprite(texture != null)
	if texture == null:
		if sprite != null:
			sprite.visible = false
		_refresh_contact_shadow(false)
		modulate = Color(0.55, 0.55, 0.55, 0.78) if _is_destroyed else Color.WHITE
		_refresh_title_label()
		return
	sprite.texture = texture
	sprite.centered = true
	sprite.position = VISUAL_OFFSET
	sprite.scale = Vector2.ONE * (_get_visual_display_size() / VISUAL_TEXTURE_SIZE)
	sprite.z_index = VISUAL_Z_INDEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.visible = true
	_has_visual_sprite = true
	_refresh_contact_shadow(not _uses_wall_visuals())
	modulate = Color(0.55, 0.55, 0.55, 0.78) if _is_destroyed and _using_destroyed_visual_fallback else Color.WHITE
	_refresh_title_label()


## 墙族铺满整格无悬浮感，不加接触阴影。
func _refresh_contact_shadow(enabled: bool) -> void:
	var existing := get_node_or_null("ContactShadow") as Node2D
	if not enabled:
		if existing != null:
			existing.visible = false
		return
	if existing == null:
		var shadow := ContactShadow.new()
		shadow.name = "ContactShadow"
		shadow.position = Vector2(0.0, CONTACT_SHADOW_Y)
		shadow.radius = 20.0
		shadow.squash = 0.36
		add_child(shadow)
		return
	existing.visible = true


func _get_visual_sprite(create_if_missing: bool) -> Sprite2D:
	if _visual_root == null and create_if_missing:
		_visual_root = Node2D.new()
		_visual_root.name = "VisualRoot"
		_visual_root.unique_name_in_owner = true
		add_child(_visual_root)
	if _visual_root == null:
		return null
	var sprite := _visual_root.get_node_or_null("IdleSprite") as Sprite2D
	if sprite == null and create_if_missing:
		sprite = Sprite2D.new()
		sprite.name = "IdleSprite"
		_visual_root.add_child(sprite)
	return sprite


func _resolve_visual_key() -> String:
	if _is_destroyed:
		var destroyed_key := String(cfg.get("destroyed_visual_key", DESTROYED_VISUAL_KEY)).strip_edges()
		return destroyed_key if not destroyed_key.is_empty() else DESTROYED_VISUAL_KEY
	return _resolve_operational_visual_key()


func _uses_wall_visuals() -> bool:
	return not String(cfg.get("wall_visual_prefix", "")).strip_edges().is_empty()


func _resolve_operational_visual_key() -> String:
	if _uses_wall_visuals():
		return _resolve_wall_visual_key()
	if can_toggle_enabled():
		var state_key_name := "active_visual_key" if _enabled else "inactive_visual_key"
		var state_key := String(cfg.get(state_key_name, "")).strip_edges()
		if not state_key.is_empty():
			return state_key
	var visual_key := String(cfg.get("visual_key", building_id)).strip_edges()
	return visual_key if not visual_key.is_empty() else String(building_id)


func _resolve_wall_visual_key() -> String:
	var prefix := String(cfg.get("wall_visual_prefix", "wood_wall")).strip_edges()
	if prefix.is_empty():
		prefix = String(cfg.get("visual_key", "wood_wall")).strip_edges()
	if prefix.is_empty():
		prefix = "wood_wall"
	return "%s_%s" % [prefix, _wall_connection_suffix(_wall_connection_mask)]


func _wall_connection_suffix(mask: int) -> String:
	match mask:
		0:
			return "0000_isolated"
		1:
			return "0001_n"
		2:
			return "0010_e"
		3:
			return "0011_ne"
		4:
			return "0100_s"
		5:
			return "0101_ns"
		6:
			return "0110_es"
		7:
			return "0111_nes"
		8:
			return "1000_w"
		9:
			return "1001_nw"
		10:
			return "1010_ew"
		11:
			return "1011_new"
		12:
			return "1100_sw"
		13:
			return "1101_nsw"
		14:
			return "1110_esw"
		15:
			return "1111_nesw"
	return "0000_isolated"


func _load_visual_texture(visual_key: String) -> Texture2D:
	var normalized_key := visual_key.strip_edges()
	if normalized_key.is_empty():
		return null
	# 墙族贴图（木墙/人工高台连接变种）由 wall_art 程序化生成，优先于文件贴图。
	var generated := WallArt.texture_for_key(normalized_key)
	if generated != null:
		return generated
	for path in _candidate_texture_paths(normalized_key):
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func _candidate_texture_paths(visual_key: String) -> PackedStringArray:
	var paths := PackedStringArray()
	paths.append("%s/%s.png" % [VISUAL_TEXTURE_ROOT, visual_key])
	paths.append("%s/%s/%s.png" % [VISUAL_TEXTURE_ROOT, visual_key, visual_key])
	paths.append("%s/%s/%s_%s_000.png" % [VISUAL_TEXTURE_ROOT, visual_key, visual_key, VISUAL_IDLE_ANIM])
	paths.append("%s/%s/%s/%s_%s_000.png" % [VISUAL_TEXTURE_ROOT, visual_key, VISUAL_IDLE_ANIM, visual_key, VISUAL_IDLE_ANIM])
	var family_key := _visual_family_key(visual_key)
	if not family_key.is_empty() and family_key != visual_key:
		paths.append("%s/%s/%s.png" % [VISUAL_TEXTURE_ROOT, family_key, visual_key])
		paths.append("%s/%s/%s_%s_000.png" % [VISUAL_TEXTURE_ROOT, family_key, visual_key, VISUAL_IDLE_ANIM])
		paths.append("%s/%s/%s/%s_%s_000.png" % [VISUAL_TEXTURE_ROOT, family_key, VISUAL_IDLE_ANIM, visual_key, VISUAL_IDLE_ANIM])
	return paths


func _visual_family_key(visual_key: String) -> String:
	if visual_key.begins_with("wood_wall_"):
		return "wood_wall"
	if visual_key.begins_with("war_shrine_"):
		return "war_shrine"
	return ""


func _get_visual_display_size() -> float:
	return max(float(cfg.get("visual_display_size", VISUAL_DISPLAY_SIZE)), 1.0)


func _update_status_view() -> void:
	if _status_view != null and _status_view.has_method("set_hp"):
		_status_view.set_hp(current_hp, max_hp)


func _play_hit_effect(damage_type_value: int = GameEnums.DAMAGE_PHYSICAL) -> void:
	var effect_root := _get_effect_root()
	var effect_parent: Node = effect_root if effect_root != null else self
	var effect := OneShotEffect.new()
	effect_parent.add_child(effect)
	effect.setup({
		"texture_path": _default_impact_texture_path(damage_type_value),
		"follow_target": self,
		"local_position": VISUAL_OFFSET,
		"hframes": 6,
		"frame_count": 6,
		"fps": 18.0,
		"size": DEFAULT_IMPACT_SIZE,
		"z_index": 24
	})


func _play_repair_effect() -> void:
	var effect_root := _get_effect_root()
	var effect_parent: Node = effect_root if effect_root != null else self
	var effect := OneShotEffect.new()
	effect_parent.add_child(effect)
	effect.setup({
		"texture_path": "res://assets/effects/common/building_repair_heal_pulse_strip.png",
		"follow_target": self,
		"local_position": VISUAL_OFFSET,
		"hframes": 6,
		"frame_count": 6,
		"fps": 14.0,
		"duration": 0.5,
		"size": Vector2(112.0, 112.0),
		"z_index": 24
	})


func _get_effect_root() -> Node:
	return get_node_or_null("../../EffectRoot")


func _default_impact_texture_path(damage_type_value: int) -> String:
	match damage_type_value:
		GameEnums.DAMAGE_MAGIC:
			return "res://assets/effects/common/impact_arts_small_strip.png"
		GameEnums.DAMAGE_TRUE:
			return "res://assets/effects/common/impact_true_damage_small_strip.png"
		_:
			return "res://assets/effects/common/impact_physical_small_strip.png"


func _set_destroyed(value: bool) -> void:
	_is_destroyed = value
	_refresh_visual_sprite()
