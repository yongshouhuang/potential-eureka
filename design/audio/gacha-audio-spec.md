# 仙侠卡牌项目 · 抽卡音频规格（Gacha Audio Spec · M3 切片）

> 范围：**M3 抽卡表现与 UI 切片**（单抽/十连按钮 + 出货结果展示 + 基础卡牌翻面动画 + 保底进度条）。
> 引擎/平台：**团结引擎 1.9.3（UGUI，Unity 技术栈）**、目标平台 **Android（IL2CPP）**。
> 音频中间件（MVP 默认）：**Unity 内置 Audio + AudioMixer 总线**（不引入 FMOD/Wwise，见 §4.6）。
> 编写：audio-director（阮和鸣）。　评审：solo / lean。
> 状态：规格 **v1.1（已定稿 · 与 art §8 双向对齐）**（采纳 art-gacha-spec 视觉-音频同步时间轴，见 §0.5）；**不写代码、不产具体音频文件、不改动 M2 任何 .cs**。

---

## 0. 范围、基线与红线

### 0.1 本文档交付物
1. 抽卡场景**音频方向**（情绪 / 调色板 / 动态层级）。
2. **音频事件清单（MVP）**：逐条触发点、时机、音色方向、优先级、SoundId、接入方式。
3. **实现接口建议**：`AudioService` 契约、`SoundId` 枚举建议、EventBus 接线、关键时序警告、混音总线、性能预算。
4. **可访问性**处理（静音开关 / 三重冗余 / reduce_motion 与音频）。
5. **资产占位策略**：MVP 占位音 → 终稿替换路径。

### 0.2 对齐基线
- `design/ux/ux-spec.md` §2.2（抽卡屏：单抽/十连 CTA、卡牌翻面·灵光升腾、SSR 紫宸虹光、羁绊序章、货币消耗、`gacha:shikigami_obtained` 演出点）。
- `art/art-bible.md`：锚点 4 紫宸虹光、§2 色彩系统、§8 可访问性（三重冗余）、情绪关键词「空灵·清冷·古韵·仙气·缥缈」。
- `art/gacha-ui-asset-spec.md` §8（**视觉-音频同步时间轴**，v1.1 已采纳，见 §0.5）。
- M2 已实现：`EventBus`（类型化 `Publish<T>/Subscribe<T>`，见 `src/unity/Core/EventBus.cs`）、`GachaShikigamiObtainedEvent`（`ShikigamiId / Rarity / PoolId`，见 `src/unity/Features/Shared/Events/GachaEvents.cs`）、`IGachaService.Pull(poolId, count)`（`GachaManager` 同步循环发布事件）。
- 稀有度枚举（M2 `Rarity`）：`N=0 / R=1 / SR=2 / SSR=3`（art-bible 另列「UR 道尊（可选）」但**当前枚举未含 UR**，音频留前向兼容槽位，见 §3 备注）。

### 0.3 解耦红线（沿用架构 ADR-3）
- 音频层**不得 import `GachaManager`/任何 manager**（与 UX 反馈层同约束）：只经 `EventBus` 订阅事件，或经 UI 调用点直接调用 `AudioService`。
- 音频层读写设置只经**设置单例**（见 §5），不直连各管理器字段。

### 0.4 与 CLAUDE.md 的口径差异（需主理人知悉）
- `CLAUDE.md` 仍写「Godot 4.3 / GDScript」；但本任务明确为**团结引擎 1.9.3 / UGUI / Android IL2CPP**，且代码已迁移至 `src/unity/` 与 `unity/My project/Assets/Scripts/`（存在 `production/unity-migration/` 迁移计划）。
- 本文档**按任务口径对齐团结引擎/UGUI/Android**，接口契约以 C# 风格给出（与 `src/unity` 一致）。建议同步更新 `CLAUDE.md` 引擎声明，避免后续规格歧义。

### 0.5 修订记录（v1 → v1.1，采纳 art-gacha-spec 同步时间轴）
- 采纳 `art/gacha-ui-asset-spec.md` §8 的**单卡翻面时间轴**（`t=0.00` 起手 whoosh / `t=0.25` 揭示换面+灵光升腾 / SSR `t=0.25+0.2s` 紫宸虹光峰值），将其固化为音频 cue 的硬同步锚点（§2、§8.2）。
- 新增两条音效：**`Gacha_Card_Flip_Start`**（t=0.00 起手 whoosh）、**`Gacha_Reveal_Swap`**（t=0.25 揭示换面基础层：whoosh + 青碧灵光升腾 chime，所有稀有度共通）。
- **修正 §4.3（重要）**：原 v1 草拟「reduce_motion 下缩短/跳过 SSR 长高潮」——经 art 确认**错误**。audio 与 VFX 订阅同一 reveal 时间轴，但 **reduce_motion 只压缩视觉时长、不门控音频**：视觉瞬判定格时，音频 cue 仍对齐「定格揭示」时刻（普通 t=0.25 / SSR 峰值），**不延迟、不缩短**。音频的「关」由独立静音开关控制（§4.1），与 reduce_motion 解耦。
- 十连为**错峰波浪（间隔 0.08s）**，音频用轻度随机化（变体/音高/声像）避免齐奏轰头（§2 备注、§3.7）。

