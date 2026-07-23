# 仙侠卡牌 · MVP 抽卡屏交互/状态规格（UGUI 落地版）

> **阶段**：M3 抽卡表现与 UI（MVP 切片）
> **引擎/平台**：Unity UGUI（Canvas + Prefab + 锚点），目标平台 **Android（IL2CPP）**，移动竖屏为主
> **对齐基线**：`design/ux/ux-spec.md` §2.2 Summon、 `art/art-bible.md`（§3/§5/§7/§8）、`art/accessibility-spec.md`（Basic/Standard/Comprehensive）、`docs/architecture/adr/adr-001-responsive-ui.md`、M2 已落地 `GachaManager`/`IGachaService`/`GachaRollEngine`
> **编写**：design-strategist（文策渊）
> **范围裁剪**：本规格只覆盖 MVP 切片 = **单抽/十连按钮 + 出货结果展示 + 基础卡牌翻面动画 + 保底进度条**；完整 Summon 屏（概率公示全量、羁绊序章全叙事、每日免费十连 UI、多卡池详情 hover）不在本切片内，相关项标注为「MVP 外/延后」。

---

## 0. 与现有文档的差异与落地口径（必读）

### 0.1 一句话差异
> 本规格是 `ux-spec.md §2.2` 的 **UGUI 翻译 + MVP 范围裁剪版**：把 Godot `Control/Container` + `UIThemeController` 响应式描述，重写为 Unity `Canvas + Prefab + 锚点` 可直接落地的结构/状态/接口规格，并只保留「单抽十连 / 翻面演出 / 结果列表 / 保底条」四块，删去概率公示全量、每日免费十连、完整羁绊序章等 MVP 外内容。

### 0.2 引擎语义翻译表（Godot 概念 → UGUI 落地）
| 现有文档概念（Godot 视角） | UGUI 落地等价 | 备注 |
|---|---|---|
| `Control` / `Container` 响应式 | `Canvas` + `CanvasScaler`（Scale With Screen Size）+ `Horizontal/Vertical/Grid LayoutGroup` + `ContentSizeFitter` | MVP 只做竖屏单变体 |
| `UIThemeController` 切 `layout_mode` 变体 | `UISkin` ScriptableObject + `UILayoutController`（MVP **仅竖屏变体**，PC 横屏变体延后） | 见 0.3 |
| `AccessibilitySettings` 单例 + `accessibility_changed` | `AccessibilitySettings` 静态单例（C# event `OnChanged`），UI 订阅 | 持有 `high_contrast / reduce_motion / text_scale / color_blind_mode / cvd_filter / performance_mode / dynamic_text` |
| `InputBridge` 抽象意图 | `EventSystem` + 自定义意图组件：`UITap`（=ui_select）、`UIBack`（=ui_back）、`UILongPress`（=long_press，移动看概率；PC hover_peek 延后） | hover_peek 不在 MVP |
| 事件总线 `gacha:shikigami_obtained` | M2 `EventBus` + `GachaShikigamiObtainedEvent`（**同名语义**，C# 类名） | 见 §5 映射 |
| 事件总线 `economy:currency_changed` | M2 `EventBus` + `CurrencyChangedEvent`（需确认 `IEconomyService.Spend` 触发，见 Handoff H4） | — |
| tabular nums | TextMeshPro `fontFeatureSettings = "tnum"` 或等宽数字 TMP 字体 | 所有数值文本强制 |

### 0.3 双端适配策略（对 ADR-001 的 MVP 偏离说明）
- **ADR-001 原决策**：单套 UI 描述 + 断点驱动布局切换，不另出独立场景。
- **MVP 实际落地**：目标平台为 **Android 竖屏（<768 列堆叠变体）**，MVP **只构建这一个竖屏变体**，不实现断点切换逻辑。`CanvasScaler` 锁定竖屏参考分辨率，所有锚点按竖屏布局。
- **为何偏离**：lean 阶段只为 Android 交付，构建变体切换逻辑（ADR-001 的 `layout_mode` 变体）属冗余成本（R3 精神：避免双份维护，但也不提前为无平台做抽象）。
- **回归路径**：后续若上 PC 横屏，新增 `UILayoutController` 监听 `Screen.width/height` 断点（≥1024 切横屏多栏变体），复用同一套 Prefab 仅切换布局组参数——届时再补 ADR-001 的变体逻辑，不破坏本规格。
- **结论**：MVP 不违反 ADR-001 的「单一真源」原则，只是把「多变体切换」推迟到确有第二端时。

