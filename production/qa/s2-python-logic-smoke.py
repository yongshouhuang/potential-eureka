# S2 纯逻辑验证脚本（Python 移植）
# ---------------------------------------------------------------
# 目的：S2 的 GDScript 当前无法在沙箱运行（无 godot / GUT 未装）。
# 本脚本把 S2 风险最高的「纯逻辑核心」忠实移植到 Python，
# 镜像 GUT 测试 T2（五行克制）/ T6（羁绊事件解耦）/ T7（养成聚合）/
# E4-S5（推图回流）/ E6-S4（云冲突）/ E4-S6（双端适配常量）的关键断言并实跑，
# 给出算法层红/绿信号。
#
# 重要边界（同 S1）：
#  - 本脚本验证「算法/数值正确性」，不验证 Godot API 接线、信号树、场景加载。
#  - RNG 用 Python 种子化 random（与 Godot RandomNumberGenerator 内部序列不同，
#    但分布一致；所有 empirical 断言用 ±容差 / 区间，故 PRNG 差异不影响结论）。
#  - checksum 用确定性 FNV-1a（与 Godot hash() 数值不同，但「篡改即失配」语义一致）。
#  - 这是 GUT 全量跑之前的轻量门禁，不替代用户本地 Godot+GUT 运行。
#
# 数据来源：除 E4-S6 直接读真实 battle_ui_constants.json 校验外，其余逻辑测试
# 注入「真实配置表 + 必要合成式神 def」（与 GDScript before_each inject 等价），
# 并对真实数据文件另做结构一致性校验（防 S1-C2 式数据漂移）。
# ---------------------------------------------------------------

import json
import copy
import random
import os

BASE = r"F:\AI\仙侠卡牌项目"

def _load_json(rel):
    with open(os.path.join(BASE, rel), "r", encoding="utf-8") as f:
        return json.load(f)

# 真实数据文件（加载失败则记为 None，结构校验会明确报错）
REAL = {}
for _rel in [
    "data/battle/element_matrix.json",
    "data/battle/bond_combos.json",
    "data/cultivation/cultivation_config.json",
    "data/shikigami/shikigami_defs.json",
    "data/battle/chapters.json",
    "data/battle/battle_ui_constants.json",
    "data/economy/economy_config.json",
]:
    try:
        REAL[_rel] = _load_json(_rel)
    except Exception as _e:
        REAL[_rel] = None
        print("  [WARN] 真实数据加载失败 %s: %s" % (_rel, _e))


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
    def clear(self):
        self._handlers.clear()

class EventBus:
    economy_currency_changed = Signal()
    economy_reward_granted = Signal()
    gacha_shikigami_obtained = Signal()
    save_written = Signal()
    save_loaded = Signal()
    save_rejected = Signal()
    accessibility_changed = Signal()
    bond_combo = Signal()
    cultivate_level_up = Signal()
    cultivate_breakthrough = Signal()
    cultivate_awakened = Signal()
    cultivate_branch_chosen = Signal()
    battle_started = Signal()
    battle_victory = Signal()
    battle_defeat = Signal()
    battle_turn_resolved = Signal()
    battle_element_advantage = Signal()
    battle_reward_dropped = Signal()
    sync_success = Signal()
    sync_conflict = Signal()

def _clear_battle_signals():
    for s in [EventBus.bond_combo, EventBus.battle_element_advantage,
              EventBus.battle_reward_dropped, EventBus.battle_started,
              EventBus.battle_victory, EventBus.battle_defeat,
              EventBus.battle_turn_resolved]:
        s.clear()


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
        return self._rng.randrange(length)
    def randi_range(self, a, b):
        return self._rng.randint(a, b)  # Godot randi_range 含两端


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
    return None


# ===================== 工具函数 =====================
def lerp(a, b, t):
    return a + (b - a) * t
def clampf(v, lo, hi):
    return max(lo, min(hi, v))
def clampi(v, lo, hi):
    return max(lo, min(hi, v))
def json_str(obj):
    return json.dumps(obj, ensure_ascii=False)
def _fnv1a(s):
    h = 0x811c9dc5
    for b in s.encode("utf-8"):
        h ^= b
        h = (h * 0x01000193) & 0xffffffff
    return str(h)


# ===================== EconomyManager（移植，S1 同款） =====================
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
        return c.get(currency, {})
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
        return [s for s in src.get(deficit_currency, [])]
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


# ===================== SaveManager（移植，S1 同款） =====================
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


# ===================== CloudSaveService（移植，E6-S4） =====================
class CloudSaveService:
    DELTA_LIMIT_BYTES = 50000
    SYNC_LATENCY_MOCK_MS = 200
    def __init__(self):
        self._cloud = {}
        self._cache = {}
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
    def push_save(self, local):
        if not self.is_delta_within_limit(local):
            return False
        self._cache = copy.deepcopy(local)
        self._cloud = copy.deepcopy(local)
        EventBus.sync_success.emit()
        return True
    def pull_and_resolve(self, local):
        if self._cloud == {}:
            return local
        winner = self.resolve_conflict(local, self._cloud)
        if winner == 2:
            EventBus.sync_conflict.emit(False)
            return copy.deepcopy(self._cloud)
        EventBus.sync_conflict.emit(True)
        return local
    def is_online(self):
        return True
    def mock_sync_latency(self):
        return float(self.SYNC_LATENCY_MOCK_MS)
    def receive_cloud(self, snapshot):
        self._cloud = copy.deepcopy(snapshot)


