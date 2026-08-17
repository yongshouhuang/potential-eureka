# M4 抽卡 UI/音频 7 项 engineering 钩子落地说明（E1–E6 + T4）

**Task**：ENG-M4-IMPL-001（High）　**切片**：M4 抽卡 UI 美术/音频终稿接入 · 7 项 eng 钩子
**执行**：engineering-lead（程基岩）　**引擎**：团结引擎 1.9.3 / UGUI / C#（Android IL2CPP）
**状态**：代码逻辑已落 `src/unity`（权威）并镜像 `unity/My project/Assets/Scripts/`；**未 git commit**（主理人统一提交）；**未实跑 Unity 编译**（本环境无 Unity，仅静态自检）。

---

## 0. 总览（落地 7/7）

| ID | 优先级 | 落点文件 | 改动性质 | 资产接入状态 |
|---|---|---|---|---|
| E1 | High | `PullButton.cs` + `GachaScreenController.cs` | 新增 `PityArmed` 态 + `SetPityArmed(bool)` + 调用点 | 空引用 + TODO(art) |
| E2 | Medium | `PityProgressBar.cs` | 新增 `OnMilestonePulse` 脉冲回调/事件 + 调用点 | 空方法体，待 VFX |
| E3 | Low | `PityProgressBar.cs`（注释） | **不新增字段**，注释声明「复用现有 `_imgFill`」 | 无代码改动 |
| E4 | Medium | `GachaScreenController.cs` | 新增 `_iconImage` 字段 + `SetIcon(Sprite)` | 空引用 + TODO(art) |
| E5 | Medium | `PullButton.cs`（+ `PityProgressBar.cs` 头部） | 防御注释，无视觉逻辑改动 | 仅文档化 |
| E6 | Low | `PityProgressBar.cs` 头部 | 注释字段名对齐实际 | 仅整洁项 |
| T4 | High | `GachaScreenController.cs` | Rolling 修正 A：StopLoop 锚定首张 Flip_Start 后（注释标记） | 零接口改动 |

> 严守 ADR-3：UI 仅经 EventBus 发意图事件，音频由 `AudioService` 接口调用、reveal 由 `RevealSequencer` 时间轴驱动；本次未新增 UI 直接订阅音频/美术的行为，未改 `IAudioService` 接口。

---

## 1. 逐条改动明细

### E1 — PullButton 保底触发态（PityArmed）【High】
**文件**：`src/unity/Features/Gacha/UI/PullButton.cs`（镜像同路径）
- 新增嵌套枚举 `public enum PullState { Normal, Pressed, Disabled, PityArmed }`（由 3 态扩为 4 态）。
- 新增序列化空引用字段：
  - `[SerializeField] private Image? _imgArmedBg;`        // 保底态底（TODO(art): `btn_bg_armed_9slice`）
  - `[SerializeField] private Image? _imgArmedBadge;`     // 保底态角标（TODO(art): 「必出 SSR」sprite）
- 新增状态追踪：`private PullState _state = PullState.Normal;` + `private bool _pityArmed;`。
- **方法签名**：`public void SetPityArmed(bool armed)`
  - 仅切换状态标志与不透明 `SetActive` 钩子；`_imgArmedBg/_imgArmedBadge` 为空引用时 `SetActive` 为 no-op（无 sprite 不渲染），**不抛 MissingReference**。
  - 与 `Disabled` 正交：禁用优先（`if (_state != PullState.Disabled)`），保底态不改变 `interactable`。
