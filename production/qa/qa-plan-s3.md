# QA 计划 · Sprint S3（Phase 5 · 制作收口）

> 编制：质量负责人 严守真（qa-s3）
> 范围：Phase 5 Sprint S3 —— E5 Demo 串接（S1–S4）、E6-S5 可访问性单例（AccessibilitySettings + accessibility_changed）、E6-S6 MotionScale 总线 + CVD 后处理 shader、双端验证（PC 横屏 ≥1024 + 移动竖屏 <768）、式神资产补齐（shikigami_defs 8→13）、以及 S2 遗留 5 个 DoD 阻塞项（B-1/B-2/B-3 + C-3/C-4）的修复验证。
> 对齐：`docs/architecture/test-strategy.md`（T1–T7 + ConfigLoader 假表 + CI 门禁）、`production/epics/mvp-epics-stories.md`（E5 / E6-S5 / E6-S6 的 AC 与 S3 的 DoD）、`production/phase4-assembly.md` §3 S3 DoD、`production/s2-gate.md` §7（5 个遗留阻塞项）、`production/qa/qa-plan-s1.md` / `qa-plan-s2.md`（沿用测试命名/结构/断言风格）、`production/qa/s2-vertical-slice-playtest.md`（B-2 验证重点）。
> 产出性质：纯文档（规划任务）。不写/不跑任何 `.gd` 测试代码，不修改 `.gd` / `project.godot`，不 `git commit`，不下载 GUT。所有测试用例名/断言要点为**待实现规格**，由 engineering-lead 据此落地、用户在本地 Godot+GUT 实跑。

---

## 0. 质量门基准（S3 的 DoD，来自 phase4-assembly.md §3 + s2-gate.md §7）

1. **E5 闭环双端跑通**：核心闭环（抽→养→编队→首关战→结算→回流）在 PC 横屏 ≥1024 与移动竖屏 <768 均跑通；旋转/分辨率切换稳定、焦点不丢。
2. **可访问性 CONCERN 闭合**：`AccessibilitySettings` + `accessibility_changed` + `MotionScale` + CVD 后处理单测全绿；Basic 全项（对比度/高对比/缩放 tabular/三重反馈/色盲冗余）达成。
3. **埋点日志贯通**：抽→养→战→回流各环节 emit telemetry，本地日志可查（复用 E1-S5）。
4. **性能预算内**：包体 <300MB / PC 60fps / 移动 30–60fps；GUT 全量 CI 绿。
5. **5 个遗留 DoD 阻塞项闭环**：B-1 觉醒改写 / B-2 羁绊实战发射 / B-3 玩家选技 / C-3 GUT 实跑 / C-4 文件级 cache 回滚。

> S2 实交付 7+ 套 GUT 测试（T2/T6/T7/E4-S5/E4-S1/E4-S6/E6-S4）+ S1 的 5 套（T1/T3/T4/E6-S5 单例）。本 S3 **沿用既有文件命名与结构**（`extends GutTest` + `before_each` 注入 `ConfigLoader.inject` / `after_each` `reset` + 种子化 `RNGWrapper` + 临时 `EventBus` 监听 `disconnect` 防污染），新增/扩展如下表。集成类（场景/真机）置于 `tests/integration/`，不阻塞核心逻辑门禁（test-strategy §1）。

---

## 1. S3 测试矩阵总览（图例）

**图例**：✅ 沿用已覆盖｜🔶 须补断言（S2 部分实现/仅标记）｜🆕 新增测试（S3 落地）｜❌ 缺失（须 S3 补）｜⚠️ 仅常量/API，场景级留集成测试

| 大块 | 覆盖目标 | 主力测试文件 | 关键断言 |
|---|---|---|---|
| **修复验证 · B-1** | E3-S3 AC2 灼烧叠层在 BattleResolver 生效 | `test_battle_status.gd` 🆕 | 灼烧可叠层、伤害随层数增长、觉醒技写入状态 |
| **修复验证 · B-2** | E4-S3 AC2 真实战斗流连携>0（_bond_bonus 写入） | `test_battle_flow.gd`（扩展） | **start_battle 后 emit `bond:combo` → `_bond_bonus`>0**；加成与事件一致 |
| **修复验证 · B-3** | E4-S4 AC1 玩家选技落地 | `test_battle_flow.gd`（扩展）/ `test_player_skill_select.gd` 🆕 | 玩家选定 element/power 被战斗使用；默认技路径仍可用 |
| **修复验证 · C-3** | GUT 全量本地+CI 实跑 | 全部 `tests/*.gd` + `tests/integration/*` | CI `-gexit` 非零退出阻断合并 |
| **修复验证 · C-4** | 文件级 cache 回滚（SaveManager 磁盘 `_cache`） | `test_save_file_cache_rollback.gd` 🆕 | **损坏档回退上一可用版本**；缺失档回退 cache |
| **E6-S5 · T5** | 可访问性单例 + accessibility_changed | `test_accessibility.gd`（扩展） | 字段变更广播；text_scale reflow；reduce_motion→MotionScale=0；持久化 |
| **E6-S6** | MotionScale 总线 + CVD 后处理 | `test_accessibility.gd`/`test_cvd_filter.gd` 🆕 | 动效总线归零；CVD 按 mode 切换；静态等效反馈保留 |
| **E5 闭环手感** | 核心闭环编排 + 双端 smoke | `tests/integration/test_e5_core_loop.gd` 🆕 + Playtest | 闭环 5 阶段无崩溃/死锁；埋点贯通 |
| **双端验证** | ≥1024 / <768 不破版、热区≥44、形状冗余 | `tests/integration/test_dual_layout.gd` 🆕 | 断点无溢出/裁切；热区≥44；旋转/分辨率焦点保持 |
| **式神补齐** | shikigami_defs 8→13（N3/R4/SR3/SSR3） | `test_shikigami_roster.gd` 🆕 | 计数=13、分布正确、bond 成员均在表、真实表结构一致 |

