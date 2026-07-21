# S4 候选冲刺计划（草案 · 不执行）

> **编制**：design-strategist（文策渊）｜**性质**：候选计划草案，**不执行、不改任何代码/数据/资产/其它文件**，供主理人 / 用户审阅拍板
> **阶段**：Phase 5 制作 · Sprint S4（S3 之后下一个推进阶段）
> **项目**：仙侠卡牌 / Xianxia Card Battler（Godot 4.x 2D-first；PC 横屏 ≥1024px + 移动竖屏 <768px）
> **仓库根**：`F:\AI\仙侠卡牌项目`（分支 `main`，本地 10 commit，未推送远程）
> **建议版本线**：S1→`v0.1.0`、S2→`v0.2.0`、S3→`v0.3.0`(CONDITIONAL PASS)；S4 建议 `v0.4.0`

---

## 0. 依据文档（已全部 Read 确认，不臆造）

| 文档 | 用途 |
|---|---|
| `production/s3-status-2026-07-20.md` | S3 7 story 收口、10 commit、Python 镜像全 PASS、剩余 2 项环境阻塞 |
| `production/qa/s3-final-qa-gate.md` | S3 门禁结论 **CONDITIONAL PASS** + 4 项环境阻塞明细（含 S3-C3 / 美术终审） |
| `production/qa/s3-perf-plan.md` | S3-Perf 指标（包体<300MB / PC≥60 / 移动30–60 / performance_mode）与真机计划 |
| `production/qa/s3-dualend-plan.md` | S3-DualEnd 双端验证矩阵（旋转/焦点/热区≥95%/灰阶可辨） |
| `production/release/s3-release-checklist.md` | 工作区脏点 / v0.3.0 建议 / 4 项待拍板（含美术升档、B-3 qi 取舍） |
| `production/release/s3-changelog.md` | S3 按 story 交付汇总 + 已知限制 L1–L6（参考级美术/Perf/DualEnd/CI/qi） |
| `production/epics/s3-epics-stories.md` | S3 Epic/Story 拆分风格与 DoD 12 项（本文件 §3 沿用其格式） |
| `production/design-review/s3-design-review.md` | B-1/B-2/B-3 机制定稿（S3 设计红线，S4 新系统须对齐） |
| `art/s3-art-visual-review.md` | 25 张参考资产结构验收 25/25；灰阶/热区/锚点待人工终审 |
| `data/battle/chapters.json` | **已存在**：3 章 ×（8 普通 + 1 Boss）= 27 关 PvE 数据（敌人 element/stats、reward 含 fu_lu/po_dan/jue_xing_shi） |
| `data/shikigami/shikigami_defs.json` / `bond_combos.json` / `gacha_pools.json` / `cultivation_config.json` / `economy_config.json` | 13 式神 / 5 羁绊组 / 抽卡概率与保底 / 养成曲线 / 5 货币 现状确权 |

---

## 1. S3 基线小结

S3 已完成「Demo 串接 + 可访问性桥接 + 双端验证 + 式神 8→13」七个 story，**逻辑层 / 数据层 / 解耦红线 / 美术结构层全部经 Python 镜像 + 静态 grep 验证 PASS**（asset-data 7/7、ui-battle 49/49、art 25/25、b1_b3 48/48、c4 15/15、e6 22/22、e5 42/42），门禁结论为 **CONDITIONAL PASS**；剩余 4 项缺口**均为环境阻塞（非机制损坏）**，待真机 / CI / 人工终审补齐（详见 `s3-final-qa-gate.md` §2）：

| # | 环境阻塞项 | 阻塞原因（沙箱无） | 闭合路径 |
|---|---|---|---|
| ① | **S3-Perf** | 包体<300MB / PC≥60fps / 移动30–60fps / performance_mode 降级 | Godot Profiler + 真机帧率采样（`s3-perf-plan.md`） |
| ② | **S3-DualEnd** | 双端跑通 / 旋转不崩 / 焦点不丢 / 热区≥95% / 灰阶可辨 | Godot 运行时 + 双端真机 / 模拟器（`s3-dualend-plan.md`） |
| ③ | **S3-C3（GUT 全量 CI 绿）** | CI 门禁尚未实跑（验证真空） | PAT 到位 + 推送触发 GitHub Actions（`-gexit`） |
| ④ | **美术视觉终审（art-director）** | 灰阶可辨 / 双端热区 / 锚点 5 形状语言一致性需人眼 | art-director 对 25 张资产终审签字（`s3-art-visual-review.md`） |

