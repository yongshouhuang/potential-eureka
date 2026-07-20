# S1 纯逻辑验证脚本（Python 移植）
# ---------------------------------------------------------------
# 目的：S1 的 GDScript 当前无法在沙箱运行（无 godot / GUT 未装）。
# 本脚本把 S1 风险最高的「纯逻辑核心」忠实移植到 Python，
# 镜像 GUT 测试 T1（经济闭环）/ T4（抽卡保底）/ T3（存档校验）
# 的关键断言并实跑，给出算法层红/绿信号。
#
# 重要边界：
#  - 本脚本验证「算法/数值正确性」，不验证 Godot API 接线、信号树、场景加载。
#  - RNG 用 Python 种子化 random（与 Godot RandomNumberGenerator 内部序列不同，
#    但统计分布一致；所有 empirical 断言用 ±容差，故 PRNG 差异不影响结论）。
#  - checksum 用确定性 FNV-1a（与 Godot hash() 数值不同，但「篡改即失配」语义一致）。
#  - 这是 GUT 全量跑之前的轻量门禁，不替代用户本地 Godot+GUT 运行。
# ---------------------------------------------------------------

import json
import copy
import random

# ===================== EventBus（极简信号桩） =====================
class Signal:
    def __init__(self):
        self._handlers = []
    def connect(self, fn):
        if fn not in self._handlers:
            self._handlers.append(fn)
    def disconnect(self, fn):
        if fn in self._handlers:
            self._handlers.remove(fn)
    def emit(self, *args):
        for fn in list(self._handlers):
            fn(*args)

class EventBus:
    economy_currency_changed = Signal()
    economy_reward_granted = Signal()
    gacha_shikigami_obtained = Signal()
    save_written = Signal()
    save_loaded = Signal()
    save_rejected = Signal()
    accessibility_changed = Signal()
    bond_combo = Signal()

# ===================== RNGWrapper（种子化） =====================
class RNGWrapper:
    def __init__(self, p_seed=0):
        self._rng = random.Random()
        if p_seed != 0:
            self._rng.seed(p_seed)
    def reseed(self, p_seed):
        self._rng.seed(p_seed)
    def randf(self):
        return self._rng.random()
    def rand_index(self, length):
        if length <= 0:
            return 0
        return self._rng.randrange(length)  # [0, length-1]

# ===================== GameState（数据持有者） =====================
class GameState:
    SCHEMA_VERSION = 1
    def __init__(self):
        self.reset_all()
    def reset_all(self):
        self.currencies = {}
        self.pity = {}
        self.deck = []
        self.shikigami = []
        self.settings = {}
        self.progression = {}
        self.free_ten_pull = {"last_claim_date": "", "claimed_today": False}
        self.meta = {"schema_version": self.SCHEMA_VERSION, "last_write_ts": 0, "device_id": "", "checksum": ""}
        self.production_tracker = {}
        self.gacha_progress = {}

gs = GameState()

# ===================== ConfigLoader（内存覆盖） =====================
_config_overrides = {}
def cl_reset():
    _config_overrides.clear()
def cl_inject(id, data):
    _config_overrides[id] = data
def cl_load_table(id, fallback_path=""):
    if id in _config_overrides:
        return _config_overrides[id]
    return None  # 沙箱无真实文件，测试一律走 inject

# ===================== 工具函数 =====================
def lerp(a, b, t):
    return a + (b - a) * t
def clampf(v, lo, hi):
    return max(lo, min(hi, v))
def json_str(obj):
    return json.dumps(obj, ensure_ascii=False)
def _fnv1a(s):
    h = 0x811c9dc5
    for b in s.encode("utf-8"):
        h ^= b
        h = (h * 0x01000193) & 0xffffffff
    return str(h)