---

## 2. 逐测试规格（测试名 · 覆盖 Story · 断言要点）

> 命名规则：扩展既有文件用 `test_<既有>`；新增逻辑用 `test_<领域>`；新增集成用 `tests/integration/test_<领域>`。每个用例给出 `func test_xxx()` 名、对应 Story/AC、断言要点。

### 2.1 B-1 · E3-S3 AC2 觉醒改写机制（灼烧叠层）— `tests/test_battle_status.gd` 🆕

> 现状（s2-gate B-1）：`CultivationManager.awaken_skill` 仅标记 `awakened_skills[]`；全工程 grep 无 `burn/灼烧/stack`；`BattleResolver` 只做五行倍率，技能 power 恒硬编码 1.0。S3 须在 `BattleResolver` 落地状态叠层逻辑（ADR 待定：状态表驱动）。
> 前置：`ConfigLoader.inject("battle/status_effects", ...)` 注入灼烧定义（每层伤害加成、最大层数、衰减）；觉醒技经 `get_final_unit` 把 `apply_status: "burn"` 带入战斗。

| 测试名 | 覆盖 Story / AC | 断言要点（精确） |
|---|---|---|
| `test_burn_applies_on_awakened_skill_hit` | E3-S3 AC2 / B-1 | 火系 SSR 觉醒技命中后，目标 `status["burn"]["stacks"]`≥1；`BattleResolver` 生成带 `apply_status` 的状态写入（不再仅标签） |
| `test_burn_stacks_up_to_cap` | E3-S3 AC2 / B-1 | 同目标多次觉醒技命中后层数递增；达 `max_stacks`（注入 3）后不再增长，断言 `stacks == 3` |
| `test_burn_scales_damage_with_stacks` | E3-S3 AC2 / B-1 | 叠 1 层 vs 叠 3 层对同一目标伤害，`damage_stack3 > damage_stack1`（伤害随层数增长，明确区间或 >1.0 倍率）；断言伤害差 >0 |
| `test_burn_decay_per_turn` | E3-S3 AC2（边缘） | 回合推进后 stacks 按定义衰减（断言下一回合 `stacks` 减 1 或归零，取决于配置） |
| `test_non_awakened_no_status` | E3-S3 AC1 回归 | 未觉醒式神的基础技 `apply_status` 为空，目标无灼烧（回归 B-1 前行为，避免误伤） |

> 注：本文件同时承担 S2「🔶 预期部分通过」的闭环——`test_cultivation.gd::test_awaken_skill` 验 AC1（标记），本文件验 AC2（机制生效）。两文件共证 E3-S3 完整。

### 2.2 B-2 · E4-S3 AC2 真实战斗流连携>0（_bond_bonus 写入）— 扩展 `tests/test_battle_flow.gd` 🔶

> 现状（s2-gate B-2，最高风险）：grep 确认 `compute_combo` 全仓零 caller，仅测试调用；`BattleManager` 监听端正确但发射责任空缺 → 真实对局 `_bond_bonus` 恒为 0。`start_battle` 会把 `_bond_bonus` 重置 0.0，**发射须在其后**。S3 由「允许 import BondManager 的战斗发起协调者/UI」于 `start_battle` 之后调用 `compute_combo(deck)` 触发 emit。

