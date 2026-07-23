#nullable enable
using System.Collections.Generic;
using System.Reflection;
using NUnit.Framework;
using XiaXia.Core;
using XiaXia.Features.Bond;
using XiaXia.Core.Models;
using XiaXia.Features.Shared;
using XiaXia.Features.Shared.Events;

namespace XiaXia.Features.Bond.Tests
{
    // Bond 第三垂直切片验收（对齐 Godot 牵绊系统「碎片合成/升阶」）。
    // EditMode 测试（UTF）；Bond 不依赖其它 manager，直接构造真 BondManager（不复用 FakeEconomyService）。
    // 预期：Bond 7/7 全绿（与 Economy 16/16 + Gacha 7/7 共存，保持 23/23 不破）。
    [TestFixture]
    public class BondTests
    {
        private EventBus _bus = null!;
        private PlayerProfile _profile = null!;

        // 构造与 data/bond/bond_config.json 等价的 BondConfig（测试不读盘）。
        private static BondConfig FakeConfig() => new BondConfig
        {
            FragmentsPerLevel = new List<int> { 20, 50, 100 },
            BondBonuses = new Dictionary<string, List<string>>(),
        };

        private static ShikigamiInstance MakeShikigami(string id, int bondLevel = 0, int fragments = 0) => new ShikigamiInstance
        {
            Id = id,
            Level = 1,
            Breakthrough = 0,
            AwakenedSkills = new List<string>(),
            BondLevel = bondLevel,
            Fragments = fragments,
        };

        [SetUp]
        public void SetUp()
        {
            _bus = new EventBus();
            _profile = new PlayerProfile();
        }

        // ── (1) 读初始牵绊等级 ──
        [Test]
        public void GetBondLevel_ReadsInitialValue()
        {
            _profile.Shikigami.Add(MakeShikigami("aoba", bondLevel: 2, fragments: 10));
            var bond = new BondManager(_bus, _profile, FakeConfig());
            Assert.AreEqual(2, bond.GetBondLevel("aoba"), "应从存档读初始 BondLevel");
            Assert.AreEqual(0, bond.GetBondLevel("missing"), "找不到式神返回 0");
        }

        // ── (2) 碎片累加 + 查 ──
        [Test]
        public void AddFragments_AccumulatesAndReadable()
        {
            _profile.Shikigami.Add(MakeShikigami("aoba", fragments: 5));
            var bond = new BondManager(_bus, _profile, FakeConfig());
            Assert.IsTrue(bond.AddFragments("aoba", 7), "应成功累加");
            Assert.AreEqual(12, _profile.Shikigami[0].Fragments, "5+7=12");
            Assert.IsFalse(bond.AddFragments("missing", 1), "找不到式神返回 false");
        }

        // ── (3) 升阶阈值边界（差1 / 刚好够 / 满级）──
        [Test]
        public void CanAwaken_ThresholdBoundary()
        {
            _profile.Shikigami.Add(MakeShikigami("aoba", bondLevel: 0, fragments: 19));
            var bond = new BondManager(_bus, _profile, FakeConfig());
            Assert.IsFalse(bond.CanAwaken("aoba"), "差1碎片不应可升阶");

            _profile.Shikigami[0].Fragments = 20;     // 恰好够（0->1 阈值=20）
            Assert.IsTrue(bond.CanAwaken("aoba"), "刚好 20 应可升阶");

            _profile.Shikigami[0].BondLevel = 3;       // = MaxLevel（列表长度）
            _profile.Shikigami[0].Fragments = 9999;
            Assert.IsFalse(bond.CanAwaken("aoba"), "已满级不可再升");
        }

        // ── (4) 升阶：扣碎片 + BondLevel+1 + 广播事件 ──
        [Test]
        public void Awaken_SpendsFragments_LevelsUp_AndBroadcasts()
        {
            _profile.Shikigami.Add(MakeShikigami("aoba", bondLevel: 0, fragments: 20));
            var bond = new BondManager(_bus, _profile, FakeConfig());

            var events = new List<BondLevelUpEvent>();
            _bus.Subscribe<BondLevelUpEvent>(e => events.Add(e));

            Assert.IsTrue(bond.Awaken("aoba"), "应升阶成功");
            Assert.AreEqual(1, _profile.Shikigami[0].BondLevel, "BondLevel +1");
            Assert.AreEqual(0, _profile.Shikigami[0].Fragments, "消耗 20 碎片");
            Assert.AreEqual(1, events.Count, "应广播一次 BondLevelUpEvent");
            Assert.AreEqual("aoba", events[0].ShikigamiId);
            Assert.AreEqual(1, events[0].NewLevel);
        }

        // ── (5) 碎片不足时升阶失败（等级/碎片均不变）──
        [Test]
        public void Awaken_FailsWhenInsufficientFragments()
        {
            _profile.Shikigami.Add(MakeShikigami("aoba", bondLevel: 0, fragments: 10));
            var bond = new BondManager(_bus, _profile, FakeConfig());
            Assert.IsFalse(bond.Awaken("aoba"), "碎片不足不应升阶");
            Assert.AreEqual(0, _profile.Shikigami[0].BondLevel, "等级不变");
            Assert.AreEqual(10, _profile.Shikigami[0].Fragments, "碎片不变");
        }

        // ── (6) 羁绊加成：配置驱动或空 ──
        [Test]
        public void GetBondBonuses_ReturnsConfigOrEmpty()
        {
            var cfg = FakeConfig();
            cfg.BondBonuses["aoba"] = new List<string> { "atk+5%", "hp+5%" };
            var bond = new BondManager(_bus, _profile, cfg);
            Assert.AreEqual(2, bond.GetBondBonuses("aoba").Count, "应返回配置加成");
            Assert.IsEmpty(bond.GetBondBonuses("missing"), "找不到返回空");
        }

        // ── (7) 红线自检：BondManager 字段不含 Gacha/Economy manager 或契约类型 ──
        // （预演 M2 ArchitectureGuardTests；确认零跨 manager 字段引用）
        [Test]
        public void Decoupling_NoGachaEconomyFieldReference()
        {
            var fields = typeof(BondManager).GetFields(
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
            foreach (var f in fields)
            {
                Assert.IsFalse(f.FieldType.Name.Contains("GachaManager"),
                    $"红线违规：BondManager 持有 GachaManager 字段 {f.FieldType.Name}");
                Assert.IsFalse(f.FieldType.Name.Contains("EconomyManager"),
                    $"红线违规：BondManager 持有 EconomyManager 字段 {f.FieldType.Name}");
                Assert.IsFalse(typeof(IGachaService).IsAssignableFrom(f.FieldType),
                    $"红线违规：BondManager 持有 IGachaService 字段 {f.FieldType.Name}");
                Assert.IsFalse(typeof(IEconomyService).IsAssignableFrom(f.FieldType),
                    $"红线违规：BondManager 持有 IEconomyService 字段 {f.FieldType.Name}");
            }
        }
    }
}