### 0.6 定稿确认（v1.1，与 art §8 双向对齐）
- art-gacha-spec（林绘澄）确认：v1.1 的 **reveal sequencer 解读正确**——`gacha:shikigami_obtained` 为单一起点/数据源，sequencer 消费 `Pull` 结果排出错峰时间轴（0.08s/张），**音频与 VFX 都订阅该 sequencer 时间轴**（非各自订阅原始事件），保证帧对齐且十连 burst 被 sequencer 吸收。
- 已据确认嵌入两点精确口径：① **t 锚点为每张卡相对时刻**，climax 按每卡槽位触发（非全局单次，见 §2 备注、§3.3）；② **reduce_motion 不门控音频**的契约依据补充引用 accessibility-spec **Standard I**（§4.3）。
- 结论：`design/audio/gacha-audio-spec.md` v1.1 与 `art/gacha-ui-asset-spec.md` §8 双向对齐，**可定稿**。后续若美术调整翻面时长（如普通 0.5s / SSR 0.7s），art 将同步更新 §8 锚点并知会音频侧重对齐 t 值。

---

## 1. 音频方向（Audio Direction）

### 1.1 场景情绪定位
抽卡屏是「仪式感 + 期待 + 递进惊喜」的核心情绪场。音频基调须与 art-bible 一致——**清冷古韵、仙气缥缈**，而非「炫酷电子奇幻」。整体走「御剑修真·问道长生」的东方仙侠声景：

- **基调音色**（建议乐器/合成层）：古琴泛音、编钟/磬、玉磬、笛/箫、铃、极少量空灵 pad。避免强电子 bass、失真吉他、808 鼓。
- **情绪曲线**：静谧仪式感（待机/选池）→ 蓄力张力（rolling）→ 逐张轻揭（翻面）→ 稀有度递进悦动（R/SR）→ 紫宸高潮（SSR 虹光）→ 余韵（展示/羁绊序章钩子）。
- **节奏**：偏慢、留白；用 silence 与泛音营造「空灵」，不堆砌。

### 1.2 稀有度递进「取悦梯度」（核心设计）
出货音效按稀有度分 4 档（N/R/SR/SSR），音色由「素朴」向「华贵·神性」递进，让玩家**听感即可分辨稀有度**，与视觉三重冗余（颜色+边框纹理+角星）形成听觉维度的第四冗余：

| 稀有度 | 听感关键词 | 音色方向 | 动态层级 |
|---|---|---|---|
| N 凡品 | 素朴、轻 | 木鱼轻叩 / 单弦轻拨（短促、无余韵） | 最薄，仅作「揭示」确认 |
| R 灵品 | 清越、玉 | 玉磬清响 + 一点上行滑音 | 轻，单声清越 |
| SR 宝品 | 暖、华、亮 | 鎏金编钟 + 暖铃齐鸣 + 短促上行琶音 | 中，明亮和鸣 |
| SSR 仙品 | 神性、恢宏、虹光 | 钟磬大和鸣 + 上行泛音 sweep + 空灵 pad 铺陈 + 一声清越长鸣（**高潮 cue**） | 满，独立 climax bed |

> 设计原则：相邻稀有度**音色与音高都拉开差**，使闭眼也能分辨 SR vs R vs SSR；SSR 必须形成「仪式高潮」，与锚点 4 紫宸虹光视觉峰值同步（见 §2、§8.2 同步点）。

### 1.3 与 art-bible 锚点 4（紫宸虹光）的情绪对齐 + 色彩配器隐喻
- 锚点 4 情绪词：**尊贵、珍稀、神话**。SSR 出货音频高潮 cue 须同时承载这三感：
  - **尊贵** → 编钟/磬的低频体量与金属泛音；
  - **珍稀** → 清越铃与上行琶音的「难得」感；
  - **神话/神性** → 空灵 pad + 长鸣 + 一点不真实的泛音（非自然乐器，暗示「仙」）。
- **色彩→配器隐喻**（与视觉峰值情绪一致，art §8 提示）：把稀有度/灵光色直接映射为音频配器色彩——
  - **青碧 `#4FA39B`** = 灵光升腾 chime 层（清冷仙气，所有稀有度揭示换面共通基础层，见 `Gacha_Reveal_Swap`）；
  - **紫宸 `#8B6DB3`** = SSR 专属和弦（尊贵神话，climax 主体）；
  - **鎏金 `#CBA75C`** = SR/SSR 点缀（暖铃、上行琶音的金光感）。
- 音频**峰值须对齐视觉光扫峰值**（§8.2 同步表）：光扫到最亮、边框虹光最盛的帧 = 紫宸和弦 + 长鸣起音的那一拍。

### 1.4 动态层级（Bus / Mix 情绪分层）
抽卡屏音频分三层，便于「蓄力→揭示」平滑过渡：

1. **Ambient（待机/仪式基底）**：极简古琴泛音 + pad 循环，低音量常驻，营造仙山静谧。
2. **Rolling（蓄力层）**：抽卡时叠加一层渐强的「灵气汇聚」纹理（铃/泛音抖动/低频微涌），随蓄力时长增厚；揭示时迅速退场。
3. **Reveal / Climax（揭示层）**：逐张翻面起手+揭示换面+稀有度 sting + SSR 高潮 bed，置于 SFX 高优总线。

