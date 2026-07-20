# test_bond_combo_after_start.gd — S3-B2 连携实战发射接线（验证驱动，headless）
# 覆盖：确认出战 -> BattleLauncher.launch(chapter, stage) 在 BattleManager.start_battle 之后
#       调用 BondManager.compute_combo(GameState.deck) 发射 bond:combo，
#       由 BattleManager（仅订阅）经事件写入 _bond_bonus。
# 断言：剑宗 4 人队 _bond_bonus > 0（≈0.175）；单人/无连携组队 _bond_bonus == 0.0。
# 红线（E4-S3 AC2）：全程不破 BattleManager 对 BondManager 的零引用；发射责任在协调器。
extends GutTest


func _fake_bonds() -> Dictionary:
	return {
		"groups": {
			"jian_zong": {
				"name": "剑宗",
				"members": ["ssr_qing_long", "ssr_bai_hu", "sr_you_ming", "sr_xuan_feng"],
				"combo_2_min": 0.08, "combo_2_max": 0.12,
				"combo_3plus_min": 0.15, "combo_3plus_max": 0.20
			}
		}
	}


func _fake_shikigami_defs(members: Array) -> Dictionary:
	var defs := {}
	for m in members:
		defs[m] = { "name": m, "element": "metal", "rarity": "SSR",
			"bond_tags": [], "base_stats": { "hp": 500, "atk": 150 }, "skills": ["sk_hero"] }
	return { "shikigami": defs }


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


func _fake_chapters() -> Dictionary:
	return {
		"chapters": [{
			"id": 1, "name": "第1章",
			"stages": [
				{ "id": 1, "boss": false,
					"enemies": [ { "id": "e1", "element": "wood", "stats": { "hp": 10, "atk": 30 } } ],
					"reward": { "fu_lu": [1, 3], "po_dan": 0, "jue_xing_shi": 0 } }
			]
		}]
	}


func _set_deck(deck_ids: Array) -> void:
	GameState.reset_all()
	GameState.shikigami = []
	for id in deck_ids:
		GameState.shikigami.append({ "id": id, "level": 1, "breakthrough": 0,
			"awakened_skills": [], "bond_level": 0, "fragments": 0, "branch": "" })
	GameState.deck = deck_ids


func before_each() -> void:
	ConfigLoader.reset()
	ConfigLoader.inject("cultivation", _fake_cultivation())
	ConfigLoader.inject("shikigami", _fake_shikigami_defs(
		["ssr_qing_long", "ssr_bai_hu", "sr_you_ming", "sr_xuan_feng", "r_tie_jia", "r_qiu_long"]))
	ConfigLoader.inject("battle/element_matrix", _fake_element_matrix())
	ConfigLoader.inject("battle/skill_defs", { "skills": {} })
	ConfigLoader.inject("battle/status_config", { "status": {} })
	ConfigLoader.inject("battle/bond_combos", _fake_bonds())
	ConfigLoader.inject("battle/chapters", _fake_chapters())


func after_each() -> void:
	ConfigLoader.reset()


# --- B-2：剑宗 4 人队 launch -> BattleManager._bond_bonus > 0（≈0.175）---
func test_launch_fires_bond_for_jian_zong_four() -> void:
	_set_deck(["ssr_qing_long", "ssr_bai_hu", "sr_you_ming", "sr_xuan_feng"])
	assert_true(BattleLauncher.launch(1, 1), "剑宗4人 开局成功")
	# start_battle 清零后，compute_combo 经事件把 _bond_bonus 写入（3+ 中点 0.175）
	assert_true(BattleManager.get_bond_bonus() > 0.0, "剑宗4人 _bond_bonus>0（连携实战生效）")
	assert_eq(BattleManager.get_bond_bonus(), 0.175, "剑宗4人 _bond_bonus=0.175（3+中点）")


# --- B-2：单人 -> BattleManager._bond_bonus == 0.0（无连携）---
func test_launch_zero_bond_for_single() -> void:
	_set_deck(["ssr_qing_long"])
	assert_true(BattleLauncher.launch(1, 1), "单人 开局成功")
	assert_eq(BattleManager.get_bond_bonus(), 0.0, "单人 _bond_bonus==0.0（无连携）")


# --- B-2：无连携组队（两单位分属不同连携组）-> _bond_bonus == 0.0 ---
func test_launch_zero_bond_for_no_combo_team() -> void:
	_set_deck(["r_tie_jia", "r_qiu_long"])
	assert_true(BattleLauncher.launch(1, 1), "无连携组队 开局成功")
	assert_eq(BattleManager.get_bond_bonus(), 0.0, "无连携组队 _bond_bonus==0.0")
