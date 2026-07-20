# 仙侠卡牌 · S3 美术资产规格（A1–A4）
**项目**：仙侠卡牌（Xianxia Card Battler）　**阶段**：Phase 5 制作 · Sprint S3　**引擎**：Godot 4.x（2D-first）　**平台**：PC Steam（横屏 ≥1024px）+ 移动 iOS/Android（竖屏 <768px）
**编写**：art-director 林绘澄　**对齐**：art/art-bible.md（§3–§11）、art/accessibility-spec.md（Basic/Standard）、art/asset-spec.md（§1.2/§1.7/§2.1）、production/design-review/s3-design-review.md（§5.3/§6.3）、production/phase4-assembly.md
**范围声明**：本文件为**纯美术方向 / 规格文档**。不修改任何 `scripts/*.gd` 或 `data/*.json`；不调用图像生成工具出图——仅产出规格 + 可直接 AI 出图 prompt，实际出图由后续步骤执行。

---

## 0. 对齐说明与前置结论

### 0.1 已读并严格对齐
- `art/art-bible.md`（§3 字体 / §4 角色 / §5 卡框双态 / §6 场景 / §7 UI / §8 可访问性 / §9 锚点 1–6 / **§10 五行形状配色 / §11 气槽**，本文件撰写时已同步增补）。
- `data/shikigami/shikigami_defs.json`（4 新卡：sr_zhu_que / r_qiu_long / r_hu_wei / n_huo_ling）。
- `data/battle/status_config.json`（burn / poison / armor_break / momentum）。
- `data/battle/bond_combos.json`（jian_zong / tie_bi / yu_zu / long_zu / hu_zu，5 组）。
- `production/design-review/s3-design-review.md`（§5.3 式神归属 / §6.3 A1–A4 前置清单）。
- `production/phase4-assembly.md`（锚点 5 五行符文阵 / 双端断点）。

### 0.2 关键前置结论（冲突排查）
1. **火行形状已定义，非缺口**：`art/accessibility-spec.md §1.1 E` 与 `art/asset-spec.md §1.7` 已定义「火 = 丹形三角」。本文件 A4(a) 为**沿用 + 扩展**（火行主题符文 + 朱雀/火灵识别），**不重定义**；并将五行权威表收口进 `art-bible.md §10`。
2. **数据文件与 art-bible 无冲突**：4 新卡元素/稀有度/bond、4 状态、5 连携组均与 art-bible §10 五行表及 §5 卡框体系一致。
3. **唯一需补充的设计 token**：`COLOR_EARTH`（赭石 `#B98A5E`）为新增，需 eng 在 `UIThemeController` 增补（其余 4 行色已存在）。详见 §4.1 与文末 §6。
4. **状态→行映射无数据载体**：`status_config.json` 不含 `element` 字段；burn=火 / poison=木 / armor_break=金 / momentum=金 来自 `s3-design-review.md §2.6` 设计侧。建议 eng 后续在 `status_config` 增 `element` 字段（不在本文件修改范围，仅提示）。

### 0.3 红线（全程贯彻）
- **三重冗余不靠色**：A2 状态 / A4 气槽全程「形状 + 图标 + 数字 + 颜色」多通道，灰阶可辨（art-bible §8 / accessibility-spec Basic D/E）。
- **双端适配**：PC 横屏 ≥1024 / 移动竖屏 <768（art-bible §7 / accessibility-spec §3）。
- **沿用既有体系**：卡框=art-bible §5；五行形状=art-bible §10；连携=锚点 5；不另起炉灶。
- **不改代码/数据**：所有 `res://assets` 命名沿用 `asset-spec.md §2.4`。

---

## 1. A1 · 4 张新立绘三视图（朱雀 / 虬龙 / 虎威 / 火灵）

### 1.0 总体规范（沿用 art-bible §5 卡框双态 + asset-spec §1.2）
- **卡框双态**：每卡套用 art-bible §5 既有 R/SR/N 卡框（立绘态 / 卡面态同套资产响应式切换）：朱雀→`card_frame_sr`（鎏金浮雕边 + 角饰 + 2 钻星）；虬龙/虎威→`card_frame_r`（青碧细边 + 1 星）；火灵→`card_frame_base` + 素灰 `#9AA3A6` tint（N 无描金、无角星）。
- **三视图定义**（每式神交付 3 张全身立绘 + 头像 + Q版，套 `asset-spec §1.2`）：
  - **正面（front）**：主图，全脸 + 核心视觉符号 + 主服饰 + 本行灵气；用于卡牌立绘窗 / 图鉴大图。
  - **侧面（side，3/4 视角）**：展示侧颜 + 侧面专属符号（朱雀翼缘羽、虬龙龙角/侧鳞、虎威虎纹侧、火灵火苗侧），验证剪影可读性。
  - **背面（back）**：展示后背符号（羽翼/鳞片/虎纹背/火苗尾）、发饰/背饰、收势；确认背剪影与正面可区分。
