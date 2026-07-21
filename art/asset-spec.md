# 仙侠卡牌 · MVP 资产规格（Asset Specification）
**项目**：仙侠卡牌（Xianxia Card Battler）　**阶段**：Phase 4 预制作　**引擎**：Godot 4.x（2D-first，保留 3D 演出余量）　**平台**：PC Steam（横屏 ≥1024px）+ 移动 iOS/Android（竖屏 <768px）　**评审**：solo / lean　**编写**：art-director 林绘澄　**对齐**：art/art-bible.md §3–§9、art/accessibility-spec.md（T3 三级）、design/gdd/02a-gdd-mvp.md

## 0. 对齐说明与待确认假设
- ✅ **已读并严格对齐**：`art/art-bible.md`（§3 字体 / §4 角色 / §5 卡牌 / §6 场景 / §7 UI / §8 可访问性 / §9 锚点）、`design/gdd/02a-gdd-mvp.md`（MVP 5 系统资产需求）。
- ⚠️ **`art/accessibility-spec.md` 未找到**（T3 约束「不要自己写磁盘」，该文件未落盘）。本规格以 T3 回传的 **Basic / Standard / Comprehensive 三级**内容为对齐基线（§5 引用其 A/B/C/D/E/G/H/I/J/K/L/M/N/O/P 条款）。建议主理人将 T3 全文落盘为该路径，保持双文档一致。
- ⚠️ **`art/references/INDEX.md` 未找到**：`art/references/` 目录为空，5 张锚点图尚未生成。本规格以 `art-bible.md §9` 的 5 个锚点（锚点 1–5）为参考图基线；INDEX 生成后请回填各锚点图路径。
- ⚠️ **`docs/architecture/01-architecture.md` 未找到**：无 `docs/` 目录。以下 **res://assets 目录结构（§2.4）、UI 组件基线、3D 余量钩子路径（§3）** 为基于 Godot 4 的合理假设，待 **engineering-lead** 用真实架构文档（1.2 目录 / 1.5 UI 基线 / 1.10 3D 余量）确认或校正。
- ⚠️ **锚点 6 歧义**：T4 提及「3D 余量资产（锚点 1/2/6）」，但 `art-bible.md §9` 仅定义锚点 1–5（无锚点 6）。推测锚点 6 = **天象裂隙 / Boss 3D 演出钩子**（对应 §6 战斗背景「煞气裂隙」）。§3 按此假设写入，待 architecture/INDEX 确认。

## 1. 资产清单（MVP）

### 1.1 汇总表
| 类别 | 资产数（约） | 说明 |
|---|---:|---|
| 角色式神立绘 | 39 | 13 式神 ×（全身立绘 1 + 头像 1 + Q版 1） |
| 卡牌框 | 8 | 通用基框 + R/SR/SSR 框 + 角星 1/2/3 + 卡面底 |
| UI 组件库 | 10 | 按钮/面板/数值条/顶栏/Tab/对话框/进度条/设置控件/焦点环 |
| 场景 | 6+ | 主菜单 1 + 宗门分层组 1 + 战斗背景 3 + 秘境分层组 1（+暗角遮罩） |
| 特效 VFX | 15 | 抽卡/突破/升级/五行×5/克制/连携/三重反馈/灵气粒子 |
| 图标体系 | 38 | 五行/门派/货币/功能/反馈/形状基元/状态 |
| **合计** | **≈113** | MVP 可见资产（不含 3D 钩子实体，仅 2D 回退） |

### 1.2 角色式神立绘（MVP 13 式神，设计范围 10–15 浮动）
- **稀有度分布**：N×3 / R×4 / SR×3 / SSR×3（覆盖四档，保证卡框 R/SR/SSR 均被使用；N 复用通用框 + 素灰 tint）。
- **每式神三视图资产**：
  - 全身立绘（7–8 头身，2:3）— 卡牌立绘窗 + 图鉴大图（`char_{id}_portrait`）。
  - 头像（1:1 裁切或独立绘制）— 列表/编队/对话（`char_{id}_face`）。
  - Q版（2–3 头身）— 战斗小人/表情包/收集反馈（`char_{id}_chibi`）。
