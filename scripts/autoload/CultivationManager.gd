# CultivationManager.gd — 养成系统（B3 / E3 S1–S5）
# 读 data/cultivation（GrowthCurveDef）+ data/shikigami（ShikigamiDef），经 ConfigLoader。
# 硬约束：只与 EventBus / GameState / ConfigLoader / EconomyManager（全局 autoload 名）交互，
# 不 preload/import 其它管理器。所有变更经 EventBus 广播。
#
# 确定性约定：GDD §B3 给出的是数值区间（如 +2~3%/级、+8~12%/阶）。本管理器取区间
# 中点作为确定性代表值（可单测可复现）；区间本身仍由配置表驱动，便于策划热调。
extends Node

const MAX_BREAKTHROUGH := 5   # 突破 0..5 -> 阶 1..6（Lv20..Lv80）
const MIN_BRANCH_TIER := 3    # 高阶突破（分支）门槛


# ---------- 配置读取 ----------
func _cult() -> Dictionary:
	return ConfigLoader.load_table("cultivation", "res://data/cultivation/cultivation_config.json")


func _defs() -> Dictionary:
	return ConfigLoader.load_table("shikigami", "res://data/shikigami/shikigami_defs.json")


# 在 GameState.shikigami 中按 id 查找式神条目（找不到返回 null）
func _entry(id: String) -> Dictionary:
	for s in GameState.shikigami:
		if s.get("id", "") == id:
			return s
	return {}


# ---------- 升级（E3-S1）----------
# 等级上限随突破阶（level_cap_per_tier[breakthrough]）。超阶上限拦截。
func max_level(id: String) -> int:
	var c := _cult()
	var caps: Array = c.get("breakthrough", {}).get("level_cap_per_tier", [20, 36, 52, 64, 72, 80])
	var e := _entry(id)
	var bt: int = int(e.get("breakthrough", 0))
	bt = clampi(bt, 0, MAX_BREAKTHROUGH)
	if bt < caps.size():
		return int(caps[bt])
	return int(caps[caps.size() - 1])


# 耗灵气升级 1 级。超上限/资源不足返回 false。成功 emit cultivate_level_up。
func upgrade(id: String) -> bool:
	var e := _entry(id)
	if e.is_empty():
		return false
	var lvl: int = int(e.get("level", 1))
	var cap: int = max_level(id)
	if lvl >= cap:
		return false  # 超阶上限拦截（E3-S1 AC2）
	var cost: int = int(_cult().get("upgrade", {}).get("ling_qi_per_level", 50)) * lvl
	if not EconomyManager.spend("ling_qi", cost, "cultivate"):
		return false  # 余额不足拦截
	e["level"] = lvl + 1
	EventBus.cultivate_level_up.emit(id, e["level"])
	return true


# ---------- 突破（E3-S2）----------
# 1→6 阶（此处 bt 0..5）。耗 突破丹 + 同名碎片。每阶全属性 +8~12%、解锁被动槽。
func breakthrough(id: String) -> bool:
	var e := _entry(id)
	if e.is_empty():
		return false
	var bt: int = int(e.get("breakthrough", 0))
	if bt >= MAX_BREAKTHROUGH:
		return false  # 已达顶阶
	var bc := _cult().get("breakthrough_cost", {})
	var need_po_dan: int = int(bc.get("po_dan_per_tier", 1))
	var need_frag: int = int(bc.get("fragments_per_tier", 5))
	if int(e.get("fragments", 0)) < need_frag:
		return false  # 同名碎片不足
	if not EconomyManager.spend("po_dan", need_po_dan, "cultivate"):
		return false  # 突破丹不足
	e["fragments"] = int(e.get("fragments", 0)) - need_frag
	e["breakthrough"] = bt + 1
	e["passive_slots"] = _passive_slots_for(e["breakthrough"])
	EventBus.cultivate_breakthrough.emit(id, e["breakthrough"])  # 新阶 = bt+1
	return true


func _passive_slots_for(bt: int) -> int:
	var slots: Array = _cult().get("breakthrough", {}).get("passive_slots_per_tier", [1, 2, 3, 4, 5, 6])
	bt = clampi(bt, 0, MAX_BREAKTHROUGH)
	if bt < slots.size():
		return int(slots[bt])
	return int(slots[slots.size() - 1])


