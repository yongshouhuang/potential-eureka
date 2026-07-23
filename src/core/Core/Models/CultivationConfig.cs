using System.Collections.Generic;
using Newtonsoft.Json;

namespace XiaXia.Core.Models
{
    // 养成配置（data/cultivation/cultivation_config.json，顶层即本对象）。
    public class CultivationConfig
    {
        [JsonProperty("breakthrough")] public Breakthrough Breakthrough { get; set; } = new Breakthrough();
        [JsonProperty("level_curve")] public LevelCurve LevelCurve { get; set; } = new LevelCurve();
        [JsonProperty("upgrade")] public Upgrade Upgrade { get; set; } = new Upgrade();
        [JsonProperty("breakthrough_cost")] public BreakthroughCost BreakthroughCost { get; set; } = new BreakthroughCost();
        [JsonProperty("awaken")] public Awaken Awaken { get; set; } = new Awaken();
        // 分支（剑修/体修），key 为 "sword"/"body"。
        [JsonProperty("branches")] public Dictionary<string, Branch> Branches { get; set; }
            = new Dictionary<string, Branch>();
    }

    public class Breakthrough
    {
        // 每阶等级上限，索引即 tier（0 基）。
        [JsonProperty("level_cap_per_tier")] public List<int> LevelCapPerTier { get; set; } = new List<int>();
        [JsonProperty("attr_gain_pct_min")] public double AttrGainPctMin { get; set; }
        [JsonProperty("attr_gain_pct_max")] public double AttrGainPctMax { get; set; }
        [JsonProperty("passive_slots_per_tier")] public List<int> PassiveSlotsPerTier { get; set; } = new List<int>();
    }

    public class LevelCurve
    {
        [JsonProperty("hp_per_level_pct_min")] public double HpPerLevelPctMin { get; set; }
        [JsonProperty("hp_per_level_pct_max")] public double HpPerLevelPctMax { get; set; }
        [JsonProperty("atk_per_level_pct_min")] public double AtkPerLevelPctMin { get; set; }
        [JsonProperty("atk_per_level_pct_max")] public double AtkPerLevelPctMax { get; set; }
    }

    public class Upgrade
    {
        [JsonProperty("ling_qi_per_level")] public int LingQiPerLevel { get; set; }
    }

    public class BreakthroughCost
    {
        [JsonProperty("po_dan_per_tier")] public int PoDanPerTier { get; set; }
        [JsonProperty("fragments_per_tier")] public int FragmentsPerTier { get; set; }
    }

    public class Awaken
    {
        [JsonProperty("tier_threshold")] public int TierThreshold { get; set; }
        // 式神 id -> 觉醒技能 id 映射。
        [JsonProperty("skills_by_shikigami")] public Dictionary<string, string> SkillsByShikigami { get; set; }
            = new Dictionary<string, string>();
    }

    public class Branch
    {
        [JsonProperty("passive")] public string Passive { get; set; } = string.Empty;
        [JsonProperty("name")] public string Name { get; set; } = string.Empty;
        [JsonProperty("dmg_mult")] public double DmgMult { get; set; }   // 剑修
        [JsonProperty("hp_mult")] public double HpMult { get; set; }    // 体修
    }
}
