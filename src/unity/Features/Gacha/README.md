# Features.Gacha · 接入说明（M2 第一垂直切片）

> 目标：把抽卡系统（B2 / E2）以 C# 端口进团结引擎 1.9.3（Unity 2022.3 LTS），守 ADR-3 解耦红线，headless 可测。
> 本目录为 **代码骨架 + 可运行纯逻辑**，须在本机 Unity / dotnet 验证（沙箱无编译环境）。

---

## 1. 目录结构

```
src/unity/Features/
├── Shared/                 # 跨特性共享：RngWrapper / 服务接口 / PlayerProfile / 事件
│   └── Features.Shared.asmdef
└── Gacha/                  # 本切片
    ├── Features.Gacha.asmdef
    ├── GachaRollEngine.cs  # 纯抽卡逻辑（T4/E2-S1 核心，可独立单测）
    ├── GachaManager.cs     # 编排（实现 IGachaService，守红线）
    ├── README.md
    └── Tests/
        ├── Features.Gacha.Tests.asmdef
        └── GachaTests.cs   # T4/E2-S1 + 红线反射自检
```

## 2. 前置条件

- M1 已交付：`Core.asmdef`（含 EventBus / ServiceRegistry / ConfigLoader / Models）已在 Unity 工程 `Assets/Scripts/Core/`。
- `Newtonsoft.Json` 包已装（ConfigLoader 依赖；见 `src/unity/README-tuanjie-verify.md`）。
- `data/` 已复制到 Unity 工程根目录（`Assets` 同级），供 `ConfigLoader` 加载 gacha_pools.json。

> ⚠️ **asmdef 引用名**：本目录所有 `.asmdef` 的 `references` 中 `"Core"` 须与你的 Unity 工程里 `Core.asmdef` 的
> **实际 `name` 字段**一致（M1 README 称 `Core.asmdef`，默认名即 `Core`）。若你曾改名（如 `XiaXia.Core`），需同步修改本目录全部 `references`。

## 3. 复制到 Unity 工程

```
仓库 src/unity/Features/   ──►   Unity工程/Assets/Scripts/Features/
```

复制后 `Assets/Scripts/Features/` 下含 `Shared/`、`Gacha/`，各带 `.asmdef`。
Unity 会自动编译三个程序集：`XiaXia.Features.Shared` → `XiaXia.Features.Gacha` → `XiaXia.Features.Gacha.Tests`(EditMode)。

## 4. 服务注册（Bootstrapper）

在 M0 的 `Bootstrapper` 场景 `Awake` 中注册（顺序：先建基础设施，再建 manager）：

```csharp
// 基础设施（单例，贯穿全游戏）
var bus = new EventBus();
var loader = new ConfigLoader(dataRoot);          // dataRoot = Application.dataPath/../data
var profile = new PlayerProfile();                // 中央真源（SaveManager 后续序列化）
var registry = new ServiceRegistry();
var rng = new RngWrapper(1);

// 经济服务（P2 落地后由 EconomyManager 实现；切片阶段可先用桩）
registry.Register<IEconomyService>(new EconomyManagerStub(bus, loader, profile));

// 抽卡服务（本切片）
registry.Register<IGachaService>(new GachaManager(bus, loader, profile, registry, rng));
```

> 红线要点：`GachaManager` 内部**不持有** `IEconomyService` 字段，仅在 `Pull()` 调用点
> `registry.Resolve<IEconomyService>()` 取用。UI/其它系统也只经 `IGachaService` 调用抽卡，零具体类引用。

## 5. 运行测试

- **EditMode（UTF）**：`Gacha.Tests` 设为 Test Assembly（`includePlatforms: ["Editor"]`，勾选 Test Assemblies）。
  Unity Test Runner → EditMode → 运行 `GachaTests`，应全绿（T4 保底 / E2-S1 概率 / 不跨池 / 新手 / 红线反射自检）。
- **dotnet test（引擎无关，推荐本地门禁）**：`Features.Shared` + `Features.Gacha` 零 `UnityEngine` 依赖，
  可配 .NET 工程直接 `dotnet test`（见 M1 `Core.Tests` 模式）。无需启动 Unity。

## 6. 已知缺口与待办（见 m2-plan.md §1.2 / §5）

- **GAP-1**：`ConfigLoader` 缺 `Inject/Reset`。本切片用 `GachaManager.SetPoolsForTest(...)` 注入假卡池绕开；
  是否补回 M1 Core 待 DECISION-C。
- **GAP-2 / GAP-3**：`RngWrapper` 与 `PlayerProfile` 暂置于 `Features.Shared`（新增，未碰 M1 Core）；
  收口阶段是否提升进 `Core` 待 DECISION-D。
- 经济服务（P2）落地前，`IEconomyService` 可由桩实现；Gacha 切片测试用 `FakeEconomyService` 内存记账。

## 7. 红线自检（开发约定）

- 新增任何 manager 时：**禁止**声明 `private OtherManager _x` 或 `GetComponent<OtherManager>()` 跨 manager 引用。
- 跨系统调用一律走 `EventBus.Publish/Subscribe`、`PlayerProfile` 读写、`ConfigLoader` 取配置、`ServiceRegistry.Resolve<T>()`（仅调用点取用）。
- 提交前跑 `GachaTests.Decoupling_NoManagerFieldReference`（预演 M2 `ArchitectureGuardTests`）确认零跨 manager 字段引用。
