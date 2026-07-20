# S3 设计范围评审与机制定稿 · design-strategist 签字报告

> 评审人：design-strategist（文策渊）｜ 阶段：Phase 5 制作 · Sprint S3 规划（E5 Demo 串接 + E6-S5/S6 可访问性桥接 + 双端验证 + 式神资产补齐）
> 评审对象：S2 门禁遗留 3 项设计/机制缺口（B-1 觉醒改写 / B-2 连携发射 / B-3 玩家选技）+ S3 范围（E5 Demo 串接、式神资产 8→13）
> 基线文档：`design/gdd/01-concept.md`（P1–P3 / R1–R5）、`02a-gdd-mvp.md`（B1–B5）、`02b-gdd-full.md`（A1/A5）、`production/s2-gate.md`、`production/phase4-assembly.md`、`production/phase4-decisions.md`、`production/qa/s2-vertical-slice-playtest.md`
> 实现文件（仅 Read 取证，未修改）：`scripts/autoload/{EventBus,BattleManager,BondManager,CultivationManager,DeckBuilder,GameState}.gd`、`data/{shikigami/shikigami_defs,battle/bond_combos,battle/chapters,cultivation/cultivation_config}.json`
> 评审性质：**规划 + 设计定稿**，未修改任何 scripts/data/配置/资产（不含本文档自身产出）。

---

## 0. 评审结论总表

| # | 评审维度 | 判定 | 一句话结论 |
|---|---|---|---|
| 1 | S3 设计范围（E5 Demo 串接「好玩」维度） | **PASS** | 抽→养→筑→战→回流闭环在交互层可验证；MDA 动态层 / 心流 / 三支柱验收口径已落到可量化 Playtest 清单 |
| 2 | B-1 觉醒「灼烧叠层」改写机制定稿 | **PASS** | 规则（叠层/层数上限/每层效果/交互/衰减）+ 数据驱动 AC + skill_defs 契约已就绪，可直接落地 |
| 3 | B-2 `bond:combo` 实战发射接线定稿 | **PASS** | 发射节点（战斗启动协调器 / 场景）、事件接线方案、零跨 import 红线守住，已给可直接抄写的调用契约 |
| 4 | B-3 玩家选技定稿 | **PASS** | 选技时机 / 数量 / 与养成觉醒·分支被动关系 / 五行倍率影响已定稿；气（qi）资源门控为推荐项 |
| 5 | 式神资产补齐 8→13 设计配合 | **PASS** | N3/R4/SR3/SSR3 分布下，5 新卡归属正好补全 5 个羁绊组（jian_zong/tie_bi/yu_zu/long_zu/hu_zu）且补齐玩家侧火行（灼烧归属火 SSR 朱雀，主理人确认朱雀为火 SSR） |
| 6 | 设计红线（R1–R5 / 支柱漂移） | **PASS** | 水克火压制灼烧_meta、状态/连携/选技正交不双 dip、五行全系玩家侧齐备；无主导策略/经济失衡/认知过载/支柱漂移 |

**S3 设计评审结论：PASS（设计定稿就绪，1 项待主理人/用户拍板）**

- 3 项 S2 遗留缺口（B-1/B-2/B-3）现已有**完整、可实现、数据驱动**的设计定稿与工程 AC，不再阻塞 S3 开工。
- 式神资产补齐方案在 R3（N3/R4/SR3/SSR3，朱雀确认为火 SSR 放宽原 SSR2 锁）与 5 个羁绊组完整性前提下，同时解决了「玩家侧无火行 → 灼烧机制无归属」的隐藏缺口（见 §5.3）。
- **设计决策已拍板（已采纳）**：主理人确认**朱雀为火 SSR（`ssr_zhu_que`）**，`ssr_zhu_que` 已补建入 `shikigami_defs.json`，R3 由原 SSR2 锁放宽至 **SSR3（青龙/白虎/朱雀）**。灼烧机制归属火 SSR 朱雀完整交付；原 §5.3「建议火 SR 朱雀」方案被此决策取代。

---

## 1. S3 设计范围评审（E5 Demo 串接应验证的「好玩」维度）

### 1.1 E5 Demo 串接范围再确认

S3 范围（据 `phase4-assembly.md §3`）：E5 全 4 故事（Demo 串接）+ E6-S5（AccessibilitySettings）+ E6-S6（MotionScale + CVD）+ 双端验证 + 式神资产补齐（8→13）。

E5 须串起的最小端到端闭环（对齐 `ux-spec.md §1` 与 `s2-vertical-slice-playtest.md §2` 场景 A–E）：

```
抽卡(Summon) → 养成(Cultivate：升级/突破/觉醒/分支) → 编队(DeckBuild：4式神+1法宝)
             → 推图战斗(Battle：选技+连携+克制+觉醒状态) → 结算(Settlement) → 资源回流(顶栏+N飘字)
             → 回到抽卡(用回流符箓)  ← 飞轮闭合
```

**S3 是「算法正确（S2 已证 155/155）」走向「交互好玩」的关键一跃**。下列维度须被显式验收。

### 1.2 应验证的「好玩」维度

#### (A) MDA · 动态层（Dynamics）三涌现是否兑现

