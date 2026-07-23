# CLAUDE.md — 仙侠卡牌项目（Xianxia Card Battler）

## 引擎与语言
- **生产引擎（M3+）**：团结引擎 1.9.3（Unity 2022 LTS 兼容，UGUI 技术栈），目标平台 **Android（IL2CPP 后端）**。具体小版本钉定于此，开工前以此为准。M3「抽卡表现与 UI」落地于该引擎，代码位于 `src/unity/` 与镜像 `unity/My project/Assets/Scripts/`。
- **原型引擎（S1 参考）**：Godot 4.3 LTS（2D-first，GDScript）——S1 经济/抽卡闭环原型，保留作参考，架构约束 §S1 仍适用。
- **语言**：C# 为主（UGUI 脚本；热路径可下沉 Burst/JobSystem）。S1 原型用 GDScript。

## 架构硬约束（S1 已落地并校验）
1. **管理器只经 EventBus / GameState / ConfigLoader / 全局 autoload 名通信**；禁止 `preload`/`const X = preload(...)` 跨管理器 import（无代码级环）。
2. **禁止硬编码十六进制色值**：颜色一律经 `UIThemeController` 的 `COLOR_*` 常量或 Theme 资源。
3. **数据驱动**：配置经 `ConfigLoader.load_table(id, fallback)` 取；测试用 `ConfigLoader.inject(id, data)` + `reset()` 注入假表。
4. **存档 schema v1 冻结**：含 `free_ten_pull` 解耦、`pity` 不跨池、checksum。
5. **种子化 RNG**：所有随机路径经 `scripts/utils/rng.gd`（`RNGWrapper`）封装，测试可复现。

## 目录
- `src/unity/Features/` M3 生产代码（C#，asmdef 分核心/玩法/UI/音频；含 UGUI 抽卡屏切片）
- `unity/My project/` 团结引擎 1.9.3 工程镜像（`src/unity/` 的同步目标，编辑器内运行/测试处）
- `scripts/autoload/` 单例（Godot S1 原型：EventBus/GameState/ConfigLoader/AccessibilitySettings/UIThemeController/InputBridge/SaveManager/CloudSaveService/EconomyManager/GachaManager）
- `scripts/utils/` 工具（RNG 封装）
- `data/economy/`、`data/gacha/` 配置（JSON，经 ConfigLoader 加载）
- `tests/` GUT 测试（`test_*.gd`，`extends GutTest`）
- `addons/gut/` GUT 测试框架（由用户安装；未就位时测试无法运行，但语法/逻辑完整）

## 测试（GUT，验证驱动）
- headless CI：`godot --headless --path res:// --script res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit -glog=1`
- S1 门禁：T1 经济闭环 / T4 抽卡保底 / T3 存档冲突（T1–T5 合并必备，E6-S5 单例测试为额外保障）
