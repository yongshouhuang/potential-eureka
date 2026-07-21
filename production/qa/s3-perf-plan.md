# S3 性能测试计划（S3-Perf Performance Test Plan）

> 编制：质量负责人 严守真（quality-lead）
> 阶段：Phase 5 Sprint S3（制作收口）｜性质：**可立即在引擎 / 真机执行的就绪计划**
> 引擎：Godot 4.x（2D-first）｜执行环境：本地 Godot 4.3 + 真机 / 模拟器（沙箱无引擎，本计划不在此执行）
> 对齐：`production/epics/s3-epics-stories.md` §8（S3-Perf DoD）、`production/qa/qa-plan-s3.md` §4（性能门）、`docs/architecture/test-strategy.md` §1.9（性能预算与 GDExtension 触发线）、`art/accessibility-spec.md` Comprehensive P（弱网 / 低性能降级）、`production/qa/s2-vertical-slice-playtest.md` 场景 D（Boss 张力，单场计时）。

---

## 0. 目标与范围

验证 S3 全量资源就位后，核心战斗场景在 **PC 横屏** 与 **移动竖屏** 的性能预算达标，并验证 `performance_mode` 降级链路在低端移动设备可用且降级后不破坏 Basic 可访问性底线。

- **主测场景**：垂直切片 **场景 D（Boss 张力，章节收口）** —— 单场时长预算 2–4min，是战斗负载最重、最贴近真实体验的场景（`s3-status-2026-07-20.md` 已指定「真机 profiling，垂直切片场景 D」）。
- **辅测场景**：场景 A（新档起手最小闭环）用于**全流程内存 / 缓存副本上限**观察（覆盖 C-4 回滚副本占用）。
- **不测**：GUT 内可确定性断言的 `BattleResolver` 单帧 <4ms（进 CI，见 §5）；纯数值平衡（交 design-strategist）。

---

## 1. 性能指标与阈值

| # | 指标 | 预算 / 阈值 | 采集点 | 工具 | Pass / Fail 判据 |
|---|---|---|---|---|---|
| P1 | **包体大小** | **< 300MB**（PC 构建） | 导出 PC 包后读 `.pck`；移动读 APK / IPA | `du -sh` / 平台构建工具 | >300MB → ⚠️ CONCERNS（限期瘦身）；远超预算致无法分发 → FAIL |
| P2 | **PC 帧率** | **≥ 60fps**（均值） | 场景 D 战斗全程采样 | Godot Profiler / 独显 FPS / `OS.get_frames_per_second()` | 稳定 <55fps → ⚠️ CONCERNS；崩溃性卡顿 / 均值 <30 → FAIL |
| P3 | **移动帧率** | **30–60fps**（低端机优先稳帧） | 场景 D 低端真机采样 | 真机 Profiler / 平台 GPU 工具 | <30fps → ⚠️ CONCERNS；明显掉帧致不可玩 → FAIL |
| P4 | **内存峰值** | 无持续上涨 / 无泄漏；cache 副本上限受控 | 全流程（场景 A–D） | Godot Profiler（Memory）/ OS 内存监视 | 内存随场次持续上涨不回落 → **FAIL（泄漏，关联 C-4 回滚副本）** |
| P5 | **performance_mode 降级** | 降纹理 / 降粒子 / 关 3D 演出；降级后 **Basic 仍满足**（对比度 / 三重标识 / 色盲冗余） | 开启 `AccessibilitySettings.performance_mode` 后重测 P2/P3 + Basic 检查 | 开关切换 + 截图比对 | 降级后 Basic 不满足 → **FAIL** |
| P6 | **单场时长** | **2–4min** | 场景 D 计时 | 场景内计时 / 录屏 | >6min 或 <30s 无内容 → FAIL |
| P7 | **BattleResolver 单帧**（CI 层） | **< 4ms** | GUT `test_battle_element` 附断言 | GUT（CI） | 越线 → ⚠️ CONCERNS（提示下沉 GDExtension，test-strategy §1.9） |
| P8 | **五行伤害差** | 克制 vs 被克 **≥ 25%** | 同阵容打克制 / 被克取均值比 | Playtest 记录（非硬性阻断） | 差 <25% → ⚠️ CONCERNS（数值调优） |

> 性能断言分两层：① GUT 内可确定性断言的（P7）进 CI；② 需真机 / 场景的（P1–P6、P8）由**真机 smoke + 回填**验证（不进 CI 硬阻断，但记入门禁，见 `s3-final-qa-gate.md`）。

---

## 2. 工具与前置条件

### 2.1 工具
- **Godot 4.3+ 编辑器 / headless**：内置 **Debugger → Profiler**（CPU / GPU / Memory / FPS）。
- **独显 FPS**：Project Settings → Debug → 勾选 `visible_fps`（或代码 `OS.get_frames_per_second()` 采样均值）。
- **真机性能工具**：Android Studio Profiler / `adb shell dumpsys gfxinfo`；iOS Instruments（Xcode）。
- **包体读取**：导出后 `du -sh build/` 或平台工具读 `.pck` / APK / IPA。
- **降级开关**：设置内 `AccessibilitySettings.performance_mode = true`（来自 accessibility-spec Comprehensive P）。

### 2.2 前置（须先满足）
- [ ] S3 全量资源就位（含 25 张美术资产 + 数据层 13 式神）。
- [ ] 本地已装 Godot 4.3 + 导出模板（PC / Android / iOS）。
- [ ] 真机 / 模拟器可用（见 §6 设备建议）。
- [ ] 同一测试存档（含剑宗 4 人编队，便于触发连携负载）。
- [ ] `performance_mode` 开关已接通 `UIThemeController` 降级路径（E6-S6 AC4）。