- 新增 `public PullState CurrentState => _state;`（供调试/VFX 读取，不改业务）。
- `SetDisabledInsufficient` 同步维护 `_state`（解除禁用时若仍临近保底回到 `PityArmed`）。
**调用点（GachaScreenController）**：新增 `private void RefreshPityArmed()`，阈值 `pity >= Mathf.Max(0, _hard - 5)`（数据驱动，随池 hard 阈值走，不硬编码 85）；在 `BindPool`（绑池后）与 `OnPull`（Pull 后保底更新）调用 → `_singlePull?.SetPityArmed(armed)` / `_tenPull?.SetPityArmed(armed)`。
**默认值**：`_pityArmed=false`、引用字段 `null`。
**待美术接入 TODO**：`_imgArmedBg ← btn_bg_armed_9slice`（idle 辉光转鎏金→朱砂）；`_imgArmedBadge ← 角标「必出 SSR」sprite`。

### E2 — PityProgressBar tick 脉冲回调【Medium】
**文件**：`src/unity/Features/Gacha/UI/PityProgressBar.cs`（镜像同路径）
- 在 `DetectCrossing(int newPity)` 跨越后触发脉冲：Soft→`Pulse(_boundSoft)`、Hard→`Pulse(_boundHard)`。
- 新增：
  - `private void Pulse(int milestone)`（调用下方两者，null 安全）。
  - `protected virtual void OnMilestonePulse(int milestone) { }`——**空方法体**，供子类/动画层覆写（描边加厚+微缩放 0.2s，art §4.2）。
  - `public event Action<int>? MilestonePulse;`——C# 事件，VFX 层可订阅；`milestone` = 被跨过的阈值（50 软 / 90 硬）。
- 需补 `using System;`（原文件缺，否则 `Action<int>` 解析失败——已补）。
**默认值**：无可视化副作用（空体 + 事件无订阅者即 no-op）。
**待 VFX 接入 TODO**：订阅 `MilestonePulse` 或覆写 `OnMilestonePulse`，`reduce_motion` 下由订阅方读 `MotionScale` 决定跳过（art §4.2 / Standard I）。

### E3 — imgTrack / matPityFill 序列化字段评估【Low】
**文件**：`src/unity/Features/Gacha/UI/PityProgressBar.cs`（头部注释）
- **结论：不新增字段**。按 `design/art/m4-ui-art-spec.md §7.3 #3`，现有 `_imgFill` 足够：轨道由 prefab 背景 Image 承载、渐变经 `_imgFill.material`（赋值 `mat_pity_fill`）实现。
- 头部注释明确写入「E3 已评估：复用现有 `_imgFill` 即可，美术已按现有字段落地、无阻塞」。
- 无任何代码/字段改动。

### E4 — CurrencyLabel icon 字段化【Medium】
**文件**：`src/unity/Features/Gacha/UI/GachaScreenController.cs`（CurrencyLabel 无独立 .cs，实为 `_currencyLabel` 字段，故落于控制器）
- 新增：`[SerializeField] private Image? _iconImage;`——sibling Image 方案（prefab 内与 `_currencyLabel` 相邻的 Image）。
- **方法签名**：`public void SetIcon(Sprite? sprite)`——`_iconImage == null` 时安全 no-op；否则设 `sprite` 并 `enabled = sprite != null`。
- 注释对比取舍：**sibling Image**（采用）vs TMP 内联 `<sprite name="ico_cur_fulu">`（备选，需 SpriteAsset 图集配置）。选 sibling 因 UGUI 下不依赖字体图集、布局对齐可控、调试直观。
- **默认值**：`_iconImage = null`（未接图标时余额数字正常显示）。
- **待美术接入 TODO**：`_iconImage ← ico_cur_fulu` sprite。

### E5 — `_disabledTint` 双重去饱和防御注释【Medium】
**文件**：`src/unity/Features/Gacha/UI/PullButton.cs`（字段 + `SetDisabledInsufficient`）+ `PityProgressBar.cs` 头部
- 在 `_disabledTint` 字段与 `SetDisabledInsufficient` 加防御注释：若 prefab 接入烘焙禁用 sprite（`btn_bg_disabled_9slice`，已含去饱和+对角划线），须将 `_disabledTint` 设为**白 `(1,1,1)`**，否则与 sprite 双重去饱和 → 禁用态过重（可见瑕疵，非阻断，见 m4-art-closure R2）。
- 约定：`_disabledTint` 永不接受 null；白值 = `Color.white` 表示「完全交给 sprite，不做额外去饱和」。
- **未改视觉逻辑**，仅文档化防护。
- `PityProgressBar.cs` 头部注明：本进度条无禁用态/无 `_disabledTint`，双重去饱和问题仅 PullButton 适用。

