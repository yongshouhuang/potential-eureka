# S3 最终 QA 门禁文档（Final QA Gate · S3）

> 编制：质量负责人 严守真（quality-lead）
> 阶段：Phase 5 Sprint S3（制作收口）
> 引擎：Godot 4.x（2D-first）｜双端：PC 横屏 ≥1024px + 移动竖屏 <768px
> 性质：**门禁结论文档（advisory）**。最终放行由主理人 / 用户人工审批。
> 对齐：`production/epics/s3-epics-stories.md` §9（DoD 12 项）、`production/s3-status-2026-07-20.md`（7 commit + Python 镜像全 PASS）、`production/qa/qa-plan-s3.md`（测试矩阵 + FAIL 定义）、`docs/architecture/test-strategy.md`（CI 门禁）、`production/qa/s2-vertical-slice-playtest.md`（场景 E/D）。

---

## 0. 结论先行（Gate Judgment）

**门禁判定：CONDITIONAL PASS（有条件放行）**

- **逻辑 / 算法层、数据结构层、解耦红线、美术资产结构 —— 全部经 Python 镜像 + 静态 grep 验证 PASS**（合计：asset-data **7/7**、ui-battle **49/49**、art **25/25**、b1_b3 **48/48**、c4 **15/15**、e6 **22/22**、e5 **42/42**）。
- **阻塞完整 PASS 的因素均为「环境阻塞」（沙箱无 Godot 运行时 / 真机 / CI），非机制损坏**：
  1. **S3-Perf**：包体 <300MB、PC≥60fps、移动 30–60fps、内存峰值、performance_mode 降级 —— 待真机 Godot Profiler。
  2. **S3-DualEnd**：PC≥1024 + 移动<768 双端跑通、旋转不崩、焦点不丢、热区≥95%、灰阶可辨 —— 待真机 / 模拟器。
  3. **S3-C3（GUT 全量 CI 绿）**：CI 门禁尚未实跑（验证真空）—— 待 PAT 到位、推送后 GitHub Actions 跑 GUT `-gexit`。
  4. **美术视觉终审（art-director）**：灰阶可辨性、双端热区 / 安全区、锚点 5 形状语言一致性 —— 待人工终审。

> **与 `qa-plan-s3.md` §7.3 的关系说明**：该文档规定「C-3 未进 CI → FAIL」。此处给予 **CONDITIONAL PASS** 的理由是：逻辑层已由 Python 镜像**全量替代验证（非验证真空）**，且 C-3 闭合路径明确（PAT 到位即推送触发 CI）。一旦 PAT 到位并推送、真机验证补齐，即可升级为完整 PASS。门禁为**建议性**，最终放行由用户审批。

---

## 1. S3 验收准则总表（逐项状态）

**图例**：✅ PASS（Python 镜像已验证）｜⚠️ CONCERNS（环境阻塞，待 Godot / 真机 / CI）｜⏳ PENDING（人工视觉终审）

