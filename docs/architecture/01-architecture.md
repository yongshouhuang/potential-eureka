# 仙侠卡牌项目 · Phase 3 技术搭建架构文档

> 阶段：Phase 3 技术搭建（绿地，首套代码/架构）｜ 引擎：Godot 4.x（2D-first，3D 演出余量）｜ 双端：PC Steam 横屏(≥1024) + 移动 iOS/Android 竖屏(<768) ｜ 云存档 ｜ 评审：solo / lean
> 对齐基线：`01-concept.md`（P1–P3 / R1–R5 / 范围分层）、`02a-gdd-mvp.md`（B1–B5）、`02b-gdd-full.md`（A1–A5 / B6–B10 / 依赖总图）、`art/art-bible.md`（视觉/断点§7/可访问性§8）、`art/accessibility-spec.md`（Basic/Standard/Comprehensive 三级契约）

---

## 1.1 技术栈决策

| 维度 | 决策 | 理由（lean） |
|---|---|---|
| 引擎 | **Godot 4.x**（锁定具体小版本写入 `CLAUDE.md`，建议 4.3 LTS） | 2D-first 强项、内置 Control/Container 响应式 UI、Resource 配置表原生、双端导出成熟、零授权成本。3D 演出用 SubViewport 余量接入，不破坏 2D 管线。 |
| 脚本语言 | **GDScript 为主**；GDExtension/C# 仅作热路径预留（见下） | 本项目回合制（非实时物理）、数据驱动，GDScript 性能足够；无编译步骤、迭代快、二进制更小（移动包体友好）、Resource 集成最顺。C# 引入 .NET 运行时 → iOS AOT/移动包体增大、构建复杂度上升，仅在 Profiler 证明战斗模拟/大表变换成瓶颈时启用。 |
| 数据驱动 | 配置表用 Godot `Resource`（`.tres`）或 JSON，经 `ConfigLoader` 校验+热重载（debug） | R1 通胀、R5 主导策略需数值快速调参、策划可热调不改代码（见 ADR-004）。 |
| 版本控制 | **Git**；场景保持"薄"（逻辑在脚本/数据），降低 `.tscn/.tres` 合并冲突 | 数据驱动使场景轻量，冲突面收窄。 |
| CI 基线 | lean：导出双端 + `gdformat`/`gdlint` + **GUT** 单元测试 + 场景加载 smoke | 不铺管道；仅保证"能出包、能跑测、不崩首屏"。需一个 runner/账号（**缺口**：见自评）。 |
| 测试 | **GUT**（addons/）+ 验证驱动：关键系统先写测试再实现（经济闭环、克制结算、存档读写、冲突解决） | lean 但核心逻辑可测。 |

**GDExtension/C# 启用触发线（明确门槛，避免过早复杂化）**：当 Profiler 显示单帧战斗模拟 > 4ms 或配置表加载 > 200ms 时，将对应纯计算模块（如 `BattleResolver`、`ConfigLoader` 批量解析）下沉 GDExtension；否则一律 GDScript。

## 1.2 工程目录结构（`res://`）

