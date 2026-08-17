# 仙侠卡牌项目 · M4 抽卡音频收口终评（Gacha Audio M4 Closure Review）

> 评审人：audio-director（阮和鸣）
> 输入：`design/audio/m4-audio-spec.md` v1.0（终稿规格）、`design/audio/gacha-audio-spec.md` v1.1（基线，已定稿）、`src/unity/Features/Audio/AudioService.cs`（已落接口）
> 范围：M4「抽卡音频终稿接入」规格收口与质量门判定
> 结论概览：**质量门 = PASS（规格层闭环）**；四项待决已由主理人默认裁定闭合；**集成 / 资产 / 代码落地 7 项实跑待补**（用户本回合不跑 Unity，列为 P1/P2/P3 跟踪，非规格缺陷）。

---

## 1. 质量门判定

- **判定：PASS**（规格层 —— 方向已定、17 SoundId 全规格可审批、接口契约已落、4 项待决已裁定、集成步骤与 QA 清单齐备）。
- **CONCERNS（执行 / 验证缺口，非规格缺陷）**：终稿 WAV 落盘、SoundBank、AudioMixer + Snapshot ducking、Rolling 修正 A 代码落地 4 项本回合未实跑（用户不跑 Unity）；须作为 engineering + QA 待办跟踪，不阻塞规格审批。
- 本评不写实现代码；仅更新规格状态（`m4-audio-spec.md` §8.2）+ 产出本评审文档。

### 1.1 PASS 依据（逐项）

- 音频方向已定稿（`gacha-audio-spec` v1.1：仙侠仪式感 + 稀有度递进取悦，与 art §8 对齐）— 无需重议。
- 17 SoundId 终稿资产规格完整（m4 §3 全字段：类型/总线、风格、时长、格式/声道、循环、命名、t 锚点、混音、变体）。
- `SoundId` 枚举冻结 17 项（gacha v1.1 §3.1）= m4 §3 表 17 项，逐一对应（§3 本评核对）。
- `IAudioService` / `AudioService` 已全实现：≤24 语音池、SoundBank 可选、AudioMixer 可选路由、PlaceholderAudioProvider 回退、ADR-3 不订阅 EventBus、EffectiveVolume 独立于 reduce_motion。
- 路由一致性：m4 §4 路由表 == `AudioService.DefaultCategory` 映射（§3 本评核对，100% 一致）。
- 四项待决已裁定（§2）。

### 1.2 CONCERNS / 实跑待补项（详细见 §5）

| ID | 待补项 | 严重度 | 责任 | 依据 |
|---|---|---|---|---|
| T1 | 终稿 WAV 落 `unity/My project/Assets/Audio/Gacha/`（15 终稿 + BGM；Screen_Close 待 P2） | P1 | 作曲/音效师 → 工程 | m4 §6.2 step1 |
| T2 | SoundBank ScriptableObject 创建 + 绑定各 SoundId → AudioClip[]/Category/Volume/变体权重 | P1 | engineering-lead | m4 §6.2 step2 |
| T3 | AudioMixer 6 组 + Snapshot ducking（rolling -3 / SSR climax -8 / pity -4 / insufficient -2） | P1 | engineering-lead | m4 §4 / §6.2 step3 |
| T4 | Rolling 修正 A 代码落地（StopLoop 移至首张 Flip_Start 后） | P1 | engineering-lead | 裁定① / §6.3 |
| T5 | Gacha_Screen_Close 调用点补（裁定③延后 P2） | P2 | engineering-lead | 裁定③ / R3 |
| T6 | A/B/C 分层 stems 微动态（裁定②延后） | P2 | 作曲/音频 | 裁定② / §1.2 |
| T7 | UR 音频（前向兼容，无需求） | P3 | — | R4 |

---

## 2. 四项待决裁定确认（主理人默认裁定采纳）

