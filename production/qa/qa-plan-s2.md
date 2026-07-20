# QA 计划 · Sprint S2（Phase 5 · 制作）

> 编制：质量负责人 严守真（quality-lead）
> 范围：Phase 5 Sprint S2 —— E3 养成系统（S1–S5）、E4 构筑+战斗（S1–S6）、E6-S4 云存档冲突（A5 收口）。
> 对齐：`docs/architecture/test-strategy.md`（T2/T6/T7/T3，GUT 脚手架与 CI 命令）、`production/epics/mvp-epics-stories.md`（E3/E4/E6-S4 的 AC 与 S2 的 DoD）、`production/qa/qa-plan-s1.md`（S1 遗留 C-3/C-4）、`production/s1-gate.md`（S1 门禁 PASS，C-3/C-4 为残留项）、`production/qa/s2-python-logic-smoke.py`（155/155 算法门禁）。
> 产出性质：纯文档。未修改任何 `.gd` / `project.godot`，未 `git commit`，未下载 GUT。所有 `.gd` 仅做静态核对（Read 核验），结论基于磁盘实读。

---

## 0. 质量门基准（S2 的 DoD，来自 mvp-epics-stories.md §Sprint S2）

1. 养成最终式神接口单测通过（E3-S5 ↔ E4 读取一致）—— **T7**。
2. 五行克制结算单测通过（×1.25–1.35 / ×0.7–0.8，假表注入）—— **T2**。
3. 羁绊连携经 `bond:combo` 事件（无跨 import）单测通过—— **T6**。
4. 推图回流闭环跑通，单场 2–4min—— **E4-S5**。
5. 云存档冲突解决单测通过（last-write + cache 回滚 + delta<50KB）—— **E6-S4**。

> S2 实交付 7 个 GUT 测试：`test_cultivation`(T7/E3) / `test_battle_element`(T2/E4-S2) / `test_bond`(T6/E4-S3) / `test_battle_flow`(E4-S4/S5) / `test_deck_builder`(E4-S1) / `test_battle_ui_constants`(E4-S6) / `test_cloud_conflict_wrapper`(E6-S4)。
> **缓解信号**：因沙箱无 Godot/GUT（C-3 延续），主理人已用 Python 移植证明 S2 最高风险纯逻辑 **155/155 PASS**（T2/T6/T7/E4-S5/E6-S4/E4-S6/数据一致性），作为 GUT 全量跑之前的轻量门禁。本计划第 1 节逐 AC 标注哪些已被该 Python 门禁间接验证。

---

## 1. S2 测试覆盖矩阵

**图例**：✅ 覆盖（有断言）｜⚠️ 部分（逻辑覆盖但机制/UI 未全）｜❌ 缺失（无测试，多为 UI/真机，留 S3）｜🔶 预期部分通过（实现未完，测试当前仅验已落地部分）

### 1.1 E3 养成系统（B3）

