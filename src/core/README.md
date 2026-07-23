# 仙侠卡牌 · Core（发动机无关 C# 层 / M1）

本目录是**增量化**引入的、与游戏引擎解耦的纯 C# 核心层（M1）。目标是在保留现有 Godot 工程（`scripts/*.gd`、`data/*.json`）不变的前提下，先把**数据模型 + 解耦基础设施**用可在 .NET 8 / 团结引擎 1.9.3（Unity 2022.3 LTS）编译的 C# 写出来，为后续移植与共享逻辑打底。

> ⚠️ **未编译验证声明**：本工作室沙箱环境**没有安装 Unity，也没有 dotnet SDK**，因此本目录下的 `.cs` 文件**未经任何编译/测试验证**。代码按 .NET 8（测试工程 `net8.0`）与团结引擎 1.9.3（Unity 2022.3 LTS，核心工程 `netstandard2.1`）的规范手写，预期可在您本机装好 .NET 8 SDK 后编译通过。如发现任何编译问题，请反馈修正。

---

## 目录结构

```
src/core/
├── Core.csproj                 # 核心工程（netstandard2.1，无 UnityEngine 引用）
├── README.md                   # 本文件
├── Core/                       # 核心源码（日后整目录搬进 Unity Assets/Scripts/Core/）
│   ├── EventBus.cs             # 类型化发布/订阅事件总线
│   ├── IService.cs             # 服务标记接口
│   ├── ServiceRegistry.cs      # 服务注册表（零 manager 硬引用）
│   ├── GameState.cs            # 共享读写状态容器（变更经 EventBus 广播）
│   ├── ConfigLoader.cs         # 从可配置 base path 加载 JSON -> 强类型模型
│   └── Models/                 # 数据模型（字段与 data/*.json 精确对齐）
│       ├── Enums.cs            # Rarity / Element 枚举
│       ├── ShikigamiDef.cs     # 13 式神
│       ├── SkillDef.cs         # 技能（含 status_on_hit 觉醒机制）
│       ├── GachaPool.cs        # 抽卡池（rarity_rates / starter_sr_id 等）
│       ├── CultivationConfig.cs# 养成曲线 / 觉醒映射 / 分支
│       ├── BattleUIConstants.cs# 战斗 HUD 数据驱动配置
│       └── Chapter.cs          # 3 章 27 关
└── Core.Tests/                 # 测试工程（net8.0，xUnit）
    ├── Core.Tests.csproj
    └── ConfigLoaderTests.cs    # 加载真实 data/*.json 并断言
```

---

## 如何运行测试

需要本机安装 **.NET 8 SDK**。

```bash
cd src/core/Core.Tests
dotnet test
```

### 数据路径解析

`ConfigLoader.ResolveDataBasePath()` 按以下顺序定位仓库的 `data/` 目录：

1. 环境变量 **`XIA_CORE_DATA`**（指向仓库 `data/` 的绝对路径，最高优先级）；
2. 从程序运行目录（`AppContext.BaseDirectory`）向上尝试 `data`、`../data` … 共 7 级；
3. 从当前工作目录（`Environment.CurrentDirectory`）向上尝试若干级。

命中判据：该目录下存在 `shikigami/shikigami_defs.json`。

> 提示：若 `dotnet test` 报“未找到 data 目录”，最稳的做法是显式设置环境变量，例如
> `set XIA_CORE_DATA=F:\AI\仙侠卡牌项目\data`（Windows）后重试。

---

## 解耦红线（硬约束）

本层刻意**不持有任何具体 manager 的字段引用**，以对接 Godot 的 autoload 风格：

- **EventBus**：类型化 `Subscribe<T>(Action<T>)` / `Publish<T>(T)` / `Unsubscribe<T>(...)`，内部 `Dictionary<Type, List<Delegate>>`，主线程假定。
- **ServiceRegistry**：`Register<TService>(TService)` / `Resolve<TService>()` / `TryResolve<TService>()`。manager 注册自身，消费者按接口/类型解析；注册时还会按实例实现的各接口登记（不含 `IService` 基接口），避免互覆槽位。
- **GameState**：共享读写状态（当前回合、活跃单位快照等），变更经 EventBus 广播，消费者订阅事件而非轮询。

任何上层（玩法/UI/网络）都**只能**通过上述三者通信，不得 `new` 或 `field` 引用具体 manager。

---

## 字段对齐说明（真实数据来源）

| 模型 | 来源文件 | 备注 |
|------|----------|------|
| `ShikigamiDef` | `data/shikigami/shikigami_defs.json` | 13 式神（N3/R4/SR3/SSR3） |
| `SkillDef` | `data/battle/skill_defs.json` | **注意真实路径在 `battle/` 下**（非 `skill/`）；`status_on_hit` 可为 `null` |
| `GachaPool` | `data/gacha/gacha_pools.json` | `rarity_rates.SSR=0.02`；`starter_sr_id` 仅 `newbie` 池有 |
| `CultivationConfig` | `data/cultivation/cultivation_config.json` | 含 `awaken.skills_by_shikigami` 觉醒映射 |
| `BattleUIConstants` | `data/battle/battle_ui_constants.json` | `element_shapes` / `status_icons`(4) 等 |
| `Chapter` | `data/battle/chapters.json` | 3 章，每章 9 关（8 普通 + 1 Boss），共 27 关 |

枚举 `Rarity`（N/R/SR/SSR）与 `Element`（Metal/Wood/Earth/Water/Fire，对应 JSON 小写）使用 `JsonStringEnumConverter` 反序列化，读取时大小写不敏感。

---

## 日后迁移到 Unity（团结引擎 1.9.3 / Unity 2022.3 LTS）

1. 把 `src/core/Core/*.cs` **整目录复制**到 `Assets/Scripts/Core/`。
2. 在该目录新建程序集定义文件 **`Core.asmdef`**，使核心层独立成 asmdef（不依赖任何具体 manager 的 asmdef）。
3. **删除** `Core.csproj` 与 `Core.Tests/`（测试留在独立的 .NET 工程，或用 Unity Test Framework 重写）。
4. **JSON 解析**：核心层使用 `Newtonsoft.Json`（dll 由 Unity 包 `com.unity.nuget.newtonsoft-json` 提供；.NET 8 侧由 `Core.csproj` 的 NuGet 包提供）。该库在团结引擎 1.9.3（Unity 2022.3 LTS）/ IL2CPP（AOT）下无需源生成器即可工作，比 `System.Text.Json` 更省心。若确实遇 AOT 限制，可将 `ConfigLoader` 的解析替换为 `JsonUtility` 或社区方案，保持 `LoadXxx()` 签名不变即可。

---

## 已知限制 / 待办

- 本 M1 仅覆盖**数据模型 + 解耦基础设施**，未实现玩法/战斗/养成的具体业务逻辑（留待后续 Epic）。
- 沙箱无 dotnet，**所有测试在本工作室未运行**；请在本地 `dotnet test` 验证后再合入。
- `Core.Models` 中的分支（`Branch`）同时含 `dmg_mult` 与 `hp_mult`，仅其一在某分支有值，未使用字段为 `0`，符合源数据。