> 注：①–④ 在物理上不属 S4「新功能」范畴，但**不闭合则 `v0.3.0` 无法晋级 GA**；故本草案将①–④收口列为 S4 必做并行专项（见 §3 Epic S4-E），标 **BLOCKED-EXT**。

---

## 2. S4 推荐聚焦（默认方案）

### 2.1 五方向速览与依赖判定

| 方向 | 内容 | 价值 | 是否新系统 | 外部依赖 |
|---|---|---|---|---|
| **A. 抽卡完整体验 + 首屏/主菜单/图鉴 UX** | gacha 动画 / 十连 / 保底 UI + 主菜单多栏单列 + 13 式神图鉴完整体验 | 让核心飞轮在 **UI 层真正可玩可看**（S3 仅逻辑层） | 否（数据/逻辑已存在：`gacha_pools.json` 概率与 soft/hard_pity、free_ten_pull=10；图鉴引用 13 式神） | 仅最终双端观感核验 |
| **B. 剧情/关卡 PvE 纵向内容** | 首章关卡地图 UI + 首领 Boss 实战化 + 五行克制实战化 | 把 `chapters.json` 现有 27 关数据变成**可玩内容**；补体验纵深 | 部分（叙事 beats 为**候选新数据**；关卡/Boss 编排已存在） | 仅最终双端观感核验 |
| **C. 式神养成深化** | 觉醒广度 / 羁绊深度 / **装备或符文系统** | 拉长养成线、提升留存 | 觉醒·分支·羁绊 config **已存在**；**装备/符文 = 全新候选系统** | 装备/符文需 design 先定稿（BLOCKED-DESIGN） |
| **D. 美术生产级升档** | 参考图→生产级 2048×3072(PC)/1024×1536(移动) + VRAM 压缩 + 九切片 UI 资产 | 视觉从「方向性参考」晋级生产级 | 否（资产重出，命名不变覆盖） | art-director 重出 + 人眼终审（**BLOCKED-EXT**） |
| **E. 真机验收专项** | Perf/DualEnd 实跑 + GUT CI + 美术终审 + 灰阶/热区/焦点回归 | 闭合 S3 四项环境阻塞，解锁 GA | 否（验收回填） | 真机 / PAT+远程 / 人眼（**BLOCKED-EXT**） |

### 2.2 推荐组合与理由

**默认方案（推荐）：`A（P0）＋ B（P0）＋ E（P0，并行收口）`，`D（P1，美术并行轨，BLOCKED-EXT）`，`C（P2，候选）`。**

- **A 为第一优先（最高杠杆、最低外部阻塞）**：S3 核心闭环只在 headless 逻辑层跑通，玩家在 UI 层仍「看不见、玩不到」抽卡演出、主菜单流与图鉴。A 把已就绪的 gacha / 13 式神数据接上演出与 UX，是让 `v0.3.0` 从「可跑」变「可展示」的关键一步；且 A 几乎不依赖真机（仅末段双端观感），可独立推进。
- **B 紧随（已有数据底座，风险可控）**：`data/battle/chapters.json` **已含 3 章 27 关**的敌人 element/stats 与 reward，S4 主要是**体验层**（章节地图 UI、选关、首章叙事 beats、Boss 实战化 UX、五行克制在 PvE 中可见反馈），不是从零搭系统。注意：**S4 不应改 `chapters.json` 数值平衡**，仅做体验承载与难度核对（改平衡需 design 定稿）。
- **E 必做（不闭合则无 GA）**：①–④ 是 S3 的尾巴，必须在本阶段配 owner 与窗口驱动到 CLOSED；属 BLOCKED-EXT，需在拍板项里落实真机/ PAT/ art 终审排期。
- **D 并行（非阻断）**：参考级美术已结构过审；升档是视觉晋级而非功能阻塞。建议作为**独立美术轨**与 A/B 并行，不抢功能排期；纯 BLOCKED-EXT，进度取决于 art-director 人力。
- **C 后置为候选**：觉醒 / 分支 / 羁绊 config 已存在（仅 5/13 式神有觉醒技）；真正的**新系统「装备/符文」风险高**（牵动 base_stats、被动、经济掉落），必须先由 design-strategist 出 GDD 定稿再过架构评审，故标 **待定/候选**，不进 S4 主线，仅做「觉醒广度（数据层）」这一低风险的 P2 动作。

