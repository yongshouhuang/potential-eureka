# test_accessibility.gd — E6-S5 可访问性单例（S1 已存在；CVD 完整接线留 S3）
# 覆盖：字段变更 emit accessibility_changed；text_scale 1.0–1.3 钳制；
# reduce_motion -> MotionScale=0；color_blind_mode 切换；持久化至 GameState.settings。
# 注：本测试为 S1 单例就绪的额外保障，主 S1 门禁为 T1/T3/T4。
extends GutTest

var _snaps := []


func before_each() -> void:
	AccessibilitySettings.high_contrast = false
	AccessibilitySettings.reduce_motion = false
	AccessibilitySettings.text_scale = 1.0
	AccessibilitySettings.color_blind_mode = AccessibilitySettings.ColorBlind.NONE
	AccessibilitySettings.cvd_filter = false
	AccessibilitySettings.performance_mode = false
	AccessibilitySettings.dynamic_text = false
	GameState.settings = {}
	_snaps.clear()


func _on_changed(snapshot: Dictionary) -> void:
	_snaps.append(snapshot)


# --- 字段变更广播 accessibility_changed ---
func test_change_emits_signal() -> void:
	AccessibilitySettings.accessibility_changed.connect(_on_changed)
	AccessibilitySettings.set_high_contrast(true)
	AccessibilitySettings.accessibility_changed.disconnect(_on_changed)
	assert_eq(_snaps.size(), 1, "恰好广播一次")
	assert_eq(_snaps[0].get("high_contrast"), true)


# --- text_scale 钳制到 [1.0, 1.3] ---
func test_text_scale_clamped() -> void:
	AccessibilitySettings.set_text_scale(2.0)
	assert_eq(AccessibilitySettings.text_scale, 1.3, "超上限钳到 1.3")
	AccessibilitySettings.set_text_scale(0.5)
	assert_eq(AccessibilitySettings.text_scale, 1.0, "超下限钳到 1.0")
	AccessibilitySettings.set_text_scale(1.2)
	assert_eq(AccessibilitySettings.text_scale, 1.2, "合法值生效")


# --- reduce_motion -> MotionScale=0（E6-S6 种子）---
func test_reduce_motion_zeroes_motion_scale() -> void:
	assert_eq(AccessibilitySettings.get_motion_scale(), 1.0, "默认动效满")
	AccessibilitySettings.set_reduce_motion(true)
	assert_eq(AccessibilitySettings.get_motion_scale(), 0.0, "减少动效 -> 动效总线归零")


# --- color_blind_mode 切换 ---
func test_color_blind_mode_switch() -> void:
	AccessibilitySettings.set_color_blind_mode(AccessibilitySettings.ColorBlind.DEUTER)
	assert_eq(AccessibilitySettings.color_blind_mode, AccessibilitySettings.ColorBlind.DEUTER, "色盲模式切换")


# --- 持久化至 GameState.settings（对齐 schema v1 settings）---
func test_persist_to_game_state() -> void:
	AccessibilitySettings.set_text_scale(1.2)
	AccessibilitySettings.set_high_contrast(true)
	assert_eq(GameState.settings.get("text_scale"), 1.2, "写入 GameState.settings")
	assert_eq(GameState.settings.get("high_contrast"), true)
