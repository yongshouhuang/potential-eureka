#nullable enable
using System.Collections.Generic;
using System.Reflection;
using NUnit.Framework;
using XiaXia.Core;
using XiaXia.Core.Models;
using XiaXia.Features.Gacha;
using XiaXia.Features.Shared;
using XiaXia.Features.Shared.Events;

namespace XiaXia.Features.Gacha.Tests
{
    // T4 抽卡保底 + E2-S1 概率抽样（映射 scripts/tests/test_gacha_pity.gd）。
    // EditMode 测试（UTF）；Features.* + Core 零 UnityEngine 依赖，亦可 dotnet test。
    //
    // 本文件属于独立 Test Assembly（见 Features.Gacha.Tests.asmdef，includePlatforms: Editor）。
    [TestFixture]
    public class GachaTests
    {
        private EventBus _bus = null!;
        private ConfigLoader _loader = null!;
        private PlayerProfile _profile = null!;
        private ServiceRegistry _services = null!;
        private RngWrapper _rng = null!;
        private GachaManager _gacha = null!;

        // 构造假卡池（与 Godot _fake_pools 对齐；SSR/SR/R/N 比例由 ssr 参数控制）。
        private static GachaPool FakePool(string id, string type, double ssr, int soft, int hard,
            Dictionary<string, List<string>> byRarity) => new GachaPool
        {
            Id = id,
            Type = type,
            RarityRates = new RarityRates { SSR = ssr, SR = 0.10, R = 0.35, N = 0.55 },
            SoftPity = soft,
            HardPity = hard,
            ShikigamiByRarity = byRarity,
        };

        [SetUp]
        public void SetUp()
        {
            _bus = new EventBus();
            _loader = new ConfigLoader("<unused>"); // 本测试用 SetPoolsForTest 注入，不读盘
            _profile = new PlayerProfile();
            _services = new ServiceRegistry();
            _rng = new RngWrapper(12345);
            _gacha = new GachaManager(_bus, _loader, _profile, _services, _rng);
        }

        // ── T4 硬保底：pity=89 下一抽必 SSR（确定性，不依赖 RNG）──
        [Test]
        public void HardPity_ForcesSsrOn90th()
        {
            var pool = FakePool("standard", "standard", 0.0, 9999, 90,
                new Dictionary<string, List<string>> { ["SSR"] = new List<string> { "ssr_a" } });
            _gacha.SetPoolsForTest(new Dictionary<string, GachaPool> { ["standard"] = pool });
            _profile.Pity["standard"] = 89;
            var r = _gacha.RollOnce("standard");
            Assert.AreEqual(Rarity.SSR, r.Rarity, "pity=89 下一抽必 SSR");
        }

        // ── T4 软保底：第 50 抽率 ≥50%，随抽数线性升（0.5→~1.0）──
        [Test]
        public void SoftPity_RateGeq50ThenRises()
        {
            var pool = FakePool("standard", "standard", 0.0, 50, 90, new Dictionary<string, List<string>>());
            _gacha.SetPoolsForTest(new Dictionary<string, GachaPool> { ["standard"] = pool });
            var engine = new GachaRollEngine(_rng);
            Assert.AreEqual(0.0, engine.EffectiveSsrRate(0, pool), 1e-9, "pity=0 用基础 0%");
            Assert.GreaterOrEqual(engine.EffectiveSsrRate(49, pool), 0.5, "第 50 抽 ≥50%");
            Assert.Greater(engine.EffectiveSsrRate(89, pool), 0.95, "接近 90 抽趋近 100%");
        }

        // ── T4 保底不跨池：pool_a 抽 89 次后，pool_b 从第 0 计 ──
        [Test]
        public void Pity_NotCrossPool()
        {
            var noPityA = FakePool("pool_a", "standard", 0.0, 9999, 9999, new Dictionary<string, List<string>>());
            var noPityB = FakePool("pool_b", "standard", 0.0, 9999, 9999, new Dictionary<string, List<string>>());
            _gacha.SetPoolsForTest(new Dictionary<string, GachaPool> { ["pool_a"] = noPityA, ["pool_b"] = noPityB });
            for (var i = 0; i < 89; i++) _gacha.RollOnce("pool_a");
            Assert.AreEqual(89, _gacha.GetPity("pool_a"), "pool_a 计到 89");
            Assert.AreEqual(0, _gacha.GetPity("pool_b"), "pool_b 从第 0 起，不继承");
            _gacha.RollOnce("pool_b");
            Assert.AreEqual(1, _gacha.GetPity("pool_b"), "切池后独立 +1");
        }