| 测试名 | 覆盖 Story / AC | 断言要点（精确） |
|---|---|---|
| **`test_bond_combo_emitted_in_real_battle_flow`** ⭐ | E4-S3 AC2 / B-2 | 1) `bat.start_battle(1,1)` 后，由协调者调用 `BondManager.compute_combo(GameState.deck)`；2) **断言 `bat.get_bond_bonus() > 0`（`_bond_bonus` 已被真实战斗流写入，非零）**；3) 断言 emit `bond:combo` 恰好一次、且 `bat.get_bond_bonus()` 与事件携带倍率一致；4) 对照组：若跳过发射步骤，`get_bond_bonus()`==0（证明不靠默认）。**这是 B-2 验收核心断言。** |
| `test_bond_combo_reset_on_new_battle` | E4-S3 AC2（边界） | 第二场 `start_battle` 后 `_bond_bonus` 重置 0.0；再发射后重新 >0（验证「发射须在 start_battle 之后」的顺序契约） |
| `test_bond_combo_2vs3plus_in_flow` | E4-S3 AC1 | 2 人 deck → 加成落入 [0.08,0.12]；3+ 人 deck → [0.15,0.20]；与 `test_bond.gd` 静态值一致（真战流校验） |
| `test_bond_combo_no_import_regression` | E4-S3 AC2（解耦） | 静态保证延续：grep `preload ...BondManager` 于 `BattleManager.gd` 仍零匹配（发射责任在协调者，监听仍在 BattleManager，不破事件解耦） |

> ⭐ 与 `s2-vertical-slice-playtest.md` 场景 C「羁绊横幅」呼应：逻辑层 `_bond_bonus>0` 由本用例钉死，横幅 UI 由 §5 双端/Playtest 真机核验。

### 2.3 B-3 · E4-S4 AC1 玩家选技落地 — 扩展 `tests/test_battle_flow.gd` + 新增 `tests/test_player_skill_select.gd` 🆕

> 现状（s2-gate B-3）：回合流程用固定技能（element=角色、power=1.0），无玩家技能选择 UI。S3 落技能选择 UI + 技能 power 配置化（经 `get_final_unit` 的 `skills[]` 驱动）。

| 测试名 | 覆盖 Story / AC | 断言要点（精确） |
|---|---|---|
| `test_player_skill_select_affects_battle` | E4-S4 AC1 / B-3 | 玩家从 `fu["skills"]` 选一技（含 element/power≠1.0）→ `bat.step()` 使用的技能 `element`/`power` 与所选一致；伤害随所选 power 变化（断言不等于默认 power=1.0 的结果） |
| `test_default_skill_fallback_when_no_select` | E4-S4 AC1（兼容） | 未选技时回退「element=角色、power=1.0」默认路径仍跑通不崩（保证 B-3 部分落地不破闭环） |
| `test_skill_power_configurable` | E4-S4 AC1（数据） | 注入技能表 `power` 字段，断言 `resolve_damage` 实际乘以该 power（配置化生效，非硬编码 1.0） |
| `test_skill_select_ui_emits_intent` ⚠️场景 | E4-S4 AC1 / E6-S2 | `InputBridge` 归一 `ui_select` 触发选技；集成测试（见 §5）断言 UI 选择写回 `BattleManager.selected_skill` |

### 2.4 C-4 · 文件级 cache 回滚（SaveManager 磁盘 `_cache`）— `tests/test_save_file_cache_rollback.gd` 🆕

> 现状（s2-gate C-4 / s2-qa §3.1）：S1 `test_save.gd` 仅内存级回滚；S2 `test_cloud_conflict_wrapper.gd` 仅 `CloudSaveService` 内存 `_cache`。`SaveManager.read_from_file()` → 正式档损坏时回退**磁盘 `_cache`** 这条真实 I/O 链路**零用例**。本文件用临时 `user://` 目录补集成用例（test-strategy §1 允许 I/O 集成用例不阻塞核心门禁，但 S3 必须闭环）。

| 测试名 | 覆盖 Story / AC | 断言要点（精确） |
|---|---|---|
| **`test_file_corrupt_rolls_back_to_last_good`** ⭐ | E6-S3 AC2 / C-4 | 1) 先写一次合法档（生成磁盘 `_cache` 副本）；2) 将正式档 `save.json` 内容破坏（改 data 不重算 checksum）；3) 调用 `SaveManager.read_from_file()`；4) **断言返回成功且 GameState 回退到「上一可用版本」（即 `_cache` 中的合法档），而非损坏态**；5) 断言 `GameState.currencies` 等于合法档值（非破坏值）。**这是 C-4 验收核心断言。** |
| `test_file_missing_rolls_back_to_cache` | E6-S3 AC2（边界） | 正式档缺失 → `read_from_file` 回退 `_cache`；无 cache 时报错且不崩（断言返回 false，GameState 保持当前安全态） |
| `test_cache_written_before_overwrite` | E6-S3 AC2（前置契约） | 每次成功 `write_to_file` 前，`_cache` 副本更新为「上一可用版本」（断言覆盖前 `_cache` 存在且内容=被覆盖前的旧档） |
| `test_corrupt_cache_rejected` | E6-S3 AC2（健壮） | 若 `_cache` 自身也损坏 → 拒绝且不崩，回退到内存默认/新建（断言不抛异常，返回可识别错误码） |

> 实现约定：测试用 `user://s3_qa_cache_test/` 临时目录，并在 `after_each` 清理，避免污染真实存档。

### 2.5 E6-S5 · T5 可访问性单例（AccessibilitySettings + accessibility_changed）— 扩展 `tests/test_accessibility.gd` 🔶