| 动态 | S2 状态 | S3 须验证（交互层首次可验） |
|---|---|---|
| **增长螺旋**（抽养战回流飞轮） | 数学闭环已证（Python 155/155） | 回流资源**即时可见**（顶栏 +N 飘字 <0.5s）+ 结算 CTA「去抽卡」缩短心理距离（ux-spec §4 卡点 #5） |
| **策略涌现**（非数值碾压） | 结构就绪（网状克制+连携数据就位） | 玩家**选技 + 编队五行 + 连携组**三者组合产生可感知的不同结果；无单卡/单组通吃（R5 运行验证） |
| **确定性与变数张力** | 养成确定性 + 战斗 band RNG 已分离 | 养成成长**完全可预期**（胜任感）；战斗克制/连携/灼烧 DoT 引入**可读变数**（惊喜欲） |

> 判定口径：若 S3 真实战斗层补回 B-1/B-2/B-3 后，玩家在「同一队伍不同选技」与「不同五行编队」下出现**可辨的差异结果**，则动态层 PASS；若无论怎么选结果趋同（策略无效），则记 CONCERNS（主导策略或策略空洞）。

#### (B) 心流（Flow）平衡

对齐 `s2-vertical-slice-playtest.md §3.1`：
- 单场时长 **2–4 min**（场景 D 计时；Boss 关偏上限但仍 <4min）。
- 回合间**无空窗**（行动条按 atk 降序已实装，S3 选技 UI 须保证玩家决策 <3s/回合，否则拖节奏）。
- 奖励**即时反馈**（结算→顶栏跳动 <0.5s）。
- **无死锁**（全员阵亡/满员正确分胜负，不卡输入等待）。

#### (C) 三大支柱在交互层首次真正成立

| 支柱 | S2（算法） | S3（交互）须兑现的体感 |
|---|---|---|
| **P1 抽养一体** | 出货记录 + 养成最终式神产出 | 出货即羁绊序章（已实现钩子）；养成每步（升级/突破飞升/觉醒/分支）**UI 可感知质变** |
| **P2 御剑修真** | 突破/觉醒确定数值 | 觉醒后**战斗机制改写可见**（灼烧叠层 DoT、破甲、中毒等），非仅数字 +X% |
| **P3 构筑随心** | 五行+连携数据结构 | 编队预览连携 + 战中选技/选目标 + 五行倍率**即时反馈**；策略表达闭环 |

### 1.3 UX 闭环（抽→养→战→回流）打通检查

| 环节 | 是否打通 | S3 必做（否则断流） |
|---|---|---|
| 抽→养 | ✓ 出货记录 + 去养成入口（ux-spec §1） | 无新增 |
| 养→筑 | ✓ 一键编队入口 | 无新增 |
| 筑→战 | ✓ 编队确认出战 | **B-2：确认出战时须发射 `bond:combo`**（否则连携恒 0） |
| 战（选技） | ✗ S2 自动流程 | **B-3：玩家选技 + 目标选择 + 技能 power 数据化** |
| 战（觉醒机制） | ✗ S2 标签 | **B-1：灼烧等状态改写实战生效** |
| 战→回流 | ✓ 经济回流 + 顶栏更新 | 无新增（S2 已证） |
| 回流→抽 | ✓ 结算 CTA「去抽卡」 | **资源断流引导（R1 UX 卡点 #1/#2）**：消耗点（抽卡/养成）资源不足时显「去哪产出」引导，接 `economy:currency_changed`（phase4-def §2 R1 遗留 S3 收口） |

> **闭环结论**：5 段跳转中，仅「筑→战（连携发射）」「战（选技/觉醒机制）」「回流→抽（断流引导）」3 处为 S3 新增缺口；其余 S2 已证或仅需 UI 承载。这 3 处全部落在 B-1/B-2/B-3 + R1 收口中。

### 1.4 可操作的 Playtest 验收口径（扩展自 s2 垂直切片）

在 `s2-vertical-slice-playtest.md` 的 5 场景 × 6 维度基础上，S3 新增 / 强化下列验收点（建议回填为 `production/qa/` 的 S3 Playtest 清单）：

**新增验收点（直接对应 B-1/B-2/B-3）**

| 维度 | 验收项 | 通过标准 | 关联缺口 |
|---|---|---|---|
| 觉醒质变 | 火系觉醒单位（朱雀）命中后目标出现「灼烧」状态图标 + 每回合 DoT 跳动 | DoT 每 tick 扣除 = `层数 × 3% × 目标最大HP`（中点）；非觉醒同卡无此效果 | B-1 |
| 觉醒质变 | 灼烧叠层上限生效（连点 3 次仍 ≤3 层） | 层数封顶 3，不溢出 | B-1 |
| 觉醒交互 | 对**水**行敌（c1_boss_add 土？取 c3_boss 水）灼烧被压制（层数≤1/时长减半） | 水克火压制可见 | B-1/R5 |
| 连携实战 | 编「剑宗 4 人」进战斗，`_bond_bonus > 0`（或横幅出现） | 加成 = 最优组中点（3+ 人 = +17.5%）；横幅不被遮挡 | B-2 |
| 连携实战 | 单人或无连携组编队，加成 = 0 且不报错 | 静默 0，无异常 | B-2 |
| 选技空间 | 战斗中每个玩家单位可**选择**技能（基础 / 觉醒）与目标 | 至少 2 选项可切换；目标可指定 | B-3 |
| 选技策略 | 觉醒技受「气」门控（可选）时，气不足无法放觉醒 | 气资源可见、门控生效 | B-3 |
| 五行倍率 | 选技/技能 element 命中克制时伤害差肉眼可辨（≥25%） | 克制 vs 被克均值差 ≥25% | B-3 |

**量化指标（对齐 s2 §4，新增项加 ★）**

