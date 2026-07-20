# S3 纯逻辑验证脚本（Python 镜像）—— B-1 灼烧状态 + B-3 玩家选技
# ===============================================================
# 背景：S2 用 s2-python-logic-smoke.py 跑过 155/155（纯 Python 镜像战斗逻辑，
#       未覆盖本次新增的 B-1 状态系统 / B-3 玩家选技）。本脚本为 S3 的「验证补齐」，
#       把 B-1 / B-3 的新逻辑忠实移植到 Python 并加断言，作为本批次唯一可在沙箱实跑的
#       验证证据。
#
# 重要边界（同 S2）：
#  - 本脚本验证「算法/数值正确性」，不验证 Godot API 接线、信号树、场景加载。
#  - 数值一律取 GDD 区间确定性中点（如 burn dot = stacks × 0.03 × max_hp）。
#  - 复用 S2 harness 的脚手架（RNGWrapper / EventBus / GameState / ConfigLoader 桩 /
#    CultivationManager / BattleResolver / EconomyManager），仅新增本批次逻辑：
#      * StatusManager 镜像（B-1）
#      * BattleManager.step(action) 镜像（B-3，含 skill 选择 / 觉醒触发 / 分支被动 / qi 门控）
#  - 只读：所有 data/*.json 仅被本脚本读取用于断言，绝不被修改。
#    已实现的 GDScript 逻辑（StatusManager.gd / BattleManager.gd）同样只读，不改动。
# ===============================================================

import os
import json
import importlib.util

# ---- 复用 S2 harness 脚手架（import 而不重复造轮子）----
_S2_PATH = os.path.join(r"F:\AI\仙侠卡牌项目", "production", "qa", "s2-python-logic-smoke.py")
_spec = importlib.util.spec_from_file_location("s2harness", _S2_PATH)
S2 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(S2)

RNGWrapper = S2.RNGWrapper
EventBus = S2.EventBus
GameState = S2.gs  # S2 的全局单例实例（注意：GameState 是类，gs 才是实例）
cl_reset = S2.cl_reset
cl_inject = S2.cl_inject
cl_load_table = S2.cl_load_table
Economy = S2.Economy
Cultivation = S2.Cultivation
BattleResolver = S2.BattleResolver
BondManager = S2.BondManager
approx = S2.approx
_clear_battle_signals = S2._clear_battle_signals
BASE = S2.BASE

# 真实数据（status_config / skill_defs 不在 S2 的 REAL 列表里，这里直接读）
def _load_json(rel):
    with open(os.path.join(BASE, rel), "r", encoding="utf-8") as f:
        return json.load(f)

REAL_STATUS = _load_json("data/battle/status_config.json")
REAL_SKILLS = _load_json("data/battle/skill_defs.json")
REAL_CULT = S2.REAL["data/cultivation/cultivation_config.json"]
REAL_SHIKI = S2.REAL["data/shikigami/shikigami_defs.json"]
REAL_MATRIX = S2.REAL["data/battle/element_matrix.json"]
REAL_BONDS = _load_json("data/battle/bond_combos.json")


# ===================== 断言框架 =====================
_results = []
def check(cond, msg):
    _results.append((bool(cond), msg)); return bool(cond)
def eq(a, b, msg):
    ok = (a == b); _results.append((ok, "%s (got=%r, exp=%r)" % (msg, a, b))); return ok
def ge(a, b, msg):
    ok = (a >= b); _results.append((ok, "%s (got=%r, exp>=%r)" % (msg, a, b))); return ok
def gt(a, b, msg):
    ok = (a > b); _results.append((ok, "%s (got=%r, exp>%r)" % (msg, a, b))); return ok