| Story / AC | GUT 测试 · 用例 | 关键断言（精确） | GUT | Python 间接 | 备注 |
|---|---|---|---|---|---|
| **E3-S1 AC1** 耗 ling_qi 升级，HP/ATK 线性 +2~3%/级 | `test_cultivation.gd::test_upgrade_linear_gain` / `test_upgrade_multi_level_linear` | 1级 atk 82(+2.5%)、hp 205；10级 atk 100、hp 250 | ✅ | ✅ T7 | 中点确定性 |
| **E3-S1 AC2** 等级上限随突破阶；超阶拦截 | `test_cultivation.gd::test_level_cap_scales_and_overcap_blocked` | bt0→Lv20、bt1→Lv36；顶 Lv36 升级被拒、level 不变 | ✅ | ✅ T7 | — |
| **E3-S2 AC1** 1→6 阶，每阶全属性 +8~12%，被动槽，耗 po_dan+碎片 | `test_cultivation.gd::test_breakthrough_attr_gain_and_passive_slots` / `test_breakthrough_resource_blocked` | bt1 atk 88(+10%)、hp 220、被动槽 2；碎片不足拦截 | ✅ | ✅ T7 | — |
| **E3-S2 AC2** 突破后 GameState.breakthrough 与被动槽数更新 | `test_cultivation.gd::test_breakthrough_attr_gain_and_passive_slots` | `GameState.shikigami[0]["breakthrough"]==1`、`passive_slots==2` | ✅ | ✅ T7 | — |
| **E3-S3 AC1** 达阶门槛觉醒主动技，标记 `awakened_skills[]` | `test_cultivation.gd::test_awaken_skill` | bt3 觉醒成功、含 `skill_*`；bt1 拒 | ✅ | ✅ T7(标记) | — |
| **E3-S3 AC2** 觉醒改写机制（火系 SSR「灼烧」可叠层）在 `BattleResolver` 生效 | （无） | 全工程 grep 无 `burn/灼烧/stack` 代码；`CultivationManager.awaken_skill` 仅标记技能 id | ❌ | ❌(仅标记) | **🔶 未实现，推迟 S3**；本 AC 当前"预期部分通过" |
| **E3-S4 AC1** 高阶突破选 剑修/体修，记录于式神数据 | `test_cultivation.gd::test_choose_branch` | bt3 选剑修成功、`branch` 记录；bt1 拒 | ✅ | ✅ T7 | — |
| **E3-S4 AC2** 两方向赋予不同被动，战斗结算生效（经数据读取） | `test_cultivation.gd::test_get_final_unit_aggregation` | `skills` 含 `jian_xiu_passive`（剑修被动） | ✅(数据级) | ✅ T7 | 被动已读入最终式神；但 `BattleManager` 不将 `skills[]` 做成战斗效果（无技能结算引擎），"生效"待 S3/E5 接线 |
| **E3-S5 AC1** `get_final_unit` 聚合 final_stats/skills/element/bond_tags/breakthrough | `test_cultivation.gd::test_get_final_unit_aggregation` | element/bond_tags/breakthrough/final_stats/skills 全聚合 | ✅ | ✅ T7 | — |
| **E3-S5 AC2** B4 读取该接口返回正确最终属性（E4 验收前置） | `test_cultivation.gd::test_final_unit_feeds_battle_resolver` | `get_final_unit`→`BattleResolver`，metal 克 wood，伤害落入 [150,162] | ✅ | ✅ T7 | B4 读取一致已证 |

### 1.2 E4 构筑 + 战斗（B4）

