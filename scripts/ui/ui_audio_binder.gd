extends Node

const AppRefs = preload("res://scripts/common/app_refs.gd")

const CUE_CLICK := &"ui_click"
const CUE_CONFIRM := &"ui_confirm"
const CUE_CANCEL := &"ui_cancel"
const CUE_PANEL_OPEN := &"ui_panel_open"
const CUE_PANEL_CLOSE := &"ui_panel_close"
const CUE_TAB_SWITCH := &"ui_tab_switch"
const CUE_REFRESH := &"ui_refresh"
const CUE_RELIC_OPEN := &"ui_relic_open"
const CUE_CARD_SELECT := &"ui_card_select"
const CUE_PAUSE := &"ui_pause"
const CUE_SPEED_TOGGLE := &"ui_speed_toggle"
const CUE_SLIDER := &"ui_slider"

const BUTTON_CUE_BY_NAME := {
	"CloseButton": CUE_PANEL_CLOSE,
	"MenuButton": CUE_CANCEL,
	"RetryButton": CUE_CONFIRM,
	"StartButton": CUE_CONFIRM,
	"StartNightButton": CUE_CONFIRM,
	"TriggerEventButton": CUE_CONFIRM,
	"CollectButton": CUE_CONFIRM,
	"RepairButton": CUE_CONFIRM,
	"DemolishButton": CUE_CANCEL,
	"ToggleButton": CUE_REFRESH,
	"RefreshShopButton": CUE_REFRESH,
	"BuildModeButton": CUE_TAB_SWITCH,
	"ShopModeButton": CUE_TAB_SWITCH,
	"ResourceCategoryButton": CUE_TAB_SWITCH,
	"AuraCategoryButton": CUE_TAB_SWITCH,
	"BlockCategoryButton": CUE_TAB_SWITCH,
	"IdleButton": CUE_CLICK,
	"ExploreButton": CUE_CLICK,
	"AudioSettingsButton": CUE_PANEL_OPEN,
	"EntryButton": CUE_RELIC_OPEN,
	"CastSkillButton": CUE_CONFIRM,
	"RetreatButton": CUE_CANCEL,
	"PurchaseButton": CUE_CONFIRM,
	"SpeedToggleButton": CUE_SPEED_TOGGLE,
	"PauseButton": CUE_PAUSE
}

var _bound_nodes: Dictionary = {}
var _bound_sliders: Dictionary = {}
var _bound_pressable_controls: Dictionary = {}
var _bound_operator_cards: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_existing_controls()
	var tree := get_tree()
	if tree != null:
		tree.node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _bind_existing_controls() -> void:
	var root := get_parent()
	if root == null:
		root = get_tree().current_scene
	if root == null:
		return
	for node in root.find_children("*", "", true, false):
		_bind_control(node)


func _on_node_added(node: Node) -> void:
	if not is_inside_tree():
		return
	if _is_inside_bound_root(node):
		_bind_control_deferred(node.get_instance_id())


func _bind_control_deferred(instance_id: int) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var node := instance_from_id(instance_id)
	if node == null or not is_instance_valid(node) or not _is_inside_bound_root(node):
		return
	_bind_control(node)


func _bind_control(node: Object) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is BaseButton:
		_bind_button(node as BaseButton)
	elif node is Slider:
		_bind_slider(node as Slider)
	elif node is Control and node.has_signal("pressed"):
		_bind_pressable_control(node as Control)
	elif node is Control and node.has_signal("operator_card_pressed"):
		_bind_operator_card(node as Control)