> 沿用 S1 已落 5 用例（字段变更广播 / text_scale 钳制 / reduce_motion→MotionScale=0 / color_blind 切换 / 持久化）。S3 补「生效」层面断言（reflow/CVD 接线），闭环 E6-S5 AC2/AC4。

| 测试名 | 覆盖 Story / AC | 断言要点（精确） |
|---|---|---|
| `test_text_scale_reflow_no_overflow` ⚠️场景 | E6-S5 AC4 / T5 | text_scale=1.3 下加载集成场景 → 断言关键文本节点 `size.y` 不超出父容器（无裁切/溢出）；需 `tests/integration/` 场景（headless 不加载场景树，故标 ⚠️） |
| `test_reduce_motion_static_equivalent` | E6-S6 AC2 / E6-S5 | `set_reduce_motion(true)` 后，`get_motion_scale()==0` 且某「状态变化」节点仍有静态等效反馈（图标/数字/边框节点 `visible==true`，仅动画 `playing==false`） |
| `test_accessibility_changed_payload_complete` | E6-S5 AC2 | 任一字段变更 emit 的 snapshot 含该字段新旧值；`UIThemeController` 已订阅并切换 `theme`（断言 `UIThemeController.current_theme` 随之变） |
| `test_persist_settings_roundtrip` | E6-S5 AC3 | `set_text_scale/high_contrast/color_blind_mode` → `GameState.settings` 含全部且经 `SaveManager.build_save_dict` 往返一致 |

### 2.6 E6-S6 · MotionScale 总线 + CVD 后处理 — `tests/test_accessibility.gd` 扩展 + 新增 `tests/test_cvd_filter.gd` 🆕

| 测试名 | 覆盖 Story / AC | 断言要点（精确） |
|---|---|---|
| `test_motion_scale_bus_default_and_zero` | E6-S6 AC1 | 默认 `get_motion_scale()==1.0`；`reduce_motion`→`0.0`（沿用并强化）；VFX 节点读该值（断言 `_read_motion_scale()` 与单例一致） |
| `test_motion_scale_reaches_vfx` | E6-S6 AC1 | 一 VFX 节点（粒子/视差/光扫 stub）的 `speed`/`emitting` 随 `get_motion_scale()` 缩放；`scale=0` 时 `emitting==false` 但静态帧保留 |
| `test_cvd_filter_activates_per_mode` | E6-S6 AC3 / Standard G | `set_color_blind_mode(DEUTER)` → `cvd_filter==true` 且根 Viewport 后处理 shader 材质参数 `mode==DEUTER`（断言 `UIThemeController.get_cvd_material().mode`）；切回 NONE → `cvd_filter` 关闭 |
| `test_cvd_filter_independent_toggle` | E6-S6 AC3 | `set_cvd_filter(true)` 独立启用（即便 `color_blind_mode==NONE`）；`performance_mode` 下降级后 `cvd_filter` 仍可保持（断言不被性能降级误关） |
| `test_performance_mode_keeps_basic` | E6-S6 AC4 | `set_performance_mode(true)` → 纹理/粒子/3D 演出降级（断言 `quality` 档降低）；降级后 Basic 三重标识（图标+数字+颜色）节点仍 `visible`（断言满足） |

### 2.7 E5 闭环手感 — `tests/integration/test_e5_core_loop.gd` 🆕 + Playtest 计划（§6）

| 测试名 | 覆盖 Story / AC | 断言要点（精确） |
|---|---|---|
| `test_core_loop_deduct_cultivate_deck_battle_settle` | E5-S1 AC1 | 编排：抽 1（GachaManager）→ 养 1（CultivationManager.upgrade）→ 编队 4+1（DeckBuilder）→ 首关战（BattleManager.start_battle+auto_resolve）→ 结算回流（reward）→ 资源（余额+）。断言每阶段状态正确推进、无崩溃；回流余额增加 |
| `test_responsive_skeleton_no_break_at_breakpoints` ⚠️场景 | E5-S1 AC2 | 视口切 ≥1024 与 <768 → `UIThemeController.layout_mode` 正确切换、关键容器 `size` 不溢出（标 ⚠️ 需场景） |
| `test_telemetry_emitted_through_loop` | E5-S3 AC1 | 钩 `EventBus` 的 `economy:*`/`battle:*`/`gacha:*` 监听 → 断言抽/养/战/回流各环节至少各 emit 1 次 telemetry；本地日志可查 |
| `test_cloud_stub_no_crash` | E5-S2 AC1/AC2 | `CloudSaveService` 云桩调用 `push_save`/`pull_and_resolve` 不崩（MVP 后端空）；本地读写经 `SaveManager` 往返一致 |

### 2.8 双端验证 — `tests/integration/test_dual_layout.gd` 🆕