| Story / AC | GUT 测试 · 用例 | 关键断言（精确） | GUT | Python 间接 | 备注 |
|---|---|---|---|---|---|
| **E4-S1 AC1** 编队 4 式神 + 1 法宝位，超出规模拦截，写入 `GameState.deck` | `test_deck_builder.gd`（5 用例） | 4+1 写入 deck；5 式神拦截；满 4 第 5 拦截；法宝位；移除 | ✅ | ❌ | headless 逻辑；GUT 未含双端 |
| **E4-S1 AC2** 双端点选/拖拽经 `InputBridge`；移动端网格热区 ≥44×44 | （无） | 无 `InputBridge` 测试；`test_deck_builder` 仅逻辑 | ❌ 缺失(UI) | ❌ | **留 S3 双端验证** |
| **E4-S2 AC1** 五行相克 + 相生；克制 ×[1.25,1.35]、被克 ×[0.7,0.8] | `test_battle_element.gd`（5 用例） | 关系判定；克制 [125,135]；被克 [70,80]；相生 [102,105]>0；中立=base；多 seed 在 band | ✅ | ✅ T2 | — |
| **E4-S2 AC2** `resolve_damage` 单元测；克制命中 emit `battle:element_advantage` | `test_battle_element.gd` + `test_battle_flow.gd::test_element_advantage_emitted_on_advantage_hit` | 纯计算可独立测；克制 emit 倍率 [1.25,1.35] | ✅ | ✅ T2/T6 | 性能（GDExtension 触发线 <4ms）未断言 |
| **E4-S3 AC1** 2 式神 +8~12% / 3+ +15~20%（静态表驱动） | `test_bond.gd`（3 用例） | 2人 [8,12]%、3+ [15,20]%、单人/空无连携 | ✅ | ✅ T6 | — |
| **E4-S3 AC2** B4 经 `bond:combo` 事件取加成，**不 import** `BondManager`；触发 emit 横幅 | `test_bond.gd::test_battle_manager_gets_bonus_via_event` | `BattleManager` 经事件获加成（与事件一致）；emit `bond:combo` | ✅(逻辑) | ✅ T6 | "不 import" 为静态保证（grep 零 preload，`BattleManager.gd` 已确认）；横幅 UI 未测 |
| **E4-S4 AC1** 行动条/能量 + 玩家选技；一回合流程跑通 | `test_battle_flow.gd::test_one_turn_runs_without_crash` | 开局成功、返回回合摘要、杂兵被秒即分胜负 | ✅(流程) | ✅ E4-S5 | **"玩家选技"未实现**（自动选 element）；选技 UI 留 S3/E5 |
| **E4-S4 AC2** 克制命中 emit `battle:element_advantage` +「克制！」浮字（图标+数字+颜色三重） | `test_battle_flow.gd::test_element_advantage_emitted_on_advantage_hit` | emit 倍率 [1.25,1.35]、攻击方/目标正确 | ✅(emit) | ✅ E4-S5 | 「克制！」浮字 UI 未测 |
| **E4-S5 AC1** 前 3 章每章 8–10 关 +1 Boss；关卡推进 `GameState.progression` | `test_battle_flow.gd::test_clear_chapter_advances_progression_and_refunds` | `stages_cleared+1`、`chapters_cleared+1`（仅 Boss 关） | ✅(逻辑) | ✅ E4-S5 + DATA | **真实 chapters 3×9 结构仅 Python `DATA_INTEGRITY` 验证**（GUT 用假 1 章 2 关） |
| **E4-S5 AC2** 通关 emit `reward_dropped`→回流符箓(1–3)/丹/石；单场 2–4min | `test_battle_flow.gd::test_clear_chapter_advances_progression_and_refunds` | 余额 fu_lu/po_dan/jue_xing_shi 增加；事件含实际数量 | ✅(回流) | ✅ E4-S5 + DATA | "单场 2–4min" 时长未测（性能，需真场景） |
| **E4-S6 AC1** 移动端 HUD 仅留关键数值；五行「图标+形状冗余」 | `test_battle_ui_constants.gd`（注**假表**）+ Python `E4_S6_suite` | 形状枚举可达；`hotzone_min_px≥44`；`shape_redundancy` 开启；**真实文件经 Python 校验** | ✅(常量/API) | ✅ E4-S6(真文件) | GUT 注假表不读真文件；HUD 布局未测 |
| **E4-S6 AC2** 技能按钮热区 ≥44×44；形状冗余图标渲染（Basic E） | `test_battle_ui_constants.gd` + Python | 热区最小 44px；形状冗余开关 | ✅(常量) | ✅ E4-S6 | 按钮实际 hitbox + 形状渲染 UI 未测 |

### 1.3 E6-S4 云存档冲突解决（ADR-002）

| Story / AC | GUT 测试 · 用例 | 关键断言（精确） | GUT | Python 间接 | 备注 |
|---|---|---|---|---|---|
| **E6-S4 AC1** 版本化 + last-write（version+ts 高者胜）；覆盖前写 cache 副本可回滚 | `test_cloud_conflict_wrapper.gd`（5 用例） | push→pull 一致；版本优先 ts；cache 副本存在 | ✅ | ✅ E6-S4 | 覆盖 `CloudSaveService` **内存** `_cache` |
| **E6-S4 AC2** 注入冲突：本地 ts<云取云 / 本地 ts>云取本地；cache 存在可回滚 | `test_cloud_conflict_wrapper.gd` | 云新取云、`_cache` 留本地；本地新取本地 | ✅ | ✅ E6-S4 | — |
| **E6-S4 AC3** delta<50KB；同步延迟 mock<2s；离线优先不阻塞 | `test_cloud_conflict_wrapper.gd` | 普通 <50KB；mock 延迟 200ms<2s；`is_online()` 永真 | ✅ | ✅ E6-S4 | — |

