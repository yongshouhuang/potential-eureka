# BattleLauncher.gd — 战斗启动协调器（S3-B2 / 闭合 S2 B-2「连携实战恒 0」阻塞项）
# =====================================================================
# 生产级「确认出战 -> 进战斗」入口：在 BattleManager.start_battle 之后，
# 调用 BondManager.compute_combo(GameState.deck) 发射 bond:combo，
# 由 BattleManager（仅订阅）经事件写入 _bond_bonus。
#
# 关键顺序（绝不能反）：start_battle 内部会把 _bond_bonus 清零（见 BattleManager.gd:58），
# 故 compute_combo 必须在其后调用，否则刚算出的加成会被清零覆盖。
#
# 红线（E4-S3 AC2 / 架构 §1.3）：
#  - 本文件是「普通脚本（非 autoload）」，仅以全局 autoload 名调用
#    BattleManager / BondManager / GameState / ConfigLoader，不 preload/import 任何管理器，
#    不构成 manager 互引；BattleManager 本身仍零 import/preload BondManager。
#  - 协调器允许以全局名调用 BondManager（属「场景/协调者」而非 manager），不违反解耦红线。
extends RefCounted
class_name BattleLauncher

# 战斗启动：先 start_battle（清零 _bond_bonus），后 compute_combo(deck) 发射 bond:combo。
# 任一前置失败（章节/队伍非法、start_battle 返回 false）则整体返回 false；成功返回 true。
static func launch(chapter: int, stage: int) -> bool:
	if not BattleManager.start_battle(chapter, stage):
		return false
	BondManager.compute_combo(GameState.deck)
	return true