```
res://
├── main.gd / main.tscn                 # 引导：注册 autoload、读存档、跳首屏
├── autoload/                           # 全局单例（见 1.3）
│   ├── EventBus.gd                     # 事件总线（解耦核心）
│   ├── GameState.gd                    # 玩家档案中央数据（存档载体）
│   ├── SaveManager.gd                  # 本地存读 + 协调云
│   ├── CloudSaveService.gd             # A5：云同步/冲突（核心层实装，MVP 桩）
│   ├── ConfigLoader.gd                 # ADR-004：配置表加载/校验/热重载
│   ├── EconomyManager.gd              # B1
│   ├── GachaManager.gd                 # B2
│   ├── CultivationManager.gd          # B3
│   ├── DeckBuilder.gd                  # B4 构筑
│   ├── BattleManager.gd                # B4 战斗状态机 + BattleResolver
│   ├── BondManager.gd                  # A1 羁绊横切
│   ├── SecretRealmManager.gd           # A2（MVP 桩，核心层实装）
│   ├── StoryManager.gd                 # A3
│   ├── PvpManager.gd                   # A4（异步/AI 代理）
│   ├── UIThemeController.gd            # ADR-001：断点/主题
│   └── InputBridge.gd                  # ADR-003：输入抽象
├── scenes/
│   ├── core/        # 主菜单、场景切换、CinematicManager（3D 余量）
│   ├── gacha/ cultivate/ battle/ bond/ secret_realm/ story/ pvp/
│   └── ui/          # 通用 UI 场景（复用）
├── scripts/
│   ├── data/        # Resource 子类（CurrencyDef/ShikigamiDef/...）
│   ├── systems/     # 可复用逻辑（非场景）
│   └── utils/       # RNG(种子)/校验/数学
├── data/                            # 配置表（Resource/JSON）
│   ├── economy/ gacha/ cultivation/ battle/ bond/ story/ balance/
├── ui/
│   ├── themes/      # Godot Theme（art-bible 色板/字体）+ 高对比主题
│   ├── components/  # 可复用控件（卡框/数值条/角星/形状冗余图标）
│   └── layouts/     # 各屏断点布局变体（同一屏多栏↔单列）
├── addons/ gut/                     # 测试框架
├── tests/                            # GUT 测试脚本
└── assets/                          # 美术/音频（art-director 交付）
```

**原则**：场景"薄"（只做组合与布局），逻辑与数据在 `scripts/`+`data/`；autoload 单例持有系统逻辑，互不直引（只经 `EventBus`/`GameState`）→ 天然无环。

## 1.3 核心系统架构

**Autoload 单例职责（依赖方向单向 → Base 层）**
- `EventBus`：全局信号中枢。所有管理器只 emit/listen，**不直接 import 彼此** → 这是消除 GDD 依赖总图潜在环的关键机制（A1 被 B4/A2/A4 消费，但 B4 仅 listen `bond:combo`，不 import `BondManager`）。
- `GameState`：玩家档案中央数据持有者，`extends Node`（**引擎约束**：Godot 4 的 autoload 必须是 `Node`，`Resource` 无法直接挂到场景树，故以 Node 承载数据，等价于「数据持有者」语义与 §1.7 的序列化意图）。它仍是货币、式神、卡组、保底、进度、羁绊、设置的唯一真源；所有管理器读写它，变更一律经管理器进行（节点内不写游戏逻辑）；存档 = 序列化 `GameState` + `meta`。
- `SaveManager`/`CloudSaveService`：本地为游玩期真源；联网时推/拉云（ADR-002）。
- 业务管理器：`EconomyManager`(B1)、`GachaManager`(B2)、`CultivationManager`(B3)、`DeckBuilder`+`BattleManager`(B4)、`BondManager`(A1)、`SecretRealmManager`(A2)、`StoryManager`(A3)、`PvpManager`(A4)、`UIThemeController`(A5)、`InputBridge`(A5)、`ConfigLoader`(ADR-004)。

**场景树组合**：`Main` → `UIRoot`(Control) + `WorldRoot`(2D/3D 分层) + `CinematicLayer`(SubViewport，3D 余量)。屏幕为 `UIRoot` 下的 Control 子树，经 `UIThemeController` 应用断点布局。

**数据层**：`Resource` 子类定义结构（`ShikigamiDef` 含 base_stats/rarity/element/bond_tags/growth_ref；`GrowthCurveDef`；`SkillDef`；`ElementMatrixDef` 五行；`BondGroupDef`；`StageDef` 等），`ConfigLoader` 加载校验后暴露类型化访问器。代码读配置不硬编码（R1/R5 热调）。

**状态管理**：`GameState` 单一真源 + `EventBus` 变更广播 + 管理器副作用。存读档只序列化 `GameState`（见 1.7）。

## 1.4 模块分解：逐系统对齐 GDD

