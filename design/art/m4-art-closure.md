# 仙侠卡牌 · M4 美术收口终评（四元素终稿规格评审）

**Task**：ART-M4-CLOSURE-001（High）　**切片**：M4 抽卡 UI 美术终稿接入 · 收口终评
**引擎/平台**：团结引擎 1.9.3 / UGUI / Android 竖屏（参考分辨率 1080×2340，Match=Height）
**评审对象**：`design/art/m4-ui-art-spec.md`（四元素 PullButton / PityProgressBar / CurrencyLabel / InsufficientCta 终稿资产表 + 字段映射 + §1 偏差诊断 + §7.3 偏差闭合）
**编写**：art-director 林绘澄
**对齐基线**：`art/art-bible.md`（§2 色彩 / §3 字体 / §7 UI 语言 / §8 可访问性）、`art/accessibility-spec.md`（Basic / Standard / Comprehensive）、`design/ux/ux-spec.md`（§2.2 Summon / §4 核心循环卡点）、`design/ux/gacha-screen-mvp.md`（§2.3 / §3.2 / §4.3 / §6）、`CLAUDE.md`（禁硬编码色 / Android IL2CPP）

> **评审口径**：本评审批次**不写实现代码、不改任何 `.cs`**，仅对「四元素终稿规格」做闭环就绪性与质量门判定。实跑验证（终稿 PNG 真接入 prefab / SpriteAtlas / 9-slice）因用户本回合无 Unity 环境未做，列为待补（见 §2.2）。

---

## 1. 四元素终稿规格闭环就绪性判定（对照基线）

> 结论先行：**四元素终稿规格在「文档 / 资产表 / 字段映射 / 偏差闭合」层面均已就绪，建议批准文档闭环。**

| 元素 | 资产/字段完成度 | art-bible 对齐 | accessibility 对齐 | ux / gacha 对齐 | 偏差闭合 | 结论 |
|---|---|---|---|---|---|---|
| **PullButton** | ✅ 4×9-slice 底（常态/按下/禁用烘焙对角划线/保底 armed）+ `ico_st_disable` 锁 glyph + tabular 文案 | §2 色板 / §3 字体 / §7 玉质面板+云纹边+圆角8–12 | Basic A/B/C/E + Standard J/K/I | gacha §2.3（≥48px）/ §3.2（禁用不靠纯色） | §1 A/B/D 均已与代码核对一致（§7.3） | **文档就绪 ✅** |
| **PityProgressBar** | ✅ `pity_track/fill`+`mat_pity_fill` 渐变 + `pity_mark_50`(菱)/`_90`(方双刻) + `_txtCount`/`_txtSub` tabular | §2 / §7 / §8（不靠色区分两段） | Basic E（形状+数字+颜色）+ Standard G/I | gacha §4.3（玉质条+鎏金描边+刻度形状） | §1 A/B/C 均已与代码核对一致（§7.3） | **文档就绪 ✅** |
| **CurrencyLabel** | ✅ `ico_cur_fulu` 符箓图标 + tabular 余额 | §2 / §3 | Basic A/C/E（icon+数字+月白三通道） | gacha §2.3（符箓 icon + tabular，监听 currency_changed） | 无独立 .cs，映射 `GachaScreenController._currencyLabel`（§5.4 明确） | **文档就绪 ✅** |
| **InsufficientCta** | ✅ 青碧 `#4FA39B` `cta_bg_9slice` + `ico_nav_battle` 去推图 glyph + 文案 | §2 灵力色 / §8 / §7 | 卡点#1 强制 CTA（引导 vs 阻断，形状/图标非纯色） | gacha §2.3（默认隐藏，InsufficientCurrency 显）/ §3.2 | §1-D（红色占位→青碧）已闭合（§7.3） | **文档就绪 ✅** |

**关键核查点（均通过，无漂移）**：
- **色板 token 零漂移**：M4 §2.1 九色（青冥/深墨/青碧/月白/朱砂/鎏金/素灰/信息灰/紫宸）与 art-bible §2 完全一致；HEX 仅作美术源资产设计 token，运行时经 `UIThemeController.COLOR_*`（CLAUDE.md 硬约束），未硬编码。
- **字段-代码一致性已闭合**：§7.3 逐字段比对 `PullButton.cs` / `PityProgressBar.cs` / `GachaScreenController.cs`，§1 四处诊断（A 标记=GameObject、B 新增 `_txtSub`、C `imgTrack/matPityFill` 未序列化、D CTA 红色偏离）全部标记为「与运行代码一致 ✅」。
- **可访问性三通道齐备**：保底段=形状(菱/方)+数字+颜色；禁用态=形状(对角划线)+glyph(锁)+文字+信息灰；CTA=形状+glyph+文字——均非纯色（art-bible §8 / accessibility E / ux §4 卡点#1）。

