# 仙侠卡牌 · 目标架构 ADR（Unity / C# 重基线）

> 角色：engineering-lead（程基岩）｜ 性质：**架构决策文档（ADR），不改任何代码**
> 目的：把 S3 已验证的 Godot 架构**意图**（解耦单例 / EventBus / 数据驱动 / 双端响应式 / 云存档冲突 / 输入抽象 / PvP 模型）**用 Unity 等价机制重新落地**。
> 连续性：既有 `docs/architecture/adr/adr-001..005`（Godot）的**决策意图仍然有效**，本文件是"如何在 Unity 实现那些意图"的 HOW 层 ADR，不推翻原意图。
> 每条 ADR 含：**Status / Context / Decision / Consequences**。

---

## 🔒 Locked Decisions（2026-07-22 用户拍板）

> 下列决策已由主理人/用户 **游承峰** 于 **2026-07-22** 拍板，本文档架构即日冻结；全部 5 条 ADR 状态已更新为 **Accepted**。决策 → 映射 ADR → 对计划的影响如下。

| # | 决策（用户拍板，2026-07-22） | 映射 ADR | 对 `port-plan` / `architecture-adrs` 的影响 |
|---|---|---|---|
| 决策2 | **Unity 版本 = Unity 6 LTS（`6000.x`）+ 2D URP** | ADR-1 | 工程基线锁定；M0 用 Unity 6 + 2D URP 起工程。ADR-1 → Accepted。 |
| 决策5 | **托管策略 = 先留本地 + Core 程序集 `dotnet test` 推进；等 GitHub/PAT 就绪再 push；CI（GameCI）暂挂** | ADR-5 | M4 CI 推迟到 GitHub/PAT 可用；M0「立空 unity-ci.yml」改为「暂挂，待 PAT 就绪再立」。ADR-5 → Accepted 但标 ⏸ 暂挂。 |
| 决策1 | **UI 框架 = UI Toolkit（UXML/USS）为主框架** | ADR-2 | M3 战斗 UI 走 UI Toolkit；美术交付 UXML/USS。ADR-2 → Accepted。 |
| 决策4 | **移动端 = 仅 Android**（⚠️ 偏离 GDD「PC Steam + 移动 iOS/Android」） | ADR-1 / ADR-5 | M4 CI 仅 Android job（删 iOS macOS job）；M5 真机核验仅 Android 设备。ADR-1 去 iOS 表述。 |
| 决策3* | **测试策略 = 纯 UTF + 引擎无关 `Core` 程序集，退役 Python 镜像**（*随 ADR-4 一并锁定，由 M0 删除 `s3_*.py` 落地*） | ADR-4 | M0 删除 `production/qa/s3_*.py`（6 个）；M2/M4 以 UTF + `dotnet test` 为主。ADR-4 → Accepted。 |

> ⚠️ **偏差警示（决策4）**：GDD `design/gdd/01-concept.md:5` 明确「平台：PC Steam + 移动 **iOS/Android**（云存档）」。用户拍板「仅 Android」**覆盖**该表述，iOS 从首发范围移除。建议**上线前复核**是否补 iOS（需 macOS runner + 证书，见 ADR-5 备选）。此偏差已在 `decisions-locked.md` 与 `port-plan.md` 显式记录。
> 🔗 **决策记录指针**：详见新建 `decisions-locked.md`；沙箱限制（无 dotnet / 无 Unity）见 `port-plan.md · Sandbox Limitation`。

---

## ADR-1 · Unity 版本 + 渲染管线

- **Status**：**Accepted（2026-07-22 用户拍板）** —— Unity 6 LTS + 2D URP 锁定；移动端仅 Android（见本文件顶部 Locked Decisions 与 ADR-5）。
- **Context**：
  - 项目是 2D-first 仙侠卡牌对战（回合制、非实时物理），**布局形态保留 PC 横屏 + 移动竖屏响应式（UI Toolkit 断点）**；但**分发/构建目标仅 Android（决策4：移动端仅 Android，取消 iOS）**——GDD 原「PC Steam + 移动 iOS/Android」表述被覆盖。
  - 需要：稳定的 LTS、成熟的 2D 渲染、可挂 CVD 后处理滤镜（替代 Godot 的 Viewport shader，见 `E6-S6`）、`performance_mode` 降级、`Input System`、`Addressables` 成熟。
  - 原 Godot 用 `gl_compatibility`；Unity 侧需等价"轻量 2D 管线"。