# ===================== EconomyManager（移植） =====================
DEFAULT_FREE_TEN = 10
class EconomyManager:
    def __init__(self):
        self.telemetry_log = []
        self._date_override = ""
        self._week_override = -1
    def _econ(self):
        return cl_load_table("economy", "")
    def _currency_cfg(self, currency):
        c = self._econ().get("currencies", {})
        if currency in c:
            return c[currency]
        return {}
    def grant(self, currency, amount, source, exempt_from_budget=False):
        if amount <= 0:
            return False
        cfg = self._currency_cfg(currency)
        if cfg.get("boss_only", False) and source != "Boss":
            return False
        if not exempt_from_budget:
            if not self._within_budget(currency, amount, cfg):
                return False
        gs.currencies[currency] = int(gs.currencies.get(currency, 0)) + amount
        self._record_production(currency, amount, cfg, exempt_from_budget)
        EventBus.economy_currency_changed.emit(currency, amount)
        self._log_telemetry("grant", currency, amount, source)
        return True
    def spend(self, currency, amount, sink):
        bal = int(gs.currencies.get(currency, 0))
        if bal < amount:
            return False
        gs.currencies[currency] = bal - amount
        EventBus.economy_currency_changed.emit(currency, -amount)
        EventBus.economy_reward_granted.emit(currency, amount, sink)
        self._log_telemetry("spend", currency, -amount, sink)
        return True
    def claim_free_ten_pull(self, today_date=""):
        today = today_date if today_date != "" else self._current_date()
        if gs.free_ten_pull.get("last_claim_date", "") != today:
            gs.free_ten_pull["claimed_today"] = False
        if gs.free_ten_pull.get("claimed_today", False):
            return 0
        amt = int(self._econ().get("free_ten_pull", {}).get("amount", DEFAULT_FREE_TEN))
        gs.free_ten_pull["last_claim_date"] = today
        gs.free_ten_pull["claimed_today"] = True
        self.grant("fu_lu", amt, "free_ten_pull", True)
        return amt
    def _period_key(self, currency, cfg):
        if "weekly_cap" in cfg:
            return "W%d" % self._current_week()
        return "D%s" % self._current_date()
    def _production_used(self, currency):
        t = gs.production_tracker.get(currency, {})
        return int(t.get("amount", 0))
    def _record_production(self, currency, amount, cfg, exempt):
        if exempt:
            return
        key = self._period_key(currency, cfg)
        t = gs.production_tracker.get(currency, {"period": key, "amount": 0})
        if t.get("period", "") != key:
            t = {"period": key, "amount": 0}
        t["amount"] = int(t.get("amount", 0)) + amount
        gs.production_tracker[currency] = t
    def _within_budget(self, currency, amount, cfg):
        cap = -1
        if "daily_soft_cap" in cfg:
            cap = int(cfg["daily_soft_cap"])
        elif "daily_cap" in cfg:
            cap = int(cfg["daily_cap"])
        elif "weekly_cap" in cfg:
            cap = int(cfg["weekly_cap"])
        if cap < 0:
            return True
        key = self._period_key(currency, cfg)
        t = gs.production_tracker.get(currency, {})
        if t.get("period", "") != key:
            return amount <= cap
        return int(t.get("amount", 0)) + amount <= cap
    def reset_daily_if_needed(self, today_date=""):
        today = today_date if today_date != "" else self._current_date()
        for cur in list(gs.production_tracker.keys()):
            t = gs.production_tracker[cur]
            if not str(t.get("period", "")).startswith("W") and t.get("period", "") != ("D" + today):
                gs.production_tracker[cur] = {"period": "D" + today, "amount": 0}
        if gs.free_ten_pull.get("last_claim_date", "") != today:
            gs.free_ten_pull["claimed_today"] = False
    def reset_weekly_if_needed(self, week=-1):
        wk = week if week >= 0 else self._current_week()
        for cur in list(gs.production_tracker.keys()):
            t = gs.production_tracker[cur]
            if str(t.get("period", "")).startswith("W") and t.get("period", "") != ("W%d" % wk):
                gs.production_tracker[cur] = {"period": "W%d" % wk, "amount": 0}
    def get_recommended_source(self, deficit_currency):
        src = self._econ().get("sources", {})
        out = []
        if deficit_currency in src:
            for s in src[deficit_currency]:
                out.append(s)
        return out
    def set_date_override(self, date_str):
        self._date_override = date_str
    def set_week_override(self, week):
        self._week_override = week
    def _current_date(self):
        if self._date_override != "":
            return self._date_override
        return "2026-07-20"
    def _current_week(self):
        if self._week_override >= 0:
            return self._week_override
        return 30
    def _log_telemetry(self, kind, currency, amount, ctx):
        self.telemetry_log.append({"kind": kind, "currency": currency, "amount": amount, "ctx": ctx})

