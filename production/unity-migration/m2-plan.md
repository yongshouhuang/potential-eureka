# M2 核心逻辑端口计划（草案）

> 角色：engineering-lead（程基岩）｜ 性质：**规划 + 代码骨架草案，不改任何 .gd，不碰已验证的 M1 Core 资产**
> 对齐：`port-plan.md`（M2 里程碑）、`architecture-adrs.md`（ADR-3 解耦红线 / ADR-4 测试 / ADR-5 CI）、M1 已验证 `src/core/Core/`、旧 `scripts/*.gd` 逻辑源、GUT 测试（`tests/`）。
> ⚠️ **沙箱限制**：本环境无 Unity / 无 dotnet，所有 C# 为手写草案，须在用户本机（团结引擎 1.9.3 + .NET SDK）编译/运行验证（同 `port-plan.md · Sandbox Limitation`）。

---

## 0. 执行摘要

- **M2 目标**：把 15 个 autoload manager + 3 core + 2 utils 从 GDScript 端口为 C#，headless 可测，强守 **ADR-3 解耦红线**。
- **本草案交付**：
  1. 本文档（M2 范围 + 系统优先级 + 第一切片设计 + 验收标准映射 M2 质量门）。
  2. 第一垂直切片 **Gacha（B2）** 的代码骨架：`src/unity/Features/Shared/`（跨特性共享契约/基础设施）+ `src/unity/Features/Gacha/`（抽卡引擎 + 编排）+ `src/unity/Features/Gacha.Tests/`（T4/E2-S1 映射骨架）。
  3. 每个切片目录附 `README.md` 说明如何接入 Unity 工程。
- **关键结论**：建议 **Gacha 作为 M2 第一个垂直切片**（数据已驱动、逻辑自包含、低风险且最完整锻炼解耦红线），**Economy 紧随其后**补齐被 stub 的经济服务。

---

## 1. M2 现状盘点（读后结论）

### 1.1 M1 已验证资产（可复用，零改动）
`src/core/Core/` 已交付且本机验证通过：
- `EventBus`（类型化 `Subscribe<T>/Publish<T>`）、`ServiceRegistry`（`Register<T>/Resolve<T>/TryResolve<T>`，按接口+类型登记）、`GameState`（**stub**：仅 `Turn/ActiveUnitId` + 通用 `SetValue/GetValue`）、`ConfigLoader`（`LoadXxx()` 强类型加载 10 JSON，**缺 `Inject/Reset`**）、`IService`。
- `Models/`：`ShikigamiDef / SkillDef / GachaPool / RarityRates / CultivationConfig / BattleUIConstants / Chapter / Enums(Rarity,Element)`——抽卡切片所需的 `GachaPool / RarityRates / Rarity` 已齐备。
- `Core.Tests/ConfigLoaderTests.cs`（Xunit，验证加载 + 字段断言）。

### 1.2 缺口（GAP，须用户拍板，见 §5）
| # | 缺口 | 影响 | 本草案应对 |
|---|---|---|---|
| **GAP-1** | `ConfigLoader` 缺 `Inject/Reset`（port-plan M1 退出准则要求，且所有 M2 测试依赖假表注入） | M2 单测难注入假表 | 特性层加 **test-seam**（`SetPoolsForTest` 直接注入 `GachaPool` 字典），绕开缺漏；同时列为审批项（是否补回 M1 Core） |
| **GAP-2** | 无 `RngWrapper`（port-plan M1 动作3 列了，M1 未交付） | 随机路径需固定种子（红线#6） | 新增于 `Features.Shared`（引擎无关，AOT 安全） |
| **GAP-3** | `GameState` 仅为 stub，缺 **save schema v1**（currencies/pity/deck/shikigami/settings/progression/free_ten_pull/production_tracker/gacha_progress） | M2 需中央真源 | 新增 `PlayerProfile`（纯数据）于 `Features.Shared`；收口时建议提升进 `Core.GameState`（动 M1 资产，DECISION-D） |

> 红线再确认（ADR-3 控制清单）：manager 不得持有其他 manager 字段引用；跨系统通信只走 `EventBus / GameState(PlayerProfile) / ConfigLoader / ServiceRegistry`；随机经 `RngWrapper`；`BattleManager` 对 `BondManager` 引用=0。

