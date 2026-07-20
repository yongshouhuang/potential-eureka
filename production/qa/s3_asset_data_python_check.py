#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
S3-Asset-Data 本地逻辑镜像（不可跑 Godot/GUT 沙箱下的替代证据）
=====================================================================
镜像式神资产数据层的数据完整性校验（对应隐患 #13 + 式神数据自检）：

  A) gacha_pools.json 中所有式神 id 引用（shikigami_by_rarity 各稀有度列表、
     starter_sr_id）必须存在于 shikigami_defs.json。
  B) shikigami_defs.json 每条核心字段齐全、结构一致；稀有度分布统计。
  C) bond_combos.json 各 group.members 引用的式神 id 必须存在于 defs。
  D) cultivation_config.json 的 awaken.skills_by_shikigami 键（式神 id）必须
     存在于 defs；其值（技能 id）必须存在于 skill_defs.json。
  E) shikigami_defs.json 各条 skills[] 引用的技能 id 必须存在于 skill_defs.json。
     （skill_defs.json 本身不反向持有式神 id，故“技能引用的式神无悬空”等价于
      上述 D/E 的技能解析闭环。）

不依赖 Godot；仅用标准库。运行：python3 production/qa/s3_asset_data_python_check.py
"""
import os
import sys
import json

DATA_ROOT = r"F:\AI\仙侠卡牌项目"

REQUIRED_FIELDS = ("name", "element", "rarity", "bond_tags", "base_stats", "skills")
VALID_RARITIES = ("SSR", "SR", "R", "N")
# id 前缀 -> 期望稀有度（仅作软一致性检查，不致命）
PREFIX_RARITY = {"ssr_": "SSR", "sr_": "SR", "r_": "R", "n_": "N"}


def _load(rel):
    with open(os.path.join(DATA_ROOT, rel), "r", encoding="utf-8") as f:
        return json.load(f)


def main():
    results = []

    def check(cond, msg):
        if cond:
            print("  [PASS] " + msg)
            results.append(True)
        else:
            print("  [FAIL] " + msg)
            results.append(False)

    defs = _load("data/shikigami/shikigami_defs.json")
    pools = _load("data/gacha/gacha_pools.json")
    bonds = _load("data/battle/bond_combos.json")
    cult = _load("data/cultivation/cultivation_config.json")
    skills = _load("data/battle/skill_defs.json")

    shikigami = defs["shikigami"]
    def_ids = set(shikigami.keys())
    skill_ids = set(skills["skills"].keys())

    print("=" * 64)
    print("S3-Asset-Data 数据完整性逻辑镜像")
    print("=" * 64)
    print("式神定义总数: %d" % len(def_ids))

    # ---- A) gacha 引用闭环 ----
    print("\n[A] gacha_pools.json 式神 id 引用 -> shikigami_defs.json")
    gacha_refs = []
    for pool_id, pool in pools["pools"].items():
        srid = pool.get("starter_sr_id")
        if srid:
            gacha_refs.append(("pools.%s.starter_sr_id" % pool_id, srid))
        for rarity, ids in pool.get("shikigami_by_rarity", {}).items():
            for sid in ids:
                gacha_refs.append(("pools.%s.shikigami_by_rarity.%s" % (pool_id, rarity), sid))
    missing_gacha = [(src, sid) for (src, sid) in gacha_refs if sid not in def_ids]
    check(len(missing_gacha) == 0,
          "gacha 池所有式神 id 引用均存在（共 %d 处引用，缺失 %d）"
          % (len(gacha_refs), len(missing_gacha)))
    for src, sid in missing_gacha:
        print("         phantom: %s  @ %s" % (sid, src))

    # ---- B) defs 字段完整性 + 稀有度分布 ----
    print("\n[B] shikigami_defs.json 字段完整性 + 稀有度分布")
    bad_fields = []
    prefix_mismatch = []
    dist = {}
    for sid, d in shikigami.items():
        missing = [f for f in REQUIRED_FIELDS if f not in d]
        if missing:
            bad_fields.append((sid, missing))
            continue
        if not isinstance(d["name"], str) or not d["name"]:
            bad_fields.append((sid, ["name(empty)"]))
        if d["rarity"] not in VALID_RARITIES:
            bad_fields.append((sid, ["rarity(invalid)"]))
        bs = d["base_stats"]
        if not (isinstance(bs, dict) and isinstance(bs.get("hp"), int) and bs["hp"] > 0
                and isinstance(bs.get("atk"), int) and bs["atk"] > 0):
            bad_fields.append((sid, ["base_stats{hp,atk}"]))
        if not (isinstance(d["skills"], list) and len(d["skills"]) > 0):
            bad_fields.append((sid, ["skills(empty)"]))
        if not isinstance(d["bond_tags"], list):
            bad_fields.append((sid, ["bond_tags"]))
        for pfx, rar in PREFIX_RARITY.items():
            if sid.startswith(pfx) and d["rarity"] != rar:
                prefix_mismatch.append((sid, d["rarity"], pfx, rar))
        dist[d["rarity"]] = dist.get(d["rarity"], 0) + 1
    check(len(bad_fields) == 0,
          "全部 %d 条式神核心字段齐全（异常 %d）" % (len(def_ids), len(bad_fields)))
    for sid, miss in bad_fields:
        print("         bad fields: %s -> %s" % (sid, miss))
    print("  稀有度分布: " + ", ".join("%s=%d" % (k, dist.get(k, 0)) for k in VALID_RARITIES))
    if prefix_mismatch:
        print("  [WARN] id 前缀与 rarity 字段不一致: %s"
              % prefix_mismatch)
    else:
        print("  [INFO] id 前缀与 rarity 字段全部一致")
    # R3 设计锁 SSR3（主理人确认：朱雀=火 SSR，放宽原 SSR2 锁）
    if dist.get("SSR", 0) != 3:
        print("  [WARN] R3 设计为 N3/R4/SR3/SSR3；当前 SSR=%d" % dist.get("SSR", 0))
    else:
        print("  [INFO] R3 稀有度分布 N3/R4/SR3/SSR3 达标")

    # ---- C) bond_combos 成员闭环 ----
    print("\n[C] bond_combos.json group.members -> shikigami_defs.json")
    bond_refs = []
    for gid, g in bonds.get("groups", {}).items():
        for m in g.get("members", []):
            bond_refs.append(("groups.%s.members" % gid, m))
    missing_bond = [(src, m) for (src, m) in bond_refs if m not in def_ids]
    check(len(missing_bond) == 0,
          "所有羁绊组成员式神 id 存在（共 %d 处，缺失 %d）"
          % (len(bond_refs), len(missing_bond)))
    for src, m in missing_bond:
        print("         dangling: %s @ %s" % (m, src))
    small_groups = [(gid, len(g.get("members", [])))
                    for gid, g in bonds.get("groups", {}).items()
                    if len(g.get("members", [])) < 2]
    check(len(small_groups) == 0,
          "每个羁绊组 >=2 成员（异常组 %d）" % len(small_groups))
    for gid, n in small_groups:
        print("         small group: %s (%d 成员)" % (gid, n))

    # ---- D) cultivation awaken 式神键 + 技能值闭环 ----
    print("\n[D] cultivation_config.awaken.skills_by_shikigami -> defs + skill_defs")
    awaken = cult.get("awaken", {}).get("skills_by_shikigami", {})
    missing_awaken_shikigami = [s for s in awaken if s not in def_ids]
    check(len(missing_awaken_shikigami) == 0,
          "awaken 映射的式神 id 均存在（共 %d 条，缺失 %d）"
          % (len(awaken), len(missing_awaken_shikigami)))
    for s in missing_awaken_shikigami:
        print("         dangling shikigami: %s" % s)
    missing_awaken_skill = [(s, sk) for s, sk in awaken.items() if sk not in skill_ids]
    check(len(missing_awaken_skill) == 0,
          "awaken 映射的技能 id 均存在（缺失 %d）" % len(missing_awaken_skill))
    for s, sk in missing_awaken_skill:
        print("         dangling skill: %s @ %s" % (sk, s))

    # ---- E) defs.skills[] -> skill_defs ----
    print("\n[E] shikigami_defs.skills[] -> skill_defs.json")
    dangling_skills = []
    for sid, d in shikigami.items():
        for sk in d.get("skills", []):
            if sk not in skill_ids:
                dangling_skills.append((sid, sk))
    check(len(dangling_skills) == 0,
          "所有式神 skills[] 引用的技能 id 存在（悬空 %d）" % len(dangling_skills))
    for sid, sk in dangling_skills:
        print("         dangling skill: %s @ %s" % (sk, sid))

    # ---- 汇总 ----
    print("\n" + "=" * 64)
    passed = sum(results)
    total = len(results)
    if all(results):
        print("RESULT: PASS  (%d/%d 项校验通过)" % (passed, total))
        print("数据一致性（无 phantom 引用 + 字段齐全）经本地 Python 镜像校验通过。")
        return 0
    print("RESULT: FAIL  (%d/%d 项校验通过)" % (passed, total))
    return 1


if __name__ == "__main__":
    sys.exit(main())
