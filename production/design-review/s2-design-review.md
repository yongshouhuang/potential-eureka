# S2 设计评审与范围检查 · 设计签字报告

> 评审人：design-strategist（文策渊）｜ 阶段：Phase 5 制作 · Sprint S2 收尾评审
> 评审对象：engineering-lead 实现的 S2（E3 养成 ×5 / E4 构筑+战斗 ×6 / E6-S4 云冲突收口）
> 基线文档：`design/gdd/02a-gdd-mvp.md`（B3/R3/B4/R4）、`design/gdd/02b-gdd-full.md`（A1 羁绊 / A5 云存+UI）、`design/gdd/01-concept.md`、`production/epics/mvp-epics-stories.md`、`docs/architecture/adr/adr-002-cloud-save-conflict.md`
> 实现文件：`scripts/autoload/{CultivationManager,BattleResolver,BondManager,BattleManager,DeckBuilder,CloudSaveService,EventBus}.gd`、`scripts/utils/element_shape.gd` 及对应数据表
> 算法层门禁：`production/qa/s2-python-logic-smoke.py`（155/155 断言 PASS，主理人已实跑，**本评审不重跑**）
> 评审性质：**只读审查**，未修改任何 scripts/data/配置/文档（不含本文档自身的产出）。

---

## 0. 评审结论总表

| # | 评审维度 | 判定 | 一句话结论 |
|---|---|---|---|
| 1 | B3 养成数值忠实度（E3 ×5） | **PASS** | 升级/突破/觉醒标记/分支/最终式神聚合全部落地，区间中点确定性约定合理且可单测 |
| 2 | B4 五行克制（E4-S2） | **PASS** | 金→木→土→水→火→金 + 相生双射环、倍率 1.25–1.35/0.7–0.8/1.02–1.05 全区间精确对齐 |
| 3 | A1 羁绊连携（E4-S3） | **CONCERNS** | 连携加成数值与事件解耦均正确，但 **`bond:combo` 发射器在 S2 交付中无人调用**，实战加成恒为 0，须 S3 接线 |
| 4 | B4 回合流程/回流（E4-S4/S5） | **CONCERNS** | 流程跑通、克制广播、推图回流（含觉醒石仅 Boss）均对齐；但「玩家选技 / 技能 power 数据化 / 目标选择」未落地（S3） |
| 5 | E3-S3 AC2 觉醒改写机制 | **CONCERNS** | AC1 觉醒技 id 已记录进最终式神；AC2 状态改写（灼烧可叠层）未实现，觉醒技实战为「标签」，无机制效应（S3） |
| 6 | E6-S4 云存档冲突（ADR-002） | **PASS** | 版本+last-write、cache 副本、delta<50KB、mock 延迟 200ms<2s 全对齐 |
| 7 | 跨 GDD 一致性（get_final_unit→战斗） | **PASS** | 养成产出字段被战斗层完整无漂移消费；仅 `skills` 被读入但未使用（关联风险 5） |
| 8 | E4-S6 双端视觉常量 | **PASS** | `battle_ui_constants.json` + `element_shape.gd` 形状冗余/热区 44px 齐备；仅数据、UI 场景 S3 落地 |
| 9 | 设计红线（R1–R5 / 支柱漂移） | **PASS** | 主导策略/经济失衡/认知过载/支柱漂移均未现；网状克制+连携结构已就位 |

**设计签字建议：有条件放行（CONCERNS）。**
- S2 在「算法正确性 + 养成/战斗/回流/云冲突的 GDD 设计意图对齐」上扎实，Python 门禁 155/155 已钉死逻辑层；无回归、无经济失衡、无支柱漂移。
- 放行前**不阻塞 S2 自身 headless DoD**（S2 范围是「算法 + 流程跑通」，上述缺口均属 S3 真实战斗层，已显式外置），但**有 3 项必须进入 S3 DoD 的阻塞项**（见 §5），否则 GDD 承诺的「P3 构筑策略增量」「P1 成队养成奖励」在实战中不会兑现。

---

## 1. 评审范围与方法

### 1.1 范围基线（Epic `mvp-epics-stories.md:196-204`）
> S2 范围：E3 全 5 故事 + E4 全 6 故事 + E6-S4（云冲突 last-write）。

