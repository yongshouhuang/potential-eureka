# M3 抽卡屏 UI 收口 · QA 计划与烟雾测试用例

> **项目**：仙侠卡牌项目（XiaXia）｜**阶段**：M3 抽卡表现与 UI 收口（Closeout）
> **引擎/平台**：Unity UGUI / Android 竖屏（1080×2340，Match=Height）
> **文档类型**：QA 计划（文档级）＋ 烟雾测试用例（Smoke Test Cases）
> **执行方式**：⚠️ **本文档为手工烟雾测试清单，需在本地 Unity 编辑器逐步执行**。沙箱无法运行 Unity，本计划不跑引擎；自动化证据见 §7（headless 单测可 `dotnet test` / Unity EditMode 先跑）。
> **编写**：quality-lead（严守真）｜**基准规格**：`design/gdd/m3-ui-closeout.md` v 收口版
> **配套代码真源**：`src/unity/Features/Gacha/**`、`src/unity/Features/Shared/Events/GachaEvents.cs`

---

## 0. 阅读须知与测试环境前置

### 0.1 六态状态机（测试判定基准）
`GachaScreenController.GachaScreenState`：

`Idle → PoolSelected → Rolling → Reveal → ResultList →（InsufficientCurrency 子态，挂在 PoolSelected 下）`

- **InsufficientCurrency** 是 `PoolSelected` 的可支付性子态：余额 `< 单抽消耗` 时进入；货币达标后回 `PoolSelected`。
- **Rolling / Reveal** 期间按钮锁定（`RefreshPullButtons` 的 `locked` 位），`ResultList` / `PoolSelected` 恢复可点（修复"只能点一次"）。

### 0.2 本地 Unity 执行前置（必做）
1. 打开抽卡屏场景（含 `Bootstrapper` 空 GameObject + `GachaScreenController` + `AudioService`）。
2. 在 `Bootstrapper` 检视面板确认：
   - `_seedFuLu`（默认 **50**）：初始符箓测试种子。**余额相关用例需临时改此值**（见各用例前置）。
   - `_seed`（默认 1）：随机种子，固定可复现。
3. `GachaScreenController` 检视面板字段（定位用）：
   - `_currencyLabel`（顶栏符箓绝对值）、`_resultSummary`（「获得 X 式神 · 含 N SSR」）、`_resultCardPrefab`、`_revealArea`
   - `_singlePull`、`_tenPull`、`_insufficientCta`（CTA 按钮）、`_againButton`、`_skipCatcher`
   - `_autoLayout`（灰盒自动摆位，默认 true；正式美术接入应取消勾选）
4. 运行模式：Play 后进入抽卡屏。所有用例以 **Play 模式 + Console 窗口** 为基础。
5. 控制台日志关键字（用例判定用）：
   - CTA 意图事件：`[Gacha] AcquireIntent received: reason=battle (gray-box stub; real nav TBD)`
   - 保底：`[Gacha] Pity ...`（若有）等（以实际 `Debug.Log` 为准）。

### 0.3 判定术语
| 词 | 含义 |
|---|---|
| **PASS** | 实际结果 == 预期结果，且判定标准全部满足 |
| **CONCERNS** | 功能无阻断，但存在灰盒/待拍板/测试性缺口，需主理人收口时知悉 |
| **FAIL** | 出现崩溃、异常、重复扣费、状态卡死、或任一硬判定不满足 |
| **判定标准** | 该用例 PASS/FAIL 的明确、可观察的边界条件 |

---

## 1. 测试对象与符号索引（定位表）

> 供测试员在 Inspector / 代码中快速定位，避免"找不到对象"。

