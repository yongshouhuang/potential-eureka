# BattleResolver.gd — 五行克制纯计算（B4 / E4-S2 / T2）
# 持有纯计算 resolve_damage(attacker, defender, skill) -> Dictionary。
# 无任何游戏状态写入、不广播、不 import 管理器；五行倍率经 ConfigLoader 注入假表可独立测。
# 可作为 class_name 在测试中直接 new()（T2 验证驱动）。
extends RefCounted
class_name BattleResolver

# 种子化 RNG（band 内选取倍率，保证可复现）
var rng: RNGWrapper = RNGWrapper.new(1)

const NEUTRAL := 1.0


# ---------- 配置读取 ----------
func _matrix() -> Dictionary:
	return ConfigLoader.load_table("battle/element_matrix", "res://data/battle/element_matrix.json")


# ---------- 关系判定 ----------
# 返回 "ADVANTAGE" / "DISADVANTAGE" / "SHENG" / "NEUTRAL"
func relation(skill_element: String, defender_element: String) -> String:
	var m: Dictionary = _matrix()
	var ke: Dictionary = m.get("ke", {})
	var sheng: Dictionary = m.get("sheng", {})
	if ke.get(skill_element, "") == defender_element:
		return "ADVANTAGE"
	if ke.get(defender_element, "") == skill_element:
		return "DISADVANTAGE"
	if sheng.get(skill_element, "") == defender_element:
		return "SHENG"
	return "NEUTRAL"


# ---------- 倍率选取（band 内，种子化 RNG）----------
func _band(rel: String) -> float:
	var m: Dictionary = _matrix()
	match rel:
		"ADVANTAGE":
			return lerpf(float(m.get("advantage_min", 1.25)), float(m.get("advantage_max", 1.35)), rng.randf())
		"DISADVANTAGE":
			return lerpf(float(m.get("disadvantage_min", 0.7)), float(m.get("disadvantage_max", 0.8)), rng.randf())
		"SHENG":
			return lerpf(float(m.get("sheng_bonus_min", 1.02)), float(m.get("sheng_bonus_max", 1.05)), rng.randf())
		_:
			return NEUTRAL


# ---------- 主入口 ----------
# attacker/defender: { "element": String, "atk": int }（atk 用于基础伤害；defender 仅贡献 element）
# skill: { "element": String, "power": float }（power 默认 1.0；skill.element 缺省取 attacker.element）
# 返回 { "damage": int, "multiplier": float, "relation": String, "element": String }
func resolve_damage(attacker: Dictionary, defender: Dictionary, skill: Dictionary) -> Dictionary:
	var atk_elem: String = attacker.get("element", "")
	var def_elem: String = defender.get("element", "")
	var skill_elem: String = skill.get("element", atk_elem)
	var base_atk: float = float(attacker.get("atk", attacker.get("stats", {}).get("atk", 0)))
	var power: float = float(skill.get("power", 1.0))
	var base: float = base_atk * power

	var rel: String = relation(skill_elem, def_elem)
	var mult: float = _band(rel)
	var dmg: int = int(round(base * mult))
	return {
		"damage": dmg,
		"multiplier": mult,
		"relation": rel,
		"element": skill_elem,
	}