| 指标 | 目标 | 测量 |
|---|---|---|
| 单关耗时 | 2–4min | 场景 D 计时 |
| 克制 vs 被克 平均伤害差 | ≥25% | 同阵容分别打克制/被克 |
| 羁绊触发率 | 100%（满足条件编队） | 横幅出现次数/应出现 |
| ★ 灼烧 DoT 占总伤害比 | 15–35%（火觉醒队 vs 单体） | 战斗日志累加 |
| ★ 连携加成应用率 | 100%（有连携组时 `_bond_bonus>0`） | 日志断言 |
| ★ 选技决策时延 | <3s/回合（不拖节奏） | 计时 |
| 双端断点 | 0 溢出 / 0 裁切 | 截图比对 |
| 热区命中率 | ≥95%（移动 ≥44px） | 连续点击 20 次 |
| 回流到账视觉延迟 | <0.5s | 结算→顶栏跳动计时 |

**通过标准（沿用 s2 §5）**：闭环走通无崩溃/死锁；上述维度全部可感知且正确；双端不破版。任一核心崩溃/数值明显错误/严重破版 = FAIL 回 eng；某维度「不够爽」= CONCERNS 交 design-strategist 调参。

---

## 2. B-1 设计定稿 · 觉醒「灼烧叠层」改写机制

### 2.1 设计意图（对齐 GDD）

- GDD `02a §B3③`：「技能觉醒：达阶位门槛后觉醒主动技（**改写机制而非纯数值**），提供 P3 构筑策略增量。」
- 概念文档 `01-concept §5` 将「技能觉醒」列为成长核心动词；`02a §B3④` 举例「火系 SSR 觉醒后『灼烧』可叠层」。
- S2 现状（`s2-design-review §3.1`）：觉醒技 id 已并入 `skills[]`，但 `BattleResolver` 无任何状态逻辑、`BattleManager.step()` 的 `power` 恒硬编码 1.0 → 觉醒技实战为**纯标签**，P2 飞升质变与 P3 策略增量落空。

### 2.2 机制总览

觉醒技在战斗中是**带 `status_on_hit` 的主动技**；命中敌方时按规则施加强身状态。以「灼烧（burn）」为首个落地类型（其余觉醒类型见 §2.6，共用同一状态系统）。

状态系统由新增 `StatusManager`（或扩展 `BattleResolver` + `BattleManager` 状态字段）承载，**数据驱动**，不写死逻辑。

### 2.3 灼烧（burn）详细规则

**施加入口**：当某玩家单位选用**带 `status_on_hit.type == "burn"` 的觉醒技**并命中敌方时，对该目标施加灼烧。

**叠层（Stack）**
- 每次命中施加 `stacks_applied`（默认 1）层。
- **层数上限 `BURN_MAX_STACKS = 3`**（配置 `burn.max_stacks`，防 runaway）。超过则丢弃溢出层数（已达上限时再施加仅**刷新持续时间**，不再加层）。
- 公式：`stacks = min(stacks + stacks_applied, BURN_MAX_STACKS)`。

**每层效果（DoT）**
- 每个受影响单位的**回合开始**触发一次 tick：
  - `Dmg_tick = round( stacks × burn_dot_pct × HP_max_target )`
  - `burn_dot_pct` = 区间 `[0.02, 0.04]` 的**中点 0.03**（确定性约定，对齐养成中点惯例），单位：目标最大 HP 的比例（无单位系数）。
  - 例：3 层 × 3% × 480（c1_boss 最大 HP）= **43 点/ tick**（可见且非碾压）。
- tick 计入该单位承受的总伤害，参与胜负判定与战斗日志。

**触发与衰减（Duration / Decay）**
- 施加时 `turns_left = BURN_DURATION`（默认 3，配置 `burn.duration`）。
- 每 tick 后 `turns_left -= 1`；`turns_left ≤ 0` 时**清除全部灼烧层数**（一次性到期，非逐层衰减，避免拖尾）。
- 重新施加刷新 `turns_left` 至 `BURN_DURATION`（维持压制力）。

**与五行克制的交互（关键：压制主导策略 R5）**
灼烧为**火行状态**，受目标五行调制：
- 目标为**水**行（五行环 `水→火`，水克火）：灼烧被「浇灭」→ `stacks 上限锁 1`、`turns_left 初始 = floor(3/2) = 1`。 thematic 且防火 meta。
- 目标为**木**行（五行环 `火→木`，火克木）：灼烧增效 → `burn_dot_pct' = burn_dot_pct × 1.20`。
- 其他目标（金/土）：中性，无修正。
- 公式统一：`Dmg_tick = round( stacks × burn_dot_pct × elem_mod × HP_max_target )`，其中 `elem_mod ∈ {1.0 中性, 1.20 火克木, 0.33 近似(水克火下 stacks≤1 且 turns≤1 自然压制)}`。

**与连携（bond）的交互（关键：正交、不双 dip）**
- `bond_bonus`（连携加成）**仅作用于直接打击伤害** `Dmg_strike = round(Atk × elem_mult × power × (1 + bond_bonus))`（已有逻辑）。
- 灼烧 DoT **独立于 `bond_bonus`**，不受连携加成缩放 → 二者正交，避免「状态流+连携流」双重叠加形成主导策略（R5 红线）。
- 觉醒技本身可同时享受连携（其直接打击部分），但 DoT 部分不享受。

**与选技（B-3）的耦合**
灼烧机制**只有在玩家能选用觉醒技时才可表达**（S2 无选技 → 觉醒技永不被触发）。故 B-1 落地须与 B-3 同步：觉醒技作为可选主动技进入选技列表（§4）。

### 2.4 数据契约（新增 `data/battle/skill_defs.json`）

