# test_status_burn.gd — B-1 灼烧状态系统（验证驱动，headless）
# 覆盖：灼烧施加/封顶3 / 水克火压制(max_stacks=1&duration=1) / 木克增益(DoT×1.20) /
# 到期清层 / 正交不双 dip（DoT 不乘连携加成，与直接打击正交）。
# 直接驱动 StatusManager autoload；集成用例经 BattleManager 端到端验证。
extends GutTest


# 在真实式神表基础上注入合成式神（status_config / skill_defs / cultivation / element_matrix
# 走 ConfigLoader 真实 fallback，确保测的是「线上配置」）。
func _real_shikigami_with(extras: Dictionary) -> Dictionary:
	var shiki := ConfigLoader.load_table("shikigami", "res://data/shikigami/shikigami_defs.json")
	for k in extras.keys():
		shiki["shikigami"][k] = extras[k]
	return shiki


func _fake_chapters() -> Dictionary:
	return {
		"chapters": [{
			"id": 1, "name": "T", "stages": [{
				"id": 1, "boss": false,
				"enemies": [{"id": "e1", "element": "wood", "stats": {"hp": 500, "atk": 50}}],
				"reward": {"fu_lu": [1, 3], "po_dan": 0, "jue_xing_shi": 0}}]}]}


func before_each() -> void:
	ConfigLoader.reset()
	StatusManager.unregister_all()


func after_each() -> void:
	ConfigLoader.reset()
	StatusManager.unregister_all()


# --- 施加灼烧后层数=1 ---
func test_apply_burn_stacks_eq_1() -> void:
	StatusManager.register_unit("u", "earth", 1000)
	StatusManager.apply_status("u", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
	assert_eq(StatusManager.get_stacks("u", "burn"), 1, "施加灼烧层数=1")


# --- 连点封顶 3（不溢出）---
func test_burn_caps_at_3() -> void:
	StatusManager.register_unit("u", "earth", 1000)
	for i in 4:
		StatusManager.apply_status("u", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
	assert_eq(StatusManager.get_stacks("u", "burn"), 3, "连点封顶=3(不溢出)")


# --- 水克火压制：max_stacks=1 & duration=1 ---
func test_water_suppresses_burn() -> void:
	StatusManager.register_unit("u", "water", 1000)
	StatusManager.apply_status("u", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
	assert_eq(StatusManager.get_stacks("u", "burn"), 1, "水行 max_stacks=1(压制)")
	var st := StatusManager.get_statuses("u")
	assert_eq(st[0]["turns_left"], 1, "水行 duration=1(压制)")
	StatusManager.apply_status("u", {"type": "burn", "stacks": 1, "duration": 3}, "fire")  # 再压一次
	assert_eq(StatusManager.get_stacks("u", "burn"), 1, "水行多次仍封顶=1")
	assert_eq(StatusManager.get_statuses("u")[0]["turns_left"], 1, "水行每次刷新 duration=1")


# --- 木克增益：DoT ×1.20 ---
func test_wood_amplifies_burn_dot() -> void:
	StatusManager.register_unit("u_wood", "wood", 1000)
	StatusManager.register_unit("u_neu", "earth", 1000)
	StatusManager.apply_status("u_wood", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
	StatusManager.apply_status("u_neu", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
	var dot_wood: int = StatusManager.tick_statuses("u_wood")
	var dot_neu: int = StatusManager.tick_statuses("u_neu")
	# 1 stack: 木行 round(1*0.03*1.20*1000)=36；中性 round(1*0.03*1000)=30
	assert_eq(dot_wood, 36, "木行 DoT=36(×1.20)")
	assert_eq(dot_neu, 30, "中性 DoT=30(对照)")
	assert_true(dot_wood > dot_neu, "木行增益 > 中性")


# --- 3 tick 后到期清层 ---
func test_burn_expires_after_3_ticks() -> void:
	StatusManager.register_unit("u", "earth", 1000)
	StatusManager.apply_status("u", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
	StatusManager.tick_statuses("u")
	StatusManager.tick_statuses("u")
	StatusManager.tick_statuses("u")
	assert_eq(StatusManager.get_stacks("u", "burn"), 0, "3 tick后清层")
	assert_eq(StatusManager.get_statuses("u").size(), 0, "状态表清空")


# --- 正交不双 dip：DoT 计算不引用 _bond_bonus（R5 红线）---
func test_burn_dot_orthogonal_to_bond() -> void:
	# 单元测试：tick_statuses 返回值只与 stacks/系数/max_hp 有关，绝不乘连携加成
	StatusManager.register_unit("u", "earth", 1000)
	StatusManager.apply_status("u", {"type": "burn", "stacks": 2, "duration": 3}, "fire")
	var dot: int = StatusManager.tick_statuses("u")
	# 2 stack 中性: round(2*0.03*1000)=60
	assert_eq(dot, 60, "中性2stack DoT=60(纯公式,无bond)")

	# 端到端：同场既有连携加成(_bond_bonus>0)又有灼烧，玩家回合开始 DoT 扣血不乘 bond
	ConfigLoader.inject("shikigami", _real_shikigami_with({
		"ts": {"name": "ts", "element": "earth", "rarity": "N", "bond_tags": [],
			   "base_stats": {"hp": 1000, "atk": 100}, "skills": ["skill_qing_long_base"]}}))
	ConfigLoader.inject("battle/chapters", _fake_chapters())
	GameState.reset_all()
	GameState.shikigami = [{"id": "ts", "level": 1, "breakthrough": 0, "awakened_skills": [], "bond_level": 0, "fragments": 0, "branch": ""}]
	GameState.deck = ["ts"]
	var bat := BattleManager.new()
	bat.rng = RNGWrapper.new(1)
	assert_true(bat.start_battle(1, 1), "开局")
	StatusManager.apply_status("ts", {"type": "burn", "stacks": 2, "duration": 3}, "fire")
	bat._bond_bonus = 0.175  # 模拟连携加成激活
	var hp_before: int = bat._players[0]["hp"]
	bat.step({"skill_id": "skill_qing_long_base", "target_id": "e1"})
	var hp_after: int = bat._players[0]["hp"]
	var dot_loss: int = hp_before - hp_after  # 玩家本回合只受 DoT 影响（直接打击打在敌人身上）
	assert_eq(dot_loss, 60, "玩家 DoT 扣血=60(未乘bond)")
	assert_ne(dot_loss, int(round(60 * 1.175)), "DoT 未双 dip 乘 bond(不等于71)")
