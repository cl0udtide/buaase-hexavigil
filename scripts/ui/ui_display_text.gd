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
		1:
			return "一阶"
		3:
			return "二阶"
		7:
			return "三阶"
		_:
			return "特殊"


static func tier_color(cost_prestige: int) -> Color:
	match cost_prestige:
		1:
			return Color(0.86, 0.93, 0.88)
		3:
			return Color(0.72, 0.88, 1.0)
		7:
			return Color(1.0, 0.82, 0.38)
		_:
			return Color(0.90, 0.96, 0.98, 1.0)


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


static func _normalize_direction(direction: Vector2i) -> Vector2i:
	if abs(direction.x) >= abs(direction.y):
		return Vector2i.RIGHT if direction.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0 else Vector2i.UP
