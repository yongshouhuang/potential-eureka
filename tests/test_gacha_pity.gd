# test_gacha_pity.gd — T4 抽卡保底 + E2-S1 概率抽样（验证驱动）
# 覆盖：硬保底 90（必出 SSR）；软保底 50（SSR≥50%）；保底不跨池；
# 新手半价 + 必出 SR；基础概率抽样落入 ±2% 容差（种子化 RNG）。
extends GutTest

var g: GachaManager


func _fake_pools(ssr_base: float = 0.0) -> Dictionary:
	return {
		"pools": {
			"standard": {
				"id": "standard", "type": "standard",
				"rarity_rates": { "SSR": ssr_base, "SR": 0.10, "R": 0.35, "N": 0.55 },
				"soft_pity": 50, "hard_pity": 90,
				"shikigami_by_rarity": {
					"SSR": ["ssr_a"], "SR": ["sr_a"], "R": ["r_a"], "N": ["n_a"]
				}
			},
			"newbie": {
				"id": "newbie", "type": "newbie",
				"rarity_rates": { "SSR": ssr_base, "SR": 0.10, "R": 0.35, "N": 0.55 },
				"soft_pity": 50, "hard_pity": 90,
				"half_price_pulls": 20, "starter_sr_id": "sr_starter",
				"shikigami_by_rarity": {
					"SSR": ["ssr_a"], "SR": ["sr_starter", "sr_b"], "R": ["r_a"], "N": ["n_a"]
				}
			}
		}
	}


func _fake_econ_high_budget() -> Dictionary:
	return {
		"currencies": {
			"fu_lu": { "daily_soft_cap": 100000 },
		},
		"free_ten_pull": { "amount": 10 },
		"sources": { "fu_lu": ["推图"] },
	}


func before_each() -> void:
	ConfigLoader.reset()
	ConfigLoader.inject("gacha", _fake_pools(0.0))
	ConfigLoader.inject("economy", _fake_econ_high_budget())
	GameState.reset_all()
	g = GachaManager.new()
	g.rng = RNGWrapper.new(12345)


func after_each() -> void:
	ConfigLoader.reset()
	g = null


# --- 硬保底：第 90 抽（连续非 SSR 第 90 次）必出 SSR ---
# 用仅硬保底的池（soft 设极大，禁用软保底干扰），保证 1..89 抽均非 SSR，第 90 抽必 SSR。
func test_hard_pity_at_90() -> void:
	ConfigLoader.inject("gacha", _fake_pools_hard_only())
	var got_ssr := false
	var first_ssr_index := -1
	for i in 90:
		var r: Dictionary = g.roll_once("hard_only")
		if r.get("rarity") == "SSR":
			got_ssr = true
			first_ssr_index = i
			break
	assert_true(got_ssr, "第 90 抽必出 SSR（硬保底）")
	assert_eq(first_ssr_index, 89, "恰好在第 90 抽（0-based 89）首次出 SSR")


func _fake_pools_hard_only() -> Dictionary:
	return {
		"pools": {
			"hard_only": {
				"id": "hard_only", "type": "standard",
				"rarity_rates": { "SSR": 0.0, "SR": 0.10, "R": 0.35, "N": 0.55 },
				"soft_pity": 9999, "hard_pity": 90,
				"shikigami_by_rarity": { "SSR": ["ssr_a"], "SR": ["sr_a"], "R": ["r_a"], "N": ["n_a"] }
			}
		}
	}


# --- 硬保底确定性：pity=89 时下一抽强制 SSR（不依赖 RNG）---
func test_hard_pity_forces_on_90th() -> void:
	var pool: Dictionary = g._pool("standard")
	GameState.pity["standard"] = 89
	assert_eq(g._determine_rarity(pool, 89), "SSR", "pity=89 下一抽必 SSR")


# --- 软保底：第 50 抽 SSR 概率 ≥ 50%，并随抽数线性升（确定性查率函数）---
func test_soft_pity_rate_geq_50() -> void:
	var pool: Dictionary = g._pool("standard")
	assert_eq(g.effective_ssr_rate(0, pool), 0.0, "pity=0 用基础 0%")
	assert_true(g.effective_ssr_rate(49, pool) >= 0.5, "第 50 抽 ≥50%")
	assert_true(g.effective_ssr_rate(89, pool) > 0.95, "接近 90 抽趋近 100%")


