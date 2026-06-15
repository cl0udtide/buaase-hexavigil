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
	_test_bgm_paths(audio_manager)
	_test_sfx_paths(audio_manager)
	_test_boss_audio_config(audio_manager)
	_test_enemy_death_tiering(audio_manager)
	_test_enemy_death_variation(audio_manager)
	_test_sfx_gain_policy(audio_manager)
	_test_boss_long_cue_policy(audio_manager)
	_test_pooled_sfx_reuse_policy(audio_manager)
	_test_sfx_prewarm_cache(audio_manager)
	_test_boss_nailoong_voice_pool(audio_manager)
	await _test_boss_voice_pause_policy(audio_manager)
	_test_audio_process_mode(audio_manager)
	_test_core_destroyed_result_delay()
	_test_night_transition_delay()
	_test_run_end_audio_delay()
	_test_boss_death_result_delay()
	_test_core_destroyed_emits_once()
	_test_boss_audio_runtime(audio_manager)
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
		&"boss_nailoong_intro_roar": "res://assets/audio/sfx/boss_nailoong_intro_roar.ogg",
		&"boss_nailoong_phase_roar": "res://assets/audio/sfx/boss_nailoong_phase_roar.ogg",
		&"boss_nailoong_death": "res://assets/audio/sfx/boss_nailoong_death.ogg",
		&"boss_nailoong_voice1": "res://assets/audio/sfx/boss_nailoong_voice1.ogg",
		&"boss_nailoong_voice2": "res://assets/audio/sfx/boss_nailoong_voice2.ogg",
		&"boss_nailoong_voice3": "res://assets/audio/sfx/boss_nailoong_voice3.ogg",
		&"boss_nailoong_phase2_laugh": "res://assets/audio/sfx/boss_nailoong_phase2_laugh.ogg",
		&"boss_penguin_intro_roar": "res://assets/audio/sfx/boss_penguin_intro_roar.ogg",
		&"boss_penguin_phase_roar": "res://assets/audio/sfx/boss_penguin_phase_roar.ogg",
		&"boss_penguin_death": "res://assets/audio/sfx/boss_penguin_death.ogg",
		&"boss_penguin_voice1": "res://assets/audio/sfx/boss_penguin_voice1.ogg",
		&"boss_penguin_voice2": "res://assets/audio/sfx/boss_penguin_voice2.ogg",
		&"boss_penguin_voice3": "res://assets/audio/sfx/boss_penguin_voice3.ogg",
		&"boss_penguin_voice4": "res://assets/audio/sfx/boss_penguin_voice4.ogg",
	}
	for key_variant: Variant in expected_paths.keys():
		var key := StringName(key_variant)
		var path := String(expected_paths[key])
		_expect(String(sfx_paths.get(key, "")) == path, "%s maps to %s" % [key, path])
		_expect(ResourceLoader.exists(path), "%s resource exists" % path)


func _test_bgm_paths(audio_manager: Node) -> void:
	var bgm_paths: Dictionary = audio_manager.get("bgm_paths")
	var expected_paths := {
		&"boss_nailoong": "res://assets/audio/bgm/boss_nailoong.ogg",
		&"boss_coucou_penguin": "res://assets/audio/bgm/boss_coucou_penguin.ogg",
	}
	for key_variant: Variant in expected_paths.keys():
		var key := StringName(key_variant)
		var path := String(expected_paths[key])
		_expect(String(bgm_paths.get(key, "")) == path, "%s maps to %s" % [key, path])
		_expect(ResourceLoader.exists(path), "%s resource exists" % path)
	var boss_bgm_keys: Dictionary = audio_manager.get("boss_bgm_keys")
	_expect(StringName(boss_bgm_keys.get(&"milk_dragon_chief", StringName())) == &"boss_nailoong", "milk_dragon_chief maps to dedicated boss bgm")
	_expect(StringName(boss_bgm_keys.get(&"coucou_penguin", StringName())) == &"boss_coucou_penguin", "coucou_penguin maps to dedicated boss bgm")


