# 仙侠卡牌 · 测试策略（GUT 脚手架 + 优先测试）

> 对齐：架构 `01-architecture.md` §1.1（测试=GUT+验证驱动）/ §1.3（单例解耦：管理器只经 `EventBus`/`GameState` 通信，无跨 import）/ §1.4（模块映射）/ §1.7（schema v1）/ §1.8（EventBus 类别冻结）/ §1.9（性能预算与 GDExtension 触发线）。
> 引擎 Godot 4.x + GDScript；评审 solo/lean，聚焦核心逻辑可测。
> autoload 单例（架构 §1.2/§1.3）：`EventBus` / `GameState` / `SaveManager` / `CloudSaveService` / `ConfigLoader` / `EconomyManager` / `GachaManager` / `CultivationManager` / `DeckBuilder` / `BattleManager` / `BondManager` / `UIThemeController` / `InputBridge` / `AccessibilitySettings`。

## 1. GUT 集成步骤

1. **安装**：从 GUT 仓库获取 Godot 4.x 兼容版本，置于 `res://addons/gut/`（架构 §1.2 已预留该目录）。
2. **启用**：Project Settings → Plugins → 勾选 GUT。
3. **目录**：测试脚本置于 `res://tests/`，命名 `test_*.gd`，继承 `GutTest`（`extends GutTest`）。
4. **运行（编辑器）**：GUT 面板选 `res://tests`，Run。
5. **运行（CI / headless）**：
   ```bash
   godot --headless --path res:// \
     --script res://addons/gut/gut_cmdln.gd \
     -gdir=res://tests -gexit -glog=1
   ```
   （`-gexit` 使存在失败用例时非零退出，供 CI 门禁；`-gdir` 指定用例目录。）
6. **场景树无关（headless 友好）**：优先测试只依赖 `GameState` + `EventBus` + `ConfigLoader` 注入，不依赖真实场景树 → 经济/战斗/存档/抽卡/可访问性均可在无视口下断言。需在场景内验证的双端适配（断点布局/热区）另用 `tests/integration/` 场景用例，不阻塞核心逻辑门禁。

## 2. 优先测试清单（验证驱动：先写测试，再实现）

| # | 测试目标 | 对应 Story | 关键断言（精确数值，对齐 GDD） |
|---|---|---|---|
| T1 | 经济闭环 | E1（S1） | 产出/消耗正确；`fu_lu` 日软预算≥10 封顶；`free_ten_pull`=10/日**不计入**软预算（pass2 解耦）；`po_dan` 周~5；`jue_xing_shi` 仅 Boss（`boss_only`）；余额不足 `spend()` 返回 `false` 拦截；`economy:currency_changed` 广播 |
| T2 | 五行克制结算 | E4-S2（S2） | `BattleResolver.resolve_damage`：克制方伤害 ×[1.25,1.35]、被克 ×[0.7,0.8]、相生增益>0（注入假 `ElementMatrixDef`）；纯计算可独立测 |
| T3 | 存档读写 + 冲突解决 | E6-S3/S4（S1/S3） | 写→读一致；`checksum` 篡改拒绝并回滚本地 cache；last-write（version+ts 高者胜）；cache 副本可回滚；delta <50KB；离线优先不阻塞 |
| T4 | 抽卡保底 | E2-S2（S1） | 50 抽未出 SSR → 第 50 抽 SSR 率≥50%（软保底）；第 90 抽必出 SSR（硬保底）；`pity` 按 `pool_id` 独立（换池不继承）；种子化 RNG 可复现 |
| T5 | 可访问性设置单例 | E6-S5/S6（S3） | `AccessibilitySettings` 字段变更 emit `accessibility_changed`；`text_scale`(1.0–1.3) 生效（缩放 reflow 不溢出/不裁切）；`reduce_motion`→`MotionScale=0`；`color_blind_mode` 切换激活 CVD 路径；持久化至 `GameState.settings` |
| T6 | 羁绊连携（事件解耦） | E4-S3（S2） | 同队 2 式神 +8~12% / 3+ +15~20%；B4 仅经 `bond:combo` 事件获加成，**不 import `BondManager`** |
| T7 | 养成最终式神 | E3-S5（S2） | `CultivationManager.get_final_unit(id)` 返回正确 `final_stats/skills/element/bond_tags/breakthrough`，与 B4 读取一致 |