---

## 2. M4 美术质量门判定

### 2.1 判定结果

> **🔶 CONCERNS（文档可审批，集成待验证）**

- **通过项（文档 / 规格层面）**：四元素资产表完整、字段映射与运行代码一致（§7.3 已逐字段核对）、4 处偏差全部闭合、色板 token 与 art-bible §2 零漂移、可访问性 Basic 全项 + Standard 主体（J/I/G）+ K（字体层级）落地、CVD 冗余（形状+数字+颜色）三通道齐备。
- **未通过 / 待补项（交付 / 验证层面）**：见 §2.2。
- **为何非 PASS**：规格「纸面闭环」成立，但「终稿真接入并可在 Unity 验证」本回合未做（用户无 Unity 环境），且 eng 钩子未接，无法声明美术交付已**验证**闭环。
- **为何非 FAIL**：无任何规格缺陷或基线违背；所有待补项均为「验证 / 接入」性质，非「重做 / 返工」。

### 2.2 阻塞 / 待补项清单（按优先级）

| ID | 类别 | 待补项 | 优先级 | 说明 / 阻塞影响 |
|---|---|---|---|---|
| **V1** | 实跑验证 | 终稿 PNG 真接入 prefab + 进 `SpriteAtlas`（2048²，ASTC 6×6）+ 9-slice 设 Border（按钮 24 / 轨道 16） | 🔴 High（验证） | 用户本回合无 Unity 环境，无法跑验证；资产表与替换路径（§7.2）已备，待有环境时执行并截图核对 |
| **V2** | 实跑验证 | 四元素字段赋值后 prefab 视觉核对（`_imgBg`/`_imgLockIcon`/`_txtLabel`/`_imgFill`/`_mark50`/`_mark90`/`_txtCount`/`_txtSub`/`_currencyLabel`/`_insufficientCta`） | 🔴 High（验证） | 同上；灰盒 interim 占位已可先接（§7.1），终稿同名替换 |
| **E1** | eng 钩子 | PullButton 保底触发态（Pity-Armed）代码钩子 | 🟠 Medium | 美术已备 `btn_bg_armed_9slice` + 角标 sprite；`PullButton.cs` 仅 3 态，无 `SetPityArmed`；属增强（非 MVP 阻断） |
| **E2** | eng 钩子 | PityProgressBar tick 脉冲动画（`DetectCrossing` 驱动） | 🟠 Medium | 代码仅返回 Crossing 未播动画；阈值含义已由「形状+数字」静态承载，脉冲为增强 |
| **E3** | eng 钩子（可选） | `imgTrack` / `matPityFill` 序列化字段评估 | ⚪ Low | 美术已按现有字段落地，无阻塞；仅「轨道增强 / 渐变独立调参」时才需 eng 加字段 |
| **E4** | eng 钩子 | CurrencyLabel icon 字段方案（TMP 内联 sprite vs sibling Image） | 🟡 Medium | `_currencyLabel` 仅 TMP 无独立 icon 字段；须 eng 选方案 |
| **E5** | 集成 footgun | `_disabledTint` 双重去饱和协调 | 🟡 Medium | 烘焙禁用 sprite 接入时须把 prefab `_disabledTint` 设白 `(1,1,1)`，避免与 sprite 双重去饱和；inspector 值调整（非改码） |
| **E6** | 代码注释 | `PityProgressBar.cs` 头部注释字段名修正 | ⚪ Low | 注释 `imgFill/imgMark50/imgMark90/matPityFill` 应为 `_imgFill/_mark50/_mark90` 且无 `matPityFill`；文档整洁项 |

### 2.3 可访问性专项核对（MVP 强制 Basic 全 + Standard 主体）

| 特性 | M4 覆盖 | 状态 | 备注 |
|---|---|---|---|
| A 对比度 | 月白 `#E8ECEF` on 深墨 `#122426` ≥4.5:1 | ✅ | 正文/数值/副文均满足 |
| B 高对比 | Sprite 变体 + `UIThemeController` 切换 | ✅ | §2.4 Basic B |
| C 文本缩放 | tabular 防跳 + 弹性 reflow | ✅ | §2.2 |
| D 三重反馈 | 禁用态=形状+glyph+文字+信息灰；出货稀有度=卡框（本切片外） | ✅ | 不靠纯色 |
| E 色盲冗余 | 保底=菱/方形状+数字+颜色 | ✅ | §2.4 Basic E |
| J 触控≥44 | 移动 48 网格（PullButton / CTA / Back） | ✅ | §2.4 Standard J |
| K 字体层级 | Body / Caption / Stat 三档映射 art-bible §3 | ✅（隐式） | 建议文档显式声明以闭合 Standard K |
| I 减少动效 | 脉冲/辉光读 `MotionScale`，静态等效（形状+数字） | ✅ | §2.4 Standard I |
| G CVD | 三重冗余 + 后处理（Standard 尾声项） | ✅ | 不阻塞 MVP |
| H 动态文本 | `_txtSub` 长文案溢出省略/展开 | ⚠️ 待核 | Standard H，低优先（_txtSub 12–13sp 短句，溢出风险低） |