# ---------- 技能觉醒（E3-S3）----------
# 达阶门槛觉醒主动技，标记 awakened_skills[]。
func awaken_skill(id: String) -> bool:
	var e := _entry(id)
	if e.is_empty():
		return false
	var bt: int = int(e.get("breakthrough", 0))
	var threshold: int = int(_cult().get("awaken", {}).get("tier_threshold", MIN_BRANCH_TIER))
	if bt < threshold:
		return false  # 未达觉醒门槛
	var skills: Array = e.get("awakened_skills", [])
	if skills.size() > 0:
		return false  # 已觉醒
	var table: Dictionary = _cult().get("awaken", {}).get("skills_by_shikigami", {})
	var skill_id: String = table.get(id, "skill_%s_awakened" % id)
	skills.append(skill_id)
	e["awakened_skills"] = skills
	EventBus.cultivate_awakened.emit(id, skill_id)
	return true


# ---------- 分支（E3-S4）----------
# 高阶突破选 剑修/体修 方向，记录于式神数据；两方向赋予不同被动（战斗经数据读取，不导入 B4）。
func choose_branch(id: String, branch: String) -> bool:
	var e := _entry(id)
	if e.is_empty():
		return false
	var bt: int = int(e.get("breakthrough", 0))
	if bt < MIN_BRANCH_TIER:
		return false  # 高阶门槛
	var branches: Dictionary = _cult().get("branches", {})
	if not branches.has(branch):
		return false
	e["branch"] = branch
	EventBus.cultivate_branch_chosen.emit(id, branch)
	return true


# ---------- 最终式神产出（E3-S5）----------
# 聚合 final_stats / skills / element / bond_tags / breakthrough，供 B4 读取（E4 验收前置）。
func get_final_unit(id: String) -> Dictionary:
	var defs := _defs().get("shikigami", {})
	if not defs.has(id):
		return {}
	var def: Dictionary = defs[id]
	var e := _entry(id)
	var level: int = int(e.get("level", 1)) if not e.is_empty() else 1
	var bt: int = int(e.get("breakthrough", 0)) if not e.is_empty() else 0
	bt = clampi(bt, 0, MAX_BREAKTHROUGH)

	# 线性升级增益（取区间中点）
	var lc := _cult().get("level_curve", {})
	var hp_rate: float = 0.5 * (float(lc.get("hp_per_level_pct_min", 0.02)) + float(lc.get("hp_per_level_pct_max", 0.03)))
	var atk_rate: float = 0.5 * (float(lc.get("atk_per_level_pct_min", 0.02)) + float(lc.get("atk_per_level_pct_max", 0.03)))
	var base_hp: float = float(def.get("base_stats", {}).get("hp", 0))
	var base_atk: float = float(def.get("base_stats", {}).get("atk", 0))
	var after_level_hp: float = base_hp * (1.0 + hp_rate * float(level - 1))
	var after_level_atk: float = base_atk * (1.0 + atk_rate * float(level - 1))

	# 突破全属性增益（取区间中点）
	var bc := _cult().get("breakthrough", {})
	var bt_rate: float = 0.5 * (float(bc.get("attr_gain_pct_min", 0.08)) + float(bc.get("attr_gain_pct_max", 0.12)))
	var final_hp: int = int(round(after_level_hp * (1.0 + bt_rate * float(bt))))
	var final_atk: int = int(round(after_level_atk * (1.0 + bt_rate * float(bt))))

	# 技能聚合：基础 + 觉醒 + 分支被动
	var skills: Array = []
	for s in def.get("skills", []):
		skills.append(s)
	for s in (e.get("awakened_skills", []) if not e.is_empty() else []):
		skills.append(s)
	var branch: String = e.get("branch", "") if not e.is_empty() else ""
	# 分支被动数值（自动生效，供 B4 结算；不入选技槽）
	var branch_dmg_mult: float = 0.0
	var branch_hp_mult: float = 0.0
	if branch != "":
		var branches: Dictionary = _cult().get("branches", {})
		if branches.has(branch):
			skills.append(branches[branch].get("passive", ""))
			branch_dmg_mult = float(branches[branch].get("dmg_mult", 0.0))
			branch_hp_mult = float(branches[branch].get("hp_mult", 0.0))

	return {
		"id": id,
		"element": def.get("element", ""),
		"bond_tags": def.get("bond_tags", []),
		"final_stats": { "hp": final_hp, "atk": final_atk },
		"skills": skills,
		"breakthrough": bt,
		"passive_slots": _passive_slots_for(bt),
		"branch": branch,
		"branch_dmg_mult": branch_dmg_mult,
		"branch_hp_mult": branch_hp_mult,
		"level": level,
	}
