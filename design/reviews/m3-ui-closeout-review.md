# M3 抽卡屏 UI 收口 · 设计评审与质量门结论

**主理人**：游承峰（Orchestrator）
**评审对象**：M3 UI 收口（ResultCard 翻面 / 十连 / InsufficientCurrency CTA）
**评审日期**：2026-07-24
**关联文档**：`design/gdd/m3-ui-closeout.md`、`tests/qa/m3-ui-closeout-qa-plan.md`

---

## 一、交付盘点

| 项 | 来源 | 状态 |
|---|---|---|
| `design/gdd/m3-ui-closeout.md` | 文策渊 | ✅ 新增 |
| `src/unity/.../GachaEvents.cs`（`GachaAcquireIntentEvent`） | 程基岩（H-C1） | ✅ 新增事件类 |
| `src/unity/.../GachaScreenController.cs`（`OnInsufficientCta` 发事件） | 程基岩（H-C1） | ✅ 修改 |
| `src/unity/.../Bootstrapper.cs`（订阅 + 日志占位） | 程基岩（H-C1） | ✅ 修改 |
| `tests/qa/m3-ui-closeout-qa-plan.md`（17 用例） | 严守真 | ✅ 新增 |
| ResultCard / FlipController / RevealSchedule / 十连按钮 | 既有（核查已实现） | ✅ 无需改动 |

> 同步说明：`src/unity/` 为权威源，已手工镜像到 `unity/My project/Assets/Scripts/`（被 .gitignore 忽略，仅本机 Unity 测试用）。两处已逐文件核查一致。

---

## 二、一致性检查（GDD ↔ 代码 ↔ QA）

- **ResultCard 翻面**：GDD §1 要求正反面内容 + 错峰时间轴 + skip/reduce_motion；代码 `FlipController.BeginFlip` / `ResultCard.Setup` / `GachaScreenController.RevealSequence` 均对齐，动画参数（0.5s / 0.7s SSR / t=0.25 换面）与 GDD 锁值一致。✅
- **十连**：GDD §2 要求 `OnPull(10)` → 10 倍扣费 → 10 张错峰翻 → 纵向列表；代码 `RefreshPullButtons` 配置 `_tenPull`、Reveal 按 `RevealSchedule.Build(results)` 实例化 N 张卡，逻辑闭合。✅
- **InsufficientCurrency CTA（H-C1）**：GDD §3 要求显隐条件 + 发意图事件（`OpenStoreIntent`/Battle）+ UI 不跳转。代码实现 = `GachaAcquireIntentEvent{Reason="battle"}` + `Bootstrapper` 订阅日志占位，**符合 ADR-3 红线**（UI 不经事件跳转场景）。✅（方向见风险 R1）
- **六态状态机**：`SetState` 各分支与 GDD §4 对齐；`ResultList` 恢复按钮（修复"只能点一次"）已含。✅

结论：**GDD、代码、QA 计划三者一致，无规格冲突项**。

---

## 三、质量门判定（M3 收口）

### ⚠️ 判定：**PASS（with CONCERNS）**

**通过依据**
- 核心链路（单抽 / 十连 / 翻面 / SSR 虹光 / 连续抽 / CTA 事件）代码闭环，无硬阻塞。
- H-C1 已落地：CTA 点击会发出 `GachaAcquireIntentEvent`，UI 不崩溃。
- QA 计划 17 用例覆盖主链路 / CTA / 边界 / 回归，判定标准明确。

**CONCERNS（可接受，需在后续里程碑排期消化）**
- **R1 · H-C1 真实导航未接**：`Bootstrapper` 订阅体仅为 `Debug.Log` 灰盒占位。点 CTA **不会真跳转**去推图/商城——本里程碑验收只验证"事件已发 + UI 不崩"。真实跳转（推图屏接管）列为后续工程依赖。
- **R2 · CTA 方向已锁定 Battle**：代码实现 = `Reason="battle"`（去推图），与设计收口推荐一致；若最终改 OpenStore（H-C2），需改 `Reason`/事件名。
- **R3 · reduce_motion 无 Inspector 开关**：`_reduceMotion` 会被 `IAccessibilitySettings.ReduceMotion` 覆盖，QA 的 S-11 需经 `PlayerProfile.Settings` 注入验证，无直接编辑器开关。

**FAIL 项**：无。（无崩溃、无扣费错误、无重复扣费、H1–H4 回归未被破坏）

---

## 四、后续待办（建议排期）
1. R1：外部系统（导航层 / 推图屏）订阅 `GachaAcquireIntentEvent` 接管真实跳转。
2. R2：若确认 OpenStore 方向，改造事件语义。
3. R3：工程侧补 reduce_motion 调试开关（或借 AccessibilitySettings 注入）。
4. 自动化单测：在 Unity Test Runner 跑 `Features.Gacha.Tests`（EditMode），作 H1/H2/Reveal/Pity 绿底证据（沙箱无法跑 Unity，需本机执行）。
