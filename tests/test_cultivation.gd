# test_cultivation.gd — T7 养成最终式神 + E3 全 5 故事（验证驱动）
# 覆盖：E3-S1 升级等级上限/线性增益；E3-S2 突破阶增益+被动槽；E3-S3 觉醒；
# E3-S4 分支；E3-S5 get_final_unit 聚合正确且与 BattleResolver 读取一致（注入 GrowthCurveDef 假表）。
extends GutTest


func _fake_cultivation() -> Dictionary:
	return {
		"breakthrough": {
			"max_tier": 6,
			"level_cap_per_tier": [20, 36, 52, 64, 72, 80],
			"attr_gain_pct_min": 0.08,
			"attr_gain_pct_max": 0.12,
			"passive_slots_per_tier": [1, 2, 3, 4, 5, 6]
		},
		"level_curve": {
			"hp_per_level_pct_min": 0.02, "hp_per_level_pct_max": 0.03,
			"atk_per_level_pct_min": 0.02, "atk_per_level_pct_max": 0.03
		},
		"upgrade": { "ling_qi_per_level": 50 },
		"breakthrough_cost": { "po_dan_per_tier": 1, "fragments_per_tier": 5 },
		"awaken": {
			"tier_threshold": 3,
			"skills_by_shikigami": { "test_ssr": "skill_test_awakened" }
		},
		"branches": {
			"sword": { "passive": "jian_xiu_passive", "name": "剑修" },
			"body":  { "passive": "ti_xiu_passive",  "name": "体修" }
		}
	}


func _fake_shikigami_defs() -> Dictionary:
	return {
		"shikigami": {
			"test_ssr": {
				"name": "测试式神", "element": "metal", "rarity": "SSR",
				"bond_tags": ["g1", "g2"],
				"base_stats": { "hp": 200, "atk": 80 },
				"skills": ["sk_base"]
			}
		}
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
			"ling_qi": { "daily_cap": 100000 },
			"po_dan": { "weekly_cap": 100 }
		},
		"free_ten_pull": { "amount": 10 },
		"sources": {}
	}


func _set_shikigami(level: int, bt: int, awakened: Array, branch: String, fragments: int) -> void:
	GameState.shikigami = [{
		"id": "test_ssr", "level": level, "breakthrough": bt,
		"awakened_skills": awakened, "bond_level": 0, "fragments": fragments, "branch": branch
	}]


func before_each() -> void:
	ConfigLoader.reset()
	ConfigLoader.inject("cultivation", _fake_cultivation())
	ConfigLoader.inject("shikigami", _fake_shikigami_defs())
	ConfigLoader.inject("battle/element_matrix", _fake_element_matrix())
	ConfigLoader.inject("economy", _fake_econ())
	GameState.reset_all()
	_set_shikigami(1, 0, [], "", 99)


func after_each() -> void:
	ConfigLoader.reset()


# --- E3-S1 升级：线性 +2~3%/级（中点 2.5%）；base atk 80 -> 1 级后 82 ---
func test_upgrade_linear_gain() -> void:
	EconomyManager.grant("ling_qi", 1000, "推图")
	var ok := CultivationManager.upgrade("test_ssr")
	assert_true(ok, "升级成功")
	assert_eq(GameState.shikigami[0]["level"], 2, "等级 -> 2")
	var fu := CultivationManager.get_final_unit("test_ssr")
	# atk: 80 * (1+0.025*1) = 82；hp: 200 * 1.025 = 205
	assert_eq(fu["final_stats"]["atk"], 82, "atk 线性 +2.5% = 82")
	assert_eq(fu["final_stats"]["hp"], 205, "hp 线性 +2.5% = 205")


# --- E3-S1 多级线性（10 级）：80*(1+0.025*10)=100 ---
func test_upgrade_multi_level_linear() -> void:
	_set_shikigami(1, 0, [], "", 99)
	EconomyManager.grant("ling_qi", 100000, "推图")
	for i in 10:
		CultivationManager.upgrade("test_ssr")
	assert_eq(GameState.shikigami[0]["level"], 11, "升到 11 级")
	var fu := CultivationManager.get_final_unit("test_ssr")
	assert_eq(fu["final_stats"]["atk"], 100, "10 级后 atk=100（线性）")
	assert_eq(fu["final_stats"]["hp"], 250, "10 级后 hp=250")


# --- E3-S1 AC2 等级上限随突破阶；超阶拦截 ---
func test_level_cap_scales_and_overcap_blocked() -> void:
	_set_shikigami(1, 0, [], "", 99)
	assert_eq(CultivationManager.max_level("test_ssr"), 20, "bt0 -> Lv20")
	GameState.shikigami[0]["breakthrough"] = 1
	assert_eq(CultivationManager.max_level("test_ssr"), 36, "bt1 -> Lv36")
	# 顶到当前上限（bt1 -> Lv36）后升级应被拦截
	GameState.shikigami[0]["level"] = 36
	EconomyManager.grant("ling_qi", 100000, "推图")
	assert_false(CultivationManager.upgrade("test_ssr"), "已达 Lv36 上限，升级被拦截")
	assert_eq(GameState.shikigami[0]["level"], 36, "等级不变")