| Epic/故事 | 对应 GDD | 实现文件 | 已读核验 |
|---|---|---|---|
| E3-S1~S5 养成 | B3（02a:100-137） | `CultivationManager.gd` + `cultivation_config.json`/`shikigami_defs.json` | ✓ |
| E4-S1 构筑 | B4（02a:140-177） | `DeckBuilder.gd` | ✓ |
| E4-S2 五行结算 | B4 | `BattleResolver.gd` + `element_matrix.json` | ✓ |
| E4-S3 羁绊 | A1（02b:17-38）/ B4 | `BondManager.gd` + `bond_combos.json` | ✓ |
| E4-S4 回合流程 | B4 | `BattleManager.gd` | ✓ |
| E4-S5 推图回流 | B4 | `BattleManager.gd` + `chapters.json` | ✓ |
| E4-S6 双端适配 | B4 / art-bible §7-8 | `element_shape.gd` + `battle_ui_constants.json` | ✓ |
| E6-S4 云冲突 | A5（02b:120-143）/ ADR-002 | `CloudSaveService.gd` | ✓ |
| 事件中枢 | 架构 §1.8 | `EventBus.gd` | ✓ |

### 1.2 方法
1. **逐文件 Read 核验**：对上表 8 个 .gd + 6 个数据表 + EventBus 全文阅读，对照 GDD 章节与 Epic AC 逐条取证。
2. **算法层信任 Python 门禁**：`s2-python-logic-smoke.py` 已实跑 155/155 PASS，覆盖 T2（五行）/T6（羁绊解耦）/T7（养成聚合）/E4-S5（回流）/E6-S4（云冲突）/E4-S6（常量）/数据一致性；本评审**不重跑**，仅在其之上做「设计意图忠实度」判断。
3. **硬约束 grep**：对 `BattleManager.gd` 做 `BondManager|preload|const Bond` 全仓 grep，确认零跨 import（验证 E4-S3 AC2 解耦硬约束）。
4. **发射器可达性 grep**：对 `scripts/` 全树 grep `compute_combo|BondManager`，确认事件发射责任是否被某组件承担（发现风险 3）。
5. **设计语言评估**：用 SDT（自主/胜任/关联）、心流、MDA、Bartle、主导策略（R5）评估核心循环「好玩」方向是否成立。

---

## 2. 逐系统对齐结论（GDD 章节对照）

### 2.1 B3 养成系统（02a:100-137）— E3 ×5 — PASS

| 项 | GDD/AC 意图 | 实现/配置 | 位置 | 结论 |
|---|---|---|---|---|
| 升级线性 +2~3%/级 | AC1（mvp:82） | `hp/atk_per_level_pct_min/max=0.02/0.03` → 中点 2.5% | `cultivation_config.json:11-14`；`CultivationManager.gd:144-149` | ✓ |
| 等级上限随阶 20→80 | B3④ / AC2（mvp:83） | `level_cap_per_tier=[20,36,52,64,72,80]`；超阶拦截 | 配置:5；`CultivationManager.gd:33-41,51-52` | ✓ |
| 突破 +8~12%/阶 + 被动槽 | B3④ / AC1（mvp:86） | `attr_gain_pct_min/max=0.08/0.12`；`passive_slots_per_tier=[1..6]` | 配置:6-8；`CultivationManager.gd:153-154,80,84-89` | ✓ |
| 突破耗丹+碎片 | AC1 | `po_dan_per_tier=1, fragments_per_tier=5`；不足拦截 | 配置:19-21；`CultivationManager.gd:71-76` | ✓ |
| 觉醒标记 | E3-S3 AC1（mvp:90） | `awakened_skills[]` 记录；`threshold=3` | `CultivationManager.gd:94-110` | ✓（仅 AC1） |
| 分支剑修/体修 | E3-S4（mvp:93-95） | `branches.sword/body`；`MIN_BRANCH_TIER=3`；被动入 skills | 配置:31-34；`CultivationManager.gd:115-127,163-167` | ✓ |
| 最终式神聚合 | E3-S5 AC1-2（mvp:97-99） | `get_final_unit` 聚合 element/stats/skills/bond_tags/bt/branch | `CultivationManager.gd:132-179` | ✓ |