        // ── T4 新手池：首次必出指定 SR 起步式神 ──
        [Test]
        public void Newbie_ForcedStarterSr()
        {
            var nb = FakePool("newbie", "newbie", 0.0, 50, 90,
                new Dictionary<string, List<string>> { ["SR"] = new List<string> { "sr_starter" } });
            nb.StarterSrId = "sr_starter";
            _gacha.SetPoolsForTest(new Dictionary<string, GachaPool> { ["newbie"] = nb });
            var r = _gacha.RollOnce("newbie");
            Assert.AreEqual("sr_starter", r.ShikigamiId, "必出起步 SR");
            Assert.AreEqual(Rarity.SR, r.Rarity, "起步式为 SR");
            Assert.IsTrue(r.ForcedStarter);
        }

        // ── T4 新手半价：20 抽共耗 10 符箓（用 FakeEconomyService 充当 IEconomyService）──
        [Test]
        public void Newbie_HalfPrice20PullsCost10()
        {
            var nb = FakePool("newbie", "newbie", 0.0, 50, 90,
                new Dictionary<string, List<string>>
                {
                    ["SSR"] = new List<string> { "x" }, ["SR"] = new List<string> { "x" },
                    ["R"] = new List<string> { "x" }, ["N"] = new List<string> { "x" },
                });
            _gacha.SetPoolsForTest(new Dictionary<string, GachaPool> { ["newbie"] = nb });
            var fakeEcon = new FakeEconomyService();
            fakeEcon.Balance["fu_lu"] = 100;
            _services.Register<IEconomyService>(fakeEcon);
            _gacha.Pull("newbie", 20);
            Assert.AreEqual(90, fakeEcon.Balance["fu_lu"], "20 抽半价共耗 10 符箓");
            _gacha.Pull("newbie", 1);
            Assert.AreEqual(89, fakeEcon.Balance["fu_lu"], "第 21 抽起全价 -1");
        }

        // ── E2-S1 概率抽样：万次落入公示 ±2% 容差（种子化 RNG）──
        [Test]
        public void Rates_WithinTolerance()
        {
            var pool = FakePool("standard", "standard", 0.02, 9999, 9999,
                new Dictionary<string, List<string>>
                {
                    ["SSR"] = new List<string> { "x" }, ["SR"] = new List<string> { "x" },
                    ["R"] = new List<string> { "x" }, ["N"] = new List<string> { "x" },
                });
            var engine = new GachaRollEngine(_rng);
            var n = 10000;
            var counts = new Dictionary<Rarity, int>();
            for (var i = 0; i < n; i++)
            {
                var rr = engine.WeightedRoll(pool.RarityRates);
                counts[rr] = counts.TryGetValue(rr, out var c) ? c + 1 : 1;
            }
            Assert.LessOrEqual(System.Math.Abs((double)counts[Rarity.SSR] / n - 0.02), 0.02, "SSR 频率≈2%");
            Assert.LessOrEqual(System.Math.Abs((double)counts[Rarity.SR] / n - 0.10), 0.02, "SR 频率≈10%");
            Assert.LessOrEqual(System.Math.Abs((double)counts[Rarity.R] / n - 0.35), 0.02, "R 频率≈35%");
            Assert.LessOrEqual(System.Math.Abs((double)counts[Rarity.N] / n - 0.53), 0.02, "N 频率≈53%");
        }

        // ── ADR-3 红线自检：GachaManager 字段不含 IEconomyService / EconomyManager 具体类型 ──
        // （预演 M2 ArchitectureGuardTests；确认零跨 manager 字段引用）
        [Test]
        public void Decoupling_NoManagerFieldReference()
        {
            var fields = typeof(GachaManager).GetFields(
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
            foreach (var f in fields)
            {
                Assert.IsFalse(typeof(IEconomyService).IsAssignableFrom(f.FieldType),
                    $"红线违规：GachaManager 持有 IEconomyService 字段 {f.FieldType.Name}");
                Assert.IsFalse(f.FieldType.Name.Contains("EconomyManager"),
                    $"红线违规：GachaManager 持有 EconomyManager 字段 {f.FieldType.Name}");
            }
        }
    }

    // 测试桩：实现 IEconomyService，内存记账（不依赖真实 EconomyManager）。
    internal sealed class FakeEconomyService : IEconomyService
    {
        public Dictionary<string, int> Balance { get; } = new Dictionary<string, int>();

        public bool Spend(string currency, int amount, string sink)
        {
            if (!Balance.TryGetValue(currency, out var b) || b < amount) return false;
            Balance[currency] = b - amount;
            return true;
        }

        public int Grant(string currency, int amount, string source, bool exemptFromBudget = false)
        {
            var next = Balance.TryGetValue(currency, out var b) ? b + amount : amount;
            Balance[currency] = next;
            return amount;
        }
    }
}
