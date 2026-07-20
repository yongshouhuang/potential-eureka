# UIThemeController.gd — 响应式断点 + 主题（ADR-001 / E6-S1 / E6-S5 / E6-S6）
# 读视口尺寸设 layout_mode；集中持有 art-bible 色板常量。
# 硬约束：管理器代码中禁止硬编码十六进制色值——一律引用本单例的色常量。
# 稀有度/五行/反馈三重的颜色、边框纹理、角星、形状均绑定到这些常量或 Theme 资源。
# E6-S5：订阅 AccessibilitySettings.accessibility_changed 应用高对比/文本缩放/CVD。
# E6-S6：暴露 CVD 主题色重映射、MotionScale 转发、performance_mode 降级入口。
extends Node

# 断点（对齐 art-bible §7 / ux-spec §0）
const BREAKPOINT_MOBILE := 768     # <768 竖屏单列
const BREAKPOINT_HYBRID := 1024    # 768–1024 混合自适应
# 8 倍数栅格基准（art-bible §3 / 架构 §1.5）
const GRID := 8

# 布局模式枚举
enum Layout { MULTI, HYBRID, SINGLE }

# ---- art-bible 色板常量（唯一硬编码色值的位置）----
# 青冥 #1F3A3D / 青碧 #4FA39B / 月白 #E8ECEF / 朱砂 #C8453A / 鎏金 #CBA75C / 紫宸 #8B6DB3
# 深墨底 #122426（高对比主题底，accessibility-spec Basic B）/ 赭石 #B98A5E（土行新 token，art-bible §10）
const COLOR_QING_MING: Color = Color("#1F3A3D")
const COLOR_QING_BI: Color = Color("#4FA39B")
const COLOR_YUE_BAI: Color = Color("#E8ECEF")
const COLOR_ZHU_SHA: Color = Color("#C8453A")
const COLOR_LIU_JIN: Color = Color("#CBA75C")
const COLOR_ZI_CHEN: Color = Color("#8B6DB3")
const COLOR_DEEP_INK: Color = Color("#122426")
const COLOR_EARTH: Color = Color("#B98A5E")   # 赭石 · 土行独立色（#11 COLOR_EARTH handoff，art-bible §10）

# 文本缩放范围（与 AccessibilitySettings 一致，1.0–1.3）
const TEXT_SCALE_MIN := 1.0
const TEXT_SCALE_MAX := 1.3

# 稀有度 -> 色常量（供 UI 渲染三重冗余的颜色通道；不硬编码）
const RARITY_COLOR := {
	"N": COLOR_YUE_BAI,
	"R": COLOR_QING_BI,
	"SR": COLOR_LIU_JIN,
	"SSR": COLOR_ZI_CHEN,
}

# 五行 -> 色常量（五行配色，形状冗余为主、颜色为辅）
const ELEMENT_COLOR := {
	"jin": COLOR_QING_BI,   # 金
	"mu": COLOR_QING_MING,  # 木
	"shui": COLOR_QING_BI,  # 水（示例，实际由美术圣经细化）
	"huo": COLOR_ZHU_SHA,   # 火
	"tu": COLOR_EARTH,      # 土（#11：独立赭石色，原映射 COLOR_LIU_JIN）
}

# 数据侧元素名（skill_defs / status_config / element_matrix 用 English）-> 主题色键（Chinese）。
# 让数据驱动路径（get_status_color 读 status_config.element）能正确映射到 ELEMENT_COLOR。
const ELEMENT_ALIAS := {
	"metal": "jin", "wood": "mu", "water": "shui", "fire": "huo", "earth": "tu",
}

