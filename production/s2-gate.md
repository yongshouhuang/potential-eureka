# S2 质量门（Quality Gate）— 仙侠卡牌项目

- **冲刺**：S2（Phase 5 制作）
- **范围**：E3 养成 ×5 故事（S1 升级 / S2 突破 / S3 觉醒 / S4 分支 / S5 最终式神聚合）、
  E4 战斗/羁绊/推图 ×6 故事（S1 组队 / S2 五行结算 / S3 羁绊 / S4 回合流程 / S5 推图回流 / S6 双端常量）、
  E6-S4 云存档冲突收口（S1 已落契约，S2 补回归 + mock 延迟）。
- **评审强度**：solo / lean
- **门禁日期**：2026-07-20

---

## 1. 总体判定

| 维度 | 判定 | 说明 |
|------|------|------|
| 算法层（纯逻辑正确性） | **PASS ✅** | Python 移植实跑 155/155（见 §2） |
| 磁盘产物与解耦红线 | **PASS ✅** | 5 单例 + element_shape + 4 数据目录 + 7 测试；零 `preload` 跨 import（见 §3） |
| 设计评审（design-strategist） | **CONCERNS** | 设计意图忠实，但 3 项实战机制缺口须进 S3 DoD（见 §4） |
| QA 评审（quality-lead） | **CONCERNS** | 代码与测试就绪，但 GUT 未实跑 + 集成/UI 缺口（见 §5） |
| **S2 总门禁** | **CONCERNS（有条件放行）** | 算法层 solid；实战连线/UI 属 S2 headless 范围外，须写进 S3 DoD 作阻塞项 |

> **结论**：S2 的「算法正确性」已钉死（Python 155/155 + 磁盘核验 + 零 preload），可以放行进入 S3。
> 但「可玩闭环」在真实运行时仍有 3 个必须进 S3 定义-of-Done 的阻塞项（B-1 觉醒改写 / B-2 羁绊发射连线 / B-3 玩家选技）。
> 这些在 S2 启动时已声明为 headless 范围外、计划内 S3，不视为 S2 回归失败。

---

## 2. 算法层独立验证（Python 移植 · 2026-07-20）

- **脚本**：`production/qa/s2-python-logic-smoke.py`
- **结果**：**155/155 断言 PASS ✅**
- **覆盖**：
  - **T2 五行克制**：`metal→wood` ADVANTAGE、克制 ×[1.25,1.35]、被克 ×[0.7,0.8]、相生 ×[1.02,1.05]、中立 ×1.0；多 seed 均落在 band 内。
  - **T6 羁绊 + 事件解耦**：2 人 +10%（中点）/3+ +17.5%（中点）；单人/空队=0；**BattleManager 经 `bond:combo` 事件取得与 BondManager 完全相同加成，证明走事件而非 import**。
  - **T7 / E3 养成聚合**：线性 +2.5%/级、突破 +10%/阶、被动槽随阶增、等级上限随突破阶、超阶/碎片不足拦截、觉醒门槛、分支门槛；`get_final_unit` 聚合 final_stats/skills/element/bond_tags/branch，且喂给 BattleResolver 抑制一致。
  - **E4-S5 推图回流（真实 chapters.json）**：一回合跑通不崩；克制命中 emit `battle:element_advantage`；Boss 关通关推进 `progression`（stages+1 / chapters+1）并经 EconomyManager 回流符箓/丹/石（觉醒石仅 `Boss` 来源，对齐 economy boss_only）。
  - **E6-S4 云冲突**：push→pull 同档一致、云新/本地新 last-write 取胜、cache 可回滚、版本优先于 ts、delta<50KB、同步延迟 mock 200ms<2s。
  - **E4-S6 双端常量**：真实 `battle_ui_constants.json` 五行→形状映射齐全、热区 44px、形状冗余开启。
  - **真实数据文件结构一致性**：五行 ke/sheng 双射环、3 章×9 关、Boss 关奖励含觉醒石1、连携成员均存在于式神表、养成曲线区间合法、经济关键货币齐全且觉醒石 boss_only 合规（防 S1-C2 式漂移）。

> 边界：本门禁验证「算法/数值正确性」，不验证 Godot 接线/信号树/UI 场景；RNG/checksum 用统计等价替代，empirical 断言用区间/容差。不替代用户本地 Godot+GUT 全量运行。

---

## 3. 磁盘产物与解耦核验

- **新增 autoload 单例**：`CultivationManager.gd`、`BondManager.gd`、`DeckBuilder.gd`、`BattleManager.gd`、`BattleResolver.gd`（RefCounted，非 Node）。
- **新增数据**：`data/{cultivation,shikigami,battle}` 下 6 张配置表 + `scripts/utils/element_shape.gd`。
- **新增 GUT 测试**：7 个（`test_cultivation/battle_element/bond/battle_flow/deck_builder/battle_ui_constants/cloud_conflict_wrapper`）。
- **解耦红线**：grep 全仓 `preload ...Manager` → **零匹配**；`BattleManager` 仅注释提及 `BondManager`，无实际 import（事件解耦硬约束成立）。
- **EventBus**：已增补 `cultivate_*` / `battle_*` 信号；`project.godot` 已注册新单例。

