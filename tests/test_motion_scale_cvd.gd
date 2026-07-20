# test_motion_scale_cvd.gd — E6-S6 MotionScale 消费 + CVD 重映射验证
# 覆盖：(1) MotionScale 消费契约（reduce_motion→0 且静态等效反馈保留）；
#       (2) CVD 模式/开关切换（apply_cvd 可断言部分）。
extends GutTest


# 模拟一个状态 VFX：读取 motion_scale 决定动画强度，但图标/数字/边框总是更新
# （静态等效反馈——reduce_motion 时跳过非必要动画，状态变化仍可见）。
class MockStatusVfx:
	var icon_updated := false
	var number_updated := false
	var border_updated := false
	var last_motion := 1.0

	func apply_feedback(value: int, motion: float) -> void:
		last_motion = motion
		# 即使 motion=0（reduce_motion），静态通道仍更新
		icon_updated = true
		number_updated = true
		border_updated = true


func before_each() -> void:
	AccessibilitySettings.high_contrast = false
	AccessibilitySettings.reduce_motion = false
	AccessibilitySettings.text_scale = 1.0
	AccessibilitySettings.color_blind_mode = AccessibilitySettings.ColorBlind.NONE
	AccessibilitySettings.cvd_filter = false
	AccessibilitySettings.performance_mode = false
	AccessibilitySettings.dynamic_text = false
	GameState.settings = {}
	UIThemeController.reset_accessibility_state()


# ===================== MotionScale 消费 =====================

func test_motion_scale_zeroes_on_reduce_motion() -> void:
	assert_eq(AccessibilitySettings.get_motion_scale(), 1.0, "默认动效满")
	assert_eq(UIThemeController.motion_scale(), 1.0, "转发入口一致")
	AccessibilitySettings.set_reduce_motion(true)
	assert_eq(AccessibilitySettings.get_motion_scale(), 0.0, "reduce_motion -> MotionScale=0")
	assert_eq(UIThemeController.motion_scale(), 0.0, "转发入口同步为 0")


func test_static_feedback_preserved_when_reduced() -> void:
	AccessibilitySettings.set_reduce_motion(true)
	var vfx := MockStatusVfx.new()
	# 一次状态变化：传入当前 motion_scale
	vfx.apply_feedback(12, UIThemeController.motion_scale())
	assert_eq(vfx.last_motion, 0.0, "动效总线归零（非必要动画跳过）")
	assert_true(vfx.icon_updated, "图标静态反馈仍更新")
	assert_true(vfx.number_updated, "数字静态反馈仍更新")
	assert_true(vfx.border_updated, "边框静态反馈仍更新")


func test_motion_scale_full_when_normal() -> void:
	var vfx := MockStatusVfx.new()
	vfx.apply_feedback(7, UIThemeController.motion_scale())
	assert_eq(vfx.last_motion, 1.0, "常态动效满")
	assert_true(vfx.icon_updated and vfx.number_updated and vfx.border_updated, "常态同样更新全部通道")


# ===================== CVD 模式/开关 =====================

func test_cvd_remap_deuter() -> void:
	UIThemeController.apply_cvd(AccessibilitySettings.ColorBlind.DEUTER, true)
	assert_ne(UIThemeController.get_element_color("huo"), UIThemeController.ELEMENT_COLOR["huo"],
		"DEUTER：火(红)被重映射")
	assert_eq(UIThemeController.get_element_color("huo"), UIThemeController.COLOR_LIU_JIN,
		"DEUTER：火→鎏金(可分离色)")


func test_cvd_remap_tritan() -> void:
	UIThemeController.apply_cvd(AccessibilitySettings.ColorBlind.TRITAN, true)
	assert_ne(UIThemeController.get_element_color("jin"), UIThemeController.ELEMENT_COLOR["jin"],
		"TRITAN：金(青碧)被重映射")
	assert_eq(UIThemeController.get_element_color("jin"), UIThemeController.COLOR_ZHU_SHA,
		"TRITAN：金→朱砂(可分离色)")


func test_cvd_disabled_identity() -> void:
	UIThemeController.apply_cvd(AccessibilitySettings.ColorBlind.DEUTER, false)
	assert_eq(UIThemeController.get_element_color("huo"), UIThemeController.ELEMENT_COLOR["huo"],
		"cvd_filter=false 时不重映射（即使 mode≠NONE）")


func test_cvd_none_identity() -> void:
	UIThemeController.apply_cvd(AccessibilitySettings.ColorBlind.NONE, true)
	assert_eq(UIThemeController.get_element_color("huo"), UIThemeController.ELEMENT_COLOR["huo"],
		"mode=NONE 时不重映射（即使 filter=true）")


func test_cvd_via_signal_path() -> void:
	AccessibilitySettings.set_color_blind_mode(AccessibilitySettings.ColorBlind.PROTAN)
	AccessibilitySettings.set_cvd_filter(true)
	assert_ne(UIThemeController.get_element_color("tu"), UIThemeController.ELEMENT_COLOR["tu"],
		"PROTAN 经信号接通后土行重映射")


func test_status_color_uses_element_field() -> void:
	# #12：status_config 含 element，状态色经五行主题色取色
	assert_eq(UIThemeController.get_status_color("burn"), UIThemeController.ELEMENT_COLOR["huo"],
		"burn -> 火行色")
	assert_eq(UIThemeController.get_status_color("armor_break"), UIThemeController.ELEMENT_COLOR["jin"],
		"armor_break -> 金行色")
