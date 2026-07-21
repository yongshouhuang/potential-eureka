# S1 设计评审与范围检查 · 设计签字报告

> 评审人：design-strategist（文策渊）｜ 阶段：Phase 5 制作 · Sprint S1 收尾评审
> 评审对象：engineering-lead 实现的 S1（E1 经济 + E2 抽卡 + E6-S1/2/3 底座）
> 基线文档：`design/gdd/02a-gdd-mvp.md`、`design/ux/ux-spec.md`、`production/epics/mvp-epics-stories.md`、`docs/architecture/01-architecture.md`
> 实现文件：`scripts/autoload/{EconomyManager,GachaManager,GameState,ConfigLoader,SaveManager}.gd`、`data/economy/economy_config.json`、`data/gacha/gacha_pools.json`、`project.godot`
> 评审性质：**只读审查**，未修改任何 scripts/data/配置/文档。

---

## 0. 评审结论总表

| # | 评审维度 | 判定 | 一句话结论 |
|---|---|---|---|
| 1 | B1 经济数值忠实度 | **PASS** | 5 货币齐全、预算/封顶/免费十连解耦全部落地；仅 `min_daily` 配置残留（非功能缺陷） |
| 2 | B2 抽卡数值忠实度 | **CONCERNS** | 概率/保底/新手池/必出SR 全部对齐，但 soft-pity 第 50 抽边界 off-by-one（1 行可修） |
| 3 | UX §6 验收关键（E1-S6） | **PASS** | `get_recommended_source` 已落地且按配置返回合理来源，ling_qi→推图/日常、jue_xing_shi→Boss 均满足 AC3 |
| 4 | schema 漂移（pity） | **CONCERNS** | 架构 §1.7 写嵌套 `{soft_count,hard_count}`，实现/存档按扁平 `pool_id→int`，文档与代码漂移；另 `production_tracker/gacha_progress` 扩了冻结 schema 未补登 |
| 5 | GameState 类型偏差 | **PASS** | `extends Node` 为 Godot 4 autoload 引擎约束所致，代码已自注；仅建议回改架构 §1.3 措辞 |
| 6 | 范围检查 | **PASS** | S1 仅做 E1/E2/E6-S1·2·3，无 E3/E4/E5 越界；E1 六故事、E2 逻辑齐全（E2-S5 UI 渲染属 S3 正确后置） |

**设计签字建议：有条件放行（Conditional Pass）。**
- B1/B2 核心数值、E1-S6 验收关键项均忠实落地，无功能缺失、无经济失衡/主导策略/认知过载/支柱漂移（设计红线全过）。
- 放行前需主理人决策 **2 项 CONCERNS**：(a) B2 soft-pity 边界 off-by-one（建议直接拍板 1 行修复）；(b) 架构 §1.7 `pity` 嵌套定义与实现漂移（建议回改架构文档以匹配 Epic AC3 + 扁平实现，并把 `production_tracker/gacha_progress` 补入冻结 schema）。
- 两项均为低风险、可快速收敛的文档/单行修复，不构成阻塞。

---

## 1. 维度一 · B1 经济数值忠实度 —— PASS

### 设计原文对照
- GDD B1（`02a-gdd-mvp.md:37-41`）：符箓日软预算 10–15（可攒）、免费十连独立 10/日不计入软预算；灵气日产 ~2000；突破丹周产 ~5；觉醒石仅 Boss 掉；灵玉仅预留入口。
- Epic E1-S1 AC1–AC3（`mvp-epics-stories.md:25-27`）、E1-S4 AC1–AC2（`mvp-epics-stories.md:38-39`）。

### 证据
| 项 | 设计值 | 实现/配置 | 位置 | 结论 |
|---|---|---|---|---|
| 货币集 5 种 | fu_lu/ling_yu/ling_qi/po_dan/jue_xing_shi | 5 项齐全 | `economy_config.json:2-8` | ✓ |
| fu_lu 日软预算 | 10–15（区间） | `daily_soft_cap: 12` ∈ [10,15] | `economy_config.json:3` | ✓ |
| ling_qi 日上限 | ~2000 | `daily_cap: 2000` | `economy_config.json:5` | ✓ |
| po_dan 周产 | ~5 | `weekly_cap: 5` | `economy_config.json:6` | ✓ |
| jue_xing_shi boss_only | 仅 Boss 掉 | `"boss_only": true` + 强制校验 | `economy_config.json:7`；`EconomyManager.gd:37` | ✓ |
| 免费十连 10/日解耦 | 不计入软预算 | `free_ten_pull.amount=10`；`claim_free_ten_pull` 经 `grant(...,exempt_from_budget=true)` | `economy_config.json:9`；`EconomyManager.gd:64-76` | ✓ |
| 预算硬上限逻辑 | 达上限拒产出 | `_within_budget` 对 exempt 跳过；`reset_daily/weekly_if_needed` | `EconomyManager.gd:102-116, 121-137` | ✓ |
| 产出/消耗广播 | emit `economy:currency_changed` | `grant`/`spend` 均 emit | `EconomyManager.gd:45, 56-57` | ✓ |