# ===================== GachaManager（移植） =====================
DEFAULT_RATES = {"SSR": 0.02, "SR": 0.10, "R": 0.35, "N": 0.53}
DEFAULT_SOFT = 50
DEFAULT_HARD = 90
class GachaManager:
    def __init__(self):
        self.rng = RNGWrapper(1)
    def _pool(self, pool_id):
        cfg = cl_load_table("gacha", "")
        if cfg is None or pool_id not in cfg.get("pools", {}):
            return {}
        return cfg["pools"][pool_id]
    def get_probabilities(self, pool_id):
        return self._pool(pool_id).get("rarity_rates", dict(DEFAULT_RATES))
    def get_pity(self, pool_id):
        return int(gs.pity.get(pool_id, 0))
    def pull(self, pool_id, count=1):
        results = []
        for i in range(count):
            cost = self._pull_cost(pool_id)
            if not Economy.spend("fu_lu", cost, "gacha"):
                break
            r = self.roll_once(pool_id)
            if not r:
                break
            gs.shikigami.append({"id": r["shikigami_id"], "level": 1, "breakthrough": 0,
                                 "awakened_skills": [], "bond_level": 0, "fragments": 0})
            EventBus.gacha_shikigami_obtained.emit(r["shikigami_id"], r["rarity"])
            results.append(r)
        return results
    def roll_once(self, pool_id):
        pool = self._pool(pool_id)
        if not pool:
            return {}
        pity_count = self.get_pity(pool_id)
        if pool.get("type") == "newbie":
            prog = gs.gacha_progress.get(pool_id, {})
            if not prog.get("starter_claimed", False):
                gs.gacha_progress[pool_id] = {"pulls_done": 1, "starter_claimed": True}
                gs.pity[pool_id] = 0
                sid = str(pool.get("starter_sr_id", ""))
                return {"shikigami_id": sid, "rarity": "SR", "pool_id": pool_id, "forced_starter": True}
        rarity = self._determine_rarity(pool, pity_count)
        sid = self._pick_shikigami(pool, rarity)
        if rarity == "SSR":
            gs.pity[pool_id] = 0
        else:
            gs.pity[pool_id] = pity_count + 1
        prog2 = gs.gacha_progress.get(pool_id, {"pulls_done": 0, "starter_claimed": False})
        prog2["pulls_done"] = int(prog2.get("pulls_done", 0)) + 1
        gs.gacha_progress[pool_id] = prog2
        return {"shikigami_id": sid, "rarity": rarity, "pool_id": pool_id}
    def _determine_rarity(self, pool, pity_count):
        rates = pool.get("rarity_rates", DEFAULT_RATES)
        soft = int(pool.get("soft_pity", DEFAULT_SOFT))
        hard = int(pool.get("hard_pity", DEFAULT_HARD))
        nxt = pity_count + 1
        if nxt >= hard:
            return "SSR"
        if nxt >= soft:
            return self._roll_with_boosted_ssr(rates, self.effective_ssr_rate(pity_count, pool))
        return self._weighted_roll(rates)
    def effective_ssr_rate(self, pity_count, pool):
        soft = int(pool.get("soft_pity", DEFAULT_SOFT))
        hard = int(pool.get("hard_pity", DEFAULT_HARD))
        nxt = pity_count + 1
        if nxt < soft:
            return float(pool.get("rarity_rates", DEFAULT_RATES).get("SSR", 0.02))
        t = float(nxt - soft) / float(hard - soft)
        return clampf(lerp(0.5, 1.0, t), 0.5, 1.0)
    def _weighted_roll(self, rates):
        ssr = float(rates.get("SSR", 0.0)); sr = float(rates.get("SR", 0.0))
        r = float(rates.get("R", 0.0)); n = float(rates.get("N", 0.0))
        total = ssr + sr + r + n
        if total <= 0:
            return "N"
        x = self.rng.randf() * total
        if x < ssr: return "SSR"
        x -= ssr
        if x < sr: return "SR"
        x -= sr
        if x < r: return "R"
        return "N"
    def _roll_with_boosted_ssr(self, rates, ssr_rate):
        ssr = ssr_rate
        remaining = 1.0 - ssr_rate
        base_others = float(rates.get("SR", 0.0)) + float(rates.get("R", 0.0)) + float(rates.get("N", 0.0))
        scale = remaining / base_others if base_others > 0 else 0.0
        r_sr = float(rates.get("SR", 0.0)) * scale
        r_r = float(rates.get("R", 0.0)) * scale
        r_n = float(rates.get("N", 0.0)) * scale
        total = ssr + r_sr + r_r + r_n
        if total <= 0:
            return "N"
        x = self.rng.randf() * total
        if x < ssr: return "SSR"
        x -= ssr
        if x < r_sr: return "SR"
        x -= r_sr
        if x < r_r: return "R"
        return "N"
    def _pick_shikigami(self, pool, rarity):
        by_rarity = pool.get("shikigami_by_rarity", {})
        lst = by_rarity.get(rarity, [])
        if not lst:
            return ""
        return str(lst[self.rng.rand_index(len(lst))])
    def _pull_cost(self, pool_id):
        pool = self._pool(pool_id)
        if pool.get("type") != "newbie":
            return 1
        prog = gs.gacha_progress.get(pool_id, {"pulls_done": 0, "starter_claimed": False})
        done = int(prog.get("pulls_done", 0))
        if done < 20:
            return 1 if (done % 2 == 1) else 0
        return 1