# ===================== BattleResolver（移植，B4/E4-S2/T2） =====================
class BattleResolver:
    NEUTRAL = 1.0
    def __init__(self):
        self.rng = RNGWrapper(1)
    def _matrix(self):
        return cl_load_table("battle/element_matrix", "")
    def relation(self, skill_element, defender_element):
        m = self._matrix()
        ke = m.get("ke", {})
        sheng = m.get("sheng", {})
        if ke.get(skill_element, "") == defender_element:
            return "ADVANTAGE"
        if ke.get(defender_element, "") == skill_element:
            return "DISADVANTAGE"
        if sheng.get(skill_element, "") == defender_element:
            return "SHENG"
        return "NEUTRAL"
    def _band(self, rel):
        m = self._matrix()
        if rel == "ADVANTAGE":
            return lerp(float(m.get("advantage_min", 1.25)), float(m.get("advantage_max", 1.35)), self.rng.randf())
        if rel == "DISADVANTAGE":
            return lerp(float(m.get("disadvantage_min", 0.7)), float(m.get("disadvantage_max", 0.8)), self.rng.randf())
        if rel == "SHENG":
            return lerp(float(m.get("sheng_bonus_min", 1.02)), float(m.get("sheng_bonus_max", 1.05)), self.rng.randf())
        return self.NEUTRAL
    def resolve_damage(self, attacker, defender, skill):
        atk_elem = attacker.get("element", "")
        def_elem = defender.get("element", "")
        skill_elem = skill.get("element", atk_elem)
        base_atk = float(attacker.get("atk", attacker.get("stats", {}).get("atk", 0)))
        power = float(skill.get("power", 1.0))
        base = base_atk * power
        rel = self.relation(skill_elem, def_elem)
        mult = self._band(rel)
        dmg = int(round(base * mult))
        return {"damage": dmg, "multiplier": mult, "relation": rel, "element": skill_elem}


# ===================== BondManager（移植，A1/E4-S3/T6） =====================
class BondManager:
    def __init__(self):
        pass
    def _combos(self):
        return cl_load_table("battle/bond_combos", "")
    def _ids(self, team):
        out = []
        for t in team:
            if isinstance(t, str):
                out.append(t)
            elif isinstance(t, dict) and "id" in t:
                out.append(str(t["id"]))
        return out
    def compute_combo(self, deck_or_team):
        ids = self._ids(deck_or_team)
        groups = self._combos().get("groups", {})
        best_bonus = 0.0
        best_group = ""
        for gid in groups.keys():
            g = groups[gid]
            members = g.get("members", [])
            cnt = 0
            for mid in members:
                if str(mid) in ids:
                    cnt += 1
            if cnt < 2:
                continue
            if cnt >= 3:
                bonus = 0.5 * (float(g.get("combo_3plus_min", 0.15)) + float(g.get("combo_3plus_max", 0.20)))
            else:
                bonus = 0.5 * (float(g.get("combo_2_min", 0.08)) + float(g.get("combo_2_max", 0.12)))
            if bonus > best_bonus:
                best_bonus = bonus
                best_group = gid
        if best_bonus > 0.0:
            EventBus.bond_combo.emit(best_group, best_bonus)
        return best_bonus


# ===================== CultivationManager（移植，B3/E3） =====================
class CultivationManager:
    MAX_BREAKTHROUGH = 5
    MIN_BRANCH_TIER = 3
    def _cult(self):
        return cl_load_table("cultivation", "")
    def _defs(self):
        return cl_load_table("shikigami", "")
    def _entry(self, id):
        for s in gs.shikigami:
            if s.get("id", "") == id:
                return s
        return {}
    def max_level(self, id):
        c = self._cult()
        caps = c.get("breakthrough", {}).get("level_cap_per_tier", [20, 36, 52, 64, 72, 80])
        e = self._entry(id)
        bt = int(e.get("breakthrough", 0))
        bt = clampi(bt, 0, self.MAX_BREAKTHROUGH)
        if bt < len(caps):
            return int(caps[bt])
        return int(caps[len(caps) - 1])
    def upgrade(self, id):
        e = self._entry(id)
        if e == {}:
            return False
        lvl = int(e.get("level", 1))
        cap = self.max_level(id)
        if lvl >= cap:
            return False
        cost = int(self._cult().get("upgrade", {}).get("ling_qi_per_level", 50)) * lvl
        if not Economy.spend("ling_qi", cost, "cultivate"):
            return False
        e["level"] = lvl + 1
        EventBus.cultivate_level_up.emit(id, e["level"])
        return True
    def _passive_slots_for(self, bt):
        slots = self._cult().get("breakthrough", {}).get("passive_slots_per_tier", [1, 2, 3, 4, 5, 6])
        bt = clampi(bt, 0, self.MAX_BREAKTHROUGH)
        if bt < len(slots):
            return int(slots[bt])
        return int(slots[len(slots) - 1])
    def breakthrough(self, id):
        e = self._entry(id)
        if e == {}:
            return False
        bt = int(e.get("breakthrough", 0))
        if bt >= self.MAX_BREAKTHROUGH:
            return False
        bc = self._cult().get("breakthrough_cost", {})
        need_po_dan = int(bc.get("po_dan_per_tier", 1))
        need_frag = int(bc.get("fragments_per_tier", 5))
        if int(e.get("fragments", 0)) < need_frag:
            return False
        if not Economy.spend("po_dan", need_po_dan, "cultivate"):
            return False
        e["fragments"] = int(e.get("fragments", 0)) - need_frag
        e["breakthrough"] = bt + 1
        e["passive_slots"] = self._passive_slots_for(e["breakthrough"])
        EventBus.cultivate_breakthrough.emit(id, e["breakthrough"])
        return True
    def awaken_skill(self, id):
        e = self._entry(id)
        if e == {}:
            return False
        bt = int(e.get("breakthrough", 0))
        threshold = int(self._cult().get("awaken", {}).get("tier_threshold", self.MIN_BRANCH_TIER))
        if bt < threshold:
            return False
        skills = e.get("awakened_skills", [])
        if len(skills) > 0:
            return False
        table = self._cult().get("awaken", {}).get("skills_by_shikigami", {})
        skill_id = table.get(id, "skill_%s_awakened" % id)
        skills.append(skill_id)
        e["awakened_skills"] = skills
        EventBus.cultivate_awakened.emit(id, skill_id)
        return True
    def choose_branch(self, id, branch):
        e = self._entry(id)
        if e == {}:
            return False
        bt = int(e.get("breakthrough", 0))
        if bt < self.MIN_BRANCH_TIER:
            return False
        branches = self._cult().get("branches", {})
        if branch not in branches:
            return False
        e["branch"] = branch
        EventBus.cultivate_branch_chosen.emit(id, branch)
        return True
    def get_final_unit(self, id):
        defs = self._defs().get("shikigami", {})
        if id not in defs:
            return {}
        def_ = defs[id]
        e = self._entry(id)
        level = int(e.get("level", 1)) if e != {} else 1
        bt = int(e.get("breakthrough", 0)) if e != {} else 0
        bt = clampi(bt, 0, self.MAX_BREAKTHROUGH)
        lc = self._cult().get("level_curve", {})
        hp_rate = 0.5 * (float(lc.get("hp_per_level_pct_min", 0.02)) + float(lc.get("hp_per_level_pct_max", 0.03)))
        atk_rate = 0.5 * (float(lc.get("atk_per_level_pct_min", 0.02)) + float(lc.get("atk_per_level_pct_max", 0.03)))
        base_hp = float(def_.get("base_stats", {}).get("hp", 0))
        base_atk = float(def_.get("base_stats", {}).get("atk", 0))
        after_level_hp = base_hp * (1.0 + hp_rate * float(level - 1))
        after_level_atk = base_atk * (1.0 + atk_rate * float(level - 1))
        bc = self._cult().get("breakthrough", {})
        bt_rate = 0.5 * (float(bc.get("attr_gain_pct_min", 0.08)) + float(bc.get("attr_gain_pct_max", 0.12)))
        final_hp = int(round(after_level_hp * (1.0 + bt_rate * float(bt))))
        final_atk = int(round(after_level_atk * (1.0 + bt_rate * float(bt))))
        skills = []
        for s in def_.get("skills", []):
            skills.append(s)
        for s in (e.get("awakened_skills", []) if e != {} else []):
            skills.append(s)
        branch = e.get("branch", "") if e != {} else ""
        if branch != "":
            branches = self._cult().get("branches", {})
            if branch in branches:
                skills.append(branches[branch].get("passive", ""))
        return {
            "id": id,
            "element": def_.get("element", ""),
            "bond_tags": def_.get("bond_tags", []),
            "final_stats": {"hp": final_hp, "atk": final_atk},
            "skills": skills,
            "breakthrough": bt,
            "passive_slots": self._passive_slots_for(bt),
            "branch": branch,
            "level": level,
        }