| 关注点 | 代码符号（文件） | 说明 |
|---|---|---|
| 控制器 | `GachaScreenController`（`UI/GachaScreenController.cs`） | 六态 + Reveal 序列器 |
| 抽卡入口 | `OnPull(int count)` | `count=1` 单抽 / `count=10` 十连 |
| 扣费/可支付 | `CanAfford(int)`、`IGachaService.GetPullCost(poolId,count)`、`IEconomyService.GetBalance("fu_lu")` | 标准池：单抽 1、十连 10 |
| 顶栏货币 | `_currencyLabel.text = GetBalance("fu_lu").ToString()` | 绝对值（H4） |
| 结果汇总 | `_resultSummary.text = $"获得 {n} 式神 · 含 {ssr} SSR"` | ResultList 态 |
| CTA 按钮 | `_insufficientCta`（`ShowInsufficientCta(bool)`） | InsufficientCurrency 态显示 |
| CTA 点击 | `OnInsufficientCta()` → `Publish(new GachaAcquireIntentEvent{Reason="battle"})` | **H-C1 核心** |
| CTA 事件 | `GachaAcquireIntentEvent`（`<Shared/Events/GachaEvents.cs>`） | `Reason` 默认 `"battle"` |
| CTA 订阅（灰盒） | `Bootstrapper.Awake`：`bus.Subscribe<GachaAcquireIntentEvent>(e => Debug.Log(...))` | **仅日志，无真实跳转** |
| 跳过 | `_skipCatcher` → `SkipReveal()`（`_skip=true`） | Reveal 期任意处点击 |
| 翻面 | `FlipController.BeginFlip(reduceMotion)` / `ShowBack/ShowFront/ForceFront` | 纯视觉 |
| 错峰时间轴 | `RevealSchedule.Build/TotalDuration`、`RevealTiming`（CardStagger=0.08、NormalFlipDuration=0.5、SsrFlipDuration=0.7、RevealSwapOffset=0.25） | 十连波浪 |
| 减少动效 | `IAccessibilitySettings.ReduceMotion`（键 `accessibility_reduce_motion`）；`GachaScreenController._reduceMotion` 被其覆盖 | **⚠ 见 §6 规格冲突-3** |
| 重编译兜底 | `Bootstrapper.Awake`：`_gachaScreen ?? FindObjectOfType<GachaScreenController>()` | 序列化引用丢失时按类型查找 |

---

## 2. 烟雾测试用例总览（矩阵）

| ID | 标题 | 关联需求 | 严重度 |
|---|---|---|---|
| S-01 | 单抽主链路（验证"只能点一次"已修复） | 主链路 / UX §2.2 | Blocker |
| S-02 | 十连主链路 | 主链路 / UX §2 | Blocker |
| S-03 | 连续抽卡（余额递减无误） | 主链路 / H4 | Critical |
| S-04 | 余额不足 CTA（H-C1 核心） | §3 / H-C1 | Blocker |
| S-05 | CTA 显隐（余额恢复回 PoolSelected） | §3.4 | Critical |
| S-06 | 边界：余额刚好 = 单抽费 | 边界 / UX §3.1 | Major |
| S-07 | 边界：余额刚好 = 十连费 | 边界 / UX §2.2 | Major |
| S-08 | 边界：余额 = 0 | 边界 / UX §3.5 | Major |
| S-09 | 抗压：Reveal 期间狂点按钮（无重复扣费） | 抗压 / UX §2.3 | Critical |
| S-10 | 抗压：重编译后 Bootstrapper 字段绑定兜底 | §0 / ADR-3 | Major |
| S-11 | 抗压：reduce_motion 瞬翻 + SSR 静态边框 | §1.3/§1.5 / Standard I | Major |
| S-12 | 补充：Reveal 期间点击跳过 → 立即定格 → ResultList | §1.3 / UX §1 | Minor |
| S-13 | 补充：SSR 落非末位（climax 独立） | §1.5 | Minor |
| S-14 | 回归：H1 保底阈值/不跨池不被破坏 | H1 | Blocker |
| S-15 | 回归：H2 式神名/稀有度显示正确 | H2 | Critical |
| S-16 | 回归：H3 式神目录（卡显示非空名） | H3 | Critical |
| S-17 | 回归：H4 货币绝对值（顶栏递减精确） | H4 | Critical |

