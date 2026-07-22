# 仙侠卡牌 · 已锁定决策记录（Locked Decisions）

> 角色：engineering-lead（程基岩）｜ 性质：**决策冻结记录（文档，不改代码）**
> 日期：**2026-07-22**｜ 拍板人：主理人/用户 **游承峰**｜ 记录人：程基岩
> 用途：把用户拍板的 4 项关键决策（及随 ADR-4 一并锁定的决策3）正式冻结，记录对 `port-plan.md` 与 `architecture-adrs.md` 的影响，并显式登记「仅 Android 偏离 GDD 双端」的偏差与沙箱限制风险。

---

## 一、锁定决策总表

| # | 决策 | 用户拍板内容 | 映射 ADR | 状态 |
|---|---|---|---|---|
| 决策2 | Unity 版本 | **Unity 6 LTS（`6000.x`）+ 2D URP** | ADR-1 | ✅ Accepted |
| 决策5 | 托管策略 | **先留本地 + Core 程序集 `dotnet test` 推进；等 GitHub/PAT 就绪再 push；CI（GameCI）暂挂** | ADR-5 | ✅ Accepted（⏸ CI 暂挂） |
| 决策1 | UI 框架 | **UI Toolkit（UXML/USS）为主框架** | ADR-2 | ✅ Accepted |
| 决策4 | 移动端 | **仅 Android**（⚠️ 偏离 GDD「PC Steam + 移动 iOS/Android」） | ADR-1 / ADR-5 | ✅ Accepted |
| 决策3* | 测试策略 | **纯 UTF + 引擎无关 `Core` 程序集，退役 Python 镜像**（*随 ADR-4 一并锁定*） | ADR-4 | ✅ Accepted |

> *决策3 虽未列入用户「4 项关键决策」主清单，但因 `port-plan.md` 的 **M0 重基线清单**已明确调用「决策3 退役 Python 镜像」（`production/qa/s3_*.py` 删除），故一并冻结记录，避免 M0 执行时依据缺失。

---

## 二、对 `port-plan.md` 的影响

| 受影响处 | 原表述 | 冻结后 |
|---|---|---|
| 里程碑总览 M0 | CI 骨架 | CI 骨架（⏸ 暂挂，决策5） |
| 里程碑总览 M4 | 21 GUT→UTF + GameCI 全绿 | 仅 Android，⏸ 暂挂待 PAT |
| 里程碑总览 M5 | 双端真机 | 仅 Android 真机 |
| **M0 重基线清单（新增章节）** | — | 删除 Godot 耦合（28 `.gd` / 1 `.tscn` / 21 `.gd` / `project.godot` / `.godot/` / `gut-ci.yml` / `CLAUDE.md` Godot 引用 / 6 个 `s3_*.py`）；保留引擎无关；新建 Unity 结构（`Assets/` `Packages/` `ProjectSettings/` / `.gitignore` / `Core/`） |
| M0 详解 | 立空 `unity-ci.yml` | `unity-ci.yml` 暂挂（决策5），以本地 `dotnet test` 托底 |
| M4 | build PC + Android；iOS 单独 macOS job | build **仅 Android**（Linux/Win runner）；iOS job 删除（决策4）；CI 推迟到 GitHub/PAT 可用 |
| M5 | 双端真机核验 | **仅 Android 设备**真机核验；iOS 取消（决策4） |
| **Sandbox Limitation（新增章节）** | — | 无 dotnet / 无 Unity；C# 可编写不可验证；与 S3-C3 同类风险 |

---

## 三、对 `architecture-adrs.md` 的影响

| ADR | 原 Status | 冻结后 | 关键变更 |
|---|---|---|---|
| ADR-1 | Proposed | **Accepted** | 移动端仅 Android（去 iOS 表述：Context 改写 + iOS IL2CPP 后果改为 Android IL2CPP/AOT） |
| ADR-2 | Proposed | **Accepted** | UI Toolkit 主框架锁定 |
| ADR-3 | Proposed（硬要求） | **Accepted** | 解耦红线原样保留 |
| ADR-4 | Proposed | **Accepted** | 纯 UTF + Core，退役 Python 镜像；`s3_*.py` 由 M0 删除 |
| ADR-5 | Proposed | **Accepted（⏸ 暂挂）** | CI 因 GitHub 阻塞暂挂；仅 Android build（删 iOS job）；新增「CI 暂挂说明」callout |

