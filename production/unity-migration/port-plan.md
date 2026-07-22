# 仙侠卡牌 · 分阶段端口计划（Unity / C# 重基线）

> 角色：engineering-lead（程基岩）｜ 性质：**计划文档，不改任何代码**
> 对齐：`migration-assessment.md`（工作量/风险）、`architecture-adrs.md`（5 条 ADR）、S3 既有 `s3-plan.md` / `s3-epics-stories.md`（连续性）、`docs/architecture/adr/adr-001..005`（意图延续）
> 总工作量：≈ 90 SP / 58–86 人天（单人资深工程师，见评估 §4）
> **铁律**：每阶段有"退出准则（Exit Criteria）"，未达不得进下一阶段；CI 骨架（M0）须与数据层（M1）并行起步。

---

## 里程碑总览

| 里程碑 | 目标 | 主要 ADR | 依赖 | 人天 |
|---|---|---|---|---|
| **M0** 重基线仓库结构 | Unity 工程骨架 + 程序集 + bootstrapper + CI 骨架（⏸ 暂挂，决策5） | ADR-1/3/5 | 用户拍板 ADR-1/2/4/5 | 3–5 |
| **M1** 数据 + 配置层 | ConfigLoader + 10 JSON 零改动消费 | ADR-3/4 | M0 | 4–6 |
| **M2** 核心逻辑端口 + headless 测试 | 15 manager + EventBus + GameState + 存档 | ADR-3/4 | M1 | 25–35 |
| **M3** 战斗 UI 双端 | UI Toolkit 战斗 HUD 双端 | ADR-2/3 | M2 + 美术 | 12–18 |
| **M4** 测试 + CI | 21 GUT→UTF + GameCI 全绿（仅 Android，⏸ 暂挂待 PAT） | ADR-4/5 | M2/M3 | 8–12 |
| **M5** 打磨 | perf / CVD / 仅 Android 真机 / 文档去 Godot 化 | ADR-1/2 | M3/M4 | 6–10 |

---

## M0 · 重基线清单（Re-baseline Checklist）

> 本清单给出在**真实 Unity 环境**执行 M0 的明确步骤（删除 Godot 耦合 / 保留引擎无关 / 新建 Unity 结构）。凡标注「⚠️ 沙箱无法代劳」者，须在用户本机 Unity/.NET 环境完成（见文末 **Sandbox Limitation**）。
> 🔗 决策记录指针：本清单落实 `decisions-locked.md` 的 4 项锁定决策（2026-07-22）。

### ① 删除（Godot 耦合）

| 条目 | 路径 / 数量 | 操作 | 依据 |
|---|---|---|---|
| GDScript 脚本 | `scripts/*.gd`（**28** 个，含 autoload / utils） | 删除整个 `scripts/` | 决策：Unity/C# 重基线，GDScript 退役 |
| Godot 场景 | `scenes/*.tscn`（**1** 个） | 删除 `scenes/` | Godot 场景，Unity 用 UXML/Prefab 替代 |
| GUT 测试 | `tests/*.gd`（**21** 个） | 删除 `tests/` | GUT 退役，UTF 替代（ADR-4） |
| Godot 工程文件 | `project.godot`（根） | 删除 | Godot 工程入口 |
| Godot 缓存 | `.godot/`（根，已被 .gitignore） | 删除 | 引擎生成缓存 |
| GUT CI | `.github/workflows/gut-ci.yml` | 删除 | 被 GameCI 取代（ADR-5） |
| CLAUDE.md 的 Godot 引用 | `CLAUDE.md` | **改写**（去 Godot 表述，改 Unity 6 LTS + C# + 红线控制清单） | 引擎改 Unity（M0 详解 #6） |
| Python 逻辑镜像 | `production/qa/s3_*.py`（**6** 个：`s3_asset_data_python_check` / `s3_b1_b3_python_logic_smoke` / `s3_c4_python_cache_rollback` / `s3_e5_python_logic_mirror` / `s3_e6_python_logic_mirror` / `s3_ui_battle_python_mirror`） | 删除 | **决策3 退役 Python 镜像**，Core 程序集取代 |

> 📌 注：`production/qa/` 下另有 `s1-python-logic-smoke.py` / `s2-python-logic-smoke.py` / `verify_s3_art.py` 三个 `.py` **不属于 `s3_*` 模式**，不在本次删除范围（属 S1/S2 阶段产物，是否退役另议）。

