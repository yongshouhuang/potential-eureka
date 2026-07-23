#nullable enable
using System.Collections.Generic;
using XiaXia.Core.Models;

namespace XiaXia.Features.Shared
{
    // 抽卡服务契约（B2 / E2）。由 GachaManager 实现并注册到 ServiceRegistry。
    // UI / 其它系统经本接口调用抽卡，不直接引用 GachaManager 具体类（红线）。
    public interface IGachaService
    {
        // 对外抽卡入口：消耗符箓 -> Roll -> 写 PlayerProfile.shikigami -> 广播。
        // 余额不足提前结束，返回已产出的结果。
        IReadOnlyList<GachaResult> Pull(string poolId, int count = 1);

        // 纯逻辑 Roll（不消耗、不广播）——供单测保底确定性使用。
        GachaResult RollOnce(string poolId);

        // 概率公示数据（E2-S5 双端展示用；渲染是 UI 职责）。
        IReadOnlyDictionary<string, double> GetProbabilities(string poolId);

        // 当前保底计数（不跨池）。
        int GetPity(string poolId);
    }

    // 单次抽卡结果（纯数据，经 EventBus 广播时用其字段）。
    public sealed class GachaResult
    {
        public string ShikigamiId { get; set; } = string.Empty;
        public Rarity Rarity { get; set; }
        public string PoolId { get; set; } = string.Empty;
        // 新手池首次强制产出的起步 SR（非随机）。
        public bool ForcedStarter { get; set; }
    }
}
