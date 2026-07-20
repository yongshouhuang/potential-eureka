# 视觉锚点参考图索引（Phase 1 · AI绘图生成）

> 由主理人基于 `art/art-bible.md` 第九节「视觉锚点清单」调用 AI 绘图生成。
> 对应美术圣经锚点编号；未生成的锚点（如锚点5 灵宠vs法宝）可后续补出。

| 锚点 | 名称 | 图片路径 | 尺寸 | 用途 |
|---|---|---|---|---|
| 锚点1 | 御剑长空 | `art/references/A_solitary_young_cultivator_in_2026-07-19T16-06-36.png` | 1536×1024 | 核心氛围 / 主视觉 |
| 锚点2 | 悬浮宗门仙山 | `art/references/A_grand_immortal_sect_built_at_2026-07-19T16-07-04.png` | 1536×1024 | 场景 / 主界面背景 |
| 锚点3 | 水系剑修式神立绘 | `art/references/Full_body_character_key_visual_2026-07-19T16-07-29.png` | 1024×1536 | 角色 / 式神立绘标杆 |
| 锚点4 | SSR 仙品卡牌成品 | `art/references/Game_card_frame_mockup__xianxi_2026-07-19T16-08-05.png` | 1024×1536 | 卡牌框 / UI 标杆 |
| 锚点5 | 灵宠 vs 法宝对比 | `art/references/Split_comparison_illustration__2026-07-19T16-22-07.png` | 1536×1024 | 资产区分 / 活物vs器物标杆 |

**备注**
- 锚点5（灵宠 vs 法宝对比）已生成，用于区分活物与器物的资产管线。
- 生成的参考图为**方向性概念图**，非最终资产；正式资产须由美术按本圣经的色板/规范产出。
- 风格微调可回美术圣经第九节取原始 prompt 重新生成。

---

## S3 · 新立绘与战斗 UI 美术资产（A1–A4，2026-07-20 生成）

> 由 studio lead 基于 `art/s3-a1-a4-spec.md` 调用 AI 绘图批量生成（全量一次性 ≈25 张）。
> 命名沿用 `asset-spec.md §2.4 / §1.2`：`char_{id}_portrait_{front/side/back}`、`char_{id}_face`、`char_{id}_chibi`、`status_*`、`combo_banner`。
> 用途：式神图鉴主图 / 卡牌立绘窗 / 头像 / 战斗小人；状态 VFX 图标；连携横幅。

### A1 · 4 式神三视图（朱雀 / 虬龙 / 虎威 / 火灵）
| 式神 | id | 立绘 front | 立绘 side | 立绘 back | 头像 face | Q版 chibi | 元素/稀有度 |
|---|---|---|---|---|---|---|---|
| 朱雀 | sr_zhu_que | char_sr_zhu_que_portrait_front.png | char_sr_zhu_que_portrait_side.png | char_sr_zhu_que_portrait_back.png | char_sr_zhu_que_face.png | char_sr_zhu_que_chibi.png | 火 / SR |
| 虬龙 | r_qiu_long | char_r_qiu_long_portrait_front.png | char_r_qiu_long_portrait_side.png | char_r_qiu_long_portrait_back.png | char_r_qiu_long_face.png | char_r_qiu_long_chibi.png | 水 / R |
| 虎威 | r_hu_wei | char_r_hu_wei_portrait_front.png | char_r_hu_wei_portrait_side.png | char_r_hu_wei_portrait_back.png | char_r_hu_wei_face.png | char_r_hu_wei_chibi.png | 金 / R |
| 火灵 | n_huo_ling | char_n_huo_ling_portrait_front.png | char_n_huo_ling_portrait_side.png | char_n_huo_ling_portrait_back.png | char_n_huo_ling_face.png | char_n_huo_ling_chibi.png | 火 / N |

### A2 · 状态 VFX 图标（透明底 1:1）
| 状态 | 文件 | 形状（灰阶可辨） | 行 |
|---|---|---|---|
| 灼烧 burn | status_burn.png | 三焰火（尖顶圆底） | 火 |
| 破甲 armor_break | status_armor_break.png | 裂盾（缺角硬边） | 金 |
| 中毒 poison | status_poison.png | 泪滴（圆润+气泡） | 木 |
| 气势 momentum | status_momentum.png | 层叠上箭（尖角堆叠） | 金 |

### A3 · 连携横幅
| 资产 | 文件 | 比例 |
|---|---|---|
| 五行符文阵缎带 | combo_banner.png | 16:9 |

**备注**
- 立绘实际输出分辨率 ~832×1216（≈2:3，参考级）；生产级应按 `asset-spec §2.1` 导出 2048×3072(PC)/1024×1536(移动)；本批为方向性参考图。
- 状态图标 1:1 透明底；灰阶可辨性（四者形状互异）需 art-director 肉眼终审（非 sandbox 可自动判定）。
- 连携横幅 16:9；不遮挡战斗信息、双端安全区见 `s3-a1-a4-spec.md §3.3`。
- 结构验收：`production/qa/verify_s3_art.py` 全 25 张 PASS。