# ===================== BattleManager（移植，B4/E4-S2..S5） =====================
class BattleManager:
    def __init__(self):
        self._resolver = BattleResolver()
        self.rng = RNGWrapper(1)
        self._players = []
        self._enemies = []
        self._order = []
        self._actors = []
        self._cursor = 0
        self._chapter = 0
        self._stage = 0
        self._stage_def = {}
        self._bond_bonus = 0.0
        self._resolved = False
        self._outcome = ""
        EventBus.bond_combo.connect(self._on_bond_combo)
    def _on_bond_combo(self, _group_id, bonus_pct):
        self._bond_bonus = bonus_pct
    def _chapters(self):
        return cl_load_table("battle/chapters", "")
    def start_battle(self, chapter, stage):
        self._resolved = False
        self._outcome = ""
        self._bond_bonus = 0.0
        self._cursor = 0
        self._chapter = chapter
        self._stage = stage
        ch_def = self._find_chapter(chapter)
        if ch_def == {}:
            return False
        self._stage_def = self._find_stage(ch_def, stage)
        if self._stage_def == {}:
            return False
        self._build_players()
        self._build_enemies()
        if len(self._players) == 0:
            return False
        self._build_order()
        EventBus.battle_started.emit(chapter, stage)
        return True
    def _find_chapter(self, chapter):
        for c in self._chapters().get("chapters", []):
            if int(c.get("id", 0)) == chapter:
                return c
        return {}
    def _find_stage(self, ch_def, stage):
        for s in ch_def.get("stages", []):
            if int(s.get("id", 0)) == stage:
                return s
        return {}
    def _build_players(self):
        self._players = []
        for entry in gs.deck:
            sid = str(entry)
            fu = Cultivation.get_final_unit(sid)
            if fu == {}:
                continue
            self._players.append({
                "id": sid, "side": "player", "element": fu.get("element", ""),
                "atk": int(fu.get("final_stats", {}).get("atk", 0)),
                "hp": int(fu.get("final_stats", {}).get("hp", 0)),
                "max_hp": int(fu.get("final_stats", {}).get("hp", 0)),
                "skills": fu.get("skills", []), "bond_tags": fu.get("bond_tags", []),
            })
    def _build_enemies(self):
        self._enemies = []
        for e in self._stage_def.get("enemies", []):
            self._enemies.append({
                "id": str(e.get("id", "enemy")), "side": "enemy",
                "element": e.get("element", ""),
                "atk": int(e.get("stats", {}).get("atk", 0)),
                "hp": int(e.get("stats", {}).get("hp", 0)),
                "max_hp": int(e.get("stats", {}).get("hp", 0)),
                "skills": [], "bond_tags": [],
            })
    def _build_order(self):
        self._actors = self._players + self._enemies
        idx = list(range(len(self._actors)))
        def key(a):
            sa = int(self._actors[a].get("atk", 0))
            side = self._actors[a].get("side", "")
            return (-sa, 0 if side == "player" else 1)
        idx.sort(key=key)
        self._order = idx
    def step(self):
        if self._resolved:
            return {"done": True, "outcome": self._outcome}
        if len(self._order) == 0:
            return {"done": True}
        actor = {}
        found = False
        guard = 0
        while guard < len(self._order):
            cand = self._actors[self._order[self._cursor]]
            self._cursor = (self._cursor + 1) % len(self._order)
            if int(cand.get("hp", 0)) > 0:
                actor = cand
                found = True
                break
            guard += 1
        if not found:
            self._resolve_outcome()
            return {"done": True, "outcome": self._outcome}
        target = None
        skill = {}
        if actor.get("side", "") == "player":
            target = self._first_alive(self._enemies)
            skill = {"element": actor.get("element", ""), "power": 1.0}
        else:
            target = self._first_alive(self._players)
            skill = {"element": actor.get("element", ""), "power": 1.0}
        if target is None:
            self._resolve_outcome()
            return {"done": True, "outcome": self._outcome}
        atk_dict = {"element": actor.get("element", ""), "atk": actor.get("atk", 0)}
        def_dict = {"element": target.get("element", ""), "atk": target.get("atk", 0)}
        res = self._resolver.resolve_damage(atk_dict, def_dict, skill)
        dmg = int(res.get("damage", 0))
        if actor.get("side", "") == "player" and self._bond_bonus > 0.0:
            dmg = int(round(float(dmg) * (1.0 + self._bond_bonus)))
        target["hp"] = int(target.get("hp", 0)) - dmg
        relation = res.get("relation", "NEUTRAL")
        if actor.get("side", "") == "player" and relation == "ADVANTAGE":
            EventBus.battle_element_advantage.emit(str(actor.get("id", "")), str(target.get("id", "")), float(res.get("multiplier", 1.0)))
        EventBus.battle_turn_resolved.emit(str(actor.get("id", "")), str(target.get("id", "")), dmg, relation)
        defeated = int(target.get("hp", 0)) <= 0
        if defeated:
            target["hp"] = 0
        self._resolve_outcome()
        return {
            "done": self._resolved,
            "actor_id": actor.get("id", ""),
            "target_id": target.get("id", ""),
            "damage": dmg,
            "relation": relation,
            "defeated": defeated,
            "outcome": self._outcome,
        }
    def auto_resolve(self, max_steps=200):
        last = {}
        for i in range(max_steps):
            last = self.step()
            if self._resolved:
                break
        return last
    def _resolve_outcome(self):
        if self._resolved:
            return
        if self._first_alive(self._enemies) is None:
            self._victory()
        elif self._first_alive(self._players) is None:
            self._defeat()
    def _victory(self):
        self._resolved = True
        self._outcome = "victory"
        self._advance_progression()
        self._grant_rewards()
        EventBus.battle_victory.emit(self._chapter, self._stage)
    def _defeat(self):
        self._resolved = True
        self._outcome = "defeat"
        EventBus.battle_defeat.emit(self._chapter, self._stage)
    def _advance_progression(self):
        if "stages_cleared" not in gs.progression:
            gs.progression["stages_cleared"] = 0
        if "chapters_cleared" not in gs.progression:
            gs.progression["chapters_cleared"] = 0
        gs.progression["stages_cleared"] = int(gs.progression["stages_cleared"]) + 1
        if bool(self._stage_def.get("boss", False)):
            gs.progression["chapters_cleared"] = int(gs.progression["chapters_cleared"]) + 1
    def _grant_rewards(self):
        rwd = self._stage_def.get("reward", {})
        gained = {"fu_lu": 0, "po_dan": 0, "jue_xing_shi": 0}
        fu_range = rwd.get("fu_lu", [0, 0])
        fu_amt = self.rng.randi_range(int(fu_range[0]), int(fu_range[1])) if len(fu_range) >= 2 else 0
        if fu_amt > 0:
            if Economy.grant("fu_lu", fu_amt, "battle"):
                gained["fu_lu"] = fu_amt
        po_dan = int(rwd.get("po_dan", 0))
        if po_dan > 0:
            if Economy.grant("po_dan", po_dan, "battle"):
                gained["po_dan"] = po_dan
        jue = int(rwd.get("jue_xing_shi", 0))
        if jue > 0:
            if Economy.grant("jue_xing_shi", jue, "Boss"):
                gained["jue_xing_shi"] = jue
        EventBus.battle_reward_dropped.emit(gained)
    def is_victory(self):
        return self._outcome == "victory"
    def is_defeat(self):
        return self._outcome == "defeat"
    def is_resolved(self):
        return self._resolved
    def get_bond_bonus(self):
        return self._bond_bonus
    def _first_alive(self, lst):
        for u in lst:
            if int(u.get("hp", 0)) > 0:
                return u
        return None