### ② 保留（引擎无关）

| 条目 | 路径 | 理由 |
|---|---|---|
| 配置数据 | `data/*.json` | 零改动消费（M1 ConfigLoader） |
| 美术资产 | `art/*.png` | Unity 直接引用（含 `art/preview-s3/` 预览副本，见忽略规则） |
| 设计 / 文档 | `design/` `docs/` `production/`（**Unity 迁移文档除外**） | 引擎无关，保留 |
| 迁移文档集 | `production/unity-migration/` | 本文档集，保留 |
| 预览忽略规则 | `art/preview-s3/`（在 `.gitignore`） | 预览副本不入库，**新建 Unity `.gitignore` 时务必保留此条** |

### ③ 新建（Unity 结构）

| 条目 | 路径 / 说明 | 注意 |
|---|---|---|
| Unity 工程根 | `Assets/` `Packages/` `ProjectSettings/` | ⚠️ **需在 Unity Editor 打开一次以生成 `ProjectVersion.txt` 等元数据；沙箱无法代劳**，须用户本机完成 |
| Unity 标准 `.gitignore` | 替换当前 Godot `.gitignore` | ⚠️ **保留 `art/preview-s3/` 忽略规则**（见 ②） |
| 引擎无关 Core | `Assets/Scripts/Core/`（**零 `UnityEngine` 依赖**） | 承载 `EventBus` / `GameState` / `ConfigLoader` / 服务注册表，映射解耦红线（ADR-3） |
| 程序集定义 | `.asmdef`：`Core` / `Services` / `UI` / `Tests`（EditMode/PlayMode） | 见 M0 详解 #2 |
| 引导启动 | `Bootstrapper` 场景 + `GameServices` 注册表 | 见 M0 详解 #3（ADR-3 映射） |

### ④ 决策记录指针
- 本清单落实 `decisions-locked.md`（2026-07-22 锁定：决策2 Unity 6 LTS / 决策5 托管暂挂 / 决策1 UI Toolkit / 决策4 仅 Android / 决策3 退役 Python 镜像）。
- 沙箱限制（无 dotnet / 无 Unity）见文末 **Sandbox Limitation** 章节。

---

## M0 详解 · 重基线仓库结构（Re-baseline Details）

- **目标**：在 `production/unity-migration/` 之外不动旧 Godot 文件，新建 Unity 工程骨架（**决策5：先留本地，待 GitHub/PAT 就绪再决定远端**），建立程序集边界与引导启动，并**立起空 CI 骨架改为暂挂**（见 Sandbox Limitation）。
- **关键动作**：
  1. Unity 6 LTS 工程 + 2D URP 管线资产（ADR-1）。
  2. 程序集定义（`.asmdef`）：`Core`（零 UnityEngine 依赖）、`Services`、`UI`、`Tests`（EditMode/PlayMode）。
  3. `Bootstrapper` 场景 + `GameServices` 注册表（ADR-3 映射）。
  4. 重命名 reconciliation：`InputBridge`×2 → 单例；`element_shape`×2 → `ElementShapeUtil`(Core) + `ElementShapeView`(UI)，namespace 隔离（评估 R9）。
  5. **`unity-ci.yml` 暂挂**（决策5：CI 因 GitHub 访问阻塞而暂挂，待 PAT 就绪再立；当前以本地 `dotnet test` 托底，见 Sandbox Limitation）。
  6. 重写 `CLAUDE.md`：引擎改 Unity 6 LTS + C#；硬约束改写为 ADR-3 控制清单。
- **退出准则（Exit Criteria）**：
  - [ ] Unity 6 + 2D URP 工程可打开、可空场景运行。
  - [ ] 4 个 `.asmdef` 编译通过，Core 零 UnityEngine 引用（架构测试可验证）。
  - [ ] `Bootstrapper` 启动后 `GameServices.Get<EventBus>()` 可取。
  - [ ] 命名冲突已消除（编译无重复类型）。
  - [ ] ~~`unity-ci.yml` 已提交~~（**暂挂，决策5**：M0 不提交；改为在 `decisions-locked.md` / Sandbox Limitation 记录「待 PAT 就绪再立」，当前以本地 `dotnet test` 为门禁替代）。
  - [ ] `CLAUDE.md` 已更新为 Unity 版本 + 红线控制清单。

---

