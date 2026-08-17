# 仙侠卡牌 · M4 抽卡 UI 美术终稿规格（UI 资产全接入）
**Task**：ART-M4-UISPEC-001（High）　**切片**：M4 灰盒占位 → 美术终稿　**引擎/平台**：团结引擎 1.9.3 / UGUI / Android 竖屏（参考分辨率 1080×1920，Match=Height）
**聚焦**：PullButton / PityProgressBar / CurrencyLabel / InsufficientCta 四元素「UI 资产全接入」
**编写**：art-director 林绘澄　**对齐**：art/art-bible.md（§2/§3/§5/§7/§8/§10）、art/gacha-ui-asset-spec.md（§0/§4/§5/§7）、art/accessibility-spec.md（Basic/Standard）、design/ux/ux-spec.md（§2.2/§3.2/§4）、design/gdd/m3-ui-closeout.md、design/ux/gacha-screen-mvp.md

> **范围**：把 M3 灰盒占位替换为美术终稿。本规格只出资产/视觉/字段映射与替换接口，不写实现代码、**不改任何 `.cs`**。
> **约束**：颜色一律经 `UIThemeController` 的 `COLOR_*` 常量落地（CLAUDE.md 硬约束）；本规格列出的 HEX 是**美术源资产设计 token**（来自 art-bible §2），运行时若需高对比/CVD 切换则提供 Sprite 变体，不靠硬编码。

---

## 0. 视觉身份对齐结论（必读）

- ✅ **已找到完整美术圣经** `art/art-bible.md`（九节齐全：视觉基调 / 色板 / 字体 / 角色 / 卡牌 / 场景 / UI 语言 / 可访问性 / 锚点 / 五行形状）。视觉身份已锁定，**无需「⚠️ 需主理人确认视觉方向」**。
- ✅ 另有 M3 抽卡 UI 资产规格 `art/gacha-ui-asset-spec.md`（已覆盖 PullButton §5、PityProgressBar §4、字段约定 §7.3）与 `art/accessibility-spec.md`（Basic/Standard/Comprehensive 三级）。本规格在其之上**收口为四元素的终稿落地表**，并修正其与当前代码字段的偏差（见 §1）。
- 引擎偏差（Godot→Unity/UGUI）已由其 §0 翻译，本规格沿用其口径（路径 `Assets/Art/UI/Gacha/...`、9-slice 用 `Image`+Sprite Border、tabular 用 `TextMeshProUGUI`+tnum）。

---

## 1. 字段一致性诊断（M3 文档 §7.3 vs 实际代码）

> 经比对 `src/unity/Features/Gacha/UI/PullButton.cs`、`PityProgressBar.cs`、`GachaScreenController.cs` 实际字段，发现 **4 处文档/代码不一致**，需主理人知悉（不影响本规格落地，终稿按真实字段接）：

| # | 不一致 | M3 文档 §7.3 写法 | 实际代码 | 处理 |
|---|---|---|---|---|
| **A** | PityProgressBar 标记字段类型 | `imgMark50 / imgMark50`（Image） | `_mark50` / `_mark90` 为 **`GameObject`**（内部包一个 Image 承载 tick sprite） | 终稿把 tick sprite 赋给 `_mark50/_mark90` 下的子 `Image.sprite`，见 §4.4 |
| **B** | 新增副文字段 | §7.3 仅 `txtCount` | 代码多出 **`_txtSub`**（TextMeshProUGUI，「距保底 / 软保底生效 / 下抽必出 SSR」） | 本规格 §4 补 `_txtSub` 资产与文案规范（M3 文档遗漏） |
| **C** | `imgTrack` / `matPityFill` 未序列化 | 列为 PityProgressBar 字段 | 代码**无 `_imgTrack`、`_matPityFill` 序列化字段**；轨道为背景静态 Image（prefab 层级内），渐变经 `_imgFill.material` 赋 `mat_pity_fill` | 终稿：轨道 sprite 直接挂 prefab 背景 Image；渐变材质赋到 `_imgFill` 的 material 槽（非独立序列化字段），见 §4.4 |
| **D** | InsufficientCTA 当前为「红色」 | 引导 CTA 应为 **青碧 `#4FA39B`**（灵力色，ux-spec §4 卡点#1 / gacha-ui-asset-spec §5.1） | 灰盒阶段 `_insufficientCta` 为**红色占位**，偏离规范 | 终稿改为青碧 `#4FA39B`（见 §6）；朱砂 `#C8453A` 仅留作否定/警示 glyph，不作 CTA 主色 |

