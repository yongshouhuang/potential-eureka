# test_telemetry_loop.gd — E5-S3 埋点贯通（抽→养→战→回流）验证（验证驱动，headless）
# 覆盖：
#  AC1  四类环节 emit 遥测事件贯通——抽 telemetry_gacha_pulled → 养 telemetry_cultivate_leveled
#       → 战 telemetry_battle_resolved → 回流 telemetry_player_reengaged；
#  AC2  TelemetryAggregator 按 session 串联四类事件，导出漏斗 + 转化率；
#  AC3  单测覆盖——一次模拟闭环产生四类事件且阶段完整；战败不触发回流（正交）。
# 复用与 test_dual_end 一致的注入环境（抽→养→战→回流 闭环可达）。
extends GutTest


func _fake_shikigami_defs() -> Dictionary:
	return {
		"shikigami": {
			"hero": { "name": "侠客", "element": "metal", "rarity": "SSR",
				"bond_tags": [], "base_stats": { "hp": 500, "atk": 200 }, "skills": ["sk_hero"] }
		}
	}


func _fake_gacha() -> Dictionary:
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
	return { "groups": {} }


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


func after_each() -> void:
	ConfigLoader.reset()
	EconomyManager.set_date_override("")
	EconomyManager.set_week_override(-1)


# --- AC1/AC2/AC3 一次模拟闭环产生四类事件且阶段完整；漏斗转化率可读 ---
func test_telemetry_funnel_four_stages() -> void:
	var agg := TelemetryAggregator.new()
	agg.attach()
	var report: Dictionary = DemoLoop.run("standard", 1, 1, agg)
	agg.detach()

	assert_true(report["ok"], "闭环跑通(胜利)")
	var c: Dictionary = agg.get_counts()
	assert_true(int(c["gacha_pulled"]) >= 1, "抽 阶段有事件(telemetry_gacha_pulled)")
	assert_true(int(c["cultivate_leveled"]) >= 1, "养 阶段有事件(telemetry_cultivate_leveled)")
	assert_true(int(c["battle_resolved"]) >= 1, "战 阶段有事件(telemetry_battle_resolved)")
	assert_true(int(c["player_reengaged"]) >= 1, "回流 阶段有事件(telemetry_player_reengaged)")

	# 四阶段均出现在有序日志中
	var seen: Array = []
	for e in agg.get_log():
		seen.append(e["stage"])
	assert_true("gacha_pulled" in seen, "日志含 抽")
	assert_true("cultivate_leveled" in seen, "日志含 养")
	assert_true("battle_resolved" in seen, "日志含 战")
	assert_true("player_reengaged" in seen, "日志含 回流")

	# 单次完整闭环：各相邻环节转化率应为 100%
	var f: Dictionary = agg.get_funnel()
	assert_eq(f["conv_pull_to_cultivate"], 1.0, "抽→养 100%")
	assert_eq(f["conv_cultivate_to_battle"], 1.0, "养→战 100%")
	assert_eq(f["conv_battle_to_reengage"], 1.0, "战→回流 100%")


# --- AC1 证明事件「实际 emit」而非仅定义：直接订阅 4 类信号计数 ---
func test_telemetry_signals_actually_emitted() -> void:
	var got := { "gacha": 0, "cultivate": 0, "battle": 0, "reengage": 0 }
	# 存 Callable 引用，便于后续 disconnect 时使用同一实例（Godot 4 不允许用新 lambda 字面量 disconnect）
	var cb_gacha: Callable = func(_a, _b: String): got["gacha"] += 1
	var cb_cultivate: Callable = func(_a, _b: int): got["cultivate"] += 1
	var cb_battle: Callable = func(_a, _b, _c: String): got["battle"] += 1
	var cb_reengage: Callable = func(_a: String): got["reengage"] += 1
	EventBus.telemetry_gacha_pulled.connect(cb_gacha)
	EventBus.telemetry_cultivate_leveled.connect(cb_cultivate)
	EventBus.telemetry_battle_resolved.connect(cb_battle)
	EventBus.telemetry_player_reengaged.connect(cb_reengage)

	# 直接驱动一次完整流（不依赖 TelemetryAggregator，验证信号本体被 emit）
	EconomyManager.claim_free_ten_pull("2026-07-20")
	var pulled: Array = GachaManager.pull("standard", 1)
	assert_false(pulled.is_empty(), "抽到式神")
	var sid: String = String(pulled[0]["shikigami_id"])
	EconomyManager.grant("ling_qi", 1000, "demo_seed")
	EconomyManager.grant("po_dan", 5, "demo_seed")
	for s in GameState.shikigami:
		if String(s.get("id", "")) == sid:
			s["fragments"] = 99
			break
	CultivationManager.upgrade(sid)
	GameState.deck = [sid]
	BattleLauncher.launch(1, 1)
	BattleManager.auto_resolve()

	assert_true(got["gacha"] >= 1, "telemetry_gacha_pulled 实际 emit")
	assert_true(got["cultivate"] >= 1, "telemetry_cultivate_leveled 实际 emit")
	assert_true(got["battle"] >= 1, "telemetry_battle_resolved 实际 emit")
	assert_true(got["reengage"] >= 1, "telemetry_player_reengaged 实际 emit")

	EventBus.telemetry_gacha_pulled.disconnect(cb_gacha)
	EventBus.telemetry_cultivate_leveled.disconnect(cb_cultivate)
	EventBus.telemetry_battle_resolved.disconnect(cb_battle)
	EventBus.telemetry_player_reengaged.disconnect(cb_reengage)


# --- AC1 正交性：战败触发 battle_resolved，但不触发 回流（资源未回流）---
func test_telemetry_defeat_resolves_no_reengage() -> void:
	# 强敌 + 弱玩家必败
	ConfigLoader.inject("battle/chapters", {
		"chapters": [{
			"id": 1, "name": "T",
			"stages": [{
				"id": 1, "boss": false,
				"enemies": [ { "id": "boss", "element": "earth", "stats": { "hp": 999999, "atk": 9999 } } ],
				"reward": { "fu_lu": [1, 3], "po_dan": 0, "jue_xing_shi": 0 }
			}]
		}]
	})
	GameState.reset_all()
	GameState.shikigami = [{
		"id": "hero", "level": 1, "breakthrough": 0, "awakened_skills": [],
		"bond_level": 0, "fragments": 0, "branch": ""
	}]
	GameState.deck = ["hero"]

	var agg := TelemetryAggregator.new()
	agg.attach()
	BattleLauncher.launch(1, 1)
	BattleManager.auto_resolve()
	agg.detach()

	assert_true(BattleManager.is_defeat(), "必败场景")
	var c: Dictionary = agg.get_counts()
	assert_true(int(c["battle_resolved"]) >= 1, "战败也触发 battle_resolved")
	assert_eq(int(c["player_reengaged"]), 0, "战败不触发 回流(资源未回流)")
