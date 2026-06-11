extends ColorRect

## 模态抉择弹窗共享压暗遮罩:挂在 ModalLayer 首子节点,
## 兄弟 Slot 内任一面板(Event/Blessing/Result)可见即亮起并拦截背后输入。
## TutorialOverlay/DialogPanel 自带全屏底,不在本层,天然排除。

var _panels: Array[Control] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	for panel in _collect_modal_panels():
		_panels.append(panel)
		panel.visibility_changed.connect(_refresh)
	_refresh()


func _collect_modal_panels() -> Array[Control]:
	var panels: Array[Control] = []
	var layer := get_parent()
	if layer == null:
		return panels
	for slot in layer.get_children():
		if slot == self or not (slot is Control):
			continue
		for child in (slot as Control).get_children():
			if child is Control:
				panels.append(child as Control)
	return panels


func _refresh() -> void:
	for panel in _panels:
		if is_instance_valid(panel) and panel.visible:
			visible = true
			return
	visible = false
