# 仙侠卡牌项目 · 抽卡屏音频终稿规格（Gacha Audio Final Spec · M4）

> **M4 定位**：本文件是 **M3 音频规格**（`design/audio/gacha-audio-spec.md` v1.1 已定稿）的**终稿层**，不重议音频方向，只在已定方向 + 已定接口契约（`SoundId`/`IAudioService`/EventBus 红线）之上，产出**可交付作曲/音效师的终稿资产规格 + 混音终稿 + 集成步骤 + 验收清单**。
> 范围：抽卡屏（单抽/十连/选池/蓄力/翻面揭示/稀有度递进/SSR 紫宸高潮/保底/符箓不足/羁绊序章钩子）全部音频需求。
> 引擎/平台：团结引擎 1.9.3（UGUI）/ Android IL2CPP；中间件：Unity 内置 Audio + AudioMixer（MVP 不引入 FMOD，见 M3 §4.6）。
> 编写：audio-director（阮和鸣）。　状态：**M4 终稿规格 v1.0（收口终评 · 四项待决已裁定 · 17 SoundId 可审批闭环 · 质量门 PASS[集成待补] · 详见 m4-audio-closure.md）**。

---

## 0. 基线确认与"方向是否已定"结论

- ✅ **音频方向已存在且已定稿**：`design/audio/gacha-audio-spec.md` v1.1（仙侠仪式感 + 稀有度递进取悦，对齐 art §8 同步时间轴、art-bible 锚点4 紫宸虹光、色彩→配器隐喻：青碧 `#4FA39B`=灵光升腾 chime / 紫宸 `#8B6DB3`=SSR 和弦 / 鎏金 `#CBA75C`=SR/SSR 点缀）。**本 M4 不再重议方向，亦无需"⚠️ 需主理人确认音频方向"**。
- ✅ **`SoundId` 枚举已冻结**（17 项，见 §3 表），与 M3 §3.1 完全一致，代码 `src/unity/Features/Audio/SoundId.cs` 即真源。
- ✅ **接口契约已落地**：`IAudioService`/`AudioService`（含 ≤24 语音池、`PlaceholderAudioProvider` 回退、`SoundBank` 可选绑定、`AudioMixer` 可选路由）已实现；`RevealSchedule` 已固化 t 锚点。
- ✅ **红线（ADR-3）已遵守**：音频层不 import 任何 manager；UI 调用点 + RevealSequencer 直接调 `IAudioService`；`AudioService` **不订阅任何 EventBus 事件**（刻意规避十连 burst）。
- ✅ **两处偏差已闭合（doc-only，代码零改）**：① 架构以真实实现为基准——reveal 音频由 `RevealSequencer` 时间轴驱动、`AudioService` 仅提供播放接口（ADR-3 有意设计，非偏差），见 §5.2；② Rolling 蓄力层可听性修正作为设计 note 给出 A/B 方案，待 engineering-lead 实现（`IAudioService` 接口零改），见 §6.3。

### 已冻结 t 锚点（源自 `RevealSchedule.RevealTiming`，与 art §8 对齐）
| 常量 | 值 | 含义 |
|---|---|---|
| `CardStagger` | 0.08s | 十连相邻卡错峰间隔 |
| `FlipStartOffset` | 0.00s | 翻面起手 whoosh（`Gacha_Card_Flip_Start`）|
| `RevealSwapOffset` | 0.25s | 揭示换面 + 灵光升腾 chime（`Gacha_Reveal_Swap` + 稀有度顶层）|
| `SsrClimaxExtra` | +0.20s | SSR 紫宸虹光峰值（`Gacha_Reveal_SSR_Climax`）|
| `NormalFlipDuration` | 0.50s | 普通卡翻面时长 |
| `SsrFlipDuration` | 0.70s | SSR 翻面时长（含 0.2s 定格）|

> **关键约束（M3 §3.4 / §4.3 沿用）**：① t 锚点为**每张卡相对时刻**，第 k 张整体偏移 `k×0.08s`；SSR climax 按**每张 SSR 卡槽位**触发（非全局单次）。② **reduce_motion 只压视觉、不门控音频**——音频 cue 仍对齐定格揭示时刻，不延迟、不缩短。

---

## 1. 音乐基调（BGM）方向 · 终稿