- **交付分辨率/格式**（对齐 asset-spec §2.1）：全身立绘 2048×3072（PC）/ 1024×1536（移动），PNG（源）→ VRAM 压缩；头像 512×512 / 256×256；Q版 512×512 / 256×256。三视图同分辨率同格式，仅姿态/角度差异。
- **命名**：`char_{id}_portrait_front` / `_side` / `_back` / `char_{id}_face` / `char_{id}_chibi`（沿用 `asset-spec §2.4` `char_{id}_portrait` 约定扩展 `_front/_side/_back`）。

### 1.1 朱雀 · sr_zhu_que（SR / 火 / yu_zu）
- **风格锚定**：援引 art-bible **锚点 3（角色立绘语言，7.5 头身工笔）** + **§10.2 火行识别** + **§5 SR 卡框**。灵宠/法宝分类：偏「灵宠感」（羽翼活物，呼应锚点 5 左）。
- **构图与姿态**：居中微 contrapposto 全身，双翼自肩后展开（凤翎赤焰尾羽），左手掐火诀、右手虚托丹丸灵火；左上轮廓光。7.5 头身修长飘逸。
- **五行配色**：主朱砂 `#C8453A` 渐变鎏金 `#CBA75C`（火生土暖金边），深青冥 `#1F3A3D` 影，月白 `#E8ECEF` 高光；灵气粒子暖橙赤。
- **三视图角度**：正面=展翼正面掐诀；侧面=收翼 3/4 侧颜显翼缘羽脉；背面=背展双翼 + 赤焰尾羽垂落。
- **图鉴引用**：`char_sr_zhu_que_portrait_front` 为图鉴主图；卡框 `card_frame_sr`；承载灼烧（burn）归属（s3-design-review §5.3）。
- **出图 Prompt（已备）**：
  - **EN（front）**：`Full-body character key visual of Zhuque the Vermilion Bird, xianxia shikigami, SR rarity. Humanoid phoenix celestial maiden, 7.5 head proportion, slender elegant. Flowing vermilion (#C8453A) and gilt (#CBA75C) layered celestial robes with phoenix-feather embroidery, magnificent flame-tipped wing plumes unfolding behind shoulders, crimson fire aura, glowing cinnabar runes. Gongbi fine-brush coloring over white-line sketch, soft gradient lighting, iridescent sheen on feathers. Neutral ink-teal (#1F3A3D) background with faint ember particles, minimal props. Composition: centered slight contrapposto, full body, rim light from upper left. Palette: cinnabar-red + gilt + moon-white highlights, deep teal shadow. Crisp linework, clean readable silhouette, feather texture distinct. Mood: majestic, blazing, divine. --ar 2:3 --niji 6`
  - **中（front）**：朱雀·SR 仙侠式神全身立绘，人形凤羽仙姬，7.5 头身修长；朱砂渐变鎏金层叠天衣、凤翎赤焰尾羽、背后展翼、赤焰灵气、发光丹符；工笔设色加白描、柔光、羽脉微虹彩；墨青背景浮赤烬；居中微扭姿、左上轮廓光；朱砂+鎏金+月白高光+深青影；线稿利落、剪影清晰、羽理分明；尊贵炽烈。竖版 2:3。
  - **侧/背变体（追加到上述 prompt 末尾）**：`— side view: wings folded showing edge feather pattern, three-quarter profile, vermilion robe side draping, readable profile silhouette.` / `— back view: rear, back wing plumes and trailing flame tail feathers, back ornament, sheathed form, silhouette distinct from front.`（均保持 `--ar 2:3 --niji 6`）

