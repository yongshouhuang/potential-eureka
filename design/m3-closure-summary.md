# M3 收口汇编（R1 导航层 + R3 reduce_motion）

**阶段**：M3（抽卡 UI 收口）· 主理人 Phase 8 汇编
**状态**：代码入 main（PASS），红 CTA 实跑闭环 CONCERNS（待用户 Unity 验证）
**提交**：`58f1898` `feat(m3): 收口 R1 导航层 + R3 reduce_motion，并补齐设计交付物`（已 push origin/main）

---

## 1. M3 目标与范围

M3 聚焦抽卡屏（GachaScreen）UI 收口，核心交付两项：

- **R1 导航层**：抽卡屏与推图屏（Battle）之间的真实跳转 + 返回，经 EventBus 意图事件驱动，符合 **ADR-3 红线**（UI 只发意图事件，导航层订阅接管，移除灰盒期双订阅歧义）。
- **R3 reduce_motion**：抽卡屏在 `accessibility_reduce_motion` 开启时降级动画（瞬判定格 / 跳过翻牌动画），由 `IAccessibilitySettings` 注入、经 `PlayerProfile.Settings` 校验。

附加：PityProgressBar 空引用安全访问、设计交付物（导航规格 / 音频规格 / 美术资产）补齐。

---

## 2. 已落地改动（提交 `58f1898`）

| 改动 | 落点 | 说明 |
|---|---|---|
| 新增 `Features/Navigation` | `src/unity/Features/Navigation/` | `NavigationManager.cs` + `Features.Navigation.asmdef`；订阅 `GachaAcquireIntentEvent`（reason=battle → 切 Battle 屏）、`GachaReturnIntentEvent`（→ 回抽卡屏）；订阅/反订阅配对防泄漏 |
| Bootstrapper 注入导航 | `Bootstrapper.cs` | `[SerializeField] NavigationManager? _navigation`，`Awake` 注入 `services` + `bus`；重编译兜底 `FindObjectOfType<NavigationManager>()` |
| 返回意图事件 | `GachaEvents.cs` | 新增 `public sealed class GachaReturnIntentEvent { }` |
| R3 reduce_motion tooltip | `GachaScreenController.cs` | `_reduceMotion` 字段加 Tooltip 说明：由 `IAccessibilitySettings` 覆盖、经 `PlayerProfile.Settings["accessibility_reduce_motion"]` 注入验证（QA S-11） |
| PityProgressBar 安全访问 | `PityProgressBar.cs` | `_mark50/_mark90` 改 `?.` 安全访问，消除空引用 |
| asmdef 引用 | `Features.Gacha.UI.asmdef` | references 加 `"XiaXia.Features.Navigation"`（修复 CS0246） |
| 设计交付物 | `design/gdd/r1-navigation-spec.md`、`design/audio/m4-audio-spec.md`、`design/art/` | R1 导航规格 + 音频规格 + 美术资产 |

---

## 3. 质量门判定

| 验证项 | 结论 | 依据 |
|---|---|---|
| R1 进出闭环（导航 + BACK 返回）| **PASS** | Unity 实跑 Console 日志确认：`🔴 BACK 按钮被点击！执行返回导航。` → `✅ 已返回抽卡屏（闭包缓存）`；GachaScreenRoot 自动重建 + 四字段绑定完整 |
| 红 CTA 完整闭环（符箓=0 → CTA → Battle → BACK）| **CONCERNS** | 代码链路已确认通（`GachaScreenController.OnInsufficientCta` → `GachaAcquireIntentEvent` → `NavigationManager` → Battle 屏 → `GachaReturnIntentEvent` → 返回）；**实跑证据待补**（用户未跑 Unity） |
| R3 reduce_motion 接入 | **PASS（代码）/ CONCERNS（实跑）** | 字段 + tooltip 已落，注入路径由 QA S-11 实跑验证 |
| 设计交付物 | **PASS** | `r1-navigation-spec` / `m4-audio-spec` / `art` 已入库 |
| 代码入 main | **PASS** | `58f1898` 已 push origin/main |

**M3 阶段门控：PASS（带 1 项 CONCERNS 留档）** —— R1 进出闭环为硬指标已 PASS；红 CTA 是同链路"初始态变体"，代码逻辑一致，不构成阻塞。

---

## 4. 已知风险与缓解

- **风险 R-M3-1（红 CTA 实跑未验证）**：若 `Bootstrapper._seedFuLu=0` 时 UI 状态机未正确切到 `InsufficientCurrency`，闭环在视觉层可能断。
  - **缓解**：编辑器脚本 `unity/My project/Assets/Scripts/Editor/GachaSeedSetup.cs` 已就位，菜单 `Tools ▸ Gacha Seed ▸ FuLu = 0 (红 CTA 闭环)` 一键设种子 + 定位 Bootstrapper 物体；用户有空跑 6 步即补证。代码层已确认链路通，风险低。
- **风险 R-M3-2（v0.4.0 tag 未移动）**：`v0.4.0` 仍指向旧提交 `df1889c`（用户选"暂不移动"，因改写公开远端 tag 为高危操作）。
  - **缓解**：待用户明确授权再执行 `git tag -f v0.4.0 58f1898` + `git push -f origin v0.4.0`。当前不影响开发。
- **风险 R-M3-3（双目录镜像）**：`src/unity`（git 源）与 `unity/My project/Assets/Scripts`（编译镜像，gitignored）须逐行一致。
  - **缓解**：M3 改动已在 My project 侧手改/跑通；如需对齐可跑 `sync-unity.ps1`。

---

## 5. 后续（进入 M4 / 待用户验证）

- M4 美术/音频终稿接入收口已完成（见 `design/m4-closure-summary.md`）。
- 待用户 Unity 实跑验证清单：
  1. 红 CTA 完整闭环（GachaSeedSetup `FuLu=0` → Play → 点红 CTA → Battle → BACK）
  2. M4 美术终稿 PNG 接入 prefab + SpriteAtlas + 9-slice
  3. M4 音频终稿 WAV + SoundBank + AudioMixer ducking
  4. M4 七项 eng 钩子（E1–E6 + T4）prefab 字段绑定
