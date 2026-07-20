# BattleManager.gd — 构筑+战斗编排（B1/B4 / E4-S2..S5 / S3-B1 / S3-B3）
# 回合流程（行动条 + 玩家选技，一回合跑通）、订阅 EventBus 的 bond:combo 加成（不 import BondManager）、
# 克制命中 emit battle:element_advantage（E4-S4 AC2）、推图章节推进 GameState.progression 并
# emit battle:reward_dropped -> EconomyManager 回流符箓(1–3/关)/丹/石（E4-S5）。
# 读养成最终属性经 CultivationManager（全局 autoload 名），读配置经 ConfigLoader，读技能定义经 skill_defs.json。
# 状态系统经 peer autoload StatusManager（全局名）调用，**零 preload 跨 import**。
#
# 硬约束：只与 EventBus / GameState / ConfigLoader / EconomyManager / CultivationManager / StatusManager
# （全局 autoload 名）交互；严禁 preload/import BondManager（须经 bond:combo 事件取加成）。
extends Node

# 纯计算结算器（class_name，非跨管理器 import）
var _resolver: BattleResolver = BattleResolver.new()
# 种子化 RNG（奖励量/行动条顺序，保证可复现）
var rng: RNGWrapper = RNGWrapper.new(1)

# 战斗状态
var _players: Array = []
var _enemies: Array = []
var _order: Array = []      # _actors 索引，按速度降序
var _actors: Array = []
var _cursor: int = 0
var _chapter: int = 0
var _stage: int = 0
var _stage_def: Dictionary = {}
var _bond_bonus: float = 0.0   # 仅经 bond:combo 事件写入
var _resolved: bool = false
var _outcome: String = ""      # "victory" / "defeat"


func _init() -> void:
	# 订阅羁绊连携加成（B4 只经事件取加成，不 import BondManager）
	EventBus.bond_combo.connect(_on_bond_combo)


func _on_bond_combo(_group_id: String, bonus_pct: float) -> void:
	_bond_bonus = bonus_pct


# ---------- 配置读取 ----------
func _chapters() -> Dictionary:
	return ConfigLoader.load_table("battle/chapters", "res://data/battle/chapters.json")


func _skill_defs() -> Dictionary:
	return ConfigLoader.load_table("battle/skill_defs", "res://data/battle/skill_defs.json")


func _skill_def(skill_id: String) -> Dictionary:
	return _skill_defs().get("skills", {}).get(skill_id, {})


# ---------- 开局 ----------
# 从 GameState.deck 构建玩家单位（经 CultivationManager 读最终属性），从章节数据构建敌人。
func start_battle(chapter: int, stage: int) -> bool:
	_resolved = false
	_outcome = ""
	_bond_bonus = 0.0
	_cursor = 0
	_chapter = chapter
	_stage = stage

	var ch_def: Dictionary = _find_chapter(chapter)
	if ch_def.is_empty():
		return false
	_stage_def = _find_stage(ch_def, stage)
	if _stage_def.is_empty():
		return false

	_build_players()
	_build_enemies()
	if _players.is_empty():
		return false
	_build_order()
	# 向状态系统注册所有单位（元素 + 最大 HP），供 DoT 计算与五行调制
	_register_status_units()
	EventBus.battle_started.emit(chapter, stage)
	return true


func _find_chapter(chapter: int) -> Dictionary:
	for c in _chapters().get("chapters", []):
		if int(c.get("id", 0)) == chapter:
			return c
	return {}


func _find_stage(ch_def: Dictionary, stage: int) -> Dictionary:
	for s in ch_def.get("stages", []):
		if int(s.get("id", 0)) == stage:
			return s
	return {}