### 1.2 虬龙 · r_qiu_long（R / 水 / long_zu）
- **风格锚定**：援引 art-bible **锚点 3** + **§10.1 水行（冰蓝/水纹圆）** + **§5 R 卡框**；龙族二线。
- **构图与姿态**：居中微 contrapposto，少年龙修士，额生独角 + 龙族冠，手持涟漪水玉戟；衣摆浮水波、身周水雾灵气自转。
- **五行配色**：冰蓝 `#6FB7C9` + 月白 `#E8ECEF`，深青冥 `#1F3A3D` 影，银高光；水行主题。
- **三视图角度**：正面=持戟正面、水玉戟涟漪；侧面=龙角侧显 + 侧鳞水纹；背面=脊鳞 + 水纹披风 + 戟负背。
- **图鉴引用**：`char_r_qiu_long_portrait_front`；卡框 `card_frame_r`；补全 long_zu（青龙+虬龙=2）。
- **出图 Prompt（已备）**：
  - **EN（front）**：`Full-body character key visual of Qiulong the Horned Flood-Dragon, xianxia shikigami, R rarity. Youthful dragon cultivator, 7.5 head proportion, slender. Ice-blue (#6FB7C9) and moon-white layered water-element robes with coiled-dragon scale embroidery, a small horn and draconic crest, wielding a rippling water-jade glaive, surrounded by floating water ripples and mist. Gongbi fine-brush, soft gradient light, iridescent sheen. Ink-teal (#1F3A3D) background with water ripples, minimal props. Composition: centered slight contrapposto, full body, rim light upper left. Palette: ice-blue + moon-white + deep teal shadow + silver highlights. Crisp linework, readable silhouette, scale texture distinct. Mood: cool, fluid, mystic. --ar 2:3 --niji 6`
  - **中（front）**：虬龙·R 仙侠式神全身立绘，少年龙修士，7.5 头身；冰蓝月白层叠水行长袍、盘龙鳞绣、独角龙冠、持涟漪水玉戟、浮水雾灵气；工笔柔光、鳞甲微虹彩；墨青水纹背景；居中微扭姿、左上轮廓光；冰蓝+月白+深青影+银高光；线稿利落、剪影清晰、鳞理分明；清冷灵动。竖版 2:3。
  - **侧/背变体**：`— side view: horn and draconic crest in profile, side scale pattern visible, water robe draping.` / `— back view: dorsal scales, water-pattern cape, glaive slung on back, distinct silhouette.`（`--ar 2:3 --niji 6`）

### 1.3 虎威 · r_hu_wei（R / 金 / hu_zu）
- **风格锚定**：援引 art-bible **锚点 3** + **§10.1 金行（鎏金/剑形三角）** + **§5 R 卡框**；金行=剑，虎威取兵刃符号。
- **构图与姿态**：居中微 contrapposto，虎 Warrior 修士，虎耳 + 虎尾 motif，身披鎏金淡玉甲（虎纹），腰侧佩剑（metal=blade glyph），金色灵气。
- **五行配色**：鎏金 `#CBA75C` + 月白 `#E8ECEF`，深青冥 `#1F3A3D` 影；金行主题。
- **三视图角度**：正面=按剑而立、虎纹甲；侧面=虎耳侧显 + 侧甲虎纹；背面=虎尾 + 背甲纹 + 剑负背。
- **图鉴引用**：`char_r_hu_wei_portrait_front`；卡框 `card_frame_r`；补全 hu_zu（白虎+虎威=2）。
- **出图 Prompt（已备）**：
  - **EN（front）**：`Full-body character key visual of Huwei the Tiger-Majesty, xianxia shikigami, R rarity. Tiger-warrior cultivator, 7.5 head proportion, powerful balanced stance. Gilt (#CBA75C) and pale-jade armor with tiger-stripe patterns, tiger ears and tail motif, a blade/sword at side (metal=blade glyph), golden spirit aura. Gongbi fine-brush, soft gradient light, metallic sheen on armor. Ink-teal (#1F3A3D) background, minimal props. Composition: centered slight contrapposto, full body, rim light upper left. Palette: gilt + moon-white + deep teal shadow. Crisp linework, readable silhouette, stripe texture distinct. Mood: fierce, regal, sharp. --ar 2:3 --niji 6`
  - **中（front）**：虎威·R 仙侠式神全身立绘，虎 Warrior 修士，7.5 头身；鎏金淡玉虎纹甲、虎耳虎尾、腰侧佩剑（金行兵刃）、金色灵气；工笔柔光、甲胄金属微光；墨青背景；居中微扭姿、左上轮廓光；鎏金+月白+深青影；线稿利落、剪影清晰、虎纹分明；威猛贵气。竖版 2:3。
  - **侧/背变体**：`— side view: tiger ear in profile, side armor stripe pattern, blade hilt visible.` / `— back view: tiger tail, back armor striping, sword slung on back, distinct silhouette.`（`--ar 2:3 --niji 6`）

