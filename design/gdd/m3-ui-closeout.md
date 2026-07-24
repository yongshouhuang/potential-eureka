# 仙侠卡牌项目 · M3 抽卡屏 UI 收口 UX 规格（Closeout Spec）

> **阶段**：M3 抽卡表现与 UI（灰盒核心循环已验证通过）｜ **引擎/平台**：Unity UGUI / Android 竖屏（1080×2340，Match=Height）
> **定位**：本文件是 M3 抽卡屏的**收口（Closeout）UX 规格**——不是新需求，而是把已落地的灰盒实现（`GachaScreenController` / `FlipController` / `ResultCard` / `PullButton` / `RevealSchedule`）+ 既有预制作规格（`design/ux/gacha-screen-mvp.md`、`art/gacha-ui-asset-spec.md`、`design/ux/ux-spec.md`、`art/art-bible.md`、`art/accessibility-spec.md`）**收口为一份权威、可直接落地/对接终稿的 UX 真源**。
> **对齐基线**：`design/ux/ux-spec.md` §2.2 Summon、`design/ux/gacha-screen-mvp.md`（六态 / §2.4 ResultCard / §3.1 主链路）、`art/art-bible.md`（§2/§5/§7/§8/§10）、`art/gacha-ui-asset-spec.md`（§1/§2/§5/§6）、`art/accessibility-spec.md`（Basic/Standard）、`02a-gdd-mvp.md` §B2 抽卡。
> **编写**：design-strategist（文策渊）。
> **范围**：仅锁 ResultCard prefab + 翻面动画、十连按钮、InsufficientCurrency CTA 三块的最终 UX 决策；不写代码、不改代码。代码符号以 `src/unity/Features/Gacha/UI/` 当前实现为准（已通过 sync-unity.ps1 同步至 `unity/My project/Assets/Scripts/`）。

---

## 0. 收口范围与"已锁 / 待定"说明（必读）

M3 灰盒六态状态机（Idle / PoolSelected / Rolling / Reveal / ResultList / InsufficientCurrency）已端到端跑通（见 `outputs/m3-overview.md` v0.4.0，41/41 全绿）。本收口规格的任务是：

1. **把分散在多处、且与代码已实现参数一致的决策，收口为一份权威表**（翻面动画参数、FlipController 职责、十连流程）。
2. **正式定义 InsufficientCurrency CTA 的「意图事件」行为**——这是相对 `gacha-screen-mvp.md §1.3` 占位文案的**设计升级/补充**（原仅"去推图"占位，现升级为"发意图事件、由外部订阅"），并标出与原 spec 的**方向冲突待用户拍板**。
3. **列出工程依赖**（CTA 意图事件为本次收口新引入的缺口，非 M2 H1–H4）。

> 标注约定：**已锁**（与代码/既有 spec 一致，直接落地）、**待拍板**（需主理人定方向）、**工程依赖**（需 engineering 补）。

---

## 1. ResultCard prefab + 翻面动画（已锁）

### 1.1 卡片正反面内容

术语对齐代码（`FlipController._back` / `_front`、`ResultCard`）：翻面**前**显示 = 卡背（正面），翻面**后**显示 = 式神信息（背面）。灰盒阶段用占位，终稿按 `art/gacha-ui-asset-spec.md §7.3` 同名 Sprite 替换，业务零改。

| 面 | 内容（灰盒占位） | 终稿资产（`gacha-ui-asset-spec.md §1/§7.3`） | 可访问性约束 |
|---|---|---|---|
| **正面（翻面前·卡背）** | 纯色/纹理方块 + 灵光升腾主题占位 | `imgCardBack`（卡背 sprite：玉质面板+云纹/符文，与卡框同尺寸） | 卡背不承载稀有度信息（避免纯色混淆，accessibility E） |
| **背面（翻面后·式神信息）** | 式神名占位 / 稀有度占位 / 式神图标占位 | `txtShikigamiName`(H2) + `txtRarity`(N/R/SR/SSR) + `rawPortrait`(立绘占位) + `imgFrame*`(四档框) + `imgStar*`(角星 1/2/3) + `txtATK`/`txtHP`(tabular) + `imgElementGlyph`(五行形状) | **三重冗余（Basic E）**：颜色+边框纹理+角星 1/2/3；五行=图标+形状（圆/三角/方）；数值 tabular（Basic C）；式神名月白 `#E8ECEF` on 深墨 `#122426` ≥4.5:1（Basic A） |