| GDD 系统 | 代码模块（autoload/script） | 数据表 | 关键对齐点 |
|---|---|---|---|
| **B1 经济** | `EconomyManager` | `data/economy/*`（货币、预算、source/sink 注册） | 货币分层：硬通灵玉/软通符箓/养成(灵气·突破丹·觉醒石)；日/周预算硬上限；**免费十连独立额度 10 符箓/日，解耦**（pass2 修正）；emit `economy:currency_changed` 供顶栏。 |
| **B2 抽卡** | `GachaManager` | `data/gacha/*`（池/概率/保底） | 常驻+新手池(前20抽半价、必出SR起步)；概率 SSR2%/SR10%/R35%/N53%；保底 50 软/90 硬；**保底不跨池**；抽养一体：出货 emit `gacha:shikigami_obtained` → `BondManager` 播羁绊序章；RNG 种子化可测。 |
| **B3 养成** | `CultivationManager` | `data/cultivation/*`（成长曲线） | 升级(灵气)/突破1→6阶(丹+碎片)/觉醒(改写机制)；等级上限随阶 Lv20→Lv80；分支剑修/体修；产出"最终式神"（final_stats/skills/element/bond_tags）。 |
| **B4 构筑+战斗** | `DeckBuilder` + `BattleManager`(`BattleResolver`) | `data/battle/*`（五行矩阵/技能/关卡） | 卡组 4 式神+1 法宝位；五行网状克制(金→木→土→水→火→金)+相生；克制×1.25–1.35/被克×0.7–0.8；连携 2式神+8~12%/3++15~20%；读 `CultivationManager` 最终属性；前3章每章8–10关+1Boss；单场2–4min；产出回流 B1（emit `battle:reward_dropped`）。 |
| **B5 Demo** | 场景编排（`core/`） | — | 串"抽→养→筑→战"最小闭环；响应式骨架验证；云存档接口留桩。集成出口/pass2 骨架。 |
| **A1 羁绊** | `BondManager` | `data/bond/*`（关系矩阵/连携组） | 关系网以"组"为单位防组合爆炸；连携技/被动；羁绊 Lv1–5（共战/赠信物升）；emit `bond:combo` 供 B4 结算、A2/A4/B6 横切增益。**横切增益经 EventBus，不导入消费方**。 |
| **A2 秘境** | `SecretRealmManager`（MVP 桩/核心层实装） | `data/secret_realm/*` | 节点图(战斗/事件/精英/商店/Boss)+遗物(局内增益+10~25%、叠加上限)；复用 B4 规则+A1；回流 B1；程序化组合摊薄产能(R4)。 |
| **A3 剧情** | `StoryManager` | `data/story/*`（章节/词条） | 章节式+宗门支线弧；词条系统(100–200)降密度(R4)；与 B2 羁绊序章耦合；3D 演出经 `CinematicManager`。 |
| **A4 PvP** | `PvpManager` | `data/pvp/*`（MMR/段位/环境Buff） | 异步/AI 代理(ADR-005)，复用 B4；属性归一防碾压(R1/R5)；段位 7–9 阶/赛季~8周；环境轮转(单行+8~12%)压主导策略。 |
| **A5 云存+UI** | `CloudSaveService`+`UIThemeController`+`InputBridge` | `ui/themes/*` | 双底座：响应式框架(ADR-001)+输入抽象(ADR-003)+云存档(ADR-002)+主题(art-bible)。被全部依赖。 |
| **B6 宗门社交** | 扩展钩子（`BondManager`助战/`A5`社交/`A4`排行） | — | 接口预留，不另起炉灶。 |
| **B7 法宝/灵宠** | `data/` 增 `TreasureDef`/`SpiritDef`；`EconomyManager` 独立资源池 | `data/treasure/*` | 独立池防通胀(R1)；视觉差异(art-bible§4 锚点5)。 |
| **B8 活动** | `GachaManager` 增活动池(半继承保底)/`EconomyManager` 活动币 | — | 复用 B2/B1/A3 框架。 |
| **B9 团本** | `BattleManager` Boss 变体 | — | 复用 B4/A5/B1/B7。 |
| **B10 UGC** | `DeckBuilder` 卡组码编解码 / `A5` 分享 | — | 复用 B4/A4/A5。 |

