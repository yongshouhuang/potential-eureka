# 仙侠卡牌项目 · 美术圣经（Art Bible）
**项目**：仙侠卡牌（Xianxia Card Battler）　**阶段**：Phase 1 概念孵化　**引擎**：Godot 4.x（2D-first，保留 3D 演出余量）　**平台**：PC Steam（横屏）+ 移动 iOS/Android（竖屏）　**评审**：solo / lean　**编写**：art-director 林绘澄

> 一句话定位：以「水墨留白 + 工笔重彩」为底，营造古典东方仙侠的空灵仙气；所有资产面向 2D 优先生产，3D 仅用于御剑/天象等少数演出。

---

## 1. 视觉基调与情绪板
整体气质：一个御剑修真、宗门林立的古典东方仙侠世界——云海之上的悬浮仙山、钟声松影的古老宗门、灵宠环绕的修士与流转符文的法宝。美术上以**水墨意境**撑起空灵氛围（大面积留白、晕染、气韵），以**工笔重彩**承载角色与道具的精致细节（白描定形、柔光渐变设色）。氛围不是「炫酷奇幻」，而是「清冷古韵、仙气缥缈」，让玩家在抽卡与养成中持续获得「收集珍奇、问道长生」的审美满足。

**情绪关键词（5）**：空灵 · 清冷 · 古韵 · 仙气 · 缥缈

---

## 2. 色彩系统
### 2.1 主色 / 辅色 / 功能色
| 类别 | 名称 | HEX | 用途 |
|---|---|---|---|
| 主色 | 青冥（墨青） | `#1F3A3D` | 主背景、深场、UI 底 |
| 主色 | 青碧（玉光） | `#4FA39B` | 灵力/主行动色、强调 |
| 辅色 | 月白 | `#E8ECEF` | 文字、留白、高光 |
| 辅色 | 朱砂 | `#C8453A` | 仪式/警示/剑穗点缀 |
| 辅色 | 鎏金 | `#CBA75C` | 边框、符文、宝物品级 |
| 功能 | 灵力+（成功） | `#4FA39B` | 增益/治疗/恢复 |
| 功能 | 煞气−（警示） | `#C8453A` | 伤害/危险/失败 |
| 功能 | 法宝（提示） | `#CBA75C` | 提示/可交互/稀有 |
| 功能 | 信息（中性） | `#8A9599` | 次级文本、禁用态 |

### 2.2 稀有度配色（Rarity）
| 稀有度 | 名称 | HEX | 视觉处理 |
|---|---|---|---|
| N 凡品 | 素灰 | `#9AA3A6` | 素色细边，无描金 |
| R 灵品 | 青碧 | `#4FA39B` | 青碧细边 |
| SR 宝品 | 鎏金 | `#CBA75C` | 鎏金浮雕边 + 角饰 |
| SSR 仙品 | 紫宸 | `#8B6DB3` | 紫宸虹光描边 + 动态光扫 |
| UR 道尊（可选） | 朱金 | `#C8453A`+`#CBA75C` | 朱金双描 + 循环光效 |

> 稀有度**不只靠颜色**区分（见第 8 节）：R/SR/SSR 同时用边框纹理与角星数量（1/2/3 星或菱形数）作冗余标识。

### 2.3 双端屏幕可读性考量
- **移动户外强光**：避免「纯黑底 + 纯白字」在强光下糊；改用深墨底 `#122426` 配月白 `#E8ECEF` 文字，正文对比度 ≥ 4.5:1、大标题 ≥ 3:1。
- **暗光夜玩**：主色青冥本就偏暗，需保证面板有足够亮度层级（玉质感半透明面板提亮）。
- **跨亮度自适应**：关键数值与按钮提供描边/投影双重边界，避免仅依赖明度差；提供「高对比模式」开关。
- **色域**：移动端 sRGB 为准，鎏金/紫宸在 OLED 上易过饱和，出图时控制饱和度上限。

---

