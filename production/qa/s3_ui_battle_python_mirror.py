#!/usr/bin/env python3
# s3_ui_battle_python_mirror.py — S3-UI-Battle 本地逻辑镜像（无 Godot / 无显示沙箱用）
#
# 复刻「五行形状映射 + 横幅数值格式化 + 热区判定 + 双端 layout 选择 + 状态三重冗余」
# 作为本地证据；真机视觉/手感验证留 S3-DualEnd（真机 Godot 跑 + 截图比对）。
#
# 数据真源：../../../data/battle/battle_ui_constants.json
#          ../../../data/battle/status_config.json（状态→本行元素）
#          ../../../data/battle/bond_combos.json（横幅组名）
#
# 用法：python3 s3_ui_battle_python_mirror.py
# 退出码 0 = 逻辑层 PASS（CONCERNS 见汇总）；非 0 = 逻辑 FAIL。

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CONST = os.path.join(ROOT, "data", "battle", "battle_ui_constants.json")
STATUS_CFG = os.path.join(ROOT, "data", "battle", "status_config.json")
BOND_CFG = os.path.join(ROOT, "data", "battle", "bond_combos.json")

# ---- 逻辑镜像（与 GDScript 实现一致）----
def compute_layout_mode(w: int) -> str:
    if w >= 1024:
        return "multi"
    if w >= 768:
        return "hybrid"
    return "single"

def format_bonus(pct: float) -> str:
    return "+%.1f%%" % (pct * 100.0)

STATUS_ELEMENT = {"burn": "fire", "armor_break": "metal", "poison": "wood", "momentum": "metal"}

results = []  # (name, ok, detail)

def check(name, ok, detail=""):
    results.append((name, ok, detail))
    mark = "PASS" if ok else "FAIL"
    print(f"  [{mark}] {name}" + (f" — {detail}" if detail else ""))