| 测试名 | 覆盖 Story / AC | 断言要点（精确） |
|---|---|---|
| `test_pc_landscape_no_overflow_at_1024` | E4-S6 AC1 / E5-S4 | 视口=1280×720（≥1024）→ 多栏布局关键节点 `size.y` 不超出视口、无裁切；HUD 显示完整数值 |
| `test_mobile_portrait_no_overflow_below_768` | E4-S6 AC1 / E5-S4 | 视口=390×844（<768）→ 单列/仅关键数值，关键节点不溢出；无横向滚动条 |
| `test_skill_button_hotzone_min_44` | E4-S6 AC2 / Basic E | 技能按钮 `size` ≥ (44,44)；`hitbox` 中心可命中（断言 `get_rect().size` 两维 ≥44） |
| `test_shape_redundancy_grayscale_legible` | E4-S6 AC2 / Basic E / **Standard J** | 五行形状（圆/三角/方/菱/五边）在去色（灰阶）下仍可区分：`ElementShapeMap.shape_for(...)` 五值互不相同且渲染节点形状枚举 != 纯色依赖（断言形状纹理在 `modulate` 去色后仍可辨，附灰阶截图比对） |
| `test_rotation_resolution_focus_retained` | E5-S4 AC1 | 视口在 横屏↔竖屏 旋转 / ≥1024↔<768 切换 → 当前聚焦 Control（如选中式神卡/技能按钮）`has_focus()` 仍 true 或焦点合理回退到同一语义节点（断言焦点不丢、不跳到无关节点） |

### 2.9 式神补齐 — `tests/test_shikigami_roster.gd` 🆕

> 现状（phase4-assembly §4 R3）：MVP = 13（N3/R4/SR3/SSR3），S3 已补齐至 13 张（含火 SSR 朱雀 `ssr_zhu_que`，原 SSR2 锁放宽至 SSR3）。

| 测试名 | 覆盖 Story / AC | 断言要点（精确） |
|---|---|---|
| `test_roster_count_12` | R3 / S3 资产 | `ConfigLoader.load_table("shikigami")` 的 `shikigami` 字典 `size()==12` |
| `test_rarity_distribution` | R3 / S3 资产 | 统计 rarity：N==3、R==4、SR==3、SSR==3（允许 10–15 浮动但分布须保证 R/SR/SSR 卡框均被使用） |
| `test_all_bond_members_exist` | E4-S3 数据一致 | 读 `bond_combos` 各 group 的 `members`，逐一断言存在于 `shikigami_defs`（剑宗 4 人齐全，避免 B-2 编队空连携） |
| `test_real_defs_structure_consistent` | 数据一致性（缓解 s2-qa B5） | 读**真实** `data/shikigami/shikigami_defs.json`（非注入假表）→ 断言每个式神含 `name/element/rarity/bond_tags/base_stats/skills`；`element` ∈ 五行；`base_stats` 含 hp/atk；克制环 data 引用的式神元素合法 |
| `test_new_shikigami_reachable_in_loop` ⚠️场景 | E5-S1 | 新增式神可被抽卡产出/编队选用（集成场景冒烟） |

---

## 3. 双端验证清单（smoke 场景 + 焦点保持 + 形状冗余）

> 执行前提：用户本地已装 Godot 4.3 + GUT（C-3 闭环）；集成场景用例（`tests/integration/`）须真实视口/场景树，headless 仅能跑纯逻辑断言，场景级断言需编辑器或导出包运行。

### 3.1 PC 横屏（≥1024，示例 1280×720 / 1440×900）
- [ ] 主菜单 → 抽卡 → 图鉴 → 养成 → 编队 → 推图首关 → 结算 全路径不破版。
- [ ] 多栏布局关键容器（顶栏货币 / 编队栏 / 战斗 HUD）`size` 不溢出视口，无横向滚动条。
- [ ] 技能按钮热区 ≥44×44 可点；「克制！」浮字（图标+数字+颜色三重）清晰。
- [ ] 五行形状冗余（圆/三角/方/菱/五边）在默认色板下可辨（**Standard J**）。

### 3.2 移动竖屏（<768，示例 390×844 / 360×800）
- [ ] 单列 / 仅留关键数值；HUD 密度不拥挤（R5 极简验证）。
- [ ] 编队网格热区 ≥44×44（手指误触率低）；拖拽 `drag_start|end` 经 `InputBridge` 可用。
- [ ] 五行形状冗余在**灰阶**下仍可区分（色盲友好，Basic E / Standard J）。

### 3.3 旋转 / 分辨率切换焦点保持（E5-S4 AC1）
- [ ] PC：横屏 1280×720 ↔ 窗口缩放 1440×900，当前聚焦节点（如选中式神卡）焦点不丢。
- [ ] 移动：竖屏 390×844 ↔ 横屏 844×390（或模拟旋转），焦点不跳到无关节点；布局随断点重排不崩。
- [ ] ≥1024 ↔ <768 断点切换：`UIThemeController.layout_mode` 正确切换，焦点合理回退到同语义节点（如「编队确认」按钮始终可聚焦）。

