# 仙侠卡牌 · M3 抽卡 UI 专用资产规格（Gacha UI Asset Spec）
**项目**：仙侠卡牌（Xianxia Card Battler）　**切片**：MVP 抽卡表现切片　**UI 框架**：UGUI　**引擎**：团结引擎 1.9.3（Unity 2022.3 LTS）　**平台**：Android（IL2CPP，移动竖屏为主，参考分辨率 1080×1920）　**评审**：solo / lean　**编写**：art-director 林绘澄　**对齐**：art/art-bible.md（§2–§9）、art/asset-spec.md、art/accessibility-spec.md、design/ux/ux-spec.md §2.2

> **范围**：单抽/十连按钮 + 出货结果展示（ResultCard）+ 基础卡牌翻面动画（灵光升腾）+ 保底进度条 + SSR 紫宸虹光峰值演出。本规格**只出资产/视觉/Shader 规格与美术替换接口**，不写实现代码、不产出具体贴图（描述灰盒占位即可），不改动 M2 任何 `.cs`。

---

## 0. 引擎偏差与适配说明（必读）

> ⚠️ **基线文档（art-bible / asset-spec / ux-spec）原为 Godot 4.x（PC+移动）编写**，路径与导入约定（如 `res://assets`、`StyleBoxTexture`、`AtlasTexture`、Godot 导入预设）**不适用于本切片**。本规格按任务要求改以 **Unity 团结引擎 / UGUI / Android IL2CPP** 落地，仅**复用其视觉身份**（色板、稀有度体系、可访问性三级），技术约定全部翻译为 UGUI 口径。

| 维度 | 基线文档（Godot） | 本规格（Unity/UGUI） |
|---|---|---|
| 资源路径 | `res://assets/...` | `Assets/Art/UI/Gacha/...`（见 §7） |
| 九宫拉伸 | `StyleBoxTexture.texture_margin` | `Image` + Sprite `Border`（9-slice） |
| 图集 | `AtlasTexture` 区域引用 | Unity SpriteAtlas（UI 打包 2048²，ASTC） |
| 等宽数字 | `FontVariation` + tnum | `TextMeshProUGUI` + `tnum` OpenType 特性 / 等宽字体 |
| 主题切换 | `Theme.tres` 覆盖 | `UIThemeController`（架构已有）+ 高对比 Sprite 变体 |
| 减少动效 | `MotionScale` | `AccessibilitySettings.reduce_motion` → `MotionScale`（同语义） |
| 压缩 | 移动 ASTC / PC BPTC | Android ASTC 6×6（UI 贴图），立绘 `max size` 降档 |

- **视觉身份强约束不变**：色板（art-bible §2）、稀有度四档配色（§2.2）、卡框结构（§5）、角星 1/2/3 三重冗余（§8 / accessibility E）、SSR 锚点4 紫宸虹光（§9）一律沿用，不得因引擎切换而偏离。
- **性能预算（Android IL2CPP）**：UI 透明 overdraw 控制（全屏 overlay ≤ 1 层）、SpriteAtlas 合批降 drawcall、立绘占位图 `max size` ≤ 512、VFX 粒子上限（普通 ≤ 16 / SSR ≤ 32）以中低端机 30fps 稳帧为底线。
- **待确认（转 engineering-lead）**：SpriteAtlas 用 `Addressables` 还是 `Resources` 同步加载；9-slice 边距数值按最终卡框源图定。

---

## 1. 卡牌框（ResultCard Prefab 视觉规格）

> 出货结果展示卡。复用 art-bible §5 卡框结构 + §8 可访问性角星/边框冗余；同一套资产响应式切换「紧凑态（移动）」，不另出两套图。