抽卡屏 BGM 是「仙山问道的仪式基底」，须承载**待机静谧 → 蓄力张力 → 揭示/高潮让位**的情绪曲线，与 art-bible 一致（空灵·清冷·古韵·仙气·缥缈）。

### 1.1 主题与配器
- **调式**：五声（宫/羽）为基础，避免功能和声"西方奇幻感"；以**古琴散音+泛音**开篇，**空灵 pad** 撑底，**玉磬/铃**极少量点缀。
- **基底音色**：古琴泛音、玉磬、编钟（低频体量仅用于 SSR 高潮，不在 BGM 常驻）、极少量空灵 pad；**禁用**强电子 bass / 失真吉他 / 808 鼓。
- **节奏**：偏慢、留白；用 silence 与泛音营造"空灵"，不堆砌。

### 1.2 动态层次（微动态，MVP 不强制 adaptive）
| Layer | 状态 | 内容 | 与 SFX 关系 |
|---|---|---|---|
| A 待机 | 进入抽卡屏 | 古琴泛音 + pad，极简常驻 | BGM 基础音量 |
| B 蓄力 | rolling 期间 | 同主题变体：灵气汇聚纹理（铃/泛音抖动/低频微涌），随蓄力渐厚 | 叠于 A；**BGM ducking -3dB 让 B 透出** |
| C 揭示/高潮 | reveal 至 SSR climax | 音乐可短暂留白或仅低频托底，让 SFX 透出；SSR climax 时 **BGM ducking -8dB 完全让位** | SFX 主导 |

> **MVP 务实做法**：先用**单条 ambient loop**（30–60s 无缝）验证"待机↔抽卡"切换；终稿做**同主题分层 stems**（A/B/C 分轨），由 `AudioMixer` Snapshot 在 rolling/climax 切换做微动态 ducking。真正 adaptive music（交互式）若后期需要再评估 FMOD（M3 §4.6，MVP 不上）。

### 1.3 BGM 资产规格
- **文件**：`gacha_bgm_ambient.wav`（母带 48k/24bit stereo）→ Unity 打包 **Vorbis**（Android，较高码率档）。
- **时长/循环**：60s 无缝循环（或 30s + crossfade tail）；标注 loopStart/loopEnd，首尾零交叉对齐，避免 loop 接缝咔哒。
- **混音**：`Music` 总线，基础 ≈ **-20 LUFS / 线性 0.30**；ducking：rolling -3dB、SSR climax -8dB（由 mixer Snapshot 实现）。
- **内存预算**：单条 BGM loop < 2MB（Vorbis 压缩后）。

---

## 2. 格式与命名总规范

- **母带交付格式**：**WAV**（44.1k 或 48k、16/24bit）。**SFX 统一单声道（mono）** 以省内存、利于移动端；**仅 `Gacha_Reveal_SSR_Climax` 与 BGM 用立体声（stereo）**（需空间/混响铺陈）。
- **切忌 mp3**：Unity 移动端标准压缩为 **Vorbis（Ogg）**，mp3 在 Unity 有专利/导入怪癖，不采用。终稿 WAV 入引擎后由平台 override 压 Vorbis。
- **循环（loop）处理**：`Gacha_Rolling` / `gacha_bgm_ambient` 须提供**无缝循环**（首尾 crossfade 或零交叉对齐），并在资产标注 loop 区域。
- **文件命名**：`gacha_<soundid snake_case>.wav`，落位 `unity/My project/Assets/Audio/Gacha/`（与 M3 §5.2 一致）。
- **变体（variants）**：每个揭示/点击 cue 提供 2–3 个变体，由 `SoundBank` 随机取 + 轻度音高/声像抖动（±几个半音、轻微 pan），规避十连波浪齐奏轰头（M3 §3.7）。

---

## 3. 逐 SoundId 终稿资产规格表

> 列：类型/总线 · 风格描述 · 时长 · 格式/采样/声道 · 循环 · 文件命名 · 触发时机(t) · 混音(总线音量dB / 条目Volume / 优先级 / ducking) · 变体。
> 优先级=概念优先级（影响 ducking 与池抢占策略，非 Unity 原生字段）；总线音量指 AudioMixer 组相对电平，条目 Volume 指 `SoundBank` 内 0–1 基准。

