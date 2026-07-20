# SaveManager.gd — 本地存档读写 + 协调云（E6-S3 / schema v1）
# 序列化 GameState + meta；checksum 对序列化载荷做 hash；
# checksum 不符 -> 拒绝应用并回滚到本地 cache 副本（覆盖前写 cache）。
# 核心逻辑（build/apply）与文件 I/O 解耦，便于 headless 单测（测试策略 §1）。
extends Node

const SAVE_PATH := "user://save_v1.json"
const CACHE_PATH := "user://save_v1.cache.json"

signal save_written
signal save_loaded
signal save_rejected(reason: String)

# 内存 cache（应用层回滚用；也落地到 CACHE_PATH）
var _cache: Dictionary = {}


# 由 GameState 构建存档字典（含 payload + meta + checksum）
func build_save_dict() -> Dictionary:
	var payload := {
		"schema_version": GameState.SCHEMA_VERSION,
		"currencies": GameState.currencies,
		"pity": GameState.pity,
		"deck": GameState.deck,
		"shikigami": GameState.shikigami,
		"settings": GameState.settings,
		"progression": GameState.progression,
		"free_ten_pull": GameState.free_ten_pull,
		"production_tracker": GameState.production_tracker,
		"gacha_progress": GameState.gacha_progress,
	}
	var meta := {
		"schema_version": GameState.SCHEMA_VERSION,
		"last_write_ts": GameState.meta.get("last_write_ts", 0),
		"device_id": GameState.meta.get("device_id", ""),
	}
	var payload_str := JSON.stringify(payload)
	meta["checksum"] = _checksum(payload_str)
	return { "meta": meta, "data": payload }


# 应用存档字典到 GameState。checksum 不符 -> 返回 false，且**不修改** GameState。
func apply_save_dict(save: Dictionary) -> bool:
	if not save.has("meta") or not save.has("data"):
		save_rejected.emit("malformed")
		return false
	var payload_str := JSON.stringify(save["data"])
	if save["meta"].get("checksum", "") != _checksum(payload_str):
		save_rejected.emit("checksum_mismatch")
		return false  # 篡改/损坏 -> 拒绝，保留现有 GameState 供回滚
	var d: Dictionary = save["data"]
	GameState.currencies = d.get("currencies", {})
	GameState.pity = d.get("pity", {})
	GameState.deck = d.get("deck", [])
	GameState.shikigami = d.get("shikigami", [])
	GameState.settings = d.get("settings", {})
	GameState.progression = d.get("progression", {})
	GameState.free_ten_pull = d.get("free_ten_pull", { "last_claim_date": "", "claimed_today": false })
	GameState.production_tracker = d.get("production_tracker", {})
	GameState.gacha_progress = d.get("gacha_progress", {})
	GameState.meta = save["meta"].duplicate(true)
	return true


# 写文件：先写 cache 副本，再写正式档（覆盖前留回滚点）
func write_to_file(path: String = SAVE_PATH) -> bool:
	var save := build_save_dict()
	_write_dict(CACHE_PATH, save)        # 回滚副本
	_write_dict(path, save)
	_cache = save.duplicate(true)
	GameState.meta["last_write_ts"] = Time.get_unix_time_from_system()
	save_written.emit()
	return true


# 读文件：checksum 不符 -> 拒绝并回滚（先内存 cache，再磁盘 CACHE_PATH 副本）。
# 冷启动（内存 _cache 为空）也能从磁盘 cache 回滚，避免正式档损坏直接失败。
func read_from_file(path: String = SAVE_PATH) -> bool:
	var save := _read_dict(path)
	if save == null:
		return false
	if apply_save_dict(save):
		_cache = save.duplicate(true)
		save_loaded.emit()
		return true
	# 正式档损坏 -> 内存快速路径回滚（warm）
	if _cache.size() > 0 and apply_save_dict(_cache):
		save_loaded.emit()
		return true
	# 冷启动 / 内存 cache 为空 -> 重新从磁盘 CACHE_PATH 读取回滚
	var disk_cache := _read_dict(CACHE_PATH)
	if disk_cache.size() > 0 and apply_save_dict(disk_cache):
		_cache = disk_cache.duplicate(true)
		save_loaded.emit()
		return true
	return false


# 序列化后字节长度（用于 delta < 50KB 校验，架构 §1.9 / T3）
func payload_size_bytes(save: Dictionary) -> int:
	return JSON.stringify(save).length()


func _checksum(s: String) -> String:
	# 非加密完整性校验（安全评审为已知缺口，ADR-002）。
	return str(hash(s))


func _write_dict(path: String, save: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: 无法写入 " + path)
		return
	f.store_string(JSON.stringify(save))
	f.close()


func _read_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