### 轻微注意（非缺陷）
- `economy_config.json:3` 同时声明 `min_daily: 10`，但 `EconomyManager._within_budget`（`EconomyManager.gd:102-116`）只读取 `daily_soft_cap`/`daily_cap`/`weekly_cap`，**`min_daily` 字段无任何逻辑引用**。该字段疑似历史残留或语义未落实，建议清理或显式说明（不影响 PASS：日软预算下限 ≥10 已由 `daily_soft_cap=12` 满足）。

---

## 2. 维度二 · B2 抽卡数值忠实度 —— CONCERNS

### 设计原文对照
- GDD B2（`02a-gdd-mvp.md:72-79`）：概率 SSR2/SR10/R35/N53；保底 50 软（SSR≥50%）/90 硬（必出），不跨池；新手前 20 抽半价 + 必出指定 SR。
- Epic E2-S1/S2/S3/S5（`mvp-epics-stories.md:57-75`）。

### 证据（匹配项）
| 项 | 设计值 | 实现/配置 | 位置 | 结论 |
|---|---|---|---|---|
| 概率四档 | SSR2/SR10/R35/N53 | 两池 `rarity_rates` 一致 | `gacha_pools.json:6, 19` | ✓ |
| get_probabilities 返回表 | 可返回概率表（E2-S5 AC1） | `get_probabilities` 返回 `rarity_rates` | `GachaManager.gd:29-30` | ✓ |
| 保底 50/90 | 软 50 / 硬 90 | `soft_pity:50`/`hard_pity:90` | `gacha_pools.json:7-8, 20-21` | ✓ |
| 硬保底必出 SSR | 第 90 抽必出 | `next >= hard → "SSR"` | `GachaManager.gd:103-104` | ✓ |
| 不跨池（按 pool_id 独立） | `pity[pool_id]` 独立计数 | `GameState.pity[pool_id]=int`；换池不继承 | `GameState.gd:14`；`GachaManager.gd:34-35, 84-87` | ✓ |
| 新手前 20 抽半价 | 20 抽共 10 符箓（半价） | `_pull_cost` 前 20 抽交替(0/1)→合计 10 | `gacha_pools.json:22`；`GachaManager.gd:174-183` | ✓ |
| 必出指定 SR | `starter_sr_id` 首抽强返 | 首次 newbie 强返 SR=`sr_zhu_que` | `gacha_pools.json:22`；`GachaManager.gd:71-78` | ✓ |

### ⚠️ CONCERNS-1：soft-pity 第 50 抽边界 off-by-one
- **设计/AC 要求**：E2-S2 AC1（`mvp-epics-stories.md:61`）——“第 50 抽 SSR 概率升至 ≥50%（软保底）”。
- **实现偏差**：`GachaManager.effective_ssr_rate`（`GachaManager.gd:115-116`）：
  ```
  115  if next <= soft:                                  # soft=50
  116      return float(...).get("SSR", 0.02)             # 返回基础 2%
  ```
  当第 50 抽时 `pity_count=49`、`next=50`，`next <= soft`（50<=50）成立 → 直接返回基础概率 **0.02**，即第 50 抽 SSR 仅 **2%**，而非 ≥50%。
  首个真正升权的抽数是第 **51** 抽（`next=51`：`t=(51-50)/40=0.025 → 51.25%`）。
- **影响**：软保底触发时机整体晚 1 抽（50→51），与 GDD/Epic 明示的“第 50 抽升至 50%”不符；属数值偏差，非崩溃类 bug，但破坏设计契约。
- **修复（建议直接拍板）**：将 `GachaManager.gd:115` 的 `if next <= soft:` 改为 `if next < soft:`。
  - 改后：第 50 抽 `next=50 → 50<50` 假 → `t=(50-50)/40=0 → lerp(0.5,1.0,0)=0.5 = 50% SSR`，精确命中 AC；第 49 抽仍走基础概率（正确前置）。一行修复即可闭合。