func _build_players() -> void:
	_players = []
	var deck: Array = GameState.deck
	for entry in deck:
		var sid: String = String(entry)
		var fu: Dictionary = CultivationManager.get_final_unit(sid)
		if fu.is_empty():
			continue  # 法宝 id 等非式神，跳过
		# 体修分支被动 +HP 入最大/当前 HP（自动生效，不入选技）
		var hp_mult: float = float(fu.get("branch_hp_mult", 0.0))
		var max_hp: int = int(round(float(fu.get("final_stats", {}).get("hp", 0)) * (1.0 + hp_mult)))
		_players.append({
			"id": sid,
			"side": "player",
			"element": fu.get("element", ""),
			"atk": int(fu.get("final_stats", {}).get("atk", 0)),
			"hp": max_hp,
			"max_hp": max_hp,
			"skills": fu.get("skills", []),
			"awakened_skills": fu.get("awakened_skills", []),
			"branch_dmg_mult": fu.get("branch_dmg_mult", 0.0),
			"bond_tags": fu.get("bond_tags", []),
			"qi": 0,
			"qi_max": 3,
		})


func _build_enemies() -> void:
	_enemies = []
	for e in _stage_def.get("enemies", []):
		_enemies.append({
			"id": String(e.get("id", "enemy")),
			"side": "enemy",
			"element": e.get("element", ""),
			"atk": int(e.get("stats", {}).get("atk", 0)),
			"hp": int(e.get("stats", {}).get("hp", 0)),
			"max_hp": int(e.get("stats", {}).get("hp", 0)),
			"skills": [],
			"awakened_skills": [],
			"branch_dmg_mult": 0.0,
			"bond_tags": [],
			"qi": 0,
			"qi_max": 3,
		})


func _build_order() -> void:
	_actors = []
	for p in _players:
		_actors.append(p)
	for e in _enemies:
		_actors.append(e)
	# 速度降序；同速玩家优先
	var idx := range(_actors.size())
	idx.sort_custom(_order_cmp)
	_order = idx


# 行动条排序比较器：速度高者先；同速玩家优先
func _order_cmp(a: int, b: int) -> bool:
	var sa: int = int(_actors[a].get("atk", 0))
	var sb: int = int(_actors[b].get("atk", 0))
	if sa != sb:
		return sa > sb
	return _actors[a].get("side", "") == "player"


# 向 StatusManager 注册所有单位（战斗开局调用一次）
func _register_status_units() -> void:
	StatusManager.unregister_all()
	for a in _actors:
		StatusManager.register_unit(a.get("id", ""), a.get("element", ""), int(a.get("max_hp", 0)))


