# 仙侠卡牌 · 引擎迁移评估（Godot 4.3 → Unity C#）

> 角色：engineering-lead（程基岩）｜ 性质：**评估文档，不改任何代码/数据/资产**（仅产出本目录 4 份文档）
> 阶段：技术层全量重基线（Phase 5 之后，S3 已 headless 验证闭环）
> 依据（全部已 Read 确认，非臆造）：
> - `project.godot`（autoload 15 单例、gl_compatibility、无 main_scene）
> - `scripts/*.gd` 实际清单（28 个，已 `find` 核对）
> - `tests/*.gd`（21 个 GUT）、`data/*.json`（10 个）、`art/references/`（31 张）
> - `docs/architecture/01-architecture.md` + `adr/adr-001..005` + `test-strategy.md`
> - `production/s3-plan.md`、`production/epics/s3-epics-stories.md`、`production/s3-status-2026-07-20.md`
> - `.github/workflows/gut-ci.yml`、`CLAUDE.md`
> - git 仓库：分支 main，11 commit（全 Godot 工作，未推送远程）

---

## 0. 一句话结论

**建议执行全量迁移**，但这是"重基线"而非"平移"：引擎无关资产（`data/*.json` / `art/*.png` / 全部 `.md`）**100% 可复用、零改动**；28 个 `.gd` + 1 个 `.tscn` + 21 个 GUT + `project.godot`/`gut-ci.yml`/`CLAUDE.md` **必须按 C# 重写**；**解耦红线（S3 硬要求）必须在 Unity 用等价机制原样守住**。最大红旗是：**本环境/沙箱跑不了 Unity，迁移的质量门（UTF + GameCI）在用户具备 Unity + CI 环境前无法验证**——这与 S3 的 C-3（GUT 从未实跑）是同一类风险，必须一开始就立 CI 骨架。

---

## 1. 可复用清单（引擎无关，零改动或近零改动）

| 类别 | 路径 / 文件 | 数量 | 复用结论 | Unity 侧落点 |
|---|---|---|---|---|
| 配置数据 | `data/shikigami/shikigami_defs.json` | 1 | ✅ 100% 移植（13 式神：N3/R4/SR3/SSR3） | Addressables/Resources 加载，反序列化为类型化数据类 |
| 配置数据 | `data/cultivation/cultivation_config.json` | 1 | ✅ 100% 移植 | 同上 |
| 配置数据 | `data/economy/economy_config.json` | 1 | ✅ 100% 移植（货币分层/日周预算） | 同上 |
| 配置数据 | `data/gacha/gacha_pools.json` | 1 | ✅ 100% 移植（`starter_sr_id:"sr_zhu_que"`、保底不跨池） | 同上 |
| 配置数据 | `data/battle/battle_ui_constants.json` | 1 | ✅ 100% 移植 | 同上 |
| 配置数据 | `data/battle/bond_combos.json` | 1 | ✅ 100% 移植（含 `yu_zu/long_zu/hu_zu`） | 同上 |
| 配置数据 | `data/battle/chapters.json` | 1 | ✅ 100% 移植 | 同上 |
| 配置数据 | `data/battle/element_matrix.json` | 1 | ✅ 100% 移植（五行网状克制） | 同上 |
| 配置数据 | `data/battle/skill_defs.json` | 1 | ✅ 100% 移植（含 `power/element/status_on_hit`） | 同上 |
| 配置数据 | `data/battle/status_config.json` | 1 | ✅ 100% 移植（burn/poison/armor_break/momentum） | 同上 |
| 美术参考 | `art/references/*.png`（A1–A4 参考图 + 美术圣经图） | 31 | ✅ 100% 移植（PNG 引擎无关） | 直接进 Addressables；**生产级导出尺寸**（PC 2048×3072 / 移动 1024×1536 + VRAM 压缩）仍待 art-director 交付，非阻塞 |
| 设计/文档 | `design/ docs/ production/` 全部 `.md` | ~40 | ⚠️ 100% 可移植，**但部分正文引用 Godot 术语**（如 `res://`、`preload`、`test-strategy.md` 的 GUT 代码样例、`01-architecture.md` 的 `res://` 目录图、`gut-ci.yml` 注释）。建议 M5 或并行做一轮"措辞去 Godot 化"，**不阻塞迁移** | 仅文档措辞，无运行影响 |
| 存档 schema | `01-architecture.md §1.7` SaveSchema v1 | 1 | ✅ 冻结基线直接沿用（含 `free_ten_pull` 解耦、`pity` 不跨池、checksum） | 反序列化为 `GameState` 数据类 |