### 1.1 尺寸与比例
| 项 | 规格 |
|---|---|
| 卡面比例 | **竖版 2:3**（对齐锚点4 / art-bible §5） |
| 源图分辨率 | **1024×1536**（@2x 设计稿）；运行时 Sprite 按 RectTransform 缩放 |
| 参考设计画布 | 1080×1920；单卡展示约 **360×540**（≈1/3 屏宽），十连以结果列表/横向排布 |
| 立绘占位区 | 卡面 **60–65%**（art-bible §5）；本规格取 **60%**，居中 |
| 信息区 | **35–40%**（顶部稀有度横幅 + 底部式神名/数值条） |
| 圆角 | 8–12px（art-bible §7 控件语言），9-slice 源图预留透明边 |

### 1.2 纵向布局（占卡高百分比）
```
┌─────────────────────┐ 0%   ── 顶部稀有度横幅（10%）：角星 + 稀有度文字
│  稀有度横幅/角星      │ 10%
├─────────────────────┤
│                     │
│   立绘占位窗 60%     │      （RawImage，居中，圆角裁切）
│   （灵光升腾叠加层）  │ 70%
│                     │
├─────────────────────┤ 70%
│  式神名（H 层级）     │      ── 底部信息条（30%）
│  稀有度 + 五行形状    │ 85%
│  ATK/HP tabular 数字 │ 100%
└─────────────────────┘
```
> 信息密度：移动小屏立绘 ≥50%、关键数值 ≥18sp（art-bible §5，本规格结果卡默认紧凑态即满足）。

### 1.3 稀有度四档（N/R/SR/SSR）边框/纹理/角星 三重冗余
> **不靠纯色区分**（art-bible §8 / accessibility E）：颜色 + 边框纹理 + 角星数量，灰度下仍可辨。色值取自 art-bible §2.2。

| 稀有度 | 名称 | 主色 HEX | 边框/纹理 | 角星数 | 角星形态（灰度可辨） | 卡背/底纹 |
|---|---|---|---|---|---|---|
| **N 凡品** | 素灰 | `#9AA3A6` | 素色细线边（无描金） | **0**（无星） | — | 素灰细边卡框 |
| **R 灵品** | 青碧 | `#4FA39B` | 青碧细边（1px 描线） | **1** | 单圆点星（实心圆+描边） | 青碧细边 |
| **SR 宝品** | 鎏金 | `#CBA75C` | 鎏金浮雕边 + 四角角饰（云纹/剑纹浮雕高光） | **2** | 双菱形星 | 鎏金浮雕边 |
| **SSR 仙品** | 紫宸 | `#8B6DB3` | 紫宸虹光描边（全息渐变）+ 动态光扫 overlay（`card_frame_ssr_sweep`）+ 角饰 | **3** | 三钻星（菱形+内高光，钻感最强） | 紫宸虹光边 |

- **角星三重冗余落地**：`star_1` / `star_2` / `star_3` 独立 Sprite，靠**数量 + 形态（圆/双菱/钻）+ 描边强度**区分；N 不显示任何角星（"无星"本身即一档）。角星在顶部横幅内水平排布，单星源图 ≥ 48×48，描边 ≥ 2px 保证灰度对比（accessibility E）。
- **灰度自测**：四档在去色后仍能凭「有无星 / 星数 / 边框纹理（细线→浮雕→虹光）」区分；立绘占位区不承载稀有度信息（避免纯美术风格混淆）。
- **UR（朱金）**：本切片不产出货（MVP 出货范围 N/R/SR/SSR），卡框资产预留 `card_frame_ur` 接口但本规格不展开。

### 1.4 文本区（式神名 / 稀有度，tabular）
- **式神名**：层级 H2（思源宋体/清刻本悦宋感，28–36sp；最小 24sp），月白 `#E8ECEF` 于深墨底 `#122426`，对比度 ≥ 4.5:1（Basic A）。
- **稀有度文字**：`N / R / SR / SSR` 用对应稀有度色 + 描边双边界（不纯色），字号 Body 16–18sp。
- **数值（ATK/HP）**：`TextMeshProUGUI` 启用 **tabular nums（tnum）** 等宽数字，24–32sp（最小 18sp），青碧 `#4FA39B` 极轻描金描边（art-bible §3「数值即资产」）。
- **五行形状标签**：立绘下方常驻「五行图标 + 形状（圆/三角/方）」glyph（锚点3 / accessibility E / art-bible §10），作为第 N 类冗余，与卡框稀有度冗余并列。