> 用例计数：**17 条**（覆盖主理人要求的 7 大块 + 4 条回归 + 2 条补充抗压强健性用例）。

---

## 3. 详细烟雾测试用例

> 每条格式：**前置条件 / 操作步骤 / 预期结果 / 判定标准**。

### S-01 · 单抽主链路（验证"只能点一次"已修复）
- **前置条件**：`_seedFuLu ≥ 1`（标准池单抽费=1）；进入场景后状态应为 `PoolSelected`，顶栏符箓显示初始值（如 50）。
- **操作步骤**：
  1. 记录顶栏符箓数 `B0`（如 50）。
  2. 点击「单抽 -1 符箓」。
  3. 观察：进入 `Rolling`（按钮禁用 + rolling loop）→ 同步 `Pull` 返回 1 张 → `Reveal` 该卡翻面（0.5s）→ `ResultList`。
  4. 读结果汇总 `_resultSummary`，记录 SSR 数 `S`。
  5. **再次点击**「单抽 -1 符箓」（验证按钮已恢复）。
- **预期结果**：
  - 顶栏符箓 `B0 → B0-1`。
  - 翻面完成，卡显示式神名/稀有度（N/R/SR/SSR）。
  - 汇总文本 = `获得 1 式神 · 含 S SSR`。
  - 进入 `ResultList` 后按钮**可再次点击**（不再永久禁用）。
- **判定标准（PASS）**：符箓精确 -1；汇总文案匹配；第二次点击成功触发下一次抽卡且无异常。**FAIL**：按钮永久 disabled（"只能点一次"复发）/ 扣费 ≠1 / 文案错。

### S-02 · 十连主链路
- **前置条件**：`_seedFuLu ≥ 10`（标准池十连费=10）；状态 `PoolSelected`。
- **操作步骤**：
  1. 记录 `B0`。
  2. 点击「十连 -10 符箓」。
  3. 观察：`Rolling` → `Pull` 同步返回 10 张 → `Reveal` 按 `CardStagger=0.08s` 错峰逐张翻面（十连纵向列表）→ `ResultList`。
  4. 数清翻面卡数 = 10，记录 SSR 数 `S`。
  5. 读汇总，点击「再来一次 / 单抽」验证可再抽。
- **预期结果**：符箓 `B0 → B0-10`；展示 10 张卡；汇总 = `获得 10 式神 · 含 S SSR`；可再次抽。
- **判定标准（PASS）**：扣费精确 -10；卡数=10 且错峰（非齐发）；文案匹配；可再抽。**FAIL**：卡数≠10 / 齐发 / 扣费错 / 卡死。

### S-03 · 连续抽卡（余额递减无误）
- **前置条件**：`_seedFuLu ≥ 5`（标准池）；状态 `PoolSelected`。
- **操作步骤**：
  1. 记录 `B0`。
  2. 连续点「单抽」5 次，每次都等到 `ResultList` 且按钮恢复后再点下一次。
- **预期结果**：每次符箓 -1，依次 `B0, B0-1, ..., B0-5`；无卡死、无重复扣费、无负数透支。
- **判定标准（PASS）**：5 次后符箓 = `B0-5`，且过程中未进入 `InsufficientCurrency`（因余额始终 ≥1）。**FAIL**：某次未扣/多扣/透支。

### S-04 · 余额不足 CTA（H-C1 核心）⭐
- **前置条件**：临时将 `Bootstrapper._seedFuLu = 0`（或把符箓耗到 `< 单抽费`）；进入场景。
- **操作步骤**：
  1. 进入场景，观察状态：因 `CanAfford(1)==false` → `SetState(InsufficientCurrency)`。
  2. 确认 `_insufficientCta` 显示（CTA 按钮可见）。
  3. 点击 CTA 按钮。
  4. 观察 Console 与 UI 行为。