### 1.5 BGM 建议（MVP 占位）
- MVP 抽卡屏用**一条占位 ambient loop**（合成的极简泛音 + pad，约 30–60s 无缝循环），验证「待机/抽卡」切换即可。
- 终稿：可做的「微动态」——待机一段、抽卡蓄力时叠一层（同一主题变体），避免两套曲。交互式/分层音乐（adaptive music）若后期需要再评估 FMOD（见 §4.6），MVP 不强制。

---

## 2. 音频事件清单（MVP）

> 表头：触发点 / 时机 / 音色方向 / 优先级 / SoundId（建议） / 接入方式。
> 优先级：**P0**=必做（MVP 验收）、**P1**=强推荐、**P2**=锦上添花。
> 接入方式缩写：`UI`=UI 调用点直接调 `AudioService.Play`；`TL`=揭示时间轴驱动（reveal sequencer，见 §3.3–3.4）。
> **时间轴基准**（采纳 art §8，MVP 参考分辨率下）：单卡翻面 `t=0.00` 起手 → `t=0.25` 揭示换面（★核心锚点）→ 普通 `t=0.25→0.5` 灵光上涌余韵；SSR `t=0.25+0.2s` 紫宸虹光 bloom+光扫峰值。

| # | 触发点 | 时机 | 音色方向 | 优先级 | SoundId（建议） | 接入方式 |
|---|---|---|---|---|---|---|
| 1 | 单抽按钮点击 | 点击「单抽」瞬间（调用 `IGachaService.Pull` 之前/同时） | 玉磬轻击 + 一点「落子」质感（确认+仪式感） | P0 | `Gacha_SinglePull_Click` | UI |
| 2 | 十连按钮点击 | 点击「十连」瞬间 | 同单抽但更饱满（双磬/和鸣），暗示「批量」 | P0 | `Gacha_TenPull_Click` | UI |
| 3 | 卡池选择切换 | 切换常驻/新手池时 | 极轻的玉磬移位（非揭示音），避免与出货混淆 | P1 | `Gacha_Pool_Select` | UI |
| 4 | 抽卡蓄力 / rolling | 进入 rolling 状态起，至首张翻面前；循环 | 渐强「灵气汇聚」：铃+泛音抖动+低频微涌，随蓄力增厚 | P0 | `Gacha_Rolling`（loop） | UI（start/stop loop） |
| 5 | 卡牌翻面·起手（逐张） | 每张卡翻面 tween 起手 **t=0.00**（卡背下沉） | 轻 whoosh（仅确认翻面起手，不随稀有度变化） | P0 | `Gacha_Card_Flip_Start` | TL（每张 t=0.00） |
| 5b | 卡牌翻面·揭示换面（基础层，逐张） | 每张卡 **t=0.25** ★ 卡背→卡面换面 + 灵光升腾启动 | 「揭示」whoosh + 灵光升腾 chime（**青碧 `#4FA39B`**，所有稀有度共通基础层） | P0 | `Gacha_Reveal_Swap` | TL（每张 t=0.25） |
| 6 | 出货揭示 · N | t=0.25 **叠于 #5b 之上** | 素朴木鱼轻叩/单弦轻拨，短、无余韵 | P0 | `Gacha_Reveal_N` | TL（按 rarity 选，叠于 Swap） |
| 7 | 出货揭示 · R | 同上 | 玉磬清响 + 上行滑音 | P0 | `Gacha_Reveal_R` | TL（按 rarity 选） |
| 8 | 出货揭示 · SR | 同上 | 鎏金编钟 + 暖铃 + 短上行琶音（鎏金 `#CBA75C` 点缀） | P0 | `Gacha_Reveal_SR` | TL（按 rarity 选） |
| 9 | 出货揭示 · SSR（紫宸虹光高潮） | t=0.25 换面 + **t=0.25+0.2s 紫宸虹光 bloom/光扫峰值** | #5b 基础层 + SSR 专属 grand sting（紫宸 `#8B6DB3` 和弦 + 鎏金 `#CBA75C` 点缀，锚点4 峰值，约 1.5–2.5s） | P0 | `Gacha_Reveal_SSR` + `Gacha_Reveal_SSR_Climax` | TL（换面 t=0.25 + climax 于 +0.2s 峰值） |
| 10 | 符箓不足（禁用/失败反馈） | 余额不足仍点抽卡 / Pull 提前中断 | 低频闷响 + 木鱼顿挫（失败感、不带刺耳高频），对应朱砂警示色 | P0 | `Gacha_Insufficient` | UI（affordability 预检失败） |
| 11 | 保底临近提示（软 50） | 保底进度条跨过软保底（50 抽）阈值时 | 轻「保底临近」tick（渐强铃/心跳式预示） | P1 | `Gacha_Pity_Near` | UI（进度条更新跨阈值） |
| 12 | 保底触发提示（硬 90） | 跨过硬保底（90 抽）当次出货 | 「保底触发」确认 cue（释然的清越一声） | P1 | `Gacha_Pity_Triggered` | TL/UI（出货时 pity==硬保底） |
| 13 | 羁绊序章开启（钩子） | 出货后弹「羁绊序章」时 | MVP 仅留**占位钩子**（一句极简引子音，如远钟）；终稿由叙事/VO 定 | P2 | `Bond_Prologue_Open`（预留，非 MVP 必做） | UI |
| 14 | 抽卡屏关闭 / 返回 | 退出抽卡屏 | 极轻收束（泛音渐隐） | P2 | `Gacha_Screen_Close` | UI |