`skills` 表，键为 skill id（与 `shikigami_defs.skills` / `cultivation_config.awaken.skills_by_shikigami` 对齐）：

```json
{
  "_doc": "SkillDef — 技能定义（B-1/B-3 数据驱动）。power 取代硬编码 1.0；status_on_hit 承载觉醒改写机制。",
  "skills": {
    "skill_qing_long_base":     { "element": "metal", "power": 1.00, "status_on_hit": null },
    "skill_qing_long_awakened": { "element": "metal", "power": 1.15,
        "status_on_hit": { "type": "armor_break", "stacks": 1, "duration": 3, "pct_per_stack": 0.05 } },
    "skill_bai_hu_base":       { "element": "metal", "power": 1.00, "status_on_hit": null },
    "skill_bai_hu_awakened":   { "element": "metal", "power": 1.10,
        "status_on_hit": { "type": "momentum", "stacks": 1, "duration": 3, "dmg_per_stack": 0.04 } },
    "skill_you_ming_base":     { "element": "wood",  "power": 1.00, "status_on_hit": null },
    "skill_you_ming_awakened": { "element": "wood",  "power": 1.10,
        "status_on_hit": { "type": "poison", "stacks": 1, "duration": 3, "dot_pct_per_stack_min": 0.02, "dot_pct_per_stack_max": 0.04 } },
    "skill_zhu_que_base":      { "element": "fire",  "power": 1.00, "status_on_hit": null },
    "skill_zhu_que_awakened":  { "element": "fire",  "power": 1.10,
        "status_on_hit": { "type": "burn", "stacks": 1, "duration": 3, "dot_pct_per_stack_min": 0.02, "dot_pct_per_stack_max": 0.04 } },
    "skill_huo_ling_base":     { "element": "fire",  "power": 1.00, "status_on_hit": null },
    "...": "其余 8 张基础技由 art/eng 按 element/base_stats 补满"
  }
}
```

`StatusManager` 配置（建议并入 `data/battle/status_config.json` 或 `skill_defs` 顶部）：
```json
"status": {
  "burn":   { "max_stacks": 3, "duration": 3, "dot_pct_per_stack_min": 0.02, "dot_pct_per_stack_max": 0.04,
              "vs_water": { "max_stacks": 1, "duration": 1 }, "vs_wood": { "dot_mult": 1.20 } },
  "poison": { "...": "同 burn 结构，木行主题" },
  "armor_break": { "max_stacks": 3, "duration": 3, "pct_per_stack": 0.05 },
  "momentum": { "max_stacks": 3, "duration": 3, "dmg_per_stack": 0.04 }
}
```

### 2.5 给 engineering-lead 的可实现 AC（B-1）

1. **新增数据表** `data/battle/skill_defs.json`，承载每个技能 `element` / `power` / `status_on_hit?`；数值区间用 `min/max`，运行取中点（对齐养成确定性约定）。
2. **新增 `StatusManager`**（或 `BattleResolver` 扩展 + `BattleManager` 状态字段），持有 `statuses[unit_id] = [{type, stacks, turns_left, src_element}]`；暴露 `apply_status(target_id, spec, src_element)` 与 `tick_statuses(unit_id) -> total_dot`。
3. **`BattleManager.step()`** 改为：从 `skill_defs` 读取当前选用技能的 `power` 与 `element`（**废除硬编码 1.0**）；命中后若 `status_on_hit` 非空则 `apply_status`；在受影响单位回合开始处调用 `tick_statuses` 结算 DoT 并写 `HP`、广播 `battle_turn_resolved`（relation 标 `STATUS`）。
4. **灼烧规则实现**：层数上限 3、DoT = `层数 × 0.03 × 目标最大HP`（中点）、持续 3 tick、到期清层；**水行目标** `max_stacks=1 & duration=1`，**木行目标** `dot × 1.20`。
5. **正交性**：`bond_bonus` 仅缩放 `Dmg_strike`，**不**缩放 DoT（代码注释标明，防双 dip）。
6. **确定性 + 可测**：所有 band 取中点；GUT 用例覆盖——灼烧施加 / 层数封顶 / 水克火压制 / 木克增益 / 到期清层 / 与连携不双 dip（同场既有连携又有灼烧，断言 DoT 不受 `_bond_bonus` 影响）。

> 注：B-1 与 B-3 共用 `skill_defs.json` 与「选技读取技能定义」路径，建议 eng 一并实现（见 §4.5）。

### 2.6 其余觉醒类型（共用状态系统，供扩展）

为兑现 P3 多样性，青龙/白虎/幽冥 觉醒各给一个改写机制（数据驱动，同一 `StatusManager`）：
- **青龙（金）· 破甲（armor_break）**：叠层降低目标防御 → 后续直接伤害 ×(1 − stacks×5%)。
- **白虎（金）· 气势（momentum）**：每连续行动叠 1 层，每层直接伤害 +4%（自增益）。
- **幽冥（木）· 中毒（poison）**：类灼烧的 DoT（木主题），克制金行目标增效、被火行压制。
S3 至少落地**灼烧（B-1 必需）+ 破甲**两项；中毒/气势可作 S3 收尾或核心层。

---

## 3. B-2 设计定稿 · `bond:combo` 实战发射接线

### 3.1 事实取证（S2 根因）

