# 变更日志 · S3（DRAFT）

> **状态：DRAFT · 待推送后生效**
> 版本：**v0.3.0**（候选，待推送后打 tag；`project.godot` 当前未设 `application/config/version`）
> 阶段：Phase 5 制作 · Sprint S3（收口）→ Phase 7 发布预备
> 项目：仙侠卡牌 / Xianxia Card Battler（Godot 4.3 LTS，2D-first，双端）
> 生成日期：2026-07-21
> 产出人：release-ops-lead（路远行）

---

## 概述

S3 完成仙侠卡牌 MVP 的**第三制作里程碑**：七个 story 全部收口，逻辑层与结构验收本地全绿，首个**双端可玩构建**就绪。本次更新带来——仓库基线 + GUT CI 门禁、文件级存档回滚、无头核心循环与遥测漏斗、无障碍桥接（MotionScale/CVD）、式神 8→13 数据、双端战斗 UI、以及 25 张美术参考图。

> ⚠️ 本日志为 DRAFT，**所列交付待 `git push` 到远程并触发 GitHub Actions（GUT CI）后正式生效**。CI 结果未出前，请勿对外宣称"已发布"。

---

## 按 Story 交付汇总（7 项）

| # | Story | 对应史诗 | Commit | 交付内容 | 本地验证 |
|---|---|---|---|---|---|
| 1 | **S3-C3 基线 + GUT CI 门禁** | C-3 | `350e1c5` | 仓库基线（Godot 4.3 LTS 钉定、`config/features="4.3"`）；新增 `.github/workflows/gut-ci.yml`，推 `main`/PR 即跑 GUT headless，`-gexit` 失败即红；CI 运行时下载 GUT 9.4.0（`addons/gut` 不入库）；`permissions: contents: read` 最小权限 | CI 配置就位 ⏳ **待推送后触发** |
| 2 | **S3-C4 文件级缓存回滚 + 死字段清理** | C-4 | `b4f5209` | SaveManager/CloudSaveService 文件级 cache 回滚（损坏/IO 失败 → 回滚上一 cache 副本，非仅内存 duplicate）；清理 s2-gate C-4 死配置字段（grep 零残留）；checksum 失败路径 | `s3_c4_python_cache_rollback.py` 通过 ✅ |
| 3 | **S3-E5 无头核心循环 + 遥测漏斗 + 双端** | E5（B5） | `621d763` | 核心闭环编排（主菜单→抽卡→图鉴→养成→编队→推图→结算→资源回流→回抽卡）；遥测漏斗贯通（`gacha:shikigami_obtained`→`cultivate_*`→`battle_*`→`economy:currency_changed`，session 串联、转化率可读）；双端跑通与旋转稳定（PC ≥1024 横屏 + 移动 <768 竖屏，`layout_mode` 三档）；资源断流引导收口（R1） | `s3_e5_python_logic_mirror.py` 通过 ✅ |
| 4 | **S3-E6 无障碍桥接 + MotionScale/CVD + handoff** | E6-S5/S6 | `5e95dbb` | 新增 peer autoload `AccessibilitySettings`（high_contrast / reduce_motion / text_scale 1.0–1.3 / color_blind_mode / cvd_filter / performance_mode / dynamic_text），`accessibility_changed` 信号；MotionScale 动效总线（reduce_motion=0，保留静态等效反馈）；CVD 后处理 shader（按 `color_blind_mode` 切换，Standard G）；Issue #11/#12 交接 | `s3_e6_python_logic_mirror.py` 通过 ✅ |
| 5 | **S3-Asset-Data 13 式神 + R3 放宽至 SSR3** | R3 | `ddec6e3` | `shikigami_defs.json` 8→13（新增 `sr_zhu_que` 火 SR/朱雀、`r_qiu_long` 水、`r_hu_wei` 金、`n_huo_ling` 火、`ssr_zhu_que` 火 SSR/朱雀）；稀有度分布 **N3/R4/SR3/SSR3**；`bond_combos.json` 新增 `yu_zu/long_zu/hu_zu` 三组；`cultivation_config.awaken.skills_by_shikigami` 扩充（朱雀→burn 等）；`skill_defs.json` 12 基础技 + 4 觉醒技（含 `status_on_hit`）；修复 phantom gacha ids（无悬空引用） | `s3_asset_data_python_check.py` **7/7 PASS** ✅ |
| 6 | **S3-UI-Battle 双端战斗 UI** | E4-S6 / D-4 | `c10e2d0` | 按 `battle_ui_constants.json` + `element_shape.gd` 渲染五行形状冗余（圆/三角/方/菱/五边）；移动端精简 HUD、技能按钮热区 ≥44×44；克制三重标识（图标+数字+颜色）、连携横幅、选技/目标选择 UI、气槽控件经 InputBridge 双端可用；状态图标三重冗余（不靠色） | `s3_ui_battle_python_mirror.py` **49/49 PASS** ✅ |
| 7 | **S3-Asset-Art 全量出图 25 张 + 结构验收** | R3 / asset-spec | `d20d63a` | 25 张美术参考图：A1 四式神各 5 视图（朱雀/虬龙/虎威/火灵 × 全身/侧/背/头像/Q版 = 20）+ A2 四状态图标（灼烧/破甲/中毒/气势 = 4）+ A3 连携横幅（1）；结构验收 `verify_s3_art.py` | `verify_s3_art.py` **25/25 PASS（ALL_OK=True）** ✅ |