- **Decision**：**采用 Unity 6 LTS（`6000.x`）+ 2D URP（Universal Render Pipeline）**。
  - 渲染管线锁定 **2D URP**（非 Built-in Render Pipeline，亦非 HDRP）。
  - 关闭不必要的高端特性；`performance_mode` 通过 Render Scale / 特性开关降级（继承 `E6-S6 AC4`）。
  - CVD 滤镜用 2D URP 的 **Scriptable Render Feature / Fullscreen Pass** 实现，成本远低于自定义 shader 全局后处理。
- **Consequences**：
  - ✅ LTS 支持窗口长、2D URP 轻量（利于包体 <300MB / 帧率预算）、UI Toolkit 与 Input System 原生集成、Addressables 成熟、CVD 滤镜有现成 Render Feature 钩子。
  - ✅ Unity 6 对 UI Toolkit / 2D / 移动构建（IL2CPP）的打磨优于 2022 LTS。
  - ✅ 运行时授权：Unity 6 已调整 runtime fee 条款，卡牌类（低营收阈值内）通常不受影响；若上线营收超阈值需复核条款（标红，待 legal/发行确认）。
  - ✗ **iOS 已取消（决策4）**：原「iOS 需 IL2CPP/AOT、macOS runner、App Store 签名」约束不再适用；仍走 **Android IL2CPP/AOT** 发布构建，故 **Core 程序集须 AOT 安全（禁反射，见 ADR-3 / R7）** 的要求不变。
  - ✗ 2D URP 需一次性管线资产配置（小成本，M0 完成）。
- **备选**：Unity 2022 LTS（生态旧、UI Toolkit 成熟度低）；Unity 6 非 LTS（不稳定，不推荐）；HDRP（过重，违背 2D-first 与包体预算）。

---

## ADR-2 · UI 框架（UI Toolkit vs UGUI）

- **Status**：**Accepted（2026-07-22 用户拍板）** —— UI Toolkit（UXML/USS）为主框架锁定。
- **Context**：
  - 双端卡牌对战，UI 占比极高（卡牌网格、编队、战斗 HUD、连携横幅、气槽、状态图标）。
  - 硬约束（继承 Godot `ADR-001`）：**单套 UI 描述 + 断点驱动布局切换，不另出独立场景**；可访问性（形状冗余 / 44×44 热区 / 高对比 / tabular nums / 文本缩放 100–130%）并入 UI 组件基线。
  - 数据驱动：卡牌列表、数值条、角星由配置/状态驱动。
- **Decision**：**主框架采用 UI Toolkit（UIDocument + UXML + USS）**；仅极端动画密集型叠加（如 3D `CinematicManager` 演出 overlay）才允许局部 UGUI/Canvas 补位。
  - **USS 变量 + 断点**：用 USS custom properties 表达 art-bible 色板（青冥#1F3A3D / 青碧#4FA39B / 月白#E8ECEF / 朱砂#C8453A / 鎏金#CBA75C / 紫宸#8B6DB3）+ 断点（`≥1024` 多栏 / `768–1024` 混合 / `<768` 单列）。`UIThemeController` 切 USS 变量即可实现高对比 / 文本缩放 / 主题切换（对齐 `01-architecture §1.5`）。
  - **数据绑定**：卡牌/编队用 VisualElement 生成 + binding，避免手写 RectTransform 锚点。
  - **可访问性**：形状冗余（圆/三角/方/菱/五边）用 UXML 矢量 + USS；44×44 热区用 USS min-size；tabular nums 用 `FontFeatures`。
- **Consequences**：
  - ✅ USS 的 flex/百分比/媒体查询天然映射 Godot "单套 UI 描述 + 断点切换"，**守住 ADR-001 单描述原则**，避免双份维护（R3 缓解）。
  - ✅ 主题切换 = 切 USS 变量集，天然支持高对比 / CVD / 文本缩放（对齐 `E6-S5/S6`）。
  - ✅ 数据驱动列表（卡组/图鉴）比 UGUI 手写锚点更省工、更不易破版。
  - ✗ UI Toolkit 在**极重实时动画/粒子**场景不如 UGUI 灵活 → 用局部 UGUI overlay 兜底（已声明，范围小）。
  - ✗ 团队需熟悉 UI Builder / USS（学习成本，M0 培训）。
- **备选**：纯 UGUI（Canvas + RectTransform + anchor）——更熟、动画更灵活，但双端断点需手写锚点变体逻辑，**违背 ADR-001 单描述原则、维护成本翻倍**（不推荐为主框架）。

---

## ADR-3 · 解耦架构映射（守住 S3 红线）⚠️ 最关键

