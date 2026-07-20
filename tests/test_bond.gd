# test_bond.gd — T6 羁绊连携（验证驱动，事件解耦）
# 覆盖：同队 2 式神 +8~12% / 3+ +15~20%（静态连携表驱动）；
# BattleManager 经 bond:combo 事件获加成，**不 import BondManager**（跨 import 由 grep 零 preload 保证）。
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


func before_each() -> void:
	ConfigLoader.reset()
	ConfigLoader.inject("battle/bond_combos", _fake_bonds())
	GameState.reset_all()


func after_each() -> void:
	ConfigLoader.reset()


# --- 2 式神同队 -> +8~12% ---
func test_combo_two_shikigami() -> void:
	var bm := BondManager.new()
	var bonus := bm.compute_combo(["ssr_qing_long", "ssr_bai_hu"])
	assert_true(bonus >= 0.08 and bonus <= 0.12, "2 人连携落入 +8~12%，实际 %.3f" % bonus)


# --- 3+ 式神同队 -> +15~20% ---
func test_combo_three_plus_shikigami() -> void:
	var bm := BondManager.new()
	var bonus := bm.compute_combo(["ssr_qing_long", "ssr_bai_hu", "sr_you_ming"])
	assert_true(bonus >= 0.15 and bonus <= 0.20, "3 人连携落入 +15~20%，实际 %.3f" % bonus)


# --- 不足 2 人无连携 ---
func test_combo_single_no_bonus() -> void:
	var bm := BondManager.new()
	assert_eq(bm.compute_combo(["ssr_qing_long"]), 0.0, "单人无连携")
	assert_eq(bm.compute_combo([]), 0.0, "空队无连携")


# --- T6 硬约束：BattleManager 经 bond:combo 事件获加成（不 import BondManager）---
func test_battle_manager_gets_bonus_via_event() -> void:
	var bm := BondManager.new()
	var bat := BattleManager.new()
	bat.rng = RNGWrapper.new(1)
	assert_eq(bat.get_bond_bonus(), 0.0, "初始无加成")
	# BondManager 计算并发出 bond:combo（BattleManager 仅经事件接收）
	var bonus := bm.compute_combo(["ssr_qing_long", "ssr_bai_hu"])
	assert_true(bonus >= 0.08 and bonus <= 0.12, "BondManager 算出 2 人连携")
	# 断言 BattleManager 捕获到的加成与事件一致（证明走事件而非 import）
	assert_eq(bat.get_bond_bonus(), bonus, "BattleManager 经 bond:combo 事件获得相同加成")
	# 3+ 路径同样经事件
	var bonus3 := bm.compute_combo(["ssr_qing_long", "ssr_bai_hu", "sr_you_ming"])
	assert_eq(bat.get_bond_bonus(), bonus3, "3+ 连携也经事件更新")
