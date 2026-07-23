#nullable enable
using System.Collections.Generic;

namespace XiaXia.Features.Shared
{
    // 牵绊（Bond）服务契约（B3）。由 BondManager 实现并注册到 ServiceRegistry。
    //
    // 解耦红线用法：消费方（如 UI/成长系统）只经 ServiceRegistry.Resolve<IBondService>() 在调用点取用，
    // 不把本接口/实现缓存为字段引用（ADR-3 控制清单 #3）。这样消费方依赖的是「契约」而非 BondManager 具体类，
    // 二者无编译期硬引用，架构测试可断言 0 跨 manager 字段引用。
    public interface IBondService
    {
        // 读式神当前牵绊等级（从 PlayerProfile.Shikigami[].BondLevel）；找不到返回 0。
        int GetBondLevel(string shikigamiId);

        // 增加碎片，落 PlayerProfile.Shikigami[].Fragments 单一真源；找不到式神返回 false。
        bool AddFragments(string shikigamiId, int amount);

        // 碎片是否够升一阶（阈值由 BondConfig 驱动）；找不到式神或已满级返回 false。
        bool CanAwaken(string shikigamiId);

        // 消耗碎片、BondLevel+1，经 EventBus 广播 BondLevelUpEvent；不足/已满级/找不到返回 false。
        bool Awaken(string shikigamiId);

        // 羁绊加成列表（由 BondConfig 驱动，可空）；找不到返回空列表。
        IReadOnlyList<string> GetBondBonuses(string shikigamiId);
    }
}
