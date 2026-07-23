#nullable enable

namespace XiaXia.Features.Shared.Events
{
    // economy:currency_changed —— 货币余额变化广播（UI/遥测订阅）。
    // 由 EconomyManager 在 grant/spend 成功后 emit；消费方只订阅，不引用 EconomyManager。
    public sealed class EconomyCurrencyChangedEvent
    {
        public string Currency { get; set; } = string.Empty;
        public int Amount { get; set; } // 正=增加，负=扣减
    }

    // economy:reward_granted —— 奖励发放（带 sink 来源）广播。
    public sealed class EconomyRewardGrantedEvent
    {
        public string Currency { get; set; } = string.Empty;
        public int Amount { get; set; }
        public string Sink { get; set; } = string.Empty;
    }
}
