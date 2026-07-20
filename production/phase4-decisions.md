# Phase 4 定稿决策文档（主理人裁决）

> 阶段：Phase 4 预制作收尾 → 定稿确认
> 依据：`production/phase4-assembly.md` §4 风险表 + §5 确认清单
> 裁决人：主理人（游承峰）
> 关联状态：S1 已实装通关（s1-gate / s1-design-review PASS）；S2 已交付（s2-gate CONCERNS）；S3 规划中

---

## 1. 决策总览

| 项 | 结论 | 状态 |
|---|---|---|
| R1 资源缺口→推荐产出源 | S1 已实装 `get_recommended_source`，单测 PASS | ✅ 已闭合 |
| R3 MVP 式神数 | 13 = N3 / R4 / SR3 / SSR3，10–15 浮动 | ✅ 定稿（朱雀确认为火 SSR，放宽原 SSR2 锁） |
| R2 锚点6 定义 | 授权增补锚点6（天象裂隙 / Boss 3D 演出钩子）于 art-bible §9 | ✅ 定稿 |
| R4 免费十连文案 | 顶栏拆两格 ＋ 抽卡页内一句话 | ✅ 定稿 |
| S2 末垂直切片 Playtest | 已采纳，quality-lead 产出计划 | ✅ 已规划 |

---

## 2. 详细裁决

### R1 · 资源缺口→推荐产出源（UX §6 验收关键）
- **结论**：✅ 已闭合，无需决策补录。
- **证据**：`EconomyManager.gd:142` 的 `get_recommended_source(deficit_currency: String) -> Array[String]` 已在 S1 实装；s1-gate.md 与 s1-design-review.md 均 PASS（ling_qi→[推图,日常]；jue_xing_shi→[Boss]；未知→空）。
- **遗留**：UX 渲染引导层（接 `economy:currency_changed` 显示产出源入口）属 S3 Demo 范畴，S1 交付数据接口即满足本 Story AC1–AC3。

### R3 · MVP 式神数 / 稀有度分布
- **结论**：✅ 定稿 **13 = N3 / R4 / SR3 / SSR3**，允许在 **10–15** 浮动（朱雀确认为火 SSR，原 SSR2 锁放宽至 SSR3）。
- **依据**：`asset-spec.md §1.2` 已按此铺排；R / SR / SSR 卡框均被使用，分布健康无浪费。
- **缺口已补齐**：S3 已将 `data/shikigami/shikigami_defs.json` 从 8 张补齐至 **13 张**（N3 / R4 / SR3 / SSR3，含火 SSR 朱雀 `ssr_zhu_que`）。原定 4 张新卡（SR 朱雀 / 虬龙 / 虎威 / 火灵）+ 1 张（SSR 朱雀）共 5 张新卡。

### R2 · 锚点6 定义歧义
- **结论**：✅ 授权在 `art/art-bible.md §9` 正式增补 **锚点6 · 天象裂隙 / Boss 3D 演出钩子**。
- **语义定位**：仅作 3D 演出余量（架构 `docs/architecture/01-architecture.md §1.10`）的"出图 / 资产钩子"来源，对应御剑飞行 / 天象裂隙 / Boss 战入场三处镜头；资产由 art-director 交付，工程仅预留 `CinematicManager` + SubViewport 钩子。
- **引用校正**：架构 §1.10 第 177 行「锚点1/2/6」引用本就正确，补完 art-bible 后不再悬空，无需改架构。

### R4 · 免费十连独立额度文案
- **结论**：✅ 定稿方向——**顶栏拆两格 ＋ 抽卡页内一句话**。
  - 顶栏：左格「玩法产出符箓（fu_lu 实时）」＋ 右格独立徽标「免费十连额度 10/日」，视觉上独立计数格，避免与玩法产出混淆。
  - 抽卡屏：十连按钮下方一句话「每日免费十连额度 10 符箓，独立于玩法产出，不计入软预算」。
- **逻辑状态**：解耦已在 S1 落地（`economy_config.json` 的 `free_ten_pull.amount = 10`，pass2 修正解耦，不计入软预算），本项仅补 UI 文案层，不触碰经济逻辑。
- **落点**：已更新 `design/ux/ux-spec.md §6 note3`（原"文案待定"已定稿）。

### S2 末垂直切片 Playtest（§5 确认项 5）
- **结论**：✅ 已采纳并先行 actioned。
- **证据**：quality-lead 已产出 `production/qa/s2-vertical-slice-playtest.md`（两层验证：headless 逻辑已由 s2-python-logic-smoke 证明 / hands-on 需本地 Godot+GUT；5 个闭环入口场景 + 6 维检查表 + 量化指标）。
- **衔接**：S2 门控 CONCERNS 含 `bond:combo` 实战零 caller（B-2 阻塞项），Playtest 须重点验证连携实战是否恒为 0，决定是否 S3 补发射器。

---

## 3. 下游行动项

- [S3 资产补齐] `shikigami_defs.json` 8 → 12（N+1 / R+2 / SR+1），关联 E5 Demo 图鉴 12 立绘三视图（`asset-spec §1.2`）。
- [S3 Demo] UX 渲染「资源缺口→推荐产出源」引导（接 `economy:currency_changed`），闭合 UX §6 验收关键 UI 层。
- [S3] 锚点6 出图由 art-director 交付；工程仅需 §1.10 `CinematicManager` / SubViewport 钩子就绪。
- [S2 验证] 本地 Godot + GUT 跑 `s2-vertical-slice-playtest`，重点验证 B-2（bond:combo 实战零 caller）是否需 S3 补发射器。

---

## 4. 与 S2 门控的衔接

S2 门控 CONCERNS 的 **B-1 / B-2 / B-3 / C-3 / C-4** 已记录于 `production/s2-gate.md`，为 S3 DoD 阻塞项。本 Phase 4 定稿（R2/R3/R4 范围歧义消除 + R1 闭合）不与 S2 门控冲突，反倒为 S3（Demo 串接 + 可访问性桥接 + 双端验证 + 资产补齐）扫清范围歧义，可按计划推进。

---

【一句话总结】Phase 4 全部待确认项已定稿：R1 已在 S1 闭合、R3=12（10–15 浮动）、R2 增补锚点6、R4 定稿顶栏拆两格文案；垂直切片 Playtest 计划已就位，Phase 4 正式收口，可推进 S3。
