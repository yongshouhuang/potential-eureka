# test_battle_ui_constants.gd — E4-S6 双端战斗视觉适配（仅数据/常量，不写 UI 场景）
# 覆盖：五行「图标+形状冗余」枚举映射可达；热区最小尺寸常量 >= 44px（art-bible §7/§8）。
extends GutTest


func _fake_ui_constants() -> Dictionary:
	return {
		"element_shapes": { "metal": "triangle", "wood": "circle", "earth": "square", "water": "diamond", "fire": "pentagon" },
		"shape_redundancy": true,
		"hotzone_min_px": 44
	}


func before_each() -> void:
	ConfigLoader.reset()
	ConfigLoader.inject("battle/ui_constants", _fake_ui_constants())


func after_each() -> void:
	ConfigLoader.reset()


# --- 热区最小尺寸 >= 44px（触控友好，art-bible §7）---
func test_hotzone_min_px() -> void:
	assert_true(ElementShapeMap.hotzone_min_px() >= 44, "热区最小 >= 44px")


# --- 五行 -> 形状冗余枚举映射可达（图标+形状，不依赖纯色）---
func test_element_shape_mapping() -> void:
	assert_eq(ElementShapeMap.shape_for("metal"), ElementShapeMap.Shape.TRIANGLE, "金 -> 三角")
	assert_eq(ElementShapeMap.shape_for("wood"), ElementShapeMap.Shape.CIRCLE, "木 -> 圆")


# --- 形状冗余开关默认开启 ---
func test_shape_redundancy_enabled() -> void:
	assert_true(ElementShapeMap.shape_redundancy_enabled(), "形状冗余默认启用")