| # | SoundId | 类型/总线 | 风格描述 | 时长 | 格式/采样/声道 | 循环 | 文件命名 | 触发时机(t) | 混音(总线dB / 条目Vol / 优先 / ducking) | 变体 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `Gacha_SinglePull_Click` | SFX/UI | 玉磬轻击 + "落子"质感（确认+仪式感） | 0.18–0.25s | WAV/44.1k/mono | 否 | `gacha_single_pull_click.wav` | 点击单抽瞬间（UI） | UI -12dB / 0.80 / 中 / 无 | 2 |
| 2 | `Gacha_TenPull_Click` | SFX/UI | 同单抽但更饱满（双磬/和鸣 + 低频体），暗示"批量" | 0.22–0.32s | WAV/44.1k/mono | 否 | `gacha_ten_pull_click.wav` | 点击十连瞬间（UI） | UI -12dB / 0.85 / 中 / 无 | 2 |
| 3 | `Gacha_Pool_Select` | SFX/UI | 极轻玉磬移位（非揭示音），避免与出货混淆 | 0.08–0.12s | WAV/44.1k/mono | 否 | `gacha_pool_select.wav` | 切换卡池（UI，line 226） | UI -16dB / 0.50 / 低 / 无 | 2 |
| 4 | `Gacha_Card_Flip_Start` | SFX/SFX | 轻 whoosh（风/织物/灵气拂过），**不随稀有度变化** | 0.12–0.18s | WAV/44.1k/mono | 否 | `gacha_card_flip_start.wav` | 每张 t=0.00（TL sequencer） | SFX -14dB / 0.55 / 高 / 无 | 2+随机音高/声像 |
| 5 | `Gacha_Rolling` | Ambient/Ambient | 渐强"灵气汇聚"：铃+泛音抖动+低频微涌（可叠层） | loop 2–4s | WAV/44.1k/**stereo** | **是** | `gacha_rolling.wav` | 进入 rolling 起（见 §6，需最小可听时长） | Ambient -18→-12dB 渐强 / 0.70 / 低 / 自身渐强、BGM -3dB | 1（含层） |
| 6 | `Gacha_Reveal_Swap` | SFX/SFX | 揭示换面 whoosh + **青碧 `#4FA39B` 灵光升腾 chime**（所有稀有度共通基础层） | 0.30–0.50s | WAV/44.1k/mono | 否 | `gacha_reveal_swap.wav` | 每张 t=0.25（叠稀有度顶层） | SFX -12dB / 0.70 / **最高(锚点)** / 无（它是 bed） | 2 |
| 7 | `Gacha_Reveal_N` | SFX/SFX | 素朴木鱼轻叩/单弦轻拨，短、无余韵 | 0.25–0.35s | WAV/44.1k/mono | 否 | `gacha_reveal_n.wav` | 每张 t=0.25（叠于 Swap） | SFX -14dB / 0.55 / 高 / 与 Swap 留 headroom | 2 |
| 8 | `Gacha_Reveal_R` | SFX/SFX | 玉磬清响 + 上行滑音（清越） | 0.30–0.40s | WAV/44.1k/mono | 否 | `gacha_reveal_r.wav` | 每张 t=0.25（叠于 Swap） | SFX -13dB / 0.65 / 高 / 与 Swap headroom | 2 |
| 9 | `Gacha_Reveal_SR` | SFX/SFX | **鎏金 `#CBA75C`** 编钟 + 暖铃 + 短上行琶音（暖亮华） | 0.40–0.60s | WAV/44.1k/mono | 否 | `gacha_reveal_sr.wav` | 每张 t=0.25（叠于 Swap） | SFX -12dB / 0.75 / 高 / 与 Swap headroom | 2–3 |
| 10 | `Gacha_Reveal_SSR` | SFX/SFX | 钟磬大和鸣 + 上行泛音 sweep（**紫宸 `#8B6DB3`** 和弦基底，不含长鸣） | 0.60–1.00s | WAV/44.1k/mono | 否 | `gacha_reveal_ssr.wav` | 每张 SSR t=0.25（叠于 Swap） | SFX -10dB / 0.85 / **最高** / BGM -5dB | 2–3 |
| 11 | `Gacha_Reveal_SSR_Climax` | SFX/SFX | **紫宸 `#8B6DB3`** 虹光高潮 bed：钟磬齐鸣峰值 + 鎏金 `#CBA75C` 点缀 + 空灵 pad 铺陈 + 清越长鸣 | 1.5–2.5s | WAV/48k/**stereo** | 否 | `gacha_reveal_ssr_climax.wav` | 每张 SSR t=0.25+0.2s（按卡槽位，非全局单次） | SFX -8dB / 0.90 / **最高(climax)** / BGM -8dB、rolling 停、与 Pity 不并发；reduce_motion 下仍完整 | 1–2 |
| 12 | `Gacha_Pity_Near` | SFX/UI | 渐强铃/心跳式预示（软保底临近 50） | 0.40–0.70s | WAV/44.1k/mono | 否 | `gacha_pity_near.wav` | 进度条跨软保底阈值（UI） | UI -14dB / 0.60 / 中 / 与 Swap 叠时留 headroom | 1–2 |
| 13 | `Gacha_Pity_Triggered` | SFX/SFX | 释然清越一声（硬保底确认 90） | 0.50–0.90s | WAV/44.1k/mono | 否 | `gacha_pity_triggered.wav` | 跨硬保底当次出货（UI/TL） | SFX -12dB / 0.75 / 高 / BGM -4dB | 1–2 |
| 14 | `Gacha_Insufficient` | SFX/UI | 低频闷响 + 木鱼顿挫（失败感，无刺耳高频；对应朱砂警示） | 0.30–0.45s | WAV/44.1k/mono | 否 | `gacha_insufficient.wav` | 余额不足/CTA 点击（UI，line 187/418） | UI -14dB / 0.70 / 中 / BGM -2dB | 1–2 |
| 15 | `Bond_Prologue_Open` | VO/VO | 极简引子音（远钟/一声明引）；终稿由叙事/VO 定 | 0.60–1.20s | WAV/44.1k/mono | 否 | `gacha_bond_prologue_open.wav` | 出货含 SSR 时（line 371，P2 钩子） | VO -14dB / 0.70 / 中 / BGM -3dB | 1 |
| — | `Gacha_Screen_Close` | SFX/UI | 极轻泛音渐隐（退屏收束） | 0.25s | WAV/44.1k/mono | 否 | `gacha_screen_close.wav` | 退出抽卡屏（**当前控制器未调用，P2**） | UI -18dB / 0.40 / 低 / 无 | 1 |
| — | `Gacha_Reveal_UR` | （保留槽位） | 前向兼容；不触发。若加 UR：超越 SSR 更高潮（多层钟磬+人声吟咏） | — | — | — | `gacha_reveal_ur.wav`（预留） | 不触发（MVP 无 UR） | — | — |

### 3.1 图层叠加关系（逐张卡）
```
t=0.00  Gacha_Card_Flip_Start                          (每张，轻 whoosh)
t=0.25  Gacha_Reveal_Swap  ┐ 基础层（青碧 chime，所有稀有度共通）
        + RevealTopLayerFor(rarity) ┘ 稀有度顶层 (N/R/SR/SSR)
t=0.25+0.2s  [仅 SSR] Gacha_Reveal_SSR_Climax         (紫宸虹光峰值 bed)
```
- 十连：第 k 张整体偏移 `k×0.08s`，上述 t 为单张相对时刻；SSR climax 按**每卡槽位**触发。
- SSR 实际 = `Swap` + `Gacha_Reveal_SSR` + `Gacha_Reveal_SSR_Climax` 三层。

---

## 4. 混音总线与 Ducking 终稿

```
Master
 ├─ Music    (BGM ambient loop；基础 -20LUFS/0.30)
 ├─ Ambient  (rolling 蓄力层；-18→-12dB 渐强)
 ├─ SFX      (出货揭示/翻面/保底/SSR climax —— 高优先虚拟化)
 ├─ UI       (按钮点击/选池/符箓不足/退屏 —— 中优先)
 └─ VO       (羁绊序章占位 —— P2)
```
- **路由**（沿用 `AudioService.DefaultCategory`）：`Gacha_Rolling`→Ambient；`Gacha_Pool_Select`/`SinglePull_Click`/`TenPull_Click`/`Insufficient`/`Screen_Close`→UI；`Bond_Prologue_Open`→VO；其余（Flip_Start/Reveal_*/Pity_*）→SFX。
- **Ducking 策略**（由 `AudioMixer` Snapshot / ExposedParam 实现，非代码 math）：
  - rolling 起 → Ambient 渐强、Music **-3dB**。
  - 任一张揭示起 → SFX 透出，Music 维持。
  - SSR climax 起 → **Music -8dB、Ambient rolling 停**、climax 占优；climax 结束回弹。
  - 保底触发（硬） → Music -4dB 短暂。
