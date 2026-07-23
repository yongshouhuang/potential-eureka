#nullable enable
using System.Collections.Generic;
using Newtonsoft.Json;

namespace XiaXia.Features.Economy
{
    // 货币定义（data/economy/economy_config.json → currencies.<id>）。
    // 用可空 int 表示「上限是否存在」：对齐 Godot 的 cfg.has("daily_cap") 语义（缺省 = 无上限）；
    // 若用普通 int 默认 0，会与「上限=0（完全禁止产出）」混淆，故以 null 区分有无。
    public sealed class CurrencyDef
    {
        [JsonProperty("daily_soft_cap")] public int? DailySoftCap { get; set; }
        [JsonProperty("daily_cap")]      public int? DailyCap { get; set; }
        [JsonProperty("weekly_cap")]     public int? WeeklyCap { get; set; }
        // hard：仅元数据（商城货币）；本切片代码不强制拦截（对齐 Godot，见 m2-plan 待拍板）。
        [JsonProperty("hard")]           public bool Hard { get; set; }
        // boss_only：仅 "Boss" 来源可产出（觉醒石）。
        [JsonProperty("boss_only")]      public bool BossOnly { get; set; }
    }

    // 免费十连额度配置（data/economy → free_ten_pull.amount）。
    public sealed class FreeTenPullConfig
    {
        [JsonProperty("amount")] public int Amount { get; set; } = 10;
    }

    // 经济配置顶层（对齐 Godot EconomyManager._econ()）。
    public sealed class EconomyConfig
    {
        [JsonProperty("currencies")]    public Dictionary<string, CurrencyDef> Currencies { get; set; } = new();
        [JsonProperty("free_ten_pull")] public FreeTenPullConfig FreeTenPull { get; set; } = new();
        [JsonProperty("sources")]       public Dictionary<string, List<string>> Sources { get; set; } = new();
    }
}