- **辨识度**：每式神含核心视觉符号（本命法宝/灵纹/标志发色/坐骑，art-bible §4）；门派用「色系 + 纹样」双编码。
- **五行/门派标签**：立绘下方常驻「五行图标 + 形状」标签（与 §5 形状冗余对齐）。

### 1.3 卡牌框（R/SR/SSR 三档 + 通用结构）
- `card_frame_base`：通用玉质半透面板（9-patch），含顶部稀有度条槽 / 名称横幅槽 / 中部立绘窗 / 底部数值条 / 四角云纹剑纹槽。
- `card_frame_r`：青碧细边；`card_frame_sr`：鎏金浮雕边 + 角饰；`card_frame_ssr`：紫宸虹光边（静态框 + `card_frame_ssr_sweep` 动态光扫 overlay）。
- `star_1` / `star_2` / `star_3`：角星装饰（映射 R=1 / SR=2 / SSR=3；N 无角星），SSR 用钻星变体；**灰度下靠星数与描边区分**。
- `card_bg`：通用卡面底纹（水墨晕染留白）。

### 1.4 UI 组件库
- 按钮：主/次/禁用/稀有 四态 × 玉质感半透 + 云纹边（`ui_btn_*`），9-patch。
- 面板：`ui_panel`（毛玻璃 + 描边，9-patch），统一圆角 8–12px，8 倍数栅格。
- 数值条：`ui_bar`（HP/ATK/灵力，带 tabular nums 占位 + 状态色描边）。
- 顶栏：`ui_topbar`（货币状态栏，含 5 货币槽位）。
- Tab 栏：`ui_tabbar`（移动底部，拇指可达）。
- 对话框：`ui_dialog`（剧情，9-patch）。
- 进度/保底条：`ui_progress`（抽卡保底进度）。
- 设置控件：`ui_toggle` / `ui_slider`（高对比/减少动效/文本缩放开关）。
- 焦点环：`ui_focusring`（键盘/手柄导航，Comprehensive L 预留）。

### 1.5 场景（2D 分层视差为主，§6）
- 主菜单背景：1 张（锚点 1/2 氛围，御剑 + 宗门剪影）。
- 宗门：分层组（远景水墨 / 中景结构 / 近景粒子）1 组（锚点 2）。
- 战斗背景：3 张（通用御剑长空 / 星河 / 煞气裂隙），按属性/阵营切换，保证与前景对比度 + 暗角遮罩。
- 秘境：分层组（晶簇 / 古阵 / 残碑 + 幽紫流光）1 组（锚点 A2 秘境，P2）。

### 1.6 特效 VFX
- 抽卡：`vfx_summon_rise`（通用灵光升腾）+ `vfx_summon_ssr`（SSR 强化·御剑/灵光意象）。
- 养成：`vfx_breakthrough`（突破「飞升」御剑意象）+ `vfx_levelup`（升级光粒汇聚）。
- 五行技能：`vfx_elem_metal/wood/water/fire/earth` ×5（按属性配色 + 形状，不靠色）。
- 反馈：`vfx_kexhi`（克制「克制！」浮字 + 标识）、`vfx_liánxié`（连携横幅）。
- 三重反馈图标：`fx_heal`（绿十字）/ `fx_damage`（红剑）/ `fx_block`（蓝盾）+ 浮字样式（Basic D）。
- 环境：`vfx_qi`（灵气粒子，hover/氛围）。