> ⚠️ **E6-S4 与 S1-C4 的边界澄清**：本 S2 云测试覆盖的是 `CloudSaveService._cache`（**内存**副本）。S1-C4 缺口的「**文件级 cache 回滚**（`SaveManager.read_from_file()` → 损坏时回退磁盘 `_cache`）」**仍未被任何用例覆盖**——这是两个不同的 cache。故 S1-C4 在该维度上**延续未闭环**（见 §3）。

### 1.4 三态汇总

| 测试目标 | 状态 | 关键缺口 |
|---|---|---|
| T7 养成最终式神（E3 全 5） | ✅ 覆盖 | E3-S3 AC2 灼烧叠层未实现（🔶预期部分通过）；E3-S4 AC2 被动无战斗效果引擎 |
| T2 五行克制（E4-S2） | ✅ 覆盖 | 性能触发线未断言 |
| T6 羁绊连携（E4-S3） | ✅ 覆盖（逻辑） | 横幅 UI 未测；"不 import" 靠静态保证 |
| E4-S1 卡组构筑 | ✅ 覆盖（逻辑） | AC2 双端/热区 UI 缺失 |
| E4-S4 回合流程 | ✅ 覆盖（流程） | 玩家选技 UI 缺失；浮字 UI 缺失 |
| E4-S5 推图回流 | ✅ 覆盖（逻辑） | 真实 3×9 结构仅靠 Python；单场时长未测 |
| E4-S6 双端战斗适配 | ⚠️ 仅常量/API | HUD 布局 / 按钮 hitbox / 形状渲染 UI 全缺 |
| E6-S4 云冲突 | ✅ 覆盖（内存 cache） | 文件级 cache 回滚（S1-C4）仍缺 |

---

## 2. GUT 缺失的缓解 —— 本地全量运行清单（S2 待办）

> 阻塞根因（C-3 延续）：`addons/gut/` **不存在**（已 Glob 核验），本机亦无 `godot` 可执行。故以下 7 个 S2 GUT 测试**当前无法本地/CI 实跑**，质量门暂置 CONCERNS。以下为用户本地需执行的标准动作。

### 2.1 前置（Prerequisites）
1. **安装 Godot 4.3 LTS**：确认 `godot` 可在 PATH 或绝对路径调用（`godot --version`）。
2. **安装 GUT addon**：从 GUT 仓库取 Godot 4.x 兼容版，置于 `res://addons/gut/`；Project Settings → Plugins → 勾选启用。（当前缺失，须先补。）
3. **autoload 已就绪（无需改动）**：`project.godot` [autoload] 已注册 **14** 个单例（含 S2 新增 `CultivationManager`/`BondManager`/`DeckBuilder`/`BattleManager`），且 `ConfigLoader`（内存假表 inject/reset）、`RNGWrapper`（`scripts/utils/rng.gd`，class_name 已就位）均在位。各 S2 测试已在 `before_each` 内 `ConfigLoader.inject(...)` 注入假表、`after_each` `reset()`，无需额外脚手架。
4. **不修改 .gd**：仅运行，不改工程配置。

### 2.2 工程可加载（先抓语法/注册错误）
```bash
godot --headless --path "F:/AI/仙侠卡牌项目" --check-only
```

### 2.3 GUT 全量运行（headless，CI 门禁）
```bash
godot --headless --path "F:/AI/仙侠卡牌项目" \
  --script res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests -gexit -glog=1
```
- `-gexit`：存在失败用例时非零退出，供门禁。
- 建议先单独跑 7 个 S2 文件确认编译/解析，再全量：
  `test_cultivation` → `test_battle_element` → `test_bond` → `test_battle_flow` → `test_deck_builder` → `test_battle_ui_constants` → `test_cloud_conflict_wrapper`（可借 `-gselect` 或按文件分别指定）。