func _test_boss_audio_config(audio_manager: Node) -> void:
	var boss_intro_sfx_keys: Dictionary = audio_manager.get("boss_intro_sfx_keys")
	var boss_phase_sfx_keys: Dictionary = audio_manager.get("boss_phase_sfx_keys")
	var boss_death_sfx_keys: Dictionary = audio_manager.get("boss_death_sfx_keys")
	var boss_voice_sfx_pools: Dictionary = audio_manager.get("boss_voice_sfx_pools")
	_expect(StringName(boss_intro_sfx_keys.get(&"milk_dragon_chief", StringName())) == &"boss_nailoong_intro_roar", "milk_dragon_chief has intro roar")
	_expect(StringName(boss_phase_sfx_keys.get(&"milk_dragon_chief", StringName())) == &"boss_nailoong_phase_roar", "milk_dragon_chief has phase roar")
	_expect(StringName(boss_death_sfx_keys.get(&"milk_dragon_chief", StringName())) == &"boss_nailoong_death", "milk_dragon_chief has dedicated death sfx")
	var nailoong_pool: Array = boss_voice_sfx_pools.get(&"milk_dragon_chief", [])
	_expect(nailoong_pool.size() == 4, "milk_dragon_chief uses four weighted voices")
	_expect(nailoong_pool.has(&"boss_nailoong_voice1"), "milk_dragon_chief pool contains voice1")
	_expect(nailoong_pool.has(&"boss_nailoong_voice2"), "milk_dragon_chief pool contains voice2")
	_expect(nailoong_pool.has(&"boss_nailoong_voice3"), "milk_dragon_chief pool contains voice3")
	_expect(nailoong_pool.has(&"boss_nailoong_phase2_laugh"), "milk_dragon_chief pool contains phase2 laugh")
	_expect(StringName(boss_intro_sfx_keys.get(&"coucou_penguin", StringName())) == &"boss_penguin_intro_roar", "coucou_penguin has intro roar")
	_expect(StringName(boss_phase_sfx_keys.get(&"coucou_penguin", StringName())) == &"boss_penguin_phase_roar", "coucou_penguin has phase roar")
	_expect(StringName(boss_death_sfx_keys.get(&"coucou_penguin", StringName())) == &"boss_penguin_death", "coucou_penguin has dedicated death sfx")
	var voice_pool: Array = boss_voice_sfx_pools.get(&"coucou_penguin", [])
	_expect(voice_pool.size() == 4, "coucou_penguin has four equal random voices")
	for voice_key in [&"boss_penguin_voice1", &"boss_penguin_voice2", &"boss_penguin_voice3", &"boss_penguin_voice4"]:
		_expect(voice_pool.has(voice_key), "voice pool contains %s" % voice_key)
	_expect(not voice_pool.has(&"boss_penguin_phase2_laugh"), "coucou_penguin does not use phase2-only voice")
	_expect(is_equal_approx(float(AudioManagerScript.BOSS_PENGUIN_PHASE_TWO_BGM_PITCH), 1.15), "boss phase two bgm pitch is 1.15")
	_expect(float(AudioManagerScript.BOSS_PENGUIN_RANDOM_VOICE_AFTER_INTRO_GRACE) > float(AudioManagerScript.BOSS_PENGUIN_INTRO_ROAR_SECONDS), "penguin random voice waits beyond intro roar")
	_expect(float(AudioManagerScript.BOSS_PENGUIN_RANDOM_VOICE_AFTER_PHASE_GRACE) > float(AudioManagerScript.BOSS_PENGUIN_PHASE_ROAR_SECONDS), "penguin random voice waits beyond phase roar")
	_expect(float(AudioManagerScript.BOSS_RANDOM_VOICE_MIN_COOLDOWN) >= 7.0, "boss random voice cooldown has a safe lower bound")
	_expect(float(AudioManagerScript.BOSS_RANDOM_VOICE_MAX_COOLDOWN) > float(AudioManagerScript.BOSS_RANDOM_VOICE_MIN_COOLDOWN), "boss random voice cooldown has random range")
	_expect(float(AudioManagerScript.BOSS_PHASE_TWO_RANDOM_VOICE_MIN_COOLDOWN) >= 4.0, "phase two boss voice cooldown keeps a safe lower bound")
	_expect(float(AudioManagerScript.BOSS_PHASE_TWO_RANDOM_VOICE_MAX_COOLDOWN) < float(AudioManagerScript.BOSS_RANDOM_VOICE_MAX_COOLDOWN), "phase two boss voice cooldown is more frequent")
	_expect(float(AudioManagerScript.BOSS_PENGUIN_RANDOM_VOICE_AFTER_INTRO_GRACE) > 0.0, "boss random voice waits after intro")


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


