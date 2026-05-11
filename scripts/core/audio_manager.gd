extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const BGM_DAY := &"day"
const BGM_NIGHT := &"night"
const BGM_BOSS := &"boss"

const SFX_UNIT_DEPLOY := &"unit_deploy"
const SFX_UNIT_REMOVED := &"unit_removed"
const SFX_BUILD_PLACE := &"build_place"
const SFX_BUILD_FAILED := &"build_failed"
const SFX_FOG_REVEAL := &"fog_reveal"
const SFX_EVENT_TRIGGER := &"event_trigger"
const SFX_RESOURCE_COLLECT := &"resource_collect"
const SFX_BLESSING_CHOSEN := &"blessing_chosen"
const SFX_UI_CLICK := &"ui_click"
const SFX_UI_CONFIRM := &"ui_confirm"
const SFX_UI_CANCEL := &"ui_cancel"
const SFX_UI_PANEL_OPEN := &"ui_panel_open"
const SFX_UI_PANEL_CLOSE := &"ui_panel_close"
const SFX_UI_ERROR := &"ui_error"
const SFX_UI_TAB_SWITCH := &"ui_tab_switch"
const SFX_UI_TRANSITION := &"ui_transition"
const SFX_UI_REFRESH := &"ui_refresh"
const SFX_UI_PURCHASE := &"ui_purchase"
const SFX_UI_RELIC_OPEN := &"ui_relic_open"
const SFX_UI_CARD_SELECT := &"ui_card_select"
const SFX_UI_PAUSE := &"ui_pause"
const SFX_UI_SPEED_TOGGLE := &"ui_speed_toggle"
const SFX_UI_SLIDER := &"ui_slider"

const FADE_SECONDS := 0.65
const SFX_POOL_SIZE := 8
const SETTINGS_PATH := "user://audio_settings.cfg"
const SETTINGS_SECTION := "audio"

var master_volume := 0.85
var music_volume := 0.75
var sfx_volume := 0.85

var bgm_paths := {
	BGM_DAY: "res://assets/audio/bgm/day_1.ogg",
	BGM_NIGHT: "res://assets/audio/bgm/night_1.ogg"
}
var sfx_paths := {
	SFX_UNIT_DEPLOY: "res://assets/audio/sfx/unit_deploy.ogg",
	SFX_UNIT_REMOVED: "res://assets/audio/sfx/unit_removed.ogg",
	SFX_BUILD_PLACE: "res://assets/audio/sfx/build_place.ogg",
	SFX_BUILD_FAILED: "res://assets/audio/sfx/ui_error.ogg",
	SFX_FOG_REVEAL: "res://assets/audio/sfx/fog_reveal.ogg",
	SFX_EVENT_TRIGGER: "res://assets/audio/sfx/event_trigger.ogg",
	SFX_RESOURCE_COLLECT: "res://assets/audio/sfx/resource_collect.ogg",
	SFX_BLESSING_CHOSEN: "res://assets/audio/sfx/blessing_chosen.ogg",
	SFX_UI_CLICK: "res://assets/audio/sfx/ui_click.ogg",
	SFX_UI_CONFIRM: "res://assets/audio/sfx/ui_confirm.ogg",
	SFX_UI_CANCEL: "res://assets/audio/sfx/ui_cancel.ogg",
	SFX_UI_PANEL_OPEN: "res://assets/audio/sfx/ui_panel_open.ogg",
	SFX_UI_PANEL_CLOSE: "res://assets/audio/sfx/ui_panel_close.ogg",
	SFX_UI_ERROR: "res://assets/audio/sfx/ui_error.ogg",
	SFX_UI_TAB_SWITCH: "res://assets/audio/sfx/ui_tab_switch.ogg",
	SFX_UI_TRANSITION: "res://assets/audio/sfx/ui_transition.ogg",
	SFX_UI_REFRESH: "res://assets/audio/sfx/ui_refresh.ogg",
	SFX_UI_PURCHASE: "res://assets/audio/sfx/ui_purchase.ogg",
	SFX_UI_RELIC_OPEN: "res://assets/audio/sfx/ui_relic_open.ogg",
	SFX_UI_CARD_SELECT: "res://assets/audio/sfx/ui_card_select.ogg",
	SFX_UI_PAUSE: "res://assets/audio/sfx/ui_transition.ogg",
	SFX_UI_SPEED_TOGGLE: "res://assets/audio/sfx/ui_transition.ogg",
	SFX_UI_SLIDER: "res://assets/audio/sfx/ui_click.ogg"
}

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _current_bgm_key := StringName()
var _fade_tween: Tween


func _ready() -> void:
	_setup_players()
	_load_settings()
	_apply_volumes()
	_bind_events()


func play_day_bgm() -> void:
	play_bgm(BGM_DAY)


func play_night_bgm() -> void:
	play_bgm(BGM_NIGHT)


func play_boss_bgm() -> void:
	if bgm_paths.has(BGM_BOSS):
		play_bgm(BGM_BOSS)
	else:
		play_bgm(BGM_NIGHT)


func stop_bgm() -> void:
	_current_bgm_key = StringName()
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bgm_player, "volume_db", -80.0, FADE_SECONDS)
	_fade_tween.tween_callback(_bgm_player.stop)


func play_bgm(bgm_key: StringName) -> void:
	if _current_bgm_key == bgm_key and _bgm_player.playing:
		return
	var stream := _load_stream(String(bgm_paths.get(bgm_key, "")))
	if stream == null:
		push_warning("Missing BGM stream for key: %s" % bgm_key)
		return
	_enable_stream_loop(stream)
	_current_bgm_key = bgm_key
	if _fade_tween != null:
		_fade_tween.kill()
	_bgm_player.stream = stream
	_bgm_player.volume_db = -80.0
	_bgm_player.play()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bgm_player, "volume_db", _linear_to_db(master_volume * music_volume), FADE_SECONDS)