| # | 待决项 | 裁定 | 依据 | 关联 |
|---|---|---|---|---|
| ① | Rolling 修正方案 | **A**（StopLoop 移至首张 `Card_Flip_Start` 后） | 改动最小、零新增资产、贴合「滚动→翻面」演出直觉；`IAudioService` 接口零改，仅 eng 调 `OnPull`/`RevealSequencer` 时序 | m4 §6.3；B 归档备选 |
| ② | BGM 终稿层级 | **单条 ambient loop 先验收**，A/B/C 分层 stems 微动态延后 | MVP 务实，避免过早分层资产投入；单条即可验证「待机↔抽卡」切换与 ducking 框架 | m4 §1.2（文档保留） |
| ③ | `Gacha_Screen_Close` | **延后到 P2**（当前控制器未调用） | 非抽卡核心验收项；枚举/占位/分类齐备，避免为单条 cue 增改控制器时序 | R3 / §3 |
| ④ | 中间件 | **维持 Unity AudioMixer（MVP 不上 FMOD）** | 无 adaptive music 刚需；Snapshot ducking 可由 AudioMixer 实现；FMOD 仅后期评估 | M3 §4.6 |

> 上述裁定已同步写入 `m4-audio-spec.md` §8.2（状态行由「待确认」改为「已裁定」），文档头部状态行亦同步更新。

---

## 3. 17 SoundId 终稿规格可审批闭环核对

对照 `gacha-audio-spec` v1.1 §3.1 枚举（契约真源）与 `AudioService.DefaultCategory` 路由。

| # | SoundId | §3 终稿规格 | 枚举(gacha v1.1) | AudioService 路由 | 闭环判定 | 备注 |
|---|---|---|---|---|---|---|
| 1 | `Gacha_SinglePull_Click` | ✓ | ✓ | UI | 闭环 | — |
| 2 | `Gacha_TenPull_Click` | ✓ | ✓ | UI | 闭环 | — |
| 3 | `Gacha_Pool_Select` | ✓ | ✓ | UI | 闭环 | — |
| 4 | `Gacha_Card_Flip_Start` | ✓ | ✓ | SFX | 闭环 | — |
| 5 | `Gacha_Rolling` | ✓ | ✓ | Ambient | 闭环 | Rolling 修正 A 待 T4 落地（当前灰盒近不可闻） |
| 6 | `Gacha_Reveal_Swap` | ✓ | ✓ | SFX | 闭环 | 青碧 `#4FA39B` 基础层 |
| 7 | `Gacha_Reveal_N` | ✓ | ✓ | SFX | 闭环 | — |
| 8 | `Gacha_Reveal_R` | ✓ | ✓ | SFX | 闭环 | — |
| 9 | `Gacha_Reveal_SR` | ✓ | ✓ | SFX | 闭环 | 鎏金 `#CBA75C` |
| 10 | `Gacha_Reveal_SSR` | ✓ | ✓ | SFX | 闭环 | — |
| 11 | `Gacha_Reveal_SSR_Climax` | ✓ | ✓ | SFX | 闭环 | stereo；紫宸 `#8B6DB3` 高潮 |
| 12 | `Gacha_Pity_Near` | ✓ | ✓ | SFX | 闭环 | — |
| 13 | `Gacha_Pity_Triggered` | ✓ | ✓ | SFX | 闭环 | — |
| 14 | `Gacha_Insufficient` | ✓ | ✓ | UI | 闭环 | — |
| 15 | `Bond_Prologue_Open` | ✓ | ✓ | VO | 闭环 | P2 钩子 |
| 16 | `Gacha_Screen_Close` | ✓(—) | ✓ | UI | 闭环(延后 P2) | 裁定③；控制器未调用 |
| 17 | `Gacha_Reveal_UR` | 保留槽位 | ✓ | SFX(default) | 闭环(不触发) | 前向兼容 |

**结论**：17/17 SoundId 枚举齐备、路由一致、终稿资产规格完整 → **可审批闭环**。其中 #16 按裁定③延后 P2（仍保留枚举/占位/分类），#17 为前向兼容槽位（MVP 不触发），均非规格缺口。

---

## 4. AudioService 接口契约对齐（代码层已落）

- **≤24 语音池**：`_poolSize = 24`，`AcquireSource` 池满抢占索引最小者 — 对齐 §3.7。✓
- **SoundBank 可选**：`ResolveClip` 优先取 `_bank`，否则 `_placeholder.GetClip` 回退。✓
- **AudioMixer 可选路由**：`ResolveGroup` 按 `cat.ToString()` 匹配组；`_mixer==null` 则 `outputAudioMixerGroup=null`（默认组播放，ducking 不生效 — 见 T3）。✓（契约支持，待 T3 资产）
- **ADR-3 红线**：`AudioService` 仅订阅 `IAudioSettings.Changed`，**不订阅任何 EventBus 事件**；reveal 由 `RevealSequencer` 驱动。✓
- **EffectiveVolume 独立于 reduce_motion**：不读 `MotionScale`，仅受 静音/分类音量/主音量 影响。✓（对齐 §4.3）
- **静音/音量经 `IAudioSettings`**（`SfxEnabled`/`MusicEnabled`/`MasterVolume`）接通。✓