---

## 1. 屏幕状态机（MVP 六态）

状态：`Idle` / `PoolSelected` / `Rolling` / `Reveal` / `ResultList` / `InsufficientCurrency`。
> 注：`InsufficientCurrency` 是 `PoolSelected` 的「可支付性子态」——卡池绑定**保持**，仅可支付性与引导 CTA 变化；因此从 PoolSelected 进入、恢复可支付后回到 PoolSelected。

### 1.1 各状态定义

| 状态 | UI 表现 | 可交互元素 | 进入条件 | 退出条件 |
|---|---|---|---|---|
| **Idle** | 屏幕载入，暂无绑定卡池；PoolTab 轻微高亮引导选择 | BackButton | 从主菜单 `ui_select 抽卡` 进入；`OnEnable` 触发 | MVP 自动绑定默认池（常驻）→ `PoolSelected`（见 1.3 备注） |
| **PoolSelected** | 卡池已绑定；PullButton 显示消耗；PityProgressBar 绑定该池保底；CurrencyLabel 实时 | PoolTab（切换）、PullButton×2（可支付时）、ProbabilityEntry、BackButton | Idle 自动绑定 / 切换 PoolTab / 从 ResultList「再来一次」/ 从 InsufficientCurrency 恢复 | 点 Pull（可支付）→ `Rolling`；货币<单抽消耗 → `InsufficientCurrency` |
| **Rolling** | PullButton 禁用（防连点）；短暂「灵光升腾」闪光演出；保底条轻微脉动 | 仅 BackButton（或锁定输入） | PoolSelected 中点 Pull 且可支付 | `Pull()` 返回结果列表 → `Reveal` |
| **Reveal** | ResultCard 实例化（背面朝上），逐张翻面（scale-X 翻 + 灵光粒子）；SSR 触发紫宸虹光+强音；支持点击跳过 | 点击任意处 = 立即跳到全翻面静态态 | Rolling 结束拿到结果 | 全部翻面完成（或跳过）→ `ResultList`（若有 SSR，BondPrologue 覆盖层排队） |
| **ResultList** | 结果以纵向滚动列表/单卡呈现；显示汇总「获得 X 式神，含 N SSR」；提供后续操作 | 去养成 / 去编队 / 看序章（若有）/ 再来一次 / 返回 / BackButton | Reveal 结束 | 再来一次 → `PoolSelected`；去养成/编队 → 对应屏（ui_back 回 Summon）；返回 → 主菜单 |
| **InsufficientCurrency** | PullButton×2 置灰（信息色+对角划线+「符箓不足」文案，**不靠纯色**）；按钮下方显「去推图产出符箓」CTA（拇指可达） | 去推图 CTA、BackButton、PoolTab（仍可看） | PoolSelected 中 `currency_changed` 使 `fu_lu < 单抽消耗` | 货币≥单抽消耗 → `PoolSelected`；点 CTA → Battle（ui_back 回 Summon） |

### 1.2 状态转移图（文本）
```
[主菜单] --ui_select 抽卡--> [Idle]
[Idle] --OnEnable 自动绑定默认池--> [PoolSelected]
[PoolSelected] --点 Pull(可支付)--> [Rolling] --> [Reveal] --> [ResultList]
[PoolSelected] --货币<单抽消耗--> [InsufficientCurrency]
[InsufficientCurrency] --货币≥单抽消耗--> [PoolSelected]
[InsufficientCurrency] --点 去推图--> [Battle] (ui_back 回 Summon→Idle→PoolSelected)
[PoolSelected] --切换 PoolTab--> [PoolSelected] (重绑保底/消耗)
[ResultList] --再来一次--> [PoolSelected]
[ResultList] --去养成/去编队--> 对应屏 (ui_back 回 Summon)
[ResultList] --返回--> [主菜单]
任意态 --ui_back--> [主菜单]   （Rolling/Reveal 期间锁 ui_back）
```

