# test_cloud_conflict_wrapper.gd — E6-S4 云存档冲突解决收口（S1 已落契约，此处补回归 + 推图 wrap + 延迟 mock）
# 覆盖：push -> pull 回合同一档一致性；last-write 取胜（云新/本地新）；cache 副本可回滚；
# delta < 50KB；同步延迟 mock < 2s（离线优先，不阻塞游玩）。
extends GutTest


func _make_save(ts: int, fu: int) -> Dictionary:
	GameState.currencies = { "fu_lu": fu }
	var s: Dictionary = SaveManager.build_save_dict()
	s["meta"]["schema_version"] = 1
	s["meta"]["last_write_ts"] = ts
	return s


func before_each() -> void:
	ConfigLoader.reset()
	GameState.reset_all()


func after_each() -> void:
	ConfigLoader.reset()


# --- push -> pull 回合同一档一致性（无冲突，本地胜）---
func test_push_pull_roundtrip_consistent() -> void:
	var local := _make_save(100, 30)
	assert_true(CloudSaveService.push_save(local), "push 成功")
	assert_true(not CloudSaveService._cache.is_empty(), "push 后 cache 副本存在（可回滚）")
	var result := CloudSaveService.pull_and_resolve(local.duplicate(true))
	assert_eq(result["data"]["currencies"].get("fu_lu", -1), 30, "pull 回合同一档数据一致")


# --- last-write：云更新 -> 取云；cache 保留本地（回滚点）---
func test_last_write_cloud_newer_wins() -> void:
	var local := _make_save(100, 30)
	CloudSaveService.push_save(local)            # _cloud = local(ts100, fu30)
	var cloud := _make_save(200, 50)             # 云更新 ts200
	CloudSaveService.receive_cloud(cloud)
	var res := CloudSaveService.pull_and_resolve(local.duplicate(true))
	assert_eq(res["data"]["currencies"].get("fu_lu", -1), 50, "云更新 -> 取云")
	assert_eq(CloudSaveService._cache["data"]["currencies"].get("fu_lu", -1), 30, "cache 保留本地副本可回滚")


# --- last-write：本地更新 -> 取本地 ---
func test_last_write_local_newer_wins() -> void:
	var local_newer := _make_save(300, 30)
	CloudSaveService.push_save(local_newer)      # _cloud = local(ts300)
	var cloud_old := _make_save(200, 50)         # 云较旧
	CloudSaveService.receive_cloud(cloud_old)
	var res := CloudSaveService.pull_and_resolve(local_newer.duplicate(true))
	assert_eq(res["data"]["currencies"].get("fu_lu", -1), 30, "本地更新 -> 取本地")


# --- 版本优先于 ts（AC1 版本化）---
func test_version_priority_over_ts() -> void:
	var local := { "meta": { "schema_version": 1, "last_write_ts": 999, "checksum": "x" }, "data": {} }
	var cloud := { "meta": { "schema_version": 2, "last_write_ts": 1, "checksum": "y" }, "data": {} }
	assert_eq(CloudSaveService.resolve_conflict(local, cloud), 2, "云版本更高 -> 取云（版本优先于 ts）")


# --- delta < 50KB 预算 ---
func test_delta_within_50kb() -> void:
	var normal := _make_save(100, 1)
	assert_true(CloudSaveService.is_delta_within_limit(normal), "普通存档 < 50KB")


# --- E6-S4 AC3：同步延迟 mock < 2s（离线优先，不阻塞游玩）---
func test_sync_latency_mock_under_2s() -> void:
	assert_true(CloudSaveService.mock_sync_latency() < 2000.0, "同步延迟 mock < 2s（预算 §1.9）")
	assert_true(CloudSaveService.is_online(), "离线优先：桩永远在线不阻塞")