# --- 软保底窗口 empirical 抽样（验证 C-1：< 修复后第 50 抽 SSR≈50% 而非 2%）---
# 对软保底窗口内的若干 pity 点，用种子化 RNG 抽样 _determine_rarity，
# 实测 SSR 频率应落入 effective_ssr_rate 期望 ±8% 容差（二项收敛，4k 样本极稳）。
func test_soft_pity_empirical_window() -> void:
	var pool: Dictionary = g._pool("standard")
	var n := 4000
	var checks := [
		{ "pity": 49, "expected": 0.5 },
		{ "pity": 59, "expected": 0.625 },
	]
	for c in checks:
		var p: int = c["pity"]
		var exp: float = c["expected"]
		var ssr := 0
		for i in n:
			if g._determine_rarity(pool, p) == "SSR":
				ssr += 1
		var freq: float = float(ssr) / float(n)
		assert_true(abs(freq - exp) <= 0.08, "pity=%d 实测 SSR 频率≈%.3f（期望 %.3f）" % [p, freq, exp])
	# 硬保底边界：pity=89 下一抽必 SSR（确定性，不入统计容差，与软保底上界衔接）
	assert_eq(g._determine_rarity(pool, 89), "SSR", "pity=89 下一抽必 SSR（硬保底）")


# --- 保底不跨池：pool_a 抽 89 次后，pool_b 从第 0 计 ---
func test_pity_not_cross_pool() -> void:
	# 用无保底干扰的池（soft/hard 设极大，SSR=0）确保 89 次均非 SSR
	ConfigLoader.inject("gacha", _fake_pools_no_pity())
	for i in 89:
		g.roll_once("pool_a")
	assert_eq(g.get_pity("pool_a"), 89, "pool_a 计到 89")
	assert_eq(g.get_pity("pool_b"), 0, "pool_b 从第 0 起，不继承")
	g.roll_once("pool_b")
	assert_eq(g.get_pity("pool_b"), 1, "切池后独立 +1")


# --- 新手池：首次必出指定 SR 起步式神 ---
func test_newbie_forced_starter_sr() -> void:
	var r: Dictionary = g.roll_once("newbie")
	assert_eq(r.get("shikigami_id"), "sr_starter", "必出起步 SR")
	assert_eq(r.get("rarity"), "SR", "起步式为 SR")


# --- 新手池：前 20 抽半价（20 抽共耗 10 符箓）---
func test_newbie_half_price() -> void:
	EconomyManager.grant("fu_lu", 100, "推图")
	assert_eq(GameState.currencies.get("fu_lu", 0), 100)
	g.pull("newbie", 20)
	assert_eq(GameState.currencies.get("fu_lu", 0), 90, "20 抽半价共耗 10 符箓")
	# 第 21 抽起全价
	g.pull("newbie", 1)
	assert_eq(GameState.currencies.get("fu_lu", 0), 89, "第 21 抽全价 -1")


# --- E2-S1 概率抽样：10k 次落入公示 ±2% 容差（种子化 RNG）---
func test_rates_within_tolerance() -> void:
	var rates := { "SSR": 0.02, "SR": 0.10, "R": 0.35, "N": 0.53 }
	var counts := { "SSR": 0, "SR": 0, "R": 0, "N": 0 }
	var n := 10000
	for i in n:
		counts[g._weighted_roll(rates)] += 1
	var tol := 0.02
	assert_true(abs(float(counts["SSR"]) / n - 0.02) <= tol, "SSR 频率≈2%")
	assert_true(abs(float(counts["SR"]) / n - 0.10) <= tol, "SR 频率≈10%")
	assert_true(abs(float(counts["R"]) / n - 0.35) <= tol, "R 频率≈35%")
	assert_true(abs(float(counts["N"]) / n - 0.53) <= tol, "N 频率≈53%")


# --- 概率公示数据可读取（E2-S5 双端展示）---
func test_get_probabilities_exposed() -> void:
	var p: Dictionary = g.get_probabilities("standard")
	assert_eq(p.get("SSR"), 0.0, "注入的 0% 池可读")
	assert_eq(p.get("N"), 0.55)


func _fake_pools_no_pity() -> Dictionary:
	return {
		"pools": {
			"pool_a": {
				"id": "pool_a", "type": "standard",
				"rarity_rates": { "SSR": 0.0, "SR": 0.10, "R": 0.35, "N": 0.55 },
				"soft_pity": 9999, "hard_pity": 9999,
				"shikigami_by_rarity": { "SSR": ["x"], "SR": ["x"], "R": ["x"], "N": ["x"] }
			},
			"pool_b": {
				"id": "pool_b", "type": "standard",
				"rarity_rates": { "SSR": 0.0, "SR": 0.10, "R": 0.35, "N": 0.55 },
				"soft_pity": 9999, "hard_pity": 9999,
				"shikigami_by_rarity": { "SSR": ["x"], "SR": ["x"], "R": ["x"], "N": ["x"] }
			},
		}
	}