- 比例：**竖版 2:3**（锚点4 / art-bible §5）；立绘占卡面 60%（`gacha-ui-asset-spec.md §1.1`）。
- 稀有度四档边框/纹理/角星映射（已锁，见 `ResultCard.ShowFrame/ShowStars`）：
  - N 凡品 `#9AA3A6` 素灰细边 / **0 星**（无星即一档）；
  - R 灵品 `#4FA39B` 青碧细边 / **1 星**（圆点）；
  - SR 宝品 `#CBA75C` 鎏金浮雕边+角饰 / **2 星**（双菱）；
  - SSR 仙品 `#8B6DB3` 紫宸虹光边+动态光扫 overlay(`imgFrameSweep`) / **3 星**（钻星）。

### 1.2 翻面触发时机（已锁·对齐 `GachaScreenController.RevealSequence` + `RevealSchedule`）

- **仅在 Reveal 阶段触发**：`OnPull` 拿到 `IReadOnlyList<GachaResult>` → `StartCoroutine(RevealSequence(results))` 先把状态置 `Reveal`，再逐张翻。
- **驱动器为 `RevealSchedule.Build(results)` 生成的错峰时间轴**（纯数据，可 headless 单测），非随 `GachaManager.Pull` 同步 burst 的原始事件（audio §3.4 红线）。
- **依次错峰（staggered wave），非齐发**：第 k 张 `AppearTime = k × CardStagger(0.08s)`；到时实例化该卡（初始 `ShowBack()`），调用 `card.Flip.BeginFlip` 起手翻面。
- 单抽 = 1 张；十连 = 10 张按同一 `CardStagger` 波浪铺开。
- 翻面中途点击任意处（`_skipCatcher`）→ 立即 `ForceFront()` 全部 → 进入 `ResultList`（见 §1.3 跳过）。

> 注：任务稿提及"依次/**并发**"。当前实现为**依次错峰**（发布学上规避齐奏轰头、对齐 audio §3.7）。"并发（全卡同时翻）"可作为未来配置项，本收口**默认锁为依次错峰**，不引入并发分支（避免过度设计，R3 精神）。

### 1.3 动画参数（已锁·取自 `FlipController` + `RevealTiming`）

| 参数 | 值 | 来源 |
|---|---|---|
| 单卡翻面时长（普通 N/R/SR） | **0.50s** | `RevealTiming.NormalFlipDuration` / `gacha-ui-asset-spec.md §2.1` |
| 单卡翻面时长（SSR） | **0.70s**（含揭示后 0.2s 定格） | `RevealTiming.SsrFlipDuration` / `gacha-ui-asset-spec.md §2.3` |
| 十连错峰间隔 `CardStagger` | **0.08s** | `RevealTiming.CardStagger` |
| 换面时刻 `RevealSwapOffset` | **t=0.25s**（scaleX=0 切卡背→卡面，灵光升腾起） | `RevealTiming.RevealSwapOffset` |
| SSR 紫宸虹光峰值 `SsrClimaxExtra` | 换面后 **+0.20s** | `RevealTiming.SsrClimaxExtra` / audio §8.2 |
| 十连感知总时长 | ≈ 9×0.08 + 0.50 ≈ **1.22s**（末张 SSR ≈ 1.42s） | `RevealSchedule.TotalDuration` |
| 缓动曲线 | 起手下沉 `OutCubic`(1→0.92, 0–0.20s) → 加速 `OutCubic`(0.92→0, 0.20–0.25s) → 升起 `OutBack` 过冲(0→1, 0.25–0.50s) | `FlipController.FlipRoutine`（代码实现，对齐 `gacha-ui-asset-spec.md §2.1/§2.2`） |
| 实现方式 | 纯 UGUI scale-X 翻（`RectTransform.localScale.x` 1→0 中点换 Sprite→1），无 3D 相机/RenderTexture（Canvas Overlay） | `gacha-ui-asset-spec.md §2.4 指引 A` |