---

## 2. 翻面动画 VFX 规格（卡背 → 卡面 · 灵光升腾）

> 基础出货演出。普通（N/R/SR）与 SSR 差异见 §2.3。注明实现方式（Shader/VFX vs 序列帧/Tween）与工程指引。

### 2.1 基础翻面（普通 N/R/SR）
| 参数 | 规格 |
|---|---|
| 时长 | **0.5s**（单卡揭示）；十连按序错峰，间隔 **0.08s**（波浪式） |
| 缓动 | 翻面用 `ease-out cubic`；揭示瞬间（scaleX=0 换面）轻微 `Back.easeOut` 过冲增强"翻出"手感 |
| 视觉意象 | **灵光升腾**：卡面揭示时，立绘窗自底向上涌出一柱柔光（青碧 `#4FA39B` 低强度），伴随少量上飘灵气粒子 |
| 实现方式 | **推荐 2D（纯 UGUI + Tween + Shader 叠加）**，见 §2.4 指引 A；不强制 3D |
| 粒子 | `vfx_summon_rise`：8–16 颗柔光灵气点（additive，上飘+淡出），单次 |
| 音频同步点 | 翻面起手 / 揭示 whoosh / 灵光升腾 chime（见 §8） |

### 2.2 揭示时序（单卡）
```
t=0.00  卡背静止 → 起手（scaleX 1→0.92，轻微下沉）
t=0.20  翻面加速（scaleX 0.92→0）
t=0.25  ★ 换面：Sprite 由 card_back 切 card_face；灵光升腾 shader _Progress 启动
t=0.25→0.5  卡面 scaleX 0→1（ease-out），立绘窗灵光上涌 + 粒子
t=0.50  落定（Back 过冲回正），普通卡静止
```
> 换面瞬间（`t=0.25`）是"揭示"高潮，所有音频/视觉强调点对齐此处。

### 2.3 普通 vs SSR 差异
| 维度 | 普通 N/R/SR | SSR 紫宸虹光 |
|---|---|---|
| 翻面时长 | 0.5s | **0.7s**（含揭示后 0.2s 定格） |
| 灵光色 | 青碧 `#4FA39B` 低强度 | 紫宸 `#8B6DB3` + 鎏金 `#CBA75C` 虹光（见 §3） |
| 粒子量 | 8–16 | **24–32**（峰值演出） |
| 额外演出 | — | 翻面后触发 `card_frame_ssr_sweep` 动态光扫 + 紫宸虹光 bloom（§3），随后进入 idle 全息微闪 |
| 音频 | 普通揭示 cue | SSR 专属 grand sting（§8） |

### 2.4 工程可实现指引
- **指引 A（推荐 MVP·2D）**：单张 `Image` 承载卡面，`RectTransform.localScale.x` 由 1→0（中点换 Sprite 卡背→卡面）→1 完成翻面；翻面期间独立 `RawImage`（或 `Image`）叠加 `mat_rise_glow`（灵光升腾 shader，`_Progress` 由 Tween 0→1 驱动 UV.y 梯度上滚 + 径向柔光 + alpha）；SSR 再叠加 `mat_ssr_rainbow`。**无 render texture、无 3D 相机**，纯 UGUI + Shader/Tween，移动端成本最低。
- **指引 B（可选·Premium 3D）**：透视相机下 `Canvas` 子平面绕 Y 轴 `rotation` 真 3D 翻面，正反两面各一材质（卡背/卡面）。成本更高，仅作后期增强，不影响 MVP。
- **Tween 来源**：DOTween 或 Unity Coroutine；Shader 用 URP/团结自定义 Shader（或 Shader Graph），`_Progress`/`_Time` 统一受 `MotionScale` 控（reduce_motion 时跳过动画直接定格，见 §6）。
- **序列帧？**：不推荐序列帧（立绘动态换图成本高、内存大）；翻面用几何变换 + Shader，粒子用 Sprite 粒子（软光点贴图集），符合 asset-spec §1.6 `vfx_summon_rise` 约定。