# ===================== StatusManager 镜像（B-1）=====================
# 忠实移植 scripts/autoload/StatusManager.gd：
#  - apply_status：叠层封顶（max_stacks，水克火可收紧为 1）、duration、五行调制（vs_<element>）
#  - tick_statuses：结算 DoT = stacks × mag × elem_dot_mult × max_hp，不读 _bond_bonus
#  - target_dmg_mult / actor_dmg_mult：仅作用于直接打击
class StatusManager:
    def __init__(self):
        self._units = {}
        self._statuses = {}

    def _config(self):
        return cl_load_table("battle/status_config", "")

    def register_unit(self, unit_id, element, max_hp):
        self._units[unit_id] = {"element": element, "max_hp": max_hp}
        if unit_id not in self._statuses:
            self._statuses[unit_id] = []

    def unregister_all(self):
        self._statuses.clear()
        self._units.clear()

    def get_statuses(self, unit_id):
        return self._statuses.get(unit_id, [])

    def get_stacks(self, unit_id, type_):
        for s in self._statuses.get(unit_id, []):
            if s.get("type", "") == type_:
                return int(s.get("stacks", 0))
        return 0

    def apply_status(self, target_id, spec, src_element):
        type_ = spec.get("type", "")
        if type_ == "":
            return
        cfg = self._config().get("status", {}).get(type_, {})
        if not cfg:
            return
        unit = self._units.get(target_id, {})
        target_elem = unit.get("element", "")

        # 目标五行调制（通用 vs_<element> 覆盖）
        max_stacks = int(cfg.get("max_stacks", 3))
        duration = int(spec.get("duration", cfg.get("duration", 3)))
        elem_dot_mult = 1.0
        for key in cfg.keys():
            if key.startswith("vs_"):
                elem = key[3:]
                v = cfg[key]
                if target_elem == elem:
                    if "max_stacks" in v:
                        max_stacks = int(v["max_stacks"])
                    if "duration" in v:
                        duration = int(v["duration"])
                    if "dot_mult" in v:
                        elem_dot_mult = float(v["dot_mult"])

        # 每 tick 系数（确定性中点）
        mag = 0.0
        if "dot_pct_per_stack_min" in cfg:
            mag = 0.5 * (float(cfg["dot_pct_per_stack_min"]) + float(cfg["dot_pct_per_stack_max"]))
        elif "pct_per_stack" in cfg:
            mag = float(cfg["pct_per_stack"])
        elif "dmg_per_stack" in cfg:
            mag = float(cfg["dmg_per_stack"])

        existing = {}
        found = False
        for s in self._statuses.get(target_id, []):
            if s.get("type", "") == type_:
                existing = s
                found = True
                break
        if not found:
            existing = {"type": type_, "stacks": 0, "turns_left": 0,
                        "src_element": src_element, "mag": mag, "elem_dot_mult": elem_dot_mult}
            if target_id not in self._statuses:
                self._statuses[target_id] = []
            self._statuses[target_id].append(existing)

        add = int(spec.get("stacks", 1))
        existing["stacks"] = min(int(existing.get("stacks", 0)) + add, max_stacks)
        existing["turns_left"] = duration
        existing["mag"] = mag
        existing["elem_dot_mult"] = elem_dot_mult

    def tick_statuses(self, unit_id):
        total = 0
        remaining = []
        max_hp = int(self._units.get(unit_id, {}).get("max_hp", 0))
        for s in self._statuses.get(unit_id, []):
            cfg = self._config().get("status", {}).get(s.get("type", ""), {})
            if cfg.get("kind", "") == "dot":
                dot_pct = float(s.get("mag", 0.0))
                mult = float(s.get("elem_dot_mult", 1.0))
                total += int(round(float(s.get("stacks", 0)) * dot_pct * mult * float(max_hp)))
            s["turns_left"] = int(s.get("turns_left", 0)) - 1
            if int(s.get("turns_left", 0)) > 0:
                remaining.append(s)
        self._statuses[unit_id] = remaining
        return total

    def target_dmg_mult(self, target_id):
        mult = 1.0
        for s in self._statuses.get(target_id, []):
            cfg = self._config().get("status", {}).get(s.get("type", ""), {})
            if cfg.get("kind", "") == "debuff":
                mult *= (1.0 - float(s.get("stacks", 0)) * float(cfg.get("pct_per_stack", 0.0)))
        return mult

    def actor_dmg_mult(self, actor_id):
        mult = 1.0
        for s in self._statuses.get(actor_id, []):
            cfg = self._config().get("status", {}).get(s.get("type", ""), {})
            if cfg.get("kind", "") == "selfbuff":
                mult *= (1.0 + float(s.get("stacks", 0)) * float(cfg.get("dmg_per_stack", 0.0)))
        return mult


