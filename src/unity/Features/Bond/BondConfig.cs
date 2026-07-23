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
}