> **设计红线提醒（沿用 S3）**：所有新系统须守住——① UI 脚本零 `preload`/`import` 管理器（仅经 EventBus / GameState / ConfigLoader / GUI autoload）；② `BattleManager` 对 `BondManager` 引用为 0（由 `BattleLauncher` 在 `start_battle` 后发射）；③ 防双 dip 主导策略（R5）：连携 `bond_bonus` 仅缩放直接打击、不缩放 DoT；④ hex 色值仅写在 `UIThemeController` 常量区。任何新系统（装备/符文、叙事数据）须先过设计评审与架构评审。

### 2.3 默认方案范围分层（MVP / 目标 / 愿景）

| 分层 | 范围 | 退出判据 |
|---|---|---|
| **MVP（必交付）** | A1 抽卡演出十连 + 保底 UI；A2 主菜单双端流；A3 图鉴 13 全量；B1 章节地图+选关；E1–E4 四项环境阻塞收口 | 核心飞轮在 UI 层双端可玩；S3 四项阻塞全 CLOSED |
| **目标（建议交付）** | B2 首章叙事 beats；B3 首领 Boss 实战化 + 五行克制反馈闭环；D1 立绘生产级升档 | PvE 首章可玩通关；生产级立绘就位 |
| **愿景（可选）** | C1 觉醒广度（其余 8 式神补觉醒技）；D2 九切片 UI 资产；C2/C3 羁绊深度 / 装备符文（候选） | 养成线拉长；美术全生产级；装备/符文 design 定稿 |

---

## 3. S4 候选 Epic / Story 骨架

> 优先级沿用 S3 约定：**P0 = 门禁/必做**；**P1 = Demo 核心/重要非阻塞**；**P2 = 增强/候选**。
> 标 **BLOCKED-EXT** = 依赖真机/CI/PAT/人眼等外部资源；标 **候选** = 用户未定的新系统，需 design 先定稿。

### Epic S4-A · 抽卡与首屏体验完整体验（Gacha & Shell UX）— P0

| Story | 优先级 | 关键依赖 | 建议 AC 要点 |
|---|---|---|---|
| **S4-A1 抽卡演出完整化（单抽/十连 + 保底 UI）** | P0 | `gacha_pools.json`（soft_pity=50/hard_pity=90/free_ten_pull=10 已就绪）、UIThemeController、MotionScale | AC1：单抽 / 十连演出（按 rarity 分级揭晓）；`reduce_motion` 时降级为静态等效揭晓（复用 MotionScale=0 路径）。AC2：保底进度 UI 显示 soft/hard_pity 计数（取自 `GameState` 抽卡计数，pity 不跨池）。AC3：新获得式神 → 弹窗 → 入图鉴 / 编队引导入口；十连结果含至少展示稀有度三重冗余（框色+纹+字）。AC4：双端热区 ≥44×44；移动单列布局不破版。 |
| **S4-A2 首屏 / 主菜单 UX 流（响应式）** | P0 | UIThemeController `layout_mode`（≥1024 multi / 768–1024 hybrid / <768 single，S1 已落）、EventBus | AC1：主菜单 PC 多栏 / 移动单列，入口（抽卡 / 图鉴 / 养成 / 编队 / 推图）一键可达。AC2：切换断点 / 旋转不崩、焦点链完整（`has_focus()` 不丢、回退同语义节点）。AC3：首屏展示资源概览（5 货币：fu_lu/ling_yu/ling_qi/po_dan/jue_xing_shi）经 `economy:currency_changed` 实时刷新。 |
| **S4-A3 图鉴 UX 完整体验（13 式神）** | P0 | 13 式神数据（`shikigami_defs.json`）、5 羁绊组（`bond_combos.json`）、4 状态图标、美术终审(④) | AC1：图鉴全量展示 13 式神（含 4 新立绘 sr_zhu_que/ssr_zhu_que/r_qiu_long/r_hu_wei/n_huo_ling），立绘/头像/技能/羁绊/养成态（突破/觉醒/分支 剑修·体修）齐备。AC2：五行（metal/wood/earth/water/fire）+ 羁绊 + 技能三重展示，数值 tabular。AC3：灰阶下五行形状（圆/三角/方/菱/五边）可辨（依赖④美术终审）。 |

### Epic S4-B · PvE 纵向内容体验化（Chapter Content Experience）— P0