> 另：`CurrencyLabel` / `InsufficientCta` **无独立 .cs**，实为 `GachaScreenController.cs` 的 `_currencyLabel`（TMP）/ `_insufficientCta`（Button）字段，本规格据此映射。

---

## 2. 通用规范（四元素共用）

### 2.1 色板 token（取自 art-bible §2，作美术源资产设计 token）
| 名称 | HEX | 用途（本切片） |
|---|---|---|
| 青冥（深场） | `#1F3A3D` | 面板底、轨道底 |
| 深墨（文字底） | `#122426` | 文本对比衬底（移动户外/高对比） |
| 青碧（玉光·灵力） | `#4FA39B` | **InsufficientCTA 主色**、灵力/主行动、数值轻描金 |
| 月白 | `#E8ECEF` | 文字、留白、高光、硬标记描边 |
| 朱砂（警示） | `#C8453A` | 保底临近段、否定 glyph（非 CTA 主色） |
| 鎏金（符文·品级） | `#CBA75C` | 按钮云纹边、软标记、边框角饰 |
| 素灰（N 边） | `#9AA3A6` | N 档边 |
| 信息灰（禁用） | `#8A9599` | **禁用态去饱和底色**（与对角划线/锁 glyph 共用，不纯色） |
| 紫宸（SSR） | `#8B6DB3` | 保底满值辉光点缀（非本切片主用） |

### 2.2 tabular 数字设置（Basic C / art-bible §3 Stat 层）
- **Font Asset**：数值 HUD 用**等宽数字 TMP Font Asset**（如 `Font_Num_Tabular`，DIN 感 / 思源黑体 Medium 表格式），于 Font Asset Inspector 启用 **Font Features → `tnum`（Tabular Figures）**。
- **混合文案**（如「十连 -100 符箓」）：数字段用 `<font="Font_Num_Tabular">-100</font>` 包裹，确保等宽不抖动；中文标签用 `Font_SourceHanSans`。
- **inspector 必做**：`_txtLabel` / `_txtCount` / `_txtSub` / `_currencyLabel` 所挂 Font Asset 必须开启 `tnum`；运行时由代码 `.text = "12 / 90"` 直接赋值（无需额外代码）。
- 文本缩放 100–130% 经弹性布局 reflow，tabular 防跳（Basic C）。

### 2.3 9-slice 与格式
- **源分辨率**：UI 控件按屏幕尺寸 ×2 出源（Android ASTC 6×6）；圆角 8–12px（art-bible §7）；玉质感半透面板 + 描边。
- **9-slice 边界**：按钮/面板 `Border = 24px`（L/T/R/B，源 px），保 corners 云纹/符文；进度条轨道 `Border = 16px`；填充用 **Image Fill 模式（Horizontal）**，不走 9-slice。
- **格式**：PNG（透明），进 `SpriteAtlas`（UI 打包 2048²，ASTC）；图标落 24/48px 网格。

### 2.4 可访问性落地分级（不靠纯色）
- **Basic A**：正文月白 `#E8ECEF` on 深墨 `#122426`，≥4.5:1。
- **Basic B**：高对比 Sprite 变体（深墨+月白+描边/投影双边界），`UIThemeController` 切换。
- **Basic C**：全数值 tabular（见 2.2）。
- **Basic E**：CVD 冗余——保底=形状(菱/方)+数字+颜色；五行=图标+形状；稀有度=颜色+边框+角星。
- **Standard G**：CVD 后处理（`COLOR_*` 驱动色相安全重映射）+ 三重冗余兜底。
- **Standard I**：`reduce_motion` 时跳过脉冲/辉光，保留边框+数字+形状静态等效。
- **Standard J**：可交互控件命中区 ≥44×44（移动按 48 网格）。

### 2.5 资产路径（同 M3 §7.1）
```
Assets/Art/UI/Gacha/Sprites/   ← 本切片四元素 sprite 落点（同名替换，业务零改）
```

---

## 3. PullButton（单抽 / 十连 CTA）

