# TelemetryAggregator.gd — headless 遥测聚合器（E5-S3 / E5-S1）
# =====================================================================
# 订阅 EventBus 的 4 类遥测事件（telemetry:*），按 session 串联
# 「抽 → 养 → 战 → 回流」漏斗，输出可读转化率。
#
# 设计要点：
#  - 仅经 EventBus 订阅（零跨管理器 import），遵守架构解耦红线。
#  - session 可串联：实例生命周期内累计 counts；reset_counts() 可清空以开启新 session；
#    多次 attach/detach 安全（基于实例方法去重）。
#  - 纯数据/统计，不持有任何游戏逻辑；DemoLoop / GUT 测试 / 真机 Demo 均可复用。
extends RefCounted
class_name TelemetryAggregator

# 漏斗四阶段（顺序即 抽→养→战→回流）
const STAGES := ["gacha_pulled", "cultivate_leveled", "battle_resolved", "player_reengaged"]

var session_id: String = ""
var _counts: Dictionary = {}
var _log: Array = []          # 有序事件流：{stage, ...}
var _attached: bool = false


func _init(p_session_id: String = "") -> void:
	session_id = p_session_id if p_session_id != "" else "sess_%d" % int(Time.get_unix_time_from_system())
	reset_counts()


# 订阅 4 类遥测信号（幂等：已订阅则跳过）
func attach() -> void:
	if _attached:
		return
	EventBus.telemetry_gacha_pulled.connect(_on_gacha_pulled)
	EventBus.telemetry_cultivate_leveled.connect(_on_cultivate_leveled)
	EventBus.telemetry_battle_resolved.connect(_on_battle_resolved)
	EventBus.telemetry_player_reengaged.connect(_on_player_reengaged)
	_attached = true


# 取消订阅（幂等）；应成对调用以释放信号连接
func detach() -> void:
	if not _attached:
		return
	EventBus.telemetry_gacha_pulled.disconnect(_on_gacha_pulled)
	EventBus.telemetry_cultivate_leveled.disconnect(_on_cultivate_leveled)
	EventBus.telemetry_battle_resolved.disconnect(_on_battle_resolved)
	EventBus.telemetry_player_reengaged.disconnect(_on_player_reengaged)
	_attached = false


# 清空累计（保留 session_id 与订阅状态），用于开启新 session 串联
func reset_counts() -> void:
	_counts = { "gacha_pulled": 0, "cultivate_leveled": 0, "battle_resolved": 0, "player_reengaged": 0 }
	_log.clear()


# ---------- 事件处理 ----------
func _on_gacha_pulled(shikigami_id: String, rarity: String) -> void:
	_counts["gacha_pulled"] += 1
	_log.append({ "stage": "gacha_pulled", "shikigami_id": shikigami_id, "rarity": rarity })


func _on_cultivate_leveled(shikigami_id: String, new_level: int) -> void:
	_counts["cultivate_leveled"] += 1
	_log.append({ "stage": "cultivate_leveled", "shikigami_id": shikigami_id, "new_level": new_level })


func _on_battle_resolved(chapter: int, stage: int, outcome: String) -> void:
	_counts["battle_resolved"] += 1
	_log.append({ "stage": "battle_resolved", "chapter": chapter, "stage_id": stage, "outcome": outcome })


func _on_player_reengaged(source: String) -> void:
	_counts["player_reengaged"] += 1
	_log.append({ "stage": "player_reengaged", "source": source })


# ---------- 查询 ----------
func is_attached() -> bool:
	return _attached


func get_counts() -> Dictionary:
	return _counts.duplicate()


func get_log() -> Array:
	return _log.duplicate()


# 漏斗转化率（环节 / 上一环节）。上一环节为 0 时记 0.0（避免除零）。
func get_funnel() -> Dictionary:
	var g: int = int(_counts["gacha_pulled"])
	var c: int = int(_counts["cultivate_leveled"])
	var b: int = int(_counts["battle_resolved"])
	var r: int = int(_counts["player_reengaged"])
	return {
		"gacha_pulled": g,
		"cultivate_leveled": c,
		"battle_resolved": b,
		"player_reengaged": r,
		"conv_pull_to_cultivate": _rate(c, g),
		"conv_cultivate_to_battle": _rate(b, c),
		"conv_battle_to_reengage": _rate(r, b),
		"conv_overall_pull_to_reengage": _rate(r, g),
	}


func _rate(num: int, den: int) -> float:
	if den <= 0:
		return 0.0
	return float(num) / float(den)


# 可读漏斗报告（Demo 实跑导出样例日志用）
func format_report() -> String:
	var f: Dictionary = get_funnel()
	var lines := PackedStringArray()
	lines.append("=== 遥测漏斗 (session=%s) ===" % session_id)
	lines.append("抽 gacha_pulled       : %d" % f["gacha_pulled"])
	lines.append("养 cultivate_leveled  : %d" % f["cultivate_leveled"])
	lines.append("战 battle_resolved     : %d" % f["battle_resolved"])
	lines.append("回流 player_reengaged  : %d" % f["player_reengaged"])
	lines.append("--- 环节转化率 ---")
	lines.append("抽 → 养   : %.1f%%" % (f["conv_pull_to_cultivate"] * 100.0))
	lines.append("养 → 战   : %.1f%%" % (f["conv_cultivate_to_battle"] * 100.0))
	lines.append("战 → 回流 : %.1f%%" % (f["conv_battle_to_reengage"] * 100.0))
	lines.append("抽 → 回流 : %.1f%%" % (f["conv_overall_pull_to_reengage"] * 100.0))
	return "\n".join(lines)