| Story | 优先级 | 关键依赖 | 建议 AC 要点 |
|---|---|---|---|
| **S4-B1 章节 / 关卡地图 UI + 选关** | P0 | `chapters.json`（3 章 27 关已存在）、GameState 进度持久化 | AC1：章节地图双端 UI（PC 多栏 / 移动单列），消费 `chapters.json` 渲染 3 章、每章 8 普通 + 1 Boss（Boss 标记）。AC2：选关进入战斗（复用 S3 战斗编排）；已通关 / 首通奖励状态持久化（`GameState` + SaveManager）。AC3：关卡 reward（fu_lu/po_dan/jue_xing_shi）经 `EconomyManager` 回流，与 S3 资源断流引导（R1）联动。 |
| **S4-B2 首章叙事 / 世界观承载** | P0 | 叙事 beats **候选新数据**（需 design 定稿）、text_scale 适配 | AC1：首章（ch1）关卡 / 首领 轻量对白或条目文案（世界观钩子），可选跳过。AC2：`text_scale(1.0–1.3)` 适配、高对比可读（Basic A ≥4.5:1）。AC3：叙事数据独立表（如 `data/story/`，**候选结构**），不侵入 `chapters.json` 数值。⚠️ 叙事结构为**待定/候选**，须 design 定稿后方可落地。 |
| **S4-B3 首领 Boss 实战化 + 五行克制反馈闭环** | P0 | S3-B1 StatusManager、element_matrix、S3-UI-Battle 三重标识 | AC1：Boss 关（首领+护卫双单位，如 `c1_boss`+`c1_boss_add`）编排进入战斗。AC2：PvE 中五行克制可见反馈（克制三重标识 图标+数字+颜色 已具备），选克制 element 技能伤害更高可感知。AC3：仅核对 `chapters.json` 难度曲线（杂兵 hp 126→168 / Boss 480→800），**不改数值平衡**；如确需调参，回到 design 定稿。 |

### Epic S4-E · S3 环境阻塞收口专项（真机验收）— P0 · BLOCKED-EXT

| Story | 优先级 | 关键依赖（外部） | 建议 AC 要点 |
|---|---|---|---|
| **S4-E1 S3-Perf 真机验收回填** | P0 | Godot Profiler + 真机（**BLOCKED-EXT**） | AC1：包体<300MB（PC .pck）/ PC≥60fps / 移动30–60fps / 内存无泄漏 / performance_mode 降级后 Basic 仍满足。AC2：按 `s3-perf-plan.md` 模板回填 `production/qa/`。 |
| **S4-E2 S3-DualEnd 双端真机验收回填** | P0 | 真机 / 模拟器（**BLOCKED-EXT**） | AC1：双端跑通 + 旋转不崩 + 焦点不丢 + 热区≥95%（移动≥44px）+ 灰阶可辨。AC2：与 `s2-vertical-slice-playtest.md` 场景 E 截图比对，回填 `s3-dualend-report.md`。 |
| **S4-E3 GUT 全量 CI 实跑 + 死字段 grep 回跑** | P0 | PAT + 远程仓库（**BLOCKED-EXT**） | AC1：推送触发 GitHub Actions `gut-ci.yml` `-gexit` 全绿（含 S3 新增用例）。AC2：死字段 grep 零命中登记（闭合 C-4）。 |
| **S4-E4 美术视觉终审签字** | P0 | art-director 人眼（**BLOCKED-EXT**） | AC1：25 张资产灰阶可辨 / 双端热区 / 锚点 5 形状语言一致性终审签名，回填 `production/qa/`。 |

### Epic S4-D · 美术生产级升档（Production Art Upgrade）— P1 · BLOCKED-EXT

| Story | 优先级 | 关键依赖（外部） | 建议 AC 要点 |
|---|---|---|---|
| **S4-D1 参考图 → 生产级重出** | P1 | art-director 重出 + 人眼终审（**BLOCKED-EXT**） | AC1：25 张资产按 `asset-spec §2.1` 升档（立绘 2048×3072(PC)/1024×1536(移动)、头像·Q版 512/256、横幅双端安全区）+ VRAM 压缩。AC2：命名不变覆盖（杜绝引用失效），`verify_s3_art.py` 复测 PASS。 |
| **S4-D2 九宫格 / 九切片 UI 资产生产化** | P1 | art-director（**BLOCKED-EXT**） | AC1：卡框 / 横幅 / 按钮九切片资产按双端安全区产出，消费 `UIThemeController` 常量区色值。AC2：双端缩放无拉伸 / 无裁切。 |

