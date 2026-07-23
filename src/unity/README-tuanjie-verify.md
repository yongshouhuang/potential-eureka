# M1 地基验证 · 团结引擎 1.9.3（Unity 2022.3 LTS 中国版）导入流程

> 目标：把 `src/core/Core/`（引擎无关数据层 + 解耦基建）导进团结引擎 1.9.3，
> 确认能在真引擎里**编译通过**并**加载 data/ 数据**。游戏画面/玩法此时仍为 0，那是 M2 的活。

---

## 0. 前置确认（你机器上）

- 团结引擎 Hub 里 **团结引擎 1.9.3** 已安装。
- 若没装这些模块，在 Hub 的「安装」页面对 1.9.3 点 **添加模块**（或右键 → 添加模块）：
  - ✅ **2D URP**
  - ✅ **Android 构建支持**（仅 Android 决策需要，M1 验证可暂不装）
  - ✅ **Android SDK & NDK Tools**、**OpenJDK**（M1 验证可暂不装）

---

## 1. 新建工程

1. 团结 Hub → **项目** → **新建项目**。
2. 模板选 **2D (URP)**。
3. 工程名例如 `XiaXia`，选好本地路径 → **创建**。
4. 等工程打开、编译完成（右下角转圈结束、Console 无红字）。

---

## 2. 复制 Core 层

把仓库里的 **整个** `src/core/Core/` 文件夹复制到 Unity 工程：

```
仓库 src/core/Core/   ──►   Unity工程/Assets/Scripts/Core/
```

复制后 `Assets/Scripts/Core/` 里应包含：`Core.asmdef`、`ConfigLoader.cs`、
`EventBus.cs`、`ServiceRegistry.cs`、`GameState.cs`、`IService.cs`、
`Models/`（各模型 .cs）。

> ⚠️ **不要**复制 `src/core/Core.Tests/` 和 `src/core/Core.csproj` ——
> 那是 .NET 8 独立测试工程，放进 Unity 会与 asmdef 冲突。

---

## 3. 复制数据

把仓库根的 **整个** `data/` 文件夹复制到 Unity 工程根目录（`Assets` 同级）：

```
仓库 data/   ──►   Unity工程/data/
```

即 `Unity工程/data/shikigami/...`、`Unity工程/data/battle/...` 等。
冒烟脚本会用 `Application.dataPath/../data` 找它。

---

## 4. ⚠️ 关键：安装 Newtonsoft.Json 包（最容易漏）

`ConfigLoader` 用了 `Newtonsoft.Json`，而团结 1.9.3 默认**不带**这个库，
不装会编译报 `类型或命名空间 "JsonConvert" 找不到`。

1. 团结编辑器顶部菜单 → **窗口 / Window** → **包管理器 / Package Manager**。
2. 左上角 **+** → **通过名称添加包 / Add package by name**。
3. 输入：`com.unity.nuget.newtonsoft-json` → **添加 / Add**。
4. 等下载完成，Console 无红字即成功。

> 如果 `Core` 程序集编译时报「找不到 Newtonsoft.Json」，多半是该包未自动引用到 asmdef。
> 打开 `Assets/Scripts/Core/Core.asmdef`，在 `references` 数组里加上 `"Newtonsoft.Json"` 即可：
> `"references": [ "Newtonsoft.Json" ]`

---

## 5. 复制冒烟脚本

把 `src/unity/CoreSmokeTest.cs` 复制到 Unity 工程的 `Assets/Scripts/`（**默认程序集**，不要放进 `Core/`）：

```
src/unity/CoreSmokeTest.cs   ──►   Unity工程/Assets/Scripts/CoreSmokeTest.cs
```

它会自动引用 `XiaXia.Core`（Core.asmdef 的 `autoReferenced` 默认开启）。

---

## 6. 运行验证

1. Hierarchy 里 **右键 → 创建空对象 / Create Empty**，重命名为 `CoreSmoke`。
2. 把 `CoreSmokeTest` 组件拖到该对象上（或 Add Component 搜 `CoreSmokeTest`）。
3. 点 **播放 / Play**。
4. 打开 **Console**（窗口/Window → 常规/General → Console），看日志：

```
[Core] dataRoot = ... | 目录存在 = True
[Core] ✅ 式神数 = 13 （期望 13）
[Core] ✅ 技能数 = ...
[Core] ✅ 抽卡卡池数 = ...
[Core] ✅ 养成配置已加载 ...
[Core] ✅ 战斗 UI 常量已加载 ...
[Core] ✅ 章节数 = 3 （期望 3）
[Core] 🎉 地基在团结引擎 1.9.3 验证通过！
```

---

## 7. 判读

- **全绿 + 🎉**：M1 在真引擎验证通过。把结果贴我，我们开 **M2（核心逻辑端口）**。
- **编译红字 CSxxxx**：把报错贴我，我改 `src/core/Core/` 对应文件（你不用碰 C#）。
- **运行时 ❌ 找不到 data/**：确认第 3 步 `data/` 在 `Assets` 同级。
- **JsonConvert 找不到**：回到第 4 步确认 `com.unity.nuget.newtonsoft-json` 已装；若 Core 仍报找不到 Newtonsoft.Json，按第 4 步末尾给 `Core.asmdef` 加 `"Newtonsoft.Json"` 引用。

---

## 备注：Android 真机（IL2CPP/AOT）的 JSON 问题

上面是 **Editor（Mono）** 验证，足够 M1。Newtonsoft.Json 在 Android 真机（IL2CPP/AOT）下通常也能工作，
但若届时遇到 AOT 链接裁剪把序列化类型剔掉，可在 `link.xml` 里保留 `Newtonsoft.Json` 与模型程序集，
或把 `ConfigLoader` 内部换成 `JsonUtility`，**对外 `LoadXxx()` 方法签名不变**，调用方无感。本阶段先不管。