**设计解读**：养成层的「御剑修真（P2）」飞升爽感被精确兑现——等级/突破/觉醒/分支四档递进、数值确定可复现、事件广播齐备（cultivate_level_up/breakthrough/awakened/branch_chosen，见 `EventBus.gd:44-47`）。**胜任感（SDT）** 来源清晰：每步成长即时、可见、无随机挫败（确定性中点消除养成 RNG 焦虑）。

### 2.2 B4 五行克制（02a:140-177）— E4-S2 — PASS

| 项 | GDD 意图 | 实现 | 位置 | 结论 |
|---|---|---|---|---|
| 网状相克金→木→土→水→火→金 | B4③ | `ke` 双射环完整 | `element_matrix.json:3-9` | ✓ |
| 相生小幅增益 | B4③ / AC2 | `sheng` 双射环；`sheng_bonus 1.02–1.05` | `element_matrix.json:10-22` | ✓ |
| 克制 ×1.25–1.35 / 被克 ×0.7–0.8 | B4④ / AC1 | `advantage/disadvantage` band + `lerp` 种子化 | `BattleResolver.gd:35-45` | ✓ |
| 纯计算、不写状态、可独立测 | — | `extends RefCounted` + `class_name` | `BattleResolver.gd:5-6` | ✓ |

**设计解读**：五行网状（非石头剪刀布）结构 + 克制/被克/相生三态倍率，是压制主导策略（R5）的**结构基座**。种子化 RNG 在 band 内取倍率，使战斗有「变数」而养成确定——精确对应概念文档「确定性与变数的张力」（01-concept:39）。

### 2.3 A1 羁绊连携（02b:17-38）— E4-S3 — CONCERNS（见风险 3）

| 项 | GDD/AC 意图 | 实现 | 位置 | 结论 |
|---|---|---|---|---|
| 2 人 +8~12% / 3+ +15~20% | B4④ / AC1（mvp:114） | `combo_2/3plus_min/max` 中点 | `bond_combos.json:7-18`；`BondManager.gd:41-45` | ✓ |
| 经 `bond:combo` 事件、不 import BondManager | AC2（mvp:115） | BattleManager 仅订阅；全仓 grep 零 preload | `BattleManager.gd:31-36`；grep 零命中 | ✓（解耦） |
| 连携触发 emit + 横幅数据 | AC2 | `EventBus.bond_combo.emit` | `BondManager.gd:49-50` | ✓ |
| **实战加成落地** | — | **无组件调用 `compute_combo`** | grep 全 `scripts/` 无 caller | ✗（见 §3.3） |

### 2.4 B4 回合流程 / 推图回流（02a:140-177）— E4-S4/S5 — CONCERNS

| 项 | GDD/AC 意图 | 实现 | 位置 | 结论 |
|---|---|---|---|---|
| 一回合流程跑通 | E4-S4 AC1（mvp:118） | `step()` 行动条(atk 降序)+自动选技+结算 | `BattleManager.gd:142-209` | ✓（流程） |
| 克制命中 emit `battle:element_advantage` | AC2（mvp:119） | 玩家方 ADVANTAGE 广播 | `BattleManager.gd:191-192` | ✓ |
| 3 章 × 8–10 关 + Boss | B4④ / AC1（mvp:122） | 3 章 × 9 关、每章 1 Boss | `chapters.json` 结构 | ✓ |
| 回流符箓 1–3/关、丹/石 | AC2（mvp:123） | `fu_lu[1,3]/[2,4]`；`po_dan=1/jue=1` 仅 Boss | `chapters.json` rewards；`BattleManager.gd:256-273` | ✓ |
| **玩家选技 + 技能 power 数据化** | AC1「玩家选技」 | **`power` 恒硬编码 1.0、自动首活目标** | `BattleManager.gd:168,171` | ✗（S3） |
| 觉醒石仅 Boss（对齐 E1 boss_only） | E1-S1 AC2 / B1 | 非 Boss 关 `jue_xing_shi=0`；Boss 以 `"Boss"` 源回流 | `chapters.json`；`BattleManager.gd:268-272` | ✓（跨系统一致） |