## M1 · 数据 + 配置层（Data & Config）

- **目标**：`ConfigLoader` 加载 10 个现有 JSON（**零改动**），schema 校验，暴露 `LoadTable<T>(id)` + `Inject/Reset`（继承 `test-strategy.md §3`）。验证"数据层零改动"（评估 R5）。
- **关键动作**：
  1. 类型化数据类：`ShikigamiDef` / `CultivationConfig` / `EconomyConfig` / `GachaPool` / `BattleUiConstants` / `BondCombo` / `Chapter` / `ElementMatrix` / `SkillDef` / `StatusConfig`（字段对齐 10 JSON）。
  2. `ConfigLoader`：Addressables 或 `Resources` 加载 JSON → `JsonConvert`/原生 JSON → schema 校验（缺字段即报错，继承 ADR-004）→ `Inject/Reset` 供测试。
  3. `RngWrapper`（Core，固定种子，AOT 安全）。
- **退出准则**：
  - [ ] **10 个原 JSON 零改动**被加载并 schema 校验通过（不新增/不改字段）。
  - [ ] 关键查询断言全绿：如 `shikigami_defs` 13 条且稀有度分布 N3/R4/SR3/SSR3、`gacha_pools.starter_sr_id=="sr_zhu_que"`、`element_matrix` 五行倍率区间正确、`bond_combos` 含 `yu_zu/long_zu/hu_zu` 且各 ≥2 成员、`skill_defs` 含 12 基础技+4 觉醒技。
  - [ ] `Inject/Reset` 单测通过（可注入假表、复位）。
  - [ ] EditMode 测试（UTF）首个空壳跑通，接 CI 骨架（fail=red 生效）。

---

## M2 · 核心逻辑端口 + headless 测试（Core Logic）

- **目标**：15 个 autoload manager + 3 core + 2 utils → C#，headless 可测；**强守解耦红线**（R1）。
- **关键动作**（按依赖序，对齐 `01-architecture §1.4` 模块分解）：
  1. `EventBus`（静态类型化）+ `GameState`（存档 schema v1 冻结，含 `free_ten_pull`/`pity`/checksum）。
  2. 业务 manager：Economy(B1) → Gacha(B2) → Cultivation(B3) → Bond(A1) → DeckBuilder(B4) → StatusManager + BattleManager(B4，`step()` 接收技能/目标 + power 数据化，继承 `S3-B1/B3`) → BattleLauncher（start_battle 后 `compute_combo`，**零 BondManager 引用**）。
  3. `SaveManager` + `CloudSaveService`（MVP 桩，last-write-wins + cache 回滚，继承 ADR-002）。
  4. `AccessibilitySettings` + `UIThemeController` + `InputBridge`（Input System 归一化意图，继承 ADR-003）。
  5. `TelemetryAggregator`（抽→养→战→回流四类事件贯通，继承 `E5-S3`）。
  6. **架构测试 `ArchitectureGuardTests`**：反射断言 manager 字段无跨 manager 引用（ADR-3 控制清单 #9）。
- **退出准则**：
  - [ ] **headless 核心闭环**（抽→养→战→回流）EditMode 全绿（对齐 S3 headless 验证）。
  - [ ] T1–T7 全绿：T1 经济闭环（含 `free_ten_pull` 不计入软预算）/ T2 五行克制 / T3 存档冲突+cache 回滚 / T4 抽卡保底（90 硬保底、不跨池、种子可复现）/ T5 可访问性单例 / T6 羁绊连携（零跨 import）/ T7 养成最终式神。
  - [ ] S3 新增用例绿：status_burn（灼烧叠层/水克火压制/木克增益/与连携不双 dip）/ accessibility_settings / motion_scale_cvd / telemetry_loop / player_skill_select / bond_combo_after_start（`_bond_bonus>0`）。
  - [ ] **`ArchitectureGuardTests` 通过**：`BattleManager` 对 `BondManager` 引用数 = 0；全 manager 字段无跨 manager 硬引用。
  - [ ] `bond_bonus` 仅缩放直接打击、不缩放 DoT（R5 正交，断言验证）。
  - [ ] CI 门禁：上述 EditMode 全绿，非零退出阻断合并。

---

## M3 · 战斗 UI 双端（Battle UI, Dual-End）