---

## 3. SSR 紫宸虹光（视觉锚点 4 · 稀有度峰值演出）

> 锚点4「SSR 仙品卡牌成品」的稀有度峰值演出规格。所有色值取自 art-bible §9 锚点4 / §2.2。

### 3.1 色值（权威）
| 角色 | HEX | 用途 |
|---|---|---|
| 紫宸（主） | `#8B6DB3` | 虹光边框主色、全息渐变核心 |
| 鎏金（点缀） | `#CBA75C` | 边框线脚、角饰高光、钻星内光 |
| 青碧（次辉） | `#4FA39B` | 辅助辉光、灵光升腾底光 |
| 月白（高光） | `#E8ECEF` | 边缘 rim light、钻星高光点 |
| 深墨底 | `#122426` / `#1F3A3D` | 卡面底、对比衬底 |

### 3.2 辉光 / 粒子 / 时长
| 参数 | 规格 |
|---|---|
| 边框辉光强度 | 加法混合（additive）emissive ≈ **1.2–1.6**（HDR 感知；移动端压到 1.2 控 overdraw） |
| 动态光扫 `card_frame_ssr_sweep` | UV 横向/斜向滚动虹光带（紫宸→鎏金→青碧循环），速度慢（周期 ≈ 3–4s） |
| 粒子 `vfx_summon_ssr` | 24–32 颗柔光灵气点（additive，上飘+淡出），峰值爆发 1 次 |
| bloom 总时长 | **1.2s**（翻面 0.7s + 虹光定格 0.5s）后转入 **idle 全息微闪**（轻量 UV 滚动，可被 reduce_motion 关闭） |
| 屏级反馈 | SSR 出货时背景轻微暗角+紫宸氛围光（不抢前景，art-bible §6） |

### 3.3 工程需求
- `mat_ssr_rainbow`：全息边框 shader（UV 滚动 + 调色板内 hue shift），additive rim。
- `mat_rise_glow`：灵光升腾（见 §2.4）。
- `card_frame_ssr_sweep`：光扫 overlay Sprite（透明带，加法混合）。
- 性能：SSR 演出为稀有度峰值，发生频率低（仅出货 SSR），粒子上限 32、bloom 单层，不影响常规帧预算。

---

## 4. 保底进度条（50 软 / 90 硬 双段）

> 对齐 ux-spec §2.2 ③「保底进度条（50 软/90 硬，不跨池）」。视觉样式 + 填充动效 + 阈值提示（须过 CVD，参考 accessibility §8 形状冗余）。

### 4.1 视觉样式
| 项 | 规格 |
|---|---|
| 形态 | 横向进度条，总程 = **90**（硬保底封顶）；轨道玉质半透面板（毛玻璃+描边），圆角 8px |
| 填充 | 横向渐变（青碧 `#4FA39B` 低段 → 鎏金 `#CBA75C` 中段 → 朱砂 `#C8453A` 临近段）；填充受 `mat_pity_fill` 控 |
| **50 软标记** | **菱形 tick（▲/◆ 形状）** + 鎏金 `#CBA75C` + 文字「软 50」；软保底起，出货概率渐升（视觉提示：tick 后填充色转暖） |
| **90 硬标记** | **方形双刻 tick（▣）** + 月白 `#E8ECEF` 描边加粗 + 锁 glyph + 文字「硬 90」；硬保底必出 SSR |
| 数值文本 | `TextMeshProUGUI` tabular：`"12 / 90"`，Body 16–18sp，月白于深墨底 |

### 4.2 填充动效
- 抽卡后填充 **0.4s ease-out** 过渡到新值；十连按累计抽数一次跳进（不逐张）。
- 阈值穿越（过 50 / 过 90）时 tick 做 **0.2s 脉冲高亮**（描边加厚+微缩放），不依赖纯色（结合形状+文字）。