### Epic S4-C · 式神养成深化（候选，部分新系统待定）— P2

| Story | 优先级 | 关键依赖 | 建议 AC 要点 |
|---|---|---|---|
| **S4-C1 觉醒技广度扩展（数据层）** | P2 | `cultivation_config.awaken.skills_by_shikigami`（现仅 5/13 有觉醒技）、S3-B1 StatusManager | AC1：为其余 8 式神补觉醒技定义（data 层），与 StatusManager / skill_defs 兼容、确定性区间中点。⚠️ 哪些式神获觉醒技 + 觉醒技效果须 **design 定稿**（候选）。 |
| **S4-C2 羁绊组深度（候选）** | P2 | 5 羁绊组（jian_zong/tie_bi/yu_zu/long_zu/hu_zu 已存在） | AC1：**候选**——羁绊 tier2 效果 / 跨组协同（如 剑宗+羽族）。⚠️ 候选，需 design 定稿；须防双 dip（R5）。 |
| **S4-C3 装备 / 符文系统（全新候选系统）** | P2 | **全新系统，待定** | AC1：**候选新系统**——装备槽 + 符文词条，影响 base_stats / 被动 / 经济掉落。⚠️ 必须先由 design-strategist 出 GDD 八节定稿 + 架构评审，再立项；未定稿前**不进 S4 主线**。 |

---

## 4. 阶段门（质量门）建议

沿用 S2/S3 的 SOP：**设计评审 → 架构评审 → 实现 → 双层验证（headless GUT + hands-on playtest）→ 最终 QA 门禁**。

### 4.1 进入门（Entry Gate）

| Gate | 判据 | 来源 |
|---|---|---|
| **G1 设计评审（design-strategist）** | S4 新系统（装备/符文 C3、叙事 beats B2、保底 UI 文案 A1）须先出 design-review 定稿（仿 `s3-design-review.md`），对齐 S3 设计红线（R5 双 dip 正交、解耦红线）。未定稿不得开工。 | 沿用 S2/S3 模式 |
| **G2 架构评审（engineering-lead）** | 新系统改动须过架构评审：仅经 EventBus / GameState / ConfigLoader / GUI autoload 通信，不新增跨 import；UI 零 `preload` 管理器；`BattleManager` 对 `BondManager` 引用为 0。 | `CLAUDE.md` / 01-architecture |
| **G3 环境前置核验** | S4-E 四项 BLOCKED-EXT 须明确 owner + 窗口：真机可用（①/②）、PAT+远程（③）、art-director 终审排期（④/ D）。无 owner 则 E 专项无法推进。 | `s3-final-qa-gate.md` §3 |
| **G4 数据冻结确认** | `chapters.json` / `gacha_pools.json` / `shikigami_defs.json` 现状确权，S4 改动范围（体验层 vs 改平衡）经主理人确认。 | 本章 §2.2/§3 |

### 4.2 退出门（Exit / DoD，S4 建议 10 项）

| # | 检查项 | 关联 |
|---|---|---|
| 1 | 抽卡演出（单抽/十连/保底 UI）双端可玩，reduce_motion 静态等效 | S4-A1 |
| 2 | 主菜单 / 图鉴（13 式神）双端 UX 跑通，焦点链完整 | S4-A2/A3 |
| 3 | PvE 首章可玩：地图→选关→战斗→结算→回流 闭环 | S4-B1/B3 |
| 4 | 首领 Boss 实战化 + 五行克制反馈可见（不改数值平衡） | S4-B3 |
| 5 | GUT 全量 CI 绿（继承 S3-C3，含 S4 新增用例） | S4-E3 |
| 6 | S3-Perf 真机验收 PASS，回填 `production/qa/` | S4-E1 / ① |
| 7 | S3-DualEnd 双端真机 PASS，回填报告 | S4-E2 / ② |
| 8 | 美术视觉终审签字（或升档 D1 后终审） | S4-E4 / ④ / D1 |
| 9 | 双层验证同时绿：headless GUT + hands-on playtest（场景 A–E 扩展至 PvE） | 沿用 S3 §9 |
| 10 | 设计红线守护：解耦 / grep 零死字段 / 双 dip 正交 0 违规 | G1/G2 |

### 4.3 验证模型与红线

