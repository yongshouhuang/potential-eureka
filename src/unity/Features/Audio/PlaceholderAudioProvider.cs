#nullable enable
using UnityEngine;

namespace XiaXia.Features.Audio
{
    // 占位音合成器（audio §5.1）：按 SoundId 程序化生成极短合成音（不同频率/波形/时长区分稀有度与图层），
    // 零外部资产即可跑通事件触发与错峰时序。终稿接入后本类可弃用（业务代码不改，audio §5.2）。
    //
    // QA 价值：能听辨稀有度差异（N 素朴短 / R 清越 / SR 暖亮 / SSR 神性和鸣 + 长高潮）与图层差异
    // （Flip_Start 轻 whoosh / Reveal_Swap 青碧 chime / 稀有度顶层），以便验证「逐张错峰 + SSR 高潮 + 图层叠加」。
    public sealed class PlaceholderAudioProvider
    {
        // 采样率（移动端单声道优先，audio §3.7）。
        private const int SampleRate = 44100;

        // 每个 SoundId 的合成参数（频率 Hz / 时长 s / 波形 / 是否叠第二音）。
        private static (float freq, float dur, Wave wave, float freq2) Spec(SoundId id) => id switch
        {
            SoundId.Gacha_SinglePull_Click => (660f, 0.18f, Wave.Triangle, 0f),
            SoundId.Gacha_TenPull_Click => (550f, 0.22f, Wave.Triangle, 880f),
            SoundId.Gacha_Pool_Select => (880f, 0.10f, Wave.Sine, 0f),
            SoundId.Gacha_Card_Flip_Start => (320f, 0.12f, Wave.Noise, 0f),
            SoundId.Gacha_Rolling => (220f, 0.40f, Wave.Sine, 0f),
            SoundId.Gacha_Insufficient => (160f, 0.35f, Wave.Saw, 0f),
            SoundId.Gacha_Pity_Near => (740f, 0.20f, Wave.Sine, 0f),
            SoundId.Gacha_Pity_Triggered => (620f, 0.45f, Wave.Sine, 930f),
            SoundId.Gacha_Screen_Close => (520f, 0.25f, Wave.Sine, 0f),
            SoundId.Bond_Prologue_Open => (440f, 0.60f, Wave.Sine, 0f),
            SoundId.Gacha_Reveal_Swap => (784f, 0.40f, Wave.Sine, 0f),     // 青碧灵光升腾 chime
            SoundId.Gacha_Reveal_N => (392f, 0.30f, Wave.Sine, 0f),       // 素朴
            SoundId.Gacha_Reveal_R => (523f, 0.34f, Wave.Sine, 0f),       // 清越
            SoundId.Gacha_Reveal_SR => (659f, 0.40f, Wave.Triangle, 988f), // 暖亮 + 上行
            SoundId.Gacha_Reveal_SSR => (784f, 0.55f, Wave.Triangle, 1175f), // 神性和鸣
            SoundId.Gacha_Reveal_SSR_Climax => (523f, 1.80f, Wave.Sine, 1046f), // 紫宸长高潮
            SoundId.Gacha_Reveal_UR => (880f, 0.70f, Wave.Triangle, 1320f),
            _ => (440f, 0.20f, Wave.Sine, 0f),
        };

        private enum Wave { Sine, Triangle, Saw, Noise }

        // 合成一个 AudioClip（一次性；调用方用毕 Destroy）。clip 名含 SoundId 便于调试。
        public AudioClip GetClip(SoundId id)
        {
            var (freq, dur, wave, freq2) = Spec(id);
            var samples = Mathf.Max(1, Mathf.RoundToInt(SampleRate * dur));
            var clip = AudioClip.Create($"ph_{id}", samples, 1, SampleRate, false);
            var data = new float[samples];
            for (var i = 0; i < samples; i++)
            {
                var t = i / (float)SampleRate;
                var env = Envelope(t, dur);                 // 起音快、衰减柔
                var s1 = Oscillate(wave, freq, t) * env;
                var s2 = freq2 > 0 ? Oscillate(wave, freq2, t) * env * 0.5f : 0f;
                data[i] = Mathf.Clamp(s1 + s2, -1f, 1f);
            }
            clip.SetData(data, 0);
            return clip;
        }

        // 简单 ADSR-lite：0..0.02s 起音，之后指数衰减到尾。
        private static float Envelope(float t, float dur)
        {
            const float attack = 0.02f;
            if (t < attack) return t / attack;
            var decay = (t - attack) / Mathf.Max(1e-4f, dur - attack);
            return Mathf.Exp(-3f * decay);
        }

        private static float Oscillate(Wave wave, float freq, float t)
        {
            var phase = 2f * Mathf.PI * freq * t;
            switch (wave)
            {
                case Wave.Sine: return Mathf.Sin(phase);
                case Wave.Triangle: return (2f / Mathf.PI) * Mathf.Asin(Mathf.Sin(phase));
                case Wave.Saw: return 2f * (freq * t - Mathf.Floor(0.5f + freq * t));
                case Wave.Noise: return (Mathf.Sin(phase) * 0.5f) + (Mathf.Sin(phase * 2.3f) * 0.5f);
                default: return Mathf.Sin(phase);
            }
        }
    }
}
