using System.Collections.Generic;
using Newtonsoft.Json;

namespace XiaXia.Core.Models
{
    // 章节与关卡（data/battle/chapters.json，顶层 { "chapters": [...] }）。
    public class ChapterDef
    {
        [JsonProperty("id")] public int Id { get; set; }
        [JsonProperty("name")] public string Name { get; set; } = string.Empty;
        [JsonProperty("stages")] public List<StageDef> Stages { get; set; } = new List<StageDef>();
    }

    public class StageDef
    {
        [JsonProperty("id")] public int Id { get; set; }
        [JsonProperty("boss")] public bool Boss { get; set; }
        [JsonProperty("enemies")] public List<EnemyDef> Enemies { get; set; } = new List<EnemyDef>();
        [JsonProperty("reward")] public Reward Reward { get; set; } = new Reward();
    }

    public class EnemyDef
    {
        [JsonProperty("id")] public string Id { get; set; } = string.Empty;
        [JsonProperty("name")] public string Name { get; set; } = string.Empty;
        [JsonProperty("element")] public Element Element { get; set; }
        [JsonProperty("stats")] public EnemyStats Stats { get; set; } = new EnemyStats();
    }

    public class EnemyStats
    {
        [JsonProperty("hp")] public int Hp { get; set; }
        [JsonProperty("atk")] public int Atk { get; set; }
    }

    public class Reward
    {
        // [min, max] 福禄区间。
        [JsonProperty("fu_lu")] public List<int> FuLu { get; set; } = new List<int>();
        [JsonProperty("po_dan")] public int PoDan { get; set; }
        [JsonProperty("jue_xing_shi")] public int JueXingShi { get; set; }
    }

    // 文件顶层容器： { "chapters": [ ChapterDef, ... ] }。
    public class ChaptersFile
    {
        [JsonProperty("chapters")] public List<ChapterDef> Chapters { get; set; } = new List<ChapterDef>();
    }
}
