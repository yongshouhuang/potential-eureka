using System.Collections.Generic;
using Newtonsoft.Json;

namespace XiaXia.Core.Models
{
    // 式神基础信息（data/shikigami/shikigami_defs.json 中每个式神的字段）。
    public class ShikigamiDef
    {
        [JsonProperty("name")] public string Name { get; set; } = string.Empty;
        [JsonProperty("element")] public Element Element { get; set; }
        [JsonProperty("rarity")] public Rarity Rarity { get; set; }
        [JsonProperty("bond_tags")] public List<string> BondTags { get; set; } = new List<string>();
        [JsonProperty("base_stats")] public BaseStats BaseStats { get; set; } = new BaseStats();
        [JsonProperty("skills")] public List<string> Skills { get; set; } = new List<string>();
    }

    // 基础属性 hp / atk。
    public class BaseStats
    {
        [JsonProperty("hp")] public int Hp { get; set; }
        [JsonProperty("atk")] public int Atk { get; set; }
    }

    // 文件顶层容器： { "shikigami": { id: ShikigamiDef, ... } }。
    public class ShikigamiDefsFile
    {
        [JsonProperty("shikigami")] public Dictionary<string, ShikigamiDef> Shikigami { get; set; }
            = new Dictionary<string, ShikigamiDef>();
    }
}