**点击跳过 / 加速（已锁）：**
- **点击跳过（Skip）**：Reveal 期间 `_skipCatcher` 任意处点击 → `SkipReveal()` 置 `_skip=true` → 协程退出后对所有卡 `ForceFront()` 定格正面 → 转 `ResultList`。✅ 已实现（`GachaScreenController`）。
- **减少动效（`reduce_motion`）**：`BeginFlip(reduceMotion=true)` 直接 `ShowFront()` 瞬翻，保留边框+角星+名+数字静态等效（Standard I，accessibility-spec §1.2 I）。✅ 已实现（经 `IAccessibilitySettings` 动态注入）。
- **单独"倍速"（1x→2x 加速但仍动画）**：当前**未实现**，列为可选，不在本收口范围。

### 1.4 FlipController 职责（已锁）

组件 `FlipController`（挂 ResultCard 上，`[RequireComponent(typeof(RectTransform))]`），**纯视觉、不持业务数据**：

1. **管理单张卡 `scale.x` 翻转动效**：`FlipRoutine` 实现 1→0.92→0→1 的 scale-X 翻（含 `OutBack` 过冲），翻转期间由上层（`ResultCard` 材质）叠加灵光升腾/SSR 扫光。
2. **正反面 active 切换**：`ShowBack()`（初始态）/ `ShowFront()`（定格正面）/ `ForceFront()`（停协程+定格，供跳过/reduce_motion）；通过 swap `_back`/`_front` GameObject 显隐完成换面（`scaleX=0` 瞬间切换）。
3. **翻面完成事件（回调）**：`BeginFlip(bool reduceMotion, Action? onReveal)`，在 `scaleX=0` 换面瞬间调用 `onReveal`——用于触发灵光升腾/音频 chime 的"揭示"时刻（`GachaScreenController` 在此播 `Gacha_Reveal_Swap` + 稀有度顶层音）。
4. **读 `reduce_motion`**：开启时跳过协程直接 `ShowFront()`，保留信息静态等效。
5. **接口**：`BeginFlip` / `ShowBack` / `ShowFront` / `ForceFront`；由 `ResultCard.Setup` 调 `ShowBack()` 初始背面、由 `RevealSequence` 调 `BeginFlip`、由 `PlaySsrHolo` 调 SSR 扫光 overlay。

### 1.5 边缘情况（≥3，已锁）

1. **reduce_motion 开启**：`BeginFlip(true)` 不播动画直接 `ShowFront()`，SSR 扫光 overlay 静态显边框不扫（卡框+角星+名+数字立即可见）——信息零丢失（Standard I，ux-spec §6 #5 验收项）。
2. **跳过（Skip）**：协程未跑完即 `ForceFront`，收尾循环对 `_revealCards` 全部 `ForceFront()` 兜底，确保无卡停留背面；跳过不丢失结果（结果列表以 `results` 为权威源）。
3. **十连含 SSR 落在非末位**：SSR 峰值 cue（`SsrClimaxTime`）独立挂在该卡时间轴，不影响其他卡错峰；`TotalDuration` 取末张（无论稀有度）决定何时转 `ResultList`。
4. **新手池前 20 抽 `PullCost` 可能为 0**：该卡翻面/汇总照常，无特殊分支；仅影响按钮可支付性预检（见 §3.5）。
5. **立绘/元数据缺失**（灰盒）：`ResultCard.Setup` 调 `IShikigamiCatalog.GetMeta/GetCombatStats`；缺失时卡仍实例化（占位名/占位立绘），不阻断翻面时间轴。

---

## 2. 十连按钮（已锁）

### 2.1 位置与文案