---

## 3. 执行步骤

### 3.1 PC 端（≥1024 横屏，示例 1280×720 / 1440×900）
1. 编辑器打开项目 → 载入场景 D（Boss 关）→ 进战斗。
2. 开启 **Debugger → Profiler**，勾选 **FPS / Frame Time / Memory**。
3. 跑完整场（含技能 / 连携横幅 / 状态 DoT 跳动），**录屏 + 记录时长**。
4. 读 Profiler：战斗全程 **FPS 均值 ≥ 60**、单帧 Frame Time 稳定；记录 **内存峰值**。
5. 导出 PC 包（release）→ 读 `.pck` 大小，断言 **< 300MB**（P1）。
6. 开启 `performance_mode` → 重跑场景 D，确认纹理 / 粒子 / 3D 演出降级且 **Basic 三重标识仍可见**（P5）。

### 3.2 移动端（<768 竖屏，示例 390×844 / 360×800）
1. 真机安装导出 APK / IPA → 载入场景 D → 进战斗。
2. 接 **Android Studio Profiler / Instruments**，采样 **FPS / Memory** 全程。
3. 记录低端机 **FPS 区间（目标 30–60，优先稳帧）** 与 **内存峰值**（P3 / P4）。
4. 单场**计时**（P6）。
5. 开启 `performance_mode` → 重跑，确认降级生效且 **Basic 仍满足**（P5）；低端机优先稳 30fps。

### 3.3 内存 / 缓存副本（场景 A 全流程）
1. 场景 A 新档起手 → 抽 1 → 养 1 → 编队 → 首关战 → 结算回流，**循环 3–5 次**。
2. Profiler Memory 观察：每次结算后内存是否**回落**（无持续上涨）；确认 `SaveManager` 磁盘 `_cache` 副本上限受控（关联 C-4）。
3. 持续上涨不回落 → 开 Bug 回 eng（判定 P4 FAIL）。

---

## 4. 数据采集模板（回填 `production/qa/`）

```
=== S3-Perf 采集记录 ===
日期 / 执行人 / Godot 版本：
设备（PC 配置 / 移动机型 + 分辨率）：

| 指标 | 目标 | 实测 | 判定 |
|---|---|---|---|
| 包体(PC .pck) | <300MB |  ___ MB | PASS/CONCERNS/FAIL |
| PC fps(场景D均值) | ≥60 |  ___ |  |
| 移动 fps(低端机) | 30–60 |  ___ |  |
| 内存峰值(场景A循环) | 无泄漏 |  ___ MB |  |
| performance_mode 降级后 Basic | 满足 |  是/否 |  |
| 单场时长(场景D) | 2–4min |  ___ |  |
| BattleResolver 单帧(CI) | <4ms |  ___ | （P7 进 CI） |

截图 / 录屏路径：
降级前后对比截图：
结论：PASS / CONCERNS(登记Bug#__) / FAIL(回eng)
```

---

## 5. Pass / Fail 判定总表

| 情形 | 判定 | 处置 |
|---|---|---|
| P1–P6 全达标 | **PASS** | 关闭 S3-Perf（DoD4） |
| 包体略超 300MB / PC 稳定 55–59fps / 移动 临界 28–30fps / 单场临界 | ⚠️ CONCERNS | 限期优化，登记 Bug，不阻断放行 |
| 移动 <30fps 明显掉帧不可玩 | ⚠️→FAIL | 开 Bug 回 eng 修复后重验 |
| 内存持续上涨（泄漏）/ performance_mode 降级后 Basic 不满足 | **FAIL** | 开 Bug 回 eng（关联 C-4 / E6-S6） |
| 单场 >6min 或 <30s 无内容 | **FAIL** | 开 Bug（数值 / 流程） |
| P7（BattleResolver 单帧 <4ms）越线 | ⚠️ CONCERNS（CI） | 提示下沉 GDExtension（test-strategy §1.9） |

> 本计划为**环境阻塞项**：沙箱内无 Godot / 真机，不在此执行。结果待 PAT 到位、推送后在真机回填（见 `s3-final-qa-gate.md` §3 #2）。

---

## 6. 真机设备建议

| 端 | 推荐设备 | 分辨率 | 说明 |
|---|---|---|---|
| **PC（目标）** | 主流配置（如 i5 / 16GB / 独显） | 1280×720、1440×900 | 验 ≥60fps |
| **PC（最低）** | 集显机型（如 i5 / 8GB / 核显） | 1280×720 | 验帧率下限与降级 |
| **移动（主流）** | 骁龙 8xx / 天玑 9xxx + 8GB | 390×844、360×800 | 验 30–60fps 上限 |
| **移动（低端·关键）** | 骁龙 6xx / 联发科中端 + 4GB | 360×800 | 验 30fps 稳帧 + performance_mode 降级必过 |
| **iOS（可选）** | iPhone SE / 中端 | 390×844 | 验帧率 + Basic 观感 |

> 低端移动为 **P3 / P5 的关键验证对象**：必须能经 `performance_mode` 降级稳 30fps 且 Basic 不破。

---

## 7. 风险与依赖

- **依赖前置**：S3-Perf 依赖「全量资源就位」（§2.2）。资源未齐则包体 / 帧率无效。
- **降级链路**：`performance_mode` 须已接通 `UIThemeController` 降级（E6-S6 AC4），否则 P5 无法测。
- **泄漏风险**：`SaveManager` 磁盘 `_cache` 副本若无限增长 → P4 FAIL（关联 C-4 机制）。
- **C-3 联动**：P7（BattleResolver 单帧）由 GUT CI 断言，须 C-3 门禁先立（见 `s3-final-qa-gate.md` §2.3）。