# ===================== SaveManager（移植） =====================
class SaveManager:
    def build_save_dict(self):
        payload = {
            "schema_version": gs.SCHEMA_VERSION,
            "currencies": gs.currencies,
            "pity": gs.pity,
            "deck": gs.deck,
            "shikigami": gs.shikigami,
            "settings": gs.settings,
            "progression": gs.progression,
            "free_ten_pull": gs.free_ten_pull,
            "production_tracker": gs.production_tracker,
            "gacha_progress": gs.gacha_progress,
        }
        meta = {
            "schema_version": gs.SCHEMA_VERSION,
            "last_write_ts": gs.meta.get("last_write_ts", 0),
            "device_id": gs.meta.get("device_id", ""),
        }
        payload_str = json_str(payload)
        meta["checksum"] = _fnv1a(payload_str)
        return {"meta": meta, "data": payload}
    def apply_save_dict(self, save):
        if "meta" not in save or "data" not in save:
            EventBus.save_rejected.emit("malformed")
            return False
        payload_str = json_str(save["data"])
        if save["meta"].get("checksum", "") != _fnv1a(payload_str):
            EventBus.save_rejected.emit("checksum_mismatch")
            return False
        d = save["data"]
        gs.currencies = d.get("currencies", {})
        gs.pity = d.get("pity", {})
        gs.deck = d.get("deck", [])
        gs.shikigami = d.get("shikigami", [])
        gs.settings = d.get("settings", {})
        gs.progression = d.get("progression", {})
        gs.free_ten_pull = d.get("free_ten_pull", {"last_claim_date": "", "claimed_today": False})
        gs.production_tracker = d.get("production_tracker", {})
        gs.gacha_progress = d.get("gacha_progress", {})
        gs.meta = copy.deepcopy(save["meta"])
        return True
    def payload_size_bytes(self, save):
        return len(json_str(save))

# ===================== CloudSaveService（移植） =====================
class CloudSaveService:
    DELTA_LIMIT_BYTES = 50000
    def resolve_conflict(self, local, cloud):
        l_meta = local.get("meta", {})
        c_meta = cloud.get("meta", {})
        lv = int(l_meta.get("schema_version", 0))
        cv = int(c_meta.get("schema_version", 0))
        if lv != cv:
            return 1 if lv > cv else 2
        lt = int(l_meta.get("last_write_ts", 0))
        ct = int(c_meta.get("last_write_ts", 0))
        if lt == ct:
            return 1
        return 1 if lt > ct else 2
    def delta_size_bytes(self, save):
        return len(json_str(save))
    def is_delta_within_limit(self, save, limit=DELTA_LIMIT_BYTES):
        return self.delta_size_bytes(save) <= limit

# ===================== 实例化 =====================
Economy = EconomyManager()
Gacha = GachaManager()
Save = SaveManager()
Cloud = CloudSaveService()

