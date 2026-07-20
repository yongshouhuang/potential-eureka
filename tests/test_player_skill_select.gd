# test_player_skill_select.gd — B-3 玩家选技（验证驱动，headless）
# 覆盖：step 由给定 skill+target 驱动 / 克制差(≥25%) / 觉醒技命中触发 status_on_hit /
# 分支被动自动入算 / qi 不足觉醒技被门控(降级基础技)。
# 直接驱动 BattleManager / StatusManager autoload；skill_defs / cultivation / element_matrix /
# shikigami 走 ConfigLoader 真实 fallback（仅注入合成式神与受控章节）。
extends GutTest


# 在真实式神表基础上注入合成/覆盖式神定义
func _real_shikigami_with(extras: Dictionary) -> Dictionary:
	var shiki := ConfigLoader.load_table("shikigami", "res://data/shikigami/shikigami_defs.json")
	for k in extras.keys():
		shiki["shikigami"][k] = extras[k]
	return shiki


func _fake_chapters(enemies: Array) -> Dictionary:
	return {
		"chapters": [{
			"id": 1, "name": "T", "stages": [{
				"id": 1, "boss": false, "enemies": enemies,
				"reward": {"fu_lu": [1, 3], "po_dan": 0, "jue_xing_shi": 0}}]}]}


# 通用开局：注入合成式神定义 + 受控章节，构建 BattleManager 并开局
func _setup(extras_defs: Dictionary, shikigami_state: Array, deck: Array, enemies: Array) -> BattleManager:
	ConfigLoader.reset()
	ConfigLoader.inject("shikigami", _real_shikigami_with(extras_defs))
	ConfigLoader.inject("battle/chapters", _fake_chapters(enemies))
	GameState.reset_all()
	GameState.shikigami = shikigami_state
	GameState.deck = deck
	var bat := BattleManager.new()
	bat.rng = RNGWrapper.new(1)
	assert_true(bat.start_battle(1, 1), "开局")
	return bat


func before_each() -> void:
	ConfigLoader.reset()
	StatusManager.unregister_all()


func after_each() -> void:
	ConfigLoader.reset()
	StatusManager.unregister_all()


# --- step 由给定 skill+target 驱动 ---
func test_step_driven_by_skill_and_target() -> void:
	var bat := _setup(
		{"test_driver": {"name": "driver", "element": "metal", "rarity": "N", "bond_tags": [],
						 "base_stats": {"hp": 1000, "atk": 100},
						 "skills": ["skill_qing_long_base", "skill_you_ming_base"]}},
		[{"id": "test_driver", "level": 1, "breakthrough": 0, "awakened_skills": [], "bond_level": 0, "fragments": 0, "branch": ""}],
		["test_driver"],
		[{"id": "e_wood", "element": "wood", "stats": {"hp": 500, "atk": 50}},
		 {"id": "e_metal", "element": "metal", "stats": {"hp": 500, "atk": 50}}])
	var res := bat.step({"skill_id": "skill_qing_long_base", "target_id": "e_metal"})
	assert_eq(res["skill_id"], "skill_qing_long_base", "使用指定 skill")
	assert_eq(res["target_id"], "e_metal", "命中指定 target")
	assert_true(res["damage"] > 0, "造成伤害")
	assert_eq(res["relation"], "NEUTRAL", "metal技打metal目标=中立")


# --- 选克制 element 技能伤害明显高于被克（≥25% 差）---
func test_counter_element_damage_difference() -> void:
	var bat_adv := _setup(
		{"test_driver": {"name": "driver", "element": "metal", "rarity": "N", "bond_tags": [],
						 "base_stats": {"hp": 1000, "atk": 100},
						 "skills": ["skill_qing_long_base", "skill_you_ming_base"]}},
		[{"id": "test_driver", "level": 1, "breakthrough": 0, "awakened_skills": [], "bond_level": 0, "fragments": 0, "branch": ""}],
		["test_driver"],
		[{"id": "e_wood", "element": "wood", "stats": {"hp": 500, "atk": 50}}])
	var res_adv := bat_adv.step({"skill_id": "skill_qing_long_base", "target_id": "e_wood"})  # metal 克 wood
	assert_eq(res_adv["relation"], "ADVANTAGE", "metal技打wood=克制")

	var bat_dis := _setup(
		{"test_driver": {"name": "driver", "element": "metal", "rarity": "N", "bond_tags": [],
						 "base_stats": {"hp": 1000, "atk": 100},
						 "skills": ["skill_qing_long_base", "skill_you_ming_base"]}},
		[{"id": "test_driver", "level": 1, "breakthrough": 0, "awakened_skills": [], "bond_level": 0, "fragments": 0, "branch": ""}],
		["test_driver"],
		[{"id": "e_metal", "element": "metal", "stats": {"hp": 500, "atk": 50}}])
	var res_dis := bat_dis.step({"skill_id": "skill_you_ming_base", "target_id": "e_metal"})  # wood 被 metal 克
	assert_eq(res_dis["relation"], "DISADVANTAGE", "wood技打metal=被克")
	assert_true(res_adv["damage"] > res_dis["damage"], "克制伤害 > 被克伤害")
	assert_true(float(res_adv["damage"]) >= float(res_dis["damage"]) * 1.25, "克制差至少为被克的1.25倍")