> **数据层零改动验证（见风险登记 R5）**：10 个 JSON 已被 S3 的 `verify_s3_art.py` / `s3_asset_data_python_check.py`（7/7）校验。Unity 侧 `ConfigLoader` 上线后，用**同一组 JSON**跑"加载→schema 校验→关键查询"断言，证明零改动即被消费（这是 M1 的退出准则之一）。

---

## 2. 须重写清单（引擎耦合，按 C# 重写）

### 2.1 28 个 `scripts/*.gd` → C#（含 Godot 角色与 Unity 落点映射）

| # | Godot 文件 | 原角色（autoload / 模块） | Unity 落点 | 难度 SP |
|---|---|---|---|---|
| 1 | `autoload/EventBus.gd` | 全局信号中枢（解耦核心） | `EventBus`（静态类型化事件总线 / SO 事件通道） | 1 |
| 2 | `autoload/GameState.gd` | 玩家档案中央真源（存档载体） | `GameState`（SO 或纯 C# 单例数据类） | 2 |
| 3 | `autoload/ConfigLoader.gd` | 配置表加载/校验/热重载 + inject/reset | `ConfigLoader`（Addressables JSON + schema 校验 + Inject/Reset） | 3 |
| 4 | `autoload/AccessibilitySettings.gd` | 可访问性单例 + `accessibility_changed` | `AccessibilitySettings`（peer 服务） | 1 |
| 5 | `autoload/UIThemeController.gd` | 断点/主题/布局模式 | `UIThemeController`（USS 变量 + 断点驱动 layout） | 3 |
| 6 | `autoload/InputBridge.gd` | 输入抽象（select/back/drag/long_press/hover_peek） | `InputBridge`（Unity Input System 归一化意图） | 3 |
| 7 | `autoload/SaveManager.gd` | 本地存读 + 协调云 | `SaveManager` | 3 |
| 8 | `autoload/CloudSaveService.gd` | 云同步/冲突（MVP 桩） | `CloudSaveService`（接口齐备，后端空） | 2 |
| 9 | `autoload/EconomyManager.gd` | B1 经济闭环/预算 | `EconomyManager` | 3 |
| 10 | `autoload/GachaManager.gd` | B2 抽卡/保底 | `GachaManager` | 3 |
| 11 | `autoload/CultivationManager.gd` | B3 养成最终式神 | `CultivationManager` | 3 |
| 12 | `autoload/BondManager.gd` | A1 羁绊连携 | `BondManager` | 3 |
| 13 | `autoload/DeckBuilder.gd` | B4 编队 | `DeckBuilder` | 3 |
| 14 | `autoload/BattleManager.gd` | B4 战斗状态机 + `step()` | `BattleManager` | 8 |
| 15 | `autoload/StatusManager.gd` | 状态系统（burn 叠层/DoT） | `StatusManager` | 3 |
| 16 | `core/BattleLauncher.gd` | 战斗启动协调（start_battle 后发 compute_combo） | `BattleLauncher` | 2 |
| 17 | `core/DemoLoop.gd` | Demo 飞轮编排 | `DemoLoop` | 3 |
| 18 | `core/TelemetryAggregator.gd` | 埋点聚合（抽→养→战→回流） | `TelemetryAggregator` | 1 |
| 19 | `ui/BattleHUD.gd` | 战斗 HUD（双端） | `BattleHUD`（UI Toolkit UXML/USS） | 8 |
| 20 | `ui/ComboBanner.gd` | 连携横幅 | `ComboBanner`（UIE） | 2 |
| 21 | `ui/QiGauge.gd` | 气槽控件（tabular/≥44px） | `QiGauge`（UIE） | 2 |
| 22 | `ui/SkillButton.gd` | 技能按钮（双端热区） | `SkillButton`（UIE） | 2 |
| 23 | `ui/StatusIcon.gd` | 状态图标（三重冗余） | `StatusIcon`（UIE） | 2 |
| 24 | `ui/element_shape.gd` | 五行形状冗余（UI 端） | `ElementShape`（UIE 视觉） | 1 |
| 25 | `ui/InputBridge.gd` | ⚠️ **与 #6 同名文件**（ui 目录副本） | 并入 #6 `InputBridge`，消除重复 | 0（合并） |
| 26 | `utils/element_shape.gd` | 五行形状工具（算法端） | `ElementShapeUtil`（纯逻辑，入 Core 程序集） | 1 |
| 27 | `utils/rng.gd` | 种子化 RNG 封装 | `RngWrapper`（Core，std `System.Random` 固定种子，AOT 安全） | 1 |
| 28 | （合计） | — | — | **合计 ≈ 64 SP** |

