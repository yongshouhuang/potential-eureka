#nullable enable
using System.Collections.Generic;
using XiaXia.Core.Models;
using XiaXia.Features.Shared;

namespace XiaXia.Features.Gacha
{
    // 揭示时间轴锚点（对齐 art §8 / audio §2）。所有时间为「单张卡相对时刻」，单位秒。
    // 十连时第 k 张整体偏移 k * CardStagger（错峰波浪，audio §3.7 规避齐奏轰头）。
    public static class RevealTiming
    {
        public const float CardStagger = 0.08f;      // 十连相邻卡间隔（audio §2 备注）
        public const float FlipStartOffset = 0.00f;  // t=0.00 翻面起手 whoosh（Gacha_Card_Flip_Start）
        public const float RevealSwapOffset = 0.25f; // t=0.25 揭示换面 + 灵光升腾 chime（Gacha_Reveal_Swap）
        public const float SsrClimaxExtra = 0.20f;   // SSR 紫宸虹光峰值再 +0.2s（Gacha_Reveal_SSR_Climax）
        public const float NormalFlipDuration = 0.50f; // 普通卡翻面时长（art §2.1）
        public const float SsrFlipDuration = 0.70f;    // SSR 翻面时长（含揭示后 0.2s 定格，art §2.3）
    }

    // 单张卡的揭示调度单元（纯数据，不含执行）。控制器据此驱动 VFX 与音频同一时间轴。
    public sealed class RevealCue
    {
        public int CardIndex { get; set; }
        public Rarity Rarity { get; set; }
        public float AppearTime { get; set; }   // 卡实例出现 / 翻面起手（Flip_Start）
        public float RevealTime { get; set; }   // = AppearTime + 0.25：换面 + chime + 稀有度顶层音
        public float SsrClimaxTime { get; set; } // = RevealTime + 0.2（仅 SSR；非 SSR = -1）

        public bool IsSsr => Rarity == Rarity.SSR;
    }

    // 揭示时间轴构建器（纯逻辑，可 headless 单测）。
    //
    // 关键契约（audio §3.3/§3.4、art §8）：
    //  • 数据来源 = IGachaService.Pull 返回的 IReadOnlyList<GachaResult>（每卡 Rarity）。
    //  • 产出 = 按 art §8 的 t 锚点排好的逐卡错峰时间轴；音频与 VFX 均「订阅此时间轴」，
    //    绝不随 GachaManager.Pull 同步 burst 的原始事件瞬时齐发（audio §3.4 红线）。
    //  • 该时间轴与 reduce_motion 无关：reduce_motion 仅压缩视觉时长，音频 cue 仍对齐定格揭示时刻
    //    （audio §4.3），故调度本身不读 reduce_motion。
    public static class RevealSchedule
    {
        // 消费有序结果列表，生成逐卡错峰时间轴（十连间隔 CardStagger）。
        public static List<RevealCue> Build(IReadOnlyList<GachaResult> results)
        {
            var cues = new List<RevealCue>(results.Count);
            for (var i = 0; i < results.Count; i++)
            {
                var appear = i * RevealTiming.CardStagger;
                var r = results[i].Rarity;
                cues.Add(new RevealCue
                {
                    CardIndex = i,
                    Rarity = r,
                    AppearTime = appear,
                    RevealTime = appear + RevealTiming.RevealSwapOffset,
                    SsrClimaxTime = r == Rarity.SSR
                        ? appear + RevealTiming.RevealSwapOffset + RevealTiming.SsrClimaxExtra
                        : -1f,
                });
            }
            return cues;
        }

        // 整段揭示总时长（控制器据此判断何时转入 ResultList；跳过则立即转）。
        public static float TotalDuration(IReadOnlyList<RevealCue> cues)
        {
            if (cues.Count == 0) return 0f;
            var last = cues[cues.Count - 1];
            var flip = last.IsSsr ? RevealTiming.SsrFlipDuration : RevealTiming.NormalFlipDuration;
            return last.AppearTime + flip;
        }
    }
}