# ===================== BattleManager 镜像（B-3）=====================
# 忠实移植 scripts/autoload/BattleManager.gd 的 step(action)：
#  - action = {"skill_id", "target_id"} 驱动；默认自动（气足且有觉醒则放觉醒）
#  - qi 门控：觉醒技需耗 1，气不足降级基础技（skill_gated=True）
#  - 命中触发 status_on_hit（觉醒改写机制）
#  - 分支被动（branch_dmg_mult）经 get_final_unit 自动入算直接伤害
#  - _bond_bonus 仅缩放直接打击，不缩放 DoT（正交红线）
class BattleManager:
    def __init__(self, status_mgr=None):
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
        self._status = status_mgr if status_mgr is not None else StatusManager()
        EventBus.bond_combo.connect(self._on_bond_combo)

    def _on_bond_combo(self, _gid, bonus):
        self._bond_bonus = bonus

    def _chapters(self):
        return cl_load_table("battle/chapters", "")
    def _skill_defs(self):
        return cl_load_table("battle/skill_defs", "")
    def _skill_def(self, sid):
        return self._skill_defs().get("skills", {}).get(sid, {})

    def start_battle(self, chapter, stage):
        self._resolved = False
        self._outcome = ""
        self._bond_bonus = 0.0
        self._cursor = 0
        self._chapter = chapter
        self._stage = stage
        ch = self._find_chapter(chapter)
        if not ch:
            return False
        self._stage_def = self._find_stage(ch, stage)
        if not self._stage_def:
            return False
        self._build_players()
        self._build_enemies()
        if not self._players:
            return False
        self._build_order()
        self._register_status_units()
        EventBus.battle_started.emit(chapter, stage)
        return True

    def _find_chapter(self, chapter):
        for c in self._chapters().get("chapters", []):
            if int(c.get("id", 0)) == chapter:
                return c
        return {}
    def _find_stage(self, ch, stage):
        for s in ch.get("stages", []):
            if int(s.get("id", 0)) == stage:
                return s
        return {}

    def _build_players(self):
        self._players = []
        for entry in GameState.deck:
            sid = str(entry)
            fu = _final_unit(sid)
            if not fu:
                continue
            hp_mult = float(fu.get("branch_hp_mult", 0.0))
            max_hp = int(round(float(fu.get("final_stats", {}).get("hp", 0)) * (1.0 + hp_mult)))
            self._players.append({
                "id": sid, "side": "player", "element": fu.get("element", ""),
                "atk": int(fu.get("final_stats", {}).get("atk", 0)),
                "hp": max_hp, "max_hp": max_hp,
                "skills": fu.get("skills", []),
                "awakened_skills": fu.get("awakened_skills", []),
                "branch_dmg_mult": fu.get("branch_dmg_mult", 0.0),
                "bond_tags": fu.get("bond_tags", []),
                "qi": 0, "qi_max": 3,
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
                "skills": [], "awakened_skills": [],
                "branch_dmg_mult": 0.0, "bond_tags": [],
                "qi": 0, "qi_max": 3,
            })

    def _build_order(self):
        self._actors = self._players + self._enemies
        idx = list(range(len(self._actors)))
        idx.sort(key=lambda a: (-int(self._actors[a].get("atk", 0)),
                                0 if self._actors[a].get("side", "") == "player" else 1))
        self._order = idx

    def _register_status_units(self):
        self._status.unregister_all()
        for a in self._actors:
            self._status.register_unit(a.get("id", ""), a.get("element", ""), int(a.get("max_hp", 0)))

    def step(self, action=None):
        if action is None:
            action = {}
        if self._resolved:
            return {"done": True, "outcome": self._outcome}
        if not self._order:
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

        actor_id = actor.get("id", "")

        # 回合开始：结算 DoT（正交——不乘 _bond_bonus）
        dot = self._status.tick_statuses(actor_id)
        if dot > 0:
            actor["hp"] = int(actor.get("hp", 0)) - dot
            EventBus.battle_turn_resolved.emit(actor_id, actor_id, dot, "STATUS")
            if int(actor.get("hp", 0)) <= 0:
                actor["hp"] = 0
                self._resolve_outcome()
                return {"done": self._resolved, "actor_id": actor_id, "target_id": actor_id,
                        "damage": dot, "relation": "STATUS", "outcome": self._outcome}

        active = self._active_skills(actor)
        skill_id = ""
        gated = False
        if action and "skill_id" in action and action["skill_id"] in active:
            skill_id = action["skill_id"]
            if self._is_awakened(actor, skill_id) and int(actor.get("qi", 0)) < self._awaken_cost():
                skill_id = active[0]
                gated = True
        elif len(active) > 1 and int(actor.get("qi", 0)) >= self._awaken_cost():
            skill_id = active[1]
        else:
            skill_id = active[0] if active else ""

        target = self._resolve_target(actor, action)
        if target is None:
            self._resolve_outcome()
            return {"done": True, "outcome": self._outcome}

        sd = self._skill_def(skill_id)
        if not sd:
            sd = {"element": actor.get("element", ""), "power": 1.0, "status_on_hit": None}
        target_id = target.get("id", "")
        skill_elem = sd.get("element", actor.get("element", ""))
        power = float(sd.get("power", 1.0))

        atk_dict = {"element": actor.get("element", ""), "atk": int(actor.get("atk", 0))}
        def_dict = {"element": target.get("element", ""), "atk": int(target.get("atk", 0))}
        res = self._resolver.resolve_damage(atk_dict, def_dict, {"element": skill_elem, "power": power})
        dmg = int(res.get("damage", 0))

        # 直接伤害修正（仅此处；_bond_bonus 仅缩放直接打击）
        dmg = int(round(float(dmg) * (1.0 + float(actor.get("branch_dmg_mult", 0.0)))
                       * self._status.target_dmg_mult(target_id) * self._status.actor_dmg_mult(actor_id)))
        if actor.get("side", "") == "player" and self._bond_bonus > 0.0:
            dmg = int(round(float(dmg) * (1.0 + self._bond_bonus)))

        target["hp"] = int(target.get("hp", 0)) - dmg

        status_on_hit = sd.get("status_on_hit", None)
        if status_on_hit is not None:
            self._status.apply_status(target_id, status_on_hit, skill_elem)

        relation = res.get("relation", "NEUTRAL")
        if actor.get("side", "") == "player" and relation == "ADVANTAGE":
            EventBus.battle_element_advantage.emit(actor_id, target_id, float(res.get("multiplier", 1.0)))
        EventBus.battle_turn_resolved.emit(actor_id, target_id, dmg, relation)

        defeated = int(target.get("hp", 0)) <= 0
        if defeated:
            target["hp"] = 0
        actor["qi"] = min(int(actor.get("qi", 0)) + 1, int(actor.get("qi_max", 3)))
        self._resolve_outcome()
        return {
            "done": self._resolved, "actor_id": actor_id, "target_id": target_id,
            "skill_id": skill_id, "skill_gated": gated, "damage": dmg,
            "relation": relation, "defeated": defeated, "outcome": self._outcome,
        }

    def _active_skills(self, actor):
        out = []
        defs = self._skill_defs().get("skills", {})
        for s in actor.get("skills", []):
            if s in defs:
                out.append(s)
        return out

    def _is_awakened(self, actor, skill_id):
        if skill_id in actor.get("awakened_skills", []):
            return True
        sd = self._skill_def(skill_id)
        return "status_on_hit" in sd and sd["status_on_hit"] is not None

    def _awaken_cost(self):
        return 1

    def _resolve_target(self, actor, action):
        foes = self._enemies if actor.get("side", "") == "player" else self._players
        if action and "target_id" in action:
            tid = action["target_id"]
            for u in foes:
                if u.get("id", "") == tid and int(u.get("hp", 0)) > 0:
                    return u
        return self._first_alive(foes)

    def _find_actor(self, unit_id):
        for a in self._actors:
            if a.get("id", "") == unit_id:
                return a
        return {}

    def can_use_skill(self, unit_id, skill_id):
        actor = self._find_actor(unit_id)
        if not actor:
            return False
        if not self._is_awakened(actor, skill_id):
            return True
        return int(actor.get("qi", 0)) >= self._awaken_cost()

    def get_qi(self, unit_id):
        return int(self._find_actor(unit_id).get("qi", 0))

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
    def _defeat(self):
        self._resolved = True
        self._outcome = "defeat"
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