---

## 2. M2 系统优先级排序（候选系统）

> 排序原则：**数据已驱动 → 逻辑自包含 → 低风险 → 优先**。越靠前的越适合做垂直切片或热身件。

| 优先级 | 系统 | 依赖 | 数据驱动 | 自包含度 | 风险 | 建议时机 | 理由 |
|---|---|---|---|---|---|---|---|
| **P1 ★切片** | **Gacha (B2)** | Economy（经 `IEconomyService` 接口，非具体类） | 高（gacha_pools.json 已建模） | 中（roll 引擎纯 / pull 编排） | 中 | **第一切片** | 数据驱动完整、逻辑自包含；最完整锻炼红线（EventBus 广播 + ServiceRegistry 接口解析 + RngWrapper + PlayerProfile 写入 + 跨系统消耗）；玩家可见特性；T4 定义清晰。符合主理人提示「抽卡适合做第一个垂直切片」。 |
| **P2** | **Economy (B1)** | 零依赖 | 高（economy_config.json） | 高 | 低 | 紧跟 Gacha | 零依赖基础件；Gacha 切片先用 `IEconomyService` stub，Economy 落地后替换为真实现（T1）。数据驱动、自包含、低风险，是补完切片的最佳下一刀。 |
| **P3** | **Bond (A1)** | 零状态写 | 高（bond_combos.json） | 极高（纯函数） | 极低 | 早期热身 | `compute_combo(deck)` 纯计算 + 发 `bond:combo`；零存档写入。证明「事件-only」跨 manager 契约（BattleManager 仅订阅），极佳信心件。 |
| **P4** | **DeckBuilder (B4 部分)** | 仅 PlayerProfile | 高 | 极高 | 极低 | 热身 | 编队 4 式神+1 法宝的增删/规模校验，纯校验逻辑，几乎无风险。 |
| **P5** | **Cultivation (B3)** | Economy + 式神 def | 高 | 中 | 中 | Bond 后 | 升级/突破/觉醒，区间取中点确定性；T7 养成最终式神。 |
| **P6** | **SaveManager + CloudSaveService** | 需完整 PlayerProfile | 高 | 中 | 中 | Gacha/Econ/Cult 之后 | 序列化 PlayerProfile + checksum + 回滚（T3）。依赖前序系统填满 Profile 字段。 |
| **P7** | **Status + BattleResolver + BattleManager (B4)** | 互依（Status/Bond/Econ/Cult） | 高 | 低 | 高 | M2 末尾 | 五行克制/状态/回合流程，复杂度最高、互依最强；是 M2 最大风险区，留到最后。T2/T6。 |
| **P8** | **Accessibility / UITheme / InputBridge** | UI 向 | 中 | 中 | 中 | M3 前/中 | `AccessibilitySettings` 单例可测（T5）；UITheme/InputBridge 偏 M3。 |
| **P9** | **TelemetryAggregator** | 横切（订阅 4 类遥测事件） | 中 | 高 | 低 | 最后 | 「抽→养→战→回流」漏斗聚合，可观测性；等前序系统 emit 后再接。 |

**推荐第一切片 = Gacha (B2)**，理由见 §3。

---

## 3. 第一垂直切片：Gacha (B2)

### 3.1 设计目标与红线自检
- ✅ 抽卡结果经 `EventBus.Publish<GachaShikigamiObtainedEvent>` + `TelemetryGachaPulledEvent` 广播（UI/遥测仅订阅，零跨 manager import）。
- ✅ 跨系统消耗符箓经 `ServiceRegistry.Resolve<IEconomyService>()` **在调用点取用，不缓存为字段**（红线#3）。`GachaManager` 字段中 **零** `EconomyManager` / `IEconomyService` 具体类型。
- ✅ 随机经 `RngWrapper`（固定种子，红线#6）。
- ✅ 存档读写经 `PlayerProfile`（纯数据对象，非 manager，红线#2/#3 允许持有本地数据对象）。
- ✅ 持有的引用均为基础设施/数据：`EventBus / ConfigLoader / PlayerProfile / RngWrapper / ServiceRegistry`——均非其他 manager。

