# 仙侠卡牌 MVP · S3 Sprint Epic / Story 拆分（engineering-lead 规划）

> 阶段：Phase 5 制作 · Sprint S3（收口）
> 角色：engineering-lead（程基岩）｜ 性质：**规划文档，不改任何脚本/数据/配置/资产**
> 上游：S2 已交付（`production/s2-gate.md` CONCERNS），5 个 DoD 阻塞项 B-1/B-2/B-3/C-3/C-4 转入 S3
> 设计前置状态：**design-strategist 已交付 `production/design-review/s3-design-review.md`（B-1/B-2/B-3 机制定稿 PASS）→ 工程前置已满足，eng 可直接落地**；art-director 立绘/VFX 仍待交付（见 §10）
> 主理人拍板（已采纳）：灼烧→火系 SR「朱雀」、B-3 采纳 qi 气门控、4 张新卡（朱雀/虬龙/虎威/火灵）归属按 design-s3 定稿；用户已于规划阶段确认「全部采纳定稿」（见 §10.3）

---

## 0. 依据文档与约定

### 0.1 依据（全部已读）
| 文档 | 用途 |
|---|---|
| `production/s2-gate.md` | 5 个 S3 DoD 阻塞项（B-1/B-2/B-3/C-3/C-4）收敛 |
| `production/phase4-assembly.md` §3 | S3 DoD（双端跑通 / 可访问性 CONCERN 闭合 / 埋点贯通 / 性能预算 / GUT CI 绿） |
| `production/epics/mvp-epics-stories.md` | 复用 Epic/Story 格式与 E5/E6-S5/S6 基线 |
| `production/phase4-decisions.md` | R3=12（N3/R4/SR3/SSR2，10–15 浮动）；R1 已在 S1 闭合，UI 引导留 S3 |
| `production/design-review/s2-design-review.md` | B-1/B-2/B-3 缺口取证与机制缺口方向 |
| `production/design-review/s3-design-review.md` | **B-1/B-2/B-3 设计定稿（§2.5/§3.4/§4.5/§6.2 为可直接落地工程 AC）；式神 8→12 归属（§5）；art 前置清单（§6.3）** |
| `production/qa/s2-vertical-slice-playtest.md` | 双层验证模型 + 5 场景 × 6 维度手感验收口径（S3 收口须同时绿） |

### 0.2 优先级约定
- **P0 = S3 门禁阻塞项**：不完成则 S3 不放行（含 5 个转入阻塞项 + DoD 强制项）。
- **P1 = Demo 核心体验**：闭环可玩、可展示，但非门禁硬阻塞。
- **P2 = 增强 / 非阻塞**：范围外置或收尾调优。

### 0.3 S3 Epic / Story 总表

| Epic / Story | 对应 GDD / 上游 | 优先级 | 关键依赖前置 |
|---|---|---|---|
| **E5 Demo 串接** | B5 | — | — |
| ├ E5-S1 核心闭环编排 | B5 / ux-spec §1 | P0 | E5-S3/S4、S3-B1/B2/B3、S3-UI-Battle |
| ├ E5-S2 云存档接口留桩（复核） | A5 / E6-S4 已落 | P1 | S2 E6-S4 |
| ├ E5-S3 埋点日志贯通（抽→养→战→回流） | E1-S5 / B5 | P0 | 各 EventBus 信号（S2 已落） |
| ├ E5-S4 双端跑通与旋转稳定 | B5 / E6-S1 | P0 | E6-S1 断点框架 |
| └ **E5-S5 资源断流引导收口（R1）** | R1 / phase4-def §2 | P0 | `EconomyManager.get_recommended_source`（S1 已落） |
| **E6-S5 可访问性桥接** | A5 / accessibility-spec §5 | P0 | UIThemeController（S1 已落） |
| **E6-S6 MotionScale + CVD** | A5 / accessibility-spec §5 | P0 | E6-S5 |
| **S3-B1 觉醒状态改写（burn）** | B-1 / E3-S3 AC2 | P0 | **design-s3 已定稿（§2.5）**；art 状态 VFX（§10） |
| **S3-B2 羁绊实战发射** | B-2 / E4-S3 | P0 | **design-s3 已定稿（§3.4）**；art 横幅 VFX（§10） |
| **S3-B3 玩家选技** | B-3 / E4-S4 | P0 | **design-s3 已定稿（§4.5）**；art 选技/气槽 UI（§10） |
| **S3-Asset-Data 式神 8→12 数据** | R3 / §5 | P1 | **design-s3 已定稿归属（§5.3）** |
| **S3-Asset-Art 立绘/VFX 交付** | R3 / asset-spec §1.2 | P1 | art-director（§10，阻塞 E5 图鉴 12） |
| **S3-UI-Battle 双端战斗 UI 落地** | E4-S6 / D-4 | P0 | art 状态 VFX/横幅/气槽/形状（§10） |
| **S3-DualEnd 双端验证** | phase4 §3 | P0 | E5-S4 + S3-UI-Battle + E6-S1 |
| **S3-C3 GUT 全量 CI 绿** | C-3 / T2/T6/T7 | P0 | 环境装 Godot 4.3 + GUT |
| **S3-C4 文件级 cache 回滚 + 死字段** | C-4 | P0 | CloudSaveService/SaveManager（S1/S2） |
| **S3-Perf 性能预算达标** | phase4 §3 | P0 | 全量资源就位 |