### 1.7 图标体系（线性 + 微填充，24/48px 网格，§7）
- 五行：`ico_elem_{metal/wood/water/fire/earth}`（金=剑三角 / 木=叶圆 / 水=水纹圆 / 火=丹三角 / 土=方）。
- 门派：`ico_sect_*`（剑修/丹修/… 约 5）。
- 货币：`ico_cur_{fulu/lingyu/lingqi/dan/shi}`（符箓/灵玉/灵气/突破丹/觉醒石）。
- 功能：`ico_fn_{summon/build/codex/cultivate/battle/shop/back/settings}` 等约 8。
- 反馈：`ico_fb_{heal/damage/block/kexhi/lianxie}` 5（含三重反馈）。
- 形状基元：`shape_circle` / `shape_triangle` / `shape_square`（冗余编码底座）。
- 状态：`ico_st_{lock/new/disable/warn}` 4。

## 2. 生产规范

### 2.1 分辨率与格式（双端）
| 资产类型 | PC 分辨率 | 移动分辨率 | 格式 |
|---|---|---|---|
| 式神全身立绘 | 2048×3072（2:3） | 1024×1536 | PNG（源）→ VRAM 压缩 |
| 式神头像 | 512×512 | 256×256 | PNG |
| 式神 Q版 | 512×512 | 256×256 | PNG |
| 卡牌框（整卡） | 1024×1536 | 512×768 | PNG（分层透明） |
| UI 组件 / 图标 | 256×256（栅格 48/24） | 128×128 | SVG 源 → PNG 多尺寸 |
| 场景分层 | 2560×1440（16:9） | 1280×720 | PNG（视差层） |
| VFX 序列/粒子贴图 | 512×512 贴图集 | 256×256 | PNG（透明） |

- **双端策略**：源文件高分辨率（PC 优先）；移动端导出压缩档（ASTC）。Godot 通过**导出预设**按平台选压缩格式，资产源同一套，不另出两套图。
- **格式要点**：UI/图标用 SVG 矢量源保清晰（Godot `SVGTexture` 或导出 PNG @1x/2x 进图集）；照片感背景/场景用 PNG + mipmaps；避免 JPG（损线稿）。

### 2.2 图集（atlas）策略
- **进图集**：UI 图标统一打包为 1024² 图集（如 `atlas_ui_icons_48.png`），用 `AtlasTexture` 按区域引用；按钮/面板等小控件同理。
- **不进图集**：角色立绘、卡牌框、场景分层、VFX 大贴图——独立文件 + mipmaps，避免图集过大与内存峰值。
- **工具**：Godot 4 用 `TextureAtlas`（运行时）或手动 spritesheet + `AtlasTexture` 区域；lean 项目推荐手动打包 + 区域引用，构建期无需额外管线。

### 2.3 9-patch 与响应式
- **9-slice**：面板/按钮/对话框/顶栏用 `StyleBoxTexture`（带 `texture_margin` 九宫格边距），由主题统一应用；源 PNG 预留透明边供拉伸。
- **响应式**：同一套卡框资产靠布局切换「紧凑态 / 完整态」（§5），不另出两套图；全站 8 倍数栅格；文本缩放 100–130% 由弹性容器 + `text_scale` 驱动（accessibility-spec C/H）。

### 2.4 命名约定（res://assets，*提案·待 engineering-lead 确认*）
```
res://assets/
├─ characters/
│  ├─ portraits/   char_{id}_portrait_{rarity}.png
│  ├─ faces/       char_{id}_face.png
│  └─ chibi/       char_{id}_chibi.png
├─ cards/
│  ├─ frame_base.png  frame_r.png  frame_sr.png  frame_ssr.png  frame_ssr_sweep.png
│  ├─ star_1.png  star_2.png  star_3.png  card_bg.png
├─ ui/
│  ├─ components/  ui_btn_{variant}.png  ui_panel.png  ui_bar.png  ui_topbar.png  ui_tabbar.png  ui_dialog.png  ui_progress.png  ui_toggle.png  ui_slider.png  ui_focusring.png
│  ├─ icons/       ico_{cat}_{name}.png        (cat: elem/sect/cur/fn/fb/st)
│  └─ shapes/      shape_circle.png  shape_triangle.png  shape_square.png
├─ scenes/
│  ├─ menu/  sect/  battle/  secret/   ({name}_{layer}.png)
├─ vfx/
│  ├─ summon/  cultivate/  elem/  feedback/  ambient/
├─ fonts/          (思源黑体/宋体/等宽数字)
└─ fallback_2d/    (3D 钩子的 2D 回退，见 §3)
```
- 规则：全小写 snake_case；`{category}_{id}_{variant}_{state}`；禁空格/中文；稀有度后缀 `n/r/sr/ssr`；状态 `normal/hover/disabled`（按钮四态合并为 1 图 + 主题态或分文件）。

