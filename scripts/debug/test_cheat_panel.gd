extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/combat/CombatHud.tscn")


func _init() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	if not hud.has_method("toggle_settings_panel"):
		_fail("CombatHud missing settings panel toggle")
	var settings_panel := hud.get_node_or_null("PopupLayer/SettingsPanelSlot/AudioSettingsPanel") as Control
	if settings_panel == null:
		_fail("settings panel missing")
	hud.toggle_settings_panel()
	await process_frame
	if not settings_panel.visible:
		_fail("settings panel did not open")
	var cheat_open_button := settings_panel.find_child("CheatOpenButton", true, false) as Button
	if cheat_open_button == null:
		_fail("cheat entry button missing from settings panel")
	if settings_panel.find_child("CheatScroll", true, false) != null:
		_fail("cheat controls should not be embedded in settings panel")
	var panel_size := settings_panel.size
	if panel_size.x < 400.0 or panel_size.y < 326.0:
		_fail("settings panel size is invalid: %s" % panel_size)
	cheat_open_button.emit_signal("pressed")
	await process_frame
	if settings_panel.visible:
		_fail("settings panel should close after opening cheat panel")
	var cheat_panel := hud.get_node_or_null("PopupLayer/CheatPanelSlot/CheatPanelCenter/CheatPanel") as Control
	if cheat_panel == null:
		_fail("cheat panel missing")
	if not cheat_panel.visible:
		_fail("cheat panel did not open")
	var cheat_scroll := cheat_panel.get_node_or_null("ContentMargin/MainVBox/CheatScroll") as Control
	if cheat_scroll == null or not cheat_scroll.visible:
		_fail("cheat panel scroll is not visible")
	panel_size = cheat_panel.size
	if panel_size.x < 620.0 or panel_size.y < 540.0:
		_fail("cheat panel size is invalid: %s" % panel_size)
	var center := hud.get_node_or_null("PopupLayer/CheatPanelSlot/CheatPanelCenter") as Control
	if center == null or not center.visible:
		_fail("cheat panel center container is not visible")
	if not cheat_panel.has_method("move_panel_to"):
		_fail("cheat panel does not expose movable positioning")
	var initial_position := cheat_panel.position
	cheat_panel.call("move_panel_to", initial_position + Vector2(120.0, 80.0))
	await process_frame
	if cheat_panel.position == initial_position:
		_fail("cheat panel did not move")
	cheat_panel.call("move_panel_to", Vector2(-999.0, -999.0))
	await process_frame
	if cheat_panel.position.x < 0.0 or cheat_panel.position.y < 0.0:
		_fail("cheat panel moved outside the top-left viewport bounds")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
