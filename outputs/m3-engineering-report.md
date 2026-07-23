# M3 工程实现报告 — UGUI 抽卡屏 MVP 切片（Phase 5 制作）

- **负责人**：程基岩（engineering-lead / 主程序）
- **阶段**：M3「抽卡表现与 UI」· Phase 5 落地制作
- **引擎**：团结引擎 1.9.3（Unity 2022 LTS 兼容）/ UGUI / 目标平台 Android（IL2CPP）
- **代码落点**：`src/unity/Features/`（真源），镜像 `unity/My project/Assets/Scripts/Features/`
- **范围**：UGUI 抽卡屏 MVP 切片（灰盒占位资源 + 程序化占位音频），M2 接口缺口 H1–H4，H5 裁定，红线自检，测试与风险。

> 说明：本阶段**不修改任何 M2 `.cs` 的行为/语义**，仅在接口/契约上追加方法与文件；所有新增 UI/音频代码均为 M3 新建。Core 不反向依赖 Features（ADR-3 红线 #3）。

---

## 0. 结论速览

| 项 | 状态 | 备注 |
| --- | --- | --- |
| 交付物 A：可运行 UGUI 抽卡屏 MVP 切片 | ✅ 已落地（灰盒） | 六态机 + reveal sequencer + 音频服务 + 程序化占位音频 |
| 交付物 B：M2 缺口 H1–H4 | ✅ 已补全 | 接口追加，不改既有语义 |
| H5 异步 Pull | 🟢 裁定：**不需要** | `Pull` 已同步返回有序 `IReadOnlyList<GachaResult>` |
| 交付物 C：CLAUDE.md 引擎声明同步 | ✅ 已改 | 团结引擎 1.9.3 / UGUI / Android IL2CPP |
| 交付物 D：本报告 | ✅ 本文件 | — |
| Unity 本地编译 / EditMode 测试 | ⏳ 待主理人本地验证 | 沙箱无 Unity / `dotnet`，无法执行 |
| 运行时接线（Bootstrapper / 场景 prefab） | ✅ 代码已补（待本机挂接/编译） | Bootstrapper.cs + AccessibilitySettings.cs 已落地（R1/R4 收口）；剩余 AudioMixer 创建与场景挂组件为 Unity 编辑器动作 |

---

## 1. 实现清单（交付物 A）

### 1.1 抽卡屏核心（UGUI）
| 文件 | 职责 |
| --- | --- |
| `Gacha/UI/GachaScreenController.cs` | 中心控制器。六态状态机 `Idle / PoolSelected / Rolling / Reveal / ResultList / InsufficientCurrency`；`Initialize(ServiceRegistry, EventBus)` 仅经接口解析服务；`OnEnable` 订阅 `EconomyCurrencyChangedEvent` + `GachaShikigamiObtainedEvent`（仅轻量副作用）；`OnPull(count)` 预检可支付→进入 Rolling→调 `IGachaService.Pull`→`RevealSequence` 驱动逐卡错峰。 |
| `Gacha/UI/FlipController.cs` | scale-X 翻面（1→0.92→0→1，reveal 段 Back 缓动）。`BeginFlip(reduceMotion, onReveal)` / `ShowFront` / `ShowBack` / `ForceFront`（跳过路径）。`reduce_motion` 下走静态等价（不播协程，保持背面→正面定格）。 |
| `Gacha/UI/PityProgressBar.cs` | 保底进度条。`Bind(pity,soft,hard)` 委派 `PityModel.Compute`；`DetectCrossing(newPity)` 委派 `PityModel.DetectCrossing`。不跨池。 |
| `Gacha/UI/ResultCard.cs` | 单卡展示。rarity **三重冗余**（色框 + 边框 + 星 1/2/3）；`Setup(result, meta, stats, reduceMotion)`；SSR 全息 `PlaySsrHolo()`。 |
| `Gacha/UI/PullButton.cs` | 单抽/十连按钮 + 不足态。`Configure(label, canAfford, onClick)` / `SetDisabledInsufficient`（锁图标 + `interactable=false` + 置灰 `#8A9599`）。 |

