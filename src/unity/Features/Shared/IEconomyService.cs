#nullable enable

namespace XiaXia.Features.Shared
{
    // 经济服务契约（B1 / E1）。由 EconomyManager 实现并注册到 ServiceRegistry。
    //
    // 解耦红线用法：消费方（如 GachaManager）**只经 ServiceRegistry.Resolve<IEconomyService>() 在调用点取用**，
    // 不把本接口/实现缓存为字段引用（ADR-3 控制清单 #3）。这样 Gacha 依赖的是「契约」而非 EconomyManager 具体类，
    // 二者无编译期硬引用，架构测试可断言 0 跨 manager 字段引用。
    public interface IEconomyService
    {
        // 校验余额；不足返回 false 且不扣减；成功则扣减 + 广播 economy:currency_changed。
        bool Spend(string currency, int amount, string sink);

        // 增加货币；遵守 boss_only 与日/周预算（免费十连可经 exemptFromBudget 解耦）。
        // 返回实际增加的量（被预算拦截返回 0）。
        int Grant(string currency, int amount, string source, bool exemptFromBudget = false);
    }
}