- **位置**：`PullButtonGroup`（Canvas 层级 `bottom-stretch`，位于全局底部 Tab 之上；见 `gacha-screen-mvp.md §2.2/§2.3`）。与单抽 `HorizontalLayoutGroup` 并排，**十连占更大权重、主 CTA 视觉最高**（鎏金边 + idle 辉光 + 尺寸最大）。
- **尺寸（≥44×44，Standard J；移动按 48 网格）**：十连 **280×72**（主 CTA）；单抽 200×64（次 CTA）。见 `gacha-ui-asset-spec.md §5.2`。
- **文案（已锁·取自 `GachaScreenController.RefreshPullButtons`）**：
  - 十连：`$"十连 -{tenCost} 符箓"`（`tenCost = IGachaService.GetPullCost(_poolId, 10)`，常驻池 = 10，对齐 `02a-gdd-mvp.md §B2` 十连=10符箓）。
  - 单抽：`$"单抽 -{singleCost} 符箓"`（`singleCost = GetPullCost(_poolId, 1)`）。
  - 消耗数字 **tabular**（tnum），对齐 Basic C。

### 2.2 点击后流程（已锁·对齐 `gacha-screen-mvp.md §3.1` + `OnPull(10)`）

1. `ui_select` 点 `PullButton_Ten` → `OnPull(10)`。
2. **可支付性预检**：`CanAfford(10)`（余额 ≥ `GetPullCost(poolId,10)`）；不足转 `InsufficientCurrency`（显 CTA，见 §3）。
3. 预检通过 → 状态 `Rolling`：禁用单/十连按钮 + Back（`RefreshPullButtons` 的 `locked` 位）、播「灵光升腾」闪光 + `Gacha_Rolling` loop 音。
4. **调用 `var results = gacha.Pull(_poolId, 10)`**（同步返回 `IReadOnlyList<GachaResult>`，M2 实现；`Pull` 内部同步 firing `GachaShikigamiObtainedEvent`/`currency_changed`，但 UI 翻面**以 results 为权威有序源**，见 ux-spec §3.1 红线）。
5. 保底：先 `PityProgressBar.DetectCrossing(newPity)` 播软/硬保底提示音，再 `Bind` 重绑进度条。
6. 状态 `Reveal`：按 `RevealSchedule.Build(results)` 实例化 **10 张 ResultCard**（初始背面），错峰翻面（§1.2/§1.3）。
7. 全部翻完（或跳过）→ 状态 `ResultList`：显 `ResultSummaryBar`（`$"获得 {n} 式神 · 含 {ssr} SSR"`）+ 后续操作（去养成/去编队/看序章/再来一次/返回）。
8. 含 SSR → 排队 `BondPrologue`（仅 SSR，1–2 屏，MVP 留钩子）。
9. 货币经 `currency_changed` 实时更新绝对值（非累加）。

### 2.3 与单抽的差异（已锁）

| 维度 | 单抽 | 十连 | 差异 |
|---|---|---|---|
| 扣费 | `GetPullCost(poolId,1)` | `GetPullCost(poolId,10)`（≈10 倍） | 十连为单抽 10 倍 |
| 结果张数 | 1 | 10 | 十连 10 张 |
| Reveal 布局 | 居中单卡 | **纵向滚动列表**（`RevealArea` = `ScrollRect` + `VerticalLayoutGroup`，单列；每卡 ≈360×540，间距 8 倍数栅格） | 十连折叠为结果列表，对齐 ux-spec §2.2 移动「十连折叠为结果列表」 |
| 错峰 | 无（单张 0.5s） | 10 张 × `CardStagger(0.08s)` 波浪 | 十连感知总时长 ≈1.22s |
| 按钮恢复逻辑 | `RefreshPullButtons` 统一 | 同左 | **一致**：`Rolling/Reveal` 锁、`ResultList`/`PoolSelected` 恢复可点（修复"只能点一次"，见 `GachaScreenController.SetState`） |
| 概率/保底 | 同 | 同（十连按累计抽数一次跳进保底，非逐张） | 保底更新逻辑一致 |

> 布局说明：任务稿建议"网格布局"，本收口按**移动竖屏单列纵向列表**锁参（与 ux-spec §2.2「十连折叠为结果列表」、gacha-screen-mvp §2.3 一致）。若后续上 PC 横屏变体，可改为多列网格（ADR-001 回归路径，不破坏本规格）。

---

## 3. InsufficientCurrency CTA（升级·含待拍板 + 工程依赖）

### 3.1 触发条件（已锁）

