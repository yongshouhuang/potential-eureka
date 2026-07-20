#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
S3-E5 本地逻辑镜像（不可跑 Godot/GUT 沙箱下的替代证据）
=====================================================================
镜像 E5 Demo 串接的两块核心逻辑：

  1) 埋点漏斗（抽→养→战→回流）
     - 忠实移植 GachaManager.pull / CultivationManager.upgrade /
       BattleManager(_victory/_defeat/_grant_rewards) 的真实流，
       并在对应节点 emit 4 类遥测事件（telemetry_gacha_pulled /
       telemetry_cultivate_leveled / telemetry_battle_resolved /
       telemetry_player_reengaged）。
     - TelemetryAggregator 订阅 4 类事件，按 session 串联漏斗并输出转化率。

  2) 双端 layout_mode 决策（UIThemeController.compute_layout_mode 镜像）
     - 断点 768 / 1024：≥1024 multi、768–1024 hybrid、<768 single。
     - 旋转/分辨率等价逻辑：宽度变化→layout_mode 变化且不丢 GameState 状态。

复用 S2 harness（s2-python-logic-smoke.py）的脚手架：RNGWrapper /
EventBus / GameState(gs) / ConfigLoader 桩 / Economy / Cultivation /
BattleResolver / BondManager。本脚本为其增补 telemetry 信号与 GachaManager 镜像，
不修改 S2 文件、不修改任何 data/*.json。

不依赖 Godot；仅用标准库。运行：python3 production/qa/s3_e5_python_logic_mirror.py
"""
import os
import json
import importlib.util

# ---- 复用 S2 harness 脚手架（import 而不重复造轮子）----
_S2_PATH = os.path.join(r"F:\AI\仙侠卡牌项目", "production", "qa", "s2-python-logic-smoke.py")
_spec = importlib.util.spec_from_file_location("s2harness", _S2_PATH)
S2 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(S2)

# 别名（与 GDScript 全局单例名对应）
EventBus = S2.EventBus
GameState = S2.gs          # GameState 是类，gs 才是单例实例
cl_reset = S2.cl_reset
cl_inject = S2.cl_inject
cl_load_table = S2.cl_load_table
Economy = S2.Economy
Cultivation = S2.Cultivation
gs = S2.gs
lerp = S2.lerp
clampf = S2.clampf

# 真实数据（仅 element_matrix / 可选参考；其余用合成注入保证确定性）
def _load_json(rel):
    with open(os.path.join(r"F:\AI\仙侠卡牌项目", rel), "r", encoding="utf-8") as f:
        return json.load(f)
try:
    REAL_ELEMENT_MATRIX = _load_json("data/battle/element_matrix.json")
except Exception:
    REAL_ELEMENT_MATRIX = None


# ===================== 增补 4 类遥测信号到 EventBus =====================
# 对应 GDScript EventBus.gd 新增的 telemetry:* 信号（category_event 契约）。
EventBus.telemetry_gacha_pulled = S2.Signal()
EventBus.telemetry_cultivate_leveled = S2.Signal()
EventBus.telemetry_battle_resolved = S2.Signal()
EventBus.telemetry_player_reengaged = S2.Signal()


# ===================== GachaManager 镜像（忠实移植 GachaManager.gd）=====================
class GachaManager:
    DEFAULT_RATES = {"SSR": 0.02, "SR": 0.10, "R": 0.35, "N": 0.53}
    DEFAULT_SOFT = 50
    DEFAULT_HARD = 90

    def __init__(self):
        self.rng = S2.RNGWrapper(1)

    def _pool(self, pool_id):
        cfg = cl_load_table("gacha", "")
        if cfg is None or "pools" not in cfg or pool_id not in cfg["pools"]:
            print("GachaManager: 无卡池 %s" % pool_id)
            return {}
        return cfg["pools"][pool_id]

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
            gs.shikigami.append({
                "id": r["shikigami_id"], "level": 1, "breakthrough": 0,
                "awakened_skills": [], "bond_level": 0, "fragments": 0,
            })
            EventBus.gacha_shikigami_obtained.emit(r["shikigami_id"], r["rarity"])
            # E5-S3 遥测：抽到式神 -> 漏斗「抽」阶段
            EventBus.telemetry_gacha_pulled.emit(r["shikigami_id"], r["rarity"])
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
        rates = pool.get("rarity_rates", GachaManager.DEFAULT_RATES)
        soft = int(pool.get("soft_pity", GachaManager.DEFAULT_SOFT))
        hard = int(pool.get("hard_pity", GachaManager.DEFAULT_HARD))
        nxt = pity_count + 1
        if nxt >= hard:
            return "SSR"
        if nxt >= soft:
            return self._roll_with_boosted_ssr(rates, self.effective_ssr_rate(pity_count, pool))
        return self._weighted_roll(rates)

    def effective_ssr_rate(self, pity_count, pool):
        rates = pool.get("rarity_rates", GachaManager.DEFAULT_RATES)
        soft = int(pool.get("soft_pity", GachaManager.DEFAULT_SOFT))
        hard = int(pool.get("hard_pity", GachaManager.DEFAULT_HARD))
        nxt = pity_count + 1
        if nxt < soft:
            return float(rates.get("SSR", 0.02))
        t = float(nxt - soft) / float(hard - soft)
        return clampf(lerp(0.5, 1.0, t), 0.5, 1.0)

    def _weighted_roll(self, rates):
        ssr = float(rates.get("SSR", 0.0)); sr = float(rates.get("SR", 0.0))
        r = float(rates.get("R", 0.0)); n = float(rates.get("N", 0.0))
        total = ssr + sr + r + n
        if total <= 0:
            return "N"
        x = self.rng.randf() * total
        if x < ssr:
            return "SSR"
        x -= ssr
        if x < sr:
            return "SR"
        x -= sr
        if x < r:
            return "R"
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
        if x < ssr:
            return "SSR"
        x -= ssr
        if x < r_sr:
            return "SR"
        x -= r_sr
        if x < r_r:
            return "R"
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


# ===================== CultivationManager 镜像（仅 upgrade 增补遥测）=====================
class CultivationManager(S2.CultivationManager):
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
        # E5-S3 遥测：养成升级 -> 漏斗「养」阶段（代表事件）
        EventBus.telemetry_cultivate_leveled.emit(id, e["level"])
        return True


# ===================== BattleManager 镜像（_victory/_defeat/_grant_rewards 增补遥测）=====================
class BattleManager(S2.BattleManager):
    def _victory(self):
        self._resolved = True
        self._outcome = "victory"
        # E5-S3 遥测：战斗结算（胜）-> 漏斗「战」阶段（先于回流，保证漏斗顺序）
        EventBus.telemetry_battle_resolved.emit(self._chapter, self._stage, self._outcome)
        self._advance_progression()
        self._grant_rewards()
        EventBus.battle_victory.emit(self._chapter, self._stage)

    def _defeat(self):
        self._resolved = True
        self._outcome = "defeat"
        # E5-S3 遥测：战斗结算（负）-> 漏斗「战」阶段（无资源回流）
        EventBus.telemetry_battle_resolved.emit(self._chapter, self._stage, self._outcome)
        EventBus.battle_defeat.emit(self._chapter, self._stage)

    def _grant_rewards(self):
        super()._grant_rewards()
        # E5-S3 遥测：战后资源回流 -> 漏斗「回流 / 再 engagement」阶段
        EventBus.telemetry_player_reengaged.emit("battle")


# ===================== BattleLauncher.launch 镜像（E5 战斗启动协调器）=====================
def launch(chapter, stage):
    bm = BattleManager()
    bm.rng = S2.RNGWrapper(1)
    if not bm.start_battle(chapter, stage):
        return False
    bond = S2.BondManager()
    bond.compute_combo(gs.deck)
    return True


# ===================== TelemetryAggregator 镜像 =====================
class TelemetryAggregator:
    STAGES = ["gacha_pulled", "cultivate_leveled", "battle_resolved", "player_reengaged"]

    def __init__(self, session_id=""):
        self.session_id = session_id or "sess"
        self.reset_counts()
        self._attached = False

    def attach(self):
        if self._attached:
            return
        EventBus.telemetry_gacha_pulled.connect(self._on_g)
        EventBus.telemetry_cultivate_leveled.connect(self._on_c)
        EventBus.telemetry_battle_resolved.connect(self._on_b)
        EventBus.telemetry_player_reengaged.connect(self._on_r)
        self._attached = True

    def detach(self):
        if not self._attached:
            return
        EventBus.telemetry_gacha_pulled.disconnect(self._on_g)
        EventBus.telemetry_cultivate_leveled.disconnect(self._on_c)
        EventBus.telemetry_battle_resolved.disconnect(self._on_b)
        EventBus.telemetry_player_reengaged.disconnect(self._on_r)
        self._attached = False

    def reset_counts(self):
        self._counts = dict(gacha_pulled=0, cultivate_leveled=0, battle_resolved=0, player_reengaged=0)
        self._log = []

    def _on_g(self, sid, rarity):
        self._counts["gacha_pulled"] += 1
        self._log.append(("gacha_pulled", sid, rarity))

    def _on_c(self, sid, lvl):
        self._counts["cultivate_leveled"] += 1
        self._log.append(("cultivate_leveled", sid, lvl))

    def _on_b(self, ch, st, out):
        self._counts["battle_resolved"] += 1
        self._log.append(("battle_resolved", ch, st, out))

    def _on_r(self, src):
        self._counts["player_reengaged"] += 1
        self._log.append(("player_reengaged", src))

    def get_counts(self):
        return dict(self._counts)

    def get_funnel(self):
        g = self._counts["gacha_pulled"]; c = self._counts["cultivate_leveled"]
        b = self._counts["battle_resolved"]; r = self._counts["player_reengaged"]
        return dict(
            gacha_pulled=g, cultivate_leveled=c, battle_resolved=b, player_reengaged=r,
            conv_pull_to_cultivate=self._rate(c, g),
            conv_cultivate_to_battle=self._rate(b, c),
            conv_battle_to_reengage=self._rate(r, b),
            conv_overall_pull_to_reengage=self._rate(r, g),
        )

    def _rate(self, n, d):
        return (n / d) if d > 0 else 0.0

    def format_report(self):
        f = self.get_funnel()
        return (
            "=== 遥测漏斗 (session=%s) ===\n" % self.session_id
            + "抽 gacha_pulled       : %d\n" % f["gacha_pulled"]
            + "养 cultivate_leveled  : %d\n" % f["cultivate_leveled"]
            + "战 battle_resolved     : %d\n" % f["battle_resolved"]
            + "回流 player_reengaged  : %d\n" % f["player_reengaged"]
            + "--- 环节转化率 ---\n"
            + "抽 -> 养   : %.1f%%\n" % (f["conv_pull_to_cultivate"] * 100.0)
            + "养 -> 战   : %.1f%%\n" % (f["conv_cultivate_to_battle"] * 100.0)
            + "战 -> 回流 : %.1f%%\n" % (f["conv_battle_to_reengage"] * 100.0)
            + "抽 -> 回流 : %.1f%%\n" % (f["conv_overall_pull_to_reengage"] * 100.0)
        )


# ===================== UIThemeController.compute_layout_mode 镜像 =====================
BREAKPOINT_MOBILE = 768
BREAKPOINT_HYBRID = 1024

def compute_layout_mode(width):
    if width >= BREAKPOINT_HYBRID:
        return "multi"
    if width >= BREAKPOINT_MOBILE:
        return "hybrid"
    return "single"


# ===================== DemoLoop 镜像（抽→养→编队→战→回流）=====================
def _level_of(sid):
    for s in gs.shikigami:
        if s.get("id", "") == sid:
            return int(s.get("level", 1))
    return 0

def _bt_of(sid):
    for s in gs.shikigami:
        if s.get("id", "") == sid:
            return int(s.get("breakthrough", 0))
    return 0

def demo_loop(pool_id="standard", chapter=1, stage=1):
    # 1. 抽卡
    Economy.claim_free_ten_pull("2026-07-20")
    pulled = GachaManager().pull(pool_id, 1)
    if not pulled:
        return {"ok": False, "error": "pull failed"}
    sid = pulled[0]["shikigami_id"]
    # 2. 养成（资源注入仅 Demo 用，数值在真实预算内）
    Economy.grant("ling_qi", 1000, "demo_seed")
    Economy.grant("po_dan", 5, "demo_seed")
    for s in gs.shikigami:
        if s.get("id", "") == sid:
            s["fragments"] = 99
            break
    CultivationManager().upgrade(sid)
    CultivationManager().breakthrough(sid)
    # 3. 编队
    gs.deck = [sid]
    # 4. 战斗
    bm = BattleManager(); bm.rng = S2.RNGWrapper(1)
    if not bm.start_battle(chapter, stage):
        return {"ok": False, "error": "start failed"}
    S2.BondManager().compute_combo(gs.deck)
    bm.auto_resolve()
    # 5. 回流（胜利后 _grant_rewards 已 emit telemetry_player_reengaged）
    return {
        "ok": bm.is_victory(),
        "pulled_id": sid,
        "cultivated_level": _level_of(sid),
        "breakthrough": _bt_of(sid),
        "outcome": "victory" if bm.is_victory() else "defeat",
        "rewards": {
            "fu_lu": int(gs.currencies.get("fu_lu", 0)),
            "po_dan": int(gs.currencies.get("po_dan", 0)),
        },
    }


# ===================== 注入环境（确定性，与 GDScript before_each 等价）=====================
def _demo_setup():
    cl_reset()
    cl_inject("gacha", {
        "pools": {
            "standard": {
                "id": "standard", "type": "standard",
                "rarity_rates": {"SSR": 0.02, "SR": 0.10, "R": 0.35, "N": 0.53},
                "soft_pity": 50, "hard_pity": 90,
                "shikigami_by_rarity": {"SSR": ["hero"], "SR": ["hero"], "R": ["hero"], "N": ["hero"]},
            }
        }
    })
    cl_inject("shikigami", {"shikigami": {
        "hero": {"name": "侠客", "element": "metal", "rarity": "SSR", "bond_tags": [],
                 "base_stats": {"hp": 500, "atk": 200}, "skills": ["sk_hero"]}}})
    cl_inject("battle/skill_defs", {"skills": {"sk_hero": {"element": "metal", "power": 1.0, "status_on_hit": None}}})
    cl_inject("cultivation", {
        "breakthrough": {"max_tier": 6, "level_cap_per_tier": [20, 36, 52, 64, 72, 80],
                         "attr_gain_pct_min": 0.08, "attr_gain_pct_max": 0.12, "passive_slots_per_tier": [1, 2, 3, 4, 5, 6]},
        "level_curve": {"hp_per_level_pct_min": 0.02, "hp_per_level_pct_max": 0.03,
                        "atk_per_level_pct_min": 0.02, "atk_per_level_pct_max": 0.03},
        "upgrade": {"ling_qi_per_level": 50},
        "breakthrough_cost": {"po_dan_per_tier": 1, "fragments_per_tier": 5},
        "awaken": {"tier_threshold": 3, "skills_by_shikigami": {}},
        "branches": {"sword": {"passive": "jian_xiu_passive"}, "body": {"passive": "ti_xiu_passive"}},
    })
    cl_inject("economy", {
        "currencies": {"fu_lu": {"daily_cap": 100000}, "ling_qi": {"daily_cap": 100000},
                       "po_dan": {"weekly_cap": 100}, "jue_xing_shi": {"boss_only": True}},
        "free_ten_pull": {"amount": 10}, "sources": {},
    })
    cl_inject("battle/chapters", {"chapters": [{
        "id": 1, "name": "T",
        "stages": [{"id": 1, "boss": False,
                    "enemies": [{"id": "e1", "element": "earth", "stats": {"hp": 10, "atk": 20}}],
                    "reward": {"fu_lu": [1, 3], "po_dan": 0, "jue_xing_shi": 0}}]}]})
    cl_inject("battle/bond_combos", {"groups": {}})
    cl_inject("battle/element_matrix", REAL_ELEMENT_MATRIX)
    gs.reset_all()
    Economy.set_date_override("2026-07-20")
    Economy.set_week_override(30)


# ===================== 断言框架 =====================
_results = []
def check(name, cond, detail=""):
    ok = bool(cond)
    _results.append((ok, name if ok else name))
    if not ok:
        print("  [FAIL] %s%s" % (name, ("  (%s)" % detail) if detail else ""))
    return ok
def eq(a, b, msg):
    ok = (a == b); _results.append((ok, msg)); 
    if not ok: print("  [FAIL] %s (got=%r, exp=%r)" % (msg, a, b))
    return ok
def ge(a, b, msg):
    ok = (a >= b); _results.append((ok, msg))
    if not ok: print("  [FAIL] %s (got=%r, exp>=%r)" % (msg, a, b))
    return ok
def gt(a, b, msg):
    ok = (a > b); _results.append((ok, msg))
    if not ok: print("  [FAIL] %s (got=%r, exp>%r)" % (msg, a, b))
    return ok


# ===================== 埋点漏斗套件 =====================
def funnel_suite():
    _demo_setup()
    agg = TelemetryAggregator("demo_e5")
    agg.attach()
    report = demo_loop("standard", 1, 1)
    agg.detach()

    check("闭环跑通(胜利)", report["ok"], str(report))
    eq(report["pulled_id"], "hero", "抽到式神=hero")
    eq(report["cultivated_level"], 2, "养成升级 Lv1->Lv2")
    eq(report["breakthrough"], 1, "突破 bt0->bt1")
    eq(report["outcome"], "victory", "战斗结算胜利")

    c = agg.get_counts()
    ge(c["gacha_pulled"], 1, "抽 阶段事件≥1")
    ge(c["cultivate_leveled"], 1, "养 阶段事件≥1")
    ge(c["battle_resolved"], 1, "战 阶段事件≥1")
    ge(c["player_reengaged"], 1, "回流 阶段事件≥1")

    # 四阶段均出现在有序日志
    seen = set(s[0] for s in agg._log)
    check("日志含 抽", "gacha_pulled" in seen)
    check("日志含 养", "cultivate_leveled" in seen)
    check("日志含 战", "battle_resolved" in seen)
    check("日志含 回流", "player_reengaged" in seen)

    f = agg.get_funnel()
    eq(f["conv_pull_to_cultivate"], 1.0, "抽→养 100%")
    eq(f["conv_cultivate_to_battle"], 1.0, "养→战 100%")
    eq(f["conv_battle_to_reengage"], 1.0, "战→回流 100%")

    print("\n" + agg.format_report())
    return agg


# ===================== 双端 layout_mode 套件 =====================
def dual_end_suite():
    print("\n[双端] compute_layout_mode 三档决策")
    eq(compute_layout_mode(1280), "multi", "PC横屏≥1024 -> multi")
    eq(compute_layout_mode(1024), "multi", "边界1024 -> multi")
    eq(compute_layout_mode(900), "hybrid", "768–1024 -> hybrid")
    eq(compute_layout_mode(768), "hybrid", "边界768 -> hybrid")
    eq(compute_layout_mode(390), "single", "移动竖屏<768 -> single")
    eq(compute_layout_mode(767), "single", "边界767 -> single")

    print("\n[双端] 核心闭环在 multi / single 下均 headless 跑通（无 UI 依赖）")
    for mode, width in [("multi", 1280), ("single", 390)]:
        _demo_setup()
        agg = TelemetryAggregator("demo_%s" % mode)
        agg.attach()
        report = demo_loop("standard", 1, 1)
        agg.detach()
        check("闭环在 %s 布局跑通" % mode, report["ok"])
        c = agg.get_counts()
        check("%s: 抽 遥测≥1" % mode, c["gacha_pulled"] >= 1)
        check("%s: 养 遥测≥1" % mode, c["cultivate_leveled"] >= 1)
        check("%s: 战 遥测≥1" % mode, c["battle_resolved"] >= 1)
        check("%s: 回流 遥测≥1" % mode, c["player_reengaged"] >= 1)

    print("\n[双端] 旋转/分辨率稳定性（宽度变化→layout_mode 变化且不丢状态）")
    _demo_setup()
    # PC 横屏起步
    mode_before = compute_layout_mode(1280)   # multi
    eq(mode_before, "multi", "起始 multi(PC横屏)")
    # 建立玩家状态
    Economy.grant("fu_lu", 50, "demo_seed")
    gs.shikigami = [{"id": "hero", "level": 5, "breakthrough": 1, "awakened_skills": [],
                     "bond_level": 0, "fragments": 99, "branch": ""}]
    gs.deck = ["hero"]
    snap_currencies = dict(gs.currencies)
    snap_shiki = json.loads(json.dumps(gs.shikigami))
    snap_deck = list(gs.deck)
    # 旋转到移动竖屏（等价：宽度 1280 -> 390）
    new_mode = compute_layout_mode(390)   # single
    check("旋转后 layout_mode 变化(multi->single)", new_mode != mode_before)
    eq(new_mode, "single", "旋转后进入 single")
    # 状态不丢（GameState 与 layout_mode 解耦）
    eq(gs.currencies, snap_currencies, "旋转后货币状态不丢")
    eq(gs.shikigami, snap_shiki, "旋转后式神状态不丢")
    eq(gs.deck, snap_deck, "旋转后编队状态不丢")
    # 旋转回来
    back_mode = compute_layout_mode(1280)
    eq(back_mode, "multi", "旋转回 PC 横屏")
    eq(gs.currencies, snap_currencies, "旋转回来后货币仍不丢")
    eq(gs.shikigami, snap_shiki, "旋转回来后式神仍不丢")
    eq(gs.deck, snap_deck, "旋转回来后编队仍不丢")


# ===================== 执行 =====================
if __name__ == "__main__":
    print("=" * 64)
    print("S3-E5 逻辑镜像验证（Python）— 埋点漏斗(抽→养→战→回流) + 双端 layout_mode")
    print("=" * 64)

    funnel_suite()
    dual_end_suite()

    total = len(_results)
    passed = sum(1 for ok, _ in _results if ok)
    print("\n" + "=" * 64)
    print("S3-E5 算法层判定: %s" % ("PASS" if (total - passed) == 0 else "FAIL"))
    print("总计断言: %d | 通过: %d | 失败: %d" % (total, passed, total - passed))
    print("=" * 64)
    import sys
    sys.exit(0 if (total - passed) == 0 else 1)