### E6 — PityProgressBar 头部注释字段名修正【Low】
**文件**：`src/unity/Features/Gacha/UI/PityProgressBar.cs` 头部
- 修正字段列表为实际序列化字段：`_imgFill / _txtCount / _txtSub / _mark50 / _mark90`（去除原「`imgTrack/matPityFill 暂缓至终稿增强`」误导表述，与 §7.3 对齐；并合并 E3 评估结论）。

### T4 — Rolling 修正 A（蓄力层 StopLoop 时序）【High】
**文件**：`src/unity/Features/Gacha/UI/GachaScreenController.cs`（**未改 `AudioService.cs` / `IAudioService`**）
- 现状核对：`OnPull` 中 `PlayLoop(Gacha_Rolling)` 后**未**在同步 `Pull()` 后立即 `StopLoop`（旧实现问题已不在本代码）；`StopLoop(Gacha_Rolling)` 已位于 `RevealSequence` 首张 `Gacha_Card_Flip_Start` 之后（design note A 位置）。
- 本次落点：**加 T4 注释标记** 三处——
  1. `OnPull` 的 `PlayLoop`：`// T4 … 蓄力层在此启动、不在此停止；停止已移至首张 Flip_Start 之后`。
  2. `RevealSequence` 首张 `Flip_Start` 后的 `StopLoop`：`// T4 … 首张翻牌开始后才停蓄力层；StopLoop 幂等，后续卡 no-op`。
  3. 收尾 `StopLoop`：`// T4 兜底：跳过/异常收尾时确保蓄力层停止`。
- 实现零接口改动；蓄力层循环音由 `RevealSequencer` 时间轴驱动，锚定首张 `Flip_Start` 之后停止，避免「蓄力层近不可闻」（m4-audio-closure R1）。

---

## 2. 双目录镜像情况

- 权威源：`src/unity/`（本次编辑）。
- 编译镜像：`unity/My project/Assets/Scripts/`（gitignored，用户侧 sync 脚本目标）。
- 编辑前 4 个目标文件 `src/unity` 与镜像 **逐字节一致**（已 `diff` 验证）。
- 本次编辑后镜像结果：
  | 文件 | 是否编辑 | 是否镜像 | 镜像结果 |
  |---|---|---|---|
  | `Features/Gacha/UI/PullButton.cs` | ✅ | ✅ | 已 `cp` 并 `diff` 确认逐行一致 |
  | `Features/Gacha/UI/PityProgressBar.cs` | ✅ | ✅ | 已 `cp` 并 `diff` 确认逐行一致 |
  | `Features/Gacha/UI/GachaScreenController.cs` | ✅ | ✅ | 已 `cp` 并 `diff` 确认逐行一致 |
  | `Features/Audio/AudioService.cs` | ❌（T4 不涉及 AudioService） | — | 未改、未镜像（保持原一致） |
- 全部 3 个改动文件镜像后 `diff -q` 通过（identical）。无文件因「漂移/不同源」被跳过。

---

## 3. 已知编译风险点（静态自检，未实跑 Unity）

