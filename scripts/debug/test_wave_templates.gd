extends SceneTree

const Resolver = preload("res://scripts/enemy/night_template_resolver.gd")

var _failures: int = 0


func _init() -> void:
	var templates := _load_templates()
	_check_data(templates)
	_check_resolver(templates)
	if _failures == 0:
		print("ALL WAVE TEMPLATE TESTS PASSED")
		quit(0)
	else:
		printerr("WAVE TEMPLATE TESTS FAILED: %d" % _failures)
		quit(1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: %s" % msg)


func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	_expect(file != null, "open %s" % path)
	return JSON.parse_string(file.get_as_text()) if file != null else null


func _load_templates() -> Array:
	var parsed: Variant = _load_json("res://data/wave_templates.json")
	_expect(typeof(parsed) == TYPE_ARRAY, "templates is array")
	return parsed if typeof(parsed) == TYPE_ARRAY else []


func _check_data(templates: Array) -> void:
	_expect(templates.size() == 15, "15 templates (got %d)" % templates.size())

	var enemies_parsed: Variant = _load_json("res://data/enemies.json")
	var enemy_ids: Dictionary = {}
	var boss_ids: Dictionary = {}
	if typeof(enemies_parsed) == TYPE_ARRAY:
		for enemy_variant: Variant in enemies_parsed:
			if typeof(enemy_variant) == TYPE_DICTIONARY:
				var enemy: Dictionary = enemy_variant
				enemy_ids[StringName(enemy.get("id", ""))] = true
				if enemy.get("behavior_type", "") == "boss":
					boss_ids[StringName(enemy.get("id", ""))] = true

	var valid_tiers := {&"early": true, &"mid": true, &"late": true, &"boss": true}
	var valid_lanes := {"main": true, "flank": true, "any": true}
	var seen_ids: Dictionary = {}
	var tier_counts: Dictionary = {}
	for template_variant: Variant in templates:
		_expect(typeof(template_variant) == TYPE_DICTIONARY, "template is dict")
		if typeof(template_variant) != TYPE_DICTIONARY:
			continue
		var template: Dictionary = template_variant
		var id := StringName(template.get("id", ""))
		_expect(id != StringName(), "template has id")
		_expect(not seen_ids.has(id), "template id unique: %s" % id)
		seen_ids[id] = true
		_expect(String(template.get("name", "")) != "", "%s has name" % id)
		_expect(String(template.get("desc", "")) != "", "%s has desc" % id)
		var tier := StringName(template.get("tier", ""))
		_expect(valid_tiers.has(tier), "%s tier valid" % id)
		tier_counts[tier] = int(tier_counts.get(tier, 0)) + 1
		var key_enemies: Array = template.get("key_enemies", [])
		_expect(not key_enemies.is_empty(), "%s has key_enemies" % id)
		for key_enemy: Variant in key_enemies:
			_expect(enemy_ids.has(StringName(key_enemy)), "%s key enemy valid: %s" % [id, key_enemy])
		var groups: Array = template.get("groups", [])
		_expect(groups.size() > 0, "%s has groups" % id)
		_expect(not template.has("entries"), "%s legacy entries removed" % id)
		var main_count := 0
		for group_variant: Variant in groups:
			_expect(typeof(group_variant) == TYPE_DICTIONARY, "%s group is dict" % id)
			if typeof(group_variant) != TYPE_DICTIONARY:
				continue
			var group: Dictionary = group_variant
			var enemy_id := StringName(group.get("enemy_id", ""))
			var choices: Array = group.get("enemy_choices", [])
			if enemy_id != StringName():
				_expect(enemy_ids.has(enemy_id), "%s enemy_id valid: %s" % [id, enemy_id])
			else:
				_expect(not choices.is_empty(), "%s has enemy_id or enemy_choices" % id)
				for choice_variant: Variant in choices:
					if typeof(choice_variant) == TYPE_DICTIONARY:
						var choice: Dictionary = choice_variant
						_expect(enemy_ids.has(StringName(choice.get("enemy_id", ""))), "%s enemy_choice valid" % id)
			_expect(not group.has("spawn_key"), "%s group has no hardcoded spawn_key" % id)
			var lane := String(group.get("lane", ""))
			_expect(valid_lanes.has(lane), "%s lane valid: %s" % [id, lane])
			if boss_ids.has(enemy_id):
				_expect(lane == "main", "%s boss group must be main" % id)
			if lane == "main":
				main_count += 1
			_expect(int(group.get("count", 0)) > 0, "%s count positive" % id)
			_expect(float(group.get("time", -1.0)) >= 0.0, "%s time non-negative" % id)
			_expect(float(group.get("interval", -1.0)) >= 0.0, "%s interval non-negative" % id)
		_expect(main_count >= 1, "%s has at least one main group" % id)
	_expect(int(tier_counts.get(&"early", 0)) == 4, "early template count")
	_expect(int(tier_counts.get(&"mid", 0)) == 5, "mid template count")
	_expect(int(tier_counts.get(&"late", 0)) == 4, "late template count")
	_expect(int(tier_counts.get(&"boss", 0)) == 2, "boss template count")


func _ids_by_tier(templates: Array, tier: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for template_variant: Variant in templates:
		if typeof(template_variant) != TYPE_DICTIONARY:
			continue
		var template: Dictionary = template_variant
		if StringName(template.get("tier", "")) == tier:
			ids.append(StringName(template.get("id", "")))
	return ids


func _check_resolver(templates: Array) -> void:
	_expect(Resolver.tier_for_day(1) == &"early", "day 1 tier")
	_expect(Resolver.tier_for_day(3) == &"early", "day 3 first-wave tier")
	_expect(Resolver.tier_for_day(5) == &"mid", "day 5 first-wave tier")
	_expect(Resolver.tier_for_day(6) == &"late", "day 6 first-wave tier")
	for day in range(1, 7):
		var tier := Resolver.tier_for_day(day)
		var pool := _ids_by_tier(templates, tier)
		var first := Resolver.resolve(pool, [], 12345, day)
		var second := Resolver.resolve(pool, [], 12345, day)
		_expect(first == second, "resolver deterministic day %d" % day)
		_expect(pool.has(first), "resolver returns id from tier pool day %d" % day)
	var early := _ids_by_tier(templates, &"early")
	var used: Array[StringName] = []
	for _i in range(early.size()):
		var id := Resolver.resolve(early, used, 101, 1)
		_expect(not used.has(id), "resolver avoids used ids")
		used.append(id)
	var recycled := Resolver.resolve(early, used, 101, 1)
	_expect(early.has(recycled), "resolver falls back to full pool")
