extends Control

const AppRefs = preload("res://scripts/common/app_refs.gd")
const AppTheme = preload("res://scripts/ui/app_theme.gd")
const GameUiStyle = preload("res://scripts/ui/game_ui_style.gd")

const TITLE_LOGO_PATH := "RightUiSlot/CenterContainer/VBoxContainer/LogoRoot/LogoPulseLayer"
const EX_LOGO_PATH := "RightUiSlot/CenterContainer/VBoxContainer/LogoRoot/ExLogoTexture"
const LOGO_FX_AURA_PATH := "RightUiSlot/CenterContainer/VBoxContainer/LogoRoot/LogoPulseLayer/LogoFxAura"
const LOGO_FX_STATIC_PATH := "RightUiSlot/CenterContainer/VBoxContainer/LogoRoot/LogoPulseLayer/LogoFxStatic"
const LOGO_FX_FLOW_A_PATH := "RightUiSlot/CenterContainer/VBoxContainer/LogoRoot/LogoPulseLayer/LogoFxFlowA"
const LOGO_FX_FLOW_B_PATH := "RightUiSlot/CenterContainer/VBoxContainer/LogoRoot/LogoPulseLayer/LogoFxFlowB"
const LOGO_FX_SPARK_PATH := "RightUiSlot/CenterContainer/VBoxContainer/LogoRoot/LogoPulseLayer/LogoFxSpark"


func _ready() -> void:
	AppTheme.apply(self)
	_apply_visual_style()
	call_deferred("_start_logo_animation")
	var start_button := get_node_or_null("%StartButton") as BaseButton
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	var tutorial_button := get_node_or_null("%TutorialButton") as BaseButton
	if tutorial_button != null:
		tutorial_button.pressed.connect(_on_tutorial_pressed)


func _on_start_pressed() -> void:
	var scene_router = AppRefs.scene_router()
	if scene_router != null:
		scene_router.goto_game()


func _on_tutorial_pressed() -> void:
	var scene_router = AppRefs.scene_router()
	if scene_router != null:
		if scene_router.has_method("goto_tutorial"):
			scene_router.goto_tutorial()
		else:
			scene_router.goto_game()


func _apply_visual_style() -> void:
	var logo_root := get_node_or_null("%LogoRoot") as Control
	if logo_root != null:
		logo_root.custom_minimum_size = Vector2(500.0, 186.0)

	var vbox := get_node_or_null("RightUiSlot/CenterContainer/VBoxContainer") as VBoxContainer
	if vbox != null:
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 16)

	var start_button := get_node_or_null("%StartButton") as Button
	if start_button != null:
		start_button.add_theme_font_size_override("font_size", 20)
		start_button.add_theme_color_override("font_color", GameUiStyle.TEXT)
		start_button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT)
		start_button.add_theme_color_override("font_pressed_color", GameUiStyle.TEXT)
		start_button.add_theme_color_override("font_focus_color", GameUiStyle.TEXT)

	var tutorial_button := get_node_or_null("%TutorialButton") as Button
	if tutorial_button != null:
		tutorial_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tutorial_button.add_theme_font_size_override("font_size", 18)
		tutorial_button.add_theme_color_override("font_color", GameUiStyle.TEXT)
		tutorial_button.add_theme_color_override("font_hover_color", GameUiStyle.TEXT)
		tutorial_button.add_theme_color_override("font_pressed_color", GameUiStyle.TEXT)
		tutorial_button.add_theme_color_override("font_focus_color", GameUiStyle.TEXT)


