# AccessibilitySettings.gd — 可访问性集中设置单例（E6-S5 部分 / S1 须存在）
# 架构 CONCERN 桥接项：独立 peer autoload（非并入 UIThemeController），
# 持有 high_contrast/reduce_motion/text_scale/color_blind_mode/cvd_filter/
# performance_mode/dynamic_text，变更 emit accessibility_changed。
# UIThemeController 订阅该信号应用高对比/缩放/CVD（CVD 完整接线留 S3）。
# 设置持久化至 GameState.settings（对齐 schema v1 settings 字段）。
# MotionScale 动效总线在此先留种子（E6-S6 收口）。
extends Node

enum ColorBlind { NONE, DEUTER, PROTAN, TRITAN }

const TEXT_SCALE_MIN := 1.0
const TEXT_SCALE_MAX := 1.3

signal accessibility_changed(snapshot: Dictionary)

var high_contrast: bool = false
var reduce_motion: bool = false
var text_scale: float = 1.0
var color_blind_mode: int = ColorBlind.NONE
var cvd_filter: bool = false
var performance_mode: bool = false
var dynamic_text: bool = false


func _ready() -> void:
	# 从已存档设置恢复（若有）
	if GameState.settings.size() > 0:
		_apply_from_dict(GameState.settings)


# 动效总线：reduce_motion 时 = 0，VFX/粒子/视差/光扫读取此值（E6-S6 种子）
func get_motion_scale() -> float:
	return 0.0 if reduce_motion else 1.0


# 取完整快照（供持久化与 UI 订阅）
func get_snapshot() -> Dictionary:
	return {
		"high_contrast": high_contrast,
		"reduce_motion": reduce_motion,
		"text_scale": text_scale,
		"color_blind_mode": color_blind_mode,
		"cvd_filter": cvd_filter,
		"performance_mode": performance_mode,
		"dynamic_text": dynamic_text,
	}


# ---- 设置器（变更才 emit + 持久化）----
func set_high_contrast(v: bool) -> void:
	if high_contrast != v:
		high_contrast = v
		_commit()


func set_reduce_motion(v: bool) -> void:
	if reduce_motion != v:
		reduce_motion = v
		_commit()


func set_text_scale(v: float) -> void:
	v = clampf(v, TEXT_SCALE_MIN, TEXT_SCALE_MAX)
	if text_scale != v:
		text_scale = v
		_commit()


func set_color_blind_mode(mode: int) -> void:
	if color_blind_mode != mode:
		color_blind_mode = mode
		_commit()


func set_cvd_filter(v: bool) -> void:
	if cvd_filter != v:
		cvd_filter = v
		_commit()


func set_performance_mode(v: bool) -> void:
	if performance_mode != v:
		performance_mode = v
		_commit()


func set_dynamic_text(v: bool) -> void:
	if dynamic_text != v:
		dynamic_text = v
		_commit()


# 批量应用（供读档恢复）
func apply_dict(d: Dictionary) -> void:
	_apply_from_dict(d)
	_commit()


# ---- 内部 ----
func _apply_from_dict(d: Dictionary) -> void:
	if d.has("high_contrast"):
		high_contrast = bool(d["high_contrast"])
	if d.has("reduce_motion"):
		reduce_motion = bool(d["reduce_motion"])
	if d.has("text_scale"):
		text_scale = clampf(float(d["text_scale"]), TEXT_SCALE_MIN, TEXT_SCALE_MAX)
	if d.has("color_blind_mode"):
		color_blind_mode = int(d["color_blind_mode"])
	if d.has("cvd_filter"):
		cvd_filter = bool(d["cvd_filter"])
	if d.has("performance_mode"):
		performance_mode = bool(d["performance_mode"])
	if d.has("dynamic_text"):
		dynamic_text = bool(d["dynamic_text"])


func _commit() -> void:
	var snap := get_snapshot()
	GameState.settings = snap
	accessibility_changed.emit(snap)
