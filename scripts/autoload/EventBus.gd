# EventBus.gd — 全局信号中枢（解耦核心）
# 架构 §1.8：事件类别冻结（economy/gacha/save/accessibility/bond...）。
# 本单例只声明信号 + 货币名枚举，不含任何游戏逻辑。
# 所有管理器只 emit / listen 这里的信号，且通过全局单例名（而非 preload/import）
# 访问彼此，从而保证无代码级循环依赖（架构 §1.3 / 控制清单）。
extends Node

# ---- 货币名枚举（S1 用到的 5 种货币）----
enum Currency {
	FU_LU,        # 符箓（软通，玩法产）
	LING_YU,      # 灵玉（硬通，MVP 预留）
	LING_QI,      # 灵气（养成资源）
	PO_DAN,       # 突破丹（养成资源，周产）
	JUE_XING_SHI, # 觉醒石（仅 Boss）
}

# 枚举 -> 规范字符串键（与 GameState.currencies / data/economy 对齐）
const CURRENCY_KEYS := {
	Currency.FU_LU: "fu_lu",
	Currency.LING_YU: "ling_yu",
	Currency.LING_QI: "ling_qi",
	Currency.PO_DAN: "po_dan",
	Currency.JUE_XING_SHI: "jue_xing_shi",
}

# 规范字符串键 -> 枚举（反向查表）
const CURRENCY_ENUMS := {
	"fu_lu": Currency.FU_LU,
	"ling_yu": Currency.LING_YU,
	"ling_qi": Currency.LING_QI,
	"po_dan": Currency.PO_DAN,
	"jue_xing_shi": Currency.JUE_XING_SHI,
}

# ---- 信号（类别_事件，参数带类型）----
# economy:*
signal economy_currency_changed(currency: String, amount: int)
signal economy_reward_granted(currency: String, amount: int, sink: String)

# gacha:*
signal gacha_shikigami_obtained(shikigami_id: String, rarity: String)

# cultivate:* （B3 养成；横切反馈给战力/战斗）
signal cultivate_level_up(shikigami_id: String, new_level: int)
signal cultivate_breakthrough(shikigami_id: String, new_tier: int)
signal cultivate_awakened(shikigami_id: String, skill_id: String)
signal cultivate_branch_chosen(shikigami_id: String, branch: String)

# battle:* （B4 构筑+战斗；与 BondManager 经 bond:combo 解耦）
signal battle_started(chapter: int, stage: int)
signal battle_turn_resolved(actor_id: String, target_id: String, damage: int, relation: String)
signal battle_element_advantage(attacker_id: String, target_id: String, multiplier: float)
signal battle_victory(chapter: int, stage: int)
signal battle_defeat(chapter: int, stage: int)
signal battle_reward_dropped(rewards: Dictionary)

# save:*
signal save_written
signal save_loaded

# accessibility:*
signal accessibility_changed(snapshot: Dictionary)

# bond:* （横切；连携加成由战斗启动协调器 BattleLauncher 在 BattleManager.start_battle 之后
#        调用 BondManager.compute_combo(GameState.deck) 发射；BattleManager 仅订阅不发射（E4-S3 AC2）。）
signal bond_combo(group_id: String, bonus_pct: float)


# 便捷：字符串键 -> 枚举
static func currency_to_enum(key: String) -> int:
	if CURRENCY_ENUMS.has(key):
		return CURRENCY_ENUMS[key]
	return -1


# 便捷：枚举 -> 字符串键
static func currency_to_key(currency: int) -> String:
	if CURRENCY_KEYS.has(currency):
		return CURRENCY_KEYS[currency]
	return ""
