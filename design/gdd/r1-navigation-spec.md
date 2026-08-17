# R1 导航层规格（H-C1 真实导航 + 返回）

- **Task**：DESIGN-R1-NAV-001 ｜ 优先级：High ｜ 阶段：M3 收尾
- **范围**：仅「导航层 + 返回」。推图**玩法/美术留后续里程碑**，R1 推图屏仅需灰盒占位。
- **红线**：ADR-3 — UI 只经 EventBus 发意图事件（`GachaAcquireIntentEvent{Reason="battle"}`），**绝不直连场景/导航**；导航层订阅事件接管跳转。
- **本任务只产出规格文档，不修改任何 `.cs`**；代码改动清单见 §9 供 engineering-lead 实现。

---

## 1. 现有代码检索结论（要求 1）

对 `f:/AI/仙侠卡牌项目/**` 做 `Glob` + `Grep`（关键字 `NavigationManager` / `SceneManager.LoadScene` / `LoadScene` / `GachaAcquireIntentEvent` / `EventBus` 导航订阅）：

| 检索项 | 结论 |
|---|---|
| 自定义 `NavigationManager` / 跨屏导航框架 | **未找到** |
| 业务代码 `SceneManager.LoadScene` / `LoadScene` | **未找到**（全仓命中仅在 `Library/PackageCache` 的 ugui/test-framework/shader 测试与内部函数，非业务代码） |
| `GachaAcquireIntentEvent` 的导航订阅 | **仅 `Bootstrapper.Awake` 订阅，且为 `Debug.Log` 占位**（无真实跳转接管） |
| 抽卡屏结构 | 单场景 `Assets/临时1.unity` 内 `GachaScreenRoot`（挂 `GachaScreenController` + `Canvas` + UI 子物体），**非独立 Scene**（已确认 `临时1.unity:1207`） |
| `EventBus` API | `Subscribe<T>(Action<T>)` / `Unsubscribe<T>(Action<T>)` / `Publish<T>(T)`（类型化，见 `Core/EventBus.cs`） |

**结论：无现成导航框架，R1 需从零建立最小导航层。**

---

## 2. 架构决策：方案 A vs B（要求 2）

### 方案 A — 多 Scene
抽卡屏拆为独立 `GachaScene` + 新建占位 `BattleScene`，导航层 `SceneManager.LoadScene`（或 additive + 持久导航根）切换场景。

### 方案 B — 同 Scene 内 Canvas 管理（**R1 推荐**）
导航层管理各屏 `Canvas`/`Root` 的 `SetActive`，抽卡屏与占位推图屏**同场景共存**，切换显隐。

| 维度 | A 多 Scene | B 同 Scene（推荐） |
|---|---|---|
| 改动场景结构 | 需拆/建 Scene | 不改场景结构 |
| 风险 | 场景加载时序、跨场景引用、资产拆分 | 仅显隐控制 |
| 打通速度 | 慢 | **快** |
| R1 适配度 | 过度 | **恰好（灰盒）** |

> ✅ **R1 推荐 B**：当前为单场景 GameObject 树，不拆场景即可快速打通；零场景资产风险；占位推图屏以灰盒 `Canvas` 同场景共存，`SetActive` 切换；后续可平滑迁移到 A。
>
> 📌 **A 是终稿规范路径**：推图玩法/美术正式接入时，拆 `GachaScene` + `BattleScene`，导航层改用 `SceneManager.LoadScene` 切换。R1 不采用 A，以免引入场景拆分/加载时序风险。

---

## 3. 导航层职责与订阅点（要求 3）

### 3.1 新增 `NavigationManager`（独立 MonoBehaviour）
- **命名空间**：`XiaXia.Features.Navigation`
- **职责**：
  1. 持有各屏 Root/Canvas/返回按钮引用（SerializeField 或场景内 Find 兜底）。
  2. 维护**屏栈** `List<GameObject>`，保证任意时刻仅 1 屏 `SetActive(true)`。
  3. 订阅 `GachaAcquireIntentEvent` 做 `reason → 屏` 路由（§4）。
  4. 订阅 `GachaReturnIntentEvent` 做 `Back()`（§6）。
  5. 严守 ADR-3：只经 EventBus 收意图，不向 UI 暴露任何跳转 API。
- **生命周期**：与 `Bootstrapper` 同挂于 `临时1.unity` 场景根。由 `Bootstrapper` 在 `Awake` 末尾注入（同 `GachaScreenController` 模式）：`navigation?.Initialize(services, bus)`。

