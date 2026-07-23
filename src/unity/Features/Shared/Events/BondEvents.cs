#nullable enable

namespace XiaXia.Features.Shared.Events
{
    // bond:level_up —— 式神牵绊升阶广播（UI/遥测订阅）。
    // 由 BondManager 在 Awaken 成功后 emit；消费方只订阅，不引用 BondManager（ADR-3 红线）。
    public sealed class BondLevelUpEvent
    {
        public string ShikigamiId { get; set; } = string.Empty;
        public int NewLevel { get; set; }
    }
}