## 3. 测试数据注入方式（ConfigLoader 假表）

`ConfigLoader`（架构 §1.4 / ADR-004）暴露内存覆盖接口，测试在 `before_each` 注入假表、`after_each` 复位，使逻辑与真实 `data/*` 解耦、确定性可复现。各管理器经 `ConfigLoader.load_table(id, fallback_path)` 取配置，故注入即生效。

```gdscript
# res://scripts/systems/config_loader.gd（架构 §1.4 / ADR-004）
extends Node  # 注册为 autoload: ConfigLoader
var _overrides := {}   # table_id -> 内存假表(Resource 或 Dict)

func load_table(id: String, fallback_path: String):
    if _overrides.has(id):
        return _overrides[id]
    return load(fallback_path)   # 真实 .tres / JSON

func inject(id: String, data) -> void:
    _overrides[id] = data        # 测试注入假表

func reset() -> void:
    _overrides.clear()
```

```gdscript
# res://tests/test_gacha_pity.gd（验证驱动示例：先此测试，再实现 GachaManager）
extends GutTest

func before_each():
    ConfigLoader.reset()

func after_each():
    ConfigLoader.reset()

# --- T4: 硬保底（90 抽必出 SSR） ---
func test_hard_pity_at_90():
    # 注入 0% SSR 假池 + 种子，强制抽满 90 次必触发硬保底
    ConfigLoader.inject("gacha/pools", _fake_pool(ssr_base=0.0, soft=50, hard=90))
    var g := GachaManager.new()
    g.rng = RandomNumberGenerator.new(); g.rng.seed = 12345
    var got_ssr := false
    for i in 90:
        var r := g.pull("standard")
        if r.rarity == "SSR":
            got_ssr = true
            break
    assert_true(got_ssr, "第90抽必出SSR（硬保底）")

# --- T4: 保底不跨池 ---
func test_pity_not_cross_pool():
    ConfigLoader.inject("gacha/pools", _fake_pool(ssr_base=0.0, soft=50, hard=90))
    var g := GachaManager.new(); g.rng.seed = 999
    for i in 89:
        g.pull("pool_a")             # pool_a 抽 89 次
    var before := g.get_pity("pool_b")
    g.pull("pool_b")                 # 切到 pool_b
    assert_eq(g.get_pity("pool_b"), before + 1, "pool_b 计数从 0 起，不继承 pool_a")
```

> 注入内容：`EconomyConfig`(预算)、`GachaPool`(概率/保底/新手)、`ElementMatrixDef`(五行倍率)、`GrowthCurveDef`(养成曲线)、`ShikigamiDef`(属性)、`AccessibilitySettings` 默认值。所有随机路径（抽卡/事件）一律种子化 `RandomNumberGenerator` 确保可复现。

## 4. CI 调用与质量门

- **lean CI**（架构 §1.1）：导出双端 → `gdformat`/`gdlint` → **GUT 全量**（§1 命令）→ 场景加载 smoke。
- **门禁**：GUT 非零退出即阻断合并；优先测试 **T1–T5 为合并必备**（经济闭环 / 五行克制 / 存档冲突 / 抽卡保底 / 可访问性单例）。
- **事件总线断言约定**：测试可 `EventBus` 连接临时监听（如 `func _on_currency_changed(...)`）验证广播；断言后 `disconnect`，避免跨用例污染。
- **性能回归**：T2/T7 可附带断言单帧 `BattleResolver` <4ms、`ConfigLoader` 加载 <200ms（架构 §1.9 触发线，越线提示下沉 GDExtension）。
- **命令**：
  ```bash
  godot --headless --path res:// \
    --script res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests -gexit -glog=1
  ```

---

【一句话总结】本测试策略与 `01-architecture.md` 的 EventBus/ConfigLoader/autoload 设计一致：以 GUT + 验证驱动 + `ConfigLoader` 假表注入（inject/reset + 种子化 RNG）落地 7 项优先测试（T1 经济闭环 / T2 五行克制 / T3 存档冲突 / T4 抽卡保底 / T5 可访问性 / T6 羁绊 / T7 养成最终式神），并给出 headless CI 调用命令与 T1–T5 合并必备门禁。
