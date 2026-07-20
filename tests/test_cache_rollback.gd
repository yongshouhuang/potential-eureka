# test_cache_rollback.gd — S3-C4 文件级 cache 回滚补完
# 覆盖（C-4 红线：test_cache_rollback）：
#  1) warm 路径：write_to_file 落盘 正式+cache，人为损坏正式档 -> read_from_file 从内存 cache 回滚
#  2) cold-start 路径：新建 SaveManager 实例（_cache 空）、正式档损坏、磁盘 CACHE_PATH 仍在
#     -> read_from_file 仍从磁盘 cache 回滚成功（本次修复核心断言）
#  3) 失败路径：正式档损坏且磁盘 cache 也缺失 -> read_from_file 返回 false、不崩
# 注：本用例在 CI（Godot+GUT headless）实跑为真门禁；本沙箱无法跑 GUT，逻辑层由
#     production/qa/s3_c4_python_cache_rollback.py 复刻验证。
extends GutTest


const SAVE_SCRIPT := "res://scripts/autoload/SaveManager.gd"


func before_each() -> void:
	ConfigLoader.reset()
	GameState.reset_all()
	_delete_save_files()


func after_each() -> void:
	ConfigLoader.reset()
	_delete_save_files()


# ---------- helpers ----------
func _delete_save_files() -> void:
	var d := DirAccess.open("user://")
	if d == null:
		return
	for fname in [SaveManager.SAVE_PATH.get_file(), SaveManager.CACHE_PATH.get_file()]:
		if d.file_exists(fname):
			d.remove(fname)


# 用无效 JSON 覆盖正式档（模拟文件损坏 / 截断）
func _corrupt_official() -> void:
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ this is not valid json ")
	f.close()


# 用「合法 JSON + 篡改数据但不重算 checksum」覆盖正式档（模拟篡改）
func _tamper_official_data() -> void:
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string('{"meta":{"schema_version":1,"checksum":"stale"},"data":{"currencies":{"fu_lu":999}}}')
	f.close()


func _fresh_saver():
	return load(SAVE_SCRIPT).new()


# ---------- 1) warm 路径：内存 cache 回滚 ----------
func test_warm_rollback_from_memory_cache() -> void:
	GameState.currencies = { "fu_lu": 77 }
	# 落盘正式 + cache（同时刷新 autoload 内存 _cache）
	assert_true(SaveManager.write_to_file(), "write_to_file 成功")
	# 人为损坏正式档（篡改数据，checksum 失效）
	_tamper_official_data()
	# 读档前把 GameState 打乱，证明 rollback 真正恢复
	GameState.currencies = {}
	var ok: bool = SaveManager.read_from_file()
	assert_true(ok, "warm：正式档损坏仍从内存 cache 回滚成功")
	assert_eq(GameState.currencies.get("fu_lu", -1), 77, "warm：currency 恢复到 last-good(77)")


# ---------- 2) cold-start 路径：磁盘 CACHE_PATH 回滚（核心修复断言）----------
func test_cold_start_rollback_from_disk_cache() -> void:
	GameState.currencies = { "fu_lu": 77 }
	# 先用 autoload 实例落盘两份（正式 + 磁盘 cache 都在）
	assert_true(SaveManager.write_to_file(), "write_to_file 落盘成功")
	# 新建 SaveManager 实例：内存 _cache 为空（冷启动），但磁盘 cache 仍在
	var sm = _fresh_saver()
	assert_eq(typeof(sm.get("_cache")), TYPE_DICTIONARY, "fresh 实例 _cache 为字典")
	assert_eq(sm.get("_cache").size(), 0, "fresh 实例 _cache 为空（冷启动）")
	# 损坏正式档
	_tamper_official_data()
	# 读档前打乱 GameState
	GameState.currencies = {}
	var ok: bool = sm.read_from_file()
	assert_true(ok, "cold-start：正式档损坏、内存空，仍从磁盘 cache 回滚成功")
	assert_eq(GameState.currencies.get("fu_lu", -1), 77, "cold-start：currency 从磁盘 cache 恢复(77)")
	# 回滚后内存 _cache 应被刷新（后续读取走快速路径）
	assert_eq(sm.get("_cache").size() > 0, true, "cold-start：回滚后 _cache 被刷新")


# ---------- 3) 失败路径：正式档损坏 + 磁盘 cache 缺失 -> false、不崩 ----------
func test_fail_when_no_cache_anywhere() -> void:
	GameState.currencies = { "fu_lu": 77 }
	assert_true(SaveManager.write_to_file(), "write_to_file 成功")
	# 损坏正式档
	_corrupt_official()
	# 删除磁盘 cache，模拟二者皆损
	_delete_save_files()
	var d := DirAccess.open("user://")
	assert_false(d.file_exists(SaveManager.CACHE_PATH.get_file()), "前置：磁盘 cache 已缺失")
	# 冷启动新实例（内存空 + 磁盘空）
	var sm = _fresh_saver()
	GameState.currencies = {}        # 读档前打乱，证明失败读取不写入任何数据
	var ok: bool = sm.read_from_file()
	assert_false(ok, "失败路径：正式档损坏且 cache 缺失 -> 返回 false")
	assert_eq(GameState.currencies.get("fu_lu", -1), -1, "失败路径：未回滚（GameState 未被篡改填充）")
	# 再读一次确认不崩（幂等 false）
	assert_false(sm.read_from_file(), "失败路径：重复读取仍 false 且不崩")


# ---------- 4) 补充：纯 JSON 损坏（非篡改）也能优雅回退 ----------
func test_corrupt_json_falls_back_then_fails_clean() -> void:
	GameState.currencies = { "fu_lu": 42 }
	assert_true(SaveManager.write_to_file(), "write_to_file 成功")
	_corrupt_official()           # 正式档：无效 JSON -> _read_dict 返回 {}
	# 保留磁盘 cache，验证先尝试内存（空）-> 磁盘 cache 成功
	GameState.currencies = {}
	var sm = _fresh_saver()
	assert_true(sm.read_from_file(), "JSON 损坏：经磁盘 cache 回滚成功")
	assert_eq(GameState.currencies.get("fu_lu", -1), 42, "JSON 损坏：currency 恢复(42)")
