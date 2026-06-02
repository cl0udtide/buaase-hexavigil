class_name GameplaySettings
extends RefCounted

const SETTINGS_PATH := "user://gameplay_settings.cfg"
const SETTINGS_SECTION := "gameplay"
const DEFAULT_AUTO_SKILL_CAST := false

static var _loaded := false
static var _auto_skill_cast_enabled := DEFAULT_AUTO_SKILL_CAST


static func is_auto_skill_cast_enabled() -> bool:
	_ensure_loaded()
	return _auto_skill_cast_enabled


static func set_auto_skill_cast_enabled(enabled: bool) -> void:
	_ensure_loaded()
	if _auto_skill_cast_enabled == enabled:
		return
	_auto_skill_cast_enabled = enabled
	_save_settings()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_auto_skill_cast_enabled = DEFAULT_AUTO_SKILL_CAST
		return
	_auto_skill_cast_enabled = bool(cfg.get_value(SETTINGS_SECTION, "auto_skill_cast", DEFAULT_AUTO_SKILL_CAST))


static func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SETTINGS_SECTION, "auto_skill_cast", _auto_skill_cast_enabled)
	cfg.save(SETTINGS_PATH)
