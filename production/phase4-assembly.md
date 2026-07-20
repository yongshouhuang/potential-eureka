# 仙侠卡牌 · Phase 4 预制作收尾汇编（主理人交付）

> 阶段：Phase 4 预制作（并行 spawn 三成员 → 主理人汇编）
> 参与：design-strategist（UX）、art-director（资产）、engineering-lead（Epic/Story + 测试策略）
> 落盘产物：`design/ux/ux-spec.md`、`art/asset-spec.md`、`production/epics/mvp-epics-stories.md`、`docs/architecture/test-strategy.md`
> 评审：solo / lean

---

## 1. 跨成员一致性检查

### 1.1 屏流 ↔ 资产清单 ↔ Epic/Story 咬合
| 核心循环节点（UX） | 资产清单落点（art） | Epic/Story 落点（eng） | 结论 |
|---|---|---|---|
| 主菜单枢纽 | 场景×1 + UI 组件库 + 顶栏 | E6-S1 断点 / E6-S2 输入 | ✅ 对齐 |
| 抽卡 Summon | 卡框 R/SR/SSR + 抽卡 VFX + 概率面板 | E2 全 5 故事 | ✅ 对齐 |
| 图鉴 Codex | 式神立绘×12(三视图) + 卡框 | （归属 B5 Demo 展示，E5） | ✅ 资产齐备 |
| 养成 Cultivate | 突破/升级 VFX + 属性条 | E3 全 5 故事 | ✅ 对齐 |
| 编队 DeckBuild | 式神池卡 + 连携横幅 VFX | E4-S1 | ✅ 对齐 |
| 战斗 Battle | 五行×5 VFX + 三重反馈图标 + 战斗背景×3 | E4 全 6 故事 | ✅ 对齐 |
| 结算 / 资源回流 | 奖励卡框 + 飘字 + 顶栏货币 | E1 经济闭环 + E4-S5 回流 | ✅ 对齐 |

- **卡框双态**：UX §5.1 要求全部 6 含卡牌屏引用 `art-bible §5` 同一套卡框（紧凑态/完整态切换，不另出两套图）；资产 §1.3 + §2.3 已给同一套 R/SR/SSR + 角星 + 9-slice 响应式方案。✅ 一致。
- **锚点4/5 复用**：UX 抽卡出货用锚点4 紫宸虹光、战斗连携用锚点5 五行符文阵、资产 §3 复用锚点5 形状语言作类别冗余编码。✅ 一致。
- **双端断点**：UX 双断点（≥1024 多栏 / <768 单列+底部 Tab）↔ 资产 §2.1 双端分辨率 ↔ E6-S1 `layout_mode` 三档。✅ 一致。

### 1.2 可访问性三级是否贯穿三者
- **UX**：逐屏标注 Basic 全项（A 对比度 / B 高对比 / C 缩放 tabular / D 三重反馈[战斗强制] / E 色盲冗余）+ Standard 主体（J/K/I/H/G），§5.2 矩阵。
- **资产**：§5 落地形状冗余烤死、44px 触控、tabular nums、`theme_high_contrast.tres`、减少动效静态等效、三重反馈三通道。
- **工程**：E6-S5 新增 `AccessibilitySettings` peer autoload + `accessibility_changed` 信号；E6-S6 `MotionScale` 总线 + CVD 后处理 shader。
- **结论**：Basic/Standard 在 UX/资产/工程三层闭环贯通；Comprehensive 仅标注为长线接口预留（焦点环/动态文本/音频可视化/性能降级），不铺 MVP。✅ 一致。

### 1.3 Phase 3 可访问性 CONCERN 闭合
- Phase 3 遗留 CONCERN：架构 §1.5 末条 + 控制清单末项（可访问性独立单例/信号/CVD/MotionScale 未显式预留）。
- engineering-lead 在 E6-S5/S6 正式化为两个 Story，明确 `AccessibilitySettings`（非并入 UIThemeController）+ `accessibility_changed` + `MotionScale` + CVD 后处理，对齐 `accessibility-spec.md §5` 契约。
- **判定：Phase 3 CONCERN 已闭合。** ✅

