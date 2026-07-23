#nullable enable
using System.Collections.Generic;
using NUnit.Framework;
using XiaXia.Core.Models;
using XiaXia.Features.Gacha;
using XiaXia.Features.Shared;

namespace XiaXia.Features.Gacha.Tests
{
    // RevealSchedule + PityModel 纯逻辑单测（headless / Unity EditMode 均可跑，无 UnityEngine 依赖）。
    // 覆盖 audio §3.4 红线（错峰不齐发）与 UX §4 保底公式/边缘情况。
    [TestFixture]
    public class RevealAndPityTests
    {
        private static List<GachaResult> Results(params Rarity[] rs)
        {
            var list = new List<GachaResult>();
            for (var i = 0; i < rs.Length; i++)
                list.Add(new GachaResult { ShikigamiId = $"s{i}", Rarity = rs[i], PoolId = "p" });
            return list;
        }

        // —— RevealSchedule：十连错峰波浪（间隔 0.08s，audio §2 备注）——
        [Test]
        public void RevealSchedule_TenPull_StaggersBy0_08()
        {
            var cues = RevealSchedule.Build(Results(
                Rarity.N, Rarity.R, Rarity.SR, Rarity.N, Rarity.N,
                Rarity.R, Rarity.N, Rarity.N, Rarity.SR, Rarity.N));

            Assert.AreEqual(0f, cues[0].AppearTime, 1e-6f, "首张 t=0");
            Assert.AreEqual(3 * RevealTiming.CardStagger, cues[3].AppearTime, 1e-6f, "第 k 张偏移 k*0.08");
            for (var i = 0; i < cues.Count; i++)
            {
                Assert.AreEqual(i * RevealTiming.CardStagger, cues[i].AppearTime, 1e-6f);
                Assert.AreEqual(cues[i].AppearTime + RevealTiming.RevealSwapOffset, cues[i].RevealTime, 1e-6f,
                    "换面在 t=0.25（art §8）");
            }
        }

        // SSR 额外在 t=0.25+0.2s 触发 climax；非 SSR 为 -1（audio §2 #9）。
        [Test]
        public void RevealSchedule_SsrClimaxOnlyForSsr()
        {
            var cues = RevealSchedule.Build(Results(Rarity.N, Rarity.SSR, Rarity.R));
            Assert.AreEqual(-1f, cues[0].SsrClimaxTime, "N 无 climax");
            Assert.AreEqual(-1f, cues[2].SsrClimaxTime, "R 无 climax");
            Assert.Greater(cues[1].SsrClimaxTime, 0f, "SSR 有 climax");
            Assert.AreEqual(cues[1].RevealTime + RevealTiming.SsrClimaxExtra, cues[1].SsrClimaxTime, 1e-6f,
                "SSR climax = 换面 + 0.2s");
        }

        // 总时长：末张 appear + 该卡翻面时长（SSR 0.7 / 普通 0.5）。
        [Test]
        public void RevealSchedule_TotalDuration_LastCard()
        {
            var tenN = RevealSchedule.Build(Results(
                Rarity.N, Rarity.N, Rarity.N, Rarity.N, Rarity.N,
                Rarity.N, Rarity.N, Rarity.N, Rarity.N, Rarity.N));
            Assert.AreEqual(9 * RevealTiming.CardStagger + RevealTiming.NormalFlipDuration,
                RevealSchedule.TotalDuration(tenN), 1e-6f);

            var withSsrLast = RevealSchedule.Build(Results(Rarity.N, Rarity.SSR));
            Assert.AreEqual(1 * RevealTiming.CardStagger + RevealTiming.SsrFlipDuration,
                RevealSchedule.TotalDuration(withSsrLast), 1e-6f);
        }

        // —— PityModel：填充公式 + 三档副文（UX §4）——
        [Test]
        public void PityModel_NewPool_ShowsRemaining()
        {
            var v = PityModel.Compute(0, 50, 90);
            Assert.AreEqual(0f, v.FillRatio, 1e-6f);
            Assert.AreEqual("0 / 90", v.CountText);
            Assert.AreEqual("距保底还有 90 抽", v.SubText);
            Assert.IsFalse(v.SoftActive);
            Assert.IsFalse(v.NearHard);
        }

        [Test]
        public void PityModel_SoftActive_ShowsBoost()
        {
            var v = PityModel.Compute(60, 50, 90);
            Assert.IsTrue(v.SoftActive, "pity>=soft → 软保底生效");
            Assert.AreEqual("软保底生效·SSR概率提升", v.SubText);
            Assert.AreEqual(60f / 90f, v.FillRatio, 1e-6f);
        }

        [Test]
        public void PityModel_HardCritical_ShowsGuaranteed()
        {
            var v = PityModel.Compute(89, 50, 90);
            Assert.IsTrue(v.NearHard, "hard-1 → 下抽必出 SSR");
            Assert.AreEqual("下抽必出 SSR", v.SubText);
            Assert.AreEqual(89f / 90f, v.FillRatio, 1e-6f);
        }

        [Test]
        public void PityModel_FillRatio_Clamped()
        {
            var v = PityModel.Compute(200, 50, 90);
            Assert.AreEqual(1f, v.FillRatio, 1e-6f, "不超过 1");
        }

        // 保底阈值跨越（audio §3.3）：驱动 Gacha_Pity_Near / Gacha_Pity_Triggered。
        [Test]
        public void PityModel_DetectCrossing_SoftAndHard()
        {
            Assert.AreEqual(PityModel.Crossing.Soft, PityModel.DetectCrossing(40, 50, 50, 90),
                "跨过软保底(50) → Soft");
            Assert.AreEqual(PityModel.Crossing.Hard, PityModel.DetectCrossing(87, 89, 50, 90),
                "跨过硬保底临界(89) → Hard");
            Assert.AreEqual(PityModel.Crossing.None, PityModel.DetectCrossing(0, 10, 50, 90),
                "普通区间无跨越");
            Assert.AreEqual(PityModel.Crossing.None, PityModel.DetectCrossing(50, 50, 50, 90),
                "已处软保底内不重复触发");
        }
    }
}