### 1.3 关键设计决策
- **Idle 在 MVP 实际被瞬间跳过**：`OnEnable` 自动绑定默认池（常驻），避免空屏。状态机仍定义 Idle 以兼容「未来多池需先选池」及无默认池的边界。
- **Rolling/Reveal 锁输入**：防重复 Pull 与状态错乱；ui_back 在两者期间禁用（UX §1 跳转规则：放弃仅战斗回主菜单，抽卡内进行中不丢失）。
- **InsufficientCurrency 必须显「去哪产出」引导**（UX §4 卡点#1，全局可读性最高优先）：**仅置灰按钮不满足 MVP 验收**，必须出现「去推图产出符箓」CTA。
- **BondPrologue（羁绊序章）MVP 范围**：仅当本次获得 **SSR** 时，在 Reveal 结束后弹出 1–2 屏序章（锚点4 鎏金描边面板）。非 SSR 不弹。完整「出货即序章」全量叙事延后。

---

## 2. UGUI 结构草案

### 2.1 Canvas 与全局设置
- **Canvas**：Render Mode = `Screen Space - Overlay`（MVP 无需 3D 翻转相机；翻面用 scale-X，见 §3）。
- **CanvasScaler**：UI Scale Mode = `Scale With Screen Size`；Reference Resolution = **1080 × 2340**（Android 竖屏常见）；Screen Match Mode = `Match Width Or Height`，**Match = 1（Height）**（竖屏锁定纵向比例，宽度自适应）。
- **EventSystem**：场景必备（M2 标准，非 Handoff）；所有可交互用 `IPointerClickHandler`/Button。
- **SafeArea**：根节点包一层 `SafeAreaAdapter`（读 `Screen.safeArea` 内缩，处理 Android 刘海/挖孔），保证顶栏/底按钮不被遮挡。
- **TextMeshPro 强制**：所有文本走 TMP；数值（保底/货币/ATK/HP）走 tabular（`fontFeatureSettings="tnum"`）；正文黑体、标题书法体仅装饰。

### 2.2 Canvas 层级（移动竖屏）
```
Canvas (Overlay, Scaler 1080x2340, Match=Height)
└─ SafeAreaAdapter (stretch, 内缩 safeArea)
   └─ SummonScreen (root, stretch)
      ├─ TopBar [anchor: top-stretch]
      │   ├─ CurrencyLabel        (符箓 icon + tabular 数字, 监听 currency_changed)
      │   └─ BackButton          (ui_back→主菜单, ≥44px)
      ├─ PoolTabBar [anchor: top-stretch, 位于 TopBar 下]
      │   ├─ PoolTab_常驻        (Toggle; 选中态=加厚边框+图标态, 非纯色)
      │   └─ PoolTab_新手        (Toggle; 子标「前20抽半价·必出SR」)
      ├─ CenterStage [anchor: middle-stretch, 弹性]
      │   ├─ PityProgressBar [anchor: top of center]
      │   │   ├─ BarBg           (玉质感半透面板)
      │   │   ├─ BarFill         (Image, Horizontal fill)
      │   │   ├─ SoftMarker      (50 软保底刻度, 图标+形状, 非纯色)
      │   │   ├─ HardMarker      (90 硬保底刻度, 图标+形状)
      │   │   └─ PityText        (tabular "X/90" + "距保底 Y 抽"/"软保底生效")
      │   ├─ RevealArea [anchor: center]   (运行时实例化 ResultCard)
      │   │   └─ ResultCard (Prefab, 见 2.4；默认可空)
      │   └─ ProbabilityEntry   (Button/链接 → ProbabilityPopup, 点击展开)
      ├─ PullButtonGroup [anchor: bottom-stretch, 全局底部 Tab 之上]
      │   ├─ PullButton_Single  (符箓消耗标, ≥48px)
      │   ├─ PullButton_Ten     (十连消耗标, ≥48px, 主 CTA 更大)
      │   └─ InsufficientCTA    (默认隐藏; 「去推图产出符箓」, InsufficientCurrency 显)
      └─ Overlays [anchor: stretch, 最高层级]
          ├─ ProbabilityPopup   (玉质面板 + tabular 概率表, 默认隐藏)
          ├─ BondProloguePopup  (锚点4 鎏金描边面板, SSR 触发, 默认隐藏)
          └─ ResultSummaryBar   (ResultList: 「获得 X / 含 N SSR」, 默认隐藏)
```
> 全局底部 Tab（抽卡/图鉴/养成/编队/推图）属主菜单导航层，不在本屏内；本屏 PullButtonGroup 置于其上方。