**设计解读**：推图回流闭环成立——产出（符箓/丹/石）经 `EconomyManager.grant` 回经济（B1），`GameState.progression` 推进，完美闭合概念文档「增长螺旋」（01-concept:37）。**但** S2 的战斗是 headless 自动流程：技能 power 恒为 1.0、目标自动选首活单位、无能量/选技。这满足 S2 DoD「流程跑通」，但**核心循环的「战成为策略表达（P3）」在交互层尚未兑现**——属 S3 真实战斗层范畴。

### 2.5 E6-S4 云存档冲突（ADR-002 / 02b:120-143）— PASS

| 项 | ADR-002 / AC 意图 | 实现 | 位置 | 结论 |
|---|---|---|---|---|
| 版本+last-write 高者胜 | AC1（mvp:164） | `resolve_conflict` 先比 schema_version 再比 ts | `CloudSaveService.gd:24-35` | ✓ |
| 覆盖前写 cache 可回滚 | AC2（mvp:165） | `push_save` 先 `_cache=duplicate` | `CloudSaveService.gd:53` | ✓ |
| delta<50KB / 延迟<2s | AC3（mvp:166） | `DELTA_LIMIT_BYTES=50000`；`SYNC_LATENCY_MOCK_MS=200` | `CloudSaveService.gd:7,11,77` | ✓ |

**设计解读**：离线优先、单人非协作下的「丢一端改动」取舍（ADR-002 Consequences）被明确接受，符合 MVP lean 定位。无安全评审（加密/认证）属已知 ADR 缺口，不在 S2 范围。

### 2.6 E4-S6 双端视觉常量（02a:177 / art-bible §7-8）— PASS（数据层）

`battle_ui_constants.json`：`element_shapes`（五行各一形状）+ `shape_redundancy=true` + `hotzone_min_px=44`（行 3-11）。`element_shape.gd`：`ElementShapeMap` 常量 + 兜底映射 + 数据驱动读取（行 8-55）。**仅数据/常量，未写 UI 场景**——UI 落地为 S3 Demo（E5）范畴，符合范围划分。

### 2.7 跨 GDD 一致性（get_final_unit → 战斗层）— PASS

`CultivationManager.get_final_unit`（132-179）输出 `{id, element, bond_tags, final_stats{hp,atk}, skills, breakthrough, passive_slots, branch, level}`，被 `BattleManager._build_players`（92-101）按同名字段完整读取：**element / final_stats.atk / final_stats.hp / bond_tags / breakthrough / passive_slots**，无字段漂移、无命名错位。唯一观察：`skills` 被读入 `players[].skills` 但当前实战未消费（关联风险 5）。

---

## 3. 重点风险项结论

### 3.1 ★ E3-S3 AC2 部分实现（觉醒改写机制缺口）

**事实取证**
- AC1（觉醒技标记）：`CultivationManager.awaken_skill`（94-110）将 `skill_id` 写入 `awakened_skills[]`；`get_final_unit`（157-167）把该 id 并入 `skills[]`。**已实现**。
- AC2（状态改写在 BattleResolver 生效）：`BattleResolver` 仅做伤害倍率计算（`resolve_damage`，52-68），**无任何状态/灼烧/叠层逻辑**；`BattleManager.step()` 的技能 `power` 硬编码为 `1.0`（168,171）且从不引用单位 `skills` 列表。**未实现**。
- 测试盲区：`test_cultivation.gd:149-156`（`test_awaken_skill`）只断言「id 被标记」，不断言任何战斗效应——缺口对单测隐形。

**设计结论：构成设计缺口（非回归、属计划内 S3 外置）**
- GDD B3③ 明确定义觉醒是「**改写机制而非纯数值**，提供 P3 构筑策略增量」；概念文档将「技能觉醒」列为成长核心动词之一（01-concept:94）。当前 S2 中，觉醒技是**纯标签**——养成层记录了它，但战斗层无任何机制响应。这意味着「御剑飞升」到达觉醒门槛后，**玩家在实战中感受不到质变**，削弱了 P2 飞升爽感与 P3 策略表达。
- **对核心循环手感的影响**：在 S2 headless 阶段影响有限（本就无交互战斗）；但若 S3 真实战斗层不补回，觉醒将成为「养成投入大、实战零反馈」的空洞承诺，直接冲击胜任感与付费/养成动机（R1/R2 相关）。
- **S3 必须补回的边界**：
  1. 在 `BattleResolver`（或新增 `StatusManager`）实现状态系统：灼烧（DoT）、叠层上限、净化/持续回合——**数据驱动**（如 `skills_by_shikigami` 由「id」扩展为「id + effect_spec」）。
  2. 觉醒技 id → 实际效果映射，需在数据表承载「改写规则」而非仅字符串。
  3. 现有中点确定性约定应延伸至状态数值（如灼烧每层 % 取区间中点），保持可单测。