> **关键协作提示**：S3-B1 与 S3-B3 共用 `data/battle/skill_defs.json` 与「`step()` 读技能定义」路径（design-s3 §2.5 注 / §4.5），**强烈建议同一实现批次内一并改造 `BattleManager.step()`**，避免两次改动。

---

## 1. E5 · Demo 串接（B5）

### E5-S1 核心闭环编排
- **优先级**：P0｜**依赖**：E5-S3、E5-S4、S3-B1/B2/B3、S3-UI-Battle、S3-Asset-Data
- **AC1**：`core/` 编排 主菜单→抽卡→图鉴→养成→编队→推图→结算→资源回流→回到抽卡（飞轮闭合），单路径含 1 抽 / 1 养 / 1 编队 / 首关战。
- **AC2**：响应式骨架在 ≥1024（多栏）/ <768（单列）不破版；各环节经 EventBus/GameState 通信，无新增跨 import。
- **AC3**：编队确认出战处接 S3-B2 发射契约（`start_battle` → `BondManager.compute_combo(GameState.deck)`）。
- **验收口径**：本地 Godot 实跑 `s2-vertical-slice-playtest.md` 场景 A 走通无崩溃；Grep 全仓无新增 `preload ...Manager`；UIThemeController `layout_mode` 三档切换稳定。

### E5-S2 云存档接口留桩（复核）
- **优先级**：P1｜**依赖**：S2 E6-S4（已实现）
- **AC1**：`CloudSaveService` 接口齐备，MVP 仅本地 + 云桩（后端空，调用不崩）。
- **AC2**：本地读写经 `SaveManager`（E6-S3/S4）已验证；S3 仅复核契约不回归。
- **验收口径**：复用 `test_cloud_conflict_wrapper.gd` 全绿；手动 mock 云桩调用不抛异常。

### E5-S3 埋点日志贯通（抽→养→战→回流）
- **优先级**：P0｜**依赖**：E1-S5 埋点接口（S1 已落）、各 EventBus 信号（S2 已落）
- **AC1**：四类环节 emit telemetry 事件贯通——抽 `gacha:shikigami_obtained` → 养 `cultivate_level_up/breakthrough/awakened/branch_chosen` → 战 `battle_started/victory/defeat/reward_dropped` → 回流 `economy:currency_changed`；复用 E1-S5 本地日志通道。
- **AC2**：新增 TelemetryAggregator（或复用 logging）按 session 串联四类事件，导出可读日志与「产出/消耗比、环节转化率」（R1 通胀监控预留）。
- **AC3**：单测覆盖——一次模拟闭环产生四类事件且顺序/字段完整。
- **验收口径**：GUT 用例 `test_telemetry_loop`（新建）全绿；Demo 实跑导出样例日志，含抽→养→战→回流全链路。

### E5-S4 双端跑通与旋转稳定
- **优先级**：P0｜**依赖**：E6-S1 断点框架（S1 已落）
- **AC1**：PC 横屏（≥1024，如 1280×720）+ 移动竖屏（<768，如 390×844）双端跑通核心闭环。
- **AC2**：旋转 / 分辨率切换不崩、焦点不丢（UIThemeController `layout_mode` 三档切换稳定）。
- **验收口径**：`s2-vertical-slice-playtest.md` 场景 E 双端各跑一遍；旋转/ resize 事件触发后焦点链不丢、无异常。

