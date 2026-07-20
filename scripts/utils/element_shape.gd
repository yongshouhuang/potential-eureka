# element_shape.gd — E4-S6 双端战斗视觉适配（仅数据/常量，不写 UI 场景）
# 五行「图标 + 形状冗余」（art-bible §8 / accessibility Basic E）：圆/三角/方/菱/五边形。
# 热区最小尺寸常量（≥44×44px）。纯常量 + ConfigLoader 读取，无跨管理器 import。
extends RefCounted
class_name ElementShapeMap

# 形状冗余枚举（与 data/battle/battle_ui_constants.json 的 element_shapes 对齐）
enum Shape { CIRCLE, TRIANGLE, SQUARE, DIAMOND, PENTAGON }

# 元素 -> 形状枚举 的静态兜底映射（与 JSON 保持一致；JSON 缺失时仍可用）
const FALLBACK := {
	"metal": Shape.TRIANGLE,
	"wood":  Shape.CIRCLE,
	"earth": Shape.SQUARE,
	"water": Shape.DIAMOND,
	"fire":  Shape.PENTAGON,
}

# 触摸热区最小边长（px）—— art-bible §7
const HOTZONE_MIN_PX := 44

# 取某元素的形状枚举（优先 JSON 配置，否则兜底映射）
static func shape_for(element: String) -> int:
	var cfg = ConfigLoader.load_table("battle/ui_constants", "res://data/battle/battle_ui_constants.json")
	if cfg != null and cfg.get("element_shapes", {}).has(element):
		return _str_to_shape(cfg["element_shapes"][element])
	if FALLBACK.has(element):
		return FALLBACK[element]
	return Shape.CIRCLE

# 取某元素的「形状名字符串」（圆/三角/方/菱/五边），供绘制几何使用。
# 与 shape_for 的 enum 不同：绘制层要字符串（match 分支），故单列此入口。
static func shape_name_for(element: String) -> String:
	var cfg = ConfigLoader.load_table("battle/ui_constants", "res://data/battle/battle_ui_constants.json")
	if cfg != null and cfg.get("element_shapes", {}).has(element):
		return cfg["element_shapes"][element]
	match element:
		"metal": return "triangle"
		"wood":  return "circle"
		"earth": return "square"
		"water": return "diamond"
		"fire":  return "pentagon"
	return "circle"


# 形状冗余是否启用（数据驱动开关）
static func shape_redundancy_enabled() -> bool:
	var cfg = ConfigLoader.load_table("battle/ui_constants", "res://data/battle/battle_ui_constants.json")
	if cfg == null:
		return true
	return bool(cfg.get("shape_redundancy", true))


# 热区最小边长（数据驱动，默认 44）
static func hotzone_min_px() -> int:
	var cfg = ConfigLoader.load_table("battle/ui_constants", "res://data/battle/battle_ui_constants.json")
	if cfg == null:
		return HOTZONE_MIN_PX
	return int(cfg.get("hotzone_min_px", HOTZONE_MIN_PX))


static func _str_to_shape(s: String) -> int:
	match s:
		"circle":   return Shape.CIRCLE
		"triangle": return Shape.TRIANGLE
		"square":   return Shape.SQUARE
		"diamond":  return Shape.DIAMOND
		"pentagon": return Shape.PENTAGON
	return Shape.CIRCLE
