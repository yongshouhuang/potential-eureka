#nullable enable
using System;
using XiaXia.Core;
using XiaXia.Core.Models;

namespace XiaXia.Features.Audio
{
    // 音频设置契约（audio §4.1）。变更经 C# event Changed 广播（等价于 Godot 信号），
    // AudioService 订阅之并调 SetMuted/SetCategoryVolume。UI 设置面板也经本接口读写。
    public interface IAudioSettings
    {
        bool SfxEnabled { get; set; }
        bool MusicEnabled { get; set; }
        float MasterVolume { get; set; }   // 0..1
        event Action Changed;
    }

    // 音频设置单例（audio §4.1）：在 AccessibilitySettings 尚未 C# 化的 M3 阶段，作为 peer 设置单例承载
    // sfx_enabled / music_enabled / master_volume(0–1)。落点对齐 GameState.settings（存档 schema v1 的
    // PlayerProfile.Settings 字典），不变更 schema 版本号。
    //
    // 解耦：只读写 PlayerProfile.Settings（存档数据对象，非 manager），不 import 任何 manager（ADR-3 #3）。
    // 注册：由 Bootstrapper 以 `new AudioSettings(profile)` 构造并 `_services.Register<IAudioSettings>(s)`。
    public sealed class AudioSettings : IAudioSettings
    {
        private const string K_Sfx = "audio_sfx_enabled";
        private const string K_Music = "audio_music_enabled";
        private const string K_Vol = "audio_master_volume";

        private readonly PlayerProfile _profile;
        public event Action? Changed;

        public AudioSettings(PlayerProfile profile)
        {
            _profile = profile ?? throw new ArgumentNullException(nameof(profile));
        }

        public bool SfxEnabled
        {
            get => GetBool(K_Sfx, true);
            set => SetBool(K_Sfx, value);
        }

        public bool MusicEnabled
        {
            get => GetBool(K_Music, true);
            set => SetBool(K_Music, value);
        }

        public float MasterVolume
        {
            get => GetFloat(K_Vol, 1f);
            set => SetFloat(K_Vol, value);
        }

        // —— 存档读写（PlayerProfile.Settings 字典；JSON 往返后 bool→bool、number→double）——
        private bool GetBool(string key, bool fallback)
        {
            if (_profile.Settings.TryGetValue(key, out var v) && v is bool b) return b;
            return fallback;
        }

        private void SetBool(string key, bool value)
        {
            if (GetBool(key, !value) == value) return; // 无变化不广播
            _profile.Settings[key] = value;
            Changed?.Invoke();
        }

        private float GetFloat(string key, float fallback)
        {
            if (_profile.Settings.TryGetValue(key, out var v))
            {
                var d = v switch
                {
                    double db => db,
                    float f => f,
                    int i => i,
                    long l => l,
                    _ => double.NaN,
                };
                if (!double.IsNaN(d)) return (float)d;
            }
            return fallback;
        }

        private void SetFloat(string key, float value)
        {
            var clamped = Math.Clamp(value, 0f, 1f);
            if (Math.Abs(GetFloat(key, clamped - 1f) - clamped) < 1e-4f) return; // 无变化不广播
            _profile.Settings[key] = (double)clamped;
            Changed?.Invoke();
        }
    }
}