### 3.2 模块分解与 asmdef
```
src/unity/Features/
├── Shared/                        # asmdef: XiaXia.Features.Shared  (refs: Core)
│   ├── Features.Shared.asmdef
│   ├── RngWrapper.cs              # 种子化 RNG（GAP-2）
│   ├── IEconomyService.cs         # 经济契约（Gacha 经此跨系统消耗）
│   ├── IGachaService.cs           # 抽卡契约 + GachaResult
│   ├── PlayerProfile.cs           # save schema v1 纯数据（GAP-3）
│   └── Events/
│       ├── GachaEvents.cs         # gacha_shikigami_obtained / telemetry_gacha_pulled
│       └── EconomyEvents.cs       # economy_currency_changed / economy_reward_granted
└── Gacha/                         # asmdef: XiaXia.Features.Gacha  (refs: Core, XiaXia.Features.Shared)
    ├── Features.Gacha.asmdef
    ├── GachaRollEngine.cs         # 纯逻辑（T4/E2-S1 核心，可独立单测）
    ├── GachaManager.cs            # 编排（实现 IGachaService，守红线）
    ├── README.md
    └── Tests/                     # asmdef: XiaXia.Features.Gacha.Tests (EditMode)
        ├── Features.Gacha.Tests.asmdef
        └── GachaTests.cs          # T4/E2-S1 + 红线反射自检
```
> **asmdef 引用名注意**：所有 `references` 中的 `"XiaXia.Core"` 须与用户 Unity 工程里 `Core.asmdef` 的 **实际 `name` 字段**一致（M1 落地的 `Core.asmdef` 的 name 即 `XiaXia.Core`）。本草案已统一用 `"XiaXia.Core"`，与 M1 对齐。

### 3.3 关键类与方法签名（详见代码）
- `GachaRollEngine`（纯，引擎无关）：
  - `GachaResult RollOnce(string poolId, GachaPool pool, Dictionary<string,int> pity, Dictionary<string,GachaProgressEntry> gachaProgress)`
  - `Rarity DetermineRarity(GachaPool pool, int pityCount)`
  - `double EffectiveSsrRate(int pityCount, GachaPool pool)`（软保底曲线）
  - `Rarity WeightedRoll(RarityRates rates)` / `Rarity RollWithBoostedSsr(RarityRates rates, double ssrRate)`
  - `string PickShikigami(GachaPool pool, Rarity rarity)`
- `GachaManager : IGachaService`（编排）：
  - `IReadOnlyList<GachaResult> Pull(string poolId, int count = 1)`
  - `GachaResult RollOnce(string poolId)`
  - `IReadOnlyDictionary<string,double> GetProbabilities(string poolId)`（E2-S5）
  - `int GetPity(string poolId)`
  - `void SetPoolsForTest(Dictionary<string,GachaPool> pools)`（test-seam，绕 GAP-1）
  - 内部 `PullCost(poolId)`（新手前 20 抽半价）

### 3.4 验收标准（对齐 M2 质量门 SOP）
| 来源 | 验收点 | 本切片覆盖 |
|---|---|---|
| **T4** | 硬保底第 90 抽必 SSR | ✅ `HardPity_ForcesSsrOn90th` |
| **T4** | 软保底第 50 抽 SSR≥50%，随抽数线性升（0.5→1.0） | ✅ `SoftPity_RateGeq50ThenRises` |
| **T4** | 保底不跨池（独立计数） | ✅ `Pity_NotCrossPool` |
| **T4** | 种子可复现 | ✅ `RngWrapper` 固定种子 + 抽样测试 |
| **T4** | 新手池首次必出指定 SR | ✅ `Newbie_ForcedStarterSr` |
| **T4** | 新手前 20 抽半价（共耗 10 符箓） | ✅ `Newbie_HalfPrice20PullsCost10`（用 `FakeEconomyService` 充 `IEconomyService`） |
| **E2-S1** | 万次抽样落入公示 ±2% | ✅ `Rates_WithinTolerance` |
| **E2-S5** | 概率公示可读取 | ✅ `GetProbabilities` |
| **ADR-3 红线** | `GachaManager` 字段无跨 manager 引用 | ✅ `Decoupling_NoManagerFieldReference`（反射自检，预演 M2 `ArchitectureGuardTests`） |
| **headless** | EditMode / `dotnet test` 全绿 | ✅ `Features.Shared` + `Gacha` 引擎无关（零 UnityEngine） |