- **静音/音量门控**：由 `IAudioSettings`（SfxEnabled/MusicEnabled/MasterVolume，已接通）经 `AudioService.EffectiveVolume` 控制；**独立于 reduce_motion**（M3 §4.3）。如需 Snapshot 级 ducking，扩展 `AudioService` 在关键 cue 触发 mixer 参数即可，**业务代码零改动**。

---

## 5. 实现策略：EventBus → SoundId 映射 / AudioService 接入点（严守 ADR-3）

### 5.1 实际接线映射（与代码/M3 §3.3 一致）
| 事件/调用点 | 驱动方式 | 触发 SoundId | 备注 |
|---|---|---|---|
| UI 按钮（单/十连/选池/符箓不足/退屏） | **UI 调用点直接 `IAudioService.Play`** | `Single/TenPull_Click`·`Pool_Select`·`Insufficient`·`Screen_Close` | ADR-3 允许"UI 直接调音频服务" |
| rolling 起/止 | **UI 调用点 `PlayLoop`/`StopLoop`** | `Gacha_Rolling` | 注意 §6 可听性修正 |
| 出货揭示（含 SSR climax） | **RevealSequencer 直接 `Play`**（消费 `Pull` 结果，按 t 锚点错峰） | `Flip_Start`·`Reveal_Swap`·`Reveal_{N/R/SR/SSR}`·`SSR_Climax` | **不随原始事件齐发**（防 burst） |
| 保底跨阈值 | UI 检测 `PityBar.DetectCrossing` 后 `Play` | `Pity_Near`/`Triggered` | |
| 羁绊序章（SSR） | UI 在 `RevealSequence` 收尾 `Play` | `Bond_Prologue_Open` | P2 钩子 |
| `GachaShikigamiObtainedEvent` | **仅广播**（图鉴/遥测）；`AudioService` **不订阅**，控制器 `OnShikigamiObtained` 空 | — | 揭示时序归 sequencer，不归此事件 |
| `GachaAcquireIntentEvent` | UI 发布（去推图意图）；`Bootstrapper` stub **仅打日志** | — | **与音频播放无关**（导航占位） |