**结论**：Basic 全项 + Standard J/K/I/G 已覆盖；H 待 `_txtSub` 溢出核对（低优先）。无 Comprehensive 要求（MVP 不铺 L/M/N/O/P，仅接口预留）。

---

## 3. 待 engineering-lead 评估项待办清单

> 供主理人后续分派 engineering-lead。**仅含 M4 美术相关项**；gacha-screen-mvp §7.2 的 H1–H4（保底阈值/卡池元数据/式神元数据/currency_changed 触发）属数据接口层，不在本清单，已另跟踪。

| # | 项 | 建议优先级 | 一句话说明 | 美术侧已就绪？ |
|---|---|---|---|---|
| 1 | PullButton Pity-Armed 态代码钩子 | 🟠 Medium | 保底临近态（≥85）idle 辉光转鎏金→朱砂 + 角标「必出 SSR」，当前 `PullButton.cs` 仅 3 态无钩子 | ✅ 已备 `btn_bg_armed_9slice` + 角标 sprite |
| 2 | PityProgressBar tick 脉冲动画 | 🟠 Medium | 阈值穿越时对应 tick 脉冲（描边加厚+微缩放 0.2s），代码仅返回 Crossing 未播动画 | ✅ 形状+数字静态等效已承载含义 |
| 3 | CurrencyLabel icon 字段方案 | 🟡 Medium | 符箓图标用 TMP 内联 `<sprite>` 或 prefab sibling Image，`_currencyLabel` 仅 TMP 无独立 icon 字段 | ✅ `ico_cur_fulu` 已备，待选挂载方案 |
| 4 | `_disabledTint` 双重去饱和协调 | 🟡 Medium | 烘焙禁用 sprite 接入时把 prefab `_disabledTint` 设白 `(1,1,1)`，避免与 sprite 双重去饱和 | ⚠️ 需 eng 接入禁用 sprite 时一并处理 |
| 5 | `imgTrack`/`matPityFill` 序列化评估 | ⚪ Low | 若需轨道增强 / 渐变材质独立调参，评估增 `[SerializeField]` 字段；否则沿用 `_imgFill`，美术已就绪无阻塞 | ✅ 已按现有字段落地 |
| 6 | `PityProgressBar.cs` 注释字段修正 | ⚪ Low | 修正头部注释字段列表以匹配现代码（`_imgFill`/`_mark50`/`_mark90`，无 `matPityFill`） | ✅ 纯文档整洁项 |

---

## 4. 风险与建议

- **R1（硬缺口）**：V1 / V2 实跑验证是 M4 美术「真接入」闭环唯一硬缺口。建议排入有 Unity 环境后的首个验证窗口，产出 **prefab 截图 + SpriteAtlas 打包清单 + 9-slice Border 配置截图** 作为闭合证据。
- **R2（可见瑕疵风险）**：E5（`_disabledTint` 双重去饱和）若遗漏，禁用态会去饱和过重（可见瑕疵，非阻断）。建议接入 `btn_bg_disabled_9slice` 时一并把 prefab `_disabledTint` 设白。
- **R3（已知未接）**：E1（Pity-Armed）/ E2（tick 脉冲）为规格内视觉项但未接钩子，不影响 MVP 功能验收（三态 + 静态冗余已够），可列为 M4.x 增强。
- **建议排期**：主理人可先**批准文档闭环**（§1），将 V1/V2 列为验证待补、E1–E6 分派 engineering-lead；美术侧在验证窗口前资产可继续产出（§7.1 interim 占位已可跑交互，业务零改）。

---

## 5. 一句话结论

四元素终稿规格**文档层已就绪、可批准闭环**；M4 美术质量门判定 **CONCERNS** —— 纸面闭环成立，但「终稿真接入 / Unity 验证」未做（V1/V2）且 6 项 eng 钩子待评估（E1–E6），均非规格缺陷，排期验证 + 分派 eng 即可收口。
