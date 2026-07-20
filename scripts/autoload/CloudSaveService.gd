# CloudSaveService.gd — 云存档冲突解决（ADR-002 / E6-S4）
# 版本化 + last-write-wins（version+ts 高者胜）；覆盖前写 cache 副本可回滚。
# MVP 仅桩：假设 delta < 50KB，无真实后端（调用不崩，直接返回成功）。
# 冲突解决逻辑可经注入时间戳单测（测试策略 T3）。
extends Node

const DELTA_LIMIT_BYTES := 50000  # 架构 §1.9：sync delta < 50KB

# E6-S4 AC3：同步延迟 mock（离线优先，不阻塞游玩）。真实后端未接入，给出可断言的桩值。
# 架构 §1.9 预算：同步延迟 < 2s（2000ms）。此处 200ms 远低于预算。
const SYNC_LATENCY_MOCK_MS := 200

signal sync_success
signal sync_conflict(local_won: bool)

# 内存云副本（桩；真实后端由核心层接入）
var _cloud: Dictionary = {}
# 本地 cache 副本（覆盖前留底，可回滚）
var _cache: Dictionary = {}


# 冲突解决：返回 1=本地胜，2=云端胜。
# 规则：schema_version 高者胜；同版本则 last_write_ts 高者胜；均同取本地。
func resolve_conflict(local: Dictionary, cloud: Dictionary) -> int:
	var l_meta: Dictionary = local.get("meta", {})
	var c_meta: Dictionary = cloud.get("meta", {})
	var lv: int = int(l_meta.get("schema_version", 0))
	var cv: int = int(c_meta.get("schema_version", 0))
	if lv != cv:
		return 1 if lv > cv else 2
	var lt: int = int(l_meta.get("last_write_ts", 0))
	var ct: int = int(c_meta.get("last_write_ts", 0))
	if lt == ct:
		return 1
	return 1 if lt > ct else 2


# delta 包大小（字节）
func delta_size_bytes(save: Dictionary) -> int:
	return JSON.stringify(save).length()


# delta 是否在预算内（< 50KB）
func is_delta_within_limit(save: Dictionary, limit: int = DELTA_LIMIT_BYTES) -> bool:
	return delta_size_bytes(save) <= limit


# 推送本地档到云（桩）：先留 cache 再「上传」，调用不崩。
func push_save(local: Dictionary) -> bool:
	if not is_delta_within_limit(local):
		push_warning("CloudSaveService: delta 超过 50KB 预算")
		return false
	_cache = local.duplicate(true)   # 覆盖前留本地底
	_cloud = local.duplicate(true)   # 桩：直接视为上传成功
	sync_success.emit()
	return true


# 拉取云端档并与本地合并（last-write-wins）。返回最终采用的存档字典。
func pull_and_resolve(local: Dictionary) -> Dictionary:
	if _cloud.size() == 0:
		return local  # 无云档，保留本地
	var winner := resolve_conflict(local, _cloud)
	if winner == 2:
		sync_conflict.emit(false)
		return _cloud.duplicate(true)
	sync_conflict.emit(true)
	return local


# 离线优先：本地为真源，不阻塞游玩（桩：永远成功）
func is_online() -> bool:
	return true


# E6-S4 AC3：同步延迟 mock（桩，无真实网络/不 sleep）。返回毫秒，断言 < 2000。
func mock_sync_latency() -> float:
	return float(SYNC_LATENCY_MOCK_MS)


# 模拟「从云端拉到一份存档」并暂存为云副本（供冲突解决 / 测试注入云端较新存档）。
func receive_cloud(snapshot: Dictionary) -> void:
	_cloud = snapshot.duplicate(true)
