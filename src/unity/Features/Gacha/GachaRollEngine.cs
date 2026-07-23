#nullable enable
using System;
using System.Collections.Generic;
using XiaXia.Core.Models;
using XiaXia.Features.Shared;

namespace XiaXia.Features.Gacha
{
    // 纯抽卡逻辑引擎（B2 / E2）。零状态写入、不广播、不引用 manager；可直接独立单测（T4/E2-S1）。
    // 所有随机经注入的 RngWrapper（固定种子，ADR-3 红线#6）。
    //
    // 设计：把「概率/保底/选角」等纯计算从 GachaManager 抽离，使其可在无 EventBus/PlayerProfile 环境下验证。
    // 保底计数与抽卡进度由调用方（GachaManager）从 PlayerProfile 取出后传入，引擎直接读写这两个字典，
    // 调用方负责把结果持久化回 PlayerProfile（保持单一真源）。
    public sealed class GachaRollEngine
    {
        private readonly RngWrapper _rng;

        public GachaRollEngine(RngWrapper rng)
        {
            _rng = rng ?? throw new ArgumentNullException(nameof(rng));
        }

        // 单次 Roll：读/写传入的 pity 与 gachaProgress（调用方从 PlayerProfile 取）。返回结果。
        public GachaResult RollOnce(
            string poolId,
            GachaPool pool,
            Dictionary<string, int> pity,
            Dictionary<string, GachaProgressEntry> gachaProgress)
        {
            if (pool == null) return new GachaResult { PoolId = poolId };

            var pityCount = pity.TryGetValue(poolId, out var p) ? p : 0;

            // 新手池：首次必出指定 SR 起步式神
            if (pool.Type == "newbie")
            {
                var prog = gachaProgress.TryGetValue(poolId, out var e) ? e : new GachaProgressEntry();
                if (!prog.StarterClaimed)
                {
                    prog.StarterClaimed = true;
                    prog.PullsDone = 1;
                    gachaProgress[poolId] = prog;
                    pity[poolId] = 0;
                    return new GachaResult
                    {
                        ShikigamiId = pool.StarterSrId ?? string.Empty,
                        Rarity = Rarity.SR,
                        PoolId = poolId,
                        ForcedStarter = true,
                    };
                }
            }

            var rarity = DetermineRarity(pool, pityCount);
            var sid = PickShikigami(pool, rarity);

            // 更新保底计数（SSR 清零，否则 +1）
            if (rarity == Rarity.SSR) pity[poolId] = 0;
            else pity[poolId] = pityCount + 1;

            // 更新抽卡进度
            var prog2 = gachaProgress.TryGetValue(poolId, out var e2) ? e2 : new GachaProgressEntry();
            prog2.PullsDone += 1;
            gachaProgress[poolId] = prog2;

            return new GachaResult { ShikigamiId = sid, Rarity = rarity, PoolId = poolId };
        }

        // 稀有度判定：硬保底 -> 软保底(提升 SSR 率) -> 常规加权。
        public Rarity DetermineRarity(GachaPool pool, int pityCount)
        {
            var soft = pool.SoftPity;
            var hard = pool.HardPity;
            var next = pityCount + 1;
            if (next >= hard) return Rarity.SSR;                       // 硬保底：第 hard 抽必出
            if (next >= soft) return RollWithBoostedSsr(pool.RarityRates, EffectiveSsrRate(pityCount, pool));
            return WeightedRoll(pool.RarityRates);
        }

        // 软保底 SSR 概率：第 soft 抽 = 50%，线性升至第 hard 抽 = 100%（下限 50%）。
        public double EffectiveSsrRate(int pityCount, GachaPool pool)
        {
            var soft = pool.SoftPity;
            var hard = pool.HardPity;
            var next = pityCount + 1;
            if (next < soft) return pool.RarityRates.SSR;
            var t = (double)(next - soft) / (hard - soft);
            return Math.Clamp(0.5 + 0.5 * t, 0.5, 1.0);
        }

        // 常规加权抽样（总概率需=1）。
        public Rarity WeightedRoll(RarityRates rates)
        {
            var ssr = rates.SSR; var sr = rates.SR; var r = rates.R; var n = rates.N;
            var total = ssr + sr + r + n;
            if (total <= 0) return Rarity.N;
            var x = _rng.NextDouble() * total;
            if (x < ssr) return Rarity.SSR;
            x -= ssr;
            if (x < sr) return Rarity.SR;
            x -= sr;
            if (x < r) return Rarity.R;
            return Rarity.N;
        }

        // 软保底区间：SSR 概率提升至 ssrRate，其余档按剩余比例缩放（总概率仍为 1）。
        public Rarity RollWithBoostedSsr(RarityRates rates, double ssrRate)
        {
            var ssr = ssrRate;
            var remaining = 1.0 - ssrRate;
            var baseOthers = rates.SR + rates.R + rates.N;
            var scale = baseOthers > 0 ? remaining / baseOthers : 0.0;
            var rSr = rates.SR * scale;
            var rR = rates.R * scale;
            var rN = rates.N * scale;
            var total = ssr + rSr + rR + rN;
            if (total <= 0) return Rarity.N;
            var x = _rng.NextDouble() * total;
            if (x < ssr) return Rarity.SSR;
            x -= ssr;
            if (x < rSr) return Rarity.SR;
            x -= rSr;
            if (x < rR) return Rarity.R;
            return Rarity.N;
        }

        // 按稀有度从池中选取式神 id（随机索引）。
        public string PickShikigami(GachaPool pool, Rarity rarity)
        {
            if (!pool.ShikigamiByRarity.TryGetValue(rarity.ToString(), out var list) || list.Count == 0)
                return string.Empty;
            return list[_rng.NextInt(list.Count)];
        }
    }
}