- **目标**：UI Toolkit 重写 `BattleHUD`（`.tscn` → `.uxml`/`.uss`），双端断点布局 + 可访问性。
- **关键动作**：
  1. `BattleHUD.uxml` + `BattleHUD.uss`：单套描述 + 断点（`≥1024` 多栏 / `768–1024` 混合 / `<768` 单列），继承 ADR-001 单描述原则。
  2. UIE 控件：`ComboBanner`（监听 `bond:combo`）/ `QiGauge`（tabular/≥44px）/ `SkillButton`（双端热区）/ `StatusIcon`（三重冗余）/ `ElementShapeView`（圆/三角/方/菱/五边）。
  3. USS 变量承载 art-bible 色板 + 高对比主题 + 文本缩放 100–130%（继承 `E6-S5/S6`）。
  4. CVD 滤镜用 2D URP Render Feature（继承 `E6-S6 AC3`）；`MotionScale` 动效总线（继承 `E6-S6`）。
  5. `InputBridge` 双端意图（drag/long_press/hover_peek）接 UIE 交互。
- **退出准则**：
  - [ ] 单套 UXML/USS 在 ≥1024（如 1280×720）与 <768（如 390×844）**不破版、0 溢出、0 裁切**。
  - [ ] 旋转/分辨率切换不崩、焦点不丢（对齐 `E5-S4` / `S3-DualEnd AC2`）。
  - [ ] 热区命中率 ≥95%（移动 ≥44px）；五行形状灰阶可辨（对齐 `S3-DualEnd AC3`）。
  - [ ] `ComboBanner` 数值 = `bonus_pct`（2 人 +10% / 3+ +17.5% 中点）。
  - [ ] 可访问性 Basic 全项（对比度/高对比/缩放 tabular/三重反馈/色盲冗余）达成。
  - [ ] **注**：双端真机核验需真机/模拟器（继承 S3-DualEnd 环境阻塞，M5 回填）。

---

## M4 · 测试 + CI（Test & CI Hardening）

- **目标**：21 个 GUT 全量平移为 UTF；GameCI 全绿（仅 Android，⏸ 推迟到 GitHub/PAT 可用，决策5），fail=red 门禁生效。
- **关键动作**：
  1. 21 GUT → UTF（EditMode 纯逻辑 17 + PlayMode 双端/场景 smoke 4），逐数值对齐 S3 Python 镜像（183/183）。
  2. GameCI `unity-ci.yml` 实跑（**推迟到 GitHub/PAT 可用，决策5**）：`activate` → `test`（EditMode+PlayMode headless）→ `build`（**仅 Android（Linux/Win runner）；iOS job 删除（决策4）**）。
  3. CI 加架构测试 + grep 检查（ADR-3 控制清单 #10）。
- **退出准则**：
  - [ ] **21 个原 GUT 用例 100% 平移并全绿**（含 S3 新增 6 项）。
  - [ ] GameCI `unity-ci.yml` 实跑（**在用户具备 Unity+CI 环境且 PAT 就绪后，决策5**）逻辑+PlayMode 全绿，非零退出阻断合并（当前以本地 `dotnet test` 托底，⚠️ 沙箱无 dotnet 见 Sandbox Limitation）。
  - [ ] 架构测试 + grep 检查进 CI 门禁。
  - [ ] ⚠️ 若本环境仍跑不了 Unity（R6），此退出准则标 CONCERNS，待用户环境就绪回填（类比 S3-C3）。

---

## M5 · 打磨（Polish & Verification）

- **目标**：性能预算、CVD/MotionScale 真机观感、**仅 Android 真机核验**、文档去 Godot 化。
- **关键动作**：
  1. perf 预算：包体 <300MB（PC）、PC ≥60fps、移动 30–60fps（继承 `01-architecture §1.9`）；`performance_mode` 降级验证。
  2. 真机核验：**仅 Android 设备**（移动竖屏）跑通核心闭环（PC 横屏可本机编辑器验证；**iOS 真机核验取消，决策4**），回填 `production/qa/`。
  3. CVD/MotionScale 真机切换观感（灰阶形状不依赖色）。
  4. 文档去 Godot 化：既有 `.md` 中 `res://`/`preload`/GUT 代码样例措辞更新（评估 R10）。
  5. 美术生产级导出尺寸核对（PC 2048×3072 / 移动 1024×1536 + VRAM 压缩，art-director 交付）。