### 3.2 ★ 数值确定性约定（区间 → 中点）

**事实取证**：`CultivationManager.gd:6-7` 头注释明确「取区间中点作为确定性代表值（可单测可复现）；区间本身仍由配置表驱动」；实现于 144-155 行（`0.5*(min+max)`）。配置表 `cultivation_config.json` 同时持有 `min/max`。

**设计结论：约定合理、可接受，附 1 条文档建议**
- **对平衡/手感**：养成确定性 = 无养成 RNG → 玩家成长曲线完全可预期，**胜任感清晰、零随机挫败**（利好 R1/R2）。与战斗层「种子化 band 变数」形成「养成确定 / 战斗变数」的干净分工，正合概念文档张力设计（01-concept:39）。
- **策划可调性**：策划只需改 JSON 的 `min/max`，中点自动重算，**零代码改动**即可调参，且不破坏单测可复现性。这是对「验证驱动 + 数据驱动（ADR-004）」的忠实落实。
- **风险点（低风险）**：若策划误将 GDD 的「+2~3%/级」理解为「每次升级随机 2–3%」，会惊讶于结果恒为 2.5%。GDD B3④ 的区间本意是**设计调参包络**（designer picks a point），中点即「设计师选定的代表值」——解释自洽，但建议在 GDD B3④ 补一句澄清「运行时取中点、区间供调参」，避免后续维护者误读。
- **判定**：不阻塞，不掉队。

### 3.3 ★ 羁绊事件解耦硬约束 + 发射器缺失（组合风险）

**解耦硬约束：PASS（已验证）**
- `BattleManager.gd` 全仓 grep `BondManager|preload|const Bond` 仅命中**注释**（2、8、31 行），**无 `preload` / `const Bond` / `import`**。BattleManager 仅经 `EventBus.bond_combo.connect(_on_bond_combo)`（31-36）取加成。E4-S3 AC2 解耦硬约束**严格满足**，无跨管理器代码级耦合，无循环依赖。

**发射器缺失：CONCERNS（关键集成断点）**
- grep 全 `scripts/` 树：`compute_combo` **仅在 `BondManager.gd:27` 定义，无任何调用方**；`BattleManager` 只订阅不发射。`test_bond.gd:58` 与 Python T6 都是**测试里手动调用** `bm.compute_combo(...)` 来触发事件——证明事件路径通畅，但也暴露：**生产代码中无任何组件在战斗开始时调用 `compute_combo(deck)`**。
- 后果：在真实战斗中 `_bond_bonus` 恒为 `0.0`，**连携加成（P1 成队养成奖励 / P3 横切增益）实战永不触发**，除非 S3 某协调器（战斗引导/E5 场景/DeckBuilder 确认编队时）主动发射 `bond:combo`。
- **为何构成风险**：连携是 A1 的核心交付、B4 的横切增益、概念文档「羁」动词的实战兑现。S2 交付把「监听端」做对了，却把「发射责任」留空——属于**集成断点**，不是算法缺陷，但会在 S3 Demo 首次跑通时表现为「组了剑宗三人却没加成」的静默 bug。
- **S3 必须接线**：在战斗启动流程中显式调用 `BondManager.compute_combo(GameState.deck)`（或新增 `BattleSetup` 协调器），使 `bond:combo` 在 `start_battle` 前/时发出。该责任归属须写入 S3 DoD（见 §6）。

### 3.4 E4-S2/S3/S4/S5 对 GDD 的忠实度汇总

