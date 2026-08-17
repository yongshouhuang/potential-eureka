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

    // gacha:acquire_intent —— 符箓不足时 UI 发出的获取意图（去推图产出符箓，防核心循环断流）。
    // 由外部系统（导航层/推图屏）订阅接管，UI 不直接跳转场景（ADR-3 红线）。
    public sealed class GachaAcquireIntentEvent
    {
        public string Reason { get; set; } = "battle"; // "battle"=去推图产出符箓
    }

    // gacha:return_intent —— 占位推图屏"返回"按钮发出，导航层订阅后 Back() 回抽卡屏（ADR-3：UI 不直连导航）。
    public sealed class GachaReturnIntentEvent { }
}
