# 仙侠卡牌 · 待用户拍板项（Unity 迁移）

> 角色：engineering-lead（程基岩）｜ 性质：**决策请求，不改任何代码**
> 用途：下列 5 项必须由主理人/用户拍板，才能冻结 `architecture-adrs.md` 并启动 `port-plan.md` 的 M0。
> 每项格式：**【推荐】+ 取舍 + 影响**。末附"建议优先拍板顺序"。

---

## 决策 1 · UI 框架：UI Toolkit vs UGUI

- **【推荐】UI Toolkit（UIDocument + UXML + USS）为主框架**，仅极重动画叠加允许局部 UGUI（见 `architecture-adrs.md` ADR-2）。
- **取舍**：
  - UI Toolkit：天然契合"单套 UI 描述 + 断点切换"（守 Godot `ADR-001` 单描述原则）、USS 变量切主题/高对比/CVD 顺、数据驱动卡组/图鉴更省工；但极重实时动画不如 UGUI 灵活，需学 UI Builder。
  - UGUI：更熟、动画灵活；但双端断点需手写 RectTransform 锚点变体，**违背单描述原则、维护成本翻倍**。
- **影响**：决定 M3 全部战斗 UI 的实现方式、美术协作接口（UXML/USS 交付）、可访问性落地成本。若选 UGUI，需在 M0 就改 ADR-2，M3 工作量与返工风险上升。
- **我的判断**：选 UI Toolkit 与既有"单套 UI 描述"架构意图一致，长期维护更省；学习成本一次性。

---

## 决策 2 · Unity 版本：Unity 6 LTS vs 其他

- **【推荐】Unity 6 LTS（`6000.x`）+ 2D URP**（见 ADR-1）。
- **取舍**：
  - Unity 6 LTS：LTS 支持长、2D URP 轻、UI Toolkit/Input System/Addressables 成熟、CVD 有 Render Feature 钩子；但 iOS 须 IL2CPP/AOT（构建慢），且 runtime fee 条款需在营收超阈值时复核。
  - Unity 2022 LTS：生态旧、UI Toolkit 成熟度低。
  - 非 LTS（如 6 非 LTS / 6000.x Tech stream）：不稳定，不推荐用于产品。
- **影响**：决定整个工程基线、包体/帧率上限、移动构建方式、后续所有 ADR 的落地前提。M0 即依赖此项。
- **我的判断**：Unity 6 LTS 是 2D 卡牌项目当前最稳选择；runtime fee 阈值对早期卡牌项目通常无影响，上线前再复核即可。

---

## 决策 3 · 测试策略：纯 Unity Test Framework vs 保留 Python 逻辑镜像

- **【推荐】纯 UTF + 引擎无关 `Core` 程序集**（Core 零 UnityEngine 依赖，可用 `dotnet test` 直跑），**不再维护 Python 镜像**（见 ADR-4）。
- **取舍**：
  - 纯 UTF + Core：逻辑测试可在 GameCI headless 真跑、最 AOT 安全、单一真源；但需把 Core 严格隔离零 UnityEngine 依赖（架构纪律要求）。
  - 保留 Python 镜像：多一层独立校验；但**双份维护成本**，且 Python 与 C# 逻辑易漂移、失去"单一真源"。
- **影响**：决定 M2/M4 测试实现方式、是否保留 `s3_*.py`、CI 结构。若保留 Python 镜像，M4 工作量 +20–30% 且无实质收益。
- **我的判断**：S3 的 Python 镜像是因"沙箱跑不了 Godot"的权宜；Unity 侧 Core 程序集 `dotnet test` 已是更好的"引擎无关验证"，应退役 Python 镜像。

---

## 决策 4 · 移动端构建目标：iOS + Android 双端 vs 仅 Android

- **【推荐】先 Android，iOS 作为第二阶段**（或明确双端但 iOS 单独 macOS CI job）。
- **取舍**：
  - iOS + Android 双端：覆盖最全（GDD 双端要求含 iOS）；但 iOS 需 **macOS runner（GitHub 计费更高）**、IL2CPP AOT 编译更久、证书/签名/App Store 流程更重。
  - 仅 Android：CI 用 Linux/Win runner 即可、成本低、上架快；但放弃 iOS 用户，与 GDD "移动 iOS/Android" 表述有偏差。
- **影响**：决定 M4 CI 结构（是否需 macOS job）、M5 真机核验设备、构建/签名成本、上线范围。核心代码（C# + UI Toolkit）双端共用，差异仅在构建/签名与 AOT 验证。
- **我的判断**：代码层双端无额外成本；建议先 Android 上线回收，iOS 在第二阶段补（需 macOS runner + 证书）。若坚持双端同发，请在决策中明确，我会在 M4 加 iOS job 并标注成本。

---

## 决策 5 · 是否沿用现有 `potential-eureka` 空 GitHub 仓装 Unity 项目

- **【推荐】暂不动现有 GitHub 仓；先在本地按 M0 起 Unity 工程，等 GitHub 访问恢复/决定远端策略后再推**（见 R4/R6）。
- **取舍**：
  - 沿用 `potential-eureka` 空仓：远端就绪后一键 push；但用户当前**网页打不开 GitHub、无 PAT**，CI（GameCI）无法验证、push 受阻。
  - 新建仓 / 暂留本地：规避当前访问阻塞，M0–M4 可在本地 + `dotnet test` 推进；但失去远程备份与 CI 直到访问恢复。
  - 其他 CI/托管（GitLab / Gitea / 自托管）：结构同（对齐原 `gut-ci.yml` ADAPTING 注释），仅 trigger/runner 不同。
- **影响**：决定代码托管与 CI 可用性时间线；直接关联 R6（最大红旗）——**迁移质量门在 GitHub 访问恢复前无法端到端验证**。
- **我的判断**：代码与架构可在本地 + `dotnet test` 充分推进（Core 引擎无关），**但 CI（GameCI）与远程备份必须等 GitHub/PAT 就绪**；建议把"恢复 GitHub 访问 + 取 PAT"列为最高优先的环境前置，类比 S3-C3 第一要务。

---

## 建议优先拍板顺序

| 优先级 | 决策 | 理由 |
|---|---|---|
| **P0（阻塞 M0）** | #2 Unity 版本 + #5 GitHub/托管策略 | 工程基线与 CI 可用性前提；#5 直接决定 R6 能否缓解 |
| **P0（阻塞 M3）** | #1 UI 框架 | 决定战斗 UI 实现路径，晚改返工大 |
| **P1（阻塞 M2/M4）** | #3 测试策略 | 决定 Core 隔离纪律与 CI 结构 |
| **P1（阻塞 M4/M5）** | #4 移动端目标 | 决定 CI job 与真机核验范围 |

> **一句话提醒**：决策 #2 与 #5 不拍板，M0 无法冻结、R6（跑不了 Unity/CI）无法缓解；请优先处理这两项，其余可在 M0 推进期间并行确认。
