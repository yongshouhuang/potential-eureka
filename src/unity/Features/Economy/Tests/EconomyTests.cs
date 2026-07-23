#nullable enable
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using NUnit.Framework;
using XiaXia.Core;
using XiaXia.Core.Models;
using XiaXia.Features.Economy;
using XiaXia.Features.Gacha;
using XiaXia.Features.Shared;
using XiaXia.Features.Shared.Events;

namespace XiaXia.Features.Economy.Tests
{
    // Economy 第二垂直切片验收（映射 Godot EconomyManager.gd「B1 / E1 S1–S6」；
    // 详见 m2-plan §7；用户提示的 T4/E2 为 Gacha 切片标签，本切片沿用 E1 系列，T1 见 m2-plan §2 引用）。
    // EditMode 测试（UTF）；Features.* + Core 零 UnityEngine 依赖，亦可 dotnet test。
    //
    // 与 Gacha 切片的区别：本切片**不复用 FakeEconomyService**，而是构造**真 EconomyManager**，
    // 经 ServiceRegistry 注册为 IEconomyService，验证 GachaManager.Pull 真正扣减 EconomyManager 持有的余额（端到端闭环）。
    [TestFixture]
    public class EconomyTests
    {
        private EventBus _bus = null!;
        private ConfigLoader _loader = null!;
        private PlayerProfile _profile = null!;
        private ServiceRegistry _services = null!;
        private RngWrapper _rng = null!;

        // 构造与 data/economy/economy_config.json 等价的 EconomyConfig（测试不读盘）。
        private static EconomyConfig FakeConfig() => new EconomyConfig
        {
            Currencies = new Dictionary<string, CurrencyDef>
            {
                ["fu_lu"]       = new CurrencyDef { DailySoftCap = 12 },
                ["ling_yu"]      = new CurrencyDef { Hard = true },
                ["ling_qi"]      = new CurrencyDef { DailyCap = 2000 },
                ["po_dan"]       = new CurrencyDef { WeeklyCap = 5 },
                ["jue_xing_shi"] = new CurrencyDef { BossOnly = true },
            },
            FreeTenPull = new FreeTenPullConfig { Amount = 10 },
            Sources = new Dictionary<string, List<string>>
            {
                ["fu_lu"]       = new List<string> { "推图", "日常", "章节首通" },
                ["ling_qi"]      = new List<string> { "推图", "日常" },
                ["po_dan"]       = new List<string> { "推图", "日常" },
                ["jue_xing_shi"] = new List<string> { "Boss" },
                ["ling_yu"]      = new List<string> { "商城" },
            },
        };

        // 与 GachaTests.FakePool 同形（构造标准池，单抽 cost=1）。
        private static GachaPool FakePool(string id, string type, double ssr) => new GachaPool
        {
            Id = id,
            Type = type,
            RarityRates = new RarityRates { SSR = ssr, SR = 0.10, R = 0.35, N = 0.55 },
            SoftPity = 9999,
            HardPity = 9999,
            ShikigamiByRarity = new Dictionary<string, List<string>>
            {
                ["SSR"] = new List<string> { "x" }, ["SR"] = new List<string> { "x" },
                ["R"] = new List<string> { "x" }, ["N"] = new List<string> { "x" },
            },
        };

        [SetUp]
        public void SetUp()
        {
            _bus = new EventBus();
            _loader = new ConfigLoader("<unused>"); // 闭环测试用 SetPoolsForTest 注入，不读盘
            _profile = new PlayerProfile();
            _services = new ServiceRegistry();
            _rng = new RngWrapper(12345);
        }

        // ── (a) 消耗成功 / 余额不足失败 ──
        [Test]
        public void Spend_SuccessAndInsufficient()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            _profile.Currencies["fu_lu"] = 10;
            var changes = new List<EconomyCurrencyChangedEvent>();
            _bus.Subscribe<EconomyCurrencyChangedEvent>(e => changes.Add(e));

            Assert.IsTrue(econ.Spend("fu_lu", 3, "gacha"), "余额充足应成功");
            Assert.AreEqual(7, _profile.Currencies["fu_lu"], "扣减 3");
            Assert.AreEqual(1, changes.Count, "成功才广播");
            Assert.AreEqual(-3, changes[0].Amount, "广播金额为负");