### 逐 Story 要点

- **S3-C3**：CI 门禁是 S2 遗留 DoD 阻塞项 C-3 的闭环。失败即红、阻断合并；GODOT/GUT 版本已钉定（4.3-stable / 9.4.0）。
- **S3-C4**：玩家存档健壮性。损坏/校验失败自动回滚上一可用 cache 副本，避免进度丢失；死字段清理消除配置歧义。
- **S3-E5**：核心飞轮闭环可在无头环境跑通，遥测漏斗贯通抽→养→战→回流，便于后续 R1 通胀监控与转化分析。
- **S3-E6**：Phase 3 可访问性 CONCERN 闭合——高对比、文本缩放、色盲（Deuter/Protan/Tritan）冗余、减动效均有静态等效反馈；与 UIThemeController 解耦为新 peer autoload。
- **S3-Asset-Data**：式神 8→13，R3 由原 SSR2 锁放宽至 **SSR3**（青龙/白虎/朱雀三 SSR）；五行齐全（金木土水火）；无 phantom 引用。
- **S3-UI-Battle**：战斗 UI 双端落地，五行形状/状态图标均"不靠色"三重冗余；热区 ≥44px 满足移动可触达。
- **S3-Asset-Art**：25 张方向性参考图就位，结构验收全绿（尺寸/宽高比/存在性）。

---

## 已知限制（Known Limitations）

| # | 限制 | 说明 | 影响 | 待办（负责） |
|---|---|---|---|---|
| L1 | **参考级出图非生产级** | 当前立绘 832×1216、图标/头像 1024²、横幅 1280×720；`asset-spec §2.1` 生产级要求立绘 **2048×3072(PC)/1024×1536(移动)**、头像/Q版 512/256、横幅按双端安全区 | 视觉为方向性参考，非最终生产资产 | [待人工] 是否升档重出（art-director） |
| L2 | **S3-Perf 待真机** | 包体 <300MB / PC≥60fps / 移动 30–60fps / `BattleResolver`<4ms；GUT 仅确定性断言 `BattleResolver<4ms`，包体/帧率/单场时长需真机 | 性能预算未最终闭合 | 真机 smoke + 用户回填（CONCERNS 级） |
| L3 | **S3-DualEnd 待真机** | 双端 UI 逻辑层镜像全绿，但场景级/真机核验（灰阶可辨 / 热区 ≥95% / 无裁切）需导出包或编辑器场景 | 双端手感/视觉终审未闭合 | `tests/integration` + 真机（CI 可能降级为人工回填） |
| L4 | **美术视觉终审待人工** | 参考图视觉质量、五行配色、VFX 观感需 art-director 人工终审 | 非 eng 阻塞，但 Demo 视觉验收未闭环 | art-director 终审 |
| L5 | **B-3 选技深度 / qi 门控** | 逻辑层选技路径存在；UI 落地与 qi 资源门控若工时紧可降级为无消耗/回合冷却（须显式记录） | 策略深度可能受限 | 视实现记录 |
| L6 | **CI GUT 未实跑** | 推送前无远程、无 CI 运行；GUT 全量结果待推送后于 GitHub Actions 产生 | 验证真空（等同 S2 CONCERNS 未收敛） | 推送后看 Actions，全绿方为 C-3 闭环 |

> 说明：L2/L3 为 `qa-plan-s3.md` 明确的 CONCERNS 级缺口（非 HARD 阻断）；逻辑层已由 Python 镜像全绿间接验证。L1/L4 为美术范围决策。L6 是发布流程本身的状态，非代码缺陷。

---

## 兼容性与升级说明

- **存档兼容**：存档 schema v1 冻结（含 `free_ten_pull` 解耦、`pity` 不跨池、checksum）；S3 **未改动 schema**，向后兼容。
- **数据向后兼容**：既有 8 条式神字段结构不变，新增 5 条；`skill_defs.json` / `bond_combos.json` 向后兼容（新增觉醒技与 3 个羁绊组）。
- **GUT 不入库**：本地开发需自行安装 GUT v9.4.0 到 `addons/gut`；CI 自动下载，无需提交。

---

## 回滚预案

- **源码回退**：`v0.3.0` tag 即不可变里程碑，可 `git checkout v0.3.0` 或 revert。
- **发布回滚**：若 CI 红或首构建异常——本地 7 commit 均在 `main`，未推送则零风险，补充修复后重推。
- **玩家存档保护**：S3-C4 文件级 cache 回滚，损坏/校验失败自动回滚上一可用 cache 副本。

---

## 配套文档

- 发布就绪检查清单：`production/release/s3-release-checklist.md`
- S3 story 规划：`production/epics/s3-epics-stories.md`
- S3 QA 计划：`production/qa/qa-plan-s3.md`
- 美术视觉评审：`art/s3-art-visual-review.md`（含 L1 升档决策点）
- CI 工作流：`.github/workflows/gut-ci.yml`