### 3.1 资产清单
| sprite 名 | 类型 | 建议尺寸（源 px） | 9-slice | 颜色 | 字体/tabular | 填字段 |
|---|---|---|---|---|---|---|
| `btn_bg_single_9slice` | 9-slice 按钮底（次 CTA） | 400×128 | 24 | 青碧 `#4FA39B` 细边+玉质半透 | — | `_imgBg`（单抽） |
| `btn_bg_ten_9slice` | 9-slice 按钮底（主 CTA） | 560×144 | 24 | 鎏金 `#CBA75C` 云纹边+玉质半透+idle 辉光 | — | `_imgBg`（十连） |
| `btn_bg_pressed_9slice` | 按下态底（同尺寸×2） | 400/560×对应 | 24 | 边框加厚+辉光转暗 | — | `_imgBg`（按下时换图，需 eng 切 sprite） |
| `btn_bg_disabled_9slice` | 禁用态底（**烘焙去饱和+对角划线**） | 400/560×对应 | 24 | 信息灰 `#8A9599` + 对角划线 | — | `_imgBg`（禁用时换图） |
| `ico_st_disable` | 锁 glyph | 96×96 | — | 月白 `#E8ECEF` 描边 | — | `_imgLockIcon` |
| （文案） | TMP 文本 | — | — | 月白 `#E8ECEF` | Body 黑体 ≥16sp + 数字 tabular | `_txtLabel` |

### 3.2 状态变体（视觉参数）
| 状态 | 视觉参数 |
|---|---|
| **常态 Normal** | 玉质半透面板（毛玻璃+描边，圆角 8–12）+ 云纹/符文边（十连鎏金 `#CBA75C`、单抽青碧 `#4FA39B`）；文案+符箓消耗（tabular）；主 CTA 带 idle 辉光（低强度加法）。尺寸：十连 280×72 / 单抽 200×64（Standard J，移动 48 网格）。 |
| **按下 Pressed** | `localScale` 0.96 + 边框加厚 + 辉光转暗 + 描边加亮；换 `btn_bg_pressed_9slice`（或 `_imgBg.color` 暗化兜底）。**不靠纯发光**（Standard I 兼容性）。 |
| **禁用-不足 Disabled** | `interactable=false` + **信息灰 `#8A9599` 去饱和** + **对角划线（烘焙进 `btn_bg_disabled_9slice`）** + **锁 glyph `ico_st_disable` 显** + 文案「符箓不足」。**不纯色失效**（ux-spec §4 卡点#1 / m3-ui-closeout §3.2）。 |
| **保底触发 Pity-Armed（待 eng 确认）** | 当 pity 临近硬保底（如 ≥85）时，主 CTA idle 辉光转为 **鎏金→朱砂** 强调 + 角标「必出 SSR」。`⚠️ 当前 `PullButton.cs` 仅 3 态（Normal/Pressed/Disabled），无此态代码钩子`；终稿先备 `btn_bg_armed_9slice` 与角标 sprite，待 eng 加 `SetPityArmed(bool)` 或 inspector 切换。 |

### 3.3 可访问性（CVD 冗余）
- 禁用态 = **形状（对角划线）+ glyph（锁）+ 文字「符箓不足」+ 信息灰** 四通道；灰度下去饱和+划线+锁仍可辨（Basic E）。
- 主/次 CTA 靠**尺寸 + 边色（鎏金 vs 青碧）+ idle 辉光**区分，不靠单一色（Standard K）。
- 命中区 ≥44×44（Standard J）。

### 3.4 字段映射（→ `PullButton.cs`）
| 资产 | 代码字段 | 备注 |
|---|---|---|
| `btn_bg_*_9slice`（常态/按下/禁用/保底） | `_imgBg` (Image) | sprite 赋 Image.sprite；禁用态建议用烘焙图避免与 `_disabledTint` 双重去饱和（见下） |
| `ico_st_disable` | `_imgLockIcon` (Image) | 禁用时 `SetActive(true)` |
| 文案「十连 -{cost} 符箓」 | `_txtLabel` (TMP) | `.text` 由 `Configure()` 赋值，数字 tabular |
| Button 组件 | `_btn` | `interactable` 由 `SetDisabledInsufficient` 控 |
| `Color _disabledTint = #8A9599` | 序列化字段（非美术资产） | 灰盒占位机制；**终稿建议**：用烘焙禁用 sprite 时把 prefab 中 `_disabledTint` 设为白 `(1,1,1)` 以免双重去饱和（inspector 值调整，非改码） |

