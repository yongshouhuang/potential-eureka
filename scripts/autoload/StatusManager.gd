# StatusManager.gd — 状态系统（B-1 觉醒改写机制；数据驱动）
# peer autoload：BattleManager 经全局名 StatusManager 调用，**零 preload 跨 import**。
# 持有 statuses[unit_id] = [{type, stacks, turns_left, src_element, mag, elem_dot_mult}]；
# 暴露 apply_status / tick_statuses（返回本 tick 总 DoT）/ target_dmg_mult / actor_dmg_mult / get_stacks。
# 规则（max_stacks/duration/dot 系数/五行调制）全部来自 data/battle/status_config.json（ADR-004 数据驱动）。
# 五行调制：通用 vs_<element> 覆盖——水克火压制(max_stacks/duration 收紧)、火克木增益(dot_mult)。
extends Node

# 单位注册表（战斗开局由 BattleManager 填充）：unit_id -> {element, max_hp}
var _units := {}
# 状态表：unit_id -> Array[{type, stacks, turns_left, src_element, mag, elem_dot_mult}]
var _statuses := {}


func _config() -> Dictionary:
	return ConfigLoader.load_table("battle/status_config", "res://data/battle/status_config.json")


# ---------- 单位注册（战斗开局调用，供 DoT 计算与五行调制）----------
func register_unit(unit_id: String, element: String, max_hp: int) -> void:
	_units[unit_id] = { "element": element, "max_hp": max_hp }
	if not _statuses.has(unit_id):
		_statuses[unit_id] = []


func unregister_all() -> void:
	_statuses.clear()
	_units.clear()


func get_statuses(unit_id: String) -> Array:
	return _statuses.get(unit_id, [])


func get_stacks(unit_id: String, type: String) -> int:
	for s in _statuses.get(unit_id, []):
		if s.get("type", "") == type:
			return int(s.get("stacks", 0))
	return 0


# ---------- 施加状态 ----------
# spec = skill_defs.status_on_hit = {type, stacks, duration}（per-cast）。
# src_element = 施法技能 element（火行状态来源，用于语义；实际目标调制看目标 element）。
func apply_status(target_id: String, spec: Dictionary, src_element: String) -> void:
	var type: String = spec.get("type", "")
	if type == "":
		return
	var cfg: Dictionary = _config().get("status", {}).get(type, {})
	if cfg.is_empty():
		return

	var unit: Dictionary = _units.get(target_id, {})
	var target_elem: String = unit.get("element", "")

	# 目标五行调制（通用 vs_<element> 覆盖）：水克火压制 / 火克木增益
	var max_stacks: int = int(cfg.get("max_stacks", 3))
	var duration: int = int(spec.get("duration", cfg.get("duration", 3)))
	var elem_dot_mult: float = 1.0
	for key in cfg.keys():
		if key.begins_with("vs_"):
			var elem: String = key.substr(3)
			var v: Dictionary = cfg[key]
			if target_elem == elem:
				if v.has("max_stacks"):
					max_stacks = int(v["max_stacks"])
				if v.has("duration"):
					duration = int(v["duration"])
				if v.has("dot_mult"):
					elem_dot_mult = float(v["dot_mult"])

	# 每 tick 系数（运行取区间中点，对齐养成确定性）
	var mag: float = 0.0
	if cfg.has("dot_pct_per_stack_min"):
		mag = 0.5 * (float(cfg["dot_pct_per_stack_min"]) + float(cfg["dot_pct_per_stack_max"]))
	elif cfg.has("pct_per_stack"):
		mag = float(cfg["pct_per_stack"])
	elif cfg.has("dmg_per_stack"):
		mag = float(cfg["dmg_per_stack"])

	# 找既有同类型，叠层（封顶）或新建
	var existing: Dictionary = {}
	var found := false
	for s in _statuses.get(target_id, []):
		if s.get("type", "") == type:
			existing = s
			found = true
			break
	if not found:
		existing = {
			"type": type, "stacks": 0, "turns_left": 0,
			"src_element": src_element, "mag": mag, "elem_dot_mult": elem_dot_mult
		}
		if not _statuses.has(target_id):
			_statuses[target_id] = []
		_statuses[target_id].append(existing)

	var add: int = int(spec.get("stacks", 1))
	# 叠层上限（水行压制下 max_stacks 已收紧为 1）
	existing["stacks"] = mini(int(existing.get("stacks", 0)) + add, max_stacks)
	existing["turns_left"] = duration
	existing["mag"] = mag
	existing["elem_dot_mult"] = elem_dot_mult


# ---------- 结算 DoT（回合开始调用）----------
# 对 unit_id 身上所有状态结算：dot 类累加总伤害；所有状态 turns_left-1，到期清除。
# 返回本 tick 总 DoT（整数）；**不写入 HP**（由 BattleManager 统一写并广播）。
# 关键：本函数完全不读取 _bond_bonus / armor_break / momentum —— DoT 与直接打击正交（R5）。
func tick_statuses(unit_id: String) -> int:
	var total := 0
	var remaining := []
	var max_hp: int = int(_units.get(unit_id, {}).get("max_hp", 0))
	for s in _statuses.get(unit_id, []):
		var cfg: Dictionary = _config().get("status", {}).get(s.get("type", ""), {})
		if cfg.get("kind", "") == "dot":
			var dot_pct: float = float(s.get("mag", 0.0))
			var mult: float = float(s.get("elem_dot_mult", 1.0))
			total += int(round(float(s.get("stacks", 0)) * dot_pct * mult * float(max_hp)))
		s["turns_left"] = int(s.get("turns_left", 0)) - 1
		if int(s.get("turns_left", 0)) > 0:
			remaining.append(s)
	_statuses[unit_id] = remaining
	return total


# ---------- 直接伤害修正（仅作用于 Dmg_strike，不作用于 DoT）----------
# 目标身上 debuff（armor_break）降低其承受的直接伤害
func target_dmg_mult(target_id: String) -> float:
	var mult := 1.0
	for s in _statuses.get(target_id, []):
		var cfg: Dictionary = _config().get("status", {}).get(s.get("type", ""), {})
		if cfg.get("kind", "") == "debuff":
			mult *= (1.0 - float(s.get("stacks", 0)) * float(cfg.get("pct_per_stack", 0.0)))
	return mult


# 持有者身上 selfbuff（momentum）提升其直接伤害
func actor_dmg_mult(actor_id: String) -> float:
	var mult := 1.0
	for s in _statuses.get(actor_id, []):
		var cfg: Dictionary = _config().get("status", {}).get(s.get("type", ""), {})
		if cfg.get("kind", "") == "selfbuff":
			mult *= (1.0 + float(s.get("stacks", 0)) * float(cfg.get("dmg_per_stack", 0.0)))
	return mult