# ---------- 回合推进 ----------
# 处理下一位行动者的一次行动；返回本回合摘要。已分胜负则返回 {done:true}。
# action: {"skill_id": String, "target_id": String}（玩家输入，可缺省=自动）。
func step(action: Dictionary = {}) -> Dictionary:
	if _resolved:
		return { "done": true, "outcome": _outcome }
	if _order.is_empty():
		return { "done": true }

	# 找到下一个存活行动者（跳过已阵亡单位）
	var actor: Dictionary = {}
	var found := false
	var guard := 0
	while guard < _order.size():
		var cand: Dictionary = _actors[_order[_cursor]]
		_cursor = (_cursor + 1) % _order.size()
		if int(cand.get("hp", 0)) > 0:
			actor = cand
			found = true
			break
		guard += 1
	if not found:
		_resolve_outcome()
		return { "done": true, "outcome": _outcome }

	var actor_id: String = actor.get("id", "")

	# 回合开始：结算该单位身上 DoT（正交红线——DoT 绝不乘 _bond_bonus / armor_break / momentum）
	var dot: int = StatusManager.tick_statuses(actor_id)
	if dot > 0:
		actor["hp"] = int(actor.get("hp", 0)) - dot
		EventBus.battle_turn_resolved.emit(actor_id, actor_id, dot, "STATUS")
		if int(actor.get("hp", 0)) <= 0:
			actor["hp"] = 0
			_resolve_outcome()
			return {
				"done": _resolved, "actor_id": actor_id, "target_id": actor_id,
				"damage": dot, "relation": "STATUS", "outcome": _outcome
			}

	# 解析动作：技能（玩家输入或自动）+ 目标
	var active: Array = _active_skills(actor)
	var skill_id: String = ""
	var gated := false
	if not action.is_empty() and action.has("skill_id") and active.has(action["skill_id"]):
		skill_id = action["skill_id"]
		# qi 门控：觉醒技需耗 1，气不足则禁止放觉醒技（自动降级为基础技）
		if _is_awakened(actor, skill_id) and int(actor.get("qi", 0)) < _awaken_cost():
			skill_id = active[0]
			gated = true
	elif active.size() > 1 and int(actor.get("qi", 0)) >= _awaken_cost():
		skill_id = active[1]       # 自动：气足且有觉醒则放觉醒技
	else:
		skill_id = active[0] if active.size() > 0 else ""

	var target: Dictionary = _resolve_target(actor, action)
	if target == null:
		# 无有效目标 -> 直接结算胜负
		_resolve_outcome()
		return { "done": true, "outcome": _outcome }

	var sd: Dictionary = _skill_def(skill_id)
	if sd.is_empty():
		# 无技能定义（如测试 hero/sk_hero）：回退「单位本行 + power 1.0」（保持旧行为）
		sd = { "element": actor.get("element", ""), "power": 1.0, "status_on_hit": null }

	var target_id: String = target.get("id", "")
	var skill_elem: String = sd.get("element", actor.get("element", ""))
	var power: float = float(sd.get("power", 1.0))

	# 直接打击伤害（不含 DoT）——技能 power/element 从 skill_defs 读取（废除硬编码 1.0）
	var atk_dict := { "element": actor.get("element", ""), "atk": int(actor.get("atk", 0)) }
	var def_dict := { "element": target.get("element", ""), "atk": int(target.get("atk", 0)) }
	var res: Dictionary = _resolver.resolve_damage(atk_dict, def_dict, { "element": skill_elem, "power": power })
	var dmg: int = int(res.get("damage", 0))

	# ===== 直接伤害修正（仅作用于 Dmg_strike，绝不作用于 DoT——R5 正交红线防双 dip）=====
	#  - 分支被动（剑修 +伤）直接增伤
	#  - 状态系统：armor_break 减伤 / momentum 增伤
	#  - 连携加成 _bond_bonus 仅缩放此处的直接打击
	dmg = int(round(float(dmg) * (1.0 + float(actor.get("branch_dmg_mult", 0.0)))
		* StatusManager.target_dmg_mult(target_id) * StatusManager.actor_dmg_mult(actor_id)))
	if actor.get("side", "") == "player" and _bond_bonus > 0.0:
		dmg = int(round(float(dmg) * (1.0 + _bond_bonus)))

	target["hp"] = int(target.get("hp", 0)) - dmg

	# 命中触发状态（觉醒改写机制）：仅当技能带 status_on_hit（经 StatusManager，零跨 import）
	var status_on_hit = sd.get("status_on_hit", null)
	if status_on_hit != null:
		StatusManager.apply_status(target_id, status_on_hit, skill_elem)

	var relation: String = res.get("relation", "NEUTRAL")

	# 克制命中（玩家方）emit battle:element_advantage（E4-S4 AC2）
	if actor.get("side", "") == "player" and relation == "ADVANTAGE":
		EventBus.battle_element_advantage.emit(actor_id, target_id, float(res.get("multiplier", 1.0)))

	EventBus.battle_turn_resolved.emit(actor_id, target_id, dmg, relation)

	var defeated: bool = int(target.get("hp", 0)) <= 0
	if defeated:
		target["hp"] = 0

	# 回合结束：该单位 qi +1（上限 qi_max）。注意：回合开始时不加，
	# 故首回合 qi=0，觉醒技被门控（B-3 qi 门控红线）。
	actor["qi"] = mini(int(actor.get("qi", 0)) + 1, int(actor.get("qi_max", 3)))

	_resolve_outcome()
	return {
		"done": _resolved,
		"actor_id": actor_id,
		"target_id": target_id,
		"skill_id": skill_id,
		"skill_gated": gated,
		"damage": dmg,
		"relation": relation,
		"defeated": defeated,
		"outcome": _outcome,
	}


# 主动技列表：过滤掉分支被动串（被动自动生效，不占选技槽）
func _active_skills(actor: Dictionary) -> Array:
	var out := []
	var defs: Dictionary = _skill_defs().get("skills", {})
	for s in actor.get("skills", []):
		if defs.has(s):
			out.append(s)
	return out


# 是否觉醒技（耗气、带 status_on_hit）
func _is_awakened(actor: Dictionary, skill_id: String) -> bool:
	var aw: Array = actor.get("awakened_skills", [])
	if aw.has(skill_id):
		return true
	var sd: Dictionary = _skill_def(skill_id)
	return sd.has("status_on_hit") and sd["status_on_hit"] != null