- **其余保底曲线正常**：第 51–89 抽由 51.25% 线性升至 ~98.75%，第 90 抽硬保底 100%，与设计“50%→100%”意图一致（仅边界 1 抽偏移）。

---

## 3. 维度三 · UX §6 验收关键（E1-S6 资源缺口→推荐产出源）—— PASS

### 设计原文对照
- UX §4 卡点 #1/#2（`ux-spec.md:171, 173`）：消耗点资源不足时必显“去哪产出”引导，避免核心循环断流；此为 **MVP 验收关键**。
- UX §6 待对齐项 2（`ux-spec.md:225`）：要求 `EconomyManager` 暴露“资源缺口→推荐产出源”查询接口。
- Epic E1-S6 AC1–AC3（`mvp-epics-stories.md:45-48`）。

### 证据
| 项 | 要求 | 实现/配置 | 位置 | 结论 |
|---|---|---|---|---|
| 接口落地 | `get_recommended_source(deficit_currency: String) -> Array[String]` | 已实现，返回 `Array[String]`，源由 `data/economy.sources` 驱动（ConfigLoader 注入） | `EconomyManager.gd:142-148` | ✓ |
| ling_qi 枯竭 | 返回含 推图/日常 | `"ling_qi": ["推图","日常"]` | `economy_config.json:12` | ✓ |
| jue_xing_shi 枯竭 | 仅含 Boss（boss_only） | `"jue_xing_shi": ["Boss"]` | `economy_config.json:14` | ✓ |
| 返回类型 | `Array[String]` 与 AC1 一致 | 函数签名 `-> Array[String]` | `EconomyManager.gd:142` | ✓ |
| 与 spend 失败联动 | 调用方据接口渲染引导 | `spend` 不足返 `false`（`EconomyManager.gd:51-54`），接口已就绪供 UI 接 `economy:currency_changed` 渲染 | `EconomyManager.gd:51-54` + `ux-spec.md:225` | ✓ |

**结论**：E1-S6 验收关键项已落地，来源配置合理且匹配 AC3 抽样期望。UI 渲染层（接 `currency_changed` 显示引导入口）属 S3 Demo 范畴，S1 交付数据接口即满足本 Story AC1–AC3。

---

## 4. 维度四 · schema 漂移检查（pity 字段）—— CONCERNS

### 冻结 schema 定义（架构 §1.7）
`docs/architecture/01-architecture.md:135`：
```
pity: { pool_id: { soft_count, hard_count } }  # B2：不跨池
```
—— 明确为 **嵌套结构**：每个 pool 下含 `soft_count` 与 `hard_count` 两个计数。

### 实现实际形态
- `GameState.gd:14`：`var pity: Dictionary = {}  # 抽卡保底：pool_id -> int（连续非 SSR 抽数，不跨池）` —— **扁平 int**。
- `GachaManager.get_pity`（`GachaManager.gd:34-35`）：`GameState.pity.get(pool_id, 0)` 返回 int。
- `GachaManager.roll_once`（`GachaManager.gd:84-87`）：`GameState.pity[pool_id] = 0`（出 SSR）或 `pity_count + 1`（否则）—— 存扁平 int。
- `SaveManager.build_save_dict`（`SaveManager.gd:23`）/`apply_save_dict`（`SaveManager.gd:53`）：序列化与反序列化均为扁平 `pool_id→int`。

### 判定：schema drift（CONCERNS）
1. **实现与 Epic AC 一致、与架构 schema 漂移**：E2-S2 AC3（`mvp-epics-stories.md:63`）写明“`pity` 按 `pool_id` 独立计数（`GameState.pity[pool_id]`）”——即扁平 int。实现选了 Epic 版（更简，且当前软/硬保底仅需“连续非 SSR 计数”，足够）。但 **架构 §1.7 的嵌套定义未同步**，冻结文档与代码不一致。
2. **影响**：
   - `SaveManager` 已按扁平序列化（自洽、可往返），短期内不崩；
   - 但任何**按 schema v1 嵌套结构 `{soft_count,hard_count}` 读取 `pity` 的读者/工具/未来迁移脚本会破裂**；
   - “schema v1 冻结”（架构控制清单 `01-architecture.md:208`）的名义被破坏——代码已先行偏离冻结文档。