### E5-S5 资源断流引导收口（R1）
- **优先级**：P0｜**依赖**：`EconomyManager.get_recommended_source(deficit_currency)`（S1 已落，单测 PASS）
- **AC1**：消耗点（抽卡 / 养成）资源不足时，UI 接 `economy:currency_changed` 渲染「去哪产出」引导入口（推图/Boss/日常/秘境）。
- **AC2**：引导入口点击跳转对应产出源；不阻塞核心循环（R1 闭环收口）。
- **验收口径**：GUT `test_recommended_source`（S1 已落）复用；Demo 实跑「灵气枯竭→提示推图/日常」「觉醒石枯竭→提示仅 Boss」视觉确认。

---

## 2. E6-S5 · 可访问性桥接 AccessibilitySettings（闭合 Phase 3 CONCERN）

- **优先级**：P0｜**依赖**：UIThemeController（S1 已落）、schema v1 `settings` 字段
- **AC1**：新增 **peer autoload `AccessibilitySettings`**（非并入 UIThemeController），持有 `high_contrast` / `reduce_motion` / `text_scale(1.0–1.3)` / `color_blind_mode(NONE/DEUTER/PROTAN/TRITAN)` / `cvd_filter` / `performance_mode` / `dynamic_text`。
- **AC2**：任一字段变更 → emit **`accessibility_changed`** 信号；UIThemeController 订阅并应用高对比主题 / 文本缩放 / CVD 切换。
- **AC3**：设置持久化至 `GameState.settings`（与 schema v1 对齐）。
- **AC4**：单测覆盖 `text_scale` 生效（缩放后布局 reflow 不溢出、不裁切）、`reduce_motion` 生效（MotionScale=0）。
- **验收口径**：GUT `test_accessibility_settings`（新建）全绿；Basic 全项（对比度/高对比/缩放 tabular/三重反馈/色盲冗余）达成。

---

## 3. E6-S6 · MotionScale 动效总线 + CVD 后处理 shader

- **优先级**：P0｜**依赖**：E6-S5
- **AC1**：全局 `MotionScale`（float，reduce_motion 时=0）；VFX/粒子/视差/光扫读取该值。
- **AC2**：reduce_motion=true → 非必要动画跳过，**状态变化保留静态等效反馈**（图标/数字/边框仍更新）。
- **AC3**：CVD 滤镜=根 Viewport 后处理 shader（或主题色重映射），按 `color_blind_mode` 切换（Standard G）；`cvd_filter` 开关可独立启用。
- **AC4**：`performance_mode` 联动纹理/粒子/3D 演出降级（Comprehensive P），降级后断言 Basic 三重标识仍满足。
- **验收口径**：GUT `test_motion_scale_cvd`（新建）全绿；真机切换 `color_blind_mode` 验证形状/图标冗余不依赖色。

---

## 4. S3 真实战斗层修复（B-1 / B-2 / B-3 · design-strategist 已定稿）

> **设计前置状态**：design-s3 已交付 `production/design-review/s3-design-review.md`，§2.5（B-1）/§3.4（B-2）/§4.5（B-3）为可直接落地工程 AC，不再阻塞 S3 开工。本组三 Story 视为 P0 门禁阻塞项。

### S3-B1 觉醒状态改写机制（灼烧叠层 · E3-S3 AC2）
- **优先级**：P0｜**依赖**：**design-s3 §2.5 已定稿**；art 状态 VFX（§10 A2）；与 S3-B3 同批改 `step()`
- **AC1**：新增 `data/battle/skill_defs.json`，每技能 `{element, power（取代硬编码 1.0）, status_on_hit?}`；数值区间用 `min/max`，运行取中点（对齐养成确定性约定）。
- **AC2**：新增 `StatusManager`（或 `BattleResolver` 扩展 + `BattleManager` 状态字段），持有 `statuses[unit_id] = [{type, stacks, turns_left, src_element}]`；暴露 `apply_status(target_id, spec, src_element)` 与 `tick_statuses(unit_id) -> total_dot`。配置 `status_config`（burn/poison/armor_break/momentum）。
- **AC3**：灼烧规则——层数上限 3、DoT = `层数 × 0.03 × 目标最大HP`（中点）、持续 3 tick、到期清层；**水行目标** `max_stacks=1 & duration=1`（水克火压制）、**木行目标** `dot × 1.20`（火克木增益）。
- **AC4**：`BattleManager.step()` 改为从 `skill_defs` 读 power/element，命中后 `apply_status`，受影响单位回合开始 `tick_statuses` 结算 DoT 写 HP 并广播 `battle_turn_resolved`（relation 标 `STATUS`）。
- **AC5**：正交性——`bond_bonus` 仅缩放直接打击 `Dmg_strike`，**不**缩放 DoT（代码注释标明，防双 dip，R5 红线）。
- **AC6**：确定性 + 可测——所有 band 取中点；GUT 覆盖：灼烧施加 / 层数封顶 / 水克火压制 / 木克增益 / 到期清层 / 与连携不双 dip（同场既有连携又有灼烧，断言 DoT 不受 `_bond_bonus` 影响）。
- **验收口径**：GUT `test_status_burn`（新建）全绿；vertical slice 场景 B 火系觉醒单位命中后目标出现灼烧 DoT 跳动、叠层封顶 3；`test_cultivation` 的 `test_awaken_skill` 升级断言「战斗效应」（此前仅断言 id）。