func _start_logo_animation() -> void:
	var title_layer := get_node_or_null(TITLE_LOGO_PATH) as Control
	if title_layer != null:
		title_layer.pivot_offset = title_layer.size * 0.5
		title_layer.scale = Vector2.ONE
		title_layer.modulate = Color.WHITE

	var logo_fx_static := get_node_or_null(LOGO_FX_STATIC_PATH) as TextureRect
	if logo_fx_static != null:
		logo_fx_static.pivot_offset = logo_fx_static.size * 0.5
		logo_fx_static.rotation_degrees = 0.0
		logo_fx_static.scale = Vector2.ONE
		logo_fx_static.modulate = Color(0.82, 0.96, 1.0, 0.34)

	var logo_fx_aura := get_node_or_null(LOGO_FX_AURA_PATH) as TextureRect
	_start_logo_fx_aura(logo_fx_aura)

	var flow_a := get_node_or_null(LOGO_FX_FLOW_A_PATH) as TextureRect
	_start_logo_fx_flow(flow_a, Vector2(-150.0, -24.0), Vector2(78.0, -30.0), 0.0, 2.55, 0.52)

	var flow_b := get_node_or_null(LOGO_FX_FLOW_B_PATH) as TextureRect
	_start_logo_fx_flow(flow_b, Vector2(-72.0, 8.0), Vector2(84.0, 26.0), 0.0, 3.15, 0.34)

	var spark_layer := get_node_or_null(LOGO_FX_SPARK_PATH) as TextureRect
	_start_logo_fx_spark(spark_layer)

	var ex_logo := get_node_or_null(EX_LOGO_PATH) as TextureRect
	if ex_logo != null:
		ex_logo.pivot_offset = ex_logo.size * 0.5
		ex_logo.rotation_degrees = -24.0
		ex_logo.scale = Vector2.ONE
		ex_logo.modulate = Color.WHITE
		var ex_tween: Tween = create_tween().set_loops()
		ex_tween.tween_interval(0.35)
		ex_tween.tween_property(ex_logo, "rotation_degrees", -13.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ex_tween.parallel().tween_property(ex_logo, "scale", Vector2(1.08, 1.08), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ex_tween.parallel().tween_property(ex_logo, "modulate", Color(1.0, 0.96, 0.84, 1.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		ex_tween.tween_property(ex_logo, "rotation_degrees", -28.0, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		ex_tween.parallel().tween_property(ex_logo, "scale", Vector2(1.01, 1.01), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ex_tween.tween_property(ex_logo, "rotation_degrees", -24.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ex_tween.parallel().tween_property(ex_logo, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ex_tween.parallel().tween_property(ex_logo, "modulate", Color.WHITE, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ex_tween.tween_interval(1.55)


func _start_logo_fx_flow(flow_layer: TextureRect, start_position: Vector2, end_position: Vector2, delay: float, duration: float, peak_alpha: float) -> void:
	if flow_layer == null:
		return
	flow_layer.pivot_offset = flow_layer.size * 0.5
	var phase := clampf(delay / duration, 0.0, 0.95)
	flow_layer.position = start_position.lerp(end_position, phase)
	flow_layer.rotation_degrees = 0.0
	flow_layer.scale = Vector2.ONE
	var low_alpha := peak_alpha * 0.18
	flow_layer.modulate = Color(0.78, 0.98, 1.0, low_alpha)
	var move_tween: Tween = create_tween().set_loops()
	move_tween.tween_property(flow_layer, "position", end_position, duration * (1.0 - phase)).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	move_tween.tween_callback(_reset_logo_fx_flow.bind(flow_layer, start_position))
	move_tween.tween_property(flow_layer, "position", end_position, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	move_tween.tween_callback(_reset_logo_fx_flow.bind(flow_layer, start_position))

	var alpha_tween: Tween = create_tween().set_loops()
	alpha_tween.tween_property(flow_layer, "modulate:a", peak_alpha, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	alpha_tween.tween_property(flow_layer, "modulate:a", low_alpha, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_logo_fx_spark(spark_layer: TextureRect) -> void:
	if spark_layer == null:
		return
	spark_layer.pivot_offset = spark_layer.size * 0.5
	spark_layer.scale = Vector2.ONE
	spark_layer.modulate = Color(1.0, 0.98, 0.86, 0.18)
	var spark_tween: Tween = create_tween().set_loops()
	spark_tween.tween_property(spark_layer, "modulate:a", 0.62, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	spark_tween.tween_property(spark_layer, "modulate:a", 0.24, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	spark_tween.tween_interval(0.42)
	spark_tween.tween_property(spark_layer, "modulate:a", 0.48, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	spark_tween.tween_property(spark_layer, "modulate:a", 0.16, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	spark_tween.tween_interval(1.15)


func _start_logo_fx_aura(aura_layer: TextureRect) -> void:
	if aura_layer == null:
		return
	aura_layer.pivot_offset = aura_layer.size * 0.5
	aura_layer.scale = Vector2(0.985, 0.985)
	aura_layer.modulate = Color(0.76, 0.96, 1.0, 0.12)
	var aura_tween: Tween = create_tween().set_loops()
	aura_tween.tween_property(aura_layer, "modulate:a", 0.34, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	aura_tween.parallel().tween_property(aura_layer, "scale", Vector2(1.035, 1.035), 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	aura_tween.tween_property(aura_layer, "modulate:a", 0.08, 1.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	aura_tween.parallel().tween_property(aura_layer, "scale", Vector2(1.075, 1.075), 1.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	aura_tween.tween_callback(_reset_logo_fx_aura.bind(aura_layer))
	aura_tween.tween_interval(0.35)


func _reset_logo_fx_aura(aura_layer: TextureRect) -> void:
	if not is_instance_valid(aura_layer):
		return
	aura_layer.scale = Vector2(0.985, 0.985)
	aura_layer.modulate = Color(0.76, 0.96, 1.0, 0.12)


func _reset_logo_fx_flow(flow_layer: TextureRect, start_position: Vector2) -> void:
	if not is_instance_valid(flow_layer):
		return
	flow_layer.position = start_position