**备注**
- **图层关系**：每张卡揭示 = `Gacha_Card_Flip_Start`（t=0）→ `Gacha_Reveal_Swap`（t=0.25 青碧基础层，所有稀有度共通）→ 叠加 `Gacha_Reveal_{N/R/SR/SSR}`（稀有度顶层）；SSR 额外在 t=0.25+0.2s 触发 `Gacha_Reveal_SSR_Climax`。
- **十连错峰波浪**：十连为相邻卡间隔 **0.08s** 的错峰波浪，每张按上述 t 锚点各自错峰（即第 k 张整体偏移 `k×0.08s`）。音频用**轻度随机化**（变体选取 + 轻微音高/声像抖动）避免齐奏轰头（§3.7）。
- **t 锚点为「每张卡相对时刻」**（art §8 确认）：`t=0.25` / `t=0.25+0.2s` 是**单张卡**的相对时刻；第 N 张实际触发 = `0.08×N + 锚点`。因此 `Gacha_Reveal_SSR_Climax` 按**每张 SSR 卡的 sequencer 槽位**触发（十连中多张 SSR 先后响，非全局同一刻）。建模须按「每卡槽位」而非「全局单次」。
- UR 道尊：art-bible 列为「可选」，M2 枚举未含。`SoundId` 预留 `Gacha_Reveal_UR`（前向兼容槽位），MVP 不触发。若后续加 UR，音频做「超越 SSR」的更高潮（如多层钟磬+人声吟咏）。
- 单抽 vs 十连 reveal 编排：单抽直接进入 #5→#5b→#6~9（SSR 含 climax）；十连逐张波浪（每张 #5+#5b+#6~9），末张（最高稀有度）或 SSR 张触发 climax。

---

## 3. 实现接口建议（Engineering-Lead 接口契约）

> 本节为**契约/伪代码**（非实现代码），供 engineering-lead 落地。新增文件，不改动任何 M2 `.cs`。

### 3.1 `SoundId` 枚举建议（契约）
```csharp
// 契约枚举（建议命名空间 XiaXia.Features.Audio），新增文件，不改 M2。
public enum SoundId
{
    // —— 抽卡 UI ——
    Gacha_SinglePull_Click,
    Gacha_TenPull_Click,
    Gacha_Pool_Select,
    Gacha_Card_Flip_Start,    // t=0.00 翻面起手 whoosh（新增，v1.1）
    Gacha_Rolling,            // loop
    Gacha_Insufficient,
    Gacha_Pity_Near,
    Gacha_Pity_Triggered,
    Gacha_Screen_Close,
    Bond_Prologue_Open,       // 占位钩子（P2）

    // —— 出货揭示（稀有度递进）——
    Gacha_Reveal_Swap,        // t=0.25 揭示换面基础层：whoosh+青碧灵光升腾 chime（所有稀有度共通，v1.1 新增）
    Gacha_Reveal_N,
    Gacha_Reveal_R,
    Gacha_Reveal_SR,
    Gacha_Reveal_SSR,
    Gacha_Reveal_SSR_Climax,  // SSR 高潮 bed（t=0.25+0.2s 紫宸虹光峰值，独立较长 cue）
    Gacha_Reveal_UR,          // 前向兼容槽位（MVP 不触发）
}

// 稀有度 → 揭示顶层 SoundId 映射辅助（契约建议）。
// 注意：播放揭示时，除本层外，另需播放基础层 Gacha_Reveal_Swap（见 §2 图层关系 / §3.3）。
public static SoundId RevealTopLayerFor(Rarity r) => r switch
{
    Rarity.N   => SoundId.Gacha_Reveal_N,
    Rarity.R   => SoundId.Gacha_Reveal_R,
    Rarity.SR  => SoundId.Gacha_Reveal_SR,
    Rarity.SSR => SoundId.Gacha_Reveal_SSR,
    _          => SoundId.Gacha_Reveal_UR,
};
```

### 3.2 `AudioService` 方法契约（建议单例，经 `ServiceRegistry` 解析，与 `IGachaService` 同模式）
```csharp
public interface IAudioService
{
    void Play(SoundId id, float volumeScale = 1f);          // 一次性
    void PlayLoop(SoundId id);                              // 开始循环（rolling）
    void StopLoop(SoundId id);                              // 停止循环
    void StopCategory(AudioCategory cat);                  // 停止某类（如切屏清场）
    void SetMuted(bool muted);                             // 静音开关（§4.1，独立于 reduce_motion）
    void SetCategoryVolume(AudioCategory cat, float v);    // 分类音量
}

// 总线分类（对齐 AudioMixer Group）
public enum AudioCategory { Master, Music, Ambient, SFX, UI, VO }
```
> 注意：`AudioService` **不读取 `MotionScale`/`reduce_motion` 来决定是否播放或缩短 cue**（见 §4.3）。音频门控仅由静音开关/分类音量控制。