## 3. 字体与排版
| 层级 | 字体取向 | 字号（移动最小） |
|---|---|---|
| Logo / 大标题 H1 | 书法/宋体感（如 思源宋体 Heavy、定制行楷） | 48–64sp |
| 章节标题 H2 | 思源宋体 / 方正清刻本悦宋 | 28–36sp |
| 正文 Body | 思源黑体 / 苹方（小屏可读优先） | 16–18sp（最小 14sp） |
| 注释 Caption | 思源黑体 Light | 12–13sp |
| 数值 Stat | 等宽数字（DIN 感 / 思源黑体 Medium 表格式） | 24–32sp（最小 18sp） |

- **中文仙侠感**：标题用衬线/书法体撑古韵，正文用黑体保可读——「古韵其外、清晰其内」。
- **数字**：战斗灵力值、攻击/生命等用表格式等宽数字（tabular nums），避免跳动；可加极轻描金描边强化「数值即资产」的收集感。
- **层级规范**：统一 8 倍数间距栅格；标题与正文对比靠字号+字重+留白，不靠纯颜色。

---

## 4. 角色 / 式神美术风格
- **线稿 / 上色取向**：白描线条定形（细而挺），工笔设色（柔光渐变、少量高光），背景大面积水墨晕染留白营造仙气；避免厚涂写实，保持「绘卷感」。
- **比例**：立绘 7–8 头身（修长飘逸）；头像/表情包可 2–3 头身 Q 版；战斗演出动态可适度夸张。
- **辨识度要点**：每个式神有**核心视觉符号**（本命法宝 / 灵纹 / 标志发色 / 坐骑）；门派用「色系 + 纹样」双编码区分（如剑修=金行+剑纹，丹修=火行+丹纹）。
- **灵宠 vs 法宝 视觉差异（关键）**：
  - **灵宠（Spirit Beast）**：生物感、圆润或鳞甲质感、自带柔光灵气粒子、眼瞳发光；暖色或自然色为主；强调「活物」——姿态生动、毛发/羽毛有体积。
  - **法宝（Treasure / Artifact）**：器物感、几何/符文对称、金属+玉+灵晶质感、悬浮自转、符文流光；冷色 + 金线为主；强调「人造神物」——硬边、对称、非生命体。

---

## 5. 卡牌视觉规范
- **卡框结构**：顶部稀有度条 + 名称横幅 → 中部立绘视窗（核心）→ 底部属性/数值条；四角装饰云纹/剑纹。
- **稀有度边框**：R 青碧细边；SR 鎏金浮雕边 + 角饰；SSR 紫宸虹光描边 + 动态光扫；UR 朱金双描 + 循环光。
- **立绘占比**：立绘占卡面 60–65%，信息区 35–40%。
- **信息密度（双端）**：
  - 移动小屏：保证立绘 ≥ 50%，关键数值 ≥ 18sp 不糊；提供「紧凑态」（仅核心数值 + 稀有度 + 名）。
  - PC 大屏：在紧凑态之上叠加 flavor text / 技能描述（「完整态」）。
  - 同一套卡框资产，靠响应式布局切换两态，不另出两套图。

---

## 6. 场景与环境
| 场景 | 美术取向 | 色彩氛围 |
|---|---|---|
| 宗门 | 云海之上的悬浮仙山、亭台楼阁、松柏、巨钟、仙鹤；工笔细节 + 水墨晨雾 | 青黛 `#2C5350` + 月白雾 + 薄金屋檐，晨光感 |
| 秘境 | 灵气异空间、晶簇、古阵、残碑；神秘、非日常 | 幽紫 `#8B6DB3` + 青碧流光 + 暗场，神秘 |
| 战斗背景 | 动态天象（御剑长空 / 星河 / 煞气裂隙），按属性/阵营切换 | 保证与卡牌、UI 的对比度，不抢前景信息 |

- 场景以 2D 分层视差为主（远景水墨、中景结构、近景粒子）；3D 仅用于御剑飞行、天象裂隙等少数演出镜头。

