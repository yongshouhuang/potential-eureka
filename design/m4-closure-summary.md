# M4 美术 / 音频终稿接入 · 收口总览（主理人汇编）

> **收口范围**：抽卡屏 UI 美术终稿（四元素）+ 抽卡音频终稿（17 SoundId）。
> **推进方式**：用户本轮无 Unity 运行环境，收口聚焦「规格闭环确认 + 待决裁定落地 + 文档汇编」；Unity 侧终稿资产接入与 SoundBank/AudioMixer 建立列**实跑待补**，不阻塞规格收口。
> **团队**：m4-closure（art-director 林绘澄 + audio-director 阮和鸣 并行收口终评）。
> **汇编**：主理人游承峰（不替成员下专业判定，仅汇总与一致性检查）。

---

## 1. 成员判定汇总

| 成员 | 范围 | 质量门 | 核心结论 |
|---|---|---|---|
| art-director | 四元素 UI 美术终稿（PullButton / PityProgressBar / CurrencyLabel / InsufficientCta） | **CONCERNS** | 文档可审批闭环；集成待验证；6 项 eng 钩子待派 |
| audio-director | 17 SoundId 音频终稿 | **PASS（规格层）/ CONCERNS（集成）** | 规格层全闭合；§8.2 四项已裁定；4 项实跑待补 |

- 美术交付：`design/art/m4-art-closure.md`
- 音频交付：`design/audio/m4-audio-closure.md`（并同步更新 `design/audio/m4-audio-spec.md` §8.2 状态行）

---

## 2. M4 整体质量门判定：**CONCERNS**

| 维度 | 状态 | 说明 |
|---|---|---|
| 规格完整度 | ✅ | 美术四元素资产表 + 字段映射完整；音频 17/17 SoundId 终稿规格完整 |
| 代码/字段一致性 | ✅ | 美术 §7.3 已逐字段核对运行代码（PullButton/PityProgressBar/GachaScreenController）；音频 AudioService 接口契约 100% 对齐 m4 §4 路由表 |
| 偏差闭合 | ✅ | 美术 §1 四处偏差全闭合；音频两处偏差（Rolling 可听性 / 架构真相）已在 m4 终稿闭合 |
| 集成实跑 | ⚠️ | Unity 侧终稿 PNG/WAV 接入、SpriteAtlas、9-slice、SoundBank、AudioMixer、Rolling 修正 A 均未实跑 |
| 待决裁定 | ✅ | audio §8.2 四项已由主理人按推荐默认裁定（见 §3） |

**结论**：规格层已可审批闭环，无返工项；集成/验证层待补。M4 不阻塞后续里程碑，但须排**验证窗口**（用户有 Unity 环境时）与 **engineering-lead 钩子分派**。

---

## 3. 已裁定待决项（audio §8.2，主理人按 audio-director 推荐默认采纳）

| # | 待决项 | 裁定 | 依据 |
|---|---|---|---|
| ① | Rolling 蓄力层可听性修正 | **A**（StopLoop 移至首张 `Gacha_Card_Flip_Start` 后）| 改动最小、零新增资产、与「滚动→翻面」演出直觉一致；`IAudioService` 接口零改 |
| ② | BGM 终稿层级 | **单条 ambient loop 先验收**，A/B/C 分层 stems 微动态延后 | MVP 务实，先验证「待机↔抽卡」切换 |
| ③ | `Gacha_Screen_Close` | **延后至 P2**（当前控制器未调用）| 非核心验收项，枚举/占位/分类齐备 |
| ④ | 音频中间件 | **维持 Unity AudioMixer**（MVP 不上 FMOD）| 沿用 M3 §4.6，避免外部依赖 |

> 用户若对任一项有异议，回头告知即可改，不影响已落文档。

---

## 4. 待派 engineering-lead 清单（汇总自两份 closure）

### 4.1 美术钩子（E1–E6，共 6 项）
| ID | 内容 | 优先级 | 阻塞？ |
|---|---|---|---|
| E1 | PullButton 保底触发态（Pity-Armed）代码钩子——当前仅 3 态，无 `SetPityArmed` | Medium | 否（终稿已备 sprite）|
| E2 | PityProgressBar tick 脉冲动画（消费 `DetectCrossing` 返回值驱动，当前仅返回未播）| Medium | 否 |
| E3 | `imgTrack` / `matPityFill` 序列化字段评估（美术已按现有 `_imgFill` 落地，无阻塞）| Low | 否 |
| E4 | CurrencyLabel icon 方案（TMP 内联 `<sprite>` vs sibling Image）| Medium | 否 |
| E5 | `_disabledTint` 双重去饱和协调（接入禁用 sprite 时须设白，footgun）| Medium | 否 |
| E6 | `PityProgressBar.cs` 头部注释字段名修正（整洁项）| Low | 否 |

### 4.2 音频钩子
| ID | 内容 | 优先级 | 阻塞？ |
|---|---|---|---|
| T4 | Rolling 修正 A 代码落地（eng 调 `OnPull` / `RevealSequencer` 时序；否则蓄力层近不可闻）| **High（体验）** | 否（接口零改）|

> E1–E6 + T4 均**业务代码零改风险可控**，属增强/整洁项，可并入后续 eng 冲刺排期。

---

## 5. 待补 Unity 实跑验证（用户运行环境）

| ID | 内容 | 优先级 |
|---|---|---|
| V1 | 美术终稿 PNG 真接入 prefab + SpriteAtlas + 9-slice Border | High |
| V2 | 四元素字段赋值后 prefab 视觉核对（截图）| High |
| T1 | 终稿 WAV 落 `unity/My project/Assets/Audio/Gacha/`（15 揭示/UI + BGM）| P1 |
| T2 | SoundBank ScriptableObject 创建 + 绑定各 SoundId → AudioClip[]/Category/Volume/变体 | P1 |
| T3 | AudioMixer 6 组（Master/Music/Ambient/SFX/UI/VO）+ Snapshot ducking（rolling -3 / SSR climax -8 / pity -4 / insufficient -2）| P1 |
| — | 完成后跑 `m4-audio-spec.md §7` QA 验收清单闭环 | — |

> 灰盒阶段 `PlaceholderAudioProvider` 已能听、`AudioService` 未绑 SoundBank 时回退程序化合成，开发与 QA 时序不受阻塞。

---

## 6. 已知风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| R-M4-1 终稿资产未实跑 | 规格正确但接入行为未知 | 排验证窗口 V1/V2/T1–T3；灰盒可听/可看，不阻塞开发 |
| R-M4-2 Rolling 层近不可闻（修正 A 未落）| 蓄力情绪缺失 | T4 排 eng；接口零改，低工作量 |
| R-M4-3 ducking 未生效（Mixer 未建）| 层级混音缺失 | T3；未建时回退音量数学（EffectiveVolume），可听但不分层 |
| R-M4-4 用户无 Unity 时间 | 验证滞后 | 文档先行收口，验证与开发解耦排期 |

---

## 7. 下一步选项（待主理人/用户定）

- **A. 提交 M4 收口文档到 main**（推荐，轻量可逆；含本汇编 + 两份 closure + m4-audio-spec §8.2 更新）
- **B. 分派 eng 钩子**（E1–E6 + T4 并入后续 eng 冲刺）
- **C. 排 Unity 验证窗口**（V1/V2/T1–T3，用户有环境时执行）
- **D. 就此打住**，M4 收口存档，回头再续

> 推荐顺序：A（文档入库）→ B（钩子排期，可与 C 并行）。C 取决于用户 Unity 时间。