### 1.2 音频系统（Audio）
| 文件 | 职责 |
| --- | --- |
| `Audio/IAudioService.cs` | 契约：`AudioCategory`(Master/Music/Ambient/SFX/UI/VO)；`Play/PlayLoop/StopLoop/StopCategory/SetMuted/SetCategoryVolume`。**不读** `reduce_motion`（audio §4.3）。 |
| `Audio/AudioService.cs` | MonoBehaviour，`RequireComponent(AudioSource)`。`Initialize(services,bus)` 注册 `IAudioService` 并订阅 `IAudioSettings.Changed`；AudioSource 对象池（≤24 声部）；`_active` 字典追踪 `(AudioSource→SoundId)`；`EffectiveVolume` = 分类门控(sfx/music) × master × mute（**不含** reduce_motion）；`PlaceholderAudioProvider` 回退。 |
| `Audio/SoundId.cs` | `SoundId` 枚举（Gacha_* + `Bond_Prologue_Open`）。`SoundIdExtensions.RevealTopLayerFor(Rarity)` → `Gacha_Reveal_N/R/SR/SSR/UR`（扩展方法，保规格命名）。 |
| `Audio/SoundBank.cs` | ScriptableObject，`[CreateAssetMenu]`。`Entry(Id, Category, Volume, Variants[])`；`Get(id)` / `PickVariant(id, salt)`。终稿音频资源就位后绑定 `AudioClip[]`，业务代码零改动（audio §5.2）。 |
| `Audio/PlaceholderAudioProvider.cs` | 程序化合成（`AudioClip.Create` + 包络/振荡）。零资源依赖，覆盖规格频率/时长/波形表。 |
| `Audio/AudioSettings.cs` | `IAudioSettings`：`SfxEnabled / MusicEnabled / MasterVolume(0..1)` + `event Changed`；`AudioSettings(PlayerProfile)` 持久化到 `PlayerProfile.Settings`（键 `audio_sfx_enabled` / `audio_music_enabled` / `audio_master_volume`，存档 schema v1，**不升版本**）。 |

### 1.3 纯逻辑辅助（可单测，无 Unity 依赖）
| 文件 | 职责 |
| --- | --- |
| `Gacha/RevealSchedule.cs` | `RevealTiming` 常量（CardStagger=0.08, FlipStartOffset=0, RevealSwapOffset=0.25, SsrClimaxExtra=0.20, NormalFlipDuration=0.5, SsrFlipDuration=0.70）；`RevealCue`(CardIndex, Rarity, AppearTime, RevealTime, SsrClimaxTime)；`Build(results)` 生成错峰队列；`TotalDuration(cues)`。 |
| `Gacha/PityModel.cs` | `View`(FillRatio, CountText, SubText, SoftActive, NearHard)；`Compute(pity,soft,hard)` 实现 UX §4 公式 + 三级副文案；纯 `Crossing` 枚举 + `DetectCrossing(prev,new,soft,hard)`（Soft/Hard/None），供跨阈值音频判定。 |

### 1.4 测试（EditMode / 纯逻辑）
| 文件 | 覆盖 |
| --- | --- |
| `Gacha.Tests/RevealAndPityTests.cs` | RevealSchedule 错峰/SSR-climax/总时长；PityModel 公式/边界/跨越检测。 |
| `Gacha.Tests/GachaTests.cs` | 既有测试 + `FakeEconomyService` 补齐 `GetBalance`（接口合规）。 |
| `Audio/Tests/AudioTests.cs` | `RevealTopLayerFor` 映射；`AudioSettings` 持久化与 `Changed` 广播；`PlaceholderAudioProvider` 生成 clip。 |

### 1.5 asmdef（编译隔离）
- `Features.Gacha.UI.asmdef`（ref：Core, Shared, Gacha, Economy, Audio）
- `Features.Audio.asmdef`（ref：Core, Shared）
- `Features.Audio.Tests.asmdef`（Editor-only，ref：Core, Shared, Audio）
- 其余沿用 M2 既有 asmdef；主 asmdef `includePlatforms:[]`，测试 asmdef `includePlatforms:[Editor]` + `precompiledReferences:[nunit.framework.dll]`。

---

## 2. M2 接口缺口补全（H1–H4）

> 仅**追加**方法/接口/文件，不改变 `Pull()`、`Spend()` 等既有语义。