### 4.3 CVD / 形状冗余（accessibility §8 / §10）
- **不靠色区分两段**：50=菱形、90=方形双刻，**形状本身可辨**；两段均带文字标签（「软50」「硬90」）与数字，三重冗余（形状+数字+颜色）。
- 颜色经 `COLOR_*`（鎏金/朱砂）并由 `AccessibilitySettings.color_blind_mode` 做 CVD 重映射（Standard G）；即使色相失真，形状+文字仍传达阈值含义。
- 轨道/填充对比度 ≥ 4.5:1（Basic A）；高对比模式下描边/投影双边界（Basic B）。

### 4.4 工程需求
- `PityProgressBar` Prefab：`Image imgTrack` / `Image imgFill`（9-slice 或 Fill 模式）/ `Image imgMark50` / `Image imgMark90` / `TextMeshProUGUI txtCount` / `Material matPityFill`。
- 热区：进度条本体非交互；但其上方「概率公示」入口与保底说明按钮 ≥44×44（Standard J）。

---

## 5. 按钮（单抽 / 十连 CTA）

> 对齐 ux-spec §2.2 ②。三态 + 尺寸 + 主 CTA 视觉权重。

### 5.1 三态（常态 / 按下 / 禁用-符箓不足）
| 状态 | 视觉 |
|---|---|
| **常态 Normal** | 玉质半透面板（毛玻璃+描边，圆角 8–12px，9-slice）+ 云纹/符文边（鎏金细线 `#CBA75C`）；显示符箓消耗（`-10` / `-100` 等 tabular）；主 CTA（十连）带轻微 idle 辉光 |
| **按下 Pressed** | `localScale` 0.96 + 边框加厚 + 辉光转暗 + 描边加亮；提供"按下即抽"的确定反馈（不靠纯发光，accessibility §3.1） |
| **禁用 Disabled（符箓不足）** | 去饱和（信息灰 `#8A9599`）+ **对角划线** + 禁用 glyph（锁/`ico_st_disable`）+ 文字「符箓不足」；**不纯色失效**；下方显「去推图产出符箓」引导 CTA（ux-spec §4 卡点#1，防核心循环断流） |

### 5.2 尺寸与视觉权重
| 按钮 | 尺寸（≥44×44，Standard J） | 视觉权重 |
|---|---|---|
| **十连（主 CTA）** | **280×72**（移动按 48px 网格；命中区 ≥44） | 最高：鎏金边 + idle 辉光 + 最大；文案「十连 -100 符箓」 |
| **单抽（次 CTA）** | **200×64** | 次：青碧边、无 idle 辉光；文案「单抽 -10 符箓」 |
| 引导 CTA（符箓不足时） | ≥44×44 | 次级引导：青碧 `#4FA39B` 灵力色，指推图 |

- 双端：移动竖屏底部堆叠（拇指可达）；PC 横屏并排（hover 描边加厚+图标态，不靠纯发光）。
- 字体：标签用 Body 黑体（≥16sp，最小 14sp），符箓消耗数字 tabular。
- 工程：`SinglePullButton.prefab` / `TenPullButton.prefab`（`Image imgBg` 9-slice + `TextMeshProUGUI txtLabel` + `Image imgLockIcon` + `Button`）。

---

## 6. 可访问性清单（本套资产如何满足分级）

> MVP 强制 **Basic 全项 + Standard 主体**（accessibility-spec §0 / ux-spec §0）。逐项映射本规格落地。