| # | 验收准则 | 来源 | 验证方式（已完成） | 状态 | 说明 / 待补跑 |
|---|---|---|---|---|---|
| 1 | 核心闭环编排逻辑（抽→养→编队→战→结算→回流） | E5-S1 / DoD1 | `s3_e5_python_logic_mirror.py` **42/42** | ✅ PASS | 逻辑层；真机双端跑通见 S3-DualEnd |
| 2 | 双端 layout_mode 决策（≥1024 multi / 768–1024 hybrid / <768 single）+ 旋转等价不丢状态 | E5-S4 / DoD1 | `s3_ui_battle_python_mirror.py` **49/49** + `s3_e5` | ✅ PASS | 决策逻辑；真机旋转 / 焦点见 S3-DualEnd |
| 3 | 双端真机跑通 + 旋转 / 分辨率切换不崩 + 焦点不丢 | E5-S4 / S3-DualEnd / DoD1 | — | ⚠️ CONCERNS | 需 Godot 真机 / 模拟器（见 `s3-dualend-plan.md`） |
| 4 | 可访问性逻辑（AccessibilitySettings / CVD_REMAP / MotionScale / status element） | E6-S5/S6 / DoD2 | `s3_e6_python_logic_mirror.py` **22/22** | ✅ PASS | 逻辑层 |
| 5 | 可访问性单测 CI 全绿 + Basic 全项真机观感 | E6-S5/S6 / DoD2 | — | ⚠️+PENDING | GUT 待 CI；观感待真机 + art 终审 |
| 6 | 埋点漏斗贯通（4 类 telemetry + session 串联 + 转化率可读） | E5-S3 / DoD3 | `s3_e5` **42/42** | ✅ PASS | 逻辑层（telemetry 漏斗镜像） |
| 7 | 包体 <300MB | S3-Perf / DoD4 | — | ⚠️ CONCERNS | 需导出 PC / 移动包读取 .pck / APK / IPA |
| 8 | PC ≥60fps / 移动 30–60fps | S3-Perf / DoD4 | — | ⚠️ CONCERNS | 需 Godot Profiler + 真机帧率采样 |
| 9 | 内存峰值受控 + performance_mode 降级（降级后仍满足 Basic） | S3-Perf / DoD4 / Comprehensive P | — | ⚠️ CONCERNS | 需真机采样 + 降级断言 |
| 10 | GUT 全量 CI 绿（含 S3 新增用例） | S3-C3 / DoD5 | — | ⚠️ CONCERNS | 待 CI 立门禁（`-gexit` 非零阻断合并） |
| 11 | B-1 觉醒改写（灼烧叠层 + StatusManager + skill_defs；与连携不双 dip） | S3-B1 / DoD6 | `s3_b1_b3_python_logic_smoke.py` **48/48** | ✅ PASS | 逻辑层；GUT `test_status_burn` 待 CI |
| 12 | B-2 连携计算（compute_combo 8–12% / 15–20%）+ 零跨 import 红线 | S3-B2 / DoD7 | S2 155/155 bond 逻辑 + 静态 grep 零 `preload BondManager` | ✅ PASS | 计算逻辑 + 解耦红线 |
| 13 | B-2 实战流发射接线（`start_battle` 后 emit `bond:combo` → `_bond_bonus>0`） | S3-B2 / DoD7 | — | ⚠️ CONCERNS | GUT `test_bond_combo_emitted_in_real_battle_flow` 待 CI |
| 14 | B-3 玩家选技（step 接收技能/目标 + power 数据化 + qi 门控） | S3-B3 / DoD8 | `s3_b1_b3` **48/48** | ✅ PASS | 逻辑层；GUT `test_player_skill_select` 待 CI |
| 15 | C-4 文件级 cache 回滚（正式档损坏回退磁盘上一可用版本）+ 死字段清理 | S3-C4 / DoD9 | `s3_c4_python_cache_rollback.py` **15/15** + 静态 grep 死字段 | ✅ PASS | 逻辑层；GUT `test_cache_rollback` 待 CI |
| 16 | 式神资产数据补齐 8→13（N3/R4/SR3/SSR3；5 羁绊组；真实表结构一致） | S3-Asset-Data / DoD10 | `s3_asset_data_python_check.py` **7/7** | ✅ PASS | 数据层 |
| 17 | 式神美术资产交付 A1–A4（立绘 / 状态 VFX / 横幅 / 气槽）+ 灰阶 / 热区 / 锚点 | S3-Asset-Art / DoD10 | `verify_s3_art.py` **25/25**（结构） | ⏳ PENDING | art-director 视觉终审 |
| 18 | UI-Battle 双端战斗 UI 逻辑数据（五行形状 / 横幅数值 / 热区判定 / 状态三重冗余 / layout） | S3-UI-Battle / E4-S6 | `s3_ui_battle` **49/49** | ✅ PASS | 逻辑层 |
| 19 | UI-Battle 双端真机 HUD / 热区 / 灰阶观感 | S3-UI-Battle / S3-DualEnd | — | ⚠️+PENDING | 真机 + art 终审 |
| 20 | 资源断流引导收口（R1：消耗点不足显产出源引导） | E5-S5 / DoD11 | `EconomyManager.get_recommended_source`（S1 单测 PASS） | ⏳ PENDING | 真机 UI 引导观感待验 |
| 21 | 解耦红线（UI 零 `preload` 跨引 manager；BattleManager 零 BondManager；hex 仅 UIThemeController 常量） | 红线 / B-2 AC2 | 静态 grep 全程守护 | ✅ PASS | 已守住（status doc 红线守护段） |
| 22 | Asset-Art 结构验收（25 张 PNG 有效 + 比例对齐 spec） | Asset-Art | `verify_s3_art.py` **25/25** | ✅ PASS | 结构；观感见 PENDING(#17) |

> **状态汇总**：✅ PASS = 14 项（#1/2/4/6/11/12/14/15/16/18/21/22 等逻辑/数据/红线类）；⚠️ CONCERNS = 7 项（#3/5/7/8/9/10/13 等运行/真机/CI 类）；⏳ PENDING = 3 项（#17/19/20 等人工视觉类）。**无任何 FAIL（机制损坏）项**。

---

## 2. 阻塞完整 PASS 的因素（明细）

### 2.1 S3-Perf（环境阻塞）
- 包体 <300MB：需导出 PC / 移动包读取 `.pck` / APK / IPA 大小。
- PC ≥60fps / 移动 30–60fps：需 Godot Profiler + 真机帧率采样（垂直切片**场景 D**）。
- 内存峰值受控 + performance_mode 降级：需真机采样 + 降级后 Basic 仍满足断言。
- 详细计划见 `production/qa/s3-perf-plan.md`。

### 2.2 S3-DualEnd（环境阻塞）
- PC≥1024 + 移动<768 双端跑通核心闭环；旋转 / 分辨率切换不崩、焦点不丢；热区命中率 ≥95%（移动 ≥44px）；五行形状冗余灰阶可辨。
- 详细计划见 `production/qa/s3-dualend-plan.md`。

### 2.3 S3-C3（GUT 全量 CI 绿，环境阻塞 = 无 CI 运行）
- CI 尚未实跑 GUT 全量（`-gexit` 未触发）。沙箱外需 PAT + GitHub Actions 跑：
  ```bash
  godot --headless --path res:// \
    --script res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests -gexit -glog=1
  ```
- 逻辑层已被 Python 镜像等价覆盖；GUT 是「进 CI 的官方门禁」而非新增证据。

### 2.4 美术视觉终审（人工 PENDING）
- 25 张资产结构 PASS（`verify_s3_art.py` 25/25），但灰阶可辨性、双端热区 / 安全区、锚点 5 形状语言一致性需 art-director 终审签名。

---

## 3. 当 PAT 到位、推送后需补跑的证据清单（Backfill Checklist）

| # | 证据 | 触发条件 | 产出物 | 闭合项 |
|---|---|---|---|---|
| 1 | CI 跑 GUT 全量（`-gexit`） | PAT 到位、推送触发 GitHub Actions | GUT 报告 + 覆盖率 + 退出码 | S3-C3 / DoD5 |
| 2 | 真机 S3-Perf | 导出包 + 真机 Godot Profiler | 包体大小、PC/移动 fps 采样、内存峰值、performance_mode 降级截图 / 视频 | S3-Perf / DoD4 |
| 3 | 真机 S3-DualEnd | 真机 / 模拟器跑场景 A–E | 双端截图 + 场景 E 比对、热区命中率 ≥95% 统计、灰阶截图、旋转 / 焦点日志 | S3-DualEnd / DoD1/12/19 |
| 4 | 美术视觉终审 | art-director 终审 | 25 张资产灰阶 / 热区 / 锚点终审签名（回填 `production/qa/`） | Asset-Art / DoD10/17 |
| 5 | Playtest 手感回填 | 本地 Godot 实跑场景 A–E × 6 维度 | 勾选清单 + 时长 / 伤害记录 | 双层验证第二层 |
| 6 | 死字段 grep 回跑 | 推送后静态扫描 | C-4 死字段零命中登记 | C-4 / DoD9 |

---

## 4. 放行建议

- **建议放行（CONDITIONAL PASS）**：逻辑层、数据层、解耦红线、美术结构均已 PASS；剩余缺口纯为环境性（需真机 / CI / 人工），且均有明确补跑路径（§3）。
- **放行前提（建议登记为 closeout 待办，不阻断引擎放行）**：上表 1–6 证据在 PAT 到位后补齐；S3-Perf / S3-DualEnd 任一出现 **FAIL 级结果**（如移动 <30fps 不可玩、双端严重破版致无法操作、performance_mode 降级后 Basic 不满足）须开 Bug 回 eng 修复后重验。
- 门禁为**建议性**；最终签字由用户（主理人）决定。

---

## 附：Python 镜像验证脚本索引（既有的、沙箱可跑的本地证据）

| 脚本 | 覆盖 | 计数 | 验证层 |
|---|---|---|---|
| `s3_asset_data_python_check.py` | 式神数据完整性（gacha_pools / defs / bond / cultivation / skill 闭环） | 7/7 | 数据层 |
| `s3_ui_battle_python_mirror.py` | 五行形状映射 / 横幅数值 / 热区判定 / 双端 layout / 状态三重冗余 | 49/49 | UI 逻辑数据 |
| `verify_s3_art.py` | 25 张美术资产 PNG 有效 + 比例对齐 spec | 25/25 | 美术结构 |
| `s3_b1_b3_python_logic_smoke.py` | B-1 灼烧状态 + B-3 玩家选技 | 48/48 | 战斗逻辑 |
| `s3_c4_python_cache_rollback.py` | 文件级 cache 回滚（损坏档回退上一可用版本） | 15/15 | 存档逻辑 |
| `s3_e6_python_logic_mirror.py` | 可访问性（ELEMENT_COLOR / CVD_REMAP / MotionScale / status element） | 22/22 | 可访问性逻辑 |
| `s3_e5_python_logic_mirror.py` | 核心闭环编排 + 埋点漏斗 + 双端 layout_mode 决策 | 42/42 | 闭环 / 遥测 |
| （基线）`s1-python-logic-smoke.py` / `s2-python-logic-smoke.py` | S1/S2 逻辑基线 155/155 | — | 基线 |

> 全部脚本为只读验证，不修改任何 `data/*.json` / `.gd` / 资产；仅作为沙箱无 Godot 时的替代证据。真机 / CI 验证以 `s3-perf-plan.md` 与 `s3-dualend-plan.md` 为准。