> ⚠️ **命名冲突须 reconciliation（M1 处理）**：`scripts/ui/InputBridge.gd` 与 `scripts/autoload/InputBridge.gd` 同名；`scripts/ui/element_shape.gd` 与 `scripts/utils/element_shape.gd` 同名。Godot 靠路径区分，Unity C# 要求类型名唯一（或显式 namespace）。迁移时：UI 版 InputBridge 并入 autoload 版；`element_shape` 拆为算法端（`ElementShapeUtil`，入 Core 程序集）+ UI 端（`ElementShapeView`，入 UI 程序集），用 namespace 隔离。

### 2.2 场景 / 测试 / 工程配置（须重写）

| 项目 | 文件 | 重写说明 | 难度 SP |
|---|---|---|---|
| 战斗场景 | `scenes/battle/BattleHUD.tscn` | 重写为 UI Toolkit `BattleHUD.uxml` + `BattleHUD.uss`（双端断点布局） | 8 |
| 测试 | `tests/*.gd`（21 个 GUT） | 重写为 UTF（EditMode 纯逻辑 + PlayMode 双端/场景 smoke）。T1–T7 优先测试 + S3 新增用例（status_burn / accessibility_settings / motion_scale_cvd / telemetry_loop / player_skill_select / bond_combo_after_start） | 5 |
| 工程配置 | `project.godot` | 无 Unity 等价；重写为 Unity `ProjectSettings` + `Packages/manifest.json` + 程序集定义（`.asmdef`） | 1 |
| CI | `.github/workflows/gut-ci.yml` | 重写为 GameCI `unity-ci.yml`（utr + GitHub Actions） | 2 |
| 工程约定 | `CLAUDE.md` | 重写：引擎改为 团结引擎 1.9.3（Unity 2022.3 LTS）+ C#；架构硬约束改写为 Unity 等价（见 `architecture-adrs.md` ADR-3） | 1 |

> **逻辑算法可移植但须用 C# 重实现**：五行克制、保底、养成曲线、连携、状态 DoT、存档冲突等算法是引擎无关的纯逻辑，可从 `.gd` 逐函数翻译到 C#（建议放 `Core` 程序集、零 `UnityEngine` 依赖，便于 `dotnet test` 直接跑、也便于 AOT/iOS）。但**不是复制粘贴**——GDScript 与 C# 在类型系统、null、字典、信号上有差异，需重写 + 重测。

---

## 3. 风险登记（Risk Register）

| ID | 风险 | 可能性 | 影响 | 红旗 | 缓解（对应里程碑/ADR） |
|---|---|---|---|---|---|
| **R1** | **解耦红线在 Unity 落地风险**：Unity 极易用 `Singleton.Instance` / `GetComponent<OtherManager>()` 互相硬引用，破坏"零跨 import"红线 | 高 | 高 | 🚩 | ADR-3 显式禁止 + 控制清单（一页规则）+ UTF 架构测试（断言 manager 间无字段硬引用）+ CI grep 检查。M2 每 Story 验收含"grep 零跨 manager 引用" |
| **R2** | **双端 UI 在 Unity 落地**：PC 横屏 ≥1024 / 移动竖屏 <768，旋转安全、焦点不丢、热区 ≥95%、灰阶可辨 | 中 | 高 | 🚩 | UI Toolkit USS 断点驱动（ADR-2）；沿用 Godot `UIThemeController` 断点三档思路；M3 双端真机核验（对齐 S3-DualEnd） |
| **R3** | **GUT → Unity Test Framework 迁移**：21 用例 + inject/reset + 种子 RNG 哲学需平移，headless 等价物需重建 | 中 | 高 | — | ADR-4：Core 程序集零 UnityEngine 依赖 → EditMode/dotnet 直跑；保留 inject/reset + 种子 RNG；M4 门禁 |
| **R4** | **CI 切换（GameCI）**：GitHub Actions 跑 Unity 需 license 激活 + runner；iOS 需 macOS runner（计费） | 中 | 中 | — | ADR-5：GameCI `unity-actions`；fail=red 门禁；但**本环境跑不了**（见 R6） |
| **R5** | **数据层零改动验证**：10 JSON 须被 Unity `ConfigLoader` 零改动消费，避免悄悄改数据格式 | 低 | 高 | — | M1 退出准则：用原 10 JSON 跑"加载→schema 校验→关键查询"全绿；不新增/不改字段 |
| **R6** 🚩 | **最大红旗：沙箱/本环境跑不了 Unity**：无法验证 headless 构建、UTF EditMode、GameCI、perf、双端。S3 的 GUT CI（C-3）同样从未实跑 | 确定（当前） | 高 | 🚩🚩 | **迁移首务 = 立 CI 骨架 + 用户本地装 团结引擎 1.9.3（Unity 2022.3 LTS，已安装）**（类比 S3-C3 第一要务）。在所有门禁可跑前，正确性只能靠"逻辑可移植性 + Core 程序集可 `dotnet test`"托底。详见 `decisions-for-user.md` |
| **R7** | **C# 类型/iOS IL2CPP AOT**：核心逻辑若用反射/动态特性会撞 AOT 限制 | 中 | 中 | — | Core 程序集禁用反射；RNG 用 `System.Random` 固定种子；M2 起保持 AOT 安全 |
| **R8** | **包体 <300MB / 帧率预算**：Unity 基础运行时 + Addressables + URP/UI Toolkit | 中 | 中 | — | ADR-1 选 2D URP（轻于 HDRP）；Addressables 流式；`performance_mode` 降级（继承 E6-S6）；M5 perf 核验 |
| **R9** | **命名冲突（InputBridge×2 / element_shape×2）** 致 Unity 编译失败或误引用 | 高 | 低 | — | M1 reconciliation，namespace 隔离（见 §2.1 注） |
| **R10** | **文档措辞漂移**：既有 `.md` 引用 Godot 术语，新人按文档易写错 | 中 | 低 | — | M5 或并行"去 Godot 化"措辞 pass（不阻塞） |