### 3.3 EventBus 接线原则（reveal sequencer 模式）
- **UI 按钮 / 卡池选择 / 屏关闭 / 符箓不足**：UI 调用点直接 `audio.Play(...)`（`UI` 接入）。这些是无时序争议的瞬时反馈。
- **rolling loop**：UI 在进入 rolling 状态时 `audio.PlayLoop(Gacha_Rolling)`，揭示开始时 `audio.StopLoop(Gacha_Rolling)`。
- **出货揭示（含 SSR climax）— reveal sequencer 驱动**：
  - 演出以 `gacha:shikigami_obtained`（C# `GachaShikigamiObtainedEvent`，含 `Rarity`）为**起点**；一个 **reveal sequencer** 消费 `IGachaService.Pull` 返回的 `IReadOnlyList<GachaResult>`（含每卡 `Rarity`），按 §2 的 t 锚点构建**逐卡错峰时间轴**（十连间隔 0.08s）。
  - **音频与 VFX 订阅同一 reveal 时间轴**：在每张卡调度到的时刻播放 `Gacha_Card_Flip_Start`(t=0) → `Gacha_Reveal_Swap`(t=0.25) → `RevealTopLayerFor(rarity)`(t=0.25，叠于 Swap) → SSR 额外 `Gacha_Reveal_SSR_Climax`(t=0.25+0.2s)。（上述 t 为**每张卡相对时刻**；第 N 张整体偏移 `0.08×N`，故多张 SSR 各自按槽位先后触发，非全局齐发——与 art §8 口径一致。）
  - 即：事件只作**起点/数据来源**，不直接触发音频；音频由 sequencer 在其调度的时刻触发，保证与视觉逐卡对齐。
- **保底提示**：UI 更新保底进度条时检测阈值跨越 → `audio.Play(Gacha_Pity_Near/Triggered)`。

### 3.4 ⚠ 关键时序警告：十连 burst 风险（务必处理）
- **事实**：M2 `GachaManager.Pull()` 是**同步循环**——十连时 10 个 `GachaShikigamiObtainedEvent` 在 `Pull()` 返回前**连续瞬间全部发布**（见 `GachaManager.cs:86-121`），而翻面动画是之后 UI 才逐张播放的。
- **反模式**：若音频层**直接订阅 `GachaShikigamiObtainedEvent` 并立即播放揭示音**，十连会**同时炸出 10 声揭示音**，与视觉完全错位，且触发移动端 polyphony 尖峰。
- **正确做法（采纳 art §8 reveal 时间轴）**：
  1. 事件仅作**起点/数据源**；由 **reveal sequencer** 把 10 张排成**错峰波浪（0.08s/张）**时间轴（§3.3）；
  2. 音频与 VFX **订阅同一 sequencer 时间轴**，在每张卡调度到的 t 锚点（#5/#5b/#6~9）触发，绝不随原始事件瞬时齐发；
  3. `GachaShikigamiObtainedEvent` 仍保留**广播语义**（图鉴点亮、遥测），音频层**可选**订阅它做非时序关键的轻提示，**绝不**用它直接播逐张 reveal。
- 结论：出货 cue 的「数据来源」是 `Pull()` 返回的 `GachaResult.Rarity`；「播放时机」由 **reveal sequencer 错峰时间轴**控制。原始事件仅作广播，不控制 reveal 时序。

### 3.5 符箓不足接入（与 UX 卡点 #1 对齐）
- UI 在调用 `IGachaService.Pull` **之前**做 affordability 预检（经 `IEconomyService` 余额，或 `GachaManager.PullCost` 等价判断）。
- 不足 → 播放 `Gacha_Insufficient` + 展示「去推图产出符箓」CTA（ux-spec §4 卡点 #1）。`Pull()` 本身也会在不足时提前 `break` 返回更少结果，UI 可双保险检测 `results.Count < requested`。

### 3.6 混音总线（AudioMixer Group 结构，MVP）
```
Master
 ├─ Music      (BGM ambient loop, 低音量常驻)
 ├─ Ambient    (抽卡仪式基底 / rolling 层)
 ├─ SFX        (出货揭示 / 翻面 / 保底 —— 高优先级虚拟化)
 ├─ UI         (按钮点击 / 屏关闭 —— 中优先级)
 └─ VO         (羁绊序章占位 / 后续叙事 —— P2)
```
- 路由：所有 `Gacha_*` 经 `SFX`/`UI`；`Gacha_Rolling`/`Ambient` 经 `Ambient`；音乐经 `Music`。
- 静音开关作用于 `Master`（或分别 `SFX`/`Music`），见 §4.1（**与 reduce_motion 无关**）。

### 3.7 性能预算（Android IL2CPP 目标）
- **最大同时 SFX 语音数**：≤ 24（移动端保守值）。
- **rolling loop**：占 1 语音。
- **十连逐张 reveal（错峰波浪）**：间隔 0.08s，单帧并发 reveal 语音 ≤ 4–6（绝不 10 同发）；单卡揭示 = `Flip_Start`+`Reveal_Swap`+顶层 共约 2–3 语音，错峰后峰值可控。
- **SSR climax**：climax bed 视为 1–2 语音（允许短暂占优）。
- **十连齐奏规避**：每个揭示 cue 用 2–3 个变体 + **轻度随机音高/声像**（±几个半音、轻微 pan）抖动，避免波浪连播时的「机械齐奏轰头」；随机种子可固定以便 QA 复现。
- **内存**：MVP 占位音极小（合成/短样）；终稿目标——抽卡 SFX 包 < 5MB，单条音乐 loop < 2MB；采样率 44.1k、单声道优先（移动端）。
- **AudioSource 池化**：建议 `AudioService` 内部维护 `AudioSource` 对象池（避免逐发 new），池大小 ≈ 最大语音数。MVP 占位阶段即可落地池，省后续重构。
- **距离衰减/空间化**：抽卡屏为 UI 2D 屏，**不使用 3D 空间化**（worldPos 恒 UI 中心），统一 2D 立体声；预留 `worldPos` 参数供战斗屏后续复用。

