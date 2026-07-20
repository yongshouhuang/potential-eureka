# QiGauge.gd — S3-UI-Battle 气槽控件（A4(b) / art-bible §11）
# 3 气格（pip）渲染为「单位本行形状 glyph」（金=三角/木=圆/水=菱/火=五边/土=方），
# 与五行形状冗余联动；右侧 tabular「qi: X/3」；热区 ≥44×44（移动 48）。
# 满格=本行主题色+柔光；空格=描边轮廓（灰度可辨）。
# reduce_motion 保留数字+形状+描边静态等效（Standard I）；性能模式降级柔光。
extends Control

class_name QiGauge

var current: int = 0
var max_count: int = 3
var element: String = ""

func _ready() -> void:
	if UIThemeController != null:
		UIThemeController.layout_mode_changed.connect(_on_theme)
	if AccessibilitySettings != null:
		AccessibilitySettings.accessibility_changed.connect(_on_theme)

func _on_theme(_p = null) -> void:
	queue_redraw()

func set_qi(cur: int, mx: int, el: String) -> void:
	current = cur
	max_count = mx
	element = el
	queue_redraw()

func _draw() -> void:
	if element == "":
		return
	var r := Rect2(Vector2.ZERO, size)
	var cfg = ConfigLoader.load_table("battle/ui_constants", "res://data/battle/battle_ui_constants.json")
	var qg := cfg.get("qi_gauge", {}) if cfg != null else {}
	var pips := int(qg.get("pips", 3))
	max_count = pips
	# 气格区（左 70%），编号网格
	var pip_area := Rect2(r.position, Vector2(r.size.x * 0.7, r.size.y))
	var step := pip_area.size.x / float(max_count)
	var motion := 0.0
	if AccessibilitySettings != null:
		motion = AccessibilitySettings.get_motion_scale()
	for i in max_count:
		var cell := Rect2(pip_area.position.x + float(i) * step + step * 0.12,
				pip_area.position.y + pip_area.size.y * 0.08,
				step * 0.76, pip_area.size.y * 0.84)
		var on := i < current
		var col := UIThemeController.get_element_color(element)
		var shape := ElementShapeMap.shape_name_for(element)
		var pts := ElementShapeDrawer.build_element_points(shape, cell)
		if on:
			draw_polygon(pts, PackedColorArray([col]))
			# 柔光（reduce_motion / 性能模式跳过）
			if motion > 0.0 and not UIThemeController.is_performance_mode():
				draw_polyline(pts, col.lightened(0.3), 2.0)
		else:
			draw_polyline(pts, UIThemeController.get_text_color() if UIThemeController.is_high_contrast() else col.lightened(0.25), 2.0)
	# 数字徽标（右 30%，tabular）
	var num_area := Rect2(pip_area.position.x + pip_area.size.x, r.position.y, r.size.x - pip_area.size.x, r.size.y)
	var txt := "qi: %d/%d" % [current, max_count]
	draw_string(txt, num_area.position + Vector2(4, num_area.size.y * 0.5 - 8), HORIZONTAL_ALIGNMENT.LEFT, 0, UIThemeController.get_text_color(), 14)
	# 高对比双边界
	if UIThemeController.is_high_contrast():
		draw_rect(r, false, 2.0)

# 最小命中区（双端热区≥44，移动 48）——供布局/lint 校验。
func min_hotzone() -> Vector2:
	var cfg = ConfigLoader.load_table("battle/ui_constants", "res://data/battle/battle_ui_constants.json")
	var qg := cfg.get("qi_gauge", {}) if cfg != null else {}
	var base := int(qg.get("hotzone_min_px", 44))
	var mobile := int(qg.get("mobile_pip_px", 48))
	var m := base
	if UIThemeController != null and UIThemeController.layout_mode == "single":
		m = maxi(base, mobile)
	return Vector2(float(m), float(m))