### 1.4 一致性检查小结
三份 Phase 4 交付物彼此咬合良好，无逻辑冲突。art-director T4 报告的 `accessibility-spec.md` / `references/INDEX.md` / `01-architecture.md` "缺失" 经主理人 `ls` 核验为**沙箱路径隔离假阳性**（磁盘均存在）。唯一实质缺口见 §4 风险 R1。

---

## 2. Phase 4 质量门

| 门控项 | 判定 | 说明 |
|---|---|---|
| 概念→系统→技术→预制作链路完整 | ✅ PASS | P1 概念 / P2 系统 GDD / P3 架构 / P4 三件套齐全 |
| 三件套内容咬合 | ✅ PASS | §1.1 屏流↔资产↔Epic 全对齐 |
| 可访问性贯穿 | ✅ PASS | Basic/Standard 三层闭环，Comprehensive 留接口 |
| Phase 3 CONCERN | ✅ CLOSED | E6-S5/S6 闭合 |
| 测试策略就位 | ✅ PASS | T1–T7 + ConfigLoader 假表 + CI 门禁 |
| 资源断流引导（UX 验收关键） | ⚠️ CONCERN | E1 缺"资源缺口→推荐产出源"Story（R1） |

**Phase 4 质量门总判定：PASS（全部 CONCERN 已闭合，见 `production/phase4-decisions.md`）**

> CONCERN 处置：R1（E1-S6）已在 **S1 实装并通关单测**（s1-gate / s1-design-review 均 PASS，`get_recommended_source` 落地），Phase 4 唯一 CONCERN 已闭合；UX 渲染引导层（接 `economy:currency_changed`）留 S3 Demo 收口。R2/R3/R4 经 Phase 4 定稿确认，无遗留阻塞（见 `production/phase4-decisions.md`）。

---

## 3. 首个冲刺计划（Phase 5 制作 · S1/S2/S3）

> 实现顺序严格自底向上：E1→E2→E3→E4→E5；A5 底座（E6-S1/2/3）前置 S1，可访问性桥接（E6-S5/6）收口 S3。

### S1 · 经济 + 抽卡 + 存档骨架（自底向上前两段 + A5 底座）
- **范围**：E1 全 5 故事 + **E1-S6（建议补入，见 R1）** + E2 全 5 故事 + E6-S1（断点框架）+ E6-S2（输入抽象）+ E6-S3（schema 本地读写）。
- **验证驱动**：T1 经济闭环 + T4 抽卡保底 + T3 存档读写，先写测试再实现。
- **DoD**：经济单测通过（产出/消耗/日周预算/免费十连解耦）；抽卡保底单测通过（50 软/90 硬/不跨池/新手半价）；本地存档读写+checksum+损坏回滚单测通过；断点框架+输入抽象就位三断点不破版。

### S2 · 养成 + 构筑战斗（玩法中枢）
- **范围**：E3 全 5 故事 + E4 全 6 故事 + E6-S4（云冲突 last-write）。
- **验证驱动**：T2 五行克制 + T6 羁绊连携 + T7 养成最终式神 + T3 冲突解决。
- **DoD**：养成最终式神接口单测通过（E3-S5 ↔ E4 读取一致）；五行克制结算单测通过；羁绊连携经 `bond:combo` 事件（无跨 import）单测通过；推图回流闭环跑通单场 2–4min；云存档冲突 last-write + cache 回滚 + delta<50KB 单测通过。

### S3 · Demo 串接 + 可访问性桥接 + 双端验证（收口）
- **范围**：E5 全 4 故事 + E6-S5（AccessibilitySettings）+ E6-S6（MotionScale + CVD）+ 双端验证。
- **验证驱动**：T5 可访问性单例 + T3 冲突 + 全量回归。
- **DoD**：核心闭环双端跑通（PC 横屏+移动竖屏）旋转/分辨率切换稳定焦点不丢；**可访问性 CONCERN 闭合**：`AccessibilitySettings`+`accessibility_changed`+`MotionScale`+CVD 单测全绿，Basic 全项达成；埋点日志贯通抽→养→战→回流；性能预算内（包体<300MB / PC60·移动30–60fps），GUT 全量 CI 绿。

