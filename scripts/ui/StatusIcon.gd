# StatusIcon.gd — S3-UI-Battle 状态图标（A2 三重冗余）
# 每个状态 = 形状 + 图标 + 数字徽标 三通道（不靠色，art-bible §8 / accessibility Basic D/E）。
#   形状通道：单位本行形状（ElementShapeDrawer，圆/三角/方/菱/五边）
#   图标通道：状态专属 glyph（flame/shield/drop/chevron），灰阶下互异
#   数字通道：stacks/max + 剩余回合点（tabular）
# 颜色经 UIThemeController（全局名）；数据经 ConfigLoader；不 preload 管理器。
extends Control

class_name StatusIcon

var status_type: String = ""      # burn / armo_break / poison / momentum
var stacks: int = 0
var max_stacks: int = 3
var turns_left: int = 0
var element: String = ""         # 单位本行（metal/wood/water/fire/earth）
var _glyph: String = ""

func _ready() -> void:
	# 高对比 / 文本缩放 / CVD 经 UIThemeController 主题色即时生效（颜色已按需取，重绘即可）
	if UIThemeController != null:
		UIThemeController.layout_mode_changed.connect(_on_theme_changed)
	if AccessibilitySettings != null:
		AccessibilitySettings.accessibility_changed.connect(_on_theme_changed)

func _on_theme_changed(_p = null) -> void:
	queue_redraw()

# 设置状态数据并重绘。
func set_status(status_type_: String, stacks_: int, max_stacks_: int, turns_left_: int, element_: String) -> void:
	status_type = status_type_
	stacks = stacks_
	max_stacks = max_stacks_
	turns_left = turns_left_
	element = element_
	_glyph = load_glyph(status_type)
	queue_redraw()

func _draw() -> void:
	if status_type == "":
		return
	var r := Rect2(Vector2.ZERO, size)
	var col := UIThemeController.get_element_color(element if element != "" else "neutral")
	# 通道1 · 形状（单位本行形状，淡填充 + 描边）
	var shape := ElementShapeMap.shape_name_for(element)
	var pts := ElementShapeDrawer.build_element_points(shape, Rect2(r.position, r.size * 0.9))
	draw_polygon(pts, PackedColorArray([col * Color(1, 1, 1, 0.18)]))
	draw_polyline(pts, UIThemeController.get_text_color() if UIThemeController.is_high_contrast() else col.lightened(0.2), 3.0)
	# 通道2 · 图标（状态专属 glyph，覆盖于形状中心，色为主、形为主）
	var glyph_rect := Rect2(r.position + r.size * 0.18, r.size * 0.64)
	var gpts := ElementShapeDrawer.build_glyph_points(_glyph, glyph_rect)
	if gpts.size() > 0:
		draw_polygon(gpts, PackedColorArray([col]))
		draw_polyline(gpts, UIThemeController.get_text_color() if UIThemeController.is_high_contrast() else col.darkened(0.2), 2.0)
	# 通道3 · 数字徽标（stacks/max + 回合点，tabular）
	var badge := "%d/%d" % [stacks, max_stacks]
	draw_string(badge, Vector2(r.position.x + 2, r.position.y + 2), HORIZONTAL_ALIGNMENT.LEFT, 0, UIThemeController.get_text_color(), 14)
	# 剩余回合点（圆点，filled=剩余）
	var dot_y := r.position.y + r.size.y - 8
	var dot_x0 := r.position.x + 4
	for i in max_stacks:
		var on := i < turns_left
		draw_circle(Vector2(dot_x0 + float(i) * 10, dot_y), 3.0, col if on else Color(0.6, 0.6, 0.6, 0.5))
	# 高对比双边界
	if UIThemeController.is_high_contrast():
		draw_rect(r, false, 2.0)

# ---- 数据 / 冗余校验（可单测）----
# 从 battle_ui_constants 读状态 glyph 名（经 ConfigLoader，全局名）。
static func load_glyph(status_type_: String) -> String:
	var cfg = ConfigLoader.load_table("battle/ui_constants", "res://data/battle/battle_ui_constants.json")
	if cfg != null and cfg.get("status_icons", {}).has(status_type_):
		return cfg["status_icons"][status_type_].get("glyph", "")
	return ""

# 三重冗余是否成立：形状(本行元素) + 图标(glyph 名非空) + 数字(stacks∈[1,max]) 三通道齐备。
static func redundancy_ok(status_type_: String, stacks_: int, turns_left_: int, element_: String) -> bool:
	if element_ == "":
		return false
	if load_glyph(status_type_) == "":
		return false
	if stacks_ < 1 or stacks_ > 3:
		return false
	if turns_left_ < 0:
		return false
	return true

# 灰阶可辨矩阵：每状态 → 专属轮廓 silhouette（4 者互异即灰阶成立）。
# 返回 {status_type: silhouette}。
static func grayscale_matrix() -> Dictionary:
	var cfg = ConfigLoader.load_table("battle/ui_constants", "res://data/battle/battle_ui_constants.json")
	var out := {}
	if cfg == null:
		return out
	for k in cfg.get("status_icons", {}).keys():
		out[k] = cfg["status_icons"][k].get("silhouette", "")
	return out

# 矩阵是否两两互异（灰阶下形状/图标可辨）。
static func grayscale_matrix_distinct() -> bool:
	var m := grayscale_matrix()
	var vals := m.values()
	for i in vals.size():
		for j in vals.size():
			if i != j and vals[i] == vals[j]:
				return false
	return true