### 1.4 火灵 · n_huo_ling（N / 火 / 无 bond）
- **风格锚定**：援引 art-bible **§4 灵宠视觉（圆润活物·暖光）** + **§10.2 火灵识别** + **§5 N 卡框（素灰无描金）**；低稀有度火行，早期灼烧教学载体。
- **构图与姿态**：非人形——小型火苗精灵（圆润火团 + 两点发光眼 + 小火舌附肢），悬浮自转，暖赤核心光。2–3 头身 Q版感但立绘按全身图交付。
- **五行配色**：朱砂 `#C8453A` 核心 + 暖金 `#CBA75C` 边缘光 + 月白 `#E8ECEF` 火花，墨青 `#1F3A3D` 背景；唯一彩色焦点为赤焰。
- **三视图角度**：正面=火团正面双眼；侧面=火舌侧附肢；背面=火团背弧 + 尾焰。
- **图鉴引用**：`char_n_huo_ling_portrait_front`；卡框 `card_frame_base` + 素灰 tint；与朱雀形成稀有度梯度。
- **出图 Prompt（已备）**：
  - **EN（front）**：`Character key visual of Huoling the Fire Spirit, xianxia shikigami, N rarity. A small cute flame sprite creature — a round wisp of living fire with two glowing eyes, small flame-lick appendages, warm cinnabar (#C8453A) core glow, floating embers. Gongbi-cute style, soft glow, rounded organic form (spirit-beast, warm). Matching ink-teal (#1F3A3D) background. Composition: centered, full creature visible, simple clear silhouette. Palette: cinnabar-red core + warm gold rim + moon-white sparkle on dark teal. Crisp, adorable, readable. Mood: lively, warm, tiny. --ar 2:3 --niji 6`
  - **中（front）**：火灵·N 仙侠式神立绘，小型赤焰精灵——圆润火团、两点发光眼、小火舌附肢、暖朱砂核心光、浮赤烬；工笔萌系、柔光、圆润活物（灵宠暖感）；墨青背景；居中、全貌、剪影简明；朱砂核心+暖金边+月白火花+深青底；清晰可爱。竖版 2:3。
  - **侧/背变体**：`— side view: flame-lick appendage on side, rounded core profile.` / `— back view: back arc of fire wisp, trailing ember tail, distinct silhouette.`（`--ar 2:3 --niji 6`）

### 1.5 图鉴 12 立绘引用关系（S3 全表）
| # | id | 名称 | 稀有度 | 元素 | bond | 卡框资产 | 立绘主图资产 | 三视图交付 |
|---|---|---|---|---|---|---|---|---|
| 1 | ssr_qing_long | 青龙 | SSR | 金 | jian_zong+long_zu | card_frame_ssr | char_ssr_qing_long_portrait | 既有（P0） |
| 2 | ssr_bai_hu | 白虎 | SSR | 金 | jian_zong+hu_zu | card_frame_ssr | char_ssr_bai_hu_portrait | 既有 |
| 3 | sr_you_ming | 幽冥 | SR | 木 | jian_zong | card_frame_sr | char_sr_you_ming_portrait | 既有 |
| 4 | sr_xuan_feng | 玄风 | SR | 木 | jian_zong | card_frame_sr | char_sr_xuan_feng_portrait | 既有 |
| 5 | r_tie_jia | 铁甲 | R | 土 | tie_bi | card_frame_r | char_r_tie_jia_portrait | 既有 |
| 6 | r_qing_yu | 青羽 | R | 水 | yu_zu | card_frame_r | char_r_qing_yu_portrait | 既有 |
| 7 | n_cao_li | 草隶 | N | 木 | — | card_frame_base+素灰 | char_n_cao_li_portrait | 既有 |
| 8 | n_shan_tong | 山童 | N | 土 | tie_bi | card_frame_base+素灰 | char_n_shan_tong_portrait | 既有 |
| 9 | **sr_zhu_que** | **朱雀** | **SR** | **火** | **yu_zu** | **card_frame_sr** | **char_sr_zhu_que_portrait_front** | **★ S3 三视图** |
| 10 | **r_qiu_long** | **虬龙** | **R** | **水** | **long_zu** | **card_frame_r** | **char_r_qiu_long_portrait_front** | **★ S3 三视图** |
| 11 | **r_hu_wei** | **虎威** | **R** | **金** | **hu_zu** | **card_frame_r** | **char_r_hu_wei_portrait_front** | **★ S3 三视图** |
| 12 | **n_huo_ling** | **火灵** | **N** | **火** | — | **card_frame_base+素灰** | **char_n_huo_ling_portrait_front** | **★ S3 三视图** |

