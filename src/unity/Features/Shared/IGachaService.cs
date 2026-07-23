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

        // H1：保底软/硬阈值（读池配置 SoftPity/HardPity）。
        // 进度条刻度（50/90）与「软保底生效」判断用；实现须从池配置读取，禁止 UI 写死阈值。
        (int soft, int hard) GetPityThresholds(string poolId);

        // H2：卡池列表（UI PoolTab 渲染）。displayName 回退到 id（GachaPool 模型暂无独立 name 字段）。
        IReadOnlyList<PoolMeta> GetPoolList();

        // H2：本次 Pull 的符箓消耗（覆盖新手半价：前 20 抽偶数位 0 符箓）。
        // UI 在调用 Pull 前用其做可支付性预检（UX §3.1/§3.2），避免进入 Rolling 后才失败。
        int GetPullCost(string poolId, int count);
    }

    // H2：卡池元数据（UI PoolTab 用）。displayName 回退到首字母大写的 id；
    // GachaPool 数据模型暂无 name 字段，后续可在 data/gacha/gacha_pools.json 增补 "name"。
    public sealed class PoolMeta
    {
        public string Id { get; set; } = string.Empty;
        public string DisplayName { get; set; } = string.Empty;
        public string Type { get; set; } = string.Empty;          // "standard" / "newbie"
        public string StarterSrId { get; set; } = string.Empty;   // 仅新手池
        public string HalfPriceNote { get; set; } = string.Empty; // 新手池提示文案（如「前20抽半价·必出SR」）
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