---

## 4. 设计评审结论（design-strategist · CONCERNS）

文档：`production/design-review/s2-design-review.md`

- **PASS**：B3 养成全 5 故事、B4 五行网状克制倍率全对齐、E6-S4 云冲突、E4-S6 双端常量、跨 GDD 一致性（get_final_unit→战斗无漂移）、设计红线（R1–R5/支柱无漂移）。
- **CONCERNS（须进 S3 DoD 的阻塞项）**：
  - **B-1 · E3-S3 AC2 部分实现**：觉醒技能 id 已记录进最终式神，但「灼烧可叠层」等状态改写机制在 `BattleResolver` 未实现（技能 power 恒硬编码 1.0，觉醒技=标签）。属 S2 headless 范围外，推迟 S3 真实战斗层。
  - **B-2 · `bond:combo` 发射器在实战中无人调用（连携实战恒为 0）**：grep 确认 `compute_combo` 全仓零 caller，仅测试调用；`BattleManager` 监听端正确但发射责任空缺 → 真实对局羁绊加成恒为 0，GDD 的 P3 构筑策略与 P1 成队养成在实战中不兑现。需在 S3 由「允许 import BondManager 的战斗发起协调者/UI」于 `start_battle` **之后**调用 `compute_combo(deck)` 触发 emit（注意 `start_battle` 会把 `_bond_bonus` 重置为 0.0，发射须在其后）。
  - **B-3 · E4-S4「玩家选技」未落地**：回合流程用固定技能（element=角色、power=1.0），无玩家技能选择 UI。headless 范围外，S3。
- **数值确定性中点**：约定合理（养成确定、战斗变数，正合「确定性与变数张力」）；附 1 条 GDD 文档澄清建议（非阻塞）。

---

## 5. QA 评审结论（quality-lead · CONCERNS）

文档：`production/qa/qa-plan-s2.md`、`production/qa/s2-vertical-slice-playtest.md`

- **覆盖矩阵**：E3×5 / E4×6 / E6-S4 逐 AC 映射到 7 个 GUT 用例；算法层已验证项显式标注由 Python 155/155 间接验证。
- **CONCERNS（阻塞项）**：
  - **C-3（延续 S1）**：GUT 未安装，7 个测试无法在沙箱实跑 → 需用户本地 Godot+GUT 跑通 `tests/*.gd`（文档已给命令/前置清单）。
  - **C-4（延续 S1）**：文件级 cache 回滚测试缺口 + 部分死配置字段仍开。
  - **E3-S3 灼烧叠层**：对应测试预期「部分通过」，待 S3 补回。
  - **双端/UI 零验证**：E4-S6 仅常量数据，无真实 UI 场景/分辨率断点/热区交互测试。
  - **bond:combo 发射缺口**：见 B-2，QA 侧标记为「连携实战恒 0」高风险。
- **垂直切片手感 Playtest 计划**：两层验证模型（headless 逻辑闭环已用 Python 门禁证明；hands-on 手感需在用户本地 Godot 实跑，含 5 闭环入口场景、6 维度检查清单、量化指标、PASS/CONCERNS/FAIL 标准）。

---

## 6. 已知风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| B-2 连携实战恒 0 | 羁绊构筑策略在实战不生效，核心卖点落空 | S3 DoD 阻塞项：战斗发起协调者于 start_battle 后触发 compute_combo 并发射 |
| B-1 觉醒状态机制缺失 | 觉醒技仅为标签，无「灼烧叠层」等深度 | S3 真实战斗层补 BattleResolver 状态逻辑 + 对应测试 |
| B-3 玩家选技缺失 | 战斗策略深度不足 | S3 落技能选择 UI + 技能 power 配置化 |
| C-3 GUT 未实跑 | 全量单测缺口 | 用户本地装 Godot+GUT 跑通 §2 清单后人工审批放行 |
| C-4 cache 回滚/死字段 | 边界健壮性 | S3 补文件级 cache 回滚测试、清理死配置 |
| E4-S6 仅数据 | 双端手感未知 | S3 落 UI 场景 + 分辨率断点 + 热区交互测试 |

---

## 7. S3 DoD 阻塞项清单（由本门禁收敛）

- **B-1** 觉醒改写机制（BattleResolver 状态逻辑）
- **B-2** 羁绊 `bond:combo` 实战发射连线（start_battle 后触发）
- **B-3** 玩家选技落地
- **C-3** 本地 Godot+GUT 全量测试通过
- **C-4** 文件级 cache 回滚测试 + 死字段清理

---

## 8. 下一步

1. **S2 垂直切片手感 Playtest**：headless 逻辑闭环已证明；**hands-on 手感需在用户本地 Godot 实跑**（计划见 `production/qa/s2-vertical-slice-playtest.md`）。建议用户装 Godot+GUT 后，按 §4 清单跑「抽卡→养成→组队→推图Boss→回流」闭环并填写手感指标。
2. **进入 S3（Demo E5 + E6-S5/S6 可访问性桥接 + 双端验证）**，并携上述 5 个 DoD 阻塞项开工。
3. 阶段确认项（Phase 4 待办，可并行）：R2 锚点6 / R3 式神数12 / R4 免费十连文案。