---

## 4. 接入方式（README 摘要，详见 `src/unity/Features/Gacha/README.md`）
1. 复制 `src/unity/Features/` 到 Unity 工程 `Assets/Scripts/Features/`。
2. 确认 `Core.asmdef` 已存在（M1）。三个新 asmdef 引用名对齐（见 §3.2）。
3. `Bootstrapper`（M0 产物）在 `Awake` 注册服务：
   - `registry.Register<IGachaService>(new GachaManager(bus, loader, profile, registry, rng));`
   - Economy 落地后：`registry.Register<IEconomyService>(new EconomyManager(...));`
4. `PlayerProfile` 作为单例数据对象，由 Bootstrapper 创建并注入各 manager；`SaveManager`（P6）负责序列化。
5. 测试：`Gacha.Tests` 设为 EditMode Test Assembly（`includePlatforms: Editor`），引用 UTF（NUnit）。

---

## 5. 待用户拍板事项（DECISION）

| # | 事项 | 选项 | 建议 |
|---|---|---|---|
| **DECISION-A** | **M0 分支/重基线策略**：`scripts/*.gd`（28 个）退役时机 | (a) M2 不动，等 M0 重基线分支批了再删；(b) 现在就开 M0 分支清理 | **(a) 维持现状**：本草案严格不改/不删任何 `.gd`（任务硬约束），M0 分支策略待你拍板后再动。 |
| **DECISION-B** | **是否先只做 Gacha 切片验证再铺开** | (a) 仅 Gacha 切片 → 本机验证 → 再铺 Economy/Bond…；(b) 一次性铺完 M2 | **(a) 切片优先**：先在本机验证 Gacha 切片（含红线自检 + T4 全绿），确认解耦模式可落地，再铺其余系统，降低 M2 整体风险。 |
| **DECISION-C** | **GAP-1：是否补 `ConfigLoader.Inject/Reset` 回 M1 Core** | (a) 补回 Core（动 M1 资产）；(b) 沿用特性层 test-seam | **(b) 暂用 test-seam**（本草案已落地），但若你希望长期统一注入机制，建议 (a)——属「补 M1 收尾」，需我改 `src/core/Core/ConfigLoader.cs`（会先说明再改）。 |
| **DECISION-D** | **GAP-3：`PlayerProfile` 是否提升进 `Core.GameState`** | (a) 留 `Features.Shared` 待 M2 收口；(b) 现在就并入 `Core.GameState`（动 M1 资产） | **(a) 暂留**：M2 早期避免动已验证 M1 资产；建议在所有 manager 落地、Profile 字段稳定后，于 M2 收口阶段统一提升进 `Core.GameState`。 |
| **DECISION-E** | **新增 asmdef 命名 / Core 引用名对齐** | 确认 `Core.asmdef` 实际 `name` | 若你 Unity 工程里 Core.asmdef 名为 `XiaXia.Core` 等非 `Core`，需同步修改本草案所有 `references` 中的 `"Core"`。 |

---

## 6. 风险与对冲
- **R1（红线在 Unity 更易破）**：用「接口解析 + 架构测试反射自检 + 控制清单」三重守住；本切片已附 `Decoupling_NoManagerFieldReference` 预演。
- **R6（无 dotnet/Unity 验证）**：本草案代码为手写，须在用户本机 `dotnet test`（Core+Features 引擎无关）+ Unity EditMode 跑通；M4 立 GameCI（决策5 暂挂）。
- **GAP-1/2/3**：均以「新增于 Features.Shared + test-seam」绕开，零改动 M1 Core；收口阶段再决定提升（DECISION-C/D）。

---

【一句话总结】M2 建议以 **Gacha（B2）为第一垂直切片**（数据驱动、自包含、最完整锻炼 ADR-3 红线），**Economy（B1）紧随补 stub**；Bond/DeckBuilder 作低风险热身，Cultivation/Save/Battle 依次推进，Telemetry 最后；本草案交付 `m2-plan.md` + `Features.Shared`/`Features.Gacha` 代码骨架 + T4/E2-S1 测试骨架，所有新增均不碰 M1 Core 与 `.gd`，缺口以 test-seam 绕开并列为 DECISION-C/D 待你拍板。
