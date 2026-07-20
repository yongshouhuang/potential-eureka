# test_combo_banner.gd — S3-UI-Battle 连携横幅数值格式化（验证驱动，headless）
# 覆盖：bond_combo 信号 → 横幅数值格式化正确（0.175 → +17.5%，tabular）。
# 直接校验 ComboBanner.format_bonus 静态函数（横幅渲染的真实逻辑，无场景依赖）。
extends GutTest

const CB = preload("res://scripts/ui/ComboBanner.gd")

# --- 0.175 → +17.5% ---
func test_format_0175() -> void:
	assert_eq(CB.format_bonus(0.175), "+17.5%", "0.175 -> +17.5%")

# --- 0.10 → +10.0%（中点下限）---
func test_format_010() -> void:
	assert_eq(CB.format_bonus(0.10), "+10.0%", "0.10 -> +10.0%")

# --- 0.20 → +20.0%（中点上限）---
func test_format_020() -> void:
	assert_eq(CB.format_bonus(0.20), "+20.0%", "0.20 -> +20.0%")

# --- 0.0 → +0.0%（无连携，不应出现横幅）---
func test_format_0() -> void:
	assert_eq(CB.format_bonus(0.0), "+0.0%", "0.0 -> +0.0%")

# --- 精度固定 1 位（tabular 防抖）---
func test_format_precision() -> void:
	assert_eq(CB.format_bonus(0.12345), "+12.3%", "截取 1 位小数（非 12.345%）")
