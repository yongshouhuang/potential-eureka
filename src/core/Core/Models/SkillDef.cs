#nullable enable
using System.Collections.Generic;
using Newtonsoft.Json;

namespace XiaXia.Core.Models
{
    // 技能定义（data/battle/skill_defs.json 中每个技能的字段）。
    // power 取代硬编码 1.0；status_on_hit 承载觉醒改写机制，可为 null。
    public class SkillDef
    {
        [JsonProperty("element")] public Element Element { get; set; }
        [JsonProperty("power")] public double Power { get; set; }
        [JsonProperty("status_on_hit")] public StatusOnHit? StatusOnHit { get; set; }
    }

    // 命中附加状态（觉醒技能才有，基础技能为 null）。
    public class StatusOnHit
    {
        [JsonProperty("type")] public string Type { get; set; } = string.Empty;
        [JsonProperty("stacks")] public int Stacks { get; set; }
        [JsonProperty("duration")] public int Duration { get; set; }
    }

    // 文件顶层容器： { "skills": { id: SkillDef, ... } }。
    public class SkillDefsFile
    {
        [JsonProperty("skills")] public Dictionary<string, SkillDef> Skills { get; set; }
            = new Dictionary<string, SkillDef>();
    }
}