### 2.3 锚点策略
- **TopBar**：top-stretch（左对齐货币、右对齐返回）。
- **PoolTabBar**：top-stretch（HorizontalLayoutGroup，各 Tab 等权）。
- **CenterStage**：middle-stretch（纵向用 VerticalLayoutGroup：保底条→Reveal区→概率入口）。
- **RevealArea**：十连用 `ScrollRect + VerticalLayoutGroup`（单列纵向列表，对齐 UX §2.2 移动「十连折叠为结果列表」）；单抽居中单卡。
- **PullButtonGroup**：bottom-stretch（两按钮 HorizontalLayoutGroup，十连占更大权重）。
- **Overlays**：stretch 全屏置顶，层级最高。
- **安全热区**：所有可交互 ≥44×44，移动按 48×48 网格落（对齐 art-bible §11 移动 48）；按钮间距 ≥8px（8 倍数栅格）。

### 2.4 ResultCard Prefab 结构（运行时实例化）
```
ResultCard (RectTransform, LayoutElement)
├─ CardBack        (Image, 翻面前显示; 灵光升腾背面图)
├─ CardFront       (Image, 翻面后显示)
│   ├─ Frame       (Image, 稀有度框 sprite: N/R/SR/SSR, 按 Rarity 切换)
│   ├─ CornerStars (1–3 角星 sprite, 按 Rarity 数量摆放; 非纯色冗余)
│   ├─ Portrait    (Image/RawImage, 式神立绘, 占卡面 60%+)
│   ├─ RarityBanner(Top: "R/SR/SSR" 文本+小 glyph)
│   ├─ NameBanner  (Bottom: 式神名 TMP)
│   ├─ StatBar     (ATK/HP tabular; MVP 可极简, 详情延后 Codex)
│   └─ SsrHolo     (Image, SSR 专属: 紫宸虹光扫光; 读 MotionScale)
└─ FlipController   (MonoBehaviour: scale-X 翻 + 灵光粒子; 读 reduce_motion)
```
- **稀有度三重冗余（Basic E）**：颜色（紫宸/鎏金/青碧/素灰）+ 边框纹理（N 素边/R 青碧细边/SR 鎏金浮雕+角饰/SSR 紫宸虹光）+ 角星数量（1/2/3）。**不靠纯色**。
- **翻面实现（Canvas 友好）**：`scaleX: 1 → 0`（切到 Front，swap Back/Front 显隐）→ `scaleX: 0 → -1`（或直接 0→1 配 Front）。避免 3D 旋转相机，省一个 RenderTexture。

---

## 3. 交互流（单抽/十连 → Pull → 事件 → 翻面 → 结果列表 → 货币）

