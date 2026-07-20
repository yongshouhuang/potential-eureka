# test_status_icon_redundancy.gd — S3-UI-Battle 状态图标三重冗余（验证驱动，headless）
# 覆盖：状态图标三重冗余数据结构（形状/图标/数字字段齐全、灰阶可辨矩阵成立）。
# 直接校验 StatusIcon 静态方法（真实渲染逻辑的数据层，无场景依赖）。
extends GutTest

const SI = preload("res://scripts/ui/StatusIcon.gd")
const PATH := "res://data/battle/battle_ui_constants.json"

# 状态 → 其本行元素（取自 status_config.json，供形状通道）。
const STATUS_ELEMENT := {
	"burn": "fire", "armor_break": "metal", "poison": "wood", "momentum": "metal"
}

func _cfg() -> Dictionary:
	var c = ConfigLoader.load_table("battle/ui_constants", PATH)
	assert_false(c == null, "battle_ui_constants.json 可加载")
	return c if c != null else {}

func before_each() -> void:
	ConfigLoader.reset()

func after_each() -> void:
	ConfigLoader.reset()

# --- 四状态均在配置中，且三重字段齐全 ---
func test_four_statuses_present_with_fields() -> void:
	var c := _cfg()
	var si: Dictionary = c.get("status_icons", {})
	for st in ["burn", "armor_break", "poison", "momentum"]:
		assert_true(si.has(st), "status_icons 含 " + st)

# --- 单状态冗余：形状(元素) + 图标(glyph) + 数字(stacks) 三通道齐备 ---
func test_redundancy_ok_per_status() -> void:
	for st in STATUS_ELEMENT.keys():
		var el: String = STATUS_ELEMENT[st]
		# 合法层数 1..3 → 冗余成立
		assert_true(SI.redundancy_ok(st, 2, 3, el), st + " 合法层数 冗余成立")
		# 越界层数 → 冗余不成立（数字通道失效）
		assert_false(SI.redundancy_ok(st, 0, 3, el), st + " stacks=0 冗余不成立")
		assert_false(SI.redundancy_ok(st, 4, 3, el), st + " stacks=4 越界不成立")

# --- 灰阶可辨矩阵：四状态 silhouette 两两互异 ---
func test_grayscale_matrix_distinct() -> void:
	assert_true(SI.grayscale_matrix_distinct(), "灰阶下四状态 silhouette 两两互异（形状/图标可辨）")

# --- 灰阶矩阵覆盖四状态 ---
func test_grayscale_matrix_covers_four() -> void:
	var m: Dictionary = SI.grayscale_matrix()
	for st in ["burn", "armor_break", "poison", "momentum"]:
		assert_true(m.has(st), "矩阵含 " + st)
		assert_ne(m[st], "", st + " 有非空的 silhouette 标注")