# CVD 主题色重映射（E6-S6a，跨端稳方案，优先于后处理 shader）。
# 键 = AccessibilitySettings.ColorBlind 枚举值（NONE=0 / DEUTER=1 / PROTAN=2 / TRITAN=3）。
# 仅对五行主题色做等效替换；三重冗余（形状+图标+颜色）为主，CVD 为额外保障。
# 设计意图：将易混淆色对（红/绿、蓝/黄）在该缺陷型下替换为可分离色。
# 真机切换观感验证见 S3-DualEnd / 打磨阶段（本仓无引擎，逻辑镜像见 production/qa/s3_e6_python_logic_mirror.py）。
const CVD_REMAP := {
	# 红绿色盲（Deuter / Protan）：火(红)→鎏金、土→朱砂，避开与青碧(绿)混淆
	1: { "jin": COLOR_QING_BI, "mu": COLOR_ZI_CHEN, "shui": COLOR_YUE_BAI, "huo": COLOR_LIU_JIN, "tu": COLOR_ZHU_SHA },
	2: { "jin": COLOR_QING_BI, "mu": COLOR_ZI_CHEN, "shui": COLOR_YUE_BAI, "huo": COLOR_LIU_JIN, "tu": COLOR_ZHU_SHA },
	# 蓝黄色盲（Tritan）：金→朱砂、水→紫宸，避开青碧(蓝绿)/金(黄)混淆
	3: { "jin": COLOR_ZHU_SHA, "mu": COLOR_QING_BI, "shui": COLOR_ZI_CHEN, "huo": COLOR_LIU_JIN, "tu": COLOR_YUE_BAI },
}

signal layout_mode_changed(mode: String)

var layout_mode: String = "single"  # "multi" / "hybrid" / "single"

# ---- 可访问性应用态（E6-S5/S6，由 accessibility_changed 驱动）----
var _high_contrast: bool = false
var _text_scale: float = 1.0
var _cvd_mode: int = 0           # 0 = NONE
var _cvd_enabled: bool = false
var _performance_mode: bool = false


func _ready() -> void:
	refresh()
	# E6-S5：订阅 AccessibilitySettings 信号（autoload 顺序 AccessibilitySettings 先于本单例，安全）
	if AccessibilitySettings != null:
		AccessibilitySettings.accessibility_changed.connect(_on_accessibility_changed)
		# 应用启动时的持久化/初始快照（首帧即正确主题）
		_apply_accessibility(AccessibilitySettings.get_snapshot())


# 由视口宽度计算布局模式（纯函数，便于单测）
func compute_layout_mode(width: int) -> String:
	if width >= BREAKPOINT_HYBRID:
		return "multi"
	if width >= BREAKPOINT_MOBILE:
		return "hybrid"
	return "single"


# 设布局模式（变更时广播）
func set_layout_mode(mode: String) -> void:
	if mode != layout_mode:
		layout_mode = mode
		layout_mode_changed.emit(mode)


# 从当前视口刷新（场景就绪时调用；headless 下视口尺寸可能为 0，做保护）
func refresh() -> void:
	var w := 0
	if get_viewport() != null:
		w = int(get_viewport().size.x)
	if w <= 0:
		w = BREAKPOINT_HYBRID  # 默认按中端断点，避免 headless 下误判
	set_layout_mode(compute_layout_mode(w))


# 便捷：当前是否移动竖屏
func is_mobile() -> bool:
	return layout_mode == "single"


# 取 8 倍数对齐值（栅格辅助）
func grid(n: int) -> int:
	return n * GRID


# =====================================================================
# E6-S5 / E6-S6 · 可访问性应用入口
# =====================================================================

# accessibility_changed 回调：把快照分发到各 apply 入口
func _on_accessibility_changed(snapshot: Dictionary) -> void:
	_apply_accessibility(snapshot)


func _apply_accessibility(snap: Dictionary) -> void:
	if snap.has("high_contrast"):
		apply_high_contrast(bool(snap["high_contrast"]))
	if snap.has("text_scale"):
		apply_text_scale(float(snap["text_scale"]))
	if snap.has("color_blind_mode"):
		apply_cvd(int(snap["color_blind_mode"]), _cvd_enabled)
	if snap.has("cvd_filter"):
		apply_cvd(_cvd_mode, bool(snap["cvd_filter"]))
	if snap.has("performance_mode"):
		apply_performance_mode(bool(snap["performance_mode"]))


