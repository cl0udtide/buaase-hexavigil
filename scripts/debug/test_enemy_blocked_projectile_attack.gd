extends SceneTree

## Regression: projectile enemies should keep projectile attack behavior when blocked.
## Run: Godot --headless --path . --script scripts/debug/test_enemy_blocked_projectile_attack.gd

const EnemyAttackControllerScript = preload("res://scripts/enemy/enemy_attack_controller.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller: Node = EnemyAttackControllerScript.new()
	root.add_child(controller)
	_expect(
		bool(controller.call("uses_projectile_blocked_attack_for_cfg", {"attack_delivery": "projectile"})),
		"projectile enemy keeps projectile attack while blocked"
	)
	_expect(
		not bool(controller.call("uses_projectile_blocked_attack_for_cfg", {"attack_delivery": "instant"})),
		"instant enemy keeps melee blocked attack"
	)
	_expect(
		not bool(controller.call("uses_projectile_blocked_attack_for_cfg", {})),
		"missing delivery defaults to melee blocked attack"
	)
	controller.queue_free()
	_finish()


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
		print("Enemy blocked projectile attack tests passed.")
		quit(0)
