# GachaManager.gd — 抽卡召唤（B2 / E2 S1–S5）
# 卡池来自 data/gacha（ConfigLoader）。种子化 RNG（RNGWrapper）。
# 保底：软 50（SSR>=50%）/ 硬 90（必出），按 pool_id 独立计数（不跨池）。
# 新手池：前 20 抽半价 + 首次必出指定 SR 起步式神。
# 硬约束：只与 EventBus / GameState / ConfigLoader / 全局单例交互，不 preload/import 其它管理器。
extends Node
class_name GachaManager

# 种子化 RNG（默认种子 1；测试注入固定种子保证可复现）
var rng: RNGWrapper = RNGWrapper.new(1)

const DEFAULT_RATES := {
	"SSR": 0.02, "SR": 0.10, "R": 0.35, "N": 0.53,
}
const DEFAULT_SOFT := 50
const DEFAULT_HARD := 90


# ---------- 配置 ----------
func _pool(pool_id: String) -> Dictionary:
	var cfg: Dictionary = ConfigLoader.load_table("gacha", "res://data/gacha/gacha_pools.json")
	if cfg == null or not cfg.get("pools", {}).has(pool_id):
		push_error("GachaManager: 无卡池 " + pool_id)
		return {}
	return cfg["pools"][pool_id]


# 概率公示数据（E2-S5 双端展示用；渲染是 UI 职责）
func get_probabilities(pool_id: String) -> Dictionary:
	return _pool(pool_id).get("rarity_rates", DEFAULT_RATES.duplicate())


# 当前保底计数（不跨池）
func get_pity(pool_id: String) -> int:
	return int(GameState.pity.get(pool_id, 0))


# ---------- 对外抽卡入口 ----------
# pull：消耗符箓 ->  Roll -> 写 GameState.shikigami -> 广播。
# 返回本次实际产出的结果数组（余额不足则提前结束）。
func pull(pool_id: String, count: int = 1) -> Array:
	var results: Array = []
	for i in count:
		var cost: int = _pull_cost(pool_id)
		if not EconomyManager.spend("fu_lu", cost, "gacha"):
			break  # 符箓不足 -> 停止，不产出
		var r: Dictionary = roll_once(pool_id)
		if r.is_empty():
			break
		GameState.shikigami.append({
			"id": r["shikigami_id"],
			"level": 1,
			"breakthrough": 0,
			"awakened_skills": [],
			"bond_level": 0,
			"fragments": 0,
		})
		EventBus.gacha_shikigami_obtained.emit(r["shikigami_id"], r["rarity"])
		# E5-S3 遥测：抽到式神 -> 漏斗「抽」阶段
		EventBus.telemetry_gacha_pulled.emit(r["shikigami_id"], r["rarity"])
		results.append(r)
	return results


# 纯逻辑 Roll（不消耗、不写档、不广播）—— 供单测保底确定性使用。
# 直接读写 GameState.pity / gacha_progress（数据持有者）。
func roll_once(pool_id: String) -> Dictionary:
	var pool: Dictionary = _pool(pool_id)
	if pool.is_empty():
		return {}
	var pity_count: int = get_pity(pool_id)

	# 新手池：首次必出指定 SR 起步式神
	if pool.get("type") == "newbie":
		var prog: Dictionary = GameState.gacha_progress.get(pool_id, {})
		if not prog.get("starter_claimed", false):
			GameState.gacha_progress[pool_id] = { "pulls_done": 1, "starter_claimed": true }
			GameState.pity[pool_id] = 0
			var sid: String = String(pool.get("starter_sr_id", ""))
			return { "shikigami_id": sid, "rarity": "SR", "pool_id": pool_id, "forced_starter": true }

	var rarity: String = _determine_rarity(pool, pity_count)
	var sid: String = _pick_shikigami(pool, rarity)

	# 更新保底计数（SSR 清零，否则 +1）
	if rarity == "SSR":
		GameState.pity[pool_id] = 0
	else:
		GameState.pity[pool_id] = pity_count + 1

	# 更新抽卡进度
	var prog2: Dictionary = GameState.gacha_progress.get(pool_id, { "pulls_done": 0, "starter_claimed": false })
	prog2["pulls_done"] = int(prog2.get("pulls_done", 0)) + 1
	GameState.gacha_progress[pool_id] = prog2

	return { "shikigami_id": sid, "rarity": rarity, "pool_id": pool_id }


