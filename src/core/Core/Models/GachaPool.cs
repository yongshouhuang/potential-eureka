using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace XiaXia.Core.Models
{
    // 抽卡池（data/gacha/gacha_pools.json 中每个池的字段）。
    public class GachaPool
    {
        [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
        [JsonPropertyName("type")] public string Type { get; set; } = string.Empty;
        [JsonPropertyName("rarity_rates")] public RarityRates RarityRates { get; set; } = new RarityRates();
        [JsonPropertyName("soft_pity")] public int SoftPity { get; set; }
        [JsonPropertyName("hard_pity")] public int HardPity { get; set; }
        // 仅新手池 newbie 含此字段，标准池为 null。
        [JsonPropertyName("starter_sr_id")] public string? StarterSrId { get; set; }
        // 各稀有度对应的式神列表（key 为 "SSR"/"SR"/"R"/"N"）。
        [JsonPropertyName("shikigami_by_rarity")] public Dictionary<string, List<string>> ShikigamiByRarity { get; set; }
            = new Dictionary<string, List<string>>();
    }

    // 各稀有度概率，key 与 JSON 严格一致（SSR/SR/R/N）。
    public class RarityRates
    {
        [JsonPropertyName("SSR")] public double SSR { get; set; }
        [JsonPropertyName("SR")] public double SR { get; set; }
        [JsonPropertyName("R")] public double R { get; set; }
        [JsonPropertyName("N")] public double N { get; set; }
    }

    // 文件顶层容器： { "pools": { id: GachaPool, ... } }。
    public class GachaPoolsFile
    {
        [JsonPropertyName("pools")] public Dictionary<string, GachaPool> Pools { get; set; }
            = new Dictionary<string, GachaPool>();
    }
}