3. **文档内部矛盾**：架构 §1.7（嵌套）与 Epic E2-S2 AC3（扁平）本身互斥，实现取了后者。需主理人拍板以哪份为准（建议以 Epic AC3 + 实现为准，回改架构 §1.7）。

### 附加漂移：S1 扩展字段未补登冻结 schema
- `GameState.gd:36-38` 新增 `production_tracker`、`gacha_progress`（S1 预算/新手池进度所需）；`SaveManager.gd:29-30` 已将其纳入序列化。
- 这两项**不在架构 §1.7 冻结 schema v1 中**。属对冻结 schema 的扩展，须正式补登（或标注 v1.1），否则“冻结”名存实亡、后续 SaveManager 契约无据可依。

### 次要观察（可接受）
- 冻结 schema v1 列 `bond: { bond_levels: { group: level } }`（`01-architecture.md:137`），但 `GameState`/`SaveManager` 均未持久化 `bond`（A1 羁绊属核心层，S1 不做，可接受）。
- `meta` 实际仅存 `last_write_ts`/`device_id`（`SaveManager.gd:33-36`），`checksum` 为派生值不入库（符合 ADR-002 描述），与冻结 schema 基本一致。

### 建议（需主理人决策）
- **回改架构 §1.7**：将 `pity: { pool_id: { soft_count, hard_count } }` 改为 `pity: { pool_id: int }  # 连续非 SSR 抽数，不跨池`，与 Epic AC3 及实现对齐；
- **补登扩展字段**：在 §1.7 增加 `production_tracker` / `gacha_progress` 定义（或注明“S1 扩展，v1.x”）。
- 此两项为**文档回改**，不动代码即可闭合 drift。

---

## 5. 维度五 · GameState 类型偏差（Resource vs Node）—— PASS

### 设计原文 vs 实现
- 架构 §1.3（`01-architecture.md:68`）：称 `GameState` 为玩家档案中央 **Resource**。
- 实现 `GameState.gd:8`：`extends Node`。

### 判定：可接受偏差
- **引擎约束**：Godot 4 的 autoload 必须是 `Node`（`Resource` 无法直接挂场景树）。`GameState.gd:5-7` 注释已明确说明此偏差与理由（“等价于数据持有者语义，与架构 Resource 意图一致，引擎约束下改以 Node 承载”）。
- 同批 autoload（`SaveManager.gd:5`、`EconomyManager.gd:4`、`GachaManager.gd:6`、`ConfigLoader.gd:4`）均为 `extends Node`，符合约束、无环。
- **建议（非阻塞）**：将架构 §1.3 的“Resource”措辞改为“Node（数据持有者）”，消除文档歧义，避免后续维护者误解。

---

## 6. 维度六 · 范围检查 —— PASS

### S1 范围基线（Epic `mvp-epics-stories.md:186-188`）
> 范围：E1 全 6 故事（含 S6）+ E2 全 5 故事 + E6-S1（断点框架）+ E6-S2（输入抽象）+ E6-S3（schema 本地读写）。

### 证据：实现了什么
| autoload（project.godot:14-24 注册） | 对应 Epic | 说明 |
|---|---|---|
| EconomyManager | E1（全 6 故事） | 货币/预算/grant/spend/日周上限/telemetry/get_recommended_source 齐全 |
| GachaManager | E2（全 5 故事） | 概率/保底/新手池/产出/get_probabilities 齐全 |
| GameState / SaveManager / ConfigLoader | E6-S3 + 数据底座 | schema 持有 + 本地读写 + checksum + 回滚 |
| UIThemeController | E6-S1 | 断点框架（文件存在，深度未在本评审展开） |
| InputBridge | E6-S2 | 输入抽象（文件存在，深度未在本评审展开） |
| EventBus / AccessibilitySettings / CloudSaveService | 底座 / 桩 | 事件总线；AccessibilitySettings 为 autoload；CloudSaveService 桩 |

### 证据：未越界
- **无 E3/E4/E5/A1–A4 管理器**：`scripts/autoload/` 目录仅含上表 10 个文件，**不存在** `CultivationManager`/`DeckBuilder`/`BattleManager`/`BondManager`/`SecretRealmManager`/`StoryManager`/`PvpManager`（见目录清单）。→ E3 养成 / E4 战斗 / E5 Demo / A1–A4 均未在 S1 实现，**范围正确，无越界**。

