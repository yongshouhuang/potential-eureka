using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using XiaXia.Core.Models;

namespace XiaXia.Core
{
    // 配置加载器：从可配置 base path 读取 JSON，返回强类型模型。
    // 不依赖任何引擎 API（无 UnityEngine），可在 .NET 8 与 Unity 6（netstandard2.1）下使用。
    public sealed class ConfigLoader
    {
        // 统一反序列化选项：忽略未知字段（如各文件的 _doc）、跳过注释、容忍尾逗号。
        private static readonly JsonSerializerOptions Options = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            ReadCommentHandling = JsonCommentHandling.Skip,
            AllowTrailingCommas = true,
        };

        private readonly string _basePath;

        // basePath 为包含 shikigami/、skill/、gacha/、cultivation/、battle/ 子目录的数据根目录。
        public ConfigLoader(string basePath)
        {
            _basePath = basePath ?? throw new ArgumentNullException(nameof(basePath));
        }

        // 解析数据根目录：优先环境变量 XIA_CORE_DATA；其次从运行目录向上尝试若干相对候选；
        // 最后兜底返回最深的相对候选（便于错误提示）。返回的路径下应存在 shikigami/shikigami_defs.json。
        public static string ResolveDataBasePath()
        {
            var env = Environment.GetEnvironmentVariable("XIA_CORE_DATA");
            if (!string.IsNullOrEmpty(env) && Directory.Exists(env)) return env;

            var candidates = new List<string>
            {
                Path.Combine(AppContext.BaseDirectory, "data"),
                Path.Combine(AppContext.BaseDirectory, "..", "data"),
                Path.Combine(AppContext.BaseDirectory, "..", "..", "data"),
                Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "data"),
                Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "data"),
                Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "data"),
                Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "..", "data"),
                Path.Combine(Environment.CurrentDirectory, "data"),
                Path.Combine(Environment.CurrentDirectory, "..", "..", "..", "data"),
                Path.Combine(Environment.CurrentDirectory, "..", "..", "..", "..", "data"),
                Path.Combine(Environment.CurrentDirectory, "..", "..", "..", "..", "..", "data"),
            };

            foreach (var c in candidates)
            {
                try
                {
                    var full = Path.GetFullPath(c);
                    if (Directory.Exists(full) &&
                        File.Exists(Path.Combine(full, "shikigami", "shikigami_defs.json")))
                        return full;
                }
                catch
                {
                    // 忽略非法路径，继续尝试下一个候选。
                }
            }

            // 兜底：最深的相对候选（对应仓库根 data/）。若仍失败，错误信息会提示设置 XIA_CORE_DATA。
            return Path.GetFullPath(candidates[6]);
        }

        private T LoadFile<T>(string relativePath)
        {
            var full = Path.Combine(_basePath, relativePath);
            if (!File.Exists(full))
                throw new FileNotFoundException($"配置文件不存在：{full}", full);
            var json = File.ReadAllText(full);
            return JsonSerializer.Deserialize<T>(json, Options)
                   ?? throw new InvalidOperationException($"反序列化失败（结果为 null）：{full}");
        }

        // data/shikigami/shikigami_defs.json -> id -> ShikigamiDef。
        public Dictionary<string, ShikigamiDef> LoadShikigamiDefs() =>
            LoadFile<ShikigamiDefsFile>("shikigami/shikigami_defs.json").Shikigami;

        // data/battle/skill_defs.json -> id -> SkillDef。（注意真实路径在 battle/ 下）
        public Dictionary<string, SkillDef> LoadSkillDefs() =>
            LoadFile<SkillDefsFile>("battle/skill_defs.json").Skills;

        // data/gacha/gacha_pools.json -> id -> GachaPool。
        public Dictionary<string, GachaPool> LoadGachaPools() =>
            LoadFile<GachaPoolsFile>("gacha/gacha_pools.json").Pools;

        // data/cultivation/cultivation_config.json -> CultivationConfig。
        public CultivationConfig LoadCultivationConfig() =>
            LoadFile<CultivationConfig>("cultivation/cultivation_config.json");

        // data/battle/battle_ui_constants.json -> BattleUIConstants。
        public BattleUIConstants LoadBattleUIConstants() =>
            LoadFile<BattleUIConstants>("battle/battle_ui_constants.json");

        // data/battle/chapters.json -> List<ChapterDef>。
        public List<ChapterDef> LoadChapters() =>
            LoadFile<ChaptersFile>("battle/chapters.json").Chapters;
    }
}
