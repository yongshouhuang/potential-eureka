# S3-C4 纯逻辑验证脚本（Python 镜像）—— 文件级 cache 回滚补完
# ===============================================================
# 背景：S3-C4 红线 = `test_cache_rollback`：正式档损坏回退磁盘上一可用版本。
# 本沙箱无法运行 Godot/GUT，故用纯文件操作忠实复刻 SaveManager 的
# 「写两份 JSON（正式+cache）→ 损坏正式档 → 读回退到 cache」决策，
# 跑出可复现的本地 PASS 证据。CI（Godot+GUT）才是真门禁（见 tests/test_cache_rollback.gd）。
#
# 忠实移植 scripts/autoload/SaveManager.gd（修复后版本）：
#   - write_to_file：先写 CACHE_PATH 副本，再写正式档，并刷新内存 _cache。
#   - read_from_file：apply 正式档；失败则 (1) 内存 _cache 回滚（warm），
#     (2) 否则重新从磁盘 CACHE_PATH 读取回滚（cold-start，本次修复核心），
#     (3) 二者皆无则优雅 return False 不崩。
#   - checksum 对序列化 payload 做 hash；不符 -> 拒绝应用（保留现有 state 供回滚）。
#
# 说明：Godot 的 hash() 与本脚本所用确定性校验（crc32）算法不同，但本镜像只验证
# 「同一 run 内 checksum 自洽 + 篡改可探测 + 回退顺序正确」的逻辑，算法差异不影响结论。
# 只读：不修改任何项目文件，仅在本临时目录读写。
# ===============================================================

import os
import json
import zlib
import copy
import tempfile

SCHEMA_VERSION = 1


# ---- 确定性 checksum（镜像 _checksum；Godot hash() 的等价替身）----
def _checksum(s: str) -> str:
    return str(zlib.crc32(s.encode("utf-8")) & 0xFFFFFFFF)


def _read_dict(path: str):
    # 镜像 SaveManager._read_dict：文件缺失/解析失败 -> 返回 {}（空字典，非 None）
    try:
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
    except (FileNotFoundError, OSError):
        return {}
    try:
        parsed = json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return {}
    if not isinstance(parsed, dict):
        return {}
    return parsed


def _write_dict(path: str, save: dict) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write(json.dumps(save, ensure_ascii=False))


# ---- 序列化/反序列化（镜像 build_save_dict / apply_save_dict）----
def build_save_dict(state: dict) -> dict:
    payload = {
        "schema_version": SCHEMA_VERSION,
        "currencies": state.get("currencies", {}),
        "pity": state.get("pity", {}),
        "deck": state.get("deck", []),
        "shikigami": state.get("shikigami", []),
        "settings": state.get("settings", {}),
        "progression": state.get("progression", {}),
        "free_ten_pull": state.get("free_ten_pull", {}),
        "production_tracker": state.get("production_tracker", {}),
        "gacha_progress": state.get("gacha_progress", {}),
    }
    payload_str = json.dumps(payload, ensure_ascii=False)
    meta = {"schema_version": SCHEMA_VERSION, "checksum": _checksum(payload_str)}
    return {"meta": meta, "data": payload}


def apply_save_dict(save: dict, state: dict) -> bool:
    # 镜像 apply_save_dict：checksum 不符 -> 返回 False 且不修改 state（保留回滚点）
    if not isinstance(save, dict) or "meta" not in save or "data" not in save:
        return False
    payload_str = json.dumps(save["data"], ensure_ascii=False)
    if save["meta"].get("checksum", "") != _checksum(payload_str):
        return False  # 篡改/损坏 -> 拒绝
    d = save["data"]
    state["currencies"] = d.get("currencies", {})
    state["pity"] = d.get("pity", {})
    state["deck"] = d.get("deck", [])
    state["shikigami"] = d.get("shikigami", [])
    state["settings"] = d.get("settings", {})
    state["progression"] = d.get("progression", {})
    state["free_ten_pull"] = d.get("free_ten_pull", {})
    state["production_tracker"] = d.get("production_tracker", {})
    state["gacha_progress"] = d.get("gacha_progress", {})
    state["meta"] = copy.deepcopy(save["meta"])
    return True


# ---- 文件级读写（镜像 write_to_file / read_from_file，修复后）----
def write_to_file(state: dict, save_path: str, cache_path: str, memory_cache: dict) -> bool:
    save = build_save_dict(state)
    _write_dict(cache_path, save)   # 回滚副本
    _write_dict(save_path, save)
    memory_cache.clear()
    memory_cache.update(copy.deepcopy(save))
    return True


def read_from_file(state: dict, save_path: str, cache_path: str, memory_cache: dict) -> bool:
    save = _read_dict(save_path)
    if save is None:
        return False
    if apply_save_dict(save, state):
        memory_cache.clear()
        memory_cache.update(copy.deepcopy(save))
        return True
    # 正式档损坏 -> 内存快速路径回滚（warm）
    if memory_cache and apply_save_dict(memory_cache, state):
        return True
    # 冷启动 / 内存 cache 为空 -> 重新从磁盘 CACHE_PATH 读取回滚
    disk_cache = _read_dict(cache_path)
    if disk_cache and apply_save_dict(disk_cache, state):
        memory_cache.clear()
        memory_cache.update(copy.deepcopy(disk_cache))
        return True
    return False


# ===================== 断言框架 =====================
_results = []
def check(cond, msg):
    _results.append((bool(cond), msg)); return bool(cond)
