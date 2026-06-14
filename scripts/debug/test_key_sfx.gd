extends SceneTree

## Key SFX regression: core/building/enemy death cue registration and enemy death tiering.
## Run: Godot --headless --path . --script scripts/debug/test_key_sfx.gd

const AudioManagerScript = preload("res://scripts/core/audio_manager.gd")
const GameControllerScript = preload("res://scripts/core/game_controller.gd")

var _failures := 0
var _core_destroyed_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio_manager: Node = AudioManagerScript.new()
	root.add_child(audio_manager)
	_test_sfx_paths(audio_manager)
	_test_enemy_death_tiering(audio_manager)
	_test_enemy_death_variation(audio_manager)
	_test_sfx_gain_policy(audio_manager)
	_test_sfx_prewarm_cache(audio_manager)
	_test_core_destroyed_result_delay()
	_test_night_transition_delay()
	_test_run_end_audio_delay()
	_test_core_destroyed_emits_once()
	_test_event_handlers_exist(audio_manager)
	audio_manager.queue_free()
	_finish()


func _test_sfx_paths(audio_manager: Node) -> void:
	var sfx_paths: Dictionary = audio_manager.get("sfx_paths")
	var expected_paths := {
		&"core_hit": "res://assets/audio/sfx/core_hit.ogg",
		&"core_destroyed": "res://assets/audio/sfx/core_destroyed.ogg",
		&"building_hit": "res://assets/audio/sfx/building_hit.ogg",
		&"building_destroyed": "res://assets/audio/sfx/building_destroyed.ogg",
		&"enemy_death_small": "res://assets/audio/sfx/enemy_death_small.ogg",
		&"enemy_death_large": "res://assets/audio/sfx/enemy_death_large.ogg",
		&"night_start": "res://assets/audio/sfx/night_start.ogg",
		&"wave_start": "res://assets/audio/sfx/wave_start.ogg",
		&"wave_advance": "res://assets/audio/sfx/wave_advance.ogg",
		&"result_defeat": "res://assets/audio/sfx/result_defeat.ogg",
		&"result_victory": "res://assets/audio/sfx/result_victory.ogg",
	}
	for key_variant: Variant in expected_paths.keys():
		var key := StringName(key_variant)
		var path := String(expected_paths[key])
		_expect(String(sfx_paths.get(key, "")) == path, "%s maps to %s" % [key, path])
		_expect(ResourceLoader.exists(path), "%s resource exists" % path)


func _test_enemy_death_tiering(audio_manager: Node) -> void:
	_expect(_enemy_death_key(audio_manager, {"max_hp": 80, "core_damage": 1}) == &"enemy_death_small", "low hp enemy uses small death sfx")
	_expect(_enemy_death_key(audio_manager, {"max_hp": 400, "core_damage": 1}) == &"enemy_death_large", "400 hp enemy uses large death sfx")
	_expect(_enemy_death_key(audio_manager, {"max_hp": 120, "core_damage": 2}) == &"enemy_death_large", "core damage 2 enemy uses large death sfx")
	_expect(_enemy_death_key(audio_manager, {"max_hp": 120, "block_weight": 2}) == &"enemy_death_large", "block weight 2 enemy uses large death sfx")
	_expect(_enemy_death_key(audio_manager, {"behavior_type": "boss", "max_hp": 1}) == &"enemy_death_large", "boss uses large death sfx")


func _enemy_death_key(audio_manager: Node, enemy_cfg: Dictionary) -> StringName:
	return StringName(audio_manager.call("get_enemy_death_sfx_key_for_cfg", enemy_cfg))


func _test_enemy_death_variation(audio_manager: Node) -> void:
	var cooldowns: Dictionary = audio_manager.get("sfx_cooldowns")
	_expect(is_equal_approx(float(cooldowns.get(&"enemy_death_small", 0.0)), 0.08), "small death sfx cooldown is tuned")
	_expect(is_equal_approx(float(cooldowns.get(&"enemy_death_large", 0.0)), 0.15), "large death sfx cooldown is tuned")
	var small_pitch_valid := true
	var large_pitch_valid := true
	var small_volume_valid := true
	var large_volume_valid := true
	for _i in range(16):
		var small_pitch := float(audio_manager.call("_get_sfx_pitch_scale", &"enemy_death_small"))
		var large_pitch := float(audio_manager.call("_get_sfx_pitch_scale", &"enemy_death_large"))
		var small_volume := float(audio_manager.call("_get_sfx_volume_scale", &"enemy_death_small"))
		var large_volume := float(audio_manager.call("_get_sfx_volume_scale", &"enemy_death_large"))
		small_pitch_valid = small_pitch_valid and small_pitch >= 0.94 and small_pitch <= 1.08
		large_pitch_valid = large_pitch_valid and large_pitch >= 0.90 and large_pitch <= 1.04
		small_volume_valid = small_volume_valid and small_volume >= 0.78 and small_volume <= 0.96
		large_volume_valid = large_volume_valid and large_volume >= 0.86 and large_volume <= 1.0
	_expect(small_pitch_valid, "small death pitch variation stays in range")
	_expect(large_pitch_valid, "large death pitch variation stays in range")
	_expect(small_volume_valid, "small death volume variation stays in range")
	_expect(large_volume_valid, "large death volume variation stays in range")