### 3.4 五行形状冗余清晰度（关联 Standard J）
- 五元素形状枚举：`metal→triangle` / `wood→circle` / `earth→square` / `water→diamond` / `fire→pentagon`（沿用 `test_battle_ui_constants.gd` 常量）。
- 验收：去色截图比对，5 形状轮廓互不相同、无歧义；不依赖色相即可辨别（满足 Basic E 色盲冗余 + Standard J）。

---

## 4. 性能门（检查方法）

| 指标 | 预算 | 检查方法 | 门禁处理 |
|---|---|---|---|
| 包体 | <300MB | 导出 PC/移动包后读 `*.pck`/APK/IPA 大小（`du -sh` / 平台工具） | 超预算 → CONCERNS（限期瘦身，不立即阻断） |
| PC 帧率 | 60fps | Godot 内置 **Profiler / 独显 FPS**（编辑器 Debugger → Profiler）；或 `OS.get_frames_per_second()` 采样均值 | 稳定 <55fps → CONCERNS；崩溃性卡顿 → FAIL |
| 移动帧率 | 30–60fps | **真机**（Android/iOS）实跑 + Profiler；低端机采样 | <30fps → CONCERNS；明显掉帧致不可玩 → FAIL |
| 单场时长 | 2–4min | E5 场景 D 计时（`s2-vertical-slice-playtest.md` §4） | >6min 或 <30s → FAIL |
| BattleResolver 单帧 | <4ms | GUT 内 `test_battle_element` 附 `assert_true(resolve_damage 耗时 < 4ms)`（test-strategy §4） | 越线 → CONCERNS（提示下沉 GDExtension） |
| 五行伤害差 | 克制 vs 被克 ≥25% | 同阵容打克制/被克，取均值比（Playtest §4） | 差 <25% → CONCERNS（数值调优） |

> 性能断言分两层：① GUT 内可确定性断言的（BattleResolver <4ms）进 CI；② 需真机/场景的（包体/帧率/单场时长）由**真机 smoke + 用户回填**验证（沿用 S2 手感 Playtest 模型，不进 CI 硬阻断，但记入门禁）。

---

## 5. 全量回归触发条件与 CI 门禁

### 5.1 全量回归触发条件（任一成立 → 触发 `tests/` + `tests/integration/` 全量）
1. 任何 autoload 单例改动的 PR（EventBus / GameState / SaveManager / CloudSaveService / ConfigLoader / EconomyManager / GachaManager / CultivationManager / DeckBuilder / BattleManager / BondManager / UIThemeController / InputBridge / AccessibilitySettings）。
2. `ConfigLoader` 表结构变更（新增/删除字段、改 key）。
3. `BattleManager` / `BattleResolver` / `BondManager` 逻辑改动（影响 B-1/B-2/B-3 战斗正确性）。
4. `EventBus` 信号增删（影响所有广播断言）。
5. `AccessibilitySettings` 字段增删（影响 T5/E6-S6）。
6. `data/shikigami/*` / `data/battle/*`（element_matrix/bond_combos/chapters/ui_constants）改动（影响式神补齐/五行/羁绊/双端）。
7. 双端布局/主题（`UIThemeController` / `theme_*` / `art-bible` 色板）改动。
8. 标记 `qa-full-regression` 标签的 PR（强制全量）。

### 5.2 CI 门禁（**C-3 实跑必须进 CI，失败阻断合并**）
- **命令**（test-strategy §1/§4，沿用）：
  ```bash
  godot --headless --path res:// \
    --script res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests -gexit -glog=1
  ```
- **`-gexit`**：存在失败用例时非零退出 → **阻断合并**（test-strategy §4 门禁）。
- **C-3 硬约束**：S3 起 GUT 全量**必须在 CI 内真实执行**，不允许仅本地口头通过 / 仅 Python 间接验证。CI 缺失 GUT addon 或 `godot` 不可调用 → **流水线失败（红灯）**，等同未验证。
- 集成类（`tests/integration/`）建议独立 stage（需导出包/真机或编辑器场景），失败同样阻断；若 CI 无场景运行能力，至少 `test_e5_core_loop` 纯逻辑段 + `test_dual_layout` 的断点常量段须跑通，场景级段降级为人工/真机回填（标 CONCERNS）。
- 门禁清单：T1–T5 为合并必备（test-strategy §4）；S3 新增 **B-1/B-2、C-4、式神补齐** 升为合并必备；B-3、E6-S6 CVD/MotionScale、双端场景级为 CONCERNS 级（失败不阻断合并，但须登记 Bug）。
- 建议 pre-merge 钩：GUT 全量 → `gdformat`/`gdlint` → 场景加载 smoke（headless 加载各 `.tscn` 不报脚本错误）。

---

## 6. S3 垂直切片手感 Playtest（复用并升级 S2 计划）