### H1 — `GetPityThresholds(poolId) → (soft, hard)`
- **接口**：`IGachaService.cs:26` 新增 `(int soft, int hard) GetPityThresholds(string poolId);`
- **实现**：`GachaManager.cs:57` 读池配置 `SoftPity / HardPity` 返回。进度条刻度（50/90）与「软保底生效」判断用，**UI 不写死阈值**。

### H2 — `GetPoolList()` + `GetPullCost(poolId, count)`
- **接口**：`IGachaService.cs:29` `IReadOnlyList<PoolMeta> GetPoolList();`；`IGachaService.cs:33` `int GetPullCost(string poolId, int count);`
- **实现**：`GachaManager.cs:65` `GetPoolList` 构建 `PoolMeta`（DisplayName 首字母大写回退，GachaPool 暂无 `name` 字段）；`GachaManager.cs:89` `GetPullCost` 从 `GachaProgress.PullsDone` 模拟本次 count 抽（新手池前 20 抽偶数位 0 符箓），供 UI 在 `Pull` 前做可支付预检（UX §3.1/§3.2）。**未改**私有 `PullCost`/`Pull`。

### H3 — `IShikigamiCatalog.GetMeta(id)`
- **接口（新建）**：`Shared/IShikigamiCatalog.cs` → `ShikigamiMeta GetMeta(id)`（`DisplayName / PortraitKey / Element / BondId`）；`(int atk, int hp) GetCombatStats(id)`。`BondId` 取首个 `bond_tag`。
- **实现（新建）**：`Shared/ShikigamiCatalog.cs` 经 `ConfigLoader` 读 `data/shikigami/shikigami_defs.json`；`SetDefsForTest` 支持 headless 注入；未知 id 走空 meta 回退。
- **缺口（数据模型）**：`ShikigamiDef` 暂无 `name` 字段 → `DisplayName` 回退到 id；无 `bondId` 字段 → `BondId` 取首个 `bond_tag`。后续可在 JSON 增补。

### H4 — `IEconomyService.Spend` 触发 `CurrencyChangedEvent` + UI 接线
- **现状确认**：`EconomyManager.cs:57` `Spend` 成功扣减后已 `Publish(EconomyCurrencyChangedEvent)`（H4 在 M2 已满足）。
- **配套追加**：`IEconomyService.cs` 新增 `int GetBalance(string currency);`；`EconomyManager.cs:35` 实现（读 `PlayerProfile.Currencies`，默认 0）。用途：UI `OnEnable` 初始化 `CurrencyLabel` 与符箓不足预检（红线 #2：余额单一真源 = `PlayerProfile.Currencies`）。`GachaScreenController` 订阅 `EconomyCurrencyChangedEvent` → 刷新 `CurrencyLabel`，自动进入/退出 `InsufficientCurrency` 态。

---

## 3. H5 异步 Pull 裁定：**不需要补**

- **依据**：`IGachaService.Pull` 已声明为 `IReadOnlyList<GachaResult> Pull(string poolId, int count = 1)`（`IGachaService.cs:13`），**同步**返回**有序**结果列表。一次十连的 10 个结果顺序即展示顺序。
- **工作流**：`GachaScreenController.OnPull` → 调 `Pull` 拿到列表 → `RevealSchedule.Build(results)` 生成逐卡错峰队列（0.08s/张）→ `RevealSequence` 在同一时间轴驱动 VFX + 音频（art §8 t 锚点：t=0 翻面起 / t=0.25 揭示换面 / t=0.25+0.2 SSR climax）。
- **红线满足**：音频**绝不**随原始事件瞬时齐发（audio §3.4），而是对齐定格揭示时刻；`reduce_motion` 仅压视觉，音频 cue 保持（audio §4.3）。
- **结论**：无需引入 `Task`/`async`/协程式 Pull 异步接口；同步 + 本地 sequencer 已完整覆盖。若后续要做「服务端权威抽卡 / 网络延迟」，再评估 H5，但那属于网络层而非本切片。

---

## 4. Unity 编译 / EditMode 测试说明

### 4.1 沙箱限制（重要）
- 本环境**无 Unity Editor、无 `dotnet`**（已验证 `dotnet: command not found`），**无法**在沙箱内执行编译或 EditMode 测试。所有代码以人工静态审查 + 接口一致性校验为准；**最终编译/测试由主理人在本地团结引擎工程执行**。