func _test_sfx_gain_policy(audio_manager: Node) -> void:
	audio_manager.set("master_volume", 0.85)
	audio_manager.set("sfx_volume", 0.85)
	_expect(is_equal_approx(float(audio_manager.call("_base_sfx_linear_volume")), 0.85 * 0.85 * 1.18), "global sfx gain raises baseline volume")
	_expect(is_equal_approx(float(audio_manager.call("_get_sfx_volume_scale", &"core_hit")), 1.35), "core hit gets warning gain")
	_expect(is_equal_approx(float(audio_manager.call("_get_sfx_volume_scale", &"core_destroyed")), 1.15), "core destroyed gets extra gain")
	_expect(float(audio_manager.call("_get_sfx_volume_scale", &"night_start")) >= 1.5, "night start gets foreground gain")
	_expect(float(audio_manager.call("_get_sfx_volume_scale", &"wave_start")) >= 1.6, "wave start gets foreground gain")
	_expect(float(audio_manager.call("_get_sfx_volume_scale", &"wave_advance")) >= 1.6, "wave advance gets foreground gain")
	_expect(float(audio_manager.call("_get_sfx_volume_scale", &"result_defeat")) >= 1.15, "defeat result gets foreground gain")
	_expect(float(audio_manager.call("_get_sfx_volume_scale", &"result_victory")) >= 1.15, "victory result gets foreground gain")
	_expect(float(audio_manager.call("_get_sfx_pitch_scale", &"wave_start")) > 1.0, "wave start gets sharper pitch")
	_expect(float(audio_manager.call("_get_sfx_pitch_scale", &"wave_advance")) > 1.0, "wave advance gets sharper pitch")


func _test_sfx_prewarm_cache(audio_manager: Node) -> void:
	var stream_cache: Dictionary = audio_manager.get("_stream_cache")
	var sfx_paths: Dictionary = audio_manager.get("sfx_paths")
	for key in [&"core_hit", &"core_destroyed", &"building_hit", &"building_destroyed"]:
		var path := String(sfx_paths.get(key, ""))
		_expect(stream_cache.has(path), "%s is prewarmed" % key)


func _test_core_destroyed_result_delay() -> void:
	_expect(float(GameControllerScript.CORE_DESTROYED_RESULT_DELAY) >= 1.8, "core destroyed waits before result scene")
	_expect(is_equal_approx(float(GameControllerScript.DEFEAT_RESULT_HIT_DELAY), 1.656), "defeat result scene aligns to hit time")
	_expect(is_equal_approx(float(GameControllerScript.VICTORY_RESULT_HIT_DELAY), 1.35), "victory result scene aligns to hit time")


func _test_night_transition_delay() -> void:
	_expect(float(GameControllerScript.NIGHT_START_TRANSITION_DELAY) >= 5.0, "night start transition lets bgm fade in before waves")


func _test_run_end_audio_delay() -> void:
	_expect(float(GameControllerScript.RUN_END_AUDIO_DELAY) >= 1.8, "run end waits for bgm fade before result scene")


func _test_core_destroyed_emits_once() -> void:
	var run_state := root.get_node_or_null("/root/RunState")
	if run_state == null:
		push_warning("RunState autoload unavailable; skipping duplicate core destroyed signal test.")
		return
	var previous_hp := int(run_state.get("core_hp"))
	var previous_max_hp := int(run_state.get("core_hp_max"))
	var event_bus := root.get_node_or_null("/root/EventBus")
	if event_bus == null:
		push_warning("EventBus autoload unavailable; skipping duplicate core destroyed signal test.")
		return
	_core_destroyed_count = 0
	event_bus.core_destroyed.connect(_on_core_destroyed_for_test)
	run_state.set("core_hp_max", 10)
	run_state.set("core_hp", 2)
	run_state.damage_core(2)
	run_state.damage_core(1)
	event_bus.core_destroyed.disconnect(_on_core_destroyed_for_test)
	run_state.set("core_hp_max", previous_max_hp)
	run_state.set("core_hp", previous_hp)
	_expect(_core_destroyed_count == 1, "core destroyed emits only on hp crossing zero")


func _on_core_destroyed_for_test() -> void:
	_core_destroyed_count += 1


func _test_event_handlers_exist(audio_manager: Node) -> void:
	for method_name in [
		"_on_core_damaged",
		"_on_core_destroyed",
		"_on_run_ending",
		"_on_building_destroyed",
		"_on_enemy_died",
		"_on_night_started",
		"_on_night_wave_started",
		"_on_run_ending",
		"_play_night_start_sfx_after_click",
		"play_detached_sfx",
	]:
		_expect(audio_manager.has_method(method_name), "%s handler exists" % method_name)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_failures += 1
		push_error("[FAIL] %s" % message)


func _finish() -> void:
	if _failures > 0:
		quit(1)
	else:
		print("Key SFX tests passed.")
		quit(0)