### 3.2 订阅点推荐：**独立 `NavigationManager`，不在 `Bootstrapper` 内联**
理由：
1. **关注点分离**：`Bootstrapper` 负责"构造并注册服务"，导航属"运行时屏切换"，不应混入引导脚本。
2. **可测试性**：`NavigationManager` 可独立单测（给定 `EventBus` + 屏引用，断言 active 状态变更）。
3. **消除双订阅歧义**：`Bootstrapper` 现有 `Debug.Log` stub 应由 `NavigationManager` 全权接管（§9 由 engineering 移除 stub）。

> ⚠️ 因本任务不改代码，`Bootstrapper` 的 stub 订阅在实现前仍存在；R1 落地时须移除（详见 §9），避免"跳转两次/日志歧义"。

---

## 4. 事件 → 屏映射表（要求 3）

| `Reason` | 目标屏 | 处理 | 备注 |
|---|---|---|---|
| `"battle"` | 占位推图屏（`BattleScreenRoot`） | `Push(battleRoot)`：显 battle / 隐 gacha | R1 仅灰盒 |
| `"store"` | 商城屏（**预留，未实装**） | `Debug.LogWarning("store 屏未实现")` + 留当前屏 | 后续里程碑 |
| 未知/空 | 留当前屏 | `Debug.LogWarning("未知 acquire reason")` | 防御性 |

---

## 5. 占位推图屏规格（灰盒，要求 3）

- **节点**：`BattleScreenRoot`（同场景 `临时1.unity`），初始 `SetActive(false)`。
- **结构**：
  - `Canvas`（与抽卡屏 Canvas 同级；进入时因 gacha 屏已 `SetActive(false)`，无叠层/射线穿透风险）。
  - 居中 `TextMeshProUGUI`：文本 **"推图（占位）"**。
  - 返回按钮 `Button`：文本"返回"，由 `NavigationManager` 在 `Initialize` 中接 `onClick`（§6）。
- **范围边界**：R1 **不含**推图玩法逻辑、关卡数据、美术资产；仅验证"能进能出"的导航闭环。玩法/美术由后续里程碑接入。

---

## 6. 返回机制（要求 3）

> ✅ **推荐：事件驱动返回（与进入对称，严守 ADR-3）**

- 新增事件（同文件 `Features/Shared/Events/GachaEvents.cs`，命名空间 `XiaXia.Features.Shared.Events`）：
  ```csharp
  // gacha:return_intent —— 占位推图屏"返回"按钮发出，导航层订阅后 Back() 回抽卡屏。
  // UI 不直接调用导航层（ADR-3 红线）。
  public sealed class GachaReturnIntentEvent { }
  ```
- **接线**：`NavigationManager.Initialize` 中
  `_battleBackButton?.onClick.AddListener(() => _bus.Publish(new GachaReturnIntentEvent()));`
  即返回按钮**只 Publish 事件**，不持有 `NavigationManager` 引用。
- **处理**：`NavigationManager` 订阅 `GachaReturnIntentEvent` → `Back()`：
  `Pop()` 屏栈 → 显 gacha / 隐 battle。
- **屏栈示例**：
  `[gacha] --acquire(battle)--> [gacha, battle(top)]`；返回 `Pop` → `[gacha]`。

> ❌ 不推荐：返回按钮直接调 `NavigationManager.Back()`（UI 直连导航，违反 ADR-3）。

---

## 7. 与现有 `GachaScreenController` / `Bootstrapper` 的接口点（要求 3）

| 组件 | R1 改动 | 接口点 |
|---|---|---|
| `GachaScreenController` | **零改动** | 已 `Publish(GachaAcquireIntentEvent{Reason="battle"})`，职责不变 ✅ |
| `Bootstrapper` | 实现阶段改动（§9） | 新增 `[SerializeField] NavigationManager? _navigation;`；`Awake` 末尾 `_navigation?.Initialize(services, bus);`；**移除** `GachaAcquireIntentEvent` 的 `Debug.Log` stub 订阅 |
| `NavigationManager`（新增） | 新增文件 | 暴露 `Initialize(ServiceRegistry, EventBus)`（与 `GachaScreenController` 同款签名）；`Awake` 自行 `FindObjectOfType` 兜底（同 `GachaScreenController` 模式） |
| `GachaEvents.cs` | 实现阶段改动 | 新增 `GachaReturnIntentEvent` 类 |

**注入链路**（ADR-3 友好）：`Bootstrapper` 构造 `EventBus` 与 `ServiceRegistry` → `NavigationManager.Initialize(services, bus)` 注入同一实例 → `NavigationManager` 在**该 bus** 上订阅意图事件。导航层不自行 `new` 基础设施，完全复用引导注入。

---

## 8. 已知风险与缓解（要求 3）