### 3.1 主链路（以十连为例）
1. 用户点 `PullButton_Ten`（`ui_select`）。
2. UI 前置校验：当前池 `fu_lu ≥ tenCost`（tenCost 来自 Handoff H2 `GetPullCost`）。不足则**不进入 Rolling**，转 `InsufficientCurrency`（显示去推图 CTA）。
3. 校验通过 → 状态 `Rolling`：禁用 PullButton×2、Back；播放「灵光升腾」闪光（~0.8s）。
4. **调用 `var results = gacha.Pull(poolId, 10);`**（同步返回 `IReadOnlyList<GachaResult>`，M2 实现）。
   - ⚠️ **关键**：`Pull` 内部**同步**触发 `GachaShikigamiObtainedEvent`（每张一张）与 `currency_changed`（每扣一次）。这些事件在 `Pull()` 返回**前**已 firing。
   - **UI 事件订阅者规则**：`GachaShikigamiObtainedEvent` 处理器**只做轻量副作用**（如标记 Codex「新」、统计），**禁止在处理器内实例化 Card/起协程**（会重入且早于 Reveal 准备）。**翻面演出以 `results` 返回列表为权威有序源**，逐张驱动。
   - `currency_changed` 处理器：CurrencyLabel **直接置绝对值**（非累加），多次 firing 安全。
5. `Rolling` 结束 → 状态 `Reveal`：按 `results` 顺序实例化 ResultCard（背面），逐张翻面（stagger ~0.15s，单张 ~0.4s）。
6. 翻面中遇 SSR → 该卡 `SsrHolo` 紫宸虹光 + 音频 `sfx_gacha_ssr_sting`（见 §10）。
7. 全部翻完（或用户点击跳过 → 立即全静态翻面）→ 状态 `ResultList`：显 `ResultSummaryBar` + 后续操作按钮。
8. 若含 SSR → 排队 `BondProloguePopup`（1–2 屏，锚点4 鎏金面板），用户关闭后回到 ResultList。
9. 货币已通过 `currency_changed` 实时更新；保底条通过 `GetPity(poolId)` 在 ResultList/PoolSelected 重绑。

### 3.2 按钮禁用条件（符箓不足）
| 按钮 | 禁用条件 | 禁用视觉（不靠纯色，Basic） |
|---|---|---|
| PullButton_Single | `fu_lu < singleCost(pool)` **或** 处于 Rolling/Reveal | 信息色 `#8A9599` 置灰 + 对角划线 + 文案「符箓不足」 |
| PullButton_Ten | `fu_lu < tenCost(pool)` **或** 处于 Rolling/Reveal | 同上 |
| 两者同时不可支付 | → 进入 `InsufficientCurrency`，显「去推图产出符箓」CTA | CTA 高亮可达（≥48px） |

- **singleCost / tenCost 来源**：M2 `PullCost` 为 `private`，UI 不可直接调用 → 需 Handoff H2 `GetPullCost(poolId, count)`（覆盖新手半价：前 20 抽偶数位 0 符箓）。
- **新手池特例**：前 20 抽内 `PullCost` 可能为 0 → 该阶段 Single/Ten 几乎恒可支付；但仍受 Rolling/Reveal 锁。

### 3.3 输入意图映射（UGUI）
| 意图 | UGUI 实现 | MVP 范围 |
|---|---|---|
| ui_select | `IPointerClickHandler` / Button | ✅ 全按钮 |
| ui_back | BackButton + Android 系统返回（`onBackPressed` 自定义，非退出 App） | ✅ |
| long_press | `UILongPress`（PointerDown 计时 ~400ms）→ 看概率/详情 | ✅ 移动看概率 |
| hover_peek | PC 悬停；MVP 移动无 hover | ❌ 延后（PC 变体时补） |

---

## 4. 保底进度条（PityProgressBar）

### 4.1 数据与公式
- **当前保底计数**：`gacha.GetPity(poolId)` ✅（M2 已暴露，读 `_profile.Pity[poolId]`）。
- **阈值（软/硬）**：M2 引擎读 `pool.SoftPity` / `pool.HardPity`（配置驱动），但 **GachaManager 未暴露** → 需 Handoff H1 `GetPityThresholds(poolId) → (soft, hard)`。MVP 暂按 UX §2.2 设计值 **软=50 / 硬=90** 写死常量，**但禁止写死进条逻辑**，应从 H1 读取以避免与配置漂移。
- **填充公式**：
  - `fillRatio = clamp(GetPity(poolId) / hard, 0, 1)`
  - `BarFill.fillAmount = fillRatio`
  - `PityText = "{pity}/{hard}"` + 副文：
    - `pity < soft`：`"距保底还有 {hard-pity} 抽"`
    - `pity ≥ soft`：`"软保底生效·SSR概率提升"`（图标+文本，非纯色）
    - `hard - pity == 1`：`"下抽必出 SSR"`（图标+文本强提示）