> S3 仅补 4 张新卡三视图（front/side/back + face + chibi 各一），既有的 8 张沿用 P0/P1 已铺立绘；卡框资产全部沿用 art-bible §5 / asset-spec §1.3，不新增卡框。

---

## 2. A2 · 状态 VFX 规格（灼烧 / 破甲 / 中毒 / 气势）

### 2.0 红线（art-bible §8 / accessibility-spec Basic D/E）
- **每个状态 = 形状 + 图标 + 数字徽标 + 颜色 四重冗余**，绝不单靠颜色区分（灰阶可辨）。
- **四者形状彼此可辨**：灼烧=上扬火舌（三角/焰）/ 破甲=裂盾（破损硬边）/ 中毒=泪滴水泡（圆润滴）/ 气势=层叠上箭（尖角堆叠）。灰度下轮廓互异。
- **数字徽标**：层数 `stacks`（burn/poison/armor_break/momentum 均 `max_stacks=3`）+ 剩余回合 `turns_left`（`duration=3`），由 UI 以 tabular nums 渲染于图标角（非图标图内文字）。
- **动效**：读取 `MotionScale`；`reduce_motion` 时保留形状+图标+数字静态等效（Standard I）。
- **灰阶自检**：每项末列「灰阶可辨性自检」。

### 2.1 灼烧 burn（火 / dot · 朱雀觉醒归属）
- **形状语言**：上扬三焰舌（丹形三角基底 + 火苗），尖顶圆底，动则向上窜动。
- **图标**：朱砂 `#C8453A` 三焰火 glyph，金 `#CBA75C` 细描边，48px 网格，透明底，高对比剪影。
- **数字徽标**：角标 `stacks/3`（如 `②/3`）+ 小回合点 `●●●`；水克火时 `max_stacks=1` 显 `①`、回合 `●`（s3-design-review §2.3）。
- **动效**：火舌轻微向上窜动（0.5s 循环）+ 目标身上赤焰粒子；`reduce_motion` 静态火 glyph + 数字不变。
- **灰阶自检**：✓ 尖顶圆底焰形，与破甲（缺角硬边）、中毒（圆润滴）、气势（尖角堆叠）均异；颜色失效仍可读。
- **出图 Prompt（已备）**：
  - **EN**：`UI status icon, xianxia style, a cinnabar-red (#C8453A) upward flame shape — a rounded pellet base with three flame tongues (丹形三角), bold clean line, thin gilt (#CBA75C) rim-light, 48px grid, flat with subtle glow, transparent background, high-contrast silhouette for grayscale readability. --ar 1:1 --niji 6`
  - **中**：仙侠风 UI 状态图标，朱砂三焰火形（丹丸圆底 + 三火舌），粗利线稿、鎏金细描边、48px 网格、平涂微光、透明底、灰阶高对比剪影。1:1。

### 2.2 破甲 armor_break（金 / debuff · 青龙觉醒归属）
- **形状语言**：破损盾/甲片——硬边几何、缺一角 + 斜裂痕，静止无窜动。
- **图标**：鎏金 `#CBA75C` 裂盾 glyph，深裂痕描线，48px 网格，透明底。
- **数字徽标**：角标 `stacks/3`；每层 `pct_per_stack=0.05` 降防，UI 可在 tooltip 显 `-X%`（数字冗余）。
- **动效**：裂痕处金屑微落；`reduce_motion` 静态裂盾 + 数字。
- **灰阶自检**：✓ 缺角硬边 + 斜裂，与火（圆底尖顶）、水（圆润滴）、气势（尖角堆叠上扬）异。
- **出图 Prompt（已备）**：
  - **EN**：`UI status icon, xianxia style, a shattered gilt (#CBA75C) shield plate with a cracked fracture line and a broken corner, bold clean line, 48px grid, flat, transparent background, distinct angular broken silhouette for grayscale readability. --ar 1:1 --niji 6`
  - **中**：仙侠风 UI 状态图标，鎏金裂盾——缺角 + 斜裂痕，粗利线稿、48px 网格、平涂、透明底、灰阶可辨硬边剪影。1:1。