- 状态机为 `PoolSelected` 的**可支付性子态**（卡池绑定保持，仅可支付性与 CTA 变化；从 `PoolSelected` 进入、恢复可支付后回 `PoolSelected`）。
- **进入**：`PoolSelected` 中 `fu_lu < 单抽消耗`（`CanAfford(1) == false`，即余额 < `GetPullCost(poolId,1)`）时转 `InsufficientCurrency`。注：以**单抽消耗**为门槛（单抽是最小抽取单位），而非十连。
- **退出（恢复）**：`OnCurrencyChanged` 使 `fu_lu ≥ 单抽消耗` → 回 `PoolSelected`（`GachaScreenController.OnCurrencyChanged`）。

### 3.2 文案与位置（位置已锁 / 文案待拍板）

- **位置（已锁）**：`PullButtonGroup` 内、`PullButton_Ten`/`_Single` **下方**显 CTA（`InsufficientCTA`，默认隐藏，`ShowInsufficientCta(true)` 仅在 `InsufficientCurrency` 态显示，其他态 `ShowInsufficientCta(false)`）。拇指可达、≥48×48（Standard J）。
- **按钮禁用态视觉（已锁·不靠纯色，Basic）**：单/十连按钮 `interactable=false` + 信息灰 `#8A9599` 去饱和 + 对角划线 + 锁 glyph（`ico_st_disable`）+ 文案「符箓不足」（`PullButton.SetDisabledInsufficient`）。**仅置灰不满足 MVP 验收**（ux-spec §4 卡点#1 最高优先可读性风险）。
- **CTA 文案（待拍板·方向冲突见 §3.6）**：
  - 候选 A（**主推荐·对齐核心循环**）：「**去推图产出符箓**」——指向战斗屏，兑现 ux-spec §4 卡点#1「所有资源消耗点资源不足时显产出源引导」，防留存飞轮断流。
  - 候选 B（任务稿示例·需商城）：「**获取符箓**」——指向商城/充值（OpenStore 意图）。

### 3.3 点击行为（升级·意图事件，工程依赖）

- **行为（已锁方向）**：CTA 点击 **发出意图事件**（经 `EventBus`），由 `Bootstrapper` / 外部系统订阅处理；**UI 本身不直接跳转场景**（守住 ADR-3 解耦红线：UI 不 import 商城/战斗 Manager）。
- **事件名（已定）**：`GachaAcquireIntentEvent`（语义含"去哪获得符箓"）。
- **事件载荷（已定·M3 收口落地）**：`Reason` 字段，MVP 取 `"battle"`（= 去推图产出符箓，对齐候选 A / §1.3 防断流）；若后续并行商城入口，可扩展为 `"store"` 等取值，订阅方据 `Reason` 路由。
- **H-C1 现状（已实现·灰盒）**：`GachaScreenController.OnInsufficientCta` 现已 `_bus.Publish(new GachaAcquireIntentEvent { Reason = "battle" })`；`Bootstrapper.Awake` 订阅该事件并 `Debug.Log(...)` 灰盒占位。**真实跳转（推图屏接管）尚未接**，列为后续里程碑依赖（见 §5.1 / 评审 R1）。

### 3.4 与状态机配合（已锁）

- `SetState(InsufficientCurrency)` → `ShowInsufficientCta(true)` + `RefreshPullButtons()`（按钮置灰）。
- `SetState(PoolSelected/Rolling/Reveal/ResultList)` → `ShowInsufficientCta(false)`。
- `OnCurrencyChanged`：`_state == InsufficientCurrency && CanAfford(1)` → 回 `PoolSelected`（CTA 自动隐藏）。
- Rolling/Reveal 期间 `currency_changed` 到达：非 `InsufficientCurrency` 态，**不**触发状态恢复跳转（防动画期间状态错乱）；仅 `InsufficientCurrency` 态响应恢复。

### 3.5 边缘情况（≥3，已锁）

