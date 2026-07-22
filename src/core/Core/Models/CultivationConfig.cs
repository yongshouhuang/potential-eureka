using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace XiaXia.Core.Models
{
    // 养成配置（data/cultivation/cultivation_config.json，顶层即本对象）。
    public class CultivationConfig
    {
        [JsonPropertyName("breakthrough")] public Breakthrough Breakthrough { get; set; } = new Breakthrough();
        [JsonPropertyName("level_curve")] public LevelCurve LevelCurve { get; set; } = new LevelCurve();
        [JsonPropertyName("upgrade")] public Upgrade Upgrade { get; set; } = new Upgrade();
        [JsonPropertyName("breakthrough_cost")] public BreakthroughCost BreakthroughCost { get; set; } = new BreakthroughCost();
        [JsonPropertyName("awaken")] public Awaken Awaken { get; set; } = new Awaken();
        // 分支（剑修/体修），key 为 "sword"/"body"。
        [JsonPropertyName("branches")] public Dictionary<string, Branch> Branches { get; set; }
            = new Dictionary<string, Branch>();
    }

    public class Breakthrough
    {
        // 每阶等级上限，索引即 tier（0 基）。
        [JsonPropertyName("level_cap_per_tier")] public List<int> LevelCapPerTier { get; set; } = new List<int>();
        [JsonPropertyName("attr_gain_pct_min")] public double AttrGainPctMin { get; set; }
        [JsonPropertyName("attr_gain_pct_max")] public double AttrGainPctMax { get; set; }
        [JsonPropertyName("passive_slots_per_tier")] public List<int> PassiveSlotsPerTier { get; set; } = new List<int>();
    }

    public class LevelCurve
    {
        [JsonPropertyName("hp_per_level_pct_min")] public double HpPerLevelPctMin { get; set; }
        [JsonPropertyName("hp_per_level_pct_max")] public double HpPerLevelPctMax { get; set; }
        [JsonPropertyName("atk_per_level_pct_min")] public double AtkPerLevelPctMin { get; set; }
        [JsonPropertyName("atk_per_level_pct_max")] public double AtkPerLevelPctMax { get; set; }
    }

    public class Upgrade
    {
        [JsonPropertyName("ling_qi_per_level")] public int LingQiPerLevel { get; set; }
    }

    public class BreakthroughCost
    {
        [JsonPropertyName("po_dan_per_tier")] public int PoDanPerTier { get; set; }
        [JsonPropertyName("fragments_per_tier")] public int FragmentsPerTier { get; set; }
    }

    public class Awaken
    {
        [JsonPropertyName("tier_threshold")] public int TierThreshold { get; set; }
        // 式神 id -> 觉醒技能 id 映射。
        [JsonPropertyName("skills_by_shikigami")] public Dictionary<string, string> SkillsByShikigami { get; set; }
            = new Dictionary<string, string>();
    }

    public class Branch
    {
        [JsonPropertyName("passive")] public string Passive { get; set; } = string.Empty;
        [JsonPropertyName("name")] public string Name { get; set; } = string.Empty;
        [JsonPropertyName("dmg_mult")] public double DmgMult { get; set; }   // 剑修
        [JsonPropertyName("hp_mult")] public double HpMult { get; set; }    // 体修
    }
}