# ===================== S3-B2 连携实战发射接线（BattleLauncher.launch 镜像） =====================
# 忠实移植 scripts/core/BattleLauncher.gd::launch：
#   start_battle 先（清零 _bond_bonus），之后 compute_combo(GameState.deck) 发射 bond_combo，
#   由 BattleManager（全局 autoload，仅订阅）经事件写入 _bond_bonus。顺序绝不能反。
# _B2_BM / _B2_BOND 模拟 GDScript 的全局 autoload 单例，供断言读取 _bond_bonus。
_B2_BM = None
_B2_BOND = None

def launch(chapter, stage):
    global _B2_BM, _B2_BOND
    _B2_BM = BattleManager()
    _B2_BM.rng = RNGWrapper(1)
    _B2_BOND = BondManager()
    if not _B2_BM.start_battle(chapter, stage):
        return False
    _B2_BOND.compute_combo(GameState.deck)
    return True


# ===================== CultivationManager.get_final_unit 镜像（忠实当前 GDScript）=====================
# 当前 GDScript CultivationManager.get_final_unit 会聚合 final_stats / skills / branch_dmg_mult
# / branch_hp_mult（分支被动数值自动生效）。S2 的旧 python 镜像缺少 branch_dmg_mult，
# 故此处按当前 GDScript 重新忠实移植，供 B-3 的 _build_players 使用。
def _passive_slots_for(bt, cult):
    slots = cult.get("breakthrough", {}).get("passive_slots_per_tier", [1, 2, 3, 4, 5, 6])
    bt = max(0, min(bt, 5))
    if bt < len(slots):
        return int(slots[bt])
    return int(slots[len(slots) - 1])

def _final_unit(unit_id):
    defs = cl_load_table("shikigami", "")
    if defs is None or unit_id not in defs.get("shikigami", {}):
        return {}
    def_ = defs["shikigami"][unit_id]
    entry = {}
    for s in GameState.shikigami:
        if s.get("id", "") == unit_id:
            entry = s
            break
    level = int(entry.get("level", 1)) if entry else 1
    bt = int(entry.get("breakthrough", 0)) if entry else 0
    bt = max(0, min(bt, 5))
    cult = cl_load_table("cultivation", "")
    lc = cult.get("level_curve", {})
    hp_rate = 0.5 * (float(lc.get("hp_per_level_pct_min", 0.02)) + float(lc.get("hp_per_level_pct_max", 0.03)))
    atk_rate = 0.5 * (float(lc.get("atk_per_level_pct_min", 0.02)) + float(lc.get("atk_per_level_pct_max", 0.03)))
    base_hp = float(def_.get("base_stats", {}).get("hp", 0))
    base_atk = float(def_.get("base_stats", {}).get("atk", 0))
    after_level_hp = base_hp * (1.0 + hp_rate * (level - 1))
    after_level_atk = base_atk * (1.0 + atk_rate * (level - 1))
    bc = cult.get("breakthrough", {})
    bt_rate = 0.5 * (float(bc.get("attr_gain_pct_min", 0.08)) + float(bc.get("attr_gain_pct_max", 0.12)))
    final_hp = int(round(after_level_hp * (1.0 + bt_rate * bt)))
    final_atk = int(round(after_level_atk * (1.0 + bt_rate * bt)))
    skills = []
    for s in def_.get("skills", []):
        skills.append(s)
    for s in (entry.get("awakened_skills", []) if entry else []):
        skills.append(s)
    branch = entry.get("branch", "") if entry else ""
    branch_dmg_mult = 0.0
    branch_hp_mult = 0.0
    if branch != "":
        branches = cult.get("branches", {})
        if branch in branches:
            skills.append(branches[branch].get("passive", ""))
            branch_dmg_mult = float(branches[branch].get("dmg_mult", 0.0))
            branch_hp_mult = float(branches[branch].get("hp_mult", 0.0))
    return {
        "id": unit_id, "element": def_.get("element", ""), "bond_tags": def_.get("bond_tags", []),
        "final_stats": {"hp": final_hp, "atk": final_atk}, "skills": skills,
        "breakthrough": bt, "passive_slots": _passive_slots_for(bt, cult),
        "branch": branch, "branch_dmg_mult": branch_dmg_mult, "branch_hp_mult": branch_hp_mult,
        "level": level, "awakened_skills": (entry.get("awakened_skills", []) if entry else []),
    }


