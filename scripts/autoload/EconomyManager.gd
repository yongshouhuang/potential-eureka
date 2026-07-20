# EconomyManager.gd — 基础资源经济闭环（B1 / E1 S1–S6）
# 货币与预算来自 data/economy（经 ConfigLoader）。所有变更经 EventBus 广播。
# 硬约束：只与 EventBus / GameState / ConfigLoader / 全局单例交互，不 preload/import 其它管理器。
extends Node

# 默认免费十连额度（被 data/economy 覆盖）
const DEFAULT_FREE_TEN := 10

# 遥测日志（MVP 落内存，供 B5 Demo 计算产出/消耗比，E1-S5）
var telemetry_log: Array = []

# 测试可注入的「今天/本周」覆盖（避免依赖真实系统时钟）
var _date_override: String = ""
var _week_override: int = -1


# ---------- 配置读取 ----------
func _econ() -> Dictionary:
	return ConfigLoader.load_table("economy", "res://data/economy/economy_config.json")


func _currency_cfg(currency: String) -> Dictionary:
	var c: Dictionary = _econ().get("currencies", {})
	if c.has(currency):
		return c[currency]
	return {}


# ---------- 产出 / 消耗 ----------
# grant：增加货币。遵守 boss_only 与日/周预算（免费十连可经 exempt_from_budget 解耦）。
# 返回是否成功（被拒返回 false 且不改动状态）。
func grant(currency: String, amount: int, source: String, exempt_from_budget: bool = false) -> bool:
	if amount <= 0:
		return false
	var cfg := _currency_cfg(currency)
	# boss_only：仅 "Boss" 来源可产出
	if cfg.get("boss_only", false) and source != "Boss":
		return false
	# 预算硬上限（免费十连豁免）
	if not exempt_from_budget:
		if not _within_budget(currency, amount, cfg):
			return false
	GameState.currencies[currency] = int(GameState.currencies.get(currency, 0)) + amount
	_record_production(currency, amount, cfg, exempt_from_budget)
	EventBus.economy_currency_changed.emit(currency, amount)
	_log_telemetry("grant", currency, amount, source)
	return true


# spend：校验余额；不足返回 false 且不扣减；成功则扣减 + 广播。
func spend(currency: String, amount: int, sink: String) -> bool:
	var bal: int = int(GameState.currencies.get(currency, 0))
	if bal < amount:
		return false
	GameState.currencies[currency] = bal - amount
	EventBus.economy_currency_changed.emit(currency, -amount)
	EventBus.economy_reward_granted.emit(currency, amount, sink)
	_log_telemetry("spend", currency, -amount, sink)
	return true


# ---------- 免费十连独立额度（pass2 解耦，不计入软预算）----------
# 返回实际领取的符箓数（已领过返回 0）。
func claim_free_ten_pull(today_date: String = "") -> int:
	var today := today_date if today_date != "" else _current_date()
	# 新的一天 -> 重置 claimed 标记
	if GameState.free_ten_pull.get("last_claim_date", "") != today:
		GameState.free_ten_pull["claimed_today"] = false
	if GameState.free_ten_pull.get("claimed_today", false):
		return 0
	var amt: int = int(_econ().get("free_ten_pull", {}).get("amount", DEFAULT_FREE_TEN))
	GameState.free_ten_pull["last_claim_date"] = today
	GameState.free_ten_pull["claimed_today"] = true
	# 经 grant 但豁免软预算 -> 进入余额但不占日软产出额度
	grant("fu_lu", amt, "free_ten_pull", true)
	return amt


# ---------- 日/周预算判定（可单测）----------
func _period_key(currency: String, cfg: Dictionary) -> String:
	if cfg.has("weekly_cap"):
		return "W%d" % _current_week()
	return "D%s" % _current_date()


func _production_used(currency: String) -> int:
	var t: Dictionary = GameState.production_tracker.get(currency, {})
	return int(t.get("amount", 0))


func _record_production(currency: String, amount: int, cfg: Dictionary, exempt: bool) -> void:
	if exempt:
		return
	var key := _period_key(currency, cfg)
	var t: Dictionary = GameState.production_tracker.get(currency, { "period": key, "amount": 0 })
	if t.get("period", "") != key:
		t = { "period": key, "amount": 0 }
	t["amount"] = int(t.get("amount", 0)) + amount
	GameState.production_tracker[currency] = t


func _within_budget(currency: String, amount: int, cfg: Dictionary) -> bool:
	var cap: int = -1
	if cfg.has("daily_soft_cap"):
		cap = int(cfg["daily_soft_cap"])
	elif cfg.has("daily_cap"):
		cap = int(cfg["daily_cap"])
	elif cfg.has("weekly_cap"):
		cap = int(cfg["weekly_cap"])
	if cap < 0:
		return true
	var key := _period_key(currency, cfg)
	var t: Dictionary = GameState.production_tracker.get(currency, {})
	if t.get("period", "") != key:
		return amount <= cap  # 新周期，从 0 计
	return int(t.get("amount", 0)) + amount <= cap


# 按日期/周序号重置（覆盖前写 cache 由 SaveManager 负责）。
# 由主流程在加载/新日时调用；也可单测注入日期。
func reset_daily_if_needed(today_date: String = "") -> void:
	var today := today_date if today_date != "" else _current_date()
	for cur in GameState.production_tracker.keys():
		var t: Dictionary = GameState.production_tracker[cur]
		if not t.get("period", "").begins_with("W") and t.get("period", "") != ("D" + today):
			GameState.production_tracker[cur] = { "period": "D" + today, "amount": 0 }
	# 免费十连：跨日重置
	if GameState.free_ten_pull.get("last_claim_date", "") != today:
		GameState.free_ten_pull["claimed_today"] = false


func reset_weekly_if_needed(week: int = -1) -> void:
	var wk := week if week >= 0 else _current_week()
	for cur in GameState.production_tracker.keys():
		var t: Dictionary = GameState.production_tracker[cur]
		if t.get("period", "").begins_with("W") and t.get("period", "") != ("W%d" % wk):
			GameState.production_tracker[cur] = { "period": "W%d" % wk, "amount": 0 }


# ---------- E1-S6 资源缺口 -> 推荐产出源（R1 · UX §6 验收关键）----------
# 来源由 data/economy 的 sources 字段驱动（经 ConfigLoader 注入）。
func get_recommended_source(deficit_currency: String) -> Array[String]:
	var src: Dictionary = _econ().get("sources", {})
	var out: Array[String] = []
	if src.has(deficit_currency):
		for s in src[deficit_currency]:
			out.append(String(s))
	return out


# ---------- 时间覆盖（测试注入）----------
func set_date_override(date_str: String) -> void:
	_date_override = date_str


func set_week_override(week: int) -> void:
	_week_override = week


func _current_date() -> String:
	if _date_override != "":
		return _date_override
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func _current_week() -> int:
	if _week_override >= 0:
		return _week_override
	return int(Time.get_datetime_dict_from_system().get("week", 1))


func _log_telemetry(kind: String, currency: String, amount: int, ctx: String) -> void:
	telemetry_log.append({
		"kind": kind,
		"currency": currency,
		"amount": amount,
		"ctx": ctx,
		"ts": Time.get_unix_time_from_system(),
	})