---

## 4. PityProgressBar（50 软 / 90 硬 双段）

### 4.1 资产清单
| sprite 名 | 类型 | 建议尺寸（源 px） | 9-slice | 颜色 | 字体/tabular | 填字段 |
|---|---|---|---|---|---|---|
| `pity_track` | 轨道底（玉质半透） | 1200×32 | 16 | 青冥 `#1F3A3D` 底+描边 | — | prefab 背景 Image（**非序列化字段**，见 §1-C） |
| `pity_fill` | 填充（圆角条 alpha 形） | 1200×32 | —（Fill 模式） | 中性 alpha，由 `mat_pity_fill` 渐变着色 | — | `_imgFill` (Image) |
| `mat_pity_fill` | 材质（渐变+ CVD） | — | — | 青碧→鎏金→朱砂 渐变 | — | 赋到 `_imgFill.material` 槽 |
| `pity_mark_50` | 软标记（菱形 tick） | 96×96 | — | 鎏金 `#CBA75C` | — | `_mark50` 内子 Image |
| `pity_mark_90` | 硬标记（方形双刻 tick+锁 glyph） | 112×112 | — | 月白 `#E8ECEF` 描边加粗 + 鎏金 | — | `_mark90` 内子 Image |
| （计数） | TMP 文本 | — | — | 月白 `#E8ECEF` | Body 16–18sp + tabular | `_txtCount`（`"12 / 90"`） |
| （副文） | TMP 文本 | — | — | 青碧 `#4FA39B`（诱明） | Caption 12–13sp + 数字 tabular | `_txtSub`（**新增字段 §1-B**） |

### 4.2 状态变体（视觉参数）
| 状态 | 视觉参数 |
|---|---|
| **常态** | 横向进度条，总程=90；填充 `_imgFill.fillAmount`=比例（青碧低段→鎏金中段→朱砂临近段，经 `mat_pity_fill`）；`_txtCount`=`"12 / 90"`；`_mark50/_mark90` 常显（形状冗余）。 |
| **按下** | 进度条本体非交互；无独立按下态（承载于按钮）。 |
| **禁用-不足** | 不适用（进度条无禁用态）。 |
| **保底触发（过 50 / 过 90）** | 阈值穿越时对应 tick **脉冲 0.2s**（描边加厚+微缩放），**不靠纯色**；`_txtSub` 同步：过 50→「软保底生效，概率渐升」；过 90→「下抽必出 SSR」；满 90 填充转朱砂 `#C8453A` 段 + 紫宸辉光点缀。`⚠️ 脉冲动画需 eng 接 `DetectCrossing` 返回值驱动（当前代码仅返回 Crossing，未播动画）` |

### 4.3 可访问性（CVD 冗余 · 形状+数字+颜色）
- **不靠色区分两段**：50=**菱形**、90=**方形双刻**，**形状本身可辨**；两段均带**数字**「12/90」+ **文字标签**（软50/硬90 由 `_txtSub` 或邻近文案）+ 颜色，三重冗余（art-bible §8 / accessibility E / M3 §4.3）。
- 轨道/填充对比度 ≥4.5:1（Basic A）；高对比模式描边/投影双边界（Basic B）。
- 颜色经 `COLOR_*` + CVD 后处理（Standard G）；色相失真时形状+文字仍传阈值含义。

### 4.4 字段映射（→ `PityProgressBar.cs`）
| 资产 | 代码字段 | 备注 |
|---|---|---|
| `pity_fill` + `mat_pity_fill` | `_imgFill` (Image) | 渐变材质赋 Image.material；`fillAmount` 由 `Bind()` 设 |
| `pity_track` | （背景 Image，无序列化字段） | 挂 prefab 层级作静态底，见 §1-C |
| `pity_mark_50` | `_mark50` (GameObject) | tick sprite 赋其**子 Image.sprite**（`SetActive(true)` 常显） |
| `pity_mark_90` | `_mark90` (GameObject) | 同上 |
| 计数文本 | `_txtCount` (TMP) | `Bind()` 设 `"12 / 90"`，tabular |
| 副文文本 | `_txtSub` (TMP) | **M3 文档遗漏字段**，本规格补：距保底/软保底/必出 SSR 文案，数字 tabular |