- **退出准则**：
  - [ ] 包体 <300MB、PC ≥60fps、移动 30–60fps（真机 profiling）。
  - [ ] **Android** 核心闭环真机跑通 + 旋转/焦点稳定 + 热区 ≥95% + 灰阶可辨（回填 QA 证据；**iOS 真机核验取消，决策4**）。
  - [ ] 可访问性 CONCERN 闭合（AccessibilitySettings/MotionScale/CVD 全绿）。
  - [ ] 既有 `.md` 措辞无 Godot 硬引用遗留（或明确标注 Unity 语境）。
  - [ ] 收口判据：`ArchitectureGuardTests` + UTF 全绿 + 双端真机双层验证同时 PASS（对齐 S3 `s2-vertical-slice-playtest` 模型）。

---

## Sandbox Limitation（沙箱限制）

> 本环境（CodeBuddy 沙箱）**既跑不了 Unity Editor，也没有 dotnet**。已实测：`command -v dotnet` → **NO_DOTNET**；`command -v unity` → **NO_UNITY**。

### 影响
- **M1–M5 的 C# 代码无法在此编译 / 自测**：Unity 工程（`Assets/` `Packages/` `ProjectSettings/`）、`.asmdef`、UTF 测试均无法在沙箱内构建或运行。
- **可编写，不可验证**：本环境可以**文本形式**编写 C# 源文件（如 `Assets/Scripts/Core/` 下的 `EventBus` / `GameState` / `ConfigLoader`），但编译、单测、PlayMode、构建、真机核验**必须落到用户本机 Unity / .NET 环境**。
- **与 S3-C3「GUT 从未实跑」是同一类风险**：质量门在工具链就绪前无法端到端验证（R6 最大红旗）。S3 用本地 Python 镜像托底，本迁移则用**引擎无关 `Core` 程序集 + `dotnet test`** 托底（ADR-4）——但本沙箱连 `dotnet` 都没有，故连 `dotnet test` 托底在沙箱内也跑不了。

### 对决策5「dotnet test」策略的关键影响 ⚠️
- 决策5 原设想「先留本地 + **Core 程序集 `dotnet test` 推进**，等 GitHub/PAT 就绪再 push；CI 暂挂」。
- **但沙箱无 dotnet**，意味着即便决策5 已为 CI 安排了 `dotnet test` 这条本地托底路径，它**在沙箱内仍无法执行**。换言之：在本环境里，M0–M4 的「逻辑验证」既无 GameCI、也无 `dotnet test` 可用，只剩「文本编写 + 人工审阅」。
- **对冲（须从第一天规划）**：① 用户本机安装 Unity 6 LTS + .NET SDK，使 `dotnet test`（Core 零 UnityEngine 依赖）可在本机跑通，作为 M0–M4 的本地门禁；② GitHub/PAT 就绪后**立即立 GameCI `unity-ci.yml` 骨架**（仅 Android，activate→test→build），让 fail=red 门禁从 day 1 生效（吸取 S3-C3 教训）；③ 远程备份（push 到 `potential-eureka` 或新仓）在 PAT 就绪后进行。

### 沙箱能做 / 不能做
| 能做 | 不能做 |
|---|---|
| 文本编写 C# 源文件 / `.asmdef` / UXML / USS | 编译 C#、运行 `dotnet test`、打开 Unity Editor |
| 编写 / 修订架构与计划文档（本文档集） | 生成 `ProjectVersion.txt` 等 Unity 元数据、跑 UTF、构建 APK、真机核验 |
| 梳理删除/保留/新建清单（见 M0 重基线清单） | 实际执行文件删除 / Unity 工程初始化（须用户本机） |

---

【一句话总结】端口计划分 M0–M5 六里程碑，每阶段带可量化退出准则；**M0 重基线清单（删 Godot 耦合 / 留引擎无关 / 建 Unity 结构）+ CI 骨架暂挂（决策5）、M1 数据零改动验证、M2 强守解耦红线（headless 闭环 + 架构测试）、M3 双端战斗 UI（仅 Android 分发）、M4 测试+CI 全绿（仅 Android，⏸ 暂挂待 PAT）、M5 perf/仅 Android 真机/文档收口**；总 ≈90 SP / 12–18 周单人，关键成败在 M2 红线与 M4 CI（均受 R6 环境阻塞影响，须用户本机具备 Unity+dotnet 并尽早取 PAT 立 CI 骨架，详见 Sandbox Limitation）。
