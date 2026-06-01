class_name UiDisplayText
extends RefCounted


static func config_name(cfg: Dictionary, fallback_id: Variant = "") -> String:
	var name := String(cfg.get("name", "")).strip_edges()
	if not name.is_empty():
		return name
	return String(fallback_id)


static func config_desc(cfg: Dictionary, fallback_text: String = "暂无说明") -> String:
	var desc := String(cfg.get("desc", "")).strip_edges()
	if not desc.is_empty():
		return desc
	return fallback_text


static func icon_text(cfg: Dictionary, fallback_text: String = "*") -> String:
	var explicit_icon := String(cfg.get("icon_text", "")).strip_edges()
	if not explicit_icon.is_empty():
		return explicit_icon.substr(0, 1)
	var fallback_icon := fallback_text.strip_edges()
	if not fallback_icon.is_empty() and fallback_icon != "*":
		return fallback_icon.substr(0, 1)
	var name := String(cfg.get("name", "")).strip_edges()
	if not name.is_empty():
		return name.substr(0, 1)
	return fallback_icon.substr(0, 1) if not fallback_icon.is_empty() else "*"


static func class_label(class_key: String) -> String:
	match class_key:
		"guard":
			return "近卫"
		"sniper":
			return "狙击"
		"caster":
			return "术士"
		"defender":
			return "重装"
		_:
			return class_key


static func tier_label(cost_prestige: int) -> String:
	match cost_prestige:
		2:
			return "一阶"
		4:
			return "二阶"
		7:
			return "三阶"
		_:
			return "特殊"


static func tier_color(cost_prestige: int) -> Color:
	match cost_prestige:
		2:
			return Color(0.090, 0.610, 0.360)
		4:
			return Color(0.145, 0.388, 0.920)
		7:
			return Color(0.915, 0.520, 0.075)
		_:
			return Color(0.285, 0.365, 0.460, 1.0)


static func damage_type_label(type_value: int) -> String:
	match type_value:
		GameEnums.DAMAGE_PHYSICAL:
			return "物理"
		GameEnums.DAMAGE_MAGIC:
			return "法术"
		GameEnums.DAMAGE_TRUE:
			return "真实"
		_:
			return "未知"


static func direction_label(direction: Vector2i) -> String:
	var normalized := _normalize_direction(direction)
	if normalized == Vector2i.LEFT:
		return "左"
	if normalized == Vector2i.UP:
		return "上"
	if normalized == Vector2i.DOWN:
		return "下"
	return "右"


static func phase_label(phase: int) -> String:
	match phase:
		GameEnums.PHASE_DAY:
			return "白天"
		GameEnums.PHASE_NIGHT:
			return "夜晚"
		GameEnums.PHASE_BLESSING:
			return "遗物"
		GameEnums.PHASE_RESULT:
			return "结算"
		_:
			return "准备"


static func relic_rarity_label(rarity: int) -> String:
	match rarity:
		3:
			return "稀有"
		2:
			return "精良"
		_:
			return "常见"


static func relic_rarity_color(rarity: int) -> Color:
	match rarity:
		3:
			return Color(0.950, 0.650, 0.220, 1.0)
		2:
			return Color(0.260, 0.760, 0.920, 1.0)
		_:
			return Color(0.290, 0.700, 0.430, 1.0)


static func relic_category_label(category: StringName) -> String:
	match category:
		&"unit":
			return "单位"
		&"building":
			return "建筑"
		&"economy":
			return "经济"
		&"core":
			return "核心"
		&"risk":
			return "风险"
		_:
			return "全部"


static func relic_category_labels(cfg: Dictionary) -> PackedStringArray:
	var labels := PackedStringArray()
	for category in [&"unit", &"building", &"economy", &"core", &"risk"]:
		if relic_matches_category(cfg, category):
			labels.append(relic_category_label(category))
	if labels.is_empty():
		labels.append("通用")
	return labels


static func relic_tag_text(cfg: Dictionary) -> String:
	return " / ".join(relic_category_labels(cfg))


static func relic_matches_category(cfg: Dictionary, category: StringName) -> bool:
	if category == &"all" or category == StringName():
		return true
	match category:
		&"unit":
			return _relic_has_any_effect_prefix(cfg, ["unit_", "enemy_", "formation_"]) or _relic_has_target_effect_prefix(cfg, "unit_") or _relic_has_filter(cfg, "class_filter") or _relic_has_filter(cfg, "damage_type_filter")
		&"building":
			return _relic_has_effect_prefix(cfg, "building_") or _relic_has_filter(cfg, "building_type_filter")
		&"economy":
			return _relic_has_any_effect_prefix(cfg, ["shop_", "kill_", "prestige_", "building_income", "building_material_cost"]) or _relic_has_filter(cfg, "material_filter")
		&"core":
			return _relic_has_any_effect_prefix(cfg, ["core_", "deploy_limit"])
		&"risk":
			return _relic_has_risk(cfg)
	return false


static func relic_effect_text(cfg: Dictionary, fallback_text: String = "暂无效果说明") -> String:
	var desc := config_desc(cfg, "")
	if not desc.is_empty():
		return desc
	var lines := PackedStringArray()
	for effect in _get_relic_effect_entries(cfg):
		lines.append(relic_effect_entry_text(effect))
	if lines.is_empty():
		return fallback_text
	return "；".join(lines)


static func relic_effect_entry_text(effect: Dictionary) -> String:
	var effect_type := String(effect.get("effect_type", "")).strip_edges()
	var value: Variant = effect.get("effect_value", null)
	var label := _relic_effect_type_label(effect_type)
	var value_text := _format_relic_effect_value(effect_type, value)
	var filters := _format_relic_filters(effect)
	if filters.is_empty():
		return "%s %s" % [label, value_text]
	return "%s：%s %s" % [filters, label, value_text]