func _test_boss_long_cue_policy(audio_manager: Node) -> void:
	var sfx_cursor_before := int(audio_manager.get("_sfx_cursor"))
	audio_manager.call("_on_enemy_spawned", 6001, &"milk_dragon_chief", Vector2i.ZERO)
	audio_manager.call("_on_boss_phase_transition_started", 6001, &"milk_dragon_chief", 2)
	audio_manager.call("_on_enemy_died", 6001, &"milk_dragon_chief")
	_expect(int(audio_manager.get("_sfx_cursor")) == sfx_cursor_before, "nailoong long cues do not consume pooled sfx players")
	audio_manager.call("_on_enemy_spawned", 7001, &"coucou_penguin", Vector2i.ZERO)
	audio_manager.call("_on_boss_phase_transition_started", 7001, &"coucou_penguin", 2)
	audio_manager.call("_on_enemy_died", 7001, &"coucou_penguin")
	_expect(int(audio_manager.get("_sfx_cursor")) == sfx_cursor_before, "penguin long cues do not consume pooled sfx players")
	var detached_player := root.find_child("DetachedResultSfxPlayer", true, false) as AudioStreamPlayer
	_expect(detached_player != null and detached_player.process_mode == Node.PROCESS_MODE_ALWAYS, "penguin detached long cue runs while paused")


func _test_boss_nailoong_voice_pool(audio_manager: Node) -> void:
	audio_manager.set("_boss_nailoong_phase", 1)
	var phase_one_pool: Array = audio_manager.call("_get_boss_nailoong_voice_pool")
	_expect(phase_one_pool.size() == 3, "phase one nailoong voice pool has three random voices")
	_expect(not phase_one_pool.has(&"boss_nailoong_phase2_laugh"), "phase one pool excludes phase2 laugh")
	audio_manager.set("_boss_nailoong_phase", 2)
	var phase_two_pool: Array = audio_manager.call("_get_boss_nailoong_voice_pool")
	_expect(phase_two_pool.size() == 5, "phase two nailoong voice pool adds weighted laugh")
	_expect(phase_two_pool.has(&"boss_nailoong_phase2_laugh"), "phase two pool includes phase2 laugh")
	_expect(is_equal_approx(float(AudioManagerScript.BOSS_PHASE_TWO_PITCH_SCALE), 1.15), "phase two boss bgm pitch is tense enough")


func _test_boss_voice_pause_policy(audio_manager: Node) -> void:
	var boss_voice_player := audio_manager.get("_boss_voice_player") as AudioStreamPlayer
	_expect(boss_voice_player != null and boss_voice_player.process_mode == Node.PROCESS_MODE_ALWAYS, "boss voice player exists")
	var accepted_unpaused := bool(audio_manager.call("_play_boss_voice_sfx", &"boss_nailoong_voice1"))
	await process_frame
	_expect(accepted_unpaused, "boss voice accepts playback while unpaused")
	root.get_tree().paused = true
	audio_manager.call("_update_boss_voice_pause_state")
	await process_frame
	_expect(boss_voice_player != null and not boss_voice_player.playing, "boss voice stops when game pauses")
	var accepted_paused := bool(audio_manager.call("_play_boss_voice_sfx", &"boss_nailoong_voice1"))
	await process_frame
	_expect(not accepted_paused, "boss voice will not start while paused")
	root.get_tree().paused = false