# ===================== 极简断言框架 =====================
_results = []
def check(cond, msg):
    _results.append((bool(cond), msg))
    return bool(cond)
def eq(a, b, msg):
    ok = (a == b)
    _results.append((ok, "%s (got=%r, exp=%r)" % (msg, a, b)))
    return ok
def ge(a, b, msg):
    ok = (a >= b)
    _results.append((ok, "%s (got=%r, exp>=%r)" % (msg, a, b)))
    return ok
def approx(a, b, tol, msg):
    ok = (abs(a - b) <= tol)
    _results.append((ok, "%s (got=%r, exp~%r, tol=%r)" % (msg, a, b, tol)))
    return ok

# ===================== 假数据构造 =====================
def fake_pools(ssr_base=0.0):
    return {"pools": {
        "standard": {"id":"standard","type":"standard",
            "rarity_rates":{"SSR":ssr_base,"SR":0.10,"R":0.35,"N":0.55},
            "soft_pity":50,"hard_pity":90,
            "shikigami_by_rarity":{"SSR":["ssr_a"],"SR":["sr_a"],"R":["r_a"],"N":["n_a"]}},
        "newbie": {"id":"newbie","type":"newbie",
            "rarity_rates":{"SSR":ssr_base,"SR":0.10,"R":0.35,"N":0.55},
            "soft_pity":50,"hard_pity":90,"half_price_pulls":20,"starter_sr_id":"sr_starter",
            "shikigami_by_rarity":{"SSR":["ssr_a"],"SR":["sr_starter","sr_b"],"R":["r_a"],"N":["n_a"]}},
    }}
def fake_pools_hard_only():
    return {"pools": {"hard_only":{"id":"hard_only","type":"standard",
        "rarity_rates":{"SSR":0.0,"SR":0.10,"R":0.35,"N":0.55},
        "soft_pity":9999,"hard_pity":90,
        "shikigami_by_rarity":{"SSR":["ssr_a"],"SR":["sr_a"],"R":["r_a"],"N":["n_a"]}}}}
def fake_pools_no_pity():
    return {"pools": {
        "pool_a":{"id":"pool_a","type":"standard","rarity_rates":{"SSR":0.0,"SR":0.10,"R":0.35,"N":0.55},
            "soft_pity":9999,"hard_pity":9999,"shikigami_by_rarity":{"SSR":["x"],"SR":["x"],"R":["x"],"N":["x"]}},
        "pool_b":{"id":"pool_b","type":"standard","rarity_rates":{"SSR":0.0,"SR":0.10,"R":0.35,"N":0.55},
            "soft_pity":9999,"hard_pity":9999,"shikigami_by_rarity":{"SSR":["x"],"SR":["x"],"R":["x"],"N":["x"]}},
    }}
def fake_econ_high_budget():
    return {"currencies":{"fu_lu":{"daily_soft_cap":100000}},
            "free_ten_pull":{"amount":10}, "sources":{"fu_lu":["推图"]}}
def fake_econ():
    return {"currencies":{
            "fu_lu":{"daily_soft_cap":12,"min_daily":10,"can_accumulate":True},
            "ling_yu":{}, "ling_qi":{"daily_cap":2000},
            "po_dan":{"weekly_cap":5}, "jue_xing_shi":{"boss_only":True}},
        "free_ten_pull":{"amount":10},
        "sources":{"fu_lu":["推图","日常","章节首通"],"ling_qi":["推图","日常"],
            "po_dan":["推图","日常"],"jue_xing_shi":["Boss"],"ling_yu":["商城"]}}