# ===================== 实例化 =====================
Economy = EconomyManager()
Cultivation = CultivationManager()
Save = SaveManager()
Cloud = CloudSaveService()


# ===================== 极简断言框架 =====================
_results = []
def check(cond, msg):
    _results.append((bool(cond), msg)); return bool(cond)
def eq(a, b, msg):
    ok = (a == b); _results.append((ok, "%s (got=%r, exp=%r)" % (msg, a, b))); return ok
def ge(a, b, msg):
    ok = (a >= b); _results.append((ok, "%s (got=%r, exp>=%r)" % (msg, a, b))); return ok
def gt(a, b, msg):
    ok = (a > b); _results.append((ok, "%s (got=%r, exp>%r)" % (msg, a, b))); return ok
def approx(a, b, tol, msg):
    ok = (abs(a - b) <= tol); _results.append((ok, "%s (got=%r, exp~%r, tol=%r)" % (msg, a, b, tol))); return ok


# ===================== T2 五行克制（BattleResolver） =====================
def T2_suite():
    cl_reset()
    cl_inject("battle/element_matrix", REAL["data/battle/element_matrix.json"])
    # 关系判定
    r = BattleResolver()
    eq(r.relation("metal", "wood"), "ADVANTAGE", "T2 金克木")
    eq(r.relation("wood", "metal"), "DISADVANTAGE", "T2 木被金克")
    eq(r.relation("wood", "fire"), "SHENG", "T2 木生火")
    eq(r.relation("metal", "earth"), "NEUTRAL", "T2 金vs土无关系")
    # 克制 base100 -> [125,135]
    r.rng = RNGWrapper(20240720)
    res = r.resolve_damage({"element":"metal","atk":100}, {"element":"wood","atk":50}, {"element":"metal","power":1.0})
    eq(res["relation"], "ADVANTAGE", "T2 克制关系")
    check(125 <= res["damage"] <= 135, "T2 克制伤害落入×[1.25,1.35]=[125,135]（实际%d）" % res["damage"])
    # 被克 base100 -> [70,80]
    res = r.resolve_damage({"element":"wood","atk":100}, {"element":"metal","atk":50}, {"element":"wood","power":1.0})
    eq(res["relation"], "DISADVANTAGE", "T2 被克关系")
    check(70 <= res["damage"] <= 80, "T2 被克伤害落入×[0.7,0.8]=[70,80]（实际%d）" % res["damage"])
    # 相生 base100 -> [102,105]
    res = r.resolve_damage({"element":"wood","atk":100}, {"element":"fire","atk":50}, {"element":"wood","power":1.0})
    eq(res["relation"], "SHENG", "T2 相生关系")
    check(res["damage"] > 100, "T2 相生增益>0（实际%d）" % res["damage"])
    check(102 <= res["damage"] <= 105, "T2 相生落入×[1.02,1.05]=[102,105]（实际%d）" % res["damage"])
    # 中立 base100 -> 100
    res = r.resolve_damage({"element":"metal","atk":100}, {"element":"earth","atk":50}, {"element":"metal","power":1.0})
    eq(res["relation"], "NEUTRAL", "T2 中立关系")
    eq(res["damage"], 100, "T2 中立倍率1.0 -> 伤害=base")
    # 多 seed 仍在 band
    for s in [1, 2, 3, 7, 42]:
        rr = BattleResolver(); rr.rng = RNGWrapper(s)
        res = rr.resolve_damage({"element":"metal","atk":100}, {"element":"wood","atk":50}, {"element":"metal","power":1.0})
        check(125 <= res["damage"] <= 135, "T2 seed%d 克制仍在band内" % s)