- **S2 五行**：完全忠实（§2.2）。相生 `1.02–1.05` 为 GDD「小幅增益」的合理数值化（GDD 未给精确值）。
- **S3 羁绊**：数值忠实、解耦忠实；**发射器缺失**（§3.3）。
- **S4 回合流程**：流程忠实、「克制！」广播忠实；**「玩家选技」未落地**（power 恒 1.0、自动目标），为 S3 真实战斗层范畴。
- **S5 推图回流**：完全忠实，且**觉醒石仅 Boss 来源**与 E1 `boss_only` 跨系统一致（数据完整性测试 `DATA_INTEGRITY_suite` 也已校验每 Boss 关 `jue_xing_shi=1`、普通关 `=0`）。

### 3.5 跨 GDD 一致性（养成产出 → 战斗消费）

见 §2.7：**PASS，无漂移**。仅 `skills` 字段被读入但未消费，与风险 3.1（觉醒技无机制效应）同源，归并处理。

---

## 4. 设计侧已知风险与缓解建议

| 编号 | 风险 | 类型 | 缓解建议 | 处理阶段 |
|---|---|---|---|---|
| D-1 | 觉醒改写机制缺位（E3-S3 AC2），觉醒技实战为标签 | 设计缺口（计划内 S3） | S3 在 BattleResolver/StatusManager 实现数据驱动状态系统；觉醒技 id→effect_spec 映射 | **S3 阻塞** |
| D-2 | `bond:combo` 发射器无人调用，连携实战恒 0 | 集成断点 | S3 战斗启动流程显式 `compute_combo(deck)` 并发射；写入 S3 DoD | **S3 阻塞** |
| D-3 | E4-S4「玩家选技」未落地（power 硬编码 1.0、自动目标） | 范围外置（S3） | S3 真实战斗层：技能 power 数据化、玩家选技、目标选择、能量资源 | **S3 阻塞** |
| D-4 | E4-S6 双端常量仅数据、未落地 UI 场景 | 范围外置（S3） | S3 Demo 按 `battle_ui_constants` + `element_shape` 渲染形状冗余/HUD/热区 | S3 |
| D-5 | 法宝位战斗惰性（headless 跳过非式神 id，无战斗效应） | 范围外置（MVP 轻） | S3 至少给法宝位一个被动/装备效应，或于 GDD 明确 MVP 法宝位为装饰性 | S3/文档 |
| D-6 | 数值区间中点约定或致策划误读 | 文档清晰度 | GDD B3④ 补「运行时取中点、区间供调参」一句 | 文档（非阻塞） |
| D-7 | 冻结 schema v1 未标注 shikigami 条目子字段（awakened_skills/branch/fragments/passive_slots） | 文档/契约 | 架构 §1.7 补 shikigami 条目子结构（SaveManager 已整体序列化可往返，无漂移） | 文档（非阻塞，延续 S1-C2） |
| D-8 | 云存档安全（加密/认证）未评审 | ADR-002 已知缺口 | 排入核心层安全评审（非 S2 阻塞） | 后续 |

---

## 5. 总体设计门禁判定

### 判定：**CONCERNS（有条件放行）**

**通过项（设计意图忠实、无红线违反）**
- B3 养成 / B4 五行 / E6-S4 云冲突 / E4-S6 常量 / 跨 GDD 一致性 / 设计红线（R1–R5 + 支柱漂移）**全部 PASS**。
- Python 算法门禁 155/155 已钉死逻辑层正确性（五行倍率、羁绊解耦、养成聚合、回流、云冲突、数据一致性）。
- 羁绊事件解耦硬约束经 grep 严格验证（零跨 import）。

**未达 PASS 的原因（非缺陷、属 S3 计划内外置）**
1. **E3-S3 AC2 觉醒改写机制未实现** → P3 构筑策略增量、P2 飞升质变在实战中缺失。
2. **`bond:combo` 发射器无人调用** → 连携加成实战恒为 0，P1 成队养成奖励静默失效。
3. **E4-S4「玩家选技」未落地** → 核心战斗的「策略表达（P3）」交互层未兑现。

三项均属 S2「headless 算法+流程」范围之外的真实战斗层内容，已在交付说明中显式外置到 S3，**不构成 S2 自身 DoD 的阻塞**；但**构成 S3 的阻塞项**——不补回则 GDD 对玩家的核心承诺（觉醒机制改写、成队连携、玩家选技）不会在实战中成立。