# ===================== T1 经济闭环 =====================
def T1_suite():
    cl_reset(); cl_inject("economy", fake_econ()); gs.reset_all()
    Economy.telemetry_log.clear(); Economy.set_date_override("2026-07-20"); Economy.set_week_override(30)
    seen = []
    def on_cc(currency, amount): seen.append({"c":currency,"a":amount})
    # 基础产出/消耗
    check(Economy.grant("fu_lu",5,"日常"), "T1 grant 成功")
    eq(gs.currencies.get("fu_lu",0), 5, "T1 余额 5")
    check(Economy.spend("fu_lu",3,"gacha"), "T1 spend 成功")
    eq(gs.currencies.get("fu_lu",0), 2, "T1 余额 2")
    check(not Economy.spend("fu_lu",99,"gacha"), "T1 余额不足被拒")
    eq(gs.currencies.get("fu_lu",0), 2, "T1 扣减被拦截")
    # 日软预算封顶
    gs.reset_all(); Economy.set_date_override("2026-07-20"); Economy.set_week_override(30)
    check(Economy.grant("fu_lu",12,"日常"), "T1 达日软上限12")
    eq(gs.currencies.get("fu_lu",0), 12, "T1 余额12")
    check(not Economy.grant("fu_lu",1,"日常"), "T1 超日软被拒")
    eq(gs.currencies.get("fu_lu",0), 12, "T1 封顶不变")
    # 免费十连解耦
    gs.reset_all(); Economy.set_date_override("2026-07-20"); Economy.set_week_override(30)
    Economy.grant("fu_lu",12,"日常")
    got = Economy.claim_free_ten_pull("2026-07-20")
    eq(got, 10, "T1 领取10免费符箓")
    eq(gs.currencies.get("fu_lu",0), 22, "T1 余额22(12软+10免)")
    check(not Economy.grant("fu_lu",1,"日常"), "T1 软预算满普通产出仍拒")
    eq(gs.currencies.get("fu_lu",0), 22, "T1 仅免费额增加")
    # po_dan 周产
    gs.reset_all(); Economy.set_date_override("2026-07-20"); Economy.set_week_override(30)
    check(Economy.grant("po_dan",5,"日常"), "T1 达周上限5")
    eq(gs.currencies.get("po_dan",0), 5, "T1 po_dan5")
    check(not Economy.grant("po_dan",1,"日常"), "T1 超周被拒")
    eq(gs.currencies.get("po_dan",0), 5, "T1 po_dan封顶")
    # jue_xing_shi boss_only
    gs.reset_all()
    check(Economy.grant("jue_xing_shi",1,"Boss"), "T1 Boss来源可产")
    eq(gs.currencies.get("jue_xing_shi",0), 1, "T1 觉醒石1")
    check(not Economy.grant("jue_xing_shi",1,"推图"), "T1 非Boss被拒")
    eq(gs.currencies.get("jue_xing_shi",0), 1, "T1 仅Boss计入")
    # 余额不足 spend
    gs.reset_all()
    check(not Economy.spend("fu_lu",999,"gacha"), "T1 无余额被拒")
    eq(gs.currencies.get("fu_lu",0), 0, "T1 不扣减")
    # 广播
    gs.reset_all(); seen.clear()
    EventBus.economy_currency_changed.connect(on_cc)
    Economy.grant("fu_lu",7,"日常")
    EventBus.economy_currency_changed.disconnect(on_cc)
    eq(len(seen), 1, "T1 恰好广播一次")
    eq(seen[0]["c"], "fu_lu", "T1 广播货币")
    eq(seen[0]["a"], 7, "T1 广播量")
    # 日界重置
    gs.reset_all(); Economy.set_date_override("2026-07-20")
    Economy.grant("fu_lu",12,"日常")
    check(not Economy.grant("fu_lu",1,"日常"), "T1 当日内被拒")
    Economy.reset_daily_if_needed("2026-07-21")
    check(Economy.grant("fu_lu",1,"日常"), "T1 新一日恢复")
    # E1-S6 推荐源
    gs.reset_all(); cl_inject("economy", fake_econ())
    ling_qi_src = Economy.get_recommended_source("ling_qi")
    check("推图" in ling_qi_src, "T1 灵气含推图")
    check("日常" in ling_qi_src, "T1 灵气含日常")
    jue_src = Economy.get_recommended_source("jue_xing_shi")
    eq(len(jue_src), 1, "T1 觉醒石仅1来源")
    eq(jue_src[0], "Boss", "T1 觉醒石仅Boss")
    eq(len(Economy.get_recommended_source("does_not_exist")), 0, "T1 未知货币空")