### S3-B2 羁绊实战发射接线（E4-S3）
- **优先级**：P0｜**依赖**：**design-s3 §3.4 已定稿**；art 连携横幅 VFX（§10 A3）；BattleManager 保持零 BondManager 引用
- **AC1**：E5 战斗场景确认出战按序 `start_battle` → `BondManager.compute_combo(GameState.deck)`（必须在 start_battle 之后，因其第 49 行清零 `_bond_bonus`）。
- **AC2**：不改 `BattleManager` 对 `BondManager` 的零引用（守住 E4-S3 AC2 与零 preload grep 红线）。
- **AC3**：战斗 HUD 监听 `EventBus.bond_combo(group_id, bonus_pct)` 渲染横幅；横幅数值 = `bonus_pct`（如 0.175）。
- **AC4**：GUT 修正——`test_battle_flow` 在 `start_battle` 后补 `BondManager.compute_combo(GameState.deck)`；断言剑宗 4 人 `_bond_bonus > 0`（≈0.175）、单人 `== 0.0`。
- **AC5**：`EventBus.gd` 注释补「战斗启动方负责发射」契约。
- **验收口径**：GUT 修正用例全绿 + grep 零 `preload BondManager`；vertical slice 场景 C 横幅出现且数值匹配编队（2 人 +10% / 3+ +17.5% 中点）。

### S3-B3 玩家选技 + 技能 power 数据化 + 目标选择（E4-S4）
- **优先级**：P0｜**依赖**：**design-s3 §4.5 已定稿**；art 选技 UI / 气槽控件（§10 A4）；与 S3-B1 同批改 `step()`
- **AC1**：`BattleManager.step()` 由「自动首活目标 + 硬编码 power」改为**接收玩家输入**（技能 id + 目标 id），经 UI/测试驱动。
- **AC2**：主动技列表由 `get_final_unit` 的 `skills` 解析为 `基础技 + 觉醒技`（过滤被动 passive 串）；分支被动（`jian_xiu_passive` / `ti_xiu_passive`）自动生效不入选技。
- **AC3**：技能 `power` 与 `element` **从 `skill_defs.json` 读取**（废除 1.0 硬编码）；五行倍率由「技能 element」对「目标 element」计算（沿用 `BattleResolver.resolve_damage`）。
- **AC4**：目标选择——玩家指定敌方单位（多敌必选，单敌自动）。
- **AC5（推荐）**：实现 `qi` 资源——每单位 `qi_max=3`、回合 +1、觉醒技耗 1；UI 显示气槽（design-s3 §4.4 推荐 AC，S3 工时紧可降级为无消耗/冷却）。
- **AC6**：GUT——`test_battle_flow` 改造为「给定技能/目标」驱动；断言选克制 element 技能伤害更高、觉醒技触发 `status_on_hit`、被动入算。
- **验收口径**：GUT `test_player_skill_select`（新建/改造）全绿；vertical slice 场景 A/D 选技交互可见、克制/连携可扭转战局、决策时延 <3s/回合。

---

## 5. S3 式神资产补齐（shikigami_defs 8 → 12）

