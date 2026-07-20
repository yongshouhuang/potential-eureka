# test_battle_element.gd — T2 五行克制结算（验证驱动，纯计算可独立测）
# BattleResolver.resolve_damage：克制 ×[1.25,1.35]、被克 ×[0.7,0.8]、相生小幅增益>0。
# 注入假 ElementMatrixDef；种子化 RNG 保证可复现。
extends GutTest


func _fake_matrix() -> Dictionary:
	return {
		"ke": { "metal": "wood", "wood": "earth", "earth": "water", "water": "fire", "fire": "metal" },
		"sheng": { "wood": "fire", "fire": "earth", "earth": "metal", "metal": "water", "water": "wood" },
		"advantage_min": 1.25, "advantage_max": 1.35,
		"disadvantage_min": 0.7, "disadvantage_max": 0.8,
		"sheng_bonus_min": 1.02, "sheng_bonus_max": 1.05
	}


var _resolver: BattleResolver


func before_each() -> void:
	ConfigLoader.reset()
	ConfigLoader.inject("battle/element_matrix", _fake_matrix())
	_resolver = BattleResolver.new()
	_resolver.rng = RNGWrapper.new(20240720)


func after_each() -> void:
	ConfigLoader.reset()


# --- 关系判定 ---
func test_relation_detection() -> void:
	assert_eq(_resolver.relation("metal", "wood"), "ADVANTAGE", "金克木")
	assert_eq(_resolver.relation("wood", "metal"), "DISADVANTAGE", "木被金克")
	assert_eq(_resolver.relation("wood", "fire"), "SHENG", "木生火")
	assert_eq(_resolver.relation("metal", "earth"), "NEUTRAL", "金vs土无关系")


# --- 克制：base 100 -> [125,135] ---
func test_advantage_damage_in_upper_band() -> void:
	var atk := { "element": "metal", "atk": 100 }
	var def := { "element": "wood", "atk": 50 }
	var res := _resolver.resolve_damage(atk, def, { "element": "metal", "power": 1.0 })
	assert_eq(res["relation"], "ADVANTAGE")
	assert_true(res["damage"] >= 125 and res["damage"] <= 135,
		"克制伤害落入 ×[1.25,1.35]=[125,135]，实际 %d" % res["damage"])


# --- 被克：base 100 -> [70,80] ---
func test_disadvantage_damage_in_lower_band() -> void:
	var atk := { "element": "wood", "atk": 100 }
	var def := { "element": "metal", "atk": 50 }
	var res := _resolver.resolve_damage(atk, def, { "element": "wood", "power": 1.0 })
	assert_eq(res["relation"], "DISADVANTAGE")
	assert_true(res["damage"] >= 70 and res["damage"] <= 80,
		"被克伤害落入 ×[0.7,0.8]=[70,80]，实际 %d" % res["damage"])


# --- 相生：base 100 -> [102,105]，且 >0 增益 ---
func test_sheng_gives_positive_bonus() -> void:
	var atk := { "element": "wood", "atk": 100 }
	var def := { "element": "fire", "atk": 50 }
	var res := _resolver.resolve_damage(atk, def, { "element": "wood", "power": 1.0 })
	assert_eq(res["relation"], "SHENG")
	assert_true(res["damage"] > 100, "相生增益>0（实际 %d）" % res["damage"])
	assert_true(res["damage"] >= 102 and res["damage"] <= 105,
		"相生小幅增益落入 ×[1.02,1.05]=[102,105]，实际 %d" % res["damage"])


# --- 中立：倍率 1.0，伤害=base ---
func test_neutral_damage_equals_base() -> void:
	var atk := { "element": "metal", "atk": 100 }
	var def := { "element": "earth", "atk": 50 }
	var res := _resolver.resolve_damage(atk, def, { "element": "metal", "power": 1.0 })
	assert_eq(res["relation"], "NEUTRAL")
	assert_eq(res["damage"], 100, "中立倍率 1.0 -> 伤害=base")


# --- 重复抽样均在 band 内（可复现，多 seed）---
func test_advantage_stays_in_band_across_seeds() -> void:
	for s in [1, 2, 3, 7, 42]:
		var r := BattleResolver.new()
		r.rng = RNGWrapper.new(s)
		var res := r.resolve_damage({ "element": "metal", "atk": 100 }, { "element": "wood", "atk": 50 }, { "element": "metal", "power": 1.0 })
		assert_true(res["damage"] >= 125 and res["damage"] <= 135, "seed %d 仍在 band 内" % s)
