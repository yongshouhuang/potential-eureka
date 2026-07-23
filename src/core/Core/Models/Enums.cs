using Newtonsoft.Json;
using Newtonsoft.Json.Converters;

namespace XiaXia.Core.Models
{
    // 稀有度：与 shikigami_defs.json / gacha_pools.json 的 "N"/"R"/"SR"/"SSR" 对齐。
    [JsonConverter(typeof(StringEnumConverter))]
    public enum Rarity
    {
        N = 0,
        R = 1,
        SR = 2,
        SSR = 3,
    }

    // 五行元素：JSON 为小写（metal/wood/earth/water/fire），StringEnumConverter 读取时大小写不敏感。
    [JsonConverter(typeof(StringEnumConverter))]
    public enum Element
    {
        Metal = 0,
        Wood = 1,
        Earth = 2,
        Water = 3,
        Fire = 4,
    }
}