### 垂直切片验证（可选，建议 S2 末做）
取 S1+S2 的"抽 1 → 养 1 → 编队 → 首关战 → 回流"最小路径，做一次手感 Playtest（quality-lead 介入），验证核心循环是否"好玩"再铺满 S3。

---

## 4. 已知风险与缓解

| ID | 风险 | 等级 | 缓解 |
|---|---|---|---|
| **R1** | **E1 缺"资源缺口→推荐产出源"查询接口**（UX §6 卡点#1/#2 标 MVP 验收关键）：消耗点资源不足时若无"去哪产出"引导，核心循环断流卡死留存飞轮 | ✅ 已闭合 | S1 已实装 `EconomyManager.get_recommended_source(deficit_currency)` 并通关单测（s1-gate / s1-design-review PASS）；UX 在消耗点接 `economy:currency_changed` 渲染引导留 S3 Demo。Phase 4 定稿确认闭合 |
| **R2** | **"锚点6" 定义歧义**：架构 §1.10 引用锚点6（天象裂隙/Boss 3D 演出），但 `art-bible.md §9` 仅定义锚点1–5 | ✅ 定稿 | 授权在 `art-bible.md §9` 正式增补 **锚点6 · 天象裂隙/Boss 3D 演出钩子**（Phase 4 定稿）；架构 §1.10 第 177 行「锚点1/2/6」引用本就正确，补完 art-bible 后不再悬空 |
| **R3** | **MVP 式神数/稀有度分布待确认**：资产按 12 式神（N3/R4/SR3/SSR2）铺，可在 10–15 浮动 | ✅ 定稿 | 定稿 **12 = N3/R4/SR3/SSR2**，10–15 浮动；分布已保证 R/SR/SSR 卡框均被使用。⚠️ 当前 `shikigami_defs.json` 仅 8 个，差 4 个（N+1/R+2/SR+1）列为 **S3 资产补齐项** |
| **R4** | **免费十连独立额度文案**：pass2 修正（10 符箓/日，不计入软预算），UX §6 note3 标记"文案待定" | ✅ 定稿 | 定稿方向 **顶栏拆两格（玩法产出符箓 ＋ 免费十连额度 10/日 独立徽标）＋ 抽卡页内一句话说明**；已更新 `ux-spec.md §6 note3`，逻辑解耦已在 S1 落地 |
| **R5** | **移动端 HUD 极简验证**：<768 HUD 密度 + 五行形状冗余清晰度需真机验证 | 低 | 关联 S3 双端验证 + Standard J lint；首屏 smoke 用真机过 |

---

## 5. 待主理人 / 用户决策与确认清单

1. ✅ **R1（已闭合）**：E1-S6 已在 S1 实装（`get_recommended_source` 落地 + 单测 PASS），Phase 4 唯一 CONCERN 消除；UX 渲染引导留 S3 Demo。
2. ✅ **R3（定稿）**：MVP 式神数 = **12（N3/R4/SR3/SSR2）**，允许 10–15 浮动。当前 defs 仅 8，差 4 个列 S3 资产补齐。
3. ✅ **R2（定稿）**：授权在 `art-bible.md §9` 增补 **锚点6 · 天象裂隙/Boss 3D 演出钩子**；架构 §1.10 引用本就正确，不再悬空。
4. ✅ **R4（定稿）**：免费十连文案方向 = **顶栏拆两格 ＋ 抽卡页内一句话**（详见 `ux-spec.md §6 note3`）。
5. ✅ **垂直切片 Playtest**：已采纳，quality-lead 已产出 `production/qa/s2-vertical-slice-playtest.md`，待本地 Godot+GUT 跑通。

---

【一句话总结】Phase 4 三件套 + 测试策略全部落盘且彼此咬合；可访问性 Basic/Standard 三层闭环、Phase 3 CONCERN 已闭合；Phase 4 质量门 **PASS（R1 CONCERN 已在 S1 闭合，R2/R3/R4 定稿确认）**；首个冲刺计划 S1/S2/S3 已就绪，S2 末垂直切片手感 Playtest 计划已就位。