# ===================== T4 抽卡保底 =====================
def T4_suite():
    # 硬保底 90
    cl_reset(); cl_inject("gacha", fake_pools_hard_only()); cl_inject("economy", fake_econ_high_budget())
    gs.reset_all(); g = GachaManager(); g.rng = RNGWrapper(12345)
    got_ssr = False; first_idx = -1
    for i in range(90):
        r = g.roll_once("hard_only")
        if r.get("rarity") == "SSR":
            got_ssr = True; first_idx = i; break
    check(got_ssr, "T4 第90抽必出SSR")
    eq(first_idx, 89, "T4 恰好第90抽")
    # 硬保底确定性
    cl_reset(); cl_inject("gacha", fake_pools(0.0)); cl_inject("economy", fake_econ_high_budget())
    gs.reset_all(); g = GachaManager(); g.rng = RNGWrapper(12345)
    pool = g._pool("standard"); gs.pity["standard"] = 89
    eq(g._determine_rarity(pool, 89), "SSR", "T4 pity=89下一抽必SSR")
    # 软保底查率
    eq(g.effective_ssr_rate(0, pool), 0.0, "T4 pity=0基础0%")
    ge(g.effective_ssr_rate(49, pool), 0.5, "T4 第50抽>=50%")
    ge(g.effective_ssr_rate(89, pool), 0.95, "T4 近90抽趋近100%")
    # 软保底 empirical
    n = 4000
    for p, exp in [(49, 0.5), (59, 0.625)]:
        ssr = 0
        for i in range(n):
            if g._determine_rarity(pool, p) == "SSR":
                ssr += 1
        approx(float(ssr)/n, exp, 0.08, "T4 empirical pity=%d SSR频率" % p)
    eq(g._determine_rarity(pool, 89), "SSR", "T4 pity=89硬保底")
    # 保底不跨池
    cl_reset(); cl_inject("gacha", fake_pools_no_pity()); cl_inject("economy", fake_econ_high_budget())
    gs.reset_all(); g = GachaManager(); g.rng = RNGWrapper(12345)
    for i in range(89):
        g.roll_once("pool_a")
    eq(g.get_pity("pool_a"), 89, "T4 pool_a计到89")
    eq(g.get_pity("pool_b"), 0, "T4 pool_b从第0")
    g.roll_once("pool_b")
    eq(g.get_pity("pool_b"), 1, "T4 切池独立+1")
    # 新手必出SR
    cl_reset(); cl_inject("gacha", fake_pools(0.0)); cl_inject("economy", fake_econ_high_budget())
    gs.reset_all(); g = GachaManager(); g.rng = RNGWrapper(12345)
    r = g.roll_once("newbie")
    eq(r.get("shikigami_id"), "sr_starter", "T4 必出起步SR")
    eq(r.get("rarity"), "SR", "T4 起步式SR")
    # 新手半价
    cl_reset(); cl_inject("gacha", fake_pools(0.0)); cl_inject("economy", fake_econ_high_budget())
    gs.reset_all(); g = GachaManager(); g.rng = RNGWrapper(12345)
    Economy.grant("fu_lu", 100, "推图")
    eq(gs.currencies.get("fu_lu",0), 100, "T4 初始100")
    g.pull("newbie", 20)
    eq(gs.currencies.get("fu_lu",0), 90, "T4 20抽半价耗10")
    g.pull("newbie", 1)
    eq(gs.currencies.get("fu_lu",0), 89, "T4 第21抽全价-1")
    # 概率抽样
    cl_reset(); cl_inject("gacha", fake_pools(0.0)); cl_inject("economy", fake_econ_high_budget())
    gs.reset_all(); g = GachaManager(); g.rng = RNGWrapper(12345)
    rates = {"SSR":0.02,"SR":0.10,"R":0.35,"N":0.53}
    counts = {"SSR":0,"SR":0,"R":0,"N":0}; nn = 10000
    for i in range(nn):
        counts[g._weighted_roll(rates)] += 1
    approx(float(counts["SSR"])/nn, 0.02, 0.02, "T4 SSR≈2%")
    approx(float(counts["SR"])/nn, 0.10, 0.02, "T4 SR≈10%")
    approx(float(counts["R"])/nn, 0.35, 0.02, "T4 R≈35%")
    approx(float(counts["N"])/nn, 0.53, 0.02, "T4 N≈53%")
    # 概率公示读取
    cl_reset(); cl_inject("gacha", fake_pools(0.0)); cl_inject("economy", fake_econ_high_budget())
    gs.reset_all(); g = GachaManager()
    p = g.get_probabilities("standard")
    eq(p.get("SSR"), 0.0, "T4 注入0%池可读")
    eq(p.get("N"), 0.55, "T4 N=0.55")