### 4.2 已就绪的验证资产
- 纯逻辑测试（无 Unity 依赖，最易本地跑）：`RevealAndPityTests.cs`、`AudioTests.cs`（AudioSettings 持久化 / SoundId 映射 / Placeholder clip）。
- `FakeEconomyService` 测试桩已补齐 `GetBalance`，保证 `IEconomyService` 接口改动后既有 `GachaTests` 仍可编译。

### 4.3 主理人本地验证步骤（建议）
1. 打开 `unity/My project/`（团结引擎 1.9.3），确认 `Assets/Scripts/Features/` 已与 `src/unity/Features/` 同步（本报告完成时已全量一致）。
2. 进入 **EditMode 测试**：`Window → General → Test Runner → EditMode`，跑 `Features.Gacha.Tests` 与 `Features.Audio.Tests`。
3. 编译检查：确认各 asmdef 引用闭合（新增 UI/音频 asmdef 不反向引用 Core 之外未声明模块）。
4. 运行时接线（见 §6 缺口）：建/补 `Bootstrapper`，注册 `ShikigamiCatalog` / `AudioSettings` / `AudioService.Initialize`，并在场景 `OnEnable` 调 `GachaScreenController.Initialize(services, bus)`。
5. 美术终稿就位前，用灰盒占位 prefab + `PlaceholderAudioProvider` 跑通六态机与 reveal sequencer。

---

## 5. 下一步（美术 / 音频终稿接入）

1. **美术终稿替换灰盒**：`ResultCard` 的 `imgFrameN/R/SR/SSR`、`imgCardBack`、`rawPortrait`、`matRiseGlow`、`matSSRRainbow` 等字段绑定正式贴图/材质；`PityProgressBar` 的 `mark50/mark90` 刻度图；`PullButton` 的正常/置灰态。rarity 三重冗余（色+框+星）保留为无障碍基线。
2. **音频终稿**：在 `SoundBank` ScriptableObject 中按 `SoundId` 绑定正式 `AudioClip[]`（含变体）；创建 Unity **AudioMixer**（5 组 Master/Music/Ambient/SFX/UI/VO）并挂到 `AudioService`。绑定后业务代码零改动（audio §5.2）。
3. **设置面板**：复用 `AudioSettings`（sfx_enabled / music_enabled / master_volume）接 UI 开关；变更经 `Changed` 事件广播，`AudioService` 自动响应。
4. **无障碍**：本地实现 `AccessibilitySettings` C# 单例后，把 `GachaScreenController._reduceMotion` 由「序列化默认值」改为读该单例 / `IAudioSettings` 的 `reduce_motion`（视觉压制动画，音频保持）。
5. **CanvasScaler**：场景根 Canvas 设 `1080×2340`、`Match=Height`（主理人裁决 #6），保证竖屏 Android 适配。

---

## 6. 已知风险与缺口