def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def main():
    print("=" * 64)
    print("S3-UI-Battle · Python 逻辑镜像（本地证据）")
    print("=" * 64)

    const = load_json(CONST)
    status_cfg = load_json(STATUS_CFG)
    bond_cfg = load_json(BOND_CFG)

    # ---- 1) 五行形状映射齐全 + 灰阶互异 ----
    print("\n[1] 五行形状映射（圆/三角/方/菱/五边 ↔ 金/木/水/火/土）")
    shapes = const.get("element_shapes", {})
    for el in ["metal", "wood", "water", "fire", "earth"]:
        check(f"element_shapes 含 {el}", el in shapes, f"-> {shapes.get(el, 'MISSING')}")
    vals = list(shapes.values())
    distinct = len(vals) == len(set(vals))
    check("五行形状两两互异（灰阶可辨）", distinct, f"shapes={vals}")
    # 正确配对 5 个互异形状名
    ok_shapes = set(vals) == {"triangle", "circle", "square", "diamond", "pentagon"}
    check("恰为 5 个互异形状（圆/三角/方/菱/五边）", ok_shapes)

    # ---- 2) 横幅数值格式化 ----
    print("\n[2] 连携横幅数值格式化（bond_combo → +X.X%）")
    for pct, want in [(0.175, "+17.5%"), (0.10, "+10.0%"), (0.20, "+20.0%"),
                         (0.0, "+0.0%"), (0.12345, "+12.3%")]:
        got = format_bonus(pct)
        check(f"format_bonus({pct})", got == want, f"-> {got}")
    # 横幅锚点 5 + tabular + 双端尺寸
    cb = const.get("combo_banner", {})
    check("横幅 anchor_id == 5（五行符文阵）", int(cb.get("anchor_id", 0)) == 5)
    check("横幅 tabular", bool(cb.get("tabular", False)))
    check("PC 横幅宽 <= 60%", float(cb.get("max_width_pct", {}).get("pc", 1.0)) <= 0.6)
    check("移动横幅宽 >= 90%", float(cb.get("max_width_pct", {}).get("mobile", 0.0)) >= 0.9)
    check("PC 横幅高 <= 96px", int(cb.get("max_height_px", {}).get("pc", 999)) <= 96)
    check("移动横幅高 <= 56px", int(cb.get("max_height_px", {}).get("mobile", 999)) <= 56)

    # ---- 3) 热区判定（>=44，移动额外>=44/48）----
    print("\n[3] 触控热区判定（Standard J，>=44×44）")
    check("全局 hotzone_min_px >= 44", int(const.get("hotzone_min_px", 0)) >= 44)
    check("移动端 mobile_hotzone_min_px >= 44", int(const.get("mobile_hotzone_min_px", 0)) >= 44)
    qg = const.get("qi_gauge", {})
    check("气槽 hotzone_min_px >= 44", int(qg.get("hotzone_min_px", 0)) >= 44)
    check("移动端气格 >= 48", int(qg.get("mobile_pip_px", 0)) >= 48)
    sb = const.get("skill_button", {})
    check("选技按钮 hotzone_min_px >= 44", int(sb.get("hotzone_min_px", 0)) >= 44)
    check("移动端选技按钮 >= 48", int(sb.get("mobile_min_px", 0)) >= 48)

    # ---- 4) 双端 layout 选择 ----
    print("\n[4] 双端 layout 选择（UIThemeController.compute_layout_mode 镜像）")
    for w, want in [(1280, "multi"), (1024, "multi"), (900, "hybrid"),
                         (768, "hybrid"), (390, "single"), (767, "single")]:
        got = compute_layout_mode(w)
        check(f"width={w} -> {want}", got == want, f"-> {got}")

    # ---- 5) 状态图标三重冗余（形状/图标/数字 + 灰阶矩阵）----
    print("\n[5] 状态图标三重冗余（不靠色）")
    si = const.get("status_icons", {})
    for st in ["burn", "armor_break", "poison", "momentum"]:
        d = si.get(st, {})
        el = d.get("element", "")
        glyph = d.get("glyph", "")
        sil = d.get("silhouette", "")
        ok = (el != "") and (glyph != "") and (sil != "") and (int(d.get("max_stacks", 0)) >= 1)
        # 本行元素须匹配 status_config 权威（形状通道来源）
        cfg_el = status_cfg.get("status", {}).get(st, {}).get("element", "")
        ok = ok and (el == cfg_el)
        check(f"{st} 三重字段齐全且本行元素权威", ok,
               f"el={el}(cfg={cfg_el}) glyph={glyph} sil={sil}")
    # 灰阶矩阵两两互异
    sils = [si[s]["silhouette"] for s in si]
    distinct_sil = len(sils) == len(set(sils))
    check("四状态 silhouette 两两互异（灰阶可辨）", distinct_sil, f"{sils}")

    # ---- 6) 气槽 pip 数 + 元素形状 glyph 联动 ----
    print("\n[6] 气槽 3 pip + 元素形状 glyph 联动")
    check("气槽 pips == 3", int(qg.get("pips", 0)) == 3)
    check("气格形状按本行联动", bool(qg.get("pip_shape_from_element", False)))
    glyphs = qg.get("pip_glyph_by_element", {})
    for el in ["metal", "wood", "water", "fire", "earth"]:
        check(f"气格 glyph 含 {el}", el in glyphs, f"-> {glyphs.get(el, 'MISSING')}")
        # glyph 须与 element_shapes 一致
        check(f"{el} 气格 glyph == 元素形状", glyphs.get(el) == shapes.get(el))

    # ---- 7) 连携组名可解析（横幅文案）----
    print("\n[7] 连携组名解析（横幅「{组名} 连携 +X.X%」）")
    groups = bond_cfg.get("groups", {})
    ok_groups = all(g.get("name", "") != "" for g in groups.values())
    check(f"bond_combos 含 {len(groups)} 组且均有 name", ok_groups,
           f"groups={list(groups.keys())}")
    # 模拟一次横幅文案
    sample = groups.get("yu_zu", {})
    banner_txt = f"{sample.get('name','')} 连携   {format_bonus(0.175)}"
    check("横幅文案样例", "羽族 连携   +17.5%" in banner_txt, f"-> {banner_txt}")

    # ---- 汇总 ----
    print("\n" + "=" * 64)
    fails = [r for r in results if not r[1]]
    n_pass = len(results) - len(fails)
    print(f"逻辑层：{n_pass}/{len(results)} 项 PASS")
    if fails:
        print("逻辑 FAIL 项：")
        for name, _, detail in fails:
            print(f"  - {name}  ({detail})")
        print("\n结论：FAIL（逻辑层有未通过项，需修正后重跑）")
        return 1
    print("结论：逻辑层 PASS")
    print("\nCONCERNS（待真机/S3 收口，不影响逻辑 PASS）：")
    print("  C1 场景/控件无法本沙箱运行（无 Godot/显示）→ 待 S3-C3 CI 跑 GUT + S3-DualEnd 真机核验。")
    print("  C2 真实立绘/VFX 美术未生成（A1–A4 仅规格）→ 当前占位视觉，Asset-Art 阶段替换。")
    print("  C3 灰阶可辨/热区命中率≥95%/无溢出裁切 → 真机截图比对（S3-DualEnd AC3）。")
    print("=" * 64)
    return 0

if __name__ == "__main__":
    sys.exit(main())
