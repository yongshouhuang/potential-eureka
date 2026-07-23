#nullable enable
using System;
using System.Collections.Generic;
using XiaXia.Core;
using XiaXia.Core.Models;
using XiaXia.Features.Shared;
using XiaXia.Features.Shared.Events;

namespace XiaXia.Features.Gacha
{
    // 抽卡召唤编排（B2 / E2）。实现 IGachaService。
    //
    // ── 解耦红线自检（ADR-3 控制清单）──
    //  • 不持有 EconomyManager / IEconomyService 字段：消耗符箓经
    //    ServiceRegistry.Resolve<IEconomyService>() 在调用点取用，拿到即用、不缓存为字段（#3）。
    //  • 随机经 RngWrapper（#6）；存档读写经 PlayerProfile（纯数据对象，#2/#3）。
    //  • 跨系统广播经 EventBus（#2）：gacha_shikigami_obtained / telemetry_gacha_pulled。
    //  • 持有的引用均为基础设施/数据：EventBus / ConfigLoader / PlayerProfile / RngWrapper / ServiceRegistry，
    //    均非其他 manager —— 架构测试（M2 ArchitectureGuardTests）应断言其字段零跨 manager 引用。
    public sealed class GachaManager : IGachaService
    {
        private readonly EventBus _bus;
        private readonly ConfigLoader _loader;
        private readonly PlayerProfile _profile;
        private readonly ServiceRegistry _services;
        private readonly RngWrapper _rng;
        private readonly GachaRollEngine _engine;

        // test-seam：注入自定义卡池，绕开 M1 Core ConfigLoader 缺 Inject/Reset（见 m2-plan GAP-1）。
        // 为 null 时回退到 _loader.LoadGachaPools()（需 data/ 在用 Unity/dotnet 环境）。
        private Dictionary<string, GachaPool>? _injectedPools;

        public GachaManager(EventBus bus, ConfigLoader loader, PlayerProfile profile,
            ServiceRegistry services, RngWrapper rng)
        {
            _bus = bus ?? throw new ArgumentNullException(nameof(bus));
            _loader = loader ?? throw new ArgumentNullException(nameof(loader));
            _profile = profile ?? throw new ArgumentNullException(nameof(profile));
            _services = services ?? throw new ArgumentNullException(nameof(services));
            _rng = rng ?? throw new ArgumentNullException(nameof(rng));
            _engine = new GachaRollEngine(_rng);
        }

        // 测试用：注入假卡池（headless 单测无需 data/ 或 ConfigLoader.Inject）。
        public void SetPoolsForTest(Dictionary<string, GachaPool> pools) => _injectedPools = pools;

        private GachaPool? GetPool(string poolId)
        {
            var dict = _injectedPools ?? _loader.LoadGachaPools();
            return dict.TryGetValue(poolId, out var p) ? p : null;
        }

        public int GetPity(string poolId) =>
            _profile.Pity.TryGetValue(poolId, out var v) ? v : 0;

        // H1：保底软/硬阈值（读池配置）。空池返回 (0,0)；UI 不得写死 50/90。
        public (int soft, int hard) GetPityThresholds(string poolId)
        {
            var pool = GetPool(poolId);
            if (pool == null) return (0, 0);
            return (pool.SoftPity, pool.HardPity);
        }

        // H2：卡池列表（UI PoolTab 渲染）。displayName 回退到首字母大写的 id。
        public IReadOnlyList<PoolMeta> GetPoolList()
        {
            var dict = _injectedPools ?? _loader.LoadGachaPools();
            var list = new List<PoolMeta>(dict.Count);
            foreach (var kv in dict)
            {
                var p = kv.Value;
                list.Add(new PoolMeta
                {
                    Id = p.Id,
                    DisplayName = string.IsNullOrEmpty(p.Id)
                        ? p.Id
                        : char.ToUpperInvariant(p.Id[0]) + p.Id.Substring(1),
                    Type = p.Type,
                    StarterSrId = p.StarterSrId ?? string.Empty,
                    HalfPriceNote = p.Type == "newbie" ? "前20抽半价·必出SR" : string.Empty,
                });
            }
            return list;
        }