- `EventBus.bond_combo(group_id, bonus_pct)` 信号已定义（`EventBus.gd:65`）。
- `BondManager.compute_combo(deck)` 已实现：取最优连携组中点、emit `bond_combo`、返回 bonus（`BondManager.gd:27-51`）。
- `BattleManager._on_bond_combo` 已订阅并写入 `_bond_bonus`（`BattleManager.gd:32,35-36`）；`step()` 中玩家伤害乘 `(1+_bond_bonus)`（`:184-185`）。
- **断点**：grep 全仓 `compute_combo` 仅定义 + 测试调用，**生产代码零 caller** → 实战 `_bond_bonus` 恒 0。
- **时序陷阱**：`start_battle` 在第 49 行把 `_bond_bonus = 0.0`，故发射**必须在 `start_battle` 之后**。

### 3.2 发射节点与事件接线方案（守住零跨 import 红线）

**红线重申**（`architecture §1.3 / s2-design-review §3.3`）：管理器（manager）仅经 `EventBus` / `GameState` / `ConfigLoader` / 其他全局 autoload **名**（非 `preload`/`import`）交互；`BattleManager` **不得** import `BondManager`（E4-S3 AC2 硬约束，零 preload grep 须保持）。

**方案（推荐 · 场景协调器发射）**：由 **E5 战斗启动场景/协调器**（如 `res://scenes/battle/BattleScreen.gd`，属场景脚本而非 autoload manager）在确认出战后编排顺序调用——这是「允许调用 BondManager」的协调者，不违反「manager 仅经 EventBus 解耦」（场景不是 manager）。

```gdscript
# res://scenes/battle/BattleScreen.gd（场景脚本，非 autoload manager）
func _on_confirm_battle(chapter: int, stage: int) -> void:
    if not BattleManager.start_battle(chapter, stage):
        return  # 关卡缺失/编队空 等失败处理
    # ★ 必须在 start_battle 之后调用，否则 _bond_bonus 被重置为 0
    BondManager.compute_combo(GameState.deck)   # emit bond_combo -> BattleManager._on_bond_combo
    # 此后 step() 中玩家伤害已含连携加成；横幅由 UI 监听 bond_combo 渲染
```

**为何不放在 `BattleManager` 内部**：若 `BattleManager` 直接调 `BondManager.compute_combo`，即便以全局名（非 preload）调用，也会在语义上让「消费方」反向依赖「提供方」，削弱 E4-S3 AC2 的解耦示范，且使零 preload grep 的「无 BondManager 引用」承诺变弱。故**发射责任外置到场景协调器**最干净。

**EventBus 契约补注（建议写进 `EventBus.gd` 注释）**：
```
# bond:combo — 由战斗启动协调器（场景）在 BattleManager.start_battle 之后
# 调用 BondManager.compute_combo(deck) 发射；BattleManager 仅订阅不发射（E4-S3 AC2）。
```

**UI 横幅接线**：战斗 HUD 监听 `EventBus.bond_combo(group_id, bonus_pct)` 渲染连携横幅（锚点5 五行符文阵意象，ux-spec §2.6）；与战斗逻辑解耦。

### 3.3 边界与鲁棒性

- 编队无连携组（如单人/混编无 ≥2 同组）→ `compute_combo` 返回 0.0 且不 emit → `_bond_bonus` 保持 0.0 → 无加成、无报错、无横幅。✓
- `GameState.deck` 含法宝 id（非式神）→ `compute_combo._ids` 仅抽取式神 id（且法宝 id 不在任何 group）→ 不影响判定。✓
- 时序：任何在 `start_battle` **之前**误调 `compute_combo` 都会被第 49 行清零 → 表现为「连携恒 0」静默 bug；故**顺序契约须写进 S3 DoD 与代码注释**。

### 3.4 给 engineering-lead 的 AC（B-2）

1. E5 战斗场景确认出战逻辑按 §3.2 顺序：`start_battle` → `BondManager.compute_combo(GameState.deck)`。
2. **不改 `BattleManager` 对 `BondManager` 的零引用**（守住 E4-S3 AC2 与零 preload grep）。
3. 战斗 HUD 监听 `bond_combo` 渲染横幅；横幅数值 = `bonus_pct`（如 0.175）。
4. **GUT 修正**：`test_battle_flow` 在 `start_battle` 后补 `BondManager.compute_combo(GameState.deck)`；新增断言——剑宗 4 人队 `_bond_bonus > 0`（≈0.175）、单人队 `_bond_bonus == 0.0`。
5. `EventBus.gd` 注释补「战斗启动方负责发射」契约。

---

## 4. B-3 设计定稿 · 玩家选技（UI / 交互 / 规则）

### 4.1 何时选、选几个

- **时机**：每个**玩家单位行动**时（按行动条 atk 降序轮到该单位），弹出该单位的**主动技选项**；选定后再选**目标**（敌方单体；仅 1 敌时自动）。
- **选几个**：每个单位主动技 = `基础技`（恒有）+ `觉醒技`（若已觉醒，即 `awakened_skills` 非空）。即每回合 **1–2 个主动选项**；玩家选 1 个使用。
- **分支被动不进选技**：`branches.sword/body` 的被动（如 `jian_xiu_passive`）为**被动自动生效**（如常驻增伤/减伤），不占选技槽，避免认知过载（红线之一）。

### 4.2 与养成 / 觉醒 / 分支的关系

| 来源 | 在选技中的角色 | 备注 |
|---|---|---|
| 养成·基础技（`shikigami_defs.skills[0]`） | 默认主动技（element=式神本行，power=1.0） | 始终可用 |
| 养成·觉醒技（`awakened_skills`，bt≥3 觉醒） | 额外主动技（带 `status_on_hit` 改写机制） | 见 B-1；是 P2 质变与 P3 策略核心 |
| 分支·剑修/体修（`branches.passive`） | **被动**，不入选项 | 自动生效（如剑修 +X% 直接伤 / 体修 +Y% 最大HP） |

