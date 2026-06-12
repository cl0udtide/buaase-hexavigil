extends SceneTree

## 覆盖层资产生成（非测试）：手写 SVG 矢量源 → Image.load_svg_from_string 烤 PNG。
## 设计语言：干净赛璐璐战场 UI——细实线、平涂低透填充、直角括角，无渐变无柔光无花饰。
## 格覆盖 64 逻辑像素 ×4 出 256；范围条按原像素尺寸与帧数出图（绘制机制零改动）。
## 改样式 = 改本文件 SVG 再重跑；跑完需 `--headless --import`。

const FRAME := 181
const FRAME_COUNT := 6


func _init() -> void:
	var failures := 0
	failures += _bake(_cell_hover(), 4.0, "res://assets/map/CommandMap/overlay_map_hover.png")
	failures += _bake(_cell_selected(), 4.0, "res://assets/map/CommandMap/overlay_map_selected.png")
	failures += _bake(_cell_region("#ff6450", 0.14, 0.78, true, false), 4.0, "res://assets/map/CommandMap/overlay_attack_range.png")
	failures += _bake(_cell_region("#58c8ff", 0.12, 0.70, false, false), 4.0, "res://assets/map/CommandMap/overlay_building_range.png")
	failures += _bake(_cell_region("#5ce08e", 0.13, 0.75, true, false), 4.0, "res://assets/map/CommandMap/overlay_deploy_valid.png")
	failures += _bake(_cell_region("#ff5a48", 0.15, 0.80, false, true), 4.0, "res://assets/map/CommandMap/overlay_deploy_invalid.png")
	failures += _bake(_edge_base(), 1.0, "res://assets/effects/range/range_outline_edge_base.png")
	failures += _bake(_node_glow_strip(), 1.0, "res://assets/effects/range/range_outline_node_glow_strip.png")
	failures += _bake(_edge_strip_solid_ticks(), 1.0, "res://assets/effects/range/skill_range_warning_edge_pulse_strip.png")
	failures += _bake(_edge_strip_dashed_marching(), 1.0, "res://assets/effects/range/aoe_warning_edge_pulse_strip.png")
	failures += _bake(_edge_strip_double_line(), 1.0, "res://assets/effects/range/building_aura_edge_pulse_strip.png")
	failures += _bake(_edge_strip_triple_line(), 1.0, "res://assets/effects/range/gravity_field_edge_pulse_strip.png")
	failures += _bake(_node_circle_strip(), 1.0, "res://assets/effects/range/field_boundary_node_pulse_strip.png")
	quit(0 if failures == 0 else 1)


static func _bake(svg: String, scale: float, dst: String) -> int:
	var image := Image.new()
	var err := image.load_svg_from_string(svg, scale)
	if err != OK:
		printerr("svg parse failed: %s" % dst)
		return 1
	err = image.save_png(ProjectSettings.globalize_path(dst))
	print("%s -> err=%d (%dx%d)" % [dst, err, image.get_width(), image.get_height()])
	return 0 if err == OK else 1


## 四角 L 括角（细节留在角上，中心透空可读单位）。
static func _brackets(inset: float, arm: float, width: float, color: String, opacity: float) -> String:
	var i := inset
	var a := inset + arm
	var j := 64.0 - inset
	var b := 64.0 - inset - arm
	var style := "fill='none' stroke='%s' stroke-opacity='%.2f' stroke-width='%.1f'" % [color, opacity, width]
	return (
		"<path d='M%.1f %.1f V%.1f H%.1f' %s/>" % [i, a, i, a, style]
		+ "<path d='M%.1f %.1f V%.1f H%.1f' %s/>" % [j, a, i, b, style]
		+ "<path d='M%.1f %.1f V%.1f H%.1f' %s/>" % [i, b, j, a, style]
		+ "<path d='M%.1f %.1f V%.1f H%.1f' %s/>" % [j, b, j, b, style]
	)


## 悬停：纯白括角 + 极淡框（运行时按用途 modulate 上色）。
static func _cell_hover() -> String:
	return (
		"<svg width='64' height='64' xmlns='http://www.w3.org/2000/svg'>"
		+ "<rect x='2.5' y='2.5' width='59' height='59' fill='none' stroke='#ffffff' stroke-opacity='0.30' stroke-width='1.2'/>"
		+ _brackets(2.5, 11.0, 2.6, "#ffffff", 1.0)
		+ "</svg>"
	)


## 选中：青色括角 + 内细框 + 极淡填充。
static func _cell_selected() -> String:
	return (
		"<svg width='64' height='64' xmlns='http://www.w3.org/2000/svg'>"
		+ "<rect x='2' y='2' width='60' height='60' fill='#62d9ff' fill-opacity='0.07'/>"
		+ "<rect x='6.5' y='6.5' width='51' height='51' fill='none' stroke='#62d9ff' stroke-opacity='0.55' stroke-width='1.4'/>"
		+ _brackets(2.0, 12.0, 3.0, "#62d9ff", 0.95)
		+ "</svg>"
	)


## 区域格：平涂低透填充 + 内侧细框；可选角刻 / 禁用斜叉。
static func _cell_region(color: String, fill_alpha: float, border_alpha: float, corner_ticks: bool, cross: bool) -> String:
	var svg := "<svg width='64' height='64' xmlns='http://www.w3.org/2000/svg'>"
	svg += "<rect x='1' y='1' width='62' height='62' fill='%s' fill-opacity='%.2f'/>" % [color, fill_alpha]
	svg += "<rect x='2.5' y='2.5' width='59' height='59' fill='none' stroke='%s' stroke-opacity='%.2f' stroke-width='1.6'/>" % [color, border_alpha]
	if corner_ticks:
		svg += _brackets(2.5, 7.0, 2.4, color, minf(border_alpha + 0.15, 1.0))
	if cross:
		var cross_style := "stroke='%s' stroke-opacity='0.85' stroke-width='3.2'" % color
		svg += "<path d='M22 22 L42 42' %s/><path d='M42 22 L22 42' %s/>" % [cross_style, cross_style]
	svg += "</svg>"
	return svg