        // H2：本次 Pull 的符箓消耗（覆盖新手半价）。
        // 与 Pull 内部 PullCost 同义：从当前 GachaProgress.PullsDone 起模拟 count 抽的累计消耗，
        // 不修改任何状态——UI 据其做可支付性预检（UX §3.1/§3.2）。
        public int GetPullCost(string poolId, int count)
        {
            var pool = GetPool(poolId);
            if (pool == null || count <= 0) return 0;
            var done = _profile.GachaProgress.TryGetValue(poolId, out var e) ? e.PullsDone : 0;
            var cost = 0;
            for (var k = 0; k < count; k++)
            {
                var p = done + k; // 第 k+1 抽前的累计进度
                if (pool.Type != "newbie") { cost += 1; continue; }
                if (p < 20) cost += (p % 2 == 1) ? 1 : 0; // 前 20 抽：偶数位(0)免费、奇数位(1)收费
                else cost += 1;
            }
            return cost;
        }

        // E2-S5 概率公示数据（双端展示用；渲染是 UI 职责）。
        public IReadOnlyDictionary<string, double> GetProbabilities(string poolId)
        {
            var pool = GetPool(poolId);
            if (pool == null) return new Dictionary<string, double>();
            return new Dictionary<string, double>
            {
                ["SSR"] = pool.RarityRates.SSR,
                ["SR"] = pool.RarityRates.SR,
                ["R"] = pool.RarityRates.R,
                ["N"] = pool.RarityRates.N,
            };
        }

        // 纯逻辑 Roll（不消耗、不广播）。直接委托引擎，读写 PlayerProfile 的 pity/gachaProgress。
        public GachaResult RollOnce(string poolId)
        {
            var pool = GetPool(poolId);
            if (pool == null) return new GachaResult { PoolId = poolId };
            return _engine.RollOnce(poolId, pool, _profile.Pity, _profile.GachaProgress);
        }

        // 对外抽卡入口：消耗符箓 -> Roll -> 写 PlayerProfile.shikigami -> 广播。
        public IReadOnlyList<GachaResult> Pull(string poolId, int count = 1)
        {
            var results = new List<GachaResult>();

            // 红线：调用点解析经济服务，不缓存为字段。
            if (!_services.TryResolve<IEconomyService>(out var econ)) return results;

            for (var i = 0; i < count; i++)
            {
                var cost = PullCost(poolId);
                if (!econ.Spend("fu_lu", cost, "gacha"))
                    break; // 符箓不足 -> 停止，不产出

                var r = RollOnce(poolId);
                if (string.IsNullOrEmpty(r.ShikigamiId))
                    break; // 空池/异常：停止（与 Godot 语义一致，已扣符箓不回填）

                _profile.Shikigami.Add(new ShikigamiInstance
                {
                    Id = r.ShikigamiId,
                    Level = 1,
                    Breakthrough = 0,
                    AwakenedSkills = new List<string>(),
                    BondLevel = 0,
                    Fragments = 0,
                });

                _bus.Publish(new GachaShikigamiObtainedEvent
                {
                    ShikigamiId = r.ShikigamiId,
                    Rarity = r.Rarity,
                    PoolId = poolId,
                });
                _bus.Publish(new TelemetryGachaPulledEvent
                {
                    ShikigamiId = r.ShikigamiId,
                    Rarity = r.Rarity,
                    PoolId = poolId,
                });

                results.Add(r);
            }
            return results;
        }

        // 单抽成本（含新手半价）：前 20 抽每 2 抽收 1 符箓 -> 20 抽共耗 10 符箓。
        private int PullCost(string poolId)
        {
            var pool = GetPool(poolId);
            if (pool == null || pool.Type != "newbie") return 1;
            var done = _profile.GachaProgress.TryGetValue(poolId, out var e) ? e.PullsDone : 0;
            if (done < 20) return (done % 2 == 1) ? 1 : 0;
            return 1;
        }
    }
}
