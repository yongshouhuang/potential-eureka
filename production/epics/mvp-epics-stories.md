# 仙侠卡牌 MVP · Epic / Story 拆分（Phase 4 预制作）

> 对齐：架构 `01-architecture.md`（1.2 目录 / 1.3 单例 / 1.4 模块 / 1.7 schema / 1.8 事件总线 / 1.9 性能 / 四 控制清单）、`02a-gdd-mvp.md`（B1–B5）、`02b-gdd-full.md`（依赖总图）、`art/accessibility-spec.md` §5（接口契约）。
> 范围：MVP（B1–B5）+ A5（云存/UI/输入/**可访问性桥接**）。A1–A4/B6–B10 属核心层/扩展层，本拆分不展开。
> 原则：验证驱动（先测后写，见 `test-strategy.md`）；管理器只经 `EventBus`/`GameState` 通信，无跨 import。

## 0. Epic 总览与冲刺映射

| Epic | 对应架构模块 | GDD | 故事数 | 冲刺 |
|---|---|---|---|---|
| **E1** 经济闭环 | `EconomyManager` + `data/economy` | B1 | 5 | S1 |
| **E2** 抽卡召唤 | `GachaManager` + `data/gacha` | B2 | 5 | S1 |
| **E3** 养成系统 | `CultivationManager` + `data/cultivation` | B3 | 5 | S2 |
| **E4** 构筑+战斗 | `DeckBuilder`+`BattleManager`/`BattleResolver`+`data/battle` | B4 | 6 | S2 |
| **E5** Demo 串接 | `core/` 场景编排 | B5 | 4 | S3 |
| **E6** A5 云存+UI+输入+可访问性桥接 | `UIThemeController`/`InputBridge`/`CloudSaveService`/`SaveManager`/`AccessibilitySettings`(新增) + CVD/MotionScale | A5 | 6 | S1(S1骨架)/S3(S5/S6桥接) |

实现顺序严格自底向上（02a§A）：E1→E2→E3→E4→E5；A5 底座（E6-S1/S2/S3）前置 S1，可访问性桥接（E6-S5/S6）收口 S3。

---

## E1 · 经济闭环（B1）

**E1-S1 货币与预算表定义**
- AC1：5 货币就位——`fu_lu`(符箓,软通玩法产)/`ling_yu`(灵玉,硬通MVP预留)/`ling_qi`(灵气)/`po_dan`(突破丹)/`jue_xing_shi`(觉醒石)；`data/economy` 经 `ConfigLoader` 加载校验。
- AC2：`ling_qi` 日产上限 ~2000；`po_dan` 周产 ~5；`jue_xing_shi` 标记 `boss_only=true`（仅 Boss 掉落）。
- AC3：**免费十连独立额度** `free_ten_pull`=10 符箓/日，字段独立于软预算表（pass2 修正，解耦）。

**E1-S2 资源产出源**
- AC1：产出源接口（日常/通关/章节首通/Boss）调用 `EconomyManager.grant(currency, amount, source)`。
- AC2：成功 emit `economy:currency_changed`；顶栏订阅该事件实时更新（tabular nums）。

**E1-S3 资源消耗 sink**
- AC1：消耗接口 `EconomyManager.spend(currency, amount, sink)` 校验余额，不足返回 `false` 并拦截。
- AC2：抽卡/养成调用该接口；成功 emit `economy:currency_changed` 与 `economy:reward_granted`（养成/抽卡侧消费）。

**E1-S4 日/周预算硬上限**
- AC1：`fu_lu` 日软预算下限 ≥10（区间 10–15，可攒）；当日软产出达上限后拒绝继续软产出（免费十连除外）。
- AC2：`free_ten_pull` 不计入软预算；日界/周界重置逻辑（按 `last_claim_date`/周序号）可单测。

**E1-S5 平衡监控埋点**
- AC1：每次产出/消耗记录 telemetry 事件（`save:`/`economy:*` 复用），MVP 落本地日志。
- AC2：日志可被 B5 Demo 读取计算「产出/消耗比」与环节转化率（R1 通胀监控预留）。

**E1-S6 资源缺口→推荐产出源查询（R1 · UX §6 验收关键 · 已采纳）**
- AC1：`EconomyManager.get_recommended_source(deficit_currency: String) -> Array[String]` 返回该货币的可产出来源列表（如 `推图`/`Boss`/`日常`/`秘境`），来源由 `data/economy` 的 `sources` 字段驱动（经 `ConfigLoader` 注入）。
- AC2：当 `spend()` 因余额不足返回 `false` 时，调用方（抽卡/养成 UI）据该接口渲染「去哪产出」引导入口，避免核心循环断流（UX §4 卡点 #1/#2）。
- AC3：单测覆盖——`ling_qi` 枯竭返回含 `推图`/`日常`；`jue_xing_shi` 枯竭返回仅含 `Boss`（`boss_only=true`）。

> 注：本 Story 由 Phase 4 汇编 R1 决议正式补入 S1（原「待补 note」升级为正式 Story）。

---

## E2 · 抽卡召唤（B2）

**E2-S1 卡池与概率**
- AC1：常驻池全档位 + 新手池；概率 `SSR 2% / SR 10% / R 35% / N 53%`（注入假表）。
- AC2：种子化 RNG（`scripts/utils/RNG`）下 10k 次抽样，各档实测频率落入公示 ±2% 容差。

**E2-S2 保底机制（50 软 / 90 硬，不跨池）**
- AC1：单池连续 50 抽未出 SSR → 第 50 抽 SSR 概率升至 ≥50%（软保底）。
- AC2：单池连续 90 抽 → 第 90 抽必出 SSR（硬保底）。
- AC3：`pity` 按 `pool_id` 独立计数（`GameState.pity[pool_id]`）；换池不继承（与 schema v1 对齐）。

**E2-S3 新手池半价与保底起步**
- AC1：新手池前 20 抽消耗半价。
- AC2：新手池首次保底必出指定 SR 起步式神（数据表 `starter_sr_id`）。

**E2-S4 消耗与式神产出**
- AC1：消耗符箓/灵玉 → 产出 `Shikigami` 写入 `GameState.shikigami`。
- AC2：产出 emit `gacha:shikigami_obtained`（→ `BondManager` 播羁绊序章，MVP 桩）。

**E2-S5 双端概率展示 + 稀有度冗余**
- AC1：`InputBridge` 抽象意图 `hover_peek`(PC 悬停)/`long_press`(移动长按) 触发概率面板。
- AC2：稀有度渲染=颜色+边框纹理+角星(1/2/3) 三重冗余（art-bible §8 / accessibility Basic E），灰度下仍可辨。

---

## E3 · 养成系统（B3）

**E3-S1 升级**
- AC1：耗 `ling_qi` 提升等级，HP/ATK 线性 +2~3%/级。
- AC2：等级上限随突破阶（1 阶 Lv20 → 6 阶 Lv80）；超阶上限拦截。

**E3-S2 突破**
- AC1：1→6 阶，每阶全属性 +8~12%，解锁 1 被动槽（上限随阶增）；耗 `po_dan`+同名碎片。
- AC2：突破后 `GameState` 式神 `breakthrough` 与被动槽数更新。

**E3-S3 技能觉醒**
- AC1：达阶门槛觉醒主动技，`awakened_skills[]` 标记。
- AC2：觉醒改写机制（如火系 SSR「灼烧」可叠层）在 `BattleResolver` 生效（E4-S2 联动）。

**E3-S4 分支（剑修/体修）**
- AC1：高阶突破可选方向，记录于式神数据。
- AC2：两方向赋予不同被动，战斗结算生效（不导入 B4，经数据读取）。

**E3-S5 最终式神产出**
- AC1：`CultivationManager.get_final_unit(shikigami_id)` 聚合 `final_stats/skills/element/bond_tags/breakthrough`。
- AC2：B4 读取该接口返回正确最终属性（E4 验收前置）。

---

## E4 · 构筑 + 战斗（B4）

**E4-S1 卡组构筑**
- AC1：编队 4 式神 + 1 法宝位，超出规模拦截；写入 `GameState.deck`。
- AC2：双端点选/拖拽经 `InputBridge`（`drag_start|end`）可用；移动端编队网格热区 ≥44×44。

**E4-S2 五行网状克制结算**
- AC1：相克 金→木→土→水→火→金 + 相生；克制伤害 ×1.25–1.35、被克 ×0.7–0.8（注入假 `ElementMatrixDef`）。
- AC2：`BattleResolver.resolve_damage(attacker, defender, skill)` 单元测：克制方落入上区间、被克落入下区间、相生给小幅增益；纯计算可独立测（GDExtension 触发线内）。

**E4-S3 羁绊连携（MVP 静态）**
- AC1：2 式神同队 +8~12% / 3+ +15~20%（静态连携表驱动）。
- AC2：B4 经 `bond:combo` 事件获取加成，**不 import `BondManager`**；连携触发 emit `bond:combo` 与横幅。

**E4-S4 回合制战斗**
- AC1：行动条/能量 + 玩家选技；一回合流程跑通。
- AC2：克制命中 emit `battle:element_advantage` + 「克制！」浮字（图标+数字+颜色三重，Basic D）。

**E4-S5 推图章节 + 产出回流**
- AC1：前 3 章每章 8–10 关 +1 Boss；关卡推进 `GameState.progression`。
- AC2：通关 emit `battle:reward_dropped` → `EconomyManager` 回流符箓(1–3/关)/丹/石；单场时长 2–4min（性能预算内）。

**E4-S6 双端战斗适配**
- AC1：移动端 HUD 仅留关键数值；五行用「图标+形状(圆/三角/方)」冗余。
- AC2：技能按钮热区 ≥44×44；形状冗余图标渲染（Basic E）。

---

## E5 · Demo 串接（B5）

**E5-S1 核心闭环编排**
- AC1：`core/` 编排 主菜单→抽卡→图鉴→养成→编队→推图→结算→资源，单路径含 1 抽/1 养/1 编队/首关战。
- AC2：响应式骨架在 ≥1024 / <768 不破版。

**E5-S2 云存档接口留桩**
- AC1：`CloudSaveService` 接口齐备，MVP 仅本地 + 云桩（后端空，调用不崩）。
- AC2：本地读写经 `SaveManager`（见 E6-S3/S4）。

**E5-S3 埋点日志**
- AC1：抽→养→战→回流各环节 emit telemetry；本地日志可查（复用 E1-S5）。

**E5-S4 双端跑通与旋转稳定**
- AC1：PC 横屏 + 移动竖屏双端跑通；旋转/分辨率切换不崩、焦点不丢。

---

## E6 · A5 云存档 + UI + 输入 + 可访问性桥接

**E6-S1 响应式断点框架（ADR-001）**
- AC1：`UIThemeController` 读视口设 `layout_mode`（≥1024 多栏 / 768–1024 混合 / <768 单列）。
- AC2：单一 `Theme` 资源承载 art-bible 色板常量（青冥/青碧/月白/朱砂/鎏金/紫宸），**禁止硬编码色值**；8 倍数栅格。

**E6-S2 输入抽象层（ADR-003）**
- AC1：`InputBridge` 归一 `ui_select`/`ui_back`/`drag_start|end`/`long_press`/`hover_peek`；触控+键鼠订阅同一抽象意图。
- AC2：可注入意图单测（不依赖真实输入设备）。

**E6-S3 存档 Schema v1 + 本地读写**
- AC1：`SaveManager` 序列化 `GameState` + v1 `meta`（`schema_version`/`last_write_ts`/`device_id`/`checksum`）；含 `free_ten_pull` 解耦、`pity` 不跨池。
- AC2：写入→读回一致；`checksum` 校验失败拒绝并回滚本地 cache。

**E6-S4 云存档冲突解决（ADR-002）**
- AC1：`CloudSaveService` 版本化 + last-write（version+ts 高者胜）+ 覆盖前写 cache 副本可回滚。
- AC2：注入冲突——本地 ts<云→取云；本地 ts>云→取本地；cache 副本存在可回滚。
- AC3：delta <50KB、同步延迟 mock <2s（离线优先，不阻塞游玩）。

**E6-S5 ★可访问性桥接（闭合 Phase 3 CONCERN）**
- AC1：新增 **peer autoload `AccessibilitySettings`**（非并入 UIThemeController），持有 `high_contrast`/`reduce_motion`/`text_scale(1.0–1.3)`/`color_blind_mode(NONE/DEUTER/PROTAN/TRITAN)`/`cvd_filter`/`performance_mode`/`dynamic_text`。
- AC2：任一字段变更 → emit **`accessibility_changed`** 信号；`UIThemeController` 订阅并应用高对比主题 / 文本缩放 / CVD 切换。
- AC3：设置持久化至 `GameState.settings`（与 schema v1 `settings` 字段对齐）。
- AC4：单测覆盖 `text_scale` 生效（缩放后布局 reflow 不溢出、不裁切）、`reduce_motion` 生效（MotionScale=0）。

**E6-S6 ★MotionScale 动效总线 + CVD 滤镜后处理**
- AC1：全局 `MotionScale`（float，reduce_motion 时=0）；VFX/粒子/视差/光扫读取该值。
- AC2：reduce_motion=true → 非必要动画跳过，**状态变化保留静态等效反馈**（图标/数字/边框仍更新）。
- AC3：CVD 滤镜=根 Viewport 后处理 shader（或主题色重映射），按 `color_blind_mode` 切换（Standard G）；`cvd_filter` 开关可独立启用。
- AC4：`performance_mode` 联动纹理/粒子/3D 演出降级（Comprehensive P），降级后断言 Basic 三重标识仍满足。

> **CONCERN 闭合说明**：Phase 3 质量门遗留项（架构 1.5 末条 + 控制清单末条）为「可访问性独立单例/信号/CVD/MotionScale 未显式预留」。本 E6-S5/S6 将其正式化为 A5 的两个 Story，新增 `AccessibilitySettings` peer autoload + `accessibility_changed` 信号，并落地 `MotionScale` 总线与 CVD 后处理 shader，严格对齐 `art/accessibility-spec.md` §5 接口契约。CONCERN 状态：**已闭合**。

---

## 冲刺建议（S1–S3）

### S1 · 经济 + 抽卡 + 存档骨架（自底向上前两段 + A5 底座）
- **目标**：跑通资源底座与内容入口，立起双端框架与本地存档。
- **范围**：E1 全 6 故事（含 S6 资源缺口查询）+ E2 全 5 故事 + E6-S1（断点框架）+ E6-S2（输入抽象）+ E6-S3（schema 本地读写）。
- **DoD**：
  1. 经济闭环单测通过（产出/消耗/日周预算/免费十连解耦）。
  2. 抽卡保底单测通过（50 软/90 硬/不跨池/新手半价），概率抽样容差达标。
  3. 本地存档读写 + checksum + 损坏回滚单测通过。
  4. 断点框架 + 输入抽象就位，三断点布局切换不破版。
  5. 控制清单相关项勾选（目录骨架/单例注册/事件总线冻结/schema v1 冻结/断点主题/输入抽象）。

### S2 · 养成 + 构筑战斗（玩法中枢）
- **目标**：打通「养成→最终式神→构筑→战斗→回流」可玩闭环。
- **范围**：E3 全 5 故事 + E4 全 6 故事 + E6-S4（云冲突 last-write）。
- **DoD**：
  1. 养成最终式神接口单测通过（E3-S5 ↔ E4 读取一致）。
  2. 五行克制结算单测通过（×1.25–1.35 / ×0.7–0.8，假表注入）。
  3. 羁绊连携经 `bond:combo` 事件（无跨 import）单测通过。
  4. 推图回流闭环跑通，单场 2–4min。
  5. 云存档冲突解决单测通过（last-write + cache 回滚 + delta<50KB）。

### S3 · Demo 串接 + 可访问性桥接 + 双端验证（收口）
- **目标**：集成最小可玩 Demo，闭合可访问性 CONCERN，双端验证基线。
- **范围**：E5 全 4 故事 + E6-S5（AccessibilitySettings）+ E6-S6（MotionScale + CVD）+ 双端验证。
- **DoD**：
  1. 核心闭环双端跑通（PC 横屏 + 移动竖屏），旋转/分辨率切换稳定、焦点不丢。
  2. **可访问性桥接 CONCERN 闭合**：`AccessibilitySettings` + `accessibility_changed` + `MotionScale` + CVD 滤镜单测全绿；Basic 全项（对比度/高对比/缩放/三重反馈/色盲冗余）达成。
  3. 埋点日志贯通抽→养→战→回流。
  4. 性能预算内（包体<300MB / PC60·移动30–60fps），GUT 全量测试 CI 绿。
  5. 控制清单末项（可访问性桥接）勾选。