### S3-Asset-Data 数据补齐（eng 独立完成）
- **优先级**：P1｜**依赖**：**design-s3 §5.3 已定稿归属**（朱雀/虬龙/虎威/火灵），R3 分布不变
- **AC1**：`data/shikigami/shikigami_defs.json` 补 4 条（N+1 / R+2 / SR+1）：`sr_zhu_que`(火/yu_zu)、`r_qiu_long`(水/long_zu)、`r_hu_wei`(金/hu_zu)、`n_huo_ling`(火/—)；稀有度分布 = N3/R4/SR3/SSR2，R/SR/SSR 卡框均被用。
- **AC2**：`data/bond/bond_combos.json` 新增 `yu_zu / long_zu / hu_zu` 三组（band 同既有 `combo_2=0.08–0.12` / `combo_3plus=0.15–0.20`）；`cultivation_config.awaken.skills_by_shikigami` 扩充（朱雀→burn、青龙→破甲、白虎→气势、幽冥→中毒）。
- **AC3**：`skill_defs.json` 含 12 基础技 + 4 觉醒技（§2.4）；既有 8 条字段结构向后兼容；新数据经 ConfigLoader 校验、无 orphan、与 bond_combos 成员一致。
- **验收口径**：Python 数据一致性用例 + GUT ConfigLoader 注入 12 全绿；5 个羁绊组各 ≥2 成员、玩家侧五行齐全（金木土水火）。

### S3-Asset-Art 立绘 / VFX 交付（art-director 前置）
- **优先级**：P1（阻塞 E5 图鉴 12 立绘）｜**依赖**：**art-director（§10 A1–A4，待交付）**
- **AC1**：4 张新立绘三视图（朱雀/虬龙/虎威/火灵），套用既有 R/SR/SSR/N 卡框（art-bible §5 双态）；E5 图鉴 12 立绘齐备。
- **AC2**：状态 VFX——灼烧/破甲/中毒/气势 图标（**形状+图标+数字三重**，不靠色，art-bible §8）。
- **AC3**：连携横幅（锚点5 五行符文阵意象）；火行五行形状/配色（朱雀/火灵）；气槽 UI 控件（tabular、≥44px）。
- **验收口径**：eng 仅消费路径引用；验收由 art-director 交付 + Demo 实跑视觉确认（非 eng 阻塞）。

---

## 6. S3 双端验证 + 战斗 UI 落地

### S3-UI-Battle 双端战斗 UI 落地（E4-S6 / D-4）
- **优先级**：P0｜**依赖**：art 状态 VFX/横幅/气槽/形状（§10）；S3-B1/B2/B3
- **AC1**：按 `battle_ui_constants.json` + `element_shape.gd` 渲染五行形状冗余（圆/三角/方/菱/五边）、移动端精简 HUD、技能按钮热区 ≥44×44。
- **AC2**：克制三重标识（图标+数字+颜色，Basic D/E）；连携横幅、选技/目标选择 UI、气槽控件经 InputBridge 双端可用（drag/long_press/hover_peek）。
- **AC3**：状态图标三重冗余（不靠色，art-bible §8）。
- **验收口径**：vertical slice 场景 E 真机核验：灰阶下五行形状可辨、热区命中率 ≥95%、无溢出/裁切。

### S3-DualEnd 双端验证（Dual-End Verification）
- **优先级**：P0｜**依赖**：E5-S4 + S3-UI-Battle + E6-S1
- **AC1**：PC 横屏 ≥1024 + 移动竖屏 <768 双端跑通核心闭环（场景 A–D）。
- **AC2**：旋转 / 分辨率切换不崩、焦点不丢。
- **AC3**：指标达标——双端断点 0 溢出 / 0 裁切；热区点击命中率 ≥95%（移动 ≥44px）；五行形状冗余灰阶可辨。
- **验收口径**：`s2-vertical-slice-playtest.md` 场景 E + 截图比对 + 实跑 PASS；回填 `production/qa/` 作为 S3 体验证据。

---

## 7. S3 测试覆盖回收（C-3 / C-4 转 Story）

### S3-C3 GUT 全量 CI 绿（C-3）
- **优先级**：P0｜**依赖**：环境装 Godot 4.3 + GUT（用户/CI）
- **AC1**：工程注入/安装 GUT addon；`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests` 全量运行退出 0。
- **AC2**：现有 7 测试（cultivation/battle_element/bond/battle_flow/deck_builder/battle_ui_constants/cloud_conflict_wrapper）+ S3 新增用例（status_burn / accessibility_settings / motion_scale_cvd / telemetry_loop / player_skill_select / bond_combo_after_start）全绿。
- **AC3**：CI 工作流挂该命令，门禁失败阻断合并。
- **验收口径**：CI 跑通记录 + 本地命令复跑 PASS（闭合 s2-gate C-3）。