- **预期结果**：
  - 进入 `InsufficientCurrency` 态，单/十连按钮置灰（`PullButton.SetDisabledInsufficient`：锁 glyph + 信息灰 `#8A9599` + `interactable=false`）。
  - CTA 点击触发 `OnInsufficientCta()` → `Publish(GachaAcquireIntentEvent{Reason="battle"})`。
  - `Bootstrapper` 订阅回调 `Debug.Log("[Gacha] AcquireIntent received: reason=battle (gray-box stub; real nav TBD)")`。
  - **UI 不崩溃、不跳转场景**（灰盒下仅日志，无真实导航）。
- **判定标准（PASS）**：CTA 可见且可点；Console 出现上述精确日志串；无 `NullReferenceException`/崩溃；无场景切换。**CONCERNS（已知灰盒）**：仅日志，无真实跳转——见 §6-冲突1。**FAIL**：无日志 / 崩溃 / 误跳转。

### S-05 · CTA 显隐（余额恢复回 PoolSelected）
- **前置条件**：先在 `InsufficientCurrency` 态（同 S-04，余额=0、CTA 可见）。
- **操作步骤**：
  1. 通过任意途径使 `fu_lu` 余额 ≥ 单抽费（如触发 `currency_changed` 使余额恢复；灰盒下可临时改 `_seedFuLu` 并重进场景，或经外部 Grant 事件）。
  2. 观察 `OnCurrencyChanged`：`_state==InsufficientCurrency && CanAfford(1)` → `SetState(PoolSelected)`。
- **预期结果**：CTA 自动隐藏（`ShowInsufficientCta(false)`）；状态回 `PoolSelected`；单/十连按钮恢复可点。
- **判定标准（PASS）**：余额达标后 CTA 消失、按钮恢复、无残留灰态。**FAIL**：CTA 残留 / 状态不回 / 按钮仍禁用。

### S-06 · 边界：余额刚好 = 单抽费
- **前置条件**：标准池设 `_seedFuLu = 1`（余额 = 单抽费，且 `< 十连费`）。
- **操作步骤**：
  1. 进入场景（应 `PoolSelected`，因 `CanAfford(1)==true`）。
  2. 观察单抽按钮（可点）、十连按钮状态。
  3. 点单抽，确认扣到 0。
  4. 抽后观察：余额=0 → `CanAfford(1)==false` → 应进入 `InsufficientCurrency`，CTA 出现。
- **预期结果**：单抽可点且十连**禁用但不弹 CTA**（仅当 `CanAfford(1)==false` 才进 CTA 态）；抽后余额 0 → CTA 出现。
- **判定标准（PASS）**：余额=1 时单抽可、十连禁用且无 CTA；抽后正确进入 `InsufficientCurrency`。**FAIL**：十连可点（应为禁用）/ 余额=1 时误弹 CTA。

### S-07 · 边界：余额刚好 = 十连费
- **前置条件**：标准池设 `_seedFuLu = 10`（余额 = 十连费）。
- **操作步骤**：点「十连 -10 符箓」→ 观察扣费与进入 `InsufficientCurrency`。
- **预期结果**：十连可点，扣 10 → 余额 0 → 进入 `InsufficientCurrency`，CTA 出现。
- **判定标准（PASS）**：十连成功扣 10 并正确进入不足态。**FAIL**：十连被误禁用 / 扣费错 / 不进不足态。

### S-08 · 边界：余额 = 0
- **前置条件**：`_seedFuLu = 0`（强确信不足）。
- **操作步骤**：进入场景，确认状态与 CTA 显隐。
- **预期结果**：进入即 `InsufficientCurrency`，CTA 显示，单/十连置灰。
- **判定标准（PASS）**：首屏即不足态、CTA 可见、按钮禁用。**FAIL**：进入 `PoolSelected` 或按钮可点。