### 5.2 AudioService 接入点（ADR-3 红线自检）
- 控制器经 `ServiceRegistry.Resolve<IAudioService>()` 取得 `_audio`，只调 `Play / PlayLoop / StopLoop / StopCategory / SetMuted / SetCategoryVolume`。
- `AudioService.Initialize(services)`：注册 `IAudioService` + 订阅 `IAudioSettings.Changed`（静音/音量）；**不订阅任何 EventBus 事件**（设计红线，规避十连 burst）。
- 音频层不 import 任何 manager；只经 `ServiceRegistry` / `IAudioSettings` / `EventBus`（仅 Publish）。
- **架构真相（ADR-3 有意设计，非偏差）**：reveal 音频**由 `RevealSequencer` 按 t 锚点时间轴直接驱动 `IAudioService.Play`**，而非 `AudioService` 订阅任何 EventBus 事件——刻意规避十连 10 声齐发。完整链路：**UI 经 EventBus 发布意图（如 `GachaAcquireIntentEvent`）→ 控制器消费 `Pull` 结果 → `RevealSequencer` 错峰播放**；`AudioService` **仅提供播放接口（Play/PlayLoop/StopLoop…），订阅 0 个事件**。任务陈述中"音频由 AudioService 订阅事件播放"为旧表述，已废弃，以本实现为准（详见 §8 风险 R2，已闭合）。

---

## 6. 灰盒占位 → 终稿 过渡建议

### 6.1 当前（灰盒 M3）"占位"的真实含义
- **音频播放已全线接线**（`GachaScreenController` 内 `_audio?.Play/PlayLoop/StopLoop`），并非缺失；"占位"指 **`AudioService` 未绑 `SoundBank`/`AudioMixer` 时回退 `PlaceholderAudioProvider` 程序化合成**（不同频率/波形区分稀有度与图层）。即灰盒能听、能 QA 时序，只是合成音非终稿。
- **`Bootstrapper` 的 `GachaAcquireIntentEvent` stub 仅打日志** = 独立的"去推图导航"占位，**与音频播放无关**，不在此过渡范围（由导航层后续接管）。