func _awaken_cost() -> int:
	return 1


# 目标选择：玩家指定敌方单位（多敌必选，单敌自动）
func _resolve_target(actor: Dictionary, action: Dictionary) -> Dictionary:
	var foes: Array = _enemies if actor.get("side", "") == "player" else _players
	if not action.is_empty() and action.has("target_id"):
		var tid: String = action["target_id"]
		for u in foes:
			if u.get("id", "") == tid and int(u.get("hp", 0)) > 0:
				return u
	return _first_alive(foes)


func _find_actor(unit_id: String) -> Dictionary:
	for a in _actors:
		if a.get("id", "") == unit_id:
			return a
	return {}


# 查询：该单位能否使用指定技能（觉醒技受 qi 门控）
func can_use_skill(unit_id: String, skill_id: String) -> bool:
	var actor: Dictionary = _find_actor(unit_id)
	if actor == {}:
		return false
	if not _is_awakened(actor, skill_id):
		return true  # 基础技无需气
	return int(actor.get("qi", 0)) >= _awaken_cost()


# 查询：该单位当前气
func get_qi(unit_id: String) -> int:
	return int(_find_actor(unit_id).get("qi", 0))


# 自动推进到分胜负（带步数上限，防呆）
func auto_resolve(max_steps: int = 200) -> Dictionary:
	var last: Dictionary = {}
	for i in max_steps:
		last = step()
		if _resolved:
			break
	return last


func _resolve_outcome() -> void:
	if _resolved:
		return
	if _first_alive(_enemies) == null:
		_victory()
	elif _first_alive(_players) == null:
		_defeat()


func _victory() -> void:
	_resolved = true
	_outcome = "victory"
	_advance_progression()
	_grant_rewards()
	EventBus.battle_victory.emit(_chapter, _stage)


func _defeat() -> void:
	_resolved = true
	_outcome = "defeat"
	EventBus.battle_defeat.emit(_chapter, _stage)


# ---------- 进度 + 回流（E4-S5）----------
func _advance_progression() -> void:
	if not GameState.progression.has("stages_cleared"):
		GameState.progression["stages_cleared"] = 0
	if not GameState.progression.has("chapters_cleared"):
		GameState.progression["chapters_cleared"] = 0
	GameState.progression["stages_cleared"] = int(GameState.progression["stages_cleared"]) + 1
	if bool(_stage_def.get("boss", false)):
		GameState.progression["chapters_cleared"] = int(GameState.progression["chapters_cleared"]) + 1


func _grant_rewards() -> void:
	var rwd: Dictionary = _stage_def.get("reward", {})
	var gained := { "fu_lu": 0, "po_dan": 0, "jue_xing_shi": 0 }
	var fu_range: Array = rwd.get("fu_lu", [0, 0])
	var fu_amt: int = rng.randi_range(int(fu_range[0]), int(fu_range[1])) if fu_range.size() >= 2 else 0
	if fu_amt > 0:
		if EconomyManager.grant("fu_lu", fu_amt, "battle"):
			gained["fu_lu"] = fu_amt
	var po_dan: int = int(rwd.get("po_dan", 0))
	if po_dan > 0:
		if EconomyManager.grant("po_dan", po_dan, "battle"):
			gained["po_dan"] = po_dan
	var jue: int = int(rwd.get("jue_xing_shi", 0))
	if jue > 0:
		# 觉醒石仅 Boss 来源（对齐 economy boss_only）；Boss 关以 "Boss" 来源回流
		if EconomyManager.grant("jue_xing_shi", jue, "Boss"):
			gained["jue_xing_shi"] = jue
	EventBus.battle_reward_dropped.emit(gained)


# ---------- 查询 ----------
func is_victory() -> bool:
	return _outcome == "victory"


func is_defeat() -> bool:
	return _outcome == "defeat"


func is_resolved() -> bool:
	return _resolved


func get_bond_bonus() -> float:
	return _bond_bonus


# ---------- 工具 ----------
func _first_alive(list: Array) -> Dictionary:
	for u in list:
		if int(u.get("hp", 0)) > 0:
			return u
	return null
