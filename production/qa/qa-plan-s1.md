# QA 计划 · Sprint S1（Phase 5 · 制作）

> 编制：质量负责人 严守真（qa-s1）
> 范围：Phase 5 Sprint S1 —— E1 经济闭环（S1–S6）、E2 抽卡召唤（S1–S5）、E6-S1/S2/S3（A5 底座，含 E6-S5 可访问性单例）。
> 对齐：`docs/architecture/test-strategy.md`（T1/T3/T4/T5，GUT 集成与 CI 命令）、`production/epics/mvp-epics-stories.md`（E1/E2/E6 的 AC 与 S1 的 DoD）。
> 产出性质：纯文档。未修改任何 `.gd` / `project.godot`，未 `git commit`，未下载 GUT，未改动工程配置。

---

## 0. 质量门基准（来自 test-strategy.md §4）

- 合并必备门禁：**T1 经济闭环 / T3 存档冲突 / T4 抽卡保底**（本 S1 落地）+ E6-S5 可访问性单例（S1 已存在，本 QA 额外保障）。
- 验证驱动：先写测试后实现；所有随机路径种子化 `RNGWrapper`；配置经 `ConfigLoader.inject/reset` 注入，与真实 `data/*` 解耦。
- GUT 全量非零退出即阻断合并（`-gexit`）。

> 本 S1 **不**覆盖：T2 五行克制、T5 完整可访问性（reflow/CVD/MotionScale 接线）、T6 羁绊、T7 养成最终式神、双端布局真机验证（均留 S2/S3）。

---

## 1. S1 测试矩阵（T1 / T4 / T3 + E6-S5 单例）