### 2.4 回填要求
用户执行后，将 stdout 的通过/失败计数回填本计划 §1（GUT 列），并把结论同步至 `production/s1-gate.md` 风格的 S2 收尾文档。**在 GUT 就位前，任何"已通过"均属推断（仅 Python 155/155 为实跑证据）。**

---

## 3. 已知测试缺口（务必列出）

### 3.1 S1 遗留项延续影响评估
| 遗留项 | 状态 | 对 S2 的影响 |
|---|---|---|
| **C-3（GUT 未安装 + 无 godot）** | 🔴 仍开（已 Glob `addons/**` 无文件确认） | S2 全部 7 个 `test_*.gd` 无法本地/CI 实跑；Godot API 接线 / 信号树 / 场景加载 **零验证**。这是 S2 最高优先级阻塞。 |
| **C-4a 文件级 cache 回滚（SaveManager 磁盘 `_cache`）** | 🔴 仍开 | S2 `test_cloud_conflict_wrapper` 只测 `CloudSaveService` 内存 `_cache`，**未触及** SaveManager 文件回滚。E6-S4 逻辑虽绿，但"损坏档回退磁盘 cache"承诺在 S2 仍未验证。 |
| **C-4b 死配置字段（min_daily 等）** | 🟡 经济层（S1），不直接影响 S2 玩法逻辑 | 属配置约束缺口，建议 `ConfigLoader` 加 schema 校验或在 MVP v1 前清理。 |
| **C-4c 广播未断言（economy:reward_granted / gacha:shikigami_obtained）** | 🟡 低 | S2 测试也未补这两条广播断言，属同类遗留。 |
| **C-4d UIThemeController / InputBridge 无单测** | 🔴 直接影响 S2 | E4-S1 AC2、E4-S6 双端 UI 依赖这两者，当前零测试 → 与 §3.3 双端缺口同源。 |

### 3.2 E3-S3 AC2 部分实现（灼烧叠层机制未实现，推迟 S3）
- 现状：`CultivationManager.awaken_skill` 仅标记 `awakened_skills[]`；全工程 grep 无 `burn/灼烧/stack` 实现；`BattleResolver` 只做五行倍率，不含状态叠层。
- 影响：`test_cultivation.gd` 只验 AC1（标记）。**AC2 当前"预期部分通过"**，对应测试在 S3 叠层机制落地后需补"灼烧可叠层、伤害随层数增长"的断言。
- 处置：与主理人确认 S3 排期；本 QA 将其标记为 🔶，不计入 S2 失败，但记入 S3 测试待办（§6）。

### 3.3 双端适配（E4-S6）仅有常量，无真实 UI 场景
- `test_battle_ui_constants.gd` 注入**假表**，仅断言 `ElementShapeMap` 的 API（形状枚举、`hotzone_min_px≥44`、`shape_redundancy`）；真实 `battle_ui_constants.json` 仅由 Python `E4_S6_suite` 做结构校验。
- **完全缺失**：移动端 HUD 布局（仅留关键数值）、分辨率断点（≥1024 / <768）不破版、技能按钮真实 hitbox ≥44×44、形状冗余图标的实际渲染（灰阶可辨）。这些都需 `tests/integration/` 场景用例 + 真机（test-strategy §1.6 已规划，留 S3）。
- E4-S1 AC2（双端点选/拖拽、`InputBridge`）、E4-S4 选技 UI /「克制！」浮字 UI 同理缺失。

### 3.4 真实数据表结构仅由 Python 门禁间接验证
- 7 个 GUT 测试**全部注入假表**（`_fake_*`），不读真实 `data/*`。真实 `chapters.json`（3×9、Boss 奖励）、`battle_ui_constants.json`、`bond_combos.json`（成员存在性）、`cultivation_config.json`、`element_matrix.json` 的结构正确性**仅由 Python `DATA_INTEGRITY_suite`（155/155 之一部）保证**。
- 风险：若某 GUT 假表与真实表 drift（如未来策划改 `combo_2_max`），GUT 不会报警。建议至少补 1 条「读真实 `data/*` 的结构一致性用例」纳入 GUT（或在 S3 集成测试里覆盖）。

