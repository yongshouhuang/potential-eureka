# UIThemeController.gd — 响应式断点 + 主题（ADR-001 / E6-S1）
# 读视口尺寸设 layout_mode；集中持有 art-bible 色板常量。
# 硬约束：管理器代码中禁止硬编码十六进制色值——一律引用本单例的色常量。
# 稀有度/五行/反馈三重的颜色、边框纹理、角星、形状均绑定到这些常量或 Theme 资源。
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
# 深墨底 #122426（高对比主题底，accessibility-spec Basic B）
const COLOR_QING_MING: Color = Color("#1F3A3D")
const COLOR_QING_BI: Color = Color("#4FA39B")
const COLOR_YUE_BAI: Color = Color("#E8ECEF")
const COLOR_ZHU_SHA: Color = Color("#C8453A")
const COLOR_LIU_JIN: Color = Color("#CBA75C")
const COLOR_ZI_CHEN: Color = Color("#8B6DB3")
const COLOR_DEEP_INK: Color = Color("#122426")

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
	"tu": COLOR_LIU_JIN,    # 土
}

signal layout_mode_changed(mode: String)

var layout_mode: String = "single"  # "multi" / "hybrid" / "single"


func _ready() -> void:
	refresh()


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