---

## 7. UI 视觉语言
- **双端适配原则**：
  - **PC 横屏（≥1024px，16:9）**：多栏布局——左式神列表 / 中战场 / 右卡组与信息；hover 灵气粒子反馈。
  - **移动竖屏（<768px，9:16）**：单列堆叠 + 底部 Tab；触控目标 ≥ 44×44px；关键操作拇指可达。
  - 响应式断点：≥1024 横屏多栏，768–1024 自适应混合，<768 竖屏单列。
- **控件风格**：玉质感半透明面板（毛玻璃 + 描边），按钮云纹/符文边，统一圆角 8–12px，间距 8 倍数栅格；状态反馈用描边 + 光效 + 图标三重。
- **图标体系**：线性 + 微填充（细金线描边图标），统一 24/48px 网格；门派/属性用符号化图标（剑=金行、水纹=水行、丹=火行…），形状本身即可区分（圆/三角/方），不依赖颜色。

---

## 8. 可访问性（solo 轻量）
- **色盲友好**：稀有度除颜色外，用边框纹理 + 角星数量（1/2/3）冗余标识；属性行用「图标 + 形状（圆/三角/方）」而非纯色。
- **文字对比度**：正文 ≥ 4.5:1，大标题 ≥ 3:1；提供高对比模式。
- **关键反馈不依赖纯颜色**：战斗伤害/治疗/格挡用「图标 + 数字 + 颜色」三重——治疗=+绿十字、伤害=红剑、格挡=蓝盾。
- **文本缩放**：支持 100%–130% 不破版（栅格弹性布局）。
- 轻量定位：以上为基线要求，不强制全特性矩阵，UX 规格引用本分级即可。

---

## 9. 视觉锚点清单（供 AI 文生图）
> 以下锚点可直接交给主理人用 AI 绘图生成参考图。每个含：名称 / 风格描述 / 构图建议 / 色彩 / 情绪 / 可直接出图 Prompt（英文主版适配 Midjourney·Niji / SD；附中文简版适配通义·即梦等）。

### 锚点 1 · 御剑长空（核心氛围锚）
- **风格描述**：水墨工笔融合，修士白衣御剑，云海翻涌，仙气缥缈。
- **构图建议**：中远景，人物偏右下三分线，剑光拖尾向左上延伸，左上大面积留白云海。
- **色彩**：青冥天空 + 月白云 + 朱砂剑穗 + 鎏金灵纹。
- **情绪**：空灵、自由、仙气。
- **Prompt (EN)**：
  `A solitary young cultivator in flowing white and pale-jade robes, standing atop a glowing jade flying sword, soaring above an endless sea of clouds at dawn. Ink-wash (shuimo) meets fine-line gongbi painting style, soft cel-shading, ethereal xianxia atmosphere. Wide cinematic composition: figure placed lower-right third, sword-light trail sweeping up-left across frame, vast negative space of misty cloud sea upper-left. Palette: deep ink-teal (#1F3A3D) sky gradient to pale moon-white (#E8ECEF) clouds, cinnabar-red (#C8453A) sword tassel, faint gilt (#CBA75C) spirit runes on sword. Volumetric god-rays, delicate ink splatter texture, subtle paper grain, dreamy soft-focus background, sharp detail on character. Mood: transcendent, free, serene. --ar 16:9 --style raw --niji 6`
- **Prompt (中)**：白衣修士踏青玉飞剑翱翔于破晓云海之上；水墨工笔融合、柔光、仙侠空灵；人物居右下三分线、剑光向左上拖尾、左上留白云海；墨青天空渐变月白云、朱砂剑穗、鎏金剑上灵纹；体积光、墨点肌理、纸纹；空灵自由。竖版 16:9。