| 测试项 | Story / AC | 测试文件 · 用例 | 关键断言（精确） | 状态 |
|---|---|---|---|---|
| 产出/消耗正确 | E1-S1/S3 | `test_economy.gd::test_grant_and_spend_basic` | grant 后余额 5；spend 3 后 2 | ✅ |
| 余额不足 spend→false 不扣减 | E1-S3 AC1 | `test_economy.gd::test_grant_and_spend_basic` / `test_spend_insufficient_returns_false` | spend(999)→false；余额 0 不变 | ✅ |
| fu_lu 日软预算封顶 | E1-S4 AC1 | `test_economy.gd::test_fu_lu_daily_soft_cap` | 达 12 后拒 +1；余额封顶 12 | ✅ |
| 免费十连=10/日，不计入软预算（pass2 解耦） | E1-S1 AC3 / E1-S4 AC2 | `test_economy.gd::test_free_ten_pull_decoupled_from_soft_budget` | claim 返 10；余额 22（12 软+10 免）；软满普通仍拒 | ✅ |
| po_dan 周产 ~5 | E1-S1 AC2 | `test_economy.gd::test_po_dan_weekly_cap` | 达 5 后拒；封顶 5 | ✅ |
| jue_xing_shi 仅 Boss（boss_only） | E1-S1 AC2 | `test_economy.gd::test_jue_xing_shi_boss_only` | Boss 来源可；推图 来源拒 | ✅ |
| economy:currency_changed 广播 | T1 / E1-S2 AC2 | `test_economy.gd::test_currency_changed_broadcast` | 恰好广播 1 次，currency+amount 正确（断言后 disconnect） | ✅ |
| 跨日重置（生产追踪归零） | E1-S4 AC2 | `test_economy.gd::test_daily_reset_clears_production_tracker` | 当日拒；reset_daily_if_needed("07-21") 后额度恢复 | ✅ |
| E1-S6 资源缺口→推荐源 | E1-S6 AC1/AC3 | `test_economy.gd::test_recommended_source_covers_boss_only` | ling_qi→[推图,日常]；jue_xing_shi→仅[Boss]；未知→空 | ✅ |
| **硬保底 90（必出 SSR）** | E2-S2 AC2 | `test_gacha_pity.gd::test_hard_pity_at_90` / `test_hard_pity_forces_on_90th` | 90 抽内必出；pity=89 下一抽 `_determine_rarity` 强制 SSR | ✅ |
| **软保底 ≥50%** | E2-S2 AC1 | `test_gacha_pity.gd::test_soft_pity_rate_geq_50` | effective_ssr_rate(0)=0.0；(49)≥0.5；(89)>0.95 | ⚠️（见 §2 缺口） |
| **保底不跨池** | E2-S2 AC3 | `test_gacha_pity.gd::test_pity_not_cross_pool` | pool_a 计到 89；pool_b 从 0 起、独立 +1 | ✅ |
| 新手池半价（前 20 抽半价） | E2-S3 AC1 | `test_gacha_pity.gd::test_newbie_half_price` | 20 抽耗 10 符箓；第 21 抽起全价 | ✅ |
| 新手池必出指定 SR | E2-S3 AC2 | `test_gacha_pity.gd::test_newbie_forced_starter_sr` | 首抽 shikigami_id=sr_starter、rarity=SR | ✅ |
| 概率抽样 ±2% 容差（种子化 RNG） | E2-S1 AC2 | `test_gacha_pity.gd::test_rates_within_tolerance` | 1 万次：SSR≈2%/SR≈10%/R≈35%/N≈53% 落 ±2% | ✅ |
| 概率公示数据可读（双端展示） | E2-S5 AC1 | `test_gacha_pity.gd::test_get_probabilities_exposed` | get_probabilities("standard") 返回注入值 | ✅ |
| 写→读一致 | E6-S3 AC2 | `test_save.gd::test_write_read_consistent` | build→apply 后 currencies/shikigami/pity 完全恢复 | ✅ |
| checksum 篡改→拒绝并回滚 cache | E6-S3 AC2 / E6-S4 AC2 | `test_save.gd::test_checksum_tamper_rejected_and_rollback` | 篡改档拒收且 GameState 不变；回滚合法档成功 | ✅（内存级，见 §2 缺口） |
| last-write-wins（version+ts） | E6-S4 AC1 | `test_save.gd::test_last_write_wins` | 云新/本地新/同 ts/云版本高 → 正确胜方 | ✅ |
| delta < 50KB 预算 | E6-S4 AC3 | `test_save.gd::test_delta_within_50kb` | 普通 <50KB；5000 式神 >50KB 标超预算 | ✅ |
| 字段变更 emit accessibility_changed | E6-S5 AC2 | `test_accessibility.gd::test_change_emits_signal` | set_high_contrast 恰好广播 1 次带快照 | ✅ |
| text_scale 钳制 [1.0,1.3] | E6-S5 AC4 | `test_accessibility.gd::test_text_scale_clamped` | 2.0→1.3；0.5→1.0；1.2→1.2 | ✅ |
| reduce_motion→MotionScale=0 | E6-S5 AC4 / E6-S6 种子 | `test_accessibility.gd::test_reduce_motion_zeroes_motion_scale` | 默认 1.0；set_reduce_motion(true)→0.0 | ✅ |
| color_blind_mode 切换 | E6-S5 | `test_accessibility.gd::test_color_blind_mode_switch` | set DEUTER→mode==DEUTER | ✅ |
| 持久化至 GameState.settings | E6-S5 AC3 | `test_accessibility.gd::test_persist_to_game_state` | settings 含 text_scale=1.2 / high_contrast=true | ✅ |

> 矩阵状态图例：✅ 已覆盖；⚠️ 已覆盖但为函数级/确定性断言，未做 empirical 分布（详见 §2）。

---

## 2. 测试覆盖核对结论（静态审查：test-strategy.md ↔ tests/*.gd 实际断言）

### 2.1 T1 经济闭环 —— **已覆盖（9/9 项均有 assert）**
逐项核对任务给定清单，全部命中：
1. 产出/消耗 → `test_grant_and_spend_basic` ✅
2. fu_lu 日软预算封顶 → `test_fu_lu_daily_soft_cap` ✅
3. free_ten_pull=10/日不计入软预算 → `test_free_ten_pull_decoupled_from_soft_budget` ✅
4. po_dan 周~5 → `test_po_dan_weekly_cap` ✅
5. jue_xing_shi boss_only → `test_jue_xing_shi_boss_only` ✅
6. 余额不足 spend→false → `test_spend_insufficient_returns_false` ✅
7. currency_changed 广播 → `test_currency_changed_broadcast` ✅
8. 跨日重置 → `test_daily_reset_clears_production_tracker` ✅
9. E1-S6 推荐源 → `test_recommended_source_covers_boss_only` ✅