### 3.5 Bug 台账缺失
- `production/qa/bugs/` 当前为空（已 Glob 核验）。建议将 §3.1–§3.4 的缺口登记为正式 Bug/Story 条目，便于 S3 跟踪。

---

## 4. S2 垂直切片手感 Playtest 计划

> 详细版见 `production/qa/s2-vertical-slice-playtest.md`（本节约等同于该文档核心，主文档自包含）。

**核心命题**：GUT/Python 只能证明"闭环**能跑通**"，不能证明"闭环**好玩**"。手感层必须在用户本地 Godot 实跑。

### 4.1 两层验证模型
- **Headless 逻辑层（已证）**：Python 155/155 已证明 养成聚合→最终式神→战斗结算→五行克制→羁绊→回流→云冲突 的通关闭环数学正确。**无需重跑**。
- **Hands-on 手感层（待跑）**：关注心流/反馈/张力，GUT headless 抓不到，需真机。

### 4.2 闭环入口场景
1. 新档起手：主菜单 →（抽卡 UI 若就位）→ 首次编队 → 第1章首关 → 结算回流。
2. 养成深度：单式神 升级×N → 突破×3 → 觉醒 → 分支(剑/体) → 再进同关对比战力。
3. 羁绊编队：组剑宗 4 人（青/白/幽/玄）→ 进战斗观察横幅与伤害加成。
4. Boss 张力：推到第1章 Boss（c1_boss 480hp / c1_boss_add 240hp）→ 观察血量/克制/时长。
5. 双端：PC 横屏 ≥1024 与 移动竖屏 <768 各跑一遍，对比布局/热区。

### 4.3 手感检查清单（6 维度）
1. **心流节奏**：单场 2–4min；操作无卡顿；奖励即时可见；无空窗死锁。
2. **克制反馈**：「克制！」浮字（图标+数字+颜色三重）清晰；克制(×1.25–1.35) vs 被克(×0.7–0.8) 伤害差可感知。
3. **羁绊横幅**：`bond:combo` 触发横幅出现；加成数值可辨；与编队一致。
4. **双端布局**：≥1024 多栏不破版；<768 单列/仅关键数值；技能按钮热区 ≥44×44 可点；形状冗余（圆/三角/方/菱/五边）灰阶可辨。
5. **数值成长爽感**：升级 +2.5%/级、突破 +10%/阶 在实战"可见"；觉醒/分支带来质变感。
6. **Boss 战张力**：Boss 血量/攻击有压力；克制/羁绊可扭转；通关回流（符箓/丹/石）有"收获"反馈。

### 4.4 观察指标（量化）
- 单关耗时（目标 2–4min）｜克制 vs 被克平均伤害差（预期 ≥25%）｜羁绊触发率与显示准确率｜双端断点无溢出/裁切｜热区点击命中率（移动 ≥44px）｜养成前后 DPS 提升 %｜回流到账视觉延迟（<0.5s）。

### 4.5 通过/不通过标准
- **PASS**：闭环完整走通（无崩溃/死锁）；6 维度均"可感知且正确"；双端不破版；单场时长在预算内。
- **CONCERNS**：可走通但某维度"不够爽"（成长感弱/反馈弱）→ 记设计调优，不阻塞。
- **FAIL**：任一环节崩溃/死锁/数值明显错（如克制反被克更高伤）/双端严重破版/时长严重超标。

---

## 5. S2 QA 门禁判定

# ⚠️ CONCERNS（建议性门禁，advisory）

**判定理由**：
- ✅ 实现 + 测试代码已就位且静态自洽（跨 import 解耦、autoload 注册完整、RNGWrapper/ConfigLoader 在位）。
- ✅ 最高风险纯逻辑经 Python 移植 **155/155 PASS**（T2/T6/T7/E4-S5/E6-S4/E4-S6/数据一致性），数学正确性已钉死。
- 🔴 但 **GUT addon 仍未安装（C-3 延续）** → 7 个 S2 GUT 测试**无法本地/CI 实跑**，Godot API 接线/信号树/场景加载**零验证**。
- 🔴 且存在**已知部分实现与 UI 缺口**（E3-S3 AC2 灼烧叠层未实现、双端/UI 适配全缺失、S1-C4 文件级 cache 回滚仍开）。

