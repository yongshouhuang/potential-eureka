# M2 垂直切片 + M1 重构收口 · 仙侠卡牌项目

## 状态
**日期**：2026-07-23  
**真机验证**：团结引擎 1.9.3（Unity 2022.3 中国版）EditMode Test Runner  **30/30 全绿**  
**质量门**：PASS

## M2 三切片完成情况

| 切片 | 程序集 | 测试数 | 关键交付 |
|------|--------|--------|----------|
| Gacha | XiaXia.Features.Gacha + .Tests | 7/7 | GachaManager / GachaRollEngine、红线自检、扣费闭环 |
| Economy | XiaXia.Features.Economy + .Tests | 16/16 | EconomyManager、ProductionBudget、日/周上限、Boss-only、免费十连豁免、Gacha 扣费闭环 |
| Bond | XiaXia.Features.Bond + .Tests | 7/7 | BondManager、碎片合成/升阶、BondConfig、红线自检 |

## 关键决策与修复
- **引擎**：由 Unity 6 LTS 改为 **团结引擎 1.9.3**（Unity 2022.3 中国版）。
- **JSON 库**：System.Text.Json → **Newtonsoft.Json**（国内镜像缺 System.Text.Json 包）。
- **红线合规**：Gacha / Economy / Bond 三 manager 之间零字段硬引用，跨系统通信经 EventBus + ServiceRegistry 在调用点 `TryResolve<>`。
- **真机验证修复**：
  - Economy `ProductionBudget` 的 `PeriodKey` / `CanGrant` / `ResolveCap` 参数加 `CurrencyDef?` 消除 CS8604 warning。
  - `ResetDailyIfNeeded` / `ResetWeeklyIfNeeded` 改为先快照 `Keys` 再遍历，避免 `foreach` 枚举期修改 Dictionary 的未定义行为。
  - 补全 `ResetWeeklyCap_ProductionTracker` 测试。
- **M1 重构（DECISION-C / DECISION-D）已落地**：
  - C：`ConfigLoader` 新增 `LoadConfig<T>`，Economy/Bond 配置加载统一入口；删除 `EconomyConfigLoader` / `BondConfigLoader`。
  - D：`PlayerProfile` 迁入 `Core.Models`，`GameState` 组合持有 `Profile`。

## 版本基线

| 标签 | Commit | 说明 |
|------|--------|------|
| v0.3.0 | `6c21322` | M2 三切片（Gacha/Economy/Bond）真机验证 30/30 全绿 |
| v0.3.1 | `7250526` | M1 重构收口：ConfigLoader 统一配置 + PlayerProfile 进 Core.GameState；Unity 30/30 验证 |

## 推送结果
- ✅ commit `6c21322`（M2 收口）已推送：`main -> main`
- ✅ tag `v0.3.0` 已推送
- ✅ commit `7250526`（M1 重构）已推送：`main -> main`
- ✅ tag `v0.3.1` 已推送
- ✅ GitHub 基线 `potential-eureka` 正式建立，本地与远程一致

## 下一步（M3 可选项）
当前 M1/M2 已完全收口。可继续：
- **A. 抽卡表现与 UI**：卡池界面、抽卡动画、结果展示（技术+美术并行）。
- **B. 战斗/关卡循环**：回合制战斗、章节推进、PVE 流程。
- **C. 存档 / Save-Load**：序列化 `PlayerProfile`、本地存档、云同步备份。
- **D. 先休整**，整理文档或 GDD 完整性检查。

推荐 **A**（抽卡表现直接承接 M2 Gacha 切片），你选哪个方向？
