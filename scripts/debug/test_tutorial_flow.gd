extends SceneTree

const TutorialManagerScript = preload("res://scripts/core/tutorial_manager.gd")


func _init() -> void:
	var manager := TutorialManagerScript.new()
	var steps: Array = manager.get("_steps")
	var skill_index := _find_step_index(steps, TutorialManagerScript.STEP_SKILL)
	var defense_index := _find_step_index(steps, TutorialManagerScript.STEP_DEFENSE_CLEAR)
	var blessing_index := _find_step_index(steps, TutorialManagerScript.STEP_BLESSING)
	_expect(skill_index >= 0, "skill step exists")
	_expect(defense_index == skill_index + 1, "defense clear wait step follows skill")
	_expect(blessing_index == defense_index + 1, "blessing step follows defense clear wait step")
	_expect(bool((steps[defense_index] as Dictionary).get("wait", false)), "defense clear step waits for blessing panel")
	manager.free()
	quit(0)


func _find_step_index(steps: Array, step_id: StringName) -> int:
	for index in range(steps.size()):
		var step: Dictionary = steps[index]
		if StringName(step.get("id", "")) == step_id:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		push_error("FAIL: %s" % message)
		quit(1)