### 6.2 真实终稿接入步骤（业务代码零改动，仅改资产/配置）
1. **交付终稿 WAV**：按 §3 命名/规格、§2 格式落到 `unity/My project/Assets/Audio/Gacha/`。
2. **建 SoundBank（ScriptableObject）**：逐 `SoundId` 绑定 `AudioClip[]`（变体）+ `AudioCategory` + `Volume`(0–1) + 权重；挂到 `AudioService._bank`。`ResolveClip` 即优先取 SoundBank，业务零改。
3. **建 AudioMixer**：6 组（Master/Music/Ambient/SFX/UI/VO），设相对音量/限幅/Snapshot(ducking)；挂到 `AudioService._mixer`，路由生效。
4. **精细 ducking**（可选扩展）：若需 climax 压 BGM，在 mixer 用 Snapshot/ExposedParam，由 `AudioService` 在关键 cue 触发——仍零业务代码改动（仅扩 AudioService）。
5. **QA 验收**（§7）。

### 6.3 Rolling 蓄力层可听性修正（design note · 待 engineering-lead 实现，AudioService 接口零改）
- **现状（实现）**：`GachaScreenController.OnPull` 中 `PlayLoop(Gacha_Rolling)` 后同步调用 `Pull()`，而 `Pull()` 同步微秒级返回后立即 `StopLoop`，导致蓄力层几乎不可闻，蓄力情绪缺失。
- **design note（二选一，推荐 A）**：
  - **A) 把 `StopLoop(Gacha_Rolling)` 移至首张 `Gacha_Card_Flip_Start` 触发之后**（即 reveal 序列首 action 完成后才停）——让滚动蓄力层完整播完再让位给揭示音。**推荐 A**：改动最小、零新增资产、且与"滚动→翻面"演出直觉一致。
  - **B) 加 loading breath 音层**：在 `PlayLoop` 与 `RevealSequence` 之间插入 0.6–1.2s 的蓄力呼吸/纹理音，再启动揭示；需新增一条短音频资产。
- 两项均**不改 `IAudioService` 接口、不改业务代码**，仅由 engineering-lead 调整 `OnPull`/`RevealSequencer` 时序。终稿 `Gacha_Rolling` 按 2–4s 无缝 loop 交付（§3 #5）。

---

## 7. 验收清单（QA · 终稿接入后）

- [ ] **时序对齐**：单卡 `Flip_Start`(t=0)→`Swap`+顶层(t=0.25)→SSR `Climax`(t=0.25+0.2s) 与美术光扫峰值帧对齐。
- [ ] **十连错峰**：相邻卡 0.08s 间隔，单帧并发 reveal 语音 ≤4–6（绝不 10 同发）；变体+随机音高/声像避免齐奏轰头。
- [ ] **稀有度可辨**：闭眼能分辨 N/R/SR/SSR（音色+音高均拉开）；`Swap` 青碧基础层所有卡共通。
- [ ] **图层叠加正确**：SSR = Swap + Reveal_SSR + Climax 三层；`Bond_Prologue_Open` 仅 SSR 触发。
- [ ] **reduce_motion 不门控音频**：视觉瞬判定格时，音频仍完整对齐 t 锚点，climax 不缩短（M3 §4.3）。
- [ ] **ducking 生效**：rolling Ambient 渐强 + Music -3dB；SSR climax Music -8dB、rolling 停。
- [ ] **静音/音量开关独立**：SFX/Music 静音与 reduce_motion 互不影响；设置落 `IAudioSettings`。
- [ ] **预算**：最大并发语音 ≤24；抽卡 SFX 包 <5MB、单条 BGM <2MB；移动端单声道优先。
- [ ] **`Gacha_Screen_Close` 状态**：当前未接线——确认补调用或降为后续里程碑（P2）。

---

## 8. 风险与待主理人确认