| # | 风险 / 缺口 | 影响 | 处置建议 |
| --- | --- | --- | --- |
| R1 | ~~运行时接线缺失~~ → **已补 `Bootstrapper.cs`**：场景 Awake 注册 EventBus/GameState/PlayerProfile/ServiceRegistry、IAudioSettings/IAccessibilitySettings、IShikigamiCatalog、IEconomyService/IGachaService，并调 `AudioService.Initialize` + `GachaScreenController.Initialize`。 | 切片现已可自启（代码层就绪）；**剩余** AudioMixer 资源创建、场景挂 Bootstrapper/GachaScreenController/AudioService 组件为 Unity 编辑器动作。 | 主理人本地：① 场景挂 Bootstrapper + 拖入 GachaScreenController/AudioService；② 建 AudioMixer（5 组）挂 AudioService；③ 编译 + 跑 EditMode 测试。本环境无法代跑。 |
| R2 | **数据模型缺口**：`GachaPool` 无 `name`、`ShikigamiDef` 无 `name`/`bondId` 字段。 | `GetPoolList` 的 DisplayName 回退到 id；`GetMeta` 的 BondId 取首个 bond_tag。 | 在 `data/gacha/gacha_pools.json` / `shikigami_defs.json` 增补 `name`/`bondId`；契约已留扩展位，补字段零破坏。 |
| R3 | **沙箱无法编译/测试**：无 Unity/`dotnet`。 | 本环境只能静态审查，编译期/运行时错误需主理人本地兜底。 | 见 §4.3 验证步骤；优先跑纯逻辑测试（`RevealAndPityTests` / `AudioTests`）。 |
| R4 | ~~reduce_motion 取序列化默认值~~ → **已补 `AccessibilitySettings` 单例 + `IAccessibilitySettings`**：`Bootstrapper` 注册，`GachaScreenController.Initialize` 注入 `_reduceMotion` 并订阅 `Changed` 动态跟随。 | 无障碍开关（视觉压制）现已闭环；音频仍不读此开关（audio §4.3）。 | 无新增动作；本地设置面板可复用 `AccessibilitySettings.ReduceMotion`（存档 schema v1 键 `accessibility_reduce_motion`）。 |
| R5 | **AudioService 不订阅 EventBus**：reveal 音频由 sequencer 直接调 `IAudioService`（audio §3.4 红线）。 | 任何「事件→音频」需求须走 sequencer，不能新增 EventBus→Audio 直连。 | 已在 `AudioService` 注释标明；新增音频点统一经 sequencer。 |
| R6 | **AudioMixer 资源未建**：`ResolveGroup` 依赖 `AudioMixer.FindMatchingGroups`，终稿 Mixer 由主理人本地创建。 | 缺 Mixer 时音量分组回退静音，但占位音频仍可在默认组播放。 | §5-2 创建 Mixer 并挂载。 |
| R7 | **存档 schema**：`AudioSettings` 写入 `PlayerProfile.Settings` 三个键，未升 schema 版本（v1 冻结）。 | 旧档无 audio 键时取默认 true/1.0，向后兼容。 | 已确认不破坏 v1；若需显式版本，单独拍板。 |

---

## 7. 红线与约束自检（ADR-3 控制清单）

- **#1 跨系统只经 EventBus / ServiceRegistry**：`GachaScreenController` 仅经 `ServiceRegistry.Resolve<T>()` 取接口，经 `EventBus.Subscribe` 接 `currency_changed` / `shikigami_obtained`；**不持有**任何 `*Manager` 具体类字段。✅
- **#2 单一真源 / 不直连数据**：UI 不经 `PlayerProfile` 直读，余额走 `IEconomyService.GetBalance`，事件走 `EconomyCurrencyChangedEvent`。✅
- **#3 Core 不反向依赖 Features**：`Audio`/`Gacha.UI` asmdef 不反向 require Core 之外的上层；新增文件无 `using XiaXia.Features.Gacha` 误入 Core。✅（纯逻辑 `RevealSchedule`/`PityModel` 无 Unity 依赖，可独立单测。）
- **#4 不写死阈值/颜色**：保底阈值经 `GetPityThresholds` 读配置；rarity 色彩走 `ResultCard` 资源字段（终稿经 `UIThemeController` 等价物约束，Godot 侧规则不等价移植，待 UI 主题落地）。✅（结构合规；Unity 侧主题常量待建。）
- **#5 验证驱动**：先写测试（`RevealAndPityTests` / `AudioTests`）再实现；灰盒切片不阻塞逻辑层测试。✅
- **#6 不破坏 M2 语义**：仅追加接口/方法/文件，未改 `Pull()`、`Spend()` 既有逻辑与 `PullCost` 私有实现。✅

---

## 8. 待主理人审批 / 执行项

1. 本地打开团结引擎工程，**编译 + 跑 EditMode 测试**（§4.3）。
2. （代码已补）本地场景挂 `Bootstrapper` 并拖入 `GachaScreenController` / `AudioService`，建 **AudioMixer**（5 组 Master/Music/Ambient/SFX/UI/VO）挂 `AudioService`（R6）。
3. 确认 `CLAUDE.md` 引擎声明（已改：团结引擎 1.9.3 / UGUI / Android IL2CPP）符合预期。
4. 美术/音频终稿接入时按 §5 绑定资源，业务代码零改动。
5. 高影响动作（提交 / 删除 / 上线）按惯例由人工审批；截至本收口，M3 代码已落盘但尚未 commit（待主理人批准）。