| 分级条款 | 含义 | 本规格落地 |
|---|---|---|
| **Basic A** | 正文≥4.5:1 / 大标题≥3:1 | 卡面文字月白 `#E8ECEF` 于深墨 `#122426`；保底数字同；H1 书法仅装饰 |
| **Basic B** | 高对比模式 | 提供高对比 Sprite 变体（深墨+月白+描边/投影双边界）；`UIThemeController` 切换 |
| **Basic C** | 文本缩放 100–130% 不破版 + tabular | 全数值（保底/ATK/HP/符箓）tabular nums；弹性栅格，缩放 reflow 不裁切 |
| **Basic E** | 色盲冗余（稀有度/五行） | 稀有度 = 颜色+边框纹理+角星 1/2/3（灰度可辨）；保底 = 形状(菱/方)+数字+颜色；五行 = 图标+形状 |
| **Standard J** | 触控 ≥44×44 | 单/十连按钮、保底说明入口、卡牌 tappable 区均 ≥44（移动按 48 网格） |
| **Standard K** | 字体层级落地 | H1 书法装饰 / H2 宋体式神名 / Body 黑体 / Stat tabular，层级靠字号+字重+留白 |
| **Standard I** | 减少动效（静态等效） | `reduce_motion` 开启时：翻面/SSR 虹光/灵光升腾**跳过动画直接定格**；**保留边框+角星+数字+名称静态等效**（卡片直接显示完整面，稀有度信息不丢失）；保底填充瞬跳、tick 静态 |
| **Standard G** | CVD 滤镜 + 色盲模拟 | 稀有度/保底/五行三重冗余之上加 CVD 后处理；`COLOR_*` 驱动色相安全重映射；dev 侧色盲模拟审查 |

> **减少动效静态等效要点（MVP 验收项，ux-spec §6 #5）**：任何动效关闭后，玩家仍能凭「边框纹理 + 角星数 + 式神名 + 稀有度文字 + 数值」完整理解出货结果——视觉演出降级但信息零丢失。

---

## 7. 资产交付清单（供 engineering-lead 实现 MVP）

> 列出 MVP 所需的 Prefab / 材质 / 贴图占位（灰盒亦可）与**美术替换接口（Sprite 字段名约定）**。路径按 §0 翻译为 Unity `Assets/` 口径。本规格不产出贴图，仅定义占位与接口。

### 7.1 目录结构（提案·待 eng 确认打包方式）
```
Assets/Art/UI/Gacha/
├─ Prefabs/   ResultCard.prefab  SinglePullButton.prefab  TenPullButton.prefab
│             PityProgressBar.prefab  GachaScreen.prefab
├─ Sprites/   card_frame_base.png  card_frame_n.png  card_frame_r.png
│             card_frame_sr.png  card_frame_ssr.png  card_frame_ssr_sweep.png
│             star_1.png  star_2.png  star_3.png  card_back.png  card_bg.png
│             portrait_placeholder.png  pity_mark_50.png  pity_mark_90.png
│             btn_bg_9slice.png  ico_st_disable.png  particle_soft.png
├─ Materials/ mat_jade_panel.mat  mat_rise_glow.mat  mat_ssr_rainbow.mat
│             mat_card_frame_sr.mat  mat_pity_fill.mat
└─ Shaders/   RiseGlow.shader  SSRRainbow.shader  PityFill.shader
```

### 7.2 Prefab / 材质 / Shader 需求表
| 资产 | 类型 | 用途 | 备注 |
|---|---|---|---|
| `ResultCard.prefab` | Prefab (UGUI) | 出货卡展示 | 见 §7.3 字段 |
| `SinglePullButton` / `TenPullButton` | Prefab | 单/十连 CTA | 三态 + 符箓消耗文本 |
| `PityProgressBar.prefab` | Prefab | 保底 50/90 进度 | 双段 tick + tabular 计数 |
| `GachaScreen.prefab` | Prefab | 抽卡屏容器 | 承载上述 + 卡池选择/概率入口（①②见 §9） |
| `mat_jade_panel` | Material | 毛玻璃半透面板 | alpha + 轻噪点 |
| `mat_rise_glow` | Material/Shader | 灵光升腾 | `_Progress` 驱动 UV.y 上滚+径向柔光 |
| `mat_ssr_rainbow` | Material/Shader | 紫宸虹光 | UV 滚动 hue shift（紫宸/鎏金/青碧） |
| `mat_card_frame_sr` | Material | 鎏金浮雕边 | 高光/bevel（可简化为描边） |
| `mat_pity_fill` | Material/Shader | 保底填充渐变 | 青碧→鎏金→朱砂 + CVD 重映射 |