> 逻辑层已由 Python 155/155 + S2 7 套 GUT 间接验证；S3 重点补「实战连线（B-2）+ 可访问性生效（T5/E6-S6）+ 双端真机（E5-S4）」三层 hands-on。完整清单沿用 `s2-vertical-slice-playtest.md` 5 场景 × 6 维度，新增：
- **场景 F · 可访问性生效**：开高对比 / 减动效 / 色盲模式 → 观察主题切换、动效归零、CVD 后处理、文本缩放 reflow 不溢出。
- **场景 G · 觉醒灼烧实战**：火系 SSR 觉醒后进战斗，观察灼烧叠层伤害随层数增长（验 B-1）。
- **场景 H · 玩家选技**：战斗中弹出选技，观察伤害随所选 power 变化（验 B-3）。
- 量化指标追加：连携倍率实测值（应 >0，验 B-2）、灼烧层数-伤害曲线、减动效下状态反馈静态等效达标率、CVD 下灰阶形状可辨率。
- PASS/CONCERNS/FAIL 标准沿用 S2 §5；其中 B-2/B-1 实战未生效 → **FAIL**（机制诚实），B-3 仅默认技但闭环可跑 → CONCERNS。

---

## 7. S3 QA 门控判定建议（PASS / CONCERNS / FAIL）

> 质量门为**建议性（advisory）**，最终放行由用户人工审批。以下为客观判定阈值。

### 7.1 判定三态定义
- **PASS（可放行）**：核心逻辑 GUT 全绿且实跑（CI 绿）；5 个遗留 DoD 项中 HARD 项全闭环、SOFT 项机制存在且有验证；E5 闭环双端无崩溃/死锁；T5 + E6-S6 单测全绿；双端不破版；性能预算内或仅限 CONCERNS 级偏差。
- **CONCERNS（有条件放行）**：闭环可走通、大部分门禁绿，但存在非阻断缺口（B-3 仅默认技 / C-4 缺测试但机制在 / 双端轻微裁切 / 式神分布偏差可用 / 性能略超预算 / 手感调优项）。须登记 Bug 并排期，不阻断放行。
- **FAIL（必须修，阻断放行）**：核心正确性/验证真空/机制损坏，见 §7.2。

### 7.2 阻塞项定义（明确：哪些 B-/C- 不解决 → FAIL）

| 项 | 性质 | 不解决/损坏 → 判定 | 说明 |
|---|---|---|---|
| **B-1** 觉醒改写（灼烧叠层） | HARD | 未实现（BattleResolver 无状态逻辑，觉醒仍仅标签）→ **FAIL** | E3-S3 AC2 机制诚实；`test_battle_status.gd` 全失败即 FAIL |
| **B-2** 羁绊实战发射（`_bond_bonus`>0） | HARD | 真实战斗流 `_bond_bonus` 恒 0（发射器仍零 caller）→ **FAIL** | 核心卖点；`test_bond_combo_emitted_in_real_battle_flow` 断言 >0 失败即 FAIL |
| **C-3** GUT 实跑进 CI | HARD | 仍未实跑 / CI 未跑 GUT / `-gexit` 未阻断合并 → **FAIL** | 验证真空；等同 S2 CONCERNS 未收敛 |
| **E5 闭环** | HARD | 任一端崩溃/死锁 或 双端严重破版致无法操作 → **FAIL** | `test_e5_core_loop` 崩溃即 FAIL |
| **C-4 机制** | SOFT→FAIL | 若 `SaveManager` 文件级回滚**代码存在但失效**（损坏档无法回退上一可用版本）→ **FAIL** | `test_file_corrupt_rolls_back_to_last_good` 失败即 FAIL |
| **B-3 机制** | SOFT→FAIL | 若玩家选技路径**缺失致战斗崩溃/不可玩** → **FAIL** | 仅默认技但可跑 → CONCERNS |
| **C-4 测试缺口** | SOFT | 回滚机制存在但**尚无 GUT 集成测试覆盖** → **CONCERNS**（须补 test，建议 S3 内补，否则移交 S4 并登记 Bug） | 不立即阻断，但属 S2 遗留必须闭环 |
| **B-3 仅默认技** | SOFT | 选技 UI 未落地但闭环用默认技跑通 → **CONCERNS** | 策略深度不足，记设计调优 |
| **双端轻微问题** | CONCERNS | 轻微裁切/热区临界/反馈弱 → **CONCERNS** | 真机核验，限期优化 |
| **式神分布偏差** | CONCERNS | 计数=12 但稀有度分布偏离（如缺 R/SR/SSR 卡框未被使用）→ **CONCERNS** | 须保证各卡框被用 |
| **性能偏差** | CONCERNS | 包体略超 / 帧率临界 / 单场时长临界 → **CONCERNS** | 限期优化，不立即阻断 |
| **手感调优项** | CONCERNS | 成长感弱/反馈弱/Boss 偏易偏磨 → **CONCERNS** | 交 design-strategist |

### 7.3 S3 门禁判读速查
- 全绿 + CI 跑通 + 5 项 HARD 闭环 → **PASS**。
- HARD 项有任一 FAIL → **FAIL**（阻断）。
- HARD 全过、仅 SOFT/CONCERNS 项 → **CONCERNS（建议放行，登记 Bug）**。
- C-3 未进 CI → 无论其余如何 → **FAIL**（验证真空，S2 CONCERNS 未收敛）。

