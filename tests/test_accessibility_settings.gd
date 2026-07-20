# test_accessibility_settings.gd — E6-S5 接线验证
# 断言：AccessibilitySettings.accessibility_changed 触发后，UIThemeController 真正应用
# high_contrast / text_scale / color_blind_mode+cvd_filter（接线真的通，而非仅单例自嗨）。
extends GutTest


func before_each() -> void:
	# 复位可访问性单例
	AccessibilitySettings.high_contrast = false
	AccessibilitySettings.reduce_motion = false
	AccessibilitySettings.text_scale = 1.0
	AccessibilitySettings.color_blind_mode = AccessibilitySettings.ColorBlind.NONE
	AccessibilitySettings.cvd_filter = false
	AccessibilitySettings.performance_mode = false
	AccessibilitySettings.dynamic_text = false
	GameState.settings = {}
	# 复位 UIThemeController 应用态（断开通路外的本地状态）
	UIThemeController.reset_accessibility_state()


# --- 高对比经信号接通 ---
func test_high_contrast_wired() -> void:
	AccessibilitySettings.set_high_contrast(true)
	assert_true(UIThemeController.is_high_contrast(), "信号触发后 UIThemeController 进入高对比")


# --- 文本缩放经信号接通 ---
func test_text_scale_wired() -> void:
	AccessibilitySettings.set_text_scale(1.2)
	assert_eq(UIThemeController.get_text_scale(), 1.2, "信号触发后 UIThemeController 应用文本缩放")


# --- color_blind_mode + cvd_filter 经信号接通，且火行被重映射 ---
func test_cvd_wired_via_signal() -> void:
	AccessibilitySettings.set_color_blind_mode(AccessibilitySettings.ColorBlind.DEUTER)
	AccessibilitySettings.set_cvd_filter(true)
	assert_true(UIThemeController.is_cvd_enabled(), "cvd_filter 经信号接通")
	assert_eq(UIThemeController.get_cvd_mode(), AccessibilitySettings.ColorBlind.DEUTER, "color_blind_mode 经信号接通")
	assert_ne(UIThemeController.get_element_color("huo"), UIThemeController.ELEMENT_COLOR["huo"],
		"DEUTER 下火行主题色被重映射")


# --- 启动即应用初始快照（_ready 中已订阅并应用）---
func test_initial_apply_on_ready() -> void:
	assert_eq(UIThemeController.get_text_scale(), 1.0, "启动即应用默认快照")
	assert_false(UIThemeController.is_high_contrast(), "默认非高对比")
	assert_false(UIThemeController.is_cvd_enabled(), "默认 CVD 未启用")


# --- 性能模式经信号接通 ---
func test_performance_mode_wired() -> void:
	AccessibilitySettings.set_performance_mode(true)
	assert_true(UIThemeController.is_performance_mode(), "性能模式经信号接通")