### 7.3 美术替换接口（Sprite 字段名约定 · 给后续美术填图）
> engineering-lead 在 Prefab 上暴露以下序列化字段，美术后续只换 Sprite/材质，不动布局。

**ResultCard（组件字段约定）**
| 字段（C# 序列化名） | 类型 | 占位/说明 |
|---|---|---|
| `imgFrameN / imgFrameR / imgFrameSR / imgFrameSSR` | `Image` | 四档卡框 9-slice；按稀有度运行时显隐其一 |
| `imgFrameSweep` | `Image` | SSR 光扫 overlay（`card_frame_ssr_sweep`，加法） |
| `imgStar1 / imgStar2 / imgStar3` | `Image` | 角星；按档显隐（R=1 / SR=2 / SSR=3 / N=0） |
| `imgCardBack` | `Image` | 卡背（翻面起手态） |
| `imgCardBg` | `Image` | 卡面底纹（`card_bg`） |
| `rawPortrait` | `RawImage` | 立绘占位（`portrait_placeholder`，后续换式神立绘） |
| `txtShikigamiName` | `TextMeshProUGUI` | 式神名（H2） |
| `txtRarity` | `TextMeshProUGUI` | `N/R/SR/SSR` 文字 |
| `txtATK / txtHP` | `TextMeshProUGUI` | tabular 数值 |
| `imgElementGlyph` | `Image` | 五行形状 glyph（圆/三角/方） |
| `matRiseGlow / matSSRRainbow` | `Material` | 翻面/SSR 叠加材质引用 |

**SinglePullButton / TenPullButton**
| 字段 | 类型 | 说明 |
|---|---|---|
| `imgBg` | `Image` | 9-slice 按钮底（常态/按下/禁用三态用同图+主题态或分 Sprite） |
| `txtLabel` | `TextMeshProUGUI` | 文案 + 符箓消耗（tabular） |
| `imgLockIcon` | `Image` | 禁用态锁 glyph（`ico_st_disable`） |
| `btn` | `Button` | 交互；Three-state 由 `UIThemeController`/Accessibility 驱动 |

**PityProgressBar**
| 字段 | 类型 | 说明 |
|---|---|---|
| `imgTrack / imgFill` | `Image` | 轨道 / 填充（Fill 模式或 9-slice） |
| `imgMark50 / imgMark90` | `Image` | 菱形 / 方形双刻 tick（形状冗余） |
| `txtCount` | `TextMeshProUGUI` | `"12 / 90"` tabular |
| `matPityFill` | `Material` | 渐变 + CVD |

### 7.4 占位与替换原则
- MVP 工程期可用**灰盒占位**（纯色块/描边矩形 + 文字）跑通交互；美术后续按 `Assets/Art/UI/Gacha/Sprites/` 同名替换。
- 所有稀有度色/五行色经 `UIThemeController.COLOR_*` 常量落地（禁硬编码），保证高对比/CVD 一键切换。
- 9-slice 边距按最终卡框源图定（§0 待确认项）。

---

## 8. 视觉-音频同步点（给 audio-director）

> 抽卡演出时间轴与音频 cue 的对齐点。音频不被 `reduce_motion` 门控（视觉可静态、音频照常），但 cue 时机须对齐**揭示/峰值**时刻。

| 时刻（单卡） | 视觉事件 | 音频 cue 建议 |
|---|---|---|
| `t=0.00` | 翻面起手（卡背下沉） | 「翻面起手」轻 whoosh |
| `t=0.25` | ★ 换面（卡背→卡面，灵光升腾启动） | 「揭示」whoosh + 灵光升腾 chime（青碧） |
| `t=0.25→0.5` | 灵光上涌 + 粒子（普通） | 升腾余韵 |
| SSR：`t=0.25` 起 +0.2s | 紫宸虹光 bloom + 光扫 | **SSR 专属 grand sting**（锚点4 峰值，紫宸和弦） |
| 保底过 50 | 软标记脉冲 | 轻「保底临近」tick |
| 保底过 90 | 硬标记脉冲 + 必出 | 「保底触发」确认 cue |
| `reduce_motion` 路径 | 翻面瞬时定格（无动画） | 音频 cue 仍对齐"定格揭示"时刻（即普通 t=0.25 / SSR 峰值点），不延迟 |