### S-09 · 抗压：Reveal 期间狂点按钮（无重复扣费）⭐
- **前置条件**：`_seedFuLu ≥ 10`；记录 `B0`。
- **操作步骤**：
  1. 点击「十连」进入 `Rolling/Reveal`。
  2. 在 `Rolling/Reveal` 动画期间，**连续狂点**单抽/十连按钮（含「再来一次」在 Reveal 期不可点）。
  3. 等待动画结束到 `ResultList`。
  4. 核对顶栏符箓。
- **预期结果**：`Rolling/Reveal` 期间按钮 `interactable=false`（`OnPull` 首行 `if (_state is Rolling or Reveal) return;` 双重保险）；无论狂点多少次，只扣一次（十连 -10）。
- **判定标准（PASS）**：符箓 = `B0-10`（不多扣）；无重复实例化卡；无异常。**FAIL**：多扣 / 重复卡 / 崩溃。

### S-10 · 抗压：重编译后 Bootstrapper 字段绑定兜底
- **前置条件**：场景已搭好 `Bootstrapper`（含 `_gachaScreen` 引用）。
- **操作步骤**：
  1. 在 Inspector **清空** `Bootstrapper._gachaScreen` 引用（模拟重编译/拖拽丢失）。
  2. 进入 Play。
  3. 观察 `Bootstrapper.Awake` 是否经 `FindObjectOfType<GachaScreenController>()` 兜底找到控制器并 `Initialize`。
  4. 执行一次 S-01 单抽验证功能正常。
- **预期结果**：即使序列化引用为空，仍按类型找到控制器并完成初始化；抽卡主链路可跑。
- **判定标准（PASS）**：清空引用后无 `MissingReference`、抽卡正常。**FAIL**：空引用崩溃 / 控制器未初始化。

### S-11 · 抗压：reduce_motion 开启（瞬翻 + SSR 静态边框）⭐
- **前置条件**：
  - ⚠ **测试性缺口**：灰盒下 `reduce_motion` 由 `IAccessibilitySettings.ReduceMotion`（PlayerProfile.Settings 键 `accessibility_reduce_motion`）控制，`GachaScreenController` 在 `Initialize` 时若注册了该服务会**覆盖**序列化 `_reduceMotion` 默认值（见 §6-冲突3）。
  - 推荐操作：在场景加载前使 `profile.Settings["accessibility_reduce_motion"] = true`（如经临时调试入口/存档注入），再进场景；或**临时**取消 `Bootstrapper` 对 `IAccessibilitySettings` 的注册并勾选 `_reduceMotion` 验证（后者需改代码，**不推荐，仅说明原理**）。
  - `_seedFuLu ≥ 10`（含 SSR 卡池更佳，便于验 SSR）。
- **操作步骤**：
  1. 确认 reduce_motion 已生效（断点/日志观察 `_reduceMotion==true`）。
  2. 点十连，观察翻面。
  3. 重点观察 SSR 卡的 `_imgFrameSweep`（紫宸虹光 overlay）：应**静态显边框、不扫光**。
- **预期结果**：`BeginFlip(true)` 直接 `ShowFront()` 瞬翻；SSR 扫光 overlay 静态显边框不扫（保留 边框+角星+名+数字，信息零丢失）。
- **判定标准（PASS）**：无翻面动画（瞬翻）、SSR 边框静态、信息完整可见。**CONCERNS**：若无法在 Inspector 直接开关，需经存档键验证（见 §6-冲突3）。**FAIL**：仍播动画 / SSR 扫光移动 / 信息丢失。

### S-12 · 补充：Reveal 期间点击跳过 → 立即定格 → ResultList
- **前置条件**：`_seedFuLu ≥ 10`；十连。
- **操作步骤**：进入 `Reveal` 后，点击任意处（`_skipCatcher`）→ 观察。
- **预期结果**：`_skip=true` → 协程退出 → 对全部卡 `ForceFront()` 定格 → 转 `ResultList`；跳过不丢结果（结果以 `results` 为权威源）。
- **判定标准（PASS）**：点击后无卡停留背面、立即进 `ResultList`、汇总正确。**FAIL**：有卡留背面 / 不进 ResultList。