### 2.3 中毒 poison（木 / dot · 幽冥觉醒归属）
- **形状语言**：泪滴/药滴——圆润水滴 + 内部气泡 + 小骷点，柔和无棱。
- **图标**：青碧 `#4FA39B` 水滴 glyph（内含气泡/骷点），48px 网格，透明底。
- **数字徽标**：角标 `stacks/3` + 回合点；火克火压制时 `max_stacks=1`（s3-design-review §2.6）。
- **动效**：气泡缓缓上浮；`reduce_motion` 静态水滴 + 数字。
- **灰阶自检**：✓ 圆润滴形（vs 火尖顶 / 甲缺角 / 气势堆叠），且气泡/骷点增强辨识；与同为圆形的水行符（水纹）靠「滴+气泡」区别。
- **出图 Prompt（已备）**：
  - **EN**：`UI status icon, xianxia style, a green (#4FA39B) teardrop potion droplet with inner bubbles and a tiny skull-dot mark, bold clean line, 48px grid, flat, transparent background, rounded teardrop silhouette distinct from flame/shield. --ar 1:1 --niji 6`
  - **中**：仙侠风 UI 状态图标，青碧泪滴药丸（内含气泡 + 小骷点），粗利线稿、48px 网格、平涂、透明底、灰阶可辨圆润滴形。1:1。

### 2.4 气势 momentum（金 / selfbuff · 白虎觉醒归属）
- **形状语言**：层叠上箭 / 上扬尖角（chevron 堆叠），向上递进，动则逐层亮起。
- **图标**：鎏金 `#CBA75C` 三层上箭 glyph，48px 网格，透明底。
- **数字徽标**：角标 `stacks/3`（每层 `dmg_per_stack=0.04` 增伤）；与破甲同金行色 → **靠形状+图标区分**（破甲=裂盾、气势=上箭）。
- **动效**：由下而上逐层点亮；`reduce_motion` 静态上箭 + 数字。
- **灰阶自检**：✓ 尖角堆叠上扬，与破甲（缺角静止硬边）异；同金行色下形状/图标为唯一区分，灰阶成立。
- **出图 Prompt（已备）**：
  - **EN**：`UI status icon, xianxia style, stacked rising chevrons/arrows pointing upward (momentum), gilt (#CBA75C), bold clean line, 48px grid, flat, transparent background, angular stacked-chevron silhouette distinct from cracked shield. --ar 1:1 --niji 6`
  - **中**：仙侠风 UI 状态图标，鎏金层叠上箭（气势），粗利线稿、48px 网格、平涂、透明底、灰阶可辨尖角堆叠剪影。1:1。

### 2.5 状态图标汇总（四者灰阶互辨矩阵）
| 状态 | 行 | 形状 | 图标 | 与余三者灰阶差异点 |
|---|---|---|---|---|
| 灼烧 | 火 | 尖顶圆底焰 | 三焰火 | 唯一「向上窜动尖顶」 |
| 破甲 | 金 | 缺角硬边 | 裂盾 | 唯一「破损静止硬边」 |
| 中毒 | 木 | 圆润滴 | 水滴+气泡 | 唯一「圆润滴+内泡」 |
| 气势 | 金 | 尖角堆叠 | 层叠上箭 | 唯一「上扬尖角堆叠」 |

---

## 3. A3 · 连携横幅规格（锚点 5 五行符文阵意象）

### 3.0 红线与原则
- **意象**：锚点 5 五行符文阵——环形五符（金剑三角/木叶圆/水涟圆/火丹三角/土方）构成闭环，激活组对应行符亮起。
- **承载数据**：监听 `EventBus.bond_combo(group_id, bonus_pct)`，横幅显 `bonus_pct`（如 0.175 → 文案「+17.5%」），tabular nums。
- **三重冗余**：横幅以「五行符文（形状）+ 组名文字 + 数值」三通道表达，不靠色（Basic E）。

### 3.1 构图与五行符文元素
- **形态**：横向玉质感半透缎带（云纹/剑纹角饰，对齐 §5 卡框语言），中央五行符文环（直径约占横幅高 60%），激活组行符高亮 + 其余四符暗描。
- **组→行符映射**：
  - jian_zong 剑宗（金+木）→ 金符+木符亮
  - tie_bi 铁壁（土）→ 土符亮
  - yu_zu 羽族（水+火）→ 水符+火符亮（含朱雀火符）
  - long_zu 龙族（金+水）→ 金符+水符亮
  - hu_zu 虎族（金）→ 金符亮