### 锚点 2 · 悬浮宗门仙山（场景锚）
- **风格描述**：云海之上悬浮仙山，古阁玉台、松柏巨钟、仙鹤盘旋；水墨氛围 + 工笔建筑。
- **构图建议**：抬升广角，中轴对称主峰 + 侧峰，晨雾遮下缘建筑。
- **色彩**：青黛山 + 月白雾 + 薄金檐线与灯笼 + 青碧灵光。
- **情绪**：古韵、神圣、震撼。
- **Prompt (EN)**：
  `A grand immortal sect built atop a floating mountain peak emerging from a sea of clouds, ancient pavilions and jade terraces, pine trees, a giant bronze bell, cranes circling. Chinese xianxia architecture, ink-wash atmosphere with gongbi detail on structures. Elevated wide shot, symmetrical central mountain with side peaks, morning mist veiling lower architecture. Palette: indigo-teal (#2C5350) mountains, moon-white (#E8ECEF) mist, thin gilt (#CBA75C) roof edges and lanterns, soft cyan spirit glow. Soft ambient light, atmospheric perspective, layered depth, faint spirit particles drifting. Mood: ancient, sacred, awe-inspiring. --ar 16:9`
- **Prompt (中)**：云海之上悬浮仙山宗门，古阁玉台、松柏、巨钟、仙鹤盘旋；仙侠建筑、水墨氛围加工笔楼阁；抬升广角中轴对称主峰侧峰、晨雾遮下缘；青黛山、月白雾、薄金檐线与灯笼、青碧灵光；柔光、空气透视、层叠纵深、灵气粒子；古韵神圣。16:9。

### 锚点 3 · 水系剑修式神立绘（角色锚）
- **风格描述**：女性水系剑修，7.5 头身，飘逸；工笔设色 + 白描，冰蓝银发、透明冰剑、水灵气。
- **构图建议**：居中微 contrapposto 全身，左上轮廓光，背景极简水纹留白。
- **色彩**：冰蓝 `#6FB7C9` + 月白 + 深青阴影 + 银高光。
- **情绪**：清冷、精致、优雅。
- **Prompt (EN)**：
  `Full-body character key visual of a female water-element sword cultivator, xianxia style. 7.5 head proportion, slender elegant. Flowing blue-white layered robes with water-ripple embroidery, silver-blue hair, holding a translucent ice sword with water spirit aura. Gongbi fine-brush coloring over white-line sketch, soft gradient lighting, hair and fabric with subtle iridescent sheen. Neutral misty teal background with faint water ripples, minimal props for clarity. Composition: centered slight contrapposto, full body visible, rim light from upper left. Palette: ice-blue (#6FB7C9), moon-white, deep teal shadow, silver highlights. Crisp linework, clean readable silhouette. Mood: cool, refined, graceful. --ar 2:3 --niji 6`
- **Prompt (中)**：女性水系剑修全身立绘，仙侠风，7.5 头身修长；蓝白层叠水纹刺绣长袍、银蓝长发、手持半透冰剑带水灵气；工笔设色加白描、柔光渐变、发丝衣料微虹彩；极简青雾背景加水纹留白；居中微扭姿、左上轮廓光；冰蓝、月白、深青影、银高光；线稿利落、剪影清晰；清冷精致。竖版 2:3。

### 锚点 4 · SSR 仙品卡牌成品（卡牌锚）
- **风格描述**：SSR 仙品卡最终成品效果，紫宸虹光边框 + 动态光扫，玉质面板。
- **构图建议**：竖版 2:3，立绘居中占 60%，上下信息区，高小屏可读性。
- **色彩**：紫宸 `#8B6DB3` + 鎏金 + 青碧 + 月白，深墨底。
- **情绪**：尊贵、珍稀、神话。
- **Prompt (EN)**：
  `Game card frame mockup, xianxia collectible card, SSR "immortal" rarity. Central portrait window (60% of card) showing a glowing celestial sword cultivator, surrounded by amethyst (#8B6DB3) iridescent holographic border with dynamic light sweep, ornate cloud-and-sword corner ornaments, top rarity banner with three diamond stars, bottom stat bar (ATK/HP) in clean tabular numerals with gold accents. Semi-transparent jade panel texture, gilt line icons. Layout: vertical card 2:3, portrait centered, info zones top and bottom, high information clarity for small mobile screens. Palette: amethyst + gilt + jade + moon-white on dark ink background. Soft glow, premium foil feel, legible. Mood: majestic, precious, mythic. --ar 2:3`