> 设计逻辑：选技表达「**这一击用哪招**」，分支表达「**这个式神是谁**」（长期 build），二者正交——自主感（SDT）来自分支的 build 选择，胜任感来自选技的临场表达。

### 4.3 是否影响五行倍率

- 技能携带自身 `element`（取自 `skill_defs`）。**默认基础技 element = 式神本行**；觉醒技 element 由 `skill_defs` 定义（如朱雀觉醒技 = 火）。
- 五行倍率（克制 ×1.25–1.35 / 被克 ×0.7–0.8 / 相生 ×1.02–1.05）**由「技能 element」对「目标 element」** 计算（沿用 `BattleResolver.resolve_damage`），不再仅用单位本行。
- **策略含义**：玩家可通过「选不同 element 的觉醒技」主动制造/规避克制 → P3 构筑随心在战斗内兑现（S2 仅单位本行，无此维度）。

### 4.4 「气（qi）」资源门控（推荐项，强化策略）

为避免「觉醒技无脑每回合放」导致策略坍缩，推荐引入轻量 **气（qi）** 资源：
- 每单位 `qi_max = 3`，每回合 +1（上限 3）；基础技耗 0，觉醒技耗 1。
- 效果：玩家须**择时**放觉醒技（攒气放大招），制造节奏与取舍 → 增强 P3 表达。
- **范围弹性**：若 S3 时间紧，可降级为「觉醒技无消耗、回合冷却 1」或直接「始终可用」；但**推荐保留 qi 门控**以兑现「策略表达」。本定稿将 qi 门控列为**推荐 AC**，由 eng 按 S3 工时拍板。

### 4.5 给 engineering-lead 的 AC（B-3）

1. `BattleManager.step()` 由「自动首活目标 + 硬编码 power」改为**接收玩家输入**（技能 id + 目标 id），经 UI/测试驱动。
2. 主动技列表由 `get_final_unit` 的 `skills` 解析为 `基础技 + 觉醒技`（过滤掉被动 passive 串）。
3. 技能 `power` 与 `element` **从 `skill_defs.json` 读取**（废除 1.0 硬编码）；五行倍率用技能 element 计算。
4. 目标选择：玩家指定敌方单位（多敌时必选；单敌自动）。
5. **（推荐）** 实现 `qi` 资源：每单位 `qi_max=3`、回合 +1、觉醒技耗 1；UI 显示气槽。
6. 分支被动（`jian_xiu_passive` / `ti_xiu_passive`）作为**被动**在伤害/属性结算中自动应用，不入选技。
7. **GUT**：`test_battle_flow` 改造为「给定技能/目标」驱动；断言——选克制 element 技能伤害更高、觉醒技触发 `status_on_hit`、被动入算。

> B-1 与 B-3 共用 `skill_defs.json` 与「选技读技能定义」路径，强烈建议 eng 在 S3 同一 Story 内一并实现（避免两次改动 `step()`）。

---

## 5. 式神资产补齐设计配合（8 → 12）

### 5.1 现状与约束

- `shikigami_defs.json` 当前 **13 张**：N3（草隶/山童/火灵）、R4（铁甲/青羽/虬龙/虎威）、SR3（幽冥/玄风/朱雀 SR）、SSR3（青龙/白虎/朱雀 SSR）。
- R3 定稿：**13 = N3 / R4 / SR3 / SSR3**（朱雀确认为火 SSR，原 SSR2 锁放宽），允许 10–15 浮动。
- 须补：**N+1 / R+2 / SR+1 = 4 张**。
- 羁绊组（任务指定 5 组）：`jian_zong / tie_bi / yu_zu / long_zu / hu_zu`。当前 `bond_combos.json` **仅定义 jian_zong、tie_bi**；`yu_zu/long_zu/hu_zu` 仅在式神 `bond_tags` 中被引用但**无 combo 组、且各仅 1 名成员**（青羽→yu_zu；青龙→long_zu；白虎→hu_zu）→ 这 3 组**永远不触发连携**。

### 5.2 分布不破坏卡框 / 羁绊完整性的设计原则

- 5 张新卡须让 **5 个羁绊组各 ≥2 名成员**（否则空组）；R3 已含 **SSR3（青龙/白虎/朱雀）**，朱雀为火行承载灼烧（S2 数据与测试依赖仅锁定青龙/白虎存在，不排斥新增火 SSR 朱雀）。
- 同时解决隐藏缺口：**当前玩家侧无火行**（8 张元素为 金/木/土/水，无火）→ 概念文档「火系觉醒灼烧」无归属。新增须补**至少 1 张火行**承载灼烧。

### 5.3 推荐新增 4 式神与羁绊归属

| 新增 id | 名称 | 稀有度 | 元素 | bond_tags | 补全的组 | 备注 |
|---|---|---|---|---|---|---|
| `sr_zhu_que` | 朱雀 | **SR** | **火** | `[yu_zu]` | **yu_zu**（青羽+朱雀=2） | **灼烧归属**（火觉醒 → burn）；同时补玩家侧火行（朱雀另有火 SSR 形态 `ssr_zhu_que`，主理人确认） |
| `r_qiu_long` | 虬龙 | **R** | 水 | `[long_zu]` | **long_zu**（青龙+虬龙=2） | 龙族二线 |
| `r_hu_wei` | 虎威 | **R** | 金 | `[hu_zu]` | **hu_zu**（白虎+虎威=2） | 虎族二线 |
| `n_huo_ling` | 火灵 | **N** | **火** | `[]` | —（独行，类草隶） | 低稀有度也可体验火行；早期灼烧教学 |