---

## 5. CurrencyLabel（符箓余额，顶栏/抽卡屏）

> 实为 `GachaScreenController._currencyLabel`（TextMeshProUGUI），监听 `economy:currency_changed` 绝对值刷新（gacha-screen-mvp §3.1 / m3-ui-closeout §2）。

### 5.1 资产清单
| sprite 名 | 类型 | 建议尺寸（源 px） | 9-slice | 颜色 | 字体/tabular | 填字段 |
|---|---|---|---|---|---|---|
| `ico_cur_fulu` | 符箓货币图标（线描金） | 96×96 | — | 鎏金 `#CBA75C` 细线 | — | 前缀（TMP 内联 `<sprite>` 或相邻 Image） |
| （余额数字） | TMP 文本 | — | — | 月白 `#E8ECEF` | Stat 24–32sp（最小18）+ tabular | `_currencyLabel` |

### 5.2 状态变体
| 状态 | 视觉参数 |
|---|---|
| **常态** | 符箓 icon + 绝对值数字（如 `1280`），tabular 防跳；月白 on 深墨 ≥4.5:1。 |
| **按下** | 不适用（展示型）。 |
| **禁用-不足** | 不适用；但余额 < 单抽消耗时屏进入 `InsufficientCurrency`（见 §6），CurrencyLabel 仅显示绝对值（不置灰，避免与「符箓不足」文案重复）。 |
| **保底触发** | 不适用。 |

### 5.3 可访问性（CVD 冗余）
- icon（符箓形状：卷轴/符纸 glyph）+ 数字 + 月白，三通道；灰度下 icon 形状可辨（Basic E）。tabular 防布局抖动（Basic C）。

### 5.4 字段映射（→ `GachaScreenController._currencyLabel`）
| 资产 | 代码字段 | 备注 |
|---|---|---|
| `ico_cur_fulu` | 相邻 Image 或 TMP `<sprite>` | `_currencyLabel` 仅 TMP；icon 用内联 sprite 或 prefab 内 sibling Image（**小缺口：代码无独立 icon 字段**，建议 eng 用 TMP 内联 sprite 或加 sibling） |
| 余额数字 | `_currencyLabel` (TMP) | `OnCurrencyChanged` 设 `.text = GetBalance("fu_lu").ToString()`，tabular |

---

## 6. InsufficientCta（去推图产出符箓 · 卡点#1 引导）

> 实为 `GachaScreenController._insufficientCta`（Button），仅 `InsufficientCurrency` 态 `ShowInsufficientCta(true)` 显（m3-ui-closeout §3）。发 `GachaAcquireIntentEvent{Reason="battle"}` 由外部接管跳转（H-C1 灰盒已实现）。

### 6.1 资产清单
| sprite 名 | 类型 | 建议尺寸（源 px） | 9-slice | 颜色 | 字体/tabular | 填字段 |
|---|---|---|---|---|---|---|
| `cta_bg_9slice` | 9-slice 按钮底（引导 CTA） | 640×112 | 24 | **青碧 `#4FA39B` 灵力色** + 玉质半透 + 云纹边（**替换当前红色占位 §1-D**） | — | `_insufficientCta` 底 Image |
| `ico_nav_battle` | 去推图 glyph（剑/地图箭头） | 96×96 | — | 月白 `#E8ECEF` 描边 | — | 相邻 Image / TMP `<sprite>` |
| （文案） | TMP 文本 | — | — | 月白 `#E8ECEF` | Body ≥16sp | Button 内 label TMP |

### 6.2 状态变体
| 状态 | 视觉参数 |
|---|---|
| **常态（显式·InsufficientCurrency）** | 青碧 `#4FA39B` 高亮可达按钮 + 去推图 glyph + 文案「去推图产出符箓」；≥48×48（Standard J）；与上方禁用按钮**强对比（形状/图标区分，非纯色）**。 |
| **按下** | `localScale` 0.96 + 描边加亮（同 PullButton 按下逻辑）。 |
| **禁用-不足** | 不适用（CTA 本身恒可点，是引导出口）。 |
| **保底触发** | 不适用。 |

