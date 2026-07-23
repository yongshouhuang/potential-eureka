using UnityEngine;
using XiaXia.Core;
using System.IO;

/// <summary>
/// M1 地基冒烟测试：挂到任意空 GameObject 上，进入 Play Mode 后在 Console 看 [Core] 日志。
/// 仅用于验证 Core 层在团结引擎 1.9.3 里能编译 + 能加载 data/ 数据。不参与游戏逻辑。
/// 注意：本文件依赖 UnityEngine，必须放在 Core 程序集之外（默认程序集即可），不要放进 Assets/Scripts/Core/。
/// </summary>
public class CoreSmokeTest : MonoBehaviour
{
    void Start()
    {
        // 把仓库根的 data/ 复制到 Unity 工程根目录（Assets 同级）后，这条路径才有效。
        string dataRoot = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "data"));
        Debug.Log($"[Core] dataRoot = {dataRoot} | 目录存在 = {Directory.Exists(dataRoot)}");

        if (!Directory.Exists(dataRoot))
        {
            Debug.LogError("[Core] ❌ 找不到 data/ 目录。请先把仓库的 data/ 复制到 Unity 工程根目录（Assets 同级）。");
            return;
        }

        try
        {
            var loader = new ConfigLoader(dataRoot);

            var shikigami = loader.LoadShikigamiDefs();
            Debug.Log($"[Core] ✅ 式神数 = {shikigami.Count} （期望 13）");

            var skills = loader.LoadSkillDefs();
            Debug.Log($"[Core] ✅ 技能数 = {skills.Count}");

            var pools = loader.LoadGachaPools();
            Debug.Log($"[Core] ✅ 抽卡卡池数 = {pools.Count}");

            var cult = loader.LoadCultivationConfig();
            Debug.Log($"[Core] ✅ 养成配置已加载（{(cult != null ? "非 null" : "为 null")}）");

            var ui = loader.LoadBattleUIConstants();
            Debug.Log($"[Core] ✅ 战斗 UI 常量已加载（{(ui != null ? "非 null" : "为 null")}）");

            var chapters = loader.LoadChapters();
            Debug.Log($"[Core] ✅ 章节数 = {chapters.Count} （期望 3）");

            Debug.Log(chapters.Count == 3 && shikigami.Count == 13
                ? "[Core] 🎉 地基在团结引擎 1.9.3 验证通过！"
                : "[Core] ⚠️ 数据量与预期不符，请检查 data/ 或 ConfigLoader。");
        }
        catch (System.Exception ex)
        {
            Debug.LogError($"[Core] ❌ 加载失败：{ex.GetType().Name}: {ex.Message}");
        }
    }
}