# ===================== T6 羁绊连携 + 事件解耦（真实 bond_combos） =====================
def T6_suite():
    cl_reset()
    cl_inject("battle/bond_combos", REAL["data/battle/bond_combos.json"])
    _clear_battle_signals()
    # 2 人同队 -> +10% 中点（真实 jian_zong 含这两个 id）
    bm = BondManager()
    bonus = bm.compute_combo(["ssr_qing_long", "ssr_bai_hu"])
    approx(bonus, 0.10, 1e-9, "T6 2人连携中点=+10%")
    check(0.08 <= bonus <= 0.12, "T6 2人落入+8~12%")
    # 3+ 人 -> +17.5% 中点
    bonus3 = bm.compute_combo(["ssr_qing_long", "ssr_bai_hu", "sr_you_ming"])
    approx(bonus3, 0.175, 1e-9, "T6 3+人连携中点=+17.5%")
    check(0.15 <= bonus3 <= 0.20, "T6 3+人落入+15~20%")
    # 不足 2 人无连携
    eq(bm.compute_combo(["ssr_qing_long"]), 0.0, "T6 单人无连携")
    eq(bm.compute_combo([]), 0.0, "T6 空队无连携")
    # 事件解耦：BattleManager 经 bond:combo 事件获得加成（不 import BondManager）
    _clear_battle_signals()
    bat = BattleManager()
    bat.rng = RNGWrapper(1)
    eq(bat.get_bond_bonus(), 0.0, "T6 初始无加成")
    b2 = bm.compute_combo(["ssr_qing_long", "ssr_bai_hu"])
    approx(b2, 0.10, 1e-9, "T6 BondManager算出2人连携中点")
    eq(bat.get_bond_bonus(), 0.10, "T6 BattleManager经事件获相同加成(2人)")
    b3 = bm.compute_combo(["ssr_qing_long", "ssr_bai_hu", "sr_you_ming"])
    eq(bat.get_bond_bonus(), 0.175, "T6 3+连携也经事件更新")


# ===================== T7 / E3 养成聚合（合成 test_ssr def） =====================
def _fake_cultivation():
    return {
        "breakthrough": {
            "max_tier": 6,
            "level_cap_per_tier": [20, 36, 52, 64, 72, 80],
            "attr_gain_pct_min": 0.08, "attr_gain_pct_max": 0.12,
            "passive_slots_per_tier": [1, 2, 3, 4, 5, 6],
        },
        "level_curve": {
            "hp_per_level_pct_min": 0.02, "hp_per_level_pct_max": 0.03,
            "atk_per_level_pct_min": 0.02, "atk_per_level_pct_max": 0.03,
        },
        "upgrade": {"ling_qi_per_level": 50},
        "breakthrough_cost": {"po_dan_per_tier": 1, "fragments_per_tier": 5},
        "awaken": {"tier_threshold": 3, "skills_by_shikigami": {"test_ssr": "skill_test_awakened"}},
        "branches": {"sword": {"passive": "jian_xiu_passive", "name": "剑修"},
                     "body": {"passive": "ti_xiu_passive", "name": "体修"}},
    }
def _fake_shikigami_defs():
    return {"shikigami": {
        "test_ssr": {"name":"测试式神","element":"metal","rarity":"SSR",
                     "bond_tags":["g1","g2"],"base_stats":{"hp":200,"atk":80},"skills":["sk_base"]}}}
def _set_shikigami(level, bt, awakened, branch, fragments):
    gs.shikigami = [{"id":"test_ssr","level":level,"breakthrough":bt,
                     "awakened_skills":awakened,"bond_level":0,"fragments":fragments,"branch":branch}]