---

## 8. S2 遗留项 → S3 映射与状态

| 遗留项 | 来源 | S3 闭环测试 | 判定层级 |
|---|---|---|---|
| B-1 灼烧叠层 | s2-gate §7 | `test_battle_status.gd`（§2.1） | HARD→FAIL |
| B-2 连携实战发射 | s2-gate §7 | `test_bond_combo_emitted_in_real_battle_flow`（§2.2）⭐ | HARD→FAIL |
| B-3 玩家选技 | s2-gate §7 | `test_player_skill_select*`（§2.3） | SOFT |
| C-3 GUT 实跑 | s2-gate §7 | §5.2 CI 门禁 | HARD→FAIL |
| C-4 文件级 cache 回滚 | s2-gate §7 | `test_save_file_cache_rollback.gd`（§2.4）⭐ | SOFT→FAIL（机制）/ CONCERNS（仅测试缺） |
| S1-C4b 死配置字段（min_daily 等） | s2-qa §3.1 | 建议 `ConfigLoader` schema 校验（不在 GUT 强制，CONCERNS） | CONCERNS |
| S1-C4c 广播未断言（economy:reward_granted / gacha:shikigami_obtained） | s2-qa §3.1 | 建议补 `test_economy`/`test_gacha` 广播断言（P2） | CONCERNS |
| S2 B5 真实数据表仅 Python 间接验证 | s2-qa §3.4 | `test_real_defs_structure_consistent`（§2.9） | CONCERNS→缓解 |
| 式神补齐 8→13 | phase4 R3 | `test_shikigami_roster.gd`（§2.9） | PASS（分布 N3/R4/SR3/SSR3）/ HARD（计数≠13 致编队空） |

---

## 9. 尚未覆盖 / 风险（留 S4 或登记 Bug）

| 测试目标 | 状态 | 处置 |
|---|---|---|
| 移动端 HUD 极简真机细节（R5） | 部分 | 真机 smoke；CONCERNS 级 |
| 单场时长 2–4min 性能断言 | 部分 | 真机计时，不进 CI 硬阻断 |
| `economy:reward_granted` / `gacha:shikigami_obtained` 广播断言 | 缺 | 建议补 P2 |
| 死配置字段 schema 校验 | 缺 | 建议 `ConfigLoader` 加校验 P2 |
| 多语言/动态文本（Comprehensive） | 缺 | MVP 不铺，留长线 |

---

## 10. 给 engineering / 用户的前置待办

- [ ] **C-3 硬前置**：装 Godot 4.3 + GUT，确保 CI 能跑 GUT 全量（`-gexit`）。**S3 启动第一要务**。
- [ ] 落 B-1：`BattleResolver` 状态叠层（灼烧），补 `test_battle_status.gd`。
- [ ] 落 B-2：战斗发起协调者于 `start_battle` 之后调用 `BondManager.compute_combo(deck)` 发射 `bond:combo`；补 `test_bond_combo_emitted_in_real_battle_flow` 断言 `_bond_bonus>0`。
- [ ] 落 B-3：玩家选技 UI + 技能 power 配置化；补 `test_player_skill_select*`。
- [ ] 落 C-4：`SaveManager.read_from_file` 磁盘 `_cache` 回滚链路；补 `test_save_file_cache_rollback.gd` 断言损坏档回退上一可用版本。
- [ ] 扩 T5/E6-S6：`test_accessibility.gd` 补 reflow/CVD 接线断言；新增 `test_cvd_filter.gd`。
- [ ] 落 E5 闭环：`tests/integration/test_e5_core_loop.gd` + Playtest 场景 F/G/H。
- [ ] 落双端：`tests/integration/test_dual_layout.gd`（断点/热区/形状/焦点）。
- [ ] 式神补齐至 13（N3/R4/SR3/SSR3），补 `test_shikigami_roster.gd`。
- [ ] 建 `production/qa/bugs/`，将 B-1/B-2/B-3/C-3/C-4 登记为正式条目跟踪。

---

【一句话总结】S3 QA 计划承接 S2 门禁 5 个 DoD 阻塞项，给出可落地的测试矩阵（B-1 灼烧叠层 / **B-2 真实战斗流 `_bond_bonus`>0** / B-3 玩家选技 / **C-4 文件级 cache 回滚到上一可用版本** / C-3 GUT 进 CI 阻断合并）、T5+E6-S6 可访问性全绿、E5 双端闭环、式神 8→13 补齐；门控判定明确 B-1/B-2/C-3 与「E5 崩溃 / C-4 机制失效」不解决即 FAIL，B-3/C-4 测试缺口与双端/性能/手感偏差为 CONCERNS 级。纯文档产出，测试代码由 engineering-lead 据此实现、用户本地 Godot+GUT 实跑回填。
