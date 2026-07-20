# test_battle_ui_constants.gd — S3-UI-Battle 数据驱动配置结构校验（验证驱动，headless）
# 覆盖：battle_ui_constants.json 结构完整；五行形状映射齐全（5 互异形状）；
# 状态图标三重冗余字段齐全；连携横幅锚点/热区；气槽 3 pip + 元素形状 glyph；
# 选技按钮热区 ≥44；双端断点；所有热区 ≥44。
extends GutTest

const PATH := "res://data/battle/battle_ui_constants.json"

func _load() -> Dictionary:
	var c = ConfigLoader.load_table("battle/ui_constants", PATH)
	assert_false(c == null, "battle_ui_constants.json 可经 ConfigLoader 加载")
	return c if c != null else {}

func before_each() -> void:
	ConfigLoader.reset()

func after_each() -> void:
	ConfigLoader.reset()

# --- 五行形状映射齐全：5 元素各 1 个互异形状 ---
func test_element_shapes_complete_and_distinct() -> void:
	var c := _load()
	var shapes: Dictionary = c.get("element_shapes", {})
	for el in ["metal", "wood", "water", "fire", "earth"]:
		assert_true(shapes.has(el), "element_shapes 含 " + el)
	var vals := shapes.values()
	for i in vals.size():
		for j in vals.size():
			if i != j:
				assert_ne(vals[i], vals[j], "五行形状两两互异（灰阶可辨）")

# --- 热区最小 ≥44（全局 + 各控件）---
func test_hotzone_min_px_ge_44() -> void:
	var c := _load()
	assert_true(int(c.get("hotzone_min_px", 0)) >= 44, "全局 hotzone_min_px >= 44")
	var qg: Dictionary = c.get("qi_gauge", {})
	assert_true(int(qg.get("hotzone_min_px", 0)) >= 44, "气槽 hotzone >= 44")
	var sb: Dictionary = c.get("skill_button", {})
	assert_true(int(sb.get("hotzone_min_px", 0)) >= 44, "选技按钮 hotzone >= 44")
	# 移动端额外热区亦 ≥44（Standard J）
	assert_true(int(c.get("mobile_hotzone_min_px", 0)) >= 44, "移动端 hotzone >= 44")
	assert_true(int(qg.get("mobile_pip_px", 0)) >= 44, "移动端气格 >= 44")
	assert_true(int(sb.get("mobile_min_px", 0)) >= 44, "移动端按钮 >= 44")

# --- 状态图标三重冗余字段齐全（形状/图标/数字通道）---
func test_status_icons_triple_redundancy_fields() -> void:
	var c := _load()
	var si: Dictionary = c.get("status_icons", {})
	for st in ["burn", "armor_break", "poison", "momentum"]:
		assert_true(si.has(st), "status_icons 含 " + st)
		var d: Dictionary = si[st]
		assert_true(d.has("element") and d["element"] != "", st + " 有本行元素（形状通道）")
		assert_true(d.has("glyph") and d["glyph"] != "", st + " 有 glyph（图标通道）")
		assert_true(d.has("silhouette") and d["silhouette"] != "", st + " 有 silhouette（灰阶互异标注）")
		assert_true(int(d.get("max_stacks", 0)) >= 1, st + " 有 max_stacks（数字通道）")

# --- 连携横幅：锚点 5 + tabular + 双端尺寸 ---
func test_combo_banner_anchor_and_tabular() -> void:
	var c := _load()
	var cb: Dictionary = c.get("combo_banner", {})
	assert_eq(int(cb.get("anchor_id", 0)), 5, "横幅锚点 = 5（五行符文阵）")
	assert_true(bool(cb.get("tabular", false)), "横幅数值 tabular")
	assert_true(float(cb.get("max_width_pct", {}).get("pc", 0.0)) <= 0.6, "PC 横幅宽 <= 60%")
	assert_true(float(cb.get("max_width_pct", {}).get("mobile", 0.0)) >= 0.9, "移动横幅满宽 >= 90%")
	assert_true(int(cb.get("max_height_px", {}).get("pc", 0)) <= 96, "PC 横幅高 <= 96px")
	assert_true(int(cb.get("max_height_px", {}).get("mobile", 0)) <= 56, "移动横幅高 <= 56px")

# --- 气槽：3 pip + 元素形状 glyph 联动 ---
func test_qi_gauge_pips_and_element_glyph() -> void:
	var c := _load()
	var qg: Dictionary = c.get("qi_gauge", {})
	assert_eq(int(qg.get("pips", 0)), 3, "气槽 pip 数 = 3")
	assert_true(bool(qg.get("pip_shape_from_element", false)), "气格形状按本行联动")
	var glyphs: Dictionary = qg.get("pip_glyph_by_element", {})
	for el in ["metal", "wood", "water", "fire", "earth"]:
		assert_true(glyphs.has(el), "气格 glyph 含 " + el)
	var shapes := c.get("element_shapes", {})
	# 气格 glyph 与元素形状映射一致
	for el in glyphs.keys():
		assert_eq(glyphs[el], shapes.get(el, ""), "气格 glyph == 元素形状 (" + el + ")")

# --- 双端断点一致（与 UIThemeController 对齐）---
func test_layout_breakpoints_align() -> void:
	var c := _load()
	var bp: Dictionary = c.get("layout_breakpoints", {})
	assert_eq(int(bp.get("mobile", 0)), 768, "移动断点 = 768（<768 竖屏）")
	assert_eq(int(bp.get("hybrid", 0)), 1024, "混合断点 = 1024（≥1024 多栏）")

# --- 与 ElementShapeMap 静态兜底映射一致（防止数据/代码漂移）---
func test_consistent_with_element_shape_map() -> void:
	var c := _load()
	var shapes: Dictionary = c.get("element_shapes", {})
	assert_eq(ElementShapeMap.shape_for("metal"), ElementShapeMap.Shape.TRIANGLE, "metal -> 三角（与 FALLBACK 一致）")
	assert_eq(ElementShapeMap.shape_for("wood"), ElementShapeMap.Shape.CIRCLE, "wood -> 圆")
	assert_eq(ElementShapeMap.shape_for("earth"), ElementShapeMap.Shape.SQUARE, "earth -> 方")
	assert_eq(ElementShapeMap.shape_for("water"), ElementShapeMap.Shape.DIAMOND, "water -> 菱")
	assert_eq(ElementShapeMap.shape_for("fire"), ElementShapeMap.Shape.PENTAGON, "fire -> 五边")