def T7_suite():
    cl_reset()
    cl_inject("battle/element_matrix", REAL["data/battle/element_matrix.json"])
    cl_inject("cultivation", _fake_cultivation())
    cl_inject("shikigami", _fake_shikigami_defs())
    cl_inject("economy", {
        "currencies": {"ling_qi":{}, "po_dan":{"weekly_cap":100}, "jue_xing_shi":{"boss_only":True}},
        "free_ten_pull": {"amount":10}, "sources": {}})
    gs.reset_all(); _set_shikigami(1, 0, [], "", 99)
    # E3-S1 线性 +2.5%/级
    Economy.grant("ling_qi", 1000, "推图")
    check(Cultivation.upgrade("test_ssr"), "T7 升级成功")
    eq(gs.shikigami[0]["level"], 2, "T7 等级->2")
    fu = Cultivation.get_final_unit("test_ssr")
    eq(fu["final_stats"]["atk"], 82, "T7 atk 线性+2.5%=82")
    eq(fu["final_stats"]["hp"], 205, "T7 hp 线性+2.5%=205")
    # 多级线性 10 级
    _set_shikigami(1, 0, [], "", 99); Economy.grant("ling_qi", 100000, "推图")
    for i in range(10):
        Cultivation.upgrade("test_ssr")
    eq(gs.shikigami[0]["level"], 11, "T7 升到11级")
    fu = Cultivation.get_final_unit("test_ssr")
    eq(fu["final_stats"]["atk"], 100, "T7 10级后atk=100")
    eq(fu["final_stats"]["hp"], 250, "T7 10级后hp=250")
    # 等级上限随突破阶 + 超阶拦截
    _set_shikigami(1, 0, [], "", 99)
    eq(Cultivation.max_level("test_ssr"), 20, "T7 bt0->Lv20")
    gs.shikigami[0]["breakthrough"] = 1
    eq(Cultivation.max_level("test_ssr"), 36, "T7 bt1->Lv36")
    gs.shikigami[0]["level"] = 36; Economy.grant("ling_qi", 100000, "推图")
    check(not Cultivation.upgrade("test_ssr"), "T7 已到Lv36上限被拦截")
    eq(gs.shikigami[0]["level"], 36, "T7 等级不变")
    # E3-S2 突破 +10% + 被动槽
    _set_shikigami(1, 0, [], "", 99); Economy.grant("ling_qi", 100000, "推图"); Economy.grant("po_dan", 10, "推图")
    check(Cultivation.breakthrough("test_ssr"), "T7 突破成功")
    eq(gs.shikigami[0]["breakthrough"], 1, "T7 突破->阶2")
    eq(gs.shikigami[0].get("passive_slots"), 2, "T7 被动槽=2")
    fu = Cultivation.get_final_unit("test_ssr")
    eq(fu["final_stats"]["atk"], 88, "T7 atk 突破+10%=88")
    eq(fu["final_stats"]["hp"], 220, "T7 hp 突破+10%=220")
    eq(fu["passive_slots"], 2, "T7 get_final_unit被动槽一致")
    # 碎片不足拦截
    _set_shikigami(1, 0, [], "", 0); Economy.grant("po_dan", 10, "推图")
    check(not Cultivation.breakthrough("test_ssr"), "T7 碎片不足拦截")
    # E3-S3 觉醒
    _set_shikigami(1, 3, [], "", 99)
    check(Cultivation.awaken_skill("test_ssr"), "T7 觉醒成功")
    check("skill_test_awakened" in gs.shikigami[0]["awakened_skills"], "T7 标记觉醒技")
    _set_shikigami(1, 1, [], "", 99)
    check(not Cultivation.awaken_skill("test_ssr"), "T7 未达阶门槛觉醒被拒")
    # E3-S4 分支
    _set_shikigami(1, 3, [], "", 99)
    check(Cultivation.choose_branch("test_ssr", "sword"), "T7 选剑修")
    eq(gs.shikigami[0]["branch"], "sword", "T7 记录分支")
    _set_shikigami(1, 1, [], "", 99)
    check(not Cultivation.choose_branch("test_ssr", "sword"), "T7 低阶选分支被拒")
    # E3-S5 / T7 聚合
    _set_shikigami(11, 2, ["skill_test_awakened"], "sword", 99)
    fu = Cultivation.get_final_unit("test_ssr")
    eq(fu["element"], "metal", "T7 element聚合")
    eq(fu["bond_tags"], ["g1","g2"], "T7 bond_tags聚合")
    eq(fu["breakthrough"], 2, "T7 breakthrough聚合")
    eq(fu["final_stats"]["atk"], 120, "T7 final atk聚合=120")
    eq(fu["final_stats"]["hp"], 300, "T7 final hp聚合=300")
    eq(fu["passive_slots"], 3, "T7 passive_slots=3(bt2)")
    check("sk_base" in fu["skills"], "T7 含基础技")
    check("skill_test_awakened" in fu["skills"], "T7 含觉醒技")
    check("jian_xiu_passive" in fu["skills"], "T7 含剑修被动")
    eq(fu["branch"], "sword", "T7 branch聚合")
    # T7 喂给 BattleResolver 一致
    attacker = {"element": fu["element"], "atk": fu["final_stats"]["atk"]}
    res = BattleResolver().resolve_damage(attacker, {"element":"wood","atk":50}, {"element":"metal","power":1.0})
    eq(res["relation"], "ADVANTAGE", "T7 metal克wood->克制")
    check(150 <= res["damage"] <= 162, "T7 克制伤害落入[150,162]（实际%d）" % res["damage"])