### S3-C4 文件级 cache 回滚 + 死字段清理（C-4）
- **优先级**：P0｜**依赖**：CloudSaveService / SaveManager（S1/S2）
- **AC1**：新增文件级 cache 回滚测试——模拟 SaveManager 写入损坏 / IO 失败，验证 cache 副本回滚（非仅内存 duplicate）。
- **AC2**：清理 s2-gate C-4 标注「死配置字段」，grep 零残留；数据表字段全部被消费或显式标记 deprecated。
- **AC3**：单测覆盖——损坏文件 → 拒绝载入并回滚到上一 cache；checksum 失败路径。
- **验收口径**：GUT `test_cache_rollback`（新建）全绿 + grep 死字段零命中（闭合 s2-gate C-4）。

---

## 8. S3 性能预算达标（S3-Perf）
- **优先级**：P0｜**依赖**：全量资源就位
- **AC1**：包体 < 300MB（PC 构建）。
- **AC2**：PC ≥ 60fps、移动 30–60fps（核心战斗场景 profiling）。
- **AC3**：内存峰值受控（无泄漏；cache 副本上限）；低端移动可经 `performance_mode` 降级（E6-S6 AC4）。
- **验收口径**：Godot Profiler / 真机帧率采样；垂直切片场景 D 单场时长 2–4min 不超预算。

---

## 9. S3 DoD 检查清单

| # | 检查项 | 来源 | 关联 Story |
|---|---|---|---|
| 1 | 核心闭环双端跑通（PC 横屏 + 移动竖屏），旋转/分辨率切换稳定、焦点不丢 | phase4 §3 | E5-S1/S4、S3-DualEnd |
| 2 | **可访问性 CONCERN 闭合**：`AccessibilitySettings` + `accessibility_changed` + `MotionScale` + CVD 单测全绿；Basic 全项（对比度/高对比/缩放/三重反馈/色盲冗余）达成 | phase4 §3 / E6-S5/S6 | E6-S5、E6-S6 |
| 3 | 埋点日志贯通抽→养→战→回流（session 可串联、转化率可读） | phase4 §3 | E5-S3 |
| 4 | 性能预算内（包体 <300MB / PC60·移动 30–60fps） | phase4 §3 | S3-Perf |
| 5 | GUT 全量 CI 绿（含 S3 新增用例） | phase4 §3 / C-3 | S3-C3 |
| 6 | **B-1 觉醒改写机制落地**：灼烧叠层+状态系统，GUT `test_status_burn` 全绿，与连携不双 dip | B-1 | S3-B1 |
| 7 | **B-2 连携实战发射**：`compute_combo` 在 start_battle 后调用，实战 `_bond_bonus>0`，零跨 import 保持 | B-2 | S3-B2 |
| 8 | **B-3 玩家选技**：step() 接收技能/目标，power 数据化，GUT 选技用例全绿 | B-3 | S3-B3 |
| 9 | **C-4 文件级 cache 回滚 + 死字段清理**：GUT 全绿 + grep 零死字段 | C-4 | S3-C4 |
| 10 | 式神资产补齐 8→12（数据 eng 完成；立绘 art 交付） | R3 | S3-Asset-Data / S3-Asset-Art |
| 11 | 资源断流引导收口（R1 UX 闭环） | phase4-def §2 | E5-S5 |
| 12 | 控制清单末项（可访问性桥接）勾选 | phase4 §3 | E6-S5/S6 |

> **双层验证同时绿**：headless 逻辑（GUT 全量）+ hands-on 手感（`s2-vertical-slice-playtest.md` 场景 A–E × 6 维度）在 S3 收口时须**同时 PASS**，任一核心崩溃/数值错误 = FAIL 回 eng。

---

## 10. 依赖前置与跨成员协作矩阵

### 10.1 design-strategist（design-s3）— **已交付（工程前置满足）**
- 交付物：`production/design-review/s3-design-review.md`
- 覆盖：B-1（§2.5）、B-2（§3.4）、B-3（§4.5）、式神 8→12 归属（§5）、art 前置清单（§6.3）、可直接落地工程 AC（§6.2 E1–E10）
- **结论**：eng 对 B-1/B-2/B-3 的实现前置已满足，可直接照 §6.2 落地，无需再等设计定稿。