# --- 觉醒技命中触发对应 status_on_hit（朱雀 awaken -> burn）---
func test_awaken_skill_triggers_status_on_hit() -> void:
	var bat := _setup({},
		[{"id": "sr_zhu_que", "level": 1, "breakthrough": 3,
		  "awakened_skills": ["skill_zhu_que_awakened"], "bond_level": 0, "fragments": 99, "branch": ""}],
		["sr_zhu_que"],
		[{"id": "e1", "element": "earth", "stats": {"hp": 500, "atk": 50}}])  # 中性，避免水压制干扰
	bat._players[0]["qi"] = 3  # 气足，不门控
	var res := bat.step({"skill_id": "skill_zhu_que_awakened", "target_id": "e1"})
	assert_eq(res["skill_id"], "skill_zhu_que_awakened", "使用觉醒技")
	assert_eq(StatusManager.get_stacks("e1", "burn"), 1, "命中触发 burn 1层")


# --- 分支被动自动入算（剑修 +10% 直接伤害）---
func test_branch_passive_auto_applied() -> void:
	# 注：bt=3 突破已让 atk 由 80 -> 104(+30%)，故 sword=round(104*1.10)=114，plain=104
	var bat_sword := _setup(
		{"test_ssr": {"name": "ssr", "element": "metal", "rarity": "N", "bond_tags": [],
					  "base_stats": {"hp": 1000, "atk": 80}, "skills": ["skill_qing_long_base"]}},
		[{"id": "test_ssr", "level": 1, "breakthrough": 3, "awakened_skills": [], "bond_level": 0, "fragments": 0, "branch": "sword"}],
		["test_ssr"],
		[{"id": "e1", "element": "earth", "stats": {"hp": 500, "atk": 50}}])
	var res_sword := bat_sword.step({"skill_id": "skill_qing_long_base", "target_id": "e1"})
	assert_eq(res_sword["damage"], 114, "剑修 dmg=114(104×1.10)")

	var bat_plain := _setup(
		{"test_ssr": {"name": "ssr", "element": "metal", "rarity": "N", "bond_tags": [],
					  "base_stats": {"hp": 1000, "atk": 80}, "skills": ["skill_qing_long_base"]}},
		[{"id": "test_ssr", "level": 1, "breakthrough": 3, "awakened_skills": [], "bond_level": 0, "fragments": 0, "branch": ""}],
		["test_ssr"],
		[{"id": "e1", "element": "earth", "stats": {"hp": 500, "atk": 50}}])
	var res_plain := bat_plain.step({"skill_id": "skill_qing_long_base", "target_id": "e1"})
	assert_eq(res_plain["damage"], 104, "无分支 dmg=104(bt3 atk)")
	assert_true(res_sword["damage"] > res_plain["damage"], "分支被动自动增伤入算")


# --- qi 不足时觉醒技被门控（自动降级基础技，伤害/状态按基础技）---
func test_qi_gate_downgrades_awaken_to_base() -> void:
	var bat := _setup({},
		[{"id": "sr_zhu_que", "level": 1, "breakthrough": 3,
		  "awakened_skills": ["skill_zhu_que_awakened"], "bond_level": 0, "fragments": 99, "branch": ""}],
		["sr_zhu_que"],
		[{"id": "e1", "element": "earth", "stats": {"hp": 500, "atk": 50}}])
	# 首回合 qi=0 -> 觉醒技门控
	var res := bat.step({"skill_id": "skill_zhu_que_awakened", "target_id": "e1"})
	assert_true(res["skill_gated"], "觉醒技被降级标记")
	assert_eq(res["skill_id"], "skill_zhu_que_base", "降级为基础技")
	assert_eq(StatusManager.get_stacks("e1", "burn"), 0, "基础技不触发 status")