**T1 缺口清单：**
- **「日软预算 ≥10 下限」无代码强制**：配置 `economy_config.json` 含 `min_daily:10`，但 `EconomyManager` 运行时从未读取 `min_daily` / `can_accumulate`（死字段）。下限仅靠配置作者遵守；若 `daily_soft_cap` 误配 <10，引擎不会拦截。属配置约束，非运行时断言。→ 建议：要么移除死字段，要么在 `ConfigLoader` 做 schema 校验（min_daily ≤ daily_soft_cap）。
- **周重置边界 `reset_weekly_if_needed` 未单测**：`po_dan` 周上限已测，但"跨周额度归零"这条边界逻辑无用例（仅日重置边界被测）。
- **免费十连跨日重置未显式单测**：现有用例只验证"同日领取返回 0"；"D1 领过 → D2 再领返回 10"的路径（`claim_free_ten_pull` 的 `last_claim_date` 跨日分支）无用例。此项同时是 §4 回归风险点。
- 次要：`economy:reward_granted` 广播（E1-S3 AC2 抽卡/养成侧消费）未被任何测试断言（仅测了 `currency_changed`）。

### 2.2 T4 抽卡保底 —— **已覆盖（6/6 项）**
1. 硬保底 90 → `test_hard_pity_at_90` + `test_hard_pity_forces_on_90th` ✅
2. 软保底 ≥50% → `test_soft_pity_rate_geq_50` ✅（**函数级/确定性**）
3. 保底不跨池 → `test_pity_not_cross_pool` ✅
4. 新手半价 → `test_newbie_half_price` ✅
5. 必出 SR → `test_newbie_forced_starter_sr` ✅
6. 概率抽样 ±2% → `test_rates_within_tolerance`（1 万次）✅

**T4 缺口清单：**
- **软保底 ≥50% 仅断言「概率函数」而非「经验分布」**：`test_soft_pity_rate_geq_50` 直接校验 `effective_ssr_rate(pity, pool)` 返回值（该值正是 `_roll_with_boosted_ssr` 用的 SSR 概率），属确定性函数层验证。但**未**在 soft-pity 区间（如 pity=49 起步）做 1 万次实证抽样验证实际出 SSR 频率≥50%。因 boosted 路径直接使用该函数值，风险低，但严格意义下"概率抽样"仅对**基础档**做了实证。
- `push`/`pull` 经 `EconomyManager.spend` 扣符箓已通过 `test_newbie_half_price` 间接覆盖；但 `gacha:shikigami_obtained` 广播未被测试断言。

### 2.3 T3 存档 —— **已覆盖（核心契约，文件级回滚路径缺失）**
1. 写读一致 → `test_write_read_consistent` ✅
2. checksum 篡改拒绝+回滚 → `test_checksum_tamper_rejected_and_rollback` ✅
3. last-write-wins → `test_last_write_wins` ✅
4. delta<50KB → `test_delta_within_50kb` ✅

**T3 缺口清单（重要）：**
- **文件级 cache 回滚路径未单测**：`SaveManager.read_from_file()` → 正式档损坏时回退 `_cache`（写入 `CACHE_PATH` 前留副本）这条**真实 I/O 回滚链路**无任何用例。现有 `test_checksum_tamper_*` 仅验证**内存级** `apply_save_dict` 拒收 + 手动重新 `apply_save_dict(valid)` 模拟回滚，并未触发 `read_from_file` 的 `_cache` 逻辑。`write_to_file` / `read_from_file` 的磁盘读写本身也未测（按 test-strategy §1 故意与 I/O 解耦，属设计取舍，但**文件 cache 回滚**是 E6-S4 AC2 的核心承诺，建议补一条 `user://` 临时目录的集成用例）。
- `CloudSaveService.push_save` / `pull_and_resolve` 包装函数未被直接断言（仅底层 `resolve_conflict` / `is_delta_within_limit` 被测）。

### 2.4 E6-S5 可访问性单例 —— **已覆盖**
- text_scale 钳制、reduce_motion→MotionScale=0、color_blind_mode 切换、字段变更广播、持久化至 `GameState.settings` **均**有断言（见 §1 末 5 行）。
- **缺口**：`text_scale` 生效后的「**reflow 不溢出 / 不裁切**」属真实 UI/场景层验证（test-strategy §1 明确 headless 跳过、留 S3 双端验证），本 S1 单例测试只覆盖**数值钳制**，未覆盖布局 reflow；`color_blind_mode` 持久化到 `GameState.settings` 未显式断言（走同一 `_commit` 路径，风险低）。CVD 完整接线（E6-S6）本 S1 未做、留 S3。