**依赖关系复核（对照 02b 依赖总图）**：B1（资源底座，仅依赖 GameState/Config）被全依赖；A5（UI/存档底座）被全依赖；B4（玩法枢纽）被 B5/A2/A4/B9 依赖；A1（横切）被 B4/A2/A4/B6 依赖。管理器经 EventBus 通信 → 无代码级环。✓

## 1.5 双端响应式 UI 框架（ADR-001 落地）

- **断点策略**（对齐 art-bible§7）：`≥1024` 横屏多栏（左列表/中战场/右信息）；`768–1024` 混合自适应（折叠次要栏）；`<768` 竖屏单列堆叠 + 底部 Tab。
- **实现**：每屏**只写一套** UI 描述（Control + Container：HBox/VBox/Grid + 锚点），`UIThemeController` 读视口尺寸设全局 `layout_mode`，切换 Container 布局变体/显隐次要栏。**不另出独立场景**（R3 缓解：避免双份维护）。
- **Theme 系统**：Godot `Theme` 资源承载 art-bible 色板(青冥#1F3A3D/青碧#4FA39B/月白#E8ECEF/朱砂#C8453A/鎏金#CBA75C/紫宸#8B6DB3) + 字体(标题衬线/正文黑体) + 8 倍数栅格；提供**高对比主题**覆盖；**文本缩放 100–130% 不破版**（弹性布局）。
- **可访问性基线**（art-bible§8 / `art/accessibility-spec.md` Basic）：稀有度=颜色+边框纹理+角星(1/2/3) 冗余；五行=图标+形状(圆/三角/方)；反馈=图标+数字+颜色 三重（治疗+绿十字/伤害红剑/格挡蓝盾）；触控目标 ≥44×44px；数值 tabular nums。
- **状态栏/顶栏**：B1 货币 PC 置角落、移动常顶栏（tabular nums 防跳）。

> 备注（CONCERN 桥接项）：art-director 在 `art/accessibility-spec.md` §5 建议工程侧额外预留独立的 `AccessibilitySettings` 单例（high_contrast/reduce_motion/text_scale/color_blind_mode/cvd_filter/performance_mode/dynamic_text + `accessibility_changed` 信号）、CVD 滤镜后处理 shader、全局 `MotionScale` 动效总线。当前架构已将这些能力部分吸收进 `UIThemeController` 基线（高对比主题、tabular nums、44px、形状冗余），但**未显式预留上述独立单例与信号**，建议 Phase 4（UX 规格）或补丁统一桥接，避免可访问性开关散落多处。

## 1.6 云存档架构（ADR-002 落地）

- **账号绑定**：平台 auth / 邮箱桩（MVP 本地+云桩，核心层实装）。
- **离线优先**：游玩期以本地存档为真源；联网时 `CloudSaveService` 推本地快照、拉云快照。
- **冲突解决**：schema 版本化（`schema_version`）+ `last_write_ts` + `device_id`；高者(last-write)胜；覆盖前写本地 cache 副本可回滚兜底。
- **同步模型**：小 delta 包（目标 <50KB），**同步延迟目标 <2s**；失败重试+本地优先，不阻塞游玩。
- **MVP 边界**：仅本地 + 云接口桩（`CloudSaveService` 接口齐备，后端留空）；核心层接入真实云。

## 1.7 存档/读档 Schema v1（冻结基线）

```yaml
# SaveSchema v1 (序列化 GameState + meta)
schema_version: 1
player:
  currencies:        # B1
    fu_lu: int        # 符箓（玩法产出，日软预算≥10，可攒）
    ling_yu: int      # 灵玉（MVP 仅预留入口）
    ling_qi: int      # 灵气（日产~2000）
    po_dan: int       # 突破丹（周~5）
    jue_xing_shi: int # 觉醒石（仅Boss，周1–2）
  production_tracker: { currency: { period, amount } }  # B1：日/周预算硬上限判定（S1 扩展字段，代码已登记）
  free_ten_pull:      # pass2 修正：独立额度，不计入软预算
    last_claim_date: str
    claimed_today: bool
  shikigami: [ { id, level, breakthrough(1-6), awakened_skills[], bond_level, fragments } ]
  deck: [ shikigami_id x4, treasure_id x1 ]   # B4：4式神+1法宝
  pity: { pool_id: int }   # B2：连续非SSR抽数（扁平），不跨池
  gacha_progress: { pool_id: { pulls_done, starter_claimed } }  # B2：新手半价计数/必出SR（S1 扩展字段，代码已登记）
  progression: { chapters_cleared, stars }        # B4 前3章
  bond: { bond_levels: { group: level } }         # A1 Lv1-5
  settings: { theme, high_contrast, text_scale(1.0-1.3), layout_override }
meta:
  last_write_ts: int
  device_id: str
  checksum: str      # 完整性校验
```

## 1.8 事件总线设计（`EventBus` 类别，冻结）

| 类别 | 事件（示例） | 用途 |
|---|---|---|
| `economy:*` | `currency_changed`, `daily_budget_reset`, `reward_granted` | B1↔顶栏/回流 |
| `gacha:*` | `pull_requested`, `shikigami_obtained`, `pity_updated` | B2→Bond/图鉴/GameState |
| `cultivate:*` | `level_up`, `breakthrough`, `awakened` | B3→属性/战力 |
| `battle:*` | `battle_started`, `turn_resolved`, `element_advantage`, `bond_combo`, `victory`, `defeat`, `reward_dropped` | B4↔A1/Economy |
| `bond:*` | `bond_level_up`, `combo_triggered` | A1 横切 B4/A2/A4/B6 |
| `story:*` | `chapter_progress`, `lexicon_unlocked` | A3→进度 |
| `pvp:*` | `match_found`, `rank_changed` | A4→排行 |
| `save:*` | `save_local`, `save_cloud_pending`, `sync_success`, `sync_conflict` | 存档状态 |
| `ui:*` | `layout_mode_changed`, `theme_changed` | ADR-001 驱动布局/主题 |

## 1.9 性能预算

| 指标 | 目标 |
|---|---|
| MVP 包体 | **<300MB**（2D 资源为主，3D 仅少数演出） |
| 帧率 | PC **60fps** / 移动 **30–60fps** |
| 存档同步延迟 | **<2s**（delta <50KB） |
| 加载 | `ConfigLoader` 异步加载，首屏不阻塞；8 倍数预算 |
| 内存 | 流式加载美术；战斗为回合制，CPU 主耗在 UI 重绘/粒子/3D 演出 |
| 测试门槛 | 单帧模拟 >4ms 或配置加载 >200ms → 触发 GDExtension 下沉（1.1） |

## 1.10 3D 演出余量（不破坏 2D 管线）

- 御剑飞行 / 天象裂隙 / Boss 战入场等少数镜头，用独立 `CinematicManager` + **SubViewport（3D 场景）** 叠于 `CinematicLayer`，与 2D UI 树**分叉独立**，不影响 Control 布局。
- 触发点：突破"飞升"(A1 意象)、Boss 战(B4)、剧情演出(A3)。
- **低档回退**：移动低端设备/用户关闭 → 回退 2D VFX（粒子+序列帧），保证包体与帧率预算。
- 资产由 art-director 交付（锚点1/2/6），技术仅预留钩子。

---

## 三、架构自评（自评估）

**满足 GDD 依赖总图（02b§C）**：
- B1 资源底座 ✓（最底层，被全依赖）；A5 UI/存档底座 ✓（被全依赖）；B4 玩法枢纽 ✓（被 B5/A2/A4/B9）；A1 羁绊横切 ✓（被 B4/A2/A4/B6）。
- 实现顺序对齐 02a§A：经济→抽卡→养成→构筑战斗→Demo，①与②可小步并行。

**无循环依赖**：所有管理器只依赖 `GameState`+`EventBus`+配置，**互不 import**（A1 被 B4/A2/A4 消费仅经 `bond:combo` 事件）。依赖图单向分层：Base(Economy/UI-Save) → Content(Gacha/Cultivate/Bond) → Hub(Battle) → Meta(SecretRealm/Story/PvP) → Extension(B6–B10)。✓

**双端覆盖**：ADR-001(断点/主题) + ADR-003(输入) + A5 三件套覆盖全部系统；B1–B5/A1–A5 双端要点逐条对齐 art-bible§7/§8。✓

**lean 但完整**：聚焦决策（5 ADR + 单例/事件总线/数据层/schema），不铺陈；核心逻辑可测（GUT）。✓

**缺口 / 风险（需主理人知悉）**：
1. **安全评审未排期**：存档加密、云认证、反作弊预留（ADR-002 缺口，标记）。
2. **CI runner/账号缺失**：lean CI 需一个 GitHub Actions runner 与商店开发者账号（PC Steam / iOS / Android），环境未就位。
3. **平衡监控后端缺**：B5 埋点 MVP 仅本地日志，需轻量后端或本地分析脚本承接（R1/R5 监控）。
4. **3D 资产待美术交付**：`CinematicManager` 钩子就绪，资产(锚点1/2/6)依赖 art-director。
5. **本地化未纳入**：当前中文优先（Godot UTF-8 天然支持），多语言为扩展项。
6. **引擎小版本待钉定**：Godot 4.x 具体版本（建议 4.3 LTS）须写入 `CLAUDE.md` 后方可开工。

---

## 四、实现前控制清单（开工门控，逐项勾选）

- [ ] 引擎锁定 **Godot 4.x 具体版本**写入 `CLAUDE.md`（建议 4.3 LTS）
- [ ] 脚本语言决策冻结：**GDScript 为主**，GDExtension/C# 仅热路径触发线
- [ ] 工程目录骨架 `res://` 创建（autoload/scenes/scripts/data/ui/addons/tests）
- [ ] autoload 单例注册（`EventBus`/`GameState`/`SaveManager`/`CloudSaveService`/`ConfigLoader`/`EconomyManager`/`GachaManager`/`CultivationManager`/`DeckBuilder`/`BattleManager`/`BondManager`/`UIThemeController`/`InputBridge` + A2/A3/A4 桩）
- [ ] `EventBus` 事件类别清单冻结（economy/gacha/cultivate/battle/bond/story/pvp/save/ui）
- [ ] **存档 schema v1 冻结**（含 free-ten-pull 解耦、pity 不跨池、checksum）
- [ ] 数据配置表格式确定（Resource vs JSON）+ `ConfigLoader` 校验器就绪
- [ ] **断点主题系统就位**（≥1024 / 768–1024 / <768 + 高对比 + 缩放 100–130%）
- [ ] **输入抽象层 `InputBridge` 就位**（select/back/drag/long_press/hover_peek）
- [ ] 可访问性基线并入 UI 组件（形状冗余 / 44×44 热区 / tabular nums / 高对比）
- [ ] 性能预算写入文档（包体<300MB / PC60、移动30–60fps / 存档 delta<50KB、<2s）
- [ ] 3D 演出接入点（`SubViewport` 钩子 + 低档 2D 回退）预留
- [ ] CI 基线建立（lint + GUT 测试 + 双端导出 smoke）
- [ ] 扩展层接口桩（B6–B10 事件/钩子）预留，避免后续返工
- [ ] **安全评审排期**（存档加密、云认证、反作弊预留）
- [ ] **（CONCERN 桥接）** 可访问性独立单例 `AccessibilitySettings` + `accessibility_changed` 信号 + CVD 滤镜 + MotionScale 动效总线，并入 `UIThemeController` 或作为 peer autoload（对齐 `art/accessibility-spec.md` §5）

---

【一句话总结】本架构以 Godot 4.x + GDScript 为主、EventBus/GameState 解耦单例 + Resource 数据驱动为骨架，用 5 条 ADR 锁定双端响应式 UI、云存档冲突、输入抽象、配置表与 PvP 网络模型，逐系统对齐 GDD（B1→B5 / A1→A5 / B6→B10）满足依赖总图且无循环依赖，附实现前 14 项控制清单与 6 个待排期缺口（另含 1 项可访问性桥接 CONCERN）。