1. **`PityProgressBar.cs` 缺 `using System;`**——已补（E2 用 `Action<int>`）。若用户在旧镜像手工改过该文件顶，需确认未遗漏此 using。
2. **`PullState.Pressed` 枚举值未被赋值**：仅作 4 态文档化，由 `Button` 组件原生表现，不触发未使用警告（枚举成员不作为 unused 报）。
3. **空引用字段（`_imgArmedBg/_imgArmedBadge/_iconImage`）**：均经 `?.`/`== null` 守卫，`SetPityArmed`/`SetIcon` 在 null 时为 no-op，不会 `NullReferenceException`；无 CS0169（已在实际代码读取）。
4. **`MilestonePulse` 事件 / `OnMilestonePulse`**：当前无订阅者/覆写者 → no-op，不影响现有 reveal 时序与音频。
5. **`RefreshPityArmed` 调用时机**：`BindPool` 与 `OnPull` 均已确保 `_gacha != null`（对应入口前置校验齐备），`Mathf` 来自 `UnityEngine`（已 using）。
6. **T4 音频时序**：`StopLoop` 幂等（`AudioService` 内有 `_loops.ContainsKey` 守护），逐卡重复调用安全；`_revealCards` 收尾 `ForceFront` 与 `StopLoop` 顺序不变。
7. **未实跑验证**：本环境无 Unity，未跑 `csc`/IL2CPP 编译与 prefab 绑定；字段命名/命名空间/可空注解与现有代码一致，但**最终编译与 prefab 字段赋值需用户在 Unity 内验证**（见 V1/V2，m4-art-closure §2.2）。

---

## 4. 待美术/音频资产接入 TODO 汇总（用户/美术侧）

- **E1**：`PullButton` prefab 接 `_imgArmedBg`(`btn_bg_armed_9slice`) + `_imgArmedBadge`(角标 sprite)；可选在 `SetPityArmed` 内取消 sprite 切换注释。
- **E2**：VFX/动画层订阅 `PityProgressBar.MilestonePulse` 或覆写 `OnMilestonePulse`，实现 tick 脉冲。
- **E4**：`GachaScreenController` prefab 接 `_iconImage`(`ico_cur_fulu`)；业务层在合适时机调 `SetIcon(sprite)`（或保留 null）。
- **E5**：接入 `btn_bg_disabled_9slice` 时，将 `PullButton._disabledTint` 在 Inspector 改为白 `(1,1,1)`。
- **T4 资产**（audio，P1，非本任务范围）：`gacha_rolling.wav` 终稿（2–4s 无缝 loop）落 `unity/My project/Assets/Audio/Gacha/`，并在 `AudioService` 绑 `SoundBank`/`AudioMixer`（T2/T3，业务零改）。

---

## 5. 需用户/主理人决策的新问题

1. **T4 真可听性边界（建议，非阻塞）**：当前 `RevealSchedule` 首张卡 `AppearTime = 0`（第 0 张 × 0.08s），即首张 `Flip_Start` 在 t≈0 触发，蓄力层实际仅播放约 1 帧（~16ms）后才停——design note A 已把 StopLoop 从「OnPull 同步」挪到「首张 Flip_Start 后」，但**若要让蓄力层真正可听**，需引入 rolling 预滚延迟（如首张卡 `AppearTime` 前加一段 charge 时长），属演出时序改动，超出 T4「音频排序」最小范围，且裁定①定位「最小改动/零新增资产」。建议用户有 Unity 环境后实测：若仍近不可闻，再决定是否加 pre-roll（可作为 M4.x 微调，不影响本任务编译）。**未在代码中改动 `RevealSchedule` 时序。**
2. **E1 保底临近阈值**：采用「距硬保底 5 抽内」(`hard-5`) 而非 art §3.2 示例的硬编码 85；如美术希望严格按「≥85」且池 hard 可能非 90，请确认阈值口径（当前随池 hard 走，更通用）。
3. **E4 icon 方案**：本任务选定 sibling Image；若后续统一 TMP 图集管理，可改内联 `<sprite>`（已在注释留备选）。不影响编译。

> 以上 3 项均为可选/待确认，**不阻塞本次 7 项钩子落地与编译就绪**。