# --- 高对比主题（accessibility-spec Basic B）---
func apply_high_contrast(on: bool) -> void:
	_high_contrast = on


func is_high_contrast() -> bool:
	return _high_contrast


# 背景色：高对比用深墨底，否则青冥。高对比不改五行色（形状/图标已冗余）。
func get_background_color() -> Color:
	return COLOR_DEEP_INK if _high_contrast else COLOR_QING_MING


func get_text_color() -> Color:
	return COLOR_YUE_BAI


# --- 文本缩放（Basic C，100%–130%）---
func apply_text_scale(v: float) -> void:
	_text_scale = clampf(v, TEXT_SCALE_MIN, TEXT_SCALE_MAX)


func get_text_scale() -> float:
	return _text_scale


# --- CVD 主题色重映射（E6-S6a，Standard G）---
# mode 取 AccessibilitySettings.ColorBlind 枚举值；enabled 对应 cvd_filter 独立开关。
func apply_cvd(mode: int, enabled: bool) -> void:
	_cvd_mode = mode
	_cvd_enabled = enabled


func is_cvd_enabled() -> bool:
	return _cvd_enabled


func get_cvd_mode() -> int:
	return _cvd_mode


# 取五行主题色（已应用 CVD 重映射）；未知 element 回退月白。
# 同时接受 English（数据侧）与 Chinese（UI 侧）键，经 ELEMENT_ALIAS 归一。
func get_element_color(element: String) -> Color:
	var key: String = element
	if ELEMENT_ALIAS.has(element):
		key = ELEMENT_ALIAS[element]
	if _cvd_enabled and CVD_REMAP.has(_cvd_mode) and CVD_REMAP[_cvd_mode].has(key):
		return CVD_REMAP[_cvd_mode][key]
	return ELEMENT_COLOR.get(key, COLOR_YUE_BAI)


# 状态色：依据 status_config 的 element 取五行主题色（#12 数据驱动），再走 CVD 重映射。
# element 未知时回退中性月白；ConfigLoader 缺失则安全回退（不阻塞主题应用）。
func get_status_color(status_id: String) -> Color:
	return get_element_color(_status_element(status_id))


func _status_element(status_id: String) -> String:
	if ConfigLoader != null and ConfigLoader.has_method("load_table"):
		var cfg: Dictionary = ConfigLoader.load_table("battle/status_config", "res://data/battle/status_config.json")
		if cfg.has("status") and cfg["status"].has(status_id):
			var s: Dictionary = cfg["status"][status_id]
			if s.has("element"):
				return str(s["element"])
	return "neutral"


# --- MotionScale 动效总线转发（E6-S6b）---
# VFX/粒子/视差/光扫读取此值（或直接读 AccessibilitySettings.get_motion_scale()）。
# reduce_motion 时 = 0，但状态变化的静态等效反馈（图标/数字/边框）仍须更新（见 test_motion_scale_cvd）。
func motion_scale() -> float:
	return AccessibilitySettings.get_motion_scale()


# --- 性能/省电降级（E6-S6c，Comprehensive P）---
# 开启后纹理/粒子/3D 演出由消费方（VFX/场景）读取此标志降级；
# 降级后 Basic 三重标识（形状/图标/颜色）仍由形状+图标冗余保证（真机见 S3-DualEnd）。
func apply_performance_mode(on: bool) -> void:
	_performance_mode = on


func is_performance_mode() -> bool:
	return _performance_mode


# 重置可访问性应用态到默认（测试用，不断开信号）
func reset_accessibility_state() -> void:
	_high_contrast = false
	_text_scale = 1.0
	_cvd_mode = 0
	_cvd_enabled = false
	_performance_mode = false