func _test_pooled_sfx_reuse_policy(audio_manager: Node) -> void:
	var sfx_players: Array = audio_manager.get("_sfx_players")
	if sfx_players.is_empty():
		_expect(false, "sfx pool exists")
		return
	var first_player := sfx_players[0] as AudioStreamPlayer
	var stream := AudioStreamGenerator.new()
	for _i in range(sfx_players.size() + 1):
		audio_manager.call("play_sfx_stream", stream)
	_expect(first_player != null and first_player.stream == stream, "pooled sfx players are reused cyclically")


func _test_sfx_prewarm_cache(audio_manager: Node) -> void:
	var stream_cache: Dictionary = audio_manager.get("_stream_cache")
	var sfx_paths: Dictionary = audio_manager.get("sfx_paths")
	for key in [&"core_hit", &"core_destroyed", &"building_hit", &"building_destroyed"]:
		var path := String(sfx_paths.get(key, ""))
		_expect(stream_cache.has(path), "%s is prewarmed" % key)


func _test_audio_process_mode(audio_manager: Node) -> void:
	_expect(audio_manager.process_mode == Node.PROCESS_MODE_ALWAYS, "audio manager runs while story pauses the tree")
	var bgm_player := audio_manager.get("_bgm_player") as AudioStreamPlayer
	_expect(bgm_player != null and bgm_player.process_mode == Node.PROCESS_MODE_ALWAYS, "bgm player runs while paused")
	var sfx_players: Array = audio_manager.get("_sfx_players")
	var sfx_modes_valid := not sfx_players.is_empty()
	for player_variant in sfx_players:
		var player := player_variant as AudioStreamPlayer
		sfx_modes_valid = sfx_modes_valid and player != null and player.process_mode == Node.PROCESS_MODE_ALWAYS
	_expect(sfx_modes_valid, "sfx players run while paused")


func _test_core_destroyed_result_delay() -> void:
	_expect(float(GameControllerScript.CORE_DESTROYED_RESULT_DELAY) >= 1.8, "core destroyed waits before result scene")
	_expect(is_equal_approx(float(GameControllerScript.DEFEAT_RESULT_HIT_DELAY), 1.656), "defeat result scene aligns to hit time")
	_expect(is_equal_approx(float(GameControllerScript.VICTORY_RESULT_HIT_DELAY), 1.35), "victory result scene aligns to hit time")
	_expect(float(GameControllerScript.BOSS_DEATH_RESULT_DELAY) >= 2.7, "boss death result delay protects long death voice")
	_expect(float(GameControllerScript.BOSS_DEATH_RESULT_DELAY) >= float(AudioManagerScript.BOSS_PENGUIN_DEATH_SECONDS), "boss death result delay protects penguin death voice")


func _test_night_transition_delay() -> void:
	_expect(float(GameControllerScript.NIGHT_START_TRANSITION_DELAY) >= 5.0, "night start transition lets bgm fade in before waves")


func _test_run_end_audio_delay() -> void:
	_expect(float(GameControllerScript.RUN_END_AUDIO_DELAY) >= 1.8, "run end waits for bgm fade before result scene")


func _test_boss_death_result_delay() -> void:
	var game_controller: Node = GameControllerScript.new()
	root.add_child(game_controller)
	game_controller.set("_last_boss_death_msec", Time.get_ticks_msec())
	var delay := float(game_controller.call("_victory_result_delay"))
	_expect(delay >= float(GameControllerScript.BOSS_DEATH_RESULT_DELAY) - 0.1, "recent boss death extends victory result delay")
	game_controller.set("_last_boss_death_msec", -1000000)
	_expect(is_equal_approx(float(game_controller.call("_victory_result_delay")), float(GameControllerScript.VICTORY_RESULT_HIT_DELAY)), "normal victory result delay stays aligned")
	game_controller.queue_free()


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