**补齐后 12 张总览**

| 稀有度 | 数量 | 式神（元素 / 羁绊组） |
|---|---|---|
| SSR | 3 | 青龙（金 / jian_zong+long_zu）、白虎（金 / jian_zong+hu_zu）、**朱雀（火 / yu_zu）** |
| SR | 3 | 幽冥（木 / jian_zong）、玄风（木 / jian_zong）、**朱雀（火 / yu_zu，SR 形态）** |
| R | 4 | 铁甲（土 / tie_bi）、青羽（水 / yu_zu）、**虬龙（水 / long_zu）**、**虎威（金 / hu_zu）** |
| N | 3 | 草隶（木 / —）、山童（土 / tie_bi）、**火灵（火 / —）** |

**5 个羁绊组最终成员**

| 组 | 成员（≥2 触发） | combo 定义状态 |
|---|---|---|
| jian_zong 剑宗 | 青龙、白虎、幽冥、玄风（4） | 已定义 |
| tie_bi 铁壁 | 铁甲、山童（2） | 已定义 |
| **yu_zu 羽族** | 青羽、朱雀（2） | **S3 新增定义** |
| **long_zu 龙族** | 青龙、虬龙（2） | **S3 新增定义** |
| **hu_zu 虎族** | 白虎、虎威（2） | **S3 新增定义** |

> 元素覆盖：玩家侧现有 **金/木/土/水/火 五行齐全**（火由朱雀+火灵补）→ B4「前 3 章铺不同五行敌人做教学」的克制闭环在玩家侧有对应 counter；且灼烧机制（火）有归属。

**设计决策（已拍板）**：主理人确认**朱雀为火 SSR（`ssr_zhu_que`）**。原方案「灼烧归属火 SR 朱雀、R3 锁 SSR2」被取代——现 R3 放宽至 **SSR3（青龙/白虎/朱雀）**，`ssr_zhu_que` 已补建，灼烧机制归属火 SSR 朱雀完整交付，且不破坏 S2 数据与测试（青龙/白虎仍在）。

### 5.4 须同步改的数据 / 资产（交给 art-director + engineering-lead）

- **`data/bond/bond_combos.json`**：新增 `yu_zu / long_zu / hu_zu` 三组，band 同既有（`combo_2_min/max=0.08/0.12`、`combo_3plus_min/max=0.15/0.20`）；成员名单如上。
- **`data/shikigami/shikigami_defs.json`**：新增 4 条（base_stats 按 `02a §B2④` 稀有度基线：SR 110–135 / R 85–105 / N 60–80 ATK；技能指向 `skill_defs`）。
- **`cultivation_config.awaken.skills_by_shikigami`**：扩充觉醒技映射——朱雀→`skill_zhu_que_awakened`（burn）、青龙→破甲、白虎→气势、幽冥→中毒（其余 N/R 不觉醒）。
- **`skill_defs.json`**：12 张式神的全部基础技 + 4 个觉醒技（§2.4）。
- **art-director 交付**：4 张新立绘三视图（E5 图鉴 12 立绘需求，`asset-spec §1.2`）；灼烧/破甲/中毒/气势 **状态 VFX**（图标 + 形状冗余，不靠色，art-bible §8）；连携横幅（锚点5）；火行五行形状/配色（朱雀/火灵）；气槽 UI 控件。

---

## 6. S3 设计评审结论与前置交付清单

### 6.1 总体结论

**PASS（设计定稿就绪，1 项待主理人拍板：灼烧归属火 SR，§5.3）**

S3 三大 S2 遗留缺口（B-1/B-2/B-3）与式神资产补齐（8→13）均已给出**完整、数据驱动、可实现**的设计定稿；红线（R1–R5 / 支柱）经自检无违反；E5 Demo 的「好玩」维度已落到可量化 Playtest 口径。设计侧**不再阻塞 S3 开工**。

### 6.2 对 engineering-lead 的前置交付要求清单

| 项 | 交付物 | 阻塞级 | 关联缺口 |
|---|---|---|---|
| E1 | `data/battle/skill_defs.json`（12 基础技 + 4 觉醒技，含 `power`/`element`/`status_on_hit`） | 阻塞 | B-1/B-3 |
| E2 | `StatusManager`（或 `BattleResolver`+`BattleManager` 状态字段）+ `status_config`（burn/poison/armor_break/momentum 规则） | 阻塞 | B-1 |
| E3 | `BattleManager.step()` 改为「读 skill_defs power/element + 施加 status_on_hit + tick DoT + 接收玩家选技/目标」；废除 power=1.0 硬编码 | 阻塞 | B-1/B-3 |
| E4 | E5 战斗场景确认出战按序 `start_battle` → `BondManager.compute_combo(GameState.deck)`；`BattleManager` 保持零 BondManager 引用 | 阻塞 | B-2 |
| E5 | 战斗 HUD 监听 `bond_combo` 渲染横幅；选技 UI（技能/目标选择，≥44px 热区） | 阻塞 | B-2/B-3 |
| E6 | （推荐）`qi` 资源：每单位 `qi_max=3`、回合+1、觉醒技耗1、UI 气槽 | 推荐 | B-3 |
| E7 | `data/bond/bond_combos.json` 新增 `yu_zu/long_zu/hu_zu` 三组；`shikigami_defs.json` 新增 4 式神；`cultivation_config.awaken.skills_by_shikigami` 扩充 | 阻塞（资产补齐） | §5 |
| E8 | GUT 修正/新增：B-2（`compute_combo` 后 `_bond_bonus>0` 断言）、B-1（灼烧施加/封顶/水克火/木增益/与连携不双 dip）、B-3（选技驱动、被动入算） | 阻塞 | B-1/B-2/B-3 |
| E9 | R1 收口：消耗点（抽卡/养成）资源不足时接 `economy:currency_changed` 渲染「去哪产出」引导（phase4-def §2 R1 遗留） | 阻塞（UX 闭环） | §1.3 |
| E10 | `EventBus.gd` 注释补「bond:combo 由战斗启动协调器在 start_battle 后发射」契约 | 非阻塞 | B-2 |

