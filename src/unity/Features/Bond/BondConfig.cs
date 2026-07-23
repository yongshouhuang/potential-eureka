#nullable enable
using System.Collections.Generic;
using Newtonsoft.Json;

namespace XiaXia.Features.Bond
{
    // 牵绊升阶阈值：fragments_per_level[i] = 从 bond 级 i 升到 i+1 所需碎片数（1-based 索引）。
    // 例：[20,50,100]：0->1 需 20，1->2 需 50，2->3 需 100；最高 bond 级 = 列表长度 = 3。
    // 列表长度即「满级」，达到后 CostToNext 返回 -1、CanAwaken 恒 false。
    public sealed class BondConfig
    {
        [JsonProperty("fragments_per_level")]
        public List<int> FragmentsPerLevel { get; set; } = new List<int>();

        // 羁绊加成配置：shikigami_id -> 每级加成描述（可选，先基础值/空）。
        [JsonProperty("bond_bonuses")]
        public Dictionary<string, List<string>> BondBonuses { get; set; } = new Dictionary<string, List<string>>();

        // 升到 nextLevel（=当前 level+1）所需碎片；已满级返回 -1。
        public int CostToNext(int currentLevel)
        {
            if (currentLevel < 0 || currentLevel >= FragmentsPerLevel.Count) return -1;
            return FragmentsPerLevel[currentLevel];
        }

        // 满级等级（= 列表长度）。
        public int MaxLevel => FragmentsPerLevel.Count;
    }

    // 配置加载：从数据根读取 bond/bond_config.json。Newtonsoft 已在 M1 接入（同 ConfigLoader 依赖）。
    // 不依赖任何 manager；Bootstrapper 调用后把 BondConfig 注入 BondManager（test-seam 友好）。
    // 与 EconomyConfigLoader 同构：文件缺失/反序列化失败抛异常。
    public static class BondConfigLoader
    {
        private static readonly JsonSerializerSettings Options = new JsonSerializerSettings
        {
            MissingMemberHandling = MissingMemberHandling.Ignore,
        };

        // dataRoot 为 data/ 根目录（与 ConfigLoader 同约定，即 bond_config.json 位于 <dataRoot>/bond/）。
        // 返回强类型 BondConfig；文件缺失/反序列化失败抛异常（与 EconomyConfigLoader 行为一致）。
        public static BondConfig Load(string dataRoot)
        {
            var full = System.IO.Path.Combine(dataRoot, "bond", "bond_config.json");
            if (!System.IO.File.Exists(full))
                throw new System.IO.FileNotFoundException($"牵绊配置不存在：{full}", full);
            var json = System.IO.File.ReadAllText(full);
            return JsonConvert.DeserializeObject<BondConfig>(json, Options)
                   ?? throw new System.InvalidOperationException($"牵绊配置反序列化失败（null）：{full}");
        }
    }
}