            Assert.IsFalse(econ.Spend("fu_lu", 100, "gacha"), "余额不足应失败");
            Assert.AreEqual(7, _profile.Currencies["fu_lu"], "不足不扣减");
            Assert.AreEqual(1, changes.Count, "失败不广播");
        }

        // ── (b) 产出受日软预算上限约束（边界值）──
        [Test]
        public void Grant_DailySoftCap_Boundary()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            econ.SetDateOverride("2026-07-20");
            Assert.AreEqual(12, econ.Grant("fu_lu", 12, "日常"), "恰好 12 放行");
            Assert.AreEqual(0, econ.Grant("fu_lu", 1, "日常"), "13 > 12 拒绝");
            Assert.AreEqual(12, _profile.Currencies["fu_lu"], "被拒不改状态");
        }

        [Test]
        public void Grant_DailySoftCap_CumulativeReject()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            econ.SetDateOverride("2026-07-20");
            Assert.AreEqual(5, econ.Grant("fu_lu", 5, "日常"));
            Assert.AreEqual(5, econ.Grant("fu_lu", 5, "日常"));   // 累计 10
            Assert.AreEqual(10, _profile.Currencies["fu_lu"]);
            Assert.AreEqual(0, econ.Grant("fu_lu", 5, "日常"), "10+5=15 > 12 整笔拒绝");
            Assert.AreEqual(10, _profile.Currencies["fu_lu"]);
        }

        [Test]
        public void Grant_DailyCap_LingQi()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            econ.SetDateOverride("2026-07-20");
            Assert.AreEqual(2000, econ.Grant("ling_qi", 2000, "推图"));
            Assert.AreEqual(0, econ.Grant("ling_qi", 1, "推图"), "超 2000 拒绝");
        }

        [Test]
        public void Grant_WeeklyCap_PoDan_CrossWeekResets()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            econ.SetWeekOverride(30);
            Assert.AreEqual(5, econ.Grant("po_dan", 5, "推图"));
            Assert.AreEqual(0, econ.Grant("po_dan", 1, "推图"), "本周已满");
            econ.SetWeekOverride(31);                            // 跨周
            Assert.AreEqual(5, econ.Grant("po_dan", 5, "推图"), "跨周重置后可再发");
        }

        [Test]
        public void ResetWeeklyCap_ProductionTracker()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            econ.SetWeekOverride(30);
            Assert.AreEqual(5, econ.Grant("po_dan", 5, "推图"), "本周发满 5（周上限）");
            Assert.AreEqual(0, econ.Grant("po_dan", 1, "推图"), "本周已满，拒绝");

            econ.ResetWeeklyIfNeeded(31);                  // 直接调周界重置
            Assert.AreEqual(5, econ.Grant("po_dan", 5, "推图"), "周重置后可再发满 5");
        }

        [Test]
        public void Grant_BossOnly_JueXingShi()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            Assert.AreEqual(3, econ.Grant("jue_xing_shi", 3, "Boss"), "Boss 来源放行");
            Assert.AreEqual(0, econ.Grant("jue_xing_shi", 3, "推图"), "非 Boss 来源拒绝");
        }

        [Test]
        public void Grant_ExemptFromBudget_SkipsCapAndTracking()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            econ.SetDateOverride("2026-07-20");
            Assert.AreEqual(100, econ.Grant("fu_lu", 100, "free_ten_pull", exemptFromBudget: true), "豁免可超 12");
            Assert.AreEqual(100, _profile.Currencies["fu_lu"]);
            // 豁免不计入预算：之后仍可正常发放至 12
            Assert.AreEqual(12, econ.Grant("fu_lu", 12, "日常"));
            Assert.AreEqual(112, _profile.Currencies["fu_lu"]);
        }

        [Test]
        public void Grant_HardCurrency_NotEnforcedInCode()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            Assert.AreEqual(10, econ.Grant("ling_yu", 10, "商城"));
            // hard 仅为元数据，代码不拦截（对齐 Godot）；是否强制「仅商城来源」见 m2-plan 待拍板。
            Assert.AreEqual(5, econ.Grant("ling_yu", 5, "推图"), "hard 未在代码层拦截");
        }

        [Test]
        public void Grant_UnknownCurrency_AllowedNoCap()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            Assert.AreEqual(999, econ.Grant("mystery", 999, "x"), "未知货币无上限");
            Assert.AreEqual(999, _profile.Currencies["mystery"]);
        }

        [Test]
        public void ClaimFreeTenPull_OncePerDay_Exempt()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            econ.SetDateOverride("2026-07-20");
            Assert.AreEqual(10, econ.ClaimFreeTenPull(), "当日首领 10 符箓");
            Assert.AreEqual(10, _profile.Currencies["fu_lu"]);
            Assert.AreEqual(0, econ.ClaimFreeTenPull(), "同日重复领取返回 0");
            econ.SetDateOverride("2026-07-21");
            Assert.AreEqual(10, econ.ClaimFreeTenPull(), "跨日可再领（仍豁免预算）");
        }

        [Test]
        public void ResetDaily_RollsProductionTrackerToNewDay()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            econ.SetDateOverride("2026-07-20");
            econ.Grant("fu_lu", 12, "日常");                       // 当日满
            Assert.AreEqual(0, econ.Grant("fu_lu", 1, "日常"), "当日已满");
            econ.SetDateOverride("2026-07-21");
            econ.ResetDailyIfNeeded();
            Assert.AreEqual(1, econ.Grant("fu_lu", 1, "日常"), "跨日重置后可再发");
        }

        [Test]
        public void GetRecommendedSources_ReturnsConfigSources()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            Assert.AreEqual(3, econ.GetRecommendedSources("fu_lu").Count, "E1-S6 推荐产出源");
            Assert.IsEmpty(econ.GetRecommendedSources("nonexistent"));
        }

        // ── (c) 与 Gacha 扣费闭环：真 EconomyManager 经 ServiceRegistry 被 GachaManager 调用 ──
        [Test]
        public void ClosedLoop_GachaPullSpendsRealEconomyBalance()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            _services.Register<IEconomyService>(econ);            // 注册真 EconomyManager
            var gacha = new GachaManager(_bus, _loader, _profile, _services, _rng);

            _profile.Currencies["fu_lu"] = 100;
            gacha.SetPoolsForTest(new Dictionary<string, GachaPool> { ["standard"] = FakePool("standard", "standard", 0.02) });

            var changes = new List<EconomyCurrencyChangedEvent>();
            _bus.Subscribe<EconomyCurrencyChangedEvent>(e => changes.Add(e));

            var results = gacha.Pull("standard", 5);
            Assert.AreEqual(5, results.Count, "5 抽全部成功");
            Assert.AreEqual(95, _profile.Currencies["fu_lu"], "真实 EconomyManager 扣了 5 符箓");
            Assert.AreEqual(5, changes.Count, "每次扣费广播一次 currency_changed");
            Assert.IsTrue(changes.TrueForAll(e => e.Currency == "fu_lu" && e.Amount == -1), "广播金额为 -1");
        }

        [Test]
        public void ClosedLoop_InsufficientFuLu_StopsEarly()
        {
            var econ = new EconomyManager(_bus, _profile, FakeConfig());
            _services.Register<IEconomyService>(econ);
            var gacha = new GachaManager(_bus, _loader, _profile, _services, _rng);
            _profile.Currencies["fu_lu"] = 2;                      // 仅够 2 抽
            gacha.SetPoolsForTest(new Dictionary<string, GachaPool> { ["standard"] = FakePool("standard", "standard", 0.02) });

            var results = gacha.Pull("standard", 5);
            Assert.AreEqual(2, results.Count, "仅 2 符箓 -> 只中 2 抽");
            Assert.AreEqual(0, _profile.Currencies["fu_lu"], "余额归零");
        }

        // ── (d) 红线自检：EconomyManager 字段不含 GachaManager / IGachaService 具体类型 ──
        // （预演 M2 ArchitectureGuardTests；确认零跨 manager 字段引用）
        [Test]
        public void Decoupling_NoGachaManagerFieldReference()
        {
            var fields = typeof(EconomyManager).GetFields(
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
            foreach (var f in fields)
            {
                Assert.IsFalse(f.FieldType.Name.Contains("GachaManager"),
                    $"红线违规：EconomyManager 持有 GachaManager 字段 {f.FieldType.Name}");
                Assert.IsFalse(typeof(IGachaService).IsAssignableFrom(f.FieldType),
                    $"红线违规：EconomyManager 持有 IGachaService 字段 {f.FieldType.Name}");
            }
        }
    }
}
