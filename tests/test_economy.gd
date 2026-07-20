# test_economy.gd — T1 经济闭环 + E1-S6 推荐产出源（验证驱动，先此测试再实现）
# 覆盖：产出/消耗正确；fu_lu 日软预算≥10 封顶；free_ten_pull=10/日不计入软预算；
# po_dan 周~5；jue_xing_shi boss_only（非 Boss 来源被拒）；余额不足 spend→false；
# economy:currency_changed 广播；E1-S6 get_recommended_source。
extends GutTest

var _seen := []


func _fake_econ() -> Dictionary:
	return {
		"currencies": {
			"fu_lu":        { "daily_soft_cap": 12, "min_daily": 10, "can_accumulate": true },
			"ling_yu":      {},
			"ling_qi":      { "daily_cap": 2000 },
			"po_dan":       { "weekly_cap": 5 },
			"jue_xing_shi": { "boss_only": true },
		},
		"free_ten_pull": { "amount": 10 },
		"sources": {
			"fu_lu":        ["推图", "日常", "章节首通"],
			"ling_qi":      ["推图", "日常"],
			"po_dan":       ["推图", "日常"],
			"jue_xing_shi": ["Boss"],
			"ling_yu":      ["商城"],
		},
	}


func before_each() -> void:
	ConfigLoader.reset()
	ConfigLoader.inject("economy", _fake_econ())
	GameState.reset_all()
	EconomyManager.telemetry_log.clear()
	EconomyManager.set_date_override("2026-07-20")
	EconomyManager.set_week_override(30)
	_seen.clear()


func after_each() -> void:
	ConfigLoader.reset()
	EconomyManager.set_date_override("")
	EconomyManager.set_week_override(-1)


func _on_cc(currency: String, amount: int) -> void:
	_seen.append({ "c": currency, "a": amount })


# --- 基础产出/消耗 ---
func test_grant_and_spend_basic() -> void:
	assert_true(EconomyManager.grant("fu_lu", 5, "日常"), "grant 成功")
	assert_eq(GameState.currencies.get("fu_lu", 0), 5, "余额 5")
	assert_true(EconomyManager.spend("fu_lu", 3, "gacha"), "spend 成功")
	assert_eq(GameState.currencies.get("fu_lu", 0), 2, "余额 2")
	assert_false(EconomyManager.spend("fu_lu", 99, "gacha"), "余额不足被拒")
	assert_eq(GameState.currencies.get("fu_lu", 0), 2, "扣减被拦截，余额不变")


# --- fu_lu 日软预算封顶（E1-S4 AC1）---
func test_fu_lu_daily_soft_cap() -> void:
	assert_true(EconomyManager.grant("fu_lu", 12, "日常"), "达日软上限 12")
	assert_eq(GameState.currencies.get("fu_lu", 0), 12)
	assert_false(EconomyManager.grant("fu_lu", 1, "日常"), "超日软预算被拒")
	assert_eq(GameState.currencies.get("fu_lu", 0), 12, "封顶，余额不变")


# --- 免费十连独立额度，不计入软预算（pass2 解耦，E1-S1 AC3 / E1-S4 AC2）---
func test_free_ten_pull_decoupled_from_soft_budget() -> void:
	# 先吃满日软预算
	assert_true(EconomyManager.grant("fu_lu", 12, "日常"))
	# 领取免费十连：+10 符箓，且不占日软额度
	var got: int = EconomyManager.claim_free_ten_pull("2026-07-20")
	assert_eq(got, 10, "领取 10 免费符箓")
	assert_eq(GameState.currencies.get("fu_lu", 0), 22, "余额 22（12 软 + 10 免费）")
	# 日软预算仍满 -> 普通产出仍被拒，证明免费额未计入软预算
	assert_false(EconomyManager.grant("fu_lu", 1, "日常"), "软预算已满，普通产出仍拒")
	assert_eq(GameState.currencies.get("fu_lu", 0), 22, "仅免费额增加，软预算不变")


# --- po_dan 周产 ~5（E1-S1 AC2）---
func test_po_dan_weekly_cap() -> void:
	assert_true(EconomyManager.grant("po_dan", 5, "日常"), "达周上限 5")
	assert_eq(GameState.currencies.get("po_dan", 0), 5)
	assert_false(EconomyManager.grant("po_dan", 1, "日常"), "超周预算被拒")
	assert_eq(GameState.currencies.get("po_dan", 0), 5)


# --- jue_xing_shi 仅 Boss（boss_only，E1-S1 AC2）---
func test_jue_xing_shi_boss_only() -> void:
	assert_true(EconomyManager.grant("jue_xing_shi", 1, "Boss"), "Boss 来源可产出")
	assert_eq(GameState.currencies.get("jue_xing_shi", 0), 1)
	assert_false(EconomyManager.grant("jue_xing_shi", 1, "推图"), "非 Boss 来源被拒")
	assert_eq(GameState.currencies.get("jue_xing_shi", 0), 1, "仅 Boss 来源计入")


# --- 余额不足 spend 返回 false 且不扣减（E1-S3 AC1）---
func test_spend_insufficient_returns_false() -> void:
	assert_false(EconomyManager.spend("fu_lu", 999, "gacha"), "无余额被拒")
	assert_eq(GameState.currencies.get("fu_lu", 0), 0, "不扣减")


# --- economy:currency_changed 广播（临时 connect，断言后 disconnect，T1）---
func test_currency_changed_broadcast() -> void:
	EventBus.economy_currency_changed.connect(_on_cc)
	EconomyManager.grant("fu_lu", 7, "日常")
	EventBus.economy_currency_changed.disconnect(_on_cc)
	assert_eq(_seen.size(), 1, "恰好广播一次")
	assert_eq(_seen[0]["c"], "fu_lu")
	assert_eq(_seen[0]["a"], 7)


# --- 日界重置（E1-S4 AC2，可单测）---
func test_daily_reset_clears_production_tracker() -> void:
	EconomyManager.grant("fu_lu", 12, "日常")  # 吃满当日软额度
	assert_false(EconomyManager.grant("fu_lu", 1, "日常"), "当日内被拒")
	# 跨日重置
	EconomyManager.reset_daily_if_needed("2026-07-21")
	assert_true(EconomyManager.grant("fu_lu", 1, "日常"), "新一日额度恢复")


# --- E1-S6 资源缺口 -> 推荐产出源（UX §6 验收关键，AC3）---
func test_recommended_source_covers_boss_only() -> void:
	var ling_qi_src := EconomyManager.get_recommended_source("ling_qi")
	assert_true(ling_qi_src.has("推图"), "灵气含推图")
	assert_true(ling_qi_src.has("日常"), "灵气含日常")
	var jue_src := EconomyManager.get_recommended_source("jue_xing_shi")
	assert_eq(jue_src.size(), 1, "觉醒石仅 1 个来源")
	assert_eq(jue_src[0], "Boss", "觉醒石仅 Boss（boss_only）")
	var unknown := EconomyManager.get_recommended_source("does_not_exist")
	assert_eq(unknown.size(), 0, "未知货币返回空")
