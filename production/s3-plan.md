# S3 冲刺计划（主理人汇编 · Phase 5 Sprint S3 收口）

> 编排：主理人（游承峰）｜ 性质：**汇编交付**，不替代任何成员专业产出
> 输入：eng-s3plan（`s3-epics-stories.md`）+ qa-s3（`qa-plan-s3.md`）+ design-s3（`s3-design-review.md`）+ 用户拍板
> 上游：S2 已交付（`s2-gate.md` CONCERNS），5 个 DoD 阻塞项 B-1/B-2/B-3/C-3/C-4 转入 S3
> 关联：Phase 4 已定稿（`phase4-decisions.md`）；S1 已通关；S2 逻辑口算 155/155 PASS

---

## 1. 一句话结论

S3 = **Demo 串接 + 可访问性桥接 + 双端验证 + 式神资产补齐**，并把 S2 门控的 **B-1/B-2/B-3/C-3/C-4 锁为 S3 DoD 红线**。三份成员文档已就位且彼此一致；用户已拍板 3 项设计决策（灼烧→火 SR 朱雀 / B-3 采纳 qi 门控 / 4 张新卡归属）。S3 可进入实现。

---

## 2. 三份来源文档（专业产出，以成员结论为准）

| 文档 | 作者 | 覆盖 |
|---|---|---|
| `production/epics/s3-epics-stories.md` | engineering-lead | Epic/Story 拆分 + DoD 12 项 + 跨成员依赖矩阵 |
| `production/qa/qa-plan-s3.md` | quality-lead | 测试矩阵 + 双端/性能门 + C-3 CI 硬门禁 + FAIL 定义 |
| `production/design-review/s3-design-review.md` | design-strategist | B-1/B-2/B-3 机制定稿（PASS）+ 式神 8→12 归属 |

---

## 3. S3 范围（锁定）

| 模块 | Story | 优先级 | 关键依赖 |
|---|---|---|---|
| E5 Demo 串接 | E5-S1 核心闭环 / E5-S2 云桩复核 / E5-S3 埋点贯通 / E5-S4 双端旋转 / E5-S5 资源断流引导(R1 收口) | P0/P1 | S2 各信号已落 |
| E6-S5 可访问性桥接 | AccessibilitySettings 单例 + accessibility_changed | P0 | UIThemeController(S1) |
| E6-S6 MotionScale + CVD | 动效总线 + CVD 后处理 shader | P0 | E6-S5 |
| S3-B1 觉醒改写 | 灼烧叠层 + StatusManager + skill_defs 数据化 | P0 | design-s3 §2.5 已定稿 |
| S3-B2 羁绊实战发射 | start_battle 后 compute_combo 发射 | P0 | design-s3 §3.4 已定稿 |
| S3-B3 玩家选技 | step() 接收技能/目标 + qi 门控 | P0 | design-s3 §4.5 已定稿 |
| S3-Asset-Data | 式神 8→12 数据 | P1(eng 先行) | design-s3 §5.3 已定稿 |
| S3-Asset-Art | 立绘/VFX 交付 | P1(阻塞视觉验收) | art-director 待交付 |
| S3-UI-Battle | 双端战斗 UI 落地(E4-S6) | P0 | art VFX/横幅/气槽 |
| S3-DualEnd | 双端验证 | P0 | E5-S4 + S3-UI-Battle |
| S3-C3 | GUT 全量 CI 绿 | P0 | 装 Godot 4.3+GUT |
| S3-C4 | 文件级 cache 回滚 + 死字段 | P0 | CloudSaveService/SaveManager |
| S3-Perf | 性能预算达标 | P0 | 全量资源就位 |

---

## 4. S2 门控 → S3 DoD 红线（核心）

| 阻塞项 | 转 S3 Story | 验收（必须绿） | 不收敛后果 |
|---|---|---|---|
| **B-1** 觉醒改写(灼烧叠层)未实现 | S3-B1 | GUT `test_status_burn` 全绿；与连携不双 dip（bond 仅缩放直接打击） | HARD → FAIL |
| **B-2** 连携实战恒 0 | S3-B2 | 真实流 start_battle 后 compute_combo 发射 → `_bond_bonus > 0`；grep 零 `preload BondManager` | HARD → FAIL |
| **B-3** 玩家选技缺失 | S3-B3 | step() 接收技能/目标；power 数据化；GUT 选技用例全绿 | SOFT → 仅默认技可跑则 CONCERNS |
| **C-3** GUT 未实跑 | S3-C3 | Godot+GUT 全量进 CI，`-gexit` 非零阻断合并 | HARD → 未进 CI 一律 FAIL |
| **C-4** cache 回滚缺口 | S3-C4 | `test_cache_rollback`：正式档损坏回退磁盘上一可用版本；grep 零死字段 | HARD(机制失效) / SOFT(仅测试缺口) |

> **C-3 铁律（qa-s3 判定）**：GUT 全量必须进 CI 实跑，CI 无 GUT/godot 即红灯，不允许仅本地口头通过。S2 CONCERNS 未在 S3 收敛则整体 FAIL。

---

## 5. 用户拍板的设计决策（已采纳 · 全部采纳定稿）

