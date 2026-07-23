#nullable enable
using XiaXia.Core.Models;

namespace XiaXia.Features.Shared.Events
{
    // gacha:shikigami_obtained —— 抽到式神广播。
    // UI / 遥测仅订阅本事件，不 import GachaManager（ADR-3 红线：解耦）。
    public sealed class GachaShikigamiObtainedEvent
    {
        public string ShikigamiId { get; set; } = string.Empty;
        public Rarity Rarity { get; set; }
        public string PoolId { get; set; } = string.Empty;
    }

    // telemetry:gacha_pulled —— 抽阶段漏斗事件（TelemetryAggregator 订阅，E5-S3）。
    // 与 gacha_shikigami_obtained 同源 emit，但语义归遥测通道，便于聚合器仅经事件串联「抽→养→战→回流」。
    public sealed class TelemetryGachaPulledEvent
    {
        public string ShikigamiId { get; set; } = string.Empty;
        public Rarity Rarity { get; set; }
        public string PoolId { get; set; } = string.Empty;
    }
}