- **双层验证**（沿用 S3）：headless GUT 全量 + hands-on playtest（场景 A–E 扩展含 PvE 首章）× 6 维度，须**同时 PASS**；任一核心崩溃 / 数值错误 = FAIL 回 eng。
- **设计红线**：UI 零跨引 manager、BattleManager 零 BondManager 引用、hex 仅 UIThemeController 常量、`bond_bonus` 仅缩放直接打击（防 R5 双 dip 主导策略）。新系统违规即标注。

---

## 5. 待用户拍板项

| # | 决策点 | 选项（请选其一 / 组合） |
|---|---|---|
| **① S4 主线选择** | S4 重心落在哪条 / 哪些？ | **(推荐) A+B+E**（抽卡/首屏/图鉴 UX + PvE 首章体验 + 四项环境阻塞收口）；或「仅 A」「仅 B」「A+B+C」「A+B+D+E」「其它组合」。 |
| **② 美术升档 D 是否纳入 S4** | 生产级升档（D1/D2）排期？ | **(推荐) 独立美术轨并行**（不抢功能排期，BLOCKED-EXT）；或「并入 S4 主线 P0」「延后至 S5」。 |
| **③ 养成深化 C 立项范围** | 「装备/符文」新系统是否立项？ | **(推荐) 仅做 C1 觉醒广度（数据层低风险）+ C2/C3 留作候选 spike**；或「C3 装备/符文正式立项（先 design 定稿）」「C 整体延后 S5」。 |
| **④ S3 四项环境阻塞推进排期** | ①–④ 的 owner 与窗口（决定 E 能否在 S4 关闭） | 需明确：真机由谁提供 / 何时（①/②）；PAT + 远程仓库何时到位（③）；art-director 终审何时做（④）。**(推荐) 在 S4 第 1 周锁定 owner + 窗口，否则 E 专项顺延。 |

---

## 6. 风险与缓解（设计视角）

| 风险 | 影响 | 缓解（S4 动作） |
|---|---|---|
| S3 四项阻塞不闭合 → `v0.3.0` 卡 CONDITIONAL，无 GA | 整个项目无法晋级 | S4-E 必做并行专项 + 拍板项④锁定 owner/窗口 |
| A+B 双 P0 范围过大 | 工期/质量风险 | 推荐 A 先行（最低外部阻塞），B 紧随；MVP 分层（§2.3）兜底 |
| C3 装备/符文为全新经济/战斗系统 | 经济失衡 / 双 dip 主导策略（R5） | 未 design 定稿不立项；先 spike；过 G1/G2 评审 |
| B 误改 `chapters.json` 数值平衡 | 破坏已验证难度曲线 | B 仅体验层；改平衡回 design 定稿（§3 B3 AC3） |
| D 升档与 A/B 抢 art 人力 | 美术产出瓶颈 | D 独立美术轨（拍板项②），不进功能关键路径 |
| 叙事 beats（B2）结构未定 | 数据侵入 / 返工 | 独立 `data/story/` 候选表；design 定稿前不落地 |

---

## 7. 一句话总结（主理人）

S4 默认推荐「**A 抽卡/首屏/图鉴 UX 完整体验 ＋ B PvE 首章体验化 ＋ E S3 四项环境阻塞收口**」为主轴（A/B 让核心飞轮在 UI 层真正可玩可看，E 闭合 S3 尾巴以解锁 GA），美术升档 D 作并行美术轨、养成深化 C 仅做低风险的觉醒广度、装备/符文留作候选；需主理人拍板 4 项（①主线组合 ②D 是否纳入 ③C 立项范围 ④S3 四项阻塞的 owner/窗口），其中**④最紧迫**——真机/PAT/art 终审若不在 S4 第 1 周锁定，E 专项将顺延、`v0.3.0` 无法晋级。本文件为草案，未改动任何代码/数据/资产。

---

**附：候选 Epic / Story 总表（速览）**

| Epic | 优先级 | Story 数 | 外部依赖 |
|---|---|---|---|
| S4-A 抽卡与首屏 UX | P0 | 3 | 仅末段双端观感 |
| S4-B PvE 内容体验化 | P0 | 3 | 仅末段双端观感（B2 叙事为候选数据） |
| S4-E S3 环境阻塞收口 | P0 | 4 | **BLOCKED-EXT**（真机/CI/PAT/人眼） |
| S4-D 美术生产级升档 | P1 | 2 | **BLOCKED-EXT**（art-director） |
| S4-C 养成深化（候选） | P2 | 3 | C3 装备/符文待 design 定稿 |