- **不跨池**：切换 PoolTab 时 `poolId` 变 → 重绑 `GetPity(newPool)` + `GetPityThresholds(newPool)`，进度条**不保留/不混合**旧池值（动画可 quick-tween 或瞬切）。

### 4.2 边缘情况（≥3）
1. **新池 pity=0**：条空，`"0/90 距保底 90 抽"`。
2. **硬保底临界（pity=89）**：`"下抽必出 SSR"` 强提示（图标+文案，非纯色），填充≈98%。
3. **切池中途**：瞬间重绑新池 pity，无跨池污染；若 reduce_motion 则瞬切无 tween。
4. **新手池首抽强制 SR**（`ForcedStarter`）：Pull 后 pity 重置 0 → 条回空，需监听结果或下次 `GetPity` 刷新。
5. **reduce_motion 开**：数值/文本照常更新，仅去 tween/脉动（Standard I 静态等效）。

### 4.3 视觉（给美术，详见 §9）
- 玉质感半透条 + 鎏金描边；SoftMarker(50)/HardMarker(90) 用**图标+形状**刻度（非纯色）。
- 填充色：常规青碧 `#4FA39B`；`pity≥soft` 渐变至鎏金 `#CBA75C`/紫宸 `#8B6DB3` 示意提升——**但须配文本标签**（不靠色）。

---

## 5. 事件映射（M2 真实类型 → UX 命名）

| UX 命名（ux-spec §0） | M2 真实类型（C#） | UI 消费方 |
|---|---|---|
| `gacha:shikigami_obtained` | `GachaShikigamiObtainedEvent { ShikigamiId, Rarity, PoolId }` | Reveal 副作用（Codex「新」标记）；**翻面以 `Pull()` 返回列表为权威源** |
| `economy:currency_changed` | `CurrencyChangedEvent`（需确认 `IEconomyService.Spend` 触发，H4） | `CurrencyLabel` 实时置绝对值 |
| （无） | `TelemetryGachaPulledEvent` | 分析用，UI 不消费 |

> UI 层只 `EventBus.Subscribe<>`，不 `import` GachaManager/ EconomyManager → 无环（对齐 ADR 解耦红线）。

---

## 6. 可访问性落地口径（MVP 强制 Basic 全项 + Standard 主体）

### 6.1 Basic（上线底线，全部满足）
| 项 | UGUI 落地 |
|---|---|
| **A 对比度** | 文本色用 art-bible 调色板；正文月白 `#E8ECEF` on 深墨 `#122426` ≥4.5:1；大标题 ≥3:1。禁用纯黑底+纯白字（户外强光，§2.3）。 |
| **B 高对比** | `AccessibilitySettings.high_contrast` 切换 `UISkin` 高对比覆盖层（深墨+月白+描边/投影双边界），持久化。 |
| **C 文本缩放 100–130%** | `text_scale` 乘到 TMP 字号；LayoutGroup + ContentSizeFitter 弹性 reflow 不破版；**所有数值 tabular（tnum）** 防跳。 |
| **D 三重反馈** | 出货稀有度 = 颜色+边框纹理+角星（§2.4）；本屏无战斗伤害，D 由卡框稀有度冗余承接。 |
| **E 色盲冗余** | 稀有度三重（颜色+边框+角星 1/2/3）；保底条 Soft/Hard 刻度用图标+形状；**不靠纯色区分**。 |

### 6.2 Standard 主体（MVP 落地项）
| 项 | UGUI 落地 |
|---|---|
| **J 触控≥44×44** | PullButton/PoolTab/Back/CTA 全部 ≥48×48（移动网格）；构建管线 lint 校验。 |
| **K 字体层级** | H1–H4/Body/Caption/Stat 六档 TMP 样式；标题书法体仅装饰，正文黑体。 |
| **I 减少动效** | `MotionScale`（reduce_motion 时=0）；翻面/紫宸扫光/保底脉动读该值；**关动效时保留静态等效**（卡框+角星+名+数字立即可见）。 |
| **G CVD** | 三重冗余之上加保障；MVP 以 dev 工具+美术审查落地，玩家端 CVD 滤镜作 Standard 尾声项（不阻塞 MVP）。 |
| **H 动态文本** | TMP 溢出走省略号+展开；尊重 OS 字体放大偏好。 |