- **文案**：左「{组名} 连携」+ 右「+{pct}%」（tabular）；如 `羽族 连携  +17.5%`。

### 3.2 动效
- 进场：符文环自中心旋开 + 激活符由暗转亮（0.4s），数值自 0 滚动至目标（tabular，防抖）；停留 ~1.5s 后上滑淡出。
- 读取 `MotionScale`；`reduce_motion` 时静态显符文环+终值，无旋转/滚动（Standard I）。

### 3.3 不遮挡战斗信息 + 双端安全区
- **不遮挡**：横幅置战斗 HUD **顶部居中缎带**（PC 多栏时避开中战场与右信息栏上缘；移动竖屏贴顶、不压手牌/技能栏）。淡出后让出空间。
- **双端安全区**：
  - PC 横屏 ≥1024：横幅宽 ≤ 屏宽 60%、高 ≤ 96px，顶部 y≈8px、水平居中；左右留白显战场。
  - 移动竖屏 <768：横幅满宽（留 8px 边距）、高 ≤ 56px，贴顶 y≈4px；底部手牌/技能栏 ≥44px 热区不被压（Standard J）。
- **对比度**：缎带深墨底 `#122426` + 月白 `#E8ECEF` 文字（≥4.5:1，Basic A），激活符色经 `COLOR_*`。

### 3.4 出图 Prompt（已备）
- **EN**：`Game UI banner illustration, xianxia style, a horizontal five-element rune-array ribbon: a circular ring of five runes (metal sword-triangle gilt / wood leaf-circle jade / water ripple-circle ice-blue / fire cinnabar-pellet triangle / earth square ochre) glowing, the active bond group's element runes brightened. Semi-transparent jade panel with cloud-and-sword corner ornaments, center shows a bonus percentage in bold tabular numerals with gilt accents. Palette: ink-teal base + five-element colors + moon-white text + gilt frame. Elegant, readable, not occluding battle. --ar 16:9 --niji 6`
- **中**：仙侠风游戏 UI 连携横幅，横向五行符文阵缎带——五符环（金剑三角鎏金/木叶圆青碧/水涟圆冰蓝/火丹三角朱砂/土方赭石）发光、激活组行符高亮；玉质半透面板、云剑角饰，中央粗体等宽数值带鎏金；墨青底+五色+月白字+鎏金框；雅致清晰、不挡战斗。16:9。

---

## 4. A4 · 火行形状/配色（4(a)）+ 气槽 UI 控件（4(b)）

### 4.1 (a) 火行专属形状与配色（朱雀/火灵识别）
- **形状**：沿用 art-bible §10.1 既有定义——火 = **丹形三角**（朱砂圆点丹丸 + 三焰舌基底 glyph）。**不重定义**（见 §0.2 结论 1）。
- **配色**：`COLOR_FIRE = #C8453A`（朱砂）；火行主题符文见 art-bible §10.2（丹丸居五行符文阵「离位」）。
- **朱雀识别**：羽翼+凤翎+赤焰尾羽 + 朱砂→鎏金暖金边；SR 鎏金浮雕框。
- **火灵识别**：小型赤焰精怪（火苗团+发光眼）+ 素灰 N 框；暖赤焰为唯一焦点。
- **与既有体系一致扩展**：金（剑三角）/木（叶圆）/水（涟圆）/火（丹三角）/土（方）五符闭环，火行作为其一，已在 art-bible §10 收口为权威表，供 VFX/UI/CVD 统一引用。

### 4.2 (b) 气槽 UI 控件规格（★ UI 控件，eng 实现，非出图）
> 本控件**仅给规格**，由 eng 按 `art-bible §11` + 本规格实现；不改任何 scripts/data。