func _test_boss_audio_runtime(audio_manager: Node) -> void:
	var sfx_cursor_before_boss_cues := int(audio_manager.get("_sfx_cursor"))
	audio_manager.call("_on_enemy_spawned", 6001, &"milk_dragon_chief", Vector2i.ZERO)
	_expect(bool(audio_manager.get("_boss_nailoong_active")), "milk_dragon_chief starts dedicated boss voice loop")
	audio_manager.call("_on_boss_phase_transition_started", 6001, &"milk_dragon_chief", 2)
	audio_manager.call("_on_enemy_died", 6001, &"milk_dragon_chief")
	_expect(not bool(audio_manager.get("_boss_nailoong_active")), "milk_dragon_chief death stops dedicated boss voice loop")
	audio_manager.call("_on_enemy_spawned", 7001, &"coucou_penguin", Vector2i.ZERO)
	_expect(int(audio_manager.get("_active_boss_runtime_id")) == 7001, "coucou_penguin starts boss voice loop")
	_expect(float(audio_manager.get("_boss_voice_cooldown_remaining")) >= float(AudioManagerScript.BOSS_PENGUIN_RANDOM_VOICE_AFTER_INTRO_GRACE) - 0.1, "coucou_penguin intro grace delays random voice")
	var bgm_player := audio_manager.get("_bgm_player") as AudioStreamPlayer
	_expect(bgm_player == null or not bgm_player.playing or is_equal_approx(bgm_player.pitch_scale, 1.0), "boss bgm stays neutral before phase shift")
	audio_manager.call("_on_boss_phase_transition_started", 7001, &"coucou_penguin", 2)
	_expect(bgm_player != null and is_equal_approx(bgm_player.pitch_scale, 1.15), "coucou_penguin phase two raises bgm pitch")
	_expect(float(audio_manager.get("_boss_voice_cooldown_remaining")) >= float(AudioManagerScript.BOSS_PENGUIN_RANDOM_VOICE_AFTER_PHASE_GRACE) - 0.1, "coucou_penguin phase grace delays random voice")
	audio_manager.call("_play_random_boss_voice")
	var tree := audio_manager.get_tree()
	var previous_paused := false
	if tree != null:
		previous_paused = tree.paused
		tree.paused = true
	audio_manager.call("_update_boss_voice_pause_state")
	var boss_voice_player := audio_manager.get("_boss_voice_player") as AudioStreamPlayer
	_expect(boss_voice_player != null and boss_voice_player.stream != null and boss_voice_player.stream_paused, "boss voice pauses with tree pause")
	if tree != null:
		tree.paused = previous_paused
	audio_manager.call("_update_boss_voice_pause_state")
	_expect(boss_voice_player != null and not boss_voice_player.stream_paused, "boss voice resumes after tree pause")
	audio_manager.call("_on_enemy_died", 7001, &"coucou_penguin")
	_expect(int(audio_manager.get("_active_boss_runtime_id")) == 0, "coucou_penguin death stops boss voice loop")
	_expect(int(audio_manager.get("_sfx_cursor")) == sfx_cursor_before_boss_cues, "boss long cues do not consume pooled sfx players")


func _test_event_handlers_exist(audio_manager: Node) -> void:
	for method_name in [
		"_on_core_damaged",
		"_on_core_destroyed",
		"_on_run_ending",
		"_on_building_destroyed",
		"_on_enemy_spawned",
		"_on_enemy_died",
		"_on_boss_phase_transition_started",
		"_start_boss_nailoong_voice_loop",
		"_stop_boss_nailoong_voice_loop",
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
