# test_dual_end.gd — E5-S4 双端跑通 + 旋转稳定（验证驱动，headless）
# 覆盖：
#  AC1  PC 横屏(≥1024, multi) / 移动竖屏(<768, single) 双端跑通核心闭环；
#  AC2  旋转/分辨率切换不丢状态（等价逻辑：宽度变化→layout_mode 变化且不丢 GameState）。
# 核心闭环经 DemoLoop（scripts/core/DemoLoop.gd）无 UI 驱动，
# 并串联 TelemetryAggregator 校验「抽→养→战→回流」四阶段事件可达。
extends GutTest


func _fake_shikigami_defs() -> Dictionary:
	return {
		"shikigami": {
			"hero": { "name": "侠客", "element": "metal", "rarity": "SSR",
				"bond_tags": [], "base_stats": { "hp": 500, "atk": 200 }, "skills": ["sk_hero"] }
		}
	}


func _fake_gacha() -> Dictionary:
	# 所有稀有度均映射到 hero，确保抽到的式神必在 shikigami_defs（闭环可 build）
	return {
		"pools": {
			"standard": {
				"id": "standard", "type": "standard",
				"rarity_rates": { "SSR": 0.02, "SR": 0.10, "R": 0.35, "N": 0.53 },
				"soft_pity": 50, "hard_pity": 90,
				"shikigami_by_rarity": { "SSR": ["hero"], "SR": ["hero"], "R": ["hero"], "N": ["hero"] }
			}
		}
	}


func _fake_skill_defs() -> Dictionary:
	return { "skills": { "sk_hero": { "element": "metal", "power": 1.0, "status_on_hit": null } } }


func _fake_cultivation() -> Dictionary:
	return {
		"breakthrough": { "max_tier": 6, "level_cap_per_tier": [20, 36, 52, 64, 72, 80],
			"attr_gain_pct_min": 0.08, "attr_gain_pct_max": 0.12, "passive_slots_per_tier": [1, 2, 3, 4, 5, 6] },
		"level_curve": { "hp_per_level_pct_min": 0.02, "hp_per_level_pct_max": 0.03,
			"atk_per_level_pct_min": 0.02, "atk_per_level_pct_max": 0.03 },
		"upgrade": { "ling_qi_per_level": 50 },
		"breakthrough_cost": { "po_dan_per_tier": 1, "fragments_per_tier": 5 },
		"awaken": { "tier_threshold": 3, "skills_by_shikigami": {} },
		"branches": { "sword": { "passive": "jian_xiu_passive" }, "body": { "passive": "ti_xiu_passive" } }
	}


func _fake_econ() -> Dictionary:
	return {
		"currencies": {
			"fu_lu": { "daily_cap": 100000 },
			"ling_qi": { "daily_cap": 100000 },
			"po_dan": { "weekly_cap": 100 },
			"jue_xing_shi": { "boss_only": true }
		},
		"free_ten_pull": { "amount": 10 },
		"sources": {}
	}


func _fake_chapters() -> Dictionary:
	return {
		"chapters": [{
			"id": 1, "name": "第1章",
			"stages": [
				{ "id": 1, "boss": false,
					"enemies": [ { "id": "e1", "element": "earth", "stats": { "hp": 10, "atk": 20 } } ],
					"reward": { "fu_lu": [1, 3], "po_dan": 0, "jue_xing_shi": 0 } }
			]
		}]
	}


func _fake_bond_combos() -> Dictionary:
	return { "groups": {} }   # 单式神编队 -> 无连携


func _fake_element_matrix() -> Dictionary:
	return {
		"ke": { "metal": "wood", "wood": "earth", "earth": "water", "water": "fire", "fire": "metal" },
		"sheng": { "wood": "fire", "fire": "earth", "earth": "metal", "metal": "water", "water": "wood" },
		"advantage_min": 1.25, "advantage_max": 1.35,
		"disadvantage_min": 0.7, "disadvantage_max": 0.8,
		"sheng_bonus_min": 1.02, "sheng_bonus_max": 1.05
	}


func before_each() -> void:
	ConfigLoader.reset()
	ConfigLoader.inject("gacha", _fake_gacha())
	ConfigLoader.inject("shikigami", _fake_shikigami_defs())
	ConfigLoader.inject("battle/skill_defs", _fake_skill_defs())
	ConfigLoader.inject("cultivation", _fake_cultivation())
	ConfigLoader.inject("economy", _fake_econ())
	ConfigLoader.inject("battle/chapters", _fake_chapters())
	ConfigLoader.inject("battle/bond_combos", _fake_bond_combos())
	ConfigLoader.inject("battle/element_matrix", _fake_element_matrix())
	GameState.reset_all()
	EconomyManager.set_date_override("2026-07-20")
	EconomyManager.set_week_override(30)
	UIThemeController.set_layout_mode("single")  # 默认起始（移动竖屏）


func after_each() -> void:
	ConfigLoader.reset()
	EconomyManager.set_date_override("")
	EconomyManager.set_week_override(-1)


# --- AC1 断点三档：compute_layout_mode 纯函数断言 ---
func test_compute_layout_mode_three_tiers() -> void:
	assert_eq(UIThemeController.compute_layout_mode(1280), "multi", "PC横屏 ≥1024 -> multi")
	assert_eq(UIThemeController.compute_layout_mode(1024), "multi", "边界 1024 -> multi")
	assert_eq(UIThemeController.compute_layout_mode(900), "hybrid", "768–1024 -> hybrid")
	assert_eq(UIThemeController.compute_layout_mode(768), "hybrid", "边界 768 -> hybrid")
	assert_eq(UIThemeController.compute_layout_mode(390), "single", "移动竖屏 <768 -> single")
	assert_eq(UIThemeController.compute_layout_mode(767), "single", "边界 767 -> single")