### 故事/AC 完整性
- **E1 六故事全覆盖**：S1–S6 对应的货币预算表、产出源(grant)、消耗 sink(spend)、日周预算硬上限、埋点(telemetry)、资源缺口推荐源(get_recommended_source) 全部落地。
- **E2 五故事**：除 E2-S5 的 **UI 渲染**（hover_peek/long_press 触发概率面板 + 稀有度三重冗余）属 S3 Demo 表现层外，其**数据接口 `get_probabilities` 已在 S1 就位**；其余逻辑（概率/保底/新手池/式神产出）全在。E2-S5 UI 部分后置 S3 属正确范围划分。

### 观察项（非缺陷，建议协调）
- `AccessibilitySettings.gd` 已在 S1 注册为 autoload，而 **E6-S5/S6（AccessibilitySettings 完整桥接 + MotionScale + CVD 滤镜）属 S3 范围**（`mvp-epics-stories.md:168-179, 208`）。若 S1 阶段即在 `AccessibilitySettings.gd` 落地了完整 S3 桥接，则属轻微越界；建议 engineering-lead / art-director 确认 S1 阶段该文件仅为**桩或最小占位**，完整可访问性桥接留 S3。此点不影响“范围未越界 E3/E4/E5”的判定。

---

## 7. 设计红线自检（R1–R5 / 支柱）
- **主导策略（R5）**：B1/B2 数值均未引入单一主导路径；五行克制/连携在 B4（S2）才生效，S1 不涉及。✓ 无。
- **经济失衡（R1）**：日/周预算硬上限与免费十连解耦均已落地，通胀/萎缩有封顶；telemetry 留痕。✓ 无。
- **认知过载**：S1 为纯逻辑层，无 UI 堆叠；E2-S5 三重冗余属 S3。✓ 无。
- **支柱漂移**：P1 抽养一体（出货写 `shikigami` + 预留 `gacha_shikigami_obtained` 钩子）、P2 御剑（数值层待 S2）、P3 构筑（待 S2）均按 GDD 推进，无漂移。✓ 无。

---

## 8. 需主理人决策 / 协调的 CONCERNS 清单

| 编号 | 维度 | 问题 | 类型 | 建议处置 | 阻塞？ |
|---|---|---|---|---|---|
| C-1 | B2（维度2） | soft-pity 第 50 抽边界 off-by-one：`GachaManager.gd:115` `if next <= soft` 应为 `if next < soft`，否则第 50 抽 SSR 仅 2% 而非 ≥50% | 数值偏差（1 行修复） | 直接拍板改 `GachaManager.gd:115`，并补一条 pull=50 的保底单测 | 否（建议 S1 收尾修） |
| C-2 | schema 漂移（维度4） | 架构 §1.7 `pity` 写嵌套 `{soft_count,hard_count}`，实现/存档为扁平 `pool_id→int`；且 `production_tracker`/`gacha_progress` 扩了冻结 schema 未补登 | 文档/契约漂移 | 回改架构 §1.7 以匹配 Epic AC3 + 实现；补登 S1 扩展字段（不动代码） | 否（文档回改即可） |
| C-3 | B1（维度1） | `economy_config.json:3` 的 `min_daily:10` 无逻辑引用（残留字段） | 配置卫生 | 清理或显式注释语义 | 否 |
| C-4 | 范围（维度6） | `AccessibilitySettings.gd` 已在 S1 注册，E6-S5/S6 属 S3 | 范围确认 | 协调 engineering-lead/art-director 确认 S1 阶段仅为桩，完整桥接留 S3 | 否 |

---

## 9. 设计签字建议

**结论：有条件放行（Conditional Pass）。**

- **放行依据**：B1 经济数值全维度忠实、B2 除 1 处边界外全对齐、E1-S6（UX §6 验收关键）扎实落地、GameState 类型偏差合理、S1 范围干净无越界、设计红线（R1–R5/支柱）全过。
- **条件（放行前闭合）**：
  1. **C-1**：拍板修复 `GachaManager.gd:115` 的 soft-pity 边界（1 行），并补 pull=50 保底单测；
  2. **C-2**：回改架构 `01-architecture.md` §1.7 的 `pity` 定义 + 补登 `production_tracker`/`gacha_progress`，使冻结 schema 与代码一致。
- **非阻塞跟踪**：C-3（配置残留）、C-4（AccessibilitySettings S1 深度确认）。
- 两项条件均为低风险、快速收敛的文档/单行修复，**不构成功能缺失或架构回退**，建议主理人在 S1 收尾或 S2 开局前闭合即可签字。