static func relic_tooltip_text(buff_id: StringName, cfg: Dictionary) -> String:
	var name := config_name(cfg, buff_id)
	var rarity := relic_rarity_label(int(cfg.get("rarity", 1)))
	var effect := relic_effect_text(cfg)
	return "%s\n%s · %s\n%s" % [name, rarity, relic_tag_text(cfg), effect]


static func _normalize_direction(direction: Vector2i) -> Vector2i:
	if abs(direction.x) >= abs(direction.y):
		return Vector2i.RIGHT if direction.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0 else Vector2i.UP


static func _get_relic_effect_entries(cfg: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if typeof(cfg.get("effects", null)) == TYPE_ARRAY:
		for raw_effect in cfg.get("effects", []):
			if typeof(raw_effect) != TYPE_DICTIONARY:
				continue
			var effect := (raw_effect as Dictionary).duplicate(true)
			for key in ["class_filter", "damage_type_filter", "building_type_filter", "material_filter", "max_cost_prestige", "min_cost_prestige"]:
				if not effect.has(key) and cfg.has(key):
					effect[key] = cfg[key]
			entries.append(effect)
	if entries.is_empty() and cfg.has("effect_type"):
		entries.append(cfg)
	return entries


static func _relic_has_effect_prefix(cfg: Dictionary, prefix: String) -> bool:
	for effect in _get_relic_effect_entries(cfg):
		if String(effect.get("effect_type", "")).begins_with(prefix):
			return true
	return false


static func _relic_has_any_effect_prefix(cfg: Dictionary, prefixes: Array[String]) -> bool:
	for prefix in prefixes:
		if _relic_has_effect_prefix(cfg, prefix):
			return true
	return false


static func _relic_has_target_effect_prefix(cfg: Dictionary, prefix: String) -> bool:
	for effect in _get_relic_effect_entries(cfg):
		if String(effect.get("target_effect_type", "")).begins_with(prefix):
			return true
	return false


static func _relic_has_filter(cfg: Dictionary, filter_key: String) -> bool:
	if cfg.has(filter_key):
		return true
	for effect in _get_relic_effect_entries(cfg):
		if effect.has(filter_key):
			return true
	return false


static func _relic_has_risk(cfg: Dictionary) -> bool:
	for effect in _get_relic_effect_entries(cfg):
		var effect_type := String(effect.get("effect_type", ""))
		var value := float(effect.get("effect_value", 0.0))
		if effect_type.contains("cost") and value > 0.0:
			return true
		if effect_type.contains("redeploy") and value > 0.0:
			return true
		if effect_type == "unit_attack_speed_add" and value < 0.0:
			return true
		if effect_type in ["unit_atk_percent", "unit_hp_percent", "unit_def_percent", "unit_block_add", "unit_deploy_slot_cost_add"] and value < 0.0:
			return true
	return false


static func _relic_effect_type_label(effect_type: String) -> String:
	match effect_type:
		"unit_atk_percent":
			return "攻击"
		"unit_hp_percent":
			return "生命"
		"unit_def_percent":
			return "防御"
		"unit_block_add":
			return "阻挡"
		"unit_redeploy_percent":
			return "再部署"
		"unit_attack_speed_add":
			return "攻速"
		"unit_sp_recover_percent":
			return "SP回复"
		"unit_deploy_slot_cost_add":
			return "部署占用"
		"deploy_limit_add":
			return "部署上限"
		"core_heal":
			return "核心治疗"
		"core_max_hp_add":
			return "核心上限"
		"shop_unit_cost_add":
			return "招募价格"
		"shop_refresh_cost_add":
			return "刷新价格"
		"kill_prestige_percent":
			return "击杀声望"
		"building_income_add":
			return "建筑产出"
		"building_income_percent":
			return "建筑产出"
		"building_aura_effect_percent":
			return "光环效果"
		"building_aura_radius_add":
			return "光环范围"
		"building_cost_add", "building_material_cost_add":
			return "建筑成本"
		_:
			return effect_type


static func _format_relic_effect_value(effect_type: String, value: Variant) -> String:
	if value == null:
		return ""
	var numeric := float(value)
	var sign := "+" if numeric > 0.0 else ""
	if effect_type.ends_with("_percent"):
		return "%s%d%%" % [sign, int(round(numeric * 100.0))]
	if numeric == round(numeric):
		return "%s%d" % [sign, int(numeric)]
	return "%s%.2f" % [sign, numeric]


static func _format_relic_filters(effect: Dictionary) -> String:
	var parts := PackedStringArray()
	if effect.has("class_filter"):
		parts.append(class_label(String(effect.get("class_filter", ""))))
	if effect.has("building_type_filter"):
		parts.append(_building_type_label(String(effect.get("building_type_filter", ""))))
	if effect.has("material_filter"):
		parts.append(_material_label(String(effect.get("material_filter", ""))))
	if effect.has("max_cost_prestige"):
		parts.append("%s及以下" % tier_label(int(effect.get("max_cost_prestige", 0))))
	if effect.has("min_cost_prestige"):
		parts.append("%s及以上" % tier_label(int(effect.get("min_cost_prestige", 0))))
	return " ".join(parts)


static func _building_type_label(type_key: String) -> String:
	match type_key:
		"resource":
			return "采集建筑"
		"aura":
			return "增益建筑"
		"block":
			return "防御建筑"
		_:
			return type_key


static func _material_label(material_key: String) -> String:
	match material_key:
		"wood":
			return "木材"
		"stone":
			return "石材"
		"mana":
			return "魔力"
		_:
			return material_key
