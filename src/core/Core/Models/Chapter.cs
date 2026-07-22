using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace XiaXia.Core.Models
{
    // 章节与关卡（data/battle/chapters.json，顶层 { "chapters": [...] }）。
    public class ChapterDef
    {
        [JsonPropertyName("id")] public int Id { get; set; }
        [JsonPropertyName("name")] public string Name { get; set; } = string.Empty;
        [JsonPropertyName("stages")] public List<StageDef> Stages { get; set; } = new List<StageDef>();
    }

    public class StageDef
    {
        [JsonPropertyName("id")] public int Id { get; set; }
        [JsonPropertyName("boss")] public bool Boss { get; set; }
        [JsonPropertyName("enemies")] public List<EnemyDef> Enemies { get; set; } = new List<EnemyDef>();
        [JsonPropertyName("reward")] public Reward Reward { get; set; } = new Reward();
    }

    public class EnemyDef
    {
        [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
        [JsonPropertyName("name")] public string Name { get; set; } = string.Empty;
        [JsonPropertyName("element")] public Element Element { get; set; }
        [JsonPropertyName("stats")] public EnemyStats Stats { get; set; } = new EnemyStats();
    }

    public class EnemyStats
    {
        [JsonPropertyName("hp")] public int Hp { get; set; }
        [JsonPropertyName("atk")] public int Atk { get; set; }
    }

    public class Reward
    {
        // [min, max] 福禄区间。
        [JsonPropertyName("fu_lu")] public List<int> FuLu { get; set; } = new List<int>();
        [JsonPropertyName("po_dan")] public int PoDan { get; set; }
        [JsonPropertyName("jue_xing_shi")] public int JueXingShi { get; set; }
    }

    // 文件顶层容器： { "chapters": [ ChapterDef, ... ] }。
    public class ChaptersFile
    {
        [JsonPropertyName("chapters")] public List<ChapterDef> Chapters { get; set; } = new List<ChapterDef>();
    }
}