### 10.2 art-director — **待交付（S3 阻塞项前置）**
| 项 | 交付物 | 阻塞的 Story | 来源 |
|---|---|---|---|
| A1 | 4 张新立绘三视图（朱雀/虬龙/虎威/火灵）+ 既有 8 张图鉴引用 | S3-Asset-Art（E5 图鉴 12） | §6.3 / asset-spec §1.2 |
| A2 | 状态 VFX：灼烧/破甲/中毒/气势 图标（形状+图标+数字三重，不靠色） | S3-B1、S3-UI-Battle | §6.3 |
| A3 | 连携横幅（锚点5 五行符文阵） | S3-B2、S3-UI-Battle | §6.3 |
| A4 | 火行五行形状/配色（朱雀/火灵）；气槽 UI 控件（tabular、≥44px） | S3-B3、S3-UI-Battle | §6.3 |
| A5 | 锚点6 出图（天象裂隙/Boss 3D，phase4-def R2，非阻塞） | 长线 | phase4 |

> eng 侧**数据层（S3-Asset-Data）可独立先行**，不阻塞逻辑；但视觉验收（图鉴 12 / 状态图标 / 横幅 / 气槽）须等 art-director 交付。

### 10.3 主理人 / 用户 — **拍板项（已于 S3 规划阶段确认「全部采纳定稿」）**
1. ✅ **灼烧归属火系 SR「朱雀」**（非概念文档举例的火系 SSR）：R3 锁 SSR2（青龙/白虎）为金行不可改，灼烧落到火 SR 朱雀以保持 R3、完整交付机制——已采纳。
2. ✅ **B-3 `qi` 气资源门控**：采纳（默认实现；S3 工时紧可降级为无消耗/回合冷却，但须显式记录降级决策）。
3. ✅ **式神 4 张归属**（§5.3）批准：朱雀=SR 承载灼烧、虬龙/虎威=R 补全龙/虎族、火灵=N 补火行。

---

## 11. 风险与缓解（继承 S2 门禁）

| 风险 | 影响 | 缓解（S3 Story） |
|---|---|---|
| B-2 连携实战恒 0 | 核心卖点落空 | S3-B2 战斗场景 start_battle 后发射；GUT 断言 `_bond_bonus>0` |
| B-1 觉醒状态缺失 | 觉醒=空标签 | S3-B1 StatusManager + skill_defs；GUT test_status_burn |
| B-3 玩家选技缺失 | 战斗无策略表达 | S3-B3 step() 接收技能/目标 + power 数据化 |
| C-3 GUT 未实跑 | 全量单测缺口 | S3-C3 装 Godot+GUT + CI 门禁 |
| C-4 cache 回滚/死字段 | 边界健壮性 | S3-C4 文件级回滚测试 + grep 死字段 |
| E4-S6 仅数据 | 双端手感未知 | S3-UI-Battle + S3-DualEnd 真机核验 |
| 双 dip 主导策略（R5） | 状态流+连携流叠加 | S3-B1 AC5 正交：bond_bonus 仅缩放直接打击 |
| art 立绘/VFX 迟到 | Demo 视觉验收阻塞 | S3-Asset-Data 先行；视觉验收排期对齐 art-director |

---

## 12. 一句话总结（主理人）

S3 规划已就位：**E5 Demo 4 故事（+R1 收口 E5-S5）+ E6-S5/S6 可访问性桥接 + 双端验证 + 式神 8→12**；S2 门禁 5 阻塞项全部转为 S3 Story（**B-1 觉醒改写 / B-2 连携发射 / B-3 玩家选技 / C-3 GUT CI / C-4 cache 回滚**），其中 **B-1/B-2/B-3 的工程 AC 已由 design-strategist 在 `s3-design-review.md` 定稿，eng 前置满足可直接落地**；art-director 仍须交付立绘/状态 VFX/横幅/气槽（§10.2）；唯一待拍板为「灼烧归属火 SR 朱雀」（§10.3）。S3 DoD（§9）列 12 项门禁检查，含双端跑通、可访问性 CONCERN 闭合、埋点贯通、性能预算、GUT 全量 CI 绿，及 5 个转入阻塞项闭环。本文件为规划文档，未改动任何代码/数据/资产。
