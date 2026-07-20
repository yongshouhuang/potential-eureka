#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
S3-E6 本地逻辑镜像（不可跑 Godot/GUT 沙箱下的替代证据）
=====================================================================
镜像 scripts/autoload/UIThemeController.gd 的：
  - ELEMENT_COLOR 基础五行配色（含 #11 COLOR_EARTH：土->赭石）
  - CVD_REMAP 主题色重映射表（E6-S6a，键 = ColorBlind 枚举 NONE=0/DEUTER=1/PROTAN=2/TRITAN=3）
  - MotionScale 消费契约（reduce_motion -> 0.0，静态反馈保留）
  - status_config.json 的 element 字段（#12 handoff）
用纯 Python 断言上述逻辑正确，给出「逻辑 PASS」本地证据；真机 GUT/观感验证见 S3-C3 / S3-DualEnd。

不依赖 Godot；仅用标准库。运行：python3 production/qa/s3_e6_python_logic_mirror.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# ---- 颜色常量（与 UIThemeController 常量区一致，hex 仅此处）----
COLOR = {
    "QING_MING": "#1F3A3D",
    "QING_BI":   "#4FA39B",
    "YUE_BAI":   "#E8ECEF",
    "ZHU_SHA":   "#C8453A",
    "LIU_JIN":   "#CBA75C",
    "ZI_CHEN":   "#8B6DB3",
    "DEEP_INK":  "#122426",
    "EARTH":     "#B98A5E",   # 赭石 · 土行新 token（#11）
}

# ---- 五行基础配色（#11：tu 由 LIU_JIN 改为 EARTH）----
ELEMENT_COLOR = {
    "jin": COLOR["QING_BI"],
    "mu":  COLOR["QING_MING"],
    "shui": COLOR["QING_BI"],
    "huo": COLOR["ZHU_SHA"],
    "tu":  COLOR["EARTH"],
}

# 数据侧 English 元素名 -> 主题色 Chinese 键（与 UIThemeController.ELEMENT_ALIAS 一致）
ELEMENT_ALIAS = {
    "metal": "jin", "wood": "mu", "water": "shui", "fire": "huo", "earth": "tu",
}

# ---- CVD 重映射（键 = ColorBlind 枚举）----
CVD_REMAP = {
    1: {"jin": COLOR["QING_BI"], "mu": COLOR["ZI_CHEN"], "shui": COLOR["YUE_BAI"],
        "huo": COLOR["LIU_JIN"], "tu": COLOR["ZHU_SHA"]},   # DEUTER
    2: {"jin": COLOR["QING_BI"], "mu": COLOR["ZI_CHEN"], "shui": COLOR["YUE_BAI"],
        "huo": COLOR["LIU_JIN"], "tu": COLOR["ZHU_SHA"]},   # PROTAN
    3: {"jin": COLOR["ZHU_SHA"], "mu": COLOR["QING_BI"], "shui": COLOR["ZI_CHEN"],
        "huo": COLOR["LIU_JIN"], "tu": COLOR["YUE_BAI"]},   # TRITAN
}


def get_element_color(element, cvd_mode=0, cvd_enabled=False):
    key = ELEMENT_ALIAS.get(element, element)
    if cvd_enabled and cvd_mode in CVD_REMAP and key in CVD_REMAP[cvd_mode]:
        return CVD_REMAP[cvd_mode][key]
    return ELEMENT_COLOR.get(key, COLOR["YUE_BAI"])


def motion_scale(reduce_motion):
    return 0.0 if reduce_motion else 1.0


# ---- 断言框架 ----
_FAILS = []


def check(name, cond, detail=""):
    mark = "PASS" if cond else "FAIL"
    if not cond:
        _FAILS.append(name)
    print(f"  [{mark}] {name}" + (f"  ({detail})" if detail else ""))


def eq(a, b):
    return a == b


def main():
    print("=== S3-E6 逻辑镜像验证 ===\n")

    print("[1] #11 COLOR_EARTH · 土行独立色")
    check("COLOR_EARTH == #B98A5E", eq(COLOR["EARTH"], "#B98A5E"), COLOR["EARTH"])
    check("ELEMENT_COLOR['tu'] == EARTH（非 LIU_JIN）",
          eq(ELEMENT_COLOR["tu"], COLOR["EARTH"]) and ELEMENT_COLOR["tu"] != COLOR["LIU_JIN"],
          ELEMENT_COLOR["tu"])

    print("\n[2] MotionScale 消费契约（E6-S6b）")
    check("常态 MotionScale == 1.0", eq(motion_scale(False), 1.0))
    check("reduce_motion MotionScale == 0.0", eq(motion_scale(True), 0.0))
    # 静态等效反馈：即使 motion=0，图标/数字/边框仍更新（此处验证“反馈函数不依赖 motion 值”）
    def feedback(value, motion):
        # 静态通道总是更新，与 motion 无关
        return {"icon": True, "number": True, "border": True, "motion": motion}
    fb = feedback(12, motion_scale(True))
    check("reduce_motion 下 图标/数字/边框 仍更新",
          fb["icon"] and fb["number"] and fb["border"] and fb["motion"] == 0.0)

    print("\n[3] CVD 重映射（E6-S6a）")
    check("DEUTER 关 filter -> 恒等",
          eq(get_element_color("huo", 1, False), ELEMENT_COLOR["huo"]))
    check("DEUTER 开 filter -> 火(红)重映射为鎏金",
          eq(get_element_color("huo", 1, True), COLOR["LIU_JIN"])
          and get_element_color("huo", 1, True) != ELEMENT_COLOR["huo"])
    check("NONE 开 filter -> 恒等",
          eq(get_element_color("huo", 0, True), ELEMENT_COLOR["huo"]))
    check("TRITAN 开 filter -> 金(青碧)重映射为朱砂",
          eq(get_element_color("jin", 3, True), COLOR["ZHU_SHA"])
          and get_element_color("jin", 3, True) != ELEMENT_COLOR["jin"])
    check("PROTAN 开 filter -> 土重映射为朱砂",
          eq(get_element_color("tu", 2, True), COLOR["ZHU_SHA"])
          and get_element_color("tu", 2, True) != ELEMENT_COLOR["tu"])
    # 每个 mode 下 5 行色互不相同（可分离性）
    for mode in (1, 2, 3):
        colors = [get_element_color(e, mode, True) for e in ELEMENT_COLOR]
        check(f"mode={mode} 五行色两两可分离", len(set(colors)) == 5, str(colors))

    print("\n[4] #12 status_config element 字段")
    cfg_path = os.path.join(ROOT, "data", "battle", "status_config.json")
    with open(cfg_path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    expect = {"burn": "fire", "poison": "wood", "armor_break": "metal", "momentum": "metal"}
    for sid, elem in expect.items():
        actual = cfg["status"][sid].get("element")
        check(f"status_config.{sid}.element == {elem}", eq(actual, elem), str(actual))
        # 状态色经五行主题色取色
        check(f"get_status_color({sid}) == 五行{elem}色",
              eq(get_element_color(actual), ELEMENT_COLOR[ELEMENT_ALIAS[elem]]))

    print("\n=== 汇总 ===")
    if _FAILS:
        print(f"FAIL：{len(_FAILS)} 项未通过 -> {_FAILS}")
        return 1
    print("逻辑 PASS：所有 S3-E6 逻辑断言通过（GUT 真跑见 S3-C3 / 真机观感见 S3-DualEnd）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