---

## 4. 工作量粗估

> 假设：1 名熟悉本项目 Godot 代码 + 可写 C# 的资深工程师（即沿用 S3 同一作者上下文，red-line 纪律已知）。若加第 2 名 C# 工程师，M2/M3 可并行压缩 ~30%。
> SP = Story Point（1/2/3/5/8，Fibonacci）；人天按 1 SP ≈ 0.7–1.0 人天折算（含重写 + 重测 + 文档）。

| 模块 | 对应 .gd / 资产 | SP | 人天（范围） | 里程碑 |
|---|---|---|---|---|
| 工程骨架 + 程序集 + 引导场景 + bootstrapper | `project.godot` → Unity 工程 | 5 | 3–5 | M0 |
| 数据/配置层（ConfigLoader + Addressables + JSON schema 校验 + inject/reset） | `ConfigLoader.gd` + 10 JSON | 6 | 4–6 | M1 |
| 核心逻辑端口（15 autoload + 3 core + 2 utils + GameState/Save） | #1–#18, #26–#27 | 47 | 25–35 | M2 |
| 战斗 UI 双端（UI Toolkit：HUD/Combo/Qi/Skill/Status/Element + .tscn→.uxml） | #19–#24 + `BattleHUD.tscn` | 17 | 12–18 | M3 |
| 测试移植 + GameCI（21 GUT→UTF + CI 骨架） | `tests/*.gd` + `gut-ci.yml` | 7 | 8–12 | M4 |
| 打磨（perf <300MB/60fps、CVD/MotionScale、双端真机、文档去 Godot 化） | 全量 | 8 | 6–10 | M5 |
| **合计** | — | **≈ 90 SP** | **≈ 58–86 人天（≈ 12–18 周 / 单人）** | — |

> 注：上表不含美术生产级导出（art-director 职责，非 eng 阻塞）与真实云后端（ADR-002 缺口，待排期）。

---

## 5. 推荐端口顺序（与 `decisions-for-user.md` / `port-plan.md` 对齐）

按依赖与风险排序，**实现顺序**为：

1. **数据/配置层（M1）** — 一切基础；`ConfigLoader` + 10 JSON 零改动消费；red-line 的"经 ConfigLoader 通信"由此落地。
2. **核心逻辑（M2）** — 15 manager + EventBus + GameState + 存档；headless 可测；**此处强守 red-line（R1）**。
3. **战斗 UI 双端（M3）** — 依赖核心逻辑 + 美术；UI Toolkit 断点布局；继承 ADR-001 单套 UI 描述原则。
4. **测试（M4）** — 21 GUT→UTF，保留 inject/reset + 种子 RNG。
5. **CI（M4 并行）** — GameCI `unity-ci.yml`，fail=red。

> ⚠️ **顺序修正（吸取 S3 教训）**：虽然"CI"在推荐实现顺序里排最后，但**CI 骨架（空 UTF + GameCI 工作流）必须在 M0/M1 就立起来**，与 S3-C3"第一要务"一致——否则全量回归无门禁，正确性只能靠人工口说（R6 会放大此风险）。即：**实现按 1→2→3→4，但 CI 骨架与 1 并行起步**。

---

【一句话总结】引擎无关资产（data/art/design 共 ~80 项）100% 可复用、零改动；28 `.gd`+1 `.tscn`+21 GUT+3 工程文件须按 C# 重写（≈90 SP / 12–18 周单人）；**解耦红线必须在 Unity 用 EventBus/GameState/ConfigLoader 等价机制原样守住（R1）**，且**最大红旗是本环境跑不了 Unity、迁移门禁在用户具备 Unity+CI 前无法验证（R6）**；推荐端口顺序 数据→核心逻辑→战斗 UI→测试→CI，但 CI 骨架须与数据层并行起步。