- **Status**：**Accepted（2026-07-22 用户拍板，硬要求原样保留）**
- **Context**：
  - **S3 解耦红线（硬要求）**：manager 之间**只经 EventBus / GameState / ConfigLoader / 全局 autoload 名字通信，零 `preload`/`import` 跨管理器引用**。Godot `01-architecture §1.3` 已落地并校验；`BattleManager` 对 `BondManager` 引用为 0（由 `BattleLauncher` 在 `start_battle` 后调 `compute_combo`，B-2/AC2）。
  - Unity 没有 autoload，且 `MonoBehaviour` 之间极易用 `GetComponent<OtherManager>()` 或 `static Instance` 互相硬引用 → **红线在 Unity 比在 Godot 更容易被无意破坏**（R1）。
  - 目标：在 Unity 用等价机制**原样**守住红线。
- **Decision**：映射如下，**并显式禁止 manager 间硬引用**：

  | Godot 机制 | Unity 等价 | 说明 |
  |---|---|---|
  | autoload 单例（15 个） | **静态服务注册表 `GameServices`** 或 ScriptableObject 资产服务（bootstrapper 场景启动时注册） | 引导场景 `Bootstrapper` 在 `Awake` 注册全部服务；业务代码经 `GameServices.Get<T>()` 按**类型/id**取，**不持有对方引用** |
  | `EventBus`（信号中枢） | **静态类型化 `EventBus`**（C# 事件 / struct 事件通道）或 SO 事件通道资产 | 管理器只 `Publish`/`Subscribe` 事件；**不直接引用彼此** |
  | `GameState`（中央真源） | `GameState` 纯 C# 数据类 / SO（单一真源，存档 = 序列化它） | 所有 manager 读写它，变更经 manager 进行 |
  | `ConfigLoader`（配置 + inject/reset） | `ConfigLoader`（Addressables 加载 JSON + schema 校验 + `Inject(id,data)` / `Reset()`） | 测试可注入假表（继承 `test-strategy.md §3`） |
  | `InputBridge`（输入抽象） | Unity **Input System** + `InputBridge` 归一化意图 | `ui_select/ui_back/drag_start|end/long_press/hover_peek`（对齐 `ADR-003`） |
  | 场景树"薄"原则 | UI Toolkit UXML 只做组合/布局，逻辑在 Core/服务 | 继承 `01-architecture §1.2` 原则 |

  **🔴 红线控制清单（程序员可立即执行的一页规则）**：
  1. 任何 manager（业务/服务）**不得**声明 `public OtherManager field` 或 `private OtherManager _x` 引用另一个 manager 类型；**不得** `GetComponent<OtherManager>()` 跨 manager 取引用。
  2. manager 间通信**只允许**三通道：`EventBus.Publish/Subscribe`、`GameState` 读写、`ConfigLoader` 取配置。
  3. 取服务用 `GameServices.Get<T>()`（按类型/id），**拿到即用、不缓存为字段引用**跨帧持有——若必须持有，仅限自身生命周期内的本地计算对象（非其他 manager）。
  4. `BattleManager` 对 `BondManager` 的引用数 **必须 = 0**；连携由 `BattleLauncher` 在 `start_battle` 后调 `BondManager.compute_combo(GameState.deck)`，战斗 HUD 仅经 `EventBus` 的 `bond:combo`（`bond_combo`）渲染横幅（守住 B-2/AC2）。
  5. 颜色值**只**写在 `UIThemeController` 的 USS 变量 / 主题资源，**禁止**硬编码 hex（继承 `CLAUDE.md` 硬约束 2）。
  6. 随机路径**全部**经 `RngWrapper`（固定种子），测试可复现（继承 `CLAUDE.md` 硬约束 5）。
  7. 存档 schema v1 冻结（`free_ten_pull` 解耦、`pity` 不跨池、checksum）原样沿用（继承 `01-architecture §1.7`）。
  8. `bond_bonus` **只缩放直接打击 `Dmg_strike`，不缩放 DoT**（正交，防双 dip 主导策略 R5，继承 `S3-B1 AC5`）。
  9. **架构测试（UTF）**：写一个 `ArchitectureGuardTests`，用反射扫描所有 manager 类型，**断言其字段中不含其他 manager 类型**——把红线变成可自动验证的门禁（对齐 S3 "grep 零 preload" 思路，升级为编译期/测试期检查）。
  10. **CI grep 检查**：在 GameCI 中加一步扫描，禁止 `GetComponent<` 指向 manager 类型 / 禁止 manager 间 `using` 直接 new 彼此（兜底）。