### S-13 · 补充：SSR 落非末位（climax 独立）
- **前置条件**：`_seedFuLu ≥ 10`；卡池含 SSR 且本次 SSR 落第 2–9 张（可用固定 `_seed` 复现）。
- **操作步骤**：十连，观察 SSR 卡（非末位）的 `SsrClimaxTime` 独立触发、末张决定 `TotalDuration`。
- **预期结果**：SSR 峰值 cue 挂在该卡独立时间轴，不拖慢整体；`TotalDuration` 取末张（无论稀有度）。
- **判定标准（PASS）**：SSR 非末位时 climax 正确、整体按时进 `ResultList`。**FAIL**：climax 错位 / 卡死。

---

## 4. 回归检查（H1–H4，收口后不被破坏）

> 硬证据：以下 Unity headless 单测（`src/unity/Features/Gacha.Tests/`）对应实现已 green；烟雾用例用于验证**收口改动未破坏**这些行为。

| ID | 硬证据（单测名） | 烟雾验证点（手动） |
|---|---|---|
| **H1** 保底阈值/不跨池 | `GachaTests.HardPity_ForcesSsrOn90th`、`SoftPity_RateGeq50ThenRises`、`Pity_NotCrossPool`、`PityModel_DetectCrossing_SoftAndHard`；UI `PityProgressBar.DetectCrossing/Bind` | S-14：连续抽至接近保底，观察进度条软/硬保底提示音与重绑；切池后保底不继承（S-01~S-03 用默认池，保底计数独立）。 |
| **H2** 式神名/稀有度 | `GachaTests.Newbie_ForcedStarterSr`；`ResultCard.Setup` 显 `meta.DisplayName` + `rarity.ToString()` | S-15：翻面后卡显示式神名（非空）+ 稀有度文本 `N/R/SR/SSR` + 角星 1/2/3 与边框档位一致。 |
| **H3** 式神目录 | `ShikigamiCatalog`（读 `data/shikigami/shikigami_defs.json`）；`ResultCard.Setup` 调 `GetMeta/GetCombatStats` | S-16：卡显示**非空**式神名（灰盒占位亦可，但不得为空字符串/缺失）；ATK/HP 数值可见（tabular）。 |
| **H4** 货币绝对值 | `EconomyManager.GetBalance`（余额单一真源）；`GachaScreenController.RefreshCurrency` 用 `GetBalance("fu_lu")` | S-17：顶栏符箓始终显示**绝对值整数**，每次抽后精确递减（S-01/S-02/S-03 已覆盖），不出现累加/负数。 |

### S-14 · 回归 H1
- **前置/操作**：用固定 `_seed` 与足够符箓，连续抽至 pity 接近软/硬阈值（或经测试注入 pity）；观察 `PityProgressBar` 提示与重绑。
- **判定标准**：保底提示触发正确；`GetPity` 不跨池；收口改动未改 `GetPityThresholds` 读池配置逻辑。**FAIL**：保底不触发 / 跨池。

### S-15 · 回归 H2
- **判定标准**：每张卡名与稀有度文本正确、角星/边框档位与稀有度一致。**FAIL**：名空/稀有度错/档位错位。

### S-16 · 回归 H3
- **判定标准**：卡显示非空名；ATK/HP 可见。**FAIL**：名空/缺元数据崩溃。

### S-17 · 回归 H4
- **判定标准**：顶栏绝对值精确递减、无负数、无累加。**FAIL**：数值错/负数。

---

## 5. 用例执行记录表（收口时填写）

