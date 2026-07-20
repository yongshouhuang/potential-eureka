# DemoLoop.gd — 核心闭环 headless 编排（E5-S1 / E5-S3）
# =====================================================================
# 无 UI 驱动「抽卡 → 养成 → 编队 → 战斗 → 回流」，证明闭环不依赖场景即可运行。
#
# 红线（与 BattleLauncher 同级协调器，架构 §1.3）：
#  - 仅以全局 autoload 名调用 GachaManager / CultivationManager / EconomyManager /
#    GameState / BattleLauncher / BattleManager / BondManager / EventBus；
#    不 preload / import 任何管理器，不构成 manager 互引。
#  - 不引用任何 UI / 场景节点 —— 因此闭环在任意 layout_mode 下都能 headless 跑通。
#
# 遥测：闭环各节点由对应管理器经 EventBus 真实 emit 4 类遥测事件；调用方在 run()
# 之前 attach 一个 TelemetryAggregator 即可串联漏斗（session 可串联）。
# 本入口不直接依赖 TelemetryAggregator 类（保持零跨引用）；若传入 aggregator 则把
# 其 funnel 一并写入报告，便于一处查看。
#
# 关键节点断言：调用方应校验返回报告的
#   pulled_id != ""（抽到式神）、cultivated_level > before（养成提升）、
#   battle_outcome == "victory"（战斗结算）、rewards/player_reengaged（回流）。
extends RefCounted
class_name DemoLoop


# 跑一次完整闭环。
# pool_id : 抽卡卡池（默认 "standard"，抽到的式神必在 shikigami_defs）。
# chapter / stage : 推图章节 / 关卡（默认 1 / 1）。
# aggregator : 可选 TelemetryAggregator（由调用方 attach / detach，用于串联漏斗）。
# 返回报告 Dict：{ ok, pulled_id, cultivated_before_level, cultivated_level,
#                  breakthrough_before, breakthrough, battle_outcome, rewards, error, telemetry? }。
static func run(pool_id: String = "standard", chapter: int = 1, stage: int = 1, aggregator = null) -> Dictionary:
	var report := {
		"ok": false,
		"pulled_id": "",
		"cultivated_before_level": 0,
		"cultivated_level": 0,
		"breakthrough_before": 0,
		"breakthrough": 0,
		"battle_outcome": "",
		"rewards": {},
		"error": "",
	}

	# --- 1. 抽卡：领免费十连额度（豁免软预算）保证有符箓，再抽 1 次 ---
	EconomyManager.claim_free_ten_pull("2026-07-20")
	var pulled: Array = GachaManager.pull(pool_id, 1)
	if pulled.is_empty():
		report["error"] = "抽卡失败（符箓不足 / 卡池无产出）"
		return report
	var sid: String = String(pulled[0]["shikigami_id"])
	report["pulled_id"] = sid

	# --- 2. 养成：灵气升级 1 级 + 突破 1 阶 ---
	# 资源注入仅 Demo 用（真实游戏由玩法产出）；数值选在真实经济预算内：
	#   ling_qi 真实 daily_cap=2000、po_dan 真实 weekly_cap=5。
	EconomyManager.grant("ling_qi", 1000, "demo_seed")
	EconomyManager.grant("po_dan", 5, "demo_seed")
	# 同名碎片直接置位（demo 协调器可直接改 GameState 真源；真实由战斗/活动产出）
	for s in GameState.shikigami:
		if String(s.get("id", "")) == sid:
			s["fragments"] = 99
			break
	report["cultivated_before_level"] = _level_of(sid)
	CultivationManager.upgrade(sid)
	report["cultivated_level"] = _level_of(sid)
	report["breakthrough_before"] = _bt_of(sid)
	CultivationManager.breakthrough(sid)
	report["breakthrough"] = _bt_of(sid)

	# --- 3. 编队：把抽到的式神放入 deck ---
	GameState.deck = [sid]

	# --- 4. 战斗：BattleLauncher.launch（start_battle → compute_combo）→ auto_resolve ---
	if not BattleLauncher.launch(chapter, stage):
		report["error"] = "战斗开局失败（章节/队伍非法）"
		return report
	BattleManager.auto_resolve()
	report["battle_outcome"] = "victory" if BattleManager.is_victory() else "defeat"

	# --- 5. 回流：胜利后 EconomyManager 经 _grant_rewards 回流符箓/丹/石
	#         （含 telemetry_player_reengaged；本 Demo 默认首关非 Boss，回流符箓）。
	report["rewards"] = {
		"fu_lu": int(GameState.currencies.get("fu_lu", 0)),
		"po_dan": int(GameState.currencies.get("po_dan", 0)),
		"jue_xing_shi": int(GameState.currencies.get("jue_xing_shi", 0)),
	}
	report["ok"] = BattleManager.is_victory()
	# 若调用方传入已 attach 的聚合器，把漏斗一并写入报告（session 串联由调用方控制）
	if aggregator != null and aggregator.has_method("get_funnel"):
		report["telemetry"] = aggregator.get_counts()
		report["funnel"] = aggregator.get_funnel()
	return report


static func _level_of(sid: String) -> int:
	for s in GameState.shikigami:
		if String(s.get("id", "")) == sid:
			return int(s.get("level", 1))
	return 0


static func _bt_of(sid: String) -> int:
	for s in GameState.shikigami:
		if String(s.get("id", "")) == sid:
			return int(s.get("breakthrough", 0))
	return 0