> 与 S1 门禁（PASS Conditional / CONCERNS）一致：实现与算法层已证，但"实跑验证"与"体验验证"未完成，最终放行由用户人工审批。

### 5.1 具体阻塞项（Blockers）
1. **B1 — GUT 未安装（C-3）**：`addons/gut/` 缺失，本机无 `godot`。所有 S2 `test_*.gd` 无法执行；无任何 Godot 运行时验证。→ **须用户本地装 Godot 4.3 + GUT 并按 §2 跑通**。
2. **B2 — E3-S3 AC2 灼烧叠层未实现**：觉醒仅标记技能，无叠层机制（推迟 S3）。当前测试"预期部分通过"，该 AC 在 S3 落地前不计完成。
3. **B3 — 双端/UI 适配零验证**：E4-S1 AC2、E4-S4 选技+浮字、E4-S6 HUD/热区/形状渲染 均无真实场景测试，全留 S3。
4. **B4 — S1-C4 文件级 cache 回滚仍缺**：E6-S4 的 S2 测试只覆盖 `CloudSaveService` 内存 `_cache`，未覆盖 `SaveManager.read_from_file` 磁盘回滚。
5. **B5 — 真实数据表仅 Python 间接验证**：GUT 全用假表，数据 drift 风险无 GUT 告警。

### 5.2 建议（不阻塞判定，但建议排期）
- [ ] 装 GUT + godot，跑 §2 命令，回填 §1 GUT 列。
- [ ] 建 `production/qa/bugs/`，登记 B2–B5 为正式条目。
- [ ] 补 1 条读真实 `data/*` 的 GUT 结构一致性用例（缓解 B5）。
- [ ] S3 落地 E3-S3 AC2 灼烧叠层并补断言（缓解 B2）。
- [ ] S3 双端验证覆盖 E4-S1/S4/S6 UI（缓解 B3）+ 补 `InputBridge`/`UIThemeController` 单测（闭环 C-4d）。
- [ ] 安排 `SaveManager` 文件级 cache 回滚集成用例（闭环 C-4a/B4）。

---

## 6. S3 测试待办（Backlog）

| 待办 | 对应缺口 | 优先级 |
|---|---|---|
| E3-S3 AC2 灼烧叠层机制实现 + 断言（可叠层、伤害随层增长） | B2 / §3.2 | P0（玩法诚实） |
| 双端验证：E4-S1 AC2 / E4-S4 选技+浮字 / E4-S6 HUD+热区+形状渲染（真机 + `tests/integration/`） | B3 / §3.3 | P0 |
| `InputBridge` / `UIThemeController` 单测（闭环 C-4d） | §3.1 | P1 |
| `SaveManager` 文件级 cache 回滚集成用例（闭环 C-4a / B4） | §3.1 / §3.4(映射) | P1 |
| 读真实 `data/*` 的 GUT 结构一致性用例（缓解 B5） | §3.4 | P2 |
| E3-S4 AC2 被动"战斗生效"接线（技能结算引擎或数据驱动效果） | §1.1 备注 | P1 |
| `economy:reward_granted` / `gacha:shikigami_obtained` 广播断言（闭环 C-4c） | §3.1 | P2 |
| 单场时长 2–4min 性能断言（E4-S5 AC2） | §1.2 备注 | P2 |

---

【一句话总结】S2 实现与 7 套 GUT 测试代码就绪、算法层 Python 155/155 PASS，但因 **GUT 仍未安装（C-3）致实跑验证为零** + **E3-S3 灼烧叠层未实现 + 双端/UI 零验证 + S1-C4 文件级回滚仍开**，质量门暂置 **CONCERNS**，最终放行由用户本地装 Godot+GUT 跑通 §2 后人工审批。
