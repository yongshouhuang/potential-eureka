# test_save.gd — T3 存档读写 + 冲突解决（E6-S3 / E6-S4）
# 覆盖：写→读一致；checksum 篡改拒绝并回滚 cache；last-write-wins（注入 ts）；
# delta < 50KB 检查（mock）。
extends GutTest


func before_each() -> void:
	ConfigLoader.reset()
	GameState.reset_all()


func after_each() -> void:
	ConfigLoader.reset()


# --- 写→读一致（内存字典 round-trip，headless 友好）---
func test_write_read_consistent() -> void:
	GameState.currencies = { "fu_lu": 30, "ling_qi": 500 }
	GameState.shikigami = [ { "id": "ssr_a", "level": 1, "breakthrough": 0, "awakened_skills": [], "bond_level": 0, "fragments": 0 } ]
	GameState.pity = { "standard": 7 }
	var save: Dictionary = SaveManager.build_save_dict()
	# 模拟读档前 GameState 被改乱
	GameState.currencies = {}
	GameState.shikigami = []
	GameState.pity = {}
	var ok: bool = SaveManager.apply_save_dict(save)
	assert_true(ok, "合法 checksum 接受")
	assert_eq(GameState.currencies.get("fu_lu", 0), 30, "符箓恢复")
	assert_eq(GameState.currencies.get("ling_qi", 0), 500, "灵气恢复")
	assert_eq(GameState.shikigami.size(), 1, "式神恢复")
	assert_eq(GameState.pity.get("standard", -1), 7, "保底恢复")


# --- checksum 篡改 -> 拒绝且回滚 cache ---
func test_checksum_tamper_rejected_and_rollback() -> void:
	GameState.currencies = { "fu_lu": 50 }
	var valid: Dictionary = SaveManager.build_save_dict()  # 合法存档（cache）
	# 模拟当前 GameState 已进入损坏态
	GameState.currencies = { "fu_lu": 0 }
	# 构造篡改档：改数据但不重算 checksum
	var tampered: Dictionary = valid.duplicate(true)
	tampered["data"]["currencies"] = { "fu_lu": 999 }
	var ok: bool = SaveManager.apply_save_dict(tampered)
	assert_false(ok, "checksum 不符拒绝")
	assert_eq(GameState.currencies.get("fu_lu", -1), 0, "拒绝后 GameState 不变（保留损坏态待回滚）")
	# 回滚到合法 cache
	var rolled_back: bool = SaveManager.apply_save_dict(valid)
	assert_true(rolled_back, "回滚合法档成功")
	assert_eq(GameState.currencies.get("fu_lu", -1), 50, "回滚到 cache 值")


# --- last-write-wins（version+ts 高者胜，注入 ts）---
func test_last_write_wins() -> void:
	var local := { "meta": { "schema_version": 1, "last_write_ts": 100, "checksum": "x" }, "data": {} }
	var cloud_newer := { "meta": { "schema_version": 1, "last_write_ts": 200, "checksum": "y" }, "data": {} }
	var cloud_older := { "meta": { "schema_version": 1, "last_write_ts": 50, "checksum": "z" }, "data": {} }
	assert_eq(CloudSaveService.resolve_conflict(local, cloud_newer), 2, "云更新 -> 取云")
	assert_eq(CloudSaveService.resolve_conflict(local, cloud_older), 1, "本地更新 -> 取本地")
	# 同 ts 平局 -> 取本地
	var cloud_same := { "meta": { "schema_version": 1, "last_write_ts": 100, "checksum": "w" }, "data": {} }
	assert_eq(CloudSaveService.resolve_conflict(local, cloud_same), 1, "同 ts 平局取本地")
	# 版本更高优先
	var cloud_higher_ver := { "meta": { "schema_version": 2, "last_write_ts": 1, "checksum": "v" }, "data": {} }
	assert_eq(CloudSaveService.resolve_conflict(local, cloud_higher_ver), 2, "云版本更高 -> 取云")


# --- delta < 50KB 预算（mock）---
func test_delta_within_50kb() -> void:
	GameState.currencies = { "fu_lu": 1 }
	var normal: Dictionary = SaveManager.build_save_dict()
	assert_true(CloudSaveService.is_delta_within_limit(normal), "普通存档 < 50KB")
	# 构造超大 payload 超预算
	var big: Dictionary = SaveManager.build_save_dict()
	big["data"]["shikigami"] = []
	for i in 5000:
		big["data"]["shikigami"].append({ "id": "ssr_%d" % i, "level": 1, "breakthrough": 0, "awakened_skills": [], "bond_level": 0, "fragments": 0 })
	assert_false(CloudSaveService.is_delta_within_limit(big), "超大存档 > 50KB 被标超预算")
	assert_true(SaveManager.payload_size_bytes(normal) < 50000, "payload 字节 < 50KB")
