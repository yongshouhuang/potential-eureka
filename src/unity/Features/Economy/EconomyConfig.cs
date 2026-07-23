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

    // 配置加载：从数据根读取 economy/economy_config.json。Newtonsoft 已在 M1 接入（同 ConfigLoader 依赖）。
    // 不依赖任何 manager；Bootstrapper 调用后把 EconomyConfig 注入 EconomyManager（test-seam 友好）。
    // 注：未改动 M1 Core.ConfigLoader（沿用 GAP 绕开思路，对应 m2-plan DECISION-C）；如用户希望统一进
    //     ConfigLoader（加 LoadEconomyConfig），属「补 M1 收尾」，需先说明再改 Core。
    public static class EconomyConfigLoader
    {
        private static readonly JsonSerializerSettings Options = new JsonSerializerSettings
        {
            MissingMemberHandling = MissingMemberHandling.Ignore,
        };

        // dataRoot 为 data/ 根目录（与 ConfigLoader 同约定，即 economy_config.json 位于 <dataRoot>/economy/）。
        // 返回强类型 EconomyConfig；文件缺失/反序列化失败抛异常（与 ConfigLoader 行为一致）。
        public static EconomyConfig Load(string dataRoot)
        {
            var full = System.IO.Path.Combine(dataRoot, "economy", "economy_config.json");
            if (!System.IO.File.Exists(full))
                throw new System.IO.FileNotFoundException($"经济配置不存在：{full}", full);
            var json = System.IO.File.ReadAllText(full);
            return JsonConvert.DeserializeObject<EconomyConfig>(json, Options)
                   ?? throw new System.InvalidOperationException($"经济配置反序列化失败（null）：{full}");
        }
    }
}
