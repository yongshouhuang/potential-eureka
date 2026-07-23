#nullable enable
using XiaXia.Core.Models;

namespace XiaXia.Features.Audio
{
    // 抽卡音频事件 Id（audio §3.1，契约枚举）。
    // 命名对齐 audio §2 事件清单；终稿替换路径：仅 SoundBank 绑定终稿 clip，业务代码零改动（audio §5.2）。
    public enum SoundId
    {
        // —— 抽卡 UI ——
        Gacha_SinglePull_Click,
        Gacha_TenPull_Click,
        Gacha_Pool_Select,
        Gacha_Card_Flip_Start,     // t=0.00 翻面起手 whoosh（audio v1.1 新增）
        Gacha_Rolling,             // loop
        Gacha_Insufficient,
        Gacha_Pity_Near,
        Gacha_Pity_Triggered,
        Gacha_Screen_Close,
        Bond_Prologue_Open,        // 占位钩子（P2）

        // —— 出货揭示（稀有度递进）——
        Gacha_Reveal_Swap,         // t=0.25 揭示换面基础层：whoosh + 青碧灵光升腾 chime（所有稀有度共通）
        Gacha_Reveal_N,
        Gacha_Reveal_R,
        Gacha_Reveal_SR,
        Gacha_Reveal_SSR,
        Gacha_Reveal_SSR_Climax,   // SSR 高潮 bed（t=0.25+0.2s 紫宸虹光峰值，独立较长 cue）
        Gacha_Reveal_UR,           // 前向兼容槽位（MVP 不触发；art-bible 列 UR 为可选）
    }

    // 稀有度 → 揭示顶层 SoundId 映射（audio §3.1）。
    // 注意：播放揭示时，除本层外还需叠加基础层 Gacha_Reveal_Swap（audio §2 图层关系）。
    // 作为 SoundId 的扩展方法，避免给枚举加方法（C# 枚举无实例方法）。
    public static class SoundIdExtensions
    {
        public static SoundId RevealTopLayerFor(Rarity r) => r switch
        {
            Rarity.N => SoundId.Gacha_Reveal_N,
            Rarity.R => SoundId.Gacha_Reveal_R,
            Rarity.SR => SoundId.Gacha_Reveal_SR,
            Rarity.SSR => SoundId.Gacha_Reveal_SSR,
            _ => SoundId.Gacha_Reveal_UR,
        };
    }
}