---

## 4. 可访问性（Accessibility）

### 4.1 静音开关（独立于 reduce_motion）
- 现有 `AccessibilitySettings` 单例（Godot 侧）持有 `high_contrast/reduce_motion/text_scale/color_blind_mode/cvd_filter/performance_mode/dynamic_text`，但**未含音频开关**。
- **建议**：在设置单例（或新增 `AudioSettings` peer）增补 `sfx_enabled / music_enabled / master_volume(0–1)` 字段，变更经同一 `accessibility_changed` 风格信号广播；`AudioService` 订阅之并调 `SetMuted/SetCategoryVolume`。
- 静音开关**必须**同时静音 SFX 与 Music（或分开关），默认开启声音；设置落点对齐 `GameState.settings`（与 `01-architecture.md §1.7` 存档 schema 一致，建议 schema v1 增补音频字段，属主理人待定项）。
- **音频的「开/关/长短」只由静音开关与分类音量决定，不由 `reduce_motion` 决定**（见 §4.3）。

### 4.2 三重冗余：关键反馈不纯靠声音
- 对齐 UX 规格 §2.2 与 accessibility-spec 原则——**任何关键反馈都有视觉等价**：
  - SSR 出货：紫宸虹光边框 + 动态光扫 + 角星 3（视觉）**先于/独立于**音频；即使静音，玩家仍明确「出货 SSR」。
  - 符箓不足：朱砂警示色 + 置灰按钮 + 「去推图产出符箓」CTA 文案（视觉/文字）独立于 `Gacha_Insufficient` 音。
  - 保底临近/触发：进度条数字（tabular）+ 颜色/图标变化独立于提示音。
- 音频是**增强层**，不是**唯一信息通道**。音频设计不承载「必须听到才知结果」的信息。

### 4.3 reduce_motion 与音频的耦合（v1.1 修正）
> ⚠ **重要修正（采纳 art §8）**：v1 草拟的「reduce_motion 下缩短/跳过 SSR 长高潮」**已撤销**。

- **原则**：`reduce_motion` 只**压缩视觉时长**，**不门控音频**。音频与 VFX 订阅同一 reveal 时间轴，但 reduce_motion 仅让视觉走「瞬判定格」路径；音频 cue **仍对齐「定格揭示」时刻**（普通 t=0.25 / SSR 峰值点），**不延迟、不缩短**。
  - 即：SSR 长 climax bed（1.5–2.5s）在 reduce_motion 下**仍完整播放**——视觉可能是静态等效（边框/角星/数字），但音频照常给高潮反馈。
  - 翻面起手/揭示换面/稀有度 sting 照常播放（属状态变化反馈，且不被 reduce_motion 门控）。
- **音频的「关」由独立静音开关控制**（§4.1），与 reduce_motion **解耦**：要静音就静音开关，要减动效就减动效，两者互不影响。
- **实现约束**：`AudioService.Play` **不读取 `MotionScale`/`reduce_motion`** 来决定播放与否或时长；音频只受静音开关/分类音量影响。reveal sequencer 在 reduce_motion 下把视觉时长压到 0，但**仍在该（压缩后的）揭示时刻触发音频**（即视觉定格那帧 = 音频 t=0.25/SSR 峰值）。
- 该处理同时对齐 accessibility 「状态变化保留静态等效」精神：视觉给静态等效，音频给完整反馈，信息不丢。

### 4.4 音频可视化（Comprehensive N，仅留接口）
- accessibility-spec 列「关键音频提示提供可视化等价（屏幕边脉冲/图标闪烁/律动条）」为 Comprehensive（MVP 不铺）。
- 本规格仅要求：SSR 揭示、保底触发等**已有视觉等价**（见 §4.2），无需额外音频可视化；接口上为「关键 cue 可挂可视化事件」留扩展点（如 `AudioService` 播高潮时可选 emit `audio:climax` 供 UI 脉冲），MVP 不实现。

---

## 5. 资产占位策略（MVP → 终稿替换路径）

### 5.1 MVP：用占位音，先打通事件触发
- **不产终稿音频文件**。MVP 用以下两种占位之一，使工程能在无终稿时联调事件触发与 UI 时序：
  1. **程序化合成 blip（推荐）**：`AudioService` 配 `PlaceholderAudioProvider`，按 `SoundId` 用 `AudioClip.Create` 生成极短合成音（不同频率/包络区分稀有度与图层），零外部资产、可立即运行与 QA；
  2. **现成库占位**：临时拖入通用 UI/揭示音（注明 TEMP），后续替换。
- 占位音须**能听辨稀有度差异**与**图层差异**（`Flip_Start` 轻 whoosh / `Reveal_Swap` 青碧 chime / 稀有度顶层），以便 QA 验证「逐张错峰 + SSR 高潮 + 图层叠加」时序正确。

