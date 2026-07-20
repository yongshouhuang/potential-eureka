# element_shape.gd — S3-UI-Battle 五行形状绘制器（绘制层）
# 按 battle_ui_constants + UIThemeController.ELEMENT_COLOR 绘制五行形状（圆/三角/方/菱/五边）。
# 灰阶下仍可辨：形状为主、颜色为辅（Basic E / Standard G）。
# 形状映射经 ElementShapeMap（全局 class_name，非 preload）读取；
# 颜色经 UIThemeController（全局 autoload 名，非 preload）读取——满足解耦红线（禁 preload 管理器脚本）。
# 本文件为 Control 子类，自绘自身；可被 StatusIcon / QiGauge / ComboBanner 内嵌复用。
extends Control

class_name ElementShapeDrawer

# 绘制目标元素（英文键 metal/wood/water/fire/earth，经 alias 落地色）。
# filled=true 填充本行主题色；false 仅描边（空格/禁用态，灰度可辨）。
var element: String = ""
var filled: bool = true
var color_override: Color = Color(0, 0, 0, 0)   # 全透明 = 用主题色
var draw_outline: bool = true

# 取本行颜色（优先 override，否则 UIThemeController 经 CVD 重映射后的主题色）。
func _color() -> Color:
	if color_override.a > 0.0:
		return color_override
	return UIThemeController.get_element_color(element)

# 当前形状名（圆/三角/方/菱/五边）。
func _shape_name() -> String:
	return ElementShapeMap.shape_name_for(element)

# 自绘：在自身 rect 内绘制五行形状（双击边界做高对比双边界）。
func _draw() -> void:
	if element == "":
		return
	var r := Rect2(Vector2.ZERO, size)
	var col := _color()
	match _shape_name():
		"circle":
			var rad := minf(r.size.x, r.size.y) * 0.42
			var c := r.get_center()
			if filled:
				draw_circle(c, rad, col)
			if draw_outline:
				draw_arc_outline(c, rad, col)
		"triangle", "square", "diamond", "pentagon":
			var pts := build_element_points(_shape_name(), r)
			if filled:
				draw_colored_polygon(pts, col)
			if draw_outline:
				draw_polyline(pts, outline_color(col), 4.0)
		_:
			pass
	# 高对比：描边 + 投影双边界（Basic B / 户外强光）
	if UIThemeController.is_high_contrast():
		draw_double_border(r)

# ---- 纯几何：形状 → 多边形顶点（可单测）----
# 供 _draw 与单测（GUT 直接调 build_element_points 验证顶点数 / 灰阶互异）。
static func build_element_points(shape: String, rect: Rect2) -> PackedVector2Array:
	match shape:
		"triangle":
			return _regular_polygon(rect, 3, -PI / 2.0)       # 尖顶三角
		"square":
			return _regular_polygon(rect, 4, PI / 4.0)          # 轴对齐方（角在四正）
		"diamond":
			return _regular_polygon(rect, 4, 0.0)              # 旋转 45° 菱
		"pentagon":
			return _regular_polygon(rect, 5, -PI / 2.0)       # 五边（尖顶）
		"circle":
			return _regular_polygon(rect, 36, 0.0)              # 圆用多边形近似（便于统一描边）
		_:
			return _regular_polygon(rect, 4, PI / 4.0)

static func _regular_polygon(rect: Rect2, sides: int, rot: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cx := rect.get_center().x
	var cy := rect.get_center().y
	var rad := minf(rect.size.x, rect.size.y) * 0.42
	for i in sides:
		var a := rot + float(i) * TAU / float(sides)
		out.append(Vector2(cx + rad * cos(a), cy + rad * sin(a)))
	return out

# 状态图标 glyph 几何（flame/shield/drop/chevron），灰阶下彼此互异。
# 返回归一化到 rect 的轮廓折线点（首尾相接）。
static func build_glyph_points(glyph: String, rect: Rect2) -> PackedVector2Array:
	var c := rect.get_center()
	var w := rect.size.x
	var h := rect.size.y
	var top := rect.position.y
	var bot := rect.position.y + h
	match glyph:
		"flame":   # 尖顶圆底焰：上尖下圆
			return PackedVector2Array([
				Vector2(c.x, top + h * 0.08),
				Vector2(c.x + w * 0.18, c.y - h * 0.05),
				Vector2(c.x + w * 0.26, c.y + h * 0.22),
				Vector2(c.x + w * 0.12, bot - h * 0.08),
				Vector2(c.x - w * 0.12, bot - h * 0.08),
				Vector2(c.x - w * 0.26, c.y + h * 0.22),
				Vector2(c.x - w * 0.18, c.y - h * 0.05),
			])
		"shield":   # 缺角硬边裂盾：上平、左右直、下缺角 + 斜裂
			return PackedVector2Array([
				Vector2(rect.position.x + w * 0.10, top + h * 0.10),
				Vector2(rect.position.x + w * 0.90, top + h * 0.10),
				Vector2(rect.position.x + w * 0.90, c.y + h * 0.10),
				Vector2(c.x + w * 0.05, c.y + h * 0.30),   # 右斜裂
				Vector2(rect.position.x + w * 0.78, bot - h * 0.08), # 缺右下角
				Vector2(rect.position.x + w * 0.22, bot - h * 0.08),
				Vector2(c.x - w * 0.05, c.y + h * 0.30),   # 左斜裂
				Vector2(rect.position.x + w * 0.10, c.y + h * 0.10),
			])
		"drop":     # 圆润泪滴 + 内泡：上尖下圆
			return PackedVector2Array([
				Vector2(c.x, top + h * 0.10),
				Vector2(c.x + w * 0.22, c.y - h * 0.02),
				Vector2(c.x + w * 0.30, c.y + h * 0.28),
				Vector2(c.x + w * 0.14, bot - h * 0.10),
				Vector2(c.x - w * 0.14, bot - h * 0.10),
				Vector2(c.x - w * 0.30, c.y + h * 0.28),
				Vector2(c.x - w * 0.22, c.y - h * 0.02),
			])
		"chevron":  # 层叠上箭：三道向上尖角
			return PackedVector2Array([
				Vector2(c.x, top + h * 0.10),
				Vector2(c.x + w * 0.26, c.y + h * 0.02),
				Vector2(c.x, c.y + h * 0.20),
				Vector2(c.x - w * 0.26, c.y + h * 0.02),
				Vector2(c.x, top + h * 0.10),
				Vector2(c.x + w * 0.26, c.y + h * 0.34),
				Vector2(c.x, c.y + h * 0.52),
				Vector2(c.x - w * 0.26, c.y + h * 0.34),
			])
		_:
			return _regular_polygon(rect, 4, PI / 4.0)

# ---- 内部绘制辅助 ----
func draw_double_border(rect: Rect2) -> void:
	draw_rect(rect, false, 2.0)
	draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), false, 1.0)

func outline_color(base: Color) -> Color:
	if UIThemeController.is_high_contrast():
		return UIThemeController.get_text_color()
	return base.lightened(0.25)

func draw_arc_outline(center: Vector2, rad: float, col: Color) -> void:
	draw_arc(center, rad, 0.0, TAU, 48, outline_color(col), 3.0, false)

func draw_colored_polygon(pts: PackedVector2Array, col: Color) -> void:
	draw_polygon(pts, PackedColorArray([col]))