---

## 5. 实跑待补项清单（用户本回合不跑 Unity）

> 以下为「规格已定、代码/资产待执行」，非规格缺陷。须在 engineering + QA 阶段闭环。

- **T1 终稿 WAV 落盘**：按 §2 命名/格式落 `unity/My project/Assets/Audio/Gacha/`。缺失则运行时仍走 Placeholder 合成音（能听时序、非终稿听感）。
- **T2 SoundBank 创建**：逐 SoundId 绑 `AudioClip[]`(变体) + `AudioCategory` + `Volume`(0–1) + 权重；挂 `AudioService._bank`。业务代码零改。
- **T3 AudioMixer + Snapshot ducking**：建 6 组（Master/Music/Ambient/SFX/UI/VO）、相对音量/限幅；Snapshot 实现 rolling -3dB / SSR climax -8dB / pity -4dB / insufficient -2dB。未建时 ducking 不生效（静音门控仍生效）。
- **T4 Rolling 修正 A**：eng 将 `StopLoop(Gacha_Rolling)` 移至首张 `Gacha_Card_Flip_Start` 后；否则灰盒/终稿蓄力层近不可闻。
- **T5 / T6 / T7**：见 §1.2 表（P2/P3）。

---

## 6. 风险收口状态

- **R1（Rolling 不可闻）**：原 design note A/B → 裁定① 采 A；待 T4 落地。**状态：规格闭合，执行待补**。
- **R2（架构以真实实现为准）**：已闭合（§5.2 ADR-3 真实架构）。**状态：闭合**。
- **R3（Screen_Close 未接线）**：裁定③ 延后 P2。**状态：规格闭合（P2 跟踪）**。
- **R4（UR 保留槽位）**：MVP 无 UR，不触发。**状态：闭合（前向兼容）**。

---

## 7. QA 验收清单（m4 §7）复核

| 项 | 静态可确认 | 实跑待验证 | 说明 |
|---|---|---|---|
| 时序对齐（t 锚点） | ✓（spec/RevealSchedule 冻结） | 待 T1/T2 | — |
| 十连错峰 ≤4–6 并发 | ✓（sequencer 驱动） | 待 T1/T2 | — |
| 稀有度可辨（闭眼） | — | 待 T1 听感 | — |
| 图层叠加正确 | ✓（spec 设计） | 待 T1/T2 | — |
| reduce_motion 不门控音频 | ✓（代码 EffectiveVolume） | — | 已实 |
| ducking 生效 | — | 待 T3 | 未建 mixer 前不生效 |
| 静音/音量开关独立 | ✓（代码 EffectiveVolume/IAudioSettings） | — | 已实 |
| 预算 ≤24 / <5MB / <2MB | ✓（池=24） | 待 T1 量内存 | 内存待 WAV 实跑 |
| Screen_Close 状态 | ✓（裁定③ P2） | — | — |

---

## 8. Handoff 摘要

- → **team-lead / engineering-lead（程基岩）**：M4 规格 PASS 可收口；执行待补 T1–T4（P1）须排期：SoundBank + AudioMixer + 终稿 WAV 落盘 + Rolling 修正 A 代码落地；业务代码零改（仅资产/配置 + `OnPull` 时序）。
- → **art-director（林绘澄）**：音频 cue 与 art §8 t 锚点一致，已闭环；无新增美术依赖。
- → **design-strategist（文策渊）**：UX 演出点已全覆盖；reveal 由 sequencer 驱动（非事件直驱），口径维持。
- → **作曲 / 音效师**：依 §3 17 项资产规格 + §2 格式交付终稿 WAV（T1）。

【一句话总结】M4 抽卡音频规格**质量门 PASS（规格层闭环）**：方向已定、17 SoundId 终稿全规格可审批、AudioService 接口契约 100% 对齐、四项待决已由主理人默认裁定闭合（A / 单条 / P2 / Unity AudioMixer）；**CONCERNS 级实跑待补 7 项**（终稿 WAV / SoundBank / AudioMixer+Snapshot ducking / Rolling 修正 A 为主要 P1），因用户本回合不跑 Unity 列为执行跟踪，非规格缺陷。