| ID | 执行人 | 日期 | 结果(PASS/CONCERNS/FAIL) | 备注/日志摘录 |
|---|---|---|---|---|
| S-01 | | | | |
| S-02 | | | | |
| S-03 | | | | |
| S-04 | | | | `[Gacha] AcquireIntent received: ...` |
| S-05 | | | | |
| S-06 | | | | |
| S-07 | | | | |
| S-08 | | | | |
| S-09 | | | | 狂点后扣费=10 |
| S-10 | | | | 清空引用兜底 |
| S-11 | | | | reduce_motion 路径 |
| S-12 | | | | |
| S-13 | | | | |
| S-14 | | | | |
| S-15 | | | | |
| S-16 | | | | |
| S-17 | | | | |

---

## 6. 规格冲突 / 已知缺口（收口前必须知悉）

> 以下为文档级核对发现的冲突与缺口，**未自行修改代码**，仅标注供主理人拍板。

### 冲突-1（⚠ 关键）：H-C1 仅灰盒日志，真实导航未接
- **现象**：`OnInsufficientCta` 已 `Publish(GachaAcquireIntentEvent{Reason="battle"})`，`Bootstrapper` 订阅仅 `Debug.Log(... gray-box stub; real nav TBD)`。
- **影响**：CTA 点击**不会真正跳转**去推图/商城；灰盒验收只能验证"事件已发 + UI 不崩"。
- **处置建议**：本里程碑若接受"灰盒占位"，则 S-04 判定为 CONCERNS 而非 FAIL；真实导航（H-C1 订阅方 + 场景切换）列为 **后续工程依赖**，需主理人排期。

### 冲突-2（待拍板）：CTA 方向冲突（§3.6）
- **现象**：`m3-ui-closeout.md §3.6` 标出与原 `gacha-screen-mvp.md §1.3` 的方向冲突——「去推图产出符箓」(Battle) vs「获取符箓」(OpenStore)。
- **代码现状**：已实现方向 = **Battle**（`Reason="battle"`，事件名 `GachaAcquireIntentEvent`），与收口推荐（候选 A）一致；`OpenStoreIntentEvent` 方向（H-C2）**未实现**。
- **处置建议**：若主理人最终拍板"OpenStore"，需改 `Reason`/事件名并接对应订阅方；当前实现与推荐一致，无需改。

### 冲突-3（测试性缺口）：reduce_motion 无 Inspector 开关
- **现象**：`GachaScreenController._reduceMotion` 为序列化字段，但 `Initialize` 中若 `IAccessibilitySettings` 已注册（Bootstrapper 恒注册），则 `_reduceMotion = acc.ReduceMotion` **覆盖**该值。Inspector 无直接开关 reduce_motion 的入口。
- **影响**：S-11 手动验证需经 `PlayerProfile.Settings["accessibility_reduce_motion"]=true` 注入（存档/调试入口），不能直接勾 Inspector。
- **处置建议**：建议工程侧补一个 Debug 菜单/Inspector 开关 `AccessibilitySettings.ReduceMotion`，便于 QA 与无障碍验收；当前 S-11 判为 CONCERNS（依赖存档注入）。

### 冲突-4（关注）：十连布局为纵向列表
- **现象**：收口 §2.3 锁"移动竖屏纵向列表"，非多列网格（任务稿曾建议网格）。与 `ux-spec §2.2` 一致。
- **影响**：仅布局决策，无功能冲突；PC 横屏多列留作 ADR-001 回归项。
- **处置建议**：无需改；记录为已锁决策。

---

## 7. 自动化证据（可立即跑，不依赖 Unity 播放器）

> 下列 headless 单测覆盖 H1/H2/Reveal/Pity 纯逻辑，**可在沙箱 `dotnet test` 或 Unity EditMode 先跑**，作为收口冒烟的"绿底"。

