using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace XiaXia.Core.Models
{
    // 式神基础信息（data/shikigami/shikigami_defs.json 中每个式神的字段）。
    public class ShikigamiDef
    {
        [JsonPropertyName("name")] public string Name { get; set; } = string.Empty;
        [JsonPropertyName("element")] public Element Element { get; set; }
        [JsonPropertyName("rarity")] public Rarity Rarity { get; set; }
        [JsonPropertyName("bond_tags")] public List<string> BondTags { get; set; } = new List<string>();
        [JsonPropertyName("base_stats")] public BaseStats BaseStats { get; set; } = new BaseStats();
        [JsonPropertyName("skills")] public List<string> Skills { get; set; } = new List<string>();
    }

    // 基础属性 hp / atk。
    public class BaseStats
    {
        [JsonPropertyName("hp")] public int Hp { get; set; }
        [JsonPropertyName("atk")] public int Atk { get; set; }
    }

    // 文件顶层容器： { "shikigami": { id: ShikigamiDef, ... } }。
    public class ShikigamiDefsFile
    {
        [JsonPropertyName("shikigami")] public Dictionary<string, ShikigamiDef> Shikigami { get; set; }
            = new Dictionary<string, ShikigamiDef>();
    }
}