- **Consequences**：
  - ✅ 红线在 Unity **被显式机制 + 自动化测试 + CI 双重守住**，比 Godot 仅靠 `grep` 更强（R1 缓解）。
  - ✅ 依赖图单向分层延续：`Base(Economy/UI-Save) → Content(Gacha/Cultivate/Bond) → Hub(Battle) → Meta(SecretRealm/Story/PvP) → Extension(B6–B10)`（继承 `01-architecture §1.3/§1.4`）。
  - ✅ Core 程序集零 `UnityEngine` 依赖 → 可 `dotnet test` 直跑、AOT 安全（R7 缓解）。
  - ✗ 开发者需习惯"经 EventBus/GameState 取，不持有引用"——初期略绕，靠控制清单 + 架构测试强制。
  - ✗ 命名冲突须 M1 reconciliation（`InputBridge`×2 / `element_shape`×2，用 namespace 隔离）。
- **备选**：纯 `MonoBehaviour` 单例 `Instance` 互相引用——**直接违反红线，否决**。

---

## ADR-4 · 测试策略（Unity Test Framework + 数据驱动逻辑镜像）

- **Status**：**Accepted（2026-07-22 用户拍板：纯 UTF + 引擎无关 Core，退役 Python 镜像）** —— `production/qa/s3_*.py` 由 M0 删除（决策3）。
- **Context**：
  - 原 Godot 策略：`GUT` + 验证驱动 + `ConfigLoader.inject/reset` + 种子 RNG；headless CI（`godot --headless`）。因沙箱无 Godot，S3 用**本地 Python 镜像**（`s3_*.py` 共 183/183）做逻辑 PASS 托底（见 `s3-status-2026-07-20.md`）。
  - Unity 侧：UTF 可在 CI **headless 真跑**（GameCI 跑 Unity headless），不再需要 Python 镜像当"替代品"。但仍想保留"引擎无关纯逻辑可独立测"的能力。
- **Decision**：**主策略 = Unity Test Framework（UTF）**，并把"Python 镜像"思想升级为**引擎无关 `Core` 程序集**：
  - **`Core` 程序集**：所有纯逻辑（Economy/Gacha/Cultivation/Bond/BattleResolver/Status/Save 冲突/Config 校验/RNG）放**零 `UnityEngine` 依赖**的 C# 程序集。
  - **EditMode 测试**（UTF）：覆盖 T1–T7 + S3 新增用例（status_burn / accessibility_settings / motion_scale_cvd / telemetry_loop / player_skill_select / bond_combo_after_start）。保留 `ConfigLoader.Inject/Reset` + 固定种子 RNG，断言与 Godot 版逐数值对齐（对齐 `test-strategy.md §2/§3`）。
  - **PlayMode 测试**（UTF）：双端 UI / 场景加载 smoke（替代 Godot 需视口的 integration 测试）。
  - **`dotnet test` 旁路**：因 Core 零 UnityEngine 依赖，可用 `dotnet test` 直接跑逻辑测试，**不启动 Unity**——这**取代原 Python 镜像**，成为更优的"引擎无关逻辑验证"（R6 的托底手段）。
  - **Python 镜像去留**：不再需要维护 Python 镜像（C# Core 即单一真源）；若用户坚持保留 Python 镜像作为独立校验，作为**可选**旁路（见 `decisions-for-user.md`）。
- **Consequences**：
  - ✅ 逻辑测试可在 CI headless 真跑（GameCI），不再靠 Python 镜像"替代"。
  - ✅ Core 零依赖 → `dotnet test` 直跑，验证最快、最便宜、最 AOT 安全。
  - ✅ 数据驱动 + inject/reset + 种子 RNG 哲学 100% 继承，S3 的 183 条 Python 断言可逐个平移为 C# 断言（等价覆盖）。
  - ✗ PlayMode 双端测试仍需真机/模拟器（继承 S3-DualEnd 环境阻塞）。
  - ✗ 若保留 Python 镜像 = 双份维护成本（不推荐）。
- **备选**：纯 `dotnet test`（放弃 UTF PlayMode / GameCI 真跑 Unity）→ 失去 PlayMode 双端门禁，不推荐;C# + Python 双镜像 → 双份维护，不推荐。

---

## ADR-5 · CI（GameCI + GitHub Actions，替换 GUT CI）