### 2.5 三态汇总
| 测试目标 | 三态 | 关键缺口 |
|---|---|---|
| T1 经济闭环 | **已覆盖** | min_daily 无代码强制；周重置边界未测；免费十连跨日重置未显式测 |
| T4 抽卡保底 | **已覆盖** | 软保底≥50% 仅函数级，无 empirical 分布；gacha 广播未断言 |
| T3 存档 | **已覆盖（核心契约）** | 文件级 cache 回滚路径未单测；push/pull_and_resolve 未直接测 |
| E6-S5 单例 | **已覆盖** | reflow 不溢出/不裁切实场景留 S3；color_blind 持久化未显式断言 |

---

## 3. 烟雾测试（smoke）清单

> 执行环境说明（见 §6）：本机**无 `godot` 可执行**、**无 GUT addon**（`addons/gut/` 缺失），故以下 smoke 步骤**本次未实际运行**，仅给出用户本地需执行的命令。未下载 GUT、未改工程配置。

### 3.1 工程可加载（headless 无解析/注册报错）
- 目的：捕获脚本语法/解析错误、autoload 注册失败、循环依赖导致启动崩溃。
- 命令（用户本地，Godot 4.3 LTS）：
  ```bash
  godot --headless --path "F:/AI/仙侠卡牌项目" --check-only
  ```
  （`--check-only` 仅解析/校验脚本后退出；如需观察 autoload 注册，可改用 `--quit` 后看 stdout 是否有 `SCRIPT ERROR` / `autoload` 报错。）

### 3.2 10 个 autoload 注册成功、无循环依赖
- 静态审查结论（本 QA 已完成，无需运行即可确认）：`project.godot` [autoload] 共注册 **10** 个——`EventBus / GameState / ConfigLoader / AccessibilitySettings / UIThemeController / InputBridge / SaveManager / CloudSaveService / EconomyManager / GachaManager`。
- **无循环依赖**：逐一读取 10 个 `.gd`，均无 `preload(...)` 彼此；仅经 `EventBus`/`GameState`/`ConfigLoader` 全局名访问，依赖均为指向**叶子数据持有者 GameState** 的单向边（符合架构 §1.3）。`AccessibilitySettings._ready()` 读 `GameState.settings`，而 `GameState` 注册序在其前，初始化序安全。
- 运行期验证（可选）：headless 加载后 stdout 不应出现任何 autoload 初始化报错。

### 3.3 GUT 全量运行（前置：先装 GUT addon）
- 前置：将 Godot 4.x 兼容版 GUT 置于 `res://addons/gut/`，并在 Project Settings → Plugins 勾选启用（本环境未就位，故无法运行）。
- 命令（取自 test-strategy.md §1/§4）：
  ```bash
  godot --headless --path "F:/AI/仙侠卡牌项目" \
    --script res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests -gexit -glog=1
  ```
  `-gexit`：存在失败用例时非零退出，供 CI 门禁。`-gdir`：仅跑 `res://tests` 下的 `test_*.gd`（T1/T3/T4 + E6-S5 单例）。

### 3.4 关键路径冒烟（手动/最小脚本）
1. **经济**：`EconomyManager.grant("fu_lu",5,"日常")` → 余额+5；`spend("fu_lu",3,"gacha")` → 余额-3。
2. **抽卡**：`GachaManager.pull("standard",1)` → 产出 1 个式神写入 `GameState.shikigami`，并广播 `gacha:shikigami_obtained`。
3. **存档**：`SaveManager.build_save_dict()` → `apply_save_dict(...)` 往返一致；篡改 `data` 后 `checksum` 不符应拒收。

---

## 4. 回归风险区（S1 → S2/S3 演进需重点看护）