# ---------- 保底 / 概率核心 ----------
func _determine_rarity(pool: Dictionary, pity_count: int) -> String:
	var rates: Dictionary = pool.get("rarity_rates", DEFAULT_RATES)
	var soft: int = int(pool.get("soft_pity", DEFAULT_SOFT))
	var hard: int = int(pool.get("hard_pity", DEFAULT_HARD))
	var next: int = pity_count + 1
	if next >= hard:
		return "SSR"  # 硬保底：第 90 抽必出
	if next >= soft:
		return _roll_with_boosted_ssr(rates, effective_ssr_rate(pity_count, pool))
	return _weighted_roll(rates)


# 软保底 SSR 概率：第 50 抽 = 50%，线性升至第 90 抽 = 100%（下限 50%）
func effective_ssr_rate(pity_count: int, pool: Dictionary) -> float:
	var soft: int = int(pool.get("soft_pity", DEFAULT_SOFT))
	var hard: int = int(pool.get("hard_pity", DEFAULT_HARD))
	var next: int = pity_count + 1
	if next < soft:
		return float(pool.get("rarity_rates", DEFAULT_RATES).get("SSR", 0.02))
	var t: float = float(next - soft) / float(hard - soft)
	return clampf(lerp(0.5, 1.0, t), 0.5, 1.0)


func _weighted_roll(rates: Dictionary) -> String:
	var ssr: float = float(rates.get("SSR", 0.0))
	var sr: float = float(rates.get("SR", 0.0))
	var r: float = float(rates.get("R", 0.0))
	var n: float = float(rates.get("N", 0.0))
	var total: float = ssr + sr + r + n
	if total <= 0:
		return "N"
	var x: float = rng.randf() * total
	if x < ssr:
		return "SSR"
	x -= ssr
	if x < sr:
		return "SR"
	x -= sr
	if x < r:
		return "R"
	return "N"


# 软保底区间：SSR 概率提升至 ssr_rate，其余档按剩余比例缩放（总概率仍为 1）
func _roll_with_boosted_ssr(rates: Dictionary, ssr_rate: float) -> String:
	var ssr: float = ssr_rate
	var remaining: float = 1.0 - ssr_rate
	var base_others: float = float(rates.get("SR", 0.0)) + float(rates.get("R", 0.0)) + float(rates.get("N", 0.0))
	var scale: float = remaining / base_others if base_others > 0 else 0.0
	var r_sr: float = float(rates.get("SR", 0.0)) * scale
	var r_r: float = float(rates.get("R", 0.0)) * scale
	var r_n: float = float(rates.get("N", 0.0)) * scale
	var total: float = ssr + r_sr + r_r + r_n
	if total <= 0:
		return "N"
	var x: float = rng.randf() * total
	if x < ssr:
		return "SSR"
	x -= ssr
	if x < r_sr:
		return "SR"
	x -= r_sr
	if x < r_r:
		return "R"
	return "N"


func _pick_shikigami(pool: Dictionary, rarity: String) -> String:
	var by_rarity: Dictionary = pool.get("shikigami_by_rarity", {})
	var list: Array = by_rarity.get(rarity, [])
	if list.is_empty():
		return ""
	return String(list[rng.rand_index(list.size())])


# ---------- 消耗成本（含新手半价）----------
func _pull_cost(pool_id: String) -> int:
	var pool: Dictionary = _pool(pool_id)
	if pool.get("type") != "newbie":
		return 1
	var prog: Dictionary = GameState.gacha_progress.get(pool_id, { "pulls_done": 0, "starter_claimed": false })
	var done: int = int(prog.get("pulls_done", 0))
	if done < 20:
		# 前 20 抽半价：每 2 抽收 1 符箓 -> 20 抽共 10 符箓
		return 1 if (done % 2 == 1) else 0
	return 1