### 2.5 Godot 4 导入设置要点
- **纹理**：`compress/mode = VRAM`；导出预设按平台设 `vram_compression`（移动 ASTC / PC BPTC·BC7）；`filter = true`；场景/立绘 `generate_mipmaps = true`，UI 小控件可关 mipmaps 保清晰。
- **SVG 图标**：`svg_scale` 设为 2–4 保证高分屏清晰；或转 PNG 进图集。
- **9-slice**：`StyleBoxTexture` 设 `region` + `expand_margin`（九宫），挂到 `Theme` 全局应用。
- **tabular nums**：数值 `Label` 用 `FontVariation` + `opentype_features = {"tnum": 1}`，或字体文件启用 tnum（accessibility-spec C）。
- **高对比主题**：定义 `theme_high_contrast.tres`（覆盖 panel/button/font 色），由 `AccessibilitySettings.accessibility_changed` 信号切换（accessibility-spec B）。
- **减少动效**：VFX 提供低粒子/静态帧变体，读取 `MotionScale`（accessibility-spec I）。
- **3D 余量**：`detect_3d` 对纯 2D 资产设 false；3D 钩子见 §3。

## 3. 3D 演出余量资产（锚点 1/2/6，*钩子路径为假设·待architecture/INDEX确认*）
- **御剑飞行（锚点 1）**：预留 `res://assets/3d/sword_flight.tscn`（剑 + 修士简化骨骼/网格）；MVP 出 **2D 回退** `fallback_2d/sword_trail.png`（剑光拖尾 sprite + 粒子）。
- **天象 / 宗门（锚点 2）**：预留 `res://assets/3d/sect_sky.tscn`（悬浮山体积/云）；MVP 用 **2D 分层视差** 宗门背景（§1.5）替代。
- **天象裂隙 / Boss（锚点 6，假设）**：预留 `res://assets/3d/rift_boss.tscn`；MVP 出 **2D 回退** `fallback_2d/rift.png`（煞气裂隙 sprite）+ Boss 2D 立绘演出。
- **落地原则**：MVP 全部以 2D 交付并保证可玩/可看；3D 钩子仅留工程桩（空场景 + 回退贴图），不占用 MVP 美术产能。性能/省电模式（accessibility-spec P）下强制走 2D 回退。

## 4. 生产优先级（与 MVP 冲刺对齐）
- **P0 必做（核心循环可见）**：卡牌框（基 + R/SR/SSR + 角星）· 首批 ~8 式神立绘/头像（覆盖四档）· 基础 UI（按钮/面板/顶栏/数值条/对话框）· 主菜单 + 战斗背景×3 + 宗门基础 · 核心图标（五行/货币/功能/三重反馈）· 抽卡 VFX + 伤害/治疗/格挡浮字 · 形状基元（圆/三角/方）。
- **P1（养成/战斗表现）**：剩余式神立绘 + Q版 · 突破飞升 / 升级 VFX · 五行技能特效 ×5 · 克制/连携浮字横幅 · 设置 UI（高对比/减少动效/缩放）· 灵气粒子。
- **P2（秘境/剧情氛围）**：秘境分层场景 · 剧情对话框氛围/主角 2D 演出 · Boss 2D 回退 · 额外环境 VFX/粒子。（注：秘境在 GDD 属核心层 A2，本规格仅按 MVP Demo 需要出最小氛围集。）