### 5.2 替换路径（终稿接入，不改代码）
- 引入 **`SoundBank` 数据资产**（团结引擎用 `ScriptableObject`），结构：`SoundId → AudioClip[]（含变体）+ 随机权重 + 分类(AudioCategory) + 音量`。
- 终稿音频文件落位：`unity/My project/Assets/Audio/Gacha/`（按 `SoundId` 命名，如 `gacha_reveal_ssr_climax.wav`）。
- 替换方式：美术/音频交付终稿后，**仅重填 `SoundBank`**（绑定终稿 clip），`AudioService` 按 `SoundBank` 解析播放——**业务代码零改动**。
- **变体（variants）**：每个揭示/点击 cue 建议 2–3 个变体随机取，避免重复机械感（尤其十连波浪连播，配合 §3.7 随机化）。

### 5.3 资产清单（待生产）
| SoundId | 终稿需求摘要 | 时长（估） | 变体 |
|---|---|---|---|
| `Gacha_SinglePull_Click` / `TenPull_Click` | 玉磬确认音（单/十差异） | 0.2–0.4s | 2 |
| `Gacha_Rolling` | 灵气汇聚 loop（可随蓄力增厚） | 循环 | 1（含层） |
| `Gacha_Card_Flip_Start` | 翻面起手轻 whoosh（t=0.00） | 0.1–0.2s | 2 |
| `Gacha_Reveal_Swap` | 揭示换面基础层：whoosh + 青碧 `#4FA39B` 灵光升腾 chime（所有稀有度共通，t=0.25） | 0.3–0.5s | 2 |
| `Gacha_Reveal_N/R/SR/SSR` | 稀有度递进揭示顶层 sting | 0.4–1.2s | 2–3 |
| `Gacha_Reveal_SSR_Climax` | 紫宸 `#8B6DB3` 虹光高潮 bed（t=0.25+0.2s 峰值，约 1.5–2.5s；reduce_motion 下仍完整播） | 1.5–2.5s | 1–2 |
| `Gacha_Insufficient` | 符箓不足闷响 | 0.3–0.5s | 1 |
| `Gacha_Pity_Near` / `Triggered` | 保底临近/触发提示 | 0.5–1.0s | 1–2 |
| BGM ambient loop | 抽卡仪式基底 | 30–60s 无缝 | 1 |

---

## 6. 与 M2 的兼容与红线确认

- ✅ 仅**新增**音频相关文件（`IAudioService`/`AudioService`/`SoundId`/`SoundBank`/`PlaceholderAudioProvider`），**不改动** `EventBus.cs` / `GachaEvents.cs` / `GachaManager.cs` / `IGachaService.cs` 等任何 M2 `.cs`。
- ✅ 音频层遵守 ADR-3：不 import 各 manager，只经 `EventBus` 订阅 + UI 调用点。
- ✅ 出货「数据来源」用 `IGachaService.Pull` 返回的 `GachaResult.Rarity`（M2 已提供），无需改动 GachaManager。
- ✅ `GachaShikigamiObtainedEvent` 原样复用（M2），仅作起点/广播语义；揭示时序由 **reveal sequencer 错峰时间轴**控制（见 §3.3–3.4）。
- ⚠ 需主理人裁决：是否将 `GachaShikigamiObtainedEvent` 的 C# 类型名与 Godot 侧 `gacha:shikigami_obtained` 字符串事件做**统一命名桥**（当前 M2 C# 用类型事件，UX 规格用 `gacha:` 前缀字符串；迁移期二者并存，建议以 C# 类型事件为真源，UX 文档同步更新命名以防歧义）。

---

## 7. 待主理人 / 团队确认项与风险

### 7.1 待确认（Decision Needed）
1. **引擎口径**：CLAUDE.md 写 Godot，本任务为团结引擎——是否同步更新 CLAUDE.md？（本文档按团结引擎/UGUI/Android 写。）
2. **音频中间件**：MVP 默认 Unity AudioMixer（无外部依赖）；是否同意？还是提前上 FMOD（adaptive 音乐）？（建议 MVP 不上，后期评估。）
3. **设置单例音频字段**：是否将 `sfx_enabled/music_enabled/master_volume` 增补进设置单例 + 存档 schema v1？（§4.1）
4. **事件命名桥**：`gacha:shikigami_obtained`（UX 文档）与 C# `GachaShikigamiObtainedEvent`（M2）是否统一？（§6）
5. **reveal sequencer 归属**：建议由 UI/演出层持有该 sequencer（驱动音频+VFX 同一时间轴），是否同意其置于 UGUI 抽卡屏控制器内？（§3.3）

### 7.2 风险
- **R1（高）**：十连 burst——若误解「监听事件直接播揭示音」会同时炸 10 声。已用 §3.4 + art §8 reveal 错峰时间轴（0.08s）明确规避；需 engineering-lead 落地时遵循。
- **R2（已消解）**：v1 草拟「reduce_motion 缩短 SSR 高潮」经 art 确认不成立，v1.1 已改为「reduce_motion 不门控音频」（§4.3）。
- **R3（低）**：移动端 polyphony/内存——已在 §3.7 给预算、池化与错峰+随机化建议。
- **R4（低）**：MVP 占位音若与终稿风格差太大，QA 仅验证「时序/触发/图层」不验证「听感」。终稿替换路径已隔离（§5.2）。