### 阻塞项清单（须进 S3 DoD，否则核心循环「好玩」承诺落空）

| 阻塞项 | 内容 | 不处理的后果 |
|---|---|---|
| **B-1** | S3 真实战斗层补回觉醒状态改写机制（灼烧可叠层等），数据驱动 | 觉醒=空标签，P2/P3 承诺失效，养成动机空洞（R1/R2） |
| **B-2** | S3 战斗启动流程接线 `bond:combo` 发射器（调用 `compute_combo(deck)`） | 连携加成实战恒 0，P1 成队奖励失效 |
| **B-3** | S3 落地玩家选技 / 技能 power 数据化 / 目标选择 / 能量资源 | 战斗仅自动流程，P3「构筑随心」无交互表达 |

> 说明：以上 B-1/B-2/B-3 是**对 S3 的放行前条件**，不是对 S2 的。S2 可签字放行（CONCERNS），但**主理人应在 S3 开局前将 B-1/B-2/B-3 写入 S3 DoD 并设为 S3 门禁阻塞项**。

---

## 6. S3 设计待办建议

1. **【阻塞】战斗机制层（B-1/B-3）**：实现 `StatusManager`（或扩展 `BattleResolver`）承载状态/灼烧/叠层/能量；技能 `power` 与效果从数据表读取；`BattleManager.step()` 改为玩家选技 + 目标选择；觉醒技 id→effect_spec 映射。保持中点确定性 + 种子化 band，便于单测。
2. **【阻塞】连携发射接线（B-2）**：在 `BattleManager.start_battle`（或新增 `BattleSetup` 协调器）中调用 `BondManager.compute_combo(GameState.deck)` 发射 `bond:combo`；建议在 `EventBus` 注释明确「战斗启动方负责发射」。
3. **E4-S6 UI 落地（D-4）**：S3 Demo 按 `battle_ui_constants` + `element_shape` 渲染五行形状冗余、移动端精简 HUD、≥44×44 热区、克制三重标识（图标+数字+颜色，accessibility Basic D/E）。
4. **法宝位效应（D-5）**：决定 MVP 法宝位为「装饰性」还是给最小战斗被动，于 GDD 显式声明，避免玩家预期落差。
5. **文档收口（D-6/D-7）**：GDD B3④ 补中点澄清；架构 §1.7 补 shikigami 条目子字段；延续闭合 S1-C2 冻结 schema  drift。
6. **云安全（D-8）**：将 ADR-002 已知的「加密/认证安全评审」排入核心层计划。
7. **心流/手感验收**：S3 Demo 跑通后应做一轮「核心循环好玩」主观验收——重点验证觉醒质变可见、连携有反馈、选技有策略空间，确认 P1/P2/P3 三支柱在交互层真正成立（而非仅算法成立）。

---

## 7. 设计红线自检（R1–R5 / 支柱）

- **主导策略（R5）**：五行网状克制 + 相生 + 连携的数据结构已就位，从机制上压制单卡通吃；但交互层（选技/状态/连携实战）在 S3 才兑现，R5 的「实战抑制」目前仅结构就绪、未运行验证。✓ 结构无主导策略；运行验证待 S3。
- **经济失衡（R1）**：觉醒石仅 Boss（跨系统一致）、S1 预算硬上限 intact、回流闭环成立。✓ 无新增 R1 风险。
- **认知过载**：S2 headless 无 UI 堆叠；E4-S6 数据就绪未渲染。✓ 无。
- **支柱漂移**：P1 抽养一体（养成产出最终式神、连携数据就绪）✓；P2 御剑修真（突破飞升确定数值爽感）✓；P3 构筑随心（五行+连携机制就绪，交互表达待 S3）△ 部分就绪、无漂移。✓ 无漂移。

---

## 8. 一句话汇报（主理人）

**S2 设计门禁判定：CONCERNS（有条件放行）；最关键发现——养成/五行/云冲突均忠实 GDD 且算法 155/155 通过，但「觉醒改写机制（E3-S3 AC2）未实现」与「`bond:combo` 发射器在 S2 交付中无人调用（连携实战恒为 0）」两项构成必须进 S3 DoD 的阻塞项，否则 GDD 对玩家的 P3 构筑策略与 P1 成队养成核心承诺在实战中不会兑现。**
