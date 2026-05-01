class_name UiLayoutAudit
extends RefCounted


static func collect_issues(root: Control) -> PackedStringArray:
	var issues := PackedStringArray()
	if root == null:
		issues.append("Root control is null.")
		return issues
	var viewport_rect := Rect2(Vector2.ZERO, root.get_viewport_rect().size)
	_collect_control_issues(root, viewport_rect, issues)
	return issues


static func _collect_control_issues(control: Control, viewport_rect: Rect2, issues: PackedStringArray) -> void:
	if not control.visible:
		return
	var rect := Rect2(control.global_position, control.size)
	var min_size := control.get_combined_minimum_size()
	if control.size.x + 0.5 < min_size.x or control.size.y + 0.5 < min_size.y:
		issues.append("%s is smaller than its minimum size. size=%s min=%s" % [control.get_path(), control.size, min_size])
	if not _rect_inside(rect, viewport_rect):
		issues.append("%s is outside viewport. rect=%s viewport=%s" % [control.get_path(), rect, viewport_rect])
	for child in control.get_children():
		if child is Control:
			_collect_control_issues(child as Control, viewport_rect, issues)


static func _rect_inside(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.x >= bounds.position.x - 0.5 \
		and rect.position.y >= bounds.position.y - 0.5 \
		and rect.end.x <= bounds.end.x + 0.5 \
		and rect.end.y <= bounds.end.y + 0.5