- 顶部新增 **🔒 Locked Decisions（2026-07-22 用户拍板）** 摘要（5 决策 → 映射 ADR → 影响），并附「仅 Android 偏离 GDD」偏差警示与决策记录指针。

---

## 四、偏差说明：仅 Android 偏离 GDD 双端

- **GDD 依据**：`design/gdd/01-concept.md:5` ——「引擎：Godot 4.x（2D-first，保留 3D 演出余量）｜ 平台：PC Steam + 移动 **iOS/Android**（云存档）」。
- **拍板覆盖**：用户 2026-07-22 拍板「决策4 移动端 = 仅 Android」，**直接覆盖** GDD 的 iOS 分发目标。
- **影响范围**：
  - 代码层无额外成本（C# + UI Toolkit 双端布局共用），差异仅在**构建 / 签名与 AOT 验证**。
  - M4 CI 删 iOS macOS job；M5 真机核验取消 iOS 设备。
- **建议**：**上线前复核**是否补 iOS。若补，需：macOS runner（GitHub 计费更高）+ 证书/签名/App Store 流程 + Core 程序集 AOT 安全复核（见 ADR-5 备选与 ADR-3 R7）。此项留作上线前决策点，**不在本次 M0–M5 首发范围**。

---

## 五、沙箱限制与风险登记（⚠️ 关键）

> 已实测：`command -v dotnet` = **NO_DOTNET**；`command -v unity` = **NO_UNITY**。

### 对决策5「dotnet test」策略的影响（新暴露风险）
- 决策5 的推进路径是「先本地 + **Core 程序集 `dotnet test`** 推进，CI 暂挂」。但**沙箱无 dotnet**，因此 `dotnet test` 这条本地托底在沙箱内**同样无法执行**。
- 结论：在本沙箱环境中，M0–M4 的逻辑验证**既无 GameCI、也无 `dotnet test`**，仅能「文本编写 C# + 人工审阅」。这与 S3-C3「GUT 从未实跑」是**同一类风险**（质量门在工具链就绪前无法端到端验证，R6 最大红旗）。
- **对冲（须从第一天规划，不可等到 M4 才补）**：
  1. 用户本机装 **Unity 6 LTS + .NET SDK**，使 `dotnet test`（Core 零 `UnityEngine` 依赖）可在本机跑通，作为 M0–M4 的本地门禁；
  2. **GitHub/PAT 就绪后立即立 GameCI `unity-ci.yml` 骨架**（仅 Android，activate→test→build），让 fail=red 门禁从 day 1 生效（吸取 S3-C3 教训）；
  3. push 远端（到 `potential-eureka` 或新仓）在 PAT 就绪后进行。

### 对 M0 重基线清单的影响
- Unity 工程根（`Assets/` `Packages/` `ProjectSettings/` 等）须**用户本机 Unity Editor 打开一次**以生成 `ProjectVersion.txt` 等元数据，沙箱无法代劳；
- 文件的实际**删除 / 新建动作**也须用户本机执行（本文档仅给清单与指引，见 `port-plan.md · M0 重基线清单` 与 `Sandbox Limitation`）。

---

## 六、决策记录指针 / 关联文档

- 架构决策：`production/unity-migration/architecture-adrs.md`（5 ADR 已 Accepted，含 Locked Decisions 摘要 + ADR-5 CI 暂挂说明）
- 端口计划：`production/unity-migration/port-plan.md`（M0 重基线清单 + 各里程碑更新 + Sandbox Limitation）
- 待拍板历史：`production/unity-migration/decisions-for-user.md`（原 5 项请求，现已全部拍板/锁定）
- GDD 偏差源：`design/gdd/01-concept.md:5`
- 连续性：既有 `docs/architecture/adr/adr-001..005`（Godot 决策意图仍有效，本记录是 Unity HOW 层落地）

---

> **一句话**：2026-07-22 用户拍板 4 项决策（Unity 6 LTS / 托管暂挂 / UI Toolkit / 仅 Android）+ 决策3（退役 Python 镜像）一并冻结；架构已 Accepted、计划已重基线；须显式登记「仅 Android 偏离 GDD 双端」偏差，并从第一天对冲「沙箱无 dotnet 使决策5 的 `dotnet test` 托底也跑不了」这一关键风险。