# ===================== T3 存档校验 =====================
def T3_suite():
    cl_reset(); gs.reset_all()
    # 写读一致
    gs.currencies = {"fu_lu":30,"ling_qi":500}
    gs.shikigami = [{"id":"ssr_a","level":1,"breakthrough":0,"awakened_skills":[],"bond_level":0,"fragments":0}]
    gs.pity = {"standard":7}
    save = Save.build_save_dict()
    gs.currencies = {}; gs.shikigami = []; gs.pity = {}
    ok = Save.apply_save_dict(save)
    check(ok, "T3 合法checksum接受")
    eq(gs.currencies.get("fu_lu",0), 30, "T3 符箓恢复")
    eq(gs.currencies.get("ling_qi",0), 500, "T3 灵气恢复")
    eq(len(gs.shikigami), 1, "T3 式神恢复")
    eq(gs.pity.get("standard",-1), 7, "T3 保底恢复")
    # checksum 篡改拒绝+回滚
    cl_reset(); gs.reset_all()
    gs.currencies = {"fu_lu":50}
    valid = Save.build_save_dict()
    gs.currencies = {"fu_lu":0}
    tampered = copy.deepcopy(valid)
    tampered["data"]["currencies"] = {"fu_lu":999}
    ok = Save.apply_save_dict(tampered)
    check(not ok, "T3 checksum不符拒绝")
    eq(gs.currencies.get("fu_lu",-1), 0, "T3 拒绝后不变")
    rolled = Save.apply_save_dict(valid)
    check(rolled, "T3 回滚合法档成功")
    eq(gs.currencies.get("fu_lu",-1), 50, "T3 回滚到cache值")
    # last-write-wins
    local = {"meta":{"schema_version":1,"last_write_ts":100,"checksum":"x"},"data":{}}
    cloud_newer = {"meta":{"schema_version":1,"last_write_ts":200,"checksum":"y"},"data":{}}
    cloud_older = {"meta":{"schema_version":1,"last_write_ts":50,"checksum":"z"},"data":{}}
    cloud_same = {"meta":{"schema_version":1,"last_write_ts":100,"checksum":"w"},"data":{}}
    cloud_higher = {"meta":{"schema_version":2,"last_write_ts":1,"checksum":"v"},"data":{}}
    eq(Cloud.resolve_conflict(local, cloud_newer), 2, "T3 云更新取云")
    eq(Cloud.resolve_conflict(local, cloud_older), 1, "T3 本地更新取本地")
    eq(Cloud.resolve_conflict(local, cloud_same), 1, "T3 同ts取本地")
    eq(Cloud.resolve_conflict(local, cloud_higher), 2, "T3 云版本更高取云")
    # delta < 50KB
    cl_reset(); gs.reset_all()
    gs.currencies = {"fu_lu":1}
    normal = Save.build_save_dict()
    check(Cloud.is_delta_within_limit(normal), "T3 普通存档<50KB")
    big = Save.build_save_dict()
    big["data"]["shikigami"] = []
    for i in range(5000):
        big["data"]["shikigami"].append({"id":"ssr_%d"%i,"level":1,"breakthrough":0,"awakened_skills":[],"bond_level":0,"fragments":0})
    check(not Cloud.is_delta_within_limit(big), "T3 超大存档>50KB被标超")
    check(Save.payload_size_bytes(normal) < 50000, "T3 payload字节<50KB")

# ===================== 执行 =====================
if __name__ == "__main__":
    T1_suite()
    T4_suite()
    T3_suite()
    passed = sum(1 for ok, _ in _results if ok)
    failed = len(_results) - passed
    print("=" * 64)
    print("S1 纯逻辑验证（Python 移植）— T1/T4/T3")
    print("=" * 64)
    for ok, msg in _results:
        if not ok:
            print("  [FAIL] " + msg)
    print("-" * 64)
    print("总计断言: %d | 通过: %d | 失败: %d" % (len(_results), passed, failed))
    print("S1 算法层判定: %s" % ("PASS ✅" if failed == 0 else "FAIL ❌"))
    print("=" * 64)
