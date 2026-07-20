# test_battle_flow.gd — E4-S4 回合流程 + E4-S5 推图回流（验证驱动，headless）
# 覆盖：一回合流程跑通不崩（AC1）；克制命中 emit battle:element_advantage（AC2）；
# 推图通关 GameState.progression 推进 + 经 EconomyManager 回流符箓/丹/石（断言余额增加）。
extends GutTest


func _fake_shikigami_defs() -> Dictionary:
	return {
		"shikigami": {
			"hero": { "name": "侠客", "element": "metal", "rarity": "SSR",
				"bond_tags": [], "base_stats": { "hp": 500, "atk": 200 }, "skills": ["sk_hero"] }
		}
	}


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


func _fake_element_matrix() -> Dictionary:
	return {
		"ke": { "metal": "wood", "wood": "earth", "earth": "water", "water": "fire", "fire": "metal" },
		"sheng": { "wood": "fire", "fire": "earth", "earth": "metal", "metal": "water", "water": "wood" },
		"advantage_min": 1.25, "advantage_max": 1.35,
		"disadvantage_min": 0.7, "disadvantage_max": 0.8,
		"sheng_bonus_min": 1.02, "sheng_bonus_max": 1.05
	}


func _fake_econ() -> Dictionary:
	return {
		"currencies": {
			"fu_lu": { "daily_cap": 100000 },
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
					"enemies": [ { "id": "e1", "element": "wood", "stats": { "hp": 10, "atk": 30 } } ],
					"reward": { "fu_lu": [1, 3], "po_dan": 0, "jue_xing_shi": 0 } },
				{ "id": 9, "boss": true,
					"enemies": [
						{ "id": "boss", "element": "wood", "stats": { "hp": 10, "atk": 20 } },
						{ "id": "boss_add", "element": "metal", "stats": { "hp": 10, "atk": 20 } }
					],
					"reward": { "fu_lu": [2, 4], "po_dan": 1, "jue_xing_shi": 1 } }
			]
		}]
	}


func _setup_hero() -> void:
	GameState.shikigami = [{
		"id": "hero", "level": 1, "breakthrough": 0, "awakened_skills": [],
		"bond_level": 0, "fragments": 0, "branch": ""
	}]
	# 战斗测试直接置 GameState.deck（BattleManager 读 deck；DeckBuilder 的 4+1 规模拦截见 test_deck_builder）
	GameState.deck = ["hero"]


func before_each() -> void:
	ConfigLoader.reset()
	ConfigLoader.inject("shikigami", _fake_shikigami_defs())
	ConfigLoader.inject("cultivation", _fake_cultivation())
	ConfigLoader.inject("battle/element_matrix", _fake_element_matrix())
	ConfigLoader.inject("economy", _fake_econ())
	ConfigLoader.inject("battle/chapters", _fake_chapters())
	GameState.reset_all()
	EconomyManager.set_date_override("2026-07-20")
	EconomyManager.set_week_override(30)
	_setup_hero()


func after_each() -> void:
	ConfigLoader.reset()
	EconomyManager.set_date_override("")
	EconomyManager.set_week_override(-1)


# --- E4-S4 AC1：一回合流程跑通不崩 ---
func test_one_turn_runs_without_crash() -> void:
	var bat := BattleManager.new()
	bat.rng = RNGWrapper.new(1)
	assert_true(bat.start_battle(1, 1), "开局成功")
	var res := bat.step()
	assert_true(res.has("actor_id"), "返回回合摘要")
	assert_true(bat.is_resolved(), "杂兵 10 血被秒 -> 已分胜负")


# --- E4-S4 AC2：克制命中 emit battle:element_advantage ---
var _elem_adv_seen := []

func _on_elem_adv(a: String, t: String, m: float) -> void:
	_elem_adv_seen.append({ "a": a, "t": t, "m": m })


func test_element_advantage_emitted_on_advantage_hit() -> void:
	_elem_adv_seen.clear()
	var bat := BattleManager.new()
	bat.rng = RNGWrapper.new(1)
	bat.start_battle(1, 1)  # 侠客(metal) vs 木敌(wood) -> 克制
	EventBus.battle_element_advantage.connect(_on_elem_adv)
	bat.step()
	EventBus.battle_element_advantage.disconnect(_on_elem_adv)
	assert_true(_elem_adv_seen.size() >= 1, "克制命中应 emit battle:element_advantage，实际 %d" % _elem_adv_seen.size())
	assert_eq(_elem_adv_seen[0]["a"], "hero", "攻击方为 hero")
	assert_eq(_elem_adv_seen[0]["t"], "e1", "目标为 e1")
	assert_true(_elem_adv_seen[0]["m"] >= 1.25 and _elem_adv_seen[0]["m"] <= 1.35, "倍率落入克制区间")


# --- E4-S5：通关推进 progression + 回流符箓/丹/石 ---
var _gained := {}

func _on_reward_dropped(r: Dictionary) -> void:
	_gained = r


func test_clear_chapter_advances_progression_and_refunds() -> void:
	_gained = {}
	var bat := BattleManager.new()
	bat.rng = RNGWrapper.new(7)
	bat.start_battle(1, 9)  # Boss 关
	var fu_before: int = int(GameState.currencies.get("fu_lu", 0))
	var po_before: int = int(GameState.currencies.get("po_dan", 0))
	var jue_before: int = int(GameState.currencies.get("jue_xing_shi", 0))

	EventBus.battle_reward_dropped.connect(_on_reward_dropped)
	bat.auto_resolve()
	EventBus.battle_reward_dropped.disconnect(_on_reward_dropped)

	assert_true(bat.is_victory(), "Boss 关通关")
	# progression 推进
	assert_eq(int(GameState.progression.get("stages_cleared", 0)), 1, "stages_cleared +1")
	assert_eq(int(GameState.progression.get("chapters_cleared", 0)), 1, "Boss 关 -> chapters_cleared +1")
	# 回流余额增加
	assert_true(int(GameState.currencies.get("fu_lu", 0)) > fu_before, "符箓回流增加")
	assert_true(int(GameState.currencies.get("po_dan", 0)) > po_before, "突破丹回流增加")
	assert_true(int(GameState.currencies.get("jue_xing_shi", 0)) > jue_before, "觉醒石回流增加")
	# reward 事件带实际数量
	assert_true(_gained.get("fu_lu", 0) >= 1, "reward 事件含符箓")
	assert_eq(_gained.get("po_dan", 0), 1, "reward 事件含突破丹 1")
	assert_eq(_gained.get("jue_xing_shi", 0), 1, "reward 事件含觉醒石 1（Boss 来源）")