| 风险 | 描述 | 缓解 |
|---|---|---|
| **R1-1 同场景两屏 Canvas 叠层** | 两屏若同时 `SetActive(true)` 会遮挡/事件穿透 | 进入时严格 `gacha.SetActive(false)` + `battle.SetActive(true)`；返回反向；屏栈保证仅 1 屏 active；battle 初始 false |
| **R1-2 EventBus 持久订阅泄漏** | `NavigationManager` 未 Unsubscribe → 重编译/场景重载重复订阅→多次跳转 | `OnDestroy`/`OnDisable` 中 `bus.Unsubscribe<GachaAcquireIntentEvent>(OnAcquireIntent)` + `Unsubscribe<GachaReturnIntentEvent>(OnReturnIntent)`，配对订阅（参照 `GachaScreenController.OnDisable` 模式） |
| **R1-3 双订阅歧义** | `Bootstrapper` stub 与 `NavigationManager` 同时订阅 acquire 事件 | 实现阶段移除 `Bootstrapper` stub（§9）；未移除前 stub 仅日志，不影响功能，code review 标记删除 |
| **R1-4 隐藏屏射线遮挡** | 透明屏若用 `alpha=0` 而非 `SetActive` 会拦截射线 | R1 用 `SetActive(false)` 方案，hidden 屏不接收射线，无穿透 |
| **R1-5 返回上下文错误** | 未来多入口（store 等）Back 栈错乱 | 屏栈通用化；`GachaReturnIntentEvent` 在 R1 仅 pop 到 gacha，未来各入口各自维护栈 |
| **R1-6 抽卡屏状态恢复** | `SetActive(false)`→`OnDisable`（unsubscribe 经济/抽卡事件），返回 `OnEnable` 重订阅并刷新 | 现有 `GachaScreenController` 已有 `OnEnable` 兜底首刷逻辑；列为 QA 验收项（§10） |

---

## 9. 实施接口 / 文件清单（供 engineering-lead）

**新增文件**
1. `unity/My project/Assets/Scripts/Features/Navigation/NavigationManager.cs`
   - `namespace XiaXia.Features.Navigation`
   - `Initialize(ServiceRegistry, EventBus)`；屏栈 `List<GameObject>`；订阅 `GachaAcquireIntentEvent` / `GachaReturnIntentEvent`；`OnDestroy` 反订阅；`[SerializeField] GameObject _gachaScreenRoot, _battleScreenRoot; [SerializeField] Button? _battleBackButton;`
2. `unity/My project/Assets/Scripts/Features/Shared/Events/GachaEvents.cs`
   - 新增 `GachaReturnIntentEvent`（仅 R1 需要；`GachaAcquireIntentEvent` 不改）

**改动文件（实现阶段，非本任务范围）**
3. `Bootstrapper.cs` — 新增 `[SerializeField] NavigationManager? _navigation;`；`Awake` 末尾 `navigation?.Initialize(services, bus);`；**移除** `bus.Subscribe<GachaAcquireIntentEvent>(Debug.Log stub)`。
4. `临时1.unity` — 场景根挂 `NavigationManager`；拖入 `GachaScreenRoot`、新建 `BattleScreenRoot`（Canvas + "推图（占位）"Text + 返回 Button）并接引用。

**依赖/顺序**
- `NavigationManager` 须与 `GachaScreenController` 同场景、且在 `Bootstrapper.Awake` 之后注入（订阅生效顺序无强依赖，因二者均在 Awake 期完成）。
- 不改 `GachaScreenController`、不改 `GachaAcquireIntentEvent` 字段。

---

## 10. QA 验收清单（建议）
- [ ] 点击抽卡屏 InsufficientCurrency CTA → 抽卡屏隐藏、推图占位屏显示（"推图（占位）"）。
- [ ] 推图占位屏"返回" → 抽卡屏恢复显示、推图屏隐藏；抽卡屏货币/状态机正确恢复（`OnEnable` 兜底首刷生效）。
- [ ] 反复进出无叠层、无射线穿透、无重复跳转（验证 R1-2 反订阅生效）。
- [ ] `GachaAcquireIntentEvent`/`GachaReturnIntentEvent` 经 EventBus 流转，UI 无任何对 `NavigationManager` 的字段引用（ADR-3 红线复检）。
- [ ] `Reason="store"` 触发时仅日志、不崩、留当前屏。

---

## 11. 设计理论自检（角色红线）
- **主导策略**：无（导航为中性通道，不奖励/惩罚任何玩法选择）。
- **经济失衡**：无（不涉及资源投放）。
- **认知过载**：低（仅 1 个灰盒屏 + 1 个返回按钮，进入/返回语义对称）。
- **支柱漂移**：无（纯导航基建，不引入新美学/玩法支柱）。
- **ADR-3 红线**：进入/返回均经 EventBus 意图事件，无任何 UI→导航字段直连。✅