# --- AC1 核心闭环在 multi(PC横屏) 下 headless 跑通（无 UI 依赖）---
func test_core_loop_runs_in_multi_layout() -> void:
	UIThemeController.set_layout_mode("multi")
	var agg := TelemetryAggregator.new()
	agg.attach()
	var report: Dictionary = DemoLoop.run("standard", 1, 1, agg)
	agg.detach()
	assert_true(report["ok"], "multi 布局下闭环跑通(胜利)")
	assert_ne(report["pulled_id"], "", "multi: 抽到式神")
	assert_true(int(report["cultivated_level"]) > int(report["cultivated_before_level"]), "multi: 养成提升")
	assert_eq(report["battle_outcome"], "victory", "multi: 战斗结算胜利")
	var c: Dictionary = agg.get_counts()
	assert_true(int(c["gacha_pulled"]) >= 1, "multi: 遥测 抽≥1")
	assert_true(int(c["cultivate_leveled"]) >= 1, "multi: 遥测 养≥1")
	assert_true(int(c["battle_resolved"]) >= 1, "multi: 遥测 战≥1")
	assert_true(int(c["player_reengaged"]) >= 1, "multi: 遥测 回流≥1")


# --- AC1 核心闭环在 single(移动竖屏) 下 headless 跑通（无 UI 依赖）---
func test_core_loop_runs_in_single_layout() -> void:
	UIThemeController.set_layout_mode("single")
	var agg := TelemetryAggregator.new()
	agg.attach()
	var report: Dictionary = DemoLoop.run("standard", 1, 1, agg)
	agg.detach()
	assert_true(report["ok"], "single 布局下闭环跑通(胜利)")
	assert_ne(report["pulled_id"], "", "single: 抽到式神")
	assert_true(int(report["cultivated_level"]) > int(report["cultivated_before_level"]), "single: 养成提升")
	assert_eq(report["battle_outcome"], "victory", "single: 战斗结算胜利")
	var c: Dictionary = agg.get_counts()
	assert_true(int(c["gacha_pulled"]) >= 1, "single: 遥测 抽≥1")
	assert_true(int(c["cultivate_leveled"]) >= 1, "single: 遥测 养≥1")
	assert_true(int(c["battle_resolved"]) >= 1, "single: 遥测 战≥1")
	assert_true(int(c["player_reengaged"]) >= 1, "single: 遥测 回流≥1")


# --- AC2 旋转/分辨率切换不丢状态（等价逻辑）---
# 核心思想：GameState 是单一真源且与 layout_mode 解耦；宽度变化仅改 layout_mode，
# 不触动任何玩家状态。此处断言：宽度变化→layout_mode 变化，且 GameState 快照不变；
# 双向旋转后仍可保持（不破版、不丢焦点/状态）。
func test_rotation_preserves_state() -> void:
	# PC 横屏起步
	UIThemeController.set_layout_mode(UIThemeController.compute_layout_mode(1280))  # multi
	var mode_before: String = UIThemeController.layout_mode
	assert_eq(mode_before, "multi", "起始为 multi(PC横屏)")

	# 建立一些玩家状态（模拟已进行到某进度）
	EconomyManager.grant("fu_lu", 50, "demo_seed")
	GameState.shikigami = [{
		"id": "hero", "level": 5, "breakthrough": 1, "awakened_skills": [],
		"bond_level": 0, "fragments": 99, "branch": ""
	}]
	GameState.deck = ["hero"]
	var currencies_before: Dictionary = GameState.currencies.duplicate(true)
	var shiki_before: Array = GameState.shikigami.duplicate(true)
	var deck_before: Array = GameState.deck.duplicate()

	# 旋转到移动竖屏（等价：宽度 1280 -> 390）
	var new_mode: String = UIThemeController.compute_layout_mode(390)  # single
	UIThemeController.set_layout_mode(new_mode)
	assert_ne(UIThemeController.layout_mode, mode_before, "旋转后 layout_mode 变化(multi->single)")
	assert_eq(UIThemeController.layout_mode, "single", "旋转后进入 single")

	# 状态不丢
	assert_eq(GameState.currencies, currencies_before, "旋转后货币状态不丢")
	assert_eq(GameState.shikigami, shiki_before, "旋转后式神状态不丢")
	assert_eq(GameState.deck, deck_before, "旋转后编队状态不丢")

	# 旋转回来（宽度 390 -> 1280）
	UIThemeController.set_layout_mode(UIThemeController.compute_layout_mode(1280))
	assert_eq(UIThemeController.layout_mode, "multi", "旋转回 PC 横屏")
	assert_eq(GameState.currencies, currencies_before, "旋转回来后货币仍不丢")
	assert_eq(GameState.shikigami, shiki_before, "旋转回来后式神仍不丢")
	assert_eq(GameState.deck, deck_before, "旋转回来后编队仍不丢")


# --- AC2 延伸：旋转后闭环仍可继续 headless 跑通（不破版）---
func test_core_loop_after_rotation() -> void:
	# 模拟从移动竖屏旋转到 PC 横屏后再跑闭环
	UIThemeController.set_layout_mode("single")
	var new_mode: String = UIThemeController.compute_layout_mode(1280)
	UIThemeController.set_layout_mode(new_mode)
	assert_eq(UIThemeController.layout_mode, "multi", "旋转到 multi")
	var agg := TelemetryAggregator.new()
	agg.attach()
	var report: Dictionary = DemoLoop.run("standard", 1, 1, agg)
	agg.detach()
	assert_true(report["ok"], "旋转后闭环仍 headless 跑通")
	assert_true(int(agg.get_counts()["battle_resolved"]) >= 1, "旋转后 战 阶段可达")