### 6.3 对 art-director 的前置交付要求清单

| 项 | 交付物 | 阻塞级 | 关联 |
|---|---|---|---|
| A1 | 4 张新立绘三视图（朱雀/虬龙/虎威/火灵），套用既有 R/SR/SSR/N 卡框（art-bible §5 双态） | 阻塞（E5 图鉴 12） | §5.4 |
| A2 | 状态 VFX：灼烧/破甲/中毒/气势 图标（**形状+图标+数字三重**，不靠色，art-bible §8） | 阻塞 | B-1 |
| A3 | 连携横幅（锚点5 五行符文阵意象） | 阻塞 | B-2 |
| A4 | 火行五行形状/配色（朱雀/火灵）；气槽 UI 控件（tabular、≥44px） | 阻塞 | B-1/B-3 |
| A5 | 锚点6（天象裂隙/Boss 3D 演出钩子，phase4-def R2）出图（如 S3 排期） | 非阻塞 | phase4 |

### 6.4 设计红线自检（R1–R5 / 支柱）

- **主导策略 R5**：五行网状克制 + 相生 + 连携 + 选技 + 状态系统多维并存；**水克火压制灼烧**、状态 DoT 与连携加成**正交不双 dip** → 无单卡/单组/单状态通吃。✓
- **经济失衡 R1**：B-1/B-3 仅改战斗表现，不改经济产出/消耗；觉醒石仅 Boss 跨系统一致保持。✓
- **认知过载**：每单位主动技 ≤2（基础+觉醒）、分支被动自动生效不占选技、状态图标三重冗余 → 界面信息密度受控。✓
- **支柱漂移**：P1（抽养一体：出货序章+养成可见质变）✓；P2（御剑修真：突破飞升+觉醒机制改写可见）✓（B-1 补回后）；P3（构筑随心：编队连携预览+战中选技+五行倍率即时反馈）✓（B-2/B-3 补回后）。无漂移。✓

### 6.5 待主理人/用户拍板项

1. **（已采纳）灼烧归属火系 SSR 朱雀（`ssr_zhu_que`）** —— 主理人确认朱雀为火 SSR，R3 由原 SSR2 锁放宽至 SSR3。见 §5.3。
2. **（建议采纳推荐项）B-3 引入 `qi` 气资源门控**觉醒技，以增强策略表达；若 S3 工时紧可降级为无消耗/冷却。
3. **式神资产补齐 5 张归属**（§5.3）已批准——朱雀确认为火 SSR（`ssr_zhu_que`，另保留 SR 朱雀 `sr_zhu_que`）、虬龙/虎威为 R 补全龙/虎族、火灵为 N 补火行；R3 分布更新为 N3/R4/SR3/SSR3。

---

## 附：关键接口速查（供 eng 落地）

| 信号/方法 | 位置 | S3 用途 |
|---|---|---|
| `EventBus.bond_combo(group_id, bonus_pct)` | `EventBus.gd:65` | B-2 发射；HUD 横幅监听 |
| `BondManager.compute_combo(deck)` | `BondManager.gd:27` | B-2 由战斗场景在 start_battle 后调用 |
| `BattleManager.start_battle(ch, st)` | `BattleManager.gd:46` | **须在 compute_combo 之前**（第49行清零 _bond_bonus） |
| `BattleManager._on_bond_combo` | `BattleManager.gd:35` | 写入 `_bond_bonus`（消费端，零 BondManager 引用） |
| `CultivationManager.get_final_unit(id)` | `CultivationManager.gd:132` | 产出 `skills`（基础+觉醒+分支被动），供选技解析 |
| `GameState.deck` | `GameState.gd:15` | 4 式神 id + 1 法宝 id，compute_combo 入参 |
| 新增 `data/battle/skill_defs.json` | — | B-1/B-3 技能定义（power/element/status_on_hit） |
| 新增 `StatusManager` | — | B-1 状态系统（burn/poison/armor_break/momentum） |

---

【一句话汇报（主理人）】S3 设计评审 **PASS（定稿就绪，1 项待拍板）**：S2 三缺口 B-1（灼烧叠层：层数上限3/DoT=层数×3%×目标最大HP/水克火压制+木克增益/与连携正交）/B-2（战斗场景在 start_battle 后调 BondManager.compute_combo，零跨 import 红线守住）/B-3（每单位基础+觉醒 1–2 主动技、选目标、技能 element 决定五行倍率、推荐 qi 门控）均已给出可落地 AC；式神 8→13 以「朱雀(SR火/yu_zu)+虬龙(R/long_zu)+虎威(R/hu_zu)+火灵(N火)」补全 5 羁绊组并补玩家侧火行（灼烧归属），E5 Demo 的 MDA 动态/心流/三支柱验收口径已量化；唯一待拍板为「灼烧归属火 SR 朱雀」（R3 锁 SSR2 为金行，概念文档火系 SSR 举例不可行）。