## 默认范围边（单帧长条）：实心主线 + 细副线。
static func _edge_base() -> String:
	return (
		"<svg width='1295' height='47' xmlns='http://www.w3.org/2000/svg'>"
		+ "<rect x='0' y='19' width='1295' height='9' fill='#ffffff' fill-opacity='0.95'/>"
		+ "<rect x='0' y='32' width='1295' height='3' fill='#ffffff' fill-opacity='0.35'/>"
		+ "<rect x='0' y='12' width='1295' height='3' fill='#ffffff' fill-opacity='0.35'/>"
		+ "</svg>"
	)


static func _pulse(frame: int) -> float:
	# 6 帧呼吸：0.55 → 1.0 → 0.55。
	var seq: Array[float] = [0.55, 0.72, 0.9, 1.0, 0.9, 0.72]
	return seq[frame % 6]


## 默认范围节点（6 帧 128²）：菱形呼吸 + 中心点。
static func _node_glow_strip() -> String:
	var svg := "<svg width='768' height='128' xmlns='http://www.w3.org/2000/svg'>"
	for f: int in range(6):
		var half := 20.0 + 5.0 * _pulse(f)
		var alpha := _pulse(f)
		svg += "<g transform='translate(%d,0)'>" % (f * 128)
		svg += "<rect x='%.1f' y='%.1f' width='%.1f' height='%.1f' transform='rotate(45 64 64)' fill='none' stroke='#ffffff' stroke-opacity='%.2f' stroke-width='8'/>" % [64.0 - half, 64.0 - half, half * 2.0, half * 2.0, alpha]
		svg += "<circle cx='64' cy='64' r='7' fill='#ffffff' fill-opacity='%.2f'/>" % alpha
		svg += "</g>"
	svg += "</svg>"
	return svg


static func _edge_strip(body_per_frame: Callable) -> String:
	var svg := "<svg width='%d' height='%d' xmlns='http://www.w3.org/2000/svg'>" % [FRAME * FRAME_COUNT, FRAME]
	for f: int in range(FRAME_COUNT):
		svg += "<g transform='translate(%d,0)'>" % (f * FRAME)
		svg += String(body_per_frame.call(f))
		svg += "</g>"
	svg += "</svg>"
	return svg


## 技能范围边：实线 + 上下对称短刻（垂直对称，旋转方向无关）。
static func _edge_strip_solid_ticks() -> String:
	return _edge_strip(func(f: int) -> String:
		var alpha := _pulse(f)
		var body := "<rect x='0' y='82' width='181' height='17' fill='#ffffff' fill-opacity='%.2f'/>" % alpha
		for tx: int in range(18, 181, 48):
			body += "<rect x='%d' y='62' width='9' height='12' fill='#ffffff' fill-opacity='%.2f'/>" % [tx, alpha * 0.7]
			body += "<rect x='%d' y='107' width='9' height='12' fill='#ffffff' fill-opacity='%.2f'/>" % [tx, alpha * 0.7]
		return body)


## AOE 警告边：粗虚线随帧行进 + 呼吸。
static func _edge_strip_dashed_marching() -> String:
	return _edge_strip(func(f: int) -> String:
		var alpha := 0.7 + 0.3 * _pulse(f)
		var offset := float(f) * 12.0
		return "<line x1='-70' y1='90.5' x2='251' y2='90.5' stroke='#ffffff' stroke-opacity='%.2f' stroke-width='21' stroke-dasharray='44 26' stroke-dashoffset='%.1f'/>" % [alpha, offset])


## 建筑光环边：对称双实线呼吸。
static func _edge_strip_double_line() -> String:
	return _edge_strip(func(f: int) -> String:
		var alpha := _pulse(f)
		return (
			"<rect x='0' y='71' width='181' height='13' fill='#ffffff' fill-opacity='%.2f'/>" % alpha
			+ "<rect x='0' y='97' width='181' height='13' fill='#ffffff' fill-opacity='%.2f'/>" % alpha
		))


## 重力场边：中线 + 上下细线（三线，场感更重）。
static func _edge_strip_triple_line() -> String:
	return _edge_strip(func(f: int) -> String:
		var alpha := _pulse(f)
		return (
			"<rect x='0' y='83' width='181' height='15' fill='#ffffff' fill-opacity='%.2f'/>" % alpha
			+ "<rect x='0' y='62' width='181' height='5' fill='#ffffff' fill-opacity='%.2f'/>" % (alpha * 0.55)
			+ "<rect x='0' y='114' width='181' height='5' fill='#ffffff' fill-opacity='%.2f'/>" % (alpha * 0.55)
		))


## 场域节点：圆环呼吸 + 中心点。
static func _node_circle_strip() -> String:
	return _edge_strip(func(f: int) -> String:
		var alpha := _pulse(f)
		var radius := 30.0 + 8.0 * _pulse(f)
		return (
			"<circle cx='90.5' cy='90.5' r='%.1f' fill='none' stroke='#ffffff' stroke-opacity='%.2f' stroke-width='9'/>" % [radius, alpha]
			+ "<circle cx='90.5' cy='90.5' r='8' fill='#ffffff' fill-opacity='%.2f'/>" % alpha
		))
