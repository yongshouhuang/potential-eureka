# M3 里程碑概述 · 抽卡表现与 UI

**版本**：v0.4.0 ｜ **日期**：2026-07-23 ｜ **阶段**：Phase 5 制作（预制作切片落地）
**主 commit**：`56966d8` ｜ **Git 链**：`6c21322`(M2) → `7250526`(M1重构) → `fdbd9c8`(M3初) → `56966d8`(M3修复)
**引擎**：团结引擎 1.9.3 / UGUI / Android IL2CPP（竖屏 1080×2340，Match=Height）

---

## 1. 里程碑范围

M3 把「抽卡结果」从纯逻辑（M2 `IGachaService.Pull`）变成**玩家可见、可交互、有表现力**的切片：

- 三份已对齐预制作规格（UX / 美术 / 音频）全部定稿并落盘
- UGUI 抽卡屏 MVP 灰盒切片跑通（六态状态机 + 翻面 + 保底条 + 错峰揭示）
- 音频子系统桩（Unity AudioMixer，零外部资产即可跑）
- M2 四处接口缺口 H1–H4 补齐
- 运行时接线 R1/R4 代码层收口

---

## 2. 交付物清单

### 2.1 设计 / 美术 / 音频规格（主理人汇编）
| 角色 | 文件 |
|---|---|
| design-strategist（文策渊） | `design/ux/gacha-screen-mvp.md` |
| art-director（林绘澄） | `art/gacha-ui-asset-spec.md` |
| audio-director（阮和鸣） | `design/audio/gacha-audio-spec.md` v1.1 |

### 2.2 工程实现（src/unity/Features/，已同步 `unity/My project/Assets/Scripts/`）
| 模块 | 文件 | 说明 |
|---|---|---|
| 抽卡 UI | `Gacha/UI/GachaScreenController.cs` | 六态机 Idle/PoolSelected/Rolling/Reveal/ResultList/InsufficientCurrency |
| 抽卡 UI | `Gacha/UI/ResultCard.cs` + `FlipController.cs` | 卡牌 prefab 逻辑 + scale-X 翻面（reduce_motion 走静态定格） |
| 抽卡 UI | `Gacha/UI/PityProgressBar.cs` | 保底条（GetPity + GetPityThresholds） |
| 抽卡 UI | `Gacha/UI/PullButton.cs` | 单抽/十连按钮 + 余额不足 CTA |
| 抽卡 UI | `Gacha/UI/RevealSchedule.cs` | 错峰时间轴（0.08s/张，t=0.25 换面，+0.2 SSR 峰值） |
| 抽卡 UI | `Gacha/UI/Bootstrapper.cs` | 服务注册 + Initialize 调起 |
| 音频 | `Audio/AudioService.cs` `IAudioService.cs` `SoundId.cs` `SoundBank.cs` `PlaceholderAudioProvider.cs` `AudioSettings.cs` | Unity AudioMixer 5 组、AudioSource 池化、程序化占位音 |
| 共享 | `Shared/IAccessibilitySettings.cs` `AccessibilitySettings.cs` `IShikigamiCatalog.cs` `ShikigamiCatalog.cs` | reduce_motion 单例 + 式神目录 |
| M2 缺口 | `Gacha/IGachaService` 增 `GetPityThresholds/GetPoolList/GetPullCost`；`Economy/IEconomyService` 增 `GetBalance` | H1–H4 |

### 2.3 工程报告
`outputs/m3-engineering-report.md`（含 R1–R6 风险登记与逐项状态）

---

## 3. 编译修复历史（沙箱无法代跑，本机迭代）

| 轮次 | 问题 | 修复 |
|---|---|---|
| 1 | `AudioService.StopCategory` 把 `AudioSource` 当 `SoundId` 传 `CategoryOf` | 改传 `kv.Value`；快照遍历 Remove |
| 1 | `PityModel.CountText/SubText` nullable 警告 | 加 `?`；`PityProgressBar` 读时 `?? ""` |
| 2 | `Features.Gacha.UI.asmdef` 缺 `Unity.TextMeshPro` 引用 | references 补 `Unity.TextMeshPro` |
| 3 | `SoundId.RevealTopLayerFor` 非扩展方法 | 加 `this` |
| 3 | `Bootstrapper` `AudioSettings` 与 `UnityEngine.AudioSettings` 歧义 | 完整限定名 |
| 3 | `GachaScreenController` tuple+lambda 推断失败 | 显式 `new Action(()=>…)` |
| 3 | `InstantiateResultCard` 返回 nullable 直接 Add | `if(card==null) return` |

最终 amend 到 `56966d8`，`v0.4.0` 指向之。

---

## 4. 本地验证结果

- **编译**：团结引擎 1.9.3 加载工程 **0 error**（退出 Safe Mode）
- **EditMode 测试**：`41/41` 全绿（M2 的 30 + M3 新增 Reveal/Pity/Audio 测试），**0 失败**

---

## 5. 已知风险 / 下一步

| 项 | 状态 | 说明 |
|---|---|---|
| R3 编译/测试 | ✅ 已本机验证 | 41/41 全绿 |
| R1/R4 接线代码 | ✅ 已落 | `Bootstrapper` + `AccessibilitySettings` 入仓 |
| R6 AudioMixer 资源 | ⏳ 本机编辑器动作 | 建 5 组（Master/Music/Ambient/SFX/UI/VO）挂 `AudioService._mixer`（不填也能跑） |
| 场景挂接 | ⏳ 本机编辑器动作 | 拖组件（见 `m3-engineering-report.md` §4.3-4 或会话步骤），不进 git |
| 美术终稿接入 | ⏳ 待 art | 按 `art/gacha-ui-asset-spec.md` §7.3 Sprite 字段同名替换，业务零改 |
| 音频终稿接入 | ⏳ 待 audio | 用真实 `SoundBank` 替换 `PlaceholderAudioProvider` |

**未做的高影响动作**：无删除、无强制 push（v0.4.0 已常规推送）。

---

## 6. 里程碑结论

M3 抽卡表现与 UI 切片达到可运行、可验证、可交付状态。核心交互循环（选池 → 单抽/十连 → 错峰翻面 → 保底条更新 → 占位音）端到端跑通，红线 ADR-3 全程守住（UI 层只经 ServiceRegistry / EventBus，无任意 `*Manager` 字段引用）。

下一步建议进入 **M4 美术/音频终稿接入** 或 **继续扩展抽卡屏功能（多池切换、十连历史、出货图鉴）**——由你拍板。
