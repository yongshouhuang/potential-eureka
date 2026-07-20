# BondManager.gd — 羁绊连携（A1 / E4-S3 / T6）
# 持静态连携表（data/battle/bond_combos.json，经 ConfigLoader）。
# compute_combo(deck_or_team) -> float：2 式神同队 +8~12% / 3+ +15~20%（取最优组中点，确定性）。
# 连携触发经 EventBus.emit bond:combo（横幅数据）广播；BattleManager 只经该事件取加成，
# 不 import BondManager（E4-S3 AC2 硬约束）。
# 硬约束：只与 EventBus / GameState / ConfigLoader（全局 autoload 名）交互，不 preload/import 其它管理器。
extends Node


func _combos() -> Dictionary:
	return ConfigLoader.load_table("battle/bond_combos", "res://data/battle/bond_combos.json")


# 从 deck_or_team 条目中抽取式神 id（兼容 String 或 {"id": ...}）
func _ids(team: Array) -> Array[String]:
	var out: Array[String] = []
	for t in team:
		if t is String:
			out.append(t)
		elif t is Dictionary and t.has("id"):
			out.append(String(t["id"]))
	return out


# 计算全队连携加成（%，如 0.10 = +10%）。同时 emit bond:combo（取最优组）。
# 返回 float 倍率（0.0 表示无连携）。
func compute_combo(deck_or_team: Array) -> float:
	var ids: Array[String] = _ids(deck_or_team)
	var groups: Dictionary = _combos().get("groups", {})
	var best_bonus := 0.0
	var best_group := ""
	for gid in groups.keys():
		var g: Dictionary = groups[gid]
		var members: Array = g.get("members", [])
		var cnt := 0
		for mid in members:
			if ids.has(String(mid)):
				cnt += 1
		if cnt < 2:
			continue
		var bonus: float
		if cnt >= 3:
			bonus = 0.5 * (float(g.get("combo_3plus_min", 0.15)) + float(g.get("combo_3plus_max", 0.20)))
		else:
			bonus = 0.5 * (float(g.get("combo_2_min", 0.08)) + float(g.get("combo_2_max", 0.12)))
		if bonus > best_bonus:
			best_bonus = bonus
			best_group = gid
	if best_bonus > 0.0:
		EventBus.bond_combo.emit(best_group, best_bonus)
	return best_bonus