### 6.3 可访问性（CVD 冗余）
- CTA = **青碧形状（圆角面板）+ glyph（剑/地图）+ 文字「去推图产出符箓」** 三通道；与去饱和禁用按钮形成**功能对比**（引导 vs 阻断），不靠纯红/纯灰（ux-spec §4 卡点#1 最高优先 / gacha-screen-mvp §3.1）。
- 「仅置灰按钮不满足 MVP 验收」——CTA 为强制出现项（m3-ui-closeout §3.2）。

### 6.4 字段映射（→ `GachaScreenController._insufficientCta`）
| 资产 | 代码字段 | 备注 |
|---|---|---|
| `cta_bg_9slice` | `_insufficientCta` (Button) 底 Image | **改红色为青碧**（§1-D） |
| `ico_nav_battle` | 相邻 Image / TMP `<sprite>` | 强对比 glyph |
| 文案 | Button 内 label TMP | 文案「去推图产出符箓」 |
| 事件 | `OnInsufficientCta()` | 已 emit `GachaAcquireIntentEvent{Reason="battle"}`（不改码） |

---

## 7. 灰盒 → 终稿过渡建议（占位 sprite 先接 + 替换路径）

> 原则（同 M3 §7.4）：灰盒期可用**纯色/简单形状占位**跑通交互；美术师产出终稿后**同名替换** `Assets/Art/UI/Gacha/Sprites/` 下路径，业务零改。

### 7.1 可立即用工具/AI 生成的占位 sprite 参数（灰盒 interim）
| 目标资产 | 占位参数（工具/AI 生成） | 终稿替换 |
|---|---|---|
| `btn_bg_*_9slice` | 纯色圆角矩形（青碧/鎏金描边 2px，圆角 12px），透明底，PNG 400×128 / 560×144，9-slice 24 | 玉质感半透+云纹边（美术师） |
| `btn_bg_disabled_9slice` | 信息灰 `#8A9599` 圆角矩形 + **对角划线**（白色 2px，45°）+ 透明底 | 烘焙去饱和+划线终稿 |
| `ico_st_disable` | 锁 glyph 线描（月白描边），96×96 透明 | 终稿锁 glyph |
| `pity_track` / `pity_fill` | 灰色圆角长条（track 深灰 / fill 浅青），1200×32 | 玉质轨道 + 渐变填充材质 |
| `pity_mark_50` / `_90` | **菱形** / **方形双刻** 简单形状（金/白描边），96–112px | 终稿 tick（形状冗余不变，仅精修） |
| `ico_cur_fulu` | 符纸/卷轴简笔 glyph（金线），96×96 | 终稿符箓图标 |
| `cta_bg_9slice` | **青碧 `#4FA39B` 圆角矩形**（替换红），640×112 | 终稿引导 CTA |
| `ico_nav_battle` | 剑/箭头简笔 glyph，96×96 | 终稿去推图 glyph |

> AI 生成提示（若用文生图）：flat vector UI icon, transparent background, single solid color `#xxxxxx`, thin stroke, no text, centered, exactly NxN px, xianxia minimal line art。——UI sprite 边界精度要求高，建议优先用矢量/SVG 或 Unity 9-slice 程序化生成，AI 仅作风格参考。

### 7.2 替换流程
1. 美术师按 §3–§6 尺寸/色板产出终稿 PNG → 放入 `Assets/Art/UI/Gacha/Sprites/`（同名覆盖占位）。
2. 进 `SpriteAtlas`（UI 2048²，ASTC 6×6）；9-slice 在 Sprite Editor 设 Border。
3. prefab 中把 sprite 赋到对应字段（§3.4/§4.4/§5.4/§6.4）；`mat_pity_fill` 赋 `_imgFill.material`。
4. **不改任何 `.cs`**：字段名与 M3 文档/代码一致（已按 §1 修正偏差），同名替换即生效。

### 7.3 字段-代码对齐修正（M4 偏差消化 · 已与代码一致 ✅）

> 依据 ART-M4-FIXDOC-001（doc-only，不改码）。本小节为 §1 四处诊断的**闭合记录**：经比对 `src/unity/Features/Gacha/UI/PityProgressBar.cs`、`PullButton.cs`、`GachaScreenController.cs` 实际字段，文档现状已逐字段与运行代码对齐，无需再改文档。