> 约定：以 `gacha:shikigami_obtained` 事件为演出起点；音频与 VFX 均订阅同一时间轴，`MotionScale` 仅影响视觉时长、不影响音频触发点。

---

## 9. 回传主理人：跨角色交付说明

### 9.1 给 design-strategist（UX 规格视觉支撑确认）
- **ux-spec §2.2 Summon 关键元素** 本规格覆盖情况：
  - ② 单/十连 CTA → **已覆盖**（§5 三态+尺寸+权重）。
  - ③ 保底进度条 → **已覆盖**（§4 双段+形状冗余+CVD）。
  - ⑤ 出货演出（翻面/灵光升腾/SSR 紫宸虹光）→ **已覆盖**（§2 翻面 VFX + §3 SSR 虹光 + §1 卡框）。
  - 稀有度三重冗余（颜色+边框+角星）→ **已覆盖**（§1.3，对齐 §5/§8）。
  - ① 卡池选择 / ④ 概率公示 / ⑥ 羁绊序章弹窗 / ⑦ 货币顶栏 → **超出本切片范围**，分别由通用 UI 控件规格（`ui_panel`/`ui_dialog`/下拉/表格，见 asset-spec §1.4）覆盖；本规格不重复定义，建议 UX 引用既有控件规格即可。
- 结论：**ux-spec §2.2 的视觉演出需求已被本规格完整支撑**；仅交互容器类（卡池/概率/序章/货币）走通用控件，无冲突。

### 9.2 给 engineering-lead（资产接口清单）
- Prefab：`ResultCard` / `SinglePullButton` / `TenPullButton` / `PityProgressBar` / `GachaScreen`。
- Sprite 字段约定：见 §7.3（运行时按稀有度显隐 `imgFrame*` / `imgStar*`）。
- Shader/材质需求：`mat_rise_glow`（灵光升腾）、`mat_ssr_rainbow`（紫宸虹光）、`mat_pity_fill`（保底渐变+CVD）、`mat_jade_panel`、`mat_card_frame_sr`。
- 约束：**不改 M2 任何 `.cs`**；新组件（如翻面控制器）由 eng 新建，本规格仅定义字段与行为。
- 待确认：SpriteAtlas 打包方式（Addressables vs Resources）、9-slice 边距、CVD 后处理挂接点。

### 9.3 给 audio-director（视觉-音频同步点）
- 见 §8 时间轴：翻面起手 / 揭示换面 / 灵光升腾 / SSR 紫宸虹光峰值 / 保底 50·90 触发；`reduce_motion` 下音频对齐定格揭示点。

---

## 一句话总结
本 M3 抽卡 UI 资产规格在**保留 art-bible 视觉身份（紫宸虹光/四档稀有度/角星三重冗余/可访问性三级）** 的前提下，将基线 Godot 约定**翻译为 Unity/UGUI/Android IL2CPP** 口径，给出 ResultCard 卡框（2:3、四档边框+角星 1/2/3 灰度可辨）、翻面 VFX（灵光升腾·2D Tween+Shader）、SSR 紫宸虹光（锚点4 色值+粒子+时长）、保底进度条（50 软/90 硬双段形状冗余+CVD）、单十连按钮三态（≥44px、主 CTA 权重）、可访问性清单（Basic A/B/C/E + Standard J/K/I/G，reduce_motion 静态等效保留边框/角星/数字）与资产交付清单（Prefab/材质/Shader + Sprite 字段替换接口），并回传 design-strategist（UX 视觉需求已覆盖确认）、engineering-lead（接口清单）、audio-director（同步时间轴）三方交付说明；不写代码、不产贴图、不改 M2 `.cs`。