# ===================== E4-S4/S5 推图回合 + 回流（真实 chapters） =====================
def _setup_hero_battle():
    cl_reset()
    cl_inject("battle/element_matrix", REAL["data/battle/element_matrix.json"])
    cl_inject("cultivation", REAL["data/cultivation/cultivation_config.json"])
    cl_inject("battle/chapters", REAL["data/battle/chapters.json"])
    cl_inject("shikigami", {"shikigami": {
        "hero": {"name":"侠客","element":"metal","rarity":"SSR","bond_tags":[],
                 "base_stats":{"hp":500,"atk":200},"skills":["sk_hero"]}}})
    cl_inject("economy", {
        "currencies": {"fu_lu":{"daily_cap":100000}, "po_dan":{"weekly_cap":100}, "jue_xing_shi":{"boss_only":True}},
        "free_ten_pull": {"amount":10}, "sources": {}})
    gs.reset_all()
    Economy.set_date_override("2026-07-20"); Economy.set_week_override(30)
    gs.shikigami = [{"id":"hero","level":1,"breakthrough":0,"awakened_skills":[],"bond_level":0,"fragments":0,"branch":""}]
    gs.deck = ["hero"]

def E4_S5_suite():
    _clear_battle_signals()
    _setup_hero_battle()
    # E4-S4 AC1 一回合跑通不崩
    bat = BattleManager(); bat.rng = RNGWrapper(1)
    check(bat.start_battle(1, 1), "E4-S5 开局成功")
    res = bat.step()
    check("actor_id" in res, "E4-S5 返回回合摘要")
    check(bat.is_resolved(), "E4-S5 杂兵被秒->已分胜负")
    # E4-S4 AC2 克制命中 emit battle:element_advantage
    _clear_battle_signals()
    seen = []
    def on_adv(a, t, m): seen.append({"a":a,"t":t,"m":m})
    _setup_hero_battle()
    bat = BattleManager(); bat.rng = RNGWrapper(1)
    bat.start_battle(1, 5)  # 侠客(metal) vs 真实木敌 c1_n5_e1(wood) 克制
    EventBus.battle_element_advantage.connect(on_adv)
    bat.step()
    EventBus.battle_element_advantage.disconnect(on_adv)
    check(len(seen) >= 1, "E4-S5 克制命中emit battle:element_advantage（实际%d）" % len(seen))
    eq(seen[0]["a"], "hero", "E4-S5 攻击方hero")
    eq(seen[0]["t"], "c1_n5_e1", "E4-S5 目标c1_n5_e1(wood)")
    check(1.25 <= seen[0]["m"] <= 1.35, "E4-S5 倍率落入克制区间")
    # E4-S5 通关推进 + 回流（Boss 关，真实配置）
    _clear_battle_signals()
    gained = {}
    def on_reward(r): gained.update(r)
    _setup_hero_battle()
    bat = BattleManager(); bat.rng = RNGWrapper(7)
    bat.start_battle(1, 9)  # Boss 关
    fu_before = int(gs.currencies.get("fu_lu", 0))
    po_before = int(gs.currencies.get("po_dan", 0))
    jue_before = int(gs.currencies.get("jue_xing_shi", 0))
    EventBus.battle_reward_dropped.connect(on_reward)
    bat.auto_resolve()
    EventBus.battle_reward_dropped.disconnect(on_reward)
    check(bat.is_victory(), "E4-S5 Boss关通关")
    eq(int(gs.progression.get("stages_cleared",0)), 1, "E4-S5 stages_cleared+1")
    eq(int(gs.progression.get("chapters_cleared",0)), 1, "E4-S5 Boss关->chapters_cleared+1")
    gt(int(gs.currencies.get("fu_lu",0)), fu_before, "E4-S5 符箓回流增加")
    gt(int(gs.currencies.get("po_dan",0)), po_before, "E4-S5 突破丹回流增加")
    gt(int(gs.currencies.get("jue_xing_shi",0)), jue_before, "E4-S5 觉醒石回流增加")
    check(gained.get("fu_lu",0) >= 1, "E4-S5 reward事件含符箓")
    eq(gained.get("po_dan",0), 1, "E4-S5 reward事件含突破丹1")
    eq(gained.get("jue_xing_shi",0), 1, "E4-S5 reward事件含觉醒石1(Boss来源)")


# ===================== E6-S4 云存档冲突（含 S2 新增 mock 延迟） =====================
def _make_save(ts, fu):
    gs.currencies = {"fu_lu": fu}
    s = Save.build_save_dict()
    s["meta"]["schema_version"] = 1
    s["meta"]["last_write_ts"] = ts
    return s

def E6_S4_suite():
    cl_reset(); gs.reset_all()
    # push -> pull 回合同一档一致 + cache 副本
    local = _make_save(100, 30)
    check(Cloud.push_save(local), "E6-S4 push成功")
    check(Cloud._cache != {}, "E6-S4 push后cache副本存在")
    res = Cloud.pull_and_resolve(copy.deepcopy(local))
    eq(res["data"]["currencies"].get("fu_lu", -1), 30, "E6-S4 pull回合同一档一致")
    # 云更新 -> 取云；cache 保留本地
    local = _make_save(100, 30); Cloud.push_save(local)
    cloud = _make_save(200, 50); Cloud.receive_cloud(cloud)
    res = Cloud.pull_and_resolve(copy.deepcopy(local))
    eq(res["data"]["currencies"].get("fu_lu", -1), 50, "E6-S4 云更新取云")
    eq(Cloud._cache["data"]["currencies"].get("fu_lu", -1), 30, "E6-S4 cache保留本地可回滚")
    # 本地更新 -> 取本地
    local_newer = _make_save(300, 30); Cloud.push_save(local_newer)
    cloud_old = _make_save(200, 50); Cloud.receive_cloud(cloud_old)
    res = Cloud.pull_and_resolve(copy.deepcopy(local_newer))
    eq(res["data"]["currencies"].get("fu_lu", -1), 30, "E6-S4 本地更新取本地")
    # 版本优先于 ts
    lv = {"meta":{"schema_version":1,"last_write_ts":999,"checksum":"x"},"data":{}}
    cv = {"meta":{"schema_version":2,"last_write_ts":1,"checksum":"y"},"data":{}}
    eq(Cloud.resolve_conflict(lv, cv), 2, "E6-S4 云版本更高取云(版本优先ts)")
    # delta < 50KB
    normal = _make_save(100, 1)
    check(Cloud.is_delta_within_limit(normal), "E6-S4 普通存档<50KB")
    # E6-S4 AC3 同步延迟 mock < 2s
    check(Cloud.mock_sync_latency() < 2000.0, "E6-S4 同步延迟mock<2s")
    check(Cloud.is_online(), "E6-S4 离线优先桩永远在线不阻塞")