| 测试程序集 | 关键用例 | 覆盖 |
|---|---|---|
| `Features.Gacha.Tests`（`GachaTests.cs`） | `HardPity_ForcesSsrOn90th`、`SoftPity_RateGeq50ThenRises`、`Pity_NotCrossPool`、`Newbie_ForcedStarterSr`、`Newbie_HalfPrice20PullsCost10`、`Rates_WithinTolerance`、`Decoupling_NoManagerFieldReference` | H1/H2/保底/解耦红线 |
| `Features.Gacha.Tests`（`RevealAndPityTests.cs`） | `RevealSchedule_TenPull_StaggersBy0_08`、`RevealSchedule_SsrClimaxOnlyForSsr`、`RevealSchedule_TotalDuration_LastCard`、`PityModel_*` | 错峰时间轴 / 保底公式 |

**建议**：收口前先跑 `dotnet test`（或 Unity Test Runner → EditMode）确认上述全绿，再执行 §3 手工烟雾。若任一自动化失败，直接 FAIL 收口、回 engineering。

---

## 8. 质量门判定草稿（供主理人收口套用）

> 以下为**建议性**质量门（advisory）。最终放行由主理人/用户决定。

### 8.1 PASS（可放行）
满足**全部**：
1. S-01、S-02、S-03、S-09、S-14~S-17 全 **PASS**（主链路 + 抗压无重复扣费 + 回归 H1–H4 未被破坏）。
2. S-04 **PASS**（CTA 事件已发 + Console 日志出现 + UI 不崩）；H-C1 真实导航缺口已**显式记录为后续依赖**且主理人知悉（不阻断本里程碑灰盒验收）。
3. S-05~S-08、S-10、S-12、S-13 全 **PASS**（边界/抗压/跳过/兜底）。
4. S-11 **PASS 或 CONCERNS**：若 reduce_motion 经存档注入验证瞬翻+SSR 静态，则 PASS；若仅因无 Inspector 开关未充分验证，标记为 CONCERNS 不阻断。
5. §7 自动化单测全绿；Play 模式 **无 Console 异常/崩溃**（无 `NullReferenceException` 等）。
6. §6 四个冲突项均已在收口记录中**标注并主理人知悉**。

### 8.2 CONCERNS（带病放行，需主理人签字）
出现以下任一，记为 CONCERNS（功能无阻断，但需显式知悉）：
- H-C1 仅灰盒日志、真实导航未接（冲突-1）——本里程碑可接受灰盒占位，但须排期补真实跳转。
- reduce_motion 无 Inspector 开关、S-11 验证不充分（冲突-3）。
- CTA 方向（Battle vs OpenStore）尚未最终拍板（冲突-2）——当前实现=推荐方向，风险低。
- S-13（SSR 非末位）因 RNG 难稳定复现，仅抽样通过。

### 8.3 FAIL（不可放行，回 engineering）
出现**任一**：
- 主链路 S-01/S-02 崩溃、扣费错误、状态卡死。
- S-09 狂点导致**重复扣费 / 重复卡实例化**。
- S-04 CTA 点击**无事件/无日志/崩溃/误跳转**。
- 回归 H1–H4（S-14~S-17）任一被破坏（如保底不触发、名空、货币负数/累加）。
- §7 自动化单测任一变红。
- Play 模式出现未处理异常导致卡死。

### 8.4 质量门结论模板（收口时由主理人填写）
```
里程碑：M3 抽卡屏 UI 收口
质量门判定：[ PASS / CONCERNS / FAIL ]
放行签字：________ 日期：____
CONCERNS 项（若选）：____________________________
回 engineering 项（若 FAIL）：____________________
```

---

## 9. Bug 报告模板（执行中发现时填）

```
[Bug] <标题>
严重度：Blocker / Critical / Major / Minor
关联用例：S-xx
环境：Unity <版本> / 平台 / 种子(_seed) / _seedFuLu
前置：...
复现步骤：
  1. ...
  2. ...
预期：...
实际：...
日志/截图：...
建议优先级：P0/P1/P2
```

---

*文档结束。本计划为文档级交付，不涉及代码修改、不提交 git。所有代码符号以 `src/unity/Features/Gacha/**` 当前实现为准（已通过 `sync-unity.ps1` 同步）。*
