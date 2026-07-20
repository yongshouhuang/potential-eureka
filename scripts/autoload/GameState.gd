# GameState.gd — 玩家档案中央数据（存档载体 / 单一真源）
# 架构 §1.3 / §1.7 (schema v1)。本节点是纯数据持有者，变更一律经管理器进行，
# 不应在节点内写游戏逻辑。
#
# 注：Godot 4 的 autoload 必须是 Node（Resource 无法直接挂到场景树），
# 故此处 extends Node 承载数据，等价于「数据持有者」语义（与架构文档
# "GameState：extends Resource" 的意图一致，引擎约束下改以 Node 承载）。
extends Node

const SCHEMA_VERSION := 1

# ---- 核心数据（对齐 schema v1 §1.7）----
var currencies: Dictionary = {}        # 货币余额：fu_lu/ling_yu/ling_qi/po_dan/jue_xing_shi -> int
var pity: Dictionary = {}              # 抽卡保底：pool_id -> int（连续非 SSR 抽数，不跨池）
var deck: Array = []                   # 卡组：4 式神 id + 1 法宝 id
var shikigami: Array = []              # 式神列表：{id,level,breakthrough,awakened_skills,bond_level,fragments}
var settings: Dictionary = {}          # 设置：high_contrast/text_scale/layout_override/...
var progression: Dictionary = {}       # 进度：chapters_cleared/stars ...

# 免费十连独立额度（pass2 解耦，不计入软预算）
var free_ten_pull: Dictionary = {
	"last_claim_date": "",
	"claimed_today": false,
}

# 存档元信息
var meta: Dictionary = {
	"schema_version": SCHEMA_VERSION,
	"last_write_ts": 0,
	"device_id": "",
	"checksum": "",
}

# ---- S1 扩展字段（为预算上限/新手池进度落地所需；向后兼容序列化）----
# 产出追踪：currency -> { period, amount }，用于日/周预算硬上限判定
var production_tracker: Dictionary = {}
# 抽卡进度：pool_id -> { pulls_done, starter_claimed }，用于新手半价计数与必出 SR
var gacha_progress: Dictionary = {}


# 重置为初始空态（供测试 before_each / 新档使用）
func reset_all() -> void:
	currencies = {}
	pity = {}
	deck = []
	shikigami = []
	settings = {}
	progression = {}
	free_ten_pull = { "last_claim_date": "", "claimed_today": false }
	meta = {
		"schema_version": SCHEMA_VERSION,
		"last_write_ts": 0,
		"device_id": "",
		"checksum": "",
	}
	production_tracker = {}
	gacha_progress = {}