- **Prompt (中)**：仙侠收藏卡成品，SSR 仙品；中央立绘窗占 60% 发光剑修，紫宸 `#8B6DB3` 虹光全息边框加动态光扫、云剑角饰、顶部三钻星稀有度横幅、底部 ATK/HP 表格式数字配金描边；玉质半透面板、鎏金线图标；竖版 2:3、上下信息区、小屏清晰；紫宸+鎏金+青碧+月白深墨底；柔光、箔感、易读；尊贵珍稀。2:3。

### 锚点 5 · 灵宠 vs 法宝对比（资产锚）
- **风格描述**：左右对比，左灵宠（活物·暖·柔），右法宝（器物·冷·硬），统一背景凸显差异。
- **构图建议**：左右分屏，各居中，统一青冥背景便于对比。
- **色彩**：灵宠暖玉金光；法宝冷青金线。
- **情绪**：灵动可爱 vs 神秘 crafted。
- **Prompt (EN)**：
  `Split comparison illustration, xianxia art style. LEFT panel: a cute spirit beast — a small fox-like celestial creature with glowing eyes, fluffy cloud-fur, floating spirit particles, warm jade-and-gold aura, alive and organic, rounded forms. RIGHT panel: a magical treasure artifact — a levitating jade talisman disc with symmetrical runes, metallic-gold inlay, cold cyan glow, geometric and crafted, self-rotating. Both on matching ink-teal (#1F3A3D) background for contrast. Style: gongbi fine-line, consistent lighting, clear visual distinction between living creature (organic, warm, soft) and artifact (geometric, cool, hard). Mood: charming vs mysterious. --ar 16:9`
- **Prompt (中)**：仙侠左右对比图；左：狐形灵宠，发光眼、云絮绒毛、浮空灵气粒子、暖玉金光、圆润活物；右：悬浮玉符盘，对称符文、金属金嵌、冷青光、几何硬边自转；统一墨青 `#1F3A3D` 背景对比；工笔细线、统一光照；明确区分活物（有机暖柔）与器物（几何冷硬）；灵动 vs 神秘。16:9。

### 锚点 6 · 天象裂隙 / Boss 3D 演出钩子（3D 余量锚）
- **风格描述**：Boss 战 / 突破飞升 / 剧情高潮时的天象异变——紫霄雷裂、星河倒卷、裂隙中浮现巨物剪影；水墨苍劲 + 工笔巨构，作为 2D 主画面之上叠 3D 演出余量（架构 `01-architecture.md §1.10`）的"出图/资产钩子"语义来源。
- **构图建议**：广角仰视，裂隙居中偏上撕裂天幕，巨物半透剪影隐于裂隙内；前景留 2D 战斗/角色剪影作尺度对比，凸显压迫感。
- **色彩**：墨青裂隙深空 `#1F3A3D` + 鎏金雷纹 `#CBA75C` + 朱砂坠星 `#C8453A` + 月白裂隙边缘光 `#E8ECEF`。
- **情绪**：压迫、史诗、神性降临。
- **Prompt (EN)**：
  `A cosmic celestial rift tearing open the heavens during a xianxia boss climax — jagged gilt lightning veins (#CBA75C) crackling across a deep ink-teal (#1F3A3D) void, cinnabar-red (#C8453A) falling stars, a colossal semi-transparent beast silhouette emerging within the fissure, pale moon-white (#E8ECEF) rim-light along the rift edges. Ink-wash grandeur meets gongbi monumental composition, low-angle wide shot, figure silhouette at bottom foreground for scale. Volumetric god-rays, spirit particles, dramatic atmospheric perspective. Mood: oppressive, epic, divine descent. --ar 16:9 --style raw --niji 6`