1. **单/十连同时不可支付** → 进 `InsufficientCurrency`，显 CTA（代码正是此路径；按钮双置灰）。
2. **新手池前 20 抽 `PullCost` 可能 0** → 该阶段恒可支付，几乎不进 `InsufficientCurrency`（仍受 `Rolling/Reveal` 锁）；若进，说明余额真为 0，CTA 照常。
3. **点 CTA 跳转后 `ui_back` 回 Summon** → `Idle → PoolSelected`，若余额仍不足 → 再进 `InsufficientCurrency`（CTA 重现），不丢状态。
4. **reduce_motion 开启**：CTA 视觉/动效不依赖动效，仍须可点可达（Standard I 仅压动效，不压功能）。
5. **Rolling/Reveal 期间货币变动**（理论不 occur，因 `Pull` 同步扣费）：`OnCurrencyChanged` 在非常态不触发恢复跳转，避免打断演出。

### 3.6 方向冲突（已拍板 = Battle·去推图）

- **冲突源**：`gacha-screen-mvp.md §1.3` 卡点#1 原文 CTA =「**去推图产出符箓**」（指向 Battle，对齐 ux-spec §4 核心循环防断流）；本任务稿示例为「**获取符箓**」+ `OpenStoreIntent`（指向商城）。两者方向相反。
- **推荐**：MVP 核心循环用**候选 A「去推图产出符箓」**（免费产出源引导，不逼氪、防断流，对齐 UX 支柱 R1/R4）；若商城/充值已实装，可**并行**提供「获取符箓」(OpenStore) 作为次级入口。最终影响事件名与订阅方（§3.3）。
- **已拍板（M3 收口）**：方向 = 候选 A「去推图产出符箓」（Battle），事件名 `GachaAcquireIntentEvent`、载荷 `Reason="battle"`，H-C1 已补 emit + `Bootstrapper` 订阅（灰盒日志）。若商城实装，可并行 `Reason="store"` 次级入口。

---

## 4. 与现有规格的一致性说明（引用章节）

| 本收口模块 | 既有规格章节（已对齐/引用） | 本次收口**补充/升级**的内容 |
|---|---|---|
| ResultCard 正反面 + 翻面 | `gacha-screen-mvp.md §2.4`（Prefab 结构）、`art/gacha-ui-asset-spec.md §1`（卡框）、`art/art-bible.md §5/§2.2/§8`（卡框+稀有度三重冗余） | 把 prefab 字段与**代码 `FlipController` 实际参数**收口为 §1.1–§1.4 权威表；补 §1.5 边缘情况（reduce_motion/Skip/SSR 非末位） |
| 翻面动画参数 | `gacha-screen-mvp.md §3.1`、`art/gacha-ui-asset-spec.md §2`（VFX 时序）、`RevealSchedule.cs`/`RevealTiming` | 把散布于 asset-spec §2.1–2.3 与代码常量的**时间轴锚点**收口为 §1.3 单表（时长/错峰/换面/峰值/缓动），明确"依次错峰、非齐发" |
| FlipController 职责 | `gacha-screen-mvp.md §2.4`（FlipController 注）、代码 `FlipController.cs` | §1.4 显式列出 5 项职责 + 接口，作为终稿对接契约 |
| 十连按钮 | `ux-spec.md §2.2`②（单/十连 CTA）、`gacha-screen-mvp.md §2.2/§2.3`（PullButtonGroup）、`art/gacha-ui-asset-spec.md §5`（三态+尺寸+权重）、`02a-gdd-mvp.md §B2`（十连=10符箓） | §2 锁"文案格式=十连 -{cost} 符箓"、纵向列表布局、与单抽差异表；明确 PC 横屏多列网格为 ADR-001 回归项 |
| InsufficientCurrency CTA | `gacha-screen-mvp.md §1/§1.3`（六态·卡点#1「去推图」CTA）、`ux-spec.md §4` 卡点#1（符箓枯竭断点）、`art/gacha-ui-asset-spec.md §5.1`（禁用态+引导 CTA） | **升级**：把"占位跳转"升级为 **§3.3 意图事件（OpenStoreIntent/GachaAcquireIntent）** 行为；标出与 §1.3「去推图」的**方向冲突（§3.6 待拍板）** 与**工程缺口 H-C1** |
| 可访问性 | `art/accessibility-spec.md §0/§1.1(Basic A/B/C/D/E)/§1.2(Standard I/J/K/G/H)`、`ux-spec.md §6`、`art/art-bible.md §8` | 全程复用既有分级，未新增条款；本收口仅**引用**并在 §1.1/§1.3/§1.5/§2.1/§3.2 标注落地点 |