def eq(a, b, msg):
    ok = (a == b); _results.append((ok, "%s (got=%r, exp=%r)" % (msg, a, b))); return ok


# ===================== 场景 =====================
def _fresh_state():
    return {"currencies": {}, "pity": {}, "deck": [], "shikigami": [], "settings": {},
            "progression": {}, "free_ten_pull": {}, "production_tracker": {},
            "gacha_progress": {}, "meta": {}}


def _tamper_official(save_path: str) -> None:
    # 合法 JSON + 篡改数据但不重算 checksum（模拟篡改）
    _write_dict(save_path, {
        "meta": {"schema_version": 1, "checksum": "stale"},
        "data": {"currencies": {"fu_lu": 999}},
    })


def _corrupt_official(save_path: str) -> None:
    # 无效 JSON（模拟文件截断/损坏）
    with open(save_path, "w", encoding="utf-8") as f:
        f.write("{ this is not valid json ")


def _delete(path: str) -> None:
    try:
        os.remove(path)
    except (FileNotFoundError, OSError):
        pass


def run_suite(tmp):
    save_path = os.path.join(tmp, "save_v1.json")
    cache_path = os.path.join(tmp, "save_v1.cache.json")

    # ---- 1) warm 路径：内存 cache 回滚 ----
    state = _fresh_state()
    state["currencies"] = {"fu_lu": 77}
    mem = {}
    check(write_to_file(state, save_path, cache_path, mem), "warm: write_to_file 成功")
    _tamper_official(save_path)
    state["currencies"] = {}  # 读档前打乱
    ok = read_from_file(state, save_path, cache_path, mem)
    check(ok, "warm: 正式档损坏仍从内存 cache 回滚成功")
    eq(state["currencies"].get("fu_lu", -1), 77, "warm: currency 恢复到 last-good(77)")

    # ---- 2) cold-start 路径：磁盘 CACHE_PATH 回滚（核心修复断言）----
    _delete(save_path); _delete(cache_path)
    state = _fresh_state()
    state["currencies"] = {"fu_lu": 77}
    mem_a = {}                       # 模拟「先写盘」的 saver 内存（仅用于落盘）
    check(write_to_file(state, save_path, cache_path, mem_a), "cold: write_to_file 落盘成功")
    # 新建冷启动实例：内存 cache 为空，但磁盘 cache 仍在
    mem_cold = {}
    check(isinstance(mem_cold, dict) and len(mem_cold) == 0, "cold: 新实例 _cache 为空（冷启动）")
    _tamper_official(save_path)
    state["currencies"] = {}
    ok = read_from_file(state, save_path, cache_path, mem_cold)
    check(ok, "cold-start: 正式档损坏、内存空，仍从磁盘 cache 回滚成功")
    eq(state["currencies"].get("fu_lu", -1), 77, "cold-start: currency 从磁盘 cache 恢复(77)")
    check(len(mem_cold) > 0, "cold-start: 回滚后 _cache 被刷新（后续走快速路径）")

    # ---- 3) 失败路径：正式档损坏 + 磁盘 cache 缺失 -> false、不崩 ----
    _delete(save_path); _delete(cache_path)
    state = _fresh_state()
    state["currencies"] = {"fu_lu": 77}
    mem_b = {}
    check(write_to_file(state, save_path, cache_path, mem_b), "fail: write_to_file 成功")
    _corrupt_official(save_path)
    _delete(cache_path)             # 磁盘 cache 也缺失
    mem_fail = {}
    state["currencies"] = {}        # 读档前打乱，证明失败读取不写入任何数据
    ok = read_from_file(state, save_path, cache_path, mem_fail)
    check(not ok, "fail: 正式档损坏且 cache 缺失 -> 返回 false")
    eq(state["currencies"].get("fu_lu", -1), -1, "fail: 未回滚（GameState 未被篡改填充）")
    # 重复读取确认不崩（幂等 false）
    ok2 = read_from_file(state, save_path, cache_path, mem_fail)
    check(not ok2, "fail: 重复读取仍 false 且不崩")

    # ---- 4) 补充：纯 JSON 损坏（非篡改）也能经磁盘 cache 优雅回退 ----
    _delete(save_path); _delete(cache_path)
    state = _fresh_state()
    state["currencies"] = {"fu_lu": 42}
    mem_c = {}
    check(write_to_file(state, save_path, cache_path, mem_c), "json: write_to_file 成功")
    _corrupt_official(save_path)    # 正式档：无效 JSON
    # 保留磁盘 cache
    mem_json = {}
    state["currencies"] = {}
    ok = read_from_file(state, save_path, cache_path, mem_json)
    check(ok, "json: JSON 损坏经磁盘 cache 回滚成功")
    eq(state["currencies"].get("fu_lu", -1), 42, "json: currency 恢复(42)")


# ===================== 执行 =====================
if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="s3c4_") as tmp:
        run_suite(tmp)

    print("=" * 64)
    print("S3-C4 纯逻辑验证（Python 镜像）— 文件级 cache 回滚补完")
    print("=" * 64)
    for ok, msg in _results:
        if not ok:
            print("  [FAIL] " + msg)
    print("-" * 64)
    total = len(_results)
    passed = sum(1 for ok, _ in _results if ok)
    print("断言: %d | 通过: %d | 失败: %d" % (total, passed, total - passed))
    print("S3-C4 逻辑层判定: %s" % ("PASS" if (total - passed) == 0 else "FAIL"))
    print("=" * 64)