---

## 7. 与 M2 的接口契约

### 7.1 M2 已具备（✅ 直接可用）
- `IGachaService.GetPity(string poolId) → int` ✅（保底条当前值）
- `IGachaService.GetProbabilities(string poolId) → IReadOnlyDictionary<string,double>` ✅（概率公示弹窗）
- `IGachaService.Pull(string poolId, int count = 1) → IReadOnlyList<GachaResult>` ✅（主入口；同步返回有序结果）
- `GachaResult { ShikigamiId, Rarity, PoolId, ForcedStarter }`（翻面/汇总数据源）
- `EventBus` + `GachaShikigamiObtainedEvent` / `TelemetryGachaPulledEvent` ✅

### 7.2 需 M2 补充（Handoff 给 engineering-lead）
| ID | 缺口 | 建议签名 / 方案 | 优先级 | 影响 |
|---|---|---|---|---|
| **H1** | 保底阈值（soft/hard）未暴露，进度条无法渲染刻度 | `GetPityThresholds(string poolId) → (int soft, int hard)`（读 `pool.SoftPity/HardPity`） | 🔴 Critical | 保底条刻度/「软保底生效」判断 |
| **H2** | 卡池元数据 + 消耗未暴露（`PullCost` 为 private） | `GetPoolList() → IReadOnlyList<PoolMeta>`（id, displayName, type, starterSrId, halfPriceNote）；`GetPullCost(string poolId, int count) → int` | 🔴 Critical | PoolTab 渲染、按钮消耗标（含新手半价） |
| **H3** | `GachaResult` 无式神名/立绘/五行/羁绊 | `IShikigamiCatalog.GetMeta(string id) → { displayName, portraitKey, element, bondId }` | 🟠 Important | ResultCard 内容（名/立绘/五行形状） |
| **H4** | 确认 `IEconomyService.Spend` 触发 `currency_changed` | 接口契约确认（UI 依赖该事件更新 CurrencyLabel） | 🟠 Confirm | 顶栏货币实时性 |
| **H5** | 逐张翻面用返回列表驱动（OK）；事件内联 firing 已处理 | 可选：`PullAsync`/回调流式 API（未来事件驱动渐进演出） | ⚪ Optional | 非 MVP 必需 |

> 设计决策（非缺口）：**卡池选择态由 UI ViewModel 持有**，`Pull(poolId,count)` 显式传 poolId；**不需要** `GetCurrentPool()`（M2 无此缺口）。若 engineering 希望集中管理可选加 `SetCurrentPool/GetCurrentPool`，MVP 不需要。

---

## 8. 给 art-director 的资产需求清单
（同步抄送 teammate: art-gacha-spec）