> **设计红线自检（ADR-3）**：本收口所有交互（翻面、十连、CTA）均经 `ServiceRegistry` 解析接口 / `EventBus` 订阅，UI 不持有 `*Manager` 字段；CTA 升级为"发意图事件"进一步守住解耦（§3.3）。
> **范围自检**：本收口不含卡池选择/概率公示/羁绊序章全叙事/每日免费十连 UI（超出 MVP 切片，由通用控件/Phase 4 定稿，见 `gacha-screen-mvp.md §0/§11`）。

---

## 5. 工程依赖与待审批项（回传 engineering-lead / 主理人）

### 5.1 工程依赖（H-C 系列，本次收口新引入，非 M2 H1–H4）

| ID | 缺口 | 建议方案 | 优先级 | 影响 |
|---|---|---|---|---|
| **H-C1** | ~~CTA 点击未 emit 意图事件~~ **已实现（灰盒）**：`OnInsufficientCta` emit `GachaAcquireIntentEvent{Reason="battle"}`，`Bootstrapper` 订阅 `Debug.Log` 占位 | 真实导航（推图屏接管）待后续里程碑接 | ✅ 已实现（灰盒）/ 🔴 真实跳转 TBD | InsufficientCurrency CTA 跳转 |
| **H-C2** | ~~事件名/目标待定~~ **已拍板 = Battle（去推图）**：事件名 `GachaAcquireIntentEvent`、载荷 `Reason="battle"` | 若后续并行商城入口，扩展 `Reason="store"` 由订阅方路由 | ✅ 已拍板 | 事件类型 + 订阅方 |

> 既有 M2 H1–H4（保底阈值/卡池元数据/式神元数据/currency_changed）**已于 M3 补齐**，本收口直接复用，无新增 H1–H4 缺口。

### 5.2 待主理人审批项

1. **【CTA 方向·§3.6】**「去推图产出符箓」(Battle) vs「获取符箓」(OpenStore)？推荐 MVP 用候选 A（防断流），商城实装后可并行次级入口。**拍板后定 H-C2 事件名 + H-C1 订阅方。**
2. **【十连布局·§2.3】**确认移动竖屏**纵向列表**（非多列网格）满足；PC 横屏多列网格留作 ADR-001 回归项。
3. **【翻面加速·§1.3】**仅"跳过+reduce_motion 瞬翻"，是否需要单独"倍速"？本收口默认不需要。

### 5.3 与美术/音频终稿对接（不变，引用既有）

- 美术：`art/gacha-ui-asset-spec.md §7.3` Sprite 字段同名替换，业务零改；翻面/SSR/保底资产按 §1/§2/§4 落地。
- 音频：`design/audio/gacha-audio-spec.md` §8 同步点（翻面起手 t=0 / 揭示 t=0.25 / SSR 峰值 +0.2s / 保底 50·90）；`reduce_motion` 下音频仍对齐定格揭示时刻（audio §4.3）。

---

**一句话总结**：本 M3 收口 UX 规格把已落地的 `FlipController`/`RevealSchedule`/`PullButton`/`GachaScreenController` 实现与既有预制作规格**收口为一份权威 UX 真源**——锁 ResultCard 正反面内容、翻面时间轴参数（0.5/0.7s、错峰 0.08s、换面 0.25s、OutCubic/OutBack、点击跳过+reduce_motion 瞬翻）、FlipController 五职责、十连按钮（文案「十连 -{cost} 符箓」/纵向列表/与单抽差异表），并**升级 InsufficientCurrency CTA 为"发意图事件（OpenStoreIntent 类）"行为**（同时标出与原 §1.3「去推图」的方向冲突待拍板、及当前代码未 emit 事件的 H-C1 工程依赖），全程对齐 ux-spec/gacha-screen-mvp/art-bible/accessibility-spec 既有章节与 ADR-3 解耦红线。