1. **日/周重置边界**：`reset_daily_if_needed` / `reset_weekly_if_needed` 依赖 `_current_date()` / `_current_week()` 返回的 period 字符串格式（"D2026-07-20" / "W30"）。跨版本/跨时区格式漂移会导致重置不触发。→ 建议补周重置 + 真实日期跨日的单测（见 §2.1）。
2. **checksum 碰撞**：`SaveManager._checksum` 使用 Godot `hash()`（**非加密、32-bit、有碰撞可能**）。极低概率下损坏档可能被误接受。属 ADR-002 已知缺口，安全评审待排期（见 §6）。
3. **保底计数跨池**：`GameState.pity[pool_id]` 按池独立，已被 `test_pity_not_cross_pool` 覆盖；但新增卡池（S2/S3 活动池）时务必复用同一 `get_pity`/`roll_once` 路径，勿另起计数。
4. **免费十连跨日重置**：`claim_free_ten_pull(last_claim_date)` 的跨日分支未被显式单测（见 §2.1）；若主流程忘记在日界调用 `reset_daily_if_needed`，会导致"当日已领"标记残留，次日无法再领。
5. **boss_only 来源校验**：`grant` 中 `cfg.get("boss_only") and source != "Boss"` 是唯一校验点；新增货币若误配 `boss_only`，非 Boss 来源会被静默拒绝，需配置评审把关。

---

## 5. 尚未覆盖（留待 S2 / S3）

| 测试目标 | 对应 Story | 状态 |
|---|---|---|
| T2 五行克制结算（×1.25–1.35 / ×0.7–0.8） | E4-S2（S2） | ⛔ 未写（需 `ElementMatrixDef` 假表注入） |
| T5 完整可访问性（reflow 不溢出/不裁切 + CVD 滤镜 + MotionScale 全接线） | E6-S5/S6（S3） | ⛔ 单例已测，场景级留 S3 |
| T6 羁绊连携（经 `bond:combo` 事件，无跨 import） | E4-S3（S2） | ⛔ 未写 |
| T7 养成最终式神（get_final_unit ↔ B4 一致） | E3-S5（S2） | ⛔ 未写 |
| 双端布局真机验证（≥1024 / <768 不破版、热区≥44×44） | E5-S4 / E4-S1/S4/S6（S3） | ⛔ 需真机/场景用例 |

> UIThemeController（`compute_layout_mode`）/ InputBridge（`inject_intent`）本 S1 亦无单测；其逻辑为纯函数/信号转发，风险低，但建议在 S3 双端验证中补最小单测以满足 T5 门禁。

---

## 6. 已知问题 / 风险

1. **GUT addon 未就位（阻塞本地测试运行）**：`res://addons/gut/` 不存在。S1 的全部 `test_*.gd` 目前**无法在本机或 CI 实际执行**，须先安装 Godot 4.x 兼容版 GUT 并启用插件（§3.3 命令）。在 GUT 就位前，质量门建议状态为 **CONCERNS（待执行）**。
2. **checksum 为非加密 hash（安全评审待排期）**：`SaveManager._checksum` 用 Godot `hash()`，非 HMAC/SHA。存档防篡改能力有限，属 ADR-002 已知缺口，需安排安全评审（建议 S3 前）。
3. **本机无 `godot` 可执行**：PATH 与常见安装目录（`C:\Program Files\Godot` 等）均无 godot；故 §3.1/§3.3 的 smoke 本次**未实际运行**，仅提供命令，未假装通过。
4. **未单测的文件级回滚**（§2.3）：`read_from_file` → `_cache` 真实回滚链路缺用例。
5. **死配置字段**（§2.1）：`economy_config.json` 的 `min_daily` / `can_accumulate` 未被 `EconomyManager` 读取，经济下限无代码保障。
6. **免费十连跨日重置 / 周重置边界**未显式单测（§2.1、§4）。

---

## 7. 给 engineering / 用户的前置待办（建议，不阻塞 DoD 判定）

- [ ] 安装并启用 GUT addon（`addons/gut/`）→ 使 §3.3 可执行。
- [ ] 本机确认 `godot` 4.3 LTS 可用 → 执行 §3.1/§3.3 并将结果回填本计划。
- [ ] （建议）补 `test_save.gd` 文件级 cache 回滚用例（临时 `user://`）。
- [ ] （建议）补 `test_economy.gd`：免费十连跨日重置、周重置边界、`min_daily` 校验。
- [ ] （建议）安排 `hash()` 安全评审（替代为非加密弱校验 or 升级 HMAC）。

> **质量门（建议性，advisory）**：按"已实现 + 测试已写 + 逻辑静态核对通过"，S1 测试覆盖对 T1/T4/T3/E6-S5 的**契约级断言均满足**；但因 GUT 未就位、本机无 godot，**实际执行结果未知**，门禁暂置 **CONCERNS（待执行）**，最终放行由用户人工审批。