# ===================== B-1 灼烧状态（StatusManager 镜像）=====================
def B1_suite():
    cl_reset()
    cl_inject("battle/status_config", REAL_STATUS)
    sm = StatusManager()
    MAXHP = 1000
    # earth 为灼烧的中性元素（既非水也非木），用于对照
    sm.register_unit("u_neutral", "earth", MAXHP)
    sm.register_unit("u_water", "water", MAXHP)
    sm.register_unit("u_wood", "wood", MAXHP)

    # B-1a 施加灼烧后层数=1
    sm.apply_status("u_neutral", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
    eq(sm.get_stacks("u_neutral", "burn"), 1, "B-1 施加灼烧层数=1")

    # B-1b 连点 3 次后封顶 3（不溢出）；第 4 次仍封顶 3
    sm.apply_status("u_neutral", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
    sm.apply_status("u_neutral", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
    eq(sm.get_stacks("u_neutral", "burn"), 3, "B-1 连点3次封顶=3")
    sm.apply_status("u_neutral", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
    eq(sm.get_stacks("u_neutral", "burn"), 3, "B-1 第4次仍封顶=3(不溢出)")

    # B-1c 水行压制：max_stacks=1 & duration=1
    sm.apply_status("u_water", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
    eq(sm.get_stacks("u_water", "burn"), 1, "B-1 水行 max_stacks=1(压制)")
    eq(sm.get_statuses("u_water")[0]["turns_left"], 1, "B-1 水行 duration=1(压制)")
    sm.apply_status("u_water", {"type": "burn", "stacks": 1, "duration": 3}, "fire")  # 再压一次
    eq(sm.get_stacks("u_water", "burn"), 1, "B-1 水行多次仍封顶=1")
    eq(sm.get_statuses("u_water")[0]["turns_left"], 1, "B-1 水行每次刷新 duration=1")

    # B-1d 木行增益：DoT ×1.20
    sm.apply_status("u_wood", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
    dot_wood = sm.tick_statuses("u_wood")        # 1 stack, mult 1.20 -> round(1*0.03*1.20*1000)=36
    dot_neutral3 = sm.tick_statuses("u_neutral") # 3 stack, mult 1.0  -> round(3*0.03*1000)=90
    eq(dot_wood, 36, "B-1 木行 DoT=36(×1.20)")
    eq(dot_neutral3, 90, "B-1 中性3stack DoT=90")
    # 对照：木行 > 中性（同层数）
    sm2 = StatusManager(); sm2.register_unit("c_wood", "wood", MAXHP); sm2.register_unit("c_neu", "earth", MAXHP)
    sm2.apply_status("c_wood", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
    sm2.apply_status("c_neu", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
    eq(sm2.tick_statuses("c_wood"), 36, "B-1 木行1stack=36")
    eq(sm2.tick_statuses("c_neu"), 30, "B-1 中性1stack=30(对照)")

    # B-1e 3 tick 后到期清层
    sm3 = StatusManager(); sm3.register_unit("u2", "earth", MAXHP)
    sm3.apply_status("u2", {"type": "burn", "stacks": 1, "duration": 3}, "fire")
    sm3.tick_statuses("u2")
    sm3.tick_statuses("u2")
    sm3.tick_statuses("u2")
    eq(sm3.get_stacks("u2", "burn"), 0, "B-1 3 tick后清层")
    eq(len(sm3.get_statuses("u2")), 0, "B-1 状态表清空")

    # B-1f 正交性：DoT 计算不引用 _bond_bonus（R5）—— StatusManager.tick_statuses 完全 bond-free
    sm4 = StatusManager(); sm4.register_unit("ub", "earth", MAXHP)
    sm4.apply_status("ub", {"type": "burn", "stacks": 2, "duration": 3}, "fire")
    dot_bond_free = sm4.tick_statuses("ub")  # 2*0.03*1000=60
    eq(dot_bond_free, 60, "B-1 中性2stack DoT=60(纯公式)")
    # 即便存在一个 bond_bonus>0 的战斗环境，DoT 不变（不乘 1.175）
    bm = BattleManager(status_mgr=sm4)
    bm._bond_bonus = 0.175
    # BM 在回合开始 tick 该单位；返回值应仍=60，而非 60*(1.175)=71
    eq(bm._status.tick_statuses("ub"), 60, "B-1 正交：BM tick 不乘 bond")
    check(int(round(60 * 1.175)) != 60, "B-1 正交：DoT 不等于 bond 缩放值(71)")
    # 端到端：带灼烧单位在 bond>0 的战斗中，回合开始扣血=纯 DoT（无双 dip）
    _ortho_integration()


def _ortho_integration():
    cl_reset()
    cl_inject("cultivation", REAL_CULT)
    shiki = {"shikigami": dict(REAL_SHIKI["shikigami"])}
    shiki["shikigami"]["ts"] = {"name": "ts", "element": "earth", "rarity": "N",
                                "bond_tags": [], "base_stats": {"hp": 1000, "atk": 100},
                                "skills": ["skill_qing_long_base"]}
    cl_inject("shikigami", shiki)
    cl_inject("battle/skill_defs", REAL_SKILLS)
    cl_inject("battle/status_config", REAL_STATUS)
    cl_inject("battle/element_matrix", REAL_MATRIX)
    cl_inject("battle/chapters", {"chapters": [{
        "id": 1, "name": "T", "stages": [{
            "id": 1, "boss": False,
            "enemies": [{"id": "e1", "element": "wood", "stats": {"hp": 500, "atk": 50}}],
            "reward": {"fu_lu": [1, 3], "po_dan": 0, "jue_xing_shi": 0}}]}]})
    GameState.reset_all()
    GameState.shikigami = [{"id": "ts", "level": 1, "breakthrough": 0, "awakened_skills": [],
                            "bond_level": 0, "fragments": 0, "branch": ""}]
    GameState.deck = ["ts"]
    bm = BattleManager()
    bm.rng = RNGWrapper(1)
    check(bm.start_battle(1, 1), "B-1 正交集成：开局成功")
    bm._status.apply_status("ts", {"type": "burn", "stacks": 2, "duration": 3}, "fire")  # 2 层灼烧
    bm._bond_bonus = 0.175  # 模拟连携加成激活
    hp_before = bm._players[0]["hp"]
    bm.step({"skill_id": "skill_qing_long_base", "target_id": "e1"})
    hp_after = bm._players[0]["hp"]
    dot_loss = hp_before - hp_after  # 玩家本回合只受 DoT 影响（直接打击打在敌人身上）
    eq(dot_loss, 60, "B-1 正交集成：玩家 DoT 扣血=60(未乘bond)")
    check(int(round(60 * 1.175)) != dot_loss, "B-1 正交集成：DoT 未双 dip(≠71)")


# ===================== B-3 玩家选技（BattleManager.step 镜像）=====================
def _b3_setup(shikigami_entries, deck, enemies, boss=False):
    cl_reset()
    cl_inject("cultivation", REAL_CULT)
    shiki = {"shikigami": dict(REAL_SHIKI["shikigami"])}
    for e in shikigami_entries:
        shiki["shikigami"][e["id"]] = e["def"]
    cl_inject("shikigami", shiki)
    cl_inject("battle/skill_defs", REAL_SKILLS)
    cl_inject("battle/status_config", REAL_STATUS)
    cl_inject("battle/element_matrix", REAL_MATRIX)
    cl_inject("battle/chapters", {"chapters": [{
        "id": 1, "name": "T", "stages": [{
            "id": 1, "boss": boss,
            "enemies": enemies,
            "reward": {"fu_lu": [1, 3], "po_dan": 0, "jue_xing_shi": 0}}]}]})
    GameState.reset_all()
    GameState.shikigami = [e["state"] for e in shikigami_entries]
    GameState.deck = deck
    bm = BattleManager()
    bm.rng = RNGWrapper(1)
    check(bm.start_battle(1, 1), "B-3 开局成功")
    return bm


def B3_suite():
    _clear_battle_signals()

    # B-3a 选技驱动：step 由给定 skill+target 驱动
    bm = _b3_setup(
        [{"id": "test_driver", "def": {"name": "driver", "element": "metal", "rarity": "N",
                                        "bond_tags": [], "base_stats": {"hp": 1000, "atk": 100},
                                        "skills": ["skill_qing_long_base", "skill_you_ming_base"]},
          "state": {"id": "test_driver", "level": 1, "breakthrough": 0, "awakened_skills": [],
                    "bond_level": 0, "fragments": 0, "branch": ""}}],
        ["test_driver"],
        [{"id": "e_wood", "element": "wood", "stats": {"hp": 500, "atk": 50}},
         {"id": "e_metal", "element": "metal", "stats": {"hp": 500, "atk": 50}}],
    )
    res = bm.step({"skill_id": "skill_qing_long_base", "target_id": "e_metal"})
    eq(res.get("skill_id"), "skill_qing_long_base", "B-3 选技驱动：使用指定 skill")
    eq(res.get("target_id"), "e_metal", "B-3 选技驱动：命中指定 target")
    gt(res.get("damage", 0), 0, "B-3 选技驱动：造成伤害")
    eq(res.get("relation"), "NEUTRAL", "B-3 选技驱动：metal技打metal目标=中立")

    # B-3b 克制差：选克制 element 技能伤害明显高于被克（≥25% 差）
    bm_adv = _b3_setup(
        [{"id": "test_driver", "def": {"name": "driver", "element": "metal", "rarity": "N",
                                        "bond_tags": [], "base_stats": {"hp": 1000, "atk": 100},
                                        "skills": ["skill_qing_long_base", "skill_you_ming_base"]},
          "state": {"id": "test_driver", "level": 1, "breakthrough": 0, "awakened_skills": [],
                    "bond_level": 0, "fragments": 0, "branch": ""}}],
        ["test_driver"],
        [{"id": "e_wood", "element": "wood", "stats": {"hp": 500, "atk": 50}}],
    )
    res_adv = bm_adv.step({"skill_id": "skill_qing_long_base", "target_id": "e_wood"})  # metal 克 wood
    eq(res_adv.get("relation"), "ADVANTAGE", "B-3 克制：metal技打wood目标=克制")

    bm_dis = _b3_setup(
        [{"id": "test_driver", "def": {"name": "driver", "element": "metal", "rarity": "N",
                                        "bond_tags": [], "base_stats": {"hp": 1000, "atk": 100},
                                        "skills": ["skill_qing_long_base", "skill_you_ming_base"]},
          "state": {"id": "test_driver", "level": 1, "breakthrough": 0, "awakened_skills": [],
                    "bond_level": 0, "fragments": 0, "branch": ""}}],
        ["test_driver"],
        [{"id": "e_metal", "element": "metal", "stats": {"hp": 500, "atk": 50}}],
    )
    res_dis = bm_dis.step({"skill_id": "skill_you_ming_base", "target_id": "e_metal"})  # wood 被 metal 克
    eq(res_dis.get("relation"), "DISADVANTAGE", "B-3 被克：wood技打metal目标=被克")
    gt(res_adv.get("damage", 0), res_dis.get("damage", 0), "B-3 克制伤害>被克伤害")
    check(float(res_adv.get("damage", 0)) >= float(res_dis.get("damage", 0)) * 1.25,
          "B-3 克制差≥25%%（adv=%r, dis=%r）" % (res_adv.get("damage"), res_dis.get("damage")))

    # B-3c 觉醒技命中触发对应 status_on_hit（朱雀 awaken -> burn）
    bm_aw = _b3_setup(
        [{"id": "sr_zhu_que", "def": REAL_SHIKI["shikigami"]["sr_zhu_que"],
          "state": {"id": "sr_zhu_que", "level": 1, "breakthrough": 3,
                    "awakened_skills": ["skill_zhu_que_awakened"],  # 已觉醒（含觉醒技）
                    "bond_level": 0, "fragments": 99, "branch": ""}}],
        ["sr_zhu_que"],
        [{"id": "e1", "element": "earth", "stats": {"hp": 500, "atk": 50}}],  # 中性，避免水压制干扰
    )
    bm_aw._players[0]["qi"] = 3  # 气足，不门控
    res_aw = bm_aw.step({"skill_id": "skill_zhu_que_awakened", "target_id": "e1"})
    eq(res_aw.get("skill_id"), "skill_zhu_que_awakened", "B-3 觉醒：使用觉醒技")
    eq(bm_aw._status.get_stacks("e1", "burn"), 1, "B-3 觉醒：命中触发 burn 1层")

    # B-3d 分支被动自动入算（剑修 +10% 直接伤害）
    # 注：bt=3 突破已让 atk 由 80 -> 104(+30%)，故 sword=round(104*1.10)=114，plain=104
    bm_sword = _b3_setup(
        [{"id": "test_ssr", "def": {"name": "ssr", "element": "metal", "rarity": "N",
                                     "bond_tags": [], "base_stats": {"hp": 1000, "atk": 80},
                                     "skills": ["skill_qing_long_base"]},
          "state": {"id": "test_ssr", "level": 1, "breakthrough": 3, "awakened_skills": [],
                    "bond_level": 0, "fragments": 0, "branch": "sword"}}],
        ["test_ssr"],
        [{"id": "e1", "element": "earth", "stats": {"hp": 500, "atk": 50}}],  # 中立 mult=1.0
    )
    res_sword = bm_sword.step({"skill_id": "skill_qing_long_base", "target_id": "e1"})
    eq(res_sword.get("damage"), 114, "B-3 分支：剑修 dmg=114(104×1.10)")

    bm_plain = _b3_setup(
        [{"id": "test_ssr", "def": {"name": "ssr", "element": "metal", "rarity": "N",
                                     "bond_tags": [], "base_stats": {"hp": 1000, "atk": 80},
                                     "skills": ["skill_qing_long_base"]},
          "state": {"id": "test_ssr", "level": 1, "breakthrough": 3, "awakened_skills": [],
                    "bond_level": 0, "fragments": 0, "branch": ""}}],
        ["test_ssr"],
        [{"id": "e1", "element": "earth", "stats": {"hp": 500, "atk": 50}}],
    )
    res_plain = bm_plain.step({"skill_id": "skill_qing_long_base", "target_id": "e1"})
    eq(res_plain.get("damage"), 104, "B-3 对照：无分支 dmg=104(bt3 atk)")
    gt(res_sword.get("damage"), res_plain.get("damage"), "B-3 分支被动自动增伤入算")

    # B-3e qi 不足时觉醒技被门控（自动降级基础技，伤害/状态按基础技）
    bm_gate = _b3_setup(
        [{"id": "sr_zhu_que", "def": REAL_SHIKI["shikigami"]["sr_zhu_que"],
          "state": {"id": "sr_zhu_que", "level": 1, "breakthrough": 3,
                    "awakened_skills": ["skill_zhu_que_awakened"],  # 已觉醒
                    "bond_level": 0, "fragments": 99, "branch": ""}}],
        ["sr_zhu_que"],
        [{"id": "e1", "element": "earth", "stats": {"hp": 500, "atk": 50}}],
    )
    # 首回合 qi=0 → 觉醒技门控
    res_gate = bm_gate.step({"skill_id": "skill_zhu_que_awakened", "target_id": "e1"})
    check(bool(res_gate.get("skill_gated", False)), "B-3 qi门控：觉醒技被降级标记")
    eq(res_gate.get("skill_id"), "skill_zhu_que_base", "B-3 qi门控：降级为基础技")
    eq(bm_gate._status.get_stacks("e1", "burn"), 0, "B-3 qi门控：基础技不触发 status")


# ===================== B-2 连携实战发射接线（BattleLauncher.launch 镜像） =====================
def _b2_setup(deck_ids):
    cl_reset()
    cl_inject("cultivation", REAL_CULT)
    cl_inject("shikigami", {"shikigami": dict(REAL_SHIKI["shikigami"])})
    cl_inject("battle/skill_defs", REAL_SKILLS)
    cl_inject("battle/status_config", REAL_STATUS)
    cl_inject("battle/element_matrix", REAL_MATRIX)
    cl_inject("battle/bond_combos", REAL_BONDS)
    cl_inject("battle/chapters", {"chapters": [{
        "id": 1, "name": "T", "stages": [{
            "id": 1, "boss": False,
            "enemies": [{"id": "e1", "element": "wood", "stats": {"hp": 500, "atk": 50}}],
            "reward": {"fu_lu": [1, 3], "po_dan": 0, "jue_xing_shi": 0}}]}]})
    GameState.reset_all()
    GameState.shikigami = [{"id": x, "level": 1, "breakthrough": 0, "awakened_skills": [],
                            "bond_level": 0, "fragments": 0, "branch": ""} for x in deck_ids]
    GameState.deck = list(deck_ids)


def B2_suite():
    # --- 剑宗 4 人队：start_battle 后 compute_combo(deck) -> _bond_bonus = 0.175 (> 0) ---
    _clear_battle_signals()
    four = ["ssr_qing_long", "ssr_bai_hu", "sr_you_ming", "sr_xuan_feng"]
    _b2_setup(four)
    ok = launch(1, 1)
    check(ok, "B-2 剑宗4人 launch 返回 True(开局成功)")
    approx(_B2_BM.get_bond_bonus(), 0.175, 1e-9, "B-2 剑宗4人 _bond_bonus=0.175(3+中点)")
    gt(_B2_BM.get_bond_bonus(), 0.0, "B-2 剑宗4人 _bond_bonus>0(连携实战生效)")

    # --- 单人：不足 2 人无连携 -> _bond_bonus == 0.0 ---
    _clear_battle_signals()
    _b2_setup(["ssr_qing_long"])
    ok = launch(1, 1)
    check(ok, "B-2 单人 launch 返回 True(开局成功)")
    eq(_B2_BM.get_bond_bonus(), 0.0, "B-2 单人 _bond_bonus==0.0(无连携)")

    # --- 无连携组队（两单位分属不同连携组，无 2 人同组）：_bond_bonus == 0.0 ---
    _clear_battle_signals()
    _b2_setup(["r_tie_jia", "r_qiu_long"])
    ok = launch(1, 1)
    check(ok, "B-2 无连携组队 launch 返回 True(开局成功)")
    eq(_B2_BM.get_bond_bonus(), 0.0, "B-2 无连携组队 _bond_bonus==0.0")


# ===================== 执行 =====================
if __name__ == "__main__":
    B1_suite()
    b1_total = len(_results)
    b1_pass = sum(1 for ok, _ in _results if ok)
    b3_start = len(_results)
    B3_suite()
    b3_total = len(_results) - b3_start
    b3_pass = sum(1 for ok, _ in _results[b3_start:]) if b3_total else 0
    b2_start = len(_results)
    B2_suite()
    b2_total = len(_results) - b2_start
    b2_pass = sum(1 for ok, _ in _results[b2_start:]) if b2_total else 0

    print("=" * 64)
    print("S3 纯逻辑验证（Python 镜像）— B-1 灼烧状态 / B-3 玩家选技 / B-2 连携实战发射")
    print("=" * 64)
    for ok, msg in _results:
        if not ok:
            print("  [FAIL] " + msg)
    print("-" * 64)
    print("B-1 灼烧状态: 断言 %d | 通过 %d | 失败 %d" % (b1_total, b1_pass, b1_total - b1_pass))
    print("B-3 玩家选技: 断言 %d | 通过 %d | 失败 %d" % (b3_total, b3_pass, b3_total - b3_pass))
    print("B-2 连携实战发射: 断言 %d | 通过 %d | 失败 %d" % (b2_total, b2_pass, b2_total - b2_pass))
    total = len(_results)
    passed = sum(1 for ok, _ in _results if ok)
    print("总计断言: %d | 通过: %d | 失败 %d" % (total, passed, total - passed))
    print("S3 算法层判定: %s" % ("PASS ✅" if (total - passed) == 0 else "FAIL ❌"))
    print("=" * 64)