---

## 8. 交付摘要（分发给队友）

### 8.1 → design-strategist（文策渊）：UX 演出点覆盖确认
- 已覆盖 ux-spec §2.2 全部抽卡演出触发点：单抽/十连 CTA（#1/#2）、卡牌翻面（#5 起手 + #5b 揭示换面）、SSR 紫宸虹光（#9）、货币消耗（#10 符箓不足 + 预检）、保底进度条（#11/#12）、羁绊序章（#13 占位钩子）。
- **差异提示**：出货揭示音**不由事件直接驱动**（十连 burst 风险，§3.4），改由 **reveal sequencer 错峰时间轴**驱动（事件仅作起点/数据源）——请确认 UX 规格 §2.2「出货用 `gacha:shikigami_obtained`」的措辞是否需要补一句「事件作起点/数据广播，揭示音频与动画由 UI reveal 时间轴逐张错峰触发」，以免工程误读。
- 符箓不足反馈已与「卡点 #1 去推图产出符箓 CTA」对齐（音频仅作增强，视觉/文案为主）。

### 8.2 → art-director（林绘澄）：音频–视觉同步点（采纳 §8 时间轴）
| 视觉事件 | 音频 cue | 同步锚点（t） |
|---|---|---|
| 卡牌翻面起手（卡背下沉） | `Gacha_Card_Flip_Start`（轻 whoosh） | **t=0.00** |
| 揭示换面 + 灵光升腾启动（★核心） | `Gacha_Reveal_Swap`（whoosh + 青碧 `#4FA39B` 灵光升腾 chime，所有稀有度共通） | **t=0.25** |
| 稀有度揭示顶层（N/R/SR/SSR，叠于 Swap） | `Gacha_Reveal_{N/R/SR/SSR}` | **t=0.25**（叠于换面） |
| SSR 紫宸虹光 bloom + 光扫峰值（锚点4） | `Gacha_Reveal_SSR_Climax`（紫宸 `#8B6DB3` 和弦 + 鎏金 `#CBA75C` 点缀） | **t=0.25+0.2s**（光扫峰值 = 钟磬齐鸣峰值） |
| 灵光升腾 rolling 蓄力层增厚 | `Gacha_Rolling` loop 渐强 | 蓄力时长→音量/层数 |
| 保底进度条跨 50 / 90 | `Gacha_Pity_Near` / `Triggered` | 数字跨阈值帧 |
| 符箓不足（朱砂警示） | `Gacha_Insufficient`（低频闷响） | 按钮置灰+CTA 同帧 |

- ✅ 已实现你的建议：SSR 揭示动画与音频 climax **共用一条 reveal 时间轴**（sequencer 同时驱动音频+VFX），光扫峰值帧绑定 `Gacha_Reveal_SSR_Climax` 长鸣起音。
- ✅ **reduce_motion 修正**：采纳你的约定——reduce_motion 只压视觉时长，**不门控音频**；视觉瞬判定格时音频仍对齐 t=0.25 / SSR 峰值，不延迟不缩短（§4.3，已撤销 v1 草拟的紧凑版）。
- ✅ **十连错峰**：采纳 0.08s 波浪间隔 + 轻度随机化避免齐奏轰头（§2 备注、§3.7）。
- 色调隐喻已写入 §1.3：青碧=灵光升腾 chime 层、紫宸=SSR 和弦、鎏金=SR/SSR 点缀。

### 8.3 → engineering-lead（程基岩）：音频接口契约
- **新增接口**（不改 M2）：`IAudioService`/`AudioService`（§3.2，注意不读 MotionScale）、`SoundId` 枚举 + `RevealTopLayerFor(Rarity)`（§3.1，揭示需叠播 `Gacha_Reveal_Swap`）、`SoundBank`（§5.2）、`PlaceholderAudioProvider`（§5.1）。
- **reveal sequencer 模式**（§3.3）：事件作起点/数据源 → sequencer 排错峰时间轴（0.08s/张）→ 音频+VFX 订阅同一时间轴；`GachaShikigamiObtainedEvent` 仅广播。
- **必读警告**：§3.4 十连 burst——揭示音严禁随原始事件瞬时齐发，必须经 sequencer 错峰。
- **总线/性能**：AudioMixer 5 group（§3.6），≤24 语音 + 池化 + 错峰(0.08s) + 变体随机化（§3.7）。
- **可访问性接线**：静音开关独立于 reduce_motion（§4.1/§4.3）；音频不被 reduce_motion 门控。
- **占位策略**：MVP 用 `PlaceholderAudioProvider` 跑通，终稿仅改 `SoundBank`（§5）。

---

【一句话总结】本规格为 M3 抽卡切片定下「仙侠仪式感 + 稀有度递进取悦」音频方向，给出 14 条事件清单与 `AudioService`/`SoundId` 接口契约；**最关键结论**：出货揭示音因 M2 `Pull()` 同步 burst 风险，必须由 **reveal sequencer 错峰时间轴（0.08s/张，采纳 art §8）**驱动（事件仅作起点/广播），且 **reduce_motion 只压视觉、不门控音频**（v1.1 修正）；SSR 高潮 cue 峰值对齐锚点4 紫宸虹光光扫峰值，色彩→配器隐喻（青碧/紫宸/鎏金）贯穿稀有度梯度。