- **数据**：每单位 `qi_max=3`、回合 +1、觉醒技耗 1（s3-design-review §4.4 / E6）。
- **结构**：玉质半透面板（圆角 8–12px）；3 气格（pip）渲染为**单位本行形状 glyph**（金=三角/木=圆/水=圆/火=三角/土=方，与 §10.1 冗余联动）；右侧 `qi: X/3` tabular nums（tnum=1，防抖）。
- **状态**：满格=本行主题色+柔光；空格=描边轮廓（灰度可辨）；气不足时觉醒技按钮置灰+对角划线+数字提示（不靠纯色）。
- **热区**：气格/觉醒技按钮命中区 **≥44×44px**（Standard J，移动 48px 网格）；PC hover 态可更小。
- **双重边界**：描边+投影双边界（Basic B / 户外强光）。
- **减少动效**：填充动画读 `MotionScale`，`reduce_motion` 保留数字+形状+描边静态等效（Standard I）。
- **双端**：PC ≥1024 横排 3 格+数字（气格≥32 hover）；移动 <768 横排 3 格 48×48+数字、不压手牌（Standard J）。
- **命名（资产层）**：`ui_qi_gauge`（容器）、`ui_qi_pip_{metal/wood/water/fire/earth}`（5 形状纹理，复用 `shape_*` + `COLOR_*`）、`ui_qi_num`（tabular Label 样式）。

---

## 5. 出图 prompt 就绪清单 / UI 控件清单（文末标注）

### 5.1 已备「可直接 AI 出图 prompt」（视觉资产）
| 项 | 资产 | prompt 位置 | 数量 |
|---|---|---|---|
| A1 | 朱雀三视图（front/side/back） | §1.1 | 3 视角 + face/chibi 变体 |
| A1 | 虬龙三视图 | §1.2 | 3 视角 |
| A1 | 虎威三视图 | §1.3 | 3 视角 |
| A1 | 火灵三视图 | §1.4 | 3 视角 |
| A2 | 灼烧图标 | §2.1 | 1 |
| A2 | 破甲图标 | §2.2 | 1 |
| A2 | 中毒图标 | §2.3 | 1 |
| A2 | 气势图标 | §2.4 | 1 |
| A3 | 连携横幅 | §3.4 | 1 |

### 5.2 「UI 控件规格，需 eng 实现」（非出图）
| 项 | 控件 | 规格位置 |
|---|---|---|
| A4(b) | 气槽 UI 控件（含 5 行形状 pip / tabular 数字 / ≥44px 热区 / 双端） | §4.2 + art-bible §11 |

> 说明：A1/A2/A3 视觉资产已附中/英出图 prompt，供后续实际出图；A4(b) 气槽为 UI 控件，**art 只给规格，eng 按 `art-bible §11` 实现**，不出图 prompt。

---

## 6. 冲突与建议（art-bible / 数据 vs 当前）

| # | 发现 | 性质 | 建议 |
|---|---|---|---|
| 1 | 火行形状（丹形三角）**已在** accessibility-spec §1.1 E / asset-spec §1.7 定义，art-bible 正文此前未含完整五行表 | 文档分散（非数据冲突） | 已通过 art-bible §10 收口为权威表；A4(a) 沿用不重定义。✅ 已处理 |
| 2 | `COLOR_EARTH`（赭石 `#B98A5E`）为土行新增设计 token，原调色板无土行专属色 | 需 eng 增补常量 | 请 engineering-lead 在 `UIThemeController` 增补 `COLOR_EARTH`（CLAUDE.md 禁硬编码色）。⚠️ 建议 |
| 3 | `status_config.json` 无 `element` 字段；burn/poison/armor_break/momentum 的行归属仅在设计文档（s3-design-review §2.6） | 数据载体缺字段 | 建议 eng 在 `status_config` 增 `element`（火/木/金/金），便于状态 VFX/符文联动取色；不在本文件修改范围。⚠️ 建议 |
| 4 | 五行形状仅 3 档（三角/圆/方），金&火共三角、木&水共圆 | 设计既定（非冲突） | 维持「形状(粗)+图标(精)+颜色」三重；图标为同形两行区分关键，已落实（§10.1）。✅ 一致 |
| 5 | 数据文件（shikigami/status/bond）与 art-bible §5/§10 完全对齐 | 无冲突 | 无需改动。✅ |

**未自行扩大修改范围声明**：本文件与 art-bible §10/§11 增补均未改动任何 `scripts/*.gd` 或 `data/*.json`；仅新增美术规格文档与 art-bible 最小增补（§10/§11），未触动 §1–§9 既有结构。

---

【交付签名】art-director 林绘澄 · S3 A1–A4 美术资产规格 · 已对齐 art-bible（含 §10/§11 增补）/ accessibility-spec / asset-spec / s3-design-review / phase4-assembly。