1. **卡框 sprite ×4 稀有度**（art-bible §5 / 锚点4）：N 素灰素边 / R 青碧细边 / SR 鎏金浮雕边+角饰 / SSR 紫宸虹光边+3 钻星。9-slice 或独立 sprite；**灰度下边框纹理/角星仍清晰**（Basic E）。
2. **卡背 sprite**（翻面前）：灵光升腾主题（玉质面板+云纹/符文），与卡框尺寸一致。
3. **角星 sprite ×3**（1/2/3 星 or 菱形），按稀有度摆放锚点。
4. **翻面 VFX**（基础）：灵光粒子爆发（小，省粒子，对齐 §6 I 可关）；MVP 用 scale-X 翻，无需 3D。
5. **SSR 紫宸虹光（锚点4）**：动态光扫 shader/动画纹理（读 MotionScale，reduce_motion 时静态显示边框不扫）；紫宸 `#8B6DB3` + 鎏金 + 青碧 + 月白。
6. **保底条视觉**：玉质半透条 + 鎏金描边；Soft(50)/Hard(90) 刻度图标（形状+图标，非纯色）；「距保底/Y抽」「软保底生效」「下抽必出SSR」标签牌（鎏金描边）。
7. **PoolTab 视觉**：常驻/新手 两态（选中=加厚边框+图标态变化，非纯色）+ 新手「前20抽半价·必出SR」子标。
8. **CurrencyLabel 图标**：符箓 `fu_lu` 线描金图标（24/48 网格）。
9. **ProbabilityPopup 面板**：玉质面板 + tabular 概率表样式（SSR/SR/R/N 各档）。
10. **BondProloguePopup 面板**：锚点4 鎏金描边面板（1–2 屏叙事容器，含立绘窗）。
11. **InsufficientCTA 视觉**：高亮可达按钮（去推图产出符箓），与禁用态按钮强对比（形状/图标区分，非纯色）。
12. **静态等效资产**：上述所有动效的「静态终态」版本（reduce_motion 时直接显示，无动画）。

---

## 9. 给 audio-director 的音频触发点清单
（同步抄送 teammate: audio-gacha-spec）

| 触发点 | 事件/交互 | 建议音效 ID | 备注 |
|---|---|---|---|
| 按钮点击（单/十） | `PullButton` tap | `sfx_gacha_click` | 基础 UI 反馈 |
| 卡池切换 | `PoolTab` tap | `sfx_gacha_tab` | 轻提示 |
| 翻面演出（每张） | Reveal 逐张翻 | `sfx_gacha_flip` | 可随稀有度微调音高/增益 |
| SSR 出货 | Reveal 中遇 SSR | `sfx_gacha_ssr_sting` | 英雄时刻强音 + 紫宸虹光同步 |
| 货币不足/禁用反馈 | 点禁用按钮 or 进 InsufficientCurrency | `sfx_gacha_deny` | 否定反馈（非纯色亦可听） |
| 结果确认/关闭 | ResultList 操作 | `sfx_ui_confirm` | 通用确认 |
| 保底临近（可选） | pity 跨 soft/hard | `sfx_gacha_pity_near` |  optional，增强预期 |
| 抽卡屏环境音（可选） | 驻留 Summon 屏 | `amb_summon` | 氛围，可随 reduce_motion/性能模式降 |

> 音频也需遵循 reduce_motion/性能模式：强动效/强音在相关开关下提供静音或弱化等效（accessibility N 音频可视化可由 later 补）。

---

## 10. 工程 Handoff 汇总（给 engineering-lead）
见 §7.2：**H1** 保底阈值暴露 / **H2** 卡池元数据+消耗暴露 / **H3** 式神元数据解析 / **H4** 确认 currency_changed 触发 / **H5** 可选异步 Pull。
**不改动任何 M2 `.cs`**；以上为 M2 需新增/暴露的查询方法契约。

---

## 11. 假设与待确认
1. MVP **不含**每日免费十连 UI（UX §6 note 3 为 Phase 4 定稿项）；含则补顶栏独立额度格 + 十连按钮文案。
2. 概率公示弹窗 MVP 仅做「点击展开基础概率表」（GetProbabilities ✅ 已够），完整概率/详情延后。
3. 羁绊序章 MVP 仅 SSR 触发 1–2 屏；全量「出货即序章」延后。
4. 参考分辨率 1080×2340 为 Android 典型竖屏；若目标机不同，调 CanvasScaler Reference 即可，布局不变。
5. `CurrencyChangedEvent` 类型名以 M2 实际命名为准（本节用 UX 命名映射）。

---
**一句话总结**：本规格把 `ux-spec.md §2.2` 从 Godot `Control/UIThemeController` 响应式描述，重写为 Unity UGUI `Canvas+Prefab+锚点` 的 MVP 切片落地规格（六态状态机 / 竖屏单变体结构 / Pull→事件→翻面→结果列表链路 / 保底条 / Basic+Standard 可访问性），并标出 M2 需补的 H1–H4 接口 Handoff。