- **Status**：**Accepted（2026-07-22 用户拍板）—— ⏸ CI 骨架因 GitHub 访问阻塞而暂挂，待 PAT 就绪再立 GameCI 骨架（决策5）**
- **Context**：
  - 原 `gut-ci.yml`：GitHub Actions ubuntu-latest + `lihop/setup-godot` + 下载 GUT + `xvfb-run godot --headless ... -gexit`（fail=red）。但 S3 中该 CI **从未实跑**（C-3 未收敛，见 `s3-status`）。
  - Unity 侧 CI 需 license 激活、headless 测试（`utr`）、构建（**仅 Android，需 Linux/Win runner**，见决策4；iOS job 取消）、**且该 CI 骨架目前因 GitHub 访问阻塞而暂挂**（决策5：等 GitHub/PAT 就绪再立）。
- **Decision**：**GameCI `unity-actions`（`game-ci/unity-actions`）+ GitHub Actions**，新建 `unity-ci.yml` 替换 `gut-ci.yml`：
  - 步骤（`unity-ci.yml` 骨架，待 PAT 就绪后再实立）：`checkout` → `game-ci/unity-actions/activate`（license 经 `UNITY_LICENSE` secret / GameCI 授权）→ `unity-actions/test`（跑 UTF EditMode+PlayMode，headless，`-batchmode -nographics`）→ `unity-actions/builder`（**仅 Android 构建（Linux/Win runner）；PC 构建可同 runner；iOS job 取消（决策4）**）。
  - **fail=red 门禁**：UTF 非零退出即阻断合并（对齐 `gut-ci.yml -gexit` 语义）。
  - **CI 骨架与 M1 并行起步**（吸取 S3-C3 教训）：先立空 UTF + 空 workflow，让门禁从 day 1 存在。
  - 缓存：`Library/` 与 Addressables 构建缓存（对齐原 `.godot` 缓存思路）。
- **Consequences**：
  - ✅ 与 GUT CI 等价的 fail=red 门禁；Unity headless 真跑逻辑 + PlayMode。
  - ✅ GameCI 生态成熟，文档充分。
  - ✗ **需要 Unity 激活（license secret）+ runner**；本环境/用户侧 GitHub 访问受限（用户网页打不开、无 PAT）→ **workflow 无法在此验证**（R4+R6）。
  - ✗ ~~iOS 构建需 macOS runner~~（**已取消，决策4：仅 Android，省 macOS runner 与 App Store 签名成本**）。
  - ✗ 首次 `Library` 导入慢，需缓存策略。
- **备选**：GitLab CI / 自托管 runner（结构同，仅 trigger/runner 不同，对齐原 `gut-ci.yml` ADAPTING 注释）；纯本地 `dotnet test` 不接 CI → 失去合并门禁（不推荐）。

> ### ⏸ CI 暂挂说明（决策5 / Sandbox Limitation）
> - **现状**：用户侧 GitHub 网页访问受限、无 PAT；本沙箱既无 Unity 也无 dotnet（`command -v dotnet` = NO_DOTNET，已实测）。故 GameCI 骨架**暂挂**，不在 M0 提交 `unity-ci.yml`。
> - **推进方式**：M0–M4 的逻辑验证改走 **本地 + `dotnet test`**（Core 零 UnityEngine 依赖，引擎无关，见 ADR-4）——这与 S3-C3「GUT 从未实跑」是同类风险，须从第一天规划「用户本机装 Unity + PAT 就绪后立 CI 骨架」来对冲。
> - **解除条件**：GitHub 访问恢复 + 取得 PAT + 本机具备 Unity 后，再立 `unity-ci.yml`（activate→test→build 仅 Android），让 fail=red 门禁从 day 1 生效（吸取 S3-C3 教训）。
> - **风险登记**：在 GitHub/PAT 就绪前，迁移质量门无法端到端验证（R6 最大红旗）；决策5 自带的 `dotnet test` 托底在本沙箱**同样无法执行**（无 dotnet），须落到用户本机。详见 `port-plan.md · Sandbox Limitation` 与 `decisions-locked.md`。

---

【一句话总结】五条 ADR 把 S3 已验证的 Godot 架构意图用 Unity 等价机制重落地：**Unity 6 LTS + 2D URP**（ADR-1，移动端仅 Android）、**UI Toolkit 主框架守单套 UI 描述**（ADR-2）、**EventBus/GameState/ConfigLoader/服务注册表映射 Godot autoload 且用"控制清单 + 架构测试 + CI grep"三重守住解耦红线**（ADR-3，最关键）、**UTF + 引擎无关 Core 程序集取代 Python 镜像**（ADR-4）、**GameCI 替换 GUT CI 立 fail=red 门禁**（ADR-5，⏸ 暂挂待 PAT 就绪）；其中 ADR-3 红线与 ADR-5 CI 骨架是迁移成败的关键，二者均受 R6 环境阻塞影响。