### 8.1 风险
- **R1（已闭合·doc-only）Rolling 不可闻**：成因详见 §6.3——`OnPull` 同步 `Pull()` 致 `StopLoop` 立即触发；设计 note 给出 **A（StopLoop 移至首张 `Card_Flip_Start` 后，推荐）/ B（loading breath 音层）** 两方案，待 engineering-lead 实现，`IAudioService` 接口零改。
- **R2（已闭合·doc-only）架构以真实实现为准**：任务旧陈述"音频由 AudioService 订阅事件播放"已废弃；真实架构为 **UI 经 EventBus 发意图 → `RevealSequencer` 按时间轴驱动 reveal 音频 → `AudioService` 仅提供播放接口且订阅 0 事件**（ADR-3 有意防 burst）。见 §5.2。
- **R3（低）`Gacha_Screen_Close` 未接线**：枚举/占位/分类齐备但控制器未调用，P2；待补或降里程碑。
- **R4（低）`Gacha_Reveal_UR` 保留槽位**：MVP 无 UR，不触发；若加 UR 音频做"超越 SSR"更高潮。

### 8.2 已裁定（主理人默认裁定采纳 · M4 收口终评）
> 主理人已按 audio-director 规格推荐给出**默认裁定**，四项待决全部闭合；详细依据与质量门判定见 `design/audio/m4-audio-closure.md`。

1. **Rolling 修正方案 = A（已裁定）**：`StopLoop(Gacha_Rolling)` 移至首张 `Gacha_Card_Flip_Start` 触发之后（reveal 序列首 action 完成才停）。**依据**：改动最小、零新增资产、与「滚动→翻面」演出直觉一致；`IAudioService` 接口零改，仅 engineering-lead 调整 `OnPull`/`RevealSequencer` 时序落地（§6.3）。B 方案（loading breath 音层）归档备选。
2. **BGM 终稿层级 = 单条 ambient loop 先验收（已裁定）**：M4 用单条 `gacha_bgm_ambient.wav` 无缝循环验收「待机↔抽卡」切换；A/B/C 分层 stems 微动态（§1.2 文档保留）延后至后续里程碑。**依据**：MVP 务实，避免过早投入分层资产；单条即可验证切换与 ducking 框架。
3. **`Gacha_Screen_Close` = 延后到 P2（已裁定）**：当前控制器未调用，且非抽卡核心验收项；枚举/占位/分类齐备，待 P2 补调用或并入屏管理。**依据**：不影响 M4 验收范围，避免为单条 cue 增改控制器时序。
4. **中间件 = 维持 Unity AudioMixer（已裁定，MVP 不上 FMOD）**：沿用 M3 §4.6。**依据**：MVP 无 adaptive music 刚需；Snapshot ducking 可由 AudioMixer 实现；FMOD 仅当后期确认交互式音乐再评估。

---

## 9. Handoff 摘要（分发）
- → **文策渊（design-strategist）**：UX 演出点已全覆盖；reveal 由 sequencer 驱动（非事件直驱），若 UX 文档仍写"出货用事件触发音频"请补一句"事件作起点/广播，揭示由 UI reveal 时间轴错峰触发"。
- → **林绘澄（art-director）**：音频 cue 严格对齐 art §8 t 锚点；SSR climax = 光扫峰值帧 = 紫宸和鸣起音；色彩→配器隐喻贯穿（青碧/紫宸/鎏金）。
- → **程基岩（engineering-lead）**：终稿仅改 `SoundBank`+`AudioMixer` 资产，业务代码零改；必读 §6.3 Rolling 修正、§5.2 ADR-3 红线；≤24 语音 + 池化 + 错峰 + 变体随机化。

【一句话总结】M4 在 M3 已定稿方向/契约上，产出抽卡屏**全 17 项 SoundId 终稿资产规格**（格式/时长/循环/命名/触发 t 锚点/混音 ducking）、BGM 微动态方向、EventBus→SoundId 实际接线（严守 ADR-3 sequencer 驱动）、灰盒→终稿零代码改动集成步骤与 QA 验收；并**闭合两处偏差（doc-only，代码零改）**：Rolling 因同步 `Pull` 几乎不可闻已转为 §6.3 设计 note（A/B 方案待 eng 实现、接口零改）、"任务事件订阅播放"旧陈述已废弃并改为 §5.2 ADR-3 真实架构（sequencer 时间轴驱动、`AudioService` 仅提供播放接口）。