func _bind_button(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		return
	var key := button.get_instance_id()
	if _bound_nodes.has(key):
		return
	_bound_nodes[key] = true
	button.pressed.connect(_on_button_pressed.bind(button))
	button.tree_exited.connect(_on_bound_node_tree_exited.bind(key))


func _bind_slider(slider: Slider) -> void:
	if slider == null or not is_instance_valid(slider):
		return
	var key := slider.get_instance_id()
	if _bound_sliders.has(key):
		return
	_bound_sliders[key] = true
	slider.drag_ended.connect(_on_slider_drag_ended.bind(slider))
	slider.tree_exited.connect(_on_bound_slider_tree_exited.bind(key))


func _bind_pressable_control(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var key := control.get_instance_id()
	if _bound_pressable_controls.has(key):
		return
	_bound_pressable_controls[key] = true
	var callable := _make_pressable_callable(control)
	if callable.is_valid():
		control.connect(&"pressed", callable)
	control.tree_exited.connect(_on_bound_pressable_control_tree_exited.bind(key))


func _bind_operator_card(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var key := control.get_instance_id()
	if _bound_operator_cards.has(key):
		return
	_bound_operator_cards[key] = true
	control.connect(&"operator_card_pressed", func(_operator_key: StringName) -> void:
		_on_operator_card_pressed(control)
	)
	control.tree_exited.connect(_on_bound_operator_card_tree_exited.bind(key))


func _on_button_pressed(button: Object) -> void:
	if button == null or not is_instance_valid(button) or not (button is BaseButton):
		return
	var base_button := button as BaseButton
	if base_button.disabled:
		return
	_emit_cue(_cue_for_button(base_button))


func _on_slider_drag_ended(_value_changed: bool, slider: Object) -> void:
	if slider == null or not is_instance_valid(slider):
		return
	_emit_cue(CUE_SLIDER)


func _make_pressable_callable(control: Control) -> Callable:
	var pressed_signal := _get_signal_info(control, &"pressed")
	var arg_count := 0
	if not pressed_signal.is_empty():
		arg_count = (pressed_signal.get("args", []) as Array).size()
	match arg_count:
		0:
			return func() -> void:
				_on_pressable_control_pressed(control)
		1:
			return func(_arg1: Variant) -> void:
				_on_pressable_control_pressed(control)
		_:
			return Callable()


func _on_pressable_control_pressed(control: Object) -> void:
	if control == null or not is_instance_valid(control) or not (control is Control):
		return
	_emit_cue(_cue_for_pressable_control(control as Control))


func _on_operator_card_pressed(control: Object) -> void:
	if control == null or not is_instance_valid(control):
		return
	_emit_cue(CUE_CARD_SELECT)


func _cue_for_button(button: BaseButton) -> StringName:
	if button.has_meta("audio_cue"):
		return StringName(button.get_meta("audio_cue"))
	var node_name := String(button.name)
	if BUTTON_CUE_BY_NAME.has(node_name):
		return BUTTON_CUE_BY_NAME[node_name]
	return CUE_CLICK


func _cue_for_pressable_control(control: Control) -> StringName:
	if control.has_meta("audio_cue"):
		return StringName(control.get_meta("audio_cue"))
	return CUE_CARD_SELECT


func _get_signal_info(node: Object, signal_name: StringName) -> Dictionary:
	for signal_info in node.get_signal_list():
		if StringName(signal_info.get("name", "")) == signal_name:
			return signal_info
	return {}


func _is_inside_bound_root(node: Object) -> bool:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return false
	var root := get_parent()
	var cursor := node as Node
	while cursor != null:
		if cursor == root:
			return true
		cursor = cursor.get_parent()
	return false


func _on_bound_node_tree_exited(instance_id: int) -> void:
	_bound_nodes.erase(instance_id)


func _on_bound_slider_tree_exited(instance_id: int) -> void:
	_bound_sliders.erase(instance_id)


func _on_bound_pressable_control_tree_exited(instance_id: int) -> void:
	_bound_pressable_controls.erase(instance_id)


func _on_bound_operator_card_tree_exited(instance_id: int) -> void:
	_bound_operator_cards.erase(instance_id)


func _emit_cue(cue_key: StringName) -> void:
	var event_bus = AppRefs.event_bus()
	if event_bus != null:
		event_bus.audio_cue_requested.emit(cue_key)