- **Prompt (中)**：仙侠 Boss 高潮天象裂隙——鎏金雷纹裂开墨青深空、朱砂坠星、裂隙内浮现金巨物半透剪影、月白裂隙边缘光；水墨苍劲加工笔巨构、广角仰视、前景角色剪影作尺度对比；体积光、灵气粒子、戏剧空气透视；压迫史诗神性降临。16:9。

---

## 10. 五行形状 / 配色系统（含火行扩展 · A4(a) 系统化）

> 本节将分散于 `art/accessibility-spec.md §1.1 E` 与 `art/asset-spec.md §1.7` 的五行「图标 + 形状」冗余编码**收口为 art-bible 唯一权威表**，并显式补全火行（朱雀/火灵）的配色与主题符文，供 S3 A4 资产生产、UI 控件（气槽）与 CVD 后处理统一引用。所有颜色经 `UIThemeController` 的 `COLOR_*` 常量落地（CLAUDE.md 硬约束），本节为设计 token。

### 10.1 五行形状 + 图标 + 配色权威表（三重冗余）
| 行 | 形状（粗冗余·圆/三角/方） | 专属图标（精冗余 glyph） | 主题色（设计 token → `COLOR_*`） | 关联式神（S3 全 12 表） |
|---|---|---|---|---|
| 金 metal | **三角**（剑形三角） | 兵刃 / 剑 glyph | 鎏金 `#CBA75C` → `COLOR_METAL` | 青龙(SSR) / 白虎(SSR) / 虎威(R) |
| 木 wood | **圆**（叶形圆） | 叶 / 藤 glyph | 青碧 `#4FA39B` → `COLOR_WOOD` | 幽冥(SR) / 玄风(SR) / 草隶(N) |
| 水 water | **圆**（水纹圆） | 水波 / 涟漪 glyph | 冰蓝 `#6FB7C9` → `COLOR_WATER`（锚点 3） | 青羽(R) / 虬龙(R) |
| 火 fire | **三角**（丹形三角） | 丹丸 / 火苗 glyph | 朱砂 `#C8453A` → `COLOR_FIRE` | **朱雀(SR) / 火灵(N)** |
| 土 earth | **方**（方形） | 山石 / 砖 glyph | 赭石 `#B98A5E`（★新增 token → `COLOR_EARTH`） | 铁甲(R) / 山童(N) |

- **形状为粗冗余**：仅三角/圆/方三档，金&火共三角、木&水共圆、土独方 → **单靠形状不能唯一区分 5 行**，必须与「图标 + 主题色」并用（即三重冗余不靠色，但也不单靠形状）。
- **图标为精冗余**：每行的 glyph 不同（剑/叶/水纹/丹/方），是灰度下区分同形两行（金 vs 火、木 vs 水）的关键。
- **火行已在既有体系定义**：火 = 丹形三角（accessibility-spec / asset-spec 已落），本表**沿用不重定义**；A4(a) 仅在此之上扩展火行「主题符文 + 朱雀/火灵识别」视觉（见 10.2）。
- ★ `COLOR_EARTH` 为新增设计 token，需 engineering-lead 在 `UIThemeController` 增补常量（其余 4 色已在调色板 / 锚点 3 中存在）。

### 10.2 火行专属视觉（朱雀 / 火灵 识别）
- **火行主题符文**：以「丹丸（朱砂圆点）+ 三焰舌」为火行 base glyph，叠加于五行符文阵（锚点 5）时居「离位」；与金行剑符、木行叶符、水行涟符、土行方符并列，构成五符闭环。
- **朱雀（SR·火·yu_zu）识别**：羽族 → 以**羽翼 + 凤翎 + 赤焰尾羽**为专属符号；主色朱砂 `#C8453A` 渐变至鎏金 `#CBA75C`（火生土之暖金边），配 SR 鎏金浮雕卡框；灵气粒子取暖橙赤。
- **火灵（N·火）识别**：以**小型赤焰精怪（火苗团 + 两点发光眼）**为符号，素灰 `#9AA3A6` 细边卡框（N 无描金），暖赤焰为唯一彩色焦点；体型小、轮廓圆润，与朱雀的华羽形成稀有度梯度。
- **灰度自测**：火行两符号（朱雀羽翼 / 火灵火苗团）在灰度下仍可凭轮廓与「丹形三角」基底 glyph，与金属剑符区分（详见 §11 / A2 灼烧）。