# ===================== E4-S6 双端适配常量（读真实文件校验） =====================
def E4_S6_suite():
    data = REAL["data/battle/battle_ui_constants.json"]
    check(data is not None, "E4-S6 配置文件可加载")
    shapes = data.get("element_shapes", {})
    for el in ["metal", "wood", "earth", "water", "fire"]:
        check(el in shapes, "E4-S6 元素%s有形状冗余" % el)
    eq(data.get("hotzone_min_px"), 44, "E4-S6 热区最小44px")
    check(data.get("shape_redundancy") is True, "E4-S6 形状冗余开启")
    eq(len(shapes), 5, "E4-S6 五行各一形状")


# ===================== 真实数据文件结构一致性（防 S1-C2 漂移） =====================
def DATA_INTEGRITY_suite():
    # element_matrix：ke/sheng 各五行构成合法双射环
    m = REAL["data/battle/element_matrix.json"]
    check(m is not None, "DATA element_matrix 可加载")
    ke = m.get("ke", {}); sheng = m.get("sheng", {})
    els = ["metal","wood","earth","water","fire"]
    check(set(ke.keys()) == set(els) and set(ke.values()) == set(els), "DATA ke 为五行双射")
    check(set(sheng.keys()) == set(els) and set(sheng.values()) == set(els), "DATA sheng 为五行双射")
    # chapters：3 章 × 9 关；Boss 关奖励含 jue_xing_shi==1
    ch = REAL["data/battle/chapters.json"]
    check(ch is not None, "DATA chapters 可加载")
    eq(len(ch.get("chapters", [])), 3, "DATA 3 章")
    for c in ch.get("chapters", []):
        eq(len(c.get("stages", [])), 9, "DATA 章%d 9关" % c.get("id"))
        for s in c.get("stages", []):
            rwd = s.get("reward", {})
            if s.get("boss", False):
                eq(rwd.get("jue_xing_shi", 0), 1, "DATA Boss关%d-%d含觉醒石1" % (c.get("id"), s.get("id")))
                eq(rwd.get("po_dan", 0), 1, "DATA Boss关%d-%d含突破丹1" % (c.get("id"), s.get("id")))
            else:
                eq(rwd.get("jue_xing_shi", 0), 0, "DATA 普通关%d-%d无觉醒石" % (c.get("id"), s.get("id")))
    # bond_combos：成员引用须存在于 shikigami_defs
    bonds = REAL["data/battle/bond_combos.json"]
    defs = REAL["data/shikigami/shikigami_defs.json"]
    sh_ids = set(defs.get("shikigami", {}).keys())
    check(bonds is not None and defs is not None, "DATA bond/shikigami 可加载")
    for gid, g in bonds.get("groups", {}).items():
        for mem in g.get("members", []):
            check(mem in sh_ids, "DATA 连携组%s成员%s存在于式神表" % (gid, mem))
    # cultivation：level_cap / passive_slots 各 6 项且 min<max
    cult = REAL["data/cultivation/cultivation_config.json"]
    check(cult is not None, "DATA cultivation 可加载")
    bt = cult.get("breakthrough", {})
    eq(len(bt.get("level_cap_per_tier", [])), 6, "DATA level_cap_per_tier 6项")
    eq(len(bt.get("passive_slots_per_tier", [])), 6, "DATA passive_slots_per_tier 6项")
    check(bt.get("attr_gain_pct_min", 0) < bt.get("attr_gain_pct_max", 1), "DATA 突破增益区间合法")
    lc = cult.get("level_curve", {})
    check(lc.get("hp_per_level_pct_min", 0) < lc.get("hp_per_level_pct_max", 1), "DATA 升级增益区间合法")
    # economy：关键货币齐全（逻辑与 boss_only 合规）
    econ = REAL["data/economy/economy_config.json"]
    check(econ is not None, "DATA economy 可加载")
    cur = econ.get("currencies", {})
    for key in ["fu_lu", "ling_qi", "po_dan", "jue_xing_shi"]:
        check(key in cur, "DATA economy 含货币%s" % key)
    check(cur.get("jue_xing_shi", {}).get("boss_only", False) is True, "DATA 觉醒石 boss_only 合规")


# ===================== 执行 =====================
if __name__ == "__main__":
    T2_suite()
    T6_suite()
    T7_suite()
    E4_S5_suite()
    E6_S4_suite()
    E4_S6_suite()
    DATA_INTEGRITY_suite()
    passed = sum(1 for ok, _ in _results if ok)
    failed = len(_results) - passed
    print("=" * 64)
    print("S2 纯逻辑验证（Python 移植）— T2 / T6 / T7 / E4-S5 / E6-S4 / E4-S6 / 数据一致性")
    print("=" * 64)
    for ok, msg in _results:
        if not ok:
            print("  [FAIL] " + msg)
    print("-" * 64)
    print("总计断言: %d | 通过: %d | 失败: %d" % (len(_results), passed, failed))
    print("S2 算法层判定: %s" % ("PASS ✅" if failed == 0 else "FAIL ❌"))
    print("=" * 64)