| # | 修正项 | 文档（修正后） | 代码实况 | 状态 |
|---|---|---|---|---|
| 1 | 标记字段类型 | `_mark50` / `_mark90` 记为 **GameObject**（内部子 Image 承载 tick sprite），见 §4.1/§4.4 | `private GameObject? _mark50;` / `private GameObject? _mark90;` | ✅ 一致 |
| 2 | 副文字段 | 补 `_txtSub`（TextMeshProUGUI），副文/数字 tabular，见 §2.2/§4.1/§4.4 | `private TextMeshProUGUI? _txtSub;` 存在且 `Bind()` 赋值 | ✅ 一致 |
| 3 | `imgTrack` / `matPityFill` 未序列化 | 轨道由 prefab 背景 Image 承载；渐变经 `mat_pity_fill` 赋 `_imgFill.material` 槽（非独立序列化字段），见 §1-C/§4.1/§4.4 | 仅序列化 `_imgFill`；**无 `_imgTrack`、`_matPityFill` 字段** | ✅ 一致 |
| 4 | CTA 颜色 | 终稿 InsufficientCta = 青碧 `#4FA39B`（灵力色）；灰盒红为临时偏离，M4 接入改回，见 §1-D/§6.1 | `_insufficientCta` 仅 `Button.SetActive`，色由 prefab/Inspector 控；灰盒红=临时可见性措施 | ✅ 一致 |

**⚠️ TODO（待 engineering-lead 评估）**：#3 当前代码未序列化 `imgTrack` / `matPityFill` 二字段。M4 接入若需「轨道增强」或「渐变材质独立调参」，建议 engineering-lead 评估为 `PityProgressBar` 增 `[SerializeField] private Image? _imgTrack;` 与 `[SerializeField] private Material? _matPityFill;`（或统一经 `_imgFill` 承载）并在 prefab 接好；美术规范已就绪，无需等此 TODO 即可按现有字段落地。

**代码侧遗留提示（非本文档范围·不改码）**：`PityProgressBar.cs` 头部注释仍写「art §7.3：imgFill / txtCount / imgMark50 / imgMark90 / matPityFill」，字段名与现代码不符（应为 `_imgFill / _txtCount / _mark50 / _mark90`，且无 `matPityFill`）。本 §7.3 即其指向章节，建议 eng 顺手修正该注释字段列表。

---

## 8. 回传主理人（Handoff 摘要）

**文档路径**：`design/art/m4-ui-art-spec.md`
**四元素资产清单（每元素 1 行）**：
- PullButton：4×9-slice 底（常态/按下/禁用烘焙对角划线/保底armed）+ `ico_st_disable` 锁 glyph + tabular 文案 → 字段 `_imgBg/_imgLockIcon/_txtLabel/_btn`。
- PityProgressBar：`pity_track/fill`+`mat_pity_fill` 渐变 + `pity_mark_50`(菱)/`_90`(方双刻) + `_txtCount`/`_txtSub` tabular → `_imgFill/_mark50/_mark90/_txtCount/_txtSub`。
- CurrencyLabel：`ico_cur_fulu` 符箓图标 + tabular 余额 → `_currencyLabel`。
- InsufficientCta：青碧 `#4FA39B` `cta_bg_9slice` + `ico_nav_battle` 去推图 glyph + 文案 → `_insufficientCta`（替换当前红色占位）。

**字段不一致**：发现 4 处（§1 A–D）：① 标记字段为 GameObject 非 Image；② 代码新增 `_txtSub` 文档遗漏；③ `imgTrack/matPityFill` 未序列化（轨道挂背景 Image、渐变赋 material 槽）；④ 当前 CTA 红色偏离规范（应青碧）。**以上 4 处均已核对代码并闭合（见 §7.3，已与运行代码一致 ✅）。**
**过渡建议**：灰盒期用纯色/简单形状占位（§7.1 参数）先接，终稿按 `Assets/Art/UI/Gacha/Sprites/` 同名替换、进 SpriteAtlas、9-slice 设 Border，业务零改。
**待主理人/eng 决策**：PullButton「保底触发」态与 PityProgressBar tick 脉冲动画需代码钩子（当前未实现）；CurrencyLabel icon 建议用 TMP 内联 sprite。