# --- E3-S2 突破：每阶全属性 +8~12%（中点 10%）；被动槽随阶增 ---
func test_breakthrough_attr_gain_and_passive_slots() -> void:
	_set_shikigami(1, 0, [], "", 99)
	EconomyManager.grant("ling_qi", 100000, "推图")
	EconomyManager.grant("po_dan", 10, "推图")
	var ok := CultivationManager.breakthrough("test_ssr")
	assert_true(ok, "突破成功")
	assert_eq(GameState.shikigami[0]["breakthrough"], 1, "突破 -> 阶2(bt1)")
	assert_eq(GameState.shikigami[0].get("passive_slots"), 2, "被动槽 = 2（被动_slots_per_tier[1]）")
	var fu := CultivationManager.get_final_unit("test_ssr")
	# atk: 80*(1+0.10*1)=88；hp: 200*1.10=220
	assert_eq(fu["final_stats"]["atk"], 88, "atk 突破 +10% = 88")
	assert_eq(fu["final_stats"]["hp"], 220, "hp 突破 +10% = 220")
	assert_eq(fu["passive_slots"], 2, "get_final_unit 被动槽一致")


# --- E3-S2 同名碎片/突破丹不足拦截 ---
func test_breakthrough_resource_blocked() -> void:
	_set_shikigami(1, 0, [], "", 0)  # 碎片不足
	EconomyManager.grant("po_dan", 10, "推图")
	assert_false(CultivationManager.breakthrough("test_ssr"), "碎片不足拦截")


# --- E3-S3 觉醒：达阶门槛觉醒主动技，标记 awakened_skills[] ---
func test_awaken_skill() -> void:
	_set_shikigami(1, 3, [], "", 99)  # bt3 达门槛
	var ok := CultivationManager.awaken_skill("test_ssr")
	assert_true(ok, "觉醒成功")
	assert_true(GameState.shikigami[0]["awakened_skills"].has("skill_test_awakened"), "标记觉醒技")
	# 未达门槛应失败
	_set_shikigami(1, 1, [], "", 99)
	assert_false(CultivationManager.awaken_skill("test_ssr"), "未达阶门槛觉醒被拒")


# --- E3-S4 分支：高阶突破选剑修/体修，记录于式神数据 ---
func test_choose_branch() -> void:
	_set_shikigami(1, 3, [], "", 99)
	assert_true(CultivationManager.choose_branch("test_ssr", "sword"), "选剑修")
	assert_eq(GameState.shikigami[0]["branch"], "sword", "记录分支")
	# 低阶不可选分支
	_set_shikigami(1, 1, [], "", 99)
	assert_false(CultivationManager.choose_branch("test_ssr", "sword"), "低阶选分支被拒")


# --- E3-S5 / T7 get_final_unit 聚合正确 ---
func test_get_final_unit_aggregation() -> void:
	_set_shikigami(11, 2, ["skill_test_awakened"], "sword", 99)
	var fu := CultivationManager.get_final_unit("test_ssr")
	assert_eq(fu["element"], "metal", "element 聚合")
	assert_eq(fu["bond_tags"], ["g1", "g2"], "bond_tags 聚合")
	assert_eq(fu["breakthrough"], 2, "breakthrough 聚合")
	# atk: 80*1.25(level) *1.20(bt2) = 120；hp: 200*1.25*1.20 = 300
	assert_eq(fu["final_stats"]["atk"], 120, "final atk 聚合=120")
	assert_eq(fu["final_stats"]["hp"], 300, "final hp 聚合=300")
	assert_eq(fu["passive_slots"], 3, "passive_slots=3（bt2）")
	# skills = base + awakened + 分支被动
	assert_true(fu["skills"].has("sk_base"), "含基础技")
	assert_true(fu["skills"].has("skill_test_awakened"), "含觉醒技")
	assert_true(fu["skills"].has("jian_xiu_passive"), "含剑修被动")
	assert_eq(fu["branch"], "sword", "branch 聚合")


# --- T7：get_final_unit 输出供 BattleResolver 读取一致（E4 验收前置）---
func test_final_unit_feeds_battle_resolver() -> void:
	_set_shikigami(11, 2, [], "", 99)
	var fu := CultivationManager.get_final_unit("test_ssr")
	var attacker := { "element": fu["element"], "atk": fu["final_stats"]["atk"] }  # metal, 120
	var defender := { "element": "wood", "atk": 50 }
	var resolver := BattleResolver.new()
	resolver.rng = RNGWrapper.new(12345)
	var res := resolver.resolve_damage(attacker, defender, { "element": "metal", "power": 1.0 })
	assert_eq(res["relation"], "ADVANTAGE", "metal 克 wood -> 克制")
	# 120 * [1.25,1.35] -> [150,162]
	assert_true(res["damage"] >= 150 and res["damage"] <= 162, "克制伤害落入 ×[1.25,1.35] = [150,162]，实际 %d" % res["damage"])