---

## 11. 气槽 UI 控件规格（A4(b) · 供 eng 实现）

> 气（qi）为 B-3 推荐资源（每单位 `qi_max=3`、回合 +1、觉醒技耗 1）。本控件**仅给美术/交互规格，由 eng 按规格实现**（不改任何 scripts/data）。规格对齐 art-bible §7 UI 语言、accessibility-spec Basic C/D/E + Standard J、CLAUDE.md（禁硬编码色 / 数据驱动）。

### 11.1 控件结构
- **容器**：玉质感半透面板（毛玻璃 + 描边，圆角 8–12px，8 倍数栅格），置于战斗 HUD 单位卡下方或技能栏旁。
- **气格（pip）×3**：每格一个 `qi_max` 槽，渲染为**单位本行形状 glyph**（金=三角 / 木=圆 / 水=圆 / 火=三角 / 土=方）→ 与五行形状冗余联动（§10.1）；满格填充本行主题色 + 柔光，空格显描边轮廓（灰度可辨）。
- **数字徽标**：右侧「`qi: X/3`」用 tabular nums（等宽，tnum=1），防布局抖动；与气格互为冗余（数字 + 形状 + 颜色三通道）。
- **觉醒技按钮联动**：技能按钮显「耗 1 气」角标（本行形状 glyph + 数字）；气不足时按钮置灰 + 对角划线 + 数字提示，**不靠纯色**失效。

### 11.2 交互与可访问性
- **热区**：气格与觉醒技按钮命中区 **≥44×44px**（Standard J，移动强制）；PC 可更小（hover 反馈），但移动端按 48px 网格落。
- **双重边界**：所有状态（满/空/失效）用描边 + 投影双边界，不依赖明度差（Basic B / 户外强光）。
- **减少动效**：蓄气填充动画读取 `MotionScale`，`reduce_motion` 时保留数字 + 形状 + 描边静态等效（Standard I）。
- **CVD**：气格颜色经 `COLOR_*` + CVD 后处理；三角形（金/火）靠 glyph 区分，圆形（木/水）靠 glyph 区分（Basic E）。

### 11.3 双端适配
| 端 | 布局 | 尺寸 |
|---|---|---|
| PC 横屏 ≥1024 | 单位卡下方横排 3 气格 + 右侧 tabular 数字；多栏右信息栏同显 | 气格 ≥32px（hover 态），数字 ≥24sp |
| 移动竖屏 <768 | 单位卡下方 / 技能栏上方横排 3 气格 + 数字；极简 HUD 不挤压战场 | 气格 **48×48**（热区≥44，thumb 可达） |

- 响应式：同一套资产（气格 glyph 按本行形状切换纹理）靠布局切换两态，不另出两套图（对齐 §5 卡框双态原则）。

---

**一句话总结**：本美术圣经以「水墨留白 + 工笔重彩」统一仙侠视觉身份，锁定青冥/青碧/月白/朱砂/鎏金主色板与 R→SSR 稀有度体系，并给出 6 个可直接 AI 出图的视觉锚点，可作为 Phase 1 美术方向与资产生产的唯一规范基线。（Phase 4→S3 增补 **§10 五行形状/配色权威表 [含火行扩展]** 与 **§11 气槽 UI 控件规格**，承载 A4 系统化内容，与 accessibility-spec / asset-spec 的五行冗余编码保持一致；火行形状沿用既有「丹形三角」定义。）