func play_sfx(sfx_key: StringName) -> void:
	var path := String(sfx_paths.get(sfx_key, ""))
	if path.is_empty():
		return
	var stream := _load_stream(path)
	if stream == null:
		push_warning("Missing SFX stream for key: %s" % sfx_key)
		return
	play_sfx_stream(stream)


func play_unit_deploy_sfx() -> void:
	play_sfx(SFX_UNIT_DEPLOY)


func play_build_place_sfx() -> void:
	play_sfx(SFX_BUILD_PLACE)


func play_fog_reveal_sfx() -> void:
	play_sfx(SFX_FOG_REVEAL)


func play_event_trigger_sfx() -> void:
	play_sfx(SFX_EVENT_TRIGGER)


func play_resource_collect_sfx() -> void:
	play_sfx(SFX_RESOURCE_COLLECT)


func play_sfx_stream(stream: AudioStream) -> void:
	if stream == null or _sfx_players.is_empty():
		return
	var player := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stop()
	player.stream = stream
	player.volume_db = _linear_to_db(master_volume * sfx_volume)
	player.play()


func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func get_volume_state() -> Dictionary:
	return {
		"master": master_volume,
		"music": music_volume,
		"sfx": sfx_volume
	}


func _setup_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	add_child(_bgm_player)
	for index in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % (index + 1)
		add_child(player)
		_sfx_players.append(player)


func _bind_events() -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus == null:
		return
	event_bus.day_started.connect(_on_day_started)
	event_bus.night_started.connect(_on_night_started)
	event_bus.run_ended.connect(_on_run_ended)
	event_bus.unit_deployed.connect(_on_unit_deployed)
	event_bus.building_placed.connect(_on_building_placed)
	event_bus.build_action_result.connect(_on_build_action_result)
	event_bus.fog_revealed.connect(_on_fog_revealed)
	event_bus.random_event_triggered.connect(_on_random_event_triggered)
	event_bus.resource_collected.connect(_on_resource_collected)
	event_bus.unit_removed.connect(_on_unit_removed)
	event_bus.shop_action_result.connect(_on_shop_action_result)
	event_bus.blessing_chosen.connect(_on_blessing_chosen)
	event_bus.audio_cue_requested.connect(_on_audio_cue_requested)


func _apply_volumes() -> void:
	if _bgm_player != null:
		_bgm_player.volume_db = _linear_to_db(master_volume * music_volume)
	for player in _sfx_players:
		player.volume_db = _linear_to_db(master_volume * sfx_volume)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = clamp(float(cfg.get_value(SETTINGS_SECTION, "master", master_volume)), 0.0, 1.0)
	music_volume = clamp(float(cfg.get_value(SETTINGS_SECTION, "music", music_volume)), 0.0, 1.0)
	sfx_volume = clamp(float(cfg.get_value(SETTINGS_SECTION, "sfx", sfx_volume)), 0.0, 1.0)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SETTINGS_SECTION, "master", master_volume)
	cfg.set_value(SETTINGS_SECTION, "music", music_volume)
	cfg.set_value(SETTINGS_SECTION, "sfx", sfx_volume)
	cfg.save(SETTINGS_PATH)


func _load_stream(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _enable_stream_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	for property_info in stream.get_property_list():
		var property_name := StringName(property_info.get("name", ""))
		if property_name == &"loop":
			stream.set("loop", true)
			return
		if property_name == &"loop_mode":
			stream.set("loop_mode", 1)
			return


func _linear_to_db(value: float) -> float:
	if value <= 0.001:
		return -80.0
	return linear_to_db(value)


func _on_day_started(_day: int) -> void:
	play_day_bgm()


func _on_night_started(day: int) -> void:
	if day >= 6:
		play_boss_bgm()
	else:
		play_night_bgm()


func _on_run_ended(_win: bool) -> void:
	stop_bgm()


func _on_unit_deployed(_unit_runtime_id: int, _operator_key: StringName, _unit_id: StringName, _cell: Vector2i) -> void:
	play_unit_deploy_sfx()


func _on_building_placed(_building_runtime_id: int, _building_id: StringName, _cell: Vector2i) -> void:
	play_build_place_sfx()


func _on_build_action_result(_building_id: StringName, _cell: Vector2i, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		play_sfx(SFX_BUILD_FAILED)


func _on_fog_revealed(_cells: Array[Vector2i]) -> void:
	play_fog_reveal_sfx()


func _on_random_event_triggered(_event_id: StringName, _cell: Vector2i) -> void:
	play_event_trigger_sfx()


func _on_resource_collected(_cell: Vector2i, _resource_type: StringName, _amount: int) -> void:
	play_resource_collect_sfx()


func _on_unit_removed(_unit_runtime_id: int, _reason: int) -> void:
	play_sfx(SFX_UNIT_REMOVED)


func _on_shop_action_result(action: StringName, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		play_sfx(SFX_UI_ERROR)
		return
	match action:
		&"buy":
			play_sfx(SFX_UI_PURCHASE)
		&"refresh":
			play_sfx(SFX_UI_REFRESH)


func _on_blessing_chosen(_buff_id: StringName) -> void:
	play_sfx(SFX_BLESSING_CHOSEN)


func _on_audio_cue_requested(cue_key: StringName) -> void:
	play_sfx(cue_key)
