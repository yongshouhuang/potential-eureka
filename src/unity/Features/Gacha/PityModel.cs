#nullable enable
using System;

namespace XiaXia.Features.Gacha
{
    // 保底进度条视图模型（纯逻辑，可 headless 单测）。
    // 计算填充比例与文案，供 PityProgressBar（UGUI）消费；UI 不得自行写死阈值/文案逻辑。
    //
    // 对齐 UX §4：填充 = pity/hard；副文分三档（距保底 / 软保底生效 / 下抽必出 SSR）。
    // 不跨池：调用方每次传入绑定池的 (pity, soft, hard)，本类不缓存。
    public static class PityModel
    {
        public sealed class View
        {
            public float FillRatio;     // 0..1
            public string? CountText;   // 例 "12 / 90"（tabular）
            public string? SubText;     // 副文（距保底 / 软保底生效 / 下抽必出 SSR）
            public bool SoftActive;     // 已入软保底区间
            public bool NearHard;       // 再抽 1 即硬保底必出 SSR
        }

        public static View Compute(int pity, int soft, int hard)
        {
            var safeHard = hard <= 0 ? 1 : hard;
            var ratio = Math.Clamp((float)pity / safeHard, 0f, 1f);

            string sub;
            var softActive = false;
            var nearHard = false;

            if (safeHard - pity <= 1)
            {
                sub = "下抽必出 SSR"; // 硬保底临界（art §4.2 边缘#2）
                nearHard = true;
            }
            else if (pity >= soft && soft > 0)
            {
                sub = "软保底生效·SSR概率提升"; // 图标+文本，非纯色（UX §4.1）
                softActive = true;
            }
            else
            {
                sub = $"距保底还有 {safeHard - pity} 抽";
            }

            return new View
            {
                FillRatio = ratio,
                CountText = $"{pity} / {hard}",
                SubText = sub,
                SoftActive = softActive,
                NearHard = nearHard,
            };
        }

        // 阈值跨越检测（音频提示，audio §3.3）。prevPity=跨越前保底值，newPity=Pull 后新值。
        // 纯逻辑（可 headless 单测），PityProgressBar 委托调用。
        public enum Crossing { None, Soft, Hard }

        public static Crossing DetectCrossing(int prevPity, int newPity, int soft, int hard)
        {
            if (hard <= 0) return Crossing.None;
            var wasNear = (hard - prevPity) <= 1;
            var nowNear = (hard - newPity) <= 1;
            if (!wasNear && nowNear) return Crossing.Hard; // 跨过硬保底（再抽必出 SSR）
            var wasSoft = prevPity >= soft && soft > 0;
            var nowSoft = newPity >= soft && soft > 0;
            if (!wasSoft && nowSoft) return Crossing.Soft; // 跨过软保底（SSR 概率提升）
            return Crossing.None;
        }
    }
}