1. **灼烧归属火系 SR「朱雀」** — 概念文档原举例「火系 SSR 觉醒灼烧」不可行（R3 锁 SSR2=青龙/白虎均金行），改挂火 SR 朱雀，保持 R3 完整交付机制。
2. **B-3 采纳 `qi` 气资源门控** — 每单位 qi_max=3、回合+1、觉醒技耗1；工时紧可降级为无消耗/回合冷却（须显式记录降级）。
3. **4 张新卡归属批准** — 朱雀(SR/火/yu_zu)、虬龙(R/水/long_zu)、虎威(R/金/hu_zu)、火灵(N/火/—)；补玩家侧火行，解决「8 张无火行→灼烧无归属」隐藏缺口。

---

## 6. 跨成员依赖与未决前置

- **art-director 待交付（S3 阻塞视觉验收，不阻塞 eng 数据/逻辑）**：
  - A1：4 张新立绘三视图（朱雀/虬龙/虎威/火灵）+ 图鉴 12 引用
  - A2：状态 VFX（灼烧/破甲/中毒/气势，形状+图标+数字三重，不靠色）
  - A3：连携横幅（锚点5 五行符文阵）
  - A4：火行形状/配色 + 气槽 UI 控件（tabular、≥44px）
  - A5：锚点6 出图（天象裂隙/Boss 3D，非阻塞，长线）
- **eng 数据层（S3-Asset-Data）可独立先行**；视觉验收排期对齐 art-director。

---

## 7. 推荐执行顺序（编排建议）

P0 门禁优先，避免返工：

1. **S3-C3 装 Godot+GUT+CI**（第一要务：否则全量回归无门禁，C-3 红线不收敛）
2. **S3-B1 + S3-B3 同批改 `step()` + `skill_defs.json`**（设计注：二者共用改造路径，务必同批次，避免两次改动）
3. **S3-B2 连携实战发射**（战斗场景 start_battle 后 compute_combo）
4. **S3-C4 文件级 cache 回滚 + 死字段清理**
5. **E6-S5 / E6-S6 可访问性桥接**（闭合 Phase 3 CONCERN）
6. **E5-S1/S3/S4/S5 Demo 串接 + 埋点贯通 + 旋转稳定 + R1 收口**
7. **S3-Asset-Data 式神 8→12**（eng 先行，不依赖 art）
8. **S3-UI-Battle + S3-DualEnd 双端验证**（依赖 art A2–A4 交付）
9. **S3-Asset-Art 立绘/VFX**（art-director，排期对齐）
10. **S3-Perf 性能预算**（包体<300MB / PC60·移动30-60fps）

**收口判据**：GUT 全量（headless）+ vertical-slice 手感（`s2-vertical-slice-playtest.md` 场景 A–E × 6 维度）**双层验证同时绿**，且 5 个转入阻塞项全部闭环。

---

## 8. S3 DoD 12 项（引用 `s3-epics-stories.md §9`）

| # | 检查项 |
|---|---|
| 1 | 核心闭环双端跑通（PC 横屏 + 移动竖屏），旋转/分辨率切换稳定、焦点不丢 |
| 2 | 可访问性 CONCERN 闭合：AccessibilitySettings + accessibility_changed + MotionScale + CVD 单测全绿；Basic 全项达成 |
| 3 | 埋点贯通抽→养→战→回流（session 可串联、转化率可读） |
| 4 | 性能预算内（包体<300MB / PC60·移动30-60fps） |
| 5 | GUT 全量 CI 绿（含 S3 新增用例） |
| 6 | B-1 觉醒改写落地（灼烧叠层+状态系统，与连携不双 dip） |
| 7 | B-2 连携实战发射（实战 `_bond_bonus>0`，零跨 import） |
| 8 | B-3 玩家选技（step() 接收技能/目标，power 数据化） |
| 9 | C-4 文件级 cache 回滚 + 死字段清理 |
| 10 | 式神资产补齐 8→12（数据 eng 完成；立绘 art 交付） |
| 11 | 资源断流引导收口（R1 UX 闭环） |
| 12 | 控制清单末项（可访问性桥接）勾选 |

---

## 9. 已知风险与缓解

- **B-2 连携实战恒 0**：S3-B2 战斗场景发射 + GUT 断言 >0。
- **B-1 觉醒空标签**：S3-B1 StatusManager + skill_defs + GUT test_status_burn。
- **B-3 无策略表达**：S3-B3 step() 接收技能/目标 + power 数据化。
- **C-3 无门禁**：S3-C3 装 GUT + CI 阻断。
- **C-4 边界健壮性**：S3-C4 文件级回滚 + grep 死字段。
- **双 dip 主导策略（R5）**：S3-B1 AC5 正交——bond_bonus 仅缩放直接打击。
- **art 立绘/VFX 迟到**：S3-Asset-Data 先行；视觉验收排期对齐 art-director。
- **E4-S6 仅数据**：S3-UI-Battle + S3-DualEnd 真机核验。

---

## 10. 下一步（等你定）

- **调度 art-director 出 A1–A4**（立绘/状态 VFX/横幅/气槽）——阻塞视觉验收，不阻塞 eng 数据/逻辑。
- **你本地装 Godot+GUT 跑 S3-C3**，先把 CI 门禁立起来。
- 或选任一 Story（如 S3-B2 连携发射）让我展开**实现级 ADR / 控制清单**再开工。

---

【一句话总结】S3 三份成员文档齐备且一致，5 个 S2 阻塞项已锁为 S3 DoD 红线，用户已拍板 3 项设计决策；按 §7 顺序推进即可进入实现，首务是 S3-C3 把 GUT 全量立进 CI。