## 5. 可访问性落地（资产层，对齐 accessibility-spec）
- **形状冗余图标**：五行图标形状烤死（圆/三角/方），灰度下可辨；不依赖色相（Basic E）。
- **灰度可读角星/边框**：角星靠数量 + 描边强度区分；R/SR/SSR 边框纹理差异（细线/浮雕/虹光）在灰度下仍清晰（Basic E）。
- **44px 触控图标**：移动端图标美术落 48px 网格，命中区强制 ≥44×44px（Standard J）；Lint 校验。
- **tabular nums 数值条**：数值条用等宽数字字体 + tnum，占位对齐防跳（Basic C / §3）。
- **高对比主题**：提供 `theme_high_contrast.tres` 覆盖（深墨底 #122426 + 月白 #E8ECEF + 描边/投影双边界，Basic B）。
- **减少动效**：VFX 提供静态帧/低粒子变体，状态变化保留图标/数字/边框静态等效反馈（Standard I）。
- **三重反馈**：伤害/治疗/格挡 = 图标 + 数字 + 颜色三通道（Basic D）。
- **动态文本**：图标/标签文本容器自适应、溢出省略号 + 展开（Standard H）。

## 6. 复用锚点 5 形状语言（类别冗余编码）
- **锚点 5（灵宠 vs 法宝对比）** 的视觉语言——**灵宠（活物·暖玉金光·圆润有机·柔光粒子）vs 法宝（器物·冷青金线·几何硬边·对称符文）**——天然以形状/质感而非颜色区分活物与器物，利于色盲与低视力辨识（accessibility-spec E 延伸）。
- **资产层落地**：
  - 「灵宠类」资产（图标/立绘/标签）统一用**圆润有机轮廓 + 暖色 + 柔光粒子**；
  - 「法宝类」资产统一用**几何硬边 + 冷色 + 金线符文**；
  - UI 中灵宠/法宝类别 tag 复用该形状语言，作为**第 N 类冗余编码**（与五行形状冗余并列），呼应 B7 法宝/灵宠独立养成线的视觉差异。
  - 该语言同时服务卡牌「立绘（活物感）vs 边框（器物感）」的质感对比，强化整卡可读性。

---

## 一句话总结
本 MVP 资产规格给出 ≈116 件可见资产的清单（13 式神三视图 / R·SR·SSR 卡框 / UI 组件 / 场景分层 / VFX / 图标体系）、双端分辨率与 Godot 4 导入规范、3D 演出 2D 回退策略、P0–P2 生产优先级，并在资产层落地 accessibility-spec 的形状冗余/44px/tabular/三重反馈，复用锚点 5 形状语言作类别冗余编码；其中 `accessibility-spec.md`、`references/INDEX.md`、`docs/architecture/01-architecture.md` 三文件缺失、且「锚点 6」需确认，已在 §0 标注待主理人/engineering-lead 补齐。

---
**待确认（请主理人协调）**：
1. 将 T3 可访问性三级规格落盘为 `art/accessibility-spec.md`（T3 约束未写盘）。
2. 生成 `art/references/INDEX.md`（5 锚点图路径）与 `docs/architecture/01-architecture.md`（1.2 目录 / 1.5 UI 基线 / 1.10 3D 余量）。
3. 确认 §2.4 res://assets 目录结构与 §3 的 3D 钩子路径（转 engineering-lead 用真实架构校正）。
4. 确认「锚点 6」定义（推测 = 天象裂隙/Boss 3D 钩子）。
5. MVP 式神数确认取 13（可在 10–15 浮动）及稀有度分布 N3/R4/SR3/SSR3（朱雀确认为火 SSR，放宽原 SSR2 锁）。
